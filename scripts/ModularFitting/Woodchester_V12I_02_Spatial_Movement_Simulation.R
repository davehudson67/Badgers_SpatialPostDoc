#!/usr/bin/env Rscript
# Woodchester V12I-02: continuous-space demographic simulation
# SYNTHETIC ANIMALS ONLY. V11 coordinates are used for GEOMETRY ONLY.
# This does not fit parameters to badger data and is NOT an emigration estimate.
#
# Outputs:
#   outputs/v12_immigration_prototype/v12i02_truth.rds
#   outputs/v12_immigration_prototype/v12i02_annual_summary.csv
#   outputs/v12_immigration_prototype/v12i02_observed_encounters.csv
#   outputs/v12_immigration_prototype/v12i02_validation.csv
#
# Core tests: (i) live movement through unobserved years; (ii) occasional
# outside-hull states; (iii) returns after missed years; (iv) all states valid.

set.seed(20261109)
out <- "outputs/v12_immigration_prototype"
dir.create(out, recursive=TRUE, showWarnings=FALSE)
f <- Sys.glob("results/V11R2_RES50_*_1932_CHAIN1.rds")
if (length(f) != 1L) stop("Expected exactly one full V11R2 RES50 chain 1 RDS")
v11 <- readRDS(f)
det <- as.data.frame(v11$detectors)
stopifnot(all(c("x","y","Sett_Clean") %in% names(det)))
stopifnot(nrow(det)>2L, all(is.finite(det$x)), all(is.finite(det$y)))
rm(v11); gc(verbose=FALSE)

# Not an effort estimate. Each detector is treated as potentially observable
# in every simulated year. Historical effort must be audited separately.
xy <- as.matrix(det[c("x","y")])
h <- chull(xy[,1], xy[,2])
hx <- xy[h,1]; hy <- xy[h,2]
in_poly <- function(x,y,px,py) {
  result <- rep(FALSE,length(x))
  for(j in seq_along(px)) {
    k <- if(j == length(px)) 1L else j+1L
    cross <- (py[j]>y)!=(py[k]>y)
    atx <- px[j]+(y-py[j])*(px[k]-px[j])/(py[k]-py[j]+1e-30)
    result <- xor(result,cross & (x<atx))
  }
  result
}
# Explicitly illustrative settings, NOT inferred from Woodchester.
par <- c(psi=.12, entry=.15, annual_survival=.87,
         movement_switch=.08, local_step_sd_m=65,
         mobile_step_sd_m=650, sigma_detect_m=190,
         p0_per_detector_year=.035, death_recovery=.18)
N <- as.integer(Sys.getenv("V12I_N", "400"))
T <- as.integer(Sys.getenv("V12I_T", "16"))
if (is.na(N) || is.na(T) || N<10L || T<3L) stop("N>=10 and T>=3 required")
# States: N=not yet entered, A=alive, D=dead.
state <- matrix(1L,N,T)
posx <- matrix(NA_real_,N,T)
posy <- matrix(NA_real_,N,T)
obs <- matrix(0L,N,T) # 0 not seen, 1 live at detector, 2 newly dead recovered
obs_detector <- matrix(NA_integer_,N,T)
origin <- rep(NA_character_, N)
latent_mobile <- matrix(FALSE,N,T)
outside <- matrix(NA,N,T)
years <- seq_len(T)

# Entry is into the INSIDE population. We specify provenance
# synthetically: a local recruit enters near an inside detector; an
# immigrant is assigned to arrive across the hull perimeter and begins
# just inside that boundary. This is a modelled provenance assumption,
# not proof that a real badger originated outside the study population.
# No explicit pre-entry trajectory is simulated at this stage.
new_start <- function() {
  immigrant <- runif(1) < .5
  if (immigrant) {
    # Sample a hull edge and a point along it, then nudge inside.
    j <- sample.int(length(h), 1L)
    k <- if (j == length(h)) 1L else j + 1L
    u <- runif(1)
    boundary <- c((1-u)*hx[j]+u*hx[k], (1-u)*hy[j]+u*hy[k])
    centre <- c(mean(hx), mean(hy))
    point <- 0.96*boundary + 0.04*centre
  } else {
    # Rejection sampling keeps local recruitment inside the study proxy.
    point <- NULL
    for (attempt in seq_len(1000L)) {
      j <- sample.int(nrow(xy), 1L)
      candidate <- c(unname(xy[j,1])+rnorm(1,0,55),
                     unname(xy[j,2])+rnorm(1,0,55))
      if (in_poly(candidate[1], candidate[2], hx, hy)) {
        point <- candidate
        break
      }
    }
    if (is.null(point)) stop("Could not place local recruit inside hull")
  }
  s <- c(x=unname(point[1]), y=unname(point[2]),
         immigrant=as.numeric(immigrant))
  stopifnot(identical(names(s), c("x","y","immigrant")),
            all(is.finite(s)),
            in_poly(s["x"],s["y"],hx,hy))
  s
}
for(i in seq_len(N)) {
  if (runif(1)<par["psi"]) {
    state[i,1]<-2L
    s<-new_start()
    posx[i,1]<-s["x"];posy[i,1]<-s["y"]
    origin[i]<-if(s["immigrant"]==1) "immigrant" else "local_recruit"
  }
}
for(tt in seq_len(T)) {
  if(tt>1L) {
    for(i in seq_len(N)) {
      old<-state[i,tt-1]
      if(old==3L) {state[i,tt]<-3L;next}
      if(old==1L) {
        if(runif(1)<par["entry"]) {
          state[i,tt]<-2L
          s<-new_start()
          posx[i,tt]<-s["x"];posy[i,tt]<-s["y"]
          origin[i]<-if(s["immigrant"]==1) "immigrant" else "local_recruit"
        }
      } else {
        if(runif(1)>par["annual_survival"]) {
          state[i,tt]<-3L
        } else {
          state[i,tt]<-2L
          latent_mobile[i,tt] <- runif(1)<par["movement_switch"]
          sd_m<-if(latent_mobile[i,tt]) par["mobile_step_sd_m"] else par["local_step_sd_m"]
          posx[i,tt]<-posx[i,tt-1]+rnorm(1,0,sd_m)
          posy[i,tt]<-posy[i,tt-1]+rnorm(1,0,sd_m)
        }
      }
    }
  }
  alive<-which(state[,tt]==2L)
  if(length(alive)) {
    outside[alive,tt]<-!in_poly(posx[alive,tt],posy[alive,tt],hx,hy)
    for(i in alive) {
      d2<-(xy[,1]-posx[i,tt])^2+(xy[,2]-posy[i,tt])^2
      p<-par["p0_per_detector_year"]*exp(-d2/(2*par["sigma_detect_m"]^2))
      hit<-which(runif(length(p))<p)
      if(length(hit)) {
        j<-hit[sample.int(length(hit),1L)]
        obs[i,tt]<-1L
        obs_detector[i,tt]<-j
      }
    }
  }
  if(tt>1L) {
    newly_dead<-which(state[,tt-1]==2L & state[,tt]==3L)
    if(length(newly_dead)) {
      detected_dead<-newly_dead[runif(length(newly_dead))<par["death_recovery"]]
      obs[detected_dead,tt]<-2L
    }
  }
}
stopifnot(all(state %in% 1:3))
stopifnot(!any(obs==1L & state!=2L))
stopifnot(!any(obs==2L & state!=3L))
bad_alive <- which(state==2L & (!is.finite(posx) | !is.finite(posy)), arr.ind=TRUE)
if (nrow(bad_alive)) {
  print(utils::head(bad_alive,10))
  stop("Alive individuals missing valid positions: ",nrow(bad_alive))
}
stopifnot(all(is.finite(posx[state==2L])),all(is.finite(posy[state==2L])))
stopifnot(all(is.na(posx[state!=2L])),all(is.na(posy[state!=2L])))
# Alive animals can be beyond hull. No absorbing emigration state in this model.
annual<-data.frame(year=years,
  n_not_yet_entered=colSums(state==1L),
  n_alive=colSums(state==2L),
  n_dead_cumulative=colSums(state==3L),
  n_alive_outside_hull=colSums(outside,na.rm=TRUE),
  n_live_detected=colSums(obs==1L),
  n_new_dead_recovered=colSums(obs==2L))
# Validate some individuals known alive outside later return inside,
# even when earlier annual captures were missed.
was_outside_then_inside <- 0L
gap_then_seen <- 0L
for(i in seq_len(N)) {
  oi<-which(outside[i,] %in% TRUE)
  ii<-which(outside[i,] %in% FALSE)
  if(length(oi) && length(ii) && any(outer(oi,ii,"<"))) was_outside_then_inside <- was_outside_then_inside+1L
  seen<-which(obs[i,]==1L)
  if(length(seen)>1L && any(diff(seen)>=2L)) gap_then_seen<-gap_then_seen+1L
}
validation<-data.frame(metric=c("candidate_individuals","ever_live_detected",
  "total_live_records","dead_recoveries","individuals_outside_then_inside",
  "individuals_with_detection_gap_then_return","alive_outside_person_years",
  "synthetic_immigrant_origins","synthetic_local_recruit_origins"),
  value=c(N,sum(rowSums(obs==1L)>0),sum(obs==1L),sum(obs==2L),
          was_outside_then_inside,gap_then_seen,
          sum(outside,na.rm=TRUE),
          sum(origin=="immigrant",na.rm=TRUE),
          sum(origin=="local_recruit",na.rm=TRUE)))
enc<-which(obs>0,arr.ind=TRUE)
records<-data.frame(id=enc[,1],year=enc[,2],
  event=ifelse(obs[enc]==1L,"LIVE","DEAD_RECOVERY"),
  detector_index=obs_detector[enc],
  detector_name=ifelse(is.na(obs_detector[enc]),NA_character_,
                       det$Sett_Clean[pmax(1L,ifelse(is.na(obs_detector[enc]),1L,obs_detector[enc]))]))
records$detector_name[is.na(records$detector_index)] <- NA_character_
saveRDS(list(parameters=par,detectors=det,source="synthetic",
             state=state,x=posx,y=posy,outside_hull=outside,
             mobile_truth=latent_mobile,origin_truth=origin,
             observations=obs,detector_index=obs_detector,
             annual=annual,validation=validation),
        file.path(out,"v12i02_truth.rds"))
write.csv(annual,file.path(out,"v12i02_annual_summary.csv"),row.names=FALSE)
write.csv(records,file.path(out,"v12i02_observed_encounters.csv"),row.names=FALSE)
write.csv(validation,file.path(out,"v12i02_validation.csv"),row.names=FALSE)
cat("\n=== V12I-02 CONTINUOUS-SPACE SIMULATION ===\n")
cat("Reference detector locations:", nrow(det),"\n")
cat("NOTE: all rates here are synthetic illustrative values.\n")
print(validation,row.names=FALSE)
cat("\nAnnual summary (first/last):\n")
print(rbind(head(annual,3),tail(annual,3)),row.names=FALSE)
cat("\nOutputs:",out,"\n")
cat("No demographic or spatial parameters were fitted in V12I-02.\n")
