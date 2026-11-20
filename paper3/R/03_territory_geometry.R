#!/usr/bin/env Rscript
# Paper 3 step 3: group distances and adjacency from the annual bait-marking
# territories (data/spatial/social_group_boundaries/territories_YYYY.shp),
# which are independent of trapping. Polygon labels are main-sett names, so
# the step also writes the polygon-vs-capture name crosswalk to resolve.
# ADJ_TOL_M (default 10): polygons within this edge distance are adjacent.
source("paper3/R/common.R")
suppressPackageStartupMessages(library(sf))
s <- p3_snapshot()
tol <- as.numeric(Sys.getenv("ADJ_TOL_M", "10"))
files <- Sys.glob("data/spatial/social_group_boundaries/territories_*.shp")
pairs <- list(); polys <- list()
for (f in files) {
  yr <- as.integer(sub(".*_(\\d{4})\\.shp$", "\\1", f))
  p <- st_read(f, quiet = TRUE)
  lab <- intersect(c("SocialName", "Sett"), names(p))[1]
  if (is.na(lab)) p3_fail("No SocialName/Sett label in ", f)
  p$group <- p3_alias(p3_norm_group(p[[lab]]))
  p <- st_make_valid(p)
  if (anyNA(p$group)) p3_fail("Unlabelled polygon in ", f)
  p <- do.call(rbind, lapply(split(p, p$group), function(q)
    st_sf(group = q$group[1], geometry = st_union(q))))
  cen <- st_coordinates(st_point_on_surface(p))
  edge <- st_distance(p); cd <- as.matrix(dist(cen))
  ij <- which(upper.tri(cd), arr.ind = TRUE)
  pairs[[f]] <- data.frame(year = yr, g1 = p$group[ij[, 1]],
    g2 = p$group[ij[, 2]], centroid_dist_m = round(cd[ij], 1),
    edge_dist_m = round(as.numeric(edge[ij]), 1))
  polys[[f]] <- data.frame(year = yr, group = p$group,
    area_ha = round(as.numeric(st_area(p)) / 1e4, 2), x = cen[, 1], y = cen[, 2])
}
pairs <- do.call(rbind, pairs); polys <- do.call(rbind, polys)
pairs$adjacent <- pairs$edge_dist_m <= tol
utils::write.csv(pairs, file.path(s$out, "territory_pairs.csv"), row.names = FALSE)
utils::write.csv(polys, file.path(s$out, "territory_groups.csv"), row.names = FALSE)

# Crosswalk: trapped resident groups vs mapped polygons, by year.
h <- utils::read.csv(file.path(s$out, "group_year_histories.csv"))
cap <- unique(h[!is.na(h$group), c("year", "group")])
cap$trapped <- TRUE; polys$mapped <- TRUE
cw <- merge(cap, polys[, c("year", "group", "mapped")], all = TRUE)
cw[is.na(cw)] <- FALSE
cw <- cw[cw$year >= 1980 & !(cw$trapped & cw$mapped), ]
utils::write.csv(cw, file.path(s$out, "check_group_name_crosswalk.csv"),
                 row.names = FALSE)
cat("Years mapped:", length(files), "; groups per year:",
    paste(range(table(polys$year)), collapse = "-"), "\n")
cat("Adjacent pairs per year (median):",
    median(tapply(pairs$adjacent, pairs$year, sum)), "\n")
cat("Group-years trapped but not mapped:", sum(cw$trapped),
    "; mapped but not trapped:", sum(cw$mapped), "\n")
cat("Resolve names via paper3/group_name_aliases.csv, then re-run 02-04.\n")
