# =============================================================================
# WOODCHESTER V7b SPATIAL INFECTION-PRESSURE BUILD + AUDIT
#
# Builds posterior infection-pressure covariates for every V7b movement interval
# and every one of the 500 sampled infection histories.
#
# TIME ORDERING
# -------------
# movement interval ends in year t
# pressure is evaluated at Q4(t)
# infection acquisition outcome is Q1-Q4(t+1)
#
# PRESSURE SOURCES
# ----------------
# Infection state:
#   sampled latent infection state of OTHER badgers at Q4(t)
#
# Location/group:
#   exact observed annual sett/social-group information in year t
#
# Focal spatial location:
#   first preference = Stage-1 observed annual x/y for focal badger in year t
#   fallback         = exact observed annual representative sett x/y in year t
#
# NO LOCF / nearest-year imputation is used here.
#
# PRESSURE METRICS
# ----------------
# 1. same social-group prevalence among other observed badgers
# 2. prevalence among other observed badgers within 500 m
# 3. prevalence among other observed badgers within 1000 m
# 4. prevalence among other observed badgers within 2000 m
# 5. exponential distance-weighted prevalence, scale = 500 m
# 6. exponential distance-weighted prevalence, scale = 1000 m
#
# Both raw prevalence and support/sample-size information are retained.
# Distance-weighted infected "intensity" is also retained for later sensitivity,
# but prevalence is preferred initially because observed source counts vary over
# the 50-year study.
#
# OUTPUT IS MATRIX-BASED:
# rows = V7b movement intervals
# cols = 500 infection-history draws
# This avoids materialising millions of repeated long-format rows.
# =============================================================================

library(tidyverse)

MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
INF_FILE  <- "data/badger_infection_trajectories_all_tests_inferred.rds"
AO_FILE   <- "data/badger_stage1_observed_annual_locations_1285.rds"
SETT_FILE <- "data/badger_annual_observed_sett_locations.rds"

for(f in c(MOVE_FILE,PAIR_FILE,INF_FILE,AO_FILE,SETT_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

mov <- readRDS(MOVE_FILE)
paired <- readRDS(PAIR_FILE)
inf <- readRDS(INF_FILE)
ao <- as_tibble(readRDS(AO_FILE))
annual <- as_tibble(readRDS(SETT_FILE))

dir.create("results",showWarnings=FALSE,recursive=TRUE)

START_YEAR <- as.integer(inf$start_year)
N_INF_DRAW <- ncol(inf$infection_time)
INF_IDS <- trimws(as.character(inf$tattoo))

if(N_INF_DRAW!=500L)
  warning("Expected 500 infection draws; found ",N_INF_DRAW)

# =============================================================================
# A. BUILD THE CANONICAL V7b INTERVAL TABLE
# =============================================================================

cat("\n============================================================\n")
cat("A. V7b INTERVAL TABLE\n")
cat("============================================================\n")

idx <- as_tibble(mov$interval_index) %>%
  mutate(
    interval_col=row_number(),
    model_i=as.integer(model_i),
    tattoo=trimws(as.character(tattoo)),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year)
  ) %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last) %>%
  mutate(
    v7b_interval_id=row_number(),
    pressure_year=to_year,
    focal_inf_row=match(tattoo,INF_IDS)
  )

if(anyNA(idx$focal_inf_row))
  stop("Some focal Phase-2 badgers are missing from infection trajectories.")

cat("V7b candidate movement intervals:",nrow(idx),"\n")
cat("Badgers:",n_distinct(idx$tattoo),"\n")
cat("Pressure years:",
    min(idx$pressure_year),"-",max(idx$pressure_year),"\n")

# =============================================================================
# B. FOCAL OBSERVED LOCATION / SOCIAL GROUP
# =============================================================================

cat("\n============================================================\n")
cat("B. FOCAL OBSERVED LOCATION SUPPORT\n")
cat("============================================================\n")

ao2 <- ao %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    year=as.integer(year),
    stage1_x=as.numeric(x),
    stage1_y=as.numeric(y),
    has_stage1_xy=is.finite(stage1_x)&is.finite(stage1_y)
  )

annual2 <- annual %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    year=as.integer(year),
    annual_sett=as.character(annual_sett),
    annual_x=as.numeric(annual_x),
    annual_y=as.numeric(annual_y),
    has_sett_xy=is.finite(annual_x)&is.finite(annual_y),
    annual_socg=as.character(annual_socg),
    has_socg=!is.na(annual_socg)&annual_socg!=""
  )

idx <- idx %>%
  left_join(
    ao2,
    by=c("tattoo","pressure_year"="year")
  ) %>%
  left_join(
    annual2,
    by=c("tattoo","pressure_year"="year")
  ) %>%
  mutate(
    focal_x=case_when(
      has_stage1_xy %in% TRUE ~ stage1_x,
      has_sett_xy %in% TRUE ~ annual_x,
      TRUE ~ NA_real_
    ),
    focal_y=case_when(
      has_stage1_xy %in% TRUE ~ stage1_y,
      has_sett_xy %in% TRUE ~ annual_y,
      TRUE ~ NA_real_
    ),
    focal_xy_source=case_when(
      has_stage1_xy %in% TRUE ~ "stage1_annual_obs",
      has_sett_xy %in% TRUE ~ "annual_observed_sett",
      TRUE ~ "missing"
    ),
    has_focal_xy=is.finite(focal_x)&is.finite(focal_y)
  )

cat("Intervals with Stage-1 annual observed XY:",
    sum(idx$has_stage1_xy %in% TRUE),"/",nrow(idx),
    sprintf("(%.1f%%)",100*mean(idx$has_stage1_xy %in% TRUE)),"\n")

cat("Intervals with combined exact observed XY:",
    sum(idx$has_focal_xy),"/",nrow(idx),
    sprintf("(%.1f%%)",100*mean(idx$has_focal_xy)),"\n")

cat("Intervals with exact annual social group:",
    sum(idx$has_socg %in% TRUE),"/",nrow(idx),
    sprintf("(%.1f%%)",100*mean(idx$has_socg %in% TRUE)),"\n")

cat("\nFocal XY source:\n")
print(count(idx,focal_xy_source),n=Inf,width=Inf)

# =============================================================================
# C. SOURCE TABLES
# =============================================================================

cat("\n============================================================\n")
cat("C. INFECTION-PRESSURE SOURCE TABLES\n")
cat("============================================================\n")

src_all <- annual2 %>%
  mutate(inf_row=match(tattoo,INF_IDS)) %>%
  filter(!is.na(inf_row))

src_sg <- src_all %>%
  filter(has_socg) %>%
  distinct(tattoo,year,.keep_all=TRUE)

src_xy <- src_all %>%
  filter(has_sett_xy) %>%
  distinct(tattoo,year,.keep_all=TRUE)

cat("Annual source rows with social group:",nrow(src_sg),"\n")
cat("Annual source rows with XY:",nrow(src_xy),"\n")
cat("Source badgers with SG:",n_distinct(src_sg$tattoo),"\n")
cat("Source badgers with XY:",n_distinct(src_xy$tattoo),"\n")

source_year_audit <- full_join(
  src_sg %>% count(year,name="n_sg_sources"),
  src_xy %>% count(year,name="n_xy_sources"),
  by="year"
) %>%
  arrange(year) %>%
  mutate(
    n_sg_sources=replace_na(n_sg_sources,0L),
    n_xy_sources=replace_na(n_xy_sources,0L)
  )

cat("\nSource support by year summary:\n")
print(
  source_year_audit %>%
    summarise(
      years=n(),
      median_sg=median(n_sg_sources),
      q025_sg=quantile(n_sg_sources,.025),
      median_xy=median(n_xy_sources),
      q025_xy=quantile(n_xy_sources,.025)
    ),
  width=Inf
)

# =============================================================================
# D. INITIALISE PRESSURE MATRICES
# =============================================================================

cat("\n============================================================\n")
cat("D. BUILD PRESSURE MATRICES ACROSS 500 INFECTION HISTORIES\n")
cat("============================================================\n")

NR <- nrow(idx)
NC <- N_INF_DRAW

NA_MAT <- function()
  matrix(NA_real_,NR,NC)

samegroup_prev <- NA_MAT()
samegroup_prev_smooth <- NA_MAT()

r500_prev <- NA_MAT()
r1000_prev <- NA_MAT()
r2000_prev <- NA_MAT()

exp500_prev <- NA_MAT()
exp1000_prev <- NA_MAT()

# Optional "infected intensity" metrics. These are source-count dependent.
exp500_infected_intensity <- NA_MAT()
exp1000_infected_intensity <- NA_MAT()

# Support denominators do not depend on infection draw.
samegroup_n <- rep(NA_integer_,NR)
r500_n <- rep(NA_integer_,NR)
r1000_n <- rep(NA_integer_,NR)
r2000_n <- rep(NA_integer_,NR)
exp500_weight_sum <- rep(NA_real_,NR)
exp1000_weight_sum <- rep(NA_real_,NR)

# Number of spatial source animals with any positive kernel weight is all
# non-self sources in the year; retained as a support metric.
xy_source_n <- rep(NA_integer_,NR)

# =============================================================================
# E. YEAR-BY-YEAR MATRIX CALCULATION
# =============================================================================

pressure_years <- sort(unique(idx$pressure_year))

for(yy in pressure_years){
  fr <- which(idx$pressure_year==yy)
  cutoff <- 4L*(yy-START_YEAR)+4L

  # ---------------------------------------------------------------------------
  # SAME SOCIAL GROUP
  # ---------------------------------------------------------------------------
  fs <- fr[idx$has_socg[fr] %in% TRUE]
  sy <- src_sg %>% filter(year==yy)

  if(length(fs) && nrow(sy)){
    # G[r,s] = source s is in same annual social group as focal interval r.
    G <- outer(
      idx$annual_socg[fs],
      sy$annual_socg,
      FUN=function(a,b) a==b
    ) * 1

    # Exclude the focal badger itself.
    self <- outer(
      idx$tattoo[fs],
      sy$tattoo,
      FUN=function(a,b) a==b
    )
    G[self] <- 0

    den <- rowSums(G)
    samegroup_n[fs] <- as.integer(den)

    # Source infection state at Q4(yy), source x infection draw.
    IT <- inf$infection_time[sy$inf_row,,drop=FALSE]
    I <- (IT>0L & IT<=cutoff) * 1

    infected_n <- G %*% I

    ok <- den>0
    if(any(ok)){
      samegroup_prev[fs[ok],] <-
        infected_n[ok,,drop=FALSE] / den[ok]

      # Jeffreys-style smoothing retained as an explicit alternative.
      samegroup_prev_smooth[fs[ok],] <-
        (infected_n[ok,,drop=FALSE]+0.5) / (den[ok]+1)
    }
  }

  # ---------------------------------------------------------------------------
  # DISTANCE-BASED PRESSURE
  # ---------------------------------------------------------------------------
  fx <- fr[idx$has_focal_xy[fr]]
  xy <- src_xy %>% filter(year==yy)

  if(length(fx) && nrow(xy)){
    dx <- outer(idx$focal_x[fx],xy$annual_x,"-")
    dy <- outer(idx$focal_y[fx],xy$annual_y,"-")
    D <- sqrt(dx^2+dy^2)

    self <- outer(
      idx$tattoo[fx],
      xy$tattoo,
      FUN=function(a,b) a==b
    )

    # Explicit fixed-radius neighbourhoods.
    W500 <- (D<=500)*1
    W1000 <- (D<=1000)*1
    W2000 <- (D<=2000)*1

    W500[self] <- 0
    W1000[self] <- 0
    W2000[self] <- 0

    d500 <- rowSums(W500)
    d1000 <- rowSums(W1000)
    d2000 <- rowSums(W2000)

    r500_n[fx] <- as.integer(d500)
    r1000_n[fx] <- as.integer(d1000)
    r2000_n[fx] <- as.integer(d2000)

    # Exponential kernels.
    E500 <- exp(-D/500)
    E1000 <- exp(-D/1000)
    E500[self] <- 0
    E1000[self] <- 0

    de500 <- rowSums(E500)
    de1000 <- rowSums(E1000)

    exp500_weight_sum[fx] <- de500
    exp1000_weight_sum[fx] <- de1000
    xy_source_n[fx] <- nrow(xy)-as.integer(idx$tattoo[fx]%in%xy$tattoo)

    IT <- inf$infection_time[xy$inf_row,,drop=FALSE]
    I <- (IT>0L & IT<=cutoff) * 1

    N500 <- W500 %*% I
    N1000 <- W1000 %*% I
    N2000 <- W2000 %*% I

    ok <- d500>0
    if(any(ok))
      r500_prev[fx[ok],] <- N500[ok,,drop=FALSE]/d500[ok]

    ok <- d1000>0
    if(any(ok))
      r1000_prev[fx[ok],] <- N1000[ok,,drop=FALSE]/d1000[ok]

    ok <- d2000>0
    if(any(ok))
      r2000_prev[fx[ok],] <- N2000[ok,,drop=FALSE]/d2000[ok]

    K500 <- E500 %*% I
    K1000 <- E1000 %*% I

    ok <- de500>0
    if(any(ok)){
      exp500_prev[fx[ok],] <- K500[ok,,drop=FALSE]/de500[ok]
      exp500_infected_intensity[fx[ok],] <- K500[ok,,drop=FALSE]
    }

    ok <- de1000>0
    if(any(ok)){
      exp1000_prev[fx[ok],] <- K1000[ok,,drop=FALSE]/de1000[ok]
      exp1000_infected_intensity[fx[ok],] <- K1000[ok,,drop=FALSE]
    }
  }

  if(yy%%5L==0L || yy==max(pressure_years))
    cat("Built pressure through year",yy,"\n")
}

# =============================================================================
# F. STATIC SUPPORT AUDIT
# =============================================================================

cat("\n============================================================\n")
cat("F. STATIC PRESSURE SUPPORT AUDIT\n")
cat("============================================================\n")

support <- idx %>%
  transmute(
    v7b_interval_id,
    tattoo,
    pressure_year,
    focal_xy_source,
    has_focal_xy,
    annual_socg,
    has_socg,
    samegroup_n,
    r500_n,
    r1000_n,
    r2000_n,
    exp500_weight_sum,
    exp1000_weight_sum,
    xy_source_n
  )

support_summary <- tibble(
  metric=c(
    "samegroup",
    "radius_500m",
    "radius_1000m",
    "radius_2000m",
    "exp_500m",
    "exp_1000m"
  ),
  usable_intervals=c(
    sum(samegroup_n>0,na.rm=TRUE),
    sum(r500_n>0,na.rm=TRUE),
    sum(r1000_n>0,na.rm=TRUE),
    sum(r2000_n>0,na.rm=TRUE),
    sum(exp500_weight_sum>0,na.rm=TRUE),
    sum(exp1000_weight_sum>0,na.rm=TRUE)
  ),
  total_intervals=NR
) %>%
  mutate(
    usable_pct=100*usable_intervals/total_intervals
  )

print(support_summary,n=Inf,width=Inf)

cat("\nSource-count/support summaries:\n")
print(
  support %>%
    summarise(
      samegroup_n_median=median(samegroup_n[samegroup_n>0],na.rm=TRUE),
      samegroup_n_q025=quantile(samegroup_n[samegroup_n>0],.025,na.rm=TRUE),
      r500_n_median=median(r500_n[r500_n>0],na.rm=TRUE),
      r1000_n_median=median(r1000_n[r1000_n>0],na.rm=TRUE),
      r2000_n_median=median(r2000_n[r2000_n>0],na.rm=TRUE)
    ),
  width=Inf
)

# =============================================================================
# G. V7b RISK/EVENT RETENTION UNDER EACH PRESSURE METRIC
# =============================================================================

cat("\n============================================================\n")
cat("G. V7b RISK / EVENT RETENTION BY PRESSURE METRIC\n")
cat("============================================================\n")

if(is.null(paired$live_bounds) ||
   !all(c("tattoo","last_live_time")%in%names(paired$live_bounds)))
  stop("paired object lacks live_bounds.")

last_live <- setNames(
  as.integer(paired$live_bounds$last_live_time),
  trimws(as.character(paired$live_bounds$tattoo))
)

metric_available <- list(
  samegroup=!is.na(samegroup_n) & samegroup_n>0,
  radius_500m=!is.na(r500_n) & r500_n>0,
  radius_1000m=!is.na(r1000_n) & r1000_n>0,
  radius_2000m=!is.na(r2000_n) & r2000_n>0,
  exp_500m=!is.na(exp500_weight_sum) & exp500_weight_sum>0,
  exp_1000m=!is.na(exp1000_weight_sum) & exp1000_weight_sum>0
)

retention_rows <- vector("list",NC)

for(dd in seq_len(NC)){
  it_focal <- as.integer(
    inf$infection_time[idx$focal_inf_row,dd]
  )

  q4_t <- 4L*(idx$pressure_year-START_YEAR)+4L

  susceptible <- it_focal==0L | it_focal>q4_t

  start_q <- 4L*((idx$pressure_year+1L)-START_YEAR)+1L
  end_q <- start_q+3L
  llt <- as.integer(last_live[idx$tattoo])
  follow_end <- pmin(end_q,llt)

  # If there is no observed-live follow-up in t+1, no risk rows.
  has_follow <- susceptible & follow_end>=start_q

  risk_n <- integer(NR)
  event <- rep(FALSE,NR)

  rr <- which(has_follow)

  if(length(rr)){
    acq <- it_focal[rr]

    # Event occurs if acquisition lies inside observable t+1 risk window.
    ev <- acq>0L &
      acq>=start_q[rr] &
      acq<=follow_end[rr]

    event[rr] <- ev

    # Risk rows include quarters from Q1(t+1) through event or censoring.
    risk_stop <- follow_end[rr]
    risk_stop[ev] <- acq[ev]

    risk_n[rr] <- risk_stop-start_q[rr]+1L
  }

  base_risk <- sum(risk_n)
  base_events <- sum(event)

  retention_rows[[dd]] <- bind_rows(
    lapply(names(metric_available),function(mm){
      av <- metric_available[[mm]]

      tibble(
        infection_col=dd,
        metric=mm,
        base_risk_quarters=base_risk,
        retained_risk_quarters=sum(risk_n[av],na.rm=TRUE),
        base_events=base_events,
        retained_events=sum(event & av,na.rm=TRUE),
        susceptible_intervals=sum(has_follow),
        pressure_supported_intervals=sum(has_follow & av,na.rm=TRUE)
      )
    })
  )
}

retention <- bind_rows(retention_rows)

retention_summary <- retention %>%
  group_by(metric) %>%
  summarise(
    median_base_risk=median(base_risk_quarters),
    median_retained_risk=median(retained_risk_quarters),
    median_risk_pct=
      median(100*retained_risk_quarters/base_risk_quarters),
    q025_risk_pct=
      quantile(100*retained_risk_quarters/base_risk_quarters,.025),
    q975_risk_pct=
      quantile(100*retained_risk_quarters/base_risk_quarters,.975),
    median_base_events=median(base_events),
    median_retained_events=median(retained_events),
    median_event_pct=
      median(100*retained_events/base_events),
    q025_event_pct=
      quantile(100*retained_events/base_events,.025),
    q975_event_pct=
      quantile(100*retained_events/base_events,.975),
    .groups="drop"
  )

print(retention_summary,n=Inf,width=Inf)

# =============================================================================
# H. PRESSURE DISTRIBUTIONS
# =============================================================================

cat("\n============================================================\n")
cat("H. PRESSURE DISTRIBUTIONS ACROSS LATENT INFECTION HISTORIES\n")
cat("============================================================\n")

matrix_summary <- function(M,name){
  z <- as.numeric(M)
  z <- z[is.finite(z)]

  tibble(
    metric=name,
    finite_values=length(z),
    mean=mean(z),
    sd=sd(z),
    q025=unname(quantile(z,.025)),
    median=median(z),
    q975=unname(quantile(z,.975)),
    min=min(z),
    max=max(z)
  )
}

pressure_distribution <- bind_rows(
  matrix_summary(samegroup_prev,"samegroup_prev"),
  matrix_summary(samegroup_prev_smooth,"samegroup_prev_smooth"),
  matrix_summary(r500_prev,"radius500_prev"),
  matrix_summary(r1000_prev,"radius1000_prev"),
  matrix_summary(r2000_prev,"radius2000_prev"),
  matrix_summary(exp500_prev,"exp500_prev"),
  matrix_summary(exp1000_prev,"exp1000_prev")
)

print(pressure_distribution,n=Inf,width=Inf)

# =============================================================================
# I. CORRELATION AMONG PRESSURE DEFINITIONS
# =============================================================================

cat("\n============================================================\n")
cat("I. PRESSURE-METRIC CORRELATIONS\n")
cat("============================================================\n")

# Correlations using posterior means across infection draws for each interval.
mean_pressure <- tibble(
  v7b_interval_id=seq_len(NR),
  samegroup=rowMeans(samegroup_prev,na.rm=TRUE),
  r500=rowMeans(r500_prev,na.rm=TRUE),
  r1000=rowMeans(r1000_prev,na.rm=TRUE),
  r2000=rowMeans(r2000_prev,na.rm=TRUE),
  exp500=rowMeans(exp500_prev,na.rm=TRUE),
  exp1000=rowMeans(exp1000_prev,na.rm=TRUE)
)

# rowMeans(all NA) returns NaN; convert.
for(nm in names(mean_pressure)[-1])
  mean_pressure[[nm]][!is.finite(mean_pressure[[nm]])] <- NA_real_

cor_mat <- cor(
  mean_pressure %>% select(-v7b_interval_id),
  use="pairwise.complete.obs"
)

print(round(cor_mat,3))

# =============================================================================
# J. SAVE
# =============================================================================

cat("\n============================================================\n")
cat("J. SAVE\n")
cat("============================================================\n")

pressure_obj <- list(
  definition=list(
    pressure_time="Q4 of movement-ending year t",
    outcome_time="infection acquisition Q1-Q4 of t+1",
    infection_sources="other infection-model badgers with exact observed annual location/group in year t",
    focal_xy="Stage-1 exact observed annual x/y, falling back to exact observed annual sett x/y",
    source_xy="exact observed annual representative sett x/y",
    self_excluded=TRUE,
    no_location_imputation=TRUE
  ),
  interval_index=idx,
  support=support,
  source_year_audit=source_year_audit,
  matrices=list(
    samegroup_prev=samegroup_prev,
    samegroup_prev_smooth=samegroup_prev_smooth,
    radius500_prev=r500_prev,
    radius1000_prev=r1000_prev,
    radius2000_prev=r2000_prev,
    exp500_prev=exp500_prev,
    exp1000_prev=exp1000_prev,
    exp500_infected_intensity=exp500_infected_intensity,
    exp1000_infected_intensity=exp1000_infected_intensity
  ),
  support_vectors=list(
    samegroup_n=samegroup_n,
    radius500_n=r500_n,
    radius1000_n=r1000_n,
    radius2000_n=r2000_n,
    exp500_weight_sum=exp500_weight_sum,
    exp1000_weight_sum=exp1000_weight_sum,
    xy_source_n=xy_source_n
  ),
  retention_by_infection_draw=retention,
  retention_summary=retention_summary,
  pressure_distribution=pressure_distribution,
  posterior_mean_pressure=mean_pressure,
  pressure_correlation=cor_mat,
  infection_draws=NC
)

saveRDS(
  pressure_obj,
  "data/badger_V7b_spatial_infection_pressure_500draws.rds",
  compress="gzip"
)

write_csv(
  support_summary,
  "results/V7b_spatial_pressure_support_summary.csv"
)

write_csv(
  retention_summary,
  "results/V7b_spatial_pressure_risk_event_retention.csv"
)

write_csv(
  pressure_distribution,
  "results/V7b_spatial_pressure_distribution.csv"
)

write_csv(
  mean_pressure,
  "results/V7b_spatial_pressure_posterior_mean_by_interval.csv"
)

cat("Saved: data/badger_V7b_spatial_infection_pressure_500draws.rds\n")
cat("Saved: results/V7b_spatial_pressure_support_summary.csv\n")
cat("Saved: results/V7b_spatial_pressure_risk_event_retention.csv\n")
cat("Saved: results/V7b_spatial_pressure_distribution.csv\n")
cat("Saved: results/V7b_spatial_pressure_posterior_mean_by_interval.csv\n")

cat("\nNEXT DECISION:\n")
cat("Choose the primary pressure metric using BOTH biological interpretability\n")
cat("and event/risk retention. Recommended starting candidate is SAME-GROUP\n")
cat("prevalence because it is directly interpretable and does not assume an\n")
cat("arbitrary Euclidean transmission kernel. Distance-based pressure is then a\n")
cat("mechanistic spatial sensitivity.\n")

cat("\nSPATIAL PRESSURE BUILD COMPLETE\n")
