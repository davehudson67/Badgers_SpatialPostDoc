# =============================================================================
# Woodchester V10B collapsed-HMM: observation support for trajectory discordance
#
# PURPOSE
#   Determine whether cross-chain annual-trajectory / high-mobility disagreement
#   is concentrated in annual transitions with weak positive-capture support.
#
# Reads:
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN1.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_trajectory_chain_diagnostic.csv
#
# Environment:
#   MAX_BADGERS   fitted population size (default 1932)
#   STATE_DIFF    p(high) chain-difference threshold (default 0.50)
#
# Writes:
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_trajectory_support_audit.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_trajectory_support_summary.csv
#
# Notes
#   A year with zero positive captures is not completely unobserved in V10B:
#   active quarterly campaigns contribute capture/non-capture information.
#   This audit therefore distinguishes positive-capture support from the number
#   of active study-wide quarterly campaigns.
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "1932"))
FILE_STEM <- Sys.getenv(
  "FILE_STEM",
  unset = "V10B_RD_MULTILOC_AR1_COLLAPSED"
)
STATE_DIFF <- as.numeric(Sys.getenv("STATE_DIFF", unset = "0.50"))

prefix <- file.path(
  "results",
  paste0(FILE_STEM, "_", MAX_BADGERS)
)

chain_file <- paste0(prefix, "_CHAIN1.rds")
diag_file <- paste0(prefix, "_trajectory_chain_diagnostic.csv")

missing <- c(chain_file, diag_file)[!file.exists(c(chain_file, diag_file))]
if (length(missing)) {
  stop("Missing required file(s):\n", paste(missing, collapse = "\n"))
}

fit <- readRDS(chain_file)
diag <- read_csv(diag_file, show_col_types = FALSE)

if (!identical(
  fit$model,
  "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM"
)) {
  stop("CHAIN1 file is not a V10B collapsed-HMM fit.")
}

required_diag <- c(
  "active_index",
  "model_i",
  "tattoo",
  "state_k",
  "from_year",
  "to_year",
  "max_p_high_difference",
  "max_disp_median_difference",
  "max_endpoint_chain_separation",
  "displacement_mode_signal",
  "endpoint_mode_signal",
  "trajectory_mode_signal"
)

if (!all(required_diag %in% names(diag))) {
  stop("Trajectory diagnostic CSV is missing required columns.")
}

ncap <- fit$ncap
campaign_active <- fit$campaign_active

if (is.null(ncap) || is.null(campaign_active)) {
  stop("CHAIN1 fit is missing ncap and/or campaign_active.")
}

if (length(dim(ncap)) != 3L) {
  stop("Expected ncap to be individual x quarter x year.")
}

year_support <- bind_rows(
  lapply(
    seq_along(fit$ids),
    function(i) {
      kk <- fit$first[i]:fit$K[i]

      bind_rows(
        lapply(
          kk,
          function(k) {
            caps <- as.numeric(ncap[i, , k])
            active <- as.numeric(campaign_active[, k])

            tibble(
              model_i = i,
              tattoo = fit$ids[i],
              state_k = k,
              year = fit$years[k],
              n_positive_captures = sum(caps),
              n_captured_quarters = sum(caps > 0),
              n_active_campaigns = sum(active > 0),
              n_active_noncapture_quarters =
                sum((active > 0) & (caps == 0))
            )
          }
        )
      )
    }
  )
)

from_support <- year_support %>%
  transmute(
    model_i,
    from_state_k = state_k,
    from_year_check = year,
    from_n_positive_captures = n_positive_captures,
    from_n_captured_quarters = n_captured_quarters,
    from_n_active_campaigns = n_active_campaigns,
    from_n_active_noncapture_quarters = n_active_noncapture_quarters
  )

to_support <- year_support %>%
  transmute(
    model_i,
    to_state_k = state_k,
    to_year_check = year,
    to_n_positive_captures = n_positive_captures,
    to_n_captured_quarters = n_captured_quarters,
    to_n_active_campaigns = n_active_campaigns,
    to_n_active_noncapture_quarters = n_active_noncapture_quarters
  )

audit <- diag %>%
  mutate(
    from_state_k = state_k - 1L,
    to_state_k = state_k
  ) %>%
  left_join(
    from_support,
    by = c("model_i", "from_state_k")
  ) %>%
  left_join(
    to_support,
    by = c("model_i", "to_state_k")
  )

if (
  any(audit$from_year != audit$from_year_check) ||
  any(audit$to_year != audit$to_year_check)
) {
  stop("Year/index mismatch while attaching capture support.")
}

audit <- audit %>%
  mutate(
    from_captured = from_n_positive_captures > 0,
    to_captured = to_n_positive_captures > 0,
    positive_capture_support = case_when(
      from_captured & to_captured ~ "both_years_captured",
      from_captured & !to_captured ~ "from_only_captured",
      !from_captured & to_captured ~ "to_only_captured",
      TRUE ~ "neither_year_captured"
    ),
    state_discordant = max_p_high_difference > STATE_DIFF,
    both_years_multi_quarter =
      from_n_captured_quarters >= 2 &
      to_n_captured_quarters >= 2,
    total_positive_captures =
      from_n_positive_captures +
      to_n_positive_captures,
    total_captured_quarters =
      from_n_captured_quarters +
      to_n_captured_quarters
  )

support_summary <- audit %>%
  group_by(positive_capture_support) %>%
  summarise(
    n_intervals = n(),
    n_state_discordant = sum(state_discordant),
    prop_state_discordant = mean(state_discordant),
    n_disp_mode_signal = sum(displacement_mode_signal),
    prop_disp_mode_signal = mean(displacement_mode_signal),
    median_state_difference = median(max_p_high_difference),
    p95_state_difference =
      unname(quantile(max_p_high_difference, 0.95)),
    median_disp_difference_m =
      median(max_disp_median_difference),
    p95_disp_difference_m =
      unname(quantile(max_disp_median_difference, 0.95)),
    .groups = "drop"
  )

discordant_support_summary <- audit %>%
  filter(state_discordant) %>%
  count(
    positive_capture_support,
    name = "n_state_discordant"
  ) %>%
  mutate(
    prop_of_state_discordant =
      n_state_discordant / sum(n_state_discordant)
  )

strong_support_summary <- audit %>%
  summarise(
    n_intervals = n(),
    n_state_discordant = sum(state_discordant),
    n_state_discordant_both_years_captured =
      sum(
        state_discordant &
        positive_capture_support == "both_years_captured"
      ),
    prop_discordant_both_years_captured =
      mean(
        positive_capture_support[state_discordant] ==
          "both_years_captured"
      ),
    n_state_discordant_both_years_multi_quarter =
      sum(
        state_discordant &
        both_years_multi_quarter
      ),
    prop_discordant_both_years_multi_quarter =
      mean(
        both_years_multi_quarter[state_discordant]
      )
  )

worst30 <- audit %>%
  arrange(
    desc(max_p_high_difference),
    desc(max_disp_median_difference)
  ) %>%
  slice_head(n = 30) %>%
  select(
    active_index,
    tattoo,
    from_year,
    to_year,
    positive_capture_support,
    from_n_positive_captures,
    from_n_captured_quarters,
    to_n_positive_captures,
    to_n_captured_quarters,
    from_n_active_campaigns,
    to_n_active_campaigns,
    max_p_high_difference,
    max_disp_median_difference,
    max_endpoint_chain_separation,
    displacement_mode_signal
  )

cat("\n============================================================\n")
cat("OBSERVATION-SUPPORT AUDIT\n")
cat("============================================================\n")
cat(
  "Important: zero positive captures does not mean no observation; ",
  "active noncapture campaigns still contribute to the likelihood.\n\n",
  sep = ""
)

cat("All intervals by positive-capture support:\n")
print(support_summary, n = Inf, width = Inf)

cat("\nComposition of state-discordant intervals:\n")
print(discordant_support_summary, n = Inf, width = Inf)

cat("\nStrong-support summary:\n")
print(strong_support_summary, n = Inf, width = Inf)

cat("\nWorst 30 discordant intervals with capture support:\n")
print(worst30, n = Inf, width = Inf)

out_audit <- paste0(prefix, "_trajectory_support_audit.csv")
out_summary <- paste0(prefix, "_trajectory_support_summary.csv")

write_csv(audit, out_audit)
write_csv(
  bind_rows(
    support_summary %>% mutate(summary_type = "all_by_support"),
    discordant_support_summary %>%
      mutate(summary_type = "discordant_composition")
  ),
  out_summary
)

cat("\nSaved:\n", out_audit, "\n", out_summary, "\n", sep = "")
cat("\nTRAJECTORY SUPPORT AUDIT COMPLETE\n")
