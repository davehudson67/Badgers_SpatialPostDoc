#!/usr/bin/env Rscript
# V12I-04 independent synthetic annual survival + quarterly detection proof of concept.
# This is a NON-SPATIAL stepping stone, not yet an immigration/emigration model.
# Entry is KNOWN at year 1. Everyone alive initially. No real data modified.
if(!requireNamespace("nimble",quietly=TRUE)) stop("Install R package 'nimble'")
suppressPackageStartupMessages(library(nimble))
seed <- as.integer(Sys.getenv("V12I_SEED","20261109"))
if(is.na(seed)) stop("Invalid seed")
data_seed <- as.integer(Sys.getenv("V12I_DATA_SEED", as.character(seed)))
if(is.na(data_seed)) stop("Invalid V12I_DATA_SEED")
set.seed(data_seed)
N <- as.integer(Sys.getenv("V12I_N","40"))
T <- as.integer(Sys.getenv("V12I_T","6"))
niter <- as.integer(Sys.getenv("V12I_NITER","12000"))
nburn <- as.integer(Sys.getenv("V12I_NBURN","4000"))
if(anyNA(c(N,T,niter,nburn)) || N<2 || T<2 || niter<=nburn)
  stop("Invalid model dimensions")
Q <- 4L
phi_true <- 0.82
p0_true <- 0.42
season <- c(.35,.85,1,.70)
z_true <- matrix(0L,N,T)
y <- array(0L,c(N,T,Q))
z_true[,1] <- 1L
for(i in seq_len(N)) for(t in seq_len(T)) {
  if(t>1) z_true[i,t] <- rbinom(1,1,z_true[i,t-1]*phi_true)
  for(q in seq_len(Q)) y[i,t,q] <- rbinom(1,1,z_true[i,t]*p0_true*season[q])
}
code <- nimble::nimbleCode({
  phi ~ dbeta(2,2)
  p0 ~ dbeta(2,3)
  for(i in 1:N) {
    z[i,1] <- 1
    for(t in 2:T) {
      z[i,t] ~ dbern(z[i,t-1]*phi)
    }
    for(t in 1:T) for(q in 1:Q) {
      y[i,t,q] ~ dbern(z[i,t]*p0*season[q])
    }
  }
})
# Use a distinct RNG stream for chain initialisation; within a replicate all
# chains share identical simulated observations when V12I_DATA_SEED matches.
set.seed(seed)
# Consistent initial state: alive through last observed year,
# with all later states initially marked dead.
init <- function() {
  zi <- matrix(0L,N,T)
  for(i in seq_len(N)) {
    detected_year <- which(rowSums(matrix(y[i,,],nrow=T,ncol=Q))>0)
    last <- if(length(detected_year)) max(detected_year) else 1L
    zi[i,seq_len(last)] <- 1L
  }
  list(phi=runif(1,.6,.95),p0=runif(1,.25,.55),z=zi)
}
cat("=== V12I-04 SYNTHETIC SURVIVAL + DETECTION ===\n")
cat("N",N,"T",T,"Q",Q,"observed capture occasions",sum(y),"\n")
samples <- nimble::nimbleMCMC(
 code=code,constants=list(N=N,T=T,Q=Q,season=season),
 data=list(y=y),inits=init,monitors=c("phi","p0"),
 nchains=1,setSeed=seed,niter=niter,nburnin=nburn,
 samplesAsCodaMCMC=FALSE,summary=FALSE,progressBar=FALSE)
s <- as.matrix(samples)
out <- Sys.getenv("V12I_OUT","outputs/v12_immigration_prototype/v12i04_survival_detection")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(s,file.path(out,"posterior.csv"),row.names=FALSE)
saveRDS(list(samples=s,seed=seed,data_seed=data_seed,
             truth=c(phi=phi_true,p0=p0_true),
             latent_alive=z_true,encounters=y),
        file.path(out,"smoke_fit.rds"))
for(nm in c("phi","p0")) {
  ci <- quantile(s[,nm],c(.025,.975))
  cat(nm," truth ",if(nm=="phi") phi_true else p0_true,
    " posterior mean ",round(mean(s[,nm]),3),
    " interval ",paste(round(ci,3),collapse=" to "),"\n",sep="")
}
cat("Saved:",out,"\n")
cat("NOT a spatial or open-population immigration/emigration model.\n")
