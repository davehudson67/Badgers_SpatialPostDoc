# WOODCHESTER V3 SPATIAL AUDIT
# Run after the V3 data-preparation section so these objects exist:
# grid, detectors, habitat_mat, SG_mat, zone_mat, cell_size,
# grid_xmin, grid_xmax, grid_ymin, grid_ymax

library(tidyverse)
library(sf)

RADII_M <- c(100,200,300,500,1000)
SIGMA_MOVE_TEST <- c(60,100,150)
DETECTOR_RADII_M <- c(100,200,300,500)
OUT_DIR <- "results/V3_spatial_audit"
dir.create(OUT_DIR,recursive=TRUE,showWarnings=FALSE)

req <- c("grid","detectors","habitat_mat","SG_mat","zone_mat","cell_size",
         "grid_xmin","grid_xmax","grid_ymin","grid_ymax")
miss <- req[!vapply(req,exists,logical(1),inherits=TRUE)]
if(length(miss)) stop("Missing objects: ",paste(miss,collapse=", "))

cat("\n========================================\nV3 SPATIAL AUDIT\n========================================\n")
cat("Grid cells:",nrow(grid),"\nCore:",sum(grid$zone==1),
    " Peripheral:",sum(grid$zone==2),"\nLand:",sum(grid$habitat==1),
    " Lake:",sum(grid$habitat==0),"\nDetectors:",nrow(detectors),"\n")

lookup_xy <- function(x,y){
  col <- floor((x-grid_xmin)/cell_size)+1L
  row <- floor((grid_ymax-y)/cell_size)+1L
  inb <- row>=1L & row<=nrow(habitat_mat) & col>=1L & col<=ncol(habitat_mat)
  SG <- habitat <- zone <- rep(NA_integer_,length(x)); ok <- which(inb)
  SG[ok] <- SG_mat[cbind(row[ok],col[ok])]
  habitat[ok] <- habitat_mat[cbind(row[ok],col[ok])]
  zone[ok] <- zone_mat[cbind(row[ok],col[ok])]
  tibble(row_R=row,col_R=col,in_bounds=inb,SG_id=SG,habitat=habitat,zone=zone)
}

# 1. Detector location and spacing
det_lookup <- bind_cols(detectors,lookup_xy(detectors$x,detectors$y))
det_by_zone <- det_lookup %>% count(zone,habitat,name="n_detectors")
det_by_sg <- det_lookup %>% count(zone,SG_id,name="n_detectors") %>% arrange(zone,SG_id)

det_sf <- st_as_sf(det_lookup,coords=c("x","y"),crs=st_crs(grid),remove=FALSE)
if(nrow(det_sf)>1){
  Ddet <- st_distance(det_sf,det_sf)
  diag(Ddet) <- units::set_units(Inf,"m")
  det_lookup$nearest_detector_m <- as.numeric(apply(Ddet,1,min))
} else det_lookup$nearest_detector_m <- NA_real_

det_spacing_zone <- det_lookup %>% group_by(zone) %>%
  summarise(n=n(),median_nn_m=median(nearest_detector_m,na.rm=TRUE),
            mean_nn_m=mean(nearest_detector_m,na.rm=TRUE),
            p10_nn_m=quantile(nearest_detector_m,.10,na.rm=TRUE),
            p90_nn_m=quantile(nearest_detector_m,.90,na.rm=TRUE),.groups="drop")

cat("\n--- DETECTORS BY ZONE ---\n"); print(det_by_zone,n=Inf)
cat("\n--- DETECTORS BY SG ---\n"); print(det_by_sg,n=Inf)
cat("\n--- DETECTOR NN SPACING BY ZONE ---\n"); print(det_spacing_zone,n=Inf)

# 2. Detector coverage of every grid cell
grid_sf <- st_as_sf(grid)
nearest_det_idx <- st_nearest_feature(grid_sf,det_sf)
nearest_det_m <- as.numeric(st_distance(grid_sf,det_sf[nearest_det_idx,],by_element=TRUE))

grid_cov <- grid %>% st_drop_geometry() %>%
  transmute(row_R,col_R,SG_id,zone,habitat,nearest_detector_m=nearest_det_m)

for(r in DETECTOR_RADII_M){
  near <- st_is_within_distance(grid_sf,det_sf,dist=r)
  grid_cov[[paste0("n_det_within_",r,"m")]] <- lengths(near)
}

grid_cov_zone <- grid_cov %>% filter(habitat==1) %>% group_by(zone) %>%
  summarise(n_cells=n(),area_km2=n()*cell_size^2/1e6,
            median_nearest_det_m=median(nearest_detector_m),
            mean_nearest_det_m=mean(nearest_detector_m),
            p90_nearest_det_m=quantile(nearest_detector_m,.90),
            p95_nearest_det_m=quantile(nearest_detector_m,.95),
            across(starts_with("n_det_within_"),mean,.names="mean_{.col}"),.groups="drop")

grid_cov_sg <- grid_cov %>% filter(habitat==1,zone==1) %>% group_by(SG_id) %>%
  summarise(n_cells=n(),area_km2=n()*cell_size^2/1e6,
            median_nearest_det_m=median(nearest_detector_m),
            mean_nearest_det_m=mean(nearest_detector_m),
            p90_nearest_det_m=quantile(nearest_detector_m,.90),
            max_nearest_det_m=max(nearest_detector_m),
            across(starts_with("n_det_within_"),mean,.names="mean_{.col}"),.groups="drop")

cat("\n--- GRID COVERAGE BY ZONE ---\n"); print(grid_cov_zone,n=Inf)
cat("\n--- GRID COVERAGE BY CORE SG ---\n"); print(grid_cov_sg,n=Inf)

# 3. SG geometry and shared boundaries from the regular 50 m grid
nr <- nrow(SG_mat); nc <- ncol(SG_mat)
core_ids <- sort(unique(grid$SG_id[grid$zone==1 & grid$SG_id!=999]))
adj_counts <- matrix(0L,length(core_ids),length(core_ids),dimnames=list(core_ids,core_ids))
core_periph_edge <- setNames(numeric(length(core_ids)),core_ids)
core_lake_edge <- setNames(numeric(length(core_ids)),core_ids)
outer_edge_by_zone <- c(core=0,peripheral=0)

for(r in seq_len(nr)) for(c in seq_len(nc)){
  sg0 <- SG_mat[r,c]; z0 <- zone_mat[r,c]; h0 <- habitat_mat[r,c]
  for(off in list(c(0L,1L),c(1L,0L))){
    rr <- r+off[1]; cc <- c+off[2]
    if(rr<=nr && cc<=nc){
      sg1 <- SG_mat[rr,cc]; z1 <- zone_mat[rr,cc]; h1 <- habitat_mat[rr,cc]
      if(z0==1 && z1==1 && sg0!=sg1 && sg0!=999 && sg1!=999){
        a <- match(as.character(sg0),rownames(adj_counts)); b <- match(as.character(sg1),colnames(adj_counts))
        adj_counts[a,b] <- adj_counts[a,b]+1L; adj_counts[b,a] <- adj_counts[b,a]+1L
      }
      if(z0!=z1){
        s <- if(z0==1) sg0 else sg1
        if(!is.na(s) && s!=999) core_periph_edge[as.character(s)] <- core_periph_edge[as.character(s)]+cell_size
      }
      if(h0!=h1){
        s <- if(z0==1 && h0==1) sg0 else if(z1==1 && h1==1) sg1 else NA
        if(!is.na(s) && s!=999) core_lake_edge[as.character(s)] <- core_lake_edge[as.character(s)]+cell_size
      }
    }
  }
  n_outer <- (r==1L)+(r==nr)+(c==1L)+(c==nc)
  if(n_outer){
    if(z0==1) outer_edge_by_zone["core"] <- outer_edge_by_zone["core"]+n_outer*cell_size
    if(z0==2) outer_edge_by_zone["peripheral"] <- outer_edge_by_zone["peripheral"]+n_outer*cell_size
  }
}

sg_geometry <- tibble(SG_id=core_ids,
  n_cells=vapply(core_ids,function(s)sum(SG_mat==s & zone_mat==1),numeric(1))) %>%
  mutate(area_m2=n_cells*cell_size^2,area_ha=area_m2/1e4,area_km2=area_m2/1e6,
         n_neighbours=vapply(SG_id,function(s)sum(adj_counts[as.character(s),]>0),numeric(1)),
         boundary_to_peripheral_m=core_periph_edge[as.character(SG_id)],
         boundary_to_lake_m=core_lake_edge[as.character(SG_id)])

adj_tbl <- as.data.frame(as.table(adj_counts),stringsAsFactors=FALSE) %>%
  transmute(SG1=as.integer(Var1),SG2=as.integer(Var2),shared_edge_m=Freq*cell_size) %>%
  filter(SG1<SG2,shared_edge_m>0) %>% arrange(SG1,SG2)

outer_boundary <- tibble(zone=c("core","peripheral"),
                         outer_boundary_m=as.numeric(outer_edge_by_zone))

cat("\n--- SG GEOMETRY ---\n"); print(sg_geometry,n=Inf)
cat("\n--- SG ADJACENCY ---\n"); print(adj_tbl,n=Inf)
cat("\n--- OUTER STATE-SPACE BOUNDARY ---\n"); print(outer_boundary,n=Inf)

# 4. Movement opportunity from each core-land cell
# Categories: same SG, neighbouring SG, non-neighbouring SG, peripheral.
core_idx <- which(grid$zone==1 & grid$habitat==1)
land_idx <- which(grid$habitat==1)
grid_xy <- st_coordinates(grid_sf)

is_neighbour <- function(s0,s1){
  if(is.na(s0)||is.na(s1)||s0==999||s1==999) return(FALSE)
  adj_counts[as.character(s0),as.character(s1)]>0
}

movement_rows <- list(); ii <- 0L
for(rad in RADII_M){
  cat("Movement opportunity radius:",rad,"m\n")
  candidates <- st_is_within_distance(grid_sf[core_idx,],grid_sf[land_idx,],dist=rad)
  for(a in seq_along(core_idx)){
    origin_idx <- core_idx[a]; dest_idx <- land_idx[candidates[[a]]]
    dest_idx <- dest_idx[dest_idx!=origin_idx]; if(!length(dest_idx)) next
    s0 <- grid$SG_id[origin_idx]; z1 <- grid$zone[dest_idx]; s1 <- grid$SG_id[dest_idx]
    catg <- ifelse(z1==2,"peripheral",ifelse(s1==s0,"same_SG",
      ifelse(vapply(s1,function(x)is_neighbour(s0,x),logical(1)),"neighbour_SG","nonneighbour_SG")))
    tab <- table(factor(catg,levels=c("same_SG","neighbour_SG","nonneighbour_SG","peripheral")))
    ii <- ii+1L
    movement_rows[[ii]] <- tibble(origin_idx=origin_idx,origin_SG=s0,radius_m=rad,
      same_SG=as.integer(tab["same_SG"]),neighbour_SG=as.integer(tab["neighbour_SG"]),
      nonneighbour_SG=as.integer(tab["nonneighbour_SG"]),peripheral=as.integer(tab["peripheral"]))
  }
}
movement_cell <- bind_rows(movement_rows) %>%
  mutate(total=same_SG+neighbour_SG+nonneighbour_SG+peripheral,
         across(c(same_SG,neighbour_SG,nonneighbour_SG,peripheral),
                ~.x/pmax(total,1),.names="prop_{.col}"))

movement_sg <- movement_cell %>% group_by(origin_SG,radius_m) %>%
  summarise(across(starts_with("prop_"),list(mean=mean,median=median),.names="{.col}_{.fn}"),.groups="drop")
movement_overall <- movement_cell %>% group_by(radius_m) %>%
  summarise(across(starts_with("prop_"),list(mean=mean,median=median),.names="{.col}_{.fn}"),.groups="drop")

cat("\n--- MOVEMENT OPPORTUNITY OVERALL ---\n"); print(movement_overall,n=Inf)
cat("\n--- MOVEMENT OPPORTUNITY BY SG ---\n"); print(movement_sg,n=Inf)

# 5. Gaussian-kernel-weighted movement opportunity
# This approximates how much baseline movement-kernel mass is available in
# each destination class before adding any SG resistance coefficient.
MAX_D <- 4*max(SIGMA_MOVE_TEST)
cand_kernel <- st_is_within_distance(grid_sf[core_idx,],grid_sf[land_idx,],dist=MAX_D)
kernel_rows <- list(); jj <- 0L

for(a in seq_along(core_idx)){
  origin_idx <- core_idx[a]; dest_idx <- land_idx[cand_kernel[[a]]]
  dest_idx <- dest_idx[dest_idx!=origin_idx]; if(!length(dest_idx)) next
  d <- sqrt((grid_xy[dest_idx,1]-grid_xy[origin_idx,1])^2+
            (grid_xy[dest_idx,2]-grid_xy[origin_idx,2])^2)
  s0 <- grid$SG_id[origin_idx]; z1 <- grid$zone[dest_idx]; s1 <- grid$SG_id[dest_idx]
  catg <- ifelse(z1==2,"peripheral",ifelse(s1==s0,"same_SG",
    ifelse(vapply(s1,function(x)is_neighbour(s0,x),logical(1)),"neighbour_SG","nonneighbour_SG")))

  for(sig in SIGMA_MOVE_TEST){
    w <- exp(-d^2/(2*sig^2))
    ws <- tapply(w,factor(catg,levels=c("same_SG","neighbour_SG","nonneighbour_SG","peripheral")),sum)
    ws[is.na(ws)] <- 0; den <- sum(ws)
    jj <- jj+1L
    kernel_rows[[jj]] <- tibble(origin_idx=origin_idx,origin_SG=s0,sigma_move=sig,
      same_SG=ws["same_SG"]/den,neighbour_SG=ws["neighbour_SG"]/den,
      nonneighbour_SG=ws["nonneighbour_SG"]/den,peripheral=ws["peripheral"]/den)
  }
}
kernel_cell <- bind_rows(kernel_rows)
kernel_sg <- kernel_cell %>% group_by(origin_SG,sigma_move) %>%
  summarise(across(c(same_SG,neighbour_SG,nonneighbour_SG,peripheral),
                   list(mean=mean,median=median),.names="{.col}_{.fn}"),.groups="drop")
kernel_overall <- kernel_cell %>% group_by(sigma_move) %>%
  summarise(across(c(same_SG,neighbour_SG,nonneighbour_SG,peripheral),
                   list(mean=mean,median=median),.names="{.col}_{.fn}"),.groups="drop")

cat("\n--- KERNEL-WEIGHTED OPPORTUNITY OVERALL ---\n"); print(kernel_overall,n=Inf)
cat("\n--- KERNEL-WEIGHTED OPPORTUNITY BY SG ---\n"); print(kernel_sg,n=Inf)

# 6. Save everything
write_csv(st_drop_geometry(det_lookup),file.path(OUT_DIR,"detectors_with_zone_sg_spacing.csv"))
write_csv(det_by_zone,file.path(OUT_DIR,"detectors_by_zone.csv"))
write_csv(det_by_sg,file.path(OUT_DIR,"detectors_by_sg.csv"))
write_csv(det_spacing_zone,file.path(OUT_DIR,"detector_spacing_by_zone.csv"))
write_csv(grid_cov_zone,file.path(OUT_DIR,"grid_detector_coverage_by_zone.csv"))
write_csv(grid_cov_sg,file.path(OUT_DIR,"grid_detector_coverage_by_sg.csv"))
write_csv(sg_geometry,file.path(OUT_DIR,"sg_geometry_boundaries.csv"))
write_csv(adj_tbl,file.path(OUT_DIR,"sg_adjacency_shared_boundaries.csv"))
write_csv(outer_boundary,file.path(OUT_DIR,"state_space_outer_boundary.csv"))
write_csv(movement_overall,file.path(OUT_DIR,"movement_opportunity_overall.csv"))
write_csv(movement_sg,file.path(OUT_DIR,"movement_opportunity_by_sg.csv"))
write_csv(kernel_overall,file.path(OUT_DIR,"kernel_opportunity_overall.csv"))
write_csv(kernel_sg,file.path(OUT_DIR,"kernel_opportunity_by_sg.csv"))

audit <- list(det_lookup=det_lookup,det_by_zone=det_by_zone,det_by_sg=det_by_sg,
              det_spacing_zone=det_spacing_zone,grid_cov_zone=grid_cov_zone,
              grid_cov_sg=grid_cov_sg,sg_geometry=sg_geometry,adjacency=adj_tbl,
              outer_boundary=outer_boundary,movement_overall=movement_overall,
              movement_sg=movement_sg,kernel_overall=kernel_overall,kernel_sg=kernel_sg,
              settings=list(radii_m=RADII_M,sigma_move_test=SIGMA_MOVE_TEST,
                            detector_radii_m=DETECTOR_RADII_M,cell_size=cell_size))
saveRDS(audit,file.path(OUT_DIR,"V3_spatial_audit.rds"))

cat("\n========================================\nAUDIT COMPLETE\n========================================\n")
cat("Send back these printed objects:\n",
    "det_by_zone, det_spacing_zone, grid_cov_zone, grid_cov_sg,\n",
    "sg_geometry, adj_tbl, outer_boundary, movement_overall,\n",
    "kernel_overall, and movement_sg/kernel_sg if manageable.\n",sep="")
