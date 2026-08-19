library(tidyverse)
library(lubridate)
library(nimble)
library(nimbleEcology)
library(coda)
library(MCMCvis)

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

# Load sett lookup & network
net_data <- readRDS("data/Social_Group_Network.rds")
sg_ids <- as.integer(net_data$sg_id_list)
n_sg <- length(sg_ids)

sg_lookup <- read_csv("data/Sett_to_SG_Lookup_Auto.csv", show_col_types = FALSE) %>%
  mutate(
    Sett_Clean = toupper(Sett_Clean) %>% str_replace_all("[[:punct:]]", " ") %>%
      str_squish() %>% str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
      str_replace_all(sett_aliases) %>% str_replace_all("\\s+", ""),
    SG_id = if_else(!is.na(SG_id) & !SG_id %in% sg_ids, 999L, as.integer(SG_id))
  ) %>%
  distinct(Sett_Clean, .keep_all = TRUE) %>% select(Sett_Clean, SG_id)

# Network movement weights
neighbor_mat <- net_data$A_matrix
diag(neighbor_mat) <- 0
neighbor_probs <- neighbor_mat / rowSums(neighbor_mat)
neighbor_probs[is.nan(neighbor_probs)] <- 0

non_neighbor_mat <- 1 - neighbor_mat - diag(n_sg)
non_neighbor_probs <- non_neighbor_mat / rowSums(non_neighbor_mat)
non_neighbor_probs[is.nan(non_neighbor_probs)] <- 0

# ==============================================================================
# ---- 2. CMR DATA & QUARTERLY TIMELINE ----
# ==============================================================================
cmr_q <- readRDS("data/badger_final_CMRready_wDisease.rds") %>%
  mutate(Sett_Clean = toupper(sett) %>% str_replace_all("[[:punct:]]", " ") %>%
           str_squish() %>% str_replace_all("\\s+", "")) %>%
  left_join(sg_lookup, by = "Sett_Clean")

if (nrow(cmr_q %>% filter(!is.na(SG_id), !SG_id %in% sg_ids)) > 0L) {
  stop("CRITICAL ERROR: Capture records contain SG IDs absent from network.")
}

min_year <- min(cmr_q$primary_year, na.rm = TRUE)
max_year <- max(cmr_q$primary_year, na.rm = TRUE)
n_years <- max_year - min_year + 1L

cmr_q <- cmr_q %>% mutate(quarter_idx = (primary_year - min_year) * 4L + trap_season)
n_quarters <- n_years * 4L
season_vec <- rep(1:4, times = n_years)

# ==============================================================================
# ---- 3. CREATE FIVE-YEAR CAPTURE-EFFORT PERIODS ----
# ==============================================================================
year_lookup <- tibble(primary_year = min_year:max_year) %>%
  mutate(period_start = floor(primary_year / 5) * 5, period_end = period_start + 4L)

period_levels <- sort(unique(year_lookup$period_start))
n_periods <- length(period_levels)

year_lookup <- year_lookup %>%
  mutate(period_id = match(period_start, period_levels), period_label = paste0(period_start, "-", period_end))

period_vec <- rep(year_lookup$period_id, each = 4L)

# ==============================================================================
# ---- 4. RESOLVE CAPTURES & ASSIGN ENTRY GROUP ----
# ==============================================================================
quarterly_live <- cmr_q %>%
  filter(has_live_capture, !is.na(SG_id)) %>%
  arrange(tattoo, quarter_idx, capture_date) %>%
  group_by(tattoo, quarter_idx) %>% slice_tail(n = 1) %>% ungroup()

badger_demographics <- cmr_q %>%
  arrange(tattoo, capture_date) %>%
  group_by(tattoo) %>%
  summarise(
    age_fc = if (length(na.omit(age_fc)) == 0L) NA_character_ else as.character(na.omit(age_fc)[1]),
    .groups = "drop"
  ) %>%
  mutate(entry_group = case_when(age_fc %in% c("Cub", "Yearling") ~ 1L, age_fc == "Adult" ~ 2L, TRUE ~ NA_integer_))

# ==============================================================================
# ---- 5. BUILD MATRICES & SPLIT LIKELIHOODS (WITH 200-BADGER SUBSET) ----
# ==============================================================================
#all_unique_badgers <- unique(cmr_q$tattoo)
unique_badgers <- unique(cmr_q$tattoo)

# ---- THE TEST SUBSET ----
#set.seed(123)
#test_n <- 200
#unique_badgers <- sample(all_unique_badgers, min(test_n, length(all_unique_badgers)))
# -------------------------

nind_raw <- length(unique_badgers)

n_true_states <- n_sg + 2L
n_obs_states <- n_sg + 2L

y_q_raw <- matrix(n_sg + 1L, nrow = nind_raw, ncol = n_quarters) 
first_q_raw <- rep(NA_integer_, nind_raw)
first_sg_raw <- rep(NA_integer_, nind_raw)
K_q_raw <- rep(n_quarters, nind_raw)
entry_group_raw <- rep(NA_integer_, nind_raw)

death_data <- cmr_q %>% filter(has_pm_record) %>%
  group_by(tattoo) %>% summarise(death_q = min(quarter_idx), .groups = "drop")

for(i in seq_len(nind_raw)) {
  b_id <- unique_badgers[i]
  
  b_demo <- badger_demographics %>% filter(tattoo == b_id)
  if(nrow(b_demo) > 0L) entry_group_raw[i] <- b_demo$entry_group[1]
  
  live_data <- quarterly_live %>% filter(tattoo == b_id)
  if(nrow(live_data) > 0L) {
    y_q_raw[i, live_data$quarter_idx] <- match(live_data$SG_id, sg_ids)
    first_q_raw[i] <- min(live_data$quarter_idx)
    first_sg_raw[i] <- y_q_raw[i, first_q_raw[i]]
  }
  
  d_row <- death_data %>% filter(tattoo == b_id)
  if(nrow(d_row) > 0L) {
    d_q <- d_row$death_q
    live_quarters <- unique(live_data$quarter_idx)
    
    if(!is.na(first_q_raw[i]) && d_q %in% live_quarters) {
      if(d_q < n_quarters) {
        y_q_raw[i, d_q + 1L] <- n_obs_states
        K_q_raw[i] <- d_q + 1L
      } else { K_q_raw[i] <- d_q }
    } else {
      y_q_raw[i, d_q] <- n_obs_states
      K_q_raw[i] <- d_q
    }
  }
}

valid_idx <- which(!is.na(first_q_raw) & !is.na(first_sg_raw) & first_sg_raw %in% seq_len(n_sg) & 
                     !is.na(entry_group_raw) & entry_group_raw %in% 1:2 & K_q_raw > first_q_raw)

y_q <- y_q_raw[valid_idx, , drop = FALSE]
first_q <- as.integer(first_q_raw[valid_idx])
first_sg <- as.integer(first_sg_raw[valid_idx])
K_q <- as.integer(K_q_raw[valid_idx])
entry_group <- as.integer(entry_group_raw[valid_idx])
run_length <- as.integer(K_q - first_q)

# Split Likelihoods
idx_hmm <- which(run_length >= 2L)
idx_one <- which(run_length == 1L)

# Safety check for test sample: Ensure we have at least 1 badger of each length
if(length(idx_hmm) == 0 || length(idx_one) == 0) {
  stop("Random sample didn't capture both history lengths. Change set.seed and run Section 5 again!")
}

nind_hmm <- length(idx_hmm)
y_hmm <- y_q[idx_hmm, , drop = FALSE]
first_q_hmm <- as.integer(first_q[idx_hmm])
first_sg_hmm <- as.integer(first_sg[idx_hmm])
K_q_hmm <- as.integer(K_q[idx_hmm])
run_length_hmm <- as.integer(run_length[idx_hmm])
entry_group_hmm <- as.integer(entry_group[idx_hmm])

nind_one <- length(idx_one)
y_one <- as.integer(y_q[cbind(idx_one, first_q[idx_one] + 1L)])
q_one <- as.integer(first_q[idx_one] + 1L)
first_sg_one <- as.integer(first_sg[idx_one])
entry_group_one <- as.integer(entry_group[idx_one])

# ==============================================================================
# ---- 6. THE NIMBLE MODEL (5-Year Periods) ----
# ==============================================================================
code_Quarterly_HMM_Period <- nimbleCode({
  
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
  for(sea in 2:4) beta_season[sea] ~ dnorm(0, sd = 1.5)
  
  beta_period[1] <- 0
  for(per in 2:n_periods) beta_period[per] ~ dnorm(0, sd = 1.5)
  
  for(g in 1:2) {
    for(per in 1:n_periods) {
      for(sea in 1:4) {
        p_capture[g, per, sea] <- ilogit(alpha_p[g] + beta_period[per] + beta_season[sea])
      }
    }
  }
  
  for(g in 1:2) {
    for(s in 1:n_sg) {
      for(m in 1:n_sg) {
        base_move[g, s, m] <- equals(s, m) * tau_q[g] + 
          neighbor_probs[s, m] * (1 - tau_q[g]) * (1 - gamma_q[g]) + 
          non_neighbor_probs[s, m] * (1 - tau_q[g]) * gamma_q[g]
      }
      sum_base[g, s] <- sum(base_move[g, s, 1:n_sg])
      for(m in 1:n_sg) psi[g, s, m] <- phi_q[g] * (base_move[g, s, m] / sum_base[g, s])
      
      psi[g, s, n_sg + 1] <- 1 - phi_q[g]
      psi[g, s, n_sg + 2] <- 0
    }
    for(m in 1:(n_sg + 1)) psi[g, n_sg + 1, m] <- 0
    psi[g, n_sg + 1, n_sg + 2] <- 1
    for(m in 1:(n_sg + 1)) psi[g, n_sg + 2, m] <- 0
    psi[g, n_sg + 2, n_sg + 2] <- 1
  }
  
  for(g in 1:2) {
    for(q in 1:n_quarters) {
      logit(p_q_t[g, q]) <- alpha_p[g] + beta_season[season_vec[q]] + beta_period[period_vec[q]]
      
      for(s in 1:n_sg) {
        for(m in 1:n_sg) p_obs_global[g, s, m, q] <- equals(s, m) * p_q_t[g, q]
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
  
  # LIKELIHOOD 1
  for(i in 1:nind_hmm) {
    for(s in 1:n_true_states) init_prob_hmm[i, s] <- psi[entry_group_hmm[i], first_sg_hmm[i], s]
    y_hmm[i, (first_q_hmm[i] + 1):K_q_hmm[i]] ~ dHMMo(
      init = init_prob_hmm[i, 1:n_true_states], 
      probTrans = psi[entry_group_hmm[i], 1:n_true_states, 1:n_true_states], 
      probObs = p_obs_global[entry_group_hmm[i], 1:n_true_states, 1:n_obs_states, (first_q_hmm[i] + 1):K_q_hmm[i]], 
      len = run_length_hmm[i], checkRowSums = 1
    )
  }
  
  # LIKELIHOOD 2
  for(i in 1:nind_one) {
    for(s in 1:n_true_states) init_prob_one[i, s] <- psi[entry_group_one[i], first_sg_one[i], s]
    for(o in 1:n_obs_states) {
      for(s in 1:n_true_states) {
        one_step_comp[i, o, s] <- init_prob_one[i, s] * p_obs_global[entry_group_one[i], s, o, q_one[i]]
      }
      one_step_prob[i, o] <- sum(one_step_comp[i, o, 1:n_true_states])
    }
    y_one[i] ~ dcat(one_step_prob[i, 1:n_obs_states])
  }
})

# ==============================================================================
# ---- 7. COMPILE AND RUN ----
# ==============================================================================
consts_q <- list(
  n_sg = n_sg, n_true_states = n_true_states, n_obs_states = n_obs_states,
  nind_hmm = nind_hmm, first_q_hmm = first_q_hmm, K_q_hmm = K_q_hmm, 
  run_length_hmm = run_length_hmm, first_sg_hmm = first_sg_hmm, entry_group_hmm = entry_group_hmm,
  nind_one = nind_one, first_sg_one = first_sg_one, entry_group_one = entry_group_one, q_one = q_one,
  neighbor_probs = neighbor_probs, non_neighbor_probs = non_neighbor_probs,
  n_quarters = n_quarters, n_periods = n_periods,
  season_vec = as.integer(season_vec), period_vec = as.integer(period_vec)
)

data_q <- list(y_hmm = y_hmm, y_one = y_one)

inits_q <- list(
  list(alpha_phi_annual = c(1.38, 1.38), alpha_tau_q = c(1.73, 1.73), alpha_p = c(-1.38, -1.38), alpha_gamma_q = c(-4.59, -4.59), alpha_p_dead_q = -2.94, beta_season = c(NA, 0, 0, 0), beta_period = c(NA, rep(0, n_periods - 1L))),
  list(alpha_phi_annual = c(2.94, 2.94), alpha_tau_q = c(3.89, 3.89), alpha_p = c(-0.40, -0.40), alpha_gamma_q = c(-2.94, -2.94), alpha_p_dead_q = -1.38, beta_season = c(NA, 0.5, -0.5, 0), beta_period = c(NA, rep(0.25, n_periods - 1L)))
)

message("1. Building NIMBLE model for 200 Badgers...")
model_q <- nimbleModel(code_Quarterly_HMM_Period, constants = consts_q, data = data_q, inits = inits_q, check = TRUE, calculate = FALSE)

initial_log_prob <- model_q$calculate()
if(!is.finite(initial_log_prob)) stop("CRITICAL ERROR: Initial log-probability is not finite.")
message("PASS: Model calculated successfully! Initial Log-Prob: ", round(initial_log_prob, 2))

message("2. Compiling model & MCMC...")
cModel_q <- compileNimble(model_q, resetFunctions = TRUE)
config_q <- configureMCMC(model_q, monitors = c("phi_annual", "phi_q", "tau_q", "gamma_q", "p_dead_q", "alpha_p", "beta_season", "beta_period"), thin = 1)
cMCMC_q <- compileNimble(buildMCMC(config_q), project = model_q, resetFunctions = TRUE)

#message("3. Launching 1,000 Iteration TEST Run...")
#system.time({
#  samples_q <- runMCMC(cMCMC_q, niter = 1000, nburnin = 200, nchains = 2, inits = inits_q, samplesAsCodaMCMC = TRUE, setSeed = c(1451, 1452))
#})

#saveRDS(samples_q, "samples_q.rds")

message("3. Launching 12,000 Iteration TEST Run...")
system.time({
  samples_q_longer <- runMCMC(cMCMC_q, niter = 12000, nburnin = 2000, nchains = 2, inits = inits_q, samplesAsCodaMCMC = TRUE, setSeed = c(1451, 1452))
})
saveRDS(samples_q_longer, "samples_q_12k.rds")

# Diagnostics
summary(samples_q_longer)
plot(samples_q_longer)
MCMCsummary(samples_q_longer)
