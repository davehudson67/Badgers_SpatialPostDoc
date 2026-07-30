library(dplyr)
library(readr)
library(stringr)

# Load the sett coordinates
spatial_raw <- read_csv("data/WoodchesterSettLocations.csv", show_col_types = FALSE)

# Apply the same cleaning rules so the names match the CMR data 1-to-1
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

settGrid <- spatial_raw %>%
  mutate(Sett_Clean = toupper(SETT) %>% 
      str_replace_all("[[:punct:]]", " ") %>%
      str_squish() %>%
      str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
      str_replace_all(sett_aliases) %>%
      str_replace_all("\\s+", "")) %>%
  # Keep only unique setts and their coordinates
  distinct(Sett_Clean, .keep_all = TRUE) %>%
  # Select coordinate columns
  select(Sett_Clean, X_raw = SettX, Y_raw = SettY) %>%
  # Mean-center and scale to kilometers
  mutate(X_coord = (X_raw - mean(X_raw, na.rm = TRUE)) / 1000,
         Y_coord = (Y_raw - mean(Y_raw, na.rm = TRUE)) / 1000,
         Sett_ID = row_number())

# Create the X Matrix
X_matrix <- settGrid %>%
  select(X_coord, Y_coord) %>%
  as.matrix()

cat("Total number of spatial traps (R):", nrow(X_matrix), "\n")
cat("X range (km):", min(X_matrix[,1]), "to", max(X_matrix[,1]), "\n")
cat("Y range (km):", min(X_matrix[,2]), "to", max(X_matrix[,2]), "\n")
