#!/usr/bin/env Rscript
# Woodchester V12I-06: NEW synthetic NIMBLE multistate movement-demography fit.
# SCIENTIFIC SMOKE / PARAMETER RECOVERY ONLY, NOT WOODCHESTER ESTIMATES.
#
# Five latent states: 1=not yet entered; 2=core; 3=periphery;
# 4=outside reference monitoring hull (alive); 5=dead.
# State 4 is TEMPORARILY outside the reference monitored hull, NOT
# permanent biological emigration. Entry is not separately identifiable
# as immigration versus recruitment without new evidence.
#
# This experiment assumes a KNOWN synthetic superpopulation N, season-constant
# observation probabilities and known recovery observation probability. These
# assumptions do NOT hold automatically for Woodchester.
#
# Categorical live observations: 1=no encounter, 2=core record, 3=peripheral
# record. Death recovery is a separate binary event emitted only on the
# transition into death. No exact capture location is fitted; use prior
# V11R2 posterior movement as a design reference, not as independent data.
#
# Run from repo root; no Supabase connection, no file overwrites.
# V12I06_N=60 V12I06_T=8 V12I06_NITER=2000 V12I06_NBURN=1000 \
# V12I06_OUT=outputs/v12_immigration_prototype/v12i06_... \
# Rscript scripts/ModularFitting/Woodchester_V12I_06_Core_Periphery_Entry_Survival_Smoke.R

if (!requireNamespace("nimble",quietly=TRUE))
 stop("Install R package nimble")
suppressPackageStartupMessages(library(nimble))
getint<-function(key,default,lower) {
 v<-as.integer(Sys.getenv(key,as.character(default)))
 if(length(v)!=1L||is.na(v)||v<lower)stop("Invalid ",key)
 v
}
N<-getint("V12I06_N",60L,10L)
TT<-getint("V12I06_T",8L,3L)
niter<-getint("V12I06_NITER",2000L,100L)
nburn<-getint("V12I06_NBURN",1000L,50L)
thin<-getint("V12I06_THIN",2L,1L)
seed<-getint("V12I06_SEED",20261110L,1L)
data_seed<-getint("V12I06_DATA_SEED",20261110L,1L)
if(nburn>=niter)stop("NBURN must be less than NITER")
out<-Sys.getenv("V12I06_OUT","")
if(!nzchar(out)||file.exists(out))
 stop("Set V12I06_OUT to a unique NEW output directory")
if(!dir.exists(dirname(out)))dir.create(dirname(out),recursive=TRUE)
truth<-c(gamma=0.16,phi=0.86,core_to_periphery=0.075,
 periphery_to_core=0.055,periphery_to_outside=0.05,
 outside_to_periphery=0.19,p_core=0.42,p_periphery=0.22)
# Fixed, explicitly stated auxiliary information. Not inferred from Woodchester.
pi_entry<-0.55
q_recovery<-0.35
p_outside<-0.000
# Some geometrical overlap between latent zone and recorded trapping location.
core_capture_fraction_core<-0.93
core_capture_fraction_periphery<-0.15
make_transition<-function(p) {
 Q<-matrix(0,5L,5L)
 Q[1,]<-c(1-p["gamma"],p["gamma"]*pi_entry,
           p["gamma"]*(1-pi_entry),0,0)
 Q[2,]<-c(0,p["phi"]*(1-p["core_to_periphery"]),
            p["phi"]*p["core_to_periphery"],0,1-p["phi"])
 Q[3,]<-c(0,p["phi"]*p["periphery_to_core"],
            p["phi"]*(1-p["periphery_to_core"]-p["periphery_to_outside"]),
            p["phi"]*p["periphery_to_outside"],1-p["phi"])
 Q[4,]<-c(0,0,p["phi"]*p["outside_to_periphery"],
            p["phi"]*(1-p["outside_to_periphery"]),1-p["phi"])
 Q[5,]<-c(0,0,0,0,1)
 Q
}
make_emission<-function(p) {
 E<-matrix(0,5L,3L)
 E[1,]<-c(1,0,0)
 E[2,]<-c(1-p["p_core"],p["p_core"]*core_capture_fraction_core,
          p["p_core"]*(1-core_capture_fraction_core))
 E[3,]<-c(1-p["p_periphery"],p["p_periphery"]*core_capture_fraction_periphery,
          p["p_periphery"]*(1-core_capture_fraction_periphery))
 E[4,]<-c(1-p_outside,p_outside*.5,p_outside*.5)
 E[5,]<-c(1,0,0)
 E
}
if(any(abs(rowSums(make_transition(truth))-1)>1e-12)||
   any(abs(rowSums(make_emission(truth))-1)>1e-12))
 stop("Simulator probability rows invalid")
set.seed(data_seed)
Qtruth<-make_transition(truth);Etruth<-make_emission(truth)
state_truth<-matrix(1L,N,TT)
y<-matrix(1L,N,TT) # y=1 means no capture
recovery<-matrix(0L,N,TT)
for(i in seq_len(N))for(t in 2:TT) {
 previous<-state_truth[i,t-1]
 current<-sample.int(5L,1L,prob=Qtruth[previous,])
 state_truth[i,t]<-current
 y[i,t]<-sample.int(3L,1L,prob=Etruth[current,])
 recovery[i,t]<-as.integer(previous!=5L && current==5L &&
                             runif(1)<q_recovery)
}
if(any(y[state_truth==5L]>1L) || any(y[state_truth==1L]>1L) ||
   any(recovery==1L & state_truth!=5L))
 stop("Simulator biological constraints failed")
# Model transition and observation matrices constructed deterministically
# inside NIMBLE; all 5 rows are stochastic for parameter values in support.
# Restrict periphery exit + return-to-core to sum <=1 via parameterisation.
# Estimable params: gamma, phi, core exit, peripheral -> core, peripheral ->
# outside, outside return, detection in core/periphery.
# p3_to_outside=(1-p3_to_core)*e3_outside gives independent unit-beta support.
code<-nimble::nimbleCode({
 gamma~dbeta(2,10)
 phi~dbeta(8,2)
 c_to_p~dbeta(2,22)
 p_to_c~dbeta(2,28)
 e_p_out~dbeta(2,18)
 out_to_p~dbeta(2,8)
 pc~dbeta(3,4)
 pp~dbeta(2,7)
 p_to_out<- (1-p_to_c)*e_p_out

 A[1,1]<-1-gamma
 A[1,2]<-gamma*pi_entry
 A[1,3]<-gamma*(1-pi_entry)
 A[1,4]<-0
 A[1,5]<-0
 A[2,1]<-0
 A[2,2]<-phi*(1-c_to_p)
 A[2,3]<-phi*c_to_p
 A[2,4]<-0
 A[2,5]<-1-phi
 A[3,1]<-0
 A[3,2]<-phi*p_to_c
 A[3,3]<-phi*(1-p_to_c-p_to_out)
 A[3,4]<-phi*p_to_out
 A[3,5]<-1-phi
 A[4,1]<-0
 A[4,2]<-0
 A[4,3]<-phi*out_to_p
 A[4,4]<-phi*(1-out_to_p)
 A[4,5]<-1-phi
 A[5,1]<-0
 A[5,2]<-0
 A[5,3]<-0
 A[5,4]<-0
 A[5,5]<-1

 E[1,1]<-1
 E[1,2]<-0
 E[1,3]<-0
 E[2,1]<-1-pc
 E[2,2]<-pc*core_fraction_core
 E[2,3]<-pc*(1-core_fraction_core)
 E[3,1]<-1-pp
 E[3,2]<-pp*core_fraction_peri
 E[3,3]<-pp*(1-core_fraction_peri)
 E[4,1]<-1-p_outside
 E[4,2]<-p_outside*0.5
 E[4,3]<-p_outside*0.5
 E[5,1]<-1
 E[5,2]<-0
 E[5,3]<-0

 for(i in 1:N) {
   z[i,1]<-1
   y[i,1]~dcat(E[z[i,1],1:3])
   for(t in 2:TT) {
     z[i,t]~dcat(A[z[i,t-1],1:5])
     y[i,t]~dcat(E[z[i,t],1:3])
     newly_dead[i,t]<-equals(z[i,t],5)*(1-equals(z[i,t-1],5))
     recovery[i,t]~dbern(newly_dead[i,t]*q_recovery)
   }
 }
})
# Distinct RNG for chains, and initial states compatible with any observed
# positive capture or recorded death recovery. Test for invalid init rather
# than hand-coding the known synthetic truth into an inference initialisation.
set.seed(seed)
inits<-function() {
 zi<-matrix(1L,N,TT)
 for(i in seq_len(N)) {
   seen<-which(y[i,]>1L)
   died<-which(recovery[i,]==1L)
   if(length(died)) {
     stopifnot(length(died)==1L)
     dd<-died[1]
   } else dd<-TT+1L
   if(length(seen)) {
     ff<-min(seen)
     for(t in ff:min(TT,dd-1L)) {
       if(t>1L)zi[i,t]<-if(y[i,t]==2L)2L else
                              if(y[i,t]==3L)3L else 3L
     }
     if(ff>1L)zi[i,ff-1L]<-1L
   }
   if(dd<=TT) {
     if(dd>1L && zi[i,dd-1L]==1L)zi[i,dd-1L]<-3L
     zi[i,dd:TT]<-5L
   }
 }
 list(gamma=runif(1,.08,.24),phi=runif(1,.75,.93),
      c_to_p=runif(1,.02,.14),p_to_c=runif(1,.02,.10),
      e_p_out=runif(1,.03,.12),out_to_p=runif(1,.08,.32),
      pc=runif(1,.32,.55),pp=runif(1,.12,.35),z=zi)
}
cat("=== V12I-06 SIMULATED CORE / PERIPHERY / OUTSIDE + ENTRY / SURVIVAL ===\n")
cat("N known synthetic candidates:",N,"T annual occasions:",TT,"\n")
cat("Alive-encounter cells:",sum(y>1L),
 " recovered deaths:",sum(recovery),"ever live detected:",
 sum(rowSums(y>1L)>0L),"\n")
cat("Truth:");print(truth)
cat("Experimental assumptions: known superpopulation, fixed q_recovery=",
 q_recovery,", zero outside detection, no real trap effort. \n",sep="")
draws<-nimble::nimbleMCMC(
 code=code,
 constants=list(N=N,TT=TT,pi_entry=pi_entry,q_recovery=q_recovery,
   p_outside=p_outside,core_fraction_core=core_capture_fraction_core,
   core_fraction_peri=core_capture_fraction_periphery),
 data=list(y=y,recovery=recovery),
 inits=inits,
 monitors=c("gamma","phi","c_to_p","p_to_c","p_to_out",
            "out_to_p","pc","pp"),
 niter=niter,nburnin=nburn,thin=thin,nchains=1,
 setSeed=seed,summary=FALSE,progressBar=FALSE,samplesAsCodaMCMC=FALSE)
s<-as.matrix(draws)
if(!nrow(s)||any(!is.finite(s)))stop("Invalid saved posterior")
map<-c(gamma="gamma",phi="phi",c_to_p="core_to_periphery",
 p_to_c="periphery_to_core",p_to_out="periphery_to_outside",
 out_to_p="outside_to_periphery",pc="p_core",pp="p_periphery")
results<-do.call(rbind,lapply(names(map),function(k) {
 v<-s[,k]
 data.frame(parameter=k,generating_value=unname(truth[map[[k]]]),
  mean=mean(v),q025=unname(quantile(v,.025)),q975=unname(quantile(v,.975)),
  contains_truth=unname(truth[map[[k]]])>=quantile(v,.025)&
    unname(truth[map[[k]]])<=quantile(v,.975))
}))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
saveRDS(list(samples=s,truth=truth,states_truth=state_truth,
  y=y,recovery=recovery,settings=list(N=N,TT=TT,niter=niter,nburn=nburn,
  thin=thin,seed=seed,data_seed=data_seed,pi_entry=pi_entry,
  q_recovery=q_recovery,p_outside=p_outside)),
  file.path(out,"synthetic_fit.rds"))
write.csv(results,file.path(out,"parameter_recovery_smoke.csv"),row.names=FALSE)
writeLines(c(
 "SYNTHETIC model only; no Woodchester survival/immigration estimates.",
 "Superpopulation size N and starting state not yet entered KNOWN; biases real use.",
 "Entry gamma combines local recruitment and immigrant entry, cannot separate origins.",
 "Outside global detector area is temporary unobserved alive state, not permanent emigration.",
 "Survival phi shared across zones; zone-specific survival not yet fitted.",
 "Death recoveries generated only at the moment of entering dead state.",
 "Known fixed recovery reporting probability q_recovery; not known in real data.",
 "Detector availability, within-era effort, and time dependence not yet represented.",
 "Capture location zone is imperfect proxy for activity centre, fixed overlap fractions.",
 "All N candidate individuals, including never-caught, are simulated as known.",
 "Single chain smoke, no multi-chain convergence, calibration, or real-data validation."),
 file.path(out,"README_LIMITATIONS.txt"))
cat("\n=== SYNTHETIC NIMBLE PARAMETER RECOVERY (SMOKE ONLY) ===\n")
print(results,row.names=FALSE,digits=3)
cat("Saved:",out,"\n")
cat("DO NOT interpret as population immigration, emigration or survival estimates.\n")
