# =============================================================================
# V7MC-MHMM v6 FINAL30K -> COHERENT MOVEMENT-HISTORY EXPORT
# =============================================================================
library(tidyverse)

CHAIN_FILES <- sprintf(
  "results/RD_SCR_V7MCMHMMv6_PAIR_AC_1285_CHAIN_%d_FINAL30K.rds",1:3
)
OUT_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
N_PER_CHAIN <- 500L
SEED <- 7092026L

missing <- CHAIN_FILES[!file.exists(CHAIN_FILES)]
if(length(missing)) stop("Missing FINAL30K chain file(s):\n",paste(missing,collapse="\n"))

ilogit <- function(x) 1/(1+exp(-x))
logsum2 <- function(a,b){m<-max(a,b);m+log(exp(a-m)+exp(b-m))}
canon <- function(x) gsub("\\s+","",x)

ffbs_sample <- function(lr,p_init,p_RD,p_DD){
  Tn <- length(lr)
  if(Tn<1L) return(integer(0))
  e <- 1e-12
  p_init <- min(1-e,max(e,p_init))
  p_RD <- min(1-e,max(e,p_RD))
  p_DD <- min(1-e,max(e,p_DD))

  a0 <- a1 <- numeric(Tn)
  x0 <- log1p(-p_init)
  x1 <- log(p_init)+lr[1]
  z <- logsum2(x0,x1)
  a0[1] <- x0-z
  a1[1] <- x1-z

  if(Tn>1L){
    for(t in 2:Tn){
      q0 <- logsum2(a0[t-1]+log1p(-p_RD),a1[t-1]+log1p(-p_DD))
      q1 <- logsum2(a0[t-1]+log(p_RD),a1[t-1]+log(p_DD))
      z <- logsum2(q0,q1+lr[t])
      a0[t] <- q0-z
      a1[t] <- q1+lr[t]-z
    }
  }

  state <- integer(Tn)
  state[Tn] <- rbinom(1,1,exp(a1[Tn]))

  if(Tn>1L){
    for(t in (Tn-1L):1L){
      if(state[t+1L]==0L){
        l0 <- a0[t]+log1p(-p_RD)
        l1 <- a1[t]+log1p(-p_DD)
      }else{
        l0 <- a0[t]+log(p_RD)
        l1 <- a1[t]+log(p_DD)
      }
      z <- logsum2(l0,l1)
      state[t] <- rbinom(1,1,exp(l1-z))
    }
  }
  state
}

set.seed(SEED)
state_list <- vector("list",3)
global_list <- vector("list",3)
draw_map <- vector("list",3)

for(cc in 1:3){
  cat("\nReading FINAL30K chain",cc,"\n")
  obj <- readRDS(CHAIN_FILES[cc])
  sm <- as.matrix(obj$samples)
  cn <- colnames(sm)
  ccn <- canon(cn)

  if(cc==1L){
    ids <- obj$ids
    individual_ids <- obj$individual_ids
    sex <- as.integer(obj$sex_data)
    adult_entry <- as.integer(obj$adult_entry)
    first <- as.integer(obj$first)
    K <- as.integer(obj$K)
    years <- obj$years
    disp_index <- obj$disp_index
    nind <- length(ids)
    n_interval <- nrow(disp_index)
    rows_by_i <- split(seq_len(n_interval),disp_index$model_i)
    emit_names <- paste0("log_emit_ratio_save[",seq_len(n_interval),"]")
    hmm_names <- c(
      "alpha_disp_init","beta_disp_adult","beta_disp_init_sex",
      "alpha_RD","beta_RD_sex","alpha_DD","beta_DD_sex"
    )
  }else{
    if(!identical(as.character(obj$ids),as.character(ids)))
      stop("Animal ordering differs in chain ",cc)
    if(!identical(obj$disp_index$node,disp_index$node))
      stop("Movement interval ordering differs in chain ",cc)
  }

  emit_pos <- match(canon(emit_names),ccn)
  hmm_pos <- match(hmm_names,cn)
  if(anyNA(emit_pos)) stop("Emission-ratio columns missing in chain ",cc)
  if(anyNA(hmm_pos)) stop("HMM parameter columns missing in chain ",cc)

  nd <- nrow(sm)
  if(nd<N_PER_CHAIN) stop("Too few retained draws in chain ",cc)
  pick <- unique(round(seq(1,nd,length.out=N_PER_CHAIN)))
  if(length(pick)!=N_PER_CHAIN)
    pick <- sort(sample(seq_len(nd),N_PER_CHAIN,replace=FALSE))

  E <- sm[pick,emit_pos,drop=FALSE]
  G <- sm[pick,hmm_pos,drop=FALSE]
  colnames(G) <- hmm_names
  states <- matrix(0L,N_PER_CHAIN,n_interval)

  for(d in seq_len(N_PER_CHAIN)){
    for(i in seq_len(nind)){
      rr <- rows_by_i[[as.character(i)]]
      if(is.null(rr)||!length(rr)) next

      p_init <- ilogit(
        G[d,"alpha_disp_init"]+
        G[d,"beta_disp_adult"]*adult_entry[i]+
        G[d,"beta_disp_init_sex"]*sex[i]
      )
      p_RD <- ilogit(G[d,"alpha_RD"]+G[d,"beta_RD_sex"]*sex[i])
      p_DD <- ilogit(G[d,"alpha_DD"]+G[d,"beta_DD_sex"]*sex[i])

      states[d,rr] <- ffbs_sample(E[d,rr],p_init,p_RD,p_DD)
    }
    if(d%%50L==0L) cat("  FFBS draw",d,"/",N_PER_CHAIN,"\n")
  }

  state_list[[cc]] <- states
  global_list[[cc]] <- G
  draw_map[[cc]] <- tibble(
    movement_draw=(cc-1L)*N_PER_CHAIN+seq_len(N_PER_CHAIN),
    chain=cc,
    retained_draw=pick
  )

  rm(obj,sm,E,G,states)
  gc()
}

state_draws <- do.call(rbind,state_list)
global_hmm_draws <- do.call(rbind,global_list)
draw_index <- bind_rows(draw_map)

interval_summary <- disp_index %>%
  mutate(p_high=colMeans(state_draws),n_high=colSums(state_draws))

cat("\nMovement posterior histories:",nrow(state_draws),"\n")
cat("Movement intervals:",ncol(state_draws),"\n")
cat("Mean P(high):",mean(interval_summary$p_high),"\n")
cat("P(high)>=0.50:",sum(interval_summary$p_high>=.50),"\n")
cat("P(high)>=0.80:",sum(interval_summary$p_high>=.80),"\n")
cat("P(high)>=0.95:",sum(interval_summary$p_high>=.95),"\n")

dir.create(dirname(OUT_FILE),showWarnings=FALSE,recursive=TRUE)
saveRDS(
  list(
    model="V7MCMHMMv6_FINAL30K",
    state_code=c(local=0L,high_mobility=1L),
    state_draws=state_draws,
    draw_index=draw_index,
    global_hmm_draws=global_hmm_draws,
    interval_index=disp_index,
    interval_summary=interval_summary,
    ids=ids,
    individual_ids=individual_ids,
    sex=sex,
    adult_entry=adult_entry,
    first=first,
    K=K,
    years=years,
    chain_files=CHAIN_FILES,
    settings=list(
      n_per_chain=N_PER_CHAIN,
      total_draws=3L*N_PER_CHAIN,
      seed=SEED,
      method="one coherent FFBS history per selected movement posterior draw"
    )
  ),
  OUT_FILE
)
cat("Saved:",OUT_FILE,"\n")
