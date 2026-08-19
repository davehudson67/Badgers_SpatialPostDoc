library(tidyverse)
library(nimble)
library(coda)

# ==============================================================================
# ---- 1. LOAD DATA & ASSIGN INFECTION GROUPS ----
# ==============================================================================
# Load your cleaned CMR data and Spatial objects
cmr_data <- readRDS("data/badger_final_CMRready_wDisease.rds")
spatial  <- readRDS("data/processed/consistent_new_grid_spatial_inputs.rds")

habitat_mat <- spatial$habitat_mat
SG_mat      <- spatial$SG_mat
X_matrix    <- spatial$settGrid %>% select(col_index, row_index) %>% as.matrix()
final_year  <- max(cmr_data$primary_year)

# Classify Badgers & Filter
# Group 1 = Never Positive, Group 2 = Positive as Cub
badger_groups <- cmr_data %>%
  group_by(tattoo) %>%
  summarise(
    first_year = min(primary_year),
    never_pos  = all(!any_positive_test),
    pos_as_cub = any(any_positive_test & age_fc == "Cub"),
    .groups = "drop"
  ) %>%
  # DROP badgers caught ONLY in the final year (fixes the NIMBLE looping bug)
  filter(first_year < final_year) %>%
  # KEEP only those strictly fitting Group 1 or Group 2
  filter(never_pos | pos_as_cub) %>%
  mutate(group = if_else(never_pos, 1L, 2L))

# Filter CMR data to valid badgers
cmr_ready <- cmr_data %>% inner_join(badger_groups %>% select(tattoo, group), by = "tattoo")

cat("Total Badgers Retained:", nrow(badger_groups), 
    "(Group 1:", sum(badger_groups$group == 1), "| Group 2:", sum(badger_groups$group == 2), ")\n")

# ==============================================================================
# ---- 2. BUILD MATRICES ----
# ==============================================================================
unique_badgers <- unique(cmr_ready$tattoo)
unique_years   <- sort(unique(cmr_ready$primary_year))

nind   <- length(unique_badgers)       
n_prim <- length(unique_years)       
R      <- nrow(X_matrix)                  

# Initialize Arrays
H              <- array(1L, dim = c(nind, 4, n_prim)) 
z_data         <- matrix(NA, nrow = nind, ncol = n_prim)
first_caught   <- rep(NA, nind)
death_occasion <- rep(n_prim + 1, nind) 
first_location <- rep(NA, nind)
group_id       <- rep(NA, nind)

for (i in seq_len(nind)) {
  b_data <- cmr_ready %>% filter(tattoo == unique_badgers[i])
  
  group_id[i]     <- b_data$group[1]
  first_caught[i] <- which(unique_years == min(b_data$primary_year))
  
  for (r in 1:nrow(b_data)) {
    k <- which(unique_years == b_data$primary_year[r])
    j <- b_data$trap_season[r]
    
    if (b_data$has_live_capture[r] && !is.na(b_data$Sett_ID[r])) H[i, j, k] <- b_data$Sett_ID[r] + 1
    if (b_data$has_pm_record[r]) death_occasion[i] <- min(death_occasion[i], k)
    z_data[i, k] <- 1 
  }
  
  # Right-Censor Deaths
  if (death_occasion[i] < n_prim) z_data[i, (death_occasion[i] + 1):n_prim] <- 0
  
  # First official trap location
  first_location[i] <- b_data %>% filter(has_live_capture, !is.na(Sett_ID)) %>% 
    arrange(primary_year, trap_season) %>% slice(1) %>% pull(Sett_ID)
}

# Safe K bounds (ensure K is strictly > first_caught)
death_occasion <- pmax(death_occasion, first_caught)
K <- pmax(first_caught, pmin(n_prim, death_occasion + 1)) 

# ==============================================================================
# ---- 3. NIMBLE CODE (Vectorized & Masked) ----
# ==============================================================================
code_Masked <- nimbleCode({
  
  # Priors (2 Groups)
  for (grp in 1:2) {
    kappa[grp]   ~ dunif(0.25, 10)
    sigma[grp]   ~ dunif(0.25, 30)
    PL[grp]      ~ dunif(0.01, 0.99)
    lambda[grp]  <- exp(log(-log(1 - PL[grp])))
    phi[grp]     ~ dunif(0.001, 0.999) 
    dmean[grp]   ~ dunif(0.25, 100)
    dlambda[grp] <- 1 / dmean[grp]
  }
  
  lake_penalty     ~ dexp(1)
  boundary_penalty ~ dexp(1)
  
  for (i in 1:nind) {
    # 1. INITIAL STATE
    z[i, first[i]] ~ dbern(1)
    
    # Anchored Start
    S[i, 1, first[i]] <- X[first_location[i], 1]
    S[i, 2, first[i]] <- X[first_location[i], 2]
    
    # Check Habitat for First Location
    col_S[i, first[i]] <- max(1, min(n_cols, trunc(S[i, 1, first[i]])))
    row_S[i, first[i]] <- max(1, min(n_rows, trunc(S[i, 2, first[i]])))
    habitat_here[i, first[i]] <- habitat_mat[row_S[i, first[i]], col_S[i, first[i]]]
    SG_here[i, first[i]]      <- SG_mat[row_S[i, first[i]], col_S[i, first[i]]]
    
    p_land[i, first[i]] <- habitat_here[i, first[i]] + (1 - habitat_here[i, first[i]]) * exp(-lake_penalty)
    land_ok[i, first[i]] ~ dbern(p_land[i, first[i]])
    
    # Spatial Hazard
    g[i, first[i], 2:(R + 1)] <- exp(-pow(sqrt((S[i, 1, first[i]] - X[1:R, 1])^2 + (S[i, 2, first[i]] - X[1:R, 2])^2) / sigma[group[i]], kappa[group[i]]))
    g[i, first[i], 1] <- 0
    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])
    Pyear[i, first[i]] <- 1 - exp(-lambda[group[i]] * G[i, first[i]])
    
    for (j in 1:4) {
      captureProb[i, first[i], j] <- step(H[i, j, first[i]] - 2) * (g[i, first[i], H[i, j, first[i]]] / (G[i, first[i]] + 1e-10)) * Pyear[i, first[i]] + (1 - step(H[i, j, first[i]] - 2)) * (1 - Pyear[i, first[i]])
      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }
    
    # 2. LATER YEARS (Movement & Masking)
    for (k in (first[i] + 1):K[i]) {
      
      Palive[i, k - 1] <- z[i, k - 1] * phi[group[i]]
      z[i, k] ~ dbern(Palive[i, k - 1] * step(death_occasion[i] - k))
      
      theta[i, k - 1] ~ dunif(-3.141593, 3.141593)
      d[i, k - 1] ~ dexp(dlambda[group[i]])
      
      # Frozen Movement if Dead
      S[i, 1, k] <- S[i, 1, k - 1] + (z[i, k - 1] * d[i, k - 1] * cos(theta[i, k - 1]))
      S[i, 2, k] <- S[i, 2, k - 1] + (z[i, k - 1] * d[i, k - 1] * sin(theta[i, k - 1]))
      
      # Check Habitat & Boundary Crossing
      col_S[i, k] <- max(1, min(n_cols, trunc(S[i, 1, k])))
      row_S[i, k] <- max(1, min(n_rows, trunc(S[i, 2, k])))
      habitat_here[i, k] <- habitat_mat[row_S[i, k], col_S[i, k]]
      SG_here[i, k]      <- SG_mat[row_S[i, k], col_S[i, k]]
      
      p_land[i, k] <- habitat_here[i, k] + (1 - habitat_here[i, k]) * exp(-lake_penalty)
      land_ok[i, k] ~ dbern(p_land[i, k])
      
      same_SG[i, k] <- equals(SG_here[i, k], SG_here[i, k - 1])
      p_boundary[i, k] <- same_SG[i, k] + (1 - same_SG[i, k]) * exp(-boundary_penalty)
      boundary_ok[i, k] ~ dbern(p_boundary[i, k])
      
      # Spatial Hazard
      g[i, k, 2:(R + 1)] <- exp(-pow(sqrt((S[i, 1, k] - X[1:R, 1])^2 + (S[i, 2, k] - X[1:R, 2])^2) / sigma[group[i]], kappa[group[i]]))
      g[i, k, 1] <- 0
      G[i, k] <- sum(g[i, k, 1:(R + 1)])
      Pyear[i, k] <- (1 - exp(-lambda[group[i]] * G[i, k])) * z[i, k]
      
      for (j in 1:4) {
        captureProb[i, k, j] <- step(H[i, j, k] - 2) * (g[i, k, H[i, j, k]] / (G[i, k] + 1e-10)) * Pyear[i, k] + (1 - step(H[i, j, k] - 2)) * (1 - Pyear[i, k])
        Ones[i, j, k] ~ dbern(captureProb[i, k, j])
      }
    }
  }
})

# ==============================================================================
# ---- 4. COMPILE & RUN NIMBLE ----
# ==============================================================================
# Pseudo-observations (We observed that badgers were ALWAYS on land and ALWAYS respected boundaries)
land_ok     <- matrix(1L, nrow = nind, ncol = n_prim)
boundary_ok <- matrix(1L, nrow = nind, ncol = n_prim)

# Initialize z
z_init <- matrix(0L, nrow = nind, ncol = n_prim)
for (i in 1:nind) z_init[i, first_caught[i]:K[i]] <- 1L
z_init[!is.na(z_data)] <- NA 

consts <- list(
  nind = nind, R = R, first = first_caught, K = K,
  first_location = first_location, death_occasion = death_occasion, group = group_id,
  n_rows = nrow(habitat_mat), n_cols = ncol(habitat_mat),
  H = H, X = X_matrix
)

data <- list(
  z = z_data, Ones = array(1L, dim = c(nind, 4, n_prim)),
  land_ok = land_ok, boundary_ok = boundary_ok,
  habitat_mat = habitat_mat, SG_mat = SG_mat
)

inits <- list(
  lake_penalty = 10, boundary_penalty = 2,
  PL = c(0.5, 0.5), kappa = c(2, 2), sigma = c(8, 8), phi = c(0.85, 0.85), dmean = c(8, 8),     
  z = z_init, d = matrix(0.1, nind, n_prim), theta = matrix(0, nind, n_prim)
)

message("Building & Compiling Model...")
model  <- nimbleModel(code_Masked, constants = consts, data = data, inits = inits, check = TRUE)
cModel <- compileNimble(model)

config <- configureMCMC(model, monitors = c("PL", "sigma", "kappa", "phi", "dmean", "boundary_penalty", "lake_penalty"), thin = 1)
cMCMC  <- compileNimble(buildMCMC(config))

message("Running MCMC...")
system.time(samples <- runMCMC(cMCMC, niter = 1000, nburnin = 200, nchains = 2, samplesAsCodaMCMC = TRUE))

plot(samples)
summary(samples)