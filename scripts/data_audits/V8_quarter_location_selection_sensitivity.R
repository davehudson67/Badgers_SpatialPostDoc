# =============================================================================
# WOODCHESTER V8 - QUARTERLY LOCATION-SELECTION SENSITIVITY AUDIT
#
# Aim
#   Quantify how much the V8 movement input depends on choosing one live sett
#   observation when a badger is captured at >1 recognised sett in a quarter.
#
# Population
#   Exactly the movement-eligible population from
#   results/V7_population_inclusion_audit.rds (expected n = 1,932).
#
# Compared representative-quarter rules
#   current_offmodal_latest
#     Exact current V8 rule: prefer a sett differing from the lifetime modal
#     sett, then choose the latest live capture.
#
#   latest_live
#     Latest spatially usable live capture in the quarter.
#
#   modal_quarter_sett
#     Sett with the most spatially usable live encounters in that quarter;
#     ties are resolved by the latest capture among the tied setts.
#
#   first_live
#     Earliest spatially usable live capture in the quarter.
#
# The audit compares:
#   1. selected sett/H observation by quarter;
#   2. detector-set membership (V8 currently builds X from selected rows);
#   3. annual observed mean location;
#   4. displacement between successively observed years;
#   5. the interpolated/snapped annual target path used to initialise latent ACs.
#
# IMPORTANT
#   This script does NOT refit the model. It tells us whether a full refit under
#   alternative observation-selection rules is warranted.
# =============================================================================

library(tidyverse)
library(lubridate)

MAX_YEAR <- 2025L
EXPECTED_N <- 1932L

ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
POP_FILE <- "results/V7_population_inclusion_audit.rds"
SETT_FILE <- "data/WoodchesterSettLocations.csv"
SPATIAL_FILE <- "data/spatial/V3_spatial_inputs_50m_2km.rds"

OUT_DIR <- "results/model_checks"
OUT_QUARTER_SUMMARY <- file.path(OUT_DIR, "V8_quarter_selection_summary.csv")
OUT_QUARTER_CHANGES <- file.path(OUT_DIR, "V8_quarter_selection_changed_quarters.csv")
OUT_DETECTOR_SUMMARY <- file.path(OUT_DIR, "V8_quarter_selection_detector_summary.csv")
OUT_ANNUAL_SUMMARY <- file.path(OUT_DIR, "V8_quarter_selection_annual_location_summary.csv")
OUT_MOVE_SUMMARY <- file.path(OUT_DIR, "V8_quarter_selection_observed_move_summary.csv")
OUT_TARGET_SUMMARY <- file.path(OUT_DIR, "V8_quarter_selection_target_step_summary.csv")
OUT_RDS <- file.path(OUT_DIR, "V8_quarter_location_selection_sensitivity.rds")

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

required_files <- c(ENCOUNTER_FILE, POP_FILE, SETT_FILE, SPATIAL_FILE)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files)) {
  stop("Missing required file(s):\n", paste(missing_files, collapse = "\n"))
}

q95 <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  as.numeric(quantile(x, 0.95, names = FALSE))
}

# ---- sett cleaning: EXACT inclusive-audit / V8 rules ------------------------
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
  for (a in names(sett_aliases)) {
    z[z == a] <- sett_aliases[[a]]
  }
  z
}

# ---- load audited population -------------------------------------------------
enc <- readRDS(ENCOUNTER_FILE)
pop_obj <- readRDS(POP_FILE)
sett_raw <- read_csv(SETT_FILE, show_col_types = FALSE)
sp <- readRDS(SPATIAL_FILE)

if (is.null(pop_obj$population)) {
  stop("Population audit RDS does not contain $population.")
}

movement_pop <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    individual_id = as.integer(individual_id)
  ) %>%
  arrange(tattoo)

if (nrow(movement_pop) != EXPECTED_N) {
  stop(
    "Expected ", EXPECTED_N,
    " movement-eligible badgers but population audit contains ",
    nrow(movement_pop), "."
  )
}

if (n_distinct(movement_pop$tattoo) != EXPECTED_N) {
  stop("Movement population does not contain exactly one row per tattoo.")
}

ids <- movement_pop$tattoo

# ---- exact sett coordinates --------------------------------------------------
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

sett_xy_conflicts <- sett_xy_all %>%
  distinct(Sett_Clean, x, y) %>%
  count(Sett_Clean, name = "n_coordinate_pairs") %>%
  filter(n_coordinate_pairs > 1L)

if (nrow(sett_xy_conflicts)) {
  print(sett_xy_conflicts, n = Inf)
  stop("One or more cleaned sett names map to multiple coordinate pairs.")
}

sett_xy <- sett_xy_all %>%
  distinct(Sett_Clean, .keep_all = TRUE)

# ---- spatially usable live encounters for the 1,932 population --------------
live <- enc %>%
  mutate(
    row_id = row_number(),
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    Sett_Clean = clean_sett2(sett)
  ) %>%
  filter(
    tattoo %in% ids,
    has_live_capture,
    !is.na(primary_year),
    primary_year <= MAX_YEAR,
    trap_season %in% 1:4
  ) %>%
  left_join(sett_xy, by = "Sett_Clean") %>%
  filter(!is.na(x), !is.na(y))

mapping_check <- live %>%
  distinct(tattoo, individual_id) %>%
  anti_join(movement_pop, by = c("tattoo", "individual_id"))

if (nrow(mapping_check)) {
  stop("Encounter snapshot contains tattoo/individual_id mappings inconsistent with population audit.")
}

live_year_check <- live %>%
  distinct(tattoo, primary_year) %>%
  count(tattoo, name = "n_live_years")

if (
  nrow(live_year_check) != EXPECTED_N ||
  any(live_year_check$n_live_years < 2L)
) {
  stop("Reconstructed live spatial histories do not match the audited movement population.")
}

quarter_complexity <- live %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(
    n_live_encounters = n(),
    n_setts = n_distinct(Sett_Clean),
    multi_encounter = n_live_encounters > 1L,
    multi_sett = n_setts > 1L,
    .groups = "drop"
  )

n_quarters <- nrow(quarter_complexity)

# ---- selection functions -----------------------------------------------------
select_current <- function(dat) {
  dat %>%
    group_by(tattoo, primary_year, trap_season) %>%
    arrange(
      desc(coalesce(differs_from_modal, FALSE)),
      desc(capture_date),
      .by_group = TRUE
    ) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(strategy = "current_offmodal_latest")
}

select_latest <- function(dat) {
  dat %>%
    group_by(tattoo, primary_year, trap_season) %>%
    arrange(desc(capture_date), .by_group = TRUE) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(strategy = "latest_live")
}

select_first <- function(dat) {
  dat %>%
    group_by(tattoo, primary_year, trap_season) %>%
    arrange(capture_date, .by_group = TRUE) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(strategy = "first_live")
}

select_quarter_mode <- function(dat) {
  dat %>%
    add_count(
      tattoo,
      primary_year,
      trap_season,
      Sett_Clean,
      name = "quarter_sett_n"
    ) %>%
    group_by(tattoo, primary_year, trap_season) %>%
    arrange(
      desc(quarter_sett_n),
      desc(capture_date),
      .by_group = TRUE
    ) %>%
    slice(1) %>%
    ungroup() %>%
    mutate(strategy = "modal_quarter_sett")
}

selected <- bind_rows(
  select_current(live),
  select_latest(live),
  select_quarter_mode(live),
  select_first(live)
) %>%
  select(
    strategy,
    tattoo,
    individual_id,
    primary_year,
    trap_season,
    capture_date,
    Sett_Clean,
    x,
    y,
    differs_from_modal,
    everything()
  )

selection_counts <- selected %>%
  count(strategy, name = "n")

if (nrow(selection_counts) != 4L || any(selection_counts$n != n_quarters)) {
  print(selection_counts)
  stop("One or more strategies did not select exactly one row per usable badger-quarter.")
}

# ---- quarter-level H/sett sensitivity ---------------------------------------
current_quarter <- selected %>%
  filter(strategy == "current_offmodal_latest") %>%
  transmute(
    tattoo,
    primary_year,
    trap_season,
    current_date = capture_date,
    current_sett = Sett_Clean,
    current_x = x,
    current_y = y
  )

quarter_comparison <- selected %>%
  select(
    strategy,
    tattoo,
    individual_id,
    primary_year,
    trap_season,
    selected_date = capture_date,
    selected_sett = Sett_Clean,
    selected_x = x,
    selected_y = y
  ) %>%
  left_join(
    quarter_complexity,
    by = c("tattoo", "primary_year", "trap_season")
  ) %>%
  left_join(
    current_quarter,
    by = c("tattoo", "primary_year", "trap_season")
  ) %>%
  mutate(
    changed_sett = selected_sett != current_sett,
    changed_date = selected_date != current_date,
    location_shift_m = sqrt(
      (selected_x - current_x)^2 +
      (selected_y - current_y)^2
    ),
    date_shift_days = as.integer(selected_date - current_date)
  )

quarter_summary <- quarter_comparison %>%
  group_by(strategy) %>%
  summarise(
    n_quarters = n(),
    n_multi_encounter_quarters = sum(multi_encounter),
    n_multi_sett_quarters = sum(multi_sett),
    n_changed_sett = sum(changed_sett),
    pct_changed_sett = 100 * mean(changed_sett),
    n_changed_date = sum(changed_date),
    pct_changed_date = 100 * mean(changed_date),
    n_badgers_with_changed_sett = n_distinct(tattoo[changed_sett]),
    pct_badgers_with_changed_sett =
      100 * n_distinct(tattoo[changed_sett]) / EXPECTED_N,
    median_location_shift_m = median(location_shift_m),
    p95_location_shift_m = q95(location_shift_m),
    max_location_shift_m = max(location_shift_m),
    .groups = "drop"
  )

# ---- detector-array sensitivity ---------------------------------------------
detector_sets <- split(
  selected$Sett_Clean,
  selected$strategy
) %>%
  lapply(unique)

current_detectors <- detector_sets[["current_offmodal_latest"]]

detector_summary <- tibble(
  strategy = names(detector_sets),
  n_unique_selected_setts = map_int(detector_sets, length),
  n_setts_added_vs_current = map_int(
    detector_sets,
    ~ length(setdiff(.x, current_detectors))
  ),
  n_setts_missing_vs_current = map_int(
    detector_sets,
    ~ length(setdiff(current_detectors, .x))
  )
)

# ---- annual observed locations ----------------------------------------------
annual_location <- selected %>%
  group_by(strategy, tattoo, primary_year) %>%
  summarise(
    x = mean(x),
    y = mean(y),
    n_selected_quarters = n(),
    .groups = "drop"
  )

current_annual <- annual_location %>%
  filter(strategy == "current_offmodal_latest") %>%
  transmute(
    tattoo,
    primary_year,
    current_annual_x = x,
    current_annual_y = y
  )

annual_comparison <- annual_location %>%
  left_join(current_annual, by = c("tattoo", "primary_year")) %>%
  mutate(
    annual_location_shift_m = sqrt(
      (x - current_annual_x)^2 +
      (y - current_annual_y)^2
    )
  )

annual_summary <- annual_comparison %>%
  group_by(strategy) %>%
  summarise(
    n_badger_years = n(),
    n_shifted = sum(annual_location_shift_m > 0),
    pct_shifted = 100 * mean(annual_location_shift_m > 0),
    n_shifted_gt25m = sum(annual_location_shift_m > 25),
    n_shifted_gt50m = sum(annual_location_shift_m > 50),
    n_shifted_gt100m = sum(annual_location_shift_m > 100),
    median_shift_m = median(annual_location_shift_m),
    p95_shift_m = q95(annual_location_shift_m),
    max_shift_m = max(annual_location_shift_m),
    .groups = "drop"
  )

# ---- observed displacement between successively observed years --------------
observed_moves <- annual_location %>%
  group_by(strategy, tattoo) %>%
  arrange(primary_year, .by_group = TRUE) %>%
  mutate(
    previous_year = lag(primary_year),
    previous_x = lag(x),
    previous_y = lag(y),
    year_gap = primary_year - previous_year,
    observed_move_m = sqrt(
      (x - previous_x)^2 +
      (y - previous_y)^2
    )
  ) %>%
  ungroup() %>%
  filter(!is.na(previous_year)) %>%
  transmute(
    strategy,
    tattoo,
    from_year = previous_year,
    to_year = primary_year,
    year_gap,
    observed_move_m
  )

current_moves <- observed_moves %>%
  filter(strategy == "current_offmodal_latest") %>%
  transmute(
    tattoo,
    from_year,
    to_year,
    current_observed_move_m = observed_move_m
  )

move_comparison <- observed_moves %>%
  left_join(
    current_moves,
    by = c("tattoo", "from_year", "to_year")
  ) %>%
  mutate(
    move_delta_m = observed_move_m - current_observed_move_m,
    abs_move_delta_m = abs(move_delta_m),
    crossed_150m =
      (observed_move_m > 150) !=
      (current_observed_move_m > 150)
  )

move_summary <- move_comparison %>%
  group_by(strategy) %>%
  summarise(
    n_observed_intervals = n(),
    n_changed = sum(abs_move_delta_m > 0),
    pct_changed = 100 * mean(abs_move_delta_m > 0),
    n_abs_delta_gt25m = sum(abs_move_delta_m > 25),
    n_abs_delta_gt50m = sum(abs_move_delta_m > 50),
    n_abs_delta_gt100m = sum(abs_move_delta_m > 100),
    n_crossed_150m = sum(crossed_150m),
    median_abs_delta_m = median(abs_move_delta_m),
    p95_abs_delta_m = q95(abs_move_delta_m),
    max_abs_delta_m = max(abs_move_delta_m),
    .groups = "drop"
  )

# ---- reproduce the V8 target-path construction -------------------------------
# V8 linearly interpolates annual observed mean locations between first and last
# observed spatial years, then snaps any target outside valid habitat to the
# nearest land-grid cell. These targets are only MCMC initial values, not data.

SG_mat <- sp$SG_mat
habitat_mat <- sp$habitat_mat
grid_xmin <- sp$xmin
grid_xmax <- sp$xmax
grid_ymin <- sp$ymin
grid_ymax <- sp$ymax
cell_size <- sp$cell_size
n_rows <- sp$n_rows
n_cols <- sp$n_cols

grid_df <- sf::st_drop_geometry(sp$grid)
grid_xy <- sf::st_coordinates(sp$grid)
land_idx <- which(grid_df$habitat == 1L)

is_valid_land_xy <- function(x, y) {
  cc <- floor((x - grid_xmin) / cell_size) + 1L
  rr <- floor((grid_ymax - y) / cell_size) + 1L

  inb <-
    rr >= 1L && rr <= n_rows &&
    cc >= 1L && cc <= n_cols

  inb &&
    !is.na(habitat_mat[rr, cc]) &&
    habitat_mat[rr, cc] == 1L
}

snap_to_land <- function(x, y) {
  if (is_valid_land_xy(x, y)) {
    return(c(x, y))
  }

  d2 <-
    (grid_xy[land_idx, 1] - x)^2 +
    (grid_xy[land_idx, 2] - y)^2

  grid_xy[land_idx[which.min(d2)], 1:2]
}

build_target_path <- function(dat) {
  dat %>%
    group_by(strategy, tattoo) %>%
    group_modify(~ {
      yrs <- seq.int(min(.x$primary_year), max(.x$primary_year))

      xi <- approx(
        .x$primary_year,
        .x$x,
        xout = yrs,
        rule = 2
      )$y

      yi <- approx(
        .x$primary_year,
        .x$y,
        xout = yrs,
        rule = 2
      )$y

      snapped <- map2_dfr(
        xi,
        yi,
        ~ {
          xy <- snap_to_land(.x, .y)
          tibble(target_x = xy[1], target_y = xy[2])
        }
      )

      bind_cols(
        tibble(primary_year = yrs),
        snapped
      )
    }) %>%
    ungroup()
}

target_path <- build_target_path(annual_location)

target_steps <- target_path %>%
  group_by(strategy, tattoo) %>%
  arrange(primary_year, .by_group = TRUE) %>%
  mutate(
    from_year = lag(primary_year),
    previous_x = lag(target_x),
    previous_y = lag(target_y),
    target_step_m = sqrt(
      (target_x - previous_x)^2 +
      (target_y - previous_y)^2
    ),
    init_high_prob = plogis((target_step_m - 150) / 50)
  ) %>%
  ungroup() %>%
  filter(!is.na(from_year)) %>%
  transmute(
    strategy,
    tattoo,
    from_year,
    to_year = primary_year,
    target_step_m,
    init_high_prob
  )

current_target_steps <- target_steps %>%
  filter(strategy == "current_offmodal_latest") %>%
  transmute(
    tattoo,
    from_year,
    to_year,
    current_target_step_m = target_step_m,
    current_init_high_prob = init_high_prob
  )

target_comparison <- target_steps %>%
  left_join(
    current_target_steps,
    by = c("tattoo", "from_year", "to_year")
  ) %>%
  mutate(
    target_step_delta_m =
      target_step_m - current_target_step_m,

    abs_target_step_delta_m =
      abs(target_step_delta_m),

    init_prob_delta =
      init_high_prob - current_init_high_prob,

    abs_init_prob_delta =
      abs(init_prob_delta),

    crossed_150m =
      (target_step_m > 150) !=
      (current_target_step_m > 150)
  )

target_summary <- target_comparison %>%
  group_by(strategy) %>%
  summarise(
    n_annual_target_steps = n(),
    n_changed = sum(abs_target_step_delta_m > 0),
    pct_changed = 100 * mean(abs_target_step_delta_m > 0),
    n_abs_delta_gt25m = sum(abs_target_step_delta_m > 25),
    n_abs_delta_gt50m = sum(abs_target_step_delta_m > 50),
    n_abs_delta_gt100m = sum(abs_target_step_delta_m > 100),
    n_crossed_150m = sum(crossed_150m),
    median_abs_delta_m = median(abs_target_step_delta_m),
    p95_abs_delta_m = q95(abs_target_step_delta_m),
    max_abs_delta_m = max(abs_target_step_delta_m),
    median_abs_init_prob_delta = median(abs_init_prob_delta),
    p95_abs_init_prob_delta = q95(abs_init_prob_delta),
    max_abs_init_prob_delta = max(abs_init_prob_delta),
    .groups = "drop"
  )

# ---- save transparent audit outputs ------------------------------------------
write_csv(quarter_summary, OUT_QUARTER_SUMMARY)

write_csv(
  quarter_comparison %>%
    filter(
      strategy != "current_offmodal_latest",
      changed_sett | changed_date
    ) %>%
    arrange(strategy, tattoo, primary_year, trap_season),
  OUT_QUARTER_CHANGES
)

write_csv(detector_summary, OUT_DETECTOR_SUMMARY)
write_csv(annual_summary, OUT_ANNUAL_SUMMARY)
write_csv(move_summary, OUT_MOVE_SUMMARY)
write_csv(target_summary, OUT_TARGET_SUMMARY)

saveRDS(
  list(
    settings = list(
      max_year = MAX_YEAR,
      expected_n = EXPECTED_N,
      reference_strategy = "current_offmodal_latest"
    ),
    movement_population = movement_pop,
    quarter_complexity = quarter_complexity,
    quarter_summary = quarter_summary,
    quarter_comparison = quarter_comparison,
    detector_summary = detector_summary,
    annual_location = annual_location,
    annual_summary = annual_summary,
    observed_moves = observed_moves,
    move_summary = move_summary,
    target_path = target_path,
    target_steps = target_steps,
    target_summary = target_summary
  ),
  OUT_RDS
)

# ---- console report ----------------------------------------------------------
cat("\n============================================================\n")
cat("V8 QUARTERLY LOCATION-SELECTION SENSITIVITY\n")
cat("============================================================\n")
cat("Movement population:", EXPECTED_N, "badgers\n")
cat("Spatially usable live encounters:", nrow(live), "\n")
cat("Usable badger-quarters:", n_quarters, "\n")
cat(
  "Quarters with >1 live encounter:",
  sum(quarter_complexity$multi_encounter),
  "\n"
)
cat(
  "Quarters with >1 recognised sett:",
  sum(quarter_complexity$multi_sett),
  "\n\n"
)

cat("Quarter/H sensitivity relative to current V8 rule:\n")
print(quarter_summary, n = Inf, width = Inf)

cat("\nDetector-array sensitivity:\n")
print(detector_summary, n = Inf, width = Inf)

cat("\nAnnual observed-location sensitivity:\n")
print(annual_summary, n = Inf, width = Inf)

cat("\nObserved-year displacement sensitivity:\n")
print(move_summary, n = Inf, width = Inf)

cat("\nV8 interpolated target-step / initialization sensitivity:\n")
print(target_summary, n = Inf, width = Inf)

cat("\nWrote:\n")
cat(OUT_QUARTER_SUMMARY, "\n")
cat(OUT_QUARTER_CHANGES, "\n")
cat(OUT_DETECTOR_SUMMARY, "\n")
cat(OUT_ANNUAL_SUMMARY, "\n")
cat(OUT_MOVE_SUMMARY, "\n")
cat(OUT_TARGET_SUMMARY, "\n")
cat(OUT_RDS, "\n")
