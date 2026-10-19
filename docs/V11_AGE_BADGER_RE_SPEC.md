# Woodchester V11 movement model

## Decision

V10B is frozen as the reference movement model. V11 is the next biological
model; no further V10B continuation is required before developing V11.

V11 tests whether annual high-mobility entry is structured by current
chronological age and persistent individual mover propensity, while simplifying
the weakly supported quarterly AR(1) component.

## Inherited unchanged from V10B

- annual primary periods;
- Q1-Q4 trapping campaigns as secondary occasions;
- all spatially usable live captures retained within each quarter;
- quarter-level capture/non-capture plus conditional spatial-location
  likelihood;
- annual activity centres;
- two-state local/high annual movement process;
- sex effects already present in the movement model;
- analytically collapsed annual movement HMM;
- post-hoc forward-backward smoothing / FFBS;
- non-centred annual movement parameterisation;
- overlapping local annual-trajectory sampler;
- 0.5--2500 m numerical movement-scale support.

Recorded social group is not fitted in V11. The V10B audit showed that SG change
provides strong external validation of the inferred high-mobility state, so it
remains a downstream biological overlay rather than defining the state.

## Change 1: iid quarterly deviations

V10B estimated small positive rho and showed continuing local-movement/omega
scale confounding. V11 therefore fixes rho = 0.

For quarter q in badger-year t:

```
Q_i,t,q = A_i,t + omega * eps_i,t,q
eps_i,t,q ~ N2(0, I)
```

The expected radial distance of a quarter centre from the annual activity
centre remains omega * sqrt(pi/2). The expected distance between two independent
quarter centres is omega * sqrt(pi).

## Change 2: chronological age

Age-at-first-capture is not used as biological age.

The audited `age_by_year` table supplies chronological age where reconstructable.
Age is evaluated at the START of each annual movement interval.

The first V11 implementation uses:

- known age 0-1: reference;
- age 2;
- age 3-5;
- age 6+;
- chronological age unknown.

Adult first-capture animals with unknown exact birth year are retained using the
explicit unknown-age category. They are not assigned an arbitrary age and are
not removed.

A single set of age coefficients is shared between the initial movement
interval and later local-to-high transitions. This is intentionally
parsimonious.

## Change 3: persistent badger mover propensity

```
u_i ~ Normal(0, 1)
sigma_badger ~ Exponential(1)
b_i = sigma_badger * u_i
```

For the first annual movement interval:

```
logit P(high_i,1) =
    alpha_init
  + beta_init_sex * sex_i
  + age_effect_i,1
  + b_i
```

For later transitions from local to high:

```
logit P(z_i,t = high | z_i,t-1 = local) =
    alpha_RD
  + beta_RD_sex * sex_i
  + age_effect_i,t
  + b_i
```

For high-to-high persistence:

```
logit P(z_i,t = high | z_i,t-1 = high) =
    alpha_DD
  + beta_DD_sex * sex_i
```

The individual effect does NOT enter high-state persistence in V11. This lets
V11 answer the narrow question: does persistent individual propensity to ENTER
high mobility explain the repeat-mover concentration? If repeated/consecutive
high movement remains underpredicted, a later extension can allow b_i to affect
p_DD.

## Immediate validation

V11 should first be smoke-tested on a reproducible subset.

The model must:

1. compile and have finite initial log probability;
2. recover annual states with the V11 age- and badger-specific transition
   probabilities;
3. show acceptable three-chain behaviour for the new global parameters,
   especially sigma_badger and age effects;
4. retain the broad V10B annual movement picture;
5. reproduce repeat-mover concentration better than a model without persistent
   heterogeneity.

Key biological diagnostics after state recovery are:

- expected / robust high movements per badger;
- proportion of animals with at least two high events;
- maximum consecutive high-state run;
- share of high events carried by the top 10% of animals;
- Gini / concentration of high events;
- sex pattern;
- chronological-age pattern.

## Next model

If V11 is computationally usable and the mover effect is supported, the next
major development is survival / apparent emigration. The movement-only audit
showed that terminal high-mobility intervals are biologically ambiguous among
relocation, emigration, mortality and right censoring. That ambiguity should be
addressed before adding a more elaborate excursion state.

Disease follows the demographic extension, rather than being added directly to
the movement-only V11.
