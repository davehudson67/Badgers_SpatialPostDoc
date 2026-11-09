#!/usr/bin/env Rscript
# Read-only annual continuity of POSITIVE CAPTURE RECORDS at fixed legacy setts.
# Uses approved Supabase snapshot capture XY and historical detector coordinates.
# Proximity is a diagnostic association, not validated sett identity or trap effort.
# Never assumes no captures = no trapping. Does not define a final spatial core.
snap <- Sys.getenv("V12_SNAPSHOT","")
zone <- Sys.getenv("ZONE_AUDIT_DIR","")
if(!nzchar(snap)||!file.exists(file.path(snap,"MANIFEST.txt"))||
   !file.exists(file.path(snap,"qualifying_live.rds")))
 stop("Set V12_SNAPSHOT to approved frozen Supabase encounter snapshot")
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",
              readLines(file.path(snap,"MANIFEST.txt"),warn=FALSE))))
 stop("Snapshot source manifest unrecognised")
detfile <- file.path(zone,"01_detector_geometry_reference.csv")
if(!nzchar(zone)||!file.exists(detfile))
 stop("Set ZONE_AUDIT_DIR to existing original zone audit")
det <- read.csv(detfile,stringsAsFactors=FALSE)
req <- c("detector","x","y","sett")
if(!all(req%in%names(det))) stop("Detector reference malformed")
if(anyDuplicated(det$detector)||any(!is.finite(det$x))||any(!is.finite(det$y)))
 stop("Detector reference duplicated or invalid")
x <- readRDS(file.path(snap,"qualifying_live.rds"))
req <- c("tattoo","capture_date","location_easting","location_northing","location_quality")
if(!all(req%in%names(x))) stop("Missing frozen capture fields")
x$capture_date<-as.Date(x$capture_date)
x$year<-as.integer(format(x$capture_date,"%Y"))
x$x<-suppressWarnings(as.numeric(x$location_easting))
x$y<-suppressWarnings(as.numeric(x$location_northing))
x<-x[!is.na(x$year)&x$year>=1977L&x$year<=2025L&
       is.finite(x$x)&is.finite(x$y),,drop=FALSE]
if(!nrow(x))stop("No eligible XY captures")
threshold<-as.numeric(Sys.getenv("ZONE_MATCH_THRESHOLD_M","100"))
if(!is.finite(threshold)||threshold<=0||threshold>500)
 stop("ZONE_MATCH_THRESHOLD_M must be positive <=500")
# Spatial proximity to the closest legacy detector, NOT name-matching.
site_index <- integer(nrow(x))
near_distance <- numeric(nrow(x))
for(i in seq_len(nrow(x))){
 dsq <- (det$x-x$x[i])^2+(det$y-x$y[i])^2
 site_index[i] <- which.min(dsq)
 near_distance[i] <- sqrt(dsq[site_index[i]])
}
x$detector <- det$detector[site_index]
x$dist_m <- near_distance
excluded<-sum(x$dist_m>threshold)
x<-x[x$dist_m<=threshold,,drop=FALSE]
years <- 1977:2025
# Build full detector x year panel explicitly: zeros mean NO RECORDED CAPTURES.
grid <- expand.grid(detector=det$detector,year=years)
grid <- grid[order(grid$detector,grid$year),,drop=FALSE]
grid$sett<-det$sett[match(grid$detector,det$detector)]
grid$x<-det$x[match(grid$detector,det$detector)]
grid$y<-det$y[match(grid$detector,det$detector)]
key <- paste(grid$detector,grid$year,sep=":")
capture_key <- paste(x$detector,x$year,sep=":")
counts <- table(capture_key)
grid$n_source_rows<-as.integer(counts[match(key,names(counts))])
grid$n_source_rows[is.na(grid$n_source_rows)]<-0L
# Unique tattoo/day capture instances, never source row duplicates.
d<-unique(x[,c("detector","year","tattoo","capture_date"),drop=FALSE])
tab <- table(paste(d$detector,d$year,sep=":"))
grid$n_capture_days<-as.integer(tab[match(key,names(tab))])
grid$n_capture_days[is.na(grid$n_capture_days)]<-0L
period <- function(z) ifelse(z<=1992,"1977-1992",ifelse(z<=2008,"1993-2008","2009-2025"))
grid$period<-period(grid$year)
site<-do.call(rbind,lapply(split(grid,grid$detector),function(z){
 observed <- z$year[z$n_capture_days>0L]
 periods_present<-unique(z$period[z$n_capture_days>0L])
 yy<-z$year
 data.frame(detector=z$detector[1],sett=z$sett[1],x=z$x[1],y=z$y[1],
  n_years_with_capture=length(observed),
  first_capture_year=if(length(observed))min(observed) else NA_integer_,
  last_capture_year=if(length(observed))max(observed) else NA_integer_,
  longest_recorded_capture_gap=if(length(observed)>1L)
    max(diff(observed)-1L) else NA_integer_,
  n_1977_1992=sum(z$n_capture_days[z$year<=1992]>0),
  n_1993_2008=sum(z$n_capture_days[z$year>=1993&z$year<=2008]>0),
  n_2009_2025=sum(z$n_capture_days[z$year>=2009]>0),
  n_recent_2019_2025=sum(z$n_capture_days[z$year>=2019]>0),
  observed_all_three_periods=length(periods_present)==3L)
}))
site<-site[order(-site$n_years_with_capture,site$sett),,drop=FALSE]
# Historical observation continuity must not be construed as capture effort.
out<-Sys.getenv("ZONE_CONTINUITY_OUT","")
if(!nzchar(out))out<-file.path("outputs","v11r2_core_periphery",
 paste0("continuity_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out)) stop("Refusing output overwrite: ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(site,file.path(out,"01_sett_annual_capture_continuity.csv"),row.names=FALSE)
write.csv(grid,file.path(out,"02_sett_year_observed_capture_panel.csv"),row.names=FALSE)
# Map by long-term capture continuity, not a nominated core.
png(file.path(out,"03_sett_capture_continuity.png"),
 width=1150,height=850,res=140)
palette<-grDevices::colorRampPalette(c("grey85","skyblue3","navy"))(50)
pidx<-pmax(1L,pmin(50L,as.integer(round((site$n_years_with_capture/49)*49))+1L))
plot(site$x,site$y,asp=1,pch=21,bg=palette[pidx],col="grey30",
 cex=1.2,xlab="Easting (m)",ylab="Northing (m)",
 main="Years with >=1 recorded live capture (1977-2025)")
legend("topright",legend=c("0","12","24","36","49 capture-years"),
 pch=21,pt.bg=palette[c(1,13,25,37,50)],pt.cex=1.1,bty="n")
dev.off()
cat("=== HISTORICAL SETT OBSERVATION CONTINUITY ===\n")
cat("Legacy detector sites:",nrow(site),"\n")
cat("With captures in all three broad periods:",sum(site$observed_all_three_periods),"\n")
cat("Among all-three, median years with captures:",
 median(site$n_years_with_capture[site$observed_all_three_periods]),"\n")
cat("All-three site years-with-captures distribution:\n")
print(summary(site$n_years_with_capture[site$observed_all_three_periods]))
cat("Capture XY beyond distance threshold (excluded):",excluded,"\n")
cat("Top 15 by number of years with recorded captures:\n")
print(head(site[,c("sett","n_years_with_capture","n_1977_1992",
  "n_1993_2008","n_2009_2025","n_recent_2019_2025")],15),row.names=FALSE)
writeLines(c(paste0("snapshot=",snap),paste0("detectors=",detfile),
 paste0("matching_threshold_m=",threshold),
 paste0("finite_XY_capture_rows_excluded_outside_threshold=",excluded),
 "Positive capture events, not trap deployments, define recorded activity.",
 "Zero capture years can be trapped with zero captures, not necessarily closed.",
 "Near-XY spatial links can share coordinate provenance; no independent ID proof.",
 "Location-quality categories need later review before using every record as exact capture site.",
 "Do not define the scientific core by arbitrary years-with-captures threshold.",
 "Time-window observation effort and exact named sett provenance still outstanding."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("Output:",out,"\n")
cat("No refits; no database changes.\n")
