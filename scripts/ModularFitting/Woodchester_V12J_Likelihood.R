# V12J: continuous annual positions with an exactly summed demographic /
# resident-relocator chain. Source into .GlobalEnv after attaching nimble.
# Coordinates are km relative to a fixed BNG origin. Independent broad normal
# coordinate reference densities are cancelled INSIDE the forward recursion
# whenever a position is biologically occupied. This allows entry to have its
# own spatial distribution, without generating a fictitious pre-entry walk.

v12j_logadd <- function(a,b) {
 if(!is.finite(a)) return(b)
 if(!is.finite(b)) return(a)
 m <- max(a,b); m+log(exp(a-m)+exp(b-m))
}

v12j_emission <- nimbleFunction(
 run=function(sx=double(0),sy=double(0),X=double(2),
   availability=double(2),counts=double(2),p=double(1),
   survey=double(1),sigma=double(0),aux=double(2),
   aux_sd=double(0)) {
  returnType(double(1))
  ans <- rep(0.0,4)
  JJ <- dim(X)[1]
  for(q in 1:4) {
   gs <- 0.0
   mark <- 0.0
   nc <- 0.0
   for(j in 1:JJ) {
    d2 <- (sx-X[j,1])^2+(sy-X[j,2])^2
    lg <- -d2/(2.0*sigma*sigma)
    g <- availability[j,q]*exp(lg)
    gs <- gs+g
    nc <- nc+counts[j,q]
    if(counts[j,q]>0.0) {
     if(availability[j,q]<0.5) return(rep(-Inf,4))
     mark <- mark+counts[j,q]*lg
    }
   }
   if(survey[q]>0.5) {
    hazard <- -log(1.0-p[q])*gs
    ans[q] <- -hazard
    if(nc>0.0) {
     # Stable log(1-exp(-hazard)); no positive probability floor.
     if(hazard<=0.0) { ans[q] <- -Inf } else {
      # NIMBLE has no expm1. The Taylor expression avoids cancellation at
      # tiny hazards (relative error below double precision at this threshold).
      lc <- 0.0
      if(hazard<0.00001) {
       lc <- log(hazard)+log(1.0-hazard/2.0+hazard*hazard/6.0-
                  hazard*hazard*hazard/24.0)
      } else { lc <- log(1.0-exp(-hazard)) }
      ans[q] <- lc+mark-nc*log(gs)
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
dV12Joint <- nimbleFunction(
 run=function(x=double(0),S=double(2),ell=double(2),
  positive=double(2),recovery=double(2),at_risk=double(2),forced=double(2),
  phi=double(0),gamma=double(0),gamma_initial=double(0),psi=double(0),rd=double(0),
  dd=double(0),qrec=double(0),sigma_res=double(0),
  sigma_high=double(0),bounds=double(1),reference_sd=double(0),
  TT=integer(0),log=integer(0,default=0)) {
  returnType(double(0))
  # States: pre-entry, alive resident, alive relocator, dead.
  # All candidate members start pre-entry; entry at annual Q1.
  a <- rep(-Inf,4)
  a[1] <- 0.0
  b <- rep(-Inf,4)
  c <- rep(-Inf,4)
  sq <- phi^0.25
  init_high <- rd/(1.0-dd+rd)
  occupied <- 0.0
  for(t in 1:TT) {
   ref <- dnorm(S[t,1],0.0,reference_sd,log=1)+
          dnorm(S[t,2],0.0,reference_sd,log=1)
   entry <- -Inf
   if(S[t,1]>=bounds[1]) {
    if(S[t,1]<=bounds[2]) {
     if(S[t,2]>=bounds[3]) {
      if(S[t,2]<=bounds[4]) {
       entry <- -log((bounds[2]-bounds[1])*(bounds[4]-bounds[3]))-ref
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
      tr <- rd
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
registerDistributions(list(dV12Joint=list(
 BUGSdist=paste0("dV12Joint(S,ell,positive,recovery,at_risk,forced,phi,gamma,gamma_initial,psi,",
 "rd,dd,qrec,sigma_res,sigma_high,bounds,reference_sd,TT)"),
 types=c("value=double(0)","S=double(2)","ell=double(2)",
 "positive=double(2)","recovery=double(2)","at_risk=double(2)","forced=double(2)",
 "bounds=double(1)","TT=integer(0)"),discrete=TRUE,pqAvail=FALSE)))

# R mirror used for state smoothing / independent implementation checks.
# transitions include density ratios, so this is a joint-density recursion.
v12j_forward_R <- function(S,ell,positive,recovery,at_risk,forced,p,bounds,reference_sd,
                          transitions=FALSE) {
 T <- nrow(S); a <- c(0,-Inf,-Inf,-Inf); mats<-list(); emissions<-list()
 sq<-p$phi^.25; ih<-p$rd/(1-p$dd+p$rd)
 for(t in seq_len(T)) {
  ref<-sum(dnorm(S[t,],0,reference_sd,log=TRUE))
  ent<-if(all(S[t,]>=bounds[c(1,3)] & S[t,]<=bounds[c(2,4)]))
    -log(diff(bounds[1:2])*diff(bounds[3:4]))-ref else -Inf
  ge<-if(t==1)p$gamma_initial else p$gamma
  B<-matrix(-Inf,4,4); B[1,1]<-log1p(-ge)
  B[1,2:3]<-log(ge)+log(c(1-ih,ih))+ent; B[4,4]<-0
  if(t>1)for(r in 2:3)for(s in 2:3) {
   tr<-if(r==2)p$rd else p$dd
   if(s==2)tr<-1-tr
   B[r,s]<-log(tr)+sum(dnorm(S[t,],S[t-1,],
              if(s==2)p$sigma_res else p$sigma_high,log=TRUE))-ref
  }
  a<-apply(B,2,function(v)Reduce(v12j_logadd,a+v))
  for(q in 1:4) {
   E<-c(0,ell[t,q],ell[t,q],0)
   if(positive[t,q])E[c(1,4)]<--Inf
   C<-matrix(-Inf,4,4); C[1,1]<-0; C[4,4]<-0
   surv<-if(forced[t,q])0 else sq
   C[2,2]<-C[3,3]<-log(surv); C[2:3,4]<-log1p(-surv)
   if(at_risk[t,q]) {
    if(recovery[t,q]) { C[,1:3]<--Inf; C[,4]<-C[,4]+log(p$qrec) }
    else C[,4]<-C[,4]+log1p(-p$qrec)
   }
   a<-apply(C,2,function(v)Reduce(v12j_logadd,a+E+v))
  }
 }
 lp<-log(p$psi)+Reduce(v12j_logadd,a)
 if(sum(positive)+sum(recovery)==0)lp<-v12j_logadd(lp,log1p(-p$psi))
 lp
}

v12j_factors_R <- function(S,ell,positive,recovery,at_risk,forced,p,bounds,reference_sd) {
 T<-nrow(S); F<-list(); sq<-p$phi^.25; ih<-p$rd/(1-p$dd+p$rd)
 for(t in seq_len(T)) {
  ref<-sum(dnorm(S[t,],0,reference_sd,log=TRUE))
  ent<-if(all(S[t,]>=bounds[c(1,3)] & S[t,]<=bounds[c(2,4)]))
    -log(diff(bounds[1:2])*diff(bounds[3:4]))-ref else -Inf
  ge<-if(t==1)p$gamma_initial else p$gamma
  B<-matrix(-Inf,4,4);B[1,1]<-log1p(-ge)
  B[1,2:3]<-log(ge)+log(c(1-ih,ih))+ent;B[4,4]<-0
  if(t>1)for(r in 2:3)for(s in 2:3) {
   tr<-if(r==2)p$rd else p$dd;if(s==2)tr<-1-tr
   B[r,s]<-log(tr)+sum(dnorm(S[t,],S[t-1,],
    if(s==2)p$sigma_res else p$sigma_high,log=TRUE))-ref
  }
  F[[length(F)+1L]]<-B
  for(q in 1:4) {
   E<-c(0,ell[t,q],ell[t,q],0);if(positive[t,q])E[c(1,4)]<--Inf
   C<-matrix(-Inf,4,4);C[1,1]<-0;C[4,4]<-0
   surv<-if(forced[t,q])0 else sq
   C[2,2]<-C[3,3]<-log(surv);C[2:3,4]<-log1p(-surv)
   if(at_risk[t,q]) {
    if(recovery[t,q]) {C[,1:3]<--Inf;C[,4]<-C[,4]+log(p$qrec)}
    else C[,4]<-C[,4]+log1p(-p$qrec)
   }
   F[[length(F)+1L]]<-sweep(C,1,E,"+")
  }
 }
 F
}

v12j_sample_path_R <- function(F,psi,observed) {
 a<-matrix(-Inf,length(F)+1L,4);a[1,1]<-0
 for(k in seq_along(F))a[k+1,]<-apply(F[[k]],2,
  function(v)Reduce(v12j_logadd,a[k,]+v))
 logL<-Reduce(v12j_logadd,a[nrow(a),])
 member_p<-1
 if(!observed) {
  joint<-log(psi)+logL
  member_p<-exp(joint-v12j_logadd(joint,log1p(-psi)))
 }
 if(rbinom(1,1,member_p)==0)return(rep(0L,nrow(a)))
 draw<-function(v)sample.int(4L,1L,prob=exp(v-max(v)))
 z<-integer(nrow(a));z[nrow(a)]<-draw(a[nrow(a),])
 for(k in rev(seq_along(F)))z[k]<-draw(a[k,]+F[[k]][,z[k+1L]])
 z
}
