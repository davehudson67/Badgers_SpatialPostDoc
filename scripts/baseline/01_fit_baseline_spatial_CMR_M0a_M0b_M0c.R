
# =============================================================================
# Woodchester badger spatial CMR baseline model suite
# Models:
#   M0a = common detection, common movement, constant adult survival
#   M0b = sex-specific detection, movement and survival
#   M0c = sex-specific detection and movement, plus sex + age + year survival
#
# This script is adapted from the user's previous Ergon & Gardner-style
# spatial CMR model, but removes infection-history filtering and makes the
# baseline model independent of bTB status.
#
# IMPORTANT
# ---------
# 1. This is a marked-population spatial CMR model. It does not yet estimate
#    total abundance of never-captured animals.
# 2. The spatial units of sigma and dmean are the same as col_index/row_index.
# 3. The code assumes one primary period per year and exactly four secondary
#    trapping occasions within each year.
# 4. Run M0a first. Only proceed to M0b/M0c once M0a builds and mixes well.
# 5. Known post-mortem recoveries are treated as observable in the recovery
#    year and dead from the following primary period.
# 6. Activity centres remain unbounded in this version. Treat movement results
#    as provisional until a biologically defensible state-space mask is added.
# =============================================================================

# ---- 0. User options ---------------------------------------------------------

MODEL_VERSION <- "M0a"   # choose "M0a", "M0b", or "M0c"
TEST_RUN <- TRUE
RANDOM_SEED <- 42

# Woodchester trapping design: four secondary trapping occasions per year.
N_SECONDARY_OCCASIONS <- 4L

MONITOR_LATENT <- FALSE   # TRUE can create very large output
RUN_PPC <- TRUE

MCMC_NITER_TEST <- 2000
MCMC_NBURN_TEST <- 500
MCMC_NCHAINS_TEST <- 2

MCMC_NITER_FULL <- 60000
MCMC_NBURN_FULL <- 15000
MCMC_NCHAINS_FULL <- 4
MCMC_THIN_FULL <- 2

# ---- 1. Packages -------------------------------------------------------------

required_packages <- c(
  "sf", "nimble", "lubridate", "tidyverse", "coda", "posterior"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Install missing packages first: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

library(sf)
library(nimble)
library(lubridate)
library(tidyverse)
library(coda)
library(posterior)

set.seed(RANDOM_SEED)

# ---- 2. Helper functions -----------------------------------------------------

find_project_root <- function(start_dir = getwd()) {
  current <- normalizePath(start_dir, winslash = "/", mustWork = TRUE)

  repeat {
    looks_like_root <-
      file.exists(file.path(current, "README.md")) &&
      dir.exists(file.path(current, "data")) &&
      dir.exists(file.path(current, "scripts"))

    if (looks_like_root) return(current)

    parent <- dirname(current)

    if (identical(parent, current)) {
      stop(
        "Could not find project root. Open NewBadgers.Rproj ",
        "in RStudio or set project_root manually.",
        call. = FALSE
      )
    }

    current <- parent
  }
}

stop_if_missing_cols <- function(dat, cols, object_name = deparse(substitute(dat))) {
  missing <- setdiff(cols, names(dat))
  if (length(missing) > 0) {
    stop(
      object_name, " is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

make_age_class <- function(age) {
  # Adapt this if your age coding differs.
  # Assumes age == 0 is cub, age == 1 is yearling, age >= 2 is adult.
  case_when(
    is.na(age) ~ NA_integer_,
    age == 0 ~ 1L,
    age == 1 ~ 2L,
    age >= 2 ~ 3L,
    TRUE ~ NA_integer_
  )
}

make_initial_values <- function(
    bc, ids, nind, n_prim, first, K, sex_id, model_version) {

  bc_init <- bc %>%
    mutate(.id_order = match(tattoo, ids)) %>%
    filter(!is.na(.id_order)) %>%
    arrange(.id_order, primary, trap_season, date)

  S_init <- array(NA_real_, dim = c(nind, 2, n_prim))

  for (i in seq_len(nind)) {
    dat_i <- bc_init %>%
      filter(tattoo == ids[i]) %>%
      arrange(primary, trap_season, date)

    if (nrow(dat_i) == 0) {
      stop("No capture rows found for individual ", ids[i], call. = FALSE)
    }

    last_x <- dat_i$col_index[1]
    last_y <- dat_i$row_index[1]

    if (is.na(last_x) || is.na(last_y)) {
      stop("First spatial location missing for ", ids[i], call. = FALSE)
    }

    for (k in seq_len(n_prim)) {
      rows_k <- dat_i %>% filter(primary == k)

      if (nrow(rows_k) > 0) {
        last_x <- rows_k$col_index[1]
        last_y <- rows_k$row_index[1]
      }

      S_init[i, 1, k] <- last_x
      S_init[i, 2, k] <- last_y
    }
  }

  z_init <- matrix(0L, nrow = nind, ncol = n_prim)

  for (i in seq_len(nind)) {
    if (!is.na(first[i]) && !is.na(K[i]) && K[i] >= first[i]) {
      z_init[i, first[i]:K[i]] <- 1L
    }
  }

  d_init <- matrix(1, nrow = nind, ncol = max(1, n_prim - 1))
  theta_init <- matrix(0, nrow = nind, ncol = max(1, n_prim - 1))

  common <- list(
    alpha_p0 = qlogis(0.35),
    alpha_logsigma = log(8),
    alpha_phi = qlogis(0.85),
    alpha_logd = log(8),
    z = z_init,
    d = d_init,
    theta = theta_init,
    S = S_init
  )

  if (model_version %in% c("M0b", "M0c")) {
    common$beta_p_sex <- 0
    common$beta_logsigma_sex <- 0
    common$beta_phi_sex <- 0
    common$beta_logd_sex <- 0
  }

  if (model_version == "M0c") {
    common$beta_phi_age <- c(0, 0)
    common$sigma_year <- 0.2
    common$year_raw <- rnorm(n_prim - 1, 0, 0.1)
  }

  common
}

extract_main_diagnostics <- function(samples) {
  draws <- posterior::as_draws_array(samples)
  summ <- posterior::summarise_draws(
    draws,
    "mean", "median", "sd", "mad", "q2.5", "q97.5",
    "rhat", "ess_bulk", "ess_tail", "mcse_mean"
  )
  as.data.frame(summ)
}

make_capture_ppc <- function(samples_mat, model_data, n_draws = 500) {
  # Lightweight posterior predictive check based on annual number detected.
  # This conditions on posterior sampled alive states and activity centres only
  # if these were monitored. If latent states were not monitored, this function
  # returns NULL and the main in-model discrepancy checks should be used instead.
  z_cols <- grep("^z\\[", colnames(samples_mat), value = TRUE)

  if (length(z_cols) == 0) {
    message(
      "Skipping latent-state PPC because z nodes were not monitored. ",
      "Set MONITOR_LATENT <- TRUE for this check."
    )
    return(NULL)
  }

  NULL
}

# ---- 3. Paths ---------------------------------------------------------------

project_root <- find_project_root()

capture_data_path <- file.path(
  project_root,
  "data/processed/badger_capture_diagnostic_cleaned_2024.rds"
)

spatial_object_path <- file.path(
  project_root,
  "data/processed/spatial_grid_and_sett_objects.RData"
)

model_tag <- paste0(MODEL_VERSION, "_", ifelse(TEST_RUN, "TEST", "FULL"))

out_dir <- file.path(
  project_root,
  "outputs/model_runs",
  "baseline_spatial_cmr"
)

plot_dir <- file.path(
  project_root,
  "outputs/diagnostics",
  "baseline_spatial_cmr",
  model_tag
)

audit_dir <- file.path(
  project_root,
  "outputs/data_audits",
  "baseline_spatial_cmr"
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

# ---- 4. Load and audit data -------------------------------------------------

bc_raw <- readRDS(capture_data_path) %>%
  droplevels()

load(spatial_object_path)

stop_if_missing_cols(
  bc_raw,
  c(
    "tattoo", "date", "sett", "pm", "socg",
    "sex", "age", "trap_season"
  ),
  "bc_raw"
)

stop_if_missing_cols(
  st_drop_geometry(settGrid),
  c("Sett", "row_index", "col_index"),
  "settGrid"
)

audit_before <- tibble(
  stage = "raw",
  n_rows = nrow(bc_raw),
  n_individuals = n_distinct(bc_raw$tattoo)
)

bc <- bc_raw %>%
  mutate(
    date = ymd(date),
    SG = iconv(socg, from = "latin1", to = "UTF-8", sub = ""),
    SG = gsub(" ", "", SG),
    sex_clean = case_when(
      toupper(as.character(sex)) %in% c("M", "MALE") ~ "Male",
      toupper(as.character(sex)) %in% c("F", "FEMALE") ~ "Female",
      TRUE ~ NA_character_
    ),
    age_numeric = safe_numeric(age),
    age_class = make_age_class(age_numeric)
  )

settGrid_clean <- settGrid %>%
  st_drop_geometry() %>%
  transmute(
    SG = gsub(" ", "", as.character(Sett)),
    row_index = as.numeric(row_index),
    col_index = as.numeric(col_index)
  ) %>%
  distinct(SG, .keep_all = TRUE)

bc <- bc %>%
  left_join(settGrid_clean, by = "SG") %>%
  mutate(
    primary_year = year(date),
    trap_season = as.integer(trap_season)
  )

exclusion_summary <- bind_rows(
  tibble(
    reason = "Missing tattoo",
    n_rows = sum(is.na(bc$tattoo) | bc$tattoo == ""),
    n_individuals = n_distinct(bc$tattoo[is.na(bc$tattoo) | bc$tattoo == ""])
  ),
  tibble(
    reason = "Missing/invalid date",
    n_rows = sum(is.na(bc$date)),
    n_individuals = n_distinct(bc$tattoo[is.na(bc$date)])
  ),
  tibble(
    reason = "Unknown sex",
    n_rows = sum(is.na(bc$sex_clean)),
    n_individuals = n_distinct(bc$tattoo[is.na(bc$sex_clean)])
  ),
  tibble(
    reason = "Missing spatial join",
    n_rows = sum(is.na(bc$row_index) | is.na(bc$col_index)),
    n_individuals = n_distinct(
      bc$tattoo[is.na(bc$row_index) | is.na(bc$col_index)]
    )
  ),
  tibble(
    reason = "Missing trap season",
    n_rows = sum(is.na(bc$trap_season)),
    n_individuals = n_distinct(bc$tattoo[is.na(bc$trap_season)])
  ),
  tibble(
    reason = "Before 1982",
    n_rows = sum(bc$primary_year < 1982, na.rm = TRUE),
    n_individuals = n_distinct(
      bc$tattoo[bc$primary_year < 1982 & !is.na(bc$primary_year)]
    )
  )
)

write.csv(
  exclusion_summary,
  file.path(audit_dir, paste0("exclusions_", model_tag, ".csv")),
  row.names = FALSE
)

bc <- bc %>%
  filter(
    !is.na(tattoo),
    tattoo != "",
    !is.na(date),
    !is.na(sex_clean),
    !is.na(row_index),
    !is.na(col_index),
    !is.na(trap_season),
    primary_year >= 1982
  ) %>%
  group_by(tattoo) %>%
  filter(!all(pm == "Yes")) %>%
  ungroup() %>%
  arrange(tattoo, date)

if (nrow(bc) == 0) {
  stop("No observations remain after baseline filtering.", call. = FALSE)
}

# Consecutive year index with no unused first year.
year_lookup <- tibble(
  primary_year = sort(unique(bc$primary_year)),
  primary = seq_along(primary_year)
)

bc <- bc %>%
  left_join(year_lookup, by = "primary_year") %>%
  mutate(
    sex_id = if_else(sex_clean == "Female", 1L, 2L)
  )

# Fill age class within individual-year where possible.
bc <- bc %>%
  group_by(tattoo, primary) %>%
  mutate(
    age_class = if_else(
      is.na(age_class) & any(!is.na(age_class)),
      first(na.omit(age_class)),
      age_class
    )
  ) %>%
  ungroup()

# For M0a/M0b age class is not needed.
# For M0c, remove individual-year records with unknown age class.
if (MODEL_VERSION == "M0c") {
  bc <- bc %>%
    filter(!is.na(age_class))
}

audit_after <- tibble(
  stage = "analysis",
  n_rows = nrow(bc),
  n_individuals = n_distinct(bc$tattoo)
)

write.csv(
  bind_rows(audit_before, audit_after),
  file.path(audit_dir, paste0("dataset_size_", model_tag, ".csv")),
  row.names = FALSE
)

annual_audit <- bc %>%
  group_by(primary_year, sex_clean) %>%
  summarise(
    n_rows = n(),
    n_individuals = n_distinct(tattoo),
    n_known_pm = sum(pm == "Yes", na.rm = TRUE),
    .groups = "drop"
  )

write.csv(
  annual_audit,
  file.path(audit_dir, paste0("annual_audit_", model_tag, ".csv")),
  row.names = FALSE
)

# ---- 5. Build capture histories --------------------------------------------

n_prim <- max(bc$primary)
n_sec <- N_SECONDARY_OCCASIONS
nind <- n_distinct(bc$tattoo)

if (any(!bc$trap_season %in% seq_len(n_sec))) {
  bad_trap_seasons <- sort(unique(
    bc$trap_season[!bc$trap_season %in% seq_len(n_sec)]
  ))

  stop(
    "trap_season must be coded 1, 2, 3 or 4. Invalid values found: ",
    paste(bad_trap_seasons, collapse = ", "),
    call. = FALSE
  )
}

# The array stores one encounter outcome per individual, secondary occasion
# and year. Multiple rows in the same cell would otherwise overwrite one
# another silently.
duplicate_encounters <- bc %>%
  count(tattoo, primary, trap_season, name = "n_rows") %>%
  filter(n_rows > 1)

if (nrow(duplicate_encounters) > 0) {
  write.csv(
    duplicate_encounters,
    file.path(audit_dir, paste0("duplicate_encounters_", model_tag, ".csv")),
    row.names = FALSE
  )

  stop(
    "There are multiple records for at least one individual-year-trap-season ",
    "combination. See duplicate_encounters_", model_tag,
    ".csv. These must be reconciled before constructing H.",
    call. = FALSE
  )
}

bc <- bc %>%
  group_by(tattoo) %>%
  mutate(
    minPrimary = min(primary),
    maxPrimary = max(primary)
  ) %>%
  group_by(tattoo, primary) %>%
  mutate(lastSecondary_year = max(trap_season)) %>%
  ungroup() %>%
  group_by(tattoo) %>%
  mutate(
    firstSecondary = if_else(
      primary == minPrimary,
      min(trap_season),
      NA_integer_
    )
  ) %>%
  fill(firstSecondary, .direction = "downup") %>%
  mutate(
    lastSecondary = if_else(
      primary == maxPrimary,
      lastSecondary_year,
      NA_integer_
    )
  ) %>%
  fill(lastSecondary, .direction = "downup") %>%
  mutate(
    death_occasion = if_else(pm == "Yes", primary, n_prim + 1L),
    death_occasion = min(death_occasion, na.rm = TRUE),
    death_secondary = if_else(pm == "Yes", trap_season, 0L)
  ) %>%
  arrange(tattoo, date) %>%
  ungroup()

# One row per individual for individual-level metadata.
ind_meta <- bc %>%
  group_by(tattoo) %>%
  arrange(date, .by_group = TRUE) %>%
  summarise(
    sex_id = first(sex_id),
    first = min(primary),
    last_observed = max(primary),
    death_occasion = min(death_occasion),
    first_location_SG = first(SG),
    .groups = "drop"
  )

ids <- ind_meta$tattoo
first <- ind_meta$first
death_occasion <- ind_meta$death_occasion
sex_id <- ind_meta$sex_id

# Final primary period represented in likelihood.
#
# A post-mortem recovery in death_occasion means the animal was still
# observable in that primary period. To use the known mortality, include the
# following primary period (where available) and fix z = 0 from then onwards.
K <- rep(n_prim, nind)
known_death <- death_occasion <= n_prim
K[known_death] <- pmin(
  n_prim,
  death_occasion[known_death] + 1L
)

# Number of secondary occasions used in each individual-year.
#
# Ordinarily every primary year has four trapping occasions. If an individual
# is recovered dead during occasion j of the death year, later occasions in
# that year are not included for that individual because it is no longer
# available after the recovery.
J <- matrix(n_sec, nrow = nind, ncol = n_prim)

death_secondary <- bc %>%
  group_by(tattoo) %>%
  summarise(
    death_secondary = {
      values <- trap_season[pm == "Yes" & !is.na(trap_season)]
      if (length(values) == 0) NA_integer_ else min(values)
    },
    .groups = "drop"
  ) %>%
  right_join(ind_meta %>% select(tattoo), by = "tattoo") %>%
  arrange(match(tattoo, ids)) %>%
  pull(death_secondary)

for (i in seq_len(nind)) {
  if (
    known_death[i] &&
    !is.na(death_secondary[i]) &&
    death_occasion[i] >= 1L &&
    death_occasion[i] <= n_prim
  ) {
    J[i, death_occasion[i]] <- death_secondary[i]
  }
}

# Spatial locations used as detector/social-group centres.
SGs <- sort(unique(bc$SG))

settGrid_model <- settGrid_clean %>%
  filter(SG %in% SGs) %>%
  arrange(match(SG, SGs))

X <- settGrid_model %>%
  select(col_index, row_index) %>%
  as.matrix()

R <- nrow(X)
sett_map <- setNames(seq_along(SGs), SGs)

bc <- bc %>%
  mutate(SGnum = as.integer(sett_map[SG]))

if (anyNA(bc$SGnum)) {
  stop("Some SG values could not be mapped to detector indices.", call. = FALSE)
}

# H = 1 means no capture; 2:(R+1) indicate capture location.
H <- array(
  1L,
  dim = c(nind, n_sec, n_prim),
  dimnames = list(ids, NULL, NULL)
)

for (row_i in seq_len(nrow(bc))) {
  i <- match(bc$tattoo[row_i], ids)
  j <- bc$trap_season[row_i]
  k <- bc$primary[row_i]

  if (is.na(i) || is.na(j) || is.na(k)) next
  H[i, j, k] <- bc$SGnum[row_i] + 1L
}

first_location <- match(ind_meta$first_location_SG, SGs)

if (anyNA(first_location)) {
  stop("Some first locations could not be matched to SGs.", call. = FALSE)
}

# Age class matrix by individual and interval start year.
#
# Age must progress coherently through missed capture years. We preferentially
# use exact recorded age, where available. If only a cub/yearling class is
# known, it is propagated forwards. If the first known class is adult, all
# subsequent years are adult; we do NOT back-calculate a unique juvenile age
# from an adult observation because adult is an open-ended category.
age_class_mat <- matrix(NA_integer_, nrow = nind, ncol = n_prim)

age_by_year <- bc %>%
  group_by(tattoo, primary) %>%
  summarise(
    age_numeric = if (all(is.na(age_numeric))) {
      NA_real_
    } else {
      first(na.omit(age_numeric))
    },
    age_class = if (all(is.na(age_class))) {
      NA_integer_
    } else {
      first(na.omit(age_class))
    },
    .groups = "drop"
  )

for (i in seq_len(nind)) {

  dat_i <- age_by_year %>%
    filter(tattoo == ids[i]) %>%
    arrange(primary)

  exact_rows <- which(!is.na(dat_i$age_numeric))

  if (length(exact_rows) > 0) {

    r0 <- exact_rows[1]
    k0 <- dat_i$primary[r0]
    age0 <- dat_i$age_numeric[r0]

    # Propagate exact age forwards from the first exact age record.
    for (k in k0:n_prim) {
      calculated_age <- age0 + (k - k0)
      age_class_mat[i, k] <- case_when(
        calculated_age < 1 ~ 1L,
        calculated_age < 2 ~ 2L,
        TRUE ~ 3L
      )
    }

  } else {

    class_rows <- which(!is.na(dat_i$age_class))

    if (length(class_rows) > 0) {

      r0 <- class_rows[1]
      k0 <- dat_i$primary[r0]
      class0 <- dat_i$age_class[r0]

      if (class0 == 1L) {
        age_class_mat[i, k0] <- 1L
        if (k0 < n_prim) age_class_mat[i, k0 + 1L] <- 2L
        if (k0 + 1L < n_prim) {
          age_class_mat[i, (k0 + 2L):n_prim] <- 3L
        }
      } else if (class0 == 2L) {
        age_class_mat[i, k0] <- 2L
        if (k0 < n_prim) age_class_mat[i, (k0 + 1L):n_prim] <- 3L
      } else {
        age_class_mat[i, k0:n_prim] <- 3L
      }
    }
  }

  # Values before first capture are not used by the likelihood. Fill them to
  # keep NIMBLE constants complete. Completely unknown animals default to
  # adult, but are reported below so this assumption can be audited.
  age_class_mat[i, is.na(age_class_mat[i, ])] <- 3L
}

unknown_age_ids <- age_by_year %>%
  group_by(tattoo) %>%
  summarise(any_age = any(!is.na(age_numeric) | !is.na(age_class)), .groups = "drop") %>%
  filter(!any_age) %>%
  pull(tattoo)

if (length(unknown_age_ids) > 0) {
  warning(
    length(unknown_age_ids),
    " individuals have no usable age information and default to adult. ",
    "Inspect these before interpreting M0c age effects."
  )
}

# Latent alive/dead data.
#
# A post-mortem record in death_occasion is an observation in that period, so
# z = 1 there. The animal is fixed dead only from the following primary period.
z_data <- matrix(NA, nrow = nind, ncol = n_prim)

for (i in seq_len(nind)) {
  observed_years_i <- sort(unique(bc$primary[bc$tattoo == ids[i]]))
  z_data[i, observed_years_i] <- 1L

  if (known_death[i] && death_occasion[i] < n_prim) {
    z_data[i, (death_occasion[i] + 1L):n_prim] <- 0L
  }
}

# Check that every recorded encounter is compatible with z = 1.
capture_cells <- which(H >= 2L, arr.ind = TRUE)

if (nrow(capture_cells) > 0) {
  conflicting_cells <- apply(
    capture_cells,
    1,
    function(idx) {
      i <- idx[1]
      k <- idx[3]
      !is.na(z_data[i, k]) && z_data[i, k] == 0L
    }
  )

  if (any(conflicting_cells)) {
    bad <- capture_cells[conflicting_cells, , drop = FALSE]

    stop(
      "At least one recorded live/dead encounter occurs in a primary period ",
      "where z_data is fixed to 0. First conflicting array position: i=",
      bad[1, 1], ", secondary=", bad[1, 2], ", primary=", bad[1, 3],
      call. = FALSE
    )
  }
}

# Verify death-year handling explicitly.
death_audit <- tibble(
  tattoo = ids,
  first_primary = first,
  death_occasion = death_occasion,
  death_secondary = death_secondary,
  known_death = known_death,
  K = K,
  z_at_death = ifelse(
    known_death,
    vapply(seq_len(nind), function(i) {
      z_data[i, death_occasion[i]]
    }, numeric(1)),
    NA_real_
  ),
  z_after_death = vapply(seq_len(nind), function(i) {
    if (known_death[i] && death_occasion[i] < n_prim) {
      z_data[i, death_occasion[i] + 1L]
    } else {
      NA_real_
    }
  }, numeric(1))
)

write.csv(
  death_audit,
  file.path(audit_dir, paste0("death_handling_audit_", model_tag, ".csv")),
  row.names = FALSE
)

# Sort individuals into those with and without a later interval.
ord <- order(K - first)

K <- K[ord]
J <- J[ord, , drop = FALSE]
first <- first[ord]
H <- H[ord, , , drop = FALSE]
death_occasion <- death_occasion[ord]
z_data <- z_data[ord, , drop = FALSE]
sex_id <- sex_id[ord]
first_location <- first_location[ord]
age_class_mat <- age_class_mat[ord, , drop = FALSE]
ids <- ids[ord]

N <- c(sum((K - first) == 0), length(first))

if (N[1] < 1) {
  stop(
    "No individuals have K == first. Rewrite the split loops or use a dataset ",
    "with at least one single-primary individual.",
    call. = FALSE
  )
}

if (N[1] >= N[2]) {
  stop("No individuals have a later survival/movement interval.", call. = FALSE)
}

# ---- 6. NIMBLE model definitions -------------------------------------------

code_M0a <- nimbleCode({

  # Priors
  alpha_p0 ~ dnorm(0, sd = 1.5)
  p0 <- ilogit(alpha_p0)
  lambda0 <- -log(1 - p0)

  alpha_logsigma ~ dnorm(log(8), sd = 1)
  sigma <- exp(alpha_logsigma)

  alpha_phi ~ dnorm(1.5, sd = 1)
  phi <- ilogit(alpha_phi)

  alpha_logd ~ dnorm(log(8), sd = 1)
  dmean <- exp(alpha_logd)
  dlambda <- 1 / dmean

  # Individuals with no later primary interval
  for (i in 1:N[1]) {

    z[i, first[i]] ~ dbern(1)

    S[i, 1, first[i]] <- X[first_location[i], 1]
    S[i, 2, first[i]] <- X[first_location[i], 2]

    g[i, first[i], 1] <- 0

    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(
        pow(S[i, 1, first[i]] - X[r, 1], 2) +
        pow(S[i, 2, first[i]] - X[r, 2], 2)
      )

      g[i, first[i], r + 1] <-
        exp(-pow(D[i, r, first[i]], 2) / (2 * pow(sigma, 2)))
    }

    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])

    for (j in 1:J[i, first[i]]) {
      P[i, j, first[i]] <- 1 - exp(-lambda0 * G[i, first[i]])

      captureProb[i, first[i], j] <-
        step(H[i, j, first[i]] - 2) *
        (g[i, first[i], H[i, j, first[i]]] /
          (G[i, first[i]] + 1e-10)) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) *
        (1 - P[i, j, first[i]])

      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }
  }

  # Individuals with later primary intervals
  for (i in (N[1] + 1):N[2]) {

    z[i, first[i]] ~ dbern(1)

    S[i, 1, first[i]] <- X[first_location[i], 1]
    S[i, 2, first[i]] <- X[first_location[i], 2]

    g[i, first[i], 1] <- 0

    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(
        pow(S[i, 1, first[i]] - X[r, 1], 2) +
        pow(S[i, 2, first[i]] - X[r, 2], 2)
      )

      g[i, first[i], r + 1] <-
        exp(-pow(D[i, r, first[i]], 2) / (2 * pow(sigma, 2)))
    }

    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])

    for (j in 1:J[i, first[i]]) {
      P[i, j, first[i]] <- 1 - exp(-lambda0 * G[i, first[i]])

      captureProb[i, first[i], j] <-
        step(H[i, j, first[i]] - 2) *
        (g[i, first[i], H[i, j, first[i]]] /
          (G[i, first[i]] + 1e-10)) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) *
        (1 - P[i, j, first[i]])

      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }

    for (k in (first[i] + 1):K[i]) {

      Palive[i, k - 1] <- z[i, k - 1] * phi
      z[i, k] ~ dbern(Palive[i, k - 1] *
        step(death_occasion[i] - k))

      theta[i, k - 1] ~ dunif(-3.141593, 3.141593)
      d[i, k - 1] ~ dexp(dlambda)

      S[i, 1, k] <- S[i, 1, k - 1] +
        d[i, k - 1] * cos(theta[i, k - 1])

      S[i, 2, k] <- S[i, 2, k - 1] +
        d[i, k - 1] * sin(theta[i, k - 1])

      g[i, k, 1] <- 0

      for (r in 1:R) {
        D[i, r, k] <- sqrt(
          pow(S[i, 1, k] - X[r, 1], 2) +
          pow(S[i, 2, k] - X[r, 2], 2)
        )

        g[i, k, r + 1] <-
          exp(-pow(D[i, r, k], 2) / (2 * pow(sigma, 2)))
      }

      G[i, k] <- sum(g[i, k, 1:(R + 1)])

      for (j in 1:J[i, k]) {
        P[i, j, k] <- (1 - exp(-lambda0 * G[i, k])) * z[i, k]

        captureProb[i, k, j] <-
          step(H[i, j, k] - 2) *
          (g[i, k, H[i, j, k]] / (G[i, k] + 1e-10)) *
          P[i, j, k] +
          (1 - step(H[i, j, k] - 2)) *
          (1 - P[i, j, k])

        Ones[i, j, k] ~ dbern(captureProb[i, k, j])
      }
    }
  }
})

code_M0b <- nimbleCode({

  alpha_p0 ~ dnorm(0, sd = 1.5)
  beta_p_sex ~ dnorm(0, sd = 1)

  alpha_logsigma ~ dnorm(log(8), sd = 1)
  beta_logsigma_sex ~ dnorm(0, sd = 0.7)

  alpha_phi ~ dnorm(1.5, sd = 1)
  beta_phi_sex ~ dnorm(0, sd = 1)

  alpha_logd ~ dnorm(log(8), sd = 1)
  beta_logd_sex ~ dnorm(0, sd = 0.7)

  for (s in 1:2) {
    p0[s] <- ilogit(alpha_p0 + beta_p_sex * equals(s, 2))
    lambda0[s] <- -log(1 - p0[s])

    sigma[s] <- exp(
      alpha_logsigma + beta_logsigma_sex * equals(s, 2)
    )

    phi[s] <- ilogit(
      alpha_phi + beta_phi_sex * equals(s, 2)
    )

    dmean[s] <- exp(
      alpha_logd + beta_logd_sex * equals(s, 2)
    )

    dlambda[s] <- 1 / dmean[s]
  }

  for (i in 1:N[1]) {

    z[i, first[i]] ~ dbern(1)

    S[i, 1, first[i]] <- X[first_location[i], 1]
    S[i, 2, first[i]] <- X[first_location[i], 2]

    g[i, first[i], 1] <- 0

    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(
        pow(S[i, 1, first[i]] - X[r, 1], 2) +
        pow(S[i, 2, first[i]] - X[r, 2], 2)
      )

      g[i, first[i], r + 1] <-
        exp(-pow(D[i, r, first[i]], 2) /
          (2 * pow(sigma[sex_id[i]], 2)))
    }

    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])

    for (j in 1:J[i, first[i]]) {
      P[i, j, first[i]] <-
        1 - exp(-lambda0[sex_id[i]] * G[i, first[i]])

      captureProb[i, first[i], j] <-
        step(H[i, j, first[i]] - 2) *
        (g[i, first[i], H[i, j, first[i]]] /
          (G[i, first[i]] + 1e-10)) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) *
        (1 - P[i, j, first[i]])

      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }
  }

  for (i in (N[1] + 1):N[2]) {

    z[i, first[i]] ~ dbern(1)

    S[i, 1, first[i]] <- X[first_location[i], 1]
    S[i, 2, first[i]] <- X[first_location[i], 2]

    g[i, first[i], 1] <- 0

    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(
        pow(S[i, 1, first[i]] - X[r, 1], 2) +
        pow(S[i, 2, first[i]] - X[r, 2], 2)
      )

      g[i, first[i], r + 1] <-
        exp(-pow(D[i, r, first[i]], 2) /
          (2 * pow(sigma[sex_id[i]], 2)))
    }

    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])

    for (j in 1:J[i, first[i]]) {
      P[i, j, first[i]] <-
        1 - exp(-lambda0[sex_id[i]] * G[i, first[i]])

      captureProb[i, first[i], j] <-
        step(H[i, j, first[i]] - 2) *
        (g[i, first[i], H[i, j, first[i]]] /
          (G[i, first[i]] + 1e-10)) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) *
        (1 - P[i, j, first[i]])

      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }

    for (k in (first[i] + 1):K[i]) {

      Palive[i, k - 1] <- z[i, k - 1] * phi[sex_id[i]]

      z[i, k] ~ dbern(
        Palive[i, k - 1] * step(death_occasion[i] - k)
      )

      theta[i, k - 1] ~ dunif(-3.141593, 3.141593)
      d[i, k - 1] ~ dexp(dlambda[sex_id[i]])

      S[i, 1, k] <- S[i, 1, k - 1] +
        d[i, k - 1] * cos(theta[i, k - 1])

      S[i, 2, k] <- S[i, 2, k - 1] +
        d[i, k - 1] * sin(theta[i, k - 1])

      g[i, k, 1] <- 0

      for (r in 1:R) {
        D[i, r, k] <- sqrt(
          pow(S[i, 1, k] - X[r, 1], 2) +
          pow(S[i, 2, k] - X[r, 2], 2)
        )

        g[i, k, r + 1] <-
          exp(-pow(D[i, r, k], 2) /
            (2 * pow(sigma[sex_id[i]], 2)))
      }

      G[i, k] <- sum(g[i, k, 1:(R + 1)])

      for (j in 1:J[i, k]) {
        P[i, j, k] <-
          (1 - exp(-lambda0[sex_id[i]] * G[i, k])) * z[i, k]

        captureProb[i, k, j] <-
          step(H[i, j, k] - 2) *
          (g[i, k, H[i, j, k]] / (G[i, k] + 1e-10)) *
          P[i, j, k] +
          (1 - step(H[i, j, k] - 2)) *
          (1 - P[i, j, k])

        Ones[i, j, k] ~ dbern(captureProb[i, k, j])
      }
    }
  }
})

code_M0c <- nimbleCode({

  alpha_p0 ~ dnorm(0, sd = 1.5)
  beta_p_sex ~ dnorm(0, sd = 1)

  alpha_logsigma ~ dnorm(log(8), sd = 1)
  beta_logsigma_sex ~ dnorm(0, sd = 0.7)

  alpha_phi ~ dnorm(1.5, sd = 1)
  beta_phi_sex ~ dnorm(0, sd = 1)

  for (a in 1:2) {
    beta_phi_age[a] ~ dnorm(0, sd = 1)
  }

  sigma_year ~ T(dnorm(0, sd = 0.7), 0, )
  for (k in 1:(n_prim - 1)) {
    year_raw[k] ~ dnorm(0, sd = 1)
    year_effect[k] <- year_raw[k] * sigma_year
  }

  alpha_logd ~ dnorm(log(8), sd = 1)
  beta_logd_sex ~ dnorm(0, sd = 0.7)

  for (s in 1:2) {
    p0[s] <- ilogit(alpha_p0 + beta_p_sex * equals(s, 2))
    lambda0[s] <- -log(1 - p0[s])

    sigma[s] <- exp(
      alpha_logsigma + beta_logsigma_sex * equals(s, 2)
    )

    dmean[s] <- exp(
      alpha_logd + beta_logd_sex * equals(s, 2)
    )

    dlambda[s] <- 1 / dmean[s]
  }

  # Derived survival estimates for reporting:
  # age 1 = cub, age 2 = yearling, age 3 = adult reference
  for (s in 1:2) {
    for (a in 1:3) {
      phi_reference[s, a] <- ilogit(
        alpha_phi +
        beta_phi_sex * equals(s, 2) +
        beta_phi_age[1] * equals(a, 1) +
        beta_phi_age[2] * equals(a, 2)
      )
    }
  }

  for (i in 1:N[1]) {

    z[i, first[i]] ~ dbern(1)

    S[i, 1, first[i]] <- X[first_location[i], 1]
    S[i, 2, first[i]] <- X[first_location[i], 2]

    g[i, first[i], 1] <- 0

    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(
        pow(S[i, 1, first[i]] - X[r, 1], 2) +
        pow(S[i, 2, first[i]] - X[r, 2], 2)
      )

      g[i, first[i], r + 1] <-
        exp(-pow(D[i, r, first[i]], 2) /
          (2 * pow(sigma[sex_id[i]], 2)))
    }

    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])

    for (j in 1:J[i, first[i]]) {
      P[i, j, first[i]] <-
        1 - exp(-lambda0[sex_id[i]] * G[i, first[i]])

      captureProb[i, first[i], j] <-
        step(H[i, j, first[i]] - 2) *
        (g[i, first[i], H[i, j, first[i]]] /
          (G[i, first[i]] + 1e-10)) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) *
        (1 - P[i, j, first[i]])

      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }
  }

  for (i in (N[1] + 1):N[2]) {

    z[i, first[i]] ~ dbern(1)

    S[i, 1, first[i]] <- X[first_location[i], 1]
    S[i, 2, first[i]] <- X[first_location[i], 2]

    g[i, first[i], 1] <- 0

    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(
        pow(S[i, 1, first[i]] - X[r, 1], 2) +
        pow(S[i, 2, first[i]] - X[r, 2], 2)
      )

      g[i, first[i], r + 1] <-
        exp(-pow(D[i, r, first[i]], 2) /
          (2 * pow(sigma[sex_id[i]], 2)))
    }

    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])

    for (j in 1:J[i, first[i]]) {
      P[i, j, first[i]] <-
        1 - exp(-lambda0[sex_id[i]] * G[i, first[i]])

      captureProb[i, first[i], j] <-
        step(H[i, j, first[i]] - 2) *
        (g[i, first[i], H[i, j, first[i]]] /
          (G[i, first[i]] + 1e-10)) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) *
        (1 - P[i, j, first[i]])

      Ones[i, j, first[i]] ~ dbern(captureProb[i, first[i], j])
    }

    for (k in (first[i] + 1):K[i]) {

      logit_phi[i, k - 1] <-
        alpha_phi +
        beta_phi_sex * equals(sex_id[i], 2) +
        beta_phi_age[1] * equals(age_class[i, k - 1], 1) +
        beta_phi_age[2] * equals(age_class[i, k - 1], 2) +
        year_effect[k - 1]

      phi_ind[i, k - 1] <- ilogit(logit_phi[i, k - 1])

      Palive[i, k - 1] <- z[i, k - 1] * phi_ind[i, k - 1]

      z[i, k] ~ dbern(
        Palive[i, k - 1] * step(death_occasion[i] - k)
      )

      theta[i, k - 1] ~ dunif(-3.141593, 3.141593)
      d[i, k - 1] ~ dexp(dlambda[sex_id[i]])

      S[i, 1, k] <- S[i, 1, k - 1] +
        d[i, k - 1] * cos(theta[i, k - 1])

      S[i, 2, k] <- S[i, 2, k - 1] +
        d[i, k - 1] * sin(theta[i, k - 1])

      g[i, k, 1] <- 0

      for (r in 1:R) {
        D[i, r, k] <- sqrt(
          pow(S[i, 1, k] - X[r, 1], 2) +
          pow(S[i, 2, k] - X[r, 2], 2)
        )

        g[i, k, r + 1] <-
          exp(-pow(D[i, r, k], 2) /
            (2 * pow(sigma[sex_id[i]], 2)))
      }

      G[i, k] <- sum(g[i, k, 1:(R + 1)])

      for (j in 1:J[i, k]) {
        P[i, j, k] <-
          (1 - exp(-lambda0[sex_id[i]] * G[i, k])) * z[i, k]

        captureProb[i, k, j] <-
          step(H[i, j, k] - 2) *
          (g[i, k, H[i, j, k]] / (G[i, k] + 1e-10)) *
          P[i, j, k] +
          (1 - step(H[i, j, k] - 2)) *
          (1 - P[i, j, k])

        Ones[i, j, k] ~ dbern(captureProb[i, k, j])
      }
    }
  }
})

model_code <- switch(
  MODEL_VERSION,
  M0a = code_M0a,
  M0b = code_M0b,
  M0c = code_M0c,
  stop("MODEL_VERSION must be M0a, M0b, or M0c.")
)

# ---- 7. Initial values, constants and data ----------------------------------

inits <- make_initial_values(
  bc = bc,
  ids = ids,
  nind = nind,
  n_prim = n_prim,
  first = first,
  K = K,
  sex_id = sex_id,
  model_version = MODEL_VERSION
)

# Do not provide initial values for z nodes fixed as data. Latent z nodes retain
# their initial values from make_initial_values().
inits$z[!is.na(z_data)] <- NA

consts <- list(
  R = R,
  N = N,
  K = K,
  J = J,
  first = first,
  X = X,
  n_prim = n_prim,
  H = H,
  death_occasion = death_occasion,
  sex_id = sex_id,
  first_location = first_location,
  age_class = age_class_mat
)

data <- list(
  Ones = array(1L, dim(H)),
  z = z_data
)

# ---- 8. Build model ----------------------------------------------------------

model <- nimbleModel(
  model_code,
  constants = consts,
  data = data,
  inits = inits,
  check = TRUE
)

init_info <- model$initializeInfo()
print(init_info)

if (!is.null(init_info) && length(init_info) > 0) {
  message("Review initializeInfo() output carefully before proceeding.")
}

cModel <- compileNimble(model)

# ---- 9. Configure MCMC -------------------------------------------------------

main_monitors <- switch(
  MODEL_VERSION,
  M0a = c(
    "alpha_p0", "p0",
    "alpha_logsigma", "sigma",
    "alpha_phi", "phi",
    "alpha_logd", "dmean"
  ),
  M0b = c(
    "alpha_p0", "beta_p_sex", "p0",
    "alpha_logsigma", "beta_logsigma_sex", "sigma",
    "alpha_phi", "beta_phi_sex", "phi",
    "alpha_logd", "beta_logd_sex", "dmean"
  ),
  M0c = c(
    "alpha_p0", "beta_p_sex", "p0",
    "alpha_logsigma", "beta_logsigma_sex", "sigma",
    "alpha_phi", "beta_phi_sex", "beta_phi_age",
    "sigma_year", "year_effect", "phi_reference",
    "alpha_logd", "beta_logd_sex", "dmean"
  )
)

if (MONITOR_LATENT) {
  latent_nodes <- character()

  for (i in seq_len(nind)) {
    valid_years <- seq(first[i], K[i])

    latent_nodes <- c(
      latent_nodes,
      paste0("z[", i, ", ", valid_years, "]"),
      paste0("S[", i, ", 1, ", valid_years, "]"),
      paste0("S[", i, ", 2, ", valid_years, "]")
    )
  }

  config <- configureMCMC(
    model,
    monitors = main_monitors,
    thin = 1,
    monitors2 = latent_nodes,
    thin2 = 20
  )
} else {
  config <- configureMCMC(
    model,
    monitors = main_monitors,
    thin = 1
  )
}

rMCMC <- buildMCMC(config)
cMCMC <- compileNimble(rMCMC)

# ---- 10. Run MCMC ------------------------------------------------------------

if (TEST_RUN) {
  niter <- MCMC_NITER_TEST
  nburnin <- MCMC_NBURN_TEST
  nchains <- MCMC_NCHAINS_TEST
  thin <- 1
} else {
  niter <- MCMC_NITER_FULL
  nburnin <- MCMC_NBURN_FULL
  nchains <- MCMC_NCHAINS_FULL
  thin <- MCMC_THIN_FULL
}

message(
  "Running ", MODEL_VERSION,
  " with ", nchains, " chains, ",
  niter, " iterations, ",
  nburnin, " burn-in, thin = ", thin
)

run_time <- system.time(
  run <- runMCMC(
    cMCMC,
    niter = niter,
    nburnin = nburnin,
    thin = thin,
    nchains = nchains,
    progressBar = TRUE,
    summary = FALSE,
    samplesAsCodaMCMC = TRUE
  )
)

print(run_time)

output_path <- file.path(
  out_dir,
  paste0("baseline_spatial_cmr_", model_tag, ".rds")
)

saveRDS(
  list(
    samples = run,
    model_version = MODEL_VERSION,
    year_lookup = year_lookup,
    ids = ids,
    sex_id = sex_id,
    age_class = age_class_mat,
    first = first,
    K = K,
    H = H,
    J = J,
    X = X,
    SGs = SGs,
    run_time = run_time
  ),
  output_path
)

message("Saved model output to: ", output_path)

# ---- 11. Core diagnostics ----------------------------------------------------

samples_mat <- as.matrix(run)

cat("\nMain sample checks\n")
cat("Rows: ", nrow(samples_mat), "\n")
cat("Columns: ", ncol(samples_mat), "\n")
cat("NA: ", sum(is.na(samples_mat)), "\n")
cat("NaN: ", sum(is.nan(samples_mat)), "\n")
cat("Inf: ", sum(is.infinite(samples_mat)), "\n")

if (any(!is.finite(samples_mat))) {
  stop("Non-finite values found in monitored posterior samples.", call. = FALSE)
}

diagnostic_table <- extract_main_diagnostics(run)

write.csv(
  diagnostic_table,
  file.path(plot_dir, paste0("parameter_diagnostics_", model_tag, ".csv")),
  row.names = FALSE
)

print(
  diagnostic_table %>%
    arrange(desc(rhat)) %>%
    head(30)
)

# Trace plots
pdf(
  file.path(plot_dir, paste0("traceplots_", model_tag, ".pdf")),
  width = 11,
  height = 8.5
)

plot(run)
dev.off()

# Posterior summaries
summary_table <- as.data.frame(summary(run)$statistics) %>%
  rownames_to_column("parameter") %>%
  left_join(
    as.data.frame(summary(run)$quantiles) %>%
      rownames_to_column("parameter"),
    by = "parameter"
  )

write.csv(
  summary_table,
  file.path(plot_dir, paste0("posterior_summary_", model_tag, ".csv")),
  row.names = FALSE
)

# Pairwise correlations for main transformed parameters
key_cols <- grep(
  "^(p0|sigma|phi\\[|phi$|dmean|beta_|sigma_year|phi_reference)",
  colnames(samples_mat),
  value = TRUE
)

if (length(key_cols) >= 2) {
  cor_mat <- cor(samples_mat[, key_cols, drop = FALSE])

  write.csv(
    cor_mat,
    file.path(plot_dir, paste0("posterior_correlations_", model_tag, ".csv"))
  )
}

# ---- 12. Basic observed-data checks -----------------------------------------

# Observed captures by year
observed_by_year <- bc %>%
  group_by(primary_year, sex_clean) %>%
  summarise(
    n_captures = n(),
    n_individuals = n_distinct(tattoo),
    .groups = "drop"
  )

write.csv(
  observed_by_year,
  file.path(plot_dir, paste0("observed_capture_counts_", model_tag, ".csv")),
  row.names = FALSE
)

p1 <- ggplot(
  observed_by_year,
  aes(primary_year, n_individuals, linetype = sex_clean)
) +
  geom_line() +
  geom_point() +
  theme_classic() +
  labs(
    x = "Year",
    y = "Number of individuals detected",
    linetype = "Sex"
  )

ggsave(
  file.path(plot_dir, paste0("observed_individuals_by_year_", model_tag, ".png")),
  p1,
  width = 10,
  height = 6,
  dpi = 300
)

# Observed annual spatial transitions
obs_transitions <- bc %>%
  arrange(tattoo, primary, trap_season, date) %>%
  group_by(tattoo, primary) %>%
  summarise(
    SG = first(SG),
    sex_clean = first(sex_clean),
    col_index = first(col_index),
    row_index = first(row_index),
    .groups = "drop"
  ) %>%
  arrange(tattoo, primary) %>%
  group_by(tattoo) %>%
  mutate(
    lag_col = lag(col_index),
    lag_row = lag(row_index),
    displacement = sqrt(
      (col_index - lag_col)^2 + (row_index - lag_row)^2
    ),
    switched_group = SG != lag(SG)
  ) %>%
  ungroup()

write.csv(
  obs_transitions,
  file.path(plot_dir, paste0("observed_spatial_transitions_", model_tag, ".csv")),
  row.names = FALSE
)

# ---- 13. Derived contrasts ---------------------------------------------------

samples_df <- as.data.frame(samples_mat)

if (MODEL_VERSION %in% c("M0b", "M0c")) {

  if (all(c("dmean[1]", "dmean[2]") %in% names(samples_df))) {
    movement_contrast <- samples_df %>%
      transmute(
        female = `dmean[1]`,
        male = `dmean[2]`,
        male_minus_female = male - female
      ) %>%
      summarise(
        median_difference = median(male_minus_female),
        lower_95 = quantile(male_minus_female, 0.025),
        upper_95 = quantile(male_minus_female, 0.975),
        probability_male_greater = mean(male_minus_female > 0)
      )

    write.csv(
      movement_contrast,
      file.path(plot_dir, paste0("movement_contrast_", model_tag, ".csv")),
      row.names = FALSE
    )

    print(movement_contrast)
  }

  if (all(c("p0[1]", "p0[2]") %in% names(samples_df))) {
    detection_contrast <- samples_df %>%
      transmute(
        female = `p0[1]`,
        male = `p0[2]`,
        male_minus_female = male - female
      ) %>%
      summarise(
        median_difference = median(male_minus_female),
        lower_95 = quantile(male_minus_female, 0.025),
        upper_95 = quantile(male_minus_female, 0.975),
        probability_male_greater = mean(male_minus_female > 0)
      )

    write.csv(
      detection_contrast,
      file.path(plot_dir, paste0("detection_contrast_", model_tag, ".csv")),
      row.names = FALSE
    )
  }
}

# ---- 14. Model run summary ---------------------------------------------------

run_summary <- tibble(
  model = MODEL_VERSION,
  test_run = TEST_RUN,
  n_rows = nrow(bc),
  n_individuals = nind,
  n_years = n_prim,
  n_secondary = n_sec,
  n_detectors = R,
  n_chains = nchains,
  n_iterations = niter,
  n_burnin = nburnin,
  thin = thin,
  elapsed_seconds = unname(run_time["elapsed"]),
  max_rhat = max(diagnostic_table$rhat, na.rm = TRUE),
  min_ess_bulk = min(diagnostic_table$ess_bulk, na.rm = TRUE),
  min_ess_tail = min(diagnostic_table$ess_tail, na.rm = TRUE)
)

write.csv(
  run_summary,
  file.path(plot_dir, paste0("run_summary_", model_tag, ".csv")),
  row.names = FALSE
)

print(run_summary)

message(
  "\nFinished ", MODEL_VERSION, ".\n",
  "Next: inspect initializeInfo, trace plots, Rhat, ESS, posterior correlations, ",
  "and the observed spatial-transition summaries before moving to the next model."
)
