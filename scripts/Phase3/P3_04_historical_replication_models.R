# =============================================================================
# PHASE 3 / P3_04 — HISTORICAL ROGERS / VICENTE REPLICATION BRIDGE
#
# Goal
#   Fit a small set of historical-style benchmark models BEFORE the new Phase-3
#   source-connectivity model.
#
# Models
#   A. Rogers-style annual movement(t) -> culture incidence(t+1), 1978-1995.
#      We fit both:
#        - all recorded study-area groups (sensitivity / best raw-rate match);
#        - published early-core anchor groups (near-core sensitivity; 21 known
#          named anchors rather than claiming the exact historical 22).
#
#   B. Vicente-style individual incident-excretor GLMM, 1990-2004.
#      This mirrors the published final model as closely as the reconstructed
#      data allow: sex, toothwear, MNA group size/trend, group sex ratio,
#      focal-excluded excretor prevalence, annual movement class, previous-year
#      group movement index, capture count, and published interactions.
#
#   C. Vicente-style group incident-vs-negative GLMM, 1990-2004.
#      Focuses on the published group-level pathways: MNA size/trend, sex ratio,
#      previous group movement, incoming core movers, and incoming immigrants.
#
# These are benchmark/replication models, not the final Phase-3 model.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

if(!requireNamespace("lme4",quietly=TRUE))
  stop("Package 'lme4' is required for the historical GLMM benchmarks.")

MEM <- "data/phase3/P3_annual_recorded_membership.rds"
BENCH <- "data/phase3/P3_literature_benchmark_panel.rds"
MNA <- "data/phase3/P3_historical_MNA_reconstruction.rds"
ANCH <- "data/phase3/P3_published_core_anchor_audit.rds"
ENC <- "data/badger_encounters_useful.rds"

for(f in c(MEM,BENCH,MNA,ANCH,ENC))
  if(!file.exists(f)) stop("Missing required file: ",f)

dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)

mem <- readRDS(MEM)
b <- readRDS(BENCH)
mna <- readRDS(MNA)
anch <- readRDS(ANCH)
enc <- as_tibble(readRDS(ENC))

clean_sg <- function(x){
  z <- toupper(stringr::str_squish(as.character(x)))
  z <- stringr::str_replace_all(z,"[^A-Z0-9]","")
  z[z==""|z=="NA"] <- NA_character_
  dplyr::recode(z,
                "CHESTNUT"="BEECH",
                "HOLLOWTREE"="NETTLE",
                "JACKS"="JACKSMIREY",
                "COLLIERS"="COLLIERSWOOD",
                .default=z)
}

tidy_glmer <- function(fit,model_name){
  z <- as.data.frame(coef(summary(fit)))
  z$term <- rownames(z)
  rownames(z) <- NULL
  names(z)[1:4] <- c("estimate","std_error","z_value","p_value")
  as_tibble(z) %>%
    mutate(model=model_name,
           odds_ratio=exp(estimate),
           ci_low=exp(estimate-1.96*std_error),
           ci_high=exp(estimate+1.96*std_error)) %>%
    select(model,term,estimate,std_error,z_value,p_value,
           odds_ratio,ci_low,ci_high)
}

fit_glmer <- function(formula,data){
  lme4::glmer(
    formula,data=data,family=binomial(),
    control=lme4::glmerControl(
      optimizer="bobyqa",
      optCtrl=list(maxfun=2e5)
    )
  )
}

cat("\n============================================================\n")
cat("P3_04 — HISTORICAL ROGERS / VICENTE REPLICATION BRIDGE\n")
cat("============================================================\n")

# =============================================================================
# A. ROGERS 1998: annual inter-group movement -> next-year culture incidence
# =============================================================================

core_early <- anch$anchor %>%
  filter(in_core_1978_1993 %in% TRUE) %>%
  pull(socg) %>%
  as.character()

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    capture_date=as.Date(capture_date),
    year=year(capture_date),
    socg=clean_sg(socg)
  ) %>%
  filter(tattoo!="",!is.na(capture_date),!is.na(socg)) %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  mutate(
    next_socg=lead(socg),
    next_date=lead(capture_date),
    move_next=if_else(!is.na(next_socg),
                      as.integer(socg!=next_socg),NA_integer_)
  ) %>%
  ungroup()

iy <- as_tibble(b$individual_year) %>%
  mutate(
    resident_socg=clean_sg(resident_socg),
    culture_incident=as.integer(incident_excretor %in% TRUE),
    susceptible=as.integer(susceptible_start %in% TRUE)
  )

annual_inc_all <- iy %>%
  group_by(year) %>%
  summarise(
    incidents=sum(culture_incident,na.rm=TRUE),
    susceptible=sum(susceptible,na.rm=TRUE),
    incidence=if_else(susceptible>0,incidents/susceptible,NA_real_),
    .groups="drop"
  )

annual_inc_core <- iy %>%
  filter(resident_socg %in% core_early) %>%
  group_by(year) %>%
  summarise(
    incidents=sum(culture_incident,na.rm=TRUE),
    susceptible=sum(susceptible,na.rm=TRUE),
    incidence=if_else(susceptible>0,incidents/susceptible,NA_real_),
    .groups="drop"
  )

move_all <- live %>%
  filter(year>=1978L,year<=1995L,!is.na(move_next)) %>%
  group_by(year) %>%
  summarise(
    n_scorable=n(),
    n_moves=sum(move_next),
    movement_proportion=mean(move_next),
    .groups="drop"
  )

move_core <- live %>%
  filter(year>=1978L,year<=1995L,
         socg %in% core_early,
         next_socg %in% core_early,
         !is.na(move_next)) %>%
  group_by(year) %>%
  summarise(
    n_scorable=n(),
    n_moves=sum(move_next),
    movement_proportion=mean(move_next),
    .groups="drop"
  )

make_rogers <- function(mv,inc,label){
  d <- mv %>%
    left_join(
      inc %>% transmute(
        year=year-1L,
        next_year_incidence=incidence,
        next_year_incidents=incidents,
        next_year_susceptible=susceptible
      ),
      by="year"
    ) %>%
    filter(is.finite(movement_proportion),
           is.finite(next_year_incidence)) %>%
    arrange(year)

  lm_fit <- lm(next_year_incidence~movement_proportion,data=d)

  # Rogers' final test allowed MA(1) serial correlation. With only 18 annual
  # values this is a benchmark, not an exact recreation of the original series.
  ar_fit <- try(
    arima(
      d$next_year_incidence,
      order=c(0,0,1),
      xreg=matrix(d$movement_proportion,ncol=1,
                  dimnames=list(NULL,"movement_proportion")),
      include.mean=TRUE,
      method="ML"
    ),
    silent=TRUE
  )

  lm_tab <- as.data.frame(coef(summary(lm_fit))) %>%
    rownames_to_column("term") %>%
    as_tibble()
  names(lm_tab)[2:5] <- c("estimate","std_error","t_value","p_value")
  lm_tab <- lm_tab %>% mutate(series=label,model="OLS")

  ar_tab <- tibble()
  if(!inherits(ar_fit,"try-error")){
    cf <- coef(ar_fit)
    vv <- diag(ar_fit$var.coef)
    ar_tab <- tibble(
      series=label,model="MA1",
      term=names(cf),estimate=as.numeric(cf),
      std_error=sqrt(vv),
      z_value=estimate/std_error,
      p_value=2*pnorm(abs(z_value),lower.tail=FALSE)
    )
  }

  list(data=d,lm=lm_fit,ar=ar_fit,lm_tab=lm_tab,ar_tab=ar_tab)
}

rog_all <- make_rogers(move_all,annual_inc_all,"ALL_RECORDED_GROUPS")
rog_core <- make_rogers(move_core,annual_inc_core,"EARLY_CORE_ANCHOR")

rogers_coef <- bind_rows(rog_all$lm_tab,rog_core$lm_tab,
                         rog_all$ar_tab,rog_core$ar_tab)

cat("\nA. ROGERS-STYLE LAGGED ANNUAL ASSOCIATION\n")
cat("All-area movement proportion:",
    round(sum(move_all$n_moves)/sum(move_all$n_scorable),3),"\n")
cat("Early-core-anchor movement proportion:",
    round(sum(move_core$n_moves)/sum(move_core$n_scorable),3),"\n")
cat("Published Rogers reference: ~0.12 movement proportion and positive lagged association.\n")
print(
  rogers_coef %>%
    filter(term=="movement_proportion") %>%
    select(any_of(c("series","model","estimate","std_error","t_value","z_value","p_value"))),
  n=Inf,width=Inf
)

# =============================================================================
# Shared annual metrics for Vicente models
# =============================================================================

core_union <- unique(as.character(anch$anchor$socg))

capture_year <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    year=year(as.Date(capture_date)),
    toothwear=suppressWarnings(as.numeric(as.character(toothwear)))
  ) %>%
  group_by(tattoo,year) %>%
  summarise(
    n_live_captures=n(),
    mean_toothwear=if(all(is.na(toothwear))) NA_real_
                   else mean(toothwear,na.rm=TRUE),
    .groups="drop"
  )

iy2 <- iy %>%
  arrange(tattoo,year) %>%
  group_by(tattoo) %>%
  mutate(
    previous_observed_year=lag(year),
    previous_resident_socg=lag(resident_socg),
    consecutive_previous=year-previous_observed_year==1L
  ) %>%
  ungroup() %>%
  group_by(tattoo) %>%
  mutate(
    first_core_year=if(any(resident_socg %in% core_union))
      min(year[resident_socg %in% core_union]) else NA_integer_
  ) %>%
  ungroup() %>%
  mutate(
    in_core=resident_socg %in% core_union,
    previous_in_core=previous_resident_socg %in% core_union,
    movement_class=case_when(
      !in_core ~ NA_character_,
      consecutive_previous & previous_in_core &
        previous_resident_socg==resident_socg ~ "NON_MOVER",
      consecutive_previous & previous_in_core &
        previous_resident_socg!=resident_socg ~ "CORE_MOVER",
      consecutive_previous & !previous_in_core &
        !is.na(previous_resident_socg) ~ "CORE_IMMIGRANT",
      year==first_core_year & age_fc=="ADULT" ~ "CORE_IMMIGRANT",
      TRUE ~ NA_character_
    ),
    adult_for_ratio=case_when(
      !is.na(birth_year) ~ year-birth_year>=1L,
      age_fc %in% c("ADULT","YEARLING") ~ TRUE,
      TRUE ~ FALSE
    ),
    excretor_by_year=!is.na(first_culture_year) &
      first_culture_year<=year
  ) %>%
  left_join(capture_year,by=c("tattoo","year"))

# Current group prevalence, excluding focal individual.
group_epi <- iy2 %>%
  filter(in_core,year>=1990L,year<=2004L) %>%
  group_by(year,resident_socg) %>%
  summarise(
    group_residents=n(),
    group_excretors_by_year=sum(excretor_by_year,na.rm=TRUE),
    adult_n=sum(adult_for_ratio,na.rm=TRUE),
    adult_female_n=sum(adult_for_ratio & sex=="FEMALE",na.rm=TRUE),
    group_sex_ratio_pct=if_else(adult_n>0,100*adult_female_n/adult_n,NA_real_),
    .groups="drop"
  )

# Previous-year movement index of the actual previous resident group.
gmove_lookup <- as_tibble(b$groupyear) %>%
  transmute(
    move_year=as.integer(year),
    move_socg=clean_sg(resident_socg),
    group_movement_index
  )

mna_gy <- as_tibble(mna$groupyear) %>%
  transmute(
    year=as.integer(year),
    resident_socg=clean_sg(mna_socg),
    mna_group_size,
    mna_trend_pct
  )

# =============================================================================
# B. VICENTE INDIVIDUAL-LEVEL MODEL
# =============================================================================

ind_dat <- iy2 %>%
  filter(
    in_core,
    year>=1990L,year<=2004L,
    susceptible_start %in% TRUE,
    !is.na(movement_class)
  ) %>%
  left_join(group_epi,by=c("year","resident_socg")) %>%
  left_join(mna_gy,by=c("year","resident_socg")) %>%
  mutate(
    move_year=year-1L,
    move_socg=previous_resident_socg
  ) %>%
  left_join(gmove_lookup,by=c("move_year","move_socg")) %>%
  mutate(
    group_tb_prevalence_pct_excl=
      if_else(
        group_residents>1L,
        100*(group_excretors_by_year-as.integer(excretor_by_year))/
          (group_residents-1L),
        NA_real_
      ),
    log10_captures=log10(pmax(n_live_captures,1)),
    sex=factor(sex,levels=c("FEMALE","MALE")),
    movement_class=factor(
      movement_class,
      levels=c("CORE_IMMIGRANT","NON_MOVER","CORE_MOVER")
    ),
    incident=as.integer(incident_excretor %in% TRUE),
    group_factor=factor(resident_socg),
    year_factor=factor(year)
  )

ind_formula <- incident ~
  sex +
  mean_toothwear +
  mna_group_size +
  mna_trend_pct +
  group_sex_ratio_pct +
  group_tb_prevalence_pct_excl +
  movement_class +
  group_movement_index +
  log10_captures +
  sex:group_sex_ratio_pct +
  group_sex_ratio_pct:group_movement_index +
  mna_trend_pct:group_tb_prevalence_pct_excl +
  (1|group_factor) + (1|year_factor)

ind_cc <- ind_dat %>%
  filter(if_all(
    c(incident,sex,mean_toothwear,mna_group_size,mna_trend_pct,
      group_sex_ratio_pct,group_tb_prevalence_pct_excl,movement_class,
      group_movement_index,log10_captures,group_factor,year_factor),
    ~!is.na(.)
  ))

if(nrow(ind_cc)<100)
  stop("Too few complete cases for Vicente individual model: ",nrow(ind_cc))

fit_ind <- fit_glmer(ind_formula,ind_cc)
ind_coef <- tidy_glmer(fit_ind,"VICENTE_INDIVIDUAL")

cat("\nB. VICENTE-STYLE INDIVIDUAL INCIDENT-EXCRETOR MODEL\n")
cat("Complete individual-years:",nrow(ind_cc),
    "| incident excretors:",sum(ind_cc$incident),"\n")
cat("Movement classes:\n")
print(ind_cc %>% count(movement_class),n=Inf,width=Inf)
cat("Key coefficients:\n")
print(
  ind_coef %>%
    filter(
      term %in% c(
        "mna_trend_pct","group_tb_prevalence_pct_excl",
        "movement_classNON_MOVER","movement_classCORE_MOVER",
        "group_movement_index"
      )
    ),
  n=Inf,width=Inf
)

# =============================================================================
# C. VICENTE GROUP-LEVEL INCIDENT-vs-NEGATIVE MODEL
# =============================================================================

# Incoming annual movement classes by destination group.
incoming <- iy2 %>%
  filter(
    in_core,year>=1990L,year<=2004L,
    movement_class %in% c("CORE_MOVER","CORE_IMMIGRANT")
  ) %>%
  group_by(year,resident_socg) %>%
  summarise(
    incoming_core=sum(movement_class=="CORE_MOVER"),
    incoming_outside=sum(movement_class=="CORE_IMMIGRANT"),
    .groups="drop"
  )

gy0 <- as_tibble(b$groupyear) %>%
  mutate(
    resident_socg=clean_sg(resident_socg),
    in_core=resident_socg %in% core_union
  ) %>%
  filter(in_core,year>=1990L,year<=2004L) %>%
  select(year,resident_socg,incident_excretors,
         prevalent_excretors_start,group_movement_index)

grp_dat <- gy0 %>%
  left_join(mna_gy,by=c("year","resident_socg")) %>%
  left_join(group_epi %>%
              select(year,resident_socg,group_sex_ratio_pct),
            by=c("year","resident_socg")) %>%
  left_join(incoming,by=c("year","resident_socg")) %>%
  mutate(
    incoming_core=replace_na(incoming_core,0L),
    incoming_outside=replace_na(incoming_outside,0L)
  ) %>%
  group_by(resident_socg) %>%
  arrange(year,.by_group=TRUE) %>%
  mutate(
    previous_group_movement_index=lag(group_movement_index)
  ) %>%
  ungroup() %>%
  mutate(
    # Closest reconstruction of Vicente model (a): no prevalent resident case
    # at the start of the current year; response is >=1 new culture excretor.
    susceptible_group=prevalent_excretors_start==0L,
    incident_group=as.integer(incident_excretors>0L),
    group_factor=factor(resident_socg),
    year_factor=factor(year)
  ) %>%
  filter(susceptible_group)

grp_formula <- incident_group ~
  mna_group_size +
  mna_trend_pct +
  group_sex_ratio_pct +
  previous_group_movement_index +
  incoming_core +
  incoming_outside +
  (1|group_factor) + (1|year_factor)

grp_cc <- grp_dat %>%
  filter(if_all(
    c(incident_group,mna_group_size,mna_trend_pct,group_sex_ratio_pct,
      previous_group_movement_index,incoming_core,incoming_outside,
      group_factor,year_factor),
    ~!is.na(.)
  ))

if(nrow(grp_cc)<50)
  stop("Too few complete cases for Vicente group model: ",nrow(grp_cc))

fit_grp <- fit_glmer(grp_formula,grp_cc)
grp_coef <- tidy_glmer(fit_grp,"VICENTE_GROUP")

cat("\nC. VICENTE-STYLE GROUP INCIDENT-vs-NEGATIVE MODEL\n")
cat("Complete susceptible group-years:",nrow(grp_cc),
    "| incident group-years:",sum(grp_cc$incident_group),"\n")
print(
  grp_coef %>%
    filter(term %in% c(
      "mna_group_size","mna_trend_pct","group_sex_ratio_pct",
      "previous_group_movement_index","incoming_core","incoming_outside"
    )),
  n=Inf,width=Inf
)

# =============================================================================
# D. PUBLISHED DIRECTION BENCHMARK TABLE
# =============================================================================

published_group <- tribble(
  ~term,~published_estimate,~published_p,~published_interpretation,
  "mna_group_size",0.08,0.10,"no clear association",
  "mna_trend_pct",-0.03,"<0.0001","declining group size -> higher incidence",
  "group_sex_ratio_pct",-0.02,"<0.01","higher female proportion -> lower incidence",
  "previous_group_movement_index",-0.61,0.31,"no clear group-index association",
  "incoming_core",0.58,"<0.01","more core immigrants -> higher incidence",
  "incoming_outside",0.26,0.32,"no clear outside-immigrant association"
)

group_compare <- published_group %>%
  left_join(
    grp_coef %>%
      select(term,our_estimate=estimate,our_se=std_error,
             our_p=p_value,our_or=odds_ratio,
             our_ci_low=ci_low,our_ci_high=ci_high),
    by="term"
  ) %>%
  mutate(
    direction_matches=case_when(
      is.na(our_estimate) ~ NA,
      published_estimate==0 ~ NA,
      TRUE ~ sign(published_estimate)==sign(our_estimate)
    )
  )

cat("\nD. VICENTE GROUP-MODEL DIRECTION CHECK\n")
print(group_compare,n=Inf,width=Inf)

# =============================================================================
# SAVE
# =============================================================================

write_csv(rogers_coef,
          "results/Phase3/P3_04_rogers_lagged_model_coefficients.csv")
write_csv(ind_coef,
          "results/Phase3/P3_04_vicente_individual_coefficients.csv")
write_csv(grp_coef,
          "results/Phase3/P3_04_vicente_group_coefficients.csv")
write_csv(group_compare,
          "results/Phase3/P3_04_vicente_group_published_comparison.csv")
write_csv(rog_all$data,
          "results/Phase3/P3_04_rogers_allarea_annual_series.csv")
write_csv(rog_core$data,
          "results/Phase3/P3_04_rogers_coreanchor_annual_series.csv")

saveRDS(
  list(
    rogers_all=rog_all,
    rogers_core=rog_core,
    vicente_individual_fit=fit_ind,
    vicente_individual_data=ind_cc,
    vicente_individual_coefficients=ind_coef,
    vicente_group_fit=fit_grp,
    vicente_group_data=grp_cc,
    vicente_group_coefficients=grp_coef,
    group_published_comparison=group_compare,
    caveats=c(
      "Rogers exact historical 22-core membership is not fully recovered",
      "Vicente core uses published historical anchor scaffold, not exact annual bait-marking polygons",
      "MNA is reconstructed and slightly high relative to published benchmark",
      "capture count and toothwear are reconstructed from the current cleaned archive"
    )
  ),
  "results/Phase3/P3_04_historical_replication_models.rds"
)

cat("\n============================================================\n")
cat("P3_04 COMPLETE\n")
cat("============================================================\n")
cat("Interpret against published directions first; do not treat numerical equality as required.\n")
