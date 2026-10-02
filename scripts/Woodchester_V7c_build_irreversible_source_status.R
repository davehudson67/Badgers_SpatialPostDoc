# =============================================================================
# WOODCHESTER V7c — BUILD IRREVERSIBLE EXCRETOR / SUPER-EXCRETOR SOURCE HISTORY
#
# Biological rule supplied for this analysis:
# infection/disease progression is one-way. Once an animal has reached an
# Excretor or Super-excretor state, it does not revert to a lower source state.
#
# Historical rule:
# - through 2014, use curated disease_status as authoritative;
# - from 2015 onward, carry the highest historical source state forward;
# - upgrade to Excretor after any M. bovis culture-positive occasion;
# - upgrade to Super excretor after a >=2-positive-site culture occasion;
# - never downgrade.
#
# This script BUILDS AND AUDITS the reconstructed source history only. It does
# not yet refit any V7c source-effect model.
# =============================================================================

library(tidyverse)
library(lubridate)

CUM_FILE <- "data/badger_V7c_cumulative_source_status_audit.rds"
ENC_FILE <- "data/badger_encounters_useful.rds"
for(f in c(CUM_FILE,ENC_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

a <- readRDS(CUM_FILE)
h <- as_tibble(a$history)
enc <- as_tibble(readRDS(ENC_FILE))

need_h <- c("tattoo","capture_date","year","stored_class","current_positive","current_super_trigger")
miss <- setdiff(need_h,names(h)); if(length(miss)) stop("Cumulative audit missing: ",paste(miss,collapse=", "))

source_rank_from_stored <- function(x){
  case_when(x=="Super excretor" ~ 4L,x=="Excretor" ~ 3L,TRUE ~ 0L)
}

source_history <- h %>%
  transmute(
    tattoo=str_to_upper(str_squish(as.character(tattoo))),
    capture_date=as.Date(capture_date),year=as.integer(year),quarter=quarter(capture_date),
    stored_class=as.character(stored_class),
    stored_source_rank=source_rank_from_stored(stored_class),
    current_culture_positive=replace_na(as.logical(current_positive),FALSE),
    current_super_trigger=replace_na(as.logical(current_super_trigger),FALSE),
    culture_trigger_rank=case_when(current_super_trigger ~ 4L,current_culture_positive ~ 3L,TRUE ~ 0L)
  ) %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  mutate(
    anchor_rank_2014=max(if_else(year<=2014L,stored_source_rank,0L),na.rm=TRUE),
    post2014_trigger_rank=if_else(year>=2015L,culture_trigger_rank,0L),
    post2014_cumulative_trigger=cummax(post2014_trigger_rank),
    source_rank=if_else(year<=2014L,stored_source_rank,pmax(anchor_rank_2014,post2014_cumulative_trigger)),
    source_class=case_when(source_rank>=4L ~ "Super excretor",source_rank>=3L ~ "Excretor",TRUE ~ "No observed excretor state"),
    prev_source_rank=lag(source_rank),
    source_downgrade=!is.na(prev_source_rank) & source_rank<prev_source_rank
  ) %>%
  ungroup()

# Add exact live social group where available.
enc_live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(tattoo=str_to_upper(str_squish(as.character(tattoo))),capture_date=as.Date(capture_date),socg=as.character(socg)) %>%
  filter(!is.na(tattoo),tattoo!="") %>%
  group_by(tattoo,capture_date) %>%
  summarise(socg={z<-unique(na.omit(socg)); if(length(z)==1L) z else NA_character_},.groups="drop")

source_history <- source_history %>% left_join(enc_live,by=c("tattoo","capture_date"))

if(any(source_history$source_downgrade,na.rm=TRUE)) stop("Internal error: reconstructed source history contains a downgrade.")

# ----------------------------------------------------------------------------
# Audits
# ----------------------------------------------------------------------------
pre2015_source <- source_history %>%
  filter(year<=2014L,stored_class %in% c("Excretor","Super excretor")) %>%
  count(stored_class,source_class,name="n")

post2014_yearly <- source_history %>%
  filter(year>=2015L) %>%
  group_by(year) %>%
  summarise(
    live_occasions=n(),unique_badgers=n_distinct(tattoo),
    excretor_occasions=sum(source_class=="Excretor"),super_occasions=sum(source_class=="Super excretor"),
    source_badgers=n_distinct(tattoo[source_rank>=3L]),super_badgers=n_distinct(tattoo[source_rank>=4L]),
    current_positive_triggers=sum(current_culture_positive),current_super_triggers=sum(current_super_trigger),
    .groups="drop"
  )

gq <- source_history %>%
  filter(!is.na(socg),socg!="",year<=2025L) %>%
  group_by(year,quarter,socg) %>%
  summarise(
    n_captured=n_distinct(tattoo),n_sources=n_distinct(tattoo[source_rank>=3L]),n_super=n_distinct(tattoo[source_rank>=4L]),
    any_source=n_sources>0L,any_super=n_super>0L,.groups="drop"
  )

gq_yearly <- gq %>%
  group_by(year) %>%
  summarise(group_quarters=n(),source_group_quarters=sum(any_source),super_group_quarters=sum(any_super),.groups="drop")

post2014_recovered <- source_history %>%
  filter(year>=2015L) %>%
  summarise(
    occasions=n(),
    stored_source_occasions=sum(stored_source_rank>=3L),
    reconstructed_source_occasions=sum(source_rank>=3L),
    reconstructed_super_occasions=sum(source_rank>=4L),
    source_occasions_recovered=sum(source_rank>=3L & stored_source_rank<3L)
  )

cat("\n============================================================\n")
cat("V7c IRREVERSIBLE SOURCE-STATUS RECONSTRUCTION\n")
cat("============================================================\n")
cat("Rule: curated source state through 2014; irreversible carry-forward + culture-triggered upgrades from 2015.\n\n")

cat("PRE-2015 SOURCE-STATE ANCHOR CHECK\n")
print(pre2015_source,n=Inf,width=Inf)

cat("\nPOST-2014 RECONSTRUCTED SOURCE SUPPORT BY YEAR\n")
print(post2014_yearly,n=Inf,width=Inf)

cat("\nPOST-2014 SOURCE OCCASIONS RECOVERED FROM MISSING disease_status\n")
print(post2014_recovered,n=Inf,width=Inf)

cat("\nEXACT SOCIAL-GROUP QUARTER SOURCE SUPPORT BY YEAR\n")
print(gq_yearly,n=Inf,width=Inf)

cat("\nQC\n")
cat("Reconstructed source-state downgrades:",sum(source_history$source_downgrade,na.rm=TRUE),"\n")
cat("Unique badgers:",n_distinct(source_history$tattoo),"\n")
cat("Source badgers ever:",n_distinct(source_history$tattoo[source_history$source_rank>=3L]),"\n")
cat("Super-excretor badgers ever:",n_distinct(source_history$tattoo[source_history$source_rank>=4L]),"\n")

cat("\nINTERPRETATION\n")
cat("- Historical <=2014 source labels are not overwritten by imperfect culture reconstruction.\n")
cat("- From 2015 onward, source state is extended under the biologically required irreversible rule.\n")
cat("- A current negative culture does not downgrade a previously attained Excretor/Super-excretor state.\n")
cat("- The next V7c model should use this source-history object rather than raw disease_status.\n")

dir.create("data",showWarnings=FALSE,recursive=TRUE); dir.create("results",showWarnings=FALSE,recursive=TRUE)
saveRDS(source_history,"data/badger_V7c_irreversible_source_status.rds")
write_csv(post2014_yearly,"results/V7c_irreversible_source_status_post2014.csv")
write_csv(gq_yearly,"results/V7c_irreversible_source_group_quarter_support.csv")
write_csv(post2014_recovered,"results/V7c_irreversible_source_status_recovered.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_irreversible_source_status.rds\n")
cat("  results/V7c_irreversible_source_status_post2014.csv\n")
cat("  results/V7c_irreversible_source_group_quarter_support.csv\n")
cat("  results/V7c_irreversible_source_status_recovered.csv\n")
