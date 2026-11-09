#!/usr/bin/env Rscript
# V11R2 historical capture footprint comparison: read-only, diagnostic only.
# Historical V11R2 detector XY and approved Supabase frozen capture XY may
# represent different location concepts (sett reference vs physical encounter).
# Spatial proximity is NOT an identity/alias matching rule and doesn't establish
# detector deployment, trap effort or zero-capture periods.
base <- Sys.getenv("ZONE_AUDIT_DIR","")
snap <- Sys.getenv("V12_SNAPSHOT","")
if(!nzchar(base)||!file.exists(file.path(base,"01_detector_geometry_reference.csv")))
 stop("Set ZONE_AUDIT_DIR to the prior V11R2 audit directory")
if(!nzchar(snap)||!file.exists(file.path(snap,"qualifying_live.rds"))||
   !file.exists(file.path(snap,"MANIFEST.txt")))
 stop("Set V12_SNAPSHOT to frozen, curated Supabase evidence")
manifest <- readLines(file.path(snap,"MANIFEST.txt"),warn=FALSE)
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",manifest)))
 stop("Unexpected data snapshot provenance")
det <- read.csv(file.path(base,"01_detector_geometry_reference.csv"),
                stringsAsFactors=FALSE)
raw <- readRDS(file.path(snap,"qualifying_live.rds"))
needed <- c("capture_id","tattoo","capture_date",
            "location_easting","location_northing","location_quality")
if(!all(needed%in%names(raw))) stop("Missing snapshot columns: ",
 paste(setdiff(needed,names(raw)),collapse=", "))
if(anyDuplicated(raw$capture_id)) stop("Duplicated capture IDs in snapshot")
raw$capture_date <- as.Date(raw$capture_date)
raw$year <- as.integer(format(raw$capture_date,"%Y"))
raw$x <- suppressWarnings(as.numeric(raw$location_easting))
raw$y <- suppressWarnings(as.numeric(raw$location_northing))
raw$valid_xy <- is.finite(raw$x)&is.finite(raw$y)
if(anyNA(raw$year)) stop("Missing capture dates")
raw <- raw[raw$year<=2025,,drop=FALSE]
if(!nrow(raw)) stop("Empty eligible snapshot")
# Three approximately equal historical epochs; labels describe capture dates,
# not a claim of consistent effort or a single stable trapping protocol.
periods <- c("1977–1992","1993–2008","2009–2025")
raw$period <- cut(raw$year,breaks=c(1976,1992,2008,2025),
 labels=periods,include.lowest=TRUE)
# 1976 data, if present, is documented separately and not silently assigned.
pre <- sum(raw$year<1977)
raw <- raw[!is.na(raw$period),,drop=FALSE]
coords <- raw[raw$valid_xy,,drop=FALSE]
if(!nrow(coords)) stop("No finite capture XY in selected study period")
if(!all(c("x","y","sett")%in%names(det)))stop("Malformed V11R2 detector reference")
if(any(!is.finite(det$x)|!is.finite(det$y)))stop("Non-finite detector coordinates")
# Compare position of each capture XY to nearest historical detector, without
# treating a near-match as evidence of detector identity.
nearest <- function(x,y,dx,dy) {
 result <- integer(length(x))
 distance <- numeric(length(x))
 for(i in seq_along(x)) {
   dist2 <- (dx-x[i])^2+(dy-y[i])^2
   result[i] <- which.min(dist2)
   distance[i] <- sqrt(min(dist2))
 }
 list(site=result,dist=distance)
}
nearest_obs <- nearest(coords$x,coords$y,det$x,det$y)
coords$nearest_legacy_detector <- nearest_obs$site
coords$nearest_distance_m <- nearest_obs$dist
# For each period, count positive recorded live capture days at each legacy
# detector's surrounding area; 100 m is a diagnostic proximity threshold only.
threshold <- as.numeric(Sys.getenv("ZONE_MATCH_THRESHOLD_M","100"))
if(!is.finite(threshold)||threshold<=0||threshold>500)
 stop("ZONE_MATCH_THRESHOLD_M must be between 0 and 500")
coords$within_threshold <- coords$nearest_distance_m<=threshold
site_rows <- list()
for(p in periods) {
 d <- coords[coords$period==p & coords$within_threshold,,drop=FALSE]
 for(j in seq_len(nrow(det))) {
   q <- d[d$nearest_legacy_detector==j,,drop=FALSE]
   site_rows[[length(site_rows)+1L]] <- data.frame(period=p,
      detector=j,sett=det$sett[j],x=det$x[j],y=det$y[j],
      n_positive_capture_rows=nrow(q),
      n_capture_days=if(nrow(q))nrow(unique(q[,c("tattoo","capture_date")])) else 0L,
      n_distinct_capture_years=length(unique(q$year)),
      first_year=if(nrow(q))min(q$year) else NA_integer_,
      last_year=if(nrow(q))max(q$year) else NA_integer_)
 }
}
site <- do.call(rbind,site_rows)
# Summarise missing coordinate evidence by period; recorded sites do not imply
# that a site was surveyed in unobserved years.
all_period <- do.call(rbind,lapply(periods,function(p) {
 a <- raw[raw$period==p,,drop=FALSE]
 c0 <- coords[coords$period==p,,drop=FALSE]
 data.frame(period=p,
  n_live_source_rows=nrow(a),n_finite_xy=nrow(c0),
  n_missing_xy=nrow(a)-nrow(c0),
  n_near_legacy_detector=sum(c0$within_threshold),
  n_farther_than_threshold=sum(!c0$within_threshold),
  median_nearest_legacy_m=if(nrow(c0))median(c0$nearest_distance_m) else NA_real_,
  p90_nearest_legacy_m=if(nrow(c0))unname(quantile(c0$nearest_distance_m,.9)) else NA_real_,
  n_legacy_sites_with_near_capture=sum(site$n_positive_capture_rows[
       site$period==p] > 0))
}))
quality <- as.data.frame(table(period=raw$period,
  location_quality=ifelse(is.na(raw$location_quality),
                       "UNSPECIFIED",as.character(raw$location_quality))),
 stringsAsFactors=FALSE)
quality <- quality[quality$Freq>0,,drop=FALSE]
out <- Sys.getenv("ZONE_FOOTPRINT_OUT","")
if(!nzchar(out))
 out <- file.path("outputs","v11r2_core_periphery",
  paste0("historical_footprint_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Refusing to overwrite ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(site,file.path(out,"01_legacy_detectors_near_captures_by_period.csv"),row.names=FALSE)
write.csv(all_period,file.path(out,"02_period_capture_coordinate_coverage.csv"),row.names=FALSE)
write.csv(quality,file.path(out,"03_recorded_xy_quality_by_period.csv"),row.names=FALSE)
# Location map: separate periods, equal extent and aspect; plot only capture
# coordinates and existing legacy site coordinates (not every capture label).
png(file.path(out,"04_historical_capture_footprint.png"),width=1700,height=620,res=135)
op <- par(no.readonly=TRUE)
par(mfrow=c(1,3),mar=c(4,4,3,1))
xr <- range(c(det$x,coords$x))
yr <- range(c(det$y,coords$y))
for(p in periods) {
 d <- coords[coords$period==p,,drop=FALSE]
 plot(det$x,det$y,asp=1,xlim=xr,ylim=yr,pch=1,cex=.55,
      xlab="Easting (m)",ylab="Northing (m)",
      main=paste(p,"| recorded capture XY"))
 if(nrow(d)) points(d$x,d$y,pch=16,cex=.32,col=adjustcolor("darkblue",.4))
 points(det$x,det$y,pch=1,cex=.6)
}
par(op);dev.off()
writeLines(c(paste0("snapshot=",snap),paste0("zone_audit=",base),
 paste0("within_nearest_detector_threshold_m=",threshold),
 paste0("excluded_pre_1977_rows=",pre),
 "Compare coordinate evidence only; capture XY and detector reference can represent different concepts.",
 "Proximity does NOT imply source sett identity, trapping at that detector, or a matched alias.",
 "Zero nearby captures in a period does NOT imply zero trap effort.",
 "No stable core, true density, trapping effort, survival or movement parameter estimated.",
 "These spatial comparisons use V11R2 legacy geometry, pending source reconciliation.",
 "XY location_quality categories are reported separately; no automatic confidence threshold."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("=== HISTORICAL COORDINATE FOOTPRINT (NOT TRAP EFFORT) ===\n")
print(all_period,row.names=FALSE)
cat("Output:",out,"\n")
cat("Plot:",file.path(out,"04_historical_capture_footprint.png"),"\n")
