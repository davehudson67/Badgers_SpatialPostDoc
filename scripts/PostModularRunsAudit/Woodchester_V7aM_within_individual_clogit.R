# =============================================================================
# WOODCHESTER V7a-M WITHIN-INDIVIDUAL SENSITIVITY
#
# Purpose:
#   Ask whether the SAME badger is more likely to make a local->high transition
#   after infection than before infection.
#
# Individual fixed effects are removed by conditional logistic regression.
# Stable individual differences (intrinsic mobility, genetics, long-term home
# range, etc.) therefore cannot confound beta_inf.
#
# Historical time is adjusted using a fixed 5-df natural spline of origin year.
#
# NOTE:
#   sex and adult-entry are constant within badger and therefore cannot be
#   estimated in this fixed-effect analysis. That is intentional.
#
# This is a sensitivity analysis, not a replacement for the primary Bayesian
# population-level V7a-M.
# =============================================================================

library(tidyverse)
if(!requireNamespace("survival",quietly=TRUE))
  stop("Package 'survival' is required.")
if(!requireNamespace("splines",quietly=TRUE))
  stop("Package 'splines' is required.")

PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
INF_FILE  <- "data/badger_infection_trajectories_all_tests_inferred.rds"

for(f in c(PAIR_FILE,MOVE_FILE,INF_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

paired <- readRDS(PAIR_FILE)
mov <- readRDS(MOVE_FILE)
inf <- readRDS(INF_FILE)

MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","1500"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","100"))
INF_LAG_YEARS <- as.integer(Sys.getenv("INF_LAG_YEARS","0"))
SEED <- as.integer(Sys.getenv("SEED","7092032"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","WITHIN")

if(!INF_LAG_YEARS%in%c(0L,1L))
  stop("INF_LAG_YEARS must be 0 or 1.")
set.seed(SEED)

START_YEAR <- as.integer(inf$start_year)

idx <- mov$interval_index %>%
  mutate(
    interval_col=row_number(),
    model_i=as.integer(model_i),
    tattoo=trimws(as.character(tattoo)),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year)
  )

inf_ids <- trimws(as.character(inf$tattoo))
inf_row_interval <- match(idx$tattoo,inf_ids)
if(anyNA(inf_row_interval))
  stop("Some movement badgers are absent from infection trajectories.")

# Previous state.
prev_col <- rep(NA_integer_,nrow(idx))
split_rows <- split(seq_len(nrow(idx)),idx$model_i)
for(rr in split_rows){
  rr <- rr[order(idx$from_year[rr],idx$to_year[rr])]
  if(length(rr)>1L) prev_col[rr[-1L]] <- rr[-length(rr)]
}

infection_cutoff <- 4L*((idx$from_year-INF_LAG_YEARS)-START_YEAR)+4L

# Natural-spline basis is fixed once, so all imputations use the same time model.
YB <- splines::ns(
  idx$from_year,
  df=5,
  Boundary.knots=range(idx$from_year,na.rm=TRUE)
)
colnames(YB) <- paste0("year_s",seq_len(ncol(YB)))

pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS)
    pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}

cat("\n============================================================\n")
cat("V7a-M WITHIN-INDIVIDUAL SENSITIVITY\n")
cat("============================================================\n")
cat("Paired histories:",nrow(pair_index),"\n")
cat("Infection lag years:",INF_LAG_YEARS,"\n")
cat("Time adjustment: natural spline, df=5\n")
cat("Conditional logistic strata: individual badger\n")

coef_draws <- vector("list",nrow(pair_index))
fit_diag <- vector("list",nrow(pair_index))

form <- as.formula(
  paste(
    "movement_state ~ infected_origin +",
    paste(colnames(YB),collapse=" + "),
    "+ strata(tattoo)"
  )
)

for(pp in seq_len(nrow(pair_index))){
  md <- pair_index$movement_draw[pp]
  ic <- pair_index$infection_col[pp]

  st <- as.integer(mov$state_draws[md,])
  eligible <- !is.na(prev_col) & st[prev_col]==0L

  it <- as.integer(inf$infection_time[,ic])
  infected <- as.integer(
    it[inf_row_interval]>0L &
    it[inf_row_interval]<=infection_cutoff
  )

  rr <- which(eligible)

  d <- tibble(
    movement_state=st[rr],
    infected_origin=infected[rr],
    tattoo=idx$tattoo[rr]
  ) %>%
    bind_cols(as_tibble(YB[rr,,drop=FALSE],.name_repair="minimal"))

  # Audit informative badgers.
  by_id <- d %>%
    group_by(tattoo) %>%
    summarise(
      n=n(),
      n_high=sum(movement_state),
      infection_var=n_distinct(infected_origin),
      .groups="drop"
    )

  n_outcome_informative <- sum(by_id$n_high>0 & by_id$n_high<by_id$n)
  n_exposure_switchers <- sum(
    by_id$n_high>0 & by_id$n_high<by_id$n & by_id$infection_var>1
  )

  fit <- tryCatch(
    survival::clogit(
      form,
      data=d,
      method="efron",
      control=survival::coxph.control(iter.max=50,eps=1e-9)
    ),
    error=function(e)e
  )

  if(inherits(fit,"error")){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_rows=nrow(d),
      n_badgers=n_distinct(d$tattoo),
      n_outcome_informative=n_outcome_informative,
      n_exposure_switchers=n_exposure_switchers,
      beta_inf=NA_real_,
      se_inf=NA_real_,
      fit_ok=FALSE,
      message=conditionMessage(fit)
    )
    next
  }

  cf <- coef(fit)
  vv <- vcov(fit)

  if(!"infected_origin"%in%names(cf) ||
     !is.finite(cf["infected_origin"]) ||
     !is.finite(vv["infected_origin","infected_origin"])){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_rows=nrow(d),
      n_badgers=n_distinct(d$tattoo),
      n_outcome_informative=n_outcome_informative,
      n_exposure_switchers=n_exposure_switchers,
      beta_inf=NA_real_,
      se_inf=NA_real_,
      fit_ok=FALSE,
      message="infection coefficient not estimable"
    )
    next
  }

  b <- unname(cf["infected_origin"])
  se <- sqrt(unname(vv["infected_origin","infected_origin"]))

  # Marginal asymptotic conditional-likelihood draw for beta_inf only.
  draws <- rnorm(N_KEEP,b,se)

  coef_draws[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    beta_inf=draws
  )

  fit_diag[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    n_rows=nrow(d),
    n_badgers=n_distinct(d$tattoo),
    n_outcome_informative=n_outcome_informative,
    n_exposure_switchers=n_exposure_switchers,
    beta_inf=b,
    se_inf=se,
    fit_ok=TRUE,
    message=""
  )

  if(pp%%100L==0L)
    cat("Fitted pair",pp,"/",nrow(pair_index),"\n")
}

fit_diag <- bind_rows(fit_diag)
pooled <- bind_rows(coef_draws)

if(!nrow(pooled))
  stop("No within-individual fits were estimable.")

summary_beta <- tibble(
  mean=mean(pooled$beta_inf),
  sd=sd(pooled$beta_inf),
  median=median(pooled$beta_inf),
  q025=unname(quantile(pooled$beta_inf,.025)),
  q975=unname(quantile(pooled$beta_inf,.975)),
  P_gt_0=mean(pooled$beta_inf>0),
  OR_median=median(exp(pooled$beta_inf)),
  OR_q025=unname(quantile(exp(pooled$beta_inf),.025)),
  OR_q975=unname(quantile(exp(pooled$beta_inf),.975))
)

cat("\n============================================================\n")
cat("WITHIN-INDIVIDUAL INFECTION EFFECT\n")
cat("============================================================\n")
print(summary_beta,width=Inf)

cat("\nFit/information audit:\n")
print(
  fit_diag %>%
    summarise(
      pairs=n(),
      fitted=sum(fit_ok),
      failed=sum(!fit_ok),
      median_rows=median(n_rows),
      median_badgers=median(n_badgers),
      median_outcome_informative=median(n_outcome_informative),
      median_exposure_switchers=median(n_exposure_switchers),
      min_exposure_switchers=min(n_exposure_switchers),
      max_exposure_switchers=max(n_exposure_switchers)
    ),
  width=Inf
)

dir.create("results",showWarnings=FALSE,recursive=TRUE)
out_rds <- paste0(
  "results/V7aM_within_individual_lag",
  INF_LAG_YEARS,"_",RESULT_TAG,".rds"
)
out_csv <- paste0(
  "results/V7aM_within_individual_lag",
  INF_LAG_YEARS,"_",RESULT_TAG,"_summary.csv"
)

saveRDS(
  list(
    model="V7a-M within-individual conditional logistic sensitivity",
    coefficient_draws=pooled,
    summary=summary_beta,
    fit_diagnostics=fit_diag,
    settings=list(
      infection_lag_years=INF_LAG_YEARS,
      year_adjustment="natural spline df=5",
      individual_effect="conditioned out with clogit strata(tattoo)",
      method="Efron conditional logistic likelihood; asymptotic normal beta_inf draws",
      note="sex and adult-entry cannot be estimated because they are constant within individual"
    )
  ),
  out_rds
)
write_csv(summary_beta,out_csv)

cat("\nSaved:",out_rds,"\n")
cat("Saved:",out_csv,"\n")
