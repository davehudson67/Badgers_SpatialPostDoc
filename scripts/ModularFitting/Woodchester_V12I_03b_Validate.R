#!/usr/bin/env Rscript
# Replicated multi-chain validation of V12I-03. No Supabase or V11 data modified.
# Run from the repository root. Uses spatial context from the existing V11 RDS.
# Default 3 synthetic datasets x 3 independent chains per dataset.
reps <- as.integer(Sys.getenv("V12I_REPS","3"))
chains <- as.integer(Sys.getenv("V12I_CHAINS","3"))
niter <- as.integer(Sys.getenv("V12I_NITER","12000"))
nburn <- as.integer(Sys.getenv("V12I_NBURN","4000"))
if(anyNA(c(reps,chains,niter,nburn)) || reps<1 || chains<2 ||
   niter<=nburn || nburn<10) stop("Invalid validation dimensions")
base <- Sys.getenv("V12I_VALIDATION_OUT",
                   "outputs/v12_immigration_prototype/v12i03_validation")
dir.create(base,recursive=TRUE,showWarnings=FALSE)
script <- "scripts/ModularFitting/Woodchester_V12I_03_NIMBLE_Spatial_Smoke.R"
if(!file.exists(script)) stop("Missing script: ",script)
runs <- list()
for(r in seq_len(reps)) for(ch in seq_len(chains)) {
  out <- file.path(base,sprintf("rep%02d_chain%02d",r,ch))
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  log <- file.path(out,"fit.log")
  env <- c(
    sprintf("V12I_OUT=%s",out),
    sprintf("V12I_DATA_SEED=%d",20261109L+1000L*r),
    sprintf("V12I_SEED=%d",20261109L+1000L*r+ch),
    "V12I_MATCHED_PRIOR=1",
    sprintf("V12I_NITER=%d",niter),
    sprintf("V12I_NBURN=%d",nburn)
  )
  cat(sprintf("Replicate %d/%d, chain %d/%d\n",r,reps,ch,chains))
  status <- suppressWarnings(system2("Rscript",script,
                    stdout=log,stderr=log,env=env))
  if(is.null(status)) status <- 0L
  if(status!=0L) stop("Model failed, inspect: ",log," (status ",status,")")
  runs[[length(runs)+1L]] <- data.frame(
    replicate=r,chain=ch,output=out,log=log)
}
run_table <- do.call(rbind,runs)
write.csv(run_table,file.path(base,"run_manifest.csv"),row.names=FALSE)
if(!requireNamespace("posterior",quietly=TRUE)) {
  stop("Fits saved but diagnostics require R package 'posterior'. ",
       "Install via install.packages('posterior') and rerun the ",
       "diagnostic stage (or install before launching).")
}
summary_rows <- list()
for(r in seq_len(reps)) {
  fits <- lapply(seq_len(chains),function(ch)
    readRDS(file.path(base,sprintf("rep%02d_chain%02d",r,ch),"smoke_fit.rds")))
  same_y <- all(vapply(fits[-1],function(f)
    identical(f$y,fits[[1]]$y),logical(1)))
  if(!same_y) stop("Different capture histories among chains, replicate ",r)
  mats <- lapply(fits,function(f) as.matrix(f$posterior_samples))
  nm <- colnames(mats[[1]])
  if(!all(vapply(mats,function(m)
    identical(colnames(m),nm) && nrow(m)==nrow(mats[[1]]),
    logical(1)))) stop("Inconsistent monitored nodes/draws")
  arr <- array(NA_real_,c(nrow(mats[[1]]),chains,length(nm)),
               dimnames=list(NULL,NULL,nm))
  for(ch in seq_len(chains)) arr[,ch,] <- mats[[ch]]
  dr <- posterior::as_draws_array(arr)
  dg <- posterior::summarise_draws(dr,
         rhat=posterior::rhat,ess_bulk=posterior::ess_bulk,ess_tail=posterior::ess_tail)
  stopifnot(all(c("variable","rhat","ess_bulk","ess_tail") %in% names(dg)),\n            sum(dg$variable=="p0")==1L)\n  write.csv(as.data.frame(dg),
       file.path(base,sprintf("rep%02d_diagnostics.csv",r)),
       row.names=FALSE)
  p0 <- unlist(lapply(mats,function(m) m[,"p0"]),use.names=FALSE)
  all_loc <- do.call(rbind,lapply(fits,function(f) f$location_recovery))
  summary_rows[[r]] <- data.frame(
    replicate=r,n_live=sum(fits[[1]]$y),
    p0_mean=mean(p0),
    p0_lower=unname(quantile(p0,.025)),
    p0_upper=unname(quantile(p0,.975)),
    p0_covers_truth=unname(quantile(p0,.025))<=fits[[1]]$p0_true &&
                    unname(quantile(p0,.975))>=fits[[1]]$p0_true,
    p0_rhat=dg$rhat[dg$variable=="p0"],
    p0_ess_bulk=dg$ess_bulk[dg$variable=="p0"],
    max_rhat=if(all(is.na(dg$rhat))) NA_real_ else max(dg$rhat,na.rm=TRUE),
    min_bulk_ess=if(all(is.na(dg$ess_bulk))) NA_real_ else min(dg$ess_bulk,na.rm=TRUE),
    median_position_error_m=median(all_loc$position_error_m),
    # This location metric is averaged over chain-level posterior means.
    # A full multi-chain location posterior is available in the saved draws.
    stringsAsFactors=FALSE
  )
}
tab <- do.call(rbind,summary_rows)
write.csv(tab,file.path(base,"validation_summary.csv"),row.names=FALSE)
print(tab,row.names=FALSE)
cat("\nSaved validation results:",base,"\n")
cat("NOTE: rhat<1.01 and bulk/tail ESS>400 are useful diagnostics,\n")
cat("not sufficient proof of calibration, identifiability or Woodchester validity.\n")
