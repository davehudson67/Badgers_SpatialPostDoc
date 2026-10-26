#!/usr/bin/env Rscript
# =============================================================================
# WOODCHESTER - INTEGRATED BEHAVIOURAL PATHWAYS BEFORE V12
#
# PURPOSE
# Combine the frozen V11R2 geographic movement engine with:
#   - lineage-aware annual territory transitions;
#   - capture-derived annual resident social groups;
#   - observed temporary extra-group use / prospecting.
#
# This is DESCRIPTIVE PATHWAY CLASSIFICATION, not another latent-state model.
#
# Two complementary outputs are retained:
#
# 1. PRIMARY ANNUAL PATHWAY
#    What happened between annual states y -> y+1?
#
# 2. PROSPECTING SEQUENCE
#    What temporary extra-group behaviour was observed within focal year y,
#    and what happened to strict resident-group assignment in y+1?
#
# Keeping these separate allows sequences such as:
#     A resident -> A-B-A prospecting -> later relocation/settlement in B
# without forcing prospecting and annual dispersal into one categorical state.
#
# IMPORTANT
# - p_relocation_50 remains the central geographic movement posterior.
# - 25 m sensitivity / relocation_robustness is carried forward.
# - territory-lineage evidence is independent of capture-derived resident SG.
# - no polygon name, sett name or SG identity is changed here.
# - a resident-SG change without geographic relocation is NOT automatically
#   called dispersal.
#
# INPUTS
#   outputs/V11R2_dynamic_social_group_overlay/lineage/
#     08_master_movement_social_lineage_table.csv
#   results/prospecting_pathway_badger_years.csv
#
# OUTPUTS
#   outputs/V11R2_dynamic_social_group_overlay/pathways/
#     01_interval_behavioural_pathways.csv
#     02_primary_annual_pathway_summary.csv
#     03_prospecting_sequence_summary.csv
#     04_primary_pathway_by_prospecting.csv
#     05_dispersal_evidence_stack.csv
#     06_pathway_movement_resolution_sensitivity.csv
#     07_prospecting_then_settlement_details.csv
#     behavioural_pathways.rds
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
OUT <- Sys.getenv(
  "PATHWAY_OUTPUT_DIR",
  unset = file.path(ROOT, "pathways")
)
MASTER_FILE <- Sys.getenv(
  "MASTER_LINEAGE_FILE",
  unset = file.path(LINEAGE_DIR, "08_master_movement_social_lineage_table.csv")
)
PROSPECTING_FILE <- Sys.getenv(
  "PROSPECTING_FILE",
  unset = "results/prospecting_pathway_badger_years.csv"
)

dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

for (p in c(MASTER_FILE, PROSPECTING_FILE)) {
  if (!file.exists(p)) stop("Missing required input: ", p)
}

cat("\n============================================================\n")
cat("INTEGRATED BEHAVIOURAL PATHWAYS BEFORE V12\n")
cat("============================================================\n\n")

master <- read_csv(MASTER_FILE, show_col_types = FALSE)
prospecting <- read_csv(PROSPECTING_FILE, show_col_types = FALSE)

need_master <- c(
  "individual_id","tattoo","year_from","year_to",
  "p_relocation_50","p_relocation_25","relocation_robustness",
  "lineage_summary_class","resident_group_change",
  "resident_group_from","resident_group_to"
)
if (!all(need_master %in% names(master))) {
  stop(
    "Master lineage table missing: ",
    paste(setdiff(need_master, names(master)), collapse = ", ")
  )
}

need_prospect <- c(
  "tattoo","focal_year",
  "baseline_group","focal_resident_group","future_group",
  "n_extra_capture_days","n_closed_prospecting_bouts",
  "closed_prospected_groups",
  "future_residency_available",
  "future_matches_any_extra_group",
  "future_matches_closed_prospected_group",
  "pure_single_target_prospecting",
  "single_target_group",
  "future_matches_single_target",
  "pathway"
)
if (!all(need_prospect %in% names(prospecting))) {
  stop(
    "Prospecting table missing: ",
    paste(setdiff(need_prospect, names(prospecting)), collapse = ", ")
  )
}

prospecting <- prospecting %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    focal_year = as.integer(focal_year),
    baseline_group = as.character(baseline_group),
    focal_resident_group = as.character(focal_resident_group),
    future_group = as.character(future_group),
    n_extra_capture_days = as.integer(n_extra_capture_days),
    n_closed_prospecting_bouts = as.integer(n_closed_prospecting_bouts),
    n_unclosed_outbound_bouts =
      if ("n_unclosed_outbound_bouts" %in% names(prospecting)) {
        as.integer(n_unclosed_outbound_bouts)
      } else {
        NA_integer_
      },
    closed_prospected_groups = as.character(closed_prospected_groups),
    future_residency_available = as.logical(future_residency_available),
    future_matches_any_extra_group = as.logical(future_matches_any_extra_group),
    future_matches_closed_prospected_group =
      as.logical(future_matches_closed_prospected_group),
    pure_single_target_prospecting = as.logical(pure_single_target_prospecting),
    single_target_group = as.character(single_target_group),
    future_matches_single_target = as.logical(future_matches_single_target),
    repeated_closed_prospecting_same_group =
      if ("repeated_closed_prospecting_same_group" %in% names(prospecting)) {
        as.logical(repeated_closed_prospecting_same_group)
      } else {
        NA
      },
    prospecting_pathway_original = as.character(pathway)
  )

dup <- prospecting %>%
  count(tattoo, focal_year) %>%
  filter(n > 1L)
if (nrow(dup)) {
  print(dup, n = Inf)
  stop("Prospecting table is not unique by tattoo + focal_year.")
}

master <- master %>%
  mutate(
    tattoo = toupper(trimws(as.character(tattoo))),
    year_from = as.integer(year_from),
    year_to = as.integer(year_to)
  )

if (anyDuplicated(master[c("tattoo","year_from","year_to")])) {
  stop("Master lineage table is not unique by tattoo + annual transition.")
}

# Prospecting in focal year y is aligned with the annual transition y -> y+1.
x <- master %>%
  left_join(
    prospecting,
    by = c("tattoo", "year_from" = "focal_year"),
    relationship = "many-to-one"
  ) %>%
  mutate(
    central_relocation = p_relocation_50 >= 0.5,
    sensitivity_relocation = p_relocation_25 >= 0.5,

    robust_relocation =
      relocation_robustness == "ROBUST_RELOCATION",
    robust_resident =
      relocation_robustness == "ROBUST_RESIDENT",
    movement_resolution_switch =
      relocation_robustness == "25_50_CLASSIFICATION_SWITCH",

    supported_same_lineage =
      lineage_summary_class == "SUPPORTED_SAME_TERRITORY_LINEAGE",
    likely_lineage_switch =
      lineage_summary_class == "LIKELY_TERRITORY_LINEAGE_SWITCH",
    lineage_conflict =
      lineage_summary_class == "CONFLICTING_LINEAGE_EVIDENCE",
    lineage_reconfiguration =
      lineage_summary_class == "UNRESOLVED_TERRITORY_RECONFIGURATION",
    lineage_posterior_uncertain =
      lineage_summary_class == "POSTERIOR_LINEAGE_UNCERTAIN",
    lineage_polygon_ambiguous =
      lineage_summary_class == "POLYGON_ASSIGNMENT_AMBIGUOUS",

    resident_SG_known = !is.na(resident_group_change),
    resident_SG_changed = resident_group_change %in% TRUE,
    resident_SG_same = resident_group_change %in% FALSE,

    any_observed_extra_group_use =
      !is.na(n_extra_capture_days) & n_extra_capture_days > 0L,
    closed_prospecting_observed =
      !is.na(n_closed_prospecting_bouts) &
      n_closed_prospecting_bouts > 0L
  )

# -----------------------------------------------------------------------------
# PRIMARY ANNUAL PATHWAY
# -----------------------------------------------------------------------------
# This classification deliberately uses the central V11R2-50 inference while
# retaining the 25/50 robustness flag as a separate evidential dimension.
#
# "SOCIAL_DISPERSAL_MULTI_EVIDENCE" is deliberately strict:
#   geographic relocation + likely territory-lineage switch +
#   capture-derived resident SG change.
#
# A resident-SG change without geographic relocation is kept as local social
# reorganisation/reassignment, not called dispersal.

x <- x %>%
  mutate(
    primary_annual_pathway = case_when(

      central_relocation &
        likely_lineage_switch &
        resident_SG_changed ~
        "SOCIAL_DISPERSAL_MULTI_EVIDENCE",

      central_relocation &
        likely_lineage_switch &
        !resident_SG_changed ~
        "GEOGRAPHIC_RELOCATION_WITH_LINEAGE_SWITCH_SG_NOT_CHANGED_OR_UNKNOWN",

      central_relocation &
        supported_same_lineage ~
        "GEOGRAPHIC_RELOCATION_WITHIN_SUPPORTED_TERRITORY_LINEAGE",

      central_relocation ~
        "GEOGRAPHIC_RELOCATION_SOCIAL_DESTINATION_UNRESOLVED",

      !central_relocation &
        supported_same_lineage &
        resident_SG_same ~
        "STABLE_LOCAL_RESIDENCY",

      !central_relocation &
        supported_same_lineage &
        resident_SG_changed ~
        "LOCAL_SOCIAL_REASSIGNMENT_WITHOUT_GEOGRAPHIC_RELOCATION",

      !central_relocation &
        supported_same_lineage &
        !resident_SG_known ~
        "LOCAL_RESIDENCY_RESIDENT_SG_UNKNOWN",

      TRUE ~
        "NO_GEOGRAPHIC_RELOCATION_SOCIAL_TERRITORY_UNRESOLVED"
    )
  )

# -----------------------------------------------------------------------------
# PROSPECTING / TEMPORARY EXTRA-GROUP SEQUENCE
# -----------------------------------------------------------------------------

x <- x %>%
  mutate(
    prospecting_sequence = case_when(
      is.na(prospecting_pathway_original) ~
        "NO_STRICT_PROSPECTING_WINDOW",

      prospecting_pathway_original ==
        "closed prospecting; later resident in prospected group" ~
        "CLOSED_PROSPECTING_THEN_SETTLEMENT_IN_VISITED_GROUP",

      prospecting_pathway_original ==
        "closed prospecting; remained baseline resident" ~
        "CLOSED_PROSPECTING_THEN_REMAINED_HOME",

      prospecting_pathway_original ==
        "closed prospecting; later moved to unvisited group" ~
        "CLOSED_PROSPECTING_THEN_SETTLEMENT_ELSEWHERE",

      prospecting_pathway_original ==
        "closed prospecting observed; future residency unavailable" ~
        "CLOSED_PROSPECTING_FUTURE_RESIDENCY_UNKNOWN",

      str_detect(
        coalesce(prospecting_pathway_original, ""),
        "unclosed|without observed return"
      ) ~
        "UNCLOSED_EXTRA_GROUP_USE",

      str_detect(
        coalesce(prospecting_pathway_original, ""),
        "no extra-group use|no observed extra-group use"
      ) ~
        "NO_OBSERVED_EXTRA_GROUP_USE",

      any_observed_extra_group_use ~
        "OTHER_EXTRA_GROUP_USE",

      TRUE ~
        "NO_OBSERVED_EXTRA_GROUP_USE"
    ),

    prospecting_before_visited_group_settlement =
      closed_prospecting_observed &
      future_matches_closed_prospected_group %in% TRUE,

    single_target_prospecting_before_target_settlement =
      pure_single_target_prospecting %in% TRUE &
      future_matches_single_target %in% TRUE
  )

# -----------------------------------------------------------------------------
# EVIDENCE STACK FOR SOCIAL DISPERSAL
# -----------------------------------------------------------------------------
# Do not collapse this into the primary pathway; keep the individual evidence
# streams visible for sensitivity and later V12 modelling.

x <- x %>%
  mutate(
    dispersal_evidence_stack = case_when(
      central_relocation &
        likely_lineage_switch &
        resident_SG_changed ~
        "RELOCATION+LINEAGE_SWITCH+RESIDENT_SG_CHANGE",

      central_relocation &
        resident_SG_changed ~
        "RELOCATION+RESIDENT_SG_CHANGE_LINEAGE_UNRESOLVED_OR_CONTINUOUS",

      central_relocation &
        likely_lineage_switch ~
        "RELOCATION+LINEAGE_SWITCH_NO_RESIDENT_SG_CHANGE",

      central_relocation &
        resident_SG_same ~
        "RELOCATION_ONLY_RESIDENT_SG_SAME",

      central_relocation ~
        "RELOCATION_ONLY_RESIDENT_SG_UNKNOWN",

      !central_relocation &
        resident_SG_changed ~
        "RESIDENT_SG_CHANGE_WITHOUT_GEOGRAPHIC_RELOCATION",

      !central_relocation &
        supported_same_lineage &
        resident_SG_same ~
        "NO_DISPERSAL_SIGNAL_STABLE_LOCAL",

      TRUE ~
        "NO_CENTRAL_RELOCATION_INCOMPLETE_SOCIAL_EVIDENCE"
    ),

    pathway_evidence_grade = case_when(
      primary_annual_pathway == "SOCIAL_DISPERSAL_MULTI_EVIDENCE" &
        robust_relocation ~
        "HIGH_CONCORDANT_AND_MOVEMENT_ROBUST",

      primary_annual_pathway == "SOCIAL_DISPERSAL_MULTI_EVIDENCE" &
        movement_resolution_switch ~
        "CONCORDANT_BUT_MOVEMENT_RESOLUTION_SENSITIVE",

      primary_annual_pathway == "SOCIAL_DISPERSAL_MULTI_EVIDENCE" ~
        "CONCORDANT",

      central_relocation & robust_relocation ~
        "GEOGRAPHIC_RELOCATION_ROBUST_SOCIAL_EVIDENCE_INCOMPLETE",

      central_relocation & movement_resolution_switch ~
        "GEOGRAPHIC_RELOCATION_RESOLUTION_SENSITIVE",

      robust_resident ~
        "NO_RELOCATION_ROBUST",

      TRUE ~
        "OTHER"
    )
  )

write_csv(
  x,
  file.path(OUT, "01_interval_behavioural_pathways.csv")
)

# -----------------------------------------------------------------------------
# SUMMARIES
# -----------------------------------------------------------------------------

primary_summary <- x %>%
  count(primary_annual_pathway, name = "n_intervals") %>%
  mutate(proportion = n_intervals / sum(n_intervals)) %>%
  arrange(desc(n_intervals))

prospecting_summary <- x %>%
  count(prospecting_sequence, name = "n_intervals") %>%
  mutate(proportion = n_intervals / sum(n_intervals)) %>%
  arrange(desc(n_intervals))

pathway_by_prospecting <- x %>%
  count(
    primary_annual_pathway,
    prospecting_sequence,
    name = "n_intervals"
  ) %>%
  group_by(primary_annual_pathway) %>%
  mutate(
    within_annual_pathway_proportion = n_intervals / sum(n_intervals)
  ) %>%
  ungroup() %>%
  arrange(primary_annual_pathway, desc(n_intervals))

evidence_summary <- x %>%
  count(dispersal_evidence_stack, name = "n_intervals") %>%
  mutate(proportion = n_intervals / sum(n_intervals)) %>%
  arrange(desc(n_intervals))

resolution_summary <- x %>%
  count(
    primary_annual_pathway,
    relocation_robustness,
    name = "n_intervals"
  ) %>%
  group_by(primary_annual_pathway) %>%
  mutate(
    within_pathway_proportion = n_intervals / sum(n_intervals)
  ) %>%
  ungroup() %>%
  arrange(primary_annual_pathway, desc(n_intervals))

prospecting_settlement_details <- x %>%
  filter(
    prospecting_before_visited_group_settlement |
    single_target_prospecting_before_target_settlement
  ) %>%
  select(
    individual_id, tattoo, year_from, year_to,
    baseline_group, focal_resident_group, future_group,
    closed_prospected_groups, single_target_group,
    n_closed_prospecting_bouts,
    p_relocation_50, p_relocation_25, relocation_robustness,
    lineage_summary_class,
    resident_group_from, resident_group_to, resident_group_change,
    primary_annual_pathway,
    prospecting_sequence,
    pathway_evidence_grade
  ) %>%
  arrange(year_from, tattoo)

write_csv(
  primary_summary,
  file.path(OUT, "02_primary_annual_pathway_summary.csv")
)
write_csv(
  prospecting_summary,
  file.path(OUT, "03_prospecting_sequence_summary.csv")
)
write_csv(
  pathway_by_prospecting,
  file.path(OUT, "04_primary_pathway_by_prospecting.csv")
)
write_csv(
  evidence_summary,
  file.path(OUT, "05_dispersal_evidence_stack.csv")
)
write_csv(
  resolution_summary,
  file.path(OUT, "06_pathway_movement_resolution_sensitivity.csv")
)
write_csv(
  prospecting_settlement_details,
  file.path(OUT, "07_prospecting_then_settlement_details.csv")
)

saveRDS(
  list(
    interval_pathways = x,
    primary_summary = primary_summary,
    prospecting_summary = prospecting_summary,
    pathway_by_prospecting = pathway_by_prospecting,
    evidence_summary = evidence_summary,
    resolution_summary = resolution_summary,
    prospecting_settlement_details = prospecting_settlement_details
  ),
  file.path(OUT, "behavioural_pathways.rds")
)

# -----------------------------------------------------------------------------
# CONSOLE REPORT
# -----------------------------------------------------------------------------

cat("Annual movement intervals:", nrow(x), "\n\n")

cat("PRIMARY ANNUAL BEHAVIOURAL PATHWAYS\n")
print(primary_summary, n = Inf, width = Inf)

cat("\nPROSPECTING / TEMPORARY EXTRA-GROUP SEQUENCES\n")
print(prospecting_summary, n = Inf, width = Inf)

cat("\nSOCIAL-DISPERSAL EVIDENCE STACK\n")
print(evidence_summary, n = Inf, width = Inf)

cat("\nMOVEMENT-RESOLUTION SUPPORT BY PRIMARY PATHWAY\n")
print(resolution_summary, n = Inf, width = Inf)

cat("\nProspecting -> visited-group settlement intervals:",
    nrow(prospecting_settlement_details), "\n")
cat(
  "  of which pure single-target prospecting -> same target:",
  sum(
    prospecting_settlement_details$single_target_group ==
      prospecting_settlement_details$future_group,
    na.rm = TRUE
  ),
  "\n"
)

if (nrow(prospecting_settlement_details)) {
  cat("\nProspecting -> settlement by annual movement pathway:\n")
  print(
    prospecting_settlement_details %>%
      count(primary_annual_pathway, name = "n_intervals") %>%
      arrange(desc(n_intervals)),
    n = Inf,
    width = Inf
  )
}

cat("\nSaved behavioural pathway outputs in: ", OUT, "\n", sep = "")
cat("No V11R2, territory, sett or SG identities were modified.\n")
