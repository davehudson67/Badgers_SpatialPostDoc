# =============================================================================
# Woodchester V10B collapsed-HMM: cross-chain annual-trajectory diagnostic
#
# PURPOSE
#   Diagnose whether disagreement in recovered annual local/high movement
#   probabilities is being driven by alternative posterior modes in the
#   continuous annual activity-centre (A) trajectories.
#
# Reads:
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN1.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN2.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN3.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN1_STATES.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN2_STATES.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN3_STATES.rds
#
# Environment:
#   MAX_BADGERS   fitted population size in filenames (default 1932)
#   TOP_N         number of worst intervals to save/print (default 100)
#   STATE_DIFF    p(high) chain-difference flag threshold (default 0.50)
#   AC_SEP_M      endpoint posterior-mean AC separation threshold in m
#                 (default 100)
#   DISP_DIFF_M   annual displacement-median chain-difference threshold in m
#                 (default 100)
#
# Writes:
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_trajectory_chain_diagnostic.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_trajectory_chain_top<N>.csv
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_trajectory_chain_summary.csv
#
# Interpretation:
#   This is a diagnostic, not a new biological model. Large cross-chain
#   differences in posterior annual displacement and/or posterior-mean AC
#   endpoints, coincident with large p(high) disagreement, support the
#   hypothesis that chains are occupying different annual-trajectory modes.
#
# Memory:
#   Full-population chain objects are large. Chains are processed one at a time,
#   and only the annual AC monitored columns are copied to a plain matrix.
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "1932"))
TOP_N <- as.integer(Sys.getenv("TOP_N", unset = "100"))
STATE_DIFF <- as.numeric(Sys.getenv("STATE_DIFF", unset = "0.50"))
AC_SEP_M <- as.numeric(Sys.getenv("AC_SEP_M", unset = "100"))
DISP_DIFF_M <- as.numeric(Sys.getenv("DISP_DIFF_M", unset = "100"))
CHAIN_IDS <- 1:3

if (!is.finite(MAX_BADGERS) || MAX_BADGERS < 2L) {
  stop("MAX_BADGERS must be >= 2.")
}
if (!is.finite(TOP_N) || TOP_N < 1L) {
  stop("TOP_N must be >= 1.")
}

prefix <- file.path(
  "results",
  paste0("V10B_RD_MULTILOC_AR1_COLLAPSED_", MAX_BADGERS)
)

chain_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, ".rds")
state_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, "_STATES.rds")

missing_files <- c(chain_files, state_files)[
  !file.exists(c(chain_files, state_files))
]
if (length(missing_files)) {
  stop(
    "Missing required file(s):\n",
    paste(missing_files, collapse = "\n")
  )
}

cat("\n============================================================\n")
cat("V10B CROSS-CHAIN ANNUAL-TRAJECTORY DIAGNOSTIC\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("State-difference flag:", STATE_DIFF, "\n")
cat("AC endpoint separation flag:", AC_SEP_M, "m\n")
cat("Displacement-median difference flag:", DISP_DIFF_M, "m\n\n")

# -----------------------------------------------------------------------------
# Canonical biological indices from chain 1
# -----------------------------------------------------------------------------
fit1 <- readRDS(chain_files[1])

if (!identical(
  fit1$model,
  "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM"
)) {
  stop("Chain 1 is not a V10B collapsed-HMM fit.")
}

disp_index <- fit1$disp_index
annual_index_ref <- fit1$annual_state_index

required_disp <- c(
  "active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "from_year",
  "to_year"
)

required_annual <- c(
  "annual_active_index",
  "model_i",
  "individual_id",
  "tattoo",
  "state_k",
  "year",
  "sample_column_x",
  "sample_column_y"
)

if (!all(required_disp %in% names(disp_index))) {
  stop("disp_index is missing required columns.")
}
if (!all(required_annual %in% names(annual_index_ref))) {
  stop("annual_state_index is missing required columns.")
}

# Exact row mapping: a movement interval at state_k is A[k-1] -> A[k].
annual_key_ref <- paste(
  annual_index_ref$model_i,
  annual_index_ref$state_k,
  sep = "::"
)

from_key <- paste(
  disp_index$model_i,
  disp_index$state_k - 1L,
  sep = "::"
)

to_key <- paste(
  disp_index$model_i,
  disp_index$state_k,
  sep = "::"
)

from_row_ref <- match(from_key, annual_key_ref)
to_row_ref <- match(to_key, annual_key_ref)

if (anyNA(from_row_ref) || anyNA(to_row_ref)) {
  stop("Could not map every movement interval to from/to annual AC rows.")
}

# Keep only the metadata needed after the first chain has been processed.
fit1$samples <- NULL
rm(fit1)
invisible(gc())

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
pair_distance <- function(x1, y1, x2, y2) {
  sqrt((x1 - x2)^2 + (y1 - y2)^2)
}

summarise_displacements <- function(
  mm,
  annual_index,
  from_row,
  to_row,
  chunk_size = 250L
) {
  n_int <- length(from_row)

  out <- tibble(
    active_index = seq_len(n_int),
    disp_mean = NA_real_,
    disp_median = NA_real_,
    disp_q025 = NA_real_,
    disp_q975 = NA_real_,
    p_disp_gt_100 = NA_real_,
    p_disp_gt_250 = NA_real_,
    p_disp_gt_500 = NA_real_,
    p_disp_gt_1000 = NA_real_
  )

  starts <- seq.int(1L, n_int, by = chunk_size)

  for (ss in starts) {
    ee <- min(n_int, ss + chunk_size - 1L)
    ii <- ss:ee

    fx <- annual_index$sample_column_x[from_row[ii]]
    fy <- annual_index$sample_column_y[from_row[ii]]
    tx <- annual_index$sample_column_x[to_row[ii]]
    ty <- annual_index$sample_column_y[to_row[ii]]

    dx <- mm[, tx, drop = FALSE] - mm[, fx, drop = FALSE]
    dy <- mm[, ty, drop = FALSE] - mm[, fy, drop = FALSE]
    dd <- sqrt(dx^2 + dy^2)

    out$disp_mean[ii] <- colMeans(dd)
    out$disp_median[ii] <- apply(dd, 2, median)
    out$disp_q025[ii] <- apply(
      dd,
      2,
      quantile,
      probs = 0.025,
      names = FALSE
    )
    out$disp_q975[ii] <- apply(
      dd,
      2,
      quantile,
      probs = 0.975,
      names = FALSE
    )

    out$p_disp_gt_100[ii] <- colMeans(dd > 100)
    out$p_disp_gt_250[ii] <- colMeans(dd > 250)
    out$p_disp_gt_500[ii] <- colMeans(dd > 500)
    out$p_disp_gt_1000[ii] <- colMeans(dd > 1000)

    rm(dx, dy, dd)
  }

  out
}

# -----------------------------------------------------------------------------
# Process one full chain at a time
# -----------------------------------------------------------------------------
chain_results <- vector("list", length(CHAIN_IDS))

for (ch in CHAIN_IDS) {
  cat(
    "Processing chain ", ch, " of 3 ...\n",
    sep = ""
  )

  fit <- readRDS(chain_files[ch])
  states <- readRDS(state_files[ch])

  if (!identical(
    fit$model,
    "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM"
  )) {
    stop("Chain ", ch, " is not a V10B collapsed-HMM fit.")
  }

  if (!identical(
    states$model,
    "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM"
  )) {
    stop("State sidecar ", ch, " is not a V10B collapsed-HMM state file.")
  }

  annual_index <- fit$annual_state_index

  same_annual <- isTRUE(
    all.equal(
      annual_index_ref %>%
        select(all_of(required_annual)) %>%
        as.data.frame(),
      annual_index %>%
        select(all_of(required_annual)) %>%
        as.data.frame(),
      check.attributes = FALSE
    )
  )

  if (!same_annual) {
    stop("Annual latent-location index differs in chain ", ch, ".")
  }

  same_disp <- isTRUE(
    all.equal(
      disp_index %>%
        select(all_of(required_disp)) %>%
        as.data.frame(),
      states$disp_index %>%
        select(all_of(required_disp)) %>%
        as.data.frame(),
      check.attributes = FALSE
    )
  )

  if (!same_disp) {
    stop("Recovered-state index differs in chain ", ch, ".")
  }

  if (
    length(states$p_high_smoothed_chain) != nrow(disp_index)
  ) {
    stop("p_high_smoothed_chain has wrong length in chain ", ch, ".")
  }

  annual_cols <- unique(
    c(
      annual_index$sample_column_x,
      annual_index$sample_column_y
    )
  )

  missing_cols <- setdiff(
    annual_cols,
    colnames(fit$samples)
  )
  if (length(missing_cols)) {
    stop(
      "Missing annual AC sample columns in chain ",
      ch,
      "; first missing: ",
      missing_cols[1]
    )
  }

  # Copy annual AC columns only. This is deliberately much smaller than copying
  # every monitored latent quarterly location.
  mm <- as.matrix(
    fit$samples[, annual_cols, drop = FALSE]
  )

  x_mean <- colMeans(
    mm[, annual_index$sample_column_x, drop = FALSE]
  )
  y_mean <- colMeans(
    mm[, annual_index$sample_column_y, drop = FALSE]
  )

  from_x_mean <- x_mean[from_row_ref]
  from_y_mean <- y_mean[from_row_ref]
  to_x_mean <- x_mean[to_row_ref]
  to_y_mean <- y_mean[to_row_ref]

  disp_sum <- summarise_displacements(
    mm = mm,
    annual_index = annual_index,
    from_row = from_row_ref,
    to_row = to_row_ref
  )

  chain_tbl <- disp_sum %>%
    mutate(
      p_high = states$p_high_smoothed_chain,
      from_x_mean = from_x_mean,
      from_y_mean = from_y_mean,
      to_x_mean = to_x_mean,
      to_y_mean = to_y_mean,
      mean_path_distance = pair_distance(
        from_x_mean,
        from_y_mean,
        to_x_mean,
        to_y_mean
      )
    )

  chain_tbl <- chain_tbl %>%
    rename_with(
      ~ paste0(.x, "_chain", ch),
      -active_index
    )

  chain_results[[ch]] <- chain_tbl

  rm(
    fit,
    states,
    mm,
    x_mean,
    y_mean,
    from_x_mean,
    from_y_mean,
    to_x_mean,
    to_y_mean,
    disp_sum,
    chain_tbl
  )
  invisible(gc())
}

# -----------------------------------------------------------------------------
# Join chain-specific diagnostics and calculate cross-chain differences
# -----------------------------------------------------------------------------
diagnostic <- disp_index %>%
  select(all_of(required_disp)) %>%
  left_join(chain_results[[1]], by = "active_index") %>%
  left_join(chain_results[[2]], by = "active_index") %>%
  left_join(chain_results[[3]], by = "active_index")

p_high_mat <- diagnostic %>%
  select(
    p_high_chain1,
    p_high_chain2,
    p_high_chain3
  ) %>%
  as.matrix()

disp_median_mat <- diagnostic %>%
  select(
    disp_median_chain1,
    disp_median_chain2,
    disp_median_chain3
  ) %>%
  as.matrix()

disp_mean_mat <- diagnostic %>%
  select(
    disp_mean_chain1,
    disp_mean_chain2,
    disp_mean_chain3
  ) %>%
  as.matrix()

from_sep_12 <- pair_distance(
  diagnostic$from_x_mean_chain1,
  diagnostic$from_y_mean_chain1,
  diagnostic$from_x_mean_chain2,
  diagnostic$from_y_mean_chain2
)
from_sep_13 <- pair_distance(
  diagnostic$from_x_mean_chain1,
  diagnostic$from_y_mean_chain1,
  diagnostic$from_x_mean_chain3,
  diagnostic$from_y_mean_chain3
)
from_sep_23 <- pair_distance(
  diagnostic$from_x_mean_chain2,
  diagnostic$from_y_mean_chain2,
  diagnostic$from_x_mean_chain3,
  diagnostic$from_y_mean_chain3
)

to_sep_12 <- pair_distance(
  diagnostic$to_x_mean_chain1,
  diagnostic$to_y_mean_chain1,
  diagnostic$to_x_mean_chain2,
  diagnostic$to_y_mean_chain2
)
to_sep_13 <- pair_distance(
  diagnostic$to_x_mean_chain1,
  diagnostic$to_y_mean_chain1,
  diagnostic$to_x_mean_chain3,
  diagnostic$to_y_mean_chain3
)
to_sep_23 <- pair_distance(
  diagnostic$to_x_mean_chain2,
  diagnostic$to_y_mean_chain2,
  diagnostic$to_x_mean_chain3,
  diagnostic$to_y_mean_chain3
)

diagnostic <- diagnostic %>%
  mutate(
    p_high_min = apply(p_high_mat, 1, min),
    p_high_max = apply(p_high_mat, 1, max),
    max_p_high_difference = p_high_max - p_high_min,

    disp_median_min = apply(disp_median_mat, 1, min),
    disp_median_max = apply(disp_median_mat, 1, max),
    max_disp_median_difference =
      disp_median_max - disp_median_min,

    disp_mean_min = apply(disp_mean_mat, 1, min),
    disp_mean_max = apply(disp_mean_mat, 1, max),
    max_disp_mean_difference =
      disp_mean_max - disp_mean_min,

    from_ac_sep_12 = from_sep_12,
    from_ac_sep_13 = from_sep_13,
    from_ac_sep_23 = from_sep_23,
    max_from_ac_chain_separation = pmax(
      from_sep_12,
      from_sep_13,
      from_sep_23
    ),

    to_ac_sep_12 = to_sep_12,
    to_ac_sep_13 = to_sep_13,
    to_ac_sep_23 = to_sep_23,
    max_to_ac_chain_separation = pmax(
      to_sep_12,
      to_sep_13,
      to_sep_23
    ),

    max_endpoint_chain_separation = pmax(
      max_from_ac_chain_separation,
      max_to_ac_chain_separation
    ),

    state_pattern = paste0(
      if_else(p_high_chain1 > 0.5, "H", "L"),
      if_else(p_high_chain2 > 0.5, "H", "L"),
      if_else(p_high_chain3 > 0.5, "H", "L")
    ),

    state_discordant =
      max_p_high_difference > STATE_DIFF,

    displacement_mode_signal =
      max_disp_median_difference > DISP_DIFF_M,

    endpoint_mode_signal =
      max_endpoint_chain_separation > AC_SEP_M,

    trajectory_mode_signal =
      displacement_mode_signal | endpoint_mode_signal,

    state_and_trajectory_discordant =
      state_discordant & trajectory_mode_signal
  ) %>%
  arrange(
    desc(max_p_high_difference),
    desc(max_disp_median_difference),
    desc(max_endpoint_chain_separation)
  )

# -----------------------------------------------------------------------------
# Summary diagnostics
# -----------------------------------------------------------------------------
safe_spearman <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 3L) return(NA_real_)
  suppressWarnings(
    cor(x[ok], y[ok], method = "spearman")
  )
}

state_discordant_tbl <- diagnostic %>%
  filter(state_discordant)

summary_tbl <- tibble(
  n_intervals = nrow(diagnostic),
  n_state_discordant = sum(diagnostic$state_discordant),
  prop_state_discordant = mean(diagnostic$state_discordant),
  n_disp_mode_signal = sum(diagnostic$displacement_mode_signal),
  n_endpoint_mode_signal = sum(diagnostic$endpoint_mode_signal),
  n_trajectory_mode_signal = sum(diagnostic$trajectory_mode_signal),
  n_state_and_trajectory_discordant =
    sum(diagnostic$state_and_trajectory_discordant),
  prop_state_discordance_with_trajectory_signal =
    if (nrow(state_discordant_tbl)) {
      mean(state_discordant_tbl$trajectory_mode_signal)
    } else {
      NA_real_
    },
  median_max_p_high_difference =
    median(diagnostic$max_p_high_difference),
  p95_max_p_high_difference =
    unname(quantile(diagnostic$max_p_high_difference, 0.95)),
  median_max_disp_median_difference =
    median(diagnostic$max_disp_median_difference),
  p95_max_disp_median_difference =
    unname(
      quantile(
        diagnostic$max_disp_median_difference,
        0.95
      )
    ),
  median_max_endpoint_chain_separation =
    median(diagnostic$max_endpoint_chain_separation),
  p95_max_endpoint_chain_separation =
    unname(
      quantile(
        diagnostic$max_endpoint_chain_separation,
        0.95
      )
    ),
  spearman_state_diff_vs_disp_diff =
    safe_spearman(
      diagnostic$max_p_high_difference,
      diagnostic$max_disp_median_difference
    ),
  spearman_state_diff_vs_endpoint_sep =
    safe_spearman(
      diagnostic$max_p_high_difference,
      diagnostic$max_endpoint_chain_separation
    )
)

top_n <- min(TOP_N, nrow(diagnostic))

top_tbl <- diagnostic %>%
  slice_head(n = top_n)

console_cols <- c(
  "active_index",
  "tattoo",
  "from_year",
  "to_year",
  "state_pattern",
  "p_high_chain1",
  "p_high_chain2",
  "p_high_chain3",
  "disp_median_chain1",
  "disp_median_chain2",
  "disp_median_chain3",
  "max_disp_median_difference",
  "max_from_ac_chain_separation",
  "max_to_ac_chain_separation",
  "max_endpoint_chain_separation",
  "trajectory_mode_signal"
)

cat("\n============================================================\n")
cat("TRAJECTORY-DIAGNOSTIC SUMMARY\n")
cat("============================================================\n")
print(summary_tbl, n = Inf, width = Inf)

cat("\n============================================================\n")
cat("WORST 30 STATE-DISCORDANT INTERVALS\n")
cat("============================================================\n")
print(
  top_tbl %>%
    select(all_of(console_cols)) %>%
    slice_head(n = min(30L, nrow(top_tbl))),
  n = Inf,
  width = Inf
)

cat("\nState-pattern counts among intervals with p(high) chain difference > ",
    STATE_DIFF, ":\n", sep = "")
print(
  diagnostic %>%
    filter(state_discordant) %>%
    count(state_pattern, sort = TRUE),
  n = Inf,
  width = Inf
)

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------
full_csv <- paste0(
  prefix,
  "_trajectory_chain_diagnostic.csv"
)
top_csv <- paste0(
  prefix,
  "_trajectory_chain_top",
  top_n,
  ".csv"
)
summary_csv <- paste0(
  prefix,
  "_trajectory_chain_summary.csv"
)

write_csv(diagnostic, full_csv)
write_csv(top_tbl, top_csv)
write_csv(summary_tbl, summary_csv)

cat("\nSaved full interval diagnostic:\n", full_csv, "\n", sep = "")
cat("Saved top-", top_n, " intervals:\n", top_csv, "\n", sep = "")
cat("Saved summary:\n", summary_csv, "\n", sep = "")
cat("\nTRAJECTORY DIAGNOSTIC COMPLETE\n")
