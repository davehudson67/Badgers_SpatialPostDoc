#!/usr/bin/env Rscript
# V12I-05d: evaluate known-truth spatial uncertainty from saved joint-model chains.
# All truth variables used for validation only, not fitting. Does not refit.
base <- Sys.getenv("V12I_VALIDATION_OUT","")
reps <- as.integer(Sys.getenv("V12I_REPS","3"))
chains <- as.integer(Sys.getenv("V12I_CHAINS","3"))
if(!nzchar(base)||!dir.exists(base)||is.na(reps)||is.na(chains)||
   reps<1||chains<2) stop("Invalid validation path or dimensions")
rows <- list()
for(r in seq_len(reps)) {
 paths <- file.path(base,sprintf("rep%02d_chain%02d",r,seq_len(chains)),
                    "smoke_fit.rds")
 if(!all(file.exists(paths))) stop("Missing chains for replicate ",r)
 fs <- lapply(paths,readRDS)
 ref <- fs[[1]]
 if(!all(vapply(fs[-1],function(f)
     identical(f$encounters,ref$encounters) &&
     identical(f$latent_survival,ref$latent_survival) &&
     identical(f$true_positions,ref$true_positions),logical(1))))
   stop("Chains have different synthetic data: replicate ",r)
 ms <- lapply(fs,function(f) as.matrix(f$posterior_samples))
 nm <- gsub("[[:space:]]","",colnames(ms[[1]]))
 if(!all(vapply(ms,function(m)
    identical(gsub("[[:space:]]","",colnames(m)),nm),logical(1))))
   stop("Inconsistent monitored variable names")
 m <- do.call(rbind,ms)
 colnames(m) <- nm
 N <- nrow(ref$latent_survival)
 T <- ncol(ref$latent_survival)
 for(i in seq_len(N)) for(t in seq_len(T)) {
   keys <- paste0("S[",i,",",1:2,",",t,"]")
   j <- match(keys,nm)
   if(anyNA(j)) stop("Missing coordinates: ",paste(keys,collapse=","))
   pos <- m[,j,drop=FALSE]
   ctr <- colMeans(pos)
   truth <- as.numeric(ref$true_positions[i,,t])
   error <- sqrt(sum((ctr-truth)^2))
   # Posterior distribution of distance from posterior mean, not an exact HPD.
   d <- sqrt(rowSums(sweep(pos,2,ctr,"-")^2))
   rad <- unname(quantile(d,0.95,names=FALSE))
   # radial 95% posterior ball gives a simple interpretable calibration check.
   nc <- sum(ref$encounters[i,t,,,drop=FALSE])
   rows[[length(rows)+1L]] <- data.frame(
      replicate=r,id=i,year=t,truth_alive=ref$latent_survival[i,t],
      detections=nc,posterior_mean_error_m=error,
      posterior_radial_95_m=rad,truth_in_radial_95=(error<=rad),
      standardized_error=if(rad>0) error/rad else NA_real_)
 }
}
tab <- do.call(rbind,rows)
out <- file.path(base,"spatial_uncertainty_audit.csv")
write.csv(tab,out,row.names=FALSE)
cat("=== SPATIAL UNCERTAINTY CALIBRATION (SYNTHETIC ONLY) ===\n")
for(status in c(1,0)) for(detected in c(TRUE,FALSE)) {
  x <- tab[tab$truth_alive==status & (tab$detections>0)==detected,,drop=FALSE]
  if(nrow(x)) cat("truth_alive=",status," detected=",detected,
      " n=",nrow(x),
      " median_error_m=",round(median(x$posterior_mean_error_m),1),
      " median_radial95_m=",round(median(x$posterior_radial_95_m),1),
      " fraction_truth_within_radial95=",round(mean(x$truth_in_radial_95),3),
      "\n",sep="")
}
cat("\nLargest error relative to posterior uncertainty (truly alive):\n")
a <- tab[tab$truth_alive==1,,drop=FALSE]
print(head(a[order(-a$standardized_error),],12),row.names=FALSE)
cat("\nOutput:",out,"\n")
cat("Radial intervals are posterior-mean-centred balls, not 2D HPD regions.\n")
cat("Joint spatial nodes still have mixing problems; coverage is provisional.\n")
