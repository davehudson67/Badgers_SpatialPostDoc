# =============================================================================
# WOODCHESTER V10B - TRAJECTORY BLOCK + NON-CENTRED COMPUTATIONAL REPARAM
#
# PURPOSE
#   Sampler-only validation of the frozen V10B biological model.
#   The likelihood, priors and latent hierarchy are unchanged. The only
#   substantive difference from the production script is that all annual
#   activity-centre coordinates for one badger are sampled together in a
#   single AF_slice block, rather than one x/y block per badger-year.
#
#   This follows the trajectory-block validation and targets the two remaining
#   continuous ridges without changing the biological model or priors:
#
#   1. stationary quarterly AR(1) deviations are generated from iid standard
#      normal innovations (non-centred AR1 parameterisation), so rho no longer
#      changes the prior density of thousands of sampled qeps nodes;
#   2. the annual high-mobility log scale is sampled directly, with the local
#      log scale reconstructed by subtracting the positive high/local contrast.
#      This is an exact one-to-one transformation of the original
#      alpha_logmove ~ N(log(20),1), beta_move_high ~ Exp(1) prior.
#
# BIOLOGICAL MODEL (UNCHANGED)
#
#   * primary periods remain YEARS;
#   * secondary occasions remain Q1-Q4 trapping campaigns;
#   * annual activity centre A[i,y] retains the established between-year
#     local/high-mobility movement process;
#   * each secondary quarter has a latent centre S[i,y,q] around A[i,y];
#   * EVERY spatially usable live capture within the quarter is retained
#     (currently max 3), rather than selecting one representative sett;
#   * the observed number of within-quarter captures is conditioned upon:
#       - one quarterly capture/non-capture term;
#       - one conditional spatial-location term per observed capture.
#
# IMPORTANT
#   This is intentionally the core identifiability model. Static SG/peripheral
#   resistance is omitted until detection scale, within-year spatial scale and
#   annual movement scale are demonstrably separable.
#
#   Full detector-by-night effort is NOT reconstructed. The model treats each
#   quarter as one study-wide trapping campaign, consistent with the available
#   historical design information.
#
#   Annual movement retains the exact V10B two-state centred Gaussian HMM, but
#   the binary local/high state path is analytically integrated out with the
#   HMM forward recursion. Annual ACs remain centred spatial states. Posterior
#   movement-state probabilities / FFBS state draws are recovered afterwards
#   from the saved annual AC and global-parameter draws.
#
# ENVIRONMENT OPTIONS
#   CHAIN_ID      1, 2 or 3 (default 1)
#   MAX_BADGERS   number of audited movement badgers for smoke fit (default 300).
#                 Use 1932 for the full audited movement population.
#   NITER         default 2000
#   NBURN         default 1000
#   THIN          default 2
#   INIT_FROM_STEM optional prior result stem. When non-empty, initialise the
#                 chain from the final retained draw of that chain, including
#                 exact reconstruction of qinnov from saved A/Q/rho/omega.
#   OUTPUT_STEM    output stem (default V10B_RD_MULTILOC_AR1_COLLAPSED_REPARAM)
#
# OUTPUT
#   results/<OUTPUT_STEM>_<N>_CHAIN<chain>.rds
# =============================================================================

library(tidyverse)
library(lubridate)
library(nimble)
library(coda)
library(sf)

set.seed(123)

# ---- options ----------------------------------------------------------------
MAX_YEAR <- 2025L
EXPECTED_FULL_N <- 1932L

CHAIN_ID <- as.integer(Sys.getenv("CHAIN_ID", unset = "1"))
if (!CHAIN_ID %in% 1:3) stop("CHAIN_ID must be 1, 2 or 3.")

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "300"))
if (!is.finite(MAX_BADGERS) || MAX_BADGERS < 2L) {
  stop("MAX_BADGERS must be >=2.")
}

NITER <- as.integer(Sys.getenv("NITER", unset = "2000"))
NBURN <- as.integer(Sys.getenv("NBURN", unset = "1000"))
THIN <- as.integer(Sys.getenv("THIN", unset = "2"))

INIT_FROM_STEM <- Sys.getenv("INIT_FROM_STEM", unset = "")
OUTPUT_STEM <- Sys.getenv(
  "OUTPUT_STEM",
  unset = "V10B_RD_MULTILOC_AR1_COLLAPSED_REPARAM"
)

MOVE_MEAN_FACTOR <- sqrt(pi / 2)
QUARTER_DIFF_MEAN_FACTOR <- sqrt(pi)
LOG_TWO_PI <- log(2 * pi)

# Annual movement support is a numerical guard, not a biological prior.
# The old 5 m lower bound became visibly influential in the 300-badger fit
# (male local movement approached it), so production V10B relaxes the floor to
# 0.5 m. For a bivariate Gaussian this still guarantees the peak density is
# below 1, which keeps the Poisson zeros-trick rate non-negative.
LOG_MOVE_MIN <- log(0.5)
LOG_MOVE_MAX <- log(2500)

encounter_file <- "data/badger_encounters_useful.rds"
individual_file <- "data/badger_individuals.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
spatial_file <- "data/spatial/V3_spatial_inputs_50m_2km.rds"
population_file <- "results/V7_population_inclusion_audit.rds"

required_files <- c(
  encounter_file,
  individual_file,
  sett_file,
  spatial_file,
  population_file
)

missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files)) {
  stop("Missing required file(s):\n", paste(missing_files, collapse = "\n"))
}

dir.create("results", showWarnings = FALSE, recursive = TRUE)

cat("\n============================================================\n")
cat("WOODCHESTER V10B: AR(1) QUARTERLY CENTRES + COLLAPSED ANNUAL MOVEMENT HMM\n")
cat("============================================================\n")
cat(
  "Chain:", CHAIN_ID,
  "| MAX_BADGERS:", MAX_BADGERS,
  "| iterations:", NITER,
  "| burn:", NBURN,
  "| thin:", THIN, "\n"
)
cat("Output stem:", OUTPUT_STEM, "\n")
if (nzchar(INIT_FROM_STEM)) {
  cat("Continuation initialisation from:", INIT_FROM_STEM, "\n")
}

# ---- helpers ----------------------------------------------------------------
clean_sett <- function(x) {
  x %>%
    as.character() %>%
    toupper() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all("\\s+", "")
}

sett_aliases <- c(
  "CHESTNUT" = "CHESNUT",
  "JACKS" = "JACKSMIREY",
  "GRAVEL" = "GRAVELPIT",
  "BUCKHOLE" = "BUCKHOLT",
  "TOPSETT" = "TOP",
  "FOXCUB" = "FOX",
  "GULLEY" = "GULLY",
  "BLACKBERRY" = "BRAMBLE",
  "BOC" = "BOG",
  "CEDARBANK" = "CEDAR",
  "CLAYTRAP" = "CLAY",
  "CLIFF" = "CLIFFFACE",
  "DINGLEVALLEY" = "DINGLE"
)

clean_sett2 <- function(x) {
  z <- clean_sett(x)
  for (a in names(sett_aliases)) z[z == a] <- sett_aliases[[a]]
  z
}

# ---- snapshots ---------------------------------------------------------------
enc <- readRDS(encounter_file)
individuals <- readRDS(individual_file)
pop_obj <- readRDS(population_file)
sp <- readRDS(spatial_file)
sett_raw <- read_csv(sett_file, show_col_types = FALSE)

if (is.null(pop_obj$population)) {
  stop("Population audit RDS does not contain $population.")
}

full_pop <- pop_obj$population %>%
  filter(movement_eligible) %>%
  transmute(
    tattoo = toupper(trimws(as.character(tattoo))),
    individual_id = as.integer(individual_id),
    sex_class = as.character(sex_class),
    age_entry_class = as.character(age_entry_class)
  ) %>%
  mutate(
    sex_code = case_when(
      sex_class == "Female" ~ 0L,
      sex_class == "Male" ~ 1L,
      TRUE ~ NA_integer_
    ),
    adult_entry = as.integer(age_entry_class == "Adult_exact_age_unknown")
  ) %>%
  arrange(tattoo)

if (nrow(full_pop) != EXPECTED_FULL_N) {
  stop(
    "Expected ", EXPECTED_FULL_N,
    " movement badgers, found ", nrow(full_pop), "."
  )
}
if (anyNA(full_pop$sex_code)) {
  stop("Audited movement population contains unknown sex.")
}

# Reproducible smoke subset. Production is MAX_BADGERS=1932.
if (MAX_BADGERS < nrow(full_pop)) {
  set.seed(101)
  keep_idx <- sort(sample(seq_len(nrow(full_pop)), MAX_BADGERS, replace = FALSE))
  pop <- full_pop[keep_idx, , drop = FALSE]
  fit_type <- "smoke_random_subset"
} else {
  pop <- full_pop
  fit_type <- "full_population"
}

pop <- pop %>% arrange(tattoo)
ids <- pop$tattoo
individual_ids <- pop$individual_id
sex_data <- as.integer(pop$sex_code)
adult_entry <- as.integer(pop$adult_entry)
nind <- nrow(pop)

cat("Fitting", nind, "badgers (", fit_type, ")\n", sep = "")
cat(
  "Female:", sum(sex_data == 0L),
  "| male:", sum(sex_data == 1L),
  "| adult entry:", sum(adult_entry == 1L), "\n"
)

# ---- spatial state space -----------------------------------------------------
habitat_mat <- sp$habitat_mat
grid_xmin <- sp$xmin
grid_xmax <- sp$xmax
grid_ymin <- sp$ymin
grid_ymax <- sp$ymax
cell_size <- sp$cell_size
n_rows <- sp$n_rows
n_cols <- sp$n_cols

grid_df <- sf::st_drop_geometry(sp$grid)
grid_xy <- sf::st_coordinates(sp$grid)

if (!all(c("row_R", "col_R", "habitat") %in% names(grid_df))) {
  stop("sp$grid must contain row_R, col_R and habitat.")
}

land_idx <- which(grid_df$habitat == 1L)
if (!length(land_idx)) stop("No habitat cells in spatial state space.")

# ---- exact sett coordinates --------------------------------------------------
name_col <- intersect(
  c("Sett_Clean", "Sett", "sett", "SettName", "Sett_Upper", "Name"),
  names(sett_raw)
)[1]
x_col <- intersect(
  c("SettX", "sett_x", "X", "x", "Easting", "easting"),
  names(sett_raw)
)[1]
y_col <- intersect(
  c("SettY", "sett_y", "Y", "y", "Northing", "northing"),
  names(sett_raw)
)[1]

if (any(is.na(c(name_col, x_col, y_col)))) {
  stop("Could not identify sett name/X/Y columns.")
}

sett_xy_raw <- sett_raw %>%
  transmute(
    Sett_Clean = clean_sett2(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(
    !is.na(Sett_Clean),
    Sett_Clean != "",
    !is.na(x),
    !is.na(y)
  )

bad_sett_coords <- sett_xy_raw %>%
  distinct(Sett_Clean, x, y) %>%
  count(Sett_Clean, name = "n_xy") %>%
  filter(n_xy > 1L)

if (nrow(bad_sett_coords)) {
  print(bad_sett_coords, n = Inf)
  stop("A cleaned sett maps to >1 coordinate pair.")
}

sett_xy <- sett_xy_raw %>%
  distinct(Sett_Clean, .keep_all = TRUE)

# ---- all usable live captures ------------------------------------------------
live_all <- enc %>%
  mutate(
    tattoo = toupper(trimws(as.character(tattoo))),
    individual_id = as.integer(individual_id),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season),
    capture_date = as.Date(capture_date),
    Sett_Clean = clean_sett2(sett)
  ) %>%
  filter(
    has_live_capture,
    !is.na(primary_year),
    primary_year <= MAX_YEAR,
    trap_season %in% 1:4
  ) %>%
  left_join(sett_xy, by = "Sett_Clean") %>%
  filter(!is.na(x), !is.na(y))

# Detectors are defined from the full audited movement population, not the
# smoke subset, so the detector geometry does not change with MAX_BADGERS.
detectors <- live_all %>%
  filter(tattoo %in% full_pop$tattoo) %>%
  distinct(Sett_Clean, x, y) %>%
  arrange(Sett_Clean) %>%
  mutate(detector = row_number())

if (nrow(detectors %>% count(Sett_Clean) %>% filter(n > 1L))) {
  stop("A cleaned sett has >1 detector coordinate.")
}

X <- as.matrix(detectors %>% select(x, y))
R <- nrow(X)

live_all <- live_all %>%
  left_join(
    detectors %>% select(Sett_Clean, detector),
    by = "Sett_Clean"
  )

if (anyNA(live_all$detector[live_all$tattoo %in% full_pop$tattoo])) {
  stop("Usable live capture failed detector mapping.")
}

# Global year range used by the audited movement population.
full_live <- live_all %>%
  filter(tattoo %in% full_pop$tattoo)

years <- min(full_live$primary_year):MAX_YEAR
n_prim <- length(years)
J <- 4L
M <- max(
  full_live %>%
    count(tattoo, primary_year, trap_season) %>%
    pull(n)
)

if (M > 3L) {
  warning("Current max within-quarter capture count is ", M, ", not 3.")
}

period_vec <- as.integer(
  match(
    floor(years / 5) * 5,
    sort(unique(floor(years / 5) * 5))
  )
)
n_periods <- max(period_vec)

# Conservative indicator that a quarterly trapping campaign is represented in
# the historical live-capture data. A completely empty study-wide quarter is
# not treated as a known non-capture campaign.
campaign_active <- matrix(0L, nrow = J, ncol = n_prim)
campaign_tbl <- full_live %>%
  distinct(primary_year, trap_season) %>%
  mutate(primary = match(primary_year, years))

for (rr in seq_len(nrow(campaign_tbl))) {
  campaign_active[
    campaign_tbl$trap_season[rr],
    campaign_tbl$primary[rr]
  ] <- 1L
}

# Selected fitting population.
live <- full_live %>%
  filter(tattoo %in% ids) %>%
  mutate(primary = match(primary_year, years)) %>%
  arrange(tattoo, primary, trap_season, capture_date, detector)

# ---- capture arrays: retain ALL locations -----------------------------------
H <- array(1L, dim = c(nind, J, M, n_prim))
ncap <- array(0L, dim = c(nind, J, n_prim))

live_slots <- live %>%
  group_by(tattoo, primary, trap_season) %>%
  arrange(capture_date, detector, .by_group = TRUE) %>%
  mutate(capture_slot = row_number()) %>%
  ungroup()

for (rr in seq_len(nrow(live_slots))) {
  i <- match(live_slots$tattoo[rr], ids)
  k <- live_slots$primary[rr]
  j <- live_slots$trap_season[rr]
  m <- live_slots$capture_slot[rr]

  H[i, j, m, k] <- live_slots$detector[rr]
  ncap[i, j, k] <- max(ncap[i, j, k], m)
}

if (max(ncap) != M) {
  stop("Capture-slot array construction mismatch.")
}

# ---- individual first/last observed years -----------------------------------
obs_year <- live %>%
  distinct(tattoo, primary) %>%
  group_by(tattoo) %>%
  summarise(
    first = min(primary),
    K = max(primary),
    n_live_years = n(),
    .groups = "drop"
  ) %>%
  right_join(tibble(tattoo = ids), by = "tattoo") %>%
  arrange(match(tattoo, ids))

first <- as.integer(obs_year$first)
K <- as.integer(obs_year$K)

if (anyNA(first) || anyNA(K) || any(K <= first)) {
  stop("Invalid first/K annual histories.")
}

# Build the biological index of genuine annual movement intervals. The binary
# states themselves are not MCMC nodes in the collapsed implementation; this
# index is used later for forward-backward smoothing and FFBS recovery.
transition_map <- bind_rows(
  lapply(
    seq_len(nind),
    function(i) {
      ks <- (first[i] + 1L):K[i]

      tibble(
        active_index = seq_along(ks),
        model_i = i,
        individual_id = individual_ids[i],
        tattoo = ids[i],
        state_k = ks,
        from_year = years[ks - 1L],
        to_year = years[ks]
      )
    }
  )
) %>%
  mutate(active_index = row_number())

n_trans <- nrow(transition_map)

if (n_trans < 1L) {
  stop("No active annual movement intervals found.")
}

# Compact indices for every genuine latent annual AC and quarterly centre.
# These avoid monitoring the full ragged A/Q arrays while preserving every
# biologically active latent location from first through last observed year.
annual_state_map <- bind_rows(
  lapply(
    seq_len(nind),
    function(i) {
      ks <- first[i]:K[i]

      tibble(
        annual_active_index = seq_along(ks),
        model_i = i,
        individual_id = individual_ids[i],
        tattoo = ids[i],
        state_k = ks,
        year = years[ks]
      )
    }
  )
) %>%
  mutate(annual_active_index = row_number())

n_annual_states <- nrow(annual_state_map)
annual_i <- as.integer(annual_state_map$model_i)
annual_k <- as.integer(annual_state_map$state_k)

quarter_state_map <- annual_state_map %>%
  select(
    annual_active_index,
    model_i,
    individual_id,
    tattoo,
    state_k,
    year
  ) %>%
  tidyr::crossing(quarter = seq_len(J)) %>%
  arrange(annual_active_index, quarter) %>%
  mutate(quarter_active_index = row_number())

n_quarter_states <- nrow(quarter_state_map)
quarter_i <- as.integer(quarter_state_map$model_i)
quarter_j <- as.integer(quarter_state_map$quarter)
quarter_k <- as.integer(quarter_state_map$state_k)

if (n_annual_states < 1L || n_quarter_states != n_annual_states * J) {
  stop("Active latent-location index construction failed.")
}

# ---- observed annual + quarterly locations for initialization ----------------
annual_loc <- live %>%
  group_by(tattoo, primary) %>%
  summarise(
    x = mean(x),
    y = mean(y),
    .groups = "drop"
  )

quarter_loc <- live %>%
  group_by(tattoo, primary, trap_season) %>%
  summarise(
    x = mean(x),
    y = mean(y),
    .groups = "drop"
  )

is_valid_land_xy <- function(x, y) {
  cc <- floor((x - grid_xmin) / cell_size) + 1L
  rr <- floor((grid_ymax - y) / cell_size) + 1L
  inb <-
    rr >= 1L && rr <= n_rows &&
    cc >= 1L && cc <= n_cols

  inb &&
    !is.na(habitat_mat[rr, cc]) &&
    habitat_mat[rr, cc] == 1L
}

snap_to_land <- function(x, y) {
  if (is_valid_land_xy(x, y)) return(c(x, y))

  d2 <-
    (grid_xy[land_idx, 1] - x)^2 +
    (grid_xy[land_idx, 2] - y)^2

  grid_xy[land_idx[which.min(d2)], 1:2]
}

target_A <- array(NA_real_, c(nind, 2L, n_prim))
target_Q <- array(NA_real_, c(nind, 2L, J, n_prim))

for (i in seq_len(nind)) {
  aa <- annual_loc %>%
    filter(tattoo == ids[i]) %>%
    arrange(primary)

  kk <- first[i]:K[i]

  xi <- approx(aa$primary, aa$x, xout = kk, rule = 2)$y
  yi <- approx(aa$primary, aa$y, xout = kk, rule = 2)$y

  for (a in seq_along(kk)) {
    xy <- snap_to_land(xi[a], yi[a])
    target_A[i, 1, kk[a]] <- xy[1]
    target_A[i, 2, kk[a]] <- xy[2]
  }

  for (k in kk) {
    for (j in seq_len(J)) {
      qq <- quarter_loc %>%
        filter(
          tattoo == ids[i],
          primary == k,
          trap_season == j
        )

      if (nrow(qq)) {
        xy <- snap_to_land(qq$x[1], qq$y[1])
      } else {
        xy <- target_A[i, , k]
      }

      target_Q[i, 1, j, k] <- xy[1]
      target_Q[i, 2, j, k] <- xy[2]
    }
  }
}

# ---- compiled quarterly multi-location likelihood ---------------------------
# There is ONE capture/non-capture term per quarterly campaign. If captured,
# all observed detector locations contribute conditionally on the observed
# number of within-campaign captures.
calc_multi_quarter_prob <- nimbleFunction(
  run = function(
    Sx = double(0),
    Sy = double(0),
    X = double(2),
    sigma = double(0),
    lambda0 = double(0),
    H_vec = double(1),
    ncap = double(0),
    active = double(0)
  ) {
    returnType(double(0))

    if (active < 0.5) {
      return(1.0)
    }

    Rf <- dim(X)[1]
    G_sum <- 0.0
    g_vec <- numeric(Rf, init = FALSE)

    for (r in 1:Rf) {
      d2 <-
        (Sx - X[r, 1])^2 +
        (Sy - X[r, 2])^2

      g_val <- exp(-d2 / (2.0 * sigma^2))
      g_vec[r] <- g_val
      G_sum <- G_sum + g_val
    }

    Pcap <- 1.0 - exp(-lambda0 * G_sum)
    nc <- as.integer(ncap)

    if (nc < 1) {
      out <- 1.0 - Pcap
      if (out < 1e-300) out <- 1e-300
      return(out)
    }

    out <- Pcap

    for (m in 1:nc) {
      hh <- as.integer(H_vec[m])
      out <- out * g_vec[hh] / (G_sum + 1e-12)
    }

    if (out < 1e-300) out <- 1e-300
    if (out > 1.0) out <- 1.0

    return(out)
  }
)

# =============================================================================
# MODEL
# =============================================================================
code_V10B_collapsed <- nimbleCode({

  # ---------------------------------------------------------------------------
  # Detection around quarter-specific spatial centres
  # ---------------------------------------------------------------------------
  alpha_p ~ dnorm(qlogis(0.17), sd = 1.5)
  beta_p_sex ~ dnorm(0, sd = 1)

  alpha_logsigma ~ dnorm(log(150), sd = 1)
  beta_sigma_sex ~ dnorm(0, sd = 0.75)

  # ---------------------------------------------------------------------------
  # Within-year spatial variation around the annual activity centre
  # ---------------------------------------------------------------------------
  alpha_logomega ~ dnorm(log(150), sd = 1)
  omega <- exp(alpha_logomega)

  # Positive quarterly persistence on the logit scale.
  #
  # Computational parameterisation:
  #   qinnov_j ~ N(0, I) independently
  #   qeps_1 = qinnov_1
  #   qeps_j = rho*qeps_(j-1) + sqrt(1-rho^2)*qinnov_j
  #
  # This induces exactly the same stationary AR(1) distribution for qeps as
  # the centred V10B model but makes the sampled innovations independent of rho
  # a priori. It is therefore a pure MCMC reparameterisation.
  alpha_rho ~ dnorm(0, sd = 1.5)
  rho <- ilogit(alpha_rho)
  q_innov_scale <- sqrt(1 - rho * rho)

  # Marginal distance from the annual AC is unchanged from V10A.
  mean_quarter_offset_from_annual <-
    omega * MOVE_MEAN_FACTOR

  # Expected distance between ADJACENT quarterly centres under stationary
  # AR(1): each coordinate difference has variance 2*omega^2*(1-rho).
  mean_between_quarter_centres <-
    omega * QUARTER_DIFF_MEAN_FACTOR * sqrt(1 - rho)

  # ---------------------------------------------------------------------------
  # Annual local/high-mobility movement process
  # ---------------------------------------------------------------------------
  # Exact reparameterisation of:
  #   alpha_logmove ~ N(log(20), 1)
  #   beta_move_high ~ Exp(1)
  #   alpha_logmove_high = alpha_logmove + beta_move_high
  #
  # We sample the directly identified high-mobility log scale instead:
  beta_move_high ~ dexp(1)
  alpha_logmove_high ~
    dnorm(log(20) + beta_move_high, sd = 1)
  alpha_logmove <-
    alpha_logmove_high - beta_move_high

  beta_move_sex ~ dnorm(0, sd = 0.50)

  alpha_disp_init ~ dnorm(qlogis(0.06), sd = 1.25)
  beta_disp_adult ~ dnorm(0, sd = 1)
  beta_disp_init_sex ~ dnorm(0, sd = 1)

  alpha_RD ~ dnorm(qlogis(0.05), sd = 1.25)
  beta_RD_sex ~ dnorm(0, sd = 1)

  alpha_DD ~ dnorm(qlogis(0.30), sd = 1.25)
  beta_DD_sex ~ dnorm(0, sd = 1)

  # Detection time effects: same sum-to-zero structure as V8.
  for (s in 1:3) {
    beta_season_raw[s] ~ dnorm(0, sd = 1)
    beta_season[s] <- beta_season_raw[s]
  }
  beta_season[4] <- -sum(beta_season_raw[1:3])

  for (p in 1:(n_periods - 1)) {
    beta_period_raw[p] ~ dnorm(0, sd = 1)
    beta_period[p] <- beta_period_raw[p]
  }
  beta_period[n_periods] <-
    -sum(beta_period_raw[1:(n_periods - 1)])

  sigma_female <- exp(alpha_logsigma)
  sigma_male <- exp(alpha_logsigma + beta_sigma_sex)

  mean_annual_move_female_local <-
    exp(alpha_logmove) * MOVE_MEAN_FACTOR

  mean_annual_move_male_local <-
    exp(alpha_logmove + beta_move_sex) * MOVE_MEAN_FACTOR

  mean_annual_move_female_high <-
    exp(alpha_logmove + beta_move_high) * MOVE_MEAN_FACTOR

  mean_annual_move_male_high <-
    exp(
      alpha_logmove +
      beta_move_sex +
      beta_move_high
    ) * MOVE_MEAN_FACTOR

  for (i in 1:nind) {

    sigma_i[i] <-
      exp(
        alpha_logsigma +
        beta_sigma_sex * sex[i]
      )

    # -------------------------------------------------------------------------
    # First annual activity centre
    # -------------------------------------------------------------------------
    A[i, 1, first[i]] ~ dunif(grid_xmin, grid_xmax)
    A[i, 2, first[i]] ~ dunif(grid_ymin, grid_ymax)

    col_A_raw[i, first[i]] <-
      trunc(
        (A[i, 1, first[i]] - grid_xmin) /
          cell_size
      ) + 1

    row_A_raw[i, first[i]] <-
      trunc(
        (grid_ymax - A[i, 2, first[i]]) /
          cell_size
      ) + 1

    col_A[i, first[i]] <-
      max(
        1,
        min(n_cols, col_A_raw[i, first[i]])
      )

    row_A[i, first[i]] <-
      max(
        1,
        min(n_rows, row_A_raw[i, first[i]])
      )

    in_bounds_A[i, first[i]] <-
      step(A[i, 1, first[i]] - grid_xmin) *
      step(grid_xmax - A[i, 1, first[i]]) *
      step(A[i, 2, first[i]] - grid_ymin) *
      step(grid_ymax - A[i, 2, first[i]])

    habitat_A[i, first[i]] <-
      habitat_mat[
        row_A[i, first[i]],
        col_A[i, first[i]]
      ]

    valid_A[i, first[i]] <-
      in_bounds_A[i, first[i]] *
      habitat_A[i, first[i]]

    annual_state_ok[i, first[i]] ~
      dbern(valid_A[i, first[i]])

    # Sentinel: no movement state before first annual AC.
    p_disp_init[i] <-
      ilogit(
        alpha_disp_init +
        beta_disp_adult * adult_entry[i] +
        beta_disp_init_sex * sex[i]
      )

    # -------------------------------------------------------------------------
    # First-year quarterly spatial centres + observations
    #
    # Stationary AR(1) deviations around the annual AC, expressed through
    # iid innovations. This is distributionally identical to centred V10B.
    # -------------------------------------------------------------------------
    qinnov[i, 1:2, 1, first[i]] ~
      dmnorm(
        mean = q_zero[1:2],
        prec = q_prec[1:2, 1:2]
      )

    qeps[i, 1, 1, first[i]] <-
      qinnov[i, 1, 1, first[i]]
    qeps[i, 2, 1, first[i]] <-
      qinnov[i, 2, 1, first[i]]

    for (j in 2:J) {
      qinnov[i, 1:2, j, first[i]] ~
        dmnorm(
          mean = q_zero[1:2],
          prec = q_prec[1:2, 1:2]
        )

      qeps[i, 1, j, first[i]] <-
        rho * qeps[i, 1, j - 1, first[i]] +
        q_innov_scale * qinnov[i, 1, j, first[i]]

      qeps[i, 2, j, first[i]] <-
        rho * qeps[i, 2, j - 1, first[i]] +
        q_innov_scale * qinnov[i, 2, j, first[i]]
    }

    for (j in 1:J) {

      Qx[i, j, first[i]] <-
        A[i, 1, first[i]] +
        omega * qeps[i, 1, j, first[i]]

      Qy[i, j, first[i]] <-
        A[i, 2, first[i]] +
        omega * qeps[i, 2, j, first[i]]

      col_Q_raw[i, j, first[i]] <-
        trunc(
          (Qx[i, j, first[i]] - grid_xmin) /
            cell_size
        ) + 1

      row_Q_raw[i, j, first[i]] <-
        trunc(
          (grid_ymax - Qy[i, j, first[i]]) /
            cell_size
        ) + 1

      col_Q[i, j, first[i]] <-
        max(
          1,
          min(
            n_cols,
            col_Q_raw[i, j, first[i]]
          )
        )

      row_Q[i, j, first[i]] <-
        max(
          1,
          min(
            n_rows,
            row_Q_raw[i, j, first[i]]
          )
        )

      in_bounds_Q[i, j, first[i]] <-
        step(Qx[i, j, first[i]] - grid_xmin) *
        step(grid_xmax - Qx[i, j, first[i]]) *
        step(Qy[i, j, first[i]] - grid_ymin) *
        step(grid_ymax - Qy[i, j, first[i]])

      habitat_Q[i, j, first[i]] <-
        habitat_mat[
          row_Q[i, j, first[i]],
          col_Q[i, j, first[i]]
        ]

      valid_Q[i, j, first[i]] <-
        in_bounds_Q[i, j, first[i]] *
        habitat_Q[i, j, first[i]]

      quarter_state_ok[i, j, first[i]] ~
        dbern(valid_Q[i, j, first[i]])

      lp0[i, j, first[i]] <-
        alpha_p +
        beta_p_sex * sex[i] +
        beta_season[j] +
        beta_period[period_vec[first[i]]]

      lambda0[i, j, first[i]] <-
        -log(1 - ilogit(lp0[i, j, first[i]]))

      quarterProb[i, j, first[i]] <-
        calc_multi_quarter_prob(
          Qx[i, j, first[i]],
          Qy[i, j, first[i]],
          X[1:R, 1:2],
          sigma_i[i],
          lambda0[i, j, first[i]],
          H[i, j, 1:M, first[i]],
          ncap[i, j, first[i]],
          campaign_active[j, first[i]]
        )

      Ones[i, j, first[i]] ~
        dbern(quarterProb[i, j, first[i]])
    }

    # -------------------------------------------------------------------------
    # Subsequent annual states: exact collapsed two-state HMM
    #
    # The explicit binary disp path is integrated out. At each annual
    # displacement we use the forward-filtered predictive probability of the
    # high-mobility state and attach the exact two-component Gaussian mixture
    # density via a zeros trick. Because sigma >= 0.5 m, the maximum
    # bivariate Gaussian density is 1/(2*pi*0.5^2) < 1, so -log(density)
    # remains a valid non-negative Poisson mean.
    #
    # A itself receives a uniform reference density over the rectangular state
    # space. That density is constant over all valid habitat cells, so the
    # posterior is identical (up to a parameter-independent constant) to the
    # original centred HMM after summing over all disp paths.
    # -------------------------------------------------------------------------
    filtered_high[i, first[i]] <- 0

    for (k in (first[i] + 1):K[i]) {

      is_initial_interval[i, k] <-
        equals(k, first[i] + 1)

      p_RD_i[i, k] <-
        ilogit(
          alpha_RD +
          beta_RD_sex * sex[i]
        )

      p_DD_i[i, k] <-
        ilogit(
          alpha_DD +
          beta_DD_sex * sex[i]
        )

      p_high_pred[i, k] <-
        is_initial_interval[i, k] *
          p_disp_init[i] +
        (1 - is_initial_interval[i, k]) *
          (
            (1 - filtered_high[i, k - 1]) *
              p_RD_i[i, k] +
            filtered_high[i, k - 1] *
              p_DD_i[i, k]
          )

      # Numerical guard only; it matters solely if a logistic probability
      # underflows exactly to 0 or 1 in floating-point arithmetic.
      p_high_safe[i, k] <-
        max(
          1e-12,
          min(1 - 1e-12, p_high_pred[i, k])
        )

      log_sigma_move_local[i, k] <-
        alpha_logmove +
        beta_move_sex * sex[i]

      log_sigma_move_high[i, k] <-
        alpha_logmove +
        beta_move_sex * sex[i] +
        beta_move_high

      sigma_move_local[i, k] <-
        exp(log_sigma_move_local[i, k])

      sigma_move_high[i, k] <-
        exp(log_sigma_move_high[i, k])

      # Component-specific version of the broad V8 computational support.
      # In the original explicit-state HMM, only the ACTIVE state's movement
      # scale was subject to the computational support. After marginalising z,
      # the equivalent rule is to give an out-of-support component zero mixture
      # weight, not to reject the other valid component. Production V10B also
      # relaxes the old 5 m lower guard to 0.5 m because the 300-badger posterior
      # approached the old artificial boundary.
      move_support_local[i, k] <-
        step(
          log_sigma_move_local[i, k] -
          LOG_MOVE_MIN
        ) *
        step(
          LOG_MOVE_MAX -
          log_sigma_move_local[i, k]
        )

      move_support_high[i, k] <-
        step(
          log_sigma_move_high[i, k] -
          LOG_MOVE_MIN
        ) *
        step(
          LOG_MOVE_MAX -
          log_sigma_move_high[i, k]
        )

      move_any_support[i, k] <-
        max(
          move_support_local[i, k],
          move_support_high[i, k]
        )

      move_support_ok[i, k] ~
        dbern(move_any_support[i, k])

      # Clamp only for safe evaluation of the Gaussian log density. The
      # component-support indicator below still makes an invalid component's
      # contribution effectively zero.
      log_sigma_move_local_eval[i, k] <-
        max(
          LOG_MOVE_MIN,
          min(
            LOG_MOVE_MAX,
            log_sigma_move_local[i, k]
          )
        )

      log_sigma_move_high_eval[i, k] <-
        max(
          LOG_MOVE_MIN,
          min(
            LOG_MOVE_MAX,
            log_sigma_move_high[i, k]
          )
        )

      sigma_move_local_eval[i, k] <-
        exp(log_sigma_move_local_eval[i, k])

      sigma_move_high_eval[i, k] <-
        exp(log_sigma_move_high_eval[i, k])

      # Reference density for the annual position. The actual annual movement
      # density is supplied by move_zero below.
      A[i, 1, k] ~
        dunif(grid_xmin, grid_xmax)

      A[i, 2, k] ~
        dunif(grid_ymin, grid_ymax)

      moveD2[i, k] <-
        pow(A[i, 1, k] - A[i, 1, k - 1], 2) +
        pow(A[i, 2, k] - A[i, 2, k - 1], 2)

      moveDist[i, k] <-
        sqrt(moveD2[i, k])

      move_logdens_local[i, k] <-
        -LOG_TWO_PI -
        2 * log_sigma_move_local_eval[i, k] -
        moveD2[i, k] /
          (2 * pow(sigma_move_local_eval[i, k], 2))

      move_logdens_high[i, k] <-
        -LOG_TWO_PI -
        2 * log_sigma_move_high_eval[i, k] -
        moveD2[i, k] /
          (2 * pow(sigma_move_high_eval[i, k], 2))

      move_logcomp_local[i, k] <-
        log(1 - p_high_safe[i, k]) +
        move_logdens_local[i, k] +
        log(
          max(
            1e-300,
            move_support_local[i, k]
          )
        )

      move_logcomp_high[i, k] <-
        log(p_high_safe[i, k]) +
        move_logdens_high[i, k] +
        log(
          max(
            1e-300,
            move_support_high[i, k]
          )
        )

      move_logmax[i, k] <-
        max(
          move_logcomp_local[i, k],
          move_logcomp_high[i, k]
        )

      move_logmix[i, k] <-
        move_logmax[i, k] +
        log(
          exp(
            move_logcomp_local[i, k] -
            move_logmax[i, k]
          ) +
          exp(
            move_logcomp_high[i, k] -
            move_logmax[i, k]
          )
        )

      move_nll[i, k] <-
        max(1e-12, -move_logmix[i, k])

      move_zero[i, k] ~
        dpois(move_nll[i, k])

      # Forward-filtered state probability. This is used only to construct the
      # predictive state probability for the next transition; final smoothed
      # posterior state probabilities are recovered with a backward pass.
      filtered_high[i, k] <-
        exp(
          move_logcomp_high[i, k] -
          move_logmix[i, k]
        )

      col_A_raw[i, k] <-
        trunc(
          (A[i, 1, k] - grid_xmin) /
            cell_size
        ) + 1

      row_A_raw[i, k] <-
        trunc(
          (grid_ymax - A[i, 2, k]) /
            cell_size
        ) + 1

      col_A[i, k] <-
        max(
          1,
          min(n_cols, col_A_raw[i, k])
        )

      row_A[i, k] <-
        max(
          1,
          min(n_rows, row_A_raw[i, k])
        )

      in_bounds_A[i, k] <-
        step(A[i, 1, k] - grid_xmin) *
        step(grid_xmax - A[i, 1, k]) *
        step(A[i, 2, k] - grid_ymin) *
        step(grid_ymax - A[i, 2, k])

      habitat_A[i, k] <-
        habitat_mat[
          row_A[i, k],
          col_A[i, k]
        ]

      valid_A[i, k] <-
        in_bounds_A[i, k] *
        habitat_A[i, k]

      annual_state_ok[i, k] ~
        dbern(valid_A[i, k])

      # -----------------------------------------------------------------------
      # Four secondary quarterly centres in year k: stationary AR(1)
      # deviations around annual AC A[i,,k].
      # -----------------------------------------------------------------------
      qinnov[i, 1:2, 1, k] ~
        dmnorm(
          mean = q_zero[1:2],
          prec = q_prec[1:2, 1:2]
        )

      qeps[i, 1, 1, k] <-
        qinnov[i, 1, 1, k]
      qeps[i, 2, 1, k] <-
        qinnov[i, 2, 1, k]

      for (j in 2:J) {
        qinnov[i, 1:2, j, k] ~
          dmnorm(
            mean = q_zero[1:2],
            prec = q_prec[1:2, 1:2]
          )

        qeps[i, 1, j, k] <-
          rho * qeps[i, 1, j - 1, k] +
          q_innov_scale * qinnov[i, 1, j, k]

        qeps[i, 2, j, k] <-
          rho * qeps[i, 2, j - 1, k] +
          q_innov_scale * qinnov[i, 2, j, k]
      }

      for (j in 1:J) {

        Qx[i, j, k] <-
          A[i, 1, k] +
          omega * qeps[i, 1, j, k]

        Qy[i, j, k] <-
          A[i, 2, k] +
          omega * qeps[i, 2, j, k]

        col_Q_raw[i, j, k] <-
          trunc(
            (Qx[i, j, k] - grid_xmin) /
              cell_size
          ) + 1

        row_Q_raw[i, j, k] <-
          trunc(
            (grid_ymax - Qy[i, j, k]) /
              cell_size
          ) + 1

        col_Q[i, j, k] <-
          max(
            1,
            min(
              n_cols,
              col_Q_raw[i, j, k]
            )
          )

        row_Q[i, j, k] <-
          max(
            1,
            min(
              n_rows,
              row_Q_raw[i, j, k]
            )
          )

        in_bounds_Q[i, j, k] <-
          step(Qx[i, j, k] - grid_xmin) *
          step(grid_xmax - Qx[i, j, k]) *
          step(Qy[i, j, k] - grid_ymin) *
          step(grid_ymax - Qy[i, j, k])

        habitat_Q[i, j, k] <-
          habitat_mat[
            row_Q[i, j, k],
            col_Q[i, j, k]
          ]

        valid_Q[i, j, k] <-
          in_bounds_Q[i, j, k] *
          habitat_Q[i, j, k]

        quarter_state_ok[i, j, k] ~
          dbern(valid_Q[i, j, k])

        lp0[i, j, k] <-
          alpha_p +
          beta_p_sex * sex[i] +
          beta_season[j] +
          beta_period[period_vec[k]]

        lambda0[i, j, k] <-
          -log(1 - ilogit(lp0[i, j, k]))

        quarterProb[i, j, k] <-
          calc_multi_quarter_prob(
            Qx[i, j, k],
            Qy[i, j, k],
            X[1:R, 1:2],
            sigma_i[i],
            lambda0[i, j, k],
            H[i, j, 1:M, k],
            ncap[i, j, k],
            campaign_active[j, k]
          )

        Ones[i, j, k] ~
          dbern(quarterProb[i, j, k])
      }
    }
  }

  # Compact annual AC coordinates for every active badger-year.
  for (aa in 1:n_annual_states) {
    A_x_active[aa] <-
      A[annual_i[aa], 1, annual_k[aa]]

    A_y_active[aa] <-
      A[annual_i[aa], 2, annual_k[aa]]
  }

  # Compact quarterly spatial-use centres for every active badger-year-quarter.
  for (qq in 1:n_quarter_states) {
    Q_x_active[qq] <-
      Qx[quarter_i[qq], quarter_j[qq], quarter_k[qq]]

    Q_y_active[qq] <-
      Qy[quarter_i[qq], quarter_j[qq], quarter_k[qq]]
  }
})

# ---- constants/data ----------------------------------------------------------
q_zero <- c(0, 0)
q_prec <- diag(1, 2)

consts <- list(
  nind = nind,
  R = R,
  J = J,
  M = M,
  first = as.integer(first),
  K = as.integer(K),
  n_annual_states = n_annual_states,
  annual_i = annual_i,
  annual_k = annual_k,
  n_quarter_states = n_quarter_states,
  quarter_i = quarter_i,
  quarter_j = quarter_j,
  quarter_k = quarter_k,
  X = X,
  H = H,
  ncap = ncap,
  campaign_active = campaign_active,
  adult_entry = adult_entry,
  sex = sex_data,
  n_periods = n_periods,
  period_vec = period_vec,
  grid_xmin = grid_xmin,
  grid_xmax = grid_xmax,
  grid_ymin = grid_ymin,
  grid_ymax = grid_ymax,
  cell_size = cell_size,
  n_rows = n_rows,
  n_cols = n_cols,
  MOVE_MEAN_FACTOR = MOVE_MEAN_FACTOR,
  QUARTER_DIFF_MEAN_FACTOR = QUARTER_DIFF_MEAN_FACTOR,
  LOG_TWO_PI = LOG_TWO_PI,
  LOG_MOVE_MIN = LOG_MOVE_MIN,
  LOG_MOVE_MAX = LOG_MOVE_MAX,
  q_zero = q_zero,
  q_prec = q_prec
)

data_list <- list(
  Ones = array(1L, c(nind, J, n_prim)),
  move_zero = matrix(0L, nind, n_prim),
  annual_state_ok = matrix(1L, nind, n_prim),
  quarter_state_ok = array(1L, c(nind, J, n_prim)),
  move_support_ok = matrix(1L, nind, n_prim),
  habitat_mat = habitat_mat
)

# ---- initial values ----------------------------------------------------------
make_inits <- function(chain) {

  set.seed(9000 + chain)

  # Deliberately over-dispersed but plausible chain starts for the parameters
  # that have shown the strongest posterior geometry. These alter only MCMC
  # initialisation, not priors or likelihood.
  local_sigma_start <- c(8, 20, 40)[chain]
  high_sigma_start <- c(500, 800, 1200)[chain]
  omega_start <- c(5, 25, 100)[chain]
  rho_start <- c(0.15, 0.50, 0.80)[chain]

  alpha_logmove0 <- log(local_sigma_start)
  beta_move_sex0 <- c(-0.15, 0, 0.15)[chain]
  beta_move_high0 <- log(high_sigma_start / local_sigma_start)
  alpha_logmove_high0 <- log(high_sigma_start)
  alpha_logomega0 <- log(omega_start)
  alpha_rho0 <- qlogis(rho_start)

  A0 <- array(NA_real_, c(nind, 2L, n_prim))
  qeps_target0 <- array(NA_real_, c(nind, 2L, J, n_prim))
  qinnov0 <- array(NA_real_, c(nind, 2L, J, n_prim))

  omega0 <- exp(alpha_logomega0)
  rho0 <- rho_start
  innov_scale0 <- sqrt(1 - rho0 * rho0)

  for (i in seq_len(nind)) {

    for (k in first[i]:K[i]) {

      A0[i, 1, k] <- target_A[i, 1, k]
      A0[i, 2, k] <- target_A[i, 2, k]

      for (j in seq_len(J)) {
        qeps_target0[i, 1, j, k] <-
          (
            target_Q[i, 1, j, k] -
            target_A[i, 1, k]
          ) / omega0

        qeps_target0[i, 2, j, k] <-
          (
            target_Q[i, 2, j, k] -
            target_A[i, 2, k]
          ) / omega0
      }

      qinnov0[i, 1, 1, k] <- qeps_target0[i, 1, 1, k]
      qinnov0[i, 2, 1, k] <- qeps_target0[i, 2, 1, k]

      if (J >= 2L) {
        for (j in 2:J) {
          qinnov0[i, 1, j, k] <-
            (
              qeps_target0[i, 1, j, k] -
              rho0 * qeps_target0[i, 1, j - 1, k]
            ) / innov_scale0

          qinnov0[i, 2, j, k] <-
            (
              qeps_target0[i, 2, j, k] -
              rho0 * qeps_target0[i, 2, j - 1, k]
            ) / innov_scale0
        }
      }

    }
  }

  list(
    alpha_p = qlogis(c(0.12, 0.17, 0.24)[chain]),
    beta_p_sex = c(-0.10, 0, 0.10)[chain],
    alpha_logsigma = log(c(125, 150, 190)[chain]),
    beta_sigma_sex = c(-0.10, 0, 0.10)[chain],

    alpha_logomega = alpha_logomega0,
    alpha_rho = alpha_rho0,

    alpha_logmove_high = alpha_logmove_high0,
    beta_move_sex = beta_move_sex0,
    beta_move_high = beta_move_high0,

    alpha_disp_init = qlogis(c(0.03, 0.06, 0.12)[chain]),
    beta_disp_adult = c(-0.30, 0, 0.30)[chain],
    beta_disp_init_sex = c(-0.30, 0, 0.30)[chain],

    alpha_RD = qlogis(c(0.025, 0.05, 0.10)[chain]),
    beta_RD_sex = c(-0.30, 0, 0.30)[chain],

    alpha_DD = qlogis(c(0.15, 0.30, 0.55)[chain]),
    beta_DD_sex = c(-0.30, 0, 0.30)[chain],

    beta_season_raw = rnorm(3, 0, 0.03),
    beta_period_raw = rnorm(n_periods - 1L, 0, 0.03),

    A = A0,
    qinnov = qinnov0
  )
}

inits <- make_inits(CHAIN_ID)

# ---- optional exact continuation initialisation ------------------------------
# Continue from the final retained posterior draw of an existing fit. The saved
# chain contains every active annual AC (A) and quarterly centre (Q), so the
# non-centred innovations can be reconstructed exactly:
#
#   qeps_j = (Q_j - A) / omega
#   qinnov_1 = qeps_1
#   qinnov_j = (qeps_j - rho*qeps_(j-1)) / sqrt(1-rho^2)
#
# This is preferable to restarting from summary means because it resumes from a
# coherent point in the full latent posterior.
if (nzchar(INIT_FROM_STEM)) {

  init_file <- file.path(
    "results",
    paste0(
      INIT_FROM_STEM,
      "_",
      nind,
      "_CHAIN",
      CHAIN_ID,
      ".rds"
    )
  )

  if (!file.exists(init_file)) {
    stop("Continuation source file not found: ", init_file)
  }

  previous_fit <- readRDS(init_file)
  previous_samples <- as.matrix(previous_fit$samples)

  if (!nrow(previous_samples)) {
    stop("Continuation source contains no posterior draws: ", init_file)
  }

  last_draw <- previous_samples[nrow(previous_samples), , drop = TRUE]

  required_global_init <- c(
    "alpha_p",
    "beta_p_sex",
    "alpha_logsigma",
    "beta_sigma_sex",
    "alpha_logomega",
    "alpha_rho",
    "alpha_logmove_high",
    "beta_move_sex",
    "beta_move_high",
    "alpha_disp_init",
    "beta_disp_adult",
    "beta_disp_init_sex",
    "alpha_RD",
    "beta_RD_sex",
    "alpha_DD",
    "beta_DD_sex"
  )

  missing_global_init <-
    setdiff(required_global_init, names(last_draw))

  if (length(missing_global_init)) {
    stop(
      "Continuation source is missing monitored stochastic globals: ",
      paste(missing_global_init, collapse = ", ")
    )
  }

  for (nm in required_global_init) {
    inits[[nm]] <- unname(last_draw[[nm]])
  }

  season_cols <- paste0("beta_season_raw[", seq_len(3L), "]")
  period_cols <- paste0(
    "beta_period_raw[",
    seq_len(n_periods - 1L),
    "]"
  )

  if (!all(season_cols %in% names(last_draw))) {
    stop("Continuation source is missing beta_season_raw monitors.")
  }
  if (!all(period_cols %in% names(last_draw))) {
    stop("Continuation source is missing beta_period_raw monitors.")
  }

  inits$beta_season_raw <-
    unname(last_draw[season_cols])
  inits$beta_period_raw <-
    unname(last_draw[period_cols])

  A0_continue <- inits$A

  for (rr in seq_len(nrow(annual_state_map))) {
    aa <- annual_state_map$annual_active_index[rr]
    ii <- annual_state_map$model_i[rr]
    kk <- annual_state_map$state_k[rr]

    xcol <- paste0("A_x_active[", aa, "]")
    ycol <- paste0("A_y_active[", aa, "]")

    if (!xcol %in% names(last_draw) || !ycol %in% names(last_draw)) {
      stop(
        "Continuation source is missing annual latent monitor(s): ",
        xcol, " / ", ycol
      )
    }

    A0_continue[ii, 1, kk] <- unname(last_draw[[xcol]])
    A0_continue[ii, 2, kk] <- unname(last_draw[[ycol]])
  }

  omega_continue <- exp(inits$alpha_logomega)
  rho_continue <- plogis(inits$alpha_rho)
  innov_scale_continue <-
    sqrt(1 - rho_continue * rho_continue)

  qeps_continue <-
    array(NA_real_, c(nind, 2L, J, n_prim))
  qinnov_continue <-
    array(NA_real_, c(nind, 2L, J, n_prim))

  for (rr in seq_len(nrow(quarter_state_map))) {
    qq <- quarter_state_map$quarter_active_index[rr]
    ii <- quarter_state_map$model_i[rr]
    jj <- quarter_state_map$quarter[rr]
    kk <- quarter_state_map$state_k[rr]

    xcol <- paste0("Q_x_active[", qq, "]")
    ycol <- paste0("Q_y_active[", qq, "]")

    if (!xcol %in% names(last_draw) || !ycol %in% names(last_draw)) {
      stop(
        "Continuation source is missing quarterly latent monitor(s): ",
        xcol, " / ", ycol
      )
    }

    qeps_continue[ii, 1, jj, kk] <-
      (
        unname(last_draw[[xcol]]) -
        A0_continue[ii, 1, kk]
      ) / omega_continue

    qeps_continue[ii, 2, jj, kk] <-
      (
        unname(last_draw[[ycol]]) -
        A0_continue[ii, 2, kk]
      ) / omega_continue
  }

  for (ii in seq_len(nind)) {
    for (kk in first[ii]:K[ii]) {

      qinnov_continue[ii, 1, 1, kk] <-
        qeps_continue[ii, 1, 1, kk]
      qinnov_continue[ii, 2, 1, kk] <-
        qeps_continue[ii, 2, 1, kk]

      if (J >= 2L) {
        for (jj in 2:J) {
          qinnov_continue[ii, 1, jj, kk] <-
            (
              qeps_continue[ii, 1, jj, kk] -
              rho_continue *
                qeps_continue[ii, 1, jj - 1L, kk]
            ) / innov_scale_continue

          qinnov_continue[ii, 2, jj, kk] <-
            (
              qeps_continue[ii, 2, jj, kk] -
              rho_continue *
                qeps_continue[ii, 2, jj - 1L, kk]
            ) / innov_scale_continue
        }
      }
    }
  }

  active_qinnov <- unlist(
    lapply(
      seq_len(nind),
      function(ii) {
        qinnov_continue[
          ii,
          ,
          ,
          first[ii]:K[ii],
          drop = FALSE
        ]
      }
    )
  )

  if (any(!is.finite(active_qinnov))) {
    stop(
      "Continuation qinnov reconstruction produced non-finite active values."
    )
  }

  inits$A <- A0_continue
  inits$qinnov <- qinnov_continue

  cat(
    "Continuation initialisation reconstructed from final retained draw: ",
    init_file,
    "\n",
    sep = ""
  )

  rm(
    previous_fit,
    previous_samples,
    last_draw,
    A0_continue,
    qeps_continue,
    qinnov_continue,
    active_qinnov
  )
  invisible(gc())
}

# ---- collapsed-HMM algebra self-check ---------------------------------------
# Verify the sequential forward factorisation against brute-force summation for
# a short synthetic state sequence. This is a code-level identity check, not a
# model comparison.
hmm_forward_loglik_R <- function(d2, pi_high, p_RD, p_DD, sig0, sig1) {
  loge0 <- -log(2 * pi) - 2 * log(sig0) - d2 / (2 * sig0^2)
  loge1 <- -log(2 * pi) - 2 * log(sig1) - d2 / (2 * sig1^2)

  filt_high <- NA_real_
  out <- 0

  for (tt in seq_along(d2)) {
    pred_high <- if (tt == 1L) {
      pi_high
    } else {
      (1 - filt_high) * p_RD + filt_high * p_DD
    }

    lc0 <- log1p(-pred_high) + loge0[tt]
    lc1 <- log(pred_high) + loge1[tt]
    mm <- max(lc0, lc1)
    lm <- mm + log(exp(lc0 - mm) + exp(lc1 - mm))

    out <- out + lm
    filt_high <- exp(lc1 - lm)
  }

  out
}

hmm_bruteforce_loglik_R <- function(d2, pi_high, p_RD, p_DD, sig0, sig1) {
  Tn <- length(d2)
  states <- expand.grid(rep(list(0:1), Tn))
  vals <- numeric(nrow(states))

  for (rr in seq_len(nrow(states))) {
    z <- as.integer(states[rr, ])
    lp <- if (z[1] == 1L) log(pi_high) else log1p(-pi_high)

    for (tt in seq_len(Tn)) {
      sig <- if (z[tt] == 1L) sig1 else sig0
      lp <- lp - log(2 * pi) - 2 * log(sig) - d2[tt] / (2 * sig^2)

      if (tt < Tn) {
        p1 <- if (z[tt] == 1L) p_DD else p_RD
        lp <- lp + if (z[tt + 1L] == 1L) log(p1) else log1p(-p1)
      }
    }

    vals[rr] <- lp
  }

  mm <- max(vals)
  mm + log(sum(exp(vals - mm)))
}

self_d2 <- c(20^2, 350^2, 40^2, 700^2)
self_forward <- hmm_forward_loglik_R(
  self_d2, 0.07, 0.05, 0.30, 20, 500
)
self_brute <- hmm_bruteforce_loglik_R(
  self_d2, 0.07, 0.05, 0.30, 20, 500
)

if (!isTRUE(all.equal(self_forward, self_brute, tolerance = 1e-10))) {
  stop(
    "Collapsed HMM forward recursion failed brute-force identity check: ",
    self_forward, " vs ", self_brute
  )
}
cat("Collapsed HMM forward recursion self-check: PASS\n")

# ---- build -------------------------------------------------------------------
cat("\nBuilding NIMBLE model...\n")

build_time <- system.time(
  model <- nimbleModel(
    code_V10B_collapsed,
    constants = consts,
    data = data_list,
    inits = inits,
    dimensions = list(
      Ones = dim(data_list$Ones),
      move_zero = c(nind, n_prim),
      annual_state_ok = c(nind, n_prim),
      quarter_state_ok = c(nind, J, n_prim),
      move_support_ok = c(nind, n_prim),
      A = c(nind, 2L, n_prim),
      qinnov = c(nind, 2L, J, n_prim),
      qeps = c(nind, 2L, J, n_prim)
    ),
    check = TRUE,
    calculate = FALSE
  )
)

print(build_time)

lp <- model$calculate()
cat("Initial log probability:", lp, "\n")

if (!is.finite(lp)) {
  st <-
    model$getNodeNames(
      stochOnly = TRUE,
      includeData = TRUE
    )

  ll <- sapply(
    st,
    function(x) model$getLogProb(x)
  )

  bad <- tibble(node = st, logProb = ll) %>%
    filter(!is.finite(logProb))

  print(bad, n = Inf)
  stop("V10B collapsed-HMM initial log probability is not finite.")
}

cat("Initial model calculation: PASS\n")

compile_model_time <- system.time(
  cModel <- compileNimble(
    model,
    resetFunctions = TRUE
  )
)

cat("\nCompiled model:\n")
print(compile_model_time)

# ---- monitors ---------------------------------------------------------------
core_monitors <- c(
  "alpha_p",
  "beta_p_sex",
  "alpha_logsigma",
  "beta_sigma_sex",
  "alpha_logomega",
  "omega",
  "alpha_rho",
  "rho",
  "mean_quarter_offset_from_annual",
  "mean_between_quarter_centres",
  "alpha_logmove",
  "alpha_logmove_high",
  "beta_move_sex",
  "beta_move_high",
  "alpha_disp_init",
  "beta_disp_adult",
  "beta_disp_init_sex",
  "alpha_RD",
  "beta_RD_sex",
  "alpha_DD",
  "beta_DD_sex",
  "beta_season_raw",
  "beta_period_raw",
  "sigma_female",
  "sigma_male",
  "mean_annual_move_female_local",
  "mean_annual_move_male_local",
  "mean_annual_move_female_high",
  "mean_annual_move_male_high"
)

disp_index <- transition_map %>%
  mutate(
    recovered_state_column = paste0(
      "disp_active[",
      active_index,
      "]"
    )
  )

annual_state_index <- annual_state_map %>%
  mutate(
    sample_column_x = paste0(
      "A_x_active[",
      annual_active_index,
      "]"
    ),
    sample_column_y = paste0(
      "A_y_active[",
      annual_active_index,
      "]"
    )
  )

quarter_state_index <- quarter_state_map %>%
  mutate(
    sample_column_x = paste0(
      "Q_x_active[",
      quarter_active_index,
      "]"
    ),
    sample_column_y = paste0(
      "Q_y_active[",
      quarter_active_index,
      "]"
    )
  )

latent_monitors <- c(
  "A_x_active",
  "A_y_active",
  "Q_x_active",
  "Q_y_active"
)

config <- configureMCMC(
  model,
  monitors = unique(
    c(
      core_monitors,
      latent_monitors
    )
  ),
  thin = THIN
)

# Block key global parameters as in the V8 production model.
global_blocks <- list(
  c(
    "alpha_logmove_high",
    "beta_move_sex",
    "beta_move_high"
  ),
  c(
    "alpha_RD",
    "beta_RD_sex"
  ),
  c(
    "alpha_DD",
    "beta_DD_sex"
  ),
  c(
    "alpha_disp_init",
    "beta_disp_adult",
    "beta_disp_init_sex"
  ),
  c(
    "alpha_p",
    "beta_p_sex"
  ),
  c(
    "alpha_logsigma",
    "beta_sigma_sex"
  ),
  c(
    "alpha_logomega",
    "alpha_rho"
  )
)

for (b in global_blocks) {
  config$removeSamplers(b, print = FALSE)
  config$addSampler(
    target = b,
    type = "AF_slice"
  )
}

# Cross-chain diagnostics from the full production run showed that different
# chains can occupy alternative annual-trajectory modes for the same badger.
# Sampling each annual x/y pair separately requires a trajectory mode switch to
# pass through low-probability intermediate configurations. Here we remove all
# annual-A samplers for one badger and replace them with ONE AF_slice block
# containing that badger's complete annual trajectory.
#
# This is a sampler-only change. It does not alter the V10B posterior model.
trajectory_block_dimensions <- integer(nind)

for (i_aa in seq_len(nind)) {
  kk_aa <- first[i_aa]:K[i_aa]

  A_trajectory_block <- unlist(
    lapply(
      kk_aa,
      function(k_aa) {
        c(
          paste0("A[", i_aa, ", 1, ", k_aa, "]"),
          paste0("A[", i_aa, ", 2, ", k_aa, "]")
        )
      }
    ),
    use.names = FALSE
  )

  trajectory_block_dimensions[i_aa] <-
    length(A_trajectory_block)

  config$removeSamplers(
    A_trajectory_block,
    print = FALSE
  )

  config$addSampler(
    target = A_trajectory_block,
    type = "AF_slice"
  )
}

cat(
  "\nFinal sampler configuration:\n",
  "  Global AF_slice blocks: ", length(global_blocks), "\n",
  "  Whole-badger annual-trajectory AF_slice blocks: ", nind, "\n",
  "  Annual trajectory block dimension: median=", 
  median(trajectory_block_dimensions),
  ", p95=", unname(quantile(trajectory_block_dimensions, 0.95)),
  ", max=", max(trajectory_block_dimensions), "\n",
  "  Quarterly iid qinnov vectors retain NIMBLE RW_block samplers.\n",
  "  alpha_logomega + alpha_rho use a joint AF_slice block.\n",
  "  Annual movement states: analytically collapsed (no binary samplers).\n",
  sep = ""
)

# Printing every sampler is useful for small validation fits but produces tens
# of thousands of log lines for the full 1,932-badger production model.
if (MAX_BADGERS <= 300L) {
  config$printSamplers()
}

build_mcmc_time <- system.time(
  Rmcmc <- buildMCMC(config)
)

cat("\nBuilt MCMC:\n")
print(build_mcmc_time)

compile_mcmc_time <- system.time(
  cMCMC <- compileNimble(
    Rmcmc,
    project = cModel,
    resetFunctions = TRUE
  )
)

cat("\nCompiled MCMC:\n")
print(compile_mcmc_time)

# ---- run ---------------------------------------------------------------------
cat("\nRunning MCMC...\n")

checkpoint_file <- file.path(
  "results",
  paste0(
    OUTPUT_STEM,
    "_",
    nind,
    "_CHAIN",
    CHAIN_ID,
    "_RAW_CHECKPOINT.rds"
  )
)

runtime <- system.time(
  samples <- runMCMC(
    cMCMC,
    niter = NITER,
    nburnin = NBURN,
    thin = THIN,
    setSeed = 12000 + CHAIN_ID,
    samplesAsCodaMCMC = TRUE,
    progressBar = TRUE
  )
)

cat("\nRuntime:\n")
print(runtime)

# Save the raw chain immediately. This checkpoint is deliberately written
# before any summaries/post-processing so a completed MCMC run is not lost if
# later diagnostics fail.
saveRDS(
  list(
    model = "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM",
    fit_type = fit_type,
    chain_id = CHAIN_ID,
    settings = list(
      max_year = MAX_YEAR,
      max_badgers = MAX_BADGERS,
      init_from_stem = if (nzchar(INIT_FROM_STEM)) INIT_FROM_STEM else NA_character_,
      output_stem = OUTPUT_STEM,
      niter = NITER,
      nburn = NBURN,
      thin = THIN
    ),
    ids = ids,
    individual_ids = individual_ids,
    years = years,
    first = first,
    K = K,
    sex_data = sex_data,
    adult_entry = adult_entry,
    disp_index = disp_index,
    annual_state_index = annual_state_index,
    quarter_state_index = quarter_state_index,
    samples = samples,
    runtime = runtime
  ),
  checkpoint_file
)

cat("\nRaw MCMC checkpoint saved:\n", checkpoint_file, "\n", sep = "")

sample_mat <- as.matrix(samples)

# ---- compact smoke diagnostics ----------------------------------------------
annual_x_cols <- grep(
  "^A_x_active\\[",
  colnames(sample_mat),
  value = TRUE
)
annual_y_cols <- grep(
  "^A_y_active\\[",
  colnames(sample_mat),
  value = TRUE
)
quarter_x_cols <- grep(
  "^Q_x_active\\[",
  colnames(sample_mat),
  value = TRUE
)
quarter_y_cols <- grep(
  "^Q_y_active\\[",
  colnames(sample_mat),
  value = TRUE
)

if (
  length(annual_x_cols) != nrow(annual_state_index) ||
  length(annual_y_cols) != nrow(annual_state_index)
) {
  stop("Annual latent-location monitor count does not match annual_state_index.")
}

if (
  length(quarter_x_cols) != nrow(quarter_state_index) ||
  length(quarter_y_cols) != nrow(quarter_state_index)
) {
  stop("Quarterly latent-location monitor count does not match quarter_state_index.")
}

latent_cols <- c(
  annual_x_cols,
  annual_y_cols,
  quarter_x_cols,
  quarter_y_cols
)

global_cols <- setdiff(
  colnames(sample_mat),
  latent_cols
)

cat(
  "\nSaved latent locations:",
  nrow(annual_state_index), "annual ACs and",
  nrow(quarter_state_index), "quarterly centres per posterior draw.\n"
)
cat(
  "Movement states are collapsed from the MCMC and will be recovered by ",
  "forward-backward smoothing / FFBS.\n",
  sep = ""
)

nonfinite_by_parameter <- tibble(
  parameter = global_cols,
  n_na = vapply(
    global_cols,
    function(z) sum(is.na(sample_mat[, z])),
    integer(1)
  ),
  n_nan = vapply(
    global_cols,
    function(z) sum(is.nan(sample_mat[, z])),
    integer(1)
  ),
  n_inf = vapply(
    global_cols,
    function(z) sum(is.infinite(sample_mat[, z])),
    integer(1)
  )
) %>%
  mutate(n_nonfinite = n_na + n_inf) %>%
  filter(n_nonfinite > 0L)

if (nrow(nonfinite_by_parameter)) {
  cat("\nMonitored global parameters containing non-finite draws:\n")
  print(nonfinite_by_parameter, n = Inf, width = Inf)
}

safe_mean <- function(z) {
  z <- z[is.finite(z)]
  if (!length(z)) return(NA_real_)
  mean(z)
}

safe_sd <- function(z) {
  z <- z[is.finite(z)]
  if (length(z) < 2L) return(NA_real_)
  sd(z)
}

safe_quantile <- function(z, p) {
  z <- z[is.finite(z)]
  if (!length(z)) return(NA_real_)
  unname(quantile(z, probs = p, names = FALSE))
}

global_summary <- tibble(
  parameter = global_cols,
  mean = vapply(
    global_cols,
    function(z) safe_mean(sample_mat[, z]),
    numeric(1)
  ),
  sd = vapply(
    global_cols,
    function(z) safe_sd(sample_mat[, z]),
    numeric(1)
  ),
  q025 = vapply(
    global_cols,
    function(z) safe_quantile(sample_mat[, z], 0.025),
    numeric(1)
  ),
  median = vapply(
    global_cols,
    function(z) safe_quantile(sample_mat[, z], 0.5),
    numeric(1)
  ),
  q975 = vapply(
    global_cols,
    function(z) safe_quantile(sample_mat[, z], 0.975),
    numeric(1)
  )
)

key_parameters <- c(
  "sigma_female",
  "sigma_male",
  "omega",
  "rho",
  "mean_quarter_offset_from_annual",
  "mean_between_quarter_centres",
  "mean_annual_move_female_local",
  "mean_annual_move_male_local",
  "mean_annual_move_female_high",
  "mean_annual_move_male_high",
  "alpha_RD",
  "beta_RD_sex",
  "alpha_DD",
  "beta_DD_sex"
)

cat("\n============================================================\n")
cat("V10B COLLAPSED-HMM SMOKE SUMMARY\n")
cat("============================================================\n")

print(
  global_summary %>%
    filter(parameter %in% key_parameters),
  n = Inf,
  width = Inf
)

# Observation architecture audit embedded in output.
quarter_counts <- live_slots %>%
  count(tattoo, primary, trap_season) %>%
  count(n, name = "n_badger_quarters")

cat("\nObserved captures retained:", nrow(live_slots), "\n")
cat(
  "Observed badger-quarters:",
  nrow(
    live_slots %>%
      distinct(tattoo, primary, trap_season)
  ),
  "\n"
)
cat("Within-quarter capture-count distribution:\n")
print(quarter_counts, n = Inf)

# ---- save --------------------------------------------------------------------
out_file <- file.path(
  "results",
  paste0(
    OUTPUT_STEM,
    "_",
    nind,
    "_CHAIN",
    CHAIN_ID,
    ".rds"
  )
)

saveRDS(
  list(
    model = "V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_HMM",
    fit_type = fit_type,
    chain_id = CHAIN_ID,
    settings = list(
      max_year = MAX_YEAR,
      max_badgers = MAX_BADGERS,
      niter = NITER,
      nburn = NBURN,
      thin = THIN,
      primary_period = "year",
      secondary_occasions = "quarterly trapping campaigns",
      multiple_locations_per_quarter = TRUE,
      within_year_structure =
        "stationary AR(1) quarterly deviations around annual activity centre",
      quarter_persistence_parameter = "rho in (0,1)",
      annual_movement_parameterization =
        "centered annual AC with two-state Gaussian HMM analytically collapsed",
      movement_support =
        "component-specific support semantics matching explicit-state V10B; lower numerical guard relaxed to 0.5 m",
      movement_state_inference =
        "posthoc forward-backward smoothing and FFBS from annual AC draws",
      annual_AC_sampler =
        "whole-badger annual A trajectory in one AF_slice block (sampler validation)",
      quarter_deviation_parameterization =
        "iid bivariate qinnov with deterministic stationary AR1 recursion to qeps",
      quarter_deviation_sampler =
        "bivariate RW_block on qinnov",
      rho_sampler =
        "joint AF_slice with alpha_logomega",
      annual_movement_scale_parameterization =
        "direct stochastic high log-scale plus positive contrast; local log-scale deterministic; exact prior transform",
      chain_initialisation =
        if (nzchar(INIT_FROM_STEM)) {
          paste0(
            "continued from final retained draw of ",
            INIT_FROM_STEM
          )
        } else {
          "deliberately over-dispersed plausible starts across chains 1--3"
        },
      sampler_validation =
        "whole-trajectory A blocking + non-centred AR1 + direct high-mobility scale; biology and priors unchanged",
      landscape_resistance = FALSE
    ),
    ids = ids,
    individual_ids = individual_ids,
    years = years,
    first = first,
    K = K,
    sex_data = sex_data,
    adult_entry = adult_entry,
    detectors = detectors,
    ncap = ncap,
    H = H,
    campaign_active = campaign_active,
    core_monitors = core_monitors,
    latent_monitors = latent_monitors,
    disp_index = disp_index,
    annual_state_index = annual_state_index,
    quarter_state_index = quarter_state_index,
    samples = samples,
    global_summary = global_summary,
    nonfinite_by_parameter = nonfinite_by_parameter,
    runtime = runtime
  ),
  out_file
)

cat("\nSaved:\n", out_file, "\n", sep = "")
