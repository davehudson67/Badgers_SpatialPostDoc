#!/usr/bin/env Rscript
# V12I-03 first Bayesian spatial NIMBLE smoke test.
# Synthetic alive cohort; real V11 detector XY used as geographical context.
# Entry, survival and migration are deliberately NOT fitted at this stage.
# Annual latent activity centres and quarterly spatial encounter likelihood.
# Read-only relative to V11, frozen snapshot and Supabase.

if (!requireNamespace("nimble",quietly=TRUE))
  stop("The NIMBLE R package is required")
set.seed(20261109)
out <- "outputs/v12_immigration_prototype/v12i03_spatial_smoke"
dir.create(out,recursive=TRUE,showWarnings=FALSE)
f <- Sys.glob("results/V11R2_RES50_*_1932_CHAIN1.rds")
if(length(f)!=1L) stop("Expected one V11R2 RES50 chain 1 file")
v <- readRDS(f)
det_all <- as.data.frame(v$detectors)
stopifnot(all(c("Sett_Clean","x","y") %in% names(det_all)))
rm(v); invisible(gc(verbose=FALSE))
centre <- which.min((det_all$x-median(det_all$x))^2 +
                    (det_all$y-median(det_all$y))^2)
ord <- order((det_all$x-det_all$x[centre])^2 +
             (det_all$y-det_all$y[centre])^2)
J <- 8L
det <- det_all[ord[seq_len(J)],c("Sett_Clean","x","y")]
offset <- c(x=mean(det$x),y=mean(det$y))
DX <- unname(det$x-offset["x"])
DY <- unname(det$y-offset["y"])

N <- as.integer(Sys.getenv("V12I_N","10"))
T <- as.integer(Sys.getenv("V12I_T","4"))
Q <- 4L
niter <- as.integer(Sys.getenv("V12I_NITER","600"))
nburn <- as.integer(Sys.getenv("V12I_NBURN","300"))
if(anyNA(c(N,T,niter,nburn)) || N<2L || T<2L ||
   niter<50L || nburn<10L || nburn>=niter)
  stop("Invalid smoke dimensions or iterations")
season <- c(.35,.85,1,.70) # fixed illustrative relative detection multipliers
p0_true <- .42
sigma_det <- 170
sigma_move <- 60
sigma_spawn <- 65
xmin <- min(DX)-600; xmax <- max(DX)+600
ymin <- min(DY)-600; ymax <- max(DY)+600

# Truth is used exclusively to GENERATE observations and evaluate recovery.
Strue <- array(NA_real_,c(N,2,T))
for(i in seq_len(N)) {
  j <- sample.int(J,1L)
  Strue[i,1,1] <- rnorm(1,DX[j],sigma_spawn)
  Strue[i,2,1] <- rnorm(1,DY[j],sigma_spawn)
  for(t in 2:T) {
    Strue[i,1,t] <- rnorm(1,Strue[i,1,t-1],sigma_move)
    Strue[i,2,t] <- rnorm(1,Strue[i,2,t-1],sigma_move)
  }
}
stopifnot(all(Strue[,1,1]>xmin & Strue[,1,1]<xmax),
          all(Strue[,2,1]>ymin & Strue[,2,1]<ymax))

# Capture at each of eight detectors in each of four quarters.
y <- array(0L,c(N,T,Q,J))
for(i in seq_len(N)) for(t in seq_len(T))
  for(q in seq_len(Q)) for(j in seq_len(J)) {
    d2 <- (Strue[i,1,t]-DX[j])^2+(Strue[i,2,t]-DY[j])^2
    p <- p0_true*season[q]*exp(-d2/(2*sigma_det^2))
    y[i,t,q,j] <- rbinom(1L,1L,p)
  }
observed_quarters <- apply(y,c(1,2,3),sum)>0L
quarters_per_badger_year <- apply(observed_quarters,c(1,2),sum)
cat("\n=== V12I-03 SPATIAL NIMBLE SMOKE ===\n")
cat("Synthetic badgers:",N,"| years:",T,"| quarters:",Q,
    "| detectors:",J,"\n")
cat("Live encounter indicators:",sum(y),"\n")
cat("Ever observed alive:",sum(apply(y,1,sum)>0),"\n")
cat("Observed badger-years with 2+ quarters:",
    sum(quarters_per_badger_year>=2),"\n")

# Fit an intentionally minimal spatial state-space model.
# Alive states and initial-entry are KNOWN to the fitting model.
# sigma_det and sigma_move are FIXED to their simulated values.
# The initial location is *not* initialised from the true S.
# The posterior estimates p0 and individual activity centres.
code <- nimble::nimbleCode({
  p0 ~ dbeta(2,3)
  for(i in 1:N) {
    S[i,1,1] ~ dunif(xmin,xmax)
    S[i,2,1] ~ dunif(ymin,ymax)
    for(t in 2:T) {
      S[i,1,t] ~ dnorm(S[i,1,t-1],sd=sigma_move)
      S[i,2,t] ~ dnorm(S[i,2,t-1],sd=sigma_move)
    }
    for(t in 1:T) {
      for(j in 1:J) {
        d2[i,t,j] <- (S[i,1,t]-DX[j])^2 + (S[i,2,t]-DY[j])^2
        base_p[i,t,j] <- p0*exp(-d2[i,t,j]/(2*sigma_det^2))
        for(q in 1:Q) {
          prob[i,t,q,j] <- base_p[i,t,j]*season[q]
          y[i,t,q,j] ~ dbern(prob[i,t,q,j])
        }
      }
    }
  }
})
constants <- list(N=N,T=T,Q=Q,J=J,DX=DX,DY=DY,season=season,
                  sigma_move=sigma_move,sigma_det=sigma_det,
                  xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax)
# Initialise using only observed detector locations, never latent truth.
initialise <- function() {
  loc <- array(NA_real_,c(N,2,T))
  for(i in seq_len(N)) {
    last <- c(mean(DX),mean(DY))
    for(t in seq_len(T)) {
      detected <- which(colSums(matrix(y[i,t,,,drop=FALSE],
                                            nrow=Q,ncol=J))>0)
      if(length(detected)) {
        last <- c(mean(DX[detected]),mean(DY[detected]))
      }
      loc[i,,t] <- last + rnorm(2,0,25)
    }
    loc[i,1,1] <- min(max(loc[i,1,1],xmin+1),xmax-1)
    loc[i,2,1] <- min(max(loc[i,2,1],ymin+1),ymax-1)
  }
  list(p0=runif(1,.25,.55),S=loc)
}
cat("Compiling and running one NIMBLE MCMC chain...\n")
samples <- nimble::nimbleMCMC(
  code=code,constants=constants,data=list(y=y),
  inits=initialise,monitors=c("p0","S"),
  niter=niter,nburnin=nburn,thin=1,
  nchains=1,setSeed=20261109,
  samplesAsCodaMCMC=FALSE,summary=FALSE,
  progressBar=FALSE
)
samples <- as.matrix(samples)
stopifnot(nrow(samples)==niter-nburn,
          "p0" %in% colnames(samples),
          all(is.finite(samples)))
p0draw <- samples[,"p0"]
cat("p0 truth:",p0_true,
    "| posterior mean:",round(mean(p0draw),3),
    "| 95% interval:",
    paste(round(quantile(p0draw,c(.025,.975)),3),collapse=" to "),"\n")

# NIMBLE monitored node names may contain whitespace after commas.
clean_names <- function(x) gsub("[[:space:]]","",x)
names_normal <- clean_names(colnames(samples))
loc_error <- numeric(0)
location_rows <- vector("list",N*T)
counter <- 0L
for(i in seq_len(N)) for(t in seq_len(T)) {
  cols <- match(c(paste0("S[",i,",1,",t,"]"),
                  paste0("S[",i,",2,",t,"]")),names_normal)
  if(anyNA(cols))
    stop("Missing spatial monitor for individual ",i,", year ",t,
         ": ",paste(names_normal[1:min(length(names_normal),20)],collapse=","))
  est <- colMeans(samples[,cols,drop=FALSE])
  truth <- Strue[i,,t]
  error <- sqrt(sum((est-truth)^2))
  counter <- counter+1L
  location_rows[[counter]] <- data.frame(id=i,year=t,
    true_x=truth[1]+offset["x"],true_y=truth[2]+offset["y"],
    post_mean_x=est[1]+offset["x"],post_mean_y=est[2]+offset["y"],
    position_error_m=error,
    captured_in_year=any(y[i,t,,]>0))
  loc_error <- c(loc_error,error)
}
locations <- do.call(rbind,location_rows)
rownames(locations) <- NULL
write.csv(locations,file.path(out,"annual_location_recovery.csv"),
          row.names=FALSE)
write.csv(data.frame(p0=as.numeric(p0draw)),
          file.path(out,"posterior_p0.csv"),row.names=FALSE)
write.csv(data.frame(detector=det$Sett_Clean,x=det$x,y=det$y),
          file.path(out,"detectors_used.csv"),row.names=FALSE)
saveRDS(list(model="V12I03 spatial synthetic smoke",
             p0_true=p0_true,sigma_det=sigma_det,sigma_move=sigma_move,
             true_positions=Strue,y=y,detectors=det,
             posterior_samples=samples,location_recovery=locations),
        file.path(out,"smoke_fit.rds"))
cat("Median annual position error:",
    round(median(loc_error),1),"m\n")
cat("Median error for years with live detections:",
    round(median(locations$position_error_m[locations$captured_in_year]),1),"m\n")
cat("Saved:",out,"\n")
cat("NOTE: demographic parameters NOT fitted; this is spatial smoke only.\n")
