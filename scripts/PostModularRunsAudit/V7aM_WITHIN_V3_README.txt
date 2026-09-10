WOODCHESTER V7a-M WITHIN-INDIVIDUAL v3

Why v2 stopped
--------------
v2 tried to call invokeRestart("muffleWarning") from a tryCatch warning handler.
That restart is only available inside a withCallingHandlers warning context.
The failure around pair ~700 was therefore an R warning-handling bug, not a
biological/model failure.

v3 fixes that, captures warning text in diagnostics, and saves a checkpoint
every 100 paired histories.

The first-pair audit from v2 was already informative:
- eligible local-origin rows: 4096
- represented badgers: 1269
- outcome-informative badgers: 202
- outcome-informative + infection-switching badgers: 32
- fit rows: 947

So the within-individual analysis IS identifiable, but it is based on a much
smaller subset than the population-level V7a model. Treat it as a valuable
low-power sensitivity analysis.

Run:
source("scripts/run_V7aM_within_v3_smoke.R")

Then:
source("scripts/run_V7aM_within_v3_FULL.R")

Then strict timing:
source("scripts/run_V7aM_within_v3_strictlag_FULL.R")
