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

sg_lookup <- read_csv("data/Sett_to_SG_Lookup.csv", show_col_types = FALSE) %>%
  mutate(Sett_Clean = toupper(Sett_Upper) %>% str_replace_all("[[:punct:]]", " ") %>% 
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

# ==============================================================================
# ---- 2. BUILD THE QUARTERLY TIMELINE & RESOLVE MULTIPLE CAPTURES ----
# ==============================================================================
cmr_data <- readRDS("data/badger_final_CMRready_wDisease.rds")
cmr_q <- cmr_data %>%
  mutate(Sett_Clean = toupper(sett) %>% str_replace_all("[[:punct:]]", " ") %>% 
           str_squish() %>% str_replace_all("\\s+", "")) %>%
  left_join(sg_lookup, by = "Sett_Clean") %>%
  # THE MAGIC SAFETY NET: If the SG_id isn't in the network, force it to 999 (Buffer)
  mutate(SG_id = if_else(is.na(SG_id) | !(SG_id %in% sg_ids), 999L, as.integer(SG_id)))

# ---- REVIEWER AUDIT: Check all mapped IDs exist in Network ----
stopifnot("Unrecognized SG_id mapped!" = all(unique(na.omit(cmr_q$SG_id)) %in% sg_ids))

min_year <- min(cmr_q$primary_year)
max_year <- max(cmr_q$primary_year)

cmr_q <- cmr_q %>%
  mutate(quarter_idx = (primary_year - min_year) * 4 + trap_season)

n_quarters <- (max_year - min_year + 1) * 4

# PRE-FILTER: Assign Locals vs Immigrants
badger_demographics <- cmr_q %>%
  group_by(tattoo) %>%
  summarise(
    first_year = min(primary_year),
    age_fc = first(na.omit(age_fc)), 
    .groups = "drop"
  ) %>%
  filter(first_year < max_year) %>%
  filter(age_fc %in% c("Cub", "Yearling", "Adult")) %>%
  mutate(imm_group = if_else(age_fc %in% c("Cub", "Yearling"), 1L, 2L))

cmr_q <- cmr_q %>% filter(tattoo %in% badger_demographics$tattoo)

# Use the LATEST valid capture location per quarter
quarterly_live <- cmr_q %>%
  filter(has_live_capture, !is.na(SG_id)) %>%
  arrange(tattoo, quarter_idx, capture_date) %>%
  group_by(tattoo, quarter_idx) %>%
  slice_tail(n = 1) %>%  
  ungroup()

# ==============================================================================
# ---- 3. BUILD THE MATRICES (Conditioned on First Capture) ----
# ==============================================================================
unique_badgers <- unique(cmr_q$tattoo)
nind_raw <- length(unique_badgers)

n_true_states <- n_sg + 2  
n_obs_states  <- n_sg + 2  

y_q_raw <- matrix(n_sg + 1, nrow = nind_raw, ncol = n_quarters) # Default: Missed (n_sg + 1)
first_q_raw <- rep(NA_integer_, nind_raw)
first_sg_raw <- rep(NA_integer_, nind_raw)
K_q_raw <- rep(n_quarters, nind_raw)
imm_group_raw <- rep(NA_integer_, nind_raw) 

death_data <- cmr_q %>% filter(has_pm_record) %>%
  group_by(tattoo) %>% summarise(death_q = min(quarter_idx), .groups = "drop")

shifted_deaths_audit <- 0

for(i in 1:nind_raw) {
  b_id <- unique_badgers[i]
  
  b_demo <- badger_demographics %>% filter(tattoo == b_id)
  if(nrow(b_demo) > 0) imm_group_raw[i] <- b_demo$imm_group[1]
  
  # A. Live Captures
  live_data <- quarterly_live %>% filter(tattoo == b_id)
  if(nrow(live_data) > 0) {
    y_q_raw[i, live_data$quarter_idx] <- match(live_data$SG_id, sg_ids)
    first_q_raw[i] <- min(live_data$quarter_idx)
    first_sg_raw[i] <- y_q_raw[i, first_q_raw[i]]
  }
  
  # B. Deaths (Shift same-quarter deaths to keep the observation!)
  d_row <- death_data %>% filter(tattoo == b_id)
  if(nrow(d_row) > 0) {
    d_q <- d_row$death_q
    
    if(!is.na(first_q_raw[i]) && d_q %in% live_data$quarter_idx) {
      if(d_q < n_quarters) {
        y_q_raw[i, d_q + 1] <- n_obs_states
        K_q_raw[i] <- d_q + 1
        shifted_deaths_audit <- shifted_deaths_audit + 1
      } else {
        K_q_raw[i] <- d_q
      }
    } else {
      y_q_raw[i, d_q] <- n_obs_states
      K_q_raw[i] <- d_q
    }
  }
}

# FILTERING: Must have a first live capture AND at least 1 quarter of follow-up
valid_idx <- which(!is.na(first_q_raw) & K_q_raw > first_q_raw & !is.na(first_sg_raw))

y_q      <- y_q_raw[valid_idx, ]
first_q  <- first_q_raw[valid_idx]
first_sg <- first_sg_raw[valid_idx]
K_q      <- K_q_raw[valid_idx]
imm_group <- imm_group_raw[valid_idx]
nind     <- length(valid_idx)
run_length <- K_q - first_q 

# Ultimate NA Scrubber
y_q[is.na(y_q)] <- n_sg + 1

cat("\n--- DATA PREP AUDIT ---\n")
cat("Original Badgers:", nind_raw, "\n")
cat("Retained Badgers (With follow-up):", nind, "\n")
cat("Same-Quarter Live/Dead events safely shifted:", shifted_deaths_audit, "\n")
cat("Are there ANY NAs in first_sg? :", anyNA(first_sg), "\n")
cat("Are there ANY NAs in y_q?      :", anyNA(y_q), "\n\n")

# ==============================================================================
# ---- 4. THE NIMBLE CODE (2-Group HMM) ----
# ==============================================================================
code_Quarterly_HMM <- nimbleCode({
  
  # 1. Priors (Now looping over g = 1:2 groups!)
  # NIMBLE uses logit() inside its own code, whereas R uses qlogis()!
  for(g in 1:2) {
    alpha_phi_annual[g] ~ dnorm(logit(0.85), sd = 1.5)
    phi_annual[g] <- ilogit(alpha_phi_annual[g])
    phi_q[g] <- pow(phi_annual[g], 0.25)
    
    alpha_tau_q[g] ~ dnorm(logit(0.90), sd = 1.5)
    tau_q[g] <- ilogit(alpha_tau_q[g])
    
    alpha_p_q[g] ~ dnorm(logit(0.20), sd = 1.5)
    p_q[g] <- ilogit(alpha_p_q[g])
    
    alpha_gamma_q[g] ~ dnorm(logit(0.05), sd = 1.5)
    gamma_q[g] <- ilogit(alpha_gamma_q[g])
  }
  
  # Keep dead recovery constant across groups (Shared parameter)
  alpha_p_dead_q ~ dnorm(logit(0.10), sd = 1.5)
  p_dead_q <- ilogit(alpha_p_dead_q)
  
  # 2. Transition Matrix (psi) - Built separately for each group!
  for(g in 1:2) {
    for (s in 1:n_sg) {
      for (m in 1:n_sg) {
        base_move[g, s, m] <- (equals(s, m) * tau_q[g]) + 
          (neighbor_probs[s, m] * (1 - tau_q[g]) * (1 - gamma_q[g])) + 
          (non_neighbor_probs[s, m] * (1 - tau_q[g]) * gamma_q[g])
      }
      
      # NORMALIZATION
      sum_base[g, s] <- sum(base_move[g, s, 1:n_sg])
      
      for(m in 1:n_sg) {
        psi[g, s, m] <- phi_q[g] * (base_move[g, s, m] / sum_base[g, s])
      }
      psi[g, s, n_sg + 1] <- 1 - phi_q[g]  
      psi[g, s, n_sg + 2] <- 0          
    }
    
    # Dead States
    for(m in 1:(n_sg + 1)) psi[g, n_sg + 1, m] <- 0
    psi[g, n_sg + 1, n_sg + 2] <- 1
    for(m in 1:(n_sg + 1)) psi[g, n_sg + 2, m] <- 0
    psi[g, n_sg + 2, n_sg + 2] <- 1
    
    # 3. Observation Matrix (p_obs) - Built separately for each group!
    for (s in 1:n_sg) {
      for (m in 1:n_sg) p_obs[g, s, m] <- equals(s, m) * p_q[g]
      p_obs[g, s, n_sg + 1] <- 1 - p_q[g]  
      p_obs[g, s, n_obs_states] <- 0  
    }
    for(m in 1:n_sg) p_obs[g, n_sg + 1, m] <- 0
    p_obs[g, n_sg + 1, n_sg + 1] <- 1 - p_dead_q  
    p_obs[g, n_sg + 1, n_obs_states] <- p_dead_q  
    for(m in 1:n_sg) p_obs[g, n_sg + 2, m] <- 0
    p_obs[g, n_sg + 2, n_sg + 1] <- 1           
    p_obs[g, n_sg + 2, n_obs_states] <- 0       
  }
  
  # 4. The Likelihood 
  for (i in 1:nind) {
    # Dynamically points to the Badger's assigned group!
    for(s in 1:n_true_states) {
      init_prob[i, s] <- psi[imm_group[i], first_sg[i], s]
    }
    
    y[i, (first_q[i] + 1):K_q[i]] ~ dHMM(
      init = init_prob[i, 1:n_true_states], 
      probTrans = psi[imm_group[i], 1:n_true_states, 1:n_true_states], 
      probObs = p_obs[imm_group[i], 1:n_true_states, 1:n_obs_states], 
      len = run_length[i], 
      checkRowSums = 1
    )
  }
})

# ==============================================================================
# ---- 5. COMPILE & CHECK ----
# ==============================================================================
# FIXED: imm_group is now safely included!
consts_q <- list(
  nind = nind, n_sg = n_sg, n_true_states = n_true_states, n_obs_states = n_obs_states,
  first_q = first_q, K_q = K_q, run_length = run_length, first_sg = first_sg,
  neighbor_probs = neighbor_probs, non_neighbor_probs = non_neighbor_probs,
  imm_group = imm_group 
)
data_q <- list(y = y_q)

# FIXED: Vectors of length 2 for our group parameters! (p_dead remains length 1)
inits_q <- list(
  list(alpha_phi_annual = c(qlogis(0.80), qlogis(0.80)), alpha_tau_q = c(qlogis(0.85), qlogis(0.85)), alpha_p_q = c(qlogis(0.20), qlogis(0.20)), alpha_gamma_q = c(qlogis(0.01), qlogis(0.01)), alpha_p_dead_q = qlogis(0.05)),
  list(alpha_phi_annual = c(qlogis(0.95), qlogis(0.95)), alpha_tau_q = c(qlogis(0.98), qlogis(0.98)), alpha_p_q = c(qlogis(0.40), qlogis(0.40)), alpha_gamma_q = c(qlogis(0.05), qlogis(0.05)), alpha_p_dead_q = qlogis(0.20))
)

message("\nBuilding NIMBLE Model...")
model_q <- nimbleModel(code_Quarterly_HMM, constants = consts_q, data = data_q, inits = inits_q[[1]], check = TRUE, calculate = FALSE)

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
cMCMC_q <- compileNimble(buildMCMC(config_q), project = model_q)

message("Running MCMC...")
system.time({
  samples_q <- runMCMC(cMCMC_q, niter = 10000, nburnin = 3000, nchains = 2, inits = inits_q, samplesAsCodaMCMC = TRUE)
})

plot(samples_q)
summary(samples_q)

#-------------------------------------------------------------------------------
# ==============================================================================
# ---- CALCULATE BAYESIAN CONTRASTS FOR SUMMARY DOCUMENT ----
# ==============================================================================
# 1. Combine MCMC chains into a single matrix
samples_mat <- as.matrix(samples_q)

# 2. Calculate the Deltas (Group 1 [Early-entry] minus Group 2 [Adult-entry])
# A positive number means Early-entry is higher. A negative means Adult-entry is higher.
delta_phi_annual <- samples_mat[, "phi_annual[1]"] - samples_mat[, "phi_annual[2]"]
delta_p_q        <- samples_mat[, "p_q[1]"] - samples_mat[, "p_q[2]"]
delta_tau_q      <- samples_mat[, "tau_q[1]"] - samples_mat[, "tau_q[2]"]
delta_gamma_q    <- samples_mat[, "gamma_q[1]"] - samples_mat[, "gamma_q[2]"]

# 3. Helper function to extract Mean, SD, and 95% CrI for the table
summarise_contrast <- function(delta_vector, param_name, interpretation) {
  mean_val <- mean(delta_vector)
  sd_val   <- sd(delta_vector)
  lower_95 <- quantile(delta_vector, 0.025)
  upper_95 <- quantile(delta_vector, 0.975)
  
  # Format the 95% CrI as a neat string: "[lower, upper]"
  cri_string <- paste0("[", sprintf("%.3f", lower_95), ", ", sprintf("%.3f", upper_95), "]")
  
  # Calculate the posterior probability that Group 1 is greater than Group 2
  prob_g1_greater <- mean(delta_vector > 0)
  
  tibble(
    `Parameter / contrast` = param_name,
    `Posterior mean` = sprintf("%.3f", mean_val),
    `SD` = sprintf("%.3f", sd_val),
    `95% CrI` = cri_string,
    `Pr(Early-entry > Adult)` = sprintf("%.2f", prob_g1_greater),
    `Interpretation` = interpretation
  )
}

# 4. Build the final table exactly as requested in the summary document
contrast_table <- bind_rows(
  summarise_contrast(delta_phi_annual, "Delta phi_annual", "Difference in annual apparent survival between early-entry and adult-entry badgers."),
  summarise_contrast(delta_p_q,        "Delta p_q",        "Difference in quarterly detection."),
  summarise_contrast(delta_tau_q,      "Delta tau_q",      "Difference in quarterly same-group retention."),
  summarise_contrast(delta_gamma_q,    "Delta gamma_q",    "Difference in conditional non-neighbour movement allocation.")
)