# Save the finished V3 spatial object once, then V3 model scripts can just read it.
library(sf); library(dplyr)

grid_file <- "data/spatial/V3_Grid_50mFinal.gpkg"
grid <- st_read(grid_file, quiet=TRUE) %>%
  mutate(row_R=as.integer(row_index)+1L, col_R=as.integer(col_index)+1L)

cell_size <- 50
bb <- st_bbox(grid)
xmin <- as.numeric(bb["xmin"]); xmax <- as.numeric(bb["xmax"])
ymin <- as.numeric(bb["ymin"]); ymax <- as.numeric(bb["ymax"])
n_rows <- max(grid$row_R); n_cols <- max(grid$col_R)

# Critical audit: coordinate -> matrix lookup must reproduce QGIS indices.
cent <- st_coordinates(st_centroid(grid))
row_calc <- floor((ymax-cent[,2])/cell_size)+1L
col_calc <- floor((cent[,1]-xmin)/cell_size)+1L
stopifnot(all(row_calc==grid$row_R), all(col_calc==grid$col_R))
stopifnot(n_rows*n_cols==nrow(grid))

SG_mat <- matrix(NA_integer_,n_rows,n_cols)
habitat_mat <- matrix(NA_integer_,n_rows,n_cols)
zone_mat <- matrix(NA_integer_,n_rows,n_cols)
SG_mat[cbind(grid$row_R,grid$col_R)] <- as.integer(grid$SG_id)
habitat_mat[cbind(grid$row_R,grid$col_R)] <- as.integer(grid$habitat)
zone_mat[cbind(grid$row_R,grid$col_R)] <- as.integer(grid$zone)
stopifnot(!anyNA(SG_mat),!anyNA(habitat_mat),!anyNA(zone_mat))

V3_spatial <- list(
  grid=grid, SG_mat=SG_mat, habitat_mat=habitat_mat, zone_mat=zone_mat,
  xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, cell_size=cell_size,
  n_rows=n_rows, n_cols=n_cols, crs=st_crs(grid)
)

saveRDS(V3_spatial,"data/spatial/V3_spatial_inputs_50m_2km.rds")
cat("Saved V3 spatial inputs:",
    n_rows,"x",n_cols,"=",n_rows*n_cols,"cells\n")
