# =============================================================================
# V10A discordant annual movement-state audit
#
# Purpose
#   Diagnose annual movement intervals whose posterior P(high mobility) differs
#   strongly among chains. This is a DESCRIPTIVE audit of the observed capture
#   history, not another fitted model.
#
# Reads
#   results/V10A_RD_MULTILOC_<N>_COMBINED.rds
#   data/badger_encounters_useful.rds
#   data/WoodchesterSettLocations.csv
#   results/V7_population_inclusion_audit.rds
#
# Environment
#   MAX_BADGERS       population size used in the V10A fit (default 100)
#   DISAGREE_THRESH   max between-chain P(high) difference (default 0.25)
#   WINDOW_YEARS      years either side to retain in trajectory export (default 2)
#
# Writes
#   results/V10A_RD_MULTILOC_<N>_discordant_interval_audit.csv
#   results/V10A_RD_MULTILOC_<N>_discordant_capture_history.csv
#   results/V10A_RD_MULTILOC_<N>_discordant_quarter_centres.csv
#   results/V10A_RD_MULTILOC_<N>_discordant_annual_centres.csv
#   results/V10A_RD_MULTILOC_<N>_discordant_state_neighbourhood.csv
#
# Interpretation
#   observed_annual_centroid_jump_m is a descriptive distance between the mean
#   coordinates of all usable live captures in the two years. It is NOT a
#   posterior annual AC displacement.
#
#   quarter-centre distances below are descriptive distances between observed
#   capture-location centroids. They are NOT fitted Q states.
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "100"))
DISAGREE_THRESH <- as.numeric(Sys.getenv("DISAGREE_THRESH", unset = "0.25"))
WINDOW_YEARS <- as.integer(Sys.getenv("WINDOW_YEARS", unset = "2"))

if (!is.finite(MAX_BADGERS) || MAX_BADGERS < 2L) {
  stop("MAX_BADGERS must be >=2.")
}
if (!is.finite(DISAGREE_THRESH) ||
    DISAGREE_THRESH < 0 ||
    DISAGREE_THRESH > 1) {
  stop("DISAGREE_THRESH must be in [0,1].")
}
if (!is.finite(WINDOW_YEARS) || WINDOW_YEARS < 0L) {
  stop("WINDOW_YEARS must be >=0.")
}

prefix <- file.path(
  "results",
  paste0("V10A_RD_MULTILOC_", MAX_BADGERS)
)

combined_file <- paste0(prefix, "_COMBINED.rds")
encounter_file <- "data/badger_encounters_useful.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
population_file <- "results/V7_population_inclusion_audit.rds"

required_files <- c(
  combined_file,
  encounter_file,
  sett_file,
  population_file
)

missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files)) {
  stop(
    "Missing required file(s):\n",
    paste(missing_files, collapse = "\n")
  )
}

cat("\n============================================================\n")
cat("V10A DISCORDANT MOVEMENT-STATE AUDIT\n")
cat("============================================================\n")
cat("Population size:", MAX_BADGERS, "\n")
cat("Chain disagreement threshold:", DISAGREE_THRESH, "\n")
cat("Trajectory window:", WINDOW_YEARS, "year(s) either side\n\n")

cmb <- readRDS(combined_file)
enc <- readRDS(encounter_file)
sett_raw <- read_csv(sett_file, show_col_types = FALSE)
pop_obj <- readRDS(population_file)

if (is.null(cmb$disp_probabilities)) {
  stop("Combined object does not contain $disp_probabilities.")
}
if (is.null(pop_obj$population)) {
  stop("Population audit does not contain $population.")
}

# -----------------------------------------------------------------------------
# Sett cleaning: deliberately identical to V10A fitting script
# -----------------------------------------------------------------------------
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

sett_xy_raw <- sett_raw %>%
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

bad_sett_coords <- sett_xy_raw %>%
  distinct(Sett_Clean, x, y) %>%
  count(Sett_Clean, name = "n_xy") %>%
  filter(n_xy > 1L)

if (nrow(bad_sett_coords)) {
  print(bad_sett_coords, n = Inf)
  stop("A cleaned sett maps to >1 coordinate pair.")
}

sett_xy <- sett_xy_raw %>%
  distinct(Sett_Clean, .keep_all = TRUE)

# -----------------------------------------------------------------------------
# Usable observed live captures: same spatial data basis as V10A
# -----------------------------------------------------------------------------
live <- enc %>%
  mutate(
    tattoo = toupper(trimws(as.character(tattoo))),
    individual_id = as.integer(individual_id),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    capture_date = as.Date(capture_date),
    Sett_Clean = clean_sett2(sett)
  ) %>%
  filter(
    has_live_capture,
    !is.na(primary_year),
    primary_year <= 2025L,
    trap_season %in% 1:4
  ) %>%
  left_join(sett_xy, by = "Sett_Clean") %>%
  filter(!is.na(x), !is.na(y))

# Restrict explicitly to the fitted individuals.
live <- live %>%
  filter(tattoo %in% cmb$ids)

# -----------------------------------------------------------------------------
# Identify genuinely discordant annual movement intervals
# -----------------------------------------------------------------------------
disp <- cmb$disp_probabilities

required_disp_cols <- c(
  "active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "from_year",
  "to_year",
  "p_high_chain1",
  "p_high_chain2",
  "p_high_chain3",
  "max_chain_difference",
  "p_high_pooled"
)

missing_disp_cols <- setdiff(required_disp_cols, names(disp))
if (length(missing_disp_cols)) {
  stop(
    "disp_probabilities missing columns: ",
    paste(missing_disp_cols, collapse = ", ")
  )
}

discordant <- disp %>%
  filter(max_chain_difference > DISAGREE_THRESH) %>%
  arrange(desc(max_chain_difference), tattoo, from_year)

if (!nrow(discordant)) {
  cat("No movement intervals exceed the disagreement threshold.\n")
  quit(save = "no", status = 0)
}

discordant_animals <- unique(discordant$tattoo)

pop_meta <- pop_obj$population %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    sex_class = as.character(sex_class),
    age_entry_class = as.character(age_entry_class)
  ) %>%
  distinct(tattoo, .keep_all = TRUE)

discordant <- discordant %>%
  left_join(pop_meta, by = "tattoo")

cat(
  "Discordant intervals:", nrow(discordant),
  "| animals:", length(discordant_animals), "\n"
)

# -----------------------------------------------------------------------------
# Capture histories in a local window around every discordant transition
# -----------------------------------------------------------------------------
windows <- discordant %>%
  transmute(
    active_index,
    tattoo,
    focal_from_year = from_year,
    focal_to_year = to_year,
    window_start = from_year - WINDOW_YEARS,
    window_end = to_year + WINDOW_YEARS
  )

capture_history <- live %>%
  inner_join(
    windows %>% select(
      active_index,
      tattoo,
      focal_from_year,
      focal_to_year,
      window_start,
      window_end
    ),
    by = "tattoo",
    relationship = "many-to-many"
  ) %>%
  filter(
    primary_year >= window_start,
    primary_year <= window_end
  ) %>%
  arrange(
    active_index,
    primary_year,
    trap_season,
    capture_date,
    Sett_Clean
  ) %>%
  mutate(
    relative_to_interval = case_when(
      primary_year < focal_from_year ~ "before",
      primary_year == focal_from_year ~ "from_year",
      primary_year == focal_to_year ~ "to_year",
      primary_year > focal_to_year ~ "after",
      TRUE ~ "between"
    )
  ) %>%
  select(
    active_index,
    tattoo,
    focal_from_year,
    focal_to_year,
    relative_to_interval,
    primary_year,
    trap_season,
    capture_date,
    Sett_Clean,
    x,
    y
  )

# -----------------------------------------------------------------------------
# Descriptive observed quarter and annual centroids
# -----------------------------------------------------------------------------
quarter_centres_all <- live %>%
  filter(tattoo %in% discordant_animals) %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(
    n_captures = n(),
    n_setts = n_distinct(Sett_Clean),
    setts = paste(sort(unique(Sett_Clean)), collapse = "|"),
    qx = mean(x),
    qy = mean(y),
    first_capture_date = min(capture_date),
    last_capture_date = max(capture_date),
    .groups = "drop"
  ) %>%
  arrange(tattoo, primary_year, trap_season) %>%
  group_by(tattoo) %>%
  mutate(
    previous_observed_year = lag(primary_year),
    previous_observed_quarter = lag(trap_season),
    previous_qx = lag(qx),
    previous_qy = lag(qy),
    distance_from_previous_observed_quarter_m = sqrt(
      (qx - previous_qx)^2 +
        (qy - previous_qy)^2
    )
  ) %>%
  ungroup()

quarter_centres <- quarter_centres_all %>%
  inner_join(windows, by = "tattoo", relationship = "many-to-many") %>%
  filter(
    primary_year >= window_start,
    primary_year <= window_end
  ) %>%
  arrange(active_index, primary_year, trap_season)

annual_centres_all <- live %>%
  filter(tattoo %in% discordant_animals) %>%
  group_by(tattoo, primary_year) %>%
  summarise(
    n_captures = n(),
    n_quarters_observed = n_distinct(trap_season),
    n_setts = n_distinct(Sett_Clean),
    setts = paste(sort(unique(Sett_Clean)), collapse = "|"),
    ax_obs = mean(x),
    ay_obs = mean(y),
    .groups = "drop"
  ) %>%
  arrange(tattoo, primary_year) %>%
  group_by(tattoo) %>%
  mutate(
    previous_observed_year = lag(primary_year),
    previous_ax_obs = lag(ax_obs),
    previous_ay_obs = lag(ay_obs),
    years_since_previous_observed = primary_year - previous_observed_year,
    distance_from_previous_observed_year_centroid_m = sqrt(
      (ax_obs - previous_ax_obs)^2 +
        (ay_obs - previous_ay_obs)^2
    )
  ) %>%
  ungroup()

annual_centres <- annual_centres_all %>%
  inner_join(windows, by = "tattoo", relationship = "many-to-many") %>%
  filter(
    primary_year >= window_start,
    primary_year <= window_end
  ) %>%
  arrange(active_index, primary_year)

# -----------------------------------------------------------------------------
# Focal interval descriptive summaries
# -----------------------------------------------------------------------------
from_stats <- annual_centres_all %>%
  select(
    tattoo,
    from_year = primary_year,
    from_n_captures = n_captures,
    from_n_quarters = n_quarters_observed,
    from_n_setts = n_setts,
    from_setts = setts,
    from_ax_obs = ax_obs,
    from_ay_obs = ay_obs
  )

to_stats <- annual_centres_all %>%
  select(
    tattoo,
    to_year = primary_year,
    to_n_captures = n_captures,
    to_n_quarters = n_quarters_observed,
    to_n_setts = n_setts,
    to_setts = setts,
    to_ax_obs = ax_obs,
    to_ay_obs = ay_obs
  )

interval_audit <- discordant %>%
  left_join(from_stats, by = c("tattoo", "from_year")) %>%
  left_join(to_stats, by = c("tattoo", "to_year")) %>%
  mutate(
    observed_annual_centroid_jump_m = sqrt(
      (to_ax_obs - from_ax_obs)^2 +
        (to_ay_obs - from_ay_obs)^2
    )
  )

# Add first/last observed quarterly centroids in each side of the transition.
from_q <- quarter_centres_all %>%
  group_by(tattoo, primary_year) %>%
  slice_max(trap_season, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(
    tattoo,
    from_year = primary_year,
    from_last_q = trap_season,
    from_last_qx = qx,
    from_last_qy = qy,
    from_last_q_setts = setts
  )

to_q <- quarter_centres_all %>%
  group_by(tattoo, primary_year) %>%
  slice_min(trap_season, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(
    tattoo,
    to_year = primary_year,
    to_first_q = trap_season,
    to_first_qx = qx,
    to_first_qy = qy,
    to_first_q_setts = setts
  )

interval_audit <- interval_audit %>%
  left_join(from_q, by = c("tattoo", "from_year")) %>%
  left_join(to_q, by = c("tattoo", "to_year")) %>%
  mutate(
    observed_lastQ_to_firstQ_jump_m = sqrt(
      (to_first_qx - from_last_qx)^2 +
        (to_first_qy - from_last_qy)^2
    )
  ) %>%
  arrange(desc(max_chain_difference), desc(p_high_pooled))

# -----------------------------------------------------------------------------
# Neighbouring annual posterior movement states for each discordant animal
# -----------------------------------------------------------------------------
state_neighbourhood <- disp %>%
  filter(tattoo %in% discordant_animals) %>%
  inner_join(
    windows %>%
      select(
        focal_active_index = active_index,
        tattoo,
        focal_from_year,
        focal_to_year,
        window_start,
        window_end
      ),
    by = "tattoo",
    relationship = "many-to-many"
  ) %>%
  filter(
    from_year >= window_start,
    to_year <= window_end
  ) %>%
  mutate(
    is_focal_interval = active_index == focal_active_index
  ) %>%
  arrange(focal_active_index, from_year)

# -----------------------------------------------------------------------------
# Compact console report
# -----------------------------------------------------------------------------
cat("\n============================================================\n")
cat("DISCORDANT INTERVALS: OBSERVED SPATIAL EVIDENCE\n")
cat("============================================================\n")

console_tbl <- interval_audit %>%
  select(
    tattoo,
    sex_class,
    age_entry_class,
    from_year,
    to_year,
    p_high_chain1,
    p_high_chain2,
    p_high_chain3,
    p_high_pooled,
    max_chain_difference,
    from_n_captures,
    from_n_quarters,
    to_n_captures,
    to_n_quarters,
    observed_annual_centroid_jump_m,
    observed_lastQ_to_firstQ_jump_m,
    from_setts,
    to_setts
  )

print(console_tbl, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("DISCORDANCE CLUSTERING BY BADGER\n")
cat("============================================================\n")

safe_median <- function(z) {
  z <- z[is.finite(z)]
  if (!length(z)) return(NA_real_)
  median(z)
}

safe_max <- function(z) {
  z <- z[is.finite(z)]
  if (!length(z)) return(NA_real_)
  max(z)
}

animal_summary <- interval_audit %>%
  group_by(tattoo, sex_class, age_entry_class) %>%
  summarise(
    n_discordant_intervals = n(),
    max_chain_difference = max(max_chain_difference),
    median_observed_annual_jump_m = safe_median(
      observed_annual_centroid_jump_m
    ),
    max_observed_annual_jump_m = safe_max(
      observed_annual_centroid_jump_m
    ),
    .groups = "drop"
  ) %>%
  arrange(desc(n_discordant_intervals), desc(max_chain_difference))

print(animal_summary, n = Inf, width = Inf)

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------
write_csv(
  interval_audit,
  paste0(prefix, "_discordant_interval_audit.csv")
)

write_csv(
  capture_history,
  paste0(prefix, "_discordant_capture_history.csv")
)

write_csv(
  quarter_centres,
  paste0(prefix, "_discordant_quarter_centres.csv")
)

write_csv(
  annual_centres,
  paste0(prefix, "_discordant_annual_centres.csv")
)

write_csv(
  state_neighbourhood,
  paste0(prefix, "_discordant_state_neighbourhood.csv")
)

cat("\nSaved:\n")
cat(paste0(prefix, "_discordant_interval_audit.csv\n"))
cat(paste0(prefix, "_discordant_capture_history.csv\n"))
cat(paste0(prefix, "_discordant_quarter_centres.csv\n"))
cat(paste0(prefix, "_discordant_annual_centres.csv\n"))
cat(paste0(prefix, "_discordant_state_neighbourhood.csv\n"))

cat("\nAUDIT COMPLETE\n")
