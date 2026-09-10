V7a-M WITHIN-INDIVIDUAL v2

The previous script could return "No within-individual fits were estimable"
without exposing the actual cause.

v2:
- explicitly attaches survival, making strata() available to clogit;
- prefilters to badgers with within-individual outcome variation;
- audits how many of those badgers also change infection status;
- prints actual failure messages if any fit fails.

Run first:
source("scripts/run_V7aM_within_v2_smoke.R")

Look for:
FIRST-PAIR INFORMATION AUDIT
FIT / INFORMATION AUDIT
WITHIN-INDIVIDUAL INFECTION EFFECT

If clean, run:
source("scripts/run_V7aM_within_v2_FULL.R")

Then:
source("scripts/run_V7aM_within_v2_strictlag_FULL.R")

Do not infer biological absence from the old zero-fit error. It was an
implementation/diagnostic failure until the v2 audit establishes how much
within-individual information is actually present.
