# =============================================================================
# V7MC-AF 5K PILOT - COMBINE + CHAIN AGREEMENT
# Run after all three PILOT_5K chains finish.
# =============================================================================

library(tidyverse)
library(coda)

files <- sprintf(
  "results/RD_SCR_V7MCAF_CENTERED_AFSLICE_1285_CHAIN_%d_PILOT_5K.rds",
  1:3
)
missing <- files[!file.exists(files)]
if(length(missing)) stop("Missing pilot chain file(s):\n",paste(missing,collapse="\n"))

canon <- function(x) gsub("\\s+","",x)
classic_rhat <- function(xs){
  n <- min(vapply(xs,length,integer(1)))
  xs <- lapply(xs,function(x) as.numeric(x[seq_len(n)]))
  means <- vapply(xs,mean,numeric(1))
  vars <- vapply(xs,var,numeric(1))
  W <- mean(vars); B <- n*var(means)
  if(!is.finite(W) || W<=0) return(NA_real_)
  sqrt((((n-1)/n)*W+B/n)/W)
}

global_chains <- vector("list",3)
disp_chains <- vector("list",3)
runtimes <- vector("list",3)

for(cc in 1:3){
  cat("\nReading pilot chain",cc,"...\n")
  obj <- readRDS(files[cc])
  m <- as.matrix(obj$samples)
  cn <- colnames(m)
  base <- sub("\\[.*$","",canon(cn))

  if(cc==1){
    disp_index <- obj$disp_index
    core_requested <- obj$core_monitors
    global_pos <- which(base %in% core_requested)
    global_names <- cn[global_pos]
    disp_names <- paste0("disp_save[",seq_len(nrow(disp_index)),"]")
    disp_pos <- match(canon(disp_names),canon(cn))
    if(anyNA(disp_pos)) stop("Could not match packed disp_save columns.")
    cat("Global columns:",length(global_pos),"\n")
    cat("Packed disp columns:",length(disp_pos),"\n")
    cat("Total saved columns:",ncol(m),"\n")
  } else {
    global_pos <- match(canon(global_names),canon(cn))
    disp_pos <- match(canon(disp_names),canon(cn))
    if(anyNA(global_pos) || anyNA(disp_pos)) stop("Chain column mismatch.")
  }

  global_chains[[cc]] <- m[,global_pos,drop=FALSE]
  disp_chains[[cc]] <- m[,disp_pos,drop=FALSE]
  runtimes[[cc]] <- obj$runtime
  rm(m,obj); gc()
}

# ---- global diagnostics ------------------------------------------------------
diag_rows <- lapply(seq_along(global_names),function(pp){
  par <- global_names[pp]
  xs <- lapply(global_chains,function(m) m[,pp])
  one <- coda::mcmc.list(lapply(xs,function(x)
    coda::as.mcmc(matrix(x,ncol=1,dimnames=list(NULL,par)))))
  tibble(
    parameter=par,
    Rhat=classic_rhat(xs),
    ESS=tryCatch(as.numeric(coda::effectiveSize(one)[1]),error=function(e) NA_real_),
    chain1_mean=mean(xs[[1]]),chain2_mean=mean(xs[[2]]),chain3_mean=mean(xs[[3]])
  )
})
global_diag <- bind_rows(diag_rows) %>% arrange(desc(Rhat))

# ---- latent state agreement --------------------------------------------------
p_by_chain <- sapply(disp_chains,colMeans)
colnames(p_by_chain) <- paste0("chain",1:3)

per_chain <- bind_rows(lapply(1:3,function(j){
  p <- p_by_chain[,j]
  tibble(chain=j,mean_p_high=mean(p),median_p_high=median(p),
         n_p50=sum(p>=.50),n_p80=sum(p>=.80),n_p95=sum(p>=.95))
}))

pairwise <- bind_rows(lapply(combn(1:3,2,simplify=FALSE),function(z){
  a <- p_by_chain[,z[1]]; b <- p_by_chain[,z[2]]
  tibble(chain_a=z[1],chain_b=z[2],correlation=cor(a,b),
         mean_abs_diff=mean(abs(a-b)),median_abs_diff=median(abs(a-b)),
         q95_abs_diff=as.numeric(quantile(abs(a-b),.95)),
         n_abs_diff_gt_0_20=sum(abs(a-b)>.20),
         n_abs_diff_gt_0_50=sum(abs(a-b)>.50))
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
  mutate(p_chain_min=apply(p_by_chain,1,min),
         p_chain_max=apply(p_by_chain,1,max),
         p_chain_range=p_chain_max-p_chain_min) %>%
  arrange(desc(p_chain_range))

cat("\n============================================================\n")
cat("GLOBAL PARAMETER DIAGNOSTICS\n")
cat("============================================================\n")
print(global_diag,n=Inf,width=Inf)

cat("\n============================================================\n")
cat("CHAIN-SPECIFIC MOVEMENT OCCUPANCY\n")
cat("============================================================\n")
print(per_chain,width=Inf)

cat("\n============================================================\n")
cat("PAIRWISE LATENT-STATE AGREEMENT\n")
cat("============================================================\n")
print(pairwise,width=Inf)

cat("\n============================================================\n")
cat("OVERALL LATENT-STATE AGREEMENT\n")
cat("============================================================\n")
print(overall,width=Inf)

cat("\n20 MOST CHAIN-SENSITIVE INTERVALS\n")
print(intervals %>%
        select(tattoo,from_year,to_year,starts_with("chain"),
               p_chain_min,p_chain_max,p_chain_range) %>%
        slice_head(n=20),
      n=20,width=Inf)

saveRDS(
  list(global_diagnostics=global_diag,per_chain=per_chain,pairwise=pairwise,
       overall=overall,interval_chain_probabilities=intervals,runtimes=runtimes,
       files=files),
  "results/V7MCAF_PILOT_5K_diagnostics.rds"
)
cat("\nSaved: results/V7MCAF_PILOT_5K_diagnostics.rds\n")
