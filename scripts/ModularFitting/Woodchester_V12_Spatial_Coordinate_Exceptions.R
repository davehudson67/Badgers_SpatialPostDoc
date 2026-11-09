#!/usr/bin/env Rscript
# Read-only final exception check for V12 fixed-sett spatial candidates.
# Uses already-audited local event-level review data. Never sends identifiers
# to GitHub or a database. Exact coordinate equality is not independent proof.
root <- Sys.getenv("V12_ELIGIBILITY_DIR","")
zone <- Sys.getenv("ZONE_AUDIT_DIR","")
if(!nzchar(root)||!nzchar(zone))stop("Set V12_ELIGIBILITY_DIR and ZONE_AUDIT_DIR")
source <- file.path(root,"08_EVENT_LEVEL_LOCAL_REVIEW_DO_NOT_COMMIT.csv")
refpath <- file.path(zone,"01_detector_geometry_reference.csv")
if(!file.exists(source)||!file.exists(refpath))stop("Missing required audit CSVs")
d <- read.csv(source,stringsAsFactors=FALSE)
r <- read.csv(refpath,stringsAsFactors=FALSE)
req <- c("capture_id","tattoo","capture_date","sett_id",
 "location_type","location_quality","location_easting","location_northing",
 "spatial_candidate")
if(!all(req%in%names(d)))stop("Event review table missing fields")
if(!all(c("detector","sett","x","y")%in%names(r)))stop("Detector reference missing fields")
d <- d[!is.na(d$spatial_candidate)&d$spatial_candidate,,drop=FALSE]
if(!nrow(d))stop("No candidate spatial records")
x <- suppressWarnings(as.numeric(d$location_easting))
y <- suppressWarnings(as.numeric(d$location_northing))
if(any(!is.finite(x))||any(!is.finite(y)))stop("Non-finite candidate XY")
best <- integer(nrow(d)); distance <- numeric(nrow(d))
for(i in seq_len(nrow(d))) {
 dsq <- (r$x-x[i])^2+(r$y-y[i])^2
 best[i] <- which.min(dsq)
 distance[i] <- sqrt(dsq[best[i]])
}
# Use strictly identical numeric coordinate values, as in original audit.
nonexact <- which(distance>0)
cat("Total candidate source records:",nrow(d),"\n")
cat("Exact matches:",sum(distance==0),"\n")
cat("Non-exact matches:",length(nonexact),"\n")
cat("More than 100 m from legacy reference:",sum(distance>100),"\n")
if(length(nonexact)) {
 z <- d[nonexact,req[req!="spatial_candidate"],drop=FALSE]
 z$legacy_nearest_detector <- r$detector[best[nonexact]]
 z$legacy_nearest_sett <- r$sett[best[nonexact]]
 z$distance_m <- round(distance[nonexact],3)
 z$legacy_x <- r$x[best[nonexact]]
 z$legacy_y <- r$y[best[nonexact]]
 cat("\n=== LOCAL SCIENTIFIC RECORDS NEEDING REVIEW ===\n")
 print(z,row.names=FALSE)
}
cat("\nNo identity reassignment, coordinate correction, or fit eligibility changed.\n")
