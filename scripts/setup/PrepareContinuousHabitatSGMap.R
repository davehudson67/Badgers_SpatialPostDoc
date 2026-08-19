library(sf)
library(dplyr)
library(readr)
library(stringr)

# ==============================================================================
# 1. Load the exact Sett Coordinates and convert to spatial points
# ==============================================================================
setts_raw <- read_csv("data/WoodchesterSettLocations.csv", show_col_types = FALSE)

# Convert to sf object (OSGB36 / British National Grid is EPSG:27700)
setts_sf <- st_as_sf(setts_raw, coords = c("SettX", "SettY"), crs = 27700) 

# ==============================================================================
# 2. Load the QGIS Habitat & Social Group Grid
# ==============================================================================
# Update this path to wherever your QGIS shapefile is saved!
grid_path <- "/home2/ISAD/dh526/Badgers_SpatialPostDoc/data/spatial/HabitatSpatial/Habitat_Final.shp" 
new_grid <- st_read(grid_path, quiet = FALSE)

# Format the columns (Your shapefile is already perfectly named!)
new_grid <- new_grid %>%
  mutate(
    SG_id = as.integer(SG_id), 
    habitat = as.integer(habitat),
    
    # QGIS counts from 0. R counts from 1. We must add 1!
    row_index = as.integer(row_index) + 1L,
    col_index = as.integer(col_index) + 1L
  )

# Ensure Coordinate Reference Systems (CRS) match perfectly
if (st_crs(setts_sf) != st_crs(new_grid)) {
  message("Aligning CRS...")
  setts_sf <- st_transform(setts_sf, st_crs(new_grid))
}

# ==============================================================================
# 3. Build the Matrices for NIMBLE
# ==============================================================================
n_rows <- max(new_grid$row_index)
n_cols <- max(new_grid$col_index)

# Create the mathematical matrices
habitat_mat <- matrix(0L, nrow = n_rows, ncol = n_cols)
SG_mat      <- matrix(0L, nrow = n_rows, ncol = n_cols)

# Fill them using the grid indices!
habitat_mat[cbind(new_grid$row_index, new_grid$col_index)] <- new_grid$habitat
SG_mat[cbind(new_grid$row_index, new_grid$col_index)]      <- new_grid$SG_id

# ==============================================================================
# 4. Snap the Setts to the QGIS Grid!
# ==============================================================================
# Find the exact QGIS grid cell each sett sits inside
nearest_cell <- st_nearest_feature(setts_sf, new_grid)

# Define your Alias Dictionary for cleaning
sett_aliases <- c(
  "\\bCHESTNUT\\b"     = "CHESNUT",
  "\\bJACKS\\b"        = "JACKSMIREY",
  "\\bGRAVEL\\b"       = "GRAVELPIT",
  "\\bBUCKHOLE\\b"     = "BUCKHOLT", 
  "\\bTOPSETT\\b"      = "TOP",
  "\\bFOXCUB\\b"       = "FOX",
  "\\bGULLEY\\b"       = "GULLY",
  "\\bBLACKBERRY\\b"   = "BRAMBLE",
  "\\bBOC\\b"          = "BOG",
  "\\bCEDARBANK\\b"    = "CEDAR",
  "\\bCLAYTRAP\\b"     = "CLAY",
  "\\bCLIFF\\b"        = "CLIFFFACE",
  "\\bDINGLEVALLEY\\b" = "DINGLE"
)

settGrid <- setts_raw %>%
  mutate(
    row_index = new_grid$row_index[nearest_cell],
    col_index = new_grid$col_index[nearest_cell],
    SG_id_landscape = new_grid$SG_id[nearest_cell],
    habitat = new_grid$habitat[nearest_cell]
  ) %>%
  # Apply text cleaning rules so the names match the CMR data perfectly!
  mutate(
    Sett_Clean = toupper(SETT) %>%    
      str_replace_all("[[:punct:]]", " ") %>%
      str_squish() %>%
      str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
      str_replace_all(sett_aliases) %>% 
      str_replace_all("\\s+", "")
  ) %>%
  distinct(Sett_Clean, .keep_all = TRUE)

# ==============================================================================
# VISUAL CHECK 1: Habitat Mask & Setts
# ==============================================================================
# Convert habitat to a factor so it plots as distinct colors
new_grid_plot <- new_grid %>%
  mutate(habitat_factor = factor(habitat, levels = c(0, 1), labels = c("Lake", "Land")))

p_habitat <- ggplot() +
  # Draw the grid cells (color = NA removes the cell borders so it looks smooth)
  geom_sf(data = new_grid_plot, aes(fill = habitat_factor), color = NA) +
  # Overlay the exact sett coordinates as Red Crosses
  geom_sf(data = setts_sf, color = "red", size = 2, shape = 4, stroke = 1) +
  # Choose nice colors
  scale_fill_manual(values = c("Lake" = "deepskyblue", "Land" = "palegreen3")) +
  theme_minimal() +
  labs(
    title = "Woodchester Setts Overlaid on Habitat Grid",
    subtitle = "Red crosses = Sett locations",
    fill = "Habitat"
  )

p_habitat

# ==============================================================================
# VISUAL CHECK 2: Social Group Territories & Setts
# ==============================================================================
p_social_groups <- ggplot() +
  # Draw the grid cells colored by Social Group ID
  geom_sf(data = new_grid, aes(fill = as.factor(SG_id)), color = NA) +
  # Overlay the setts as black dots
  geom_sf(data = setts_sf, color = "black", size = 1.5) +
  theme_minimal() +
  # Turn off the legend because 40+ social groups will make it huge!
  theme(legend.position = "none") +
  labs(
    title = "Woodchester Setts Overlaid on Social Group Territories",
    subtitle = "Black dots = Sett locations"
  )

p_social_groups

