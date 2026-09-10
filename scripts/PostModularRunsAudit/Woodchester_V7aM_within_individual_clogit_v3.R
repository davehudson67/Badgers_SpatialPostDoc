# =============================================================================
# WOODCHESTER V7a-M WITHIN-INDIVIDUAL SENSITIVITY v3
#
# Fixes v2 warning handling:
# - warnings from clogit are captured with withCallingHandlers()
# - muffleWarning is invoked only where that restart exists
# - warning text is retained in diagnostics
# - progress checkpoint is saved every 100 paired histories
#
# QUESTION
# --------
# Among the same badger's eligible local-origin transitions, is a local->high
# transition more likely after infection than before infection?
#
# Individual fixed effects are conditioned out with conditional logistic
# regression. Stable individual characteristics cannot confound beta_inf.
#
# Historical calendar time is adjusted with a fixed 5-df natural spline.
#
# sex/adult-entry are not included because they are constant within individual
# and therefore disappear under individual fixed effects.
# =============================================================================

library(tidyverse)
library(survival)
library(splines)

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
RESULT_TAG <- Sys.getenv("RESULT_TAG","WITHIN_V3")

if(!INF_LAG_YEARS%in%c(0L,1L))
  stop("INF_LAG_YEARS must be 0 or 1.")

set.seed(SEED)

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
    to_year=as.integer(to_year)
  )

if(ncol(mov$state_draws)!=nrow(idx))
  stop("Movement state matrix does not match interval index.")

inf_ids <- trimws(as.character(inf$tattoo))
inf_row_interval <- match(idx$tattoo,inf_ids)
if(anyNA(inf_row_interval))
  stop("Some movement badgers are absent from infection trajectories.")

# Previous movement interval within badger.
prev_col <- rep(NA_integer_,nrow(idx))
split_rows <- split(seq_len(nrow(idx)),idx$model_i)
for(rr in split_rows){
  rr <- rr[order(idx$from_year[rr],idx$to_year[rr])]
  if(length(rr)>1L) prev_col[rr[-1L]] <- rr[-length(rr)]
}

# Infection precedence:
# lag 0 = infected by Q4 of movement-origin year
# lag 1 = infected by Q4 of previous year
infection_cutoff <- 4L*((idx$from_year-INF_LAG_YEARS)-START_YEAR)+4L

# One fixed calendar-time basis across all paired latent histories.
YB <- splines::ns(
  idx$from_year,
  df=5,
  Boundary.knots=range(idx$from_year,na.rm=TRUE)
)
colnames(YB) <- paste0("year_s",seq_len(ncol(YB)))

pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))

if(MAX_PAIRS<1L) stop("MAX_PAIRS must be >=1.")

if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS)
    pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}

form <- stats::as.formula(
  paste(
    "movement_state ~ infected_origin +",
    paste(colnames(YB),collapse=" + "),
    "+ strata(tattoo)"
  )
)

dir.create("results",showWarnings=FALSE,recursive=TRUE)

CHECKPOINT_FILE <- paste0(
  "results/V7aM_within_v3_checkpoint_lag",
  INF_LAG_YEARS,"_",RESULT_TAG,".rds"
)

cat("\n============================================================\n")
cat("V7a-M WITHIN-INDIVIDUAL SENSITIVITY v3\n")
cat("============================================================\n")
cat("Paired histories:",nrow(pair_index),"\n")
cat("Infection lag years:",INF_LAG_YEARS,"\n")
cat("Time adjustment: natural spline, df=5\n")
cat("Individual fixed effects: conditional logistic strata(tattoo)\n\n")

coef_draws <- vector("list",nrow(pair_index))
fit_diag <- vector("list",nrow(pair_index))

for(pp in seq_len(nrow(pair_index))){
  md <- pair_index$movement_draw[pp]
  ic <- pair_index$infection_col[pp]

  st <- as.integer(mov$state_draws[md,])

  # V7a is specifically initiation of high mobility from previous local state.
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
    bind_cols(
      as_tibble(
        YB[rr,,drop=FALSE],
        .name_repair="minimal"
      )
    )

  id_info <- d %>%
    group_by(tattoo) %>%
    summarise(
      n=n(),
      n_high=sum(movement_state),
      outcome_var=n_distinct(movement_state),
      exposure_var=n_distinct(infected_origin),
      .groups="drop"
    )

  outcome_ids <- id_info %>%
    filter(outcome_var>1L) %>%
    pull(tattoo)

  exposure_switch_ids <- id_info %>%
    filter(outcome_var>1L,exposure_var>1L) %>%
    pull(tattoo)

  d_fit <- d %>%
    filter(tattoo%in%outcome_ids)

  if(pp==1L){
    cat("FIRST-PAIR INFORMATION AUDIT\n")
    cat("Eligible local-origin rows:",nrow(d),"\n")
    cat("Badgers represented:",n_distinct(d$tattoo),"\n")
    cat("Outcome-informative badgers:",length(outcome_ids),"\n")
    cat("Outcome-informative badgers that switch infection status:",
        length(exposure_switch_ids),"\n")
    cat("Rows retained for conditional logistic fit:",nrow(d_fit),"\n\n")
  }

  if(length(outcome_ids)<2L || length(exposure_switch_ids)<1L){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_rows=nrow(d),
      n_fit_rows=nrow(d_fit),
      n_badgers=n_distinct(d$tattoo),
      n_outcome_informative=length(outcome_ids),
      n_exposure_switchers=length(exposure_switch_ids),
      beta_inf=NA_real_,
      se_inf=NA_real_,
      fit_ok=FALSE,
      warning_count=0L,
      warning_message="",
      message="insufficient within-individual outcome/exposure variation"
    )
    next
  }

  warning_messages <- character(0)

  fit <- tryCatch(
    withCallingHandlers(
      survival::clogit(
        form,
        data=d_fit,
        method="efron",
        control=survival::coxph.control(
          iter.max=100,
          eps=1e-9
        )
      ),
      warning=function(w){
        warning_messages <<- c(
          warning_messages,
          conditionMessage(w)
        )
        invokeRestart("muffleWarning")
      }
    ),
    error=function(e)e
  )

  warning_text <- paste(unique(warning_messages),collapse=" | ")

  if(inherits(fit,"error")){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_rows=nrow(d),
      n_fit_rows=nrow(d_fit),
      n_badgers=n_distinct(d$tattoo),
      n_outcome_informative=length(outcome_ids),
      n_exposure_switchers=length(exposure_switch_ids),
      beta_inf=NA_real_,
      se_inf=NA_real_,
      fit_ok=FALSE,
      warning_count=length(warning_messages),
      warning_message=warning_text,
      message=conditionMessage(fit)
    )
    next
  }

  cf <- coef(fit)
  vv <- tryCatch(vcov(fit),error=function(e)NULL)

  if(is.null(vv) ||
     !"infected_origin"%in%names(cf) ||
     !is.finite(cf["infected_origin"]) ||
     !"infected_origin"%in%rownames(vv) ||
     !is.finite(vv["infected_origin","infected_origin"]) ||
     vv["infected_origin","infected_origin"]<=0){

    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_rows=nrow(d),
      n_fit_rows=nrow(d_fit),
      n_badgers=n_distinct(d$tattoo),
      n_outcome_informative=length(outcome_ids),
      n_exposure_switchers=length(exposure_switch_ids),
      beta_inf=if("infected_origin"%in%names(cf))
        unname(cf["infected_origin"]) else NA_real_,
      se_inf=NA_real_,
      fit_ok=FALSE,
      warning_count=length(warning_messages),
      warning_message=warning_text,
      message="infection coefficient/variance not estimable"
    )
    next
  }

  b <- unname(cf["infected_origin"])
  se <- sqrt(unname(vv["infected_origin","infected_origin"]))

  draws <- rnorm(N_KEEP,b,se)

  coef_draws[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    beta_inf=draws
  )

  fit_diag[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    n_rows=nrow(d),
    n_fit_rows=nrow(d_fit),
    n_badgers=n_distinct(d$tattoo),
    n_outcome_informative=length(outcome_ids),
    n_exposure_switchers=length(exposure_switch_ids),
    beta_inf=b,
    se_inf=se,
    fit_ok=TRUE,
    warning_count=length(warning_messages),
    warning_message=warning_text,
    message=""
  )

  if(pp%%100L==0L){
    cat("Processed pair",pp,"/",nrow(pair_index),"\n")

    # Progress checkpoint. Safe to overwrite.
    saveRDS(
      list(
        completed_pair=pp,
        coef_draws=coef_draws[seq_len(pp)],
        fit_diag=fit_diag[seq_len(pp)],
        settings=list(
          infection_lag_years=INF_LAG_YEARS,
          result_tag=RESULT_TAG
        )
      ),
      CHECKPOINT_FILE
    )
  }
}

fit_diag <- bind_rows(fit_diag)
pooled <- bind_rows(coef_draws)

cat("\n============================================================\n")
cat("FIT / INFORMATION AUDIT\n")
cat("============================================================\n")

print(
  fit_diag %>%
    summarise(
      pairs=n(),
      fitted=sum(fit_ok),
      failed=sum(!fit_ok),
      pairs_with_warnings=sum(warning_count>0),
      median_rows=median(n_rows),
      median_fit_rows=median(n_fit_rows),
      median_badgers=median(n_badgers),
      median_outcome_informative=median(n_outcome_informative),
      median_exposure_switchers=median(n_exposure_switchers),
      q025_exposure_switchers=quantile(n_exposure_switchers,.025),
      q975_exposure_switchers=quantile(n_exposure_switchers,.975),
      min_exposure_switchers=min(n_exposure_switchers),
      max_exposure_switchers=max(n_exposure_switchers)
    ),
  width=Inf
)

if(any(fit_diag$warning_count>0)){
  cat("\nMost common warnings:\n")
  print(
    fit_diag %>%
      filter(warning_count>0) %>%
      count(warning_message,sort=TRUE),
    n=20,width=Inf
  )
}

if(any(!fit_diag$fit_ok)){
  cat("\nMost common failure messages:\n")
  print(
    fit_diag %>%
      filter(!fit_ok) %>%
      count(message,sort=TRUE),
    n=20,width=Inf
  )
}

if(!nrow(pooled)){
  stop(
    "No within-individual fits were estimable. ",
    "See printed information/failure audit above."
  )
}

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

out_rds <- paste0(
  "results/V7aM_within_individual_v3_lag",
  INF_LAG_YEARS,"_",RESULT_TAG,".rds"
)
out_csv <- paste0(
  "results/V7aM_within_individual_v3_lag",
  INF_LAG_YEARS,"_",RESULT_TAG,"_summary.csv"
)

saveRDS(
  list(
    model="V7a-M within-individual conditional logistic sensitivity v3",
    coefficient_draws=pooled,
    summary=summary_beta,
    fit_diagnostics=fit_diag,
    settings=list(
      infection_lag_years=INF_LAG_YEARS,
      year_adjustment="natural spline df=5",
      individual_effect="conditioned out with clogit strata(tattoo)",
      input_filter="only outcome-informative individual strata retained",
      method="Efron conditional logistic likelihood; asymptotic normal beta_inf draws",
      note="sex and adult-entry are conditioned out because constant within individual"
    )
  ),
  out_rds
)

write_csv(summary_beta,out_csv)

cat("\nSaved:",out_rds,"\n")
cat("Saved:",out_csv,"\n")
cat("Checkpoint:",CHECKPOINT_FILE,"\n")
