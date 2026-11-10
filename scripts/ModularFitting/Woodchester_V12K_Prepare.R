#!/usr/bin/env Rscript
# Identical baseline encounter preparation, plus frozen individual metadata.
out<-Sys.getenv("V12K_RUN","")
if(!nzchar(out))stop("Set V12K_RUN")
Sys.setenv(V12J_RUN=out)
for(key in c("COVERAGE","MORTALITY","BUFFER_KM","CORE_FRACTION","FIRST_YEAR","LAST_YEAR")) {
 value<-Sys.getenv(paste0("V12K_",key),"")
 if(nzchar(value))do.call(Sys.setenv,setNames(list(value),paste0("V12J_",key)))
}
source("scripts/ModularFitting/Woodchester_V12J_Prepare.R",local=.GlobalEnv)
source("scripts/ModularFitting/Woodchester_V12K_Covariates.R",local=.GlobalEnv)
b<-readRDS(file.path(out,"joint_inputs.rds"))
reference<-Sys.getenv("V12K_REFERENCE_INPUT","")
comparison<-"Reference input not available; snapshot and baseline preparation rules retained"
if(nzchar(reference)&&file.exists(reference)) {
 old<-readRDS(reference)
 fields<-c("ids","years","counts","positive","aux","recovery","at_risk","forced",
           "survey","availability","detectors","origin","bounds","coverage","mortality")
 same<-vapply(fields,function(nm)identical(old[[nm]],b[[nm]]),logical(1))
 if(!all(same))stop("Baseline encounter inputs differ: ",paste(fields[!same],collapse=", "))
 comparison<-paste0("Verified identical baseline encounter arrays: ",normalizePath(reference))
}
live<-as.data.frame(readRDS(file.path(b$snapshot,"qualifying_live.rds")))
padding<-as.integer(Sys.getenv("V12K_BIRTH_PADDING","30"))
if(is.na(padding)||padding<10L||padding>100L)stop("Birth padding must be 10–100 years")
cv<-v12k_metadata(live,b$ids,b$years,padding)
b$metadata<-cv$metadata;b$birth_years<-cv$birth_years;b$birth_padding<-padding
adult_min<-as.integer(Sys.getenv("V12K_ADULT_MIN_AGE","1"))
if(is.na(adult_min)||!adult_min %in% 1:2)stop("Adult minimum age must be 1 or 2")
b$adult_min_age<-adult_min
b$model<-"V12K age sex persistent individual movement / spatial demography"
path<-file.path(out,"joint_covariate_inputs.rds")
if(file.exists(path))stop("Refusing to overwrite covariate input")
saveRDS(b,path)
write.csv(cv$metadata,file.path(out,"individual_covariate_audit_LOCAL.csv"),row.names=FALSE)
sexcounts<-table(factor(cv$metadata$sex_data,levels=c(0,1)),useNA="always")
agecounts<-table(cv$metadata$age_class,useNA="always")
lines<-c(paste0("input_sha256=",digest::digest(path,file=TRUE,algo="sha256")),
 paste0("same_encounter_cohort_N=",b$N),paste0("source_snapshot=",b$snapshot),
 paste0("baseline_comparison=",comparison),
 paste0("birth_year_support=",min(b$birth_years),"-",max(b$birth_years)),
 paste0("birth_reference=discrete uniform reference cancelled at entry; CUB/YEARLING cohorts observed; ADULT lower bound=",adult_min),
 "entry_age=estimated truncated geometric distributions, separately for initial presence and subsequent entry",
 "unknown_age_and_sex=latent for both observed animals and augmentation candidates",
 "age_groups=0-1 reference; 2; 3-5; >=6; no invented exact adult ages",
 "movement=age/sex relocation probability; sex persistence/scale; persistent individual movement propensity",
 "detection=sex effects on baseline probability and spatial scale; existing quarter/era effects",
 "survival=age and sex effects; recovery and intervention rules unchanged",
 "entry_age_maximum_is_a_sensitivity_assumption_not_a_verified_lifespan_bound",
 "status=developmental model; individual ages/sex and augmentation require convergence/sensitivity checks")
writeLines(lines,file.path(out,"COVARIATE_MANIFEST.txt"))
cat("\nSEX DATA (0 female, 1 male, NA inferred):\n");print(sexcounts)
cat("\nSOURCE FIRST-CAPTURE AGE CLASSES:\n");print(agecounts)
cat(lines,sep="\n");cat("\n")
