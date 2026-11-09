#!/usr/bin/env Rscript
# V12I-02c: descriptive calibration of synthetic V12I-02 to Woodchester.
# READ ONLY: does not refit models or write to Supabase.
# This audit compares observation summaries, NOT latent detection probabilities.
# Differences in population size, study duration, site coverage and detection
# opportunity prevent treating marginal totals as directly comparable rates.
out <- "outputs/v12_immigration_prototype/v12i02_empirical_calibration"
dir.create(out, recursive=TRUE, showWarnings=FALSE)
root <- "data/model_snapshots/v12_20261106T103144Z_1079872"
snap <- file.path(root,"qualifying_live.rds")
sim <- "outputs/v12_immigration_prototype/v12i02_truth.rds"
if (!file.exists(snap) || !file.exists(sim))
 stop("Missing frozen snapshot or V12I02 simulation. Run from repository root.")
x <- readRDS(snap)
z <- readRDS(sim)
need <- c("tattoo","capture_date","location_easting","location_northing")
if (!all(need %in% names(x))) stop("Missing frozen columns: ",paste(setdiff(need,names(x)),collapse=", "))
x$tattoo <- toupper(trimws(as.character(x$tattoo)))
x$capture_date <- as.Date(x$capture_date)
x <- x[!is.na(x$capture_date) & !is.na(x$tattoo) & nzchar(x$tattoo),,drop=FALSE]
x$year <- as.integer(format(x$capture_date,"%Y"))
x$quarter <- (as.integer(format(x$capture_date,"%m"))-1L)%/% 3L+1L
# Restrict to complete calendar years; annual model is on whole-year scale.
x <- x[x$year <= 2025,,drop=FALSE]
# A recorded live encounter can have multiple source rows in a day;
# use tattoo x date when calibrating frequency rather than row count.
xday <- unique(x[c("tattoo","capture_date","year","quarter")])
xy <- x[c("tattoo","capture_date","year","location_easting","location_northing")]
xy$location_easting <- suppressWarnings(as.numeric(xy$location_easting))
xy$location_northing <- suppressWarnings(as.numeric(xy$location_northing))
xy <- xy[is.finite(xy$location_easting) & is.finite(xy$location_northing),,drop=FALSE]
xy <- unique(xy)
# Multiple locations on a date are retained as a separate quality check,
# not flattened into a fictitious single observation position.
xdayyear <- unique(xday[c("tattoo","year")])
xdayyear <- xdayyear[order(xdayyear$tattoo,xdayyear$year),]
xby <- split(xdayyear$year,xdayyear$tattoo)
gap <- unlist(lapply(xby,function(v) if(length(v)>1) diff(sort(unique(v))) else integer(0)),use.names=FALSE)
year_counts <- as.data.frame(table(xdayyear$year),stringsAsFactors=FALSE)
names(year_counts) <- c("year","n_distinct_badgers_observed")
year_counts$year <- as.integer(as.character(year_counts$year))
year_counts$n_live_capture_days <- as.integer(table(factor(xday$year,levels=year_counts$year)))
quarter_counts <- as.data.frame(table(xday$year,xday$quarter),stringsAsFactors=FALSE)
names(quarter_counts) <- c("year","quarter","n_live_capture_days")
quarter_counts$year <- as.integer(as.character(quarter_counts$year))
quarter_counts$quarter <- as.integer(as.character(quarter_counts$quarter))
# Comparable animal-by-year summaries, conditional on EVER being observed.
yrs_sim <- seq_len(ncol(z$observations))
live_sim <- z$observations == 1L
sim_by_year <- data.frame(year=yrs_sim,
 n_distinct_badgers_observed=colSums(live_sim),
 n_live_capture_days=colSums(live_sim))
sim_recap <- rowSums(live_sim)
real_recap <- table(xdayyear$tattoo)
# Annual gap patterns for detected individuals; absence is not emigration.
sim_years <- lapply(seq_len(nrow(live_sim)),function(i) which(live_sim[i,]))
sim_gap <- unlist(lapply(sim_years,function(v) if(length(v)>1) diff(v) else integer(0)),use.names=FALSE)
real_freq <- as.integer(table(xdayyear$tattoo))
sim_freq <- sim_recap[sim_recap>0]
freq_summary <- function(v,source) {
 data.frame(source=source,n_ever_observed=length(v),
            prop_single_year=mean(v==1L),
            prop_2plus_years=mean(v>=2L),
            prop_5plus_years=mean(v>=5L),
            median_observed_years=median(v),mean_observed_years=mean(v))
}
gap_summary <- function(v,source) {
 data.frame(source=source,n_intervals=length(v),
            prop_next_year=mean(v==1L),
            prop_one_missing_year=mean(v==2L),
            prop_2plus_missing_years=mean(v>=3L),
            maximum_gap_years=if(length(v))max(v) else NA_integer_)
}
comparison <- rbind(freq_summary(real_freq,"Woodchester 1976-2025"),
                    freq_summary(sim_freq,"V12I02 simulation 16 years"))
gaps <- rbind(gap_summary(gap,"Woodchester 1976-2025"),
              gap_summary(sim_gap,"V12I02 simulation 16 years"))
# Distances between observed positions in successive *distinct* years;
# may have more than one point per year, so use daily coordinate medians.
position <- aggregate(cbind(location_easting,location_northing) ~ tattoo+year,xy,median)
position <- position[order(position$tattoo,position$year),]
spatial <- do.call(rbind,lapply(split(position,position$tattoo),function(d) {
 if(nrow(d)<2L)return(NULL)
 data.frame(from_year=head(d$year,-1),to_year=tail(d$year,-1),
            step_m=sqrt(diff(d$location_easting)^2+diff(d$location_northing)^2))
}))
if(is.null(spatial)) spatial <- data.frame(from_year=integer(0),to_year=integer(0),step_m=numeric(0))
# Synthetic captures are at detectors; compare corresponding detector distances.
det <- z$detectors
enc <- which(live_sim,arr.ind=TRUE)
simsp <- data.frame(id=enc[,1],year=enc[,2],detector=z$detector_index[enc])
simsp <- simsp[order(simsp$id,simsp$year),]
sim_steps <- do.call(rbind,lapply(split(simsp,simsp$id),function(d) {
 if(nrow(d)<2L)return(NULL)
 # Exactly one recorded detector per animal-year in simulator.
 dx <- diff(det$x[d$detector]);dy <- diff(det$y[d$detector])
 data.frame(from_year=head(d$year,-1),to_year=tail(d$year,-1),
            step_m=sqrt(dx^2+dy^2))
}))
if(is.null(sim_steps))sim_steps<-data.frame(from_year=integer(0),to_year=integer(0),step_m=numeric(0))
spatial_summary <- function(d,source) {
 data.frame(source=source,n_observed_transitions=nrow(d),
 median_observed_step_m=if(nrow(d))median(d$step_m) else NA_real_,
 p90_observed_step_m=if(nrow(d))unname(quantile(d$step_m,.9)) else NA_real_,
 median_year_gap=if(nrow(d))median(d$to_year-d$from_year) else NA_real_)
}
spatial_comp <- rbind(spatial_summary(spatial,"Woodchester"),
                      spatial_summary(sim_steps,"Simulation"))
write.csv(comparison,file.path(out,"01_observed_frequency.csv"),row.names=FALSE)
write.csv(gaps,file.path(out,"02_annual_gap_summary.csv"),row.names=FALSE)
write.csv(spatial_comp,file.path(out,"03_spatial_recapture_summary.csv"),row.names=FALSE)
write.csv(year_counts,file.path(out,"04_woodchester_annual_counts.csv"),row.names=FALSE)
write.csv(quarter_counts,file.path(out,"05_woodchester_quarterly_counts.csv"),row.names=FALSE)
write.csv(sim_by_year,file.path(out,"06_simulated_annual_counts.csv"),row.names=FALSE)
cat("\n=== V12I-02c EMPIRICAL OBSERVATION CALIBRATION ===\n")
cat("Woodchester tattoos with records:",length(real_freq),"\n")
cat("Woodchester live capture-days:",nrow(xday),"\n")
cat("Woodchester spatially referenced records:",nrow(xy),"\n")
cat("\nObserved-years frequency (ever detected, different durations):\n")
print(comparison,row.names=FALSE,digits=3)
cat("\nGap intervals (years between observed years):\n")
print(gaps,row.names=FALSE,digits=3)
cat("\nObserved geographical recapture steps (not latent movement):\n")
print(spatial_comp,row.names=FALSE,digits=3)
cat("\nIMPORTANT: real and simulated periods/populations are different.\n")
cat("Annual capture gaps and step distances are descriptive, NOT estimators of\n",
    "true detection, immigration, emigration or survival.\n",sep="")
cat("Outputs:",out,"\n")
