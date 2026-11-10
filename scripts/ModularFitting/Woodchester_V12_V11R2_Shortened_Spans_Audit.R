#!/usr/bin/env Rscript
# Read-only follow-up: identify 22 historic V11R2 tattoos whose annual
# fixed-sett spatial span is shorter under approved 2026-11-10 rules.
# Uses existing local reconciliation CSVs; never writes source/DB data.
dir <- Sys.getenv("V12_RECONCILIATION_DIR","")
if(!nzchar(dir))stop("Set V12_RECONCILIATION_DIR")
paths <- file.path(dir,c("03_LEGACY_COHORT_LOCAL.csv",
                         "04_DIFFERENT_DATES_LOCAL.csv"))
if(!all(file.exists(paths)))stop("Missing reconciliation files: ",
 paste(paths[!file.exists(paths)],collapse=","))
coh <- read.csv(paths[1],stringsAsFactors=FALSE)
dates <- read.csv(paths[2],stringsAsFactors=FALSE)
needed <- c("tattoo","legacy_first","legacy_last","legacy_latent_intervals",
 "curated_spatial_first","curated_spatial_last",
 "curated_spatial_latent_intervals",
 "curated_all_live_first","curated_all_live_last")
if(!all(needed %in% names(coh)))stop("Missing cohort fields")
coh$delta <- coh$curated_spatial_latent_intervals - coh$legacy_latent_intervals
if(anyNA(coh$delta))stop("Unexpected missing spatial cohort history")
short <- coh[coh$delta<0,,drop=FALSE]
short$lost_intervals <- -short$delta
short$reason <- ifelse(short$curated_spatial_first>short$legacy_first &
 short$curated_spatial_last<short$legacy_last,"BOTH_ENDS",
 ifelse(short$curated_spatial_first>short$legacy_first,"FIRST_SPATIAL_YEAR_LATER",
 ifelse(short$curated_spatial_last<short$legacy_last,"LAST_SPATIAL_YEAR_EARLIER",
 "REVIEW_UNEXPECTED")))
if(nrow(short)!=22L || sum(short$lost_intervals)!=40L)
 stop("Expected 22 shortened tattoos and 40 lost latent intervals: found ",
      nrow(short)," and ",sum(short$lost_intervals))
short<-short[order(-short$lost_intervals,short$tattoo),,drop=FALSE]
cat("\n=== 22 OLD-COHORT BADGERS: SHORTENED SPATIAL SPANS ===\n")
print(short[,c("tattoo","legacy_first","legacy_last",
 "curated_spatial_first","curated_spatial_last","lost_intervals","reason",
 "curated_all_live_first","curated_all_live_last")],
 row.names=FALSE)
cat("\n=== SUMMARY OF SPAN ENDS ===\n")
print(as.data.frame(table(short$reason)),row.names=FALSE)
cat("\n=== DISCREPANT CAPTURE DATES FOR THESE BADGERS ===\n")
d <- dates[dates$tattoo %in% short$tattoo,,drop=FALSE]
if(nrow(d)) {
 d$legacy_mapped_rows <- ifelse(is.na(d$legacy_mapped_rows),0,d$legacy_mapped_rows)
 d$curated_spatial_rows <- ifelse(is.na(d$curated_spatial_rows),0,d$curated_spatial_rows)
 d$curated_all_live_rows <- ifelse(is.na(d$curated_all_live_rows),0,d$curated_all_live_rows)
 d<-d[order(d$tattoo,d$date),,drop=FALSE]
 print(d[,c("tattoo","date","status","legacy_mapped_rows",
            "curated_spatial_rows","curated_all_live_rows")],
       row.names=FALSE)
} else cat("No date-level differences among shortened tattoos (unexpected; inspect).\n")
cat("\nNote: source-date matching is a screen, NOT capture event identity.\n")
cat("Missing mapped capture is not a missing live encounter, and\n")
cat("a missing coordinate must not be replaced by a nearest sett.\n")
