#!/usr/bin/env Rscript
# Summarise independent NIMBLE chains fitted to IDENTICAL V12I-06 synthetic data.
# Do not combine chains that used different simulated encounters / recovery histories.
# No Woodchester survival/immigration inference.
if(!requireNamespace("posterior",quietly=TRUE))stop("Install R package posterior")
base<-Sys.getenv("V12I06_VALIDATION_OUT","")
if(!nzchar(base)||!dir.exists(base))
 stop("Set V12I06_VALIDATION_OUT to a completed V12I-06 validation run")
nchains<-as.integer(Sys.getenv("V12I06_CHAINS","3"))
if(is.na(nchains)||nchains<2L)stop("V12I06_CHAINS must be >=2")
paths<-file.path(base,sprintf("chain%02d",seq_len(nchains)),"synthetic_fit.rds")
if(!all(file.exists(paths)))
 stop("Missing chain result files: ",paste(paths[!file.exists(paths)],collapse=", "))
stopifnot(!file.exists(file.path(base,"multichain_summary.csv")))
fits<-lapply(paths,readRDS)
baseline<-fits[[1]]
for(ch in seq_along(fits)) {
 f<-fits[[ch]]
 if(!identical(f$y,baseline$y)||
    !identical(f$recovery,baseline$recovery)||
    !identical(f$truth,baseline$truth)||
    !identical(f$states_truth,baseline$states_truth))
  stop("CHAIN DATA INTEGRITY ERROR: differing simulated observations/truth at chain ",ch)
 if(!identical(f$settings$data_seed,baseline$settings$data_seed)||
    !identical(f$settings$N,baseline$settings$N)||
    !identical(f$settings$TT,baseline$settings$TT))
  stop("CHAIN SETTINGS MISMATCH at ",ch)
}
nm<-colnames(baseline$samples)
nit<-nrow(baseline$samples)
if(nit<100L)stop("Too few saved posterior draws for validation")
if(!all(vapply(fits,function(x) identical(colnames(x$samples),nm)&&
             nrow(x$samples)==nit,logical(1))))
 stop("Chain sample dimensions or names mismatch")
arr<-array(NA_real_,c(nit,nchains,length(nm)),
 dimnames=list(NULL,paste0("chain",seq_len(nchains)),nm))
for(ch in seq_along(fits)) {
 arr[,ch,]<-fits[[ch]]$samples
}
if(any(!is.finite(arr)))stop("Nonfinite posterior sample")
draws<-posterior::as_draws_array(arr)
stat<-posterior::summarise_draws(draws,
 mean=mean,sd=sd,
 q025=function(x)unname(quantile(x,.025)),
 q975=function(x)unname(quantile(x,.975)),
 rhat=posterior::rhat,
 ess_bulk=posterior::ess_bulk,
 ess_tail=posterior::ess_tail)
stat<-as.data.frame(stat,stringsAsFactors=FALSE)
lookup<-c(gamma="gamma",phi="phi",c_to_p="core_to_periphery",
 p_to_c="periphery_to_core",p_to_out="periphery_to_outside",
 out_to_p="outside_to_periphery",pc="p_core",pp="p_periphery")
stat$truth<-unname(baseline$truth[unname(lookup[stat$variable])])
if(anyNA(stat$truth))stop("Posterior monitor not in generating truth")
stat$includes_truth<-stat$q025<=stat$truth&stat$q975>=stat$truth
stat$bias<-stat$mean-stat$truth
stat$diagnostics_pass<-!is.na(stat$rhat)&stat$rhat<1.01&
 !is.na(stat$ess_bulk)&stat$ess_bulk>=400&
 !is.na(stat$ess_tail)&stat$ess_tail>=400
write.csv(stat,file.path(base,"multichain_summary.csv"),row.names=FALSE)
writeLines(c("SYNTHETIC V12I-06 chains share EXACT y/recovery/state truth.",
 "Parameter Rhat <1.01 and bulk/tail ESS >=400 are screening criteria.",
 "Passing Rhat/ESS does NOT establish calibration/identifiability.",
 "Eight truth intervals from a single replicated dataset are not coverage.",
 "Fixed known superpopulation, q_recovery and zero external detection.",
 "Some recovered deaths can be observed among never-captured synthetic animals.",
 "No biological Woodchester immigration, emigration or survival inference."),
 file.path(base,"multichain_assumptions.txt"))
cat("=== V12I-06b IDENTICAL-DATA MULTICHAIN VALIDATION ===\n")
cat("Chains:",nchains,"iterations per chain kept:",nit,"\n")
cat("Simulated N=",baseline$settings$N,
 " T=",baseline$settings$TT,
 " ever alive captured=",sum(rowSums(baseline$y>1L)>0),
 " recovery rows=",sum(baseline$recovery),"\n",sep="")
print(stat[,c("variable","truth","mean","q025","q975",
 "rhat","ess_bulk","ess_tail","includes_truth","diagnostics_pass")],
 row.names=FALSE,digits=4)
cat("Saved:",file.path(base,"multichain_summary.csv"),"\n")
if(!all(stat$diagnostics_pass)) {
 cat("WARNING: One or more convergence / ESS screening criteria NOT met.\n")
} else {
 cat("MCMC convergence/ESS screening criteria pass, not a validation of biological identifiability.\n")
}
