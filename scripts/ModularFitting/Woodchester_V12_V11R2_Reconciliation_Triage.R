#!/usr/bin/env Rscript
# Read-only local follow-up to V11R2 cohort reconciliation; no DB connection.
# Print only aggregated results except the single missing historic cohort tattoo.
d <- Sys.getenv("V12_RECONCILIATION_DIR","")
if(!nzchar(d))stop("Set V12_RECONCILIATION_DIR to the output folder from prior reconciliation")
paths <- file.path(d,c("01_overview.csv","03_LEGACY_COHORT_LOCAL.csv",
                       "04_DIFFERENT_DATES_LOCAL.csv",
                       "07_LEGACY_TATTOOS_NO_CURATED_SPATIAL_LOCAL.csv"))
if(!all(file.exists(paths)))stop("Missing: ",paste(paths[!file.exists(paths)],collapse=", "))
overview <- read.csv(paths[1],stringsAsFactors=FALSE)
coh <- read.csv(paths[2],stringsAsFactors=FALSE)
diffs <- read.csv(paths[3],stringsAsFactors=FALSE)
missing <- read.csv(paths[4],stringsAsFactors=FALSE)
required <- c("tattoo","legacy_first","legacy_last","legacy_latent_states",
 "legacy_latent_intervals","curated_spatial_first","curated_spatial_last",
 "curated_spatial_latent_states","curated_spatial_latent_intervals",
 "curated_all_live_first","curated_all_live_last",
 "curated_all_live_latent_states","curated_all_live_latent_intervals")
if(!all(required %in% names(coh)))
 stop("Missing cohort columns: ",paste(setdiff(required,names(coh)),collapse=", "))
if(anyDuplicated(coh$tattoo))stop("Duplicated cohort tattoo")
if(nrow(coh)!=1932L)stop("Expected 1932 historic cohort tattoos; got ",nrow(coh))
if(!all(c("tattoo","date","status") %in% names(diffs)))
 stop("Changed-date summary missing expected fields")
sum0 <- function(x) sum(x,na.rm=TRUE)
z <- function(x) replace(x,is.na(x),0L)
cat("\n=== RECONCILIATION SUMMARY / AUDIT CHECK ===\n")
for(col in c("legacy_latent_states","legacy_latent_intervals",
 "curated_spatial_latent_states","curated_spatial_latent_intervals",
 "curated_all_live_latent_states","curated_all_live_latent_intervals"))
 cat(sprintf("%-40s %d\n",col,sum0(coh[[col]])))
if(sum0(coh$legacy_latent_states)!=8248L ||
   sum0(coh$legacy_latent_intervals)!=6316L)
 stop("Legacy annual movement totals do not reproduce V11R2")
cat("\n=== OLD-COHORT BADGERS WITH NO CURATED SPATIAL CAPTURE ===\n")
print(missing,row.names=FALSE)
if(nrow(missing)!=1L)warning("Expected exactly 1 absent spatial tattoo; observed ",nrow(missing))
cat("\n=== CHANGES IN FIRST/LAST OBSERVED YEAR ===\n")
spok <- !is.na(coh$curated_spatial_first)
liveok <- !is.na(coh$curated_all_live_first)
tally <- data.frame(
 comparison=c("curated spatial vs old mapped","curated all live vs old mapped"),
 with_history=c(sum(spok),sum(liveok)),
 missing_history=c(sum(!spok),sum(!liveok)),
 first_year_earlier=c(sum(coh$curated_spatial_first < coh$legacy_first,na.rm=TRUE),
                      sum(coh$curated_all_live_first < coh$legacy_first,na.rm=TRUE)),
 first_year_later=c(sum(coh$curated_spatial_first > coh$legacy_first,na.rm=TRUE),
                    sum(coh$curated_all_live_first > coh$legacy_first,na.rm=TRUE)),
 last_year_earlier=c(sum(coh$curated_spatial_last < coh$legacy_last,na.rm=TRUE),
                     sum(coh$curated_all_live_last < coh$legacy_last,na.rm=TRUE)),
 last_year_later=c(sum(coh$curated_spatial_last > coh$legacy_last,na.rm=TRUE),
                   sum(coh$curated_all_live_last > coh$legacy_last,na.rm=TRUE))
)
print(tally,row.names=FALSE)
cat("\n=== ANNUAL SPAN CHANGES, BY BADGER ===\n")
for(label in c("curated_spatial","curated_all_live")) {
 diff <- z(coh[[paste0(label,"_latent_intervals")]]) -
         z(coh$legacy_latent_intervals)
 cat(label,": shorter=",sum(diff<0),", longer=",sum(diff>0),
  ", unchanged=",sum(diff==0),", net=",sum(diff),"\n",sep="")
 cat(" Net lost intervals:",sum(diff[diff<0]),
     " | net gained:",sum(diff[diff>0]),"\n")
}
cat("\n=== DATE-LEVEL DIFFERENCES ===\n")
print(as.data.frame(table(diffs$status)),row.names=FALSE)
cat("Distinct animals involved:",length(unique(diffs$tattoo)),"\n")
cat("\n=== DIFFERENCE DISTRIBUTION BY DATE YEAR ===\n")
yr <- as.integer(substr(as.character(diffs$date),1,4))
if(anyNA(yr))stop("Invalid changed date")
print(as.data.frame(table(year=yr,status=diffs$status)),row.names=FALSE,
      max=50)
cat("\nInterpretation: tattoo/date is a screening key, not confirmed episode identity.\n")
cat("No missing-XY event is made into a fabricated fixed-sett detection.\n")
cat("The number of latent intervals is a between-first-and-last-year span,\n")
cat("not the count of observed consecutive-year recapture pairs.\n")
