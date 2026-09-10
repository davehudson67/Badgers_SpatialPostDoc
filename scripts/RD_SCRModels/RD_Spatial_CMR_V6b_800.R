# =============================================================================
# WOODCHESTER SPATIAL CMR V6b
# CLEAN RESIDENT <-> DISPERSER MOVEMENT MODEL
#
# PURPOSE:
#   Establish a well-identified movement phenotype BEFORE adding infection.
#
# KEY CHANGES FROM V6a:
#   - Badgers require >=2 observed live years
#   - Movement process stops at LAST observed live year
#   - Missing years BETWEEN live observations remain in the movement process
#   - No long latent post-last-capture movement tails
#   - No individual movement random effect
#   - Gaussian resident movement
#   - Gaussian disperser movement with sigma_D > sigma_R
#   - Resident <-> disperser first-order Markov process retained
#   - Adult entry affects INITIAL disperser probability only
#   - Dynamic annual activity centres retained
#   - SG/peripheral normalized landscape resistance retained
#   - Spatial detection process retained
#   - Survival deliberately conditioned out in V6b
#
# V6b is a movement-development model, NOT the definitive survival model.
# =============================================================================

library(tidyverse); library(lubridate); library(nimble); library(coda); library(MCMCvis); library(sf)

set.seed(123)

# =============================================================================
# OPTIONS
# =============================================================================

MAX_YEAR <- 2025L                 # use complete calendar years only
MIN_LIVE_YEARS <- 2L

SAMPLE_N <- 500L
MAX_ADULT_ENTRY <- 250L

NITER <- 16000
NBURN <- 4000
NCHAINS <- 2
THIN <- 1

SAVE_LATENT_STATES <- FALSE       # FALSE for overnight global-parameter test

SIGMA_MOVE_INIT <- 55             # female resident movement scale
MOVE_PRIOR_LOGMEAN <- log(SIGMA_MOVE_INIT)

# Gaussian movement: mean radial distance = sigma * sqrt(pi/2)
MOVE_MEAN_FACTOR <- sqrt(pi/2)

# Wider than V6a because disperser state may genuinely be broad.
N_SIGMA_GRID <- 31L
LOG_SIGMA_MIN <- log(10)
LOG_SIGMA_MAX <- log(1200)
LOG_SIGMA_STEP <- (LOG_SIGMA_MAX-LOG_SIGMA_MIN)/(N_SIGMA_GRID-1L)
SIGMA_GRID <- exp(seq(LOG_SIGMA_MIN,LOG_SIGMA_MAX,length.out=N_SIGMA_GRID))

SOCIAL_ZERO_CONST <- 50

cat("\n============================================================\n")
cat("V6b CLEAN RESIDENT <-> DISPERSER MODEL\n")
cat("Gaussian movement states | dynamic annual activity centres\n")
cat("Years <=",MAX_YEAR,"\n")
cat("Target sample:",SAMPLE_N,"| max adult-entry:",MAX_ADULT_ENTRY,"\n")
cat("Minimum observed live years:",MIN_LIVE_YEARS,"\n")
cat("Iterations:",NITER,"| burn:",NBURN,"| chains:",NCHAINS,"\n")
cat("============================================================\n\n")

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

dir.create("results",showWarnings=FALSE)

# =============================================================================
# SETT CLEANING
# =============================================================================

sett_aliases <- c(
  "\\bCHESTNUT\\b"="CHESNUT",
  "\\bJACKS\\b"="JACKSMIREY",
  "\\bGRAVEL\\b"="GRAVELPIT",
  "\\bBUCKHOLE\\b"="BUCKHOLT",
  "\\bTOPSETT\\b"="TOP",
  "\\bFOXCUB\\b"="FOX",
  "\\bGULLEY\\b"="GULLY",
  "\\bBLACKBERRY\\b"="BRAMBLE",
  "\\bBOC\\b"="BOG",
  "\\bCEDARBANK\\b"="CEDAR",
  "\\bCLAYTRAP\\b"="CLAY",
  "\\bCLIFF\\b"="CLIFFFACE",
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
# ENCOUNTER DATA
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

cat("\nAnalysis years:",min(years),"-",max(years),
    "|",n_prim,"primary years\n")

# =============================================================================
# INDIVIDUAL DEMOGRAPHICS
# =============================================================================

demog <- individuals %>%
  transmute(
    individual_id,
    tattoo,
    age_fc=as.character(age_fc),
    entry_group=case_when(
      age_fc %in% c("Cub","Yearling") ~ 1L,
      age_fc=="Adult" ~ 2L,
      TRUE ~ NA_integer_
    )
  )

sex_lookup <- individuals %>%
  transmute(
    individual_id,
    tattoo,
    sex_raw=as.character(sex)
  ) %>%
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

# Only true live encounters define detector observations.
# Multiple live captures in same individual/year/quarter:
# prefer non-modal location, then latest live record.

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

cat("\nMovement-informative eligible badgers:",nrow(eligible),"\n")
cat("  adult-entry:",sum(eligible$entry_group==2L),"\n")
cat("  young-entry:",sum(eligible$entry_group==1L),"\n")

# =============================================================================
# ADULT-ENRICHED SAMPLE
# =============================================================================

# ---- adult-enriched sample ---------------------------------------------------
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

eligible <- bind_rows(adult_sample,young_sample) %>% slice_sample(prop=1)

if(nrow(eligible)<SAMPLE_N)
  warning("Fewer movement-informative badgers than SAMPLE_N.")

cat("\nSelected sample:\n")
cat("  total:",nrow(eligible),"\n")
cat("  adult-entry:",sum(eligible$entry_group==2L),"\n")
cat("  young-entry:",sum(eligible$entry_group==1L),"\n")
cat("  median observed live years:",median(eligible$n_live_years),"\n")

ids <- eligible$tattoo
nind <- length(ids)

live <- live %>% filter(tattoo %in% ids)

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
  left_join(
    detectors %>% select(Sett_Clean,detector),
    by="Sett_Clean"
  )

det_audit <- detectors %>%
  mutate(
    col_R=floor((x-grid_xmin)/cell_size)+1L,
    row_R=floor((grid_ymax-y)/cell_size)+1L,
    in_bounds=col_R>=1L & col_R<=n_cols &
      row_R>=1L & row_R<=n_rows
  )

if(any(!det_audit$in_bounds))
  stop("Used detector outside spatial grid.")

cat("Spatial detectors used:",R,"\n")

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

# IMPORTANT V6b CHANGE:
# K is LAST OBSERVED LIVE PRIMARY YEAR, not end of study.
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

# All four quarters are modelled for COMPLETE calendar years.
J <- matrix(n_sec,nind,n_prim)

# =============================================================================
# REORDER BY HISTORY LENGTH
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

cat("\nFinal V6b sample:\n")
cat("  nind:",nind,"\n")
cat("  observed live years:",sum(n_live_years),"\n")
cat("  movement intervals:",sum(K-first),"\n")
cat("  adult-entry:",sum(adult_entry==1L),"\n")
cat("  young-entry:",sum(adult_entry==0L),"\n")
cat("  known sex:",sum(!is.na(sex_data)),"\n")
cat("  unknown sex:",length(unknown_sex_idx),"\n")
cat("  maximum movement-history span:",max(K-first),"years\n")

# =============================================================================
# LATENT-STATE INDEX
# =============================================================================

# disp[i,k] describes movement during interval k -> k+1.
# Only those states are scientifically interesting for summaries.

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

cat("  informative latent movement states:",length(disp_nodes),"\n")

# =============================================================================
# INITIAL VALUES
# =============================================================================

make_inits <- function(chain=1L){
  
  S_init <- array(NA_real_,c(nind,2,n_prim))
  eps_init <- array(NA_real_,c(nind,2,n_prim))
  disp_init <- matrix(NA_integer_,nind,n_prim)
  
  alpha_logmove_init <- log(SIGMA_MOVE_INIT)+rnorm(1,0,.03)
  beta_move_sex_init <- log(1.40)+rnorm(1,0,.03)
  
  # Start disperser scale roughly 4-6 x resident.
  beta_move_disp_init <- log(5)+rnorm(1,0,.05)
  
  sex_init <- sex_data
  
  if(length(unknown_sex_idx))
    sex_init[unknown_sex_idx] <-
    rbinom(length(unknown_sex_idx),1,.47)
  
  # Different sensible starting thresholds across chains.
  disp_threshold <- if(chain%%2L==1L) 180 else 300
  
  for(i in seq_len(nind)){
    
    d <- live %>%
      filter(tattoo==ids[i]) %>%
      arrange(primary,trap_season,capture_date) %>%
      group_by(primary) %>%
      slice(1) %>%
      ungroup() %>%
      select(primary,x,y)
    
    xy <- matrix(NA_real_,n_prim,2)
    
    # Start every missing year at previous known/initialized valid sett.
    for(k in first[i]:K[i]){
      
      dk <- d %>%
        filter(primary==k)
      
      if(nrow(dk)){
        xy[k,] <- c(dk$x[1],dk$y[1])
      } else if(k>first[i]){
        xy[k,] <- xy[k-1,]
      }
    }
    
    S_init[i,,first[i]] <- xy[first[i],]
    
    # Initialize latent movement state from displacement magnitude.
    # This is INITIALIZATION ONLY; states are inferred by the model.
    for(k in first[i]:(K[i]-1L)){
      
      dd <- sqrt(
        (xy[k+1L,1]-xy[k,1])^2+
          (xy[k+1L,2]-xy[k,2])^2
      )
      
      disp_init[i,k] <- as.integer(dd>=disp_threshold)
    }
    
    # Terminal state is not used to explain another movement interval,
    # but is required by the current simple Markov implementation.
    disp_init[i,K[i]] <- disp_init[i,K[i]-1L]
    
    # Non-centred Gaussian movement innovations.
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
    
    alpha_disp_init=qlogis(.10)+rnorm(1,0,.08),
    beta_disp_adult=rnorm(1,.30,.10),
    
    p_RD=runif(1,.05,.15),
    p_DD=runif(1,.45,.70),
    
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
    
    sex_i <- if(is.na(sex_data[i]))
      init$sex[i]
    else
      sex_data[i]
    
    col <- floor((sx-grid_xmin)/cell_size)+1L
    row <- floor((grid_ymax-sy)/cell_size)+1L
    
    in_bounds <- col>=1L && col<=n_cols &&
      row>=1L && row<=n_rows
    
    habitat <- if(in_bounds)
      habitat_mat[row,col]
    else
      0L
    
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
      
      habitat <- if(in_bounds)
        habitat_mat[row,col]
      else
        0L
      
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
  
  if(length(bad))
    bind_rows(bad)
  else
    tibble()
}

init_audit <- audit_init(inits[[1]])

cat("\nInitialization spatial audit:\n")
cat("  invalid states:",nrow(init_audit),"\n")

if(nrow(init_audit)){
  print(init_audit)
  stop("Initial spatial reconstruction contains invalid habitat states.")
}

cat("  PASS\n")

# =============================================================================
# GAUSSIAN LANDSCAPE NORMALIZATION GRID
# =============================================================================

cat("\nPreparing GAUSSIAN landscape-normalization arrays...\n")

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
    "V6b_qgrid_GAUSSIAN_",
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
  
  cat("Loading cached Gaussian normalization grid:\n")
  cat(" ",q_cache_file,"\n")
  
  q_same_grid <- qcache$q_same
  q_other_grid <- qcache$q_other
  q_peripheral_grid <- qcache$q_peripheral
  
} else {
  
  cat("No matching Gaussian cache; computing once...\n")
  
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
      
      per <-
        grid_df$zone[land_idx]==2L
      
      for(ss in seq_len(ns)){
        
        sig <- SIGMA_GRID[ss]
        
        # IMPORTANT:
        # Gaussian movement kernel for V6b.
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
  
  if(is.na(nc_detected))
    nc_detected <- 1L
  
  ncores <- max(1L,min(8L,nc_detected-1L))
  nchunks <- min(ncores,length(core_idx))
  
  if(nchunks==1L){
    
    chunks <- list(core_idx)
    
  } else {
    
    chunks <- split(
      core_idx,
      cut(
        seq_along(core_idx),
        breaks=nchunks,
        labels=FALSE
      )
    )
  }
  
  cat(
    "Computing",length(core_idx),
    "core origins x",N_SIGMA_GRID,
    "sigma knots using",ncores,"core(s)...\n"
  )
  
  q_time <- system.time({
    
    if(.Platform$OS.type!="windows" && ncores>1L){
      
      q_parts <- parallel::mclapply(
        chunks,
        calc_q_chunk,
        mc.cores=ncores
      )
      
    } else {
      
      q_parts <- lapply(
        chunks,
        calc_q_chunk
      )
    }
  })
  
  cat("Normalization-grid calculation time:\n")
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
  
  cat("Saved Gaussian normalization cache:\n")
  cat(" ",q_cache_file,"\n")
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
  
  qsum_ss <-
    q_same_grid[ss,,]+
    q_other_grid[ss,,]+
    q_peripheral_grid[ss,,]
  
  max_q_error <-
    max(
      max_q_error,
      max(abs(qsum_ss[core_rc]-1))
    )
  
  min_q_same <-
    min(
      min_q_same,
      min(q_same_grid[ss,,][core_rc])
    )
}

cat("Normalization max |sum(q)-1|:",max_q_error,"\n")
cat("Minimum same-SG mass:",min_q_same,"\n")

if(SOCIAL_ZERO_CONST<=-log(min_q_same)+5)
  stop("SOCIAL_ZERO_CONST is too small.")

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
      
      g_val <-
        exp(-d2/(2.0*sigma^2))
      
      g_vec[r+1] <- g_val
      
      G_sum <- G_sum+g_val
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
# V6b MODEL
# =============================================================================

eps_zero <- c(0,0)
eps_cov <- diag(1,2)

code_V6b <- nimbleCode({
  
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
  # RESIDENT / DISPERSER MOVEMENT PROCESS
  # ===========================================================================
  
  # Female resident baseline.
  alpha_logmove ~ dnorm(MOVE_PRIOR_LOGMEAN,sd=.60)
  
  # Male/female difference.
  beta_move_sex ~ dnorm(0,sd=.50)
  
  # Positive log-scale increase for disperser state.
  # This identifies state 1 as the HIGHER movement state.
  beta_move_disp ~ dexp(1)
  
  # Initial state.
  alpha_disp_init ~ dnorm(qlogis(.10),sd=1.25)
  beta_disp_adult ~ dnorm(0,sd=1)
  
  p_disp_init_young <-
    ilogit(alpha_disp_init)
  
  p_disp_init_adult <-
    ilogit(
      alpha_disp_init+
        beta_disp_adult
    )
  
  # Markov transitions.
  p_RD ~ dbeta(1,4)
  p_DD ~ dbeta(2,2)
  
  p_RR <- 1-p_RD
  p_DR <- 1-p_DD
  
  # ===========================================================================
  # FOUR POSSIBLE MOVEMENT SCALES
  #
  # 1 = female resident
  # 2 = male resident
  # 3 = female disperser
  # 4 = male disperser
  # ===========================================================================
  
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
  
  # Derived movement summaries.
  
  move_multiplier_male <-
    exp(beta_move_sex)
  
  move_multiplier_disp <-
    exp(beta_move_disp)
  
  sigma_move_female_resident <-
    sigma_move_state[1]
  
  sigma_move_male_resident <-
    sigma_move_state[2]
  
  sigma_move_female_disperser <-
    sigma_move_state[3]
  
  sigma_move_male_disperser <-
    sigma_move_state[4]
  
  mean_move_female_resident <-
    sigma_move_state[1]*
    MOVE_MEAN_FACTOR
  
  mean_move_male_resident <-
    sigma_move_state[2]*
    MOVE_MEAN_FACTOR
  
  mean_move_female_disperser <-
    sigma_move_state[3]*
    MOVE_MEAN_FACTOR
  
  mean_move_male_disperser <-
    sigma_move_state[4]*
    MOVE_MEAN_FACTOR
  
  # ===========================================================================
  # LANDSCAPE RESISTANCE
  # ===========================================================================
  
  beta_sg ~ dexp(1)
  beta_peripheral ~ dexp(1)
  
  sg_multiplier <-
    exp(-beta_sg)
  
  peripheral_multiplier <-
    exp(-beta_peripheral)
  
  # ===========================================================================
  # DETECTION TIME EFFECTS
  # ===========================================================================
  
  for(s in 1:3){
    
    beta_season_raw[s] ~
      dnorm(0,sd=1)
    
    beta_season[s] <-
      beta_season_raw[s]
  }
  
  beta_season[4] <-
    -sum(beta_season_raw[1:3])
  
  for(p in 1:(n_periods-1)){
    
    beta_period_raw[p] ~
      dnorm(0,sd=1)
    
    beta_period[p] <-
      beta_period_raw[p]
  }
  
  beta_period[n_periods] <-
    -sum(
      beta_period_raw[
        1:(n_periods-1)
      ]
    )
  
  # ===========================================================================
  # INDIVIDUAL HISTORIES
  # ===========================================================================
  
  for(i in 1:nind){
    
    # -------------------------------------------------------------------------
    # Initial movement state
    # -------------------------------------------------------------------------
    
    logit_p_disp_init[i] <-
      alpha_disp_init+
      beta_disp_adult*
      adult_entry[i]
    
    p_disp_init[i] <-
      ilogit(
        logit_p_disp_init[i]
      )
    
    disp[i,first[i]] ~
      dbern(
        p_disp_init[i]
      )
    
    # -------------------------------------------------------------------------
    # Initial annual activity centre
    # -------------------------------------------------------------------------
    
    S[i,1,first[i]] ~
      dunif(
        grid_xmin,
        grid_xmax
      )
    
    S[i,2,first[i]] ~
      dunif(
        grid_ymin,
        grid_ymax
      )
    
    col_raw[i,first[i]] <-
      trunc(
        (
          S[i,1,first[i]]-
            grid_xmin
        )/
          cell_size
      )+
      1
    
    row_raw[i,first[i]] <-
      trunc(
        (
          grid_ymax-
            S[i,2,first[i]]
        )/
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
      step(
        S[i,1,first[i]]-
          grid_xmin
      )*
      step(
        grid_xmax-
          S[i,1,first[i]]
      )*
      step(
        S[i,2,first[i]]-
          grid_ymin
      )*
      step(
        grid_ymax-
          S[i,2,first[i]]
      )
    
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
    # Detection in first year
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
      
      # -----------------------------------------------------------------------
      # Movement state for interval k-1 -> k
      # -----------------------------------------------------------------------
      
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
      # Gaussian annual displacement
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
      # Next latent movement state
      # -----------------------------------------------------------------------
      
      p_disp[i,k] <-
        (
          1-
            disp[i,k-1]
        )*
        p_RD+
        disp[i,k-1]*
        p_DD
      
      disp[i,k] ~
        dbern(
          p_disp[i,k]
        )
      
      # -----------------------------------------------------------------------
      # Current spatial state
      # -----------------------------------------------------------------------
      
      col_raw[i,k] <-
        trunc(
          (
            S[i,1,k]-
              grid_xmin
          )/
            cell_size
        )+
        1
      
      row_raw[i,k] <-
        trunc(
          (
            grid_ymax-
              S[i,2,k]
          )/
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
        step(
          S[i,1,k]-
            grid_xmin
        )*
        step(
          grid_xmax-
            S[i,1,k]
        )*
        step(
          S[i,2,k]-
            grid_ymin
        )*
        step(
          grid_ymax-
            S[i,2,k]
        )
      
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
      # Dynamic normalized SG / peripheral resistance
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
      # Detection in year k
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

# These must remain DATA because they are dynamically indexed.
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

code_txt <- paste(
  deparse(code_V6b),
  collapse=" "
)

if(!grepl("dmnorm",code_txt))
  stop("STOP: Gaussian movement missing.")

if(grepl("dmvt",code_txt))
  stop("STOP: Student-t movement should NOT occur in V6b.")

if(!grepl("beta_move_disp",code_txt))
  stop("STOP: disperser movement effect missing.")

if(!grepl("p_RD",code_txt) || !grepl("p_DD",code_txt))
  stop("STOP: resident/disperser Markov process missing.")

if(grepl("move_re",code_txt))
  stop("STOP: individual movement random effect should be absent.")

if(!grepl("social_Z",code_txt))
  stop("STOP: normalized landscape resistance missing.")

cat("\nV6b structural checks: PASS\n")
cat("  Gaussian resident/disperser movement\n")
cat("  positive disperser movement effect\n")
cat("  dynamic annual ACs\n")
cat("  bounded first -> last-live histories\n")
cat("  resident <-> disperser Markov process\n")
cat("  SG/peripheral resistance\n")

# =============================================================================
# BUILD MODEL
# =============================================================================

message("\nBuilding V6b model...")

build_time_V6b <- system.time(
  
  model_V6b <- nimbleModel(
    code_V6b,
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
print(build_time_V6b)

lp <- model_V6b$calculate()

cat("\nInitial log probability:",lp,"\n")

if(!is.finite(lp)){
  
  print(
    model_V6b$initializeInfo()
  )
  
  stop(
    "V6b initial log probability is not finite."
  )
}

# =============================================================================
# MONITORS
# =============================================================================

core_monitors <- c(
  "alpha_p",
  "beta_p_sex",
  "alpha_logsigma",
  "beta_sigma_sex",
  
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_disp",
  
  "alpha_disp_init",
  "beta_disp_adult",
  
  "p_RD",
  "p_DD",
  "p_RR",
  "p_DR",
  
  "p_disp_init_young",
  "p_disp_init_adult",
  
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
  
  "p0_female",
  "p0_male",
  "sigma_female",
  "sigma_male",
  
  "beta_season",
  "beta_period",
  
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
    paste0(
      "sex[",
      unknown_sex_idx,
      "]"
    )
  )

if(SAVE_LATENT_STATES)
  monitors <- c(
    monitors,
    disp_nodes
  )

# =============================================================================
# MCMC CONFIGURATION
# =============================================================================

message("\nConfiguring MCMC...")

config_V6b <- configureMCMC(
  model_V6b,
  monitors=unique(monitors),
  thin=THIN
)

# NIMBLE will use its default multivariate sampler for dmnorm eps blocks.
# Only relatively small correlated GLOBAL parameter sets are customised.

move_global <- c(
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_disp"
)

detect_p_global <- c(
  "alpha_p",
  "beta_p_sex"
)

detect_sigma_global <- c(
  "alpha_logsigma",
  "beta_sigma_sex"
)

disp_init_global <- c(
  "alpha_disp_init",
  "beta_disp_adult"
)

landscape_global <- c(
  "beta_sg",
  "beta_peripheral"
)

config_V6b$removeSamplers(
  move_global,
  print=FALSE
)

config_V6b$addSampler(
  target=move_global,
  type="AF_slice"
)

config_V6b$removeSamplers(
  detect_p_global,
  print=FALSE
)

config_V6b$addSampler(
  target=detect_p_global,
  type="AF_slice"
)

config_V6b$removeSamplers(
  detect_sigma_global,
  print=FALSE
)

config_V6b$addSampler(
  target=detect_sigma_global,
  type="AF_slice"
)

config_V6b$removeSamplers(
  disp_init_global,
  print=FALSE
)

config_V6b$addSampler(
  target=disp_init_global,
  type="AF_slice"
)

config_V6b$removeSamplers(
  landscape_global,
  print=FALSE
)

config_V6b$addSampler(
  target=landscape_global,
  type="AF_slice"
)

cat("\nSampler configuration:\n")
cat("  Gaussian eps blocks: NIMBLE default multivariate samplers\n")
cat("  movement global:",paste(move_global,collapse=", "),"\n")
cat("  detection p:",paste(detect_p_global,collapse=", "),"\n")
cat("  detection sigma:",paste(detect_sigma_global,collapse=", "),"\n")
cat("  initial movement state:",paste(disp_init_global,collapse=", "),"\n")
cat("  landscape:",paste(landscape_global,collapse=", "),"\n")
cat("  latent movement states monitored:",SAVE_LATENT_STATES,"\n")

# =============================================================================
# BUILD MCMC
# =============================================================================

build_mcmc_time_V6b <- system.time(
  Rmcmc_V6b <- buildMCMC(
    config_V6b
  )
)

cat("\nMCMC build time:\n")
print(build_mcmc_time_V6b)

# =============================================================================
# COMPILE MODEL + MCMC TOGETHER
# =============================================================================

message("\nCompiling model + MCMC together...")

compile_time_V6b <- system.time(
  
  compiled_V6b <- compileNimble(
    model_V6b,
    Rmcmc_V6b,
    resetFunctions=TRUE
  )
)

cat("\nCombined compile time:\n")
print(compile_time_V6b)

# compileNimble returns the objects in supplied order.
cModel_V6b <- compiled_V6b[[1]]
cMCMC_V6b <- compiled_V6b[[2]]

# =============================================================================
# RUN
# =============================================================================

message("\nRunning V6b overnight movement model...")

runtime_V6b <- system.time(
  
  samples_V6b <- runMCMC(
    cMCMC_V6b,
    
    niter=NITER,
    nburnin=NBURN,
    nchains=NCHAINS,
    
    inits=inits,
    
    samplesAsCodaMCMC=TRUE,
    progressBar=TRUE,
    
    setSeed=
      3451:
      (3451+NCHAINS-1L)
  )
)

cat("\nMCMC runtime:\n")
print(runtime_V6b)

# =============================================================================
# IMMEDIATE DIAGNOSTICS
# =============================================================================

core_pars <- c(
  "alpha_logmove",
  "beta_move_sex",
  "beta_move_disp",
  
  "alpha_disp_init",
  "beta_disp_adult",
  
  "p_RD",
  "p_DD",
  
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
cat("V6b CORE POSTERIOR SUMMARY\n")
cat("============================================================\n")

print(
  MCMCsummary(
    samples_V6b,
    params=core_pars
  )
)

cat("\nGelman-Rubin:\n")

print(
  gelman.diag(
    samples_V6b[,core_pars],
    multivariate=FALSE
  )
)

cat("\nEffective sample sizes:\n")

print(
  effectiveSize(
    samples_V6b[,core_pars]
  )
)

# =============================================================================
# OPTIONAL LATENT-STATE SUMMARIES
# =============================================================================

if(SAVE_LATENT_STATES){
  
  posterior_means <-
    Reduce(
      "+",
      lapply(
        samples_V6b,
        function(x)
          colMeans(as.matrix(x))
      )
    )/
    length(samples_V6b)
  
  disp_summary <- disp_index %>%
    mutate(
      p_disperser=
        unname(
          posterior_means[node]
        )
    )
  
  individual_movement_summary <- disp_summary %>%
    arrange(model_i,from_primary) %>%
    group_by(model_i,tattoo) %>%
    summarise(
      n_intervals=n(),
      
      mean_p_disperser=
        mean(
          p_disperser,
          na.rm=TRUE
        ),
      
      max_p_disperser=
        max(
          p_disperser,
          na.rm=TRUE
        ),
      
      first_p_disperser=
        first(p_disperser),
      
      last_p_disperser=
        last(p_disperser),
      
      n_intervals_p50=
        sum(
          p_disperser>=.50,
          na.rm=TRUE
        ),
      
      n_intervals_p80=
        sum(
          p_disperser>=.80,
          na.rm=TRUE
        ),
      
      .groups="drop"
    ) %>%
    mutate(
      pattern=case_when(
        
        first_p_disperser>=.70 &
          last_p_disperser<.30 ~
          "disperser_then_settled",
        
        first_p_disperser<.30 &
          last_p_disperser>=.70 ~
          "became_disperser",
        
        mean_p_disperser>=.70 ~
          "persistent_high_mobility",
        
        mean_p_disperser<=.30 ~
          "persistent_resident",
        
        TRUE ~
          "mixed_or_uncertain"
      )
    )
  
} else {
  
  disp_summary <- NULL
  individual_movement_summary <- NULL
}

# =============================================================================
# SAVE
# =============================================================================

result_file <- paste0(
  "results/",
  "RD_SCR_V6b_GAUSSIAN_RESIDENT_DISPERSER_",
  nind,
  "_badgers.rds"
)

saveRDS(
  
  list(
    samples=samples_V6b,
    
    runtime=runtime_V6b,
    build_time=build_time_V6b,
    build_mcmc_time=build_mcmc_time_V6b,
    compile_time=compile_time_V6b,
    
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
    
    disp_index=disp_index,
    disp_summary=disp_summary,
    individual_movement_summary=individual_movement_summary,
    
    settings=list(
      model="V6b_clean_resident_disperser",
      
      analysis_end_year=MAX_YEAR,
      min_live_years=MIN_LIVE_YEARS,
      
      sample_n=nind,
      max_adult_entry=MAX_ADULT_ENTRY,
      
      niter=NITER,
      nburn=NBURN,
      nchains=NCHAINS,
      thin=THIN,
      
      movement_kernel="bivariate_Gaussian",
      resident_state="Gaussian_low_movement",
      disperser_state="Gaussian_higher_movement",
      
      disperser_effect=
        "positive_log_scale_increment",
      
      transition_model=
        "first_order_Markov_p_RD_p_DD",
      
      movement_process_window=
        "first_live_year_to_last_live_year",
      
      intervening_missing_years=
        "retained",
      
      post_last_capture_movement=
        "not_modelled",
      
      survival_process=
        "conditioned_out_in_V6b",
      
      adult_entry_effect=
        "initial_disperser_probability_only",
      
      individual_movement_random_effect=
        FALSE,
      
      activity_centres=
        "dynamic_annual",
      
      sg_model=
        "dynamic_normalized_core_SG_plus_peripheral",
      
      normalization_kernel=
        "Gaussian",
      
      latent_states_saved=
        SAVE_LATENT_STATES,
      
      disease_effects=
        "none_in_V6b",
      
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
cat("V6b COMPLETE\n")
cat("============================================================\n")
cat("Saved:",result_file,"\n")

cat("\nTIMINGS\n")
cat("Model build:\n"); print(build_time_V6b)
cat("MCMC build:\n"); print(build_mcmc_time_V6b)
cat("Compile:\n"); print(compile_time_V6b)
cat("MCMC runtime:\n"); print(runtime_V6b)

core_pars <- c(
  "alpha_logmove","beta_move_sex","beta_move_disp",
  "alpha_disp_init","beta_disp_adult",
  "p_RD","p_DD",
  "sigma_move_female_resident","sigma_move_male_resident",
  "sigma_move_female_disperser","sigma_move_male_disperser",
  "mean_move_female_resident","mean_move_male_resident",
  "mean_move_female_disperser","mean_move_male_disperser",
  "alpha_p","beta_p_sex",
  "alpha_logsigma","beta_sigma_sex",
  "beta_sg","beta_peripheral"
)

MCMCsummary(samples_V6b,params=core_pars)

gelman.diag(
  samples_V6b[,core_pars],
  multivariate=FALSE
)

effectiveSize(
  samples_V6b[,core_pars]
)

