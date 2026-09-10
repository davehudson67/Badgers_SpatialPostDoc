# Woodchester Park badger spatial modelling: complete development audit to V7

**Status:** Living modelling record  
**Audit date:** 27 August 2026  
**Current fitted movement model:** V6c  
**Next planned model:** V7, adding probabilistic infection state through time

---

## 1. Purpose of this document

This document records **why the Woodchester spatial model has the form it has now**, rather than presenting only the latest code.

The modelling process has been intentionally iterative. Several early models were useful precisely because they failed, mixed poorly, or revealed that a proposed biological classification was not identifiable. Those outcomes are part of the audit trail and should not be erased from the final methodological narrative.

The present endpoint is not a claim that the final model has already been reached. Instead:

- V6c is the current **movement-state scaffold**;
- V6c has produced an interpretable and computationally workable description of annual spatial stability and relocation;
- V7 will add probabilistic longitudinal bTB infection information;
- survival, explicit permanent emigration, finer spatial resolution, and alternative local-movement formulations remain sensitivity or later joint-model components.

---

# 2. Reproducible data architecture

The biological database is deliberately separated from the modelling scripts.

```text
Supabase / PostgreSQL
        |
        v
BadgerDatabase.R
  connection and database access only
        |
        v
DataPrep.R
  common biological preparation
        |
        v
fixed RDS snapshots
        |
        +--> movement / SCR models
        +--> audit scripts
        +--> disease models
```

The main biological snapshots used in the current model family are:

```text
data/badger_encounters_useful.rds
data/badger_individuals.rds
data/badger_CMRready.rds
data/badger_final_CMRready_wDisease.rds
data/badger_quarter_location_audit.rds
```

Spatial inputs are read separately, including:

```text
data/WoodchesterSettLocations.csv
data/spatial/V3_spatial_inputs_50m_2km.rds
```

### Why this matters

A model result should be reproducible against an immutable biological snapshot. Model scripts should not reconnect to Supabase or silently rerun database cleaning. If data preparation changes, a new snapshot should be produced and recorded.

---

# 3. Core data-preparation decisions behind the spatial model

The current prepared data arose from a database audit and encounter-level reconstruction rather than direct use of raw Access rows.

Key audit totals in the current canonical preparation were:

| Quantity | Current audit value |
|---|---:|
| Raw database capture records | 17,586 |
| Same-day biological encounters after live/PM fusion | 17,573 |
| Same-day live + PM combinations | 13 |
| PM-only individuals excluded from live CMR analysis | 567 |
| Individuals retained after PM-only exclusion | 3,224 |
| Biological encounters before quarterly collapse | 17,006 |
| Individual/year/quarter records after collapse | 15,506 |
| Records compressed by quarterly collapse | 1,500 |
| Individual/year/quarters containing >1 sett | 501 |
| Individual/year/quarters containing >1 recorded SG | 285 |

For continuous-space SCR, the important object is **`encounters_useful`**, i.e. the biological encounter-level dataset before the one-row-per-quarter collapse. A live spatial record is selected directly from true live encounters. This avoids the error of using a quarterly representative row that happened to be a PM record as a live detector location.

Within a badger/year/quarter containing multiple live sett locations, the current rule prefers:

1. a record differing from the individual's modal location, to retain relocation information;
2. otherwise the latest live encounter.

The current model uses years as primary occasions and four trapping quarters/seasons as secondary occasions.

### Incomplete 2026

The 2026 trapping year is incomplete. V6b and V6c therefore use:

```r
MAX_YEAR <- 2025L
```

This prevents unobserved 2026 quarters from being treated as genuine complete-year nondetections.

---

# 4. The central spatial distinction

From V1 onward, the model separates two different quantities that must never be conflated.

## 4.1 Within-year spatial detection scale

For an annual latent activity centre \(S_{it}\), capture probability declines with distance from \(S_{it}\) to detector sett \(r\):

\[
g_{irt} = \exp\left(
-\frac{\|x_r-S_{it}\|^2}{2\sigma_{\mathrm{det},i}^2}
\right).
\]

`alpha_logsigma` and `beta_sigma_sex` describe this **detection / within-period space-use scale**.

## 4.2 Between-year activity-centre displacement

The movement model describes:

\[
S_{i,t}\rightarrow S_{i,t+1}.
\]

Its scale is represented by `sigma_move`, or by state-specific movement scales in V6 onward.

These are conceptually different:

```text
detection sigma
    = how capture locations are distributed around the annual AC

movement sigma
    = how the annual AC itself changes between years
```

This distinction becomes particularly important when comparing the current work with Ketwaroo et al. (2025), whose disease-associated `sigma` describes spatial detection/home-range scale around an activity centre that is fixed across the study, rather than annual AC relocation.

---

# 5. Model-development timeline

## 5.1 Early social-group HMM branch

An earlier project branch represented space discretely using social groups. Living states were social groups, with additional newly-dead and long-dead states. The network HMM was useful because it could model:

- apparent survival;
- detection;
- same-group retention;
- neighbour versus non-neighbour movement;
- dead recovery.

This branch remains scientifically useful, particularly for social-group turnover. However, the continuous-space branch was pursued because it preserves actual sett coordinates and separates the annual activity centre from the sett at which an animal happened to be caught.

---

## 5.2 V1: continuous-space robust-design baseline

### Biological question

Can the long-term capture history support simultaneous estimation of annual survival, spatial detection, and annual AC displacement?

### Structure

- primary occasions: years;
- secondary occasions: four trapping periods within a year;
- detector locations: actual sett coordinates;
- annual latent AC;
- annual survival;
- half-normal spatial detection;
- exponential annual movement distance plus random direction;
- entry-history groups: first caught Cub/Yearling versus first caught Adult.

The original V1 documentation explicitly treated adult-entry as an **entry-history group**, not confirmed immigrant status.

### Main problem

Movement was biologically interpretable, but the large set of latent movement distances and directions produced poor MCMC mixing, especially for population-level movement parameters.

### Decision

Retain robust-design spatial logic, but reparameterize movement.

---

## 5.3 M2: direct bivariate AC transition

M2 replaced distance-plus-angle movement with:

\[
S^x_{i,t+1}\sim N(S^x_{it},\sigma_{\rm move}^2)
\]

\[
S^y_{i,t+1}\sim N(S^y_{it},\sigma_{\rm move}^2).
\]

The implied radial displacement is Rayleigh distributed.

M2 also made the first activity centre latent rather than fixing it exactly to the first capture sett.

### Why this was useful

It removed unnecessary latent distance and angle variables and gave a much cleaner continuous-space random walk.

### Remaining limitation

The landscape was still essentially Euclidean and featureless.

---

## 5.4 V3: habitat and social-group spatial structure

V3 introduced:

- a 50 m GIS state-space grid;
- valid terrestrial habitat;
- social-group identity for each grid cell;
- a peripheral/buffer region;
- a likelihood penalty for annual endpoints in a different SG.

The important conceptual lesson was that an endpoint penalty is not equivalent to a fully normalized movement kernel. If changing SG is penalized without accounting for how much destination area is available in each spatial category, the SG parameter can partially reflect landscape geometry.

### Decision

Move toward a **normalized landscape-dependent movement process**.

---

## 5.5 V4/V4c: heavy-tailed movement and normalized SG/peripheral resistance

The next family added:

- non-centred bivariate Student-\(t_3\) annual movement;
- explicit SG and peripheral resistance;
- precomputed normalization masses over the 50 m landscape;
- interpolation over a grid of movement scales;
- custom NIMBLE functions and sampler changes for computational tractability.

The Student-\(t\) kernel was introduced to protect the model against occasional long steps that a Gaussian random walk might fit poorly.

### Key advance

Movement distance and landscape resistance were no longer treated independently: the expected destination mass available in same-SG, other-SG, and peripheral habitat was normalized for the current movement scale.

---

## 5.6 V5c: latent immigrant status for adult-entry badgers

### Motivation

Adult-entry badgers might contain a higher fraction of immigrants. V5c therefore asked whether an inferred entry-origin class predicted subsequent movement.

### Structure

- 800 badgers, adult-enriched;
- maximum 400 adult-entry animals;
- latent immigrant status only for adult-entry animals;
- immigrant status inferred **without sex**;
- immigrant effect on movement only;
- sex effects retained on survival, detection, detection scale and movement;
- Student-\(t_3\) movement;
- normalized SG/peripheral resistance.

### Result

The immigrant movement coefficient appeared strongly positive:

\[
\beta_{\rm move,imm}\approx 0.79
\]

with posterior median approximately 0.93, implying a movement-scale ratio on the order of \(e^{0.8}\) to \(e^{0.93}\), roughly 2.2–2.5.

However, the effective sample size was only approximately 5–6.

### Interpretation

The coding was checked and the adult-entry indexing was correct. The result was therefore not rejected because of a coding mistake; it was rejected as **too poorly mixed to support biological inference**.

### Scientific lesson

A permanent “immigrant” class at entry is not the same thing as subsequent movement behaviour.

A locally born animal can later disperse, and an immigrant can settle.

This motivated replacing the permanent entry class with a **time-varying movement state**.

---

# 6. V6: latent movement phenotype

V6 introduced a first-order Markov movement state:

\[
D_{it}\in\{0,1\}
\]

where state 1 was identified as the higher-movement state by constraining:

\[
\beta_{\rm move,disp}>0.
\]

The initial version included both:

1. a persistent individual movement random effect `move_re[i]`; and
2. a temporary resident/disperser state `disp[i,t]`.

This was intended to distinguish:

- persistent low movers;
- persistent high movers;
- temporary dispersers;
- repeated dispersal episodes.

### Computational problems found

The first V6 build exposed several important implementation issues:

- model construction was extremely slow;
- an initialization mismatch produced `-Inf` log probability because movement parameters used to construct `eps` were redrawn before being supplied to NIMBLE;
- the fix was to draw movement parameters once and use exactly those values both to construct `eps` and to initialize the model;
- `AF_slice` was incorrectly assigned to scalar `move_re_raw[i]` nodes; scalar slice sampling or the default sampler was required;
- long latent movement tails were being propagated to the end of the study for animals with unknown death;
- persistent individual heterogeneity and the latent movement state could explain the same variation.

### Deeper statistical problem

V6 also combined:

- a heavy-tailed \(t_3\) movement kernel; and
- a high-movement latent state.

Both mechanisms could explain a long movement.

Thus:

```text
long move
   |
   +--> tail of the resident t distribution
   |
   +--> high-mobility latent state
```

This created a structural identifiability problem.

---

# 7. V6a: optimized two-state Student-t model

V6a was deliberately simplified:

- persistent individual movement RE removed;
- animals required at least two observed live years;
- four global sex × state movement scales;
- latent states not saved during development;
- default multivariate NIMBLE samplers retained for 2-D movement innovations.

## 7.1 Computational result

| Stage | V6a elapsed time |
|---|---:|
| Model build | 54 s |
| MCMC build | 259 s |
| Compile | 468 s |
| MCMC run | 17,155 s (~4 h 46 min) |

## 7.2 Main posterior diagnostics

| Parameter | Estimate | Rhat | ESS |
|---|---:|---:|---:|
| `alpha_logmove` | 3.81 | 1.60 | 6 |
| `beta_move_sex` | 0.36 | 2.56 | 16 |
| `beta_move_disp` | 2.28 | 1.84 | 5 |
| `p_RD` | 0.168 | 1.30 | 6 |
| `p_DD` | 0.314 | 1.12 | 15 |
| female resident sigma | 48 m | 1.62 | 5 |
| male resident sigma | 69 m | 1.61 | 8 |
| female disperser sigma | 457 m | 2.81 | 9 |
| male disperser sigma | 652 m | 1.06 | 8 |

The detection block mixed much better than the movement-state block.

### Decision

Do **not** interpret V6a biologically and do not solve it merely by adding iterations.

The movement-state formulation needed to change.

---

# 8. V6b: clean stable/local versus high-mobility state

V6b made the decisive structural changes:

1. cap analysis at 2025;
2. retain only badgers with at least two observed live years;
3. stop each animal's movement process at its **last observed live year**;
4. retain missing years *between* first and last live observations;
5. remove the individual movement RE;
6. replace Student-\(t_3\) movement with state-specific Gaussian movement;
7. constrain the high-mobility state to have a larger movement scale;
8. condition survival out for this movement-development model.

This means V6b was **not** intended as a final survival model. It was a targeted experiment asking whether the annual spatial histories support a distinguishable high-mobility state.

## 8.1 Computational improvement

| Stage | V6a | V6b |
|---|---:|---:|
| Model build | 54 s | 31 s |
| MCMC build | 259 s | 14 s |
| Compile | 468 s | 133 s |
| MCMC | 17,155 s | 4,258 s |

The MCMC itself was approximately four times faster.

## 8.2 V6b movement results

| Quantity | Posterior summary |
|---|---:|
| female resident sigma | ~11.6 m |
| male resident sigma | ~11.7 m |
| female high-mobility sigma | ~865 m |
| male high-mobility sigma | ~870 m |
| `p_RD` | ~0.055 |
| `p_DD` | ~0.294 |
| `beta_disp_adult` | ~0 |
| `beta_move_sex` | ~0 |

Crucially:

- `p_RD` Rhat ≈ 1.03, ESS ≈ 838;
- `p_DD` Rhat ≈ 1.02, ESS ≈ 509;
- `beta_move_disp` Rhat ≈ 1.04, ESS ≈ 103.

This was a major improvement over V6a.

### Remaining concern

The local scale was close to the lower support (10 m), while the high-mobility scale approached the upper support (1,200 m).

Therefore V6b could not yet establish that the separation was robust to the arbitrary movement-scale limits.

---

# 9. V6c: wide-support robustness test and sex-specific state transitions

V6c widened the movement normalization support:

```text
V6b: 10–1200 m
V6c:  5–2500 m
```

It also explicitly separated four possible effects of sex:

1. sex effect on movement distance **within a state**;
2. sex effect on initial high-mobility probability;
3. sex effect on stable/local → high-mobility transition;
4. sex effect on persistence in the high-mobility state.

This distinction is essential. A male-biased movement pattern could arise because males:

- move farther once moving;
- move more often;
- start the study in a different state;
- remain in a high-mobility state longer.

A post-hoc male:female ratio cannot distinguish these mechanisms.

---

# 10. V6c numerical results

## 10.1 Movement scale

| Parameter | Mean | 95% CrI | Rhat | ESS |
|---|---:|---:|---:|---:|
| `beta_move_sex` | -0.060 | [-0.317, 0.182] | 1.01 | 105 |
| `beta_move_disp` | 4.802 | [4.371, 5.112] | 1.02 | 779 |
| female local sigma | 7.0 m | [5.16, 10.55] | 1.01 | 900 |
| male local sigma | 6.6 m | [5.06, 10.12] | 1.01 | 811 |
| female high-mobility sigma | 843 m | [713, 1022] | 1.15 | 88 |
| male high-mobility sigma | 796 m | [643, 1008] | 1.11 | 60 |

### Interpretation

The high-mobility scale remained near 0.8–1 km after the upper movement support was expanded from 1.2 km to 2.5 km. This strongly reduces the concern that V6b's high-mobility component was simply being forced against its upper boundary.

The high-mobility scale itself still mixes less well than the transition parameters, so its precise numerical value should be treated as developmental rather than final.

The local sigma moved downward toward the new lower bound. This is now understood as the Gaussian local component trying to approximate a large spike of **unchanged annual sett location**, not evidence that badgers literally move only 7–9 m biologically.

---

## 10.2 Sex and movement-state transitions

| Quantity | Posterior mean / CrI |
|---|---|
| `beta_disp_init_sex` | 0.143 [-0.845, 1.109] |
| `beta_RD_sex` | **0.705 [0.087, 1.329]** |
| `beta_DD_sex` | -0.521 [-1.915, 0.761] |
| \(P(R\rightarrow D)\), female | **0.046** [0.030, 0.065] |
| \(P(R\rightarrow D)\), male | **0.090** [0.054, 0.132] |
| \(P(D\rightarrow D)\), female | 0.307 [0.133, 0.512] |
| \(P(D\rightarrow D)\), male | 0.218 [0.061, 0.437] |

The best-supported sex effect is therefore on the **probability of entering the high-mobility state**.

There is currently little evidence that males travel farther than females conditional on state.

A concise interpretation is:

> Males and females have broadly similar movement magnitudes conditional on movement state, but males have approximately twice the annual probability of switching from the stable/local state into a high-mobility/relocation state.

This result is well mixed (`beta_RD_sex` Rhat ≈ 1.00; ESS ≈ 898).

---

# 11. V6c landscape results

V6c estimated approximately:

\[
\beta_{SG}\approx0.10
\]

and

\[
\beta_{\rm peripheral}\approx4.37.
\]

The SG penalty is weak and uncertain. The peripheral penalty is large.

This should **not yet** be interpreted as a definitive ecological statement about boundaries, because the movement kernel and normalization interact with state-space geometry. The large peripheral penalty may partly be required to prevent the broad high-mobility kernel from placing ACs in inappropriate peripheral space.

Landscape coefficients therefore remain sensitivity targets.

---

# 12. Empirical movement audit

The raw observed annual-location audit is important because it reveals what the latent model is trying to explain.

Across 1,257 observed transitions between annual representative locations:

| Year gap | Number |
|---:|---:|
| 1 | 1,043 |
| 2 | 149 |
| 3 | 37 |
| 4 | 18 |
| 5 | 6 |
| 6 | 1 |
| 7 | 3 |

Most observed transitions therefore span adjacent years.

## 12.1 Consecutive-year movement

For the 1,043 adjacent-year transitions:

- 657, or **63.0%**, have exactly the same observed sett coordinate;
- median observed displacement = **0 m**;
- 75th percentile ≈ **185 m**;
- 90th percentile ≈ **387 m**;
- 95th percentile ≈ **544 m**;
- 99th percentile ≈ **1.33 km**;
- maximum ≈ **3.80 km**.

This is strong empirical evidence for:

```text
large mass at spatial stability / same sett
              +
long relocation tail
```

The V6c local sigma should therefore not be interpreted literally as an 8 m annual biological step. It is a continuous Gaussian approximation to a process with very strong annual spatial fidelity at the sett-observation scale.

---

# 13. Does the latent high-mobility state mean what we think it means?

Posterior high-mobility probability was joined to observed adjacent-year displacement.

| Observed displacement | n | Mean P(high mobility) | Median | Fraction with P >= 0.8 |
|---|---:|---:|---:|---:|
| 0 m | 657 | 0.013 | 0.003 | 0.003 |
| 1–250 m | 175 | 0.028 | 0.005 | 0.006 |
| 251–500 m | 152 | 0.104 | 0.013 | 0.066 |
| 501–1000 m | 43 | 0.462 | 0.331 | 0.349 |
| >1000 m | 16 | **0.940** | **1.000** | **0.875** |

This is not an independent validation—movement distance contributes to the inference of the state—but it demonstrates that the latent state has a clear and sensible ecological interpretation.

The high-mobility state is overwhelmingly associated with large-scale annual relocation.

---

# 14. Are there two types of badger?

No such claim is supported at present.

A first descriptive classification mistakenly labelled one-interval animals as “persistent high mobility”, because a single high posterior probability automatically produced a high mean, first, and last state probability.

The classification was corrected to require at least three intervals for persistence.

The corrected 500-animal classification is:

| Movement pattern | n | % |
|---|---:|---:|
| Strongly resident/stable | 421 | 84.2 |
| Mixed or uncertain | 35 | 7.0 |
| Episodic disperser | 21 | 4.2 |
| Became disperser | 12 | 2.4 |
| Single high-mobility event | 8 | 1.6 |
| Disperser then settled | 2 | 0.4 |
| Persistent high mobility | 1 | 0.2 |

There were 1,581 latent movement intervals in total:

- 70 had \(P(D)\ge0.5\);
- 50 had \(P(D)\ge0.8\);
- mean \(P(D)=0.061\);
- median \(P(D)=0.0055\).

### Current biological interpretation

The evidence is much more consistent with:

> **a dominant stable/local state with rarer episodic relocation/high-mobility events**

than with:

> two permanent kinds of badger.

One individual currently satisfies the deliberately strict descriptive definition of persistent high mobility, but repeated high-mobility phenotypes require further study rather than being assumed a priori.

---

# 15. Recommended terminology

Use:

- stable/local movement state;
- high-mobility/relocation state;
- dispersal/relocation episode;
- probability of entering the high-mobility state;
- state persistence.

Avoid:

- “resident badger” and “disperser badger” as immutable lifetime categories;
- “two types of badger”;
- calling every large movement permanent dispersal;
- interpreting an annual latent AC transition as the animal's literal path travelled.

---

# 16. Why V6c is currently the preferred V7 scaffold

V6c has now passed several important tests:

1. the latent movement-state concept is computationally estimable;
2. transition parameters mix well;
3. high-mobility separation persists when movement support is widened;
4. posterior state probability increases coherently with observed relocation distance;
5. high mobility is mostly episodic rather than a fixed individual class;
6. sex appears to affect the transition into high mobility rather than movement magnitude conditional on state.

A complete spike-and-slab/stay-versus-relocate model remains a useful sensitivity analysis, especially because the local Gaussian component collapses toward zero. However, it is not necessary to delay disease integration merely to replace V6c.

---

# 17. V7: planned infection–movement model

The exact implementation will depend on the form in which the probabilistic annual infection histories arrive.

The first V7 model should not dichotomize infection probability using an arbitrary threshold.

## 17.1 Infection -> future high mobility

The central movement transition becomes:

\[
\mathrm{logit}\left[
P(D_{i,t+1}=1\mid D_{it}=0)
\right]
=
\alpha_{RD}
+
\beta_{RD,\mathrm{sex}}\,Sex_i
+
\beta_{RD,\mathrm{inf}}\,I_{it}
+\ldots
\]

where \(I_{it}\) is the probabilistic or latent infection state at the **start of the movement interval**.

The key parameter is:

\[
\boxed{\beta_{RD,\mathrm{inf}}}
\]

which tests:

> Does infection increase or decrease the probability that a currently stable/local badger enters a high-mobility/relocation episode during the next annual transition?

## 17.2 Movement -> future infection

For animals not yet infected:

\[
\mathrm{logit}\left[
P(I_{i,t+1}=1\mid I_{it}=0)
\right]
=
\alpha_I
+
\beta_{I,D}D_{it}
+
\ldots
\]

This asks:

> Does high-mobility/relocation precede increased probability of infection acquisition?

These are different hypotheses and should not be collapsed into a single contemporaneous association.

---

# 18. How to use probabilistic infection histories

Preferred hierarchy:

## Best case: posterior infection-state draws are available

Use posterior infection draws directly, preserving correlation through time.

Possible strategies include:

- joint model if the infection model can be embedded safely;
- posterior cut / modular approach;
- repeated movement-model fits over infection-state draws;
- integrated likelihood if computationally feasible.

## If only annual posterior infection probabilities are available

Do not set:

```r
infected <- p_infected > 0.5
```

Instead use uncertainty propagation, such as posterior multiple imputation / Monte Carlo integration.

The exact method should depend on how those probabilities were generated. If movement or survival data contributed to the infection posterior, blindly reusing them as an independent covariate could double-use information.

---

# 19. Relationship to Ketwaroo et al. (2025)

Ketwaroo et al. developed an open SCR model for the same Woodchester system that jointly models:

- latent presence;
- latent binary infection;
- imperfect DPP, IFN and culture results;
- disease-dependent survival;
- disease-dependent baseline encounter;
- disease-dependent spatial detection scale;
- density-dependent infection transition;
- abundance and prevalence.

Their case study found lower survival and larger space-use scale in infected badgers.

The crucial difference is spatial dynamics:

\[
s_{it}=s_i
\]

in their model—the activity centre is fixed over the analysed period.

Their Discussion explicitly identifies dynamic AC movement, including Markovian random walks, as a natural model extension.

The current Woodchester V6c/V7 programme therefore should not be framed as simply repeating “infected badgers range more widely”. Its distinctive target is:

> whether probabilistic infection history predicts **transitions into actual between-year AC relocation/high-mobility states**, and whether those movement episodes in turn predict later infection.

---

# 20. Important limitations to carry into V7

## 20.1 Selection on >=2 live years

The movement-development sample requires at least two observed live years. This conditions on future survival/detection.

Therefore V6b/V6c are not final population survival analyses.

## 20.2 Movement after last live observation

V6b/V6c deliberately stop movement at the last observed live year. This avoids decades of weakly identified latent movement, but means movement and post-disappearance survival/emigration are not yet jointly estimated.

## 20.3 Multi-year capture gaps

Most movement information is adjacent-year, but some intervals span multiple years. A relocation between observations five years apart cannot be assigned confidently to a particular annual interval.

For directional infection analyses:

- adjacent-year transitions should receive particular attention;
- multi-year gaps can remain in the latent model;
- sensitivity analyses should distinguish direct observed-year transitions from gap-imputed state histories.

## 20.4 50 m state-space grid

The AC is continuous, but SG/peripheral normalization is evaluated on a 50 m grid.

Because the local movement component is currently smaller than one grid cell, a 25 m grid sensitivity is advisable before interpreting local movement scale or small-scale SG resistance literally.

## 20.5 Movement kernel / state structure

A two-state model will partition heterogeneous movement if instructed to do so. Formal support for a biologically discrete two-state process requires comparison with alternatives such as:

- one-state movement;
- continuous random-effects heterogeneity;
- spike-and-slab/local-relocation model;
- possibly semi-Markov state persistence.

The present evidence supports the **utility and interpretability** of the two-state representation, not ontological proof that movement biology consists of exactly two discrete processes.

## 20.6 Peripheral resistance

The very large peripheral penalty may interact with the broad high-mobility kernel and state-space boundary.

Sensitivity to buffer width, state-space extent, and alternative peripheral parameterizations is required.

## 20.7 Detection effort

Exact detector-specific historical trapping effort is unavailable. Seasonal and broad temporal detection terms absorb part of the observation heterogeneity, but cannot reconstruct exact sett-by-quarter effort.

---

# 21. Minimum V7 model sequence

A defensible staged sequence is:

### V7a: infection -> relocation
Movement scaffold = V6c.  
Add probabilistic infection at \(t\) to \(R\rightarrow D\) at \(t\rightarrow t+1\).

### V7b: movement -> infection
For susceptible animals, add movement state/event at \(t\) as a predictor of infection transition by \(t+1\).

### V7c: reciprocal / joint co-dynamics
Only after V7a/V7b are stable, consider a joint process in which movement and infection co-evolve.

### V7d: demographic integration
Add infection-dependent survival and potentially detection/space-use effects, benchmarked against the published Woodchester disease-SCR literature.

### Sensitivity models
- fixed/regularized local movement scale;
- 25 m grid;
- alternate movement kernels;
- consecutive-year subset;
- full versus restricted historical periods;
- management-era effects;
- alternative infection uncertainty propagation.

---

# 22. What can be stated now

Reasonable developmental conclusions are:

1. annual badger spatial histories contain a dominant stability/local-fidelity component plus a rarer long-relocation component;
2. a latent high-mobility state has a coherent relationship with observed relocation distance;
3. high mobility appears predominantly episodic rather than a persistent lifetime classification;
4. males have higher estimated probability of entering the high-mobility state;
5. there is little current evidence that males move farther than females conditional on state;
6. the current movement framework is suitable for testing temporally directed movement–infection hypotheses once probabilistic infection histories are available.

---

# 23. What should not yet be claimed

Do **not** yet claim:

- that there are “two types of badger”;
- that resident badgers move only 7–9 m per year;
- that the exact high-mobility scale is fully converged;
- that weak SG resistance means social groups do not constrain movement;
- that the peripheral coefficient is a literal biological barrier effect;
- that males disperse twice as far as females;
- that infection causes dispersal;
- that dispersal causes infection;
- that survival has been corrected for permanent emigration in V6c;
- that V7 is already fitted.

---

# 24. Reproducibility checklist before publication

- [ ] Freeze the exact `DataPrep.R` and RDS versions used.
- [ ] Record spatial input file hashes.
- [ ] Record NIMBLE/R/package versions.
- [ ] Record random seeds and sampled tattoo set internally.
- [ ] Confirm 2026 handling.
- [ ] Audit duplicate sett-coordinate rows.
- [ ] Repeat state-space/grid sensitivity.
- [ ] Repeat buffer/peripheral sensitivity.
- [ ] Compare two-state movement against one-state/continuous alternatives.
- [ ] Check trace plots as well as Rhat/ESS.
- [ ] Conduct posterior predictive checks on movement-distance distribution.
- [ ] Check high-mobility classification under alternative posterior thresholds.
- [ ] Repeat key inference using adjacent-year movement evidence only.
- [ ] Document how probabilistic infection uncertainty is propagated.
- [ ] Avoid double use of diagnostic/movement data across modular models.
- [ ] Define time ordering of infection and movement explicitly.
- [ ] Separate exploratory model-development results from final inferential estimates.

---

# 25. Final status at the V6c -> V7 transition

The modelling history has moved from a generic continuous random walk, through explicit landscape normalization and an unsuccessful permanent immigrant classification, to a dynamic movement-state formulation.

The most important conceptual change is:

```text
OLD QUESTION
Are some adult-entry badgers a permanently different "immigrant" class?

CURRENT QUESTION
When does an individual enter a high-mobility relocation state,
what predicts that transition, and what happens epidemiologically afterwards?
```

That is the question V7 is designed to answer.
