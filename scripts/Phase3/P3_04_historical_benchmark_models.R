# PHASE 3 P3_04 — historical Rogers/Vicente benchmark models
#
# Purpose
#   Fit a deliberately small set of historical-style benchmark models before
#   the new Phase-3 spatiotemporal model.
#
# This is NOT claimed as an exact re-analysis of the original archived data.
# It asks whether the principal published relationships are recovered using
# our reconstructed capture histories, culture-only disease endpoint, annual
# social-group assignment and reconstructed MNA.
#
# Benchmarks
#   Rogers et al. 1998:
#     annual inter-group movement -> next-year culture incidence.
#
#   Vicente et al. 2007, group-level model A:
#     among groups with no prevalent excretor at start of year,
#     incident group ~ MNA size + MNA trend + adult-female % +
#       previous group movement index + incoming core moves + incoming outside.
#
#   Vicente et al. 2007, group incidence-proportion retained terms:
#     incident cases / susceptible animals ~ current group excretor prevalence +
#       MNA trend + previous group movement index * adult-female %.
#
# Outputs
#   results/Phase3/P3_04_rogers_lag_benchmark.csv
#   results/Phase3/P3_04_vicente_modelA_benchmark.csv
#   results/Phase3/P3_04_vicente_incidence_proportion_benchmark.csv
#   results/Phase3/P3_04_model_support.csv
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

if(!requireNamespace("lme4",quietly=TRUE))
  stop("Package 'lme4' is required for the historical GLMM benchmark.")

BENCH <- "data/phase3/P3_literature_benchmark_panel.rds"
MNA <- "data/phase3/P3_historical_MNA_reconstruction.rds"
ANCH <- "data/phase3/P3_published_core_anchor_audit.rds"

for(f in c(BENCH,MNA,ANCH)) if(!file.exists(f)) stop("Missing: ",f)
dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)

b <- readRDS(BENCH)
m <- readRDS(MNA)
a <- readRDS(ANCH)

iy <- as_tibble(b$individual_year)
gy <- as_tibble(b$groupyear)
rog <- as_tibble(b$rogers)
mna <- as_tibble(m$groupyear) %>%
  transmute(year=as.integer(year),
            resident_socg=as.character(mna_socg),
            mna_group_size=as.numeric(mna_group_size),
            mna_trend_pct=as.numeric(mna_trend_pct))
core <- unique(as.character(a$anchor$socg))

cat("\n============================================================\n")
cat("P3_04 — HISTORICAL ROGERS/VICENTE BENCHMARK MODELS\n")
cat("============================================================\n")

# =============================================================================
# 1. ROGERS: ANNUAL MOVEMENT -> NEXT-YEAR CULTURE INCIDENCE
# =============================================================================

rog_dat <- rog %>%
  filter(is.finite(movement_proportion),
         is.finite(next_year_culture_incidence))

rog_lm <- lm(next_year_culture_incidence ~ movement_proportion,data=rog_dat)
rog_cf <- summary(rog_lm)$coefficients

rog_out <- tibble(
  model="Rogers_lag_linear",
  n_years=nrow(rog_dat),
  term=rownames(rog_cf),
  estimate=rog_cf[,1],
  se=rog_cf[,2],
  statistic=rog_cf[,3],
  p=rog_cf[,4]
)

# MA(1) time-series sensitivity, matching the published final treatment.
rog_ma1_out <- NULL
if(nrow(rog_dat)>=8){
  mafit <- try(
    arima(
      rog_dat$next_year_culture_incidence,
      order=c(0,0,1),
      xreg=matrix(
        rog_dat$movement_proportion,
        ncol=1,
        dimnames=list(NULL,"movement_proportion")
      ),
      include.mean=TRUE,
      method="ML"
    ),
    silent=TRUE
  )
  if(!inherits(mafit,"try-error")){
    nm <- grep("movement_proportion",names(mafit$coef),value=TRUE)[1]
    est <- unname(mafit$coef[nm])
    se <- sqrt(unname(mafit$var.coef[nm,nm]))
    z <- est/se
    rog_ma1_out <- tibble(
      model="Rogers_lag_MA1",
      n_years=nrow(rog_dat),
      term="movement_proportion",
      estimate=est,
      se=se,
      statistic=z,
      p=2*pnorm(-abs(z))
    )
  }
}
rog_out <- bind_rows(rog_out,rog_ma1_out)

cat("\nROGERS BENCHMARK\n")
cat("Complete annual lag pairs:",nrow(rog_dat),"\n")
print(rog_out %>% filter(term=="movement_proportion"),n=Inf,width=Inf)
cat("Published benchmark: positive association; time-series t=3.09, P<0.01.\n")

# =============================================================================
# 2. BUILD VICENTE GROUP-YEAR COVARIATES
# =============================================================================

# Adult female percentage among annual residents.
# Vicente treated cubs separately; known-age animals age >=1 and adult-entry
# animals are counted here as adults. Unknown-age non-adult entries are omitted
# from the sex-ratio denominator.
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

# Annual movement into each core group. Direct consecutive-year movement from
# another core group is "core"; prior non-core residence is "outside".
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
    consecutive_previous=!is.na(previous_year)&year-previous_year==1L,
    incoming_core=
      consecutive_previous &
      previous_group %in% core &
      previous_group!=resident_socg,
    incoming_outside_observed=
      consecutive_previous &
      !is.na(previous_group) &
      !(previous_group %in% core),
    # Vicente classified adult first-captures in the core as immigrants.
    adult_first_core=
      year==first_core_year &
      age_fc=="ADULT" &
      (!consecutive_previous | is.na(previous_group) | !(previous_group %in% core)),
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

# =============================================================================
# 3. VICENTE GROUP MODEL A: INCIDENT VS NEGATIVE GROUPS
# =============================================================================

va <- vdat %>%
  filter(!group_start_prevalent) %>%
  drop_na(mna_group_size,mna_trend_pct,adult_female_pct,
          prev_group_movement_index)

cat("\nVICENTE MODEL A SUPPORT\n")
cat("Complete susceptible/negative-start group-years:",nrow(va),"\n")
cat("Published model A group-years: 242\n")
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

Aout <- tidy_glmer(fitA,"Vicente_group_model_A")

published_A <- tribble(
  ~term,~published_estimate,~published_result,
  "mna_group_size",0.08,"not significant",
  "mna_trend_pct",-0.03,"negative, P<0.0001",
  "adult_female_pct",-0.02,"negative, P<0.01",
  "prev_group_movement_index",-0.61,"not significant",
  "incoming_core",0.58,"positive, P<0.01",
  "incoming_outside",0.26,"not significant"
)

Aout <- Aout %>%
  left_join(published_A,by="term")

cat("\nVICENTE GROUP MODEL A\n")
print(Aout %>% filter(term!="(Intercept)"),n=Inf,width=Inf)

# =============================================================================
# 4. VICENTE GROUP INCIDENCE-PROPORTION RETAINED TERMS
# =============================================================================

vc <- vdat %>%
  filter(susceptible_start>0,
         incident_excretors<=susceptible_start) %>%
  drop_na(mna_trend_pct,adult_female_pct,
          prev_group_movement_index,excretor_prevalence_pct) %>%
  mutate(nonincident_susceptible=susceptible_start-incident_excretors)

cat("\nVICENTE INCIDENCE-PROPORTION SUPPORT\n")
cat("Complete group-years:",nrow(vc),"\n")

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

Cout <- tidy_glmer(fitC,"Vicente_group_incidence_proportion")

published_C <- tribble(
  ~term,~published_estimate,~published_result,
  "excretor_prevalence_pct",0.04,"positive",
  "mna_trend_pct",-0.01,"negative",
  "prev_group_movement_index",1.12,"positive",
  "prev_group_movement_index:adult_female_pct",-0.02,
    "negative interaction"
)

Cout <- Cout %>%
  left_join(published_C,by="term")

cat("\nVICENTE GROUP INCIDENCE-PROPORTION MODEL\n")
print(Cout %>% filter(term!="(Intercept)"),n=Inf,width=Inf)

# =============================================================================
# 5. SUPPORT / DIAGNOSTIC SUMMARY
# =============================================================================

support <- tibble(
  item=c(
    "Rogers complete annual lag pairs",
    "Vicente model A group-years",
    "Vicente incidence-proportion group-years",
    "Vicente model A groups",
    "Vicente model A years",
    "MNA source"
  ),
  value=c(
    as.character(nrow(rog_dat)),
    as.character(nrow(va)),
    as.character(nrow(vc)),
    as.character(n_distinct(va$resident_socg)),
    as.character(n_distinct(va$year)),
    "P3_03 reconstructed MNA"
  )
)

write_csv(rog_out,
          "results/Phase3/P3_04_rogers_lag_benchmark.csv")
write_csv(Aout,
          "results/Phase3/P3_04_vicente_modelA_benchmark.csv")
write_csv(Cout,
          "results/Phase3/P3_04_vicente_incidence_proportion_benchmark.csv")
write_csv(support,
          "results/Phase3/P3_04_model_support.csv")

saveRDS(
  list(
    rogers_data=rog_dat,
    rogers_model=rog_lm,
    vicente_data=vdat,
    vicente_modelA_data=va,
    vicente_modelA=fitA,
    vicente_incidence_data=vc,
    vicente_incidence_model=fitC,
    modelA_results=Aout,
    incidence_results=Cout,
    support=support,
    caveats=c(
      "Historical core is reconstructed from published anchors, not annual bait-marking polygons.",
      "MNA is reconstructed from first-to-last live histories and annual resident SG assignments.",
      "Outside immigrants include observed non-core-to-core transitions plus adult first-core entries.",
      "These are benchmark reproductions, not claims of exact recovery of the original SAS datasets."
    )
  ),
  "data/phase3/P3_historical_benchmark_models.rds"
)

cat("\n============================================================\n")
cat("P3_04 COMPLETE\n")
cat("============================================================\n")
cat("Interpret direction and support against the published benchmarks before Phase 3 modelling.\n")
