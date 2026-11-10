#!/usr/bin/env Rscript
# Woodchester V12 entry/disappearance/mortality audit: real curated evidence.
# READ ONLY. Does not fit survival, immigration, emigration, or density.
# Historical V11R2 zone probabilities only, never biological zone truth.
# Usage:
# V12_SNAPSHOT=data/model_snapshots/v12_20261110T105256Z_2681271 \
# ZONE_AUDIT_DIR=outputs/v11r2_core_periphery/audit_20261109T134751Z \
# Rscript scripts/ModularFitting/Woodchester_V12_Entry_Exit_Death_Zone_Audit.R
snap <- Sys.getenv("V12_SNAPSHOT","")
zone_dir <- Sys.getenv("ZONE_AUDIT_DIR","")
if(!nzchar(snap) || !nzchar(zone_dir))
 stop("Set V12_SNAPSHOT and ZONE_AUDIT_DIR")
paths <- c(
  file.path(snap,"MANIFEST.txt"),
  file.path(snap,"qualifying_live.rds"),
  file.path(snap,"mortality_candidates.rds"),
  file.path(zone_dir,"04_individual_annual_zone_probabilities.csv"))
if(!all(file.exists(paths)))
 stop("Missing source: ",paste(paths[!file.exists(paths)],collapse=", "))
manifest <- readLines(paths[1],warn=FALSE)
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",manifest)))
 stop("Snapshot provenance is not audited Supabase")
live <- as.data.frame(readRDS(paths[2]))
mort <- as.data.frame(readRDS(paths[3]))
zone <- read.csv(paths[4],stringsAsFactors=FALSE)
norm <- function(x) toupper(trimws(as.character(x)))
live$tattoo <- norm(live$tattoo)
live$capture_date <- as.Date(live$capture_date)
live$year <- as.integer(format(live$capture_date,"%Y"))
live$quarter <- (as.integer(format(live$capture_date,"%m"))-1L)%/%3L+1L
live <- live[!is.na(live$year)&live$year>=1977L&
               live$year<=2025L,,drop=FALSE]
if(!nrow(live)||anyNA(live$tattoo)||any(!nzchar(live$tattoo)))
 stop("No valid live histories")
if(anyNA(live$capture_date))stop("Live date missing")
if(anyDuplicated(paste(live$tattoo,live$capture_date,live$capture_id)))
 stop("Duplicate live-source rows")
if(!all(c("tattoo","capture_id","recorded_event_date",
 "terminal_model_status","mortality_review_status",
 "linked_pm_capture_id","next_live_capture_date") %in% names(mort)))
 stop("Mortality data schema differs; audit before fitting")
mort$tattoo <- norm(mort$tattoo)
mort$recorded_event_date <- as.Date(mort$recorded_event_date)
mort$next_live_capture_date <- as.Date(mort$next_live_capture_date)
zone$tattoo <- norm(zone$tattoo)
if(!all(c("scenario","tattoo","year","p_core","p_periphery",
 "p_outside") %in% names(zone)))stop("Zone fields missing")
if(anyDuplicated(paste(zone$scenario,zone$tattoo,zone$year,sep="|")))
 stop("Duplicated posterior zone index")
if(anyNA(zone[,c("p_core","p_periphery","p_outside")]) ||
 any(abs(rowSums(zone[,c("p_core","p_periphery","p_outside")])-1)>1e-6))
 stop("Invalid posterior zone sums")
# Annual and quarterly observation panels, positive events only.
qy <- unique(live[,c("tattoo","year","quarter")])
qy <- qy[order(qy$tattoo,qy$year,qy$quarter),,drop=FALSE]
ay <- unique(qy[,c("tattoo","year")])
ay <- ay[order(ay$tattoo,ay$year),,drop=FALSE]
first_y <- tapply(ay$year,ay$tattoo,min)
last_y <- tapply(ay$year,ay$tattoo,max)
n_years <- tapply(ay$year,ay$tattoo,length)
ids <- names(first_y)
person <- data.frame(tattoo=ids,
 first_observed_year=as.integer(first_y[ids]),
 last_observed_year=as.integer(last_y[ids]),
 n_years_observed=as.integer(n_years[ids]),row.names=NULL)
person$right_censored_2025 <- person$last_observed_year==2025L
person$first_observed_not_proven_entry <- TRUE
person$last_observed_not_proven_death_or_emigration <- TRUE
if(!all(person$first_observed_year<=person$last_observed_year))
 stop("Invalid live history")
# Mortality source: retain BOTH adjudicated terminal status and held reviews.
# Several mortality source records may refer to the same death episode.
# This script deliberately DOES NOT collapse those into a unique death count.
terminal <- mort[!is.na(mort$terminal_model_status)&
 mort$terminal_model_status=="CANDIDATE_TERMINAL_DEATH",,drop=FALSE]
held <- mort[is.na(mort$terminal_model_status)|
 mort$terminal_model_status!="CANDIDATE_TERMINAL_DEATH",,drop=FALSE]
postlive <- merge(terminal,person[,c("tattoo","last_observed_year")],
 by="tattoo",all.x=TRUE,sort=FALSE)
postlive$death_year <- as.integer(format(postlive$recorded_event_date,"%Y"))
postlive$source_death_before_last_live_year <- !is.na(postlive$death_year)&
 !is.na(postlive$last_observed_year)&
 postlive$death_year < postlive$last_observed_year
# Full date comparison is more informative than calendar-year comparison.
last_dates <- tapply(as.numeric(live$capture_date),live$tattoo,max)
postlive$source_death_before_later_live_date <- !is.na(postlive$recorded_event_date)&
 !is.na(postlive$tattoo)&postlive$tattoo%in%names(last_dates)&
 as.numeric(postlive$recorded_event_date) <
 as.numeric(last_dates[postlive$tattoo])
# Multiple terminal sources for same animal are NOT necessarily distinct deaths.
term_ids <- unique(terminal$tattoo)
person$has_any_candidate_terminal_source <- person$tattoo%in%term_ids
person$n_terminal_source_rows <- as.integer(table(factor(
 terminal$tattoo,levels=person$tattoo)))
person$n_held_mortality_rows <- as.integer(table(factor(
 held$tattoo,levels=person$tattoo)))
# Prior V11R2 spatial posteriors are only available for a selected
# previously mapped 1932-individual population and its annual windows.
zone_years <- merge(zone,ay,by=c("tattoo","year"),sort=FALSE)
zone_years <- zone_years[zone_years$year<2025L,,drop=FALSE]
obs_keys <- paste(ay$tattoo,ay$year,sep="|")
zone_years$observed_next_year <-
 paste(zone_years$tattoo,zone_years$year+1L,sep="|")%in%obs_keys
zone_years$first_observed_year <-
 zone_years$year==as.integer(first_y[zone_years$tattoo])
# Compute posterior-weighted exposure and observed next-year return.
summarise_zone <- function(d) {
 z <- c("core","periphery","outside")
 do.call(rbind,lapply(z,function(zz){
   w<-d[[paste0("p_",zz)]]
   den<-sum(w)
   data.frame(scenario=d$scenario[1],zone=zz,
     n_observed_animal_years=nrow(d),
     posterior_expected_zone_observed_years=den,
     posterior_expected_nextyear_observed=sum(w*d$observed_next_year),
     nextyear_observation_fraction=if(den>0)
        sum(w*d$observed_next_year)/den else NA_real_,
     posterior_expected_first_observation_years=sum(w*d$first_observed_year))
 }))
}
zone_aggregate <- if(nrow(zone_years))
 do.call(rbind,lapply(split(zone_years,zone_years$scenario),summarise_zone)) else
 data.frame()
annual <- do.call(rbind,lapply(split(ay,ay$year),function(z) {
 data.frame(year=z$year[1],n_observed_tattoos=nrow(z),
 n_first_observed_tattoos=sum(
   z$year==as.integer(first_y[z$tattoo])),
 n_last_observed_tattoos=sum(
   z$year==as.integer(last_y[z$tattoo])))
}))
annual<-annual[order(annual$year),,drop=FALSE]
# Minimal aggregate audit: no ungrounded population-entry rates.
summary <- data.frame(metric=c(
 "source_qualifying_live_rows_1977_2025",
 "distinct_positive_live_tattoos",
 "distinct_positive_live_tattoo_quarters",
 "observed_once_in_single_year",
 "observed_again_in_multiple_years",
 "candidate_terminal_source_rows_all_years",
 "distinct_tattoos_with_candidate_terminal_source_all_years",
 "held_mortality_source_rows_all_years",
 "candidate_terminal_source_rows_before_later_live_capture",
 "legacy_V11R2_posterior_tattoo_years_with_real_live_record"),
 value=c(nrow(live),nrow(person),nrow(qy),
 sum(person$n_years_observed==1L),
 sum(person$n_years_observed>=2L),
 nrow(terminal),length(unique(terminal$tattoo)),nrow(held),
 sum(postlive$source_death_before_later_live_date,na.rm=TRUE),
 nrow(unique(zone_years[,c("tattoo","year"),drop=FALSE]))))
out <- Sys.getenv("V12_ENTRY_AUDIT_OUT","")
if(!nzchar(out))out <- file.path("outputs","v12_entry_exit_death_zone_audit",
 paste0("audit_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Refusing overwrite: ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(summary,file.path(out,"01_scope_and_risk_summary.csv"),row.names=FALSE)
write.csv(annual,file.path(out,"02_annual_live_observation_history.csv"),row.names=FALSE)
write.csv(zone_aggregate,file.path(out,"03_old_V11R2_zone_observed_return.csv"),row.names=FALSE)
# Sensitive individual/event review files stay local and untracked.
write.csv(person,file.path(out,"04_individual_histories_LOCAL.csv"),row.names=FALSE)
write.csv(postlive[,c("tattoo","capture_id","recorded_event_date",
 "terminal_model_status","mortality_review_status","linked_pm_capture_id",
 "source_death_before_later_live_date")],
 file.path(out,"05_candidate_terminal_source_audit_LOCAL.csv"),row.names=FALSE)
write.csv(held,file.path(out,"06_held_mortality_review_LOCAL.csv"),row.names=FALSE)
writeLines(c(paste0("snapshot=",snap),paste0("legacy_zone_audit=",zone_dir),
 "READ-ONLY source evidence. No actual trap effort or zero-capture sessions.",
 "Full source death rows are NOT unique biological death events.",
 "Death classification requires episode audit and post-death live cross-check.",
 "First capture is NOT automatically immigration, birth or local recruitment.",
 "Last capture is NOT automatically death, emigration or permanent departure.",
 "Observed yearly return is a mixture of phi, p, movement and effort.",
 "Old V11R2 zones are smoothed from later captures: outcome leakage if used as",
 "independent predictors of next-year observation or causal survival.",
 "Outside global detector convex hull is NOT independently known emigration.",
 "Year 2025 not assessed for following year observation.",
 "No density, immigration, death hazard or survival rate fitted.",
 "Local person-level outputs contain sensitive research data; keep out of Git."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("=== V12 ENTRY / EXIT / DEATH / ZONE SOURCE READINESS ===\n")
print(summary,row.names=FALSE)
cat("\n=== HISTORICAL V11R2 ZONE / OBSERVED RETURN ===\n")
print(zone_aggregate,row.names=FALSE,digits=4)
cat("Saved ",out,"\n",sep="")
cat("NOT survival, immigration, death or emigration estimates.\n")
