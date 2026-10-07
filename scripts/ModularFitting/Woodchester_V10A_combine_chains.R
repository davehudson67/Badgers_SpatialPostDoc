# =============================================================================
# Woodchester V10A: combine and diagnose independent MCMC chains
#
# Reads:
#   results/V10A_RD_MULTILOC_<N>_CHAIN1.rds
#   results/V10A_RD_MULTILOC_<N>_CHAIN2.rds
#   results/V10A_RD_MULTILOC_<N>_CHAIN3.rds
#
# Environment:
#   MAX_BADGERS   fitted population size in filenames (default 100)
#
# Writes:
#   results/V10A_RD_MULTILOC_<N>_COMBINED.rds
#   results/V10A_RD_MULTILOC_<N>_global_summary.csv
#   results/V10A_RD_MULTILOC_<N>_convergence.csv
#   results/V10A_RD_MULTILOC_<N>_chain_summary.csv
#   results/V10A_RD_MULTILOC_<N>_disp_probabilities.csv
#   results/V10A_RD_MULTILOC_<N>_disp_summary.csv
#   results/V10A_RD_MULTILOC_<N>_scale_correlations.csv
#
# Notes:
#   - Chains remain separate in mcmc_list for convergence diagnostics.
#   - pooled_samples is supplied only for posterior summaries, never for Rhat.
#   - Rhat below is the standard split-chain Gelman-Rubin statistic.
# =============================================================================

library(tidyverse)
library(coda)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "100"))
CHAIN_IDS <- 1:3

prefix <- file.path(
  "results",
  paste0("V10A_RD_MULTILOC_", MAX_BADGERS)
)

chain_files <- paste0(
  prefix,
  "_CHAIN",
  CHAIN_IDS,
  ".rds"
)

missing_files <- chain_files[!file.exists(chain_files)]
if (length(missing_files)) {
  stop(
    "Missing chain file(s):\n",
    paste(missing_files, collapse = "\n")
  )
}

cat("\n============================================================\n")
cat("WOODCHESTER V10A: COMBINE CHAINS\n")
cat("============================================================\n")
cat("Population size:", MAX_BADGERS, "\n")
cat("Reading:\n", paste(chain_files, collapse = "\n"), "\n\n")

fits <- lapply(chain_files, readRDS)

# -----------------------------------------------------------------------------
# Validate that these really are three fits of the same posterior
# -----------------------------------------------------------------------------
if (!all(vapply(fits, function(x) identical(x$model, "V10A_RD_SCR_MULTILOC"), logical(1)))) {
  stop("At least one file is not a V10A_RD_SCR_MULTILOC fit.")
}

if (!identical(vapply(fits, function(x) x$chain_id, integer(1)), CHAIN_IDS)) {
  stop("Chain IDs do not match expected 1, 2, 3.")
}

same_ids <- all(vapply(
  fits[-1],
  function(x) identical(x$ids, fits[[1]]$ids),
  logical(1)
))
if (!same_ids) stop("Chains do not contain the same badgers in the same order.")

same_years <- all(vapply(
  fits[-1],
  function(x) identical(x$years, fits[[1]]$years),
  logical(1)
))
if (!same_years) stop("Chains do not use the same year vector.")

same_first <- all(vapply(
  fits[-1],
  function(x) identical(x$first, fits[[1]]$first),
  logical(1)
))
same_K <- all(vapply(
  fits[-1],
  function(x) identical(x$K, fits[[1]]$K),
  logical(1)
))
if (!same_first || !same_K) stop("Chains do not contain identical annual histories.")

# Compare the biological movement-interval mapping rather than requiring
# byte-for-byte identity of the saved tibble. Attributes or auxiliary columns
# can differ harmlessly between serialized objects, while the key mapping must
# be identical.
disp_key_cols <- c(
  "active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "from_year",
  "to_year"
)

if (!all(vapply(
  fits,
  function(x) all(disp_key_cols %in% names(x$disp_index)),
  logical(1)
))) {
  stop("At least one chain is missing required disp_index key columns.")
}

disp_keys <- lapply(
  fits,
  function(x) {
    x$disp_index %>%
      select(all_of(disp_key_cols)) %>%
      as.data.frame()
  }
)

same_disp_index <- all(vapply(
  disp_keys[-1],
  function(x) isTRUE(all.equal(x, disp_keys[[1]], check.attributes = FALSE)),
  logical(1)
))

if (!same_disp_index) {
  cat("\nActive movement-state index genuinely differs among chains.\n")
  for (ch in 2:length(disp_keys)) {
    cat("\nChain 1 versus chain ", ch, ":\n", sep = "")
    print(all.equal(
      disp_keys[[1]],
      disp_keys[[ch]],
      check.attributes = FALSE
    ))
  }
  stop("Chains do not have the same biological active movement-state index.")
}

sample_mats <- lapply(fits, function(x) as.matrix(x$samples))

same_cols <- all(vapply(
  sample_mats[-1],
  function(x) identical(colnames(x), colnames(sample_mats[[1]])),
  logical(1)
))
if (!same_cols) stop("Monitored sample columns differ among chains.")

draw_counts <- vapply(sample_mats, nrow, integer(1))
if (length(unique(draw_counts)) != 1L) {
  stop("Chains have different numbers of retained posterior draws.")
}

nonfinite <- vapply(
  sample_mats,
  function(x) sum(!is.finite(x)),
  integer(1)
)
if (any(nonfinite > 0L)) {
  stop(
    "Non-finite posterior draws found: ",
    paste0("chain", CHAIN_IDS, "=", nonfinite, collapse = ", ")
  )
}

cat("Validation: PASS\n")
cat("Badgers:", length(fits[[1]]$ids), "\n")
cat("Retained draws per chain:", draw_counts[1], "\n")
cat("Total retained draws:", sum(draw_counts), "\n")

# -----------------------------------------------------------------------------
# Identify global and active movement-state columns
# -----------------------------------------------------------------------------
all_cols <- colnames(sample_mats[[1]])
state_cols <- grep("^disp_active\\[", all_cols, value = TRUE)
global_cols <- setdiff(all_cols, state_cols)

cat("Global monitored columns:", length(global_cols), "\n")
cat("Active movement-state columns:", length(state_cols), "\n")

if (length(state_cols) != nrow(fits[[1]]$disp_index)) {
  stop(
    "Movement-state column count (", length(state_cols),
    ") does not match disp_index rows (", nrow(fits[[1]]$disp_index), ")."
  )
}

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
summarise_vector <- function(z) {
  c(
    mean = mean(z),
    sd = sd(z),
    q025 = unname(quantile(z, 0.025)),
    median = unname(quantile(z, 0.5)),
    q975 = unname(quantile(z, 0.975))
  )
}

split_rhat <- function(chain_values) {
  # Standard split-chain Gelman-Rubin Rhat.
  # chain_values: matrix draws x chains.
  n <- nrow(chain_values)
  m <- ncol(chain_values)

  if (n < 4L || m < 2L) return(NA_real_)

  half <- floor(n / 2L)
  if (half < 2L) return(NA_real_)

  split_chains <- cbind(
    chain_values[seq_len(half), , drop = FALSE],
    chain_values[(n - half + 1L):n, , drop = FALSE]
  )

  n2 <- nrow(split_chains)
  m2 <- ncol(split_chains)

  chain_means <- colMeans(split_chains)
  chain_vars <- apply(split_chains, 2, var)

  W <- mean(chain_vars)
  B <- n2 * var(chain_means)

  if (!is.finite(W) || W <= 0) {
    if (isTRUE(all.equal(B, 0))) return(1)
    return(NA_real_)
  }

  var_plus <- ((n2 - 1) / n2) * W + B / n2
  sqrt(var_plus / W)
}

# -----------------------------------------------------------------------------
# Keep chains separate for diagnostics; pool only for posterior summaries
# -----------------------------------------------------------------------------
mcmc_list <- mcmc.list(
  lapply(sample_mats, mcmc)
)

pooled_samples <- do.call(rbind, sample_mats)

# -----------------------------------------------------------------------------
# Global posterior summary
# -----------------------------------------------------------------------------
global_summary <- bind_rows(
  lapply(
    global_cols,
    function(p) {
      ss <- summarise_vector(pooled_samples[, p])
      tibble(
        parameter = p,
        mean = ss["mean"],
        sd = ss["sd"],
        q025 = ss["q025"],
        median = ss["median"],
        q975 = ss["q975"]
      )
    }
  )
)

# -----------------------------------------------------------------------------
# Per-chain summaries
# -----------------------------------------------------------------------------
chain_summary <- bind_rows(
  lapply(
    seq_along(sample_mats),
    function(ch) {
      bind_rows(
        lapply(
          global_cols,
          function(p) {
            ss <- summarise_vector(sample_mats[[ch]][, p])
            tibble(
              chain = ch,
              parameter = p,
              mean = ss["mean"],
              sd = ss["sd"],
              q025 = ss["q025"],
              median = ss["median"],
              q975 = ss["q975"]
            )
          }
        )
      )
    }
  )
)

# -----------------------------------------------------------------------------
# Convergence diagnostics for global parameters
# -----------------------------------------------------------------------------
rhat_vals <- vapply(
  global_cols,
  function(p) {
    z <- sapply(
      sample_mats,
      function(mm) mm[, p]
    )
    split_rhat(z)
  },
  numeric(1)
)

# coda effectiveSize on mcmc.list gives the effective sample size across chains.
ess_vals <- effectiveSize(
  mcmc.list(
    lapply(
      sample_mats,
      function(mm) mcmc(mm[, global_cols, drop = FALSE])
    )
  )
)

convergence <- tibble(
  parameter = global_cols,
  rhat = as.numeric(rhat_vals[global_cols]),
  ess = as.numeric(ess_vals[global_cols])
) %>%
  arrange(desc(rhat))

# -----------------------------------------------------------------------------
# Active annual movement-state posterior probabilities
# -----------------------------------------------------------------------------
disp_index <- fits[[1]]$disp_index

# Explicitly map columns because lexical ordering would place [10] before [2].
expected_state_cols <- disp_index$sample_column
state_match <- match(expected_state_cols, state_cols)

if (anyNA(state_match)) {
  stop("Could not map all disp_index rows to sampled disp_active columns.")
}

ordered_state_cols <- state_cols[state_match]

disp_by_chain <- sapply(
  sample_mats,
  function(mm) {
    colMeans(mm[, ordered_state_cols, drop = FALSE])
  }
)

colnames(disp_by_chain) <- paste0("p_high_chain", CHAIN_IDS)

disp_probabilities <- bind_cols(
  disp_index,
  as_tibble(disp_by_chain)
) %>%
  mutate(
    p_high = rowMeans(disp_by_chain),
    max_chain_difference = apply(
      disp_by_chain,
      1,
      function(z) max(z) - min(z)
    )
  )

pooled_state_probs <- colMeans(
  pooled_samples[, ordered_state_cols, drop = FALSE]
)

disp_probabilities$p_high_pooled <- pooled_state_probs

disp_summary <- tibble(
  n_intervals = nrow(disp_probabilities),
  mean_p_high = mean(disp_probabilities$p_high_pooled),
  median_p_high = median(disp_probabilities$p_high_pooled),
  n_gt_050 = sum(disp_probabilities$p_high_pooled > 0.50),
  n_gt_080 = sum(disp_probabilities$p_high_pooled > 0.80),
  n_gt_095 = sum(disp_probabilities$p_high_pooled > 0.95),
  median_chain_difference = median(disp_probabilities$max_chain_difference),
  p95_chain_difference = unname(
    quantile(disp_probabilities$max_chain_difference, 0.95)
  ),
  max_chain_difference = max(disp_probabilities$max_chain_difference)
)

# -----------------------------------------------------------------------------
# Posterior correlations among key spatial scales
# -----------------------------------------------------------------------------
scale_parameters <- intersect(
  c(
    "sigma_female",
    "sigma_male",
    "omega",
    "mean_annual_move_female_local",
    "mean_annual_move_male_local",
    "mean_annual_move_female_high",
    "mean_annual_move_male_high"
  ),
  global_cols
)

scale_pairs <- combn(scale_parameters, 2, simplify = FALSE)

scale_correlations <- bind_rows(
  lapply(
    scale_pairs,
    function(pp) {
      per_chain <- vapply(
        sample_mats,
        function(mm) cor(mm[, pp[1]], mm[, pp[2]]),
        numeric(1)
      )

      tibble(
        parameter_1 = pp[1],
        parameter_2 = pp[2],
        cor_chain1 = per_chain[1],
        cor_chain2 = per_chain[2],
        cor_chain3 = per_chain[3],
        cor_pooled = cor(
          pooled_samples[, pp[1]],
          pooled_samples[, pp[2]]
        )
      )
    }
  )
)

# -----------------------------------------------------------------------------
# Console report: focus on the parameters we care about first
# -----------------------------------------------------------------------------
key_parameters <- intersect(
  c(
    "sigma_female",
    "sigma_male",
    "omega",
    "mean_quarter_offset_from_annual",
    "mean_between_quarter_centres",
    "mean_annual_move_female_local",
    "mean_annual_move_male_local",
    "mean_annual_move_female_high",
    "mean_annual_move_male_high",
    "alpha_disp_init",
    "beta_disp_adult",
    "beta_disp_init_sex",
    "alpha_RD",
    "beta_RD_sex",
    "alpha_DD",
    "beta_DD_sex"
  ),
  global_cols
)

key_report <- global_summary %>%
  filter(parameter %in% key_parameters) %>%
  left_join(convergence, by = "parameter") %>%
  arrange(match(parameter, key_parameters))

cat("\n============================================================\n")
cat("KEY THREE-CHAIN POSTERIOR SUMMARY\n")
cat("============================================================\n")
print(key_report, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("WORST GLOBAL RHAT VALUES\n")
cat("============================================================\n")
print(
  convergence %>%
    arrange(desc(rhat)) %>%
    slice_head(n = 15),
  n = Inf,
  width = Inf
)

cat("\n============================================================\n")
cat("ANNUAL HIGH-MOBILITY STATE SUMMARY\n")
cat("============================================================\n")
print(disp_summary, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("KEY SIGMA / OMEGA CORRELATIONS\n")
cat("============================================================\n")
print(
  scale_correlations %>%
    filter(
      parameter_1 %in% c("sigma_female", "sigma_male", "omega") &
        parameter_2 %in% c(
          "sigma_female",
          "sigma_male",
          "omega",
          "mean_annual_move_female_local",
          "mean_annual_move_male_local"
        )
    ),
  n = Inf,
  width = Inf
)

# -----------------------------------------------------------------------------
# Save outputs
# -----------------------------------------------------------------------------
combined_file <- paste0(prefix, "_COMBINED.rds")

saveRDS(
  list(
    model = "V10A_RD_SCR_MULTILOC",
    population_size = MAX_BADGERS,
    chain_files = chain_files,
    chain_ids = CHAIN_IDS,
    draws_per_chain = draw_counts,
    ids = fits[[1]]$ids,
    individual_ids = fits[[1]]$individual_ids,
    years = fits[[1]]$years,
    first = fits[[1]]$first,
    K = fits[[1]]$K,
    disp_index = disp_index,
    mcmc_list = mcmc_list,
    pooled_samples = pooled_samples,
    global_summary = global_summary,
    chain_summary = chain_summary,
    convergence = convergence,
    disp_probabilities = disp_probabilities,
    disp_summary = disp_summary,
    scale_correlations = scale_correlations
  ),
  combined_file
)

write_csv(
  global_summary,
  paste0(prefix, "_global_summary.csv")
)

write_csv(
  convergence,
  paste0(prefix, "_convergence.csv")
)

write_csv(
  chain_summary,
  paste0(prefix, "_chain_summary.csv")
)

write_csv(
  disp_probabilities,
  paste0(prefix, "_disp_probabilities.csv")
)

write_csv(
  disp_summary,
  paste0(prefix, "_disp_summary.csv")
)

write_csv(
  scale_correlations,
  paste0(prefix, "_scale_correlations.csv")
)

cat("\nSaved combined object:\n", combined_file, "\n", sep = "")
cat("\nSaved diagnostic CSV files with prefix:\n", prefix, "_*\n", sep = "")
cat("\nCOMBINE COMPLETE\n")
