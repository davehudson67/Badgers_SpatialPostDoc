# Loaded by V12K_Check.R after emission functions and compile helper exist.
set.seed(20261117)
annual_cases<-0L
for(test in seq_len(100L)) {
 JJ<-8L;TT<-3L;NN<-2L;NM<-5L
 av<-array(rbinom(JJ*4L*TT,1,.4),c(JJ,4L,TT))
 av[1:3,,1]<-0
 av[,,3]<-0
 if(test %% 3L==0L) {av[,,2]<-0;av[5,1,2]<-1}
 packed<-array(0,c(NN,TT,NM,3L))
 for(i in seq_len(NN))for(t in 1:2) {
  cells<-which(av[,,t]>0,arr.ind=TRUE)
  cells<-cells[seq_len(min(NM,nrow(cells))),,drop=FALSE]
  if(nrow(cells))for(k in seq_len(nrow(cells)))
   packed[i,t,k,]<-c(cells[k,],sample(1:3,1))
 }
 # Retain invalid positive marks so their -Inf likelihood is also preserved.
 if(test %% 10L==0L)packed[1,3,1,]<-c(2,1,1)
 local<-v12k_annual_detectors(av,packed)
 X<-matrix(rnorm(JJ*2,sd=.2),JJ,2)
 for(i in seq_len(NN))for(t in seq_len(TT)) {
  selected<-local$active[[t]]
  XX<-matrix(0,local$n_local[t],2)
  if(length(selected))XX[seq_along(selected),]<-X[selected,,drop=FALSE]
  args<-list(sx=rnorm(1,sd=.2),sy=rnorm(1,sd=.2),
    p=c(.2,1e-10,0,.6),survey=c(1,1,1,0),sigma=.15,
    aux=matrix(0,4,4),aux_sd=.25)
  # Include an auxiliary observation, including in the empty-coverage year.
  args$aux[4,]<-c(1,.1,.2,.05)
  full<-c(args,list(X=X,availability=matrix(av[,,t],JJ,4),
    captures=matrix(packed[i,t,,],NM,3)))
  small<-c(args,list(X=XX,
    availability=matrix(local$availability[seq_len(local$n_local[t]),,t],
                        local$n_local[t],4),
    captures=matrix(local$packed[i,t,,],NM,3)))
  want<-do.call(v12k_emission,full)
  for(fn in list(v12k_emission,ce)) {
   got<-do.call(fn,small)
   stopifnot(identical(is.finite(got),is.finite(want)),
    all(got[!is.finite(got)]==want[!is.finite(want)]),
    all(abs(got[is.finite(got)]-want[is.finite(want)])<1e-10))
  }
  annual_cases<-annual_cases+1L
 }
}
singleton<-v12k_annual_detectors(array(0,c(1,4,1)),array(0,c(1,1,1,3)))
stopifnot(identical(dim(singleton$packed),c(1L,1L,2L,3L)),
          singleton$n_local==2L,all(singleton$packed==0))
cat("PASS:",annual_cases,"annual-subset emission cases, including empty coverage and invalid marks.\n")

if(!r_only) {
 # Check the actual graph and compiled ordinary sampler restore/recalculate
 # behaviour: X[2] influences year 1, X[3] year 2, X[4] neither.
 av<-array(0,c(4,4,3))
 av[c(1,2),,1]<-1;av[c(1,3),,2]<-1
 packed<-array(0,c(1,3,1,3))
 local<-v12k_annual_detectors(av,packed)
 annual_code<-nimbleCode({
  for(j in 1:4)for(d in 1:2) X[j,d]~dunif(-2,2)
  for(t in 1:3) {
   if(n_active[t]>0) {
    for(j in 1:n_active[t])for(d in 1:2)
     localX[t,j,d]<-X[detector_index[j,t],d]
   }
   if(n_active[t]<n_local[t]) {
    for(j in (n_active[t]+1):n_local[t])for(d in 1:2)localX[t,j,d]<-0
   }
   ell[t,1:4]<-v12k_emission(0,0,localX[t,1:n_local[t],1:2],
     availability[1:n_local[t],1:4,t],captures[1,t,1:2,1:3],
     p[1:4],survey[1:4],.15,aux[1:4,1:4],.25)
   y[t]~dnorm(sum(ell[t,1:4]),sd=1)
  }
 })
 annual_model<-nimbleModel(annual_code,
  constants=list(n_active=local$n_active,n_local=local$n_local,
   detector_index=local$indices,availability=local$availability,
   captures=local$packed,p=rep(.3,4),survey=rep(1,4),aux=matrix(0,4,4)),
  data=list(y=rep(0,3),X=rbind(c(0,0),matrix(NA,3,2))),
  inits=list(X=rbind(c(NA,NA),c(.1,.2),c(.2,.1),c(.3,.3))))
 for(j in 2:4) {
  deps<-gsub(" ","",annual_model$getDependencies(sprintf("X[%d,1]",j)),fixed=TRUE)
  want<-if(j==2)1L else if(j==3)2L else integer(0)
  got<-sort(as.integer(sub("y\\[([0-9]+)\\]","\\1",
    grep("^y\\[",deps,value=TRUE))))
  if(!identical(got,want))stop("X[",j,"] dependency years: got ",
    paste(got,collapse=","),"; expected ",paste(want,collapse=","),
    ". All dependencies: ",paste(deps,collapse="; "))
 }
 ac<-configureMCMC(annual_model,monitors="X",enableWAIC=FALSE,print=FALSE)
 am<-buildMCMC(ac)
 cm<-compileNimble(annual_model,showCompilerOutput=TRUE)
 cs<-compileNimble(am,project=annual_model,showCompilerOutput=TRUE)
 set.seed(913)
 cs$run(20,progressBar=FALSE)
 stored_lp<-cm$getLogProb(annual_model$getNodeNames(stochOnly=TRUE))
 full_lp<-cm$calculate()
 stopifnot(is.finite(full_lp),abs(stored_lp-full_lp)<1e-9)
 for(t in 1:3) {
  want<-v12k_emission(0,0,cm$X,matrix(av[,,t],4,4),
     matrix(0,1,3),rep(.3,4),rep(1,4),.15,matrix(0,4,4),.25)
  stopifnot(max(abs(cm$ell[t,]-want))<1e-10)
 }
 cat("PASS: compiled annual detector dependencies and MCMC cached values match full recalculation.\n")
}
