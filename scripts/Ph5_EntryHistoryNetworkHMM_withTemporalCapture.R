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

# Load the verified lookup table
sg_lookup <- read_csv("data/Sett_to_SG_Lookup.csv", show_col_types = FALSE) %>%
  mutate(Sett_Clean = toupper(Sett_Upper) %>% str_replace_all("[[:punct:]]", " ") %>% 
           str_squish() %>% str_replace_all("\\s+", "")) %>%
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

# ==============================================================================
# ---- 2. BUILD THE QUARTERLY TIMELINE & RESOLVE MULTIPLE CAPTURES ----
# ==============================================================================
cmr_data <- readRDS("data/badger_final_CMRready_wDisease.rds")

# Force missing SG IDs into the Buffer (999) FIRST!
sg_lookup <- sg_lookup %>%
  mutate(SG_id = if_else(SG_id %in% sg_ids, as.integer(SG_id), 999L))

cmr_q <- cmr_data %>%
  mutate(Sett_Clean = toupper(sett) %>% str_replace_all("[[:punct:]]", " ") %>% 
           str_squish() %>% str_replace_all("\\s+", "")) %>%
  left_join(sg_lookup, by = "Sett_Clean")

# Strict Invalid SG Check
invalid_sg <- cmr_q %>% filter(!is.na(SG_id), !SG_id %in% sg_ids) %>% distinct(Sett_Clean, SG_id)
if (nrow(invalid_sg) > 0) stop("CRITICAL ERROR: Capture records contain SG IDs absent from the network.")

min_year <- min(cmr_q$primary_year)
max_year <- max(cmr_q$primary_year)

cmr_q <- cmr_q %>% mutate(quarter_idx = (primary_year - min_year) * 4 + trap_season)

n_quarters <- (max_year - min_year + 1) * 4
n_years <- max_year - min_year + 1

season_vec <- rep(1:4, times = n_years)        
year_vec   <- rep(1:n_years, each = 4)         

# Use the LATEST valid capture location per quarter
quarterly_live <- cmr_q %>%
  filter(has_live_capture, !is.na(SG_id)) %>%
  arrange(tattoo, quarter_idx, capture_date) %>%
  group_by(tattoo, quarter_idx) %>%
  slice_tail(n = 1) %>%
  ungroup()

badger_demographics <- cmr_q %>%
  arrange(tattoo, capture_date) %>%
  group_by(tattoo) %>%
  summarise(
    age_fc = {
      values <- na.omit(age_fc)
      if (length(values) == 0L) NA_character_ else as.character(values[1])
    },
    .groups = "drop"
  ) %>%
  mutate(
    entry_group = case_when(
      age_fc %in% c("Cub", "Yearling") ~ 1L,
      age_fc == "Adult" ~ 2L,
      TRUE ~ NA_integer_
    )
  )

# ==============================================================================
# ---- 3. BUILD THE MATRICES (Conditioned on First Capture) ----
# ==============================================================================
unique_badgers <- unique(cmr_q$tattoo)
nind_raw <- length(unique_badgers)

n_true_states <- n_sg + 2  
n_obs_states  <- n_sg + 2  

y_q_raw <- matrix(n_sg + 1, nrow = nind_raw, ncol = n_quarters) 
first_q_raw <- rep(NA_integer_, nind_raw)
first_sg_raw <- rep(NA_integer_, nind_raw)
K_q_raw <- rep(n_quarters, nind_raw)
entry_group_raw <- rep(NA_integer_, nind_raw) 

death_data <- cmr_q %>% filter(has_pm_record) %>%
  group_by(tattoo) %>% summarise(death_q = min(quarter_idx), .groups = "drop")

################################################################################
################################################################################
################################################################################
# ==============================================================================
# ---- 3. BUILD THE MATRICES (Conditioned on First Capture) ----
# ==============================================================================
all_unique_badgers <- unique(cmr_q$tattoo)

# ---- THE TEST SUBSET ----
#set.seed(1)   # Keeps the random sample reproducible!
#test_n <- 100  # Sample 150 badgers for the trial run
#unique_badgers <- sample(all_unique_badgers, min(test_n, length(all_unique_badgers)))
# -------------------------
nind_raw <- length(unique_badgers)

n_true_states <- n_sg + 2  
n_obs_states  <- n_sg + 2  

y_q_raw <- matrix(n_sg + 1, nrow = nind_raw, ncol = n_quarters) # Default: Missed
first_q_raw <- rep(NA_integer_, nind_raw)
first_sg_raw <- rep(NA_integer_, nind_raw)
K_q_raw <- rep(n_quarters, nind_raw)
entry_group_raw <- rep(NA_integer_, nind_raw) 

death_data <- cmr_q %>% filter(has_pm_record) %>%
  group_by(tattoo) %>% summarise(death_q = min(quarter_idx), .groups = "drop")

shifted_deaths_audit <- 0

################################################################################
################################################################################
################################################################################

for(i in 1:nind_raw) {
  b_id <- unique_badgers[i]
  
  b_demo <- badger_demographics %>% filter(tattoo == b_id)
  if(nrow(b_demo) > 0) entry_group_raw[i] <- b_demo$entry_group[1]
  
  live_data <- quarterly_live %>% filter(tattoo == b_id)
  if(nrow(live_data) > 0) {
    y_q_raw[i, live_data$quarter_idx] <- match(live_data$SG_id, sg_ids)
    first_q_raw[i] <- min(live_data$quarter_idx)
    first_sg_raw[i] <- y_q_raw[i, first_q_raw[i]]
  }
  
  d_row <- death_data %>% filter(tattoo == b_id)
  if(nrow(d_row) > 0) {
    d_q <- d_row$death_q
    live_quarters <- unique(live_data$quarter_idx)
    
    if(!is.na(first_q_raw[i]) && d_q %in% live_quarters) {
      if(d_q < n_quarters) {
        y_q_raw[i, d_q + 1] <- n_obs_states
        K_q_raw[i] <- d_q + 1
      } else {
        K_q_raw[i] <- d_q
      }
    } else {
      y_q_raw[i, d_q] <- n_obs_states
      K_q_raw[i] <- d_q
    }
  }
}

# STRICT FILTERING
valid_idx <- which(
  !is.na(first_q_raw) & !is.na(first_sg_raw) & first_sg_raw %in% seq_len(n_sg) &
    !is.na(entry_group_raw) & entry_group_raw %in% 1:2 & K_q_raw > first_q_raw
)

y_q         <- y_q_raw[valid_idx, , drop = FALSE]
first_q     <- as.integer(first_q_raw[valid_idx])
first_sg    <- as.integer(first_sg_raw[valid_idx])
K_q         <- as.integer(K_q_raw[valid_idx])
entry_group <- as.integer(entry_group_raw[valid_idx])
run_length  <- as.integer(K_q - first_q)

# ==============================================================================
# ---- THE REVIEWER'S FIX: Split the lengths to stop NIMBLE crashing ----
# ==============================================================================
idx_hmm <- which(run_length >= 2L)
idx_one <- which(run_length == 1L)

cat("\n--- SPLIT LIKELIHOOD AUDIT ---\n")
cat("Histories with >= 2 follow-up quarters (dHMMo):", length(idx_hmm), "\n")
cat("Histories with exactly 1 follow-up quarter (dcat):", length(idx_one), "\n")

# Make sure we actually have both types so NIMBLE doesn't loop 1:0 !
stopifnot(length(idx_hmm) > 0L, length(idx_one) > 0L)

# Data for standard >= 2 sequences
nind_hmm        <- length(idx_hmm)
y_hmm           <- y_q[idx_hmm, , drop = FALSE]
first_q_hmm     <- first_q[idx_hmm]
first_sg_hmm    <- first_sg[idx_hmm]
K_q_hmm         <- K_q[idx_hmm]
run_length_hmm  <- run_length[idx_hmm]
entry_group_hmm <- entry_group[idx_hmm]

# Data for EXACTLY 1 sequence
nind_one        <- length(idx_one)
y_one           <- as.integer(y_q[cbind(idx_one, first_q[idx_one] + 1L)])
q_one           <- as.integer(first_q[idx_one] + 1L)
first_sg_one    <- as.integer(first_sg[idx_one])
entry_group_one <- as.integer(entry_group[idx_one])

# ==============================================================================
# ---- 4. THE SPLIT-LIKELIHOOD NIMBLE CODE ----
# ==============================================================================
code_Quarterly_HMM_Time <- nimbleCode({
  
  for(g in 1:2) {
    alpha_phi_annual[g] ~ dnorm(1.7346, sd = 1.5)  
    phi_annual[g] <- ilogit(alpha_phi_annual[g])
    phi_q[g] <- pow(phi_annual[g], 0.25)
    
    alpha_tau_q[g] ~ dnorm(2.1972, sd = 1.5)       
    tau_q[g] <- ilogit(alpha_tau_q[g])
    
    alpha_gamma_q[g] ~ dnorm(-2.9444, sd = 1.5)    
    gamma_q[g] <- ilogit(alpha_gamma_q[g])
    
    alpha_p[g] ~ dnorm(-1.3863, sd = 1.5)        
  }
  
  alpha_p_dead_q ~ dnorm(-2.1972, sd = 1.5)        
  p_dead_q <- ilogit(alpha_p_dead_q)
  
  beta_season[1] <- 0
  for(sea in 2:4) {
    beta_season[sea] ~ dnorm(0, sd = 1.5)
  }
  
  sd_year ~ dunif(0, 2)
  for(yr in 1:n_years) {
    z_year[yr] ~ dnorm(0, sd = 1)
    eps_year[yr] <- sd_year * z_year[yr]
  }
  
  # Calculate user-friendly average detection params
  for (g in 1:2) {
    for (sea in 1:4) {
      p_reference_year[g, sea] <- ilogit(alpha_p[g] + beta_season[sea])
    }
  }
  
  # Transition Matrix (psi)
  for(g in 1:2) {
    for (s in 1:n_sg) {
      for (m in 1:n_sg) {
        base_move[g, s, m] <- (equals(s, m) * tau_q[g]) + 
          (neighbor_probs[s, m] * (1 - tau_q[g]) * (1 - gamma_q[g])) + 
          (non_neighbor_probs[s, m] * (1 - tau_q[g]) * gamma_q[g])
      }
      sum_base[g, s] <- sum(base_move[g, s, 1:n_sg])
      for(m in 1:n_sg) {
        psi[g, s, m] <- phi_q[g] * (base_move[g, s, m] / sum_base[g, s])
      }
      psi[g, s, n_sg + 1] <- 1 - phi_q[g]  
      psi[g, s, n_sg + 2] <- 0          
    }
    for(m in 1:(n_sg + 1)) psi[g, n_sg + 1, m] <- 0
    psi[g, n_sg + 1, n_sg + 2] <- 1
    for(m in 1:(n_sg + 1)) psi[g, n_sg + 2, m] <- 0
    psi[g, n_sg + 2, n_sg + 2] <- 1
  }
  
  # TIME-VARYING Observation Matrix (p_obs_global) [Group, State, Obs, Time]
  for(g in 1:2) {
    for(q in 1:n_quarters) {
      
      logit(p_q_t[g, q]) <- alpha_p[g] + beta_season[season_vec[q]] + eps_year[year_vec[q]]
      
      for (s in 1:n_sg) {
        for (m in 1:n_sg) p_obs_global[g, s, m, q] <- equals(s, m) * p_q_t[g, q]
        p_obs_global[g, s, n_sg + 1, q] <- 1 - p_q_t[g, q]  
        p_obs_global[g, s, n_obs_states, q] <- 0  
      }
      for(m in 1:n_sg) p_obs_global[g, n_sg + 1, m, q] <- 0
      p_obs_global[g, n_sg + 1, n_sg + 1, q] <- 1 - p_dead_q  
      p_obs_global[g, n_sg + 1, n_obs_states, q] <- p_dead_q  
      
      for(m in 1:n_sg) p_obs_global[g, n_sg + 2, m, q] <- 0
      p_obs_global[g, n_sg + 2, n_sg + 1, q] <- 1           
      p_obs_global[g, n_sg + 2, n_obs_states, q] <- 0       
    }
  }
  
  # ======================================================================
  # THE LIKELIHOOD 1: Standard histories (Length >= 2) via dHMMo
  # ======================================================================
  for (i in 1:nind_hmm) {
    for(s in 1:n_true_states) {
      init_prob_hmm[i, s] <- psi[entry_group_hmm[i], first_sg_hmm[i], s]
    }
    
    y_hmm[i, (first_q_hmm[i] + 1):K_q_hmm[i]] ~ dHMMo(
      init = init_prob_hmm[i, 1:n_true_states], 
      probTrans = psi[entry_group_hmm[i], 1:n_true_states, 1:n_true_states], 
      probObs = p_obs_global[entry_group_hmm[i], 1:n_true_states, 1:n_obs_states, (first_q_hmm[i] + 1):K_q_hmm[i]], 
      len = run_length_hmm[i], 
      checkRowSums = 1
    )
  }
  
  # ======================================================================
  # THE LIKELIHOOD 2: Short histories (Length == 1) via Manual Marginalization
  # ======================================================================
  for (i in 1:nind_one) {
    for (s in 1:n_true_states) {
      init_prob_one[i, s] <- psi[entry_group_one[i], first_sg_one[i], s]
    }
    
    for (o in 1:n_obs_states) {
      for (s in 1:n_true_states) {
        one_step_component[i, o, s] <- init_prob_one[i, s] * p_obs_global[entry_group_one[i], s, o, q_one[i]]
      }
      one_step_obs_prob[i, o] <- sum(one_step_component[i, o, 1:n_true_states])
    }
    
    y_one[i] ~ dcat(one_step_obs_prob[i, 1:n_obs_states])
  }
})

# ==============================================================================
# ---- 5. BUILD MODEL ----
# ==============================================================================

consts_q <- list(
  n_sg = n_sg,
  n_true_states = n_true_states,
  n_obs_states = n_obs_states,
  
  nind_hmm = nind_hmm,
  first_q_hmm = as.integer(first_q_hmm),
  K_q_hmm = as.integer(K_q_hmm),
  run_length_hmm = as.integer(run_length_hmm),
  first_sg_hmm = as.integer(first_sg_hmm),
  entry_group_hmm = as.integer(entry_group_hmm),
  
  nind_one = nind_one,
  first_sg_one = as.integer(first_sg_one),
  entry_group_one = as.integer(entry_group_one),
  q_one = as.integer(q_one),
  
  neighbor_probs = neighbor_probs,
  non_neighbor_probs = non_neighbor_probs,
  
  n_quarters = n_quarters,
  n_years = n_years,
  season_vec = as.integer(season_vec),
  year_vec = as.integer(year_vec)
)

data_q <- list(
  y_hmm = y_hmm,
  y_one = as.integer(y_one)
)

inits_q <- list(
  list(
    alpha_phi_annual = c(1.38, 1.38),
    alpha_tau_q = c(1.73, 1.73),
    alpha_p = c(-1.38, -1.38),
    alpha_gamma_q = c(-4.59, -4.59),
    alpha_p_dead_q = -2.94,
    sd_year = 0.3,
    beta_season = c(NA, 0, 0, 0),
    z_year = rep(0, n_years)
  ),
  list(
    alpha_phi_annual = c(2.94, 2.94),
    alpha_tau_q = c(3.89, 3.89),
    alpha_p = c(-0.40, -0.40),
    alpha_gamma_q = c(-2.94, -2.94),
    alpha_p_dead_q = -1.38,
    sd_year = 0.8,
    beta_season = c(NA, 0.5, -0.5, 0),
    z_year = rep(0.1, n_years)
  )
)

message("Building NIMBLE model...")
model_q <- nimbleModel(code_Quarterly_HMM_Time, constants = consts_q, data = data_q, inits = inits_q[[1]], check = TRUE, calculate = FALSE)

initial_log_prob <- model_q$calculate()
if (!is.finite(initial_log_prob)) {
  stop(
    "Initial model log-probability is not finite."
  )
}

message("PASS: R model log-probability = ", round(initial_log_prob, 2))

# ==============================================================================
# ---- 6. CONFIGURE AND COMPILE ----
# ==============================================================================

config_q <- configureMCMC(
  model_q,
  monitors = c(
    "phi_annual",
    "phi_q",
    "tau_q",
    "gamma_q",
    "p_dead_q",
    "alpha_p",
    "beta_season",
    "sd_year",
    "eps_year",
    "p_reference_year"
  ),
  thin = 1
)

config_q$printSamplers()

Rmcmc_q <- buildMCMC(config_q)

message("Compiling model to C++...")

cModel_q <- compileNimble(
  model_q,
  resetFunctions = TRUE
)

compiled_log_prob <- cModel_q$calculate()

if (!is.finite(compiled_log_prob)) {
  stop(
    "Compiled model log-probability is not finite."
  )
}

message(
  "PASS: Compiled model log-probability = ",
  round(compiled_log_prob, 2)
)

message("Compiling MCMC...")

cMCMC_q <- compileNimble(
  Rmcmc_q,
  project = cModel_q,
  resetFunctions = TRUE
)

# ==============================================================================
# ---- 7. SHORT TEST RUN ----
# ==============================================================================

message("Running short MCMC test...")

test_samples <- runMCMC(
  cMCMC_q,
  niter = 50,
  nburnin = 0,
  nchains = 1,
  inits = inits_q[[1]],
  samplesAsCodaMCMC = TRUE,
  progressBar = TRUE,
  setSeed = 1451
)
