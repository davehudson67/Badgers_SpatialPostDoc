#!/usr/bin/env Rscript
# V12I-05 DEVELOPMENTAL synthetic joint spatial survival and detection model.
# This does not fit real Woodchester data, immigrants, or emigration.
# Read-only, never overwrites V11 results; V11 detector locations used as geometry only.
if(!requireNamespace("nimble",quietly=TRUE))
  stop("Install R package nimble")
suppressPackageStartupMessages(library(nimble))
seed <- as.integer(Sys.getenv("V12I_SEED","20261109"))
data_seed <- as.integer(Sys.getenv("V12I_DATA_SEED",as.character(seed)))
N <- as.integer(Sys.getenv("V12I_N","12"))
T <- as.integer(Sys.getenv("V12I_T","4"))
niter <- as.integer(Sys.getenv("V12I_NITER","1200"))
nburn <- as.integer(Sys.getenv("V12I_NBURN","600"))
if(anyNA(c(seed,data_seed,N,T,niter,nburn)) || N<2 || T<2 ||
   nburn<10 || niter<=nburn) stop("Invalid run settings")
out <- Sys.getenv("V12I_OUT","")
if(!nzchar(out)) stop("Set V12I_OUT to a NEW dedicated output directory")
if(file.exists(out)) stop("Refusing to overwrite output directory: ",out)
f <- Sys.glob("results/V11R2_RES50_*_1932_CHAIN1.rds")
if(length(f)!=1) stop("Expected exactly one V11R2 RES50 reference RDS")
v <- readRDS(f)
det_all <- as.data.frame(v$detectors)
stopifnot(all(c("x","y","Sett_Clean") %in% colnames(det_all)))
rm(v)
central <- which.min((det_all$x-median(det_all$x))^2+
                     (det_all$y-median(det_all$y))^2)
ord <- order((det_all$x-det_all$x[central])^2+
             (det_all$y-det_all$y[central])^2)
J <- 8L
if(nrow(det_all)<J) stop("Insufficient detector coordinates")
det <- det_all[ord[seq_len(J)],c("Sett_Clean","x","y")]
DX <- unname(det$x-mean(det$x))
DY <- unname(det$y-mean(det$y))
xmin <- min(DX)-150; xmax <- max(DX)+150
ymin <- min(DY)-150; ymax <- max(DY)+150
Q <- 4L
phi_true <- .82
p0_true <- .42
sigma_move <- 60
sigma_det <- 170
season <- c(.35,.85,1,.70)
set.seed(data_seed)
Strue <- array(NA_real_,c(N,2,T))
ztrue <- matrix(0L,N,T)
y <- array(0L,c(N,T,Q,J))
for(i in seq_len(N)) {
  ztrue[i,1] <- 1L
  Strue[i,1,1] <- runif(1,xmin,xmax)
  Strue[i,2,1] <- runif(1,ymin,ymax)
  for(t in seq_len(T)) {
    if(t>1) {
      ztrue[i,t] <- rbinom(1,1,ztrue[i,t-1]*phi_true)
      Strue[i,1,t] <- rnorm(1,Strue[i,1,t-1],sigma_move)
      Strue[i,2,t] <- rnorm(1,Strue[i,2,t-1],sigma_move)
    }
    for(q in seq_len(Q)) for(j in seq_len(J)) {
      d2 <- (Strue[i,1,t]-DX[j])^2+(Strue[i,2,t]-DY[j])^2
      prob <- ztrue[i,t]*p0_true*season[q]*exp(-d2/(2*sigma_det^2))
      y[i,t,q,j] <- rbinom(1,1,prob)
    }
  }
}
code <- nimble::nimbleCode({
  phi ~ dbeta(2,2)
  p0 ~ dbeta(2,3)
  for(i in 1:N) {
    z[i,1] <- 1
    S[i,1,1] ~ dunif(xmin,xmax)
    S[i,2,1] ~ dunif(ymin,ymax)
    for(t in 2:T) {
      z[i,t] ~ dbern(z[i,t-1]*phi)
      S[i,1,t] ~ dnorm(S[i,1,t-1],sd=sigma_move)
      S[i,2,t] ~ dnorm(S[i,2,t-1],sd=sigma_move)
    }
    for(t in 1:T) {
      for(j in 1:J) {
        d2[i,t,j] <- (S[i,1,t]-DX[j])^2+(S[i,2,t]-DY[j])^2
        base_p[i,t,j] <- p0*exp(-d2[i,t,j]/(2*sigma_det^2))
        for(q in 1:Q) {
          prob[i,t,q,j] <- z[i,t]*base_p[i,t,j]*season[q]
          y[i,t,q,j] ~ dbern(prob[i,t,q,j])
        }
      }
    }
  }
})
# Initial latent states reflect only detected history, never the true states.
set.seed(seed)
initialise <- function() {
  zi <- matrix(0L,N,T)
  loc <- array(NA_real_,c(N,2,T))
  for(i in seq_len(N)) {
    detected <- which(vapply(seq_len(T),function(t) sum(y[i,t,,])>0,
                             logical(1)))
    last <- if(length(detected)) max(detected) else 1L
    zi[i,seq_len(last)] <- 1L
    previous <- c(mean(DX),mean(DY))
    for(t in seq_len(T)) {
      dets <- which(vapply(seq_len(J),function(j) sum(y[i,t,,j])>0,
                            logical(1)))
      if(length(dets)) previous <- c(mean(DX[dets]),mean(DY[dets]))
      loc[i,,t] <- previous+rnorm(2,0,25)
    }
    loc[i,1,1] <- pmin(pmax(loc[i,1,1],xmin+1),xmax-1)
    loc[i,2,1] <- pmin(pmax(loc[i,2,1],ymin+1),ymax-1)
  }
  list(phi=runif(1,.6,.95),p0=runif(1,.25,.55),z=zi,S=loc)
}
cat("=== V12I-05 JOINT SPATIAL SURVIVAL SMOKE ===\n")
cat("Synthetic individuals:",N,"years:",T,"quarters:",Q,
    "detectors:",J,"encounter indicators:",sum(y),
    "dead at end:",sum(ztrue[,T]==0),"\n")
s <- nimble::nimbleMCMC(code=code,
    constants=list(N=N,T=T,Q=Q,J=J,DX=DX,DY=DY,season=season,
                   xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,
                   sigma_move=sigma_move,sigma_det=sigma_det),
    data=list(y=y),inits=initialise,monitors=c("phi","p0","S","z"),
    niter=niter,nburnin=nburn,nchains=1,setSeed=seed,
    samplesAsCodaMCMC=FALSE,summary=FALSE,progressBar=FALSE)
s <- as.matrix(s)
stopifnot(nrow(s)==niter-nburn,
          all(c("phi","p0") %in% colnames(s)),all(is.finite(s)))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
saveRDS(list(model="V12I-05 synthetic joint spatial-survival",
             seed=seed,data_seed=data_seed,
             truth=c(phi=phi_true,p0=p0_true),
             latent_survival=ztrue,true_positions=Strue,
             encounters=y,detectors=det,posterior_samples=s),
        file.path(out,"smoke_fit.rds"))
for(nm in c("phi","p0")) {
  interval <- unname(quantile(s[,nm],c(.025,.975)))
  cat(nm,": true=",if(nm=="phi") phi_true else p0_true,
      ", mean=",round(mean(s[,nm]),3),
      ", 95% interval=",paste(round(interval,3),collapse=" to "),"\n",sep="")
}
cat("Saved:",out,"\n")
cat("DEVELOPMENTAL SMOKE ONLY: no entry, immigration, emigration or real-data fit.\n")
