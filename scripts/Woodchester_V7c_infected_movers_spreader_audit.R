# =============================================================================
# WOODCHESTER V7c — INFECTED MOVERS AS POTENTIAL SPREADERS: FIRST AUDIT
#
# PURPOSE
# -------
# This is the first step in testing whether infected high-mobility badgers may
# contribute disproportionately to BETWEEN-GROUP transmission.
#
# It does NOT yet fit the recipient infection model. First it establishes:
#   1. how many observed Excretor / Super excretor records exist;
#   2. how many can be aligned to V7b-compatible movement intervals;
#   3. whether those animals have higher posterior probability of high mobility;
#   4. how often they are observed changing social group / sett;
#   5. how many group-years contain candidate infected mover arrivals.
#
# IMPORTANT
# ---------
# "Super excretor" is kept as the database disease-state label. The biological
# definition is the Woodchester classification based on culture-positive
# shedding from >=2 body/sample sites at the same capture occasion. This script
# does not reconstruct that classification from diagnostic rows; it uses the
# already-curated capture-level disease_status field.
#
# A disease state observed in destination year t is evidence that the badger was
# in that state at some capture in year t. It is NOT proof that it was shedding
# at the exact instant it moved. We therefore describe these as candidate
# spreading events until the prospective recipient analysis is fitted.
# =============================================================================

library(tidyverse)
library(lubridate)

MOVE_FILE   <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
ANNUAL_FILE <- "data/badger_annual_observed_sett_locations.rds"

for(f in c(MOVE_FILE,ENCOUNTER_FILE,ANNUAL_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

mov <- readRDS(MOVE_FILE)
enc <- as_tibble(readRDS(ENCOUNTER_FILE))
annual <- as_tibble(readRDS(ANNUAL_FILE))

dir.create("results",showWarnings=FALSE,recursive=TRUE)
dir.create("data",showWarnings=FALSE,recursive=TRUE)

# =============================================================================
# 1. NORMALISE OBSERVED DISEASE STATES
# =============================================================================

if(!"disease_status" %in% names(enc))
  stop("badger_encounters_useful.rds has no disease_status column.")
if(!"capture_date" %in% names(enc))
  stop("badger_encounters_useful.rds has no capture_date column.")
if(!"tattoo" %in% names(enc))
  stop("badger_encounters_useful.rds has no tattoo column.")

if(!"primary_year" %in% names(enc))
  enc$primary_year <- year(as.Date(enc$capture_date))

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

status_rank <- c("Negative"=1L,"Exposed"=2L,"Excretor"=3L,"Super excretor"=4L)

status_occ <- enc %>%
  transmute(
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    capture_date=as.Date(capture_date),
    year=as.integer(primary_year),
    socg=if("socg" %in% names(enc)) as.character(socg) else NA_character_,
    sett=if("sett" %in% names(enc)) as.character(sett) else NA_character_,
    disease_status_raw=as.character(disease_status),
    disease_class=classify_disease(disease_status)
  ) %>%
  mutate(disease_rank=unname(status_rank[disease_class])) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(year),!is.na(disease_class))

unknown_status <- enc %>%
  transmute(raw=str_squish(as.character(disease_status)),classified=classify_disease(disease_status)) %>%
  filter(!is.na(raw),raw!="",is.na(classified)) %>%
  count(raw,sort=TRUE)

if(nrow(unknown_status)){
  cat("\nWARNING: Unclassified non-empty disease_status values:\n")
  print(unknown_status,n=Inf,width=Inf)
}

status_capture_audit <- status_occ %>%
  mutate(disease_class=factor(disease_class,levels=names(status_rank))) %>%
  group_by(disease_class) %>%
  summarise(
    capture_occasions=n(),
    badgers=n_distinct(tattoo),
    years=n_distinct(year),
    first_year=min(year),
    last_year=max(year),
    .groups="drop"
  )

# Highest observed disease state in each badger-year. If tied, use latest
# capture so that the retained location is deterministic.
status_year <- status_occ %>%
  arrange(tattoo,year,desc(disease_rank),desc(capture_date)) %>%
  group_by(tattoo,year) %>%
  slice(1) %>%
  ungroup() %>%
  transmute(
    tattoo,year,
    disease_class,
    disease_rank,
    status_date=capture_date,
    status_socg=socg,
    status_sett=sett
  )

# =============================================================================
# 2. EXACT OBSERVED ANNUAL LOCATIONS
# =============================================================================

need_annual <- c("tattoo","year","annual_socg","annual_sett")
miss_annual <- setdiff(need_annual,names(annual))
if(length(miss_annual))
  stop("Annual location file is missing: ",paste(miss_annual,collapse=", "))

annual2 <- annual %>%
  transmute(
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    year=as.integer(year),
    annual_socg=as.character(annual_socg),
    annual_sett=as.character(annual_sett)
  ) %>%
  distinct(tattoo,year,.keep_all=TRUE)

# =============================================================================
# 3. V7b-COMPATIBLE MOVEMENT INTERVALS + POSTERIOR P(HIGH MOBILITY)
# =============================================================================

idx <- as_tibble(mov$interval_index) %>%
  mutate(
    interval_col=row_number(),
    model_i=as.integer(model_i),
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year)
  ) %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last)

if(ncol(mov$state_draws) < max(idx$interval_col))
  stop("Movement state_draws do not cover interval_index columns.")

p_high_all <- colMeans(mov$state_draws==1L,na.rm=TRUE)
idx$p_high <- p_high_all[idx$interval_col]

from_loc <- annual2 %>%
  rename(from_year=year,from_socg=annual_socg,from_sett=annual_sett)

to_loc <- annual2 %>%
  rename(to_year=year,to_socg=annual_socg,to_sett=annual_sett)

intervals <- idx %>%
  left_join(from_loc,by=c("tattoo","from_year")) %>%
  left_join(to_loc,by=c("tattoo","to_year")) %>%
  left_join(status_year,by=c("tattoo","to_year"="year")) %>%
  mutate(
    observed_socg_switch=case_when(
      !is.na(from_socg) & from_socg!="" & !is.na(to_socg) & to_socg!="" ~ from_socg!=to_socg,
      TRUE ~ NA
    ),
    observed_sett_switch=case_when(
      !is.na(from_sett) & from_sett!="" & !is.na(to_sett) & to_sett!="" ~ from_sett!=to_sett,
      TRUE ~ NA
    ),
    status_group_confirmed=case_when(
      !is.na(status_socg) & status_socg!="" & !is.na(to_socg) & to_socg!="" ~ status_socg==to_socg,
      TRUE ~ NA
    ),
    p_high_ge_0_5=is.finite(p_high) & p_high>=0.5,
    infectious_observed=!is.na(disease_rank) & disease_rank>=3L,
    super_observed=!is.na(disease_rank) & disease_rank==4L
  )

# =============================================================================
# 4. MOVEMENT SUMMARY BY OBSERVED DISEASE STATE
# =============================================================================

movement_by_status <- intervals %>%
  filter(!is.na(disease_class)) %>%
  mutate(disease_class=factor(disease_class,levels=names(status_rank))) %>%
  group_by(disease_class) %>%
  summarise(
    movement_intervals=n(),
    badgers=n_distinct(tattoo),
    median_p_high=median(p_high,na.rm=TRUE),
    mean_p_high=mean(p_high,na.rm=TRUE),
    intervals_p_high_ge_0_5=sum(p_high_ge_0_5,na.rm=TRUE),
    proportion_p_high_ge_0_5=mean(p_high_ge_0_5,na.rm=TRUE),
    socg_switch_supported=sum(!is.na(observed_socg_switch)),
    observed_socg_switches=sum(observed_socg_switch %in% TRUE),
    proportion_socg_switch=if_else(socg_switch_supported>0,
                                   observed_socg_switches/socg_switch_supported,NA_real_),
    sett_switch_supported=sum(!is.na(observed_sett_switch)),
    observed_sett_switches=sum(observed_sett_switch %in% TRUE),
    status_destination_group_confirmed=sum(status_group_confirmed %in% TRUE),
    .groups="drop"
  )

# =============================================================================
# 5. EXCRETOR / SUPER-EXCRETOR CANDIDATE SOURCE EVENTS
# =============================================================================

candidate_sources <- intervals %>%
  filter(infectious_observed,!is.na(to_socg),to_socg!="") %>%
  transmute(
    tattoo,
    year=to_year,
    destination_socg=to_socg,
    destination_sett=to_sett,
    disease_class,
    disease_rank,
    status_date,
    status_socg,
    status_sett,
    status_group_confirmed,
    p_high,
    p_high_ge_0_5,
    observed_socg_switch,
    observed_sett_switch,
    from_socg,
    from_sett
  )

# Liberal table: status observed somewhere in that badger-year and annual
# destination group known.
source_group_year_all <- candidate_sources %>%
  group_by(year,destination_socg) %>%
  summarise(
    n_excretor_or_super=n(),
    n_super=sum(disease_class=="Super excretor"),
    expected_high_excretor_or_super=sum(p_high,na.rm=TRUE),
    expected_high_super=sum(if_else(disease_class=="Super excretor",p_high,0),na.rm=TRUE),
    n_high_ge_0_5=sum(p_high_ge_0_5,na.rm=TRUE),
    n_super_high_ge_0_5=sum(disease_class=="Super excretor" & p_high_ge_0_5,na.rm=TRUE),
    n_observed_socg_arrivals=sum(observed_socg_switch %in% TRUE),
    n_super_observed_socg_arrivals=sum(disease_class=="Super excretor" & observed_socg_switch %in% TRUE),
    .groups="drop"
  )

# Strict table: the disease-status capture itself is recorded in the same social
# group as the annual destination group.
source_group_year_strict <- candidate_sources %>%
  filter(status_group_confirmed %in% TRUE) %>%
  group_by(year,destination_socg) %>%
  summarise(
    n_excretor_or_super=n(),
    n_super=sum(disease_class=="Super excretor"),
    expected_high_excretor_or_super=sum(p_high,na.rm=TRUE),
    expected_high_super=sum(if_else(disease_class=="Super excretor",p_high,0),na.rm=TRUE),
    n_high_ge_0_5=sum(p_high_ge_0_5,na.rm=TRUE),
    n_super_high_ge_0_5=sum(disease_class=="Super excretor" & p_high_ge_0_5,na.rm=TRUE),
    n_observed_socg_arrivals=sum(observed_socg_switch %in% TRUE),
    n_super_observed_socg_arrivals=sum(disease_class=="Super excretor" & observed_socg_switch %in% TRUE),
    .groups="drop"
  )

super_summary <- tibble(
  measure=c(
    "Super-excretor capture occasions",
    "Unique super-excretor badgers",
    "Super-excretor badger-years",
    "Super-excretor badger-years linked to V7b-compatible movement intervals",
    "Linked intervals with disease capture confirmed in destination group",
    "Linked intervals with posterior P(high mobility) >= 0.5",
    "Linked intervals with exact observed social-group switch",
    "Destination-group-confirmed intervals with exact observed social-group switch"
  ),
  n=c(
    sum(status_occ$disease_class=="Super excretor"),
    n_distinct(status_occ$tattoo[status_occ$disease_class=="Super excretor"]),
    sum(status_year$disease_class=="Super excretor"),
    sum(intervals$disease_class=="Super excretor",na.rm=TRUE),
    sum(intervals$disease_class=="Super excretor" & intervals$status_group_confirmed %in% TRUE,na.rm=TRUE),
    sum(intervals$disease_class=="Super excretor" & intervals$p_high_ge_0_5,na.rm=TRUE),
    sum(intervals$disease_class=="Super excretor" & intervals$observed_socg_switch %in% TRUE,na.rm=TRUE),
    sum(intervals$disease_class=="Super excretor" & intervals$status_group_confirmed %in% TRUE & intervals$observed_socg_switch %in% TRUE,na.rm=TRUE)
  )
)

# =============================================================================
# 6. PRINT AUDIT
# =============================================================================

cat("\n============================================================\n")
cat("V7c INFECTED MOVERS / SUPER-EXCRETOR AUDIT\n")
cat("============================================================\n")
cat("V7b-compatible movement intervals:",nrow(intervals),"\n")
cat("Badgers represented:",n_distinct(intervals$tattoo),"\n\n")

cat("OBSERVED DISEASE-STATE CAPTURES\n")
print(status_capture_audit,n=Inf,width=Inf)

cat("\nMOVEMENT BY DISEASE STATE OBSERVED IN DESTINATION YEAR\n")
print(movement_by_status,n=Inf,width=Inf)

cat("\nSUPER-EXCRETOR SUPPORT\n")
print(super_summary,n=Inf,width=Inf)

cat("\nCANDIDATE INFECTIOUS SOURCE GROUP-YEARS\n")
cat("Liberal group-years:",nrow(source_group_year_all),"\n")
cat("Strict destination-confirmed group-years:",nrow(source_group_year_strict),"\n")
cat("Strict group-years with >=1 super excretor:",sum(source_group_year_strict$n_super>0),"\n")
cat("Strict group-years with >=1 observed SG-switching excretor/super:",sum(source_group_year_strict$n_observed_socg_arrivals>0),"\n")
cat("Strict group-years with >=1 observed SG-switching SUPER excretor:",sum(source_group_year_strict$n_super_observed_socg_arrivals>0),"\n")

cat("\nINTERPRETATION\n")
cat("- This is an audit, not yet a transmission-effect model.\n")
cat("- P(high mobility) comes from the final Stage-1 movement posterior histories.\n")
cat("- Social-group switches require exact observed groups in consecutive years.\n")
cat("- 'Strict' candidate sources require the disease-status capture itself to be in the annual destination group.\n")
cat("- The next model should use susceptible OTHER badgers as recipients and test whether arrival/presence of an observed Excretor or Super excretor predicts their later acquisition.\n")
cat("- Background same-group infection pressure should be retained so mover-specific spreading is separated from general local prevalence.\n")

# =============================================================================
# 7. SAVE
# =============================================================================

saveRDS(
  list(
    status_occ=status_occ,
    status_year=status_year,
    movement_intervals=intervals,
    candidate_sources=candidate_sources,
    source_group_year_all=source_group_year_all,
    source_group_year_strict=source_group_year_strict,
    status_capture_audit=status_capture_audit,
    movement_by_status=movement_by_status,
    super_summary=super_summary
  ),
  "data/badger_V7c_infected_mover_spreader_audit.rds"
)

write_csv(status_capture_audit,"results/V7c_status_capture_audit.csv")
write_csv(movement_by_status,"results/V7c_movement_by_observed_disease_status.csv")
write_csv(super_summary,"results/V7c_super_excretor_support.csv")
write_csv(source_group_year_all,"results/V7c_candidate_source_group_year_all.csv")
write_csv(source_group_year_strict,"results/V7c_candidate_source_group_year_strict.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_infected_mover_spreader_audit.rds\n")
cat("  results/V7c_status_capture_audit.csv\n")
cat("  results/V7c_movement_by_observed_disease_status.csv\n")
cat("  results/V7c_super_excretor_support.csv\n")
cat("  results/V7c_candidate_source_group_year_all.csv\n")
cat("  results/V7c_candidate_source_group_year_strict.csv\n")
