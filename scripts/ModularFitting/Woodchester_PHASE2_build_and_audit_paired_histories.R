# =============================================================================
# WOODCHESTER PHASE 2 - BUILD/AUDIT PAIRED LATENT HISTORIES
#
# Inputs:
#   data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds
#   data/badger_infection_trajectories_all_tests_inferred.rds
#   data/badger_encounters_useful.rds
#
# Infection object is the canonical trajectory snapshot produced by
# Woodchester_V7_prepare_trajectory_draws.R:
#   infection_time = 0 means never infected in observed history
#   infection_time > 0 is a 1-based quarterly occasion
#   time = 4 * (year - start_year) + quarter
#
# Creates balanced pairings between 1500 movement histories and the 500
# infection trajectory draws and audits BOTH directional analyses.
# =============================================================================

library(tidyverse)

MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
OUT_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
SEED <- 7092027L

for(f in c(MOVE_FILE,INF_FILE,ENCOUNTER_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

mov <- readRDS(MOVE_FILE)
inf <- readRDS(INF_FILE)
enc <- readRDS(ENCOUNTER_FILE)

# ---- strict input checks ------------------------------------------------------
req_inf <- c("tattoo","draws","infection_time","start_year")
if(!all(req_inf%in%names(inf)))
  stop("Infection snapshot is not canonical. Missing: ",
       paste(setdiff(req_inf,names(inf)),collapse=", "))

if(!is.matrix(inf$infection_time))
  stop("inf$infection_time must be a tattoo x draw matrix.")

if(nrow(inf$infection_time)!=length(inf$tattoo))
  stop("infection_time rows do not match inf$tattoo.")

if(ncol(inf$infection_time)!=length(inf$draws))
  stop("infection_time columns do not match inf$draws.")

if(any(inf$infection_time<0L))
  stop("infection_time must be zero or positive.")

START_YEAR <- as.integer(inf$start_year)
if(length(START_YEAR)!=1L || is.na(START_YEAR))
  stop("Invalid infection start_year.")

idx <- mov$interval_index %>%
  mutate(
    interval_col=row_number(),
    tattoo=trimws(as.character(tattoo)),
    model_i=as.integer(model_i),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year)
  )

if(ncol(mov$state_draws)!=nrow(idx))
  stop("Movement state matrix does not match interval index.")

if(!all(mov$state_draws%in%c(0L,1L)))
  stop("Movement histories must be coded 0=local, 1=high.")

move_ids <- unique(idx$tattoo)
inf_ids <- trimws(as.character(inf$tattoo))
inf_row <- match(move_ids,inf_ids)
names(inf_row) <- move_ids

if(anyNA(inf_row))
  stop("Some movement badgers are absent from infection trajectories: ",
       paste(head(move_ids[is.na(inf_row)],20),collapse=", "))

# ---- exact last live quarter -------------------------------------------------
req_enc <- c("tattoo","primary_year","trap_season","has_live_capture")
if(!all(req_enc%in%names(enc)))
  stop("Encounter snapshot lacks columns: ",
       paste(setdiff(req_enc,names(enc)),collapse=", "))

live_bounds <- enc %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    primary_year=as.integer(primary_year),
    trap_season=as.integer(trap_season),
    has_live_capture=as.logical(has_live_capture)
  ) %>%
  filter(
    tattoo%in%move_ids,
    has_live_capture,
    !is.na(primary_year),
    trap_season%in%1:4,
    primary_year<=2025L
  ) %>%
  mutate(time=4L*(primary_year-START_YEAR)+trap_season) %>%
  group_by(tattoo) %>%
  summarise(
    first_live_time=min(time),
    last_live_time=max(time),
    .groups="drop"
  )

if(nrow(live_bounds)!=length(move_ids))
  stop("Could not reconstruct live-quarter bounds for every movement badger.")

last_live <- setNames(live_bounds$last_live_time,live_bounds$tattoo)

# ---- balanced posterior pairing ---------------------------------------------
# Movement export contains 1500 histories (500 from each final movement chain).
# Infection snapshot contains 500 coherent trajectory draws.
#
# Use every movement history exactly once and every infection trajectory equally
# often. With 1500 vs 500 this means each infection draw is used exactly 3 times.
set.seed(SEED)

n_move <- nrow(mov$state_draws)
n_inf <- ncol(inf$infection_time)

if(n_move%%n_inf!=0L)
  warning("Movement/infection draw counts are not an exact multiple; pairing remains balanced as possible.")

inf_col_balanced <- rep(seq_len(n_inf),length.out=n_move)
inf_col_balanced <- sample(inf_col_balanced,length(inf_col_balanced),replace=FALSE)

pair_index <- tibble(
  pair_draw=seq_len(n_move),
  movement_draw=seq_len(n_move),
  movement_chain=mov$draw_index$chain,
  movement_retained_draw=mov$draw_index$retained_draw,
  infection_col=inf_col_balanced,
  infection_draw=inf$draws[inf_col_balanced]
)

# ---- helpers ----------------------------------------------------------------
q4_time <- function(year) 4L*(as.integer(year)-START_YEAR)+4L

# Return one exact V7a-M conditional dataset.
make_v7a <- function(move_draw,inf_col){
  st <- as.integer(mov$state_draws[move_draw,])
  inf_t <- as.integer(inf$infection_time[,inf_col])
  names(inf_t) <- inf_ids

  idx %>%
    group_by(model_i,tattoo) %>%
    arrange(from_year,to_year,.by_group=TRUE) %>%
    mutate(
      movement_state=st[interval_col],
      previous_state=lag(movement_state),
      infection_time=inf_t[tattoo],
      infected_origin=as.integer(
        infection_time>0L &
        infection_time<=q4_time(from_year)
      ),
      sex=mov$sex[model_i],
      eligible=!is.na(previous_state) & previous_state==0L
    ) %>%
    ungroup() %>%
    filter(eligible) %>%
    transmute(
      model_i,tattoo,from_year,to_year,
      previous_state,movement_state,
      infected_origin,sex
    )
}

# Return one exact V7b-M strict-future quarterly risk dataset.
make_v7b <- function(move_draw,inf_col){
  st <- as.integer(mov$state_draws[move_draw,])
  inf_t <- as.integer(inf$infection_time[,inf_col])
  names(inf_t) <- inf_ids

  out <- vector("list",nrow(idx))
  oo <- 0L

  # Last movement interval for a badger cannot predict a fully subsequent year
  # because there is no modeled next annual occasion. Mirror V7b-T exactly.
  eligible_move <- idx %>%
    group_by(model_i,tattoo) %>%
    arrange(from_year,to_year,.by_group=TRUE) %>%
    mutate(is_last=row_number()==n()) %>%
    ungroup() %>%
    filter(!is_last)

  for(rr in seq_len(nrow(eligible_move))){
    row <- eligible_move[rr,]
    tattoo <- row$tattoo
    it <- inf_t[tattoo]
    move_end_year <- row$to_year
    move_end_q4 <- q4_time(move_end_year)

    susceptible_q4 <- it==0L || it>move_end_q4
    if(!susceptible_q4) next

    outcome_year <- move_end_year+1L
    llt <- last_live[tattoo]

    for(q in 1:4){
      ot <- 4L*(outcome_year-START_YEAR)+q
      if(ot>llt) break
      if(it>0L && it<ot) break

      event <- as.integer(it>0L && it==ot)
      oo <- oo+1L
      out[[oo]] <- tibble(
        model_i=row$model_i,
        tattoo=tattoo,
        movement_from_year=row$from_year,
        movement_to_year=move_end_year,
        movement_state=st[row$interval_col],
        sex=mov$sex[row$model_i],
        outcome_year=outcome_year,
        outcome_quarter=q,
        outcome_time=ot,
        period_start=floor(outcome_year/5)*5L,
        infection_event=event
      )
      if(event==1L) break
    }
  }

  if(oo==0L) return(tibble())
  bind_rows(out[seq_len(oo)])
}

# ---- audit all paired posterior histories ------------------------------------
audit <- vector("list",nrow(pair_index))

for(pp in seq_len(nrow(pair_index))){
  a <- make_v7a(pair_index$movement_draw[pp],pair_index$infection_col[pp])
  b <- make_v7b(pair_index$movement_draw[pp],pair_index$infection_col[pp])

  audit[[pp]] <- tibble(
    pair_draw=pp,
    v7a_R_origin_transitions=nrow(a),
    v7a_infected_origins=sum(a$infected_origin==1L),
    v7a_high_outcomes=sum(a$movement_state==1L),
    v7a_badgers=n_distinct(a$tattoo),
    v7b_risk_quarters=nrow(b),
    v7b_events=sum(b$infection_event==1L),
    v7b_badgers=n_distinct(b$tattoo),
    v7b_event_badgers=n_distinct(b$tattoo[b$infection_event==1L])
  )

  if(pp%%100L==0L) cat("Audited pair",pp,"/",nrow(pair_index),"\n")
}

audit <- bind_rows(audit)

summary_q <- function(x){
  c(
    min=min(x),
    q025=unname(quantile(x,.025)),
    median=median(x),
    mean=mean(x),
    q975=unname(quantile(x,.975)),
    max=max(x)
  )
}

cat("\n============================================================\n")
cat("PHASE 2 PAIRED-HISTORY AUDIT\n")
cat("============================================================\n")
cat("Matched badgers:",length(move_ids),"\n")
cat("Paired posterior datasets:",nrow(pair_index),"\n")
cat("Infection start year:",START_YEAR,"\n\n")

for(nm in setdiff(names(audit),"pair_draw")){
  cat(nm,":\n")
  print(summary_q(audit[[nm]]))
  cat("\n")
}

# Save helper metadata + pairing + audit. We intentionally do not materialize
# all 1500 large regression datasets; the Phase-2 fitting scripts construct each
# paired dataset on demand from these exact posterior histories.
saveRDS(
  list(
    movement_file=MOVE_FILE,
    infection_file=INF_FILE,
    encounter_file=ENCOUNTER_FILE,
    pair_index=pair_index,
    audit=audit,
    start_year=START_YEAR,
    movement_ids=move_ids,
    infection_ids=inf_ids,
    live_bounds=live_bounds,
    settings=list(
      movement_model="V7MCMHMMv6_FINAL30K",
      infection_model=inf$model,
      pairing="balanced: every movement draw once; every infection draw equally often",
      V7a_M="infected by Q4 of movement-origin year -> subsequent R-to-high transition; only previous_state=local",
      V7b_M="movement interval ending year t -> infection acquisition Q1-Q4 year t+1; susceptible risk only",
      first_movement_interval="initialization only; excluded from V7a R-to-high regression",
      uncertainty="paired coherent latent histories; do not treat imputations as independent biological rows"
    )
  ),
  OUT_FILE
)

cat("\nSaved:",OUT_FILE,"\n")
cat("\nPhase 2 input construction is ready. Next scripts fit V7a-M and V7b-M\n")
cat("conditional models over these paired posterior datasets and pool effects.\n")
