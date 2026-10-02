# =============================================================================
# WOODCHESTER V7c — CURRENT CULTURE-SHEDDING SENSITIVITY
#
# Question: is subsequent infection acquisition elevated after sharing an exact
# social-group quarter with an animal that is culture-positive AT THAT CAPTURE,
# especially when >=2 distinct culture sample/body sites are positive?
#
# This differs from the primary irreversible source-state analysis. Here source
# exposure is occasion-specific:
#   ordinary current shedder = culture-positive at >=1 site, but not >=2 sites
#   current multi-site shedder = >=2 positive culture sample/body sites
#
# A source must be live-captured in the recipient's exact recorded social group
# and quarter. A later negative culture does not alter the irreversible disease
# history; it simply means the animal is not counted as a CURRENT shedder at that
# capture. Results are therefore a shedding sensitivity, not a replacement for
# the primary irreversible-state analysis.
# =============================================================================

library(tidyverse)
library(lubridate)

SOURCE_FILE <- "data/badger_V7c_irreversible_source_status.rds"
ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
ANNUAL_FILE <- "data/badger_annual_observed_sett_locations.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
for(f in c(SOURCE_FILE,ENCOUNTER_FILE,ANNUAL_FILE,INF_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

source_history <- as_tibble(readRDS(SOURCE_FILE))
enc <- as_tibble(readRDS(ENCOUNTER_FILE))
annual <- as_tibble(readRDS(ANNUAL_FILE))
inf <- readRDS(INF_FILE)

MAX_DRAWS <- as.integer(Sys.getenv("MAX_DRAWS","500"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","100"))
SEED <- as.integer(Sys.getenv("SEED","7092045"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","FULL_500")
END_YEAR <- as.integer(Sys.getenv("END_YEAR","2025"))
set.seed(SEED)

START_YEAR <- as.integer(inf$start_year)
INF_IDS <- str_to_upper(str_squish(as.character(inf$tattoo)))
N_INF_DRAW <- ncol(inf$infection_time)
DRAW_IDS <- seq_len(min(MAX_DRAWS,N_INF_DRAW))
LAGS <- 1:8

qindex <- function(year,quarter) 4L*(as.integer(year)-START_YEAR)+as.integer(quarter)
qyear <- function(qtime) START_YEAR+(as.integer(qtime)-1L)%/%4L
qquarter <- function(qtime) ((as.integer(qtime)-1L)%%4L)+1L

need_enc <- c("tattoo","capture_date","has_live_capture","socg")
need_annual <- c("tattoo","year","annual_socg")
need_source <- c("tattoo","capture_date","year","quarter","socg","current_culture_positive","current_super_trigger")
miss_enc <- setdiff(need_enc,names(enc)); if(length(miss_enc)) stop("Encounter file is missing: ",paste(miss_enc,collapse=", "))
miss_annual <- setdiff(need_annual,names(annual)); if(length(miss_annual)) stop("Annual location file is missing: ",paste(miss_annual,collapse=", "))
miss_source <- setdiff(need_source,names(source_history)); if(length(miss_source)) stop("Irreversible source-history file is missing current-culture fields: ",paste(miss_source,collapse=", "))

# =============================================================================
# 1. LIVE HISTORY, EXACT QUARTER MEMBERSHIP, SEX
# =============================================================================

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(tattoo=str_to_upper(str_squish(as.character(tattoo))),capture_date=as.Date(capture_date),year=year(capture_date),quarter=quarter(capture_date),qtime=qindex(year,quarter),socg=as.character(socg)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(capture_date))

live_bounds <- live %>% group_by(tattoo) %>% summarise(first_live_q=min(qtime),last_live_q=max(qtime),.groups="drop")
quarter_members_all <- live %>% filter(!is.na(socg),socg!="") %>% distinct(tattoo,year,quarter,qtime,socg)
ambiguous_q <- quarter_members_all %>% group_by(tattoo,qtime) %>% summarise(n_groups=n_distinct(socg),.groups="drop") %>% filter(n_groups>1L)
quarter_members <- quarter_members_all %>% anti_join(ambiguous_q %>% select(tattoo,qtime),by=c("tattoo","qtime")) %>% distinct(tattoo,qtime,.keep_all=TRUE)

sex_candidates <- c("sex","Sex","SEX")
sex_col <- sex_candidates[sex_candidates %in% names(enc)][1]
USE_SEX <- length(sex_col)==1L && !is.na(sex_col)
if(USE_SEX){
  sex_by_id <- enc %>%
    transmute(tattoo=str_to_upper(str_squish(as.character(tattoo))),sex_raw=str_to_upper(str_squish(as.character(.data[[sex_col]])))) %>%
    mutate(sex_class=case_when(sex_raw %in% c("M","MALE","1")~"M",sex_raw %in% c("F","FEMALE","0")~"F",TRUE~NA_character_)) %>%
    filter(!is.na(tattoo),tattoo!="",!is.na(sex_class)) %>% count(tattoo,sex_class,name="n") %>% arrange(tattoo,desc(n),sex_class) %>%
    group_by(tattoo) %>% slice(1L) %>% ungroup() %>% select(tattoo,sex_class)
}else sex_by_id <- tibble(tattoo=character(),sex_class=character())

# =============================================================================
# 2. CURRENT SHEDDING SOURCE GROUP-QUARTERS
# =============================================================================

source_occ <- source_history %>%
  transmute(
    source_tattoo=str_to_upper(str_squish(as.character(tattoo))),capture_date=as.Date(capture_date),year=as.integer(year),quarter=as.integer(quarter),
    qtime=qindex(year,quarter),socg=as.character(socg),current_positive=replace_na(as.logical(current_culture_positive),FALSE),
    current_multisite=replace_na(as.logical(current_super_trigger),FALSE)
  ) %>%
  filter(year<=END_YEAR,current_positive,!is.na(source_tattoo),source_tattoo!="",!is.na(socg),socg!="") %>%
  mutate(shedding_class=if_else(current_multisite,"MULTISITE","ORDINARY")) %>%
  distinct(source_tattoo,year,quarter,qtime,socg,shedding_class)

if(!nrow(source_occ)) stop("No current culture-positive source occasions found.")

source_counts <- source_occ %>%
  group_by(year,quarter,qtime,socg) %>%
  summarise(n_current_shedders=n_distinct(source_tattoo),n_multisite_shedders=n_distinct(source_tattoo[shedding_class=="MULTISITE"]),.groups="drop")

source_members <- source_occ %>%
  group_by(year,quarter,qtime,socg,source_tattoo) %>%
  summarise(source_is_multisite=any(shedding_class=="MULTISITE"),.groups="drop")

source_support_year <- source_occ %>%
  group_by(year) %>%
  summarise(current_positive_source_occasions=n(),current_multisite_source_occasions=sum(shedding_class=="MULTISITE"),source_badgers=n_distinct(source_tattoo),multisite_badgers=n_distinct(source_tattoo[shedding_class=="MULTISITE"]),.groups="drop")

context <- quarter_members %>%
  filter(year<=END_YEAR) %>% mutate(inf_row=match(tattoo,INF_IDS)) %>% filter(!is.na(inf_row)) %>%
  left_join(live_bounds,by="tattoo") %>% left_join(source_counts,by=c("year","quarter","qtime","socg")) %>%
  mutate(n_current_shedders=replace_na(n_current_shedders,0L),n_multisite_shedders=replace_na(n_multisite_shedders,0L)) %>%
  left_join(source_members %>% rename(tattoo=source_tattoo,recipient_is_multisite_source=source_is_multisite) %>% mutate(recipient_is_current_source=TRUE),by=c("tattoo","year","quarter","qtime","socg")) %>%
  mutate(recipient_is_current_source=replace_na(recipient_is_current_source,FALSE),recipient_is_multisite_source=replace_na(recipient_is_multisite_source,FALSE)) %>%
  filter(!recipient_is_current_source) %>%
  mutate(any_current_source=n_current_shedders>0L,any_multisite_source=n_multisite_shedders>0L,ordinary_source_only=any_current_source & !any_multisite_source,context_id=paste(year,quarter,socg,sep="|")) %>%
  left_join(sex_by_id,by="tattoo")

if(!nrow(context)) stop("No eligible exact-quarter recipient context rows.")
if(anyDuplicated(context[c("tattoo","qtime")])) stop("Internal error: duplicate recipient-quarter context rows remain after ambiguous quarters were removed.")

context_support_year <- context %>%
  group_by(year) %>%
  summarise(recipient_contexts=n(),current_source_contexts=sum(any_current_source),multisite_source_contexts=sum(any_multisite_source),unique_recipients=n_distinct(tattoo),.groups="drop")

# =============================================================================
# 3. BACKGROUND INFECTION PRESSURE
# =============================================================================

annual2 <- annual %>%
  transmute(member_tattoo=str_to_upper(str_squish(as.character(tattoo))),year=as.integer(year),socg=as.character(annual_socg),member_inf_row=match(str_to_upper(str_squish(as.character(tattoo))),INF_IDS)) %>%
  filter(!is.na(member_tattoo),member_tattoo!="",!is.na(year),!is.na(socg),socg!="",!is.na(member_inf_row)) %>% distinct(member_tattoo,year,.keep_all=TRUE)

context_groups <- context %>% distinct(context_id,year,quarter,qtime,socg)
bg_long <- context_groups %>%
  inner_join(annual2,by=c("year","socg"),relationship="many-to-many") %>%
  left_join(source_occ %>% distinct(qtime,socg,source_tattoo) %>% mutate(observed_current_source=TRUE),by=c("qtime","socg","member_tattoo"="source_tattoo")) %>%
  mutate(observed_current_source=replace_na(observed_current_source,FALSE)) %>% filter(!observed_current_source) %>%
  select(context_id,qtime,socg,member_tattoo,member_inf_row)
if(!nrow(bg_long)) stop("No background group-member rows could be constructed.")

focal_in_bg <- bg_long %>% transmute(context_id,tattoo=member_tattoo) %>% inner_join(context %>% select(context_id,tattoo),by=c("context_id","tattoo")) %>% distinct(context_id,tattoo) %>% mutate(focal_in_background=TRUE)
context <- context %>% left_join(focal_in_bg,by=c("context_id","tattoo")) %>% mutate(focal_in_background=replace_na(focal_in_background,FALSE))

# =============================================================================
# 4. MODEL HELPERS
# =============================================================================

inv_psd <- function(M){
  M <- (M+t(M))/2; ee <- eigen(M,symmetric=TRUE); tol <- max(1e-12,max(abs(ee$values))*1e-10); keep <- ee$values>tol
  if(!any(keep)) stop("Information matrix has no positive eigenvalues.")
  V <- ee$vectors[,keep,drop=FALSE]; V %*% diag(1/ee$values[keep],nrow=sum(keep)) %*% t(V)
}

rmvn_psd <- function(n,mu,Sigma){
  mu <- as.numeric(mu); Sigma <- as.matrix(Sigma); Sigma <- (Sigma+t(Sigma))/2
  if(!length(mu) || any(!is.finite(mu)) || any(!is.finite(Sigma))) stop("Invalid MVN inputs.")
  ee <- eigen(Sigma,symmetric=TRUE); ee$values[ee$values<1e-10] <- 1e-10
  A <- ee$vectors %*% diag(sqrt(ee$values),nrow=length(ee$values)); Z <- matrix(rnorm(n*length(mu)),nrow=n); sweep(Z %*% t(A),2,mu,"+")
}

DECADES <- sort(unique(10L*(qyear(context$qtime+1L)%/%10L)))

build_X <- function(d,model){
  cols <- list("(Intercept)"=rep(1,nrow(d)),background_pressure10=10*as.numeric(d$background_pressure))
  if(USE_SEX){cols$sex_male <- as.numeric(d$sex_class=="M" & !is.na(d$sex_class)); cols$sex_unknown <- as.numeric(is.na(d$sex_class))}
  cols$outcome_Q2 <- as.numeric(d$outcome_quarter==2L); cols$outcome_Q3 <- as.numeric(d$outcome_quarter==3L); cols$outcome_Q4 <- as.numeric(d$outcome_quarter==4L)
  for(p in DECADES[-1L]) cols[[paste0("decade",p)]] <- as.numeric(d$decade==p)
  if(model=="S_MULTISITE") cols$any_multisite_source <- as.numeric(d$any_multisite_source)
  if(model=="C_SHEDDING_CLASS"){
    cols$ordinary_source_only <- as.numeric(d$ordinary_source_only)
    cols$any_multisite_source <- as.numeric(d$any_multisite_source)
  }
  X <- do.call(cbind,cols); storage.mode(X) <- "double"; X
}

cluster_meat <- function(score_rows,cluster,N,K){
  cluster <- as.character(cluster); U <- rowsum(score_rows,group=cluster,reorder=FALSE); G <- nrow(U)
  correction <- if(G>1L && N>K) (G/(G-1))*((N-1)/(N-K)) else 1; correction*crossprod(U)
}

fit_binary_hazard <- function(model,d,nkeep){
  X <- build_X(d,model); y <- as.numeric(d$event); cl_badger <- as.character(d$tattoo); cl_group <- as.character(d$socg); cl_intersection <- paste(cl_badger,cl_group,sep="|")
  finite_by_col <- colSums(!is.finite(X))
  if(any(finite_by_col>0) || any(!is.finite(y))) return(list(ok=FALSE,draws=NULL,message="invalid model inputs",warning=""))
  warns <- character(0)
  fit <- tryCatch(withCallingHandlers(stats::glm.fit(x=X,y=y,family=stats::binomial(link="logit"),control=stats::glm.control(maxit=100,epsilon=1e-8),intercept=TRUE),warning=function(w){warns <<- c(warns,conditionMessage(w)); invokeRestart("muffleWarning")}),error=function(e)e)
  if(inherits(fit,"error")) return(list(ok=FALSE,draws=NULL,message=conditionMessage(fit),warning=paste(unique(warns),collapse=" | ")))
  if(!isTRUE(fit$converged)) return(list(ok=FALSE,draws=NULL,message="glm.fit did not converge",warning=paste(unique(warns),collapse=" | ")))
  cf_all <- fit$coefficients; active <- which(is.finite(cf_all)); if(!length(active)) return(list(ok=FALSE,draws=NULL,message="no estimable coefficients",warning=paste(unique(warns),collapse=" | ")))
  Xa <- X[,active,drop=FALSE]; cf <- cf_all[active]; names(cf) <- colnames(X)[active]; mu <- as.numeric(fit$fitted.values)
  rob <- tryCatch({
    w <- pmax(mu*(1-mu),1e-12); bread <- inv_psd(crossprod(Xa,Xa*w)); score_rows <- Xa*as.numeric(y-mu); N <- nrow(Xa); K <- ncol(Xa)
    meat <- cluster_meat(score_rows,cl_badger,N,K)+cluster_meat(score_rows,cl_group,N,K)-cluster_meat(score_rows,cl_intersection,N,K)
    V <- bread %*% meat %*% bread; V <- (V+t(V))/2; rownames(V) <- colnames(V) <- names(cf); list(beta=cf,V=V)
  },error=function(e)e)
  if(inherits(rob,"error")) return(list(ok=FALSE,draws=NULL,message=paste("two-way robust covariance failed:",conditionMessage(rob)),warning=paste(unique(warns),collapse=" | ")))
  dr <- tryCatch(rmvn_psd(nkeep,rob$beta,rob$V),error=function(e)e)
  if(inherits(dr,"error")) return(list(ok=FALSE,draws=NULL,message=paste("MVN draw failed:",conditionMessage(dr)),warning=paste(unique(warns),collapse=" | ")))
  colnames(dr) <- names(rob$beta); list(ok=TRUE,draws=as_tibble(dr),message="",warning=paste(unique(warns),collapse=" | "))
}

# =============================================================================
# 5. LOOP ACROSS INFECTION TRAJECTORIES
# =============================================================================

cat("\n============================================================\n")
cat("V7c CURRENT CULTURE-SHEDDING SENSITIVITY\n")
cat("============================================================\n")
cat("Infection-history draws:",length(DRAW_IDS),"\n")
cat("Coefficient draws/history/model:",N_KEEP,"\n")
cat("Exact recipient group-quarters:",nrow(context),"\n")
cat("Unique recipient badgers:",n_distinct(context$tattoo),"\n")
cat("Current culture-positive recipient contexts:",sum(context$any_current_source),"\n")
cat("Current >=2-site positive recipient contexts:",sum(context$any_multisite_source),"\n")
cat("Outcome years capped at:",END_YEAR,"\n")
cat("Covariance: two-way cluster robust by recipient and social group.\n\n")
cat("CURRENT SHEDDING SOURCE SUPPORT BY YEAR\n"); print(source_support_year,n=Inf,width=Inf)
cat("\nRECIPIENT EXPOSURE SUPPORT BY YEAR\n"); print(context_support_year,n=Inf,width=Inf); cat("\n")

draw_list <- list(); diag_list <- list(); nd <- 0L; ng <- 0L
models <- c("B_BACKGROUND","S_MULTISITE","C_SHEDDING_CLASS")

for(dd in DRAW_IDS){
  bb <- bg_long; bt <- as.integer(inf$infection_time[bb$member_inf_row,dd]); bb$infected_q0 <- bt>0L & bt<=bb$qtime
  bg_stats <- bb %>% group_by(context_id) %>% summarise(background_n=n(),background_infected=sum(infected_q0),.groups="drop")
  cd <- context %>% left_join(bg_stats,by="context_id"); tt_context <- as.integer(inf$infection_time[cd$inf_row,dd])
  for(lag in LAGS){
    outcome_q <- cd$qtime+lag; outcome_year <- qyear(outcome_q); outcome_quarter <- qquarter(outcome_q)
    d <- cd %>% mutate(infection_time=tt_context,outcome_qtime=outcome_q,outcome_year=outcome_year,outcome_quarter=outcome_quarter,background_n_loo=background_n-as.integer(focal_in_background),background_pressure=background_infected/background_n_loo,at_risk=(infection_time==0L | infection_time>=outcome_qtime),event=(infection_time==outcome_qtime),decade=10L*(outcome_year%/%10L)) %>%
      filter(outcome_qtime<=last_live_q,outcome_year<=END_YEAR,at_risk,is.finite(background_pressure),background_n_loo>0) %>% select(-infection_time)
    if(anyDuplicated(d[c("tattoo","outcome_qtime")])) stop("Internal error: duplicate recipient-quarter risk rows at lag ",lag," draw ",dd)
    if(!nrow(d)) next
    for(mm in models){
      fit <- fit_binary_hazard(mm,d,N_KEEP); ng <- ng+1L
      diag_list[[ng]] <- tibble(infection_draw=dd,lag_quarters=lag,model=mm,n_risk=nrow(d),n_events=sum(d$event),n_badgers=n_distinct(d$tattoo),n_groups=n_distinct(d$socg),n_multisite_exposed=sum(d$any_multisite_source),n_ordinary_exposed=sum(d$ordinary_source_only),events_multisite=sum(d$event & d$any_multisite_source),events_ordinary=sum(d$event & d$ordinary_source_only),median_background_n=median(d$background_n_loo),fit_ok=fit$ok,warnings=fit$warning,message=fit$message)
      if(fit$ok){
        z <- fit$draws
        if(mm=="C_SHEDDING_CLASS" && all(c("ordinary_source_only","any_multisite_source") %in% names(z))) z$multisite_vs_ordinary <- z$any_multisite_source-z$ordinary_source_only
        z$infection_draw <- dd; z$lag_quarters <- lag; z$model <- mm; nd <- nd+1L; draw_list[[nd]] <- z
      }
    }
  }
  if(dd%%25L==0L || dd==max(DRAW_IDS)) cat("Processed infection draw",dd,"/",max(DRAW_IDS),"\n")
}

draws <- bind_rows(draw_list); diag <- bind_rows(diag_list)
if(!nrow(draws)) stop("No current-shedding hazard models fitted successfully.")

# =============================================================================
# 6. SUMMARIES
# =============================================================================

cat("\n============================================================\nFIT AUDIT\n============================================================\n")
fit_audit <- diag %>% group_by(lag_quarters,model) %>% summarise(draws=n(),fitted=sum(fit_ok),failed=sum(!fit_ok),draws_with_warnings=sum(nchar(warnings)>0),median_risk=median(n_risk),median_events=median(n_events),median_badgers=median(n_badgers),median_groups=median(n_groups),median_multisite_exposed=median(n_multisite_exposed),median_ordinary_exposed=median(n_ordinary_exposed),median_events_multisite=median(events_multisite),median_events_ordinary=median(events_ordinary),median_background_n=median(median_background_n),.groups="drop")
print(fit_audit,n=Inf,width=Inf)
if(any(!diag$fit_ok)){cat("\nFailures:\n"); print(diag %>% filter(!fit_ok) %>% count(lag_quarters,model,message,sort=TRUE),n=100,width=Inf)}
if(any(nchar(diag$warnings)>0)){cat("\nWarnings:\n"); print(diag %>% filter(nchar(warnings)>0) %>% count(lag_quarters,model,warnings,sort=TRUE),n=100,width=Inf)}

summarise_parameter <- function(df,param,label){
  if(!param %in% names(df)) return(NULL); x <- as.numeric(df[[param]]); x <- x[is.finite(x)]; if(!length(x)) return(NULL)
  tibble(lag_quarters=unique(df$lag_quarters),model=unique(df$model),parameter=label,n_draws=length(x),mean=mean(x),sd=sd(x),median=median(x),q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))
}

specs <- list(c("background_pressure10","beta_background_pressure_per_10pp"),c("any_multisite_source","beta_current_multisite_positive"),c("ordinary_source_only","beta_current_single_site_positive_only"),c("multisite_vs_ordinary","beta_multisite_vs_single_site"),c("sex_male","beta_recipient_male"))
summary_rows <- list(); ns <- 0L
for(lag in sort(unique(draws$lag_quarters))){for(mm in unique(draws$model)){z <- draws %>% filter(lag_quarters==lag,model==mm); if(!nrow(z)) next; for(sp in specs){rr <- summarise_parameter(z,sp[1],sp[2]); if(!is.null(rr)){ns <- ns+1L; summary_rows[[ns]] <- rr}}}}
param_summary <- bind_rows(summary_rows) %>% arrange(lag_quarters,model,parameter)

cat("\n============================================================\nPOOLED CURRENT-SHEDDING SUMMARY\n============================================================\n"); print(param_summary,n=Inf,width=Inf)
cat("\n============================================================\nCURRENT MULTI-SITE TIMING SUMMARY\n============================================================\n")
multisite_timing <- param_summary %>% filter(model=="S_MULTISITE",parameter=="beta_current_multisite_positive") %>% select(lag_quarters,n_draws,median,q025,q975,P_gt_0,OR_median,OR_q025,OR_q975)
print(multisite_timing,n=Inf,width=Inf)
cat("\n============================================================\nCURRENT MULTI-SITE vs SINGLE-SITE CONTRAST\n============================================================\n")
class_contrast <- param_summary %>% filter(model=="C_SHEDDING_CLASS",parameter %in% c("beta_current_single_site_positive_only","beta_current_multisite_positive","beta_multisite_vs_single_site"))
print(class_contrast,n=Inf,width=Inf)

cat("\nINTERPRETATION GUIDE\n")
cat("- This sensitivity uses current culture shedding at the source capture, not carried-forward source state.\n")
cat("- Current multi-site means >=2 distinct culture sample/body sites positive at that capture.\n")
cat("- A source must be observed live in the exact recipient social group and quarter.\n")
cat("- Background pressure excludes the observed current culture-positive source animals.\n")
cat("- Results remain observational and do not directly attribute a recipient infection to a specific source.\n")

# =============================================================================
# 7. SAVE
# =============================================================================

dir.create("results",showWarnings=FALSE,recursive=TRUE)
out_rds <- paste0("results/V7c_current_shedding_hazard_",RESULT_TAG,".rds")
out_summary <- paste0("results/V7c_current_shedding_hazard_",RESULT_TAG,"_summary.csv")
out_timing <- paste0("results/V7c_current_shedding_hazard_",RESULT_TAG,"_multisite_timing.csv")
out_fit <- paste0("results/V7c_current_shedding_hazard_",RESULT_TAG,"_fit_audit.csv")

saveRDS(list(model="V7c current culture-shedding sensitivity",coefficient_draws=draws,parameter_summary=param_summary,multisite_timing=multisite_timing,class_contrast=class_contrast,fit_audit=fit_audit,fit_diagnostics=diag,source_support_year=source_support_year,recipient_support_year=context_support_year,settings=list(infection_draws=length(DRAW_IDS),draws_per_history=N_KEEP,lags_quarters=LAGS,end_year=END_YEAR,source="current culture-positive capture occasion; >=2 positive sites defines current multi-site shedding",exposure="exact live co-membership in same recorded social group and quarter",outcome="sampled first infection acquisition exactly L quarters later among animals still at risk",censoring="truncate at last observed live quarter",covariance="two-way cluster robust by recipient badger and social group")),out_rds)
write_csv(param_summary,out_summary); write_csv(multisite_timing,out_timing); write_csv(fit_audit,out_fit)
cat("\nSaved:",out_rds,"\nSaved:",out_summary,"\nSaved:",out_timing,"\nSaved:",out_fit,"\n")
