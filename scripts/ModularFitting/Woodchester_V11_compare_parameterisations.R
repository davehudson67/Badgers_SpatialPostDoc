# =============================================================================
# V11 centred parameterisation race: fair computational comparison
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "300"))

variants <- tribble(
  ~variant, ~stem,
  "centred_control", "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTEREDCHECK",
  "joint_high", "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_JOINT_HIGH",
  "joint_local", "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_JOINT_LOCAL",
  "mean_separation", "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_MEANSEP"
)

key_parameters <- c(
  "alpha_logmove",
  "alpha_logmove_high",
  "beta_move_high",
  "beta_move_sex",
  "mean_annual_move_female_local",
  "mean_annual_move_male_local",
  "mean_annual_move_female_high",
  "mean_annual_move_male_high",
  "omega",
  "sigma_badger",
  "beta_RD_sex",
  "beta_age_2",
  "beta_age_3_5",
  "beta_age_6plus",
  "beta_age_unknown"
)

objs <- lapply(seq_len(nrow(variants)), function(ii) {
  ff <- file.path(
    "results",
    paste0(variants$stem[ii], "_", MAX_BADGERS, "_COMBINED.rds")
  )
  if (!file.exists(ff)) stop("Missing combined file: ", ff)
  readRDS(ff)
})

conv <- bind_rows(lapply(seq_along(objs), function(ii) {
  objs[[ii]]$convergence %>%
    filter(parameter %in% key_parameters) %>%
    mutate(variant = variants$variant[ii], .before = 1)
}))

summ <- bind_rows(lapply(seq_along(objs), function(ii) {
  objs[[ii]]$global_summary %>%
    filter(parameter %in% key_parameters) %>%
    mutate(variant = variants$variant[ii], .before = 1)
}))

states <- bind_rows(lapply(seq_along(objs), function(ii) {
  z <- objs[[ii]]$state_disagreement_summary
  z %>% mutate(variant = variants$variant[ii], .before = 1)
}))

score <- conv %>%
  group_by(variant) %>%
  summarise(
    max_key_rhat = max(rhat, na.rm = TRUE),
    median_key_rhat = median(rhat, na.rm = TRUE),
    min_key_ess = min(ess, na.rm = TRUE),
    median_key_ess = median(ess, na.rm = TRUE),
    n_key_rhat_gt_1_05 = sum(rhat > 1.05, na.rm = TRUE),
    n_key_rhat_gt_1_10 = sum(rhat > 1.10, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(states, by = "variant") %>%
  arrange(max_key_rhat, desc(min_key_ess))

cat("\n============================================================\n")
cat("V11 CENTRED PARAMETERISATION RACE\n")
cat("============================================================\n")
cat("Selection criterion: computational performance only.\n")
cat("Biological effect size/significance is NOT a selection criterion.\n\n")

cat("OVERALL SCORECARD\n")
print(score, n = Inf, width = Inf)

cat("\nKEY PARAMETER CONVERGENCE\n")
print(
  conv %>% arrange(parameter, variant),
  n = Inf,
  width = Inf
)

cat("\nKEY POSTERIOR SUMMARIES\n")
print(
  summ %>%
    select(variant, parameter, mean, sd, q025, median, q975) %>%
    arrange(parameter, variant),
  n = Inf,
  width = Inf
)

median_spread <- summ %>%
  select(variant, parameter, median) %>%
  pivot_wider(names_from = variant, values_from = median) %>%
  rowwise() %>%
  mutate(
    min_median = min(c_across(where(is.numeric)), na.rm = TRUE),
    max_median = max(c_across(where(is.numeric)), na.rm = TRUE),
    median_range = max_median - min_median
  ) %>%
  ungroup() %>%
  arrange(desc(median_range))

cat("\nCROSS-PARAMETERISATION POSTERIOR MEDIAN SPREAD\n")
print(median_spread, n = Inf, width = Inf)

write_csv(
  score,
  file.path(
    "results",
    paste0("V11_parameterisation_race_", MAX_BADGERS, "_scorecard.csv")
  )
)
write_csv(
  conv,
  file.path(
    "results",
    paste0("V11_parameterisation_race_", MAX_BADGERS, "_convergence.csv")
  )
)
write_csv(
  summ,
  file.path(
    "results",
    paste0("V11_parameterisation_race_", MAX_BADGERS, "_posterior_summaries.csv")
  )
)
write_csv(
  median_spread,
  file.path(
    "results",
    paste0("V11_parameterisation_race_", MAX_BADGERS, "_median_spread.csv")
  )
)

cat("\nCOMPARISON COMPLETE\n")
