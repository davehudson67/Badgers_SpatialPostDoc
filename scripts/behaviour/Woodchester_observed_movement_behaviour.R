# =============================================================================
# WOODCHESTER - OBSERVED BEHAVIOURAL MOVEMENT ANALYSIS
#
# PRE-SPECIFIED QUESTIONS
# 1. Among badger-quarters with >=2 captures, what predicts being observed at
#    >1 sett?  This is the sett-switching model and explicitly adjusts for
#    observation opportunity.
# 2. Among observed different-sett transitions, what predicts displacement
#    magnitude?
# 3. Among transitions with usable historical capture-level social groups, what
#    predicts crossing a social-group boundary?
#
# This script intentionally does NOT include disease status or V11S latent
# movement state. Those are later, separately pre-specified extensions.
#
# OUTPUTS
#   results/behaviour_repeat_capture_quarters.csv
#   results/behaviour_observed_sett_transitions.csv
#   results/behaviour_sett_switching_parametric.csv
#   results/behaviour_distance_parametric.csv
#   results/behaviour_cross_group_parametric.csv   (when supported)
#   logs/behavioural_movement_models.txt
# =============================================================================

library(tidyverse)
library(mgcv)

encounter_file <- "data/badger_encounters_useful.rds"
population_file <- "results/V7_population_inclusion_audit.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
resident_file <- "results/annual_resident_social_group_vicente.csv"

enc <- readRDS(encounter_file)
pop_obj <- readRDS(population_file)
sett_raw <- read_csv(sett_file, show_col_types = FALSE)

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

clean_group <- function(x) {
  z <- x %>%
    as.character() %>%
    toupper() %>%
    str_squish()

  z[z %in% c("", "NA", "N/A", "UNKNOWN", "UNK", "NOT KNOWN")] <- NA_character_
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

# ---- population attributes ---------------------------------------------------
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

resident <- if (file.exists(resident_file)) {
  read_csv(resident_file, show_col_types = FALSE) %>%
    transmute(
      tattoo = toupper(trimws(as.character(tattoo))),
      primary_year = as.integer(primary_year),
      resident_group = clean_group(resident_group),
      resident_assignment_criterion = as.integer(assignment_criterion)
    )
} else {
  tibble(
    tattoo = character(),
    primary_year = integer(),
    resident_group = character(),
    resident_assignment_criterion = integer()
  )
}

# ---- sett coordinates --------------------------------------------------------
name_col <- find_first_col(
  names(sett_raw),
  c("Sett_Clean", "Sett", "sett", "SettName", "Sett_Upper", "Name")
)
x_col <- find_first_col(
  names(sett_raw),
  c("SettX", "sett_x", "X", "x", "Easting", "easting")
)
y_col <- find_first_col(
  names(sett_raw),
  c("SettY", "sett_y", "Y", "y", "Northing", "northing")
)

if (any(is.na(c(name_col, x_col, y_col)))) {
  stop("Could not identify sett name/X/Y columns.")
}

sett_xy <- sett_raw %>%
  transmute(
    sett_clean = clean_sett2(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(!is.na(sett_clean), sett_clean != "", !is.na(x), !is.na(y)) %>%
  distinct(sett_clean, x, y)

if (nrow(sett_xy %>% count(sett_clean) %>% filter(n > 1L))) {
  stop("A cleaned sett maps to >1 coordinate pair.")
}

# ---- capture table -----------------------------------------------------------
cap <- enc %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    capture_date = as.Date(capture_date),
    has_live_capture = as.logical(has_live_capture),
    sett_clean = clean_sett2(sett),
    capture_group = if (!is.na(group_col)) {
      clean_group(.data[[group_col]])
    } else {
      NA_character_
    }
  ) %>%
  filter(
    has_live_capture,
    tattoo %in% pop$tattoo,
    !is.na(primary_year),
    primary_year <= 2025,
    trap_season %in% 1:4,
    !is.na(capture_date),
    !is.na(sett_clean),
    sett_clean != ""
  ) %>%
  left_join(pop, by = "tattoo") %>%
  left_join(age, by = c("tattoo", "primary_year")) %>%
  left_join(resident, by = c("tattoo", "primary_year")) %>%
  arrange(tattoo, primary_year, trap_season, capture_date, sett_clean)

# ---- 1. repeat-capture quarter dataset --------------------------------------
quarter <- cap %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(
    sex = first(sex),
    age_class = first(age_class),
    resident_group = first(resident_group),
    resident_assignment_criterion = first(resident_assignment_criterion),
    n_capture_records = n(),
    n_capture_dates = n_distinct(capture_date),
    n_distinct_setts = n_distinct(sett_clean),
    first_capture = min(capture_date),
    last_capture = max(capture_date),
    quarter_span_days = as.integer(last_capture - first_capture),
    .groups = "drop"
  ) %>%
  filter(n_capture_records >= 2L) %>%
  mutate(
    switched_sett = as.integer(n_distinct_setts > 1L),
    sex = factor(sex, levels = c("Female", "Male")),
    age_class = factor(
      coalesce(age_class, "Unknown"),
      levels = c("0-1", "2", "3-5", "6+", "Unknown")
    ),
    season = factor(trap_season),
    n_capture_factor = factor(n_capture_records),
    year_factor = factor(primary_year),
    tattoo_factor = factor(tattoo),
    resident_group_factor = factor(resident_group),
    log_span = log1p(quarter_span_days)
  )

write_csv(quarter, "results/behaviour_repeat_capture_quarters.csv")

cat("\n============================================================\n")
cat("BEHAVIOUR MODEL 1: OBSERVED WITHIN-QUARTER SETT SWITCHING\n")
cat("============================================================\n")
cat("Repeat-captured quarters:", nrow(quarter), "\n")
cat("Multi-sett quarters:", sum(quarter$switched_sett), "\n")
cat(
  "Observed switch probability conditional on repeat capture:",
  round(mean(quarter$switched_sett), 4), "\n"
)

# Primary model. The random badger effect asks whether persistent individual
# switching propensity remains after correcting for observation opportunity.
fit_switch <- gam(
  switched_sett ~
    sex +
    age_class +
    season +
    n_capture_factor +
    s(log_span, k = 5) +
    s(year_factor, bs = "re") +
    s(tattoo_factor, bs = "re"),
  data = quarter,
  family = binomial(link = "logit"),
  method = "REML"
)

print(summary(fit_switch))
cat("\nVariance components:\n")
print(gam.vcomp(fit_switch))

switch_param <- as.data.frame(summary(fit_switch)$p.table) %>%
  rownames_to_column("term") %>%
  as_tibble()

write_csv(
  switch_param,
  "results/behaviour_sett_switching_parametric.csv"
)

# ---- 2. observed consecutive different-sett transitions ---------------------
transitions <- cap %>%
  left_join(sett_xy, by = "sett_clean") %>%
  filter(!is.na(x), !is.na(y)) %>%
  group_by(tattoo, primary_year, trap_season) %>%
  arrange(capture_date, sett_clean, .by_group = TRUE) %>%
  mutate(
    from_date = lag(capture_date),
    from_sett = lag(sett_clean),
    from_group = lag(capture_group),
    from_x = lag(x),
    from_y = lag(y),
    to_date = capture_date,
    to_sett = sett_clean,
    to_group = capture_group,
    to_x = x,
    to_y = y,
    days_between = as.integer(to_date - from_date),
    distance_m = sqrt((to_x - from_x)^2 + (to_y - from_y)^2),
    changed_sett = !is.na(from_sett) & from_sett != to_sett
  ) %>%
  filter(!is.na(from_date), changed_sett) %>%
  ungroup() %>%
  mutate(
    cross_group = case_when(
      !is.na(from_group) & !is.na(to_group) ~ from_group != to_group,
      TRUE ~ NA
    ),
    from_resident = case_when(
      !is.na(from_group) & !is.na(resident_group) ~ from_group == resident_group,
      TRUE ~ NA
    ),
    to_resident = case_when(
      !is.na(to_group) & !is.na(resident_group) ~ to_group == resident_group,
      TRUE ~ NA
    ),
    transition_type = case_when(
      is.na(from_group) | is.na(to_group) | is.na(resident_group) ~
        "group unresolved",
      from_group == to_group ~
        "same-group sett switch",
      from_group == resident_group & to_group != resident_group ~
        "resident -> other group",
      from_group != resident_group & to_group == resident_group ~
        "other group -> resident",
      from_group != resident_group & to_group != resident_group &
        from_group != to_group ~
        "nonresident group -> different nonresident group",
      TRUE ~ "cross-group other"
    ),
    sex = factor(sex, levels = c("Female", "Male")),
    age_class = factor(
      coalesce(age_class, "Unknown"),
      levels = c("0-1", "2", "3-5", "6+", "Unknown")
    ),
    season = factor(trap_season),
    year_factor = factor(primary_year),
    tattoo_factor = factor(tattoo),
    log_days = log1p(days_between),
    log_distance = log(distance_m)
  )

write_csv(
  transitions,
  "results/behaviour_observed_sett_transitions.csv"
)

cat("\n============================================================\n")
cat("BEHAVIOUR MODEL 2: OBSERVED SETT-TO-SETT DISTANCE\n")
cat("============================================================\n")
cat("Observed different-sett transitions:", nrow(transitions), "\n")

fit_distance <- gam(
  log_distance ~
    sex +
    age_class +
    season +
    s(log_days, k = 5) +
    s(year_factor, bs = "re") +
    s(tattoo_factor, bs = "re"),
  data = transitions,
  family = gaussian(),
  method = "REML"
)

print(summary(fit_distance))
cat("\nVariance components:\n")
print(gam.vcomp(fit_distance))

distance_param <- as.data.frame(summary(fit_distance)$p.table) %>%
  rownames_to_column("term") %>%
  as_tibble()

write_csv(
  distance_param,
  "results/behaviour_distance_parametric.csv"
)

# ---- 3. historical capture-group crossing -----------------------------------
cross_dat <- transitions %>%
  filter(!is.na(cross_group)) %>%
  mutate(
    cross_group_int = as.integer(cross_group),
    resident_group_factor = factor(resident_group)
  )

cat("\n============================================================\n")
cat("BEHAVIOUR MODEL 3: OBSERVED SOCIAL-GROUP CROSSING\n")
cat("============================================================\n")
cat("Transitions with both capture-level groups resolved:", nrow(cross_dat), "\n")

if (nrow(cross_dat) >= 100L && length(unique(cross_dat$cross_group_int)) == 2L) {
  cat("Cross-group transitions:", sum(cross_dat$cross_group_int), "\n")
  cat(
    "Observed cross-group proportion:",
    round(mean(cross_dat$cross_group_int), 4), "\n"
  )

  # Distance is included deliberately: this asks what predicts group crossing
  # beyond the obvious geometric fact that farther sett pairs are more likely
  # to belong to different groups.
  fit_cross <- gam(
    cross_group_int ~
      sex +
      age_class +
      season +
      s(log_days, k = 5) +
      s(log_distance, k = 5) +
      s(year_factor, bs = "re") +
      s(tattoo_factor, bs = "re"),
    data = cross_dat,
    family = binomial(link = "logit"),
    method = "REML"
  )

  print(summary(fit_cross))
  cat("\nVariance components:\n")
  print(gam.vcomp(fit_cross))

  cross_param <- as.data.frame(summary(fit_cross)$p.table) %>%
    rownames_to_column("term") %>%
    as_tibble()

  write_csv(
    cross_param,
    "results/behaviour_cross_group_parametric.csv"
  )
} else {
  cat(
    "Insufficient resolved capture-level group information for the pre-specified ",
    "cross-group model. No model fitted.\n",
    sep = ""
  )
}

cat("\nTransition types relative to annual resident group:\n")
print(
  transitions %>%
    count(transition_type, sort = TRUE),
  n = Inf
)

cat("\nSaved behavioural datasets and model summaries in results/.\n")
