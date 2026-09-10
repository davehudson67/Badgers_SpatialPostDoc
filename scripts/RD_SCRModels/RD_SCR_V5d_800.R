# =============================================================================
# WOODCHESTER SPATIAL CMR V5c
# PREPARED-DATA VERSION
#
# ADULT-ENRICHED LATENT IMMIGRATION: MOVEMENT ONLY
#
# 50 m habitat state space
# + NON-CENTRED HEAVY-TAILED Student-t3 movement
# + NORMALIZED social-group and peripheral resistance
# + SEX affecting survival, baseline detection, detection scale and movement
# + LATENT IMMIGRANT STATUS for adult-entry badgers, inferred WITHOUT using sex
# + Immigrant effect on annual movement scale ONLY
#
# DATA WORKFLOW:
#
# PostgreSQL / Supabase
#        ↓
# scripts/DataPrep.R
#        ↓
# data/badger_encounters_useful.rds
# data/badger_individuals.rds
#        ↓
# THIS MODEL
#
# Spatial GIS inputs remain local:
#   data/WoodchesterSettLocations.csv
#   data/spatial/V3_spatial_inputs_50m_2km.rds
# =============================================================================

library(tidyverse)
library(lubridate)
library(nimble)
library(coda)
library(MCMCvis)
library(sf)

set.seed(123)

cat("\n============================================================\n")
cat("V5c ADULT-ENRICHED LATENT IMMIGRATION: MOVEMENT-ONLY MODEL\n")
cat("PREPARED-DATA VERSION\n")
cat("800 badgers | up to 400 adult-entry | Student-t3\n")
cat("============================================================\n\n")


# =============================================================================
# ---- options ----------------------------------------------------------------
# =============================================================================

SAMPLE_N <- 800L
MAX_ADULT_ENTRY <- 400L

NITER <- 5000
NBURN <- 1250
NCHAINS <- 2

MOVE_DF <- 3

if(MOVE_DF <= 2) stop("MOVE_DF must be > 2.")

T_SCALE_FACTOR <- sqrt((MOVE_DF - 2) / MOVE_DF)

MOVE_MEAN_FACTOR <-
  sqrt(MOVE_DF - 2) *
  sqrt(pi) / 2 *
  gamma((MOVE_DF - 1) / 2) /
  gamma(MOVE_DF / 2)

cat(
  "Movement kernel: bivariate Student-t, df =", MOVE_DF,
  "; standardized t scale =", round(T_SCALE_FACTOR, 4),
  "; mean radial factor =", round(MOVE_MEAN_FACTOR, 4), "\n"
)

SIGMA_MOVE_INIT <- 72
MOVE_PRIOR_LOGMEAN <- log(SIGMA_MOVE_INIT)

N_SIGMA_GRID <- 21L
LOG_SIGMA_MIN <- log(15)
LOG_SIGMA_MAX <- log(400)
LOG_SIGMA_STEP <- (LOG_SIGMA_MAX - LOG_SIGMA_MIN) / (N_SIGMA_GRID - 1)

SIGMA_GRID <- exp(
  seq(
    LOG_SIGMA_MIN,
    LOG_SIGMA_MAX,
    length.out = N_SIGMA_GRID
  )
)

SOCIAL_ZERO_CONST <- 50

cat(
  "Movement estimated; initialization:",
  round(SIGMA_MOVE_INIT, 3), "m\n"
)

cat(
  "Dynamic normalization grid:",
  round(min(SIGMA_GRID), 1), "to",
  round(max(SIGMA_GRID), 1),
  "m with", N_SIGMA_GRID, "log-spaced knots\n"
)


# =============================================================================
# ---- prepared biological data + spatial files -------------------------------
# =============================================================================
#
# DataPrep.R is run separately.
#
# For SCR we use encounters_useful rather than the one-row-per-quarter
# encounters_final_with_disease dataset because the SCR detector history needs
# access to the live biological encounters BEFORE quarterly collapse.
# =============================================================================

encounter_file <- "data/badger_encounters_useful.rds"
individual_file <- "data/badger_individuals.rds"

sett_file <- "data/WoodchesterSettLocations.csv"
spatial_file <- "data/spatial/V3_spatial_inputs_50m_2km.rds"

required_files <- c(
  encounter_file,
  individual_file,
  sett_file,
  spatial_file
)

missing_files <- required_files[!file.exists(required_files)]

if(length(missing_files)) {
  stop(
    "Required input file(s) missing:\n",
    paste(missing_files, collapse = "\n"),
    "\n\nRun scripts/DataPrep.R first to create the biological RDS snapshots."
  )
}

cmr_raw <- readRDS(encounter_file)
individuals <- readRDS(individual_file)

dir.create("results", showWarnings = FALSE)

cat("\n============================================================\n")
cat("MODEL INPUT SNAPSHOTS\n")
cat("============================================================\n")
cat("Encounter file:", encounter_file, "\n")
cat("Encounter rows:", nrow(cmr_raw), "\n")
cat("Encounter individuals:", n_distinct(cmr_raw$individual_id), "\n")
cat("Individual file:", individual_file, "\n")
cat("Individual rows:", nrow(individuals), "\n")


# =============================================================================
# ---- sett cleaning -----------------------------------------------------------
# =============================================================================
#
# Database preparation has already determined which capture locations are
# genuine setts.
#
# clean_sett() is retained ONLY to create a common key between those canonical
# database sett names and the historical local coordinate CSV.
# =============================================================================

sett_aliases <- c(
  "\\bCHESTNUT\\b" = "CHESNUT",
  "\\bJACKS\\b" = "JACKSMIREY",
  "\\bGRAVEL\\b" = "GRAVELPIT",
  "\\bBUCKHOLE\\b" = "BUCKHOLT",
  "\\bTOPSETT\\b" = "TOP",
  "\\bFOXCUB\\b" = "FOX",
  "\\bGULLEY\\b" = "GULLY",
  "\\bBLACKBERRY\\b" = "BRAMBLE",
  "\\bBOC\\b" = "BOG",
  "\\bCEDARBANK\\b" = "CEDAR",
  "\\bCLAYTRAP\\b" = "CLAY",
  "\\bCLIFF\\b" = "CLIFFFACE",
  "\\bDINGLEVALLEY\\b" = "DINGLE"
)

clean_sett <- function(x) {
  x %>%
    as.character() %>%
    toupper() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all(sett_aliases) %>%
    str_replace_all("\\s+", "")
}


# =============================================================================
# ---- V3 spatial inputs -------------------------------------------------------
# =============================================================================

sp <- readRDS(spatial_file)

SG_mat <- sp$SG_mat
habitat_mat <- sp$habitat_mat
zone_mat <- sp$zone_mat

grid_xmin <- sp$xmin
grid_xmax <- sp$xmax
grid_ymin <- sp$ymin
grid_ymax <- sp$ymax

cell_size <- sp$cell_size
n_rows <- sp$n_rows
n_cols <- sp$n_cols

stopifnot(
  !anyNA(SG_mat),
  !anyNA(habitat_mat),
  !anyNA(zone_mat)
)

cat(
  "\nV3 grid:",
  n_rows, "x", n_cols, "@", cell_size, "m =",
  n_rows * n_cols, "cells\n"
)


# =============================================================================
# ---- exact sett coordinates --------------------------------------------------
# =============================================================================

sett_raw <- read_csv(
  sett_file,
  show_col_types = FALSE
)

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

if(any(is.na(c(name_col, x_col, y_col))))
  stop("Could not identify sett name/X/Y columns.")

sett_xy <- sett_raw %>%
  transmute(
    Sett_Clean = clean_sett(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(
    !is.na(Sett_Clean),
    Sett_Clean != "",
    !is.na(x),
    !is.na(y)
  ) %>%
  distinct(Sett_Clean, .keep_all = TRUE)


# =============================================================================
# ---- prepared encounter data -------------------------------------------------
# =============================================================================

cmr <- cmr_raw %>%
  mutate(
    Sett_Clean = clean_sett(sett),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season)
  ) %>%
  left_join(
    sett_xy,
    by = "Sett_Clean"
  )

cat("\n============================================================\n")
cat("PREPARED DATA -> SCR INPUT AUDIT\n")
cat("============================================================\n")

cat("Biological encounters available:", nrow(cmr), "\n")
cat("Individuals available:", n_distinct(cmr$individual_id), "\n")
cat("Live encounters:", sum(cmr$has_live_capture, na.rm = TRUE), "\n")
cat("PM/death encounters:", sum(cmr$has_pm_record, na.rm = TRUE), "\n")

cat(
  "Live encounters with recognised sett + coordinates:",
  sum(
    cmr$has_live_capture &
      !is.na(cmr$x) &
      !is.na(cmr$y),
    na.rm = TRUE
  ),
  "\n"
)

cat(
  "Live encounters lacking usable sett coordinates:",
  sum(
    cmr$has_live_capture &
      (is.na(cmr$x) | is.na(cmr$y)),
    na.rm = TRUE
  ),
  "\n"
)


# =============================================================================
# ---- primary-year structure --------------------------------------------------
# =============================================================================

years <- min(cmr$primary_year, na.rm = TRUE):max(cmr$primary_year, na.rm = TRUE)

n_prim <- length(years)
n_sec <- 4L

cmr <- cmr %>%
  mutate(primary = match(primary_year, years))

period_vec <- as.integer(
  match(
    floor(years / 5) * 5,
    sort(unique(floor(years / 5) * 5))
  )
)

n_periods <- max(period_vec)

cat(
  "Primary years:",
  min(years), "-", max(years),
  "| n =", n_prim, "\n"
)


# =============================================================================
# ---- entry group & sex -------------------------------------------------------
# =============================================================================

demog <- individuals %>%
  transmute(
    individual_id,
    tattoo,
    age_fc = as.character(age_fc),
    entry_group = case_when(
      age_fc %in% c("Cub", "Yearling") ~ 1L,
      age_fc == "Adult" ~ 2L,
      TRUE ~ NA_integer_
    )
  )

sex_lookup <- individuals %>%
  transmute(
    individual_id,
    tattoo,
    sex_raw = as.character(sex),
    sex_clean = toupper(str_squish(sex_raw)),
    sex_code = case_when(
      sex_clean %in% c("F", "FEMALE") ~ 0L,
      sex_clean %in% c("M", "MALE") ~ 1L,
      TRUE ~ NA_integer_
    )
  )


# =============================================================================
# ---- LIVE SCR OBSERVATIONS ---------------------------------------------------
# =============================================================================
#
# Only true live encounters become detector observations.
#
# If >1 live capture occurs in the same quarter:
#   1. prefer an observation away from lifetime modal sett
#   2. otherwise retain latest live capture
# =============================================================================

live <- cmr %>%
  filter(
    has_live_capture,
    !is.na(primary),
    !is.na(trap_season),
    !is.na(x),
    !is.na(y)
  ) %>%
  arrange(
    individual_id,
    primary,
    trap_season,
    capture_date
  ) %>%
  group_by(
    individual_id,
    primary,
    trap_season
  ) %>%
  arrange(
    desc(differs_from_modal),
    desc(capture_date),
    .by_group = TRUE
  ) %>%
  slice(1) %>%
  ungroup()

cat(
  "Unique live individual-quarter detector observations:",
  nrow(live),
  "\n"
)

stopifnot(
  nrow(
    live %>%
      count(individual_id, primary, trap_season) %>%
      filter(n > 1)
  ) == 0
)


# =============================================================================
# ---- eligible individuals ---------------------------------------------------
# =============================================================================

eligible <- live %>%
  distinct(individual_id, tattoo) %>%
  inner_join(
    demog,
    by = c("individual_id", "tattoo")
  ) %>%
  left_join(
    sex_lookup %>%
      select(individual_id, tattoo, sex_code),
    by = c("individual_id", "tattoo")
  ) %>%
  filter(
    entry_group %in% 1:2,
    !tattoo %in% "007V"
  )


# =============================================================================
# ---- adult-enriched development sample ---------------------------------------
# =============================================================================

eligible_adult <- eligible %>%
  filter(entry_group == 2L)

eligible_young <- eligible %>%
  filter(entry_group == 1L)

n_adult_take <- min(MAX_ADULT_ENTRY, nrow(eligible_adult), SAMPLE_N)
n_young_take <- min(SAMPLE_N - n_adult_take, nrow(eligible_young))

adult_sample <- if(n_adult_take < nrow(eligible_adult)) {
  eligible_adult %>%
    slice_sample(n = n_adult_take)
} else {
  eligible_adult
}

young_sample <- if(n_young_take < nrow(eligible_young)) {
  eligible_young %>%
    slice_sample(n = n_young_take)
} else {
  eligible_young
}

eligible <- bind_rows(adult_sample, young_sample) %>%
  slice_sample(prop = 1)

cat("\nAdult-enriched sample:\n")
cat(
  "  eligible adult-entry:",
  nrow(eligible_adult),
  "| selected:",
  nrow(adult_sample), "\n"
)
cat(
  "  eligible young-entry:",
  nrow(eligible_young),
  "| selected:",
  nrow(young_sample), "\n"
)
cat(
  "  total selected:",
  nrow(eligible),
  "of target",
  SAMPLE_N, "\n"
)

if(nrow(eligible) < SAMPLE_N)
  warning("Fewer eligible badgers than SAMPLE_N after stratified selection.")

ids <- eligible$tattoo
nind <- length(ids)

live <- live %>%
  filter(tattoo %in% ids)

cmr <- cmr %>%
  filter(tattoo %in% ids)


# =============================================================================
# ---- exact-sett detectors ----------------------------------------------------
# =============================================================================

detectors <- live %>%
  distinct(Sett_Clean, x, y) %>%
  arrange(Sett_Clean) %>%
  mutate(detector = row_number())

X <- as.matrix(
  detectors %>%
    select(x, y)
)

R <- nrow(X)

live <- live %>%
  left_join(
    detectors %>%
      select(Sett_Clean, detector),
    by = "Sett_Clean"
  )

det_audit <- detectors %>%
  mutate(
    col_R = floor((x - grid_xmin) / cell_size) + 1L,
    row_R = floor((grid_ymax - y) / cell_size) + 1L,
    in_bounds =
      col_R >= 1 &
      col_R <= n_cols &
      row_R >= 1 &
      row_R <= n_rows
  )

if(any(!det_audit$in_bounds))
  stop("Used detector outside V3 grid.")

cat("\nSpatial detectors used:", R, "\n")


# =============================================================================
# ---- individual metadata ----------------------------------------------------
# =============================================================================

meta <- live %>%
  arrange(tattoo, primary, trap_season, capture_date) %>%
  group_by(tattoo) %>%
  summarise(
    first = first(primary),
    first_detector = first(detector),
    .groups = "drop"
  ) %>%
  right_join(
    tibble(tattoo = ids),
    by = "tattoo"
  ) %>%
  left_join(
    eligible %>%
      select(tattoo, entry_group, sex_code),
    by = "tattoo"
  ) %>%
  arrange(match(tattoo, ids))

first <- as.integer(meta$first)
first_detector <- as.integer(meta$first_detector)
entry_group <- as.integer(meta$entry_group)
sex_data <- as.integer(meta$sex_code)

stopifnot(
  !anyNA(first),
  !anyNA(first_detector),
  !anyNA(entry_group)
)

if(any(!is.na(sex_data) & !sex_data %in% 0:1))
  stop("Known sex values must be 0=female or 1=male.")


# =============================================================================
# ---- latent immigrant setup --------------------------------------------------
# =============================================================================

adult_entry <- as.integer(entry_group == 2L)


# =============================================================================
# ---- first-capture edge metric -----------------------------------------------
# =============================================================================

grid_df_edge <- sf::st_drop_geometry(sp$grid)
grid_xy_edge <- sf::st_coordinates(sp$grid)

periph_xy_edge <- grid_xy_edge[
  grid_df_edge$habitat == 1L &
    grid_df_edge$zone == 2L,
  ,
  drop = FALSE
]

if(!nrow(periph_xy_edge))
  stop("No peripheral land cells found for immigrant edge metric.")

det_edge_dist <- vapply(
  seq_len(nrow(detectors)),
  function(r) {
    sqrt(
      min(
        (periph_xy_edge[, 1] - detectors$x[r])^2 +
          (periph_xy_edge[, 2] - detectors$y[r])^2
      )
    )
  },
  numeric(1)
)

det_audit$edge_dist_m <- det_edge_dist

first_edge_dist_m <- det_edge_dist[first_detector]

edge_proximity <- as.numeric(
  scale(-first_edge_dist_m)
)

if(anyNA(edge_proximity) || !all(is.finite(edge_proximity)))
  stop("Invalid first-capture edge-proximity metric.")

immigrant_data <- ifelse(
  adult_entry == 0L,
  0L,
  NA_integer_
)

cat("\nEntry/origin setup:\n")
cat("  young-entry known local:", sum(adult_entry == 0L), "\n")
cat("  adult-entry latent origin:", sum(adult_entry == 1L), "\n")
cat(
  "  first-edge distance (m): median",
  round(median(first_edge_dist_m), 1),
  "| range",
  round(min(first_edge_dist_m), 1),
  "-",
  round(max(first_edge_dist_m), 1),
  "\n"
)


# =============================================================================
# ---- death info --------------------------------------------------------------
# =============================================================================

death <- cmr %>%
  filter(
    has_pm_record,
    !is.na(primary)
  ) %>%
  group_by(tattoo) %>%
  summarise(
    death_primary = min(primary),
    death_season = {
      q <- trap_season[primary == min(primary)]
      q <- q[!is.na(q)]
      if(length(q)) min(q) else NA_integer_
    },
    .groups = "drop"
  )

death_primary <- rep(n_prim + 1L, nind)
death_season <- rep(NA_integer_, nind)

m <- match(ids, death$tattoo)
has_death <- !is.na(m)

death_primary[has_death] <- death$death_primary[m[has_death]]
death_season[has_death] <- death$death_season[m[has_death]]

known_death <- death_primary <= n_prim

K <- rep(n_prim, nind)

K[known_death] <- pmin(
  n_prim,
  death_primary[known_death] + 1L
)


# =============================================================================
# ---- encounters --------------------------------------------------------------
# =============================================================================

H <- array(
  1L,
  c(nind, n_sec, n_prim)
)

for(r in seq_len(nrow(live))) {
  H[
    match(live$tattoo[r], ids),
    live$trap_season[r],
    live$primary[r]
  ] <- live$detector[r] + 1L
}

J <- matrix(
  n_sec,
  nind,
  n_prim
)

for(i in seq_len(nind)) {
  if(
    known_death[i] &&
    !is.na(death_season[i]) &&
    death_primary[i] <= n_prim
  ) {
    J[i, death_primary[i]] <- max(
      1L,
      death_season[i]
    )
  }
}

z_data <- matrix(
  NA_integer_,
  nind,
  n_prim
)

for(i in seq_len(nind)) {
  
  z_data[
    i,
    unique(live$primary[live$tattoo == ids[i]])
  ] <- 1L
  
  if(known_death[i]) {
    
    z_data[i, death_primary[i]] <- 1L
    
    if(death_primary[i] < n_prim) {
      z_data[
        i,
        (death_primary[i] + 1L):n_prim
      ] <- 0L
    }
  }
}


# =============================================================================
# ---- reorder histories -------------------------------------------------------
# =============================================================================

ord <- order(K - first)

ids <- ids[ord]

H <- H[ord, , , drop = FALSE]
J <- J[ord, , drop = FALSE]
z_data <- z_data[ord, , drop = FALSE]

first <- first[ord]
K <- K[ord]

first_detector <- first_detector[ord]
entry_group <- entry_group[ord]
adult_entry <- adult_entry[ord]
first_edge_dist_m <- first_edge_dist_m[ord]
edge_proximity <- edge_proximity[ord]
immigrant_data <- immigrant_data[ord]
sex_data <- sex_data[ord]
death_primary <- death_primary[ord]

# Recreate after ordering so all vectors use the same individual order.
known_death <- death_primary <= n_prim

unknown_sex_idx <- which(is.na(sex_data))
adult_entry_idx <- which(adult_entry == 1L)
young_entry_idx <- which(adult_entry == 0L)

N <- c(
  sum(K == first),
  nind
)

if(any(K < first))
  stop("ERROR: K < first.")

if(any(death_primary < first & death_primary <= n_prim))
  stop("ERROR: known death before first spatial capture.")

if(N[1] == 0L || N[1] == N[2])
  stop("Current compact loops require both single- and multi-primary histories.")

cat("\n============================================================\n")
cat("FINAL MODEL SAMPLE\n")
cat("============================================================\n")
cat("nind:", nind, "\n")
cat("single-primary histories:", N[1], "\n")
cat("multi-primary histories:", N[2] - N[1], "\n")
cat("known deaths:", sum(known_death), "\n")
cat("known sex:", sum(!is.na(sex_data)), "\n")
cat("unknown sex:", length(unknown_sex_idx), "\n")
cat("adult-entry:", length(adult_entry_idx), "\n")
cat("young-entry:", length(young_entry_idx), "\n")


# =============================================================================
# ---- initial values ----------------------------------------------------------
# =============================================================================

make_inits <- function(chain = 1L) {
  
  z_init <- matrix(0L, nind, n_prim)
  S_init <- array(NA_real_, c(nind, 2, n_prim))
  eps_init <- array(NA_real_, c(nind, 2, n_prim))
  
  sex_init <- sex_data
  
  if(length(unknown_sex_idx)) {
    sex_init[unknown_sex_idx] <- rbinom(
      length(unknown_sex_idx),
      1,
      .47
    )
  }
  
  immigrant_init <- rep(
    NA_integer_,
    nind
  )
  
  if(length(adult_entry_idx)) {
    
    p0_imm_init <- plogis(
      qlogis(.30) +
        0.30 * edge_proximity[adult_entry_idx]
    )
    
    immigrant_init[adult_entry_idx] <- rbinom(
      length(adult_entry_idx),
      1,
      p0_imm_init
    )
  }
  
  beta_move_sex_init <- log(1.70)
  
  sigma_move_init_i <-
    SIGMA_MOVE_INIT *
    exp(beta_move_sex_init * sex_init)
  
  for(i in seq_len(nind)) {
    
    d <- live %>%
      filter(tattoo == ids[i]) %>%
      arrange(primary, trap_season, capture_date) %>%
      group_by(primary) %>%
      slice(1) %>%
      ungroup() %>%
      select(primary, x, y)
    
    xy <- matrix(
      NA_real_,
      n_prim,
      2
    )
    
    for(k in first[i]:K[i]) {
      
      dk <- d %>%
        filter(primary == k)
      
      if(nrow(dk)) {
        xy[k, ] <- c(
          dk$x[1],
          dk$y[1]
        )
      } else if(k > first[i]) {
        xy[k, ] <- xy[k - 1, ]
      }
    }
    
    S_init[i, , first[i]] <- xy[first[i], ]
    
    z_init[
      i,
      first[i]:K[i]
    ] <- 1L
    
    if(K[i] > first[i]) {
      
      for(k in (first[i] + 1L):K[i]) {
        
        eps_init[i, 1, k] <-
          (xy[k, 1] - xy[k - 1, 1]) /
          sigma_move_init_i[i]
        
        eps_init[i, 2, k] <-
          (xy[k, 2] - xy[k - 1, 2]) /
          sigma_move_init_i[i]
      }
    }
  }
  
  z_init[!is.na(z_data)] <- NA
  
  list(
    alpha_phi = qlogis(.81) + rnorm(1, 0, .03),
    alpha_p = qlogis(.17) + rnorm(1, 0, .03),
    alpha_logsigma = log(132) + rnorm(1, 0, .03),
    alpha_logmove = log(SIGMA_MOVE_INIT) + rnorm(1, 0, .03),
    
    beta_phi_sex = -.50 + rnorm(1, 0, .03),
    beta_p_sex = .35 + rnorm(1, 0, .03),
    beta_sigma_sex = -.06 + rnorm(1, 0, .02),
    beta_move_sex = beta_move_sex_init + rnorm(1, 0, .03),
    
    beta_move_imm = rnorm(1, 0, .08),
    
    psi_sex = runif(1, .43, .50),
    
    sex = {
      s <- rep(NA_integer_, nind)
      if(length(unknown_sex_idx))
        s[unknown_sex_idx] <- sex_init[unknown_sex_idx]
      s
    },
    
    alpha_imm = qlogis(.30) + rnorm(1, 0, .10),
    beta_imm_edge = rnorm(1, .30, .10),
    immigrant = immigrant_init,
    
    beta_season_raw = rnorm(3, 0, .03),
    beta_period_raw = rnorm(n_periods - 1L, 0, .03),
    
    beta_sg = runif(1, .02, .15),
    beta_peripheral = runif(1, .10, .40),
    
    S = S_init,
    eps = eps_init,
    z = z_init
  )
}

inits <- lapply(
  seq_len(NCHAINS),
  make_inits
)


# =============================================================================
# ---- precompute DYNAMIC normalized landscape opportunity ---------------------
# =============================================================================

cat("\nPreparing dynamic t3 landscape-normalization arrays...\n")

grid_df <- sp$grid %>%
  sf::st_drop_geometry()

if(
  !all(
    c(
      "row_R",
      "col_R",
      "SG_id",
      "habitat",
      "zone"
    ) %in% names(grid_df)
  )
) {
  stop(
    "sp$grid must contain row_R, col_R, SG_id, habitat and zone."
  )
}

grid_xy <- sf::st_coordinates(sp$grid)

land_idx <- which(
  grid_df$habitat == 1L
)

core_idx <- which(
  grid_df$habitat == 1L &
    grid_df$zone == 1L
)

q_cache_file <- file.path(
  "data",
  "spatial",
  paste0(
    "V4c_qgrid_t",
    MOVE_DF,
    "_",
    N_SIGMA_GRID,
    "knots_",
    round(min(SIGMA_GRID)),
    "to",
    round(max(SIGMA_GRID)),
    "m.rds"
  )
)

cache_ok <- FALSE

if(file.exists(q_cache_file)) {
  
  qcache <- readRDS(q_cache_file)
  
  cache_ok <-
    identical(qcache$n_rows, n_rows) &&
    identical(qcache$n_cols, n_cols) &&
    identical(qcache$move_df, MOVE_DF) &&
    isTRUE(
      all.equal(
        qcache$sigma_grid,
        SIGMA_GRID,
        tolerance = 1e-12
      )
    )
}

if(cache_ok) {
  
  cat(
    "Loading cached normalization grid:",
    q_cache_file,
    "\n"
  )
  
  q_same_grid <- qcache$q_same
  q_other_grid <- qcache$q_other
  q_peripheral_grid <- qcache$q_peripheral
  
} else {
  
  cat(
    "No matching cache found; computing normalization grid once...\n"
  )
  
  q_same_grid <- array(
    1,
    c(
      N_SIGMA_GRID,
      n_rows,
      n_cols
    )
  )
  
  q_other_grid <- array(
    0,
    c(
      N_SIGMA_GRID,
      n_rows,
      n_cols
    )
  )
  
  q_peripheral_grid <- array(
    0,
    c(
      N_SIGMA_GRID,
      n_rows,
      n_cols
    )
  )
  
  calc_q_chunk <- function(origin_idx) {
    
    ns <- length(SIGMA_GRID)
    
    out_same <- matrix(
      0,
      length(origin_idx),
      ns
    )
    
    out_other <- matrix(
      0,
      length(origin_idx),
      ns
    )
    
    out_per <- matrix(
      0,
      length(origin_idx),
      ns
    )
    
    for(a in seq_along(origin_idx)) {
      
      oi <- origin_idx[a]
      
      dx <-
        grid_xy[land_idx, 1] -
        grid_xy[oi, 1]
      
      dy <-
        grid_xy[land_idx, 2] -
        grid_xy[oi, 2]
      
      d2 <- dx^2 + dy^2
      
      same <-
        grid_df$zone[land_idx] == 1L &
        grid_df$SG_id[land_idx] ==
        grid_df$SG_id[oi]
      
      other <-
        grid_df$zone[land_idx] == 1L &
        grid_df$SG_id[land_idx] !=
        grid_df$SG_id[oi]
      
      per <-
        grid_df$zone[land_idx] == 2L
      
      for(ss in seq_len(ns)) {
        
        sig <- SIGMA_GRID[ss]
        
        w <- (
          1 +
            d2 /
            (
              sig^2 *
                (MOVE_DF - 2)
            )
        )^(
          -(MOVE_DF + 2) / 2
        )
        
        den <- sum(w)
        
        out_same[a, ss] <-
          sum(w[same]) / den
        
        out_other[a, ss] <-
          sum(w[other]) / den
        
        out_per[a, ss] <-
          sum(w[per]) / den
      }
    }
    
    list(
      origin_idx = origin_idx,
      same = out_same,
      other = out_other,
      per = out_per
    )
  }
  
  nc_detected <- parallel::detectCores()
  
  if(is.na(nc_detected))
    nc_detected <- 1L
  
  ncores <- max(
    1L,
    min(
      8L,
      nc_detected - 1L
    )
  )
  
  nchunks <- min(
    ncores,
    length(core_idx)
  )
  
  if(nchunks == 1L) {
    chunks <- list(core_idx)
  } else {
    chunks <- split(
      core_idx,
      cut(
        seq_along(core_idx),
        breaks = nchunks,
        labels = FALSE
      )
    )
  }
  
  cat(
    "Computing",
    length(core_idx),
    "core origins x",
    N_SIGMA_GRID,
    "sigma knots using",
    ncores,
    "core(s)...\n"
  )
  
  q_time <- system.time({
    
    if(
      .Platform$OS.type != "windows" &&
      ncores > 1L
    ) {
      
      q_parts <- parallel::mclapply(
        chunks,
        calc_q_chunk,
        mc.cores = ncores
      )
      
    } else {
      
      q_parts <- lapply(
        chunks,
        calc_q_chunk
      )
    }
  })
  
  cat(
    "Normalization-grid calculation time:\n"
  )
  
  print(q_time)
  
  for(part in q_parts) {
    
    for(a in seq_along(part$origin_idx)) {
      
      oi <- part$origin_idx[a]
      rr <- grid_df$row_R[oi]
      cc <- grid_df$col_R[oi]
      
      q_same_grid[, rr, cc] <-
        part$same[a, ]
      
      q_other_grid[, rr, cc] <-
        part$other[a, ]
      
      q_peripheral_grid[, rr, cc] <-
        part$per[a, ]
    }
  }
  
  saveRDS(
    list(
      q_same = q_same_grid,
      q_other = q_other_grid,
      q_peripheral = q_peripheral_grid,
      sigma_grid = SIGMA_GRID,
      n_rows = n_rows,
      n_cols = n_cols,
      move_df = MOVE_DF
    ),
    q_cache_file
  )
  
  cat(
    "Saved normalization cache:",
    q_cache_file,
    "\n"
  )
}

stopifnot(
  all(is.finite(q_same_grid)),
  all(is.finite(q_other_grid)),
  all(is.finite(q_peripheral_grid))
)

core_rc <- cbind(
  grid_df$row_R[core_idx],
  grid_df$col_R[core_idx]
)

max_q_error <- 0
min_q_same <- Inf

for(ss in seq_len(N_SIGMA_GRID)) {
  
  qsum_ss <-
    q_same_grid[ss, , ] +
    q_other_grid[ss, , ] +
    q_peripheral_grid[ss, , ]
  
  max_q_error <- max(
    max_q_error,
    max(
      abs(
        qsum_ss[core_rc] - 1
      )
    )
  )
  
  min_q_same <- min(
    min_q_same,
    min(
      q_same_grid[
        ss,
        ,
      ][core_rc]
    )
  )
}

cat(
  "Normalization check, max |sum(q)-1|:",
  max_q_error,
  "\n"
)

cat(
  "Minimum same-SG mass across grid:",
  min_q_same,
  "; max same-SG log correction:",
  -log(min_q_same),
  "\n"
)

if(
  SOCIAL_ZERO_CONST <=
  -log(min_q_same) + 5
) {
  stop(
    "SOCIAL_ZERO_CONST is too small for the normalized likelihood correction."
  )
}


# =============================================================================
# ---- CUSTOM COMPILED DETECTION LIKELIHOOD -----------------------------------
# =============================================================================

calc_capture_prob <- nimbleFunction(
  
  run = function(
    Sx = double(0),
    Sy = double(0),
    X = double(2),
    sigma = double(0),
    lambda0_vec = double(1),
    H_vec = double(1),
    z = double(0)
  ) {
    
    returnType(
      double(1)
    )
    
    R <- dim(X)[1]
    J <- length(H_vec)
    
    G_sum <- 0.0
    
    g_vec <- numeric(
      R + 1,
      init = FALSE
    )
    
    g_vec[1] <- 0.0
    
    for(r in 1:R) {
      
      d2 <-
        (Sx - X[r, 1])^2 +
        (Sy - X[r, 2])^2
      
      g_val <- exp(
        -d2 /
          (
            2.0 *
              sigma^2
          )
      )
      
      g_vec[r + 1] <- g_val
      
      G_sum <- G_sum + g_val
    }
    
    captureProb <- numeric(
      J,
      init = FALSE
    )
    
    for(j in 1:J) {
      
      P_alive <-
        (
          1.0 -
            exp(
              -lambda0_vec[j] *
                G_sum
            )
        ) *
        z
      
      H_j <- as.integer(
        H_vec[j]
      )
      
      if(H_j >= 2) {
        
        captureProb[j] <-
          (
            g_vec[H_j] /
              (G_sum + 1e-10)
          ) *
          P_alive
        
      } else {
        
        captureProb[j] <-
          1.0 -
          P_alive
      }
    }
    
    return(
      captureProb
    )
  }
)


# =============================================================================
# ---- V5c MODEL ---------------------------------------------------------------
# =============================================================================

code_V3 <- nimbleCode({
  
  alpha_phi ~ dnorm(qlogis(.80), sd = 1.5)
  alpha_p ~ dnorm(qlogis(.17), sd = 1.5)
  alpha_logsigma ~ dnorm(log(150), sd = 1)
  alpha_logmove ~ dnorm(MOVE_PRIOR_LOGMEAN, sd = .60)
  
  beta_phi_sex ~ dnorm(0, sd = 1)
  beta_p_sex ~ dnorm(0, sd = 1)
  beta_sigma_sex ~ dnorm(0, sd = .75)
  beta_move_sex ~ dnorm(0, sd = .50)
  
  beta_move_imm ~ dnorm(0, sd = .50)
  
  psi_sex ~ dbeta(1, 1)
  
  alpha_imm ~ dnorm(0, sd = 1.5)
  beta_imm_edge ~ dnorm(0, sd = 1)
  
  for(i in 1:N[2]) {
    
    sex[i] ~ dbern(psi_sex)
    
    logit_p_imm[i] <-
      alpha_imm +
      beta_imm_edge *
      edge_proximity[i]
    
    p_imm_adult[i] <-
      ilogit(
        logit_p_imm[i]
      )
    
    p_imm[i] <-
      adult_entry[i] *
      p_imm_adult[i]
    
    immigrant[i] ~ dbern(
      p_imm[i]
    )
    
    phi_i[i] <-
      ilogit(
        alpha_phi +
          beta_phi_sex *
          sex[i]
      )
    
    sigma_i[i] <-
      exp(
        alpha_logsigma +
          beta_sigma_sex *
          sex[i]
      )
    
    log_sigma_move_i[i] <-
      alpha_logmove +
      beta_move_sex *
      sex[i] +
      beta_move_imm *
      immigrant[i]
    
    sigma_move_i[i] <-
      exp(
        log_sigma_move_i[i]
      )
    
    sigma_grid_pos[i] <-
      (
        log_sigma_move_i[i] -
          LOG_SIGMA_MIN
      ) /
      LOG_SIGMA_STEP +
      1
    
    sigma_grid_lo_raw[i] <-
      trunc(
        sigma_grid_pos[i]
      )
    
    sigma_grid_lo[i] <-
      max(
        1,
        min(
          N_SIGMA_GRID - 1,
          sigma_grid_lo_raw[i]
        )
      )
    
    sigma_grid_frac[i] <-
      max(
        0,
        min(
          1,
          sigma_grid_pos[i] -
            sigma_grid_lo[i]
        )
      )
  }
  
  phi_female_local <- ilogit(alpha_phi)
  phi_male_local <- ilogit(alpha_phi + beta_phi_sex)
  
  phi_female <- ilogit(alpha_phi)
  phi_male <- ilogit(alpha_phi + beta_phi_sex)
  
  p0_female <- ilogit(alpha_p)
  p0_male <- ilogit(alpha_p + beta_p_sex)
  
  sigma_female <- exp(alpha_logsigma)
  sigma_male <- exp(alpha_logsigma + beta_sigma_sex)
  
  sigma_move_female_local <- exp(alpha_logmove)
  sigma_move_male_local <- exp(alpha_logmove + beta_move_sex)
  sigma_move_female_imm <- exp(alpha_logmove + beta_move_imm)
  sigma_move_male_imm <- exp(alpha_logmove + beta_move_sex + beta_move_imm)
  
  mean_move_female_local <- sigma_move_female_local * MOVE_MEAN_FACTOR
  mean_move_male_local <- sigma_move_male_local * MOVE_MEAN_FACTOR
  mean_move_female_imm <- sigma_move_female_imm * MOVE_MEAN_FACTOR
  mean_move_male_imm <- sigma_move_male_imm * MOVE_MEAN_FACTOR
  
  move_support[1] <-
    step(alpha_logmove - LOG_SIGMA_MIN) *
    step(LOG_SIGMA_MAX - alpha_logmove)
  
  move_support[2] <-
    step(alpha_logmove + beta_move_sex - LOG_SIGMA_MIN) *
    step(LOG_SIGMA_MAX - alpha_logmove - beta_move_sex)
  
  move_support[3] <-
    step(alpha_logmove + beta_move_imm - LOG_SIGMA_MIN) *
    step(LOG_SIGMA_MAX - alpha_logmove - beta_move_imm)
  
  move_support[4] <-
    step(alpha_logmove + beta_move_sex + beta_move_imm - LOG_SIGMA_MIN) *
    step(LOG_SIGMA_MAX - alpha_logmove - beta_move_sex - beta_move_imm)
  
  for(mm in 1:4) {
    move_support_ok[mm] ~ dbern(move_support[mm])
  }
  
  p_imm_edge_minus1 <- ilogit(alpha_imm - beta_imm_edge)
  p_imm_edge_mean <- ilogit(alpha_imm)
  p_imm_edge_plus1 <- ilogit(alpha_imm + beta_imm_edge)
  
  beta_sg ~ dexp(1)
  beta_peripheral ~ dexp(1)
  
  sg_multiplier <- exp(-beta_sg)
  peripheral_multiplier <- exp(-beta_peripheral)
  
  for(s in 1:3) {
    beta_season_raw[s] ~ dnorm(0, sd = 1)
    beta_season[s] <- beta_season_raw[s]
  }
  
  beta_season[4] <- -sum(beta_season_raw[1:3])
  
  for(p in 1:(n_periods - 1)) {
    beta_period_raw[p] ~ dnorm(0, sd = 1)
    beta_period[p] <- beta_period_raw[p]
  }
  
  beta_period[n_periods] <-
    -sum(
      beta_period_raw[
        1:(n_periods - 1)
      ]
    )
  
  
  # ===========================================================================
  # Single-primary histories
  # ===========================================================================
  
  for(i in 1:N[1]) {
    
    z[i, first[i]] ~ dbern(1)
    
    S[i, 1, first[i]] ~ dunif(grid_xmin, grid_xmax)
    S[i, 2, first[i]] ~ dunif(grid_ymin, grid_ymax)
    
    col_raw[i, first[i]] <-
      trunc(
        (
          S[i, 1, first[i]] -
            grid_xmin
        ) /
          cell_size
      ) +
      1
    
    row_raw[i, first[i]] <-
      trunc(
        (
          grid_ymax -
            S[i, 2, first[i]]
        ) /
          cell_size
      ) +
      1
    
    col_S[i, first[i]] <-
      max(
        1,
        min(
          n_cols,
          col_raw[i, first[i]]
        )
      )
    
    row_S[i, first[i]] <-
      max(
        1,
        min(
          n_rows,
          row_raw[i, first[i]]
        )
      )
    
    in_bounds[i, first[i]] <-
      step(
        S[i, 1, first[i]] -
          grid_xmin
      ) *
      step(
        grid_xmax -
          S[i, 1, first[i]]
      ) *
      step(
        S[i, 2, first[i]] -
          grid_ymin
      ) *
      step(
        grid_ymax -
          S[i, 2, first[i]]
      )
    
    habitat_here[i, first[i]] <-
      habitat_mat[
        row_S[i, first[i]],
        col_S[i, first[i]]
      ]
    
    SG_here[i, first[i]] <-
      SG_mat[
        row_S[i, first[i]],
        col_S[i, first[i]]
      ]
    
    zone_here[i, first[i]] <-
      zone_mat[
        row_S[i, first[i]],
        col_S[i, first[i]]
      ]
    
    state_ok[i, first[i]] ~ dbern(
      in_bounds[i, first[i]] *
        habitat_here[i, first[i]]
    )
    
    for(j in 1:J[i, first[i]]) {
      
      lp0[i, j, first[i]] <-
        alpha_p +
        beta_p_sex *
        sex[i] +
        beta_season[j] +
        beta_period[
          period_vec[first[i]]
        ]
      
      lambda0[i, j, first[i]] <-
        -log(
          1 -
            ilogit(
              lp0[i, j, first[i]]
            )
        )
    }
    
    captureProb[
      i,
      1:J[i, first[i]],
      first[i]
    ] <- calc_capture_prob(
      S[i, 1, first[i]],
      S[i, 2, first[i]],
      X[1:R, 1:2],
      sigma_i[i],
      lambda0[
        i,
        1:J[i, first[i]],
        first[i]
      ],
      H[
        i,
        1:J[i, first[i]],
        first[i]
      ],
      z[i, first[i]]
    )
    
    for(j in 1:J[i, first[i]]) {
      Ones[
        i,
        j,
        first[i]
      ] ~ dbern(
        captureProb[
          i,
          j,
          first[i]
        ]
      )
    }
  }
  
  
  # ===========================================================================
  # Multi-primary histories
  # ===========================================================================
  
  for(i in (N[1] + 1):N[2]) {
    
    z[i, first[i]] ~ dbern(1)
    
    S[i, 1, first[i]] ~ dunif(grid_xmin, grid_xmax)
    S[i, 2, first[i]] ~ dunif(grid_ymin, grid_ymax)
    
    col_raw[i, first[i]] <-
      trunc(
        (
          S[i, 1, first[i]] -
            grid_xmin
        ) /
          cell_size
      ) +
      1
    
    row_raw[i, first[i]] <-
      trunc(
        (
          grid_ymax -
            S[i, 2, first[i]]
        ) /
          cell_size
      ) +
      1
    
    col_S[i, first[i]] <-
      max(
        1,
        min(
          n_cols,
          col_raw[i, first[i]]
        )
      )
    
    row_S[i, first[i]] <-
      max(
        1,
        min(
          n_rows,
          row_raw[i, first[i]]
        )
      )
    
    in_bounds[i, first[i]] <-
      step(
        S[i, 1, first[i]] -
          grid_xmin
      ) *
      step(
        grid_xmax -
          S[i, 1, first[i]]
      ) *
      step(
        S[i, 2, first[i]] -
          grid_ymin
      ) *
      step(
        grid_ymax -
          S[i, 2, first[i]]
      )
    
    habitat_here[i, first[i]] <-
      habitat_mat[
        row_S[i, first[i]],
        col_S[i, first[i]]
      ]
    
    SG_here[i, first[i]] <-
      SG_mat[
        row_S[i, first[i]],
        col_S[i, first[i]]
      ]
    
    zone_here[i, first[i]] <-
      zone_mat[
        row_S[i, first[i]],
        col_S[i, first[i]]
      ]
    
    state_ok[i, first[i]] ~ dbern(
      in_bounds[i, first[i]] *
        habitat_here[i, first[i]]
    )
    
    for(j in 1:J[i, first[i]]) {
      
      lp0[i, j, first[i]] <-
        alpha_p +
        beta_p_sex *
        sex[i] +
        beta_season[j] +
        beta_period[
          period_vec[first[i]]
        ]
      
      lambda0[i, j, first[i]] <-
        -log(
          1 -
            ilogit(
              lp0[i, j, first[i]]
            )
        )
    }
    
    captureProb[
      i,
      1:J[i, first[i]],
      first[i]
    ] <- calc_capture_prob(
      S[i, 1, first[i]],
      S[i, 2, first[i]],
      X[1:R, 1:2],
      sigma_i[i],
      lambda0[
        i,
        1:J[i, first[i]],
        first[i]
      ],
      H[
        i,
        1:J[i, first[i]],
        first[i]
      ],
      z[i, first[i]]
    )
    
    for(j in 1:J[i, first[i]]) {
      Ones[
        i,
        j,
        first[i]
      ] ~ dbern(
        captureProb[
          i,
          j,
          first[i]
        ]
      )
    }
    
    for(k in (first[i] + 1):K[i]) {
      
      Palive[i, k - 1] <-
        z[i, k - 1] *
        phi_i[i]
      
      z[i, k] ~ dbern(
        Palive[i, k - 1] *
          step(
            death_primary[i] -
              k
          )
      )
      
      eps[
        i,
        1:2,
        k
      ] ~ dmvt(
        mu = eps_zero[1:2],
        scale = eps_scale[1:2, 1:2],
        df = MOVE_DF
      )
      
      S[i, 1, k] <-
        S[i, 1, k - 1] +
        sigma_move_i[i] *
        eps[i, 1, k]
      
      S[i, 2, k] <-
        S[i, 2, k - 1] +
        sigma_move_i[i] *
        eps[i, 2, k]
      
      moveDist[i, k - 1] <-
        sigma_move_i[i] *
        sqrt(
          pow(
            eps[i, 1, k],
            2
          ) +
            pow(
              eps[i, 2, k],
              2
            )
        )
      
      col_raw[i, k] <-
        trunc(
          (
            S[i, 1, k] -
              grid_xmin
          ) /
            cell_size
        ) +
        1
      
      row_raw[i, k] <-
        trunc(
          (
            grid_ymax -
              S[i, 2, k]
          ) /
            cell_size
        ) +
        1
      
      col_S[i, k] <-
        max(
          1,
          min(
            n_cols,
            col_raw[i, k]
          )
        )
      
      row_S[i, k] <-
        max(
          1,
          min(
            n_rows,
            row_raw[i, k]
          )
        )
      
      in_bounds[i, k] <-
        step(
          S[i, 1, k] -
            grid_xmin
        ) *
        step(
          grid_xmax -
            S[i, 1, k]
        ) *
        step(
          S[i, 2, k] -
            grid_ymin
        ) *
        step(
          grid_ymax -
            S[i, 2, k]
        )
      
      habitat_here[i, k] <-
        habitat_mat[
          row_S[i, k],
          col_S[i, k]
        ]
      
      SG_here[i, k] <-
        SG_mat[
          row_S[i, k],
          col_S[i, k]
        ]
      
      zone_here[i, k] <-
        zone_mat[
          row_S[i, k],
          col_S[i, k]
        ]
      
      valid_state[i, k] <-
        in_bounds[i, k] *
        habitat_here[i, k]
      
      state_prob[i, k] <-
        (
          1 -
            z[i, k]
        ) +
        z[i, k] *
        valid_state[i, k]
      
      state_ok[i, k] ~ dbern(
        state_prob[i, k]
      )
      
      apply_social[i, k] <-
        z[i, k] *
        equals(
          zone_here[i, k - 1],
          1
        )
      
      q_same_lo[i, k] <-
        q_same_grid[
          sigma_grid_lo[i],
          row_S[i, k - 1],
          col_S[i, k - 1]
        ]
      
      q_same_hi[i, k] <-
        q_same_grid[
          sigma_grid_lo[i] + 1,
          row_S[i, k - 1],
          col_S[i, k - 1]
        ]
      
      q_other_lo[i, k] <-
        q_other_grid[
          sigma_grid_lo[i],
          row_S[i, k - 1],
          col_S[i, k - 1]
        ]
      
      q_other_hi[i, k] <-
        q_other_grid[
          sigma_grid_lo[i] + 1,
          row_S[i, k - 1],
          col_S[i, k - 1]
        ]
      
      q_per_lo[i, k] <-
        q_peripheral_grid[
          sigma_grid_lo[i],
          row_S[i, k - 1],
          col_S[i, k - 1]
        ]
      
      q_per_hi[i, k] <-
        q_peripheral_grid[
          sigma_grid_lo[i] + 1,
          row_S[i, k - 1],
          col_S[i, k - 1]
        ]
      
      q_same_here[i, k] <-
        q_same_lo[i, k] +
        sigma_grid_frac[i] *
        (
          q_same_hi[i, k] -
            q_same_lo[i, k]
        )
      
      q_other_here[i, k] <-
        q_other_lo[i, k] +
        sigma_grid_frac[i] *
        (
          q_other_hi[i, k] -
            q_other_lo[i, k]
        )
      
      q_per_here[i, k] <-
        q_per_lo[i, k] +
        sigma_grid_frac[i] *
        (
          q_per_hi[i, k] -
            q_per_lo[i, k]
        )
      
      social_Z[i, k] <-
        q_same_here[i, k] +
        q_other_here[i, k] *
        sg_multiplier +
        q_per_here[i, k] *
        peripheral_multiplier
      
      dest_other_core[i, k] <-
        equals(
          zone_here[i, k],
          1
        ) *
        (
          1 -
            equals(
              SG_here[i, k],
              SG_here[i, k - 1]
            )
        )
      
      dest_peripheral[i, k] <-
        equals(
          zone_here[i, k],
          2
        )
      
      log_R_dest[i, k] <-
        -beta_sg *
        dest_other_core[i, k] -
        beta_peripheral *
        dest_peripheral[i, k]
      
      log_social_correction[i, k] <-
        apply_social[i, k] *
        (
          log_R_dest[i, k] -
            log(
              social_Z[i, k]
            )
        )
      
      social_lambda[i, k] <-
        SOCIAL_ZERO_CONST -
        log_social_correction[i, k]
      
      social_zero[i, k] ~ dpois(
        social_lambda[i, k]
      )
      
      for(j in 1:J[i, k]) {
        
        lp0[i, j, k] <-
          alpha_p +
          beta_p_sex *
          sex[i] +
          beta_season[j] +
          beta_period[
            period_vec[k]
          ]
        
        lambda0[i, j, k] <-
          -log(
            1 -
              ilogit(
                lp0[i, j, k]
              )
          )
      }
      
      captureProb[
        i,
        1:J[i, k],
        k
      ] <- calc_capture_prob(
        S[i, 1, k],
        S[i, 2, k],
        X[1:R, 1:2],
        sigma_i[i],
        lambda0[
          i,
          1:J[i, k],
          k
        ],
        H[
          i,
          1:J[i, k],
          k
        ],
        z[i, k]
      )
      
      for(j in 1:J[i, k]) {
        Ones[
          i,
          j,
          k
        ] ~ dbern(
          captureProb[
            i,
            j,
            k
          ]
        )
      }
    }
  }
})


# =============================================================================
# ---- build constants/data ----------------------------------------------------
# =============================================================================

eps_zero <- c(0, 0)
eps_scale <- diag(T_SCALE_FACTOR^2, 2)

consts <- list(
  R = R,
  N = N,
  K = as.integer(K),
  J = J,
  first = as.integer(first),
  X = X,
  H = H,
  n_periods = n_periods,
  period_vec = period_vec,
  death_primary = death_primary,
  adult_entry = adult_entry,
  edge_proximity = edge_proximity,
  grid_xmin = grid_xmin,
  grid_xmax = grid_xmax,
  grid_ymin = grid_ymin,
  grid_ymax = grid_ymax,
  cell_size = cell_size,
  n_rows = n_rows,
  n_cols = n_cols,
  MOVE_DF = MOVE_DF,
  MOVE_MEAN_FACTOR = MOVE_MEAN_FACTOR,
  eps_zero = eps_zero,
  eps_scale = eps_scale,
  MOVE_PRIOR_LOGMEAN = MOVE_PRIOR_LOGMEAN,
  N_SIGMA_GRID = N_SIGMA_GRID,
  LOG_SIGMA_MIN = LOG_SIGMA_MIN,
  LOG_SIGMA_MAX = LOG_SIGMA_MAX,
  LOG_SIGMA_STEP = LOG_SIGMA_STEP,
  SOCIAL_ZERO_CONST = SOCIAL_ZERO_CONST
)

social_zero_data <- matrix(
  0L,
  nind,
  n_prim
)

data_list <- list(
  Ones = array(1L, dim(H)),
  z = z_data,
  sex = sex_data,
  immigrant = immigrant_data,
  state_ok = matrix(1L, nind, n_prim),
  social_zero = social_zero_data,
  move_support_ok = rep(1L, 4),
  habitat_mat = habitat_mat,
  SG_mat = SG_mat,
  zone_mat = zone_mat,
  q_same_grid = q_same_grid,
  q_other_grid = q_other_grid,
  q_peripheral_grid = q_peripheral_grid
)


# =============================================================================
# ---- model-code sanity checks ------------------------------------------------
# =============================================================================

code_txt <- paste(
  deparse(code_V3),
  collapse = " "
)

if(!grepl("dmvt", code_txt))
  stop("STOP: Student-t movement code not found.")

if(
  !grepl("immigrant\\[i\\] ~ dbern", code_txt) ||
  !grepl("beta_move_imm", code_txt)
)
  stop("STOP: latent immigrant movement structure not found.")

if(grepl("beta_phi_imm", code_txt))
  stop("STOP: immigrant survival effect must be absent in V5c.")

if(grepl("beta_imm_sex", code_txt))
  stop("STOP: sex must NOT define immigrant status in V5.")

if(
  !grepl("social_Z", code_txt) ||
  !grepl("beta_peripheral", code_txt)
)
  stop("STOP: normalized SG/peripheral code not found.")

if(
  !grepl("beta_move_sex", code_txt) ||
  !grepl("sigma_grid_frac", code_txt)
)
  stop("STOP: sex-specific dynamic movement normalization not found.")

cat(
  "\nModel code checks: PASS ",
  "(t3 + sex + latent immigrant movement-only + dynamic SG normalization)\n"
)


# =============================================================================
# ---- build model -------------------------------------------------------------
# =============================================================================

message(
  "\nBuilding V5c optimized latent-immigrant Student-t3 model..."
)

build_time_V3 <- system.time(
  
  model_V3 <- nimbleModel(
    code_V3,
    constants = consts,
    data = data_list,
    inits = inits[[1]],
    dimensions = list(
      Ones = dim(H),
      z = dim(z_data),
      immigrant = nind,
      state_ok = c(nind, n_prim),
      social_zero = c(nind, n_prim),
      move_support_ok = 4
    ),
    check = TRUE,
    calculate = FALSE
  )
)

cat("\nModel build time:\n")
print(build_time_V3)

lp <- model_V3$calculate()

cat(
  "\nInitial log probability:",
  lp,
  "\n"
)

if(!is.finite(lp))
  stop("V5c initial log probability is not finite.")


# =============================================================================
# ---- compile model -----------------------------------------------------------
# =============================================================================

message("\nCompiling model...")

compile_model_time_V3 <- system.time(
  
  cModel_V3 <- compileNimble(
    model_V3,
    resetFunctions = TRUE
  )
)

cat("\nModel compile time:\n")
print(compile_model_time_V3)


# =============================================================================
# ---- monitors ---------------------------------------------------------------
# =============================================================================

monitors <- c(
  "alpha_phi",
  "alpha_p",
  "alpha_logsigma",
  "alpha_logmove",
  
  "beta_phi_sex",
  "beta_p_sex",
  "beta_sigma_sex",
  "beta_move_sex",
  
  "beta_move_imm",
  "alpha_imm",
  "beta_imm_edge",
  
  "psi_sex",
  
  "phi_female",
  "phi_male",
  
  "p0_female",
  "p0_male",
  
  "sigma_female",
  "sigma_male",
  
  "sigma_move_female_local",
  "sigma_move_male_local",
  "sigma_move_female_imm",
  "sigma_move_male_imm",
  
  "mean_move_female_local",
  "mean_move_male_local",
  "mean_move_female_imm",
  "mean_move_male_imm",
  
  "p_imm_edge_minus1",
  "p_imm_edge_mean",
  "p_imm_edge_plus1",
  
  "beta_season",
  "beta_period",
  "beta_sg",
  "beta_peripheral",
  
  "sg_multiplier",
  "peripheral_multiplier"
)

if(length(unknown_sex_idx)) {
  monitors <- c(
    monitors,
    paste0(
      "sex[",
      unknown_sex_idx,
      "]"
    )
  )
}

if(length(adult_entry_idx)) {
  monitors <- c(
    monitors,
    paste0(
      "immigrant[",
      adult_entry_idx,
      "]"
    )
  )
}


# =============================================================================
# ---- configure MCMC ----------------------------------------------------------
# =============================================================================

config_V3 <- configureMCMC(
  model_V3,
  monitors = monitors,
  thin = 1
)


# =============================================================================
# ---- CUSTOM SAMPLERS ---------------------------------------------------------
# =============================================================================

message(
  "\nAssigning AF_slice samplers to annual movement innovations..."
)

eps_nodes <- unlist(
  lapply(
    (N[1] + 1L):N[2],
    function(i) {
      
      if(K[i] >= first[i] + 1L) {
        paste0(
          "eps[",
          i,
          ", 1:2, ",
          (first[i] + 1L):K[i],
          "]"
        )
      } else {
        character(0)
      }
    }
  ),
  use.names = FALSE
)

if(length(eps_nodes)) {
  
  config_V3$removeSamplers(
    eps_nodes,
    print = FALSE
  )
  
  invisible(
    lapply(
      eps_nodes,
      function(n) {
        config_V3$addSampler(
          target = n,
          type = "AF_slice"
        )
      }
    )
  )
}

move_pars <- c(
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_imm"
)

config_V3$removeSamplers(
  move_pars,
  print = FALSE
)

config_V3$addSampler(
  target = move_pars,
  type = "AF_slice"
)

surv_pars <- c(
  "alpha_phi",
  "beta_phi_sex"
)

config_V3$removeSamplers(
  surv_pars,
  print = FALSE
)

config_V3$addSampler(
  target = surv_pars,
  type = "AF_slice"
)

imm_process_pars <- c(
  "alpha_imm",
  "beta_imm_edge"
)

config_V3$removeSamplers(
  imm_process_pars,
  print = FALSE
)

config_V3$addSampler(
  target = imm_process_pars,
  type = "AF_slice"
)

cat("\nCustom samplers assigned:\n")
cat("  annual eps blocks:", length(eps_nodes), "AF_slice targets\n")
cat("  movement block:", paste(move_pars, collapse = ", "), "\n")
cat("  survival block:", paste(surv_pars, collapse = ", "), "\n")
cat(
  "  immigration-process block:",
  paste(imm_process_pars, collapse = ", "),
  "\n"
)
cat(
  "  latent adult immigrant states:",
  length(adult_entry_idx),
  "binary nodes\n"
)

print(config_V3)


# =============================================================================
# ---- build + compile MCMC ----------------------------------------------------
# =============================================================================

build_mcmc_time_V3 <- system.time(
  
  Rmcmc_V3 <- buildMCMC(
    config_V3
  )
)

cat("\nMCMC build time:\n")
print(build_mcmc_time_V3)

message("Compiling MCMC...")

compile_mcmc_time_V3 <- system.time(
  
  cMCMC_V3 <- compileNimble(
    Rmcmc_V3,
    project = cModel_V3,
    resetFunctions = TRUE
  )
)

cat("\nMCMC compile time:\n")
print(compile_mcmc_time_V3)


# =============================================================================
# ---- run ---------------------------------------------------------------------
# =============================================================================

message(
  "\nRunning V5c 800-badger LATENT IMMIGRANT + MOVE/SURVIVAL OPTIMIZED model..."
)

runtime_V3 <- system.time(
  
  samples_V3 <- runMCMC(
    cMCMC_V3,
    niter = NITER,
    nburnin = NBURN,
    nchains = NCHAINS,
    inits = inits,
    samplesAsCodaMCMC = TRUE,
    progressBar = TRUE,
    setSeed = 3451:(3451 + NCHAINS - 1L)
  )
)

print(runtime_V3)


# =============================================================================
# ---- save --------------------------------------------------------------------
# =============================================================================

saveRDS(
  
  list(
    samples = samples_V3,
    
    runtime = runtime_V3,
    build_time = build_time_V3,
    compile_model_time = compile_model_time_V3,
    build_mcmc_time = build_mcmc_time_V3,
    compile_mcmc_time = compile_mcmc_time_V3,
    
    ids = ids,
    
    sex_data = sex_data,
    
    entry_group = entry_group,
    adult_entry = adult_entry,
    
    immigrant_data = immigrant_data,
    
    edge_proximity = edge_proximity,
    first_edge_dist_m = first_edge_dist_m,
    
    unknown_sex_idx = unknown_sex_idx,
    adult_entry_idx = adult_entry_idx,
    
    detectors = detectors,
    det_audit = det_audit,
    
    settings = list(
      sample_n = SAMPLE_N,
      max_adult_entry = MAX_ADULT_ENTRY,
      
      n_adult_selected = sum(adult_entry == 1L),
      n_young_selected = sum(adult_entry == 0L),
      
      niter = NITER,
      nburn = NBURN,
      nchains = NCHAINS,
      
      data_source =
        "PostgreSQL/Supabase -> DataPrep.R -> fixed RDS snapshot",
      
      encounter_file =
        encounter_file,
      
      individual_file =
        individual_file,
      
      spatial_capture_source =
        "saved encounters_useful pre-quarter-collapse biological encounters",
      
      primary_occasion =
        "calendar year with four quarterly secondary occasions",
      
      within_quarter_live_rule =
        "prefer non-modal recognised sett then latest live capture",
      
      parameterisation =
        "noncentred",
      
      movement_kernel =
        "bivariate_Student_t",
      
      move_df =
        MOVE_DF,
      
      sg_model =
        "dynamic_interpolated_normalized_core_SG_plus_peripheral",
      
      entry_group_effects =
        "removed_from_survival_detection_movement",
      
      immigration_model =
        "young_entry_fixed_local_adult_entry_latent_edge_informed",
      
      sex_used_to_define_immigrant =
        FALSE,
      
      immigrant_effects =
        "movement_only",
      
      immigrant_survival_effect =
        FALSE,
      
      movement_global_sampler =
        "AF_slice_alpha_logmove_beta_move_sex_beta_move_imm",
      
      survival_global_sampler =
        "AF_slice_alpha_phi_beta_phi_sex",
      
      immigrant_process_sampler =
        "AF_slice_alpha_imm_beta_imm_edge",
      
      movement_normalization =
        "log_sigma_grid_linear_interpolation",
      
      sigma_grid =
        SIGMA_GRID,
      
      detection_implementation =
        "custom_compiled_nimbleFunction"
    ),
    
    spatial_file = spatial_file,
    q_cache_file = q_cache_file
  ),
  
  paste0(
    "results/RD_SCR_V5c_t",
    MOVE_DF,
    "_LATENT_IMMIGRANT_MOVEMENT_ONLY_OPTIMIZED_",
    nind,
    "_badgers.rds"
  )
)

cat("\n============================================================\n")
cat("MODEL COMPLETE\n")
cat("============================================================\n")
cat("Results saved for", nind, "badgers.\n")