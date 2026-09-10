# =============================================================================
# WOODCHESTER SPATIAL CMR V6c
# ROBUST RESIDENT <-> DISPERSER MODEL + SEX-SPECIFIC STATE DYNAMICS
#
# PURPOSE
#   1. Test whether V6b's extreme resident/disperser separation is robust
#      to substantially wider movement support.
#   2. Test WHERE sex acts:
#        a) movement distance conditional on state
#        b) initial probability of dispersal
#        c) resident -> disperser probability
#        d) persistence in disperser state
#   3. Save latent-state posteriors for individual movement histories.
#
# IMPORTANT
#   - These are MOVEMENT STATES, not assumed permanent badger "types".
#   - Movement process is conditioned on first -> last observed live year.
#   - Survival is deliberately NOT estimated in this bridge model.
#   - 2026 excluded because it is an incomplete trapping year.
# =============================================================================

library(tidyverse); library(lubridate); library(nimble); library(coda); library(MCMCvis); library(sf)

set.seed(123)

# =============================================================================
# OPTIONS
# =============================================================================

MAX_YEAR <- 2025L
MIN_LIVE_YEARS <- 2L

SAMPLE_N <- 500L
MAX_ADULT_ENTRY <- 250L

NITER <- 24000
NBURN <- 6000
NCHAINS <- 3
THIN <- 4L

SAVE_LATENT_STATES <- TRUE

# ---- movement ---------------------------------------------------------------
SIGMA_MOVE_INIT <- 55
MOVE_PRIOR_LOGMEAN <- log(SIGMA_MOVE_INIT)

# Gaussian 2-D movement: E(radial distance) = sigma * sqrt(pi/2)
MOVE_MEAN_FACTOR <- sqrt(pi/2)

# V6c sensitivity: much wider support than V6b.
N_SIGMA_GRID <- 41L
LOG_SIGMA_MIN <- log(5)
LOG_SIGMA_MAX <- log(2500)
LOG_SIGMA_STEP <- (LOG_SIGMA_MAX-LOG_SIGMA_MIN)/(N_SIGMA_GRID-1L)
SIGMA_GRID <- exp(seq(LOG_SIGMA_MIN,LOG_SIGMA_MAX,length.out=N_SIGMA_GRID))

SOCIAL_ZERO_CONST <- 50

cat("\n============================================================\n")
cat("V6c ROBUST RESIDENT <-> DISPERSER + SEX MODEL\n")
cat("============================================================\n")
cat("Years:",MAX_YEAR,"and earlier\n")
cat("Target sample:",SAMPLE_N,"\n")
cat("Minimum live years:",MIN_LIVE_YEARS,"\n")
cat("Iterations:",NITER,"| burn:",NBURN,"| chains:",NCHAINS,"| thin:",THIN,"\n")
cat("Movement support:",round(min(SIGMA_GRID),1),"-",round(max(SIGMA_GRID),1),"m\n")
cat("Sigma knots:",N_SIGMA_GRID,"\n")
cat("Latent states saved:",SAVE_LATENT_STATES,"\n\n")

# =============================================================================
# FILES
# =============================================================================

encounter_file <- "data/badger_encounters_useful.rds"
individual_file <- "data/badger_individuals.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
spatial_file <- "data/spatial/V3_spatial_inputs_50m_2km.rds"

required_files <- c(encounter_file,individual_file,sett_file,spatial_file)
missing_files <- required_files[!file.exists(required_files)]

if(length(missing_files))
  stop("Missing required file(s):\n",paste(missing_files,collapse="\n"))

cmr_raw <- readRDS(encounter_file)
individuals <- readRDS(individual_file)
sp <- readRDS(spatial_file)

dir.create("results",showWarnings=FALSE)

# =============================================================================
# SETT CLEANING
# =============================================================================

sett_aliases <- c(
  "\\bCHESTNUT\\b"="CHESNUT","\\bJACKS\\b"="JACKSMIREY",
  "\\bGRAVEL\\b"="GRAVELPIT","\\bBUCKHOLE\\b"="BUCKHOLT",
  "\\bTOPSETT\\b"="TOP","\\bFOXCUB\\b"="FOX",
  "\\bGULLEY\\b"="GULLY","\\bBLACKBERRY\\b"="BRAMBLE",
  "\\bBOC\\b"="BOG","\\bCEDARBANK\\b"="CEDAR",
  "\\bCLAYTRAP\\b"="CLAY","\\bCLIFF\\b"="CLIFFFACE",
  "\\bDINGLEVALLEY\\b"="DINGLE"
)

clean_sett <- function(x) x %>%
  as.character() %>%
  toupper() %>%
  str_replace_all("[[:punct:]]"," ") %>%
  str_squish() %>%
  str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
  str_replace_all(sett_aliases) %>%
  str_replace_all("\\s+","")

# =============================================================================
# SPATIAL INPUTS
# =============================================================================

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

stopifnot(!anyNA(SG_mat),!anyNA(habitat_mat),!anyNA(zone_mat))

cat("Spatial grid:",n_rows,"x",n_cols,"@",cell_size,"m\n")

# =============================================================================
# SETT COORDINATES
# =============================================================================

sett_raw <- read_csv(sett_file,show_col_types=FALSE)

name_col <- intersect(c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name"),names(sett_raw))[1]
x_col <- intersect(c("SettX","sett_x","X","x","Easting","easting"),names(sett_raw))[1]
y_col <- intersect(c("SettY","sett_y","Y","y","Northing","northing"),names(sett_raw))[1]

if(any(is.na(c(name_col,x_col,y_col))))
  stop("Could not identify sett name/X/Y columns.")

sett_xy <- sett_raw %>%
  transmute(
    Sett_Clean=clean_sett(.data[[name_col]]),
    x=as.numeric(.data[[x_col]]),
    y=as.numeric(.data[[y_col]])
  ) %>%
  filter(!is.na(Sett_Clean),Sett_Clean!="",!is.na(x),!is.na(y)) %>%
  distinct(Sett_Clean,.keep_all=TRUE)

# =============================================================================
# BIOLOGICAL ENCOUNTERS
# =============================================================================

cmr <- cmr_raw %>%
  mutate(
    Sett_Clean=clean_sett(sett),
    primary_year=as.integer(primary_year),
    trap_season=as.integer(trap_season)
  ) %>%
  filter(!is.na(primary_year),primary_year<=MAX_YEAR) %>%
  left_join(sett_xy,by="Sett_Clean")

years <- min(cmr$primary_year,na.rm=TRUE):max(cmr$primary_year,na.rm=TRUE)
n_prim <- length(years)
n_sec <- 4L

cmr <- cmr %>%
  mutate(primary=match(primary_year,years))

period_raw <- floor(years/5)*5
period_vec <- as.integer(match(period_raw,sort(unique(period_raw))))
n_periods <- max(period_vec)

cat("Analysis years:",min(years),"-",max(years),"|",n_prim,"years\n")

# =============================================================================
# DEMOGRAPHICS
# =============================================================================

demog <- individuals %>%
  transmute(
    individual_id,tattoo,
    age_fc=as.character(age_fc),
    entry_group=case_when(
      age_fc %in% c("Cub","Yearling") ~ 1L,
      age_fc=="Adult" ~ 2L,
      TRUE ~ NA_integer_
    )
  )

sex_lookup <- individuals %>%
  transmute(individual_id,tattoo,sex_raw=as.character(sex)) %>%
  mutate(
    sex_clean=toupper(str_squish(sex_raw)),
    sex_code=case_when(
      sex_clean %in% c("F","FEMALE") ~ 0L,
      sex_clean %in% c("M","MALE") ~ 1L,
      TRUE ~ NA_integer_
    )
  )

# =============================================================================
# LIVE SCR OBSERVATIONS
# =============================================================================

# One detector observation per badger/year/quarter.
# If >1 live location exists in a quarter:
# non-modal movement record preferred, then latest record.

live <- cmr %>%
  filter(
    has_live_capture,
    !is.na(primary),
    !is.na(trap_season),
    !is.na(x),
    !is.na(y)
  ) %>%
  arrange(individual_id,primary,trap_season,capture_date) %>%
  group_by(individual_id,primary,trap_season) %>%
  arrange(desc(differs_from_modal),desc(capture_date),.by_group=TRUE) %>%
  slice(1) %>%
  ungroup()

stopifnot(
  nrow(
    live %>%
      count(individual_id,primary,trap_season) %>%
      filter(n>1)
  )==0
)

# =============================================================================
# MOVEMENT-INFORMATIVE INDIVIDUALS
# =============================================================================

live_years <- live %>%
  distinct(individual_id,tattoo,primary) %>%
  count(individual_id,tattoo,name="n_live_years")

cat("\nObserved live-year distribution:\n")
print(live_years %>% count(n_live_years))

eligible <- live %>%
  distinct(individual_id,tattoo) %>%
  inner_join(live_years,by=c("individual_id","tattoo")) %>%
  inner_join(demog,by=c("individual_id","tattoo")) %>%
  left_join(
    sex_lookup %>% select(individual_id,tattoo,sex_code),
    by=c("individual_id","tattoo")
  ) %>%
  filter(
    entry_group %in% 1:2,
    n_live_years>=MIN_LIVE_YEARS,
    tattoo!="007V"
  )

cat("\nMovement-informative eligible:",nrow(eligible),"\n")
cat("Adult-entry:",sum(eligible$entry_group==2L),"\n")
cat("Young-entry:",sum(eligible$entry_group==1L),"\n")

# =============================================================================
# ADULT-ENRICHED SAMPLE
# =============================================================================

eligible_adult <- eligible %>% filter(entry_group==2L)
eligible_young <- eligible %>% filter(entry_group==1L)

n_adult_take <- min(MAX_ADULT_ENTRY,nrow(eligible_adult),SAMPLE_N)
n_young_take <- min(SAMPLE_N-n_adult_take,nrow(eligible_young))

if(n_adult_take<nrow(eligible_adult)){
  adult_sample <- eligible_adult %>% slice_sample(n=n_adult_take)
} else {
  adult_sample <- eligible_adult
}

if(n_young_take<nrow(eligible_young)){
  young_sample <- eligible_young %>% slice_sample(n=n_young_take)
} else {
  young_sample <- eligible_young
}

eligible <- bind_rows(adult_sample,young_sample) %>%
  slice_sample(prop=1)

if(nrow(eligible)<SAMPLE_N)
  warning("Fewer movement-informative badgers than SAMPLE_N.")

ids <- eligible$tattoo
nind <- length(ids)

live <- live %>% filter(tattoo %in% ids)

cat("\nSelected sample:",nind,"\n")
cat("Adult-entry:",sum(eligible$entry_group==2L),"\n")
cat("Young-entry:",sum(eligible$entry_group==1L),"\n")

# =============================================================================
# DETECTORS
# =============================================================================

detectors <- live %>%
  distinct(Sett_Clean,x,y) %>%
  arrange(Sett_Clean) %>%
  mutate(detector=row_number())

X <- as.matrix(detectors %>% select(x,y))
R <- nrow(X)

live <- live %>%
  left_join(detectors %>% select(Sett_Clean,detector),by="Sett_Clean")

det_audit <- detectors %>%
  mutate(
    col_R=floor((x-grid_xmin)/cell_size)+1L,
    row_R=floor((grid_ymax-y)/cell_size)+1L,
    in_bounds=col_R>=1L & col_R<=n_cols &
      row_R>=1L & row_R<=n_rows
  )

if(any(!det_audit$in_bounds))
  stop("Used detector outside spatial grid.")

cat("Detectors:",R,"\n")

# =============================================================================
# INDIVIDUAL HISTORY LIMITS
# =============================================================================

meta <- live %>%
  group_by(tattoo) %>%
  summarise(
    first=min(primary),
    last_live=max(primary),
    n_live_years=n_distinct(primary),
    .groups="drop"
  ) %>%
  right_join(tibble(tattoo=ids),by="tattoo") %>%
  left_join(
    eligible %>% select(tattoo,entry_group,sex_code),
    by="tattoo"
  ) %>%
  arrange(match(tattoo,ids))

first <- as.integer(meta$first)
K <- as.integer(meta$last_live)
n_live_years <- as.integer(meta$n_live_years)

entry_group <- as.integer(meta$entry_group)
adult_entry <- as.integer(entry_group==2L)
sex_data <- as.integer(meta$sex_code)

stopifnot(
  !anyNA(first),
  !anyNA(K),
  !anyNA(entry_group),
  all(K>first)
)

if(any(!is.na(sex_data) & !sex_data %in% 0:1))
  stop("Known sex must be 0=female or 1=male.")

# =============================================================================
# ENCOUNTER HISTORIES
# =============================================================================

H <- array(1L,c(nind,n_sec,n_prim))

for(r in seq_len(nrow(live))){
  i <- match(live$tattoo[r],ids)
  
  H[
    i,
    live$trap_season[r],
    live$primary[r]
  ] <- live$detector[r]+1L
}

# Complete years only, four quarters each year.
J <- matrix(n_sec,nind,n_prim)

# =============================================================================
# REORDER
# =============================================================================

ord <- order(K-first)

ids <- ids[ord]
H <- H[ord,,,drop=FALSE]
J <- J[ord,,drop=FALSE]

first <- first[ord]
K <- K[ord]
n_live_years <- n_live_years[ord]

entry_group <- entry_group[ord]
adult_entry <- adult_entry[ord]
sex_data <- sex_data[ord]

unknown_sex_idx <- which(is.na(sex_data))

cat("\nFinal V6c sample:\n")
cat("nind:",nind,"\n")
cat("movement intervals:",sum(K-first),"\n")
cat("maximum history span:",max(K-first),"years\n")
cat("known sex:",sum(!is.na(sex_data)),"\n")
cat("unknown sex:",length(unknown_sex_idx),"\n")
cat("adult-entry:",sum(adult_entry==1L),"\n")
cat("young-entry:",sum(adult_entry==0L),"\n")

# =============================================================================
# RAW MOVEMENT AUDIT
# =============================================================================

annual_obs <- live %>%
  arrange(tattoo,primary,trap_season,capture_date) %>%
  group_by(tattoo,primary) %>%
  slice(1) %>%
  ungroup() %>%
  arrange(tattoo,primary) %>%
  group_by(tattoo) %>%
  mutate(
    previous_primary=lag(primary),
    previous_x=lag(x),
    previous_y=lag(y),
    year_gap=primary-previous_primary,
    observed_move=sqrt((x-previous_x)^2+(y-previous_y)^2)
  ) %>%
  ungroup() %>%
  filter(!is.na(observed_move))

cat("\nRaw observed between-year location movement:\n")

print(
  quantile(
    annual_obs$observed_move,
    probs=c(0,.25,.5,.75,.9,.95,.99,1),
    na.rm=TRUE
  )
)

cat("Observed moves >250 m:",sum(annual_obs$observed_move>250),"\n")
cat("Observed moves >500 m:",sum(annual_obs$observed_move>500),"\n")
cat("Observed moves >1000 m:",sum(annual_obs$observed_move>1000),"\n")

# =============================================================================
# LATENT MOVEMENT-STATE INDEX
# =============================================================================

# disp[i,k] controls movement interval k -> k+1.

disp_index <- map_dfr(seq_len(nind),function(i){
  
  kk <- first[i]:(K[i]-1L)
  
  tibble(
    node=paste0("disp[",i,", ",kk,"]"),
    model_i=i,
    tattoo=ids[i],
    from_primary=kk,
    to_primary=kk+1L,
    from_year=years[kk],
    to_year=years[kk+1L]
  )
})

disp_nodes <- disp_index$node

cat("Latent movement intervals to monitor:",length(disp_nodes),"\n")

# =============================================================================
# INITIAL VALUES
# =============================================================================

make_inits <- function(chain=1L){
  
  S_init <- array(NA_real_,c(nind,2,n_prim))
  eps_init <- array(NA_real_,c(nind,2,n_prim))
  disp_init <- matrix(NA_integer_,nind,n_prim)
  
  alpha_logmove_init <- log(SIGMA_MOVE_INIT)+rnorm(1,0,.04)
  beta_move_sex_init <- rnorm(1,0,.05)
  beta_move_disp_init <- log(5)+rnorm(1,0,.08)
  
  alpha_disp_init_val <- qlogis(.10)+rnorm(1,0,.08)
  beta_disp_adult_val <- rnorm(1,0,.10)
  beta_disp_init_sex_val <- rnorm(1,0,.10)
  
  alpha_RD_val <- qlogis(.06)+rnorm(1,0,.08)
  beta_RD_sex_val <- rnorm(1,0,.10)
  
  alpha_DD_val <- qlogis(.30)+rnorm(1,0,.08)
  beta_DD_sex_val <- rnorm(1,0,.10)
  
  sex_init <- sex_data
  
  if(length(unknown_sex_idx))
    sex_init[unknown_sex_idx] <-
    rbinom(length(unknown_sex_idx),1,.47)
  
  # Deliberately different starting allocations across chains.
  thresholds <- c(150,275,450)
  disp_threshold <- thresholds[((chain-1L)%%length(thresholds))+1L]
  
  for(i in seq_len(nind)){
    
    d <- live %>%
      filter(tattoo==ids[i]) %>%
      arrange(primary,trap_season,capture_date) %>%
      group_by(primary) %>%
      slice(1) %>%
      ungroup() %>%
      select(primary,x,y)
    
    xy <- matrix(NA_real_,n_prim,2)
    
    for(k in first[i]:K[i]){
      
      dk <- d %>%
        filter(primary==k)
      
      if(nrow(dk)){
        xy[k,] <- c(dk$x[1],dk$y[1])
      } else if(k>first[i]){
        xy[k,] <- xy[k-1L,]
      }
    }
    
    S_init[i,,first[i]] <- xy[first[i],]
    
    # Initial state allocation only.
    for(k in first[i]:(K[i]-1L)){
      
      dd <- sqrt(
        (xy[k+1L,1]-xy[k,1])^2+
          (xy[k+1L,2]-xy[k,2])^2
      )
      
      disp_init[i,k] <- as.integer(dd>=disp_threshold)
    }
    
    # Terminal state retained for simple Markov implementation.
    disp_init[i,K[i]] <- disp_init[i,K[i]-1L]
    
    for(k in (first[i]+1L):K[i]){
      
      log_sig_init <-
        alpha_logmove_init+
        beta_move_sex_init*sex_init[i]+
        beta_move_disp_init*disp_init[i,k-1L]
      
      sig_init <- exp(log_sig_init)
      
      eps_init[i,1,k] <-
        (xy[k,1]-xy[k-1L,1])/sig_init
      
      eps_init[i,2,k] <-
        (xy[k,2]-xy[k-1L,2])/sig_init
    }
  }
  
  list(
    alpha_p=qlogis(.17)+rnorm(1,0,.03),
    alpha_logsigma=log(132)+rnorm(1,0,.03),
    
    beta_p_sex=.10+rnorm(1,0,.03),
    beta_sigma_sex=.05+rnorm(1,0,.02),
    
    alpha_logmove=alpha_logmove_init,
    beta_move_sex=beta_move_sex_init,
    beta_move_disp=beta_move_disp_init,
    
    alpha_disp_init=alpha_disp_init_val,
    beta_disp_adult=beta_disp_adult_val,
    beta_disp_init_sex=beta_disp_init_sex_val,
    
    alpha_RD=alpha_RD_val,
    beta_RD_sex=beta_RD_sex_val,
    
    alpha_DD=alpha_DD_val,
    beta_DD_sex=beta_DD_sex_val,
    
    disp=disp_init,
    
    psi_sex=runif(1,.43,.50),
    
    sex={
      s <- rep(NA_integer_,nind)
      
      if(length(unknown_sex_idx))
        s[unknown_sex_idx] <- sex_init[unknown_sex_idx]
      
      s
    },
    
    beta_season_raw=rnorm(3,0,.03),
    beta_period_raw=rnorm(n_periods-1L,0,.03),
    
    beta_sg=runif(1,.02,.15),
    beta_peripheral=runif(1,.05,.25),
    
    S=S_init,
    eps=eps_init
  )
}

inits <- lapply(seq_len(NCHAINS),make_inits)

# =============================================================================
# INITIAL SPATIAL AUDIT
# =============================================================================

audit_init <- function(init){
  
  bad <- list()
  
  for(i in seq_len(nind)){
    
    sx <- init$S[i,1,first[i]]
    sy <- init$S[i,2,first[i]]
    
    sex_i <- if(is.na(sex_data[i])) init$sex[i] else sex_data[i]
    
    col <- floor((sx-grid_xmin)/cell_size)+1L
    row <- floor((grid_ymax-sy)/cell_size)+1L
    
    in_bounds <- col>=1L && col<=n_cols &&
      row>=1L && row<=n_rows
    
    habitat <- if(in_bounds) habitat_mat[row,col] else 0L
    
    if(!in_bounds || habitat!=1L){
      
      bad[[length(bad)+1L]] <- tibble(
        i=i,tattoo=ids[i],
        primary=first[i],
        year=years[first[i]],
        x=sx,y=sy
      )
    }
    
    for(k in (first[i]+1L):K[i]){
      
      sig <- exp(
        init$alpha_logmove+
          init$beta_move_sex*sex_i+
          init$beta_move_disp*init$disp[i,k-1L]
      )
      
      sx <- sx+sig*init$eps[i,1,k]
      sy <- sy+sig*init$eps[i,2,k]
      
      col <- floor((sx-grid_xmin)/cell_size)+1L
      row <- floor((grid_ymax-sy)/cell_size)+1L
      
      in_bounds <- col>=1L && col<=n_cols &&
        row>=1L && row<=n_rows
      
      habitat <- if(in_bounds) habitat_mat[row,col] else 0L
      
      if(!in_bounds || habitat!=1L){
        
        bad[[length(bad)+1L]] <- tibble(
          i=i,tattoo=ids[i],
          primary=k,
          year=years[k],
          x=sx,y=sy
        )
      }
    }
  }
  
  if(length(bad)) bind_rows(bad) else tibble()
}

init_audit <- audit_init(inits[[1]])

cat("\nInitialization audit:\n")
cat("invalid states:",nrow(init_audit),"\n")

if(nrow(init_audit)){
  print(init_audit)
  stop("Initial spatial reconstruction contains invalid states.")
}

cat("PASS\n")

# =============================================================================
# GAUSSIAN LANDSCAPE NORMALIZATION CACHE
# =============================================================================

cat("\nPreparing Gaussian landscape-normalization arrays...\n")

grid_df <- sp$grid %>%
  sf::st_drop_geometry()

if(!all(c("row_R","col_R","SG_id","habitat","zone") %in% names(grid_df)))
  stop("sp$grid must contain row_R, col_R, SG_id, habitat and zone.")

grid_xy <- sf::st_coordinates(sp$grid)

land_idx <- which(grid_df$habitat==1L)
core_idx <- which(grid_df$habitat==1L & grid_df$zone==1L)

q_cache_file <- file.path(
  "data","spatial",
  paste0(
    "V6c_qgrid_GAUSSIAN_",
    N_SIGMA_GRID,"knots_",
    round(min(SIGMA_GRID)),"to",
    round(max(SIGMA_GRID)),"m.rds"
  )
)

cache_ok <- FALSE

if(file.exists(q_cache_file)){
  
  qcache <- readRDS(q_cache_file)
  
  cache_ok <-
    identical(qcache$n_rows,n_rows) &&
    identical(qcache$n_cols,n_cols) &&
    identical(qcache$kernel,"gaussian") &&
    isTRUE(
      all.equal(
        qcache$sigma_grid,
        SIGMA_GRID,
        tolerance=1e-12
      )
    )
}

if(cache_ok){
  
  cat("Loading cached normalization grid:\n",q_cache_file,"\n")
  
  q_same_grid <- qcache$q_same
  q_other_grid <- qcache$q_other
  q_peripheral_grid <- qcache$q_peripheral
  
} else {
  
  cat("No matching cache; calculating normalization grid...\n")
  
  q_same_grid <- array(1,c(N_SIGMA_GRID,n_rows,n_cols))
  q_other_grid <- array(0,c(N_SIGMA_GRID,n_rows,n_cols))
  q_peripheral_grid <- array(0,c(N_SIGMA_GRID,n_rows,n_cols))
  
  calc_q_chunk <- function(origin_idx){
    
    ns <- length(SIGMA_GRID)
    
    out_same <- matrix(0,length(origin_idx),ns)
    out_other <- matrix(0,length(origin_idx),ns)
    out_per <- matrix(0,length(origin_idx),ns)
    
    for(a in seq_along(origin_idx)){
      
      oi <- origin_idx[a]
      
      dx <- grid_xy[land_idx,1]-grid_xy[oi,1]
      dy <- grid_xy[land_idx,2]-grid_xy[oi,2]
      d2 <- dx^2+dy^2
      
      same <-
        grid_df$zone[land_idx]==1L &
        grid_df$SG_id[land_idx]==grid_df$SG_id[oi]
      
      other <-
        grid_df$zone[land_idx]==1L &
        grid_df$SG_id[land_idx]!=grid_df$SG_id[oi]
      
      per <- grid_df$zone[land_idx]==2L
      
      for(ss in seq_len(ns)){
        
        sig <- SIGMA_GRID[ss]
        w <- exp(-d2/(2*sig^2))
        den <- sum(w)
        
        out_same[a,ss] <- sum(w[same])/den
        out_other[a,ss] <- sum(w[other])/den
        out_per[a,ss] <- sum(w[per])/den
      }
    }
    
    list(
      origin_idx=origin_idx,
      same=out_same,
      other=out_other,
      per=out_per
    )
  }
  
  nc_detected <- parallel::detectCores()
  if(is.na(nc_detected)) nc_detected <- 1L
  
  ncores <- max(1L,min(8L,nc_detected-1L))
  nchunks <- min(ncores,length(core_idx))
  
  if(nchunks==1L){
    chunks <- list(core_idx)
  } else {
    chunks <- split(
      core_idx,
      cut(seq_along(core_idx),breaks=nchunks,labels=FALSE)
    )
  }
  
  cat(
    "Computing",length(core_idx),"core origins x",
    N_SIGMA_GRID,"knots using",ncores,"core(s)...\n"
  )
  
  q_time <- system.time({
    
    if(.Platform$OS.type!="windows" && ncores>1L){
      
      q_parts <- parallel::mclapply(
        chunks,
        calc_q_chunk,
        mc.cores=ncores
      )
      
    } else {
      
      q_parts <- lapply(chunks,calc_q_chunk)
    }
  })
  
  print(q_time)
  
  for(part in q_parts){
    
    for(a in seq_along(part$origin_idx)){
      
      oi <- part$origin_idx[a]
      
      rr <- grid_df$row_R[oi]
      cc <- grid_df$col_R[oi]
      
      q_same_grid[,rr,cc] <- part$same[a,]
      q_other_grid[,rr,cc] <- part$other[a,]
      q_peripheral_grid[,rr,cc] <- part$per[a,]
    }
  }
  
  saveRDS(
    list(
      q_same=q_same_grid,
      q_other=q_other_grid,
      q_peripheral=q_peripheral_grid,
      sigma_grid=SIGMA_GRID,
      n_rows=n_rows,
      n_cols=n_cols,
      kernel="gaussian"
    ),
    q_cache_file
  )
  
  cat("Saved:",q_cache_file,"\n")
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

for(ss in seq_len(N_SIGMA_GRID)){
  
  qsum <-
    q_same_grid[ss,,]+
    q_other_grid[ss,,]+
    q_peripheral_grid[ss,,]
  
  max_q_error <-
    max(max_q_error,max(abs(qsum[core_rc]-1)))
  
  min_q_same <-
    min(min_q_same,min(q_same_grid[ss,,][core_rc]))
}

cat("Normalization max |sum(q)-1|:",max_q_error,"\n")
cat("Minimum same-SG mass:",min_q_same,"\n")

if(SOCIAL_ZERO_CONST<=-log(min_q_same)+5)
  stop("SOCIAL_ZERO_CONST too small.")

# =============================================================================
# COMPILED DETECTION LIKELIHOOD
# =============================================================================

calc_capture_prob <- nimbleFunction(
  
  run=function(
    Sx=double(0),
    Sy=double(0),
    X=double(2),
    sigma=double(0),
    lambda0_vec=double(1),
    H_vec=double(1)
  ){
    
    returnType(double(1))
    
    R <- dim(X)[1]
    J <- length(H_vec)
    
    G_sum <- 0.0
    g_vec <- numeric(R+1,init=FALSE)
    
    g_vec[1] <- 0.0
    
    for(r in 1:R){
      
      d2 <-
        (Sx-X[r,1])^2+
        (Sy-X[r,2])^2
      
      g <- exp(-d2/(2.0*sigma^2))
      
      g_vec[r+1] <- g
      G_sum <- G_sum+g
    }
    
    captureProb <- numeric(J,init=FALSE)
    
    for(j in 1:J){
      
      P_capture <-
        1.0-exp(-lambda0_vec[j]*G_sum)
      
      H_j <- as.integer(H_vec[j])
      
      if(H_j>=2){
        
        captureProb[j] <-
          (g_vec[H_j]/(G_sum+1e-10))*
          P_capture
        
      } else {
        
        captureProb[j] <-
          1.0-P_capture
      }
    }
    
    return(captureProb)
  }
)

# =============================================================================
# MODEL
# =============================================================================

eps_zero <- c(0,0)
eps_cov <- diag(1,2)

code_V6c <- nimbleCode({
  
  # ===========================================================================
  # SEX + DETECTION
  # ===========================================================================
  
  psi_sex ~ dbeta(1,1)
  
  alpha_p ~ dnorm(qlogis(.17),sd=1.5)
  alpha_logsigma ~ dnorm(log(150),sd=1)
  
  beta_p_sex ~ dnorm(0,sd=1)
  beta_sigma_sex ~ dnorm(0,sd=.75)
  
  for(i in 1:nind){
    
    sex[i] ~ dbern(psi_sex)
    
    sigma_i[i] <-
      exp(
        alpha_logsigma+
          beta_sigma_sex*sex[i]
      )
  }
  
  p0_female <- ilogit(alpha_p)
  p0_male <- ilogit(alpha_p+beta_p_sex)
  
  sigma_female <- exp(alpha_logsigma)
  sigma_male <- exp(alpha_logsigma+beta_sigma_sex)
  
  # ===========================================================================
  # MOVEMENT SCALE
  # ===========================================================================
  
  alpha_logmove ~ dnorm(MOVE_PRIOR_LOGMEAN,sd=.60)
  
  # Sex effect on movement DISTANCE conditional on being in same state.
  beta_move_sex ~ dnorm(0,sd=.50)
  
  # Positive constraint identifies disp=1 as HIGH movement.
  beta_move_disp ~ dexp(1)
  
  # ===========================================================================
  # INITIAL MOVEMENT STATE
  # ===========================================================================
  
  alpha_disp_init ~ dnorm(qlogis(.10),sd=1.25)
  
  beta_disp_adult ~ dnorm(0,sd=1)
  
  # NEW: male/female difference in INITIAL disperser probability.
  beta_disp_init_sex ~ dnorm(0,sd=1)
  
  p_disp_init_young_female <-
    ilogit(alpha_disp_init)
  
  p_disp_init_young_male <-
    ilogit(
      alpha_disp_init+
        beta_disp_init_sex
    )
  
  p_disp_init_adult_female <-
    ilogit(
      alpha_disp_init+
        beta_disp_adult
    )
  
  p_disp_init_adult_male <-
    ilogit(
      alpha_disp_init+
        beta_disp_adult+
        beta_disp_init_sex
    )
  
  # ===========================================================================
  # SEX-SPECIFIC MARKOV TRANSITIONS
  # ===========================================================================
  
  # Resident -> disperser
  alpha_RD ~ dnorm(qlogis(.10),sd=1.5)
  beta_RD_sex ~ dnorm(0,sd=1)
  
  # Disperser -> disperser
  alpha_DD ~ dnorm(qlogis(.50),sd=1.5)
  beta_DD_sex ~ dnorm(0,sd=1)
  
  p_RD_female <- ilogit(alpha_RD)
  p_RD_male <- ilogit(alpha_RD+beta_RD_sex)
  
  p_DD_female <- ilogit(alpha_DD)
  p_DD_male <- ilogit(alpha_DD+beta_DD_sex)
  
  p_RR_female <- 1-p_RD_female
  p_RR_male <- 1-p_RD_male
  
  p_DR_female <- 1-p_DD_female
  p_DR_male <- 1-p_DD_male
  
  # ===========================================================================
  # FOUR MOVEMENT SCALES
  # ===========================================================================
  
  # 1 female resident
  # 2 male resident
  # 3 female disperser
  # 4 male disperser
  
  log_sigma_move_state[1] <-
    alpha_logmove
  
  log_sigma_move_state[2] <-
    alpha_logmove+
    beta_move_sex
  
  log_sigma_move_state[3] <-
    alpha_logmove+
    beta_move_disp
  
  log_sigma_move_state[4] <-
    alpha_logmove+
    beta_move_sex+
    beta_move_disp
  
  for(m in 1:4){
    
    sigma_move_state[m] <-
      exp(log_sigma_move_state[m])
    
    move_support[m] <-
      step(
        log_sigma_move_state[m]-
          LOG_SIGMA_MIN
      )*
      step(
        LOG_SIGMA_MAX-
          log_sigma_move_state[m]
      )
    
    move_support_ok[m] ~
      dbern(move_support[m])
    
    sigma_grid_pos_state[m] <-
      (
        log_sigma_move_state[m]-
          LOG_SIGMA_MIN
      )/
      LOG_SIGMA_STEP+
      1
    
    sigma_grid_lo_raw_state[m] <-
      trunc(sigma_grid_pos_state[m])
    
    sigma_grid_lo_state[m] <-
      max(
        1,
        min(
          N_SIGMA_GRID-1,
          sigma_grid_lo_raw_state[m]
        )
      )
    
    sigma_grid_frac_state[m] <-
      max(
        0,
        min(
          1,
          sigma_grid_pos_state[m]-
            sigma_grid_lo_state[m]
        )
      )
  }
  
  move_multiplier_male <- exp(beta_move_sex)
  move_multiplier_disp <- exp(beta_move_disp)
  
  sigma_move_female_resident <- sigma_move_state[1]
  sigma_move_male_resident <- sigma_move_state[2]
  sigma_move_female_disperser <- sigma_move_state[3]
  sigma_move_male_disperser <- sigma_move_state[4]
  
  mean_move_female_resident <-
    sigma_move_state[1]*MOVE_MEAN_FACTOR
  
  mean_move_male_resident <-
    sigma_move_state[2]*MOVE_MEAN_FACTOR
  
  mean_move_female_disperser <-
    sigma_move_state[3]*MOVE_MEAN_FACTOR
  
  mean_move_male_disperser <-
    sigma_move_state[4]*MOVE_MEAN_FACTOR
  
  # ===========================================================================
  # LANDSCAPE
  # ===========================================================================
  
  beta_sg ~ dexp(1)
  beta_peripheral ~ dexp(1)
  
  sg_multiplier <- exp(-beta_sg)
  peripheral_multiplier <- exp(-beta_peripheral)
  
  # ===========================================================================
  # DETECTION TIME EFFECTS
  # ===========================================================================
  
  for(s in 1:3){
    
    beta_season_raw[s] ~ dnorm(0,sd=1)
    beta_season[s] <- beta_season_raw[s]
  }
  
  beta_season[4] <-
    -sum(beta_season_raw[1:3])
  
  for(p in 1:(n_periods-1)){
    
    beta_period_raw[p] ~ dnorm(0,sd=1)
    beta_period[p] <- beta_period_raw[p]
  }
  
  beta_period[n_periods] <-
    -sum(beta_period_raw[1:(n_periods-1)])
  
  # ===========================================================================
  # INDIVIDUAL HISTORIES
  # ===========================================================================
  
  for(i in 1:nind){
    
    # -------------------------------------------------------------------------
    # Sex-specific state-transition probabilities
    # -------------------------------------------------------------------------
    
    p_RD_i[i] <-
      ilogit(
        alpha_RD+
          beta_RD_sex*sex[i]
      )
    
    p_DD_i[i] <-
      ilogit(
        alpha_DD+
          beta_DD_sex*sex[i]
      )
    
    # -------------------------------------------------------------------------
    # Initial movement state
    # -------------------------------------------------------------------------
    
    logit_p_disp_init[i] <-
      alpha_disp_init+
      beta_disp_adult*adult_entry[i]+
      beta_disp_init_sex*sex[i]
    
    p_disp_init[i] <-
      ilogit(logit_p_disp_init[i])
    
    disp[i,first[i]] ~
      dbern(p_disp_init[i])
    
    # -------------------------------------------------------------------------
    # Initial activity centre
    # -------------------------------------------------------------------------
    
    S[i,1,first[i]] ~
      dunif(grid_xmin,grid_xmax)
    
    S[i,2,first[i]] ~
      dunif(grid_ymin,grid_ymax)
    
    col_raw[i,first[i]] <-
      trunc(
        (S[i,1,first[i]]-grid_xmin)/
          cell_size
      )+
      1
    
    row_raw[i,first[i]] <-
      trunc(
        (grid_ymax-S[i,2,first[i]])/
          cell_size
      )+
      1
    
    col_S[i,first[i]] <-
      max(
        1,
        min(
          n_cols,
          col_raw[i,first[i]]
        )
      )
    
    row_S[i,first[i]] <-
      max(
        1,
        min(
          n_rows,
          row_raw[i,first[i]]
        )
      )
    
    in_bounds[i,first[i]] <-
      step(S[i,1,first[i]]-grid_xmin)*
      step(grid_xmax-S[i,1,first[i]])*
      step(S[i,2,first[i]]-grid_ymin)*
      step(grid_ymax-S[i,2,first[i]])
    
    habitat_here[i,first[i]] <-
      habitat_mat[
        row_S[i,first[i]],
        col_S[i,first[i]]
      ]
    
    SG_here[i,first[i]] <-
      SG_mat[
        row_S[i,first[i]],
        col_S[i,first[i]]
      ]
    
    zone_here[i,first[i]] <-
      zone_mat[
        row_S[i,first[i]],
        col_S[i,first[i]]
      ]
    
    state_ok[i,first[i]] ~
      dbern(
        in_bounds[i,first[i]]*
          habitat_here[i,first[i]]
      )
    
    # -------------------------------------------------------------------------
    # Detection at initial year
    # -------------------------------------------------------------------------
    
    for(j in 1:J[i,first[i]]){
      
      lp0[i,j,first[i]] <-
        alpha_p+
        beta_p_sex*sex[i]+
        beta_season[j]+
        beta_period[
          period_vec[first[i]]
        ]
      
      lambda0[i,j,first[i]] <-
        -log(
          1-
            ilogit(
              lp0[i,j,first[i]]
            )
        )
    }
    
    captureProb[
      i,
      1:J[i,first[i]],
      first[i]
    ] <-
      calc_capture_prob(
        S[i,1,first[i]],
        S[i,2,first[i]],
        X[1:R,1:2],
        sigma_i[i],
        lambda0[
          i,
          1:J[i,first[i]],
          first[i]
        ],
        H[
          i,
          1:J[i,first[i]],
          first[i]
        ]
      )
    
    for(j in 1:J[i,first[i]]){
      
      Ones[i,j,first[i]] ~
        dbern(
          captureProb[
            i,
            j,
            first[i]
          ]
        )
    }
    
    # =========================================================================
    # ANNUAL MOVEMENT
    # =========================================================================
    
    for(k in (first[i]+1):K[i]){
      
      # State governing k-1 -> k.
      move_state_idx[i,k] <-
        1+
        sex[i]+
        2*disp[i,k-1]
      
      sigma_move[i,k] <-
        sigma_move_state[
          move_state_idx[i,k]
        ]
      
      grid_lo_here[i,k] <-
        sigma_grid_lo_state[
          move_state_idx[i,k]
        ]
      
      grid_frac_here[i,k] <-
        sigma_grid_frac_state[
          move_state_idx[i,k]
        ]
      
      # -----------------------------------------------------------------------
      # Gaussian annual AC displacement
      # -----------------------------------------------------------------------
      
      eps[i,1:2,k] ~
        dmnorm(
          mean=eps_zero[1:2],
          cov=eps_cov[1:2,1:2]
        )
      
      S[i,1,k] <-
        S[i,1,k-1]+
        sigma_move[i,k]*
        eps[i,1,k]
      
      S[i,2,k] <-
        S[i,2,k-1]+
        sigma_move[i,k]*
        eps[i,2,k]
      
      moveDist[i,k-1] <-
        sigma_move[i,k]*
        sqrt(
          pow(eps[i,1,k],2)+
            pow(eps[i,2,k],2)
        )
      
      # -----------------------------------------------------------------------
      # Sex-specific movement-state transition
      # -----------------------------------------------------------------------
      
      p_disp[i,k] <-
        (1-disp[i,k-1])*
        p_RD_i[i]+
        disp[i,k-1]*
        p_DD_i[i]
      
      disp[i,k] ~
        dbern(p_disp[i,k])
      
      # -----------------------------------------------------------------------
      # Spatial state
      # -----------------------------------------------------------------------
      
      col_raw[i,k] <-
        trunc(
          (S[i,1,k]-grid_xmin)/
            cell_size
        )+
        1
      
      row_raw[i,k] <-
        trunc(
          (grid_ymax-S[i,2,k])/
            cell_size
        )+
        1
      
      col_S[i,k] <-
        max(
          1,
          min(
            n_cols,
            col_raw[i,k]
          )
        )
      
      row_S[i,k] <-
        max(
          1,
          min(
            n_rows,
            row_raw[i,k]
          )
        )
      
      in_bounds[i,k] <-
        step(S[i,1,k]-grid_xmin)*
        step(grid_xmax-S[i,1,k])*
        step(S[i,2,k]-grid_ymin)*
        step(grid_ymax-S[i,2,k])
      
      habitat_here[i,k] <-
        habitat_mat[
          row_S[i,k],
          col_S[i,k]
        ]
      
      SG_here[i,k] <-
        SG_mat[
          row_S[i,k],
          col_S[i,k]
        ]
      
      zone_here[i,k] <-
        zone_mat[
          row_S[i,k],
          col_S[i,k]
        ]
      
      state_ok[i,k] ~
        dbern(
          in_bounds[i,k]*
            habitat_here[i,k]
        )
      
      # -----------------------------------------------------------------------
      # Normalized social-group/peripheral resistance
      # -----------------------------------------------------------------------
      
      apply_social[i,k] <-
        equals(
          zone_here[i,k-1],
          1
        )
      
      q_same_lo[i,k] <-
        q_same_grid[
          grid_lo_here[i,k],
          row_S[i,k-1],
          col_S[i,k-1]
        ]
      
      q_same_hi[i,k] <-
        q_same_grid[
          grid_lo_here[i,k]+1,
          row_S[i,k-1],
          col_S[i,k-1]
        ]
      
      q_other_lo[i,k] <-
        q_other_grid[
          grid_lo_here[i,k],
          row_S[i,k-1],
          col_S[i,k-1]
        ]
      
      q_other_hi[i,k] <-
        q_other_grid[
          grid_lo_here[i,k]+1,
          row_S[i,k-1],
          col_S[i,k-1]
        ]
      
      q_per_lo[i,k] <-
        q_peripheral_grid[
          grid_lo_here[i,k],
          row_S[i,k-1],
          col_S[i,k-1]
        ]
      
      q_per_hi[i,k] <-
        q_peripheral_grid[
          grid_lo_here[i,k]+1,
          row_S[i,k-1],
          col_S[i,k-1]
        ]
      
      q_same_here[i,k] <-
        q_same_lo[i,k]+
        grid_frac_here[i,k]*
        (
          q_same_hi[i,k]-
            q_same_lo[i,k]
        )
      
      q_other_here[i,k] <-
        q_other_lo[i,k]+
        grid_frac_here[i,k]*
        (
          q_other_hi[i,k]-
            q_other_lo[i,k]
        )
      
      q_per_here[i,k] <-
        q_per_lo[i,k]+
        grid_frac_here[i,k]*
        (
          q_per_hi[i,k]-
            q_per_lo[i,k]
        )
      
      social_Z[i,k] <-
        q_same_here[i,k]+
        q_other_here[i,k]*
        sg_multiplier+
        q_per_here[i,k]*
        peripheral_multiplier
      
      dest_other_core[i,k] <-
        equals(
          zone_here[i,k],
          1
        )*
        (
          1-
            equals(
              SG_here[i,k],
              SG_here[i,k-1]
            )
        )
      
      dest_peripheral[i,k] <-
        equals(
          zone_here[i,k],
          2
        )
      
      log_R_dest[i,k] <-
        -beta_sg*
        dest_other_core[i,k]-
        beta_peripheral*
        dest_peripheral[i,k]
      
      log_social_correction[i,k] <-
        apply_social[i,k]*
        (
          log_R_dest[i,k]-
            log(social_Z[i,k])
        )
      
      social_lambda[i,k] <-
        SOCIAL_ZERO_CONST-
        log_social_correction[i,k]
      
      social_zero[i,k] ~
        dpois(
          social_lambda[i,k]
        )
      
      # -----------------------------------------------------------------------
      # Detection
      # -----------------------------------------------------------------------
      
      for(j in 1:J[i,k]){
        
        lp0[i,j,k] <-
          alpha_p+
          beta_p_sex*sex[i]+
          beta_season[j]+
          beta_period[
            period_vec[k]
          ]
        
        lambda0[i,j,k] <-
          -log(
            1-
              ilogit(
                lp0[i,j,k]
              )
          )
      }
      
      captureProb[
        i,
        1:J[i,k],
        k
      ] <-
        calc_capture_prob(
          S[i,1,k],
          S[i,2,k],
          X[1:R,1:2],
          sigma_i[i],
          lambda0[
            i,
            1:J[i,k],
            k
          ],
          H[
            i,
            1:J[i,k],
            k
          ]
        )
      
      for(j in 1:J[i,k]){
        
        Ones[i,j,k] ~
          dbern(
            captureProb[i,j,k]
          )
      }
    }
  }
})

# =============================================================================
# CONSTANTS + DATA
# =============================================================================

consts <- list(
  nind=nind,
  R=R,
  
  K=as.integer(K),
  J=J,
  first=as.integer(first),
  
  X=X,
  H=H,
  
  n_periods=n_periods,
  period_vec=period_vec,
  
  adult_entry=adult_entry,
  
  grid_xmin=grid_xmin,
  grid_xmax=grid_xmax,
  grid_ymin=grid_ymin,
  grid_ymax=grid_ymax,
  
  cell_size=cell_size,
  n_rows=n_rows,
  n_cols=n_cols,
  
  eps_zero=eps_zero,
  eps_cov=eps_cov,
  
  MOVE_MEAN_FACTOR=MOVE_MEAN_FACTOR,
  MOVE_PRIOR_LOGMEAN=MOVE_PRIOR_LOGMEAN,
  
  N_SIGMA_GRID=N_SIGMA_GRID,
  LOG_SIGMA_MIN=LOG_SIGMA_MIN,
  LOG_SIGMA_MAX=LOG_SIGMA_MAX,
  LOG_SIGMA_STEP=LOG_SIGMA_STEP,
  
  SOCIAL_ZERO_CONST=SOCIAL_ZERO_CONST
)

# Dynamically indexed arrays MUST remain data.
data_list <- list(
  Ones=array(1L,dim(H)),
  sex=sex_data,
  
  state_ok=matrix(1L,nind,n_prim),
  social_zero=matrix(0L,nind,n_prim),
  move_support_ok=rep(1L,4),
  
  habitat_mat=habitat_mat,
  SG_mat=SG_mat,
  zone_mat=zone_mat,
  
  q_same_grid=q_same_grid,
  q_other_grid=q_other_grid,
  q_peripheral_grid=q_peripheral_grid
)

# =============================================================================
# STRUCTURAL CHECKS
# =============================================================================

code_txt <- paste(deparse(code_V6c),collapse=" ")

if(!grepl("dmnorm",code_txt))
  stop("Gaussian movement missing.")

if(grepl("dmvt",code_txt))
  stop("Student-t movement should not occur in V6c.")

if(!grepl("beta_RD_sex",code_txt))
  stop("Sex-specific R -> D process missing.")

if(!grepl("beta_DD_sex",code_txt))
  stop("Sex-specific D -> D process missing.")

if(!grepl("beta_disp_init_sex",code_txt))
  stop("Sex effect on initial movement state missing.")

if(grepl("move_re",code_txt))
  stop("Individual movement random effect should be absent.")

if(!grepl("social_Z",code_txt))
  stop("Normalized landscape resistance missing.")

cat("\nV6c structural checks: PASS\n")

# =============================================================================
# BUILD MODEL
# =============================================================================

message("\nBuilding V6c...")

build_time_V6c <- system.time(
  
  model_V6c <- nimbleModel(
    code_V6c,
    constants=consts,
    data=data_list,
    inits=inits[[1]],
    
    dimensions=list(
      Ones=dim(H),
      disp=c(nind,n_prim),
      state_ok=c(nind,n_prim),
      social_zero=c(nind,n_prim),
      move_support_ok=4
    ),
    
    check=FALSE,
    calculate=FALSE
  )
)

cat("\nModel build time:\n")
print(build_time_V6c)

lp <- model_V6c$calculate()

cat("\nInitial log probability:",lp,"\n")

if(!is.finite(lp)){
  
  print(model_V6c$initializeInfo())
  
  stop(
    "V6c initial log probability is not finite."
  )
}

# =============================================================================
# MONITORS
# =============================================================================

core_monitors <- c(
  # movement scale
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_disp",
  
  # initial state
  "alpha_disp_init",
  "beta_disp_adult",
  "beta_disp_init_sex",
  
  # transitions
  "alpha_RD",
  "beta_RD_sex",
  "alpha_DD",
  "beta_DD_sex",
  
  "p_RD_female",
  "p_RD_male",
  "p_DD_female",
  "p_DD_male",
  
  "p_RR_female",
  "p_RR_male",
  "p_DR_female",
  "p_DR_male",
  
  "p_disp_init_young_female",
  "p_disp_init_young_male",
  "p_disp_init_adult_female",
  "p_disp_init_adult_male",
  
  # movement summaries
  "move_multiplier_male",
  "move_multiplier_disp",
  
  "sigma_move_female_resident",
  "sigma_move_male_resident",
  "sigma_move_female_disperser",
  "sigma_move_male_disperser",
  
  "mean_move_female_resident",
  "mean_move_male_resident",
  "mean_move_female_disperser",
  "mean_move_male_disperser",
  
  # detection
  "alpha_p",
  "beta_p_sex",
  "alpha_logsigma",
  "beta_sigma_sex",
  
  "p0_female",
  "p0_male",
  "sigma_female",
  "sigma_male",
  
  # landscape
  "beta_sg",
  "beta_peripheral",
  "sg_multiplier",
  "peripheral_multiplier",
  
  "psi_sex"
)

monitors <- core_monitors

if(length(unknown_sex_idx))
  monitors <- c(
    monitors,
    paste0("sex[",unknown_sex_idx,"]")
  )

if(SAVE_LATENT_STATES)
  monitors <- c(monitors,disp_nodes)

# =============================================================================
# MCMC CONFIGURATION
# =============================================================================

message("\nConfiguring V6c MCMC...")

config_V6c <- configureMCMC(
  model_V6c,
  monitors=unique(monitors),
  thin=THIN
)

move_global <- c(
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_disp"
)

initial_state_global <- c(
  "alpha_disp_init",
  "beta_disp_adult",
  "beta_disp_init_sex"
)

transition_global <- c(
  "alpha_RD",
  "beta_RD_sex",
  "alpha_DD",
  "beta_DD_sex"
)

detect_p_global <- c(
  "alpha_p",
  "beta_p_sex"
)

detect_sigma_global <- c(
  "alpha_logsigma",
  "beta_sigma_sex"
)

landscape_global <- c(
  "beta_sg",
  "beta_peripheral"
)

config_V6c$removeSamplers(move_global,print=FALSE)
config_V6c$addSampler(target=move_global,type="AF_slice")

config_V6c$removeSamplers(initial_state_global,print=FALSE)
config_V6c$addSampler(target=initial_state_global,type="AF_slice")

config_V6c$removeSamplers(transition_global,print=FALSE)
config_V6c$addSampler(target=transition_global,type="AF_slice")

config_V6c$removeSamplers(detect_p_global,print=FALSE)
config_V6c$addSampler(target=detect_p_global,type="AF_slice")

config_V6c$removeSamplers(detect_sigma_global,print=FALSE)
config_V6c$addSampler(target=detect_sigma_global,type="AF_slice")

config_V6c$removeSamplers(landscape_global,print=FALSE)
config_V6c$addSampler(target=landscape_global,type="AF_slice")

cat("\nCustom global blocks:\n")
cat("movement:",paste(move_global,collapse=", "),"\n")
cat("initial state:",paste(initial_state_global,collapse=", "),"\n")
cat("transitions:",paste(transition_global,collapse=", "),"\n")
cat("detection p:",paste(detect_p_global,collapse=", "),"\n")
cat("detection sigma:",paste(detect_sigma_global,collapse=", "),"\n")
cat("landscape:",paste(landscape_global,collapse=", "),"\n")
cat("latent intervals monitored:",if(SAVE_LATENT_STATES) length(disp_nodes) else 0,"\n")

# =============================================================================
# BUILD MCMC
# =============================================================================

build_mcmc_time_V6c <- system.time(
  Rmcmc_V6c <- buildMCMC(config_V6c)
)

cat("\nMCMC build time:\n")
print(build_mcmc_time_V6c)

# =============================================================================
# COMPILE
# =============================================================================

message("\nCompiling model + MCMC together...")

compile_time_V6c <- system.time(
  
  compiled_V6c <- compileNimble(
    model_V6c,
    Rmcmc_V6c,
    resetFunctions=TRUE
  )
)

cat("\nCompile time:\n")
print(compile_time_V6c)

cModel_V6c <- compiled_V6c[[1]]
cMCMC_V6c <- compiled_V6c[[2]]

# =============================================================================
# RUN
# =============================================================================

message("\nRunning V6c overnight...")

runtime_V6c <- system.time(
  
  samples_V6c <- runMCMC(
    cMCMC_V6c,
    
    niter=NITER,
    nburnin=NBURN,
    nchains=NCHAINS,
    
    inits=inits,
    
    samplesAsCodaMCMC=TRUE,
    progressBar=TRUE,
    
    setSeed=3451:(3451+NCHAINS-1L)
  )
)

cat("\nRuntime:\n")
print(runtime_V6c)

# =============================================================================
# CORE DIAGNOSTICS
# =============================================================================

core_pars <- c(
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_disp",
  
  "alpha_disp_init",
  "beta_disp_adult",
  "beta_disp_init_sex",
  
  "alpha_RD",
  "beta_RD_sex",
  "alpha_DD",
  "beta_DD_sex",
  
  "p_RD_female",
  "p_RD_male",
  "p_DD_female",
  "p_DD_male",
  
  "sigma_move_female_resident",
  "sigma_move_male_resident",
  "sigma_move_female_disperser",
  "sigma_move_male_disperser",
  
  "mean_move_female_resident",
  "mean_move_male_resident",
  "mean_move_female_disperser",
  "mean_move_male_disperser",
  
  "alpha_p",
  "beta_p_sex",
  "alpha_logsigma",
  "beta_sigma_sex",
  
  "beta_sg",
  "beta_peripheral"
)

cat("\n============================================================\n")
cat("V6c CORE POSTERIOR SUMMARY\n")
cat("============================================================\n")

print(
  MCMCsummary(
    samples_V6c,
    params=core_pars
  )
)

cat("\nGelman-Rubin:\n")

print(
  gelman.diag(
    samples_V6c[,core_pars],
    multivariate=FALSE
  )
)

cat("\nEffective sample sizes:\n")

print(
  effectiveSize(
    samples_V6c[,core_pars]
  )
)

# =============================================================================
# POSTERIOR LATENT MOVEMENT STATES
# =============================================================================

posterior_means <-
  Reduce(
    "+",
    lapply(
      samples_V6c,
      function(x) colMeans(as.matrix(x))
    )
  )/
  length(samples_V6c)

if(SAVE_LATENT_STATES){
  
  disp_summary <- disp_index %>%
    mutate(
      p_disperser=
        unname(
          posterior_means[node]
        )
    )
  
  # ---------------------------------------------------------------------------
  # Posterior sex probability
  # ---------------------------------------------------------------------------
  
  p_male <- as.numeric(sex_data)
  
  if(length(unknown_sex_idx)){
    
    sex_nodes <-
      paste0(
        "sex[",
        unknown_sex_idx,
        "]"
      )
    
    p_male[unknown_sex_idx] <-
      unname(
        posterior_means[
          sex_nodes
        ]
      )
  }
  
  sex_summary <- tibble(
    model_i=seq_len(nind),
    tattoo=ids,
    sex_known=!is.na(sex_data),
    known_sex=sex_data,
    p_male=p_male
  )
  
  # ---------------------------------------------------------------------------
  # Individual movement histories
  # ---------------------------------------------------------------------------
  
  individual_movement_summary <- disp_summary %>%
    arrange(model_i,from_primary) %>%
    group_by(model_i,tattoo) %>%
    summarise(
      n_intervals=n(),
      
      mean_p_disperser=
        mean(p_disperser),
      
      max_p_disperser=
        max(p_disperser),
      
      first_p_disperser=
        first(p_disperser),
      
      last_p_disperser=
        last(p_disperser),
      
      n_intervals_p50=
        sum(p_disperser>=.50),
      
      n_intervals_p80=
        sum(p_disperser>=.80),
      
      .groups="drop"
    ) %>%
    left_join(
      sex_summary,
      by=c("model_i","tattoo")
    ) %>%
    mutate(
      movement_pattern=case_when(
        
        max_p_disperser<.20 ~
          "strongly_resident",
        
        mean_p_disperser>=.70 ~
          "persistent_high_mobility",
        
        first_p_disperser>=.70 &
          last_p_disperser<.30 ~
          "disperser_then_settled",
        
        first_p_disperser<.30 &
          last_p_disperser>=.70 ~
          "became_disperser",
        
        n_intervals_p80>=1 ~
          "episodic_disperser",
        
        TRUE ~
          "mixed_or_uncertain"
      )
    )
  
  # ---------------------------------------------------------------------------
  # Expected sex composition BY MOVEMENT STATE
  #
  # This propagates uncertainty in latent movement state and unknown sex.
  # It is descriptive; beta_RD_sex etc are the direct inferential tests.
  # ---------------------------------------------------------------------------
  
  interval_sex <- disp_summary %>%
    left_join(
      sex_summary %>%
        select(model_i,p_male,sex_known,known_sex),
      by="model_i"
    )
  
  expected_resident_intervals <-
    sum(
      1-interval_sex$p_disperser
    )
  
  expected_disperser_intervals <-
    sum(
      interval_sex$p_disperser
    )
  
  expected_male_resident <-
    sum(
      (
        1-interval_sex$p_disperser
      )*
        interval_sex$p_male
    )
  
  expected_male_disperser <-
    sum(
      interval_sex$p_disperser*
        interval_sex$p_male
    )
  
  expected_sex_by_state <- tibble(
    state=c("resident","disperser"),
    
    expected_intervals=c(
      expected_resident_intervals,
      expected_disperser_intervals
    ),
    
    expected_male_intervals=c(
      expected_male_resident,
      expected_male_disperser
    )
  ) %>%
    mutate(
      expected_male_proportion=
        expected_male_intervals/
        expected_intervals,
      
      expected_female_proportion=
        1-
        expected_male_proportion
    )
  
  # Known-sex-only descriptive sensitivity.
  known_interval_sex <- interval_sex %>%
    filter(sex_known)
  
  known_expected_resident <-
    sum(
      1-known_interval_sex$p_disperser
    )
  
  known_expected_disperser <-
    sum(
      known_interval_sex$p_disperser
    )
  
  known_expected_male_resident <-
    sum(
      (
        1-known_interval_sex$p_disperser
      )*
        known_interval_sex$known_sex
    )
  
  known_expected_male_disperser <-
    sum(
      known_interval_sex$p_disperser*
        known_interval_sex$known_sex
    )
  
  known_sex_by_state <- tibble(
    state=c("resident","disperser"),
    
    expected_intervals=c(
      known_expected_resident,
      known_expected_disperser
    ),
    
    expected_male_intervals=c(
      known_expected_male_resident,
      known_expected_male_disperser
    )
  ) %>%
    mutate(
      expected_male_proportion=
        expected_male_intervals/
        expected_intervals,
      
      expected_female_proportion=
        1-
        expected_male_proportion
    )
  
  cat("\n============================================================\n")
  cat("POSTERIOR MOVEMENT-STATE SUMMARY\n")
  cat("============================================================\n")
  
  cat(
    "Intervals P(disperser)>=0.50:",
    sum(disp_summary$p_disperser>=.50),
    "of",
    nrow(disp_summary),
    "\n"
  )
  
  cat(
    "Intervals P(disperser)>=0.80:",
    sum(disp_summary$p_disperser>=.80),
    "\n"
  )
  
  cat(
    "Individuals with >=1 interval P(disperser)>=0.80:",
    sum(
      individual_movement_summary$n_intervals_p80>=1
    ),
    "\n"
  )
  
  cat("\nExpected sex composition by movement state:\n")
  print(expected_sex_by_state)
  
  cat("\nKnown-sex-only composition:\n")
  print(known_sex_by_state)
  
  cat("\nPosterior movement-pattern counts:\n")
  
  print(
    individual_movement_summary %>%
      count(movement_pattern)
  )
  
} else {
  
  disp_summary <- NULL
  sex_summary <- NULL
  individual_movement_summary <- NULL
  expected_sex_by_state <- NULL
  known_sex_by_state <- NULL
}

# =============================================================================
# SAVE
# =============================================================================

result_file <- paste0(
  "results/",
  "RD_SCR_V6c_WIDE_SUPPORT_SEX_TRANSITIONS_",
  nind,
  "_badgers.rds"
)

saveRDS(
  list(
    samples=samples_V6c,
    
    runtime=runtime_V6c,
    build_time=build_time_V6c,
    build_mcmc_time=build_mcmc_time_V6c,
    compile_time=compile_time_V6c,
    
    ids=ids,
    sex_data=sex_data,
    entry_group=entry_group,
    adult_entry=adult_entry,
    
    first=first,
    K=K,
    n_live_years=n_live_years,
    years=years,
    
    detectors=detectors,
    det_audit=det_audit,
    
    annual_obs=annual_obs,
    
    disp_index=disp_index,
    disp_summary=disp_summary,
    
    sex_summary=sex_summary,
    expected_sex_by_state=expected_sex_by_state,
    known_sex_by_state=known_sex_by_state,
    
    individual_movement_summary=
      individual_movement_summary,
    
    settings=list(
      model=
        "V6c_wide_support_sex_specific_resident_disperser",
      
      analysis_end_year=
        MAX_YEAR,
      
      min_live_years=
        MIN_LIVE_YEARS,
      
      sample_n=
        nind,
      
      max_adult_entry=
        MAX_ADULT_ENTRY,
      
      niter=
        NITER,
      
      nburn=
        NBURN,
      
      nchains=
        NCHAINS,
      
      thin=
        THIN,
      
      movement_kernel=
        "bivariate_Gaussian",
      
      movement_support_m=
        c(
          exp(LOG_SIGMA_MIN),
          exp(LOG_SIGMA_MAX)
        ),
      
      sigma_grid=
        SIGMA_GRID,
      
      activity_centres=
        "dynamic_annual",
      
      movement_process_window=
        "first_live_to_last_live",
      
      latent_state=
        "resident_vs_disperser",
      
      state_interpretation=
        "time_varying_movement_mode_not_fixed_individual_type",
      
      disperser_identification=
        "positive_movement_scale_increment",
      
      sex_effects=
        c(
          "movement_scale_given_state",
          "initial_disperser_probability",
          "resident_to_disperser_transition",
          "disperser_persistence",
          "detection",
          "detection_scale"
        ),
      
      adult_entry_effect=
        "initial_disperser_probability_only",
      
      survival=
        "conditioned_out",
      
      individual_movement_random_effect=
        FALSE,
      
      sg_model=
        "dynamic_normalized_core_SG_plus_peripheral",
      
      latent_states_saved=
        SAVE_LATENT_STATES,
      
      disease_effects=
        "none_in_V6c",
      
      data_source=
        "PostgreSQL/Supabase -> DataPrep.R -> fixed RDS snapshots",
      
      encounter_file=
        encounter_file,
      
      individual_file=
        individual_file
    ),
    
    spatial_file=spatial_file,
    q_cache_file=q_cache_file
  ),
  
  result_file
)

cat("\n============================================================\n")
cat("V6c COMPLETE\n")
cat("============================================================\n")
cat("Saved:",result_file,"\n")

cat("\nTIMINGS\n")
cat("Model build:\n"); print(build_time_V6c)
cat("MCMC build:\n"); print(build_mcmc_time_V6c)
cat("Compile:\n"); print(compile_time_V6c)
cat("MCMC runtime:\n"); print(runtime_V6c)

# 1. Main posterior table
MCMCsummary(samples_V6c,params=core_pars)

# 2. Chain agreement
gelman.diag(samples_V6c[,core_pars],multivariate=FALSE)

# 3. Effective sample sizes
effectiveSize(samples_V6c[,core_pars])

# 4. Biological state summaries
expected_sex_by_state
known_sex_by_state

individual_movement_summary %>%
  count(movement_pattern)

disp_summary %>%
  summarise(
    n_intervals=n(),
    n_p50=sum(p_disperser>=.5),
    n_p80=sum(p_disperser>=.8),
    mean_p=mean(p_disperser),
    median_p=median(p_disperser)
  )

quantile(
  annual_obs$observed_move,
  probs=c(0,.25,.5,.75,.9,.95,.99,1),
  na.rm=TRUE
)

cat("Moves >250 m:",sum(annual_obs$observed_move>250),"\n")
cat("Moves >500 m:",sum(annual_obs$observed_move>500),"\n")
cat("Moves >1000 m:",sum(annual_obs$observed_move>1000),"\n")


individual_movement_summary %>%
  count(movement_pattern,n_intervals) %>%
  arrange(movement_pattern,n_intervals)

individual_movement_summary %>%
  filter(movement_pattern=="persistent_high_mobility") %>%
  select(tattoo,n_intervals,mean_p_disperser,max_p_disperser,
         first_p_disperser,last_p_disperser,p_male) %>%
  arrange(desc(n_intervals))



individual_movement_summary <- disp_summary %>%
  arrange(model_i,from_primary) %>%
  group_by(model_i,tattoo) %>%
  summarise(
    n_intervals=n(),
    mean_p_disperser=mean(p_disperser),
    max_p_disperser=max(p_disperser),
    first_p_disperser=first(p_disperser),
    last_p_disperser=last(p_disperser),
    n_intervals_p50=sum(p_disperser>=.50),
    n_intervals_p80=sum(p_disperser>=.80),
    .groups="drop"
  ) %>%
  left_join(sex_summary,by=c("model_i","tattoo")) %>%
  mutate(
    movement_pattern=case_when(
      max_p_disperser<.20 ~ "strongly_resident",
      
      n_intervals==1 & max_p_disperser>=.80 ~
        "single_high_mobility_event",
      
      n_intervals>=3 & mean_p_disperser>=.70 &
        n_intervals_p80/n_intervals>=.67 ~
        "persistent_high_mobility",
      
      n_intervals>=2 & first_p_disperser>=.70 &
        last_p_disperser<.30 ~
        "disperser_then_settled",
      
      n_intervals>=2 & first_p_disperser<.30 &
        last_p_disperser>=.70 ~
        "became_disperser",
      
      n_intervals_p80>=1 ~
        "episodic_disperser",
      
      TRUE ~
        "mixed_or_uncertain"
    )
  )

individual_movement_summary %>%
  count(movement_pattern)


annual_obs %>%
  count(year_gap)

annual_obs %>%
  group_by(year_gap) %>%
  summarise(
    n=n(),
    zero=sum(observed_move==0),
    p_zero=mean(observed_move==0),
    median=median(observed_move),
    p75=quantile(observed_move,.75),
    p90=quantile(observed_move,.90),
    p95=quantile(observed_move,.95),
    max=max(observed_move),
    .groups="drop"
  )

annual_obs %>%
  filter(year_gap==1) %>%
  summarise(
    n=n(),
    zero=sum(observed_move==0),
    p_zero=mean(observed_move==0),
    median=median(observed_move),
    p75=quantile(observed_move,.75),
    p90=quantile(observed_move,.90),
    p95=quantile(observed_move,.95),
    p99=quantile(observed_move,.99),
    max=max(observed_move)
  )


obs_sett_change <- annual_obs %>%
  mutate(
    consecutive=year_gap==1,
    moved_250=observed_move>250,
    moved_500=observed_move>500,
    moved_1000=observed_move>1000
  )

obs_sett_change %>%
  summarise(
    n=n(),
    consecutive=sum(consecutive),
    moved_250=sum(moved_250),
    moved_500=sum(moved_500),
    moved_1000=sum(moved_1000)
  )




disp_validation <- disp_summary %>%
  left_join(
    annual_obs %>%
      transmute(
        tattoo,
        from_primary=previous_primary,
        to_primary=primary,
        year_gap,
        observed_move
      ),
    by=c("tattoo","from_primary","to_primary")
  ) %>%
  filter(!is.na(observed_move))

disp_validation %>%
  mutate(
    move_class=case_when(
      observed_move==0 ~ "0 m",
      observed_move<=250 ~ "1-250 m",
      observed_move<=500 ~ "251-500 m",
      observed_move<=1000 ~ "501-1000 m",
      TRUE ~ ">1000 m"
    )
  ) %>%
  group_by(move_class) %>%
  summarise(
    n=n(),
    mean_p_disperser=mean(p_disperser),
    median_p_disperser=median(p_disperser),
    p80=sum(p_disperser>=.8)/n(),
    .groups="drop"
  )
