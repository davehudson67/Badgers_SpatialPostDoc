# =============================================================================
# WOODCHESTER - INTER-GROUP EXCURSION / RESIDENCY-CHANGE ANALYSIS
#
# PURPOSE
# Use the now-validated capture-level SOCG field to distinguish:
#   1. capture in annual resident group;
#   2. temporary observed use of another social group;
#   3. later annual resident-group change.
#
# PRE-SPECIFIED QUESTIONS
# E1. What predicts observed extra-group use within a trapping quarter?
# E2. Does observed extra-group use in year y predict annual resident-group
#     change in y+1, after accounting for capture opportunity?
# E3. When we directly observe resident -> other-group movement, how often is
#     the next observed capture back in the resident group?
#
# IMPORTANT
# Annual resident group is derived from the same capture SOCG history, so these
# are behavioural linkage analyses, not statistically independent validation.
#
# LOGIC SAFEGUARDS
# - The main E2 model is retained for comparability, but annual residency
#   criteria 2-5 can use adjacent-year information. A strict E2 sensitivity
#   therefore requires criterion-1 residency with >=2 grouped captures in both
#   y and y+1, removing cross-year assignment leakage and weak one-capture
#   residency assignments.
# - The original E3 sequence is explicitly descriptive because focal-year
#   annual residency is estimated from the same year's captures. E3B therefore
#   uses a PRIOR-YEAR, criterion-1, >=2-capture resident group as the baseline,
#   collapses captures to unambiguous capture-days, and follows the next
#   observed capture across calendar-year boundaries.
#
# OUTPUTS
#   results/behaviour_extra_group_captures.csv
#   results/behaviour_extra_group_quarters.csv
#   results/behaviour_extra_group_years.csv
#   results/behaviour_next_year_residency_change.csv
#   results/behaviour_observed_excursion_returns.csv
#   results/behaviour_extra_group_quarter_parametric.csv
#   results/behaviour_next_year_residency_change_parametric.csv
# =============================================================================

# Prevent nested BLAS/OpenMP + mgcv threading from oversubscribing large servers.
# bam() is parallelized explicitly below; BLAS should remain single-threaded.
Sys.setenv(
  OPENBLAS_NUM_THREADS = "1",
  OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  BLIS_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1"
)

BAM_THREADS <- as.integer(Sys.getenv("BAM_THREADS", unset = "4"))
if (!is.finite(BAM_THREADS) || BAM_THREADS < 1L) BAM_THREADS <- 4L
BAM_THREADS <- min(BAM_THREADS, 8L)

START_STAGE <- toupper(Sys.getenv("START_STAGE", unset = "E1"))
if (!START_STAGE %in% c("E1", "E2", "E3")) {
  stop("START_STAGE must be one of E1, E2, E3.")
}

library(tidyverse)
library(mgcv)

cat("bam worker threads:", BAM_THREADS, "\n")
cat("OPENBLAS_NUM_THREADS:", Sys.getenv("OPENBLAS_NUM_THREADS"), "\n")
cat("Starting model stage:", START_STAGE, "\n")

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
resident_raw <- read_csv(resident_file, show_col_types = FALSE)

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

if (is.na(group_col)) stop("Could not identify capture-level SOCG field.")

clean_group <- function(x) {
  z <- x %>%
    as.character() %>%
    toupper() %>%
    str_squish()

  z[z %in% c("", "NA", "N/A", "UNKNOWN", "UNK", "NOT KNOWN")] <- NA_character_
  z[z %in% c("CHESTNUT", "HOLLOW TREE")] <- NA_character_
  z
}

pop <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    sex = case_when(
      sex_class == "Female" ~ "Female",
      sex_class == "Male" ~ "Male",
      TRUE ~ NA_character_
    )
  )

age <- pop_obj$age_by_year %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    age_years = as.integer(age_years),
    age_class = case_when(
      is.na(age_years) ~ "Unknown",
      age_years <= 1L ~ "0-1",
      age_years == 2L ~ "2",
      age_years >= 3L & age_years <= 5L ~ "3-5",
      age_years >= 6L ~ "6+",
      TRUE ~ "Unknown"
    )
  )

resident <- resident_raw %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    resident_group = clean_group(resident_group),
    resident_assignment_criterion = as.integer(assignment_criterion),
    resident_n_grouped_captures = as.integer(n_grouped_captures),
    resident_n_distinct_groups = as.integer(n_distinct_groups_current)
  )

cap <- enc %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    capture_date = as.Date(capture_date),
    has_live_capture = as.logical(has_live_capture),
    capture_socg = clean_group(.data[[group_col]])
  ) %>%
  filter(
    has_live_capture,
    tattoo %in% pop$tattoo,
    !is.na(primary_year),
    primary_year <= 2025,
    !is.na(capture_date),
    !is.na(capture_socg)
  ) %>%
  left_join(pop, by = "tattoo") %>%
  left_join(age, by = c("tattoo", "primary_year")) %>%
  left_join(resident, by = c("tattoo", "primary_year")) %>%
  filter(!is.na(resident_group)) %>%
  arrange(tattoo, capture_date, capture_socg) %>%
  mutate(
    extra_group = capture_socg != resident_group
  )

write_csv(cap, "results/behaviour_extra_group_captures.csv")

cat("\n============================================================\n")
cat("INTER-GROUP EXCURSION / RESIDENCY-CHANGE ANALYSIS\n")
cat("============================================================\n\n")
cat("Usable captures with SOCG + annual resident group:", nrow(cap), "\n")
cat("Extra-group captures:", sum(cap$extra_group), "\n")
cat(
  "Extra-group capture proportion:",
  round(mean(cap$extra_group), 4), "\n\n"
)

# =============================================================================
# E1. QUARTER-LEVEL EXTRA-GROUP USE
# =============================================================================

quarter <- cap %>%
  filter(trap_season %in% 1:4) %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(
    sex = first(sex),
    age_class = first(age_class),
    resident_group = first(resident_group),
    resident_assignment_criterion = first(resident_assignment_criterion),
    resident_n_grouped_captures = first(resident_n_grouped_captures),
    resident_n_distinct_groups = first(resident_n_distinct_groups),
    n_captures = n(),
    n_extra_captures = sum(extra_group),
    any_extra_group = as.integer(any(extra_group)),
    prop_extra_group = mean(extra_group),
    n_capture_groups = n_distinct(capture_socg),
    n_extra_groups = n_distinct(capture_socg[extra_group]),
    .groups = "drop"
  ) %>%
  mutate(
    sex = factor(sex, levels = c("Female", "Male")),
    age_class = factor(
      coalesce(age_class, "Unknown"),
      levels = c("0-1", "2", "3-5", "6+", "Unknown")
    ),
    season = factor(trap_season),
    n_capture_factor = factor(pmin(n_captures, 4L)),
    year_factor = factor(primary_year),
    tattoo_factor = factor(tattoo)
  )

write_csv(quarter, "results/behaviour_extra_group_quarters.csv")

cat("E1: QUARTER-LEVEL EXTRA-GROUP USE\n")
cat("Observed quarters:", nrow(quarter), "\n")
cat("Quarters with >=1 extra-group capture:", sum(quarter$any_extra_group), "\n")
cat(
  "Quarter-level extra-group-use proportion:",
  round(mean(quarter$any_extra_group), 4), "\n"
)

if (START_STAGE == "E1") {
  fit_extra_q <- bam(
    any_extra_group ~
      sex +
      age_class +
      season +
      n_capture_factor +
      s(year_factor, bs = "re") +
      s(tattoo_factor, bs = "re"),
    data = quarter,
    family = binomial(link = "logit"),
    method = "fREML",
    discrete = TRUE,
    nthreads = BAM_THREADS
  )

  saveRDS(
    fit_extra_q,
    "results/behaviour_extra_group_quarter_model.rds"
  )

  print(summary(fit_extra_q))
  cat("\nVariance components:\n")
  print(gam.vcomp(fit_extra_q))

  write_csv(
    as.data.frame(summary(fit_extra_q)$p.table) %>%
      rownames_to_column("term") %>%
      as_tibble(),
    "results/behaviour_extra_group_quarter_parametric.csv"
  )
} else {
  cat("\nSkipping E1 model fit because START_STAGE =", START_STAGE, "\n")
  cat("Existing E1 outputs are retained.\n")
}

# =============================================================================
# YEAR-LEVEL EXTRA-GROUP USE
# =============================================================================

year_behaviour <- cap %>%
  group_by(tattoo, primary_year) %>%
  summarise(
    sex = first(sex),
    age_class = first(age_class),
    resident_group = first(resident_group),
    resident_assignment_criterion = first(resident_assignment_criterion),
    resident_n_grouped_captures = first(resident_n_grouped_captures),
    resident_n_distinct_groups = first(resident_n_distinct_groups),
    n_captures = n(),
    n_extra_captures = sum(extra_group),
    any_extra_group = as.integer(any(extra_group)),
    prop_extra_group = mean(extra_group),
    n_capture_groups = n_distinct(capture_socg),
    n_extra_groups = n_distinct(capture_socg[extra_group]),
    first_capture_group = first(capture_socg),
    last_capture_group = last(capture_socg),
    .groups = "drop"
  )

write_csv(year_behaviour, "results/behaviour_extra_group_years.csv")

# =============================================================================
# E2. DOES EXTRA-GROUP USE PRECEDE NEXT-YEAR RESIDENCY CHANGE?
# =============================================================================

next_resident <- resident %>%
  transmute(
    tattoo,
    next_year = primary_year,
    next_resident_group = resident_group,
    next_resident_assignment_criterion = resident_assignment_criterion,
    next_resident_n_grouped_captures = resident_n_grouped_captures,
    next_resident_n_distinct_groups = resident_n_distinct_groups
  )

next_year_dat <- year_behaviour %>%
  mutate(next_year = primary_year + 1L) %>%
  left_join(next_resident, by = c("tattoo", "next_year")) %>%
  filter(!is.na(next_resident_group)) %>%
  mutate(
    resident_change_next = as.integer(next_resident_group != resident_group),
    sex = factor(sex, levels = c("Female", "Male")),
    age_class = factor(
      coalesce(age_class, "Unknown"),
      levels = c("0-1", "2", "3-5", "6+", "Unknown")
    ),
    capture_effort = log1p(n_captures),
    year_factor = factor(primary_year),
    tattoo_factor = factor(tattoo)
  )

write_csv(
  next_year_dat,
  "results/behaviour_next_year_residency_change.csv"
)

cat("\n============================================================\n")
cat("E2: EXTRA-GROUP USE -> NEXT-YEAR RESIDENCY CHANGE\n")
cat("============================================================\n")
cat("Consecutive resident badger-years:", nrow(next_year_dat), "\n")
cat("Next-year resident-group changes:", sum(next_year_dat$resident_change_next), "\n")
cat(
  "Overall next-year residency-change proportion:",
  round(mean(next_year_dat$resident_change_next), 4), "\n"
)

raw_next <- next_year_dat %>%
  group_by(any_extra_group) %>%
  summarise(
    n = n(),
    changes = sum(resident_change_next),
    prop_change = mean(resident_change_next),
    .groups = "drop"
  )
print(raw_next, n = Inf)

if (START_STAGE %in% c("E1", "E2")) {
  fit_next <- bam(
    resident_change_next ~
      any_extra_group +
      sex +
      age_class +
      s(capture_effort, k = 5) +
      s(year_factor, bs = "re") +
      s(tattoo_factor, bs = "re"),
    data = next_year_dat,
    family = binomial(link = "logit"),
    method = "fREML",
    discrete = TRUE,
    nthreads = BAM_THREADS
  )

  saveRDS(
    fit_next,
    "results/behaviour_next_year_residency_change_model.rds"
  )

  print(summary(fit_next))
  cat("\nVariance components:\n")
  print(gam.vcomp(fit_next))

  write_csv(
    as.data.frame(summary(fit_next)$p.table) %>%
      rownames_to_column("term") %>%
      as_tibble(),
    "results/behaviour_next_year_residency_change_parametric.csv"
  )
} else {
  cat("\nSkipping E2 adjusted model fit because START_STAGE = E3.\n")
}


# -----------------------------------------------------------------------------
# E2S. STRICT RESIDENCY SENSITIVITY
# -----------------------------------------------------------------------------
# Criteria 2-5 in the annual resident-group reconstruction can use adjacent-year
# information. That is appropriate for reconstructing residency, but it creates
# possible information leakage when y residency is used to predict a y+1
# outcome. Restricting both years to criterion 1 removes that leakage.
#
# Requiring >=2 grouped captures in each year also removes resident assignments
# based on a single observed capture, which are too weak for a strong claim
# about annual relocation.

strict_next_year_dat <- next_year_dat %>%
  filter(
    resident_assignment_criterion == 1L,
    next_resident_assignment_criterion == 1L,
    resident_n_grouped_captures >= 2L,
    next_resident_n_grouped_captures >= 2L
  )

cat("\n------------------------------------------------------------\n")
cat("E2S: STRICT CRITERION-1 / >=2-CAPTURE SENSITIVITY\n")
cat("------------------------------------------------------------\n")
cat("Strict consecutive badger-years:", nrow(strict_next_year_dat), "\n")

if (nrow(strict_next_year_dat) > 0L) {
  strict_raw <- strict_next_year_dat %>%
    group_by(any_extra_group) %>%
    summarise(
      n = n(),
      changes = sum(resident_change_next),
      prop_change = mean(resident_change_next),
      .groups = "drop"
    )

  print(strict_raw, n = Inf)

  write_csv(
    strict_next_year_dat,
    "results/behaviour_next_year_residency_change_STRICT.csv"
  )
  write_csv(
    strict_raw,
    "results/behaviour_next_year_residency_change_STRICT_raw.csv"
  )
}

if (START_STAGE %in% c("E1", "E2") && nrow(strict_next_year_dat) > 0L) {
  fit_next_strict <- bam(
    resident_change_next ~
      any_extra_group +
      sex +
      age_class +
      s(capture_effort, k = 5) +
      s(year_factor, bs = "re") +
      s(tattoo_factor, bs = "re"),
    data = strict_next_year_dat,
    family = binomial(link = "logit"),
    method = "fREML",
    discrete = TRUE,
    nthreads = BAM_THREADS
  )

  saveRDS(
    fit_next_strict,
    "results/behaviour_next_year_residency_change_STRICT_model.rds"
  )

  print(summary(fit_next_strict))
  cat("\nStrict-model variance components:\n")
  print(gam.vcomp(fit_next_strict))

  write_csv(
    as.data.frame(summary(fit_next_strict)$p.table) %>%
      rownames_to_column("term") %>%
      as_tibble(),
    "results/behaviour_next_year_residency_change_STRICT_parametric.csv"
  )
} else if (START_STAGE == "E3") {
  cat("\nSkipping E2S adjusted model fit because START_STAGE = E3.\n")
}

# =============================================================================
# E3A. DIRECTLY OBSERVED EXCURSION RETURN — DESCRIPTIVE / POST-HOC BASELINE
# =============================================================================
#
# Define an observed outward excursion when a capture in the focal year's
# reconstructed annual resident group is followed by a capture in another group
# during that same year. If there is a subsequent capture that year, classify
# whether the next observed group is back in the annual resident group.
#
# IMPORTANT INTERPRETATION LIMIT:
# the focal-year annual resident group is itself estimated from all captures in
# that year. Therefore this analysis is useful descriptively, but its return
# fraction is expected to be biased upward toward temporary departures. Do not
# use the E3A return percentage as an unbiased population estimate of excursion
# return probability. E3B below uses an independent prior-year baseline.

seq_cap <- cap %>%
  group_by(tattoo, primary_year) %>%
  arrange(capture_date, capture_socg, .by_group = TRUE) %>%
  mutate(
    prev_group = lag(capture_socg),
    prev_date = lag(capture_date),
    next_group = lead(capture_socg),
    next_date = lead(capture_date),
    outward_excursion =
      !is.na(prev_group) &
      prev_group == resident_group &
      capture_socg != resident_group,
    next_observed = !is.na(next_group),
    returned_resident_next =
      outward_excursion &
      next_observed &
      next_group == resident_group,
    remained_extra_next =
      outward_excursion &
      next_observed &
      next_group != resident_group,
    days_resident_to_extra =
      as.integer(capture_date - prev_date),
    days_extra_to_next =
      as.integer(next_date - capture_date)
  ) %>%
  ungroup()

excursions <- seq_cap %>%
  filter(outward_excursion) %>%
  mutate(
    observed_followup = next_observed,
    return_status = case_when(
      !next_observed ~ "no later capture that year",
      returned_resident_next ~ "returned to resident group at next capture",
      remained_extra_next ~ "next capture still outside resident group",
      TRUE ~ "unclassified"
    )
  )

write_csv(
  excursions,
  "results/behaviour_observed_excursion_returns.csv"
)

cat("\n============================================================\n")
cat("E3A: FOCAL-YEAR-MODAL RESIDENT -> OTHER-GROUP EXCURSIONS\n")
cat("============================================================\n")
cat("Observed outward excursion events:", nrow(excursions), "\n")
cat("With later same-year capture:", sum(excursions$observed_followup), "\n")
if (sum(excursions$observed_followup) > 0L) {
  ex_follow <- excursions %>% filter(observed_followup)
  cat(
    "Returned to resident group at next observed capture:",
    sum(ex_follow$returned_resident_next),
    "of",
    nrow(ex_follow),
    "(",
    round(100 * mean(ex_follow$returned_resident_next), 2),
    "%)\n"
  )
}
cat("\nReturn-status counts:\n")
print(excursions %>% count(return_status, sort = TRUE), n = Inf)


# =============================================================================
# E3B. PROSPECTIVE OUTWARD EVENTS USING AN INDEPENDENT PRIOR-YEAR BASELINE
# =============================================================================
#
# Baseline residency is taken only from y-1 and must be:
#   - criterion 1 (current-year information only); and
#   - supported by >=2 grouped captures.
#
# In focal year y, an outward event requires an unambiguous capture-day in the
# prior resident group followed by an unambiguous capture-day in another group.
# Capture-days with >1 recorded social group are retained as ambiguous breakers
# rather than being alphabetically ordered. The next observed capture-day is
# followed across year boundaries.
#
# A strict y+1 resident group is also attached where available, giving an
# independent long-term relocation indicator relative to the y-1 baseline.

strict_resident <- resident %>%
  filter(
    resident_assignment_criterion == 1L,
    resident_n_grouped_captures >= 2L
  )

baseline_resident <- strict_resident %>%
  transmute(
    tattoo,
    source_resident_year = primary_year,
    primary_year = source_resident_year + 1L,
    baseline_year = source_resident_year,
    baseline_group = resident_group,
    baseline_n_grouped_captures = resident_n_grouped_captures
  )

future_resident <- strict_resident %>%
  transmute(
    tattoo,
    source_resident_year = primary_year,
    primary_year = source_resident_year - 1L,
    future_year = source_resident_year,
    future_group = resident_group,
    future_n_grouped_captures = resident_n_grouped_captures
  )

cap_day <- cap %>%
  group_by(tattoo, primary_year, capture_date) %>%
  summarise(
    sex = first(sex),
    age_class = first(age_class),
    n_capture_records_day = n(),
    n_groups_day = n_distinct(capture_socg),
    day_group = if (n_distinct(capture_socg) == 1L) {
      first(capture_socg)
    } else {
      NA_character_
    },
    .groups = "drop"
  ) %>%
  arrange(tattoo, capture_date) %>%
  group_by(tattoo) %>%
  mutate(
    prev_day_group = lag(day_group),
    prev_date = lag(capture_date),
    prev_year = lag(primary_year),
    next_day_group = lead(day_group),
    next_date = lead(capture_date),
    next_year_observed = lead(primary_year)
  ) %>%
  ungroup() %>%
  left_join(
    baseline_resident,
    by = c("tattoo", "primary_year")
  ) %>%
  left_join(
    future_resident,
    by = c("tattoo", "primary_year")
  ) %>%
  mutate(
    outward_from_prior_resident =
      !is.na(baseline_group) &
      !is.na(prev_day_group) &
      !is.na(day_group) &
      prev_year == primary_year &
      prev_day_group == baseline_group &
      day_group != baseline_group,
    observed_followup_anytime = !is.na(next_day_group),
    returned_prior_resident_next =
      outward_from_prior_resident &
      observed_followup_anytime &
      next_day_group == baseline_group,
    remained_outside_prior_next =
      outward_from_prior_resident &
      observed_followup_anytime &
      next_day_group != baseline_group,
    days_prior_resident_to_extra = as.integer(capture_date - prev_date),
    days_extra_to_next = as.integer(next_date - capture_date),
    future_residency_available = !is.na(future_group),
    changed_residency_by_yplus1 = case_when(
      is.na(future_group) ~ NA_integer_,
      future_group != baseline_group ~ 1L,
      TRUE ~ 0L
    )
  )

excursions_prior_baseline <- cap_day %>%
  filter(outward_from_prior_resident) %>%
  mutate(
    return_status = case_when(
      !observed_followup_anytime ~ "next observed capture-day absent or ambiguous",
      returned_prior_resident_next ~
        "returned to prior-year resident group at next capture-day",
      remained_outside_prior_next ~
        "next capture-day still outside prior-year resident group",
      TRUE ~ "unclassified"
    )
  )

write_csv(
  excursions_prior_baseline,
  "results/behaviour_observed_excursion_returns_PRIOR_BASELINE.csv"
)

cat("\n============================================================\n")
cat("E3B: PRIOR-YEAR BASELINE OUTWARD EVENTS\n")
cat("============================================================\n")
cat(
  "Direct outward events from independently established prior residence:",
  nrow(excursions_prior_baseline), "\n"
)
cat(
  "With an interpretable next observed capture-day:",
  sum(excursions_prior_baseline$observed_followup_anytime), "\n"
)

e3b_follow <- excursions_prior_baseline %>%
  filter(observed_followup_anytime)

if (nrow(e3b_follow) > 0L) {
  cat(
    "Returned to prior resident group at next observed capture-day:",
    sum(e3b_follow$returned_prior_resident_next),
    "of", nrow(e3b_follow),
    "(",
    round(100 * mean(e3b_follow$returned_prior_resident_next), 2),
    "%)\n"
  )

  e3b_365 <- e3b_follow %>%
    filter(days_extra_to_next <= 365L)

  if (nrow(e3b_365) > 0L) {
    cat(
      "Return among next captures observed within 365 days:",
      sum(e3b_365$returned_prior_resident_next),
      "of", nrow(e3b_365),
      "(",
      round(100 * mean(e3b_365$returned_prior_resident_next), 2),
      "%)\n"
    )
  }
}

cat("\nE3B return-status counts:\n")
print(
  excursions_prior_baseline %>%
    count(return_status, sort = TRUE),
  n = Inf
)

e3b_future <- excursions_prior_baseline %>%
  filter(future_residency_available)

if (nrow(e3b_future) > 0L) {
  cat(
    "\nEvents with strict y+1 residency available:",
    nrow(e3b_future), "\n"
  )
  cat(
    "Changed resident group by y+1 relative to y-1 baseline:",
    sum(e3b_future$changed_residency_by_yplus1),
    "of", nrow(e3b_future),
    "(",
    round(100 * mean(e3b_future$changed_residency_by_yplus1), 2),
    "%)\n"
  )

  cat("\nImmediate return versus confirmed y+1 residency change:\n")
  print(
    e3b_future %>%
      filter(observed_followup_anytime) %>%
      group_by(returned_prior_resident_next) %>%
      summarise(
        n = n(),
        changed_by_yplus1 = sum(changed_residency_by_yplus1),
        prop_changed_by_yplus1 = mean(changed_residency_by_yplus1),
        .groups = "drop"
      ),
    n = Inf
  )
}


cat("\nSaved excursion/residency-change outputs in results/.\n")
