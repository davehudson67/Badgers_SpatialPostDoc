# =============================================================================
# WOODCHESTER V10A - ANNUAL-PRIMARY RD-SCR WITH MULTIPLE QUARTER LOCATIONS
#
# PURPOSE
#   Smoke/identifiability fit for the revised movement model:
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
# ENVIRONMENT OPTIONS
#   CHAIN_ID      1, 2 or 3 (default 1)
#   MAX_BADGERS   number of audited movement badgers for smoke fit (default 300).
#                 Use 1932 for the full audited movement population.
#   NITER         default 2000
#   NBURN         default 1000
#   THIN          default 2
#
# OUTPUT
#   results/V10A_RD_MULTILOC_<N>_CHAIN<chain>.rds
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

MOVE_MEAN_FACTOR <- sqrt(pi / 2)
QUARTER_DIFF_MEAN_FACTOR <- sqrt(pi)

# Annual movement support: retained from V8 as a broad computational guard.
LOG_MOVE_MIN <- log(5)
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
cat("WOODCHESTER V10A: ANNUAL-PRIMARY RD-SCR + MULTIPLE LOCATIONS\n")
cat("============================================================\n")
cat(
  "Chain:", CHAIN_ID,
  "| MAX_BADGERS:", MAX_BADGERS,
  "| iterations:", NITER,
  "| burn:", NBURN,
  "| thin:", THIN, "\n"
)

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
code_V10A <- nimbleCode({

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

  # For an isotropic bivariate Gaussian quarter offset:
  #   distance from annual AC ~ Rayleigh(scale = omega)
  #   difference between two independent quarter centres
  #     ~ Rayleigh(scale = sqrt(2) * omega)
  mean_quarter_offset_from_annual <-
    omega * MOVE_MEAN_FACTOR

  mean_between_quarter_centres <-
    omega * QUARTER_DIFF_MEAN_FACTOR

  # ---------------------------------------------------------------------------
  # Annual local/high-mobility movement process
  # ---------------------------------------------------------------------------
  alpha_logmove ~ dnorm(log(20), sd = 1)
  beta_move_sex ~ dnorm(0, sd = 0.50)
  beta_move_high ~ dexp(1)

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
    # -------------------------------------------------------------------------
    for (j in 1:J) {

      qeps[i, 1:2, j, first[i]] ~
        dmnorm(
          mean = q_zero[1:2],
          prec = q_prec[1:2, 1:2]
        )

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
    # Subsequent annual states
    # -------------------------------------------------------------------------
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

      p_disp_markov[i, k] <-
        (1 - disp[i, k - 1]) *
          p_RD_i[i, k] +
        disp[i, k - 1] *
          p_DD_i[i, k]

      p_disp_state[i, k] <-
        is_initial_interval[i, k] *
          p_disp_init[i] +
        (1 - is_initial_interval[i, k]) *
          p_disp_markov[i, k]

      disp[i, k] ~
        dbern(p_disp_state[i, k])

      log_sigma_move[i, k] <-
        alpha_logmove +
        beta_move_sex * sex[i] +
        beta_move_high * disp[i, k]

      sigma_move[i, k] <-
        exp(log_sigma_move[i, k])

      move_support[i, k] <-
        step(
          log_sigma_move[i, k] -
          LOG_MOVE_MIN
        ) *
        step(
          LOG_MOVE_MAX -
          log_sigma_move[i, k]
        )

      move_support_ok[i, k] ~
        dbern(move_support[i, k])

      eps[i, 1:2, k] ~
        dmnorm(
          mean = eps_zero[1:2],
          prec = eps_prec[1:2, 1:2]
        )

      A[i, 1, k] <-
        A[i, 1, k - 1] +
        sigma_move[i, k] *
        eps[i, 1, k]

      A[i, 2, k] <-
        A[i, 2, k - 1] +
        sigma_move[i, k] *
        eps[i, 2, k]

      moveDist[i, k] <-
        sigma_move[i, k] *
        sqrt(
          pow(eps[i, 1, k], 2) +
          pow(eps[i, 2, k], 2)
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
      # Four secondary quarterly centres in year k
      # -----------------------------------------------------------------------
      for (j in 1:J) {

        qeps[i, 1:2, j, k] ~
          dmnorm(
            mean = q_zero[1:2],
            prec = q_prec[1:2, 1:2]
          )

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
})

# ---- constants/data ----------------------------------------------------------
eps_zero <- c(0, 0)
eps_prec <- diag(1, 2)
q_zero <- c(0, 0)
q_prec <- diag(1, 2)

consts <- list(
  nind = nind,
  R = R,
  J = J,
  M = M,
  first = as.integer(first),
  K = as.integer(K),
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
  LOG_MOVE_MIN = LOG_MOVE_MIN,
  LOG_MOVE_MAX = LOG_MOVE_MAX,
  eps_zero = eps_zero,
  eps_prec = eps_prec,
  q_zero = q_zero,
  q_prec = q_prec
)

disp_data <- matrix(NA_integer_, nind, n_prim)
for (i in seq_len(nind)) {
  disp_data[i, first[i]] <- 0L
}

data_list <- list(
  Ones = array(1L, c(nind, J, n_prim)),
  disp = disp_data,
  annual_state_ok = matrix(1L, nind, n_prim),
  quarter_state_ok = array(1L, c(nind, J, n_prim)),
  move_support_ok = matrix(1L, nind, n_prim),
  habitat_mat = habitat_mat
)

# ---- initial values ----------------------------------------------------------
make_inits <- function(chain) {

  set.seed(9000 + chain)

  alpha_logmove0 <- log(20) + rnorm(1, 0, 0.05)
  beta_move_sex0 <- rnorm(1, 0, 0.03)
  beta_move_high0 <- 4.0 + rnorm(1, 0, 0.08)
  alpha_logomega0 <- log(150) + rnorm(1, 0, 0.03)

  A0 <- array(NA_real_, c(nind, 2L, n_prim))
  eps0 <- array(NA_real_, c(nind, 2L, n_prim))
  qeps0 <- array(NA_real_, c(nind, 2L, J, n_prim))
  disp0 <- matrix(NA_integer_, nind, n_prim)

  omega0 <- exp(alpha_logomega0)

  for (i in seq_len(nind)) {

    A0[i, 1, first[i]] <- target_A[i, 1, first[i]]
    A0[i, 2, first[i]] <- target_A[i, 2, first[i]]

    for (k in first[i]:K[i]) {

      for (j in seq_len(J)) {
        qeps0[i, 1, j, k] <-
          (
            target_Q[i, 1, j, k] -
            target_A[i, 1, k]
          ) / omega0

        qeps0[i, 2, j, k] <-
          (
            target_Q[i, 2, j, k] -
            target_A[i, 2, k]
          ) / omega0
      }

      if (k > first[i]) {
        dx <-
          target_A[i, 1, k] -
          target_A[i, 1, k - 1]

        dy <-
          target_A[i, 2, k] -
          target_A[i, 2, k - 1]

        dd <- sqrt(dx^2 + dy^2)

        d0 <-
          rbinom(
            1,
            1,
            plogis((dd - 150) / 50)
          )

        disp0[i, k] <- d0

        sig0 <-
          exp(
            alpha_logmove0 +
            beta_move_sex0 * sex_data[i] +
            beta_move_high0 * d0
          )

        eps0[i, 1, k] <- dx / sig0
        eps0[i, 2, k] <- dy / sig0
      }
    }
  }

  list(
    alpha_p = qlogis(0.17) + rnorm(1, 0, 0.05),
    beta_p_sex = rnorm(1, 0, 0.03),
    alpha_logsigma = log(150) + rnorm(1, 0, 0.03),
    beta_sigma_sex = rnorm(1, 0, 0.02),

    alpha_logomega = alpha_logomega0,

    alpha_logmove = alpha_logmove0,
    beta_move_sex = beta_move_sex0,
    beta_move_high = beta_move_high0,

    alpha_disp_init = qlogis(0.06) + rnorm(1, 0, 0.08),
    beta_disp_adult = rnorm(1, 0, 0.05),
    beta_disp_init_sex = rnorm(1, 0, 0.05),

    alpha_RD = qlogis(0.05) + rnorm(1, 0, 0.08),
    beta_RD_sex = rnorm(1, 0, 0.05),

    alpha_DD = qlogis(0.30) + rnorm(1, 0, 0.08),
    beta_DD_sex = rnorm(1, 0, 0.05),

    beta_season_raw = rnorm(3, 0, 0.03),
    beta_period_raw = rnorm(n_periods - 1L, 0, 0.03),

    A = A0,
    eps = eps0,
    qeps = qeps0,
    disp = disp0
  )
}

inits <- make_inits(CHAIN_ID)

# ---- build -------------------------------------------------------------------
cat("\nBuilding NIMBLE model...\n")

build_time <- system.time(
  model <- nimbleModel(
    code_V10A,
    constants = consts,
    data = data_list,
    inits = inits,
    dimensions = list(
      Ones = dim(data_list$Ones),
      disp = c(nind, n_prim),
      annual_state_ok = c(nind, n_prim),
      quarter_state_ok = c(nind, J, n_prim),
      move_support_ok = c(nind, n_prim),
      eps = c(nind, 2L, n_prim),
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
  stop("V10A initial log probability is not finite.")
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
  "mean_quarter_offset_from_annual",
  "mean_between_quarter_centres",
  "alpha_logmove",
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

disp_index <- bind_rows(
  lapply(
    seq_len(nind),
    function(i) {

      ks <- (first[i] + 1L):K[i]

      tibble(
        model_i = i,
        individual_id = individual_ids[i],
        tattoo = ids[i],
        state_k = ks,
        from_year = years[ks - 1L],
        to_year = years[ks],
        node = paste0(
          "disp[",
          i,
          ", ",
          ks,
          "]"
        )
      )
    }
  )
)

disp_nodes <- disp_index$node

config <- configureMCMC(
  model,
  monitors = unique(c(core_monitors, disp_nodes)),
  thin = THIN
)

# Block key global parameters as in the V8 production model.
global_blocks <- list(
  c(
    "alpha_logmove",
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
  )
)

for (b in global_blocks) {
  config$removeSamplers(b, print = FALSE)
  config$addSampler(
    target = b,
    type = "AF_slice"
  )
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
    "V10A_RD_MULTILOC_",
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
    model = "V10A_RD_SCR_MULTILOC",
    fit_type = fit_type,
    chain_id = CHAIN_ID,
    settings = list(
      max_year = MAX_YEAR,
      max_badgers = MAX_BADGERS,
      niter = NITER,
      nburn = NBURN,
      thin = THIN
    ),
    ids = ids,
    individual_ids = individual_ids,
    years = years,
    first = first,
    K = K,
    samples = samples,
    runtime = runtime
  ),
  checkpoint_file
)

cat("\nRaw MCMC checkpoint saved:\n", checkpoint_file, "\n", sep = "")

sample_mat <- as.matrix(samples)

# ---- compact smoke diagnostics ----------------------------------------------
global_cols <- setdiff(
  colnames(sample_mat),
  disp_nodes
)

global_summary <- tibble(
  parameter = global_cols,
  mean = colMeans(sample_mat[, global_cols, drop = FALSE]),
  sd = apply(
    sample_mat[, global_cols, drop = FALSE],
    2,
    sd
  ),
  q025 = apply(
    sample_mat[, global_cols, drop = FALSE],
    2,
    quantile,
    probs = 0.025
  ),
  median = apply(
    sample_mat[, global_cols, drop = FALSE],
    2,
    median
  ),
  q975 = apply(
    sample_mat[, global_cols, drop = FALSE],
    2,
    quantile,
    probs = 0.975
  )
)

key_parameters <- c(
  "sigma_female",
  "sigma_male",
  "omega",
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
cat("V10A SMOKE SUMMARY\n")
cat("============================================================\n")

print(
  global_summary %>%
    filter(parameter %in% key_parameters),
  n = Inf,
  width = Inf
)

if (length(disp_nodes)) {
  disp_prob <-
    colMeans(
      sample_mat[, disp_nodes, drop = FALSE]
    )

  cat(
    "\nMean posterior high-mobility occupancy:",
    mean(disp_prob), "\n"
  )
}

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
    "V10A_RD_MULTILOC_",
    nind,
    "_CHAIN",
    CHAIN_ID,
    ".rds"
  )
)

saveRDS(
  list(
    model = "V10A_RD_SCR_MULTILOC",
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
        "quarter-specific spatial centre around annual activity centre",
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
    disp_index = disp_index,
    samples = samples,
    global_summary = global_summary,
    runtime = runtime
  ),
  out_file
)

cat("\nSaved:\n", out_file, "\n", sep = "")
