# PHASE 3 P3_03 — historical MNA reconstruction audit
#
# Purpose
#   Reconstruct a transparent minimum-number-alive (MNA) group-size series for
#   the 1990-2004 Vicente benchmark, using the published historical core-anchor
#   scaffold from P3_02d.
#
# Important
#   This is a reconstruction/audit, not yet an exact claim of the unpublished
#   original Woodchester MNA data product.
#
# MNA principle
#   A marked badger is known alive in calendar year y if y lies between its
#   first and last live-capture years. Years with no capture are therefore
#   back-filled from later recaptures.
#
# Group assignment for missed years
#   - observed annual resident SOCG from P3_01 where available;
#   - if missed, same flanking resident group -> assign that group;
#   - if flanking groups differ, assign the temporally nearest observed resident
#     group; exact ties are left unresolved rather than forced.
#
# Validation targets from Vicente et al. (2007)
#   - annual core population roughly 177-300, peaking in 1999;
#   - annual mean MNA group size range 7.00-11.82;
#   - mean annual group size across 1990-2004 about 9.61.
#
# Outputs
#   data/phase3/P3_historical_MNA_reconstruction.rds
#   results/Phase3/P3_03_MNA_population_by_year.csv
#   results/Phase3/P3_03_MNA_groupyear.csv
#   results/Phase3/P3_03_MNA_assignment_audit.csv

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

MEM <- "data/phase3/P3_annual_recorded_membership.rds"
ENC <- "data/badger_encounters_useful.rds"
ANCH <- "data/phase3/P3_published_core_anchor_audit.rds"

for(f in c(MEM,ENC,ANCH)) if(!file.exists(f)) stop("Missing: ",f)
dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)
dir.create("data/phase3",recursive=TRUE,showWarnings=FALSE)

mem <- readRDS(MEM)
enc <- as_tibble(readRDS(ENC))
anch <- readRDS(ANCH)

clean_sg <- function(x){
  z <- toupper(stringr::str_squish(as.character(x)))
  z <- stringr::str_replace_all(z,"[^A-Z0-9]","")
  z[z==""|z=="NA"] <- NA_character_
  dplyr::recode(z,
                "CHESTNUT"="BEECH",
                "HOLLOWTREE"="NETTLE",
                "JACKS"="JACKSMIREY",
                "COLLIERS"="COLLIERSWOOD",
                .default=z)
}

core_labels <- unique(as.character(anch$anchor$socg))

annual_obs <- as_tibble(mem$annual_membership) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    year=as.integer(year),
    observed_resident_socg=clean_sg(candidate_resident_socg),
    assignment_criterion=as.integer(assignment_criterion)
  ) %>%
  filter(!is.na(observed_resident_socg)) %>%
  distinct(tattoo,year,.keep_all=TRUE)

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    capture_date=as.Date(capture_date),
    year=lubridate::year(capture_date),
    socg=clean_sg(socg)
  ) %>%
  filter(tattoo!="",!is.na(capture_date))

bounds <- live %>%
  group_by(tattoo) %>%
  summarise(
    first_live_year=min(year),
    last_live_year=max(year),
    .groups="drop"
  ) %>%
  filter(last_live_year>=1989L,first_live_year<=2004L)

# Expand every marked animal through all years in which it is known alive.
alive_years <- bounds %>%
  mutate(year=map2(first_live_year,last_live_year,seq.int)) %>%
  select(-first_live_year,-last_live_year) %>%
  unnest(year) %>%
  filter(year>=1989L,year<=2004L) %>%
  left_join(annual_obs,by=c("tattoo","year"))

# For missed years, use nearest observed annual resident assignment.
obs_split <- split(annual_obs,annual_obs$tattoo)

fill_one <- function(tat,y,observed){
  if(!is.na(observed))
    return(tibble(mna_socg=observed,mna_group_rule="OBSERVED_ANNUAL_SOCG",
                  prev_group=NA_character_,next_group=NA_character_,
                  prev_gap=NA_integer_,next_gap=NA_integer_))

  h <- obs_split[[tat]]
  if(is.null(h) || !nrow(h))
    return(tibble(mna_socg=NA_character_,mna_group_rule="NO_SOCG_HISTORY",
                  prev_group=NA_character_,next_group=NA_character_,
                  prev_gap=NA_integer_,next_gap=NA_integer_))

  pre <- h %>% filter(year<y) %>% arrange(desc(year)) %>% slice(1)
  post <- h %>% filter(year>y) %>% arrange(year) %>% slice(1)

  pg <- if(nrow(pre)) pre$observed_resident_socg[1] else NA_character_
  ng <- if(nrow(post)) post$observed_resident_socg[1] else NA_character_
  pgy <- if(nrow(pre)) y-pre$year[1] else NA_integer_
  ngy <- if(nrow(post)) post$year[1]-y else NA_integer_

  if(!is.na(pg) && !is.na(ng) && pg==ng)
    return(tibble(mna_socg=pg,mna_group_rule="FLANKS_AGREE",
                  prev_group=pg,next_group=ng,prev_gap=pgy,next_gap=ngy))

  if(!is.na(pg) && !is.na(ng)){
    if(pgy<ngy)
      return(tibble(mna_socg=pg,mna_group_rule="NEAREST_PREVIOUS",
                    prev_group=pg,next_group=ng,prev_gap=pgy,next_gap=ngy))
    if(ngy<pgy)
      return(tibble(mna_socg=ng,mna_group_rule="NEAREST_NEXT",
                    prev_group=pg,next_group=ng,prev_gap=pgy,next_gap=ngy))
    return(tibble(mna_socg=NA_character_,mna_group_rule="EQUIDISTANT_GROUP_CHANGE_UNRESOLVED",
                  prev_group=pg,next_group=ng,prev_gap=pgy,next_gap=ngy))
  }

  # These are rare inside the first:last capture bracket, but retain explicitly.
  if(!is.na(pg))
    return(tibble(mna_socg=pg,mna_group_rule="PREVIOUS_ONLY",
                  prev_group=pg,next_group=ng,prev_gap=pgy,next_gap=ngy))
  if(!is.na(ng))
    return(tibble(mna_socg=ng,mna_group_rule="NEXT_ONLY",
                  prev_group=pg,next_group=ng,prev_gap=pgy,next_gap=ngy))

  tibble(mna_socg=NA_character_,mna_group_rule="NO_SOCG_HISTORY",
         prev_group=pg,next_group=ng,prev_gap=pgy,next_gap=ngy)
}

alive_years <- alive_years %>%
  mutate(.fill=pmap(list(tattoo,year,observed_resident_socg),fill_one)) %>%
  unnest(.fill) %>%
  mutate(
    in_historical_core=mna_socg %in% core_labels,
    observed_in_year=!is.na(observed_resident_socg)
  )

assignment_audit <- alive_years %>%
  filter(year>=1990L,year<=2004L) %>%
  count(mna_group_rule,name="badger_years",sort=TRUE) %>%
  mutate(pct=100*badger_years/sum(badger_years))

groupyear <- alive_years %>%
  filter(year>=1990L,year<=2004L,in_historical_core,!is.na(mna_socg)) %>%
  count(year,mna_socg,name="mna_group_size") %>%
  group_by(mna_socg) %>%
  arrange(year,.by_group=TRUE) %>%
  mutate(
    previous_mna=lag(mna_group_size),
    mna_trend_pct=if_else(
      !is.na(previous_mna) & previous_mna>0,
      100*(mna_group_size-previous_mna)/previous_mna,
      NA_real_
    )
  ) %>%
  ungroup()

# Preserve annual core groups that had residents observed but no reconstructed
# MNA row only if such a case exists; MNA=0 is not silently invented.
population_year <- groupyear %>%
  group_by(year) %>%
  summarise(
    mna_population=sum(mna_group_size),
    n_groups_with_mna=n(),
    mean_group_mna=mean(mna_group_size),
    median_group_mna=median(mna_group_size),
    min_group_mna=min(mna_group_size),
    max_group_mna=max(mna_group_size),
    .groups="drop"
  ) %>%
  complete(year=1990:2004)

# Observed annual resident counts for comparison.
observed_core <- annual_obs %>%
  filter(year>=1990L,year<=2004L,observed_resident_socg %in% core_labels) %>%
  count(year,observed_resident_socg,name="observed_residents") %>%
  group_by(year) %>%
  summarise(
    observed_population=sum(observed_residents),
    observed_groups=n(),
    observed_mean_group_size=mean(observed_residents),
    .groups="drop"
  )

population_year <- population_year %>%
  left_join(observed_core,by="year") %>%
  mutate(
    mna_minus_observed=mna_population-observed_population,
    mna_uplift_pct=100*mna_minus_observed/observed_population
  )

cat("\n============================================================\n")
cat("P3_03 — HISTORICAL MNA RECONSTRUCTION AUDIT\n")
cat("============================================================\n")
cat("Historical core anchor labels:",length(core_labels),"\n\n")

cat("MNA GROUP-ASSIGNMENT RULES\n")
print(assignment_audit,n=Inf,width=Inf)

cat("\nANNUAL POPULATION / GROUP-SIZE SERIES\n")
print(population_year,n=Inf,width=Inf)

cat("\nVICENTE BENCHMARK CHECKS\n")
cat("Reconstructed MNA population range:",
    paste(range(population_year$mna_population,na.rm=TRUE),collapse="-"),"\n")
cat("Year of reconstructed population maximum:",
    paste(population_year$year[
      population_year$mna_population==max(population_year$mna_population,na.rm=TRUE)
    ],collapse=", "),"\n")
cat("Published Vicente population range: 177-300; peak 1999.\n")
cat("Reconstructed annual mean group-MNA range:",
    paste(round(range(population_year$mean_group_mna,na.rm=TRUE),2),collapse="-"),"\n")
cat("Mean of annual mean group MNA:",
    round(mean(population_year$mean_group_mna,na.rm=TRUE),2),"\n")
cat("Published Vicente annual mean group-size range: 7.00-11.82; overall mean 9.61.\n")

cat("\nUNRESOLVED MISSED-YEAR GROUP ASSIGNMENTS:",
    sum(alive_years$mna_group_rule=="EQUIDISTANT_GROUP_CHANGE_UNRESOLVED",na.rm=TRUE),"\n")

write_csv(population_year,
          "results/Phase3/P3_03_MNA_population_by_year.csv")
write_csv(groupyear,
          "results/Phase3/P3_03_MNA_groupyear.csv")
write_csv(assignment_audit,
          "results/Phase3/P3_03_MNA_assignment_audit.csv")

saveRDS(
  list(
    alive_years=alive_years,
    groupyear=groupyear,
    population_year=population_year,
    assignment_audit=assignment_audit,
    core_labels=core_labels,
    definition=list(
      alive="calendar year lies between first and last live-capture year",
      observed_group="P3_01 published annual resident-group assignment",
      missed_year_group="same flanks if possible; otherwise temporally nearest observed annual resident group; exact change-point ties unresolved",
      caveat="transparent reconstruction of MNA; exact historical APHA annual bait-marking/MNA product remains preferable if recovered"
    )
  ),
  "data/phase3/P3_historical_MNA_reconstruction.rds"
)

cat("\nP3_03 COMPLETE\n")
