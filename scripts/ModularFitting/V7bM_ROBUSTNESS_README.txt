WOODCHESTER V7b-M robustness check

Run:
source("scripts/Woodchester_V7bM_robustness_patch_poor_IS_pairs.R")

The script reads:
results/V7bM_movement_to_infection_FULL_1500.rds

It identifies the paired histories with IS_ESS < 500, reruns ONLY those
conditional posteriors with 50,000 defensive-mixture importance proposals,
retains exactly 100 replacement posterior draws for each poor pair, and
replaces their original 100 draws.

This preserves equal weight across all 1,500 paired latent-history datasets.

The script prints:
- old vs retry ESS and maximum importance weight for every poor pair
- original vs robust-patched beta_move / OR posterior
- final patched posterior summary

Outputs:
results/V7bM_movement_to_infection_FULL_1500_ROBUST.rds
results/V7bM_movement_to_infection_FULL_1500_ROBUST_summary.csv

If the primary beta_move posterior is essentially unchanged, numerical
importance-sampling quality is not driving the biological conclusion.
