# =============================================================================
# WOODCHESTER PHASE 2B: V7b-M
# HIGH MOBILITY -> SUBSEQUENT INFECTION ACQUISITION
#
# Modular/cut analysis:
#   movement ending in year t predicts infection acquisition in Q1-Q4 of t+1,
#   conditional on being susceptible at Q4 of year t.
#
# Discrete-time quarterly hazard:
#
# logit(h_iq) =
#   alpha + beta_move * high_mobility_t + beta_sex * sex
#         + quarter_effect[q] + period_effect[p]
#
# Quarter and 5-year period effects use sum-to-zero coding, matching the earlier
# V7b-T formulation. Each paired movement/infection latent history is fitted
# conditionally, then equal numbers of posterior draws are pooled across pairs.
#
# The exact grouped-binomial likelihood is used. A multivariate normal proposal
# around the posterior mode is used only for importance sampling.
# =============================================================================

library(tidyverse)

PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"

for(f in c(PAIR_FILE,MOVE_FILE,INF_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

paired <- readRDS(PAIR_FILE)
mov <- readRDS(MOVE_FILE)
inf <- readRDS(INF_FILE)

# ---- run controls -------------------------------------------------------------
MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","1500"))
N_PROP <- as.integer(Sys.getenv("N_PROP","4000"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","100"))
SEED <- as.integer(Sys.getenv("SEED","7092029"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","FULL")

set.seed(SEED)

# ---- input checks -------------------------------------------------------------
if(!all(c("tattoo","draws","infection_time","start_year")%in%names(inf)))
  stop("Canonical infection trajectory fields are missing.")
if(!is.matrix(inf$infection_time))
  stop("inf$infection_time must be a tattoo x draw matrix.")

START_YEAR <- as.integer(inf$start_year)
if(length(START_YEAR)!=1L || is.na(START_YEAR))
  stop("Invalid infection start_year.")

idx <- mov$interval_index %>%
  mutate(
    interval_col=row_number(),
    model_i=as.integer(model_i),
    tattoo=trimws(as.character(tattoo)),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year)
  )

if(ncol(mov$state_draws)!=nrow(idx))
  stop("Movement state matrix does not match interval index.")
if(!all(mov$state_draws%in%c(0L,1L)))
  stop("Movement histories must be coded 0=local, 1=high.")

sex_i <- as.integer(mov$sex)
if(any(!sex_i%in%c(0L,1L)))
  stop("Sex must be coded 0=female, 1=male.")

inf_ids <- trimws(as.character(inf$tattoo))
inf_row <- setNames(seq_along(inf_ids),inf_ids)

if(any(!unique(idx$tattoo)%in%inf_ids))
  stop("Some movement badgers are absent from infection trajectories.")

if(is.null(paired$live_bounds) ||
   !all(c("tattoo","last_live_time")%in%names(paired$live_bounds)))
  stop("paired object lacks live_bounds required for strict future follow-up.")

last_live <- setNames(
  as.integer(paired$live_bounds$last_live_time),
  trimws(as.character(paired$live_bounds$tattoo))
)

# Exclude the last movement interval for each badger: it cannot predict a fully
# subsequent modeled annual interval, matching the V7b-T audit construction.
eligible_move <- idx %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last)

# All possible 5-year periods represented by strict t+1 follow-up.
possible_outcome_years <- sort(unique(eligible_move$to_year+1L))
PERIOD_LEVELS <- sort(unique(floor(possible_outcome_years/5L)*5L))
N_PERIOD <- length(PERIOD_LEVELS)
if(N_PERIOD<2L) stop("Need at least two period levels.")

# ---- sum-to-zero design -------------------------------------------------------
# Free parameters:
# alpha
# beta_move
# beta_sex
# quarter_raw[1:3], with quarter 4 = -sum(raw)
# period_raw[1:(N_PERIOD-1)], with final period = -sum(raw)
P <- 3L + 3L + (N_PERIOD-1L)

par_names <- c(
  "alpha","beta_move","beta_sex",
  paste0("quarter_raw[",1:3,"]"),
  paste0("period_raw[",1:(N_PERIOD-1L),"]")
)

quarter_contrast <- function(q){
  z <- numeric(3)
  if(q<=3L) z[q] <- 1 else z[] <- -1
  z
}
period_contrast <- function(period_start){
  j <- match(period_start,PERIOD_LEVELS)
  if(is.na(j)) stop("Unknown period level: ",period_start)
  z <- numeric(N_PERIOD-1L)
  if(j<N_PERIOD) z[j] <- 1 else z[] <- -1
  z
}

# Fixed cell grid: movement x sex x quarter x period
cells <- expand_grid(
  movement_state=0:1,
  sex=0:1,
  outcome_quarter=1:4,
  period_start=PERIOD_LEVELS
) %>%
  arrange(period_start,outcome_quarter,sex,movement_state) %>%
  mutate(cell=row_number())

X <- matrix(0,nrow=nrow(cells),ncol=P,dimnames=list(NULL,par_names))
for(r in seq_len(nrow(cells))){
  X[r,1] <- 1
  X[r,2] <- cells$movement_state[r]
  X[r,3] <- cells$sex[r]
  X[r,4:6] <- quarter_contrast(cells$outcome_quarter[r])
  X[r,7:P] <- period_contrast(cells$period_start[r])
}

cell_key <- with(
  cells,
  paste(movement_state,sex,outcome_quarter,period_start,sep="|")
)

# ---- priors ------------------------------------------------------------------
# Baseline quarterly acquisition is around 1-2%; use a weak intercept prior.
PRIOR_MEAN <- c(
  alpha=qlogis(.0125),
  beta_move=0,
  beta_sex=0,
  rep(0,3),
  rep(0,N_PERIOD-1L)
)
PRIOR_SD <- c(
  alpha=1.5,
  beta_move=1.5,
  beta_sex=1.5,
  rep(1,3),
  rep(1,N_PERIOD-1L)
)
names(PRIOR_MEAN) <- names(PRIOR_SD) <- par_names

# ---- paired history selection -------------------------------------------------
pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<1L) stop("MAX_PAIRS must be >=1.")

if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS)
    pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}

cat("\n============================================================\n")
cat("WOODCHESTER V7b-M: HIGH MOBILITY -> FUTURE INFECTION\n")
cat("============================================================\n")
cat("Paired histories used:",nrow(pair_index),"\n")
cat("Importance proposals / history:",N_PROP,"\n")
cat("Posterior draws retained / history:",N_KEEP,"\n")
cat("Total pooled posterior draws:",nrow(pair_index)*N_KEEP,"\n")
cat("Quarter effects: sum-to-zero (3 free)\n")
cat("5-year periods:",paste(PERIOD_LEVELS,collapse=", "),"\n")
cat("Period effects: sum-to-zero (",N_PERIOD-1L," free)\n",sep="")
cat("Total model parameters:",P,"\n")

# ---- construct grouped risk counts -------------------------------------------
n_mat <- matrix(0L,nrow=nrow(pair_index),ncol=nrow(cells))
y_mat <- matrix(0L,nrow=nrow(pair_index),ncol=nrow(cells))

for(pp in seq_len(nrow(pair_index))){
  md <- pair_index$movement_draw[pp]
  ic <- pair_index$infection_col[pp]

  st <- as.integer(mov$state_draws[md,])
  it <- as.integer(inf$infection_time[,ic])
  names(it) <- inf_ids

  nvec <- integer(nrow(cells))
  yvec <- integer(nrow(cells))

  for(rr in seq_len(nrow(eligible_move))){
    row <- eligible_move[rr,]
    tattoo <- row$tattoo
    infection_time <- it[tattoo]
    move_end_year <- row$to_year
    move_end_q4 <- 4L*(move_end_year-START_YEAR)+4L

    susceptible_q4 <- infection_time==0L || infection_time>move_end_q4
    if(!susceptible_q4) next

    outcome_year <- move_end_year+1L
    period_start <- floor(outcome_year/5L)*5L
    llt <- last_live[tattoo]

    for(q in 1:4){
      ot <- 4L*(outcome_year-START_YEAR)+q
      if(ot>llt) break
      if(infection_time>0L && infection_time<ot) break

      event <- as.integer(infection_time>0L && infection_time==ot)

      key <- paste(
        st[row$interval_col],
        sex_i[row$model_i],
        q,
        period_start,
        sep="|"
      )
      cc <- match(key,cell_key)
      if(is.na(cc)) stop("Could not match risk cell.")

      nvec[cc] <- nvec[cc]+1L
      yvec[cc] <- yvec[cc]+event

      if(event==1L) break
    }
  }

  n_mat[pp,] <- nvec
  y_mat[pp,] <- yvec

  if(pp%%100L==0L) cat("Built risk counts",pp,"/",nrow(pair_index),"\n")
}

# Reproduce audit exactly.
count_audit <- pair_index %>%
  transmute(
    pair_draw,
    risk_quarters=rowSums(n_mat),
    events=rowSums(y_mat)
  )

check <- count_audit %>%
  left_join(
    paired$audit %>%
      select(
        pair_draw,
        audit_risk=v7b_risk_quarters,
        audit_events=v7b_events
      ),
    by="pair_draw"
  )

if(any(check$risk_quarters!=check$audit_risk) ||
   any(check$events!=check$audit_events))
  stop("V7b model counts do not reproduce Phase-2 audit exactly.")

cat("Model-input counts reproduce Phase-2 audit: PASS\n")

# ---- posterior utilities ------------------------------------------------------
log1pexp <- function(x)
  ifelse(x>0,x+log1p(exp(-x)),log1p(exp(x)))

logpost_one <- function(theta,n,y){
  eta <- as.vector(X%*%theta)
  ll <- sum(y*eta-n*log1pexp(eta))
  lp <- -0.5*sum(((theta-PRIOR_MEAN)/PRIOR_SD)^2)
  ll+lp
}

nlp_one <- function(theta,n,y) -logpost_one(theta,n,y)

grad_nlp_one <- function(theta,n,y){
  eta <- as.vector(X%*%theta)
  p <- plogis(eta)
  g <- as.vector(crossprod(X,y-n*p))-(theta-PRIOR_MEAN)/(PRIOR_SD^2)
  -g
}

hessian_one <- function(theta,n){
  eta <- as.vector(X%*%theta)
  p <- plogis(eta)
  w <- n*p*(1-p)
  crossprod(X,X*w)+diag(1/(PRIOR_SD^2),P)
}

logpost_many <- function(theta_mat,n,y){
  eta <- theta_mat%*%t(X)
  ll <- rowSums(
    sweep(eta,2,y,"*") -
    sweep(log1pexp(eta),2,n,"*")
  )
  z <- sweep(theta_mat,2,PRIOR_MEAN,"-")
  lp <- -0.5*rowSums(sweep(z^2,2,PRIOR_SD^2,"/"))
  ll+lp
}

draw_mvn <- function(n,mu,Sigma){
  R <- chol(Sigma)
  sweep(matrix(rnorm(n*length(mu)),n,length(mu))%*%R,2,mu,"+")
}

logdmvn_many <- function(x,mu,Sigma){
  d <- length(mu)
  md <- mahalanobis(x,center=mu,cov=Sigma)
  logdet <- as.numeric(determinant(Sigma,logarithm=TRUE)$modulus)
  -0.5*(d*log(2*pi)+logdet+md)
}

logsumexp2 <- function(a,b){
  m <- pmax(a,b)
  m+log(exp(a-m)+exp(b-m))
}

# ---- conditional posterior over all paired histories -------------------------
pooled <- matrix(
  NA_real_,
  nrow=nrow(pair_index)*N_KEEP,
  ncol=P,
  dimnames=list(NULL,par_names)
)
pooled_pair <- integer(nrow(pooled))
pair_diag <- vector("list",nrow(pair_index))

start_row <- 1L
start_par <- PRIOR_MEAN

for(pp in seq_len(nrow(pair_index))){
  n <- as.numeric(n_mat[pp,])
  y <- as.numeric(y_mat[pp,])

  opt <- optim(
    par=start_par,
    fn=nlp_one,
    gr=grad_nlp_one,
    n=n,
    y=y,
    method="BFGS",
    control=list(maxit=750,reltol=1e-9)
  )

  if(opt$convergence!=0L){
    opt <- optim(
      par=PRIOR_MEAN,
      fn=nlp_one,
      gr=grad_nlp_one,
      n=n,
      y=y,
      method="BFGS",
      control=list(maxit=1000,reltol=1e-10)
    )
  }

  H <- hessian_one(opt$par,n)
  eig <- eigen(H,symmetric=TRUE)
  eig$values[eig$values<1e-8] <- 1e-8
  V <- eig$vectors%*%diag(1/eig$values,P)%*%t(eig$vectors)

  # Defensive mixture proposal:
  # 90% moderately inflated Laplace covariance + 10% broad tail component.
  V1 <- V*(1.25^2)
  V2 <- V*(2.5^2)

  comp2 <- runif(N_PROP)<0.10
  prop <- matrix(NA_real_,N_PROP,P)
  if(any(!comp2))
    prop[!comp2,] <- draw_mvn(sum(!comp2),opt$par,V1)
  if(any(comp2))
    prop[comp2,] <- draw_mvn(sum(comp2),opt$par,V2)

  lq1 <- logdmvn_many(prop,opt$par,V1)+log(.90)
  lq2 <- logdmvn_many(prop,opt$par,V2)+log(.10)
  logq <- logsumexp2(lq1,lq2)

  logw <- logpost_many(prop,n,y)-logq
  logw <- logw-max(logw)
  w <- exp(logw)
  w <- w/sum(w)

  is_ess <- 1/sum(w^2)

  keep <- sample.int(N_PROP,N_KEEP,replace=TRUE,prob=w)
  rows <- start_row:(start_row+N_KEEP-1L)
  pooled[rows,] <- prop[keep,,drop=FALSE]
  pooled_pair[rows] <- pair_index$pair_draw[pp]
  start_row <- start_row+N_KEEP
  start_par <- opt$par

  pair_diag[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    movement_draw=pair_index$movement_draw[pp],
    infection_draw=pair_index$infection_draw[pp],
    n_risk=sum(n),
    n_events=sum(y),
    mode_beta_move=opt$par[2],
    mode_beta_sex=opt$par[3],
    IS_ESS=is_ess,
    max_importance_weight=max(w),
    optim_code=opt$convergence
  )

  if(pp%%100L==0L)
    cat("Fitted paired history",pp,"/",nrow(pair_index),"\n")
}

pair_diag <- bind_rows(pair_diag)
pooled <- as_tibble(pooled) %>%
  mutate(pair_draw=pooled_pair,.before=1)

# ---- pooled posterior summaries ----------------------------------------------
summ <- function(x){
  tibble(
    mean=mean(x),
    sd=sd(x),
    median=median(x),
    q025=unname(quantile(x,.025)),
    q975=unname(quantile(x,.975)),
    P_gt_0=mean(x>0)
  )
}

main_summary <- bind_rows(
  lapply(c("alpha","beta_move","beta_sex"),function(nm)
    summ(pooled[[nm]]) %>% mutate(parameter=nm,.before=1))
)

effect_draws <- pooled %>%
  transmute(
    pair_draw,
    alpha,beta_move,beta_sex,
    OR_high_mobility=exp(beta_move),
    OR_male=exp(beta_sex)
  )

derived_summary <- tibble(
  quantity=c("OR_high_mobility","OR_male"),
  median=c(
    median(effect_draws$OR_high_mobility),
    median(effect_draws$OR_male)
  ),
  q025=c(
    quantile(effect_draws$OR_high_mobility,.025),
    quantile(effect_draws$OR_male,.025)
  ),
  q975=c(
    quantile(effect_draws$OR_high_mobility,.975),
    quantile(effect_draws$OR_male,.975)
  )
)

cat("\n============================================================\n")
cat("V7b-M POOLED MODULAR POSTERIOR\n")
cat("============================================================\n")
print(main_summary,n=Inf,width=Inf)

cat("\nDerived effects:\n")
print(derived_summary,n=Inf,width=Inf)

cat("\nPrimary movement effect:\n")
cat("  beta_move median:",median(pooled$beta_move),"\n")
cat("  95% CrI:",
    unname(quantile(pooled$beta_move,.025)),"to",
    unname(quantile(pooled$beta_move,.975)),"\n")
cat("  P(beta_move > 0):",mean(pooled$beta_move>0),"\n")
cat("  high-mobility OR median:",median(effect_draws$OR_high_mobility),"\n")
cat("  OR 95% CrI:",
    unname(quantile(effect_draws$OR_high_mobility,.025)),"to",
    unname(quantile(effect_draws$OR_high_mobility,.975)),"\n")

cat("\nImportance-sampling diagnostics:\n")
print(
  pair_diag %>%
    summarise(
      pairs=n(),
      min_IS_ESS=min(IS_ESS),
      q025_IS_ESS=quantile(IS_ESS,.025),
      median_IS_ESS=median(IS_ESS),
      mean_IS_ESS=mean(IS_ESS),
      max_weight=max(max_importance_weight),
      n_ESS_lt_500=sum(IS_ESS<500),
      n_optim_nonzero=sum(optim_code!=0)
    ),
  width=Inf
)

# ---- save --------------------------------------------------------------------
dir.create("results",showWarnings=FALSE,recursive=TRUE)

out_rds <- paste0("results/V7bM_movement_to_infection_",RESULT_TAG,".rds")
out_csv <- paste0("results/V7bM_movement_to_infection_",RESULT_TAG,"_summary.csv")

saveRDS(
  list(
    model="V7b-M modular high mobility -> subsequent infection acquisition",
    coefficient_draws=pooled,
    effect_draws=effect_draws,
    main_summary=main_summary,
    derived_summary=derived_summary,
    pair_diagnostics=pair_diag,
    pair_counts=list(n=n_mat,y=y_mat,cells=cells),
    periods=PERIOD_LEVELS,
    design=X,
    priors=list(mean=PRIOR_MEAN,sd=PRIOR_SD),
    settings=list(
      n_pairs=nrow(pair_index),
      n_importance_proposals=N_PROP,
      n_posterior_draws_per_pair=N_KEEP,
      seed=SEED,
      movement_definition="movement interval ending in year t",
      risk_definition="susceptible at Q4 year t; acquisition Q1-Q4 of t+1",
      followup="censored at last observed live quarter",
      quarter_effect="sum-to-zero",
      period_effect="5-year categorical sum-to-zero",
      pooling="equal posterior draws per paired latent-history dataset",
      approximation="exact grouped-binomial posterior via defensive-mixture importance sampling"
    )
  ),
  out_rds
)

bind_rows(
  main_summary %>%
    transmute(
      type="coefficient",name=parameter,
      median,q025,q975,
      probability_positive=P_gt_0
    ),
  derived_summary %>%
    transmute(
      type="derived",name=quantity,
      median,q025,q975,
      probability_positive=NA_real_
    )
) %>%
  write_csv(out_csv)

cat("\nSaved:",out_rds,"\n")
cat("Saved:",out_csv,"\n")
