WOODCHESTER V7a-M: infection -> subsequent high mobility

Model
-----
For movement-state transitions whose previous state is local:

logit P(high_t = 1) =
    alpha + beta_inf * infected_origin + beta_sex * sex

infected_origin = infection acquired by Q4 of the current movement interval's
origin year.

The first movement interval is excluded because it is an initial state rather
than an R->high transition.

Why no 1,500 NIMBLE fits?
-------------------------
Conditional on one paired movement/infection history, the model has only three
coefficients and four unique covariate strata:
female/male x uninfected/infected.

The script therefore evaluates the exact grouped binomial likelihood, finds the
posterior mode, uses an inflated Laplace MVN only as an IMPORTANCE-SAMPLING
proposal, and reweights the proposals by the exact posterior density.

Every paired latent-history dataset contributes the same number of posterior
draws to the final mixture. Thus the 1,500 latent reconstructions are integrated
over rather than treated as extra biological observations.

Run order
---------
1. Quick smoke:
source("scripts/run_V7aM_smoke_100pairs.R")

Check:
- "Model-input counts reproduce Phase-2 audit: PASS"
- no optimisation failures
- importance-sampling ESS comfortably high
- sensible coefficient output

2. Full:
source("scripts/run_V7aM_FULL_1500pairs.R")

Primary result
--------------
beta_inf:
  positive = prior infection predicts greater subsequent local->high transition.

Also report:
- P(beta_inf > 0)
- infection odds ratio exp(beta_inf)
- female/male transition probabilities with and without prior infection.

Outputs
-------
results/V7aM_infection_to_movement_FULL_1500.rds
results/V7aM_infection_to_movement_FULL_1500_summary.csv
