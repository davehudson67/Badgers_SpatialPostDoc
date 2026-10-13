# =============================================================================
# PHASE 3 / P3_05b — TEMPORAL OBSERVATION-EFFORT / SUPPORT AUDIT
#
# Purpose
#   Before interpreting the strong post-2018 descriptive changes in P3_05,
#   check whether observation/support changed at the same time.
#
# This is an audit only. It does not fit a disease or movement model.
#
# Checks by year:
#   - live captures
#   - distinct live-captured badgers
#   - distinct recorded social groups
#   - captures per badger
#   - quarter coverage
#   - annual resident assignments and criterion-1 support
#   - V9 interval support and mean posterior high-mobility probability
#   - latent infection support
#   - culture-only susceptible denominator / incident excretors
#
# Also compares PRE_2018 vs 2018_PLUS in two ways:
#   - equal weight per year (as in P3_05 descriptive summary)
#   - support-weighted summaries, to reduce leverage of sparse late years
#
# 2026 is reported separately and excluded from era comparisons because it is
# incomplete.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

ENC <- "data/badger_encounters_useful.rds"
MEM <- "data/phase3/P3_annual_recorded_membership.rds"
MOVE <- "data/badger_movement_posterior_histories_1932_V9_FINAL.rds"
PANEL <- "data/phase3/P3_groupyear_temporal_panel.rds"

for(f in c(ENC,MEM,MOVE,PANEL))
  if(!file.exists(f)) stop("Missing required file: ",f)

dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)

enc <- as_tibble(readRDS(ENC))
mem <- readRDS(MEM)
mov <- readRDS(MOVE)
p3 <- readRDS(PANEL)

annual_membership <- as_tibble(mem$annual_membership) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    year=as.integer(year),
    resident_socg=as.character(candidate_resident_socg),
    assignment_criterion=as.integer(assignment_criterion),
    n_live_records=as.integer(n_live_records)
  ) %>%
  filter(!is.na(resident_socg),resident_socg!="")

# -----------------------------------------------------------------------------
# Live-capture observation effort
# -----------------------------------------------------------------------------

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    capture_date=as.Date(capture_date),
    year=year(capture_date),
    quarter=quarter(capture_date),
    socg=as.character(socg)
  ) %>%
  filter(!is.na(capture_date),tattoo!="")

effort_year <- live %>%
  group_by(year) %>%
  summarise(
    live_capture_events=n(),
    live_badgers=n_distinct(tattoo),
    recorded_groups=n_distinct(socg[!is.na(socg) & socg!=""]),
    captures_per_badger=live_capture_events/live_badgers,
    badger_quarters=n_distinct(paste(tattoo,quarter,sep="|")),
    mean_quarters_per_badger=badger_quarters/live_badgers,
    .groups="drop"
  )

membership_year <- annual_membership %>%
  group_by(year) %>%
  summarise(
    annual_resident_badgers=n(),
    annual_resident_groups=n_distinct(resident_socg),
    criterion1_badger_years=sum(assignment_criterion==1L,na.rm=TRUE),
    criterion1_share=criterion1_badger_years/annual_resident_badgers,
    median_live_records_per_assignment=median(n_live_records,na.rm=TRUE),
    .groups="drop"
  )

# -----------------------------------------------------------------------------
# V9 support by destination year
# -----------------------------------------------------------------------------

idx <- as_tibble(mov$interval_index) %>%
  mutate(
    interval_col=row_number(),
    tattoo=trimws(as.character(tattoo)),
    to_year=as.integer(to_year)
  )

if(ncol(mov$state_draws)!=nrow(idx))
  stop("V9 movement state matrix does not match interval index.")

move_year <- idx %>%
  mutate(p_high=colMeans(mov$state_draws)) %>%
  group_by(year=to_year) %>%
  summarise(
    v9_intervals=n(),
    v9_badgers=n_distinct(tattoo),
    mean_v9_p_high=mean(p_high),
    median_v9_p_high=median(p_high),
    high_prob_intervals=sum(p_high>0.5),
    high_prob_share=mean(p_high>0.5),
    .groups="drop"
  )

# -----------------------------------------------------------------------------
# Infection and group-level support from P3_05 annual summaries
# -----------------------------------------------------------------------------

system <- as_tibble(p3$annual_system) %>%
  select(
    year,
    n_resident_groups,
    observed_resident_population,
    expected_susceptible_start,
    expected_incident_infections,
    latent_population_prevalence,
    latent_population_incidence,
    culture_incident_excretors,
    culture_susceptible_start,
    culture_incidence,
    capture_movement_supported_groups,
    mean_capture_group_movement,
    v9_supported_groups,
    mean_v9_p_high_panel=mean_v9_p_high,
    incoming_resident_switches,
    residents_with_previous_year,
    resident_switch_rate
  )

audit <- full_join(effort_year,membership_year,by="year") %>%
  full_join(move_year,by="year") %>%
  full_join(system,by="year") %>%
  arrange(year) %>%
  mutate(
    era2018=case_when(
      year>=2018L & year<=2025L ~ "2018_PLUS",
      year<=2017L ~ "PRE_2018",
      year==2026L ~ "2026_INCOMPLETE",
      TRUE ~ NA_character_
    )
  )

# -----------------------------------------------------------------------------
# Equal-year vs support-weighted era comparisons
# -----------------------------------------------------------------------------

era_year_equal <- audit %>%
  filter(year<=2025L,!is.na(era2018)) %>%
  group_by(era2018) %>%
  summarise(
    years=n(),
    mean_live_capture_events=mean(live_capture_events,na.rm=TRUE),
    mean_live_badgers=mean(live_badgers,na.rm=TRUE),
    mean_captures_per_badger=mean(captures_per_badger,na.rm=TRUE),
    mean_quarters_per_badger=mean(mean_quarters_per_badger,na.rm=TRUE),
    mean_criterion1_share=mean(criterion1_share,na.rm=TRUE),
    mean_resident_population=mean(observed_resident_population,na.rm=TRUE),
    mean_groups=mean(n_resident_groups,na.rm=TRUE),
    mean_latent_prevalence=mean(latent_population_prevalence,na.rm=TRUE),
    mean_latent_incidence=mean(latent_population_incidence,na.rm=TRUE),
    mean_capture_movement=mean(mean_capture_group_movement,na.rm=TRUE),
    mean_v9_p_high=mean(mean_v9_p_high,na.rm=TRUE),
    mean_resident_switch_rate=mean(resident_switch_rate,na.rm=TRUE),
    .groups="drop"
  )

weighted_mean_safe <- function(x,w){
  ok <- is.finite(x) & is.finite(w) & w>0
  if(!any(ok)) return(NA_real_)
  weighted.mean(x[ok],w[ok])
}

era_weighted <- audit %>%
  filter(year<=2025L,!is.na(era2018)) %>%
  group_by(era2018) %>%
  summarise(
    years=n(),
    total_live_capture_events=sum(live_capture_events,na.rm=TRUE),
    total_live_badgers_years=sum(live_badgers,na.rm=TRUE),
    total_v9_intervals=sum(v9_intervals,na.rm=TRUE),
    total_susceptible_support=sum(expected_susceptible_start,na.rm=TRUE),
    weighted_latent_prevalence=
      weighted_mean_safe(latent_population_prevalence,
                         observed_resident_population),
    weighted_latent_incidence=
      sum(expected_incident_infections,na.rm=TRUE)/
      sum(expected_susceptible_start,na.rm=TRUE),
    weighted_capture_movement=
      weighted_mean_safe(mean_capture_group_movement,
                         live_capture_events),
    weighted_v9_p_high=
      weighted_mean_safe(mean_v9_p_high,v9_intervals),
    weighted_resident_switch_rate=
      sum(incoming_resident_switches,na.rm=TRUE)/
      sum(residents_with_previous_year,na.rm=TRUE),
    .groups="drop"
  )

cat("\n============================================================\n")
cat("P3_05b — TEMPORAL OBSERVATION-EFFORT / SUPPORT AUDIT\n")
cat("============================================================\n")

cat("\nANNUAL SUPPORT — 2014 ONWARD\n")
print(
  audit %>%
    filter(year>=2014L) %>%
    select(
      year,live_capture_events,live_badgers,captures_per_badger,
      mean_quarters_per_badger,annual_resident_badgers,
      annual_resident_groups,criterion1_share,
      v9_intervals,v9_badgers,mean_v9_p_high,
      expected_susceptible_start,culture_susceptible_start,
      latent_population_incidence,resident_switch_rate
    ),
  n=Inf,width=Inf
)

cat("\nERA SUMMARY — EQUAL WEIGHT PER YEAR\n")
print(era_year_equal,n=Inf,width=Inf)

cat("\nERA SUMMARY — SUPPORT WEIGHTED\n")
print(era_weighted,n=Inf,width=Inf)

if(any(audit$year==2026L)){
  cat("\n2026 INCOMPLETE — REPORT ONLY, DO NOT USE FOR ERA INFERENCE\n")
  print(audit %>% filter(year==2026L),n=Inf,width=Inf)
}

write_csv(audit,
          "results/Phase3/P3_05b_temporal_support_audit.csv")
write_csv(era_year_equal,
          "results/Phase3/P3_05b_era_equal_year_summary.csv")
write_csv(era_weighted,
          "results/Phase3/P3_05b_era_support_weighted_summary.csv")

saveRDS(
  list(
    annual=audit,
    era_equal_year=era_year_equal,
    era_support_weighted=era_weighted,
    note=paste(
      "Observation/support audit only. Differences across 2018 are not",
      "interpreted as causal and 2026 is incomplete."
    )
  ),
  "data/phase3/P3_temporal_support_audit.rds"
)

cat("\nP3_05b COMPLETE\n")
