# =============================================================================
# WOODCHESTER V7b-M WITHIN-INDIVIDUAL / CASE-CROSSOVER SENSITIVITY
#
# QUESTION
# --------
# Among badgers that acquire infection during follow-up, is acquisition more
# likely during risk periods preceded by that SAME badger being in the
# high-mobility state than during its own local-mobility risk periods?
#
# This is a conditional logistic sensitivity to the primary V7b-M discrete-time
# hazard model. Individual fixed effects are conditioned out with strata(tattoo).
# Stable individual susceptibility therefore cannot confound beta_move.
#
# Risk definition exactly matches V7b-M:
#   movement interval ending year t
#     -> susceptible at Q4(t)
#     -> infection risk in Q1-Q4(t+1)
#     -> stop at infection or last observed live quarter.
#
# Quarter + 5-year period effects are retained.
#
# NOTE
# ----
# Sex is constant within badger and therefore cannot be estimated here.
# Only event badgers contribute to the conditional likelihood, and the movement
# effect is principally identified by event badgers whose movement exposure
# changes across their risk periods. This is intentionally a sensitivity check,
# not a replacement for the population-level V7b-M.
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
SEED <- as.integer(Sys.getenv("SEED","7092035"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","WITHIN")

set.seed(SEED)

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

# Mirror V7b-M: last movement interval cannot predict a full subsequent modeled
# annual interval, so exclude it.
eligible_move <- idx %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last)

pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<1L) stop("MAX_PAIRS must be >=1.")

if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS)
    pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}

# Build one V7b person-period risk dataset exactly as in the audit.
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

    susceptible_q4 <- infection_time==0L || infection_time>move_end_q4
    if(!susceptible_q4) next

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
        outcome_year=outcome_year,
        outcome_quarter=q,
        period_start=floor(outcome_year/5L)*5L,
        infection_event=event
      )

      if(event==1L) break
    }
  }

  if(oo==0L) return(tibble())
  bind_rows(out[seq_len(oo)])
}

form <- infection_event ~ movement_state +
  factor(outcome_quarter) +
  factor(period_start) +
  strata(tattoo)

cat("\n============================================================\n")
cat("V7b-M WITHIN-INDIVIDUAL / CASE-CROSSOVER SENSITIVITY\n")
cat("============================================================\n")
cat("Paired histories:",nrow(pair_index),"\n")
cat("Risk timing: movement t -> acquisition Q1-Q4 t+1\n")
cat("Individual fixed effects: strata(tattoo)\n")
cat("Time adjustment: quarter + 5-year period\n\n")

coef_draws <- vector("list",nrow(pair_index))
fit_diag <- vector("list",nrow(pair_index))

dir.create("results",showWarnings=FALSE,recursive=TRUE)
CHECKPOINT_FILE <- paste0(
  "results/V7bM_within_checkpoint_",RESULT_TAG,".rds"
)

for(pp in seq_len(nrow(pair_index))){
  d <- make_v7b(
    pair_index$movement_draw[pp],
    pair_index$infection_col[pp]
  )

  if(!nrow(d)){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_rows=0L,n_event_badgers=0L,n_exposure_switchers=0L,
      beta_move=NA_real_,se_move=NA_real_,
      fit_ok=FALSE,warning_count=0L,warning_message="",
      message="empty risk dataset"
    )
    next
  }

  # Exact audit against existing paired-history audit.
  aud <- paired$audit %>%
    filter(pair_draw==pair_index$pair_draw[pp])

  if(nrow(d)!=aud$v7b_risk_quarters ||
     sum(d$infection_event)!=aud$v7b_events)
    stop("V7b risk/event audit mismatch for pair_draw ",
         pair_index$pair_draw[pp])

  id_info <- d %>%
    group_by(tattoo) %>%
    summarise(
      event=sum(infection_event),
      exposure_var=n_distinct(movement_state),
      n=n(),
      .groups="drop"
    )

  event_ids <- id_info %>%
    filter(event==1L) %>%
    pull(tattoo)

  switch_ids <- id_info %>%
    filter(event==1L,exposure_var>1L) %>%
    pull(tattoo)

  # In conditional logistic regression, strata with no event contribute nothing.
  d_fit <- d %>%
    filter(tattoo%in%event_ids)

  if(pp==1L){
    cat("FIRST-PAIR INFORMATION AUDIT\n")
    cat("Risk quarters:",nrow(d),"\n")
    cat("Infection events:",sum(d$infection_event),"\n")
    cat("Event badgers:",length(event_ids),"\n")
    cat("Event badgers switching movement exposure:",length(switch_ids),"\n")
    cat("Rows retained for conditional fit:",nrow(d_fit),"\n\n")
  }

  if(length(event_ids)<2L || length(switch_ids)<1L){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_rows=nrow(d),
      n_event_badgers=length(event_ids),
      n_exposure_switchers=length(switch_ids),
      beta_move=NA_real_,se_move=NA_real_,
      fit_ok=FALSE,warning_count=0L,warning_message="",
      message="insufficient within-individual movement variation among event badgers"
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
        control=survival::coxph.control(iter.max=100,eps=1e-9)
      ),
      warning=function(w){
        warning_messages <<- c(warning_messages,conditionMessage(w))
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
      n_event_badgers=length(event_ids),
      n_exposure_switchers=length(switch_ids),
      beta_move=NA_real_,se_move=NA_real_,
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
     !"movement_state"%in%names(cf) ||
     !is.finite(cf["movement_state"]) ||
     !"movement_state"%in%rownames(vv) ||
     !is.finite(vv["movement_state","movement_state"]) ||
     vv["movement_state","movement_state"]<=0){

    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_rows=nrow(d),
      n_event_badgers=length(event_ids),
      n_exposure_switchers=length(switch_ids),
      beta_move=if("movement_state"%in%names(cf))
        unname(cf["movement_state"]) else NA_real_,
      se_move=NA_real_,
      fit_ok=FALSE,
      warning_count=length(warning_messages),
      warning_message=warning_text,
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
    n_rows=nrow(d),
    n_event_badgers=length(event_ids),
    n_exposure_switchers=length(switch_ids),
    beta_move=b,se_move=se,
    fit_ok=TRUE,
    warning_count=length(warning_messages),
    warning_message=warning_text,
    message=""
  )

  if(pp%%100L==0L){
    cat("Processed pair",pp,"/",nrow(pair_index),"\n")
    saveRDS(
      list(
        completed_pair=pp,
        coef_draws=coef_draws[seq_len(pp)],
        fit_diag=fit_diag[seq_len(pp)]
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
      median_risk_rows=median(n_rows),
      median_event_badgers=median(n_event_badgers),
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
  cat("\nMost common failures:\n")
  print(
    fit_diag %>%
      filter(!fit_ok) %>%
      count(message,sort=TRUE),
    n=20,width=Inf
  )
}

if(!nrow(pooled))
  stop("No within-individual V7b fits were estimable.")

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
cat("WITHIN-INDIVIDUAL MOVEMENT EFFECT ON INFECTION\n")
cat("============================================================\n")
print(summary_beta,width=Inf)

out_rds <- paste0(
  "results/V7bM_within_individual_",RESULT_TAG,".rds"
)
out_csv <- paste0(
  "results/V7bM_within_individual_",RESULT_TAG,"_summary.csv"
)

saveRDS(
  list(
    model="V7b-M within-individual conditional logistic sensitivity",
    coefficient_draws=pooled,
    summary=summary_beta,
    fit_diagnostics=fit_diag,
    settings=list(
      risk_definition="movement ending year t -> infection Q1-Q4 t+1",
      individual_effect="conditioned out with clogit strata(tattoo)",
      time_adjustment="quarter + 5-year period",
      method="Efron conditional logistic likelihood; asymptotic normal beta_move draws",
      note="only event badgers contribute; effect mainly identified by event badgers switching movement exposure"
    )
  ),
  out_rds
)
write_csv(summary_beta,out_csv)

cat("\nSaved:",out_rds,"\n")
cat("Saved:",out_csv,"\n")
cat("Checkpoint:",CHECKPOINT_FILE,"\n")
