#!/usr/bin/env Rscript
# Postprocess V11R2 exploratory core/periphery/outside audit. READ ONLY.
# Conditional zone transitions are based on expected joint posterior counts,
# not on hard zone assignments or independent marginal probabilities.
base <- Sys.getenv("ZONE_AUDIT_DIR","")
if(!nzchar(base) || !dir.exists(base)) stop("Set ZONE_AUDIT_DIR to existing audit output")
tp <- file.path(base,"05_consecutive_year_transition_probabilities.csv")
op <- file.path(base,"04_individual_annual_zone_probabilities.csv")
dp <- file.path(base,"01_detector_geometry_reference.csv")
if(!all(file.exists(c(tp,op,dp))))
 stop("Missing required source CSVs from V11R2 zone audit")
tr <- read.csv(tp,check.names=FALSE,stringsAsFactors=FALSE)
oc <- read.csv(op,stringsAsFactors=FALSE)
det <- read.csv(dp,stringsAsFactors=FALSE)
zones <- c("core","periphery","outside")
cross <- as.vector(t(outer(zones,zones,function(a,b)paste0(a,"_to_",b))))
# By-row flattening: core->core/core->periphery/core->outside, then periphery,...
if(!all(c("scenario","tattoo","from_year","to_year","observed_both",cross)%in%names(tr)))
 stop("Missing expected joint transition fields")
if(!all(c("scenario","tattoo","year","p_core","p_periphery","p_outside")%in%names(oc)))
 stop("Missing expected annual occupancy fields")
if(!nrow(tr)||anyNA(tr[cross])||anyNA(oc[paste0("p_",zones)]))
 stop("Missing transition/occupancy data")
if(any(abs(rowSums(tr[cross])-1)>1e-6)) stop("Transition rows do not sum to one")
if(any(abs(rowSums(oc[paste0("p_",zones)])-1)>1e-6)) stop("Occupancy rows do not sum to one")
if(any(tr$to_year != tr$from_year+1L)) stop("Non-consecutive intervals present")
# Make a transparent aggregate conditional-on-origin transition table.
make_conditional <- function(d,scenario,subset) {
  joint <- colSums(d[cross])
  total <- nrow(d)
  if(total==0L)return(NULL)
  out <- do.call(rbind,lapply(zones,function(from) {
    p <- joint[paste0(from,"_to_",zones)]
    denom <- sum(p)
    data.frame(scenario=scenario,subset=subset,origin=from,
       n_intervals=total,expected_origin_intervals=unname(denom),
       destination=zones,
       conditional_probability=if(denom>0) unname(p/denom) else NA_real_,
       joint_probability_of_all_intervals=unname(p/total))
  }))
  out
}
pieces <- list()
for(s in unique(tr$scenario)) {
 d <- tr[tr$scenario==s,,drop=FALSE]
 pieces[[length(pieces)+1L]] <- make_conditional(d,s,"all_modelled_intervals")
 sub <- d[!is.na(d$observed_both)&d$observed_both,,drop=FALSE]
 if(nrow(sub)) pieces[[length(pieces)+1L]] <- make_conditional(sub,s,"detected_both_years")
}
tab <- do.call(rbind,pieces)
stopifnot(nrow(tab)>0L)
# Relative year trends in occupancy, conditional on the set of V11 modelled
# states in each year; these cannot be interpreted as population density.
yrs <- do.call(rbind,lapply(split(oc,interaction(oc$scenario,oc$year,drop=TRUE)),
 function(d) data.frame(scenario=d$scenario[1],year=d$year[1],
    n_states=nrow(d),
    n_observed_in_year=sum(d$observed_in_year,na.rm=TRUE),
    mean_core=mean(d$p_core),mean_periphery=mean(d$p_periphery),
    mean_outside=mean(d$p_outside))))
yrs <- yrs[order(yrs$scenario,yrs$year),,drop=FALSE]
# Source files are not mutated. New timestamped output, refuse overwrite.
out <- Sys.getenv("ZONE_SUMMARY_OUT","")
if(!nzchar(out))out <- file.path("outputs","v11r2_core_periphery",
 paste0("conditional_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Refusing to overwrite ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(tab,file.path(out,"01_conditional_zone_transitions.csv"),row.names=FALSE)
write.csv(yrs,file.path(out,"02_annual_zone_occupancy_and_observation.csv"),row.names=FALSE)
writeLines(c(paste0("source_audit=",base),
  "conditional_probabilities= sum posterior joint transitions / sum posterior origin occupancy",
  "Each consecutive tattoo-year interval is weighted once; not a fitted biological transition probability.",
  "subset detected_both_years is selected by observed data and has recapture-selection bias.",
  "Core/scenario boundaries are central-detector convex hulls, not historically verified areas.",
  "Outside means outside global detector hull, not emigration; historical V11R2 not reconciled.",
  "Annual occupancy means conditional on V11R2 modelled states, NOT population density.",
  "V11R2 smoothed posterior states may contain future observations; no predictive validation."),
  file.path(out,"README_ASSUMPTIONS.txt"))
cat("=== CONDITIONAL ORIGIN -> DESTINATION, ALL MODELLED INTERVALS ===\n")
print(tab[tab$subset=="all_modelled_intervals",
          c("scenario","origin","destination","expected_origin_intervals",
            "conditional_probability")],row.names=FALSE,digits=3)
cat("\n=== YEAR RANGE / SUPPORT ===\n")
for(s in unique(yrs$scenario)) {
 d<-yrs[yrs$scenario==s,,drop=FALSE]
 cat(s,": ",min(d$year),"-",max(d$year)," with ",
      nrow(d)," calendar years; min/max modelled states ",
      min(d$n_states),"/",max(d$n_states),"\n",sep="")
}
cat("Output:",out,"\n")
cat("Exploratory retrospective posterior summary only; NO refit.\n")
