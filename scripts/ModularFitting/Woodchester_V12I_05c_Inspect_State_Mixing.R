#!/usr/bin/env Rscript
# V12I-05c: diagnose existing joint spatial-survival validation fits only.
# Does not execute MCMC, modify model inputs, or touch prior chain outputs.
if(!requireNamespace("posterior",quietly=TRUE)) stop("R package 'posterior' required")
base <- Sys.getenv("V12I_VALIDATION_OUT","")
reps <- as.integer(Sys.getenv("V12I_REPS","3"))
chains <- as.integer(Sys.getenv("V12I_CHAINS","3"))
if(!nzchar(base) || !dir.exists(base) || is.na(reps) || is.na(chains) ||
   reps<1 || chains<2) stop("Provide existing validation directory, valid reps/chains")
normal <- function(x) gsub("[[:space:]]","",x)
allrows <- list()
for(r in seq_len(reps)) {
  paths <- file.path(base,sprintf("rep%02d_chain%02d",r,seq_len(chains)),"smoke_fit.rds")
  if(!all(file.exists(paths))) stop("Missing input fit for replicate ",r)
  fits <- lapply(paths,readRDS)
  ref <- fits[[1]]
  if(!all(vapply(fits[-1],function(f)
     identical(f$encounters,ref$encounters) &&
     identical(f$latent_survival,ref$latent_survival) &&
     identical(f$true_positions,ref$true_positions),logical(1))))
    stop("Chains used different synthetic data, replicate ",r)
  mats <- lapply(fits,function(f) as.matrix(f$posterior_samples))
  nm <- normal(colnames(mats[[1]]))
  if(!all(vapply(mats,function(m)
    identical(normal(colnames(m)),nm) && nrow(m)==nrow(mats[[1]]),
    logical(1)))) stop("Mismatch in chain draws or variable names")
  arr <- array(NA_real_,c(nrow(mats[[1]]),chains,length(nm)),
               dimnames=list(NULL,NULL,nm))
  for(ch in seq_len(chains)) arr[,ch,] <- mats[[ch]]
  dg <- posterior::summarise_draws(posterior::as_draws_array(arr),
       rhat=posterior::rhat,ess_bulk=posterior::ess_bulk,
       ess_tail=posterior::ess_tail)
  names_dg <- normal(dg$variable)
  m <- do.call(rbind,mats)
  colnames(m) <- nm
  N <- nrow(ref$latent_survival)
  T <- ncol(ref$latent_survival)
  det <- as.data.frame(ref$detectors)
  if(!all(c("x","y") %in% names(det))) stop("Detector columns missing")
  DX <- det$x-mean(det$x)
  DY <- det$y-mean(det$y)
  rows <- vector("list",N*T)
  k <- 0L
  for(i in seq_len(N)) for(t in seq_len(T)) {
    k <- k+1L
    keys <- paste0("S[",i,",",1:2,",",t,"]")
    zk <- paste0("z[",i,",",t,"]")
    idx <- match(keys,nm)
    zidx <- match(zk,nm)
    if(anyNA(idx)) stop("Missing location node(s): ",paste(keys,collapse=", "))
    # Initial survival state may be a deterministic rather than monitored node.
    zp <- if(is.na(zidx)) 1 else mean(m[,zidx])
    n_capture <- sum(ref$encounters[i,t,,,drop=FALSE])
    loc <- as.numeric(colMeans(m[,idx,drop=FALSE]))
    truth <- as.numeric(ref$true_positions[i,,t])
    loc_error <- sqrt(sum((loc-truth)^2))
    nearest <- min(sqrt((DX-truth[1])^2+(DY-truth[2])^2))
    drows <- dg[match(keys,names_dg),,drop=FALSE]
    rows[[k]] <- data.frame(replicate=r,id=i,year=t,
        truth_alive=ref$latent_survival[i,t],
        posterior_alive=zp,capture_indicators=n_capture,
        nearest_detector_m=nearest,location_error_m=loc_error,
        worst_location_rhat=if(all(is.na(drows$rhat))) NA_real_ else
            max(drows$rhat,na.rm=TRUE),
        min_location_bulk_ess=if(all(is.na(drows$ess_bulk))) NA_real_ else
            min(drows$ess_bulk,na.rm=TRUE))
  }
  allrows[[r]] <- do.call(rbind,rows)
}
result <- do.call(rbind,allrows)
file <- file.path(base,"animal_year_spatial_state_audit.csv")
write.csv(result,file,row.names=FALSE)
cat("=== LOCATION MIXING BY KNOWN SIMULATED ALIVE STATUS ===\n")
for(status in c(1,0)) {
  x <- result[result$truth_alive==status,,drop=FALSE]
  if(nrow(x)) cat(if(status==1) "Alive" else "Dead",
     ": n=",nrow(x),", median error=",round(median(x$location_error_m),1),
     " m, worst Rhat=",round(max(x$worst_location_rhat,na.rm=TRUE),3),
     ", min bulk ESS=",round(min(x$min_location_bulk_ess,na.rm=TRUE),1),"\n",sep="")
}
cat("\n=== WORST ANIMAL-YEAR LOCATION MIXING ===\n")
ord <- order(result$worst_location_rhat,decreasing=TRUE,na.last=TRUE)
print(head(result[ord,],20),row.names=FALSE)
cat("\n=== HIGHEST ERRORS WHEN TRULY ALIVE ===\n")
alive <- result[result$truth_alive==1,,drop=FALSE]
print(head(alive[order(-alive$location_error_m),],15),row.names=FALSE)
cat("\nSaved:",file,"\n")
cat("Truth alive/dead is used ONLY for diagnostic evaluation of synthetic data.\n")
