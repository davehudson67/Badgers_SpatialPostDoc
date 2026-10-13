# =============================================================================
# PHASE 3 / P3_04a — ROGERS 1998 LAGGED MOVEMENT -> CULTURE INCIDENCE
#
# First historical benchmark only.
#
# Question:
#   Can we reproduce the reported positive relationship between annual
#   capture-based inter-group movement in year t and culture-excretion incidence
#   in year t+1?
#
# Published Rogers benchmark:
#   - 1978-1995 movement series
#   - movement between social groups expressed as a proportion of captures
#   - higher movement in one year associated with higher TB incidence next year
#   - final time-series model: t = 3.09, df = 12, p < 0.01
#
# We fit:
#   1) ALL_RECORDED_GROUPS: closest match to the recovered overall 11.6%
#      movement rate.
#   2) EARLY_CORE_ANCHOR: sensitivity using the 21 named early-core anchors
#      recovered from the historical literature. This is not claimed to be the
#      exact original 22-core set.
#
# Models:
#   - ordinary linear regression, matching the exploratory analysis;
#   - regression with MA(1) residual structure via ARIMA, matching the published
#     final time-series idea as closely as practical from the reconstructed data.
#
# This is a benchmark, not the final Phase-3 disease model.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

BENCH <- "data/phase3/P3_literature_benchmark_panel.rds"
ANCH <- "data/phase3/P3_published_core_anchor_audit.rds"
ENC <- "data/badger_encounters_useful.rds"

for(f in c(BENCH,ANCH,ENC))
  if(!file.exists(f)) stop("Missing required file: ",f)

dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)

b <- readRDS(BENCH)
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

core_early <- anch$anchor %>%
  filter(in_core_1978_1993 %in% TRUE) %>%
  pull(socg) %>%
  as.character()

cat("\n============================================================\n")
cat("P3_04a — ROGERS LAGGED MOVEMENT -> CULTURE INCIDENCE\n")
cat("============================================================\n")

# Capture-to-next-capture social-group movement, matching Rogers.
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
  filter(
    year>=1978L,year<=1995L,
    socg %in% core_early,
    next_socg %in% core_early,
    !is.na(move_next)
  ) %>%
  group_by(year) %>%
  summarise(
    n_scorable=n(),
    n_moves=sum(move_next),
    movement_proportion=mean(move_next),
    .groups="drop"
  )

# Culture-only first-positive incidence from the historical benchmark object.
iy <- as_tibble(b$individual_year) %>%
  mutate(
    resident_socg=clean_sg(resident_socg),
    incident=as.integer(incident_excretor %in% TRUE),
    susceptible=as.integer(susceptible_start %in% TRUE)
  )

inc_all <- iy %>%
  group_by(year) %>%
  summarise(
    incidents=sum(incident,na.rm=TRUE),
    susceptible=sum(susceptible,na.rm=TRUE),
    culture_incidence=if_else(susceptible>0,incidents/susceptible,NA_real_),
    .groups="drop"
  )

inc_core <- iy %>%
  filter(resident_socg %in% core_early) %>%
  group_by(year) %>%
  summarise(
    incidents=sum(incident,na.rm=TRUE),
    susceptible=sum(susceptible,na.rm=TRUE),
    culture_incidence=if_else(susceptible>0,incidents/susceptible,NA_real_),
    .groups="drop"
  )

fit_series <- function(move,inc,label){
  d <- move %>%
    left_join(
      inc %>%
        transmute(
          year=year-1L,
          next_year_incidents=incidents,
          next_year_susceptible=susceptible,
          next_year_culture_incidence=culture_incidence
        ),
      by="year"
    ) %>%
    filter(
      is.finite(movement_proportion),
      is.finite(next_year_culture_incidence)
    ) %>%
    arrange(year) %>%
    mutate(
      movement_z=as.numeric(scale(movement_proportion))
    )

  if(nrow(d)<8L) stop(label,": too few annual pairs: ",nrow(d))

  lm_raw <- lm(next_year_culture_incidence~movement_proportion,data=d)
  lm_z <- lm(next_year_culture_incidence~movement_z,data=d)

  cor_p <- cor.test(
    d$movement_proportion,
    d$next_year_culture_incidence,
    method="pearson"
  )
  cor_s <- suppressWarnings(cor.test(
    d$movement_proportion,
    d$next_year_culture_incidence,
    method="spearman",
    exact=FALSE
  ))

  ma1 <- try(
    arima(
      d$next_year_culture_incidence,
      order=c(0,0,1),
      xreg=matrix(
        d$movement_proportion,
        ncol=1,
        dimnames=list(NULL,"movement_proportion")
      ),
      include.mean=TRUE,
      method="ML"
    ),
    silent=TRUE
  )

  sm <- coef(summary(lm_raw))
  lm_row <- tibble(
    series=label,
    model="OLS",
    n_year_pairs=nrow(d),
    estimate=sm["movement_proportion","Estimate"],
    std_error=sm["movement_proportion","Std. Error"],
    statistic=sm["movement_proportion","t value"],
    p_value=sm["movement_proportion","Pr(>|t|)"],
    residual_MA1=NA_real_
  )

  ma_row <- tibble(
    series=label,model="MA1",
    n_year_pairs=nrow(d),
    estimate=NA_real_,std_error=NA_real_,
    statistic=NA_real_,p_value=NA_real_,
    residual_MA1=NA_real_
  )

  if(!inherits(ma1,"try-error")){
    cf <- coef(ma1)
    se <- sqrt(diag(ma1$var.coef))
    if("movement_proportion" %in% names(cf)){
      z <- cf["movement_proportion"]/se["movement_proportion"]
      ma_row <- tibble(
        series=label,model="MA1",
        n_year_pairs=nrow(d),
        estimate=unname(cf["movement_proportion"]),
        std_error=unname(se["movement_proportion"]),
        statistic=unname(z),
        p_value=2*pnorm(abs(z),lower.tail=FALSE),
        residual_MA1=if("ma1" %in% names(cf)) unname(cf["ma1"]) else NA_real_
      )
    }
  }

  diagnostics <- tibble(
    series=label,
    n_year_pairs=nrow(d),
    first_movement_year=min(d$year),
    last_movement_year=max(d$year),
    overall_movement_proportion=sum(d$n_moves)/sum(d$n_scorable),
    pearson_r=unname(cor_p$estimate),
    pearson_p=cor_p$p.value,
    spearman_rho=unname(cor_s$estimate),
    spearman_p=cor_s$p.value,
    OLS_standardized_beta=coef(lm_z)[["movement_z"]]
  )

  list(
    data=d,
    coefficients=bind_rows(lm_row,ma_row),
    diagnostics=diagnostics,
    lm=lm_raw,
    ma1=ma1
  )
}

all_fit <- fit_series(move_all,inc_all,"ALL_RECORDED_GROUPS")
core_fit <- fit_series(move_core,inc_core,"EARLY_CORE_ANCHOR")

coef_tab <- bind_rows(all_fit$coefficients,core_fit$coefficients)
diag_tab <- bind_rows(all_fit$diagnostics,core_fit$diagnostics)

cat("\nMOVEMENT RATE RECOVERY\n")
print(
  diag_tab %>%
    select(series,n_year_pairs,overall_movement_proportion),
  n=Inf,width=Inf
)
cat("Published Rogers movement proportion: approximately 0.12.\n")

cat("\nLAGGED MOVEMENT -> NEXT-YEAR CULTURE INCIDENCE\n")
print(coef_tab,n=Inf,width=Inf)

cat("\nCORRELATION CHECK\n")
print(
  diag_tab %>%
    select(series,pearson_r,pearson_p,spearman_rho,spearman_p,
           OLS_standardized_beta),
  n=Inf,width=Inf
)

cat("\nPublished Rogers final time-series reference: positive association, t = 3.09, df = 12, p < 0.01.\n")
cat("Judge replication primarily by direction and evidence, not numerical equality.\n")

write_csv(
  all_fit$data,
  "results/Phase3/P3_04a_rogers_allarea_annual_series.csv"
)
write_csv(
  core_fit$data,
  "results/Phase3/P3_04a_rogers_coreanchor_annual_series.csv"
)
write_csv(
  coef_tab,
  "results/Phase3/P3_04a_rogers_lagged_coefficients.csv"
)
write_csv(
  diag_tab,
  "results/Phase3/P3_04a_rogers_lagged_diagnostics.csv"
)

saveRDS(
  list(
    all_recorded_groups=all_fit,
    early_core_anchor=core_fit,
    published_reference=list(
      movement_proportion=0.12,
      lagged_direction="positive",
      final_t=3.09,
      final_df=12,
      final_p="<0.01"
    ),
    interpretation_note=paste(
      "Historical benchmark only. The early-core anchor is 21 recovered named",
      "groups and is not claimed to be the exact original 22-core series."
    )
  ),
  "results/Phase3/P3_04a_rogers_lagged_movement_incidence.rds"
)

cat("\n============================================================\n")
cat("P3_04a COMPLETE\n")
cat("============================================================\n")
