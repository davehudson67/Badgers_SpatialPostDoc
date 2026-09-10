WOODCHESTER V7b-M MUNDLAK RANDOM-INTERCEPT SENSITIVITY

Why this replaces the attempted calendar-adjusted clogit
--------------------------------------------------------
The debug run showed:
- movement-only clogit works;
- movement + quarter works;
- adding absolute calendar year makes all coefficients NA.

This is structural rather than a coding bug. For an event badger, acquisition
is necessarily its final susceptible risk occasion. Within an individual,
monotonic calendar time therefore predicts the event position and can separate
the conditional likelihood. The earlier 5-year period warnings were the same
problem in categorical form.

The mixed model avoids this problem because calendar period is estimated across
the population rather than entirely within each event-badger stratum.

It also separates:
- movement_within: same-badger high vs local risk periods
- movement_mean: between-badger general mobility propensity

Model:
infection_event ~ movement_within + movement_mean + sex + adult_entry +
                  quarter + 5-year period + (1 | tattoo)

Run first:
source("scripts/run_V7bM_Mundlak_smoke_10pairs.R")

If fit diagnostics are clean:
source("scripts/run_V7bM_Mundlak_100pairs.R")

This is intentionally 100 balanced paired histories, not 1500. It is a
sensitivity analysis and GLMM fitting is substantially heavier than the small
conditional models.

Please send back:
FIT / INFORMATION AUDIT
MUNDLAK MIXED-MODEL POSTERIOR APPROXIMATION
KEY WITHIN-BADGER MOVEMENT EFFECT
