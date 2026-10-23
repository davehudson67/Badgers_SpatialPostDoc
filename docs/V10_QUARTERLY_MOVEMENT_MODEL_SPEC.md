# Woodchester V10 quarterly movement model specification

> **SUPERSEDED FOR PRIMARY IMPLEMENTATION.** This document records the exploratory
> pure-quarterly state-space formulation. The primary V10a development now keeps
> **year as the robust-design primary period** and Q1-Q4 as secondary trapping
> campaigns, while adding quarter-specific spatial-use centres around an annual
> activity centre. See `docs/V10A_RD_SCR_MULTILOC_SPEC.md`.

## Why V10 exists

V8/V9 reduce each badger/year/quarter to one representative capture location and then
model one latent activity centre per year. Audits of the 1,932-badger movement
population showed that this discards genuine information:

- 14,049 spatially usable live encounters occur in 12,907 observed badger-quarters.
- 1,076 quarters contain more than one live capture.
- 443 quarters contain captures at more than one recognised sett.
- A badger has at most 3 spatially usable live captures and at most 3 unique setts
  in a quarter in the current snapshot.
- Multi-sett quarters span substantial distances and several weeks.

Trapping within a quarter occurred over several nights and different parts of the
study area were trapped on different nights. Exact historic trap deployment/effort
for every night is not available. Therefore capture order within a quarter must not
be interpreted automatically as the animal's literal movement path, and a nightly
SCR likelihood must not assume that all setts were simultaneously available.

V10 therefore uses all genuine capture locations in their true quarter, treats them
as repeated spatial observations of a latent quarterly centre of use, and models
movement of that centre between quarters.

## What the latent state means

For badger i and calendar quarter t,

    S[i,t] = (Sx[i,t], Sy[i,t])

is the latent centre of the animal's spatial use during that quarter.

It is not:

- the exact position of the badger on a particular trapping night;
- necessarily the sett at which the animal lived;
- a manually selected "representative" sett;
- a back-filled capture location.

A quarter with no capture still has a latent S[i,t]. It is inferred from the
movement process and neighbouring observed quarters.

## Observation data

Let n[i,t] be the number of spatially usable live captures for badger i in quarter t.
For capture m = 1,...,n[i,t], let

    x[i,t,m] = (x, y)

be the coordinate of the recognised capture sett.

All captures are retained. For example,

    Q1: A
    Q2: A, A
    Q3: no capture
    Q4: A, B

remains exactly that. Q3 is not changed into a capture quarter and neither A nor B
is discarded from Q4.

Capture dates are retained for provenance/audits but the order of captures within a
quarter is not used as a movement trajectory in the primary V10 model because trap
placement changed among nights.

## Conditional spatial observation model

The primary V10 movement fit conditions on the fact that these captures occurred.
It does not attempt to reconstruct unknown nightly trap effort.

Each observed capture location is treated as a repeated observation around the
quarterly latent centre:

    x[i,t,m] | S[i,t], tau[i] ~ Normal_2(S[i,t], tau[i]^2 I)

Equivalently, the location contribution to the log likelihood is

    log L_obs =
      sum_i sum_t sum_m [
        -log(2*pi*tau[i]^2)
        - ||x[i,t,m] - S[i,t]||^2 / (2*tau[i]^2)
      ]

where tau is a within-quarter spatial-use / capture-location scale.

Interpretation of tau:

- tau is NOT between-quarter movement;
- tau absorbs the spatial spread of capture locations around the quarter's centre;
- repeated captures at the same sett provide repeated evidence for that location;
- captures at multiple setts pull the latent centre toward the spatial pattern
  observed during that quarter.

A planned sensitivity will collapse repeated same-sett captures within a quarter to
one unique-sett observation. Comparing it with the all-captures fit tests whether
repeat captures at the same sett exert too much weight.

### Why the primary V10 fit is conditional on captures

A full SCR encounter likelihood would require the set of traps/detectors available
on each trapping occasion (or a defensible effort measure). The historic database
contains capture dates and locations but not a complete trap-night deployment
history. Different parts of the study area were trapped on different nights.

Therefore V10a does not treat an animal's lack of capture at all other setts on a
given night as observed detector-level non-detections.

This changes the model's purpose: V10a is a movement state-space model for known
badgers, not an abundance SCR model.

A future effort-aware extension can replace the conditional observation model if a
reliable historic detector-effort mask becomes available.

## Quarterly movement process

For each badger, latent quarterly centres exist from its first spatially usable live
quarter through its last spatially usable live quarter.

For t > first[i],

    S[i,t] = S[i,t-1] + epsilon[i,t]

with

    epsilon[i,t] ~ Normal_2(0, sigma_move[i,t]^2 I)

and

    log sigma_move[i,t] =
        alpha_logmove
      + beta_move_sex * sex[i]
      + beta_move_state * z[i,t]

where

    z[i,t] = 0  local/stable movement state
    z[i,t] = 1  high-mobility/relocation state

and beta_move_state > 0 so that the high-mobility state has a larger movement scale.

The realised quarterly displacement is

    D[i,t] = ||S[i,t] - S[i,t-1]||

and under the isotropic Gaussian increment model it follows a Rayleigh distribution
conditional on sigma_move, with mean

    E[D | sigma_move] = sigma_move * sqrt(pi/2).

The quarterly movement scales must be re-estimated. Annual V8 movement scales are
not copied directly into V10.

## Movement-state process

The first movement interval for each animal has

    z[i, first[i]+1] ~ Bernoulli(p_init[i])

with an initial model such as

    logit(p_init[i]) =
        alpha_init
      + beta_init_sex * sex[i]
      + beta_init_adult * adult_entry[i].

Subsequent states follow a two-state Markov process:

    p_RD[i,t] = P(z[i,t]=1 | z[i,t-1]=0)
    p_DD[i,t] = P(z[i,t]=1 | z[i,t-1]=1)

with initial core specification

    logit(p_RD[i,t]) = alpha_RD + beta_RD_sex * sex[i]
    logit(p_DD[i,t]) = alpha_DD + beta_DD_sex * sex[i].

Quarter/season effects are scientifically plausible and should be tested after the
core quarterly model is stable rather than inserted silently at the first fit.

## Habitat/state-space constraint

Quarterly centres S[i,t] must lie in the valid Woodchester habitat state space.
The existing V8 habitat grid and boundary machinery can be reused.

The initial centre S[i,first[i]] receives a spatial prior over valid habitat.
Subsequent centres are generated by the movement process and rejected/penalised if
they fall outside valid habitat.

## Landscape/social-group effects

The first V10 movement fit should validate the new temporal and observation
architecture before adding the V8 social-group/peripheral resistance terms.

Planned sequence:

1. V10a: quarterly centres + all capture locations + two-state movement.
2. V10b: add landscape/peripheral resistance.
3. V10c: add time-varying social-group boundaries once the bait-marking territory
   histories have been encoded.
4. Disease modules: use posterior quarterly movement histories rather than forcing
   disease analyses to define the movement population.

The old static SG map must not be interpreted as the historical territory map for
the entire 1975-2025 period.

## Survival and availability

V10a remains conditional on the observed live history:

- an animal enters at its first spatially usable live quarter;
- it is assumed available/alive through its last spatially usable live quarter;
- internal missing quarters are latent spatial states, not deaths;
- quarters after the last observed live quarter are not used to infer mortality.

Survival/emigration is a later extension and must not be inferred from the
movement-only model.

## Individual covariates

Population audit for the current 1,932-badger movement pool:

- all 1,932 have known sex;
- 1,756 have exact/near-exact chronological age reconstructable from cub/yearling
  entry;
- 176 entered as adults and must remain in the model with exact age unknown.

Adult entry is therefore a valid entry-class covariate but must not be described as
known chronological age or as proof of immigration.

## Likelihood factorisation

For individual i, conditional on its first and last spatially usable quarters,

    L_i =
      p(S[i,f_i])
      *
      product_{t=f_i+1}^{l_i}
        p(z[i,t] | z[i,t-1], covariates)
        p(S[i,t] | S[i,t-1], z[i,t], covariates)
      *
      product_{t=f_i}^{l_i}
        product_{m=1}^{n[i,t]}
          p(x[i,t,m] | S[i,t], tau[i]).

For n[i,t] = 0, that quarter contributes no spatial observation term. Its state is
inferred from the movement process and observations before/after it.

This is the central distinction from manual back-filling: missing-quarter locations
are inferred probabilistically rather than created from captures that happened at
another time.

## What the data identify

The repeated-capture structure allows the model to separate two scales:

1. tau: within-quarter spread of capture locations around a quarterly centre;
2. sigma_move: movement of the quarterly centre between successive quarters.

This separation is essential. Raw sett-to-sett capture distances contain both
within-quarter space use and longer-term relocation.

## Primary sensitivities

The first V10 analysis should include at least:

1. all capture events vs one observation per unique sett per quarter;
2. Gaussian vs a more robust observation kernel if posterior predictive checks
   show excessive influence from rare long-distance within-quarter observations;
3. consecutive-quarter-only movement summaries vs histories containing latent
   internal quarters;
4. sex effects vs no sex effects;
5. one-state continuous movement vs the two-state local/high-mobility model.

## Posterior checks required before disease modelling

- within-quarter capture-distance distribution replicated by the model;
- distribution of quarter-to-quarter observed displacements;
- posterior predictive frequency of multi-sett capture quarters;
- movement-state chain mixing and state-label stability;
- sensitivity of state occupancy to observation model;
- sensitivity of high-mobility classification to long internal gaps;
- comparison with the legacy annual V8/V9 movement results.

## Terminology

Use:

- "quarterly centre of spatial use" or "quarterly latent centre";
- "within-quarter observation/spatial-use scale" for tau;
- "quarterly movement scale" for sigma_move;
- "high-mobility/relocation state" for z=1.

Avoid describing S as the animal's exact location or describing within-quarter
capture order as a known movement path.
