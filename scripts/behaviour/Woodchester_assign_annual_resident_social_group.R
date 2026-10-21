# =============================================================================
# WOODCHESTER - ANNUAL RESIDENT SOCIAL-GROUP ASSIGNMENT
#
# Reproduces the hierarchy described by Vicente et al. (2007) as closely and
# transparently as possible from the available capture-history data.
#
# IMPORTANT
#   This creates a DERIVED annual residency product. It never rewrites the
#   capture-level historical social-group field.
#
# OUTPUT
#   results/annual_resident_social_group_vicente.csv
# =============================================================================

library(tidyverse)
library(lubridate)

encounter_file <- "data/badger_encounters_useful.rds"
population_file <- "results/V7_population_inclusion_audit.rds"

enc <- readRDS(encounter_file)
pop_obj <- readRDS(population_file)

find_first_col <- function(nms, candidates) {
  z <- candidates[candidates %in% nms]
  if (!length(z)) return(NA_character_)
  z[1]
}

group_col <- find_first_col(
  names(enc),
  c(
    "recorded_social_group_name",
    "socg",
    "social_group",
    "normalized_social_group_name"
  )
)

if (is.na(group_col)) {
  stop(
    "Could not find a capture-level social-group field. Looked for: ",
    paste(
      c(
        "recorded_social_group_name",
        "socg",
        "social_group",
        "normalized_social_group_name"
      ),
      collapse = ", "
    )
  )
}

cat("Using capture-level social-group field:", group_col, "\n")

clean_group <- function(x) {
  z <- x %>%
    as.character() %>%
    toupper() %>%
    str_squish()

  z[z %in% c("", "NA", "N/A", "UNKNOWN", "UNK", "NOT KNOWN")] <- NA_character_

  # Explicit migration-QC cases that are known sett names, not valid social
  # groups, when found in the legacy SOCG field.
  z[z %in% c("CHESTNUT", "HOLLOW TREE")] <- NA_character_

  z
}

eligible <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(tattoo = toupper(trimws(as.character(tattoo))))

cap <- enc %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    capture_date = as.Date(capture_date),
    has_live_capture = as.logical(has_live_capture),
    recorded_group_raw = .data[[group_col]],
    recorded_group = clean_group(.data[[group_col]])
  ) %>%
  filter(
    has_live_capture,
    tattoo %in% eligible$tattoo,
    !is.na(primary_year),
    primary_year <= 2025,
    !is.na(capture_date)
  ) %>%
  arrange(tattoo, capture_date)

badger_years <- cap %>%
  distinct(tattoo, primary_year) %>%
  arrange(tattoo, primary_year)

# ---------------------------------------------------------------------------
# Capture summaries used by the five criteria
# ---------------------------------------------------------------------------

annual_counts <- cap %>%
  filter(!is.na(recorded_group)) %>%
  count(tattoo, primary_year, recorded_group, name = "n_current")

annual_ranked <- annual_counts %>%
  group_by(tattoo, primary_year) %>%
  mutate(
    max_current = max(n_current),
    is_current_mode = n_current == max_current,
    n_current_modes = sum(is_current_mode)
  ) %>%
  ungroup()

criterion1 <- annual_ranked %>%
  filter(is_current_mode, n_current_modes == 1L) %>%
  transmute(
    tattoo,
    primary_year,
    resident_group = recorded_group,
    assignment_criterion = 1L,
    assignment_detail = "unique modal capture group in current year"
  )

# Working table: every captured badger-year, including unresolved.
res <- badger_years %>%
  left_join(
    criterion1,
    by = c("tattoo", "primary_year")
  )

# Current-year top candidates, retained for tie-breaking.
current_candidates <- annual_ranked %>%
  filter(is_current_mode) %>%
  select(tattoo, primary_year, candidate_group = recorded_group, n_current)

# ---------------------------------------------------------------------------
# Criterion 2:
# For unresolved current-year ties, use already unambiguous criterion-1
# allocations in adjacent years. Among the current-year tied candidate groups,
# choose a unique group supported most often by y-1/y+1 criterion-1 residency.
# ---------------------------------------------------------------------------

adjacent_c1 <- criterion1 %>%
  select(tattoo, adjacent_year = primary_year, adjacent_group = resident_group)

c2_support <- res %>%
  filter(is.na(resident_group)) %>%
  select(tattoo, primary_year) %>%
  left_join(current_candidates, by = c("tattoo", "primary_year")) %>%
  left_join(adjacent_c1, by = "tattoo", relationship = "many-to-many") %>%
  filter(
    adjacent_year %in% c(primary_year - 1L, primary_year + 1L),
    adjacent_group == candidate_group
  ) %>%
  count(tattoo, primary_year, candidate_group, name = "adjacent_support") %>%
  group_by(tattoo, primary_year) %>%
  mutate(
    best = max(adjacent_support),
    n_best = sum(adjacent_support == best)
  ) %>%
  filter(adjacent_support == best, n_best == 1L) %>%
  ungroup() %>%
  transmute(
    tattoo,
    primary_year,
    c2_group = candidate_group
  )

res <- res %>%
  left_join(c2_support, by = c("tattoo", "primary_year")) %>%
  mutate(
    resident_group = coalesce(resident_group, c2_group),
    assignment_criterion = case_when(
      !is.na(assignment_criterion) ~ assignment_criterion,
      !is.na(c2_group) ~ 2L,
      TRUE ~ NA_integer_
    ),
    assignment_detail = case_when(
      !is.na(assignment_detail) ~ assignment_detail,
      !is.na(c2_group) ~
        "current-year tie resolved by criterion-1 residency in adjacent year(s)",
      TRUE ~ NA_character_
    )
  ) %>%
  select(-c2_group)

# ---------------------------------------------------------------------------
# Criterion 3:
# Pool captures in current year and both adjacent years. Choose a unique modal
# group. To avoid inventing residency unsupported in the current year, prefer
# groups that were among the current-year candidates when such candidates exist.
# ---------------------------------------------------------------------------

three_year_counts <- res %>%
  filter(is.na(resident_group)) %>%
  select(tattoo, primary_year) %>%
  left_join(
    cap %>%
      filter(!is.na(recorded_group)) %>%
      select(tattoo, capture_year = primary_year, recorded_group),
    by = "tattoo",
    relationship = "many-to-many"
  ) %>%
  filter(abs(capture_year - primary_year) <= 1L) %>%
  count(tattoo, primary_year, recorded_group, name = "n_three_year") %>%
  left_join(
    current_candidates,
    by = c("tattoo", "primary_year", "recorded_group" = "candidate_group")
  ) %>%
  group_by(tattoo, primary_year) %>%
  mutate(
    has_current_candidate = any(!is.na(n_current)),
    eligible_c3 = if_else(has_current_candidate, !is.na(n_current), TRUE)
  ) %>%
  filter(eligible_c3) %>%
  mutate(
    best = max(n_three_year),
    n_best = sum(n_three_year == best)
  ) %>%
  filter(n_three_year == best, n_best == 1L) %>%
  ungroup() %>%
  transmute(
    tattoo,
    primary_year,
    c3_group = recorded_group
  )

res <- res %>%
  left_join(three_year_counts, by = c("tattoo", "primary_year")) %>%
  mutate(
    resident_group = coalesce(resident_group, c3_group),
    assignment_criterion = case_when(
      !is.na(assignment_criterion) ~ assignment_criterion,
      !is.na(c3_group) ~ 3L,
      TRUE ~ NA_integer_
    ),
    assignment_detail = case_when(
      !is.na(assignment_detail) ~ assignment_detail,
      !is.na(c3_group) ~
        "unique modal capture group across current and adjacent years",
      TRUE ~ NA_character_
    )
  ) %>%
  select(-c3_group)

# ---------------------------------------------------------------------------
# Criterion 4:
# For remaining unresolved cases, use the last usable capture before 1 Jan and
# first usable capture after 31 Dec. Choose whichever is temporally closer to
# the focal year, restricted to the tied most-frequent groups across the
# three-year window where possible.
# ---------------------------------------------------------------------------

c3_candidates <- res %>%
  filter(is.na(resident_group)) %>%
  select(tattoo, primary_year) %>%
  left_join(
    cap %>%
      filter(!is.na(recorded_group)) %>%
      select(tattoo, capture_year = primary_year, capture_date, recorded_group),
    by = "tattoo",
    relationship = "many-to-many"
  ) %>%
  filter(abs(capture_year - primary_year) <= 1L) %>%
  count(tattoo, primary_year, recorded_group, name = "n_three_year") %>%
  group_by(tattoo, primary_year) %>%
  mutate(best = max(n_three_year)) %>%
  filter(n_three_year == best) %>%
  ungroup() %>%
  select(tattoo, primary_year, candidate_group = recorded_group)

c4_evidence <- res %>%
  filter(is.na(resident_group)) %>%
  select(tattoo, primary_year) %>%
  mutate(
    year_start = as.Date(paste0(primary_year, "-01-01")),
    year_end = as.Date(paste0(primary_year, "-12-31"))
  ) %>%
  left_join(
    cap %>%
      filter(!is.na(recorded_group)) %>%
      select(tattoo, capture_date, recorded_group),
    by = "tattoo",
    relationship = "many-to-many"
  ) %>%
  left_join(c3_candidates, by = c("tattoo", "primary_year")) %>%
  filter(
    is.na(candidate_group) | recorded_group == candidate_group
  ) %>%
  mutate(
    relative = case_when(
      capture_date < year_start ~ "before",
      capture_date > year_end ~ "after",
      TRUE ~ "inside"
    ),
    lag_days = case_when(
      relative == "before" ~ as.integer(year_start - capture_date),
      relative == "after" ~ as.integer(capture_date - year_end),
      TRUE ~ NA_integer_
    )
  ) %>%
  filter(relative %in% c("before", "after")) %>%
  group_by(tattoo, primary_year, relative) %>%
  slice_min(lag_days, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  group_by(tattoo, primary_year) %>%
  slice_min(lag_days, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(tattoo, primary_year, c4_group = recorded_group)

res <- res %>%
  left_join(c4_evidence, by = c("tattoo", "primary_year")) %>%
  mutate(
    resident_group = coalesce(resident_group, c4_group),
    assignment_criterion = case_when(
      !is.na(assignment_criterion) ~ assignment_criterion,
      !is.na(c4_group) ~ 4L,
      TRUE ~ NA_integer_
    ),
    assignment_detail = case_when(
      !is.na(assignment_detail) ~ assignment_detail,
      !is.na(c4_group) ~
        "nearest relevant capture immediately before/after focal year",
      TRUE ~ NA_character_
    )
  ) %>%
  select(-c4_group)

# ---------------------------------------------------------------------------
# Criterion 5:
# First relevant capture group in the focal year, otherwise the first usable
# group in the local capture history.
# ---------------------------------------------------------------------------

c5 <- res %>%
  filter(is.na(resident_group)) %>%
  select(tattoo, primary_year) %>%
  left_join(
    cap %>%
      filter(!is.na(recorded_group)) %>%
      select(tattoo, capture_year = primary_year, capture_date, recorded_group),
    by = "tattoo",
    relationship = "many-to-many"
  ) %>%
  mutate(
    focal_priority = if_else(capture_year == primary_year, 0L, 1L),
    year_distance = abs(capture_year - primary_year)
  ) %>%
  arrange(tattoo, primary_year, focal_priority, year_distance, capture_date) %>%
  group_by(tattoo, primary_year) %>%
  slice_head(n = 1) %>%
  ungroup() %>%
  transmute(tattoo, primary_year, c5_group = recorded_group)

res <- res %>%
  left_join(c5, by = c("tattoo", "primary_year")) %>%
  mutate(
    resident_group = coalesce(resident_group, c5_group),
    assignment_criterion = case_when(
      !is.na(assignment_criterion) ~ assignment_criterion,
      !is.na(c5_group) ~ 5L,
      TRUE ~ NA_integer_
    ),
    assignment_detail = case_when(
      !is.na(assignment_detail) ~ assignment_detail,
      !is.na(c5_group) ~ "first relevant usable capture group",
      TRUE ~ "unresolved: no usable recorded social-group evidence"
    )
  ) %>%
  select(-c5_group)

# Attach evidence summaries.
annual_evidence <- annual_counts %>%
  group_by(tattoo, primary_year) %>%
  summarise(
    n_grouped_captures = sum(n_current),
    n_distinct_groups_current = n_distinct(recorded_group),
    current_group_counts = paste(
      paste0(recorded_group, ":", n_current),
      collapse = " | "
    ),
    .groups = "drop"
  )

res <- res %>%
  left_join(annual_evidence, by = c("tattoo", "primary_year")) %>%
  mutate(
    resident_group_resolved = !is.na(resident_group)
  ) %>%
  arrange(tattoo, primary_year)

dir.create("results", showWarnings = FALSE, recursive = TRUE)
out_file <- "results/annual_resident_social_group_vicente.csv"
write_csv(res, out_file)

cat("\n============================================================\n")
cat("ANNUAL RESIDENT SOCIAL-GROUP ASSIGNMENT\n")
cat("============================================================\n\n")

cat("Captured badger-years:", format(nrow(res), big.mark = ","), "\n")
cat("Resolved:", sum(res$resident_group_resolved), "\n")
cat("Unresolved:", sum(!res$resident_group_resolved), "\n\n")

criterion_summary <- res %>%
  count(assignment_criterion, name = "n_badger_years") %>%
  mutate(percent = 100 * n_badger_years / nrow(res))

print(criterion_summary, n = Inf)

p1 <- mean(res$assignment_criterion == 1L, na.rm = TRUE)
cat("\nCriterion-1 proportion:", round(100 * p1, 2), "%\n")
cat("Published Vicente et al. benchmark: >96% assigned by criterion 1.\n")

if (is.finite(p1) && p1 < 0.90) {
  warning(
    "Criterion-1 proportion is well below the published Woodchester benchmark. ",
    "Audit capture-level social-group cleaning before using this product."
  )
}

cat("\nSaved:\n", out_file, "\n", sep = "")
