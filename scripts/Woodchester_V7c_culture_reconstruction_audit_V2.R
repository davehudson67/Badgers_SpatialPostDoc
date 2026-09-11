# =============================================================================
# WOODCHESTER V7c — CULTURE-BASED EXCRETOR / SUPER-EXCRETOR RECONSTRUCTION AUDIT V2
#
# Fixes the database-connection handling in V1: the connection is opened once,
# checked, used for both canonical analysis views, and disconnected once.
# =============================================================================

library(tidyverse)
library(lubridate)
library(DBI)
library(dbplyr)
source("scripts/BadgerDatabase.R")

classify_stored <- function(x){
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

norm_sample <- function(x){
  x <- str_to_upper(str_squish(as.character(x)))
  x[x==""] <- NA_character_
  x
}

cat("\nConnecting to canonical badger database...\n")
con <- badger_db_connect()
if(!DBI::dbIsValid(con)) stop("Database connection was created but is not valid.")

captures <- tryCatch(
  capture_history_db(con) %>% collect(),
  error=function(e){
    if(DBI::dbIsValid(con)) try(DBI::dbDisconnect(con),silent=TRUE)
    stop("Could not read analysis.capture_history: ",conditionMessage(e),call.=FALSE)
  }
)

diagnostics <- tryCatch(
  diagnostic_results_db(con) %>% collect(),
  error=function(e){
    if(DBI::dbIsValid(con)) try(DBI::dbDisconnect(con),silent=TRUE)
    stop("Could not read analysis.diagnostic_results: ",conditionMessage(e),call.=FALSE)
  }
)

if(DBI::dbIsValid(con)) DBI::dbDisconnect(con)
cat("Database import complete: ",nrow(captures)," capture rows; ",nrow(diagnostics)," diagnostic rows.\n",sep="")

need_cap <- c("individual_id","tattoo","capture_date","is_pm","disease_status")
need_diag <- c("individual_id","tattoo","capture_date","test_family","sample_type","result")
miss_cap <- setdiff(need_cap,names(captures)); miss_diag <- setdiff(need_diag,names(diagnostics))
if(length(miss_cap)) stop("capture_history missing: ",paste(miss_cap,collapse=", "))
if(length(miss_diag)) stop("diagnostic_results missing: ",paste(miss_diag,collapse=", "))

# One LIVE biological capture occasion per individual/date.
live <- captures %>%
  filter(!is_pm) %>%
  transmute(
    individual_id,
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    capture_date=as.Date(capture_date),
    year=year(capture_date),
    stored_class=classify_stored(disease_status)
  ) %>%
  group_by(individual_id,tattoo,capture_date,year) %>%
  summarise(
    stored_class={
      z <- na.omit(stored_class)
      if(!length(z)) NA_character_ else {
        lev <- c("Negative"=1L,"Exposed"=2L,"Excretor"=3L,"Super excretor"=4L)
        z[which.max(unname(lev[z]))]
      }
    },
    .groups="drop"
  )

culture <- diagnostics %>%
  filter(test_family=="Culture") %>%
  transmute(
    individual_id,
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    capture_date=as.Date(capture_date),
    year=year(capture_date),
    sample_type=norm_sample(sample_type),
    result_upper=str_to_upper(str_squish(as.character(result))),
    is_pos=str_detect(result_upper,"M\\.BOVIS|M BOVIS")
  )

culture_occ <- culture %>%
  group_by(individual_id,tattoo,capture_date,year) %>%
  summarise(
    culture_rows=n(),
    culture_tested=TRUE,
    culture_positive=any(is_pos,na.rm=TRUE),
    positive_rows=sum(is_pos,na.rm=TRUE),
    positive_sample_types=n_distinct(sample_type[is_pos & !is.na(sample_type)]),
    positive_samples=paste(sort(unique(sample_type[is_pos & !is.na(sample_type)])),collapse=" | "),
    all_samples=paste(sort(unique(sample_type[!is.na(sample_type)])),collapse=" | "),
    .groups="drop"
  ) %>%
  mutate(
    derived_source_class=case_when(
      positive_sample_types>=2L ~ "Super excretor",
      culture_positive ~ "Excretor",
      culture_tested ~ "Culture negative",
      TRUE ~ NA_character_
    )
  )

occ <- live %>%
  left_join(culture_occ,by=c("individual_id","tattoo","capture_date","year")) %>%
  mutate(
    culture_tested=replace_na(culture_tested,FALSE),
    culture_positive=replace_na(culture_positive,FALSE),
    positive_rows=replace_na(positive_rows,0L),
    positive_sample_types=replace_na(positive_sample_types,0L),
    derived_source_class=if_else(culture_tested,derived_source_class,NA_character_)
  )

yearly <- occ %>%
  group_by(year) %>%
  summarise(
    live_capture_occasions=n(),
    culture_tested=sum(culture_tested),
    p_culture_tested=mean(culture_tested),
    culture_positive=sum(culture_positive),
    derived_excretor=sum(derived_source_class=="Excretor",na.rm=TRUE),
    derived_super=sum(derived_source_class=="Super excretor",na.rm=TRUE),
    stored_excretor=sum(stored_class=="Excretor",na.rm=TRUE),
    stored_super=sum(stored_class=="Super excretor",na.rm=TRUE),
    .groups="drop"
  )

validation <- occ %>%
  filter(year<=2014,!is.na(stored_class),culture_tested) %>%
  count(stored_class,derived_source_class,name="n") %>%
  group_by(stored_class) %>%
  mutate(prop_within_stored=n/sum(n)) %>%
  ungroup()

stored_source_validation <- occ %>%
  filter(year<=2014,stored_class %in% c("Excretor","Super excretor")) %>%
  group_by(stored_class) %>%
  summarise(
    stored_occasions=n(),
    culture_tested=sum(culture_tested),
    any_culture_positive=sum(culture_positive),
    at_least_2_positive_sample_types=sum(positive_sample_types>=2L),
    p_culture_positive=mean(culture_positive),
    p_two_plus_positive_sites=mean(positive_sample_types>=2L),
    .groups="drop"
  )

post2014 <- yearly %>% filter(year>=2015)
positive_sample_types_year <- culture %>% filter(is_pos) %>% count(year,sample_type,sort=TRUE,name="positive_rows")
post2014_positive_samples <- positive_sample_types_year %>% filter(year>=2015)

mismatch_examples <- occ %>%
  filter(year<=2014,stored_class %in% c("Excretor","Super excretor")) %>%
  mutate(expected_from_stored=case_when(
    stored_class=="Super excretor" ~ positive_sample_types>=2L,
    stored_class=="Excretor" ~ culture_positive & positive_sample_types<2L,
    TRUE ~ NA
  )) %>%
  filter(!expected_from_stored) %>%
  select(tattoo,capture_date,year,stored_class,culture_tested,culture_positive,positive_rows,
         positive_sample_types,positive_samples,all_samples) %>%
  arrange(year,capture_date,tattoo)

cat("\n============================================================\n")
cat("V7c CULTURE-BASED SOURCE-STATUS RECONSTRUCTION AUDIT V2\n")
cat("============================================================\n")
cat("Live capture occasions:",nrow(occ),"\n")
cat("Culture diagnostic rows:",nrow(culture),"\n\n")

cat("VALIDATION OF CULTURE RULE AGAINST STORED SOURCE LABELS <=2014\n")
print(stored_source_validation,n=Inf,width=Inf)

cat("\nSTORED CLASS x CULTURE-DERIVED CLASS <=2014\n")
print(validation,n=Inf,width=Inf)

cat("\nCULTURE-DERIVED SOURCE SUPPORT BY YEAR\n")
print(yearly,n=Inf,width=Inf)

cat("\nPOST-2014 CULTURE SUPPORT\n")
print(post2014,n=Inf,width=Inf)

cat("\nPOST-2014 POSITIVE CULTURE SAMPLE TYPES\n")
print(post2014_positive_samples,n=Inf,width=Inf)

cat("\nPRE-2015 SOURCE-LABEL MISMATCH EXAMPLES\n")
print(head(mismatch_examples,100),n=100,width=Inf)

cat("\nDECISION GUIDE\n")
cat("- If stored Super-excretor occasions overwhelmingly have >=2 positive culture sample types, the culture rule is empirically supported.\n")
cat("- If post-2014 culture testing and positive cultures continue, later source status can potentially be reconstructed.\n")
cat("- If culture testing itself becomes sparse, later no-source quarters cannot be treated as observed source absence without restriction/ascertainment modelling.\n")
cat("- Do NOT rerun the source-effect models until this audit determines the recoverable exposure period/definition.\n")

dir.create("results",showWarnings=FALSE,recursive=TRUE)
dir.create("data",showWarnings=FALSE,recursive=TRUE)
saveRDS(list(occasion=occ,yearly=yearly,validation=validation,stored_source_validation=stored_source_validation,
             post2014=post2014,positive_sample_types_year=positive_sample_types_year,mismatch_examples=mismatch_examples),
        "data/badger_V7c_culture_reconstruction_audit.rds")
write_csv(yearly,"results/V7c_culture_reconstruction_yearly.csv")
write_csv(validation,"results/V7c_culture_reconstruction_validation.csv")
write_csv(stored_source_validation,"results/V7c_culture_reconstruction_stored_source_validation.csv")
write_csv(post2014_positive_samples,"results/V7c_culture_reconstruction_post2014_positive_samples.csv")
write_csv(mismatch_examples,"results/V7c_culture_reconstruction_mismatches.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_culture_reconstruction_audit.rds\n")
cat("  results/V7c_culture_reconstruction_yearly.csv\n")
cat("  results/V7c_culture_reconstruction_validation.csv\n")
cat("  results/V7c_culture_reconstruction_stored_source_validation.csv\n")
cat("  results/V7c_culture_reconstruction_post2014_positive_samples.csv\n")
cat("  results/V7c_culture_reconstruction_mismatches.csv\n")
