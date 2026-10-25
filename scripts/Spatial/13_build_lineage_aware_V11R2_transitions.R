#!/usr/bin/env Rscript
# =============================================================================
# WOODCHESTER - LINEAGE-AWARE V11R2 TERRITORY TRANSITIONS
#
# PURPOSE
# Reinterpret raw year-to-year polygon label changes using the independent
# consecutive-territory lineage evidence assembled in script 12.
#
# IMPORTANT
# - Raw annual polygon names are preserved.
# - No global SG-name dictionary is created.
# - No polygon, sett or social-group identity is rewritten.
# - "Same lineage" means supported continuity of annual territory objects,
#   not permanent individual social-group membership.
#
# INPUTS
#   outputs/V11R2_dynamic_social_group_overlay/
#     04_posterior_transition_territory_draws.csv
#     06_master_movement_social_transition_table.csv
#   outputs/V11R2_dynamic_social_group_overlay/lineage/
#     03_consecutive_territory_lineage_evidence.csv
#
# OUTPUTS
#   outputs/V11R2_dynamic_social_group_overlay/lineage/
#     06_posterior_lineage_transition_draws.csv
#     07_lineage_transition_summary.csv
#     08_master_movement_social_lineage_table.csv
#     09_lineage_transition_class_summary.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(tibble)
})

ROOT <- Sys.getenv(
  "OVERLAY_DIR",
  unset = "outputs/V11R2_dynamic_social_group_overlay"
)
LINEAGE_DIR <- Sys.getenv(
  "LINEAGE_DIR",
  unset = file.path(ROOT, "lineage")
)

draw_file <- file.path(ROOT, "04_posterior_transition_territory_draws.csv")
master_file <- file.path(ROOT, "06_master_movement_social_transition_table.csv")
lineage_file <- file.path(LINEAGE_DIR, "03_consecutive_territory_lineage_evidence.csv")

for (p in c(draw_file, master_file, lineage_file)) {
  if (!file.exists(p)) stop("Missing required input: ", p)
}

cat("\n============================================================\n")
cat("LINEAGE-AWARE V11R2 TERRITORY TRANSITIONS\n")
cat("============================================================\n\n")

draws <- read_csv(draw_file, show_col_types = FALSE)
master <- read_csv(master_file, show_col_types = FALSE)
lineage <- read_csv(lineage_file, show_col_types = FALSE)

need_draw <- c(
  "individual_id","tattoo","year_from","year_to",
  "territory_key_origin","territory_key_destination",
  "all_four_unambiguous",
  "strict_stable_boundary_cross",
  "boundary_change_only",
  "polygon_ambiguous"
)
if (!all(need_draw %in% names(draws))) {
  stop("Draw table missing: ", paste(setdiff(need_draw, names(draws)), collapse=", "))
}

need_lineage <- c(
  "year_from","year_to",
  "origin_territory_key","destination_territory_key",
  "jaccard","n_shared_setts","sett_jaccard",
  "origin_dominant_SG","origin_dominant_SG_share",
  "destination_dominant_SG","destination_dominant_SG_share",
  "lineage_evidence_class"
)
if (!all(need_lineage %in% names(lineage))) {
  stop(
    "Lineage evidence missing: ",
    paste(setdiff(need_lineage, names(lineage)), collapse=", ")
  )
}

# One geometry/lineage row must exist at most once for a given consecutive
# year + territory-key pair.
dup <- lineage %>%
  count(year_from, year_to, origin_territory_key, destination_territory_key) %>%
  filter(n > 1L)
if (nrow(dup)) {
  print(dup, n = Inf)
  stop("Lineage table has duplicate year/pair keys.")
}

# Classes with independent evidence sufficient to treat a changed annual
# polygon label as continuity of the same territory lineage.
supported_continuity_classes <- c(
  "SAME_FORMATTED_LABEL",
  "VERY_STRONG_MULTI_EVIDENCE_CONTINUITY",
  "STRONG_MULTI_EVIDENCE_CONTINUITY",
  "GEOMETRY_SETT_CONTINUITY_SG_UNRESOLVED",
  "GEOMETRY_AND_SG_CONTINUITY"
)

# Explicit conflict: geometry suggests continuity, but strong capture-derived
# SG evidence differs. Keep unresolved rather than forcing a lineage decision.
conflict_classes <- c(
  "GEOMETRIC_CONTINUITY_BUT_DIFFERENT_STRONG_SG_EVIDENCE"
)

# Geometry alone is informative but not enough to merge territory identity.
weak_continuity_classes <- c(
  "GEOMETRIC_CONTINUITY_ONLY",
  "SUBSTANTIAL_OVERLAP_NOT_RECIPROCAL_BEST",
  "LOWER_GEOMETRIC_CONTINUITY"
)

draw_lineage <- draws %>%
  left_join(
    lineage %>%
      select(
        year_from, year_to,
        origin_territory_key,
        destination_territory_key,
        jaccard,
        n_shared_setts,
        sett_jaccard,
        origin_dominant_SG,
        origin_dominant_SG_share,
        destination_dominant_SG,
        destination_dominant_SG_share,
        lineage_evidence_class
      ),
    by = c(
      "year_from",
      "year_to",
      "territory_key_origin" = "origin_territory_key",
      "territory_key_destination" = "destination_territory_key"
    ),
    relationship = "many-to-one"
  ) %>%
  mutate(
    same_raw_key =
      !is.na(territory_key_origin) &
      !is.na(territory_key_destination) &
      territory_key_origin == territory_key_destination,

    # Same formatted key is continuity even if the polygons do not spatially
    # overlap enough to appear in the crosswalk; raw names are still retained.
    supported_same_lineage =
      all_four_unambiguous &
      (
        same_raw_key |
        lineage_evidence_class %in% supported_continuity_classes
      ),

    lineage_evidence_conflict =
      all_four_unambiguous &
      lineage_evidence_class %in% conflict_classes,

    weak_or_reconfiguration_evidence =
      all_four_unambiguous &
      lineage_evidence_class %in% weak_continuity_classes,

    # If two unambiguous endpoint territories have different labels and there
    # is NO consecutive-year polygon-overlap relation between them, there is no
    # evidence that they are the same territory lineage. This is the strongest
    # geometric evidence for a lineage switch, but remains distinct from
    # capture-derived resident-SG change.
    no_direct_continuity_edge =
      all_four_unambiguous &
      !same_raw_key &
      is.na(lineage_evidence_class),

    likely_lineage_switch =
      all_four_unambiguous &
      !supported_same_lineage &
      no_direct_continuity_edge,

    lineage_draw_class = case_when(
      polygon_ambiguous ~
        "POLYGON_ASSIGNMENT_AMBIGUOUS",

      supported_same_lineage & same_raw_key ~
        "SUPPORTED_SAME_LINEAGE_SAME_LABEL",

      supported_same_lineage & !same_raw_key ~
        "SUPPORTED_SAME_LINEAGE_DIFFERENT_LABEL",

      lineage_evidence_conflict ~
        "CONFLICT_GEOMETRY_VS_STRONG_SG_EVIDENCE",

      likely_lineage_switch ~
        "LIKELY_LINEAGE_SWITCH_NO_CONTINUITY_EDGE",

      weak_or_reconfiguration_evidence ~
        "UNRESOLVED_RECONFIGURATION",

      TRUE ~
        "UNRESOLVED_LINEAGE"
    )
  )

write_csv(
  draw_lineage,
  file.path(LINEAGE_DIR, "06_posterior_lineage_transition_draws.csv")
)

summary <- draw_lineage %>%
  group_by(individual_id, tattoo, year_from, year_to) %>%
  summarise(
    n_draws = n(),
    p_supported_same_lineage = mean(supported_same_lineage),
    p_same_lineage_different_label =
      mean(supported_same_lineage & !same_raw_key),
    p_likely_lineage_switch = mean(likely_lineage_switch),
    p_lineage_evidence_conflict = mean(lineage_evidence_conflict),
    p_unresolved_reconfiguration = mean(weak_or_reconfiguration_evidence),
    p_lineage_polygon_ambiguous = mean(polygon_ambiguous),
    p_raw_stable_boundary_cross = mean(strict_stable_boundary_cross),
    p_raw_boundary_change_only = mean(boundary_change_only),
    .groups = "drop"
  ) %>%
  mutate(
    lineage_summary_class = case_when(
      p_lineage_polygon_ambiguous >= 0.5 ~
        "POLYGON_ASSIGNMENT_AMBIGUOUS",

      p_supported_same_lineage >= 0.5 ~
        "SUPPORTED_SAME_TERRITORY_LINEAGE",

      p_likely_lineage_switch >= 0.5 ~
        "LIKELY_TERRITORY_LINEAGE_SWITCH",

      p_lineage_evidence_conflict >= 0.5 ~
        "CONFLICTING_LINEAGE_EVIDENCE",

      p_unresolved_reconfiguration >= 0.5 ~
        "UNRESOLVED_TERRITORY_RECONFIGURATION",

      TRUE ~
        "POSTERIOR_LINEAGE_UNCERTAIN"
    )
  )

write_csv(
  summary,
  file.path(LINEAGE_DIR, "07_lineage_transition_summary.csv")
)

master_lineage <- master %>%
  left_join(
    summary,
    by = c("individual_id","tattoo","year_from","year_to"),
    relationship = "one-to-one"
  ) %>%
  mutate(
    # Biological descriptive combinations. These remain separate from the
    # capture-derived resident_group_change field.
    relocation_lineage_class = case_when(
      p_relocation_50 >= 0.5 &
        lineage_summary_class == "LIKELY_TERRITORY_LINEAGE_SWITCH" ~
        "GEOGRAPHIC_RELOCATION_WITH_LIKELY_LINEAGE_SWITCH",

      p_relocation_50 >= 0.5 &
        lineage_summary_class == "SUPPORTED_SAME_TERRITORY_LINEAGE" ~
        "GEOGRAPHIC_RELOCATION_WITHIN_SUPPORTED_TERRITORY_LINEAGE",

      p_relocation_50 >= 0.5 ~
        "GEOGRAPHIC_RELOCATION_LINEAGE_UNCERTAIN",

      p_relocation_50 < 0.5 &
        lineage_summary_class == "LIKELY_TERRITORY_LINEAGE_SWITCH" ~
        "LIKELY_LINEAGE_SWITCH_WITHOUT_CENTRAL_RELOCATION",

      p_relocation_50 < 0.5 &
        lineage_summary_class == "SUPPORTED_SAME_TERRITORY_LINEAGE" ~
        "NO_CENTRAL_RELOCATION_SUPPORTED_SAME_LINEAGE",

      TRUE ~
        "NO_CENTRAL_RELOCATION_LINEAGE_UNCERTAIN"
    )
  )

write_csv(
  master_lineage,
  file.path(LINEAGE_DIR, "08_master_movement_social_lineage_table.csv")
)

class_summary <- master_lineage %>%
  count(
    relocation_lineage_class,
    resident_group_change,
    name = "n_intervals"
  ) %>%
  group_by(relocation_lineage_class) %>%
  mutate(
    within_class_proportion = n_intervals / sum(n_intervals)
  ) %>%
  ungroup() %>%
  arrange(relocation_lineage_class, desc(n_intervals))

write_csv(
  class_summary,
  file.path(LINEAGE_DIR, "09_lineage_transition_class_summary.csv")
)

cat("Intervals:", nrow(summary), "\n\n")

cat("Lineage-aware interval classes:\n")
print(
  summary %>%
    count(lineage_summary_class, name = "n_intervals") %>%
    mutate(proportion = n_intervals / sum(n_intervals)) %>%
    arrange(desc(n_intervals)),
  n = Inf,
  width = Inf
)

cat("\nMovement x lineage classes:\n")
print(
  master_lineage %>%
    count(relocation_lineage_class, name = "n_intervals") %>%
    mutate(proportion = n_intervals / sum(n_intervals)) %>%
    arrange(desc(n_intervals)),
  n = Inf,
  width = Inf
)

cat("\nMovement x lineage x resident-SG evidence:\n")
print(class_summary, n = Inf, width = Inf)

cat("\nSaved lineage-aware transition outputs in: ", LINEAGE_DIR, "\n", sep="")
cat("NO raw territory names or social-group identities were modified.\n")
