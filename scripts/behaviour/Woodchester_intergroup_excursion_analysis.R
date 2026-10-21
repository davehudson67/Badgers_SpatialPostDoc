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
# OUTPUTS
#   results/behaviour_extra_group_captures.csv
#   results/behaviour_extra_group_quarters.csv
#   results/behaviour_extra_group_years.csv
#   results/behaviour_next_year_residency_change.csv
#   results/behaviour_observed_excursion_returns.csv
#   results/behaviour_extra_group_quarter_parametric.csv
#   results/behaviour_next_year_residency_change_parametric.csv
# =============================================================================

library(tidyverse)
library(mgcv)

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
    resident_assignment_criterion = as.integer(assignment_criterion)
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
  nthreads = max(1L, parallel::detectCores(logical = FALSE) - 2L)
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
    next_resident_assignment_criterion = resident_assignment_criterion
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
  nthreads = max(1L, parallel::detectCores(logical = FALSE) - 2L)
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

# =============================================================================
# E3. DIRECTLY OBSERVED EXCURSION RETURN
# =============================================================================
#
# Define an observed outward excursion when a capture in the annual resident
# group is followed by a capture in another group during the same calendar
# year. If there is a subsequent capture that year, classify whether the next
# observed group is back in the resident group.

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
cat("E3: DIRECTLY OBSERVED RESIDENT -> OTHER-GROUP EXCURSIONS\n")
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

cat("\nSaved excursion/residency-change outputs in results/.\n")
