#!/usr/bin/env Rscript
# First executable combined REAL-data likelihood; developmental, not validated.
for(pkg in c("nimble","digest"))if(!requireNamespace(pkg,quietly=TRUE))stop("Install ",pkg)
suppressPackageStartupMessages(library(nimble))
source("scripts/ModularFitting/Woodchester_V12J_Likelihood.R",local=.GlobalEnv)
input<-Sys.getenv("V12J_INPUT",""); out<-Sys.getenv("V12J_OUT","")
if(!nzchar(input)||!nzchar(out)||file.exists(out))stop("Set input and NEW V12J_OUT")
getint<-function(key,default,lo=0L) {
 x<-as.integer(Sys.getenv(key,as.character(default)))
 if(is.na(x)||x<lo)stop("Invalid ",key); x
}
maxn<-getint("V12J_MAX_BADGERS",0)
aug<-getint("V12J_AUGMENT",200)
seed<-getint("V12J_SEED",20261111,1)
niter<-getint("V12J_NITER",2000,20); burn<-getint("V12J_NBURN",1000,10)
thin<-getint("V12J_THIN",2,1)
if(burn>=niter||thin>niter-burn)stop("Invalid MCMC schedule")
b<-readRDS(input)
selected<-seq_len(b$N)
if(maxn>0 && maxn<b$N) {
 # Deterministic stratification by first observation year for compilation only.
 # Full detector network and coverage masks ALWAYS retained.
 first<-apply(b$positive,1,function(z)min(which(rowSums(z)>0)))
 oo<-order(first,b$ids); selected<-oo[unique(round(seq(1,b$N,length.out=maxn)))]
}
Nobs<-length(selected); NN<-Nobs+aug; TT<-b$T; JJ<-b$J
if(NN<2||TT<2)stop("Insufficient dimensions")
counts<-array(0,c(NN,TT,JJ,4)); pos<-rec<-risk<-array(0,c(NN,TT,4))
forced<-array(0,c(NN,TT,4))
aux<-array(0,c(NN,TT,4,4)); survey<-array(0,c(NN,TT,4))
counts[seq_len(Nobs),,,]<-b$counts[selected,,,,drop=FALSE]
pos[seq_len(Nobs),,]<-b$positive[selected,,,drop=FALSE]
rec[seq_len(Nobs),,]<-b$recovery[selected,,,drop=FALSE]
risk[seq_len(Nobs),,]<-b$at_risk[selected,,,drop=FALSE]
forced[seq_len(Nobs),,]<-b$forced[selected,,,drop=FALSE]
aux[seq_len(Nobs),,,]<-b$aux[selected,,,,drop=FALSE]
survey[seq_len(Nobs),,]<-b$survey[selected,,,drop=FALSE]
if(aug>0)for(i in (Nobs+1L):NN)
 survey[i,,]<-apply(b$availability,c(3,2),function(z)as.integer(any(z>0)))
refsd<-max(diff(b$bounds[1:2]),diff(b$bounds[3:4]))
sigma_res<-as.numeric(Sys.getenv("V12J_RESIDENT_MEAN_M","50"))/1000/sqrt(pi/2)
auxsd<-as.numeric(Sys.getenv("V12J_AUX_SD_M","250"))/1000
if(!is.finite(sigma_res)||sigma_res<=0||!is.finite(auxsd)||auxsd<=0)stop("Invalid scales")
# Known detector coordinates are data; only unknown detector positions sample.
Xdata<-as.matrix(b$detectors[,c("x","y")]); storage.mode(Xdata)<-"double"
Xinit<-Xdata; Xinit[!is.finite(Xinit)]<-0
set.seed(seed)
Sinit<-array(0,c(NN,TT,2))
for(i in seq_len(NN)) {
 if(i<=Nobs) {
  anchors<-matrix(NA_real_,TT,2)
  for(t in seq_len(TT)) {
   n<-apply(counts[i,t,,,drop=FALSE],3,sum)
   # counts subset dimensions N,T,J,Q; third margin is detector.
   jj<-which(n>0 & b$detectors$known)
   if(length(jj))anchors[t,]<-colSums(Xdata[jj,,drop=FALSE]*n[jj])/sum(n[jj])
   aq<-aux[i,t,,1]
   if(any(aq>0))anchors[t,]<-c(sum(aux[i,t,,2]),sum(aux[i,t,,3]))/sum(aq)
  }
  kk<-which(is.finite(anchors[,1]))
  for(d in 1:2) {
   if(length(kk)>1)Sinit[i,,d]<-approx(kk,anchors[kk,d],xout=seq_len(TT),rule=2)$y
   else if(length(kk)==1)Sinit[i,,d]<-anchors[kk,d]
  }
 } else {
  Sinit[i,,1]<-runif(1,b$bounds[1],b$bounds[2])
  Sinit[i,,2]<-runif(1,b$bounds[3],b$bounds[4])
 }
 Sinit[i,,]<-Sinit[i,,]+rnorm(TT*2,0,.015)
}
for(j in which(!b$detectors$known)) {
 ij<-which(apply(counts[seq_len(Nobs),,j,,drop=FALSE],1,sum)>0)
 if(length(ij))Xinit[j,]<-apply(Sinit[ij,,,drop=FALSE],3,mean)
 Xinit[j,1]<-min(max(Xinit[j,1],b$bounds[1]+.001),b$bounds[2]-.001)
 Xinit[j,2]<-min(max(Xinit[j,2],b$bounds[3]+.001),b$bounds[4]-.001)
}
# One-period arrays still have a well-defined reference level (five-year eras).
NP<-max(b$period)
code<-nimbleCode({
 phi ~ dbeta(2,2)
 gamma ~ dbeta(1,4)
 gamma_initial ~ dbeta(1,1)
 psi ~ dbeta(1,1)
 rd ~ dbeta(1,9)
 dd ~ dbeta(2,4)
 qrec ~ dbeta(1,9)
 log_sigma_high ~ dnorm(log(0.8),sd=1)
 sigma_high <- sigma_res+exp(log_sigma_high)
 log_sigma_det ~ dnorm(log(0.15),sd=0.75)
 sigma_det <- exp(log_sigma_det)
 alpha_p ~ dnorm(-1.38629436112,sd=1.5)
 season[1] <- 0
 for(q in 2:4)season[q] ~ dnorm(0,sd=0.7)
 era[1] <- 0
 for(e in 2:NP)era[e] ~ dnorm(0,sd=0.7)
 for(t in 1:TT)for(q in 1:4)
  p[t,q] <- ilogit(alpha_p+season[q]+era[period[t]])
 for(j in 1:JJ) {
  X[j,1] ~ dunif(bounds[1],bounds[2])
  X[j,2] ~ dunif(bounds[3],bounds[4])
 }
 for(i in 1:NN) {
  for(t in 1:TT) {
   S[i,t,1] ~ dnorm(0,sd=reference_sd)
   S[i,t,2] ~ dnorm(0,sd=reference_sd)
   ell[i,t,1:4] <- v12j_emission(S[i,t,1],S[i,t,2],X[1:JJ,1:2],
    availability[1:JJ,1:4,t],counts[i,t,1:JJ,1:4],p[t,1:4],
    survey[i,t,1:4],sigma_det,aux[i,t,1:4,1:4],aux_sd)
  }
  history[i] ~ dV12Joint(S[i,1:TT,1:2],ell[i,1:TT,1:4],
   positive[i,1:TT,1:4],recovery[i,1:TT,1:4],at_risk[i,1:TT,1:4],forced[i,1:TT,1:4],
   phi,gamma,gamma_initial,psi,rd,dd,qrec,sigma_res,sigma_high,bounds[1:4],reference_sd,TT)
 }
})
if(NP==1L)stop("First executable requires >=2 five-year periods; use full study window")
constants<-list(NN=NN,TT=TT,JJ=JJ,NP=NP,period=b$period,
 availability=b$availability,counts=counts,positive=pos,recovery=rec,
 at_risk=risk,forced=forced,survey=survey,aux=aux,bounds=b$bounds,
 reference_sd=refsd,sigma_res=sigma_res,aux_sd=auxsd)
inits<-list(phi=.85,gamma=.08,gamma_initial=.15,psi=.8,rd=.05,dd=.3,qrec=.1,
 log_sigma_high=log(.8),log_sigma_det=log(.15),alpha_p=qlogis(.25),
 season=c(NA,0,0,0),era=c(NA,rep(0,NP-1)),S=Sinit,X=Xinit)
inits$X[b$detectors$known,]<-NA_real_
dir.create(out,recursive=TRUE)
cat("=== V12J REAL JOINT SPATIAL / SURVIVAL / ENTRY MODEL ===\n")
cat("Observed:",Nobs,"augmented:",aug,"years:",TT,"detectors:",JJ,"\n")
cat("Coverage:",b$coverage,"mortality:",b$mortality,"\n")
cat("Unknown detector XY:",sum(!b$detectors$known),"\n")
model<-nimbleModel(code,constants=constants,data=list(history=rep(1,NN),X=Xdata),
 inits=inits,check=TRUE,calculate=TRUE)
lp<-model$calculate()
if(!is.finite(lp)) {
 model$initializeInfo();stop("Nonfinite initial joint density; no MCMC launched")
}
cat("Initial log density:",lp,"\n")
monitors<-c("phi","gamma","gamma_initial","psi","rd","dd","qrec","sigma_high","sigma_det",
 "alpha_p",sprintf("season[%d]",2:4),sprintf("era[%d]",2:NP))
conf<-configureMCMC(model,monitors=monitors,enableWAIC=FALSE)
# Joint coordinate updates preserve x/y geometry. The hidden demographic and
# movement states are integrated, so no sticky sampled alive/dead histories.
for(i in seq_len(NN))for(t in seq_len(TT)) {
 nodes<-sprintf("S[%d,%d,%d]",i,t,1:2)
 conf$removeSamplers(nodes)
 conf$addSampler(target=nodes,type="RW_block",silent=TRUE,
                 control=list(scale=.05,propCov=diag(2),adaptive=TRUE))
}
for(j in which(!b$detectors$known)) {
 nodes<-sprintf("X[%d,%d]",j,1:2)
 conf$removeSamplers(nodes)
 conf$addSampler(target=nodes,type="RW_block",silent=TRUE,
                 control=list(scale=.1,propCov=diag(2),adaptive=TRUE))
}
conf$addMonitors2(c("S","X"))
# Spatial samples are thinned separately to keep full-cohort outputs manageable.
thin2<-thin*max(1L,ceiling((niter-burn)/getint("V12J_SPATIAL_DRAWS",100,1)/thin))
mcmc<-buildMCMC(conf)
compiled_model<-tryCatch(compileNimble(model,showCompilerOutput=TRUE),error=function(e) {
 try(printErrors(),silent=TRUE);stop(e)
})
compiled_mcmc<-compileNimble(mcmc,project=model,showCompilerOutput=TRUE)
sam<-runMCMC(compiled_mcmc,niter=niter,nburnin=burn,thin=thin,thin2=thin2,
 nchains=1,setSeed=seed,samplesAsCodaMCMC=FALSE,summary=FALSE,progressBar=FALSE)
if(!is.list(sam)||is.null(sam$samples)||is.null(sam$samples2))
 stop("Unexpected dual-monitor output; inspect NIMBLE version")
if(any(!is.finite(as.matrix(sam$samples))))stop("Nonfinite global samples")
saveRDS(list(samples=as.matrix(sam$samples),spatial=as.matrix(sam$samples2),
 ids=c(b$ids[selected],if(aug>0)paste0("AUGMENTED_",seq_len(aug)) else character(0)),Nobs=Nobs,
 selected=selected,seed=seed,niter=niter,burn=burn,thin=thin,thin2=thin2,
 input=normalizePath(input),input_sha256=digest::digest(input,file=TRUE,algo="sha256"),
 sigma_res=sigma_res,aux_sd=auxsd,reference_sd=refsd,
 initial_log_density=lp,session=capture.output(sessionInfo())),file.path(out,"joint_fit.rds"))
q<-t(apply(as.matrix(sam$samples),2,function(x)c(mean=mean(x),
 q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)))))
write.csv(data.frame(parameter=rownames(q),q),file.path(out,"parameter_summary.csv"),row.names=FALSE)
print(q,digits=4)
cat("Saved:",out,"\nExecution success is not convergence or biological validation.\n")
