# =============================================================================
# WOODCHESTER PHASE 2A: V7a-M
# PRIOR INFECTION -> SUBSEQUENT LOCAL-TO-HIGH MOVEMENT
#
# Modular/cut analysis:
#   Stage 1 movement histories are fixed posterior imputations from V6 FINAL50K.
#   Infection histories are fixed posterior imputations from all_tests_inferred.
#   Disease does NOT feed back into movement-state inference.
#
# For each paired latent-history dataset:
#
#   logit P(high_t = 1 | state_{t-1}=local)
#       = alpha + beta_inf * infected_origin + beta_sex * sex
#
# infected_origin = infected by Q4 of the current movement interval's origin year.
#
# Rather than running 1,500 separate MCMCs, the conditional model is reduced to
# four binomial strata (female/male x uninfected/infected). We then obtain an
# essentially exact 3-parameter Bayesian posterior using importance sampling
# around the posterior mode for EACH paired history, and combine equal numbers
# of posterior draws from each history.
#
# This preserves equal weight across latent-history imputations and does NOT
# treat the 1,500 reconstructions as additional biological data.
# =============================================================================

library(tidyverse)

# ---- files -------------------------------------------------------------------
PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
INF_FILE  <- "data/badger_infection_trajectories_all_tests_inferred.rds"

for(f in c(PAIR_FILE,MOVE_FILE,INF_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

paired <- readRDS(PAIR_FILE)
mov <- readRDS(MOVE_FILE)
inf <- readRDS(INF_FILE)

# ---- run controls -------------------------------------------------------------
# Defaults = final analysis. Environment variables allow a quick smoke test.
MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","1500"))
N_PROP <- as.integer(Sys.getenv("N_PROP","3000"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","100"))
SEED <- as.integer(Sys.getenv("SEED","7092028"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","FULL")

set.seed(SEED)

# ---- priors ------------------------------------------------------------------
# Weakly informative and intentionally independent of the Stage-1 posterior.
# Intercept prior centres baseline annual R->high probability around 5%.
PRIOR_MEAN <- c(alpha=qlogis(.05),beta_inf=0,beta_sex=0)
PRIOR_SD <- c(alpha=1.5,beta_inf=1.5,beta_sex=1.5)

# ---- input checks -------------------------------------------------------------
req_pair <- c(
  "pair_draw","movement_draw","movement_chain",
  "movement_retained_draw","infection_col","infection_draw"
)
if(!all(req_pair%in%names(paired$pair_index)))
  stop("pair_index missing: ",paste(setdiff(req_pair,names(paired$pair_index)),collapse=", "))

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
  stop("Movement states must be 0=local, 1=high.")

inf_ids <- trimws(as.character(inf$tattoo))
inf_row_interval <- match(idx$tattoo,inf_ids)
if(anyNA(inf_row_interval))
  stop("Some movement interval tattoos are missing from infection trajectories.")

# Previous movement-state interval within each badger.
prev_col <- rep(NA_integer_,nrow(idx))
split_rows <- split(seq_len(nrow(idx)),idx$model_i)
for(rr in split_rows){
  rr <- rr[order(idx$from_year[rr],idx$to_year[rr])]
  if(length(rr)>1L) prev_col[rr[-1L]] <- rr[-length(rr)]
}

sex_interval <- as.integer(mov$sex[idx$model_i])
if(any(!sex_interval%in%c(0L,1L)))
  stop("Sex must be coded 0=female, 1=male.")

q4_time <- 4L*(idx$from_year-START_YEAR)+4L

# ---- select paired imputations ------------------------------------------------
pair_index <- paired$pair_index %>%
  arrange(pair_draw)

if(MAX_PAIRS<1L) stop("MAX_PAIRS must be >=1.")
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))

# For smoke tests, spread selected pairs across the entire paired posterior.
if(MAX_PAIRS<nrow(pair_index)){
  pick_pair_rows <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick_pair_rows)!=MAX_PAIRS)
    pick_pair_rows <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick_pair_rows,,drop=FALSE]
}

cat("\n============================================================\n")
cat("WOODCHESTER V7a-M: INFECTION -> HIGH MOBILITY\n")
cat("============================================================\n")
cat("Paired histories used:",nrow(pair_index),"\n")
cat("Importance proposals / history:",N_PROP,"\n")
cat("Posterior draws retained / history:",N_KEEP,"\n")
cat("Total pooled posterior draws:",nrow(pair_index)*N_KEEP,"\n")
cat("Infection start year:",START_YEAR,"\n")
cat("Priors:\n")
print(tibble(parameter=names(PRIOR_MEAN),mean=PRIOR_MEAN,sd=PRIOR_SD))

# ---- build the four binomial strata for every paired history -----------------
# Stratum order:
# 1 = female, uninfected
# 2 = male,   uninfected
# 3 = female, infected
# 4 = male,   infected
strata <- tibble(
  stratum=1:4,
  sex=c(0L,1L,0L,1L),
  infected=c(0L,0L,1L,1L)
)

n_mat <- matrix(0L,nrow=nrow(pair_index),ncol=4)
y_mat <- matrix(0L,nrow=nrow(pair_index),ncol=4)

for(pp in seq_len(nrow(pair_index))){
  md <- pair_index$movement_draw[pp]
  ic <- pair_index$infection_col[pp]

  st <- as.integer(mov$state_draws[md,])
  eligible <- !is.na(prev_col) & st[prev_col]==0L

  it <- as.integer(inf$infection_time[,ic])
  infected <- it[inf_row_interval]>0L & it[inf_row_interval]<=q4_time

  y <- st[eligible]
  sx <- sex_interval[eligible]
  ii <- as.integer(infected[eligible])

  g <- 1L + sx + 2L*ii
  n_mat[pp,] <- tabulate(g,nbins=4)
  y_mat[pp,] <- tabulate(g[y==1L],nbins=4)

  if(pp%%100L==0L) cat("Built counts",pp,"/",nrow(pair_index),"\n")
}

colnames(n_mat) <- paste0("n_",c("F_U","M_U","F_I","M_I"))
colnames(y_mat) <- paste0("y_",c("F_U","M_U","F_I","M_I"))

count_audit <- pair_index %>%
  transmute(
    pair_draw,
    transitions=rowSums(n_mat),
    infected_origins=n_mat[,3]+n_mat[,4],
    high_outcomes=rowSums(y_mat)
  )

# Exact consistency check against the Phase-2 audit for the selected pair_draws.
audit_match <- paired$audit %>%
  select(
    pair_draw,
    audit_transitions=v7a_R_origin_transitions,
    audit_infected=v7a_infected_origins,
    audit_high=v7a_high_outcomes
  )

check <- count_audit %>%
  left_join(audit_match,by="pair_draw")

if(any(check$transitions!=check$audit_transitions) ||
   any(check$infected_origins!=check$audit_infected) ||
   any(check$high_outcomes!=check$audit_high))
  stop("V7a model counts do not reproduce the Phase-2 audit exactly.")

cat("Model-input counts reproduce Phase-2 audit: PASS\n")

# ---- exact grouped-binomial posterior ----------------------------------------
X <- cbind(
  alpha=1,
  beta_inf=strata$infected,
  beta_sex=strata$sex
)

log1pexp <- function(x)
  ifelse(x>0,x+log1p(exp(-x)),log1p(exp(x)))

logpost_one <- function(theta,n,y){
  eta <- as.vector(X%*%theta)
  ll <- sum(y*eta-n*log1pexp(eta))
  lp <- -0.5*sum(((theta-PRIOR_MEAN)/PRIOR_SD)^2)
  ll+lp
}

grad_nlp_one <- function(theta,n,y){
  eta <- as.vector(X%*%theta)
  p <- plogis(eta)
  g <- as.vector(crossprod(X,y-n*p))-(theta-PRIOR_MEAN)/(PRIOR_SD^2)
  -g
}

nlp_one <- function(theta,n,y) -logpost_one(theta,n,y)

hessian_one <- function(theta,n){
  eta <- as.vector(X%*%theta)
  p <- plogis(eta)
  w <- n*p*(1-p)
  crossprod(X,X*w)+diag(1/(PRIOR_SD^2),3)
}

logpost_many <- function(theta_mat,n,y){
  # theta_mat = proposals x 3
  eta <- theta_mat%*%t(X)  # proposals x 4
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

# ---- conditional posterior for every paired history --------------------------
pooled <- matrix(
  NA_real_,
  nrow=nrow(pair_index)*N_KEEP,
  ncol=3,
  dimnames=list(NULL,c("alpha","beta_inf","beta_sex"))
)
pooled_pair <- integer(nrow(pooled))

pair_diag <- vector("list",nrow(pair_index))

start_row <- 1L

for(pp in seq_len(nrow(pair_index))){
  n <- as.numeric(n_mat[pp,])
  y <- as.numeric(y_mat[pp,])

  opt <- optim(
    par=PRIOR_MEAN,
    fn=nlp_one,
    gr=grad_nlp_one,
    n=n,
    y=y,
    method="BFGS",
    control=list(maxit=500,reltol=1e-10)
  )

  if(opt$convergence!=0L)
    warning("optim convergence code ",opt$convergence," for paired history ",pp)

  H <- hessian_one(opt$par,n)

  # Robust inverse Hessian.
  eig <- eigen(H,symmetric=TRUE)
  eig$values[eig$values<1e-8] <- 1e-8
  V <- eig$vectors%*%diag(1/eig$values,3)%*%t(eig$vectors)

  # Inflate Laplace covariance to ensure proposal tails comfortably cover target.
  PROP_SCALE <- 1.5
  QV <- V*(PROP_SCALE^2)

  prop <- draw_mvn(N_PROP,opt$par,QV)
  logw <- logpost_many(prop,n,y)-logdmvn_many(prop,opt$par,QV)
  logw <- logw-max(logw)
  w <- exp(logw)
  w <- w/sum(w)

  is_ess <- 1/sum(w^2)
  max_w <- max(w)

  keep <- sample.int(N_PROP,size=N_KEEP,replace=TRUE,prob=w)
  rows <- start_row:(start_row+N_KEEP-1L)
  pooled[rows,] <- prop[keep,,drop=FALSE]
  pooled_pair[rows] <- pair_index$pair_draw[pp]
  start_row <- start_row+N_KEEP

  pair_diag[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    movement_draw=pair_index$movement_draw[pp],
    infection_draw=pair_index$infection_draw[pp],
    n_transitions=sum(n),
    n_infected=n[3]+n[4],
    n_high=sum(y),
    mode_alpha=opt$par[1],
    mode_beta_inf=opt$par[2],
    mode_beta_sex=opt$par[3],
    IS_ESS=is_ess,
    max_importance_weight=max_w,
    optim_code=opt$convergence
  )

  if(pp%%100L==0L)
    cat("Fitted paired history",pp,"/",nrow(pair_index),"\n")
}

pair_diag <- bind_rows(pair_diag)
pooled <- as_tibble(pooled) %>%
  mutate(pair_draw=pooled_pair,.before=1)

# ---- pooled modular posterior ------------------------------------------------
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

coef_summary <- bind_rows(
  lapply(c("alpha","beta_inf","beta_sex"),function(nm)
    summ(pooled[[nm]]) %>% mutate(parameter=nm,.before=1))
)

effect_draws <- pooled %>%
  transmute(
    pair_draw,
    alpha,beta_inf,beta_sex,
    OR_infection=exp(beta_inf),
    OR_male=exp(beta_sex),
    p_F_uninfected=plogis(alpha),
    p_F_infected=plogis(alpha+beta_inf),
    p_M_uninfected=plogis(alpha+beta_sex),
    p_M_infected=plogis(alpha+beta_inf+beta_sex),
    RD_F=p_F_infected-p_F_uninfected,
    RD_M=p_M_infected-p_M_uninfected
  )

or_inf <- effect_draws$OR_infection
or_sex <- effect_draws$OR_male

derived_summary <- tibble(
  quantity=c(
    "OR_infection","OR_male",
    "p_F_uninfected","p_F_infected",
    "p_M_uninfected","p_M_infected",
    "risk_difference_F","risk_difference_M"
  ),
  median=c(
    median(or_inf),median(or_sex),
    median(effect_draws$p_F_uninfected),median(effect_draws$p_F_infected),
    median(effect_draws$p_M_uninfected),median(effect_draws$p_M_infected),
    median(effect_draws$RD_F),median(effect_draws$RD_M)
  ),
  q025=c(
    quantile(or_inf,.025),quantile(or_sex,.025),
    quantile(effect_draws$p_F_uninfected,.025),quantile(effect_draws$p_F_infected,.025),
    quantile(effect_draws$p_M_uninfected,.025),quantile(effect_draws$p_M_infected,.025),
    quantile(effect_draws$RD_F,.025),quantile(effect_draws$RD_M,.025)
  ),
  q975=c(
    quantile(or_inf,.975),quantile(or_sex,.975),
    quantile(effect_draws$p_F_uninfected,.975),quantile(effect_draws$p_F_infected,.975),
    quantile(effect_draws$p_M_uninfected,.975),quantile(effect_draws$p_M_infected,.975),
    quantile(effect_draws$RD_F,.975),quantile(effect_draws$RD_M,.975)
  )
)

cat("\n============================================================\n")
cat("V7a-M POOLED MODULAR POSTERIOR\n")
cat("============================================================\n")
print(coef_summary,n=Inf,width=Inf)

cat("\nDerived effects:\n")
print(derived_summary,n=Inf,width=Inf)

cat("\nPrimary infection effect:\n")
cat("  beta_inf median:",median(pooled$beta_inf),"\n")
cat("  95% CrI:",
    unname(quantile(pooled$beta_inf,.025)),"to",
    unname(quantile(pooled$beta_inf,.975)),"\n")
cat("  P(beta_inf > 0):",mean(pooled$beta_inf>0),"\n")
cat("  infection OR median:",median(or_inf),"\n")
cat("  OR 95% CrI:",
    unname(quantile(or_inf,.025)),"to",
    unname(quantile(or_inf,.975)),"\n")

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

out_rds <- paste0("results/V7aM_infection_to_movement_",RESULT_TAG,".rds")
out_csv <- paste0("results/V7aM_infection_to_movement_",RESULT_TAG,"_summary.csv")

saveRDS(
  list(
    model="V7a-M modular infection -> subsequent high mobility",
    coefficient_draws=pooled,
    effect_draws=effect_draws,
    coefficient_summary=coef_summary,
    derived_summary=derived_summary,
    pair_diagnostics=pair_diag,
    pair_counts=bind_cols(pair_index,n=as_tibble(n_mat),y=as_tibble(y_mat)),
    priors=list(mean=PRIOR_MEAN,sd=PRIOR_SD),
    settings=list(
      n_pairs=nrow(pair_index),
      n_importance_proposals=N_PROP,
      n_posterior_draws_per_pair=N_KEEP,
      seed=SEED,
      state_definition="previous movement state local; outcome=current state high",
      infection_definition="infected by Q4 of current movement interval origin year",
      pooling="equal posterior draws per paired latent-history dataset",
      approximation="importance sampling using inflated Laplace MVN proposal"
    )
  ),
  out_rds
)

bind_rows(
  coef_summary %>%
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
