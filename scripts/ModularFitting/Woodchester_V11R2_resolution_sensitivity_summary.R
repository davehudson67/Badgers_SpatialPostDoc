# =============================================================================
# WOODCHESTER V11R2 - CROSS-RESOLUTION SENSITIVITY SUMMARY
#
# Compares the full 25 / 50 / 100 m fixed-resident V11R fits after each scale
# has three fitted chains and recovered-state objects.
#
# Environment:
#   MAX_BADGERS default 1932
#   SCALES      comma- or space-separated fixed resident means; default 25,50,100
#
# This is a robustness analysis, NOT resident-scale model selection.
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "1932"))
scale_text <- Sys.getenv("SCALES", unset = "25,50,100")
SCALES <- as.numeric(str_split(scale_text, "[,[:space:]]+")[[1]])
SCALES <- SCALES[is.finite(SCALES)]

if (length(SCALES) < 2L) {
  stop("Need at least two finite scales in SCALES.")
}

stem_for <- function(scale) {
  paste0(
    "V11R2_RES", format(scale, scientific = FALSE, trim = TRUE),
    "_RD_ANNUALAC_DECOUPLED_MULTILOC_AGE_BADGERRE"
  )
}

idcols <- c("model_i", "tattoo", "state_k", "from_year", "to_year")

key_parameters <- c(
  "mean_annual_move_female_local",
  "mean_annual_move_male_local",
  "mean_annual_move_female_high",
  "mean_annual_move_male_high",
  "alpha_logmove_high",
  "beta_highscale_sex",
  "alpha_disp_init",
  "beta_disp_init_sex",
  "alpha_RD",
  "beta_RD_sex",
  "beta_age_2",
  "beta_age_3_5",
  "beta_age_6plus",
  "beta_age_unknown",
  "sigma_badger",
  "alpha_DD",
  "beta_DD_sex",
  "sigma_female",
  "sigma_male"
)

fit_by_scale <- list()
state_by_scale <- list()
parameter_summary <- list()
state_pooled <- list()
state_chain_agreement <- list()

for (scale in SCALES) {
  stem <- stem_for(scale)
  prefix <- file.path("results", paste0(stem, "_", MAX_BADGERS))
  fit_files <- paste0(prefix, "_CHAIN", 1:3, ".rds")
  state_files <- paste0(prefix, "_CHAIN", 1:3, "_STATES.rds")

  missing <- c(
    fit_files[!file.exists(fit_files)],
    state_files[!file.exists(state_files)]
  )
  if (length(missing)) {
    stop(
      "Missing V11R2 file(s) for ", scale, " m:\n",
      paste(missing, collapse = "\n")
    )
  }

  fits <- lapply(fit_files, readRDS)
  states <- lapply(state_files, readRDS)

  resident_means <- vapply(
    fits,
    function(x) as.numeric(x$settings$resident_mean_m),
    numeric(1)
  )
  if (any(abs(resident_means - scale) > 1e-8)) {
    stop("Fit metadata does not match requested resident scale ", scale, " m.")
  }

  idx <- states[[1]]$disp_index
  for (cc in 2:3) {
    if (!identical(
      as.data.frame(states[[cc]]$disp_index[, idcols]),
      as.data.frame(idx[, idcols])
    )) {
      stop("State interval maps differ among chains at ", scale, " m.")
    }
  }

  mats <- lapply(fits, function(x) as.matrix(x$samples))
  common <- Reduce(intersect, lapply(mats, colnames))
  pars <- intersect(key_parameters, common)
  pooled <- do.call(rbind, lapply(mats, function(m) m[, pars, drop = FALSE]))

  parameter_summary[[as.character(scale)]] <- tibble(
    resident_mean_m = scale,
    parameter = pars,
    mean = vapply(pars, function(z) mean(pooled[, z]), numeric(1)),
    sd = vapply(pars, function(z) sd(pooled[, z]), numeric(1)),
    q025 = vapply(pars, function(z) unname(quantile(pooled[, z], .025)), numeric(1)),
    median = vapply(pars, function(z) median(pooled[, z]), numeric(1)),
    q975 = vapply(pars, function(z) unname(quantile(pooled[, z], .975)), numeric(1))
  )

  P <- do.call(
    cbind,
    lapply(states, function(s) as.numeric(s$p_high_smoothed_chain))
  )

  within_range <- apply(P, 1, function(z) max(z) - min(z))

  state_pooled[[as.character(scale)]] <- idx %>%
    select(all_of(idcols)) %>%
    mutate(
      resident_mean_m = scale,
      p_relocation = rowMeans(P),
      within_scale_chain_range = within_range
    )

  state_chain_agreement[[as.character(scale)]] <- tibble(
    resident_mean_m = scale,
    n_intervals = nrow(P),
    median_chain_range = median(within_range),
    p95_chain_range = unname(quantile(within_range, .95)),
    n_chain_range_gt_025 = sum(within_range > .25),
    prop_chain_range_gt_025 = mean(within_range > .25),
    n_chain_range_gt_050 = sum(within_range > .50),
    n_chain_range_gt_080 = sum(within_range > .80)
  )

  fit_by_scale[[as.character(scale)]] <- fits
  state_by_scale[[as.character(scale)]] <- states
}

parameter_summary <- bind_rows(parameter_summary)
state_chain_agreement <- bind_rows(state_chain_agreement)

state_occupancy <- bind_rows(state_pooled) %>%
  group_by(resident_mean_m) %>%
  summarise(
    n_intervals = n(),
    mean_p_relocation = mean(p_relocation),
    n_p_relocation_ge_050 = sum(p_relocation >= .50),
    prop_p_relocation_ge_050 = mean(p_relocation >= .50),
    n_p_relocation_ge_080 = sum(p_relocation >= .80),
    .groups = "drop"
  )

# Require exactly the same annual transition map across all sensitivity scales.
base_state <- state_pooled[[1]] %>%
  select(all_of(idcols))

for (ii in seq_along(state_pooled)[-1]) {
  if (!identical(
    as.data.frame(state_pooled[[ii]][, idcols]),
    as.data.frame(base_state)
  )) {
    stop("Annual transition maps differ across resident-scale sensitivities.")
  }
}

# Wide interval-level comparison.
state_wide <- base_state
for (scale in SCALES) {
  ss <- state_pooled[[as.character(scale)]]
  nm <- paste0("p_relocation_res", scale)
  state_wide[[nm]] <- ss$p_relocation
}

pcols <- paste0("p_relocation_res", SCALES)
Pscale <- as.matrix(state_wide[, pcols, drop = FALSE])

state_wide <- state_wide %>%
  mutate(
    sensitivity_range = apply(Pscale, 1, function(z) max(z) - min(z)),
    p_relocation_min = apply(Pscale, 1, min),
    p_relocation_max = apply(Pscale, 1, max),
    p_relocation_mean = rowMeans(Pscale),
    classification = case_when(
      p_relocation_min >= 0.5 ~ "robust_relocation",
      p_relocation_max < 0.5 ~ "robust_resident",
      TRUE ~ "sensitivity_dependent"
    )
  )

state_robustness <- state_wide %>%
  summarise(
    n_intervals = n(),
    n_robust_resident = sum(classification == "robust_resident"),
    n_robust_relocation = sum(classification == "robust_relocation"),
    n_sensitivity_dependent = sum(classification == "sensitivity_dependent"),
    prop_sensitivity_dependent = mean(classification == "sensitivity_dependent"),
    median_sensitivity_range = median(sensitivity_range),
    p95_sensitivity_range = unname(quantile(sensitivity_range, .95)),
    n_range_gt_010 = sum(sensitivity_range > .10),
    n_range_gt_025 = sum(sensitivity_range > .25),
    n_range_gt_050 = sum(sensitivity_range > .50),
    max_sensitivity_range = max(sensitivity_range)
  )

# Pairwise sensitivity comparisons.
pairs <- combn(SCALES, 2, simplify = FALSE)
pairwise_states <- map_dfr(
  pairs,
  function(pair) {
    a <- pair[1]
    b <- pair[2]
    pa <- state_wide[[paste0("p_relocation_res", a)]]
    pb <- state_wide[[paste0("p_relocation_res", b)]]

    class_a <- pa >= 0.5
    class_b <- pb >= 0.5

    tibble(
      resident_mean_a = a,
      resident_mean_b = b,
      correlation = cor(pa, pb),
      mean_abs_difference = mean(abs(pa - pb)),
      median_abs_difference = median(abs(pa - pb)),
      p95_abs_difference = unname(quantile(abs(pa - pb), .95)),
      n_abs_diff_gt_010 = sum(abs(pa - pb) > .10),
      n_abs_diff_gt_025 = sum(abs(pa - pb) > .25),
      n_classification_switch = sum(class_a != class_b),
      prop_classification_switch = mean(class_a != class_b)
    )
  }
)

# Parameter medians in a human-readable wide table.
parameter_medians_wide <- parameter_summary %>%
  select(resident_mean_m, parameter, median) %>%
  mutate(scale = paste0("res", resident_mean_m)) %>%
  select(-resident_mean_m) %>%
  pivot_wider(names_from = scale, values_from = median)

# Identify intervals most sensitive to the unresolved resident scale.
most_sensitive <- state_wide %>%
  arrange(desc(sensitivity_range)) %>%
  slice_head(n = 50)

# Animal-level concentration of sensitivity.
animal_sensitivity <- state_wide %>%
  group_by(tattoo) %>%
  summarise(
    n_intervals = n(),
    max_sensitivity_range = max(sensitivity_range),
    mean_sensitivity_range = mean(sensitivity_range),
    n_sensitivity_dependent = sum(classification == "sensitivity_dependent"),
    .groups = "drop"
  ) %>%
  arrange(
    desc(n_sensitivity_dependent),
    desc(max_sensitivity_range)
  )

# Output.
out_prefix <- file.path("results", paste0("V11R2_resolution_sensitivity_", MAX_BADGERS))

write_csv(
  parameter_summary,
  paste0(out_prefix, "_parameter_summary.csv")
)
write_csv(
  parameter_medians_wide,
  paste0(out_prefix, "_parameter_medians_wide.csv")
)
write_csv(
  state_chain_agreement,
  paste0(out_prefix, "_within_scale_state_agreement.csv")
)
write_csv(
  state_occupancy,
  paste0(out_prefix, "_state_occupancy_by_scale.csv")
)
write_csv(
  state_wide,
  paste0(out_prefix, "_interval_state_robustness.csv")
)
write_csv(
  state_robustness,
  paste0(out_prefix, "_state_robustness_scorecard.csv")
)
write_csv(
  pairwise_states,
  paste0(out_prefix, "_pairwise_state_comparison.csv")
)
write_csv(
  most_sensitive,
  paste0(out_prefix, "_most_sensitive_intervals.csv")
)
write_csv(
  animal_sensitivity,
  paste0(out_prefix, "_animal_sensitivity.csv")
)

cat("\n============================================================\n")
cat("V11R2 CROSS-RESOLUTION SENSITIVITY SUMMARY\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("Resident mean sensitivities:", paste(SCALES, collapse = ", "), "m\n\n")

cat("WITHIN-SCALE STATE AGREEMENT\n")
print(state_chain_agreement, n = Inf, width = Inf)

cat("\nSTATE OCCUPANCY BY RESIDENT SCALE\n")
print(state_occupancy, n = Inf, width = Inf)

cat("\nCROSS-SCALE STATE ROBUSTNESS\n")
print(state_robustness, width = Inf)

cat("\nPAIRWISE STATE COMPARISON\n")
print(pairwise_states, n = Inf, width = Inf)

cat("\nBIOLOGICAL / SCALE PARAMETER MEDIANS\n")
print(parameter_medians_wide, n = Inf, width = Inf)

cat("\nMOST RESOLUTION-SENSITIVE INTERVALS\n")
print(most_sensitive, n = 30, width = Inf)

cat("\nANIMALS CONTRIBUTING MOST RESOLUTION SENSITIVITY\n")
print(animal_sensitivity, n = 30, width = Inf)

cat("\nSaved V11R2 cross-resolution diagnostics in results/.\n")
