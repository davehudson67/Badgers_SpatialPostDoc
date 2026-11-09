#!/usr/bin/env Rscript
# V11R2 EXPLORATORY core/periphery/outside posterior audit.
# READ-ONLY: existing 3-chain V11R2 spatial posterior; no model or DB writes.
# Illustrative nested detector hulls are sensitivity scenarios, NOT validated
# biological or effort-based study area boundaries. NO immigration inference.
# Only consecutive-year transitions are reported, from JOINT posterior draws.
# Historical V11R2 inputs remain pending reconciliation with curated Supabase.
norm <- function(x) toupper(trimws(as.character(x)))
files <- sort(Sys.glob("results/V11R2_RES50_*_1932_CHAIN[123].rds"))
if(length(files)!=3L) stop("Expected 3 V11R2 RES50 1932 chain files, found ",length(files))
draws_per_chain <- as.integer(Sys.getenv("ZONE_DRAWS_PER_CHAIN","60"))
if(is.na(draws_per_chain)||draws_per_chain<10L||draws_per_chain>200L)
  stop("ZONE_DRAWS_PER_CHAIN must be 10..200")
snap <- Sys.getenv("V12_SNAPSHOT","")
if(!nzchar(snap)||!file.exists(file.path(snap,"qualifying_live.rds"))||
   !file.exists(file.path(snap,"MANIFEST.txt")))
  stop("Set V12_SNAPSHOT to a valid Supabase-derived frozen snapshot")
manifest <- readLines(file.path(snap,"MANIFEST.txt"),warn=FALSE)
if(!any(grepl("^source_encounters=analysis.encounters_clean_v1",manifest)))
  stop("Snapshot manifest is not from approved source extractor")
x <- readRDS(file.path(snap,"qualifying_live.rds"))
if(!all(c("tattoo","capture_date") %in% names(x)))
  stop("Missing capture date/tattoo in frozen snapshot")
x$tattoo <- norm(x$tattoo); x$capture_date <- as.Date(x$capture_date)
x <- x[!is.na(x$capture_date)&!is.na(x$tattoo)&nzchar(x$tattoo),,drop=FALSE]
obs <- unique(paste(x$tattoo,as.integer(format(x$capture_date,"%Y")),sep="|"))
# A ray-casting polygon, vectorized over individual annual coordinates.
inside_poly <- function(x,y,px,py) {
  if(length(px)<3L) stop("Polygon needs 3+ vertices")
  inside <- rep(FALSE,length(x))
  n <- length(px)
  for(j in seq_len(n)) {
    k <- if(j==n) 1L else j+1L
    cross <- (py[j]>y)!=(py[k]>y)
    xcross <- px[j]+(y-py[j])*(px[k]-px[j])/(py[k]-py[j]+1e-30)
    inside <- xor(inside,cross&(x<xcross))
  }
  inside
}
# Convex hull of central detector subset; study extent = hull of all detectors.
z <- readRDS(files[[1]])
det <- as.data.frame(z$detectors)
if(!all(c("x","y")%in%names(det))||any(!is.finite(det$x))||
   any(!is.finite(det$y))) stop("Missing/invalid XY detector geometry")
if(nrow(det)<8L) stop("Not enough detectors for exploratory nested hulls")
if(anyDuplicated(paste(det$x,det$y))) stop("Duplicated detector coordinates")
idx <- as.data.frame(z$annual_state_index)
if(!all(c("tattoo","year","sample_column_x","sample_column_y") %in% names(idx)))
 stop("Invalid annual_state_index")
idx$tattoo <- norm(idx$tattoo)
idx$key <- paste(idx$tattoo,idx$year,sep="|")
if(anyDuplicated(idx$key)) stop("Duplicate tattoo-year index")
if(anyNA(idx$tattoo)||anyNA(idx$year)) stop("Missing tattoo/year index")
idx$observed_in_year <- idx$key %in% obs
idx <- idx[order(idx$tattoo,idx$year),,drop=FALSE]
rownames(idx) <- NULL
# Only consecutive years, so uncaught gaps are never interpreted as adjacent moves.
from <- which(idx$tattoo[-nrow(idx)]==idx$tattoo[-1L] &
   idx$year[-nrow(idx)]+1L==idx$year[-1L])
to <- from+1L
centre <- c(stats::median(det$x),stats::median(det$y))
rank <- order((det$x-centre[1])^2+(det$y-centre[2])^2)
fractions <- c(.50,.65,.80)
hull <- function(d) {
   h <- chull(d$x,d$y)
   if(length(h)<3L) stop("Degenerate detector hull")
   list(x=d$x[h],y=d$y[h])
}
outer <- hull(det)
geoms <- lapply(fractions,function(f) {
  n <- max(4L,min(nrow(det)-1L,ceiling(f*nrow(det))))
  d <- det[rank[seq_len(n)],,drop=FALSE]
  h <- hull(d)
  list(fraction=f,n_core_detectors=n,px=h$x,py=h$y)
})
names(geoms) <- sprintf("central_%02d",round(100*fractions))
# Include explicit outer hull as "outside": a point outside any detector
# hull is geographically outside sampled-site convex extent, NOT an emigrant.
out <- Sys.getenv("ZONE_AUDIT_OUT","")
if(!nzchar(out))
 out <- file.path("outputs","v11r2_core_periphery",
    paste0("audit_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out)) stop("Refusing to overwrite existing directory ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(data.frame(detector=seq_len(nrow(det)),
   sett=if("Sett_Clean"%in%names(det)) det$Sett_Clean else NA_character_,
   x=det$x,y=det$y,rank_from_global_centre=match(seq_len(nrow(det)),rank)),
 file.path(out,"01_detector_geometry_reference.csv"),row.names=FALSE)
hulls <- do.call(rbind,lapply(names(geoms),function(nm) {
 g<-geoms[[nm]]
 data.frame(scenario=nm,core_detector_count=g$n_core_detectors,
   vertex=seq_along(g$px),x=g$px,y=g$py)
}))
write.csv(hulls,file.path(out,"02_core_hull_vertices.csv"),row.names=FALSE)
write.csv(data.frame(vertex=seq_along(outer$x),x=outer$x,y=outer$y),
 file.path(out,"03_outer_detector_hull_vertices.csv"),row.names=FALSE)
occ_sum <- list();move_sum <- list()
total_draws <- 0L
for(ch in seq_along(files)) {
 if(ch>1L) {rm(z);invisible(gc());z <- readRDS(files[[ch]])}
 ix <- as.data.frame(z$annual_state_index)
 ix$key <- paste(norm(ix$tattoo),ix$year,sep="|")
 if(anyDuplicated(ix$key)||!setequal(ix$key,idx$key))
   stop("Index mismatch across chains")
 ix <- ix[match(idx$key,ix$key),,drop=FALSE]
 nm <- colnames(z$samples)
 cx <- match(ix$sample_column_x,nm)
 cy <- match(ix$sample_column_y,nm)
 if(anyNA(cx)||anyNA(cy)) stop("Missing latent coordinate monitor")
 pick <- unique(round(seq(1,nrow(z$samples),length.out=draws_per_chain)))
 mx <- as.matrix(z$samples[pick,cx,drop=FALSE])
 my <- as.matrix(z$samples[pick,cy,drop=FALSE])
 if(!identical(dim(mx),dim(my)) || any(!is.finite(mx))||
    any(!is.finite(my))) stop("Invalid posterior spatial samples")
 nr <- nrow(mx); ns <- ncol(mx); total_draws <- total_draws+nr
 outside <- matrix(!inside_poly(as.vector(mx),as.vector(my),outer$x,outer$y),
                   nrow=nr,ncol=ns)
 for(scenario in names(geoms)) {
   g <- geoms[[scenario]]
   core <- matrix(inside_poly(as.vector(mx),as.vector(my),g$px,g$py),
                  nrow=nr,ncol=ns)
   core[outside] <- FALSE
   zone <- matrix(2L,nrow=nr,ncol=ns)
   zone[core] <- 1L
   zone[outside] <- 3L
   occ_sum[[scenario]] <- if(is.null(occ_sum[[scenario]]))
       colSums(zone==1L)*0 else occ_sum[[scenario]]
   # State tallies per individual and year, retaining posterior uncertainty.
   if(is.null(occ_sum[[paste0(scenario,"_zone")]]))
     occ_sum[[paste0(scenario,"_zone")]] <- matrix(0,ns,3)
   for(k in 1:3)
     occ_sum[[paste0(scenario,"_zone")]][,k] <-
        occ_sum[[paste0(scenario,"_zone")]][,k]+colSums(zone==k)
   if(length(from)) {
     # Matched draw row for two endpoints preserves posterior dependence.
     aa<-zone[,from,drop=FALSE];bb<-zone[,to,drop=FALSE]
     if(is.null(move_sum[[scenario]]))
       move_sum[[scenario]] <- matrix(0,length(from),9)
     for(k in 1:3)for(l in 1:3) {
       v <- (k-1L)*3L+l
       move_sum[[scenario]][,v] <- move_sum[[scenario]][,v]+
          colSums((aa==k)&(bb==l))
     }
   }
 }
 cat("Chain ",ch,": ",nr," spatial posterior rows; ",ns,
     " annual individual states\n",sep="")
 rm(mx,my,outside);invisible(gc())
}
occ <- do.call(rbind,lapply(names(geoms),function(scenario) {
 p <- occ_sum[[paste0(scenario,"_zone")]]/total_draws
 data.frame(scenario=scenario,tattoo=idx$tattoo,year=idx$year,
   observed_in_year=idx$observed_in_year,
   p_core=p[,1],p_periphery=p[,2],p_outside=p[,3],
   uncertainty=1-apply(p,1,max))
}))
if(any(abs(occ$p_core+occ$p_periphery+occ$p_outside-1)>1e-7))
 stop("Occupancy probabilities do not sum to one")
write.csv(occ,file.path(out,"04_individual_annual_zone_probabilities.csv"),
 row.names=FALSE)
trans <- if(length(from)) do.call(rbind,lapply(names(geoms),function(scenario) {
 p <- move_sum[[scenario]]/total_draws
 colnames(p) <- as.vector(outer(c("core","periphery","outside"),
        c("core","periphery","outside"),paste,sep="_to_"))
 data.frame(scenario=scenario,tattoo=idx$tattoo[from],
  from_year=idx$year[from],to_year=idx$year[to],
  observed_both=idx$observed_in_year[from]&idx$observed_in_year[to],
  p,check.names=FALSE)
})) else data.frame()
if(nrow(trans)) {
 if(any(abs(rowSums(trans[,grepl("_to_",names(trans)),drop=FALSE])-1)>1e-7))
   stop("Transition probabilities do not sum to one")
 write.csv(trans,file.path(out,"05_consecutive_year_transition_probabilities.csv"),
   row.names=FALSE)
}
annual <- aggregate(cbind(p_core,p_periphery,p_outside)~scenario+year,
                    data=occ,FUN=mean)
annual$n_model_states <- as.integer(table(interaction(occ$scenario,occ$year))[
  interaction(annual$scenario,annual$year)])
write.csv(annual,file.path(out,"06_annual_model_state_occupancy.csv"),row.names=FALSE)
if(nrow(trans)) {
 transitions <- aggregate(trans[,grepl("_to_",names(trans)),drop=FALSE],
                           by=trans[,c("scenario","from_year")],FUN=mean)
 transitions$n_intervals <- as.integer(table(interaction(trans$scenario,trans$from_year))[
  interaction(transitions$scenario,transitions$from_year)])
 write.csv(transitions,file.path(out,"07_annual_mean_transition_probabilities.csv"),
           row.names=FALSE)
}
summary <- do.call(rbind,lapply(names(geoms),function(s) {
 d <- occ[occ$scenario==s,,drop=FALSE]
 u <- trans[trans$scenario==s,,drop=FALSE]
 data.frame(scenario=s,core_detectors=geoms[[s]]$n_core_detectors,
  n_annual_model_states=nrow(d),n_consecutive_intervals=nrow(u),
  mean_p_core=mean(d$p_core),mean_p_periphery=mean(d$p_periphery),
  mean_p_outside=mean(d$p_outside),
  fraction_states_uncertain=mean(d$uncertainty>.25),
  mean_p_core_to_periphery=if(nrow(u))mean(u$core_to_periphery) else NA_real_,
  mean_p_periphery_to_core=if(nrow(u))mean(u$periphery_to_core) else NA_real_)
}))
write.csv(summary,file.path(out,"08_scenario_sensitivity_summary.csv"),
 row.names=FALSE)
writeLines(c(paste0("git_commit=",tryCatch(system2("git",c("rev-parse","HEAD"),stdout=TRUE)[1],
 error=function(e)"UNKNOWN")),paste0("snapshot=",snap),
 paste0("legacy_files=",paste(files,collapse=";")),
 paste0("posterior_rows_total=",total_draws),
 "BOUNDARY: central 50/65/80 percent of LEGACY global detector coordinates,",
 "core = hull of selected central sites; periphery = remainder inside full detector hull;",
 "outside = beyond full detector hull (NOT an emigrant state).",
 "All are sensitivity scenarios, NOT historically effort-aware boundaries.",
 "PROBABILITIES: fitted latent positions, not independently validated biological locations.",
 "TRANSITIONS: consecutive annual states, paired posterior samples within each chain.",
 "ANNUAL: mean occupancy conditional on V11R2 modelled animal-year sample, NOT density.",
 "V11R2 historical coordinates/aliases NOT approved as current curated inputs.",
 "Current trapping effort/absence unverified; smoothed locations use future observations.",
 "DO NOT interpret outside occupancy as immigration/emigration or true survival."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("\n=== EXPLORATORY CORE / PERIPHERY / OUTSIDE AUDIT ===\n")
print(summary,row.names=FALSE)
cat("Saved outputs: ",out,"\n",sep="")
cat("NOT a fit, population density estimate, or immigration/emigration analysis.\n")
