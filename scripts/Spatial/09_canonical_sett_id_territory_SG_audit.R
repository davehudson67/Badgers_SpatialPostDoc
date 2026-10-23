#!/usr/bin/env Rscript
# 09: Canonical-ID based historical sett -> territory -> SG crosswalk.
# Prerequisite: DATABASE_URL (read-only Postgres connection URI), plus
# the geometry and coordinate files already used in script 07.
# No SQL writes, and no modifications to primary data.
suppressPackageStartupMessages({
 library(DBI); library(RPostgres); library(sf)
 library(dplyr); library(tidyr); library(readr); library(stringr); library(purrr)
})
snapshot_dir <- Sys.getenv("SUPABASE_SNAPSHOT_DIR",file.path("data","local_supabase_snapshots"))
root <- Sys.getenv("PROJECT_ROOT",".")
coord_path <- Sys.getenv("SETT_FILE",file.path(root,"data/WoodchesterSettLocations.csv"))
gpkg <- Sys.getenv("TERRITORY_FILE",file.path(root,"outputs/social_group_boundary_audit/annual_territories.gpkg"))
out <- Sys.getenv("OUTPUT_DIR",file.path(root,"outputs/canonical_sett_SG_territory_crosswalk"))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(p in c(coord_path,gpkg)) if (!file.exists(p)) stop("Missing spatial source: ",p)
clean <- function(z) {
 z <- toupper(trimws(as.character(z)))
 z <- gsub("[^A-Z0-9]","",z)
 z[!nzchar(z)|is.na(z)] <- NA_character_
 z
}
load_snapshot <- function(file,required) {
 path <- file.path(snapshot_dir,file)
 if(!file.exists(path)) stop("Missing snapshot ",path,
   ". See docs/database/ANNUAL_SETT_TERRITORY_CROSSWALK.md")
 x <- read_csv(path,show_col_types=FALSE)
 if(!all(required %in% names(x))) stop("Snapshot ",path,
  " missing columns: ",paste(setdiff(required,names(x)),collapse=", "))
 x
}
canonical <- load_snapshot("setts.csv",c("sett_id","sett_name","notes"))
groups <- load_snapshot("groups.csv",c("social_group_id","social_group_name"))
history <- load_snapshot("history.csv",c("sett_id","social_group_id","valid_from","valid_to","notes"))
agg <- load_snapshot("captures_annual_aggregate.csv",
 c("year","sett_id","recorded_social_group_id","n_captures")) %>%
 filter(year>=1977,year<=2025)
# Snapshot contains aggregated non-PM capture counts by year, sett_id and recorded SG ID.
# NULL social-group IDs are valid: they contribute to observed sett activity.
captures <- agg %>% left_join(groups,by=c("recorded_social_group_id"="social_group_id")) %>%
 transmute(year=as.integer(year),sett_id=as.integer(sett_id),
  recorded_social_group_id=as.integer(recorded_social_group_id),
  captured_sg=social_group_name,n_captures=as.integer(n_captures))
if(anyNA(canonical$sett_id)||anyDuplicated(canonical$sett_id)) stop("Canonical sett_id missing/duplicated")
if(anyDuplicated(groups$social_group_id)) stop("Social group IDs duplicated")
if(any(is.na(captures$n_captures)|captures$n_captures<1)) stop("Invalid aggregate counts")
if(any(!is.na(captures$sett_id)&!captures$sett_id %in% canonical$sett_id))
 stop("Capture aggregate contains unknown sett IDs")
if(any(!is.na(captures$recorded_social_group_id)&
 !captures$recorded_social_group_id %in% groups$social_group_id))
 stop("Capture aggregate contains unknown group IDs")
write_csv(canonical,file.path(out,"01_canonical_setts.csv"))
# Coordinate source contains historical names, not canonical IDs.
co <- read_csv(coord_path,show_col_types=FALSE)
must <- c("Sett_Upper","SettX","SettY")
if (!all(must %in% names(co))) stop("Expected coordinate columns: ",paste(must,collapse=", "))
co <- co %>% transmute(coordinate_name=Sett_Upper,
 east=suppressWarnings(as.numeric(SettX)),north=suppressWarnings(as.numeric(SettY)),
 name_key=clean(coordinate_name))
canonical <- canonical %>% mutate(name_key=clean(sett_name))
dup_coord <- co %>% filter(!is.na(name_key)) %>% count(name_key) %>% filter(n>1)
dup_can <- canonical %>% filter(!is.na(name_key)) %>% count(name_key) %>% filter(n>1)
write_csv(dup_coord,file.path(out,"02_duplicate_coordinate_keys.csv"))
write_csv(dup_can,file.path(out,"03_duplicate_canonical_keys.csv"))
if(nrow(dup_coord)||nrow(dup_can)) stop("Non-unique cleaned name keys. Review duplicate reports: no uncertain matches permitted.")
joined <- canonical %>% left_join(co,by="name_key") %>%
 mutate(coord_status=case_when(is.na(east)|is.na(north)~"NO_COORDINATE",
 TRUE~"EXACT_NORMALISED_NAME"))
write_csv(joined,file.path(out,"04_canonical_coordinate_match.csv"))
write_csv(co %>% anti_join(canonical,by="name_key"),file.path(out,"05_coordinate_names_not_canonical.csv"))
# Crucially, we NEVER turn an unmatched capture name into a settled ID.
summary <- tibble(
 metric=c("n_canonical_setts","n_canonical_with_coordinates",
 "n_canonical_without_coordinates","n_captures_1977_2025",
 "n_captures_with_sett_id","n_captures_without_sett_id",
 "n_captures_with_sg_id"),
 value=c(nrow(canonical),sum(joined$coord_status=="EXACT_NORMALISED_NAME"),
 sum(joined$coord_status=="NO_COORDINATE"),sum(captures$n_captures),
 sum(captures$n_captures[!is.na(captures$sett_id)]),NA_integer_,
 sum(captures$n_captures[!is.na(captures$recorded_social_group_id)])))
write_csv(summary,file.path(out,"00_source_audit_summary.csv"))
# The local annual aggregate includes only canonical-ID-linked captures.
# Missing/unresolved capture locations are NOT represented in this snapshot.
write_csv(tibble(metric="unresolved_capture_locations",status="NOT_IN_SNAPSHOT"),
 file.path(out,"06_unresolved_capture_sett_names.csv"))
evidence <- captures %>% filter(!is.na(sett_id),!is.na(recorded_social_group_id)) %>%
 group_by(year,sett_id) %>% mutate(total_captures=sum(n_captures),
 proportion=n_captures/total_captures,n_observed_sgs=n()) %>% ungroup()
write_csv(evidence,file.path(out,"07_canonical_capture_SG_evidence.csv"))
# Keep dated historically documented relations separate from observed capture groups.
write_csv(history,file.path(out,"08_documented_sett_SG_history.csv"))
polys <- st_read(gpkg,quiet=TRUE)
if(is.na(st_crs(polys))) stop("Territory CRS missing")
polys <- st_transform(polys,27700)
need <- c("year","polygon_id","territory_name")
if(!all(need %in% names(polys))) stop("Polygon fields missing: ",paste(setdiff(need,names(polys)),collapse=","))
polys <- polys %>% mutate(year=as.integer(year),
 polygon_uid=paste(year,polygon_id,sep=":"))
if(anyDuplicated(polys$polygon_uid)) stop("Duplicate year:polygon_id; cannot audit reliably")
setts <- joined %>% filter(coord_status=="EXACT_NORMALISED_NAME") %>%
 st_as_sf(coords=c("east","north"),crs=27700,remove=FALSE)
years <- sort(unique(polys$year))
hits <- map_dfr(years,function(y) {
 py <- polys %>% filter(year==y)
 ids <- st_intersects(setts,py)
 idx <- rep(seq_len(nrow(setts)),lengths(ids))
 j <- unlist(ids,use.names=FALSE)
 if(!length(j)) return(tibble(year=integer(),sett_id=integer(),polygon_uid=character(),polygon_name=character()))
 tibble(year=y,sett_id=setts$sett_id[idx],
 polygon_uid=py$polygon_uid[j],polygon_name=as.character(py$territory_name[j]))
})
write_csv(hits,file.path(out,"09_sett_polygon_all_matches.csv"))
all_years <- crossing(year=years,joined %>% select(sett_id,sett_name,coord_status))
status <- all_years %>% left_join(hits %>% count(year,sett_id,name="n_polygons"),
 by=c("year","sett_id")) %>% mutate(n_polygons=coalesce(n_polygons,0L),
 status=case_when(coord_status=="NO_COORDINATE"~"NO_COORDINATE",
 n_polygons==0~"OUTSIDE_ALL",n_polygons==1~"ONE_POLYGON",TRUE~"MULTIPLE_POLYGONS"))
write_csv(status,file.path(out,"10_all_sett_year_status.csv"))
# 'Observed' means captured at least once that year, NOT proof of biological occupancy.
observed <- captures %>% filter(!is.na(sett_id)) %>% distinct(year,sett_id)
obsstatus <- status %>% inner_join(observed,by=c("year","sett_id"))
write_csv(obsstatus,file.path(out,"11_observed_canonical_sett_years.csv"))
candidate <- hits %>% inner_join(observed,by=c("year","sett_id")) %>%
 left_join(evidence,by=c("year","sett_id"),relationship="many-to-many")
write_csv(candidate,file.path(out,"12_observed_polygon_group_candidates.csv"))
pgroup <- candidate %>% filter(!is.na(recorded_social_group_id)) %>%
 group_by(year,polygon_uid,polygon_name,recorded_social_group_id,captured_sg) %>%
 summarise(n_observed_setts=n_distinct(sett_id),
 n_captures=sum(n_captures,na.rm=TRUE),.groups="drop")
write_csv(pgroup,file.path(out,"13_polygon_group_candidate_evidence.csv"))
pdecision <- st_drop_geometry(polys) %>% select(year,polygon_uid,territory_name) %>%
 left_join(pgroup %>% group_by(year,polygon_uid) %>%
 summarise(n_candidate_SGs=n_distinct(recorded_social_group_id),
 candidate_SGs=paste(sort(unique(captured_sg)),collapse=" | "),.groups="drop"),
 by=c("year","polygon_uid")) %>% mutate(n_candidate_SGs=coalesce(n_candidate_SGs,0L),
 review_status=case_when(n_candidate_SGs==0~"NO_CAPTURE_EVIDENCE",
 n_candidate_SGs>1~"COMPETING_GROUPS",TRUE~"SINGLE_UNVERIFIED_CANDIDATE"),
 approved_sg_id=NA_integer_,approval_source="",reviewer="",review_date="",notes="")
write_csv(pdecision,file.path(out,"14_annual_polygon_review_worklist.csv"))
annual <- obsstatus %>% group_by(year) %>%
 summarise(n_observed_setts=n(),n_with_coordinates=sum(status!="NO_COORDINATE"),
 n_one_polygon=sum(status=="ONE_POLYGON"),n_overlap=sum(status=="MULTIPLE_POLYGONS"),
 n_outside=sum(status=="OUTSIDE_ALL"),n_missing_coordinates=sum(status=="NO_COORDINATE"),
 .groups="drop")
write_csv(annual,file.path(out,"15_annual_observed_coverage.csv"))
cat("Completed in ",out,"\n",sep="")
print(summary)
cat("NO social-group memberships or polygon IDs have been automatically approved.\n")
