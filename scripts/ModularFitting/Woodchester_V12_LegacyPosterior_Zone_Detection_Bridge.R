#!/usr/bin/env Rscript
# V12 bridge using PRE-EXISTING V11R2 posterior occupancy, not a V12 model.
# Results are exploratory, conditional on old V11R2 spatial smoothing.
# This script does NOT estimate survival, immigration, density or trapping effort.
# It tests whether past location uncertainty is retained in a zone-specific
# observed-next-year recapture summary to guide simulation model development.
zone_dir<-Sys.getenv("ZONE_AUDIT_DIR","")
snap<-Sys.getenv("V12_SNAPSHOT","")
if(!nzchar(zone_dir)||!nzchar(snap))stop("Set ZONE_AUDIT_DIR and V12_SNAPSHOT")
op<-file.path(zone_dir,"04_individual_annual_zone_probabilities.csv")
mp<-file.path(snap,"MANIFEST.txt")
lp<-file.path(snap,"qualifying_live.rds")
if(!all(file.exists(c(op,mp,lp))))stop("Missing zone probabilities or Supabase evidence")
manifest<-readLines(mp,warn=FALSE)
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",manifest)))
 stop("Unrecognised curated snapshot")
o<-read.csv(op,stringsAsFactors=FALSE)
required<-c("scenario","tattoo","year","p_core","p_periphery","p_outside")
if(!all(required%in%names(o)))stop("Zone posterior output lacks necessary fields")
if(anyDuplicated(paste(o$scenario,o$tattoo,o$year)))stop("Duplicate scenario-tattoo-year")
if(anyNA(o[,c("p_core","p_periphery","p_outside")]) ||
 any(abs(rowSums(o[,c("p_core","p_periphery","p_outside")])-1)>1e-5))
 stop("Zone posterior probabilities do not sum to one")
x<-readRDS(lp)
if(!all(c("tattoo","capture_date","capture_id")%in%names(x)))
 stop("Invalid captured-live input")
x$tattoo<-toupper(trimws(as.character(x$tattoo)))
x$capture_date<-as.Date(x$capture_date)
x$year<-as.integer(format(x$capture_date,"%Y"))
x<-x[!is.na(x$year)&x$year>=1977L&x$year<=2025L,,drop=FALSE]
if(anyNA(x$tattoo)||any(!nzchar(x$tattoo)))stop("Missing tattoo")
o$tattoo<-toupper(trimws(o$tattoo))
if(anyNA(o$year)||any(o$year>=2025L)) {
 # 2025 entries are fine as occupancy states but lack 2026 follow-up.
 if(anyNA(o$year))stop("Missing model year")
}
observed<-unique(paste(x$tattoo,x$year,sep="|"))
o$observed_this_year<-paste(o$tattoo,o$year,sep="|")%in%observed
o$observed_next_year<-paste(o$tattoo,o$year+1L,sep="|")%in%observed
o<-o[o$year<2025L & o$observed_this_year,,drop=FALSE]
if(!nrow(o))stop("No observed modelled animal-years with follow-up")
# First recorded year should not be equated with biological entry.
first<-tapply(x$year,x$tattoo,min)
o$first_observed_in_snapshot<-o$year==unname(first[o$tattoo])
# Weighted mean is a summary of observed next-year re-encounter frequency
# by old posterior probability zone; it is NOT phi, p, emigration or recruitment.
zones<-c("core","periphery","outside")
split_key<-interaction(o$scenario,o$year,drop=TRUE)
summaries<-lapply(split(o,split_key),function(d) {
 do.call(rbind,lapply(zones,function(z) {
  w<-d[[paste0("p_",z)]]
  den<-sum(w)
  data.frame(scenario=d$scenario[1],year=d$year[1],zone=z,
   n_tattoos_with_observation=nrow(d),
   expected_legacy_zone_observed_tattoos=den,
   n_expected_next_year_recaptures=sum(w*d$observed_next_year),
   observed_next_year_fraction=if(den>0)
    sum(w*d$observed_next_year)/den else NA_real_,
   n_expected_first_observed_tattoos=sum(w*d$first_observed_in_snapshot))
 }))
})
result<-do.call(rbind,summaries)
result<-result[order(result$scenario,result$year,
 match(result$zone,zones)),,drop=FALSE]
total<-do.call(rbind,lapply(split(result,interaction(result$scenario,result$zone,
 drop=TRUE)),function(d) {
 den<-sum(d$expected_legacy_zone_observed_tattoos)
 data.frame(scenario=d$scenario[1],zone=d$zone[1],
    n_expected_observed_tattoo_years=den,
    n_expected_observed_following_year=sum(d$n_expected_next_year_recaptures),
    conditional_observed_return=if(den>0)
     sum(d$n_expected_next_year_recaptures)/den else NA_real_)
}))
out<-Sys.getenv("V12_ZONE_BRIDGE_OUT","")
if(!nzchar(out))out<-file.path("outputs","v12_legacy_zone_bridge",
 paste0("bridge_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Output exists: ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(result,file.path(out,"01_annual_observed_zone_return.csv"),row.names=FALSE)
write.csv(total,file.path(out,"02_pooled_observed_zone_return.csv"),row.names=FALSE)
writeLines(c(paste0("snapshot=",snap),paste0("zone_audit=",zone_dir),
 "All probabilities derived from HISTORICAL V11R2 three-chain posterior.",
 "ZONE: central 50/65/80 percent historical detector hulls, NOT approved biological core.",
 "Outside hull is not permanent emigration; areas moved historically.",
 "Unobserved next year conflates survival, movement, availability and detection.",
 "First observed is not proof of immigration or recruitment.",
 "Location posteriors are smoothed using observations from later years: DO NOT use as",
 "independent prospective survival predictors or claim unbiased zone-survival effects.",
 "No known zero-effort occasions; this is a descriptive bridge, NOT a CJS fit.",
 "2025 excluded from next-year observations due to absent 2026 follow-up."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("=== V12 HISTORICAL V11R2 POSTERIOR BRIDGE (NOT SURVIVAL) ===\n")
print(total,row.names=FALSE,digits=4)
cat("Annual summaries:",nrow(result),"; saved:",out,"\n")
