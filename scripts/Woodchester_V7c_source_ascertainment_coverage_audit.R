# =============================================================================
# WOODCHESTER V7c — SOURCE ASCERTAINMENT COVERAGE AUDIT
#
# PURPOSE
# -------
# Check whether the apparent end of observed Excretor / Super-excretor source
# quarters after 2014 reflects biology or a change in disease-status ascertainment.
# This must be understood before treating later quarters as true 'no-source'
# comparison periods in within-group sensitivity models.
#
# This script is descriptive only. It does not estimate infection effects.
# =============================================================================

library(tidyverse)
library(lubridate)

ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
if(!file.exists(ENCOUNTER_FILE)) stop("Missing required file: ",ENCOUNTER_FILE)
enc <- as_tibble(readRDS(ENCOUNTER_FILE))
END_YEAR <- as.integer(Sys.getenv("END_YEAR","2025"))

qindex <- function(year,quarter) 4L*as.integer(year)+as.integer(quarter)

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

need <- c("tattoo","capture_date","has_live_capture","socg","disease_status")
miss <- setdiff(need,names(enc))
if(length(miss)) stop("Encounter file is missing: ",paste(miss,collapse=", "))

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    capture_date=as.Date(capture_date),
    year=year(capture_date),quarter=quarter(capture_date),qtime=qindex(year,quarter),
    socg=as.character(socg),disease_class=classify_disease(disease_status)
  ) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(capture_date),year<=END_YEAR)

# Biological encounter-level ascertainment by year.
yearly <- live %>%
  group_by(year) %>%
  summarise(
    live_encounters=n(),
    unique_badgers=n_distinct(tattoo),
    classified=sum(!is.na(disease_class)),
    p_classified=classified/live_encounters,
    negative=sum(disease_class=="Negative",na.rm=TRUE),
    exposed=sum(disease_class=="Exposed",na.rm=TRUE),
    excretor=sum(disease_class=="Excretor",na.rm=TRUE),
    super_excretor=sum(disease_class=="Super excretor",na.rm=TRUE),
    infectious=excretor+super_excretor,
    .groups="drop"
  ) %>% arrange(year)

# Five-year summaries make broad changes in ascertainment easier to see.
period5 <- yearly %>%
  mutate(period_start=5L*(year%/%5L)) %>%
  group_by(period_start) %>%
  summarise(
    years=paste(range(year),collapse="-"),
    live_encounters=sum(live_encounters),classified=sum(classified),
    p_classified=classified/live_encounters,
    negative=sum(negative),exposed=sum(exposed),excretor=sum(excretor),
    super_excretor=sum(super_excretor),infectious=sum(infectious),
    .groups="drop"
  )

class_years <- live %>%
  filter(!is.na(disease_class)) %>%
  group_by(disease_class) %>%
  summarise(first_year=min(year),last_year=max(year),encounters=n(),badgers=n_distinct(tattoo),.groups="drop") %>%
  arrange(factor(disease_class,levels=c("Negative","Exposed","Excretor","Super excretor")))

# Exact social-group-quarter ascertainment. This reveals whether quarters labelled
# no-source are based on well-classified captured animals or largely missing status.
gq <- live %>%
  filter(!is.na(socg),socg!="") %>%
  group_by(year,quarter,qtime,socg) %>%
  summarise(
    live_captures=n_distinct(tattoo),
    classified_captures=n_distinct(tattoo[!is.na(disease_class)]),
    p_classified=classified_captures/live_captures,
    any_classified=classified_captures>0,
    any_infectious=any(disease_class %in% c("Excretor","Super excretor"),na.rm=TRUE),
    any_super=any(disease_class=="Super excretor",na.rm=TRUE),
    .groups="drop"
  )

gq_year <- gq %>%
  group_by(year) %>%
  summarise(
    group_quarters=n(),
    group_quarters_any_classified=sum(any_classified),
    p_group_quarters_any_classified=group_quarters_any_classified/group_quarters,
    median_group_quarter_classified_fraction=median(p_classified),
    q25_group_quarter_classified_fraction=unname(quantile(p_classified,.25)),
    q75_group_quarter_classified_fraction=unname(quantile(p_classified,.75)),
    infectious_group_quarters=sum(any_infectious),
    super_group_quarters=sum(any_super),
    .groups="drop"
  ) %>% arrange(year)

# Direct pre/post-2014 comparison, because the exposure-variation audit found no
# ordinary or Super source recipient quarters after 2014.
prepost <- live %>%
  mutate(period=if_else(year<=2014,"<=2014",">2014")) %>%
  group_by(period) %>%
  summarise(
    live_encounters=n(),classified=sum(!is.na(disease_class)),p_classified=classified/live_encounters,
    infectious=sum(disease_class %in% c("Excretor","Super excretor"),na.rm=TRUE),
    super_excretor=sum(disease_class=="Super excretor",na.rm=TRUE),.groups="drop"
  )

cat("\n============================================================\n")
cat("V7c SOURCE ASCERTAINMENT COVERAGE AUDIT\n")
cat("============================================================\n")
cat("Live encounter years:",min(live$year),"to",max(live$year),"\n\n")

cat("LAST OBSERVED YEAR BY DISEASE CLASS\n")
print(class_years,n=Inf,width=Inf)

cat("\nPRE/POST-2014 CLASSIFICATION COVERAGE\n")
print(prepost,n=Inf,width=Inf)

cat("\nYEARLY DISEASE-STATUS COVERAGE\n")
print(yearly,n=Inf,width=Inf)

cat("\nFIVE-YEAR DISEASE-STATUS COVERAGE\n")
print(period5,n=Inf,width=Inf)

cat("\nGROUP-QUARTER ASCERTAINMENT BY YEAR\n")
print(gq_year,n=Inf,width=Inf)

cat("\nDECISION GUIDE\n")
cat("- If disease-status classification collapses after 2014, later no-source quarters must NOT be treated as true observed absence of Excretor/Super-excretor sources.\n")
cat("- If classification remains high after 2014 but infectious states disappear, the 2014 cutoff may be biologically meaningful rather than an ascertainment artefact.\n")
cat("- The next V7c within-group sensitivity should be restricted to a period with comparable source ascertainment and should adjust for exact-quarter capture intensity.\n")

saveRDS(list(yearly=yearly,period5=period5,class_years=class_years,group_quarter_year=gq_year,prepost=prepost,
             settings=list(end_year=END_YEAR)),"data/badger_V7c_source_ascertainment_coverage_audit.rds")
write_csv(yearly,"results/V7c_source_ascertainment_yearly.csv")
write_csv(period5,"results/V7c_source_ascertainment_5year.csv")
write_csv(class_years,"results/V7c_source_ascertainment_class_years.csv")
write_csv(gq_year,"results/V7c_source_ascertainment_group_quarter_yearly.csv")
write_csv(prepost,"results/V7c_source_ascertainment_prepost2014.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_source_ascertainment_coverage_audit.rds\n")
cat("  results/V7c_source_ascertainment_yearly.csv\n")
cat("  results/V7c_source_ascertainment_5year.csv\n")
cat("  results/V7c_source_ascertainment_class_years.csv\n")
cat("  results/V7c_source_ascertainment_group_quarter_yearly.csv\n")
cat("  results/V7c_source_ascertainment_prepost2014.csv\n")
