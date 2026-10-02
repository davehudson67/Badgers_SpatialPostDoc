# =============================================================================
# WOODCHESTER V9 FINAL — GROUP MOVEMENT INDEX -> SUBSEQUENT INFECTION BRIDGE
#
# Motivation
#   Bridge the final latent high-mobility result to the published Woodchester
#   group-movement result (Vicente et al. 2007).
#
# Published-style group movement index
#   At each live capture, score 1 if social group differs from the immediately
#   previous live capture and 0 if unchanged (only when both groups are known).
#   Average scores within badger-year, exclude cub-years, then average those
#   individual annual scores among residents of each observed social group-year.
#   For focal analyses use a leave-one-out group index.
#
# Timing
#   focal latent movement state  = interval ending in year t
#   group movement index         = observed movement during year t
#   group infection pressure     = Q4(t), other observed group members
#   infection outcome            = Q1-Q4(t+1), susceptible at Q4(t)
#
# Models on identical group-movement-supported rows:
#   G0_BASE        focal high mobility + pressure + sex + quarter + 5y period
#   G1_GROUPMOVE   G0 + group movement index
#   G1_TREND_CC    G1 restricted to rows with group-size trend support
#   G2_PLUS_TREND  G1_TREND_CC + observed group-size trend
#
# Logistic GLM + badger-cluster robust covariance + MVN coefficient draws.
# Not MCMC.
# =============================================================================

library(tidyverse)
library(lubridate)

MOVE_FILE <- "data/badger_movement_posterior_histories_1932_V9_FINAL.rds"
PAIR_FILE <- "data/badger_phase2_paired_latent_inputs_V9_FINAL.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
ANNUAL_FILE <- "results/badger_annual_observed_sett_locations.csv"
ENC_FILE <- "data/badger_encounters_useful.rds"
IND_FILE <- "data/badger_individuals.rds"
for(f in c(MOVE_FILE,PAIR_FILE,INF_FILE,ANNUAL_FILE,ENC_FILE,IND_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

mov <- readRDS(MOVE_FILE)
paired <- readRDS(PAIR_FILE)
inf <- readRDS(INF_FILE)
annual <- read_csv(ANNUAL_FILE,show_col_types=FALSE)
enc <- as_tibble(readRDS(ENC_FILE))
ind <- as_tibble(readRDS(IND_FILE))

MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","100"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","50"))
MIN_PRESSURE_N <- as.integer(Sys.getenv("MIN_PRESSURE_N","3"))
MIN_GROUP_MOVE_N <- as.integer(Sys.getenv("MIN_GROUP_MOVE_N","3"))
SEED <- as.integer(Sys.getenv("SEED","7092072"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","SMOKE_100")
set.seed(SEED)

START_YEAR <- as.integer(inf$start_year)
INF_IDS <- trimws(as.character(inf$tattoo))
if(anyDuplicated(INF_IDS)) stop("Duplicate tattoos in infection trajectories.")
if(!all(c("tattoo","capture_date","has_live_capture","socg")%in%names(enc)))
  stop("Encounter file lacks tattoo/capture_date/has_live_capture/socg.")

clean_group <- function(x){
  z <- toupper(str_squish(as.character(x)))
  z[is.na(z) | z=="" | z=="NA"] <- NA_character_
  z
}

# =============================================================================
# A. PUBLISHED-STYLE OBSERVED GROUP MOVEMENT INDEX
# =============================================================================
birth <- ind %>%
  transmute(tattoo=trimws(as.character(tattoo)),
            age_fc=toupper(str_squish(as.character(age_fc))),
            year_fc=as.integer(year_fc)) %>%
  mutate(birth_year=case_when(age_fc=="CUB"~year_fc,
                              age_fc=="YEARLING"~year_fc-1L,
                              TRUE~NA_integer_)) %>%
  distinct(tattoo,.keep_all=TRUE)

live <- enc %>%
  filter(has_live_capture%in%TRUE) %>%
  transmute(tattoo=trimws(as.character(tattoo)),capture_date=as.Date(capture_date),
            year=lubridate::year(as.Date(capture_date)),socg=clean_group(socg)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(capture_date)) %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  mutate(prev_socg=lag(socg),
         movement_score=if_else(!is.na(socg)&!is.na(prev_socg),as.integer(socg!=prev_socg),NA_integer_)) %>%
  ungroup() %>%
  left_join(birth %>% select(tattoo,birth_year),by="tattoo") %>%
  mutate(is_cub=!is.na(birth_year) & year==birth_year)

ind_year_move <- live %>%
  filter(!is_cub,!is.na(movement_score)) %>%
  group_by(tattoo,year) %>%
  summarise(individual_movement_mean=mean(movement_score),
            n_scored_captures=n(),.groups="drop")

annual_sg <- annual %>%
  transmute(tattoo=trimws(as.character(tattoo)),year=as.integer(year),
            annual_socg=clean_group(annual_socg)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(year),!is.na(annual_socg))
if(anyDuplicated(annual_sg[c("tattoo","year")])) stop("Annual SG file duplicated by tattoo-year.")

resident_move <- annual_sg %>%
  left_join(ind_year_move,by=c("tattoo","year")) %>%
  filter(is.finite(individual_movement_mean))

group_move <- resident_move %>%
  group_by(year,annual_socg) %>%
  summarise(group_move_sum=sum(individual_movement_mean),
            group_move_n=n(),
            group_move_index=mean(individual_movement_mean),.groups="drop")

# Leave-one-out context for every focal annual resident.
focal_context <- annual_sg %>%
  left_join(group_move,by=c("year","annual_socg")) %>%
  left_join(ind_year_move %>% select(tattoo,year,focal_move_mean=individual_movement_mean),
            by=c("tattoo","year")) %>%
  mutate(focal_in_move_index=is.finite(focal_move_mean),
         group_move_loo_n=group_move_n-as.integer(focal_in_move_index),
         group_move_loo=if_else(group_move_loo_n>0,
           (group_move_sum-if_else(focal_in_move_index,focal_move_mean,0))/group_move_loo_n,NA_real_))

# Observed group size and lagged trend.
group_size <- annual_sg %>%
  count(year,annual_socg,name="group_size_t")
group_size_prev <- group_size %>%
  transmute(year=year+1L,annual_socg,group_size_prev=group_size_t)
focal_context <- focal_context %>%
  left_join(group_size,by=c("year","annual_socg")) %>%
  left_join(group_size_prev,by=c("year","annual_socg")) %>%
  mutate(group_size_trend=group_size_t-group_size_prev)

cat("\n============================================================\n")
cat("OBSERVED GROUP MOVEMENT INDEX AUDIT\n")
cat("============================================================\n")
cat("Scorable non-cub badger-years:",nrow(ind_year_move),"\n")
cat("Group-years with movement index:",nrow(group_move),"\n")
cat("Median contributors/group-year:",median(group_move$group_move_n),"\n")
cat("Group movement index summary:\n"); print(summary(group_move$group_move_index))

# =============================================================================
# B. FINAL V7b INTERVALS + PRESSURE
# =============================================================================
idx <- as_tibble(mov$interval_index) %>%
  mutate(interval_col=row_number(),model_i=as.integer(model_i),
         tattoo=trimws(as.character(tattoo)),
         from_year=as.integer(from_year),to_year=as.integer(to_year))
if(ncol(mov$state_draws)!=nrow(idx)) stop("Movement state matrix does not match index.")

pidx <- idx %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last) %>%
  transmute(interval_col,model_i,tattoo,from_year,to_year,context_year=to_year,
            focal_inf_row=match(tattoo,INF_IDS)) %>%
  left_join(focal_context %>%
              select(tattoo,year,annual_socg,group_move_loo,group_move_loo_n,
                     group_size_t,group_size_prev,group_size_trend),
            by=c("tattoo","context_year"="year")) %>%
  mutate(sg_key=if_else(!is.na(annual_socg),paste(context_year,annual_socg,sep="|"),NA_character_),
         q4_time=4L*(context_year-START_YEAR)+4L)

if(anyNA(pidx$focal_inf_row)) stop("Movement focal absent from infection trajectories.")

src <- annual_sg %>%
  mutate(inf_row=match(tattoo,INF_IDS)) %>%
  filter(!is.na(inf_row),year%in%unique(pidx$context_year)) %>%
  mutate(sg_key=paste(year,annual_socg,sep="|")) %>%
  select(sg_key,tattoo,inf_row)
src_by_key <- split(src,src$sg_key)

pressure_cache <- new.env(parent=emptyenv())
get_pressure <- function(inf_col){
  kk <- as.character(inf_col)
  if(exists(kk,envir=pressure_cache,inherits=FALSE)) return(get(kk,envir=pressure_cache))
  it <- as.integer(inf$infection_time[,inf_col])
  raw <- rep(NA_real_,nrow(pidx)); n_other <- integer(nrow(pidx))
  for(key in unique(na.omit(pidx$sg_key))){
    rr <- which(pidx$sg_key==key)
    ss <- src_by_key[[key]]
    if(is.null(ss)) next
    for(j in rr){
      rows <- ss$inf_row[ss$tattoo!=pidx$tattoo[j]]
      n_other[j] <- length(rows)
      if(length(rows)) raw[j] <- sum(it[rows]>0L & it[rows]<=pidx$q4_time[j])/length(rows)
    }
  }
  ans <- list(raw=raw,n=n_other); assign(kk,ans,envir=pressure_cache); ans
}

pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  pair_index <- pair_index[pick,,drop=FALSE]
}
last_live <- setNames(as.integer(paired$live_bounds$last_live_time),trimws(as.character(paired$live_bounds$tattoo)))
PERIOD_LEVELS <- sort(unique(5L*((pidx$context_year+1L)%/%5L)))

make_risk <- function(move_draw,inf_col,need_trend=FALSE){
  st <- as.integer(mov$state_draws[move_draw,pidx$interval_col])
  it <- as.integer(inf$infection_time[pidx$focal_inf_row,inf_col])
  pr <- get_pressure(inf_col)
  susceptible <- it==0L | it>pidx$q4_time
  start_q <- 4L*((pidx$context_year+1L)-START_YEAR)+1L
  end_q <- start_q+3L
  llt <- as.integer(last_live[pidx$tattoo])
  support <- susceptible & !is.na(llt) & start_q<=llt &
    pr$n>=MIN_PRESSURE_N & is.finite(pr$raw) &
    pidx$group_move_loo_n>=MIN_GROUP_MOVE_N & is.finite(pidx$group_move_loo)
  if(need_trend) support <- support & is.finite(pidx$group_size_trend)
  rr <- which(support)
  out <- vector("list",length(rr)*4L); oo <- 0L
  for(j in rr){
    last_q <- min(end_q[j],llt[j])
    for(qtime in seq.int(start_q[j],last_q)){
      if(it[j]>0L && it[j]<qtime) break
      q <- ((qtime-1L)%%4L)+1L
      yr <- START_YEAR+((qtime-1L)%/%4L)
      ev <- as.integer(it[j]>0L && it[j]==qtime)
      oo <- oo+1L
      out[[oo]] <- tibble(
        tattoo=pidx$tattoo[j],movement_state=st[j],sex=as.integer(mov$sex[pidx$model_i[j]]),
        pressure10=10*pr$raw[j],group_move10=10*pidx$group_move_loo[j],
        group_move_n=pidx$group_move_loo_n[j],group_size_trend=pidx$group_size_trend[j],
        outcome_quarter=q,outcome_year=yr,period_start=5L*(yr%/%5L),event=ev)
      if(ev==1L) break
    }
  }
  if(!oo) return(tibble())
  bind_rows(out[seq_len(oo)])
}

# =============================================================================
# C. ROBUST LOGISTIC FIT
# =============================================================================
inv_psd <- function(M){
  M <- (M+t(M))/2; ee <- eigen(M,symmetric=TRUE)
  tol <- max(1e-12,max(abs(ee$values))*1e-10); keep <- ee$values>tol
  if(!any(keep)) stop("No positive information eigenvalues.")
  V <- ee$vectors[,keep,drop=FALSE]
  V %*% diag(1/ee$values[keep],nrow=sum(keep)) %*% t(V)
}
rmvn_psd <- function(n,mu,Sigma){
  Sigma <- (Sigma+t(Sigma))/2; ee <- eigen(Sigma,symmetric=TRUE)
  ee$values[ee$values<1e-10] <- 1e-10
  A <- ee$vectors%*%diag(sqrt(ee$values),nrow=length(ee$values))
  out <- sweep(matrix(rnorm(n*length(mu)),nrow=n)%*%t(A),2,as.numeric(mu),"+")
  colnames(out) <- names(mu); out
}
build_X <- function(d,model){
  z <- list("(Intercept)"=rep(1,nrow(d)),movement_state=d$movement_state,pressure10=d$pressure10)
  if(model%in%c("G1_GROUPMOVE","G1_TREND_CC","G2_PLUS_TREND")) z$group_move10 <- d$group_move10
  if(model=="G2_PLUS_TREND") z$group_size_trend <- d$group_size_trend
  z$sex <- d$sex
  for(q in 2:4) z[[paste0("quarter",q)]] <- as.numeric(d$outcome_quarter==q)
  for(p in PERIOD_LEVELS[-1L]) z[[paste0("period",p)]] <- as.numeric(d$period_start==p)
  X <- do.call(cbind,z); storage.mode(X)<-"double"; X
}
fit_one <- function(d,model){
  X <- build_X(d,model); y <- as.numeric(d$event)
  fit <- glm.fit(X,y,family=binomial(),control=glm.control(maxit=100,epsilon=1e-8),intercept=TRUE)
  if(!isTRUE(fit$converged)) return(list(ok=FALSE))
  cf <- fit$coefficients; active <- which(is.finite(cf)); X <- X[,active,drop=FALSE]; cf <- cf[active]; names(cf)<-colnames(X)
  mu <- fit$fitted.values; w <- pmax(mu*(1-mu),1e-12)
  bread <- inv_psd(crossprod(X,X*w))
  score <- X*as.numeric(y-mu)
  U <- rowsum(score,group=d$tattoo,reorder=FALSE)
  G <- nrow(U); N <- nrow(X); K <- ncol(X)
  corr <- if(G>1L && N>K) (G/(G-1))*((N-1)/(N-K)) else 1
  V <- bread%*%(corr*crossprod(U))%*%bread; V <- (V+t(V))/2
  dr <- rmvn_psd(N_KEEP,cf,V)
  list(ok=TRUE,draws=as_tibble(dr),n=nrow(d),events=sum(y),badgers=n_distinct(d$tattoo))
}

draws <- list(); diags <- list(); nd <- 0L; ng <- 0L
for(pp in seq_len(nrow(pair_index))){
  d_main <- make_risk(pair_index$movement_draw[pp],pair_index$infection_col[pp],FALSE)
  d_trend <- make_risk(pair_index$movement_draw[pp],pair_index$infection_col[pp],TRUE)
  datasets <- list(G0_BASE=d_main,G1_GROUPMOVE=d_main,G1_TREND_CC=d_trend,G2_PLUS_TREND=d_trend)
  for(nm in names(datasets)){
    fit <- fit_one(datasets[[nm]],nm); ng <- ng+1L
    diags[[ng]] <- tibble(pair_draw=pair_index$pair_draw[pp],model=nm,fit_ok=fit$ok,
                          n_rows=nrow(datasets[[nm]]),n_events=sum(datasets[[nm]]$event),
                          n_badgers=n_distinct(datasets[[nm]]$tattoo))
    if(fit$ok){
      dr <- fit$draws; dr$pair_draw <- pair_index$pair_draw[pp]; dr$model <- nm
      nd <- nd+1L; draws[[nd]] <- dr
    }
  }
  if(pp%%10L==0L) cat("Processed paired history",pp,"/",nrow(pair_index),"\n")
}
draws <- bind_rows(draws); diagnostics <- bind_rows(diags)

summ <- function(z,p,label){
  if(!p%in%names(z)) return(NULL)
  x <- z[[p]]; x <- x[is.finite(x)]
  tibble(parameter=label,n_draws=length(x),median=median(x),
         q025=quantile(x,.025),q975=quantile(x,.975),P_gt_0=mean(x>0),
         OR_median=median(exp(x)),OR_q025=quantile(exp(x),.025),OR_q975=quantile(exp(x),.975))
}
summary <- bind_rows(lapply(unique(draws$model),function(mm){
  z <- filter(draws,model==mm)
  bind_rows(summ(z,"movement_state","beta_high_mobility"),
            summ(z,"pressure10","beta_pressure_per_10pp"),
            summ(z,"group_move10","beta_group_movement_per_10pp"),
            summ(z,"group_size_trend","beta_group_size_trend_per_badger"),
            summ(z,"sex","beta_male")) %>%
    mutate(model=mm,.before=1)
}))
audit <- diagnostics %>% group_by(model) %>%
  summarise(pairs=n(),fit_ok=sum(fit_ok),failed=sum(!fit_ok),
            median_rows=median(n_rows),median_events=median(n_events),
            median_badgers=median(n_badgers),.groups="drop")

cat("\n============================================================\n")
cat("V9 FINAL GROUP MOVEMENT INDEX -> INFECTION BRIDGE\n")
cat("============================================================\n")
print(audit,n=Inf,width=Inf)
cat("\nCoefficient summary:\n"); print(summary,n=Inf,width=Inf)

prefix <- paste0("results/V9FINAL_group_movement_infection_bridge_",RESULT_TAG)
saveRDS(list(summary=summary,audit=audit,diagnostics=diagnostics,draws=draws,
             group_move=group_move,
             settings=list(group_movement_definition="published-style annual mean of capture-to-capture intergroup movement scores; cub-years excluded; focal leave-one-out",
                           group_move_scale="10 percentage points",
                           pressure_min_n=MIN_PRESSURE_N,group_move_min_n=MIN_GROUP_MOVE_N,
                           n_pairs=nrow(pair_index),n_keep=N_KEEP)),
        paste0(prefix,".rds"))
write_csv(summary,paste0(prefix,"_summary.csv"))
write_csv(audit,paste0(prefix,"_audit.csv"))
write_csv(group_move,paste0(prefix,"_group_index.csv"))
cat("\nSaved group movement bridge outputs.\n")
