# =============================================================================
# WOODCHESTER V11 - ANNUAL MOVEMENT SCALE / CHAIN-MODE DIAGNOSTIC
#
# PURPOSE
#   Diagnose whether the remaining V11 annual movement-scale disagreement is:
#     (a) slow within-chain drift toward a common posterior region, or
#     (b) stable occupation of distinct chain-specific trajectory/scale modes.
#
#   This script changes NO model biology and performs NO refitting.
#
# ENVIRONMENT
#   FILE_STEM   default V11_RD_MULTILOC_IID_AGE_BADGERRE
#   MAX_BADGERS default 300
#
# OUTPUT
#   results/<stem>_<N>_movement_scale_chain_diagnostic.csv
#   results/<stem>_<N>_movement_scale_half_diagnostic.csv
#   results/<stem>_<N>_state_disagreement_by_chain_mode.csv
# =============================================================================

library(tidyverse)
library(coda)

FILE_STEM <- Sys.getenv(
  "FILE_STEM",
  unset = "V11_RD_MULTILOC_IID_AGE_BADGERRE"
)
MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "300"))
CHAIN_IDS <- 1:3

prefix <- file.path(
  "results",
  paste0(FILE_STEM, "_", MAX_BADGERS)
)

chain_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, ".rds")
state_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, "_STATES.rds")

missing <- c(chain_files, state_files)[
  !file.exists(c(chain_files, state_files))
]
if (length(missing)) {
  stop("Missing V11 chain/state file(s):\n", paste(missing, collapse = "\n"))
}

fits <- lapply(chain_files, readRDS)
states <- lapply(state_files, readRDS)

accepted_models <- c(
  "V11_RD_SCR_MULTILOC_IID_AGE_BADGERRE_COLLAPSED_HMM",
  "V11_RD_SCR_ANNUALAC_MULTILOC_AGE_BADGERRE_COLLAPSED_HMM"
)

if (any(!vapply(fits, function(x) x$model %in% accepted_models, logical(1)))) {
  stop("At least one input is not a supported V11/V11S fit.")
}

mats <- lapply(fits, function(x) as.matrix(x$samples))

common_cols <- Reduce(intersect, lapply(mats, colnames))

pars <- c(
  "alpha_logmove",
  "alpha_logmove_high",
  "beta_move_high",
  "beta_move_sex",
  "mean_annual_move_female_local",
  "mean_annual_move_male_local",
  "mean_annual_move_female_high",
  "mean_annual_move_male_high",
  "omega",
  "sigma_female",
  "sigma_male",
  "sigma_badger",
  "alpha_disp_init",
  "beta_disp_init_sex",
  "alpha_RD",
  "beta_RD_sex",
  "alpha_DD",
  "beta_DD_sex",
  "beta_age_2",
  "beta_age_3_5",
  "beta_age_6plus",
  "beta_age_unknown"
)

pars <- intersect(pars, common_cols)

summarise_vec <- function(x) {
  tibble(
    mean = mean(x),
    sd = sd(x),
    q025 = unname(quantile(x, 0.025)),
    median = median(x),
    q975 = unname(quantile(x, 0.975)),
    first = x[1],
    last = x[length(x)]
  )
}

chain_summary <- bind_rows(
  lapply(
    seq_along(mats),
    function(cc) {
      bind_rows(
        lapply(
          pars,
          function(p) {
            summarise_vec(mats[[cc]][, p]) %>%
              mutate(chain = cc, parameter = p, .before = 1)
          }
        )
      )
    }
  )
)

half_summary <- bind_rows(
  lapply(
    seq_along(mats),
    function(cc) {
      mm <- mats[[cc]]
      nd <- nrow(mm)
      h <- floor(nd / 2)

      bind_rows(
        lapply(
          pars,
          function(p) {
            x1 <- mm[seq_len(h), p]
            x2 <- mm[(h + 1L):nd, p]

            tibble(
              chain = cc,
              parameter = p,
              first_half_mean = mean(x1),
              second_half_mean = mean(x2),
              first_half_median = median(x1),
              second_half_median = median(x2),
              mean_shift = mean(x2) - mean(x1),
              pooled_sd = sd(mm[, p]),
              standardized_shift =
                ifelse(sd(mm[, p]) > 0, (mean(x2) - mean(x1)) / sd(mm[, p]), NA_real_)
            )
          }
        )
      )
    }
  )
)

# Approximate effective sample size and within-chain lag-1 autocorrelation.
mixing_summary <- bind_rows(
  lapply(
    seq_along(mats),
    function(cc) {
      mm <- mats[[cc]]

      bind_rows(
        lapply(
          pars,
          function(p) {
            x <- mm[, p]
            tibble(
              chain = cc,
              parameter = p,
              ess_within_chain = as.numeric(effectiveSize(mcmc(x))),
              acf1 = if (length(x) > 2L) cor(x[-length(x)], x[-1]) else NA_real_
            )
          }
        )
      )
    }
  )
)

chain_summary <- chain_summary %>%
  left_join(mixing_summary, by = c("chain", "parameter"))

# Chain-separation statistic: range of chain medians relative to pooled SD.
chain_separation <- chain_summary %>%
  group_by(parameter) %>%
  summarise(
    min_chain_median = min(median),
    max_chain_median = max(median),
    median_range = max(median) - min(median),
    .groups = "drop"
  ) %>%
  left_join(
    tibble(
      parameter = pars,
      pooled_sd = vapply(
        pars,
        function(p) sd(unlist(lapply(mats, function(mm) mm[, p]))),
        numeric(1)
      )
    ),
    by = "parameter"
  ) %>%
  mutate(
    median_range_over_pooled_sd =
      median_range / pooled_sd
  )

# Pairwise within-chain correlations for the annual-scale ridge.
ridge_pars <- intersect(
  c(
    "alpha_logmove",
    "alpha_logmove_high",
    "beta_move_high",
    "beta_move_sex",
    "mean_annual_move_female_local",
    "mean_annual_move_male_local",
    "mean_annual_move_female_high",
    "mean_annual_move_male_high"
  ),
  common_cols
)

ridge_corr <- bind_rows(
  lapply(
    seq_along(mats),
    function(cc) {
      cm <- cor(mats[[cc]][, ridge_pars, drop = FALSE])
      idx <- which(upper.tri(cm), arr.ind = TRUE)
      tibble(
        chain = cc,
        parameter_1 = rownames(cm)[idx[, 1]],
        parameter_2 = colnames(cm)[idx[, 2]],
        correlation = cm[idx]
      )
    }
  )
)


# Broader annual state-process geometry: identify tradeoffs between movement
# scales, transition probabilities and persistent individual mover propensity.
state_process_pars <- intersect(
  c(
    "alpha_logmove",
    "alpha_logmove_high",
    "beta_move_high",
    "mean_annual_move_female_local",
    "mean_annual_move_female_high",
    "sigma_badger",
    "alpha_disp_init",
    "beta_disp_init_sex",
    "alpha_RD",
    "beta_RD_sex",
    "alpha_DD",
    "beta_DD_sex",
    "beta_age_2",
    "beta_age_3_5",
    "beta_age_6plus",
    "beta_age_unknown"
  ),
  common_cols
)

state_process_corr <- bind_rows(
  lapply(
    seq_along(mats),
    function(cc) {
      cm <- cor(mats[[cc]][, state_process_pars, drop = FALSE])
      idx <- which(upper.tri(cm), arr.ind = TRUE)

      tibble(
        chain = cc,
        parameter_1 = rownames(cm)[idx[, 1]],
        parameter_2 = colnames(cm)[idx[, 2]],
        correlation = cm[idx]
      ) %>%
        filter(
          parameter_1 == "sigma_badger" |
          parameter_2 == "sigma_badger" |
          parameter_1 %in% c("alpha_RD", "alpha_disp_init") |
          parameter_2 %in% c("alpha_RD", "alpha_disp_init")
        )
    }
  )
)

# State disagreement and whether it is concentrated in the same animals.
state_means <- lapply(
  states,
  function(x) colMeans(x$state_draws)
)

state_cols <- Reduce(intersect, lapply(states, function(x) colnames(x$state_draws)))
if (!length(state_cols)) stop("No common recovered movement-state columns.")

state_means <- lapply(
  seq_along(states),
  function(cc) {
    z <- states[[cc]]$state_draws[, state_cols, drop = FALSE]
    colMeans(z)
  }
)

state_mat <- do.call(cbind, state_means)
colnames(state_mat) <- paste0("chain", CHAIN_IDS)

state_range <- apply(state_mat, 1, function(z) max(z) - min(z))

disp_index <- fits[[1]]$disp_index
m <- match(state_cols, disp_index$recovered_state_column)
if (anyNA(m)) stop("Could not align recovered state columns to disp_index.")

state_diag <- disp_index[m, ] %>%
  mutate(
    p_high_chain1 = state_mat[, 1],
    p_high_chain2 = state_mat[, 2],
    p_high_chain3 = state_mat[, 3],
    max_chain_difference = state_range
  ) %>%
  arrange(desc(max_chain_difference))

animal_disagreement <- state_diag %>%
  group_by(model_i, tattoo) %>%
  summarise(
    n_intervals = n(),
    n_gt_025 = sum(max_chain_difference > 0.25),
    n_gt_050 = sum(max_chain_difference > 0.50),
    mean_difference = mean(max_chain_difference),
    max_difference = max(max_chain_difference),
    .groups = "drop"
  ) %>%
  arrange(desc(n_gt_050), desc(max_difference))

cat("\n============================================================\n")
cat("V11 ANNUAL MOVEMENT SCALE / CHAIN-MODE DIAGNOSTIC\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("Draws per chain:", paste(vapply(mats, nrow, integer(1)), collapse = ", "), "\n\n")

cat("CHAIN MEDIANS FOR KEY ANNUAL-SCALE PARAMETERS\n")
print(
  chain_summary %>%
    filter(parameter %in% ridge_pars) %>%
    select(chain, parameter, median, q025, q975, ess_within_chain, acf1),
  n = Inf,
  width = Inf
)

cat("\nCHAIN SEPARATION\n")
print(
  chain_separation %>%
    filter(parameter %in% ridge_pars) %>%
    arrange(desc(median_range_over_pooled_sd)),
  n = Inf,
  width = Inf
)

cat("\nFIRST-HALF VS SECOND-HALF DRIFT\n")
print(
  half_summary %>%
    filter(parameter %in% ridge_pars) %>%
    arrange(desc(abs(standardized_shift))),
  n = Inf,
  width = Inf
)

cat("\nSTRONGEST WITHIN-CHAIN RIDGE CORRELATIONS\n")
print(
  ridge_corr %>%
    arrange(desc(abs(correlation))) %>%
    slice_head(n = 30),
  n = 30,
  width = Inf
)

cat("\nSTATE-PROCESS / PERSISTENT-MOVER GEOMETRY\n")
print(
  state_process_corr %>%
    arrange(desc(abs(correlation))) %>%
    slice_head(n = 40),
  n = 40,
  width = Inf
)

cat("\nSTATE-PROCESS CHAIN SEPARATION / DRIFT\n")
print(
  chain_separation %>%
    filter(parameter %in% state_process_pars) %>%
    arrange(desc(median_range_over_pooled_sd)),
  n = Inf,
  width = Inf
)
print(
  half_summary %>%
    filter(parameter %in% state_process_pars) %>%
    arrange(desc(abs(standardized_shift))) %>%
    slice_head(n = 40),
  n = 40,
  width = Inf
)

cat("\nSTATE DISAGREEMENT SUMMARY\n")
print(
  tibble(
    n_intervals = length(state_range),
    n_gt_025 = sum(state_range > 0.25),
    n_gt_050 = sum(state_range > 0.50),
    n_gt_080 = sum(state_range > 0.80),
    median = median(state_range),
    p95 = unname(quantile(state_range, 0.95)),
    max = max(state_range)
  ),
  width = Inf
)

cat("\nANIMALS CONTRIBUTING MOST TO STATE DISAGREEMENT\n")
print(slice_head(animal_disagreement, n = 30), n = 30, width = Inf)

write_csv(
  chain_summary,
  paste0(prefix, "_movement_scale_chain_diagnostic.csv")
)
write_csv(
  half_summary,
  paste0(prefix, "_movement_scale_half_diagnostic.csv")
)
write_csv(
  chain_separation,
  paste0(prefix, "_movement_scale_chain_separation.csv")
)
write_csv(
  ridge_corr,
  paste0(prefix, "_movement_scale_ridge_correlations.csv")
)
write_csv(
  state_process_corr,
  paste0(prefix, "_state_process_correlations.csv")
)
write_csv(
  state_diag,
  paste0(prefix, "_state_disagreement_by_chain_mode.csv")
)
write_csv(
  animal_disagreement,
  paste0(prefix, "_state_disagreement_by_animal.csv")
)

cat("\nInterpretation guide:\n")
cat(
  "- Large chain separation with little first/second-half drift suggests stable ",
  "distinct modes rather than simply too-short chains.\n"
)
cat(
  "- Large within-chain half shifts in the direction of other chains suggests ",
  "longer continuation may be enough.\n"
)
cat(
  "- Strong alpha_logmove/beta_move_high correlations identify the remaining ",
  "annual local/high scale ridge.\n"
)
cat(
  "- sigma_badger correlations with transition and movement-scale parameters ",
  "identify tradeoffs between persistent mover propensity and state assignment.\n"
)
cat(
  "- State disagreement concentrated in a few animals/intervals suggests a ",
  "localized ambiguity rather than wholesale failure of the two-state model.\n"
)
