# =============================================================================
# WOODCHESTER V9 FINAL — MOVEMENT -> SURVIVAL / DISAPPEARANCE SUPPORT AUDIT
#
# Purpose
#   Before fitting a survival model, determine whether high-mobility intervals
#   are followed disproportionately by:
#     1. supported continued survival in the study,
#     2. a known PM/death record, or
#     3. unresolved disappearance.
#
# IMPORTANT INTERPRETATION
#   This is NOT yet a mortality model.
#
#   "Unresolved disappearance" may represent:
#     - permanent emigration,
#     - missed detection,
#     - unrecovered death.
#
#   Because the exposure of interest is movement, apparent survival and true
#   survival must not be conflated. This audit decides whether a formal
#   capture-recapture / survival analysis is justified.
#
# Exposure
#   V9 annual movement state for an interval ending in year t.
#
# Outcomes
#   At +1 and +2 years after t:
#     SUPPORTED_ALIVE          a live observation exists at/after target year
#     KNOWN_PM_DEATH           a PM/death record occurs by target year
#     UNRESOLVED_DISAPPEARANCE neither of the above
#
# Intervals with a PM record in or before exposure year t are excluded because
# temporal ordering relative to the annual movement interval is not defensible.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

MOVE_FILE <- "data/badger_movement_posterior_draws_1932_V9.rds"
ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
OUT_DIR <- "results/model_checks"
MAX_YEAR <- 2025L

for(f in c(MOVE_FILE, ENCOUNTER_FILE)) {
  if(!file.exists(f)) stop("Missing required file: ", f)
}
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("\n============================================================\n")
cat("V9 MOVEMENT -> SURVIVAL / DISAPPEARANCE SUPPORT AUDIT\n")
cat("============================================================\n")

mov <- readRDS(MOVE_FILE)
enc <- as_tibble(readRDS(ENCOUNTER_FILE))

need_enc <- c("tattoo", "capture_date", "has_live_capture", "has_pm_record")
miss <- setdiff(need_enc, names(enc))
if(length(miss)) stop("Encounter file lacks: ", paste(miss, collapse = ", "))

# =============================================================================
# 1. LIVE AND PM HISTORIES
# =============================================================================

hist <- enc %>%
  transmute(
    tattoo = str_to_upper(str_squish(as.character(tattoo))),
    capture_date = as.Date(capture_date),
    year = year(capture_date),
    has_live_capture = as.logical(has_live_capture),
    has_pm_record = as.logical(has_pm_record)
  ) %>%
  filter(!is.na(tattoo), tattoo != "", !is.na(capture_date))

live_bounds <- hist %>%
  filter(has_live_capture %in% TRUE) %>%
  group_by(tattoo) %>%
  summarise(
    first_live_date = min(capture_date),
    last_live_date = max(capture_date),
    first_live_year = min(year),
    last_live_year = max(year),
    .groups = "drop"
  )

pm_first <- hist %>%
  filter(has_pm_record %in% TRUE) %>%
  group_by(tattoo) %>%
  summarise(
    first_pm_date = min(capture_date),
    first_pm_year = min(year),
    .groups = "drop"
  )

history_audit <- live_bounds %>%
  left_join(pm_first, by = "tattoo") %>%
  mutate(
    live_after_pm = !is.na(first_pm_date) & last_live_date > first_pm_date
  )

cat("Badgers with live histories:", nrow(live_bounds), "\n")
cat("Badgers with a PM/death record:", sum(!is.na(history_audit$first_pm_date)), "\n")
cat("Badgers with a live observation after first PM record:",
    sum(history_audit$live_after_pm), "\n")

# =============================================================================
# 2. ALIGN MOVEMENT INTERVALS
# =============================================================================

idx <- as_tibble(mov$disp_index) %>%
  mutate(
    interval_col = row_number(),
    tattoo = str_to_upper(str_squish(as.character(tattoo))),
    from_year = as.integer(from_year),
    to_year = as.integer(to_year)
  )

if(ncol(mov$movement_draws) != nrow(idx))
  stop("Movement draw matrix does not align with disp_index.")

if(any(!mov$movement_draws %in% c(0L, 1L)))
  stop("Movement states must be coded 0/1.")

p_high <- colMeans(mov$movement_draws)

sex_lookup <- tibble(
  model_i = seq_along(mov$ids),
  tattoo_check = str_to_upper(str_squish(as.character(mov$ids))),
  sex = as.integer(mov$sex_data)
)

intervals <- idx %>%
  left_join(
    sex_lookup %>% select(model_i, tattoo_check, sex),
    by = "model_i"
  ) %>%
  mutate(
    p_high = p_high,
    sex_label = case_when(
      sex == 0L ~ "Female",
      sex == 1L ~ "Male",
      TRUE ~ "Unknown"
    )
  ) %>%
  left_join(history_audit, by = "tattoo")

if(anyNA(intervals$last_live_year))
  warning(sum(is.na(intervals$last_live_year)),
          " movement intervals could not be linked to a live-history bound.")

tattoo_mismatch <- intervals %>%
  filter(!is.na(tattoo_check), tattoo != tattoo_check)
if(nrow(tattoo_mismatch))
  stop("Movement IDs do not agree with model_i tattoo lookup.")

# =============================================================================
# 3. FOLLOW-UP CLASSIFICATION
# =============================================================================

classify_horizon <- function(d, horizon_years) {
  target <- d$to_year + horizon_years

  eligible <- !is.na(d$last_live_year) &
    target <= MAX_YEAR &
    (is.na(d$first_pm_year) | d$first_pm_year > d$to_year)

  status <- rep(NA_character_, nrow(d))

  supported <- eligible & d$last_live_year >= target

  known_pm <- eligible &
    !supported &
    !is.na(d$first_pm_year) &
    d$first_pm_year > d$to_year &
    d$first_pm_year <= target

  unresolved <- eligible & !supported & !known_pm

  status[supported] <- "SUPPORTED_ALIVE"
  status[known_pm] <- "KNOWN_PM_DEATH"
  status[unresolved] <- "UNRESOLVED_DISAPPEARANCE"

  tibble(
    eligible = eligible,
    target_year = target,
    followup_status = factor(
      status,
      levels = c(
        "SUPPORTED_ALIVE",
        "KNOWN_PM_DEATH",
        "UNRESOLVED_DISAPPEARANCE"
      )
    )
  )
}

h1 <- classify_horizon(intervals, 1L)
h2 <- classify_horizon(intervals, 2L)

intervals <- intervals %>%
  bind_cols(
    h1 %>% rename(
      eligible_1y = eligible,
      target_year_1y = target_year,
      status_1y = followup_status
    ),
    h2 %>% rename(
      eligible_2y = eligible,
      target_year_2y = target_year,
      status_2y = followup_status
    )
  ) %>%
  mutate(
    is_terminal_live_year = !is.na(last_live_year) & to_year == last_live_year,
    state_confidence = case_when(
      p_high < 0.20 ~ "strong_local",
      p_high > 0.80 ~ "strong_high_mobility",
      TRUE ~ "uncertain"
    )
  )

# =============================================================================
# 4. DESCRIPTIVE SUPPORT
# =============================================================================

status_summary <- bind_rows(
  intervals %>%
    filter(eligible_1y) %>%
    count(horizon = "1 year", status = as.character(status_1y), name = "intervals") %>%
    mutate(proportion = intervals / sum(intervals)),
  intervals %>%
    filter(eligible_2y) %>%
    count(horizon = "2 years", status = as.character(status_2y), name = "intervals") %>%
    mutate(proportion = intervals / sum(intervals))
)

status_by_state_conf <- bind_rows(
  intervals %>%
    filter(eligible_1y) %>%
    group_by(horizon = "1 year", state_confidence, status = as.character(status_1y)) %>%
    summarise(
      intervals = n(),
      badgers = n_distinct(tattoo),
      median_p_high = median(p_high),
      .groups = "drop"
    ) %>%
    group_by(horizon, state_confidence) %>%
    mutate(proportion = intervals / sum(intervals)) %>%
    ungroup(),

  intervals %>%
    filter(eligible_2y) %>%
    group_by(horizon = "2 years", state_confidence, status = as.character(status_2y)) %>%
    summarise(
      intervals = n(),
      badgers = n_distinct(tattoo),
      median_p_high = median(p_high),
      .groups = "drop"
    ) %>%
    group_by(horizon, state_confidence) %>%
    mutate(proportion = intervals / sum(intervals)) %>%
    ungroup()
)

p_high_by_status <- bind_rows(
  intervals %>%
    filter(eligible_1y) %>%
    group_by(horizon = "1 year", status = as.character(status_1y)) %>%
    summarise(
      intervals = n(),
      badgers = n_distinct(tattoo),
      median_p_high = median(p_high),
      q25_p_high = quantile(p_high, .25),
      q75_p_high = quantile(p_high, .75),
      prop_p_high_gt_0.5 = mean(p_high >= .5),
      prop_p_high_gt_0.8 = mean(p_high >= .8),
      .groups = "drop"
    ),

  intervals %>%
    filter(eligible_2y) %>%
    group_by(horizon = "2 years", status = as.character(status_2y)) %>%
    summarise(
      intervals = n(),
      badgers = n_distinct(tattoo),
      median_p_high = median(p_high),
      q25_p_high = quantile(p_high, .25),
      q75_p_high = quantile(p_high, .75),
      prop_p_high_gt_0.5 = mean(p_high >= .5),
      prop_p_high_gt_0.8 = mean(p_high >= .8),
      .groups = "drop"
    )
)

terminal_summary <- intervals %>%
  filter(!is.na(is_terminal_live_year)) %>%
  group_by(is_terminal_live_year) %>%
  summarise(
    intervals = n(),
    badgers = n_distinct(tattoo),
    median_p_high = median(p_high),
    q25_p_high = quantile(p_high, .25),
    q75_p_high = quantile(p_high, .75),
    prop_p_high_gt_0.5 = mean(p_high >= .5),
    prop_p_high_gt_0.8 = mean(p_high >= .8),
    .groups = "drop"
  )

# =============================================================================
# 5. PROPAGATE MOVEMENT-STATE UNCERTAINTY — DESCRIPTIVE DRAW-BY-DRAW CONTRASTS
# =============================================================================

draw_contrasts_one <- function(status_var, eligible_var, label) {
  eligible <- intervals[[eligible_var]]
  status <- as.character(intervals[[status_var]])

  keep <- which(eligible & !is.na(status))
  if(!length(keep)) return(tibble())

  stmat <- mov$movement_draws[, keep, drop = FALSE]
  status <- status[keep]

  out <- vector("list", nrow(stmat))

  for(dd in seq_len(nrow(stmat))) {
    s <- as.integer(stmat[dd, ])

    summarise_state <- function(state) {
      z <- status[s == state]
      n <- length(z)
      if(!n) return(c(n = 0, supported = NA, pm = NA, unresolved = NA))
      c(
        n = n,
        supported = mean(z == "SUPPORTED_ALIVE"),
        pm = mean(z == "KNOWN_PM_DEATH"),
        unresolved = mean(z == "UNRESOLVED_DISAPPEARANCE")
      )
    }

    lo <- summarise_state(0L)
    hi <- summarise_state(1L)

    out[[dd]] <- tibble(
      movement_draw = dd,
      horizon = label,
      n_local = lo["n"],
      n_high = hi["n"],
      p_supported_local = lo["supported"],
      p_supported_high = hi["supported"],
      p_pm_local = lo["pm"],
      p_pm_high = hi["pm"],
      p_unresolved_local = lo["unresolved"],
      p_unresolved_high = hi["unresolved"],
      RD_supported_high_minus_local = hi["supported"] - lo["supported"],
      RD_pm_high_minus_local = hi["pm"] - lo["pm"],
      RD_unresolved_high_minus_local = hi["unresolved"] - lo["unresolved"]
    )
  }

  bind_rows(out)
}

draw_contrasts <- bind_rows(
  draw_contrasts_one("status_1y", "eligible_1y", "1 year"),
  draw_contrasts_one("status_2y", "eligible_2y", "2 years")
)

contrast_summary <- draw_contrasts %>%
  group_by(horizon) %>%
  summarise(
    median_n_high = median(n_high, na.rm = TRUE),

    supported_RD_median = median(RD_supported_high_minus_local, na.rm = TRUE),
    supported_RD_q025 = quantile(RD_supported_high_minus_local, .025, na.rm = TRUE),
    supported_RD_q975 = quantile(RD_supported_high_minus_local, .975, na.rm = TRUE),

    pm_RD_median = median(RD_pm_high_minus_local, na.rm = TRUE),
    pm_RD_q025 = quantile(RD_pm_high_minus_local, .025, na.rm = TRUE),
    pm_RD_q975 = quantile(RD_pm_high_minus_local, .975, na.rm = TRUE),

    unresolved_RD_median = median(RD_unresolved_high_minus_local, na.rm = TRUE),
    unresolved_RD_q025 = quantile(RD_unresolved_high_minus_local, .025, na.rm = TRUE),
    unresolved_RD_q975 = quantile(RD_unresolved_high_minus_local, .975, na.rm = TRUE),

    .groups = "drop"
  )

# =============================================================================
# 6. SEX-STRATIFIED SUPPORT
# =============================================================================

sex_summary <- bind_rows(
  intervals %>%
    filter(eligible_1y, sex_label %in% c("Female", "Male")) %>%
    group_by(horizon = "1 year", sex_label, status = as.character(status_1y)) %>%
    summarise(
      intervals = n(),
      badgers = n_distinct(tattoo),
      median_p_high = median(p_high),
      .groups = "drop"
    ),
  intervals %>%
    filter(eligible_2y, sex_label %in% c("Female", "Male")) %>%
    group_by(horizon = "2 years", sex_label, status = as.character(status_2y)) %>%
    summarise(
      intervals = n(),
      badgers = n_distinct(tattoo),
      median_p_high = median(p_high),
      .groups = "drop"
    )
)

# =============================================================================
# 7. SAVE
# =============================================================================

write_csv(
  status_summary,
  file.path(OUT_DIR, "V9_movement_survival_status_summary.csv")
)
write_csv(
  status_by_state_conf,
  file.path(OUT_DIR, "V9_movement_survival_status_by_state_confidence.csv")
)
write_csv(
  p_high_by_status,
  file.path(OUT_DIR, "V9_movement_survival_p_high_by_status.csv")
)
write_csv(
  terminal_summary,
  file.path(OUT_DIR, "V9_movement_terminal_interval_summary.csv")
)
write_csv(
  contrast_summary,
  file.path(OUT_DIR, "V9_movement_survival_drawwise_contrast_summary.csv")
)
write_csv(
  sex_summary,
  file.path(OUT_DIR, "V9_movement_survival_sex_summary.csv")
)
write_csv(
  history_audit,
  file.path(OUT_DIR, "V9_movement_survival_live_pm_history_audit.csv")
)

saveRDS(
  list(
    intervals = intervals,
    draw_contrasts = draw_contrasts,
    summaries = list(
      status = status_summary,
      by_state_confidence = status_by_state_conf,
      p_high_by_status = p_high_by_status,
      terminal = terminal_summary,
      draw_contrast = contrast_summary,
      sex = sex_summary
    ),
    definitions = list(
      exposure = "V9 movement state for annual interval ending in year t",
      supported_alive = "last observed live year reaches or exceeds target year",
      known_pm_death = "first PM/death record occurs after t and by target year, with no supported live observation reaching target",
      unresolved_disappearance = "no supported live observation reaching target and no known PM/death by target",
      warning = "unresolved disappearance is not mortality; it can include emigration, missed detection or unrecovered death"
    )
  ),
  file.path(OUT_DIR, "V9_movement_survival_disappearance_audit.rds"),
  compress = "gzip"
)

cat("\nFOLLOW-UP STATUS\n")
print(status_summary, n = Inf, width = Inf)

cat("\nPOSTERIOR HIGH-MOBILITY PROBABILITY BY FOLLOW-UP STATUS\n")
print(p_high_by_status, n = Inf, width = Inf)

cat("\nDRAW-BY-DRAW HIGH MINUS LOCAL RISK DIFFERENCES\n")
print(contrast_summary, n = Inf, width = Inf)

cat("\nTERMINAL VS NON-TERMINAL MOVEMENT INTERVALS\n")
print(terminal_summary, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("SURVIVAL / DISAPPEARANCE SUPPORT AUDIT COMPLETE\n")
cat("============================================================\n")
cat("This audit does NOT estimate true survival.\n")
cat("Use it to decide whether a formal apparent-survival / observation model is warranted.\n")
