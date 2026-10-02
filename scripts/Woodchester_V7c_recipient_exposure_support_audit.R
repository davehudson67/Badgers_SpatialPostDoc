# =============================================================================
# WOODCHESTER V7c — RECIPIENT EXPOSURE SUPPORT AUDIT
#
# PURPOSE
# -------
# Before fitting an onward-transmission model, quantify whether there is enough
# prospective recipient information after observed infectious source events.
#
# Exposure year = t.
# Recipient must be another badger observed in the same annual social group at t.
# Outcome window = infection acquisition in Q1-Q4 of t+1.
# Susceptibility = sampled latent infection state still negative at Q4(t).
#
# IMPORTANT
# ---------
# This is a support/audit script, NOT an effect model. It deliberately reports
# how many susceptible recipients and acquisition events are available under
# increasingly specific source definitions:
#   - any strict observed Excretor/Super-excretor source;
#   - any exact observed social-group-arriving infectious source;
#   - any Super excretor source;
#   - any exact observed social-group-arriving Super excretor.
#
# "Strict source" means the disease-status capture itself was recorded in the
# same social group as the source badger's annual destination group.
# =============================================================================

library(tidyverse)

AUDIT_FILE  <- "data/badger_V7c_infected_mover_spreader_audit.rds"
INF_FILE    <- "data/badger_infection_trajectories_all_tests_inferred.rds"
ANNUAL_FILE <- "data/badger_annual_observed_sett_locations.rds"

for(f in c(AUDIT_FILE,INF_FILE,ANNUAL_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

v7c <- readRDS(AUDIT_FILE)
inf <- readRDS(INF_FILE)
annual <- as_tibble(readRDS(ANNUAL_FILE))

START_YEAR <- as.integer(inf$start_year)
INF_IDS <- str_to_upper(str_squish(as.character(inf$tattoo)))
N_DRAW <- ncol(inf$infection_time)

if(!all(c("candidate_sources","movement_intervals") %in% names(v7c))) stop("V7c audit RDS lacks required objects.")
need_annual <- c("tattoo","year","annual_socg")
miss <- setdiff(need_annual,names(annual))
if(length(miss)) stop("Annual location file missing: ",paste(miss,collapse=", "))

annual2 <- annual %>%
  transmute(tattoo=str_to_upper(str_squish(as.character(tattoo))),
            year=as.integer(year),annual_socg=as.character(annual_socg)) %>%
  filter(!is.na(tattoo),tattoo!="",!is.na(year),!is.na(annual_socg),annual_socg!="") %>%
  distinct(tattoo,year,.keep_all=TRUE)

# Last annual observation gives a conservative follow-up support check. We do
# not require an exact t+1 capture; we require that the animal remained in the
# observed study history through at least t+1.
last_obs <- annual2 %>% group_by(tattoo) %>% summarise(last_observed_year=max(year),.groups="drop")

# Strict observed infectious sources from the first V7c audit.
strict_sources <- as_tibble(v7c$candidate_sources) %>%
  filter(status_group_confirmed %in% TRUE) %>%
  transmute(source_tattoo=str_to_upper(str_squish(as.character(tattoo))),
            year=as.integer(year),destination_socg=as.character(destination_socg),
            disease_class=as.character(disease_class),p_high=as.numeric(p_high),
            observed_socg_switch=as.logical(observed_socg_switch)) %>%
  filter(!is.na(source_tattoo),source_tattoo!="",!is.na(year),!is.na(destination_socg),destination_socg!="")

source_gy <- strict_sources %>%
  group_by(year,destination_socg) %>%
  summarise(
    n_infectious_sources=n_distinct(source_tattoo),
    n_super_sources=n_distinct(source_tattoo[disease_class=="Super excretor"]),
    n_observed_infectious_arrivals=n_distinct(source_tattoo[observed_socg_switch %in% TRUE]),
    n_observed_super_arrivals=n_distinct(source_tattoo[disease_class=="Super excretor" & observed_socg_switch %in% TRUE]),
    expected_high_source=sum(p_high,na.rm=TRUE),
    .groups="drop"
  ) %>%
  mutate(any_infectious_source=n_infectious_sources>0,
         any_super_source=n_super_sources>0,
         any_infectious_arrival=n_observed_infectious_arrivals>0,
         any_super_arrival=n_observed_super_arrivals>0)

# All annual group-years create the comparison universe. Group-years without a
# strict source are retained as the reference support pool, but "no strict
# source" must not be interpreted as proof that no infectious animal existed.
group_years <- annual2 %>%
  count(year,annual_socg,name="n_group_members") %>%
  filter(n_group_members>=2L) %>%
  rename(destination_socg=annual_socg) %>%
  left_join(source_gy,by=c("year","destination_socg")) %>%
  mutate(across(c(n_infectious_sources,n_super_sources,n_observed_infectious_arrivals,n_observed_super_arrivals),~replace_na(.x,0L)),
         expected_high_source=replace_na(expected_high_source,0),
         across(c(any_infectious_source,any_super_source,any_infectious_arrival,any_super_arrival),~replace_na(.x,FALSE)),
         exposure_class=case_when(
           any_super_arrival ~ "Observed Super-excretor arrival",
           any_infectious_arrival ~ "Observed infectious arrival",
           any_super_source ~ "Super excretor present, no observed arrival",
           any_infectious_source ~ "Infectious source present, no observed arrival",
           TRUE ~ "No strict observed infectious source"
         ))

# Recipient rows: annual group members, excluding every strict source individual
# from its own source group-year. For unexposed group-years there is no source to
# exclude. Follow-up requires observed history to extend through t+1.
source_ids_by_gy <- strict_sources %>%
  group_by(year,destination_socg) %>%
  summarise(source_ids=list(unique(source_tattoo)),.groups="drop")

recipients <- annual2 %>%
  rename(destination_socg=annual_socg) %>%
  inner_join(group_years,by=c("year","destination_socg")) %>%
  left_join(source_ids_by_gy,by=c("year","destination_socg")) %>%
  left_join(last_obs,by="tattoo") %>%
  rowwise() %>%
  mutate(is_source=if(is.null(source_ids) || length(source_ids)==0L) FALSE else tattoo %in% source_ids) %>%
  ungroup() %>%
  filter(!is_source,last_observed_year>=year+1L) %>%
  mutate(inf_row=match(tattoo,INF_IDS)) %>%
  filter(!is.na(inf_row))

if(!nrow(recipients)) stop("No recipient rows after support/follow-up filtering.")

# Matrix of sampled susceptibility at Q4(t) and acquisition in t+1.
it <- inf$infection_time[recipients$inf_row,,drop=FALSE]
q4_t <- 4L*(recipients$year-START_YEAR)+4L
start_next <- q4_t+1L
end_next <- q4_t+4L

SUS <- matrix(FALSE,nrow(recipients),N_DRAW)
EVT <- matrix(FALSE,nrow(recipients),N_DRAW)
for(j in seq_len(nrow(recipients))){
  tt <- as.integer(it[j,])
  SUS[j,] <- tt==0L | tt>q4_t[j]
  EVT[j,] <- tt>=start_next[j] & tt<=end_next[j]
}

recipients$p_susceptible_q4 <- rowMeans(SUS)
recipients$p_acquire_next_year <- rowMeans(EVT)

summarise_flag <- function(flag,label){
  rr <- if(flag=="ALL") rep(TRUE,nrow(recipients)) else recipients[[flag]]
  idx <- which(rr %in% TRUE)
  if(!length(idx)) return(tibble(exposure=label,group_years=0L,recipient_rows=0L,recipient_badgers=0L,
                                 median_susceptible=0,q025_susceptible=0,q975_susceptible=0,
                                 median_acquisitions=0,q025_acquisitions=0,q975_acquisitions=0,
                                 median_risk=NA_real_,p_draw_any_event=0))
  nrisk <- colSums(SUS[idx,,drop=FALSE])
  nevent <- colSums(EVT[idx,,drop=FALSE])
  risk <- ifelse(nrisk>0,nevent/nrisk,NA_real_)
  tibble(
    exposure=label,
    group_years=n_distinct(paste(recipients$year[idx],recipients$destination_socg[idx],sep="|")),
    recipient_rows=length(idx),recipient_badgers=n_distinct(recipients$tattoo[idx]),
    median_susceptible=median(nrisk),q025_susceptible=unname(quantile(nrisk,.025)),q975_susceptible=unname(quantile(nrisk,.975)),
    median_acquisitions=median(nevent),q025_acquisitions=unname(quantile(nevent,.025)),q975_acquisitions=unname(quantile(nevent,.975)),
    median_risk=median(risk,na.rm=TRUE),p_draw_any_event=mean(nevent>0)
  )
}

support_summary <- bind_rows(
  summarise_flag("ALL","All eligible recipient group-years"),
  summarise_flag("any_infectious_source","Any strict infectious source"),
  summarise_flag("any_infectious_arrival","Any exact observed infectious SG arrival"),
  summarise_flag("any_super_source","Any Super excretor source"),
  summarise_flag("any_super_arrival","Any exact observed Super-excretor SG arrival")
)

class_summary <- map_dfr(unique(group_years$exposure_class),function(cl){
  idx <- which(recipients$exposure_class==cl)
  if(!length(idx)) return(tibble(exposure_class=cl,group_years=0L,recipient_rows=0L,recipient_badgers=0L,
                                 median_susceptible=0,median_acquisitions=0,median_risk=NA_real_))
  nrisk <- colSums(SUS[idx,,drop=FALSE]); nevent <- colSums(EVT[idx,,drop=FALSE])
  tibble(exposure_class=cl,
         group_years=n_distinct(paste(recipients$year[idx],recipients$destination_socg[idx],sep="|")),
         recipient_rows=length(idx),recipient_badgers=n_distinct(recipients$tattoo[idx]),
         median_susceptible=median(nrisk),median_acquisitions=median(nevent),
         median_risk=median(ifelse(nrisk>0,nevent/nrisk,NA_real_),na.rm=TRUE))
})

cat("\n============================================================\n")
cat("V7c RECIPIENT EXPOSURE SUPPORT AUDIT\n")
cat("============================================================\n")
cat("Infection trajectory draws:",N_DRAW,"\n")
cat("Eligible annual group-years (>=2 observed members):",nrow(group_years),"\n")
cat("Recipient rows with follow-up through t+1:",nrow(recipients),"\n")
cat("Unique recipient badgers:",n_distinct(recipients$tattoo),"\n\n")

cat("PROSPECTIVE SUPPORT BY SOURCE DEFINITION\n")
print(support_summary,n=Inf,width=Inf)

cat("\nHIERARCHICAL EXPOSURE CLASSES\n")
print(class_summary,n=Inf,width=Inf)

cat("\nDECISION GUIDE\n")
cat("- If observed infectious-arrival exposure has very few susceptible recipients or acquisitions, do not fit a conventional multi-parameter mover-transmission model.\n")
cat("- Super-excretor arrival is expected to be too sparse for a standalone coefficient if supported by only one group-year.\n")
cat("- Super-excretor PRESENCE can still be tested as a local infectiousness sensitivity if recipient support is adequate.\n")
cat("- The primary mover-spread exposure should combine Excretor + Super excretor and use exact observed SG arrival, with general local infection pressure retained separately.\n")
cat("- Group-years with no strict observed source are a comparison pool, not proof of absence of infectious badgers.\n")

# Save compact audit outputs.
dir.create("results",showWarnings=FALSE,recursive=TRUE)
dir.create("data",showWarnings=FALSE,recursive=TRUE)
saveRDS(list(group_years=group_years,recipients=recipients,support_summary=support_summary,
             class_summary=class_summary,settings=list(outcome_window="Q1-Q4(t+1)",
             susceptibility_time="Q4(t)",followup_rule="last observed annual year >= t+1",
             source_definition="strict observed capture in destination social group")),
        "data/badger_V7c_recipient_exposure_support_audit.rds")
write_csv(support_summary,"results/V7c_recipient_exposure_support_summary.csv")
write_csv(class_summary,"results/V7c_recipient_exposure_class_summary.csv")

cat("\nSaved:\n")
cat("  data/badger_V7c_recipient_exposure_support_audit.rds\n")
cat("  results/V7c_recipient_exposure_support_summary.csv\n")
cat("  results/V7c_recipient_exposure_class_summary.csv\n")
