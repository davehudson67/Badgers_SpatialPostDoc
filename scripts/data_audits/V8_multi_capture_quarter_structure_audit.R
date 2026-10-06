# =============================================================================
# WOODCHESTER V8 - MULTI-CAPTURE QUARTER STRUCTURE AUDIT
#
# Aim
#   Characterise repeated spatially usable live captures within the same quarter
#   before replacing the one-location-per-quarter V8 observation likelihood.
#
# This specifically tests the proposed "backfill" idea, but does NOT alter dates:
#   - how many captures / unique setts occur per quarter?
#   - how far apart in time are first and last captures?
#   - how often would an immediately previous calendar quarter be empty?
#   - in multi-sett quarters, does the first sett match the previous observed
#     quarter and/or the last sett match the next observed quarter?
#
# The preferred future model can then retain all capture locations in their true
# quarter rather than fabricating capture timing.
# =============================================================================

library(tidyverse)
library(lubridate)

MAX_YEAR <- 2025L
EXPECTED_N <- 1932L

ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
POP_FILE <- "results/V7_population_inclusion_audit.rds"
SETT_FILE <- "data/WoodchesterSettLocations.csv"

OUT_DIR <- "results/model_checks"
OUT_COUNT_DIST <- file.path(OUT_DIR, "V8_multi_capture_quarter_count_distribution.csv")
OUT_MULTI_SETT <- file.path(OUT_DIR, "V8_multi_capture_quarter_details.csv")
OUT_SUMMARY <- file.path(OUT_DIR, "V8_multi_capture_quarter_summary.csv")
OUT_RDS <- file.path(OUT_DIR, "V8_multi_capture_quarter_structure_audit.rds")

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

for (f in c(ENCOUNTER_FILE, POP_FILE, SETT_FILE)) {
  if (!file.exists(f)) stop("Missing required file: ", f)
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

enc <- readRDS(ENCOUNTER_FILE)
pop_obj <- readRDS(POP_FILE)
sett_raw <- read_csv(SETT_FILE, show_col_types = FALSE)

movement_pop <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    individual_id = as.integer(individual_id)
  )

if (nrow(movement_pop) != EXPECTED_N) {
  stop("Expected ", EXPECTED_N, " movement-eligible badgers.")
}

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

sett_xy <- sett_raw %>%
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
  ) %>%
  distinct(Sett_Clean, .keep_all = TRUE)

live <- enc %>%
  mutate(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    Sett_Clean = clean_sett2(sett)
  ) %>%
  filter(
    tattoo %in% movement_pop$tattoo,
    has_live_capture,
    primary_year <= MAX_YEAR,
    trap_season %in% 1:4
  ) %>%
  left_join(sett_xy, by = "Sett_Clean") %>%
  filter(!is.na(x), !is.na(y)) %>%
  mutate(
    quarter_index = primary_year * 4L + trap_season
  ) %>%
  arrange(tattoo, capture_date)

quarter <- live %>%
  group_by(tattoo, primary_year, trap_season, quarter_index) %>%
  summarise(
    n_live_encounters = n(),
    n_unique_setts = n_distinct(Sett_Clean),
    first_date = min(capture_date),
    last_date = max(capture_date),
    span_days = as.integer(last_date - first_date),
    first_sett = Sett_Clean[which.min(capture_date)],
    last_sett = Sett_Clean[which.max(capture_date)],
    sett_sequence = paste(Sett_Clean[order(capture_date)], collapse = " -> "),
    date_sequence = paste(as.character(capture_date[order(capture_date)]), collapse = " -> "),
    .groups = "drop"
  )

quarter_context <- quarter %>%
  group_by(tattoo) %>%
  arrange(quarter_index, .by_group = TRUE) %>%
  mutate(
    previous_observed_quarter_index = lag(quarter_index),
    previous_observed_last_sett = lag(last_sett),
    next_observed_quarter_index = lead(quarter_index),
    next_observed_first_sett = lead(first_sett),

    immediate_previous_quarter_observed =
      previous_observed_quarter_index == quarter_index - 1L,

    immediate_next_quarter_observed =
      next_observed_quarter_index == quarter_index + 1L,

    previous_calendar_quarter_empty =
      is.na(previous_observed_quarter_index) |
      previous_observed_quarter_index < quarter_index - 1L,

    next_calendar_quarter_empty =
      is.na(next_observed_quarter_index) |
      next_observed_quarter_index > quarter_index + 1L,

    first_matches_previous_observed =
      !is.na(previous_observed_last_sett) &
      first_sett == previous_observed_last_sett,

    last_matches_next_observed =
      !is.na(next_observed_first_sett) &
      last_sett == next_observed_first_sett
  ) %>%
  ungroup()

count_distribution <- quarter_context %>%
  count(n_live_encounters, n_unique_setts, name = "n_quarters") %>%
  arrange(n_live_encounters, n_unique_setts)

multi_sett <- quarter_context %>%
  filter(n_unique_setts > 1L) %>%
  arrange(desc(n_live_encounters), desc(span_days), tattoo, quarter_index)

summary_tbl <- tibble(
  metric = c(
    "movement_population",
    "spatial_live_encounters",
    "usable_badger_quarters",
    "quarters_with_gt1_live_encounter",
    "quarters_with_gt1_sett",
    "max_live_encounters_in_one_quarter",
    "max_unique_setts_in_one_quarter",
    "multi_sett_previous_calendar_quarter_empty",
    "multi_sett_immediate_previous_quarter_observed",
    "multi_sett_immediate_next_quarter_observed",
    "multi_sett_first_matches_previous_observed",
    "multi_sett_last_matches_next_observed",
    "multi_sett_first_matches_prev_and_last_matches_next",
    "multi_sett_first_sett_differs_from_last_sett"
  ),
  value = c(
    EXPECTED_N,
    nrow(live),
    nrow(quarter_context),
    sum(quarter_context$n_live_encounters > 1L),
    sum(quarter_context$n_unique_setts > 1L),
    max(quarter_context$n_live_encounters),
    max(quarter_context$n_unique_setts),
    sum(multi_sett$previous_calendar_quarter_empty),
    sum(multi_sett$immediate_previous_quarter_observed),
    sum(multi_sett$immediate_next_quarter_observed),
    sum(multi_sett$first_matches_previous_observed),
    sum(multi_sett$last_matches_next_observed),
    sum(
      multi_sett$first_matches_previous_observed &
      multi_sett$last_matches_next_observed
    ),
    sum(multi_sett$first_sett != multi_sett$last_sett)
  )
)

span_summary <- multi_sett %>%
  summarise(
    n_multi_sett_quarters = n(),
    median_span_days = median(span_days),
    p75_span_days = as.numeric(quantile(span_days, 0.75)),
    p90_span_days = as.numeric(quantile(span_days, 0.90)),
    p95_span_days = as.numeric(quantile(span_days, 0.95)),
    max_span_days = max(span_days)
  )

write_csv(count_distribution, OUT_COUNT_DIST)
write_csv(multi_sett, OUT_MULTI_SETT)
write_csv(
  bind_rows(
    summary_tbl %>% mutate(section = "counts", .before = 1),
    span_summary %>%
      pivot_longer(everything(), names_to = "metric", values_to = "value") %>%
      mutate(section = "multi_sett_time_span", .before = 1)
  ),
  OUT_SUMMARY
)

saveRDS(
  list(
    summary = summary_tbl,
    span_summary = span_summary,
    count_distribution = count_distribution,
    quarter_context = quarter_context,
    multi_sett = multi_sett
  ),
  OUT_RDS
)

cat("\n============================================================\n")
cat("V8 MULTI-CAPTURE QUARTER STRUCTURE AUDIT\n")
cat("============================================================\n")
print(summary_tbl, n = Inf, width = Inf)

cat("\nTime span within multi-sett quarters:\n")
print(span_summary, width = Inf)

cat("\nCapture-count / unique-sett distribution:\n")
print(count_distribution, n = Inf, width = Inf)

cat("\nWrote:\n")
cat(OUT_COUNT_DIST, "\n")
cat(OUT_MULTI_SETT, "\n")
cat(OUT_SUMMARY, "\n")
cat(OUT_RDS, "\n")
