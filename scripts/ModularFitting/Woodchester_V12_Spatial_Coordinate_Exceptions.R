#!/usr/bin/env Rscript
# Targeted read-only comparison of Supabase-curated fixed-sett locations
# against historical V11R2 detector XY. Reads the frozen original RDS,
# not the earlier local CSV that printed integer64 IDs incorrectly.
# This is a source-reference check, not a correction or fit eligibility approval.
snapshot <- Sys.getenv("V12_SNAPSHOT","")
zone <- Sys.getenv("ZONE_AUDIT_DIR","")
if(!nzchar(snapshot)||!nzchar(zone))
 stop("Set V12_SNAPSHOT and ZONE_AUDIT_DIR")
snapfile <- file.path(snapshot,"qualifying_live.rds")
manifest <- file.path(snapshot,"MANIFEST.txt")
refpath <- file.path(zone,"01_detector_geometry_reference.csv")
if(!all(file.exists(c(snapfile,manifest,refpath))))
 stop("Missing original snapshot or detector reference")
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",
 readLines(manifest,warn=FALSE))))
 stop("Unrecognised snapshot source")
d <- as.data.frame(readRDS(snapfile))
r <- read.csv(refpath,stringsAsFactors=FALSE)
req<-c("capture_id","tattoo","capture_date","sett_id",
 "location_type","location_quality","location_easting","location_northing")
if(!all(req%in%names(d)))stop("Original snapshot missing fields")
if(!all(c("detector","sett","x","y")%in%names(r)))
 stop("Legacy detector reference missing fields")
to_text<-function(x,label) {
 if(inherits(x,"integer64")) {
   if(!requireNamespace("bit64",quietly=TRUE))
      stop("Install bit64 to decode original PostgreSQL BIGINT values")
   return(bit64::as.character.integer64(x))
 }
 if(is.double(x)&&any(is.finite(x)&x!=0&abs(x)<1e-200)) {
   if(!requireNamespace("bit64",quietly=TRUE))
      stop("Install bit64 to re-interpret BIGINT bit-pattern values")
   if(any(is.finite(x)&x!=0&abs(x)>=1e-200))
      stop(label," mixes possible BIGINT bit patterns with regular numbers")
   return(bit64::as.character.integer64(structure(x,class="integer64")))
 }
 if(is.numeric(x)) {
   if(any(is.finite(x)&x!=floor(x)))
      stop(label," contains fractional IDs")
   return(format(x,scientific=FALSE,trim=TRUE))
 }
 as.character(x)
}
# IMPORTANT: convert BIGINT fields BEFORE any subset/data-frame row bind.
d$capture_id<-to_text(d$capture_id,"source capture_id")
d$sett_id<-to_text(d$sett_id,"source sett_id")
d$tattoo<-toupper(trimws(as.character(d$tattoo)))
d$capture_date<-as.Date(d$capture_date)
year<-as.integer(format(d$capture_date,"%Y"))
d<-d[!is.na(year)&year>=1977&year<=2025,,drop=FALSE]
d$location_type<-toupper(trimws(as.character(d$location_type)))
d$location_quality<-toupper(trimws(as.character(d$location_quality)))
x<-suppressWarnings(as.numeric(d$location_easting))
y<-suppressWarnings(as.numeric(d$location_northing))
qualifies<-is.finite(x)&is.finite(y)&
 !is.na(d$location_type)&d$location_type=="SETT"&
 !is.na(d$sett_id)&nzchar(d$sett_id)&
 !is.na(d$location_quality)&d$location_quality=="SETT_POINT_PROVISIONAL"
d<-d[qualifies,,drop=FALSE]
x<-x[qualifies];y<-y[qualifies]
if(nrow(d)!=15521L)
 warning("Expected 15,521 source spatial candidates, found ",nrow(d),
         "; please reconcile input snapshot before accepting exceptions")
if(anyDuplicated(d$capture_id))stop("Duplicate original capture IDs")
best<-integer(nrow(d));distance<-numeric(nrow(d))
for(i in seq_len(nrow(d))) {
 dsq<-(r$x-x[i])^2+(r$y-y[i])^2
 best[i]<-which.min(dsq)
 distance[i]<-sqrt(dsq[best[i]])
}
ix<-which(distance>0)
cat("Original source spatial candidates:",nrow(d),"\n")
cat("Exact matches:",sum(distance==0),"\n")
cat("Non-exact matches:",length(ix),"\n")
cat("More than 100m:",sum(distance>100),"\n")
if(length(ix)) {
 z<-d[ix,req,drop=FALSE]
 z$nearest_legacy_sett<-r$sett[best[ix]]
 z$nearest_legacy_detector<-r$detector[best[ix]]
 z$distance_m<-round(distance[ix],3)
 z$legacy_x<-r$x[best[ix]]
 z$legacy_y<-r$y[best[ix]]
 cat("\n=== AUTHORITATIVE SNAPSHOT IDs AND LOCATIONS ===\n")
 print(z,row.names=FALSE,right=FALSE)
 # The legacy raw encounter data can supply context, but are not an
 # authoritative match because tattoo-date need not uniquely key episodes.
 legacy_path<-"data/badger_encounters_useful.rds"
 if(file.exists(legacy_path)) {
   old<-as.data.frame(readRDS(legacy_path))
   if(all(c("tattoo","capture_date","sett")%in%names(old))) {
     old$tattoo<-toupper(trimws(as.character(old$tattoo)))
     old$capture_date<-as.Date(old$capture_date)
     cat("\n=== ORIGINAL V11R2 SETT-TEXT CANDIDATES (NONUNIQUE MATCH) ===\n")
     for(i in ix) {
       zold<-old[old$tattoo==d$tattoo[i] &
                   !is.na(old$capture_date) &
                   old$capture_date==d$capture_date[i],,drop=FALSE]
       val<-if(nrow(zold))paste(unique(as.character(zold$sett)),
                                collapse="; ") else "NO LEGACY DATE MATCH"
       cat("Capture ",d$capture_id[i], " / ",d$tattoo[i],
           " / ",as.character(d$capture_date[i]),": ",val,"\n",sep="")
     }
   }
 }
}
cat("\nNo source IDs, sett assignments, coordinates, likelihood or fit changed.\n")
