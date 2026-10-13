# =============================================================================
# WOODCHESTER V9 - KEY CONVERGENCE DIAGNOSTICS
#
# Purpose
#   Decide whether the V9 exact-prior reparameterisation has resolved the V8
#   movement-scale mixing problem before any further biological model building.
#
# Checks
#   1. Rhat / ESS for the V9 identified movement coordinates and transition terms
#   2. Rhat / ESS for derived mean annual radial movement distances
#   3. chain-specific latent high-mobility occupancy and state agreement
#   4. first-half vs second-half derived-distance means within each chain
#   5. age-effect posterior/convergence for the known-age model
#
# This script does NOT declare a model "good" automatically. It writes compact
# diagnostic tables for review before the movement model is frozen.
# =============================================================================

library(tidyverse)
library(coda)

MOVE_MEAN_FACTOR <- sqrt(pi/2)

models <- list(
  MAXDATA=list(
    files=sprintf("results/RD_SCR_V9_MOVEMENT_MAXDATA_1932_CHAIN_%d.rds",1:3),
    expected_intervals=6316L
  ),
  AGE=list(
    files=sprintf("results/RD_SCR_V9_MOVEMENT_AGE_1756_CHAIN_%d.rds",1:3),
    expected_intervals=5810L
  )
)

for(mm in models){
  missing <- mm$files[!file.exists(mm$files)]
  if(length(missing)) stop("Missing V9 chain file(s):\n",paste(missing,collapse="\n"))
}

dir.create("results",showWarnings=FALSE)

rhat_ess <- function(chains){
  ml <- do.call(coda::mcmc.list,lapply(chains,coda::as.mcmc))
  gd <- coda::gelman.diag(ml,multivariate=FALSE,autoburnin=FALSE)$psrf
  ee <- coda::effectiveSize(ml)
  tibble(parameter=rownames(gd),Rhat=gd[,"Point est."],Rhat_upper=gd[,"Upper C.I."],ESS=as.numeric(ee[rownames(gd)]))
}

analyse_one <- function(label,files,expected_intervals){
  cat("\n============================================================\n")
  cat("V9",label,"DIAGNOSTICS\n")
  cat("============================================================\n")

  global_keep <- c(
    "logmove_male_local","logmove_female_high","beta_move_disp",
    "alpha_logmove","beta_move_sex",
    "alpha_disp_init","beta_disp_adult","beta_disp_init_sex",
    "alpha_RD","beta_RD_sex","alpha_DD","beta_DD_sex",
    "beta_sg","beta_peripheral","beta_age","OR_age_per_year"
  )

  global_chains <- vector("list",length(files))
  derived_chains <- vector("list",length(files))
  p_high_chain <- vector("list",length(files))
  half_tables <- vector("list",length(files))
  interval_nodes <- NULL

  for(cc in seq_along(files)){
    cat("Reading chain",cc,":",files[cc],"\n")
    obj <- readRDS(files[cc])
    m <- as.matrix(obj$samples)

    if(is.null(interval_nodes)){
      interval_nodes <- obj$disp_index$node
      if(length(interval_nodes)!=expected_intervals)
        stop(label,": expected ",expected_intervals," movement intervals but found ",length(interval_nodes),".")
    } else if(!identical(obj$disp_index$node,interval_nodes)){
      stop(label,": movement-state node order differs between chains.")
    }

    need <- c("logmove_male_local","logmove_female_high","beta_move_disp")
    if(!all(need%in%colnames(m))) stop(label," chain ",cc," missing V9 movement coordinates: ",paste(setdiff(need,colnames(m)),collapse=", "))

    keep <- intersect(global_keep,colnames(m))
    global_chains[[cc]] <- m[,keep,drop=FALSE]

    # Mean radial distance for an isotropic 2D Gaussian step = sigma*sqrt(pi/2).
    beta_disp <- m[,"beta_move_disp"]
    male_local_log <- m[,"logmove_male_local"]
    female_high_log <- m[,"logmove_female_high"]
    der <- cbind(
      female_local_m=MOVE_MEAN_FACTOR*exp(female_high_log-beta_disp),
      male_local_m=MOVE_MEAN_FACTOR*exp(male_local_log),
      female_high_m=MOVE_MEAN_FACTOR*exp(female_high_log),
      male_high_m=MOVE_MEAN_FACTOR*exp(male_local_log+beta_disp)
    )
    derived_chains[[cc]] <- der

    n <- nrow(der); h <- floor(n/2)
    half_tables[[cc]] <- map_dfr(colnames(der),function(p){
      a <- mean(der[seq_len(h),p]); b <- mean(der[(h+1L):n,p])
      tibble(model=label,chain=cc,parameter=p,first_half_mean=a,second_half_mean=b,
             pct_change=100*(b-a)/a)
    })

    disp_block <- m[,interval_nodes,drop=FALSE]
    p_high_chain[[cc]] <- colMeans(disp_block)

    rm(m,disp_block,obj,der); gc()
  }

  # All retained global columns must match across chains.
  common <- Reduce(intersect,lapply(global_chains,colnames))
  global_chains <- lapply(global_chains,function(x) x[,common,drop=FALSE])
  global_diag <- rhat_ess(global_chains) %>% mutate(model=label,.before=1)
  derived_diag <- rhat_ess(derived_chains) %>% mutate(model=label,.before=1)

  occupancy <- map_dfr(seq_along(p_high_chain),function(cc){
    p <- p_high_chain[[cc]]
    tibble(model=label,chain=cc,mean_p_high=mean(p),median_p_high=median(p),
           n_p50=sum(p>=.5),n_p80=sum(p>=.8))
  })

  pairs <- combn(seq_along(p_high_chain),2,simplify=FALSE)
  agreement <- map_dfr(pairs,function(z){
    a <- p_high_chain[[z[1]]]; b <- p_high_chain[[z[2]]]
    tibble(
      model=label,chain_a=z[1],chain_b=z[2],
      correlation=cor(a,b),mean_abs_difference=mean(abs(a-b)),
      median_abs_difference=median(abs(a-b)),
      n_absdiff_gt_0.10=sum(abs(a-b)>.10),n_absdiff_gt_0.20=sum(abs(a-b)>.20),
      n_hard_disagree=sum((a>=.5)!=(b>=.5)),hard_agreement=mean((a>=.5)==(b>=.5))
    )
  })

  halves <- bind_rows(half_tables)

  age_summary <- NULL
  if("beta_age"%in%common){
    ba <- unlist(lapply(global_chains,function(x) x[,"beta_age"]))
    age_summary <- tibble(
      model=label,
      beta_age_mean=mean(ba),beta_age_median=median(ba),
      beta_age_q025=quantile(ba,.025),beta_age_q975=quantile(ba,.975),
      P_beta_age_lt_0=mean(ba<0),
      OR_age_median=median(exp(ba)),OR_age_q025=quantile(exp(ba),.025),OR_age_q975=quantile(exp(ba),.975)
    )
  }

  cat("\nKey movement-coordinate convergence:\n")
  print(global_diag %>% filter(parameter%in%c("logmove_male_local","logmove_female_high","beta_move_disp","alpha_logmove","beta_move_sex","beta_age","OR_age_per_year")) %>% arrange(desc(Rhat)),n=Inf,width=Inf)
  cat("\nDerived mean radial-distance convergence:\n")
  print(derived_diag %>% arrange(desc(Rhat)),n=Inf,width=Inf)
  cat("\nLatent-state occupancy by chain:\n")
  print(occupancy,n=Inf,width=Inf)
  cat("\nLatent-state agreement between chains:\n")
  print(agreement,n=Inf,width=Inf)
  cat("\nWithin-chain first-half -> second-half movement-distance drift (%):\n")
  print(halves,n=Inf,width=Inf)
  if(!is.null(age_summary)){
    cat("\nChronological-age posterior:\n")
    print(age_summary,n=Inf,width=Inf)
  }

  invisible(list(global=global_diag,derived=derived_diag,occupancy=occupancy,
                 agreement=agreement,halves=halves,age=age_summary))
}

out <- imap(models,function(mm,label) analyse_one(label,mm$files,mm$expected_intervals))

write_csv(bind_rows(map(out,"global")),"results/V9_key_global_convergence.csv")
write_csv(bind_rows(map(out,"derived")),"results/V9_derived_movement_distance_convergence.csv")
write_csv(bind_rows(map(out,"occupancy")),"results/V9_state_occupancy_by_chain.csv")
write_csv(bind_rows(map(out,"agreement")),"results/V9_state_chain_agreement.csv")
write_csv(bind_rows(map(out,"halves")),"results/V9_within_chain_distance_drift.csv")
age_out <- bind_rows(map(out,"age"))
if(nrow(age_out)) write_csv(age_out,"results/V9_age_effect_summary.csv")

cat("\n============================================================\n")
cat("V9 KEY DIAGNOSTICS COMPLETE\n")
cat("============================================================\n")
cat("Saved:\n")
cat("  results/V9_key_global_convergence.csv\n")
cat("  results/V9_derived_movement_distance_convergence.csv\n")
cat("  results/V9_state_occupancy_by_chain.csv\n")
cat("  results/V9_state_chain_agreement.csv\n")
cat("  results/V9_within_chain_distance_drift.csv\n")
if(nrow(age_out)) cat("  results/V9_age_effect_summary.csv\n")
cat("\nReview Rhat/ESS, derived-distance drift and state agreement before freezing V9.\n")
