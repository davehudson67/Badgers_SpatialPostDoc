#
# BASELINE SCR MODEL
#==============================================================================
#
# What is this model inferring?
# This model estimates four master "baseline" parameters for the Woodchester badger population:
#  ϕ (phi): The baseline annual survival probability. (Because we feed it exact roadkill/death dates via death_occasion, this estimate will be highly accurate).
#  σ (sigma): The spatial scale of detection. Biologically, this represents the radius of a badger's home range within a single trapping season.
#  dmean (dmean): The average distance an activity center shifts between years. Biologically, this captures annual territorial drift and dispersal.
#  p0/λ0: The baseline capture probability if a trap is placed exactly at the exact center of a badger's home range.
#
# What are the assumptions?
# Because this is an M0 (null) model, it makes several strong, simplifying assumptions:
# Homogeneous Badgers: Survival, movement, and detection are assumed to be identical for all badgers (males = females, cubs = adults).
# Homogeneous Time: Survival and detection are constant across all 40 years (no "good" years or "bad/drought" years).
# Anchored Origins: We assume a badger's true "home" in its very first year was the exact XY coordinate of the trap it was caught in.
# Continuous Random Walk: Between years, badgers walk in a random direction (theta) for a random distance (d). Space is assumed to be an infinite, 
# featureless plain with no territorial boundaries, fences, or social group polygons.
# Constant Trapping Effort: It assumes that every trap in the X matrix was equally available and active across the 40 years.

#==============================================================================

library(readr)
library(tidyverse)
library(stringr)
library(lubridate)
library(nimble)
library(coda)

# ==============================================================================
# Build Spatial Trap Array (settGrid & X_matrix)
# ==============================================================================
# Define the alias dictionary
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

# Load the official sett coordinates
spatial_raw <- read_csv("data/WoodchesterSettLocations.csv", show_col_types = FALSE)

settGrid <- spatial_raw %>%
  mutate(Sett_Clean = toupper(SETT) %>%
           str_replace_all("[[:punct:]]", " ") %>%
           str_squish() %>%
           str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
           str_replace_all(sett_aliases) %>%
           str_replace_all("\\s+", "")) %>%
  distinct(Sett_Clean, .keep_all = TRUE) %>%
  select(Sett_Clean, X_raw = SettX, Y_raw = SettY) %>%
  # Mean-center and scale to kilometers
  mutate(X_coord = (X_raw - mean(X_raw, na.rm = TRUE)) / 1000,
         Y_coord = (Y_raw - mean(Y_raw, na.rm = TRUE)) / 1000,
         Sett_ID = row_number())

# Create the X Matrix (Coordinates)
X_matrix <- settGrid %>%
  select(X_coord, Y_coord) %>%
  as.matrix()

# ==============================================================================
# Load Data & Filter Badgers
# ==============================================================================
# Load cleaned CMR data
cmr_data <- readRDS("data/badger_final_CMRready_wDisease.rds")

# Join the numeric Sett_ID onto the CMR data
cmr_data <- cmr_data %>%
  left_join(settGrid %>% select(Sett_Clean, Sett_ID), by = c("sett" = "Sett_Clean"))

# Identify badgers that have at least one official spatial capture
valid_spatial_badgers <- cmr_data %>% 
  filter(has_live_capture == TRUE, !is.na(Sett_ID)) %>% 
  pull(tattoo) %>% 
  unique()

final_year <- max(cmr_data$primary_year)

# Filter the dataset BEFORE building matrices:
# 1. Must have visited a valid sett
# 2. Must NOT be caught for the very first time in the final year
cmr_data_filtered <- cmr_data %>%
  filter(tattoo %in% valid_spatial_badgers) %>%
  group_by(tattoo) %>%
  mutate(first_year = min(primary_year)) %>%
  filter(first_year < final_year) %>%
  ungroup()

cat("Total traps (R):", nrow(X_matrix), "\n")
cat("Total badgers retained for spatial CMR:", n_distinct(cmr_data_filtered$tattoo), "\n")

# ==============================================================================
# Build the Matrices
# ==============================================================================
unique_badgers <- unique(cmr_data_filtered$tattoo)
unique_years <- sort(unique(cmr_data_filtered$primary_year))

nind <- length(unique_badgers)       
n_prim <- length(unique_years)       
n_sec <- 4                           
R <- nrow(X_matrix)                  

H <- array(1L, dim = c(nind, n_sec, n_prim)) 
z_data <- matrix(NA, nrow = nind, ncol = n_prim)
first_caught <- rep(NA, nind)
death_occasion <- rep(n_prim + 1, nind) 
first_location <- rep(NA, nind)

for (i in seq_len(nind)) {
  b_data <- cmr_data_filtered %>% filter(tattoo == unique_badgers[i])
  
  first_caught[i] <- which(unique_years == min(b_data$primary_year))
  
  for (r in 1:nrow(b_data)) {
    k <- which(unique_years == b_data$primary_year[r])
    j <- b_data$trap_season[r]
    
    if (b_data$has_live_capture[r] && !is.na(b_data$Sett_ID[r])) {
      H[i, j, k] <- b_data$Sett_ID[r] + 1
    }
    if (b_data$has_pm_record[r]) {
      death_occasion[i] <- min(death_occasion[i], k)
    }
    z_data[i, k] <- 1 
  }
  
  # Right-censor dead badgers safely
  if (death_occasion[i] <= n_prim) {
    if (death_occasion[i] < n_prim) {
      z_data[i, (death_occasion[i] + 1):n_prim] <- 0
    }
  }
  
  # Extract First Location
  first_location[i] <- b_data %>% 
    filter(has_live_capture, !is.na(Sett_ID)) %>% 
    arrange(primary_year, trap_season) %>% 
    slice(1) %>% 
    pull(Sett_ID)
}

# Safe K bounds (Guarantee K is never lower than first_caught)
death_occasion <- pmax(death_occasion, first_caught)
K <- pmin(n_prim, death_occasion + 1)
K <- pmax(first_caught, K) 
J <- matrix(4, nrow = nind, ncol = n_prim)

# ==============================================================================
# Compile Constants and Data
# ==============================================================================
consts <- list(
  nind = nind,
  R = R,
  first = first_caught,
  K = K,
  first_location = first_location,
  death_occasion = death_occasion,
  H = H,           
  X = X_matrix
)

data <- list(
  z = z_data,
  Ones = array(1L, dim = c(nind, n_sec, n_prim))
)

# ==============================================================================
# The Vectorized NIMBLE Code
# ==============================================================================
code_M0a_vectorized <- nimbleCode({
  
  # ---- Priors ----
  alpha_p0 ~ dnorm(0, sd = 1.5)
  p0 <- ilogit(alpha_p0)
  lambda0 <- -log(1 - p0)
  
  alpha_logsigma ~ dnorm(log(0.5), sd = 1) 
  sigma <- exp(alpha_logsigma)
  
  alpha_phi ~ dnorm(1.5, sd = 1)
  phi <- ilogit(alpha_phi)
  
  alpha_logd ~ dnorm(log(0.5), sd = 1)
  dmean <- exp(alpha_logd)
  dlambda <- 1 / dmean
  
  # ---- Model Loop ----
  for (i in 1:nind) {
    
    # =========================================================
    # 1. INITIAL STATE (Anchored to first trap location)
    # =========================================================
    z[i, first[i]] ~ dbern(1)
    
    # Deterministically anchor the starting activity center
    S[i, 1, first[i]] <- X[first_location[i], 1] 
    S[i, 2, first[i]] <- X[first_location[i], 2]
    
    # Vectorized Spatial Hazard (calculates distance to all traps at once)
    g[i, first[i], 2:(R + 1)] <- exp(- ((S[i, 1, first[i]] - X[1:R, 1])^2 + (S[i, 2, first[i]] - X[1:R, 2])^2) / (2 * pow(sigma, 2)))
    g[i, first[i], 1] <- 0
    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])
    
    # Calculate Pyear ONCE outside the j-loop
    Pyear[i, first[i]] <- 1 - exp(-lambda0 * G[i, first[i]])
    
    # Loop over the 4 secondary occasions
    for (j in 1:4) {
      captureProb[i, first[i], j] <- 
        step(H[i, j, first[i]] - 2) * (g[i, first[i], H[i, j, first[i]]] / (G[i, first[i]] + 1e-10)) * Pyear[i, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) * (1 - Pyear[i, first[i]])
      
      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }
    
    # =========================================================
    # 2. SUBSEQUENT YEARS (Survival & Frozen Movement)
    # =========================================================
    for (k in (first[i] + 1):K[i]) {
      
      # Survival
      Palive[i, k - 1] <- z[i, k - 1] * phi
      z[i, k] ~ dbern(Palive[i, k - 1] * step(death_occasion[i] - k))
      
      # Random Walk
      theta[i, k - 1] ~ dunif(-3.141593, 3.141593)
      d[i, k - 1] ~ dexp(dlambda)
      
      # FROZEN MOVEMENT: Multiply by z[i, k-1]. If dead, movement = 0!
      S[i, 1, k] <- S[i, 1, k - 1] + (z[i, k - 1] * d[i, k - 1] * cos(theta[i, k - 1]))
      S[i, 2, k] <- S[i, 2, k - 1] + (z[i, k - 1] * d[i, k - 1] * sin(theta[i, k - 1]))
      
      # Vectorized Spatial Hazard
      g[i, k, 2:(R + 1)] <- exp(- ((S[i, 1, k] - X[1:R, 1])^2 + (S[i, 2, k] - X[1:R, 2])^2) / (2 * pow(sigma, 2)))
      g[i, k, 1] <- 0
      G[i, k] <- sum(g[i, k, 1:(R + 1)])
      
      # Calculate Pyear ONCE outside the j-loop. Multiply by current z state.
      Pyear[i, k] <- (1 - exp(-lambda0 * G[i, k])) * z[i, k]
      
      for (j in 1:4) {
        captureProb[i, k, j] <- 
          step(H[i, j, k] - 2) * (g[i, k, H[i, j, k]] / (G[i, k] + 1e-10)) * Pyear[i, k] +
          (1 - step(H[i, j, k] - 2)) * (1 - Pyear[i, k])
        
        Ones[i, j, k] ~ dbern(captureProb[i, k, j])
      }
    }
  }
})

# ==============================================================================
# Initialize, Build & Run Model
# ==============================================================================
# Initialize z safely
z_init <- matrix(0L, nrow = nind, ncol = n_prim)
for (i in 1:nind) {
  z_init[i, first_caught[i]:K[i]] <- 1L
}
z_init[!is.na(z_data)] <- NA 

inits <- list(
  alpha_p0 = qlogis(0.35),
  alpha_logsigma = log(0.5), 
  alpha_phi = qlogis(0.85),
  alpha_logd = log(0.5),     
  z = z_init,
  d = matrix(0.1, nrow = nind, ncol = n_prim),
  theta = matrix(0, nrow = nind, ncol = n_prim)
)

#==============================================================================#
#==============================================================================
# Create 300-Badger Test Dataset
# ==============================================================================
test_n <- 300

# Subset the Constants (And remove 'J' to silence the Note!)
consts_test <- list(
  nind = test_n,
  R = R,
  first = first_caught[1:test_n],
  K = K[1:test_n],
  first_location = first_location[1:test_n],
  death_occasion = death_occasion[1:test_n],
  H = H[1:test_n, , ],
  X = X_matrix
)

# Subset the Data
data_test <- list(
  z = z_data[1:test_n, ],
  Ones = array(1L, dim = c(test_n, n_sec, n_prim))
)

# Subset and Fix the Initial Values
z_init_test <- z_init[1:test_n, ]

inits_test <- list(
  alpha_p0 = qlogis(0.35),
  alpha_logsigma = log(0.5), 
  alpha_phi = qlogis(0.85),
  alpha_logd = log(0.5),     
  z = z_init_test,
  
  # FIXED: Padded to n_prim - 1 to silence the dimension warnings!
  d = matrix(0.1, nrow = test_n, ncol = n_prim - 1),
  theta = matrix(0, nrow = test_n, ncol = n_prim - 1)
)

# ==============================================================================
# Build, Compile, and Run
# ==============================================================================
message("Building NIMBLE Model for ", test_n, " Badgers...")
model_test <- nimbleModel(code_M0a_vectorized, constants = consts_test, data = data_test, inits = inits_test, check = TRUE)
cModel_test <- compileNimble(model_test)

config_test <- configureMCMC(model_test, monitors = c("p0", "sigma", "phi", "dmean"), thin = 1)
rMCMC_test <- buildMCMC(config_test)
cMCMC_test <- compileNimble(rMCMC_test)

system.time({
  samples <- runMCMC(cMCMC_test, niter = 5000, nburnin = 1000, nchains = 2, samplesAsCodaMCMC = TRUE)
})

plot(samples)

# ==============================================================================
# Build, Compile, and Run Full Model
# ==============================================================================
message("Building FULL Latent SCR Model...")
model <- nimbleModel(code_M0a_vectorized, constants = consts, data = data, inits = inits, check = TRUE)

message("Compiling to C++...")
cModel <- compileNimble(model)

message("Configuring MCMC...")
config <- configureMCMC(model, monitors = c("p0", "sigma", "phi", "dmean"), thin = 1)
rMCMC <- buildMCMC(config)
cMCMC <- compileNimble(rMCMC)

message("Running Test MCMC...")
system.time({
  samples <- runMCMC(cMCMC, niter = 500, nburnin = 100, nchains = 2, samplesAsCodaMCMC = TRUE)
})