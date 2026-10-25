#!/usr/bin/env Rscript
# =============================================================================
# WOODCHESTER - CONSECUTIVE TERRITORY LINEAGE EVIDENCE
#
# PURPOSE
# Combine three independent evidence streams for consecutive-year territory
# continuity:
#   1. polygon geometry overlap;
#   2. shared canonical sett IDs;
#   3. capture-recorded social-group evidence at those setts.
#
# This is a REVIEW / EVIDENCE table. It NEVER automatically renames polygons,
# merges social groups or writes to Supabase.
#
# PREREQUISITES
#   scripts/Spatial/09_canonical_sett_id_territory_SG_audit.R
#   scripts/Spatial/11_audit_V11R2_dynamic_social_group_overlay.R
#
# INPUTS
#   outputs/canonical_sett_SG_territory_crosswalk/
#     07_canonical_capture_SG_evidence.csv
#     09_sett_polygon_all_matches.csv
#   outputs/V11R2_dynamic_social_group_overlay/audit/
#     04_boundary_change_label_pairs.csv
#     05_consecutive_polygon_overlap_crosswalk.csv
#
# OUTPUTS
#   outputs/V11R2_dynamic_social_group_overlay/lineage/
#     01_territory_year_sett_evidence.csv
#     02_territory_year_capture_SG_evidence.csv
#     03_consecutive_territory_lineage_evidence.csv
#     04_boundary_change_lineage_priority.csv
#     05_lineage_review_summary.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(purrr)
  library(tibble)
})

CANONICAL_DIR <- Sys.getenv(
  "CANONICAL_DIR",
  unset = "outputs/canonical_sett_SG_territory_crosswalk"
)
OVERLAY_AUDIT_DIR <- Sys.getenv(
  "OVERLAY_AUDIT_DIR",
  unset = "outputs/V11R2_dynamic_social_group_overlay/audit"
)
OUT <- Sys.getenv(
  "LINEAGE_OUTPUT_DIR",
  unset = "outputs/V11R2_dynamic_social_group_overlay/lineage"
)
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

sett_polygon_file <- file.path(CANONICAL_DIR, "09_sett_polygon_all_matches.csv")
capture_sg_file <- file.path(CANONICAL_DIR, "07_canonical_capture_SG_evidence.csv")
geom_file <- file.path(OVERLAY_AUDIT_DIR, "05_consecutive_polygon_overlap_crosswalk.csv")
boundary_pair_file <- file.path(OVERLAY_AUDIT_DIR, "04_boundary_change_label_pairs.csv")

for (p in c(sett_polygon_file, capture_sg_file, geom_file, boundary_pair_file)) {
  if (!file.exists(p)) {
    stop(
      "Missing required input: ", p,
      "\nRun scripts/Spatial/09_canonical_sett_id_territory_SG_audit.R ",
      "and scripts/Spatial/11_audit_V11R2_dynamic_social_group_overlay.R first."
    )
  }
}

territory_key <- function(x) {
  z <- toupper(str_squish(as.character(x)))
  z <- str_replace_all(z, "[^A-Z0-9]", "")
  z[is.na(x) | z == ""] <- NA_character_
  z
}

collapse_sorted <- function(x) {
  z <- sort(unique(x[!is.na(x) & x != ""]))
  if (!length(z)) NA_character_ else paste(z, collapse = " | ")
}

safe_ratio <- function(a, b) {
  ifelse(is.finite(b) & b > 0, a / b, NA_real_)
}

cat("\n============================================================\n")
cat("CONSECUTIVE TERRITORY LINEAGE EVIDENCE\n")
cat("============================================================\n\n")

# -----------------------------------------------------------------------------
# 1. Canonical sett membership of each mapped territory-year
# -----------------------------------------------------------------------------

hits <- read_csv(sett_polygon_file, show_col_types = FALSE)
need_hits <- c("year", "sett_id", "polygon_name")
if (!all(need_hits %in% names(hits))) {
  stop(
    "Sett-polygon file missing: ",
    paste(setdiff(need_hits, names(hits)), collapse = ", ")
  )
}

territory_setts_long <- hits %>%
  transmute(
    year = as.integer(year),
    territory_key = territory_key(polygon_name),
    territory_label = as.character(polygon_name),
    sett_id = as.integer(sett_id)
  ) %>%
  filter(!is.na(year), !is.na(territory_key), !is.na(sett_id)) %>%
  distinct(year, territory_key, sett_id, .keep_all = TRUE)

territory_setts_summary <- territory_setts_long %>%
  group_by(year, territory_key) %>%
  summarise(
    territory_labels = collapse_sorted(territory_label),
    n_canonical_setts = n_distinct(sett_id),
    canonical_sett_ids = paste(sort(unique(sett_id)), collapse = ";"),
    .groups = "drop"
  )

write_csv(
  territory_setts_summary,
  file.path(OUT, "01_territory_year_sett_evidence.csv")
)

# Fast lookup for set arithmetic.
sett_lookup <- split(
  territory_setts_long$sett_id,
  paste(territory_setts_long$year, territory_setts_long$territory_key, sep = "::")
)
sett_lookup <- lapply(sett_lookup, function(z) sort(unique(as.integer(z))))

get_setts <- function(year, key) {
  z <- sett_lookup[[paste(year, key, sep = "::")]]
  if (is.null(z)) integer() else z
}

# -----------------------------------------------------------------------------
# 2. Capture-recorded SG evidence within each territory-year
# -----------------------------------------------------------------------------

cap <- read_csv(capture_sg_file, show_col_types = FALSE)
need_cap <- c("year", "sett_id", "captured_sg", "n_captures")
if (!all(need_cap %in% names(cap))) {
  stop(
    "Capture SG evidence file missing: ",
    paste(setdiff(need_cap, names(cap)), collapse = ", ")
  )
}

cap <- cap %>%
  transmute(
    year = as.integer(year),
    sett_id = as.integer(sett_id),
    captured_sg = as.character(captured_sg),
    n_captures = as.integer(n_captures)
  ) %>%
  filter(
    !is.na(year),
    !is.na(sett_id),
    !is.na(captured_sg),
    captured_sg != "",
    is.finite(n_captures),
    n_captures > 0
  )

territory_sg_long <- territory_setts_long %>%
  select(year, territory_key, sett_id) %>%
  inner_join(
    cap,
    by = c("year", "sett_id"),
    relationship = "many-to-many"
  ) %>%
  group_by(year, territory_key, captured_sg) %>%
  summarise(
    n_captures = sum(n_captures),
    n_setts_supporting = n_distinct(sett_id),
    .groups = "drop"
  ) %>%
  group_by(year, territory_key) %>%
  mutate(
    total_grouped_captures = sum(n_captures),
    capture_share = n_captures / total_grouped_captures,
    max_capture_share = max(capture_share),
    is_dominant = capture_share == max_capture_share,
    n_dominant = sum(is_dominant)
  ) %>%
  ungroup()

territory_sg_summary <- territory_sg_long %>%
  group_by(year, territory_key) %>%
  summarise(
    total_grouped_captures = max(total_grouped_captures),
    n_recorded_SGs = n_distinct(captured_sg),
    recorded_SGs = collapse_sorted(captured_sg),
    dominant_SG = if (
      sum(is_dominant) == 1L
    ) captured_sg[which(is_dominant)[1]] else NA_character_,
    dominant_SG_share = if (
      sum(is_dominant) == 1L
    ) max_capture_share[which(is_dominant)[1]] else NA_real_,
    dominant_SG_n_setts = if (
      sum(is_dominant) == 1L
    ) n_setts_supporting[which(is_dominant)[1]] else NA_integer_,
    .groups = "drop"
  )

write_csv(
  territory_sg_summary,
  file.path(OUT, "02_territory_year_capture_SG_evidence.csv")
)

# SG set lookup for overlap evidence.
sg_lookup <- split(
  territory_sg_long$captured_sg,
  paste(territory_sg_long$year, territory_sg_long$territory_key, sep = "::")
)
sg_lookup <- lapply(sg_lookup, function(z) sort(unique(as.character(z))))

get_sgs <- function(year, key) {
  z <- sg_lookup[[paste(year, key, sep = "::")]]
  if (is.null(z)) character() else z
}

# -----------------------------------------------------------------------------
# 3. Consecutive polygon geometry + sett + SG evidence
# -----------------------------------------------------------------------------

geom <- read_csv(geom_file, show_col_types = FALSE)
need_geom <- c(
  "year_from", "year_to",
  "origin_territory_key", "destination_territory_key",
  "origin_territory_label", "destination_territory_label",
  "overlap_fraction_of_origin", "overlap_fraction_of_destination",
  "jaccard", "reciprocal_best_match", "same_key"
)
if (!all(need_geom %in% names(geom))) {
  stop(
    "Geometry crosswalk missing: ",
    paste(setdiff(need_geom, names(geom)), collapse = ", ")
  )
}

lineage <- geom %>%
  rowwise() %>%
  mutate(
    origin_setts_obj = list(get_setts(year_from, origin_territory_key)),
    destination_setts_obj = list(get_setts(year_to, destination_territory_key)),
    shared_setts_obj = list(intersect(origin_setts_obj, destination_setts_obj)),
    union_setts_obj = list(union(origin_setts_obj, destination_setts_obj)),

    n_origin_setts = length(origin_setts_obj),
    n_destination_setts = length(destination_setts_obj),
    n_shared_setts = length(shared_setts_obj),
    sett_jaccard = if (
      length(union_setts_obj) > 0L
    ) length(shared_setts_obj) / length(union_setts_obj) else NA_real_,
    shared_sett_ids = if (
      length(shared_setts_obj)
    ) paste(shared_setts_obj, collapse = ";") else NA_character_,

    origin_sgs_obj = list(get_sgs(year_from, origin_territory_key)),
    destination_sgs_obj = list(get_sgs(year_to, destination_territory_key)),
    shared_sgs_obj = list(intersect(origin_sgs_obj, destination_sgs_obj)),
    union_sgs_obj = list(union(origin_sgs_obj, destination_sgs_obj)),

    n_origin_recorded_SGs = length(origin_sgs_obj),
    n_destination_recorded_SGs = length(destination_sgs_obj),
    n_shared_recorded_SGs = length(shared_sgs_obj),
    SG_jaccard = if (
      length(union_sgs_obj) > 0L
    ) length(shared_sgs_obj) / length(union_sgs_obj) else NA_real_,
    shared_recorded_SGs = if (
      length(shared_sgs_obj)
    ) paste(shared_sgs_obj, collapse = " | ") else NA_character_
  ) %>%
  ungroup() %>%
  select(
    -origin_setts_obj, -destination_setts_obj, -shared_setts_obj, -union_setts_obj,
    -origin_sgs_obj, -destination_sgs_obj, -shared_sgs_obj, -union_sgs_obj
  ) %>%
  left_join(
    territory_sg_summary %>%
      rename(
        year_from = year,
        origin_territory_key = territory_key,
        origin_total_grouped_captures = total_grouped_captures,
        origin_n_recorded_SGs = n_recorded_SGs,
        origin_recorded_SGs = recorded_SGs,
        origin_dominant_SG = dominant_SG,
        origin_dominant_SG_share = dominant_SG_share,
        origin_dominant_SG_n_setts = dominant_SG_n_setts
      ),
    by = c("year_from", "origin_territory_key"),
    relationship = "many-to-one"
  ) %>%
  left_join(
    territory_sg_summary %>%
      rename(
        year_to = year,
        destination_territory_key = territory_key,
        destination_total_grouped_captures = total_grouped_captures,
        destination_n_recorded_SGs = n_recorded_SGs,
        destination_recorded_SGs = recorded_SGs,
        destination_dominant_SG = dominant_SG,
        destination_dominant_SG_share = dominant_SG_share,
        destination_dominant_SG_n_setts = dominant_SG_n_setts
      ),
    by = c("year_to", "destination_territory_key"),
    relationship = "many-to-one"
  ) %>%
  mutate(
    dominant_SG_same =
      !is.na(origin_dominant_SG) &
      !is.na(destination_dominant_SG) &
      origin_dominant_SG == destination_dominant_SG,

    both_dominant_SG_high_support =
      !is.na(origin_dominant_SG_share) &
      !is.na(destination_dominant_SG_share) &
      origin_dominant_SG_share >= 0.70 &
      destination_dominant_SG_share >= 0.70,

    # Evidence class only. NONE of these statuses authorises a rename/merge.
    lineage_evidence_class = case_when(
      same_key ~
        "SAME_FORMATTED_LABEL",

      reciprocal_best_match &
        jaccard >= 0.80 &
        sett_jaccard >= 0.50 &
        dominant_SG_same &
        both_dominant_SG_high_support ~
        "VERY_STRONG_MULTI_EVIDENCE_CONTINUITY",

      reciprocal_best_match &
        jaccard >= 0.50 &
        n_shared_setts >= 1L &
        dominant_SG_same ~
        "STRONG_MULTI_EVIDENCE_CONTINUITY",

      reciprocal_best_match &
        jaccard >= 0.50 &
        sett_jaccard >= 0.50 &
        (is.na(origin_dominant_SG) | is.na(destination_dominant_SG)) ~
        "GEOMETRY_SETT_CONTINUITY_SG_UNRESOLVED",

      reciprocal_best_match &
        jaccard >= 0.50 &
        dominant_SG_same ~
        "GEOMETRY_AND_SG_CONTINUITY",

      reciprocal_best_match &
        jaccard >= 0.50 &
        both_dominant_SG_high_support &
        !dominant_SG_same ~
        "GEOMETRIC_CONTINUITY_BUT_DIFFERENT_STRONG_SG_EVIDENCE",

      reciprocal_best_match &
        jaccard >= 0.50 ~
        "GEOMETRIC_CONTINUITY_ONLY",

      jaccard >= 0.50 ~
        "SUBSTANTIAL_OVERLAP_NOT_RECIPROCAL_BEST",

      TRUE ~
        "LOWER_GEOMETRIC_CONTINUITY"
    ),

    identity_decision = "UNAPPROVED_REVIEW_REQUIRED"
  )

write_csv(
  lineage,
  file.path(OUT, "03_consecutive_territory_lineage_evidence.csv")
)

# -----------------------------------------------------------------------------
# 4. Prioritise the exact polygon-name pairs driving boundary-change intervals
# -----------------------------------------------------------------------------

bp <- read_csv(boundary_pair_file, show_col_types = FALSE)
need_bp <- c(
  "year_from", "year_to",
  "mode_origin_territory_key", "mode_destination_territory_key",
  "n_intervals"
)
if (!all(need_bp %in% names(bp))) {
  stop(
    "Boundary-pair table missing: ",
    paste(setdiff(need_bp, names(bp)), collapse = ", ")
  )
}

priority <- bp %>%
  left_join(
    lineage,
    by = c(
      "year_from",
      "year_to",
      "mode_origin_territory_key" = "origin_territory_key",
      "mode_destination_territory_key" = "destination_territory_key"
    ),
    relationship = "many-to-one"
  ) %>%
  mutate(
    review_priority = case_when(
      n_intervals >= 8L ~ "HIGH",
      n_intervals >= 4L ~ "MEDIUM",
      TRUE ~ "LOW"
    )
  ) %>%
  arrange(
    factor(review_priority, levels = c("HIGH","MEDIUM","LOW")),
    desc(n_intervals),
    desc(jaccard)
  )

write_csv(
  priority,
  file.path(OUT, "04_boundary_change_lineage_priority.csv")
)

review_summary <- priority %>%
  group_by(lineage_evidence_class) %>%
  summarise(
    n_label_pairs = n(),
    n_boundary_change_intervals = sum(n_intervals),
    .groups = "drop"
  ) %>%
  mutate(
    proportion_boundary_change_intervals =
      n_boundary_change_intervals / sum(n_boundary_change_intervals)
  ) %>%
  arrange(desc(n_boundary_change_intervals))

write_csv(
  review_summary,
  file.path(OUT, "05_lineage_review_summary.csv")
)

cat("Consecutive polygon-overlap pairs:", nrow(lineage), "\n")
cat("Boundary-change label-pair rows:", nrow(priority), "\n\n")

cat("Boundary-change intervals by multi-evidence lineage class:\n")
print(review_summary, n = Inf, width = Inf)

cat("\nHighest-priority boundary-change lineage review:\n")
print(
  priority %>%
    select(
      year_from, year_to,
      mode_origin_territory_label,
      mode_destination_territory_label,
      n_intervals,
      jaccard,
      n_shared_setts,
      sett_jaccard,
      origin_dominant_SG,
      origin_dominant_SG_share,
      destination_dominant_SG,
      destination_dominant_SG_share,
      lineage_evidence_class,
      review_priority
    ) %>%
    slice_head(n = 30),
  n = Inf,
  width = Inf
)

cat("\nSaved lineage evidence in: ", OUT, "\n", sep = "")
cat("NO names, canonical sett IDs or social-group identities were changed.\n")
