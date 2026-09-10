# =============================================================================
# WOODCHESTER SPATIAL PRESSURE AUDIT 2
# Resolve detector/sett coordinates and movement endpoint locations
#
# The first audit found:
# - no posterior activity-centre coordinates saved in final FFBS/chain outputs
# - no XY columns in encounters_useful
# - excellent social-group support
# - existing detector/sett spatial lookup files
#
# This audit tests whether:
#   from_primary / to_primary in the final movement interval index
#   can be mapped to the final Stage-1 detector table,
# and whether encounter setts can be mapped to Woodchester sett coordinates.
#
# It also constructs a canonical annual OBSERVED spatial table for later
# infection-pressure calculations. No location imputation is performed.
# =============================================================================

library(tidyverse)

CHAIN_FILE <- "results/RD_SCR_V7MCMHMMv6_PAIR_AC_1285_CHAIN_1_FINAL30K.rds"
MOVE_FILE  <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
ENC_FILE   <- "data/badger_encounters_useful.rds"
INF_FILE   <- "data/badger_infection_trajectories_all_tests_inferred.rds"

SETT_FILES <- c(
  "data/movement_audit/sett_master.csv",
  "data/WoodchesterSettLocations.csv",
  "data/sett_dictionary.csv"
)

for(f in c(CHAIN_FILE,MOVE_FILE,ENC_FILE,INF_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

ch <- readRDS(CHAIN_FILE)
mov <- readRDS(MOVE_FILE)
enc <- readRDS(ENC_FILE)
inf <- readRDS(INF_FILE)

dir.create("results",showWarnings=FALSE,recursive=TRUE)

norm <- function(x) gsub("[^A-Z0-9]","",toupper(trimws(as.character(x))))

pick_col <- function(df,candidates,label,required=FALSE){
  nmap <- setNames(names(df),tolower(gsub("[^a-z0-9]","",names(df))))
  c2 <- tolower(gsub("[^a-z0-9]","",candidates))
  hit <- c2[c2%in%names(nmap)]
  if(length(hit)){
    ans <- unname(nmap[hit[1]])
    cat(label,":",ans,"\n")
    return(ans)
  }
  cat(label,": NOT FOUND\n")
  if(required) stop("Required field missing: ",label)
  NULL
}

# =============================================================================
# A. DETECTOR TABLE
# =============================================================================

cat("\n============================================================\n")
cat("A. FINAL STAGE-1 DETECTOR TABLE\n")
cat("============================================================\n")

det <- as_tibble(ch$detectors)
cat("Rows:",nrow(det),"\n")
cat("Columns:\n")
print(names(det))
cat("\nFirst 12 rows:\n")
print(head(det,12),n=12,width=Inf)

det_name <- pick_col(
  det,
  c("sett","sett_name","name","detector","detector_name","trap"),
  "Detector name",FALSE
)
det_x <- pick_col(
  det,
  c("x","easting","east","xcoord","x_coord","sett_x"),
  "Detector X/Easting",FALSE
)
det_y <- pick_col(
  det,
  c("y","northing","north","ycoord","y_coord","sett_y"),
  "Detector Y/Northing",FALSE
)
det_id <- pick_col(
  det,
  c("detector_id","detectorid","sett_id","settid","id"),
  "Detector ID",FALSE
)

cat("\nDetector coordinate availability:\n")
if(!is.null(det_x) && !is.null(det_y)){
  dx <- suppressWarnings(as.numeric(det[[det_x]]))
  dy <- suppressWarnings(as.numeric(det[[det_y]]))
  cat("Finite XY:",sum(is.finite(dx)&is.finite(dy)),"/",nrow(det),"\n")
  cat("X range:",paste(range(dx[is.finite(dx)]),collapse=" to "),"\n")
  cat("Y range:",paste(range(dy[is.finite(dy)]),collapse=" to "),"\n")
}else{
  cat("No explicit detector XY pair detected.\n")
}

# =============================================================================
# B. from_primary / to_primary MAPPING
# =============================================================================

cat("\n============================================================\n")
cat("B. MOVEMENT from_primary / to_primary\n")
cat("============================================================\n")

idx <- as_tibble(mov$interval_index) %>%
  mutate(interval_col=row_number())

need <- c("tattoo","from_year","to_year","from_primary","to_primary")
if(!all(need%in%names(idx)))
  stop("interval_index lacks: ",paste(setdiff(need,names(idx)),collapse=", "))

cat("from_primary class:",class(idx$from_primary),"\n")
cat("to_primary class:",class(idx$to_primary),"\n")
cat("from_primary range:\n")
print(range(idx$from_primary,na.rm=TRUE))
cat("to_primary range:\n")
print(range(idx$to_primary,na.rm=TRUE))
cat("Unique from_primary:",n_distinct(idx$from_primary,na.rm=TRUE),"\n")
cat("Unique to_primary:",n_distinct(idx$to_primary,na.rm=TRUE),"\n")
cat("Missing from/to:",
    sum(is.na(idx$from_primary)),
    sum(is.na(idx$to_primary)),"\n")

# Test the most likely interpretation: 1-based detector row indices.
row_index_plausible <-
  is.numeric(idx$from_primary) &&
  is.numeric(idx$to_primary) &&
  all(idx$from_primary[!is.na(idx$from_primary)]>=1 &
      idx$from_primary[!is.na(idx$from_primary)]<=nrow(det)) &&
  all(idx$to_primary[!is.na(idx$to_primary)]>=1 &
      idx$to_primary[!is.na(idx$to_primary)]<=nrow(det))

cat("\n1-based detector-row mapping plausible:",
    row_index_plausible,"\n")

endpoint_map <- idx %>%
  transmute(
    interval_col,
    tattoo=trimws(as.character(tattoo)),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year),
    from_primary,
    to_primary
  )

if(row_index_plausible){
  f <- as.integer(endpoint_map$from_primary)
  t <- as.integer(endpoint_map$to_primary)

  if(!is.null(det_name)){
    endpoint_map$from_detector_name <- as.character(det[[det_name]][f])
    endpoint_map$to_detector_name   <- as.character(det[[det_name]][t])
  }

  if(!is.null(det_x) && !is.null(det_y)){
    endpoint_map$from_x <- as.numeric(det[[det_x]][f])
    endpoint_map$from_y <- as.numeric(det[[det_y]][f])
    endpoint_map$to_x   <- as.numeric(det[[det_x]][t])
    endpoint_map$to_y   <- as.numeric(det[[det_y]][t])
    endpoint_map$observed_endpoint_distance_m <-
      sqrt((endpoint_map$to_x-endpoint_map$from_x)^2 +
           (endpoint_map$to_y-endpoint_map$from_y)^2)
  }

  cat("\nExample mapped intervals:\n")
  print(head(endpoint_map,20),n=20,width=Inf)
}

# =============================================================================
# C. annual_obs / disp_index CROSS-CHECK
# =============================================================================

cat("\n============================================================\n")
cat("C. STAGE-1 annual_obs AND disp_index\n")
cat("============================================================\n")

cat("annual_obs columns:\n")
print(names(ch$annual_obs))
cat("\nannual_obs first 15:\n")
print(head(as_tibble(ch$annual_obs),15),n=15,width=Inf)

cat("\ndisp_index columns:\n")
print(names(ch$disp_index))
cat("\ndisp_index first 15:\n")
print(head(as_tibble(ch$disp_index),15),n=15,width=Inf)

# Compare final FFBS interval index to chain disp_index exactly on core fields.
di <- as_tibble(ch$disp_index)

common <- intersect(
  c("model_i","individual_id","tattoo","state_k","from_primary","to_primary",
    "from_year","to_year","is_initial_interval","node"),
  intersect(names(idx),names(di))
)

if(length(common)){
  same <- identical(
    idx %>% select(all_of(common)),
    di %>% select(all_of(common))
  )
  cat("\nFinal FFBS interval_index identical to chain disp_index on common fields:",
      same,"\n")
}

# =============================================================================
# D. SETT LOOKUP FILES
# =============================================================================

cat("\n============================================================\n")
cat("D. SETT SPATIAL LOOKUPS\n")
cat("============================================================\n")

sett_tables <- list()

for(f in SETT_FILES){
  if(!file.exists(f)){
    cat("\nMISSING:",f,"\n")
    next
  }

  cat("\nFILE:",f,"\n")
  z <- suppressMessages(readr::read_csv(f,show_col_types=FALSE))
  cat("Rows:",nrow(z),"\n")
  cat("Columns:\n")
  print(names(z))
  cat("First 10:\n")
  print(head(z,10),n=10,width=Inf)

  sname <- pick_col(
    z,
    c("sett","sett_name","settname","name"),
    paste0("Sett name [",basename(f),"]"),FALSE
  )
  sx <- pick_col(
    z,
    c("x","easting","east","xcoord","x_coord","sett_x"),
    paste0("X [",basename(f),"]"),FALSE
  )
  sy <- pick_col(
    z,
    c("y","northing","north","ycoord","y_coord","sett_y"),
    paste0("Y [",basename(f),"]"),FALSE
  )

  sett_tables[[f]] <- list(
    data=z,name_col=sname,x_col=sx,y_col=sy
  )
}

# Choose first lookup with name + XY.
chosen_name <- NULL
chosen <- NULL

for(nm in names(sett_tables)){
  q <- sett_tables[[nm]]
  if(!is.null(q$name_col) && !is.null(q$x_col) && !is.null(q$y_col)){
    chosen_name <- nm
    chosen <- q
    break
  }
}

cat("\nChosen sett-coordinate lookup:",
    ifelse(is.null(chosen_name),"NONE",chosen_name),"\n")

# =============================================================================
# E. ENCOUNTER -> SETT COORDINATE COVERAGE
# =============================================================================

cat("\n============================================================\n")
cat("E. ENCOUNTER TO SETT-COORDINATE COVERAGE\n")
cat("============================================================\n")

enc2 <- as_tibble(enc)

tattoo_col <- pick_col(enc2,c("tattoo"),"Encounter tattoo",TRUE)
date_col <- pick_col(enc2,c("capture_date","capdate"),"Encounter date",TRUE)
sett_col <- pick_col(
  enc2,c("sett","sett_name","recorded_sett_name"),
  "Encounter sett",TRUE
)
socg_col <- pick_col(
  enc2,c("socg","socg_name","social_group"),
  "Encounter social group",FALSE
)

enc2 <- enc2 %>%
  mutate(
    tattoo_audit=trimws(as.character(.data[[tattoo_col]])),
    capture_year=as.integer(format(as.Date(.data[[date_col]]),"%Y")),
    sett_audit=trimws(as.character(.data[[sett_col]])),
    sett_key=norm(sett_audit),
    socg_audit=if(!is.null(socg_col))
      trimws(as.character(.data[[socg_col]])) else NA_character_
  )

if(!is.null(chosen)){
  sl <- chosen$data %>%
    transmute(
      sett_lookup=trimws(as.character(.data[[chosen$name_col]])),
      sett_key=norm(sett_lookup),
      x=as.numeric(.data[[chosen$x_col]]),
      y=as.numeric(.data[[chosen$y_col]])
    ) %>%
    filter(sett_key!="") %>%
    distinct(sett_key,.keep_all=TRUE)

  enc2 <- enc2 %>%
    left_join(sl,by="sett_key") %>%
    mutate(has_xy=is.finite(x)&is.finite(y))

  cat("Encounter rows with sett:",sum(enc2$sett_key!=""),"\n")
  cat("Encounter rows mapped to finite XY:",sum(enc2$has_xy),"/",nrow(enc2),
      sprintf("(%.1f%%)",100*mean(enc2$has_xy)),"\n")

  missing_setts <- enc2 %>%
    filter(sett_key!="",!has_xy) %>%
    count(sett_audit,sort=TRUE)

  cat("\nUnmapped encounter sett names (top 30):\n")
  print(head(missing_setts,30),n=30,width=Inf)

  # Canonical annual observed location: choose the last live encounter in year
  # after DataPrep fusion. This is OBSERVED location, not activity centre.
  annual_spatial <- enc2 %>%
    filter(
      tattoo_audit!="",
      !is.na(capture_year)
    ) %>%
    arrange(tattoo_audit,capture_year,.data[[date_col]]) %>%
    group_by(tattoo_audit,capture_year) %>%
    summarise(
      n_encounters=n(),
      sett={
        vv <- sett_audit[!is.na(sett_audit) & sett_audit!=""]
        if(length(vv)) tail(vv,1) else NA_character_
      },
      socg={
        vv <- socg_audit[!is.na(socg_audit) & socg_audit!=""]
        if(length(vv)) tail(vv,1) else NA_character_
      },
      x={
        vv <- x[is.finite(x)]
        if(length(vv)) tail(vv,1) else NA_real_
      },
      y={
        vv <- y[is.finite(y)]
        if(length(vv)) tail(vv,1) else NA_real_
      },
      n_distinct_sett=n_distinct(sett_audit[sett_audit!=""]),
      n_distinct_socg=n_distinct(socg_audit[!is.na(socg_audit)&socg_audit!=""]),
      .groups="drop"
    ) %>%
    mutate(
      has_xy=is.finite(x)&is.finite(y),
      in_infection_model=tattoo_audit%in%trimws(as.character(inf$tattoo)),
      in_phase2=tattoo_audit%in%trimws(as.character(mov$ids))
    )

  cat("\nAnnual observed-location coverage:\n")
  print(
    annual_spatial %>%
      summarise(
        annual_rows=n(),
        badgers=n_distinct(tattoo_audit),
        exact_xy=sum(has_xy),
        exact_xy_pct=100*mean(has_xy),
        multi_sett_years=sum(n_distinct_sett>1),
        multi_socg_years=sum(n_distinct_socg>1)
      ),
    width=Inf
  )

  cat("\nAnnual infection-model observed-location coverage:\n")
  print(
    annual_spatial %>%
      filter(in_infection_model) %>%
      summarise(
        annual_rows=n(),
        badgers=n_distinct(tattoo_audit),
        exact_xy=sum(has_xy),
        exact_xy_pct=100*mean(has_xy)
      ),
    width=Inf
  )

  write_csv(
    annual_spatial,
    "results/badger_annual_observed_spatial_locations.csv"
  )
  saveRDS(
    annual_spatial,
    "data/badger_annual_observed_spatial_locations.rds"
  )
}else{
  annual_spatial <- tibble()
  cat("No sett-coordinate lookup was resolvable, so no annual spatial table created.\n")
}

# =============================================================================
# F. MOVEMENT-ENDPOINT COORDINATE COVERAGE + MOVEMENT SANITY CHECK
# =============================================================================

cat("\n============================================================\n")
cat("F. MOVEMENT ENDPOINT COORDINATES / SANITY CHECK\n")
cat("============================================================\n")

if(row_index_plausible && !is.null(det_x) && !is.null(det_y)){
  endpoint_map <- endpoint_map %>%
    mutate(
      has_origin_xy=is.finite(from_x)&is.finite(from_y),
      has_destination_xy=is.finite(to_x)&is.finite(to_y)
    )

  cat("Intervals with both detector endpoints:",
      sum(endpoint_map$has_origin_xy & endpoint_map$has_destination_xy),
      "/",nrow(endpoint_map),"\n")

  if("p_high"%in%names(mov$interval_summary)){
    sm <- as_tibble(mov$interval_summary) %>%
      mutate(interval_col=row_number()) %>%
      select(interval_col,p_high)

    tmp <- endpoint_map %>%
      left_join(sm,by="interval_col")

    cat("Correlation observed endpoint distance vs posterior P(high):",
        cor(tmp$observed_endpoint_distance_m,tmp$p_high,use="complete.obs"),
        "\n")
  }else{
    # find likely posterior-high probability field
    cat("interval_summary columns:\n")
    print(names(mov$interval_summary))
  }

  cat("\nObserved endpoint distance summary (m):\n")
  print(
    endpoint_map %>%
      summarise(
        median=median(observed_endpoint_distance_m,na.rm=TRUE),
        q75=quantile(observed_endpoint_distance_m,.75,na.rm=TRUE),
        q90=quantile(observed_endpoint_distance_m,.90,na.rm=TRUE),
        q95=quantile(observed_endpoint_distance_m,.95,na.rm=TRUE),
        max=max(observed_endpoint_distance_m,na.rm=TRUE)
      ),
    width=Inf
  )

  write_csv(
    endpoint_map,
    "results/phase2_movement_observed_endpoint_coordinates.csv"
  )
}

# =============================================================================
# G. DECISION
# =============================================================================

cat("\n============================================================\n")
cat("G. DECISION FOR INFECTION-PRESSURE CONSTRUCTION\n")
cat("============================================================\n")

if(row_index_plausible && !is.null(det_x) && !is.null(det_y)){
  cat("Movement interval observed origin/destination coordinates: AVAILABLE\n")
}else{
  cat("Movement interval observed origin/destination coordinates: NOT YET RESOLVED\n")
}

if(!is.null(chosen) && nrow(annual_spatial)){
  cat("All-badger annual observed sett coordinates: AVAILABLE\n")
  cat("Recommended first spatial-pressure model:\n")
  cat("  - pressure time = Q4 of movement-ending year t\n")
  cat("  - source infection states = other badgers' sampled I(Q4_t)\n")
  cat("  - source locations = exact observed sett coordinate in year t\n")
  cat("  - focal location = observed destination detector/sett coordinate in year t\n")
  cat("  - leave missing annual locations missing in PRIMARY analysis\n")
  cat("  - separately evaluate same-social-group pressure, which has higher coverage\n")
}else{
  cat("All-badger annual sett coordinates not sufficiently resolved yet.\n")
}

cat("\nIMPORTANT CAUSAL INTERPRETATION:\n")
cat("Origin infection pressure is a baseline/context covariate.\n")
cat("Destination infection pressure and change in pressure may lie on the pathway\n")
cat("from movement to infection. Adding them estimates a more direct movement\n")
cat("effect and should NOT replace the primary total-effect V7b-M model.\n")

# =============================================================================
# SAVE AUDIT
# =============================================================================

saveRDS(
  list(
    detectors=det,
    detector_fields=list(
      name=det_name,x=det_x,y=det_y,id=det_id
    ),
    row_index_mapping_plausible=row_index_plausible,
    movement_endpoint_map=endpoint_map,
    annual_spatial=annual_spatial,
    chosen_sett_lookup=chosen_name
  ),
  "results/spatial_pressure_coordinate_resolution_audit.rds"
)

cat("\nSaved: results/spatial_pressure_coordinate_resolution_audit.rds\n")
if(exists("annual_spatial") && nrow(annual_spatial)){
  cat("Saved: data/badger_annual_observed_spatial_locations.rds\n")
  cat("Saved: results/badger_annual_observed_spatial_locations.csv\n")
}
if(exists("endpoint_map") &&
   all(c("from_x","from_y","to_x","to_y")%in%names(endpoint_map))){
  cat("Saved: results/phase2_movement_observed_endpoint_coordinates.csv\n")
}

cat("\nAUDIT 2 COMPLETE\n")
