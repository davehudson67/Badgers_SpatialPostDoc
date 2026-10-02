# =============================================================================
# WOODCHESTER V7c — REVISED SUPER-EXCRETOR DEFINITION AUDIT (V2)
#
# User-specified qualification rule:
# A) >=2 DISTINCT culture-positive sample sites on the SAME live capture occasion;
# OR
# B) TWO CONSECUTIVE live capture occasions are each culture-positive and the
#    UNION of positive sample sites across those two captures contains >=2
#    distinct sites. Qualification under B occurs at the SECOND capture only.
#
# Examples:
#   faeces + wound at one capture                     -> qualifies at that capture
#   faeces at capture 1, wound at capture 2           -> qualifies at capture 2
#   faeces at capture 1, faeces at capture 2          -> does not qualify by B
#   positive capture, intervening live capture, positive later -> NOT consecutive
#
# This script builds/audits the phenotype only. It deliberately does not assume
# that qualification is reversible/irreversible in later recipient-risk models.
# Sample-site labels are conservatively normalised only by upper-case/whitespace;
# the raw site-frequency table should be reviewed before final publication use.
# =============================================================================

library(tidyverse)
library(lubridate)
library(DBI)
library(dbplyr)
source("scripts/BadgerDatabase.R")

norm_site <- function(x){
  z <- str_to_upper(str_squish(as.character(x)))
  z[z==""] <- NA_character_
  z
}
split_sites <- function(x){
  if(length(x)!=1L || is.na(x) || !nzchar(x)) return(character(0))
  unique(strsplit(x," | ",fixed=TRUE)[[1]])
}
union_n <- function(a,b) length(unique(c(split_sites(a),split_sites(b))))

cat("\nConnecting to canonical badger database...\n")
con <- badger_db_connect()
if(!DBI::dbIsValid(con)) stop("Database connection is not valid.")
captures <- tryCatch(capture_history_db(con) %>% collect(),error=function(e){if(DBI::dbIsValid(con)) try(DBI::dbDisconnect(con),silent=TRUE); stop("Could not read capture_history: ",conditionMessage(e))})
diagnostics <- tryCatch(diagnostic_results_db(con) %>% collect(),error=function(e){if(DBI::dbIsValid(con)) try(DBI::dbDisconnect(con),silent=TRUE); stop("Could not read diagnostic_results: ",conditionMessage(e))})
if(DBI::dbIsValid(con)) DBI::dbDisconnect(con)

need_cap <- c("individual_id","tattoo","capture_date","is_pm")
need_diag <- c("individual_id","tattoo","capture_date","test_family","sample_type","result")
if(length(setdiff(need_cap,names(captures)))) stop("capture_history missing required fields.")
if(length(setdiff(need_diag,names(diagnostics)))) stop("diagnostic_results missing required fields.")

# One row for every LIVE capture occasion, including occasions with no culture.
live <- captures %>%
  filter(!is_pm) %>%
  transmute(individual_id,tattoo=str_to_upper(str_squish(as.character(tattoo))),capture_date=as.Date(capture_date)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(capture_date)) %>%
  distinct(individual_id,tattoo,capture_date)

culture <- diagnostics %>%
  filter(test_family=="Culture") %>%
  transmute(individual_id,tattoo=str_to_upper(str_squish(as.character(tattoo))),capture_date=as.Date(capture_date),
            raw_sample_type=str_squish(as.character(sample_type)),site=norm_site(sample_type),
            result_upper=str_to_upper(str_squish(as.character(result))),
            is_pos=str_detect(result_upper,"M\\.BOVIS|M BOVIS")) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(capture_date))

culture_occ <- culture %>%
  group_by(individual_id,tattoo,capture_date) %>%
  summarise(culture_rows=n(),culture_tested=TRUE,culture_positive=any(is_pos,na.rm=TRUE),
            positive_rows=sum(is_pos,na.rm=TRUE),
            positive_site_count=n_distinct(site[is_pos & !is.na(site)]),
            positive_sites=paste(sort(unique(site[is_pos & !is.na(site)])),collapse=" | "),
            .groups="drop")

occ <- live %>%
  left_join(culture_occ,by=c("individual_id","tattoo","capture_date")) %>%
  mutate(culture_tested=replace_na(culture_tested,FALSE),culture_positive=replace_na(culture_positive,FALSE),
         positive_rows=replace_na(positive_rows,0L),positive_site_count=replace_na(positive_site_count,0L),
         positive_sites=replace_na(positive_sites,"")) %>%
  arrange(individual_id,capture_date) %>%
  group_by(individual_id,tattoo) %>%
  mutate(capture_index=row_number(),prev_capture_date=lag(capture_date),days_since_prev=as.integer(capture_date-prev_capture_date),
         prev_culture_positive=lag(culture_positive,default=FALSE),prev_positive_sites=lag(positive_sites,default=""),
         consecutive_union_site_count=mapply(union_n,prev_positive_sites,positive_sites),
         SE_same_capture=positive_site_count>=2L,
         SE_consecutive=culture_positive & prev_culture_positive & consecutive_union_site_count>=2L,
         SE_event=SE_same_capture | SE_consecutive,
         SE_route=case_when(SE_same_capture & SE_consecutive~"both",SE_same_capture~"same_capture",SE_consecutive~"consecutive_captures",TRUE~"none"),
         first_SE_date=if(any(SE_event)) min(capture_date[SE_event]) else as.Date(NA),
         ever_SE=any(SE_event),
         first_SE_event=SE_event & !is.na(first_SE_date) & capture_date==first_SE_date) %>%
  ungroup()

# Event-level and individual-level comparisons with the previous same-capture rule.
individual_summary <- occ %>%
  group_by(individual_id,tattoo) %>%
  summarise(n_live_captures=n(),n_positive_captures=sum(culture_positive),
            old_same_capture_SE=any(SE_same_capture),new_union_SE=any(SE_event),
            first_old_SE=if(any(SE_same_capture)) min(capture_date[SE_same_capture]) else as.Date(NA),
            first_new_SE=if(any(SE_event)) min(capture_date[SE_event]) else as.Date(NA),
            added_by_consecutive=!old_same_capture_SE & new_union_SE,
            .groups="drop")

route_summary <- occ %>% filter(SE_event) %>% count(SE_route,name="qualifying_occasions")
added_events <- occ %>% filter(SE_consecutive,!SE_same_capture) %>%
  select(tattoo,capture_date,capture_index,days_since_prev,prev_positive_sites,positive_sites,consecutive_union_site_count,first_SE_event)

site_frequency <- culture %>% filter(is_pos,!is.na(site)) %>% count(site,sort=TRUE,name="positive_culture_rows")

yearly <- occ %>% mutate(year=year(capture_date)) %>% group_by(year) %>%
  summarise(live_captures=n(),culture_tested=sum(culture_tested),culture_positive=sum(culture_positive),
            same_capture_SE_events=sum(SE_same_capture),consecutive_SE_events=sum(SE_consecutive),
            union_SE_events=sum(SE_event),first_SE_events=sum(first_SE_event),.groups="drop")

cat("\n============================================================\n")
cat("REVISED SUPER-EXCRETOR DEFINITION AUDIT\n")
cat("============================================================\n")
cat("Live capture occasions:",nrow(occ),"\n")
cat("Unique badgers:",n_distinct(occ$tattoo),"\n")
cat("Culture-positive capture occasions:",sum(occ$culture_positive),"\n")
cat("Old >=2-site same-capture qualifying occasions:",sum(occ$SE_same_capture),"\n")
cat("Consecutive-capture qualifying occasions:",sum(occ$SE_consecutive),"\n")
cat("Union-rule qualifying occasions:",sum(occ$SE_event),"\n")
cat("Badgers ever qualifying under old rule:",sum(individual_summary$old_same_capture_SE),"\n")
cat("Badgers ever qualifying under revised rule:",sum(individual_summary$new_union_SE),"\n")
cat("Additional badgers captured ONLY by consecutive-capture rule:",sum(individual_summary$added_by_consecutive),"\n")
cat("\nQualification routes:\n"); print(route_summary,n=Inf,width=Inf)
cat("\nGap (days) for consecutive-only qualifying occasions:\n"); print(summary(added_events$days_since_prev))
cat("\nPositive culture site labels (review for synonyms before final freeze):\n"); print(site_frequency,n=Inf,width=Inf)
cat("\nYearly support:\n"); print(yearly,n=Inf,width=Inf)
cat("\nConsecutive-only examples:\n"); print(head(added_events,100),n=100,width=Inf)

if(any(occ$SE_consecutive & !occ$culture_positive)) stop("Internal error: consecutive SE without current positive culture.")
if(any(occ$SE_consecutive & !occ$prev_culture_positive)) stop("Internal error: consecutive SE without previous positive capture.")
if(any(occ$SE_consecutive & occ$consecutive_union_site_count<2L)) stop("Internal error: consecutive SE with <2 union sites.")

dir.create("data",showWarnings=FALSE,recursive=TRUE); dir.create("results",showWarnings=FALSE,recursive=TRUE)
saveRDS(list(occasion=occ,individual_summary=individual_summary,route_summary=route_summary,added_events=added_events,site_frequency=site_frequency,yearly=yearly,
             definition=list(same_capture=">=2 distinct positive culture sample-site labels at one live capture",
                             consecutive="two consecutive LIVE captures each culture-positive; >=2 distinct positive sample-site labels across their union; qualification at second capture",
                             postmortem_included=FALSE,site_normalisation="upper-case + whitespace only; inspect site_frequency before final use")),
        "data/badger_V7c_super_excretor_definition_v2_audit.rds")
write_csv(individual_summary,"results/V7c_super_excretor_v2_individual_summary.csv")
write_csv(route_summary,"results/V7c_super_excretor_v2_route_summary.csv")
write_csv(added_events,"results/V7c_super_excretor_v2_consecutive_only_events.csv")
write_csv(site_frequency,"results/V7c_super_excretor_v2_positive_site_frequency.csv")
write_csv(yearly,"results/V7c_super_excretor_v2_yearly.csv")
cat("\nSaved revised phenotype audit outputs.\n")
