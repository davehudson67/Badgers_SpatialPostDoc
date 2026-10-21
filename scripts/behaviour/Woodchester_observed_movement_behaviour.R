# =============================================================================
# WOODCHESTER - OBSERVED BEHAVIOURAL MOVEMENT ANALYSIS
#
# PRE-SPECIFIED QUESTIONS / TIME SCALES
#
# B1. WITHIN QUARTER
#     Among badger-quarters with >=2 captures, what predicts being observed at
#     >1 sett?  Explicitly adjust for opportunity (capture count and time span).
#
# B2. ADJACENT QUARTER -> QUARTER
#     For consecutive trapping campaigns in which the badger was observed,
#     what predicts whether its last observed sett in quarter q differs from
#     its first observed sett in q+1?  What predicts cross-group movement?
#
# B3. OBSERVED DISPLACEMENT MAGNITUDE
#     Among consecutive capture events at different mapped setts, what predicts
#     straight-line displacement?  Distinguish within-quarter, adjacent-quarter
#     and longer-gap observation windows.
#
# B4. SOCIAL-GROUP BRIDGING
#     Where contemporaneous capture-level groups are resolved, what predicts a
#     same-group versus cross-group transition, and how does that transition
#     relate to the annual resident group?
#
# This script intentionally does NOT include disease status or V11S latent
# movement state. Those are later, separately pre-specified extensions.
#
# IMPORTANT
#   Quarter-to-quarter behaviour is based on observed capture endpoints, NOT a
#   reconstructed quarterly activity centre.  For adjacent quarters, the
#   relevant transition is the last capture in q -> first capture in q+1.
#
# OUTPUTS
#   results/behaviour_repeat_capture_quarters.csv
#   results/behaviour_all_consecutive_capture_transitions.csv
#   results/behaviour_adjacent_quarter_transitions.csv
#   results/behaviour_observed_sett_transitions.csv
#   results/behaviour_sett_switching_parametric.csv
#   results/behaviour_adjacent_quarter_sett_switching_parametric.csv
#   results/behaviour_adjacent_quarter_cross_group_parametric.csv
#   results/behaviour_distance_parametric.csv
#   results/behaviour_cross_group_parametric.csv
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
  left_join(sett_xy, by = "sett_clean") %>%
  arrange(tattoo, capture_date, primary_year, trap_season, sett_clean) %>%
  mutate(
    quarter_index = primary_year * 4L + trap_season
  )

# =============================================================================
# B1. WITHIN-QUARTER REPEAT-CAPTURE SETT SWITCHING
# =============================================================================

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
    n_distinct_capture_groups = n_distinct(capture_group, na.rm = TRUE),
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
    log_span = log1p(quarter_span_days)
  )

write_csv(quarter, "results/behaviour_repeat_capture_quarters.csv")

cat("\n============================================================\n")
cat("B1: OBSERVED WITHIN-QUARTER SETT SWITCHING\n")
cat("============================================================\n")
cat("Repeat-captured quarters:", nrow(quarter), "\n")
cat("Multi-sett quarters:", sum(quarter$switched_sett), "\n")
cat(
  "Observed switch probability conditional on repeat capture:",
  round(mean(quarter$switched_sett), 4), "\n"
)

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

write_csv(
  as.data.frame(summary(fit_switch)$p.table) %>%
    rownames_to_column("term") %>%
    as_tibble(),
  "results/behaviour_sett_switching_parametric.csv"
)

# =============================================================================
# BUILD COMPLETE ORDERED CAPTURE-TO-CAPTURE TRANSITION HISTORY
# =============================================================================
#
# This uses ALL consecutive usable live captures for each badger.
#
# quarter_gap = 0  : within the same trapping quarter
# quarter_gap = 1  : adjacent trapping quarters, including Q4 -> next-year Q1
# quarter_gap >= 2 : longer observational gap
#
# Hence adjacent-quarter transitions are naturally the last capture in quarter q
# -> first capture in quarter q+1.  We do not invent a quarterly centroid.

all_transitions <- cap %>%
  group_by(tattoo) %>%
  arrange(capture_date, quarter_index, sett_clean, .by_group = TRUE) %>%
  mutate(
    from_date = lag(capture_date),
    from_year = lag(primary_year),
    from_season = lag(trap_season),
    from_quarter_index = lag(quarter_index),
    from_sett = lag(sett_clean),
    from_group = lag(capture_group),
    from_resident_group = lag(resident_group),
    from_resident_criterion = lag(resident_assignment_criterion),
    from_x = lag(x),
    from_y = lag(y),

    to_date = capture_date,
    to_year = primary_year,
    to_season = trap_season,
    to_quarter_index = quarter_index,
    to_sett = sett_clean,
    to_group = capture_group,
    to_resident_group = resident_group,
    to_resident_criterion = resident_assignment_criterion,
    to_x = x,
    to_y = y,

    days_between = as.integer(to_date - from_date),
    quarter_gap = to_quarter_index - from_quarter_index,

    changed_sett = !is.na(from_sett) & from_sett != to_sett,

    distance_m = case_when(
      !is.na(from_x) & !is.na(from_y) & !is.na(to_x) & !is.na(to_y) ~
        sqrt((to_x - from_x)^2 + (to_y - from_y)^2),
      TRUE ~ NA_real_
    ),

    cross_group = case_when(
      !is.na(from_group) & !is.na(to_group) ~ from_group != to_group,
      TRUE ~ NA
    ),

    temporal_scale = case_when(
      quarter_gap == 0L ~ "within_quarter",
      quarter_gap == 1L ~ "adjacent_quarter",
      quarter_gap >= 2L ~ "longer_gap",
      TRUE ~ "unresolved"
    ),

    from_is_resident = case_when(
      !is.na(from_group) & !is.na(from_resident_group) ~
        from_group == from_resident_group,
      TRUE ~ NA
    ),

    to_is_resident = case_when(
      !is.na(to_group) & !is.na(to_resident_group) ~
        to_group == to_resident_group,
      TRUE ~ NA
    ),

    transition_type = case_when(
      is.na(from_group) | is.na(to_group) ~
        "group unresolved",
      from_group == to_group ~
        "same-group",
      !is.na(from_resident_group) &
        from_group == from_resident_group &
        to_group != from_resident_group ~
        "resident -> other group",
      !is.na(to_resident_group) &
        from_group != to_resident_group &
        to_group == to_resident_group ~
        "other group -> resident",
      from_group != to_group ~
        "cross-group other",
      TRUE ~ "group unresolved"
    )
  ) %>%
  filter(!is.na(from_date), days_between >= 0L, quarter_gap >= 0L) %>%
  ungroup() %>%
  mutate(
    sex = factor(sex, levels = c("Female", "Male")),
    age_class = factor(
      coalesce(age_class, "Unknown"),
      levels = c("0-1", "2", "3-5", "6+", "Unknown")
    ),
    season = factor(to_season),
    year_factor = factor(to_year),
    tattoo_factor = factor(tattoo),
    temporal_scale = factor(
      temporal_scale,
      levels = c("within_quarter", "adjacent_quarter", "longer_gap")
    ),
    log_days = log1p(days_between),
    log_distance = if_else(distance_m > 0, log(distance_m), NA_real_),
    log1p_distance = if_else(!is.na(distance_m), log1p(distance_m), NA_real_)
  )

write_csv(
  all_transitions,
  "results/behaviour_all_consecutive_capture_transitions.csv"
)

cat("\n============================================================\n")
cat("COMPLETE CONSECUTIVE CAPTURE TRANSITION HISTORY\n")
cat("============================================================\n")
cat("All consecutive usable transitions:", nrow(all_transitions), "\n")
print(all_transitions %>% count(temporal_scale, sort = FALSE), n = Inf)

cat("\nObserved sett-change proportion by temporal scale:\n")
print(
  all_transitions %>%
    filter(!is.na(temporal_scale)) %>%
    group_by(temporal_scale) %>%
    summarise(
      n = n(),
      n_changed_sett = sum(changed_sett),
      prop_changed_sett = mean(changed_sett),
      median_days = median(days_between),
      .groups = "drop"
    ),
  n = Inf
)

cat("\nObserved social-group-change proportion by temporal scale:\n")
print(
  all_transitions %>%
    filter(!is.na(cross_group), !is.na(temporal_scale)) %>%
    group_by(temporal_scale) %>%
    summarise(
      n_resolved = n(),
      n_cross_group = sum(cross_group),
      prop_cross_group = mean(cross_group),
      .groups = "drop"
    ),
  n = Inf
)

# =============================================================================
# B2. ADJACENT QUARTER -> QUARTER
# =============================================================================

adjacent_q <- all_transitions %>%
  filter(quarter_gap == 1L) %>%
  mutate(
    changed_sett_int = as.integer(changed_sett)
  )

write_csv(
  adjacent_q,
  "results/behaviour_adjacent_quarter_transitions.csv"
)

cat("\n============================================================\n")
cat("B2: ADJACENT QUARTER -> QUARTER OBSERVED MOVEMENT\n")
cat("============================================================\n")
cat("Adjacent-quarter observed transitions:", nrow(adjacent_q), "\n")
cat("Different-sett transitions:", sum(adjacent_q$changed_sett), "\n")
cat(
  "Different-sett proportion:",
  round(mean(adjacent_q$changed_sett), 4), "\n"
)

# This asks whether location changes between consecutive observed campaigns.
# days_between is retained because trapping dates vary within campaigns.
fit_adj_sett <- gam(
  changed_sett_int ~
    sex +
    age_class +
    season +
    s(log_days, k = 5) +
    s(year_factor, bs = "re") +
    s(tattoo_factor, bs = "re"),
  data = adjacent_q,
  family = binomial(link = "logit"),
  method = "REML"
)

print(summary(fit_adj_sett))
cat("\nVariance components:\n")
print(gam.vcomp(fit_adj_sett))

write_csv(
  as.data.frame(summary(fit_adj_sett)$p.table) %>%
    rownames_to_column("term") %>%
    as_tibble(),
  "results/behaviour_adjacent_quarter_sett_switching_parametric.csv"
)

adjacent_q_cross <- adjacent_q %>%
  filter(!is.na(cross_group)) %>%
  mutate(cross_group_int = as.integer(cross_group))

cat("\nAdjacent-quarter transitions with both groups resolved:",
    nrow(adjacent_q_cross), "\n")

if (
  nrow(adjacent_q_cross) >= 100L &&
  length(unique(adjacent_q_cross$cross_group_int)) == 2L
) {
  cat("Adjacent-quarter cross-group transitions:",
      sum(adjacent_q_cross$cross_group_int), "\n")
  cat(
    "Adjacent-quarter cross-group proportion:",
    round(mean(adjacent_q_cross$cross_group_int), 4), "\n"
  )

  fit_adj_cross <- gam(
    cross_group_int ~
      sex +
      age_class +
      season +
      s(log_days, k = 5) +
      s(year_factor, bs = "re") +
      s(tattoo_factor, bs = "re"),
    data = adjacent_q_cross,
    family = binomial(link = "logit"),
    method = "REML"
  )

  print(summary(fit_adj_cross))
  cat("\nVariance components:\n")
  print(gam.vcomp(fit_adj_cross))

  write_csv(
    as.data.frame(summary(fit_adj_cross)$p.table) %>%
      rownames_to_column("term") %>%
      as_tibble(),
    "results/behaviour_adjacent_quarter_cross_group_parametric.csv"
  )
} else {
  cat("Insufficient resolved adjacent-quarter group transitions for B2 group model.\n")
}

# =============================================================================
# B3. OBSERVED DIFFERENT-SETT DISPLACEMENT MAGNITUDE
# =============================================================================

sett_transitions <- all_transitions %>%
  filter(changed_sett, !is.na(distance_m), distance_m > 0)

write_csv(
  sett_transitions,
  "results/behaviour_observed_sett_transitions.csv"
)

cat("\n============================================================\n")
cat("B3: OBSERVED SETT-TO-SETT DISTANCE\n")
cat("============================================================\n")
cat("Observed different-sett transitions:", nrow(sett_transitions), "\n")
print(
  sett_transitions %>%
    group_by(temporal_scale) %>%
    summarise(
      n = n(),
      median_distance_m = median(distance_m),
      q25 = quantile(distance_m, .25),
      q75 = quantile(distance_m, .75),
      q95 = quantile(distance_m, .95),
      .groups = "drop"
    ),
  n = Inf
)

fit_distance <- gam(
  log_distance ~
    sex +
    age_class +
    season +
    temporal_scale +
    s(log_days, k = 5) +
    s(year_factor, bs = "re") +
    s(tattoo_factor, bs = "re"),
  data = sett_transitions,
  family = gaussian(),
  method = "REML"
)

print(summary(fit_distance))
cat("\nVariance components:\n")
print(gam.vcomp(fit_distance))

write_csv(
  as.data.frame(summary(fit_distance)$p.table) %>%
    rownames_to_column("term") %>%
    as_tibble(),
  "results/behaviour_distance_parametric.csv"
)

# =============================================================================
# B4. OBSERVED SOCIAL-GROUP BRIDGING ACROSS ALL CONSECUTIVE CAPTURES
# =============================================================================

cross_dat <- all_transitions %>%
  filter(!is.na(cross_group)) %>%
  mutate(
    cross_group_int = as.integer(cross_group)
  )

cat("\n============================================================\n")
cat("B4: OBSERVED SOCIAL-GROUP CROSSING\n")
cat("============================================================\n")
cat("Transitions with both capture-level groups resolved:", nrow(cross_dat), "\n")

if (nrow(cross_dat) >= 100L && length(unique(cross_dat$cross_group_int)) == 2L) {
  cat("Cross-group transitions:", sum(cross_dat$cross_group_int), "\n")
  cat(
    "Observed cross-group proportion:",
    round(mean(cross_dat$cross_group_int), 4), "\n"
  )

  # Include all spatially resolved transitions, including same-sett events.
  # log1p(distance) is defined at zero, avoiding selection on different-sett
  # transitions and keeping the model aligned with the printed denominator.
  cross_spatial <- cross_dat %>%
    filter(!is.na(log1p_distance))

  fit_cross <- gam(
    cross_group_int ~
      sex +
      age_class +
      season +
      temporal_scale +
      s(log_days, k = 5) +
      s(log1p_distance, k = 5) +
      s(year_factor, bs = "re") +
      s(tattoo_factor, bs = "re"),
    data = cross_spatial,
    family = binomial(link = "logit"),
    method = "REML"
  )

  cat("Spatially resolved transitions used in B4:", nrow(cross_spatial), "\n")
  print(summary(fit_cross))
  cat("\nVariance components:\n")
  print(gam.vcomp(fit_cross))

  write_csv(
    as.data.frame(summary(fit_cross)$p.table) %>%
      rownames_to_column("term") %>%
      as_tibble(),
    "results/behaviour_cross_group_parametric.csv"
  )
} else {
  cat(
    "Insufficient resolved capture-level group information for B4. ",
    "No cross-group model fitted.\n",
    sep = ""
  )
}

cat("\nTransition types relative to annual resident-group histories:\n")
print(
  all_transitions %>%
    count(temporal_scale, transition_type, sort = TRUE),
  n = Inf
)

cat("\nSaved behavioural datasets and model summaries in results/.\n")
