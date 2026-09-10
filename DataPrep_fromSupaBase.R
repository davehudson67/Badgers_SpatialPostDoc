# ==============================================================================
# DataPrep.R
# Canonical badger data preparation from PostgreSQL / Supabase
#
# SOURCE TABLES:
#   analysis.capture_history
#   analysis.diagnostic_results
#
# Database cleaning, Access conversion, lookup repair and historical location
# cleaning are handled upstream in PostgreSQL.
#
# This script performs ANALYTICAL preparation only:
#   - same-day biological encounter fusion
#   - PM-only filtering
#   - quarterly primary occasions
#   - modal sett / social group
#   - movement-aware quarterly collapse
#   - diagnostic aggregation
#   - final CMR-ready dataset
# ==============================================================================


# ==============================================================================
# 0. Packages + Database Connection Helper
# ==============================================================================

library(tidyverse)
library(stringr)
library(lubridate)
library(DBI)
library(RPostgres)
library(dbplyr)

source("scripts/BadgerDatabase.R")


# ==============================================================================
# 1. Load Canonical Database Views
# ==============================================================================

con <- badger_db_connect()

captures_db <- tbl(
  con,
  dbplyr::in_schema("analysis", "capture_history")
) %>%
  collect()

diagnostics_db <- tbl(
  con,
  dbplyr::in_schema("analysis", "diagnostic_results")
) %>%
  collect()

DBI::dbDisconnect(con)

cat("\n============================================================\n")
cat("DATABASE IMPORT\n")
cat("============================================================\n")
cat("Capture rows:", nrow(captures_db), "\n")
cat("Individuals:", n_distinct(captures_db$individual_id), "\n")
cat("Diagnostic rows:", nrow(diagnostics_db), "\n")
cat(
  "Capture date range:",
  as.character(min(captures_db$capture_date, na.rm = TRUE)),
  "to",
  as.character(max(captures_db$capture_date, na.rm = TRUE)),
  "\n"
)


# ==============================================================================
# 2. Helper Functions
# ==============================================================================

# Return first non-missing value while retaining the original data type
first_nonmissing <- function(x) {
  idx <- which(!is.na(x) & trimws(as.character(x)) != "")
  if (length(idx) == 0) return(x[NA_integer_][1])
  x[idx[1]]
}

# Return first non-missing text value
first_nonmissing_text <- function(x) {
  x <- as.character(x)
  idx <- which(!is.na(x) & trimws(x) != "")
  if (length(idx) == 0) return(NA_character_)
  x[idx[1]]
}

# Collapse location names to the compact historical format used by the
# existing modelling workflow:
#
# "PARK MILL"    -> "PARKMILL"
# "TOP SETT"     -> "TOP"
# "COLLIERS WOOD"-> "COLLIERSWOOD"
make_location_key <- function(x) {
  x %>%
    toupper() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all("\\s+", "") %>%
    na_if("")
}

# Modal character value
# Tie-breaking is deterministic because count tables are sorted alphabetically
# after descending frequency below.
get_mode_character <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) return(NA_character_)
  z <- sort(table(x), decreasing = TRUE)
  names(z)[1]
}


# ==============================================================================
# 3. Individual Traits
#
# Replaces the old tblBadger.csv import and cleaning.
# ==============================================================================

individuals <- captures_db %>%
  transmute(
    individual_id,
    tattoo = toupper(trimws(tattoo)),
    elect_tag,
    sex = str_to_title(trimws(sex)),
    age_fc = str_to_title(trimws(age_first_capture)),
    year_fc = year_first_capture,
    historical_names,
    n_historical_names
  ) %>%
  filter(!is.na(tattoo), tattoo != "") %>%
  distinct(individual_id, .keep_all = TRUE) %>%
  mutate(
    sex = case_when(
      sex %in% c("Male", "Female") ~ sex,
      TRUE ~ "Unknown"
    ),
    sex = factor(sex, levels = c("Female", "Male", "Unknown"))
  )

stopifnot(
  nrow(individuals) == n_distinct(captures_db$individual_id)
)


# ==============================================================================
# 4. Prepare Capture Records
#
# IMPORTANT LOCATION RULES
#
# sett:
#   derived ONLY from normalized_sett_name, i.e. locations recognised in the
#   database as genuine setts.
#
# socg:
#   derived from recorded_social_group_name because the capture-level recorded
#   social group is the authoritative historical observation.
#
# recorded_sett_name:
#   retained separately and NOT automatically treated as a valid sett.
# ==============================================================================

capture_records <- captures_db %>%
  transmute(
    capture_id,
    individual_id,
    tattoo = toupper(trimws(tattoo)),
    capture_date,
    
    pm_flag = is_pm,
    
    sett_id,
    sett_name = normalized_sett_name,
    
    recorded_social_group_id,
    socg_name = recorded_social_group_name,
    
    recorded_sett_name,
    recorded_supergroup_name,
    
    where = capture_location_text,
    os_ref,
    
    comment_raw = comment,
    pm_cause_raw = pm_cause,
    
    disease_status_id,
    disease_status,
    
    moc,
    
    weight,
    body_length,
    temperature,
    toothwear,
    neck_diameter,
    condition,
    reproductive_status,
    testes,
    
    primary_year = year(capture_date),
    trap_season = quarter(capture_date)
  ) %>%
  mutate(
    sett = make_location_key(sett_name),
    socg = make_location_key(socg_name)
  )


# ==============================================================================
# 5. Fuse Same-Day Records
#
# The relational database deliberately retains separate live and PM source
# records. For the CMR/model pipeline we reproduce the old biological rule:
#
#   one individual + one calendar date = one biological encounter
#
# Live records sort before PM records, allowing live location information to
# take priority where both exist on the same day.
# ==============================================================================

encounters <- capture_records %>%
  arrange(individual_id, capture_date, pm_flag) %>%
  group_by(individual_id, tattoo, capture_date) %>%
  summarise(
    primary_year = first(primary_year),
    trap_season = first(trap_season),
    
    has_live_capture = any(!pm_flag),
    has_pm_record = any(pm_flag),
    
    sett_id = first_nonmissing(sett_id),
    sett_name = first_nonmissing_text(sett_name),
    sett = first_nonmissing_text(sett),
    
    recorded_social_group_id = first_nonmissing(recorded_social_group_id),
    socg_name = first_nonmissing_text(socg_name),
    socg = first_nonmissing_text(socg),
    
    recorded_sett_name = first_nonmissing_text(recorded_sett_name),
    recorded_supergroup_name = first_nonmissing_text(recorded_supergroup_name),
    
    where = first_nonmissing_text(where),
    os_ref = first_nonmissing_text(os_ref),
    
    moc = first_nonmissing_text(moc),
    
    disease_status_id = first_nonmissing(disease_status_id),
    disease_status = first_nonmissing_text(disease_status),
    
    weight = first_nonmissing(weight),
    body_length = first_nonmissing(body_length),
    temperature = first_nonmissing(temperature),
    toothwear = first_nonmissing(toothwear),
    neck_diameter = first_nonmissing(neck_diameter),
    
    condition = first_nonmissing_text(condition),
    reproductive_status = first_nonmissing_text(reproductive_status),
    testes = first_nonmissing_text(testes),
    
    comment = {
      z <- unique(na.omit(c(
        as.character(comment_raw),
        as.character(pm_cause_raw)
      )))
      z <- z[trimws(z) != ""]
      if (length(z) == 0) NA_character_ else paste(z, collapse = " | ")
    },
    
    .groups = "drop"
  )


# ==============================================================================
# 6. Join Individual Traits
# ==============================================================================

encounters_all <- encounters %>%
  left_join(
    individuals %>%
      select(
        individual_id,
        sex,
        age_fc,
        year_fc,
        elect_tag,
        historical_names,
        n_historical_names
      ),
    by = "individual_id"
  ) %>%
  arrange(individual_id, capture_date)


# ==============================================================================
# 7. Same-Day Fusion Audit
# ==============================================================================

cat("\n============================================================\n")
cat("SAME-DAY ENCOUNTER FUSION\n")
cat("============================================================\n")

cat("Database capture rows:", nrow(capture_records), "\n")
cat("Biological same-day encounters:", nrow(encounters_all), "\n")
cat(
  "Rows fused:",
  nrow(capture_records) - nrow(encounters_all),
  "\n"
)

same_day_live_pm <- encounters_all %>%
  filter(has_live_capture & has_pm_record)

cat(
  "Same-day live + PM encounters:",
  nrow(same_day_live_pm),
  "\n"
)


# ==============================================================================
# 8. Remove PM-Only Individuals
#
# Same biological rule as the previous pipeline:
# individuals never captured alive are excluded from the CMR population.
# ==============================================================================

live_check <- encounters_all %>%
  group_by(individual_id, tattoo) %>%
  summarise(
    ever_live = any(has_live_capture),
    .groups = "drop"
  )

badgers_to_drop <- live_check %>%
  filter(!ever_live) %>%
  pull(individual_id)

encounters_useful <- encounters_all %>%
  filter(!(individual_id %in% badgers_to_drop))

cat("\n============================================================\n")
cat("CMR POPULATION FILTER\n")
cat("============================================================\n")

cat("PM-only individuals dropped:", length(badgers_to_drop), "\n")
cat(
  "Individuals retained:",
  n_distinct(encounters_useful$individual_id),
  "\n"
)


# ==============================================================================
# 9. Lifetime Modal Sett
#
# Only recognised/normalised setts contribute.
# ==============================================================================

modal_setts <- encounters_useful %>%
  filter(!is.na(sett)) %>%
  count(individual_id, sett, name = "n") %>%
  arrange(individual_id, desc(n), sett) %>%
  group_by(individual_id) %>%
  slice(1) %>%
  transmute(
    individual_id,
    modal_sett = sett
  ) %>%
  ungroup()


# ==============================================================================
# 10. Lifetime Modal Social Group
#
# Based on historical capture-level recorded SG.
# ==============================================================================

modal_social_groups <- encounters_useful %>%
  filter(!is.na(socg)) %>%
  count(individual_id, socg, name = "n") %>%
  arrange(individual_id, desc(n), socg) %>%
  group_by(individual_id) %>%
  slice(1) %>%
  transmute(
    individual_id,
    modal_socg = socg
  ) %>%
  ungroup()


# ==============================================================================
# 11. Add Modal Locations + Movement Flags
# ==============================================================================

encounters_useful <- encounters_useful %>%
  left_join(modal_setts, by = "individual_id") %>%
  left_join(modal_social_groups, by = "individual_id") %>%
  mutate(
    differs_from_modal =
      !is.na(sett) &
      !is.na(modal_sett) &
      sett != modal_sett,
    
    socg_differs_from_modal =
      !is.na(socg) &
      !is.na(modal_socg) &
      socg != modal_socg
  )


# ==============================================================================
# 12. Audit Multiple Locations Within Quarter
#
# These are important biological observations even though the CMR-ready dataset
# subsequently chooses one representative observation per primary occasion.
# ==============================================================================

quarter_location_audit <- encounters_useful %>%
  group_by(
    individual_id,
    tattoo,
    primary_year,
    trap_season
  ) %>%
  summarise(
    n_encounters = n(),
    n_setts = n_distinct(sett[!is.na(sett)]),
    n_socg = n_distinct(socg[!is.na(socg)]),
    
    multi_sett = n_setts > 1,
    multi_socg = n_socg > 1,
    
    .groups = "drop"
  )


# ==============================================================================
# 13. Collapse to One Record Per Quarter
#
# Priority for representative location/record:
#
#   1. PM/death record
#   2. sett differs from lifetime modal sett
#   3. latest capture date
#
# IMPORTANT:
# has_live_capture and has_pm_record in the final quarterly dataset describe
# whether ANY such record occurred during that quarter, not merely the
# representative source row selected below.
# ==============================================================================

encounters_cmr_ready <- encounters_useful %>%
  group_by(
    individual_id,
    primary_year,
    trap_season
  ) %>%
  
  # Preserve quarter-level biological information BEFORE selecting one row
  mutate(
    quarter_has_live_capture = any(has_live_capture),
    quarter_has_pm_record = any(has_pm_record)
  ) %>%
  
  arrange(
    desc(has_pm_record),
    desc(differs_from_modal),
    desc(capture_date),
    .by_group = TRUE
  ) %>%
  
  slice(1) %>%
  
  # After collapse these flags now refer to the whole primary occasion
  mutate(
    has_live_capture = quarter_has_live_capture,
    has_pm_record = quarter_has_pm_record
  ) %>%
  
  select(
    -quarter_has_live_capture,
    -quarter_has_pm_record
  ) %>%
  
  ungroup()

# ==============================================================================
# 14. Extract Observations Removed by Quarterly Collapse
# ==============================================================================

dropped_observations <- encounters_useful %>%
  anti_join(
    encounters_cmr_ready,
    by = c("individual_id", "capture_date")
  ) %>%
  arrange(individual_id, capture_date)

cat("\n============================================================\n")
cat("QUARTERLY COLLAPSE\n")
cat("============================================================\n")

cat("Biological encounters retained before collapse:", nrow(encounters_useful), "\n")
cat("Collapsed CMR records:", nrow(encounters_cmr_ready), "\n")
cat("Observations compressed away:", nrow(dropped_observations), "\n")

cat(
  "Individual-quarters with >1 recognised sett:",
  sum(quarter_location_audit$multi_sett, na.rm = TRUE),
  "\n"
)

cat(
  "Individual-quarters with >1 recorded social group:",
  sum(quarter_location_audit$multi_socg, na.rm = TRUE),
  "\n"
)


# ==============================================================================
# 15. Prepare Diagnostic Database
# ==============================================================================

diagnostics <- diagnostics_db %>%
  mutate(
    tattoo = toupper(trimws(tattoo)),
    primary_year = year(capture_date),
    trap_season = quarter(capture_date),
    
    result_upper = toupper(trimws(result)),
    result_code_upper = toupper(trimws(result_code))
  )


# ==============================================================================
# 16. Culture
#
# Preserve the previous analytical definition:
# M. BOVIS = culture positive.
# ==============================================================================

culture_clean <- diagnostics %>%
  filter(test_family == "Culture") %>%
  mutate(
    sample_type = toupper(trimws(sample_type)),
    is_pos = str_detect(
      result_upper,
      "M\\.BOVIS|M BOVIS"
    )
  ) %>%
  group_by(
    individual_id,
    tattoo,
    primary_year,
    trap_season
  ) %>%
  summarise(
    culture_tested = TRUE,
    culture_positive = any(is_pos, na.rm = TRUE),
    
    culture_samples = paste(
      sort(unique(na.omit(sample_type))),
      collapse = " | "
    ),
    
    .groups = "drop"
  )


# ==============================================================================
# 17. IFN-Gamma ELISA
#
# The historical 2919 -> 2019 typo is already corrected upstream in PostgreSQL.
# ==============================================================================

ifn_clean <- diagnostics %>%
  filter(test_family == "IFN-gamma ELISA") %>%
  mutate(
    is_pos = str_detect(
      result_upper,
      "POSITIVE"
    )
  ) %>%
  group_by(
    individual_id,
    tattoo,
    primary_year,
    trap_season
  ) %>%
  summarise(
    ifn_tested = TRUE,
    ifn_positive = any(is_pos, na.rm = TRUE),
    .groups = "drop"
  )


# ==============================================================================
# 18. DPP
#
# There is deliberately NO database-derived overall DPP result.
#
# Preserve the previous analytical rule:
# either visual line P or Px => DPP positive.
# ==============================================================================

dpp_clean <- diagnostics %>%
  filter(test_family == "DPP") %>%
  mutate(
    line1 = toupper(trimws(visual_line_1)),
    line2 = toupper(trimws(visual_line_2)),
    
    is_pos =
      line1 %in% c("P", "PX") |
      line2 %in% c("P", "PX")
  ) %>%
  group_by(
    individual_id,
    tattoo,
    primary_year,
    trap_season
  ) %>%
  summarise(
    dpp_tested = TRUE,
    dpp_positive = any(is_pos, na.rm = TRUE),
    .groups = "drop"
  )


# ==============================================================================
# 19. Stat-Pak + Brock
#
# Replaces historical all.diag.results.csv.
#
# VALIDATED CODES
#
# Stat-Pak:
#   N = Negative
#   P = Positive
#   C = No Clotted Sample
#
# Brock:
#   N    = Negative
#   P    = Positive
#   NULL = no recorded result
#
# We retain BOTH:
#   *_tested            = a source test record exists
#   *_result_available  = an interpretable N/P result exists
#
# This allows downstream models to distinguish an attempted/recorded test from
# an actual diagnostic observation.
# ==============================================================================

hist_diag_clean <- diagnostics %>%
  filter(test_family %in% c("Stat-Pak", "Brock")) %>%
  mutate(
    is_pos = case_when(
      test_family == "Stat-Pak" ~ result_code_upper == "P",
      test_family == "Brock" ~ result_upper == "P",
      TRUE ~ FALSE
    ),
    
    result_available = case_when(
      # C = no clotted sample, therefore not an interpretable N/P result
      test_family == "Stat-Pak" ~ result_code_upper %in% c("N", "P"),
      
      # Brock NULL rows have no interpretable result
      test_family == "Brock" ~ result_upper %in% c("N", "P"),
      
      TRUE ~ FALSE
    )
  ) %>%
  group_by(
    individual_id,
    tattoo,
    primary_year,
    trap_season
  ) %>%
  summarise(
    hist_test_record = TRUE,
    
    statpak_tested =
      any(test_family == "Stat-Pak"),
    
    statpak_result_available =
      any(
        test_family == "Stat-Pak" &
          result_available
      ),
    
    statpak_positive =
      any(
        test_family == "Stat-Pak" &
          is_pos,
        na.rm = TRUE
      ),
    
    brock_tested =
      any(test_family == "Brock"),
    
    brock_result_available =
      any(
        test_family == "Brock" &
          result_available
      ),
    
    brock_positive =
      any(
        test_family == "Brock" &
          is_pos,
        na.rm = TRUE
      ),
    
    hist_result_available =
      any(result_available),
    
    hist_positive =
      any(is_pos, na.rm = TRUE),
    
    .groups = "drop"
  )


# ==============================================================================
# 20. Join Diagnostics to Quarterly CMR Dataset
# ==============================================================================

encounters_final_with_disease <- encounters_cmr_ready %>%
  left_join(
    culture_clean,
    by = c(
      "individual_id",
      "tattoo",
      "primary_year",
      "trap_season"
    )
  ) %>%
  left_join(
    ifn_clean,
    by = c(
      "individual_id",
      "tattoo",
      "primary_year",
      "trap_season"
    )
  ) %>%
  left_join(
    dpp_clean,
    by = c(
      "individual_id",
      "tattoo",
      "primary_year",
      "trap_season"
    )
  ) %>%
  left_join(
    hist_diag_clean,
    by = c(
      "individual_id",
      "tattoo",
      "primary_year",
      "trap_season"
    )
  ) %>%
  mutate(
    across(
      ends_with("_tested"),
      ~ replace_na(.x, FALSE)
    ),
    
    across(
      ends_with("_positive"),
      ~ replace_na(.x, FALSE)
    ),
    
    across(
      ends_with("_result_available"),
      ~ replace_na(.x, FALSE)
    ),
    
    hist_test_record =
      replace_na(hist_test_record, FALSE),
    
    # ----------------------------------------------------------
    # Compatibility-style flag:
    # Was there a disease-test record in this quarter?
    # ----------------------------------------------------------
    
    tested_this_season =
      culture_tested |
      ifn_tested |
      dpp_tested |
      statpak_tested |
      brock_tested,
    
    # ----------------------------------------------------------
    # Did any diagnostic assay return a positive result?
    # ----------------------------------------------------------
    
    any_positive_test =
      culture_positive |
      ifn_positive |
      dpp_positive |
      statpak_positive |
      brock_positive,
    
    # ----------------------------------------------------------
    # For Stat-Pak/Brock specifically:
    # did we have an interpretable N/P observation?
    # ----------------------------------------------------------
    
    hist_result_available =
      replace_na(hist_result_available, FALSE)
  )


# ==============================================================================
# 21. Diagnostic Audits
# ==============================================================================

cat("\n============================================================\n")
cat("FINAL DISEASE AUDIT\n")
cat("============================================================\n")

cat(
  "Total CMR records:",
  nrow(encounters_final_with_disease),
  "\n"
)

cat(
  "Records with ANY disease-test record:",
  sum(encounters_final_with_disease$tested_this_season),
  "\n"
)

cat(
  "Records with ANY positive diagnostic test:",
  sum(encounters_final_with_disease$any_positive_test),
  "\n\n"
)

diagnostic_summary <- encounters_final_with_disease %>%
  summarise(
    Culture_Tested = sum(culture_tested),
    Culture_Pos = sum(culture_positive),
    
    IFN_Tested = sum(ifn_tested),
    IFN_Pos = sum(ifn_positive),
    
    DPP_Tested = sum(dpp_tested),
    DPP_Pos = sum(dpp_positive),
    
    StatPak_Tested = sum(statpak_tested),
    StatPak_Result = sum(statpak_result_available),
    StatPak_Pos = sum(statpak_positive),
    
    Brock_Tested = sum(brock_tested),
    Brock_Result = sum(brock_result_available),
    Brock_Pos = sum(brock_positive),
    
    Historical_Result = sum(hist_result_available),
    Historical_Pos = sum(hist_positive)
  )

print(diagnostic_summary)


# ==============================================================================
# 22. Additional Individual-Level Summary
# ==============================================================================

individual_summary <- encounters_final_with_disease %>%
  group_by(
    individual_id,
    tattoo
  ) %>%
  summarise(
    sex = first(sex),
    age_fc = first(age_fc),
    year_fc = first(year_fc),
    
    first_encounter = min(capture_date),
    last_encounter = max(capture_date),
    
    first_live_capture = if (
      any(has_live_capture)
    ) {
      min(capture_date[has_live_capture])
    } else {
      as.Date(NA)
    },
    
    last_live_capture = if (
      any(has_live_capture)
    ) {
      max(capture_date[has_live_capture])
    } else {
      as.Date(NA)
    },
    
    has_pm = any(has_pm_record),
    
    first_pm_date = if (
      any(has_pm_record)
    ) {
      min(capture_date[has_pm_record])
    } else {
      as.Date(NA)
    },
    
    n_primary_occasions = n(),
    
    modal_sett = first(modal_sett),
    modal_socg = first(modal_socg),
    
    ever_disease_tested =
      any(tested_this_season),
    
    ever_positive =
      any(any_positive_test),
    
    .groups = "drop"
  )


# ==============================================================================
# 23. Final Structural QC
# ==============================================================================

cat("\n============================================================\n")
cat("FINAL DATA-PREP QC\n")
cat("============================================================\n")

cat(
  "Database capture rows:",
  nrow(captures_db),
  "\n"
)

cat(
  "Database individuals:",
  n_distinct(captures_db$individual_id),
  "\n"
)

cat(
  "Same-day biological encounters:",
  nrow(encounters_all),
  "\n"
)

cat(
  "PM-only individuals dropped:",
  length(badgers_to_drop),
  "\n"
)

cat(
  "Individuals retained for CMR:",
  n_distinct(encounters_cmr_ready$individual_id),
  "\n"
)

cat(
  "Quarterly CMR records:",
  nrow(encounters_cmr_ready),
  "\n"
)

cat(
  "Unique individual-quarter combinations:",
  n_distinct(
    paste(
      encounters_cmr_ready$individual_id,
      encounters_cmr_ready$primary_year,
      encounters_cmr_ready$trap_season,
      sep = "_"
    )
  ),
  "\n"
)

cat(
  "CMR records with recognised sett:",
  sum(!is.na(encounters_cmr_ready$sett)),
  "\n"
)

cat(
  "CMR records with recorded social group:",
  sum(!is.na(encounters_cmr_ready$socg)),
  "\n"
)

cat(
  "Individuals with modal sett:",
  sum(!is.na(individual_summary$modal_sett)),
  "\n"
)

cat(
  "Individuals with modal social group:",
  sum(!is.na(individual_summary$modal_socg)),
  "\n"
)

cat(
  "Individual-quarters with multiple setts before collapse:",
  sum(quarter_location_audit$multi_sett, na.rm = TRUE),
  "\n"
)

cat(
  "Individual-quarters with multiple SGs before collapse:",
  sum(quarter_location_audit$multi_socg, na.rm = TRUE),
  "\n"
)

cat("============================================================\n")


# ==============================================================================
# 24. Critical Assertions
# ==============================================================================

# The quarterly model dataset must have exactly one row per
# individual / year / quarter.

quarter_duplicates <- encounters_cmr_ready %>%
  count(
    individual_id,
    primary_year,
    trap_season
  ) %>%
  filter(n > 1)

stopifnot(
  nrow(quarter_duplicates) == 0
)

# Every retained individual must genuinely have had at least one live capture.

retained_live_check <- encounters_cmr_ready %>%
  group_by(individual_id) %>%
  summarise(
    ever_live = any(has_live_capture),
    .groups = "drop"
  )

stopifnot(
  all(retained_live_check$ever_live)
)


# ==============================================================================
# 25. Save Reproducible Analysis Snapshots
#
# PostgreSQL remains the canonical source.
# These RDS files are model-input snapshots only.
# ==============================================================================

saveRDS(
  encounters_final_with_disease,
  "data/badger_final_CMRready_wDisease.rds"
)

# ==============================================================================
# Save analysis objects
# ==============================================================================

dir.create("data", showWarnings = FALSE)

saveRDS(
  encounters_final_with_disease,
  "data/badger_final_CMRready_wDisease.rds"
)

saveRDS(
  encounters_cmr_ready,
  "data/badger_CMRready.rds"
)

saveRDS(
  encounters_useful,
  "data/badger_encounters_useful.rds"
)

saveRDS(
  individuals,
  "data/badger_individuals.rds"
)

saveRDS(
  quarter_location_audit,
  "data/badger_quarter_location_audit.rds"
)
