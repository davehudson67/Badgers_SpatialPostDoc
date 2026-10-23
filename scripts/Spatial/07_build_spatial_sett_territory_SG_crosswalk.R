#!/usr/bin/env Rscript
# Woodchester annual spatial sett -> polygon -> recorded social-group audit
# Geometry is evidence of spatial association, NOT automatic SG identity.
# Source shapefiles, sett files and capture database remain unchanged.
suppressPackageStartupMessages({
  library(sf); library(dplyr); library(readr); library(stringr); library(tidyr); library(purrr)
})
sett_file <- Sys.getenv('SETT_FILE', 'data/WoodchesterSettLocations.csv')
enc_file <- Sys.getenv('ENCOUNTER_FILE', 'data/badger_encounters_useful.rds')
territory_file <- Sys.getenv('TERRITORY_FILE', 'outputs/social_group_boundary_audit/annual_territories.gpkg')
out <- Sys.getenv('OUTPUT_DIR', 'outputs/spatial_sett_territory_SG_crosswalk')
dir.create(out, recursive=TRUE, showWarnings=FALSE)
for (p in c(sett_file,enc_file,territory_file)) if (!file.exists(p)) stop('Missing input: ', p)

key <- function(x) {
  x <- toupper(str_squish(as.character(x)))
  x[is.na(x) | x %in% c('','NA','N/A','UNKNOWN','UNK','NOT KNOWN')] <- NA_character_
  z <- str_replace_all(x, '[^A-Z0-9]', '')
  z[!nzchar(z)] <- NA_character_
  z
}
pick <- function(tbl,candidates,what) {
  z <- intersect(candidates,names(tbl))
  if (!length(z)) stop('Cannot identify ',what,'. Available columns: ',paste(names(tbl),collapse=', '))
  z[[1]]
}
# The master sett-location file is the authoritative location source.
raw <- read_csv(sett_file,show_col_types=FALSE)
nm <- pick(raw,c('Sett_Clean','Sett','sett','SettName','Sett_Upper','Name'),'sett name')
xc <- pick(raw,c('SettX','sett_x','X','x','Easting','easting'),'sett easting')
yc <- pick(raw,c('SettY','sett_y','Y','y','Northing','northing'),'sett northing')
setts_all <- raw %>% transmute(sett_original=as.character(.data[[nm]]),
  sett_key=key(sett_original),x=suppressWarnings(as.numeric(.data[[xc]])),
  y=suppressWarnings(as.numeric(.data[[yc]]))) %>%
  filter(!is.na(sett_key),is.finite(x),is.finite(y)) %>% distinct()
# Do not silently select one location if a normalised name maps to several coordinates.
conflicts <- setts_all %>% distinct(sett_key,x,y) %>% count(sett_key,name='n_distinct_coordinates') %>% filter(n_distinct_coordinates>1)
write_csv(left_join(conflicts,setts_all,by='sett_key'),file.path(out,'00_duplicate_sett_keys_REVIEW.csv'))
if (nrow(conflicts)) stop(nrow(conflicts),' cleaned sett keys map to multiple coordinate pairs. Review 00_duplicate_sett_keys_REVIEW.csv and resolve before proceeding.')
setts_all <- setts_all %>% group_by(sett_key,x,y) %>% summarise(sett_original=paste(sort(unique(sett_original)),collapse=' | '),.groups='drop')
setts <- st_as_sf(setts_all,coords=c('x','y'),crs=27700,remove=FALSE)

polys <- st_read(territory_file,quiet=TRUE)
if (is.na(st_crs(polys))) stop('Combined polygon GeoPackage has no CRS')
polys <- st_transform(polys,27700)
need <- c('year','polygon_id','territory_name')
if (!all(need %in% names(polys))) stop('Missing fields in polygon GeoPackage: ',paste(setdiff(need,names(polys)),collapse=', '))
polys <- polys %>% mutate(year=as.integer(year),polygon_id=as.integer(polygon_id),
  polygon_key=key(territory_name),source_polygon_id=paste(year,polygon_id,sep=':'))
if (anyDuplicated(polys$source_polygon_id)) stop('Non-unique year:polygon_id; cannot proceed')
if (!all(st_is_valid(polys))) stop('Invalid geometry in annual_territories.gpkg; rerun boundary audit')

# Live capture evidence is separate from geography.
enc <- as_tibble(readRDS(enc_file))
sett_col <- pick(enc,c('recorded_sett_name','sett','normalized_sett_name','Sett'),'capture sett field')
sg_col <- pick(enc,c('recorded_social_group_name','socg','social_group','normalized_social_group_name'),'capture SG field')
if (!all(c('primary_year','has_live_capture') %in% names(enc))) stop('Encounter file missing primary_year or has_live_capture')
cap <- enc %>% transmute(year=as.integer(primary_year),live=as.logical(has_live_capture),
  sett_original=as.character(.data[[sett_col]]),sg_original=as.character(.data[[sg_col]])) %>%
  filter(live %in% TRUE,!is.na(year)) %>%
  mutate(sett_key=key(sett_original),sg_key=key(sg_original)) %>%
  filter(!is.na(sett_key),!is.na(sg_key),!sg_key %in% c('CHESTNUT','HOLLOWTREE'))
evidence <- cap %>% count(year,sett_key,sg_key,name='n_captures') %>%
  group_by(year,sett_key) %>% mutate(n_captures_at_sett_year=sum(n_captures),
      sg_share=n_captures/n_captures_at_sett_year,n_observed_SGs=n()) %>% ungroup()
write_csv(evidence,file.path(out,'01_capture_sett_SG_year_evidence.csv'))

# st_intersects INCLUDES the boundary: conservatively flag boundary-touching points.
# All polygon matches are preserved, never reduced to a first match.
years <- sort(unique(polys$year))
message('Mapping ',nrow(setts),' master setts against ',length(years),' annual polygon maps ...')
spatial <- map_dfr(years,function(yr) {
  py <- polys %>% filter(year==yr)
  hits <- st_intersects(setts,py)
  tibble(sett_key=rep(setts$sett_key,lengths(hits)),
         sett_original=rep(setts$sett_original,lengths(hits)),
         x=rep(setts$x,lengths(hits)),y=rep(setts$y,lengths(hits)),
         polygon_row_index=unlist(hits,use.names=FALSE)) %>%
    mutate(year=yr,polygon_id=py$polygon_id[polygon_row_index],
      source_polygon_id=py$source_polygon_id[polygon_row_index],
      polygon_name=py$territory_name[polygon_row_index],
      polygon_key=py$polygon_key[polygon_row_index]) %>%
    select(year,sett_key,sett_original,x,y,source_polygon_id,polygon_id,polygon_name,polygon_key)
})
# Data for all sett-years, including those with zero polygon hits.
all_sett_years <- tidyr::expand_grid(year=years,st_drop_geometry(setts) %>% select(sett_key,sett_original,x,y))
status <- all_sett_years %>% left_join(spatial %>% count(year,sett_key,name='n_polygon_matches'),by=c('year','sett_key')) %>%
 mutate(n_polygon_matches=coalesce(n_polygon_matches,0L),
 spatial_status=case_when(n_polygon_matches==0~'OUTSIDE_ALL',n_polygon_matches==1~'ONE_POLYGON',TRUE~'MULTIPLE_POLYGONS'))
write_csv(status,file.path(out,'02_all_sett_year_spatial_status.csv'))
write_csv(spatial,file.path(out,'03_sett_polygon_spatial_matches.csv'))

# Compare each plausible polygon with all capture-derived SG possibilities.
joined <- spatial %>% left_join(evidence,by=c('year','sett_key'),relationship='many-to-many') %>%
 mutate(evidence_status=case_when(
   is.na(sg_key)~'NO_CAPTURE_SG_EVIDENCE',
   TRUE~'CAPTURE_SG_CANDIDATE'),
   polygon_name_equals_capture_SG=!is.na(polygon_key)&!is.na(sg_key)&polygon_key==sg_key,
   # Neither an exact label nor a spatial match alone establishes formal group identity.
   approved_group_identity=FALSE) %>%
 left_join(status %>% select(year,sett_key,n_polygon_matches,spatial_status),by=c('year','sett_key'))
write_csv(joined,file.path(out,'04_spatial_sett_polygon_capture_SG_candidates.csv'))

# For each polygon, examine all contained setts and recorded groups. Raw counts are
# capture-frequency evidence, not independent individuals or proof of residency.
poly_groups <- joined %>% filter(!is.na(sg_key)) %>%
 group_by(year,source_polygon_id,polygon_name,sg_key) %>%
 summarise(n_setts_supporting_SG=n_distinct(sett_key),
   summed_capture_records=sum(n_captures,na.rm=TRUE),
   supporting_setts=paste(sort(unique(sett_original)),collapse=' | '),.groups='drop')
write_csv(poly_groups,file.path(out,'05_polygon_candidate_SGs.csv'))
poly_summary <- st_drop_geometry(polys) %>% select(year,polygon_id,source_polygon_id,territory_name,polygon_key) %>%
 left_join(spatial %>% group_by(year,source_polygon_id) %>% summarise(n_setts_inside=n_distinct(sett_key),
    contained_setts=paste(sort(unique(sett_original)),collapse=' | '),.groups='drop'),by=c('year','source_polygon_id')) %>%
 left_join(poly_groups %>% group_by(year,source_polygon_id) %>% summarise(n_candidate_SGs=n_distinct(sg_key),
    candidate_SGs=paste(sort(unique(sg_key)),collapse=' | '),.groups='drop'),by=c('year','source_polygon_id')) %>%
 mutate(n_setts_inside=coalesce(n_setts_inside,0L),n_candidate_SGs=coalesce(n_candidate_SGs,0L),
   review_status=case_when(n_setts_inside==0~'NO_SETT_WITHIN_POLYGON',
      n_candidate_SGs==0~'NO_CAPTURE_SG_EVIDENCE',
      n_candidate_SGs>1~'MULTIPLE_RECORDED_SGS',TRUE~'SINGLE_CAPTURE_SG_CANDIDATE')) %>%
 arrange(year,polygon_id)
write_csv(poly_summary,file.path(out,'06_polygon_level_review.csv'))

# Identify same sett captured under multiple polygon territories in a given year,
# as well as overlapping polygon assignments for master setts without captures.
overlap <- joined %>% filter(n_polygon_matches>1) %>%
 arrange(year,sett_key,source_polygon_id,desc(n_captures))
write_csv(overlap,file.path(out,'07_overlapping_setts_detailed_review.csv'))
annual <- status %>% group_by(year) %>% summarise(n_master_setts=n(),
 n_one_polygon=sum(n_polygon_matches==1),n_multiple_polygons=sum(n_polygon_matches>1),
 n_outside=sum(n_polygon_matches==0),.groups='drop') %>%
 left_join(poly_summary %>% count(year,review_status,name='n_polygons') %>%
 pivot_wider(names_from=review_status,values_from=n_polygons,values_fill=0),by='year')
write_csv(annual,file.path(out,'08_annual_coverage_and_ambiguity.csv'))
review <- poly_summary %>% mutate(decision='PENDING',approved_SG='',relation='UNKNOWN',
 reviewed_by='',review_date='',documentary_evidence='',notes='')
write_csv(review,file.path(out,'09_field_team_review_template.csv'))
cat('\nCOMPLETE. Outputs: ',out,'\n',sep='')
print(status %>% count(spatial_status,name='n_sett_years'))
cat('Capture sett field: ',sett_col,'; recorded SG field: ',sg_col,'\n',sep='')
cat('No automatic group assignments have been approved.\n')
