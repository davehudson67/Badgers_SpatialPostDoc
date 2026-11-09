#!/usr/bin/env Rscript
# V12I-04b: 3 independent chains per simulated survival/detection dataset.
# Runs sequentially to avoid oversubscribing RStudio; no old results overwritten.
# Reuses V12I-04 model and checks simulation identity and convergence.
if(!requireNamespace("posterior",quietly=TRUE)) stop("Install R package 'posterior'")
R <- as.integer(Sys.getenv("V12I_REPS","3"))
C <- as.integer(Sys.getenv("V12I_CHAINS","3"))
ni <- as.integer(Sys.getenv("V12I_NITER","12000"))
nb <- as.integer(Sys.getenv("V12I_NBURN","4000"))
if(anyNA(c(R,C,ni,nb))||R<1||C<2||ni<=nb) stop("Invalid settings")
out <- Sys.getenv("V12I_OUT","")
if(!nzchar(out)) stop("Specify a new V12I_OUT run folder")
if(file.exists(out)) stop("Refusing to overwrite output: ",out)
script <- "scripts/ModularFitting/Woodchester_V12I_04_Survival_Detection_Smoke.R"
if(!file.exists(script)) stop("Cannot find source script")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
rows <- list()
for(r in seq_len(R)) {
  fits <- vector("list",C)
  for(ch in seq_len(C)) {
    dir <- file.path(out,sprintf("rep%02d_chain%02d",r,ch))
    if(file.exists(dir)) stop("Existing chain directory: ",dir)
    log <- paste0(dir,".log")
    env <- c(sprintf("V12I_OUT=%s",dir),
             sprintf("V12I_DATA_SEED=%d",20261109+1000*r),
             sprintf("V12I_SEED=%d",20261109+1000*r+ch),
             sprintf("V12I_NITER=%d",ni),sprintf("V12I_NBURN=%d",nb))
    cat("Running synthetic replicate",r,"chain",ch,"\n")
    status <- suppressWarnings(system2("Rscript",script,stdout=log,stderr=log,env=env))
    if(is.null(status)) status <- 0L
    if(status!=0) stop("Fit failed; inspect ",log)
    fits[[ch]] <- readRDS(file.path(dir,"smoke_fit.rds"))
  }
  if(!all(vapply(fits[-1],function(f)
       identical(f$encounters,fits[[1]]$encounters),logical(1))))
    stop("Chains did not fit identical observations for replicate ",r)
  mats <- lapply(fits,function(f) as.matrix(f$samples))
  if(!all(vapply(mats,function(x)
    identical(colnames(x),colnames(mats[[1]])) &&
    nrow(x)==nrow(mats[[1]]),logical(1)))) stop("Inconsistent draws")
  a <- array(NA_real_,c(nrow(mats[[1]]),C,ncol(mats[[1]])),
             dimnames=list(NULL,NULL,colnames(mats[[1]])))
  for(ch in seq_len(C)) a[,ch,] <- mats[[ch]]
  d <- posterior::summarise_draws(posterior::as_draws_array(a),
          rhat=posterior::rhat,
          ess_bulk=posterior::ess_bulk,
          ess_tail=posterior::ess_tail)
  if(!all(c("variable","rhat","ess_bulk","ess_tail")%in%names(d)))
    stop("Missing posterior diagnostic fields")
  write.csv(as.data.frame(d),file.path(out,sprintf("rep%02d_diagnostics.csv",r)),
            row.names=FALSE)
  for(param in c("phi","p0")) {
    w <- d[d$variable==param,]
    if(nrow(w)!=1L) stop("Missing summary parameter: ",param)
    draws <- unlist(lapply(mats,function(x) x[,param]),use.names=FALSE)
    bounds <- unname(quantile(draws,c(.025,.975)))
    truth <- unname(fits[[1]]$truth[param])
    rows[[length(rows)+1L]] <- data.frame(replicate=r,
       parameter=param,truth=truth,mean=mean(draws),
       lower=bounds[1],upper=bounds[2],
       covers_truth=(bounds[1]<=truth && truth<=bounds[2]),
       rhat=w$rhat,ess_bulk=w$ess_bulk,ess_tail=w$ess_tail)
  }
}
result <- do.call(rbind,rows)
write.csv(result,file.path(out,"validation_summary.csv"),row.names=FALSE)
print(result,row.names=FALSE)
cat("PRELIMINARY: 3 datasets are insufficient to establish robust coverage.\n")
