# =============================================================================
# WOODCHESTER - DESTINATION MATCH NULL TEST
#
# PURPOSE
# Test whether later settlement into a prospected group occurs more often than
# expected from the dispersal destinations that were locally/historically
# available to other badgers from the same source social group.
#
# WHY THIS TEST
# The focal sample is intentionally small and biologically strict:
#   closed prospecting in focal year y,
#   strict baseline residence in y-1,
#   strict future residence in y+1,
#   and actual resident-group change by y+1.
#
# Therefore do NOT fit a large multivariable regression.
# Instead use small-sample exact/randomisation logic.
#
# FOCAL EVENT
#   A (resident y-1) -> prospect B and return to A during y -> resident ? in y+1
#
# OBSERVED SUCCESS
#   future resident group is one of the CLOSED-prospected groups.
#
# NULL
# For each focal mover, use OTHER badgers that made the same two-year
# resident-group transition horizon:
#
#   strict resident A in t-1 -> strict different resident group in t+1
#
# from the same source group A and within a specified time window around the
# focal year. Their observed destinations form an empirical accessibility /
# dispersal-choice distribution. This automatically reflects source-group
# geography, neighbouring-group availability and historical connectivity better
# than an equal-probability null.
#
# We evaluate several temporal windows because the number of focal movers is
# small:
#   exact focal year, +/-2 years, +/-5 years, and pooled all years.
#
# The primary inferential summary is a Poisson-binomial tail probability for
# observing at least the actual number of destination matches given each
# focal event's empirical null match probability.
#
# To avoid overconfidence when a small reference set has 0 or 100% matches,
# Jeffreys smoothing is also reported:
#   p = (matches + 0.5) / (n_reference + 1)
#
# OUTPUTS
#   results/prospecting_destination_null_event_level.csv
#   results/prospecting_destination_null_summary.csv
#   results/prospecting_destination_null_reference_moves.csv
# =============================================================================

library(tidyverse)

pathway_file <- "results/prospecting_pathway_badger_years.csv"
resident_file <- "results/annual_resident_social_group_vicente.csv"

required <- c(pathway_file, resident_file)
missing <- required[!file.exists(required)]
if (length(missing)) {
  stop("Missing required file(s):\n", paste(missing, collapse = "\n"))
}

pathway <- read_csv(pathway_file, show_col_types = FALSE)
resident_raw <- read_csv(resident_file, show_col_types = FALSE)

clean_group <- function(x) {
  z <- x %>%
    as.character() %>%
    toupper() %>%
    str_squish()
  z[z %in% c("", "NA", "N/A", "UNKNOWN", "UNK", "NOT KNOWN")] <- NA_character_
  z[z %in% c("CHESTNUT", "HOLLOW TREE")] <- NA_character_
  z
}

split_groups <- function(x) {
  if (is.na(x) || x == "") character(0) else str_split(x, ";", simplify = FALSE)[[1]]
}

# Exact Poisson-binomial tail probability P(X >= k_obs)
poibin_tail <- function(probs, k_obs) {
  probs <- probs[is.finite(probs)]
  if (!length(probs)) return(NA_real_)
  pmf <- 1
  for (p in probs) {
    p <- min(max(p, 0), 1)
    new <- numeric(length(pmf) + 1L)
    new[seq_along(pmf)] <- new[seq_along(pmf)] + pmf * (1 - p)
    new[seq_along(pmf) + 1L] <- new[seq_along(pmf) + 1L] + pmf * p
    pmf <- new
  }
  if (k_obs <= 0L) return(1)
  if (k_obs > length(probs)) return(0)
  sum(pmf[(k_obs + 1L):length(pmf)])
}

# Clopper-Pearson interval for observed match proportion.
cp_interval <- function(k, n, conf = 0.95) {
  alpha <- 1 - conf
  lower <- if (k == 0L) 0 else qbeta(alpha / 2, k, n - k + 1)
  upper <- if (k == n) 1 else qbeta(1 - alpha / 2, k + 1, n - k)
  c(lower = lower, upper = upper)
}

resident <- resident_raw %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    resident_group = clean_group(resident_group),
    assignment_criterion = as.integer(assignment_criterion),
    n_grouped_captures = as.integer(n_grouped_captures)
  ) %>%
  filter(
    !is.na(tattoo),
    !is.na(primary_year),
    !is.na(resident_group),
    assignment_criterion == 1L,
    n_grouped_captures >= 2L
  )

# ---------------------------------------------------------------------------
# Build the same two-year resident transition horizon as the prospecting design:
# baseline y-1 -> future y+1, represented by focal_year = y.
# ---------------------------------------------------------------------------

reference_moves <- resident %>%
  transmute(
    tattoo,
    baseline_year = primary_year,
    focal_year = primary_year + 1L,
    baseline_group = resident_group
  ) %>%
  left_join(
    resident %>%
      transmute(
        tattoo,
        future_year = primary_year,
        focal_year = primary_year - 1L,
        future_group = resident_group
      ),
    by = c("tattoo", "focal_year")
  ) %>%
  filter(
    !is.na(future_group),
    future_group != baseline_group
  )

write_csv(
  reference_moves,
  "results/prospecting_destination_null_reference_moves.csv"
)

# ---------------------------------------------------------------------------
# Strict focal movers after CLOSED prospecting.
# ---------------------------------------------------------------------------

focal <- pathway %>%
  mutate(
    baseline_group = clean_group(baseline_group),
    future_group = clean_group(future_group),
    closed_prospected_groups = as.character(closed_prospected_groups)
  ) %>%
  filter(
    n_closed_prospecting_bouts > 0L,
    future_residency_available,
    future_group != baseline_group,
    !is.na(closed_prospected_groups),
    closed_prospected_groups != ""
  ) %>%
  rowwise() %>%
  mutate(
    observed_match = future_group %in% split_groups(closed_prospected_groups)
  ) %>%
  ungroup()

cat("\n============================================================\n")
cat("DESTINATION MATCH NULL TEST\n")
cat("============================================================\n\n")
cat("Strict closed-prospecting movers:", nrow(focal), "\n")
cat("Observed destination matches:", sum(focal$observed_match), "\n")
cat(
  "Observed match proportion:",
  round(mean(focal$observed_match), 4), "\n"
)

ci <- cp_interval(sum(focal$observed_match), nrow(focal))
cat(
  "Exact 95% CI for observed match proportion:",
  round(ci["lower"], 4), "-",
  round(ci["upper"], 4), "\n\n"
)

# ---------------------------------------------------------------------------
# Event-level empirical null probabilities across several temporal windows.
# ---------------------------------------------------------------------------

window_specs <- tibble(
  window_label = c(
    "exact_year",
    "plus_minus_2y",
    "plus_minus_5y",
    "all_years"
  ),
  half_window = c(0, 2, 5, Inf)
)

event_rows <- list()
ii <- 0L

for (w in seq_len(nrow(window_specs))) {

  label <- window_specs$window_label[w]
  half_window <- window_specs$half_window[w]

  for (i in seq_len(nrow(focal))) {

    fi <- focal[i, ]
    targets <- split_groups(fi$closed_prospected_groups)

    ref <- reference_moves %>%
      filter(
        baseline_group == fi$baseline_group,
        tattoo != fi$tattoo
      )

    if (is.finite(half_window)) {
      ref <- ref %>%
        filter(abs(focal_year - fi$focal_year) <= half_window)
    }

    n_ref <- nrow(ref)
    n_ref_match <- if (n_ref) sum(ref$future_group %in% targets) else 0L
    n_ref_dest <- if (n_ref) n_distinct(ref$future_group) else 0L

    p_raw <- if (n_ref) n_ref_match / n_ref else NA_real_
    p_jeffreys <- if (n_ref) (n_ref_match + 0.5) / (n_ref + 1) else NA_real_

    ii <- ii + 1L
    event_rows[[ii]] <- tibble(
      window_label = label,
      half_window_years = half_window,
      tattoo = fi$tattoo,
      focal_year = fi$focal_year,
      baseline_group = fi$baseline_group,
      future_group = fi$future_group,
      prospected_groups = fi$closed_prospected_groups,
      observed_match = fi$observed_match,
      n_reference_moves = n_ref,
      n_reference_matching_destinations = n_ref_match,
      n_distinct_reference_destinations = n_ref_dest,
      null_match_probability_raw = p_raw,
      null_match_probability_jeffreys = p_jeffreys
    )
  }
}

event_level <- bind_rows(event_rows)

write_csv(
  event_level,
  "results/prospecting_destination_null_event_level.csv"
)

# ---------------------------------------------------------------------------
# Poisson-binomial summaries.
# ---------------------------------------------------------------------------

summary_rows <- event_level %>%
  group_by(window_label, half_window_years) %>%
  group_modify(~{
    d <- .x %>% filter(!is.na(null_match_probability_raw))
    dj <- .x %>% filter(!is.na(null_match_probability_jeffreys))

    n_tested <- nrow(d)
    k_obs <- if (n_tested) sum(d$observed_match) else NA_integer_

    tibble(
      n_focal_total = nrow(.x),
      n_focal_with_reference = n_tested,
      observed_matches_tested = k_obs,
      observed_match_prop_tested =
        if (n_tested) mean(d$observed_match) else NA_real_,
      median_reference_moves =
        if (n_tested) median(d$n_reference_moves) else NA_real_,
      min_reference_moves =
        if (n_tested) min(d$n_reference_moves) else NA_real_,
      median_null_match_probability_raw =
        if (n_tested) median(d$null_match_probability_raw) else NA_real_,
      expected_matches_raw =
        if (n_tested) sum(d$null_match_probability_raw) else NA_real_,
      exact_tail_p_raw =
        if (n_tested) {
          poibin_tail(d$null_match_probability_raw, k_obs)
        } else {
          NA_real_
        },
      expected_matches_jeffreys =
        if (nrow(dj)) sum(dj$null_match_probability_jeffreys) else NA_real_,
      exact_tail_p_jeffreys =
        if (nrow(dj)) {
          poibin_tail(
            dj$null_match_probability_jeffreys,
            sum(dj$observed_match)
          )
        } else {
          NA_real_
        }
    )
  }) %>%
  ungroup()

write_csv(
  summary_rows,
  "results/prospecting_destination_null_summary.csv"
)

cat("Empirical destination-choice null summaries:\n")
print(summary_rows, n = Inf, width = Inf)

# ---------------------------------------------------------------------------
# Reference-support diagnostics.
# ---------------------------------------------------------------------------

cat("\nReference support by temporal window:\n")
print(
  event_level %>%
    group_by(window_label) %>%
    summarise(
      focal_events = n(),
      with_any_reference = sum(n_reference_moves > 0L),
      with_at_least_3_reference = sum(n_reference_moves >= 3L),
      with_at_least_5_reference = sum(n_reference_moves >= 5L),
      median_reference_moves = median(n_reference_moves),
      max_reference_moves = max(n_reference_moves),
      .groups = "drop"
    ),
  n = Inf
)

cat("\nPer-focal-event support at +/-5 years:\n")
print(
  event_level %>%
    filter(window_label == "plus_minus_5y") %>%
    select(
      tattoo, focal_year, baseline_group, future_group, prospected_groups,
      observed_match, n_reference_moves, n_distinct_reference_destinations,
      null_match_probability_raw, null_match_probability_jeffreys
    ) %>%
    arrange(n_reference_moves),
  n = Inf,
  width = Inf
)

cat("\nInterpretation guardrails:\n")
cat(
  "- The focal n is deliberately small because the pathway definition is strict.\n",
  "- Emphasise effect size, exact CI, and consistency across null windows.\n",
  "- Do not treat p-values as decisive if reference support is sparse.\n",
  "- If +/-2y and +/-5y reference sets are poorly supported, the result is\n",
  "  suggestive and should not be promoted as a definitive destination-choice\n",
  "  effect.\n",
  "- If the destination-match excess survives both local temporal windows and\n",
  "  the all-years sensitivity, that substantially strengthens the prospecting\n",
  "  interpretation.\n",
  sep = ""
)

cat("\nSaved destination-null outputs in results/.\n")
