# =============================================================================
# Woodchester V11 collapsed-HMM: recover annual movement states
#
# Reads one collapsed-HMM MCMC chain and performs, conditional on every retained
# posterior draw:
#   1. forward filtering,
#   2. backward smoothing,
#   3. one exact FFBS sample of the complete local/high state path.
#
# The fitted biological model is unchanged from explicit-state V11. The binary
# states were integrated out during MCMC only to improve mixing.
#
# Environment:
#   FILE_STEM     result filename stem; default "V11_RD_MULTILOC_AR1_COLLAPSED"
#   MAX_BADGERS  default 100
#   CHAIN_ID     1, 2 or 3
#   MIN_RAW_ITER minimum underlying raw MCMC iteration to retain (default 0)
#   STATE_SUFFIX optional suffix for sidecar filenames, e.g. "_TAIL"
#
# Writes:
#   results/V11_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN<C>_STATES.rds
#   results/V11_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN<C>_state_probabilities.csv
# =============================================================================

library(tidyverse)

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "100"))
FILE_STEM <- Sys.getenv(
  "FILE_STEM",
  unset = "V11_RD_MULTILOC_IID_AGE_BADGERRE"
)
CHAIN_ID <- as.integer(Sys.getenv("CHAIN_ID", unset = "1"))
MIN_RAW_ITER <- as.integer(Sys.getenv("MIN_RAW_ITER", unset = "0"))
STATE_SUFFIX <- Sys.getenv("STATE_SUFFIX", unset = "")

if (!is.finite(MIN_RAW_ITER) || MIN_RAW_ITER < 0L) {
  stop("MIN_RAW_ITER must be >= 0.")
}

MOVE_MIN <- 0.5
MOVE_MAX <- 2500

if (!CHAIN_ID %in% 1:3) stop("CHAIN_ID must be 1, 2 or 3.")

prefix <- file.path(
  "results",
  paste0(FILE_STEM, "_", MAX_BADGERS)
)

chain_file <- paste0(prefix, "_CHAIN", CHAIN_ID, ".rds")
state_file <- paste0(
  prefix, "_CHAIN", CHAIN_ID, "_STATES", STATE_SUFFIX, ".rds"
)
csv_file <- paste0(
  prefix, "_CHAIN", CHAIN_ID, "_state_probabilities", STATE_SUFFIX, ".csv"
)

if (!file.exists(chain_file)) {
  stop("Missing collapsed-HMM chain file: ", chain_file)
}

fit <- readRDS(chain_file)

accepted_models <- c(
  "V11_RD_SCR_MULTILOC_IID_AGE_BADGERRE_COLLAPSED_HMM",
  "V11_RD_SCR_ANNUALAC_MULTILOC_AGE_BADGERRE_COLLAPSED_HMM",
  "V11R_RD_SCR_ANNUALAC_FIXEDRES_MULTILOC_AGE_BADGERRE_COLLAPSED_HMM",
  "V11R2_RD_SCR_ANNUALAC_DECOUPLED_MULTILOC_AGE_BADGERRE_COLLAPSED_HMM"
)

if (!fit$model %in% accepted_models) {
  stop(
    "Input is not a supported V11/V11R age + badger-RE collapsed-HMM fit. Model: ",
    fit$model
  )
}

is_v11r2 <- identical(
  fit$model,
  "V11R2_RD_SCR_ANNUALAC_DECOUPLED_MULTILOC_AGE_BADGERRE_COLLAPSED_HMM"
)

required_fit_fields <- c(
  "sex_data",
  "age_years_matrix",
  "age_2",
  "age_3_5",
  "age_6plus",
  "age_unknown"
)

missing_fit_fields <- required_fit_fields[
  !vapply(required_fit_fields, function(z) !is.null(fit[[z]]), logical(1))
]

if (length(missing_fit_fields)) {
  stop(
    "Collapsed V11 fit is missing required age/sex fields: ",
    paste(missing_fit_fields, collapse = ", ")
  )
}

mm <- as.matrix(fit$samples)

# Optional late-chain filter expressed in the underlying raw MCMC iteration.
# For these fits, retained draw r corresponds to approximately
#   nburn + thin * r.
# Using ">" makes the cutoff conservative and keeps only draws strictly after
# the requested raw iteration.
if (MIN_RAW_ITER > 0L) {
  nburn_fit <- as.integer(fit$settings$nburn)
  thin_fit <- as.integer(fit$settings$thin)

  if (!is.finite(nburn_fit) || !is.finite(thin_fit) || thin_fit < 1L) {
    stop("Fit metadata is missing valid nburn/thin values.")
  }

  raw_iteration <- nburn_fit + thin_fit * seq_len(nrow(mm))
  keep_draw <- raw_iteration > MIN_RAW_ITER

  if (sum(keep_draw) < 100L) {
    stop(
      "Too few posterior draws remain after MIN_RAW_ITER=", MIN_RAW_ITER,
      ": ", sum(keep_draw)
    )
  }

  mm <- mm[keep_draw, , drop = FALSE]

  cat(
    "Using late-chain subset: raw iteration > ", MIN_RAW_ITER,
    " (", nrow(mm), " retained draws)\n",
    sep = ""
  )
}

disp_index <- fit$disp_index
annual_index <- fit$annual_state_index

required_global <- if (is_v11r2) {
  c(
    "alpha_logmove",
    "alpha_logmove_high",
    "beta_highscale_sex",
    "alpha_disp_init",
    "beta_disp_init_sex",
    "alpha_RD",
    "beta_RD_sex",
    "beta_age_2",
    "beta_age_3_5",
    "beta_age_6plus",
    "beta_age_unknown",
    "alpha_DD",
    "beta_DD_sex"
  )
} else {
  c(
    "alpha_logmove",
    "beta_move_sex",
    "beta_move_high",
    "alpha_disp_init",
    "beta_disp_init_sex",
    "alpha_RD",
    "beta_RD_sex",
    "beta_age_2",
    "beta_age_3_5",
    "beta_age_6plus",
    "beta_age_unknown",
    "alpha_DD",
    "beta_DD_sex"
  )
}

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
cat("V11 AGE + BADGER-RE COLLAPSED-HMM STATE RECOVERY\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("Chain:", CHAIN_ID, "\n")
cat("Posterior draws:", nd, "\n")
cat("Minimum raw iteration:", MIN_RAW_ITER, "\n")
cat("State suffix:", ifelse(nzchar(STATE_SUFFIX), STATE_SUFFIX, "<none>"), "\n")
cat("Movement intervals:", ntotal, "\n")

# Stable two-component log mixture and filter update, vectorised over draws.
forward_one_badger <- function(
  d2,
  sex_i,
  age2_i,
  age35_i,
  age6_i,
  ageunk_i,
  b_col,
  mm
) {
  Tn <- ncol(d2)
  nd <- nrow(d2)

  if (
    length(age2_i) != Tn ||
    length(age35_i) != Tn ||
    length(age6_i) != Tn ||
    length(ageunk_i) != Tn
  ) {
    stop("Age-vector length does not match movement-history length.")
  }

  if (!b_col %in% colnames(mm)) {
    stop("Missing individual mover-effect posterior column: ", b_col)
  }

  if (is_v11r2) {
    # V11R2: resident process noise is sex-neutral and fixed; sex affects
    # relocation distance only.
    log_sig0 <- mm[, "alpha_logmove"]
    log_sig1 <-
      mm[, "alpha_logmove_high"] +
      mm[, "beta_highscale_sex"] * sex_i
  } else {
    log_sig0 <-
      mm[, "alpha_logmove"] +
      mm[, "beta_move_sex"] * sex_i

    log_sig1 <-
      log_sig0 +
      mm[, "beta_move_high"]
  }

  sig0_raw <- exp(log_sig0)
  sig1_raw <- exp(log_sig1)

  support0 <- sig0_raw >= MOVE_MIN & sig0_raw <= MOVE_MAX
  support1 <- sig1_raw >= MOVE_MIN & sig1_raw <= MOVE_MAX

  if (any(!support0 & !support1)) {
    stop(
      "A posterior draw has neither movement component within the ",
      "0.5--2500 m computational support."
    )
  }

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

  b_i <- mm[, b_col]

  age_eta <-
    outer(mm[, "beta_age_2"], age2_i) +
    outer(mm[, "beta_age_3_5"], age35_i) +
    outer(mm[, "beta_age_6plus"], age6_i) +
    outer(mm[, "beta_age_unknown"], ageunk_i)

  p_init <- plogis(
    mm[, "alpha_disp_init"] +
      mm[, "beta_disp_init_sex"] * sex_i +
      age_eta[, 1L] +
      b_i
  )

  base_RD <-
    mm[, "alpha_RD"] +
    mm[, "beta_RD_sex"] * sex_i +
    b_i

  p_RD <- plogis(
    matrix(base_RD, nrow = nd, ncol = Tn) +
      age_eta
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
      (1 - alpha1[, tt - 1L]) * p_RD[, tt] +
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

      p_RD_next <- p_RD[, tt + 1L]

      b0_new <-
        (1 - p_RD_next) * e0 * b0 +
        p_RD_next * e1 * b1

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

  z <- matrix(0L, nd, Tn)
  z[, Tn] <- rbinom(nd, 1L, alpha1[, Tn])

  if (Tn > 1L) {
    for (tt in (Tn - 1L):1L) {
      next_is_high <- z[, tt + 1L] == 1L
      p_RD_next <- p_RD[, tt + 1L]

      num_high <- ifelse(
        next_is_high,
        alpha1[, tt] * p_DD,
        alpha1[, tt] * (1 - p_DD)
      )

      num_low <- ifelse(
        next_is_high,
        (1 - alpha1[, tt]) * p_RD_next,
        (1 - alpha1[, tt]) * (1 - p_RD_next)
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
# Compare smoothed probabilities with exact enumeration when age effects and
# individual propensity are zero. This recovers the standard constant-transition
# HMM and verifies that the time-varying implementation reduces correctly.
test_cols <- c(required_global, "b_badger[1]")
test_mm <- matrix(
  0,
  nrow = 1,
  ncol = length(test_cols),
  dimnames = list(NULL, test_cols)
)

test_mm[1, "alpha_logmove"] <- log(20)
if (is_v11r2) {
  test_mm[1, "alpha_logmove_high"] <- log(500)
  test_mm[1, "beta_highscale_sex"] <- 0
} else {
  test_mm[1, "beta_move_sex"] <- 0
  test_mm[1, "beta_move_high"] <- log(500 / 20)
}
test_mm[1, "alpha_disp_init"] <- qlogis(0.07)
test_mm[1, "beta_disp_init_sex"] <- 0
test_mm[1, "alpha_RD"] <- qlogis(0.05)
test_mm[1, "beta_RD_sex"] <- 0
test_mm[1, "beta_age_2"] <- 0
test_mm[1, "beta_age_3_5"] <- 0
test_mm[1, "beta_age_6plus"] <- 0
test_mm[1, "beta_age_unknown"] <- 0
test_mm[1, "alpha_DD"] <- qlogis(0.30)
test_mm[1, "beta_DD_sex"] <- 0
test_mm[1, "b_badger[1]"] <- 0

test_d2 <- matrix(c(20^2, 350^2, 40^2, 700^2), nrow = 1)
test_rr <- forward_one_badger(
  d2 = test_d2,
  sex_i = 0L,
  age2_i = rep(0L, 4),
  age35_i = rep(0L, 4),
  age6_i = rep(0L, 4),
  ageunk_i = rep(0L, 4),
  b_col = "b_badger[1]",
  mm = test_mm
)

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
    "V11 forward-backward state recovery failed brute-force identity check."
  )
}

cat("V11 forward-backward smoothing self-check: PASS\n")

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

  ks <- disp_index$state_k[di]
  age_k <- ks - 1L
  b_col <- paste0("b_badger[", i, "]")

  rr <- forward_one_badger(
    d2 = d2,
    sex_i = fit$sex_data[i],
    age2_i = fit$age_2[i, age_k],
    age35_i = fit$age_3_5[i, age_k],
    age6_i = fit$age_6plus[i, age_k],
    ageunk_i = fit$age_unknown[i, age_k],
    b_col = b_col,
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
    age_from_years = vapply(
      seq_len(n()),
      function(rr) {
        fit$age_years_matrix[
          model_i[rr],
          state_k[rr] - 1L
        ]
      },
      integer(1)
    ),
    age_from_class = case_when(
      is.finite(age_from_years) & age_from_years <= 1L ~ "0-1",
      age_from_years == 2L ~ "2",
      age_from_years >= 3L & age_from_years <= 5L ~ "3-5",
      age_from_years >= 6L ~ "6+",
      TRUE ~ "Unknown"
    ),
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
    model = fit$model,
    source_chain = chain_file,
    chain_id = CHAIN_ID,
    ids = fit$ids,
    individual_ids = fit$individual_ids,
    sex_data = fit$sex_data,
    age_years_matrix = fit$age_years_matrix,
    age_2 = fit$age_2,
    age_3_5 = fit$age_3_5,
    age_6plus = fit$age_6plus,
    age_unknown = fit$age_unknown,
    years = fit$years,
    first = fit$first,
    K = fit$K,
    disp_index = disp_index,
    state_draws = state_draws,
    p_high_smoothed_chain = smooth_mean,
    p_high_ffbs_chain = ffbs_mean,
    state_summary = state_summary,
    draw_filter = list(
      min_raw_iter = MIN_RAW_ITER,
      state_suffix = STATE_SUFFIX,
      n_draws_used = nd
    )
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
