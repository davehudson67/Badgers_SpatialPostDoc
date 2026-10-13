# PHASE 3 P3_02c — historical social-group ID / name lineage audit
# Tests whether the 40 text SOCG labels in 1990-2004 are multiple names for a
# smaller number of stable database social-group entities.
# Audit only: no reclassification is applied automatically.

suppressPackageStartupMessages({library(tidyverse); library(lubridate)})

ENC <- "data/badger_encounters_useful.rds"
MEM <- "data/phase3/P3_annual_recorded_membership.rds"
for(f in c(ENC,MEM)) if(!file.exists(f)) stop("Missing: ",f)
dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)
dir.create("data/phase3",recursive=TRUE,showWarnings=FALSE)

enc <- as_tibble(readRDS(ENC))
mem <- readRDS(MEM)

need <- c("tattoo","capture_date","has_live_capture","socg")
miss <- setdiff(need,names(enc))
if(length(miss)) stop("Encounter data missing: ",paste(miss,collapse=", "))
if(!"recorded_social_group_id" %in% names(enc))
  stop("Encounter data has no recorded_social_group_id; cannot run lineage audit.")

clean_sg <- function(x){
  z <- toupper(stringr::str_squish(as.character(x)))
  z <- stringr::str_replace_all(z,"[^A-Z0-9]","")
  z[z==""|z=="NA"] <- NA_character_
  dplyr::recode(z,"CHESTNUT"="BEECH","HOLLOWTREE"="NETTLE",.default=z)
}

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    capture_date=as.Date(capture_date),
    year=lubridate::year(capture_date),
    socg=clean_sg(socg),
    group_id=as.character(recorded_social_group_id)
  ) %>%
  mutate(group_id=na_if(trimws(group_id),"")) %>%
  filter(year>=1989L,year<=2004L)

id_name <- live %>%
  filter(!is.na(group_id),!is.na(socg)) %>%
  count(group_id,socg,name="n_capture_records") %>%
  group_by(group_id) %>%
  mutate(id_total=sum(n_capture_records),
         name_share=n_capture_records/id_total,
         n_names_for_id=n()) %>%
  ungroup() %>%
  group_by(socg) %>%
  mutate(n_ids_for_name=n_distinct(group_id)) %>%
  ungroup() %>%
  arrange(group_id,desc(n_capture_records),socg)

id_summary <- id_name %>%
  group_by(group_id) %>%
  summarise(
    n_names=n_distinct(socg),
    modal_name=socg[which.max(n_capture_records)],
    modal_name_share=max(name_share),
    capture_records=sum(n_capture_records),
    first_year=min(live$year[live$group_id==first(group_id)],na.rm=TRUE),
    last_year=max(live$year[live$group_id==first(group_id)],na.rm=TRUE),
    .groups="drop"
  ) %>%
  arrange(desc(n_names),group_id)

name_summary <- id_name %>%
  group_by(socg) %>%
  summarise(
    n_ids=n_distinct(group_id),
    ids=paste(sort(unique(group_id)),collapse=" | "),
    capture_records=sum(n_capture_records),
    .groups="drop"
  ) %>%
  arrange(desc(n_ids),socg)

year_id <- live %>%
  filter(year>=1990L,year<=2004L,!is.na(group_id)) %>%
  distinct(year,group_id) %>%
  count(year,name="n_group_ids") %>%
  complete(year=1990:2004,fill=list(n_group_ids=0L))

year_name <- live %>%
  filter(year>=1990L,year<=2004L,!is.na(socg)) %>%
  distinct(year,socg) %>%
  count(year,name="n_group_names") %>%
  complete(year=1990:2004,fill=list(n_group_names=0L))

coverage <- live %>%
  filter(year>=1990L,year<=2004L) %>%
  summarise(
    live_records=n(),
    records_with_name=sum(!is.na(socg)),
    records_with_id=sum(!is.na(group_id)),
    records_with_both=sum(!is.na(socg)&!is.na(group_id)),
    badgers=n_distinct(tattoo),
    badgers_with_name=n_distinct(tattoo[!is.na(socg)]),
    badgers_with_id=n_distinct(tattoo[!is.na(group_id)])
  )

annual <- as_tibble(mem$annual_membership) %>%
  transmute(tattoo=trimws(as.character(tattoo)),year=as.integer(year),
            annual_socg=clean_sg(candidate_resident_socg),
            assignment_criterion=assignment_criterion) %>%
  filter(year>=1990L,year<=2004L,!is.na(annual_socg))

# Year-specific name -> ID mapping. Use only an unambiguous modal ID;
# retain ambiguity explicitly rather than silently forcing it.
year_name_id <- live %>%
  filter(year>=1990L,year<=2004L,!is.na(socg),!is.na(group_id)) %>%
  count(year,socg,group_id,name="n") %>%
  group_by(year,socg) %>%
  arrange(desc(n),group_id,.by_group=TRUE) %>%
  summarise(
    n_ids=n_distinct(group_id),
    top_n=max(n),
    n_top=sum(n==max(n)),
    mapped_group_id=if(n_top==1L) group_id[which.max(n)] else NA_character_,
    mapping_share=max(n)/sum(n),
    .groups="drop"
  )

annual_id <- annual %>%
  left_join(year_name_id,by=c("year","annual_socg"="socg"))

annual_id_year <- annual_id %>%
  filter(!is.na(mapped_group_id)) %>%
  distinct(year,mapped_group_id) %>%
  count(year,name="n_annual_group_ids") %>%
  complete(year=1990:2004,fill=list(n_annual_group_ids=0L))

cat("\n============================================================\n")
cat("P3_02c — HISTORICAL SG ID / NAME LINEAGE AUDIT\n")
cat("============================================================\n")
print(coverage,width=Inf)

cat("\n1990-2004 unique text SOCG labels with live captures:",
    n_distinct(live$socg[live$year>=1990 & live$year<=2004],na.rm=TRUE),"\n")
cat("1990-2004 unique recorded social-group IDs:",
    n_distinct(live$group_id[live$year>=1990 & live$year<=2004],na.rm=TRUE),"\n")
cat("IDs represented by >1 text name:",sum(id_summary$n_names>1),"\n")
cat("Names represented by >1 ID:",sum(name_summary$n_ids>1),"\n")

cat("\nGROUP COUNTS BY YEAR\n")
print(year_name %>%
        left_join(year_id,by="year") %>%
        left_join(annual_id_year,by="year"),
      n=Inf,width=Inf)

cat("\nID -> NAME LINEAGES WITH >1 NAME\n")
print(id_name %>% filter(n_names_for_id>1),n=Inf,width=Inf)

cat("\nNAME -> ID AMBIGUITIES WITH >1 ID\n")
print(name_summary %>% filter(n_ids>1),n=Inf,width=Inf)

cat("\nANNUAL ASSIGNMENT -> ID COVERAGE\n")
print(annual_id %>%
        summarise(
          annual_badger_years=n(),
          mapped_id=sum(!is.na(mapped_group_id)),
          ambiguous_name_year=sum(n_ids>1|n_top>1,na.rm=TRUE),
          median_mapping_share=median(mapping_share,na.rm=TRUE)
        ),width=Inf)

write_csv(id_name,"results/Phase3/P3_02c_group_id_name_pairs.csv")
write_csv(id_summary,"results/Phase3/P3_02c_group_id_summary.csv")
write_csv(name_summary,"results/Phase3/P3_02c_group_name_summary.csv")
write_csv(year_name %>% left_join(year_id,by="year") %>%
            left_join(annual_id_year,by="year"),
          "results/Phase3/P3_02c_groups_by_year_name_vs_id.csv")
write_csv(year_name_id,"results/Phase3/P3_02c_year_name_to_id.csv")

saveRDS(list(id_name=id_name,id_summary=id_summary,name_summary=name_summary,
             year_name_id=year_name_id,annual_id=annual_id,coverage=coverage),
        "data/phase3/P3_historical_group_lineage_audit.rds")

cat("\nInterpretation:\n")
cat("- If IDs collapse historical names to about the published 27 entities and 23-27/year, use IDs as lineage support.\n")
cat("- If not, do not invent a core definition: seek annual bait-marking/core metadata or reconstruct it separately.\n")
cat("\nP3_02c COMPLETE\n")
