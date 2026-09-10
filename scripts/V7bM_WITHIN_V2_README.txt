WOODCHESTER V7b-M WITHIN-INDIVIDUAL v2

The first within-individual V7b run produced separation warnings in every
paired history. The warning variable numbers correspond mainly to the many
5-year-period nuisance coefficients. With only ~171 event badgers and ~24
event badgers switching movement exposure per paired history, that period
factor is too sparse for this conditional-likelihood sensitivity.

Recommended clean rerun:
1. source("scripts/run_V7bM_within_v2_linear_smoke.R")
2. source("scripts/run_V7bM_within_v2_linear_FULL.R")

This retains:
- individual fixed effects;
- quarter;
- one centred linear calendar-year effect.

Optional robustness:
source("scripts/run_V7bM_within_v2_spline3_FULL.R")
source("scripts/run_V7bM_within_v2_quarteronly_FULL.R")

The within-individual analysis remains a low-power sensitivity and does not
replace the primary V7b-M population hazard model.
