#!/usr/bin/env Rscript
# V11R2 core / periphery / outside: read-only geometry review.
# Uses existing exploratory audit CSVs, NOT current validated trapping effort.
# Writes a PNG with map panels + a separate detector/hull diagnostic CSV.
base <- Sys.getenv("ZONE_AUDIT_DIR","")
if(!nzchar(base)||!dir.exists(base)) stop("Set ZONE_AUDIT_DIR to the existing V11R2 zone audit")
f <- file.path(base,c("01_detector_geometry_reference.csv",
                     "02_core_hull_vertices.csv",
                     "03_outer_detector_hull_vertices.csv"))
if(!all(file.exists(f)))stop("Missing zone geometry inputs")
det <- read.csv(f[1],stringsAsFactors=FALSE)
core <- read.csv(f[2],stringsAsFactors=FALSE)
outer <- read.csv(f[3],stringsAsFactors=FALSE)
stopifnot(all(c("x","y","sett")%in%names(det)),
          all(c("scenario","vertex","x","y")%in%names(core)),
          all(c("vertex","x","y")%in%names(outer)))
if(any(!is.finite(det$x)|!is.finite(det$y))) stop("Non-finite detector coordinates")
scenarios <- c("central_50","central_65","central_80")
if(!all(scenarios%in%core$scenario))stop("Missing one or more scenarios")
out <- Sys.getenv("ZONE_GEOMETRY_OUT","")
if(!nzchar(out))out <- file.path("outputs","v11r2_core_periphery",
 paste0("geometry_",format(Sys.time(),"%Y%m%dT%H%M%SZ",tz="UTC")))
if(file.exists(out))stop("Refusing to overwrite existing output: ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
margin <- 0.06*max(diff(range(det$x)),diff(range(det$y)))
xlim <- range(det$x)+c(-margin,margin)
ylim <- range(det$y)+c(-margin,margin)
png(file.path(out,"01_candidate_zone_boundaries.png"),
    width=1600,height=640,res=140)
op <- par(no.readonly=TRUE)
par(mfrow=c(1,3),mar=c(4,4,4,1))
for(sc in scenarios) {
 c0 <- core[core$scenario==sc,,drop=FALSE]
 c0 <- c0[order(c0$vertex),,drop=FALSE]
 o0 <- outer[order(outer$vertex),,drop=FALSE]
 plot(det$x,det$y,asp=1,pch=16,cex=.55,
      xlab="Easting (m)",ylab="Northing (m)",
      xlim=xlim,ylim=ylim,main=paste(sc,"(exploratory)"))
 polygon(o0$x,o0$y,col=adjustcolor("steelblue",alpha.f=.12),
         border="steelblue",lwd=2)
 polygon(c0$x,c0$y,col=adjustcolor("darkolivegreen3",alpha.f=.45),
         border="darkgreen",lwd=2)
 points(det$x,det$y,pch=16,cex=.55)
 if(sc=="central_65") {
   idx <- which(!is.na(det$sett)&nzchar(det$sett))
   # Label all sites only when few; otherwise plot legends without obscuring map.
   if(length(idx)<=25) text(det$x[idx],det$y[idx],labels=det$sett[idx],
                           pos=3,cex=.48)
 }
 legend("bottomleft",legend=c("Core candidate","Full detector hull","Detector"),
        fill=c(adjustcolor("darkolivegreen3",alpha.f=.45),
               adjustcolor("steelblue",alpha.f=.12),NA),
        border=c("darkgreen","steelblue",NA),pch=c(NA,NA,16),
        bty="n",cex=.65)
}
par(op)
dev.off()
# Track number of duplicate or suspicious reference positions and footprint extents.
site <- data.frame(
 n_sites=nrow(det),n_distinct_xy=nrow(unique(det[c("x","y")])),
 min_x=min(det$x),max_x=max(det$x),min_y=min(det$y),max_y=max(det$y),
 n_missing_sett=sum(is.na(det$sett)|!nzchar(det$sett)))
write.csv(site,file.path(out,"02_legacy_detector_extent.csv"),row.names=FALSE)
writeLines(c(paste0("source_audit=",base),
 "Geometry is historical V11R2 detector coordinates, NOT validated modern sett XY.",
 "Core = convex hull of central 50/65/80 percent ranked detector locations.",
 "Periphery = within full detector convex hull but outside inner hull.",
 "Outside = beyond outer detector convex hull, NOT evidence of emigration.",
 "These boundaries are global across 1977-2025, NOT time-specific sampling footprints.",
 "Visually check hull geometry before any biological interpretation or refit."),
 file.path(out,"README_ASSUMPTIONS.txt"))
cat("Site extent:\n");print(site,row.names=FALSE)
cat("Map:",file.path(out,"01_candidate_zone_boundaries.png"),"\n")
cat("No model fit or data modification performed.\n")
