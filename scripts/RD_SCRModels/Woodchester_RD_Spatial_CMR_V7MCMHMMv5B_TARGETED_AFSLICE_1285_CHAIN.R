# =============================================================================
# WOODCHESTER V7MC-MHMM v5B - TARGETED AF_SLICE BLOCKING
#
# Purpose
#   Fit the established V6c two-state annual activity-centre movement model ONCE
#   to all 1,285 badgers that can contribute to the directional V7 analyses.
#
#   Disease is deliberately absent. Posterior movement-state draws are then
#   exported and combined later with sampled infection trajectories in fast
#   modular directional analyses.
#
# Key optimization
#   ONE CHAIN PER R PROCESS / BACKGROUND JOB.
#   Set CHAIN_ID=1, 2 or 3 and run three jobs simultaneously.
#
# Default production settings
#   16,000 iterations; 4,000 burn-in; thin 4; one chain per job.
#
# Scientific structure retained from V6c
#   - annual ACs + four quarterly capture occasions
#   - each annual AC S[i,1:2,k] updated jointly with one AF_slice sampler
#   - Gaussian stable/local vs high-mobility movement states
#   - movement state sequence analytically MARGINALIZED with nimbleEcology dHMMo
#   - no discrete disp nodes are sampled during MCMC
#   - sex effects on movement magnitude and R->D / D->D transitions
#   - adult-entry effect on initial movement state only
#   - dynamically normalized SG + peripheral resistance
#   - movement first live year -> last observed live year
#   - 2026 excluded; survival conditioned out
#
# Optimization relative to V7a-T/V7b-T
#   - no infection nodes or likelihood
#   - exact directional-analysis population from the all-badger audit
#   - sex is fixed data/constant (all 1,285 have known sex), not a stochastic node
#   - monitor only core fitted parameters + latent disp states
#   - no large derived-quantity monitoring
# =============================================================================

library(tidyverse); library(lubridate); library(nimble); library(coda); library(MCMCvis); library(sf)
if(!requireNamespace("nimbleEcology",quietly=TRUE))
  stop("Package 'nimbleEcology' is required. Install it with install.packages('nimbleEcology').")
library(nimbleEcology)
set.seed(123)

# ---- options ----------------------------------------------------------------
MAX_YEAR <- 2025L
MIN_LIVE_YEARS <- 2L

CHAIN_ID <- as.integer(Sys.getenv("CHAIN_ID",unset="1"))
if(!CHAIN_ID %in% 1:3) stop("CHAIN_ID must be 1, 2 or 3.")

NITER <- as.integer(Sys.getenv("NITER",unset="16000"))
NBURN <- as.integer(Sys.getenv("NBURN",unset="4000"))
THIN <- as.integer(Sys.getenv("THIN",unset="4"))
RESULT_TAG <- Sys.getenv("RESULT_TAG",unset="")
if(nchar(RESULT_TAG) && !grepl("^_",RESULT_TAG)) RESULT_TAG <- paste0("_",RESULT_TAG)

V6C_RESULT_FILE <- "results/RD_SCR_V6c_WIDE_SUPPORT_SEX_TRANSITIONS_500_badgers.rds"
AUDIT_FILE <- "results/V7_all_badger_all_trajectory_information_audit.rds"

MOVE_MEAN_FACTOR <- sqrt(pi/2)
LOG_TWO_PI <- log(2*pi)
N_SIGMA_GRID <- 41L
LOG_SIGMA_MIN <- log(5)
LOG_SIGMA_MAX <- log(2500)
LOG_SIGMA_STEP <- (LOG_SIGMA_MAX-LOG_SIGMA_MIN)/(N_SIGMA_GRID-1)
SIGMA_GRID <- exp(seq(LOG_SIGMA_MIN,LOG_SIGMA_MAX,length.out=N_SIGMA_GRID))
MOVE_PRIOR_LOGMEAN <- log(20)
SOCIAL_ZERO_CONST <- 50

encounter_file <- "data/badger_encounters_useful.rds"
individual_file <- "data/badger_individuals.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
spatial_file <- "data/spatial/V3_spatial_inputs_50m_2km.rds"

required_files <- c(encounter_file,individual_file,sett_file,spatial_file,
                    V6C_RESULT_FILE,AUDIT_FILE)
missing_files <- required_files[!file.exists(required_files)]
if(length(missing_files)) stop("Missing required file(s):\n",paste(missing_files,collapse="\n"))
dir.create("results",showWarnings=FALSE); dir.create("data/spatial",recursive=TRUE,showWarnings=FALSE)

cat("\n============================================================\n")
cat("WOODCHESTER V7MC-MHMM v5B: TARGETED AF_SLICE + MARGINALIZED HMM\n")
cat("============================================================\n")
cat("Chain:",CHAIN_ID,"| iterations:",NITER,"| burn:",NBURN,"| thin:",THIN,"\n")
cat("Years <= ",MAX_YEAR," | sigma support ",round(min(SIGMA_GRID)),":",round(max(SIGMA_GRID))," m\n",sep="")

# ---- fixed snapshots ---------------------------------------------------------
cmr_raw <- readRDS(encounter_file)
individuals <- readRDS(individual_file)
v6c <- readRDS(V6C_RESULT_FILE)
audit_obj <- readRDS(AUDIT_FILE)

required_cmr_cols <- c(
  "individual_id","tattoo","sett","primary_year","trap_season",
  "capture_date","has_live_capture","differs_from_modal"
)
missing_cmr_cols <- setdiff(required_cmr_cols,names(cmr_raw))
if(length(missing_cmr_cols))
  stop("encounters_useful snapshot is missing required column(s): ",
       paste(missing_cmr_cols,collapse=", "))

directional_ids <- audit_obj$history %>%
  filter(v7a_contributor) %>%
  pull(tattoo) %>%
  as.character()

cat("Directional-analysis IDs from audit:",length(directional_ids),"\n")
if(length(directional_ids)!=1285L)
  warning("Audit currently contains ",length(directional_ids),
          " directional-analysis badgers rather than 1285.")

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

# ---- exact all-directional-badger population ---------------------------------
eligible <- eligible %>%
  filter(tattoo %in% directional_ids) %>%
  mutate(audit_order=match(tattoo,directional_ids)) %>%
  arrange(audit_order)

missing_directional <- setdiff(directional_ids,eligible$tattoo)
if(length(missing_directional))
  stop(length(missing_directional),
       " audit-selected directional IDs are no longer model-eligible.")

if(nrow(eligible)!=length(directional_ids))
  stop("Could not reconstruct exact directional-analysis population.")

ids <- eligible$tattoo
individual_ids <- eligible$individual_id
nind <- nrow(eligible)

entry_group <- eligible$entry_group
adult_entry <- as.integer(entry_group==2L)
sex_data <- as.integer(eligible$sex_code)

if(anyNA(sex_data))
  stop("Directional population should have known sex for every badger.")

live <- live %>% filter(individual_id %in% individual_ids)

cat("\nProduction population:",nind,"badgers\n")
cat("  female:",sum(sex_data==0L),"| male:",sum(sex_data==1L),"\n")
cat("  adult entry:",sum(adult_entry==1L),"| young entry:",sum(adult_entry==0L),"\n")

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

# ---- exact modeled movement intervals ---------------------------------------
# Pack only real annual movement states.  This avoids NIMBLE monitoring the
# unused cells of the large rectangular disp[i,k] array.
disp_index <- bind_rows(lapply(seq_len(nind),function(i){
  ks <- seq.int(first[i]+1L,K[i])
  tibble(model_i=i,individual_id=individual_ids[i],tattoo=ids[i],state_k=ks,
         from_primary=ks-1L,to_primary=ks,from_year=years[ks-1L],to_year=years[ks],
         is_initial_interval=ks==(first[i]+1L),
         node=paste0("disp[",i,", ",ks,"]"))
}))
n_disp_save <- nrow(disp_index)
disp_save_i <- as.integer(disp_index$model_i)
disp_save_k <- as.integer(disp_index$state_k)

cat("Modeled annual movement intervals:",n_disp_save,"\n")

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

# ---- marginal HMM constants --------------------------------------------------
n_move <- as.integer(K-first)
max_move <- max(n_move)

# Use ONE FIXED HMM length for every badger. This is much friendlier to NIMBLE's
# model/type system than a multivariate stochastic node whose length changes
# with i. Real movement intervals are followed only by neutral padded intervals.
#
# At padded intervals probObs = c(.5,.5) for BOTH latent states. Therefore each
# padded observation contributes the same fixed factor .5 and carries no
# information about movement state or transition parameters.
active_move <- matrix(0L,nind,max_move)
move_from_k <- matrix(1L,nind,max_move)
move_to_k <- matrix(1L,nind,max_move)

for(i in seq_len(nind)){
  ni <- n_move[i]
  active_move[i,seq_len(ni)] <- 1L

  # All badgers in this analysis have K > first. For real intervals use the
  # exact annual transition; padded cells reuse the last valid transition only
  # as a safe finite index (its likelihood is multiplied by active_move = 0).
  move_from_k[i,seq_len(ni)] <- first[i]+seq_len(ni)-1L
  move_to_k[i,seq_len(ni)] <- first[i]+seq_len(ni)

  if(ni < max_move){
    pad <- (ni+1L):max_move
    move_from_k[i,pad] <- K[i]-1L
    move_to_k[i,pad] <- K[i]
  }
}

# dHMMo requires observation probabilities. Encode the continuous movement
# density as category-1 probability = L_state / EMIT_SCALE. Because EMIT_SCALE
# is FIXED and independent of state/parameters this changes the likelihood only
# by an additive constant on real intervals.
max_emission_bound <- (1/(2*pi*min(SIGMA_GRID)^2))/min_q_same
EMIT_SCALE <- max(10,2*max_emission_bound)
cat("Marginal-HMM emission upper bound:",max_emission_bound,
    "| fixed scale:",EMIT_SCALE,"\n")
if(max_emission_bound>=EMIT_SCALE) stop("EMIT_SCALE is not conservative.")

# Category 1 is observed at every HMM time. Padded times have state-independent
# P(category 1)=.5 and hence are likelihood-neutral apart from a constant.
move_obs_data <- matrix(1L,nind,max_move)

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
# ---- V7MC-MHMM MODEL: MOVEMENT STATES MARGINALIZED ---------------------------
# =============================================================================
code_V7 <- nimbleCode({

  # detection
  alpha_p ~ dnorm(qlogis(.17),sd=1.5)
  alpha_logsigma ~ dnorm(log(150),sd=1)
  beta_p_sex ~ dnorm(0,sd=1)
  beta_sigma_sex ~ dnorm(0,sd=.75)

  for(i in 1:nind)
    sigma_i[i] <- exp(alpha_logsigma+beta_sigma_sex*sex[i])

  # movement magnitude
  alpha_logmove ~ dnorm(MOVE_PRIOR_LOGMEAN,sd=1)
  beta_move_sex ~ dnorm(0,sd=.50)
  beta_move_disp ~ dexp(1) # state 2 is the high-mobility state

  # first movement-interval state
  alpha_disp_init ~ dnorm(qlogis(.06),sd=1.25)
  beta_disp_adult ~ dnorm(0,sd=1)
  beta_disp_init_sex ~ dnorm(0,sd=1)

  # subsequent state transitions
  alpha_RD ~ dnorm(qlogis(.05),sd=1.25)
  beta_RD_sex ~ dnorm(0,sd=1)
  alpha_DD ~ dnorm(qlogis(.30),sd=1.25)
  beta_DD_sex ~ dnorm(0,sd=1)

  # landscape
  beta_sg ~ dexp(1)
  beta_peripheral ~ dexp(1)
  sg_multiplier <- exp(-beta_sg)
  peripheral_multiplier <- exp(-beta_peripheral)

  # useful derived movement scales
  sigma_move_female_local <- exp(alpha_logmove)
  sigma_move_male_local <- exp(alpha_logmove+beta_move_sex)
  sigma_move_female_high <- exp(alpha_logmove+beta_move_disp)
  sigma_move_male_high <- exp(alpha_logmove+beta_move_sex+beta_move_disp)

  # detection time effects
  for(s in 1:3){
    beta_season_raw[s] ~ dnorm(0,sd=1)
    beta_season[s] <- beta_season_raw[s]
  }
  beta_season[4] <- -sum(beta_season_raw[1:3])

  for(p in 1:(n_periods-1)){
    beta_period_raw[p] ~ dnorm(0,sd=1)
    beta_period[p] <- beta_period_raw[p]
  }
  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods-1)])

  for(i in 1:nind){

    # HMM initial/transition probabilities: state 1=local, state 2=high.
    p_disp_init[i] <- ilogit(
      alpha_disp_init+
      beta_disp_adult*adult_entry[i]+
      beta_disp_init_sex*sex[i]
    )
    p_RD_i[i] <- ilogit(alpha_RD+beta_RD_sex*sex[i])
    p_DD_i[i] <- ilogit(alpha_DD+beta_DD_sex*sex[i])

    init_move[i,1] <- 1-p_disp_init[i]
    init_move[i,2] <- p_disp_init[i]

    trans_move[i,1,1] <- 1-p_RD_i[i]
    trans_move[i,1,2] <- p_RD_i[i]
    trans_move[i,2,1] <- 1-p_DD_i[i]
    trans_move[i,2,2] <- p_DD_i[i]

    # State-specific movement scales are constant through time within individual.
    log_sigma_state[i,1] <- alpha_logmove+beta_move_sex*sex[i]
    log_sigma_state[i,2] <- alpha_logmove+beta_move_sex*sex[i]+beta_move_disp

    for(ss in 1:2){

      # Hard support remains exactly [5,2500] m, but use a clipped value for
      # deterministic density/q-grid calculations. This prevents 0*Inf/NaN
      # when a proposal lies outside support.
      support_state[i,ss] <-
        step(log_sigma_state[i,ss]-LOG_SIGMA_MIN)*
        step(LOG_SIGMA_MAX-log_sigma_state[i,ss])

      log_sigma_safe_state[i,ss] <-
        max(LOG_SIGMA_MIN,min(LOG_SIGMA_MAX,log_sigma_state[i,ss]))
      sigma_state[i,ss] <- exp(log_sigma_safe_state[i,ss])

      sigma_grid_pos_state[i,ss] <-
        (log_sigma_safe_state[i,ss]-LOG_SIGMA_MIN)/LOG_SIGMA_STEP+1
      sigma_grid_lo_raw_state[i,ss] <- trunc(sigma_grid_pos_state[i,ss])
      sigma_grid_lo_state[i,ss] <-
        max(1,min(N_SIGMA_GRID-1,sigma_grid_lo_raw_state[i,ss]))
      sigma_grid_frac_state[i,ss] <-
        max(0,min(1,sigma_grid_pos_state[i,ss]-sigma_grid_lo_state[i,ss]))
    }

    # -------------------------------------------------------------------------
    # ACTIVITY CENTRES + DETECTION/HABITAT
    #
    # All annual S are given a uniform base density over the state-space bounds.
    # The actual Gaussian movement transition density is supplied inside the
    # marginalized HMM likelihood below.  The extra uniform density is constant
    # over valid S and therefore does not alter the target posterior.
    # -------------------------------------------------------------------------
    for(k in first[i]:K[i]){

      S[i,1,k] ~ dunif(grid_xmin,grid_xmax)
      S[i,2,k] ~ dunif(grid_ymin,grid_ymax)

      col_raw[i,k] <- trunc((S[i,1,k]-grid_xmin)/cell_size)+1
      row_raw[i,k] <- trunc((grid_ymax-S[i,2,k])/cell_size)+1
      col_S[i,k] <- max(1,min(n_cols,col_raw[i,k]))
      row_S[i,k] <- max(1,min(n_rows,row_raw[i,k]))

      in_bounds[i,k] <-
        step(S[i,1,k]-grid_xmin)*step(grid_xmax-S[i,1,k])*
        step(S[i,2,k]-grid_ymin)*step(grid_ymax-S[i,2,k])

      habitat_here[i,k] <- habitat_mat[row_S[i,k],col_S[i,k]]
      SG_here[i,k] <- SG_mat[row_S[i,k],col_S[i,k]]
      zone_here[i,k] <- zone_mat[row_S[i,k],col_S[i,k]]
      valid_state[i,k] <- in_bounds[i,k]*habitat_here[i,k]
      state_ok[i,k] ~ dbern(valid_state[i,k])

      for(j in 1:J){
        lp0[i,j,k] <-
          alpha_p+beta_p_sex*sex[i]+
          beta_season[j]+beta_period[period_vec[k]]
        lambda0[i,j,k] <- -log(1-ilogit(lp0[i,j,k]))
      }

      captureProb[i,1:J,k] <- calc_capture_prob(
        S[i,1,k],S[i,2,k],X[1:R,1:2],sigma_i[i],
        lambda0[i,1:J,k],H[i,1:J,k]
      )

      for(j in 1:J)
        Ones[i,j,k] ~ dbern(captureProb[i,j,k])
    }

    # -------------------------------------------------------------------------
    # STATE-SPECIFIC MOVEMENT EMISSIONS
    #
    # Fixed max_move length for every individual. active_move=1 denotes a real
    # annual transition. active_move=0 denotes a neutral padded HMM time.
    # -------------------------------------------------------------------------
    for(tt in 1:max_move){

      dx_move[i,tt] <-
        S[i,1,move_to_k[i,tt]]-S[i,1,move_from_k[i,tt]]
      dy_move[i,tt] <-
        S[i,2,move_to_k[i,tt]]-S[i,2,move_from_k[i,tt]]
      r2_move[i,tt] <- pow(dx_move[i,tt],2)+pow(dy_move[i,tt],2)

      # These terms do NOT depend on candidate latent state, so define them
      # once per interval (not inside the ss loop).
      apply_social[i,tt] <-
        equals(zone_here[i,move_from_k[i,tt]],1)

      dest_other[i,tt] <-
        equals(zone_here[i,move_to_k[i,tt]],1)*
        (1-equals(
          SG_here[i,move_to_k[i,tt]],
          SG_here[i,move_from_k[i,tt]]
        ))

      dest_per[i,tt] <-
        equals(zone_here[i,move_to_k[i,tt]],2)

      log_R_dest[i,tt] <-
        -beta_sg*dest_other[i,tt]-
        beta_peripheral*dest_per[i,tt]

      for(ss in 1:2){

        # Exact isotropic 2-D Gaussian movement density.
        log_gauss_move[i,ss,tt] <-
          -LOG_TWO_PI-2*log_sigma_safe_state[i,ss]-
          0.5*r2_move[i,tt]/pow(sigma_state[i,ss],2)

        # Dynamic normalized SG/peripheral resistance under candidate state ss.
        q_same_lo_state[i,ss,tt] <-
          q_same_grid[
            sigma_grid_lo_state[i,ss],
            row_S[i,move_from_k[i,tt]],
            col_S[i,move_from_k[i,tt]]
          ]
        q_same_hi_state[i,ss,tt] <-
          q_same_grid[
            sigma_grid_lo_state[i,ss]+1,
            row_S[i,move_from_k[i,tt]],
            col_S[i,move_from_k[i,tt]]
          ]

        q_other_lo_state[i,ss,tt] <-
          q_other_grid[
            sigma_grid_lo_state[i,ss],
            row_S[i,move_from_k[i,tt]],
            col_S[i,move_from_k[i,tt]]
          ]
        q_other_hi_state[i,ss,tt] <-
          q_other_grid[
            sigma_grid_lo_state[i,ss]+1,
            row_S[i,move_from_k[i,tt]],
            col_S[i,move_from_k[i,tt]]
          ]

        q_per_lo_state[i,ss,tt] <-
          q_peripheral_grid[
            sigma_grid_lo_state[i,ss],
            row_S[i,move_from_k[i,tt]],
            col_S[i,move_from_k[i,tt]]
          ]
        q_per_hi_state[i,ss,tt] <-
          q_peripheral_grid[
            sigma_grid_lo_state[i,ss]+1,
            row_S[i,move_from_k[i,tt]],
            col_S[i,move_from_k[i,tt]]
          ]

        q_same_state[i,ss,tt] <-
          q_same_lo_state[i,ss,tt]+
          sigma_grid_frac_state[i,ss]*
          (q_same_hi_state[i,ss,tt]-q_same_lo_state[i,ss,tt])

        q_other_state[i,ss,tt] <-
          q_other_lo_state[i,ss,tt]+
          sigma_grid_frac_state[i,ss]*
          (q_other_hi_state[i,ss,tt]-q_other_lo_state[i,ss,tt])

        q_per_state[i,ss,tt] <-
          q_per_lo_state[i,ss,tt]+
          sigma_grid_frac_state[i,ss]*
          (q_per_hi_state[i,ss,tt]-q_per_lo_state[i,ss,tt])

        social_Z_state[i,ss,tt] <-
          q_same_state[i,ss,tt]+
          q_other_state[i,ss,tt]*sg_multiplier+
          q_per_state[i,ss,tt]*peripheral_multiplier

        log_social_corr_state[i,ss,tt] <-
          apply_social[i,tt]*
          (log_R_dest[i,tt]-log(social_Z_state[i,ss,tt]))

        log_emit_weight[i,ss,tt] <-
          log_gauss_move[i,ss,tt]+
          log_social_corr_state[i,ss,tt]

        emit_weight[i,ss,tt] <-
          support_state[i,ss]*exp(log_emit_weight[i,ss,tt])

        # Real interval: scaled continuous movement likelihood.
        # Padded interval: exactly .5 for both states.
        probObs_move[i,ss,1,tt] <-
          active_move[i,tt]*(emit_weight[i,ss,tt]/EMIT_SCALE)+
          (1-active_move[i,tt])*0.5

        probObs_move[i,ss,2,tt] <-
          1-probObs_move[i,ss,1,tt]
      }

      log_emit_ratio[i,tt] <-
        active_move[i,tt]*
        (
          log(probObs_move[i,2,1,tt]+1e-300)-
          log(probObs_move[i,1,1,tt]+1e-300)
        )
    }

    # Fixed-length marginalized HMM. Padding is exactly state-neutral.
    move_obs[i,1:max_move] ~ dHMMo(
      init=init_move[i,1:2],
      probObs=probObs_move[i,1:2,1:2,1:max_move],
      probTrans=trans_move[i,1:2,1:2],
      len=max_move,
      checkRowSums=0
    )
  }

  # Packed emission log-ratios for posterior FFBS state reconstruction.
  for(r in 1:n_disp_save){
    tt_save[r] <- disp_save_k[r]-first[disp_save_i[r]]
    log_emit_ratio_save[r] <-
      log_emit_ratio[disp_save_i[r],tt_save[r]]
  }
})

# ---- constants/data ----------------------------------------------------------
consts <- list(
  nind=nind,R=R,J=J,first=as.integer(first),K=as.integer(K),
  max_move=as.integer(max_move),
  active_move=active_move,
  move_from_k=move_from_k,move_to_k=move_to_k,
  X=X,H=H,
  adult_entry=as.integer(adult_entry),sex=as.integer(sex_data),
  n_periods=n_periods,period_vec=as.integer(period_vec),
  grid_xmin=grid_xmin,grid_xmax=grid_xmax,
  grid_ymin=grid_ymin,grid_ymax=grid_ymax,
  cell_size=cell_size,n_rows=n_rows,n_cols=n_cols,
  MOVE_PRIOR_LOGMEAN=MOVE_PRIOR_LOGMEAN,
  LOG_TWO_PI=LOG_TWO_PI,
  N_SIGMA_GRID=N_SIGMA_GRID,
  LOG_SIGMA_MIN=LOG_SIGMA_MIN,LOG_SIGMA_MAX=LOG_SIGMA_MAX,
  LOG_SIGMA_STEP=LOG_SIGMA_STEP,
  EMIT_SCALE=EMIT_SCALE,
  n_disp_save=n_disp_save,
  disp_save_i=disp_save_i,disp_save_k=disp_save_k
)

data_list <- list(
  Ones=array(1L,c(nind,J,n_prim)),
  state_ok=matrix(1L,nind,n_prim),
  move_obs=move_obs_data,
  habitat_mat=habitat_mat,
  SG_mat=SG_mat,
  zone_mat=zone_mat,
  q_same_grid=q_same_grid,
  q_other_grid=q_other_grid,
  q_peripheral_grid=q_peripheral_grid
)

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

# ---- initials: centered annual AC paths --------------------------------------
make_inits <- function(chain){
  set.seed(7000+chain)

  a_move <- warm$alpha_logmove+rnorm(1,0,.05)
  b_sex <- warm$beta_move_sex+rnorm(1,0,.03)
  b_disp <- max(.2,warm$beta_move_disp+rnorm(1,0,.08))

  S0 <- array(NA_real_,c(nind,2L,n_prim))
  for(i in seq_len(nind)){
    for(k in first[i]:K[i]){
      S0[i,1,k] <- target_S[i,1,k]
      S0[i,2,k] <- target_S[i,2,k]
    }
  }

  list(alpha_p=warm$alpha_p+rnorm(1,0,.05),beta_p_sex=warm$beta_p_sex+rnorm(1,0,.03),
       alpha_logsigma=warm$alpha_logsigma+rnorm(1,0,.03),
       beta_sigma_sex=warm$beta_sigma_sex+rnorm(1,0,.02),
       alpha_logmove=a_move,beta_move_sex=b_sex,beta_move_disp=b_disp,
       alpha_disp_init=warm$alpha_disp_init+rnorm(1,0,.08),
       beta_disp_adult=warm$beta_disp_adult+rnorm(1,0,.05),
       beta_disp_init_sex=warm$beta_disp_init_sex+rnorm(1,0,.05),
       alpha_RD=warm$alpha_RD+rnorm(1,0,.08),beta_RD_sex=warm$beta_RD_sex+rnorm(1,0,.05),
       alpha_DD=warm$alpha_DD+rnorm(1,0,.08),beta_DD_sex=warm$beta_DD_sex+rnorm(1,0,.05),
       beta_sg=max(.001,warm$beta_sg+rnorm(1,0,.02)),
       beta_peripheral=max(.05,warm$beta_peripheral+rnorm(1,0,.08)),
       beta_season_raw=rnorm(3,0,.03),beta_period_raw=rnorm(n_periods-1L,0,.03),
       S=S0)
}
inits <- make_inits(CHAIN_ID)

# ---- sanity checks -----------------------------------------------------------
code_txt <- paste(deparse(code_V7),collapse=" ")
if(grepl("disp\\[i,k\\] ~",code_txt))
  stop("Discrete disp state nodes remain; marginal HMM should remove them.")
if(!grepl("dHMMo",code_txt))
  stop("Marginal HMM likelihood not found.")
if(!grepl("checkRowSums = 0|checkRowSums=0",code_txt))
  stop("Internal dHMMo row-sum checker should be disabled in v3.")
if(!grepl("log_sigma_safe_state",code_txt))
  stop("Safe supported movement-scale calculation missing.")
if(grepl("(^|[^A-Za-z0-9_])pi([^A-Za-z0-9_]|$)",code_txt))
  stop("Bare pi remains inside nimbleCode; use LOG_TWO_PI constant.")
if(grepl("apply_social_state",code_txt) || grepl("dest_other_state",code_txt))
  stop("Old multiply-defined social nodes remain.")
if(grepl("beta_RD_inf",code_txt) || grepl("infected_q4",code_txt) ||
   grepl("infection_event",code_txt) || grepl("beta_acq",code_txt))
  stop("Disease code remains in movement-only model.")
cat("\nMarginal-HMM model code checks: PASS\n")

# ---- build/compile -----------------------------------------------------------
build_time_V7 <- system.time(
  model_V7 <- nimbleModel(code_V7,constants=consts,data=data_list,inits=inits,
    dimensions=list(
      Ones=dim(data_list$Ones),
      state_ok=c(nind,n_prim),
      move_obs=c(nind,max_move),
      S=c(nind,2L,n_prim)
    ),
    check=TRUE,calculate=FALSE))
cat("\nModel build time:\n"); print(build_time_V7)

lp <- model_V7$calculate()
cat("Initial log probability:",lp,"\n")
if(!is.finite(lp)){
  st <- model_V7$getNodeNames(stochOnly=TRUE,includeData=TRUE)
  ll <- sapply(st,function(x) model_V7$getLogProb(x))
  print(tibble(node=st,logProb=ll) %>% filter(!is.finite(logProb)),n=Inf)
  stop("V7MC-MHMM initial log probability is not finite.")
}

compile_model_time_V7 <- system.time(cModel_V7 <- compileNimble(model_V7,resetFunctions=TRUE))
cat("\nModel compile time:\n"); print(compile_model_time_V7)

# ---- monitors ---------------------------------------------------------------
core_monitors <- c(
  "alpha_p","beta_p_sex","alpha_logsigma","beta_sigma_sex",
  "alpha_logmove","beta_move_sex","beta_move_disp",
  "alpha_disp_init","beta_disp_adult","beta_disp_init_sex",
  "alpha_RD","beta_RD_sex","alpha_DD","beta_DD_sex",
  "beta_season_raw","beta_period_raw",
  "beta_sg","beta_peripheral"
)

# Save one state-likelihood log-ratio per real movement interval.
# Together with the global transition parameters, these are sufficient to draw
# coherent posterior local/high state histories with FFBS after MCMC.
monitors <- c(core_monitors,"log_emit_ratio_save")

# ---- MCMC configuration ------------------------------------------------------
config_V7 <- configureMCMC(model_V7,monitors=unique(monitors),thin=1)

# ---- targeted AF_slice blocking ---------------------------------------------
# v4 diagnostics showed the main remaining convergence problem in the movement
# scale parameters and the R->D transition parameters.
#
# v5B joins ONLY those five directly coupled parameters into one AF_slice block.
# Parameters that already mixed relatively well remain in the smaller v4
# blocks, avoiding the high computational cost of the 12-D v5 block.

move_RD_global <- c(
  "alpha_logmove","beta_move_sex","beta_move_disp",
  "alpha_RD","beta_RD_sex"
)

DD_global <- c("alpha_DD","beta_DD_sex")
init_global <- c("alpha_disp_init","beta_disp_adult","beta_disp_init_sex")
detect_p_global <- c("alpha_p","beta_p_sex")
detect_sigma_global <- c("alpha_logsigma","beta_sigma_sex")
landscape_global <- c("beta_sg","beta_peripheral")

for(b in list(
  move_RD_global,DD_global,init_global,
  detect_p_global,detect_sigma_global,landscape_global
)){
  config_V7$removeSamplers(b,print=FALSE)
  config_V7$addSampler(target=b,type="AF_slice")
}

cat("\nTargeted global AF_slice blocks:\n")
cat("  movement + R->D:",length(move_RD_global),"parameters\n")
cat("  D->D:",length(DD_global),"parameters\n")
cat("  initial state:",length(init_global),"parameters\n")
cat("  detection p:",length(detect_p_global),"parameters\n")
cat("  detection sigma:",length(detect_sigma_global),"parameters\n")
cat("  landscape:",length(landscape_global),"parameters\n")

# ---- bivariate activity-centre AF_slice samplers -----------------------------
# Update X and Y TOGETHER for each annual AC.  The biological model is unchanged:
# only the MCMC transition kernel changes.
#
# We include the first annual AC as well as all subsequent annual ACs.
S_blocks <- unlist(
  lapply(seq_len(nind),function(i){
    ks <- seq.int(first[i],K[i])
    paste0("S[",i,", 1:2, ",ks,"]")
  }),
  use.names=FALSE
)

message("\nReplacing scalar S samplers with bivariate AF_slice blocks...")
config_V7$removeSamplers(S_blocks,print=FALSE)
invisible(lapply(
  S_blocks,
  function(n) config_V7$addSampler(target=n,type="AF_slice")
))
cat("  bivariate S AF_slice blocks:",length(S_blocks),"\n")

cat("\n===== FINAL V5B SAMPLER CONFIGURATION =====\n")
config_V7$printSamplers()

build_mcmc_time_V7 <- system.time(Rmcmc_V7 <- buildMCMC(config_V7))
cat("\nMCMC build time:\n"); print(build_mcmc_time_V7)
compile_mcmc_time_V7 <- system.time(
  cMCMC_V7 <- compileNimble(Rmcmc_V7,project=cModel_V7,resetFunctions=TRUE))
cat("\nMCMC compile time:\n"); print(compile_mcmc_time_V7)

# ---- run ONE chain in this process ------------------------------------------
runtime_V7 <- system.time(
  samples_V7 <- runMCMC(
    cMCMC_V7,
    niter=NITER,
    nburnin=NBURN,
    nchains=1,
    thin=THIN,
    inits=inits,
    samplesAsCodaMCMC=TRUE,
    progressBar=TRUE,
    setSeed=91000L+CHAIN_ID
  )
)
cat("\nRuntime:\n"); print(runtime_V7)

# Normalize to a single mcmc object for compact chain files.
if(inherits(samples_V7,"mcmc.list"))
  samples_V7 <- samples_V7[[1]]

# ---- compact chain summary ---------------------------------------------------
m <- as.matrix(samples_V7)

cat("\n============================================================\n")
cat("V7MC-MHMM CHAIN ",CHAIN_ID," COMPLETE\n",sep="")
cat("============================================================\n")
cat("Posterior draws saved:",nrow(m),"\n")
cat("Packed movement-emission ratios saved:",n_disp_save,"\n")

cat("\nCore posterior means for quick chain check:\n")
quick <- intersect(
  c("alpha_logmove","beta_move_sex","beta_move_disp",
    "alpha_RD","beta_RD_sex","alpha_DD","beta_DD_sex",
    "beta_sg","beta_peripheral"),
  colnames(m)
)
print(colMeans(m[,quick,drop=FALSE]))

result_file <- sprintf(
  "results/RD_SCR_V7MCMHMMv5B_TARGETED_AFSLICE_1285_CHAIN_%d%s.rds",
  CHAIN_ID,RESULT_TAG
)

saveRDS(
  list(
    samples=samples_V7,
    runtime=runtime_V7,
    build_time=build_time_V7,
    compile_model_time=compile_model_time_V7,
    build_mcmc_time=build_mcmc_time_V7,
    compile_mcmc_time=compile_mcmc_time_V7,
    chain_id=CHAIN_ID,
    ids=ids,
    individual_ids=individual_ids,
    sex_data=sex_data,
    entry_group=entry_group,
    adult_entry=adult_entry,
    first=first,
    K=K,
    years=years,
    detectors=detectors,
    H=H,
    annual_obs=annual_obs,
    disp_index=disp_index,
    core_monitors=core_monitors,
    settings=list(
      model="V7MCMHMMv5B_targeted_5D_move_RD_AFslice_marginalized_HMM",
      sample_source="all_directional_badgers_from_V7_audit",
      sample_n=nind,
      max_year=MAX_YEAR,
      min_live_years=MIN_LIVE_YEARS,
      niter=NITER,
      nburn=NBURN,
      thin=THIN,
      chain_id=CHAIN_ID,
      result_tag=RESULT_TAG,
      parameterisation="bounded_uniform_AC_base_plus_marginal_Gaussian_HMM_likelihood",
      ac_sampler="AF_slice_bivariate_XY_by_annual_activity_centre",
      global_sampler="targeted_5D_AF_slice_move_plus_RD; other v4 blocks retained",
      movement_kernel="isotropic_bivariate_Gaussian_via_two_independent_dnorm_coordinates",
      latent_state="stable_local_vs_high_mobility_relocation_marginalized_during_MCMC",
      state_definition="state for movement primary k-1 to k; reconstructed post hoc by FFBS",
      adult_entry_effect="initial_state_probability_only",
      sex="fixed_known_covariate",
      survival="conditioned_out",
      movement_endpoint="last_observed_live_year",
      sg_model="dynamic_normalized_core_SG_plus_peripheral",
      spatial_file=spatial_file,
      q_cache_file=q_cache_file,
      audit_file=AUDIT_FILE
    )
  ),
  result_file
)

cat("\nSaved:",result_file,"\n")
