#!/usr/bin/env Rscript
# Independent compiled gates before the real-data smoke; no data/DB needed.
r_only<-identical(Sys.getenv("V12K_CHECK_R_ONLY","0"),"1")
if(r_only) {
 nimbleFunction<-function(run)run;registerDistributions<-function(...)NULL
 returnType<-function(...)NULL
} else suppressPackageStartupMessages(library(nimble))
source("scripts/ModularFitting/Woodchester_V12K_Likelihood.R",local=.GlobalEnv)
source("scripts/ModularFitting/Woodchester_V12K_Covariates.R",local=.GlobalEnv)
source("scripts/ModularFitting/Woodchester_V12K_Captures.R",local=.GlobalEnv)
compile<-function(f)if(r_only)f else compileNimble(f,showCompilerOutput=TRUE)
cd<-compile(dV12Covariate);ce<-compile(v12k_emission);cr<-compile(v12k_rates)
enumerate<-function(F,k=1L,state=1L) {
 if(k>length(F))return(0)
 v<-numeric(0)
 for(s in 1:4)if(is.finite(F[[k]][state,s]))
  v<-c(v,F[[k]][state,s]+enumerate(F,k+1L,s))
 if(!length(v))return(-Inf)
 Reduce(v12k_logadd,v)
}
cases<-0L
for(TT in 1:2)for(w in 1:10) {
 p<-list(phi=seq(.73,.91,length.out=TT),rd=seq(.05,.25,length.out=TT),dd=.3,
  entry_weight=rep(1,TT),gamma=.2,gamma_initial=.4,psi=.8,qrec=.15,
  sigma_res=.05,sigma_high=.8)
 S<-cbind(seq(0,.1,length.out=TT),seq(0,.05,length.out=TT))
 ell<-matrix(log(.8),TT,4);pos<-rec<-risk<-forced<-matrix(0,TT,4)
 if(w %in% c(2,3,4,5,6)) {pos[1,1]<-1;ell[1,1]<-log(.2)}
 if(w==3) {rec[TT,4]<-1;risk[,]<-1}
 if(w==4) {rec[1,1]<-1;risk[,]<-1;pos[TT,4]<-1}
 if(w==5)S[,1]<-3
 if(w==6) {rec[1,1]<-1;rec[TT,4]<-1;risk[,]<-1}
 if(w==7) {pos[TT,4]<-1;ell[TT,4]<-log(.1)}
 if(w==8) {pos[1,1]<-1;forced[1,1]<-1;ell[,]<-0}
 if(w==9) {p$entry_weight[1]<-0;pos[TT,4]<-1;ell[TT,4]<-log(.1)}
 if(w==10)p$entry_weight[]<-0
 bounds<-c(-2,2,-2,2);refsd<-4
 F<-v12k_factors_R(S,ell,pos,rec,risk,forced,p,bounds,refsd)
 exact<-log(p$psi)+enumerate(F)
 if(sum(pos)+sum(rec)==0)exact<-v12k_logadd(exact,log1p(-p$psi))
 args<-list(x=1,S=S,ell=ell,positive=pos,recovery=rec,at_risk=risk,forced=forced,
  phi=p$phi,gamma=p$gamma,gamma_initial=p$gamma_initial,psi=p$psi,rd=p$rd,
  dd=p$dd,entry_weight=p$entry_weight,qrec=p$qrec,sigma_res=p$sigma_res,
  sigma_high=p$sigma_high,bounds=bounds,reference_sd=refsd,TT=as.integer(TT),log=1L)
 for(fn in list(dV12Covariate,cd)) {
  got<-do.call(fn,args)
  if(is.infinite(exact))stopifnot(identical(got,exact))
  else stopifnot(is.finite(got),abs(got-exact)<1e-8)
 }
 cases<-cases+1L
}
X<-rbind(c(0,0),c(.2,0));av<-matrix(1,2,4)
marks<-rbind(c(1,2,1),c(1,3,1),c(2,3,1),c(0,0,0))
ea<-list(sx=.03,sy=.02,X=X,availability=av,captures=marks,p=rep(.4,4),
 survey=rep(1,4),sigma=.15,aux=matrix(0,4,4),aux_sd=.25)
gg<-exp(-rowSums(sweep(X,2,c(.03,.02))^2)/(2*.15^2));h<--log(.6)*sum(gg)
expected<-c(-h,log(-expm1(-h))+log(gg[1]/sum(gg)),
 log(-expm1(-h))+sum(log(gg/sum(gg))),-h)
stopifnot(max(abs(do.call(ce,ea)-expected))<1e-10)

# Independent dense observation calculation, including impossible captures.
dense_emission<-function(ct,sx,sy,X,availability,p,survey,sigma,aux,aux_sd) {
 if(any(ct>0 & availability<.5))return(rep(-Inf,4L))
 lg<- -rowSums(sweep(X,2,c(sx,sy))^2)/(2*sigma^2)
 mass<-colSums(availability*exp(lg))
 hazard<- -log(1-p)*mass
 nc<-colSums(ct)
 ans<-numeric(4L)
 surveyed<-survey>.5
 ans[surveyed]<- -hazard[surveyed]
 detected<-surveyed & nc>0
 ans[detected & hazard<=0]<- -Inf
 ok<-detected & hazard>0
 ans[ok]<-log(-expm1(-hazard[ok]))+colSums(ct*lg)[ok]-nc[ok]*log(mass[ok])
 ans-aux[,1]*log(2*pi*aux_sd^2)-
  (aux[,4]-2*sx*aux[,2]-2*sy*aux[,3]+aux[,1]*(sx^2+sy^2))/(2*aux_sd^2)
}
set.seed(20261112)
ct<-array(0,c(12L,4L,9L,4L))
ct[sample.int(length(ct),90L)]<-sample.int(4L,90L,replace=TRUE)
input<-list(N=12L,T=4L,J=9L,counts=ct)
selected<-c(8L,1L,12L,4L,7L)
packed<-v12k_pack_captures(input,selected,7L)
sparse<-input
sparse$capture_events<-v12k_capture_events(input)
sparse$counts<-NULL
stopifnot(identical(packed,v12k_pack_captures(sparse,selected,7L)))
empty<-input
empty$counts[]<-0
stopifnot(identical(dim(v12k_pack_captures(empty,selected,7L)$packed),c(7L,4L,1L,3L)))
for(i in 1:7)for(t in 1:4) {
 original<-matrix(0,9L,4L)
 if(i<=length(selected))original<-ct[selected[i],t,,]
 marks<-matrix(packed$packed[i,t,,,drop=FALSE],ncol=3L)
 used<-marks[,1]>0
 recovered<-matrix(0,9L,4L)
 recovered[marks[used,1:2,drop=FALSE]]<-marks[used,3]
 stopifnot(identical(recovered,original))
 av<-matrix(as.numeric(runif(36)>.35),9L,4L)
 av[original>0]<-1
 if(any(used) && t==4L)av[marks[which(used)[1],1],marks[which(used)[1],2]]<-0
 points<-matrix(rnorm(4,sd=.2),2L,2L)
 aux<-matrix(0,4L,4L)
 aux[3,]<-c(nrow(points),colSums(points),sum(points^2))
 args<-list(sx=.03,sy=.02,X=matrix(rnorm(18,sd=.2),9L,2L),availability=av,
  p=c(.4,1e-10,0,.7),survey=c(1,1,1,0),sigma=.15,aux=aux,aux_sd=.25)
 want<-do.call(dense_emission,c(list(ct=original),args))
 for(fn in list(v12k_emission,ce)) {
  got<-do.call(fn,c(list(captures=marks),args))
  stopifnot(identical(is.finite(got),is.finite(want)),
   all(got[!is.finite(got)]==want[!is.finite(want)]),
   all(abs(got[is.finite(got)]-want[is.finite(want)])<1e-10))
 }
}
g<-c(alpha_phi=qlogis(.86),alpha_rd=qlogis(.08),alpha_dd=qlogis(.3),
 beta_phi_sex=-.2,beta_rd_sex=.4,beta_dd_sex=.2,sigma_individual=.7,
 gamma=.2,gamma_initial=.4,psi=.8,qrec=.15,age_rate_initial=.4,age_rate_entry=.7,log_sigma_high=log(.8),
 log_sigma_det=log(.15),beta_highscale_sex=.2,beta_sigma_sex=.1,beta_p_sex=.2,
 setNames(c(-.3,.1,-.5),paste0("beta_phi_age[",1:3,"]")),
 setNames(c(.4,.2,-.1),paste0("beta_move_age[",1:3,"]")))
for(sx in 0:1)for(u in c(-1.4,.9)) {
 years<-as.numeric(1998:2008)
 p<-v12k_individual_parameters(g,sx,2000,u,years,.05)
 ra<-list(birth=2000,sex=as.numeric(sx),u=u,sd_ind=g["sigma_individual"],years=years,
  alpha_phi=g["alpha_phi"],beta_phi_sex=g["beta_phi_sex"],
  beta_phi_age=unname(g[paste0("beta_phi_age[",1:3,"]")]),
  alpha_rd=g["alpha_rd"],beta_rd_sex=g["beta_rd_sex"],
  beta_move_age=unname(g[paste0("beta_move_age[",1:3,"]")]),
  age_rate_initial=g["age_rate_initial"],age_rate_entry=g["age_rate_entry"],
  max_entry_age=30,n_birth=length(years)+30,TT=length(years))
 stopifnot(max(abs(do.call(cr,ra)-cbind(p$phi,p$rd,p$entry_weight)))<1e-12)
}
live<-data.frame(tattoo=c("A","B","C","D"),sex_clean=c("FEMALE","M","UNKNOWN",NA),
 age_first_capture_clean=c("CUB","YEARLING","ADULT",NA),year_first_capture=c(1999,2000,2001,NA),
 capture_date=as.Date(c("1999-06-01","2000-06-01","2001-06-01","2002-06-01")))
m<-v12k_metadata(live,live$tattoo,1999:2008)$metadata
stopifnot(identical(m$birth_year_data,c(1999L,1999L,NA_integer_,NA_integer_)),
 m$adult_constraint[3]==1,is.na(m$sex_data[3]),is.na(m$sex_data[4]))
for(TT in 1:2) {
 years<-as.numeric(2000+seq_len(TT)-1L);pad<-4;pool<-seq(min(years)-pad,max(years));NB<-length(pool)
 vals<-numeric(NB);rs<-sqrt(16/(2*pi))
 for(ii in seq_along(pool)) {
  age<-years-pool[ii];ar<-c(.4,rep(.7,TT-1L))
  ew<-ifelse(age>=0&age<=pad,NB*ar*(1-ar)^age/(1-(1-ar)^(pad+1)),0)
  zero<-matrix(0,TT,4)
  args<-list(x=1,S=matrix(0,TT,2),ell=zero,positive=zero,recovery=zero,at_risk=zero,forced=zero,
   phi=rep(.86,TT),gamma=.2,gamma_initial=.4,psi=.8,rd=rep(.1,TT),dd=.3,
   entry_weight=ew,qrec=.15,sigma_res=rs,sigma_high=rs,bounds=c(-2,2,-2,2),
   reference_sd=rs,TT=as.integer(TT),log=0L)
  vals[ii]<-do.call(cd,args)
 }
 stopifnot(abs(mean(vals)-1)<1e-10)
}
cat("PASS:",cases,"state-path cases, 28 sparse/dense emission cases, 4 covariate cases, metadata and birth-reference normalization. Compiled:",!r_only,"\n")
