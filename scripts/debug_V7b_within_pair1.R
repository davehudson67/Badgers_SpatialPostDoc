# =============================================================================
# DEBUG V7b WITHIN-INDIVIDUAL FIT
# Runs ONE paired history and progressively adds terms so we can see exactly
# which component is causing the zero-fit failure.
# =============================================================================

library(tidyverse)
library(survival)

PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
INF_FILE  <- "data/badger_infection_trajectories_all_tests_inferred.rds"

paired <- readRDS(PAIR_FILE)
mov <- readRDS(MOVE_FILE)
inf <- readRDS(INF_FILE)

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

last_live <- setNames(
  as.integer(paired$live_bounds$last_live_time),
  trimws(as.character(paired$live_bounds$tattoo))
)

eligible_move <- idx %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last)

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
        outcome_year=outcome_year,
        outcome_quarter=q,
        infection_event=event
      )

      if(event==1L) break
    }
  }

  d <- bind_rows(out[seq_len(oo)])
  d$year_c <- (d$outcome_year-mean(d$outcome_year))/10
  d
}

pd <- paired$pair_index[1,]
d <- make_v7b(pd$movement_draw,pd$infection_col)

id_info <- d %>%
  group_by(tattoo) %>%
  summarise(
    event=sum(infection_event),
    exposure_var=n_distinct(movement_state),
    .groups="drop"
  )

event_ids <- id_info %>% filter(event==1L) %>% pull(tattoo)
switch_ids <- id_info %>% filter(event==1L,exposure_var>1L) %>% pull(tattoo)
d_fit <- d %>% filter(tattoo%in%event_ids)

cat("\n============================================================\n")
cat("V7b WITHIN-INDIVIDUAL DEBUG: PAIR 1\n")
cat("============================================================\n")
cat("Risk rows:",nrow(d),"\n")
cat("Events:",sum(d$infection_event),"\n")
cat("Event badgers:",length(event_ids),"\n")
cat("Event badgers switching movement state:",length(switch_ids),"\n")
cat("Fit rows:",nrow(d_fit),"\n")
cat("Movement table:\n")
print(table(d_fit$movement_state,d_fit$infection_event))
cat("Quarter x event table:\n")
print(table(d_fit$outcome_quarter,d_fit$infection_event))
cat("Outcome year range:",range(d_fit$outcome_year),"\n\n")

run_fit <- function(label,formula){
  cat("\n------------------------------------------------------------\n")
  cat(label,"\n")
  cat("Formula:"); print(formula)
  cat("------------------------------------------------------------\n")

  warns <- character(0)

  fit <- tryCatch(
    withCallingHandlers(
      survival::clogit(
        formula,
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

  if(inherits(fit,"error")){
    cat("ERROR:\n",conditionMessage(fit),"\n")
    return(invisible(NULL))
  }

  if(length(warns)){
    cat("WARNINGS:\n")
    print(unique(warns))
  }else{
    cat("Warnings: none\n")
  }

  cat("Coefficients:\n")
  print(coef(fit))
  cat("SEs:\n")
  print(sqrt(diag(vcov(fit))))

  invisible(fit)
}

f1 <- run_fit(
  "MODEL 1: movement only",
  infection_event ~ movement_state + strata(tattoo)
)

f2 <- run_fit(
  "MODEL 2: movement + quarter",
  infection_event ~ movement_state + factor(outcome_quarter) + strata(tattoo)
)

f3 <- run_fit(
  "MODEL 3: movement + quarter + linear calendar year",
  infection_event ~ movement_state + factor(outcome_quarter) + year_c + strata(tattoo)
)

cat("\n============================================================\n")
cat("DEBUG COMPLETE\n")
cat("============================================================\n")
cat("Paste the complete MODEL 1 / MODEL 2 / MODEL 3 output back into ChatGPT.\n")
