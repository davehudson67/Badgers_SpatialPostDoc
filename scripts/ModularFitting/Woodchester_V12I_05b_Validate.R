#!/usr/bin/env Rscript
# V12I-05b read-only summary of independently saved joint spatial-survival fits.
# Fits must have been run with the same V12I_DATA_SEED within replicate.
if(!requireNamespace("posterior",quietly=TRUE)) stop("Install 'posterior'")
base <- Sys.getenv("V12I_VALIDATION_OUT","")
reps <- as.integer(Sys.getenv("V12I_REPS","3"))
chains <- as.integer(Sys.getenv("V12I_CHAINS","3"))
if(!nzchar(base)||!dir.exists(base)||is.na(reps)||is.na(chains)||
   reps<1||chains<2) stop("Invalid validation directory/dimensions")
results <- list()
for(r in seq_len(reps)) {
  paths <- file.path(base,sprintf("rep%02d_chain%02d",r,seq_len(chains)),
                     "smoke_fit.rds")
  if(!all(file.exists(paths))) stop("Missing fit(s): ",paste(paths[!file.exists(paths)],collapse=", "))
  fits <- lapply(paths,readRDS)
  ref <- fits[[1]]
  if(!all(vapply(fits[-1],function(f) identical(f$encounters,ref$encounters) &&
      identical(f$latent_survival,ref$latent_survival) &&
      identical(f$true_positions,ref$true_positions),logical(1))))
    stop("Inconsistent synthetic data across chains: replicate ",r)
  mats <- lapply(fits,function(f) as.matrix(f$posterior_samples))
  nm <- colnames(mats[[1]])
  if(!all(vapply(mats,function(m) nrow(m)==nrow(mats[[1]]) &&
       identical(colnames(m),nm),logical(1))))
    stop("Posterior matrices differ among chains")
  a <- array(NA_real_,c(nrow(mats[[1]]),chains,length(nm)),
             dimnames=list(NULL,NULL,nm))
  for(ch in seq_len(chains)) a[,ch,] <- mats[[ch]]
  d <- posterior::summarise_draws(posterior::as_draws_array(a),
       rhat=posterior::rhat,ess_bulk=posterior::ess_bulk,
       ess_tail=posterior::ess_tail)
  if(!all(c("variable","rhat","ess_bulk","ess_tail") %in% names(d)))
     stop("Missing expected diagnostics")
  write.csv(as.data.frame(d),file.path(base,sprintf("rep%02d_diagnostics.csv",r)),
            row.names=FALSE)
  for(param in c("phi","p0")) {
    drow <- d[d$variable==param,,drop=FALSE]
    if(nrow(drow)!=1L) stop("Missing diagnostic for ",param)
    samp <- unlist(lapply(mats,function(m) m[,param]),use.names=FALSE)
    ci <- unname(quantile(samp,c(.025,.975)))
    truth <- unname(ref$truth[param])
    results[[length(results)+1L]] <- data.frame(replicate=r,
      parameter=param,truth=truth,mean=mean(samp),
      lower=ci[1],upper=ci[2],covers_truth=ci[1]<=truth&&truth<=ci[2],
      rhat=drow$rhat,ess_bulk=drow$ess_bulk,ess_tail=drow$ess_tail)
  }
  spatial <- d[grepl("^S\\[",d$variable),,drop=FALSE]
  latent <- d[grepl("^z\\[",d$variable),,drop=FALSE]
  sumrow <- function(tab,type) data.frame(replicate=r,type=type,
       n_nodes=nrow(tab),
       worst_rhat=if(nrow(tab)&&any(is.finite(tab$rhat)))
          max(tab$rhat[is.finite(tab$rhat)]) else NA_real_,
       min_bulk_ess=if(nrow(tab)&&any(is.finite(tab$ess_bulk)))
          min(tab$ess_bulk[is.finite(tab$ess_bulk)]) else NA_real_,
       missing_rhat=sum(!is.finite(tab$rhat)))
  if(r==1L) node_stats <- list()
  node_stats[[length(node_stats)+1L]] <- sumrow(spatial,"spatial")
  node_stats[[length(node_stats)+1L]] <- sumrow(latent,"survival")
}
table <- do.call(rbind,results)
write.csv(table,file.path(base,"parameter_validation.csv"),row.names=FALSE)
nodes <- do.call(rbind,node_stats)
write.csv(nodes,file.path(base,"node_diagnostics.csv"),row.names=FALSE)
cat("=== PARAMETER RECOVERY ===\n");print(table,row.names=FALSE)
cat("\n=== LATENT-STATE MIXING ===\n");print(nodes,row.names=FALSE)
cat("\nNote: constant/degenerate latent z nodes can have undefined Rhat; inspect missing_rhat.\n")
cat("No full spatial credible-region calibration or PPC yet.\n")
