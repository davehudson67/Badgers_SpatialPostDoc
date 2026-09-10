# =============================================================================
# WOODCHESTER V7a-M SENSITIVITY
# Infection -> subsequent local-to-high movement
#
# Adds two deliberately simple controls to the primary V7a-M:
#   1. 5-year historical period (sum-to-zero)
#   2. adult-entry vs young-entry status
#
# Also allows a stricter infection-precedence sensitivity:
#   INF_LAG_YEARS = 0 : infected by Q4 of movement-origin year (primary timing)
#   INF_LAG_YEARS = 1 : infected by Q4 of the PREVIOUS year (strict timing)
#
# Model, conditional on previous movement state being local:
#
# logit P(high_t = 1) =
#   alpha + beta_inf * infected_origin
#         + beta_sex * sex
#         + beta_adult * adult_entry
#         + beta_period[5-year period]
#
# Each paired latent-history dataset is fitted separately with an exact grouped
# binomial posterior and defensive-mixture importance sampling. Equal posterior
# draws are retained per paired history before pooling.
# =============================================================================

library(tidyverse)

PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
INF_FILE  <- "data/badger_infection_trajectories_all_tests_inferred.rds"

for(f in c(PAIR_FILE,MOVE_FILE,INF_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

paired <- readRDS(PAIR_FILE)
mov <- readRDS(MOVE_FILE)
inf <- readRDS(INF_FILE)

# ---- controls ----------------------------------------------------------------
MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","1500"))
N_PROP <- as.integer(Sys.getenv("N_PROP","6000"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","100"))
INF_LAG_YEARS <- as.integer(Sys.getenv("INF_LAG_YEARS","0"))
SEED <- as.integer(Sys.getenv("SEED","7092031"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","PERIOD_ENTRY")

if(!INF_LAG_YEARS%in%c(0L,1L))
  stop("INF_LAG_YEARS must be 0 or 1.")

set.seed(SEED)

# ---- canonical inputs ---------------------------------------------------------
if(!all(c("tattoo","draws","infection_time","start_year")%in%names(inf)))
  stop("Canonical infection trajectory fields are missing.")
if(!is.matrix(inf$infection_time))
  stop("inf$infection_time must be a tattoo x draw matrix.")

START_YEAR <- as.integer(inf$start_year)

idx <- mov$interval_index %>%
  mutate(
    interval_col=row_number(),
    model_i=as.integer(model_i),
    tattoo=trimws(as.character(tattoo)),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year),
    period_start=floor(from_year/5L)*5L
  )

if(ncol(mov$state_draws)!=nrow(idx))
  stop("Movement state matrix does not match interval index.")

sex_i <- as.integer(mov$sex)
adult_i <- as.integer(mov$adult_entry)

if(any(!sex_i%in%c(0L,1L))) stop("Sex must be 0/1.")
if(any(!adult_i%in%c(0L,1L))) stop("adult_entry must be 0/1.")

sex_interval <- sex_i[idx$model_i]
adult_interval <- adult_i[idx$model_i]

inf_ids <- trimws(as.character(inf$tattoo))
inf_row_interval <- match(idx$tattoo,inf_ids)
if(anyNA(inf_row_interval))
  stop("Some movement badgers are missing from infection trajectories.")

# Previous state within each badger.
prev_col <- rep(NA_integer_,nrow(idx))
split_rows <- split(seq_len(nrow(idx)),idx$model_i)
for(rr in split_rows){
  rr <- rr[order(idx$from_year[rr],idx$to_year[rr])]
  if(length(rr)>1L) prev_col[rr[-1L]] <- rr[-length(rr)]
}

# Infection must have occurred by Q4 of origin year - lag.
infection_cutoff <- 4L*((idx$from_year-INF_LAG_YEARS)-START_YEAR)+4L

# ---- period coding ------------------------------------------------------------
PERIOD_LEVELS <- sort(unique(idx$period_start))
N_PERIOD <- length(PERIOD_LEVELS)

# Cells: infection x sex x adult_entry x period
cells <- expand_grid(
  infected=0:1,
  sex=0:1,
  adult_entry=0:1,
  period_start=PERIOD_LEVELS
) %>%
  arrange(period_start,adult_entry,sex,infected) %>%
  mutate(cell=row_number())

period_contrast <- function(period_start){
  j <- match(period_start,PERIOD_LEVELS)
  z <- numeric(N_PERIOD-1L)
  if(j<N_PERIOD) z[j] <- 1 else z[] <- -1
  z
}

P <- 4L+(N_PERIOD-1L)
par_names <- c(
  "alpha","beta_inf","beta_sex","beta_adult",
  paste0("period_raw[",seq_len(N_PERIOD-1L),"]")
)

X <- matrix(0,nrow=nrow(cells),ncol=P,dimnames=list(NULL,par_names))
for(r in seq_len(nrow(cells))){
  X[r,1] <- 1
  X[r,2] <- cells$infected[r]
  X[r,3] <- cells$sex[r]
  X[r,4] <- cells$adult_entry[r]
  X[r,5:P] <- period_contrast(cells$period_start[r])
}

cell_key <- with(
  cells,
  paste(infected,sex,adult_entry,period_start,sep="|")
)

# ---- priors ------------------------------------------------------------------
PRIOR_MEAN <- c(
  alpha=qlogis(.05),
  beta_inf=0,
  beta_sex=0,
  beta_adult=0,
  rep(0,N_PERIOD-1L)
)
PRIOR_SD <- c(
  alpha=1.5,
  beta_inf=1.5,
  beta_sex=1.5,
  beta_adult=1.5,
  rep(1,N_PERIOD-1L)
)
names(PRIOR_MEAN) <- names(PRIOR_SD) <- par_names

# ---- paired histories ---------------------------------------------------------
pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS)
    pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}

cat("\n============================================================\n")
cat("V7a-M SENSITIVITY: PERIOD + ENTRY AGE\n")
cat("============================================================\n")
cat("Paired histories:",nrow(pair_index),"\n")
cat("Infection lag years:",INF_LAG_YEARS,"\n")
cat("Timing rule:",
    ifelse(INF_LAG_YEARS==0,
           "infected by Q4 of movement-origin year",
           "infected by Q4 of PREVIOUS year"),"\n")
cat("5-year periods:",paste(PERIOD_LEVELS,collapse=", "),"\n")
cat("Model parameters:",P,"\n")
cat("Importance proposals/history:",N_PROP,"\n")
cat("Retained posterior draws/history:",N_KEEP,"\n")

# ---- grouped counts -----------------------------------------------------------
n_mat <- matrix(0L,nrow=nrow(pair_index),ncol=nrow(cells))
y_mat <- matrix(0L,nrow=nrow(pair_index),ncol=nrow(cells))

for(pp in seq_len(nrow(pair_index))){
  md <- pair_index$movement_draw[pp]
  ic <- pair_index$infection_col[pp]

  st <- as.integer(mov$state_draws[md,])
  eligible <- !is.na(prev_col) & st[prev_col]==0L

  it <- as.integer(inf$infection_time[,ic])
  infected <- it[inf_row_interval]>0L &
              it[inf_row_interval]<=infection_cutoff

  key <- paste(
    as.integer(infected[eligible]),
    sex_interval[eligible],
    adult_interval[eligible],
    idx$period_start[eligible],
    sep="|"
  )
  cc <- match(key,cell_key)
  if(anyNA(cc)) stop("Failed to match one or more grouped cells.")

  n_mat[pp,] <- tabulate(cc,nbins=nrow(cells))
  y_mat[pp,] <- tabulate(cc[st[eligible]==1L],nbins=nrow(cells))

  if(pp%%100L==0L) cat("Built counts",pp,"/",nrow(pair_index),"\n")
}

# Transitions and outcomes must exactly reproduce original audit.
count_audit <- pair_index %>%
  transmute(
    pair_draw,
    transitions=rowSums(n_mat),
    infected_origins=rowSums(n_mat[,cells$infected==1L,drop=FALSE]),
    high_outcomes=rowSums(y_mat)
  ) %>%
  left_join(
    paired$audit %>%
      select(
        pair_draw,
        audit_transitions=v7a_R_origin_transitions,
        audit_infected=v7a_infected_origins,
        audit_high=v7a_high_outcomes
      ),
    by="pair_draw"
  )

if(any(count_audit$transitions!=count_audit$audit_transitions) ||
   any(count_audit$high_outcomes!=count_audit$audit_high))
  stop("Transition/high-outcome counts do not reproduce the Phase-2 audit.")

if(INF_LAG_YEARS==0L &&
   any(count_audit$infected_origins!=count_audit$audit_infected))
  stop("Lag-0 infected-origin counts do not reproduce Phase-2 audit.")

cat("Transition/outcome audit: PASS\n")
if(INF_LAG_YEARS==0L) cat("Infected-origin audit: PASS\n")

# ---- exact posterior / IS helpers --------------------------------------------
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
  g <- as.vector(crossprod(X,y-n*p))-
       (theta-PRIOR_MEAN)/(PRIOR_SD^2)
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
logsumexp_rows <- function(M){
  m <- apply(M,1,max)
  m+log(rowSums(exp(M-m)))
}

# ---- fit every paired history -------------------------------------------------
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
    n=n,y=y,
    method="BFGS",
    control=list(maxit=1000,reltol=1e-9)
  )
  if(opt$convergence!=0L){
    opt <- optim(
      par=PRIOR_MEAN,
      fn=nlp_one,
      gr=grad_nlp_one,
      n=n,y=y,
      method="BFGS",
      control=list(maxit=1500,reltol=1e-10)
    )
  }

  H <- hessian_one(opt$par,n)
  eg <- eigen(H,symmetric=TRUE)
  eg$values[eg$values<1e-8] <- 1e-8
  V <- eg$vectors%*%diag(1/eg$values,P)%*%t(eg$vectors)

  # Defensive mixture proposal.
  V1 <- V*(1.20^2)
  V2 <- V*(2.25^2)
  V3 <- V*(4.0^2)

  comp <- sample.int(3,N_PROP,replace=TRUE,prob=c(.85,.12,.03))
  prop <- matrix(NA_real_,N_PROP,P)
  if(any(comp==1L)) prop[comp==1L,] <- draw_mvn(sum(comp==1L),opt$par,V1)
  if(any(comp==2L)) prop[comp==2L,] <- draw_mvn(sum(comp==2L),opt$par,V2)
  if(any(comp==3L)) prop[comp==3L,] <- draw_mvn(sum(comp==3L),opt$par,V3)

  LQ <- cbind(
    log(.85)+logdmvn_many(prop,opt$par,V1),
    log(.12)+logdmvn_many(prop,opt$par,V2),
    log(.03)+logdmvn_many(prop,opt$par,V3)
  )
  logq <- logsumexp_rows(LQ)

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
    n_transitions=sum(n),
    n_infected=sum(n[cells$infected==1L]),
    n_high=sum(y),
    mode_beta_inf=opt$par[2],
    mode_beta_sex=opt$par[3],
    mode_beta_adult=opt$par[4],
    IS_ESS=is_ess,
    max_importance_weight=max(w),
    optim_code=opt$convergence
  )

  if(pp%%100L==0L)
    cat("Fitted pair",pp,"/",nrow(pair_index),"\n")
}

pair_diag <- bind_rows(pair_diag)
pooled <- as_tibble(pooled) %>%
  mutate(pair_draw=pooled_pair,.before=1)

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
  lapply(c("alpha","beta_inf","beta_sex","beta_adult"),function(nm)
    summ(pooled[[nm]]) %>% mutate(parameter=nm,.before=1))
)

derived_summary <- tibble(
  quantity=c("OR_infection","OR_male","OR_adult_entry"),
  median=c(
    median(exp(pooled$beta_inf)),
    median(exp(pooled$beta_sex)),
    median(exp(pooled$beta_adult))
  ),
  q025=c(
    quantile(exp(pooled$beta_inf),.025),
    quantile(exp(pooled$beta_sex),.025),
    quantile(exp(pooled$beta_adult),.025)
  ),
  q975=c(
    quantile(exp(pooled$beta_inf),.975),
    quantile(exp(pooled$beta_sex),.975),
    quantile(exp(pooled$beta_adult),.975)
  )
)

cat("\n============================================================\n")
cat("V7a-M PERIOD/ENTRY SENSITIVITY POSTERIOR\n")
cat("============================================================\n")
print(main_summary,n=Inf,width=Inf)
cat("\nDerived effects:\n")
print(derived_summary,n=Inf,width=Inf)

cat("\nPrimary infection effect:\n")
cat("beta_inf median:",median(pooled$beta_inf),"\n")
cat("95% CrI:",
    unname(quantile(pooled$beta_inf,.025)),"to",
    unname(quantile(pooled$beta_inf,.975)),"\n")
cat("P(beta_inf>0):",mean(pooled$beta_inf>0),"\n")
cat("OR median:",median(exp(pooled$beta_inf)),"\n")
cat("OR 95% CrI:",
    unname(quantile(exp(pooled$beta_inf),.025)),"to",
    unname(quantile(exp(pooled$beta_inf),.975)),"\n")

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

dir.create("results",showWarnings=FALSE,recursive=TRUE)
out_rds <- paste0(
  "results/V7aM_sensitivity_period_entry_lag",
  INF_LAG_YEARS,"_",RESULT_TAG,".rds"
)
out_csv <- paste0(
  "results/V7aM_sensitivity_period_entry_lag",
  INF_LAG_YEARS,"_",RESULT_TAG,"_summary.csv"
)

saveRDS(
  list(
    model="V7a-M sensitivity: period + adult-entry + infection lag",
    coefficient_draws=pooled,
    main_summary=main_summary,
    derived_summary=derived_summary,
    pair_diagnostics=pair_diag,
    pair_counts=list(n=n_mat,y=y_mat,cells=cells),
    periods=PERIOD_LEVELS,
    design=X,
    priors=list(mean=PRIOR_MEAN,sd=PRIOR_SD),
    settings=list(
      infection_lag_years=INF_LAG_YEARS,
      n_pairs=nrow(pair_index),
      n_importance_proposals=N_PROP,
      n_posterior_draws_per_pair=N_KEEP,
      period_effect="5-year categorical sum-to-zero",
      adult_entry="0=young-entry, 1=adult-entry",
      note="adult-entry is an entry-age category, not exact chronological age"
    )
  ),
  out_rds
)

bind_rows(
  main_summary %>%
    transmute(
      type="coefficient",name=parameter,
      median,q025,q975,probability_positive=P_gt_0
    ),
  derived_summary %>%
    transmute(
      type="derived",name=quantity,
      median,q025,q975,probability_positive=NA_real_
    )
) %>%
  write_csv(out_csv)

cat("\nSaved:",out_rds,"\n")
cat("Saved:",out_csv,"\n")
