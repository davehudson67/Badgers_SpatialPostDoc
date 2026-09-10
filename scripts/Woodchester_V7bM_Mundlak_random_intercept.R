# =============================================================================
# WOODCHESTER V7b-M MUNDLAK RANDOM-INTERCEPT SENSITIVITY
#
# Why this model?
# ----------------
# The individual fixed-effect clogit showed a structural problem when absolute
# calendar year/period was included: infection events are necessarily the final
# susceptible risk occasion within an event badger, so monotonic calendar time
# can separate the conditional likelihood.
#
# This sensitivity instead uses a discrete-time logistic mixed model:
#
#   infection_event ~
#       movement_within + movement_mean
#       + sex + adult_entry
#       + quarter + 5-year period
#       + (1 | tattoo)
#
# movement_mean   = each badger's mean high-mobility exposure over its risk rows
# movement_within = movement_state - movement_mean
#
# beta_move_within is the key estimate:
# "For the same badger, is infection acquisition more likely in a risk period
#  preceded by high mobility than during that badger's own more-local periods?"
#
# The subject mean ("Mundlak") term allows the within-badger effect to be
# separated from between-badger differences in general mobility propensity.
#
# This is a sensitivity analysis, not a replacement for primary V7b-M.
# =============================================================================

library(tidyverse)

if(!requireNamespace("lme4",quietly=TRUE))
  stop("Package 'lme4' is required. Install once with install.packages('lme4').")

PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
INF_FILE  <- "data/badger_infection_trajectories_all_tests_inferred.rds"

for(f in c(PAIR_FILE,MOVE_FILE,INF_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

paired <- readRDS(PAIR_FILE)
mov <- readRDS(MOVE_FILE)
inf <- readRDS(INF_FILE)

MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","100"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","100"))
SEED <- as.integer(Sys.getenv("SEED","7092039"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","MUNDLAK_100")

set.seed(SEED)

START_YEAR <- as.integer(inf$start_year)

idx <- mov$interval_index %>%
  mutate(
    interval_col=row_number(),
    model_i=as.integer(model_i),
    tattoo=trimws(as.character(tattoo)),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year),
    sex=as.integer(mov$sex[model_i]),
    adult_entry=as.integer(mov$adult_entry[model_i])
  )

if(ncol(mov$state_draws)!=nrow(idx))
  stop("Movement state matrix does not match interval index.")
if(any(!idx$sex%in%c(0L,1L))) stop("Sex must be 0/1.")
if(any(!idx$adult_entry%in%c(0L,1L))) stop("adult_entry must be 0/1.")

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

# Mirror primary V7b-M: last movement interval excluded.
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

    # Must be susceptible at Q4 of movement-ending year.
    if(!(infection_time==0L || infection_time>move_end_q4)) next

    outcome_year <- move_end_year+1L
    llt <- last_live[tattoo]

    for(q in 1:4){
      ot <- 4L*(outcome_year-START_YEAR)+q

      # Follow-up cannot extend beyond last observed-live quarter.
      if(ot>llt) break

      # Stop after acquisition.
      if(infection_time>0L && infection_time<ot) break

      event <- as.integer(infection_time>0L && infection_time==ot)

      oo <- oo+1L
      out[[oo]] <- tibble(
        tattoo=tattoo,
        movement_state=st[row$interval_col],
        sex=as.integer(row$sex),
        adult_entry=as.integer(row$adult_entry),
        outcome_year=as.integer(outcome_year),
        outcome_quarter=as.integer(q),
        period_start=as.integer(floor(outcome_year/5L)*5L),
        infection_event=event
      )

      if(event==1L) break
    }
  }

  if(oo==0L) return(tibble())

  d <- bind_rows(out[seq_len(oo)]) %>%
    group_by(tattoo) %>%
    mutate(
      movement_mean=mean(movement_state),
      movement_within=movement_state-movement_mean
    ) %>%
    ungroup() %>%
    mutate(
      tattoo=factor(tattoo),
      quarter=factor(outcome_quarter),
      period=factor(period_start)
    )

  d
}

form <- infection_event ~
  movement_within + movement_mean +
  sex + adult_entry +
  quarter + period +
  (1|tattoo)

cat("\n============================================================\n")
cat("V7b-M MUNDLAK RANDOM-INTERCEPT SENSITIVITY\n")
cat("============================================================\n")
cat("Paired histories:",nrow(pair_index),"\n")
cat("Retained coefficient draws/history:",N_KEEP,"\n")
cat("Risk timing: movement t -> acquisition Q1-Q4 t+1\n")
cat("Time adjustment: quarter + 5-year period\n")
cat("Random intercept: tattoo\n")
cat("Key effect: movement_within\n\n")

coef_draws <- vector("list",nrow(pair_index))
fit_diag <- vector("list",nrow(pair_index))

draw_mvn <- function(n,mu,Sigma){
  eg <- eigen(Sigma,symmetric=TRUE)
  eg$values[eg$values<1e-10] <- 1e-10
  A <- eg$vectors %*% diag(sqrt(eg$values),length(eg$values))
  Z <- matrix(rnorm(n*length(mu)),n,length(mu))
  sweep(Z%*%t(A),2,mu,"+")
}

for(pp in seq_len(nrow(pair_index))){
  d <- make_v7b(
    pair_index$movement_draw[pp],
    pair_index$infection_col[pp]
  )

  aud <- paired$audit %>%
    filter(pair_draw==pair_index$pair_draw[pp])

  if(nrow(d)!=aud$v7b_risk_quarters ||
     sum(d$infection_event)!=aud$v7b_events)
    stop("V7b audit mismatch for pair_draw ",pair_index$pair_draw[pp])

  info <- d %>%
    group_by(tattoo) %>%
    summarise(
      event=sum(infection_event),
      move_var=n_distinct(movement_state),
      .groups="drop"
    )

  n_event_badgers <- sum(info$event==1L)
  n_move_switch_badgers <- sum(info$move_var>1L)
  n_event_move_switch <- sum(info$event==1L & info$move_var>1L)

  if(pp==1L){
    cat("FIRST-PAIR INFORMATION AUDIT\n")
    cat("Risk quarters:",nrow(d),"\n")
    cat("Events:",sum(d$infection_event),"\n")
    cat("Risk badgers:",n_distinct(d$tattoo),"\n")
    cat("Event badgers:",n_event_badgers,"\n")
    cat("Badgers switching movement exposure:",n_move_switch_badgers,"\n")
    cat("Event badgers switching movement exposure:",n_event_move_switch,"\n\n")
  }

  warn <- character(0)

  fit <- tryCatch(
    withCallingHandlers(
      lme4::glmer(
        form,
        data=d,
        family=binomial(link="logit"),
        nAGQ=1,
        control=lme4::glmerControl(
          optimizer="bobyqa",
          optCtrl=list(maxfun=200000),
          calc.derivs=TRUE
        )
      ),
      warning=function(w){
        warn <<- c(warn,conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error=function(e)e
  )

  if(inherits(fit,"error")){
    # One retry with a different optimizer.
    warn2 <- character(0)
    fit <- tryCatch(
      withCallingHandlers(
        lme4::glmer(
          form,
          data=d,
          family=binomial(link="logit"),
          nAGQ=1,
          control=lme4::glmerControl(
            optimizer="nloptwrap",
            optCtrl=list(maxeval=200000),
            calc.derivs=TRUE
          )
        ),
        warning=function(w){
          warn2 <<- c(warn2,conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error=function(e)e
    )
    warn <- c(warn,warn2)
  }

  if(inherits(fit,"error")){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_risk=nrow(d),
      n_events=sum(d$infection_event),
      n_event_badgers=n_event_badgers,
      n_move_switch_badgers=n_move_switch_badgers,
      n_event_move_switch=n_event_move_switch,
      beta_within=NA_real_,
      se_within=NA_real_,
      RE_sd=NA_real_,
      singular=NA,
      max_abs_gradient=NA_real_,
      fit_ok=FALSE,
      warnings=paste(unique(warn),collapse=" | "),
      message=conditionMessage(fit)
    )
    next
  }

  cf <- lme4::fixef(fit)
  vv <- as.matrix(vcov(fit))

  if(!"movement_within"%in%names(cf) ||
     !is.finite(cf["movement_within"]) ||
     !is.finite(vv["movement_within","movement_within"])){
    fit_diag[[pp]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      n_risk=nrow(d),
      n_events=sum(d$infection_event),
      n_event_badgers=n_event_badgers,
      n_move_switch_badgers=n_move_switch_badgers,
      n_event_move_switch=n_event_move_switch,
      beta_within=NA_real_,
      se_within=NA_real_,
      RE_sd=NA_real_,
      singular=lme4::isSingular(fit,tol=1e-4),
      max_abs_gradient=NA_real_,
      fit_ok=FALSE,
      warnings=paste(unique(warn),collapse=" | "),
      message="movement_within coefficient not estimable"
    )
    next
  }

  draws <- draw_mvn(N_KEEP,cf,vv)
  colnames(draws) <- names(cf)

  coef_draws[[pp]] <- as_tibble(draws) %>%
    transmute(
      pair_draw=pair_index$pair_draw[pp],
      beta_move_within=movement_within,
      beta_move_between=movement_mean,
      beta_sex=sex,
      beta_adult=adult_entry
    )

  vc <- as.data.frame(lme4::VarCorr(fit))
  re_sd <- vc$sdcor[vc$grp=="tattoo"][1]

  grad <- tryCatch(
    fit@optinfo$derivs$gradient,
    error=function(e)NULL
  )
  max_grad <- if(is.null(grad)) NA_real_ else max(abs(grad))

  fit_diag[[pp]] <- tibble(
    pair_draw=pair_index$pair_draw[pp],
    n_risk=nrow(d),
    n_events=sum(d$infection_event),
    n_event_badgers=n_event_badgers,
    n_move_switch_badgers=n_move_switch_badgers,
    n_event_move_switch=n_event_move_switch,
    beta_within=unname(cf["movement_within"]),
    se_within=sqrt(vv["movement_within","movement_within"]),
    RE_sd=re_sd,
    singular=lme4::isSingular(fit,tol=1e-4),
    max_abs_gradient=max_grad,
    fit_ok=TRUE,
    warnings=paste(unique(warn),collapse=" | "),
    message=""
  )

  if(pp%%10L==0L)
    cat("Fitted pair",pp,"/",nrow(pair_index),"\n")
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
      singular=sum(singular %in% TRUE,na.rm=TRUE),
      pairs_with_warnings=sum(nchar(warnings)>0),
      median_risk=median(n_risk),
      median_events=median(n_events),
      median_event_move_switch=median(n_event_move_switch),
      q025_event_move_switch=quantile(n_event_move_switch,.025),
      q975_event_move_switch=quantile(n_event_move_switch,.975),
      median_RE_sd=median(RE_sd,na.rm=TRUE),
      max_gradient=max(max_abs_gradient,na.rm=TRUE)
    ),
  width=Inf
)

if(any(!fit_diag$fit_ok)){
  cat("\nFailures:\n")
  print(
    fit_diag %>%
      filter(!fit_ok) %>%
      count(message,sort=TRUE),
    n=20,width=Inf
  )
}

if(any(nchar(fit_diag$warnings)>0)){
  cat("\nMost common warnings:\n")
  print(
    fit_diag %>%
      filter(nchar(warnings)>0) %>%
      count(warnings,sort=TRUE),
    n=20,width=Inf
  )
}

if(!nrow(pooled))
  stop("No successful mixed-model fits.")

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
  summ(pooled$beta_move_within) %>%
    mutate(parameter="beta_move_within",.before=1),
  summ(pooled$beta_move_between) %>%
    mutate(parameter="beta_move_between",.before=1),
  summ(pooled$beta_sex) %>%
    mutate(parameter="beta_sex",.before=1),
  summ(pooled$beta_adult) %>%
    mutate(parameter="beta_adult",.before=1)
)

derived <- tibble(
  quantity=c(
    "OR_within_high_vs_local",
    "OR_between_mobility_mean",
    "OR_male",
    "OR_adult_entry"
  ),
  median=c(
    median(exp(pooled$beta_move_within)),
    median(exp(pooled$beta_move_between)),
    median(exp(pooled$beta_sex)),
    median(exp(pooled$beta_adult))
  ),
  q025=c(
    quantile(exp(pooled$beta_move_within),.025),
    quantile(exp(pooled$beta_move_between),.025),
    quantile(exp(pooled$beta_sex),.025),
    quantile(exp(pooled$beta_adult),.025)
  ),
  q975=c(
    quantile(exp(pooled$beta_move_within),.975),
    quantile(exp(pooled$beta_move_between),.975),
    quantile(exp(pooled$beta_sex),.975),
    quantile(exp(pooled$beta_adult),.975)
  )
)

cat("\n============================================================\n")
cat("MUNDLAK MIXED-MODEL POSTERIOR APPROXIMATION\n")
cat("============================================================\n")
print(main_summary,n=Inf,width=Inf)
cat("\nDerived odds ratios:\n")
print(derived,n=Inf,width=Inf)

cat("\nKEY WITHIN-BADGER MOVEMENT EFFECT\n")
cat("beta median:",median(pooled$beta_move_within),"\n")
cat("95% interval:",
    unname(quantile(pooled$beta_move_within,.025)),"to",
    unname(quantile(pooled$beta_move_within,.975)),"\n")
cat("P(beta>0):",mean(pooled$beta_move_within>0),"\n")
cat("OR median:",median(exp(pooled$beta_move_within)),"\n")
cat("OR 95% interval:",
    unname(quantile(exp(pooled$beta_move_within),.025)),"to",
    unname(quantile(exp(pooled$beta_move_within),.975)),"\n")

dir.create("results",showWarnings=FALSE,recursive=TRUE)

out_rds <- paste0(
  "results/V7bM_Mundlak_random_intercept_",RESULT_TAG,".rds"
)
out_csv <- paste0(
  "results/V7bM_Mundlak_random_intercept_",RESULT_TAG,"_summary.csv"
)

saveRDS(
  list(
    model="V7b-M Mundlak random-intercept sensitivity",
    coefficient_draws=pooled,
    main_summary=main_summary,
    derived_summary=derived,
    fit_diagnostics=fit_diag,
    settings=list(
      n_pairs=nrow(pair_index),
      n_draws_per_pair=N_KEEP,
      time_adjustment="quarter + 5-year period",
      random_intercept="tattoo",
      within_between_decomposition=
        "movement_within = movement_state - individual mean; movement_mean = individual mean"
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
  derived %>%
    transmute(
      type="derived",name=quantity,
      median,q025,q975,probability_positive=NA_real_
    )
) %>%
  write_csv(out_csv)

cat("\nSaved:",out_rds,"\n")
cat("Saved:",out_csv,"\n")
