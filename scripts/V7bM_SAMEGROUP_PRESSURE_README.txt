WOODCHESTER V7b-M SAME-SOCIAL-GROUP PRESSURE MODELS

Start with:
source("scripts/run_V7bM_samegroup_pressure_SMOKE_100.R")

If clean:
source("scripts/run_V7bM_samegroup_pressure_FULL_1500.R")

Optional denominator-support sensitivity:
source("scripts/run_V7bM_samegroup_pressure_minN3_FULL_1500.R")

Models:
M0_CC       matched complete-case model without pressure
M1_RAW      M0_CC + raw same-group prevalence
M1_SMOOTH   M0_CC + smoothed same-group prevalence
M2_INTERACTION M1_RAW + movement x pressure

All pressure coefficients are per +10 percentage points prevalence.
Covariance is clustered by badger.

Please paste:
FIT AUDIT
POOLED COEFFICIENT SUMMARY
INTERACTION
MOVEMENT EFFECT COMPARISON
