# =============================================================================
# WOODCHESTER V10 - QUARTERLY STATE-SPACE DATA AUDIT / BUILDER
#
# Purpose
#   Build the data structure required by the proposed V10 quarterly movement
#   state-space model while retaining every spatially usable live capture.
#
# This script does NOT fit the model.
#
# It reports:
#   - number of latent quarterly states from first to last usable capture;
#   - number of quarter-to-quarter movement intervals;
#   - observed vs internally missing quarters;
#   - capture-count distribution per badger-quarter;
#   - calendar-quarter gap structure;
#   - successful capture-date footprint as a LOWER BOUND on trapping nights.
#
# IMPORTANT
#   Capture dates with no animals caught are not available here, and setts with
#   traps but zero captures cannot be reconstructed from capture records alone.
#   Therefore the capture-date footprint MUST NOT be used as a complete effort
#   mask in the primary V10 likelihood.
# =============================================================================

library(tidyverse)
library(lubridate)

MAX_YEAR <- 2025L
EXPECTED_N <- 1932L

ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
POP_FILE <- "results/V7_population_inclusion_audit.rds"
SETT_FILE <- "data/WoodchesterSettLocations.csv"

OUT_DIR <- "results/model_checks"
OUT_RDS <- file.path(OUT_DIR, "V10_quarterly_state_data.rds")
OUT_SUMMARY <- file.path(OUT_DIR, "V10_quarterly_state_summary.csv")
OUT_GAPS <- file.path(OUT_DIR, "V10_observed_quarter_gap_distribution.csv")
OUT_CAPTURE_COUNTS <- file.path(OUT_DIR, "V10_capture_count_distribution.csv")
OUT_CALENDAR_Q <- file.path(OUT_DIR, "V10_calendar_quarter_capture_footprint.csv")
OUT_CAPTURE_DATES <- file.path(OUT_DIR, "V10_successful_capture_date_footprint.csv")

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

for (f in c(ENCOUNTER_FILE, POP_FILE, SETT_FILE)) {
  if (!file.exists(f)) stop("Missing required file: ", f)
}

# ---- sett cleaning: same rules as inclusive audit / V8 ----------------------
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

# ---- load -------------------------------------------------------------------
enc <- readRDS(ENCOUNTER_FILE)
pop_obj <- readRDS(POP_FILE)
sett_raw <- read_csv(SETT_FILE, show_col_types = FALSE)

if (is.null(pop_obj$population)) {
  stop("Population audit RDS does not contain $population.")
}

movement_pop <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    individual_id = as.integer(individual_id),
    sex_class = as.character(sex_class),
    age_entry_class = as.character(age_entry_class)
  ) %>%
  mutate(
    sex_code = case_when(
      sex_class == "Female" ~ 0L,
      sex_class == "Male" ~ 1L,
      TRUE ~ NA_integer_
    ),
    adult_entry = as.integer(age_entry_class == "Adult_exact_age_unknown")
  ) %>%
  arrange(tattoo)

if (nrow(movement_pop) != EXPECTED_N) {
  stop(
    "Expected ", EXPECTED_N,
    " movement-eligible badgers, found ", nrow(movement_pop), "."
  )
}
if (anyNA(movement_pop$sex_code)) {
  stop("Movement population contains unknown sex.")
}

# ---- coordinates -------------------------------------------------------------
name_col <- intersect(
  c("Sett_Clean", "Sett", "sett", "SettName", "Sett_Upper", "Name"),
  names(sett_raw)
)[1]
x_col <- intersect(
  c("SettX", "sett_x", "X", "x", "Easting", "easting"),
  names(sett_raw)
)[1]
y_col <- intersect(
  c("SettY", "sett_y", "Y", "y", "Northing", "northing"),
  names(sett_raw)
)[1]

if (any(is.na(c(name_col, x_col, y_col)))) {
  stop("Could not identify sett name/X/Y columns.")
}

sett_xy_all <- sett_raw %>%
  transmute(
    Sett_Clean = clean_sett2(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(
    !is.na(Sett_Clean),
    Sett_Clean != "",
    !is.na(x),
    !is.na(y)
  )

conflicts <- sett_xy_all %>%
  distinct(Sett_Clean, x, y) %>%
  count(Sett_Clean, name = "n_coordinate_pairs") %>%
  filter(n_coordinate_pairs > 1L)

if (nrow(conflicts)) {
  print(conflicts, n = Inf)
  stop("One or more cleaned sett names map to multiple coordinate pairs.")
}

sett_xy <- sett_xy_all %>%
  distinct(Sett_Clean, .keep_all = TRUE)

# ---- all spatially usable live captures -------------------------------------
captures <- enc %>%
  mutate(
    tattoo = toupper(trimws(as.character(tattoo))),
    individual_id = as.integer(individual_id),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    capture_date = as.Date(capture_date),
    Sett_Clean = clean_sett2(sett)
  ) %>%
  filter(
    tattoo %in% movement_pop$tattoo,
    has_live_capture,
    !is.na(primary_year),
    primary_year <= MAX_YEAR,
    trap_season %in% 1:4
  ) %>%
  left_join(sett_xy, by = "Sett_Clean") %>%
  filter(!is.na(x), !is.na(y)) %>%
  mutate(
    quarter_abs = primary_year * 4L + (trap_season - 1L),
    calendar_quarter = paste0(primary_year, "Q", trap_season)
  ) %>%
  arrange(tattoo, quarter_abs, capture_date, Sett_Clean) %>%
  group_by(tattoo, quarter_abs) %>%
  mutate(capture_slot = row_number()) %>%
  ungroup()

mapping_check <- captures %>%
  distinct(tattoo, individual_id) %>%
  anti_join(
    movement_pop %>% select(tattoo, individual_id),
    by = c("tattoo", "individual_id")
  )

if (nrow(mapping_check)) {
  stop("Encounter/population tattoo-individual_id mapping mismatch.")
}

# ---- observed quarter summaries ---------------------------------------------
observed_quarters <- captures %>%
  group_by(
    tattoo,
    individual_id,
    primary_year,
    trap_season,
    quarter_abs,
    calendar_quarter
  ) %>%
  summarise(
    n_captures = n(),
    n_unique_setts = n_distinct(Sett_Clean),
    first_capture_date = min(capture_date),
    last_capture_date = max(capture_date),
    capture_span_days = as.integer(last_capture_date - first_capture_date),
    .groups = "drop"
  )

if (max(observed_quarters$n_captures) != max(captures$capture_slot)) {
  stop("Capture-slot construction mismatch.")
}

# ---- individual latent-quarter spans ----------------------------------------
individual_span <- observed_quarters %>%
  group_by(tattoo, individual_id) %>%
  summarise(
    first_quarter_abs = min(quarter_abs),
    last_quarter_abs = max(quarter_abs),
    n_observed_quarters = n_distinct(quarter_abs),
    n_latent_quarters = last_quarter_abs - first_quarter_abs + 1L,
    n_quarterly_movement_intervals = n_latent_quarters - 1L,
    n_internal_missing_quarters = n_latent_quarters - n_observed_quarters,
    .groups = "drop"
  ) %>%
  right_join(
    movement_pop %>%
      select(tattoo, individual_id, sex_class, sex_code, age_entry_class, adult_entry),
    by = c("tattoo", "individual_id")
  ) %>%
  arrange(tattoo)

if (nrow(individual_span) != EXPECTED_N || anyNA(individual_span$first_quarter_abs)) {
  stop("Could not reconstruct quarterly span for every movement badger.")
}

# ---- explicit state table, including quarters with no capture ---------------
state_table <- individual_span %>%
  select(
    tattoo,
    individual_id,
    sex_class,
    sex_code,
    age_entry_class,
    adult_entry,
    first_quarter_abs,
    last_quarter_abs
  ) %>%
  rowwise() %>%
  mutate(quarter_abs = list(seq.int(first_quarter_abs, last_quarter_abs))) %>%
  ungroup() %>%
  unnest(quarter_abs) %>%
  mutate(
    primary_year = quarter_abs %/% 4L,
    trap_season = quarter_abs %% 4L + 1L,
    calendar_quarter = paste0(primary_year, "Q", trap_season)
  ) %>%
  left_join(
    observed_quarters %>%
      select(
        tattoo,
        quarter_abs,
        n_captures,
        n_unique_setts,
        first_capture_date,
        last_capture_date,
        capture_span_days
      ),
    by = c("tattoo", "quarter_abs")
  ) %>%
  mutate(
    n_captures = replace_na(n_captures, 0L),
    n_unique_setts = replace_na(n_unique_setts, 0L),
    observed = n_captures > 0L
  ) %>%
  group_by(tattoo) %>%
  arrange(quarter_abs, .by_group = TRUE) %>%
  mutate(
    individual_state_index = row_number(),
    is_first_state = individual_state_index == 1L,
    is_movement_interval = !is_first_state
  ) %>%
  ungroup() %>%
  mutate(global_state_index = row_number())

# ---- gaps between actually observed quarters --------------------------------
observed_gap <- observed_quarters %>%
  group_by(tattoo) %>%
  arrange(quarter_abs, .by_group = TRUE) %>%
  mutate(
    previous_observed_quarter_abs = lag(quarter_abs),
    observed_quarter_gap =
      quarter_abs - previous_observed_quarter_abs,
    n_missing_between_observations =
      observed_quarter_gap - 1L
  ) %>%
  ungroup() %>%
  filter(!is.na(previous_observed_quarter_abs))

gap_distribution <- observed_gap %>%
  count(
    observed_quarter_gap,
    n_missing_between_observations,
    name = "n_observed_pairs"
  ) %>%
  arrange(observed_quarter_gap)

capture_count_distribution <- state_table %>%
  count(n_captures, n_unique_setts, observed, name = "n_badger_quarters") %>%
  arrange(n_captures, n_unique_setts)

# ---- successful capture-night footprint -------------------------------------
# This is deliberately labelled a lower bound on effort.
capture_date_footprint <- captures %>%
  group_by(
    capture_date,
    primary_year,
    trap_season,
    quarter_abs,
    calendar_quarter
  ) %>%
  summarise(
    n_capture_events = n(),
    n_badgers_caught = n_distinct(tattoo),
    n_setts_with_successful_capture = n_distinct(Sett_Clean),
    .groups = "drop"
  ) %>%
  arrange(capture_date)

calendar_quarter_footprint <- captures %>%
  group_by(
    primary_year,
    trap_season,
    quarter_abs,
    calendar_quarter
  ) %>%
  summarise(
    n_capture_events = n(),
    n_badgers_caught = n_distinct(tattoo),
    n_setts_with_successful_capture = n_distinct(Sett_Clean),
    n_dates_with_successful_capture = n_distinct(capture_date),
    first_successful_capture_date = min(capture_date),
    last_successful_capture_date = max(capture_date),
    successful_capture_span_days =
      as.integer(last_successful_capture_date - first_successful_capture_date),
    .groups = "drop"
  ) %>%
  arrange(quarter_abs)

# ---- overall summary ---------------------------------------------------------
summary_tbl <- tibble(
  metric = c(
    "movement_population",
    "spatially_usable_live_capture_events",
    "observed_badger_quarters",
    "latent_badger_quarter_states_first_to_last",
    "internal_missing_badger_quarters",
    "quarter_to_quarter_movement_intervals",
    "max_captures_in_badger_quarter",
    "max_unique_setts_in_badger_quarter",
    "observed_quarter_pairs_consecutive",
    "observed_quarter_pairs_with_gap",
    "max_observed_quarter_gap",
    "calendar_quarters_with_at_least_one_successful_capture",
    "unique_dates_with_at_least_one_successful_capture"
  ),
  value = c(
    EXPECTED_N,
    nrow(captures),
    nrow(observed_quarters),
    nrow(state_table),
    sum(!state_table$observed),
    sum(state_table$is_movement_interval),
    max(observed_quarters$n_captures),
    max(observed_quarters$n_unique_setts),
    sum(observed_gap$observed_quarter_gap == 1L),
    sum(observed_gap$observed_quarter_gap > 1L),
    max(observed_gap$observed_quarter_gap),
    nrow(calendar_quarter_footprint),
    n_distinct(captures$capture_date)
  )
)

write_csv(summary_tbl, OUT_SUMMARY)
write_csv(gap_distribution, OUT_GAPS)
write_csv(capture_count_distribution, OUT_CAPTURE_COUNTS)
write_csv(calendar_quarter_footprint, OUT_CALENDAR_Q)
write_csv(capture_date_footprint, OUT_CAPTURE_DATES)

saveRDS(
  list(
    settings = list(
      max_year = MAX_YEAR,
      expected_n = EXPECTED_N,
      movement_time_step = "calendar_quarter",
      observation_model = "conditional_on_observed_live_captures",
      capture_order_within_quarter_used_for_movement = FALSE
    ),
    population = movement_pop,
    individual_span = individual_span,
    states = state_table,
    captures = captures,
    observed_quarters = observed_quarters,
    observed_gap = observed_gap,
    capture_date_footprint = capture_date_footprint,
    calendar_quarter_footprint = calendar_quarter_footprint
  ),
  OUT_RDS
)

cat("\n============================================================\n")
cat("V10 QUARTERLY STATE-SPACE DATA AUDIT\n")
cat("============================================================\n")
print(summary_tbl, n = Inf, width = Inf)

cat("\nObserved-quarter gap distribution:\n")
print(gap_distribution, n = Inf, width = Inf)

cat("\nCapture-count distribution including latent empty quarters:\n")
print(capture_count_distribution, n = Inf, width = Inf)

cat("\nSuccessful-capture calendar-quarter footprint summary:\n")
print(
  calendar_quarter_footprint %>%
    summarise(
      n_calendar_quarters = n(),
      median_successful_capture_dates =
        median(n_dates_with_successful_capture),
      p90_successful_capture_dates =
        as.numeric(quantile(n_dates_with_successful_capture, 0.90)),
      max_successful_capture_dates =
        max(n_dates_with_successful_capture),
      median_setts_with_successful_capture =
        median(n_setts_with_successful_capture),
      p90_setts_with_successful_capture =
        as.numeric(quantile(n_setts_with_successful_capture, 0.90)),
      max_setts_with_successful_capture =
        max(n_setts_with_successful_capture)
    ),
  width = Inf
)

cat("\nIMPORTANT: successful-capture dates/setts are a LOWER BOUND on trapping effort.\n")
cat("Do not use them as a complete detector-effort mask.\n")

cat("\nWrote:\n")
cat(OUT_SUMMARY, "\n")
cat(OUT_GAPS, "\n")
cat(OUT_CAPTURE_COUNTS, "\n")
cat(OUT_CALENDAR_Q, "\n")
cat(OUT_CAPTURE_DATES, "\n")
cat(OUT_RDS, "\n")
