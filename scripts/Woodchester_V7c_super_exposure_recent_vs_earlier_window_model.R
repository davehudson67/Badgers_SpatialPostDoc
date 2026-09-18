# =============================================================================
# WOODCHESTER V7c — PARSIMONIOUS SUPER-EXPOSURE TIMING MODEL
#
# One discrete-time recipient infection-hazard model replaces eight separate lag
# models with two mutually adjusted exposure windows:
#   RECENT  = >=1 observed exact-quarter Super-excretor-state exposure in t-1/t-2
#   EARLIER = >=1 observed exact-quarter Super-excretor-state exposure in t-3/t-4
#
# Each recipient/outcome quarter appears once. This avoids treating eight lag
# models as independent tests. Exact-quarter exposure remains observation-based:
# only quarters in which the recipient has an exact recorded social group are
# used to ascertain exposure. Primary rows require >=1 observed quarter in both
# the recent and earlier windows; the numbers of observed quarters are included
# as covariates. Background infection pressure and exact capture intensity are
# averaged separately within the two windows.
# =============================================================================

library(tidyverse)
library(lubridate)

SOURCE_FILE <- "data/badger_V7c_irreversible_source_status.rds"
ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
ANNUAL_FILE <- "data/badger_annual_observed_sett_locations.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
for(f in c(SOURCE_FILE,ENCOUNTER_FILE,ANNUAL_FILE,INF_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

source_history <- as_tibble(readRDS(SOURCE_FILE)); enc <- as_tibble(readRDS(ENCOUNTER_FILE)); annual <- as_tibble(readRDS(ANNUAL_FILE)); inf <- readRDS(INF_FILE)
MAX_DRAWS <- as.integer(Sys.getenv("MAX_DRAWS","500")); N_KEEP <- as.integer(Sys.getenv("N_KEEP","100")); SEED <- as.integer(Sys.getenv("SEED","7092045")); RESULT_TAG <- Sys.getenv("RESULT_TAG","FULL_500"); END_YEAR <- as.integer(Sys.getenv("END_YEAR","2025")); set.seed(SEED)
START_YEAR <- as.integer(inf$start_year); INF_IDS <- str_to_upper(str_squish(as.character(inf$tattoo))); DRAW_IDS <- seq_len(min(MAX_DRAWS,ncol(inf$infection_time)))
qindex <- function(year,quarter) 4L*(as.integer(year)-START_YEAR)+as.integer(quarter)
qyear <- function(qtime) START_YEAR+(as.integer(qtime)-1L)%/%4L
qquarter <- function(qtime) ((as.integer(qtime)-1L)%%4L)+1L
mean_or_na <- function(x) if(length(x) && any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_

need_enc <- c("tattoo","capture_date","has_live_capture","socg"); need_annual <- c("tattoo","year","annual_socg"); need_source <- c("tattoo","capture_date","year","quarter","socg","source_class","source_rank")
if(length(miss<-setdiff(need_enc,names(enc)))) stop("Encounter file missing: ",paste(miss,collapse=", "))
if(length(miss<-setdiff(need_annual,names(annual)))) stop("Annual file missing: ",paste(miss,collapse=", "))
if(length(miss<-setdiff(need_source,names(source_history)))) stop("Source-history file missing: ",paste(miss,collapse=", "))

# =============================================================================
# 1. EXACT RECIPIENT GROUP-QUARTERS AND IRREVERSIBLE SUPER EXPOSURE
# =============================================================================

live <- enc %>% filter(has_live_capture %in% TRUE) %>% transmute(tattoo=str_to_upper(str_squish(as.character(tattoo))),capture_date=as.Date(capture_date),year=year(capture_date),quarter=quarter(capture_date),qtime=qindex(year,quarter),socg=as.character(socg)) %>% filter(!is.na(tattoo),tattoo!="",!is.na(capture_date))
live_bounds <- live %>% group_by(tattoo) %>% summarise(first_live_q=min(qtime),last_live_q=max(qtime),.groups="drop")
qm_all <- live %>% filter(!is.na(socg),socg!="") %>% distinct(tattoo,year,quarter,qtime,socg)
ambiguous_q <- qm_all %>% group_by(tattoo,qtime) %>% summarise(n_groups=n_distinct(socg),.groups="drop") %>% filter(n_groups>1L)
qm <- qm_all %>% anti_join(ambiguous_q %>% select(tattoo,qtime),by=c("tattoo","qtime")) %>% distinct(tattoo,qtime,.keep_all=TRUE)
group_capture_n <- qm %>% count(year,quarter,qtime,socg,name="n_exact_members")

sex_candidates <- c("sex","Sex","SEX"); sex_col <- sex_candidates[sex_candidates %in% names(enc)][1]; USE_SEX <- length(sex_col)==1L && !is.na(sex_col)
if(USE_SEX){
  sex_by_id <- enc %>% transmute(tattoo=str_to_upper(str_squish(as.character(tattoo))),sex_raw=str_to_upper(str_squish(as.character(.data[[sex_col]])))) %>% mutate(sex_class=case_when(sex_raw %in% c("M","MALE","1")~"M",sex_raw %in% c("F","FEMALE","0")~"F",TRUE~NA_character_)) %>% filter(!is.na(tattoo),tattoo!="",!is.na(sex_class)) %>% count(tattoo,sex_class,name="n") %>% arrange(tattoo,desc(n),sex_class) %>% group_by(tattoo) %>% slice(1L) %>% ungroup() %>% select(tattoo,sex_class)
}else sex_by_id <- tibble(tattoo=character(),sex_class=character())

source_occ <- source_history %>% transmute(source_tattoo=str_to_upper(str_squish(as.character(tattoo))),year=as.integer(year),quarter=as.integer(quarter),qtime=qindex(year,quarter),socg=as.character(socg),source_class=as.character(source_class),source_rank=as.integer(source_rank)) %>% filter(year<=END_YEAR,source_rank>=3L,source_class %in% c("Excretor","Super excretor"),!is.na(source_tattoo),source_tattoo!="",!is.na(socg),socg!="") %>% distinct(source_tattoo,year,quarter,qtime,socg,source_class)
source_counts <- source_occ %>% group_by(year,quarter,qtime,socg) %>% summarise(n_sources=n_distinct(source_tattoo),n_super=n_distinct(source_tattoo[source_class=="Super excretor"]),.groups="drop")
source_members <- source_occ %>% group_by(year,quarter,qtime,socg,source_tattoo) %>% summarise(is_source=TRUE,.groups="drop")

context <- qm %>% filter(year<=END_YEAR) %>% mutate(inf_row=match(tattoo,INF_IDS)) %>% filter(!is.na(inf_row)) %>% left_join(live_bounds,by="tattoo") %>% left_join(group_capture_n,by=c("year","quarter","qtime","socg")) %>% left_join(source_counts,by=c("year","quarter","qtime","socg")) %>% mutate(n_sources=replace_na(n_sources,0L),n_super=replace_na(n_super,0L),other_captured=pmax(n_exact_members-1L,0L)) %>% left_join(source_members %>% rename(tattoo=source_tattoo,recipient_is_source=is_source),by=c("tattoo","year","quarter","qtime","socg")) %>% mutate(recipient_is_source=replace_na(recipient_is_source,FALSE)) %>% filter(!recipient_is_source) %>% mutate(any_super=n_super>0L,context_id=paste(year,quarter,socg,sep="|")) %>% left_join(sex_by_id,by="tattoo")
if(!nrow(context)) stop("No eligible exact-quarter recipient contexts.")
if(anyDuplicated(context[c("tattoo","qtime")])) stop("Duplicate recipient-quarter context rows remain.")

# Static window history. One recipient/outcome quarter will later become one risk row.
window_static <- context %>% select(tattoo,qtime,socg,any_super,other_captured,context_id) %>% tidyr::crossing(lag_quarters=1:4) %>% mutate(outcome_qtime=qtime+lag_quarters,window=if_else(lag_quarters<=2L,"RECENT","EARLIER")) %>% group_by(tattoo,outcome_qtime) %>% summarise(
  n_recent_observed=sum(window=="RECENT"),n_earlier_observed=sum(window=="EARLIER"),
  super_recent=any(any_super[window=="RECENT"]),super_earlier=any(any_super[window=="EARLIER"]),
  capture_recent=mean_or_na(other_captured[window=="RECENT"]),capture_earlier=mean_or_na(other_captured[window=="EARLIER"]),
  cluster_group=socg[which.min(lag_quarters)],.groups="drop") %>%
  filter(n_recent_observed>=1L,n_earlier_observed>=1L) %>% mutate(outcome_year=qyear(outcome_qtime),outcome_quarter=qquarter(outcome_qtime),decade=10L*(outcome_year%/%10L)) %>% filter(outcome_year<=END_YEAR) %>%
  left_join(live_bounds,by="tattoo") %>% filter(outcome_qtime<=last_live_q) %>% mutate(inf_row=match(tattoo,INF_IDS)) %>% filter(!is.na(inf_row)) %>% left_join(sex_by_id,by="tattoo")

if(!nrow(window_static)) stop("No outcome quarters have observed exposure information in both 1-2q and 3-4q windows.")
if(anyDuplicated(window_static[c("tattoo","outcome_qtime")])) stop("Duplicate windowed outcome rows remain.")

support_combo <- window_static %>% count(super_recent,super_earlier,name="outcome_quarters")
observation_support <- window_static %>% summarise(outcome_quarters=n(),unique_badgers=n_distinct(tattoo),both_windows_fully_observed=sum(n_recent_observed==2L & n_earlier_observed==2L),p_both_windows_fully_observed=mean(n_recent_observed==2L & n_earlier_observed==2L),median_recent_observed=median(n_recent_observed),median_earlier_observed=median(n_earlier_observed))

# =============================================================================
# 2. BACKGROUND PRESSURE FOR EACH OBSERVED EXPOSURE CONTEXT
# =============================================================================

annual2 <- annual %>% transmute(member_tattoo=str_to_upper(str_squish(as.character(tattoo))),year=as.integer(year),socg=as.character(annual_socg),member_inf_row=match(str_to_upper(str_squish(as.character(tattoo))),INF_IDS)) %>% filter(!is.na(member_tattoo),member_tattoo!="",!is.na(year),!is.na(socg),socg!="",!is.na(member_inf_row)) %>% distinct(member_tattoo,year,.keep_all=TRUE)
context_groups <- context %>% distinct(context_id,year,quarter,qtime,socg)
bg_long <- context_groups %>% inner_join(annual2,by=c("year","socg"),relationship="many-to-many") %>% left_join(source_occ %>% distinct(qtime,socg,source_tattoo) %>% mutate(observed_source=TRUE),by=c("qtime","socg","member_tattoo"="source_tattoo")) %>% mutate(observed_source=replace_na(observed_source,FALSE)) %>% filter(!observed_source) %>% select(context_id,qtime,socg,member_tattoo,member_inf_row)
if(!nrow(bg_long)) stop("No background group-member rows.")
focal_in_bg <- bg_long %>% transmute(context_id,tattoo=member_tattoo) %>% inner_join(context %>% select(context_id,tattoo),by=c("context_id","tattoo")) %>% distinct(context_id,tattoo) %>% mutate(focal_in_background=TRUE)
context <- context %>% left_join(focal_in_bg,by=c("context_id","tattoo")) %>% mutate(focal_in_background=replace_na(focal_in_background,FALSE))

# =============================================================================
# 3. MODEL HELPERS
# =============================================================================

inv_psd <- function(M){M<-(M+t(M))/2; ee<-eigen(M,symmetric=TRUE); tol<-max(1e-12,max(abs(ee$values))*1e-10); keep<-ee$values>tol; if(!any(keep)) stop("No positive information eigenvalues."); V<-ee$vectors[,keep,drop=FALSE]; V%*%diag(1/ee$values[keep],nrow=sum(keep))%*%t(V)}
rmvn_psd <- function(n,mu,Sigma){mu<-as.numeric(mu); Sigma<-(as.matrix(Sigma)+t(as.matrix(Sigma)))/2; if(any(!is.finite(mu))||any(!is.finite(Sigma))) stop("Invalid MVN inputs."); ee<-eigen(Sigma,symmetric=TRUE); ee$values[ee$values<1e-10]<-1e-10; A<-ee$vectors%*%diag(sqrt(ee$values),nrow=length(ee$values)); Z<-matrix(rnorm(n*length(mu)),nrow=n); sweep(Z%*%t(A),2,mu,"+")}
cluster_meat <- function(score_rows,cluster,N,K){U<-rowsum(score_rows,group=as.character(cluster),reorder=FALSE); G<-nrow(U); correction<-if(G>1L&&N>K)(G/(G-1))*((N-1)/(N-K)) else 1; correction*crossprod(U)}
DECADES <- sort(unique(window_static$decade))

build_X <- function(d){
  cols <- list("(Intercept)"=rep(1,nrow(d)),super_recent=as.numeric(d$super_recent),super_earlier=as.numeric(d$super_earlier),background_recent10=10*as.numeric(d$background_recent),background_earlier10=10*as.numeric(d$background_earlier),recent_observed2=as.numeric(d$n_recent_observed==2L),earlier_observed2=as.numeric(d$n_earlier_observed==2L),capture_recent_log=log1p(as.numeric(d$capture_recent)),capture_earlier_log=log1p(as.numeric(d$capture_earlier)))
  if(USE_SEX){cols$sex_male<-as.numeric(d$sex_class=="M" & !is.na(d$sex_class)); cols$sex_unknown<-as.numeric(is.na(d$sex_class))}
  cols$outcome_Q2<-as.numeric(d$outcome_quarter==2L); cols$outcome_Q3<-as.numeric(d$outcome_quarter==3L); cols$outcome_Q4<-as.numeric(d$outcome_quarter==4L)
  for(p in DECADES[-1L]) cols[[paste0("decade",p)]] <- as.numeric(d$decade==p)
  X<-do.call(cbind,cols); storage.mode(X)<-"double"; X
}

fit_window_model <- function(d,nkeep){
  X<-build_X(d); y<-as.numeric(d$event); cl_badger<-as.character(d$tattoo); cl_group<-as.character(d$cluster_group); cl_intersection<-paste(cl_badger,cl_group,sep="|")
  if(any(!is.finite(X))||any(!is.finite(y))) return(list(ok=FALSE,draws=NULL,message="invalid model inputs",warning=""))
  warns<-character(0); fit<-tryCatch(withCallingHandlers(stats::glm.fit(x=X,y=y,family=stats::binomial(link="logit"),control=stats::glm.control(maxit=100,epsilon=1e-8),intercept=TRUE),warning=function(w){warns<<-c(warns,conditionMessage(w)); invokeRestart("muffleWarning")}),error=function(e)e)
  if(inherits(fit,"error")) return(list(ok=FALSE,draws=NULL,message=conditionMessage(fit),warning=paste(unique(warns),collapse=" | ")))
  if(!isTRUE(fit$converged)) return(list(ok=FALSE,draws=NULL,message="glm.fit did not converge",warning=paste(unique(warns),collapse=" | ")))
  cf_all<-fit$coefficients; active<-which(is.finite(cf_all)); if(!length(active)) return(list(ok=FALSE,draws=NULL,message="no estimable coefficients",warning=paste(unique(warns),collapse=" | ")))
  Xa<-X[,active,drop=FALSE]; cf<-cf_all[active]; names(cf)<-colnames(X)[active]; mu<-as.numeric(fit$fitted.values)
  rob<-tryCatch({w<-pmax(mu*(1-mu),1e-12); bread<-inv_psd(crossprod(Xa,Xa*w)); score_rows<-Xa*as.numeric(y-mu); N<-nrow(Xa); K<-ncol(Xa); meat<-cluster_meat(score_rows,cl_badger,N,K)+cluster_meat(score_rows,cl_group,N,K)-cluster_meat(score_rows,cl_intersection,N,K); V<-bread%*%meat%*%bread; V<-(V+t(V))/2; rownames(V)<-colnames(V)<-names(cf); list(beta=cf,V=V)},error=function(e)e)
  if(inherits(rob,"error")) return(list(ok=FALSE,draws=NULL,message=paste("robust covariance failed:",conditionMessage(rob)),warning=paste(unique(warns),collapse=" | ")))
  dr<-tryCatch(rmvn_psd(nkeep,rob$beta,rob$V),error=function(e)e); if(inherits(dr,"error")) return(list(ok=FALSE,draws=NULL,message=paste("MVN draw failed:",conditionMessage(dr)),warning=paste(unique(warns),collapse=" | ")))
  colnames(dr)<-names(rob$beta); list(ok=TRUE,draws=as_tibble(dr),message="",warning=paste(unique(warns),collapse=" | "))
}

# =============================================================================
# 4. FIT ACROSS INFECTION TRAJECTORIES
# =============================================================================

cat("\n============================================================\nV7c PARSIMONIOUS SUPER-EXPOSURE TIMING MODEL\n============================================================\n")
cat("Infection-history draws:",length(DRAW_IDS),"\nCoefficient draws/history:",N_KEEP,"\n")
cat("Eligible outcome-quarter rows:",nrow(window_static),"\nUnique badgers:",n_distinct(window_static$tattoo),"\n")
cat("\nOBSERVATION SUPPORT\n"); print(observation_support,n=Inf,width=Inf)
cat("\nSUPER-EXPOSURE WINDOW COMBINATIONS\n"); print(support_combo,n=Inf,width=Inf); cat("\n")

draw_list<-list(); diag_list<-list(); nd<-0L
for(dd in DRAW_IDS){
  bb<-bg_long; bt<-as.integer(inf$infection_time[bb$member_inf_row,dd]); bb$infected_q0<-bt>0L & bt<=bb$qtime
  bg_stats<-bb %>% group_by(context_id) %>% summarise(background_n=n(),background_infected=sum(infected_q0),.groups="drop")
  cd<-context %>% left_join(bg_stats,by="context_id") %>% mutate(background_n_loo=background_n-as.integer(focal_in_background),background_pressure=background_infected/background_n_loo) %>% filter(background_n_loo>0,is.finite(background_pressure))
  dyn_windows<-cd %>% select(tattoo,qtime,context_id,background_pressure) %>% tidyr::crossing(lag_quarters=1:4) %>% mutate(outcome_qtime=qtime+lag_quarters,window=if_else(lag_quarters<=2L,"RECENT","EARLIER")) %>% group_by(tattoo,outcome_qtime) %>% summarise(background_recent=mean_or_na(background_pressure[window=="RECENT"]),background_earlier=mean_or_na(background_pressure[window=="EARLIER"]),.groups="drop")
  d<-window_static %>% left_join(dyn_windows,by=c("tattoo","outcome_qtime"))
  tt<-as.integer(inf$infection_time[d$inf_row,dd]); d<-d %>% mutate(infection_time=tt,at_risk=(infection_time==0L | infection_time>=outcome_qtime),event=(infection_time==outcome_qtime)) %>% filter(at_risk,is.finite(background_recent),is.finite(background_earlier)) %>% select(-infection_time)
  fit<-fit_window_model(d,N_KEEP)
  diag_list[[dd]]<-tibble(infection_draw=dd,n_risk=nrow(d),n_events=sum(d$event),n_badgers=n_distinct(d$tattoo),n_groups=n_distinct(d$cluster_group),recent_super_rows=sum(d$super_recent),earlier_super_rows=sum(d$super_earlier),events_recent_super=sum(d$event & d$super_recent),events_earlier_super=sum(d$event & d$super_earlier),fit_ok=fit$ok,warnings=fit$warning,message=fit$message)
  if(fit$ok){z<-fit$draws; if(all(c("super_recent","super_earlier") %in% names(z))) z$recent_vs_earlier<-z$super_recent-z$super_earlier; z$infection_draw<-dd; nd<-nd+1L; draw_list[[nd]]<-z}
  if(dd%%25L==0L || dd==max(DRAW_IDS)) cat("Processed infection draw",dd,"/",max(DRAW_IDS),"\n")
}

draws<-bind_rows(draw_list); diag<-bind_rows(diag_list); if(!nrow(draws)) stop("No timing-window models fitted successfully.")
cat("\n============================================================\nFIT AUDIT\n============================================================\n")
fit_audit<-diag %>% summarise(draws=n(),fitted=sum(fit_ok),failed=sum(!fit_ok),draws_with_warnings=sum(nchar(warnings)>0),median_risk=median(n_risk),median_events=median(n_events),median_badgers=median(n_badgers),median_groups=median(n_groups),median_recent_super_rows=median(recent_super_rows),median_earlier_super_rows=median(earlier_super_rows),median_events_recent_super=median(events_recent_super),median_events_earlier_super=median(events_earlier_super))
print(fit_audit,n=Inf,width=Inf)
if(any(!diag$fit_ok)){cat("\nFailures:\n"); print(diag %>% filter(!fit_ok) %>% count(message,sort=TRUE),n=100,width=Inf)}
if(any(nchar(diag$warnings)>0)){cat("\nWarnings:\n"); print(diag %>% filter(nchar(warnings)>0) %>% count(warnings,sort=TRUE),n=100,width=Inf)}

summ <- function(param,label){if(!param %in% names(draws)) return(NULL); x<-as.numeric(draws[[param]]); x<-x[is.finite(x)]; tibble(parameter=label,n_draws=length(x),median=median(x),q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))}
summary_table<-bind_rows(summ("super_recent","beta_super_recent_1_2q"),summ("super_earlier","beta_super_earlier_3_4q"),summ("recent_vs_earlier","beta_recent_vs_earlier"),summ("background_recent10","beta_background_recent_per_10pp"),summ("background_earlier10","beta_background_earlier_per_10pp"),summ("sex_male","beta_recipient_male"))
cat("\n============================================================\nRECENT 1-2q vs EARLIER 3-4q SUPER-EXPOSURE SUMMARY\n============================================================\n"); print(summary_table,n=Inf,width=Inf)
cat("\nINTERPRETATION GUIDE\n")
cat("- beta_super_recent_1_2q and beta_super_earlier_3_4q are mutually adjusted in one model.\n")
cat("- beta_recent_vs_earlier directly tests whether the recent association exceeds the earlier association.\n")
cat("- Each recipient/outcome quarter is represented once; this is not eight independent lag tests.\n")
cat("- Exposure remains exact-quarter observation based; rows require >=1 observed recipient group-quarter in each two-quarter window.\n")
cat("- Numbers of observed quarters, background pressure and capture intensity in each window are adjusted.\n")
cat("- This remains an observational association and does not attribute transmission to a specific source.\n")

dir.create("results",showWarnings=FALSE,recursive=TRUE)
out_rds<-paste0("results/V7c_super_exposure_window_timing_",RESULT_TAG,".rds"); out_summary<-paste0("results/V7c_super_exposure_window_timing_",RESULT_TAG,"_summary.csv"); out_fit<-paste0("results/V7c_super_exposure_window_timing_",RESULT_TAG,"_fit_audit.csv")
saveRDS(list(model="V7c one-model Super exposure timing: recent 1-2q vs earlier 3-4q",coefficient_draws=draws,summary=summary_table,fit_audit=fit_audit,fit_diagnostics=diag,observation_support=observation_support,exposure_combinations=support_combo,settings=list(infection_draws=length(DRAW_IDS),draws_per_history=N_KEEP,end_year=END_YEAR,recent_window="t-1,t-2",earlier_window="t-3,t-4",eligibility=">=1 observed exact recipient social-group quarter in each window",covariance="two-way cluster robust by recipient and most recent observed social group")),out_rds)
write_csv(summary_table,out_summary); write_csv(fit_audit,out_fit)
cat("\nSaved:",out_rds,"\nSaved:",out_summary,"\nSaved:",out_fit,"\n")
