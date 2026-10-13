# =============================================================================
# WOODCHESTER V9 FINAL — PHASE-2 TARGETED MODEL CHECKS
#
# Purpose
#   Close Phase 2 with a compact set of checks that can be done from the frozen
#   V9 outputs WITHOUT refitting the NIMBLE movement model.
#
# Checks
#   A. Observable movement/state consistency
#      - observed annual displacement
#      - observed social-group switching
#      - posterior probability of high mobility
#      - sex-stratified summaries
#
#      IMPORTANT: this is a consistency check, not an independent validation of
#      the latent state, because the movement observations helped infer that state.
#
#   B. V7a posterior-predictive checks
#      - reproduce local -> high-mobility counts overall and in the four
#        sex x infection strata.
#
#   C. V7b posterior-predictive checks
#      - reproduce infection-acquisition counts overall and by movement state,
#        sex, quarter and 5-year period.
#
# The same-group pressure calibration is kept in a separate closure script
# because it requires reconstruction of the pressure-supported quarterly rows.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

set.seed(7092201)

OUT_DIR <- "results/model_checks"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

MOVE_FILE <- "data/badger_movement_posterior_draws_1932_V9.rds"
ANNUAL_FILE <- "results/badger_annual_observed_sett_locations.csv"
V7A_FILE <- "results/V9FINAL_V7aM_infection_to_movement_FULL_1500.rds"
V7B_FILE <- "results/V9FINAL_V7bM_movement_to_infection_FULL_1500.rds"

for (f in c(MOVE_FILE, ANNUAL_FILE, V7A_FILE, V7B_FILE)) {
  if (!file.exists(f)) stop("Missing required file: ", f)
}

cat("\n============================================================\n")
cat("WOODCHESTER V9 FINAL — TARGETED PHASE-2 MODEL CHECKS\n")
cat("============================================================\n")

# =============================================================================
# A. OBSERVABLE MOVEMENT / LATENT-STATE CONSISTENCY
# =============================================================================

cat("\nA. OBSERVABLE MOVEMENT / STATE CONSISTENCY\n")
cat("-----------------------------------------\n")

mov <- readRDS(MOVE_FILE)
annual <- read_csv(ANNUAL_FILE, show_col_types = FALSE)

if (is.null(mov$disp_summary) || is.null(mov$disp_index))
  stop("Movement export lacks disp_summary or disp_index.")

disp <- as_tibble(mov$disp_summary)

if (!all(c("tattoo", "from_year", "to_year", "p_high_mobility") %in% names(disp)))
  stop("disp_summary lacks tattoo/from_year/to_year/p_high_mobility.")

# Add sex robustly from the canonical movement export.
if ("model_i" %in% names(disp)) {
  disp <- disp %>%
    mutate(
      model_i = as.integer(model_i),
      sex = as.integer(mov$sex_data[model_i])
    )
} else {
  sex_lookup <- tibble(
    tattoo = trimws(as.character(mov$ids)),
    sex = as.integer(mov$sex_data)
  )
  disp <- disp %>%
    mutate(tattoo = trimws(as.character(tattoo))) %>%
    left_join(sex_lookup, by = "tattoo")
}

disp <- disp %>%
  mutate(
    tattoo = trimws(as.character(tattoo)),
    from_year = as.integer(from_year),
    to_year = as.integer(to_year),
    state_confidence = case_when(
      p_high_mobility < 0.20 ~ "strong_local",
      p_high_mobility > 0.80 ~ "strong_high_mobility",
      TRUE ~ "uncertain"
    ),
    sex_label = case_when(
      sex == 0L ~ "Female",
      sex == 1L ~ "Male",
      TRUE ~ "Unknown"
    )
  )

req_annual <- c("tattoo", "year", "annual_socg", "annual_x", "annual_y", "has_annual_xy")
if (!all(req_annual %in% names(annual)))
  stop("Annual observed-location file lacks: ",
       paste(setdiff(req_annual, names(annual)), collapse = ", "))

annual2 <- annual %>%
  transmute(
    tattoo = trimws(as.character(tattoo)),
    year = as.integer(year),
    annual_socg = na_if(trimws(as.character(annual_socg)), ""),
    annual_x = as.numeric(annual_x),
    annual_y = as.numeric(annual_y),
    has_annual_xy = as.logical(has_annual_xy)
  ) %>%
  arrange(tattoo, year) %>%
  group_by(tattoo) %>%
  mutate(
    previous_year = lag(year),
    previous_x = lag(annual_x),
    previous_y = lag(annual_y),
    previous_socg = lag(annual_socg),
    year_gap = year - previous_year,
    observed_move_m = sqrt((annual_x - previous_x)^2 + (annual_y - previous_y)^2),
    observed_sg_switch = case_when(
      is.na(previous_socg) | is.na(annual_socg) ~ NA,
      TRUE ~ annual_socg != previous_socg
    )
  ) %>%
  ungroup() %>%
  filter(
    year_gap == 1L,
    is.finite(observed_move_m),
    isTRUE(has_annual_xy) | has_annual_xy
  ) %>%
  transmute(
    tattoo,
    from_year = previous_year,
    to_year = year,
    observed_move_m,
    observed_sg_switch
  )

move_check <- disp %>%
  inner_join(annual2, by = c("tattoo", "from_year", "to_year"))

if (!nrow(move_check))
  stop("No adjacent-year observed movement rows matched the V9 movement intervals.")

safe_rate <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  mean(x, na.rm = TRUE)
}

summarise_movement <- function(d) {
  d %>%
    summarise(
      n = n(),
      median_move_m = median(observed_move_m, na.rm = TRUE),
      q25_move_m = quantile(observed_move_m, 0.25, na.rm = TRUE),
      q75_move_m = quantile(observed_move_m, 0.75, na.rm = TRUE),
      q90_move_m = quantile(observed_move_m, 0.90, na.rm = TRUE),
      q95_move_m = quantile(observed_move_m, 0.95, na.rm = TRUE),
      prop_gt_250m = mean(observed_move_m > 250, na.rm = TRUE),
      prop_gt_500m = mean(observed_move_m > 500, na.rm = TRUE),
      prop_gt_1000m = mean(observed_move_m > 1000, na.rm = TRUE),
      sg_switch_rate = safe_rate(observed_sg_switch),
      median_p_high = median(p_high_mobility, na.rm = TRUE),
      .groups = "drop"
    )
}

move_summary_overall <- move_check %>%
  group_by(state_confidence) %>%
  summarise_movement() %>%
  mutate(stratum = "All", .before = 1)

move_summary_sex <- move_check %>%
  filter(sex_label %in% c("Female", "Male")) %>%
  group_by(sex_label, state_confidence) %>%
  summarise_movement() %>%
  rename(stratum = sex_label)

move_summary <- bind_rows(move_summary_overall, move_summary_sex)

move_continuous <- tibble(
  n = nrow(move_check),
  spearman_p_high_vs_observed_move =
    suppressWarnings(cor(move_check$p_high_mobility,
                         move_check$observed_move_m,
                         method = "spearman",
                         use = "complete.obs")),
  median_p_high_no_sg_switch =
    median(move_check$p_high_mobility[move_check$observed_sg_switch %in% FALSE],
           na.rm = TRUE),
  median_p_high_sg_switch =
    median(move_check$p_high_mobility[move_check$observed_sg_switch %in% TRUE],
           na.rm = TRUE),
  n_observed_sg_switch =
    sum(move_check$observed_sg_switch %in% TRUE, na.rm = TRUE)
)

write_csv(move_summary,
          file.path(OUT_DIR, "V9_movement_observable_consistency_summary.csv"))
write_csv(move_continuous,
          file.path(OUT_DIR, "V9_movement_observable_consistency_continuous.csv"))

p1 <- move_check %>%
  filter(state_confidence %in% c("strong_local", "uncertain", "strong_high_mobility")) %>%
  mutate(
    state_confidence = factor(
      state_confidence,
      levels = c("strong_local", "uncertain", "strong_high_mobility"),
      labels = c("Strong local", "Uncertain", "Strong high mobility")
    )
  ) %>%
  ggplot(aes(x = state_confidence, y = observed_move_m)) +
  geom_boxplot(outlier.alpha = 0.12) +
  scale_y_log10() +
  labs(
    x = NULL,
    y = "Observed adjacent-year displacement (m; log scale)",
    title = "Observed displacement by posterior movement-state confidence",
    subtitle = "Consistency check only: the same movement observations contribute to state inference"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  file.path(OUT_DIR, "V9_movement_observed_displacement_by_state.png"),
  p1, width = 8, height = 5.5, dpi = 180
)

p2 <- move_check %>%
  filter(!is.na(observed_sg_switch)) %>%
  mutate(
    switch = if_else(observed_sg_switch, "Observed SG switch", "No observed SG switch")
  ) %>%
  ggplot(aes(x = switch, y = p_high_mobility)) +
  geom_boxplot(outlier.alpha = 0.12) +
  labs(
    x = NULL,
    y = "Posterior P(high mobility)",
    title = "Posterior high-mobility probability and observed social-group switching",
    subtitle = "Consistency check, not independent validation"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  file.path(OUT_DIR, "V9_movement_p_high_by_observed_sg_switch.png"),
  p2, width = 7, height = 5.5, dpi = 180
)

cat("\nMovement observable summary:\n")
print(move_summary, n = Inf, width = Inf)
cat("\nContinuous/switch summary:\n")
print(move_continuous, width = Inf)


# =============================================================================
# B. V7a POSTERIOR-PREDICTIVE CHECK
# =============================================================================

cat("\n\nB. V7a POSTERIOR-PREDICTIVE CHECK\n")
cat("---------------------------------\n")

a <- readRDS(V7A_FILE)

need_a <- c("coefficient_draws", "pair_counts")
if (!all(need_a %in% names(a)))
  stop("V7a object lacks coefficient_draws and/or pair_counts.")

ad <- as_tibble(a$coefficient_draws)
ac <- as_tibble(a$pair_counts)

need_ad <- c("pair_draw", "alpha", "beta_inf", "beta_sex")
if (!all(need_ad %in% names(ad)))
  stop("V7a coefficient draws lack: ",
       paste(setdiff(need_ad, names(ad)), collapse = ", "))

strata_a <- tibble(
  label = c("Female uninfected", "Male uninfected",
            "Female infected", "Male infected"),
  n_col = c("n_F_U", "n_M_U", "n_F_I", "n_M_I"),
  y_col = c("y_F_U", "y_M_U", "y_F_I", "y_M_I"),
  sex = c(0, 1, 0, 1),
  infected = c(0, 0, 1, 1)
)

aa <- ad %>%
  left_join(ac, by = "pair_draw")

if (anyNA(aa$n_F_U))
  stop("V7a coefficient draws did not match pair_counts by pair_draw.")

v7a_obs <- matrix(NA_real_, nrow = nrow(aa), ncol = 5)
v7a_rep <- matrix(NA_real_, nrow = nrow(aa), ncol = 5)
colnames(v7a_obs) <- colnames(v7a_rep) <-
  c("Total", strata_a$label)

for (j in seq_len(nrow(strata_a))) {
  s <- strata_a[j, ]
  n <- aa[[s$n_col]]
  y <- aa[[s$y_col]]
  p <- plogis(
    aa$alpha +
      aa$beta_inf * s$infected +
      aa$beta_sex * s$sex
  )
  yr <- rbinom(nrow(aa), size = n, prob = p)

  v7a_obs[, j + 1L] <- y
  v7a_rep[, j + 1L] <- yr
}

v7a_obs[, 1] <- rowSums(v7a_obs[, -1, drop = FALSE])
v7a_rep[, 1] <- rowSums(v7a_rep[, -1, drop = FALSE])

summarise_ppc_matrix <- function(obs, rep) {
  map_dfr(seq_len(ncol(obs)), function(j) {
    tibble(
      statistic = colnames(obs)[j],
      observed_median = median(obs[, j], na.rm = TRUE),
      observed_q025 = quantile(obs[, j], 0.025, na.rm = TRUE),
      observed_q975 = quantile(obs[, j], 0.975, na.rm = TRUE),
      replicated_median = median(rep[, j], na.rm = TRUE),
      replicated_q025 = quantile(rep[, j], 0.025, na.rm = TRUE),
      replicated_q975 = quantile(rep[, j], 0.975, na.rm = TRUE),
      posterior_predictive_P_rep_ge_obs = mean(rep[, j] >= obs[, j], na.rm = TRUE),
      median_rep_minus_obs = median(rep[, j] - obs[, j], na.rm = TRUE)
    )
  })
}

v7a_ppc <- summarise_ppc_matrix(v7a_obs, v7a_rep)
write_csv(v7a_ppc, file.path(OUT_DIR, "V9FINAL_V7a_posterior_predictive_counts.csv"))

cat("\nV7a posterior-predictive count checks:\n")
print(v7a_ppc, n = Inf, width = Inf)


# =============================================================================
# C. V7b POSTERIOR-PREDICTIVE CHECK
# =============================================================================

cat("\n\nC. V7b POSTERIOR-PREDICTIVE CHECK\n")
cat("---------------------------------\n")

b <- readRDS(V7B_FILE)

need_b <- c("coefficient_draws", "pair_counts", "design")
if (!all(need_b %in% names(b)))
  stop("V7b object lacks coefficient_draws, pair_counts and/or design.")

bd <- as_tibble(b$coefficient_draws)
X <- as.matrix(b$design)
nmat <- as.matrix(b$pair_counts$n)
ymat <- as.matrix(b$pair_counts$y)
cells <- as_tibble(b$pair_counts$cells)

if (!identical(dim(nmat), dim(ymat)))
  stop("V7b n and y matrices have different dimensions.")
if (ncol(nmat) != nrow(X) || nrow(X) != nrow(cells))
  stop("V7b n/y cells and design matrix do not align.")

par_names <- colnames(X)
if (!all(par_names %in% names(bd)))
  stop("V7b coefficient draws lack design parameters: ",
       paste(setdiff(par_names, names(bd)), collapse = ", "))

# The rows of n/y were created in the same paired-history order as pair_diagnostics.
pair_order <- NULL
if (!is.null(b$pair_diagnostics) && "pair_draw" %in% names(b$pair_diagnostics)) {
  pair_order <- as.integer(b$pair_diagnostics$pair_draw)
}
if (is.null(pair_order) || length(pair_order) != nrow(nmat)) {
  # Safe fallback for the canonical full run, whose pair rows are 1..1500.
  pair_order <- seq_len(nrow(nmat))
}

pair_row <- match(as.integer(bd$pair_draw), pair_order)
if (anyNA(pair_row))
  stop("Could not map every V7b coefficient draw to its paired-history count row.")

stat_indices <- list(
  "Total" = seq_len(nrow(cells)),
  "Local movement" = which(cells$movement_state == 0),
  "High mobility" = which(cells$movement_state == 1),
  "Female" = which(cells$sex == 0),
  "Male" = which(cells$sex == 1)
)

for (q in sort(unique(cells$outcome_quarter))) {
  stat_indices[[paste0("Quarter ", q)]] <- which(cells$outcome_quarter == q)
}
for (p in sort(unique(cells$period_start))) {
  stat_indices[[paste0("Period ", p)]] <- which(cells$period_start == p)
}

n_draws <- nrow(bd)
n_stats <- length(stat_indices)
obs_stats <- matrix(NA_real_, nrow = n_draws, ncol = n_stats,
                    dimnames = list(NULL, names(stat_indices)))
rep_stats <- matrix(NA_real_, nrow = n_draws, ncol = n_stats,
                    dimnames = list(NULL, names(stat_indices)))

chunk_size <- 1000L
starts <- seq.int(1L, n_draws, by = chunk_size)

for (ss in starts) {
  ee <- min(n_draws, ss + chunk_size - 1L)
  rr <- ss:ee

  B <- as.matrix(bd[rr, par_names, drop = FALSE])
  eta <- B %*% t(X)
  prob <- plogis(eta)

  N <- nmat[pair_row[rr], , drop = FALSE]
  Y <- ymat[pair_row[rr], , drop = FALSE]

  Yrep <- matrix(
    rbinom(length(N), size = as.vector(N), prob = as.vector(prob)),
    nrow = nrow(N),
    ncol = ncol(N)
  )

  jj <- 0L
  for (nm in names(stat_indices)) {
    jj <- jj + 1L
    cc <- stat_indices[[nm]]
    obs_stats[rr, jj] <- rowSums(Y[, cc, drop = FALSE])
    rep_stats[rr, jj] <- rowSums(Yrep[, cc, drop = FALSE])
  }

  if (ee %% 10000L == 0L || ee == n_draws)
    cat("  simulated ", ee, " / ", n_draws, " posterior-predictive draws\n", sep = "")
}

v7b_ppc <- summarise_ppc_matrix(obs_stats, rep_stats)
write_csv(v7b_ppc, file.path(OUT_DIR, "V9FINAL_V7b_posterior_predictive_counts.csv"))

cat("\nV7b posterior-predictive count checks:\n")
print(v7b_ppc, n = Inf, width = Inf)


# =============================================================================
# D. COMPACT PPC FLAGS
# =============================================================================

flag_ppc <- function(tab, model) {
  tab %>%
    mutate(
      model = model,
      ppc_flag = case_when(
        posterior_predictive_P_rep_ge_obs < 0.025 |
          posterior_predictive_P_rep_ge_obs > 0.975 ~ "CHECK",
        posterior_predictive_P_rep_ge_obs < 0.05 |
          posterior_predictive_P_rep_ge_obs > 0.95 ~ "MILD",
        TRUE ~ "OK"
      ),
      .before = 1
    )
}

flags <- bind_rows(
  flag_ppc(v7a_ppc, "V7a"),
  flag_ppc(v7b_ppc, "V7b")
)

write_csv(flags, file.path(OUT_DIR, "V9FINAL_phase2_ppc_flags.csv"))

cat("\n\n============================================================\n")
cat("TARGETED PHASE-2 MODEL CHECKS COMPLETE\n")
cat("============================================================\n")
cat("\nPPC flags (these are diagnostics, not hypothesis tests):\n")
print(flags %>% select(model, statistic, posterior_predictive_P_rep_ge_obs, ppc_flag),
      n = Inf, width = Inf)

cat("\nSaved:\n")
cat("  ", file.path(OUT_DIR, "V9_movement_observable_consistency_summary.csv"), "\n", sep = "")
cat("  ", file.path(OUT_DIR, "V9_movement_observable_consistency_continuous.csv"), "\n", sep = "")
cat("  ", file.path(OUT_DIR, "V9_movement_observed_displacement_by_state.png"), "\n", sep = "")
cat("  ", file.path(OUT_DIR, "V9_movement_p_high_by_observed_sg_switch.png"), "\n", sep = "")
cat("  ", file.path(OUT_DIR, "V9FINAL_V7a_posterior_predictive_counts.csv"), "\n", sep = "")
cat("  ", file.path(OUT_DIR, "V9FINAL_V7b_posterior_predictive_counts.csv"), "\n", sep = "")
cat("  ", file.path(OUT_DIR, "V9FINAL_phase2_ppc_flags.csv"), "\n", sep = "")

cat("\nInterpretation rules:\n")
cat("  * Movement section = observable consistency check, NOT independent validation.\n")
cat("  * V7a/V7b = posterior-predictive outcome checks conditional on each sampled latent history.\n")
cat("  * Extreme posterior-predictive probabilities flag where the model systematically\n")
cat("    under- or over-reproduces an observed count; they are not conventional p-values.\n")
cat("  * No NIMBLE model has been refitted by this script.\n")
