# =============================================================================
# WOODCHESTER V9 SPATIAL ARCHIVE — COMBINE, COMPACT AND AUDIT
#
# Run only after all three V9 spatial-archive chains have completed.
#
# Produces one coherent archive containing:
#   - 1,500 joint posterior activity-centre histories (Sx/Sy)
#   - matching 1,500 latent movement-state histories (disp)
#   - matching global parameter draws
#   - badger/year activity-centre index
#   - movement interval index
#
# It also checks:
#   - Rhat / ESS of the archive rerun's global parameters
#   - agreement of posterior high-mobility probabilities with accepted V9
#
# Accepted V9 remains the inferential reference. This object exists to support
# future spatial/group/network analyses.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(coda)
})

CHAIN_FILES <- sprintf(
  "results/RD_SCR_V9_SPATIAL_ARCHIVE_1932_CHAIN_%d.rds",
  1:3
)
ACCEPTED_MOVE <- "data/badger_movement_posterior_draws_1932_V9.rds"
OUT_FILE <- "data/badger_V9_spatial_activity_centre_archive_1500.rds"

for(f in c(CHAIN_FILES, ACCEPTED_MOVE)) {
  if(!file.exists(f)) stop("Missing required file: ", f)
}

dir.create("results/model_checks", recursive = TRUE, showWarnings = FALSE)
dir.create("data", recursive = TRUE, showWarnings = FALSE)

cat("\n============================================================\n")
cat("V9 SPATIAL ARCHIVE — COMBINE AND AUDIT\n")
cat("============================================================\n")

first_obj <- readRDS(CHAIN_FILES[1])

required <- c(
  "primary_global_samples", "spatial_samples", "spatial_disp_draws",
  "spatial_primary_rows", "spatial_thin", "ac_index",
  "disp_index", "ids", "individual_ids", "sex_data",
  "first", "K", "years"
)
miss <- setdiff(required, names(first_obj))
if(length(miss)) stop("Spatial chain object is missing: ", paste(miss, collapse = ", "))

ac_index <- as_tibble(first_obj$ac_index)
disp_index <- as_tibble(first_obj$disp_index)
ids <- first_obj$ids
individual_ids <- first_obj$individual_ids
sex_data <- first_obj$sex_data
years <- first_obj$years

if(anyDuplicated(ac_index[c("model_i", "state_k")]))
  stop("ac_index is not unique by model_i + state_k.")

cat("Badgers:", length(ids), "\n")
cat("Supported latent annual activity centres:", nrow(ac_index), "\n")
cat("Movement intervals:", nrow(disp_index), "\n")
cat("Spatial draws / chain:", nrow(first_obj$spatial_samples), "\n")
cat("Spatial thinning:", first_obj$spatial_thin, "\n")

# Free chain 1 now; each chain is reread sequentially below.
rm(first_obj)
gc()

global_chains <- vector("list", length(CHAIN_FILES))
spatial_global_list <- vector("list", length(CHAIN_FILES))
Sx_list <- vector("list", length(CHAIN_FILES))
Sy_list <- vector("list", length(CHAIN_FILES))
disp_list <- vector("list", length(CHAIN_FILES))
source_list <- vector("list", length(CHAIN_FILES))
alignment_list <- vector("list", length(CHAIN_FILES))

for(cc in seq_along(CHAIN_FILES)) {
  cat("\nReading archive chain ", cc, ": ", CHAIN_FILES[cc], "\n", sep = "")
  obj <- readRDS(CHAIN_FILES[cc])

  if(!identical(as.character(obj$ids), as.character(ids)))
    stop("Chain ", cc, " has different animal ordering.")
  if(!identical(as.character(obj$disp_index$node), as.character(disp_index$node)))
    stop("Chain ", cc, " has different movement interval ordering.")
  if(!identical(obj$ac_index$model_i, ac_index$model_i) ||
     !identical(obj$ac_index$state_k, ac_index$state_k))
    stop("Chain ", cc, " has different activity-centre index ordering.")

  G <- as.matrix(obj$primary_global_samples)
  SP <- as.matrix(obj$spatial_samples)
  DD <- as.matrix(obj$spatial_disp_draws)

  if(nrow(SP) != nrow(DD))
    stop("Chain ", cc, ": spatial S and disp draw counts differ.")
  if(ncol(DD) != nrow(disp_index))
    stop("Chain ", cc, ": spatial disp matrix does not match disp_index.")

  missing_x <- setdiff(ac_index$x_node, colnames(SP))
  missing_y <- setdiff(ac_index$y_node, colnames(SP))
  if(length(missing_x) || length(missing_y))
    stop("Chain ", cc, " lacks one or more supported S nodes.")

  spatial_global_cols <- setdiff(
    colnames(SP),
    c(ac_index$x_node, ac_index$y_node)
  )

  global_chains[[cc]] <- coda::as.mcmc(G)
  spatial_global_list[[cc]] <- SP[, spatial_global_cols, drop = FALSE]
  Sx_list[[cc]] <- SP[, ac_index$x_node, drop = FALSE]
  Sy_list[[cc]] <- SP[, ac_index$y_node, drop = FALSE]

  disp_list[[cc]] <- matrix(
    as.integer(DD),
    nrow = nrow(DD),
    ncol = ncol(DD),
    dimnames = list(NULL, disp_index$node)
  )

  source_list[[cc]] <- tibble(
    archive_draw_in_chain = seq_len(nrow(SP)),
    source_chain = cc,
    primary_retained_row = as.integer(obj$spatial_primary_rows),
    spatial_thin = as.integer(obj$spatial_thin)
  )

  alignment_list[[cc]] <- tibble(
    chain = cc,
    alignment_parameter = as.character(obj$spatial_alignment_parameter),
    alignment_max_error = as.numeric(obj$spatial_alignment_max_error),
    n_spatial_draws = nrow(SP),
    n_supported_activity_centres = nrow(ac_index)
  )

  rm(obj, G, SP, DD)
  gc()
}

# =============================================================================
# 1. GLOBAL-PARAMETER CONVERGENCE IN ARCHIVE RERUN
# =============================================================================

common_global <- Reduce(intersect, lapply(global_chains, colnames))
global_chains <- lapply(global_chains, function(x) x[, common_global, drop = FALSE])
global_mcmc <- do.call(coda::mcmc.list, lapply(global_chains, coda::as.mcmc))

gd <- coda::gelman.diag(
  global_mcmc,
  multivariate = FALSE,
  autoburnin = FALSE
)$psrf
ess <- coda::effectiveSize(global_mcmc)

global_diag <- tibble(
  parameter = rownames(gd),
  Rhat = gd[, "Point est."],
  Rhat_upper = gd[, "Upper C.I."],
  ESS = as.numeric(ess[rownames(gd)])
) %>%
  arrange(desc(Rhat))

key_parameters <- c(
  "logmove_male_local", "logmove_female_high", "beta_move_disp",
  "alpha_logmove", "beta_move_sex",
  "alpha_disp_init", "beta_disp_adult", "beta_disp_init_sex",
  "alpha_RD", "beta_RD_sex", "alpha_DD", "beta_DD_sex",
  "beta_sg", "beta_peripheral",
  "alpha_p", "beta_p_sex", "alpha_logsigma", "beta_sigma_sex"
)

key_diag <- global_diag %>% filter(parameter %in% key_parameters)

write_csv(
  global_diag,
  "results/model_checks/V9_SPATIAL_ARCHIVE_global_convergence.csv"
)

cat("\nKey archive-rerun convergence diagnostics:\n")
print(key_diag, n = Inf, width = Inf)

# =============================================================================
# 2. COMBINE COHERENT SPATIAL DRAWS
# =============================================================================

Sx_draws <- do.call(rbind, Sx_list)
Sy_draws <- do.call(rbind, Sy_list)
disp_draws <- do.call(rbind, disp_list)
spatial_global_draws <- do.call(rbind, spatial_global_list)

draw_source <- bind_rows(source_list) %>%
  mutate(archive_draw = row_number(), .before = 1)

if(nrow(Sx_draws) != 1500L) {
  warning("Expected 1,500 spatial draws across three production chains; found ",
          nrow(Sx_draws), ".")
}

if(nrow(Sx_draws) != nrow(Sy_draws) ||
   nrow(Sx_draws) != nrow(disp_draws) ||
   nrow(Sx_draws) != nrow(spatial_global_draws))
  stop("Combined spatial S/disp/global draws do not have matching row counts.")

# =============================================================================
# 3. COMPARE ARCHIVE MOVEMENT STATES WITH ACCEPTED V9
# =============================================================================

accepted <- readRDS(ACCEPTED_MOVE)

if(!identical(as.character(accepted$disp_index$node), as.character(disp_index$node)))
  stop("Accepted V9 and spatial archive have different movement interval ordering.")

p_high_archive <- colMeans(disp_draws)
p_high_accepted <- as.numeric(accepted$disp_summary$p_high_mobility)

state_agreement <- tibble(
  n_intervals = length(p_high_archive),
  correlation = cor(p_high_archive, p_high_accepted),
  mean_abs_difference = mean(abs(p_high_archive - p_high_accepted)),
  median_abs_difference = median(abs(p_high_archive - p_high_accepted)),
  n_absdiff_gt_0.10 = sum(abs(p_high_archive - p_high_accepted) > 0.10),
  n_absdiff_gt_0.20 = sum(abs(p_high_archive - p_high_accepted) > 0.20),
  hard_agreement_50 = mean((p_high_archive >= 0.5) == (p_high_accepted >= 0.5)),
  n_hard_disagree_50 = sum((p_high_archive >= 0.5) != (p_high_accepted >= 0.5))
)

state_interval <- disp_index %>%
  select(any_of(c(
    "model_i", "individual_id", "tattoo", "from_year", "to_year", "node"
  ))) %>%
  mutate(
    p_high_accepted = p_high_accepted,
    p_high_spatial_archive = p_high_archive,
    difference = p_high_spatial_archive - p_high_accepted,
    abs_difference = abs(difference)
  )

write_csv(
  state_agreement,
  "results/model_checks/V9_SPATIAL_ARCHIVE_state_agreement.csv"
)
write_csv(
  state_interval,
  "results/model_checks/V9_SPATIAL_ARCHIVE_state_agreement_by_interval.csv"
)
write_csv(
  bind_rows(alignment_list),
  "results/model_checks/V9_SPATIAL_ARCHIVE_monitor_alignment.csv"
)

cat("\nAgreement with accepted V9 movement-state posterior:\n")
print(state_agreement, width = Inf)

# =============================================================================
# 4. SAVE COMPACT COHERENT ARCHIVE
# =============================================================================

saveRDS(
  list(
    model = "V9 spatial archive: accepted V9 model rerun with thinned latent activity centres",
    Sx_draws = Sx_draws,
    Sy_draws = Sy_draws,
    movement_draws = disp_draws,
    global_draws = spatial_global_draws,
    ac_index = ac_index,
    disp_index = disp_index,
    draw_source = draw_source,
    ids = ids,
    individual_ids = individual_ids,
    sex_data = sex_data,
    years = years,
    accepted_movement_reference = ACCEPTED_MOVE,
    state_agreement = state_agreement,
    alignment_audit = bind_rows(alignment_list),
    settings = list(
      n_chains = length(CHAIN_FILES),
      n_joint_spatial_draws = nrow(Sx_draws),
      activity_centres_per_draw = ncol(Sx_draws),
      movement_intervals_per_draw = ncol(disp_draws),
      supported_history = "activity centres retained only for first:K; no extrapolation after final observed live year",
      important = "Each archive row is one coherent joint S + movement-state + global-parameter posterior draw from the same MCMC iteration."
    )
  ),
  OUT_FILE,
  compress = "gzip"
)

cat("\n============================================================\n")
cat("V9 SPATIAL ARCHIVE COMPLETE\n")
cat("============================================================\n")
cat("Saved:", OUT_FILE, "\n")
cat("Joint spatial draws:", nrow(Sx_draws), "\n")
cat("Activity centres / draw:", ncol(Sx_draws), "\n")
cat("Movement states / draw:", ncol(disp_draws), "\n")
cat("\nAccepted V9 remains the inferential reference; review convergence and state-agreement tables before using S downstream.\n")
