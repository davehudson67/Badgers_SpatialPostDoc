#!/usr/bin/env Rscript
# Summarise already-completed V12I-03 tmux parallel outputs; NEVER rerun fits.
if(!requireNamespace("posterior",quietly=TRUE))
  stop("Install the R package 'posterior' before summarising")
base <- Sys.getenv("V12I_VALIDATION_OUT","")
if(!nzchar(base) || !dir.exists(base)) stop("Set V12I_VALIDATION_OUT to existing run folder")
reps <- as.integer(Sys.getenv("V12I_REPS","3"))
chains <- as.integer(Sys.getenv("V12I_CHAINS","3"))
if(anyNA(c(reps,chains)) || reps<1 || chains<2) stop("Invalid dimensions")
rows <- list()
for(r in seq_len(reps)) {
  dirs <- file.path(base,sprintf("rep%02d_chain%02d",r,seq_len(chains)))
  fits <- lapply(dirs,function(d) {
    f <- file.path(d,"smoke_fit.rds")
    if(!file.exists(f)) stop("Missing completed fit: ",f)
    readRDS(f)
  })
  if(!all(vapply(fits[-1],function(f)
      identical(f$y,fits[[1]]$y),logical(1))))
    stop("Different capture histories between chains for replicate ",r)
  mats <- lapply(fits,function(f) as.matrix(f$posterior_samples))
  nm <- colnames(mats[[1]])
  if(!all(vapply(mats,function(m)
      identical(colnames(m),nm) && nrow(m)==nrow(mats[[1]]),
      logical(1)))) stop("Monitor names or sample counts disagree")
  arr <- array(NA_real_,c(nrow(mats[[1]]),chains,length(nm)),
               dimnames=list(NULL,NULL,nm))
  for(ch in seq_len(chains)) arr[,ch,] <- mats[[ch]]
  dg <- posterior::summarise_draws(posterior::as_draws_array(arr),
          rhat=posterior::rhat,ess_bulk=posterior::ess_bulk,ess_tail=posterior::ess_tail)
  stopifnot(all(c("variable","rhat","ess_bulk","ess_tail") %in% names(dg)),\n            sum(dg$variable=="p0")==1L)\n  write.csv(as.data.frame(dg),file.path(base,sprintf("rep%02d_diagnostics.csv",r)),
            row.names=FALSE)
  p0 <- unlist(lapply(mats,function(m) m[,"p0"]),use.names=FALSE)
  truth <- fits[[1]]$p0_true
  p0ci <- unname(quantile(p0,c(.025,.975)))
  # Pool draws BEFORE finding the posterior location means.
  sloc <- grep("^S\\[",nm)
  meanloc <- colMeans(do.call(rbind,mats)[,sloc,drop=FALSE])
  names(meanloc) <- gsub("[[:space:]]","",nm[sloc])
  errors <- data.frame()
  for(i in seq_len(dim(fits[[1]]$true_positions)[1]))
    for(t in seq_len(dim(fits[[1]]$true_positions)[3])) {
      keys <- paste0("S[",i,",",1:2,",",t,"]")
      if(!all(keys %in% names(meanloc))) stop("Missing location monitors")
      tr <- fits[[1]]$true_positions[i,,t]
      err <- sqrt(sum((meanloc[keys]-tr)^2))
      errors <- rbind(errors,data.frame(id=i,year=t,
           location_error_m=err,detected=sum(fits[[1]]$y[i,t,,])>0))
    }
  write.csv(errors,file.path(base,sprintf("rep%02d_location_recovery.csv",r)),
            row.names=FALSE)
  rows[[r]] <- data.frame(
    replicate=r,live_indicators=sum(fits[[1]]$y),
    p0_mean=mean(p0),p0_low=p0ci[1],p0_high=p0ci[2],
    p0_covers_truth=(p0ci[1]<=truth && p0ci[2]>=truth),
    p0_rhat=dg$rhat[dg$variable=="p0"],
    p0_bulk_ess=dg$ess_bulk[dg$variable=="p0"],
    p0_tail_ess=dg$ess_tail[dg$variable=="p0"],
    worst_rhat=if(all(is.na(dg$rhat))) NA_real_ else max(dg$rhat,na.rm=TRUE),
    min_bulk_ess=if(all(is.na(dg$ess_bulk))) NA_real_ else min(dg$ess_bulk,na.rm=TRUE),
    median_location_error_m=median(errors$location_error_m),
    max_location_error_m=max(errors$location_error_m)
  )
}
result <- do.call(rbind,rows)
write.csv(result,file.path(base,"validation_summary.csv"),row.names=FALSE)
print(result,row.names=FALSE)
cat("\nThese are diagnostics across",reps,"synthetic datasets, not a real-data fit.\n")
cat("Investigate any Rhat >=1.01, ESS <400, or systematic recovery failure.\n")
