#!/usr/bin/env Rscript
# Annual Woodchester sett-point x social-group-polygon crosswalk, 1977–2025.
# Run from repository root with Rscript scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R
# Uses the mapped sett coordinates in Supabase; original 173 undated links are not changed.
# Default: CSV audit only. UPLOAD_ANNUAL_CROSSWALK=1 uploads after coverage checks.
suppressPackageStartupMessages({library(sf);library(DBI);library(dplyr);library(readr);library(tidyr)})
source("scripts/BadgerDatabase.R")
years <- 1977:2025
base <- "data/spatial/social_group_boundaries"
output <- "outputs/V1_annual_sett_polygon_membership"
dir.create(output,recursive=TRUE,showWarnings=FALSE)
con <- badger_db_connect()
on.exit(if (DBI::dbIsValid(con)) DBI::dbDisconnect(con),add=TRUE)
setts <- DBI::dbGetQuery(con,"select sett_id,sett_name,easting,northing,coordinate_source from research.setts order by sett_id")
stopifnot(nrow(setts)==176L,!anyDuplicated(setts$sett_id))
mapped <- setts %>% filter(!is.na(easting),!is.na(northing))
pts <- st_as_sf(mapped,coords=c("easting","northing"),remove=FALSE,crs=27700)
results <- vector("list",length(years))
for(k in seq_along(years)){
 y<-years[k]
 shp<-file.path(base,sprintf("territories_%04d.shp",y))
 if(!file.exists(shp))stop("Missing: ",shp)
 poly<-st_read(shp,quiet=TRUE)
 if(is.na(st_crs(poly))) { warning("Missing polygon CRS, assuming EPSG:27700 as in existing 01 boundary audit: ",shp);st_crs(poly)<-27700 }
 poly<-st_transform(poly,27700)
 name_candidates<-c("SocialName","Sett","SETT","Social_grp")
 name_col<-name_candidates[name_candidates %in% names(poly)][1]
 if(length(name_col)==0L || is.na(name_col))stop("No known territory label field: ",shp,
 "; available: ",paste(names(poly),collapse=","))
 poly$polygon_id<-as.character(seq_len(nrow(poly)))
 if(any(!st_is_valid(poly)))stop("Invalid polygons in ",shp)
 inside<-st_within(pts,poly)
 intersects<-st_intersects(pts,poly)
 rows<-vector("list",nrow(setts))
 for(i in seq_len(nrow(setts))){
  id<-setts$sett_id[i]; pt_i<-match(id,mapped$sett_id)
  if(is.na(pt_i)){
   rows[[i]]<-data.frame(year=y,sett_id=id,polygon_id=NA_character_,
      territory_name=NA_character_,match_status="NO_COORDINATE",
      polygon_source=basename(shp),coordinate_source=NA_character_)
   next
  }
  hit<-intersects[[pt_i]]
  if(length(hit)==0){
   rows[[i]]<-data.frame(year=y,sett_id=id,polygon_id=NA_character_,
      territory_name=NA_character_,match_status="OUTSIDE_ALL",
      polygon_source=basename(shp),coordinate_source=setts$coordinate_source[i])
   next
  }
  # st_within excludes exact boundary points, so flag boundary cases explicitly.
  boundary<-!(hit %in% inside[[pt_i]])
  status <- ifelse(boundary, "ON_BOUNDARY",
                   if (length(hit) > 1L) "MULTIPLE_POLYGONS" else "ONE_POLYGON")
  rows[[i]]<-data.frame(
    year=rep(y,length(hit)),
    sett_id=rep(id,length(hit)),
    polygon_id=poly$polygon_id[hit],
    territory_name=as.character(poly[[name_col]][hit]),
    match_status=status,
    polygon_source=rep(basename(shp),length(hit)),
    coordinate_source=rep(setts$coordinate_source[i],length(hit))
  )
 }
 results[[k]]<-bind_rows(rows)
}
crosswalk<-bind_rows(results)
stopifnot(n_distinct(crosswalk$year)==49L,n_distinct(crosswalk$sett_id)==176L,
 nrow(crosswalk)>=49L*176L,all(!is.na(crosswalk$match_status)),
 all(crosswalk$year %in% years))
write_csv(crosswalk,file.path(output,"annual_sett_polygon_all_matches.csv"),na="")
summary<-dplyr::count(crosswalk,year,match_status,name="n_records")
write_csv(summary,file.path(output,"annual_sett_polygon_year_status.csv"))
print(as.data.frame(summary), row.names=FALSE)
message("Exported ",nrow(crosswalk)," rows to ",output)
if(identical(Sys.getenv("UPLOAD_ANNUAL_CROSSWALK"),"1")){
 # Only write on explicit opt-in; require write-enabled Supabase credentials.
 DBI::dbWithTransaction(con,{
  DBI::dbExecute(con,"delete from research.sett_annual_territory_matches")
  DBI::dbWriteTable(con,DBI::Id(schema="research",table="sett_annual_territory_matches"),
   crosswalk,append=TRUE,row.names=FALSE)
  after<-DBI::dbGetQuery(con,"select count(*) n from research.sett_annual_territory_matches")
  if(after$n!=nrow(crosswalk))stop("Upload row count mismatch; rolling back")
 })
 message("Uploaded and verified ",nrow(crosswalk)," rows")
}
