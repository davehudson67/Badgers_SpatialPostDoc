# =============================================================================
# WOODCHESTER V7c — QUARTERLY SOURCE-EFFECT SUPPORT AUDIT
#
# PURPOSE
# -------
# Extend the annual V7c source-effect analysis to finer temporal resolution
# before fitting a quarterly discrete-time infection-hazard model.
#
# This script asks whether there is enough supported follow-up after an observed
# Excretor / Super-excretor capture to estimate when subsequent infections occur.
# It does NOT yet estimate a source effect.
#
# EXPOSURE
# --------
# Exposure occurs in the exact calendar quarter of a LIVE capture at which the
# source badger was classified as:
#   - Excretor or Super excretor ("infectious source")
#   - Super excretor specifically
#
# Source social group is the social group recorded at that capture occasion.
# Multiple source captures in the same social-group x quarter are collapsed to
# one source group-quarter while retaining all source identities.
#
# RECIPIENT MEMBERSHIP — TWO SUPPORT DEFINITIONS
# ------------------------------------------------
# 1. EXACT_QUARTER
#    Recipient has an exact LIVE capture in the same social group and quarter.
#
# 2. ANNUAL_GROUP
#    Recipient has that exact observed annual social group in the exposure year
#    and the source quarter falls inside the recipient's observed LIVE history.
#    This gives broader support without assuming presence before first capture
#    or after last live capture.
#
# FOLLOW-UP
# ---------
# Recipients must be susceptible through the exposure quarter in each sampled
# infection history. Acquisition is then counted 1, 2, 4 and 8 quarters after
# exposure, but follow-up is truncated at the recipient's last observed LIVE
# quarter. We therefore do NOT manufacture alive/exposed time after final live
# observation.
#
# IMPORTANT
# ---------
# A recipient can appear after more than one source quarter. Pair-level event
# counts can therefore count the same eventual infection against overlapping
# exposures. This is intentional for a SUPPORT audit only. We also report the
# number of UNIQUE recipient acquisitions. The next model must use unique
# recipient-quarter risk rows so each infection event enters only once.
# =============================================================================

library(tidyverse)
library(lubridate)

ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
ANNUAL_FILE    <- "data/badger_annual_observed_sett_locations.rds"
INF_FILE       <- "data/badger_infection_trajectories_all_tests_inferred.rds"

for(f in c(ENCOUNTER_FILE,ANNUAL_FILE,INF_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

enc <- as_tibble(readRDS(ENCOUNTER_FILE))
annual <- as_tibble(readRDS(ANNUAL_FILE))
inf <- readRDS(INF_FILE)

START_YEAR <- as.integer(inf$start_year)
INF_IDS <- str_to_upper(str_squish(as.character(inf$tattoo)))
N_DRAW <- ncol(inf$infection_time)
WINDOWS <- c(1L,2L,4L,8L)

qindex <- function(year,quarter) 4L*(as.integer(year)-START_YEAR)+as.integer(quarter)

classify_disease <- function(x){
  z <- str_to_upper(str_squish(as.character(x)))
  case_when(
    is.na(z) | z=="" ~ NA_character_,
    str_detect(z,"SUPER.*EXCRET|SUPERSPREAD") ~ "Super excretor",
    str_detect(z,"EXCRET") ~ "Excretor",
    str_detect(z,"EXPOS") ~ "Exposed",
    str_detect(z,"NEG") ~ "Negative",
    TRUE ~ NA_character_
  )
}

need_enc <- c("tattoo","capture_date","has_live_capture","socg","disease_status")
miss_enc <- setdiff(need_enc,names(enc))
if(length(miss_enc)) stop("Encounter file is missing: ",paste(miss_enc,collapse=", "))

need_annual <- c("tattoo","year","annual_socg")
miss_annual <- setdiff(need_annual,names(annual))
if(length(miss_annual)) stop("Annual location file is missing: ",paste(miss_annual,collapse=", "))

# =============================================================================
# 1. LIVE ENCOUNTERS AND OBSERVED LIVE-HISTORY BOUNDS
# =============================================================================

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    capture_date=as.Date(capture_date),
    year=year(capture_date),
    quarter=quarter(capture_date),
    qtime=qindex(year,quarter),
    socg=as.character(socg),
    disease_class=classify_disease(disease_status)
  ) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(capture_date))

live_bounds <- live %>%
  group_by(tattoo) %>%
  summarise(first_live_q=min(qtime),last_live_q=max(qtime),.groups="drop")

# Exact quarter/group membership uses any exact live capture in that group and
# quarter. If an animal was observed in >1 group in a quarter, both exact
# observations are retained rather than choosing one arbitrarily.
quarter_members <- live %>%
  filter(!is.na(socg),socg!="") %>%
  distinct(tattoo,year,quarter,qtime,socg)

annual2 <- annual %>%
  transmute(
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    year=as.integer(year),
    annual_socg=as.character(annual_socg)
  ) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(year),!is.na(annual_socg),annual_socg!="") %>%
  distinct(tattoo,year,.keep_all=TRUE) %>%
  left_join(live_bounds,by="tattoo")

# =============================================================================
# 2. OBSERVED INFECTIOUS SOURCE GROUP-QUARTERS
# =============================================================================

source_occ <- live %>%
  filter(disease_class %in% c("Excretor","Super excretor"),!is.na(socg),socg!="") %>%
  transmute(source_tattoo=tattoo,capture_date,year,quarter,qtime,socg,disease_class)

source_gq <- source_occ %>%
  group_by(year,quarter,qtime,socg) %>%
  summarise(
    source_ids=list(unique(source_tattoo)),
    n_infectious_sources=n_distinct(source_tattoo),
    n_super_sources=n_distinct(source_tattoo[disease_class=="Super excretor"]),
    any_super=n_super_sources>0,
    .groups="drop"
  ) %>%
  arrange(qtime,socg)

if(!nrow(source_gq)) stop("No live Excretor/Super-excretor source group-quarters found.")

# =============================================================================
# 3. BUILD RECIPIENT EXPOSURE PAIRS UNDER TWO MEMBERSHIP DEFINITIONS
# =============================================================================

exclude_source_rows <- function(d){
  d %>%
    rowwise() %>%
    mutate(is_source=tattoo %in% source_ids) %>%
    ungroup() %>%
    filter(!is_source) %>%
    select(-is_source)
}

# Exact-quarter recipients.
pairs_exact <- source_gq %>%
  inner_join(
    quarter_members %>% rename(tattoo=tattoo),
    by=c("year","quarter","qtime","socg")
  ) %>%
  exclude_source_rows() %>%
  left_join(live_bounds,by="tattoo") %>%
  mutate(membership="EXACT_QUARTER")

# Annual-group recipients, bounded by observed live history at exposure.
pairs_annual <- source_gq %>%
  inner_join(
    annual2 %>% select(tattoo,year,annual_socg,first_live_q,last_live_q),
    by=c("year","socg"="annual_socg")
  ) %>%
  filter(qtime>=first_live_q,qtime<=last_live_q) %>%
  exclude_source_rows() %>%
  mutate(membership="ANNUAL_GROUP")

pairs <- bind_rows(pairs_exact,pairs_annual) %>%
  mutate(
    inf_row=match(tattoo,INF_IDS),
    exposure_type=if_else(any_super,"SUPER_PRESENT","INFECTIOUS_PRESENT"),
    exposure_id=paste(year,quarter,socg,sep="|")
  ) %>%
  filter(!is.na(inf_row)) %>%
  distinct(membership,exposure_id,tattoo,.keep_all=TRUE)

if(!nrow(pairs)) stop("No eligible recipient-source-quarter pairs were constructed.")

# =============================================================================
# 4. STATIC SUPPORT + REPEATED-EXPOSURE BURDEN
# =============================================================================

static_support <- pairs %>%
  group_by(membership) %>%
  summarise(
    source_group_quarters=n_distinct(exposure_id),
    source_group_quarters_with_super=n_distinct(exposure_id[any_super]),
    recipient_exposure_rows=n(),
    unique_recipients=n_distinct(tattoo),
    .groups="drop"
  )

repeat_exposure <- pairs %>%
  group_by(membership,tattoo) %>%
  summarise(
    n_infectious_source_quarters=n_distinct(exposure_id),
    n_super_source_quarters=n_distinct(exposure_id[any_super]),
    .groups="drop"
  ) %>%
  group_by(membership) %>%
  summarise(
    recipients=n(),
    median_source_quarters=median(n_infectious_source_quarters),
    q90_source_quarters=unname(quantile(n_infectious_source_quarters,.90)),
    max_source_quarters=max(n_infectious_source_quarters),
    recipients_multiple_source_quarters=sum(n_infectious_source_quarters>1),
    recipients_ever_super=sum(n_super_source_quarters>0),
    recipients_multiple_super_quarters=sum(n_super_source_quarters>1),
    .groups="drop"
  )

# =============================================================================
# 5. POSTERIOR SUPPORT BY FOLLOW-UP WINDOW
# =============================================================================

# Each exposure definition is evaluated separately. SUPER_PRESENT is a subset
# of infectious source group-quarters; INFECTIOUS_PRESENT includes all.
make_pair_subset <- function(membership,exposure){
  z <- pairs %>% filter(.data$membership==membership)
  if(exposure=="SUPER_PRESENT") z <- z %>% filter(any_super)
  z
}

support_rows <- list(); lag_rows <- list(); ns <- 0L; nl <- 0L

for(mm in c("EXACT_QUARTER","ANNUAL_GROUP")){
  for(ee in c("INFECTIOUS_PRESENT","SUPER_PRESENT")){
    z <- make_pair_subset(mm,ee)
    if(!nrow(z)) next

    IT <- inf$infection_time[z$inf_row,,drop=FALSE]
    q0 <- z$qtime
    lastq <- z$last_live_q

    # Susceptible through the source quarter.
    SUS <- matrix(FALSE,nrow(z),N_DRAW)
    for(i in seq_len(nrow(z))){
      tt <- as.integer(IT[i,])
      SUS[i,] <- tt==0L | tt>q0[i]
    }

    for(ww in WINDOWS){
      EVT <- matrix(FALSE,nrow(z),N_DRAW)
      for(i in seq_len(nrow(z))){
        tt <- as.integer(IT[i,])
        endq <- min(q0[i]+ww,lastq[i])
        if(endq>q0[i]) EVT[i,] <- tt>q0[i] & tt<=endq
      }

      nrisk <- colSums(SUS)
      nevent_rows <- colSums(EVT & SUS)

      # Unique recipient acquisitions: each badger counted at most once per draw
      # even if the same infection falls in overlapping exposure windows.
      unique_events <- integer(N_DRAW)
      for(dd in seq_len(N_DRAW)){
        ii <- which(SUS[,dd] & EVT[,dd])
        unique_events[dd] <- if(length(ii)) n_distinct(z$tattoo[ii]) else 0L
      }

      risk <- ifelse(nrisk>0,nevent_rows/nrisk,NA_real_)
      ns <- ns+1L
      support_rows[[ns]] <- tibble(
        membership=mm,
        exposure=ee,
        followup_quarters=ww,
        source_group_quarters=n_distinct(z$exposure_id),
        recipient_exposure_rows=nrow(z),
        unique_recipients=n_distinct(z$tattoo),
        median_susceptible_exposure_rows=median(nrisk),
        q025_susceptible_exposure_rows=unname(quantile(nrisk,.025)),
        q975_susceptible_exposure_rows=unname(quantile(nrisk,.975)),
        median_event_rows=median(nevent_rows),
        q025_event_rows=unname(quantile(nevent_rows,.025)),
        q975_event_rows=unname(quantile(nevent_rows,.975)),
        median_unique_recipient_acquisitions=median(unique_events),
        q025_unique_recipient_acquisitions=unname(quantile(unique_events,.025)),
        q975_unique_recipient_acquisitions=unname(quantile(unique_events,.975)),
        median_pair_level_risk=median(risk,na.rm=TRUE),
        p_draw_any_event=mean(nevent_rows>0)
      )
    }

    # Exact lag support through eight quarters. This is descriptive only and is
    # used to choose parsimonious lag bins for the subsequent hazard model.
    for(lag in 1:8){
      event_rows <- integer(N_DRAW)
      unique_events <- integer(N_DRAW)
      for(dd in seq_len(N_DRAW)){
        tt <- as.integer(IT[,dd])
        ok <- SUS[,dd] & lastq>=q0+lag & tt==q0+lag
        event_rows[dd] <- sum(ok)
        unique_events[dd] <- if(any(ok)) n_distinct(z$tattoo[ok]) else 0L
      }
      nl <- nl+1L
      lag_rows[[nl]] <- tibble(
        membership=mm,exposure=ee,lag_quarter=lag,
        median_event_rows=median(event_rows),
        q025_event_rows=unname(quantile(event_rows,.025)),
        q975_event_rows=unname(quantile(event_rows,.975)),
        median_unique_recipient_acquisitions=median(unique_events),
        q025_unique_recipient_acquisitions=unname(quantile(unique_events,.025)),
        q975_unique_recipient_acquisitions=unname(quantile(unique_events,.975)),
        p_draw_any_event=mean(event_rows>0)
      )
    }
  }
}

support_summary <- bind_rows(support_rows)
lag_summary <- bind_rows(lag_rows)

# =============================================================================
# 6. PRINT AUDIT
# =============================================================================

cat("\n============================================================\n")
cat("V7c QUARTERLY SOURCE-EFFECT SUPPORT AUDIT\n")
cat("============================================================\n")
cat("Infection trajectory draws:",N_DRAW,"\n")
cat("Live infectious source capture occasions:",nrow(source_occ),"\n")
cat("Unique infectious source badgers:",n_distinct(source_occ$source_tattoo),"\n")
cat("Source social-group x quarters:",nrow(source_gq),"\n")
cat("Source group-quarters containing >=1 Super excretor:",sum(source_gq$any_super),"\n\n")

cat("STATIC RECIPIENT SUPPORT\n")
print(static_support,n=Inf,width=Inf)

cat("\nREPEATED EXPOSURE BURDEN\n")
print(repeat_exposure,n=Inf,width=Inf)

cat("\nFOLLOW-UP SUPPORT BY WINDOW\n")
print(support_summary,n=Inf,width=Inf)

cat("\nEVENT SUPPORT BY EXACT LAG QUARTER\n")
print(lag_summary,n=Inf,width=Inf)

cat("\nDECISION GUIDE\n")
cat("- This is a support audit, not an effect model.\n")
cat("- EXACT_QUARTER is the strictest co-membership definition.\n")
cat("- ANNUAL_GROUP increases support but is bounded by each recipient's first/last live quarter.\n")
cat("- Follow-up stops at last observed LIVE quarter; no post-disappearance risk time is invented.\n")
cat("- Pair-level event rows can duplicate an infection across overlapping source exposures.\n")
cat("- Unique-recipient acquisition counts show how much independent event information is actually present.\n")
cat("- The next analysis should use unique recipient-quarter risk rows and time-varying source exposure.\n")
cat("- A later survival/observation sensitivity can explicitly distinguish mortality, emigration and missed capture.\n")

# =============================================================================
# 7. SAVE
# =============================================================================

dir.create("results",showWarnings=FALSE,recursive=TRUE)
dir.create("data",showWarnings=FALSE,recursive=TRUE)

saveRDS(
  list(
    source_occ=source_occ,
    source_group_quarters=source_gq,
    recipient_pairs=pairs,
    static_support=static_support,
    repeated_exposure=repeat_exposure,
    support_summary=support_summary,
    lag_summary=lag_summary,
    settings=list(
      infection_draws=N_DRAW,
      followup_windows_quarters=WINDOWS,
      source_definition="live observed Excretor/Super-excretor capture in exact recorded social group/quarter",
      exact_membership="live capture in same social group/quarter",
      annual_membership="same annual observed social group, exposure quarter inside observed live-history bounds",
      censoring="truncate at last observed live quarter"
    )
  ),
  "data/badger_V7c_quarterly_source_effect_support_audit.rds"
)

write_csv(static_support,"results/V7c_quarterly_static_support.csv")
write_csv(repeat_exposure,"results/V7c_quarterly_repeated_exposure.csv")
write_csv(support_summary,"results/V7c_quarterly_followup_support.csv")
write_csv(lag_summary,"results/V7c_quarterly_lag_event_support.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_quarterly_source_effect_support_audit.rds\n")
cat("  results/V7c_quarterly_static_support.csv\n")
cat("  results/V7c_quarterly_repeated_exposure.csv\n")
cat("  results/V7c_quarterly_followup_support.csv\n")
cat("  results/V7c_quarterly_lag_event_support.csv\n")
