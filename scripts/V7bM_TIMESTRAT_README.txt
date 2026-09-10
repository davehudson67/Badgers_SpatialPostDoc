WOODCHESTER V7b-M TIME-STRATIFIED WITHIN-INDIVIDUAL SENSITIVITY

Why this model
--------------
Debugging established:
- individual fixed-effect clogit with movement only works;
- movement + quarter works;
- adding absolute calendar year makes the conditional likelihood degenerate;
- 5-year period dummy coefficients also separate.

This happens because infection acquisition is necessarily the final susceptible
risk occasion within an event badger. Absolute time is therefore structurally
entangled with the event position.

The time-stratified case-crossover solution controls calendar era BY DESIGN:
each event is compared only with the same badger's susceptible control
occasions in the same calendar block.

Preferred:
source("scripts/run_V7bM_timestrat5_smoke_100.R")
source("scripts/run_V7bM_timestrat5_FULL_1500.R")

Robustness:
source("scripts/run_V7bM_timestrat10_FULL_1500.R")

The key information diagnostic is:
n_exposure_switch_event_strata

Only event strata with both local and high-mobility occasions identify the
movement coefficient.
