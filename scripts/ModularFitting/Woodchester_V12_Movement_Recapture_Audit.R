#!/usr/bin/env Rscript
# V12: retrospective V11R2 movement vs subsequent detection
# READ ONLY: no database changes, no model refitting.
# IMPORTANT: smoothed/FFBS states may use future observations.
# Therefore this is an association audit, NOT predictive validation.

root <- "data/model_snapshots/v12_20261106T103144Z_1079872"
out <- "outputs/v12_movement_demography_audit"
dir.create(out, recursive = TRUE, showWarnings = FALSE)

normalise_tattoo <- function(z) toupper(trimws(as.character(z)))

# ----------------------------------------------------------
# 1. Cleaned live encounters
# ----------------------------------------------------------
x <- readRDS(file.path(root, "qualifying_live.rds"))
x$capture_date <- as.Date(x$capture_date)
x <- x[!is.na(x$capture_date) & !is.na(x$tattoo), ]
x$tattoo <- normalise_tattoo(x$tattoo)
x$year <- as.integer(format(x$capture_date, "%Y"))

# One observation per individual and year.
observed <- unique(x[c("tattoo", "year")])
observed <- observed[observed$year <= 2025, ]

observed$key <- paste(observed$tattoo, observed$year, sep = "|")
observed_keys <- unique(observed$key)

# ----------------------------------------------------------
# 2. Three V11R2 state chains, 50m specification
# ----------------------------------------------------------
files <- Sys.glob(
  "results/V11R2_RES50_*_1932_CHAIN*_STATES.rds"
)

stopifnot(length(files) == 3L)

states <- lapply(files, function(f) {
  z <- readRDS(f)$state_summary

  required <- c("tattoo", "from_year", "to_year",
                "p_high_smoothed", "p_high_ffbs")
  stopifnot(all(required %in% names(z)))

  z <- as.data.frame(z[required])
  z$tattoo <- normalise_tattoo(z$tattoo)
  z$key <- paste(z$tattoo, z$from_year, z$to_year, sep = "|")

  if (anyDuplicated(z$key))
    stop("Duplicate state intervals in ", basename(f))

  z
})

keys <- states[[1]]$key

if (!all(vapply(states, function(z)
  setequal(z$key, keys), logical(1)))) {
  stop("V11R2 chain interval keys do not match.")
}

# Align all chains by explicit interval keys.
states <- lapply(states, function(z) z[match(keys, z$key), ])

movement <- states[[1]][c("tattoo", "from_year", "to_year")]
movement$p_high <- rowMeans(
  sapply(states, function(z) z$p_high_smoothed)
)
movement$p_high_ffbs <- rowMeans(
  sapply(states, function(z) z$p_high_ffbs)
)

# ----------------------------------------------------------
# 3. Join posterior geographical relocation probabilities
# ----------------------------------------------------------
path <- paste0(
  "outputs/V11R2_dynamic_social_group_overlay/",
  "pathways/01_interval_behavioural_pathways.csv"
)

p <- read.csv(path, stringsAsFactors = FALSE)
needed <- c("tattoo", "year_from", "year_to",
            "p_relocation_50", "mean_distance_m",
            "primary_annual_pathway")

stopifnot(all(needed %in% names(p)))

p$tattoo <- normalise_tattoo(p$tattoo)
p$key <- paste(p$tattoo, p$year_from, p$year_to, sep = "|")

if (anyDuplicated(p$key)) {
  stop("Duplicate behavioural pathway intervals.")
}

movement$key <- paste(movement$tattoo,
                      movement$from_year,
                      movement$to_year, sep = "|")

cols <- c("p_relocation_50", "mean_distance_m",
          "primary_annual_pathway")

idx <- match(movement$key, p$key)
for (nm in cols) movement[[nm]] <- p[[nm]][idx]

cat("Movement intervals:", nrow(movement), "\n")
cat("Intervals matched to pathway table:",
    sum(!is.na(idx)), "\n")

# ----------------------------------------------------------
# 4. Link to future recapture
# ----------------------------------------------------------
# Only use intervals ending by 2024, allowing full
# next-calendar-year follow-up through end-2025.

movement <- subset(movement, to_year <= 2024)

# Require a real live encounter in the destination year.
movement$observed_at_endpoint <-
  paste(movement$tattoo, movement$to_year, sep = "|") %in%
  observed_keys

movement <- subset(movement, observed_at_endpoint)

# Observation at any point in the following year.
movement$recaptured_next_year <-
  paste(movement$tattoo, movement$to_year + 1L, sep = "|") %in%
  observed_keys

# ----------------------------------------------------------
# 5. Summaries
# ----------------------------------------------------------
movement$mobility_group <- cut(
  movement$p_high,
  breaks = c(-Inf, 0.1, 0.5, 0.9, Inf),
  labels = c("<0.1", "0.1-0.5", "0.5-0.9", ">0.9")
)

movement$relocation_group <- cut(
  movement$p_relocation_50,
  breaks = c(-Inf, 0.1, 0.5, 0.9, Inf),
  labels = c("<0.1", "0.1-0.5", "0.5-0.9", ">0.9")
)

summarise <- function(group, df) {
  dat <- data.frame(
    group = as.character(group),
    returned = df$recaptured_next_year,
    tattoo = df$tattoo
  )

  dat <- dat[!is.na(dat$group) & !is.na(dat$returned), ]

  groups <- unique(dat$group)
  do.call(rbind, lapply(groups, function(g) {
    a <- dat[dat$group == g, ]
    data.frame(
      group = g,
      n_intervals = nrow(a),
      n_badgers = length(unique(a$tattoo)),
      recaptured = sum(a$returned),
      return_percent = round(100 * mean(a$returned), 1)
    )
  }))
}

cat("\n=== MATCHED SAMPLE ===\n")
cat("Eligible annual intervals:", nrow(movement), "\n")
cat("Distinct badgers:", length(unique(movement$tattoo)), "\n")
cat("Return next calendar year:",
    round(100 * mean(movement$recaptured_next_year), 1), "%\n")

cat("\n=== HIGH-MOBILITY PROBABILITY ===\n")
mob <- summarise(movement$mobility_group, movement)
print(mob, row.names = FALSE)

cat("\n=== RELOCATION PROBABILITY (50m MODEL) ===\n")
rel <- summarise(movement$relocation_group, movement)
print(rel, row.names = FALSE)

write.csv(movement,
  file.path(out, "v11r2_movement_vs_next_year_recapture.csv"),
  row.names = FALSE)

write.csv(mob,
  file.path(out, "mobility_vs_recapture_summary.csv"),
  row.names = FALSE)

write.csv(rel,
  file.path(out, "relocation_vs_recapture_summary.csv"),
  row.names = FALSE)

cat("\nOutputs saved to:", out, "\n")
cat("No fitted model or database data modified.\n")
