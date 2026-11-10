#!/usr/bin/env Rscript
# V12: historical V11R2 joint posterior exchange between core, periphery,
# and outside the GLOBAL detector hull, by broad study era.
# READ ONLY. Descriptive POSTERIOR exchange, NOT immigration/emigration rate.
# Uses paired (joint) zone transition probabilities from saved old V11R2
# draws; NEVER multiplies independent annual zone marginals.
# Run:
# ZONE_AUDIT_DIR=outputs/v11r2_core_periphery/audit_20261109T134751Z \
# Rscript scripts/ModularFitting/Woodchester_V12_Core_Periphery_Exchange_Audit.R
dir <- Sys.getenv("ZONE_AUDIT_DIR","")
if(!nzchar(dir))stop("Set ZONE_AUDIT_DIR to existing V11R2 posterior zone audit")
path<-file.path(dir,"05_consecutive_year_transition_probabilities.csv")
if(!file.exists(path))stop("Missing paired zone transition file: ",path)
d<-read.csv(path,stringsAsFactors=FALSE,check.names=FALSE)
zones<-c("core","periphery","outside")
pairs<-as.vector(t(outer(zones,zones,paste,sep="_to_")))
required<-c("scenario","tattoo","from_year","to_year","observed_both",pairs)
if(!all(required%in%names(d)))
 stop("Missing joint posterior fields: ",paste(setdiff(required,names(d)),collapse=","))
if(anyNA(d[pairs])||any(d[pairs]< -1e-8)|any(d[pairs]>1+1e-8)||
 any(abs(rowSums(d[pairs])-1)>1e-6))
 stop("Invalid paired transition probabilities")
if(anyNA(d$from_year)|anyNA(d$to_year)|
 any(d$to_year!=d$from_year+1L))
 stop("Only consecutive annual intervals are allowed")
if(anyDuplicated(paste(d$scenario,d$tattoo,d$from_year,sep="|")))
 stop("Duplicate tattoo/year/scenario")
d$era<-cut(d$from_year,breaks=c(1976,1992,2008,2025),
 labels=c("1977-1992","1993-2008","2009-2025"),
 include.lowest=TRUE,right=TRUE)
if(anyNA(d$era))stop("Year outside analysis eras")
d$observed_both<-as.logical(d$observed_both)
if(anyNA(d$observed_both))stop("Missing both-year detection indicator")
# Expected origin and destination counts are calculated from JOINT
# posterior transitions. Asymmetric flows imply conditional spatial
# redistributions of the old (selected) modelled cohort, not net
# immigration, population growth, or a biological open-population rate.
summarise_group<-function(z,subset_label) {
 n<-nrow(z)
 if(n==0L)return(NULL)
 C<-matrix(colSums(z[pairs]),nrow=3,ncol=3,byrow=TRUE,
  dimnames=list(zones,zones))
 row_mass<-rowSums(C)
 flow<-as.data.frame(as.table(C),stringsAsFactors=FALSE)
 names(flow)<-c("origin","destination","expected_joint_intervals")
 flow$scenario<-z$scenario[1]
 flow$era<-as.character(z$era[1])
 flow$subset<-subset_label
 flow$n_modelled_intervals<-n
 flow$expected_origin_intervals<-row_mass[match(flow$origin,zones)]
 flow$p_destination_given_origin<-ifelse(flow$expected_origin_intervals>0,
  flow$expected_joint_intervals/flow$expected_origin_intervals,NA_real_)
 flow$expected_joint_per_100_intervals<-100*flow$expected_joint_intervals/n
 flow
}
outlist<-list()
k<-0L
for(s in unique(d$scenario))for(e in levels(d$era)) {
 z<-d[d$scenario==s & d$era==e,,drop=FALSE]
 if(!nrow(z))next
 k<-k+1L;outlist[[k]]<-summarise_group(z,"all_modelled_intervals")
 z<-z[z$observed_both,,drop=FALSE]
 if(nrow(z)) {
  k<-k+1L;outlist[[k]]<-summarise_group(z,"detected_both_years")
 }
}
flows<-do.call(rbind,outlist)
if(!nrow(flows))stop("No supported movement intervals")
flows<-flows[order(flows$scenario,flows$era,flows$subset,
 match(flows$origin,zones),match(flows$destination,zones)),,drop=FALSE]
rownames(flows)<-NULL
# Summarise in both directions without interpreting flux as actual entry.
directions<-data.frame(origin=c("core","periphery","periphery","outside"),
 destination=c("periphery","core","outside","periphery"),
 reverse_origin=c("periphery","core","outside","periphery"),
 reverse_destination=c("core","periphery","periphery","outside"))
summaries<-list();k<-0L
groupkey<-unique(flows[,c("scenario","era","subset")])
for(g in seq_len(nrow(groupkey))) {
 z<-flows[flows$scenario==groupkey$scenario[g]&
  flows$era==groupkey$era[g]&flows$subset==groupkey$subset[g],,drop=FALSE]
 findflow<-function(a,b) {
  x<-z$expected_joint_intervals[z$origin==a&z$destination==b]
  if(length(x)!=1L)stop("Missing zone transition pair ",a," -> ",b)
  x
 }
 k<-k+1L
 summaries[[k]]<-data.frame(
  scenario=z$scenario[1],era=z$era[1],subset=z$subset[1],
  n_modelled_intervals=z$n_modelled_intervals[1],
  expected_core_to_periphery=findflow("core","periphery"),
  expected_periphery_to_core=findflow("periphery","core"),
  expected_periphery_to_outside=findflow("periphery","outside"),
  expected_outside_to_periphery=findflow("outside","periphery"),
  expected_core_to_outside=findflow("core","outside"),
  expected_outside_to_core=findflow("outside","core"))
}
exchange<-do.call(rbind,summaries)
exchange$net_core_to_periphery<-exchange$expected_core_to_periphery-
 exchange$expected_periphery_to_core
exchange$net_periphery_to_outside<-exchange$expected_periphery_to_outside-
 exchange$expected_outside_to_periphery
# These are expected posterior move classifications per 100 *historic
# modelled* intervals, not per 100 animals in the wider population.
exchange$net_periphery_to_outside_per100_modelled_intervals<-
 100*exchange$net_periphery_to_outside/exchange$n_modelled_intervals
out<-Sys.getenv("V12_EXCHANGE_OUT","")
if(!nzchar(out))
 out<-file.path("outputs","v12_core_periphery_exchange",
  paste0("audit_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Refusing to overwrite ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(flows,file.path(out,"01_joint_transition_flows_by_era.csv"),
 row.names=FALSE)
write.csv(exchange,file.path(out,"02_bidirectional_exchange_by_era.csv"),
 row.names=FALSE)
writeLines(c(paste0("old_V11R2_posterior_zone_audit=",dir),
 "This is exploratory RETROSPECTIVE legacy V11R2 paired spatial posterior, not a new fit.",
 "Core is central 50/65/80 percentile historical detector hull, NOT biological core.",
 "Outside is outside the GLOBAL V11R2 detector convex hull, NOT proven emigration.",
 "Eras reflect the from-year of a modelled consecutive interval.",
 "Posterior transition masses are conditional on a historically selected cohort",
 "with time-varying capture and posterior smoothing using future observations.",
 "Both-year recaptured subset is strongly selected by detection and effort.",
 "Study coverage contracted: historical static geometry is not era-specific monitoring.",
 "No external habitat/dispersal boundary, external counts or trap effort is identified.",
 "Expected origin/destination counts are posterior probability mass, not field counts.",
 "Net flows do not estimate immigration, emigration, survival, population growth or density.",
 "Do NOT extrapolate absolute outside animals without explicit population/area assumptions.",
 "Current V11R3 fit is not used and is unchanged."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("=== V12 LEGACY V11R2 POSTERIOR CORE/PERIPHERY/OUTSIDE EXCHANGE ===\n")
print(exchange[exchange$subset=="all_modelled_intervals",],
 row.names=FALSE,digits=4)
cat("Saved:",out,"\n")
cat("Descriptions of exchange, NOT biological immigration or emigration estimates.\n")
