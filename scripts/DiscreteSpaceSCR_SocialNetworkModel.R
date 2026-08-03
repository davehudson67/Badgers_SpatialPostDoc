library(tidyverse)
library(lubridate)
library(nimble)
library(coda)

# ==============================================================================
# ---- 1. SPATIAL SETUP: Map Setts to Social Groups ----
# ==============================================================================
# Define aliases to ensure 100% perfect matching between captures and setts
sett_aliases <- c(
  "\\bCHESTNUT\\b" = "CHESNUT", "\\bJACKS\\b" = "JACKSMIREY",
  "\\bGRAVEL\\b" = "GRAVELPIT", "\\bBUCKHOLE\\b" = "BUCKHOLT", 
  "\\bTOPSETT\\b" = "TOP", "\\bFOXCUB\\b" = "FOX",
  "\\bGULLEY\\b" = "GULLY", "\\bBLACKBERRY\\b" = "BRAMBLE",
  "\\bBOC\\b" = "BOG", "\\bCEDARBANK\\b" = "CEDAR",
  "\\bCLAYTRAP\\b" = "CLAY", "\\bCLIFF\\b" = "CLIFFFACE",
  "\\bDINGLEVALLEY\\b" = "DINGLE"
)

# Load the lookup table created in QGIS
sg_lookup <- read_csv("data/Sett_to_SG_Lookup.csv", show_col_types = FALSE) %>%
  mutate(
    Sett_Clean = toupper(Sett_Upper) %>%    
      str_replace_all("[[:punct:]]", " ") %>% str_squish() %>%
      str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
      str_replace_all(sett_aliases) %>% str_replace_all("\\s+", ""),
    
    # If a sett sits outside the core polygons (NULL in QGIS), assign it to 999 (The Buffer)
    SG_id = replace_na(as.integer(SG_id), 999L)
  ) %>%
  distinct(Sett_Clean, .keep_all = TRUE) %>%
  select(Sett_Clean, SG_id)

# ==============================================================================
# ---- 2. DATA PREP: Join Captures & Apply Vicente Rule 1 ----
# ==============================================================================
cmr_data <- readRDS("data/badger_final_CMRready_wDisease.rds")
net_data <- readRDS("data/Social_Group_Network.rds")

# Vicente et al. (2007) Rule 1: Allocate badger to the group where most frequently caught that year.
annual_sg <- cmr_data %>%
  left_join(sg_lookup, by = c("sett" = "Sett_Clean")) %>%
  filter(!is.na(SG_id)) %>%
  group_by(tattoo, primary_year) %>%
  count(SG_id, name = "capture_count") %>%
  arrange(tattoo, primary_year, desc(capture_count), SG_id) %>%
  slice(1) %>%
  ungroup()

# PRE-FILTER: Drop badgers caught ONLY in the final year (Fixes NIMBLE indexing bounds)
final_year <- max(cmr_data$primary_year)
valid_badgers <- annual_sg %>%
  group_by(tattoo) %>%
  summarise(first_year = min(primary_year), .groups = "drop") %>%
  filter(first_year < final_year) %>%
  pull(tattoo)

annual_sg <- annual_sg %>% filter(tattoo %in% valid_badgers)

cat("Total Badgers retained for Network Model:", n_distinct(annual_sg$tattoo), "\n")

# ==============================================================================
# ---- 3. BUILD THE HMM MATRICES ----
# ==============================================================================
unique_badgers <- unique(annual_sg$tattoo)
unique_years <- sort(unique(cmr_data$primary_year))

nind <- length(unique_badgers)
n_prim <- length(unique_years)
sg_ids <- net_data$sg_id_list
n_sg <- length(sg_ids)
n_states <- n_sg + 1 # State 1:n_sg = Alive. State n_sg+1 = Dead / Not Seen.

# Initialize Base Matrices
y_raw <- matrix(NA_integer_, nrow = nind, ncol = n_prim)
x_data <- matrix(NA_integer_, nrow = nind, ncol = n_prim)
first_caught <- rep(NA_integer_, nind)
death_occasion <- rep(n_prim + 1, nind)
first_sg <- rep(NA_integer_, nind)

# Find death years
death_data <- cmr_data %>% filter(has_pm_record) %>%
  group_by(tattoo) %>% summarise(death_year = min(primary_year), .groups = "drop")

for(i in 1:nind) {
  b_id <- unique_badgers[i]
  
  # Fill Raw Y Matrix
  b_annual <- annual_sg %>% filter(tattoo == b_id)
  year_idx <- match(b_annual$primary_year, unique_years)
  y_raw[i, year_idx] <- b_annual$SG_id
  
  # Define first capture
  first_caught[i] <- min(year_idx)
  
  # Map known deaths
  d_row <- death_data %>% filter(tattoo == b_id)
  if(nrow(d_row) > 0) death_occasion[i] <- which(unique_years == d_row$death_year)
  
  # HMM X-Data: If we know they died, fix state to "Dead" for all years AFTER death
  if (death_occasion[i] < n_prim) {
    x_data[i, (death_occasion[i] + 1):n_prim] <- n_states
  }
}

# Calculate Safe K
death_occasion <- pmax(death_occasion, first_caught)
K <- pmax(first_caught, pmin(n_prim, death_occasion + 1)) 

# Convert raw SG_ids to consecutive indices (1 to n_sg) for NIMBLE
y_idx <- matrix(match(y_raw, sg_ids), nrow = nind, ncol = n_prim)
y_idx[is.na(y_idx)] <- n_states # NAs become "Not Seen" (n_states)

# Safely extract first known location for every badger
for(i in 1:nind) {
  valid_obs <- y_idx[i, ][y_idx[i, ] <= n_sg]
  first_sg[i] <- valid_obs[1]
}

# Build Neighbor Probability Matrix (From the network object)
neighbor_mat <- net_data$A_matrix
diag(neighbor_mat) <- 0
neighbor_probs <- neighbor_mat / rowSums(neighbor_mat)
neighbor_probs[is.nan(neighbor_probs)] <- 0 

# ==============================================================================
# ---- 4. THE NIMBLE HMM CODE ----
# ==============================================================================
code_Network_HMM <- nimbleCode({
  
  # Priors
  phi ~ dunif(0.01, 0.99)    # Annual Survival
  p ~ dunif(0.01, 0.99)      # Detection probability
  tau ~ dunif(0.01, 0.99)    # Site Fidelity 
  gamma ~ dunif(0.00, 0.10)  # "Long Distance" dispersal (fixes the -Inf bug!)
  
  # 1. Build Transition Matrix (psi) [Row = t-1, Col = t]
  for (s in 1:n_sg) {
    for (m in 1:n_sg) {
      # Movement prob while alive
      move_prob[s, m] <- (equals(s, m) * tau) + 
        (neighbor_probs[s, m] * (1 - tau) * (1 - gamma)) + 
        (gamma / n_sg)
      
      psi[s, m] <- phi * move_prob[s, m]
    }
    psi[s, n_states] <- 1 - phi  # Dying
  }
  
  # Absorbing State: Dead stays Dead
  for(m in 1:n_sg) psi[n_states, m] <- 0
  psi[n_states, n_states] <- 1
  
  # 2. Build Observation Matrix (p_obs) [Row = True State, Col = Observed]
  for (s in 1:n_sg) {
    for (m in 1:n_sg) p_obs[s, m] <- equals(s, m) * p
    p_obs[s, n_states] <- 1 - p  # Alive but missed
  }
  for(m in 1:n_sg) p_obs[n_states, m] <- 0
  p_obs[n_states, n_states] <- 1 # Dead is always missed
  
  # 3. The Model Loop
  for (i in 1:nind) {
    x[i, first[i]] <- first_sg[i] 
    
    for (k in (first[i] + 1):K[i]) {
      # Transition to a new state (or die)
      x[i, k] ~ dcat(psi[x[i, k - 1], 1:n_states])
      
      # Observation
      y[i, k] ~ dcat(p_obs[x[i, k], 1:n_states])
    }
  }
})

# ==============================================================================
# ---- 5. COMPILE & RUN ----
# ==============================================================================
consts_net <- list(
  nind = nind, n_sg = n_sg, n_states = n_states,
  first = first_caught, K = K, first_sg = first_sg,
  neighbor_probs = neighbor_probs
)

data_net <- list(y = y_idx, x = x_data)

# Sensible starting path for the latent state 'x'
x_init <- matrix(NA_integer_, nrow = nind, ncol = n_prim)
for(i in 1:nind) {
  current_sg <- first_sg[i]
  if(K[i] > first_caught[i]) {
    for(k in (first_caught[i] + 1):K[i]) {
      if(y_idx[i, k] <= n_sg) current_sg <- y_idx[i, k]
      x_init[i, k] <- current_sg
    }
  }
}
x_init[!is.na(x_data)] <- NA 

inits_net <- list(phi = 0.85, p = 0.5, tau = 0.9, gamma = 0.01, x = x_init)

# ---- Run the Model ----
message("Building Network Model (calculate = FALSE prevents R from freezing!)...")
model_net <- nimbleModel(code_Network_HMM, constants = consts_net, data = data_net, inits = inits_net, check = TRUE, calculate = FALSE)

message("Compiling to C++...")
cModel_net <- compileNimble(model_net)

message("Configuring MCMC...")
config_net <- configureMCMC(model_net, monitors = c("phi", "p", "tau", "gamma"), thin = 1)
cMCMC_net <- compileNimble(buildMCMC(config_net))

message("Running Network MCMC...")
system.time({
  samples_net <- runMCMC(cMCMC_net, niter = 30000, nburnin = 9000, nchains = 2, samplesAsCodaMCMC = TRUE)
})

saveRDS(samples_net, "DiscreteSpaceSCR_SocialNetworkModel_samples.rds")

plot(samples_net)
summary(samples_net)