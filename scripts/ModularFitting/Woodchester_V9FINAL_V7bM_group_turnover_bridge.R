# =============================================================================
# WOODCHESTER V9 FINAL — GROUP TURNOVER / SOCIAL INSTABILITY -> INFECTION BRIDGE
#
# FINAL STOPPING-POINT ANALYSIS
#
# Scientific question
#   Does recent instability in the focal badger's observed social group predict
#   subsequent infection acquisition, above and beyond:
#     * the focal animal's V9 high-mobility state,
#     * same-group infection pressure,
#     * sex,
#     * quarter, and
#     * broad calendar period?
#
# Why this model
#   Earlier Woodchester work (notably Vicente et al. 2007) reported that a
#   group-level movement index predicted TB incidence. Their index was based on
#   capture-to-capture social-group changes and excluded cubs. The present data
#   product contains annual observed social-group assignments, so this is a
#   BRIDGE analysis rather than an exact replication.
#
# Timing
#   group turnover  = observed inter-group changes from year t-1 -> t
#   focal movement  = V9 annual latent state ending in year t
#   infection pressure = other group members infected by Q4(t)
#   outcome         = focal infection acquisition in Q1-Q4(t+1),
#                     conditional on susceptibility at Q4(t)
#
# Turnover definition
#   For focal social group g in year t, consider OTHER non-cub badgers with
#   observed social groups in BOTH t-1 and t whose transition involved g:
#       stay:    g -> g
#       arrive:  other -> g
#       depart:  g -> other
#   turnover = (arrivals + departures) /
#              (stayers + arrivals + departures)
#
#   The focal animal is excluded from its own group-turnover numerator and
#   denominator. A between-group mover contributes once to each group involved,
#   which is appropriate for a group-specific flux index.
#
# Model ladder — identical common-support rows
#   M0_CC_NOPRESSURE : focal movement + sex + quarter + 5-year period
#   M0_CC_PRESSURE   : M0 + raw same-group infection pressure
#   M1_TURNOVER      : M0 + pressure + group turnover
#
# Both pressure and turnover are scaled per +10 percentage points.
#
# Inference
#   Each of the 1,500 paired V9 movement/infection histories is fitted
#   separately with logistic regression. Uncertainty uses two-way cluster-robust
#   covariance (focal badger + focal social-group-year) because turnover and
#   pressure are shared group-year exposures. MVN coefficient draws are pooled
#   equally across paired histories. This is NOT MCMC.
#
# This is deliberately the final exploratory bridge analysis before reflection.
# =============================================================================

library(tidyverse)

MOVE_FILE <- "data/badger_movement_posterior_histories_1932_V9_FINAL.rds"
PAIR_FILE <- "data/badger_phase2_paired_latent_inputs_V9_FINAL.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
ANNUAL_FILE <- "results/badger_annual_observed_sett_locations.csv"
IND_FILE <- "data/badger_individuals.rds"

for(f in c(MOVE_FILE,PAIR_FILE,INF_FILE,ANNUAL_FILE,IND_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

mov <- readRDS(MOVE_FILE)
paired <- readRDS(PAIR_FILE)
inf <- readRDS(INF_FILE)
annual <- read_csv(ANNUAL_FILE,show_col_types=FALSE)
individuals <- as_tibble(readRDS(IND_FILE))

MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","1500"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","50"))
MIN_PRESSURE_N <- as.integer(Sys.getenv("MIN_PRESSURE_N","3"))
MIN_TURNOVER_N <- as.integer(Sys.getenv("MIN_TURNOVER_N","3"))
SEED <- as.integer(Sys.getenv("SEED","7092072"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","FULL_1500")
set.seed(SEED)

if(!is.matrix(inf$infection_time)) stop("inf$infection_time must be a matrix.")
if(is.null(paired$live_bounds) || !all(c("tattoo","last_live_time") %in% names(paired$live_bounds)))
  stop("paired object lacks live_bounds.")
if(!all(c("tattoo","year","annual_socg") %in% names(annual)))
  stop("Annual location file lacks tattoo/year/annual_socg.")
if(!all(c("tattoo","age_fc","year_fc") %in% names(individuals)))
  stop("badger_individuals.rds lacks tattoo/age_fc/year_fc.")

START_YEAR <- as.integer(inf$start_year)
INF_IDS <- trimws(as.character(inf$tattoo))
if(anyDuplicated(INF_IDS)) stop("Duplicate tattoos in infection trajectories.")

# =============================================================================
# A. FINAL V9 V7b INTERVAL TABLE
# =============================================================================
idx <- as_tibble(mov$interval_index) %>%
  mutate(interval_col=row_number(),model_i=as.integer(model_i),
         tattoo=trimws(as.character(tattoo)),
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
  transmute(interval_col,model_i,tattoo,from_year,to_year,
            exposure_year=to_year,focal_inf_row=match(tattoo,INF_IDS))

if(anyNA(pidx$focal_inf_row)) stop("Some V9 movement badgers are absent from infection trajectories.")

# =============================================================================
# B. OBSERVED ANNUAL SOCIAL GROUPS
# =============================================================================
annual_sg <- annual %>%
  transmute(tattoo=trimws(as.character(tattoo)),
            year=as.integer(year),
            annual_socg=trimws(as.character(annual_socg))) %>%
  mutate(annual_socg=if_else(is.na(annual_socg) | annual_socg=="" |
                              toupper(annual_socg)=="NA",NA_character_,annual_socg)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(year))

dup <- annual_sg %>% count(tattoo,year) %>% filter(n>1L)
if(nrow(dup)) stop("Annual SG table is not unique by tattoo+year; duplicated rows: ",nrow(dup))

pidx <- pidx %>%
  left_join(annual_sg,by=c("tattoo","exposure_year"="year")) %>%
  mutate(has_socg=!is.na(annual_socg),
         groupyear=if_else(has_socg,paste(exposure_year,annual_socg,sep="|"),NA_character_),
         q4_time=4L*(exposure_year-START_YEAR)+4L)

# =============================================================================
# C. GROUP TURNOVER INDEX FROM OBSERVED t-1 -> t SOCIAL-GROUP CHANGES
# =============================================================================
# Reconstruct birth year when possible solely to exclude known cub-year
# contributions from the group movement index, following the published logic.
birth <- individuals %>%
  transmute(tattoo=trimws(as.character(tattoo)),
            age_fc=toupper(str_squish(as.character(age_fc))),
            year_fc=as.integer(year_fc)) %>%
  mutate(birth_year=case_when(
    age_fc=="CUB" & !is.na(year_fc) ~ year_fc,
    age_fc=="YEARLING" & !is.na(year_fc) ~ year_fc-1L,
    TRUE ~ NA_integer_
  )) %>%
  distinct(tattoo,.keep_all=TRUE)

prev_sg <- annual_sg %>%
  filter(!is.na(annual_socg)) %>%
  transmute(tattoo,year=year+1L,prev_group=annual_socg)

trans <- annual_sg %>%
  filter(!is.na(annual_socg)) %>%
  transmute(tattoo,year,curr_group=annual_socg) %>%
  inner_join(prev_sg,by=c("tattoo","year")) %>%
  left_join(birth %>% select(tattoo,birth_year),by="tattoo") %>%
  mutate(is_known_cub=!is.na(birth_year) & year==birth_year,
         moved=as.integer(prev_group!=curr_group)) %>%
  filter(!is_known_cub)

# One contribution per animal to each group involved in its annual transition.
stay_contrib <- trans %>%
  filter(prev_group==curr_group) %>%
  transmute(tattoo,year,group=curr_group,moved=0L,
            arrived=0L,departed=0L,stayed=1L)

move_arrive <- trans %>%
  filter(prev_group!=curr_group) %>%
  transmute(tattoo,year,group=curr_group,moved=1L,
            arrived=1L,departed=0L,stayed=0L)

move_depart <- trans %>%
  filter(prev_group!=curr_group) %>%
  transmute(tattoo,year,group=prev_group,moved=1L,
            arrived=0L,departed=1L,stayed=0L)

turn_contrib <- bind_rows(stay_contrib,move_arrive,move_depart)

turn_group <- turn_contrib %>%
  group_by(year,group) %>%
  summarise(turn_n=n(),turn_moved=sum(moved),
            n_arrivals=sum(arrived),n_departures=sum(departed),n_stayers=sum(stayed),
            .groups="drop")

# The focal contribution to its CURRENT group in year t is either a stay or
# arrival. Subtract it so focal movement cannot mechanically create its own
# turnover exposure.
focal_turn <- turn_contrib %>%
  transmute(tattoo,year,group,focal_n=1L,focal_moved=moved,
            focal_arrived=arrived,focal_departed=departed,focal_stayed=stayed)

pidx <- pidx %>%
  left_join(turn_group,by=c("exposure_year"="year","annual_socg"="group")) %>%
  left_join(focal_turn,by=c("tattoo","exposure_year"="year","annual_socg"="group")) %>%
  mutate(
    across(c(turn_n,turn_moved,n_arrivals,n_departures,n_stayers,
             focal_n,focal_moved,focal_arrived,focal_departed,focal_stayed),
           ~replace_na(as.integer(.x),0L)),
    turnover_n_other=turn_n-focal_n,
    turnover_moved_other=turn_moved-focal_moved,
    turnover_other=if_else(turnover_n_other>0,
                           turnover_moved_other/turnover_n_other,NA_real_)
  )

if(any(pidx$turnover_n_other<0)) stop("Negative focal-excluded turnover denominator.")
if(any(is.finite(pidx$turnover_other) & (pidx$turnover_other<0 | pidx$turnover_other>1)))
  stop("Turnover proportion outside [0,1].")

# =============================================================================
# D. SAME-GROUP INFECTION PRESSURE
# =============================================================================
src <- annual_sg %>%
  mutate(inf_row=match(tattoo,INF_IDS)) %>%
  filter(!is.na(annual_socg),!is.na(inf_row),year %in% unique(pidx$exposure_year)) %>%
  mutate(groupyear=paste(year,annual_socg,sep="|")) %>%
  select(groupyear,tattoo,inf_row)

src_by_key <- split(src,src$groupyear)

pressure_cache <- new.env(parent=emptyenv())
get_pressure <- function(inf_col){
  key_cache <- as.character(inf_col)
  if(exists(key_cache,envir=pressure_cache,inherits=FALSE))
    return(get(key_cache,envir=pressure_cache,inherits=FALSE))

  it <- as.integer(inf$infection_time[,inf_col])
  raw <- rep(NA_real_,nrow(pidx))
  n_other <- integer(nrow(pidx))

  keys <- unique(na.omit(pidx$groupyear))
  for(kk in keys){
    rr <- which(!is.na(pidx$groupyear) & pidx$groupyear==kk)
    ss <- src_by_key[[kk]]
    if(is.null(ss) || !nrow(ss)) next

    for(j in rr){
      keep <- ss$tattoo!=pidx$tattoo[j]
      rows <- ss$inf_row[keep]
      n <- length(rows)
      n_other[j] <- n
      if(n>0L){
        ninfected <- sum(it[rows]>0L & it[rows]<=pidx$q4_time[j])
        raw[j] <- ninfected/n
      }
    }
  }

  ans <- list(raw=raw,n=n_other)
  assign(key_cache,ans,envir=pressure_cache)
  ans
}

# =============================================================================
# E. AUDIT THE TURNOVER EXPOSURE BEFORE FITTING
# =============================================================================
turn_audit <- pidx %>%
  filter(has_socg,is.finite(turnover_other),turnover_n_other>=MIN_TURNOVER_N) %>%
  summarise(
    intervals=n(),
    badgers=n_distinct(tattoo),
    groupyears=n_distinct(groupyear),
    median_turnover_n=median(turnover_n_other),
    q025_turnover=quantile(turnover_other,.025),
    median_turnover=median(turnover_other),
    mean_turnover=mean(turnover_other),
    q975_turnover=quantile(turnover_other,.975),
    prop_zero=mean(turnover_other==0)
  )

cat("\n============================================================\n")
cat("V9 FINAL GROUP TURNOVER -> INFECTION BRIDGE\n")
cat("============================================================\n")
cat("Candidate V7b intervals:",nrow(pidx),"\n")
cat("Focal badgers:",n_distinct(pidx$tattoo),"\n")
cat("Intervals with observed social group:",sum(pidx$has_socg),"/",nrow(pidx),"\n")
cat("Observed non-cub consecutive-year SG transitions used for turnover:",nrow(trans),"\n")
cat("  Movers:",sum(trans$moved),"| Stayers:",sum(trans$moved==0L),"\n")
cat("Minimum pressure support:",MIN_PRESSURE_N,"other badgers\n")
cat("Minimum turnover support:",MIN_TURNOVER_N,"other annual transitions\n")
cat("\nTURNOVER EXPOSURE AUDIT\n")
print(turn_audit,width=Inf)

# Save deterministic interval-level exposure audit now.
dir.create("results",showWarnings=FALSE,recursive=TRUE)
exposure_audit <- pidx %>%
  select(tattoo,from_year,to_year,exposure_year,annual_socg,groupyear,
         turn_n,turn_moved,n_arrivals,n_departures,n_stayers,
         focal_n,focal_moved,turnover_n_other,turnover_moved_other,turnover_other)
write_csv(exposure_audit,"results/V9FINAL_group_turnover_interval_exposure_audit.csv")

# =============================================================================
# F. PAIRED POSTERIOR HISTORIES + QUARTERLY RISK DATA
# =============================================================================
pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<1L) stop("MAX_PAIRS must be >=1.")
if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS)
    pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}

last_live <- setNames(as.integer(paired$live_bounds$last_live_time),
                      trimws(as.character(paired$live_bounds$tattoo)))

QUARTER_LEVELS <- 1:4
OUTCOME_YEARS <- sort(unique(pidx$exposure_year+1L))
PERIOD_LEVELS <- sort(unique(5L*(OUTCOME_YEARS%/%5L)))

make_risk_data <- function(move_draw,inf_col){
  st <- as.integer(mov$state_draws[move_draw,pidx$interval_col])
  it_focal <- as.integer(inf$infection_time[pidx$focal_inf_row,inf_col])
  pr <- get_pressure(inf_col)

  susceptible <- it_focal==0L | it_focal>pidx$q4_time
  start_q <- 4L*((pidx$exposure_year+1L)-START_YEAR)+1L
  end_q <- start_q+3L
  llt <- as.integer(last_live[pidx$tattoo])

  support <- pidx$has_socg &
    pr$n>=MIN_PRESSURE_N & is.finite(pr$raw) &
    pidx$turnover_n_other>=MIN_TURNOVER_N & is.finite(pidx$turnover_other)

  keep_interval <- susceptible & !is.na(llt) & start_q<=llt & support
  rr <- which(keep_interval)
  out <- vector("list",length(rr)*4L)
  oo <- 0L

  for(j in rr){
    last_q <- min(end_q[j],llt[j])
    for(qtime in seq.int(start_q[j],last_q)){
      if(it_focal[j]>0L && it_focal[j]<qtime) break
      q <- ((qtime-1L)%%4L)+1L
      yr <- START_YEAR+((qtime-1L)%/%4L)
      ev <- as.integer(it_focal[j]>0L && it_focal[j]==qtime)
      oo <- oo+1L
      out[[oo]] <- tibble(
        tattoo=pidx$tattoo[j],
        groupyear=pidx$groupyear[j],
        sex=as.integer(mov$sex[pidx$model_i[j]]),
        movement_state=st[j],
        pressure=pr$raw[j],
        pressure_n=pr$n[j],
        turnover=pidx$turnover_other[j],
        turnover_n=pidx$turnover_n_other[j],
        outcome_quarter=q,
        outcome_year=yr,
        period_start=5L*(yr%/%5L),
        infection_event=ev
      )
      if(ev==1L) break
    }
  }

  if(!oo) return(tibble())
  bind_rows(out[seq_len(oo)])
}

# =============================================================================
# G. TWO-WAY CLUSTER-ROBUST LOGISTIC ENGINE
# =============================================================================
rmvn_psd <- function(n,mu,Sigma){
  mu <- as.numeric(mu)
  Sigma <- as.matrix(Sigma)
  Sigma <- (Sigma+t(Sigma))/2
  if(!length(mu) || any(!is.finite(mu)) || any(!is.finite(Sigma)))
    stop("Invalid MVN inputs.")
  ee <- eigen(Sigma,symmetric=TRUE)
  ee$values[ee$values<1e-10] <- 1e-10
  A <- ee$vectors %*% diag(sqrt(ee$values),nrow=length(ee$values))
  out <- sweep(matrix(rnorm(n*length(mu)),nrow=n) %*% t(A),2,mu,"+")
  colnames(out) <- names(mu)
  out
}

inv_psd <- function(M){
  M <- (M+t(M))/2
  ee <- eigen(M,symmetric=TRUE)
  tol <- max(1e-12,max(abs(ee$values))*1e-10)
  keep <- ee$values>tol
  if(!any(keep)) stop("Information matrix has no positive eigenvalues.")
  V <- ee$vectors[,keep,drop=FALSE]
  V %*% diag(1/ee$values[keep],nrow=sum(keep)) %*% t(V)
}

cluster_meat <- function(score_rows,cluster){
  cluster <- as.character(cluster)
  U <- rowsum(score_rows,group=cluster,reorder=FALSE)
  G <- nrow(U)
  M <- crossprod(U)
  if(G>1L) M <- (G/(G-1))*M
  list(meat=M,G=G)
}

build_X <- function(d,model){
  cols <- list(
    "(Intercept)"=rep(1,nrow(d)),
    movement_state=as.numeric(d$movement_state)
  )

  if(model %in% c("M0_CC_PRESSURE","M1_TURNOVER"))
    cols$pressure10 <- 10*as.numeric(d$pressure)

  if(model=="M1_TURNOVER")
    cols$turnover10 <- 10*as.numeric(d$turnover)

  cols$sex <- as.numeric(d$sex)

  for(q in QUARTER_LEVELS[-1L])
    cols[[paste0("quarter",q)]] <- as.numeric(d$outcome_quarter==q)

  for(p in PERIOD_LEVELS[-1L])
    cols[[paste0("period",p)]] <- as.numeric(d$period_start==p)

  X <- do.call(cbind,cols)
  storage.mode(X) <- "double"
  X
}

fit_one <- function(model,d,nkeep){
  warns <- character(0)
  y <- as.numeric(d$infection_event)
  X <- build_X(d,model)
  cl_badger <- trimws(as.character(d$tattoo))
  cl_groupyear <- trimws(as.character(d$groupyear))
  cl_intersection <- paste(cl_badger,cl_groupyear,sep="||")

  finite_by_col <- colSums(!is.finite(X))
  bad_y <- sum(!is.finite(y))
  bad_cluster <- sum(is.na(cl_badger) | !nzchar(cl_badger) |
                     is.na(cl_groupyear) | !nzchar(cl_groupyear))

  if(any(finite_by_col>0) || bad_y>0 || bad_cluster>0){
    bad_cols <- paste(names(finite_by_col)[finite_by_col>0],
                      finite_by_col[finite_by_col>0],sep="=",collapse=", ")
    return(list(ok=FALSE,draws=NULL,warning="",
                message=paste0("non-finite inputs; X[",bad_cols,
                               "]; y=",bad_y,"; cluster=",bad_cluster)))
  }

  fit <- tryCatch(
    withCallingHandlers(
      glm.fit(x=X,y=y,family=binomial(link="logit"),intercept=FALSE,
              control=glm.control(maxit=100,epsilon=1e-8)),
      warning=function(w){
        warns <<- c(warns,conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error=function(e)e
  )

  if(inherits(fit,"error"))
    return(list(ok=FALSE,draws=NULL,warning=paste(unique(warns),collapse=" | "),
                message=conditionMessage(fit)))

  if(!isTRUE(fit$converged))
    return(list(ok=FALSE,draws=NULL,warning=paste(unique(warns),collapse=" | "),
                message="glm.fit did not converge"))

  cf_all <- fit$coefficients
  active <- which(is.finite(cf_all))
  if(!length(active))
    return(list(ok=FALSE,draws=NULL,warning=paste(unique(warns),collapse=" | "),
                message="no estimable coefficients"))

  Xa <- X[,active,drop=FALSE]
  cf <- cf_all[active]
  names(cf) <- colnames(X)[active]
  mu <- as.numeric(fit$fitted.values)

  rob <- tryCatch({
    w <- pmax(mu*(1-mu),1e-12)
    bread <- inv_psd(crossprod(Xa,Xa*w))
    score_rows <- Xa*as.numeric(y-mu)

    mb <- cluster_meat(score_rows,cl_badger)
    mg <- cluster_meat(score_rows,cl_groupyear)
    mi <- cluster_meat(score_rows,cl_intersection)

    # Cameron-Gelbach-Miller inclusion-exclusion for two-way clustering.
    meat <- mb$meat + mg$meat - mi$meat

    N <- nrow(Xa)
    K <- ncol(Xa)
    if(N>K) meat <- ((N-1)/(N-K))*meat

    V <- bread %*% meat %*% bread
    V <- (V+t(V))/2
    rownames(V) <- colnames(V) <- names(cf)

    list(beta=cf,V=V,n_badger_clusters=mb$G,
         n_groupyear_clusters=mg$G,n_intersection_clusters=mi$G)
  },error=function(e)e)

  if(inherits(rob,"error") || any(!is.finite(rob$V)))
    return(list(ok=FALSE,draws=NULL,warning=paste(unique(warns),collapse=" | "),
                message="two-way robust covariance failed"))

  dr <- tryCatch(rmvn_psd(nkeep,rob$beta,rob$V),error=function(e)e)
  if(inherits(dr,"error"))
    return(list(ok=FALSE,draws=NULL,warning=paste(unique(warns),collapse=" | "),
                message=paste("MVN draw failed:",conditionMessage(dr))))

  colnames(dr) <- names(rob$beta)

  list(ok=TRUE,draws=as_tibble(dr),
       warning=paste(unique(warns),collapse=" | "),message="",
       n_badger_clusters=rob$n_badger_clusters,
       n_groupyear_clusters=rob$n_groupyear_clusters,
       n_intersection_clusters=rob$n_intersection_clusters)
}

# =============================================================================
# H. FIT MODEL LADDER ACROSS ALL PAIRED HISTORIES
# =============================================================================
draw_list <- list()
diag_list <- list()
retention_list <- list()
nd <- 0L
ng <- 0L

for(pp in seq_len(nrow(pair_index))){
  move_draw <- pair_index$movement_draw[pp]
  inf_col <- pair_index$infection_col[pp]
  d <- make_risk_data(move_draw,inf_col)

  if(!nrow(d))
    stop("Empty common-support risk data at pair ",pair_index$pair_draw[pp])

  retention_list[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    n_rows=nrow(d),
    n_events=sum(d$infection_event),
    n_badgers=n_distinct(d$tattoo),
    n_groupyears=n_distinct(d$groupyear),
    n_high_rows=sum(d$movement_state==1L),
    median_pressure_n=median(d$pressure_n),
    median_turnover_n=median(d$turnover_n),
    median_turnover=median(d$turnover)
  )

  if(pp==1L){
    cat("\nFIRST-PAIR COMMON-SUPPORT AUDIT\n")
    print(retention_list[[pp]],width=Inf)
    cat("Raw infection pressure summary:\n")
    print(summary(d$pressure))
    cat("Group turnover summary:\n")
    print(summary(d$turnover))
  }

  models <- c("M0_CC_NOPRESSURE","M0_CC_PRESSURE","M1_TURNOVER")
  fits <- lapply(models,function(nm) fit_one(nm,d,N_KEEP))
  names(fits) <- models

  for(nm in models){
    z <- fits[[nm]]
    ng <- ng+1L
    diag_list[[ng]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      movement_draw=move_draw,
      infection_col=inf_col,
      model=nm,
      n_rows=nrow(d),
      n_events=sum(d$infection_event),
      n_badgers=n_distinct(d$tattoo),
      n_groupyears=n_distinct(d$groupyear),
      n_high_rows=sum(d$movement_state==1L),
      fit_ok=z$ok,
      n_badger_clusters=if(z$ok) z$n_badger_clusters else NA_integer_,
      n_groupyear_clusters=if(z$ok) z$n_groupyear_clusters else NA_integer_,
      warnings=z$warning,
      message=z$message
    )

    if(z$ok){
      dr <- z$draws
      dr$pair_draw <- pair_index$pair_draw[pp]
      dr$model <- nm
      nd <- nd+1L
      draw_list[[nd]] <- dr
    }
  }

  if(pp%%10L==0L)
    cat("Processed paired history",pp,"/",nrow(pair_index),"\n")
}

draws <- bind_rows(draw_list)
diag <- bind_rows(diag_list)
retention <- bind_rows(retention_list)
if(!nrow(draws)) stop("No models fitted successfully.")

fit_audit <- diag %>%
  group_by(model) %>%
  summarise(
    pairs=n(),
    fit_ok=sum(fit_ok),
    failed=sum(!fit_ok),
    median_rows=median(n_rows),
    median_events=median(n_events),
    median_badgers=median(n_badgers),
    median_groupyears=median(n_groupyears),
    median_high_rows=median(n_high_rows),
    .groups="drop"
  )

retention_summary <- retention %>%
  summarise(
    pairs=n(),
    median_rows=median(n_rows),
    median_events=median(n_events),
    median_badgers=median(n_badgers),
    median_groupyears=median(n_groupyears),
    median_high_rows=median(n_high_rows),
    median_pressure_n=median(median_pressure_n),
    median_turnover_n=median(median_turnover_n),
    median_turnover=median(median_turnover)
  )

summarise_parameter_safe <- function(df,param,label){
  if(!param %in% names(df)) return(NULL)
  x <- as.numeric(df[[param]])
  x <- x[is.finite(x)]
  if(!length(x)) return(NULL)

  tibble(
    model=unique(df$model),
    parameter=label,
    n_draws=length(x),
    mean=mean(x),
    sd=sd(x),
    median=median(x),
    q025=unname(quantile(x,.025)),
    q975=unname(quantile(x,.975)),
    P_gt_0=mean(x>0),
    OR_median=median(exp(x)),
    OR_q025=unname(quantile(exp(x),.025)),
    OR_q975=unname(quantile(exp(x),.975))
  )
}

summary_rows <- list()
ns <- 0L

for(nm in unique(draws$model)){
  z <- draws %>% filter(model==nm)
  specs <- list(
    c("movement_state","beta_move"),
    c("pressure10","beta_pressure_per_10pp"),
    c("turnover10","beta_turnover_per_10pp"),
    c("sex","beta_sex")
  )

  for(sp in specs){
    rr <- summarise_parameter_safe(z,sp[1],sp[2])
    if(!is.null(rr)){
      ns <- ns+1L
      summary_rows[[ns]] <- rr
    }
  }
}

param_summary <- bind_rows(summary_rows)

cat("\n============================================================\n")
cat("FIT AUDIT\n")
cat("============================================================\n")
print(fit_audit,n=Inf,width=Inf)

cat("\nCOMMON-SUPPORT RISK SET\n")
print(retention_summary,width=Inf)

cat("\nPOOLED COEFFICIENT SUMMARY\n")
print(param_summary,n=Inf,width=Inf)

cat("\nInterpretation guide:\n")
cat("  beta_turnover_per_10pp = change in subsequent infection odds per +10 percentage points\n")
cat("  in focal-excluded annual social-group turnover (t-1 -> t), adjusted for focal\n")
cat("  V9 movement state, Q4(t) same-group infection pressure, sex, quarter and period.\n")
cat("  This annual turnover index is a bridge to, not an exact recreation of, the\n")
cat("  capture-event group movement index used in earlier Woodchester publications.\n")

# =============================================================================
# I. SAVE
# =============================================================================
prefix <- paste0("results/V9FINAL_V7bM_group_turnover_bridge_",RESULT_TAG)

saveRDS(
  list(
    model="V9FINAL group turnover/social instability -> subsequent infection bridge",
    coefficient_draws=draws,
    parameter_summary=param_summary,
    fit_audit=fit_audit,
    fit_diagnostics=diag,
    retention_by_pair=retention,
    retention_summary=retention_summary,
    pair_index=pair_index,
    turnover_audit=turn_audit,
    definition=list(
      turnover_window="observed annual social-group transitions t-1 -> t",
      turnover_numerator="other non-cub arrivals + departures involving focal social group",
      turnover_denominator="other non-cub stayers + arrivals + departures with observed group in both years",
      focal_excluded=TRUE,
      cubs_excluded_when_birth_year_reconstructable=TRUE,
      pressure_time="Q4(t)",
      outcome_time="Q1-Q4(t+1)",
      pressure="infected other badgers / all other infection-history badgers in focal observed social group",
      turnover_scale="10 percentage points",
      pressure_scale="10 percentage points",
      published_bridge="analogous in purpose to Vicente et al. 2007 group movement index, but based on annual observed group changes rather than capture-to-capture movement scores"
    ),
    settings=list(
      n_pairs=nrow(pair_index),
      draws_per_history=N_KEEP,
      min_pressure_n=MIN_PRESSURE_N,
      min_turnover_n=MIN_TURNOVER_N,
      seed=SEED,
      covariance="two-way cluster robust: focal badger + focal social-group-year",
      final_bridge_analysis=TRUE
    )
  ),
  paste0(prefix,".rds")
)

write_csv(param_summary,paste0(prefix,"_summary.csv"))
write_csv(fit_audit,paste0(prefix,"_fit_audit.csv"))
write_csv(retention,paste0(prefix,"_retention_by_pair.csv"))
write_csv(turn_audit,paste0(prefix,"_turnover_audit.csv"))

cat("\nSaved:\n")
cat(prefix,".rds\n",sep="")
cat(prefix,"_summary.csv\n",sep="")
cat(prefix,"_fit_audit.csv\n",sep="")
cat(prefix,"_retention_by_pair.csv\n",sep="")
cat(prefix,"_turnover_audit.csv\n",sep="")
cat("results/V9FINAL_group_turnover_interval_exposure_audit.csv\n")
