WOODCHESTER V7b SPATIAL INFECTION-PRESSURE BUILD

This script constructs posterior infection-pressure covariates for all 4,382
V7b candidate movement intervals across all 500 latent infection histories.

Definitions
-----------
Pressure is measured at Q4 of movement-ending year t.
Outcome remains infection acquisition in Q1-Q4 of t+1.

Source animals are OTHER badgers with exact observed annual location/group in
year t. The focal badger is always excluded.

Metrics:
- same social-group prevalence
- 500 m prevalence
- 1000 m prevalence
- 2000 m prevalence
- exponential distance-weighted prevalence, 500 m scale
- exponential distance-weighted prevalence, 1000 m scale

No nearest-year / LOCF location imputation is used.

Run
---
source("scripts/run_V7b_build_spatial_infection_pressure.R")

Please paste back sections:
F. STATIC PRESSURE SUPPORT AUDIT
G. V7b RISK / EVENT RETENTION BY PRESSURE METRIC
H. PRESSURE DISTRIBUTIONS
I. PRESSURE-METRIC CORRELATIONS

Key output
----------
data/badger_V7b_spatial_infection_pressure_500draws.rds

The output is matrix-based:
rows = V7b movement intervals
columns = infection-history draw
so it stays compact and can be indexed directly by pair_index$infection_col.

Interpretation
--------------
Same-group prevalence is the recommended FIRST pressure model because it has a
clear biological interpretation and avoids choosing a Euclidean kernel.

Destination/local pressure is potentially a mediator of movement -> infection.
The pressure-adjusted model therefore estimates a mechanistic/direct effect and
does NOT replace the frozen primary total-effect V7b-M result.
