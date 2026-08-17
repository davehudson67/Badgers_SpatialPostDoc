# ==============================================================================
# WOODCHESTER BADGER MOVEMENT AUDIT
#
# PURPOSE
# -------
# Quantify the spatial and temporal structure of observed badger movements
# before deciding on the spatial state-space for the next hybrid model.
#
# Specifically examines:
#   1. Capture-sett locations and spacing
#   2. Consecutive observed capture movements
#   3. Time gaps between spatial observations
#   4. Same-sett vs within-SG vs between-SG movements
#   5. Core <-> peripheral movements
#   6. Peripheral-sett movements
#   7. Distance distributions by time interval
#   8. Sampling intensity among setts
#
# IMPORTANT
# ---------
# Consecutive CAPTURES are not necessarily consecutive quarters.
# delta_q records how many quarters elapsed between observations.
#
# For estimating quarterly movement scale, delta_q == 1 contains the
# most direct information.
# ==============================================================================


library(tidyverse)
library(lubridate)


# ==============================================================================
# ---- 0. FILE PATHS ----
# ==============================================================================

cmr_file <-
  "data/badger_final_CMRready_wDisease.rds"

sg_lookup_file <-
  "data/Sett_to_SG_Lookup_Auto.csv"

sett_location_file <-
  "data/WoodchesterSettLocations.csv"

network_file <-
  "data/Social_Group_Network.rds"


# Create output directory
dir.create(
  "data/movement_audit",
  recursive = TRUE,
  showWarnings = FALSE
)

# ==============================================================================
# ---- 1. SETT NAME STANDARDISATION ----
# ==============================================================================
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


clean_sett <- function(x) {
  
  x %>%
    
    as.character() %>%
    
    toupper() %>%
    
    str_replace_all(
      "[[:punct:]]",
      " "
    ) %>%
    
    str_squish() %>%
    
    str_remove_all(
      "\\b(SETT|MAIN|OUTLIER)\\b"
    ) %>%
    
    str_replace_all(
      sett_aliases
    ) %>%
    
    str_replace_all(
      "\\s+",
      ""
    )
}


# ==============================================================================
# ---- 2. LOAD SOCIAL-GROUP NETWORK ----
# ==============================================================================

net_data <-
  readRDS(
    network_file
  )


sg_ids <-
  as.integer(
    net_data$sg_id_list
  )


n_sg <-
  length(
    sg_ids
  )


cat(
  "\n========================================\n",
  "NETWORK\n",
  "========================================\n",
  "Number of network SG states:",
  n_sg,
  "\n"
)


# ==============================================================================
# ---- 3. LOAD SETT -> SOCIAL GROUP LOOKUP ----
# ==============================================================================

sg_lookup_raw <-
  read_csv(
    sg_lookup_file,
    show_col_types = FALSE
  )


cat(
  "\nColumns in SG lookup:\n"
)

print(
  names(sg_lookup_raw)
)


# We know the automatic file already contains Sett_Clean,
# based on the previous model code.

if(!"Sett_Clean" %in% names(sg_lookup_raw)) {
  
  stop(
    "Sett_to_SG_Lookup_Auto.csv does not contain Sett_Clean."
  )
}


if(!"SG_id" %in% names(sg_lookup_raw)) {
  
  stop(
    "Sett_to_SG_Lookup_Auto.csv does not contain SG_id."
  )
}


sg_lookup <-
  sg_lookup_raw %>%
  
  transmute(
    
    Sett_Clean =
      clean_sett(
        Sett_Clean
      ),
    
    SG_id =
      as.integer(
        SG_id
      )
  ) %>%
  
  distinct(
    Sett_Clean,
    .keep_all = TRUE
  )


# ---- Audit SG IDs ----

invalid_sg <- sg_lookup %>%
  
  filter(
    !is.na(SG_id),
    !SG_id %in% sg_ids
  )


if(nrow(invalid_sg) > 0L) {
  
  cat(
    "\nWARNING: SG IDs in lookup but absent from network:\n"
  )
  
  print(
    invalid_sg,
    n = Inf
  )
  
} else {
  
  cat(
    "\nPASS: All non-missing lookup SG IDs occur in network.\n"
  )
}


# ==============================================================================
# ---- 4. LOAD SETT COORDINATES ----
# ==============================================================================

sett_location_raw <-
  read_csv(
    sett_location_file,
    show_col_types = FALSE
  )


cat(
  "\n========================================\n",
  "SETT LOCATION FILE\n",
  "========================================\n"
)

cat(
  "\nColumns:\n"
)

print(
  names(sett_location_raw)
)


# ------------------------------------------------------------------------------
# Automatically identify sett-name and coordinate columns
# ------------------------------------------------------------------------------

sett_name_candidates <- c(
  "Sett_Upper",
  "Sett_Clean")


x_candidates <- c(
  "SettX",
  "sett_x",
  "X",
  "x",
  "Easting",
  "easting",
  "Eastings",
  "eastings",
  "official_sett_x"
)


y_candidates <- c(
  "SettY",
  "sett_y",
  "Y",
  "y",
  "Northing",
  "northing",
  "Northings",
  "northings",
  "official_sett_y"
)


sett_name_col <-
  intersect(
    sett_name_candidates,
    names(sett_location_raw)
  )[1]


x_col <-
  intersect(
    x_candidates,
    names(sett_location_raw)
  )[1]


y_col <-
  intersect(
    y_candidates,
    names(sett_location_raw)
  )[1]


if(
  is.na(sett_name_col) ||
  is.na(x_col) ||
  is.na(y_col)
) {
  
  cat(
    "\nCould not identify one or more required columns automatically.\n"
  )
  
  cat(
    "Sett name column:",
    sett_name_col,
    "\n"
  )
  
  cat(
    "X column:",
    x_col,
    "\n"
  )
  
  cat(
    "Y column:",
    y_col,
    "\n\n"
  )
  
  stop(
    "Check names(sett_location_raw) and add the actual column names ",
    "to sett_name_candidates/x_candidates/y_candidates."
  )
}


cat(
  "\nUsing sett-name column:",
  sett_name_col,
  "\n"
)

cat(
  "Using X coordinate:",
  x_col,
  "\n"
)

cat(
  "Using Y coordinate:",
  y_col,
  "\n"
)


# ==============================================================================
# ---- 5. BUILD MASTER SETT TABLE ----
# ==============================================================================

sett_locations <-
  sett_location_raw %>%
  
  transmute(
    
    Sett_original =
      as.character(
        .data[[sett_name_col]]
      ),
    
    Sett_Clean =
      clean_sett(
        .data[[sett_name_col]]
      ),
    
    x =
      as.numeric(
        .data[[x_col]]
      ),
    
    y =
      as.numeric(
        .data[[y_col]]
      )
  )


# ------------------------------------------------------------------------------
# Check for duplicated cleaned names with DIFFERENT coordinates
# ------------------------------------------------------------------------------

duplicate_coordinate_check <-
  sett_locations %>%
  
  filter(
    !is.na(Sett_Clean)
  ) %>%
  
  group_by(
    Sett_Clean
  ) %>%
  
  summarise(
    
    n_rows =
      n(),
    
    n_xy =
      n_distinct(
        paste(
          x,
          y
        )
      ),
    
    .groups =
      "drop"
  ) %>%
  
  filter(
    n_xy > 1L
  )


if(nrow(duplicate_coordinate_check) > 0L) {
  
  cat(
    "\nWARNING: Some cleaned sett names have multiple coordinates:\n"
  )
  
  print(
    duplicate_coordinate_check,
    n = Inf
  )
}


# Keep one coordinate per cleaned sett after audit

sett_locations <-
  sett_locations %>%
  
  distinct(
    Sett_Clean,
    .keep_all = TRUE
  )


# ------------------------------------------------------------------------------
# Combine coordinates and social-group assignment
# ------------------------------------------------------------------------------

sett_master <-
  sett_locations %>%
  
  left_join(
    sg_lookup,
    by = "Sett_Clean"
  ) %>%
  
  mutate(
    
    spatial_class =
      case_when(
        
        SG_id == 999L ~
          "peripheral",
        
        is.na(SG_id) ~
          "SG unassigned",
        
        TRUE ~
          "core"
      )
  )


cat(
  "\n--- MASTER SETT TABLE ---\n"
)


sett_master %>%
  
  summarise(
    
    n_setts =
      n(),
    
    n_with_xy =
      sum(
        !is.na(x) &
          !is.na(y)
      ),
    
    n_core =
      sum(
        spatial_class == "core"
      ),
    
    n_peripheral =
      sum(
        spatial_class == "peripheral"
      ),
    
    n_SG_unassigned =
      sum(
        spatial_class == "SG unassigned"
      )
  ) %>%
  
  print()


# Save master table
write_csv(
  sett_master,
  "data/movement_audit/sett_master.csv"
)


# ==============================================================================
# ---- 6. LOAD CMR DATA ----
# ==============================================================================

cmr_raw <-
  readRDS(
    cmr_file
  )


cmr_q <-
  cmr_raw %>%
  
  mutate(
    
    Sett_Clean =
      clean_sett(
        sett
      )
  ) %>%
  
  left_join(
    
    sg_lookup,
    
    by =
      "Sett_Clean"
  ) %>%
  
  left_join(
    
    sett_locations %>%
      select(
        Sett_Clean,
        x,
        y
      ),
    
    by =
      "Sett_Clean"
  )


# ==============================================================================
# ---- 7. BUILD QUARTER INDEX ----
# ==============================================================================

min_year <-
  min(
    cmr_q$primary_year,
    na.rm = TRUE
  )


max_year <-
  max(
    cmr_q$primary_year,
    na.rm = TRUE
  )


n_years <-
  max_year -
  min_year +
  1L


cmr_q <-
  cmr_q %>%
  
  mutate(
    
    quarter_idx =
      (
        primary_year -
          min_year
      ) *
      4L +
      trap_season
  )


cat(
  "\nStudy period:",
  min_year,
  "-",
  max_year,
  "\n"
)


# ==============================================================================
# ---- 8. AUDIT LOCATION MATCHING ----
# ==============================================================================

capture_location_match_audit <-
  cmr_q %>%
  
  filter(
    has_live_capture
  ) %>%
  
  mutate(
    
    coordinate_status =
      case_when(
        
        is.na(Sett_Clean) |
          Sett_Clean == "" ~
          "missing sett name",
        
        is.na(x) |
          is.na(y) ~
          "sett has no matched coordinates",
        
        TRUE ~
          "coordinates available"
      ),
    
    SG_status =
      case_when(
        
        SG_id == 999L ~
          "peripheral",
        
        is.na(SG_id) ~
          "SG unassigned",
        
        TRUE ~
          "core SG"
      )
  )


cat(
  "\n--- LIVE CAPTURE COORDINATE MATCHING ---\n"
)


capture_location_match_audit %>%
  
  count(
    coordinate_status
  ) %>%
  
  print()


cat(
  "\n--- LIVE CAPTURE SG ASSIGNMENT ---\n"
)


capture_location_match_audit %>%
  
  count(
    SG_status
  ) %>%
  
  print()


# Which capture setts have no coordinates?

missing_coordinate_setts <-
  capture_location_match_audit %>%
  
  filter(
    coordinate_status ==
      "sett has no matched coordinates"
  ) %>%
  
  count(
    Sett_Clean,
    SG_id,
    sort = TRUE
  )


if(nrow(missing_coordinate_setts) > 0L) {
  
  cat(
    "\nCapture setts without matched coordinates:\n"
  )
  
  print(
    missing_coordinate_setts,
    n = Inf
  )
}


write_csv(
  missing_coordinate_setts,
  "data/movement_audit/capture_setts_missing_coordinates.csv"
)


# ==============================================================================
# ---- 9. RESOLVE MULTIPLE CAPTURES WITHIN QUARTERS ----
# ==============================================================================
#
# IMPORTANT:
# We do NOT filter on SG_id here.
#
# A sett with coordinates but no assigned social group is still
# informative for the movement audit.
#
# As in the current HMM, when multiple live captures occur within the same
# quarter, retain the latest capture for this initial audit.
# ==============================================================================

quarterly_live_spatial <-
  cmr_q %>%
  
  filter(
    has_live_capture,
    !is.na(x),
    !is.na(y)
  ) %>%
  
  arrange(
    tattoo,
    quarter_idx,
    capture_date
  ) %>%
  
  group_by(
    tattoo,
    quarter_idx
  ) %>%
  
  slice_tail(
    n = 1
  ) %>%
  
  ungroup()


cat(
  "\n========================================\n",
  "QUARTERLY SPATIAL DATA\n",
  "========================================\n"
)


cat(
  "Quarterly live-capture records:",
  nrow(quarterly_live_spatial),
  "\n"
)


cat(
  "Badgers represented:",
  n_distinct(
    quarterly_live_spatial$tattoo
  ),
  "\n"
)


cat(
  "Capture setts represented:",
  n_distinct(
    quarterly_live_spatial$Sett_Clean
  ),
  "\n"
)


# ==============================================================================
# ---- 10. SETT USAGE AUDIT ----
# ==============================================================================

sett_usage <-
  quarterly_live_spatial %>%
  
  group_by(
    Sett_Clean,
    SG_id,
    x,
    y
  ) %>%
  
  summarise(
    
    n_captures =
      n(),
    
    n_badgers =
      n_distinct(
        tattoo
      ),
    
    n_quarters_used =
      n_distinct(
        quarter_idx
      ),
    
    first_year =
      min(
        primary_year,
        na.rm = TRUE
      ),
    
    last_year =
      max(
        primary_year,
        na.rm = TRUE
      ),
    
    .groups =
      "drop"
  ) %>%
  
  mutate(
    
    spatial_class =
      case_when(
        
        SG_id == 999L ~
          "peripheral",
        
        is.na(SG_id) ~
          "SG unassigned",
        
        TRUE ~
          "core"
      )
  ) %>%
  
  arrange(
    desc(
      n_captures
    )
  )


cat(
  "\n--- SETT USAGE ---\n"
)


print(
  sett_usage,
  n = Inf
)


write_csv(
  sett_usage,
  "data/movement_audit/sett_usage.csv"
)


cat(
  "\nUnique used setts:",
  nrow(sett_usage),
  "\n"
)

cat(
  "Core used setts:",
  sum(
    sett_usage$spatial_class ==
      "core"
  ),
  "\n"
)

cat(
  "Peripheral used setts:",
  sum(
    sett_usage$spatial_class ==
      "peripheral"
  ),
  "\n"
)

cat(
  "Used setts with no SG assignment:",
  sum(
    sett_usage$spatial_class ==
      "SG unassigned"
  ),
  "\n"
)


# ==============================================================================
# ---- 11. BUILD OBSERVED MOVEMENT TRANSITIONS ----
# ==============================================================================

movement_obs <-
  quarterly_live_spatial %>%
  
  arrange(
    tattoo,
    quarter_idx
  ) %>%
  
  group_by(
    tattoo
  ) %>%
  
  mutate(
    
    previous_q =
      lag(
        quarter_idx
      ),
    
    previous_year =
      lag(
        primary_year
      ),
    
    previous_season =
      lag(
        trap_season
      ),
    
    previous_sett =
      lag(
        Sett_Clean
      ),
    
    previous_SG =
      lag(
        SG_id
      ),
    
    previous_x =
      lag(
        x
      ),
    
    previous_y =
      lag(
        y
      )
  ) %>%
  
  ungroup() %>%
  
  filter(
    !is.na(previous_q),
    !is.na(previous_x),
    !is.na(previous_y),
    !is.na(x),
    !is.na(y)
  ) %>%
  
  mutate(
    
    delta_q =
      as.integer(
        quarter_idx -
          previous_q
      ),
    
    distance_m =
      sqrt(
        (
          x -
            previous_x
        )^2 +
          (
            y -
              previous_y
          )^2
      ),
    
    same_sett =
      Sett_Clean ==
      previous_sett,
    
    same_SG =
      !is.na(SG_id) &
      !is.na(previous_SG) &
      SG_id ==
      previous_SG,
    
    movement_type =
      case_when(
        
        same_sett ~
          "same sett",
        
        previous_SG == 999L &
          SG_id == 999L ~
          "different peripheral sett",
        
        previous_SG == 999L &
          !is.na(SG_id) &
          SG_id != 999L ~
          "peripheral -> core",
        
        !is.na(previous_SG) &
          previous_SG != 999L &
          SG_id == 999L ~
          "core -> peripheral",
        
        !is.na(previous_SG) &
          !is.na(SG_id) &
          previous_SG == SG_id ~
          "different sett, same SG",
        
        !is.na(previous_SG) &
          !is.na(SG_id) &
          previous_SG != SG_id ~
          "different SG",
        
        TRUE ~
          "SG unassigned"
      )
  )


# Safety checks

if(any(movement_obs$delta_q <= 0)) {
  
  stop(
    "Found movement transitions with delta_q <= 0."
  )
}


if(any(movement_obs$distance_m < 0)) {
  
  stop(
    "Negative movement distance found."
  )
}


cat(
  "\n========================================\n",
  "MOVEMENT TRANSITIONS\n",
  "========================================\n"
)


cat(
  "Observed capture-to-capture transitions:",
  nrow(movement_obs),
  "\n"
)


cat(
  "Badgers contributing transitions:",
  n_distinct(
    movement_obs$tattoo
  ),
  "\n"
)


write_csv(
  movement_obs,
  "data/movement_audit/all_observed_movements.csv"
)


# ==============================================================================
# ---- 12. OVERALL MOVEMENT-TYPE SUMMARY ----
# ==============================================================================

movement_summary <-
  movement_obs %>%
  
  group_by(
    movement_type
  ) %>%
  
  summarise(
    
    n =
      n(),
    
    n_badgers =
      n_distinct(
        tattoo
      ),
    
    median_distance_m =
      median(
        distance_m
      ),
    
    mean_distance_m =
      mean(
        distance_m
      ),
    
    q25_distance_m =
      quantile(
        distance_m,
        0.25
      ),
    
    q75_distance_m =
      quantile(
        distance_m,
        0.75
      ),
    
    q90_distance_m =
      quantile(
        distance_m,
        0.90
      ),
    
    q95_distance_m =
      quantile(
        distance_m,
        0.95
      ),
    
    max_distance_m =
      max(
        distance_m
      ),
    
    median_gap_q =
      median(
        delta_q
      ),
    
    .groups =
      "drop"
  )


cat(
  "\n--- ALL OBSERVED MOVEMENTS ---\n"
)


print(
  movement_summary,
  n = Inf
)


write_csv(
  movement_summary,
  "data/movement_audit/movement_summary_all.csv"
)


# ==============================================================================
# ---- 13. TIME GAP BETWEEN OBSERVED CAPTURES ----
# ==============================================================================

gap_frequency <-
  movement_obs %>%
  
  count(
    delta_q,
    name = "n_transitions"
  ) %>%
  
  arrange(
    delta_q
  )


cat(
  "\n--- NUMBER OF QUARTERS BETWEEN OBSERVED CAPTURES ---\n"
)


print(
  gap_frequency,
  n = Inf
)


write_csv(
  gap_frequency,
  "data/movement_audit/transition_gap_frequency.csv"
)


# Broader gap classes

movement_by_gap <-
  movement_obs %>%
  
  mutate(
    
    gap_class =
      case_when(
        
        delta_q == 1L ~
          "1 quarter",
        
        delta_q == 2L ~
          "2 quarters",
        
        delta_q <= 4L ~
          "3-4 quarters",
        
        delta_q <= 8L ~
          "5-8 quarters",
        
        TRUE ~
          ">8 quarters"
      ),
    
    gap_class =
      factor(
        gap_class,
        levels = c(
          "1 quarter",
          "2 quarters",
          "3-4 quarters",
          "5-8 quarters",
          ">8 quarters"
        )
      )
  ) %>%
  
  group_by(
    gap_class
  ) %>%
  
  summarise(
    
    n =
      n(),
    
    n_badgers =
      n_distinct(
        tattoo
      ),
    
    median_distance_m =
      median(
        distance_m
      ),
    
    q75_distance_m =
      quantile(
        distance_m,
        0.75
      ),
    
    q90_distance_m =
      quantile(
        distance_m,
        0.90
      ),
    
    q95_distance_m =
      quantile(
        distance_m,
        0.95
      ),
    
    .groups =
      "drop"
  )


cat(
  "\n--- DISPLACEMENT BY TIME GAP ---\n"
)


print(
  movement_by_gap,
  n = Inf
)


write_csv(
  movement_by_gap,
  "data/movement_audit/movement_by_gap.csv"
)


# ==============================================================================
# ---- 14. ADJACENT-QUARTER MOVEMENT ----
# ==============================================================================
#
# These are especially important because they provide the closest thing
# in this dataset to direct observations of quarterly displacement.
# ==============================================================================

movement_q1 <-
  movement_obs %>%
  
  filter(
    delta_q == 1L
  )


adjacent_summary <-
  movement_q1 %>%
  
  group_by(
    movement_type
  ) %>%
  
  summarise(
    
    n =
      n(),
    
    n_badgers =
      n_distinct(
        tattoo
      ),
    
    proportion =
      n() /
      nrow(
        movement_q1
      ),
    
    median_distance_m =
      median(
        distance_m
      ),
    
    mean_distance_m =
      mean(
        distance_m
      ),
    
    q25_distance_m =
      quantile(
        distance_m,
        0.25
      ),
    
    q75_distance_m =
      quantile(
        distance_m,
        0.75
      ),
    
    q90_distance_m =
      quantile(
        distance_m,
        0.90
      ),
    
    q95_distance_m =
      quantile(
        distance_m,
        0.95
      ),
    
    max_distance_m =
      max(
        distance_m
      ),
    
    .groups =
      "drop"
  )


cat(
  "\n--- CONSECUTIVE-QUARTER MOVEMENTS ---\n"
)


print(
  adjacent_summary,
  n = Inf
)


write_csv(
  adjacent_summary,
  "data/movement_audit/movement_adjacent_quarters.csv"
)


# ==============================================================================
# ---- 15. SAME SETT / WITHIN SG / BETWEEN SG ----
# ==============================================================================

core_q1 <-
  movement_q1 %>%
  
  filter(
    previous_SG != 999L,
    SG_id != 999L,
    !is.na(previous_SG),
    !is.na(SG_id)
  ) %>%
  
  mutate(
    
    core_movement_class =
      case_when(
        
        same_sett ~
          "same sett",
        
        previous_SG == SG_id ~
          "different sett, same SG",
        
        TRUE ~
          "different SG"
      )
  )


core_movement_summary <-
  core_q1 %>%
  
  group_by(
    core_movement_class
  ) %>%
  
  summarise(
    
    n =
      n(),
    
    n_badgers =
      n_distinct(
        tattoo
      ),
    
    proportion =
      n() /
      nrow(
        core_q1
      ),
    
    median_distance_m =
      median(
        distance_m
      ),
    
    q75_distance_m =
      quantile(
        distance_m,
        0.75
      ),
    
    q90_distance_m =
      quantile(
        distance_m,
        0.90
      ),
    
    q95_distance_m =
      quantile(
        distance_m,
        0.95
      ),
    
    .groups =
      "drop"
  )


cat(
  "\n--- CORE MOVEMENT: SETT VS SOCIAL GROUP ---\n"
)


print(
  core_movement_summary,
  n = Inf
)


write_csv(
  core_movement_summary,
  "data/movement_audit/core_movement_summary_q1.csv"
)


# ==============================================================================
# ---- 16. PERIPHERAL / SG 999 AUDIT ----
# ==============================================================================

peripheral_movements <-
  movement_obs %>%
  
  filter(
    previous_SG == 999L |
      SG_id == 999L
  )


peripheral_pair_summary <-
  peripheral_movements %>%
  
  group_by(
    previous_sett,
    Sett_Clean,
    movement_type
  ) %>%
  
  summarise(
    
    n =
      n(),
    
    n_badgers =
      n_distinct(
        tattoo
      ),
    
    median_distance_m =
      median(
        distance_m
      ),
    
    median_gap_q =
      median(
        delta_q
      ),
    
    .groups =
      "drop"
  ) %>%
  
  arrange(
    desc(n)
  )


cat(
  "\n--- PERIPHERAL MOVEMENT PAIRS ---\n"
)


print(
  peripheral_pair_summary,
  n = Inf
)


write_csv(
  peripheral_pair_summary,
  "data/movement_audit/peripheral_movement_pairs.csv"
)


# Specifically 999 -> 999

peripheral_to_peripheral <-
  movement_obs %>%
  
  filter(
    previous_SG == 999L,
    SG_id == 999L
  ) %>%
  
  mutate(
    
    peripheral_detail =
      if_else(
        previous_sett == Sett_Clean,
        "same peripheral sett",
        "different peripheral sett"
      )
  )


cat(
  "\n--- 999 -> 999 DETAIL ---\n"
)


peripheral_to_peripheral %>%
  
  count(
    peripheral_detail
  ) %>%
  
  print()


cat(
  "\n--- SPECIFIC PERIPHERAL SETT PAIRS ---\n"
)


peripheral_to_peripheral %>%
  
  count(
    previous_sett,
    Sett_Clean,
    sort = TRUE
  ) %>%
  
  print(
    n = Inf
  )


# ==============================================================================
# ---- 17. SETT-TO-SETT DISTANCE MATRIX ----
# ==============================================================================

sett_used <-
  sett_usage %>%
  
  filter(
    !is.na(x),
    !is.na(y)
  ) %>%
  
  arrange(
    Sett_Clean
  )


coords <-
  as.matrix(
    
    sett_used %>%
      
      select(
        x,
        y
      )
  )


sett_distance_matrix <-
  as.matrix(
    dist(
      coords
    )
  )


rownames(
  sett_distance_matrix
) <-
  sett_used$Sett_Clean


colnames(
  sett_distance_matrix
) <-
  sett_used$Sett_Clean


# Save complete matrix

write.csv(
  sett_distance_matrix,
  "data/movement_audit/sett_distance_matrix_m.csv",
  row.names = TRUE
)


# ==============================================================================
# ---- 18. NEAREST-NEIGHBOUR SETT SPACING ----
# ==============================================================================

sett_distance_for_nn <-
  sett_distance_matrix


diag(
  sett_distance_for_nn
) <-
  NA_real_


nearest_sett_distance <-
  apply(
    sett_distance_for_nn,
    1,
    min,
    na.rm = TRUE
  )


sett_spacing <-
  sett_used %>%
  
  mutate(
    
    nearest_sett_m =
      nearest_sett_distance
  )


cat(
  "\n--- NEAREST SETT SPACING ---\n"
)


print(
  summary(
    sett_spacing$nearest_sett_m
  )
)


cat(
  "\nQuantiles:\n"
)


print(
  
  quantile(
    
    sett_spacing$nearest_sett_m,
    
    probs =
      c(
        0.05,
        0.10,
        0.25,
        0.50,
        0.75,
        0.90,
        0.95
      ),
    
    na.rm =
      TRUE
  )
)


write_csv(
  sett_spacing,
  "data/movement_audit/sett_spacing.csv"
)


# ==============================================================================
# ---- 19. OBSERVED TRANSITION MATRIX BETWEEN SETTS ----
# ==============================================================================

sett_transition_counts <-
  movement_obs %>%
  
  count(
    previous_sett,
    Sett_Clean,
    sort = TRUE,
    name = "n"
  )


cat(
  "\n--- MOST COMMON OBSERVED SETT TRANSITIONS ---\n"
)


print(
  sett_transition_counts,
  n = 30
)


write_csv(
  sett_transition_counts,
  "data/movement_audit/sett_transition_counts.csv"
)


# Same, but only consecutive quarters

sett_transition_counts_q1 <-
  movement_q1 %>%
  
  count(
    previous_sett,
    Sett_Clean,
    sort = TRUE,
    name = "n"
  )


write_csv(
  sett_transition_counts_q1,
  "data/movement_audit/sett_transition_counts_q1.csv"
)


# ==============================================================================
# ---- 20. DISTANCE DISTRIBUTION FOR ADJACENT QUARTERS ----
# ==============================================================================

cat(
  "\n--- OVERALL ADJACENT-QUARTER DISTANCE DISTRIBUTION ---\n"
)


print(
  summary(
    movement_q1$distance_m
  )
)


cat(
  "\nAdjacent-quarter distance quantiles:\n"
)


print(
  
  quantile(
    
    movement_q1$distance_m,
    
    probs =
      c(
        0.25,
        0.50,
        0.75,
        0.80,
        0.90,
        0.95,
        0.975,
        0.99
      ),
    
    na.rm =
      TRUE
  )
)


# Exclude zero-distance repeat captures for actual displacement distribution

movement_q1_moved <-
  movement_q1 %>%
  
  filter(
    distance_m > 0
  )


cat(
  "\n--- ADJACENT-QUARTER DISTANCE WHEN SETT CHANGED ---\n"
)


print(
  
  quantile(
    
    movement_q1_moved$distance_m,
    
    probs =
      c(
        0.25,
        0.50,
        0.75,
        0.80,
        0.90,
        0.95,
        0.975,
        0.99
      ),
    
    na.rm =
      TRUE
  )
)


# ==============================================================================
# ---- 21. PLOTS ----
# ==============================================================================


# ------------------------------------------------------------------------------
# Plot 1: displacement vs time between observed captures
# ------------------------------------------------------------------------------

p_gap <-
  movement_obs %>%
  
  filter(
    delta_q <= 12L
  ) %>%
  
  ggplot(
    aes(
      x =
        factor(
          delta_q
        ),
      
      y =
        distance_m
    )
  ) +
  
  geom_boxplot(
    outlier.alpha =
      0.15
  ) +
  
  coord_cartesian(
    
    ylim =
      c(
        0,
        quantile(
          movement_obs$distance_m,
          0.99,
          na.rm = TRUE
        )
      )
  ) +
  
  labs(
    
    x =
      "Quarters between observed captures",
    
    y =
      "Observed sett-to-sett displacement (m)",
    
    title =
      "Badger spatial displacement through time",
    
    subtitle =
      "Successive captures are separated according to elapsed quarters"
  ) +
  
  theme_minimal()


print(
  p_gap
)

dev.off()
ggsave(
  "data/movement_audit/displacement_by_time_gap.png",
  p_gap,
  width = 9,
  height = 6,
  dpi = 300
)


# ------------------------------------------------------------------------------
# Plot 2: adjacent-quarter movement type
# ------------------------------------------------------------------------------

p_type <-
  movement_q1 %>%
  
  ggplot(
    
    aes(
      x =
        movement_type,
      
      y =
        distance_m
    )
  ) +
  
  geom_boxplot(
    outlier.alpha =
      0.15
  ) +
  
  coord_cartesian(
    
    ylim =
      c(
        0,
        quantile(
          movement_q1$distance_m,
          0.99,
          na.rm = TRUE
        )
      )
  ) +
  
  labs(
    
    x =
      NULL,
    
    y =
      "Observed displacement (m)",
    
    title =
      "Consecutive-quarter movement by spatial transition type"
  ) +
  
  theme_minimal() +
  
  theme(
    
    axis.text.x =
      element_text(
        angle = 35,
        hjust = 1
      )
  )


print(
  p_type
)


ggsave(
  "data/movement_audit/q1_movement_by_type.png",
  p_type,
  width = 10,
  height = 6,
  dpi = 300
)


# ------------------------------------------------------------------------------
# Plot 3: sett sampling intensity
# ------------------------------------------------------------------------------

p_sett_usage <-
  sett_usage %>%
  
  ggplot(
    
    aes(
      x =
        reorder(
          Sett_Clean,
          n_captures
        ),
      
      y =
        n_captures
    )
  ) +
  
  geom_col() +
  
  coord_flip() +
  
  labs(
    
    x =
      "Sett",
    
    y =
      "Quarterly capture records",
    
    title =
      "Sampling intensity among Woodchester setts"
  ) +
  
  theme_minimal()


print(
  p_sett_usage
)


ggsave(
  "data/movement_audit/sett_capture_intensity.png",
  p_sett_usage,
  width = 8,
  height = 12,
  dpi = 300
)


# ------------------------------------------------------------------------------
# Plot 4: spatial distribution of USED capture setts
# ------------------------------------------------------------------------------

p_sett_map <-
  sett_usage %>%
  
  ggplot(
    
    aes(
      x = x,
      y = y,
      
      size =
        n_captures,
      
      shape =
        spatial_class
    )
  ) +
  
  geom_point(
    alpha =
      0.7
  ) +
  
  coord_equal() +
  
  labs(
    
    x =
      "Easting",
    
    y =
      "Northing",
    
    size =
      "Captures",
    
    shape =
      "Spatial class",
    
    title =
      "Spatial distribution and sampling intensity of capture setts"
  ) +
  
  theme_minimal()


print(
  p_sett_map
)


ggsave(
  "data/movement_audit/sett_spatial_distribution.png",
  p_sett_map,
  width = 8,
  height = 8,
  dpi = 300
)


# ==============================================================================
# ---- 22. KEY SUMMARY FOR MODEL DESIGN ----
# ==============================================================================

cat(
  "\n\n============================================================\n",
  "KEY RESULTS FOR CHOOSING SPATIAL STATE-SPACE\n",
  "============================================================\n"
)


cat(
  "\nNumber of used capture setts:",
  nrow(sett_usage),
  "\n"
)


cat(
  "Number of badgers with spatial transitions:",
  n_distinct(movement_obs$tattoo),
  "\n"
)


cat(
  "Total observed capture-to-capture transitions:",
  nrow(movement_obs),
  "\n"
)


cat(
  "Consecutive-quarter transitions:",
  nrow(movement_q1),
  "\n"
)


cat(
  "Proportion consecutive-quarter:",
  round(
    nrow(movement_q1) /
      nrow(movement_obs),
    3
  ),
  "\n"
)


cat(
  "\nMedian nearest-sett spacing (m):",
  round(
    median(
      sett_spacing$nearest_sett_m,
      na.rm = TRUE
    ),
    1
  ),
  "\n"
)


cat(
  "25th percentile nearest-sett spacing (m):",
  round(
    quantile(
      sett_spacing$nearest_sett_m,
      0.25,
      na.rm = TRUE
    ),
    1
  ),
  "\n"
)


cat(
  "75th percentile nearest-sett spacing (m):",
  round(
    quantile(
      sett_spacing$nearest_sett_m,
      0.75,
      na.rm = TRUE
    ),
    1
  ),
  "\n"
)


cat(
  "\nMedian adjacent-quarter displacement (m):",
  round(
    median(
      movement_q1$distance_m,
      na.rm = TRUE
    ),
    1
  ),
  "\n"
)


cat(
  "90th percentile adjacent-quarter displacement (m):",
  round(
    quantile(
      movement_q1$distance_m,
      0.90,
      na.rm = TRUE
    ),
    1
  ),
  "\n"
)


cat(
  "95th percentile adjacent-quarter displacement (m):",
  round(
    quantile(
      movement_q1$distance_m,
      0.95,
      na.rm = TRUE
    ),
    1
  ),
  "\n"
)


cat(
  "\nSame-sett consecutive-quarter proportion:",
  round(
    mean(
      movement_q1$same_sett,
      na.rm = TRUE
    ),
    3
  ),
  "\n"
)


# Within/between social groups excluding peripheral and unassigned setts

core_changed_sett_q1 <-
  movement_q1 %>%
  
  filter(
    !same_sett,
    !is.na(previous_SG),
    !is.na(SG_id),
    previous_SG != 999L,
    SG_id != 999L
  )


if(nrow(core_changed_sett_q1) > 0L) {
  
  cat(
    "\nAmong adjacent-quarter CORE movements where the sett changed:\n"
  )
  
  cat(
    "Proportion staying within same SG:",
    round(
      mean(
        core_changed_sett_q1$previous_SG ==
          core_changed_sett_q1$SG_id
      ),
      3
    ),
    "\n"
  )
  
  cat(
    "Proportion crossing SG boundary:",
    round(
      mean(
        core_changed_sett_q1$previous_SG !=
          core_changed_sett_q1$SG_id
      ),
      3
    ),
    "\n"
  )
}


cat(
  "\n============================================================\n",
  "AUDIT COMPLETE\n",
  "Outputs saved to:\n",
  "data/processed/movement_audit/\n",
  "============================================================\n"
)
