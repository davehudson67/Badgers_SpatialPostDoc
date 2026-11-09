#!/usr/bin/env Rscript
# V12I-02b: synthetic detection sensitivity (not fitted / no real data).
# Calls V12I-02 with separate output folders; reports capture-recapture
# information. Different scenarios are independent synthetic experiments;
# identical seeds do not guarantee identical latent paths because detector
# Bernoulli draws also consume the RNG stream.
sim <- "scripts/ModularFitting/Woodchester_V12I_02_Spatial_Movement_Simulation.R"
if (!file.exists(sim)) stop("Run from repo root")
base <- "outputs/v12_immigration_prototype/v12i02_detection_sensitivity"
dir.create(base, recursive=TRUE, showWarnings=FALSE)
scenarios <- data.frame(name=c("baseline","medium","higher"),
                        p0=c(.035,.070,.120),
                        sigma=c(190,190,190),stringsAsFactors=FALSE)
results <- vector("list",nrow(scenarios))
for (k in seq_len(nrow(scenarios))) {
  d<-scenarios[k,]
  folder<-file.path(base,d$name)
  log<-file.path(folder,"simulation.log")
  dir.create(folder,recursive=TRUE,showWarnings=FALSE)
  env <- c(
    paste0("V12I_OUT=",folder),
    paste0("V12I_P0_PER_DETECTOR_YEAR=",d$p0),
    paste0("V12I_SIGMA_DETECT_M=",d$sigma),
    "V12I_SEED=20261109"
  )
  status<-system2("Rscript", shQuote(sim), stdout=log,
                  stderr=log, env=env)
  if(status != 0L) {
    cat(readLines(log),sep="\n")
    stop("Scenario failed: ",d$name)
  }
  z<-readRDS(file.path(folder,"v12i02_truth.rds"))
  alive<-z$state==2L
  seen<-z$observations==1L
  inside<-alive & !is.na(z$outside_hull) & !z$outside_hull
  outside<-alive & !is.na(z$outside_hull) & z$outside_hull
  n<-rowSums(seen)
  origin<-z$origin_truth
  r1<-mean(n[which(origin=="immigrant")]>0)
  r2<-mean(n[which(origin=="local_recruit")]>0)
  results[[k]]<-data.frame(
    scenario=d$name, p0=d$p0, sigma_m=d$sigma,
    ever_detected=sum(n>0), single_capture=sum(n==1),
    recaptured_individuals=sum(n>=2),
    live_records=sum(seen), dead_recoveries=sum(z$observations==2L),
    detection_rate_inside=mean(seen[inside]),
    detection_rate_outside=mean(seen[outside]),
    ever_detected_immigrant= r1,
    ever_detected_local_recruit=r2)
}
summary<-do.call(rbind,results)
write.csv(summary,file.path(base,"detection_sensitivity_summary.csv"),
          row.names=FALSE)
cat("\n=== V12I-02b SYNTHETIC DETECTION SENSITIVITY ===\n")
print(summary, digits=3, row.names=FALSE)
cat("\nSaved:",file.path(base,"detection_sensitivity_summary.csv"),"\n")
cat("All parameters simulated. No spatial-demographic parameters fitted.\n")
