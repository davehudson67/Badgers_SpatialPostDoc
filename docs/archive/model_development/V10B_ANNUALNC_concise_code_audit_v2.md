# Woodchester V10B ANNUALNC — concise code audit

**File audited:** `scripts/ModularFitting/Woodchester_V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_ANNUALNC.R`

## How to use this guide

For each major part of the model:

- **Code** — compact version of the actual implementation.
- **Does** — what the code is doing.
- **Meaning** — biological interpretation.
- **Basis** — why the approach is statistically defensible.
- **Status** — **Established**, **Adapted**, or **Bespoke**.

The exact Woodchester model is not copied from one published model. It combines established SCR, robust-design, state-space, HMM and hierarchical-MCMC ideas.

---

# 1. Overall model

For badger `i`, year `k`, quarter `j`:

\[
A_{ik}\rightarrow Q_{ijk}\rightarrow \text{captures}.
\]

- `A` = annual activity centre.
- `Q` = quarter-specific centre.
- Captures occur around `Q`.
- Between years, `A` can move under either a **local** or **high-mobility** state.

**Meaning:** an animal has an underlying annual spatial centre, uses slightly different parts of its range through the year, and may occasionally make a much larger annual relocation.

**Basis:** latent activity centres and distance-based detection are standard SCR; moving activity centres are established in robust-design/open SCR.

**Status:** **Established components; adapted combination.**

---

# 2. Primary and secondary periods

```r
MAX_YEAR <- 2025L
J <- 4L
years <- min(full_live$primary_year):MAX_YEAR
```

**Does:** uses years as primary periods and four trapping quarters as secondary occasions.

**Meaning:** annual movement is separated from within-year spatial variation.

**Basis:** robust-design capture–recapture uses repeated secondary samples nested within primary periods; open/RD-SCR extends this spatially.

**Status:** **Established / adapted.**

**Key references:** Pollock (1982); Ergon & Gardner (2014).

---

# 3. Capture-location arrays

```r
H <- array(1L, dim = c(nind, J, M, n_prim))
ncap <- array(0L, dim = c(nind, J, n_prim))

for (rr in seq_len(nrow(live_slots))) {
  i <- match(live_slots$tattoo[rr], ids)
  k <- live_slots$primary[rr]
  j <- live_slots$trap_season[rr]
  m <- live_slots$capture_slot[rr]

  H[i, j, m, k] <- live_slots$detector[rr]
  ncap[i, j, k] <- max(ncap[i, j, k], m)
}
```

**Does:** retains every observed sett for each badger-quarter.

- `ncap[i,j,k]` = number of captures.
- `H[i,j,m,k]` = detector used for capture `m`.

**Meaning:** if a badger was caught at two different setts in one quarter, both locations inform its quarterly centre.

**Basis:** SCR explicitly uses spatial encounter locations.

**Status:** **Established SCR idea; adapted data structure.**

**References:** Efford (2004); Borchers & Efford (2008).

---

# 4. Quarterly SCR likelihood

## Spatial detection kernel

```r
for (r in 1:R) {
  d2 <- (Sx - X[r, 1])^2 + (Sy - X[r, 2])^2
  g_vec[r] <- exp(-d2 / (2 * sigma^2))
  G_sum <- G_sum + g_vec[r]
}
```

\[
g_r=\exp[-d_r^2/(2\sigma^2)].
\]

**Meaning:** nearby setts are more likely to catch the badger than distant ones.

**Status:** **Established SCR.**

## Was it caught?

```r
Pcap <- 1 - exp(-lambda0 * G_sum)
```

with:

```r
lambda0[i, j, k] <- -log(1 - ilogit(lp0[i, j, k]))
```

**Meaning:** capture probability increases when more suitable detectors are close to the quarterly centre.

## Where was it caught?

```r
if (nc < 1) return(max(1 - Pcap, 1e-300))

out <- Pcap
for (m in 1:nc) {
  hh <- as.integer(H_vec[m])
  out <- out * g_vec[hh] / (G_sum + 1e-12)
}
```

\[
L=P_{\rm cap}\prod_{m=1}^{n_{\rm cap}}
\frac{g_{h_m}}{\sum_r g_r}.
\]

**Meaning:** we model whether the badger was caught and where those captures occurred, but condition on the observed number of within-quarter captures.

**Why:** exact detector-by-night historical effort is unavailable.

**Status:** spatial kernel **Established**; quarterly conditional factorisation **Bespoke/adapted to the data**.

---

# 5. Detection parameters

```r
alpha_p ~ dnorm(qlogis(0.17), sd = 1.5)
beta_p_sex ~ dnorm(0, sd = 1)

alpha_logsigma ~ dnorm(log(150), sd = 1)
beta_sigma_sex ~ dnorm(0, sd = 0.75)

lp0[i, j, k] <- alpha_p +
  beta_p_sex * sex[i] +
  beta_season[j] +
  beta_period[period_vec[k]]
```

**Meaning:**

- `p0` = baseline quarterly catchability.
- `sigma` = how quickly capture probability falls with distance from `Q`.
- detection can differ by sex, season and long-term period.

**Important:** detection `sigma` is **not movement distance**.

**Status:** **Established SCR structure; chosen priors are model-specific.**

---

# 6. First annual activity centre

```r
A[i, 1, first[i]] ~ dunif(grid_xmin, grid_xmax)
A[i, 2, first[i]] ~ dunif(grid_ymin, grid_ymax)
```

followed by the habitat constraint.

**Meaning:** the first annual centre is not fixed at the first capture. Capture locations in that year infer where it should be.

The mean capture coordinate is used only as an MCMC starting value.

**Basis:** latent activity centres are central to SCR.

**Status:** **Established.**

**References:** Efford (2004); Borchers & Efford (2008); Royle et al. (2013).

---

# 7. Quarterly centre: new random nudge

First quarter:

```r
qinnov[i, 1:2, 1, first[i]] ~
  dmnorm(mean = q_zero[1:2], prec = q_prec[1:2, 1:2])

qeps[i, 1, 1, first[i]] <- qinnov[i, 1, 1, first[i]]
qeps[i, 2, 1, first[i]] <- qinnov[i, 2, 1, first[i]]
```

Later quarters:

```r
for (j in 2:J) {
  qinnov[i, 1:2, j, first[i]] ~
    dmnorm(mean = q_zero[1:2], prec = q_prec[1:2, 1:2])

  qeps[i, 1, j, first[i]] <- rho * qeps[i, 1, j - 1, first[i]] +
    q_innov_scale * qinnov[i, 1, j, first[i]]

  qeps[i, 2, j, first[i]] <- rho * qeps[i, 2, j - 1, first[i]] +
    q_innov_scale * qinnov[i, 2, j, first[i]]
}
```

where:

```r
rho <- ilogit(alpha_rho)
q_innov_scale <- sqrt(1 - rho^2)
```

**Does:** creates a stationary AR(1) displacement around the annual centre.

\[
\epsilon_j=\rho\epsilon_{j-1}+\sqrt{1-\rho^2}\eta_j.
\]

**Meaning:** this quarter partly remembers the previous quarter and partly receives a new random spatial nudge.

- `rho` = persistence.
- `omega` = amount of within-year spatial variation.

The scaling keeps total variance constant as `rho` changes.

**Basis:** standard AR/state-space mathematics; innovation form is a non-centred representation.

**Status:** **Established mathematics; adapted ecological application.**

**References:** Jonsen et al. (2005); Patterson et al. (2008); Papaspiliopoulos et al. (2007).

**Assumption:** `rho` is restricted to 0–1, so systematic quarter-to-quarter alternation is not allowed.

---

# 8. Convert quarterly displacement into a real location

```r
for (j in 1:J) {
  Qx[i, j, first[i]] <- A[i, 1, first[i]] +
    omega * qeps[i, 1, j, first[i]]

  Qy[i, j, first[i]] <- A[i, 2, first[i]] +
    omega * qeps[i, 2, j, first[i]]
}
```

\[
Q=A+\omega\epsilon.
\]

**Meaning:** `qeps` gives direction/relative amount; `omega` converts it to metres.

**Why bivariate normal?** movement has x and y components, with no preferred compass direction. Small shifts are common and large shifts rarer.

**Status:** **Established spatial/state-space idea.**

---

# 9. Interpretable quarterly summaries

```r
mean_quarter_offset_from_annual <- omega * sqrt(pi / 2)

mean_between_quarter_centres <-
  omega * sqrt(pi) * sqrt(1 - rho)
```

**Meaning:**

- first quantity = average distance of a quarterly centre from annual `A`;
- second = average distance between consecutive quarterly centres.

**Basis:** radial distance from an isotropic 2-D Gaussian is Rayleigh distributed.

**Status:** **Established mathematics.**

---

# 10. Habitat restriction

```r
col_Q_raw[i, j, k] <- trunc((Qx[i, j, k] - grid_xmin) / cell_size) + 1
row_Q_raw[i, j, k] <- trunc((grid_ymax - Qy[i, j, k]) / cell_size) + 1

col_Q[i, j, k] <- max(1, min(n_cols, col_Q_raw[i, j, k]))
row_Q[i, j, k] <- max(1, min(n_rows, row_Q_raw[i, j, k]))

in_bounds_Q[i, j, k] <-
  step(Qx[i, j, k] - grid_xmin) *
  step(grid_xmax - Qx[i, j, k]) *
  step(Qy[i, j, k] - grid_ymin) *
  step(grid_ymax - Qy[i, j, k])

habitat_Q[i, j, k] <- habitat_mat[row_Q[i, j, k], col_Q[i, j, k]]
valid_Q[i, j, k] <- in_bounds_Q[i, j, k] * habitat_Q[i, j, k]

quarter_state_ok[i, j, k] ~ dbern(valid_Q[i, j, k])
```

**Meaning:** quarterly centres must lie inside the state space and on allowed terrestrial habitat.

**Status:** **Established state-space restriction; implementation-specific.**

**Caveat:** the movement kernel is not explicitly renormalised near irregular habitat boundaries, so edge effects need a spatial PPC/sensitivity check.

**Reference:** Gardner et al. (2018).

---

# 11. Annual movement states

Each annual displacement can be:

- **local/resident**
- **high mobility**

Transition probabilities:

```r
p_RD_i[i, k] <- ilogit(alpha_RD + beta_RD_sex * sex[i])
p_DD_i[i, k] <- ilogit(alpha_DD + beta_DD_sex * sex[i])
```

Prediction:

```r
p_high_pred[i, k] <- is_initial_interval[i, k] * p_disp_init[i] +
  (1 - is_initial_interval[i, k]) *
  ((1 - filtered_high[i, k - 1]) * p_RD_i[i, k] +
   filtered_high[i, k - 1] * p_DD_i[i, k])
```

**Meaning:**

- `RD` = probability a resident becomes high-mobility.
- `DD` = probability high mobility persists.

**Basis:** standard two-state HMM / multistate movement framework.

**Status:** **Established concept; adapted to annual SCR-centre movements.**

**References:** Morales et al. (2004); McClintock et al. (2012); Langrock et al. (2012).

---

# 12. Collapse the HMM rather than sampling states

```r
move_logcomp_local[i, k] <-
  log(1 - p_high_safe[i, k]) + move_logdens_local[i, k]

move_logcomp_high[i, k] <-
  log(p_high_safe[i, k]) + move_logdens_high[i, k]

move_logmax[i, k] <- max(move_logcomp_local[i, k],
                         move_logcomp_high[i, k])

move_logmix[i, k] <- move_logmax[i, k] +
  log(exp(move_logcomp_local[i, k] - move_logmax[i, k]) +
      exp(move_logcomp_high[i, k] - move_logmax[i, k]))

filtered_high[i, k] <-
  exp(move_logcomp_high[i, k] - move_logmix[i, k])
```

**Does:** sums over local and high possibilities instead of sampling a binary state during MCMC.

\[
p(d)=(1-p_H)f_L(d)+p_Hf_H(d).
\]

**Meaning:** fit the movement trajectory without forcing the chain to repeatedly flip thousands of local/high switches. State probabilities are recovered afterwards.

**Why:** explicit-state chains became trapped in different state paths.

**Status:** **Established HMM marginalisation; applied to our model.**

---

# 13. Directly sample the high-mobility scale

```r
beta_move_high ~ dexp(1)

alpha_logmove_high ~
  dnorm(log(20) + beta_move_high, sd = 1)

alpha_logmove <- alpha_logmove_high - beta_move_high
```

Original structure:

\[
\alpha_{\log L}\sim N(\log20,1),\qquad
\beta_H\sim\operatorname{Exp}(1),
\]

\[
\alpha_{\log H}=\alpha_{\log L}+\beta_H.
\]

**Meaning:** estimate the well-defined large-movement scale directly, then derive the less well-defined resident scale.

**Why:** the data identify high movement much better than the exact local/high decomposition.

**Important:** this is a one-to-one reparameterisation; the original local-scale prior is preserved.

**Status:** **Bespoke algebraic reparameterisation based on established MCMC principles.**

**Reference for principle:** Papaspiliopoulos et al. (2007).

---

# 14. Annual non-centred movement

```r
u_move[i, 1:2, k] ~
  dmnorm(mean = q_zero[1:2], prec = u_ref_prec[1:2, 1:2])

A[i, 1, k] <- A[i, 1, k - 1] +
  sigma_move_local_eval[i, k] * u_move[i, 1, k]

A[i, 2, k] <- A[i, 2, k - 1] +
  sigma_move_local_eval[i, k] * u_move[i, 2, k]
```

\[
A_k=A_{k-1}+\sigma_Lu_k.
\]

**Meaning:** sample annual movement in units of normal resident movement, then reconstruct the map coordinates.

**Why:** centred annual locations showed serious cross-chain trajectory trapping.

**Biology:** unchanged; this is a coordinate change for MCMC.

**Status:** **Established non-centring principle; bespoke implementation.**

**Reference:** Papaspiliopoulos et al. (2007).

---

# 15. Local and high movement on the non-centred scale

Under local movement:

\[
u\sim N_2(0,I).
\]

Under high movement:

\[
u\sim N_2(0,r^2I),\qquad
r=\sigma_H/\sigma_L.
\]

Compact code:

```r
move_high_ratio[i, k] <-
  sigma_move_high_eval[i, k] / sigma_move_local_eval[i, k]

move_logdens_local[i, k] <-
  -LOG_TWO_PI - u_moveD2[i, k] / 2

move_logdens_high[i, k] <-
  -LOG_TWO_PI -
  2 * log(move_high_ratio[i, k]) -
  u_moveD2[i, k] / (2 * move_high_ratio[i, k]^2)
```

**Meaning:** an ordinary annual movement is around one local-movement unit; high movements allow much larger standardised steps.

**Status:** **Direct consequence of the change of variables.**

---

# 16. Zeros-trick correction

NIMBLE gives `u_move` a broad reference Gaussian, then the zeros trick replaces that reference with the required collapsed-HMM density.

```r
move_log_target_over_ref[i, k] <-
  move_logmix[i, k] - move_logref_u[i, k]

move_nll[i, k] <- max(
  1e-12,
  MOVE_NC_CORR_CONST - move_log_target_over_ref[i, k]
)

move_zero[i, k] ~ dpois(move_nll[i, k])
```

For observed `move_zero = 0`:

\[
P(0|\lambda)=e^{-\lambda}.
\]

Choosing:

\[
\lambda=C-\log(t/q)
\]

gives:

\[
q(u)P(0|\lambda)\propto t(u).
\]

**Meaning:** the broad Gaussian exists only so NIMBLE has a stochastic node; the Poisson correction gives `u_move` the movement density we actually want.

**Status:** zeros trick **Established**; this exact transformed mixture implementation **Bespoke and algebraically checked**.

**Reference:** Lunn et al. (2013), *The BUGS Book*.

**Audit result:** the current correction constant `2 * log(U_REF_SD)` is appropriate on the transformed scale.

---

# 17. Radial annual movement summaries

```r
mean_annual_move_female_local <-
  exp(alpha_logmove) * sqrt(pi / 2)

mean_annual_move_female_high <-
  exp(alpha_logmove + beta_move_high) * sqrt(pi / 2)
```

(and corresponding male quantities).

**Meaning:** these are average straight-line annual centre shifts in metres.

The underlying Gaussian `sigma` is an x/y coordinate SD, not the mean distance.

**Status:** **Established Rayleigh result.**

---

# 18. Sex effect on annual movement

```r
beta_move_sex ~ dnorm(0, sd = 0.50)
```

It enters both local and high movement scales.

**Implication:** the male:female scale ratio is assumed to be the same in both states.

**Status:** **Model assumption.**

This is parsimonious but should be stated explicitly.

---

# 19. Seasonal and long-term detection effects

```r
for (s in 1:3) {
  beta_season_raw[s] ~ dnorm(0, sd = 1)
  beta_season[s] <- beta_season_raw[s]
}
beta_season[4] <- -sum(beta_season_raw[1:3])
```

and similarly for five-year periods.

**Does:** forces effects to sum to zero so `alpha_p` is an overall baseline.

**Audit issue:** the final category is the negative sum of the others, so it has a wider induced prior.

For seasons:

- Q1–Q3 variance = 1
- Q4 variance = 3

The asymmetry is stronger for many five-year periods.

**Status:** valid but **not ideal/exchangeable**.

**Recommendation:** leave the current 300-badger comparison unchanged; revisit a symmetric sum-to-zero prior before final production.

---

# 20. Campaign-effort approximation

```r
campaign_tbl <- full_live %>%
  distinct(primary_year, trap_season)
```

A year-quarter is active if at least one successful capture occurred anywhere in the full audited population.

**Meaning:** completely empty historical quarters are not treated as known study-wide non-capture campaigns.

**Why:** full detector × night effort is unavailable.

**Status:** **Bespoke approximation forced by historical data.**

This needs to be stated clearly and explored in observation-model PPCs.

---

# 21. Whole-badger annual trajectory sampler

```r
annual_nc_block <- c(
  paste0("A[", i_aa, ", 1, ", first[i_aa], "]"),
  paste0("A[", i_aa, ", 2, ", first[i_aa], "]"),
  unlist(lapply((first[i_aa] + 1L):K[i_aa],
    \(k_aa) paste0("u_move[", i_aa, ", 1:2, ", k_aa, "]")))
)

config$removeSamplers(annual_nc_block, print = FALSE)

config$addSampler(
  target = annual_nc_block,
  type = "AF_slice",
  control = list(sliceAdaptFactorMaxIter = AF_ADAPT_MAX)
)
```

**Meaning:** the initial annual location and all annual movement increments for one badger are updated together.

**Why:** annual trajectory coordinates are highly correlated.

**Status:** **Bespoke sampler choice**, motivated by general block-MCMC theory.

It must be judged by ESS, drift and cross-chain trajectory agreement—not assumed superior.

**Reference:** Turek et al. (2017) for blocking principles.

---

# 22. Interwoven movement-scale updates

Movement-scale parameters are updated before and again after the annual-trajectory sweep.

```r
config$addSampler(
  target = c("alpha_logmove_high", "beta_move_sex"),
  type = "AF_slice",
  control = list(sliceAdaptFactorMaxIter = AF_ADAPT_MAX)
)

config$addSampler(target = "beta_move_high", type = "slice")
```

**Meaning:** after the trajectories change, the scale parameters get another chance to respond immediately.

**Status:** **Bespoke sampler schedule**, conceptually related to interweaving strategies.

**Reference:** Yu & Meng (2011).

---

# 23. Built-in algebra checks

## HMM check

The code compares the forward recursion against explicit enumeration of all state paths for a short synthetic example.

**Purpose:** verifies the collapsed HMM is algebraically identical to summing over explicit states.

## Non-centred/Jacobian check

The code compares:

- the original displacement-space mixture density;
- the transformed `u`-space density;
- the Gaussian-reference + zeros-trick correction.

**Purpose:** verifies the annual-NC transformation preserves the intended posterior up to a constant.

**Status:** **Bespoke unit tests; important safeguards.**

---

# 24. What is established and what is ours?

| Component | Status |
|---|---|
| robust primary/secondary design | **Established** |
| distance-based SCR capture kernel | **Established** |
| latent activity centres | **Established** |
| changing annual activity centres | **Established in open/RD-SCR** |
| bivariate Gaussian spatial movement | **Established** |
| AR(1) within-year process | **Established mathematics; adapted** |
| local/high movement states | **Established HMM idea; adapted** |
| HMM analytical collapse | **Established** |
| non-centred innovations | **Established MCMC principle** |
| zeros trick | **Established computational device** |
| direct high-scale parameterisation | **Bespoke exact reparameterisation** |
| conditional within-quarter location likelihood | **Bespoke/adapted to missing effort** |
| whole-badger AF-slice trajectory block | **Bespoke sampler design** |
| second movement-scale update | **Bespoke/interweaving-inspired** |
| exact complete model combination | **Novel architecture** |

---

# 25. Main assumptions to remember

1. Annual primary periods; four quarterly secondary occasions.
2. Exact detector-night effort is unavailable.
3. Campaign activity is approximated from whether any successful capture occurred that quarter.
4. Number of repeated captures within a quarter is conditioned upon.
5. `rho` is restricted to positive persistence.
6. Annual and quarterly centres must lie on allowed habitat.
7. Movement densities are not explicitly renormalised near irregular boundaries.
8. Male:female movement-scale ratio is shared by local and high states.
9. High movement is constrained to exceed local movement.
10. Inference runs from first to last observed live year; survival/emigration are not modelled here.
11. Annual movement scale has computational support 0.5–2500 m.
12. Current season/period sum-to-zero priors are asymmetric.

---

# 26. What the current 300-badger ANNUALNC validation must show

It is not enough that the model compiles.

Compared with the centred annual sampler, we need:

- improved ESS for local movement/contrast;
- no systematic within-chain drift;
- much better cross-chain annual displacement agreement;
- much better cross-chain `P(high)` agreement;
- disappearance/reduction of alternative ~5 m versus several-hundred-metre trajectory modes.

Only then should ANNUALNC become the production parameterisation.

---

# Core literature trail

**SCR / activity centres**
- Efford, M. (2004). *Density estimation in live-trapping studies*. Oikos 106:598–610. DOI: 10.1111/j.0030-1299.2004.13043.x.
- Borchers, D.L. & Efford, M.G. (2008). *Spatially Explicit Maximum Likelihood Methods for Capture–Recapture Studies*. Biometrics 64:377–385. DOI: 10.1111/j.1541-0420.2007.00927.x.
- Royle, J.A., Chandler, R.B., Sollmann, R. & Gardner, B. (2013). *Spatial Capture-Recapture*. Academic Press.

**Robust/open SCR and movement**
- Pollock, K.H. (1982). *A capture-recapture design robust to unequal probability of capture*. Journal of Wildlife Management 46:752–757.
- Ergon, T. & Gardner, B. (2014). *Separating mortality and emigration: modelling space use, dispersal and survival with robust-design spatial capture–recapture data*. Methods in Ecology and Evolution 5:1327–1336. DOI: 10.1111/2041-210X.12133.
- Gardner, B. et al. (2018). *State space and movement specification in open population spatial capture–recapture models*. Ecology and Evolution 8:10336–10344. DOI: 10.1002/ece3.4509.

**State-space / movement states**
- Jonsen, I.D., Flemming, J.M. & Myers, R.A. (2005). *Robust state-space modeling of animal movement data*. Ecology 86:2874–2880.
- Patterson, T.A. et al. (2008). *State-space models of individual animal movement*. Trends in Ecology & Evolution 23:87–94.
- Morales, J.M. et al. (2004). *Extracting more out of relocation data: building movement models as mixtures of random walks*. Ecology 85:2436–2445.
- McClintock, B.T. et al. (2012). *A general discrete-time modeling framework for animal movement using multistate random walks*. Ecological Monographs 82:335–349.
- Langrock, R. et al. (2012). *Flexible and practical modeling of animal telemetry data: hidden Markov models and extensions*. Ecology 93:2336–2342. DOI: 10.1890/11-2241.1.

**Computation / parameterisation**
- Papaspiliopoulos, O., Roberts, G.O. & Sköld, M. (2007). *A General Framework for the Parametrization of Hierarchical Models*. Statistical Science 22:59–73. DOI: 10.1214/088342307000000014.
- Yu, Y. & Meng, X.-L. (2011). *To Center or Not to Center: That Is Not the Question—An Ancillarity–Sufficiency Interweaving Strategy (ASIS) for Boosting MCMC Efficiency*. JCGS 20:531–570.
- de Valpine, P. et al. (2017). *Programming with models: writing statistical algorithms for general model structures with NIMBLE*. JCGS 26:403–413.
- Turek, D. et al. (2017). *Automated Parameter Blocking for Efficient Markov Chain Monte Carlo Sampling*. Bayesian Analysis 12:465–490.
- Lunn, D. et al. (2013). *The BUGS Book*. CRC Press.
