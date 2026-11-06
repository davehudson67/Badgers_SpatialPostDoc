# Woodchester Robust-Design Spatial CMR — M2
## Fully annotated model, data workflow, and NIMBLE implementation

This document explains the current **Woodchester robust-design spatial CMR Model 2 (M2)** in detail. It is intended as a modelling record and collaborator-facing explanation of the model.

M2 builds on the V1 baseline but makes two major structural changes:

- the **first annual activity centre (AC) is latent**, rather than fixed to the first observed capture sett;
- annual movement is represented as a **direct bivariate-normal transition in X/Y space**, implying a Rayleigh distribution for annual radial displacement.

The model retains:

- primary occasions = years;
- secondary occasions = four trapping seasons per year;
- actual sett coordinates as detector locations;
- annual survival;
- group-specific detection and movement parameters;
- half-normal spatial detection;
- seasonal and five-year temporal detection effects;
- known death constraints;
- conditioning on first spatial capture.

M2 does **not yet** include social-group boundary resistance, habitat costs, alternative detection kernels, age-dependent survival, immigration classes, or bTB effects.

---

# 1. Why M2 was introduced

The earlier V1 movement formulation was:

```text
annual movement distance d
        +
annual direction theta
        ↓
new X/Y activity centre
```

This was biologically interpretable, but MCMC mixing for the population-level movement parameter `dmean` was very poor.

M2 removes the large collection of latent `d[i,k]` and `theta[i,k]` variables and instead models the next annual AC directly:

\[
S^x_{i,k} \sim N(S^x_{i,k-1}, \sigma_{move,g(i)}^2)
\]

\[
S^y_{i,k} \sim N(S^y_{i,k-1}, \sigma_{move,g(i)}^2)
\]

This is an isotropic bivariate-normal random walk.

The implied annual radial displacement is:

\[
D_{i,k}=\sqrt{(S^x_{i,k}-S^x_{i,k-1})^2+(S^y_{i,k}-S^y_{i,k-1})^2}
\]

and follows a Rayleigh distribution.

---

# 2. Core model structure

For each badger \(i\) and year \(k\), the model estimates a latent annual AC:

\[
\mathbf{S}_{i,k}=(S^x_{i,k},S^y_{i,k})
\]

Within each year, four seasonal capture occasions are observed around that same annual AC:

```text
Year k
  latent AC S[i,k]
      ├── Season 1
      ├── Season 2
      ├── Season 3
      └── Season 4
            ↓
      annual movement
            ↓
Year k+1
  latent AC S[i,k+1]
```

The AC is not treated as a literal sett. It is the underlying centre of space use from which capture probability declines with distance to sett detectors.

---

# 3. Latent first activity centre

In V1, the first AC was fixed exactly at the first detector:

```r
S[i,1,first[i]] <- X[first_detector[i],1]
S[i,2,first[i]] <- X[first_detector[i],2]
```

M2 instead estimates the first AC:

```r
S[i,1,first[i]] ~ dunif(xmin,xmax)
S[i,2,first[i]] ~ dunif(ymin,ymax)
```

This means all capture observations from the first year can inform the first AC.

The first capture is therefore no longer assumed to equal the animal's centre of space use.

---

# 4. Initial AC state space

The first AC is assigned a broad uniform prior over a rectangular domain defined by the detector array plus a 3-km buffer:

```r
AC_BUFFER <- 3000

xmin <- min(X[,1]) - AC_BUFFER
xmax <- max(X[,1]) + AC_BUFFER
ymin <- min(X[,2]) - AC_BUFFER
ymax <- max(X[,2]) + AC_BUFFER
```

Thus:

\[
S^x_{i,first} \sim U(x_{min},x_{max})
\]

\[
S^y_{i,first} \sim U(y_{min},y_{max})
\]

The first capture location is not used to centre this prior.

Only the first AC is explicitly bounded by this rectangle in M2. Subsequent ACs arise from the movement transition and can technically move outside it. This avoids introducing an incorrectly normalized hard boundary at this stage.

---

# 5. Entry-history groups

```text
Group 1 = first captured as Cub/Yearling
Group 2 = first captured as Adult
```

These groups currently affect:

- annual survival;
- spatial detection scale `sigma`;
- annual movement scale `sigma_move`;
- baseline detection intercept `alpha_p`.

This remains a static entry-history grouping, not a time-varying age model.

---

# 6. Robust-design structure

The model uses:

```text
Primary occasions   = years
Secondary occasions = four trapping seasons/year
```

One annual AC is shared across the four seasonal observations within a year.

This is robust-design-like rather than a strict Pollock robust design because the four secondary occasions span the full year.

---

# 7. Spatial detection

Distance from annual AC to detector sett \(r\):

\[
D_{ikr}=\sqrt{(S^x_{ik}-X^x_r)^2+(S^y_{ik}-X^y_r)^2}
\]

Half-normal spatial detection weight:

\[
g_{ikr}=\exp\left(-\frac{D_{ikr}^2}{2\sigma_{g(i)}^2}\right)
\]

The total spatial opportunity for capture is:

\[
G_{ik}=\sum_r g_{ikr}
\]

`Sigma` is therefore the within-year spatial detection scale in metres.

---

# 8. Temporal detection model

Baseline capture probability is:

\[
\text{logit}(p_{0,ijk})=
\alpha_{p,g(i)}
+\beta_{season,j}
+\beta_{period,k}
\]

Formal trapping-effort histories are unavailable, so seasonal and five-year effects represent broad observation heterogeneity rather than direct effort.

---

# 9. Sum-to-zero detection effects

Seasonal effects:

```r
for (s in 1:3) {
  beta_season_raw[s] ~ dnorm(0,sd=1)
  beta_season[s] <- beta_season_raw[s]
}
beta_season[4] <- -sum(beta_season_raw[1:3])
```

Five-year temporal effects:

```r
for (p in 1:(n_periods-1)) {
  beta_period_raw[p] ~ dnorm(0,sd=1)
  beta_period[p] <- beta_period_raw[p]
}
beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods-1)])
```

This makes `alpha_p` an overall group-specific detection intercept rather than tying it to one arbitrary reference season and period.

---

# 10. Capture probability

The baseline probability is converted to a hazard:

\[
\lambda_0=-\log(1-p_0)
\]

Probability of capture somewhere:

\[
P_{ijk}=1-\exp(-\lambda_{0,ijk}G_{ik})
\]

For later years this is multiplied by `z[i,k]`, so dead animals cannot be captured alive.

If captured, the observed detector probability is:

\[
P(R=r\mid captured)=\frac{g_{ikr}}{G_{ik}}
\]

---

# 11. Ones-trick likelihood

The custom observation probability is inserted using:

```r
Ones[i,j,k] ~ dbern(captureProb[i,j,k])
```

Every `Ones` value is observed as 1, so the likelihood contribution is exactly `captureProb`.

---

# 12. Annual survival

The survival process is:

\[
z_{i,k}\sim Bernoulli(z_{i,k-1}\phi_{g(i)})
\]

In code:

```r
Palive[i,k-1] <- z[i,k-1]*phi_annual[entry_group[i]]
z[i,k] ~ dbern(Palive[i,k-1]*step(death_primary[i]-k))
```

Known live captures constrain `z=1`, and known death information constrains later states.

---

# 13. Direct annual movement model

M2 replaces `d + theta` with direct annual X/Y transitions:

```r
S[i,1,k] ~ dnorm(S[i,1,k-1],sd=sigma_move[entry_group[i]])
S[i,2,k] ~ dnorm(S[i,2,k-1],sd=sigma_move[entry_group[i]])
```

So:

\[
\Delta X\sim N(0,\sigma_{move}^2)
\]

\[
\Delta Y\sim N(0,\sigma_{move}^2)
\]

Movement is currently isotropic.

---

# 14. Rayleigh radial movement

The derived annual movement distance is:

```r
moveDist[i,k-1] <- sqrt(
  pow(S[i,1,k]-S[i,1,k-1],2) +
  pow(S[i,2,k]-S[i,2,k-1],2)
)
```

Because X and Y changes are independent zero-mean normals with equal variance:

\[
D\sim Rayleigh(\sigma_{move})
\]

The expected radial movement is:

\[
E(D)=\sigma_{move}\sqrt{\frac{\pi}{2}}
\approx1.2533\sigma_{move}
\]

Therefore the model derives:

```r
mean_move[grp] <- sigma_move[grp]*sqrt(3.141593/2)
```

`mean_move` is the quantity most directly comparable with the old `dmean`.

---

# 15. Difference from V1 movement

```text
V1:
d ~ Exponential
theta ~ Uniform
S[k+1] calculated from d + theta

M2:
Sx[k+1] ~ Normal(Sx[k], sigma_move)
Sy[k+1] ~ Normal(Sy[k], sigma_move)
distance implied as Rayleigh
```

This is not merely a computational reparameterization; it changes the radial movement kernel.

That is acceptable because M1 remains the exponential-kernel baseline, while M4 is planned to evaluate kernel sensitivity explicitly.

---

# 16. Data flow

```text
Raw CMR data
   ↓
clean sett names
   ↓
join sett coordinates
   ↓
remove live captures without XY
   ↓
build year index
   ↓
build five-year periods
   ↓
assign entry group
   ↓
one spatial observation per season
   ↓
select eligible individuals
   ↓
exclude impossible chronology
   ↓
construct detector table
   ↓
define initial AC domain
   ↓
derive first capture metadata
   ↓
derive death timing
   ↓
construct H array
   ↓
construct z_data
   ↓
sort histories
   ↓
initialize latent AC trajectory
   ↓
build NIMBLE model
   ↓
compile + run MCMC
```

---

# 17. Full annotated code

## 17.1 Options

```r
library(tidyverse)
library(lubridate)
library(nimble)
library(coda)
library(MCMCvis)

set.seed(123)

SAMPLE_N <- 200L
NITER <- 2000
NBURN <- 500
NCHAINS <- 2
AC_BUFFER <- 3000

cmr_file <- "data/badger_final_CMRready_wDisease.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
dir.create("results",showWarnings=FALSE)
```

`SAMPLE_N <- 200L` is retained for development testing. Once M2 is stable it can be set to `NA_integer_` for the full dataset.

---

## 17.2 Sett-name cleaning

```r
sett_aliases <- c(
  "\\bCHESTNUT\\b"="CHESNUT","\\bJACKS\\b"="JACKSMIREY",
  "\\bGRAVEL\\b"="GRAVELPIT","\\bBUCKHOLE\\b"="BUCKHOLT",
  "\\bTOPSETT\\b"="TOP","\\bFOXCUB\\b"="FOX",
  "\\bGULLEY\\b"="GULLY","\\bBLACKBERRY\\b"="BRAMBLE",
  "\\bBOC\\b"="BOG","\\bCEDARBANK\\b"="CEDAR",
  "\\bCLAYTRAP\\b"="CLAY","\\bCLIFF\\b"="CLIFFFACE",
  "\\bDINGLEVALLEY\\b"="DINGLE"
)

clean_sett <- function(x) {
  x %>% as.character() %>% toupper() %>%
    str_replace_all("[[:punct:]]"," ") %>% str_squish() %>%
    str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
    str_replace_all(sett_aliases) %>% str_replace_all("\\s+","")
}
```

The same cleaning rule is used for the CMR data and sett-coordinate data.

---

## 17.3 Load sett coordinates

```r
sett_raw <- read_csv(sett_file,show_col_types=FALSE)

name_candidates <- c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name")
x_candidates <- c("SettX","sett_x","X","x","Easting","easting")
y_candidates <- c("SettY","sett_y","Y","y","Northing","northing")

name_col <- intersect(name_candidates,names(sett_raw))[1]
x_col <- intersect(x_candidates,names(sett_raw))[1]
y_col <- intersect(y_candidates,names(sett_raw))[1]

if (any(is.na(c(name_col,x_col,y_col)))) stop("Could not identify sett name/X/Y columns.")

sett_xy <- sett_raw %>%
  transmute(Sett_Clean=clean_sett(.data[[name_col]]),
            x=as.numeric(.data[[x_col]]),y=as.numeric(.data[[y_col]])) %>%
  filter(!is.na(Sett_Clean),Sett_Clean!="",!is.na(x),!is.na(y)) %>%
  distinct(Sett_Clean,.keep_all=TRUE)
```

---

## 17.4 Load CMR data

```r
cmr_raw <- readRDS(cmr_file)

cmr <- cmr_raw %>%
  mutate(Sett_Clean=clean_sett(sett),
         primary_year=as.integer(primary_year),
         trap_season=as.integer(trap_season)) %>%
  left_join(sett_xy,by="Sett_Clean")
```

---

## 17.5 Remove live captures without XY

```r
excluded_xy <- cmr %>%
  filter(has_live_capture,is.na(x) | is.na(y)) %>%
  count(Sett_Clean,sort=TRUE)

n_live_before <- sum(cmr$has_live_capture,na.rm=TRUE)
cmr <- cmr %>% filter(!has_live_capture | (!is.na(x) & !is.na(y)))
n_live_after <- sum(cmr$has_live_capture,na.rm=TRUE)
```

Only spatially unusable live captures are removed. PM-only records are retained.

---

## 17.6 Year and period indexing

```r
min_year <- min(cmr$primary_year,na.rm=TRUE)
max_year <- max(cmr$primary_year,na.rm=TRUE)
years <- min_year:max_year
n_prim <- length(years)
n_sec <- 4L

cmr <- cmr %>% mutate(primary=match(primary_year,years))

year_lookup <- tibble(primary_year=years) %>%
  mutate(period_start=floor(primary_year/5)*5,
         period_id=match(period_start,sort(unique(period_start))))

period_vec <- as.integer(year_lookup$period_id)
n_periods <- max(period_vec)
```

---

## 17.7 Entry group

```r
demog <- cmr_raw %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  summarise(age_fc={
    z <- na.omit(age_fc)
    if (length(z)) as.character(z[1]) else NA_character_
  },.groups="drop") %>%
  mutate(entry_group=case_when(
    age_fc %in% c("Cub","Yearling") ~ 1L,
    age_fc=="Adult" ~ 2L,
    TRUE ~ NA_integer_
  ))

cmr <- cmr %>% left_join(demog %>% select(tattoo,entry_group),by="tattoo")
```

---

## 17.8 One live location per season

```r
live <- cmr %>%
  filter(has_live_capture,!is.na(primary),!is.na(trap_season),
         !is.na(x),!is.na(y)) %>%
  arrange(tattoo,primary,trap_season,capture_date) %>%
  group_by(tattoo,primary,trap_season) %>%
  slice_tail(n=1) %>% ungroup()
```

This remains a simplifying assumption: multiple captures in the same season are collapsed to the latest.

---

## 17.9 Eligible individuals

```r
eligible <- live %>%
  distinct(tattoo) %>%
  inner_join(demog,by="tattoo") %>%
  filter(entry_group %in% 1:2)

exclude_ids <- "007V"
eligible <- eligible %>% filter(!tattoo %in% exclude_ids)
```

`007V` is excluded because of an irreconcilable PM-before-live-capture chronology.

---

## 17.10 Detector table and AC domain

```r
detectors <- live %>%
  distinct(Sett_Clean,x,y) %>%
  arrange(Sett_Clean) %>%
  mutate(detector=row_number())

X <- as.matrix(detectors %>% select(x,y))
R <- nrow(X)

live <- live %>%
  left_join(detectors %>% select(Sett_Clean,detector),by="Sett_Clean")

xmin <- min(X[,1])-AC_BUFFER
xmax <- max(X[,1])+AC_BUFFER
ymin <- min(X[,2])-AC_BUFFER
ymax <- max(X[,2])+AC_BUFFER
```

---

## 17.11 Initial values

```r
make_inits <- function(chain=1L) {

  z_init <- matrix(0L,nind,n_prim)
  S_init <- array(NA_real_,dim=c(nind,2,n_prim))

  for (i in seq_len(nind)) {

    dat <- live %>%
      filter(tattoo==ids[i]) %>%
      group_by(primary) %>%
      summarise(x=mean(x),y=mean(y),.groups="drop")

    xy <- matrix(NA_real_,n_prim,2)

    for (k in first[i]:K[i]) {
      dk <- dat %>% filter(primary==k)
      if (nrow(dk)) xy[k,] <- c(dk$x[1],dk$y[1])
      else if (k>first[i]) xy[k,] <- xy[k-1,]
    }

    S_init[i,,first[i]:K[i]] <- t(xy[first[i]:K[i],,drop=FALSE])
    z_init[i,first[i]:K[i]] <- 1L
  }

  z_init[!is.na(z_data)] <- NA

  list(
    alpha_phi=c(qlogis(.70),qlogis(.68))+rnorm(2,0,.03),
    alpha_p=c(qlogis(.20),qlogis(.20))+rnorm(2,0,.03),
    alpha_logsigma=log(c(135,95))+rnorm(2,0,.03),
    alpha_logmove=log(c(70,70))+rnorm(2,0,.03),
    beta_season_raw=rnorm(3,0,.03),
    beta_period_raw=rnorm(n_periods-1L,0,.03),
    S=S_init,z=z_init
  )
}
```

The latent trajectory is initialized from observed annual mean positions, with the last observed position carried forward across missing years.

These are starting values only.

---

# 18. Full NIMBLE model

```r
code_M2 <- nimbleCode({

  for (grp in 1:2) {
    alpha_phi[grp] ~ dnorm(qlogis(.70),sd=1.5)
    phi_annual[grp] <- ilogit(alpha_phi[grp])

    alpha_p[grp] ~ dnorm(qlogis(.15),sd=1.5)

    alpha_logsigma[grp] ~ dnorm(log(250),sd=1)
    sigma[grp] <- exp(alpha_logsigma[grp])

    alpha_logmove[grp] ~ dnorm(log(100),sd=1)
    sigma_move[grp] <- exp(alpha_logmove[grp])
    mean_move[grp] <- sigma_move[grp]*sqrt(3.141593/2)
  }

  for (s in 1:3) {
    beta_season_raw[s] ~ dnorm(0,sd=1)
    beta_season[s] <- beta_season_raw[s]
  }
  beta_season[4] <- -sum(beta_season_raw[1:3])

  for (p in 1:(n_periods-1)) {
    beta_period_raw[p] ~ dnorm(0,sd=1)
    beta_period[p] <- beta_period_raw[p]
  }
  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods-1)])

  for (i in 1:N[1]) {

    z[i,first[i]] ~ dbern(1)

    S[i,1,first[i]] ~ dunif(xmin,xmax)
    S[i,2,first[i]] ~ dunif(ymin,ymax)

    g[i,first[i],1] <- 0

    for (r in 1:R) {
      D[i,r,first[i]] <- sqrt(
        pow(S[i,1,first[i]]-X[r,1],2) +
        pow(S[i,2,first[i]]-X[r,2],2)
      )

      g[i,first[i],r+1] <- exp(
        -pow(D[i,r,first[i]],2) /
        (2*pow(sigma[entry_group[i]],2))
      )
    }

    G[i,first[i]] <- sum(g[i,first[i],1:(R+1)])

    for (j in 1:J[i,first[i]]) {

      lp0[i,j,first[i]] <- alpha_p[entry_group[i]] +
        beta_season[j] + beta_period[period_vec[first[i]]]

      p0[i,j,first[i]] <- ilogit(lp0[i,j,first[i]])
      lambda0[i,j,first[i]] <- -log(1-p0[i,j,first[i]])
      P[i,j,first[i]] <- 1-exp(-lambda0[i,j,first[i]]*G[i,first[i]])

      captureProb[i,j,first[i]] <-
        step(H[i,j,first[i]]-2) *
        g[i,first[i],H[i,j,first[i]]] /
        (G[i,first[i]]+1e-10) *
        P[i,j,first[i]] +
        (1-step(H[i,j,first[i]]-2)) *
        (1-P[i,j,first[i]])

      Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])
    }
  }

  for (i in (N[1]+1):N[2]) {

    z[i,first[i]] ~ dbern(1)

    S[i,1,first[i]] ~ dunif(xmin,xmax)
    S[i,2,first[i]] ~ dunif(ymin,ymax)

    g[i,first[i],1] <- 0

    for (r in 1:R) {
      D[i,r,first[i]] <- sqrt(
        pow(S[i,1,first[i]]-X[r,1],2) +
        pow(S[i,2,first[i]]-X[r,2],2)
      )

      g[i,first[i],r+1] <- exp(
        -pow(D[i,r,first[i]],2) /
        (2*pow(sigma[entry_group[i]],2))
      )
    }

    G[i,first[i]] <- sum(g[i,first[i],1:(R+1)])

    for (j in 1:J[i,first[i]]) {

      lp0[i,j,first[i]] <- alpha_p[entry_group[i]] +
        beta_season[j] + beta_period[period_vec[first[i]]]

      p0[i,j,first[i]] <- ilogit(lp0[i,j,first[i]])
      lambda0[i,j,first[i]] <- -log(1-p0[i,j,first[i]])
      P[i,j,first[i]] <- 1-exp(-lambda0[i,j,first[i]]*G[i,first[i]])

      captureProb[i,j,first[i]] <-
        step(H[i,j,first[i]]-2) *
        g[i,first[i],H[i,j,first[i]]] /
        (G[i,first[i]]+1e-10) *
        P[i,j,first[i]] +
        (1-step(H[i,j,first[i]]-2)) *
        (1-P[i,j,first[i]])

      Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])
    }

    for (k in (first[i]+1):K[i]) {

      Palive[i,k-1] <- z[i,k-1]*phi_annual[entry_group[i]]
      z[i,k] ~ dbern(Palive[i,k-1]*step(death_primary[i]-k))

      S[i,1,k] ~ dnorm(S[i,1,k-1],sd=sigma_move[entry_group[i]])
      S[i,2,k] ~ dnorm(S[i,2,k-1],sd=sigma_move[entry_group[i]])

      moveDist[i,k-1] <- sqrt(
        pow(S[i,1,k]-S[i,1,k-1],2) +
        pow(S[i,2,k]-S[i,2,k-1],2)
      )

      g[i,k,1] <- 0

      for (r in 1:R) {
        D[i,r,k] <- sqrt(
          pow(S[i,1,k]-X[r,1],2) +
          pow(S[i,2,k]-X[r,2],2)
        )

        g[i,k,r+1] <- exp(
          -pow(D[i,r,k],2) /
          (2*pow(sigma[entry_group[i]],2))
        )
      }

      G[i,k] <- sum(g[i,k,1:(R+1)])

      for (j in 1:J[i,k]) {

        lp0[i,j,k] <- alpha_p[entry_group[i]] +
          beta_season[j] + beta_period[period_vec[k]]

        p0[i,j,k] <- ilogit(lp0[i,j,k])
        lambda0[i,j,k] <- -log(1-p0[i,j,k])

        P[i,j,k] <- (1-exp(-lambda0[i,j,k]*G[i,k]))*z[i,k]

        captureProb[i,j,k] <-
          step(H[i,j,k]-2) *
          g[i,k,H[i,j,k]] /
          (G[i,k]+1e-10) *
          P[i,j,k] +
          (1-step(H[i,j,k]-2)) *
          (1-P[i,j,k])

        Ones[i,j,k] ~ dbern(captureProb[i,j,k])
      }
    }
  }
})
```

---

# 19. Main parameters

## `phi_annual[1:2]`

Annual survival by entry-history group.

## `sigma[1:2]`

Half-normal spatial detection scale in metres.

## `sigma_move[1:2]`

Standard deviation of annual X/Y displacement.

## `mean_move[1:2]`

Expected annual radial displacement:

\[
mean\_move=\sigma_{move}\sqrt{\pi/2}
\]

## `alpha_p[1:2]`

Overall detection intercept by group.

## `beta_season`

Sum-to-zero recurring seasonal detection effects.

## `beta_period`

Sum-to-zero five-year temporal detection effects.

---

# 20. Model building

```r
#model_M2 <- nimbleModel(
#  code_M2,constants=consts,data=data_list,
#  inits=inits[[1]],check=TRUE,calculate=FALSE
#)

#print(model_M2$initializeInfo())

#lp <- model_M2$calculate()
#cat("\nInitial log probability:",lp,"\n")

#if (!is.finite(lp))
#  stop("M2 initial model log probability is not finite.")
```

A finite initial likelihood confirms compatibility between starting ACs, survival states and observed detections.

---

# 21. MCMC configuration

```r
#cModel_M2 <- compileNimble(model_M2,resetFunctions=TRUE)

#monitors <- c(
#  "phi_annual","sigma_move","mean_move",
#  "sigma","alpha_p","beta_season","beta_period"
#)

#config_M2 <- configureMCMC(model_M2,monitors=monitors,thin=1)
#Rmcmc_M2 <- buildMCMC(config_M2)

#cMCMC_M2 <- compileNimble(
#  Rmcmc_M2,project=cModel_M2,resetFunctions=TRUE
#)
```

The full `S` array is not monitored routinely to avoid very large posterior output.

---

# 22. Running MCMC

```r
#runtime_M2 <- system.time({
#  samples_M2 <- runMCMC(
#    cMCMC_M2,niter=NITER,nburnin=NBURN,
#    nchains=NCHAINS,inits=inits,
#    samplesAsCodaMCMC=TRUE,progressBar=TRUE,
#    setSeed=2451:(2451+NCHAINS-1L)
#  )
#})
```

The development run uses 200 individuals to test mixing and runtime before fitting the full dataset.

---

# 23. Diagnostics

```r
MCMCsummary(samples_M2)
gelman.diag(samples_M2,multivariate=FALSE)
effectiveSize(samples_M2)
```

The main diagnostic focus is on:

```text
sigma_move
mean_move
phi_annual
sigma
alpha_p
```

The key question is whether `sigma_move` and `mean_move` mix substantially better than `dmean` did under V1.

---

# 24. Important assumptions and limitations

## First AC prior

The first AC is latent but uses a simple rectangular uniform prior rather than a habitat mask.

## Annual AC

All four seasonal observations within a year are linked to one annual AC.

## Isotropic movement

Movement has no directional preference.

## Rayleigh radial movement

The bivariate-normal transition implies Rayleigh movement distance.

## Half-normal detection

Detection-kernel sensitivity has not yet been explored.

## Unknown trapping effort

Season and period effects absorb broad temporal observation heterogeneity, not measured effort.

## Detector availability

All included sett detector locations are effectively treated as available across the study period.

## No explicit outside/emigration state

M2 still does not formally separate permanent emigration from mortality using an integrated outside state.

---

# 25. Relationship to M1

```text
M1
- first AC fixed at first capture
- exponential radial movement
- uniform movement angle
- d + theta latent variables
- half-normal detection

M2
- first AC latent
- direct bivariate-normal XY movement
- Rayleigh radial displacement
- no d or theta latent variables
- half-normal detection
```

M2 is therefore a genuinely different spatial formulation rather than a minor parameter tweak.

---

# 26. Five-model roadmap

```text
M1 — Baseline
Fixed first AC
Exponential movement + angle
Half-normal detection

M2 — Direct latent-AC model
Latent first AC
Direct bivariate-normal annual movement
Rayleigh radial displacement

M3 — Hybrid spatial/social model
M2 structure
+ explicit landscape state space
+ social-group boundary resistance
+ better peripheral/emigration treatment

M4 — Kernel sensitivity
Compare plausible detection and movement kernels

M5 — Demographic/disease model
Best-supported spatial structure
+ age / origin / immigration
+ bTB effects
```

---

# 27. What success looks like for M2

M2 is successful if:

- the model initializes with a finite likelihood;
- both chains converge adequately;
- movement ESS improves substantially;
- survival remains stable;
- detection parameters remain well behaved;
- runtime remains feasible for a full-data run.

Biologically, M2 should provide a more defensible first-year AC and a cleaner annual movement process than V1.

---

# 28. Summary

M2 is:

\[
\boxed{
\text{latent first AC}
+
\text{direct annual XY movement}
+
\text{annual survival}
+
\text{four seasonal spatial observations}
}
\]

The first AC is now estimated from the data rather than fixed to the first observed sett.

Annual movement is represented directly through successive latent X/Y coordinates, with Rayleigh radial displacement implied by the bivariate-normal transition.

The key movement outputs are:

```text
sigma_move = annual X/Y movement scale
mean_move  = expected annual radial displacement
```

M2 is intended as the computationally cleaner spatial baseline from which the hybrid social/spatial M3 can be built.
