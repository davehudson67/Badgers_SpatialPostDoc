# =============================================================================
# WOODCHESTER - HISTORICAL SOCG PROVENANCE AUDIT
#
# PURPOSE
# Determine empirically what the legacy capture-level SOCG field behaves like:
#
#   A) contemporaneous social group associated with capture location/sett; or
#   B) annual/individual resident social-group membership.
#
# This audit does NOT assume either interpretation in advance.
#
# KEY DIAGNOSTICS
# 1. How pure is SOCG within sett-year and sett-quarter combinations?
# 2. Can SOCG change while the sett remains the same?
# 3. When sett changes, how often does SOCG change?
# 4. VISITOR TEST:
#    for a badger whose Vicente-style annual resident group differs from the
#    SOCG overwhelmingly recorded for OTHER badgers at that sett-year, does the
#    focal badger's capture SOCG follow:
#       - the sett-year group (supports capture-location interpretation), or
#       - its annual resident group (supports membership interpretation)?
# 5. Do dominant sett->SOCG relationships change coherently through time?
#
# IMPORTANT
# The annual resident-group product itself is derived from capture SOCG and is
# therefore not independent evidence. The visitor test reduces circularity by
# defining the sett-year group from OTHER badgers only.
#
# INPUTS
#   data/badger_encounters_useful.rds
#   results/V7_population_inclusion_audit.rds
#   results/annual_resident_social_group_vicente.csv
#
# OUTPUTS
#   results/SOCG_audit_sett_year.csv
#   results/SOCG_audit_sett_quarter.csv
#   results/SOCG_audit_badger_year.csv
#   results/SOCG_audit_visitor_test.csv
#   results/SOCG_audit_sett_year_changes.csv
#   results/SOCG_audit_consecutive_capture_transitions.csv
#   results/SOCG_audit_summary.csv
# =============================================================================

library(tidyverse)
library(lubridate)

encounter_file <- "data/badger_encounters_useful.rds"
population_file <- "results/V7_population_inclusion_audit.rds"
resident_file <- "results/annual_resident_social_group_vicente.csv"

required <- c(encounter_file, population_file, resident_file)
missing <- required[!file.exists(required)]
if (length(missing)) {
  stop("Missing required file(s):\n", paste(missing, collapse = "\n"))
}

enc <- readRDS(encounter_file)
pop_obj <- readRDS(population_file)
resident <- read_csv(resident_file, show_col_types = FALSE)

dir.create("results", showWarnings = FALSE, recursive = TRUE)
dir.create("logs", showWarnings = FALSE, recursive = TRUE)

find_first_col <- function(nms, candidates) {
  z <- candidates[candidates %in% nms]
  if (!length(z)) return(NA_character_)
  z[1]
}

group_col <- find_first_col(
  names(enc),
  c(
    "recorded_social_group_name",
    "socg",
    "social_group",
    "normalized_social_group_name"
  )
)

sett_col <- find_first_col(
  names(enc),
  c(
    "recorded_sett_name",
    "sett",
    "normalized_sett_name"
  )
)

if (is.na(group_col)) {
  stop("Could not identify capture-level social-group/SOCG field.")
}
if (is.na(sett_col)) {
  stop("Could not identify capture-level sett field.")
}

clean_group <- function(x) {
  z <- x %>%
    as.character() %>%
    toupper() %>%
    str_squish()

  z[z %in% c("", "NA", "N/A", "UNKNOWN", "UNK", "NOT KNOWN")] <- NA_character_

  # Explicit migration-QC cases known to be sett names rather than valid
  # social-group labels in the legacy SOCG field.
  z[z %in% c("CHESTNUT", "HOLLOW TREE")] <- NA_character_

  z
}

clean_sett <- function(x) {
  x %>%
    as.character() %>%
    toupper() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all("\\s+", "")
}

sett_aliases <- c(
  "CHESTNUT" = "CHESNUT",
  "JACKS" = "JACKSMIREY",
  "GRAVEL" = "GRAVELPIT",
  "BUCKHOLE" = "BUCKHOLT",
  "TOPSETT" = "TOP",
  "FOXCUB" = "FOX",
  "GULLEY" = "GULLY",
  "BLACKBERRY" = "BRAMBLE",
  "BOC" = "BOG",
  "CEDARBANK" = "CEDAR",
  "CLAYTRAP" = "CLAY",
  "CLIFF" = "CLIFFFACE",
  "DINGLEVALLEY" = "DINGLE"
)

clean_sett2 <- function(x) {
  z <- clean_sett(x)
  for (a in names(sett_aliases)) z[z == a] <- sett_aliases[[a]]
  z
}

eligible <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(tattoo = toupper(trimws(as.character(tattoo)))) %>%
  distinct()

resident <- resident %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    resident_group = clean_group(resident_group),
    resident_assignment_criterion = as.integer(assignment_criterion)
  )

cap <- enc %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    capture_date = as.Date(capture_date),
    has_live_capture = as.logical(has_live_capture),
    sett = clean_sett2(.data[[sett_col]]),
    socg = clean_group(.data[[group_col]])
  ) %>%
  filter(
    has_live_capture,
    tattoo %in% eligible$tattoo,
    !is.na(primary_year),
    primary_year <= 2025,
    !is.na(capture_date),
    !is.na(sett),
    sett != "",
    !is.na(socg)
  ) %>%
  left_join(resident, by = c("tattoo", "primary_year")) %>%
  arrange(tattoo, capture_date, sett, socg)

cat("\n============================================================\n")
cat("HISTORICAL SOCG PROVENANCE AUDIT\n")
cat("============================================================\n\n")
cat("Capture-level group field:", group_col, "\n")
cat("Capture-level sett field:", sett_col, "\n")
cat("Usable live captures with sett + SOCG:", format(nrow(cap), big.mark = ","), "\n")
cat("Badgers:", n_distinct(cap$tattoo), "\n")
cat("Years:", min(cap$primary_year), "-", max(cap$primary_year), "\n\n")

# -----------------------------------------------------------------------------
# 1. Sett-year purity
# -----------------------------------------------------------------------------

sett_year_counts <- cap %>%
  count(sett, primary_year, socg, name = "n_captures")

sett_year <- sett_year_counts %>%
  group_by(sett, primary_year) %>%
  arrange(desc(n_captures), socg, .by_group = TRUE) %>%
  summarise(
    dominant_socg = first(socg),
    dominant_n = first(n_captures),
    total_captures = sum(n_captures),
    n_groups = n(),
    socg_purity = dominant_n / total_captures,
    group_counts = paste0(socg, ":", n_captures, collapse = " | "),
    .groups = "drop"
  ) %>%
  rename(n_captures = total_captures) %>%
  left_join(
    cap %>%
      group_by(sett, primary_year) %>%
      summarise(n_badgers = n_distinct(tattoo), .groups = "drop"),
    by = c("sett", "primary_year")
  )

write_csv(sett_year, "results/SOCG_audit_sett_year.csv")


# Reusable historical sett-year -> social-group reference.
# Evidence is capture-derived and explicitly contemporaneous. It does not
# reconstruct an unobserved polygon or interpolate across missing years.
historical_sett_group <- sett_year %>%
  mutate(
    evidence_class = case_when(
      n_badgers >= 2L & n_captures >= 3L & socg_purity >= 0.95 ~ "strong",
      n_badgers >= 2L & n_captures >= 3L & socg_purity >= 0.80 ~ "moderate",
      TRUE ~ "limited"
    ),
    source = "capture_SOCG_dominant_sett_year",
    exact_observed_year = TRUE
  ) %>%
  select(
    sett,
    primary_year,
    historical_social_group = dominant_socg,
    socg_purity,
    n_badgers,
    n_captures,
    n_groups,
    evidence_class,
    source,
    exact_observed_year,
    group_counts
  )

write_csv(
  historical_sett_group,
  "results/historical_sett_social_group_reference.csv"
)

# -----------------------------------------------------------------------------
# 2. Sett-quarter purity
# -----------------------------------------------------------------------------

sett_quarter_counts <- cap %>%
  filter(trap_season %in% 1:4) %>%
  count(sett, primary_year, trap_season, socg, name = "n_captures")

sett_quarter <- sett_quarter_counts %>%
  group_by(sett, primary_year, trap_season) %>%
  arrange(desc(n_captures), socg, .by_group = TRUE) %>%
  summarise(
    dominant_socg = first(socg),
    dominant_n = first(n_captures),
    total_captures = sum(n_captures),
    n_groups = n(),
    socg_purity = dominant_n / total_captures,
    group_counts = paste0(socg, ":", n_captures, collapse = " | "),
    .groups = "drop"
  ) %>%
  rename(n_captures = total_captures) %>%
  left_join(
    cap %>%
      filter(trap_season %in% 1:4) %>%
      group_by(sett, primary_year, trap_season) %>%
      summarise(n_badgers = n_distinct(tattoo), .groups = "drop"),
    by = c("sett", "primary_year", "trap_season")
  )

write_csv(sett_quarter, "results/SOCG_audit_sett_quarter.csv")

# -----------------------------------------------------------------------------
# 3. Badger-year SOCG structure and relation to annual residency
# -----------------------------------------------------------------------------

badger_year <- cap %>%
  group_by(tattoo, primary_year) %>%
  summarise(
    resident_group = first(resident_group),
    resident_assignment_criterion = first(resident_assignment_criterion),
    n_captures = n(),
    n_setts = n_distinct(sett),
    n_socg = n_distinct(socg),
    prop_capture_socg_equals_resident = if_else(
      !is.na(resident_group),
      mean(socg == resident_group),
      NA_real_
    ),
    setts = paste(sort(unique(sett)), collapse = " | "),
    socgs = paste(sort(unique(socg)), collapse = " | "),
    .groups = "drop"
  )

write_csv(badger_year, "results/SOCG_audit_badger_year.csv")

# -----------------------------------------------------------------------------
# 4. Consecutive capture transition logic
# -----------------------------------------------------------------------------

trans <- cap %>%
  group_by(tattoo) %>%
  arrange(capture_date, sett, socg, .by_group = TRUE) %>%
  mutate(
    prev_date = lag(capture_date),
    prev_year = lag(primary_year),
    prev_sett = lag(sett),
    prev_socg = lag(socg),
    same_year = primary_year == prev_year,
    sett_changed = !is.na(prev_sett) & sett != prev_sett,
    socg_changed = !is.na(prev_socg) & socg != prev_socg,
    days_between = as.integer(capture_date - prev_date)
  ) %>%
  filter(!is.na(prev_date), days_between >= 0L) %>%
  ungroup()

write_csv(
  trans,
  "results/SOCG_audit_consecutive_capture_transitions.csv"
)

# -----------------------------------------------------------------------------
# 5. Visitor test using OTHER badgers to define the sett-year group
# -----------------------------------------------------------------------------
#
# For each focal badger-sett-year, remove all captures of that badger from the
# sett-year group counts, then determine the dominant SOCG among OTHER badgers.
# This avoids defining the focal badger's capture-location group using its own
# SOCG records.

total_syg <- cap %>%
  count(sett, primary_year, socg, name = "n_all_group")

focal_syg <- cap %>%
  count(tattoo, sett, primary_year, socg, name = "n_focal_group")

focal_totals <- cap %>%
  group_by(tattoo, sett, primary_year) %>%
  summarise(
    n_focal_captures = n(),
    n_focal_socg = n_distinct(socg),
    focal_socg_mode = {
      tt <- sort(table(socg), decreasing = TRUE)
      names(tt)[1]
    },
    focal_socg_mode_purity = {
      tt <- sort(table(socg), decreasing = TRUE)
      as.numeric(tt[1] / sum(tt))
    },
    resident_group = first(resident_group),
    resident_assignment_criterion = first(resident_assignment_criterion),
    .groups = "drop"
  )

# Number of OTHER badgers available at the sett-year.
other_badger_n <- cap %>%
  distinct(tattoo, sett, primary_year) %>%
  count(sett, primary_year, name = "n_badgers_all") %>%
  right_join(
    focal_totals %>% select(tattoo, sett, primary_year),
    by = c("sett", "primary_year")
  ) %>%
  mutate(n_other_badgers = n_badgers_all - 1L)

visitor_grid <- focal_totals %>%
  select(tattoo, sett, primary_year) %>%
  inner_join(total_syg, by = c("sett", "primary_year"), relationship = "many-to-many") %>%
  left_join(
    focal_syg,
    by = c("tattoo", "sett", "primary_year", "socg"),
    relationship = "many-to-one"
  ) %>%
  mutate(
    n_focal_group = replace_na(n_focal_group, 0L),
    n_other_group = n_all_group - n_focal_group
  ) %>%
  group_by(tattoo, sett, primary_year) %>%
  filter(sum(n_other_group) > 0L) %>%
  arrange(desc(n_other_group), socg, .by_group = TRUE) %>%
  summarise(
    n_other_captures = sum(n_other_group),
    other_sett_year_socg = first(socg),
    other_sett_year_socg_n = first(n_other_group),
    other_sett_year_purity = other_sett_year_socg_n / n_other_captures,
    other_group_counts = paste0(socg, ":", n_other_group, collapse = " | "),
    .groups = "drop"
  ) %>%
  left_join(
    other_badger_n,
    by = c("tattoo", "sett", "primary_year")
  ) %>%
  left_join(
    focal_totals,
    by = c("tattoo", "sett", "primary_year")
  ) %>%
  mutate(
    is_visitor_case =
      !is.na(resident_group) &
      resident_group != other_sett_year_socg &
      n_other_badgers >= 2L &
      n_other_captures >= 3L &
      other_sett_year_purity >= 0.80,

    focal_follows_sett_year =
      focal_socg_mode == other_sett_year_socg,

    focal_follows_resident =
      !is.na(resident_group) &
      focal_socg_mode == resident_group,

    visitor_outcome = case_when(
      !is_visitor_case ~ "not visitor-test eligible",
      focal_follows_sett_year & !focal_follows_resident ~
        "SOCG follows other-badger sett-year group",
      focal_follows_resident & !focal_follows_sett_year ~
        "SOCG follows annual resident group",
      focal_follows_sett_year & focal_follows_resident ~
        "both (unexpected in visitor case)",
      TRUE ~ "SOCG follows neither"
    )
  )

write_csv(
  visitor_grid,
  "results/SOCG_audit_visitor_test.csv"
)

# -----------------------------------------------------------------------------
# 6. Historical changes in dominant sett-year SOCG
# -----------------------------------------------------------------------------

sett_year_changes <- sett_year %>%
  filter(n_badgers >= 2L, socg_purity >= 0.80) %>%
  arrange(sett, primary_year) %>%
  group_by(sett) %>%
  mutate(
    previous_year = lag(primary_year),
    previous_socg = lag(dominant_socg),
    year_gap = primary_year - previous_year,
    dominant_socg_changed =
      !is.na(previous_socg) &
      dominant_socg != previous_socg
  ) %>%
  ungroup()

write_csv(
  sett_year_changes,
  "results/SOCG_audit_sett_year_changes.csv"
)

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

eligible_sy <- sett_year %>% filter(n_badgers >= 2L, n_captures >= 3L)
eligible_sq <- sett_quarter %>% filter(n_badgers >= 2L, n_captures >= 3L)
visitor <- visitor_grid %>% filter(is_visitor_case)

same_year_trans <- trans %>% filter(same_year)

summary_tbl <- tibble(
  metric = c(
    "usable_capture_n",
    "sett_year_n_ge2badgers_ge3captures",
    "sett_year_prop_purity_ge_0.80",
    "sett_year_prop_purity_ge_0.90",
    "sett_year_prop_purity_ge_0.95",
    "sett_year_prop_purity_eq_1",
    "sett_quarter_n_ge2badgers_ge3captures",
    "sett_quarter_prop_purity_ge_0.90",
    "same_year_consecutive_transition_n",
    "same_sett_socg_change_n",
    "same_sett_socg_change_prop",
    "different_sett_socg_change_n",
    "different_sett_socg_change_prop",
    "visitor_test_n",
    "visitor_follows_sett_year_n",
    "visitor_follows_sett_year_prop",
    "visitor_follows_resident_n",
    "visitor_follows_resident_prop",
    "high_purity_sett_year_socg_change_n"
  ),
  value = c(
    nrow(cap),
    nrow(eligible_sy),
    mean(eligible_sy$socg_purity >= .80),
    mean(eligible_sy$socg_purity >= .90),
    mean(eligible_sy$socg_purity >= .95),
    mean(eligible_sy$socg_purity == 1),
    nrow(eligible_sq),
    mean(eligible_sq$socg_purity >= .90),
    nrow(same_year_trans),
    sum(!same_year_trans$sett_changed & same_year_trans$socg_changed),
    mean(same_year_trans$socg_changed[!same_year_trans$sett_changed]),
    sum(same_year_trans$sett_changed & same_year_trans$socg_changed),
    mean(same_year_trans$socg_changed[same_year_trans$sett_changed]),
    nrow(visitor),
    sum(visitor$focal_follows_sett_year),
    if_else(nrow(visitor) > 0, mean(visitor$focal_follows_sett_year), NA_real_),
    sum(visitor$focal_follows_resident),
    if_else(nrow(visitor) > 0, mean(visitor$focal_follows_resident), NA_real_),
    sum(sett_year_changes$dominant_socg_changed, na.rm = TRUE)
  )
)

write_csv(summary_tbl, "results/SOCG_audit_summary.csv")

cat("SETT-YEAR SOCG PURITY\n")
cat("Eligible sett-years (>=2 badgers, >=3 captures):", nrow(eligible_sy), "\n")
cat("  >=80% pure:", round(100 * mean(eligible_sy$socg_purity >= .80), 2), "%\n")
cat("  >=90% pure:", round(100 * mean(eligible_sy$socg_purity >= .90), 2), "%\n")
cat("  >=95% pure:", round(100 * mean(eligible_sy$socg_purity >= .95), 2), "%\n")
cat("  100% pure:", round(100 * mean(eligible_sy$socg_purity == 1), 2), "%\n\n")

cat("SETT-QUARTER SOCG PURITY\n")
cat("Eligible sett-quarters (>=2 badgers, >=3 captures):", nrow(eligible_sq), "\n")
cat("  >=90% pure:", round(100 * mean(eligible_sq$socg_purity >= .90), 2), "%\n\n")

cat("CONSECUTIVE CAPTURE LOGIC (same calendar year)\n")
cat("Transitions:", nrow(same_year_trans), "\n")
cat(
  "SOCG changes while sett stays the same:",
  sum(!same_year_trans$sett_changed & same_year_trans$socg_changed),
  "of",
  sum(!same_year_trans$sett_changed),
  "(",
  round(100 * mean(same_year_trans$socg_changed[!same_year_trans$sett_changed]), 2),
  "%)\n"
)
cat(
  "SOCG changes when sett changes:",
  sum(same_year_trans$sett_changed & same_year_trans$socg_changed),
  "of",
  sum(same_year_trans$sett_changed),
  "(",
  round(100 * mean(same_year_trans$socg_changed[same_year_trans$sett_changed]), 2),
  "%)\n\n"
)

cat("VISITOR TEST\n")
cat(
  "Eligible focal badger-sett-years:",
  nrow(visitor),
  "\n"
)
if (nrow(visitor)) {
  cat(
    "  focal SOCG follows OTHER-badger sett-year group:",
    sum(visitor$focal_follows_sett_year),
    "(",
    round(100 * mean(visitor$focal_follows_sett_year), 2),
    "%)\n"
  )
  cat(
    "  focal SOCG follows annual resident group:",
    sum(visitor$focal_follows_resident),
    "(",
    round(100 * mean(visitor$focal_follows_resident), 2),
    "%)\n"
  )
  cat("\nVisitor outcomes:\n")
  print(visitor %>% count(visitor_outcome, sort = TRUE), n = Inf)
}

cat("\nHISTORICAL SETT->SOCG CHANGES\n")
cat(
  "High-purity sett-year dominant-group changes across observed years:",
  sum(sett_year_changes$dominant_socg_changed, na.rm = TRUE),
  "\n"
)

cat("\nTop examples of changing dominant sett SOCG:\n")
print(
  sett_year_changes %>%
    filter(dominant_socg_changed) %>%
    select(
      sett,
      previous_year,
      primary_year,
      previous_socg,
      dominant_socg,
      socg_purity,
      n_badgers,
      n_captures
    ) %>%
    arrange(sett, primary_year) %>%
    slice_head(n = 40),
  n = 40,
  width = Inf
)

cat("\nINTERPRETATION RULE\n")
cat(
  "Strong sett-year purity + rare same-sett SOCG changes + visitor SOCG ",
  "following the OTHER-badger sett-year group supports SOCG as a ",
  "contemporaneous capture-location/social-group field.\n"
)
cat(
  "Visitor SOCG following annual resident group instead would support SOCG ",
  "as individual membership/residency. Mixed results imply mixed/curated ",
  "usage and require caution or year-specific source reconstruction.\n"
)

cat("\nSaved SOCG provenance audit outputs in results/.\n")
