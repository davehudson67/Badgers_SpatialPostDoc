# =============================================================================
# WOODCHESTER V7c — WITHIN-GROUP EXPOSURE VARIATION / CAPTURE-INTENSITY AUDIT
#
# PURPOSE
# -------
# Before fitting a within-social-group sensitivity for the quarterly recipient
# hazard result, check whether observed Super-excretor exposure varies enough
# WITHIN groups through time and whether source classes differ strongly in the
# number of badgers captured in the exact group-quarter.
#
# This is descriptive only. It does not estimate infection effects.
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
    capture_date=as.Date(capture_date),year=year(capture_date),quarter=quarter(capture_date),
    qtime=qindex(year,quarter),socg=as.character(socg),disease_class=classify_disease(disease_status)
  ) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(capture_date),year<=END_YEAR)

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
  mutate(recipient_is_source=TRUE)

member_n <- quarter_members %>%
  count(year,quarter,qtime,socg,name="n_exact_members")

# Reproduce the hazard model's recipient-context definition: infectious source
# animals themselves are removed as recipients, but their source status remains
# attached to all OTHER recipients in that group-quarter.
context <- quarter_members %>%
  left_join(source_counts,by=c("year","quarter","qtime","socg")) %>%
  mutate(n_infectious_sources=replace_na(n_infectious_sources,0L),n_super_sources=replace_na(n_super_sources,0L)) %>%
  left_join(source_members %>% rename(tattoo=source_tattoo),by=c("tattoo","year","quarter","qtime","socg")) %>%
  mutate(recipient_is_source=replace_na(recipient_is_source,FALSE)) %>%
  filter(!recipient_is_source) %>%
  mutate(
    exposure_class=case_when(
      n_super_sources>0L ~ "SUPER",
      n_infectious_sources>0L ~ "ORDINARY_ONLY",
      TRUE ~ "NONE"
    ),
    exposure_class=factor(exposure_class,levels=c("NONE","ORDINARY_ONLY","SUPER")),
    context_id=paste(year,quarter,socg,sep="|")
  )

if(anyDuplicated(context[c("tattoo","qtime")])) stop("Internal error: duplicate recipient-quarter contexts remain.")

# One row per group-quarter represented in the actual recipient analysis.
gq <- context %>%
  group_by(context_id,year,quarter,qtime,socg,exposure_class,n_infectious_sources,n_super_sources) %>%
  summarise(n_recipient_contexts=n_distinct(tattoo),.groups="drop") %>%
  left_join(member_n,by=c("year","quarter","qtime","socg"))

by_group <- gq %>%
  group_by(socg) %>%
  summarise(
    group_quarters=n(),
    none_quarters=sum(exposure_class=="NONE"),
    ordinary_quarters=sum(exposure_class=="ORDINARY_ONLY"),
    super_quarters=sum(exposure_class=="SUPER"),
    has_super=super_quarters>0,
    has_non_super=(none_quarters+ordinary_quarters)>0,
    has_none=none_quarters>0,
    super_within_group_variation=has_super & has_non_super,
    super_vs_none_within_group=has_super & has_none,
    .groups="drop"
  ) %>%
  arrange(desc(super_quarters),desc(group_quarters),socg)

variation_summary <- tibble(
  measure=c(
    "Social groups represented",
    "Groups ever observed with a Super-excretor source",
    "Groups with Super AND non-Super recipient quarters",
    "Groups with Super AND no-source recipient quarters",
    "Groups ever observed with ordinary Excretor-only source",
    "Groups with all three exposure classes"
  ),
  n=c(
    nrow(by_group),
    sum(by_group$has_super),
    sum(by_group$super_within_group_variation),
    sum(by_group$super_vs_none_within_group),
    sum(by_group$ordinary_quarters>0),
    sum(by_group$none_quarters>0 & by_group$ordinary_quarters>0 & by_group$super_quarters>0)
  )
)

capture_intensity <- gq %>%
  group_by(exposure_class) %>%
  summarise(
    group_quarters=n(),groups=n_distinct(socg),
    median_exact_members=median(n_exact_members),q25_exact_members=unname(quantile(n_exact_members,.25)),
    q75_exact_members=unname(quantile(n_exact_members,.75)),mean_exact_members=mean(n_exact_members),
    median_recipient_contexts=median(n_recipient_contexts),
    first_year=min(year),last_year=max(year),.groups="drop"
  )

super_concentration <- by_group %>%
  filter(super_quarters>0) %>%
  mutate(prop_super_quarters=super_quarters/sum(super_quarters),cum_prop=cumsum(prop_super_quarters)) %>%
  select(socg,group_quarters,none_quarters,ordinary_quarters,super_quarters,prop_super_quarters,cum_prop,
         super_within_group_variation,super_vs_none_within_group)

cat("\n============================================================\n")
cat("V7c WITHIN-GROUP EXPOSURE VARIATION AUDIT\n")
cat("============================================================\n")
cat("Exact recipient contexts:",nrow(context),"\n")
cat("Recipient-analysis group-quarters:",nrow(gq),"\n")
cat("Ambiguous recipient quarters dropped:",nrow(ambiguous_q),"\n\n")

cat("WITHIN-GROUP EXPOSURE VARIATION\n")
print(variation_summary,n=Inf,width=Inf)

cat("\nCAPTURE INTENSITY BY EXPOSURE CLASS\n")
print(capture_intensity,n=Inf,width=Inf)

cat("\nSUPER EXPOSURE CONCENTRATION BY SOCIAL GROUP\n")
print(super_concentration,n=Inf,width=Inf)

cat("\nDECISION GUIDE\n")
cat("- Strong support for a within-group sensitivity requires many groups with both Super and non-Super/no-source quarters.\n")
cat("- Large differences in exact-quarter member counts by exposure class would motivate explicit capture-intensity adjustment.\n")
cat("- Cluster-robust SEs handle dependence but do not remove stable between-group confounding; the next model should therefore use a within-group/Mundlak decomposition if support is adequate.\n")

saveRDS(list(group_quarters=gq,by_group=by_group,variation_summary=variation_summary,capture_intensity=capture_intensity,
             super_concentration=super_concentration,settings=list(end_year=END_YEAR)),
        "data/badger_V7c_group_exposure_variation_audit.rds")
write_csv(variation_summary,"results/V7c_group_exposure_variation_summary.csv")
write_csv(capture_intensity,"results/V7c_group_exposure_capture_intensity.csv")
write_csv(super_concentration,"results/V7c_group_exposure_concentration.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_group_exposure_variation_audit.rds\n")
cat("  results/V7c_group_exposure_variation_summary.csv\n")
cat("  results/V7c_group_exposure_capture_intensity.csv\n")
cat("  results/V7c_group_exposure_concentration.csv\n")
