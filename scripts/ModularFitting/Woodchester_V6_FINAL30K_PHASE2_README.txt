WOODCHESTER V6 FINAL30K + PHASE 2 START

FINAL STAGE 1
-------------
Run the three chains independently:
source("scripts/run_V7MCMHMMv6_FINAL30K_chain_1.R")
source("scripts/run_V7MCMHMMv6_FINAL30K_chain_2.R")
source("scripts/run_V7MCMHMMv6_FINAL30K_chain_3.R")

Each uses:
NITER = 30000
NBURN = 4000
THIN  = 2
= 13000 retained draws per chain.

Then:
source("scripts/Woodchester_V7MCMHMMv6_FINAL30K_combine_exact_state_diagnostics.R")

If final diagnostics are acceptable:
source("scripts/Woodchester_V7MCMHMMv6_FINAL30K_export_FFBS_histories.R")

This exports 1500 coherent whole movement histories (500 per chain) to:
data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds

PHASE 2 START
-------------
Then run:
source("scripts/Woodchester_PHASE2_build_and_audit_paired_histories.R")

That script matches the movement posterior to:
data/badger_infection_trajectories_all_tests_inferred.rds

It deliberately does NOT guess the infection-time calendar origin. Once that
audit confirms the stored trajectory format/time scale, the next scripts are:

V7a-M:
infection status at origin-year Q4 -> subsequent local-to-high transition.

V7b-M:
movement interval ending year t -> infection acquisition in Q1-Q4 of year t+1.

The Phase-2 analyses will pair coherent movement histories with coherent
infection trajectories and pool across paired imputations; they will not stack
imputations as independent biological observations.


PHASE 2 EXACT TIMING
--------------------
The canonical infection trajectory snapshot already stores:
start_year = 1976
infection_time = 4 * (year - 1976) + quarter
with infection_time = 0 for never infected.

The paired-history builder therefore reproduces the strict timing used in the
trajectory pilots without guessing:
- V7a-M: infection by Q4 of the new movement interval's origin year.
- V7b-M: movement ending year t, then infection risk only in Q1-Q4 of t+1,
  censored at the individual's last live quarter.
