# =============================================================================
# PHASE 3 / P3_07 — LOCAL VS EXTERNAL INFECTED CONNECTIVITY
#
# Main Phase-3 disease model.
#
# Question
#   For a recipient social group, is infection in year t+1 associated with:
#     (1) infection already present locally in that group at Q4(t); and/or
#     (2) infection in OTHER groups connected to it by recent directed
#         capture-transition movement?
#
# Primary exposure:
#   ExternalPressure[g,t] = sum_{h != g} I[h,t] * C[h->g,t]
# using the trailing 5-year network from P3_06.
#
# Outcome:
#   posterior latent infection acquisitions among residents of group g during
#   t+1, conditional on being susceptible at Q4(t).
#
# Models:
#   LOCAL:
#     future infection ~ within infection + group size + group-size change
#
#   LOCAL_EXTERNAL:
#     LOCAL + external infected connectivity
#
# Both include random intercepts for recipient group and outcome year.
# Thus the external effect is identified largely from differences among groups
# within the same year, rather than from a crude pre/post time contrast.
#
# Infection uncertainty:
#   Fit each model to every coherent infection-trajectory draw, then combine
#   latent-history uncertainty with coefficient-estimation uncertainty by
#   drawing from the fixed-effect covariance matrix for each fitted draw.
#
# Primary restrictions:
#   exposure years 1980-2024 (full trailing-network era and complete outcome
#   through 2025);
#   >=3 residents in exposure group;
#   >=3 residents in outcome group;
#   consecutive group-size observations for the size-change control.
#
# No 2018 indicator is fitted. 2018 remains descriptive/contextual only.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

if(!requireNamespace("lme4",quietly=TRUE))
  stop("Package 'lme4' is required.")

PRESSURE_FILE <- "data/phase3/P3_external_infected_connectivity.rds"
MEM_FILE <- "data/phase3/P3_annual_recorded_membership.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"

for(f in c(PRESSURE_FILE,MEM_FILE,INF_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)

p6 <- readRDS(PRESSURE_FILE)
mem <- readRDS(MEM_FILE)
inf <- readRDS(INF_FILE)

N_KEEP <- as.integer(Sys.getenv("N_KEEP","20"))
MIN_SOURCE_N <- as.integer(Sys.getenv("MIN_SOURCE_N","3"))
MIN_OUTCOME_N <- as.integer(Sys.getenv("MIN_OUTCOME_N","3"))
FIRST_EXPOSURE_YEAR <- as.integer(Sys.getenv("FIRST_EXPOSURE_YEAR","1980"))
LAST_EXPOSURE_YEAR <- as.integer(Sys.getenv("LAST_EXPOSURE_YEAR","2024"))
SEED <- as.integer(Sys.getenv("SEED","7092077"))
set.seed(SEED)

clean_sg <- function(x){
  z <- toupper(stringr::str_squish(as.character(x)))
  z <- stringr::str_replace_all(z,"[^A-Z0-9]","")
  z[z==""|z=="NA"] <- NA_character_
  dplyr::recode(
    z,
    "CHESTNUT"="BEECH",
    "HOLLOWTREE"="NETTLE",
    "JACKS"="JACKSMIREY",
    "COLLIERS"="COLLIERSWOOD",
    .default=z
  )
}

annual <- as_tibble(mem$annual_membership) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    year=as.integer(year),
    resident_socg=clean_sg(candidate_resident_socg)
  ) %>%
  filter(!is.na(resident_socg),resident_socg!="") %>%
  distinct(tattoo,year,.keep_all=TRUE)

if(anyDuplicated(annual[c("tattoo","year")]))
  stop("Annual resident membership duplicated by tattoo-year.")

INF_IDS <- trimws(as.character(inf$tattoo))
START_YEAR <- as.integer(inf$start_year)
N_DRAW <- ncol(inf$infection_time)

if(!is.matrix(inf$infection_time))
  stop("inf$infection_time must be a matrix.")
if(nrow(inf$infection_time)!=length(INF_IDS))
  stop("infection_time row mismatch.")
if(anyDuplicated(INF_IDS))
  stop("Duplicate infection tattoos.")

cat("\n============================================================\n")
cat("P3_07 — LOCAL VS EXTERNAL INFECTED CONNECTIVITY\n")
cat("============================================================\n")
cat("Infection draws:",N_DRAW,"\n")
cat("Exposure years:",FIRST_EXPOSURE_YEAR,"to",LAST_EXPOSURE_YEAR,"\n")
cat("Minimum source/outcome group residents:",
    MIN_SOURCE_N,"/",MIN_OUTCOME_N,"\n")

# =============================================================================
# A. COMMON GROUP-YEAR MODEL FRAME
# =============================================================================

# Explicitly consecutive group-size change; do not bridge years in which a
# group label was absent.
group_size <- annual %>%
  count(year,resident_socg,name="source_group_n") %>%
  group_by(resident_socg) %>%
  arrange(year,.by_group=TRUE) %>%
  mutate(
    previous_year=lag(year),
    previous_group_n=lag(source_group_n),
    consecutive_previous=year-previous_year==1L,
    log_group_change=if_else(
      consecutive_previous,
      log((source_group_n+0.5)/(previous_group_n+0.5)),
      NA_real_
    ),
    log_group_size=log(source_group_n)
  ) %>%
  ungroup()

outcome_group_size <- annual %>%
  count(outcome_year=year,resident_socg,name="outcome_group_n")

pressure <- as_tibble(p6$groupyear) %>%
  mutate(
    year=as.integer(year),
    resident_socg=clean_sg(resident_socg),
    outcome_year=year+1L
  ) %>%
  left_join(
    group_size %>%
      select(year,resident_socg,source_group_n,
             previous_group_n,consecutive_previous,
             log_group_change,log_group_size),
    by=c("year","resident_socg")
  ) %>%
  left_join(
    outcome_group_size,
    by=c("outcome_year","resident_socg")
  ) %>%
  filter(
    year>=FIRST_EXPOSURE_YEAR,
    year<=LAST_EXPOSURE_YEAR,
    source_group_n>=MIN_SOURCE_N,
    outcome_group_n>=MIN_OUTCOME_N,
    consecutive_previous,
    is.finite(log_group_change),
    is.finite(log_group_size)
  ) %>%
  arrange(year,resident_socg) %>%
  mutate(model_row=row_number())

if(!nrow(pressure)) stop("No eligible group-year rows.")

# Match source group-year infection prevalence draws.
src_inf <- as_tibble(p6$infection_groupyear_draws) %>%
  mutate(
    year=as.integer(year),
    resident_socg=clean_sg(resident_socg)
  )

src_key <- paste(src_inf$year,src_inf$resident_socg,sep="|")
if(anyDuplicated(src_key)) stop("Duplicate source infection group-year keys.")

p_key <- paste(pressure$year,pressure$resident_socg,sep="|")
src_match <- match(p_key,src_key)
if(anyNA(src_match))
  stop("Some eligible pressure rows lack source infection draws.")

# Match outcome-year annual residents to infection rows.
annual_inf <- annual %>%
  mutate(inf_row=match(tattoo,INF_IDS)) %>%
  filter(!is.na(inf_row))

outcome_members <- split(
  annual_inf,
  paste(annual_inf$year,annual_inf$resident_socg,sep="|")
)

# Fixed scaling constants based on posterior means / observed controls.
within_ref <- vapply(
  src_inf$prevalence_draw[src_match],
  mean,
  numeric(1)
)
external_ref <- vapply(
  pressure$external_prev5_draw,
  mean,
  numeric(1)
)

scale_info <- tibble(
  variable=c("within_prevalence","external_pressure",
             "log_group_size","log_group_change"),
  center=c(
    mean(within_ref),
    mean(external_ref),
    mean(pressure$log_group_size),
    mean(pressure$log_group_change)
  ),
  scale=c(
    sd(within_ref),
    sd(external_ref),
    sd(pressure$log_group_size),
    sd(pressure$log_group_change)
  )
)

if(any(!is.finite(scale_info$scale) | scale_info$scale<=0))
  stop("Invalid predictor scaling.")

sc <- setNames(scale_info$scale,scale_info$variable)
ct <- setNames(scale_info$center,scale_info$variable)

pressure <- pressure %>%
  mutate(
    log_group_size_z=(log_group_size-ct[["log_group_size"]])/
      sc[["log_group_size"]],
    log_group_change_z=(log_group_change-ct[["log_group_change"]])/
      sc[["log_group_change"]]
  )

# =============================================================================
# B. HELPERS
# =============================================================================

q4_time <- function(y) 4L*(as.integer(y)-START_YEAR)+4L

make_draw_data <- function(draw_col){
  within <- vapply(
    src_inf$prevalence_draw[src_match],
    function(x) as.numeric(x[draw_col]),
    numeric(1)
  )
  external <- vapply(
    pressure$external_prev5_draw,
    function(x) as.numeric(x[draw_col]),
    numeric(1)
  )

  out <- vector("list",nrow(pressure))
  oo <- 0L

  for(i in seq_len(nrow(pressure))){
    key <- paste(pressure$outcome_year[i],
                 pressure$resident_socg[i],sep="|")
    mm <- outcome_members[[key]]
    if(is.null(mm) || !nrow(mm)) next

    it <- as.integer(inf$infection_time[mm$inf_row,draw_col])
    end_t <- q4_time(pressure$year[i])
    end_out <- q4_time(pressure$outcome_year[i])

    susceptible <- (it==0L | it>end_t)
    n_sus <- sum(susceptible)
    if(n_sus<1L) next

    incident <- sum(it> end_t & it<=end_out)

    oo <- oo+1L
    out[[oo]] <- tibble(
      model_row=pressure$model_row[i],
      year=pressure$year[i],
      outcome_year=pressure$outcome_year[i],
      resident_socg=pressure$resident_socg[i],
      source_group_n=pressure$source_group_n[i],
      outcome_group_n=pressure$outcome_group_n[i],
      susceptible=n_sus,
      incident=incident,
      nonincident=n_sus-incident,
      within_z=(within[i]-ct[["within_prevalence"]])/
        sc[["within_prevalence"]],
      external_z=(external[i]-ct[["external_pressure"]])/
        sc[["external_pressure"]],
      log_group_size_z=pressure$log_group_size_z[i],
      log_group_change_z=pressure$log_group_change_z[i],
      within_raw=within[i],
      external_raw=external[i]
    )
  }

  if(!oo) return(tibble())
  bind_rows(out[seq_len(oo)]) %>%
    mutate(
      resident_socg=factor(resident_socg),
      outcome_year_factor=factor(outcome_year)
    )
}

rmvn_psd <- function(n,mu,Sigma){
  Sigma <- as.matrix((Sigma+t(Sigma))/2)
  ee <- eigen(Sigma,symmetric=TRUE)
  ee$values[ee$values<1e-10] <- 1e-10
  A <- ee$vectors %*% diag(sqrt(ee$values),nrow=length(ee$values))
  z <- matrix(rnorm(n*length(mu)),nrow=n)
  ans <- sweep(z %*% t(A),2,as.numeric(mu),"+")
  colnames(ans) <- names(mu)
  ans
}

fit_one <- function(d,include_external=FALSE){
  rhs <- if(include_external){
    "within_z + external_z + log_group_size_z + log_group_change_z"
  } else {
    "within_z + log_group_size_z + log_group_change_z"
  }

  form <- as.formula(
    paste0(
      "cbind(incident,nonincident) ~ ",rhs,
      " + (1|resident_socg) + (1|outcome_year_factor)"
    )
  )

  fit <- try(
    lme4::glmer(
      form,
      data=d,
      family=binomial(),
      nAGQ=0,
      control=lme4::glmerControl(
        optimizer="bobyqa",
        optCtrl=list(maxfun=2e5),
        check.conv.singular="ignore"
      )
    ),
    silent=TRUE
  )

  if(inherits(fit,"try-error"))
    return(list(ok=FALSE,reason="fit_error"))

  cf <- lme4::fixef(fit)
  vv <- try(as.matrix(vcov(fit)),silent=TRUE)
  if(inherits(vv,"try-error") ||
     any(!is.finite(cf)) || any(!is.finite(vv)))
    return(list(ok=FALSE,reason="nonfinite"))

  dr <- rmvn_psd(N_KEEP,cf,vv)

  list(
    ok=TRUE,
    fit=fit,
    draws=as_tibble(dr),
    AIC=AIC(fit),
    n=nrow(d),
    incidents=sum(d$incident),
    susceptible=sum(d$susceptible),
    groups=n_distinct(d$resident_socg),
    years=n_distinct(d$outcome_year)
  )
}

# =============================================================================
# C. FIT ALL COHERENT INFECTION DRAWS
# =============================================================================

coef_draws <- vector("list",N_DRAW*2L)
diagnostics <- vector("list",N_DRAW)
kk <- 0L

for(dd in seq_len(N_DRAW)){
  dat <- make_draw_data(dd)

  local <- fit_one(dat,FALSE)
  full <- fit_one(dat,TRUE)

  diagnostics[[dd]] <- tibble(
    infection_draw=dd,
    n_rows=nrow(dat),
    incident=sum(dat$incident),
    susceptible=sum(dat$susceptible),
    groups=n_distinct(dat$resident_socg),
    years=n_distinct(dat$outcome_year),
    local_ok=local$ok,
    full_ok=full$ok,
    AIC_local=if(local$ok) local$AIC else NA_real_,
    AIC_local_external=if(full$ok) full$AIC else NA_real_,
    delta_AIC_external=if(local$ok && full$ok)
      full$AIC-local$AIC else NA_real_
  )

  if(local$ok){
    kk <- kk+1L
    z <- local$draws
    z$infection_draw <- dd
    z$model <- "LOCAL"
    coef_draws[[kk]] <- z
  }

  if(full$ok){
    kk <- kk+1L
    z <- full$draws
    z$infection_draw <- dd
    z$model <- "LOCAL_EXTERNAL"
    coef_draws[[kk]] <- z
  }

  if(dd%%25L==0L)
    cat("Processed infection draw",dd,"/",N_DRAW,"\n")
}

diagnostics <- bind_rows(diagnostics)
coef_draws <- bind_rows(coef_draws[seq_len(kk)])

if(!nrow(coef_draws))
  stop("No successful coefficient draws.")

# =============================================================================
# D. SUMMARISE
# =============================================================================

parameter_labels <- c(
  "(Intercept)"="intercept",
  "within_z"="within_infection_pressure_per_SD",
  "external_z"="external_infected_connectivity_per_SD",
  "log_group_size_z"="log_group_size_per_SD",
  "log_group_change_z"="group_size_change_per_SD"
)

long_draws <- coef_draws %>%
  pivot_longer(
    cols=any_of(names(parameter_labels)),
    names_to="term",
    values_to="beta"
  ) %>%
  mutate(parameter=unname(parameter_labels[term]))

summary <- long_draws %>%
  filter(is.finite(beta)) %>%
  group_by(model,parameter) %>%
  summarise(
    n_draws=n(),
    median=median(beta),
    q025=quantile(beta,.025),
    q975=quantile(beta,.975),
    P_gt_0=mean(beta>0),
    OR_median=median(exp(beta)),
    OR_q025=quantile(exp(beta),.025),
    OR_q975=quantile(exp(beta),.975),
    .groups="drop"
  )

aic_summary <- diagnostics %>%
  summarise(
    infection_draws=n(),
    local_success=sum(local_ok),
    full_success=sum(full_ok),
    paired_success=sum(local_ok & full_ok),
    median_rows=median(n_rows),
    median_incident=median(incident),
    median_susceptible=median(susceptible),
    median_groups=median(groups),
    median_years=median(years),
    median_delta_AIC_external=
      median(delta_AIC_external,na.rm=TRUE),
    q025_delta_AIC_external=
      quantile(delta_AIC_external,.025,na.rm=TRUE),
    q975_delta_AIC_external=
      quantile(delta_AIC_external,.975,na.rm=TRUE),
    P_delta_AIC_lt_0=
      mean(delta_AIC_external<0,na.rm=TRUE),
    P_delta_AIC_lt_minus2=
      mean(delta_AIC_external< -2,na.rm=TRUE)
  )

# Also show posterior-mean exposure correlation in the actual model frame.
exposure_audit <- tibble(
  n_groupyears=nrow(pressure),
  years=n_distinct(pressure$year),
  groups=n_distinct(pressure$resident_socg),
  within_external_spearman=cor(
    within_ref,external_ref,
    method="spearman",use="complete.obs"
  ),
  within_SD=sc[["within_prevalence"]],
  external_SD=sc[["external_pressure"]],
  log_group_size_SD=sc[["log_group_size"]],
  log_group_change_SD=sc[["log_group_change"]]
)

cat("\nMODEL SUPPORT\n")
print(aic_summary,n=Inf,width=Inf)

cat("\nEXPOSURE / SCALE AUDIT\n")
print(exposure_audit,n=Inf,width=Inf)

cat("\nCOEFFICIENT SUMMARY\n")
print(summary,n=Inf,width=Inf)

cat("\nINTERPRETATION TARGET\n")
cat("- Within pressure > 0: local amplification/persistence signal.\n")
cat("- External pressure > 0 in LOCAL_EXTERNAL: importation/connectivity signal beyond local infection.\n")
cat("- Negative delta AIC favours adding external infected connectivity.\n")
cat("- Random year effects mean this is not a crude post-2018 comparison.\n")

write_csv(
  summary,
  "results/Phase3/P3_07_local_vs_external_summary.csv"
)
write_csv(
  diagnostics,
  "results/Phase3/P3_07_local_vs_external_diagnostics.csv"
)
write_csv(
  aic_summary,
  "results/Phase3/P3_07_local_vs_external_model_support.csv"
)
write_csv(
  scale_info,
  "results/Phase3/P3_07_local_vs_external_scale_info.csv"
)
write_csv(
  exposure_audit,
  "results/Phase3/P3_07_local_vs_external_exposure_audit.csv"
)

saveRDS(
  list(
    summary=summary,
    diagnostics=diagnostics,
    coefficient_draws=coef_draws,
    model_frame=pressure %>% select(-ends_with("_draw")),
    scale_info=scale_info,
    exposure_audit=exposure_audit,
    settings=list(
      first_exposure_year=FIRST_EXPOSURE_YEAR,
      last_exposure_year=LAST_EXPOSURE_YEAR,
      min_source_n=MIN_SOURCE_N,
      min_outcome_n=MIN_OUTCOME_N,
      n_infection_draws=N_DRAW,
      n_coefficient_draws_per_fit=N_KEEP,
      external_definition="trailing-5-year directed movement connectivity weighted by source-group latent infection prevalence",
      within_definition="recipient-group latent infection prevalence at Q4(t)",
      outcome="latent infection acquisitions among residents susceptible at Q4(t), during t+1",
      controls="current log group size + consecutive-year log group-size change",
      random_effects="recipient social group + outcome year",
      time_note="2018 is not fitted as a breakpoint"
    )
  ),
  "data/phase3/P3_local_vs_external_infected_connectivity_fit.rds"
)

cat("\n============================================================\n")
cat("P3_07 COMPLETE\n")
cat("============================================================\n")
