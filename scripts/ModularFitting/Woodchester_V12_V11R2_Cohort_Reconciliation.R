#!/usr/bin/env Rscript
# Woodchester V11R2 -> curated Supabase cohort/capture reconciliation.
# READ-ONLY; no DB connection, no source writes, no fitting.
# Tattoo + capture-date is a SCREENING key, not proof of row identity.
# Never assume absent captures are absent trapping effort.
snap <- Sys.getenv("V12_SNAPSHOT","data/model_snapshots/v12_20261106T103144Z_1079872")
legacy_enc_path <- "data/badger_encounters_useful.rds"
legacy_pop_path <- "results/V7_population_inclusion_audit.rds"
legacy_sett_path <- "data/WoodchesterSettLocations.csv"
need <- c(file.path(snap,"MANIFEST.txt"),file.path(snap,"qualifying_live.rds"),
          legacy_enc_path,legacy_pop_path,legacy_sett_path)
if(any(!file.exists(need)))stop("Missing required file(s):\n",
 paste(need[!file.exists(need)],collapse="\n"))
manifest<-readLines(need[1],warn=FALSE)
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",manifest)))
 stop("Unexpected Supabase snapshot provenance")
popobj<-readRDS(legacy_pop_path)
if(is.null(popobj$population))stop("Missing legacy $population")
pop<-as.data.frame(popobj$population)
if(!all(c("tattoo","movement_eligible")%in%names(pop)))
 stop("Missing legacy population columns")
norm<-function(z){x<-toupper(trimws(as.character(z)));x[is.na(z)]<-NA_character_;x}
ids<-unique(norm(pop$tattoo[which(!is.na(pop$movement_eligible)&pop$movement_eligible)]))
if(length(ids)!=1932L)stop("Expected 1932 legacy movement tattoos; got ",length(ids))
if(anyNA(ids)||any(!nzchar(ids)))stop("Missing legacy tattoo")
legacy<-as.data.frame(readRDS(legacy_enc_path))
require<-c("tattoo","capture_date","primary_year","trap_season","sett","has_live_capture")
if(!all(require%in%names(legacy)))stop("Legacy encounter fields missing: ",
 paste(setdiff(require,names(legacy)),collapse=", "))
legacy$tattoo<-norm(legacy$tattoo)
legacy$capture_date<-as.Date(legacy$capture_date)
legacy$year<-suppressWarnings(as.integer(legacy$primary_year))
legacy$quarter<-suppressWarnings(as.integer(legacy$trap_season))
legacy<-legacy[!is.na(legacy$has_live_capture)&legacy$has_live_capture&
 !is.na(legacy$year)&legacy$year<=2025&
 legacy$quarter%in%1:4&legacy$tattoo%in%ids,,drop=FALSE]
raw<-as.data.frame(readRDS(file.path(snap,"qualifying_live.rds")))
needed<-c("capture_id","tattoo","capture_date","location_type","location_quality",
 "location_easting","location_northing","sett_id","encounter_type")
if(!all(needed%in%names(raw)))stop("Curated snapshot fields missing: ",
 paste(setdiff(needed,names(raw)),collapse=", "))
# Avoid numeric interpretation of integer64 physical bytes in exported IDs.
safe_id<-function(x) {
 if(inherits(x,"integer64")) {
  if(!requireNamespace("bit64",quietly=TRUE))stop("Install bit64")
  return(bit64::as.character.integer64(x))
 }
 if(is.double(x)&&any(is.finite(x)&x!=0&abs(x)<1e-200)) {
  if(!requireNamespace("bit64",quietly=TRUE))stop("Install bit64")
  return(bit64::as.character.integer64(structure(x,class="integer64")))
 }
 as.character(x)
}
raw$capture_id<-safe_id(raw$capture_id)
raw$sett_id<-safe_id(raw$sett_id)
if(anyDuplicated(raw$capture_id)||anyNA(raw$capture_id))stop("Duplicate/missing capture IDs")
raw$tattoo<-norm(raw$tattoo)
raw$capture_date<-as.Date(raw$capture_date)
raw$year<-as.integer(format(raw$capture_date,"%Y"))
raw$quarter<-(as.integer(format(raw$capture_date,"%m"))-1L)%/%3L+1L
raw<-raw[raw$year>=1977&raw$year<=2025,,drop=FALSE]
# Investigator-approved 2026-11-10 rule. The original source context for
# the 159 named-sett blank-location captures was checked against live Supabase.
# Use a guarded, model-specific derivation; NEVER rewrite the frozen snapshot.
source("scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R",local=TRUE)
raw<-v12_spatial_eligibility(raw,enforce_20261106_snapshot=TRUE)
raw$spatial_candidate<-raw$v12_fixed_sett_spatial
cat("\nApproved spatial input evidence (whole snapshot):\n")
print(table(raw$v12_spatial_evidence,useNA="ifany"))
if(anyNA(raw$capture_date)||anyNA(raw$tattoo))stop("Missing curated identity or date")
# Main comparison is on EXACTLY the original V11R2 population; full cohort is
# reported as separate discovery, never silently included in a new refit.
new<-raw[raw$tattoo%in%ids,,drop=FALSE]
legacy$ym<-paste(legacy$tattoo,legacy$year,sep="|")
new$ym<-paste(new$tattoo,new$year,sep="|")
# Legacy was mapped by cleaned-sett names against a historic sett-coordinate
# CSV. Rebuild its exact name cleaning solely to reproduce V11R2 input.
sett<-utils::read.csv(legacy_sett_path,check.names=FALSE,stringsAsFactors=FALSE)
pick<-function(options,choices){
 k<-intersect(options,choices)
 if(!length(k))stop("Legacy coordinate CSV missing expected columns: ",paste(choices,collapse=", "))
 k[1]
}
name_col<-pick(c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name"),names(sett))
x_col<-pick(c("SettX","sett_x","X","x","Easting","easting"),names(sett))
y_col<-pick(c("SettY","sett_y","Y","y","Northing","northing"),names(sett))
clean<-function(z) {
 z<-norm(z);z<-gsub("[[:punct:]]"," ",z)
 z<-gsub("\\b(SETT|MAIN|OUTLIER)\\b","",z,perl=TRUE)
 z<-gsub("\\s+","",z,perl=TRUE)
 aliases<-c(CHESTNUT="CHESNUT",JACKS="JACKSMIREY",GRAVEL="GRAVELPIT",
 BUCKHOLE="BUCKHOLT",TOPSETT="TOP",FOXCUB="FOX",GULLEY="GULLY",
 BLACKBERRY="BRAMBLE",BOC="BOG",CEDARBANK="CEDAR",CLAYTRAP="CLAY",
 CLIFF="CLIFFFACE",DINGLEVALLEY="DINGLE")
 k<-which(!is.na(z)&z%in%names(aliases))
 if(length(k))z[k]<-unname(aliases[z[k]])
 z
}
sx<-data.frame(sett=clean(sett[[name_col]]),
 x=suppressWarnings(as.numeric(sett[[x_col]])),
 y=suppressWarnings(as.numeric(sett[[y_col]])))
sx<-sx[!is.na(sx$sett)&nzchar(sx$sett)&is.finite(sx$x)&is.finite(sx$y),,drop=FALSE]
sx<-unique(sx)
if(anyDuplicated(sx$sett))stop("Legacy sett key has multiple XY")
legacy$key<-clean(legacy$sett)
ix<-match(legacy$key,sx$sett)
legacy$x<-sx$x[ix];legacy$y<-sx$y[ix]
legacy$spatial_eligible<-is.finite(legacy$x)&is.finite(legacy$y)
# Original model only used mapped captures; report unmapped separately.
oldmapped<-legacy[legacy$spatial_eligible,,drop=FALSE]
old_dates<-aggregate(rep(1L,nrow(oldmapped)),
 list(tattoo=oldmapped$tattoo,date=as.character(oldmapped$capture_date)),
 sum);names(old_dates)[3]<-"legacy_mapped_rows"
new_dates<-aggregate(rep(1L,nrow(new)),
 list(tattoo=new$tattoo,date=as.character(new$capture_date)),sum)
names(new_dates)[3]<-"curated_all_live_rows"
new_sp<-new[new$spatial_candidate,,drop=FALSE]
new_spdates<-aggregate(rep(1L,nrow(new_sp)),
 list(tattoo=new_sp$tattoo,date=as.character(new_sp$capture_date)),sum)
names(new_spdates)[3]<-"curated_spatial_rows"
cmp<-merge(old_dates,new_dates,by=c("tattoo","date"),all=TRUE)
cmp<-merge(cmp,new_spdates,by=c("tattoo","date"),all=TRUE)
for(k in c("legacy_mapped_rows","curated_all_live_rows","curated_spatial_rows"))
 cmp[[k]][is.na(cmp[[k]])]<-0L
cmp$status<-ifelse(cmp$legacy_mapped_rows==0,"ONLY_CURATED",
 ifelse(cmp$curated_all_live_rows==0,"ONLY_LEGACY",
 ifelse(cmp$legacy_mapped_rows!=cmp$curated_spatial_rows,
 "SPATIAL_DATE_ROW_COUNT_CHANGED","MATCHED_SPATIAL_DATE_COUNT")))
# annual spans represent model latent states, NOT consecutive actually observed years
annualspan<-function(d,yearcol) {
 if(!nrow(d))return(data.frame(tattoo=character(),first=integer(),last=integer(),
  n_obs_years=integer(),latent_states=integer(),latent_intervals=integer()))
 # split() has stable list behaviour; aggregate() can simplify its vector-
 # valued summary into a matrix, which previously broke do.call(rbind,z$x).
 grouped<-split(as.integer(d[[yearcol]]),d$tattoo,drop=TRUE)
 if(any(vapply(grouped,function(y)anyNA(y),logical(1))))
  stop("Missing year in annual span input")
 out<-data.frame(
  tattoo=names(grouped),
  first=as.integer(vapply(grouped,min,integer(1))),
  last=as.integer(vapply(grouped,max,integer(1))),
  n_obs_years=as.integer(vapply(grouped,function(y)length(unique(y)),integer(1))),
  row.names=NULL,stringsAsFactors=FALSE)
 out$latent_states<-out$last-out$first+1L
 out$latent_intervals<-out$latent_states-1L
 out
}
a<-annualspan(oldmapped,"year")
b<-annualspan(new_sp,"year")
c<-annualspan(new,"year")
names(a)[-1]<-paste0("legacy_",names(a)[-1])
names(b)[-1]<-paste0("curated_spatial_",names(b)[-1])
names(c)[-1]<-paste0("curated_all_live_",names(c)[-1])
coh<-data.frame(tattoo=ids)
coh<-merge(coh,a,all.x=TRUE,by="tattoo",sort=FALSE)
coh<-merge(coh,b,all.x=TRUE,by="tattoo",sort=FALSE)
coh<-merge(coh,c,all.x=TRUE,by="tattoo",sort=FALSE)
coh<-coh[match(ids,coh$tattoo),,drop=FALSE]
# Compare geographic source labels without snapping nearby points to a detector.
coords<-unique(data.frame(sett_id=new_sp$sett_id,
 x=as.numeric(new_sp$location_easting),y=as.numeric(new_sp$location_northing)))
coords<-coords[!is.na(coords$sett_id),,drop=FALSE]
geo<-unique(data.frame(x=sx$x,y=sx$y))
coords$exact_xy_in_legacy_reference<-paste(coords$x,coords$y)%in%
 paste(geo$x,geo$y)
all_sp<-raw[raw$spatial_candidate,,drop=FALSE]
full_extra<-setdiff(unique(raw$tattoo),ids)
overview<-data.frame(metric=c(
 "legacy_movement_population_tattoos","legacy_mapped_capture_rows",
 "legacy_mapped_tattoos","legacy_model_latent_states_from_mapped_history",
 "legacy_model_latent_intervals_from_mapped_history",
 "curated_qualifying_live_rows_all_tattoos","curated_spatial_candidate_rows_all_tattoos",
 "approved_named_sett_blank_location_all_tattoos",
 "curated_all_live_rows_in_legacy_cohort",
 "curated_spatial_rows_in_legacy_cohort",
 "curated_spatial_tattoos_in_legacy_cohort",
 "legacy_tattoos_with_no_curated_spatial_capture",
 "curated_tattoos_outside_legacy_movement_cohort",
 "curated_spatial_tattoos_outside_legacy_movement_cohort",
 "curated_spatial_legacy_cohort_latent_states",
 "curated_spatial_legacy_cohort_latent_intervals",
 "curated_legacy_cohort_all_live_latent_states",
 "curated_legacy_cohort_all_live_latent_intervals",
 "curated_spatial_distinct_sett_ids_legacy_cohort",
 "curated_spatial_distinct_sites_not_exact_legacy_csv_xy",
 "curated_spatial_distinct_sett_ids_all_tattoos",
 "date_key_comparison_differences"),
 value=c(length(ids),nrow(oldmapped),length(unique(oldmapped$tattoo)),
 sum(a$legacy_latent_states),sum(a$legacy_latent_intervals),nrow(raw),nrow(all_sp),
 sum(raw$v12_spatial_evidence=="APPROVED_NAMED_SETT_BLANK_LOCATION"),
 nrow(new),nrow(new_sp),length(unique(new_sp$tattoo)),
 sum(!ids%in%new_sp$tattoo),length(full_extra),
 length(setdiff(unique(all_sp$tattoo),ids)),
 sum(b$curated_spatial_latent_states),sum(b$curated_spatial_latent_intervals),
 sum(c$curated_all_live_latent_states),sum(c$curated_all_live_latent_intervals),
 nrow(coords),sum(!coords$exact_xy_in_legacy_reference),
 length(unique(all_sp$sett_id)),
 sum(cmp$status!="MATCHED_SPATIAL_DATE_COUNT")))
out<-Sys.getenv("V12_RECONCILE_OUT","")
if(!nzchar(out))out<-file.path("outputs","v12_v11r2_reconciliation",
 paste0("run_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Refusing to overwrite existing output ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
utils::write.csv(overview,file.path(out,"01_overview.csv"),row.names=FALSE)
utils::write.csv(as.data.frame(table(cmp$status)),file.path(out,"02_date_comparison_status.csv"),row.names=FALSE)
utils::write.csv(coh,file.path(out,"03_LEGACY_COHORT_LOCAL.csv"),row.names=FALSE)
utils::write.csv(cmp[cmp$status!="MATCHED_SPATIAL_DATE_COUNT",],
 file.path(out,"04_DIFFERENT_DATES_LOCAL.csv"),row.names=FALSE)
utils::write.csv(coords,file.path(out,"05_curated_detector_reference_comparison_LOCAL.csv"),row.names=FALSE)
utils::write.csv(data.frame(tattoo=sort(full_extra)),
 file.path(out,"06_EXTRA_CURATED_BADGERS_LOCAL.csv"),row.names=FALSE)
utils::write.csv(data.frame(tattoo=ids[!ids%in%new_sp$tattoo]),
 file.path(out,"07_LEGACY_TATTOOS_NO_CURATED_SPATIAL_LOCAL.csv"),row.names=FALSE)
writeLines(c(paste("snapshot",snap,sep="="),
 "READ ONLY. Historical V11R2 full movement cohort exactly 1932 tattoos.",
 "Legacy mapped capture eligibility reproduced using legacy alias code and reference CSV.",
 "New fixed-sett candidate: approved explicit SETT point OR 159 investigator-approved blank-location named-sett TRAP associations with known XY.",
 "The 159 category was source-audited 2026-11-10; frozen snapshot has no original MOC, so 49 inferred-method captures cannot be separately tagged in this output.",
 "Future input snapshots must be re-audited before this category is automatically approved.",
 "Curated events with missing XY remain valid dated observations but not geographic detections.",
 "Date comparison = tattoo-date screening only, NOT event-level identity parity.",
 "Annual model span = last spatial year minus first spatial year plus one; NO interpolation of actual capture evidence.",
 "Difference in annual spans is not proof of change in movement biology.",
 "Detector comparison compares XY coordinates, NEVER approves nearest detector or assumes trap effort.",
 "Capture counts and individual data may be sensitive. Keep all output local and do not commit.",
 "No demographic inference, no social groups imposed, no refit."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("\n=== V11R2 VERSUS CURATED SNAPSHOT RECONCILIATION ===\n")
print(overview,row.names=FALSE)
if(any(overview$value[overview$metric %in% c(
 "legacy_model_latent_states_from_mapped_history",
 "legacy_model_latent_intervals_from_mapped_history",
 "curated_spatial_legacy_cohort_latent_states",
 "curated_spatial_legacy_cohort_latent_intervals",
 "curated_legacy_cohort_all_live_latent_states",
 "curated_legacy_cohort_all_live_latent_intervals")] == 0L))
 stop("Invalid zero annual span summary: inspect column names")
cat("\nDate-level differences:\n")
print(as.data.frame(table(cmp$status)),row.names=FALSE)
cat("\nSaved local review files:",out,"\n")
