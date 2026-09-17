# =============================================================================
# V8 PROVISIONAL V7b-M KNOWN-AGE SENSITIVITY
#
# DEVELOPMENT ONLY: uses existing V8 provisional movement histories.
# Fits on IDENTICAL known-age quarterly risk rows:
#   B0: logit(h) = alpha + movement + sex + quarter + 5-year period
#   B1: B0 + chronological age at the infection-risk quarter
#
# Birth rule matches the movement age model: Cub -> Q1 first-capture year;
# Yearling -> Q1 previous year. Age is centred at 3 years.
# =============================================================================

library(tidyverse)

PAIR_FILE <- "data/badger_phase2_paired_latent_inputs_V8_PROVISIONAL.rds"
MOVE_FILE <- "data/badger_movement_posterior_histories_1932_V8_PROVISIONAL.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
IND_FILE <- "data/badger_individuals.rds"
for(f in c(PAIR_FILE,MOVE_FILE,INF_FILE,IND_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

paired<-readRDS(PAIR_FILE); mov<-readRDS(MOVE_FILE); inf<-readRDS(INF_FILE); individuals<-as_tibble(readRDS(IND_FILE))
MAX_PAIRS<-as.integer(Sys.getenv("MAX_PAIRS","100")); N_PROP<-as.integer(Sys.getenv("N_PROP","3000")); N_KEEP<-as.integer(Sys.getenv("N_KEEP","50")); SEED<-as.integer(Sys.getenv("SEED","7092062")); RESULT_TAG<-Sys.getenv("RESULT_TAG","SMOKE_100"); AGE_CENTER<-3
set.seed(SEED)

START_YEAR<-as.integer(inf$start_year); inf_ids<-trimws(as.character(inf$tattoo))
birth<-individuals %>% transmute(tattoo=trimws(as.character(tattoo)),age_fc=toupper(str_squish(as.character(age_fc))),year_fc=as.integer(year_fc)) %>% mutate(birth_year=case_when(age_fc=="CUB" & !is.na(year_fc)~year_fc,age_fc=="YEARLING" & !is.na(year_fc)~year_fc-1L,TRUE~NA_integer_)) %>% distinct(tattoo,.keep_all=TRUE)

idx<-as_tibble(mov$interval_index) %>% mutate(interval_col=row_number(),model_i=as.integer(model_i),tattoo=trimws(as.character(tattoo)),from_year=as.integer(from_year),to_year=as.integer(to_year)) %>% left_join(birth %>% select(tattoo,birth_year),by="tattoo") %>% mutate(known_age=!is.na(birth_year))
if(ncol(mov$state_draws)!=nrow(idx)) stop("Movement state matrix mismatch.")
sex_i<-as.integer(mov$sex); if(any(!sex_i%in%c(0L,1L))) stop("Sex must be 0/1.")
if(any(!unique(idx$tattoo)%in%inf_ids)) stop("Movement badger absent from infection trajectories.")
if(is.null(paired$live_bounds) || !all(c("tattoo","last_live_time")%in%names(paired$live_bounds))) stop("paired object lacks live_bounds.")
last_live<-setNames(as.integer(paired$live_bounds$last_live_time),trimws(as.character(paired$live_bounds$tattoo)))

eligible_move<-idx %>% group_by(model_i,tattoo) %>% arrange(from_year,to_year,.by_group=TRUE) %>% mutate(is_last=row_number()==n()) %>% ungroup() %>% filter(!is_last,known_age)
PERIOD_LEVELS<-sort(unique(5L*((eligible_move$to_year+1L)%/%5L))); N_PERIOD<-length(PERIOD_LEVELS)
if(N_PERIOD<2L) stop("Need >=2 period levels.")

quarter_contrast<-function(q){z<-numeric(3); if(q<=3L) z[q]<-1 else z[]<--1; z}
period_contrast<-function(p){j<-match(p,PERIOD_LEVELS); z<-numeric(N_PERIOD-1L); if(j<N_PERIOD) z[j]<-1 else z[]<--1; z}

base_names<-c("alpha","beta_move","beta_sex",paste0("quarter_raw[",1:3,"]"),paste0("period_raw[",1:(N_PERIOD-1L),"]"))
make_X<-function(d,with_age=FALSE){
  X<-matrix(0,nrow(d),length(base_names),dimnames=list(NULL,base_names)); X[,1]<-1; X[,2]<-d$movement_state; X[,3]<-d$sex
  for(r in seq_len(nrow(d))){X[r,4:6]<-quarter_contrast(d$outcome_quarter[r]); X[r,7:ncol(X)]<-period_contrast(d$period_start[r])}
  if(with_age) X<-cbind(X,beta_age=d$age_c)
  X
}

make_prior<-function(with_age=FALSE){
  pm<-c(alpha=qlogis(.0125),beta_move=0,beta_sex=0,rep(0,3),rep(0,N_PERIOD-1L)); ps<-c(alpha=1.5,beta_move=1.5,beta_sex=1.5,rep(1,3),rep(1,N_PERIOD-1L)); names(pm)<-names(ps)<-base_names
  if(with_age){pm<-c(pm,beta_age=0); ps<-c(ps,beta_age=.5)}
  list(mean=pm,sd=ps)
}

pair_index<-paired$pair_index %>% arrange(pair_draw); MAX_PAIRS<-min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<nrow(pair_index)){pick<-unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS))); if(length(pick)!=MAX_PAIRS) pick<-sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS)); pair_index<-pair_index[pick,,drop=FALSE]}

make_risk_counts<-function(move_draw,inf_col){
  st<-as.integer(mov$state_draws[move_draw,]); it<-as.integer(inf$infection_time[,inf_col]); names(it)<-inf_ids
  out<-vector("list",nrow(eligible_move)*4L); oo<-0L
  for(rr in seq_len(nrow(eligible_move))){
    row<-eligible_move[rr,]; tattoo<-row$tattoo; infection_time<-it[tattoo]; move_end_year<-row$to_year; q4<-4L*(move_end_year-START_YEAR)+4L
    if(!(infection_time==0L || infection_time>q4)) next
    outcome_year<-move_end_year+1L; period_start<-5L*(outcome_year%/%5L); llt<-last_live[tattoo]
    for(q in 1:4){
      ot<-4L*(outcome_year-START_YEAR)+q; if(is.na(llt) || ot>llt) break; if(infection_time>0L && infection_time<ot) break
      ev<-as.integer(infection_time>0L && infection_time==ot)
      age_years<-(outcome_year-row$birth_year)+(q-1)/4; age_c<-age_years-AGE_CENTER
      oo<-oo+1L; out[[oo]]<-tibble(movement_state=st[row$interval_col],sex=sex_i[row$model_i],outcome_quarter=q,period_start=period_start,age_years=age_years,age_c=age_c,event=ev)
      if(ev==1L) break
    }
  }
  if(!oo) return(tibble())
  bind_rows(out[seq_len(oo)]) %>% group_by(movement_state,sex,outcome_quarter,period_start,age_years,age_c) %>% summarise(n=n(),y=sum(event),.groups="drop")
}

log1pexp<-function(x) ifelse(x>0,x+log1p(exp(-x)),log1p(exp(x)))
draw_mvn<-function(n,mu,Sigma){R<-chol(Sigma); sweep(matrix(rnorm(n*length(mu)),n,length(mu))%*%R,2,mu,"+")}
logdmvn_many<-function(x,mu,Sigma){d<-length(mu); md<-mahalanobis(x,mu,Sigma); ld<-as.numeric(determinant(Sigma,logarithm=TRUE)$modulus); -.5*(d*log(2*pi)+ld+md)}
logsumexp2<-function(a,b){m<-pmax(a,b); m+log(exp(a-m)+exp(b-m))}

fit_pair<-function(d,with_age=FALSE){
  X<-make_X(d,with_age); pr<-make_prior(with_age); pm<-pr$mean; ps<-pr$sd; n<-d$n; y<-d$y; P<-ncol(X)
  logpost<-function(th){eta<-as.vector(X%*%th); sum(y*eta-n*log1pexp(eta))-.5*sum(((th-pm)/ps)^2)}
  nlp<-function(th)-logpost(th)
  grad<-function(th){eta<-as.vector(X%*%th); p<-plogis(eta); -as.vector(crossprod(X,y-n*p)-(th-pm)/(ps^2))}
  opt<-optim(pm,nlp,grad,method="BFGS",control=list(maxit=750,reltol=1e-9)); if(opt$convergence!=0L) opt<-optim(pm,nlp,grad,method="BFGS",control=list(maxit=1200,reltol=1e-10))
  eta<-as.vector(X%*%opt$par); p<-plogis(eta); w<-n*p*(1-p); H<-crossprod(X,X*w)+diag(1/(ps^2),P); ee<-eigen(H,symmetric=TRUE); ee$values[ee$values<1e-8]<-1e-8; V<-ee$vectors%*%diag(1/ee$values,P)%*%t(ee$vectors)
  V1<-V*(1.25^2); V2<-V*(2.5^2); comp2<-runif(N_PROP)<.10; prop<-matrix(NA_real_,N_PROP,P); if(any(!comp2)) prop[!comp2,]<-draw_mvn(sum(!comp2),opt$par,V1); if(any(comp2)) prop[comp2,]<-draw_mvn(sum(comp2),opt$par,V2)
  lq1<-logdmvn_many(prop,opt$par,V1)+log(.9); lq2<-logdmvn_many(prop,opt$par,V2)+log(.1); lq<-logsumexp2(lq1,lq2)
  etaP<-prop%*%t(X); ll<-rowSums(sweep(etaP,2,y,"*")-sweep(log1pexp(etaP),2,n,"*")); z<-sweep(prop,2,pm,"-"); lp<--.5*rowSums(sweep(z^2,2,ps^2,"/")); lw<-ll+lp-lq; lw<-lw-max(lw); ww<-exp(lw); ww<-ww/sum(ww)
  keep<-sample.int(N_PROP,N_KEEP,replace=TRUE,prob=ww); dr<-prop[keep,,drop=FALSE]; colnames(dr)<-colnames(X)
  list(draws=dr,ESS=1/sum(ww^2),maxw=max(ww),optim=opt$convergence,risk=sum(n),events=sum(y),age_min=min(d$age_years),age_max=max(d$age_years))
}

pooled<-list(); diags<-list(); k<-0L; dd<-0L
for(pp in seq_len(nrow(pair_index))){
  d<-make_risk_counts(pair_index$movement_draw[pp],pair_index$infection_col[pp]); if(!nrow(d)) stop("No known-age risk rows for pair ",pair_index$pair_draw[pp])
  for(with_age in c(FALSE,TRUE)){
    nm<-if(with_age) "KNOWNAGE_PLUS_AGE" else "KNOWNAGE_BASELINE"; fit<-fit_pair(d,with_age)
    k<-k+1L; pooled[[k]]<-as_tibble(fit$draws) %>% mutate(pair_draw=pair_index$pair_draw[pp],model=nm,.before=1)
    dd<-dd+1L; diags[[dd]]<-tibble(model=nm,pair_draw=pair_index$pair_draw[pp],risk_quarters=fit$risk,events=fit$events,age_min=fit$age_min,age_max=fit$age_max,IS_ESS=fit$ESS,max_weight=fit$maxw,optim_code=fit$optim)
  }
  if(pp%%10L==0L) cat("Fitted known-age V7b pair",pp,"/",nrow(pair_index),"\n")
}
draws<-bind_rows(pooled); diagnostics<-bind_rows(diags)

summ_one<-function(z,param){x<-z[[param]]; tibble(parameter=param,mean=mean(x),sd=sd(x),median=median(x),q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))}
summary<-bind_rows(lapply(unique(draws$model),function(mm){z<-filter(draws,model==mm); pars<-intersect(c("beta_move","beta_sex","beta_age"),names(z)); bind_rows(lapply(pars,function(p)summ_one(z,p))) %>% mutate(model=mm,.before=1)}))

cat("\n============================================================\nV8PROV V7b KNOWN-AGE AGE SENSITIVITY\n============================================================\n"); print(summary,n=Inf,width=Inf)
cat("\nDiagnostics:\n"); print(diagnostics %>% group_by(model) %>% summarise(pairs=n(),median_risk=median(risk_quarters),median_events=median(events),min_ESS=min(IS_ESS),median_ESS=median(IS_ESS),max_weight=max(max_weight),optim_fail=sum(optim_code!=0),.groups="drop"),n=Inf,width=Inf)

out<-paste0("results/V8PROV_V7bM_knownage_age_",RESULT_TAG,".rds"); csv<-paste0("results/V8PROV_V7bM_knownage_age_",RESULT_TAG,"_summary.csv")
saveRDS(list(model="V8PROV V7b known-age baseline vs chronological-age adjustment",draws=draws,summary=summary,diagnostics=diagnostics,pair_index=pair_index,settings=list(age_center=AGE_CENTER,age_at_risk="Q1 birth assumption; outcome-year age + (quarter-1)/4",n_pairs=nrow(pair_index),N_PROP=N_PROP,N_KEEP=N_KEEP,development_only=TRUE)),out)
write_csv(summary,csv); cat("Saved:",out,"\nSaved:",csv,"\n")
