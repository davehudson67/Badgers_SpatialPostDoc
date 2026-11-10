#!/usr/bin/env Rscript
# V11R3 preparation gate, READ ONLY. Not a NIMBLE model fit.
# Read new immutable Supabase snapshot, review approved capture source evidence,
# protect original cohort, validate detector geometry and positive-site histories.
# Never assume missing site-quarter equals a zero-capture trapping occasion.
snap <- Sys.getenv("V12_SNAPSHOT","")
if(!nzchar(snap))stop("Set V12_SNAPSHOT to a fresh Supabase snapshot")
need <- c(file.path(snap,"MANIFEST.txt"),file.path(snap,"qualifying_live.rds"))
if(!all(file.exists(need)))stop("Missing snapshot manifest/qualifying_live.rds")
manifest <- readLines(need[1],warn=FALSE)
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",manifest)) ||
   !any(grepl("^source_record_evidence=",manifest)))
 stop("Expected newer Supabase snapshot with original source method and location")
x <- as.data.frame(readRDS(need[2]))
if(!file.exists("results/V7_population_inclusion_audit.rds"))
 stop("Missing archival V11R2 cohort reference; do not rebuild historic cohort silently")
p<-readRDS("results/V7_population_inclusion_audit.rds")$population
if(is.null(p))stop("Invalid historic cohort reference")
ids<-unique(toupper(trimws(as.character(p$tattoo[!is.na(p$movement_eligible)&p$movement_eligible]))))
if(length(ids)!=1932L||anyNA(ids))stop("Historic cohort reference is not the verified 1932 tattoos")
source("scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R")
x<-v12_spatial_eligibility(x,enforce_20261106_snapshot=FALSE)
x$capture_date<-as.Date(x$capture_date)
x$tattoo<-toupper(trimws(as.character(x$tattoo)))
x$year<-as.integer(format(x$capture_date,"%Y"))
x$quarter<-(as.integer(format(x$capture_date,"%m"))-1L)%/%3L+1L
x<-x[!is.na(x$year)&x$year>=1977L&x$year<=2025L,,drop=FALSE]
if(anyNA(x$tattoo)||any(!nzchar(x$tattoo)))stop("Missing tattoo")
if(anyDuplicated(as.character(x$capture_id)))stop("Duplicate source capture ID")
fixed<-x[x$v12_fixed_sett_spatial,,drop=FALSE]
if(!nrow(fixed))stop("No approved fixed-sett observations")
fixed$easting<-as.numeric(fixed$location_easting)
fixed$northing<-as.numeric(fixed$location_northing)
if(any(!is.finite(fixed$easting)|!is.finite(fixed$northing)))
 stop("Approved fixed-sett points contain invalid XY")
fixed$sett_id<-as.character(fixed$sett_id)
pairs<-unique(fixed[,c("sett_id","easting","northing")])
if(anyDuplicated(pairs$sett_id))stop("One canonical sett ID has multiple spatial XY; source review required")
# K051 nonsett locality must be retained in the new snapshot but never
# included in the fixed-detector universe.
j<-x[as.character(x$capture_id)=="8810",,drop=FALSE]
if(nrow(j)!=1L || j$tattoo!="K051" || j$encounter_type!="FOUND_ALIVE" ||
   j$location_type!="BUILDING" ||
   as.numeric(j$location_easting)!=382442 ||
   as.numeric(j$location_northing)!=201956 ||
   j$v12_fixed_sett_spatial)
 stop("Capture 8810 K051 nonsett-location correction missing or misclassified")
# Source audit: all 159 previous blank-location captures were approved;
# revised frozen data should preserve these counts until separate evidence changes.
blank<-x[x$v12_spatial_evidence=="APPROVED_NAMED_SETT_BLANK_LOCATION",,drop=FALSE]
if(nrow(blank)!=159L)stop("Previously approved 159 capture class changed; re-audit before fitting: ",nrow(blank))
method_counts<-table(blank$v12_original_method_evidence)
if(!identical(as.integer(method_counts[c("ORIGINAL_TRAP",
 "CURATED_TRAP_ORIGINAL_MOC_MISSING")]),c(110L,49L)))
 stop("Approved 159 original-method evidence no longer 110 explicit/49 inferred; re-audit")
# The 304 historical explicit SETT without XY are retained as temporal history;
# future sett XY changes can shrink this class without retrospectively rewriting history.
unmapped <- x[!x$v12_fixed_sett_spatial & x$location_type=="SETT",,drop=FALSE]
# Positive-only detector occasions: NEVER turn all unobserved cells into
# verified surveyed-negative effort observations.
presence <- unique(fixed[,c("sett_id","year","quarter")])
presence$positive_capture_recorded<-TRUE
cohort<-x[x$tattoo%in%ids,,drop=FALSE]
cohort_fixed<-cohort[cohort$v12_fixed_sett_spatial,,drop=FALSE]
if(length(unique(cohort_fixed$tattoo))!=1932L)
 stop("Not all 1932 original movement cohort tattoos have approved mapped captures")
# Count capture episodes at canonical fixed detectors, not raw row counts as
# inferred negative effort or density.
cat("=== V11R3 PREFIT SPATIAL INPUT GATE ===\n")
cat("Snapshot:",snap,"\n")
cat("Qualifying live rows:",nrow(x),"\n")
cat("Approved fixed-sett rows:",nrow(fixed),"\n")
print(table(fixed$v12_spatial_evidence))
cat("Approved named-sett original method evidence:\n");print(method_counts)
cat("Historical movement cohort mapped tattoos:",length(unique(cohort_fixed$tattoo)),"\n")
cat("Distinct approved fixed sett IDs:",nrow(pairs),"\n")
cat("Positive sett-year-quarter combinations:",nrow(presence),"\n")
cat("Explicit SETT rows still without spatial approval:",nrow(unmapped),"\n")
cat("Geolocated K051 non-sett positive encounter: verified\n")
out<-Sys.getenv("V11R3_GATE_OUT","")
if(!nzchar(out))out<-file.path("outputs","v11r3_input_gate",
 paste0("gate_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Output directory already exists: ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(pairs,file.path(out,"01_approved_detector_reference_LOCAL.csv"),row.names=FALSE)
write.csv(presence,file.path(out,"02_positive_capture_site_quarters_LOCAL.csv"),row.names=FALSE)
write.csv(data.frame(tattoo=sort(unique(cohort_fixed$tattoo))),
 file.path(out,"03_legacy_cohort_spatial_tattoos_LOCAL.csv"),row.names=FALSE)
write.csv(as.data.frame(table(source=fixed$v12_spatial_evidence)),
 file.path(out,"04_location_evidence_counts.csv"),row.names=FALSE)
writeLines(c(paste0("snapshot=",snap),
 paste0("git_commit=",tryCatch(system2("git",c("rev-parse","HEAD"),stdout=TRUE)[1],
  error=function(e)"UNKNOWN")),
 "POSITIVE captures at a sett-quarter establish at least one observation.",
 "Unobserved sett-quarter DOES NOT imply no trapping OR known zero captures.",
 "The old 1932 tattoo cohort is an archival comparison reference only.",
 "Bown Hill Farm K051 8810 is a non-sett live spatial observation, not a detector.",
 "This script does not fit V11, infer survival/immigration, or impute effort.",
 "Local exported tattoo/sett evidence must remain untracked; do not commit."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("PASSED input gate; outputs:",out,"\n")
cat("NOT APPROVED FOR LONG NIMBLE FIT until coverage-aware likelihood smoke passes.\n")
