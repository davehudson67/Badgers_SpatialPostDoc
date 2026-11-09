#!/usr/bin/env Rscript
# WOODCHESTER V12 — read-only spatial-input eligibility audit.
# Requires an immutable, reviewed, Supabase-derived V12 snapshot.
# Does NOT classify provisional sett points as verified, build a fit-ready
# spatial dataset, discard unlocated encounters, or change the database.
# Sensitive event-level outputs remain local and must not be committed.

root <- Sys.getenv("V12_SNAPSHOT", "")
if (!nzchar(root) || !dir.exists(root)) stop("Set V12_SNAPSHOT")
required_files <- file.path(root,c("MANIFEST.txt","qualifying_live.rds",
                                    "encounters.rds"))
if (!all(file.exists(required_files)))
 stop("Missing snapshot file(s): ",
      paste(required_files[!file.exists(required_files)],collapse=", "))
manifest <- readLines(required_files[1],warn=FALSE)
if (!any(grepl("^source_encounters=analysis.encounters_clean_v1",manifest)))
 stop("Unrecognised curated snapshot source")
live <- as.data.frame(readRDS(required_files[2]))
all_enc <- as.data.frame(readRDS(required_files[3]))
required <- c("capture_id","tattoo","capture_date","is_pm","sett_id",
              "episode_record_role","encounter_type","location_type",
              "location_easting","location_northing","location_quality")
missing <- setdiff(required,names(live))
if(length(missing))stop("Qualifying live columns missing: ",paste(missing,collapse=", "))
if(anyDuplicated(live$capture_id)||anyNA(live$capture_id)||
   anyDuplicated(all_enc$capture_id))
 stop("Invalid source capture ID key")
norm <- function(x) {
 z<-toupper(trimws(as.character(x)))
 z[is.na(x)]<-NA_character_
 z
}
live$tattoo<-norm(live$tattoo)
live$capture_date<-as.Date(live$capture_date)
if(anyNA(live$tattoo)||any(!nzchar(live$tattoo))||anyNA(live$capture_date))
 stop("Invalid scientific identity or capture date")
if(any(live$is_pm!=FALSE,na.rm=TRUE) ||
   any(live$episode_record_role=="PM_COMPANION",na.rm=TRUE))
 stop("Qualifying-live source contains PM/companion encounter")
live$year<-as.integer(format(live$capture_date,"%Y"))
live$quarter<-(as.integer(format(live$capture_date,"%m"))-1L)%/%3L+1L
live<-live[live$year>=1977L&live$year<=2025L,,drop=FALSE]
if(!nrow(live))stop("No qualifying live captures in model period")
live$location_type<-norm(live$location_type)
live$location_quality<-norm(live$location_quality)
live$encounter_type<-norm(live$encounter_type)
live$x<-suppressWarnings(as.numeric(live$location_easting))
live$y<-suppressWarnings(as.numeric(live$location_northing))
live$xy_finite<-is.finite(live$x)&is.finite(live$y)
# Fixed-sett spatial likelihood requires BOTH appropriate type and a
# provenance-supported coordinate; other kinds of encounter are retained
# as time-stamped evidence but not treated as observations at trap sites.
live$location_is_sett<- !is.na(live$location_type)&
                        live$location_type=="SETT"
live$has_sett_id<-!is.na(live$sett_id)
live$sett_candidate<-live$xy_finite&live$location_is_sett&
                     live$has_sett_id
live$spatial_eligibility<-rep("WITHHELD_OTHER_LOCATION",nrow(live))
live$spatial_eligibility[!live$xy_finite]<-"WITHHELD_MISSING_XY"
live$spatial_eligibility[live$xy_finite & !live$location_is_sett]<-
   "WITHHELD_NON_SETT_LOCATION"
live$spatial_eligibility[live$xy_finite & live$location_is_sett &
                          !live$has_sett_id]<-"WITHHELD_UNLINKED_SETT"
conflict<-live$location_quality %in%
 c("SETT_COORDINATE_CONFLICT","UNRESOLVED",
   "GRID_REFERENCE_AMBIGUOUS_WITHHELD")
live$spatial_eligibility[live$sett_candidate & conflict]<-
   "WITHHELD_LOCATION_CONFLICT"
assoc<-live$location_quality %in%
 c("SETT_ASSOCIATION_ONLY","SETT_ASSOCIATION_PROVISIONAL")
live$spatial_eligibility[live$sett_candidate & assoc]<-
   "WITHHELD_SETT_ASSOCIATION"
provisional<-!is.na(live$location_quality) &
             live$location_quality=="SETT_POINT_PROVISIONAL"
live$spatial_eligibility[live$sett_candidate & provisional]<-
   "CANDIDATE_FIXED_SETT_PROVISIONAL"
# No category in the current frozen data is automatically known 'verified'.
# Other finite XY + SETT records are review-required, not auto-included.
other <- live$sett_candidate & !(conflict|assoc|provisional)
live$spatial_eligibility[other]<-"REVIEW_OTHER_SETT_QUALITY"
live$spatial_candidate<-live$spatial_eligibility==
                         "CANDIDATE_FIXED_SETT_PROVISIONAL"
live$observed_alive<-TRUE

# Within an audited canonical sett_id, a changing XY signals a conflict
# even if every individual event was labelled as provisional.
s<-live[live$spatial_candidate,c("sett_id","x","y"),drop=FALSE]
if(nrow(s)) {
 key<-paste(s$x,s$y,sep=":")
 ncoord<-tapply(key,as.character(s$sett_id),
                function(z)length(unique(z)))
 inconsistent<-names(ncoord)[ncoord>1L]
} else inconsistent<-character(0)
live$multiple_xy_for_sett_id<-live$spatial_candidate&
 as.character(live$sett_id)%in%inconsistent
live$spatial_eligibility[live$multiple_xy_for_sett_id]<-
 "WITHHELD_SETT_ID_MULTIPLE_XY"
live$spatial_candidate[live$multiple_xy_for_sett_id]<-FALSE

# Another fail-closed screen: one coordinate attached to different sett IDs
# is not necessarily incorrect (neighbouring sett points may coincide), but
# should be individually reviewed rather than automatically fit as separate
# equivalent detectors.
s<-live[live$spatial_candidate,c("sett_id","x","y"),drop=FALSE]
if(nrow(s)) {
 key<-paste(s$x,s$y,sep=":")
 ids_by_xy<-split(as.character(s$sett_id),key)
 shared_coords<-names(ids_by_xy)[vapply(ids_by_xy,
   function(z)length(unique(z))>1L,logical(1))]
} else shared_coords<-character(0)
live$shared_xy_between_setts<-live$spatial_candidate&
 paste(live$x,live$y,sep=":")%in%shared_coords
live$spatial_eligibility[live$shared_xy_between_setts]<-
 "REVIEW_SHARED_COORDINATE"
live$spatial_candidate[live$shared_xy_between_setts]<-FALSE

# Count existing non-live and unusual episode roles, without converting any
# to capture detections or dropping them from the source data.
all_enc$is_pm<-as.logical(all_enc$is_pm)
role<-as.data.frame(table(is_pm=ifelse(is.na(all_enc$is_pm),
 "UNKNOWN",ifelse(all_enc$is_pm,"PM","NOT_PM")),
 episode_role=ifelse(is.na(all_enc$episode_record_role),
 "UNKNOWN",as.character(all_enc$episode_record_role))),
 stringsAsFactors=FALSE)
role<-role[role$Freq>0,,drop=FALSE]
live$year_quarter<-paste(live$year,live$quarter,sep="Q")

# Rows and distinct tattoo dates (events) are separate: source rows are
# never silently de-duplicated. Same-day distinct capture IDs are flagged.
event_key<-paste(live$tattoo,live$capture_date,sep="|")
event_repeated<-duplicated(event_key)|duplicated(event_key,fromLast=TRUE)
live$multiple_source_rows_same_day<-event_repeated
summary_by <- function(group) {
 do.call(rbind,lapply(split(seq_len(nrow(live)),group),function(ii) {
   z<-live[ii,,drop=FALSE]
   data.frame(group=as.character(group[ii[1]]),n_rows=nrow(z),
     n_tattoos=length(unique(z$tattoo)),
     n_tattoo_dates=length(unique(paste(z$tattoo,z$capture_date))),
     n_multiple_event_rows=sum(z$multiple_source_rows_same_day),
     n_spatial_candidate=sum(z$spatial_candidate),
     n_nonspatial_encounter=sum(!z$spatial_candidate))
 }))
}
category<-summary_by(live$spatial_eligibility)
category<-category[order(-category$n_rows),,drop=FALSE]
quality<-summary_by(paste(
 ifelse(is.na(live$location_type),"UNKNOWN",live$location_type),
 ifelse(is.na(live$location_quality),"UNKNOWN",live$location_quality),
 sep=" | "))
annual<-do.call(rbind,lapply(split(live,live$year),function(z) {
 zsp<-z[z$spatial_candidate,,drop=FALSE]
 data.frame(year=z$year[1],n_live_rows=nrow(z),
  n_capture_days=length(unique(paste(z$tattoo,z$capture_date))),
  n_badgers=length(unique(z$tattoo)),
  n_spatial_candidate_rows=nrow(zsp),
  n_spatial_candidate_tattoos=length(unique(zsp$tattoo)),
  n_withheld_rows=sum(!z$spatial_candidate),
  n_missing_xy=sum(!z$xy_finite))
}))
annual<-annual[order(annual$year),,drop=FALSE]
quarterly<-do.call(rbind,lapply(split(live,live$year_quarter),function(z) {
 data.frame(year=z$year[1],quarter=z$quarter[1],
   n_source_rows=nrow(z),n_spatial_candidate=sum(z$spatial_candidate),
   n_withheld=sum(!z$spatial_candidate),
   n_badgers=length(unique(z$tattoo)))
}))
quarterly<-quarterly[order(quarterly$year,quarterly$quarter),,drop=FALSE]

# Consecutive ANNUAL observation support: compare which intervals contain
# any observation at both endpoints, and have spatial observations at both
# endpoints; and note intervals crossing unlocated evidence.
all_years<-unique(live[c("tattoo","year")])
spatial_years<-unique(live[live$spatial_candidate,
                             c("tattoo","year"),drop=FALSE])
all_key<-paste(all_years$tattoo,all_years$year,sep="|")
sp_key<-paste(spatial_years$tattoo,spatial_years$year,sep="|")
yearly <- all_years[order(all_years$tattoo,all_years$year),,drop=FALSE]
yearly$key<-paste(yearly$tattoo,yearly$year,sep="|")
yearly$has_candidate_xy<-yearly$key%in%sp_key
n_annual_pairs<-0L
n_pairs_spatial<-0L
n_pairs_at_least_one_unlocated<-0L
if(nrow(yearly)>1L) {
 a<-which(yearly$tattoo[-nrow(yearly)]==yearly$tattoo[-1L] &
          yearly$year[-nrow(yearly)]+1L==yearly$year[-1L])
 n_annual_pairs<-length(a)
 if(length(a)) {
   has2<-yearly$has_candidate_xy[a]&yearly$has_candidate_xy[a+1L]
   n_pairs_spatial<-sum(has2)
   n_pairs_at_least_one_unlocated<-sum(!has2)
 }
}
# Long gaps between spatially mapped years can INCLUDE additional observations
# with missing XY. Calculate this explicitly without imputing distances.
gap_rows<-list()
for(tat in unique(live$tattoo)) {
 z<-sort(unique(spatial_years$year[spatial_years$tattoo==tat]))
 if(length(z)<2L)next
 recorded<-sort(unique(all_years$year[all_years$tattoo==tat]))
 for(i in seq_len(length(z)-1L)){
  a<-z[i];b<-z[i+1L]
  gap_rows[[length(gap_rows)+1L]]<-data.frame(tattoo=tat,
   from_year=a,to_year=b,year_gap=b-a,
   n_intervening_observed_years=sum(recorded>a&recorded<b))
 }
}
gaps<-if(length(gap_rows))do.call(rbind,gap_rows) else
 data.frame(tattoo=character(),from_year=integer(),to_year=integer(),
            year_gap=integer(),n_intervening_observed_years=integer())
# Screens against the independent legacy V11R2 detector geometry. Same XY
# is not independent provenance validation, merely a reproducibility check.
refdir<-Sys.getenv("ZONE_AUDIT_DIR","")
legacy_summary<-data.frame(metric=character(),value=numeric())
if(nzchar(refdir)) {
 detpath<-file.path(refdir,"01_detector_geometry_reference.csv")
 if(!file.exists(detpath))stop("Legacy detector reference not found: ",detpath)
 det<-read.csv(detpath,stringsAsFactors=FALSE)
 if(!all(c("x","y")%in%names(det)))stop("Legacy detector XY missing")
 z<-live[live$spatial_candidate,,drop=FALSE]
 dist<-numeric(nrow(z))
 for(i in seq_len(nrow(z))) {
  dist[i]<-sqrt(min((det$x-z$x[i])^2+(det$y-z$y[i])^2))
 }
 legacy_summary<-data.frame(metric=c("n_candidate_source_rows",
  "n_candidate_exact_match_legacy_detector",
  "n_candidate_farther_than_100m"),
  value=c(nrow(z),sum(dist<1e-8),sum(dist>100)))
}
headline<-data.frame(metric=c("all_eligible_live_rows","distinct_tattoos_all",
 "candidate_spatial_rows","distinct_tattoos_spatial",
 "withheld_or_review_rows","consecutive_annual_observed_pairs",
 "consecutive_annual_pairs_spatial_both",
 "consecutive_annual_pairs_lacking_spatial_at_endpoint",
 "between_spatial_captures_intervals",
 "between_spatial_captures_intervals_with_intervening_unlocated_observation",
 "same_tattoo_date_multiple_source_rows",
 "sett_ids_with_inconsistent_xy","distinct_xy_shared_by_sett_ids"),
 value=c(nrow(live),length(unique(live$tattoo)),
 sum(live$spatial_candidate),length(unique(live$tattoo[live$spatial_candidate])),
 sum(!live$spatial_candidate),n_annual_pairs,n_pairs_spatial,
 n_pairs_at_least_one_unlocated,nrow(gaps),
 sum(gaps$n_intervening_observed_years>0),sum(event_repeated),
 length(inconsistent),length(shared_coords)))
output<-Sys.getenv("V12_SPATIAL_ELIGIBILITY_OUT","")
if(!nzchar(output))output<-file.path("outputs","v12_spatial_eligibility",
 paste0("audit_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(output))stop("Refusing to overwrite: ",output)
dir.create(output,recursive=TRUE,showWarnings=FALSE)
write.csv(headline,file.path(output,"01_inclusion_overview.csv"),row.names=FALSE)
write.csv(category,file.path(output,"02_inclusion_by_status.csv"),row.names=FALSE)
write.csv(quality,file.path(output,"03_location_type_quality.csv"),row.names=FALSE)
write.csv(annual,file.path(output,"04_inclusion_by_year.csv"),row.names=FALSE)
write.csv(quarterly,file.path(output,"05_inclusion_by_year_quarter.csv"),row.names=FALSE)
write.csv(role,file.path(output,"06_source_pm_and_episode_roles.csv"),row.names=FALSE)
write.csv(legacy_summary,file.path(output,"07_legacy_detector_coordinate_screen.csv"),
 row.names=FALSE)
# Restricted event-level review; no automatic spatial fit inputs exported.
review<-live[,c("capture_id","tattoo","capture_date","sett_id",
 "episode_record_role","encounter_type","location_type","location_quality",
 "location_easting","location_northing","xy_finite",
 "spatial_eligibility","spatial_candidate",
 "multiple_source_rows_same_day","multiple_xy_for_sett_id",
 "shared_xy_between_setts"),drop=FALSE]
write.csv(review,file.path(output,"08_EVENT_LEVEL_LOCAL_REVIEW_DO_NOT_COMMIT.csv"),
 row.names=FALSE)
write.csv(gaps,file.path(output,"09_spatial_interval_observed_gaps_LOCAL.csv"),
 row.names=FALSE)
writeLines(c(paste0("source_snapshot=",root),
 "source=curated frozen Supabase read-only evidence; NOT a fit-ready data freeze",
 "spatial_candidate=finite XY + location_type SETT + sett_id + SETT_POINT_PROVISIONAL only",
 "candidate means provisional, NOT independently verified and NOT automatically approved",
 "fail_closed=coordinate conflict, association, unresolved, unset sett ID, shared/multiple sett XY",
 "all other eligible live encounters retained as dated evidence",
 "date grain=each source capture_id retained; tattoo-date counts for audit only",
 "movement support=observed consecutive years; spatial paired years shown separately",
 "positive capture does not verify monitoring of any other detector",
 "source PM/companion roles reported separately, not fitted as live trapping",
 "legacy detector comparison is XY equality screen only; cannot establish provenance",
 "event-level CSVs contain scientific identifiers: KEEP LOCAL, DO NOT COMMIT",
 "no automatic aliases, invented sett coordinates, social groups or trap effort",
 "no database writes, no NIMBLE refits, no imputed locations"),
 file.path(output,"README_ASSUMPTIONS.txt"))
cat("\n=== HIGH-CONFIDENCE SPATIAL INPUT ELIGIBILITY SCREEN ===\n")
print(headline,row.names=FALSE)
cat("\n=== BY LOCATION CATEGORY ===\n");print(category,row.names=FALSE)
cat("\n=== RECENT YEARS ===\n");print(tail(annual,10),row.names=FALSE)
cat("\nOutput: ",output,"\n",sep="")
cat("REVIEW: SETT_POINT_PROVISIONAL is candidate evidence, NOT verified input.\n")
cat("Unlocated encounters remain dated evidence; no database or fit changed.\n")
