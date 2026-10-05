# =============================================================================
# PHASE 3 / P3_05 — GROUP-YEAR PANEL + TEMPORAL DESCRIPTION
#
# Purpose
#   Build the common group-year panel that will underpin the new Phase-3 model.
#   This is descriptive/data-construction only: no causal or disease-effect
#   model is fitted here.
#
# Combines
#   - frozen annual resident SOCG (P3_01);
#   - all-tests latent infection trajectories;
#   - culture-only historical benchmark outcomes;
#   - published-style capture-based group movement index;
#   - V9 posterior high-mobility probability;
#   - observed resident-group switching;
#   - reconstructed historical MNA where available.
#
# Outputs
#   data/phase3/P3_groupyear_temporal_panel.rds
#   results/Phase3/P3_05_groupyear_panel.csv
#   results/Phase3/P3_05_annual_system_summary.csv
#   results/Phase3/P3_05_prepost2018_descriptive.csv
#
# 2018 is a prespecified ERA MARKER only, not a causal intervention estimate.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

MEM <- "data/phase3/P3_annual_recorded_membership.rds"
INF <- "data/badger_infection_trajectories_all_tests_inferred.rds"
MOVE <- "data/badger_movement_posterior_histories_1932_V9_FINAL.rds"
BENCH <- "data/phase3/P3_literature_benchmark_panel.rds"
MNA <- "data/phase3/P3_historical_MNA_reconstruction.rds"

for(f in c(MEM,INF,MOVE,BENCH,MNA))
  if(!file.exists(f)) stop("Missing required file: ",f)

dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)
dir.create("data/phase3",recursive=TRUE,showWarnings=FALSE)

mem <- readRDS(MEM)
inf <- readRDS(INF)
mov <- readRDS(MOVE)
bench <- readRDS(BENCH)
mna <- readRDS(MNA)

annual <- as_tibble(mem$annual_membership) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    year=as.integer(year),
    resident_socg=as.character(candidate_resident_socg),
    assignment_criterion=assignment_criterion,
    n_live_records=n_live_records,
    n_distinct_socg=n_distinct_socg
  ) %>%
  filter(!is.na(resident_socg),resident_socg!="")

if(anyDuplicated(annual[c("tattoo","year")]))
  stop("Annual resident membership duplicated by tattoo-year.")

# -----------------------------------------------------------------------------
# A. ALL-TESTS LATENT INFECTION SUMMARIES BY BADGER-YEAR
# -----------------------------------------------------------------------------

if(!all(c("tattoo","infection_time","start_year") %in% names(inf)))
  stop("Canonical infection object structure not found.")
if(!is.matrix(inf$infection_time))
  stop("inf$infection_time must be a matrix.")

INF_IDS <- trimws(as.character(inf$tattoo))
START_YEAR <- as.integer(inf$start_year)
if(anyDuplicated(INF_IDS)) stop("Duplicate infection tattoos.")

annual_inf <- annual %>%
  filter(tattoo %in% INF_IDS) %>%
  mutate(inf_row=match(tattoo,INF_IDS))

years <- sort(unique(annual_inf$year))
inf_by_year <- vector("list",length(years))

for(ii in seq_along(years)){
  y <- years[ii]
  rr <- which(annual_inf$year==y)
  rows <- annual_inf$inf_row[rr]

  q4 <- 4L*(y-START_YEAR)+4L
  q4_prev <- q4-4L
  q1 <- q4-3L

  IT <- inf$infection_time[rows,,drop=FALSE]

  p_inf_q4 <- rowMeans(IT>0L & IT<=q4)
  p_sus_start <- rowMeans(IT==0L | IT>q4_prev)
  p_incident_year <- rowMeans(IT>=q1 & IT<=q4)

  inf_by_year[[ii]] <- annual_inf[rr,] %>%
    transmute(
      tattoo,year,resident_socg,
      p_infected_q4=p_inf_q4,
      p_susceptible_start=p_sus_start,
      p_infection_event_year=p_incident_year
    )
}
badger_year_inf <- bind_rows(inf_by_year)

latent_group <- badger_year_inf %>%
  group_by(year,resident_socg) %>%
  summarise(
    latent_residents=n(),
    expected_infected_q4=sum(p_infected_q4),
    latent_prevalence_q4=mean(p_infected_q4),
    expected_susceptible_start=sum(p_susceptible_start),
    expected_incident_infections=sum(p_infection_event_year),
    latent_incidence=
      if_else(expected_susceptible_start>0,
              expected_incident_infections/expected_susceptible_start,
              NA_real_),
    .groups="drop"
  )

# -----------------------------------------------------------------------------
# B. V9 HIGH-MOBILITY POSTERIOR BY DESTINATION YEAR / RESIDENT GROUP
# -----------------------------------------------------------------------------

idx <- as_tibble(mov$interval_index) %>%
  mutate(
    interval_col=row_number(),
    tattoo=trimws(as.character(tattoo)),
    to_year=as.integer(to_year)
  )

if(ncol(mov$state_draws)!=nrow(idx))
  stop("V9 movement state matrix does not match interval index.")

move_mean <- idx %>%
  mutate(p_high=colMeans(mov$state_draws)) %>%
  left_join(
    annual %>% select(tattoo,year,resident_socg),
    by=c("tattoo","to_year"="year")
  ) %>%
  filter(!is.na(resident_socg)) %>%
  group_by(to_year,resident_socg) %>%
  summarise(
    v9_interval_n=n(),
    expected_high_mobility=sum(p_high),
    mean_p_high=mean(p_high),
    .groups="drop"
  ) %>%
  rename(year=to_year)

# -----------------------------------------------------------------------------
# C. OBSERVED RESIDENT-GROUP SWITCHING
# -----------------------------------------------------------------------------

switches <- annual %>%
  arrange(tattoo,year) %>%
  group_by(tattoo) %>%
  mutate(
    previous_year=lag(year),
    previous_socg=lag(resident_socg),
    consecutive=year-previous_year==1L,
    resident_switch=consecutive & !is.na(previous_socg) &
      resident_socg!=previous_socg
  ) %>%
  ungroup() %>%
  group_by(year,resident_socg) %>%
  summarise(
    residents_with_previous_year=sum(consecutive,na.rm=TRUE),
    incoming_resident_switches=sum(resident_switch,na.rm=TRUE),
    incoming_resident_switch_rate=
      if_else(residents_with_previous_year>0,
              incoming_resident_switches/residents_with_previous_year,
              NA_real_),
    .groups="drop"
  )

# -----------------------------------------------------------------------------
# D. CULTURE-ONLY + CAPTURE-BASED MOVEMENT BENCHMARK VARIABLES
# -----------------------------------------------------------------------------

hist_group <- as_tibble(bench$groupyear) %>%
  transmute(
    year=as.integer(year),
    resident_socg=as.character(resident_socg),
    culture_resident_count=resident_count,
    culture_incident_excretors=incident_excretors,
    culture_prevalent_excretors_start=prevalent_excretors_start,
    culture_susceptible_start=susceptible_start,
    culture_incident_proportion=incident_prop,
    culture_prior_excretor_prevalence=prior_excretor_prevalence,
    capture_group_movement_index=group_movement_index,
    capture_group_movement_n=group_movement_n
  )

mna_group <- as_tibble(mna$groupyear) %>%
  transmute(
    year=as.integer(year),
    resident_socg=as.character(mna_socg),
    historical_mna=mna_group_size,
    historical_mna_trend_pct=mna_trend_pct
  )

# -----------------------------------------------------------------------------
# E. BASE GROUP-YEAR PANEL
# -----------------------------------------------------------------------------

base <- annual %>%
  count(year,resident_socg,name="observed_resident_count") %>%
  group_by(resident_socg) %>%
  arrange(year,.by_group=TRUE) %>%
  mutate(
    previous_observed_resident_count=lag(observed_resident_count),
    observed_resident_count_change=
      observed_resident_count-previous_observed_resident_count,
    observed_resident_count_trend_pct=
      if_else(
        !is.na(previous_observed_resident_count) &
          previous_observed_resident_count>0,
        100*observed_resident_count_change/
          previous_observed_resident_count,
        NA_real_
      )
  ) %>%
  ungroup() %>%
  left_join(latent_group,by=c("year","resident_socg")) %>%
  left_join(move_mean,by=c("year","resident_socg")) %>%
  left_join(switches,by=c("year","resident_socg")) %>%
  left_join(hist_group,by=c("year","resident_socg")) %>%
  left_join(mna_group,by=c("year","resident_socg")) %>%
  mutate(
    era2018=if_else(year>=2018L,"2018_PLUS","PRE_2018")
  ) %>%
  arrange(year,resident_socg)

# -----------------------------------------------------------------------------
# F. ANNUAL SYSTEM SUMMARY
# -----------------------------------------------------------------------------

annual_system <- base %>%
  group_by(year) %>%
  summarise(
    n_resident_groups=n(),
    observed_resident_population=sum(observed_resident_count,na.rm=TRUE),

    latent_supported_groups=sum(is.finite(latent_prevalence_q4)),
    expected_infected_q4=sum(expected_infected_q4,na.rm=TRUE),
    expected_susceptible_start=sum(expected_susceptible_start,na.rm=TRUE),
    expected_incident_infections=sum(expected_incident_infections,na.rm=TRUE),
    latent_population_prevalence=
      expected_infected_q4/sum(latent_residents,na.rm=TRUE),
    latent_population_incidence=
      expected_incident_infections/expected_susceptible_start,

    culture_incident_excretors=sum(culture_incident_excretors,na.rm=TRUE),
    culture_susceptible_start=sum(culture_susceptible_start,na.rm=TRUE),
    culture_incidence=
      if_else(culture_susceptible_start>0,
              culture_incident_excretors/culture_susceptible_start,
              NA_real_),

    capture_movement_supported_groups=
      sum(is.finite(capture_group_movement_index)),
    mean_capture_group_movement=
      if_else(
        capture_movement_supported_groups>0,
        weighted.mean(
          capture_group_movement_index,
          w=pmax(capture_group_movement_n,1),
          na.rm=TRUE
        ),
        NA_real_
      ),

    v9_supported_groups=sum(is.finite(mean_p_high)),
    v9_expected_high=sum(expected_high_mobility,na.rm=TRUE),
    v9_interval_n=sum(v9_interval_n,na.rm=TRUE),
    mean_v9_p_high=
      if_else(v9_interval_n>0,v9_expected_high/v9_interval_n,NA_real_),

    incoming_resident_switches=sum(incoming_resident_switches,na.rm=TRUE),
    residents_with_previous_year=sum(residents_with_previous_year,na.rm=TRUE),
    resident_switch_rate=
      if_else(residents_with_previous_year>0,
              incoming_resident_switches/residents_with_previous_year,
              NA_real_),

    .groups="drop"
  ) %>%
  mutate(era2018=if_else(year>=2018L,"2018_PLUS","PRE_2018"))

prepost <- annual_system %>%
  filter(year<=2025L) %>%
  group_by(era2018) %>%
  summarise(
    years=n(),
    mean_groups=mean(n_resident_groups,na.rm=TRUE),
    mean_population=mean(observed_resident_population,na.rm=TRUE),
    mean_latent_prevalence=mean(latent_population_prevalence,na.rm=TRUE),
    mean_latent_incidence=mean(latent_population_incidence,na.rm=TRUE),
    mean_capture_group_movement=mean(mean_capture_group_movement,na.rm=TRUE),
    mean_v9_p_high=mean(mean_v9_p_high,na.rm=TRUE),
    mean_resident_switch_rate=mean(resident_switch_rate,na.rm=TRUE),
    .groups="drop"
  )

cat("\n============================================================\n")
cat("P3_05 — GROUP-YEAR PANEL + TEMPORAL DESCRIPTION\n")
cat("============================================================\n")
cat("Group-years:",nrow(base),"\n")
cat("Years:",min(base$year),"to",max(base$year),"\n")
cat("Distinct resident SOCGs:",n_distinct(base$resident_socg),"\n")
cat("Group-years with latent infection support:",
    sum(is.finite(base$latent_prevalence_q4)),"\n")
cat("Group-years with V9 movement support:",
    sum(is.finite(base$mean_p_high)),"\n")
cat("Group-years with capture-movement support:",
    sum(is.finite(base$capture_group_movement_index)),"\n")

cat("\nPRE/POST-2018 DESCRIPTIVE SUMMARY\n")
print(prepost,n=Inf,width=Inf)

cat("\nANNUAL SUMMARY — 2014 ONWARD\n")
print(
  annual_system %>%
    filter(year>=2014L) %>%
    select(
      year,n_resident_groups,observed_resident_population,
      latent_population_prevalence,latent_population_incidence,
      mean_capture_group_movement,mean_v9_p_high,resident_switch_rate
    ),
  n=Inf,width=Inf
)

write_csv(base,
          "results/Phase3/P3_05_groupyear_panel.csv")
write_csv(annual_system,
          "results/Phase3/P3_05_annual_system_summary.csv")
write_csv(prepost,
          "results/Phase3/P3_05_prepost2018_descriptive.csv")

saveRDS(
  list(
    groupyear=base,
    annual_system=annual_system,
    prepost2018=prepost,
    badger_year_infection=badger_year_inf,
    definitions=list(
      resident_group="P3_01 published Woodchester annual assignment",
      latent_prevalence="posterior probability infected by Q4, averaged/summed over annual residents",
      latent_incidence="expected posterior infection events during year / expected susceptible residents at start of year",
      capture_group_movement="published-style annual capture-to-previous-capture movement index",
      v9_high_mobility="posterior mean probability of high mobility for annual movement interval ending in that year",
      resident_switch="change in annual resident SOCG across consecutive observed years",
      era2018="descriptive marker only"
    )
  ),
  "data/phase3/P3_groupyear_temporal_panel.rds"
)

cat("\nP3_05 COMPLETE\n")
