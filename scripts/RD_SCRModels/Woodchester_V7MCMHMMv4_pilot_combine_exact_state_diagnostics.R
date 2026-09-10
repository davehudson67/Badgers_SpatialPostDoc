# =============================================================================
# V7MC-MHMM v4 PILOT COMBINE + EXACT POSTERIOR STATE AGREEMENT
#
# The MCMC marginalized local/high movement states.  Each retained draw saves:
#   - global initial/transition parameters
#   - log_emit_ratio_save[r] = log L(high) - log L(local)
#
# This script reconstructs exact smoothed P(high) for every interval for every
# retained MCMC draw using forward-backward recursions, then averages within
# chain.  Thus chain-agreement diagnostics do NOT add Monte Carlo noise from
# sampling latent histories.
# =============================================================================

library(tidyverse)
library(coda)

CHAIN_FILES <- sprintf(
  "results/RD_SCR_V7MCMHMMv4_PI_FIX_MARGINAL_HMM_1285_CHAIN_%d_PILOT_5K.rds",
  1:3
)

missing <- CHAIN_FILES[!file.exists(CHAIN_FILES)]
if(length(missing))
  stop("Missing pilot chain file(s):\n",paste(missing,collapse="\n"))

ilogit <- function(x) 1/(1+exp(-x))
logsum2 <- function(a,b){
  m <- max(a,b)
  m+log(exp(a-m)+exp(b-m))
}

# Exact two-state forward-backward smoother.
# State 0 = local, state 1 = high.
smooth_high <- function(lr,p_init,p_RD,p_DD){
  Tn <- length(lr)
  if(Tn<1L) return(numeric(0))

  eps <- 1e-12
  p_init <- min(1-eps,max(eps,p_init))
  p_RD <- min(1-eps,max(eps,p_RD))
  p_DD <- min(1-eps,max(eps,p_DD))

  la0 <- numeric(Tn)
  la1 <- numeric(Tn)

  x0 <- log1p(-p_init)
  x1 <- log(p_init)+lr[1]
  z <- logsum2(x0,x1)
  la0[1] <- x0-z
  la1[1] <- x1-z

  if(Tn>1L){
    for(t in 2:Tn){
      pred0 <- logsum2(
        la0[t-1]+log1p(-p_RD),
        la1[t-1]+log1p(-p_DD)
      )
      pred1 <- logsum2(
        la0[t-1]+log(p_RD),
        la1[t-1]+log(p_DD)
      )
      x0 <- pred0
      x1 <- pred1+lr[t]
      z <- logsum2(x0,x1)
      la0[t] <- x0-z
      la1[t] <- x1-z
    }
  }

  lb0 <- numeric(Tn)
  lb1 <- numeric(Tn)
  # final backward messages are zero on log scale

  if(Tn>1L){
    for(t in (Tn-1L):1L){
      b0 <- logsum2(
        log1p(-p_RD) + lb0[t+1],
        log(p_RD) + lr[t+1] + lb1[t+1]
      )
      b1 <- logsum2(
        log1p(-p_DD) + lb0[t+1],
        log(p_DD) + lr[t+1] + lb1[t+1]
      )
      # normalize to keep values numerically tame
      zz <- logsum2(b0,b1)
      lb0[t] <- b0-zz
      lb1[t] <- b1-zz
    }
  }

  out <- numeric(Tn)
  for(t in seq_len(Tn)){
    g0 <- la0[t]+lb0[t]
    g1 <- la1[t]+lb1[t]
    zz <- logsum2(g0,g1)
    out[t] <- exp(g1-zz)
  }
  out
}

canon <- function(x) gsub("\\s+","",x)
classic_rhat <- function(xs){
  n <- min(vapply(xs,length,integer(1)))
  xs <- lapply(xs,function(x) as.numeric(x[seq_len(n)]))
  means <- vapply(xs,mean,numeric(1))
  vars <- vapply(xs,var,numeric(1))
  W <- mean(vars)
  B <- n*var(means)
  if(!is.finite(W) || W<=0) return(NA_real_)
  sqrt((((n-1)/n)*W+B/n)/W)
}

global_chains <- vector("list",3)
p_by_chain <- NULL
runtimes <- vector("list",3)

for(cc in 1:3){

  cat("\n============================================================\n")
  cat("READING MARGINAL-HMM PILOT CHAIN",cc,"\n")
  cat("============================================================\n")

  obj <- readRDS(CHAIN_FILES[cc])
  sm <- as.matrix(obj$samples)
  cn <- colnames(sm)
  ccn <- canon(cn)

  if(cc==1L){
    ids <- obj$ids
    individual_ids <- obj$individual_ids
    sex_data <- as.integer(obj$sex_data)
    adult_entry <- as.integer(obj$adult_entry)
    first <- as.integer(obj$first)
    K <- as.integer(obj$K)
    years <- obj$years
    disp_index <- obj$disp_index
    nind <- length(ids)
    n_interval <- nrow(disp_index)

    core_requested <- obj$core_monitors
    base <- sub("\\[.*$","",ccn)
    global_pos <- which(base %in% core_requested)
    global_names <- cn[global_pos]

    emit_names <- paste0("log_emit_ratio_save[",seq_len(n_interval),"]")
    emit_pos <- match(canon(emit_names),ccn)
    if(anyNA(emit_pos))
      stop("Could not match all ",n_interval," log_emit_ratio_save columns.")

    # Exact interval row indices per badger.
    rows_by_i <- split(seq_len(n_interval),disp_index$model_i)

    p_by_chain <- matrix(
      NA_real_,nrow=n_interval,ncol=3,
      dimnames=list(NULL,paste0("chain",1:3))
    )

    cat("Retained draws:",nrow(sm),"\n")
    cat("Global columns:",length(global_pos),"\n")
    cat("Emission-ratio columns:",length(emit_pos),"\n")
    cat("Total saved columns:",ncol(sm),"\n")
  } else {
    if(!identical(as.character(obj$ids),as.character(ids)))
      stop("Animal ordering differs in chain ",cc)
    if(!identical(obj$disp_index$node,disp_index$node))
      stop("Interval ordering differs in chain ",cc)

    global_pos <- match(canon(global_names),ccn)
    emit_pos <- match(canon(emit_names),ccn)
    if(anyNA(global_pos) || anyNA(emit_pos))
      stop("Column mismatch in chain ",cc)
  }

  global_chains[[cc]] <- sm[,global_pos,drop=FALSE]
  E <- sm[,emit_pos,drop=FALSE]
  p_sum <- numeric(n_interval)

  # Positions of transition parameters in the compact global matrix.
  gnames <- colnames(global_chains[[cc]])
  gp <- function(x){
    z <- match(x,gnames)
    if(is.na(z)) stop("Missing global parameter: ",x)
    z
  }
  j_ai <- gp("alpha_disp_init")
  j_ba <- gp("beta_disp_adult")
  j_bs <- gp("beta_disp_init_sex")
  j_ar <- gp("alpha_RD")
  j_br <- gp("beta_RD_sex")
  j_ad <- gp("alpha_DD")
  j_bd <- gp("beta_DD_sex")

  cat("Exact forward-backward smoothing across",nrow(sm),"retained draws...\n")

  for(d in seq_len(nrow(sm))){
    gd <- global_chains[[cc]][d,]

    for(i in seq_len(nind)){
      rr <- rows_by_i[[as.character(i)]]
      if(is.null(rr) || !length(rr)) next

      p_init <- ilogit(
        gd[j_ai]+gd[j_ba]*adult_entry[i]+gd[j_bs]*sex_data[i]
      )
      p_RD <- ilogit(gd[j_ar]+gd[j_br]*sex_data[i])
      p_DD <- ilogit(gd[j_ad]+gd[j_bd]*sex_data[i])

      p_sum[rr] <- p_sum[rr]+smooth_high(E[d,rr],p_init,p_RD,p_DD)
    }

    if(d %% 250L==0L)
      cat("  draw",d,"/",nrow(sm),"\n")
  }

  p_by_chain[,cc] <- p_sum/nrow(sm)
  runtimes[[cc]] <- obj$runtime

  rm(sm,E,obj,p_sum)
  gc()
}

# ---- global diagnostics ------------------------------------------------------
diag_rows <- lapply(seq_along(global_names),function(pp){
  par <- global_names[pp]
  xs <- lapply(global_chains,function(m) m[,pp])

  one <- coda::mcmc.list(
    lapply(xs,function(x)
      coda::as.mcmc(matrix(x,ncol=1,dimnames=list(NULL,par))))
  )

  tibble(
    parameter=par,
    Rhat=classic_rhat(xs),
    ESS=tryCatch(
      as.numeric(coda::effectiveSize(one)[1]),
      error=function(e) NA_real_
    ),
    chain1_mean=mean(xs[[1]]),
    chain2_mean=mean(xs[[2]]),
    chain3_mean=mean(xs[[3]])
  )
})

global_diag <- bind_rows(diag_rows) %>%
  arrange(desc(Rhat))

# ---- exact latent-state agreement -------------------------------------------
per_chain <- bind_rows(lapply(1:3,function(j){
  p <- p_by_chain[,j]
  tibble(
    chain=j,
    mean_p_high=mean(p),
    median_p_high=median(p),
    n_p50=sum(p>=.50),
    n_p80=sum(p>=.80),
    n_p95=sum(p>=.95)
  )
}))

pairwise <- bind_rows(lapply(combn(1:3,2,simplify=FALSE),function(z){
  a <- p_by_chain[,z[1]]
  b <- p_by_chain[,z[2]]
  tibble(
    chain_a=z[1],
    chain_b=z[2],
    correlation=cor(a,b),
    mean_abs_diff=mean(abs(a-b)),
    median_abs_diff=median(abs(a-b)),
    q95_abs_diff=as.numeric(quantile(abs(a-b),.95)),
    n_abs_diff_gt_0_20=sum(abs(a-b)>.20),
    n_abs_diff_gt_0_50=sum(abs(a-b)>.50)
  )
}))

range_p <- apply(p_by_chain,1,function(z) max(z)-min(z))
majority50 <- rowSums(p_by_chain>=.50)
majority80 <- rowSums(p_by_chain>=.80)

overall <- tibble(
  n_intervals=nrow(p_by_chain),
  mean_chain_range=mean(range_p),
  median_chain_range=median(range_p),
  q95_chain_range=as.numeric(quantile(range_p,.95)),
  n_range_gt_0_20=sum(range_p>.20),
  n_range_gt_0_50=sum(range_p>.50),
  n_p50_all_3=sum(majority50==3),
  n_p50_2_of_3=sum(majority50==2),
  n_p50_1_of_3=sum(majority50==1),
  n_p80_all_3=sum(majority80==3),
  n_p80_2_of_3=sum(majority80==2),
  n_p80_1_of_3=sum(majority80==1)
)

intervals <- disp_index %>%
  bind_cols(as_tibble(p_by_chain)) %>%
  mutate(
    p_chain_min=apply(p_by_chain,1,min),
    p_chain_max=apply(p_by_chain,1,max),
    p_chain_range=p_chain_max-p_chain_min
  ) %>%
  arrange(desc(p_chain_range))

cat("\n============================================================\n")
cat("GLOBAL PARAMETER DIAGNOSTICS\n")
cat("============================================================\n")
print(global_diag,n=Inf,width=Inf)

cat("\n============================================================\n")
cat("EXACT SMOOTHED MOVEMENT-STATE OCCUPANCY\n")
cat("============================================================\n")
print(per_chain,width=Inf)

cat("\n============================================================\n")
cat("PAIRWISE CHAIN AGREEMENT: EXACT P(HIGH)\n")
cat("============================================================\n")
print(pairwise,width=Inf)

cat("\n============================================================\n")
cat("OVERALL LATENT-STATE AGREEMENT\n")
cat("============================================================\n")
print(overall,width=Inf)

cat("\n20 MOST CHAIN-SENSITIVE INTERVALS\n")
print(
  intervals %>%
    select(
      tattoo,from_year,to_year,
      starts_with("chain"),
      p_chain_min,p_chain_max,p_chain_range
    ) %>%
    slice_head(n=20),
  n=20,width=Inf
)

saveRDS(
  list(
    global_diagnostics=global_diag,
    per_chain=per_chain,
    pairwise=pairwise,
    overall=overall,
    interval_chain_probabilities=intervals,
    runtimes=runtimes,
    chain_files=CHAIN_FILES,
    settings=list(
      model="V7MCMHMMv4",
      latent_diagnostic="exact_forward_backward_smoothed_P_high",
      important="No thresholding and no sampled-state Monte Carlo noise."
    )
  ),
  "results/V7MCMHMMv4_PILOT_5K_diagnostics.rds"
)

cat("\nSaved: results/V7MCMHMMv4_PILOT_5K_diagnostics.rds\n")
