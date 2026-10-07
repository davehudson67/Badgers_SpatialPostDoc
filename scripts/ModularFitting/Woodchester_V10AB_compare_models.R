# =============================================================================
# Woodchester V10A versus V10B matched-model comparison
#
# Decision experiment:
#   V10A = independent quarterly deviations around annual AC
#   V10B = stationary AR(1) quarterly deviations around annual AC
#
# Everything else is intended to be matched: population subset, detection
# model, annual movement model, priors (apart from V10B rho), chain settings,
# and latent-location retention.
#
# Environment:
#   MAX_BADGERS   fitted population size in filenames (default 300)
#
# Reads the two COMBINED objects and writes compact side-by-side diagnostics.
# This script does NOT automatically declare a winner.
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "300"))

prefix_a <- file.path(
  "results",
  paste0("V10A_RD_MULTILOC_", MAX_BADGERS)
)

prefix_b <- file.path(
  "results",
  paste0("V10B_RD_MULTILOC_AR1_", MAX_BADGERS)
)

file_a <- paste0(prefix_a, "_COMBINED.rds")
file_b <- paste0(prefix_b, "_COMBINED.rds")

missing_files <- c(file_a, file_b)[!file.exists(c(file_a, file_b))]
if (length(missing_files)) {
  stop(
    "Missing combined model file(s):\n",
    paste(missing_files, collapse = "\n")
  )
}

a <- readRDS(file_a)
b <- readRDS(file_b)

if (!identical(a$ids, b$ids)) {
  stop("V10A and V10B do not contain the same badgers in the same order.")
}
if (!identical(a$years, b$years)) {
  stop("V10A and V10B do not use the same year vector.")
}

disp_key <- c(
  "active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "from_year",
  "to_year"
)

annual_key <- c(
  "annual_active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "year"
)

quarter_key <- c(
  "quarter_active_index",
  "annual_active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "year",
  "quarter"
)

same_keys <- function(x, y, cols) {
  isTRUE(
    all.equal(
      x %>% select(all_of(cols)) %>% as.data.frame(),
      y %>% select(all_of(cols)) %>% as.data.frame(),
      check.attributes = FALSE
    )
  )
}

if (!same_keys(a$disp_index, b$disp_index, disp_key)) {
  stop("Movement-state indices differ between V10A and V10B.")
}
if (!same_keys(a$annual_state_index, b$annual_state_index, annual_key)) {
  stop("Annual latent-location indices differ between V10A and V10B.")
}
if (!same_keys(a$quarter_state_index, b$quarter_state_index, quarter_key)) {
  stop("Quarterly latent-location indices differ between V10A and V10B.")
}

cat("\n============================================================\n")
cat("WOODCHESTER V10A vs V10B MATCHED COMPARISON\n")
cat("============================================================\n")
cat("Population size:", MAX_BADGERS, "\n")
cat("Badgers:", length(a$ids), "\n")
cat("Movement intervals:", nrow(a$disp_index), "\n")
cat("Annual latent ACs:", nrow(a$annual_state_index), "\n")
cat("Quarterly latent centres:", nrow(a$quarter_state_index), "\n")

# -----------------------------------------------------------------------------
# Global convergence
# -----------------------------------------------------------------------------
convergence_overview <- bind_rows(
  list(
    V10A = a$convergence,
    V10B = b$convergence
  ),
  .id = "model"
) %>%
  group_by(model) %>%
  summarise(
    n_global_parameters = n(),
    max_rhat = max(rhat, na.rm = TRUE),
    n_rhat_gt_1_05 = sum(rhat > 1.05, na.rm = TRUE),
    n_rhat_gt_1_10 = sum(rhat > 1.10, na.rm = TRUE),
    median_ess = median(ess, na.rm = TRUE),
    min_ess = min(ess, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n============================================================\n")
cat("GLOBAL CONVERGENCE OVERVIEW\n")
cat("============================================================\n")
print(convergence_overview, n = Inf, width = Inf)

# -----------------------------------------------------------------------------
# Matched key posterior parameters
# -----------------------------------------------------------------------------
key_parameters <- c(
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
)

parameter_table <- bind_rows(
  list(
    V10A = a$global_summary %>%
      left_join(a$convergence, by = "parameter"),
    V10B = b$global_summary %>%
      left_join(b$convergence, by = "parameter")
  ),
  .id = "model"
) %>%
  filter(parameter %in% key_parameters) %>%
  mutate(
    parameter = factor(parameter, levels = key_parameters)
  ) %>%
  arrange(parameter, model) %>%
  mutate(parameter = as.character(parameter))

cat("\n============================================================\n")
cat("KEY POSTERIOR PARAMETERS\n")
cat("============================================================\n")
print(parameter_table, n = Inf, width = Inf)

rho_summary <- parameter_table %>%
  filter(model == "V10B", parameter == "rho")

cat("\n============================================================\n")
cat("V10B QUARTERLY PERSISTENCE rho\n")
cat("============================================================\n")
print(rho_summary, n = Inf, width = Inf)

# -----------------------------------------------------------------------------
# Annual high-mobility state agreement between model formulations
# -----------------------------------------------------------------------------
state_comparison <- a$disp_probabilities %>%
  select(
    all_of(disp_key),
    p_high_A = p_high_pooled,
    chain_diff_A = max_chain_difference
  ) %>%
  left_join(
    b$disp_probabilities %>%
      select(
        all_of(disp_key),
        p_high_B = p_high_pooled,
        chain_diff_B = max_chain_difference
      ),
    by = disp_key
  ) %>%
  mutate(
    abs_p_high_difference = abs(p_high_B - p_high_A),
    class_A_050 = p_high_A > 0.50,
    class_B_050 = p_high_B > 0.50,
    class_A_080 = p_high_A > 0.80,
    class_B_080 = p_high_B > 0.80
  )

state_overview <- tibble(
  n_intervals = nrow(state_comparison),
  cor_p_high = cor(
    state_comparison$p_high_A,
    state_comparison$p_high_B
  ),
  mean_abs_p_high_difference = mean(
    state_comparison$abs_p_high_difference
  ),
  median_abs_p_high_difference = median(
    state_comparison$abs_p_high_difference
  ),
  p95_abs_p_high_difference = unname(
    quantile(state_comparison$abs_p_high_difference, 0.95)
  ),
  n_class_changed_050 = sum(
    state_comparison$class_A_050 != state_comparison$class_B_050
  ),
  n_class_changed_080 = sum(
    state_comparison$class_A_080 != state_comparison$class_B_080
  ),
  V10A_median_chain_difference = median(
    state_comparison$chain_diff_A
  ),
  V10B_median_chain_difference = median(
    state_comparison$chain_diff_B
  ),
  V10A_p95_chain_difference = unname(
    quantile(state_comparison$chain_diff_A, 0.95)
  ),
  V10B_p95_chain_difference = unname(
    quantile(state_comparison$chain_diff_B, 0.95)
  )
)

cat("\n============================================================\n")
cat("ANNUAL MOVEMENT-STATE ROBUSTNESS TO QUARTER MODEL\n")
cat("============================================================\n")
print(state_overview, n = Inf, width = Inf)

cat("\nLargest V10A/V10B state-probability differences:\n")
print(
  state_comparison %>%
    arrange(desc(abs_p_high_difference)) %>%
    slice_head(n = 20),
  n = Inf,
  width = Inf
)

# -----------------------------------------------------------------------------
# Posterior mean latent-location sensitivity
# -----------------------------------------------------------------------------
annual_location_comparison <- a$annual_location_summary %>%
  select(
    all_of(annual_key),
    x_mean_A = x_mean,
    y_mean_A = y_mean
  ) %>%
  left_join(
    b$annual_location_summary %>%
      select(
        all_of(annual_key),
        x_mean_B = x_mean,
        y_mean_B = y_mean
      ),
    by = annual_key
  ) %>%
  mutate(
    posterior_mean_AC_difference_m = sqrt(
      (x_mean_B - x_mean_A)^2 +
        (y_mean_B - y_mean_A)^2
    )
  )

quarter_location_comparison <- a$quarter_location_summary %>%
  select(
    all_of(quarter_key),
    x_mean_A = x_mean,
    y_mean_A = y_mean
  ) %>%
  left_join(
    b$quarter_location_summary %>%
      select(
        all_of(quarter_key),
        x_mean_B = x_mean,
        y_mean_B = y_mean
      ),
    by = quarter_key
  ) %>%
  mutate(
    posterior_mean_Q_difference_m = sqrt(
      (x_mean_B - x_mean_A)^2 +
        (y_mean_B - y_mean_A)^2
    )
  )

location_overview <- tibble(
  state_type = c("annual_AC", "quarter_centre"),
  median_difference_m = c(
    median(annual_location_comparison$posterior_mean_AC_difference_m),
    median(quarter_location_comparison$posterior_mean_Q_difference_m)
  ),
  p95_difference_m = c(
    unname(
      quantile(
        annual_location_comparison$posterior_mean_AC_difference_m,
        0.95
      )
    ),
    unname(
      quantile(
        quarter_location_comparison$posterior_mean_Q_difference_m,
        0.95
      )
    )
  ),
  max_difference_m = c(
    max(annual_location_comparison$posterior_mean_AC_difference_m),
    max(quarter_location_comparison$posterior_mean_Q_difference_m)
  )
)

cat("\n============================================================\n")
cat("LATENT LOCATION SENSITIVITY\n")
cat("============================================================\n")
print(location_overview, n = Inf, width = Inf)

# -----------------------------------------------------------------------------
# Pre-agreed decision framing
# -----------------------------------------------------------------------------
cat("\n============================================================\n")
cat("DECISION FRAME\n")
cat("============================================================\n")
cat(
  paste0(
    "Prefer V10A if V10B rho is weak/near zero and V10B does not materially ",
    "improve convergence or state stability.\n",
    "Prefer V10B if rho is meaningfully positive AND the sequential structure ",
    "improves or at least preserves convergence/state stability without ",
    "materially destabilising annual movement inference.\n",
    "After this 300-badger comparison, choose one architecture and take only ",
    "that model forward.\n"
  )
)

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------
out_prefix <- file.path(
  "results",
  paste0("V10AB_", MAX_BADGERS, "_comparison")
)

write_csv(
  convergence_overview,
  paste0(out_prefix, "_convergence.csv")
)

write_csv(
  parameter_table,
  paste0(out_prefix, "_parameters.csv")
)

write_csv(
  state_comparison,
  paste0(out_prefix, "_movement_states.csv")
)

write_csv(
  state_overview,
  paste0(out_prefix, "_movement_state_overview.csv")
)

write_csv(
  annual_location_comparison,
  paste0(out_prefix, "_annual_locations.csv")
)

write_csv(
  quarter_location_comparison,
  paste0(out_prefix, "_quarter_locations.csv")
)

write_csv(
  location_overview,
  paste0(out_prefix, "_location_overview.csv")
)

cat("\nSaved V10A/V10B comparison files with prefix:\n")
cat(out_prefix, "_*\n", sep = "")
cat("\nCOMPARISON COMPLETE\n")
