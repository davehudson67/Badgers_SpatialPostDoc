# =============================================================================
# WOODCHESTER V11R - THREE-CHAIN CONVERGENCE / STATE-AGREEMENT SUMMARY
#
# Environment:
#   MAX_BADGERS default 300
#   FILE_STEM default V11R_RES50_RD_ANNUALAC_FIXEDRES_MULTILOC_AGE_BADGERRE
#
# Requires fit and recovered-state files for chains 1:3.
# =============================================================================

library(tidyverse)
library(coda)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "300"))
FILE_STEM <- Sys.getenv(
  "FILE_STEM",
  unset = "V11R_RES50_RD_ANNUALAC_FIXEDRES_MULTILOC_AGE_BADGERRE"
)

prefix <- file.path("results", paste0(FILE_STEM, "_", MAX_BADGERS))
fit_files <- paste0(prefix, "_CHAIN", 1:3, ".rds")
state_files <- paste0(prefix, "_CHAIN", 1:3, "_STATES.rds")

missing <- c(fit_files[!file.exists(fit_files)], state_files[!file.exists(state_files)])
if (length(missing)) stop("Missing required file(s):\n", paste(missing, collapse = "\n"))

fits <- lapply(fit_files, readRDS)
states <- lapply(state_files, readRDS)

expected_model <- "V11R_RD_SCR_ANNUALAC_FIXEDRES_MULTILOC_AGE_BADGERRE_COLLAPSED_HMM"
if (any(!vapply(fits, function(x) identical(x$model, expected_model), logical(1)))) {
  stop("At least one input is not a V11R fixed-resident fit.")
}

resident_means <- vapply(
  fits,
  function(x) as.numeric(x$settings$resident_mean_m),
  numeric(1)
)
if (any(!is.finite(resident_means)) || length(unique(resident_means)) != 1L) {
  stop("V11R chains do not share one fixed resident mean scale.")
}
resident_mean_m <- resident_means[1]

key <- c(
  "sigma_female",
  "sigma_male",
  "sigma_badger",
  "beta_move_high",
  "beta_move_sex",
  "mean_annual_move_female_high",
  "mean_annual_move_male_high",
  "alpha_disp_init",
  "beta_disp_init_sex",
  "alpha_RD",
  "beta_RD_sex",
  "beta_age_2",
  "beta_age_3_5",
  "beta_age_6plus",
  "beta_age_unknown",
  "alpha_DD",
  "beta_DD_sex"
)

mats <- lapply(fits, function(x) as.matrix(x$samples))
common <- Reduce(intersect, lapply(mats, colnames))
key <- intersect(key, common)

if (!length(key)) stop("No pre-specified key parameters found.")

ml <- mcmc.list(lapply(mats, function(m) mcmc(m[, key, drop = FALSE])))

gd <- gelman.diag(
  ml,
  autoburnin = FALSE,
  multivariate = FALSE,
  transform = FALSE
)$psrf

ess <- effectiveSize(ml)

pooled <- do.call(rbind, lapply(mats, function(m) m[, key, drop = FALSE]))

conv <- tibble(
  parameter = rownames(gd),
  rhat = gd[, 1],
  rhat_upper = gd[, 2],
  ess = as.numeric(ess[rownames(gd)])
) %>%
  mutate(
    mean = vapply(parameter, function(z) mean(pooled[, z]), numeric(1)),
    sd = vapply(parameter, function(z) sd(pooled[, z]), numeric(1)),
    q025 = vapply(parameter, function(z) quantile(pooled[, z], .025), numeric(1)),
    median = vapply(parameter, function(z) median(pooled[, z]), numeric(1)),
    q975 = vapply(parameter, function(z) quantile(pooled[, z], .975), numeric(1))
  ) %>%
  arrange(desc(rhat))

# Chain medians for direct scale comparison.
scale_params <- intersect(
  c(
    "beta_move_high",
    "beta_move_sex",
    "mean_annual_move_female_high",
    "mean_annual_move_male_high",
    "sigma_badger",
    "beta_RD_sex"
  ),
  common
)

chain_medians <- map_dfr(
  seq_along(mats),
  function(cc) {
    tibble(
      chain = cc,
      parameter = scale_params,
      median = vapply(
        scale_params,
        function(z) median(mats[[cc]][, z]),
        numeric(1)
      )
    )
  }
)

# Recovered-state cross-chain agreement.
idx1 <- states[[1]]$disp_index
if (!all(vapply(states, function(s) identical(s$disp_index, idx1), logical(1)))) {
  # exact tibble attributes can differ; require identifying columns to match
  idcols <- c("model_i", "tattoo", "state_k", "from_year", "to_year")
  for (cc in 2:3) {
    if (!identical(
      as.data.frame(states[[cc]]$disp_index[, idcols]),
      as.data.frame(idx1[, idcols])
    )) {
      stop("Recovered-state interval maps differ across chains.")
    }
  }
}

P <- do.call(
  cbind,
  lapply(states, function(s) as.numeric(s$p_high_smoothed_chain))
)
colnames(P) <- paste0("chain", 1:3)

state_range <- apply(P, 1, function(z) max(z) - min(z))
state_median_diff <- apply(
  P,
  1,
  function(z) median(abs(outer(z, z, "-"))[upper.tri(matrix(0, 3, 3))])
)

state_summary <- idx1 %>%
  mutate(
    chain1 = P[, 1],
    chain2 = P[, 2],
    chain3 = P[, 3],
    chain_range = state_range,
    median_pairwise_difference = state_median_diff,
    pooled_p_high = rowMeans(P)
  )

score <- tibble(
  n_key_parameters = nrow(conv),
  max_rhat = max(conv$rhat, na.rm = TRUE),
  median_rhat = median(conv$rhat, na.rm = TRUE),
  min_ess = min(conv$ess, na.rm = TRUE),
  median_ess = median(conv$ess, na.rm = TRUE),
  n_rhat_gt_1_05 = sum(conv$rhat > 1.05, na.rm = TRUE),
  n_rhat_gt_1_10 = sum(conv$rhat > 1.10, na.rm = TRUE),
  n_intervals = nrow(state_summary),
  state_n_gt_025 = sum(state_summary$chain_range > .25),
  state_n_gt_050 = sum(state_summary$chain_range > .50),
  state_n_gt_080 = sum(state_summary$chain_range > .80),
  state_prop_gt_025 = mean(state_summary$chain_range > .25),
  state_median_range = median(state_summary$chain_range),
  state_p95_range = quantile(state_summary$chain_range, .95),
  state_max_range = max(state_summary$chain_range)
)

safe_stem <- gsub("[^A-Za-z0-9_]+", "_", FILE_STEM)
out_stub <- paste0(safe_stem, "_", MAX_BADGERS)

write_csv(conv, file.path("results", paste0(out_stub, "_convergence.csv")))
write_csv(chain_medians, file.path("results", paste0(out_stub, "_chain_medians.csv")))
write_csv(state_summary, file.path("results", paste0(out_stub, "_state_agreement.csv")))
write_csv(score, file.path("results", paste0(out_stub, "_scorecard.csv")))

cat("\n============================================================\n")
cat("V11R THREE-CHAIN CONVERGENCE SUMMARY\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("Fixed resident mean radial displacement:", resident_mean_m, "m\n\n")

cat("SCORECARD\n")
print(score, width = Inf)

cat("\nKEY PARAMETER CONVERGENCE\n")
print(conv, n = Inf, width = Inf)

cat("\nCHAIN MEDIANS\n")
print(
  chain_medians %>%
    pivot_wider(names_from = chain, values_from = median, names_prefix = "chain"),
  n = Inf,
  width = Inf
)

cat("\nSTATE AGREEMENT\n")
cat("Intervals:", nrow(state_summary), "\n")
cat(">0.25 chain range:", sum(state_range > .25), "\n")
cat(">0.50 chain range:", sum(state_range > .50), "\n")
cat(">0.80 chain range:", sum(state_range > .80), "\n")
cat("Median range:", median(state_range), "\n")
cat("95th percentile range:", quantile(state_range, .95), "\n")
cat("Maximum range:", max(state_range), "\n")

cat("\nAnimals contributing most disagreement\n")
print(
  state_summary %>%
    group_by(tattoo) %>%
    summarise(
      n_intervals = n(),
      max_chain_range = max(chain_range),
      mean_chain_range = mean(chain_range),
      n_gt_025 = sum(chain_range > .25),
      .groups = "drop"
    ) %>%
    arrange(desc(max_chain_range), desc(n_gt_025)) %>%
    slice_head(n = 30),
  n = 30,
  width = Inf
)

cat("\nSaved V11R diagnostics in results/.\n")
