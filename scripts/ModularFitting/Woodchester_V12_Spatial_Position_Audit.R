#!/usr/bin/env Rscript
# Exploratory V11R2 spatial position versus subsequent recapture
# Read-only: does not alter the database, V11, or fitted models.
# Smoothed positions may be informed by later capture observations.

out <- "outputs/v12_movement_demography_audit"
root <- "data/model_snapshots/v12_20261106T103144Z_1079872"

files <- sort(Sys.glob(
  "results/V11R2_RES50_*_1932_CHAIN[123].rds"
))
stopifnot(length(files) == 3L)

norm <- function(x) toupper(trimws(as.character(x)))

# Ray-casting point-in-polygon calculation.
inside_polygon <- function(x, y, px, py) {
  inside <- rep(FALSE, length(x))
  n <- length(px)
  for (j in seq_len(n)) {
    k <- if (j == n) 1L else j + 1L
    cross <- (py[j] > y) != (py[k] > y)
    xcross <- px[j] + (y - py[j]) *
      (px[k] - px[j]) / (py[k] - py[j] + 1e-30)
    inside <- xor(inside, cross & (x < xcross))
  }
  inside
}

# Load first chain for indexing and reference detectors.
z <- readRDS(files[1])
idx <- as.data.frame(z$annual_state_index)
idx$tattoo <- norm(idx$tattoo)
idx$key <- paste(idx$tattoo, idx$year, sep = "|")

stopifnot(!anyDuplicated(idx$key))

det <- as.data.frame(z$detectors)
stopifnot(all(c("x", "y") %in% names(det)))

h <- chull(det$x, det$y)
hx <- det$x[h]
hy <- det$y[h]

sum_x <- numeric(nrow(idx))
sum_y <- numeric(nrow(idx))
outside_count <- numeric(nrow(idx))
total_draws <- 0L

# Process chains sequentially to limit memory usage.
for (chain in seq_along(files)) {
  if (chain > 1L) z <- readRDS(files[chain])

  ix <- as.data.frame(z$annual_state_index)
  ix$tattoo <- norm(ix$tattoo)
  ix$key <- paste(ix$tattoo, ix$year, sep = "|")

  stopifnot(!anyDuplicated(ix$key))
  order_ix <- match(idx$key, ix$key)
  stopifnot(!anyNA(order_ix))

  ix <- ix[order_ix, ]
  nm <- colnames(z$samples)

  cx <- match(ix$sample_column_x, nm)
  cy <- match(ix$sample_column_y, nm)
  stopifnot(!anyNA(cx), !anyNA(cy))

  pick <- unique(round(seq(
    1, nrow(z$samples), length.out = 60
  )))

  mx <- as.matrix(z$samples[pick, cx, drop = FALSE])
  my <- as.matrix(z$samples[pick, cy, drop = FALSE])

  stopifnot(all(is.finite(mx)), all(is.finite(my)))

  nr <- nrow(mx)
  nc <- ncol(mx)

  outside <- !matrix(
    inside_polygon(as.vector(mx), as.vector(my), hx, hy),
    nrow = nr, ncol = nc
  )

  sum_x <- sum_x + colSums(mx)
  sum_y <- sum_y + colSums(my)
  outside_count <- outside_count + colSums(outside)
  total_draws <- total_draws + nr

  cat("Processed chain", chain, "with", nr, "draws\n")
  rm(z, mx, my, outside)
  gc(verbose = FALSE)
}

idx$posterior_mean_x <- sum_x / total_draws
idx$posterior_mean_y <- sum_y / total_draws
idx$p_outside_global_hull <- outside_count / total_draws

# Distance to nearest detector from posterior mean position.
idx$nearest_detector_m <- vapply(
  seq_len(nrow(idx)),
  function(i) {
    min(sqrt(
      (det$x - idx$posterior_mean_x[i])^2 +
      (det$y - idx$posterior_mean_y[i])^2
    ))
  },
  numeric(1)
)

# Cleaned live recapture histories.
x <- readRDS(file.path(root, "qualifying_live.rds"))
x$capture_date <- as.Date(x$capture_date)
x <- x[!is.na(x$capture_date) & !is.na(x$tattoo), ]

x$tattoo <- norm(x$tattoo)
x$year <- as.integer(format(x$capture_date, "%Y"))

obs <- unique(paste(x$tattoo, x$year, sep = "|"))

# Complete next-calendar-year observation window through 2025.
idx <- idx[idx$year <= 2024, ]
idx$observed_this_year <- idx$key %in% obs
idx$return_next_year <- paste(
  idx$tattoo, idx$year + 1L, sep = "|"
) %in% obs

eligible <- idx[idx$observed_this_year, ]

cat("\n=== SPATIAL POSTERIOR AUDIT ===\n")
cat("All annual states through 2024:", nrow(idx), "\n")
cat("Endpoint-observed states:", nrow(eligible), "\n")
cat("Distinct badgers:", length(unique(eligible$tattoo)), "\n")
cat("Posterior draws per state:", total_draws, "\n")

cat("\nOutside historical detector hull probability:\n")
print(summary(eligible$p_outside_global_hull))

cat("\nNearest historical detector distance (metres):\n")
print(summary(eligible$nearest_detector_m))

# Descriptive summaries only, not inferential comparisons.
eligible$outside_group <- cut(
  eligible$p_outside_global_hull,
  c(-Inf, 0.05, 0.25, 0.75, Inf),
  labels = c("0-5%", "5-25%", "25-75%", ">75%")
)

cat("\n=== NEXT-YEAR RECAPTURE BY SPATIAL POSITION ===\n")

print(aggregate(
  return_next_year ~ outside_group,
  eligible,
  function(v) c(n = length(v),
                recapture_rate = mean(v))
))

write.csv(
  idx,
  file.path(out, "v11r2_annual_spatial_posterior_summary.csv"),
  row.names = FALSE
)

write.csv(
  eligible,
  file.path(out, "v11r2_spatial_position_vs_recapture.csv"),
  row.names = FALSE
)

cat("\nAudit saved. No source data modified.\n")
