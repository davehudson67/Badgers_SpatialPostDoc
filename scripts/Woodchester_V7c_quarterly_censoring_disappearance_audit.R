# =============================================================================
# WOODCHESTER V7c — QUARTERLY CENSORING / DISAPPEARANCE AUDIT
#
# PURPOSE
# -------
# Audit whether follow-up availability differs after exact-quarter exposure to
# ordinary Excretors or Super excretors. This directly addresses a key caveat of
# the quarterly V7c hazard models, which stop follow-up at the recipient's last
# observed LIVE quarter.
#
# This script does NOT estimate infection effects. Instead, for each exact
# recipient social-group x quarter context used by the quarterly hazard analysis
# it asks, at lags 1..8 quarters, whether the recipient:
#   1. is still supported by a later/equal LIVE observation;
#   2. has a known PM/death record by the target quarter; or
#   3. has disappeared without a known PM record by the target quarter.
#
# Exposure classes are mutually exclusive:
#   NONE          : no observed Excretor/Super-excretor source in the group-quarter
#   ORDINARY_ONLY : >=1 observed Excretor but no Super excretor
#   SUPER         : >=1 observed Super excretor
#
# IMPORTANT
# ---------
# 'Unresolved disappearance' combines emigration, missed capture and unrecovered
# death. It is not assumed to be mortality. The aim is to see whether the amount
# of unresolved censoring differs materially by exposure class. If it does, a
# formal observation/survival sensitivity is warranted.
# =============================================================================

library(tidyverse)
library(lubridate)

ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
if(!file.exists(ENCOUNTER_FILE)) stop("Missing required file: ",ENCOUNTER_FILE)

enc <- as_tibble(readRDS(ENCOUNTER_FILE))
END_YEAR <- as.integer(Sys.getenv("END_YEAR","2025"))
LAGS <- 1:8

qindex <- function(year,quarter) 4L*as.integer(year)+as.integer(quarter)
qyear <- function(qtime) (as.integer(qtime)-1L)%/%4L

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

need <- c("tattoo","capture_date","has_live_capture","has_pm_record","socg","disease_status")
miss <- setdiff(need,names(enc))
if(length(miss)) stop("Encounter file is missing: ",paste(miss,collapse=", "))

# =============================================================================
# 1. LIVE AND PM HISTORIES
# =============================================================================

base <- enc %>%
  transmute(
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    capture_date=as.Date(capture_date),
    year=year(capture_date),
    quarter=quarter(capture_date),
    qtime=qindex(year,quarter),
    socg=as.character(socg),
    has_live_capture=as.logical(has_live_capture),
    has_pm_record=as.logical(has_pm_record),
    disease_class=classify_disease(disease_status)
  ) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(capture_date))

live <- base %>% filter(has_live_capture %in% TRUE)
pm <- base %>% filter(has_pm_record %in% TRUE)

live_bounds <- live %>%
  group_by(tattoo) %>%
  summarise(first_live_q=min(qtime),last_live_q=max(qtime),.groups="drop")

pm_first <- pm %>%
  group_by(tattoo) %>%
  summarise(first_pm_q=min(qtime),.groups="drop")

pm_consistency <- live_bounds %>%
  left_join(pm_first,by="tattoo") %>%
  mutate(live_after_pm=!is.na(first_pm_q) & last_live_q>first_pm_q)

# Exact-quarter membership. As in the hazard model, remove animal-quarters with
# >1 observed social group rather than assigning one arbitrarily.
quarter_members_all <- live %>%
  filter(!is.na(socg),socg!="") %>%
  distinct(tattoo,year,quarter,qtime,socg)

ambiguous_q <- quarter_members_all %>%
  group_by(tattoo,qtime) %>%
  summarise(n_groups=n_distinct(socg),.groups="drop") %>%
  filter(n_groups>1L)

quarter_members <- quarter_members_all %>%
  anti_join(ambiguous_q %>% select(tattoo,qtime),by=c("tattoo","qtime")) %>%
  distinct(tattoo,qtime,.keep_all=TRUE)

# =============================================================================
# 2. OBSERVED INFECTIOUS SOURCES AND RECIPIENT CONTEXTS
# =============================================================================

source_occ <- live %>%
  filter(disease_class %in% c("Excretor","Super excretor"),!is.na(socg),socg!="") %>%
  transmute(source_tattoo=tattoo,year,quarter,qtime,socg,disease_class) %>%
  distinct()

source_counts <- source_occ %>%
  group_by(year,quarter,qtime,socg) %>%
  summarise(
    n_infectious_sources=n_distinct(source_tattoo),
    n_super_sources=n_distinct(source_tattoo[disease_class=="Super excretor"]),
    .groups="drop"
  )

source_members <- source_occ %>%
  distinct(year,quarter,qtime,socg,source_tattoo) %>%
  mutate(recipient_is_infectious_source=TRUE)

context <- quarter_members %>%
  filter(year<=END_YEAR) %>%
  left_join(live_bounds,by="tattoo") %>%
  left_join(pm_first,by="tattoo") %>%
  left_join(source_counts,by=c("year","quarter","qtime","socg")) %>%
  mutate(
    n_infectious_sources=replace_na(n_infectious_sources,0L),
    n_super_sources=replace_na(n_super_sources,0L)
  ) %>%
  left_join(
    source_members %>% rename(tattoo=source_tattoo),
    by=c("tattoo","year","quarter","qtime","socg")
  ) %>%
  mutate(recipient_is_infectious_source=replace_na(recipient_is_infectious_source,FALSE)) %>%
  filter(!recipient_is_infectious_source) %>%
  mutate(
    exposure_class=case_when(
      n_super_sources>0L ~ "SUPER",
      n_infectious_sources>0L ~ "ORDINARY_ONLY",
      TRUE ~ "NONE"
    ),
    exposure_class=factor(exposure_class,levels=c("NONE","ORDINARY_ONLY","SUPER"))
  )

if(anyDuplicated(context[c("tattoo","qtime")])) stop("Internal error: duplicate recipient-quarter context rows remain.")

# =============================================================================
# 3. FOLLOW-UP STATUS AT EACH LAG
# =============================================================================

lag_rows <- vector("list",length(LAGS))

for(j in seq_along(LAGS)){
  L <- LAGS[j]
  z <- context %>%
    mutate(target_q=qtime+L,target_year=qyear(target_q)) %>%
    filter(target_year<=END_YEAR) %>%
    mutate(
      supported_live=last_live_q>=target_q,
      known_pm_by_target=!supported_live & !is.na(first_pm_q) & first_pm_q>=qtime & first_pm_q<=target_q,
      unresolved_disappearance=!supported_live & !known_pm_by_target,
      followup_status=case_when(
        supported_live ~ "SUPPORTED_LIVE",
        known_pm_by_target ~ "KNOWN_PM_DEATH",
        TRUE ~ "UNRESOLVED_DISAPPEARANCE"
      ),
      lag_quarters=L
    )
  lag_rows[[j]] <- z
}

followup <- bind_rows(lag_rows)

status_summary <- followup %>%
  group_by(lag_quarters,exposure_class) %>%
  summarise(
    contexts=n(),
    unique_badgers=n_distinct(tattoo),
    supported_live=sum(supported_live),
    known_pm_death=sum(known_pm_by_target),
    unresolved_disappearance=sum(unresolved_disappearance),
    p_supported=supported_live/contexts,
    p_known_pm=known_pm_death/contexts,
    p_unresolved=unresolved_disappearance/contexts,
    .groups="drop"
  )

contrast_summary <- status_summary %>%
  select(lag_quarters,exposure_class,p_supported,p_known_pm,p_unresolved) %>%
  pivot_wider(names_from=exposure_class,values_from=c(p_supported,p_known_pm,p_unresolved)) %>%
  mutate(
    delta_supported_super_vs_none=p_supported_SUPER-p_supported_NONE,
    delta_unresolved_super_vs_none=p_unresolved_SUPER-p_unresolved_NONE,
    ratio_unresolved_super_vs_none=if_else(p_unresolved_NONE>0,p_unresolved_SUPER/p_unresolved_NONE,NA_real_),
    delta_supported_ordinary_vs_none=p_supported_ORDINARY_ONLY-p_supported_NONE,
    delta_unresolved_ordinary_vs_none=p_unresolved_ORDINARY_ONLY-p_unresolved_NONE
  )

# How quickly do contexts lose live support, irrespective of exact target lag?
first_loss_summary <- context %>%
  mutate(
    quarters_to_last_live=pmax(0L,last_live_q-qtime),
    quarters_to_pm=if_else(!is.na(first_pm_q) & first_pm_q>=qtime,first_pm_q-qtime,NA_integer_)
  ) %>%
  group_by(exposure_class) %>%
  summarise(
    contexts=n(),
    unique_badgers=n_distinct(tattoo),
    median_quarters_to_last_live=median(quarters_to_last_live),
    q25_quarters_to_last_live=unname(quantile(quarters_to_last_live,.25)),
    q75_quarters_to_last_live=unname(quantile(quarters_to_last_live,.75)),
    contexts_with_known_pm=sum(!is.na(quarters_to_pm)),
    median_quarters_to_pm=if(any(!is.na(quarters_to_pm))) median(quarters_to_pm,na.rm=TRUE) else NA_real_,
    .groups="drop"
  )

# =============================================================================
# 4. PRINT
# =============================================================================

cat("\n============================================================\n")
cat("V7c QUARTERLY CENSORING / DISAPPEARANCE AUDIT\n")
cat("============================================================\n")
cat("Exact recipient group-quarter contexts:",nrow(context),"\n")
cat("Unique recipient badgers:",n_distinct(context$tattoo),"\n")
cat("Ambiguous recipient quarters dropped:",nrow(ambiguous_q),"\n")
cat("Recipients with any PM record:",sum(!is.na(pm_consistency$first_pm_q)),"\n")
cat("Individuals with LIVE observation after first PM record:",sum(pm_consistency$live_after_pm,na.rm=TRUE),"\n")
cat("Outcome years capped at:",END_YEAR,"\n\n")

cat("BASELINE CONTEXTS BY EXPOSURE CLASS\n")
print(context %>% count(exposure_class,name="contexts") %>% mutate(unique_badgers=map_int(exposure_class,~n_distinct(context$tattoo[context$exposure_class==.x]))),n=Inf,width=Inf)

cat("\nFOLLOW-UP STATUS BY LAG AND EXPOSURE CLASS\n")
print(status_summary,n=Inf,width=Inf)

cat("\nSUPER/ORDINARY VERSUS NO-SOURCE CENSORING CONTRASTS\n")
print(contrast_summary,n=Inf,width=Inf)

cat("\nTIME TO END OF OBSERVED LIVE SUPPORT\n")
print(first_loss_summary,n=Inf,width=Inf)

cat("\nINTERPRETATION GUIDE\n")
cat("- SUPPORTED_LIVE means a live observation exists at or after the target quarter; it does not require capture in the target quarter itself.\n")
cat("- KNOWN_PM_DEATH means the animal lacks live support through the target but has a PM record by then.\n")
cat("- UNRESOLVED_DISAPPEARANCE means follow-up ended without a known PM record by the target; this can be emigration, missed capture or unrecovered death.\n")
cat("- Compare p_unresolved and p_supported for SUPER versus NONE. Large differences would make informative censoring a serious concern for the hazard analysis.\n")
cat("- This audit is descriptive. It does not by itself correct informative censoring.\n")

# =============================================================================
# 5. SAVE
# =============================================================================

dir.create("results",showWarnings=FALSE,recursive=TRUE)
dir.create("data",showWarnings=FALSE,recursive=TRUE)

saveRDS(
  list(
    context=context,
    followup=followup,
    status_summary=status_summary,
    contrast_summary=contrast_summary,
    time_to_last_live_summary=first_loss_summary,
    pm_consistency=pm_consistency,
    settings=list(
      end_year=END_YEAR,
      lags=LAGS,
      membership="exact observed live social-group quarter; ambiguous multi-group quarters removed",
      source_classes=c("NONE","ORDINARY_ONLY","SUPER"),
      unresolved_definition="no live support through target and no PM record by target"
    )
  ),
  "data/badger_V7c_quarterly_censoring_disappearance_audit.rds"
)

write_csv(status_summary,"results/V7c_quarterly_censoring_status_by_lag.csv")
write_csv(contrast_summary,"results/V7c_quarterly_censoring_contrasts.csv")
write_csv(first_loss_summary,"results/V7c_quarterly_time_to_last_live_support.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_quarterly_censoring_disappearance_audit.rds\n")
cat("  results/V7c_quarterly_censoring_status_by_lag.csv\n")
cat("  results/V7c_quarterly_censoring_contrasts.csv\n")
cat("  results/V7c_quarterly_time_to_last_live_support.csv\n")
