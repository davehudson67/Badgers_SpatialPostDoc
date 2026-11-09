#!/usr/bin/env Rscript
# V12 exploratory, READ ONLY. Does not fit detection or immigration rates.
# Uses an explicitly selected Supabase-derived immutable snapshot, NEVER historical
# V11R2 RDS as the source of scientific observations.
# Usage: V12_SNAPSHOT=data/model_snapshots/v12_... Rscript <this script>
# Optional V12_AUDIT_OUT new directory; outputs aggregate summaries only.
snapshot <- Sys.getenv("V12_SNAPSHOT","")
if(!nzchar(snapshot)) stop("Set V12_SNAPSHOT to an approved Supabase snapshot path")
manifest <- file.path(snapshot,"MANIFEST.txt")
path <- file.path(snapshot,"qualifying_live.rds")
if(!file.exists(manifest)||!file.exists(path))
 stop("Missing manifest or qualifying live data: ",snapshot)
meta <- readLines(manifest,warn=FALSE)
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",meta)))
 stop("Not a recognised curated Supabase encounter snapshot")
x <- readRDS(path)
need <- c("tattoo","capture_date","capture_id","location_easting",
          "location_northing","location_quality","encounter_type")
if(!all(need %in% names(x)))
 stop("Missing expected snapshot fields: ",paste(setdiff(need,names(x)),collapse=", "))
stopifnot(!anyDuplicated(x$capture_id))
x$tattoo <- toupper(trimws(as.character(x$tattoo)))
x$capture_date <- as.Date(x$capture_date)
x$year <- as.integer(format(x$capture_date,"%Y"))
x$quarter <- (as.integer(format(x$capture_date,"%m"))-1L)%/%3L+1L
if(anyNA(x$tattoo)||any(!nzchar(x$tattoo))||anyNA(x$capture_date))
 stop("Missing tattoo/date; audit before proceeding")
x <- x[!is.na(x$year) & x$year<=2025,,drop=FALSE]
if(!nrow(x)) stop("No eligible observations")
# Avoid double counting multiple rows or setts on the same date as distinct
# capture days. Retain the original per-event coordinates for spatial audit.
days <- unique(x[,c("tattoo","capture_date","year","quarter")])
days <- days[order(days$tattoo,days$capture_date),,drop=FALSE]
first_dates <- tapply(days$capture_date,days$tattoo,function(z) min(as.Date(z)))
# tapply may strip Date; work with character keys instead.
first_numeric <- tapply(as.numeric(days$capture_date),days$tattoo,min)
days$first_observed_day <- as.numeric(days$capture_date)==
                          unname(first_numeric[days$tattoo])
days$previously_seen <- !days$first_observed_day
days$first_observed_year <- as.integer(format(as.Date(
                          first_numeric[days$tattoo],origin="1970-01-01"),"%Y"))
# First observed is conditional on dataset start, NOT biological recruitment.
annual <- do.call(rbind,lapply(split(days,days$year),function(d) {
 data.frame(year=d$year[1],n_distinct_badgers=length(unique(d$tattoo)),
   n_capture_days=nrow(d),
   n_first_observed_days=sum(d$first_observed_day),
   n_repeat_capture_days=sum(d$previously_seen),
   n_first_observed_badgers=length(unique(d$tattoo[d$first_observed_day])),
   n_previously_seen_badgers=length(unique(d$tattoo[d$previously_seen])))
}))
quarterly <- do.call(rbind,lapply(split(days,interaction(days$year,days$quarter,
                                            drop=TRUE)),function(d) {
 data.frame(year=d$year[1],quarter=d$quarter[1],
  observed_badgers=length(unique(d$tattoo)),n_capture_days=nrow(d),
  first_observed_days=sum(d$first_observed_day),
  repeat_capture_days=sum(d$previously_seen))
}))
# Observed return next year, conditional on detection in this year; NOT a survival
# or capture probability. Last year excluded because it lacks full follow up.
oy <- unique(days[,c("tattoo","year")])
oy <- oy[order(oy$tattoo,oy$year),,drop=FALSE]
oy <- oy[oy$year<2025,,drop=FALSE]
observed_set <- unique(paste(days$tattoo,days$year,sep="|"))
oy$next_year_detected <- paste(oy$tattoo,oy$year+1L,sep="|") %in% observed_set
ret <- do.call(rbind,lapply(split(oy,oy$year),function(d)
 data.frame(year=d$year[1],n_observed_badgers=nrow(d),
     n_detected_next_year=sum(d$next_year_detected),
     observed_next_year_fraction=mean(d$next_year_detected))))
x$has_xy <- is.finite(suppressWarnings(as.numeric(x$location_easting))) &
             is.finite(suppressWarnings(as.numeric(x$location_northing)))
# Spatial footprint checks are indexed by year/quarter and recorded spatial
# provenance: no arbitrary core boundary is invented.
spatial <- do.call(rbind,lapply(split(x,interaction(x$year,x$quarter,drop=TRUE)),
 function(d) data.frame(year=d$year[1],quarter=d$quarter[1],
   n_source_rows=nrow(d),n_with_accepted_xy=sum(d$has_xy),
   n_without_xy=sum(!d$has_xy),
   n_distinct_xy=length(unique(paste(d$location_easting[d$has_xy],
                                     d$location_northing[d$has_xy],sep="|"))),
   n_unique_tattoos=length(unique(d$tattoo)))))
quality <- as.data.frame(table(year=x$year,quality=ifelse(
 is.na(x$location_quality),"UNKNOWN",as.character(x$location_quality))),
 stringsAsFactors=FALSE)
quality <- quality[quality$Freq>0,,drop=FALSE]
# The following temporal observations CANNOT substitute for historical trap
# deployment, trap checks, zero captures, detector effort or all badgers present.
cat("Snapshot:",snapshot,"\n")
cat("Source rows:",nrow(x),"capture-days:",nrow(days),
    "observed tattoos:",length(unique(days$tattoo)),"\n")
cat("=== Latest annual observed counts ===\n")
print(tail(annual,12),row.names=FALSE)
cat("=== Observed return following year (not survival) ===\n")
print(tail(ret,12),row.names=FALSE)
out <- Sys.getenv("V12_AUDIT_OUT","")
if(!nzchar(out))
 out <- file.path("outputs","v12_zone_firstrecapture_audit",
      paste0("audit_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out)) stop("Refusing to overwrite output directory: ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(annual,file.path(out,"01_annual_observed_first_repeat.csv"),row.names=FALSE)
write.csv(quarterly,file.path(out,"02_quarterly_observed_first_repeat.csv"),row.names=FALSE)
write.csv(ret,file.path(out,"03_conditional_observed_next_year.csv"),row.names=FALSE)
write.csv(spatial,file.path(out,"04_annual_quarter_spatial_coverage_proxy.csv"),
          row.names=FALSE)
write.csv(quality,file.path(out,"05_location_quality_by_year.csv"),row.names=FALSE)
writeLines(c(paste0("input_snapshot=",snapshot),
  "observed_first_capture=first date in eligible snapshot, not immigration",
  "repeat_capture=previously observed tattoo, not fitted recapture probability",
  "return_next_year=conditional observed association, not apparent survival",
  "spatial_sites=unique accepted XY observations, not proven effort",
  "zone_boundaries=NOT ASSIGNED: require period-specific effort footprint",
  "density=NOT ESTIMATED",
  "zero_capture_events=NOT AVAILABLE from positive-only encounter data"),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("Saved aggregated audit:",out,"\n")
cat("NO population density, trapping effort or entry/emigration rate estimated.\n")
