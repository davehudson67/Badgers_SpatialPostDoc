#!/usr/bin/env Rscript
# Run standalone before real-data compilation. No database/data dependencies.
r_only<-identical(Sys.getenv("V12J_CHECK_R_ONLY","0"),"1")
if(r_only) {
 # Execute the actual run bodies as R functions on hosts without NIMBLE.
 nimbleFunction<-function(run)run
 registerDistributions<-function(...)invisible(NULL)
 returnType<-function(...)invisible(NULL)
} else suppressPackageStartupMessages(library(nimble))
source("scripts/ModularFitting/Woodchester_V12J_Likelihood.R",local=.GlobalEnv)
compiled<-if(r_only)dV12Joint else tryCatch(compileNimble(dV12Joint,showCompilerOutput=TRUE),error=function(e) {
 try(printErrors(),silent=TRUE);stop(e)
})
compiled_emission<-if(r_only)v12j_emission else compileNimble(v12j_emission,showCompilerOutput=TRUE)
p<-list(phi=.86,gamma=.2,gamma_initial=.4,psi=.8,rd=.075,dd=.3,qrec=.15,
 sigma_res=.05,sigma_high=.8)
bounds<-c(-2,2,-2,2);refsd<-4
# Independent recursive summation visits only feasible state paths.
enumerate<-function(F,k=1L,state=1L) {
 if(k>length(F))return(0)
 val<-numeric(0)
 for(s in 1:4)if(is.finite(F[[k]][state,s]))
  val<-c(val,F[[k]][state,s]+enumerate(F,k+1L,s))
 if(!length(val))return(-Inf)
 Reduce(v12j_logadd,val)
}
cases<-0L
for(TT in 1:2)for(which in 1:8) {
 S<-cbind(seq(0,.1,length.out=TT),seq(0,.05,length.out=TT))
 ell<-matrix(log(.8),TT,4);pos<-rec<-risk<-forced<-matrix(0,TT,4)
 if(which %in% c(2,3,4,5,6)) {pos[1,1]<-1;ell[1,1]<-log(.2)}
 if(which==3) {rec[TT,4]<-1;risk[,]<-1}
 if(which==4) {rec[1,1]<-1;risk[,]<-1;pos[TT,4]<-1}
 if(which==5)S[,1]<-3 # no entry position in support
 if(which==6) {rec[1,1]<-1;rec[TT,4]<-1;risk[,]<-1}
 if(which==7) {pos[TT,4]<-1;ell[TT,4]<-log(.1)}
 if(which==8) {pos[1,1]<-1;forced[1,1]<-1;ell[,]<-0}
 F<-v12j_factors_R(S,ell,pos,rec,risk,forced,p,bounds,refsd)
 exact<-log(p$psi)+enumerate(F)
 if(sum(pos)+sum(rec)==0)exact<-v12j_logadd(exact,log1p(-p$psi))
 args<-list(x=1,S=S,ell=ell,positive=pos,recovery=rec,at_risk=risk,forced=forced,
  phi=p$phi,gamma=p$gamma,gamma_initial=p$gamma_initial,psi=p$psi,rd=p$rd,dd=p$dd,qrec=p$qrec,
  sigma_res=p$sigma_res,sigma_high=p$sigma_high,bounds=bounds,
  reference_sd=refsd,TT=as.integer(TT),log=1L)
 values<-c(do.call(dV12Joint,args),do.call(compiled,args),
  v12j_forward_R(S,ell,pos,rec,risk,forced,p,bounds,refsd))
 same<-vapply(values,function(x) {
  if(is.infinite(exact))return(identical(x,exact))
  is.finite(x)&&abs(x-exact)<1e-8
 },logical(1))
 if(!all(same))stop("Forward/enumeration disagreement: ",TT,"/",which)
 cases<-cases+1L
}
# Conditional trap-location marks and saturated-network no-capture check.
X<-rbind(c(0,0),c(.2,0));av<-matrix(1,2,4);ct<-matrix(0,2,4)
ct[1,2]<-1;ct[,3]<-c(1,1)
emargs<-list(sx=.03,sy=.02,X=X,availability=av,counts=ct,
 p=rep(.4,4),survey=rep(1,4),sigma=.15,aux=matrix(0,4,4),aux_sd=.25)
g<-exp(-rowSums(sweep(X,2,c(.03,.02))^2)/(2*.15^2))
h<--log(.6)*sum(g)
expected<-c(-h,log(-expm1(-h))+log(g[1]/sum(g)),
 log(-expm1(-h))+sum(log(g/sum(g))),-h)
stopifnot(max(abs(do.call(v12j_emission,emargs)-expected))<1e-10,
 max(abs(do.call(compiled_emission,emargs)-expected))<1e-10)
cat("PASS:",cases,"forward / exact-enumeration cases; spatial emissions matched. Compiled checks:",!r_only,"\n")
