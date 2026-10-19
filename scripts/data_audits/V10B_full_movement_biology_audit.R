# =============================================================================
# V10B FULL MOVEMENT-BIOLOGY AUDIT
#
# PURPOSE
#   Diagnose what the fitted annual movement process is biologically describing
#   BEFORE adding more structure to the SCR/HMM.
#
#   This is deliberately an audit, not a new inferential model. It combines:
#     1. cross-chain movement-state / trajectory agreement;
#     2. robust local vs high-mobility intervals;
#     3. temporary-return vs settled-relocation vs continued-mobility patterns;
#     4. recurrent / frequent mover concentration among individuals;
#     5. sex and age structure;
#     6. recorded historical social-group changes;
#     7. temporal patterns around the 2018 cull;
#     8. observed within-year capture spread around the cull;
#     9. calendar-time composition and observed sampling-footprint checks;
#    10. whether within-year spread tracks annual relocation/recurrent movers;
#    11. rho/omega/global-ridge outputs where available;
#    12. annotation of the remaining computationally difficult intervals.
#
# IMPORTANT INTERPRETATION
#   * "robust high" means ALL THREE chains have p(high) >= HIGH_CUT.
#   * "robust local" means ALL THREE chains have p(high) <= LOW_CUT.
#   * excursion / relocation labels are descriptive candidate patterns based on
#     posterior-mean annual centres and are NOT extra latent states.
#   * recorded social group is an historical capture-level observation, not a
#     static true lifetime group assignment.
#   * the 2018 analysis here is temporal/descriptive only. It is NOT a causal
#     cull-effect model and does not yet use spatial cull exposure.
#   * observed annual capture spread is NOT a home-range estimator. It is a
#     data-level diagnostic of within-year spatial breadth. Repeated captures
#     at one sett are retained as zero observed spread (not treated as missing).
#
# REQUIRED INPUTS
#   results/<FILE_STEM>_<N>_trajectory_chain_diagnostic<OUTPUT_SUFFIX>.csv
#   results/<FILE_STEM>_<N>_trajectory_chain_summary<OUTPUT_SUFFIX>.csv
#   results/V7_population_inclusion_audit.rds
#   data/badger_encounters_useful.rds
#   data/WoodchesterSettLocations.csv
#
# OPTIONAL INPUTS
#   results/<FILE_STEM>_<N>_global_ridge_segments.csv
#   results/<FILE_STEM>_<N>_global_ridge_convergence.csv
#
# ENVIRONMENT
#   FILE_STEM       fitted result stem
#   MAX_BADGERS     default 1932
#   OUTPUT_SUFFIX   e.g. _TAIL22500
#   HIGH_CUT        default 0.80
#   LOW_CUT         default 0.20
#   RETURN_RATIO    default 0.50
#   GEOM_SEP_M      max cross-chain endpoint separation for geometric pattern
#                   classification; default 150 m
#   CULL_YEAR       default 2018
#   CULL_WINDOW     years either side in event-window outputs; default 6
#
# OUTPUT PREFIX
#   results/<FILE_STEM>_<N>_movement_biology_audit<OUTPUT_SUFFIX>_*
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "1932"))
FILE_STEM <- Sys.getenv(
  "FILE_STEM",
  unset = "V10B_RD_MULTILOC_AR1_COLLAPSED_ANNUALNC_OVERLAP"
)
OUTPUT_SUFFIX <- Sys.getenv("OUTPUT_SUFFIX", unset = "")
HIGH_CUT <- as.numeric(Sys.getenv("HIGH_CUT", unset = "0.80"))
LOW_CUT <- as.numeric(Sys.getenv("LOW_CUT", unset = "0.20"))
RETURN_RATIO <- as.numeric(Sys.getenv("RETURN_RATIO", unset = "0.50"))
GEOM_SEP_M <- as.numeric(Sys.getenv("GEOM_SEP_M", unset = "150"))
CULL_YEAR <- as.integer(Sys.getenv("CULL_YEAR", unset = "2018"))
CULL_WINDOW <- as.integer(Sys.getenv("CULL_WINDOW", unset = "6"))

if (!is.finite(MAX_BADGERS) || MAX_BADGERS < 2L) {
  stop("MAX_BADGERS must be >=2.")
}
if (!is.finite(HIGH_CUT) || !is.finite(LOW_CUT) ||
    LOW_CUT < 0 || HIGH_CUT > 1 || LOW_CUT >= HIGH_CUT) {
  stop("Require 0 <= LOW_CUT < HIGH_CUT <= 1.")
}
if (!is.finite(RETURN_RATIO) || RETURN_RATIO <= 0) {
  stop("RETURN_RATIO must be >0.")
}
if (!is.finite(GEOM_SEP_M) || GEOM_SEP_M <= 0) {
  stop("GEOM_SEP_M must be >0.")
}

base_prefix <- file.path("results", paste0(FILE_STEM, "_", MAX_BADGERS))
traj_file <- paste0(
  base_prefix,
  "_trajectory_chain_diagnostic",
  OUTPUT_SUFFIX,
  ".csv"
)
traj_summary_file <- paste0(
  base_prefix,
  "_trajectory_chain_summary",
  OUTPUT_SUFFIX,
  ".csv"
)
ridge_segments_file <- paste0(
  base_prefix,
  "_global_ridge_segments.csv"
)
ridge_conv_file <- paste0(
  base_prefix,
  "_global_ridge_convergence.csv"
)

population_file <- "results/V7_population_inclusion_audit.rds"
encounter_file <- "data/badger_encounters_useful.rds"
sett_file <- "data/WoodchesterSettLocations.csv"

required_files <- c(
  traj_file,
  traj_summary_file,
  population_file,
  encounter_file,
  sett_file
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files)) {
  stop("Missing required file(s):\n", paste(missing_files, collapse = "\n"))
}

out_prefix <- paste0(
  base_prefix,
  "_movement_biology_audit",
  OUTPUT_SUFFIX
)

cat("\n============================================================\n")
cat("V10B FULL MOVEMENT-BIOLOGY AUDIT\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("File stem:", FILE_STEM, "\n")
cat("Output suffix:", ifelse(nzchar(OUTPUT_SUFFIX), OUTPUT_SUFFIX, "<none>"), "\n")
cat("Robust high threshold: all chains >=", HIGH_CUT, "\n")
cat("Robust local threshold: all chains <=", LOW_CUT, "\n")
cat("Return ratio threshold:", RETURN_RATIO, "\n")
cat("Geometry agreement threshold:", GEOM_SEP_M, "m\n")
cat("Cull year:", CULL_YEAR, "\n\n")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
pair_distance <- function(x1, y1, x2, y2) {
  sqrt((x1 - x2)^2 + (y1 - y2)^2)
}

safe_ratio <- function(a, b) {
  ifelse(is.finite(a) & is.finite(b) & b > 0, a / b, NA_real_)
}

safe_prop <- function(x) {
  if (!length(x)) return(NA_real_)
  mean(x, na.rm = TRUE)
}

safe_median <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  median(x)
}

safe_mean <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  mean(x)
}

safe_q <- function(x, p) {
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  unname(quantile(x, p, names = FALSE))
}

gini_nonnegative <- function(x) {
  x <- x[is.finite(x) & x >= 0]
  if (!length(x) || sum(x) == 0) return(NA_real_)
  x <- sort(x)
  n <- length(x)
  (2 * sum(seq_len(n) * x) / (n * sum(x))) - (n + 1) / n
}

max_true_run <- function(x) {
  if (!length(x)) return(0L)
  rr <- rle(replace_na(as.logical(x), FALSE))
  if (!any(rr$values)) return(0L)
  max(rr$lengths[rr$values])
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

max_pair_distance <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]

  # Fewer than two observed locations cannot define a within-year spread.
  if (length(x) < 2L) return(NA_real_)

  xy <- unique(cbind(x, y))

  # Two or more captures at exactly the same sett are genuine zero observed
  # spread, not missing information. Returning NA here would condition the
  # annual median on animals that changed sett and inflate the spread metric.
  if (nrow(xy) < 2L) return(0)

  max(as.numeric(dist(xy)))
}

rms_radius <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  if (length(x) < 2L) return(NA_real_)
  sqrt(mean((x - mean(x))^2 + (y - mean(y))^2))
}

# -----------------------------------------------------------------------------
# Canonical movement interval table from the cross-chain diagnostic
# -----------------------------------------------------------------------------
traj <- read_csv(traj_file, show_col_types = FALSE)
traj_summary <- read_csv(traj_summary_file, show_col_types = FALSE)

required_traj <- c(
  "active_index", "model_i", "individual_id", "tattoo",
  "state_k", "from_year", "to_year",
  "p_high_chain1", "p_high_chain2", "p_high_chain3",
  "disp_median_chain1", "disp_median_chain2", "disp_median_chain3",
  "from_x_mean_chain1", "from_y_mean_chain1",
  "from_x_mean_chain2", "from_y_mean_chain2",
  "from_x_mean_chain3", "from_y_mean_chain3",
  "to_x_mean_chain1", "to_y_mean_chain1",
  "to_x_mean_chain2", "to_y_mean_chain2",
  "to_x_mean_chain3", "to_y_mean_chain3",
  "max_endpoint_chain_separation",
  "max_p_high_difference",
  "state_discordant",
  "trajectory_mode_signal"
)

missing_traj <- setdiff(required_traj, names(traj))
if (length(missing_traj)) {
  stop(
    "Trajectory diagnostic is missing required columns: ",
    paste(missing_traj, collapse = ", ")
  )
}

traj <- traj %>%
  mutate(
    tattoo = toupper(trimws(as.character(tattoo))),
    p_high_mean = rowMeans(
      cbind(p_high_chain1, p_high_chain2, p_high_chain3)
    ),
    p_high_min = pmin(p_high_chain1, p_high_chain2, p_high_chain3),
    p_high_max = pmax(p_high_chain1, p_high_chain2, p_high_chain3),

    robust_high = p_high_min >= HIGH_CUT,
    robust_local = p_high_max <= LOW_CUT,
    state_audit_class = case_when(
      robust_high ~ "robust_high",
      robust_local ~ "robust_local",
      TRUE ~ "uncertain"
    ),

    disp_median_consensus = apply(
      cbind(
        disp_median_chain1,
        disp_median_chain2,
        disp_median_chain3
      ),
      1,
      median,
      na.rm = TRUE
    ),

    from_x_consensus = rowMeans(
      cbind(
        from_x_mean_chain1,
        from_x_mean_chain2,
        from_x_mean_chain3
      )
    ),
    from_y_consensus = rowMeans(
      cbind(
        from_y_mean_chain1,
        from_y_mean_chain2,
        from_y_mean_chain3
      )
    ),
    to_x_consensus = rowMeans(
      cbind(
        to_x_mean_chain1,
        to_x_mean_chain2,
        to_x_mean_chain3
      )
    ),
    to_y_consensus = rowMeans(
      cbind(
        to_y_mean_chain1,
        to_y_mean_chain2,
        to_y_mean_chain3
      )
    ),
    centre_step_consensus = pair_distance(
      from_x_consensus,
      from_y_consensus,
      to_x_consensus,
      to_y_consensus
    ),

    geometry_agrees =
      max_endpoint_chain_separation <= GEOM_SEP_M,

    cull_event_time = to_year - CULL_YEAR,
    cull_phase = case_when(
      to_year < CULL_YEAR ~ "pre",
      to_year == CULL_YEAR ~ "onset_interval",
      to_year > CULL_YEAR ~ "post"
    )
  )

# -----------------------------------------------------------------------------
# Population / age / sex annotation
# -----------------------------------------------------------------------------
pop_obj <- readRDS(population_file)
if (is.null(pop_obj$population) || is.null(pop_obj$age_by_year)) {
  stop("Population audit RDS must contain $population and $age_by_year.")
}

pop <- pop_obj$population %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    individual_id = as.integer(individual_id),
    sex_class = as.character(sex_class),
    age_entry_class = as.character(age_entry_class),
    exact_age_supported = as.logical(exact_age_supported),
    inferred_birth_year = as.integer(inferred_birth_year)
  )

age_year <- pop_obj$age_by_year %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    age_years = as.integer(age_years),
    age_model_class = as.character(age_model_class)
  )

traj <- traj %>%
  left_join(pop, by = c("tattoo", "individual_id")) %>%
  left_join(
    age_year %>%
      rename(
        from_year = primary_year,
        age_from_years = age_years,
        age_from_class = age_model_class
      ),
    by = c("tattoo", "from_year")
  ) %>%
  group_by(tattoo) %>%
  arrange(from_year, to_year, .by_group = TRUE) %>%
  mutate(
    interval_number = row_number(),
    is_first_interval = interval_number == 1L,
    is_last_interval = interval_number == n()
  ) %>%
  ungroup()

# -----------------------------------------------------------------------------
# Historical recorded social-group audit
# -----------------------------------------------------------------------------
enc <- readRDS(encounter_file)

if (!all(c(
  "tattoo", "primary_year", "has_live_capture", "recorded_socg"
) %in% names(enc))) {
  stop(
    "Encounter snapshot lacks tattoo/primary_year/has_live_capture/recorded_socg."
  )
}

sg_capture <- enc %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    has_live_capture = as.logical(has_live_capture),
    recorded_socg = toupper(str_squish(as.character(recorded_socg)))
  ) %>%
  filter(
    has_live_capture,
    !is.na(primary_year),
    !is.na(recorded_socg),
    recorded_socg != ""
  )

sg_counts <- sg_capture %>%
  count(tattoo, primary_year, recorded_socg, name = "n_sg_records")

sg_year <- sg_counts %>%
  group_by(tattoo, primary_year) %>%
  mutate(
    max_n = max(n_sg_records),
    is_modal = n_sg_records == max_n
  ) %>%
  summarise(
    n_recorded_sg = n(),
    n_sg_records = sum(n_sg_records),
    sg_tie = sum(is_modal) > 1L,
    modal_recorded_sg = if_else(
      sum(is_modal) == 1L,
      recorded_socg[which(is_modal)[1]],
      NA_character_
    ),
    .groups = "drop"
  )

traj <- traj %>%
  left_join(
    sg_year %>%
      rename(
        from_year = primary_year,
        from_sg = modal_recorded_sg,
        from_sg_tie = sg_tie,
        from_n_recorded_sg = n_recorded_sg,
        from_n_sg_records = n_sg_records
      ),
    by = c("tattoo", "from_year")
  ) %>%
  left_join(
    sg_year %>%
      rename(
        to_year = primary_year,
        to_sg = modal_recorded_sg,
        to_sg_tie = sg_tie,
        to_n_recorded_sg = n_recorded_sg,
        to_n_sg_records = n_sg_records
      ),
    by = c("tattoo", "to_year")
  ) %>%
  mutate(
    sg_comparable =
      !is.na(from_sg) &
      !is.na(to_sg) &
      !replace_na(from_sg_tie, TRUE) &
      !replace_na(to_sg_tie, TRUE),
    sg_changed = case_when(
      sg_comparable ~ from_sg != to_sg,
      TRUE ~ NA
    ),
    sg_change_class = case_when(
      is.na(sg_changed) ~ "unknown_or_tied",
      sg_changed ~ "recorded_SG_changed",
      TRUE ~ "recorded_SG_same"
    )
  )

# -----------------------------------------------------------------------------
# Sequence geometry: return / relocation / continued movement candidates
# -----------------------------------------------------------------------------
traj <- traj %>%
  group_by(tattoo) %>%
  arrange(from_year, to_year, .by_group = TRUE) %>%
  mutate(
    next_from_year = lead(from_year, 1),
    next_to_year = lead(to_year, 1),
    next_robust_high = lead(robust_high, 1),
    next_robust_local = lead(robust_local, 1),
    next_geometry_agrees = lead(geometry_agrees, 1),
    next_to_x = lead(to_x_consensus, 1),
    next_to_y = lead(to_y_consensus, 1),

    next2_from_year = lead(from_year, 2),
    next2_to_year = lead(to_year, 2),
    next2_robust_high = lead(robust_high, 2),
    next2_geometry_agrees = lead(geometry_agrees, 2),
    next2_to_x = lead(to_x_consensus, 2),
    next2_to_y = lead(to_y_consensus, 2),

    next_consecutive =
      !is.na(next_from_year) &
      next_from_year == to_year,

    next2_consecutive =
      !is.na(next2_from_year) &
      next_consecutive &
      next2_from_year == next_to_year,

    immediate_return_distance = if_else(
      next_consecutive,
      pair_distance(
        from_x_consensus,
        from_y_consensus,
        next_to_x,
        next_to_y
      ),
      NA_real_
    ),
    immediate_return_ratio = safe_ratio(
      immediate_return_distance,
      centre_step_consensus
    ),

    delayed_return_distance = if_else(
      next2_consecutive,
      pair_distance(
        from_x_consensus,
        from_y_consensus,
        next2_to_x,
        next2_to_y
      ),
      NA_real_
    ),
    delayed_return_ratio = safe_ratio(
      delayed_return_distance,
      centre_step_consensus
    ),

    movement_sequence_class = case_when(
      !robust_high ~ NA_character_,

      !geometry_agrees ~
        "high_move_geometry_cross_chain_uncertain",

      next_consecutive &
        next_robust_high &
        next_geometry_agrees &
        immediate_return_ratio <= RETURN_RATIO ~
        "immediate_return_candidate",

      next_consecutive &
        next_robust_high &
        next_geometry_agrees ~
        "continued_high_mobility_candidate",

      next2_consecutive &
        next_robust_local &
        next2_robust_high &
        next2_geometry_agrees &
        delayed_return_ratio <= RETURN_RATIO ~
        "delayed_return_candidate",

      next_consecutive &
        next_robust_local ~
        "settled_relocation_candidate",

      !next_consecutive ~
        "terminal_high_move_unresolved",

      TRUE ~
        "high_move_followup_uncertain"
    )
  ) %>%
  ungroup()

# -----------------------------------------------------------------------------
# Individual mover concentration / recurrence
# -----------------------------------------------------------------------------
individual_audit <- traj %>%
  group_by(tattoo, individual_id, sex_class, age_entry_class) %>%
  arrange(from_year, to_year, .by_group = TRUE) %>%
  summarise(
    n_intervals = n(),
    expected_high_intervals = sum(p_high_mean),
    mean_p_high = mean(p_high_mean),
    n_robust_high = sum(robust_high),
    n_robust_local = sum(robust_local),
    n_uncertain = sum(state_audit_class == "uncertain"),
    max_consecutive_robust_high = max_true_run(robust_high),
    recurrent_robust_mover = n_robust_high >= 2L,
    n_state_discordant = sum(state_discordant),
    n_geometry_discordant =
      sum(max_endpoint_chain_separation > GEOM_SEP_M),
    n_immediate_return =
      sum(movement_sequence_class == "immediate_return_candidate", na.rm = TRUE),
    n_delayed_return =
      sum(movement_sequence_class == "delayed_return_candidate", na.rm = TRUE),
    n_settled_relocation =
      sum(movement_sequence_class == "settled_relocation_candidate", na.rm = TRUE),
    n_continued_high =
      sum(
        movement_sequence_class == "continued_high_mobility_candidate",
        na.rm = TRUE
      ),
    n_sg_comparable = sum(sg_comparable),
    n_sg_changes = sum(sg_changed, na.rm = TRUE),
    first_year = min(from_year),
    last_year = max(to_year),
    .groups = "drop"
  ) %>%
  mutate(
    robust_mover_audit_class = case_when(
      n_robust_high == 0L ~ "none",
      n_robust_high == 1L ~ "one",
      n_robust_high %in% 2:3 ~ "recurrent_2_3",
      n_robust_high >= 4L ~ "frequent_4plus"
    )
  ) %>%
  arrange(desc(expected_high_intervals))

n_top10 <- max(1L, ceiling(0.10 * nrow(individual_audit)))
top10_expected_share <-
  sum(head(individual_audit$expected_high_intervals, n_top10)) /
  sum(individual_audit$expected_high_intervals)

individual_concentration <- tibble(
  n_animals = nrow(individual_audit),
  n_recurrent_robust_movers =
    sum(individual_audit$recurrent_robust_mover),
  prop_recurrent_robust_movers =
    mean(individual_audit$recurrent_robust_mover),
  n_frequent_4plus =
    sum(individual_audit$robust_mover_audit_class == "frequent_4plus"),
  top10pct_share_expected_high = top10_expected_share,
  gini_expected_high = gini_nonnegative(
    individual_audit$expected_high_intervals
  )
)

# -----------------------------------------------------------------------------
# Sex, age, first-interval summaries
# -----------------------------------------------------------------------------
sex_summary <- traj %>%
  group_by(sex_class) %>%
  summarise(
    n_animals = n_distinct(tattoo),
    n_intervals = n(),
    mean_p_high = mean(p_high_mean),
    robust_high_prop = mean(robust_high),
    robust_local_prop = mean(robust_local),
    median_disp_m = median(disp_median_consensus),
    state_discordant_prop = mean(state_discordant),
    .groups = "drop"
  ) %>%
  left_join(
    individual_audit %>%
      group_by(sex_class) %>%
      summarise(
        recurrent_mover_prop = mean(recurrent_robust_mover),
        mean_expected_high_per_animal = mean(expected_high_intervals),
        .groups = "drop"
      ),
    by = "sex_class"
  )

age_summary <- traj %>%
  mutate(
    age_from_class = replace_na(
      age_from_class,
      "Age_unknown"
    )
  ) %>%
  group_by(age_from_class) %>%
  summarise(
    n_animals = n_distinct(tattoo),
    n_intervals = n(),
    mean_p_high = mean(p_high_mean),
    robust_high_prop = mean(robust_high),
    median_disp_m = median(disp_median_consensus),
    state_discordant_prop = mean(state_discordant),
    .groups = "drop"
  ) %>%
  arrange(desc(n_intervals))

first_interval_summary <- traj %>%
  group_by(is_first_interval, age_entry_class, sex_class) %>%
  summarise(
    n_intervals = n(),
    mean_p_high = mean(p_high_mean),
    robust_high_prop = mean(robust_high),
    median_disp_m = median(disp_median_consensus),
    .groups = "drop"
  )

# -----------------------------------------------------------------------------
# Social-group relation to inferred movement
# -----------------------------------------------------------------------------
sg_summary <- traj %>%
  group_by(sg_change_class) %>%
  summarise(
    n_intervals = n(),
    n_animals = n_distinct(tattoo),
    mean_p_high = mean(p_high_mean),
    robust_high_prop = mean(robust_high),
    robust_local_prop = mean(robust_local),
    median_disp_m = median(disp_median_consensus),
    .groups = "drop"
  )

sg_mismatch_summary <- traj %>%
  filter(sg_comparable) %>%
  summarise(
    n_comparable = n(),
    n_high_same_sg = sum(robust_high & !sg_changed),
    n_high_changed_sg = sum(robust_high & sg_changed),
    n_local_changed_sg = sum(robust_local & sg_changed),
    p_sg_change_given_robust_high =
      if_else(
        sum(robust_high) > 0,
        sum(robust_high & sg_changed) / sum(robust_high),
        NA_real_
      ),
    p_sg_change_given_robust_local =
      if_else(
        sum(robust_local) > 0,
        sum(robust_local & sg_changed) / sum(robust_local),
        NA_real_
      )
  )

# -----------------------------------------------------------------------------
# Temporal / 2018 cull audit of annual movement
# -----------------------------------------------------------------------------
year_summary <- traj %>%
  group_by(to_year) %>%
  summarise(
    n_intervals = n(),
    n_animals = n_distinct(tattoo),
    mean_p_high = mean(p_high_mean),
    robust_high_prop = mean(robust_high),
    robust_local_prop = mean(robust_local),
    last_interval_prop = mean(is_last_interval),
    n_nonterminal_intervals = sum(!is_last_interval),
    mean_p_high_nonterminal =
      if_else(
        sum(!is_last_interval) > 0,
        mean(p_high_mean[!is_last_interval]),
        NA_real_
      ),
    robust_high_prop_nonterminal =
      if_else(
        sum(!is_last_interval) > 0,
        mean(robust_high[!is_last_interval]),
        NA_real_
      ),
    median_disp_m = median(disp_median_consensus),
    p90_disp_m = safe_q(disp_median_consensus, 0.90),
    sg_comparable_prop = mean(sg_comparable),
    sg_change_prop =
      if_else(sum(sg_comparable) > 0, mean(sg_changed, na.rm = TRUE), NA_real_),
    state_discordant_prop = mean(state_discordant),
    .groups = "drop"
  ) %>%
  mutate(
    cull_event_time = to_year - CULL_YEAR,
    cull_phase = case_when(
      to_year < CULL_YEAR ~ "pre",
      to_year == CULL_YEAR ~ "onset_interval",
      TRUE ~ "post"
    )
  )

cull_movement_summary <- traj %>%
  filter(abs(cull_event_time) <= CULL_WINDOW) %>%
  group_by(cull_phase) %>%
  summarise(
    n_intervals = n(),
    n_animals = n_distinct(tattoo),
    mean_p_high = mean(p_high_mean),
    robust_high_prop = mean(robust_high),
    last_interval_prop = mean(is_last_interval),
    n_nonterminal_intervals = sum(!is_last_interval),
    mean_p_high_nonterminal =
      if_else(
        sum(!is_last_interval) > 0,
        mean(p_high_mean[!is_last_interval]),
        NA_real_
      ),
    robust_high_prop_nonterminal =
      if_else(
        sum(!is_last_interval) > 0,
        mean(robust_high[!is_last_interval]),
        NA_real_
      ),
    median_disp_m = median(disp_median_consensus),
    sg_change_prop =
      if_else(sum(sg_comparable) > 0, mean(sg_changed, na.rm = TRUE), NA_real_),
    .groups = "drop"
  )

# -----------------------------------------------------------------------------
# Temporal composition checks: distinguish calendar-time signal from changing
# sex/age composition of the animals contributing movement intervals.
# -----------------------------------------------------------------------------
movement_by_year_sex <- traj %>%
  group_by(to_year, sex_class) %>%
  summarise(
    n_intervals = n(),
    n_animals = n_distinct(tattoo),
    mean_p_high = mean(p_high_mean),
    robust_high_prop = mean(robust_high),
    last_interval_prop = mean(is_last_interval),
    n_nonterminal = sum(!is_last_interval),
    mean_p_high_nonterminal =
      if_else(
        sum(!is_last_interval) > 0,
        mean(p_high_mean[!is_last_interval]),
        NA_real_
      ),
    robust_high_prop_nonterminal =
      if_else(
        sum(!is_last_interval) > 0,
        mean(robust_high[!is_last_interval]),
        NA_real_
      ),
    .groups = "drop"
  ) %>%
  mutate(cull_event_time = to_year - CULL_YEAR)

movement_by_year_age <- traj %>%
  mutate(
    age_from_class = replace_na(age_from_class, "Age_unknown")
  ) %>%
  group_by(to_year, age_from_class) %>%
  summarise(
    n_intervals = n(),
    n_animals = n_distinct(tattoo),
    mean_p_high = mean(p_high_mean),
    robust_high_prop = mean(robust_high),
    last_interval_prop = mean(is_last_interval),
    .groups = "drop"
  ) %>%
  mutate(cull_event_time = to_year - CULL_YEAR)

movement_year_composition <- traj %>%
  group_by(to_year) %>%
  summarise(
    n_intervals = n(),
    male_prop = mean(sex_class == "Male"),
    exact_age_supported_prop = mean(exact_age_supported),
    age_0_1_prop = mean(age_from_class == "0-1", na.rm = TRUE),
    age_2_prop = mean(age_from_class == "2", na.rm = TRUE),
    age_3_5_prop = mean(age_from_class == "3-5", na.rm = TRUE),
    age_6plus_prop = mean(age_from_class == "6+", na.rm = TRUE),
    adult_unknown_age_prop =
      mean(age_entry_class == "Adult_exact_age_unknown"),
    last_interval_prop = mean(is_last_interval),
    sg_comparable_prop = mean(sg_comparable),
    .groups = "drop"
  ) %>%
  mutate(cull_event_time = to_year - CULL_YEAR)

# -----------------------------------------------------------------------------
# Observed annual capture spread: descriptive ranging-breadth audit
# -----------------------------------------------------------------------------
sett_raw <- read_csv(sett_file, show_col_types = FALSE)

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
  stop("Could not identify sett name/X/Y columns for observed-spread audit.")
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
    is.finite(x),
    is.finite(y)
  ) %>%
  distinct(Sett_Clean, x, y)

sett_conflict <- sett_xy %>%
  count(Sett_Clean, name = "n_xy") %>%
  filter(n_xy > 1L)

if (nrow(sett_conflict)) {
  stop("Cleaned sett names map to multiple coordinate pairs.")
}

sett_xy <- sett_xy %>%
  distinct(Sett_Clean, .keep_all = TRUE)

fit_ids <- unique(traj$tattoo)

spatial_capture_rows <- enc %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    has_live_capture = as.logical(has_live_capture),
    Sett_Clean = clean_sett2(sett)
  ) %>%
  filter(
    tattoo %in% fit_ids,
    has_live_capture,
    !is.na(primary_year)
  ) %>%
  left_join(sett_xy, by = "Sett_Clean") %>%
  filter(is.finite(x), is.finite(y))

sampling_footprint_year <- spatial_capture_rows %>%
  group_by(primary_year) %>%
  summarise(
    n_spatial_capture_records = n(),
    n_animals = n_distinct(tattoo),
    n_unique_setts = n_distinct(Sett_Clean),
    n_quarters_with_any_capture = n_distinct(trap_season),
    mean_spatial_captures_per_animal =
      n_spatial_capture_records / n_animals,
    .groups = "drop"
  )

capture_spread <- spatial_capture_rows %>%
  group_by(tattoo, primary_year) %>%
  summarise(
    n_spatial_captures = n(),
    n_unique_setts = n_distinct(Sett_Clean),
    n_quarters = n_distinct(trap_season),
    max_capture_span_m = max_pair_distance(x, y),
    rms_capture_radius_m = rms_radius(x, y),
    .groups = "drop"
  ) %>%
  mutate(
    cull_event_time = primary_year - CULL_YEAR,
    cull_phase = case_when(
      primary_year < CULL_YEAR ~ "pre",
      primary_year == CULL_YEAR ~ "onset_year",
      TRUE ~ "post"
    )
  )

# Internal algebra check: for an animal-year with >=2 spatial captures,
# max pairwise span is zero iff RMS radius is zero. This guards against
# accidentally conditioning one metric on animals that changed sett.
spread_check <- capture_spread %>%
  filter(n_spatial_captures >= 2L) %>%
  summarise(
    n = n(),
    n_bad_zero_status = sum(
      (max_capture_span_m == 0) != (rms_capture_radius_m == 0),
      na.rm = TRUE
    ),
    n_nonfinite_span = sum(!is.finite(max_capture_span_m)),
    n_nonfinite_rms = sum(!is.finite(rms_capture_radius_m))
  )

if (
  spread_check$n_bad_zero_status > 0L ||
  spread_check$n_nonfinite_span > 0L ||
  spread_check$n_nonfinite_rms > 0L
) {
  stop(
    "Observed-spread algebra check failed: ",
    paste(names(spread_check), spread_check[1, ], collapse = "; ")
  )
}

cat("\nObserved-spread algebra check: PASS\n")

capture_spread_year <- capture_spread %>%
  group_by(primary_year) %>%
  summarise(
    n_animal_years = n(),
    n_2plus_spatial_captures = sum(n_spatial_captures >= 2L),
    n_2plus_quarters = sum(n_quarters >= 2L),
    median_max_span_2plus = safe_median(
      max_capture_span_m[n_spatial_captures >= 2L]
    ),
    p90_max_span_2plus = safe_q(
      max_capture_span_m[n_spatial_captures >= 2L],
      0.90
    ),
    median_rms_radius_2plus = safe_median(
      rms_capture_radius_m[n_spatial_captures >= 2L]
    ),
    median_max_span_2plus_quarters = safe_median(
      max_capture_span_m[n_quarters >= 2L]
    ),
    median_rms_radius_2plus_quarters = safe_median(
      rms_capture_radius_m[n_quarters >= 2L]
    ),
    prop_any_span_2plus_quarters =
      if_else(
        sum(n_quarters >= 2L) > 0,
        mean(max_capture_span_m[n_quarters >= 2L] > 0),
        NA_real_
      ),
    prop_span_gt250_2plus_quarters =
      if_else(
        sum(n_quarters >= 2L) > 0,
        mean(max_capture_span_m[n_quarters >= 2L] > 250),
        NA_real_
      ),
    prop_span_gt500_2plus_quarters =
      if_else(
        sum(n_quarters >= 2L) > 0,
        mean(max_capture_span_m[n_quarters >= 2L] > 500),
        NA_real_
      ),
    prop_span_gt1000_2plus_quarters =
      if_else(
        sum(n_quarters >= 2L) > 0,
        mean(max_capture_span_m[n_quarters >= 2L] > 1000),
        NA_real_
      ),
    median_positive_span_2plus_quarters = safe_median(
      max_capture_span_m[
        n_quarters >= 2L &
        max_capture_span_m > 0
      ]
    ),
    .groups = "drop"
  ) %>%
  mutate(
    cull_event_time = primary_year - CULL_YEAR,
    cull_phase = case_when(
      primary_year < CULL_YEAR ~ "pre",
      primary_year == CULL_YEAR ~ "onset_year",
      TRUE ~ "post"
    )
  )

cull_capture_spread <- capture_spread %>%
  filter(
    abs(cull_event_time) <= CULL_WINDOW,
    n_quarters >= 2L
  ) %>%
  group_by(cull_phase) %>%
  summarise(
    n_animal_years = n(),
    median_max_capture_span_m = safe_median(max_capture_span_m),
    p90_max_capture_span_m = safe_q(max_capture_span_m, 0.90),
    median_rms_capture_radius_m = safe_median(rms_capture_radius_m),
    prop_any_span = mean(max_capture_span_m > 0),
    prop_span_gt250 = mean(max_capture_span_m > 250),
    prop_span_gt500 = mean(max_capture_span_m > 500),
    prop_span_gt1000 = mean(max_capture_span_m > 1000),
    median_positive_span_m = safe_median(
      max_capture_span_m[max_capture_span_m > 0]
    ),
    .groups = "drop"
  )

# -----------------------------------------------------------------------------
# Link within-year observed spread to the annual movement state entering that
# year. This tests whether range-breadth and annual relocation are the same
# phenomenon or partly independent.
# -----------------------------------------------------------------------------
spread_movement_link <- capture_spread %>%
  left_join(
    traj %>%
      select(
        tattoo,
        to_year,
        state_audit_class,
        p_high_mean,
        robust_high,
        robust_local,
        is_last_interval
      ),
    by = c("tattoo", "primary_year" = "to_year")
  ) %>%
  left_join(
    individual_audit %>%
      select(
        tattoo,
        recurrent_robust_mover,
        robust_mover_audit_class
      ),
    by = "tattoo"
  )

spread_by_entering_state <- spread_movement_link %>%
  filter(n_quarters >= 2L, !is.na(state_audit_class)) %>%
  group_by(state_audit_class) %>%
  summarise(
    n_animal_years = n(),
    prop_any_span = mean(max_capture_span_m > 0),
    prop_span_gt250 = mean(max_capture_span_m > 250),
    prop_span_gt500 = mean(max_capture_span_m > 500),
    prop_span_gt1000 = mean(max_capture_span_m > 1000),
    median_span_m = safe_median(max_capture_span_m),
    p90_span_m = safe_q(max_capture_span_m, 0.90),
    .groups = "drop"
  )

spread_by_mover_history <- spread_movement_link %>%
  filter(n_quarters >= 2L, !is.na(recurrent_robust_mover)) %>%
  group_by(recurrent_robust_mover) %>%
  summarise(
    n_animal_years = n(),
    prop_any_span = mean(max_capture_span_m > 0),
    prop_span_gt500 = mean(max_capture_span_m > 500),
    median_span_m = safe_median(max_capture_span_m),
    p90_span_m = safe_q(max_capture_span_m, 0.90),
    .groups = "drop"
  )

# Complete the observed sampling-footprint table with animal-year repeatability.
sampling_footprint_year <- sampling_footprint_year %>%
  left_join(
    capture_spread %>%
      group_by(primary_year) %>%
      summarise(
        n_animal_years = n(),
        prop_animal_years_2plus_captures =
          mean(n_spatial_captures >= 2L),
        prop_animal_years_2plus_quarters =
          mean(n_quarters >= 2L),
        .groups = "drop"
      ),
    by = "primary_year"
  ) %>%
  mutate(cull_event_time = primary_year - CULL_YEAR)

# -----------------------------------------------------------------------------
# Movement sequence summary
# -----------------------------------------------------------------------------
sequence_summary <- traj %>%
  filter(robust_high) %>%
  count(movement_sequence_class, sort = TRUE, name = "n_intervals") %>%
  mutate(
    prop_of_robust_high = n_intervals / sum(n_intervals)
  )

# -----------------------------------------------------------------------------
# Remaining difficult trajectories: biological annotation
# -----------------------------------------------------------------------------
difficult <- traj %>%
  filter(state_discordant | trajectory_mode_signal) %>%
  select(
    active_index,
    tattoo,
    individual_id,
    sex_class,
    age_entry_class,
    age_from_years,
    age_from_class,
    from_year,
    to_year,
    cull_event_time,
    cull_phase,
    from_sg,
    to_sg,
    sg_change_class,
    p_high_chain1,
    p_high_chain2,
    p_high_chain3,
    p_high_mean,
    state_audit_class,
    disp_median_chain1,
    disp_median_chain2,
    disp_median_chain3,
    disp_median_consensus,
    max_p_high_difference,
    max_endpoint_chain_separation,
    state_discordant,
    trajectory_mode_signal,
    movement_sequence_class
  ) %>%
  left_join(
    individual_audit %>%
      select(
        tattoo,
        expected_high_intervals,
        n_robust_high,
        recurrent_robust_mover,
        robust_mover_audit_class
      ),
    by = "tattoo"
  ) %>%
  arrange(
    desc(state_discordant),
    desc(max_p_high_difference),
    desc(max_endpoint_chain_separation)
  )

difficult_summary <- difficult %>%
  summarise(
    n_difficult_intervals = n(),
    n_difficult_animals = n_distinct(tattoo),
    prop_from_recurrent_movers =
      mean(recurrent_robust_mover, na.rm = TRUE),
    prop_post_cull = mean(cull_phase == "post"),
    prop_adult_entry =
      mean(age_entry_class == "Adult_exact_age_unknown", na.rm = TRUE)
  )

# -----------------------------------------------------------------------------
# Optional global-ridge/rho/omega context
# -----------------------------------------------------------------------------
ridge_segments <- NULL
ridge_convergence <- NULL
rho_omega_summary <- tibble()

if (file.exists(ridge_segments_file)) {
  ridge_segments <- read_csv(ridge_segments_file, show_col_types = FALSE)

  if (all(c("chain", "n", "rho", "omega") %in% names(ridge_segments))) {
    rho_omega_summary <- ridge_segments %>%
      group_by(chain) %>%
      summarise(
        rho_segment_weighted_mean = weighted.mean(rho, n),
        rho_segment_min = min(rho),
        rho_segment_max = max(rho),
        omega_segment_weighted_mean = weighted.mean(omega, n),
        omega_segment_min = min(omega),
        omega_segment_max = max(omega),
        .groups = "drop"
      )
  }
}

if (file.exists(ridge_conv_file)) {
  ridge_convergence <- read_csv(ridge_conv_file, show_col_types = FALSE)
}

# -----------------------------------------------------------------------------
# Decision inputs: evidence, not automatic model selection
# -----------------------------------------------------------------------------
n_robust_high_total <- sum(traj$robust_high)
n_return_candidates <- sum(
  traj$movement_sequence_class %in%
    c("immediate_return_candidate", "delayed_return_candidate"),
  na.rm = TRUE
)
n_settled_candidates <- sum(
  traj$movement_sequence_class == "settled_relocation_candidate",
  na.rm = TRUE
)
n_continued_candidates <- sum(
  traj$movement_sequence_class == "continued_high_mobility_candidate",
  na.rm = TRUE
)

sex_range <- if (nrow(sex_summary) > 1L) {
  max(sex_summary$mean_p_high) - min(sex_summary$mean_p_high)
} else {
  NA_real_
}

age_known <- age_summary %>%
  filter(age_from_class %in% c("0-1", "2", "3-5", "6+"))

age_range <- if (nrow(age_known) > 1L) {
  max(age_known$mean_p_high) - min(age_known$mean_p_high)
} else {
  NA_real_
}

sg_high_change <- if (nrow(sg_mismatch_summary)) {
  sg_mismatch_summary$p_sg_change_given_robust_high[1]
} else {
  NA_real_
}
sg_local_change <- if (nrow(sg_mismatch_summary)) {
  sg_mismatch_summary$p_sg_change_given_robust_local[1]
} else {
  NA_real_
}

rho_mean_over_chains <- if (nrow(rho_omega_summary)) {
  mean(rho_omega_summary$rho_segment_weighted_mean)
} else {
  NA_real_
}

decision_inputs <- tibble(
  candidate = c(
    "retain_two_state_baseline",
    "iid_quarter_rho_zero_sensitivity",
    "signed_rho_sensitivity",
    "age_effect_on_high_state_entry",
    "individual_mover_propensity_random_effect",
    "temporary_excursion_vs_relocation_extension",
    "recorded_social_group_overlay_then_dynamic_territory_model",
    "2018_cull_effect_on_annual_relocation",
    "2018_cull_effect_on_within_year_ranging_breadth"
  ),
  audit_metric = c(
    "late/current cross-chain state discordance",
    "mean rho from ridge-segment summaries",
    "current rho restricted to (0,1)",
    "range in mean p(high) among exact-age classes",
    "top 10% share / Gini of expected high intervals",
    "return candidates among robust-high intervals",
    "P(SG change | robust high) vs P(SG change | robust local)",
    "annual p(high)/displacement event-time table around 2018",
    "observed annual capture-spread event-time table around 2018"
  ),
  value = c(
    as.character(traj_summary$prop_state_discordant[1]),
    as.character(rho_mean_over_chains),
    "structural assumption: positive only",
    as.character(age_range),
    paste0(
      "top10share=", round(top10_expected_share, 4),
      "; gini=", round(individual_concentration$gini_expected_high, 4)
    ),
    paste0(
      n_return_candidates, "/", n_robust_high_total,
      " robust-high intervals"
    ),
    paste0(
      "high=", round(sg_high_change, 4),
      "; local=", round(sg_local_change, 4)
    ),
    paste0(
      "see movement_by_year and cull_movement_summary; cull year=", CULL_YEAR
    ),
    paste0(
      "see observed_capture_spread_by_year and cull_capture_spread; cull year=",
      CULL_YEAR
    )
  ),
  interpretation = c(
    "Baseline remains the reference model; do not replace it unless biology audit supports an extension.",
    "If rho remains near zero after continuation, compare against rho=0 model.",
    "Required prior/structural sensitivity before final production conclusions.",
    "Use descriptive age pattern to decide whether cub/yearling/adult transition effects deserve a model.",
    "Strong concentration/recurrent movers would motivate persistent individual heterogeneity.",
    "A substantial return fraction would motivate separating excursion from permanent relocation.",
    "Recorded SG is an overlay/check only now; dynamic bait-marking territories are the later mechanistic layer.",
    "Scientific target; current table is descriptive and not causal.",
    "Scientific target; current spread metric is descriptive and not a home-range estimate."
  )
)

# -----------------------------------------------------------------------------
# Save tables
# -----------------------------------------------------------------------------
write_csv(traj, paste0(out_prefix, "_intervals.csv"))
write_csv(individual_audit, paste0(out_prefix, "_individuals.csv"))
write_csv(individual_concentration, paste0(out_prefix, "_individual_concentration.csv"))
write_csv(sex_summary, paste0(out_prefix, "_sex.csv"))
write_csv(age_summary, paste0(out_prefix, "_age.csv"))
write_csv(first_interval_summary, paste0(out_prefix, "_first_interval.csv"))
write_csv(sg_year, paste0(out_prefix, "_recorded_SG_by_year.csv"))
write_csv(sg_summary, paste0(out_prefix, "_recorded_SG_movement.csv"))
write_csv(sg_mismatch_summary, paste0(out_prefix, "_recorded_SG_mismatch.csv"))
write_csv(sequence_summary, paste0(out_prefix, "_movement_sequences.csv"))
write_csv(year_summary, paste0(out_prefix, "_movement_by_year.csv"))
write_csv(cull_movement_summary, paste0(out_prefix, "_cull_movement_summary.csv"))
write_csv(capture_spread, paste0(out_prefix, "_observed_capture_spread_animal_year.csv"))
write_csv(capture_spread_year, paste0(out_prefix, "_observed_capture_spread_by_year.csv"))
write_csv(cull_capture_spread, paste0(out_prefix, "_cull_capture_spread_summary.csv"))
write_csv(movement_by_year_sex, paste0(out_prefix, "_movement_by_year_sex.csv"))
write_csv(movement_by_year_age, paste0(out_prefix, "_movement_by_year_age.csv"))
write_csv(movement_year_composition, paste0(out_prefix, "_movement_year_composition.csv"))
write_csv(sampling_footprint_year, paste0(out_prefix, "_sampling_footprint_by_year.csv"))
write_csv(spread_movement_link, paste0(out_prefix, "_spread_movement_link.csv"))
write_csv(spread_by_entering_state, paste0(out_prefix, "_spread_by_entering_state.csv"))
write_csv(spread_by_mover_history, paste0(out_prefix, "_spread_by_mover_history.csv"))
write_csv(difficult, paste0(out_prefix, "_difficult_intervals_annotated.csv"))
write_csv(difficult_summary, paste0(out_prefix, "_difficult_summary.csv"))
write_csv(rho_omega_summary, paste0(out_prefix, "_rho_omega_chain_summary.csv"))
write_csv(decision_inputs, paste0(out_prefix, "_decision_inputs.csv"))

# -----------------------------------------------------------------------------
# Plots
# -----------------------------------------------------------------------------
p1 <- ggplot(year_summary, aes(x = to_year, y = mean_p_high)) +
  geom_line() +
  geom_point() +
  geom_vline(xintercept = CULL_YEAR, linetype = 2) +
  labs(
    x = "Movement interval ending year",
    y = "Mean posterior P(high mobility)",
    title = "Annual high-mobility signal through time",
    subtitle = paste("Vertical line =", CULL_YEAR, "cull onset")
  ) +
  theme_minimal()

ggsave(
  paste0(out_prefix, "_movement_by_year.png"),
  p1,
  width = 9,
  height = 5,
  dpi = 160
)

p2 <- capture_spread_year %>%
  ggplot(
    aes(
      x = primary_year,
      y = median_max_span_2plus_quarters
    )
  ) +
  geom_line() +
  geom_point() +
  geom_vline(xintercept = CULL_YEAR, linetype = 2) +
  labs(
    x = "Year",
    y = "Median max observed capture span (m)",
    title = "Observed within-year spatial breadth",
    subtitle = "Animal-years represented in at least two trapping quarters; descriptive only"
  ) +
  theme_minimal()

ggsave(
  paste0(out_prefix, "_observed_capture_spread_by_year.png"),
  p2,
  width = 9,
  height = 5,
  dpi = 160
)

p3 <- sex_summary %>%
  ggplot(aes(x = sex_class, y = mean_p_high)) +
  geom_col() +
  labs(
    x = "Sex",
    y = "Mean posterior P(high mobility)",
    title = "Movement-state signal by sex"
  ) +
  theme_minimal()

ggsave(
  paste0(out_prefix, "_movement_by_sex.png"),
  p3,
  width = 6,
  height = 5,
  dpi = 160
)

p4 <- age_summary %>%
  ggplot(aes(x = reorder(age_from_class, mean_p_high), y = mean_p_high)) +
  geom_col() +
  coord_flip() +
  labs(
    x = "Age class at start of movement interval",
    y = "Mean posterior P(high mobility)",
    title = "Movement-state signal by age support"
  ) +
  theme_minimal()

ggsave(
  paste0(out_prefix, "_movement_by_age.png"),
  p4,
  width = 7,
  height = 5,
  dpi = 160
)

p5 <- sg_summary %>%
  ggplot(aes(x = sg_change_class, y = mean_p_high)) +
  geom_col() +
  coord_flip() +
  labs(
    x = "Recorded social-group comparison",
    y = "Mean posterior P(high mobility)",
    title = "High-mobility signal versus recorded social-group change"
  ) +
  theme_minimal()

ggsave(
  paste0(out_prefix, "_movement_by_recorded_SG_change.png"),
  p5,
  width = 8,
  height = 5,
  dpi = 160
)

# -----------------------------------------------------------------------------
# Concise console decision report
# -----------------------------------------------------------------------------
cat("\n============================================================\n")
cat("1. BASELINE STATE / TRAJECTORY ROBUSTNESS\n")
cat("============================================================\n")
print(traj_summary, n = Inf, width = Inf)

cat("\nRobust state calls across all three chains:\n")
print(
  traj %>%
    count(state_audit_class, sort = TRUE) %>%
    mutate(prop = n / sum(n)),
  n = Inf
)

cat("\n============================================================\n")
cat("2. WHAT DO ROBUST HIGH-MOBILITY INTERVALS LOOK LIKE?\n")
cat("============================================================\n")
print(sequence_summary, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("3. REPEATED / INDIVIDUAL MOVER SIGNAL\n")
cat("============================================================\n")
print(individual_concentration, n = Inf, width = Inf)
cat("\nMover audit classes:\n")
print(
  individual_audit %>%
    count(robust_mover_audit_class, sort = TRUE),
  n = Inf
)

cat("\nTop 20 animals by expected number of high-mobility intervals:\n")
print(
  individual_audit %>%
    select(
      tattoo, sex_class, age_entry_class, n_intervals,
      expected_high_intervals, n_robust_high,
      max_consecutive_robust_high, robust_mover_audit_class
    ) %>%
    slice_head(n = 20L),
  n = Inf,
  width = Inf
)

cat("\n============================================================\n")
cat("4. SEX / AGE / ENTRY BIOLOGY\n")
cat("============================================================\n")
cat("\nSex:\n")
print(sex_summary, n = Inf, width = Inf)
cat("\nAge at start of interval:\n")
print(age_summary, n = Inf, width = Inf)
cat("\nFirst interval / entry class:\n")
print(first_interval_summary, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("5. RECORDED SOCIAL GROUP\n")
cat("============================================================\n")
print(sg_summary, n = Inf, width = Inf)
cat("\nHigh/local versus SG-change mismatches:\n")
print(sg_mismatch_summary, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("6. 2018 CULL: DESCRIPTIVE MOVEMENT WINDOW\n")
cat("============================================================\n")
print(
  year_summary %>%
    filter(abs(cull_event_time) <= CULL_WINDOW),
  n = Inf,
  width = Inf
)
cat("\nPre/onset/post summary within event window:\n")
print(cull_movement_summary, n = Inf, width = Inf)

cat("\nCalendar-time composition around the cull (movement intervals):\n")
print(
  movement_year_composition %>%
    filter(abs(cull_event_time) <= CULL_WINDOW),
  n = Inf,
  width = Inf
)

cat("\nSex-stratified movement signal around the cull:\n")
print(
  movement_by_year_sex %>%
    filter(abs(cull_event_time) <= CULL_WINDOW),
  n = Inf,
  width = Inf
)

cat("\n============================================================\n")
cat("7. 2018 CULL: OBSERVED WITHIN-YEAR CAPTURE SPREAD\n")
cat("============================================================\n")
print(
  capture_spread_year %>%
    filter(abs(cull_event_time) <= CULL_WINDOW),
  n = Inf,
  width = Inf
)
cat("\nPre/onset/post observed-spread summary (>=2 quarters):\n")
print(cull_capture_spread, n = Inf, width = Inf)

cat("\nObserved sampling footprint around the cull:\n")
print(
  sampling_footprint_year %>%
    filter(abs(cull_event_time) <= CULL_WINDOW),
  n = Inf,
  width = Inf
)

cat("\nObserved spread by annual movement state entering the year:\n")
print(spread_by_entering_state, n = Inf, width = Inf)

cat("\nObserved spread by recurrent-mover history:\n")
print(spread_by_mover_history, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("8. RHO / OMEGA CONTEXT\n")
cat("============================================================\n")
if (nrow(rho_omega_summary)) {
  print(rho_omega_summary, n = Inf, width = Inf)
} else {
  cat("Global ridge segment file not available; skipped.\n")
}
if (!is.null(ridge_convergence)) {
  cat("\nGlobal convergence table:\n")
  print(ridge_convergence, n = Inf, width = Inf)
}

cat("\n============================================================\n")
cat("9. REMAINING DIFFICULT INTERVALS\n")
cat("============================================================\n")
print(difficult_summary, n = Inf, width = Inf)
cat("\nTop 30 annotated difficult intervals:\n")
print(difficult %>% slice_head(n = 30L), n = 30L, width = Inf)

cat("\n============================================================\n")
cat("10. DECISION INPUTS FOR NEXT BIOLOGICAL MODEL\n")
cat("============================================================\n")
print(decision_inputs, n = Inf, width = Inf)

cat(
  "\nAUDIT COMPLETE.\n",
  "This audit does NOT select a new model automatically. ",
  "Use these outputs to decide which biological extensions are supported ",
  "before changing the frozen V10B baseline.\n",
  sep = ""
)
