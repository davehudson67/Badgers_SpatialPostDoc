WOODCHESTER V7b-M: high mobility -> subsequent infection

Model
-----
Among badgers susceptible at Q4 of year t:

logit(hazard in quarter q of year t+1) =
    alpha
  + beta_move * high_mobility_t
  + beta_sex * sex
  + quarter effect
  + 5-year period effect

Quarter and period effects use sum-to-zero coding, matching the earlier
trajectory-pilot formulation.

Strict temporal direction
-------------------------
Movement interval ends in year t.
Infection risk is only Q1-Q4 of year t+1.
Follow-up stops at the individual's last observed live quarter.
Once infection occurs, no later risk rows are included.

Run order
---------
1. Smoke:
source("scripts/run_V7bM_smoke_100pairs.R")

Check:
- "Model-input counts reproduce Phase-2 audit: PASS"
- no optimisation failures
- importance-sampling ESS is healthy

2. Full:
source("scripts/run_V7bM_FULL_1500pairs.R")

Primary result
--------------
beta_move:
  positive = high mobility predicts higher subsequent infection-acquisition hazard.

Report:
- beta_move median + 95% credible interval
- P(beta_move > 0)
- OR = exp(beta_move)

Outputs
-------
results/V7bM_movement_to_infection_FULL_1500.rds
results/V7bM_movement_to_infection_FULL_1500_summary.csv
