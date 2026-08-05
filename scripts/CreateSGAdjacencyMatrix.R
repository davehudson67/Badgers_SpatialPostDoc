library(sf)
library(dplyr)
library(readr)
library(stringr)

# ==============================================================================
# 1. Load the New Clean Polygons & Generate Group 999
# ==============================================================================
# Load your new hand-drawn territories
sg_polys <- st_read("data/spatial/CleanSocialGroups.gpkg", quiet = TRUE) %>%
  rename(SG_id = SG_id) %>%       # Ensure your column is named SG_id in QGIS!
  mutate(SG_id = as.integer(SG_id)) %>%
  select(SG_id, geometry)

message("Drawing the Outside World buffer...")
core_footprint <- st_union(sg_polys)
bbox_expanded <- st_buffer(st_as_sfc(st_bbox(core_footprint)), dist = 1500)
outside_world_geom <- st_difference(bbox_expanded, core_footprint)

# Combine the core territories with the Group 999 Buffer
outside_world_sf <- st_sf(SG_id = 999L, geometry = outside_world_geom)
all_nodes_sf <- bind_rows(sg_polys, outside_world_sf)

cat("Total distinct nodes (Social Groups + Outside World):", nrow(all_nodes_sf), "\n")

# ==============================================================================
# 2. Build the Adjacency Matrix (The Network)
# ==============================================================================
message("Calculating Adjacency Matrix...")
touches <- st_touches(all_nodes_sf, sparse = FALSE)
A_matrix <- ifelse(touches, 1L, 0L)
rownames(A_matrix) <- all_nodes_sf$SG_id
colnames(A_matrix) <- all_nodes_sf$SG_id
diag(A_matrix) <- 1L # A group touches itself

# Save the Network object for the CMR script
saveRDS(
  list(sg_polygons = all_nodes_sf, A_matrix = A_matrix, sg_id_list = all_nodes_sf$SG_id), 
  "data/Social_Group_Network.rds"
)

# ==============================================================================
# 3. Assign Setts to the Territories (R does the Point-in-Polygon!)
# ==============================================================================
message("Assigning Sett locations to Social Groups...")

sett_aliases <- c(
  "\\bCHESTNUT\\b"="CHESNUT", "\\bJACKS\\b"="JACKSMIREY", "\\bGRAVEL\\b"="GRAVELPIT", 
  "\\bBUCKHOLE\\b"="BUCKHOLT", "\\bTOPSETT\\b"="TOP", "\\bFOXCUB\\b"="FOX",
  "\\bGULLEY\\b"="GULLY", "\\bBLACKBERRY\\b"="BRAMBLE", "\\bBOC\\b"="BOG", 
  "\\bCEDARBANK\\b"="CEDAR", "\\bCLAYTRAP\\b"="CLAY", "\\bCLIFF\\b"="CLIFFFACE",
  "\\bDINGLEVALLEY\\b"="DINGLE"
)

# Load your raw sett coordinates
setts_raw <- read_csv("data/WoodchesterSettLocations.csv", show_col_types = FALSE)

# Convert to spatial points
setts_sf <- st_as_sf(setts_raw, coords = c("SettX", "SettY"), crs = 27700)

# The Magic Step: st_join checks which polygon each point falls into!
setts_mapped <- st_join(setts_sf, all_nodes_sf, join = st_intersects)

# Build the final lookup table
sg_lookup <- setts_mapped %>%
  st_drop_geometry() %>%
  mutate(
    Sett_Clean = toupper(SETT) %>%    
      str_replace_all("[[:punct:]]", " ") %>% str_squish() %>%
      str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
      str_replace_all(sett_aliases) %>% str_replace_all("\\s+", ""),
    
    # If a sett was literally > 1.5km off the map, default it to 999
    SG_id = replace_na(as.integer(SG_id), 999L)
  ) %>%
  distinct(Sett_Clean, .keep_all = TRUE) %>%
  select(Sett_Clean, SG_id)

# Save the generated lookup table!
write_csv(sg_lookup, "data/Sett_to_SG_Lookup_Auto.csv")

cat("Successfully mapped", nrow(sg_lookup), "setts to their territories!\n")
message("Spatial Preparation Complete. You are ready for the CMR model.")
