# =============================================================================
# WOODCHESTER V7M - COMBINE MOVEMENT-ONLY CHAINS + EXPORT JOINT DISP DRAWS
#
# Run only after chains 1, 2 and 3 have finished.
#
# Outputs:
#   results/RD_SCR_V7M_MOVEMENT_ONLY_1285_COMBINED.rds
#   data/badger_movement_posterior_draws_1285.rds
#
# The movement export keeps coherent JOINT posterior movement-state histories.
# A row is one posterior iteration across every modeled movement interval.
# This is the object used by the fast modular V7a-M / V7b-M analyses.
# =============================================================================

library(tidyverse)
library(coda)

CHAIN_FILES <- sprintf(
  "results/RD_SCR_V7M_MOVEMENT_ONLY_1285_CHAIN_%d.rds",
  1:3
)

N_EXPORT_DRAWS <- 1500L
EXPORT_SEED <- 71023L

combined_file <- "results/RD_SCR_V7M_MOVEMENT_ONLY_1285_COMBINED.rds"
movement_export_file <- "data/badger_movement_posterior_draws_1285.rds"

missing <- CHAIN_FILES[!file.exists(CHAIN_FILES)]
if(length(missing))
  stop("Missing chain file(s):\n",paste(missing,collapse="\n"))

dir.create("data",showWarnings=FALSE)
dir.create("results",showWarnings=FALSE)

cat("\n============================================================\n")
cat("COMBINING V7M MOVEMENT-ONLY CHAINS\n")
cat("============================================================\n")

# ---- first object defines metadata -------------------------------------------
first_obj <- readRDS(CHAIN_FILES[1])
ids <- first_obj$ids
individual_ids <- first_obj$individual_ids
sex_data <- first_obj$sex_data
entry_group <- first_obj$entry_group
first <- first_obj$first
K <- first_obj$K
years <- first_obj$years
disp_index <- first_obj$disp_index
disp_nodes <- disp_index$node
core_requested <- first_obj$core_monitors

# Use exact column names present in chain 1. This safely expands vector monitors
# such as beta_season_raw[1].
m1_names <- colnames(as.matrix(first_obj$samples))

core_exact <- setdiff(m1_names,disp_nodes)

cat("Badgers:",length(ids),"\n")
cat("Movement intervals:",nrow(disp_index),"\n")
cat("Exact global/core columns:",length(core_exact),"\n")

# Number of retained draws per chain.
n_per_chain <- vapply(CHAIN_FILES,function(f){
  obj <- readRDS(f)
  nrow(as.matrix(obj$samples))
},integer(1))

cat("Retained draws per chain:",paste(n_per_chain,collapse=", "),"\n")
cat("Total retained posterior draws:",sum(n_per_chain),"\n")

# Balanced export across chains.
base_n <- N_EXPORT_DRAWS %/% length(CHAIN_FILES)
extra <- N_EXPORT_DRAWS %% length(CHAIN_FILES)
export_n <- rep(base_n,length(CHAIN_FILES))
if(extra>0) export_n[seq_len(extra)] <- export_n[seq_len(extra)]+1L
export_n <- pmin(export_n,n_per_chain)
N_EXPORT_ACTUAL <- sum(export_n)

cat("Joint movement draws to export:",N_EXPORT_ACTUAL,"\n")

set.seed(EXPORT_SEED)

global_chains <- vector("list",length(CHAIN_FILES))
disp_selected <- vector("list",length(CHAIN_FILES))
selected_index <- vector("list",length(CHAIN_FILES))
disp_sum <- numeric(length(disp_nodes))
disp_n <- 0L
runtimes <- vector("list",length(CHAIN_FILES))

# ---- read sequentially to avoid holding three huge full matrices -------------
for(cc in seq_along(CHAIN_FILES)){

  cat("\nReading chain",cc,":",CHAIN_FILES[cc],"\n")
  obj <- readRDS(CHAIN_FILES[cc])

  if(!identical(as.character(obj$ids),as.character(ids)))
    stop("Chain ",cc," has different animal ordering.")
  if(!identical(obj$disp_index$node,disp_nodes))
    stop("Chain ",cc," has different movement-state node ordering.")

  m <- as.matrix(obj$samples)

  if(!all(core_exact %in% colnames(m)))
    stop("Chain ",cc," is missing one or more global parameter columns.")
  if(!all(disp_nodes %in% colnames(m)))
    stop("Chain ",cc," is missing one or more disp nodes.")

  global_chains[[cc]] <- coda::as.mcmc(m[,core_exact,drop=FALSE])

  # Exact posterior movement-state probabilities using every retained draw.
  disp_block <- m[,disp_nodes,drop=FALSE]
  disp_sum <- disp_sum+colSums(disp_block)
  disp_n <- disp_n+nrow(disp_block)

  # Preserve coherent whole-model draws for downstream modular analyses.
  take <- sort(sample.int(nrow(m),export_n[cc],replace=FALSE))
  disp_selected[[cc]] <- matrix(
    as.integer(disp_block[take,,drop=FALSE]),
    nrow=length(take),
    ncol=length(disp_nodes),
    dimnames=list(NULL,disp_nodes)
  )

  selected_index[[cc]] <- tibble(
    export_row=seq_len(length(take)),
    source_chain=cc,
    source_iteration_row=take
  )

  runtimes[[cc]] <- obj$runtime

  rm(m,disp_block,obj)
  gc()
}

global_samples <- coda::mcmc.list(global_chains)

# ---- convergence diagnostics ------------------------------------------------
cat("\n============================================================\n")
cat("GLOBAL-PARAMETER CONVERGENCE\n")
cat("============================================================\n")

gelman <- coda::gelman.diag(
  global_samples,
  multivariate=FALSE,
  autoburnin=FALSE
)

ess <- coda::effectiveSize(global_samples)

gelman_table <- as_tibble(
  gelman$psrf,
  rownames="parameter"
) %>%
  rename(Rhat=`Point est.`,Rhat_upper=`Upper C.I.`) %>%
  left_join(
    tibble(parameter=names(ess),ESS=as.numeric(ess)),
    by="parameter"
  ) %>%
  arrange(desc(Rhat))

print(gelman_table,n=Inf,width=Inf)

# ---- movement-state export ---------------------------------------------------
movement_draws <- do.call(rbind,disp_selected)
storage.mode(movement_draws) <- "integer"

draw_source <- bind_rows(lapply(seq_along(selected_index),function(cc){
  selected_index[[cc]] %>%
    mutate(source_chain=cc)
})) %>%
  mutate(export_draw=row_number()) %>%
  select(export_draw,source_chain,source_iteration_row)

p_high <- disp_sum/disp_n

disp_summary <- disp_index %>%
  mutate(
    p_high_mobility=p_high,
    state_call=case_when(
      p_high_mobility<.20 ~ "strong_local",
      p_high_mobility>.80 ~ "strong_high_mobility",
      TRUE ~ "uncertain"
    )
  )

cat("\nMovement posterior occupancy:\n")
print(
  disp_summary %>%
    summarise(
      n_intervals=n(),
      mean_p_high=mean(p_high_mobility),
      median_p_high=median(p_high_mobility),
      n_p50=sum(p_high_mobility>=.50),
      n_p80=sum(p_high_mobility>=.80)
    )
)

cat("\nExport matrix:",nrow(movement_draws),"joint draws x",
    ncol(movement_draws),"movement intervals\n")

# ---- combined archive --------------------------------------------------------
saveRDS(
  list(
    global_samples=global_samples,
    gelman=gelman_table,
    ids=ids,
    individual_ids=individual_ids,
    sex_data=sex_data,
    entry_group=entry_group,
    first=first,
    K=K,
    years=years,
    disp_index=disp_index,
    disp_summary=disp_summary,
    runtimes=runtimes,
    chain_files=CHAIN_FILES,
    settings=list(
      model="V7M_movement_only_combined",
      n_chains=length(CHAIN_FILES),
      retained_draws_per_chain=n_per_chain,
      total_retained_draws=sum(n_per_chain)
    )
  ),
  combined_file
)

# ---- compact downstream object ----------------------------------------------
saveRDS(
  list(
    movement_draws=movement_draws,
    draw_source=draw_source,
    disp_index=disp_index,
    disp_summary=disp_summary,
    ids=ids,
    individual_ids=individual_ids,
    sex_data=sex_data,
    entry_group=entry_group,
    years=years,
    settings=list(
      model_source="V7M_movement_only_1285",
      representation="joint binary posterior movement-state draws",
      n_export_draws=nrow(movement_draws),
      n_intervals=ncol(movement_draws),
      export_seed=EXPORT_SEED,
      important="Do not threshold posterior means; sample coherent movement_draw rows."
    )
  ),
  movement_export_file,
  compress="xz"
)

cat("\n============================================================\n")
cat("V7M COMBINATION COMPLETE\n")
cat("============================================================\n")
cat("Saved combined diagnostics:",combined_file,"\n")
cat("Saved modular movement draws:",movement_export_file,"\n")
