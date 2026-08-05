library(tidyverse)
library(lubridate)
library(nimble)
library(nimbleEcology)
library(coda)

# ==============================================================================
# ---- 1. SPATIAL & NETWORK SETUP ----
# ==============================================================================
sett_aliases <- c(
  "\\bCHESTNUT\\b"="CHESNUT", "\\bJACKS\\b"="JACKSMIREY", "\\bGRAVEL\\b"="GRAVELPIT", 
  "\\bBUCKHOLE\\b"="BUCKHOLT", "\\bTOPSETT\\b"="TOP", "\\bFOXCUB\\b"="FOX",
  "\\bGULLEY\\b"="GULLY", "\\bBLACKBERRY\\b"="BRAMBLE", "\\bBOC\\b"="BOG", 
  "\\bCEDARBANK\\b"="CEDAR", "\\bCLAYTRAP\\b"="CLAY", "\\bCLIFF\\b"="CLIFFFACE",
  "\\bDINGLEVALLEY\\b"="DINGLE"
)

# Load the verified lookup table and network
sg_lookup <- read_csv("data/Sett_to_SG_Lookup_Auto.csv", show_col_types = FALSE) %>%
  mutate(Sett_Clean = toupper(Sett_Clean) %>% str_replace_all("[[:punct:]]", " ") %>% 
           str_squish() %>% str_replace_all("\\s+", ""),
         SG_id = replace_na(as.integer(SG_id), 999L)) %>%
  distinct(Sett_Clean, .keep_all = TRUE) %>% select(Sett_Clean, SG_id)

net_data <- readRDS("data/Social_Group_Network.rds")
sg_ids <- net_data$sg_id_list
n_sg <- length(sg_ids)

# Neighbor Probabilities
neighbor_mat <- net_data$A_matrix
diag(neighbor_mat) <- 0
neighbor_probs <- neighbor_mat / rowSums(neighbor_mat)
neighbor_probs[is.nan(neighbor_probs)] <- 0 

non_neighbor_mat <- 1 - neighbor_mat - diag(n_sg)
non_neighbor_probs <- non_neighbor_mat / rowSums(non_neighbor_mat)
non_neighbor_probs[is.nan(non_neighbor_probs)] <- 0 

# ---- REVIEWER AUDIT: Network Validity ----
cat("\n--- NETWORK AUDIT ---\n")
stopifnot("Group 999 is missing from the network!" = 999L %in% sg_ids)
stopifnot("Some groups have no neighbors!" = all(rowSums(neighbor_mat) > 0))
stopifnot("Some groups have no non-neighbors!" = all(rowSums(non_neighbor_mat) > 0))
cat("Network validated: All groups have neighbors and non-neighbors.\n")

# ==============================================================================
# ---- 2. BUILD THE QUARTERLY TIMELINE & RESOLVE MULTIPLE CAPTURES ----
# ==============================================================================
cmr_data <- readRDS("data/badger_final_CMRready_wDisease.rds")
cmr_q <- cmr_data %>%
  mutate(Sett_Clean = toupper(sett) %>% str_replace_all("[[:punct:]]", " ") %>% 
           str_squish() %>% str_replace_all("\\s+", "")) %>%
  left_join(sg_lookup, by = "Sett_Clean")

# ---- REVIEWER AUDIT: Check all mapped IDs exist in Network ----
stopifnot("Unrecognized SG_id mapped!" = all(unique(na.omit(cmr_q$SG_id)) %in% sg_ids))

min_year <- min(cmr_q$primary_year)
max_year <- max(cmr_q$primary_year)

cmr_q <- cmr_q %>%
  mutate(quarter_idx = (primary_year - min_year) * 4 + trap_season)

n_quarters <- (max_year - min_year + 1) * 4

# ---- REVIEWER AUDIT: Continuous Index Check ----
stopifnot(
  "Invalid trap seasons found" = all(cmr_q$trap_season %in% 1:4),
  "NA quarter indices found" = !anyNA(cmr_q$quarter_idx),
  "Quarter indices out of bounds" = all(cmr_q$quarter_idx >= 1 & cmr_q$quarter_idx <= n_quarters)
)

# ---- REVIEWER OPTION A: Explicit Within-Quarter Movement Audit ----
quarterly_live <- cmr_q %>%
  filter(has_live_capture, !is.na(SG_id)) %>%
  arrange(tattoo, quarter_idx, capture_date) %>%
  group_by(tattoo, quarter_idx) %>%
  summarise(
    n_live_captures = n(),
    n_social_groups = n_distinct(SG_id),
    first_capture_date = first(capture_date),
    last_capture_date = last(capture_date),
    first_SG_id = first(SG_id),
    last_SG_id = last(SG_id),
    SG_sequence = paste(SG_id, collapse = " -> "),
    moved_within_quarter = n_distinct(SG_id) > 1,
    .groups = "drop"
  )

# ==============================================================================
# ---- 3. BUILD THE MATRICES (Conditioned on First Capture) ----
# ==============================================================================
unique_badgers <- unique(cmr_q$tattoo)
nind_raw <- length(unique_badgers)

n_true_states <- n_sg + 2  # Alive(1:n_sg), NewlyDead(n_sg+1), LongDead(n_sg+2)
n_obs_states  <- n_sg + 2  # Caught(1:n_sg), Missed(n_sg+1), FoundDead(n_sg+2)

y_q_raw <- matrix(n_sg + 1, nrow = nind_raw, ncol = n_quarters) # Default: Missed
first_q_raw <- rep(NA_integer_, nind_raw)
first_sg_raw <- rep(NA_integer_, nind_raw)
K_q_raw <- rep(n_quarters, nind_raw)

# Audit variables for death shifting
death_shifted_raw <- rep(FALSE, nind_raw)
actual_death_q_raw <- rep(NA_integer_, nind_raw)
model_death_q_raw <- rep(NA_integer_, nind_raw)

death_data <- cmr_q %>% filter(has_pm_record) %>%
  group_by(tattoo) %>% summarise(death_q = min(quarter_idx), .groups = "drop")

for(i in 1:nind_raw) {
  b_id <- unique_badgers[i]
  live_data <- quarterly_live %>% filter(tattoo == b_id)
  
  # A. Live Captures (Using last_SG_id from Option A!)
  if(nrow(live_data) > 0) {
    y_q_raw[i, live_data$quarter_idx] <- match(live_data$last_SG_id, sg_ids)
    first_q_raw[i] <- min(live_data$quarter_idx)
    first_sg_raw[i] <- y_q_raw[i, first_q_raw[i]]
  }
  
  # B. Deaths (Reviewer Fix: Shift safely across ALL quarters)
  d_row <- death_data %>% filter(tattoo == b_id)
  if(nrow(d_row) > 0) {
    d_q <- d_row$death_q
    live_quarters <- unique(live_data$quarter_idx)
    
    if(d_q %in% live_quarters) {
      if(d_q < n_quarters) {
        y_q_raw[i, d_q + 1] <- n_obs_states
        K_q_raw[i] <- d_q + 1
        
        death_shifted_raw[i] <- TRUE
        actual_death_q_raw[i] <- d_q
        model_death_q_raw[i] <- d_q + 1L
      } else {
        # Death is in the very last quarter. Censor the recovery, keep the live capture.
        K_q_raw[i] <- d_q
        death_shifted_raw[i] <- FALSE
        actual_death_q_raw[i] <- d_q
        model_death_q_raw[i] <- NA_integer_
      }
    } else {
      # Found dead in a quarter with no live captures
      y_q_raw[i, d_q] <- n_obs_states
      K_q_raw[i] <- d_q
      
      death_shifted_raw[i] <- FALSE
      actual_death_q_raw[i] <- d_q
      model_death_q_raw[i] <- d_q
    }
  }
}

# FILTERING: Must have a first live capture AND at least 1 quarter of follow-up
valid_idx <- which(!is.na(first_q_raw) & K_q_raw > first_q_raw)

y_q      <- y_q_raw[valid_idx, ]
first_q  <- first_q_raw[valid_idx]
first_sg <- first_sg_raw[valid_idx]
K_q      <- K_q_raw[valid_idx]
nind     <- length(valid_idx)
run_length <- K_q - first_q 

cat("\n--- DATA PREP AUDIT ---\n")
cat("Original Badgers:", nind_raw, "\n")
cat("Retained Badgers (With follow-up):", nind, "\n")
cat("Same-Quarter Live/Dead events shifted (+1 Q):", sum(death_shifted_raw[valid_idx]), "\n\n")

# ==============================================================================
# ---- 4. THE NIMBLE CODE (Quarterly, Conditioned, Airtight) ----
# ==============================================================================
code_Quarterly_HMM <- nimbleCode({
  
  # 1. Priors (Logit-scale per reviewer recommendation)
  alpha_phi_annual ~ dnorm(qlogis(0.85), sd = 1.5)
  phi_annual <- ilogit(alpha_phi_annual)
  phi_q <- pow(phi_annual, 0.25)
  
  # Reviewer Fix: tau_q estimated directly!
  alpha_tau_q ~ dnorm(qlogis(0.90), sd = 1.5)
  tau_q <- ilogit(alpha_tau_q)
  
  alpha_p_q ~ dnorm(qlogis(0.20), sd = 1.5)
  p_q <- ilogit(alpha_p_q)
  
  alpha_gamma_q ~ dnorm(qlogis(0.05), sd = 1.5)
  gamma_q <- ilogit(alpha_gamma_q)
  
  alpha_p_dead_q ~ dnorm(qlogis(0.10), sd = 1.5)
  p_dead_q <- ilogit(alpha_p_dead_q)
  
  # 2. Transition Matrix (psi)
  for (s in 1:n_sg) {
    for (m in 1:n_sg) {
      base_move[s, m] <- (equals(s, m) * tau_q) + 
        (neighbor_probs[s, m] * (1 - tau_q) * (1 - gamma_q)) + 
        (non_neighbor_probs[s, m] * (1 - tau_q) * gamma_q)
    }
    
    # NORMALIZATION: Guarantee rows sum to exactly 1.0 before survival
    sum_base[s] <- sum(base_move[s, 1:n_sg])
    
    for(m in 1:n_sg) {
      psi[s, m] <- phi_q * (base_move[s, m] / sum_base[s])
    }
    psi[s, n_sg + 1] <- 1 - phi_q  # Alive -> Newly Dead
    psi[s, n_sg + 2] <- 0          # Alive -> Long Dead (Impossible)
  }
  
  # Dead States
  for(m in 1:(n_sg + 1)) psi[n_sg + 1, m] <- 0
  psi[n_sg + 1, n_sg + 2] <- 1
  for(m in 1:(n_sg + 1)) psi[n_sg + 2, m] <- 0
  psi[n_sg + 2, n_sg + 2] <- 1
  
  # 3. Observation Matrix (p_obs)
  for (s in 1:n_sg) {
    for (m in 1:n_sg) p_obs[s, m] <- equals(s, m) * p_q
    p_obs[s, n_sg + 1] <- 1 - p_q  
    p_obs[s, n_obs_states] <- 0  
  }
  
  for(m in 1:n_sg) p_obs[n_sg + 1, m] <- 0
  p_obs[n_sg + 1, n_sg + 1] <- 1 - p_dead_q  
  p_obs[n_sg + 1, n_obs_states] <- p_dead_q  
  
  for(m in 1:n_sg) p_obs[n_sg + 2, m] <- 0
  p_obs[n_sg + 2, n_sg + 1] <- 1           
  p_obs[n_sg + 2, n_obs_states] <- 0       
  
  # 4. The Likelihood (Conditioned on First Capture)
  for (i in 1:nind) {
    
    # Initial state probability vector is the transition out of their first known group
    for(s in 1:n_true_states) {
      init_prob[i, s] <- psi[first_sg[i], s]
    }
    
    # Evaluate sequence starting the quarter AFTER first capture
    y[i, (first_q[i] + 1):K_q[i]] ~ dHMM(
      init = init_prob[i, 1:n_true_states], 
      probTrans = psi[1:n_true_states, 1:n_true_states], 
      probObs = p_obs[1:n_true_states, 1:n_obs_states], 
      len = run_length[i], 
      checkRowSums = 1 # Reviewer check: ON!
    )
  }
})

# ==============================================================================
# ---- 5. COMPILE & CHECK ----
# ==============================================================================
consts_q <- list(
  nind = nind, n_sg = n_sg, n_true_states = n_true_states, n_obs_states = n_obs_states,
  first_q = first_q, K_q = K_q, run_length = run_length, first_sg = first_sg,
  neighbor_probs = neighbor_probs, non_neighbor_probs = non_neighbor_probs
)
data_q <- list(y = y_q)

# Reviewer Fix: Use dispersed starting values for two chains
inits_q <- list(
  list(alpha_phi_annual = qlogis(0.80), alpha_tau_q = qlogis(0.85), alpha_p_q = qlogis(0.20), alpha_gamma_q = qlogis(0.01), alpha_p_dead_q = qlogis(0.05)),
  list(alpha_phi_annual = qlogis(0.95), alpha_tau_q = qlogis(0.95), alpha_p_q = qlogis(0.40), alpha_gamma_q = qlogis(0.05), alpha_p_dead_q = qlogis(0.20))
)

message("\nBuilding NIMBLE Model...")
model_q <- nimbleModel(code_Quarterly_HMM, constants = consts_q, data = data_q, inits = inits_q[[1]], check = TRUE, calculate = FALSE)

# Explicitly test initial calculations (Reviewer Request)
initial_log_prob <- model_q$calculate()
if (!is.finite(initial_log_prob)) {
  stop("CRITICAL ERROR: Initial model log-probability is not finite. Check row sums or bounds.")
} else {
  message("PASS: Model calculated successfully! Initial Log-Prob: ", round(initial_log_prob, 2))
}

# ==============================================================================
# ---- 6. RUN MCMC ----
# ==============================================================================
message("Compiling to C++...")
cModel_q <- compileNimble(model_q)

config_q <- configureMCMC(model_q, monitors = c("phi_annual", "phi_q", "tau_q", "p_q", "gamma_q", "p_dead_q"), thin = 1)
Rmcmc_q <- buildMCMC(config_q)
cMCMC_q <- compileNimble(Rmcmc_q, project = model_q)

message("Running MCMC...")
system.time({
  samples_q <- runMCMC(cMCMC_q, niter = 5000, nburnin = 1000, nchains = 2, inits = inits_q, samplesAsCodaMCMC = TRUE)
})

# Diagnostics
plot(samples_q)
summary(samples_q)
gelman.diag(samples_q, multivariate = FALSE)

# Save!
saveRDS(samples_q, "outputs/DiscreteSpaceSCR_SocialNetworkModel_samples.rds")
