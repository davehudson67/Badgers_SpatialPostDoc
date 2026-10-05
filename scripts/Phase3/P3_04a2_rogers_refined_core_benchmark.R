# =============================================================================
# PHASE 3 / P3_04a2 — ROGERS LAGGED MOVEMENT, REFINED HISTORICAL CORE
#
# Refines P3_04a using a literature-supported dynamic core:
#   - 21 core groups before 1990
#   - Wychelm added from 1990 onward
#
# Also prevents current-archive captures after 1995 from contributing a
# "next capture" movement score to the original 1978-1995 Rogers window.
#
# Outcome remains culture-only first-positive incidence, consistent with the
# Rogers 1998 paper's stated diagnostic basis.
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

core21 <- anch$anchor %>%
  filter(in_core_1978_1993 %in% TRUE) %>%
  pull(socg) %>%
  as.character()

if("WYCHELM" %in% core21)
  stop("Unexpected: WYCHELM already present in the 21-group early anchor.")

core_for_year <- function(y)
  if(y >= 1990L) c(core21,"WYCHELM") else core21

is_core_year <- function(sg,y)
  !is.na(sg) & sg %in% core_for_year(y)

cat("\n============================================================\n")
cat("P3_04a2 — ROGERS REFINED DYNAMIC-CORE BENCHMARK\n")
cat("============================================================\n")
cat("Core groups before 1990:",length(core21),"\n")
cat("Core groups from 1990:",length(unique(c(core21,"WYCHELM"))),"\n")

# -----------------------------------------------------------------------------
# Capture-to-next-capture movement, strictly truncated at 31 Dec 1995.
# -----------------------------------------------------------------------------

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    capture_date=as.Date(capture_date),
    year=year(capture_date),
    socg=clean_sg(socg)
  ) %>%
  filter(tattoo!="",!is.na(capture_date),!is.na(socg),
         capture_date<=as.Date("1995-12-31")) %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  mutate(
    next_socg=lead(socg),
    next_date=lead(capture_date),
    next_year=year(next_date),
    move_next=if_else(!is.na(next_socg),
                      as.integer(socg!=next_socg),NA_integer_)
  ) %>%
  ungroup() %>%
  mutate(
    current_core=map2_lgl(socg,year,is_core_year),
    next_core=map2_lgl(next_socg,next_year,is_core_year)
  )

move_dynamic_core <- live %>%
  filter(year>=1978L,year<=1995L,
         current_core,next_core,!is.na(move_next)) %>%
  group_by(year) %>%
  summarise(
    n_scorable=n(),
    n_moves=sum(move_next),
    movement_proportion=mean(move_next),
    .groups="drop"
  )

# All-study-area sensitivity under the same strict 1978-1995 truncation.
move_all_strict <- live %>%
  filter(year>=1978L,year<=1995L,!is.na(move_next)) %>%
  group_by(year) %>%
  summarise(
    n_scorable=n(),
    n_moves=sum(move_next),
    movement_proportion=mean(move_next),
    .groups="drop"
  )

# -----------------------------------------------------------------------------
# Culture-only incident series within the same dynamic core.
# -----------------------------------------------------------------------------

iy <- as_tibble(b$individual_year) %>%
  mutate(
    year=as.integer(year),
    resident_socg=clean_sg(resident_socg),
    incident=as.integer(incident_excretor %in% TRUE),
    susceptible=as.integer(susceptible_start %in% TRUE),
    dynamic_core=map2_lgl(resident_socg,year,is_core_year)
  )

inc_dynamic_core <- iy %>%
  filter(dynamic_core) %>%
  group_by(year) %>%
  summarise(
    incidents=sum(incident,na.rm=TRUE),
    susceptible=sum(susceptible,na.rm=TRUE),
    culture_incidence=if_else(susceptible>0,incidents/susceptible,NA_real_),
    .groups="drop"
  )

inc_all <- iy %>%
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
    filter(is.finite(movement_proportion),
           is.finite(next_year_culture_incidence)) %>%
    arrange(year)

  lm_fit <- lm(next_year_culture_incidence~movement_proportion,data=d)

  ma1 <- try(
    arima(
      d$next_year_culture_incidence,
      order=c(0,0,1),
      xreg=matrix(d$movement_proportion,ncol=1,
                  dimnames=list(NULL,"movement_proportion")),
      include.mean=TRUE,method="ML"
    ),
    silent=TRUE
  )

  sm <- coef(summary(lm_fit))
  rows <- tibble(
    series=label,model="OLS",n_year_pairs=nrow(d),
    estimate=sm["movement_proportion","Estimate"],
    std_error=sm["movement_proportion","Std. Error"],
    statistic=sm["movement_proportion","t value"],
    p_value=sm["movement_proportion","Pr(>|t|)"],
    residual_MA1=NA_real_
  )

  if(!inherits(ma1,"try-error")){
    cf <- coef(ma1); se <- sqrt(diag(ma1$var.coef))
    if("movement_proportion" %in% names(cf)){
      z <- cf["movement_proportion"]/se["movement_proportion"]
      rows <- bind_rows(rows,tibble(
        series=label,model="MA1",n_year_pairs=nrow(d),
        estimate=unname(cf["movement_proportion"]),
        std_error=unname(se["movement_proportion"]),
        statistic=unname(z),
        p_value=2*pnorm(abs(z),lower.tail=FALSE),
        residual_MA1=if("ma1" %in% names(cf)) unname(cf["ma1"]) else NA_real_
      ))
    }
  }

  cor_p <- cor.test(d$movement_proportion,d$next_year_culture_incidence,
                    method="pearson")
  cor_s <- suppressWarnings(cor.test(
    d$movement_proportion,d$next_year_culture_incidence,
    method="spearman",exact=FALSE))

  diagnostics <- tibble(
    series=label,
    n_year_pairs=nrow(d),
    overall_movement_proportion=sum(d$n_moves)/sum(d$n_scorable),
    movement_min_year=d$year[which.min(d$movement_proportion)],
    movement_max_year=d$year[which.max(d$movement_proportion)],
    movement_1985=d$movement_proportion[d$year==1985][1],
    movement_1990=d$movement_proportion[d$year==1990][1],
    pearson_r=unname(cor_p$estimate),pearson_p=cor_p$p.value,
    spearman_rho=unname(cor_s$estimate),spearman_p=cor_s$p.value
  )

  list(data=d,coef=rows,diagnostics=diagnostics,lm=lm_fit,ma1=ma1)
}

core_fit <- fit_series(move_dynamic_core,inc_dynamic_core,
                       "DYNAMIC_21_TO_22_CORE")
all_fit <- fit_series(move_all_strict,inc_all,
                      "ALL_GROUPS_STRICT_1978_1995")

coef_tab <- bind_rows(core_fit$coef,all_fit$coef)
diag_tab <- bind_rows(core_fit$diagnostics,all_fit$diagnostics)

cat("\nMOVEMENT-SERIES CHECK\n")
print(diag_tab,n=Inf,width=Inf)
cat("Published Rogers qualitative pattern: movement minimum around 1985, maximum around 1990.\n")

cat("\nLAGGED MOVEMENT -> NEXT-YEAR CULTURE INCIDENCE\n")
print(coef_tab,n=Inf,width=Inf)
cat("Published Rogers final reference: positive association, t=3.09, df=12, p<0.01.\n")

write_csv(core_fit$data,
          "results/Phase3/P3_04a2_rogers_dynamic_core_annual_series.csv")
write_csv(all_fit$data,
          "results/Phase3/P3_04a2_rogers_allgroups_strict_annual_series.csv")
write_csv(coef_tab,
          "results/Phase3/P3_04a2_rogers_coefficients.csv")
write_csv(diag_tab,
          "results/Phase3/P3_04a2_rogers_diagnostics.csv")

saveRDS(
  list(
    dynamic_core=core_fit,
    all_groups_strict=all_fit,
    core21=core21,
    added_from_1990="WYCHELM",
    caveat=paste(
      "Dynamic core follows literature evidence of 21 core groups before 1990",
      "and Wychelm added from 1990. Culture incidence is reconstructed from",
      "the current cleaned archive and may not exactly equal the original series."
    )
  ),
  "results/Phase3/P3_04a2_rogers_refined_core_benchmark.rds"
)

cat("\nP3_04a2 COMPLETE\n")
