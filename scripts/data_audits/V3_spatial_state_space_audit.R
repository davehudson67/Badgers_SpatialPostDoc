# =============================================================================
# WOODCHESTER V3 SPATIAL STATE-SPACE AUDIT
#
# Purpose
#   Audit the exact spatial object used by V10B:
#     data/spatial/V3_spatial_inputs_50m_2km.rds
#
# This is an audit only. It never rewrites the spatial RDS.
#
# Checks
#   1. object structure, dimensions, cell size and matrix consistency;
#   2. centroid-vs-outer-edge geometry (the historical half-cell bug);
#   3. R row/column indexing and full rectangular grid coverage;
#   4. habitat / zone / social-group coding;
#   5. exact sett-coordinate mapping into the state space;
#   6. every spatially usable live capture used by the movement population;
#   7. detector distance to the outer state-space boundary;
#   8. known regression check: OLDPONDDRAIN must map to row 54, col 79,
#      habitat 1 (not the old erroneous col 78 lookup).
#
# The current V10B movement model uses habitat_mat but does NOT currently use
# SG_mat or zone_mat in the likelihood. They are audited because they document
# how the V3 state space was constructed and will become relevant when
# time-varying bait-marking/social-group information is available.
#
# Output
#   results/V3_spatial_state_space_audit.rds
#   results/V3_spatial_sett_audit.csv
#   results/V3_spatial_state_space_summary.csv
# =============================================================================

library(tidyverse)
library(sf)

SPATIAL_FILE <- "data/spatial/V3_spatial_inputs_50m_2km.rds"
GRID_SOURCE_FILE <- "data/spatial/V3_Grid_50mFinal.gpkg"
SETT_FILE <- "data/WoodchesterSettLocations.csv"
ENCOUNTER_FILE <- "data/badger_encounters_useful.rds"
POPULATION_FILE <- "results/V7_population_inclusion_audit.rds"

required <- c(
  SPATIAL_FILE,
  GRID_SOURCE_FILE,
  SETT_FILE,
  ENCOUNTER_FILE,
  POPULATION_FILE
)
missing_files <- required[!file.exists(required)]
if (length(missing_files)) {
  stop("Missing required file(s):\n", paste(missing_files, collapse = "\n"))
}

dir.create("results", showWarnings = FALSE, recursive = TRUE)

cat("\n============================================================\n")
cat("WOODCHESTER V3 SPATIAL STATE-SPACE AUDIT\n")
cat("============================================================\n")

sp <- readRDS(SPATIAL_FILE)
grid_source <- st_read(GRID_SOURCE_FILE, quiet = TRUE)
sett_raw <- read_csv(SETT_FILE, show_col_types = FALSE)
enc <- readRDS(ENCOUNTER_FILE)
pop_obj <- readRDS(POPULATION_FILE)

# -----------------------------------------------------------------------------
# 1. Structure and dimensions
# -----------------------------------------------------------------------------
required_sp_names <- c(
  "grid", "SG_mat", "habitat_mat", "zone_mat",
  "xmin", "xmax", "ymin", "ymax",
  "cell_size", "n_rows", "n_cols"
)

missing_sp <- setdiff(required_sp_names, names(sp))
if (length(missing_sp)) {
  stop("Spatial RDS missing: ", paste(missing_sp, collapse = ", "))
}

cell_size <- as.numeric(sp$cell_size)
n_rows <- as.integer(sp$n_rows)
n_cols <- as.integer(sp$n_cols)
xmin <- as.numeric(sp$xmin)
xmax <- as.numeric(sp$xmax)
ymin <- as.numeric(sp$ymin)
ymax <- as.numeric(sp$ymax)

if (!isTRUE(all.equal(cell_size, 50))) {
  stop("Expected 50 m cells; found cell_size=", cell_size)
}
if (n_rows != 124L || n_cols != 165L) {
  stop(
    "Expected historical V3 dimensions 124 x 165; found ",
    n_rows, " x ", n_cols
  )
}
if (n_rows * n_cols != 20460L) {
  stop("Expected 20,460 rectangular grid cells.")
}

for (nm in c("SG_mat", "habitat_mat", "zone_mat")) {
  mm <- sp[[nm]]
  if (!identical(dim(mm), c(n_rows, n_cols))) {
    stop(
      nm, " dimension mismatch: ",
      paste(dim(mm), collapse = " x "),
      " vs expected ", n_rows, " x ", n_cols
    )
  }
  if (anyNA(mm)) stop(nm, " contains NA values.")
}

if (!all(sp$habitat_mat %in% c(0, 1))) {
  stop("habitat_mat contains values other than 0/1.")
}
if (!all(sp$zone_mat %in% c(1, 2))) {
  stop("zone_mat contains values other than 1/2.")
}

# -----------------------------------------------------------------------------
# 2. Reproduce the saved RDS from the original QGIS grid source
# -----------------------------------------------------------------------------
source_required <- c(
  "row_index", "col_index", "SG_id", "habitat", "zone"
)
source_missing <- setdiff(source_required, names(grid_source))
if (length(source_missing)) {
  stop(
    "Source GPKG missing required fields: ",
    paste(source_missing, collapse = ", ")
  )
}

source_grid <- grid_source %>%
  mutate(
    row_R = as.integer(row_index) + 1L,
    col_R = as.integer(col_index) + 1L
  )

source_cent <- st_coordinates(st_centroid(source_grid))
source_half_cell <- cell_size / 2

source_edges <- c(
  xmin = min(source_cent[, 1]) - source_half_cell,
  xmax = max(source_cent[, 1]) + source_half_cell,
  ymin = min(source_cent[, 2]) - source_half_cell,
  ymax = max(source_cent[, 2]) + source_half_cell
)

source_n_rows <- max(source_grid$row_R)
source_n_cols <- max(source_grid$col_R)

if (
  source_n_rows != n_rows ||
  source_n_cols != n_cols
) {
  stop(
    "GPKG dimensions ", source_n_rows, " x ", source_n_cols,
    " do not match saved RDS ", n_rows, " x ", n_cols
  )
}

if (nrow(source_grid) != source_n_rows * source_n_cols) {
  stop("Source GPKG does not contain a complete rectangular cell lattice.")
}

source_df <- st_drop_geometry(source_grid)

build_source_matrix <- function(value) {
  out <- matrix(
    NA_integer_,
    nrow = source_n_rows,
    ncol = source_n_cols
  )
  out[cbind(source_df$row_R, source_df$col_R)] <- as.integer(value)
  out
}

source_SG_mat <- build_source_matrix(source_df$SG_id)
source_habitat_mat <- build_source_matrix(source_df$habitat)
source_zone_mat <- build_source_matrix(source_df$zone)

if (anyNA(source_SG_mat) ||
    anyNA(source_habitat_mat) ||
    anyNA(source_zone_mat)) {
  stop("Rebuilding matrices from source GPKG produced NA cells.")
}

if (!identical(source_SG_mat, sp$SG_mat)) {
  stop("Saved SG_mat does not exactly match source GPKG.")
}
if (!identical(source_habitat_mat, sp$habitat_mat)) {
  stop("Saved habitat_mat does not exactly match source GPKG.")
}
if (!identical(source_zone_mat, sp$zone_mat)) {
  stop("Saved zone_mat does not exactly match source GPKG.")
}

stored_edges_source_delta <- stored_edges - source_edges
if (any(abs(stored_edges_source_delta) > 1e-8)) {
  print(tibble(
    edge = names(stored_edges),
    stored = as.numeric(stored_edges),
    rebuilt_from_GPKG = as.numeric(source_edges),
    delta_m = as.numeric(stored_edges_source_delta)
  ))
  stop(
    "Saved RDS edges do not match GPKG centroid extrema +/- 25 m."
  )
}

if (!isTRUE(st_crs(sp$grid) == st_crs(grid_source))) {
  stop("Saved RDS grid CRS differs from source GPKG CRS.")
}

cat("\nSource GPKG -> saved RDS reproduction: PASS\n")

# Approximate 2-km buffer check from cell centroids. Because both core and
# peripheral locations are represented by 50-m cell centroids, allow one cell
# diagonal beyond 2 km as discretisation tolerance.
source_points <- st_as_sf(
  tibble(
    zone = as.integer(source_df$zone),
    x = source_cent[, 1],
    y = source_cent[, 2]
  ),
  coords = c("x", "y"),
  crs = st_crs(grid_source)
)

core_pts <- source_points %>% filter(zone == 1L)
peripheral_pts <- source_points %>% filter(zone == 2L)

if (!nrow(core_pts) || !nrow(peripheral_pts)) {
  stop("Source grid lacks core or peripheral cells.")
}

nearest_core <- st_nearest_feature(peripheral_pts, core_pts)
peripheral_to_core_m <- as.numeric(
  st_distance(
    peripheral_pts,
    core_pts[nearest_core, ],
    by_element = TRUE
  )
)

buffer_tolerance_m <- sqrt(2) * cell_size

if (
  max(peripheral_to_core_m, na.rm = TRUE) >
    2000 + buffer_tolerance_m
) {
  warning(
    "At least one peripheral-cell centroid is > 2 km + one-cell-diagonal ",
    "from the nearest core-cell centroid. Max = ",
    round(max(peripheral_to_core_m, na.rm = TRUE), 1), " m."
  )
}

cat(
  "Approximate peripheral-to-core distance (cell centroids):\n",
  "  median = ", round(median(peripheral_to_core_m), 1), " m\n",
  "  p95    = ", round(quantile(peripheral_to_core_m, 0.95), 1), " m\n",
  "  max    = ", round(max(peripheral_to_core_m), 1), " m\n",
  sep = ""
)

# -----------------------------------------------------------------------------
# 3. Grid centroid geometry and outer-edge convention
# -----------------------------------------------------------------------------
if (!inherits(sp$grid, "sf")) {
  stop("sp$grid is not an sf object.")
}

grid_df <- st_drop_geometry(sp$grid)
grid_xy <- st_coordinates(sp$grid)

if (nrow(grid_df) != n_rows * n_cols) {
  stop(
    "Grid row count ", nrow(grid_df),
    " does not equal n_rows*n_cols=", n_rows * n_cols
  )
}

if (!all(c("row_R", "col_R", "habitat") %in% names(grid_df))) {
  stop("sp$grid must contain row_R, col_R and habitat.")
}

if (nrow(grid_xy) != nrow(grid_df)) {
  stop("Grid coordinate count differs from grid attribute count.")
}

half_cell <- cell_size / 2

expected_edges <- c(
  xmin = min(grid_xy[, 1]) - half_cell,
  xmax = max(grid_xy[, 1]) + half_cell,
  ymin = min(grid_xy[, 2]) - half_cell,
  ymax = max(grid_xy[, 2]) + half_cell
)

stored_edges <- c(
  xmin = xmin,
  xmax = xmax,
  ymin = ymin,
  ymax = ymax
)

edge_delta <- stored_edges - expected_edges

if (any(abs(edge_delta) > 1e-8)) {
  print(tibble(
    edge = names(stored_edges),
    stored = as.numeric(stored_edges),
    expected_from_centroids = as.numeric(expected_edges),
    delta_m = as.numeric(edge_delta)
  ))
  stop(
    "Stored state-space extents are not centroid extrema +/- half a cell. ",
    "This would reintroduce the historical half-cell indexing error."
  )
}

expected_width <- n_cols * cell_size
expected_height <- n_rows * cell_size

if (!isTRUE(all.equal(xmax - xmin, expected_width))) {
  stop("X extent is inconsistent with n_cols * cell_size.")
}
if (!isTRUE(all.equal(ymax - ymin, expected_height))) {
  stop("Y extent is inconsistent with n_rows * cell_size.")
}

# -----------------------------------------------------------------------------
# 4. One-based row/column indexing and matrix reconstruction
# -----------------------------------------------------------------------------
if (anyNA(grid_df$row_R) || anyNA(grid_df$col_R)) {
  stop("Grid has missing row_R/col_R.")
}

if (!all(grid_df$row_R %in% seq_len(n_rows))) {
  stop("row_R contains values outside 1:n_rows.")
}
if (!all(grid_df$col_R %in% seq_len(n_cols))) {
  stop("col_R contains values outside 1:n_cols.")
}

duplicate_cells <- grid_df %>%
  count(row_R, col_R) %>%
  filter(n != 1L)

if (nrow(duplicate_cells)) {
  print(duplicate_cells, n = Inf)
  stop("Grid does not contain exactly one record per row_R/col_R cell.")
}

if (n_distinct(grid_df$row_R, grid_df$col_R) != n_rows * n_cols) {
  stop("Grid does not cover the full rectangular row/column lattice.")
}

# Check that row/column derived from coordinates reproduce stored row_R/col_R.
coord_col <- floor((grid_xy[, 1] - xmin) / cell_size) + 1L
coord_row <- floor((ymax - grid_xy[, 2]) / cell_size) + 1L

if (!all(coord_row == grid_df$row_R)) {
  bad <- which(coord_row != grid_df$row_R)
  stop(
    "Coordinate-derived row index differs from stored row_R for ",
    length(bad), " grid cells."
  )
}
if (!all(coord_col == grid_df$col_R)) {
  bad <- which(coord_col != grid_df$col_R)
  stop(
    "Coordinate-derived col index differs from stored col_R for ",
    length(bad), " grid cells."
  )
}

rebuild_matrix <- function(value) {
  out <- matrix(NA_integer_, nrow = n_rows, ncol = n_cols)
  out[cbind(grid_df$row_R, grid_df$col_R)] <- as.integer(value)
  out
}

if (!identical(rebuild_matrix(grid_df$habitat), sp$habitat_mat)) {
  stop("habitat_mat does not reproduce grid$habitat.")
}

if ("zone" %in% names(grid_df)) {
  if (!identical(rebuild_matrix(grid_df$zone), sp$zone_mat)) {
    stop("zone_mat does not reproduce grid$zone.")
  }
}

sg_col <- intersect(c("SG_id", "sg_id", "SG"), names(grid_df))[1]
if (!is.na(sg_col)) {
  if (!identical(rebuild_matrix(grid_df[[sg_col]]), sp$SG_mat)) {
    stop("SG_mat does not reproduce the social-group field in sp$grid.")
  }
}

# -----------------------------------------------------------------------------
# 5. Habitat / zone / SG coding
# -----------------------------------------------------------------------------
cell_table <- tibble(
  row_R = grid_df$row_R,
  col_R = grid_df$col_R,
  x = grid_xy[, 1],
  y = grid_xy[, 2],
  habitat = as.integer(sp$habitat_mat[cbind(grid_df$row_R, grid_df$col_R)]),
  zone = as.integer(sp$zone_mat[cbind(grid_df$row_R, grid_df$col_R)]),
  SG_id = as.integer(sp$SG_mat[cbind(grid_df$row_R, grid_df$col_R)])
)

cell_area_km2 <- (cell_size^2) / 1e6

state_space_cross_tab <- cell_table %>%
  count(zone, habitat, SG_id, name = "n_cells") %>%
  mutate(area_km2 = n_cells * cell_area_km2) %>%
  arrange(zone, habitat, SG_id)

core_sg <- sort(unique(cell_table$SG_id[cell_table$zone == 1L]))
peripheral_sg <- sort(unique(cell_table$SG_id[cell_table$zone == 2L]))

# Historical V3 construction: 22 mapped core groups and 999 for peripheral.
if (!identical(core_sg, 1:22)) {
  warning(
    "Core SG IDs are not exactly 1:22. Found: ",
    paste(core_sg, collapse = ", ")
  )
}
if (!identical(peripheral_sg, 999L)) {
  warning(
    "Peripheral SG coding is not exactly 999. Found: ",
    paste(peripheral_sg, collapse = ", ")
  )
}

# The current V10B model only uses habitat_mat. Report rather than assume that
# water classification and zone classification have a particular cross-tab.
cat("\nState-space cell cross-tabulation:\n")
print(state_space_cross_tab, n = Inf)

# -----------------------------------------------------------------------------
# 6. Exact sett coordinates and model-compatible cleaning
# -----------------------------------------------------------------------------
clean_sett <- function(x) {
  x %>%
    as.character() %>%
    toupper() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all("\\s+", "")
}

sett_aliases <- c(
  "CHESTNUT" = "CHESNUT",
  "JACKS" = "JACKSMIREY",
  "GRAVEL" = "GRAVELPIT",
  "BUCKHOLE" = "BUCKHOLT",
  "TOPSETT" = "TOP",
  "FOXCUB" = "FOX",
  "GULLEY" = "GULLY",
  "BLACKBERRY" = "BRAMBLE",
  "BOC" = "BOG",
  "CEDARBANK" = "CEDAR",
  "CLAYTRAP" = "CLAY",
  "CLIFF" = "CLIFFFACE",
  "DINGLEVALLEY" = "DINGLE"
)

clean_sett2 <- function(x) {
  z <- clean_sett(x)
  for (a in names(sett_aliases)) z[z == a] <- sett_aliases[[a]]
  z
}

name_col <- intersect(
  c("Sett_Clean", "Sett", "sett", "SettName", "Sett_Upper", "Name"),
  names(sett_raw)
)[1]
x_col <- intersect(
  c("SettX", "sett_x", "X", "x", "Easting", "easting"),
  names(sett_raw)
)[1]
y_col <- intersect(
  c("SettY", "sett_y", "Y", "y", "Northing", "northing"),
  names(sett_raw)
)[1]

if (any(is.na(c(name_col, x_col, y_col)))) {
  stop("Could not identify sett name/X/Y columns.")
}

sett_xy <- sett_raw %>%
  transmute(
    Sett_Clean = clean_sett2(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(
    !is.na(Sett_Clean),
    Sett_Clean != "",
    !is.na(x),
    !is.na(y)
  )

sett_conflicts <- sett_xy %>%
  distinct(Sett_Clean, x, y) %>%
  count(Sett_Clean, name = "n_xy") %>%
  filter(n_xy > 1L)

if (nrow(sett_conflicts)) {
  print(sett_conflicts, n = Inf)
  stop("One or more cleaned sett names map to multiple coordinate pairs.")
}

sett_xy <- sett_xy %>%
  distinct(Sett_Clean, .keep_all = TRUE) %>%
  mutate(
    col_R = floor((x - xmin) / cell_size) + 1L,
    row_R = floor((ymax - y) / cell_size) + 1L,
    in_bounds =
      col_R >= 1L & col_R <= n_cols &
      row_R >= 1L & row_R <= n_rows
  )

sett_xy <- sett_xy %>%
  mutate(
    habitat = if_else(
      in_bounds,
      as.integer(sp$habitat_mat[cbind(row_R, col_R)]),
      NA_integer_
    ),
    zone = if_else(
      in_bounds,
      as.integer(sp$zone_mat[cbind(row_R, col_R)]),
      NA_integer_
    ),
    SG_id = if_else(
      in_bounds,
      as.integer(sp$SG_mat[cbind(row_R, col_R)]),
      NA_integer_
    ),
    distance_to_outer_boundary_m = if_else(
      in_bounds,
      pmin(
        x - xmin,
        xmax - x,
        y - ymin,
        ymax - y
      ),
      NA_real_
    )
  )

# Regression test for the previously fixed centroid/edge indexing bug.
oldpond <- sett_xy %>% filter(Sett_Clean == "OLDPONDDRAIN")
if (nrow(oldpond) != 1L) {
  stop("Could not uniquely locate OLDPONDDRAIN in sett coordinate table.")
}
if (
  oldpond$row_R != 54L ||
  oldpond$col_R != 79L ||
  oldpond$habitat != 1L
) {
  print(oldpond, width = Inf)
  stop(
    "OLDPONDDRAIN regression check failed. Expected row 54, col 79, habitat 1."
  )
}

# -----------------------------------------------------------------------------
# 7. Every spatial live encounter in the audited movement population
# -----------------------------------------------------------------------------
if (is.null(pop_obj$population)) {
  stop("Population audit RDS lacks $population.")
}

movement_ids <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(tattoo = toupper(trimws(as.character(tattoo))))

enc_live <- enc %>%
  mutate(
    tattoo = toupper(trimws(as.character(tattoo))),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    Sett_Clean = clean_sett2(sett)
  ) %>%
  filter(
    tattoo %in% movement_ids$tattoo,
    has_live_capture,
    !is.na(primary_year),
    primary_year <= 2025L,
    trap_season %in% 1:4
  ) %>%
  left_join(
    sett_xy %>%
      select(
        Sett_Clean, x, y, row_R, col_R,
        in_bounds, habitat, zone, SG_id,
        distance_to_outer_boundary_m
      ),
    by = "Sett_Clean"
  )

unmapped_live <- enc_live %>%
  filter(is.na(x) | is.na(y))

if (nrow(unmapped_live)) {
  cat("\nMovement-population live encounters lacking sett coordinates:\n")
  print(
    unmapped_live %>% count(Sett_Clean, sort = TRUE),
    n = Inf
  )
}

spatial_live <- enc_live %>%
  filter(!is.na(x), !is.na(y))

outside_live <- spatial_live %>% filter(!in_bounds)
water_live <- spatial_live %>% filter(in_bounds, habitat != 1L)

if (nrow(outside_live)) {
  print(outside_live, n = Inf, width = Inf)
  stop("At least one spatially usable live encounter lies outside state space.")
}

if (nrow(water_live)) {
  print(water_live, n = Inf, width = Inf)
  stop("At least one spatially usable live encounter maps to habitat=0.")
}

used_setts <- spatial_live %>%
  distinct(
    Sett_Clean, x, y, row_R, col_R,
    habitat, zone, SG_id, distance_to_outer_boundary_m
  ) %>%
  arrange(distance_to_outer_boundary_m)

# -----------------------------------------------------------------------------
# 8. Summary and boundary diagnostics
# -----------------------------------------------------------------------------
valid_habitat_cells <- sum(sp$habitat_mat == 1L)
water_cells <- sum(sp$habitat_mat == 0L)
core_cells <- sum(sp$zone_mat == 1L)
peripheral_cells <- sum(sp$zone_mat == 2L)

summary_tbl <- tibble(
  metric = c(
    "cell_size_m",
    "n_rows",
    "n_cols",
    "n_cells",
    "extent_width_m",
    "extent_height_m",
    "valid_habitat_cells",
    "water_cells",
    "valid_habitat_area_km2",
    "core_cells",
    "peripheral_cells",
    "n_exact_setts",
    "n_used_movement_setts",
    "n_movement_live_encounters",
    "n_unmapped_movement_live_encounters",
    "min_used_sett_distance_to_outer_boundary_m",
    "p05_used_sett_distance_to_outer_boundary_m",
    "median_used_sett_distance_to_outer_boundary_m",
    "median_peripheral_cell_distance_to_core_m",
    "p95_peripheral_cell_distance_to_core_m",
    "max_peripheral_cell_distance_to_core_m"
  ),
  value = c(
    cell_size,
    n_rows,
    n_cols,
    n_rows * n_cols,
    xmax - xmin,
    ymax - ymin,
    valid_habitat_cells,
    water_cells,
    valid_habitat_cells * cell_area_km2,
    core_cells,
    peripheral_cells,
    nrow(sett_xy),
    nrow(used_setts),
    nrow(spatial_live),
    nrow(unmapped_live),
    min(used_setts$distance_to_outer_boundary_m, na.rm = TRUE),
    unname(quantile(
      used_setts$distance_to_outer_boundary_m,
      0.05,
      na.rm = TRUE
    )),
    median(
      used_setts$distance_to_outer_boundary_m,
      na.rm = TRUE
    ),
    median(peripheral_to_core_m, na.rm = TRUE),
    unname(quantile(peripheral_to_core_m, 0.95, na.rm = TRUE)),
    max(peripheral_to_core_m, na.rm = TRUE)
  )
)

cat("\n============================================================\n")
cat("SPATIAL STATE-SPACE SUMMARY\n")
cat("============================================================\n")
print(summary_tbl, n = Inf, width = Inf)

cat("\nClosest used setts to outer state-space boundary:\n")
print(
  used_setts %>%
    slice_head(n = 20),
  n = Inf,
  width = Inf
)

cat("\nCRS:\n")
print(st_crs(sp$grid))

# A detector close to the OUTER RECTANGULAR edge is worth inspecting because
# the movement density is truncated there. This is distinct from the mapped
# core/peripheral boundary.
n_within_250_edge <- sum(
  used_setts$distance_to_outer_boundary_m < 250,
  na.rm = TRUE
)
n_within_500_edge <- sum(
  used_setts$distance_to_outer_boundary_m < 500,
  na.rm = TRUE
)

cat("\nUsed sett boundary counts:\n")
cat("  <250 m from outer rectangular edge:", n_within_250_edge, "\n")
cat("  <500 m from outer rectangular edge:", n_within_500_edge, "\n")

audit_object <- list(
  spatial_file = SPATIAL_FILE,
  grid_source_file = GRID_SOURCE_FILE,
  object_names = names(sp),
  crs = st_crs(sp$grid),
  stored_edges = stored_edges,
  expected_edges = expected_edges,
  edge_delta_m = edge_delta,
  summary = summary_tbl,
  cell_cross_tab = state_space_cross_tab,
  sett_audit = sett_xy,
  used_sett_audit = used_setts,
  unmapped_live = unmapped_live,
  checks = list(
    source_GPKG_reproduces_saved_RDS = TRUE,
    dimensions_124x165 = TRUE,
    cell_size_50m = TRUE,
    centroid_edges_correct = TRUE,
    complete_one_based_lattice = TRUE,
    matrix_grid_alignment = TRUE,
    oldponddrain_regression = TRUE,
    used_spatial_captures_in_bounds = TRUE,
    used_spatial_captures_on_habitat = TRUE
  )
)

saveRDS(
  audit_object,
  "results/V3_spatial_state_space_audit.rds"
)

write_csv(
  sett_xy,
  "results/V3_spatial_sett_audit.csv"
)

write_csv(
  summary_tbl,
  "results/V3_spatial_state_space_summary.csv"
)

cat("\nSaved:\n")
cat("  results/V3_spatial_state_space_audit.rds\n")
cat("  results/V3_spatial_sett_audit.csv\n")
cat("  results/V3_spatial_state_space_summary.csv\n")
cat("\nSPATIAL AUDIT COMPLETE\n")
