# =============================================================================
# WOODCHESTER - PROSPECTING, TEMPORARY BRIDGING, AND LATER SETTLEMENT
#
# PURPOSE
# Move beyond generic mover/non-mover analyses and test explicit behavioural
# pathways in social space.
#
# FLAGSHIP QUESTION
# Do badgers prospect a future social group before settling there?
#
# Strong prospective sequence:
#
#   strict resident A in year y-1
#          ->
#   observed A -> B -> A in focal year y
#          ->
#   strict resident group in year y+1
#
# The focal-year captures are NOT used to define the baseline home group.
# Baseline A comes only from y-1. Future residency comes only from y+1.
# Both annual resident assignments must be criterion 1 and supported by >=2
# grouped captures, so adjacent-year information is not used to define either
# endpoint.
#
# This script is deliberately descriptive first. It does not fit another
# generic "who moves?" model. The aim is to establish whether the behavioural
# sequence exists in useful numbers before deciding on any inferential model.
#
# DEFINITIONS
# - capture-day: all live captures of one badger on one date.
# - unambiguous capture-day: all group records on that day agree.
# - closed prospecting bout: within one uninterrupted sequence of unambiguous
#   capture-days, baseline A is observed, followed by >=1 capture-day outside A,
#   followed by a return to A. This allows A->B->B->A and A->B->C->A, not just
#   the special case A->B->A.
# - unclosed outbound bout: A is observed, followed by extra-group use, but no
#   later A is observed before the sequence ends. This is NOT labelled permanent
#   dispersal because non-return may simply reflect incomplete observation.
# - destination match: strict y+1 resident group is one of the group(s) visited
#   during a focal-year prospecting bout.
#
# PRIMARY OUTPUTS
#   results/prospecting_pathway_badger_years.csv
#   results/prospecting_closed_bouts.csv
#   results/prospecting_unclosed_bouts.csv
#   results/prospecting_group_visits.csv
#   results/prospecting_summary.csv
#
# IMPORTANT
# We can demonstrate observed prospecting and later settlement into a visited
# group. We cannot infer unobserved visits between trapping occasions, nor exact
# bait-marked boundary-crossing paths.
# =============================================================================

library(tidyverse)

encounter_file <- "data/badger_encounters_useful.rds"
population_file <- "results/V7_population_inclusion_audit.rds"
resident_file <- "results/annual_resident_social_group_vicente.csv"

required <- c(encounter_file, population_file, resident_file)
missing <- required[!file.exists(required)]
if (length(missing)) {
  stop("Missing required file(s):\n", paste(missing, collapse = "\n"))
}

enc <- readRDS(encounter_file)
pop_obj <- readRDS(population_file)
resident_raw <- read_csv(resident_file, show_col_types = FALSE)

dir.create("results", showWarnings = FALSE, recursive = TRUE)

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

if (is.na(group_col)) stop("Could not identify capture-level SOCG field.")

clean_group <- function(x) {
  z <- x %>%
    as.character() %>%
    toupper() %>%
    str_squish()

  z[z %in% c("", "NA", "N/A", "UNKNOWN", "UNK", "NOT KNOWN")] <- NA_character_

  # Known legacy values excluded elsewhere in the movement pipeline.
  z[z %in% c("CHESTNUT", "HOLLOW TREE")] <- NA_character_
  z
}

collapse_groups <- function(x) {
  z <- sort(unique(x[!is.na(x) & x != ""]))
  if (!length(z)) NA_character_ else paste(z, collapse = ";")
}

split_groups <- function(x) {
  if (is.na(x) || x == "") character(0) else str_split(x, ";", simplify = FALSE)[[1]]
}

movement_badgers <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    sex = case_when(
      sex_class == "Female" ~ "Female",
      sex_class == "Male" ~ "Male",
      TRUE ~ NA_character_
    )
  )

resident <- resident_raw %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    resident_group = clean_group(resident_group),
    resident_assignment_criterion = as.integer(assignment_criterion),
    resident_n_grouped_captures = as.integer(n_grouped_captures)
  ) %>%
  filter(
    tattoo %in% movement_badgers$tattoo,
    !is.na(primary_year),
    !is.na(resident_group)
  )

strict_resident <- resident %>%
  filter(
    resident_assignment_criterion == 1L,
    resident_n_grouped_captures >= 2L
  )

# -----------------------------------------------------------------------------
# Three-year windows
# Baseline = y-1, focal behavioural year = y, future resident = y+1.
# -----------------------------------------------------------------------------

baseline <- strict_resident %>%
  transmute(
    tattoo,
    baseline_year = primary_year,
    focal_year = primary_year + 1L,
    baseline_group = resident_group,
    baseline_n_grouped_captures = resident_n_grouped_captures
  )

focal_resident <- strict_resident %>%
  transmute(
    tattoo,
    focal_year = primary_year,
    focal_resident_group = resident_group,
    focal_resident_n_grouped_captures = resident_n_grouped_captures
  )

future_resident <- strict_resident %>%
  transmute(
    tattoo,
    focal_year = primary_year - 1L,
    future_year = primary_year,
    future_group = resident_group,
    future_n_grouped_captures = resident_n_grouped_captures
  )

windows <- baseline %>%
  left_join(focal_resident, by = c("tattoo", "focal_year")) %>%
  left_join(future_resident, by = c("tattoo", "focal_year")) %>%
  left_join(movement_badgers, by = "tattoo") %>%
  filter(focal_year <= 2025L)

# -----------------------------------------------------------------------------
# Collapse capture records to capture-days.
# Ambiguous days are retained with day_group = NA and act as sequence breaks.
# -----------------------------------------------------------------------------

cap_day <- enc %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    capture_date = as.Date(capture_date),
    has_live_capture = as.logical(has_live_capture),
    capture_socg = clean_group(.data[[group_col]])
  ) %>%
  filter(
    has_live_capture,
    tattoo %in% movement_badgers$tattoo,
    !is.na(primary_year),
    primary_year <= 2025L,
    !is.na(capture_date),
    !is.na(capture_socg)
  ) %>%
  group_by(tattoo, primary_year, capture_date) %>%
  summarise(
    n_capture_records = n(),
    n_groups_day = n_distinct(capture_socg),
    day_group = if (n_distinct(capture_socg) == 1L) first(capture_socg) else NA_character_,
    groups_recorded_day = collapse_groups(capture_socg),
    .groups = "drop"
  )

focal_days <- windows %>%
  inner_join(
    cap_day,
    by = c("tattoo", "focal_year" = "primary_year")
  ) %>%
  arrange(tattoo, focal_year, capture_date)

cat("\n============================================================\n")
cat("PROSPECTING / TEMPORARY BRIDGING / LATER SETTLEMENT\n")
cat("============================================================\n\n")
cat("Strict prior-residency windows:", nrow(windows), "\n")
cat(
  "Windows with >=1 focal-year capture-day:",
  focal_days %>% distinct(tattoo, focal_year) %>% nrow(), "\n"
)
cat("Focal capture-days:", nrow(focal_days), "\n")
cat(
  "Ambiguous focal capture-days:",
  sum(is.na(focal_days$day_group)), "\n\n"
)

# -----------------------------------------------------------------------------
# Sequence parser
# -----------------------------------------------------------------------------

closed_bouts <- list()
open_bouts <- list()
year_rows <- list()
closed_i <- 0L
open_i <- 0L
year_i <- 0L

keys <- focal_days %>%
  distinct(tattoo, focal_year)

for (k in seq_len(nrow(keys))) {

  id <- keys$tattoo[k]
  yy <- keys$focal_year[k]

  d <- focal_days %>%
    filter(tattoo == id, focal_year == yy) %>%
    arrange(capture_date)

  A <- d$baseline_group[1]
  future_group <- d$future_group[1]
  focal_group <- d$focal_resident_group[1]

  # Ambiguous capture-days break the observed sequence. We do not bridge across
  # them because the order of social-group use is unresolved on that date.
  d <- d %>%
    mutate(
      ambiguous_day = is.na(day_group),
      segment_id = cumsum(ambiguous_day)
    )

  unamb <- d %>% filter(!ambiguous_day)

  all_extra_groups <- sort(unique(unamb$day_group[unamb$day_group != A]))
  all_extra_groups_chr <- if (length(all_extra_groups)) {
    paste(all_extra_groups, collapse = ";")
  } else {
    NA_character_
  }

  n_left_censored_extra_segments <- 0L
  n_closed <- 0L
  n_open <- 0L
  closed_groups_this_year <- character(0)
  closed_group_episode_hits <- character(0)

  segments <- split(unamb, unamb$segment_id)

  for (seg in segments) {
    if (!nrow(seg)) next

    seg <- seg %>% arrange(capture_date)
    g <- seg$day_group
    home_pos <- which(g == A)

    if (!length(home_pos)) {
      # All observations in this segment are outside the established baseline
      # group; departure and return are both unobserved.
      if (any(g != A)) n_left_censored_extra_segments <- n_left_censored_extra_segments + 1L
      next
    }

    if (home_pos[1] > 1L && any(g[seq_len(home_pos[1] - 1L)] != A)) {
      n_left_censored_extra_segments <- n_left_censored_extra_segments + 1L
    }

    # Every gap between consecutive observed home captures is a closed
    # prospecting bout if it contains >=1 outside-group capture-day.
    if (length(home_pos) >= 2L) {
      for (j in seq_len(length(home_pos) - 1L)) {
        p1 <- home_pos[j]
        p2 <- home_pos[j + 1L]

        if (p2 <= p1 + 1L) next

        extra_idx <- (p1 + 1L):(p2 - 1L)
        extra <- seg[extra_idx, , drop = FALSE]
        extra <- extra %>% filter(day_group != A)

        if (!nrow(extra)) next

        groups <- sort(unique(extra$day_group))
        closed_i <- closed_i + 1L
        n_closed <- n_closed + 1L
        closed_groups_this_year <- union(closed_groups_this_year, groups)
        closed_group_episode_hits <- c(closed_group_episode_hits, groups)

        closed_bouts[[closed_i]] <- tibble(
          tattoo = id,
          focal_year = yy,
          baseline_year = yy - 1L,
          future_year = yy + 1L,
          baseline_group = A,
          focal_resident_group = focal_group,
          future_group = future_group,
          departure_home_date = seg$capture_date[p1],
          extra_start_date = min(extra$capture_date),
          extra_end_date = max(extra$capture_date),
          return_home_date = seg$capture_date[p2],
          n_extra_capture_days = nrow(extra),
          n_visited_groups = length(groups),
          visited_groups = paste(groups, collapse = ";"),
          single_visited_group = if (length(groups) == 1L) groups else NA_character_,
          days_departure_to_return = as.integer(seg$capture_date[p2] - seg$capture_date[p1]),
          future_residency_available = !is.na(future_group),
          future_stayed_baseline = !is.na(future_group) && future_group == A,
          future_matches_this_bout = !is.na(future_group) && future_group %in% groups
        )
      }
    }

    # Extra-group use after the final observed home capture is right-censored:
    # we saw departure from A but did not observe a return before this sequence
    # ended. Never call this permanent dispersal.
    last_home <- max(home_pos)
    if (last_home < nrow(seg)) {
      extra <- seg[(last_home + 1L):nrow(seg), , drop = FALSE] %>%
        filter(day_group != A)

      if (nrow(extra)) {
        groups <- sort(unique(extra$day_group))
        open_i <- open_i + 1L
        n_open <- n_open + 1L

        open_bouts[[open_i]] <- tibble(
          tattoo = id,
          focal_year = yy,
          baseline_year = yy - 1L,
          future_year = yy + 1L,
          baseline_group = A,
          focal_resident_group = focal_group,
          future_group = future_group,
          departure_home_date = seg$capture_date[last_home],
          extra_start_date = min(extra$capture_date),
          last_extra_date = max(extra$capture_date),
          n_extra_capture_days = nrow(extra),
          n_visited_groups = length(groups),
          visited_groups = paste(groups, collapse = ";"),
          single_visited_group = if (length(groups) == 1L) groups else NA_character_,
          future_residency_available = !is.na(future_group),
          future_matches_unclosed_bout = !is.na(future_group) && future_group %in% groups
        )
      }
    }
  }

  closed_group_counts <- table(closed_group_episode_hits)
  repeated_closed_group <- if (length(closed_group_counts)) {
    any(closed_group_counts >= 2L)
  } else {
    FALSE
  }

  n_repeat_groups <- if (length(closed_group_counts)) {
    sum(closed_group_counts >= 2L)
  } else {
    0L
  }

  future_available <- !is.na(future_group)
  future_changed <- future_available && future_group != A
  future_match_any <- future_available && future_group %in% all_extra_groups
  future_match_closed <- future_available && future_group %in% closed_groups_this_year

  pure_single_target <- n_closed > 0L && length(closed_groups_this_year) == 1L
  single_target <- if (pure_single_target) closed_groups_this_year[1] else NA_character_

  pathway <- case_when(
    !future_available & n_closed == 0L & !length(all_extra_groups) ~
      "no extra-group use; future residency unavailable",
    !future_available & n_closed > 0L ~
      "closed prospecting observed; future residency unavailable",
    !future_available ~
      "extra-group use observed; future residency unavailable",

    future_available & !length(all_extra_groups) & future_group == A ~
      "no extra-group use; remained baseline resident",
    future_available & !length(all_extra_groups) & future_group != A ~
      "no observed extra-group use; later moved elsewhere",

    future_available & n_closed == 0L & future_group == A ~
      "extra-group use without observed return; remained baseline resident",
    future_available & n_closed == 0L & future_match_any ~
      "unclosed extra-group use; later resident in visited group",
    future_available & n_closed == 0L & future_changed ~
      "unclosed extra-group use; later moved to unvisited group",

    future_available & n_closed > 0L & future_group == A ~
      "closed prospecting; remained baseline resident",
    future_available & n_closed > 0L & future_match_closed ~
      "closed prospecting; later resident in prospected group",
    future_available & n_closed > 0L & future_changed ~
      "closed prospecting; later moved to unvisited group",

    TRUE ~ "other"
  )

  year_i <- year_i + 1L
  year_rows[[year_i]] <- tibble(
    tattoo = id,
    focal_year = yy,
    baseline_year = yy - 1L,
    future_year = yy + 1L,
    sex = d$sex[1],
    baseline_group = A,
    focal_resident_group = focal_group,
    future_group = future_group,
    baseline_n_grouped_captures = d$baseline_n_grouped_captures[1],
    focal_resident_n_grouped_captures = d$focal_resident_n_grouped_captures[1],
    future_n_grouped_captures = d$future_n_grouped_captures[1],
    n_capture_days = nrow(d),
    n_unambiguous_capture_days = sum(!d$ambiguous_day),
    n_ambiguous_capture_days = sum(d$ambiguous_day),
    n_home_capture_days = sum(d$day_group == A, na.rm = TRUE),
    n_extra_capture_days = sum(!is.na(d$day_group) & d$day_group != A),
    n_distinct_extra_groups = length(all_extra_groups),
    extra_groups_all = all_extra_groups_chr,
    n_closed_prospecting_bouts = n_closed,
    n_unclosed_outbound_bouts = n_open,
    n_left_censored_extra_segments = n_left_censored_extra_segments,
    n_distinct_closed_prospected_groups = length(closed_groups_this_year),
    closed_prospected_groups = if (length(closed_groups_this_year)) {
      paste(sort(closed_groups_this_year), collapse = ";")
    } else {
      NA_character_
    },
    repeated_closed_prospecting_same_group = repeated_closed_group,
    n_groups_repeatedly_prospected = n_repeat_groups,
    future_residency_available = future_available,
    future_changed_from_baseline = if (future_available) future_changed else NA,
    future_matches_any_extra_group = if (future_available) future_match_any else NA,
    future_matches_closed_prospected_group = if (future_available) future_match_closed else NA,
    pure_single_target_prospecting = pure_single_target,
    single_target_group = single_target,
    future_matches_single_target = if (future_available && pure_single_target) {
      future_group == single_target
    } else {
      NA
    },
    focal_residency_already_differs_from_baseline =
      !is.na(focal_group) && focal_group != A,
    pathway = pathway
  )
}

closed_tbl <- bind_rows(closed_bouts)
open_tbl <- bind_rows(open_bouts)
pathway_tbl <- bind_rows(year_rows)

if (!nrow(closed_tbl)) {
  closed_tbl <- tibble(
    tattoo = character(), focal_year = integer(), baseline_group = character()
  )
}
if (!nrow(open_tbl)) {
  open_tbl <- tibble(
    tattoo = character(), focal_year = integer(), baseline_group = character()
  )
}

write_csv(
  pathway_tbl,
  "results/prospecting_pathway_badger_years.csv"
)
write_csv(
  closed_tbl,
  "results/prospecting_closed_bouts.csv"
)
write_csv(
  open_tbl,
  "results/prospecting_unclosed_bouts.csv"
)

# One row per closed bout x visited group. This is useful for later network and
# disease analyses without treating semicolon-separated text as data.
group_visits <- if (nrow(closed_tbl)) {
  closed_tbl %>%
    select(
      tattoo, focal_year, baseline_group, future_group,
      departure_home_date, return_home_date, visited_groups
    ) %>%
    separate_rows(visited_groups, sep = ";") %>%
    rename(visited_group = visited_groups) %>%
    mutate(
      future_matches_visited_group =
        !is.na(future_group) & future_group == visited_group
    )
} else {
  tibble(
    tattoo = character(),
    focal_year = integer(),
    baseline_group = character(),
    future_group = character(),
    departure_home_date = as.Date(character()),
    return_home_date = as.Date(character()),
    visited_group = character(),
    future_matches_visited_group = logical()
  )
}

write_csv(
  group_visits,
  "results/prospecting_group_visits.csv"
)

# -----------------------------------------------------------------------------
# Primary summaries
# -----------------------------------------------------------------------------

cat("\n============================================================\n")
cat("P1: CLOSED PROSPECTING EXISTS?\n")
cat("============================================================\n")

cat("Focal badger-years analysed:", nrow(pathway_tbl), "\n")
cat(
  "Badger-years with any extra-group capture-day:",
  sum(pathway_tbl$n_extra_capture_days > 0L), "\n"
)
cat(
  "Badger-years with >=1 CLOSED prospecting bout (A -> other -> A):",
  sum(pathway_tbl$n_closed_prospecting_bouts > 0L), "\n"
)
cat("Total closed prospecting bouts:", nrow(closed_tbl), "\n")
cat(
  "Badger-years with repeated closed prospecting to the same group:",
  sum(pathway_tbl$repeated_closed_prospecting_same_group), "\n"
)
cat(
  "Badger-years prospecting >1 distinct outside group:",
  sum(pathway_tbl$n_distinct_closed_prospected_groups > 1L), "\n"
)

cat("\nClosed-bout visited-group counts:\n")
if (nrow(group_visits)) {
  print(
    group_visits %>%
      count(baseline_group, visited_group, sort = TRUE) %>%
      slice_head(n = 20),
    n = 20
  )
}

cat("\n============================================================\n")
cat("P2: DOES A PROSPECTED GROUP BECOME THE LATER RESIDENCE?\n")
cat("============================================================\n")

closed_future <- pathway_tbl %>%
  filter(
    n_closed_prospecting_bouts > 0L,
    future_residency_available
  )

cat(
  "Closed-prospecting badger-years with strict y+1 residency:",
  nrow(closed_future), "\n"
)

if (nrow(closed_future)) {

  destination_summary <- closed_future %>%
    summarise(
      n = n(),
      remained_baseline = sum(future_group == baseline_group),
      settled_prospected =
        sum(future_matches_closed_prospected_group),
      moved_unvisited =
        sum(
          future_group != baseline_group &
          !future_matches_closed_prospected_group
        )
    )

  print(destination_summary)

  cat(
    "Proportion later resident in a CLOSED-prospected group:",
    round(
      mean(closed_future$future_matches_closed_prospected_group),
      4
    ), "\n"
  )

  movers_after_closed <- closed_future %>%
    filter(future_group != baseline_group)

  if (nrow(movers_after_closed)) {
    cat(
      "Among animals that later changed residence, destination had been",
      "closed-prospected:",
      sum(movers_after_closed$future_matches_closed_prospected_group),
      "of", nrow(movers_after_closed),
      "(",
      round(
        100 * mean(
          movers_after_closed$future_matches_closed_prospected_group
        ),
        2
      ),
      "%)\n"
    )
  }
}

cat("\n============================================================\n")
cat("P3: PURE A -> B -> A PROSPECTING, THEN WHAT?\n")
cat("============================================================\n")

single_target <- pathway_tbl %>%
  filter(
    pure_single_target_prospecting,
    future_residency_available
  )

cat(
  "Badger-years where all CLOSED prospecting involved one target group B",
  "and strict y+1 residency is known:",
  nrow(single_target), "\n"
)

if (nrow(single_target)) {
  single_outcomes <- single_target %>%
    mutate(
      outcome = case_when(
        future_group == baseline_group ~ "returned/stayed resident A",
        future_group == single_target_group ~
          "later resident B (the prospected group)",
        TRUE ~ "later resident another group C"
      )
    ) %>%
    count(outcome, sort = TRUE) %>%
    mutate(prop = n / sum(n))

  print(single_outcomes, n = Inf)
}

cat("\n============================================================\n")
cat("P4: REPEATED PROSPECTING / TEMPORARY BRIDGING\n")
cat("============================================================\n")

repeat_years <- pathway_tbl %>%
  filter(repeated_closed_prospecting_same_group)

cat(
  "Badger-years with >=2 separate closed bouts to the same outside group:",
  nrow(repeat_years), "\n"
)
cat(
  "Unique badgers showing repeated same-group prospecting:",
  n_distinct(repeat_years$tattoo), "\n"
)

repeat_individuals <- pathway_tbl %>%
  filter(n_closed_prospecting_bouts > 0L) %>%
  group_by(tattoo) %>%
  summarise(
    n_years_with_closed_prospecting = n(),
    total_closed_bouts = sum(n_closed_prospecting_bouts),
    n_distinct_baseline_groups = n_distinct(baseline_group),
    .groups = "drop"
  ) %>%
  arrange(desc(n_years_with_closed_prospecting), desc(total_closed_bouts))

cat(
  "Badgers with closed prospecting in >=2 different focal years:",
  sum(repeat_individuals$n_years_with_closed_prospecting >= 2L), "\n"
)

write_csv(
  repeat_individuals,
  "results/prospecting_repeat_individuals.csv"
)

cat("\nPathway classification:\n")
pathway_counts <- pathway_tbl %>%
  count(pathway, sort = TRUE) %>%
  mutate(prop = n / sum(n))
print(pathway_counts, n = Inf)

summary_tbl <- tibble(
  metric = c(
    "focal_badger_years",
    "badger_years_any_extra_group_day",
    "badger_years_closed_prospecting",
    "closed_prospecting_bouts",
    "badger_years_repeated_same_group_prospecting",
    "badger_years_multiple_closed_prospected_groups",
    "closed_prospecting_years_with_future_residency",
    "pure_single_target_years_with_future_residency",
    "unique_badgers_repeated_same_group_prospecting",
    "unique_badgers_closed_prospecting_multiple_years"
  ),
  value = c(
    nrow(pathway_tbl),
    sum(pathway_tbl$n_extra_capture_days > 0L),
    sum(pathway_tbl$n_closed_prospecting_bouts > 0L),
    nrow(closed_tbl),
    sum(pathway_tbl$repeated_closed_prospecting_same_group),
    sum(pathway_tbl$n_distinct_closed_prospected_groups > 1L),
    nrow(closed_future),
    nrow(single_target),
    n_distinct(repeat_years$tattoo),
    sum(repeat_individuals$n_years_with_closed_prospecting >= 2L)
  )
)

write_csv(
  summary_tbl,
  "results/prospecting_summary.csv"
)

cat("\nSaved prospecting pathway outputs in results/.\n")
