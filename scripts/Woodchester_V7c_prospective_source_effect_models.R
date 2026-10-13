# =============================================================================
# WOODCHESTER V7c — PROSPECTIVE SOURCE-EFFECT MODELS
#
# PURPOSE
# -------
# Test whether observed infectious-source group-years predict infection
# acquisition among OTHER susceptible badgers in the following year.
#
# Unit of analysis: annual social-group x year.
# Exposure year: t.
# Susceptibility: sampled latent infection state negative at Q4(t).
# Outcome: sampled infection acquisition during Q1-Q4(t+1).
#
# PRIMARY SCIENTIFIC CONTRASTS
# ----------------------------
# G0_BACKGROUND : background latent infection pressure + decade
# G1_SOURCE     : G0 + any observed Excretor/Super-excretor source
# G2_SUPER      : G0 + any observed Super excretor source
# G3_ARRIVAL    : G0 + any exact observed infectious social-group arrival
#
# Super-excretor ARRIVAL is not fitted separately: the support audit found only
# one exposed group-year. G3 combines Excretor + Super excretor arrivals and is
# explicitly exploratory because there are only 11 exposed group-years.
#
# BACKGROUND PRESSURE
# -------------------
# For each group-year and infection trajectory, background pressure is the Q4(t)
# latent infection prevalence among observed group members after EXCLUDING all
# strict observed Excretor/Super-excretor source animals in that group-year.
# This avoids simply re-encoding the observed source exposure inside the local
# prevalence covariate. Pressure is scaled per +10 percentage points.
#
# INFERENCE
# ---------
# Each of the sampled infection trajectories is analysed separately. Models are
# grouped-binomial logistic regressions. Sandwich covariance is clustered by
# social group because exposure is shared within group-year and social groups
# recur through time. Coefficient uncertainty is propagated with MVN draws.
#
# This is an observed-source mechanistic sensitivity, not a causal transmission
# model. Absence of an observed strict source is not proof that no infectious
# badger was present.
# =============================================================================

library(tidyverse)

RECIP_FILE <- "data/badger_V7c_recipient_exposure_support_audit.rds"
AUDIT_FILE <- "data/badger_V7c_infected_mover_spreader_audit.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
ANNUAL_FILE <- "data/badger_annual_observed_sett_locations.rds"

for(f in c(RECIP_FILE,AUDIT_FILE,INF_FILE,ANNUAL_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

rec_audit <- readRDS(RECIP_FILE)
v7c <- readRDS(AUDIT_FILE)
inf <- readRDS(INF_FILE)
annual <- as_tibble(readRDS(ANNUAL_FILE))

MAX_DRAWS <- as.integer(Sys.getenv("MAX_DRAWS","500"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","100"))
SEED <- as.integer(Sys.getenv("SEED","7092044"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","FULL_500")
set.seed(SEED)

START_YEAR <- as.integer(inf$start_year)
INF_IDS <- str_to_upper(str_squish(as.character(inf$tattoo)))
N_INF_DRAW <- ncol(inf$infection_time)
DRAW_IDS <- seq_len(min(MAX_DRAWS,N_INF_DRAW))

if(!all(c("group_years","recipients") %in% names(rec_audit))) stop("Recipient audit RDS lacks group_years/recipients.")
if(!"candidate_sources" %in% names(v7c)) stop("V7c source audit RDS lacks candidate_sources.")

# =============================================================================
# 1. FIXED OBSERVED GROUP-YEAR EXPOSURES
# =============================================================================

gy <- as_tibble(rec_audit$group_years) %>%
  transmute(
    year=as.integer(year),
    destination_socg=as.character(destination_socg),
    any_infectious_source=as.logical(any_infectious_source),
    any_super_source=as.logical(any_super_source),
    any_infectious_arrival=as.logical(any_infectious_arrival),
    any_super_arrival=as.logical(any_super_arrival)
  ) %>%
  distinct(year,destination_socg,.keep_all=TRUE)

recipients <- as_tibble(rec_audit$recipients) %>%
  transmute(tattoo=str_to_upper(str_squish(as.character(tattoo))),
            year=as.integer(year),destination_socg=as.character(destination_socg),
            inf_row=as.integer(inf_row)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(year),!is.na(destination_socg),destination_socg!="",!is.na(inf_row))

strict_sources <- as_tibble(v7c$candidate_sources) %>%
  filter(status_group_confirmed %in% TRUE) %>%
  transmute(source_tattoo=str_to_upper(str_squish(as.character(tattoo))),
            year=as.integer(year),destination_socg=as.character(destination_socg)) %>%
  distinct(source_tattoo,year,destination_socg)

source_ids_by_gy <- strict_sources %>%
  group_by(year,destination_socg) %>%
  summarise(source_ids=list(unique(source_tattoo)),.groups="drop")

annual2 <- annual %>%
  transmute(tattoo=str_to_upper(str_squish(as.character(tattoo))),
            year=as.integer(year),destination_socg=as.character(annual_socg),
            inf_row=match(str_to_upper(str_squish(as.character(tattoo))),INF_IDS)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(year),!is.na(destination_socg),destination_socg!="",!is.na(inf_row)) %>%
  distinct(tattoo,year,destination_socg,.keep_all=TRUE)

# Background source membership excludes every strict observed infectious source
# in that group-year. These rows are reused across infection-history draws.
bg_members <- annual2 %>%
  left_join(source_ids_by_gy,by=c("year","destination_socg")) %>%
  rowwise() %>%
  mutate(is_strict_source=if(is.null(source_ids) || length(source_ids)==0L) FALSE else tattoo %in% source_ids) %>%
  ungroup() %>%
  filter(!is_strict_source) %>%
  select(tattoo,year,destination_socg,inf_row)

# Recipient risk rows define which group-years have prospective follow-up.
gy_follow <- recipients %>% distinct(year,destination_socg) %>% inner_join(gy,by=c("year","destination_socg"))

# =============================================================================
# 2. HELPERS
# =============================================================================

inv_psd <- function(M){
  M <- (M+t(M))/2
  ee <- eigen(M,symmetric=TRUE)
  tol <- max(1e-12,max(abs(ee$values))*1e-10)
  keep <- ee$values>tol
  if(!any(keep)) stop("Information matrix has no positive eigenvalues.")
  V <- ee$vectors[,keep,drop=FALSE]
  V %*% diag(1/ee$values[keep],nrow=sum(keep)) %*% t(V)
}

rmvn_psd <- function(n,mu,Sigma){
  mu <- as.numeric(mu)
  Sigma <- as.matrix(Sigma); Sigma <- (Sigma+t(Sigma))/2
  if(!length(mu) || any(!is.finite(mu)) || any(!is.finite(Sigma))) stop("Invalid MVN inputs.")
  ee <- eigen(Sigma,symmetric=TRUE)
  ee$values[ee$values<1e-10] <- 1e-10
  A <- ee$vectors %*% diag(sqrt(ee$values),nrow=length(ee$values))
  Z <- matrix(rnorm(n*length(mu)),nrow=n)
  sweep(Z %*% t(A),2,mu,"+")
}

DECADES <- sort(unique(10L*(gy_follow$year%/%10L)))

build_X <- function(d,model){
  cols <- list("(Intercept)"=rep(1,nrow(d)),background_pressure10=10*as.numeric(d$background_pressure))
  if(model=="G1_SOURCE") cols$any_infectious_source <- as.numeric(d$any_infectious_source)
  if(model=="G2_SUPER") cols$any_super_source <- as.numeric(d$any_super_source)
  if(model=="G3_ARRIVAL") cols$any_infectious_arrival <- as.numeric(d$any_infectious_arrival)
  for(p in DECADES[-1L]) cols[[paste0("decade",p)]] <- as.numeric(d$decade==p)
  X <- do.call(cbind,cols); storage.mode(X) <- "double"; X
}

fit_group_binomial <- function(model,d,nkeep){
  X <- build_X(d,model)
  y <- as.numeric(d$n_events/d$n_risk)
  wt <- as.numeric(d$n_risk)
  cluster <- as.character(d$destination_socg)

  finite_by_col <- colSums(!is.finite(X))
  if(any(finite_by_col>0) || any(!is.finite(y)) || any(!is.finite(wt)) || any(wt<=0) || any(is.na(cluster)|!nzchar(cluster))){
    bad_cols <- paste(names(finite_by_col)[finite_by_col>0],finite_by_col[finite_by_col>0],sep="=",collapse=", ")
    return(list(ok=FALSE,draws=NULL,message=paste0("invalid model inputs; X[",bad_cols,"]"),warning=""))
  }

  warns <- character(0)
  fit <- tryCatch(withCallingHandlers(
    stats::glm.fit(x=X,y=y,weights=wt,family=stats::binomial(link="logit"),
                   control=stats::glm.control(maxit=100,epsilon=1e-8),intercept=TRUE),
    warning=function(w){warns <<- c(warns,conditionMessage(w)); invokeRestart("muffleWarning")}),
    error=function(e)e)
  if(inherits(fit,"error")) return(list(ok=FALSE,draws=NULL,message=conditionMessage(fit),warning=paste(unique(warns),collapse=" | ")))
  if(!isTRUE(fit$converged)) return(list(ok=FALSE,draws=NULL,message="glm.fit did not converge",warning=paste(unique(warns),collapse=" | ")))

  cf_all <- fit$coefficients
  active <- which(is.finite(cf_all))
  if(!length(active)) return(list(ok=FALSE,draws=NULL,message="no estimable coefficients",warning=paste(unique(warns),collapse=" | ")))
  Xa <- X[,active,drop=FALSE]
  cf <- cf_all[active]; names(cf) <- colnames(X)[active]
  mu <- as.numeric(fit$fitted.values)
  if(any(!is.finite(mu))) return(list(ok=FALSE,draws=NULL,message="invalid fitted probabilities",warning=paste(unique(warns),collapse=" | ")))

  rob <- tryCatch({
    w <- pmax(wt*mu*(1-mu),1e-12)
    bread <- inv_psd(crossprod(Xa,Xa*w))
    score_rows <- Xa*as.numeric(d$n_events-wt*mu)
    U <- rowsum(score_rows,group=cluster,reorder=FALSE)
    meat <- crossprod(U)
    G <- nrow(U); N <- nrow(Xa); K <- ncol(Xa)
    correction <- if(G>1L && N>K) (G/(G-1))*((N-1)/(N-K)) else 1
    V <- bread %*% (correction*meat) %*% bread
    V <- (V+t(V))/2; rownames(V) <- colnames(V) <- names(cf)
    list(beta=cf,V=V,G=G)
  },error=function(e)e)
  if(inherits(rob,"error")) return(list(ok=FALSE,draws=NULL,message=paste("robust covariance failed:",conditionMessage(rob)),warning=paste(unique(warns),collapse=" | ")))
  if(any(!is.finite(rob$V))) return(list(ok=FALSE,draws=NULL,message="non-finite robust covariance",warning=paste(unique(warns),collapse=" | ")))

  dr <- tryCatch(rmvn_psd(nkeep,rob$beta,rob$V),error=function(e)e)
  if(inherits(dr,"error")) return(list(ok=FALSE,draws=NULL,message=paste("MVN draw failed:",conditionMessage(dr)),warning=paste(unique(warns),collapse=" | ")))
  colnames(dr) <- names(rob$beta)
  list(ok=TRUE,draws=as_tibble(dr),message="",warning=paste(unique(warns),collapse=" | "))
}

# =============================================================================
# 3. LOOP ACROSS INFECTION TRAJECTORIES
# =============================================================================

cat("\n============================================================\n")
cat("V7c PROSPECTIVE SOURCE-EFFECT MODELS\n")
cat("============================================================\n")
cat("Infection-history draws:",length(DRAW_IDS),"\n")
cat("Coefficient draws/history/model:",N_KEEP,"\n")
cat("Prospective group-years:",nrow(gy_follow),"\n")
cat("Observed Super-excretor group-years:",sum(gy_follow$any_super_source),"\n")
cat("Observed infectious-arrival group-years:",sum(gy_follow$any_infectious_arrival),"\n")
cat("Covariance clustered by social group.\n\n")

draw_list <- list(); diag_list <- list(); nd <- 0L; ng <- 0L

for(dd in DRAW_IDS){
  # Recipient susceptibility and next-year acquisition.
  rr <- recipients
  tt <- as.integer(inf$infection_time[rr$inf_row,dd])
  q4 <- 4L*(rr$year-START_YEAR)+4L
  rr$sus <- tt==0L | tt>q4
  rr$event <- tt>=q4+1L & tt<=q4+4L

  risk_gy <- rr %>%
    group_by(year,destination_socg) %>%
    summarise(n_risk=sum(sus),n_events=sum(event & sus),.groups="drop") %>%
    filter(n_risk>0)

  # Background Q4 infection pressure among non-source observed group members.
  bb <- bg_members
  bt <- as.integer(inf$infection_time[bb$inf_row,dd])
  bq4 <- 4L*(bb$year-START_YEAR)+4L
  bb$infected_q4 <- bt>0L & bt<=bq4
  bg_gy <- bb %>%
    group_by(year,destination_socg) %>%
    summarise(background_n=n(),background_infected=sum(infected_q4),
              background_pressure=background_infected/background_n,.groups="drop")

  dat <- risk_gy %>%
    inner_join(gy_follow,by=c("year","destination_socg")) %>%
    left_join(bg_gy,by=c("year","destination_socg")) %>%
    filter(is.finite(background_pressure),background_n>0) %>%
    mutate(decade=10L*(year%/%10L))

  models <- c("G0_BACKGROUND","G1_SOURCE","G2_SUPER","G3_ARRIVAL")
  for(mm in models){
    fit <- fit_group_binomial(mm,dat,N_KEEP); ng <- ng+1L
    diag_list[[ng]] <- tibble(infection_draw=dd,model=mm,n_group_years=nrow(dat),n_events=sum(dat$n_events),
                              n_risk=sum(dat$n_risk),n_groups=n_distinct(dat$destination_socg),
                              exposed_group_years=case_when(mm=="G1_SOURCE"~sum(dat$any_infectious_source),
                                                          mm=="G2_SUPER"~sum(dat$any_super_source),
                                                          mm=="G3_ARRIVAL"~sum(dat$any_infectious_arrival),TRUE~NA_integer_),
                              fit_ok=fit$ok,warnings=fit$warning,message=fit$message)
    if(fit$ok){
      z <- fit$draws; z$infection_draw <- dd; z$model <- mm
      nd <- nd+1L; draw_list[[nd]] <- z
    }
  }
  if(dd%%50L==0L || dd==max(DRAW_IDS)) cat("Processed infection draw",dd,"/",max(DRAW_IDS),"\n")
}

draws <- bind_rows(draw_list)
diag <- bind_rows(diag_list)

cat("\n============================================================\nFIT AUDIT\n============================================================\n")
fit_audit <- diag %>% group_by(model) %>% summarise(draws=n(),fitted=sum(fit_ok),failed=sum(!fit_ok),
  draws_with_warnings=sum(nchar(warnings)>0),median_group_years=median(n_group_years),median_events=median(n_events),
  median_risk=median(n_risk),median_groups=median(n_groups),median_exposed_group_years=median(exposed_group_years,na.rm=TRUE),.groups="drop")
print(fit_audit,n=Inf,width=Inf)
if(any(!diag$fit_ok)){
  cat("\nFailures:\n")
  print(diag %>% filter(!fit_ok) %>% count(model,message,sort=TRUE),n=50,width=Inf)
}
if(any(nchar(diag$warnings)>0)){
  cat("\nWarnings:\n")
  print(diag %>% filter(nchar(warnings)>0) %>% count(model,warnings,sort=TRUE),n=50,width=Inf)
}

summarise_parameter <- function(df,param,label){
  if(!param %in% names(df)) return(NULL)
  x <- as.numeric(df[[param]]); x <- x[is.finite(x)]
  if(!length(x)) return(NULL)
  tibble(model=unique(df$model),parameter=label,n_draws=length(x),mean=mean(x),sd=sd(x),median=median(x),
         q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),
         OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))
}

specs <- list(
  c("background_pressure10","beta_background_pressure_per_10pp"),
  c("any_infectious_source","beta_any_infectious_source"),
  c("any_super_source","beta_any_super_source"),
  c("any_infectious_arrival","beta_any_infectious_arrival")
)

summary_rows <- list(); ns <- 0L
for(mm in unique(draws$model)){
  z <- draws %>% filter(model==mm)
  for(sp in specs){
    rr <- summarise_parameter(z,sp[1],sp[2])
    if(!is.null(rr)){ns <- ns+1L; summary_rows[[ns]] <- rr}
  }
}
param_summary <- bind_rows(summary_rows)

cat("\n============================================================\nPOOLED SOURCE-EFFECT SUMMARY\n============================================================\n")
print(param_summary,n=Inf,width=Inf)

cat("\nINTERPRETATION GUIDE\n")
cat("- G1 asks whether any observed Excretor/Super-excretor source adds risk beyond sampled background group infection pressure.\n")
cat("- G2 asks whether a Super excretor in the group adds risk beyond sampled background pressure.\n")
cat("- G3 asks whether an exact observed infectious social-group arrival adds risk; only 11 exposed group-years make this exploratory.\n")
cat("- Super-excretor arrival is not separately modelled because only one exposed group-year exists.\n")
cat("- Background pressure excludes all strict observed infectious source animals in that group-year.\n")
cat("- These are prospective observed-source associations, not proof of direct transmission from a named source animal.\n")

dir.create("results",showWarnings=FALSE,recursive=TRUE)
out_rds <- paste0("results/V7c_prospective_source_effect_",RESULT_TAG,".rds")
out_summary <- paste0("results/V7c_prospective_source_effect_",RESULT_TAG,"_summary.csv")
out_fit <- paste0("results/V7c_prospective_source_effect_",RESULT_TAG,"_fit_audit.csv")
saveRDS(list(model="V7c prospective observed-source group-year models",coefficient_draws=draws,
             parameter_summary=param_summary,fit_audit=fit_audit,fit_diagnostics=diag,
             settings=list(infection_draws=length(DRAW_IDS),draws_per_history=N_KEEP,
                           exposure_time="observed source during year t / annual destination group",
                           susceptibility_time="Q4(t)",outcome_time="Q1-Q4(t+1)",
                           background_pressure="Q4(t) latent prevalence excluding strict observed source animals",
                           covariance="social-group cluster robust",arrival_model="exploratory")),out_rds)
write_csv(param_summary,out_summary); write_csv(fit_audit,out_fit)
cat("\nSaved:",out_rds,"\nSaved:",out_summary,"\nSaved:",out_fit,"\n")
