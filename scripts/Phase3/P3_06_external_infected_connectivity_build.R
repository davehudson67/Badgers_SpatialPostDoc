# =============================================================================
# PHASE 3 / P3_06 — EXTERNAL INFECTED CONNECTIVITY BUILD + AUDIT
#
# Scientific question
#   Is future infection in recipient group g associated with infection in OTHER
#   groups that are connected to g by observed inter-group movement?
#
# Core quantity for each group-year:
#
#   ExternalPressure[g,t] = sum_{h != g} I[h,t] * C[h->g,t]
#
# where
#   I[h,t] = posterior infection prevalence in source group h by Q4(t)
#   C[h->g,t] = empirical directed capture-transition connectivity from h to g.
#
# Primary connectivity:
#   trailing 5-year movement network ending in year t. This uses only movement
#   observations available by the end of t and therefore can predict t+1
#   without future movement information.
#
# Sensitivity:
#   all-years structural movement network.
#
# The denominator for C is ALL scorable capture-to-capture transitions from
# source h in the window, including same-group transitions. Thus off-diagonal
# C values capture both the propensity to leave h and where movements go.
#
# Build/audit only — no disease-effect model is fitted here.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

MEM <- "data/phase3/P3_annual_recorded_membership.rds"
INF <- "data/badger_infection_trajectories_all_tests_inferred.rds"
ENC <- "data/badger_encounters_useful.rds"
PANEL <- "data/phase3/P3_groupyear_temporal_panel.rds"

for(f in c(MEM,INF,ENC,PANEL))
  if(!file.exists(f)) stop("Missing required file: ",f)

dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)
dir.create("data/phase3",recursive=TRUE,showWarnings=FALSE)

mem <- readRDS(MEM)
inf <- readRDS(INF)
enc <- as_tibble(readRDS(ENC))
panel <- readRDS(PANEL)

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

INF_IDS <- trimws(as.character(inf$tattoo))
START_YEAR <- as.integer(inf$start_year)
N_DRAW <- ncol(inf$infection_time)

if(!is.matrix(inf$infection_time))
  stop("inf$infection_time must be a matrix.")
if(nrow(inf$infection_time)!=length(INF_IDS))
  stop("Infection matrix row count mismatch.")
if(anyDuplicated(INF_IDS))
  stop("Duplicate infection tattoos.")

# =============================================================================
# A. DIRECTED CAPTURE-TRANSITION NETWORK
# =============================================================================

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
    source_socg=lag(socg),
    source_date=lag(capture_date),
    source_year=lag(year),
    gap_days=as.integer(capture_date-source_date)
  ) %>%
  ungroup() %>%
  filter(!is.na(source_socg),!is.na(source_date)) %>%
  transmute(
    tattoo,
    source_socg,
    dest_socg=socg,
    event_date=capture_date,
    event_year=year,
    source_date,
    source_year,
    gap_days,
    moved=source_socg!=dest_socg
  )

cat("\n============================================================\n")
cat("P3_06 — EXTERNAL INFECTED CONNECTIVITY BUILD + AUDIT\n")
cat("============================================================\n")
cat("Scorable capture transitions:",nrow(live),"\n")
cat("Inter-group transitions:",sum(live$moved),"\n")
cat("Overall transition movement proportion:",
    round(mean(live$moved),4),"\n")
cat("Distinct directed inter-group edges:",
    nrow(live %>% filter(moved) %>% distinct(source_socg,dest_socg)),"\n")

groups <- sort(unique(c(
  annual$resident_socg,
  live$source_socg,
  live$dest_socg
)))
G <- length(groups)
gidx <- setNames(seq_along(groups),groups)

build_C <- function(transitions){
  C <- matrix(0,nrow=G,ncol=G,
              dimnames=list(source=groups,dest=groups))
  if(!nrow(transitions)) return(C)

  den <- transitions %>%
    count(source_socg,name="n_source")
  ed <- transitions %>%
    count(source_socg,dest_socg,name="n_edge") %>%
    left_join(den,by="source_socg") %>%
    mutate(prob=n_edge/n_source)

  for(i in seq_len(nrow(ed))){
    s <- ed$source_socg[i]
    d <- ed$dest_socg[i]
    if(s %in% groups && d %in% groups)
      C[gidx[[s]],gidx[[d]]] <- ed$prob[i]
  }

  diag(C) <- 0
  C
}

C_static <- build_C(live)

# Trailing five-year network: events observed in years t-4,...,t.
years <- sort(unique(annual$year))
C5 <- setNames(vector("list",length(years)),as.character(years))
network_support <- vector("list",length(years))

for(ii in seq_along(years)){
  y <- years[ii]
  tr <- live %>% filter(event_year>=y-4L,event_year<=y)
  C5[[as.character(y)]] <- build_C(tr)

  network_support[[ii]] <- tibble(
    year=y,
    window_start=y-4L,
    scorable_transitions=nrow(tr),
    intergroup_transitions=sum(tr$moved),
    movement_proportion=if(nrow(tr)>0) mean(tr$moved) else NA_real_,
    active_source_groups=n_distinct(tr$source_socg),
    directed_intergroup_edges=nrow(
      tr %>% filter(moved) %>% distinct(source_socg,dest_socg)
    )
  )
}
network_support <- bind_rows(network_support)

# =============================================================================
# B. POSTERIOR SOURCE-GROUP INFECTION STATE BY Q4 OF EACH YEAR
# =============================================================================

annual_inf <- annual %>%
  mutate(inf_row=match(tattoo,INF_IDS)) %>%
  filter(!is.na(inf_row))

gy_keys <- annual_inf %>%
  distinct(year,resident_socg) %>%
  arrange(year,resident_socg)

infection_draws <- vector("list",nrow(gy_keys))

for(k in seq_len(nrow(gy_keys))){
  y <- gy_keys$year[k]
  sg <- gy_keys$resident_socg[k]
  rows <- annual_inf %>%
    filter(year==y,resident_socg==sg) %>%
    pull(inf_row)

  q4 <- 4L*(y-START_YEAR)+4L
  IT <- inf$infection_time[rows,,drop=FALSE]
  infected <- IT>0L & IT<=q4

  infection_draws[[k]] <- tibble(
    year=y,
    resident_socg=sg,
    n_residents=length(rows),
    prevalence_draw=list(colMeans(infected)),
    infected_count_draw=list(colSums(infected))
  )
}
infection_draws <- bind_rows(infection_draws)

# =============================================================================
# C. EXTERNAL PRESSURE DRAWS
# =============================================================================

pressure_list <- vector("list",length(years))

for(ii in seq_along(years)){
  y <- years[ii]
  gy <- infection_draws %>% filter(year==y)
  if(!nrow(gy)) next

  P <- matrix(0,nrow=G,ncol=N_DRAW,
              dimnames=list(groups,NULL))
  N <- matrix(0,nrow=G,ncol=N_DRAW,
              dimnames=list(groups,NULL))
  active <- logical(G)

  for(j in seq_len(nrow(gy))){
    gg <- gy$resident_socg[j]
    if(!(gg %in% groups)) next
    rr <- gidx[[gg]]
    P[rr,] <- gy$prevalence_draw[[j]]
    N[rr,] <- gy$infected_count_draw[[j]]
    active[rr] <- TRUE
  }

  C_trailing <- C5[[as.character(y)]]

  # rows=recipient group, cols=posterior draw
  Eprev5 <- t(C_trailing) %*% P
  Ecount5 <- t(C_trailing) %*% N
  EprevStatic <- t(C_static) %*% P
  EcountStatic <- t(C_static) %*% N

  recipients <- gy$resident_socg
  out <- vector("list",length(recipients))

  for(j in seq_along(recipients)){
    gg <- recipients[j]
    rr <- gidx[[gg]]

    out[[j]] <- tibble(
      year=y,
      resident_socg=gg,
      n_residents=gy$n_residents[match(gg,gy$resident_socg)],
      within_prevalence_mean=mean(P[rr,]),
      external_prev5_mean=mean(Eprev5[rr,]),
      external_prev5_q025=quantile(Eprev5[rr,],.025),
      external_prev5_q975=quantile(Eprev5[rr,],.975),
      external_count5_mean=mean(Ecount5[rr,]),
      external_count5_q025=quantile(Ecount5[rr,],.025),
      external_count5_q975=quantile(Ecount5[rr,],.975),
      external_prev_static_mean=mean(EprevStatic[rr,]),
      external_count_static_mean=mean(EcountStatic[rr,]),
      external_prev5_draw=list(as.numeric(Eprev5[rr,])),
      external_count5_draw=list(as.numeric(Ecount5[rr,]))
    )
  }

  pressure_list[[ii]] <- bind_rows(out)
}
pressure <- bind_rows(pressure_list)

# Attach outcome/context fields from the Phase-3 common panel.
panel_gy <- as_tibble(panel$groupyear) %>%
  mutate(resident_socg=clean_sg(resident_socg))

pressure_panel <- pressure %>%
  left_join(
    panel_gy,
    by=c("year","resident_socg")
  ) %>%
  arrange(year,resident_socg)

# Build future-year recipient outcomes for later model fitting.
future <- pressure_panel %>%
  select(
    year,
    resident_socg,
    external_prev5_mean,
    external_count5_mean,
    external_prev_static_mean,
    external_count_static_mean,
    within_prevalence_mean,
    external_prev5_draw,
    external_count5_draw
  ) %>%
  mutate(outcome_year=year+1L) %>%
  left_join(
    panel_gy %>%
      select(
        outcome_year=year,
        resident_socg,
        outcome_expected_susceptible=expected_susceptible_start,
        outcome_expected_incident=expected_incident_infections,
        outcome_latent_incidence=latent_incidence,
        outcome_culture_incident_excretors=culture_incident_excretors,
        outcome_culture_susceptible_start=culture_susceptible_start
      ),
    by=c("outcome_year","resident_socg")
  )

# =============================================================================
# D. AUDIT / DESCRIPTIVE SUPPORT
# =============================================================================

support_summary <- pressure_panel %>%
  summarise(
    groupyears=n(),
    years=n_distinct(year),
    groups=n_distinct(resident_socg),
    finite_external_prev5=sum(is.finite(external_prev5_mean)),
    finite_external_count5=sum(is.finite(external_count5_mean)),
    median_external_prev5=median(external_prev5_mean,na.rm=TRUE),
    q95_external_prev5=quantile(external_prev5_mean,.95,na.rm=TRUE),
    median_external_count5=median(external_count5_mean,na.rm=TRUE),
    q95_external_count5=quantile(external_count5_mean,.95,na.rm=TRUE)
  )

annual_pressure <- pressure_panel %>%
  group_by(year) %>%
  summarise(
    recipient_groups=n(),
    mean_within_prevalence=weighted.mean(
      within_prevalence_mean,
      w=pmax(n_residents,1),
      na.rm=TRUE
    ),
    mean_external_prev5=mean(external_prev5_mean,na.rm=TRUE),
    mean_external_count5=mean(external_count5_mean,na.rm=TRUE),
    mean_external_prev_static=mean(external_prev_static_mean,na.rm=TRUE),
    .groups="drop"
  )

cat("\nCONNECTIVITY SUPPORT — 2014 ONWARD\n")
print(
  network_support %>% filter(year>=2014L),
  n=Inf,width=Inf
)

cat("\nEXTERNAL PRESSURE SUPPORT\n")
print(support_summary,n=Inf,width=Inf)

cat("\nANNUAL EXTERNAL PRESSURE — 2014 ONWARD\n")
print(
  annual_pressure %>% filter(year>=2014L),
  n=Inf,width=Inf
)

cat("\nCORRELATIONS\n")
cat("Within prevalence vs trailing external prevalence pressure: ",
    round(cor(
      pressure_panel$within_prevalence_mean,
      pressure_panel$external_prev5_mean,
      use="complete.obs",
      method="spearman"
    ),3),"\n",sep="")
cat("Trailing vs static external prevalence pressure: ",
    round(cor(
      pressure_panel$external_prev5_mean,
      pressure_panel$external_prev_static_mean,
      use="complete.obs",
      method="spearman"
    ),3),"\n",sep="")

# =============================================================================
# E. SAVE
# =============================================================================

write_csv(
  network_support,
  "results/Phase3/P3_06_connectivity_network_support.csv"
)
write_csv(
  pressure_panel %>% select(-ends_with("_draw")),
  "results/Phase3/P3_06_external_infected_connectivity_summary.csv"
)
write_csv(
  annual_pressure,
  "results/Phase3/P3_06_annual_external_pressure.csv"
)

saveRDS(
  list(
    groupyear=pressure_panel,
    future_outcome_panel=future,
    network_support=network_support,
    static_connectivity=C_static,
    trailing5_connectivity=C5,
    infection_groupyear_draws=infection_draws,
    definitions=list(
      external_prev5=
        "sum over other groups of source infection prevalence by Q4(t) times trailing-5-year directed capture-transition probability into recipient group",
      external_count5=
        "sum over other groups of posterior infected source count by Q4(t) times trailing-5-year directed capture-transition probability into recipient group",
      connectivity_denominator=
        "all scorable capture-to-capture transitions from each source group, including same-group transitions",
      timing=
        "movement network uses transitions observed by end of year t; pressure at t is intended to predict infection in t+1",
      static_network=
        "all-years structural-network sensitivity only"
    )
  ),
  "data/phase3/P3_external_infected_connectivity.rds"
)

cat("\nP3_06 COMPLETE\n")
