#!/usr/bin/env Rscript
# First executable combined REAL-data likelihood; developmental, not validated.
for(pkg in c("nimble","digest"))if(!requireNamespace(pkg,quietly=TRUE))stop("Install ",pkg)
suppressPackageStartupMessages(library(nimble))
source("scripts/ModularFitting/Woodchester_V12K_Likelihood.R",local=.GlobalEnv)
source("scripts/ModularFitting/Woodchester_V12K_Covariates.R",local=.GlobalEnv)
input<-Sys.getenv("V12K_INPUT",""); out<-Sys.getenv("V12K_OUT","")
if(!nzchar(input)||!nzchar(out)||file.exists(out))stop("Set input and NEW V12K_OUT")
getint<-function(key,default,lo=0L) {
 x<-as.integer(Sys.getenv(key,as.character(default)))
 if(is.na(x)||x<lo)stop("Invalid ",key); x
}
maxn<-getint("V12K_MAX_BADGERS",0)
aug<-getint("V12K_AUGMENT",200)
seed<-getint("V12K_SEED",20261111,1)
niter<-getint("V12K_NITER",2000,20); burn<-getint("V12K_NBURN",1000,10)
thin<-getint("V12K_THIN",2,1)
if(burn>=niter||thin>niter-burn)stop("Invalid MCMC schedule")
b<-readRDS(input)
if(is.null(b$metadata)||is.null(b$birth_years))stop("Use V12K covariate inputs")
if(is.null(b$adult_min_age))b$adult_min_age<-1L
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
sigma_res<-as.numeric(Sys.getenv("V12K_RESIDENT_MEAN_M","50"))/1000/sqrt(pi/2)
auxsd<-as.numeric(Sys.getenv("V12K_AUX_SD_M","250"))/1000
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
# Metadata for the same observed cohort plus properly latent augmentation.
NB<-length(b$birth_years)
meta<-b$metadata[selected,,drop=FALSE]
if(!identical(meta$tattoo,b$ids[selected]))stop("Covariate tattoo alignment failure")
sex_data<-birth_data<-rep(NA_real_,NN)
sex_data[seq_len(Nobs)]<-meta$sex_data
birth_data[seq_len(Nobs)]<-match(meta$birth_year_data,b$birth_years)
adult<-rep(0,NN);adult[seq_len(Nobs)]<-meta$adult_constraint
first_age_year<-rep(b$years[1],NN)
fy<-meta$source_first_year;fy[is.na(fy)]<-meta$earliest_model_live_year[is.na(fy)]
first_age_year[seq_len(Nobs)]<-fy
sex_init<-rbinom(NN,1,.5);sex_init[!is.na(sex_data)]<-NA_real_
birth_init<-sample.int(NB,NN,replace=TRUE)
for(i in seq_len(Nobs)) {
 guess<-min(max(meta$earliest_model_live_year[i]-3L,min(b$birth_years)),max(b$birth_years))
 if(adult[i])guess<-min(guess,first_age_year[i]-b$adult_min_age)
 birth_init[i]<-match(guess,b$birth_years)
}
birth_init[!is.na(birth_data)]<-NA_real_
NP<-max(b$period)
code<-nimbleCode({
 phi0 ~ dbeta(2,2)
 alpha_phi <- log(phi0/(1-phi0))
 gamma ~ dbeta(1,4)
 gamma_initial ~ dbeta(1,1)
 psi ~ dbeta(1,1)
 rd0 ~ dbeta(1,9)
 dd0 ~ dbeta(2,4)
 alpha_rd <- log(rd0/(1-rd0))
 alpha_dd <- log(dd0/(1-dd0))
 qrec ~ dbeta(1,9)
 sex_prop ~ dbeta(1,1)
 age_rate_initial ~ dbeta(2,2)
 age_rate_entry ~ dbeta(2,2)
 sigma_individual ~ dexp(1)
 beta_phi_sex ~ dnorm(0,sd=1)
 beta_rd_sex ~ dnorm(0,sd=1)
 beta_dd_sex ~ dnorm(0,sd=1)
 beta_highscale_sex ~ dnorm(0,sd=.5)
 beta_sigma_sex ~ dnorm(0,sd=.75)
 beta_p_sex ~ dnorm(0,sd=1)
 for(g in 1:3) {
  beta_phi_age[g] ~ dnorm(0,sd=.7)
  beta_move_age[g] ~ dnorm(0,sd=1)
 }
 log_sigma_high ~ dnorm(log(.8),sd=1)
 log_sigma_det ~ dnorm(log(.15),sd=.75)
 alpha_p ~ dnorm(-1.38629436112,sd=1.5)
 season[1] <- 0
 for(q in 2:4)season[q] ~ dnorm(0,sd=.7)
 era[1] <- 0
 for(e in 2:NP)era[e] ~ dnorm(0,sd=.7)
 for(sx in 1:2) {
  sigma_high[sx] <- sigma_res+exp(log_sigma_high+beta_highscale_sex*(sx-1))
  sigma_det[sx] <- exp(log_sigma_det+beta_sigma_sex*(sx-1))
  dd[sx] <- ilogit(alpha_dd+beta_dd_sex*(sx-1))
  for(t in 1:TT)for(q in 1:4)
   p[sx,t,q] <- ilogit(alpha_p+beta_p_sex*(sx-1)+season[q]+era[period[t]])
 }
 for(j in 1:JJ) {
  X[j,1] ~ dunif(bounds[1],bounds[2])
  X[j,2] ~ dunif(bounds[3],bounds[4])
 }
 for(i in 1:NN) {
  sex[i] ~ dbern(sex_prop)
  sex_group[i] <- sex[i]+1
  birth_index[i] ~ dcat(birth_prior[1:NB])
  birth_year[i] <- birth_min+birth_index[i]-1
  valid_age[i] <- (1-age_is_adult[i])+age_is_adult[i]*step(first_age_year[i]-birth_year[i]-adult_min_age)
  age_ok[i] ~ dbern(valid_age[i])
  u_move[i] ~ dnorm(0,sd=1)
  rates[i,1:TT,1:3] <- v12k_rates(birth_year[i],sex[i],u_move[i],sigma_individual,
   years[1:TT],alpha_phi,beta_phi_sex,beta_phi_age[1:3],
   alpha_rd,beta_rd_sex,beta_move_age[1:3],age_rate_initial,age_rate_entry,max_entry_age,NB,TT)
  for(t in 1:TT) {
   S[i,t,1] ~ dnorm(0,sd=reference_sd)
   S[i,t,2] ~ dnorm(0,sd=reference_sd)
   ell[i,t,1:4] <- v12k_emission(S[i,t,1],S[i,t,2],X[1:JJ,1:2],
    availability[1:JJ,1:4,t],counts[i,t,1:JJ,1:4],p[sex_group[i],t,1:4],
    survey[i,t,1:4],sigma_det[sex_group[i]],aux[i,t,1:4,1:4],aux_sd)
  }
  history[i] ~ dV12Covariate(S[i,1:TT,1:2],ell[i,1:TT,1:4],
   positive[i,1:TT,1:4],recovery[i,1:TT,1:4],at_risk[i,1:TT,1:4],forced[i,1:TT,1:4],
   rates[i,1:TT,1],gamma,gamma_initial,psi,rates[i,1:TT,2],dd[sex_group[i]],rates[i,1:TT,3],
   qrec,sigma_res,sigma_high[sex_group[i]],bounds[1:4],reference_sd,TT)
 }
})
if(NP==1L)stop("First executable requires >=2 five-year periods; use full study window")
constants<-list(NN=NN,TT=TT,JJ=JJ,NP=NP,period=b$period,
 NB=NB,birth_min=as.numeric(min(b$birth_years)),birth_prior=rep(1/NB,NB),max_entry_age=b$birth_padding,
 age_is_adult=adult,adult_min_age=b$adult_min_age,first_age_year=first_age_year,years=as.numeric(b$years),
 availability=b$availability,counts=counts,positive=pos,recovery=rec,
 at_risk=risk,forced=forced,survey=survey,aux=aux,bounds=b$bounds,
 reference_sd=refsd,sigma_res=sigma_res,aux_sd=auxsd)
inits<-list(phi0=.85,gamma=.08,gamma_initial=.15,psi=.8,rd0=.05,dd0=.3,qrec=.1,
 sex_prop=.5,age_rate_initial=.4,age_rate_entry=.6,sigma_individual=.4,beta_phi_sex=0,beta_rd_sex=0,beta_dd_sex=0,
 beta_highscale_sex=0,beta_sigma_sex=0,beta_p_sex=0,
 beta_phi_age=rep(0,3),beta_move_age=rep(0,3),u_move=rnorm(NN,0,.05),
 sex=sex_init,birth_index=birth_init,
 log_sigma_high=log(.8),log_sigma_det=log(.15),alpha_p=qlogis(.25),
 season=c(NA,0,0,0),era=c(NA,rep(0,NP-1)),S=Sinit,X=Xinit)
inits$X[b$detectors$known,]<-NA_real_
dir.create(out,recursive=TRUE)
cat("=== V12K REAL JOINT AGE / SEX / INDIVIDUAL MOVEMENT MODEL ===\n")
cat("Observed:",Nobs,"augmented:",aug,"years:",TT,"detectors:",JJ,"\n")
cat("Coverage:",b$coverage,"mortality:",b$mortality,"\n")
cat("Unknown detector XY:",sum(!b$detectors$known),"\n")
model<-nimbleModel(code,constants=constants,data=list(history=rep(1,NN),X=Xdata,
 sex=sex_data,birth_index=birth_data,age_ok=rep(1,NN)),
 inits=inits,check=TRUE,calculate=TRUE)
lp<-model$calculate()
if(!is.finite(lp)) {
 model$initializeInfo();stop("Nonfinite initial joint density; no MCMC launched")
}
cat("Initial log density:",lp,"\n")
monitors<-c("phi0","alpha_phi","gamma","gamma_initial","psi","rd0","dd0","alpha_rd","alpha_dd",
 "qrec","sex_prop","age_rate_initial","age_rate_entry","sigma_individual","beta_phi_sex","beta_rd_sex","beta_dd_sex",
 "beta_highscale_sex","beta_sigma_sex","beta_p_sex","log_sigma_high","log_sigma_det","alpha_p",
 sprintf("beta_phi_age[%d]",1:3),sprintf("beta_move_age[%d]",1:3),
 sprintf("season[%d]",2:4),sprintf("era[%d]",2:NP))
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
conf$addMonitors2(c("S","X","sex","birth_index","u_move"))
# Spatial samples are thinned separately to keep full-cohort outputs manageable.
thin2<-thin*max(1L,ceiling((niter-burn)/getint("V12K_SPATIAL_DRAWS",100,1)/thin))
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
 model="V12K age sex individual movement",birth_padding=b$birth_padding,
 initial_log_density=lp,session=capture.output(sessionInfo())),file.path(out,"joint_fit.rds"))
q<-t(apply(as.matrix(sam$samples),2,function(x)c(mean=mean(x),
 q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)))))
write.csv(data.frame(parameter=rownames(q),q),file.path(out,"parameter_summary.csv"),row.names=FALSE)
print(q,digits=4)
cat("Saved:",out,"\nExecution success is not convergence or biological validation.\n")
