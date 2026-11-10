#!/usr/bin/env Rscript
# Real-data input adapter. No database changes; fresh immutable evidence only.
source("scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R")
for(pkg in c("digest","sf"))if(!requireNamespace(pkg,quietly=TRUE))stop("Install ",pkg)
snap<-Sys.getenv("V12_SNAPSHOT","")
out<-Sys.getenv("V12J_RUN","")
if(!nzchar(snap)||!nzchar(out))stop("Set V12_SNAPSHOT and V12J_RUN")
target<-file.path(out,"joint_inputs.rds")
if(file.exists(target))stop("Refusing to overwrite prepared inputs")
manifest<-readLines(file.path(snap,"MANIFEST.txt"),warn=FALSE)
if(!any(grepl("^source_record_evidence=",manifest)))stop("Need fresh source-rich snapshot")
for(nm in c("qualifying_live","mortality_candidates")) {
 line<-grep(paste0("^sha256_",nm,"="),manifest,value=TRUE)
 if(length(line)!=1||sub("^[^=]+=","",line)!=digest::digest(
   file.path(snap,paste0(nm,".rds")),algo="sha256",file=TRUE))stop("Snapshot hash mismatch: ",nm)
}
d<-as.data.frame(readRDS(file.path(snap,"qualifying_live.rds")))
for(nm in c("capture_id","sett_id","episode_primary_capture_id"))
 if(nm %in% names(d))d[[nm]]<-wecs_bigint_to_character(d[[nm]])
d$tattoo<-toupper(trimws(as.character(d$tattoo)))
d$capture_date<-as.Date(d$capture_date)
d<-v12_spatial_eligibility(d,enforce_20261106_snapshot=FALSE)
first_year<-as.integer(Sys.getenv("V12J_FIRST_YEAR","1977"))
last_year<-as.integer(Sys.getenv("V12J_LAST_YEAR","2025"))
if(anyNA(c(first_year,last_year))||last_year<=first_year)stop("Invalid study window")
d$year<-as.integer(format(d$capture_date,"%Y"))
d$quarter<-(as.integer(format(d$capture_date,"%m"))-1L)%/%3L+1L
d<-d[d$year>=first_year & d$year<=last_year,,drop=FALSE]
if(anyDuplicated(d$capture_id))stop("Duplicate capture IDs")
if("episode_primary_capture_id" %in% names(d)) {
 key<-d$episode_primary_capture_id
 key[is.na(key)|!nzchar(key)]<-d$capture_id[is.na(key)|!nzchar(key)]
 if(anyDuplicated(key))stop("Repeated qualifying live biological episode: review before counting twice")
}
# Canonical explicitly unmapped SETT records become shared latent detector
# positions. They do NOT receive invented fixed coordinates or get discarded.
unmapped<-d$encounter_type=="TRAP" & d$location_type=="SETT" &
 !is.na(d$sett_id) & nzchar(d$sett_id) &
 (!is.finite(d$location_easting)|!is.finite(d$location_northing)) &
 d$location_quality %in% c("UNRESOLVED","SETT_ASSOCIATION_ONLY")
unmapped[is.na(unmapped)]<-FALSE
systematic<-d$encounter_type=="TRAP" & (d$v12_fixed_sett_spatial|unmapped)
systematic[is.na(systematic)]<-FALSE
det<-unique(d[systematic,c("sett_id","location_easting","location_northing")])
det$known<-is.finite(det$location_easting)&is.finite(det$location_northing)
# Prefer accepted known XY if a canonical sett has both missing and mapped rows.
det<-det[order(!det$known,det$sett_id),]
for(id in unique(det$sett_id)) {
 xy<-unique(det[det$sett_id==id & det$known,c("location_easting","location_northing")])
 if(nrow(xy)>1)stop("Conflicting accepted coordinates for sett ",id)
}
det<-det[!duplicated(det$sett_id),]; rownames(det)<-NULL
if(sum(det$known)<4)stop("Insufficient mapped geometry")
det$detector<-seq_len(nrow(det))
origin<-c(mean(det$location_easting[det$known]),mean(det$location_northing[det$known]))
det$x<-(det$location_easting-origin[1])/1000
det$y<-(det$location_northing-origin[2])/1000
buffer<-as.numeric(Sys.getenv("V12J_BUFFER_KM","2"))
if(!is.finite(buffer)||buffer<=0)stop("Invalid initial/entry buffer")
bounds<-c(min(det$x,na.rm=TRUE)-buffer,max(det$x,na.rm=TRUE)+buffer,
          min(det$y,na.rm=TRUE)-buffer,max(det$y,na.rm=TRUE)+buffer)
years<-first_year:last_year; TT<-length(years); JJ<-nrow(det)
d$t<-match(d$year,years); d$j<-match(d$sett_id,det$sett_id)
d$k<-4L*(d$t-1L)+d$quarter
ids<-sort(unique(d$tattoo[systematic]))
if(!length(ids))stop("No systematically trapped animals")
# Do not silently pretend auxiliary-only ascertainment is the same as capture
# ascertainment in an augmented population. Retain those animals in the audit.
aux_only<-d[!d$tattoo %in% ids,,drop=FALSE]
period<-match(floor(years/5)*5,sort(unique(floor(years/5)*5)))
availability<-array(0,c(JJ,4,TT))
survey<-matrix(0,TT,4)
for(r in which(systematic)) {
 availability[d$j[r],d$quarter[r],d$t[r]]<-1
 survey[d$t[r],d$quarter[r]]<-1
}
scenario<-Sys.getenv("V12J_COVERAGE","positive_5year")
if(!scenario %in% c("positive_5year","all_sites","positive_same_quarter"))stop("Unknown coverage scenario")
positive_mask<-availability
if(scenario=="positive_5year")for(t in seq_len(TT))for(q in 1:4)
 availability[,q,t]<-as.integer(apply(positive_mask[,q,max(1,t-4):t,drop=FALSE],1,function(z)any(z>0)))
if(scenario=="all_sites")for(t in seq_len(TT))for(q in 1:4)
 if(survey[t,q])availability[,q,t]<-1
# Entirely empty study quarters do not supply assumed negative trapping trials.
for(t in seq_len(TT))for(q in 1:4)if(!survey[t,q])availability[,q,t]<-0

N<-length(ids)
counts<-array(0,c(N,TT,JJ,4)); positive<-array(0,c(N,TT,4))
aux<-array(0,c(N,TT,4,4)); recover<-array(0,c(N,TT,4))
risk<-array(0,c(N,TT,4)); use_survey<-array(0,c(N,TT,4))
forced_death<-array(0,c(N,TT,4))
for(i in seq_len(N))use_survey[i,,]<-survey
for(r in which(d$tattoo %in% ids)) {
 i<-match(d$tattoo[r],ids); t<-d$t[r]; q<-d$quarter[r]
 positive[i,t,q]<-1
 if(systematic[r]) counts[i,t,d$j[r],q]<-counts[i,t,d$j[r],q]+1
 # Only supported, physically located NON-sett positive marks. No sett proxy.
 if(!systematic[r] && d$location_type[r] %in% c("BUILDING","RECOVERY_SITE","FIELD","WOOD","BOUNDARY") &&
    d$location_quality[r] %in% c("GRID_REFERENCE_CORRECTED_PROVISIONAL","GRID_REFERENCE_PROVISIONAL","LOCALITY_CENTROID_APPROXIMATE") &&
    is.finite(d$location_easting[r]) && is.finite(d$location_northing[r])) {
  xy<-(c(d$location_easting[r],d$location_northing[r])-origin)/1000
  aux[i,t,q,]<-aux[i,t,q,]+c(1,xy,sum(xy^2))
 }
}
if("8810" %in% d$capture_id) {
 r<-which(d$capture_id=="8810")
 if(d$tattoo[r]!="K051"||systematic[r]||d$location_easting[r]!=382442||
    d$location_northing[r]!=201956||sum(aux[match("K051",ids),d$t[r],d$quarter[r],1])!=1)
  stop("K051 nonsett spatial-mark gate failed")
}

m<-as.data.frame(readRDS(file.path(snap,"mortality_candidates.rds")))
for(nm in c("capture_id","linked_pm_capture_id"))if(nm %in% names(m))
 m[[nm]]<-wecs_bigint_to_character(m[[nm]])
m$tattoo<-toupper(trimws(as.character(m$tattoo)))
m$date<-as.Date(m$recorded_event_date)
mortality_outside_cohort<-m[!m$tattoo %in% ids,,drop=FALSE]
m<-m[m$tattoo %in% ids & !is.na(m$date) &
       m$date>=as.Date(paste0(first_year,"-01-01")) &
       m$date<=as.Date(paste0(last_year,"-12-31")),,drop=FALSE]
m$use<-"HELD_NOT_TERMINAL"
mortality<-Sys.getenv("V12J_MORTALITY","candidate_recovery")
if(!mortality %in% c("candidate_recovery","censor"))stop("Invalid mortality scenario")
for(i in seq_len(N)) {
 di<-d[d$tattoo==ids[i],,drop=FALSE]
 first<-min(di$capture_date)
 mi<-which(m$tattoo==ids[i] & !is.na(m$terminal_model_status) &
            m$terminal_model_status=="CANDIDATE_TERMINAL_DEATH")
 if(!length(mi))next
 mi<-mi[order(m$date[mi])]; r<-mi[1]
 if(m$date[r]<max(di$capture_date)) {
  m$use[mi]<-"HELD_LIVE_AFTER_CANDIDATE_DEATH"; next
 }
 k<-4L*(as.integer(format(m$date[r],"%Y"))-first_year)+
      (as.integer(format(m$date[r],"%m"))-1L)%/%3L+1L
 text<-paste(m$mortality_outcome[r],m$encounter_type[r])
 forced<-grepl("REMOV|PUT.DOWN|EUTH|SHOT|KILL|ANAESTH",toupper(text))
 # Deliberate removal/euthanasia is an intervention, with a forced end-quarter
 # death independent of natural survival. All candidate assumptions exported.
 if(forced) {
  stopk<-k;m$use[r]<-"FORCED_DEATH_END_QUARTER_NO_NATURAL_SURVIVAL_FAILURE"
  t<-(k-1L)%/%4L+1L;q<-(k-1L)%%4L+1L
  positive[i,t,q]<-1;forced_death[i,t,q]<-1
 } else if(mortality=="censor") {
  stopk<-k-1L;m$use[r]<-"CANDIDATE_CENSOR_BEFORE_QUARTER"
 } else {
  stopk<-k; recover[i,(k-1L)%/%4L+1L,(k-1L)%%4L+1L]<-1
  m$use[r]<-"CANDIDATE_RECOVERY_SCENARIO_NOT_SIGNED_OFF"
 }
 for(kk in seq_len(4L*TT))if(kk>stopk) {
  t<-(kk-1L)%/%4L+1L; q<-(kk-1L)%%4L+1L
  use_survey[i,t,q]<-0; positive[i,t,q]<-0; counts[i,t,,q]<-0; aux[i,t,q,]<-0
 }
}
# Recovery reporting applies only once marked, through first report/censor.
for(i in seq_len(N)) {
 liveks<-which(as.vector(t(positive[i,,]))>0)
 if(!length(liveks))next
 first<-min(liveks)
 if(mortality=="candidate_recovery") {
  stopk<-4L*TT
  report<-which(as.vector(t(recover[i,,]))>0)
  if(length(report))stopk<-min(report)
  mi<-which(m$tattoo==ids[i] & grepl("CENSOR_BEFORE_QUARTER|FORCED_DEATH",m$use))
  if(length(mi)) {
   dt<-min(m$date[mi]); ck<-4L*(as.integer(format(dt,"%Y"))-first_year)+
    (as.integer(format(dt,"%m"))-1L)%/%3L+1L
   stopk<-min(stopk,ck-1L)
  }
  if(stopk>=first)for(kk in first:stopk)risk[i,(kk-1L)%/%4L+1L,(kk-1L)%%4L+1L]<-1
 }
}
# Censoring may leave no systematic encounter: keep audit, exclude from
# augmented capture cohort rather than accidentally adding an all-zero animal.
keep<-apply(counts,1,sum)>0
dropped<-ids[!keep]; ids<-ids[keep]
counts<-counts[keep,,,,drop=FALSE]; positive<-positive[keep,,,drop=FALSE]
aux<-aux[keep,,,,drop=FALSE]; recover<-recover[keep,,,drop=FALSE]
risk<-risk[keep,,,drop=FALSE]; use_survey<-use_survey[keep,,,drop=FALSE]
forced_death<-forced_death[keep,,,drop=FALSE]
N<-length(ids)
# Reuse the existing audited reference boundaries. No old posterior tracks
# enter the likelihood; these vertices are fixed reporting geometry only.
frac<-as.numeric(Sys.getenv("V12J_CORE_FRACTION","0.65"))
if(!is.finite(frac)||frac<=0||frac>=1)stop("Invalid core fraction")
zd<-Sys.getenv("ZONE_AUDIT_DIR","outputs/v11r2_core_periphery/audit_20261109T134751Z")
zf<-file.path(zd,c("02_core_hull_vertices.csv","03_outer_detector_hull_vertices.csv"))
if(all(file.exists(zf))) {
 cc<-read.csv(zf[1]);oo<-read.csv(zf[2])
 cc<-cc[cc$scenario==sprintf("central_%02d",round(frac*100)),]
 if(nrow(cc)<3||nrow(oo)<3)stop("Requested reference hull unavailable")
 cc<-cc[order(cc$vertex),];oo<-oo[order(oo$vertex),]
 core<-sweep(as.matrix(cc[,c("x","y")]),2,origin)/1000
 outer<-sweep(as.matrix(oo[,c("x","y")]),2,origin)/1000
 core<-rbind(core,core[1,]);outer<-rbind(outer,outer[1,])
 zone_source<-paste0("existing_audit:",normalizePath(zd))
} else {
 # Portable fallback uses the identical ranked central-fraction convention.
 xy<-as.matrix(det[det$known,c("x","y")])
 hh<-chull(xy);outer<-rbind(xy[hh,,drop=FALSE],xy[hh[1],,drop=FALSE])
 radius<-rowSums(sweep(xy,2,apply(xy,2,median))^2)
 nc<-max(4L,min(nrow(xy)-1L,ceiling(frac*nrow(xy))))
 cx<-xy[order(radius)[seq_len(nc)],,drop=FALSE]
 hh<-chull(cx);core<-rbind(cx[hh,,drop=FALSE],cx[hh[1],,drop=FALSE])
 zone_source<-"fallback_current_detector_geometry_not_identical_to_legacy_reference"
 warning("Existing zone vertices not found; using declared current-geometry fallback")
}
# sf is used only for geometry in postprocessing, not for an invented habitat.
zones<-sf::st_sf(zone=c("core","reference_outer"),geometry=sf::st_sfc(
 sf::st_polygon(list(core*1000+matrix(rep(origin,nrow(core)),ncol=2,byrow=TRUE))),
 sf::st_polygon(list(outer*1000+matrix(rep(origin,nrow(outer)),ncol=2,byrow=TRUE))),crs=27700))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(det,file.path(out,"detectors_known_and_latent.csv"),row.names=FALSE)
write.csv(m,file.path(out,"mortality_scenario_audit_LOCAL.csv"),row.names=FALSE)
write.csv(mortality_outside_cohort,file.path(out,"mortality_outside_capture_cohort_HELD_LOCAL.csv"),row.names=FALSE)
write.csv(aux_only,file.path(out,"auxiliary_only_animals_HELD_LOCAL.csv"),row.names=FALSE)
write.csv(data.frame(tattoo=dropped),file.path(out,"censoring_exclusions_LOCAL.csv"),row.names=FALSE)
audit<-data.frame(capture_id=d$capture_id,tattoo=d$tattoo,systematic=systematic,
 unmapped_detector=unmapped,spatial_evidence=d$v12_spatial_evidence,
 year=d$year,quarter=d$quarter)
write.csv(audit,file.path(out,"encounter_inclusion_LOCAL.csv"),row.names=FALSE)
saveRDS(list(ids=ids,N=N,T=TT,J=JJ,years=years,period=period,counts=counts,
 positive=positive,aux=aux,recovery=recover,at_risk=risk,forced=forced_death,survey=use_survey,
 availability=availability,detectors=det,origin=origin,bounds=bounds,zones=zones,
 snapshot=normalizePath(snap),snapshot_manifest=manifest,
 coverage=scenario,mortality=mortality,core_fraction=frac,zone_source=zone_source),target)
hash<-digest::digest(target,file=TRUE,algo="sha256")
writeLines(c(paste0("input_sha256=",hash),paste0("snapshot=",normalizePath(snap)),
 paste0("N_observed_capture_cohort=",N),paste0("detectors_known=",sum(det$known)),
 paste0("detectors_latent_XY=",sum(!det$known)),paste0("years=",first_year,"-",last_year),
 paste0("coverage_assumption=",scenario),paste0("mortality_scenario=",mortality),
 paste0("zone_source=",zone_source),
 paste0("auxiliary_only_held_animals=",length(unique(aux_only$tattoo))),
 paste0("mortality_only_or_outside_capture_cohort_rows_held=",nrow(mortality_outside_cohort)),
 "effort=saturated within assumed network; no trap-day records reconstructed",
 "membership=augmented capture cohort; auxiliary-only ascertainment not modelled",
 "entry=annual entry into modelled population; not labelled immigration",
 "outside=continuous unbounded movement; finite rectangle only for initial/entry positions",
 "status=developmental real-data model; mortality candidates remain provisional"),file.path(out,"INPUT_MANIFEST.txt"))
cat(readLines(file.path(out,"INPUT_MANIFEST.txt")),sep="\n")
cat("\nPrepared:",target,"\n")
