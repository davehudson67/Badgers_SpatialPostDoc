# =============================================================================
# WOODCHESTER SPATIAL CMR V4b DEVELOPMENT TEST
# 50 m habitat state space + NON-CENTRED HEAVY-TAILED Student-t3 movement
# + NORMALIZED social-group and peripheral resistance
# + PARTIALLY OBSERVED LATENT SEX affecting survival, baseline detection and detection scale.
#
# IMPORTANT DEVELOPMENT CHOICE:
# To make the landscape normalization mathematically coherent and computationally
# tractable in this first test, sigma_move is FIXED at the current t3 development
# estimates. The base t3 movement density and the precomputed normalization
# therefore use exactly the same movement scales. Known sex is supplied as data
# (0=female, 1=male); unknown sex is NA and sampled by NIMBLE. Sex affects
# survival, p0 and detection sigma; movement remains fixed so normalization is exact.
# =============================================================================
library(tidyverse); library(lubridate); library(nimble); library(coda); library(MCMCvis)

set.seed(123)

cat("\n============================================================\n")
cat("V4b NORMALIZED SOCIAL MOVEMENT + LATENT SEX MODEL\n")
cat("400 badgers | Student-t3 | normalized SG/peripheral | latent sex on phi, p0 and sigma\n")
cat("============================================================\n\n")

# ---- options ----------------------------------------------------------------
SAMPLE_N <- 400L
NITER <- 3000; NBURN <- 750; NCHAINS <- 2

MOVE_DF <- 3
if(MOVE_DF <= 2) stop("MOVE_DF must be > 2.")
T_SCALE_FACTOR <- sqrt((MOVE_DF-2)/MOVE_DF)
MOVE_MEAN_FACTOR <- sqrt(MOVE_DF-2)*sqrt(pi)/2*gamma((MOVE_DF-1)/2)/gamma(MOVE_DF/2)
cat("Movement kernel: bivariate Student-t, df =",MOVE_DF,"; standardized t scale =",round(T_SCALE_FACTOR,4),"; mean radial factor =",round(MOVE_MEAN_FACTOR,4),"\n")

# Fixed movement scales for this normalized architecture test, taken from the
# current 400-badger t3 short run. Replace with the long-run t3 estimates later.
SIGMA_MOVE_FIXED <- c(82.867,81.732)
SOCIAL_ZERO_CONST <- 50
cat("Fixed sigma_move for normalization:",paste(round(SIGMA_MOVE_FIXED,3),collapse=", "),"\n")

cmr_file <- "data/badger_final_CMRready_wDisease.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
spatial_file <- "data/spatial/V3_spatial_inputs_50m_2km.rds"
dir.create("results",showWarnings=FALSE)

# ---- sett cleaning -----------------------------------------------------------
sett_aliases <- c("\\bCHESTNUT\\b"="CHESNUT","\\bJACKS\\b"="JACKSMIREY","\\bGRAVEL\\b"="GRAVELPIT",
                  "\\bBUCKHOLE\\b"="BUCKHOLT","\\bTOPSETT\\b"="TOP","\\bFOXCUB\\b"="FOX","\\bGULLEY\\b"="GULLY",
                  "\\bBLACKBERRY\\b"="BRAMBLE","\\bBOC\\b"="BOG","\\bCEDARBANK\\b"="CEDAR","\\bCLAYTRAP\\b"="CLAY",
                  "\\bCLIFF\\b"="CLIFFFACE","\\bDINGLEVALLEY\\b"="DINGLE")

clean_sett <- function(x) x %>% as.character() %>% toupper() %>%
  str_replace_all("[[:punct:]]"," ") %>% str_squish() %>%
  str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>% str_replace_all(sett_aliases) %>%
  str_replace_all("\\s+","")

# ---- V3 spatial inputs -------------------------------------------------------
sp <- readRDS(spatial_file)
SG_mat <- sp$SG_mat; habitat_mat <- sp$habitat_mat; zone_mat <- sp$zone_mat
grid_xmin <- sp$xmin; grid_xmax <- sp$xmax; grid_ymin <- sp$ymin; grid_ymax <- sp$ymax
cell_size <- sp$cell_size; n_rows <- sp$n_rows; n_cols <- sp$n_cols
stopifnot(!anyNA(SG_mat),!anyNA(habitat_mat),!anyNA(zone_mat))
cat("\nV3 grid:",n_rows,"x",n_cols,"@",cell_size,"m =",n_rows*n_cols,"cells\n")

# ---- exact sett coordinates --------------------------------------------------
sett_raw <- read_csv(sett_file,show_col_types=FALSE)
name_col <- intersect(c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name"),names(sett_raw))[1]
x_col <- intersect(c("SettX","sett_x","X","x","Easting","easting"),names(sett_raw))[1]
y_col <- intersect(c("SettY","sett_y","Y","y","Northing","northing"),names(sett_raw))[1]
if(any(is.na(c(name_col,x_col,y_col)))) stop("Could not identify sett name/X/Y columns.")

sett_xy <- sett_raw %>% transmute(Sett_Clean=clean_sett(.data[[name_col]]),
                                  x=as.numeric(.data[[x_col]]),y=as.numeric(.data[[y_col]])) %>%
  filter(!is.na(Sett_Clean),Sett_Clean!="",!is.na(x),!is.na(y)) %>% distinct(Sett_Clean,.keep_all=TRUE)

# ---- capture data ------------------------------------------------------------
cmr_raw <- readRDS(cmr_file)
cmr <- cmr_raw %>% mutate(Sett_Clean=clean_sett(sett),primary_year=as.integer(primary_year),
                          trap_season=as.integer(trap_season)) %>% left_join(sett_xy,by="Sett_Clean")

cat("\nLive captures without XY:\n")
print(cmr %>% filter(has_live_capture,is.na(x)|is.na(y)) %>% count(Sett_Clean,sort=TRUE),n=Inf)
cmr <- cmr %>% filter(!has_live_capture | (!is.na(x)&!is.na(y)))

years <- min(cmr$primary_year,na.rm=TRUE):max(cmr$primary_year,na.rm=TRUE)
n_prim <- length(years); n_sec <- 4L
cmr <- cmr %>% mutate(primary=match(primary_year,years))
period_vec <- as.integer(match(floor(years/5)*5,sort(unique(floor(years/5)*5))))
n_periods <- max(period_vec)

# ---- entry group -------------------------------------------------------------
demog <- cmr_raw %>% arrange(tattoo,capture_date) %>% group_by(tattoo) %>%
  summarise(age_fc={a<-na.omit(age_fc); if(length(a)) as.character(a[1]) else NA_character_},.groups="drop") %>%
  mutate(entry_group=case_when(age_fc %in% c("Cub","Yearling")~1L,age_fc=="Adult"~2L,TRUE~NA_integer_))
cmr <- cmr %>% left_join(demog %>% select(tattoo,entry_group),by="tattoo")


# ---- sex ---------------------------------------------------------------------
# Partially observed individual sex:
#   0 = female, 1 = male, NA = unknown and therefore sampled in the model.
# If an individual has conflicting known records, use the modal known sex and flag it.
sex_col <- intersect(c("sex","Sex","SEX"),names(cmr_raw))[1]
if(is.na(sex_col)) stop("Could not identify a sex column in cmr_raw.")

sex_lookup <- cmr_raw %>% transmute(tattoo,sex_raw=as.character(.data[[sex_col]])) %>%
  mutate(sex_clean=toupper(str_squish(sex_raw)),
         sex_code=case_when(sex_clean %in% c("F","FEMALE")~0L,
                            sex_clean %in% c("M","MALE")~1L,
                            TRUE~NA_integer_)) %>%
  group_by(tattoo) %>%
  summarise(n_known_sexes=n_distinct(sex_code[!is.na(sex_code)]),
            sex_code={s<-sex_code[!is.na(sex_code)]; if(length(s)) as.integer(names(sort(table(s),decreasing=TRUE))[1]) else NA_integer_},
            .groups="drop")

if(any(sex_lookup$n_known_sexes>1L))
  warning("Some badgers have conflicting recorded sex values; modal known sex has been used. Inspect sex_lookup.")
cat("\nSex coding in full data:\n")
print(sex_lookup %>% count(sex_code,sort=TRUE),n=Inf)

# one live observation per badger x year x season
live <- cmr %>% filter(has_live_capture,!is.na(primary),!is.na(trap_season),!is.na(x),!is.na(y)) %>%
  arrange(tattoo,primary,trap_season,capture_date) %>% group_by(tattoo,primary,trap_season) %>%
  slice_tail(n=1) %>% ungroup()

eligible <- live %>% distinct(tattoo) %>% inner_join(demog,by="tattoo") %>%
  left_join(sex_lookup %>% select(tattoo,sex_code),by="tattoo") %>%
  filter(entry_group %in% 1:2,!tattoo %in% "007V")
if(!is.na(SAMPLE_N) && SAMPLE_N<nrow(eligible)) eligible <- eligible %>% slice_sample(n=SAMPLE_N)

ids <- eligible$tattoo; nind <- length(ids)
live <- live %>% filter(tattoo %in% ids); cmr <- cmr %>% filter(tattoo %in% ids)
cat("\nBadgers:",nind,"\n"); print(count(eligible,entry_group))
cat("\nObserved sex by entry group in model sample:\n")
print(eligible %>% count(entry_group,sex_code),n=Inf)

# ---- exact-sett detectors ----------------------------------------------------
detectors <- live %>% distinct(Sett_Clean,x,y) %>% arrange(Sett_Clean) %>% mutate(detector=row_number())
X <- as.matrix(detectors %>% select(x,y)); R <- nrow(X)
live <- live %>% left_join(detectors %>% select(Sett_Clean,detector),by="Sett_Clean")

# Used-detector audit against new state space
det_audit <- detectors %>% mutate(
  col_R=floor((x-grid_xmin)/cell_size)+1L,row_R=floor((grid_ymax-y)/cell_size)+1L,
  in_bounds=col_R>=1 & col_R<=n_cols & row_R>=1 & row_R<=n_rows)
if(any(!det_audit$in_bounds)){print(det_audit %>% filter(!in_bounds),n=Inf); stop("Used detector outside V3 grid.")}

det_audit <- det_audit %>% mutate(
  SG=SG_mat[cbind(row_R,col_R)],habitat=habitat_mat[cbind(row_R,col_R)],zone=zone_mat[cbind(row_R,col_R)])
cat("\nDetector-grid audit:\n"); print(count(det_audit,zone,habitat,SG,sort=TRUE),n=Inf)
if(any(det_audit$habitat!=1L)) warning("At least one used detector falls in habitat=0; inspect det_audit.")

# ---- individual metadata -----------------------------------------------------
meta <- live %>% arrange(tattoo,primary,trap_season,capture_date) %>% group_by(tattoo) %>%
  summarise(first=first(primary),first_detector=first(detector),entry_group=first(entry_group),.groups="drop") %>%
  right_join(tibble(tattoo=ids),by="tattoo") %>%
  left_join(eligible %>% select(tattoo,sex_code),by="tattoo") %>%
  arrange(match(tattoo,ids))

first <- as.integer(meta$first); first_detector <- as.integer(meta$first_detector)
entry_group <- as.integer(meta$entry_group); sex_data <- as.integer(meta$sex_code)
stopifnot(!anyNA(first),!anyNA(first_detector),!anyNA(entry_group))
if(any(!is.na(sex_data) & !sex_data %in% 0:1)) stop("Known sex values must be 0=female or 1=male.")

# ---- death information -------------------------------------------------------
death <- cmr %>% filter(has_pm_record,!is.na(primary)) %>% group_by(tattoo) %>%
  summarise(death_primary=min(primary),death_season={
    q<-trap_season[primary==min(primary)]; q<-q[!is.na(q)]; if(length(q)) min(q) else NA_integer_},.groups="drop")

death_primary <- rep(n_prim+1L,nind); death_season <- rep(NA_integer_,nind)
m <- match(ids,death$tattoo); has_death <- !is.na(m)
death_primary[has_death] <- death$death_primary[m[has_death]]
death_season[has_death] <- death$death_season[m[has_death]]
known_death <- death_primary<=n_prim
K <- rep(n_prim,nind); K[known_death] <- pmin(n_prim,death_primary[known_death]+1L)

# ---- encounters --------------------------------------------------------------
H <- array(1L,c(nind,n_sec,n_prim))
for(r in seq_len(nrow(live))) H[match(live$tattoo[r],ids),live$trap_season[r],live$primary[r]] <- live$detector[r]+1L

J <- matrix(n_sec,nind,n_prim)
for(i in seq_len(nind)) if(known_death[i] && !is.na(death_season[i]) && death_primary[i]<=n_prim)
  J[i,death_primary[i]] <- max(1L,death_season[i])

z_data <- matrix(NA_integer_,nind,n_prim)
for(i in seq_len(nind)){
  z_data[i,unique(live$primary[live$tattoo==ids[i]])] <- 1L
  if(known_death[i]){
    z_data[i,death_primary[i]] <- 1L
    if(death_primary[i]<n_prim) z_data[i,(death_primary[i]+1L):n_prim] <- 0L
  }
}

# sort histories for compact model loops
ord <- order(K-first)
ids<-ids[ord]; H<-H[ord,,,drop=FALSE]; J<-J[ord,,drop=FALSE]; z_data<-z_data[ord,,drop=FALSE]
first<-first[ord]; K<-K[ord]; first_detector<-first_detector[ord]; entry_group<-entry_group[ord]
sex_data<-sex_data[ord]; death_primary<-death_primary[ord]
unknown_sex_idx <- which(is.na(sex_data))
cat("\nUnknown sex in model sample:",length(unknown_sex_idx),"of",nind,"badgers\n")
N <- c(sum(K==first),nind)
if(any(K<first)) stop("ERROR: K < first.")
if(any(death_primary<first & death_primary<=n_prim)) stop("ERROR: known death before first spatial capture.")
if(N[1]==0L || N[1]==N[2]) stop("Current compact loops require both single- and multi-primary histories.")

# ---- initial values ----------------------------------------------------------
make_inits <- function(chain=1L){
  z_init <- matrix(0L,nind,n_prim)
  S_init <- array(NA_real_,c(nind,2,n_prim))
  eps_init <- array(NA_real_,c(nind,2,n_prim))
  
  sigma_move_init <- SIGMA_MOVE_FIXED
  
  for(i in seq_len(nind)){
    d <- live %>% filter(tattoo==ids[i]) %>% arrange(primary,trap_season,capture_date) %>%
      group_by(primary) %>% slice(1) %>% ungroup() %>% select(primary,x,y)
    
    xy <- matrix(NA_real_,n_prim,2)
    for(k in first[i]:K[i]){
      dk <- d %>% filter(primary==k)
      if(nrow(dk)) xy[k,] <- c(dk$x[1],dk$y[1]) else if(k>first[i]) xy[k,] <- xy[k-1,]
    }
    
    # Only the first annual AC is stochastic in the non-centred model.
    S_init[i,,first[i]] <- xy[first[i],]
    z_init[i,first[i]:K[i]] <- 1L
    
    # Innovations reconstruct exactly the same initial AC trajectory:
    # S[k] = S[k-1] + sigma_move[group] * eps[k].
    if(K[i]>first[i]) for(k in (first[i]+1L):K[i]){
      eps_init[i,1,k] <- (xy[k,1]-xy[k-1,1])/sigma_move_init[entry_group[i]]
      eps_init[i,2,k] <- (xy[k,2]-xy[k-1,2])/sigma_move_init[entry_group[i]]
    }
  }
  
  z_init[!is.na(z_data)] <- NA
  list(alpha_phi=c(qlogis(.70),qlogis(.68))+rnorm(2,0,.03),
       alpha_p=c(qlogis(.20),qlogis(.20))+rnorm(2,0,.03),
       alpha_logsigma=log(c(150,120))+rnorm(2,0,.03),
       beta_phi_sex=rnorm(1,0,.05),beta_p_sex=rnorm(1,0,.05),beta_sigma_sex=rnorm(1,0,.05),
       psi_sex=runif(2,.4,.6),
       sex={s<-rep(NA_integer_,nind); if(length(unknown_sex_idx)) s[unknown_sex_idx]<-rbinom(length(unknown_sex_idx),1,.5); s},
       beta_season_raw=rnorm(3,0,.03),beta_period_raw=rnorm(n_periods-1L,0,.03),
       beta_sg=runif(1,.2,.8),beta_peripheral=runif(1,.2,.8),
       S=S_init,eps=eps_init,z=z_init)
}
inits <- lapply(seq_len(NCHAINS),make_inits)

# ---- V3 initialization habitat audit -----------------------------------------
# Reconstruct the non-centred initial AC trajectories and verify that every
# living AC starts inside the grid and on habitat = 1.
bad_init <- list()
for(i in seq_len(nind)){
  g <- entry_group[i]
  sig0 <- SIGMA_MOVE_FIXED[g]
  sx <- inits[[1]]$S[i,1,first[i]]
  sy <- inits[[1]]$S[i,2,first[i]]
  
  for(k in first[i]:K[i]){
    if(k>first[i]){
      sx <- sx + sig0*inits[[1]]$eps[i,1,k]
      sy <- sy + sig0*inits[[1]]$eps[i,2,k]
    }
    col <- floor((sx-grid_xmin)/cell_size)+1L
    row <- floor((grid_ymax-sy)/cell_size)+1L
    inb <- row>=1L && row<=n_rows && col>=1L && col<=n_cols
    hab <- if(inb) habitat_mat[row,col] else NA_integer_
    z0 <- if(is.na(z_data[i,k])) 1L else z_data[i,k]
    
    if(z0==1L && (!inb || is.na(hab) || hab!=1L))
      bad_init[[length(bad_init)+1L]] <- tibble(i=i,tattoo=ids[i],k=k,year=years[k],
                                                x=sx,y=sy,row=row,col=col,in_bounds=inb,habitat=hab)
  }
}
bad_init <- bind_rows(bad_init)
if(nrow(bad_init)){print(bad_init,n=Inf); stop("Invalid living AC initial values detected.")}
cat("\nInitial non-centred AC habitat audit: PASS\n")

# ---- precompute normalized landscape opportunity -----------------------------
# For every CORE LAND origin cell and each entry group, calculate the baseline
# t3 movement-kernel mass available in:
#   1) the same mapped SG,
#   2) another mapped SG,
#   3) peripheral space.
#
# Because sigma_move is fixed in this V4a test, these probabilities are exact
# for the discretized 50 m landscape approximation and do not change in MCMC.

cat("\nPrecomputing t3 landscape-normalization arrays...\n")
grid_df <- sp$grid %>% sf::st_drop_geometry()
if(!all(c("row_R","col_R","SG_id","habitat","zone") %in% names(grid_df)))
  stop("sp$grid must contain row_R, col_R, SG_id, habitat and zone.")

grid_xy <- sf::st_coordinates(sp$grid)
land_idx <- which(grid_df$habitat==1L)
core_idx <- which(grid_df$habitat==1L & grid_df$zone==1L)

q_same <- array(1,c(2,n_rows,n_cols))
q_other <- array(0,c(2,n_rows,n_cols))
q_peripheral <- array(0,c(2,n_rows,n_cols))

for(grp in 1:2){
  sig <- SIGMA_MOVE_FIXED[grp]
  cat("  group",grp,"sigma =",sig,"m\n")
  
  for(a in seq_along(core_idx)){
    oi <- core_idx[a]
    if(a %% 500L==0L) cat("    origin",a,"of",length(core_idx),"\n")
    
    dx <- grid_xy[land_idx,1]-grid_xy[oi,1]
    dy <- grid_xy[land_idx,2]-grid_xy[oi,2]
    d2 <- dx^2+dy^2
    
    # For standardized bivariate t_nu movement:
    # kernel ∝ [1 + d^2 / {sigma^2 (nu-2)}]^(-(nu+2)/2)
    w <- (1+d2/(sig^2*(MOVE_DF-2)))^(-(MOVE_DF+2)/2)
    
    same <- grid_df$zone[land_idx]==1L & grid_df$SG_id[land_idx]==grid_df$SG_id[oi]
    other <- grid_df$zone[land_idx]==1L & grid_df$SG_id[land_idx]!=grid_df$SG_id[oi]
    per <- grid_df$zone[land_idx]==2L
    
    den <- sum(w)
    rr <- grid_df$row_R[oi]; cc <- grid_df$col_R[oi]
    q_same[grp,rr,cc] <- sum(w[same])/den
    q_other[grp,rr,cc] <- sum(w[other])/den
    q_peripheral[grp,rr,cc] <- sum(w[per])/den
  }
}

stopifnot(all(is.finite(q_same)),all(is.finite(q_other)),all(is.finite(q_peripheral)))
qs <- q_same+q_other+q_peripheral
core_rc <- cbind(grid_df$row_R[core_idx],grid_df$col_R[core_idx])
qsum_core <- c(qs[1,,][core_rc],qs[2,,][core_rc])
cat("Normalization check, max |sum(q)-1| on core cells:",max(abs(qsum_core-1)),"\n")

# The maximum possible positive log correction is -log(q_same). Check that the
# Poisson-zero constant safely exceeds it.
qsame_core <- c(q_same[1,,][core_rc],q_same[2,,][core_rc])
min_q_same <- min(qsame_core)
cat("Minimum same-SG baseline mass:",min_q_same,
    "; max possible same-SG log correction:",-log(min_q_same),"\n")
if(SOCIAL_ZERO_CONST <= -log(min_q_same)+5)
  stop("SOCIAL_ZERO_CONST is too small for the normalized likelihood correction.")

# ---- V4a model ---------------------------------------------------------------
code_V3 <- nimbleCode({
  
  for(grp in 1:2){
    alpha_phi[grp] ~ dnorm(qlogis(.70),sd=1.5)
    alpha_p[grp] ~ dnorm(qlogis(.15),sd=1.5)
    alpha_logsigma[grp] ~ dnorm(log(250),sd=1)
    sigma_move[grp] <- SIGMA_MOVE_FIXED[grp]
    mean_move[grp] <- sigma_move[grp]*MOVE_MEAN_FACTOR
    
    psi_sex[grp] ~ dbeta(1,1)
    
    phi_female[grp] <- ilogit(alpha_phi[grp])
    phi_male[grp] <- ilogit(alpha_phi[grp]+beta_phi_sex)
    p0_female[grp] <- ilogit(alpha_p[grp])
    p0_male[grp] <- ilogit(alpha_p[grp]+beta_p_sex)
    sigma_female[grp] <- exp(alpha_logsigma[grp])
    sigma_male[grp] <- exp(alpha_logsigma[grp]+beta_sigma_sex)
  }
  
  beta_phi_sex ~ dnorm(0,sd=1)
  beta_p_sex ~ dnorm(0,sd=1)
  beta_sigma_sex ~ dnorm(0,sd=.75)
  
  for(i in 1:N[2]){
    sex[i] ~ dbern(psi_sex[entry_group[i]])
    phi_i[i] <- ilogit(alpha_phi[entry_group[i]]+beta_phi_sex*sex[i])
    sigma_i[i] <- exp(alpha_logsigma[entry_group[i]]+beta_sigma_sex*sex[i])
  }
  
  beta_sg ~ dexp(1)
  beta_peripheral ~ dexp(1)
  sg_multiplier <- exp(-beta_sg)
  peripheral_multiplier <- exp(-beta_peripheral)
  
  for(s in 1:3){beta_season_raw[s] ~ dnorm(0,sd=1); beta_season[s] <- beta_season_raw[s]}
  beta_season[4] <- -sum(beta_season_raw[1:3])
  
  for(p in 1:(n_periods-1)){beta_period_raw[p] ~ dnorm(0,sd=1); beta_period[p] <- beta_period_raw[p]}
  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods-1)])
  
  # Single-primary histories
  for(i in 1:N[1]){
    z[i,first[i]] ~ dbern(1)
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
    state_ok[i,first[i]] ~ dbern(in_bounds[i,first[i]]*habitat_here[i,first[i]])
    
    g[i,first[i],1] <- 0
    for(r in 1:R){
      D[i,r,first[i]] <- sqrt(pow(S[i,1,first[i]]-X[r,1],2)+pow(S[i,2,first[i]]-X[r,2],2))
      g[i,first[i],r+1] <- exp(-pow(D[i,r,first[i]],2)/(2*pow(sigma_i[i],2)))
    }
    G[i,first[i]] <- sum(g[i,first[i],1:(R+1)])
    
    for(j in 1:J[i,first[i]]){
      lp0[i,j,first[i]] <- alpha_p[entry_group[i]]+beta_p_sex*sex[i]+beta_season[j]+beta_period[period_vec[first[i]]]
      p0[i,j,first[i]] <- ilogit(lp0[i,j,first[i]])
      lambda0[i,j,first[i]] <- -log(1-p0[i,j,first[i]])
      P[i,j,first[i]] <- 1-exp(-lambda0[i,j,first[i]]*G[i,first[i]])
      captureProb[i,j,first[i]] <- step(H[i,j,first[i]]-2)*(g[i,first[i],H[i,j,first[i]]]/
                                                              (G[i,first[i]]+1e-10))*P[i,j,first[i]]+(1-step(H[i,j,first[i]]-2))*(1-P[i,j,first[i]])
      Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])
    }
  }
  
  # Multi-primary histories
  for(i in (N[1]+1):N[2]){
    z[i,first[i]] ~ dbern(1)
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
    state_ok[i,first[i]] ~ dbern(in_bounds[i,first[i]]*habitat_here[i,first[i]])
    
    g[i,first[i],1] <- 0
    for(r in 1:R){
      D[i,r,first[i]] <- sqrt(pow(S[i,1,first[i]]-X[r,1],2)+pow(S[i,2,first[i]]-X[r,2],2))
      g[i,first[i],r+1] <- exp(-pow(D[i,r,first[i]],2)/(2*pow(sigma_i[i],2)))
    }
    G[i,first[i]] <- sum(g[i,first[i],1:(R+1)])
    
    for(j in 1:J[i,first[i]]){
      lp0[i,j,first[i]] <- alpha_p[entry_group[i]]+beta_p_sex*sex[i]+beta_season[j]+beta_period[period_vec[first[i]]]
      p0[i,j,first[i]] <- ilogit(lp0[i,j,first[i]])
      lambda0[i,j,first[i]] <- -log(1-p0[i,j,first[i]])
      P[i,j,first[i]] <- 1-exp(-lambda0[i,j,first[i]]*G[i,first[i]])
      captureProb[i,j,first[i]] <- step(H[i,j,first[i]]-2)*(g[i,first[i],H[i,j,first[i]]]/
                                                              (G[i,first[i]]+1e-10))*P[i,j,first[i]]+(1-step(H[i,j,first[i]]-2))*(1-P[i,j,first[i]])
      Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])
    }
    
    for(k in (first[i]+1):K[i]){
      Palive[i,k-1] <- z[i,k-1]*phi_i[i]
      z[i,k] ~ dbern(Palive[i,k-1]*step(death_primary[i]-k))
      
      # HEAVY-TAILED NON-CENTRED movement. The bivariate-t scale matrix is
      # chosen so each innovation coordinate has variance 1, retaining the
      # Gaussian model's interpretation of sigma_move as per-axis movement SD.
      eps[i,1:2,k] ~ dmvt(mu=eps_zero[1:2],scale=eps_scale[1:2,1:2],df=MOVE_DF)
      S[i,1,k] <- S[i,1,k-1]+sigma_move[entry_group[i]]*eps[i,1,k]
      S[i,2,k] <- S[i,2,k-1]+sigma_move[entry_group[i]]*eps[i,2,k]
      moveDist[i,k-1] <- sigma_move[entry_group[i]]*sqrt(pow(eps[i,1,k],2)+pow(eps[i,2,k],2))
      
      # metre coordinates -> 50 m landscape matrix
      col_raw[i,k] <- trunc((S[i,1,k]-grid_xmin)/cell_size)+1
      row_raw[i,k] <- trunc((grid_ymax-S[i,2,k])/cell_size)+1
      col_S[i,k] <- max(1,min(n_cols,col_raw[i,k]))
      row_S[i,k] <- max(1,min(n_rows,row_raw[i,k]))
      in_bounds[i,k] <- step(S[i,1,k]-grid_xmin)*step(grid_xmax-S[i,1,k])*
        step(S[i,2,k]-grid_ymin)*step(grid_ymax-S[i,2,k])
      
      habitat_here[i,k] <- habitat_mat[row_S[i,k],col_S[i,k]]
      SG_here[i,k] <- SG_mat[row_S[i,k],col_S[i,k]]
      zone_here[i,k] <- zone_mat[row_S[i,k],col_S[i,k]]
      
      # living AC must occupy valid land inside the state space
      valid_state[i,k] <- in_bounds[i,k]*habitat_here[i,k]
      state_prob[i,k] <- (1-z[i,k])+z[i,k]*valid_state[i,k]
      state_ok[i,k] ~ dbern(state_prob[i,k])
      
      # NORMALIZED social/peripheral movement correction.
      # Applied only to living transitions whose previous AC is in a mapped core SG.
      # q_* are baseline destination-class probabilities under the SAME t3 kernel.
      apply_social[i,k] <- z[i,k]*equals(zone_here[i,k-1],1)
      q_same_here[i,k] <- q_same[entry_group[i],row_S[i,k-1],col_S[i,k-1]]
      q_other_here[i,k] <- q_other[entry_group[i],row_S[i,k-1],col_S[i,k-1]]
      q_per_here[i,k] <- q_peripheral[entry_group[i],row_S[i,k-1],col_S[i,k-1]]
      
      social_Z[i,k] <- q_same_here[i,k]+q_other_here[i,k]*sg_multiplier+
        q_per_here[i,k]*peripheral_multiplier
      
      dest_other_core[i,k] <- equals(zone_here[i,k],1)*(1-equals(SG_here[i,k],SG_here[i,k-1]))
      dest_peripheral[i,k] <- equals(zone_here[i,k],2)
      log_R_dest[i,k] <- -beta_sg*dest_other_core[i,k]-beta_peripheral*dest_peripheral[i,k]
      log_social_correction[i,k] <- apply_social[i,k]*(log_R_dest[i,k]-log(social_Z[i,k]))
      
      # zeros trick: log P(0 | lambda) = -lambda, so this contributes
      # log_social_correction plus an irrelevant constant -SOCIAL_ZERO_CONST.
      social_lambda[i,k] <- SOCIAL_ZERO_CONST-log_social_correction[i,k]
      social_zero[i,k] ~ dpois(social_lambda[i,k])
      
      g[i,k,1] <- 0
      for(r in 1:R){
        D[i,r,k] <- sqrt(pow(S[i,1,k]-X[r,1],2)+pow(S[i,2,k]-X[r,2],2))
        g[i,k,r+1] <- exp(-pow(D[i,r,k],2)/(2*pow(sigma_i[i],2)))
      }
      G[i,k] <- sum(g[i,k,1:(R+1)])
      
      for(j in 1:J[i,k]){
        lp0[i,j,k] <- alpha_p[entry_group[i]]+beta_p_sex*sex[i]+beta_season[j]+beta_period[period_vec[k]]
        p0[i,j,k] <- ilogit(lp0[i,j,k])
        lambda0[i,j,k] <- -log(1-p0[i,j,k])
        P[i,j,k] <- (1-exp(-lambda0[i,j,k]*G[i,k]))*z[i,k]
        captureProb[i,j,k] <- step(H[i,j,k]-2)*(g[i,k,H[i,j,k]]/(G[i,k]+1e-10))*P[i,j,k]+
          (1-step(H[i,j,k]-2))*(1-P[i,j,k])
        Ones[i,j,k] ~ dbern(captureProb[i,j,k])
      }
    }
  }
})


# ---- build -------------------------------------------------------------------
eps_zero <- c(0,0)
eps_scale <- diag(T_SCALE_FACTOR^2,2)

consts <- list(R=R,N=N,K=as.integer(K),J=J,first=as.integer(first),X=X,H=H,
               n_periods=n_periods,period_vec=period_vec,entry_group=entry_group,death_primary=death_primary,
               grid_xmin=grid_xmin,grid_xmax=grid_xmax,grid_ymin=grid_ymin,grid_ymax=grid_ymax,
               cell_size=cell_size,n_rows=n_rows,n_cols=n_cols,MOVE_DF=MOVE_DF,
               MOVE_MEAN_FACTOR=MOVE_MEAN_FACTOR,eps_zero=eps_zero,eps_scale=eps_scale,
               SIGMA_MOVE_FIXED=SIGMA_MOVE_FIXED,SOCIAL_ZERO_CONST=SOCIAL_ZERO_CONST)

social_zero_data <- matrix(0L,nind,n_prim)

data_list <- list(Ones=array(1L,dim(H)),z=z_data,sex=sex_data,state_ok=matrix(1L,nind,n_prim),
                  social_zero=social_zero_data,habitat_mat=habitat_mat,SG_mat=SG_mat,zone_mat=zone_mat,
                  q_same=q_same,q_other=q_other,q_peripheral=q_peripheral)

# ---- sanity check: make sure this is NOT the Gaussian epsX/epsY model -------
code_txt <- paste(deparse(code_V3),collapse=" ")
if(!grepl("dmvt",code_txt)) stop("STOP: code_V3 does not contain dmvt; wrong model loaded.")
if(grepl("epsX|epsY",code_txt)) stop("STOP: Gaussian epsX/epsY code detected; wrong model loaded.")
cat("\nHeavy-tail code check: PASS (dmvt present; epsX/epsY absent)\n")
if(!grepl("social_Z",code_txt) || !grepl("beta_peripheral",code_txt))
  stop("STOP: normalized SG/peripheral code not found.")
cat("Normalized social/peripheral code check: PASS\n")
if(!grepl("sex\\[i\\] ~ dbern",code_txt) || !grepl("psi_sex",code_txt))
  stop("STOP: latent-sex code not found.")
cat("Latent-sex code check: PASS\n")

message("\nBuilding V4b normalized Student-t3 social-movement + LATENT SEX model...")
model_V3 <- nimbleModel(code_V3,constants=consts,data=data_list,inits=inits[[1]],
                        dimensions=list(Ones=dim(H),z=dim(z_data),state_ok=c(nind,n_prim),
                                        social_zero=c(nind,n_prim)),
                        check=TRUE,calculate=FALSE)

print(model_V3$initializeInfo())
lp <- model_V3$calculate()
cat("\nInitial log probability:",lp,"\n")
if(!is.finite(lp)){
  stoch_nodes <- model_V3$getNodeNames(stochOnly=TRUE,includeData=TRUE)
  node_lp <- sapply(stoch_nodes,function(x)model_V3$getLogProb(x))
  print(tibble(node=stoch_nodes,logProb=node_lp) %>% filter(!is.finite(logProb)),n=Inf)
  stop("V4b initial log probability is not finite.")
}

message("\nCompiling model...")
cModel_V3 <- compileNimble(model_V3,resetFunctions=TRUE)

monitors <- c("alpha_phi","alpha_p","alpha_logsigma","psi_sex","sex",
              "beta_phi_sex","beta_p_sex","beta_sigma_sex",
              "phi_female","phi_male","p0_female","p0_male","sigma_female","sigma_male",
              "sigma_move","mean_move","beta_season","beta_period",
              "beta_sg","beta_peripheral","sg_multiplier","peripheral_multiplier")
config_V3 <- configureMCMC(model_V3,monitors=monitors,thin=1)

# Each subsequent annual movement innovation is one bivariate-t stochastic node.
for(i in (N[1]+1L):N[2]) for(k in (first[i]+1L):K[i]){
  node <- paste0("eps[",i,", 1:2, ",k,"]")
  config_V3$removeSamplers(node,print=FALSE)
  config_V3$addSampler(target=node,type="AF_slice")
}

Rmcmc_V3 <- buildMCMC(config_V3)
message("\nCompiling MCMC...")
cMCMC_V3 <- compileNimble(Rmcmc_V3,project=cModel_V3,resetFunctions=TRUE)

# ---- run ---------------------------------------------------------------------
message("\nRunning V4b NORMALIZED Student-t3 SG/peripheral + LATENT SEX development model...")
runtime_V3 <- system.time(samples_V3 <- runMCMC(cMCMC_V3,niter=NITER,nburnin=NBURN,nchains=NCHAINS,
                                                inits=inits,samplesAsCodaMCMC=TRUE,progressBar=TRUE,setSeed=3451:(3451+NCHAINS-1L)))
print(runtime_V3)

saveRDS(list(samples=samples_V3,runtime=runtime_V3,ids=ids,sex_data=sex_data,unknown_sex_idx=unknown_sex_idx,detectors=detectors,det_audit=det_audit,
             settings=list(sample_n=SAMPLE_N,niter=NITER,nburn=NBURN,nchains=NCHAINS,
                           ac_sampler="AF_slice_bivariate_t",parameterisation="noncentred",movement_kernel="bivariate_Student_t",move_df=MOVE_DF,sg_model="normalized_core_SG_plus_peripheral",sex_model="partially_observed_latent_sex_phi_p0_detection_sigma",movement_sigma="fixed_for_normalization_test",sigma_move_fixed=SIGMA_MOVE_FIXED),
             spatial_file=spatial_file),
        paste0("results/RD_SCR_V4b_t",MOVE_DF,"_NORMALIZED_SG_PERIPH_LATENT_SEX_SHORT_",nind,"_badgers.rds"))

MCMCsummary(samples_V3)
gelman.diag(samples_V3,multivariate=FALSE)
effectiveSize(samples_V3)

if(length(unknown_sex_idx)){
  smat <- as.matrix(samples_V3)
  sex_cols <- paste0("sex[",unknown_sex_idx,"]")
  keep <- sex_cols[sex_cols %in% colnames(smat)]
  sex_posterior <- tibble(i=unknown_sex_idx[match(keep,sex_cols)],
                          tattoo=ids[unknown_sex_idx[match(keep,sex_cols)]],
                          entry_group=entry_group[unknown_sex_idx[match(keep,sex_cols)]],
                          p_male=colMeans(smat[,keep,drop=FALSE])) %>% arrange(desc(p_male))
  cat("\nPosterior P(male) for unknown-sex badgers:\n")
  print(sex_posterior,n=Inf)
} else {
  sex_posterior <- tibble()
  cat("\nNo unknown-sex badgers in this 400-individual sample.\n")
}