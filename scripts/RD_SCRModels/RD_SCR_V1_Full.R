# =============================================================================
# WOODCHESTER ROBUST-DESIGN SPATIAL CMR - V1 FULL DATASET
#
# Primary occasions: years
# Secondary occasions: 4 trapping seasons/year
# Spatial observation: actual sett coordinates
# Annual movement: continuous AC displacement
# Detection: entry group + season + 5-year period
# Survival: entry-group specific
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

SAMPLE_N <- NA_integer_      # full dataset
NITER <- 6000
NBURN <- 1500
NCHAINS <- 2

cmr_file <- "data/badger_final_CMRready_wDisease.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
dir.create("results", showWarnings = FALSE)

# =============================================================================
# 1. SETT NAME CLEANING
# =============================================================================

sett_aliases <- c(
  "\\bCHESTNUT\\b" = "CHESNUT", "\\bJACKS\\b" = "JACKSMIREY",
  "\\bGRAVEL\\b" = "GRAVELPIT", "\\bBUCKHOLE\\b" = "BUCKHOLT",
  "\\bTOPSETT\\b" = "TOP", "\\bFOXCUB\\b" = "FOX",
  "\\bGULLEY\\b" = "GULLY", "\\bBLACKBERRY\\b" = "BRAMBLE",
  "\\bBOC\\b" = "BOG", "\\bCEDARBANK\\b" = "CEDAR",
  "\\bCLAYTRAP\\b" = "CLAY", "\\bCLIFF\\b" = "CLIFFFACE",
  "\\bDINGLEVALLEY\\b" = "DINGLE"
)

clean_sett <- function(x) {
  x %>% as.character() %>% toupper() %>%
    str_replace_all("[[:punct:]]", " ") %>% str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all(sett_aliases) %>% str_replace_all("\\s+", "")
}

# =============================================================================
# 2. LOAD SETT COORDINATES
# =============================================================================

sett_raw <- read_csv(sett_file, show_col_types = FALSE)

name_candidates <- c("Sett_Clean", "Sett", "sett", "SettName", "Sett_Upper", "Name")
x_candidates <- c("SettX", "sett_x", "X", "x", "Easting", "easting")
y_candidates <- c("SettY", "sett_y", "Y", "y", "Northing", "northing")

name_col <- intersect(name_candidates, names(sett_raw))[1]
x_col <- intersect(x_candidates, names(sett_raw))[1]
y_col <- intersect(y_candidates, names(sett_raw))[1]

if (any(is.na(c(name_col, x_col, y_col)))) stop("Could not identify sett name/X/Y columns.")

sett_xy <- sett_raw %>%
  transmute(
    Sett_Clean = clean_sett(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(!is.na(Sett_Clean), Sett_Clean != "", !is.na(x), !is.na(y)) %>%
  distinct(Sett_Clean, .keep_all = TRUE)

# =============================================================================
# 3. LOAD CMR DATA
# =============================================================================

cmr_raw <- readRDS(cmr_file)

cmr <- cmr_raw %>%
  mutate(
    Sett_Clean = clean_sett(sett),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season)
  ) %>%
  left_join(sett_xy, by = "Sett_Clean")

# =============================================================================
# 4. REMOVE LIVE CAPTURES WITHOUT XY
# =============================================================================

excluded_xy <- cmr %>%
  filter(has_live_capture, is.na(x) | is.na(y)) %>%
  count(Sett_Clean, sort = TRUE)

cat("\n--- LIVE CAPTURES EXCLUDED: NO XY ---\n")
print(excluded_xy, n = Inf)

n_live_before <- sum(cmr$has_live_capture, na.rm = TRUE)
cmr <- cmr %>% filter(!has_live_capture | (!is.na(x) & !is.na(y)))
n_live_after <- sum(cmr$has_live_capture, na.rm = TRUE)

cat("\nLive captures before XY filtering:", n_live_before, "\n")
cat("Live captures after XY filtering:", n_live_after, "\n")
cat("Live captures removed:", n_live_before - n_live_after, "\n")

# =============================================================================
# 5. CHECK BADGERS LOST ENTIRELY
# =============================================================================

all_live_ids <- cmr_raw %>% filter(has_live_capture) %>% distinct(tattoo)
spatial_live_ids <- cmr %>% filter(has_live_capture) %>% distinct(tattoo)
lost_badgers <- anti_join(all_live_ids, spatial_live_ids, by = "tattoo")

cat("Badgers with no spatially usable live capture:", nrow(lost_badgers), "\n")
if (nrow(lost_badgers) > 0L) print(lost_badgers, n = Inf)

# =============================================================================
# 6. YEAR INDEX
# =============================================================================

min_year <- min(cmr$primary_year, na.rm = TRUE)
max_year <- max(cmr$primary_year, na.rm = TRUE)
years <- min_year:max_year
n_prim <- length(years)
n_sec <- 4L

cmr <- cmr %>% mutate(primary = match(primary_year, years))

cat("\nStudy years:", min_year, "-", max_year, "\n")
cat("Primary occasions:", n_prim, "\n")

# =============================================================================
# 7. FIVE-YEAR TEMPORAL PERIODS
# =============================================================================

year_lookup <- tibble(primary_year = years) %>%
  mutate(
    period_start = floor(primary_year / 5) * 5,
    period_id = match(period_start, sort(unique(period_start)))
  )

period_vec <- as.integer(year_lookup$period_id)
n_periods <- max(period_vec)

print(year_lookup)

# =============================================================================
# 8. ENTRY GROUP
# =============================================================================

demog <- cmr_raw %>%
  arrange(tattoo, capture_date) %>%
  group_by(tattoo) %>%
  summarise(
    age_fc = {
      z <- na.omit(age_fc)
      if (length(z)) as.character(z[1]) else NA_character_
    },
    .groups = "drop"
  ) %>%
  mutate(entry_group = case_when(
    age_fc %in% c("Cub", "Yearling") ~ 1L,
    age_fc == "Adult" ~ 2L,
    TRUE ~ NA_integer_
  ))

cmr <- cmr %>% left_join(demog %>% select(tattoo, entry_group), by = "tattoo")

# =============================================================================
# 9. ONE LIVE LOCATION PER SEASON
# =============================================================================

live <- cmr %>%
  filter(has_live_capture, !is.na(primary), !is.na(trap_season), !is.na(x), !is.na(y)) %>%
  arrange(tattoo, primary, trap_season, capture_date) %>%
  group_by(tattoo, primary, trap_season) %>%
  slice_tail(n = 1) %>% ungroup()

cat("\nQuarterly spatial live records:", nrow(live), "\n")
cat("Badgers represented:", n_distinct(live$tattoo), "\n")
cat("Setts represented:", n_distinct(live$Sett_Clean), "\n")

# =============================================================================
# 10. ELIGIBLE INDIVIDUALS
# =============================================================================

eligible <- live %>%
  distinct(tattoo) %>%
  inner_join(demog, by = "tattoo") %>%
  filter(entry_group %in% 1:2)

exclude_ids <- "007V"
eligible <- eligible %>% filter(!tattoo %in% exclude_ids)

cat("\nEligible badgers:", nrow(eligible), "\n")
cat("Excluded impossible histories:", paste(exclude_ids, collapse = ", "), "\n")

if (!is.na(SAMPLE_N) && SAMPLE_N < nrow(eligible)) eligible <- eligible %>% slice_sample(n = SAMPLE_N)

ids <- eligible$tattoo
live <- live %>% filter(tattoo %in% ids)
cmr <- cmr %>% filter(tattoo %in% ids)
nind <- length(ids)

cat("Badgers used in model:", nind, "\n")
print(count(eligible, entry_group))

# =============================================================================
# 11. DETECTOR TABLE
# =============================================================================

detectors <- live %>%
  distinct(Sett_Clean, x, y) %>%
  arrange(Sett_Clean) %>%
  mutate(detector = row_number())

X <- as.matrix(detectors %>% select(x, y))
R <- nrow(X)

live <- live %>%
  left_join(detectors %>% select(Sett_Clean, detector), by = "Sett_Clean")

cat("Spatial detectors:", R, "\n")

# =============================================================================
# 12. INDIVIDUAL METADATA
# =============================================================================

ind_meta <- live %>%
  arrange(tattoo, primary, trap_season, capture_date) %>%
  group_by(tattoo) %>%
  summarise(
    first = first(primary),
    first_detector = first(detector),
    entry_group = first(entry_group),
    .groups = "drop"
  ) %>%
  right_join(tibble(tattoo = ids), by = "tattoo") %>%
  arrange(match(tattoo, ids))

first <- as.integer(ind_meta$first)
first_detector <- as.integer(ind_meta$first_detector)
entry_group <- as.integer(ind_meta$entry_group)

stopifnot(!anyNA(first), !anyNA(first_detector), !anyNA(entry_group))

cat("\nEntry groups:\n")
print(table(entry_group))

# =============================================================================
# 13. DEATH INFORMATION
# =============================================================================

death <- cmr %>%
  filter(has_pm_record, !is.na(primary)) %>%
  group_by(tattoo) %>%
  summarise(
    death_primary = min(primary),
    death_season = {
      x <- trap_season[primary == min(primary)]
      x <- x[!is.na(x)]
      if (length(x)) min(x) else NA_integer_
    },
    .groups = "drop"
  )

death_primary <- rep(n_prim + 1L, nind)
death_season <- rep(NA_integer_, nind)
m <- match(ids, death$tattoo)
has_death <- !is.na(m)

death_primary[has_death] <- death$death_primary[m[has_death]]
death_season[has_death] <- death$death_season[m[has_death]]

known_death <- death_primary <= n_prim
K <- rep(n_prim, nind)
K[known_death] <- pmin(n_prim, death_primary[known_death] + 1L)

# =============================================================================
# 14. ENCOUNTER ARRAY
# H = 1 = no capture; H = 2:R+1 = detector 1:R
# =============================================================================

H <- array(1L, dim = c(nind, n_sec, n_prim))

for (r in seq_len(nrow(live))) {
  i <- match(live$tattoo[r], ids)
  j <- live$trap_season[r]
  k <- live$primary[r]
  H[i, j, k] <- live$detector[r] + 1L
}

J <- matrix(n_sec, nrow = nind, ncol = n_prim)

for (i in seq_len(nind)) {
  if (known_death[i] && !is.na(death_season[i])) {
    k <- death_primary[i]
    if (k <= n_prim) J[i, k] <- max(1L, death_season[i])
  }
}

# =============================================================================
# 15. KNOWN ALIVE / DEAD STATES
# =============================================================================

z_data <- matrix(NA_integer_, nrow = nind, ncol = n_prim)

for (i in seq_len(nind)) {
  captured_years <- unique(live$primary[live$tattoo == ids[i]])
  z_data[i, captured_years] <- 1L
  
  if (known_death[i]) {
    z_data[i, death_primary[i]] <- 1L
    if (death_primary[i] < n_prim) z_data[i, (death_primary[i] + 1L):n_prim] <- 0L
  }
}

# =============================================================================
# 16. SORT HISTORIES
# =============================================================================

ord <- order(K - first)

ids <- ids[ord]
H <- H[ord, , , drop = FALSE]
J <- J[ord, , drop = FALSE]
z_data <- z_data[ord, , drop = FALSE]

first <- first[ord]
K <- K[ord]
first_detector <- first_detector[ord]
entry_group <- entry_group[ord]
death_primary <- death_primary[ord]

N <- c(sum(K == first), nind)

cat("\nSingle-primary histories:", N[1], "\n")
cat("Multi-primary histories:", N[2] - N[1], "\n")

if (N[1] == 0L || N[1] == N[2]) stop("Current NIMBLE loops require both history types.")

if (any(K < first)) stop("ERROR: At least one individual has K < first.")

if (any(death_primary < first & death_primary <= n_prim)) {
  stop("ERROR: Known death occurs before first spatial capture.")
}

# =============================================================================
# 17. INITIAL VALUES
# =============================================================================

make_inits <- function(chain = 1L) {
  
  d_init <- matrix(50, nind, max(1L, n_prim - 1L))
  th_init <- matrix(0, nind, max(1L, n_prim - 1L))
  z_init <- matrix(0L, nind, n_prim)
  
  for (i in seq_len(nind)) {
    
    dat <- live %>%
      filter(tattoo == ids[i]) %>%
      group_by(primary) %>%
      summarise(x = mean(x), y = mean(y), .groups = "drop")
    
    xy <- matrix(NA_real_, n_prim, 2)
    xy[first[i], ] <- X[first_detector[i], ]
    
    for (k in first[i]:K[i]) {
      dk <- dat %>% filter(primary == k)
      if (nrow(dk)) xy[k, ] <- c(dk$x, dk$y) else if (k > first[i]) xy[k, ] <- xy[k - 1, ]
    }
    
    if (K[i] > first[i]) {
      for (k in first[i]:(K[i] - 1L)) {
        dx <- xy[k + 1L, 1] - xy[k, 1]
        dy <- xy[k + 1L, 2] - xy[k, 2]
        d_init[i, k] <- max(sqrt(dx^2 + dy^2), 1)
        th_init[i, k] <- atan2(dy, dx)
      }
    }
    
    z_init[i, first[i]:K[i]] <- 1L
  }
  
  z_init[!is.na(z_data)] <- NA
  
  list(
    alpha_phi = c(qlogis(.70), qlogis(.68)) + rnorm(2, 0, .03),
    alpha_p = c(qlogis(.15), qlogis(.10)) + rnorm(2, 0, .03),
    alpha_logsigma = log(c(120, 100)) + rnorm(2, 0, .03),
    alpha_logd = log(c(120, 120)) + rnorm(2, 0, .03),
    beta_season_raw = rnorm(3, 0, .03),
    beta_period_raw = rnorm(n_periods - 1L, 0, .03),
    z = z_init, d = d_init, theta = th_init
  )
}

inits <- lapply(seq_len(NCHAINS), make_inits)

# =============================================================================
# 18. NIMBLE MODEL
# =============================================================================

code_RD_SCR <- nimbleCode({
  
  # ---- Priors ---------------------------------------------------------------
  
  for (grp in 1:2) {
    alpha_phi[grp] ~ dnorm(qlogis(0.70), sd = 1.5)
    phi_annual[grp] <- ilogit(alpha_phi[grp])
    
    alpha_p[grp] ~ dnorm(qlogis(0.15), sd = 1.5)
    
    alpha_logsigma[grp] ~ dnorm(log(250), sd = 1)
    sigma[grp] <- exp(alpha_logsigma[grp])
    
    alpha_logd[grp] ~ dnorm(log(300), sd = 1)
    dmean[grp] <- exp(alpha_logd[grp])
    dlambda[grp] <- 1 / dmean[grp]
  }
  
  # Sum-to-zero seasonal effects
  for (s in 1:3) {
    beta_season_raw[s] ~ dnorm(0, sd = 1)
    beta_season[s] <- beta_season_raw[s]
  }
  beta_season[4] <- -sum(beta_season_raw[1:3])
  
  # Sum-to-zero five-year period effects
  for (p in 1:(n_periods - 1)) {
    beta_period_raw[p] ~ dnorm(0, sd = 1)
    beta_period[p] <- beta_period_raw[p]
  }
  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods - 1)])
  
  # ---------------------------------------------------------------------------
  # SINGLE-PRIMARY HISTORIES
  # ---------------------------------------------------------------------------
  
  for (i in 1:N[1]) {
    
    z[i, first[i]] ~ dbern(1)
    S[i, 1, first[i]] <- X[first_detector[i], 1]
    S[i, 2, first[i]] <- X[first_detector[i], 2]
    g[i, first[i], 1] <- 0
    
    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(pow(S[i, 1, first[i]] - X[r, 1], 2) +
                                  pow(S[i, 2, first[i]] - X[r, 2], 2))
      g[i, first[i], r + 1] <- exp(-pow(D[i, r, first[i]], 2) /
                                     (2 * pow(sigma[entry_group[i]], 2)))
    }
    
    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])
    
    for (j in 1:J[i, first[i]]) {
      lp0[i, j, first[i]] <- alpha_p[entry_group[i]] +
        beta_season[j] + beta_period[period_vec[first[i]]]
      
      p0[i, j, first[i]] <- ilogit(lp0[i, j, first[i]])
      lambda0[i, j, first[i]] <- -log(1 - p0[i, j, first[i]])
      P[i, j, first[i]] <- 1 - exp(-lambda0[i, j, first[i]] * G[i, first[i]])
      
      captureProb[i, j, first[i]] <-
        step(H[i, j, first[i]] - 2) *
        g[i, first[i], H[i, j, first[i]]] / (G[i, first[i]] + 1e-10) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) * (1 - P[i, j, first[i]])
      
      Ones[i, j, first[i]] ~ dbern(captureProb[i, j, first[i]])
    }
  }
  
  # ---------------------------------------------------------------------------
  # MULTI-PRIMARY HISTORIES
  # ---------------------------------------------------------------------------
  
  for (i in (N[1] + 1):N[2]) {
    
    z[i, first[i]] ~ dbern(1)
    S[i, 1, first[i]] <- X[first_detector[i], 1]
    S[i, 2, first[i]] <- X[first_detector[i], 2]
    g[i, first[i], 1] <- 0
    
    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(pow(S[i, 1, first[i]] - X[r, 1], 2) +
                                  pow(S[i, 2, first[i]] - X[r, 2], 2))
      g[i, first[i], r + 1] <- exp(-pow(D[i, r, first[i]], 2) /
                                     (2 * pow(sigma[entry_group[i]], 2)))
    }
    
    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])
    
    for (j in 1:J[i, first[i]]) {
      lp0[i, j, first[i]] <- alpha_p[entry_group[i]] +
        beta_season[j] + beta_period[period_vec[first[i]]]
      
      p0[i, j, first[i]] <- ilogit(lp0[i, j, first[i]])
      lambda0[i, j, first[i]] <- -log(1 - p0[i, j, first[i]])
      P[i, j, first[i]] <- 1 - exp(-lambda0[i, j, first[i]] * G[i, first[i]])
      
      captureProb[i, j, first[i]] <-
        step(H[i, j, first[i]] - 2) *
        g[i, first[i], H[i, j, first[i]]] / (G[i, first[i]] + 1e-10) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) * (1 - P[i, j, first[i]])
      
      Ones[i, j, first[i]] ~ dbern(captureProb[i, j, first[i]])
    }
    
    # ---- Subsequent years ---------------------------------------------------
    
    for (k in (first[i] + 1):K[i]) {
      
      Palive[i, k - 1] <- z[i, k - 1] * phi_annual[entry_group[i]]
      z[i, k] ~ dbern(Palive[i, k - 1] * step(death_primary[i] - k))
      
      theta[i, k - 1] ~ dunif(-3.141593, 3.141593)
      d[i, k - 1] ~ dexp(dlambda[entry_group[i]])
      
      S[i, 1, k] <- S[i, 1, k - 1] + d[i, k - 1] * cos(theta[i, k - 1])
      S[i, 2, k] <- S[i, 2, k - 1] + d[i, k - 1] * sin(theta[i, k - 1])
      g[i, k, 1] <- 0
      
      for (r in 1:R) {
        D[i, r, k] <- sqrt(pow(S[i, 1, k] - X[r, 1], 2) +
                             pow(S[i, 2, k] - X[r, 2], 2))
        g[i, k, r + 1] <- exp(-pow(D[i, r, k], 2) /
                                (2 * pow(sigma[entry_group[i]], 2)))
      }
      
      G[i, k] <- sum(g[i, k, 1:(R + 1)])
      
      for (j in 1:J[i, k]) {
        lp0[i, j, k] <- alpha_p[entry_group[i]] +
          beta_season[j] + beta_period[period_vec[k]]
        
        p0[i, j, k] <- ilogit(lp0[i, j, k])
        lambda0[i, j, k] <- -log(1 - p0[i, j, k])
        P[i, j, k] <- (1 - exp(-lambda0[i, j, k] * G[i, k])) * z[i, k]
        
        captureProb[i, j, k] <-
          step(H[i, j, k] - 2) *
          g[i, k, H[i, j, k]] / (G[i, k] + 1e-10) * P[i, j, k] +
          (1 - step(H[i, j, k] - 2)) * (1 - P[i, j, k])
        
        Ones[i, j, k] ~ dbern(captureProb[i, j, k])
      }
    }
  }
})

# =============================================================================
# 19. CONSTANTS + DATA
# =============================================================================

consts <- list(
  R = R, N = N, K = as.integer(K), J = J, first = as.integer(first),
  X = X, H = H, n_periods = n_periods, period_vec = period_vec,
  first_detector = first_detector, entry_group = entry_group,
  death_primary = death_primary
)

data_list <- list(Ones = array(1L, dim(H)), z = z_data)

# =============================================================================
# 20. FULL DATA SUMMARY
# =============================================================================

cat("\n========================================\nFULL MODEL DATA SUMMARY\n========================================\n")
cat("Individuals:", nind, "\nDetectors:", R, "\nYears:", n_prim, "\n")
cat("Single-primary:", N[1], "\nMulti-primary:", N[2] - N[1], "\n")

cat("\nEntry groups:\n")
print(table(entry_group))

cat("\nHistory lengths by group:\n")
print(
  tibble(entry_group, history = K - first) %>%
    group_by(entry_group) %>%
    summarise(
      n = n(), median = median(history), mean = mean(history),
      min = min(history), max = max(history), .groups = "drop"
    )
)

cat("\nDetector X range:\n")
print(summary(X[, 1]))
cat("\nDetector Y range:\n")
print(summary(X[, 2]))

# =============================================================================
# 21. BUILD MODEL
# =============================================================================

message("\nBuilding model...")

model <- nimbleModel(
  code_RD_SCR, constants = consts, data = data_list,
  inits = inits[[1]], check = TRUE, calculate = FALSE
)

print(model$initializeInfo())

lp <- model$calculate()
cat("\nInitial log probability:", lp, "\n")
if (!is.finite(lp)) stop("Initial model log probability is not finite.")

# =============================================================================
# 22. COMPILE MODEL + MCMC
# =============================================================================

message("\nCompiling model...")
cModel <- compileNimble(model, resetFunctions = TRUE)

monitors <- c("phi_annual", "dmean", "sigma", "alpha_p", "beta_season", "beta_period")

config <- configureMCMC(model, monitors = monitors, thin = 1)
Rmcmc <- buildMCMC(config)

message("\nCompiling MCMC...")
cMCMC <- compileNimble(Rmcmc, project = cModel, resetFunctions = TRUE)

# =============================================================================
# 23. RUN FULL MCMC
# =============================================================================

message("\nRunning full-data MCMC...")

runtime <- system.time({
  samples_RD <- runMCMC(
    cMCMC, niter = NITER, nburnin = NBURN, nchains = NCHAINS, inits = inits,
    samplesAsCodaMCMC = TRUE, progressBar = TRUE,
    setSeed = 1451:(1451 + NCHAINS - 1L)
  )
})

print(runtime)

# =============================================================================
# 24. SAVE RESULTS
# =============================================================================

saveRDS(
  list(
    samples = samples_RD, runtime = runtime, years = years,
    detectors = detectors, ids = ids, entry_group = entry_group,
    first = first, K = K,
    settings = list(
      niter = NITER, nburn = NBURN, nchains = NCHAINS,
      sample_n = SAMPLE_N
    )
  ),
  "results/RD_SCR_V1_full.rds"
)

# =============================================================================
# 25. DIAGNOSTICS
# =============================================================================

MCMCsummary(samples_RD)
gelman.diag(samples_RD, multivariate = FALSE)
effectiveSize(samples_RD)

pdf("results/RD_SCR_V1_traceplots.pdf", width = 10, height = 7)
traceplot(samples_RD[, c(
  "phi_annual[1]", "phi_annual[2]",
  "dmean[1]", "dmean[2]",
  "sigma[1]", "sigma[2]",
  "alpha_p[1]", "alpha_p[2]"
)])
dev.off()