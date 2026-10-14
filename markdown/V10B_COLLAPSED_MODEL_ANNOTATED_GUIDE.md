# Woodchester V10B collapsed-HMM movement model
## Annotated guide to the production code

Source file: scripts/ModularFitting/Woodchester_V10B_RD_SCR_MULTILOC_AR1_COLLAPSED.R  
Source blob SHA: af6e97a372a74c51764ff80999a00dcc9cf95ade  
Branch: audit-tattoo-identifier  
Guide date: 8 October 2026

This is a live teaching document for the exact movement model now being run on the full 1,932-badger population.

The aim is to distinguish four things that are easy to mix together in a long NIMBLE script:

1. data preparation inside the fitting file;
2. the statistical model itself;
3. MCMC starting values;
4. computational/sampler choices.

Only items 1 and 2 define what biological information enters the posterior. Starting values and samplers affect whether the computer can explore that posterior efficiently, but they do not change the model being fitted.

The biological hierarchy is:

$$
\text{annual movement state}
\rightarrow
A_{i,t}
\rightarrow
Q_{i,t,q}
\rightarrow
\text{quarterly capture and capture locations}.
$$

A is the annual activity centre.  
Q is the quarter-specific centre.  
Sigma describes observed capture-location spread around Q.  
Omega describes quarter-centre spread around A.  
Annual movement sigma describes movement of A between years.

---

# 1. Header, libraries, run options and numerical constants

```r
# =============================================================================
# WOODCHESTER V10B - ANNUAL-PRIMARY RD-SCR WITH MULTIPLE QUARTER LOCATIONS
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
#
# OUTPUT
#   results/V10B_RD_MULTILOC_AR1_COLLAPSED_<N>_CHAIN<chain>.rds
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

```


### Explanation

The comments at the top state the design. Years are primary periods and the four quarterly trapping campaigns are secondary occasions. Every usable capture location within a quarter is retained.

The libraries are used as follows:

- tidyverse: data manipulation;
- lubridate: date handling;
- nimble: Bayesian model definition and MCMC;
- coda: MCMC object handling;
- sf: spatial state-space objects.

The first seed makes R-side preprocessing reproducible. Later sections deliberately use separate seeds for the smoke subset, initial values and MCMC.

MAX_YEAR is 2025 because 2026 is not a complete annual primary period. The model therefore does not create a partially observed 2026 movement year.

EXPECTED_FULL_N equals 1932. This is a safety assertion. If the upstream audited movement population changes, the fit stops rather than silently analysing a different population.

CHAIN_ID chooses chain 1, 2 or 3. MAX_BADGERS allows exactly the same code to run a 300-badger validation fit or the full 1932 fit. NITER, NBURN and THIN control MCMC length.

MOVE_MEAN_FACTOR equals

$$
\sqrt{\pi/2}.
$$

If x and y movement increments are independent Gaussian variables with the same coordinate standard deviation sigma, the radial distance is Rayleigh distributed and has mean sigma times this factor.

QUARTER_DIFF_MEAN_FACTOR equals

$$
\sqrt{\pi}
$$

and is used later to report the expected distance between adjacent quarter centres under the AR(1).

LOG_TWO_PI is cached because it occurs repeatedly in the bivariate Gaussian movement density.

The annual movement support is only a numerical guard:

$$
0.5 < \sigma_{\rm move} < 2500 {\rm m}.
$$

The lower guard used to be 5 m. The 300-badger diagnostic showed that the male local posterior was hitting that value, so it was influencing inference. It was therefore relaxed to 0.5 m.

At sigma = 0.5 m the peak bivariate Gaussian density is still

$$
1/(2\pi 0.5^2) \approx 0.637 < 1,
$$

which is important for the Poisson zeros trick later.

The required-file checks make a production run fail immediately if an audited input is missing.

One small code-cleanliness point: the individual RDS is currently read later but the resulting object is not actually used by this model. That is harmless and can be cleaned after the production run.

---

# 2. Sett cleaning and definition of the fitting population

```r
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

```


### Explanation

The sett-cleaning functions ensure that historical punctuation, spaces and known aliases do not create false detector identities.

The first cleaner:

- converts to character;
- upper-cases names;
- replaces punctuation;
- collapses whitespace;
- removes generic terms such as SETT, MAIN and OUTLIER;
- removes spaces.

The alias table then maps known historical synonyms onto a single canonical detector name.

The model does not decide for itself which badgers are eligible. It reads the already-audited population object and keeps only movement_eligible animals.

Sex is coded female = 0 and male = 1. Adult_entry is 1 only for the adult-exact-age-unknown entry class.

This is worth understanding because adult_entry does not mean proven immigrant. It is an entry-history descriptor that is used only in the initial high-mobility probability later.

The hard 1932 count check protects the analysis against upstream population drift.

For smoke tests, the code draws a reproducible random subset with seed 101. Production uses all 1932.

---

# 3. State space and exact sett coordinates

```r
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

```


### Explanation

The current V10B model uses the habitat matrix but deliberately does not use static social-group resistance.

The rectangular limits, 50 m cell size, row count and column count are the geometry used to map any continuous latent x-y coordinate to a habitat cell.

The grid coordinates are needed mainly for initialisation and snapping invalid starting values onto land.

The code then discovers which columns in the sett table contain the name, Easting and Northing. This makes the script robust to older column naming conventions.

The coordinate audit is scientifically important. After cleaning, one detector name must map to exactly one coordinate pair. If it maps to more than one, the model stops.

---

# 4. Live captures, detector network and active campaigns

```r
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

```


### Explanation

Only live captures enter this movement fit. Records must have:

- a primary year;
- year no later than 2025;
- quarter 1 to 4;
- a sett that can be mapped to coordinates.

Post-mortem records are intentionally absent. Mortality and survival belong in the later open-population model.

The detector network is built from the full audited 1932 population, not from a 300-animal smoke subset. Therefore the detector geometry is identical between validation and production fits.

For detector r:

$$
X_r=(x_r,y_r).
$$

All detector coordinates are collected in the matrix X.

The year vector runs from the first usable year in the audited population to 2025. There are four secondary occasions per year.

M is the maximum number of captures for one badger in one quarter. It is currently three.

Five-year periods are created for the detection model because capture conditions and study practice may have changed over the nearly 50-year series.

campaign_active is one if at least one successful live capture occurred anywhere in the audited population in that year-quarter.

This is an effort approximation. A completely empty study-wide quarter is not automatically treated as a trapping campaign in which every badger was missed. We lack complete historical detector-by-night effort, so that would be too strong an assumption.

---

# 5. Capture arrays, first/last years and latent-state indexes

```r
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

```


### Explanation

H stores detector identities for every observed within-quarter capture.

Conceptually:

$$
H_{i,q,m,t}=r
$$

means that the m-th capture of badger i in quarter q of year t occurred at detector r.

ncap stores the number of observed captures in each badger-quarter.

Unused H slots contain the value 1 only as padding. The likelihood loops only to ncap, so padded slots do not contribute.

This is the key V10 observation improvement: every usable location is retained rather than choosing a single representative sett.

For each animal, first is the first observed spatial live year and K is the last.

The model therefore conditions on the time window

$$
first_i,\ldots,K_i.
$$

It does not yet answer what happened after the last observation. Death and permanent emigration are not part of V10B.

However, missing years inside that window remain in the model. If an animal is observed in 1990 and 1993, the model still creates latent annual activity centres for 1991 and 1992.

transition_map, annual_state_map and quarter_state_map are bookkeeping tables. They map compact monitored columns back to biological identities, years and quarters.

They do not add likelihood terms.

---

# 6. Initial activity-centre targets

```r
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

```


### Explanation

This section only creates starting values.

annual_loc is the mean observed capture coordinate within an observed animal-year. quarter_loc is the corresponding mean within a badger-quarter.

is_valid_land_xy tests whether a coordinate falls inside a valid terrestrial grid cell.

snap_to_land moves an invalid starting value to the nearest valid habitat-cell centre.

For unobserved years between first and last capture, approx linearly interpolates an initial annual x-y position between observed years.

These values are not treated as data. They do not appear in the likelihood. Once MCMC starts, A and Q move according to the Bayesian model.

This distinction is essential: interpolation is a computational starting strategy, not inferred biological movement.

---

# 7. The quarterly multi-location likelihood

```r
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

```


This function defines the complete observation likelihood for one animal-quarter.

For quarter centre

$$
Q=(S_x,S_y)
$$

and detector r,

$$
d_r^2=(S_x-X_{r,x})^2+(S_y-X_{r,y})^2.
$$

The spatial weight is

$$
g_r=
\exp\left[-\frac{d_r^2}{2\sigma_i^2}\right].
$$

G_sum is

$$
G=\sum_r g_r.
$$

This is the total spatial accessibility of the detector network to that quarter centre.

The total quarterly encounter hazard is

$$
\lambda_0 G.
$$

Therefore the probability of at least one capture is

$$
P_{\rm cap}=1-\exp(-\lambda_0 G).
$$

This follows from a Poisson encounter process: the probability of zero encounters is exp(-lambda0 G).

## No capture

If ncap = 0, the quarter likelihood is

$$
L_q=1-P_{\rm cap}
=\exp(-\lambda_0G).
$$

## One or more captures

Conditional on a capture, detector r has probability

$$
\pi_r=\frac{g_r}{G}.
$$

If the observed detectors are h1 through hn,

$$
L_q
=
P_{\rm cap}
\prod_{m=1}^{n}
\pi_{h_m}.
$$

Therefore

$$
L_q
=
\left[1-\exp(-\lambda_0G)\right]
\prod_{m=1}^{n}
\frac{g_{h_m}}{G}.
$$

This is exactly what the loop calculates.

### What is conditioned on

The number n of within-quarter captures is conditioned upon once the animal was captured.

There is no term

$$
P(N=n).
$$

So V10B models:

1. capture versus noncapture in the quarterly campaign;
2. the locations of all observed captures, conditional on the observed number.

It does not model why one captured animal was caught once and another three times.

That is intentional because we do not have the historical detector-by-night effort needed for a credible repeated-count model.

This has a direct consequence for posterior predictive checks: we may check binary capture/noncapture and conditional capture locations, but we must not claim that this likelihood predicts the observed frequencies of one-, two-, and three-capture quarters.

If two observed captures are both at sett A, the contribution contains pi_A squared, so repeated same-sett observations strengthen evidence for a nearby Q.

If campaign_active is zero, the function returns 1. A likelihood contribution of one means the quarter supplies no information.

The tiny numerical floors prevent floating-point underflow.

---

# 8. Priors, within-year AR(1), annual movement parameters and detection effects

```r
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

  # Positive quarterly persistence on the logit scale. qeps has stationary
  # marginal variance 1 in each coordinate, so omega keeps the same marginal
  # interpretation as in V10A.
  alpha_rho ~ dnorm(0, sd = 1.5)
  rho <- ilogit(alpha_rho)

  q_ar_precision <- 1 / (1 - rho * rho)
  q_ar_prec[1, 1] <- q_ar_precision
  q_ar_prec[1, 2] <- 0
  q_ar_prec[2, 1] <- 0
  q_ar_prec[2, 2] <- q_ar_precision

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
```


### Detection

The baseline probability parameter is centred around 0.17 on the logit scale.

Sex can shift baseline detection.

The capture-location scale is

$$
\log \sigma_i
=
\alpha_{\log \sigma}
+
\beta_{\sigma,sex}sex_i.
$$

Thus sigma_female and sigma_male are derived directly.

Sigma is not annual movement. It is the scale of observed capture locations around Q.

### Within-year quarter scale

$$
\omega=\exp(\alpha_{\log\omega}).
$$

Quarter deviations have unit marginal coordinate variance before multiplication by omega.

The persistence parameter is

$$
\rho=\operatorname{logit}^{-1}(\alpha_\rho),
$$

so rho is restricted to 0 to 1.

The AR(1) precision is

$$
1/(1-\rho^2).
$$

That means

$$
\epsilon_1\sim N_2(0,I)
$$

and

$$
\epsilon_q\mid\epsilon_{q-1}
\sim
N_2(\rho\epsilon_{q-1},(1-\rho^2)I).
$$

If Var(epsilon_{q-1}) = 1, then

$$
Var(\epsilon_q)
=
\rho^2+(1-\rho^2)=1.
$$

So rho changes persistence without changing the marginal scale omega.

The expected radial distance of Q from A is

$$
\omega\sqrt{\pi/2}.
$$

The expected distance between adjacent quarter centres is

$$
\omega\sqrt{\pi}\sqrt{1-\rho}.
$$

### Annual movement

alpha_logmove determines the local coordinate movement scale.

beta_move_sex changes movement scale for males.

beta_move_high is exponential and therefore positive. Consequently the high-mobility scale is always larger than the local scale.

That positive constraint also identifies the HMM labels and prevents local/high label switching.

The same sex coefficient is used in both local and high states, so the male:female movement-scale ratio is assumed to be the same in both states.

### HMM probabilities

p_disp_init is the probability that the first annual transition is high mobility.

It can depend on adult-entry status and sex.

p_RD is the probability of entering high mobility after a previous local state.

p_DD is the probability of remaining high after a previous high state.

The historical labels can be read as R = resident/local and D = dispersal/high mobility.

### Detection season and period effects

Quarter and five-year effects are constrained to sum to zero.

This lets alpha_p remain an overall baseline rather than depending on an arbitrary reference category.

---

# 9. First annual activity centre and habitat validity

```r
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
```


### Explanation

The first annual centre has independent rectangular uniform x and y reference distributions.

The code converts continuous coordinates to a row and column.

The row/column values are clamped before matrix lookup so proposals just outside the rectangle cannot crash the habitat lookup.

in_bounds_A uses step functions to retain whether the true continuous coordinate is actually inside the rectangle.

habitat_A then reads whether the corresponding cell is terrestrial habitat.

Thus

$$
valid_A
=
I(\text{inside rectangle})
I(\text{habitat}=1).
$$

annual_state_ok is observed as 1 with a Bernoulli probability equal to valid_A.

Therefore invalid positions have likelihood zero.

For the first activity centre, the rectangular uniform density is constant and this behaves like a uniform starting location restricted to allowable habitat.

Later movement states use the same validity device on top of the movement density.

An important modelling approximation is that the movement transition is not explicitly renormalised as a truncated Gaussian over the irregular habitat polygon at each step. Habitat is imposed through the validity pseudo-observation. This should remain documented and can be probed by edge/habitat sensitivity checks.

---

# 10. First-year quarterly centres and quarterly observations

```r
      )

    # -------------------------------------------------------------------------
    # First-year quarterly spatial centres + observations
    #
    # Stationary AR(1) deviations around the annual AC:
    #   qeps_1 ~ N(0, I)
    #   qeps_q | qeps_(q-1) ~ N(rho*qeps_(q-1), (1-rho^2)I)
    # Hence each quarterly deviation marginally has variance omega^2, exactly
    # as in V10A, but adjacent quarters can be temporally persistent.
    # -------------------------------------------------------------------------
    qeps[i, 1:2, 1, first[i]] ~
      dmnorm(
        mean = q_zero[1:2],
        prec = q_prec[1:2, 1:2]
      )

    for (j in 2:J) {
      q_ar_mean[i, 1, j, first[i]] <-
        rho * qeps[i, 1, j - 1, first[i]]

      q_ar_mean[i, 2, j, first[i]] <-
        rho * qeps[i, 2, j - 1, first[i]]

      qeps[i, 1:2, j, first[i]] ~
        dmnorm(
          mean = q_ar_mean[i, 1:2, j, first[i]],
          prec = q_ar_prec[1:2, 1:2]
        )
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
```


The first quarterly standardised deviation has distribution

$$
\epsilon_1\sim N_2(0,I).
$$

For q = 2 to 4,

$$
\epsilon_q\mid\epsilon_{q-1}
\sim
N_2(\rho\epsilon_{q-1},(1-\rho^2)I).
$$

The actual quarter centre is

$$
Q=A+\omega\epsilon.
$$

Each Q is converted to a habitat cell and required to be valid terrestrial space using the same ones-style validity device as A.

The baseline detection linear predictor is

$$
lp0
=
\alpha_p
+
\beta_{p,sex}sex
+
\beta_{season,q}
+
\beta_{period,t}.
$$

The inverse-logit result is converted to a hazard:

$$
\lambda_0=-\log(1-p_0).
$$

This transformation has a convenient interpretation. If there were one effective detector with g = 1,

$$
1-\exp[-(-\log(1-p_0))]=p_0.
$$

So the regression remains interpretable on an ordinary capture-probability scale while the detector network is handled through a cumulative hazard.

quarterProb is then the custom likelihood from Section 7.

The observed pseudo-datum Ones = 1 has

$$
Ones\sim \operatorname{Bernoulli}(quarterProb).
$$

Because the observed value is one, its likelihood contribution is exactly quarterProb. This is the Bernoulli ones trick.

---

# 11. Collapsed annual local/high movement HMM

```r
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

```


This is the key movement section.

There is still a conceptual binary state

$$
Z_t=0\quad\text{local}
$$

or

$$
Z_t=1\quad\text{high mobility}.
$$

But Z is not an MCMC node.

Instead, the likelihood sums over both states exactly.

## Predictive high-state probability

For the first transition,

$$
p_t=p_{\rm disp,init}.
$$

For later transitions,

$$
p_t
=
(1-f_{t-1})p_{RD}
+
f_{t-1}p_{DD},
$$

where f_{t-1} is the previous forward-filtered probability of the high state.

This is just the law of total probability.

## State-specific movement scales

For females in the local state,

$$
\log \sigma_L=\alpha_{\log\mathrm{move}}.
$$

For males, beta_move_sex is added.

The high state additionally adds beta_move_high.

Because beta_move_high is positive, high mobility always has a larger spatial scale.

## Component-specific support

Local and high scales are checked separately against the broad numerical interval 0.5 to 2500 m.

This detail matters after state collapsing. In the old explicit-state model, only the movement scale of the active state mattered for a particular interval. Therefore an invalid unused component should not make the other component impossible.

move_any_support requires at least one valid component.

The evaluation sigmas are clamped only to keep numerical calculations safe. Invalid components receive an effectively zero mixture contribution.

## Annual displacement density

The annual displacement vector is

$$
\Delta A_t=A_t-A_{t-1}.
$$

Its squared radial distance is

$$
d_t^2
=
(\Delta x)^2+(\Delta y)^2.
$$

Under state s,

$$
\Delta A_t\mid Z_t=s
\sim
N_2(0,\sigma_s^2I).
$$

The density is

$$
f_s(\Delta A_t)
=
\frac{1}{2\pi\sigma_s^2}
\exp\left[-\frac{d_t^2}{2\sigma_s^2}\right].
$$

The log density is therefore

$$
-\log(2\pi)
-2\log \sigma_s
-\frac{d_t^2}{2\sigma_s^2}.
$$

Those are the move_logdens expressions.

## Mixture likelihood

The local weighted contribution is

$$
c_L=(1-p_t)f_L.
$$

The high weighted contribution is

$$
c_H=p_tf_H.
$$

The movement likelihood for the interval is

$$
m_t=c_L+c_H.
$$

The code evaluates log(m_t) using the log-sum-exp identity to avoid numerical underflow.

## Zeros trick

NIMBLE still needs A to be stochastic nodes, so A receives a constant rectangular uniform reference density.

The actual movement density m_t is inserted via an observed Poisson zero.

Let

$$
\lambda_t=-\log m_t.
$$

Then

$$
P(Y=0|\lambda_t)
=
\exp(-\lambda_t)
=
m_t.
$$

Therefore

$$
move_zero=0
$$

with a Poisson mean of minus log movement likelihood multiplies the model by exactly the desired movement density, subject only to the tiny numerical floor.

Because the minimum allowed sigma is 0.5 m, the peak bivariate Gaussian density remains below one, so the Poisson mean remains non-negative.

## Forward filtering

After seeing the current displacement,

$$
f_t
=
P(Z_t=1|\Delta A_{1:t},\theta)
=
\frac{p_tf_H}{(1-p_t)f_L+p_tf_H}.
$$

The code calculates this from the high log component minus the log mixture.

This filtered probability is used to predict the next state.

It is not the final scientific movement-state probability. After MCMC, the state-recovery script runs the backward recursion so that the final smoothed probability uses both past and future information.

---

# 12. Subsequent-year quarterly centres and compact monitored positions

```r
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
      qeps[i, 1:2, 1, k] ~
        dmnorm(
          mean = q_zero[1:2],
          prec = q_prec[1:2, 1:2]
        )

      for (j in 2:J) {
        q_ar_mean[i, 1, j, k] <-
          rho * qeps[i, 1, j - 1, k]

        q_ar_mean[i, 2, j, k] <-
          rho * qeps[i, 2, j - 1, k]

        qeps[i, 1:2, j, k] ~
          dmnorm(
            mean = q_ar_mean[i, 1:2, j, k],
            prec = q_ar_prec[1:2, 1:2]
          )
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
```


The remaining annual years repeat the same structure:

1. annual activity centre constrained to habitat;
2. stationary AR(1) quarterly deviations;
3. Q = A + omega times deviation;
4. habitat-valid quarter centres;
5. quarter-specific detection predictor;
6. custom capture/noncapture plus location likelihood.

The final two loops copy all biologically active A and Q coordinates into compact vectors.

This is only monitoring/bookkeeping. It avoids saving huge ragged arrays while preserving every annual and quarterly latent location needed downstream.

---

# 13. Overall likelihood factorisation

Ignoring fixed constants and bookkeeping nodes, the posterior can be written schematically as

$$
p(\theta,\mathbf A,\mathbf Q|\mathbf y)
\propto
p(\theta)
L_{\rm movement}
L_{\rm quarter process}
L_{\rm observation}
L_{\rm habitat/support}.
$$

For each animal, annual movement contributes

$$
\prod_{t=first_i+1}^{K_i}
\left[
(1-p_{i,t})f_L(\Delta A_{i,t})
+
p_{i,t}f_H(\Delta A_{i,t})
\right].
$$

The quarter AR(1) contributes its Gaussian densities for the standardised deviations.

For every active quarter with no capture,

$$
L_q=e^{-\lambda_0G}.
$$

For every captured quarter,

$$
L_q
=
\left(1-e^{-\lambda_0G}\right)
\prod_m
\frac{g_{h_m}}{G}.
$$

Annual and quarterly habitat-validity terms force latent centres onto valid terrestrial cells.

That is the core V10B posterior.

---

# 14. Constants and pseudo-data supplied to NIMBLE

```r

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
```


Constants are fixed values and indexes.

Observed pseudo-data perform four specific jobs:

- Ones = 1 inserts the custom quarter likelihood;
- move_zero = 0 inserts the collapsed annual movement density;
- annual_state_ok = 1 restricts A to valid habitat;
- quarter_state_ok = 1 restricts Q to valid habitat;
- move_support_ok = 1 requires at least one numerically valid annual movement component.

These devices are not extra biological observations. They are ways of expressing custom likelihood constraints inside NIMBLE.

---

# 15. Over-dispersed initial values

```r

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
  alpha_logomega0 <- log(omega_start)
  alpha_rho0 <- qlogis(rho_start)

  A0 <- array(NA_real_, c(nind, 2L, n_prim))
  qeps0 <- array(NA_real_, c(nind, 2L, J, n_prim))

  omega0 <- exp(alpha_logomega0)

  for (i in seq_len(nind)) {

    for (k in first[i]:K[i]) {

      A0[i, 1, k] <- target_A[i, 1, k]
      A0[i, 2, k] <- target_A[i, 2, k]

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

    }
  }

  list(
    alpha_p = qlogis(c(0.12, 0.17, 0.24)[chain]),
    beta_p_sex = c(-0.10, 0, 0.10)[chain],
    alpha_logsigma = log(c(125, 150, 190)[chain]),
    beta_sigma_sex = c(-0.10, 0, 0.10)[chain],

    alpha_logomega = alpha_logomega0,
    alpha_rho = alpha_rho0,

    alpha_logmove = alpha_logmove0,
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
    qeps = qeps0
  )
}

inits <- make_inits(CHAIN_ID)
```


Initial values do not define the posterior.

The three chains deliberately start from different plausible stories:

- local movement SD 8, 20, 40 m;
- high movement SD 500, 800, 1200 m;
- omega 5, 25, 100 m;
- rho 0.15, 0.50, 0.80.

Detection and Markov-state parameters are also dispersed.

This makes the convergence test stronger. If chains with very different starting values arrive at the same posterior, we have better evidence that the result is not simply a starting-value artefact.

The initial annual positions come from the Section 6 targets.

The starting standardised quarter deviations are calculated by rearranging

$$
Q=A+\omega\epsilon
$$

to give

$$
\epsilon=(Q-A)/\omega.
$$

---

# 16. Algebraic self-check of the HMM collapse

```r

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
```


The first function computes the movement likelihood by forward recursion.

The second enumerates every possible binary state path for a short four-transition synthetic example.

With four transitions there are only 16 possible paths.

The script requires the forward log-likelihood and brute-force summed log-likelihood to agree within 1e-10.

This is a strong code-level check that the HMM marginalisation algebra is implemented correctly.

It does not test biological adequacy. That is why posterior predictive checks are still needed.

---

# 17. Building, validating and compiling the NIMBLE model

```r

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
```


nimbleModel combines model code, constants, observed data and starting values.

The model is then explicitly calculated at the initial state.

If the total log probability is not finite, the code interrogates every stochastic node and prints the problematic nodes before stopping.

This is an important production safeguard against impossible initial positions, invalid supports or numerical errors.

The valid model is then compiled to C++ for speed.

---

# 18. Monitors and MCMC sampler configuration

```r

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
    "beta_sigma_sex",
    "alpha_logomega"
  )
)

for (b in global_blocks) {
  config$removeSamplers(b, print = FALSE)
  config$addSampler(
    target = b,
    type = "AF_slice"
  )
}

# AF_slice is a multivariate sampler and requires at least two target nodes.
# rho is a scalar parameter, so use NIMBLE's scalar slice sampler instead.
config$removeSamplers("alpha_rho", print = FALSE)
config$addSampler(
  target = "alpha_rho",
  type = "slice"
)

# Earlier centred AC experiments mixed better when each annual position was
# updated jointly in x/y rather than by two independent scalar RW samplers.
# This changes only the MCMC parameterisation/sampler, not the posterior model.
for (aa in seq_len(nrow(annual_state_map))) {
  i_aa <- annual_state_map$model_i[aa]
  k_aa <- annual_state_map$state_k[aa]

  A_block <- c(
    paste0("A[", i_aa, ", 1, ", k_aa, "]"),
    paste0("A[", i_aa, ", 2, ", k_aa, "]")
  )

  config$removeSamplers(A_block, print = FALSE)
  config$addSampler(
    target = A_block,
    type = "AF_slice"
  )
}

cat(
  "\nFinal sampler configuration:\n",
  "  Global AF_slice blocks: ", length(global_blocks), "\n",
  "  Joint annual-AC (x/y) AF_slice blocks: ", nrow(annual_state_map), "\n",
  "  Quarterly qeps blocks retain NIMBLE RW_block samplers.\n",
  "  alpha_rho uses NIMBLE's scalar slice sampler.\n",
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
```


The monitored global parameters include detection, spatial scales, AR(1) persistence, movement scales and HMM transition parameters.

The script also saves every active annual A and quarterly Q location.

Binary movement states are absent because they have been analytically collapsed.

Strongly correlated global parameters are sampled in multivariate AF_slice blocks.

For example, alpha_logmove, beta_move_sex and beta_move_high form one block because the 300-badger diagnostic showed a strong posterior ridge among these quantities.

alpha_rho is scalar, so it uses NIMBLE's scalar slice sampler.

Each annual x-y activity centre is sampled jointly as a two-dimensional block. Earlier testing showed that moving x and y jointly mixed better than updating them independently.

The qeps quarter-deviation nodes retain NIMBLE's bivariate random-walk block samplers.

These choices alter sampling efficiency, not the statistical posterior.

---

# 19. Running MCMC, checkpointing, summaries and output

```r

# ---- run ---------------------------------------------------------------------
cat("\nRunning MCMC...\n")

checkpoint_file <- file.path(
  "results",
  paste0(
    "V10B_RD_MULTILOC_AR1_COLLAPSED_",
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
    "V10B_RD_MULTILOC_AR1_COLLAPSED_",
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
        "joint x/y AF_slice per active badger-year",
      quarter_deviation_sampler =
        "bivariate RW_block on qeps",
      rho_sampler =
        "separate NIMBLE scalar slice sampler on alpha_rho",
      chain_initialisation =
        "deliberately over-dispersed plausible starts across chains 1--3",
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
```


runMCMC applies the requested iteration count, burn-in and thinning with a chain-specific seed.

Immediately after MCMC finishes, the raw samples are saved to a checkpoint before any post-processing.

That is deliberate: a long production chain should not be lost because a later summary command fails.

The code then:

- identifies annual A columns;
- identifies quarter Q columns;
- checks they match the index tables;
- separates latent columns from global columns;
- detects non-finite global draws;
- calculates basic summaries;
- prints key parameters;
- prints the retained within-quarter capture-count distribution;
- saves the final chain RDS.

The one-chain summary is not the final convergence assessment. Rhat, ESS and between-chain state agreement are calculated only after all three chains are combined.

The saved RDS contains the posterior plus enough metadata to recover movement states and feed later disease/survival analyses without refitting V10B.

---

# 20. What the model estimates and does not estimate

## Estimated here

- annual activity centre A;
- quarterly centre Q;
- capture-location scale sigma;
- within-year scale omega;
- quarterly persistence rho;
- local annual movement scale;
- high annual movement scale;
- sex effect on movement scale;
- probability of entering high mobility;
- probability of remaining high;
- quarterly capture probability effects;
- posterior high-mobility states after separate smoothing.

## Not estimated here

- survival;
- mortality versus permanent emigration;
- disease state;
- cull effects;
- dynamic social-group boundaries;
- static social-group resistance;
- exact detector-night effort;
- the number of repeated captures within a quarter.

---

# 21. Assumptions and approximations that should stay visible

1. Quarter is treated as the finest reliable trapping occasion.

2. In an active quarter, the full detector network is used because detector-by-night effort is unavailable.

3. Repeated capture count is conditioned on, not modelled.

4. Movement is conditioned between first and last observed live year.

5. Rho is restricted to positive persistence.

6. The same sex scale ratio applies to local and high movement states.

7. Habitat is imposed through validity pseudo-data rather than an analytically normalised truncated movement kernel.

8. Static social-group boundaries are deliberately excluded pending annual bait-marking maps.

9. The model interprets complete study-wide empty quarters conservatively as unavailable rather than definite zero-capture campaigns.

---

# 22. Posterior predictive checks: these should be part of final validation

Convergence and posterior predictive fit answer different questions.

Convergence asks:

> Did independent MCMC chains explore the same posterior?

Posterior predictive checking asks:

> Can the fitted model generate observations that resemble the actual observations?

A model can converge perfectly and still fit the data poorly.

The PPCs should therefore be performed after the full three-chain run and before V10B is finally frozen.

## PPC 1: quarterly capture versus noncapture

For every active badger-quarter define

$$
C^{obs}=I(ncap>0).
$$

For each selected posterior draw, reconstruct Pcap and simulate

$$
C^{rep}\sim \operatorname{Bernoulli}(Pcap).
$$

Compare observed and replicated:

- overall capture fraction;
- capture fraction by quarter;
- capture fraction by sex;
- capture fraction by five-year period;
- capture frequency per badger;
- lengths of noncapture runs inside observed histories.

This checks the first part of the observation likelihood.

## PPC 2: conditional detector locations

For every observed captured quarter, calculate

$$
\pi_r=g_r/G.
$$

Condition on the observed ncap and simulate the same number of detector locations from the categorical distribution pi.

Compare:

- capture distance from Q;
- number of unique setts within a quarter;
- pairwise distance among multiple same-quarter captures;
- repeated capture at the same sett;
- maximum within-quarter detector spread.

This is especially important because retaining multiple within-quarter locations was one of the main reasons for V10.

## A PPC we must not do

The current model cannot predict how often badgers are caught once, twice or three times within a quarter, because that count was conditioned upon.

A replicated ncap distribution would therefore be pretending that the model contains a likelihood component that it does not contain.

If we ever obtain sufficient detector-night effort, a true count/encounter model could be added and then that PPC would become legitimate.

## PPC 3: calibration through historical time

Repeat capture and location discrepancies by:

- quarter;
- five-year period;
- early/middle/late study;
- sex.

This is particularly important because historical effort is approximated.

If early decades and late decades show systematic opposite residuals, the period effects may not be sufficient to absorb effort changes.

## PPC 4: annual movement kernel

From posterior HMM parameters, generate replicated local/high state paths and bivariate annual displacements.

Compare:

- median displacement;
- 75th, 90th, 95th and 99th percentiles;
- numbers above 100, 250, 500 and 1000 m;
- maximum displacement;
- distributions by sex;
- high-state run lengths;
- number of high-mobility episodes per badger.

Because A is latent, this is partly a latent-process check rather than a pure observation-level PPC.

The first version can check the unconstrained movement kernel. A more complete version can use habitat-aware rejection simulation if the spatial-edge diagnostics suggest that habitat truncation matters.

## PPC 5: within-year AR(1)

Simulate quarter deviations from posterior omega and rho.

Compare with posterior-derived Q minus A:

- quarter-to-annual radial offsets;
- adjacent-quarter centre distances;
- lag-1 correlation of x and y deviations;
- extreme within-year shifts.

This asks whether one stationary positive AR(1) is sufficient.

## PPC 6: state-space and boundary behaviour

Summarise posterior A and Q positions:

- within 250 m of the outer boundary;
- within 500 m;
- near excluded water/habitat edges.

Heavy accumulation at artificial edges would suggest state-space truncation.

This complements the separate V3 state-space audit.

## PPC 7: difficult individual histories

Inspect posterior predictive behaviour for the animals that drive the most uncertain movement classifications, especially those with:

- missing intermediate years;
- multiple setts within quarters;
- large displacements;
- remaining between-chain disagreement.

A good global fit can otherwise hide local failures in the very animals driving the biological conclusions.

---

# 23. Proposed post-fit validation sequence

Once all 1932 chains finish:

1. combine chains;
2. inspect Rhat and ESS;
3. recover smoothed high-mobility probabilities;
4. assess chain agreement in those probabilities;
5. run capture/noncapture PPCs;
6. run conditional detector-location PPCs;
7. stratify those PPCs through time and by quarter/sex;
8. run annual movement-kernel checks;
9. run AR(1) within-year checks;
10. inspect boundary/habitat behaviour;
11. document any systematic lack of fit;
12. freeze V10B if no material failure is found.

Posterior predictive probabilities can be reported for selected discrepancy statistics:

$$
p_B
=
P[T(y^{rep},\theta)\ge T(y^{obs},\theta)|y].
$$

Values near zero or one flag mismatch, but graphical observed-versus-replicated distributions are usually easier to interpret than treating p_B as a classical p-value.

---

# 24. When should movement be reopened?

Not merely because one parameter has a slightly imperfect ESS or a few individual histories remain uncertain.

Movement should be reopened only if:

- the full collapsed production chains genuinely fail to converge;
- observation-level PPCs reveal a systematic failure;
- the state-space audit shows meaningful edge truncation;
- annual bait-marking maps materially change interpretation of uncertain trajectories;
- or future effort reconstruction allows a clearly better observation model.

Otherwise, movement should be treated as a solved component and the project should move on to disease, survival and persistence.

---

# 25. One-page mathematical summary

For individual i, year t and quarter q:

## Annual movement

$$
\Delta A_{i,t}=A_{i,t}-A_{i,t-1}.
$$

Conditional on the hidden movement state:

$$
\Delta A_{i,t}\mid Z_{i,t}=L
\sim N_2(0,\sigma_{L,i}^2I),
$$

$$
\Delta A_{i,t}\mid Z_{i,t}=H
\sim N_2(0,\sigma_{H,i}^2I).
$$

Z follows a two-state Markov process and is integrated out analytically.

## Within-year spatial use

$$
Q_{i,t,q}=A_{i,t}+\omega\epsilon_{i,t,q}.
$$

$$
\epsilon_1\sim N_2(0,I).
$$

$$
\epsilon_q\mid\epsilon_{q-1}
\sim
N_2(\rho\epsilon_{q-1},(1-\rho^2)I).
$$

## Capture-location kernel

$$
g_r
=
\exp\left[
-\frac{\lVert Q-X_r\rVert^2}{2\sigma_i^2}
\right].
$$

## Quarterly capture probability

$$
P_{\rm cap}
=
1-\exp\left(-\lambda_0\sum_r g_r\right).
$$

## Conditional detector probability

$$
P(H=r|captured)
=
g_r/\sum_s g_s.
$$

## Quarter likelihood

If uncaptured:

$$
L_q=1-P_{\rm cap}.
$$

If captured n times at detectors h1 through hn:

$$
L_q
=
P_{\rm cap}
\prod_{m=1}^{n}
\frac{g_{h_m}}{\sum_r g_r}.
$$

The final scientific outputs are annual spatial position and

$$
P(\text{high mobility}_{i,t}|\text{all movement data}).
$$

These then feed the disease, survival and persistence programme.

---

# 26. Validation checklist

- [x] Supabase/data-preparation audit;
- [x] biological identifier audit;
- [x] movement-population inclusion audit;
- [x] all within-quarter capture locations retained;
- [x] representative-location bias investigated;
- [x] multi-capture quarter structure audited;
- [x] V10A versus V10B architecture comparison;
- [x] stationary AR(1) V10B selected;
- [x] explicit binary-state path trapping diagnosed;
- [x] movement HMM analytically collapsed;
- [x] forward likelihood checked against brute-force enumeration;
- [x] backward state-recovery algebra checked independently;
- [x] artificial 5 m lower movement floor diagnosed;
- [x] lower numerical floor relaxed to 0.5 m;
- [x] collapsed component-support semantics matched to explicit-state logic;
- [x] production chains given deliberately over-dispersed starts;
- [ ] full 1932 three-chain run complete;
- [ ] smoothed/FFBS state recovery complete;
- [ ] final Rhat/ESS/state-agreement assessment complete;
- [ ] V3 spatial state-space audit complete;
- [ ] posterior predictive checks implemented;
- [ ] final movement results documented and architecture frozen;
- [ ] existing disease-movement analyses refreshed;
- [ ] survival/open-population model developed.

---

# 27. Final interpretation

The model is complex in code because it has to manage nearly fifty years of irregular spatial capture histories efficiently. The underlying statistical story is much simpler:

1. an animal has an annual spatial centre;
2. its quarterly spatial use varies around that centre;
3. captures occur near those quarter centres with imperfect detection;
4. annual centres move according to a persistent mixture of local and high-mobility processes;
5. uncertainty about local versus high state is integrated rather than hard-classified;
6. the posterior gives us spatial trajectories and movement-state probabilities with uncertainty.

Posterior predictive checking is the final missing validation layer after convergence.

If those checks show that V10B reproduces the important capture/noncapture and spatial-location patterns, geographical movement should be frozen and used as an input to the next scientific questions: disease transmission, survival, immigration/replacement, culling effects and long-term disease persistence.
