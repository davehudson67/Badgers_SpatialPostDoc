# =============================================================================
# V10B COLLAPSED-HMM: POST-AF-SLICE-ADAPTATION DIAGNOSTIC
#
# PURPOSE
#   Diagnose stationarity and effective sample size using only retained draws
#   whose underlying raw MCMC iteration occurs AFTER AF_slice factor adaptation
#   has ended.
#
#   NIMBLE's AF_slice default sliceAdaptFactorMaxIter is 15000. If burn-in is
#   shorter than that, ordinary posterior summaries can contain retained draws
#   from the adaptation period. This script removes those draws before
#   calculating Rhat/ESS and temporal segment summaries.
#
# ENVIRONMENT
#   FILE_STEM      result stem (required)
#   MAX_BADGERS    population size (default 300)
#   AF_ADAPT_MAX   raw MCMC iteration at which AF factor adaptation stops
#                  (default 15000; match the sampler control used in fitting)
#   N_SEGMENTS     temporal segments within post-adaptation tail (default 4)
# =============================================================================

library(tidyverse)
library(coda)

FILE_STEM <- Sys.getenv("FILE_STEM", unset = "")
if (!nzchar(FILE_STEM)) stop("FILE_STEM is required.")

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "300"))
AF_ADAPT_MAX <- as.integer(Sys.getenv("AF_ADAPT_MAX", unset = "15000"))
N_SEGMENTS <- as.integer(Sys.getenv("N_SEGMENTS", unset = "4"))

if (!is.finite(MAX_BADGERS) || MAX_BADGERS < 2L) {
  stop("MAX_BADGERS must be >= 2.")
}
if (!is.finite(AF_ADAPT_MAX) || AF_ADAPT_MAX < 0L) {
  stop("AF_ADAPT_MAX must be >= 0.")
}
if (!is.finite(N_SEGMENTS) || N_SEGMENTS < 2L) {
  stop("N_SEGMENTS must be >= 2.")
}

files <- file.path(
  "results",
  paste0(
    FILE_STEM,
    "_",
    MAX_BADGERS,
    "_CHAIN",
    1:3,
    ".rds"
  )
)

missing <- files[!file.exists(files)]
if (length(missing)) {
  stop("Missing chain file(s):\n", paste(missing, collapse = "\n"))
}

fits <- lapply(files, readRDS)

extract_tail <- function(fit, chain_id) {

  m <- as.matrix(fit$samples)
  st <- fit$settings

  nburn <- as.integer(st$nburn)
  thin <- as.integer(st$thin)

  if (!is.finite(nburn) || !is.finite(thin) || thin < 1L) {
    stop("Invalid nburn/thin metadata in chain ", chain_id)
  }

  # runMCMC returns retained post-burn samples spaced by thin. The exact first
  # retained raw iteration can differ by at most one thinning interval across
  # implementations; using nburn + thin * sequence is conservative enough for
  # excluding the entire AF-factor adaptation window.
  raw_iteration <- nburn + thin * seq_len(nrow(m))

  keep <- raw_iteration > AF_ADAPT_MAX

  if (sum(keep) < 100L) {
    stop(
      "Too few post-adaptation draws in chain ", chain_id,
      ": ", sum(keep)
    )
  }

  list(
    chain = chain_id,
    mat = m[keep, , drop = FALSE],
    raw_iteration = raw_iteration[keep],
    n_total = nrow(m),
    n_tail = sum(keep),
    first_tail_raw = min(raw_iteration[keep]),
    last_tail_raw = max(raw_iteration[keep])
  )
}

tails <- Map(extract_tail, fits, 1:3)

cat("\n============================================================\n")
cat("V10B POST-AF-SLICE-ADAPTATION DIAGNOSTIC\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("File stem:", FILE_STEM, "\n")
cat("AF_slice factor adaptation cutoff:", AF_ADAPT_MAX, "\n\n")

tail_meta <- tibble(
  chain = 1:3,
  total_retained = vapply(tails, function(x) x$n_total, integer(1)),
  postadapt_retained = vapply(tails, function(x) x$n_tail, integer(1)),
  first_postadapt_raw = vapply(tails, function(x) x$first_tail_raw, integer(1)),
  last_raw = vapply(tails, function(x) x$last_tail_raw, integer(1))
)
print(tail_meta, n = Inf)

required <- c(
  "alpha_logmove",
  "beta_move_high",
  "rho",
  "omega",
  "mean_annual_move_female_local",
  "mean_annual_move_male_local",
  "mean_annual_move_female_high",
  "mean_annual_move_male_high"
)

for (cc in required) {
  if (!all(vapply(tails, function(x) cc %in% colnames(x$mat), logical(1)))) {
    stop("Required monitored column missing: ", cc)
  }
}

make_derived <- function(m) {
  cbind(
    alpha_logmove = m[, "alpha_logmove"],
    beta_move_high = m[, "beta_move_high"],
    rho = m[, "rho"],
    omega = m[, "omega"],
    female_local = m[, "mean_annual_move_female_local"],
    male_local = m[, "mean_annual_move_male_local"],
    female_high = m[, "mean_annual_move_female_high"],
    male_high = m[, "mean_annual_move_male_high"],
    log_female_local_sigma = m[, "alpha_logmove"],
    log_female_high_sigma =
      m[, "alpha_logmove"] + m[, "beta_move_high"],
    log_high_to_local_ratio = m[, "beta_move_high"]
  )
}

derived <- lapply(tails, function(x) make_derived(x$mat))
ml <- mcmc.list(lapply(derived, mcmc))

rhat <- gelman.diag(
  ml,
  autoburnin = FALSE,
  multivariate = FALSE
)$psrf[, 1]

ess <- effectiveSize(ml)

conv <- tibble(
  parameter = names(rhat),
  rhat = as.numeric(rhat),
  ess = as.numeric(ess)
) %>%
  arrange(desc(rhat))

cat("\n============================================================\n")
cat("POST-ADAPTATION RHAT / ESS\n")
cat("============================================================\n")
print(conv, n = Inf)

segment_one <- function(x, chain_id) {
  m <- make_derived(x$mat)
  n <- nrow(m)

  seg <- pmin(
    N_SEGMENTS,
    ceiling(seq_len(n) / (n / N_SEGMENTS))
  )

  bind_rows(
    lapply(
      seq_len(N_SEGMENTS),
      function(ss) {
        ii <- which(seg == ss)
        tibble(
          chain = chain_id,
          segment = paste0("T", ss),
          n = length(ii),
          raw_start = min(x$raw_iteration[ii]),
          raw_end = max(x$raw_iteration[ii]),
          alpha_logmove = mean(m[ii, "alpha_logmove"]),
          beta_move_high = mean(m[ii, "beta_move_high"]),
          female_local = mean(m[ii, "female_local"]),
          male_local = mean(m[ii, "male_local"]),
          female_high = mean(m[ii, "female_high"]),
          male_high = mean(m[ii, "male_high"]),
          rho = mean(m[ii, "rho"]),
          omega = mean(m[ii, "omega"])
        )
      }
    )
  )
}

segments <- bind_rows(Map(segment_one, tails, 1:3))

cat("\n============================================================\n")
cat("POST-ADAPTATION TEMPORAL SEGMENTS\n")
cat("============================================================\n")
print(segments, n = Inf, width = Inf)

trend <- segments %>%
  group_by(chain) %>%
  summarise(
    female_local_first = first(female_local),
    female_local_last = last(female_local),
    female_local_change = last(female_local) - first(female_local),
    female_high_first = first(female_high),
    female_high_last = last(female_high),
    female_high_change = last(female_high) - first(female_high),
    rho_first = first(rho),
    rho_last = last(rho),
    rho_change = last(rho) - first(rho),
    .groups = "drop"
  )

cat("\n============================================================\n")
cat("FIRST -> LAST POST-ADAPTATION SEGMENT CHANGE\n")
cat("============================================================\n")
print(trend, n = Inf, width = Inf)

# Within-chain iteration correlations provide a simple direction-of-drift
# diagnostic. They are not a formal stationarity test but are useful alongside
# segment means and ESS.
iteration_trends <- bind_rows(
  lapply(
    seq_along(tails),
    function(ch) {
      m <- make_derived(tails[[ch]]$mat)
      it <- tails[[ch]]$raw_iteration
      tibble(
        chain = ch,
        spearman_iter_female_local =
          cor(it, m[, "female_local"], method = "spearman"),
        spearman_iter_female_high =
          cor(it, m[, "female_high"], method = "spearman"),
        spearman_iter_rho =
          cor(it, m[, "rho"], method = "spearman"),
        spearman_iter_omega =
          cor(it, m[, "omega"], method = "spearman")
      )
    }
  )
)

cat("\n============================================================\n")
cat("POST-ADAPTATION ITERATION TREND CORRELATIONS\n")
cat("============================================================\n")
print(iteration_trends, n = Inf)

prefix <- file.path(
  "results",
  paste0(
    FILE_STEM,
    "_",
    MAX_BADGERS,
    "_postadapt"
  )
)

write_csv(conv, paste0(prefix, "_convergence.csv"))
write_csv(segments, paste0(prefix, "_segments.csv"))
write_csv(trend, paste0(prefix, "_trend.csv"))
write_csv(iteration_trends, paste0(prefix, "_iteration_correlations.csv"))

cat("\nSaved post-adaptation diagnostics with prefix:\n", prefix, "\n", sep = "")
cat("\nPOST-ADAPTATION DIAGNOSTIC COMPLETE\n")
