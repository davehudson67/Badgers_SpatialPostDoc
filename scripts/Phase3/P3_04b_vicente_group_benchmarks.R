# =============================================================================
# PHASE 3 / P3_04b — VICENTE 2007 GROUP-LEVEL BENCHMARKS
#
# Purpose
#   Reproduce the two Vicente group-level results most relevant to Phase 3:
#
#   Model A: among groups with no prevalent excretor at the start of year t,
#     incident group(t) ~ MNA size + MNA trend + adult-female % +
#       previous-year group movement index +
#       incoming core movers + incoming outside/core immigrants.
#
#   Model C: proportion of susceptible residents becoming incident excretors,
#     with current group excretor prevalence + MNA trend +
#     previous-year group movement index x adult-female %.
#
# Historical benchmark only. The annual core uses the published anchor scaffold
# reconstructed in P3_02d, and MNA is the validated reconstruction from P3_03.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

if(!requireNamespace("lme4",quietly=TRUE))
  stop("Package 'lme4' is required.")

BENCH <- "data/phase3/P3_literature_benchmark_panel.rds"
MNA <- "data/phase3/P3_historical_MNA_reconstruction.rds"
ANCH <- "data/phase3/P3_published_core_anchor_audit.rds"

for(f in c(BENCH,MNA,ANCH))
  if(!file.exists(f)) stop("Missing required file: ",f)

dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)

b <- readRDS(BENCH)
m <- readRDS(MNA)
a <- readRDS(ANCH)

iy <- as_tibble(b$individual_year)
gy <- as_tibble(b$groupyear)
core <- unique(as.character(a$anchor$socg))

mna <- as_tibble(m$groupyear) %>%
  transmute(
    year=as.integer(year),
    resident_socg=as.character(mna_socg),
    mna_group_size=as.numeric(mna_group_size),
    mna_trend_pct=as.numeric(mna_trend_pct)
  )

cat("\n============================================================\n")
cat("P3_04b — VICENTE GROUP-LEVEL BENCHMARKS\n")
cat("============================================================\n")

# -----------------------------------------------------------------------------
# Adult female percentage among annual residents.
# -----------------------------------------------------------------------------

sexratio <- iy %>%
  filter(year>=1990L,year<=2004L,resident_socg %in% core) %>%
  mutate(
    adult=case_when(
      age_fc=="ADULT" ~ TRUE,
      !is.na(birth_year) ~ (year-birth_year)>=1L,
      TRUE ~ FALSE
    )
  ) %>%
  filter(adult,sex %in% c("FEMALE","MALE")) %>%
  group_by(year,resident_socg) %>%
  summarise(
    n_adults=n(),
    n_adult_females=sum(sex=="FEMALE"),
    adult_female_pct=100*n_adult_females/n_adults,
    .groups="drop"
  )

# -----------------------------------------------------------------------------
# Incoming annual movement categories.
#
# Vicente:
#   core mover      = resident in one core group then another core group
#   core immigrant  = previously outside core OR adult first caught in core
# -----------------------------------------------------------------------------

arrivals <- iy %>%
  arrange(tattoo,year) %>%
  group_by(tattoo) %>%
  mutate(
    first_core_year=if(any(resident_socg %in% core))
      min(year[resident_socg %in% core]) else NA_integer_,
    previous_year=lag(year),
    previous_group=lag(resident_socg)
  ) %>%
  ungroup() %>%
  filter(year>=1990L,year<=2004L,resident_socg %in% core) %>%
  mutate(
    consecutive_previous=!is.na(previous_year) & year-previous_year==1L,
    incoming_core=
      consecutive_previous &
      previous_group %in% core &
      previous_group!=resident_socg,
    incoming_outside_observed=
      consecutive_previous &
      !is.na(previous_group) &
      !(previous_group %in% core),
    adult_first_core=
      year==first_core_year &
      age_fc=="ADULT" &
      (!consecutive_previous | is.na(previous_group) |
         !(previous_group %in% core)),
    incoming_outside=incoming_outside_observed | adult_first_core
  ) %>%
  group_by(year,resident_socg) %>%
  summarise(
    incoming_core=sum(incoming_core,na.rm=TRUE),
    incoming_outside=sum(incoming_outside,na.rm=TRUE),
    incoming_outside_observed=sum(incoming_outside_observed,na.rm=TRUE),
    adult_first_core=sum(adult_first_core,na.rm=TRUE),
    .groups="drop"
  )

# -----------------------------------------------------------------------------
# Group-year table.
# -----------------------------------------------------------------------------

vdat <- gy %>%
  filter(year>=1990L,year<=2004L,resident_socg %in% core) %>%
  left_join(mna,by=c("year","resident_socg")) %>%
  left_join(sexratio,by=c("year","resident_socg")) %>%
  left_join(arrivals,by=c("year","resident_socg")) %>%
  mutate(
    incoming_core=replace_na(incoming_core,0),
    incoming_outside=replace_na(incoming_outside,0),
    incoming_outside_observed=replace_na(incoming_outside_observed,0),
    adult_first_core=replace_na(adult_first_core,0),
    group_incident=incident_excretors>0,
    group_start_prevalent=prevalent_excretors_start>0,
    excretor_prevalence_pct=100*prior_excretor_prevalence
  )

tidy_glmer <- function(fit,model_name){
  cc <- summary(fit)$coefficients
  tibble(
    model=model_name,
    term=rownames(cc),
    estimate=cc[,1],
    se=cc[,2],
    z=cc[,3],
    p=cc[,4],
    OR=exp(cc[,1]),
    OR_low=exp(cc[,1]-1.96*cc[,2]),
    OR_high=exp(cc[,1]+1.96*cc[,2])
  )
}

# =============================================================================
# MODEL A — INCIDENT VS NEGATIVE GROUPS
# =============================================================================

va <- vdat %>%
  filter(!group_start_prevalent) %>%
  drop_na(
    mna_group_size,mna_trend_pct,adult_female_pct,
    prev_group_movement_index
  )

cat("\nMODEL A SUPPORT\n")
cat("Complete susceptible/negative-start group-years:",nrow(va),"\n")
cat("Published Vicente Model A group-years: 242\n")
cat("Distinct groups:",n_distinct(va$resident_socg),
    "| years:",n_distinct(va$year),"\n")
cat("Incident group-years:",sum(va$group_incident),"\n")

fitA <- lme4::glmer(
  group_incident ~
    mna_group_size +
    mna_trend_pct +
    adult_female_pct +
    prev_group_movement_index +
    incoming_core +
    incoming_outside +
    (1|resident_socg) + (1|year),
  data=va,
  family=binomial(),
  nAGQ=0,
  control=lme4::glmerControl(
    optimizer="bobyqa",
    optCtrl=list(maxfun=2e5),
    check.conv.singular="ignore"
  )
)

Aout <- tidy_glmer(fitA,"VICENTE_MODEL_A")

published_A <- tribble(
  ~term,~published_estimate,~published_p,~published_interpretation,
  "mna_group_size",0.08,"0.10","no clear association",
  "mna_trend_pct",-0.03,"<0.0001","declining group size -> higher incidence",
  "adult_female_pct",-0.02,"<0.01","more adult females -> lower incidence",
  "prev_group_movement_index",-0.61,"0.31","no clear association",
  "incoming_core",0.58,"<0.01","more core movers -> higher incidence",
  "incoming_outside",0.26,"0.32","no clear outside-immigrant association"
)

Acompare <- Aout %>%
  filter(term!="(Intercept)") %>%
  left_join(published_A,by="term") %>%
  mutate(
    direction_matches=case_when(
      is.na(published_estimate) ~ NA,
      TRUE ~ sign(estimate)==sign(published_estimate)
    )
  )

cat("\nMODEL A — OUR RESULTS VS PUBLISHED\n")
print(Acompare,n=Inf,width=Inf)

# =============================================================================
# MODEL C — INCIDENT CASES / SUSCEPTIBLE RESIDENTS
# =============================================================================

vc <- vdat %>%
  filter(
    susceptible_start>0,
    incident_excretors<=susceptible_start
  ) %>%
  drop_na(
    mna_trend_pct,adult_female_pct,
    prev_group_movement_index,excretor_prevalence_pct
  ) %>%
  mutate(nonincident_susceptible=susceptible_start-incident_excretors)

cat("\nMODEL C SUPPORT\n")
cat("Complete group-years:",nrow(vc),"\n")
cat("Published Vicente Model C group-years: 355\n")
cat("Distinct groups:",n_distinct(vc$resident_socg),
    "| years:",n_distinct(vc$year),"\n")
cat("Incident excretors:",sum(vc$incident_excretors),
    "| susceptible denominator:",sum(vc$susceptible_start),"\n")

fitC <- lme4::glmer(
  cbind(incident_excretors,nonincident_susceptible) ~
    excretor_prevalence_pct +
    mna_trend_pct +
    prev_group_movement_index * adult_female_pct +
    (1|resident_socg) + (1|year),
  data=vc,
  family=binomial(),
  nAGQ=0,
  control=lme4::glmerControl(
    optimizer="bobyqa",
    optCtrl=list(maxfun=2e5),
    check.conv.singular="ignore"
  )
)

Cout <- tidy_glmer(fitC,"VICENTE_MODEL_C")

published_C <- tribble(
  ~term,~published_estimate,~published_p,~published_interpretation,
  "excretor_prevalence_pct",0.04,"<0.001","higher local prevalence -> higher incidence",
  "mna_trend_pct",-0.01,"<0.05","declining group size -> higher incidence",
  "prev_group_movement_index",1.11,"0.03","higher prior group movement -> higher incidence",
  "prev_group_movement_index:adult_female_pct",-0.02,"<0.01",
    "movement association stronger in more male-biased groups"
)

Ccompare <- Cout %>%
  filter(term!="(Intercept)") %>%
  left_join(published_C,by="term") %>%
  mutate(
    direction_matches=case_when(
      is.na(published_estimate) ~ NA,
      TRUE ~ sign(estimate)==sign(published_estimate)
    )
  )

cat("\nMODEL C — OUR RESULTS VS PUBLISHED\n")
print(Ccompare,n=Inf,width=Inf)

# -----------------------------------------------------------------------------
# Movement support summary: useful if coefficients differ.
# -----------------------------------------------------------------------------

movement_support <- vdat %>%
  summarise(
    groupyears=n(),
    groupyears_with_movement_index=sum(is.finite(group_movement_index)),
    groupyears_with_prev_movement_index=sum(is.finite(prev_group_movement_index)),
    total_incoming_core=sum(incoming_core,na.rm=TRUE),
    total_incoming_outside=sum(incoming_outside,na.rm=TRUE),
    groupyears_with_core_arrival=sum(incoming_core>0,na.rm=TRUE),
    groupyears_with_outside_arrival=sum(incoming_outside>0,na.rm=TRUE)
  )

cat("\nMOVEMENT SUPPORT\n")
print(movement_support,width=Inf)

# -----------------------------------------------------------------------------
# Save.
# -----------------------------------------------------------------------------

write_csv(Acompare,
          "results/Phase3/P3_04b_vicente_modelA_comparison.csv")
write_csv(Ccompare,
          "results/Phase3/P3_04b_vicente_modelC_comparison.csv")
write_csv(movement_support,
          "results/Phase3/P3_04b_vicente_movement_support.csv")
write_csv(va,
          "results/Phase3/P3_04b_vicente_modelA_data.csv")
write_csv(vc,
          "results/Phase3/P3_04b_vicente_modelC_data.csv")

saveRDS(
  list(
    groupyear=vdat,
    modelA_data=va,
    modelA_fit=fitA,
    modelA_results=Acompare,
    modelC_data=vc,
    modelC_fit=fitC,
    modelC_results=Ccompare,
    movement_support=movement_support,
    published_reference=list(
      modelA_n=242L,
      modelC_n=355L
    ),
    caveats=c(
      "Historical core is reconstructed from published anchors, not exact annual bait-marking polygons.",
      "MNA is reconstructed and slightly high relative to the published benchmark.",
      "Core movers are annual resident-group changes within the reconstructed core.",
      "Outside immigrants are observed outside-to-core transitions plus adult first-core entries."
    )
  ),
  "results/Phase3/P3_04b_vicente_group_benchmarks.rds"
)

cat("\n============================================================\n")
cat("P3_04b COMPLETE\n")
cat("============================================================\n")
