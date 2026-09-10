# =============================================================================
# WOODCHESTER V7b-M TIME-STRATIFIED WITHIN-INDIVIDUAL SENSITIVITY
#
# Motivation
# ----------
# Ordinary individual fixed-effect clogit works for movement + quarter, but
# absolute calendar year/period cannot be estimated cleanly because infection
# acquisition is necessarily the final susceptible risk occasion for an event
# badger. That creates monotonic-time separation.
#
# Solution
# --------
# Match each event to that SAME badger's susceptible control occasions within
# the SAME calendar block, then condition on:
#
#     strata(tattoo x calendar_block)
#
# This is a time-stratified case-crossover design. Broad calendar period is
# controlled by design rather than estimated as a coefficient.
#
# Model:
#   infection_event ~ movement_state + quarter +
#                     strata(tattoo_calendar_block)
#
# BLOCK_YEARS:
#   5  = preferred, tighter calendar matching
#   10 = robustness, more within-stratum information
#
# The movement coefficient is identified only by event strata containing both
# local and high-mobility risk occasions.
# =============================================================================

library(tidyverse)
library(survival)

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
BLOCK_YEARS <- as.integer(Sys.getenv("BLOCK_YEARS","5"))
SEED <- as.integer(Sys.getenv("SEED","7092040"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","TIMESTRAT")

if(!BLOCK_YEARS%in%c(5L,10L))
  stop("BLOCK_YEARS must be 5 or 10.")

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

if(ncol(mov$state_draws)!=nrow(idx))
  stop("Movement state matrix does not match interval index.")

inf_ids <- trimws(as.character(inf$tattoo))
if(any(!unique(idx$tattoo)%in%inf_ids))
  stop("Some movement badgers are absent from infection trajectories.")

if(is.null(paired$live_bounds) ||
   !all(c("tattoo","last_live_time")%in%names(paired$live_bounds)))
  stop("paired object lacks live_bounds.")

last_live <- setNames(
  as.integer(paired$live_bounds$last_live_time),
  trimws(as.character(paired$live_bounds$tattoo))
)

# Mirror primary V7b-M: exclude last movement interval.
eligible_move <- idx %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last)

pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))

if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS)
    pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}

make_v7b <- function(move_draw,inf_col){
  st <- as.integer(mov$state_draws[move_draw,])
  it <- as.integer(inf$infection_time[,inf_col])
  names(it) <- inf_ids

  out <- vector("list",nrow(eligible_move)*2L)
  oo <- 0L

  for(rr in seq_len(nrow(eligible_move))){
    row <- eligible_move[rr,]
    tattoo <- row$tattoo
    infection_time <- it[tattoo]
    move_end_year <- row$to_year
    move_end_q4 <- 4L*(move_end_year-START_YEAR)+4L

    # susceptible at Q4(t)
    if(!(infection_time==0L || infection_time>move_end_q4)) next

    outcome_year <- move_end_year+1L
    llt <- last_live[tattoo]

    for(q in 1:4){
      ot <- 4L*(outcome_year-START_YEAR)+q

      if(ot>llt) break
      if(infection_time>0L && infection_time<ot) break

      event <- as.integer(infection_time>0L && infection_time==ot)

      oo <- oo+1L
      out[[oo]] <- tibble(
        tattoo=tattoo,
        movement_state=st[row$interval_col],
        outcome_year=as.integer(outcome_year),
        outcome_quarter=as.integer(q),
        infection_event=event
      )

      if(event==1L) break
    }
  }

  if(oo==0L) return(tibble())

  bind_rows(out[seq_len(oo)]) %>%
    mutate(
      calendar_block=
        floor(outcome_year/BLOCK_YEARS)*BLOCK_YEARS,
      stratum=paste(tattoo,calendar_block,sep="__"),
      quarter=factor(outcome_quarter)
    )
}

form <- infection_event ~ movement_state + quarter + strata(stratum)

cat("\n============================================================\n")
cat("V7b-M TIME-STRATIFIED WITHIN-INDIVIDUAL SENSITIVITY\n")
cat("============================================================\n")
cat("Paired histories:",nrow(pair_index),"\n")
cat("Risk timing: movement t -> acquisition Q1-Q4 t+1\n")
cat("Calendar block width:",BLOCK_YEARS,"years\n")
cat("Conditional strata: badger x calendar block\n")
cat("Additional adjustment: quarter\n\n")

coef_draws <- vector("list",nrow(pair_index))
fit_diag <- vector("list",nrow(pair_index))

for(pp in seq_len(nrow(pair_index))){
  d <- make_v7b(
    pair_index$movement_draw[pp],
    pair_index$infection_col[pp]
  )

  aud <- paired$audit %>%
    filter(pair_draw==pair_index$pair_draw[pp])

  if(nrow(d)!=aud$v7b_risk_quarters ||
     sum(d$infection_event)!=aud$v7b_events)
    stop("V7b risk/event audit mismatch for pair_draw ",
         pair_index$pair_draw[pp])

  s_info <- d %>%
    group_by(stratum) %>%
    summarise(
      tattoo=first(tattoo),
      calendar_block=first(calendar_block),
      n=n(),
      events=sum(infection_event),
      outcome_var=n_distinct(infection_event),
      exposure_var=n_distinct(movement_state),
      .groups="drop"
    )

  event_strata <- s_info %>%
    filter(events==1L,n>=2L) %>%
    pull(stratum)

  exposure_switch_event_strata <- s_info %>%
    filter(events==1L,n>=2L,exposure_var>1L) %>%
    pull(stratum)

  d_fit <- d %>%
    filter(stratum%in%event_strata)

  if(pp==1L){
    cat("FIRST-PAIR INFORMATION AUDIT\n")
    cat("All risk quarters:",nrow(d),"\n")
    cat("All infection events:",sum(d$infection_event),"\n")
    cat("Event strata with >=1 control:",length(event_strata),"\n")
    cat("Event strata switching movement exposure:",
        length(exposure_switch_event_strata),"\n")
    cat("Rows retained for conditional fit:",nrow(d_fit),"\n")
    cat("Retained events:",sum(d_fit$infection_event),"\n\n")
  }

  if(length(exposure_switch_event_strata)<1L){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_risk=nrow(d),
      n_events=sum(d$infection_event),
      n_event_strata=length(event_strata),
      n_exposure_switch_event_strata=
        length(exposure_switch_event_strata),
      n_fit_rows=nrow(d_fit),
      beta_move=NA_real_,
      se_move=NA_real_,
      fit_ok=FALSE,
      warning_count=0L,
      warning_message="",
      message="no movement-switching event strata"
    )
    next
  }

  warns <- character(0)

  fit <- tryCatch(
    withCallingHandlers(
      survival::clogit(
        form,
        data=d_fit,
        method="efron",
        control=survival::coxph.control(iter.max=100,eps=1e-9)
      ),
      warning=function(w){
        warns <<- c(warns,conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error=function(e)e
  )

  warn_text <- paste(unique(warns),collapse=" | ")

  if(inherits(fit,"error")){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_risk=nrow(d),
      n_events=sum(d$infection_event),
      n_event_strata=length(event_strata),
      n_exposure_switch_event_strata=
        length(exposure_switch_event_strata),
      n_fit_rows=nrow(d_fit),
      beta_move=NA_real_,
      se_move=NA_real_,
      fit_ok=FALSE,
      warning_count=length(warns),
      warning_message=warn_text,
      message=conditionMessage(fit)
    )
    next
  }

  cf <- coef(fit)
  vv <- tryCatch(vcov(fit),error=function(e)NULL)

  ok <- !is.null(vv) &&
    "movement_state"%in%names(cf) &&
    is.finite(cf["movement_state"]) &&
    "movement_state"%in%rownames(vv) &&
    is.finite(vv["movement_state","movement_state"]) &&
    vv["movement_state","movement_state"]>0

  if(!ok){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_risk=nrow(d),
      n_events=sum(d$infection_event),
      n_event_strata=length(event_strata),
      n_exposure_switch_event_strata=
        length(exposure_switch_event_strata),
      n_fit_rows=nrow(d_fit),
      beta_move=if("movement_state"%in%names(cf))
        unname(cf["movement_state"]) else NA_real_,
      se_move=NA_real_,
      fit_ok=FALSE,
      warning_count=length(warns),
      warning_message=warn_text,
      message="movement coefficient/variance not estimable"
    )
    next
  }

  b <- unname(cf["movement_state"])
  se <- sqrt(unname(vv["movement_state","movement_state"]))

  coef_draws[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    beta_move=rnorm(N_KEEP,b,se)
  )

  fit_diag[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    n_risk=nrow(d),
    n_events=sum(d$infection_event),
    n_event_strata=length(event_strata),
    n_exposure_switch_event_strata=
      length(exposure_switch_event_strata),
    n_fit_rows=nrow(d_fit),
    beta_move=b,
    se_move=se,
    fit_ok=TRUE,
    warning_count=length(warns),
    warning_message=warn_text,
    message=""
  )

  if(pp%%100L==0L)
    cat("Processed pair",pp,"/",nrow(pair_index),"\n")
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
      median_all_events=median(n_events),
      median_event_strata=median(n_event_strata),
      median_exposure_switch_event_strata=
        median(n_exposure_switch_event_strata),
      q025_exposure_switch_event_strata=
        quantile(n_exposure_switch_event_strata,.025),
      q975_exposure_switch_event_strata=
        quantile(n_exposure_switch_event_strata,.975),
      min_exposure_switch_event_strata=
        min(n_exposure_switch_event_strata),
      max_exposure_switch_event_strata=
        max(n_exposure_switch_event_strata)
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
  cat("\nMost common failures:\n")
  print(
    fit_diag %>%
      filter(!fit_ok) %>%
      count(message,sort=TRUE),
    n=20,width=Inf
  )
}

if(!nrow(pooled))
  stop("No time-stratified within-individual fits were estimable.")

summary_beta <- tibble(
  mean=mean(pooled$beta_move),
  sd=sd(pooled$beta_move),
  median=median(pooled$beta_move),
  q025=unname(quantile(pooled$beta_move,.025)),
  q975=unname(quantile(pooled$beta_move,.975)),
  P_gt_0=mean(pooled$beta_move>0),
  OR_median=median(exp(pooled$beta_move)),
  OR_q025=unname(quantile(exp(pooled$beta_move),.025)),
  OR_q975=unname(quantile(exp(pooled$beta_move),.975))
)

cat("\n============================================================\n")
cat("TIME-STRATIFIED WITHIN-BADGER MOVEMENT EFFECT\n")
cat("============================================================\n")
print(summary_beta,width=Inf)

dir.create("results",showWarnings=FALSE,recursive=TRUE)

out_rds <- paste0(
  "results/V7bM_time_stratified_within_",
  BLOCK_YEARS,"yr_",RESULT_TAG,".rds"
)
out_csv <- paste0(
  "results/V7bM_time_stratified_within_",
  BLOCK_YEARS,"yr_",RESULT_TAG,"_summary.csv"
)

saveRDS(
  list(
    model="V7b-M time-stratified within-individual sensitivity",
    coefficient_draws=pooled,
    summary=summary_beta,
    fit_diagnostics=fit_diag,
    settings=list(
      block_years=BLOCK_YEARS,
      risk_definition="movement ending t -> infection Q1-Q4 t+1",
      strata="tattoo x calendar block",
      quarter_adjustment=TRUE,
      note="broad calendar time controlled by matching/stratification rather than estimated as a coefficient"
    )
  ),
  out_rds
)

write_csv(summary_beta,out_csv)

cat("\nSaved:",out_rds,"\n")
cat("Saved:",out_csv,"\n")
