# =============================================================================
# Woodchester V10B: combine and diagnose independent MCMC chains
#
# Reads:
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN1.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN2.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN3.rds
#
# Environment:
#   FILE_STEM     result filename stem; default "V10B_RD_MULTILOC_AR1_COLLAPSED"
#   MAX_BADGERS   fitted population size in filenames (default 100)
#
# Writes:
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_COMBINED.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_global_summary.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_convergence.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_chain_summary.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_disp_probabilities.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_disp_summary.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_scale_correlations.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_annual_location_summary.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_quarter_location_summary.csv
#
# Notes:
#   - Chains remain separate in mcmc_list for convergence diagnostics.
#   - Movement-state probabilities come from exact forward-backward smoothing
#     sidecars; FFBS binary draws are retained in those sidecars for downstream
#     modular analyses.
#   - full-population combination does not duplicate all latent draws into one
#     pooled matrix; full draws remain in the three chain files.
#   - Rhat below is the standard split-chain Gelman-Rubin statistic.
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

chain_files <- paste0(
  prefix,
  "_CHAIN",
  CHAIN_IDS,
  ".rds"
)

state_files <- paste0(
  prefix,
  "_CHAIN",
  CHAIN_IDS,
  "_STATES.rds"
)

missing_files <- c(chain_files, state_files)[
  !file.exists(c(chain_files, state_files))
]
if (length(missing_files)) {
  stop(
    "Missing chain file(s):\n",
    paste(missing_files, collapse = "\n")
  )
}

cat("\n============================================================\n")
cat("WOODCHESTER V10B COLLAPSED-HMM: COMBINE CHAINS\n")
cat("============================================================\n")
cat("Population size:", MAX_BADGERS, "\n")
cat("Reading MCMC chains:\n", paste(chain_files, collapse = "\n"), "\n")
cat("Reading recovered-state sidecars:\n", paste(state_files, collapse = "\n"), "\n\n")

fits <- lapply(chain_files, readRDS)
state_fits <- lapply(state_files, readRDS)

# -----------------------------------------------------------------------------
# Validate that these really are three fits of the same posterior
# -----------------------------------------------------------------------------
if (!all(vapply(fits, function(x) identical(x$model, "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM"), logical(1)))) {
  stop("At least one file is not a V10B collapsed-HMM fit.")
}

if (!all(vapply(state_fits, function(x) identical(x$model, "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM"), logical(1)))) {
  stop("At least one recovered-state sidecar is not a V10B collapsed-HMM state file.")
}

if (!identical(vapply(fits, function(x) x$chain_id, integer(1)), CHAIN_IDS)) {
  stop("Chain IDs do not match expected 1, 2, 3.")
}
if (!identical(vapply(state_fits, function(x) x$chain_id, integer(1)), CHAIN_IDS)) {
  stop("Recovered-state sidecar chain IDs do not match expected 1, 2, 3.")
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

annual_key_cols <- c(
  "annual_active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "year"
)

quarter_key_cols <- c(
  "quarter_active_index",
  "annual_active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "year",
  "quarter"
)

if (!all(vapply(
  fits,
  function(x) {
    !is.null(x$annual_state_index) &&
      all(annual_key_cols %in% names(x$annual_state_index))
  },
  logical(1)
))) {
  stop("At least one chain is missing the annual latent-location index.")
}

if (!all(vapply(
  fits,
  function(x) {
    !is.null(x$quarter_state_index) &&
      all(quarter_key_cols %in% names(x$quarter_state_index))
  },
  logical(1)
))) {
  stop("At least one chain is missing the quarterly latent-location index.")
}

annual_keys <- lapply(
  fits,
  function(x) {
    x$annual_state_index %>%
      select(all_of(annual_key_cols)) %>%
      as.data.frame()
  }
)

quarter_keys <- lapply(
  fits,
  function(x) {
    x$quarter_state_index %>%
      select(all_of(quarter_key_cols)) %>%
      as.data.frame()
  }
)

same_annual_index <- all(vapply(
  annual_keys[-1],
  function(x) isTRUE(all.equal(x, annual_keys[[1]], check.attributes = FALSE)),
  logical(1)
))
if (!same_annual_index) {
  stop("Chains do not have the same biological annual latent-location index.")
}

same_quarter_index <- all(vapply(
  quarter_keys[-1],
  function(x) isTRUE(all.equal(x, quarter_keys[[1]], check.attributes = FALSE)),
  logical(1)
))
if (!same_quarter_index) {
  stop("Chains do not have the same biological quarterly latent-location index.")
}

sample_mats <- lapply(fits, function(x) as.matrix(x$samples))

# Full-population latent draws are large. Once copied to plain matrices, drop
# the duplicated mcmc objects from the fit containers while retaining metadata.
for (ch in seq_along(fits)) {
  fits[[ch]]$samples <- NULL
}
invisible(gc())

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
# Identify global and compact latent-location columns.
# Movement states are absent from MCMC and come from forward-backward sidecars.
# -----------------------------------------------------------------------------
all_cols <- colnames(sample_mats[[1]])

state_cols <- grep("^disp_active\\[", all_cols, value = TRUE)
if (length(state_cols)) {
  stop("Collapsed-HMM chains unexpectedly contain explicit disp_active samples.")
}

annual_x_cols <- grep("^A_x_active\\[", all_cols, value = TRUE)
annual_y_cols <- grep("^A_y_active\\[", all_cols, value = TRUE)
quarter_x_cols <- grep("^Q_x_active\\[", all_cols, value = TRUE)
quarter_y_cols <- grep("^Q_y_active\\[", all_cols, value = TRUE)

latent_cols <- c(
  annual_x_cols,
  annual_y_cols,
  quarter_x_cols,
  quarter_y_cols
)

global_cols <- setdiff(
  all_cols,
  latent_cols
)

cat("Global monitored columns:", length(global_cols), "\n")
cat("Recovered movement-state intervals:", nrow(fits[[1]]$disp_index), "\n")
cat("Annual latent ACs:", length(annual_x_cols), "\n")
cat("Quarterly latent centres:", length(quarter_x_cols), "\n")

if (
  length(annual_x_cols) != nrow(fits[[1]]$annual_state_index) ||
  length(annual_y_cols) != nrow(fits[[1]]$annual_state_index)
) {
  stop("Annual latent-coordinate columns do not match annual_state_index.")
}

if (
  length(quarter_x_cols) != nrow(fits[[1]]$quarter_state_index) ||
  length(quarter_y_cols) != nrow(fits[[1]]$quarter_state_index)
) {
  stop("Quarterly latent-coordinate columns do not match quarter_state_index.")
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
# Keep chains separate for diagnostics. Avoid constructing a second giant
# pooled matrix for the full population: each chain file remains the
# authoritative store of full latent posterior draws.
# -----------------------------------------------------------------------------
global_mcmc_list <- mcmc.list(
  lapply(
    sample_mats,
    function(mm) mcmc(mm[, global_cols, drop = FALSE])
  )
)

pooled_vector <- function(p) {
  unlist(
    lapply(sample_mats, function(mm) mm[, p]),
    use.names = FALSE
  )
}

# Retain the convenient pooled matrix only for smaller validation fits.
pooled_samples <- if (MAX_BADGERS <= 300L) {
  do.call(rbind, sample_mats)
} else {
  NULL
}

# -----------------------------------------------------------------------------
# Global posterior summary
# -----------------------------------------------------------------------------
global_summary <- bind_rows(
  lapply(
    global_cols,
    function(p) {
      ss <- summarise_vector(pooled_vector(p))
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
ess_vals <- effectiveSize(global_mcmc_list)

convergence <- tibble(
  parameter = global_cols,
  rhat = as.numeric(rhat_vals[global_cols]),
  ess = as.numeric(ess_vals[global_cols])
) %>%
  arrange(desc(rhat))

# -----------------------------------------------------------------------------
# Annual movement-state posterior probabilities from exact smoothing
# -----------------------------------------------------------------------------
disp_index <- fits[[1]]$disp_index

state_key_cols <- c(
  "active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "from_year",
  "to_year"
)

for (ch in seq_along(state_fits)) {
  si <- state_fits[[ch]]$disp_index

  same_state_map <- isTRUE(
    all.equal(
      disp_index %>% select(all_of(state_key_cols)) %>% as.data.frame(),
      si %>% select(all_of(state_key_cols)) %>% as.data.frame(),
      check.attributes = FALSE
    )
  )

  if (!same_state_map) {
    stop("Recovered-state index differs from MCMC chain index in chain ", ch, ".")
  }

  if (length(state_fits[[ch]]$p_high_smoothed_chain) != nrow(disp_index)) {
    stop("Recovered smoothed-state vector has wrong length in chain ", ch, ".")
  }
}

disp_by_chain <- sapply(
  state_fits,
  function(x) x$p_high_smoothed_chain
)

colnames(disp_by_chain) <- paste0("p_high_chain", CHAIN_IDS)

ffbs_by_chain <- sapply(
  state_fits,
  function(x) x$p_high_ffbs_chain
)
colnames(ffbs_by_chain) <- paste0("p_high_ffbs_chain", CHAIN_IDS)

disp_probabilities <- bind_cols(
  disp_index,
  as_tibble(disp_by_chain),
  as_tibble(ffbs_by_chain)
) %>%
  mutate(
    p_high = rowMeans(disp_by_chain),
    p_high_pooled = p_high,
    p_high_ffbs_pooled = rowMeans(ffbs_by_chain),
    max_chain_difference = apply(
      disp_by_chain,
      1,
      function(z) max(z) - min(z)
    )
  )

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

discordant_disp <- disp_probabilities %>%
  filter(max_chain_difference > 0.25) %>%
  arrange(desc(max_chain_difference), desc(p_high_pooled))

# -----------------------------------------------------------------------------
# Posterior summaries for every active latent annual AC and quarterly centre
# -----------------------------------------------------------------------------
annual_state_index <- fits[[1]]$annual_state_index
quarter_state_index <- fits[[1]]$quarter_state_index

ordered_annual_x <- annual_state_index$sample_column_x
ordered_annual_y <- annual_state_index$sample_column_y
ordered_quarter_x <- quarter_state_index$sample_column_x
ordered_quarter_y <- quarter_state_index$sample_column_y

if (
  anyNA(match(ordered_annual_x, annual_x_cols)) ||
  anyNA(match(ordered_annual_y, annual_y_cols))
) {
  stop("Could not map annual latent-location columns to annual_state_index.")
}

if (
  anyNA(match(ordered_quarter_x, quarter_x_cols)) ||
  anyNA(match(ordered_quarter_y, quarter_y_cols))
) {
  stop("Could not map quarterly latent-location columns to quarter_state_index.")
}

summarise_coordinate_pair <- function(index_tbl, x_cols, y_cols) {
  bind_rows(
    lapply(
      seq_len(nrow(index_tbl)),
      function(ii) {
        sx <- summarise_vector(pooled_vector(x_cols[ii]))
        sy <- summarise_vector(pooled_vector(y_cols[ii]))

        bind_cols(
          index_tbl[ii, , drop = FALSE],
          tibble(
            x_mean = sx["mean"],
            x_sd = sx["sd"],
            x_q025 = sx["q025"],
            x_median = sx["median"],
            x_q975 = sx["q975"],
            y_mean = sy["mean"],
            y_sd = sy["sd"],
            y_q025 = sy["q025"],
            y_median = sy["median"],
            y_q975 = sy["q975"]
          )
        )
      }
    )
  )
}

annual_location_summary <- summarise_coordinate_pair(
  annual_state_index,
  ordered_annual_x,
  ordered_annual_y
)

quarter_location_summary <- summarise_coordinate_pair(
  quarter_state_index,
  ordered_quarter_x,
  ordered_quarter_y
)

# -----------------------------------------------------------------------------
# Posterior correlations among key spatial scales
# -----------------------------------------------------------------------------
scale_parameters <- intersect(
  c(
    "sigma_female",
    "sigma_male",
    "omega",
    "rho",
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
          pooled_vector(pp[1]),
          pooled_vector(pp[2])
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
    "rho",
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
cat("ANNUAL HIGH-MOBILITY STATE SUMMARY (FORWARD-BACKWARD SMOOTHED)\n")
cat("============================================================\n")
print(disp_summary, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("KEY SIGMA / OMEGA CORRELATIONS\n")
cat("============================================================\n")
print(
  scale_correlations %>%
    filter(
      parameter_1 %in% c("sigma_female", "sigma_male", "omega", "rho") &
        parameter_2 %in% c(
          "sigma_female",
          "sigma_male",
          "omega",
          "rho",
          "mean_annual_move_female_local",
          "mean_annual_move_male_local"
        )
    ),
  n = Inf,
  width = Inf
)

state_disagreement_summary <- tibble(
  n_intervals = nrow(disp_probabilities),
  n_gt_025 = sum(disp_probabilities$max_chain_difference > 0.25),
  n_gt_050 = sum(disp_probabilities$max_chain_difference > 0.50),
  n_gt_080 = sum(disp_probabilities$max_chain_difference > 0.80),
  n_gt_095 = sum(disp_probabilities$max_chain_difference > 0.95),
  n_eq_100 = sum(disp_probabilities$max_chain_difference >= 0.999999),
  prop_gt_025 = mean(disp_probabilities$max_chain_difference > 0.25),
  median_chain_difference = median(disp_probabilities$max_chain_difference),
  p95_chain_difference = unname(
    quantile(disp_probabilities$max_chain_difference, 0.95)
  ),
  max_chain_difference = max(disp_probabilities$max_chain_difference)
)

cat("\n============================================================\n")
cat("SMOOTHED MOVEMENT-STATE CHAIN DISAGREEMENT\n")
cat("============================================================\n")
print(state_disagreement_summary, n = Inf, width = Inf)

cat("\nWorst 30 movement intervals by chain disagreement:\n")
if (nrow(discordant_disp)) {
  print(
    discordant_disp %>% slice_head(n = 30),
    n = Inf,
    width = Inf
  )
} else {
  cat("NONE\n")
}

# -----------------------------------------------------------------------------
# Save outputs
# -----------------------------------------------------------------------------
combined_file <- paste0(prefix, "_COMBINED.rds")

saveRDS(
  list(
    model = "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM",
    population_size = MAX_BADGERS,
    chain_files = chain_files,
    state_files = state_files,
    chain_ids = CHAIN_IDS,
    draws_per_chain = draw_counts,
    ids = fits[[1]]$ids,
    individual_ids = fits[[1]]$individual_ids,
    years = fits[[1]]$years,
    first = fits[[1]]$first,
    K = fits[[1]]$K,
    disp_index = disp_index,
    annual_state_index = annual_state_index,
    quarter_state_index = quarter_state_index,
    pooled_samples = pooled_samples,
    global_summary = global_summary,
    chain_summary = chain_summary,
    convergence = convergence,
    disp_probabilities = disp_probabilities,
    disp_summary = disp_summary,
    state_disagreement_summary = state_disagreement_summary,
    discordant_disp = discordant_disp,
    scale_correlations = scale_correlations,
    annual_location_summary = annual_location_summary,
    quarter_location_summary = quarter_location_summary
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
  discordant_disp,
  paste0(prefix, "_disp_chain_disagreement_gt025.csv")
)

write_csv(
  state_disagreement_summary,
  paste0(prefix, "_state_disagreement_summary.csv")
)

write_csv(
  scale_correlations,
  paste0(prefix, "_scale_correlations.csv")
)

write_csv(
  annual_location_summary,
  paste0(prefix, "_annual_location_summary.csv")
)

write_csv(
  quarter_location_summary,
  paste0(prefix, "_quarter_location_summary.csv")
)

cat("\nSaved combined object:\n", combined_file, "\n", sep = "")
cat("\nSaved diagnostic CSV files with prefix:\n", prefix, "_*\n", sep = "")
cat("\nCOMBINE COMPLETE\n")
