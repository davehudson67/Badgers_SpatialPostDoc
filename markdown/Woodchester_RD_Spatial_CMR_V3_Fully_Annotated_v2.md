# Woodchester Park badger spatial CMR — V3 fully annotated model

## Purpose of V3

V3 extends the current continuous-space robust-design spatial CMR model by adding an explicit landscape layer describing **valid habitat** and **social-group (SG) territory identity**.

The central biological idea is:

> Annual activity-centre movement is still governed primarily by continuous Euclidean distance, but a movement that finishes in a different social-group territory can receive an additional resistance penalty.

V3 therefore keeps the main statistical architecture of V2/M2 and adds the ecological structure that was present in the earlier landscape model, but using the newer exact sett coordinates and direct bivariate-normal movement model.

The model is best described at this stage as **V3a: continuous-space spatial CMR with habitat support and an SG endpoint-transition resistance term**.

This distinction matters because the SG term is currently introduced as a likelihood factor rather than being built into a fully normalized continuous-space transition density. That makes V3a a practical model for testing whether SG structure contains additional information after accounting for distance. If the SG effect is strongly supported, a later version could replace this with a formally normalized landscape-dependent movement kernel.

---

# 1. Model structure in words

For each badger, the model follows its history through annual primary periods. Within each year there are four seasonal secondary capture occasions.

For badger \(i\) in year \(k\):

1. The animal has a latent alive/dead state \(z_{ik}\).
2. If this is its first observed year, its activity centre \(\mathbf S_{ik}=(S^x_{ik},S^y_{ik})\) is estimated as a latent continuous location within the landscape state space.
3. In later years, its activity centre moves according to a bivariate normal movement kernel centred on the previous year's activity centre.
4. The continuous activity centre is mapped onto the 50 m GIS grid.
5. If the animal is alive, its activity centre must fall on valid terrestrial habitat.
6. The social-group identity at the new activity centre is compared with the social-group identity at the previous activity centre.
7. If the two annual activity centres are in different social-group territories, the transition receives an additional likelihood penalty controlled by \(\beta_{SG}\).
8. For each of the four seasonal trapping occasions within that year, capture probability depends on distance from the annual activity centre to every used sett detector, plus seasonal and broad temporal detection effects.
9. Survival is estimated between annual primary periods.

In schematic form:

```text
badger i
   |
   | first observed year k
   v
latent annual AC S[i,k]
   |
   +----> 50 m grid lookup ----> habitat / SG identity
   |
   +----> seasonal spatial detection at exact sett coordinates
   |
   v
annual survival
   |
   v
S[i,k+1] ~ bivariate normal around S[i,k]
   |
   +----> habitat validity
   +----> same SG vs different SG
   +----> seasonal spatial detection
   |
   v
next year ...
```

---

# 2. Biological groups

The current V3 model retains the same entry-history grouping used in M2:

```text
Group 1 = first captured as Cub or Yearling
Group 2 = first captured as Adult
```

These are **entry-history groups**, not true known-origin categories. In particular, a badger first captured as an adult is not automatically known to be an immigrant: it may have been locally present but previously uncaught.

For now, the following parameters are group-specific:

- annual survival \(\phi_g\);
- spatial detection scale \(\sigma_g\);
- annual movement scale \(\sigma_{move,g}\);
- baseline detection intercept \(\alpha_{p,g}\).

The SG resistance parameter is initially **shared across groups**. This is deliberate: V3 should first ask whether SG structure matters at all before adding group-specific SG effects.

---

# 3. Spatial state space

The spatial state space is a newly rebuilt 50 m grid created in QGIS.

The final grid contains:

- a 2 km peripheral buffer around the mapped core SG polygons;
- 20,460 cells;
- 124 rows × 165 columns;
- mapped SG IDs 1–22 inside the core;
- `SG_id = 999` outside mapped SG territories but within peripheral state space;
- `zone = 1` for core SG territory;
- `zone = 2` for peripheral space;
- `habitat = 1` for valid terrestrial habitat;
- `habitat = 0` for lake/water cells.

The grid is saved once as:

```r
data/spatial/V3_spatial_inputs_50m_2km.rds
```

The RDS contains the three matrices used by NIMBLE:

```text
SG_mat
habitat_mat
zone_mat
```

plus the true outer grid edges, cell size, dimensions and CRS.

A crucial implementation detail is that the original QGIS `row_index` and `col_index` are zero-based. The saved R object therefore uses:

```r
row_R = row_index + 1L
col_R = col_index + 1L
```

because R matrices are one-based.

The state-space edges must also represent the **outer edges of the cells**, not the bounding box of the centroid points. For 50 m cells:

```r
xmin <- min(centroid_x) - 25
xmax <- max(centroid_x) + 25
ymin <- min(centroid_y) - 25
ymax <- max(centroid_y) + 25
```

This avoids the half-cell offset that initially caused `OLDPONDDRAIN` to be assigned to the wrong habitat cell.

---

# 4. Survival model

Annual survival is group-specific:

\[
\text{logit}(\phi_g)=\alpha_{\phi,g}
\]

with:

\[
\alpha_{\phi,g}\sim N(\text{logit}(0.70),1.5^2).
\]

For an animal alive in year \(k-1\):

\[
z_{ik}\sim Bernoulli(z_{i,k-1}\phi_{g_i}).
\]

Known post-mortem information is used to force the alive/dead chronology where appropriate.

The parameter `phi_annual[g]` is therefore the annual survival probability for entry group \(g\), conditional on the model's spatial and observation processes.

---

# 5. Annual activity-centre movement

V3 retains the direct bivariate-normal movement model introduced in M2.

For later year \(k\):

\[
S^x_{ik}\sim N(S^x_{i,k-1},\sigma_{move,g_i}^2)
\]

and

\[
S^y_{ik}\sim N(S^y_{i,k-1},\sigma_{move,g_i}^2).
\]

The resulting radial displacement

\[
d_{ik}=\sqrt{(S^x_{ik}-S^x_{i,k-1})^2+(S^y_{ik}-S^y_{i,k-1})^2}
\]

has a Rayleigh distribution.

The mean radial displacement is:

\[
E(d)=\sigma_{move}\sqrt{\pi/2}.
\]

Therefore the model reports both:

```text
sigma_move[g] = SD of movement in each coordinate
mean_move[g]  = implied mean radial annual displacement
```

This avoids the older distance-plus-angle parameterisation (`d + theta`) while representing the same idea of an isotropic annual movement process.

---

# 6. Habitat constraint

Each continuous annual activity centre is translated into a row and column of the 50 m landscape matrix:

\[
col = \left\lfloor \frac{x-x_{min}}{50}\right\rfloor+1
\]

\[
row = \left\lfloor \frac{y_{max}-y}{50}\right\rfloor+1.
\]

The model then looks up:

```r
habitat_mat[row, col]
```

and

```r
SG_mat[row, col]
```

For living animals, V3 currently requires the activity centre to be:

1. inside the rectangular state space; and
2. in a cell with `habitat = 1`.

This is implemented using a Bernoulli pseudo-observation fixed at one:

\[
state\_ok_{ik}=1.
\]

For an alive animal:

\[
P(state\_ok=1)=I(inside)\times habitat.
\]

For a dead animal, the spatial constraint is switched off so that latent nuisance locations after death do not generate impossible habitat likelihoods.

This makes water genuinely unavailable as an annual activity-centre location in V3a.

---

# 7. Social-group resistance

The new ecological parameter is:

\[
\beta_{SG}\ge0.
\]

with prior:

\[
\beta_{SG}\sim Exponential(1).
\]

The model also calculates:

\[
M_{SG}=e^{-\beta_{SG}}.
\]

`sg_transition_multiplier` is **not a second fitted parameter**. It is a deterministic transformation of the single estimated parameter `beta_sg`:

\[
\text{sg\_transition\_multiplier}=e^{-\beta_{SG}}.
\]

Both are monitored only for convenience: `beta_sg` is the parameter used by the model, whereas `sg_transition_multiplier` expresses exactly the same posterior information on a more intuitive 0–1 scale.

The values below are therefore **examples of how different possible values of the one parameter `beta_sg` translate into the corresponding multiplier**; the model is not estimating four different multipliers.

```text
beta_sg = 0.0  -> exp(-0.0) = 1.00
beta_sg = 0.5  -> exp(-0.5) = 0.61
beta_sg = 1.0  -> exp(-1.0) = 0.37
beta_sg = 2.0  -> exp(-2.0) = 0.14
```

For example, if the posterior mean of `beta_sg` were 1.2, the corresponding multiplier would be `exp(-1.2) = 0.30`. A different-SG endpoint transition would then receive about 30% of the SG-related likelihood weight of a same-SG endpoint transition, conditional on the rest of the V3a model.

For successive annual activity centres:

```r
same_SG[i,k] <- equals(SG_here[i,k], SG_here[i,k-1])
```

If they have the same SG identity:

\[
P(SG\ factor)=1.
\]

If they have different SG identities:

\[
P(SG\ factor)=e^{-\beta_{SG}}.
\]

Thus, conditional on the underlying distance-based movement process, annual transitions ending in a different SG receive less likelihood support when \(\beta_{SG}>0\).

### Important interpretation

This parameter is best described as **resistance associated with an annual transition between different SG endpoint territories**.

It should **not** be described as a literal physical boundary-crossing probability, because we only know the annual AC endpoints. We do not observe the actual path taken between them.

### Important statistical caveat

This V3a term is an additional likelihood factor. It is not yet part of a movement density that has been explicitly normalized over every possible destination in the landscape.

Therefore V3a is primarily a development model for asking:

> Is there strong evidence that SG identity adds information beyond Euclidean movement distance?

If yes, a later version can build the SG effect into a properly normalized movement transition kernel.

---

# 8. Observation model

For each annual activity centre, the model calculates the distance to every used sett detector \(r\):

\[
D_{irk}=\|S_{ik}-X_r\|.
\]

Detection weight follows a half-normal function:

\[
g_{irk}=\exp\left(-\frac{D_{irk}^2}{2\sigma_{g_i}^2}\right).
\]

`G[i,k]` is the sum of these spatial weights across all used detectors.

Baseline seasonal capture probability is modelled on the logit scale:

\[
\text{logit}(p_{0,igjk})=
\alpha_{p,g_i}+\beta_{season,j}+\beta_{period,k}.
\]

Here:

- `alpha_p[g]` is group-specific baseline detectability;
- `beta_season[j]` captures the systematic difference among the four within-year trapping seasons;
- `beta_period` captures broad temporal variation in observation conditions using 5-year periods.

Because actual trapping effort is not explicitly available, these time effects should be interpreted as **temporal observation/detectability heterogeneity**, not as measured effort effects.

The seasonal and period effects are constrained to sum to zero, reducing confounding with the group-specific detection intercepts.

---

# 9. Encounter coding

The encounter array `H` has dimensions:

```text
individual × season × year
```

with:

```text
1       = not captured
2:R+1   = captured at detector 1:R
```

The code uses a competing-detector style likelihood. First, it estimates the probability of any capture in that season. Conditional on capture, the probability of the observed detector is proportional to its spatial detection weight.

This means an observed capture contributes both:

1. information that the badger was caught; and
2. information about **where** it was caught relative to its latent annual AC.

---

# 10. Why there are two individual loops

NIMBLE does not handle loops such as `for(k in (first+1):K)` safely when `K == first`, because that expression can generate an unintended decreasing sequence.

The individuals are therefore sorted by history length and split into:

```text
N[1] = number with K == first
N[2] = total number of individuals
```

The model then has two main individual loops.

### Loop 1 — single-primary histories

```r
for(i in 1:N[1]) {
    ...
}
```

These badgers have no later annual transition to model. The loop estimates:

- their first annual AC;
- habitat/SG location;
- their capture likelihood in that year.

There is no annual movement or later survival transition for these histories.

### Loop 2 — multi-primary histories

```r
for(i in (N[1]+1):N[2]) {
    ...
}
```

These individuals have at least one later primary period. For each one the model first estimates the initial AC and first-year observation likelihood, then enters:

```r
for(k in (first[i]+1):K[i]) {
    ...
}
```

which advances that badger through every subsequent annual primary period in its modelled history.

Within each annual iteration the model performs, in order:

```text
1. survival transition
2. activity-centre movement
3. GIS row/column conversion
4. habitat validation
5. SG endpoint comparison
6. distances to all detectors
7. four seasonal observation likelihoods
```

That annual loop is the core of V3.

---

# 11. Initial values

Because V3 has a hard land constraint, initial latent ACs must themselves be valid terrestrial locations.

The earlier M2 initialization used the mean of all capture coordinates in a year. That is unsafe for V3 because the mean of two valid sett locations can fall in a lake or otherwise invalid grid cell.

V3 should therefore initialize a captured year using an **actual observed sett coordinate** from that year.

For years with no observed capture, the previous valid AC is carried forward as the starting value.

This is only an MCMC initialization strategy. It does **not** fix the posterior AC to the observed sett.

The first AC remains stochastic:

```r
S[i,1,first[i]] ~ dunif(grid_xmin,grid_xmax)
S[i,2,first[i]] ~ dunif(grid_ymin,grid_ymax)
```

and later ACs remain stochastic movement states.

---

# 12. MCMC sampling

The current centred movement formulation creates strong posterior dependence between the latent AC coordinates and `sigma_move`.

The current V3 development version uses an `RW_block` sampler to update each annual `(x,y)` activity centre jointly:

```r
nodes <- c(
    paste0("S[",i,", 1, ",k,"]"),
    paste0("S[",i,", 2, ",k,"]")
)
```

This retains the same biological model while allowing X and Y to move together during MCMC.

The same caveat found in M2 remains: if `sigma_move` mixes poorly, the next computational experiment should be a non-centred movement parameterisation rather than continuing to tune the centred model indefinitely.

---

# 13. Complete annotated V3 code

The following is the current V3a code with the corrected grid-edge handling assumed to already be stored in `V3_spatial_inputs_50m_2km.rds`, corrected initial AC values based on actual observed sett locations, and without unnecessary explicit `dimensions` declarations for the dynamically indexed GIS matrices.

```r
# =============================================================================
# WOODCHESTER SPATIAL CMR V3a
# Continuous annual activity centres + habitat + social-group resistance
# =============================================================================

library(tidyverse)
library(lubridate)
library(nimble)
library(coda)
library(MCMCvis)

set.seed(123)

# =============================================================================
# 0. USER OPTIONS
# =============================================================================

# Use 200 for development. Set to NA_integer_ only when ready for the full data.
SAMPLE_N <- 200L

NITER <- 3000
NBURN <- 750
NCHAINS <- 2

cmr_file <- "data/badger_final_CMRready_wDisease.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
spatial_file <- "data/spatial/V3_spatial_inputs_50m_2km.rds"

dir.create("results", showWarnings = FALSE)

# =============================================================================
# 1. CLEAN SETT NAMES
# =============================================================================

sett_aliases <- c(
  "\\bCHESTNUT\\b"="CHESNUT", "\\bJACKS\\b"="JACKSMIREY",
  "\\bGRAVEL\\b"="GRAVELPIT", "\\bBUCKHOLE\\b"="BUCKHOLT",
  "\\bTOPSETT\\b"="TOP", "\\bFOXCUB\\b"="FOX",
  "\\bGULLEY\\b"="GULLY", "\\bBLACKBERRY\\b"="BRAMBLE",
  "\\bBOC\\b"="BOG", "\\bCEDARBANK\\b"="CEDAR",
  "\\bCLAYTRAP\\b"="CLAY", "\\bCLIFF\\b"="CLIFFFACE",
  "\\bDINGLEVALLEY\\b"="DINGLE"
)

clean_sett <- function(x) x %>% as.character() %>% toupper() %>%
  str_replace_all("[[:punct:]]", " ") %>% str_squish() %>%
  str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
  str_replace_all(sett_aliases) %>% str_replace_all("\\s+", "")

# =============================================================================
# 2. LOAD THE FIXED V3 LANDSCAPE OBJECT
# =============================================================================

# This RDS was generated from the final 50 m QGIS grid. It contains the complete
# rectangular SG/habitat/zone matrices and the TRUE outer edges of the grid.
sp <- readRDS(spatial_file)

SG_mat <- sp$SG_mat
habitat_mat <- sp$habitat_mat
zone_mat <- sp$zone_mat

grid_xmin <- sp$xmin
grid_xmax <- sp$xmax
grid_ymin <- sp$ymin
grid_ymax <- sp$ymax

cell_size <- sp$cell_size
n_rows <- sp$n_rows
n_cols <- sp$n_cols

stopifnot(
  !anyNA(SG_mat),
  !anyNA(habitat_mat),
  !anyNA(zone_mat),
  n_rows * n_cols == length(SG_mat)
)

cat("\nV3 grid:", n_rows, "x", n_cols, "@", cell_size,
    "m =", n_rows * n_cols, "cells\n")

# =============================================================================
# 3. LOAD EXACT SETT COORDINATES
# =============================================================================

sett_raw <- read_csv(sett_file, show_col_types = FALSE)

name_col <- intersect(c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name"), names(sett_raw))[1]
x_col <- intersect(c("SettX","sett_x","X","x","Easting","easting"), names(sett_raw))[1]
y_col <- intersect(c("SettY","sett_y","Y","y","Northing","northing"), names(sett_raw))[1]

if (any(is.na(c(name_col, x_col, y_col))))
  stop("Could not identify sett name/X/Y columns.")

sett_xy <- sett_raw %>%
  transmute(
    Sett_Clean = clean_sett(.data[[name_col]]),
    x = as.numeric(.data[[x_col]]),
    y = as.numeric(.data[[y_col]])
  ) %>%
  filter(!is.na(Sett_Clean), Sett_Clean != "", !is.na(x), !is.na(y)) %>%
  distinct(Sett_Clean, .keep_all = TRUE)

# =============================================================================
# 4. LOAD AND SPATIALLY CLEAN THE CAPTURE DATA
# =============================================================================

cmr_raw <- readRDS(cmr_file)

cmr <- cmr_raw %>%
  mutate(
    Sett_Clean = clean_sett(sett),
    primary_year = as.integer(primary_year),
    trap_season = as.integer(trap_season)
  ) %>%
  left_join(sett_xy, by = "Sett_Clean")

cat("\nLive captures without usable XY:\n")
print(
  cmr %>%
    filter(has_live_capture, is.na(x) | is.na(y)) %>%
    count(Sett_Clean, sort = TRUE),
  n = Inf
)

# Remove only LIVE observations that cannot be placed spatially. PM-only rows
# are retained because they still carry survival/death information.
cmr <- cmr %>%
  filter(!has_live_capture | (!is.na(x) & !is.na(y)))

# =============================================================================
# 5. PRIMARY YEARS AND BROAD DETECTION PERIODS
# =============================================================================

years <- min(cmr$primary_year, na.rm = TRUE):max(cmr$primary_year, na.rm = TRUE)
n_prim <- length(years)
n_sec <- 4L

cmr <- cmr %>%
  mutate(primary = match(primary_year, years))

# Five-year period effect used to absorb broad temporal detectability variation.
period_vec <- as.integer(
  match(
    floor(years / 5) * 5,
    sort(unique(floor(years / 5) * 5))
  )
)

n_periods <- max(period_vec)

# =============================================================================
# 6. ENTRY-HISTORY GROUP
# =============================================================================

demog <- cmr_raw %>%
  arrange(tattoo, capture_date) %>%
  group_by(tattoo) %>%
  summarise(
    age_fc = {
      a <- na.omit(age_fc)
      if (length(a)) as.character(a[1]) else NA_character_
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

# =============================================================================
# 7. ONE OBSERVED CAPTURE LOCATION PER SECONDARY OCCASION
# =============================================================================

# The annual AC is latent. The four seasonal observations within each year are
# the robust-design-like secondary capture occasions. If multiple captures occur
# in the same badger x year x season, retain the latest one.
live <- cmr %>%
  filter(
    has_live_capture,
    !is.na(primary),
    !is.na(trap_season),
    !is.na(x),
    !is.na(y)
  ) %>%
  arrange(tattoo, primary, trap_season, capture_date) %>%
  group_by(tattoo, primary, trap_season) %>%
  slice_tail(n = 1) %>%
  ungroup()

# =============================================================================
# 8. ELIGIBLE INDIVIDUALS
# =============================================================================

eligible <- live %>%
  distinct(tattoo) %>%
  inner_join(demog, by = "tattoo") %>%
  filter(entry_group %in% 1:2, !tattoo %in% "007V")

if (!is.na(SAMPLE_N) && SAMPLE_N < nrow(eligible))
  eligible <- eligible %>% slice_sample(n = SAMPLE_N)

ids <- eligible$tattoo
nind <- length(ids)

live <- live %>% filter(tattoo %in% ids)
cmr <- cmr %>% filter(tattoo %in% ids)

cat("\nBadgers used:", nind, "\n")
print(count(eligible, entry_group))

# =============================================================================
# 9. BUILD THE EXACT-SETT DETECTOR ARRAY
# =============================================================================

# Every actually used sett with known coordinates becomes a spatial detector.
detectors <- live %>%
  distinct(Sett_Clean, x, y) %>%
  arrange(Sett_Clean) %>%
  mutate(detector = row_number())

X <- as.matrix(detectors %>% select(x, y))
R <- nrow(X)

live <- live %>%
  left_join(detectors %>% select(Sett_Clean, detector), by = "Sett_Clean")

# =============================================================================
# 10. AUDIT USED DETECTORS AGAINST THE NEW LANDSCAPE
# =============================================================================

# Convert every used sett coordinate into the same 1-based R grid indices used
# by SG_mat/habitat_mat/zone_mat.
det_audit <- detectors %>%
  mutate(
    col_R = floor((x - grid_xmin) / cell_size) + 1L,
    row_R = floor((grid_ymax - y) / cell_size) + 1L,
    in_bounds = col_R >= 1 & col_R <= n_cols & row_R >= 1 & row_R <= n_rows
  )

if (any(!det_audit$in_bounds)) {
  print(det_audit %>% filter(!in_bounds), n = Inf)
  stop("At least one USED detector lies outside V3 grid.")
}

det_audit <- det_audit %>%
  mutate(
    SG = SG_mat[cbind(row_R, col_R)],
    habitat = habitat_mat[cbind(row_R, col_R)],
    zone = zone_mat[cbind(row_R, col_R)]
  )

cat("\nDetector-grid audit:\n")
print(count(det_audit, zone, habitat, SG, sort = TRUE), n = Inf)

if (any(det_audit$habitat != 1L)) {
  print(det_audit %>% filter(habitat != 1L), n = Inf)
  stop("At least one USED detector falls in habitat = 0. Resolve before modelling.")
}

# =============================================================================
# 11. INDIVIDUAL METADATA
# =============================================================================

meta <- live %>%
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

first <- as.integer(meta$first)
first_detector <- as.integer(meta$first_detector)
entry_group <- as.integer(meta$entry_group)

stopifnot(!anyNA(first), !anyNA(first_detector), !anyNA(entry_group))

# =============================================================================
# 12. KNOWN DEATH INFORMATION
# =============================================================================

death <- cmr %>%
  filter(has_pm_record, !is.na(primary)) %>%
  group_by(tattoo) %>%
  summarise(
    death_primary = min(primary),
    death_season = {
      q <- trap_season[primary == min(primary)]
      q <- q[!is.na(q)]
      if (length(q)) min(q) else NA_integer_
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

# K defines the final primary period included in the individual history.
K <- rep(n_prim, nind)
K[known_death] <- pmin(n_prim, death_primary[known_death] + 1L)

# =============================================================================
# 13. ENCOUNTER ARRAY H
# =============================================================================

# H = 1 means not captured.
# H = detector + 1 means captured at that exact spatial detector.
H <- array(1L, dim = c(nind, n_sec, n_prim))

for (r in seq_len(nrow(live))) {
  i <- match(live$tattoo[r], ids)
  H[i, live$trap_season[r], live$primary[r]] <- live$detector[r] + 1L
}

# J gives the number of secondary occasions to use in each primary year.
J <- matrix(n_sec, nrow = nind, ncol = n_prim)

for (i in seq_len(nind)) {
  if (known_death[i] && !is.na(death_season[i]) && death_primary[i] <= n_prim)
    J[i, death_primary[i]] <- max(1L, death_season[i])
}

# =============================================================================
# 14. KNOWN ALIVE / DEAD STATE DATA
# =============================================================================

z_data <- matrix(NA_integer_, nrow = nind, ncol = n_prim)

for (i in seq_len(nind)) {
  captured_years <- unique(live$primary[live$tattoo == ids[i]])
  z_data[i, captured_years] <- 1L

  if (known_death[i]) {
    # Alive in the year in which death was recorded.
    z_data[i, death_primary[i]] <- 1L

    # Definitely dead thereafter.
    if (death_primary[i] < n_prim)
      z_data[i, (death_primary[i] + 1L):n_prim] <- 0L
  }
}

# =============================================================================
# 15. SORT HISTORIES FOR SAFE NIMBLE LOOPS
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

if (any(K < first)) stop("ERROR: K < first.")
if (any(death_primary < first & death_primary <= n_prim))
  stop("ERROR: known death before first spatial capture.")
if (N[1] == 0L || N[1] == N[2])
  stop("Current compact loops require both single- and multi-primary histories.")

# =============================================================================
# 16. INITIAL VALUES
# =============================================================================

make_inits <- function(chain = 1L) {

  z_init <- matrix(0L, nrow = nind, ncol = n_prim)
  S_init <- array(NA_real_, dim = c(nind, 2, n_prim))

  for (i in seq_len(nind)) {

    # IMPORTANT FOR V3:
    # Use an ACTUAL observed sett location in every captured year rather than
    # the annual mean XY. An average of two valid setts can fall in a lake cell.
    d <- live %>%
      filter(tattoo == ids[i]) %>%
      arrange(primary, trap_season, capture_date) %>%
      group_by(primary) %>%
      slice(1) %>%
      ungroup() %>%
      select(primary, x, y)

    xy <- matrix(NA_real_, nrow = n_prim, ncol = 2)

    for (k in first[i]:K[i]) {
      dk <- d %>% filter(primary == k)

      if (nrow(dk)) {
        xy[k, ] <- c(dk$x[1], dk$y[1])
      } else if (k > first[i]) {
        # Carry the previous valid location forward purely as an initial value.
        xy[k, ] <- xy[k - 1, ]
      }
    }

    S_init[i, , first[i]:K[i]] <- t(xy[first[i]:K[i], , drop = FALSE])
    z_init[i, first[i]:K[i]] <- 1L
  }

  # Known z values are data in NIMBLE and must therefore be NA in the inits.
  z_init[!is.na(z_data)] <- NA

  list(
    alpha_phi = c(qlogis(.70), qlogis(.68)) + rnorm(2, 0, .03),
    alpha_p = c(qlogis(.20), qlogis(.20)) + rnorm(2, 0, .03),
    alpha_logsigma = log(c(150, 120)) + rnorm(2, 0, .03),
    alpha_logmove = log(c(70, 50)) + rnorm(2, 0, .03),
    beta_season_raw = rnorm(3, 0, .03),
    beta_period_raw = rnorm(n_periods - 1L, 0, .03),
    beta_sg = .5 + runif(1, -.05, .05),
    S = S_init,
    z = z_init
  )
}

inits <- lapply(seq_len(NCHAINS), make_inits)

# =============================================================================
# 17. NIMBLE MODEL
# =============================================================================

code_V3 <- nimbleCode({

  # ---------------------------------------------------------------------------
  # 17a. GROUP-SPECIFIC POPULATION PARAMETERS
  # ---------------------------------------------------------------------------

  for (grp in 1:2) {

    alpha_phi[grp] ~ dnorm(qlogis(.70), sd = 1.5)
    phi_annual[grp] <- ilogit(alpha_phi[grp])

    alpha_p[grp] ~ dnorm(qlogis(.15), sd = 1.5)

    alpha_logsigma[grp] ~ dnorm(log(250), sd = 1)
    sigma[grp] <- exp(alpha_logsigma[grp])

    alpha_logmove[grp] ~ dnorm(log(100), sd = 1)
    sigma_move[grp] <- exp(alpha_logmove[grp])
    mean_move[grp] <- sigma_move[grp] * sqrt(3.141593 / 2)
  }

  # ---------------------------------------------------------------------------
  # 17b. SHARED SOCIAL-GROUP RESISTANCE
  # ---------------------------------------------------------------------------

  beta_sg ~ dexp(1)
  sg_transition_multiplier <- exp(-beta_sg)

  # ---------------------------------------------------------------------------
  # 17c. SUM-TO-ZERO SEASONAL DETECTION EFFECTS
  # ---------------------------------------------------------------------------

  for (s in 1:3) {
    beta_season_raw[s] ~ dnorm(0, sd = 1)
    beta_season[s] <- beta_season_raw[s]
  }

  beta_season[4] <- -sum(beta_season_raw[1:3])

  # ---------------------------------------------------------------------------
  # 17d. SUM-TO-ZERO BROAD TEMPORAL DETECTION EFFECTS
  # ---------------------------------------------------------------------------

  for (p in 1:(n_periods - 1)) {
    beta_period_raw[p] ~ dnorm(0, sd = 1)
    beta_period[p] <- beta_period_raw[p]
  }

  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods - 1)])

  # ==========================================================================
  # 17e. LOOP 1: BADGERS WITH ONLY ONE PRIMARY PERIOD
  # ==========================================================================

  for (i in 1:N[1]) {

    # The animal is known alive at first spatial capture.
    z[i, first[i]] ~ dbern(1)

    # The first annual activity centre is latent over the complete rectangle.
    S[i, 1, first[i]] ~ dunif(grid_xmin, grid_xmax)
    S[i, 2, first[i]] ~ dunif(grid_ymin, grid_ymax)

    # Convert continuous BNG metre coordinates into 1-based 50 m matrix indices.
    col_raw[i, first[i]] <- trunc((S[i, 1, first[i]] - grid_xmin) / cell_size) + 1
    row_raw[i, first[i]] <- trunc((grid_ymax - S[i, 2, first[i]]) / cell_size) + 1

    # Clamp the lookup index so that NIMBLE never attempts an illegal matrix
    # index. `in_bounds` below separately records whether the AC is genuinely
    # inside the state space.
    col_S[i, first[i]] <- max(1, min(n_cols, col_raw[i, first[i]]))
    row_S[i, first[i]] <- max(1, min(n_rows, row_raw[i, first[i]]))

    in_bounds[i, first[i]] <-
      step(S[i, 1, first[i]] - grid_xmin) *
      step(grid_xmax - S[i, 1, first[i]]) *
      step(S[i, 2, first[i]] - grid_ymin) *
      step(grid_ymax - S[i, 2, first[i]])

    habitat_here[i, first[i]] <- habitat_mat[row_S[i, first[i]], col_S[i, first[i]]]
    SG_here[i, first[i]] <- SG_mat[row_S[i, first[i]], col_S[i, first[i]]]

    # state_ok is observed as 1. Therefore the latent first AC must be both
    # inside the state space and in habitat = 1.
    state_ok[i, first[i]] ~
      dbern(in_bounds[i, first[i]] * habitat_here[i, first[i]])

    # Spatial detection weights for this annual AC.
    g[i, first[i], 1] <- 0

    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(
        pow(S[i, 1, first[i]] - X[r, 1], 2) +
        pow(S[i, 2, first[i]] - X[r, 2], 2)
      )

      g[i, first[i], r + 1] <-
        exp(-pow(D[i, r, first[i]], 2) /
            (2 * pow(sigma[entry_group[i]], 2)))
    }

    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])

    # Four seasonal secondary occasions within this annual primary period.
    for (j in 1:J[i, first[i]]) {

      lp0[i, j, first[i]] <-
        alpha_p[entry_group[i]] +
        beta_season[j] +
        beta_period[period_vec[first[i]]]

      p0[i, j, first[i]] <- ilogit(lp0[i, j, first[i]])
      lambda0[i, j, first[i]] <- -log(1 - p0[i, j, first[i]])

      # Probability of at least one spatial capture during this season.
      P[i, j, first[i]] <-
        1 - exp(-lambda0[i, j, first[i]] * G[i, first[i]])

      # If captured, probability is divided among detectors in proportion to g.
      # If not captured, likelihood contribution is 1 - P.
      captureProb[i, j, first[i]] <-
        step(H[i, j, first[i]] - 2) *
        (g[i, first[i], H[i, j, first[i]]] / (G[i, first[i]] + 1e-10)) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) *
        (1 - P[i, j, first[i]])

      Ones[i, j, first[i]] ~ dbern(captureProb[i, j, first[i]])
    }
  }

  # ==========================================================================
  # 17f. LOOP 2: BADGERS WITH AT LEAST ONE LATER PRIMARY PERIOD
  # ==========================================================================

  for (i in (N[1] + 1):N[2]) {

    # -------------------- FIRST OBSERVED YEAR ---------------------------------

    z[i, first[i]] ~ dbern(1)

    S[i, 1, first[i]] ~ dunif(grid_xmin, grid_xmax)
    S[i, 2, first[i]] ~ dunif(grid_ymin, grid_ymax)

    col_raw[i, first[i]] <- trunc((S[i, 1, first[i]] - grid_xmin) / cell_size) + 1
    row_raw[i, first[i]] <- trunc((grid_ymax - S[i, 2, first[i]]) / cell_size) + 1
    col_S[i, first[i]] <- max(1, min(n_cols, col_raw[i, first[i]]))
    row_S[i, first[i]] <- max(1, min(n_rows, row_raw[i, first[i]]))

    in_bounds[i, first[i]] <-
      step(S[i, 1, first[i]] - grid_xmin) *
      step(grid_xmax - S[i, 1, first[i]]) *
      step(S[i, 2, first[i]] - grid_ymin) *
      step(grid_ymax - S[i, 2, first[i]])

    habitat_here[i, first[i]] <- habitat_mat[row_S[i, first[i]], col_S[i, first[i]]]
    SG_here[i, first[i]] <- SG_mat[row_S[i, first[i]], col_S[i, first[i]]]

    state_ok[i, first[i]] ~
      dbern(in_bounds[i, first[i]] * habitat_here[i, first[i]])

    g[i, first[i], 1] <- 0

    for (r in 1:R) {
      D[i, r, first[i]] <- sqrt(
        pow(S[i, 1, first[i]] - X[r, 1], 2) +
        pow(S[i, 2, first[i]] - X[r, 2], 2)
      )

      g[i, first[i], r + 1] <-
        exp(-pow(D[i, r, first[i]], 2) /
            (2 * pow(sigma[entry_group[i]], 2)))
    }

    G[i, first[i]] <- sum(g[i, first[i], 1:(R + 1)])

    for (j in 1:J[i, first[i]]) {
      lp0[i, j, first[i]] <-
        alpha_p[entry_group[i]] +
        beta_season[j] +
        beta_period[period_vec[first[i]]]

      p0[i, j, first[i]] <- ilogit(lp0[i, j, first[i]])
      lambda0[i, j, first[i]] <- -log(1 - p0[i, j, first[i]])
      P[i, j, first[i]] <- 1 - exp(-lambda0[i, j, first[i]] * G[i, first[i]])

      captureProb[i, j, first[i]] <-
        step(H[i, j, first[i]] - 2) *
        (g[i, first[i], H[i, j, first[i]]] / (G[i, first[i]] + 1e-10)) *
        P[i, j, first[i]] +
        (1 - step(H[i, j, first[i]] - 2)) *
        (1 - P[i, j, first[i]])

      Ones[i, j, first[i]] ~ dbern(captureProb[i, j, first[i]])
    }

    # ========================================================================
    # ANNUAL LOOP: ADVANCE THIS INDIVIDUAL THROUGH ALL LATER PRIMARY PERIODS
    # ========================================================================

    for (k in (first[i] + 1):K[i]) {

      # ----------------------------------------------------------------------
      # A. SURVIVAL
      # ----------------------------------------------------------------------

      Palive[i, k - 1] <- z[i, k - 1] * phi_annual[entry_group[i]]

      z[i, k] ~
        dbern(Palive[i, k - 1] * step(death_primary[i] - k))

      # ----------------------------------------------------------------------
      # B. CONTINUOUS ANNUAL ACTIVITY-CENTRE MOVEMENT
      # ----------------------------------------------------------------------

      S[i, 1, k] ~
        dnorm(S[i, 1, k - 1], sd = sigma_move[entry_group[i]])

      S[i, 2, k] ~
        dnorm(S[i, 2, k - 1], sd = sigma_move[entry_group[i]])

      moveDist[i, k - 1] <- sqrt(
        pow(S[i, 1, k] - S[i, 1, k - 1], 2) +
        pow(S[i, 2, k] - S[i, 2, k - 1], 2)
      )

      # ----------------------------------------------------------------------
      # C. CONVERT CONTINUOUS COORDINATES TO THE 50 m GIS GRID
      # ----------------------------------------------------------------------

      col_raw[i, k] <- trunc((S[i, 1, k] - grid_xmin) / cell_size) + 1
      row_raw[i, k] <- trunc((grid_ymax - S[i, 2, k]) / cell_size) + 1

      col_S[i, k] <- max(1, min(n_cols, col_raw[i, k]))
      row_S[i, k] <- max(1, min(n_rows, row_raw[i, k]))

      in_bounds[i, k] <-
        step(S[i, 1, k] - grid_xmin) *
        step(grid_xmax - S[i, 1, k]) *
        step(S[i, 2, k] - grid_ymin) *
        step(grid_ymax - S[i, 2, k])

      habitat_here[i, k] <- habitat_mat[row_S[i, k], col_S[i, k]]
      SG_here[i, k] <- SG_mat[row_S[i, k], col_S[i, k]]

      # ----------------------------------------------------------------------
      # D. HABITAT / STATE-SPACE CONSTRAINT
      # ----------------------------------------------------------------------

      valid_state[i, k] <- in_bounds[i, k] * habitat_here[i, k]

      # z = 1 -> valid_state must equal 1.
      # z = 0 -> probability becomes 1 and the spatial constraint disappears.
      state_prob[i, k] <-
        (1 - z[i, k]) + z[i, k] * valid_state[i, k]

      state_ok[i, k] ~ dbern(state_prob[i, k])

      # ----------------------------------------------------------------------
      # E. SOCIAL-GROUP ENDPOINT RESISTANCE
      # ----------------------------------------------------------------------

      same_SG[i, k] <-
        equals(SG_here[i, k], SG_here[i, k - 1])

      sg_live_prob[i, k] <-
        same_SG[i, k] +
        (1 - same_SG[i, k]) * sg_transition_multiplier

      # Again, switch the ecological movement penalty off if z = 0.
      sg_prob[i, k] <-
        (1 - z[i, k]) + z[i, k] * sg_live_prob[i, k]

      sg_ok[i, k] ~ dbern(sg_prob[i, k])

      # ----------------------------------------------------------------------
      # F. DISTANCE FROM CURRENT AC TO EVERY EXACT SETT DETECTOR
      # ----------------------------------------------------------------------

      g[i, k, 1] <- 0

      for (r in 1:R) {
        D[i, r, k] <- sqrt(
          pow(S[i, 1, k] - X[r, 1], 2) +
          pow(S[i, 2, k] - X[r, 2], 2)
        )

        g[i, k, r + 1] <-
          exp(-pow(D[i, r, k], 2) /
              (2 * pow(sigma[entry_group[i]], 2)))
      }

      G[i, k] <- sum(g[i, k, 1:(R + 1)])

      # ----------------------------------------------------------------------
      # G. FOUR WITHIN-YEAR SEASONAL OBSERVATIONS
      # ----------------------------------------------------------------------

      for (j in 1:J[i, k]) {

        lp0[i, j, k] <-
          alpha_p[entry_group[i]] +
          beta_season[j] +
          beta_period[period_vec[k]]

        p0[i, j, k] <- ilogit(lp0[i, j, k])
        lambda0[i, j, k] <- -log(1 - p0[i, j, k])

        # z switches capture probability to zero when the badger is dead.
        P[i, j, k] <-
          (1 - exp(-lambda0[i, j, k] * G[i, k])) * z[i, k]

        captureProb[i, j, k] <-
          step(H[i, j, k] - 2) *
          (g[i, k, H[i, j, k]] / (G[i, k] + 1e-10)) *
          P[i, j, k] +
          (1 - step(H[i, j, k] - 2)) *
          (1 - P[i, j, k])

        Ones[i, j, k] ~ dbern(captureProb[i, j, k])
      }
    }
  }
})

# =============================================================================
# 18. CONSTANTS AND DATA
# =============================================================================

consts <- list(
  R = R,
  N = N,
  K = as.integer(K),
  J = J,
  first = as.integer(first),
  X = X,
  H = H,
  n_periods = n_periods,
  period_vec = period_vec,
  entry_group = entry_group,
  death_primary = death_primary,
  grid_xmin = grid_xmin,
  grid_xmax = grid_xmax,
  grid_ymin = grid_ymin,
  grid_ymax = grid_ymax,
  cell_size = cell_size,
  n_rows = n_rows,
  n_cols = n_cols
)

# `state_ok` and `sg_ok` are pseudo-observations fixed to 1.
# The full habitat/SG matrices are supplied as data because they are dynamically
# indexed by the latent activity-centre locations.
data_list <- list(
  Ones = array(1L, dim(H)),
  z = z_data,
  state_ok = matrix(1L, nrow = nind, ncol = n_prim),
  sg_ok = matrix(1L, nrow = nind, ncol = n_prim),
  habitat_mat = habitat_mat,
  SG_mat = SG_mat
)

# =============================================================================
# 19. BUILD AND CHECK THE MODEL
# =============================================================================

message("\nBuilding V3...")

model_V3 <- nimbleModel(
  code_V3,
  constants = consts,
  data = data_list,
  inits = inits[[1]],
  dimensions = list(
    Ones = dim(H),
    z = dim(z_data),
    state_ok = c(nind, n_prim),
    sg_ok = c(nind, n_prim)
  ),
  check = TRUE,
  calculate = FALSE
)

# Some unused array elements outside first[i]:K[i] can remain uninitialized.
# This is not automatically a model failure. The important check is whether the
# full active graph has a finite initial log probability.
print(model_V3$initializeInfo())

lp <- model_V3$calculate()
cat("\nInitial log probability:", lp, "\n")

if (!is.finite(lp))
  stop("V3 initial log probability is not finite.")

# =============================================================================
# 20. COMPILE MODEL
# =============================================================================

message("\nCompiling model...")
cModel_V3 <- compileNimble(model_V3, resetFunctions = TRUE)

# =============================================================================
# 21. CONFIGURE MCMC
# =============================================================================

monitors <- c(
  "phi_annual",
  "sigma_move",
  "mean_move",
  "sigma",
  "alpha_p",
  "beta_season",
  "beta_period",
  "beta_sg",
  "sg_transition_multiplier"
)

config_V3 <- configureMCMC(model_V3, monitors = monitors, thin = 1)

# Replace separate scalar RW samplers for Sx and Sy with a joint two-dimensional
# block sampler for each annual activity centre.
for (i in seq_len(nind)) {
  for (k in first[i]:K[i]) {
    nodes <- c(
      paste0("S[", i, ", 1, ", k, "]"),
      paste0("S[", i, ", 2, ", k, "]")
    )

    config_V3$removeSamplers(nodes, print = FALSE)
    config_V3$addSampler(target = nodes, type = "RW_block")
  }
}

Rmcmc_V3 <- buildMCMC(config_V3)

# =============================================================================
# 22. COMPILE MCMC
# =============================================================================

message("\nCompiling MCMC...")

cMCMC_V3 <- compileNimble(
  Rmcmc_V3,
  project = cModel_V3,
  resetFunctions = TRUE
)

# =============================================================================
# 23. DEVELOPMENT RUN
# =============================================================================

message("\nRunning V3 development model...")

runtime_V3 <- system.time({
  samples_V3 <- runMCMC(
    cMCMC_V3,
    niter = NITER,
    nburnin = NBURN,
    nchains = NCHAINS,
    inits = inits,
    samplesAsCodaMCMC = TRUE,
    progressBar = TRUE,
    setSeed = 3451:(3451 + NCHAINS - 1L)
  )
})

print(runtime_V3)

# =============================================================================
# 24. SAVE RESULTS
# =============================================================================

saveRDS(
  list(
    samples = samples_V3,
    runtime = runtime_V3,
    ids = ids,
    detectors = detectors,
    det_audit = det_audit,
    settings = list(
      sample_n = SAMPLE_N,
      niter = NITER,
      nburn = NBURN,
      nchains = NCHAINS
    ),
    spatial_file = spatial_file
  ),
  paste0("results/RD_SCR_V3_hybrid_", nind, "_badgers.rds")
)

# =============================================================================
# 25. BASIC MCMC DIAGNOSTICS
# =============================================================================

MCMCsummary(samples_V3)
gelman.diag(samples_V3, multivariate = FALSE)
effectiveSize(samples_V3)
```

---

# 14. Parameter interpretation table

| Parameter | Meaning | Scale / interpretation |
|---|---|---|
| `phi_annual[1]` | Annual survival, first-caught-young group | probability 0–1 |
| `phi_annual[2]` | Annual survival, first-caught-adult group | probability 0–1 |
| `sigma_move[g]` | SD of annual movement separately in X and Y | metres |
| `mean_move[g]` | Implied mean annual radial AC displacement | metres |
| `sigma[g]` | Half-normal spatial detection scale | metres; not automatically home-range size |
| `alpha_p[g]` | Group-specific baseline detection intercept | logit scale |
| `beta_season[j]` | Within-year seasonal detection effect | logit scale; sum-to-zero |
| `beta_period[p]` | Broad temporal detection heterogeneity | logit scale; sum-to-zero |
| `beta_sg` | Resistance associated with different-SG annual endpoints | non-negative |
| `sg_transition_multiplier` | Relative SG factor for a different-SG endpoint | `exp(-beta_sg)`, 0–1 |

---

# 15. What V3 changes relative to M2

V3 is intentionally a small ecological extension of M2.

### Retained unchanged

- exact sett detector coordinates;
- annual latent continuous ACs;
- latent first AC;
- BVN/Rayleigh movement;
- group-specific annual survival;
- group-specific movement scale;
- group-specific spatial detection scale;
- four seasonal secondary occasions;
- seasonal detection effects;
- broad temporal detection effects;
- known-death constraints;
- current entry-history groups.

### Added in V3

- explicit 50 m state-space grid;
- valid-land constraint;
- mapped SG identity at every annual AC;
- explicit peripheral `SG_id = 999` area;
- shared SG endpoint-transition resistance parameter.

### Deliberately not added yet

- age as a time-varying survival covariate;
- bTB disease state;
- sex effects;
- habitat preference covariates;
- separate core-to-periphery emigration parameter;
- group-specific SG resistance;
- alternative detection kernels;
- heavy-tailed movement kernel;
- fully normalized SG-dependent movement kernel.

This staged approach is important because otherwise any difference from M2 would be impossible to attribute to a particular ecological addition.

---

# 16. What V3 can and cannot tell us

## It can estimate

- annual survival by entry-history group;
- annual continuous-space movement scale by group;
- spatial capture scale by group;
- broad temporal and seasonal detection differences;
- whether different-SG annual AC endpoints are disfavoured beyond the baseline Euclidean movement kernel.

## It cannot yet cleanly estimate

- literal path-based boundary crossing;
- a separate emigration probability;
- immigration status of first-caught adults;
- age-specific survival;
- disease effects;
- true habitat-selection coefficients;
- a mechanistically normalized landscape transition probability.

The peripheral state space is nevertheless useful because it provides valid habitat outside the mapped core rather than making the detector footprint itself an artificial biological boundary.

---

# 17. Immediate diagnostics for a successful V3 development run

Before interpreting biology, check:

```text
1. Initial model log probability is finite.
2. No used detector is outside the grid.
3. No used detector is assigned habitat = 0.
4. phi_annual has satisfactory Rhat and ESS.
5. sigma_move / mean_move have satisfactory Rhat and ESS.
6. sigma has satisfactory Rhat and ESS.
7. beta_sg is not stuck at its prior boundary.
8. sg_transition_multiplier is sampled across both chains.
```

The main new ecological quantity to inspect is:

```r
sg_transition_multiplier
```

rather than looking only at `beta_sg`, because the multiplier has the more intuitive interpretation:

> relative likelihood factor assigned to a transition whose annual endpoint lies in a different SG.

---

# 18. Recommended progression after V3a

If V3a runs well and the SG effect is supported, the next technical question is not simply to add more covariates. It is whether to formalize the movement model as a **normalized landscape-dependent transition kernel**.

A possible later formulation would be proportional to:

\[
K(\mathbf s_k\mid\mathbf s_{k-1})\propto
\exp\left[-\frac{\|\mathbf s_k-\mathbf s_{k-1}\|^2}{2\sigma_{move}^2}
-\beta_{SG}I(SG_k\ne SG_{k-1})\right]
\]

with normalization over the valid state space.

That would make the SG effect an explicit part of the movement transition distribution rather than an auxiliary likelihood factor. The computational cost is substantially higher, so V3a is intended to establish whether that additional complexity is justified.

After the spatial architecture is settled, age/origin and disease can then be added to the best-supported spatial model rather than being confounded with unresolved movement structure.

---

# 19. Short model description suitable for methods notes

A concise description of V3 is:

> We fitted a robust-design-like spatial capture–recapture model in which each individual had an annual latent continuous activity centre and up to four within-year seasonal capture observations. Annual activity-centre displacement followed an isotropic bivariate normal transition, yielding a Rayleigh distribution of radial displacement. Capture probability declined with Euclidean distance between the activity centre and exact sett detector coordinates according to a half-normal spatial detection function, while seasonal and broad temporal effects accommodated variation in detectability. Continuous activity centres were linked to a 50 m GIS state-space grid containing terrestrial habitat, mapped social-group territories and a peripheral buffer. Living activity centres were constrained to valid terrestrial habitat. In addition, annual transitions whose endpoint occurred in a different social-group territory received a multiplicative resistance term, allowing us to test whether social-group structure explained movement beyond Euclidean distance alone. Annual survival, movement scale, detection scale and baseline detectability were estimated separately for badgers first captured as cubs/yearlings versus adults.

---

# 20. Literature lineage of the V3 model

V3 is not copied from a single published model. It combines several established ideas from the spatial capture–recapture, robust-design, dispersal and landscape-connectivity literature with a Woodchester-specific social-group component. Some pieces closely follow published model structures, whereas the current `beta_sg` endpoint-resistance factor is a pragmatic development step rather than a likelihood copied directly from one paper.

## 20.1 Ergon & Gardner (2014): the main structural ancestor

**Ergon, T. & Gardner, B. (2014). Separating mortality and emigration: modelling space use, dispersal and survival with robust-design spatial capture–recapture data. Methods in Ecology and Evolution.**

[Read the paper / DOI](https://doi.org/10.1111/2041-210X.12133)

This is the closest conceptual ancestor of the Woodchester model. Their robust-design SCR framework combines spatial capture probabilities within primary periods, latent individual activity centres, movement/dispersal of activity centres between primary periods, survival between primary periods, and repeated secondary observations within primary periods.

That is the basic logic behind:

```text
annual latent activity centre
        +
within-year spatial detections
        +
movement between years
        +
survival between years
```

Our implementation differs in details, including the four seasonal secondary periods spread through the year, exact sett detectors, entry-history grouping, known-death constraints and SG/habitat additions.

## 20.2 Schaub & Royle (2014): survival versus emigration

**Schaub, M. & Royle, J. A. (2014). Estimating true instead of apparent survival using spatial Cormack–Jolly–Seber models. Methods in Ecology and Evolution.**

[Read the paper / DOI](https://doi.org/10.1111/2041-210X.12134)

This is central to the biological motivation. Conventional CMR survival can confound mortality with permanent emigration. Spatial models that explicitly represent movement can, when the spatial process is sufficiently identifiable, help separate these processes.

This is why V3 state-space extent and the movement kernel are substantive modelling decisions rather than merely GIS choices.

## 20.3 Turek et al. (2021): efficient large-scale SCR implementation

**Turek, D. et al. (2021). Efficient estimation of large-scale spatial capture–recapture models. Ecosphere.**

[Read the paper / DOI](https://doi.org/10.1002/ecs2.3385)

This paper is especially relevant to our NIMBLE implementation. It includes an Ergon–Gardner-style vole model with survival between primary occasions, activity-centre dispersal between primary occasions and spatial capture.

Relevant ideas include direct modelling of successive bivariate activity-centre coordinates, avoiding unnecessary latent distance/angle variables, MCMC customization and other computational strategies for large SCR models.

## 20.4 Efford (2022): review of movement models in open-population capture–recapture

**Efford, M. G. (2022). A review of movement models in open population capture–recapture. Methods in Ecology and Evolution.**

[Read the paper / DOI](https://doi.org/10.1111/2041-210X.13947)

This provides a useful overview of activity-centre movement, dispersal and other movement formulations in open-population capture–recapture models. It is useful for interpreting what `sigma_move` represents and for thinking about alternative movement kernels.

## 20.5 Dupont, Linden & Sutherland (2022): landscape connectivity and movement

**Dupont, G., Linden, D. W. & Sutherland, C. (2022). Improved inferences about landscape connectivity from spatial capture–recapture by integration of a movement model. Ecology.**

[Read the paper / DOI](https://doi.org/10.1002/ecy.3544)

This is one of the most relevant papers for the future development of V3. It integrates an explicit movement model with SCR so that landscape structure can influence connectivity.

The conceptual connection is:

```text
movement is not determined by Euclidean distance alone;
landscape structure can modify the relative support for alternative movements
```

Our present V3a `beta_sg` factor is a simpler endpoint-based test of that idea. A later normalized SG-dependent movement kernel would be closer in spirit to this framework.

## 20.6 Royle et al. (2013): incorporating ecological landscape information in SCR

**Royle, J. A. et al. (2013). Integrating resource selection information with spatial capture–recapture. Methods in Ecology and Evolution.**

[Read the paper / DOI](https://doi.org/10.1111/2041-210X.12039)

This paper demonstrates the broader principle that ecological and spatial covariates can be incorporated directly into SCR. V3 is simpler than a full resource-selection model: habitat currently defines valid support and SG identity contributes a movement-resistance term. This literature would become more directly relevant if habitat-selection coefficients were later estimated.

## 20.7 McClintock et al. (2022): linking SCR with explicit movement paths

**McClintock, B. T. et al. (2022). An integrated path for spatial capture–recapture and animal movement modeling. Ecology.**

[Read the paper / DOI](https://doi.org/10.1002/ecy.3473)

This is particularly useful for distinguishing a latent activity centre, detections around that activity centre and the animal's actual movement path.

That distinction is important for V3: `SG_here[k] != SG_here[k-1]` tells us that two annual AC endpoints occur in different SG territories. It does not reveal the literal path or exact number of boundaries crossed.

## 20.8 Gardner et al. (2022): integrated animal movement and SCR

**Gardner, B. et al. (2022). Integrated animal movement and spatial capture–recapture models. Ecology.**

[Read the paper / DOI](https://doi.org/10.1002/ecy.3771)

This paper provides another bridge between explicit movement information and latent spatial structure in SCR, and is useful for thinking about how capture locations inform movement and space use.

## 20.9 Crum, Gowan & Ramachandran (2023): movement transitions and spatial structure

**Crum, N. J., Gowan, T. A. & Ramachandran, A. (2023). Forecasting wildlife movement with spatial capture–recapture. Methods in Ecology and Evolution.**

[Read the paper / DOI](https://doi.org/10.1111/2041-210X.14222)

This work is especially relevant to a possible later V3b because it shows how SCR movement transitions can be structured by spatial regions and environmental covariates.

## 20.10 Badia-Boher et al. (2023): joint survival and dispersal

**Badia-Boher, J. A. et al. (2023). Joint estimation of survival and dispersal effectively corrects the permanent emigration bias in mark-recapture analyses. Scientific Reports.**

[Read the open-access paper / DOI](https://doi.org/10.1038/s41598-023-32866-0)

This paper is highly relevant to our survival objective. It illustrates why survival and dispersal should be estimated jointly where permanent emigration can otherwise bias survival, and also highlights sensitivity to dispersal-kernel assumptions.

## 20.11 Fukasawa & Higashide (2025): mechanistic home-range capture–recapture

**Fukasawa, K. & Higashide, D. (2025). Mechanistic home range capture–recapture models for the estimation of population density and landscape connectivity. Ecology.**

[Read the paper / DOI](https://doi.org/10.1002/ecy.70046)

This work moves toward a mechanistic representation of home-range use and connectivity. It reinforces an important interpretation for Woodchester: seasonal captures at setts should not automatically be treated as literal movement steps; they are observations generated by an underlying space-use process.

## 20.12 Which literature supports which V3 component?

| V3 component | Main literature connection |
|---|---|
| Robust-design-like primary/secondary structure | Ergon & Gardner (2014) |
| Annual latent activity centre | Ergon & Gardner (2014); standard SCR |
| Survival and movement estimated jointly | Ergon & Gardner (2014); Schaub & Royle (2014); Badia-Boher et al. (2023) |
| Direct bivariate annual AC transition | Turek et al. (2021) and broader movement-SCR literature |
| Spatial detection around an AC | Standard SCR; Ergon & Gardner (2014) |
| Explicit landscape/state-space information | Royle et al. (2013); Dupont et al. (2022) |
| SG structure modifying movement | Inspired especially by Dupont et al. (2022) and Crum et al. (2023) |
| Peripheral state space and emigration logic | Schaub & Royle (2014); Ergon & Gardner (2014) |
| Movement-kernel sensitivity | Efford (2022); Badia-Boher et al. (2023) |
| Distinguishing AC movement from literal paths | McClintock et al. (2022); Fukasawa & Higashide (2025) |

### Important originality / caveat of V3a

None of these papers should be cited as though it uses our exact current SG pseudo-likelihood:

```r
same_SG[i,k] <- equals(SG_here[i,k], SG_here[i,k-1])
sg_live_prob[i,k] <- same_SG[i,k] +
                     (1-same_SG[i,k]) * exp(-beta_sg)
sg_ok[i,k] ~ dbern(sg_live_prob[i,k])
```

That particular implementation is a **Woodchester V3a development device**. The literature supports the broader idea that landscape structure can modify spatial use and movement. If V3a shows a strong SG signal, the papers above provide a methodological route toward a more formally normalized V3b movement kernel.

---

# 21. Current status

V3 should first be run on a small development subset, not immediately on all 3,003 eligible badgers. The first computational milestone is a finite `model_V3$calculate()` value after the corrected initial-value scheme is used. Only after that should the short MCMC benchmark be assessed and compared against M2.
