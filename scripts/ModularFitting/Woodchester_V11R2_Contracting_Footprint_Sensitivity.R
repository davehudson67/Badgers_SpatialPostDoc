#!/usr/bin/env Rscript
# V11R2 spatial coverage sensitivity (read-only, no model refitting).
# Compare historical fixed-site spatial posterior draws under three hypothetical
# capture-network footprints. All use the SAME existing V11R2 posterior.
#
# GLOBAL: all 119 historical V11R2 detector reference sites in every year.
# ERA: sites with >=1 observed live capture anywhere within that era.
# TRAILING5: sites with >=1 observed live capture in current or preceding 4 years.
#
# ERA / TRAILING5 are *recorded-capture evidence envelopes*, NOT true deployed
# trapping footprints. A site with zero captures may have been actively trapped.
# Global detector geometry is legacy V11R2, not reconciled to audited Supabase.
# No detection/effort parameters, survival, density or emigration estimated.

snapshot <- Sys.getenv("V12_SNAPSHOT", "")
continuity_dir <- Sys.getenv("ZONE_CONTINUITY_DIR", "")
if (!nzchar(snapshot) || !file.exists(file.path(snapshot, "MANIFEST.txt")))
  stop("Set V12_SNAPSHOT to a frozen Supabase snapshot")
metadata <- readLines(file.path(snapshot, "MANIFEST.txt"), warn=FALSE)
if (!any(grepl("^source_encounters=analysis.encounters_clean_v1", metadata)))
  stop("Unrecognised Supabase snapshot manifest")
fn <- file.path(continuity_dir, "02_sett_year_observed_capture_panel.csv")
if (!nzchar(continuity_dir) || !file.exists(fn))
  stop("Set ZONE_CONTINUITY_DIR to previous annual continuity audit output")
p <- read.csv(fn, stringsAsFactors=FALSE)
required <- c("detector", "sett", "x", "y", "year", "n_capture_days")
if (!all(required %in% names(p)))
  stop("Continuity panel missing columns: ", paste(setdiff(required, names(p)),collapse=", "))
years <- 1977:2025
p <- p[order(p$detector,p$year),,drop=FALSE]
det <- unique(p[c("detector","sett","x","y")])
det <- det[order(det$detector),,drop=FALSE]
if (anyDuplicated(p[c("detector","year")]) ||
    nrow(p)!=length(years)*nrow(det) ||
    !setequal(unique(p$year),years) ||
    any(!is.finite(det$x)) || any(!is.finite(det$y)))
  stop("Missing/duplicated site-years or invalid fixed detector coordinates")
if (anyNA(p$n_capture_days) || any(p$n_capture_days<0))
  stop("Invalid capture-day count")
site_rows <- match(p$detector,det$detector)
year_cols <- match(p$year,years)
obs <- matrix(NA_real_,nrow=nrow(det),ncol=length(years),
              dimnames=list(as.character(det$detector),as.character(years)))
obs[cbind(site_rows,year_cols)] <- as.numeric(p$n_capture_days)
if (anyNA(obs)) stop("Incomplete observed-site matrix")
eras <- list("1977-1992"=1977:1992,
             "1993-2008"=1993:2008,
             "2009-2025"=2009:2025)
era_name <- function(y) {
  if(y<=1992) "1977-1992" else if(y<=2008) "1993-2008" else "2009-2025"
}
scenarios <- c("global","era","trailing5")
active <- setNames(vector("list",length(scenarios)),scenarios)
for (sc in scenarios) {
  a <- matrix(FALSE,nrow=nrow(det),ncol=length(years),
              dimnames=list(rownames(obs),colnames(obs)))
  for (yi in seq_along(years)) {
    y <- years[yi]
    a[,yi] <- switch(sc,
       global=TRUE,
       era=rowSums(obs[,match(eras[[era_name(y)]],years),drop=FALSE]>0)>0,
       trailing5=rowSums(obs[,which(years>=y-4 & years<=y),drop=FALSE]>0)>0)
    # Every detector with an actual capture in year y must remain available in
    # the hypothetical active envelope. This is a necessary lower bound only.
    if (any(obs[,yi]>0 & !a[,yi]))
      stop("Captured detector incorrectly excluded from footprint")
    if (sum(a[,yi])<3L)
      stop("Too few observed sites to form a hull: ",sc," year ",y,
           ". Need a separately declared fallback, not an invented one.")
  }
  active[[sc]] <- a
}
# Fixed set coordinates are compared against the V11R2 detector locations
# used to fit the posterior (ID and XY).
files <- sort(Sys.glob("results/V11R2_RES50_*_1932_CHAIN[123].rds"))
if(length(files)!=3L)
 stop("Expected three fitted V11R2_RES50_1932 chain files, found ",length(files))
n_draw <- as.integer(Sys.getenv("ZONE_DRAWS_PER_CHAIN","60"))
radius <- as.numeric(Sys.getenv("ZONE_NEAR_RADIUS_M","250"))
if (is.na(n_draw) || n_draw<10L || n_draw>200L ||
    !is.finite(radius) || radius<=0)
  stop("Invalid ZONE_DRAWS_PER_CHAIN or ZONE_NEAR_RADIUS_M")
reference <- readRDS(files[1])
ix <- as.data.frame(reference$annual_state_index)
ix$tattoo <- toupper(trimws(as.character(ix$tattoo)))
ix$key <- paste(ix$tattoo,ix$year,sep="|")
if(anyDuplicated(ix$key) || anyNA(ix$year)) stop("Invalid posterior state index")
ix <- ix[order(ix$tattoo,ix$year),,drop=FALSE]
rownames(ix)<-NULL
legacy <- as.data.frame(reference$detectors)
if(!all(c("x","y") %in% names(legacy)) || nrow(legacy)!=nrow(det))
 stop("V11R2 reference detector count differs from continuity output")
# Require matching coordinate SETS; ordering isn't relevant.
coordkey <- function(z) paste(format(z$x,digits=12,trim=TRUE),
                             format(z$y,digits=12,trim=TRUE),sep=":")
if (!setequal(coordkey(legacy),coordkey(det)))
  stop("Legacy detector geometry differs from annual continuity reference")
if(any(!ix$year%in%years))
 stop("Spatial state years outside 1977..2025")
inside_polygon <- function(x,y,px,py) {
  v <- rep(FALSE,length(x))
  for(j in seq_along(px)) {
    k <- if(j==length(px)) 1L else j+1L
    cross <- (py[j]>y)!=(py[k]>y)
    xcross <- px[j]+(y-py[j])*(px[k]-px[j])/(py[k]-py[j]+1e-30)
    v <- xor(v,cross & x<xcross)
  }
  v
}
hulls <- lapply(scenarios,function(sc) lapply(seq_along(years),function(yi) {
  d<-det[active[[sc]][,yi],,drop=FALSE]
  h<-chull(d$x,d$y)
  if(length(h)<3L) stop("Degenerate convex hull for ",sc," ",years[yi])
  list(x=d$x[h],y=d$y[h],dx=d$x,dy=d$y)
}))
names(hulls)<-scenarios
nstate <- nrow(ix)
out_count <- matrix(0,nrow=nstate,ncol=length(scenarios),
                    dimnames=list(NULL,scenarios))
near_count <- out_count
dist_total <- out_count
n_sample <- 0L
idx_by_year <- split(seq_len(nstate),ix$year)
for (ch in seq_along(files)) {
  z <- if (ch==1L) reference else readRDS(files[ch])
  jx <- as.data.frame(z$annual_state_index)
  jx$key<-paste(toupper(trimws(as.character(jx$tattoo))),jx$year,sep="|")
  if(anyDuplicated(jx$key) || !setequal(jx$key,ix$key))
    stop("State indices differ between chains")
  jx <- jx[match(ix$key,jx$key),,drop=FALSE]
  cols<-colnames(z$samples)
  cx<-match(jx$sample_column_x,cols)
  cy<-match(jx$sample_column_y,cols)
  if(anyNA(cx)||anyNA(cy)) stop("Coordinate posterior monitors missing")
  rows<-unique(round(seq(1,nrow(z$samples),length.out=n_draw)))
  mx<-as.matrix(z$samples[rows,cx,drop=FALSE])
  my<-as.matrix(z$samples[rows,cy,drop=FALSE])
  if(any(!is.finite(mx))||any(!is.finite(my)))
    stop("Non-finite fitted positions")
  n_sample<-n_sample+nrow(mx)
  for(yy in names(idx_by_year)) {
    ids<-idx_by_year[[yy]]
    yi<-match(as.integer(yy),years)
    xx<-as.vector(mx[,ids,drop=FALSE])
    yypos<-as.vector(my[,ids,drop=FALSE])
    for(sc in scenarios) {
      g<-hulls[[sc]][[yi]]
      within<-inside_polygon(xx,yypos,g$x,g$y)
      # Nearest active-sett distance; the proximity threshold is a separate
      # diagnostic, not a capture probability or movement-classification rule.
      dsq<-rep(Inf,length(xx))
      for(j in seq_along(g$dx))
        dsq<-pmin(dsq,(xx-g$dx[j])^2+(yypos-g$dy[j])^2)
      dd<-sqrt(dsq)
      out_count[ids,sc]<-out_count[ids,sc]+
           colSums(matrix(!within,nrow=nrow(mx)))
      near_count[ids,sc]<-near_count[ids,sc]+
           colSums(matrix(dd<=radius,nrow=nrow(mx)))
      dist_total[ids,sc]<-dist_total[ids,sc]+
           colSums(matrix(dd,nrow=nrow(mx)))
    }
  }
  cat("Chain ",ch,": ",nrow(mx)," posterior draws over ",nstate,
      " fitted annual positions\n",sep="")
  rm(z,mx,my); invisible(gc(verbose=FALSE))
}
if(n_sample==0L)stop("No posterior draws")
states<-do.call(rbind,lapply(scenarios,function(sc)
 data.frame(scenario=sc,tattoo=ix$tattoo,year=ix$year,
   p_outside_capture_hull=out_count[,sc]/n_sample,
   p_within_near_radius=near_count[,sc]/n_sample,
   posterior_mean_nearest_m=dist_total[,sc]/n_sample)))
state_key<-paste(states$tattoo,states$year,sep="|")
if(any(!is.finite(states$p_outside_capture_hull)) ||
   any(states$p_outside_capture_hull < -1e-6 |
       states$p_outside_capture_hull > 1+1e-6))
 stop("Invalid zone probabilities")
# Uses existing posterior only. These are reclassified fitted locations, NOT
# refitted posterior results under new detector-availability assumptions.
siteyear<-do.call(rbind,lapply(scenarios,function(sc)
 data.frame(scenario=sc,year=years,era=vapply(years,era_name,character(1)),
   n_sites_envelope=colSums(active[[sc]]),
   n_sites_with_recorded_capture=colSums(obs>0),
   n_positive_capture_days=colSums(obs))))
annual<-do.call(rbind,lapply(split(states,interaction(states$scenario,states$year,
                                                      drop=TRUE)),
 function(d) data.frame(scenario=d$scenario[1],year=d$year[1],
    n_modelled_states=nrow(d),
    mean_p_outside_capture_hull=mean(d$p_outside_capture_hull),
    mean_p_near_sett=mean(d$p_within_near_radius),
    mean_nearest_sett_m=mean(d$posterior_mean_nearest_m))))
annual<-merge(annual,siteyear,by=c("scenario","year"),sort=FALSE)
annual<-annual[order(match(annual$scenario,scenarios),annual$year),,drop=FALSE]
period_summary<-do.call(rbind,lapply(split(annual,
 interaction(annual$scenario,annual$era,drop=TRUE)),function(d)
 data.frame(scenario=d$scenario[1],era=d$era[1],
  n_modelled_states=sum(d$n_modelled_states),
  min_sites=min(d$n_sites_envelope),max_sites=max(d$n_sites_envelope),
  weighted_mean_p_outside=sum(d$mean_p_outside_capture_hull*d$n_modelled_states)/
                          sum(d$n_modelled_states),
  weighted_mean_p_near_sett=sum(d$mean_p_near_sett*d$n_modelled_states)/
                          sum(d$n_modelled_states))))
period_summary<-period_summary[
 order(match(period_summary$scenario,scenarios),period_summary$era),,drop=FALSE]
out<-Sys.getenv("ZONE_COVERAGE_OUT","")
if(!nzchar(out))out<-file.path("outputs","v11r2_core_periphery",
 paste0("coverage_sensitivity_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Refusing to overwrite directory ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(siteyear,file.path(out,"01_scenario_site_envelopes_by_year.csv"),row.names=FALSE)
write.csv(annual,file.path(out,"02_annual_spatial_coverage_sensitivity.csv"),row.names=FALSE)
write.csv(period_summary,file.path(out,"03_era_coverage_comparison.csv"),row.names=FALSE)
write.csv(states,file.path(out,"04_posterior_state_footprint_probabilities.csv"),row.names=FALSE)
png(file.path(out,"05_coverage_sensitivity_time_series.png"),
 width=1450,height=900,res=140)
op<-par(no.readonly=TRUE)
par(mfrow=c(2,1),mar=c(4,5,3,1),las=1)
colours<-c(global="black",era="steelblue4",trailing5="darkorange3")
plot(NA,xlim=range(years),ylim=c(0,nrow(det)),xlab="Year",
 ylab="Sites in capture-evidence envelope",main="Hypothetical site coverage (not observed trap effort)")
for(sc in scenarios) {
 d<-siteyear[siteyear$scenario==sc,,drop=FALSE]
 lines(d$year,d$n_sites_envelope,col=colours[sc],lwd=2)
}
legend("topright",legend=scenarios,col=colours,lty=1,lwd=2,bty="n")
plot(NA,xlim=range(years),ylim=c(0,1),xlab="Year",
 ylab="Mean posterior P(outside envelope hull)",
 main="Same V11R2 posterior under different observation-footprint envelopes")
for(sc in scenarios) {
 d<-annual[annual$scenario==sc,,drop=FALSE]
 lines(d$year,d$mean_p_outside_capture_hull,col=colours[sc],lwd=2)
}
legend("topright",legend=scenarios,col=colours,lty=1,lwd=2,bty="n")
par(op);dev.off()
writeLines(c(paste0("snapshot=",snapshot),
 paste0("continuity_panel=",fn),
 paste0("fitted_chains=",paste(files,collapse=";")),
 paste0("n_posterior_rows=",n_sample),
 paste0("nearest_radius_m=",radius),
 "GLOBAL envelope=all fixed legacy detector points every year",
 "ERA envelope=detectors with a positive capture in the corresponding historical era",
 "TRAILING5 envelope=detectors with a capture in the year or preceding four years",
 "ERA and TRAILING5 are observed capture evidence envelopes, NOT trap deployment data",
 "No capture does not mean untrapped; positive capture confirms sampled at least once",
 "Convex hull can enclose unsampled patches; nearest-sett distance is an additional diagnostic",
 "Footprint scenarios do NOT change the posterior; this is reclassification, not refitting",
 "Model annual states reflect model cohort/selection, NOT population density",
 "No capture detection process, survival, emigration, immigration or density estimated",
 "Legacy V11R2 detector inputs remain to be reconciled with audited Supabase"),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("\n=== ERA-DEPENDENT SPATIAL COVERAGE (RECLASSIFICATION ONLY) ===\n")
print(period_summary,row.names=FALSE,digits=4)
cat("\nOutput: ",out,"\n",sep="")
cat("No model refits, true effort reconstruction, or database changes.\n")
