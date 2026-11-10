# Shared metadata and posterior covariate calculations. Base R only.
v12k_metadata <- function(live,ids,years,padding=30L) {
 needed<-c("tattoo","sex_clean","age_first_capture_clean","year_first_capture","capture_date")
 if(!all(needed %in% names(live)))stop("Snapshot lacks covariates: ",paste(setdiff(needed,names(live)),collapse=", "))
 norm<-function(x)toupper(trimws(as.character(x)))
 live$tattoo<-norm(live$tattoo)
 one<-function(x,label,id) {
  x<-unique(x[!is.na(x)&nzchar(as.character(x))])
  if(length(x)>1L)stop("Conflicting ",label," for ",id)
  if(length(x))x else NA
 }
 rows<-lapply(ids,function(id) {
  z<-live[live$tattoo==id,,drop=FALSE]
  sx<-norm(z$sex_clean)
  male<-rep(NA_real_,length(sx));male[sx %in% c("M","MALE")]<-1
  male[sx %in% c("F","FEMALE")]<-0
  sex<-one(male,"sex",id)
  ac<-norm(z$age_first_capture_clean)
  ac[!ac %in% c("CUB","YEARLING","ADULT")]<-NA_character_
  ageclass<-one(ac,"first-capture age class",id)
  fy<-one(suppressWarnings(as.integer(z$year_first_capture)),"first-capture year",id)
  earliest<-min(as.integer(format(as.Date(z$capture_date),"%Y")))
  reason<-"SOURCE_AGE_CLASS"
  if(is.na(fy)||fy>earliest) {
   ageclass<-NA_character_;reason<-"FIRST_YEAR_MISSING_OR_INCONSISTENT_AGE_HELD_UNKNOWN"
  }
  birth<-NA_integer_
  if(!is.na(ageclass)) {
   if(ageclass=="CUB")birth<-fy
   if(ageclass=="YEARLING")birth<-fy-1L
  }
  data.frame(tattoo=id,sex_data=as.numeric(sex),age_class=ageclass,
   source_first_year=as.integer(fy),earliest_model_live_year=earliest,
   birth_year_data=birth,adult_constraint=as.integer(!is.na(ageclass)&&ageclass=="ADULT"),
   age_provenance=reason,stringsAsFactors=FALSE)
 })
 m<-do.call(rbind,rows)
 if(any(!is.na(m$birth_year_data)&m$birth_year_data>m$earliest_model_live_year))
  stop("Known-age birth follows live evidence")
 minbirth<-min(c(min(years)-padding,m$birth_year_data),na.rm=TRUE)
 list(metadata=m,birth_years=seq.int(minbirth,max(years)))
}

v12k_individual_parameters <- function(g,sex,birth,u,years,sigma_res,
                                      max_entry_age=30,n_birth=length(years)+30) {
 # Movement age is at start of the preceding annual interval; survival age
 # is calendar-year age. Newborn entries have reference (young) movement.
 age<-years-birth; ma<-years-1L-birth
 groups<-function(a)cbind(as.numeric(a==2),as.numeric(a>=3&a<=5),as.numeric(a>=6))
 beta<-function(key)unname(g[paste0(key,"[",1:3,"]")])
 phi<-plogis(g["alpha_phi"]+g["beta_phi_sex"]*sex+groups(age)%*%beta("beta_phi_age"))
 rd<-plogis(g["alpha_rd"]+g["beta_rd_sex"]*sex+groups(ma)%*%beta("beta_move_age")+
             g["sigma_individual"]*u)
 ar<-rep(g["age_rate_entry"],length(years));ar[1]<-g["age_rate_initial"]
 ew<-ifelse(age>=0&age<=max_entry_age,
   n_birth*ar*(1-ar)^age/(1-(1-ar)^(max_entry_age+1)),0)
 list(phi=as.numeric(phi),rd=as.numeric(rd),
  dd=unname(plogis(g["alpha_dd"]+g["beta_dd_sex"]*sex)),
  entry_weight=as.numeric(ew),gamma=unname(g["gamma"]),
  gamma_initial=unname(g["gamma_initial"]),psi=unname(g["psi"]),qrec=unname(g["qrec"]),
  sigma_res=sigma_res,
  sigma_high=unname(sigma_res+exp(g["log_sigma_high"]+g["beta_highscale_sex"]*sex)),
  sigma_det=unname(exp(g["log_sigma_det"]+g["beta_sigma_sex"]*sex)),
  detection_sex=unname(g["beta_p_sex"]*sex))
}

v12k_logadd <- function(a,b) {
 if(a== -Inf)return(b)
 if(b== -Inf)return(a)
 mm<-max(a,b);mm+log(exp(a-mm)+exp(b-mm))
}

v12k_factors_R <- function(S,ell,positive,recovery,at_risk,forced,p,bounds,reference_sd) {
 T<-nrow(S);F<-list()
 for(t in seq_len(T)) {
  sq<-p$phi[t]^.25;ih<-p$rd[t]/(1-p$dd+p$rd[t])
  ref<-sum(dnorm(S[t,],0,reference_sd,log=TRUE))
  ent<-if(all(S[t,]>=bounds[c(1,3)]&S[t,]<=bounds[c(2,4)]))
    -log(diff(bounds[1:2])*diff(bounds[3:4]))-ref+log(p$entry_weight[t]) else -Inf
  ge<-if(t==1)p$gamma_initial else p$gamma
  B<-matrix(-Inf,4,4);B[1,1]<-log1p(-ge)
  B[1,2:3]<-log(ge)+log(c(1-ih,ih))+ent;B[4,4]<-0
  if(t>1)for(r in 2:3)for(s in 2:3) {
   tr<-if(r==2)p$rd[t] else p$dd;if(s==2)tr<-1-tr
   B[r,s]<-log(tr)+sum(dnorm(S[t,],S[t-1,],
     if(s==2)p$sigma_res else p$sigma_high,log=TRUE))-ref
  }
  F[[length(F)+1L]]<-B
  for(q in 1:4) {
   E<-c(0,ell[t,q],ell[t,q],0);if(positive[t,q])E[c(1,4)]<--Inf
   C<-matrix(-Inf,4,4);C[1,1]<-C[4,4]<-0
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

v12k_sample_path_R <- function(F,psi,observed) {
 a<-matrix(-Inf,length(F)+1L,4);a[1,1]<-0
 for(k in seq_along(F))a[k+1,]<-apply(F[[k]],2,
  function(v)Reduce(v12k_logadd,a[k,]+v))
 logL<-Reduce(v12k_logadd,a[nrow(a),])
 mp<-1
 if(!observed) {
  joint<-log(psi)+logL;mp<-exp(joint-v12k_logadd(joint,log1p(-psi)))
 }
 if(rbinom(1,1,mp)==0)return(rep(0L,nrow(a)))
 draw<-function(v)sample.int(4L,1L,prob=exp(v-max(v)))
 z<-integer(nrow(a));z[nrow(a)]<-draw(a[nrow(a),])
 for(k in rev(seq_along(F)))z[k]<-draw(a[k,]+F[[k]][,z[k+1L]])
 z
}
