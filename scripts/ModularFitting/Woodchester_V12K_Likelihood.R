# V12K: continuous annual positions with an exactly summed demographic /
# resident-relocator chain. Source into .GlobalEnv after attaching nimble.
# Coordinates are km relative to a fixed BNG origin. Independent broad normal
# coordinate and birth-cohort reference densities are cancelled INSIDE the forward recursion
# whenever a position is biologically occupied. This allows entry to have its
# own spatial distribution, without generating a fictitious pre-entry walk.

v12k_rates <- nimbleFunction(
 run=function(birth=double(0),sex=double(0),u=double(0),sd_ind=double(0),
 years=double(1),alpha_phi=double(0),beta_phi_sex=double(0),
 beta_phi_age=double(1),alpha_rd=double(0),beta_rd_sex=double(0),
 beta_move_age=double(1),age_rate_initial=double(0),age_rate_entry=double(0),
 max_entry_age=double(0),n_birth=double(0),TT=integer(0)) {
  returnType(double(2))
  ans<-matrix(0.0,nrow=TT,ncol=3)
  for(t in 1:TT) {
   age<-years[t]-birth
   ma<-age-1.0
   eta_phi<-alpha_phi+beta_phi_sex*sex
   eta_rd<-alpha_rd+beta_rd_sex*sex+sd_ind*u
   if(age==2.0) eta_phi<-eta_phi+beta_phi_age[1]
   if(age>=3.0) { if(age<=5.0) eta_phi<-eta_phi+beta_phi_age[2] }
   if(age>=6.0) eta_phi<-eta_phi+beta_phi_age[3]
   if(ma==2.0) eta_rd<-eta_rd+beta_move_age[1]
   if(ma>=3.0) { if(ma<=5.0) eta_rd<-eta_rd+beta_move_age[2] }
   if(ma>=6.0) eta_rd<-eta_rd+beta_move_age[3]
   ans[t,1]<-1.0/(1.0+exp(-eta_phi))
   ans[t,2]<-1.0/(1.0+exp(-eta_rd))
   ar<-age_rate_entry
   if(t==1)ar<-age_rate_initial
   if(age>=0.0) {
    if(age<=max_entry_age) {
     # Entry-age density / independent birth-cohort reference density.
     ans[t,3]<-n_birth*ar*(1.0-ar)^age/(1.0-(1.0-ar)^(max_entry_age+1.0))
    }
   }
  }
  return(ans)
 })

v12k_emission <- nimbleFunction(
 run=function(sx=double(0),sy=double(0),X=double(2),
   availability=double(2),captures=double(2),p=double(1),
   survey=double(1),sigma=double(0),aux=double(2),
   aux_sd=double(0)) {
  returnType(double(1))
  ans <- rep(0.0,4)
  mark <- rep(0.0,4)
  nc <- rep(0.0,4)
  # Rows are ordered by quarter and detector so each quarter's marks
  # accumulate in the same order as in the dense encounter likelihood.
  for(k in 1:dim(captures)[1]) {
   detector <- as.integer(captures[k,1])
   if(detector>0) {
    quarter <- as.integer(captures[k,2])
    if(availability[detector,quarter]<0.5) return(rep(-Inf,4))
    count <- captures[k,3]
    d2_mark <- (sx-X[detector,1])^2+(sy-X[detector,2])^2
    lg_mark <- -d2_mark/(2.0*sigma*sigma)
    mark[quarter] <- mark[quarter]+count*lg_mark
    nc[quarter] <- nc[quarter]+count
   }
  }
  JJ <- dim(X)[1]
  for(q in 1:4) {
   gs <- 0.0
   for(j in 1:JJ) {
    d2 <- (sx-X[j,1])^2+(sy-X[j,2])^2
    lg <- -d2/(2.0*sigma*sigma)
    g <- availability[j,q]*exp(lg)
    gs <- gs+g
   }
   if(survey[q]>0.5) {
    hazard <- -log(1.0-p[q])*gs
    ans[q] <- -hazard
    if(nc[q]>0.0) {
     # Stable log(1-exp(-hazard)); no positive probability floor.
     if(hazard<=0.0) { ans[q] <- -Inf } else {
      # NIMBLE has no expm1. The Taylor expression avoids cancellation at
      # tiny hazards (relative error below double precision at this threshold).
      lc <- 0.0
      if(hazard<0.00001) {
       lc <- log(hazard)+log(1.0-hazard/2.0+hazard*hazard/6.0-
                  hazard*hazard*hazard/24.0)
      } else { lc <- log(1.0-exp(-hazard)) }
      ans[q] <- lc+mark[q]-nc[q]*log(gs)
     }
    }
   }
   # Auxiliary positions are conditional spatial marks; there is no invented
   # series of failed opportunistic surveys. aux columns: n, sumx, sumy,
   # sum(x^2+y^2). Normal observation error includes within-year space use.
   if(aux[q,1]>0.0) {
    ss <- aux[q,4]-2.0*sx*aux[q,2]-2.0*sy*aux[q,3]+
          aux[q,1]*(sx*sx+sy*sy)
    ans[q] <- ans[q]-aux[q,1]*log(2.0*3.141592653589793*aux_sd*aux_sd)-
              ss/(2.0*aux_sd*aux_sd)
   }
  }
  return(ans)
 })

# history is a dummy observed scalar (1); this factor also contains the
# occupied-position / reference-position density ratios. Its product with
# the independent S reference nodes is a normalized joint model.
dV12Covariate <- nimbleFunction(
 run=function(x=double(0),S=double(2),ell=double(2),
  positive=double(2),recovery=double(2),at_risk=double(2),forced=double(2),
  phi=double(1),gamma=double(0),gamma_initial=double(0),psi=double(0),rd=double(1),
  dd=double(0),entry_weight=double(1),qrec=double(0),sigma_res=double(0),
  sigma_high=double(0),bounds=double(1),reference_sd=double(0),
  TT=integer(0),log=integer(0,default=0)) {
  returnType(double(0))
  # States: pre-entry, alive resident, alive relocator, dead.
  # All candidate members start pre-entry; entry at annual Q1.
  a <- rep(-Inf,4)
  a[1] <- 0.0
  b <- rep(-Inf,4)
  c <- rep(-Inf,4)
  occupied <- 0.0
  for(t in 1:TT) {
   sq <- phi[t]^0.25
   init_high <- rd[t]/(1.0-dd+rd[t])
   ref <- dnorm(S[t,1],0.0,reference_sd,log=1)+
          dnorm(S[t,2],0.0,reference_sd,log=1)
   entry <- -Inf
   if(S[t,1]>=bounds[1]) {
    if(S[t,1]<=bounds[2]) {
     if(S[t,2]>=bounds[3]) {
      if(S[t,2]<=bounds[4]) {
       entry <- -log((bounds[2]-bounds[1])*(bounds[4]-bounds[3]))-ref+log(entry_weight[t])
      }
     }
    }
   }
   # Annual boundary: entry or movement, with no extra survival transition.
   ge <- gamma
   if(t==1) ge <- gamma_initial
   b[1] <- a[1]+log(1.0-ge)
   b[2] <- a[1]+log(ge)+log(1.0-init_high)+entry
   b[3] <- a[1]+log(ge)+log(init_high)+entry
   b[4] <- a[4]
   if(t>1) {
    for(s in 2:3) {
     sig <- sigma_res
     if(s==3) sig <- sigma_high
     mv <- dnorm(S[t,1],S[t-1,1],sig,log=1)+
           dnorm(S[t,2],S[t-1,2],sig,log=1)-ref
     for(r in 2:3) {
      tr <- rd[t]
      if(r==3) tr <- dd
      if(s==2) tr <- 1.0-tr
      val <- a[r]+log(tr)+mv
      # log-sum-exp, including both negative-infinity case.
      if(val> -Inf) {
       if(b[s]== -Inf) { b[s] <- val } else {
        mm <- max(b[s],val)
        b[s] <- mm+log(exp(b[s]-mm)+exp(val-mm))
       }
      }
     }
    }
   }
   for(s in 1:4) a[s] <- b[s]
   for(k in 1:4) {
    # Conditional live observation at start of quarter.
    a[2] <- a[2]+ell[t,k]
    a[3] <- a[3]+ell[t,k]
    if(positive[t,k]>0.5) { a[1] <- -Inf; a[4] <- -Inf }
    # Mortality occurs between live observation and end-quarter recovery.
    for(s in 1:4) c[s] <- -Inf
    c[1] <- a[1]
    surv <- sq
    if(forced[t,k]>0.5) surv <- 0.0
    c[2] <- a[2]+log(surv)
    c[3] <- a[3]+log(surv)
    c[4] <- a[4]
    for(r in 2:3) {
     val <- a[r]+log(1.0-surv)
     if(val> -Inf) {
      if(c[4]== -Inf) { c[4] <- val } else {
       mm <- max(c[4],val)
       c[4] <- mm+log(exp(c[4]-mm)+exp(val-mm))
      }
     }
    }
    # Recovery can lag death. Reporting is modelled only after first live
    # encounter (marked animals); follow-up stops after first report.
    if(at_risk[t,k]>0.5) {
     if(recovery[t,k]>0.5) {
      c[1] <- -Inf; c[2] <- -Inf; c[3] <- -Inf
      c[4] <- c[4]+log(qrec)
     } else { c[4] <- c[4]+log(1.0-qrec) }
    }
    for(s in 1:4) a[s] <- c[s]
    occupied <- occupied+positive[t,k]+recovery[t,k]
   }
  }
  lp <- -Inf
  for(s in 1:4) {
   if(a[s]> -Inf) {
    if(lp== -Inf) { lp <- a[s] } else {
     mm <- max(lp,a[s]); lp <- mm+log(exp(lp-mm)+exp(a[s]-mm))
    }
   }
  }
  lp <- log(psi)+lp
  if(occupied<0.5) {
   val <- log(1.0-psi)
   mm <- max(lp,val); lp <- mm+log(exp(lp-mm)+exp(val-mm))
  }
  if(log==1) return(lp)
  return(exp(lp))
 })
registerDistributions(list(dV12Covariate=list(
 BUGSdist=paste0("dV12Covariate(S,ell,positive,recovery,at_risk,forced,phi,gamma,gamma_initial,psi,",
 "rd,dd,entry_weight,qrec,sigma_res,sigma_high,bounds,reference_sd,TT)"),
 types=c("value=double(0)","S=double(2)","ell=double(2)",
 "positive=double(2)","recovery=double(2)","at_risk=double(2)","forced=double(2)",
 "phi=double(1)","rd=double(1)","entry_weight=double(1)","bounds=double(1)","TT=integer(0)"),discrete=TRUE,pqAvail=FALSE)))
