# =============================================================================
# WOODCHESTER V11 - REPEAT-MOVER POSTERIOR-PREDICTIVE CHECK
#
# PURPOSE
#   Test whether the V11 transition model reproduces the concentration of
#   repeated high-mobility events among individuals.
#
#   For each retained posterior draw:
#     * "posterior_state" metrics come from the exact FFBS movement-state path
#       conditional on the fitted movement/spatial data;
#     * "replicated" metrics come from a new latent state path simulated from
#       the V11 transition process using that draw's sex effects, chronological
#       age effects and individual badger propensity.
#
#   If replicated paths remain substantially less concentrated than posterior
#   state paths, the next movement refinement is to allow the individual
#   propensity to affect high->high persistence as well as local->high entry.
#
# ENVIRONMENT
#   FILE_STEM   default V11_RD_MULTILOC_IID_AGE_BADGERRE
#   MAX_BADGERS default 100
#   PPC_DRAWS   maximum draws used per chain (default 500)
#
# OUTPUT
#   results/<stem>_<N>_repeat_mover_ppc_draws.csv
#   results/<stem>_<N>_repeat_mover_ppc_summary.csv
# =============================================================================

library(tidyverse)

FILE_STEM <- Sys.getenv(
  "FILE_STEM",
  unset = "V11_RD_MULTILOC_IID_AGE_BADGERRE"
)
MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "100"))
PPC_DRAWS <- as.integer(Sys.getenv("PPC_DRAWS", unset = "500"))
CHAIN_IDS <- 1:3

if (!is.finite(PPC_DRAWS) || PPC_DRAWS < 50L) {
  stop("PPC_DRAWS must be at least 50.")
}

prefix <- file.path(
  "results",
  paste0(FILE_STEM, "_", MAX_BADGERS)
)

chain_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, ".rds")
state_files <- paste0(prefix, "_CHAIN", CHAIN_IDS, "_STATES.rds")

missing <- c(chain_files, state_files)[
  !file.exists(c(chain_files, state_files))
]
if (length(missing)) {
  stop("Missing V11 chain/state file(s):\n", paste(missing, collapse = "\n"))
}

max_true_run <- function(z) {
  rr <- rle(as.integer(z))
  if (!any(rr$values == 1L)) return(0L)
  max(rr$lengths[rr$values == 1L])
}

row_max_run <- function(zmat) {
  apply(zmat, 1, max_true_run)
}

gini_nonnegative <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x) & x >= 0]
  if (!length(x) || sum(x) == 0) return(0)
  x <- sort(x)
  n <- length(x)
  (2 * sum(seq_len(n) * x) / (n * sum(x))) - (n + 1) / n
}

top_share <- function(x, prop = 0.10) {
  x <- as.numeric(x)
  total <- sum(x)
  if (!is.finite(total) || total <= 0) return(0)
  k <- max(1L, ceiling(length(x) * prop))
  sum(sort(x, decreasing = TRUE)[seq_len(k)]) / total
}

metric_rows <- function(counts, max_run, chain, kind, draw_ids) {
  tibble(
    chain = chain,
    draw = draw_ids,
    kind = kind,
    total_high_events = rowSums(counts),
    n_animals_any_high = rowSums(counts >= 1L),
    n_animals_repeat_high = rowSums(counts >= 2L),
    prop_animals_repeat_high = rowMeans(counts >= 2L),
    max_high_count_one_badger = apply(counts, 1, max),
    max_consecutive_high_run = max_run,
    top10_share_high_events = apply(counts, 1, top_share),
    gini_high_events = apply(counts, 1, gini_nonnegative)
  )
}

simulate_chain <- function(chain_id) {
  fit <- readRDS(chain_files[chain_id])
  st <- readRDS(state_files[chain_id])

  if (!identical(
    fit$model,
    "V11_RD_SCR_MULTILOC_IID_AGE_BADGERRE_COLLAPSED_HMM"
  )) {
    stop("Chain ", chain_id, " is not a V11 fit.")
  }

  mm_all <- as.matrix(fit$samples)
  z_all <- st$state_draws

  if (nrow(mm_all) != nrow(z_all)) {
    stop(
      "Chain ", chain_id,
      ": posterior draw count differs between fit and state sidecar."
    )
  }

  nd_all <- nrow(mm_all)
  use_n <- min(PPC_DRAWS, nd_all)
  keep <- unique(as.integer(round(seq(1, nd_all, length.out = use_n))))

  mm <- mm_all[keep, , drop = FALSE]
  z_post <- z_all[keep, , drop = FALSE]
  nd <- nrow(mm)
  nind <- length(fit$ids)

  post_counts <- matrix(0L, nd, nind)
  rep_counts <- matrix(0L, nd, nind)
  post_maxrun <- integer(nd)
  rep_maxrun <- integer(nd)

  set.seed(91000L + chain_id)

  for (i in seq_len(nind)) {
    di <- which(fit$disp_index$model_i == i)
    if (!length(di)) next

    di <- di[order(fit$disp_index$state_k[di])]
    ks <- fit$disp_index$state_k[di]
    age_k <- ks - 1L
    Tn <- length(di)

    z_i_post <- z_post[, di, drop = FALSE]
    post_counts[, i] <- rowSums(z_i_post)
    post_maxrun <- pmax(post_maxrun, row_max_run(z_i_post))

    b_col <- paste0("b_badger[", i, "]")
    if (!b_col %in% colnames(mm)) {
      stop("Missing posterior mover effect: ", b_col)
    }

    age_eta <-
      outer(mm[, "beta_age_2"], fit$age_2[i, age_k]) +
      outer(mm[, "beta_age_3_5"], fit$age_3_5[i, age_k]) +
      outer(mm[, "beta_age_6plus"], fit$age_6plus[i, age_k]) +
      outer(mm[, "beta_age_unknown"], fit$age_unknown[i, age_k])

    b_i <- mm[, b_col]

    p_init <- plogis(
      mm[, "alpha_disp_init"] +
        mm[, "beta_disp_init_sex"] * fit$sex_data[i] +
        age_eta[, 1L] +
        b_i
    )

    base_RD <-
      mm[, "alpha_RD"] +
      mm[, "beta_RD_sex"] * fit$sex_data[i] +
      b_i

    p_RD <- plogis(
      matrix(base_RD, nrow = nd, ncol = Tn) +
        age_eta
    )

    p_DD <- plogis(
      mm[, "alpha_DD"] +
        mm[, "beta_DD_sex"] * fit$sex_data[i]
    )

    z_i_rep <- matrix(0L, nd, Tn)
    z_i_rep[, 1L] <- rbinom(nd, 1L, p_init)

    if (Tn > 1L) {
      for (tt in 2:Tn) {
        pp <- ifelse(
          z_i_rep[, tt - 1L] == 1L,
          p_DD,
          p_RD[, tt]
        )
        z_i_rep[, tt] <- rbinom(nd, 1L, pp)
      }
    }

    rep_counts[, i] <- rowSums(z_i_rep)
    rep_maxrun <- pmax(rep_maxrun, row_max_run(z_i_rep))
  }

  bind_rows(
    metric_rows(
      post_counts,
      post_maxrun,
      chain_id,
      "posterior_state",
      keep
    ),
    metric_rows(
      rep_counts,
      rep_maxrun,
      chain_id,
      "replicated",
      keep
    )
  )
}

ppc_draws <- bind_rows(lapply(CHAIN_IDS, simulate_chain))

metric_names <- c(
  "total_high_events",
  "n_animals_any_high",
  "n_animals_repeat_high",
  "prop_animals_repeat_high",
  "max_high_count_one_badger",
  "max_consecutive_high_run",
  "top10_share_high_events",
  "gini_high_events"
)

long <- ppc_draws %>%
  pivot_longer(
    cols = all_of(metric_names),
    names_to = "metric",
    values_to = "value"
  )

summary_by_kind <- long %>%
  group_by(metric, kind) %>%
  summarise(
    mean = mean(value),
    q025 = unname(quantile(value, 0.025)),
    median = median(value),
    q975 = unname(quantile(value, 0.975)),
    .groups = "drop"
  )

paired <- ppc_draws %>%
  select(chain, draw, kind, all_of(metric_names)) %>%
  pivot_longer(
    cols = all_of(metric_names),
    names_to = "metric",
    values_to = "value"
  ) %>%
  pivot_wider(
    names_from = kind,
    values_from = value
  )

ppc_tail <- paired %>%
  group_by(metric) %>%
  summarise(
    p_rep_ge_posterior = mean(replicated >= posterior_state),
    mean_rep_minus_posterior = mean(replicated - posterior_state),
    .groups = "drop"
  )

ppc_summary <- summary_by_kind %>%
  pivot_wider(
    names_from = kind,
    values_from = c(mean, q025, median, q975)
  ) %>%
  left_join(ppc_tail, by = "metric")

cat("\n============================================================\n")
cat("V11 REPEAT-MOVER POSTERIOR-PREDICTIVE CHECK\n")
cat("============================================================\n")
cat("Population:", MAX_BADGERS, "\n")
cat("Draws requested per chain:", PPC_DRAWS, "\n\n")
print(ppc_summary, n = Inf, width = Inf)

write_csv(
  ppc_draws,
  paste0(prefix, "_repeat_mover_ppc_draws.csv")
)

write_csv(
  ppc_summary,
  paste0(prefix, "_repeat_mover_ppc_summary.csv")
)

cat("\nInterpretation:\n")
cat(
  "If posterior-state mover concentration lies systematically above the ",
  "replicated distribution (small p_rep_ge_posterior), V11 still underpredicts ",
  "repeat/consecutive movement and the badger effect should be considered for ",
  "high-state persistence as well.\n",
  sep = ""
)
