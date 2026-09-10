WOODCHESTER V7a-M SENSITIVITY SET 1
===================================

This set addresses the first three checks after freezing the primary V7a/V7b:
1. historical period
2. reliable entry-age category (adult-entry vs young-entry)
3. within-individual dependence
4. stricter infection precedence

IMPORTANT
---------
adult_entry is NOT exact chronological age. It is the robust age-at-entry
classification already used in Stage 1. Exact/time-varying age should be
handled later only where the source data support it reliably.

A. Population-level period + entry-age sensitivity
---------------------------------------------------
First smoke:
source("scripts/run_V7aM_period_entry_smoke.R")

Then full:
source("scripts/run_V7aM_period_entry_FULL.R")

Compare beta_inf with the frozen primary V7a-M:
median ~0.113; 95% CrI ~[-0.347,0.529]; P(beta>0) ~0.692.

B. Strict temporal precedence
-----------------------------
source("scripts/run_V7aM_strictlag_period_entry_FULL.R")

Here infection must already have occurred by Q4 of the PREVIOUS year, rather
than by Q4 of the movement-origin year.

C. Within-individual sensitivity
--------------------------------
Smoke:
source("scripts/run_V7aM_within_smoke.R")

Full:
source("scripts/run_V7aM_within_FULL.R")

This uses conditional logistic regression with each badger as its own stratum.
All stable individual differences are conditioned out. Historical year is
adjusted with a 5-df natural spline. Sex and adult-entry cannot be estimated in
this analysis because they do not vary within an individual.

Optional strict-lag within-individual version:
source("scripts/run_V7aM_within_strictlag_FULL.R")

WHAT TO SEND BACK
-----------------
For population period/entry runs:
- primary infection effect
- importance-sampling diagnostics
- beta_sex and beta_adult

For within-individual runs:
- WITHIN-INDIVIDUAL INFECTION EFFECT
- fit/information audit, especially median_exposure_switchers and failed fits

NEXT AFTER THIS
---------------
Then move to:
- V7b individual heterogeneity / age sensitivity
- local infection-pressure construction
- alternative infection histories
- survival/disappearance diagnostic
- event-study around infection acquisition
- directional spatial spread
