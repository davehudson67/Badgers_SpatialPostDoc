#!/usr/bin/env Rscript
# V12I-06c: same synthetic data, priors, and scientific model as V12I-06.
# Exact marginalisation of latent states, not an identifiability fix.
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

# Exact forward likelihood of packed live/recovery observations.
# Recovery is transition-dependent: only the FIRST transition into death.
dV12I06HMM <- nimbleFunction(
 run=function(x=double(1), A=double(2), E=double(2),
              q=double(0), TT=integer(0), log=integer(0,default=0)) {
  returnType(double(0))
  alpha <- rep(0.0,5)
  nxt <- rep(0.0,5)
  alpha[1] <- 1.0
  lp <- 0.0
  if(x[1] != 1) {
   if(log==1) return(-Inf)
   return(0.0)
  }
  for(t in 2:TT) {
   recovered <- as.integer(floor((x[t]-1)/3))
   live_code <- as.integer(x[t]-3*recovered)
   for(b in 1:5) {
    nxt[b] <- 0.0
    for(a in 1:5) {
     rq <- 0.0
     if(b==5) {
      if(a!=5) rq <- q
     }
     rp <- 1.0-rq
     if(recovered==1) rp <- rq
     nxt[b] <- nxt[b]+alpha[a]*A[a,b]*E[b,live_code]*rp
    }
   }
   scale <- sum(nxt)
   if(scale<=0.0) {
    if(log==1) return(-Inf)
    return(0.0)
   }
   lp <- lp+log(scale)
   for(b in 1:5) alpha[b] <- nxt[b]/scale
  }
  if(log==1) return(lp)
  return(exp(lp))
 })
registerDistributions(list(dV12I06HMM=list(
 BUGSdist="dV12I06HMM(A,E,q,TT)",
 types=c("value=double(1)","A=double(2)","E=double(2)",
         "q=double(0)","TT=integer(0)"),
 discrete=TRUE,pqAvail=FALSE)))

# Independent exact path enumeration gate; all 216 length-4 packed histories.
# Includes no records, ordinary captures, one recovery, repeat recoveries,
# impossible simultaneous live+death, and captures after a recorded death.
enumerate_history <- function(x,A,E,q) {
 paths <- as.matrix(expand.grid(rep(list(1:5),length(x)-1L)))
 total <- 0
 for(k in seq_len(nrow(paths))) {
  z <- c(1L,paths[k,])
  prob <- as.numeric(x[1]==1L)
  for(t in 2:length(x)) {
   recovered <- (x[t]-1L)%/%3L
   live_code <- x[t]-3L*recovered
   rq <- as.numeric(z[t]==5L && z[t-1L]!=5L)*q
   prob <- prob*A[z[t-1L],z[t]]*E[z[t],live_code]*
                  if(recovered==1L) rq else (1-rq)
  }
  total <- total+prob
 }
 total
}
cat("Compiling forward density for independent likelihood checks.\n")
compiled_density <- tryCatch(
 compileNimble(dV12I06HMM, showCompilerOutput=TRUE),
 error=function(e) {
  # Rscript exits after an error, so preserve compiler diagnostics in smoke.log.
  try(printErrors(), silent=TRUE)
  stop(conditionMessage(e), call.=FALSE)
 })
histories <- as.matrix(expand.grid(rep(list(1:6),3L)))
# Test truth and a second valid parameter setting.
test_parameters <- list(truth, c(gamma=.31,phi=.67,core_to_periphery=.23,
 periphery_to_core=.17,periphery_to_outside=.21,outside_to_periphery=.37,
 p_core=.61,p_periphery=.34))
for(testpar in test_parameters) {
 aa <- make_transition(testpar); ee <- make_emission(testpar)
 for(k in seq_len(nrow(histories))) {
  xx <- c(1,histories[k,])
  expected <- enumerate_history(xx,aa,ee,q_recovery)
  actual <- dV12I06HMM(xx,aa,ee,q_recovery,4L,0L)
  compiled <- compiled_density(xx,aa,ee,q_recovery,4L,0L)
  if(!isTRUE(all.equal(actual,expected,tolerance=1e-10)) ||
     !isTRUE(all.equal(compiled,expected,tolerance=1e-10)))
   stop("Forward/path-enumeration mismatch at history ",paste(xx,collapse=","))
 }
}
cat("PASS: forward likelihood equals full state-path enumeration.\n")
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
  history[i,1:TT] ~ dV12I06HMM(A[1:5,1:5],E[1:5,1:3],q_recovery,TT)
 }
})
history <- y+3L*recovery
set.seed(seed)
inits<-function() list(gamma=runif(1,.08,.24),phi=runif(1,.75,.93),
 c_to_p=runif(1,.02,.14),p_to_c=runif(1,.02,.10),
 e_p_out=runif(1,.03,.12),out_to_p=runif(1,.08,.32),
 pc=runif(1,.32,.55),pp=runif(1,.12,.35))
cat("=== V12I-06c EXACTLY MARGINALISED SYNTHETIC HMM ===\n")
cat("N:",N," T:",TT," live cells:",sum(y>1L),
 " recoveries:",sum(recovery)," data seed:",data_seed,"\n")
draws<-nimble::nimbleMCMC(
 code=code,
 constants=list(N=N,TT=TT,pi_entry=pi_entry,q_recovery=q_recovery,
   p_outside=p_outside,core_fraction_core=core_capture_fraction_core,
   core_fraction_peri=core_capture_fraction_periphery),
 data=list(history=history),
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
  q_recovery=q_recovery,p_outside=p_outside,engine="collapsed_forward")),
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
 "Exact forward marginalisation removes sampled discrete states; priors/model unchanged.",
 "Single-chain result requires independent-chain and repeated-dataset validation."),
 file.path(out,"README_LIMITATIONS.txt"))
cat("\n=== SYNTHETIC NIMBLE PARAMETER RECOVERY (SMOKE ONLY) ===\n")
print(results,row.names=FALSE,digits=3)
cat("Saved:",out,"\n")
cat("DO NOT interpret as population immigration, emigration or survival estimates.\n")
