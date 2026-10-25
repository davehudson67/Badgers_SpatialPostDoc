#!/usr/bin/env Rscript
# =============================================================================
# WOODCHESTER - V11R2 DYNAMIC SG OVERLAY DIAGNOSTIC AUDIT
#
# PURPOSE
# Audit two deliberately conservative outputs from script 10:
#   1. polygon ambiguity / outside-map assignment;
#   2. "boundary-change-only" transitions.
#
# This script does NOT rename territories or infer social-group identity.
# It quantifies consecutive-year polygon continuity so that apparent changes
# can be separated into:
#   - likely label continuity / rename candidates;
#   - strong geometric continuity with boundary adjustment;
#   - split/merge/reconfiguration candidates;
#   - poorly supported or ambiguous cases.
#
# INPUTS
#   outputs/V11R2_dynamic_social_group_overlay/
#     04_posterior_transition_territory_draws.csv
#     06_master_movement_social_transition_table.csv
#   outputs/social_group_boundary_audit/annual_territories.gpkg
#
# OUTPUTS
#   outputs/V11R2_dynamic_social_group_overlay/audit/
#     01_ambiguity_draw_components.csv
#     02_ambiguity_interval_components.csv
#     03_boundary_change_interval_details.csv
#     04_boundary_change_label_pairs.csv
#     05_consecutive_polygon_overlap_crosswalk.csv
#     06_boundary_change_with_polygon_continuity.csv
#     07_candidate_label_continuity.csv
#     08_stable_cross_vs_resident_SG.csv
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(purrr)
  library(tibble)
})

ROOT <- Sys.getenv(
  "OVERLAY_DIR",
  unset = "outputs/V11R2_dynamic_social_group_overlay"
)
TERRITORIES_FILE <- Sys.getenv(
  "TERRITORIES_FILE",
  unset = "outputs/social_group_boundary_audit/annual_territories.gpkg"
)
OUT <- file.path(ROOT, "audit")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

draw_file <- file.path(ROOT, "04_posterior_transition_territory_draws.csv")
master_file <- file.path(ROOT, "06_master_movement_social_transition_table.csv")

for (p in c(draw_file, master_file, TERRITORIES_FILE)) {
  if (!file.exists(p)) stop("Missing required input: ", p)
}

key <- function(x) {
  z <- toupper(str_squish(as.character(x)))
  z <- str_replace_all(z, "[^A-Z0-9]", "")
  z[is.na(x) | z == ""] <- NA_character_
  z
}

is_overlap <- function(x) {
  !is.na(x) & str_detect(x, fixed("|"))
}
is_outside <- function(x) {
  !is.na(x) & x == "OUTSIDE"
}
is_nomap <- function(x) {
  !is.na(x) & x == "NO_MAP"
}

cat("\n============================================================\n")
cat("V11R2 DYNAMIC SG OVERLAY DIAGNOSTIC AUDIT\n")
cat("============================================================\n\n")

draws <- read_csv(draw_file, show_col_types = FALSE)
master <- read_csv(master_file, show_col_types = FALSE)

need_draw <- c(
  "tattoo","year_from","year_to",
  "territory_key_origin",
  "territory_key_destination_on_previous_map",
  "territory_key_origin_on_next_map",
  "territory_key_destination",
  "strict_stable_boundary_cross",
  "boundary_change_only",
  "polygon_ambiguous"
)
if (!all(need_draw %in% names(draws))) {
  stop("Draw table missing: ", paste(setdiff(need_draw, names(draws)), collapse=", "))
}

# -----------------------------------------------------------------------------
# 1. WHY ARE DRAWS AMBIGUOUS?
# -----------------------------------------------------------------------------

draw_amb <- draws %>%
  mutate(
    origin_overlap = is_overlap(territory_key_origin),
    destination_prev_overlap = is_overlap(territory_key_destination_on_previous_map),
    origin_next_overlap = is_overlap(territory_key_origin_on_next_map),
    destination_overlap = is_overlap(territory_key_destination),

    origin_outside = is_outside(territory_key_origin),
    destination_prev_outside = is_outside(territory_key_destination_on_previous_map),
    origin_next_outside = is_outside(territory_key_origin_on_next_map),
    destination_outside = is_outside(territory_key_destination),

    origin_nomap = is_nomap(territory_key_origin),
    destination_prev_nomap = is_nomap(territory_key_destination_on_previous_map),
    origin_next_nomap = is_nomap(territory_key_origin_on_next_map),
    destination_nomap = is_nomap(territory_key_destination),

    any_overlap =
      origin_overlap | destination_prev_overlap |
      origin_next_overlap | destination_overlap,

    any_outside =
      origin_outside | destination_prev_outside |
      origin_next_outside | destination_outside,

    any_nomap =
      origin_nomap | destination_prev_nomap |
      origin_next_nomap | destination_nomap,

    ambiguity_reason = case_when(
      !polygon_ambiguous ~ "NOT_AMBIGUOUS",
      any_nomap & any_outside & any_overlap ~ "NO_MAP+OUTSIDE+OVERLAP",
      any_nomap & any_outside ~ "NO_MAP+OUTSIDE",
      any_nomap & any_overlap ~ "NO_MAP+OVERLAP",
      any_outside & any_overlap ~ "OUTSIDE+OVERLAP",
      any_nomap ~ "NO_MAP",
      any_outside ~ "OUTSIDE",
      any_overlap ~ "OVERLAP",
      TRUE ~ "OTHER"
    )
  )

ambiguity_draw_summary <- draw_amb %>%
  count(ambiguity_reason, name = "n_draw_transitions") %>%
  mutate(proportion = n_draw_transitions / sum(n_draw_transitions)) %>%
  arrange(desc(n_draw_transitions))

write_csv(
  ambiguity_draw_summary,
  file.path(OUT, "01_ambiguity_draw_components.csv")
)

ambiguity_interval <- draw_amb %>%
  group_by(tattoo, year_from, year_to) %>%
  summarise(
    p_polygon_ambiguous = mean(polygon_ambiguous),
    p_any_overlap = mean(any_overlap),
    p_any_outside = mean(any_outside),
    p_any_nomap = mean(any_nomap),
    p_origin_outside = mean(origin_outside),
    p_destination_outside = mean(destination_outside),
    p_origin_overlap = mean(origin_overlap),
    p_destination_overlap = mean(destination_overlap),
    .groups = "drop"
  ) %>%
  arrange(desc(p_polygon_ambiguous))

write_csv(
  ambiguity_interval,
  file.path(OUT, "02_ambiguity_interval_components.csv")
)

# -----------------------------------------------------------------------------
# 2. BOUNDARY-CHANGE DOMINANT INTERVALS
# -----------------------------------------------------------------------------

boundary_intervals <- master %>%
  filter(p_boundary_change_only >= 0.5) %>%
  arrange(desc(p_boundary_change_only)) %>%
  mutate(
    polygon_pair = paste0(
      mode_origin_territory_key,
      " -> ",
      mode_destination_territory_key
    )
  )

write_csv(
  boundary_intervals,
  file.path(OUT, "03_boundary_change_interval_details.csv")
)

boundary_pairs <- boundary_intervals %>%
  group_by(
    year_from,
    year_to,
    mode_origin_territory_key,
    mode_destination_territory_key,
    mode_origin_territory_label,
    mode_destination_territory_label
  ) %>%
  summarise(
    n_intervals = n(),
    mean_p_boundary_change_only = mean(p_boundary_change_only),
    mean_p_relocation_50 = mean(p_relocation_50),
    n_central_relocation = sum(p_relocation_50 >= 0.5),
    n_resident_group_change = sum(resident_group_change %in% TRUE, na.rm = TRUE),
    n_resident_group_same = sum(resident_group_change %in% FALSE, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(n_intervals), year_from)

write_csv(
  boundary_pairs,
  file.path(OUT, "04_boundary_change_label_pairs.csv")
)

# -----------------------------------------------------------------------------
# 3. CONSECUTIVE-YEAR POLYGON GEOMETRIC CONTINUITY
# -----------------------------------------------------------------------------

terr_raw <- st_read(TERRITORIES_FILE, quiet = TRUE)
if (!all(c("year","territory_name") %in% names(terr_raw))) {
  stop("Territory file lacks year/territory_name.")
}
if (is.na(st_crs(terr_raw))) stop("Territory file has no CRS.")

terr <- terr_raw %>%
  st_transform(27700) %>%
  mutate(
    year = as.integer(year),
    territory_name = as.character(territory_name),
    territory_key = key(territory_name)
  ) %>%
  filter(!is.na(year), !is.na(territory_key)) %>%
  group_by(year, territory_key) %>%
  summarise(
    territory_labels = paste(sort(unique(territory_name)), collapse = " | "),
    .groups = "drop"
  ) %>%
  mutate(area_m2 = as.numeric(st_area(.)))

years <- sort(unique(terr$year))
crosswalk <- vector("list", length(years) - 1L)

for (ii in seq_len(length(years) - 1L)) {
  y0 <- years[ii]
  y1 <- years[ii + 1L]
  if (y1 != y0 + 1L) next

  a <- terr %>% filter(year == y0)
  b <- terr %>% filter(year == y1)

  hits <- st_intersects(a, b)
  rows <- list()
  rr <- 0L

  for (i in seq_len(nrow(a))) {
    if (!length(hits[[i]])) next

    for (j in hits[[i]]) {
      inter <- suppressWarnings(st_intersection(
        st_geometry(a[i, ]),
        st_geometry(b[j, ])
      ))
      ia <- if (length(inter)) {
        sum(as.numeric(st_area(inter)))
      } else {
        0
      }

      if (!is.finite(ia) || ia <= 0) next

      rr <- rr + 1L
      union_area <- a$area_m2[i] + b$area_m2[j] - ia

      rows[[rr]] <- tibble(
        year_from = y0,
        year_to = y1,
        origin_territory_key = a$territory_key[i],
        origin_territory_label = a$territory_labels[i],
        destination_territory_key = b$territory_key[j],
        destination_territory_label = b$territory_labels[j],
        origin_area_m2 = a$area_m2[i],
        destination_area_m2 = b$area_m2[j],
        intersection_area_m2 = ia,
        overlap_fraction_of_origin = ia / a$area_m2[i],
        overlap_fraction_of_destination = ia / b$area_m2[j],
        jaccard = ia / union_area
      )
    }
  }

  crosswalk[[ii]] <- bind_rows(rows)
}

polygon_crosswalk <- bind_rows(crosswalk) %>%
  group_by(year_from, origin_territory_key) %>%
  mutate(
    origin_best_jaccard = max(jaccard, na.rm = TRUE),
    origin_best_match = jaccard == origin_best_jaccard
  ) %>%
  ungroup() %>%
  group_by(year_to, destination_territory_key) %>%
  mutate(
    destination_best_jaccard = max(jaccard, na.rm = TRUE),
    destination_best_match = jaccard == destination_best_jaccard
  ) %>%
  ungroup() %>%
  mutate(
    reciprocal_best_match = origin_best_match & destination_best_match,
    same_key = origin_territory_key == destination_territory_key
  )

write_csv(
  st_drop_geometry(polygon_crosswalk),
  file.path(OUT, "05_consecutive_polygon_overlap_crosswalk.csv")
)

# Join boundary-change intervals to geometry of their modal label pair.
boundary_continuity <- boundary_intervals %>%
  left_join(
    st_drop_geometry(polygon_crosswalk) %>%
      select(
        year_from, year_to,
        origin_territory_key,
        destination_territory_key,
        overlap_fraction_of_origin,
        overlap_fraction_of_destination,
        jaccard,
        reciprocal_best_match,
        same_key
      ),
    by = c(
      "year_from",
      "year_to",
      "mode_origin_territory_key" = "origin_territory_key",
      "mode_destination_territory_key" = "destination_territory_key"
    ),
    relationship = "many-to-one"
  ) %>%
  mutate(
    polygon_continuity_class = case_when(
      is.na(jaccard) ~ "NO_DIRECT_POLYGON_OVERLAP_MATCH",
      mode_origin_territory_key == mode_destination_territory_key ~
        "SAME_LABEL",
      reciprocal_best_match & jaccard >= 0.80 ~
        "VERY_HIGH_CONTINUITY_DIFFERENT_LABEL",
      reciprocal_best_match & jaccard >= 0.50 ~
        "HIGH_CONTINUITY_DIFFERENT_LABEL",
      jaccard >= 0.50 ~
        "SUBSTANTIAL_OVERLAP_NOT_RECIPROCAL_BEST",
      TRUE ~
        "LOWER_CONTINUITY_RECONFIGURATION"
    )
  )

write_csv(
  boundary_continuity,
  file.path(OUT, "06_boundary_change_with_polygon_continuity.csv")
)

# This is a REVIEW LIST only. Do not convert these into automatic aliases.
candidate_continuity <- polygon_crosswalk %>%
  st_drop_geometry() %>%
  filter(
    !same_key,
    reciprocal_best_match,
    jaccard >= 0.50
  ) %>%
  arrange(year_from, desc(jaccard)) %>%
  transmute(
    year_from,
    year_to,
    origin_territory_key,
    origin_territory_label,
    destination_territory_key,
    destination_territory_label,
    overlap_fraction_of_origin,
    overlap_fraction_of_destination,
    jaccard,
    review_status = "REVIEW_ONLY_DO_NOT_AUTO_RENAME"
  )

write_csv(
  candidate_continuity,
  file.path(OUT, "07_candidate_label_continuity.csv")
)

# -----------------------------------------------------------------------------
# 4. TERRITORY CROSSING VS CAPTURE-DERIVED RESIDENT SG CHANGE
# -----------------------------------------------------------------------------

cross_vs_sg <- master %>%
  mutate(
    stable_cross_50 = p_strict_stable_boundary_cross >= 0.5,
    relocation_50 = p_relocation_50 >= 0.5,
    resident_SG_status = case_when(
      is.na(resident_group_change) ~ "RESIDENT_SG_UNKNOWN",
      resident_group_change ~ "RESIDENT_SG_CHANGED",
      TRUE ~ "RESIDENT_SG_SAME"
    ),
    stable_cross_status = if_else(
      stable_cross_50,
      "STABLE_TERRITORY_CROSS",
      "NO_STRONG_STABLE_TERRITORY_CROSS"
    ),
    relocation_status = if_else(
      relocation_50,
      "CENTRAL_RELOCATION",
      "NO_CENTRAL_RELOCATION"
    )
  ) %>%
  count(
    relocation_status,
    stable_cross_status,
    resident_SG_status,
    name = "n_intervals"
  ) %>%
  mutate(proportion = n_intervals / sum(n_intervals)) %>%
  arrange(
    relocation_status,
    stable_cross_status,
    resident_SG_status
  )

write_csv(
  cross_vs_sg,
  file.path(OUT, "08_stable_cross_vs_resident_SG.csv")
)

# -----------------------------------------------------------------------------
# Console summary
# -----------------------------------------------------------------------------

cat("Movement intervals:", nrow(master), "\n")
cat(
  "Intervals with p(boundary-change-only) >= 0.5:",
  nrow(boundary_intervals),
  "\n\n"
)

cat("Draw-level ambiguity causes:\n")
print(ambiguity_draw_summary, n = Inf, width = Inf)

cat("\nBoundary-change intervals by polygon-continuity class:\n")
print(
  boundary_continuity %>%
    count(polygon_continuity_class, name = "n_intervals") %>%
    arrange(desc(n_intervals)),
  n = Inf,
  width = Inf
)

cat("\nHighest-frequency boundary-change label pairs:\n")
print(
  boundary_pairs %>%
    slice_head(n = 25),
  n = Inf,
  width = Inf
)

cat("\nCandidate consecutive-year label continuity pairs (review only):\n")
print(
  candidate_continuity %>%
    slice_head(n = 25),
  n = Inf,
  width = Inf
)

cat("\nStable territory cross vs resident SG:\n")
print(cross_vs_sg, n = Inf, width = Inf)

cat("\nSaved diagnostic outputs in: ", OUT, "\n", sep = "")
cat("NO territory names or social-group identities were changed.\n")
