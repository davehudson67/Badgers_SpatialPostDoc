# =============================================================================
# Woodchester V10B collapsed-HMM: global movement-ridge diagnostic
#
# PURPOSE
#   Diagnose the remaining cross-chain non-convergence after annual-trajectory
#   blocking. In particular, determine whether chains are still drifting along
#   the local-movement / high-movement-contrast ridge:
#
#       alpha_logmove  <->  beta_move_high
#
#   while the implied high-mobility scale is already stable.
#
# Reads three fitted chain RDS files. No MCMC is run.
#
# Environment:
#   FILE_STEM    result filename stem
#                default V10B_RD_MULTILOC_AR1_COLLAPSED
#   MAX_BADGERS  fitted population size (default 100)
# =============================================================================

library(tidyverse)
library(coda)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "100"))
FILE_STEM <- Sys.getenv(
  "FILE_STEM",
  unset = "V10B_RD_MULTILOC_AR1_COLLAPSED"
)
CHAIN_IDS <- 1:3

prefix <- file.path(
  "results",
  paste0(FILE_STEM, "_", MAX_BADGERS)
)
chain_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, ".rds")

missing <- chain_files[!file.exists(chain_files)]
if (length(missing)) {
  stop("Missing chain file(s):\n", paste(missing, collapse = "\n"))
}

cat("\n============================================================\n")
cat("V10B GLOBAL MOVEMENT-RIDGE DIAGNOSTIC\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("File stem:", FILE_STEM, "\n\n")

segment_results <- list()
corr_results <- list()
derived_chains <- vector("list", 3)

for (ch in CHAIN_IDS) {
  fit <- readRDS(chain_files[ch])
  mm <- as.matrix(fit$samples)

  required <- c(
    "alpha_logmove",
    "beta_move_high",
    "beta_move_sex",
    "rho",
    "omega",
    "mean_annual_move_female_local",
    "mean_annual_move_male_local",
    "mean_annual_move_female_high",
    "mean_annual_move_male_high"
  )

  missing_cols <- setdiff(required, colnames(mm))
  if (length(missing_cols)) {
    stop(
      "Chain ", ch, " missing columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  n <- nrow(mm)
  seg <- cut(
    seq_len(n),
    breaks = c(0, floor(n/4), floor(n/2), floor(3*n/4), n),
    labels = c("Q1", "Q2", "Q3", "Q4"),
    include.lowest = TRUE
  )

  seg_tbl <- tibble(
    draw = seq_len(n),
    segment = seg,
    alpha_logmove = mm[, "alpha_logmove"],
    beta_move_high = mm[, "beta_move_high"],
    beta_move_sex = mm[, "beta_move_sex"],
    rho = mm[, "rho"],
    omega = mm[, "omega"],
    female_local = mm[, "mean_annual_move_female_local"],
    male_local = mm[, "mean_annual_move_male_local"],
    female_high = mm[, "mean_annual_move_female_high"],
    male_high = mm[, "mean_annual_move_male_high"],
    log_female_high_sigma =
      mm[, "alpha_logmove"] + mm[, "beta_move_high"]
  )

  segment_results[[ch]] <- seg_tbl %>%
    group_by(segment) %>%
    summarise(
      chain = ch,
      n = n(),
      alpha_logmove = mean(alpha_logmove),
      beta_move_high = mean(beta_move_high),
      rho = mean(rho),
      omega = mean(omega),
      female_local = mean(female_local),
      male_local = mean(male_local),
      female_high = mean(female_high),
      male_high = mean(male_high),
      .groups = "drop"
    ) %>%
    select(chain, everything())

  corr_results[[ch]] <- tibble(
    chain = ch,
    cor_alpha_logmove_beta_move_high =
      cor(
        seg_tbl$alpha_logmove,
        seg_tbl$beta_move_high
      ),
    cor_female_local_female_high =
      cor(
        seg_tbl$female_local,
        seg_tbl$female_high
      ),
    cor_rho_female_local =
      cor(
        seg_tbl$rho,
        seg_tbl$female_local
      ),
    q1_to_q4_change_female_local =
      mean(
        seg_tbl$female_local[seg_tbl$segment == "Q4"]
      ) -
      mean(
        seg_tbl$female_local[seg_tbl$segment == "Q1"]
      ),
    q1_to_q4_change_female_high =
      mean(
        seg_tbl$female_high[seg_tbl$segment == "Q4"]
      ) -
      mean(
        seg_tbl$female_high[seg_tbl$segment == "Q1"]
      ),
    q1_to_q4_change_rho =
      mean(
        seg_tbl$rho[seg_tbl$segment == "Q4"]
      ) -
      mean(
        seg_tbl$rho[seg_tbl$segment == "Q1"]
      )
  )

  derived_chains[[ch]] <- coda::mcmc(
    cbind(
      log_female_local_sigma =
        mm[, "alpha_logmove"],
      log_female_high_sigma =
        mm[, "alpha_logmove"] +
        mm[, "beta_move_high"],
      log_high_to_local_ratio =
        mm[, "beta_move_high"],
      rho =
        mm[, "rho"],
      omega =
        mm[, "omega"],
      female_local =
        mm[, "mean_annual_move_female_local"],
      female_high =
        mm[, "mean_annual_move_female_high"]
    )
  )

  rm(fit, mm, seg_tbl)
  invisible(gc())
}

segment_tbl <- bind_rows(segment_results)
corr_tbl <- bind_rows(corr_results)

mcmc_list <- coda::mcmc.list(derived_chains)

rhat <- gelman.diag(
  mcmc_list,
  autoburnin = FALSE,
  multivariate = FALSE
)$psrf[, 1]

ess <- effectiveSize(mcmc_list)

param_names <- names(rhat)

if (is.null(param_names) || !length(param_names)) {
  param_names <- colnames(as.matrix(derived_chains[[1]]))
}

if (length(ess) != length(param_names)) {
  stop(
    "ESS length (", length(ess),
    ") does not match derived-parameter count (",
    length(param_names), ")."
  )
}

# coda::effectiveSize() can return an unnamed numeric vector for mcmc.list
# objects. When that happens, its order follows the monitored column order.
if (is.null(names(ess)) || !all(param_names %in% names(ess))) {
  ess_values <- as.numeric(ess)
} else {
  ess_values <- as.numeric(ess[param_names])
}

derived_diag <- tibble(
  parameter = param_names,
  rhat = as.numeric(rhat),
  ess = ess_values
) %>%
  arrange(desc(rhat))

cat("============================================================\n")
cat("DERIVED-PARAMETER CONVERGENCE\n")
cat("============================================================\n")
print(derived_diag, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("WITHIN-CHAIN RIDGE CORRELATIONS AND Q1 -> Q4 CHANGE\n")
cat("============================================================\n")
print(corr_tbl, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("POSTERIOR QUARTER MEANS BY CHAIN\n")
cat("============================================================\n")
print(segment_tbl, n = Inf, width = Inf)

# A compact interpretation aid. This does not replace visual trace inspection,
# but distinguishes obvious ongoing drift from flat separated chains.
trend_tbl <- segment_tbl %>%
  select(
    chain,
    segment,
    female_local,
    female_high,
    rho
  ) %>%
  pivot_longer(
    cols = c(female_local, female_high, rho),
    names_to = "parameter",
    values_to = "mean"
  ) %>%
  group_by(chain, parameter) %>%
  summarise(
    q1 = mean[segment == "Q1"],
    q4 = mean[segment == "Q4"],
    q4_minus_q1 = q4 - q1,
    .groups = "drop"
  )

cat("\n============================================================\n")
cat("Q1 VS Q4 TREND SUMMARY\n")
cat("============================================================\n")
print(trend_tbl, n = Inf, width = Inf)

out_segments <- paste0(prefix, "_global_ridge_segments.csv")
out_corr <- paste0(prefix, "_global_ridge_correlations.csv")
out_diag <- paste0(prefix, "_global_ridge_convergence.csv")

write_csv(segment_tbl, out_segments)
write_csv(corr_tbl, out_corr)
write_csv(derived_diag, out_diag)

cat("\nSaved:\n")
cat(out_segments, "\n")
cat(out_corr, "\n")
cat(out_diag, "\n")
cat("\nGLOBAL RIDGE DIAGNOSTIC COMPLETE\n")
