library(sf)
library(dplyr)

# ==============================================================================
# Load the Core Social Group Polygons
# ==============================================================================
sg_polys <- st_read("data/spatial/CoreSGboudaries.shp", quiet = TRUE) %>%
  mutate(SG_id = as.integer(SG_id)) %>%
  select(SG_id, geometry)

# ==============================================================================
# Auto-Generate the "Outside World" (Group 999)
# ==============================================================================
# Combine all SG polygons into one giant "Woodchester Core" shape
core_footprint <- st_union(sg_polys)

# Draw a bounding box around it, and expand it by 1000 meters
bbox_expanded <- st_buffer(st_as_sfc(st_bbox(core_footprint)), dist = 1000)

# Subtract the core footprint from the expanded box
outside_world_geom <- st_difference(bbox_expanded, core_footprint)

# Convert to an sf object and call it Group 999
outside_world_sf <- st_sf(SG_id = 999L, geometry = outside_world_geom)

# Bind the original groups and the outside world together into our final map!
all_nodes_sf <- bind_rows(sg_polys, outside_world_sf)

cat("Total distinct nodes (Social Groups + Outside World):", nrow(all_nodes_sf), "\n")

# ==============================================================================
# Build the Adjacency Matrix (The Network)
# ==============================================================================
touches <- st_touches(all_nodes_sf, sparse = FALSE)

# Convert TRUE/FALSE to 1s and 0s
A_matrix <- ifelse(touches, 1L, 0L)

# Label rows and columns with the actual Social Group IDs
rownames(A_matrix) <- all_nodes_sf$SG_id
colnames(A_matrix) <- all_nodes_sf$SG_id

# A badger is allowed to stay in its own group so the diagonal must be 1.
diag(A_matrix) <- 1L

cat("Average number of neighbors per group:", round(mean(rowSums(A_matrix) - 1), 2), "\n\n")

# ==============================================================================
# Create a Base Transition Matrix for NIMBLE
# ==============================================================================
# NIMBLE needs probabilities that sum to 1. 
# We initialize a flat matrix where moving to any adjacent group is equally likely.
n_sg <- nrow(A_matrix)
transition_probs <- matrix(0, nrow = n_sg, ncol = n_sg)

for(i in 1:n_sg) {
  n_neighbors <- sum(A_matrix[i, ])
  transition_probs[i, ] <- A_matrix[i, ] / n_neighbors
}

# ==============================================================================
# Save the Network
# ==============================================================================
saveRDS(list(sg_polygons = all_nodes_sf,
             A_matrix = A_matrix,
             transition_probs = transition_probs,
             sg_id_list = all_nodes_sf$SG_id), 
  "data/Social_Group_Network.rds")

# Load the network
net_data <- readRDS("data/Social_Group_Network.rds")
polygons <- net_data$sg_polygons

# Plot
p_network <- ggplot(data = polygons) +
  geom_sf(aes(fill = as.factor(SG_id)), color = "black", linewidth = 0.5, alpha = 0.7) +
  geom_sf_text(aes(label = SG_id), size = 3.5, fontface = "bold", color = "black") +
  theme_void() +
  theme(legend.position = "none") +
  labs(
    title = "Woodchester Social Group Network",
    subtitle = "Group 999 is the 'Outside World' Emigration/Immigration Buffer")

# 3. Print to your RStudio viewer
print(p_network)
