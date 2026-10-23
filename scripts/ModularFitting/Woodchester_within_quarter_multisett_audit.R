# =============================================================================
# WOODCHESTER - WITHIN-QUARTER MULTI-SETT MOVEMENT AUDIT
#
# PURPOSE
#   Treat repeated within-quarter captures as observed behaviour rather than as
#   justification for a latent quarterly activity-centre layer.
#
# OUTPUTS
#   results/within_quarter_multisett_quarters.csv
#   results/within_quarter_multisett_consecutive_moves.csv
#
# NOTES
#   Distances are Euclidean distances between mapped sett coordinates.
#   Historical social-group crossing is deliberately NOT inferred here; that
#   should be joined to the versioned year/sett/social-group history separately.
# =============================================================================

library(tidyverse)

encounter_file <- "data/badger_encounters_useful.rds"
population_file <- "results/V7_population_inclusion_audit.rds"
sett_file <- "data/WoodchesterSettLocations.csv"

enc <- readRDS(encounter_file)
pop_obj <- readRDS(population_file)
sett_raw <- read_csv(sett_file, show_col_types = FALSE)

clean_sett <- function(x) {
  x %>%
    as.character() %>%
    toupper() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all("\\s+", "")
}

sett_aliases <- c(
  "CHESTNUT" = "CHESNUT",
  "JACKS" = "JACKSMIREY",
  "GRAVEL" = "GRAVELPIT",
  "BUCKHOLE" = "BUCKHOLT",
  "TOPSETT" = "TOP",
  "FOXCUB" = "FOX",
  "GULLEY" = "GULLY",
  "BLACKBERRY" = "BRAMBLE",
  "BOC" = "BOG",
  "CEDARBANK" = "CEDAR",
  "CLAYTRAP" = "CLAY",
  "CLIFF" = "CLIFFFACE",
  "DINGLEVALLEY" = "DINGLE"
)

clean_sett2 <- function(x) {
  z <- clean_sett(x)
  for (a in names(sett_aliases)) z[z == a] <- sett_aliases[[a]]
  z
}

name_col <- intersect(
  c("Sett_Clean", "Sett", "sett", "SettName", "Sett_Upper", "Name"),
  names(sett_raw)
)[1]
x_col <- intersect(
  c("SettX", "sett_x", "X", "x", "Easting", "easting"),
  names(sett_raw)
)[1]
y_col <- intersect(
  c("SettY", "sett_y", "Y", "y", "Northing", "northing"),
  names(sett_raw)
)[1]

if (any(is.na(c(name_col, x_col, y_col)))) {
  stop("Could not identify sett name/X/Y columns.")
}

sett_xy <- sett_raw %>%
  transmute(
    Sett_Clean = clean_sett2(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(!is.na(Sett_Clean), Sett_Clean != "", !is.na(x), !is.na(y)) %>%
  distinct(Sett_Clean, x, y)

bad_xy <- sett_xy %>% count(Sett_Clean) %>% filter(n > 1)
if (nrow(bad_xy)) stop("A cleaned sett maps to more than one coordinate pair.")

eligible <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(tattoo = toupper(trimws(as.character(tattoo))))

x <- enc %>%
  mutate(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    capture_date = as.Date(capture_date),
    Sett_Clean = clean_sett2(sett)
  ) %>%
  filter(
    has_live_capture,
    tattoo %in% eligible$tattoo,
    !is.na(primary_year),
    primary_year <= 2025,
    trap_season %in% 1:4,
    !is.na(capture_date),
    !is.na(Sett_Clean),
    Sett_Clean != ""
  ) %>%
  left_join(sett_xy, by = "Sett_Clean") %>%
  filter(!is.na(x), !is.na(y)) %>%
  arrange(tattoo, primary_year, trap_season, capture_date, Sett_Clean)

quarter_summary <- x %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(
    n_capture_records = n(),
    n_capture_dates = n_distinct(capture_date),
    n_distinct_setts = n_distinct(Sett_Clean),
    first_capture = min(capture_date),
    last_capture = max(capture_date),
    quarter_span_days = as.integer(last_capture - first_capture),
    setts = paste(unique(Sett_Clean), collapse = " | "),
    .groups = "drop"
  )

multi <- quarter_summary %>%
  filter(n_distinct_setts > 1)

consecutive_moves <- x %>%
  group_by(tattoo, primary_year, trap_season) %>%
  arrange(capture_date, Sett_Clean, .by_group = TRUE) %>%
  mutate(
    from_date = lag(capture_date),
    from_sett = lag(Sett_Clean),
    from_x = lag(x),
    from_y = lag(y),
    to_date = capture_date,
    to_sett = Sett_Clean,
    to_x = x,
    to_y = y,
    days_between = as.integer(to_date - from_date),
    distance_m = sqrt((to_x - from_x)^2 + (to_y - from_y)^2),
    changed_sett = !is.na(from_sett) & from_sett != to_sett
  ) %>%
  filter(!is.na(from_date), changed_sett) %>%
  ungroup() %>%
  select(
    tattoo, primary_year, trap_season,
    from_date, to_date, days_between,
    from_sett, to_sett,
    from_x, from_y, to_x, to_y,
    distance_m
  )

move_summary <- consecutive_moves %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(
    n_observed_sett_changes = n(),
    min_days_between = min(days_between),
    max_days_between = max(days_between),
    min_distance_m = min(distance_m),
    median_distance_m = median(distance_m),
    max_distance_m = max(distance_m),
    total_consecutive_distance_m = sum(distance_m),
    .groups = "drop"
  )

multi <- multi %>%
  left_join(
    move_summary,
    by = c("tattoo", "primary_year", "trap_season")
  ) %>%
  arrange(desc(max_distance_m), min_days_between)

dir.create("results", showWarnings = FALSE, recursive = TRUE)

write_csv(multi, "results/within_quarter_multisett_quarters.csv")
write_csv(
  consecutive_moves,
  "results/within_quarter_multisett_consecutive_moves.csv"
)

cat("\n============================================================\n")
cat("WITHIN-QUARTER MULTI-SETT MOVEMENT AUDIT\n")
cat("============================================================\n\n")

cat("Captured badger-quarters:", format(nrow(quarter_summary), big.mark = ","), "\n")
cat(
  "Multi-sett badger-quarters:", format(nrow(multi), big.mark = ","),
  " (", round(100 * nrow(multi) / nrow(quarter_summary), 2), "%)\n",
  sep = ""
)
cat(
  "Badgers ever multi-sett within a quarter:",
  n_distinct(multi$tattoo), "\n"
)
cat(
  "Observed consecutive sett-change transitions:",
  format(nrow(consecutive_moves), big.mark = ","), "\n\n"
)

if (nrow(consecutive_moves)) {
  cat("Days between observed different-sett captures:\n")
  print(quantile(
    consecutive_moves$days_between,
    c(0, .25, .5, .75, .9, .95, 1),
    na.rm = TRUE
  ))

  cat("\nDistance (m) between observed different-sett captures:\n")
  print(quantile(
    consecutive_moves$distance_m,
    c(0, .25, .5, .75, .9, .95, 1),
    na.rm = TRUE
  ))

  cat("\nTop multi-sett quarters by maximum observed distance:\n")
  print(
    multi %>%
      select(
        tattoo, primary_year, trap_season,
        n_capture_records, n_distinct_setts,
        quarter_span_days, setts,
        n_observed_sett_changes,
        min_days_between, max_distance_m
      ) %>%
      slice_head(n = 30),
    n = 30,
    width = Inf
  )
}

cat("\nSaved:\n")
cat("  results/within_quarter_multisett_quarters.csv\n")
cat("  results/within_quarter_multisett_consecutive_moves.csv\n")
