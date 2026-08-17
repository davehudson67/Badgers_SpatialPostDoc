# =============================================================================
# WOODCHESTER ROBUST-DESIGN SPATIAL CMR - M2
#
# M2:
# - latent first-year AC
# - direct bivariate-normal annual AC transition
# - Rayleigh annual displacement implied by XY transition
# - actual sett coordinates
# - half-normal spatial detection
# - annual survival
# - 4 seasonal secondary occasions
# - sum-to-zero season + 5-year detection effects
#
# Group 1 = first caught Cub/Yearling
# Group 2 = first caught Adult
# =============================================================================

library(tidyverse)
library(lubridate)
library(nimble)
library(coda)
library(MCMCvis)

set.seed(123)

# =============================================================================
# 0. OPTIONS
# =============================================================================

SAMPLE_N <- NA_integer_
NITER <- 12000
NBURN <- 3000
NCHAINS <- 2
AC_BUFFER <- 2000

cmr_file <- "data/badger_final_CMRready_wDisease.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
dir.create("results", showWarnings=FALSE)

# =============================================================================
# 1. CLEAN SETT NAMES
# =============================================================================

sett_aliases <- c(
  "\\bCHESTNUT\\b"="CHESNUT", "\\bJACKS\\b"="JACKSMIREY",
  "\\bGRAVEL\\b"="GRAVELPIT", "\\bBUCKHOLE\\b"="BUCKHOLT",
  "\\bTOPSETT\\b"="TOP", "\\bFOXCUB\\b"="FOX",
  "\\bGULLEY\\b"="GULLY", "\\bBLACKBERRY\\b"="BRAMBLE",
  "\\bBOC\\b"="BOG", "\\bCEDARBANK\\b"="CEDAR",
  "\\bCLAYTRAP\\b"="CLAY", "\\bCLIFF\\b"="CLIFFFACE",
  "\\bDINGLEVALLEY\\b"="DINGLE"
)

clean_sett <- function(x) {
  x %>% as.character() %>% toupper() %>%
    str_replace_all("[[:punct:]]"," ") %>% str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all(sett_aliases) %>% str_replace_all("\\s+","")
}

# =============================================================================
# 2. LOAD SETT COORDINATES
# =============================================================================

sett_raw <- read_csv(sett_file, show_col_types=FALSE)

name_candidates <- c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name")
x_candidates <- c("SettX","sett_x","X","x","Easting","easting")
y_candidates <- c("SettY","sett_y","Y","y","Northing","northing")

name_col <- intersect(name_candidates,names(sett_raw))[1]
x_col <- intersect(x_candidates,names(sett_raw))[1]
y_col <- intersect(y_candidates,names(sett_raw))[1]

if (any(is.na(c(name_col,x_col,y_col)))) stop("Could not identify sett name/X/Y columns.")

sett_xy <- sett_raw %>%
  transmute(Sett_Clean=clean_sett(.data[[name_col]]),
            x=as.numeric(.data[[x_col]]), y=as.numeric(.data[[y_col]])) %>%
  filter(!is.na(Sett_Clean),Sett_Clean!="",!is.na(x),!is.na(y)) %>%
  distinct(Sett_Clean,.keep_all=TRUE)

# =============================================================================
# 3. LOAD CMR DATA
# =============================================================================

cmr_raw <- readRDS(cmr_file)

cmr <- cmr_raw %>%
  mutate(Sett_Clean=clean_sett(sett),
         primary_year=as.integer(primary_year),
         trap_season=as.integer(trap_season)) %>%
  left_join(sett_xy,by="Sett_Clean")

# =============================================================================
# 4. REMOVE LIVE CAPTURES WITHOUT XY
# =============================================================================

excluded_xy <- cmr %>%
  filter(has_live_capture,is.na(x) | is.na(y)) %>%
  count(Sett_Clean,sort=TRUE)

cat("\n--- LIVE CAPTURES EXCLUDED: NO XY ---\n")
print(excluded_xy,n=Inf)

n_live_before <- sum(cmr$has_live_capture,na.rm=TRUE)
cmr <- cmr %>% filter(!has_live_capture | (!is.na(x) & !is.na(y)))
n_live_after <- sum(cmr$has_live_capture,na.rm=TRUE)

cat("\nLive captures before:",n_live_before,
    "\nLive captures after:",n_live_after,
    "\nRemoved:",n_live_before-n_live_after,"\n")

all_live_ids <- cmr_raw %>% filter(has_live_capture) %>% distinct(tattoo)
spatial_live_ids <- cmr %>% filter(has_live_capture) %>% distinct(tattoo)
lost_badgers <- anti_join(all_live_ids,spatial_live_ids,by="tattoo")

cat("Badgers with no spatially usable live capture:",nrow(lost_badgers),"\n")

# =============================================================================
# 5. YEAR + PERIOD INDEX
# =============================================================================

min_year <- min(cmr$primary_year,na.rm=TRUE)
max_year <- max(cmr$primary_year,na.rm=TRUE)
years <- min_year:max_year
n_prim <- length(years)
n_sec <- 4L

cmr <- cmr %>% mutate(primary=match(primary_year,years))

year_lookup <- tibble(primary_year=years) %>%
  mutate(period_start=floor(primary_year/5)*5,
         period_id=match(period_start,sort(unique(period_start))))

period_vec <- as.integer(year_lookup$period_id)
n_periods <- max(period_vec)

cat("\nStudy years:",min_year,"-",max_year,
    "\nPrimary occasions:",n_prim,
    "\nDetection periods:",n_periods,"\n")

# =============================================================================
# 6. ENTRY GROUP
# =============================================================================

demog <- cmr_raw %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  summarise(age_fc={
    z <- na.omit(age_fc)
    if (length(z)) as.character(z[1]) else NA_character_
  },.groups="drop") %>%
  mutate(entry_group=case_when(
    age_fc %in% c("Cub","Yearling") ~ 1L,
    age_fc=="Adult" ~ 2L,
    TRUE ~ NA_integer_
  ))

cmr <- cmr %>% left_join(demog %>% select(tattoo,entry_group),by="tattoo")

# =============================================================================
# 7. ONE LIVE LOCATION PER SEASON
# =============================================================================

live <- cmr %>%
  filter(has_live_capture,!is.na(primary),!is.na(trap_season),
         !is.na(x),!is.na(y)) %>%
  arrange(tattoo,primary,trap_season,capture_date) %>%
  group_by(tattoo,primary,trap_season) %>%
  slice_tail(n=1) %>% ungroup()

cat("\nQuarterly spatial records:",nrow(live),
    "\nBadgers represented:",n_distinct(live$tattoo),
    "\nSetts represented:",n_distinct(live$Sett_Clean),"\n")

# =============================================================================
# 8. ELIGIBLE INDIVIDUALS
# =============================================================================

eligible <- live %>%
  distinct(tattoo) %>%
  inner_join(demog,by="tattoo") %>%
  filter(entry_group %in% 1:2)

exclude_ids <- "007V"
eligible <- eligible %>% filter(!tattoo %in% exclude_ids)

cat("\nEligible badgers:",nrow(eligible),"\n")
cat("Excluded impossible histories:",paste(exclude_ids,collapse=", "),"\n")

if (!is.na(SAMPLE_N) && SAMPLE_N<nrow(eligible))
  eligible <- eligible %>% slice_sample(n=SAMPLE_N)

ids <- eligible$tattoo
live <- live %>% filter(tattoo %in% ids)
cmr <- cmr %>% filter(tattoo %in% ids)
nind <- length(ids)

cat("Badgers used:",nind,"\n")
print(count(eligible,entry_group))

# =============================================================================
# 9. DETECTORS + AC DOMAIN
# =============================================================================

detectors <- live %>%
  distinct(Sett_Clean,x,y) %>%
  arrange(Sett_Clean) %>%
  mutate(detector=row_number())

X <- as.matrix(detectors %>% select(x,y))
R <- nrow(X)

live <- live %>%
  left_join(detectors %>% select(Sett_Clean,detector),by="Sett_Clean")

xmin <- min(X[,1])-AC_BUFFER
xmax <- max(X[,1])+AC_BUFFER
ymin <- min(X[,2])-AC_BUFFER
ymax <- max(X[,2])+AC_BUFFER

cat("\nSpatial detectors:",R,
    "\nAC domain X:",xmin,"-",xmax,
    "\nAC domain Y:",ymin,"-",ymax,"\n")

# =============================================================================
# 10. INDIVIDUAL METADATA
# =============================================================================

ind_meta <- live %>%
  arrange(tattoo,primary,trap_season,capture_date) %>%
  group_by(tattoo) %>%
  summarise(first=first(primary),
            first_detector=first(detector),
            entry_group=first(entry_group),
            .groups="drop") %>%
  right_join(tibble(tattoo=ids),by="tattoo") %>%
  arrange(match(tattoo,ids))

first <- as.integer(ind_meta$first)
first_detector <- as.integer(ind_meta$first_detector)
entry_group <- as.integer(ind_meta$entry_group)

stopifnot(!anyNA(first),!anyNA(first_detector),!anyNA(entry_group))

cat("\nEntry groups:\n")
print(table(entry_group))

# =============================================================================
# 11. DEATH INFORMATION
# =============================================================================

death <- cmr %>%
  filter(has_pm_record,!is.na(primary)) %>%
  group_by(tattoo) %>%
  summarise(
    death_primary=min(primary),
    death_season={
      x <- trap_season[primary==min(primary)]
      x <- x[!is.na(x)]
      if (length(x)) min(x) else NA_integer_
    },
    .groups="drop"
  )

death_primary <- rep(n_prim+1L,nind)
death_season <- rep(NA_integer_,nind)

m <- match(ids,death$tattoo)
has_death <- !is.na(m)

death_primary[has_death] <- death$death_primary[m[has_death]]
death_season[has_death] <- death$death_season[m[has_death]]

known_death <- death_primary<=n_prim
K <- rep(n_prim,nind)
K[known_death] <- pmin(n_prim,death_primary[known_death]+1L)

# =============================================================================
# 12. ENCOUNTER ARRAY
# =============================================================================

H <- array(1L,dim=c(nind,n_sec,n_prim))

for (r in seq_len(nrow(live))) {
  i <- match(live$tattoo[r],ids)
  H[i,live$trap_season[r],live$primary[r]] <- live$detector[r]+1L
}

J <- matrix(n_sec,nind,n_prim)

for (i in seq_len(nind)) {
  if (known_death[i] && !is.na(death_season[i])) {
    k <- death_primary[i]
    if (k<=n_prim) J[i,k] <- max(1L,death_season[i])
  }
}

# =============================================================================
# 13. KNOWN ALIVE / DEAD STATES
# =============================================================================

z_data <- matrix(NA_integer_,nind,n_prim)

for (i in seq_len(nind)) {
  captured_years <- unique(live$primary[live$tattoo==ids[i]])
  z_data[i,captured_years] <- 1L
  
  if (known_death[i]) {
    z_data[i,death_primary[i]] <- 1L
    if (death_primary[i]<n_prim)
      z_data[i,(death_primary[i]+1L):n_prim] <- 0L
  }
}

# =============================================================================
# 14. SORT HISTORIES
# =============================================================================

ord <- order(K-first)

ids <- ids[ord]
H <- H[ord,,,drop=FALSE]
J <- J[ord,,drop=FALSE]
z_data <- z_data[ord,,drop=FALSE]
first <- first[ord]
K <- K[ord]
first_detector <- first_detector[ord]
entry_group <- entry_group[ord]
death_primary <- death_primary[ord]

N <- c(sum(K==first),nind)

if (any(K<first)) stop("ERROR: At least one individual has K < first.")
if (any(death_primary<first & death_primary<=n_prim))
  stop("ERROR: Known death occurs before first spatial capture.")
if (N[1]==0L || N[1]==N[2])
  stop("Current NIMBLE loops require both history types.")

cat("\nSingle-primary:",N[1],
    "\nMulti-primary:",N[2]-N[1],"\n")

# =============================================================================
# 15. INITIAL VALUES
# =============================================================================

make_inits <- function(chain=1L) {
  
  z_init <- matrix(0L,nind,n_prim)
  S_init <- array(NA_real_,dim=c(nind,2,n_prim))
  
  for (i in seq_len(nind)) {
    
    dat <- live %>%
      filter(tattoo==ids[i]) %>%
      group_by(primary) %>%
      summarise(x=mean(x),y=mean(y),.groups="drop")
    
    xy <- matrix(NA_real_,n_prim,2)
    
    for (k in first[i]:K[i]) {
      dk <- dat %>% filter(primary==k)
      if (nrow(dk)) xy[k,] <- c(dk$x[1],dk$y[1])
      else if (k>first[i]) xy[k,] <- xy[k-1,]
    }
    
    S_init[i,,first[i]:K[i]] <- t(xy[first[i]:K[i],,drop=FALSE])
    z_init[i,first[i]:K[i]] <- 1L
  }
  
  z_init[!is.na(z_data)] <- NA
  
  list(
    alpha_phi=c(qlogis(.70),qlogis(.68))+rnorm(2,0,.03),
    alpha_p=c(qlogis(.20),qlogis(.20))+rnorm(2,0,.03),
    alpha_logsigma=log(c(135,95))+rnorm(2,0,.03),
    alpha_logmove=log(c(70,70))+rnorm(2,0,.03),
    beta_season_raw=rnorm(3,0,.03),
    beta_period_raw=rnorm(n_periods-1L,0,.03),
    S=S_init,z=z_init
  )
}

inits <- lapply(seq_len(NCHAINS),make_inits)

# =============================================================================
# 16. M2 NIMBLE MODEL
# =============================================================================

code_M2 <- nimbleCode({
  
  # ---------------------------------------------------------------------------
  # POPULATION PARAMETERS
  # ---------------------------------------------------------------------------
  
  for (grp in 1:2) {
    alpha_phi[grp] ~ dnorm(qlogis(.70),sd=1.5)
    phi_annual[grp] <- ilogit(alpha_phi[grp])
    
    alpha_p[grp] ~ dnorm(qlogis(.15),sd=1.5)
    
    alpha_logsigma[grp] ~ dnorm(log(250),sd=1)
    sigma[grp] <- exp(alpha_logsigma[grp])
    
    alpha_logmove[grp] ~ dnorm(log(100),sd=1)
    sigma_move[grp] <- exp(alpha_logmove[grp])
    
    # Mean radial displacement implied by Rayleigh movement distance.
    mean_move[grp] <- sigma_move[grp]*sqrt(3.141593/2)
  }
  
  # ---------------------------------------------------------------------------
  # SUM-TO-ZERO DETECTION EFFECTS
  # ---------------------------------------------------------------------------
  
  for (s in 1:3) {
    beta_season_raw[s] ~ dnorm(0,sd=1)
    beta_season[s] <- beta_season_raw[s]
  }
  beta_season[4] <- -sum(beta_season_raw[1:3])
  
  for (p in 1:(n_periods-1)) {
    beta_period_raw[p] ~ dnorm(0,sd=1)
    beta_period[p] <- beta_period_raw[p]
  }
  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods-1)])
  
  # ---------------------------------------------------------------------------
  # SINGLE-PRIMARY HISTORIES
  # ---------------------------------------------------------------------------
  
  for (i in 1:N[1]) {
    
    z[i,first[i]] ~ dbern(1)
    
    # Latent first annual AC.
    S[i,1,first[i]] ~ dunif(xmin,xmax)
    S[i,2,first[i]] ~ dunif(ymin,ymax)
    
    g[i,first[i],1] <- 0
    
    for (r in 1:R) {
      D[i,r,first[i]] <- sqrt(
        pow(S[i,1,first[i]]-X[r,1],2) +
          pow(S[i,2,first[i]]-X[r,2],2)
      )
      
      g[i,first[i],r+1] <- exp(
        -pow(D[i,r,first[i]],2) /
          (2*pow(sigma[entry_group[i]],2))
      )
    }
    
    G[i,first[i]] <- sum(g[i,first[i],1:(R+1)])
    
    for (j in 1:J[i,first[i]]) {
      
      lp0[i,j,first[i]] <- alpha_p[entry_group[i]] +
        beta_season[j] + beta_period[period_vec[first[i]]]
      
      p0[i,j,first[i]] <- ilogit(lp0[i,j,first[i]])
      lambda0[i,j,first[i]] <- -log(1-p0[i,j,first[i]])
      P[i,j,first[i]] <- 1-exp(-lambda0[i,j,first[i]]*G[i,first[i]])
      
      captureProb[i,j,first[i]] <-
        step(H[i,j,first[i]]-2) *
        g[i,first[i],H[i,j,first[i]]] /
        (G[i,first[i]]+1e-10) *
        P[i,j,first[i]] +
        (1-step(H[i,j,first[i]]-2)) *
        (1-P[i,j,first[i]])
      
      Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])
    }
  }
  
  # ---------------------------------------------------------------------------
  # MULTI-PRIMARY HISTORIES
  # ---------------------------------------------------------------------------
  
  for (i in (N[1]+1):N[2]) {
    
    z[i,first[i]] ~ dbern(1)
    
    # Latent first annual AC.
    S[i,1,first[i]] ~ dunif(xmin,xmax)
    S[i,2,first[i]] ~ dunif(ymin,ymax)
    
    g[i,first[i],1] <- 0
    
    for (r in 1:R) {
      D[i,r,first[i]] <- sqrt(
        pow(S[i,1,first[i]]-X[r,1],2) +
          pow(S[i,2,first[i]]-X[r,2],2)
      )
      
      g[i,first[i],r+1] <- exp(
        -pow(D[i,r,first[i]],2) /
          (2*pow(sigma[entry_group[i]],2))
      )
    }
    
    G[i,first[i]] <- sum(g[i,first[i],1:(R+1)])
    
    for (j in 1:J[i,first[i]]) {
      
      lp0[i,j,first[i]] <- alpha_p[entry_group[i]] +
        beta_season[j] + beta_period[period_vec[first[i]]]
      
      p0[i,j,first[i]] <- ilogit(lp0[i,j,first[i]])
      lambda0[i,j,first[i]] <- -log(1-p0[i,j,first[i]])
      P[i,j,first[i]] <- 1-exp(-lambda0[i,j,first[i]]*G[i,first[i]])
      
      captureProb[i,j,first[i]] <-
        step(H[i,j,first[i]]-2) *
        g[i,first[i],H[i,j,first[i]]] /
        (G[i,first[i]]+1e-10) *
        P[i,j,first[i]] +
        (1-step(H[i,j,first[i]]-2)) *
        (1-P[i,j,first[i]])
      
      Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])
    }
    
    # -------------------------------------------------------------------------
    # SUBSEQUENT YEARS
    # -------------------------------------------------------------------------
    
    for (k in (first[i]+1):K[i]) {
      
      Palive[i,k-1] <- z[i,k-1]*phi_annual[entry_group[i]]
      z[i,k] ~ dbern(Palive[i,k-1]*step(death_primary[i]-k))
      
      # Direct bivariate-normal AC transition.
      S[i,1,k] ~ dnorm(S[i,1,k-1],sd=sigma_move[entry_group[i]])
      S[i,2,k] ~ dnorm(S[i,2,k-1],sd=sigma_move[entry_group[i]])
      
      # Derived radial movement distance.
      moveDist[i,k-1] <- sqrt(
        pow(S[i,1,k]-S[i,1,k-1],2) +
          pow(S[i,2,k]-S[i,2,k-1],2)
      )
      
      g[i,k,1] <- 0
      
      for (r in 1:R) {
        D[i,r,k] <- sqrt(
          pow(S[i,1,k]-X[r,1],2) +
            pow(S[i,2,k]-X[r,2],2)
        )
        
        g[i,k,r+1] <- exp(
          -pow(D[i,r,k],2) /
            (2*pow(sigma[entry_group[i]],2))
        )
      }
      
      G[i,k] <- sum(g[i,k,1:(R+1)])
      
      for (j in 1:J[i,k]) {
        
        lp0[i,j,k] <- alpha_p[entry_group[i]] +
          beta_season[j] + beta_period[period_vec[k]]
        
        p0[i,j,k] <- ilogit(lp0[i,j,k])
        lambda0[i,j,k] <- -log(1-p0[i,j,k])
        
        P[i,j,k] <- (1-exp(-lambda0[i,j,k]*G[i,k]))*z[i,k]
        
        captureProb[i,j,k] <-
          step(H[i,j,k]-2) *
          g[i,k,H[i,j,k]] /
          (G[i,k]+1e-10) *
          P[i,j,k] +
          (1-step(H[i,j,k]-2)) *
          (1-P[i,j,k])
        
        Ones[i,j,k] ~ dbern(captureProb[i,j,k])
      }
    }
  }
})

# =============================================================================
# 17. CONSTANTS + DATA
# =============================================================================

consts <- list(
  R=R,N=N,K=as.integer(K),J=J,first=as.integer(first),
  X=X,H=H,n_periods=n_periods,period_vec=period_vec,
  entry_group=entry_group,death_primary=death_primary,
  xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax
)

data_list <- list(Ones=array(1L,dim(H)),z=z_data)

# =============================================================================
# 18. PRE-BUILD SUMMARY
# =============================================================================

cat("\n========================================\n")
cat("M2 DIRECT-AC MODEL SUMMARY\n")
cat("========================================\n")
cat("Individuals:",nind,
    "\nDetectors:",R,
    "\nYears:",n_prim,
    "\nSingle-primary:",N[1],
    "\nMulti-primary:",N[2]-N[1],
    "\nAC buffer:",AC_BUFFER,"m\n")

cat("\nEntry groups:\n")
print(table(entry_group))

cat("\nHistory lengths:\n")
print(
  tibble(entry_group,history=K-first) %>%
    group_by(entry_group) %>%
    summarise(
      n=n(),median=median(history),mean=mean(history),
      min=min(history),max=max(history),.groups="drop"
    )
)

# =============================================================================
# 19. BUILD MODEL
# =============================================================================

message("\nBuilding M2...")

model_M2 <- nimbleModel(
  code_M2,constants=consts,data=data_list,
  inits=inits[[1]],check=TRUE,calculate=FALSE
)

print(model_M2$initializeInfo())

lp <- model_M2$calculate()
cat("\nInitial log probability:",lp,"\n")

if (!is.finite(lp))
  stop("M2 initial model log probability is not finite.")

# =============================================================================
# 20. COMPILE + CONFIGURE
# =============================================================================

message("\nCompiling M2...")
cModel_M2 <- compileNimble(model_M2,resetFunctions=TRUE)

monitors <- c(
  "phi_annual","sigma_move","mean_move",
  "sigma","alpha_p","beta_season","beta_period"
)

config_M2 <- configureMCMC(model_M2,monitors=monitors,thin=1)

for (i in seq_len(nind)) {
  for (k in first[i]:K[i]) {
    nodes <- c(
      paste0("S[",i,", 1, ",k,"]"),
      paste0("S[",i,", 2, ",k,"]")
    )
    
    config_M2$removeSamplers(nodes,print=FALSE)
    config_M2$addSampler(target=nodes,type="RW_block")
  }
}

Rmcmc_M2 <- buildMCMC(config_M2)

message("\nCompiling M2 MCMC...")
cMCMC_M2 <- compileNimble(
  Rmcmc_M2,project=cModel_M2,resetFunctions=TRUE
)

# =============================================================================
# 21. RUN DEVELOPMENT MCMC
# =============================================================================

message("\nRunning M2 development MCMC...")

runtime_M2 <- system.time({
  samples_M2 <- runMCMC(
    cMCMC_M2,niter=NITER,nburnin=NBURN,
    nchains=NCHAINS,inits=inits,
    samplesAsCodaMCMC=TRUE,progressBar=TRUE,
    setSeed=2451:(2451+NCHAINS-1L)
  )
})

print(runtime_M2)

saveRDS(
  list(
    samples=samples_M2,runtime=runtime_M2,
    years=years,detectors=detectors,
    ids=ids,entry_group=entry_group,
    first=first,K=K,
    state_space=c(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax),
    settings=list(
      niter=NITER,nburn=NBURN,nchains=NCHAINS,
      sample_n=SAMPLE_N,AC_BUFFER=AC_BUFFER
    )
  ),
  paste0("results/RD_SCR_M2_Centered_XYBlock_",nind,"_badgers.rds")
)

# =============================================================================
# 22. DIAGNOSTICS
# =============================================================================

MCMCsummary(samples_M2)
gelman.diag(samples_M2,multivariate=FALSE)
effectiveSize(samples_M2)
