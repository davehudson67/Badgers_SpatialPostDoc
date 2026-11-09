#!/usr/bin/env Rscript
# READ-ONLY review of historical capture evidence at FIXED named sett locations.
# The per-period proximity to legacy V11R2 detector points is provisional;
# do not treat a site with no captures as untrapped or historically closed.
# No biological core assignment is made in this analysis.
base <- Sys.getenv("ZONE_FOOTPRINT_DIR", "")
if (!nzchar(base)) stop("Set ZONE_FOOTPRINT_DIR to historical_footprint audit directory")
f <- file.path(base,"01_legacy_detectors_near_captures_by_period.csv")
if (!file.exists(f)) stop("Missing historical footprint table: ",f)
x <- read.csv(f,stringsAsFactors=FALSE,check.names=FALSE)
need <- c("period","detector","sett","x","y","n_positive_capture_rows",
          "n_capture_days","n_distinct_capture_years")
if (!all(need %in% names(x))) stop("Required columns missing")
periods <- c("1977–1992","1993–2008","2009–2025")
if (!setequal(unique(x$period),periods)) stop("Unexpected period labels")
if(anyDuplicated(x[c("detector","period")])) stop("Duplicate detector-period")
# Do not hard-code an expected count. Instead compare the actual period table
# against the full detector list when available and expose any discrepancy.
if(anyNA(x$detector)) stop("Missing detector IDs in historical footprint table")
ids <- sort(unique(x$detector))
if(!length(ids)) stop("No detector IDs in historical footprint table")
if(nrow(x)!=length(ids)*length(periods))
  stop("Incomplete detector-period grid: ",nrow(x)," rows for ",
       length(ids)," detectors and ",length(periods)," periods")
reference <- Sys.getenv("ZONE_AUDIT_DIR","")
reference_file <- file.path(reference,"01_detector_geometry_reference.csv")
if(nzchar(reference) && file.exists(reference_file)) {
  ref <- read.csv(reference_file,stringsAsFactors=FALSE)
  if(!"detector"%in%names(ref)) stop("Detector reference lacks detector IDs")
  missing_ids <- setdiff(ref$detector,ids)
  extra_ids <- setdiff(ids,ref$detector)
  if(length(missing_ids)||length(extra_ids))
    warning("Historical detector reference mismatch; missing IDs: ",
       paste(missing_ids,collapse=","),"; extra IDs: ",
       paste(extra_ids,collapse=","))
  cat("Detector count in reference: ",nrow(ref),"\n",sep="")
}
cat("Distinct detector IDs in period file: ",length(ids),"\n",sep="")
matrix_var <- function(field) {
  mat <- matrix(NA_real_,nrow=length(ids),ncol=length(periods),
                dimnames=list(ids,periods))
  for(i in seq_len(nrow(x))) {
    a <- match(x$detector[i],ids); b <- match(x$period[i],periods)
    mat[a,b] <- x[[field]][i]
  }
  if(anyNA(mat))stop("Incomplete detector by period coverage")
  mat
}
active <- matrix_var("n_capture_days")>0
years <- matrix_var("n_distinct_capture_years")
site <- x[match(ids,x$detector),c("detector","sett","x","y")]
site$recorded_1977_1992 <- active[,1]
site$recorded_1993_2008 <- active[,2]
site$recorded_2009_2025 <- active[,3]
site$periods_with_observed_captures <- rowSums(active)
site$years_captured_1977_1992 <- years[,1]
site$years_captured_1993_2008 <- years[,2]
site$years_captured_2009_2025 <- years[,3]
site$observed_all_three_periods <- rowSums(active)==3
site$earlier_recorded_not_recent <- (active[,1]|active[,2]) & !active[,3]
site$recent_only <- active[,3] & !active[,1] & !active[,2]
# A site with no captures in a period may nevertheless have been trapped.
n <- nrow(site)
summ <- data.frame(
  metric=c("legacy_sites","captured_in_1977_1992",
           "captured_in_1993_2008","captured_in_2009_2025",
           "observed_all_three_periods","earlier_recorded_not_recent",
           "recent_only"),
  n=c(n,colSums(active),sum(site$observed_all_three_periods),
      sum(site$earlier_recorded_not_recent),sum(site$recent_only))
)
out <- Sys.getenv("ZONE_SETT_REVIEW_OUT","")
if(!nzchar(out))out<-file.path("outputs","v11r2_core_periphery",
 paste0("sett_network_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Refusing overwrite: ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(site,file.path(out,"01_sett_capture_history_by_period.csv"),row.names=FALSE)
write.csv(summ,file.path(out,"02_historical_network_summary.csv"),row.names=FALSE)
# Map with legend showing whether any LIVE capture was observed at a fixed
# legacy detector in each period; does not represent active survey effort.
png(file.path(out,"03_sett_network_period_comparison.png"),
 width=1650,height=640,res=135)
op <- par(no.readonly=TRUE)
par(mfrow=c(1,3),mar=c(4,4,3,1))
xr <- range(site$x); yr<-range(site$y)
for(k in seq_along(periods)) {
 plot(site$x,site$y,asp=1,xlim=xr,ylim=yr,pch=1,col="grey65",
      cex=.75,xlab="Easting (m)",ylab="Northing (m)",
      main=paste(periods[k],"| observed capture setts"))
 a<-active[,k]
 points(site$x[a],site$y[a],pch=16,col="darkblue",cex=.85)
 legend("bottomleft",legend=c("Capture(s) recorded","No capture recorded"),
        pch=c(16,1),col=c("darkblue","grey65"),bty="n",cex=.75)
}
par(op);dev.off()
writeLines(c(paste0("source_footprint=",base),
 "Detectors reflect fixed legacy sett points (per investigator confirmation).",
 "Spatial source locations are generally named trapping setts, not animal GPS positions.",
 "Period classification indicates positive recorded captures only, NOT trap deployment.",
 "Never captured in a period does NOT establish never trapped, fewer trap-nights, or closure.",
 "Proximity-linked record is not an independently validated sett identity.",
 "Do NOT adopt all-three-period captures as a biological core without effort metadata.",
 "Spatial capture network contracted in recent decades per investigator field knowledge;",
 "this requires explicit era-specific observation model prior to final biological inference."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("=== RECORDED SETT NETWORK BY HISTORICAL PERIOD ===\n")
print(summ,row.names=FALSE)
cat("Map:",file.path(out,"03_sett_network_period_comparison.png"),"\n")
cat("No trapping effort, density or immigration parameter estimated.\n")
