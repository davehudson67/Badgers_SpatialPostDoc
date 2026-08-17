# Woodchester Robust-Design Spatial CMR — V1 Full-Dataset Baseline
## Fully annotated model, data workflow, and NIMBLE implementation

This document explains the current **Woodchester robust-design spatial capture–recapture / spatial CMR model (V1 full-dataset baseline)** in detail. It is based on the current working code and is intended both as a modelling record and as documentation for collaborators.

The model uses:

- **Primary occasions:** years
- **Secondary occasions:** four trapping seasons within each year
- **Spatial observations:** actual sett coordinates
- **Latent spatial process:** annual activity-centre movement
- **Survival:** annual
- **Detection:** group-specific baseline detection with seasonal and five-year temporal effects
- **Movement:** exponential annual displacement with a random direction
- **Entry-history groups:** first caught as Cub/Yearling versus first caught as Adult

The model is deliberately still a **baseline robust-design spatial CMR model**. It does **not yet explicitly model an outer emigration state, social-group boundary resistance, age-dependent survival, or disease effects**. Those are intended as later extensions.

---

# 1. Conceptual overview

For badger \(i\) in year \(k\), the model assumes an unobserved annual activity centre

\[
\mathbf{S}_{i,k} = (S^x_{i,k}, S^y_{i,k}).
\]

Within each year there are four trapping seasons. A badger may be:

- not captured, or
- captured at one of the known sett locations.

The observed sett is treated as a **detector location**, not as the animal's true activity centre.

The model therefore separates two spatial scales:

1. **Within-year spatial detection / space-use scale**, controlled by `sigma`.
2. **Between-year displacement of the latent activity centre**, controlled by `dmean`.

This distinction is important. `sigma` is not interpreted as annual dispersal distance, and `dmean` is not interpreted as the within-season home-range radius.

Annual survival is modelled separately using `phi_annual`.

---

# 2. Robust-design structure

The data are organised as:

```text
Individual
 └── Year = primary occasion
      ├── Season 1
      ├── Season 2
      ├── Season 3
      └── Season 4
```

The latent activity centre is allowed to change **between years**, but is treated as common to all four seasonal capture occasions within a year.

So, for one badger:

```text
Year 1: one latent AC -> four seasonal observations
Year 2: new latent AC -> four seasonal observations
Year 3: new latent AC -> four seasonal observations
...
```

The four secondary occasions therefore provide repeated spatial information about the annual activity centre.

---

# 3. Entry-history groups

Two groups are currently used:

```text
Group 1 = first captured as Cub or Yearling
Group 2 = first captured as Adult
```

This is a **static entry-history classification**.

It is important not to interpret Group 1 as "young animals" throughout life. A badger first caught as a cub remains Group 1 when it is an adult.

Likewise, Group 2 should not yet be interpreted as proven immigrants. Some adults first detected in the study area may have been resident but previously uncaught.

At this stage the grouping is retained mainly for continuity with the earlier survival models.

---

# 4. Detection model

For badger \(i\), year \(k\), and detector sett \(r\), the spatial detection weight is

\[
g_{ikr} = \exp\left[-\frac{D_{ikr}^{2}}{2\sigma_{g(i)}^{2}}\right],
\]

where

\[
D_{ikr} = \|\mathbf{S}_{ik} - \mathbf{X}_{r}\|.
\]

Here:

- \(\mathbf{S}_{ik}\) = latent annual activity centre
- \(\mathbf{X}_{r}\) = coordinates of sett detector \(r\)
- \(\sigma_g\) = group-specific spatial detection scale

The weights over all detector setts are summed:

\[
G_{ik} = \sum_r g_{ikr}.
\]

Baseline seasonal capture probability is modelled on the logit scale:

\[
\text{logit}(p_{0,ijk}) = \alpha_{p,g(i)} + \beta_{\text{season},j} + \beta_{\text{period},k}.
\]

This `p0` is converted to a hazard:

\[
\lambda_0 = -\log(1-p_0).
\]

The probability of being captured at least once during a secondary occasion is then

\[
P_{ijk} = 1-\exp(-\lambda_{0,ijk}G_{ik}).
\]

If the badger is captured, the probability that the observed detector is sett \(r\) is proportional to its spatial detection weight:

\[
P(R=r \mid \text{captured}) = \frac{g_{ikr}}{G_{ik}}.
\]

Thus the likelihood distinguishes:

```text
whether the animal is captured
```

from

```text
where it is captured.
```

---

# 5. Temporal detection effects and unknown trapping effort

Formal trapping-effort histories are not available.

The model therefore allows capture probability to vary through:

- a recurring **four-season effect**
- a shared **five-year temporal-period effect**

Both sets of effects are now fitted with **sum-to-zero constraints**, so `alpha_p` represents an overall group-specific detection intercept rather than the intercept for one arbitrary reference season and historical period.

Thus:

\[
\text{logit}(p_0) = \alpha_p + \beta_{\text{season}} + \beta_{\text{period}}.
\]

These effects should be interpreted as **temporal heterogeneity in the observation process**.

They may absorb variation caused by:

- trapping effort
- trapping intensity
- operational changes
- changing field protocols
- environmental effects on capture probability
- other unmeasured temporal changes

They should **not** be described as direct estimates of trapping effort because effort itself is not observed.

---

# 6. Annual survival

The survival process is

\[
z_{i,k} \sim \text{Bernoulli}(z_{i,k-1}\phi_{g(i)}),
\]

where:

- \(z_{ik}=1\) means alive
- \(z_{ik}=0\) means dead
- \(\phi_g\) is annual survival for entry-history group \(g\)

Known live captures fix `z = 1`.

Known death information is also used to constrain the state process.

At present, `phi_annual` remains closely related to **apparent survival**, because the model has not yet formally integrated over an explicitly bounded outer state space for emigration. The future objective is to extend the spatial process so that disappearance through dispersal can be separated more explicitly from mortality.

---

# 7. Annual movement model

Between years, the activity centre moves according to:

\[
d_{ik} \sim \text{Exponential}(\lambda_g),
\]

with

\[
\lambda_g = \frac{1}{dmean_g}.
\]

A random movement direction is drawn:

\[
\theta_{ik} \sim \text{Uniform}(-\pi,\pi).
\]

The next year's activity centre is then

\[
S^x_{i,k+1} = S^x_{ik} + d_{ik}\cos(\theta_{ik}),
\]

\[
S^y_{i,k+1} = S^y_{ik} + d_{ik}\sin(\theta_{ik}).
\]

Thus `dmean[g]` is the **mean annual displacement of the latent activity centre** for entry-history group \(g\).

This is a deliberately simple baseline movement kernel. Later versions should test:

- heavier-tailed dispersal kernels
- social-group boundary resistance
- explicit outer-state geometry
- potentially distinct local versus dispersal movement processes

---

# 8. Data flow through the model

The overall workflow is:

```text
Raw CMR RDS
   |
   +--> clean sett names
   |
   +--> join sett coordinates
   |
   +--> remove live captures with no usable XY
   |
   +--> construct year index
   |
   +--> assign five-year period
   |
   +--> assign entry-history group
   |
   +--> retain one spatial live capture per season
   |
   +--> construct detector table
   |
   +--> derive first capture year and detector
   |
   +--> derive death information
   |
   +--> construct H[individual, season, year]
   |
   +--> construct z_data[individual, year]
   |
   +--> initialise latent movement from observed annual locations
   |
   +--> build NIMBLE model
   |
   +--> compile model + MCMC
   |
   +--> sample posterior distributions
```

---

# 9. Full annotated R code

## 9.1 Packages and options

```r
library(tidyverse)
library(lubridate)
library(nimble)
library(coda)
library(MCMCvis)

set.seed(123)

SAMPLE_N <- NA_integer_   # full dataset
NITER <- 6000
NBURN <- 1500
NCHAINS <- 2

cmr_file <- "data/badger_final_CMRready_wDisease.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
dir.create("results", showWarnings = FALSE)
```

### What this does

The packages provide:

- `tidyverse` — data manipulation
- `lubridate` — date handling
- `nimble` — Bayesian model definition and MCMC
- `coda` — MCMC diagnostics
- `MCMCvis` — posterior summaries

`SAMPLE_N <- NA_integer_` configures the baseline for the **entire eligible dataset**, rather than the earlier 200-individual development sample.

The full baseline is configured for `6000` MCMC iterations per chain, with the first `1500` discarded as burn-in and two independent chains. These values provide a substantive full-data baseline, but convergence and effective sample size still need to be checked after fitting.

The `results` directory is created automatically so posterior output and diagnostics can be saved reproducibly.

## 9.2 Standardising sett names

```r
sett_aliases <- c(
  "\\bCHESTNUT\\b" = "CHESNUT",
  "\\bJACKS\\b" = "JACKSMIREY",
  "\\bGRAVEL\\b" = "GRAVELPIT",
  "\\bBUCKHOLE\\b" = "BUCKHOLT",
  "\\bTOPSETT\\b" = "TOP",
  "\\bFOXCUB\\b" = "FOX",
  "\\bGULLEY\\b" = "GULLY",
  "\\bBLACKBERRY\\b" = "BRAMBLE",
  "\\bBOC\\b" = "BOG",
  "\\bCEDARBANK\\b" = "CEDAR",
  "\\bCLAYTRAP\\b" = "CLAY",
  "\\bCLIFF\\b" = "CLIFFFACE",
  "\\bDINGLEVALLEY\\b" = "DINGLE"
)

clean_sett <- function(x) {
  x %>%
    as.character() %>%
    toupper() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all(sett_aliases) %>%
    str_replace_all("\\s+", "")
}
```

### Why this is necessary

Sett names have accumulated spelling differences, punctuation, aliases and descriptors over the long study period. The same cleaning rule is therefore applied to the CMR records and to the coordinate table so that the join is based on a consistent identifier.

---

## 9.3 Loading sett coordinates

```r
sett_raw <- read_csv(sett_file, show_col_types = FALSE)

name_candidates <- c(
  "Sett_Clean", "Sett", "sett", "SettName", "Sett_Upper", "Name"
)
x_candidates <- c("SettX", "sett_x", "X", "x", "Easting", "easting")
y_candidates <- c("SettY", "sett_y", "Y", "y", "Northing", "northing")

name_col <- intersect(name_candidates, names(sett_raw))[1]
x_col <- intersect(x_candidates, names(sett_raw))[1]
y_col <- intersect(y_candidates, names(sett_raw))[1]

if (any(is.na(c(name_col, x_col, y_col)))) {
  stop("Could not identify sett name/X/Y columns.")
}

sett_xy <- sett_raw %>%
  transmute(
    Sett_Clean = clean_sett(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(!is.na(Sett_Clean), Sett_Clean != "", !is.na(x), !is.na(y)) %>%
  distinct(Sett_Clean, .keep_all = TRUE)
```

### What happens here

The coordinate file is loaded and the script automatically identifies plausible sett-name, X-coordinate and Y-coordinate columns. The resulting `sett_xy` object contains one coordinate pair per usable sett.

---

## 9.4 Loading and joining the CMR data

```r
cmr_raw <- readRDS(cmr_file)

cmr <- cmr_raw %>%
  mutate(
    Sett_Clean = clean_sett(sett),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season)
  ) %>%
  left_join(sett_xy, by = "Sett_Clean")
```

Each capture record is given a cleaned sett identifier and then matched to the coordinate table.

---

## 9.5 Removing spatially unusable live captures

```r
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
```

Only live encounters lacking coordinates are removed. PM/death-only records are retained because they can still inform the demographic process.

---

## 9.6 Checking whether entire individuals are lost

```r
all_live_ids <- cmr_raw %>% filter(has_live_capture) %>% distinct(tattoo)
spatial_live_ids <- cmr %>% filter(has_live_capture) %>% distinct(tattoo)
lost_badgers <- anti_join(all_live_ids, spatial_live_ids, by = "tattoo")

cat("Badgers with no spatially usable live capture:",
    nrow(lost_badgers), "\n")

if (nrow(lost_badgers) > 0L) print(lost_badgers, n = Inf)
```

A badger is retained if it has at least one spatially usable live capture, even if some other captures lacked coordinates.

---

## 9.7 Constructing annual primary occasions

```r
min_year <- min(cmr$primary_year, na.rm = TRUE)
max_year <- max(cmr$primary_year, na.rm = TRUE)

years <- min_year:max_year
n_prim <- length(years)
n_sec <- 4L

cmr <- cmr %>% mutate(primary = match(primary_year, years))

cat("\nStudy years:", min_year, "-", max_year, "\n")
cat("Primary occasions:", n_prim, "\n")
```

Calendar years are converted to sequential primary-occasion indices for use in arrays.

---

## 9.8 Five-year detection periods

```r
year_lookup <- tibble(primary_year = years) %>%
  mutate(
    period_start = floor(primary_year / 5) * 5,
    period_id = match(period_start, sort(unique(period_start)))
  )

period_vec <- as.integer(year_lookup$period_id)
n_periods <- max(period_vec)

print(year_lookup)
```

This creates broad temporal blocks used to absorb long-term changes in detectability without estimating a separate detection effect for every year.

---

## 9.9 Entry-history group

```r
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
  mutate(
    entry_group = case_when(
      age_fc %in% c("Cub", "Yearling") ~ 1L,
      age_fc == "Adult" ~ 2L,
      TRUE ~ NA_integer_
    )
  )

cmr <- cmr %>%
  left_join(demog %>% select(tattoo, entry_group), by = "tattoo")
```

This creates the static two-group entry-history variable used by the current baseline model.

---

## 9.10 Retaining one live location per season

```r
live <- cmr %>%
  filter(
    has_live_capture, !is.na(primary), !is.na(trap_season),
    !is.na(x), !is.na(y)
  ) %>%
  arrange(tattoo, primary, trap_season, capture_date) %>%
  group_by(tattoo, primary, trap_season) %>%
  slice_tail(n = 1) %>%
  ungroup()

cat("\nQuarterly spatial live records:", nrow(live), "\n")
cat("Badgers represented:", n_distinct(live$tattoo), "\n")
cat("Setts represented:", n_distinct(live$Sett_Clean), "\n")
```

The current observation array allows one detector observation per badger × year × season, so multiple captures in the same season are collapsed to the latest capture.

---

## 9.11 Selecting eligible individuals

```r
eligible <- live %>%
  distinct(tattoo) %>%
  inner_join(demog, by = "tattoo") %>%
  filter(entry_group %in% 1:2)

# Irreconcilable chronology: PM in 2006 followed by live capture in 2015.
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
```

The model retains individuals with at least one usable spatial capture and a defined entry-history group.

One individual, `007V`, is explicitly excluded because the database contains an irreconcilable chronology under that tattoo identifier:

```text
2006-01-03 : post-mortem record
2015-05-20 : live capture at WEST
```

The same individual cannot genuinely be dead in 2006 and captured alive nine years later. Because there is no defensible basis for deciding which source record is wrong, the whole individual history is excluded rather than selectively deleting either record.

This exclusion should be retained in the analysis audit and reported when documenting data exclusions.

## 9.12 Constructing the detector table

```r
detectors <- live %>%
  distinct(Sett_Clean, x, y) %>%
  arrange(Sett_Clean) %>%
  mutate(detector = row_number())

X <- as.matrix(detectors %>% select(x, y))
R <- nrow(X)

live <- live %>%
  left_join(detectors %>% select(Sett_Clean, detector),
            by = "Sett_Clean")

cat("Spatial detectors:", R, "\n")
```

Each unique used sett becomes a detector. `X` is the detector-coordinate matrix used in the spatial likelihood.

---

## 9.13 Individual metadata

```r
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

stopifnot(
  !anyNA(first),
  !anyNA(first_detector),
  !anyNA(entry_group)
)

cat("\nEntry groups:\n")
print(table(entry_group))
```

The model records the first primary occasion, first detector and entry-history class for every badger.

---

## 9.14 Death information

```r
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
```

The first known PM year is used to constrain the latent alive/dead process. One post-death year is retained where possible so that the dead state can be represented explicitly.

---

## 9.15 Encounter array

```r
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
```

`H[individual, season, year]` is coded as:

```text
1       = not captured
2       = detector 1
3       = detector 2
...
R + 1   = detector R
```

The detector category is offset by one because category 1 is reserved for non-capture.

---

## 9.16 Known alive/dead states

```r
z_data <- matrix(NA_integer_, nrow = nind, ncol = n_prim)

for (i in seq_len(nind)) {
  captured_years <- unique(live$primary[live$tattoo == ids[i]])
  z_data[i, captured_years] <- 1L

  if (known_death[i]) {
    z_data[i, death_primary[i]] <- 1L

    if (death_primary[i] < n_prim) {
      z_data[i, (death_primary[i] + 1L):n_prim] <- 0L
    }
  }
}
```

Known live captures fix the alive state to 1. Years after a known death are fixed to 0. Other years remain latent.

---

## 9.17 Sorting histories

```r
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

if (any(K < first)) stop("ERROR: At least one individual has K < first.")
if (any(death_primary < first & death_primary <= n_prim)) {
  stop("ERROR: Known death occurs before first spatial capture.")
}
if (N[1] == 0L || N[1] == N[2]) stop("Current NIMBLE loops require both history types.")
```

This separates one-primary histories from longer histories so NIMBLE does not need to evaluate invalid loops such as `(first + 1):K` when no subsequent primary occasion exists.

Two additional chronology checks now stop execution if:

- `K < first`, meaning an individual's modelled history would end before its first usable spatial capture; or
- a known death precedes first spatial capture.

These checks were added after the `007V` inconsistency revealed a negative history length (`K - first = -8`). They ensure this class of contradiction cannot silently enter a future run.

## 9.18 Initial values

```r
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
```

### Why the initialisation is constructed from the data

The movement variables `d` and `theta` determine all post-entry activity centres deterministically. Arbitrary starting values can therefore make an observed capture essentially impossible.

The corrected initialisation estimates an approximate annual centre from the mean coordinates of observed captures in that year, carries the last observed position through years with no spatial capture, and derives initial displacement distance and direction from those positions.

During development, setting every annual displacement to 200 m due east placed one known activity centre 2.2 km from its observed capture sett and produced a zero capture probability and an initial log-likelihood of `-Inf`. Data-informed movement initialisation removed that numerical failure.

The starting values for `sigma` and `dmean` are now closer to the broad spatial scales found in the 200-individual development run. This changes **starting values only**, not the priors or fitted model.

Seasonal and period starting values are now supplied as `beta_season_raw` and `beta_period_raw`, because the fitted effects use a sum-to-zero parameterisation.

# 10. NIMBLE model

```r
code_RD_SCR <- nimbleCode({

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

  for (s in 1:3) {
    beta_season_raw[s] ~ dnorm(0, sd = 1)
    beta_season[s] <- beta_season_raw[s]
  }
  beta_season[4] <- -sum(beta_season_raw[1:3])

  for (p in 1:(n_periods - 1)) {
    beta_period_raw[p] ~ dnorm(0, sd = 1)
    beta_period[p] <- beta_period_raw[p]
  }
  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods - 1)])

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
```

The biological structure is unchanged from the development model. The main parameterisation change is that seasonal and five-year temporal effects now use **sum-to-zero constraints** rather than fixing the first category to zero. This makes the detection intercept less dependent on an arbitrary reference season and historical period.

# 11. Detailed model mechanics

## 11.1 Survival priors

```r
alpha_phi[grp] ~ dnorm(qlogis(0.70), sd = 1.5)
phi_annual[grp] <- ilogit(alpha_phi[grp])
```

Survival is estimated on the logit scale and transformed back to probability with `ilogit()`.

---

## 11.2 Detection baseline

```r
alpha_p[grp] ~ dnorm(qlogis(0.15), sd = 1.5)
```

This is the group-specific baseline capture tendency before seasonal and temporal-period effects are added.

---

## 11.3 Spatial detection scale

```r
alpha_logsigma[grp] ~ dnorm(log(250), sd = 1)
sigma[grp] <- exp(alpha_logsigma[grp])
```

Exponentiation guarantees `sigma > 0`. Because the sett coordinates are in metres, `sigma` is also in metres.

---

## 11.4 Annual movement scale

```r
alpha_logd[grp] ~ dnorm(log(300), sd = 1)
dmean[grp] <- exp(alpha_logd[grp])
dlambda[grp] <- 1 / dmean[grp]
```

`dmean` is the expected annual activity-centre displacement. `dlambda` is the corresponding exponential rate parameter.

---

## 11.5 Seasonal effects

```r
for (s in 1:3) {
  beta_season_raw[s] ~ dnorm(0, sd = 1)
  beta_season[s] <- beta_season_raw[s]
}
beta_season[4] <- -sum(beta_season_raw[1:3])
```

The four seasonal effects are constrained to sum to zero:

\[
\sum_{s=1}^{4}\beta_{\text{season},s}=0.
\]

The first three effects are estimated directly and the fourth is derived as their negative sum.

This replaces the earlier reference-category formulation, where Season 1 was fixed to zero. Under the new formulation, `alpha_p` is much closer to an overall group-specific detection intercept rather than the intercept specifically for Season 1. This is intended to reduce posterior correlation between `alpha_p` and seasonal effects.

## 11.6 Five-year effects

```r
for (p in 1:(n_periods - 1)) {
  beta_period_raw[p] ~ dnorm(0, sd = 1)
  beta_period[p] <- beta_period_raw[p]
}
beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods - 1)])
```

The five-year period effects are also constrained to sum to zero:

\[
\sum_{p=1}^{P}\beta_{\text{period},p}=0.
\]

This replaces the earlier approach in which the first historical period was fixed to zero. The change was motivated by poor mixing in the 200-individual development run, where the detection intercept and several reference-coded period effects were strongly correlated.

The `beta_period` values therefore represent deviations from the overall temporal mean detection process rather than deviations from the earliest study period.

# 12. First-year conditioning

```r
z[i, first[i]] ~ dbern(1)
S[i, 1, first[i]] <- X[first_detector[i], 1]
S[i, 2, first[i]] <- X[first_detector[i], 2]
```

At first spatial capture the badger is known alive and its initial annual AC is fixed at the first capture sett. The model therefore conditions on first spatial capture rather than estimating abundance or recruitment.

---

# 13. Distance and spatial detection

```r
D[i, r, k] <- sqrt(
  pow(S[i, 1, k] - X[r, 1], 2) +
  pow(S[i, 2, k] - X[r, 2], 2)
)
```

This calculates Euclidean distance from the annual AC to detector `r`.

```r
g[i, k, r + 1] <- exp(
  -pow(D[i, r, k], 2) /
  (2 * pow(sigma[entry_group[i]], 2))
)
```

This converts distance into a half-normal detection weight.

```r
g[i, k, 1] <- 0
```

Category 1 is reserved for non-capture, allowing `H` to directly index the `g` array.

```r
G[i, k] <- sum(g[i, k, 1:(R + 1)])
```

`G` is the total spatial detection opportunity given the current activity centre and the detector layout.

---

# 14. Seasonal capture probability

```r
lp0[i, j, k] <- alpha_p[entry_group[i]] +
  beta_season[j] + beta_period[period_vec[k]]

p0[i, j, k] <- ilogit(lp0[i, j, k])
lambda0[i, j, k] <- -log(1 - p0[i, j, k])
```

This gives the season- and period-specific baseline detection level and converts it to a hazard.

```r
P[i, j, k] <- 1 - exp(-lambda0[i, j, k] * G[i, k])
```

This is the probability of being captured somewhere during that secondary occasion, conditional on being alive.

For later years:

```r
P[i, j, k] <- (1 - exp(-lambda0[i, j, k] * G[i, k])) *
  z[i, k]
```

A dead badger therefore has zero probability of live capture.

---

# 15. Likelihood of the observed detector or non-capture

```r
captureProb[i, j, k] <-
  step(H[i, j, k] - 2) *
  g[i, k, H[i, j, k]] /
  (G[i, k] + 1e-10) *
  P[i, j, k] +
  (1 - step(H[i, j, k] - 2)) *
  (1 - P[i, j, k])
```

If the animal was captured, the likelihood is:

\[
P(\text{captured somewhere})
\times
P(\text{observed sett}\mid\text{captured}).
\]

If the animal was not captured, the likelihood is simply:

\[
1-P.
\]

The small `1e-10` term prevents numerical division by exactly zero.

---

# 16. The Ones trick

```r
Ones[i, j, k] ~ dbern(captureProb[i, j, k])
```

Every element of `Ones` is supplied as observed data equal to 1. The Bernoulli likelihood contribution is therefore exactly `captureProb`. This is a convenient way of inserting the custom observation likelihood into NIMBLE.

---

# 17. Survival transition

```r
Palive[i, k - 1] <- z[i, k - 1] *
  phi_annual[entry_group[i]]

z[i, k] ~ dbern(
  Palive[i, k - 1] * step(death_primary[i] - k)
)
```

If the animal is alive at year `k - 1`, it survives to the next annual state with probability `phi_annual`. If already dead, it remains dead. Known death information further constrains the state process.

---

# 18. Annual AC movement

```r
theta[i, k - 1] ~ dunif(-3.141593, 3.141593)
d[i, k - 1] ~ dexp(dlambda[entry_group[i]])

S[i, 1, k] <- S[i, 1, k - 1] +
  d[i, k - 1] * cos(theta[i, k - 1])

S[i, 2, k] <- S[i, 2, k - 1] +
  d[i, k - 1] * sin(theta[i, k - 1])
```

This draws a distance and direction and converts them into X/Y displacement. The process is currently isotropic.

---

# 19. Constants and data

```r
consts <- list(
  R = R, N = N, K = as.integer(K), J = J,
  first = as.integer(first), X = X, H = H,
  n_periods = n_periods, period_vec = period_vec,
  first_detector = first_detector,
  entry_group = entry_group,
  death_primary = death_primary
)

data_list <- list(
  Ones = array(1L, dim(H)),
  z = z_data
)
```

`consts` contains fixed inputs to the model. `data_list` contains the custom likelihood observations and partially observed survival states.

---

# 19A. Full-data audit before model building

Before building the full NIMBLE graph, the current script prints the structure of the final analysis dataset.

```r
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
```

This audit checks the final model-ready histories rather than only the raw input records.

During full-data preparation, the history summary identified a minimum history length of `-8` in Group 2. Tracing that record revealed `007V`, whose database history contained a PM record in 2006 followed by a live capture in 2015. The contradiction is now handled by excluding that individual and by the hard chronology checks in Section 9.17.

After the exclusion, every modelled history must satisfy `K >= first`, and no known death may precede first spatial capture.

Before that single exclusion, the full-data group sizes were 2,643 Cub/Yearling-entry and 361 Adult-entry badgers. After excluding `007V`, the expected Adult-entry count is 360, giving 3,003 individuals in the full V1 analysis, provided all preceding filters reproduce the same data state.

The detector coordinate range observed during full-data setup was approximately:

```text
X: 379814 to 384143 m
Y: 199687 to 202710 m
```

This is also a useful check that coordinates remain in the expected projected metre-based system.

---

# 20. Model building and initial-likelihood check

```r
#message("\nBuilding model...")

#model <- nimbleModel(
#  code_RD_SCR, constants = consts, data = data_list,
#  inits = inits[[1]], check = TRUE, calculate = FALSE
#)

#print(model$initializeInfo())

#lp <- model$calculate()
#cat("\nInitial log probability:", lp, "\n")
#if (!is.finite(lp)) stop("Initial model log probability is not finite.")
```

These lines are intentionally retained **commented out** in this documentation copy so the model setup can be inspected without rebuilding the large NIMBLE graph accidentally.

When activated, the finite-likelihood check catches impossible starting states before compilation. This was important during development because poor movement initialisation once placed an annual AC 2.2 km from a known capture, giving a zero capture probability and `-Inf` likelihood.

# 21. Compiling and configuring MCMC

```r
#message("\nCompiling model...")
#cModel <- compileNimble(model, resetFunctions = TRUE)

#monitors <- c("phi_annual", "dmean", "sigma", "alpha_p", "beta_season", "beta_period")
#config <- configureMCMC(model, monitors = monitors, thin = 1)
#Rmcmc <- buildMCMC(config)

#message("\nCompiling MCMC...")
#cMCMC <- compileNimble(Rmcmc, project = cModel, resetFunctions = TRUE)
```

These lines are deliberately retained commented out in this documentation copy.

Only biologically important population-level parameters are monitored. Large latent arrays such as `S`, `D`, `g`, `G`, `P`, `d`, and `theta` are not saved routinely because retaining them for every posterior draw would greatly increase memory and output size.

# 22. Running MCMC

```r
#message("\nRunning full-data MCMC...")

#runtime <- system.time({
#  samples_RD <- runMCMC(
#    cMCMC, niter = NITER, nburnin = NBURN, nchains = NCHAINS, inits = inits,
#    samplesAsCodaMCMC = TRUE, progressBar = TRUE,
#    setSeed = 1451:(1451 + NCHAINS - 1L)
#  )
#})

#print(runtime)

#saveRDS(
#  list(
#    samples = samples_RD, runtime = runtime, years = years,
#    detectors = detectors, ids = ids, entry_group = entry_group,
#    first = first, K = K,
#    settings = list(
#      niter = NITER, nburn = NBURN, nchains = NCHAINS,
#      sample_n = SAMPLE_N
#    )
#  ),
#  "results/RD_SCR_V1_full.rds"
#)
```

The full MCMC block is intentionally **left commented out** here, as requested, so the script can be reviewed without accidentally launching a long full-data run.

When enabled, the model records total runtime and saves posterior samples together with key detector, individual, history and MCMC metadata. This is preferable to saving the posterior object alone.

# 23. Diagnostics

```r
#MCMCsummary(samples_RD)
#gelman.diag(samples_RD, multivariate = FALSE)
#effectiveSize(samples_RD)

#pdf("results/RD_SCR_V1_traceplots.pdf", width = 10, height = 7)
#traceplot(samples_RD[, c(
#  "phi_annual[1]", "phi_annual[2]",
#  "dmean[1]", "dmean[2]",
#  "sigma[1]", "sigma[2]",
#  "alpha_p[1]", "alpha_p[2]"
#)])
#dev.off()
```

The diagnostic code is also retained commented out in this review copy.

The main checks after the full run are posterior uncertainty, between-chain convergence using \(\hat{R}\), effective sample size, and trace behaviour for survival, movement, spatial detection and detection-intercept parameters.

The earlier 200-individual development run showed that `dmean` in particular could mix slowly, so effective sample size is especially important even when \(\hat{R}\) appears close to 1.

# 24. Interpretation of the main parameters

## `phi_annual[1]`
Annual survival for badgers first captured as Cub/Yearling.

## `phi_annual[2]`
Annual survival for badgers first captured as Adult.

These remain entry-history comparisons rather than age-specific survival estimates.

## `sigma[1]`, `sigma[2]`
Spatial scale governing how rapidly capture probability declines as detector setts become more distant from the annual AC. Units are metres.

## `dmean[1]`, `dmean[2]`
Mean annual displacement of the latent activity centre. Units are metres per annual transition.

## `alpha_p`
Group-specific overall capture intercept on the logit scale. Because seasonal and period effects sum to zero, `alpha_p` is no longer tied to one arbitrary reference season or historical period.

## `beta_season`
Recurring seasonal deviations in capture probability constrained to sum to zero across the four seasons.

## `beta_period`
Broad historical deviations in capture probability constrained to sum to zero across temporal periods.

---

# 25. Important assumptions and limitations

## Annual AC stability
The four seasonal detections within a year are assumed to arise around one annual latent activity centre. This does not mean the animal is physically stationary; the AC represents the underlying centre of space use.

## Isotropic annual movement
The movement model currently gives every direction equal prior probability. It does not yet account for habitat, topography, social-group boundaries or other directional constraints.

## Exponential displacement kernel
The current annual movement-distance distribution is exponential. Later sensitivity analyses should compare heavier-tailed alternatives because long-distance dispersal can be under-observed near study boundaries.

## Unknown trapping effort
Seasonal and temporal-period effects absorb broad observation heterogeneity, but they cannot reconstruct true sett-by-season trapping effort.

## Detector availability
The current likelihood effectively treats all included sett detector locations as available throughout the analysed period. This is an approximation resulting from the absence of detector-specific historical effort data.

## First AC fixed at first capture
The first annual activity centre is fixed at the first observed detector. This stabilises the model but understates uncertainty in the first AC compared with a model that integrates over its possible location.

## Emigration is not yet explicitly identified
The annual AC can move away from the trapping array, but V1 does not yet define a formal outer state-space boundary and permanent-emigration process. Therefore survival should not yet be described as fully corrected true survival.

---

# 26. Planned model development

A sensible progression is:

```text
V1
Full-data annual AC + survival + spatial detection
+ sum-to-zero season + temporal-period detection

V2
Explicit outer spatial domain
+ stronger survival/emigration separation

V3
Alternative dispersal kernels
+ heavy-tail sensitivity

V4
Social-group boundary resistance

V5
Age-dependent survival

V6
Immigration / dispersal class

V7
bTB disease process
```

The order can be adjusted depending on computational behaviour and what the earlier stages reveal.

---

# 27. Summary

The current model is best viewed as a **conditional open spatial CMR model with a robust-design observation structure**.

Its core is:

\[
\boxed{
\text{annual survival}
+
\text{annual latent AC movement}
+
\text{four seasonal spatial observations}
}
\]

It improves on the social-group-only HMM because it keeps the actual sett coordinates and distinguishes the animal's underlying annual spatial centre from the particular sett where it was captured.

At the same time, the annual-primary / seasonal-secondary structure avoids treating every quarterly sett-to-sett observation as a literal movement of the underlying activity centre.

V1 is therefore intended as the stable spatial-demographic baseline from which explicit emigration, social structure, age, immigration and disease effects can be added sequentially.
