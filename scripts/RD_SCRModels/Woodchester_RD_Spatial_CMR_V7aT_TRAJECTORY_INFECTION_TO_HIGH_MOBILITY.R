# =============================================================================
# WOODCHESTER SPATIAL CMR V7a-T
# SAMPLED INFECTION TRAJECTORY -> FUTURE HIGH-MOBILITY / RELOCATION
#
# Same V6c movement scaffold as V7a, but infection status is taken from ONE
# coherent sampled trajectory from the "All tests (inferred)" infection model.
#
# For selected trajectory draw m:
#   I_i,t = 0 before sampled infection_time
#   I_i,t = 1 from sampled infection_time onward
#   infection_time = 0 means never infected during the capture history.
#
# Q4 infection state in origin year t predicts R->D for movement t -> t+1.
# beta_RD_inf is therefore the infected-vs-susceptible log odds contrast.
#
# Default is a short pilot. Set environment variable PILOT=false for the
# production 24k / 6k / 3-chain fit. Select a trajectory with TRAJ_DRAW.
# =============================================================================

library(tidyverse); library(lubridate); library(nimble); library(coda); library(MCMCvis); library(sf)
set.seed(123)

# ---- options ----------------------------------------------------------------
MAX_YEAR <- 2025L
MIN_LIVE_YEARS <- 2L
USE_V6C_SAMPLE <- TRUE
V6C_RESULT_FILE <- "results/RD_SCR_V6c_WIDE_SUPPORT_SEX_TRANSITIONS_500_badgers.rds"
SAMPLE_N <- 500L
MAX_ADULT_ENTRY <- 250L

PILOT <- tolower(Sys.getenv("PILOT",unset="true")) %in% c("true","1","yes")
TRAJ_DRAW <- as.integer(Sys.getenv("TRAJ_DRAW",unset="1"))

if(PILOT){
  NITER <- 8000L
  NBURN <- 2000L
  NCHAINS <- 2L
  THIN <- 2L
} else {
  NITER <- 24000L
  NBURN <- 6000L
  NCHAINS <- 3L
  THIN <- 4L
}
SAVE_LATENT_STATES <- TRUE
START_YEAR <- 1976L

MOVE_MEAN_FACTOR <- sqrt(pi/2)
N_SIGMA_GRID <- 41L
LOG_SIGMA_MIN <- log(5)
LOG_SIGMA_MAX <- log(2500)
LOG_SIGMA_STEP <- (LOG_SIGMA_MAX-LOG_SIGMA_MIN)/(N_SIGMA_GRID-1)
SIGMA_GRID <- exp(seq(LOG_SIGMA_MIN,LOG_SIGMA_MAX,length.out=N_SIGMA_GRID))
MOVE_PRIOR_LOGMEAN <- log(20)
SOCIAL_ZERO_CONST <- 50

encounter_file <- "data/badger_encounters_useful.rds"
individual_file <- "data/badger_individuals.rds"
trajectory_file <- "data/badger_infection_trajectories_all_tests_inferred.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
spatial_file <- "data/spatial/V3_spatial_inputs_50m_2km.rds"

required_files <- c(encounter_file,individual_file,trajectory_file,sett_file,spatial_file)
if(USE_V6C_SAMPLE) required_files <- c(required_files,V6C_RESULT_FILE)
missing_files <- required_files[!file.exists(required_files)]
if(length(missing_files)) stop("Missing required file(s):\n",paste(missing_files,collapse="\n"))
dir.create("results",showWarnings=FALSE); dir.create("data/spatial",recursive=TRUE,showWarnings=FALSE)

cat("\n============================================================\n")
cat("WOODCHESTER V7a-T: TRAJECTORY INFECTION -> FUTURE HIGH MOBILITY\n")
cat("============================================================\n")
cat("Trajectory draw:",TRAJ_DRAW,"| pilot:",PILOT,"\n")
cat("Years <= ",MAX_YEAR," | sigma support ",round(min(SIGMA_GRID)),":",round(max(SIGMA_GRID)),
    " m | ",NCHAINS," chains x ",NITER,"\n",sep="")

# ---- fixed snapshots ---------------------------------------------------------
cmr_raw <- readRDS(encounter_file)
individuals <- readRDS(individual_file)
trajectory_obj <- readRDS(trajectory_file)

if(!TRAJ_DRAW %in% trajectory_obj$draws)
  stop("TRAJ_DRAW ",TRAJ_DRAW," is not present in trajectory object.")

traj_col <- match(TRAJ_DRAW,trajectory_obj$draws)
trajectory_draw <- tibble(
  tattoo=trajectory_obj$tattoo,
  infection_time=as.integer(trajectory_obj$infection_time[,traj_col])
)

if(anyDuplicated(trajectory_draw$tattoo))
  stop("Duplicate tattoos in selected trajectory draw.")

# ---- sett cleaning -----------------------------------------------------------
sett_aliases <- c("\\bCHESTNUT\\b"="CHESNUT","\\bJACKS\\b"="JACKSMIREY","\\bGRAVEL\\b"="GRAVELPIT",
                  "\\bBUCKHOLE\\b"="BUCKHOLT","\\bTOPSETT\\b"="TOP","\\bFOXCUB\\b"="FOX",
                  "\\bGULLEY\\b"="GULLY","\\bBLACKBERRY\\b"="BRAMBLE","\\bBOC\\b"="BOG",
                  "\\bCEDARBANK\\b"="CEDAR","\\bCLAYTRAP\\b"="CLAY","\\bCLIFF\\b"="CLIFFFACE",
                  "\\bDINGLEVALLEY\\b"="DINGLE")
clean_sett <- function(x) x %>% as.character() %>% toupper() %>%
  str_replace_all("[[:punct:]]"," ") %>% str_squish() %>%
  str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>% str_replace_all(sett_aliases) %>%
  str_replace_all("\\s+","")

# ---- spatial inputs ----------------------------------------------------------
sp <- readRDS(spatial_file)
SG_mat <- sp$SG_mat; habitat_mat <- sp$habitat_mat; zone_mat <- sp$zone_mat
grid_xmin <- sp$xmin; grid_xmax <- sp$xmax; grid_ymin <- sp$ymin; grid_ymax <- sp$ymax
cell_size <- sp$cell_size; n_rows <- sp$n_rows; n_cols <- sp$n_cols
stopifnot(!anyNA(SG_mat),!anyNA(habitat_mat),!anyNA(zone_mat))

grid_df <- sp$grid %>% sf::st_drop_geometry()
grid_xy <- sf::st_coordinates(sp$grid)
if(!all(c("row_R","col_R","SG_id","habitat","zone") %in% names(grid_df)))
  stop("sp$grid must contain row_R, col_R, SG_id, habitat and zone.")
land_idx <- which(grid_df$habitat==1L)
core_idx <- which(grid_df$habitat==1L & grid_df$zone==1L)

# ---- exact sett coordinates; fail rather than silently choose duplicates -----
sett_raw <- read_csv(sett_file,show_col_types=FALSE)
name_col <- intersect(c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name"),names(sett_raw))[1]
x_col <- intersect(c("SettX","sett_x","X","x","Easting","easting"),names(sett_raw))[1]
y_col <- intersect(c("SettY","sett_y","Y","y","Northing","northing"),names(sett_raw))[1]
if(any(is.na(c(name_col,x_col,y_col)))) stop("Could not identify sett name/X/Y columns.")

sett_xy_raw <- sett_raw %>%
  transmute(Sett_Clean=clean_sett(.data[[name_col]]),x=as.numeric(.data[[x_col]]),y=as.numeric(.data[[y_col]])) %>%
  filter(!is.na(Sett_Clean),Sett_Clean!="",!is.na(x),!is.na(y))
bad_sett_coords <- sett_xy_raw %>%
  group_by(Sett_Clean) %>%
  summarise(n_xy=n_distinct(paste(x,y,sep="|")),.groups="drop") %>%
  filter(n_xy>1)
if(nrow(bad_sett_coords)){print(bad_sett_coords,n=Inf); stop("Cleaned sett maps to >1 coordinate pair.")}
sett_xy <- sett_xy_raw %>% distinct(Sett_Clean,.keep_all=TRUE)

# ---- encounters, years, demography ------------------------------------------
cmr <- cmr_raw %>%
  mutate(Sett_Clean=clean_sett(sett),primary_year=as.integer(primary_year),
         trap_season=as.integer(trap_season)) %>%
  filter(primary_year<=MAX_YEAR) %>%
  left_join(sett_xy,by="Sett_Clean")

years <- min(cmr$primary_year,na.rm=TRUE):MAX_YEAR
n_prim <- length(years); J <- 4L
cmr <- cmr %>% mutate(primary=match(primary_year,years))
period_vec <- as.integer(match(floor(years/5)*5,sort(unique(floor(years/5)*5))))
n_periods <- max(period_vec)

demog <- individuals %>%
  transmute(individual_id=as.integer(individual_id),tattoo=as.character(tattoo),age_fc=as.character(age_fc),
            entry_group=case_when(age_fc %in% c("Cub","Yearling")~1L,age_fc=="Adult"~2L,TRUE~NA_integer_))
sex_lookup <- individuals %>%
  transmute(individual_id=as.integer(individual_id),tattoo=as.character(tattoo),sex_raw=as.character(sex)) %>%
  mutate(sex_clean=toupper(str_squish(sex_raw)),
         sex_code=case_when(sex_clean %in% c("F","FEMALE")~0L,
                            sex_clean %in% c("M","MALE")~1L,TRUE~NA_integer_))

# ---- one true live location per badger/year/quarter --------------------------
live <- cmr %>%
  filter(has_live_capture,!is.na(primary),trap_season %in% 1:4,!is.na(x),!is.na(y)) %>%
  arrange(individual_id,primary,trap_season,capture_date) %>%
  group_by(individual_id,primary,trap_season) %>%
  arrange(desc(coalesce(differs_from_modal,FALSE)),desc(capture_date),.by_group=TRUE) %>%
  slice(1) %>%
  ungroup()
if(nrow(live %>% count(individual_id,primary,trap_season) %>% filter(n>1))) stop("Duplicate live quarter rows remain.")

live_year_counts <- live %>% distinct(individual_id,primary) %>% count(individual_id,name="n_live_years")
eligible <- live %>%
  distinct(individual_id,tattoo) %>%
  inner_join(demog,by=c("individual_id","tattoo")) %>%
  left_join(sex_lookup %>% select(individual_id,tattoo,sex_code),by=c("individual_id","tattoo")) %>%
  inner_join(live_year_counts,by="individual_id") %>%
  filter(entry_group %in% 1:2,n_live_years>=MIN_LIVE_YEARS,!tattoo %in% "007V")

# ---- exact V6c sample ---------------------------------------------------------
v6c <- NULL
if(USE_V6C_SAMPLE){
  v6c <- readRDS(V6C_RESULT_FILE)
  v6c_ids <- as.character(v6c$ids)
  miss <- setdiff(v6c_ids,eligible$tattoo)
  if(length(miss)) stop(length(miss)," V6c IDs are no longer V7 eligible.")
  eligible <- eligible %>%
    filter(tattoo %in% v6c_ids) %>%
    mutate(v6c_order=match(tattoo,v6c_ids)) %>%
    arrange(v6c_order)
  if(nrow(eligible)!=length(v6c_ids)) stop("Could not reproduce exact V6c sample.")
} else {
  ea <- eligible %>% filter(entry_group==2L); ey <- eligible %>% filter(entry_group==1L)
  na <- min(MAX_ADULT_ENTRY,nrow(ea),SAMPLE_N); ny <- min(SAMPLE_N-na,nrow(ey))
  ea <- if(na<nrow(ea)) ea %>% slice_sample(n=na) else ea
  ey <- if(ny<nrow(ey)) ey %>% slice_sample(n=ny) else ey
  eligible <- bind_rows(ea,ey) %>% slice_sample(prop=1)
}

ids <- eligible$tattoo; individual_ids <- eligible$individual_id; nind <- nrow(eligible)
entry_group <- eligible$entry_group; adult_entry <- as.integer(entry_group==2L)
sex_data <- eligible$sex_code; unknown_sex_idx <- which(is.na(sex_data))
live <- live %>% filter(individual_id %in% individual_ids)

cat("\nSample:",nind,"badgers | adult entry:",sum(adult_entry),"| unknown sex:",length(unknown_sex_idx),"\n")

# ---- detectors + H -----------------------------------------------------------
detectors <- live %>% distinct(Sett_Clean,x,y) %>% arrange(Sett_Clean) %>% mutate(detector=row_number())
if(nrow(detectors %>% count(Sett_Clean) %>% filter(n>1))) stop("A cleaned sett has >1 detector coordinate.")
X <- as.matrix(detectors %>% select(x,y)); R <- nrow(X)
live <- live %>% left_join(detectors %>% select(Sett_Clean,detector),by="Sett_Clean")

H <- array(1L,dim=c(nind,J,n_prim))
for(rr in seq_len(nrow(live))){
  i <- match(live$tattoo[rr],ids); k <- live$primary[rr]; j <- live$trap_season[rr]
  H[i,j,k] <- live$detector[rr]+1L
}

obs_year <- live %>%
  distinct(tattoo,primary) %>%
  group_by(tattoo) %>%
  summarise(first=min(primary),K=max(primary),n_live_years=n(),.groups="drop") %>%
  right_join(tibble(tattoo=ids),by="tattoo") %>%
  arrange(match(tattoo,ids))
first <- as.integer(obs_year$first); K <- as.integer(obs_year$K)
if(anyNA(first) || anyNA(K) || any(K<=first)) stop("Invalid first/K histories.")

# ---- sampled trajectory -> binary Q4 infection state --------------------------
trajectory_draw <- trajectory_draw %>%
  filter(tattoo %in% ids) %>%
  right_join(tibble(tattoo=ids),by="tattoo") %>%
  arrange(match(tattoo,ids))

if(anyNA(trajectory_draw$infection_time))
  stop("Selected trajectory draw is missing one or more V7 sample badgers.")

infection_time <- as.integer(trajectory_draw$infection_time)
q4_time <- 4L*(years-START_YEAR)+4L

infected_q4 <- matrix(0L,nrow=nind,ncol=n_prim)

for(i in seq_len(nind)){
  if(infection_time[i]>0L)
    infected_q4[i,] <- as.integer(q4_time>=infection_time[i])
}

transition_rows <- list()
for(i in seq_len(nind)){
  if(K[i]-first[i]>=2L){
    for(k in (first[i]+2L):K[i]){
      transition_rows[[length(transition_rows)+1L]] <- tibble(
        model_i=i,individual_id=individual_ids[i],tattoo=ids[i],
        previous_state_from=years[k-2L],previous_state_to=years[k-1L],
        new_state_from=years[k-1L],new_state_to=years[k],
        infection_origin_year=years[k-1L],
        infected_q4=infected_q4[i,k-1L])
    }
  }
}
transition_audit <- bind_rows(transition_rows)

cat("Movement-state transitions informing beta_RD_inf:",nrow(transition_audit),"\n")
cat("Susceptible origin states:",sum(transition_audit$infected_q4==0L),"\n")
cat("Infected origin states:",sum(transition_audit$infected_q4==1L),"\n")
cat("Badgers sampled infected at some point:",sum(infection_time>0L),"of",nind,"\n")

if(length(unique(transition_audit$infected_q4))<2L)
  stop("Selected trajectory draw does not provide both susceptible and infected transition origins.")

# ---- annual observed locations; used only for initialization/audit -----------
annual_loc <- live %>%
  group_by(tattoo,primary) %>%
  summarise(x=mean(x),y=mean(y),n_quarters=n(),.groups="drop") %>%
  arrange(tattoo,primary)
annual_obs <- annual_loc %>%
  group_by(tattoo) %>%
  arrange(primary,.by_group=TRUE) %>%
  mutate(previous_primary=lag(primary),previous_x=lag(x),previous_y=lag(y),
         year_gap=primary-previous_primary,
         observed_move=sqrt((x-previous_x)^2+(y-previous_y)^2)) %>%
  ungroup() %>%
  filter(!is.na(previous_primary))

# ---- valid initial AC paths --------------------------------------------------
is_valid_land_xy <- function(x,y){
  cc <- floor((x-grid_xmin)/cell_size)+1L
  rr <- floor((grid_ymax-y)/cell_size)+1L
  inb <- rr>=1L && rr<=n_rows && cc>=1L && cc<=n_cols
  inb && !is.na(habitat_mat[rr,cc]) && habitat_mat[rr,cc]==1L
}
snap_to_land <- function(x,y){
  if(is_valid_land_xy(x,y)) return(c(x,y))
  d2 <- (grid_xy[land_idx,1]-x)^2+(grid_xy[land_idx,2]-y)^2
  grid_xy[land_idx[which.min(d2)],1:2]
}
target_S <- array(NA_real_,c(nind,2L,n_prim))
for(i in seq_len(nind)){
  aa <- annual_loc %>% filter(tattoo==ids[i]) %>% arrange(primary)
  kk <- first[i]:K[i]
  xi <- approx(aa$primary,aa$x,xout=kk,rule=2)$y
  yi <- approx(aa$primary,aa$y,xout=kk,rule=2)$y
  for(a in seq_along(kk)){
    xy <- snap_to_land(xi[a],yi[a])
    target_S[i,1,kk[a]] <- xy[1]; target_S[i,2,kk[a]] <- xy[2]
  }
}
for(i in seq_len(nind)) for(k in first[i]:K[i])
  if(!is_valid_land_xy(target_S[i,1,k],target_S[i,2,k])) stop("Invalid target S.")

# ---- Gaussian dynamic normalization cache -----------------------------------
q_cache_file <- file.path("data","spatial",
  paste0("V7_gaussian_qgrid_",N_SIGMA_GRID,"knots_",round(min(SIGMA_GRID)),"to",round(max(SIGMA_GRID)),"m.rds"))
cache_ok <- FALSE
if(file.exists(q_cache_file)){
  qcache <- readRDS(q_cache_file)
  cache_ok <- identical(qcache$n_rows,n_rows) && identical(qcache$n_cols,n_cols) &&
    identical(qcache$kernel,"bivariate_gaussian") &&
    isTRUE(all.equal(qcache$sigma_grid,SIGMA_GRID,tolerance=1e-12))
}
if(cache_ok){
  q_same_grid <- qcache$q_same; q_other_grid <- qcache$q_other; q_peripheral_grid <- qcache$q_peripheral
  cat("Loaded Gaussian q cache:",q_cache_file,"\n")
} else {
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
      d2 <- (grid_xy[land_idx,1]-grid_xy[oi,1])^2+(grid_xy[land_idx,2]-grid_xy[oi,2])^2
      same <- grid_df$zone[land_idx]==1L & grid_df$SG_id[land_idx]==grid_df$SG_id[oi]
      other <- grid_df$zone[land_idx]==1L & grid_df$SG_id[land_idx]!=grid_df$SG_id[oi]
      per <- grid_df$zone[land_idx]==2L
      for(ss in seq_len(ns)){
        sig <- SIGMA_GRID[ss]; w <- exp(-d2/(2*sig^2)); den <- sum(w)
        out_same[a,ss] <- sum(w[same])/den
        out_other[a,ss] <- sum(w[other])/den
        out_per[a,ss] <- sum(w[per])/den
      }
    }
    list(origin_idx=origin_idx,same=out_same,other=out_other,per=out_per)
  }

  nc <- parallel::detectCores(); if(is.na(nc)) nc <- 1L
  ncores <- max(1L,min(8L,nc-1L)); nchunks <- min(ncores,length(core_idx))
  chunks <- if(nchunks==1L) list(core_idx) else
    split(core_idx,cut(seq_along(core_idx),breaks=nchunks,labels=FALSE))
  q_time <- system.time({
    if(.Platform$OS.type!="windows" && ncores>1L)
      q_parts <- parallel::mclapply(chunks,calc_q_chunk,mc.cores=ncores)
    else q_parts <- lapply(chunks,calc_q_chunk)
  })
  print(q_time)
  for(part in q_parts) for(a in seq_along(part$origin_idx)){
    oi <- part$origin_idx[a]; rr <- grid_df$row_R[oi]; cc <- grid_df$col_R[oi]
    q_same_grid[,rr,cc] <- part$same[a,]
    q_other_grid[,rr,cc] <- part$other[a,]
    q_peripheral_grid[,rr,cc] <- part$per[a,]
  }
  saveRDS(list(q_same=q_same_grid,q_other=q_other_grid,q_peripheral=q_peripheral_grid,
               sigma_grid=SIGMA_GRID,n_rows=n_rows,n_cols=n_cols,kernel="bivariate_gaussian"),
          q_cache_file)
  cat("Saved Gaussian q cache:",q_cache_file,"\n")
}

stopifnot(all(is.finite(q_same_grid)),all(is.finite(q_other_grid)),all(is.finite(q_peripheral_grid)))
core_rc <- cbind(grid_df$row_R[core_idx],grid_df$col_R[core_idx])
max_q_error <- 0; min_q_same <- Inf
for(ss in seq_len(N_SIGMA_GRID)){
  qs <- q_same_grid[ss,,]+q_other_grid[ss,,]+q_peripheral_grid[ss,,]
  max_q_error <- max(max_q_error,max(abs(qs[core_rc]-1)))
  min_q_same <- min(min_q_same,min(q_same_grid[ss,,][core_rc]))
}
cat("q normalization max error:",max_q_error,"| min q_same:",min_q_same,"\n")
if(SOCIAL_ZERO_CONST<=-log(min_q_same)+5) stop("SOCIAL_ZERO_CONST too small.")

# ---- compiled capture likelihood --------------------------------------------
calc_capture_prob <- nimbleFunction(
  run=function(Sx=double(0),Sy=double(0),X=double(2),sigma=double(0),
               lambda0_vec=double(1),H_vec=double(1)){
    returnType(double(1))
    Rf <- dim(X)[1]; Jf <- length(H_vec); G_sum <- 0.0
    g_vec <- numeric(Rf+1,init=FALSE); g_vec[1] <- 0.0
    for(r in 1:Rf){
      d2 <- (Sx-X[r,1])^2+(Sy-X[r,2])^2
      g_val <- exp(-d2/(2.0*sigma^2))
      g_vec[r+1] <- g_val; G_sum <- G_sum+g_val
    }
    captureProb <- numeric(Jf,init=FALSE)
    for(j in 1:Jf){
      Pcap <- 1.0-exp(-lambda0_vec[j]*G_sum)
      Hj <- as.integer(H_vec[j])
      if(Hj>=2) captureProb[j] <- (g_vec[Hj]/(G_sum+1e-10))*Pcap
      else captureProb[j] <- 1.0-Pcap
    }
    return(captureProb)
  }
)

# =============================================================================
# ---- V7a MODEL ---------------------------------------------------------------
# =============================================================================
code_V7 <- nimbleCode({

  # detection
  alpha_p ~ dnorm(qlogis(.17),sd=1.5)
  alpha_logsigma ~ dnorm(log(150),sd=1)
  beta_p_sex ~ dnorm(0,sd=1)
  beta_sigma_sex ~ dnorm(0,sd=.75)
  psi_sex ~ dbeta(1,1)

  for(i in 1:nind){
    sex[i] ~ dbern(psi_sex)
    sigma_i[i] <- exp(alpha_logsigma+beta_sigma_sex*sex[i])
  }

  p0_female <- ilogit(alpha_p)
  p0_male <- ilogit(alpha_p+beta_p_sex)
  sigma_female <- exp(alpha_logsigma)
  sigma_male <- exp(alpha_logsigma+beta_sigma_sex)

  # movement magnitude
  alpha_logmove ~ dnorm(MOVE_PRIOR_LOGMEAN,sd=1)
  beta_move_sex ~ dnorm(0,sd=.50)
  beta_move_disp ~ dexp(1)   # state 1 = higher movement

  # first interval state
  alpha_disp_init ~ dnorm(qlogis(.06),sd=1.25)
  beta_disp_adult ~ dnorm(0,sd=1)
  beta_disp_init_sex ~ dnorm(0,sd=1)

  # R->D and D->D
  alpha_RD ~ dnorm(qlogis(.05),sd=1.25)
  beta_RD_sex ~ dnorm(0,sd=1)
  beta_RD_inf ~ dnorm(0,sd=1)   # PRIMARY V7a PARAMETER

  alpha_DD ~ dnorm(qlogis(.30),sd=1.25)
  beta_DD_sex ~ dnorm(0,sd=1)

  p_RD_female_uninfected <- ilogit(alpha_RD)
  p_RD_female_infected <- ilogit(alpha_RD+beta_RD_inf)
  p_RD_male_uninfected <- ilogit(alpha_RD+beta_RD_sex)
  p_RD_male_infected <- ilogit(alpha_RD+beta_RD_sex+beta_RD_inf)
  p_DD_female <- ilogit(alpha_DD)
  p_DD_male <- ilogit(alpha_DD+beta_DD_sex)
  OR_RD_infection <- exp(beta_RD_inf)
  OR_RD_male <- exp(beta_RD_sex)

  sigma_move_female_local <- exp(alpha_logmove)
  sigma_move_male_local <- exp(alpha_logmove+beta_move_sex)
  sigma_move_female_high <- exp(alpha_logmove+beta_move_disp)
  sigma_move_male_high <- exp(alpha_logmove+beta_move_sex+beta_move_disp)
  mean_move_female_local <- sigma_move_female_local*MOVE_MEAN_FACTOR
  mean_move_male_local <- sigma_move_male_local*MOVE_MEAN_FACTOR
  mean_move_female_high <- sigma_move_female_high*MOVE_MEAN_FACTOR
  mean_move_male_high <- sigma_move_male_high*MOVE_MEAN_FACTOR

  # landscape
  beta_sg ~ dexp(1)
  beta_peripheral ~ dexp(1)
  sg_multiplier <- exp(-beta_sg)
  peripheral_multiplier <- exp(-beta_peripheral)

  # detection time effects
  for(s in 1:3){beta_season_raw[s] ~ dnorm(0,sd=1); beta_season[s] <- beta_season_raw[s]}
  beta_season[4] <- -sum(beta_season_raw[1:3])
  for(p in 1:(n_periods-1)){beta_period_raw[p] ~ dnorm(0,sd=1); beta_period[p] <- beta_period_raw[p]}
  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods-1)])

  for(i in 1:nind){

    # first AC
    S[i,1,first[i]] ~ dunif(grid_xmin,grid_xmax)
    S[i,2,first[i]] ~ dunif(grid_ymin,grid_ymax)

    col_raw[i,first[i]] <- trunc((S[i,1,first[i]]-grid_xmin)/cell_size)+1
    row_raw[i,first[i]] <- trunc((grid_ymax-S[i,2,first[i]])/cell_size)+1
    col_S[i,first[i]] <- max(1,min(n_cols,col_raw[i,first[i]]))
    row_S[i,first[i]] <- max(1,min(n_rows,row_raw[i,first[i]]))
    in_bounds[i,first[i]] <- step(S[i,1,first[i]]-grid_xmin)*step(grid_xmax-S[i,1,first[i]])*
      step(S[i,2,first[i]]-grid_ymin)*step(grid_ymax-S[i,2,first[i]])
    habitat_here[i,first[i]] <- habitat_mat[row_S[i,first[i]],col_S[i,first[i]]]
    SG_here[i,first[i]] <- SG_mat[row_S[i,first[i]],col_S[i,first[i]]]
    zone_here[i,first[i]] <- zone_mat[row_S[i,first[i]],col_S[i,first[i]]]
    valid_state[i,first[i]] <- in_bounds[i,first[i]]*habitat_here[i,first[i]]
    state_ok[i,first[i]] ~ dbern(valid_state[i,first[i]])

    for(j in 1:J){
      lp0[i,j,first[i]] <- alpha_p+beta_p_sex*sex[i]+beta_season[j]+beta_period[period_vec[first[i]]]
      lambda0[i,j,first[i]] <- -log(1-ilogit(lp0[i,j,first[i]]))
    }
    captureProb[i,1:J,first[i]] <- calc_capture_prob(
      S[i,1,first[i]],S[i,2,first[i]],X[1:R,1:2],sigma_i[i],
      lambda0[i,1:J,first[i]],H[i,1:J,first[i]])
    for(j in 1:J) Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])

    p_disp_init[i] <- ilogit(alpha_disp_init+beta_disp_adult*adult_entry[i]+beta_disp_init_sex*sex[i])

    # disp[i,k] = movement state for k-1 -> k.
    # disp[i,first[i]] is fixed data sentinel 0.
    for(k in (first[i]+1):K[i]){

      is_initial_interval[i,k] <- equals(k,first[i]+1)

      # Fixed binary infection state from one coherent sampled trajectory.
      p_RD_i[i,k] <- ilogit(
        alpha_RD+
        beta_RD_sex*sex[i]+
        beta_RD_inf*infected_q4[i,k-1]
      )
      p_DD_i[i,k] <- ilogit(alpha_DD+beta_DD_sex*sex[i])
      p_disp_markov[i,k] <- (1-disp[i,k-1])*p_RD_i[i,k]+disp[i,k-1]*p_DD_i[i,k]
      p_disp_state[i,k] <- is_initial_interval[i,k]*p_disp_init[i]+
        (1-is_initial_interval[i,k])*p_disp_markov[i,k]
      disp[i,k] ~ dbern(p_disp_state[i,k])

      # Gaussian annual AC movement
      log_sigma_move[i,k] <- alpha_logmove+beta_move_sex*sex[i]+beta_move_disp*disp[i,k]
      sigma_move[i,k] <- exp(log_sigma_move[i,k])
      move_support[i,k] <- step(log_sigma_move[i,k]-LOG_SIGMA_MIN)*step(LOG_SIGMA_MAX-log_sigma_move[i,k])
      move_support_ok[i,k] ~ dbern(move_support[i,k])

      sigma_grid_pos[i,k] <- (log_sigma_move[i,k]-LOG_SIGMA_MIN)/LOG_SIGMA_STEP+1
      sigma_grid_lo_raw[i,k] <- trunc(sigma_grid_pos[i,k])
      sigma_grid_lo[i,k] <- max(1,min(N_SIGMA_GRID-1,sigma_grid_lo_raw[i,k]))
      sigma_grid_frac[i,k] <- max(0,min(1,sigma_grid_pos[i,k]-sigma_grid_lo[i,k]))

      eps[i,1:2,k] ~ dmnorm(mean=eps_zero[1:2],prec=eps_prec[1:2,1:2])
      S[i,1,k] <- S[i,1,k-1]+sigma_move[i,k]*eps[i,1,k]
      S[i,2,k] <- S[i,2,k-1]+sigma_move[i,k]*eps[i,2,k]
      moveDist[i,k] <- sigma_move[i,k]*sqrt(pow(eps[i,1,k],2)+pow(eps[i,2,k],2))

      # habitat
      col_raw[i,k] <- trunc((S[i,1,k]-grid_xmin)/cell_size)+1
      row_raw[i,k] <- trunc((grid_ymax-S[i,2,k])/cell_size)+1
      col_S[i,k] <- max(1,min(n_cols,col_raw[i,k]))
      row_S[i,k] <- max(1,min(n_rows,row_raw[i,k]))
      in_bounds[i,k] <- step(S[i,1,k]-grid_xmin)*step(grid_xmax-S[i,1,k])*
        step(S[i,2,k]-grid_ymin)*step(grid_ymax-S[i,2,k])
      habitat_here[i,k] <- habitat_mat[row_S[i,k],col_S[i,k]]
      SG_here[i,k] <- SG_mat[row_S[i,k],col_S[i,k]]
      zone_here[i,k] <- zone_mat[row_S[i,k],col_S[i,k]]
      valid_state[i,k] <- in_bounds[i,k]*habitat_here[i,k]
      state_ok[i,k] ~ dbern(valid_state[i,k])

      # normalized SG/peripheral resistance
      apply_social[i,k] <- equals(zone_here[i,k-1],1)
      q_same_lo[i,k] <- q_same_grid[sigma_grid_lo[i,k],row_S[i,k-1],col_S[i,k-1]]
      q_same_hi[i,k] <- q_same_grid[sigma_grid_lo[i,k]+1,row_S[i,k-1],col_S[i,k-1]]
      q_other_lo[i,k] <- q_other_grid[sigma_grid_lo[i,k],row_S[i,k-1],col_S[i,k-1]]
      q_other_hi[i,k] <- q_other_grid[sigma_grid_lo[i,k]+1,row_S[i,k-1],col_S[i,k-1]]
      q_per_lo[i,k] <- q_peripheral_grid[sigma_grid_lo[i,k],row_S[i,k-1],col_S[i,k-1]]
      q_per_hi[i,k] <- q_peripheral_grid[sigma_grid_lo[i,k]+1,row_S[i,k-1],col_S[i,k-1]]

      q_same_here[i,k] <- q_same_lo[i,k]+sigma_grid_frac[i,k]*(q_same_hi[i,k]-q_same_lo[i,k])
      q_other_here[i,k] <- q_other_lo[i,k]+sigma_grid_frac[i,k]*(q_other_hi[i,k]-q_other_lo[i,k])
      q_per_here[i,k] <- q_per_lo[i,k]+sigma_grid_frac[i,k]*(q_per_hi[i,k]-q_per_lo[i,k])

      social_Z[i,k] <- q_same_here[i,k]+q_other_here[i,k]*sg_multiplier+
        q_per_here[i,k]*peripheral_multiplier
      dest_other_core[i,k] <- equals(zone_here[i,k],1)*(1-equals(SG_here[i,k],SG_here[i,k-1]))
      dest_peripheral[i,k] <- equals(zone_here[i,k],2)
      log_R_dest[i,k] <- -beta_sg*dest_other_core[i,k]-beta_peripheral*dest_peripheral[i,k]
      log_social_correction[i,k] <- apply_social[i,k]*(log_R_dest[i,k]-log(social_Z[i,k]))
      social_lambda[i,k] <- SOCIAL_ZERO_CONST-log_social_correction[i,k]
      social_zero[i,k] ~ dpois(social_lambda[i,k])

      # detection
      for(j in 1:J){
        lp0[i,j,k] <- alpha_p+beta_p_sex*sex[i]+beta_season[j]+beta_period[period_vec[k]]
        lambda0[i,j,k] <- -log(1-ilogit(lp0[i,j,k]))
      }
      captureProb[i,1:J,k] <- calc_capture_prob(
        S[i,1,k],S[i,2,k],X[1:R,1:2],sigma_i[i],lambda0[i,1:J,k],H[i,1:J,k])
      for(j in 1:J) Ones[i,j,k] ~ dbern(captureProb[i,j,k])
    }
  }
})

# ---- constants/data ----------------------------------------------------------
eps_zero <- c(0,0); eps_prec <- diag(1,2)
consts <- list(nind=nind,R=R,J=J,first=as.integer(first),K=as.integer(K),X=X,H=H,
               adult_entry=as.integer(adult_entry),n_periods=n_periods,period_vec=as.integer(period_vec),
               grid_xmin=grid_xmin,grid_xmax=grid_xmax,grid_ymin=grid_ymin,grid_ymax=grid_ymax,
               cell_size=cell_size,n_rows=n_rows,n_cols=n_cols,
               MOVE_MEAN_FACTOR=MOVE_MEAN_FACTOR,MOVE_PRIOR_LOGMEAN=MOVE_PRIOR_LOGMEAN,
               N_SIGMA_GRID=N_SIGMA_GRID,LOG_SIGMA_MIN=LOG_SIGMA_MIN,LOG_SIGMA_MAX=LOG_SIGMA_MAX,
               LOG_SIGMA_STEP=LOG_SIGMA_STEP,SOCIAL_ZERO_CONST=SOCIAL_ZERO_CONST,
               eps_zero=eps_zero,eps_prec=eps_prec)

disp_data <- matrix(NA_integer_,nind,n_prim)
for(i in seq_len(nind)) disp_data[i,first[i]] <- 0L

data_list <- list(Ones=array(1L,c(nind,J,n_prim)),sex=sex_data,disp=disp_data,
                  infected_q4=infected_q4,state_ok=matrix(1L,nind,n_prim),
                  move_support_ok=matrix(1L,nind,n_prim),social_zero=matrix(0L,nind,n_prim),
                  habitat_mat=habitat_mat,SG_mat=SG_mat,zone_mat=zone_mat,
                  q_same_grid=q_same_grid,q_other_grid=q_other_grid,
                  q_peripheral_grid=q_peripheral_grid)

# ---- warm starts from V6c ----------------------------------------------------
v6_post_mean <- function(name,default){
  if(is.null(v6c) || is.null(v6c$samples)) return(default)
  z <- unlist(lapply(v6c$samples,function(ch){
    m <- as.matrix(ch)
    if(name %in% colnames(m)) mean(m[,name]) else NA_real_
  }))
  z <- z[is.finite(z)]
  if(length(z)) mean(z) else default
}
warm <- list(
  alpha_p=v6_post_mean("alpha_p",-1.35),beta_p_sex=v6_post_mean("beta_p_sex",0),
  alpha_logsigma=v6_post_mean("alpha_logsigma",4.95),beta_sigma_sex=v6_post_mean("beta_sigma_sex",.17),
  alpha_logmove=v6_post_mean("alpha_logmove",1.93),beta_move_sex=v6_post_mean("beta_move_sex",-.06),
  beta_move_disp=max(.2,v6_post_mean("beta_move_disp",4.8)),
  alpha_disp_init=v6_post_mean("alpha_disp_init",-3.29),beta_disp_adult=v6_post_mean("beta_disp_adult",-.15),
  beta_disp_init_sex=v6_post_mean("beta_disp_init_sex",.14),
  alpha_RD=v6_post_mean("alpha_RD",-3.05),beta_RD_sex=v6_post_mean("beta_RD_sex",.70),
  alpha_DD=v6_post_mean("alpha_DD",-.86),beta_DD_sex=v6_post_mean("beta_DD_sex",-.52),
  beta_sg=max(.001,v6_post_mean("beta_sg",.10)),beta_peripheral=max(.05,v6_post_mean("beta_peripheral",4.36))
)

# ---- initials: movement parameters drawn ONCE then used to build eps --------
make_inits <- function(chain){
  set.seed(7000+chain)
  sex_work <- sex_data
  if(length(unknown_sex_idx)) sex_work[unknown_sex_idx] <- rbinom(length(unknown_sex_idx),1,.5)

  a_move <- warm$alpha_logmove+rnorm(1,0,.05)
  b_sex <- warm$beta_move_sex+rnorm(1,0,.03)
  b_disp <- max(.2,warm$beta_move_disp+rnorm(1,0,.08))

  S0 <- array(NA_real_,c(nind,2L,n_prim))
  eps0 <- array(NA_real_,c(nind,2L,n_prim))
  disp0 <- matrix(NA_integer_,nind,n_prim)

  for(i in seq_len(nind)){
    S0[i,1,first[i]] <- target_S[i,1,first[i]]
    S0[i,2,first[i]] <- target_S[i,2,first[i]]
    for(k in (first[i]+1L):K[i]){
      dx <- target_S[i,1,k]-target_S[i,1,k-1L]
      dy <- target_S[i,2,k]-target_S[i,2,k-1L]
      dd <- sqrt(dx^2+dy^2)
      d0 <- rbinom(1,1,plogis((dd-150)/50))
      disp0[i,k] <- d0
      sig0 <- exp(a_move+b_sex*sex_work[i]+b_disp*d0)
      eps0[i,1,k] <- dx/sig0; eps0[i,2,k] <- dy/sig0
    }
  }

  sex0 <- rep(NA_integer_,nind)
  if(length(unknown_sex_idx)) sex0[unknown_sex_idx] <- sex_work[unknown_sex_idx]

  list(alpha_p=warm$alpha_p+rnorm(1,0,.05),beta_p_sex=warm$beta_p_sex+rnorm(1,0,.03),
       alpha_logsigma=warm$alpha_logsigma+rnorm(1,0,.03),
       beta_sigma_sex=warm$beta_sigma_sex+rnorm(1,0,.02),
       psi_sex=runif(1,.4,.6),sex=sex0,
       alpha_logmove=a_move,beta_move_sex=b_sex,beta_move_disp=b_disp,
       alpha_disp_init=warm$alpha_disp_init+rnorm(1,0,.08),
       beta_disp_adult=warm$beta_disp_adult+rnorm(1,0,.05),
       beta_disp_init_sex=warm$beta_disp_init_sex+rnorm(1,0,.05),
       alpha_RD=warm$alpha_RD+rnorm(1,0,.08),beta_RD_sex=warm$beta_RD_sex+rnorm(1,0,.05),
       beta_RD_inf=rnorm(1,0,.08),
       alpha_DD=warm$alpha_DD+rnorm(1,0,.08),beta_DD_sex=warm$beta_DD_sex+rnorm(1,0,.05),
       beta_sg=max(.001,warm$beta_sg+rnorm(1,0,.02)),
       beta_peripheral=max(.05,warm$beta_peripheral+rnorm(1,0,.08)),
       beta_season_raw=rnorm(3,0,.03),beta_period_raw=rnorm(n_periods-1L,0,.03),
       S=S0,eps=eps0,disp=disp0)
}
inits <- lapply(seq_len(NCHAINS),make_inits)

# ---- sanity checks -----------------------------------------------------------
code_txt <- paste(deparse(code_V7),collapse=" ")
if(grepl("dmvt",code_txt)) stop("Student-t found: V7a must retain V6c Gaussian movement.")
if(!grepl("dmnorm",code_txt) || !grepl("beta_RD_inf",code_txt) || !grepl("infected_q4",code_txt))
  stop("Required V7a-T Gaussian/trajectory-infection structure missing.")
if(grepl("p_RD_marginal",code_txt))
  stop("Probability-mixture code remains: V7a-T should use sampled binary infection state.")
if(!grepl("beta_RD_sex",code_txt) || !grepl("beta_DD_sex",code_txt))
  stop("V6c sex transition effects missing.")
if(!grepl("social_Z",code_txt) || !grepl("beta_peripheral",code_txt))
  stop("Normalized SG/peripheral resistance missing.")
cat("\nModel code checks: PASS\n")

# ---- build/compile -----------------------------------------------------------
build_time_V7 <- system.time(
  model_V7 <- nimbleModel(code_V7,constants=consts,data=data_list,inits=inits[[1]],
    dimensions=list(Ones=dim(data_list$Ones),sex=nind,disp=c(nind,n_prim),
                    infected_q4=c(nind,n_prim),state_ok=c(nind,n_prim),
                    move_support_ok=c(nind,n_prim),social_zero=c(nind,n_prim),
                    eps=c(nind,2L,n_prim)),
    check=TRUE,calculate=FALSE))
cat("\nModel build time:\n"); print(build_time_V7)

lp <- model_V7$calculate()
cat("Initial log probability:",lp,"\n")
if(!is.finite(lp)){
  st <- model_V7$getNodeNames(stochOnly=TRUE,includeData=TRUE)
  ll <- sapply(st,function(x) model_V7$getLogProb(x))
  print(tibble(node=st,logProb=ll) %>% filter(!is.finite(logProb)),n=Inf)
  stop("V7a initial log probability is not finite.")
}

compile_model_time_V7 <- system.time(cModel_V7 <- compileNimble(model_V7,resetFunctions=TRUE))
cat("\nModel compile time:\n"); print(compile_model_time_V7)

# ---- monitors ---------------------------------------------------------------
core_monitors <- c(
  "alpha_p","beta_p_sex","alpha_logsigma","beta_sigma_sex",
  "alpha_logmove","beta_move_sex","beta_move_disp",
  "alpha_disp_init","beta_disp_adult","beta_disp_init_sex",
  "alpha_RD","beta_RD_sex","beta_RD_inf","alpha_DD","beta_DD_sex",
  "OR_RD_infection","OR_RD_male",
  "p_RD_female_uninfected","p_RD_female_infected",
  "p_RD_male_uninfected","p_RD_male_infected","p_DD_female","p_DD_male",
  "sigma_move_female_local","sigma_move_male_local","sigma_move_female_high","sigma_move_male_high",
  "mean_move_female_local","mean_move_male_local","mean_move_female_high","mean_move_male_high",
  "p0_female","p0_male","sigma_female","sigma_male",
  "beta_season","beta_period","beta_sg","beta_peripheral","sg_multiplier","peripheral_multiplier","psi_sex")

disp_index <- bind_rows(lapply(seq_len(nind),function(i){
  ks <- (first[i]+1L):K[i]
  tibble(model_i=i,individual_id=individual_ids[i],tattoo=ids[i],state_k=ks,
         from_primary=ks-1L,to_primary=ks,from_year=years[ks-1L],to_year=years[ks],
         is_initial_interval=ks==(first[i]+1L),
         infected_q4_origin=infected_q4[i,ks-1L],
         node=paste0("disp[",i,", ",ks,"]"))
}))
disp_nodes <- disp_index$node

monitors <- core_monitors
if(length(unknown_sex_idx)) monitors <- c(monitors,paste0("sex[",unknown_sex_idx,"]"))
if(SAVE_LATENT_STATES) monitors <- c(monitors,disp_nodes)

# ---- MCMC configuration ------------------------------------------------------
config_V7 <- configureMCMC(model_V7,monitors=unique(monitors),thin=1)

move_global <- c("alpha_logmove","beta_move_sex","beta_move_disp")
RD_global <- c("alpha_RD","beta_RD_sex","beta_RD_inf")
DD_global <- c("alpha_DD","beta_DD_sex")
init_global <- c("alpha_disp_init","beta_disp_adult","beta_disp_init_sex")
detect_p_global <- c("alpha_p","beta_p_sex")
detect_sigma_global <- c("alpha_logsigma","beta_sigma_sex")
landscape_global <- c("beta_sg","beta_peripheral")

for(b in list(move_global,RD_global,DD_global,init_global,detect_p_global,detect_sigma_global,landscape_global)){
  config_V7$removeSamplers(b,print=FALSE)
  config_V7$addSampler(target=b,type="AF_slice")
}

build_mcmc_time_V7 <- system.time(Rmcmc_V7 <- buildMCMC(config_V7))
cat("\nMCMC build time:\n"); print(build_mcmc_time_V7)
compile_mcmc_time_V7 <- system.time(
  cMCMC_V7 <- compileNimble(Rmcmc_V7,project=cModel_V7,resetFunctions=TRUE))
cat("\nMCMC compile time:\n"); print(compile_mcmc_time_V7)

# ---- run --------------------------------------------------------------------
runtime_V7 <- system.time(
  samples_V7 <- runMCMC(cMCMC_V7,niter=NITER,nburnin=NBURN,nchains=NCHAINS,
                        thin=THIN,inits=inits,samplesAsCodaMCMC=TRUE,
                        progressBar=TRUE,setSeed=3451:(3451+NCHAINS-1L)))
cat("\nRuntime:\n"); print(runtime_V7)

# ---- primary posterior -------------------------------------------------------
cat("\n============================================================\n")
cat("V7a PRIMARY POSTERIOR SUMMARY\n")
cat("============================================================\n")
print(MCMCsummary(samples_V7,params=core_monitors))

chain_names <- lapply(samples_V7,function(x) colnames(as.matrix(x)))
common_names <- Reduce(intersect,chain_names)
diag_params <- unique(c(
  intersect(setdiff(core_monitors,c("beta_season","beta_period")),common_names),
  grep("^beta_season\\[",common_names,value=TRUE),
  grep("^beta_period\\[",common_names,value=TRUE)
))
diag_samples <- coda::mcmc.list(lapply(samples_V7,function(ch)
  coda::as.mcmc(as.matrix(ch)[,diag_params,drop=FALSE])))

cat("\nGelman-Rubin:\n")
print(coda::gelman.diag(diag_samples,multivariate=FALSE,autoburnin=FALSE))
cat("\nEffective sample sizes:\n")
print(sort(coda::effectiveSize(diag_samples)))

beta_inf_draws <- unlist(lapply(samples_V7,function(ch) as.matrix(ch)[,"beta_RD_inf"]))
or_inf_draws <- exp(beta_inf_draws)
infection_effect_summary <- tibble(
  quantity=c("beta_RD_inf","OR_RD_infection","P(beta_RD_inf > 0)"),
  mean=c(mean(beta_inf_draws),mean(or_inf_draws),mean(beta_inf_draws>0)),
  q2.5=c(quantile(beta_inf_draws,.025),quantile(or_inf_draws,.025),NA_real_),
  median=c(median(beta_inf_draws),median(or_inf_draws),NA_real_),
  q97.5=c(quantile(beta_inf_draws,.975),quantile(or_inf_draws,.975),NA_real_))
print(infection_effect_summary)

# ---- latent-state summaries --------------------------------------------------
posterior_means <- Reduce("+",lapply(samples_V7,function(x) colMeans(as.matrix(x))))/length(samples_V7)

if(SAVE_LATENT_STATES){
  disp_summary <- disp_index %>% mutate(p_high_mobility=unname(posterior_means[node]))
  individual_movement_summary <- disp_summary %>%
    arrange(model_i,from_primary) %>%
    group_by(model_i,individual_id,tattoo) %>%
    summarise(n_intervals=n(),mean_p_high=mean(p_high_mobility),max_p_high=max(p_high_mobility),
              first_p_high=first(p_high_mobility),last_p_high=last(p_high_mobility),
              n_intervals_p50=sum(p_high_mobility>=.50),n_intervals_p80=sum(p_high_mobility>=.80),
              .groups="drop") %>%
    mutate(movement_pattern=case_when(
      max_p_high<.20 ~ "strongly_resident",
      n_intervals==1 & max_p_high>=.80 ~ "single_high_mobility_event",
      n_intervals>=3 & mean_p_high>=.70 & n_intervals_p80/n_intervals>=.67 ~ "persistent_high_mobility",
      n_intervals>=2 & first_p_high>=.70 & last_p_high<.30 ~ "disperser_then_settled",
      n_intervals>=2 & first_p_high<.30 & last_p_high>=.70 ~ "became_disperser",
      n_intervals_p80>=1 ~ "episodic_disperser",TRUE ~ "mixed_or_uncertain"))
  pattern_counts <- individual_movement_summary %>% count(movement_pattern,name="n") %>%
    mutate(proportion=n/sum(n))
  state_occupancy <- disp_summary %>%
    summarise(n_intervals=n(),n_p50=sum(p_high_mobility>=.50),n_p80=sum(p_high_mobility>=.80),
              mean_p=mean(p_high_mobility),median_p=median(p_high_mobility))
  infection_state_descriptive <- disp_summary %>%
    filter(!is_initial_interval) %>%
    group_by(infected_q4_origin) %>%
    summarise(n=n(),mean_p_high=mean(p_high_mobility),
              median_p_high=median(p_high_mobility),.groups="drop")
  print(pattern_counts,n=Inf); print(state_occupancy); print(infection_state_descriptive,n=Inf)
} else {
  disp_summary <- individual_movement_summary <- pattern_counts <- state_occupancy <- infection_state_descriptive <- NULL
}

# ---- save -------------------------------------------------------------------
result_file <- paste0(
  "results/RD_SCR_V7aT_TRAJECTORY_DRAW_",TRAJ_DRAW,
  if(PILOT) "_PILOT_" else "_FULL_",
  nind,"_badgers.rds"
)
saveRDS(list(
  samples=samples_V7,runtime=runtime_V7,build_time=build_time_V7,
  compile_model_time=compile_model_time_V7,build_mcmc_time=build_mcmc_time_V7,
  compile_mcmc_time=compile_mcmc_time_V7,
  ids=ids,individual_ids=individual_ids,sex_data=sex_data,entry_group=entry_group,
  adult_entry=adult_entry,first=first,K=K,years=years,detectors=detectors,H=H,
  trajectory_draw=TRAJ_DRAW,infection_time=infection_time,infected_q4=infected_q4,
  transition_audit=transition_audit,
  annual_obs=annual_obs,disp_index=disp_index,disp_summary=disp_summary,
  individual_movement_summary=individual_movement_summary,
  infection_effect_summary=infection_effect_summary,pattern_counts=pattern_counts,
  state_occupancy=state_occupancy,infection_state_descriptive=infection_state_descriptive,
  settings=list(model="V7aT_sampled_trajectory_infection_to_future_high_mobility",
    movement_scaffold="V6c_two_state_Gaussian",
    sample_source=if(USE_V6C_SAMPLE) "exact_V6c_sample" else "new_adult_enriched_sample",
    sample_n=nind,max_year=MAX_YEAR,min_live_years=MIN_LIVE_YEARS,
    niter=NITER,nburn=NBURN,nchains=NCHAINS,thin=THIN,
    encounter_file=encounter_file,individual_file=individual_file,trajectory_file=trajectory_file,
    infection_variant="All tests (inferred)",trajectory_draw=TRAJ_DRAW,
    infection_alignment="sampled binary Q4 infection state in origin year",
    infection_uncertainty="one coherent sampled absorbing trajectory",infection_thresholded=FALSE,
    primary_parameter="beta_RD_inf",first_interval_infection_effect=FALSE,
    movement_kernel="bivariate_Gaussian",
    latent_state="stable_local_vs_high_mobility_relocation",
    state_definition="disp[i,k] is movement from primary k-1 to k",
    adult_entry_effect="initial_state_probability_only",
    survival="conditioned_out",movement_endpoint="last_observed_live_year",
    sg_model="dynamic_normalized_core_SG_plus_peripheral",sigma_grid=SIGMA_GRID,
    spatial_file=spatial_file,q_cache_file=q_cache_file)),
  result_file)

cat("\n============================================================\n")
cat("V7a-T COMPLETE\n")
cat("============================================================\n")
cat("Saved:",result_file,"\n")
cat("Primary parameter: beta_RD_inf; OR = exp(beta_RD_inf)\n")
