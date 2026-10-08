# =============================================================================
# V10B COLLAPSED-HMM: 300-BADGER MOVEMENT-SCALE / AC DIAGNOSTIC
#
# Post-processing only. Does NOT run MCMC.
#
# Reads the existing 300-badger collapsed chains and recovered-state sidecars
# and diagnoses:
#   - chain-specific local/high movement scales;
#   - alpha_logmove <-> beta_move_high posterior ridge;
#   - proximity to the 5 m / 2500 m computational movement-scale guards;
#   - annual-AC displacement summaries for the most chain-discordant states;
#   - whether discordant intervals span years with no observed live capture.
#
# Output:
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_300_movement_diagnostic.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_300_movement_scale_by_chain.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_300_worst_state_AC_diagnostic.csv
# =============================================================================

library(tidyverse)

N <- 300L
CHAIN_IDS <- 1:3
MOVE_MIN <- 5
MOVE_MAX <- 2500
RAYLEIGH_MEAN_FACTOR <- sqrt(pi / 2)

prefix <- file.path(
  "results",
  paste0("V10B_RD_MULTILOC_AR1_COLLAPSED_", N)
)

chain_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, ".rds")
state_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, "_STATES.rds")

missing <- c(chain_files, state_files)[
  !file.exists(c(chain_files, state_files))
]
if (length(missing)) {
  stop("Missing required posterior file(s):\n", paste(missing, collapse = "\n"))
}

fits <- lapply(chain_files, readRDS)
states <- lapply(state_files, readRDS)

if (!all(vapply(
  fits,
  function(x) identical(x$model, "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM"),
  logical(1)
))) {
  stop("At least one input chain is not the collapsed V10B model.")
}

mats <- lapply(fits, function(x) as.matrix(x$samples))

needed <- c(
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_high"
)

for (ch in seq_along(mats)) {
  miss <- setdiff(needed, colnames(mats[[ch]]))
  if (length(miss)) {
    stop("Chain ", ch, " missing: ", paste(miss, collapse = ", "))
  }
}

cat("\n============================================================\n")
cat("V10B COLLAPSED 300: MOVEMENT DIAGNOSTIC\n")
cat("============================================================\n")

# -----------------------------------------------------------------------------
# 1. Chain-specific movement-scale geometry
# -----------------------------------------------------------------------------
scale_draws <- bind_rows(
  lapply(
    seq_along(mats),
    function(ch) {
      mm <- mats[[ch]]

      tibble(
        chain = CHAIN_IDS[ch],
        draw = seq_len(nrow(mm)),
        alpha_logmove = mm[, "alpha_logmove"],
        beta_move_sex = mm[, "beta_move_sex"],
        beta_move_high = mm[, "beta_move_high"],
        sigma_F_local = exp(alpha_logmove),
        sigma_M_local = exp(alpha_logmove + beta_move_sex),
        sigma_F_high = exp(alpha_logmove + beta_move_high),
        sigma_M_high = exp(
          alpha_logmove +
            beta_move_sex +
            beta_move_high
        ),
        mean_F_local = sigma_F_local * RAYLEIGH_MEAN_FACTOR,
        mean_M_local = sigma_M_local * RAYLEIGH_MEAN_FACTOR,
        mean_F_high = sigma_F_high * RAYLEIGH_MEAN_FACTOR,
        mean_M_high = sigma_M_high * RAYLEIGH_MEAN_FACTOR
      )
    }
  )
)

qfun <- function(x, p) unname(quantile(x, p, na.rm = TRUE))

scale_by_chain <- scale_draws %>%
  group_by(chain) %>%
  summarise(
    n_draws = n(),
    alpha_logmove_mean = mean(alpha_logmove),
    beta_move_high_mean = mean(beta_move_high),
    cor_alpha_beta_high = cor(alpha_logmove, beta_move_high),

    sigma_F_local_mean = mean(sigma_F_local),
    sigma_F_local_q001 = qfun(sigma_F_local, 0.001),
    sigma_F_local_q01 = qfun(sigma_F_local, 0.01),
    sigma_F_local_q025 = qfun(sigma_F_local, 0.025),
    sigma_F_local_median = median(sigma_F_local),
    sigma_F_local_min = min(sigma_F_local),

    sigma_M_local_mean = mean(sigma_M_local),
    sigma_M_local_q001 = qfun(sigma_M_local, 0.001),
    sigma_M_local_q01 = qfun(sigma_M_local, 0.01),
    sigma_M_local_q025 = qfun(sigma_M_local, 0.025),
    sigma_M_local_median = median(sigma_M_local),
    sigma_M_local_min = min(sigma_M_local),

    prop_F_local_lt_5_25 = mean(sigma_F_local < 5.25),
    prop_F_local_lt_5_5 = mean(sigma_F_local < 5.5),
    prop_F_local_lt_6 = mean(sigma_F_local < 6),
    prop_M_local_lt_5_25 = mean(sigma_M_local < 5.25),
    prop_M_local_lt_5_5 = mean(sigma_M_local < 5.5),
    prop_M_local_lt_6 = mean(sigma_M_local < 6),

    sigma_F_high_mean = mean(sigma_F_high),
    sigma_F_high_q975 = qfun(sigma_F_high, 0.975),
    sigma_F_high_max = max(sigma_F_high),
    sigma_M_high_mean = mean(sigma_M_high),
    sigma_M_high_q975 = qfun(sigma_M_high, 0.975),
    sigma_M_high_max = max(sigma_M_high),

    prop_F_high_gt_2000 = mean(sigma_F_high > 2000),
    prop_M_high_gt_2000 = mean(sigma_M_high > 2000),
    .groups = "drop"
  )

cat("\nChain-specific movement scales and support proximity:\n")
print(scale_by_chain, n = Inf, width = Inf)

pooled_support <- scale_draws %>%
  summarise(
    min_F_local = min(sigma_F_local),
    min_M_local = min(sigma_M_local),
    prop_F_local_lt_5_25 = mean(sigma_F_local < 5.25),
    prop_M_local_lt_5_25 = mean(sigma_M_local < 5.25),
    prop_F_local_lt_5_5 = mean(sigma_F_local < 5.5),
    prop_M_local_lt_5_5 = mean(sigma_M_local < 5.5),
    prop_F_local_lt_6 = mean(sigma_F_local < 6),
    prop_M_local_lt_6 = mean(sigma_M_local < 6),
    max_F_high = max(sigma_F_high),
    max_M_high = max(sigma_M_high),
    prop_F_high_gt_2000 = mean(sigma_F_high > 2000),
    prop_M_high_gt_2000 = mean(sigma_M_high > 2000)
  )

cat("\nPooled support diagnostic:\n")
print(pooled_support, n = Inf, width = Inf)

# -----------------------------------------------------------------------------
# 2. Movement-state chain disagreement from exact smoothing
# -----------------------------------------------------------------------------
disp_index <- fits[[1]]$disp_index

state_mat <- sapply(
  states,
  function(x) x$p_high_smoothed_chain
)
colnames(state_mat) <- paste0("p_high_chain", CHAIN_IDS)

state_diag <- bind_cols(
  disp_index,
  as_tibble(state_mat)
) %>%
  mutate(
    p_high_pooled = rowMeans(state_mat),
    max_chain_difference = apply(
      state_mat,
      1,
      function(z) max(z) - min(z)
    )
  ) %>%
  arrange(desc(max_chain_difference))

# -----------------------------------------------------------------------------
# 3. Posterior annual-AC displacement for worst discordant intervals
# -----------------------------------------------------------------------------
annual_index <- fits[[1]]$annual_state_index

annual_key <- annual_index %>%
  select(
    annual_active_index,
    model_i,
    individual_id,
    tattoo,
    state_k,
    year,
    sample_column_x,
    sample_column_y
  )

summarise_interval_AC <- function(row, ch) {
  mm <- mats[[ch]]

  aa0 <- annual_key %>%
    filter(
      model_i == row$model_i,
      state_k == row$state_k - 1L
    )
  aa1 <- annual_key %>%
    filter(
      model_i == row$model_i,
      state_k == row$state_k
    )

  if (nrow(aa0) != 1L || nrow(aa1) != 1L) {
    stop(
      "Could not uniquely map annual ACs for ",
      row$tattoo, " ", row$from_year, "->", row$to_year
    )
  }

  x0 <- mm[, aa0$sample_column_x]
  y0 <- mm[, aa0$sample_column_y]
  x1 <- mm[, aa1$sample_column_x]
  y1 <- mm[, aa1$sample_column_y]

  dd <- sqrt((x1 - x0)^2 + (y1 - y0)^2)

  tibble(
    chain = CHAIN_IDS[ch],
    displacement_mean_m = mean(dd),
    displacement_median_m = median(dd),
    displacement_q025_m = qfun(dd, 0.025),
    displacement_q975_m = qfun(dd, 0.975),
    A0_x_mean = mean(x0),
    A0_y_mean = mean(y0),
    A1_x_mean = mean(x1),
    A1_y_mean = mean(y1)
  )
}

# Reconstruct observed-live years from ncap arrays saved with the fit.
observed_live_year <- function(fit, model_i, state_k) {
  sum(fit$ncap[model_i, , state_k]) > 0
}

worst_n <- min(30L, nrow(state_diag))

worst_AC <- bind_rows(
  lapply(
    seq_len(worst_n),
    function(rr) {
      row <- state_diag[rr, ]

      per_chain <- bind_rows(
        lapply(
          seq_along(fits),
          function(ch) summarise_interval_AC(row, ch)
        )
      )

      bind_cols(
        row %>%
          select(
            active_index,
            model_i,
            individual_id,
            tattoo,
            state_k,
            from_year,
            to_year,
            starts_with("p_high_chain"),
            p_high_pooled,
            max_chain_difference
          ) %>%
          slice(rep(1, nrow(per_chain))),
        per_chain
      ) %>%
        mutate(
          observed_from_year =
            observed_live_year(fits[[1]], row$model_i, row$state_k - 1L),
          observed_to_year =
            observed_live_year(fits[[1]], row$model_i, row$state_k),
          both_endpoint_years_observed =
            observed_from_year & observed_to_year
        )
    }
  )
)

cat("\nWorst 30 state-discordant intervals with annual-AC displacement summaries:\n")
print(worst_AC, n = Inf, width = Inf)

discordance_observation_summary <- worst_AC %>%
  distinct(
    active_index,
    tattoo,
    from_year,
    to_year,
    max_chain_difference,
    observed_from_year,
    observed_to_year,
    both_endpoint_years_observed
  ) %>%
  summarise(
    n_intervals = n(),
    n_both_endpoints_observed = sum(both_endpoint_years_observed),
    n_at_least_one_endpoint_unobserved =
      sum(!both_endpoint_years_observed)
  )

cat("\nObservation coverage among worst intervals:\n")
print(discordance_observation_summary, width = Inf)

# -----------------------------------------------------------------------------
# 4. Automated decision aid
# -----------------------------------------------------------------------------
# This is deliberately conservative. It is not a statistical acceptance test;
# it simply flags whether the artificial movement support appears influential.
support_close <- with(
  pooled_support,
  prop_F_local_lt_5_5 > 0.01 ||
    prop_M_local_lt_5_5 > 0.01 ||
    prop_F_high_gt_2000 > 0.01 ||
    prop_M_high_gt_2000 > 0.01
)

cat("\n============================================================\n")
cat("DIAGNOSTIC DECISION AID\n")
cat("============================================================\n")

if (support_close) {
  cat(
    "CAUTION: >1% of posterior draws lie close to a computational movement ",
    "support bound. Inspect before final production.\n",
    sep = ""
  )
} else {
  cat(
    "SUPPORT CHECK: PASS -- posterior movement scales are not materially ",
    "piling against the computational guards.\n",
    sep = ""
  )
}

cat(
  "NOTE: alpha_logmove/beta_move_high chain mixing remains a convergence ",
  "diagnostic; the support check does not override Rhat/ESS.\n"
)

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------
out <- list(
  chain_files = chain_files,
  state_files = state_files,
  scale_draws = scale_draws,
  scale_by_chain = scale_by_chain,
  pooled_support = pooled_support,
  state_diag = state_diag,
  worst_AC = worst_AC,
  discordance_observation_summary = discordance_observation_summary,
  support_close = support_close
)

saveRDS(
  out,
  paste0(prefix, "_movement_diagnostic.rds")
)

write_csv(
  scale_by_chain,
  paste0(prefix, "_movement_scale_by_chain.csv")
)

write_csv(
  worst_AC,
  paste0(prefix, "_worst_state_AC_diagnostic.csv")
)

cat("\nSaved movement diagnostic outputs with prefix:\n", prefix, "_*\n", sep = "")
cat("\nMOVEMENT DIAGNOSTIC COMPLETE\n")
