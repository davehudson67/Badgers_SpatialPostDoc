# =============================================================================
# Woodchester V10B collapsed-HMM: recover annual movement states
#
# Reads one collapsed-HMM MCMC chain and performs, conditional on every retained
# posterior draw:
#   1. forward filtering,
#   2. backward smoothing,
#   3. one exact FFBS sample of the complete local/high state path.
#
# The fitted biological model is unchanged from explicit-state V10B. The binary
# states were integrated out during MCMC only to improve mixing.
#
# Environment:
#   MAX_BADGERS  default 100
#   CHAIN_ID     1, 2 or 3
#
# Writes:
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN<C>_STATES.rds
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN<C>_state_probabilities.csv
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "100"))
CHAIN_ID <- as.integer(Sys.getenv("CHAIN_ID", unset = "1"))

MOVE_MIN <- 0.5
MOVE_MAX <- 2500

if (!CHAIN_ID %in% 1:3) stop("CHAIN_ID must be 1, 2 or 3.")

prefix <- file.path(
  "results",
  paste0("V10B_RD_MULTILOC_AR1_COLLAPSED_", MAX_BADGERS)
)

chain_file <- paste0(prefix, "_CHAIN", CHAIN_ID, ".rds")
state_file <- paste0(prefix, "_CHAIN", CHAIN_ID, "_STATES.rds")
csv_file <- paste0(prefix, "_CHAIN", CHAIN_ID, "_state_probabilities.csv")

if (!file.exists(chain_file)) {
  stop("Missing collapsed-HMM chain file: ", chain_file)
}

fit <- readRDS(chain_file)

if (!identical(
  fit$model,
  "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM"
)) {
  stop("Input is not a V10B collapsed-HMM fit.")
}

if (is.null(fit$sex_data) || is.null(fit$adult_entry)) {
  stop("Collapsed fit is missing sex_data/adult_entry required for state recovery.")
}

mm <- as.matrix(fit$samples)
disp_index <- fit$disp_index
annual_index <- fit$annual_state_index

required_global <- c(
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_high",
  "alpha_disp_init",
  "beta_disp_adult",
  "beta_disp_init_sex",
  "alpha_RD",
  "beta_RD_sex",
  "alpha_DD",
  "beta_DD_sex"
)

missing_global <- setdiff(required_global, colnames(mm))
if (length(missing_global)) {
  stop(
    "Missing global posterior columns: ",
    paste(missing_global, collapse = ", ")
  )
}

annual_cols <- c(
  annual_index$sample_column_x,
  annual_index$sample_column_y
)
missing_annual <- setdiff(annual_cols, colnames(mm))
if (length(missing_annual)) {
  stop(
    "Missing annual AC posterior columns; first missing: ",
    missing_annual[1]
  )
}

nd <- nrow(mm)
ntotal <- nrow(disp_index)

if (ntotal < 1L) stop("No movement intervals in disp_index.")

cat("\n============================================================\n")
cat("V10B COLLAPSED-HMM STATE RECOVERY\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("Chain:", CHAIN_ID, "\n")
cat("Posterior draws:", nd, "\n")
cat("Movement intervals:", ntotal, "\n")

# Stable two-component log mixture and filter update, vectorised over draws.
forward_one_badger <- function(
  d2,
  sex_i,
  adult_i,
  mm
) {
  Tn <- ncol(d2)
  nd <- nrow(d2)

  log_sig0 <-
    mm[, "alpha_logmove"] +
    mm[, "beta_move_sex"] * sex_i

  log_sig1 <-
    log_sig0 +
    mm[, "beta_move_high"]

  sig0_raw <- exp(log_sig0)
  sig1_raw <- exp(log_sig1)

  support0 <-
    sig0_raw >= MOVE_MIN &
    sig0_raw <= MOVE_MAX

  support1 <-
    sig1_raw >= MOVE_MIN &
    sig1_raw <= MOVE_MAX

  if (any(!support0 & !support1)) {
    stop(
      "A posterior draw has neither movement component within the ",
      "0.5--2500 m computational support."
    )
  }

  # Clamp only for safe density evaluation; unsupported components are then
  # assigned -Inf emission log density, exactly matching the collapsed fitter.
  sig0 <- pmin(MOVE_MAX, pmax(MOVE_MIN, sig0_raw))
  sig1 <- pmin(MOVE_MAX, pmax(MOVE_MIN, sig1_raw))

  loge0 <-
    -log(2 * pi) -
    2 * log(sig0) -
    d2 / (2 * sig0^2)

  loge1 <-
    -log(2 * pi) -
    2 * log(sig1) -
    d2 / (2 * sig1^2)

  loge0[!support0, ] <- -Inf
  loge1[!support1, ] <- -Inf

  p_init <- plogis(
    mm[, "alpha_disp_init"] +
      mm[, "beta_disp_adult"] * adult_i +
      mm[, "beta_disp_init_sex"] * sex_i
  )

  p_RD <- plogis(
    mm[, "alpha_RD"] +
      mm[, "beta_RD_sex"] * sex_i
  )

  p_DD <- plogis(
    mm[, "alpha_DD"] +
      mm[, "beta_DD_sex"] * sex_i
  )

  alpha1 <- matrix(NA_real_, nd, Tn)

  for (tt in seq_len(Tn)) {
    pred1 <- if (tt == 1L) {
      p_init
    } else {
      (1 - alpha1[, tt - 1L]) * p_RD +
        alpha1[, tt - 1L] * p_DD
    }

    pred1 <- pmin(1 - 1e-12, pmax(1e-12, pred1))

    lc0 <- log1p(-pred1) + loge0[, tt]
    lc1 <- log(pred1) + loge1[, tt]

    lm0 <- pmax(lc0, lc1)
    lm <- lm0 + log(
      exp(lc0 - lm0) +
        exp(lc1 - lm0)
    )

    alpha1[, tt] <- exp(lc1 - lm)
  }

  # Backward smoothing. Backward messages are rescaled at every step because
  # only their relative values are required.
  smooth1 <- matrix(NA_real_, nd, Tn)
  b0 <- rep(1, nd)
  b1 <- rep(1, nd)

  smooth1[, Tn] <- alpha1[, Tn]

  if (Tn > 1L) {
    for (tt in (Tn - 1L):1L) {
      ee_max <- pmax(
        loge0[, tt + 1L],
        loge1[, tt + 1L]
      )

      e0 <- exp(loge0[, tt + 1L] - ee_max)
      e1 <- exp(loge1[, tt + 1L] - ee_max)

      b0_new <-
        (1 - p_RD) * e0 * b0 +
        p_RD * e1 * b1

      b1_new <-
        (1 - p_DD) * e0 * b0 +
        p_DD * e1 * b1

      bb_scale <- pmax(b0_new + b1_new, 1e-300)
      b0 <- b0_new / bb_scale
      b1 <- b1_new / bb_scale

      den <-
        (1 - alpha1[, tt]) * b0 +
        alpha1[, tt] * b1

      smooth1[, tt] <-
        alpha1[, tt] * b1 /
        pmax(den, 1e-300)
    }
  }

  # Exact forward-filter backward-sample path for every posterior draw.
  z <- matrix(0L, nd, Tn)
  z[, Tn] <- rbinom(nd, 1L, alpha1[, Tn])

  if (Tn > 1L) {
    for (tt in (Tn - 1L):1L) {
      next_is_high <- z[, tt + 1L] == 1L

      num_high <- ifelse(
        next_is_high,
        alpha1[, tt] * p_DD,
        alpha1[, tt] * (1 - p_DD)
      )

      num_low <- ifelse(
        next_is_high,
        (1 - alpha1[, tt]) * p_RD,
        (1 - alpha1[, tt]) * (1 - p_RD)
      )

      prob_high <- num_high / pmax(num_high + num_low, 1e-300)
      z[, tt] <- rbinom(nd, 1L, prob_high)
    }
  }

  list(
    smooth1 = smooth1,
    z = z
  )
}

# ---- forward/backward algebra self-check ------------------------------------
# Compare smoothed probabilities from forward_one_badger() with exact
# brute-force enumeration of all 2^4 state sequences.
test_mm <- matrix(
  0,
  nrow = 1,
  ncol = length(required_global),
  dimnames = list(NULL, required_global)
)
test_mm[1, "alpha_logmove"] <- log(20)
test_mm[1, "beta_move_sex"] <- 0
test_mm[1, "beta_move_high"] <- log(500 / 20)
test_mm[1, "alpha_disp_init"] <- qlogis(0.07)
test_mm[1, "beta_disp_adult"] <- 0
test_mm[1, "beta_disp_init_sex"] <- 0
test_mm[1, "alpha_RD"] <- qlogis(0.05)
test_mm[1, "beta_RD_sex"] <- 0
test_mm[1, "alpha_DD"] <- qlogis(0.30)
test_mm[1, "beta_DD_sex"] <- 0

test_d2 <- matrix(c(20^2, 350^2, 40^2, 700^2), nrow = 1)
test_rr <- forward_one_badger(test_d2, 0L, 0L, test_mm)

test_states <- expand.grid(rep(list(0:1), 4))
test_logw <- numeric(nrow(test_states))

for (rr in seq_len(nrow(test_states))) {
  z <- as.integer(test_states[rr, ])
  lp <- if (z[1] == 1L) log(0.07) else log(0.93)

  for (tt in 1:4) {
    sig <- if (z[tt] == 1L) 500 else 20
    lp <-
      lp -
      log(2 * pi) -
      2 * log(sig) -
      test_d2[1, tt] / (2 * sig^2)

    if (tt < 4) {
      p1 <- if (z[tt] == 1L) 0.30 else 0.05
      lp <- lp +
        if (z[tt + 1L] == 1L) log(p1) else log1p(-p1)
    }
  }

  test_logw[rr] <- lp
}

test_w <- exp(test_logw - max(test_logw))
test_w <- test_w / sum(test_w)

test_exact <- vapply(
  1:4,
  function(tt) sum(test_w * as.integer(test_states[[tt]])),
  numeric(1)
)

if (!isTRUE(
  all.equal(
    as.numeric(test_rr$smooth1[1, ]),
    test_exact,
    tolerance = 1e-10
  )
)) {
  stop(
    "Forward-backward state recovery failed brute-force identity check."
  )
}

cat("Forward-backward smoothing self-check: PASS\n")

set.seed(73000L + CHAIN_ID)

state_draws <- matrix(
  0L,
  nrow = nd,
  ncol = ntotal
)

smooth_mean <- numeric(ntotal)

for (i in seq_along(fit$ids)) {
  di <- which(disp_index$model_i == i)
  ai <- which(annual_index$model_i == i)

  if (!length(di)) next

  di <- di[order(disp_index$state_k[di])]
  ai <- ai[order(annual_index$state_k[ai])]

  if (length(ai) != length(di) + 1L) {
    stop(
      "Annual/transition index mismatch for ",
      fit$ids[i],
      ": annual=", length(ai),
      " transitions=", length(di)
    )
  }

  xcols <- annual_index$sample_column_x[ai]
  ycols <- annual_index$sample_column_y[ai]

  xx <- mm[, xcols, drop = FALSE]
  yy <- mm[, ycols, drop = FALSE]

  d2 <-
    (xx[, -1L, drop = FALSE] - xx[, -ncol(xx), drop = FALSE])^2 +
    (yy[, -1L, drop = FALSE] - yy[, -ncol(yy), drop = FALSE])^2

  rr <- forward_one_badger(
    d2 = d2,
    sex_i = fit$sex_data[i],
    adult_i = fit$adult_entry[i],
    mm = mm
  )

  state_draws[, di] <- rr$z
  smooth_mean[di] <- colMeans(rr$smooth1)

  if (i %% 100L == 0L || i == length(fit$ids)) {
    cat("Recovered states for", i, "of", length(fit$ids), "badgers\n")
  }
}

colnames(state_draws) <- paste0(
  "disp_active[",
  seq_len(ntotal),
  "]"
)

ffbs_mean <- colMeans(state_draws)

state_summary <- disp_index %>%
  mutate(
    p_high_smoothed = smooth_mean,
    p_high_ffbs = ffbs_mean,
    ffbs_minus_smoothed = p_high_ffbs - p_high_smoothed
  )

cat("\nState recovery diagnostics:\n")
cat(
  "  Mean smoothed high-state occupancy:",
  mean(state_summary$p_high_smoothed), "\n"
)
cat(
  "  Mean FFBS high-state occupancy:",
  mean(state_summary$p_high_ffbs), "\n"
)
cat(
  "  Mean absolute FFBS-vs-smoothed difference:",
  mean(abs(state_summary$ffbs_minus_smoothed)), "\n"
)
cat(
  "  Max absolute FFBS-vs-smoothed difference:",
  max(abs(state_summary$ffbs_minus_smoothed)), "\n"
)

saveRDS(
  list(
    model = "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM",
    source_chain = chain_file,
    chain_id = CHAIN_ID,
    ids = fit$ids,
    individual_ids = fit$individual_ids,
    sex_data = fit$sex_data,
    adult_entry = fit$adult_entry,
    years = fit$years,
    first = fit$first,
    K = fit$K,
    disp_index = disp_index,
    state_draws = state_draws,
    p_high_smoothed_chain = smooth_mean,
    p_high_ffbs_chain = ffbs_mean,
    state_summary = state_summary
  ),
  state_file
)

write_csv(
  state_summary,
  csv_file
)

cat("\nSaved recovered-state object:\n", state_file, "\n", sep = "")
cat("Saved state-probability CSV:\n", csv_file, "\n", sep = "")
cat("\nSTATE RECOVERY COMPLETE\n")
