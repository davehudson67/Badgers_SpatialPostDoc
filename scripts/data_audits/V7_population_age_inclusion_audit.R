# =============================================================================
# WOODCHESTER V7 - INCLUSIVE POPULATION + AGE AUDIT
#
# Aim
#   Identify the MAXIMUM scientifically usable population for movement, V7a and
#   V7b without excluding individuals simply to force a common analysis subset.
#
# Principle
#   KEEP individuals unless the specific analysis genuinely cannot use them.
#   Missing sex/age are reported, not silently filtered. Adult first-captures are
#   retained even though exact chronological age is unknown.
#
# Outputs
#   results/V7_population_inclusion_audit.csv
#   results/V7_population_flow.csv
#   results/V7_age_support_by_year.csv
#   results/V7_population_inclusion_audit.rds
# =============================================================================

library(tidyverse)
library(lubridate)

MAX_YEAR <- 2025L
MIN_LIVE_YEARS_MOVEMENT <- 2L

ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
INDIVIDUAL_FILE <- "data/badger_individuals.rds"
SETT_FILE <- "data/WoodchesterSettLocations.csv"
INFECTION_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"

OUT_DETAIL <- "results/V7_population_inclusion_audit.csv"
OUT_FLOW <- "results/V7_population_flow.csv"
OUT_AGE <- "results/V7_age_support_by_year.csv"
OUT_RDS <- "results/V7_population_inclusion_audit.rds"

dir.create("results",showWarnings=FALSE,recursive=TRUE)
for(f in c(ENCOUNTER_FILE,INDIVIDUAL_FILE,SETT_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

enc <- readRDS(ENCOUNTER_FILE)
ind <- readRDS(INDIVIDUAL_FILE)
sett_raw <- read_csv(SETT_FILE,show_col_types=FALSE)

clean_sett <- function(x) x %>% as.character() %>% toupper() %>%
  str_replace_all("[[:punct:]]"," ") %>% str_squish() %>%
  str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>% str_replace_all("\\s+","")

sett_aliases <- c("CHESTNUT"="CHESNUT","JACKS"="JACKSMIREY","GRAVEL"="GRAVELPIT",
                  "BUCKHOLE"="BUCKHOLT","TOPSETT"="TOP","FOXCUB"="FOX","GULLEY"="GULLY",
                  "BLACKBERRY"="BRAMBLE","BOC"="BOG","CEDARBANK"="CEDAR","CLAYTRAP"="CLAY",
                  "CLIFF"="CLIFFFACE","DINGLEVALLEY"="DINGLE")
clean_sett2 <- function(x){
  z <- clean_sett(x)
  for(a in names(sett_aliases)) z[z==a] <- sett_aliases[[a]]
  z
}

name_col <- intersect(c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name"),names(sett_raw))[1]
x_col <- intersect(c("SettX","sett_x","X","x","Easting","easting"),names(sett_raw))[1]
y_col <- intersect(c("SettY","sett_y","Y","y","Northing","northing"),names(sett_raw))[1]
if(any(is.na(c(name_col,x_col,y_col)))) stop("Could not identify sett name/X/Y columns.")
sett_xy <- sett_raw %>%
  transmute(Sett_Clean=clean_sett2(.data[[name_col]]),x=as.numeric(.data[[x_col]]),y=as.numeric(.data[[y_col]])) %>%
  filter(!is.na(Sett_Clean),Sett_Clean!="",!is.na(x),!is.na(y)) %>%
  distinct(Sett_Clean,.keep_all=TRUE)

# ---- canonical individual table ---------------------------------------------
# year_fc is the year of first capture. For animals first caught as cub/yearling
# it supports an inferred birth year. Adult entrants are deliberately retained
# with exact age unknown.
individuals <- ind %>%
  transmute(
    individual_id=as.integer(individual_id),
    tattoo=trimws(as.character(tattoo)),
    sex_raw=as.character(sex),
    age_fc_raw=as.character(age_fc),
    year_fc=as.integer(year_fc)
  ) %>%
  mutate(
    sex_clean=toupper(str_squish(sex_raw)),
    sex_class=case_when(sex_clean %in% c("F","FEMALE")~"Female",
                        sex_clean %in% c("M","MALE")~"Male",
                        TRUE~"Unknown"),
    age_fc=toupper(str_squish(age_fc_raw)),
    age_entry_class=case_when(age_fc=="CUB"~"Cub",
                              age_fc=="YEARLING"~"Yearling",
                              age_fc=="ADULT"~"Adult_exact_age_unknown",
                              TRUE~"Unknown"),
    exact_age_supported=age_entry_class %in% c("Cub","Yearling") & !is.na(year_fc),
    inferred_birth_year=case_when(age_entry_class=="Cub" & !is.na(year_fc)~year_fc,
                                  age_entry_class=="Yearling" & !is.na(year_fc)~year_fc-1L,
                                  TRUE~NA_integer_)
  ) %>%
  distinct(individual_id,.keep_all=TRUE)

# ---- all live encounters with and without usable spatial coordinates ---------
live_all <- enc %>%
  mutate(individual_id=as.integer(individual_id),tattoo=trimws(as.character(tattoo)),
         primary_year=as.integer(primary_year),trap_season=as.integer(trap_season),
         Sett_Clean=clean_sett2(sett)) %>%
  filter(has_live_capture,!is.na(primary_year),primary_year<=MAX_YEAR,trap_season %in% 1:4)

live_spatial <- live_all %>%
  left_join(sett_xy,by="Sett_Clean") %>%
  filter(!is.na(x),!is.na(y))

live_stats <- live_all %>%
  group_by(individual_id) %>%
  summarise(n_live_encounters=n(),n_live_years_any=n_distinct(primary_year),
            first_live_year_any=min(primary_year),last_live_year_any=max(primary_year),.groups="drop")

spatial_stats <- live_spatial %>%
  group_by(individual_id) %>%
  summarise(n_spatial_encounters=n(),n_spatial_years=n_distinct(primary_year),
            first_spatial_year=min(primary_year),last_spatial_year=max(primary_year),
            spatial_year_span=last_spatial_year-first_spatial_year,.groups="drop")

# Infection trajectories are optional for the population audit. Their absence
# must never remove an animal from the movement population.
inf_ids <- character()
if(file.exists(INFECTION_FILE)){
  inf <- readRDS(INFECTION_FILE)
  if("tattoo" %in% names(inf)) inf_ids <- trimws(as.character(inf$tattoo))
}

pop <- individuals %>%
  left_join(live_stats,by="individual_id") %>%
  left_join(spatial_stats,by="individual_id") %>%
  mutate(
    across(c(n_live_encounters,n_live_years_any,n_spatial_encounters,n_spatial_years),~replace_na(.x,0L)),
    has_any_live=n_live_years_any>=1L,
    has_any_spatial_year=n_spatial_years>=1L,
    has_two_spatial_years=n_spatial_years>=MIN_LIVE_YEARS_MOVEMENT,
    has_known_sex=sex_class!="Unknown",
    has_entry_age_class=age_entry_class!="Unknown",
    has_infection_trajectory=tattoo %in% inf_ids,

    # Movement requires repeated spatial information. Sex and age are NOT hard
    # filters here: unknown values should be accommodated in the model or a
    # sensitivity analysis rather than deleting otherwise informative animals.
    movement_eligible=has_two_spatial_years,

    # V7a predicts a later movement-state transition from a previous movement
    # state, so structurally it needs at least two annual movement intervals.
    # This is based on annual span, not number of capture years, because internal
    # unobserved years are represented by latent annual AC/state processes.
    v7a_structurally_eligible=movement_eligible & !is.na(spatial_year_span) & spatial_year_span>=2L & has_infection_trajectory,

    # V7b also needs a movement interval followed by a subsequent infection-risk
    # year. Exact at-risk contribution remains draw-specific after infection
    # trajectories are paired; this flag is only the maximum structural pool.
    v7b_structurally_eligible=movement_eligible & !is.na(spatial_year_span) & spatial_year_span>=2L & has_infection_trajectory,

    exclusion_from_movement=case_when(
      movement_eligible~NA_character_,
      !has_any_live~"No live capture <=2025",
      !has_any_spatial_year~"Live capture(s), but no capture at a sett with usable coordinates",
      n_spatial_years<2L~"Only one spatially usable live year",
      TRUE~"Other"
    )
  )

# ---- age by year for every movement-eligible animal --------------------------
# Exact chronological age is reconstructed only for cub/yearling entrants.
# Adult entrants and unknown-entry animals remain in the data with age unknown.
age_year <- pop %>%
  filter(movement_eligible) %>%
  select(individual_id,tattoo,sex_class,age_entry_class,exact_age_supported,inferred_birth_year,
         first_spatial_year,last_spatial_year) %>%
  filter(!is.na(first_spatial_year),!is.na(last_spatial_year)) %>%
  rowwise() %>%
  mutate(primary_year=list(seq.int(first_spatial_year,last_spatial_year))) %>%
  ungroup() %>%
  unnest(primary_year) %>%
  mutate(age_years=if_else(exact_age_supported,primary_year-inferred_birth_year,NA_integer_),
         age_model_class=case_when(
           exact_age_supported & age_years<=1L~"0-1",
           exact_age_supported & age_years==2L~"2",
           exact_age_supported & age_years>=3L & age_years<=5L~"3-5",
           exact_age_supported & age_years>=6L~"6+",
           age_entry_class=="Adult_exact_age_unknown"~"Adult_exact_age_unknown",
           TRUE~"Age_unknown"
         ))

# ---- transparent flow table --------------------------------------------------
flow <- tribble(
  ~stage,~n,
  "All individuals in individual snapshot",nrow(pop),
  "At least one live capture <=2025",sum(pop$has_any_live),
  "At least one live year with usable sett coordinates",sum(pop$has_any_spatial_year),
  "At least two spatially usable live years: maximum movement pool",sum(pop$movement_eligible),
  "Movement pool with known sex",sum(pop$movement_eligible & pop$has_known_sex),
  "Movement pool with exact/near-exact age reconstructable (cub/yearling entry)",sum(pop$movement_eligible & pop$exact_age_supported),
  "Movement pool adult entrants retained with exact age unknown",sum(pop$movement_eligible & pop$age_entry_class=="Adult_exact_age_unknown"),
  "Movement pool with age entry class unknown retained",sum(pop$movement_eligible & pop$age_entry_class=="Unknown"),
  "Structurally eligible for V7a before posterior-history conditions",sum(pop$v7a_structurally_eligible),
  "Structurally eligible for V7b before posterior-history conditions",sum(pop$v7b_structurally_eligible)
)

write_csv(pop,OUT_DETAIL)
write_csv(flow,OUT_FLOW)
write_csv(age_year,OUT_AGE)
saveRDS(list(population=pop,flow=flow,age_by_year=age_year,settings=list(max_year=MAX_YEAR,min_live_years_movement=MIN_LIVE_YEARS_MOVEMENT)),OUT_RDS)

cat("\n============================================================\n")
cat("V7 INCLUSIVE POPULATION + AGE AUDIT\n")
cat("============================================================\n")
print(flow,n=Inf)
cat("\nMovement exclusions:\n")
print(pop %>% count(exclusion_from_movement,sort=TRUE),n=Inf)
cat("\nEntry-age support within movement pool:\n")
print(pop %>% filter(movement_eligible) %>% count(age_entry_class,exact_age_supported,sort=TRUE),n=Inf)
cat("\nSex support within movement pool:\n")
print(pop %>% filter(movement_eligible) %>% count(sex_class,sort=TRUE),n=Inf)
cat("\nWrote:\n",OUT_DETAIL,"\n",OUT_FLOW,"\n",OUT_AGE,"\n",OUT_RDS,"\n",sep="")
