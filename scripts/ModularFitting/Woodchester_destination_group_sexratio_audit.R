# =============================================================================
# WOODCHESTER DESTINATION SOCIAL-GROUP SEX-RATIO AUDIT
#
# Lightweight descriptive development analysis while V9 movement chains run.
# Scientific questions:
#   1) When badgers switch observed social groups between consecutive years,
#      what is the sex composition of the destination group (excluding mover)?
#   2) Do males and females differ in the kinds of groups they enter?
#   3) Among switches with observed t+1 follow-up, is staying in the destination
#      group associated with destination female proportion, especially for males?
#
# This script is intentionally an AUDIT, not a final inferential model.
# A group-entry event requires observed social group at t-1 and t, in consecutive
# calendar years, with a different group at t. Staying requires observed social
# group again at t+1; missing t+1 is NOT classified as leaving.
# =============================================================================

library(tidyverse)

IND_FILE <- "data/badger_individuals.rds"
ANNUAL_FILE <- "results/badger_annual_observed_sett_locations.csv"
for(f in c(IND_FILE,ANNUAL_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

ind <- readRDS(IND_FILE) %>%
  transmute(tattoo=trimws(as.character(tattoo)),sex=trimws(as.character(sex))) %>%
  mutate(sex=case_when(tolower(sex)=="male"~"Male",tolower(sex)=="female"~"Female",TRUE~NA_character_))
if(anyDuplicated(ind$tattoo)) stop("Duplicate tattoos in badger_individuals.rds")

annual <- read_csv(ANNUAL_FILE,show_col_types=FALSE) %>%
  transmute(tattoo=trimws(as.character(tattoo)),year=as.integer(year),annual_socg=trimws(as.character(annual_socg))) %>%
  mutate(annual_socg=if_else(is.na(annual_socg) | annual_socg=="" | toupper(annual_socg)=="NA",NA_character_,annual_socg)) %>%
  left_join(ind,by="tattoo")
if(anyDuplicated(annual[c("tattoo","year")])) stop("Annual social-group table is not unique by tattoo+year")

cat("\n============================================================\n")
cat("DESTINATION SOCIAL-GROUP SEX-RATIO AUDIT\n")
cat("============================================================\n")
cat("Annual badger-year rows:",nrow(annual),"\n")
cat("Distinct badgers:",n_distinct(annual$tattoo),"\n")
cat("Rows with observed social group:",sum(!is.na(annual$annual_socg)),"\n")
cat("Rows with known sex:",sum(!is.na(annual$sex)),"\n")
cat("Rows with both SG + sex:",sum(!is.na(annual$annual_socg) & !is.na(annual$sex)),"\n")

# Group-year sex composition among sex-known observed badgers.
group_comp <- annual %>%
  filter(!is.na(annual_socg),!is.na(sex)) %>%
  group_by(year,annual_socg) %>%
  summarise(n_sex_known=n(),n_female=sum(sex=="Female"),n_male=sum(sex=="Male"),.groups="drop") %>%
  mutate(prop_female=n_female/n_sex_known)

# Exact previous-year and next-year observed groups for each focal badger.
prev <- annual %>%
  filter(!is.na(annual_socg)) %>%
  transmute(tattoo,year=year+1L,origin_group=annual_socg)
nexty <- annual %>%
  filter(!is.na(annual_socg)) %>%
  transmute(tattoo,year=year-1L,next_group=annual_socg)

entries <- annual %>%
  filter(!is.na(annual_socg),!is.na(sex)) %>%
  rename(destination_group=annual_socg,entry_year=year) %>%
  left_join(prev,by=c("tattoo","entry_year"="year")) %>%
  left_join(nexty,by=c("tattoo","entry_year"="year")) %>%
  filter(!is.na(origin_group),origin_group!=destination_group)

# Destination composition in entry year, subtracting focal mover from its own sex.
dest_comp <- group_comp %>%
  rename(entry_year=year,destination_group=annual_socg,dest_n=n_sex_known,dest_n_female=n_female,dest_n_male=n_male)
origin_comp <- group_comp %>%
  transmute(entry_year=year+1L,origin_group=annual_socg,origin_n=n_sex_known,origin_n_female=n_female,origin_n_male=n_male)

entries <- entries %>%
  left_join(dest_comp,by=c("entry_year","destination_group")) %>%
  left_join(origin_comp,by=c("entry_year","origin_group")) %>%
  mutate(
    dest_female_other=dest_n_female-as.integer(sex=="Female"),
    dest_male_other=dest_n_male-as.integer(sex=="Male"),
    dest_n_other=dest_female_other+dest_male_other,
    dest_prop_female_other=if_else(dest_n_other>0,dest_female_other/dest_n_other,NA_real_),
    origin_female_other=origin_n_female-as.integer(sex=="Female"),
    origin_male_other=origin_n_male-as.integer(sex=="Male"),
    origin_n_other=origin_female_other+origin_male_other,
    origin_prop_female_other=if_else(origin_n_other>0,origin_female_other/origin_n_other,NA_real_),
    delta_prop_female=dest_prop_female_other-origin_prop_female_other,
    has_tplus1=!is.na(next_group),
    stay_next_year=case_when(is.na(next_group)~NA_integer_,next_group==destination_group~1L,TRUE~0L),
    dest_female_band=case_when(
      is.na(dest_prop_female_other)~NA_character_,
      dest_prop_female_other<0.40~"<40% female",
      dest_prop_female_other<=0.60~"40-60% female",
      TRUE~">60% female"
    )
  )

cat("\nSTRICT CONSECUTIVE-YEAR ENTRY EVENTS\n")
cat("Observed group switches t-1 -> t:",nrow(entries),"\n")
print(entries %>% count(sex,name="switches"))
cat("Entries with destination composition (>=1 other sex-known badger):",sum(entries$dest_n_other>=1,na.rm=TRUE),"\n")
cat("Entries with destination composition (>=3 others):",sum(entries$dest_n_other>=3,na.rm=TRUE),"\n")
cat("Entries with observed t+1 social group:",sum(entries$has_tplus1),"\n")
cat("Entries with t+1 follow-up + >=3 destination others:",sum(entries$has_tplus1 & entries$dest_n_other>=3,na.rm=TRUE),"\n")

cat("\nDESTINATION FEMALE PROPORTION BY MOVER SEX (>=3 other group members)\n")
dest_summary <- entries %>%
  filter(dest_n_other>=3,!is.na(dest_prop_female_other)) %>%
  group_by(sex) %>%
  summarise(n=n(),mean=mean(dest_prop_female_other),median=median(dest_prop_female_other),
            q25=quantile(dest_prop_female_other,.25),q75=quantile(dest_prop_female_other,.75),
            prop_dest_gt60_female=mean(dest_prop_female_other>.60),.groups="drop")
print(dest_summary,width=Inf)

cat("\nCHANGE IN FEMALE PROPORTION: DESTINATION - ORIGIN (>=3 others at both)\n")
delta_summary <- entries %>%
  filter(dest_n_other>=3,origin_n_other>=3,!is.na(delta_prop_female)) %>%
  group_by(sex) %>%
  summarise(n=n(),mean_delta=mean(delta_prop_female),median_delta=median(delta_prop_female),
            q25=quantile(delta_prop_female,.25),q75=quantile(delta_prop_female,.75),
            prop_moved_more_female=mean(delta_prop_female>0),.groups="drop")
print(delta_summary,width=Inf)

cat("\nSTAY NEXT YEAR BY SEX AND DESTINATION FEMALE BAND (t+1 observed; >=3 others)\n")
stay_band <- entries %>%
  filter(has_tplus1,dest_n_other>=3,!is.na(dest_female_band)) %>%
  group_by(sex,dest_female_band) %>%
  summarise(n_entries=n(),n_stay=sum(stay_next_year),stay_rate=mean(stay_next_year),
            median_dest_n_other=median(dest_n_other),.groups="drop") %>%
  arrange(sex,factor(dest_female_band,levels=c("<40% female","40-60% female",">60% female")))
print(stay_band,n=Inf,width=Inf)

cat("\nOVERALL STAY NEXT YEAR BY SEX (t+1 observed; >=3 others)\n")
stay_sex <- entries %>%
  filter(has_tplus1,dest_n_other>=3) %>%
  group_by(sex) %>%
  summarise(n_entries=n(),n_stay=sum(stay_next_year),stay_rate=mean(stay_next_year),.groups="drop")
print(stay_sex,width=Inf)

# Model-ready rows for a later pre-specified inferential model.
model_ready <- entries %>%
  filter(has_tplus1,dest_n_other>=3,!is.na(dest_prop_female_other)) %>%
  transmute(tattoo,sex,entry_year,origin_group,destination_group,next_group,stay_next_year,
            dest_n_other,dest_prop_female_other,origin_n_other,origin_prop_female_other,delta_prop_female)

dir.create("results",showWarnings=FALSE,recursive=TRUE)
write_csv(entries,"results/destination_group_sexratio_entry_events.csv")
write_csv(group_comp,"results/destination_group_sexratio_groupyear_composition.csv")
write_csv(dest_summary,"results/destination_group_sexratio_destination_summary.csv")
write_csv(delta_summary,"results/destination_group_sexratio_origin_destination_delta.csv")
write_csv(stay_band,"results/destination_group_sexratio_stay_by_band.csv")
write_csv(stay_sex,"results/destination_group_sexratio_stay_by_sex.csv")
write_csv(model_ready,"results/destination_group_sexratio_model_ready.csv")

cat("\nSaved:\n")
cat("  results/destination_group_sexratio_entry_events.csv\n")
cat("  results/destination_group_sexratio_groupyear_composition.csv\n")
cat("  results/destination_group_sexratio_destination_summary.csv\n")
cat("  results/destination_group_sexratio_origin_destination_delta.csv\n")
cat("  results/destination_group_sexratio_stay_by_band.csv\n")
cat("  results/destination_group_sexratio_stay_by_sex.csv\n")
cat("  results/destination_group_sexratio_model_ready.csv\n")
