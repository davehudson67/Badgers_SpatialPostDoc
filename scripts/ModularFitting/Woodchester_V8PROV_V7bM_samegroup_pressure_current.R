# =============================================================================
# WOODCHESTER V8PROV V7b-M — CURRENT SAME-GROUP INFECTION-PRESSURE DEVELOPMENT
#
# DEVELOPMENT ONLY. Uses the current V8 provisional movement histories while
# the final V9 movement model is being resolved.
#
# Scientific question:
#   Does high mobility predict subsequent infection differently depending on
#   infection pressure in the focal badger's observed social group?
#
# Timing:
#   movement state = annual interval ending in year t
#   pressure       = infection prevalence among OTHER observed badgers in the
#                    same social group at Q4(t)
#   outcome        = infection acquisition in Q1-Q4(t+1), conditional on being
#                    susceptible at Q4(t)
#
# Model ladder (same architecture as the established V5 pressure sensitivity):
#   M0_FULL        movement + sex + quarter + 5-year period, all eligible rows
#   M0_CC          same model, pressure-supported rows only
#   M1_RAW         M0_CC + raw same-group infection prevalence
#   M1_SMOOTH      M0_CC + Jeffreys-smoothed same-group prevalence
#   M2_INTERACTION M1_RAW + movement x raw pressure
#
# Pressure is scaled so one coefficient unit = +10 percentage-points prevalence.
# Source animals are all badgers with a canonical infection history AND an exact
# observed annual social-group assignment in year t. The focal badger is excluded.
# No spatial-coordinate files and no legacy 1,285-animal pressure objects are used.
# =============================================================================

library(tidyverse)

MOVE_FILE <- "data/badger_movement_posterior_histories_1932_V8_PROVISIONAL.rds"
PAIR_FILE <- "data/badger_phase2_paired_latent_inputs_V8_PROVISIONAL.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
ANNUAL_FILE <- "results/badger_annual_observed_sett_locations.csv"
for(f in c(MOVE_FILE,PAIR_FILE,INF_FILE,ANNUAL_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

mov <- readRDS(MOVE_FILE)
paired <- readRDS(PAIR_FILE)
inf <- readRDS(INF_FILE)
annual <- read_csv(ANNUAL_FILE,show_col_types=FALSE)

MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","100"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","50"))
MIN_GROUP_N <- as.integer(Sys.getenv("MIN_GROUP_N","1"))
SEED <- as.integer(Sys.getenv("SEED","7092063"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","SMOKE_100")
set.seed(SEED)

if(!is.matrix(inf$infection_time)) stop("inf$infection_time must be a matrix.")
if(is.null(paired$live_bounds) || !all(c("tattoo","last_live_time") %in% names(paired$live_bounds))) stop("paired object lacks live_bounds.")
if(!all(c("tattoo","year","annual_socg") %in% names(annual))) stop("Annual location file lacks tattoo/year/annual_socg.")
START_YEAR <- as.integer(inf$start_year)
INF_IDS <- trimws(as.character(inf$tattoo))
if(anyDuplicated(INF_IDS)) stop("Duplicate tattoos in infection trajectories.")

# =============================================================================
# A. CURRENT V8 V7b INTERVAL TABLE
# =============================================================================
idx <- as_tibble(mov$interval_index) %>%
  mutate(interval_col=row_number(),model_i=as.integer(model_i),tattoo=trimws(as.character(tattoo)),
         from_year=as.integer(from_year),to_year=as.integer(to_year))
if(ncol(mov$state_draws)!=nrow(idx)) stop("Movement state matrix does not match interval index.")
if(any(!mov$state_draws %in% c(0L,1L))) stop("Movement states must be coded 0/1.")
if(any(!as.integer(mov$sex) %in% c(0L,1L))) stop("Sex must be coded 0/1.")

pidx <- idx %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last) %>%
  transmute(interval_col,model_i,tattoo,from_year,to_year,pressure_year=to_year,
            focal_inf_row=match(tattoo,INF_IDS))
if(anyNA(pidx$focal_inf_row)) stop("Some V8 movement badgers are absent from infection trajectories.")

# =============================================================================
# B. OBSERVED ANNUAL SOCIAL GROUPS AND PRESSURE SOURCE SET
# =============================================================================
annual_sg <- annual %>%
  transmute(tattoo=trimws(as.character(tattoo)),year=as.integer(year),
            annual_socg=trimws(as.character(annual_socg))) %>%
  mutate(annual_socg=if_else(is.na(annual_socg) | annual_socg=="" | toupper(annual_socg)=="NA",NA_character_,annual_socg)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(year))
dup <- annual_sg %>% count(tattoo,year) %>% filter(n>1L)
if(nrow(dup)) stop("Annual SG table is not unique by tattoo+year; duplicated rows: ",nrow(dup))

pidx <- pidx %>%
  left_join(annual_sg,by=c("tattoo","pressure_year"="year")) %>%
  mutate(has_socg=!is.na(annual_socg),sg_key=if_else(has_socg,paste(pressure_year,annual_socg,sep="|"),NA_character_),
         q4_time=4L*(pressure_year-START_YEAR)+4L)

src <- annual_sg %>%
  mutate(inf_row=match(tattoo,INF_IDS)) %>%
  filter(!is.na(annual_socg),!is.na(inf_row),year %in% unique(pidx$pressure_year)) %>%
  mutate(sg_key=paste(year,annual_socg,sep="|")) %>%
  select(sg_key,tattoo,inf_row)
src_by_key <- split(src,src$sg_key)

cat("\n============================================================\n")
cat("V8PROV CURRENT SAME-GROUP PRESSURE DEVELOPMENT\n")
cat("============================================================\n")
cat("Candidate V7b movement intervals:",nrow(pidx),"\n")
cat("Focal badgers:",n_distinct(pidx$tattoo),"\n")
cat("Intervals with observed annual social group:",sum(pidx$has_socg),"/",nrow(pidx),
    sprintf("(%.1f%%)",100*mean(pidx$has_socg)),"\n")
cat("Annual source badger-years with infection histories + SG:",nrow(src),"\n")
cat("Distinct source badgers:",n_distinct(src$tattoo),"\n")

# Pressure is deterministic conditional on one sampled infection history, so
# cache it by infection draw when a draw is reused by multiple paired histories.
pressure_cache <- new.env(parent=emptyenv())
get_pressure <- function(inf_col){
  key_cache <- as.character(inf_col)
  if(exists(key_cache,envir=pressure_cache,inherits=FALSE)) return(get(key_cache,envir=pressure_cache,inherits=FALSE))
  it <- as.integer(inf$infection_time[,inf_col])
  raw <- rep(NA_real_,nrow(pidx)); smooth <- rep(NA_real_,nrow(pidx)); n_other <- integer(nrow(pidx))
  keys <- unique(na.omit(pidx$sg_key))
  for(kk in keys){
    rr <- which(!is.na(pidx$sg_key) & pidx$sg_key==kk)
    ss <- src_by_key[[kk]]
    if(is.null(ss) || !nrow(ss)) next
    for(j in rr){
      keep <- ss$tattoo!=pidx$tattoo[j]
      rows <- ss$inf_row[keep]
      n <- length(rows); n_other[j] <- n
      if(n>0L){
        ninfected <- sum(it[rows]>0L & it[rows]<=pidx$q4_time[j])
        raw[j] <- ninfected/n
        smooth[j] <- (ninfected+.5)/(n+1)
      }
    }
  }
  ans <- list(raw=raw,smooth=smooth,n=n_other)
  assign(key_cache,ans,envir=pressure_cache)
  ans
}

# =============================================================================
# C. PAIRED POSTERIOR HISTORIES
# =============================================================================
pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<1L) stop("MAX_PAIRS must be >=1.")
if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS) pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}
last_live <- setNames(as.integer(paired$live_bounds$last_live_time),trimws(as.character(paired$live_bounds$tattoo)))

QUARTER_LEVELS <- 1:4
OUTCOME_YEARS <- sort(unique(pidx$pressure_year+1L))
PERIOD_LEVELS <- sort(unique(5L*(OUTCOME_YEARS%/%5L)))

make_risk_data <- function(move_draw,inf_col,require_pressure=FALSE){
  st <- as.integer(mov$state_draws[move_draw,pidx$interval_col])
  it_focal <- as.integer(inf$infection_time[pidx$focal_inf_row,inf_col])
  pr <- get_pressure(inf_col)
  susceptible <- it_focal==0L | it_focal>pidx$q4_time
  start_q <- 4L*((pidx$pressure_year+1L)-START_YEAR)+1L
  end_q <- start_q+3L
  llt <- as.integer(last_live[pidx$tattoo])
  keep_interval <- susceptible & !is.na(llt) & start_q<=llt
  if(require_pressure){
    support <- pidx$has_socg & pr$n>=MIN_GROUP_N & is.finite(pr$raw) & is.finite(pr$smooth)
    keep_interval <- keep_interval & support
  }
  rr <- which(keep_interval)
  out <- vector("list",length(rr)*4L); oo <- 0L
  for(j in rr){
    last_q <- min(end_q[j],llt[j])
    for(qtime in seq.int(start_q[j],last_q)){
      if(it_focal[j]>0L && it_focal[j]<qtime) break
      q <- ((qtime-1L)%%4L)+1L
      yr <- START_YEAR+((qtime-1L)%/%4L)
      ev <- as.integer(it_focal[j]>0L && it_focal[j]==qtime)
      oo <- oo+1L
      out[[oo]] <- tibble(tattoo=pidx$tattoo[j],sex=as.integer(mov$sex[pidx$model_i[j]]),movement_state=st[j],
                          pressure=pr$raw[j],pressure_smooth=pr$smooth[j],group_n=pr$n[j],
                          outcome_quarter=q,outcome_year=yr,period_start=5L*(yr%/%5L),infection_event=ev)
      if(ev==1L) break
    }
  }
  if(!oo) return(tibble())
  bind_rows(out[seq_len(oo)])
}

# =============================================================================
# D. ESTIMATION ENGINE — ESTABLISHED V5 CLUSTER-ROBUST LOGISTIC FRAMEWORK
# =============================================================================
rmvn_psd <- function(n,mu,Sigma){
  mu <- as.numeric(mu); Sigma <- as.matrix(Sigma); Sigma <- (Sigma+t(Sigma))/2
  if(!length(mu) || any(!is.finite(mu)) || any(!is.finite(Sigma))) stop("Invalid MVN inputs.")
  ee <- eigen(Sigma,symmetric=TRUE); ee$values[ee$values<1e-10] <- 1e-10
  A <- ee$vectors %*% diag(sqrt(ee$values),nrow=length(ee$values))
  sweep(matrix(rnorm(n*length(mu)),nrow=n) %*% t(A),2,mu,"+")
}
inv_psd <- function(M){
  M <- (M+t(M))/2; ee <- eigen(M,symmetric=TRUE); tol <- max(1e-12,max(abs(ee$values))*1e-10)
  keep <- ee$values>tol; if(!any(keep)) stop("Information matrix has no positive eigenvalues.")
  V <- ee$vectors[,keep,drop=FALSE]
  V %*% diag(1/ee$values[keep],nrow=sum(keep)) %*% t(V)
}

build_X <- function(d,model){
  cols <- list("(Intercept)"=rep(1,nrow(d)),movement_state=as.numeric(d$movement_state))
  if(model %in% c("M1_RAW","M2_INTERACTION")) cols$pressure10 <- 10*as.numeric(d$pressure)
  if(model=="M1_SMOOTH") cols$pressure_smooth10 <- 10*as.numeric(d$pressure_smooth)
  if(model=="M2_INTERACTION") cols$`movement_state:pressure10` <- as.numeric(d$movement_state)*(10*as.numeric(d$pressure))
  cols$sex <- as.numeric(d$sex)
  for(q in QUARTER_LEVELS[-1L]) cols[[paste0("quarter",q)]] <- as.numeric(d$outcome_quarter==q)
  for(p in PERIOD_LEVELS[-1L]) cols[[paste0("period",p)]] <- as.numeric(d$period_start==p)
  X <- do.call(cbind,cols); storage.mode(X) <- "double"; X
}

fit_one <- function(model,d,nkeep){
  warns <- character(0); y <- as.numeric(d$infection_event); cluster <- trimws(as.character(d$tattoo)); X <- build_X(d,model)
  finite_by_col <- colSums(!is.finite(X)); bad_y <- sum(!is.finite(y)); bad_cluster <- sum(is.na(cluster) | !nzchar(cluster))
  if(any(finite_by_col>0) || bad_y>0 || bad_cluster>0){
    bad_cols <- paste(names(finite_by_col)[finite_by_col>0],finite_by_col[finite_by_col>0],sep="=",collapse=", ")
    return(list(ok=FALSE,draws=NULL,converged=FALSE,warning="",message=paste0("non-finite inputs; X[",bad_cols,"]; y=",bad_y,"; cluster=",bad_cluster)))
  }
  fit <- tryCatch(withCallingHandlers(
    stats::glm.fit(x=X,y=y,family=stats::binomial(link="logit"),control=stats::glm.control(maxit=100,epsilon=1e-8),intercept=TRUE),
    warning=function(w){warns <<- c(warns,conditionMessage(w)); invokeRestart("muffleWarning")}),error=function(e)e)
  if(inherits(fit,"error")) return(list(ok=FALSE,draws=NULL,converged=FALSE,warning=paste(unique(warns),collapse=" | "),message=conditionMessage(fit)))
  if(!isTRUE(fit$converged)) return(list(ok=FALSE,draws=NULL,converged=FALSE,warning=paste(unique(warns),collapse=" | "),message="glm.fit did not converge"))
  cf_all <- fit$coefficients; active <- which(is.finite(cf_all))
  if(!length(active)) return(list(ok=FALSE,draws=NULL,converged=TRUE,warning=paste(unique(warns),collapse=" | "),message="no estimable coefficients"))
  Xa <- X[,active,drop=FALSE]; cf <- cf_all[active]; names(cf) <- colnames(X)[active]; mu <- as.numeric(fit$fitted.values)
  rob <- tryCatch({
    w <- pmax(mu*(1-mu),1e-12); bread <- inv_psd(crossprod(Xa,Xa*w)); score_rows <- Xa*as.numeric(y-mu)
    U <- rowsum(score_rows,group=cluster,reorder=FALSE); meat <- crossprod(U); G <- nrow(U); N <- nrow(Xa); K <- ncol(Xa)
    correction <- if(G>1L && N>K) (G/(G-1))*((N-1)/(N-K)) else 1
    V <- bread %*% (correction*meat) %*% bread; V <- (V+t(V))/2; rownames(V) <- colnames(V) <- names(cf)
    list(beta=cf,V=V)
  },error=function(e)e)
  if(inherits(rob,"error") || any(!is.finite(rob$V))) return(list(ok=FALSE,draws=NULL,converged=TRUE,warning=paste(unique(warns),collapse=" | "),message="robust covariance failed"))
  dr <- tryCatch(rmvn_psd(nkeep,rob$beta,rob$V),error=function(e)e)
  if(inherits(dr,"error")) return(list(ok=FALSE,draws=NULL,converged=TRUE,warning=paste(unique(warns),collapse=" | "),message=paste("MVN draw failed:",conditionMessage(dr))))
  colnames(dr) <- names(rob$beta)
  list(ok=TRUE,draws=as_tibble(dr),converged=TRUE,warning=paste(unique(warns),collapse=" | "),message="")
}

# =============================================================================
# E. FIT MODEL LADDER ACROSS PAIRED HISTORIES
# =============================================================================
draw_list <- list(); diag_list <- list(); retention_list <- list(); nd <- 0L; ng <- 0L
for(pp in seq_len(nrow(pair_index))){
  move_draw <- pair_index$movement_draw[pp]; inf_col <- pair_index$infection_col[pp]
  d_full <- make_risk_data(move_draw,inf_col,FALSE); d_cc <- make_risk_data(move_draw,inf_col,TRUE)
  if(!nrow(d_full)) stop("Empty full risk data at pair ",pair_index$pair_draw[pp])
  if(!nrow(d_cc)) stop("Empty pressure-supported risk data at pair ",pair_index$pair_draw[pp])
  retention_list[[pp]] <- tibble(pair_draw=pair_index$pair_draw[pp],full_rows=nrow(d_full),cc_rows=nrow(d_cc),
                                 full_events=sum(d_full$infection_event),cc_events=sum(d_cc$infection_event),
                                 full_badgers=n_distinct(d_full$tattoo),cc_badgers=n_distinct(d_cc$tattoo),
                                 full_high_rows=sum(d_full$movement_state==1L),cc_high_rows=sum(d_cc$movement_state==1L),
                                 median_group_n=median(d_cc$group_n))
  if(pp==1L){
    cat("\nFIRST-PAIR AUDIT\n")
    print(retention_list[[pp]],width=Inf)
    cat("Raw pressure summary:\n"); print(summary(d_cc$pressure))
    cat("Smoothed pressure summary:\n"); print(summary(d_cc$pressure_smooth))
  }
  datasets <- list(M0_FULL=d_full,M0_CC=d_cc,M1_RAW=d_cc,M1_SMOOTH=d_cc,M2_INTERACTION=d_cc)
  fits <- lapply(names(datasets),function(nm) fit_one(nm,datasets[[nm]],N_KEEP)); names(fits) <- names(datasets)
  for(nm in names(fits)){
    z <- fits[[nm]]; dd <- datasets[[nm]]; ng <- ng+1L
    diag_list[[ng]] <- tibble(pair_draw=pair_index$pair_draw[pp],movement_draw=move_draw,infection_col=inf_col,model=nm,
                              n_rows=nrow(dd),n_events=sum(dd$infection_event),n_badgers=n_distinct(dd$tattoo),
                              n_high_rows=sum(dd$movement_state==1L),fit_ok=z$ok,converged=z$converged,warnings=z$warning,message=z$message)
    if(z$ok){
      dr <- z$draws; dr$pair_draw <- pair_index$pair_draw[pp]; dr$model <- nm; nd <- nd+1L; draw_list[[nd]] <- dr
    }
  }
  if(pp%%10L==0L) cat("Processed paired history",pp,"/",nrow(pair_index),"\n")
}

draws <- bind_rows(draw_list); diag <- bind_rows(diag_list); retention <- bind_rows(retention_list)
if(!nrow(draws)) stop("No models fitted successfully.")

fit_audit <- diag %>% group_by(model) %>% summarise(pairs=n(),fit_ok=sum(fit_ok),failed=sum(!fit_ok),
  median_rows=median(n_rows),median_events=median(n_events),median_badgers=median(n_badgers),median_high_rows=median(n_high_rows),.groups="drop")
retention_summary <- retention %>% summarise(pairs=n(),median_full_rows=median(full_rows),median_cc_rows=median(cc_rows),
  median_rows_retained_pct=median(100*cc_rows/full_rows),median_full_events=median(full_events),median_cc_events=median(cc_events),
  median_events_retained_pct=median(100*cc_events/full_events),median_group_n=median(median_group_n))

summarise_parameter_safe <- function(df,param,label){
  if(!param %in% names(df)) return(NULL)
  x <- as.numeric(df[[param]]); x <- x[is.finite(x)]; if(!length(x)) return(NULL)
  tibble(model=unique(df$model),parameter=label,n_draws=length(x),mean=mean(x),sd=sd(x),median=median(x),
         q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),
         OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))
}
summary_rows <- list(); ns <- 0L
for(nm in unique(draws$model)){
  z <- draws %>% filter(model==nm)
  specs <- list(c("movement_state","beta_move"),c("pressure10","beta_pressure_per_10pp"),
                c("pressure_smooth10","beta_smoothed_pressure_per_10pp"),
                c("movement_state:pressure10","beta_move_x_pressure_per_10pp"),c("sex","beta_sex"))
  for(sp in specs){rr <- summarise_parameter_safe(z,sp[1],sp[2]); if(!is.null(rr)){ns <- ns+1L; summary_rows[[ns]] <- rr}}
}
param_summary <- bind_rows(summary_rows)

interaction_derived <- tibble()
if("M2_INTERACTION" %in% draws$model){
  z <- draws %>% filter(model=="M2_INTERACTION")
  keep <- is.finite(z$movement_state) & is.finite(z$`movement_state:pressure10`)
  if(any(keep)){
    bM <- z$movement_state[keep]; bI <- z$`movement_state:pressure10`[keep]
    interaction_derived <- bind_rows(lapply(c(0,.10,.25,.50),function(p){
      lp <- bM+bI*(10*p)
      tibble(pressure_prevalence=p,n_draws=length(lp),OR_move_median=median(exp(lp)),
             OR_move_q025=unname(quantile(exp(lp),.025)),OR_move_q975=unname(quantile(exp(lp),.975)),P_move_positive=mean(lp>0))
    }))
  }
}

cat("\n============================================================\n")
cat("FIT AUDIT\n")
cat("============================================================\n"); print(fit_audit,n=Inf,width=Inf)
cat("\nPRESSURE-SUPPORT RETENTION\n"); print(retention_summary,width=Inf)
cat("\nPOOLED COEFFICIENT SUMMARY\n"); print(param_summary,n=Inf,width=Inf)
cat("\nMOVEMENT EFFECT UNDER M2 AT SELECTED PRESSURES\n"); print(interaction_derived,n=Inf,width=Inf)
cat("\nInterpretation reminder: this is V8 provisional development only. Final inference must be rebuilt from accepted V9 movement histories.\n")

# =============================================================================
# F. SAVE
# =============================================================================
dir.create("results",showWarnings=FALSE,recursive=TRUE)
prefix <- paste0("results/V8PROV_V7bM_samegroup_pressure_CURRENT_",RESULT_TAG,"_minN",MIN_GROUP_N)
saveRDS(list(model="V8PROV current same-group pressure development sensitivity",coefficient_draws=draws,
             parameter_summary=param_summary,interaction_derived=interaction_derived,fit_audit=fit_audit,
             fit_diagnostics=diag,retention_by_pair=retention,retention_summary=retention_summary,pair_index=pair_index,
             definition=list(pressure_time="Q4(t)",outcome_time="Q1-Q4(t+1)",source_population="other badgers with canonical infection history and exact observed annual social group in year t",
                             self_excluded=TRUE,raw_pressure="infected other badgers / all other source badgers in same group-year",
                             smooth_pressure="Jeffreys: (infected+0.5)/(n+1)",pressure_scale="10 percentage points"),
             settings=list(n_pairs=nrow(pair_index),draws_per_history=N_KEEP,min_group_n=MIN_GROUP_N,seed=SEED,
                           covariance="badger-cluster robust",development_only=TRUE)),paste0(prefix,".rds"))
write_csv(param_summary,paste0(prefix,"_summary.csv"))
write_csv(interaction_derived,paste0(prefix,"_interaction.csv"))
write_csv(fit_audit,paste0(prefix,"_fit_audit.csv"))
write_csv(retention,paste0(prefix,"_retention_by_pair.csv"))
cat("\nSaved:\n",prefix,".rds\n",prefix,"_summary.csv\n",prefix,"_interaction.csv\n",prefix,"_fit_audit.csv\n",prefix,"_retention_by_pair.csv\n",sep="")
