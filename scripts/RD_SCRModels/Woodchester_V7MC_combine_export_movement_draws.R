# =============================================================================
# WOODCHESTER V7M-C - MEMORY-SAFE COMBINE / MOVEMENT EXPORT v3
#
# Why v3?
# The original chain files contain a very large monitored `disp` array.  Only
# 5,667 modeled movement-state cells are scientifically required, plus ~29
# global parameters.  This script NEVER converts the full ~58k-column chain to
# a matrix and NEVER treats all non-matched columns as global parameters.
#
# It reads ONE large chain at a time, extracts:
#   1. exact requested global parameters,
#   2. the exact 5,667 modeled disp[i,k] cells,
#   3. 500 coherent joint movement-state draws per chain,
#   4. posterior P(high mobility) from every retained draw.
#
# Then it frees the large chain object before reading the next chain.
# =============================================================================

library(tidyverse)
library(coda)

CHAIN_FILES <- sprintf(
  "results/RD_SCR_V7MC_CENTERED_MOVEMENT_ONLY_1285_CHAIN_%d.rds",
  1:3
)

EXPORT_PER_CHAIN <- 500L
EXPORT_SEED <- 71023L
ROW_CHUNK <- 250L

combined_file <- "results/RD_SCR_V7MC_CENTERED_MOVEMENT_ONLY_1285_COMBINED.rds"
movement_export_file <- "data/badger_movement_posterior_draws_1285_centered.rds"

missing <- CHAIN_FILES[!file.exists(CHAIN_FILES)]
if(length(missing)) stop("Missing chain file(s):\n",paste(missing,collapse="\n"))

dir.create("data",showWarnings=FALSE)
dir.create("results",showWarnings=FALSE)

canon <- function(x) gsub("\\s+","",x)

cat("\n============================================================\n")
cat("V7M-C MEMORY-SAFE COMBINE v3\n")
cat("============================================================\n")

set.seed(EXPORT_SEED)

global_chains <- vector("list",length(CHAIN_FILES))
selected_disp <- vector("list",length(CHAIN_FILES))
selected_source <- vector("list",length(CHAIN_FILES))
runtimes <- vector("list",length(CHAIN_FILES))
n_per_chain <- integer(length(CHAIN_FILES))

# Metadata initialized from chain 1 only.
ids <- individual_ids <- sex_data <- entry_group <- first <- K <- years <- NULL
disp_index <- NULL
disp_nodes <- NULL
core_requested <- NULL
core_exact <- NULL
disp_sum <- NULL
disp_n <- 0L

for(cc in seq_along(CHAIN_FILES)){
  
  cat("\n------------------------------------------------------------\n")
  cat("READING CHAIN",cc,"\n")
  cat("------------------------------------------------------------\n")
  
  gc()
  obj <- readRDS(CHAIN_FILES[cc])
  sm <- obj$samples
  
  cn <- colnames(sm)
  if(is.null(cn)) stop("Chain ",cc," samples have no column names.")
  n <- nrow(sm)
  n_per_chain[cc] <- n
  
  cat("Retained draws:",n,"\n")
  cat("Saved columns in raw chain:",length(cn),"\n")
  
  if(cc==1L){
    ids <- obj$ids
    individual_ids <- obj$individual_ids
    sex_data <- obj$sex_data
    entry_group <- obj$entry_group
    first <- obj$first
    K <- obj$K
    years <- obj$years
    disp_index <- obj$disp_index
    disp_nodes <- disp_index$node
    core_requested <- obj$core_monitors
    
    # Match globals by BASE variable name, never by "everything not disp".
    cn_canon <- canon(cn)
    base_name <- sub("\\[.*$","",cn_canon)
    core_pos <- which(base_name %in% core_requested)
    core_exact <- cn[core_pos]
    
    # Match only the 5,667 scientifically modeled movement-state cells.
    disp_pos <- match(canon(disp_nodes),cn_canon)
    
    if(length(core_pos)==0L)
      stop("No global parameters matched.")
    if(anyNA(disp_pos)){
      bad <- which(is.na(disp_pos))
      stop("Could not match ",length(bad)," modeled disp nodes. First missing: ",
           disp_nodes[bad[1]])
    }
    if(anyDuplicated(disp_pos))
      stop("Duplicate raw-chain matches for modeled disp nodes.")
    
    cat("Requested global monitor families:",length(core_requested),"\n")
    cat("Exact global columns matched:",length(core_exact),"\n")
    cat("Modeled movement-state cells matched:",length(disp_pos),"\n")
    cat("Raw columns intentionally ignored:",
        length(cn)-length(core_pos)-length(disp_pos),"\n")
    
    disp_sum <- numeric(length(disp_pos))
    
  } else {
    
    if(!identical(as.character(obj$ids),as.character(ids)))
      stop("Chain ",cc," has different animal ordering.")
    if(!identical(obj$disp_index$node,disp_nodes))
      stop("Chain ",cc," has different disp_index ordering.")
    
    cn_canon <- canon(cn)
    base_name <- sub("\\[.*$","",cn_canon)
    core_pos <- match(canon(core_exact),cn_canon)
    disp_pos <- match(canon(disp_nodes),cn_canon)
    
    if(anyNA(core_pos)) stop("Chain ",cc," is missing global columns.")
    if(anyNA(disp_pos)) stop("Chain ",cc," is missing modeled disp nodes.")
  }
  
  # ---- globals: tiny ---------------------------------------------------------
  global_chains[[cc]] <- coda::as.mcmc(
    as.matrix(sm[,core_pos,drop=FALSE])
  )
  
  # ---- P(high): process modeled disp nodes in small ROW chunks ---------------
  starts <- seq.int(1L,n,by=ROW_CHUNK)
  
  for(ss in starts){
    ee <- min(n,ss+ROW_CHUNK-1L)
    block <- as.matrix(sm[ss:ee,disp_pos,drop=FALSE])
    disp_sum <- disp_sum+colSums(block)
    rm(block)
  }
  disp_n <- disp_n+n
  
  # ---- coherent joint movement-state draws ----------------------------------
  take_n <- min(EXPORT_PER_CHAIN,n)
  take <- sort(sample.int(n,take_n,replace=FALSE))
  
  dsel <- as.matrix(sm[take,disp_pos,drop=FALSE])
  selected_disp[[cc]] <- matrix(
    as.integer(dsel),
    nrow=nrow(dsel),
    ncol=ncol(dsel),
    dimnames=list(NULL,disp_nodes)
  )
  
  selected_source[[cc]] <- tibble(
    source_chain=cc,
    source_iteration_row=take
  )
  
  runtimes[[cc]] <- obj$runtime
  
  cat("Extracted",take_n,"coherent movement histories from chain",cc,"\n")
  
  # Critical: free the huge raw chain before reading the next one.
  rm(dsel,sm,obj,cn,cn_canon,base_name,core_pos,disp_pos)
  gc()
  cat("Chain",cc,"released from memory.\n")
}

cat("\n============================================================\n")
cat("GLOBAL-PARAMETER DIAGNOSTICS\n")
cat("============================================================\n")

# Classic Gelman-Rubin R-hat, one parameter at a time.
classic_rhat <- function(xs){
  m <- length(xs)
  n <- min(vapply(xs,length,integer(1)))
  xs <- lapply(xs,function(x) as.numeric(x[seq_len(n)]))
  chain_means <- vapply(xs,mean,numeric(1))
  chain_vars <- vapply(xs,var,numeric(1))
  W <- mean(chain_vars)
  B <- n*var(chain_means)
  if(!is.finite(W) || W<=0) return(NA_real_)
  var_hat <- ((n-1)/n)*W+B/n
  sqrt(var_hat/W)
}

diag_rows <- vector("list",length(core_exact))

for(pp in seq_along(core_exact)){
  par <- core_exact[pp]
  xs <- lapply(global_chains,function(ch) as.matrix(ch)[,par])
  
  rhat <- classic_rhat(xs)
  
  one <- coda::mcmc.list(
    lapply(xs,function(x)
      coda::as.mcmc(matrix(x,ncol=1,dimnames=list(NULL,par))))
  )
  
  ess <- tryCatch(
    as.numeric(coda::effectiveSize(one)[1]),
    error=function(e) NA_real_
  )
  
  diag_rows[[pp]] <- tibble(
    parameter=par,
    Rhat=rhat,
    ESS=ess,
    chain1_mean=mean(xs[[1]]),
    chain2_mean=mean(xs[[2]]),
    chain3_mean=mean(xs[[3]])
  )
}

diag_table <- bind_rows(diag_rows) %>% arrange(desc(Rhat))

print(diag_table,n=Inf,width=Inf)

cat("\nDiagnostic summary:\n")
print(
  diag_table %>%
    summarise(
      n_parameters=n(),
      max_Rhat=max(Rhat,na.rm=TRUE),
      n_Rhat_gt_1_01=sum(Rhat>1.01,na.rm=TRUE),
      n_Rhat_gt_1_05=sum(Rhat>1.05,na.rm=TRUE),
      min_ESS=min(ESS,na.rm=TRUE),
      median_ESS=median(ESS,na.rm=TRUE)
    )
)

# ---- movement posterior ------------------------------------------------------
movement_draws <- do.call(rbind,selected_disp)
storage.mode(movement_draws) <- "integer"

draw_source <- bind_rows(selected_source) %>%
  mutate(export_draw=row_number()) %>%
  select(export_draw,source_chain,source_iteration_row)

p_high <- disp_sum/disp_n

disp_summary <- disp_index %>%
  mutate(
    p_high_mobility=p_high,
    state_call=case_when(
      p_high_mobility<.20 ~ "strong_local",
      p_high_mobility>=.80 ~ "strong_high_mobility",
      TRUE ~ "uncertain"
    )
  )

cat("\n============================================================\n")
cat("MOVEMENT-STATE POSTERIOR\n")
cat("============================================================\n")

movement_summary <- disp_summary %>%
  summarise(
    n_intervals=n(),
    mean_p_high=mean(p_high_mobility),
    median_p_high=median(p_high_mobility),
    n_p50=sum(p_high_mobility>=.50),
    n_p80=sum(p_high_mobility>=.80),
    n_p95=sum(p_high_mobility>=.95)
  )

print(movement_summary,width=Inf)

cat("\nExport matrix:",nrow(movement_draws),"joint draws x",
    ncol(movement_draws),"modeled movement intervals\n")

# ---- save --------------------------------------------------------------------
saveRDS(
  list(
    global_samples=coda::mcmc.list(global_chains),
    diagnostics=diag_table,
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
      model="V7MC_centered_movement_only_combined",
      n_chains=length(CHAIN_FILES),
      retained_draws_per_chain=n_per_chain,
      total_retained_draws=sum(n_per_chain),
      combine_version="memory_safe_v3"
    )
  ),
  combined_file
)

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
      model_source="V7MC_centered_movement_only_1285",
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
cat("V7M-C COMBINE COMPLETE\n")
cat("============================================================\n")
cat("Saved combined diagnostics:",combined_file,"\n")
cat("Saved modular movement draws:",movement_export_file,"\n")
