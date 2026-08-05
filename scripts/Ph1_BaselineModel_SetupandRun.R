# ==============================================================================
# BASELINE SCR MODEL (Continuous Space, Vectorized, Anchored Start)
# ==============================================================================
library(readr)
library(tidyverse)
library(stringr)
library(lubridate)
library(nimble)
library(coda)

# ==============================================================================
# 1. Build Spatial Trap Array (settGrid & X_matrix in Kilometers)
# ==============================================================================
sett_aliases <- c(
  "\\bCHESTNUT\\b"     = "CHESNUT", "\\bJACKS\\b"        = "JACKSMIREY",
  "\\bGRAVEL\\b"       = "GRAVELPIT", "\\bBUCKHOLE\\b"   = "BUCKHOLT", 
  "\\bTOPSETT\\b"      = "TOP", "\\bFOXCUB\\b"           = "FOX",
  "\\bGULLEY\\b"       = "GULLY", "\\bBLACKBERRY\\b"     = "BRAMBLE",
  "\\bBOC\\b"          = "BOG", "\\bCEDARBANK\\b"        = "CEDAR",
  "\\bCLAYTRAP\\b"     = "CLAY", "\\bCLIFF\\b"           = "CLIFFFACE",
  "\\bDINGLEVALLEY\\b" = "DINGLE"
)

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

X_matrix <- settGrid %>% select(X_coord, Y_coord) %>% as.matrix()

# ==============================================================================
# 2. Load Data & Filter Badgers
# ==============================================================================
cmr_data <- readRDS("data/badger_final_CMRready_wDisease.rds") %>%
  left_join(settGrid %>% select(Sett_Clean, Sett_ID), by = c("sett" = "Sett_Clean"))

# 1. Must have visited a valid sett
valid_spatial_badgers <- cmr_data %>% 
  filter(has_live_capture == TRUE, !is.na(Sett_ID)) %>% 
  pull(tattoo) %>% unique()

# 2. Must NOT be caught for the very first time in the final year
final_year <- max(cmr_data$primary_year)

cmr_data_filtered <- cmr_data %>%
  filter(tattoo %in% valid_spatial_badgers) %>%
  group_by(tattoo) %>%
  mutate(first_year = min(primary_year)) %>%
  filter(first_year < final_year) %>%
  ungroup()

cat("Total traps (R):", nrow(X_matrix), "\n")
cat("Total badgers retained for spatial CMR:", n_distinct(cmr_data_filtered$tattoo), "\n")

# ==============================================================================
# 3. Build the Matrices
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
    
    if (b_data$has_live_capture[r] && !is.na(b_data$Sett_ID[r])) H[i, j, k] <- b_data$Sett_ID[r] + 1
    if (b_data$has_pm_record[r]) death_occasion[i] <- min(death_occasion[i], k)
    z_data[i, k] <- 1 
  }
  
  if (death_occasion[i] < n_prim) z_data[i, (death_occasion[i] + 1):n_prim] <- 0
  
  first_location[i] <- b_data %>% filter(has_live_capture, !is.na(Sett_ID)) %>% 
    arrange(primary_year, trap_season) %>% slice(1) %>% pull(Sett_ID)
}

death_occasion <- pmax(death_occasion, first_caught)
K <- pmax(first_caught, pmin(n_prim, death_occasion + 1))

# Custom function to calculate spatial hazard instantly
calc_g_vec <- nimbleFunction(
  run = function(Sx = double(0), Sy = double(0), X = double(2), sigma = double(0)) {
    returnType(double(1))            # Returns a 1D vector
    R <- dim(X)[1]                   # Number of traps
    g_vec <- numeric(R + 1, init = FALSE) 
    g_vec[1] <- 0                    # Index 1 is always 0 (for "not caught")
    
    for(r in 1:R) {
      d2 <- (Sx - X[r, 1])^2 + (Sy - X[r, 2])^2
      g_vec[r + 1] <- exp(-d2 / (2 * sigma^2))
    }
    return(g_vec)
  }
)

# ==============================================================================
# 4. The Vectorized NIMBLE Code
# ==============================================================================
code_M0a_vectorized <- nimbleCode({
  
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
  
  for (i in 1:nind) {
    # 1. INITIAL STATE
    z[i, first[i]] ~ dbern(1)
    
    S[i, 1, first[i]] <- X[first_location[i], 1] 
    S[i, 2, first[i]] <- X[first_location[i], 2]
    
    # MAGIC FIX: Use our custom fast-compiled function!
    g[i, first[i], 1:(R + 1)] <- calc_g_vec(S[i, 1, first[i]], S[i, 2, first[i]], X[1:R, 1:2], sigma)
    
    G[i, first[i]] <- sum(g[i, first[i], 2:(R + 1)])
    Pyear[i, first[i]] <- 1 - exp(-lambda0 * G[i, first[i]])
    
    for (j in 1:4) {
      captureProb[i, first[i], j] <- step(H[i, j, first[i]] - 2) * (g[i, first[i], H[i, j, first[i]]] / (G[i, first[i]] + 1e-10)) * Pyear[i, first[i]] + (1 - step(H[i, j, first[i]] - 2)) * (1 - Pyear[i, first[i]])
      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }
    
    # 2. SUBSEQUENT YEARS
    for (k in (first[i] + 1):K[i]) {
      
      Palive[i, k - 1] <- z[i, k - 1] * phi
      z[i, k] ~ dbern(Palive[i, k - 1] * step(death_occasion[i] - k))
      
      theta[i, k - 1] ~ dunif(-3.141593, 3.141593)
      d[i, k - 1] ~ dexp(dlambda)
      
      S[i, 1, k] <- S[i, 1, k - 1] + (z[i, k - 1] * d[i, k - 1] * cos(theta[i, k - 1]))
      S[i, 2, k] <- S[i, 2, k - 1] + (z[i, k - 1] * d[i, k - 1] * sin(theta[i, k - 1]))
      
      # MAGIC FIX: Use our custom fast-compiled function!
      g[i, k, 1:(R + 1)] <- calc_g_vec(S[i, 1, k], S[i, 2, k], X[1:R, 1:2], sigma)
      
      G[i, k] <- sum(g[i, k, 2:(R + 1)])
      Pyear[i, k] <- (1 - exp(-lambda0 * G[i, k])) * z[i, k]
      
      for (j in 1:4) {
        captureProb[i, k, j] <- step(H[i, j, k] - 2) * (g[i, k, H[i, j, k]] / (G[i, k] + 1e-10)) * Pyear[i, k] + (1 - step(H[i, j, k] - 2)) * (1 - Pyear[i, k])
        Ones[i, j, k] ~ dbern(captureProb[i, k, j])
      }
    }
  }
})

# ==============================================================================
# 5. Create 300-Badger Test Run
# ==============================================================================
set.seed(123)
test_n <- 200
test_idx <- sample(1:nind, test_n)

consts_test <- list(
  nind = test_n, R = R, first = first_caught[test_idx], 
  K = K[test_idx], first_location = first_location[test_idx], 
  death_occasion = death_occasion[test_idx], 
  H = H[test_idx, , ], X = X_matrix
)

data_test <- list(
  z = z_data[test_idx, ], Ones = array(1L, dim = c(test_n, 4, n_prim))
)

z_init_test <- matrix(0L, nrow = test_n, ncol = n_prim)
for (i in 1:test_n) z_init_test[i, consts_test$first[i]:consts_test$K[i]] <- 1L
z_init_test[!is.na(data_test$z)] <- NA 

inits_test <- list(
  alpha_p0 = qlogis(0.35), alpha_logsigma = log(0.5), 
  alpha_phi = qlogis(0.85), alpha_logd = log(0.5),     
  z = z_init_test, d = matrix(0.1, test_n, n_prim - 1), theta = matrix(0, test_n, n_prim - 1)
)

model_test <- nimbleModel(code_M0a_vectorized, constants = consts_test, data = data_test, inits = inits_test)
cModel_test <- compileNimble(model_test)
cMCMC_test <- compileNimble(buildMCMC(configureMCMC(model_test, monitors = c("p0", "sigma", "phi", "dmean"), thin = 1)))

system.time(samples_test <- runMCMC(cMCMC_test, niter = 50000, nburnin = 19000, nchains = 2, samplesAsCodaMCMC = TRUE))
plot(samples_test)
summary(samples_test)
saveRDS(samples_test, "outputs/BaselineModel_TestRun200Badgers_samples.rds")

# ==============================================================================
# 6. Full Model Run (Overnight)
# ==============================================================================
# NOTE: Only highlight and run this block after the test run looks good!

consts_full <- list(
  nind = nind, R = R, first = first_caught, K = K, 
  first_location = first_location, death_occasion = death_occasion, 
  H = H, X = X_matrix
)

data_full <- list(
  z = z_data, Ones = array(1L, dim = c(nind, 4, n_prim))
)

z_init_full <- matrix(0L, nrow = nind, ncol = n_prim)
for (i in 1:nind) z_init_full[i, first_caught[i]:K[i]] <- 1L
z_init_full[!is.na(z_data)] <- NA 

inits_full <- list(
  alpha_p0 = qlogis(0.35), alpha_logsigma = log(0.5), 
  alpha_phi = qlogis(0.85), alpha_logd = log(0.5),     
  z = z_init_full, d = matrix(0.1, nind, n_prim - 1), theta = matrix(0, nind, n_prim - 1)
)

message("--- Running FULL Dataset ---")
model_full <- nimbleModel(code_M0a_vectorized, constants = consts_full, data = data_full, inits = inits_full)
cModel_full <- compileNimble(model_full)
cMCMC_full <- compileNimble(buildMCMC(configureMCMC(model_full, monitors = c("p0", "sigma", "phi", "dmean"), thin = 1)))

system.time(samples_full <- runMCMC(cMCMC_full, niter = 50000, nburnin = 14000, nchains = 2, samplesAsCodaMCMC = TRUE))


