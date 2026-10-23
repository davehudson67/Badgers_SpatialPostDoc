#!/usr/bin/env Rscript
# 08: Annual observed-sett / territory / SG validation.
# Spatial inclusion is not a claim of social-group identity. No raw files changed.
suppressPackageStartupMessages({
 library(dplyr); library(readr); library(tidyr); library(stringr); library(purrr)
})
root <- Sys.getenv("CROSSWALK_DIR","outputs/spatial_sett_territory_SG_crosswalk")
out <- Sys.getenv("OUTPUT_DIR","outputs/active_sett_territory_validation")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
req <- c("01_capture_sett_SG_year_evidence.csv",
 "02_all_sett_year_spatial_status.csv",
 "03_sett_polygon_spatial_matches.csv",
 "04_spatial_sett_polygon_capture_SG_candidates.csv",
 "06_polygon_level_review.csv")
for(p in req) if(!file.exists(file.path(root,p))) stop("Missing ",file.path(root,p))
read <- function(p) read_csv(file.path(root,p),show_col_types=FALSE)
ev <- read(req[1])
status <- read(req[2])
matches <- read(req[3])
poly <- read(req[5])
stopifnot(all(c("year","sett_key","sg_key","n_captures","sg_share") %in% names(ev)))
stopifnot(all(c("year","sett_key","n_polygon_matches") %in% names(status)))
stopifnot(all(c("year","sett_key","source_polygon_id","polygon_key") %in% names(matches)))
# Observed is deliberately defined as 'live captured at this sett this year'.
# This is a minimum observation-based set of active setts, not a complete occupancy census.
observed <- ev %>% group_by(year,sett_key) %>%
 summarise(n_capture_records=sum(n_captures),n_recorded_sgs=n_distinct(sg_key),
 modal_share=max(sg_share),n_modal=sum(abs(sg_share-max(sg_share))<1e-9),
 modal_sg=if(n_modal==1) sg_key[which.max(sg_share)] else NA_character_,
 recorded_sgs=paste(sort(unique(sg_key)),collapse=" | "),.groups="drop")
# Restrict to annual territory map coverage, not capture-only years (1976/2026).
map_years <- sort(unique(status$year))
observed <- observed %>% filter(year %in% map_years)
observed <- observed %>% left_join(
 status %>% select(year,sett_key,n_polygon_matches,spatial_status),
 by=c("year","sett_key")) %>%
 mutate(n_polygon_matches=coalesce(n_polygon_matches,0L),
 spatial_status=coalesce(spatial_status,"NO_MASTER_COORDINATE"))
write_csv(observed,file.path(out,"01_observed_live_capture_sett_years.csv"))
# A sett may have zero, one, or multiple polygons. Keep all matches.
observed_polys <- observed %>% left_join(matches,by=c("year","sett_key"),relationship="many-to-many")
write_csv(observed_polys,file.path(out,"02_observed_sett_polygon_links.csv"))
# Polygons can contain multiple observed setts with different SGs; avoid assuming
# that all contained setts or their captured animals belong to a single SG.
candidate <- observed_polys %>% filter(!is.na(source_polygon_id)) %>%
 left_join(ev %>% select(year,sett_key,sg_key,n_captures,sg_share),
 by=c("year","sett_key"),relationship="many-to-many") %>%
 group_by(year,source_polygon_id,polygon_name,sg_key) %>%
 summarise(n_observed_setts=n_distinct(sett_key),
 n_capture_records=sum(n_captures,na.rm=TRUE),
 supporting_setts=paste(sort(unique(sett_key)),collapse=" | "),
 .groups="drop")
write_csv(candidate,file.path(out,"03_polygon_candidate_SGs_observed_only.csv"))
polygon_report <- poly %>% select(year,source_polygon_id,territory_name) %>%
 left_join(observed_polys %>% filter(!is.na(source_polygon_id)) %>%
 group_by(year,source_polygon_id) %>%
 summarise(n_observed_setts=n_distinct(sett_key),
 n_ambiguous_setts=n_distinct(sett_key[n_polygon_matches>1]),
 n_observed_setts_with_mixed_sg=n_distinct(sett_key[n_recorded_sgs>1]),
 .groups="drop"),by=c("year","source_polygon_id")) %>%
 left_join(candidate %>% group_by(year,source_polygon_id) %>%
 summarise(n_candidate_sgs=n_distinct(sg_key),
 candidate_sgs=paste(sort(unique(sg_key)),collapse=" | "),
 .groups="drop"),by=c("year","source_polygon_id")) %>%
 mutate(across(c(n_observed_setts,n_ambiguous_setts,
 n_observed_setts_with_mixed_sg,n_candidate_sgs),~coalesce(.x,0L)),
 review_class=case_when(n_observed_setts==0~"NO_OBSERVED_SETT",
 n_candidate_sgs>1~"COMPETING_GROUP_EVIDENCE",
 n_ambiguous_setts>0~"OVERLAPPING_SETT_LOCATION",
 TRUE~"ONE_CANDIDATE_SG")) %>% arrange(year,source_polygon_id)
write_csv(polygon_report,file.path(out,"04_polygon_observed_evidence_review.csv"))
annual <- observed %>% group_by(year) %>%
 summarise(n_setts_observed=n(),n_capture_records=sum(n_capture_records),
 n_setts_outside=sum(spatial_status=="OUTSIDE_ALL"),
 n_setts_in_one=sum(n_polygon_matches==1),
 n_setts_in_multiple=sum(n_polygon_matches>1),
 n_setts_with_competing_recorded_SGs=sum(n_recorded_sgs>1),
 n_without_master_coordinate=sum(spatial_status=="NO_MASTER_COORDINATE"),
 .groups="drop") %>%
 left_join(polygon_report %>% group_by(year) %>% summarise(
 n_polygons=n(),n_polygons_without_observed_sett=sum(n_observed_setts==0),
 n_polygons_with_competing_groups=sum(n_candidate_sgs>1),.groups="drop"),by="year")
write_csv(annual,file.path(out,"05_annual_active_sett_coverage.csv"))
# Name concordance is secondary; per-sett spatial evidence takes precedence.
review <- polygon_report %>% filter(review_class!="ONE_CANDIDATE_SG") %>%
 mutate(field_team_decision="PENDING",approved_SG="",reason="",
 reviewer="",date_checked="",evidence_reference="")
write_csv(review,file.path(out,"06_field_team_priority_review.csv"))
# Resident assignment is kept distinct: these are capture-history derived,
# never inferred from a polygon match.
resfile <- "results/annual_resident_social_group_vicente.csv"
if(file.exists(resfile)) {
 resident <- read_csv(resfile,show_col_types=FALSE)
 write_csv(resident %>% count(assignment_criterion,resident_group_resolved,name="n_badger_years"),
  file.path(out,"07_Vicente_resident_assignment_criteria.csv"))
}
message("Completed: ",out)
print(annual %>% select(year,n_setts_observed,n_setts_in_one,
 n_setts_in_multiple,n_setts_outside,n_polygons_with_competing_groups),n=Inf)
message("No polygon-to-SG identities automatically approved.")
