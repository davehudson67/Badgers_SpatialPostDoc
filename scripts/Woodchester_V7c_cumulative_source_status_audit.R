# =============================================================================
# WOODCHESTER V7c — CUMULATIVE SOURCE-STATUS AUDIT
#
# PURPOSE
# -------
# The same-occasion culture reconstruction does not reproduce the historical
# stored Excretor / Super-excretor labels well. A likely explanation is that the
# stored disease_status is a persistent state: once an animal has excreted, or
# once it has met the Super-excretor criterion, that status may be carried
# forward to later captures even when the current culture is negative.
#
# This audit tests that hypothesis without changing any source-effect model.
# It compares stored <=2014 labels against CULTURE HISTORY UP TO THAT DATE:
#   ever Excretor trigger = any previous/current M. bovis culture-positive site
#   ever Super trigger    = any previous/current capture with >=2 distinct
#                           positive culture sample/body sites
#
# It also audits whether stored disease classes generally progress monotonically
# through Negative -> Exposed -> Excretor -> Super excretor.
# =============================================================================

library(tidyverse)
library(lubridate)

AUDIT_FILE <- "data/badger_V7c_culture_reconstruction_audit.rds"
if(!file.exists(AUDIT_FILE)) stop("Missing required file: ",AUDIT_FILE)

a <- readRDS(AUDIT_FILE)
occ <- as_tibble(a$occasion)

need <- c("tattoo","capture_date","year","stored_class","culture_tested","culture_positive","positive_sample_types")
miss <- setdiff(need,names(occ))
if(length(miss)) stop("Culture reconstruction audit is missing: ",paste(miss,collapse=", "))

rank_class <- c("Negative"=1L,"Exposed"=2L,"Excretor"=3L,"Super excretor"=4L)

hist <- occ %>%
  mutate(
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    capture_date=as.Date(capture_date),
    current_positive=replace_na(as.logical(culture_positive),FALSE),
    current_super_trigger=replace_na(as.integer(positive_sample_types),0L)>=2L,
    stored_rank=unname(rank_class[stored_class])
  ) %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  mutate(
    ever_positive_to_date=cummax(as.integer(current_positive))>0L,
    ever_super_trigger_to_date=cummax(as.integer(current_super_trigger))>0L,
    cumulative_source_class=case_when(
      ever_super_trigger_to_date ~ "Super excretor",
      ever_positive_to_date ~ "Excretor",
      TRUE ~ "No culture-positive history"
    ),
    previous_stored_rank=lag(stored_rank),
    stored_rank_drop=!is.na(stored_rank) & !is.na(previous_stored_rank) & stored_rank<previous_stored_rank
  ) %>%
  ungroup()

# -----------------------------------------------------------------------------
# 1. Does cumulative culture history explain stored source labels?
# -----------------------------------------------------------------------------
source_validation <- hist %>%
  filter(year<=2014,stored_class %in% c("Excretor","Super excretor")) %>%
  group_by(stored_class) %>%
  summarise(
    stored_occasions=n(),
    ever_culture_positive=sum(ever_positive_to_date),
    ever_super_trigger=sum(ever_super_trigger_to_date),
    p_ever_culture_positive=mean(ever_positive_to_date),
    p_ever_super_trigger=mean(ever_super_trigger_to_date),
    current_culture_positive=sum(current_positive),
    current_super_trigger=sum(current_super_trigger),
    .groups="drop"
  )

confusion <- hist %>%
  filter(year<=2014,!is.na(stored_class)) %>%
  count(stored_class,cumulative_source_class,name="n") %>%
  group_by(stored_class) %>%
  mutate(prop_within_stored=n/sum(n)) %>%
  ungroup()

# -----------------------------------------------------------------------------
# 2. Timing of first culture trigger versus first stored source classification
# -----------------------------------------------------------------------------
first_dates <- hist %>%
  group_by(tattoo) %>%
  summarise(
    first_live=min(capture_date),
    first_culture_positive=if(any(current_positive)) min(capture_date[current_positive]) else as.Date(NA),
    first_super_trigger=if(any(current_super_trigger)) min(capture_date[current_super_trigger]) else as.Date(NA),
    first_stored_excretor=if(any(stored_class %in% c("Excretor","Super excretor"),na.rm=TRUE)) min(capture_date[stored_class %in% c("Excretor","Super excretor")],na.rm=TRUE) else as.Date(NA),
    first_stored_super=if(any(stored_class=="Super excretor",na.rm=TRUE)) min(capture_date[stored_class=="Super excretor"],na.rm=TRUE) else as.Date(NA),
    .groups="drop"
  ) %>%
  mutate(
    days_culture_to_stored_excretor=as.numeric(first_stored_excretor-first_culture_positive),
    days_super_trigger_to_stored_super=as.numeric(first_stored_super-first_super_trigger)
  )

timing_summary <- tibble(
  comparison=c("first culture positive -> first stored Excretor/Super","first >=2-site trigger -> first stored Super"),
  n=c(sum(!is.na(first_dates$days_culture_to_stored_excretor)),sum(!is.na(first_dates$days_super_trigger_to_stored_super))),
  median_days=c(median(first_dates$days_culture_to_stored_excretor,na.rm=TRUE),median(first_dates$days_super_trigger_to_stored_super,na.rm=TRUE)),
  q25_days=c(unname(quantile(first_dates$days_culture_to_stored_excretor,.25,na.rm=TRUE)),unname(quantile(first_dates$days_super_trigger_to_stored_super,.25,na.rm=TRUE))),
  q75_days=c(unname(quantile(first_dates$days_culture_to_stored_excretor,.75,na.rm=TRUE)),unname(quantile(first_dates$days_super_trigger_to_stored_super,.75,na.rm=TRUE))),
  exact_same_day=c(sum(first_dates$days_culture_to_stored_excretor==0,na.rm=TRUE),sum(first_dates$days_super_trigger_to_stored_super==0,na.rm=TRUE))
)

# -----------------------------------------------------------------------------
# 3. Stored-class transition audit
# -----------------------------------------------------------------------------
stored_sequences <- hist %>%
  filter(year<=2014,!is.na(stored_rank)) %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  mutate(prev_class=lag(stored_class),prev_rank=lag(stored_rank),rank_change=stored_rank-prev_rank) %>%
  ungroup()

transition_summary <- stored_sequences %>%
  filter(!is.na(prev_rank)) %>%
  summarise(
    transitions=n(),
    upgrades=sum(rank_change>0),
    same=sum(rank_change==0),
    downgrades=sum(rank_change<0),
    p_downgrade=mean(rank_change<0)
  )

downgrade_types <- stored_sequences %>%
  filter(!is.na(prev_rank),rank_change<0) %>%
  count(prev_class,stored_class,sort=TRUE,name="n")

# -----------------------------------------------------------------------------
# 4. What would the cumulative culture rule imply after 2014?
# -----------------------------------------------------------------------------
post2014 <- hist %>%
  filter(year>=2015) %>%
  group_by(year) %>%
  summarise(
    live_capture_occasions=n(),
    culture_tested=sum(culture_tested,na.rm=TRUE),
    p_culture_tested=sum(culture_tested,na.rm=TRUE)/n(),
    current_culture_positive=sum(current_positive),
    current_super_trigger=sum(current_super_trigger),
    cumulative_excretor_or_super=sum(ever_positive_to_date),
    cumulative_super=sum(ever_super_trigger_to_date),
    unique_badgers=n_distinct(tattoo),
    .groups="drop"
  )

cat("\n============================================================\n")
cat("V7c CUMULATIVE SOURCE-STATUS AUDIT\n")
cat("============================================================\n")

cat("\nCUMULATIVE CULTURE HISTORY vs STORED SOURCE LABELS <=2014\n")
print(source_validation,n=Inf,width=Inf)

cat("\nSTORED CLASS x CUMULATIVE CULTURE CLASS <=2014\n")
print(confusion,n=Inf,width=Inf)

cat("\nTIMING OF CULTURE TRIGGERS vs STORED SOURCE CLASSIFICATION\n")
print(timing_summary,n=Inf,width=Inf)

cat("\nSTORED DISEASE-STATUS TRANSITION AUDIT <=2014\n")
print(transition_summary,n=Inf,width=Inf)

cat("\nDOWNGRADE TYPES <=2014\n")
print(downgrade_types,n=Inf,width=Inf)

cat("\nPOST-2014 SUPPORT UNDER CUMULATIVE CULTURE RULE\n")
print(post2014,n=Inf,width=Inf)

cat("\nDECISION GUIDE\n")
cat("- If stored Excretor/Super labels are much better matched by cumulative than same-occasion culture history, disease_status is functioning as a persistent historical state.\n")
cat("- If stored Super labels are strongly associated with a prior >=2-site culture-positive occasion, the Super criterion can be reconstructed after 2014 by carrying that state forward.\n")
cat("- If many stored-class downgrades occur, a simple irreversible-state reconstruction is not adequate and the historical classification rules need further investigation.\n")
cat("- Do not refit V7c source-effect models until this audit resolves whether source status is instantaneous or persistent.\n")

dir.create("results",showWarnings=FALSE,recursive=TRUE)
saveRDS(list(history=hist,source_validation=source_validation,confusion=confusion,first_dates=first_dates,
             timing_summary=timing_summary,transition_summary=transition_summary,downgrade_types=downgrade_types,
             post2014=post2014),"data/badger_V7c_cumulative_source_status_audit.rds")
write_csv(source_validation,"results/V7c_cumulative_source_validation.csv")
write_csv(confusion,"results/V7c_cumulative_source_confusion.csv")
write_csv(timing_summary,"results/V7c_cumulative_source_timing.csv")
write_csv(downgrade_types,"results/V7c_cumulative_source_downgrades.csv")
write_csv(post2014,"results/V7c_cumulative_source_post2014.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_cumulative_source_status_audit.rds\n")
cat("  results/V7c_cumulative_source_validation.csv\n")
cat("  results/V7c_cumulative_source_confusion.csv\n")
cat("  results/V7c_cumulative_source_timing.csv\n")
cat("  results/V7c_cumulative_source_downgrades.csv\n")
cat("  results/V7c_cumulative_source_post2014.csv\n")
