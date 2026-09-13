# V7c quarterly source-effect extension

## Why this extension exists

The annual V7c model found that the presence of an observed **Super excretor** in a social group was associated with higher infection acquisition in other badgers during the following year, even after accounting for background group infection pressure. The annual model is deliberately simple, but it does not show when subsequent acquisitions occur and it requires prospective support through the annual outcome window.

The quarterly extension asks a finer question:

> After an observed Excretor or Super-excretor source capture, how much supported susceptible-recipient follow-up is available in the next 1, 2, 4 and 8 quarters, and when do acquisition events occur?

## Stage 1 — quarterly support audit

Run:

```r
source("scripts/run_V7c_quarterly_source_effect_support_audit.R")
```

The audit uses the exact quarter and recorded social group of **live** Excretor / Super-excretor capture occasions. It compares two recipient-membership definitions:

- `EXACT_QUARTER`: the recipient was also captured alive in that social group during the source quarter;
- `ANNUAL_GROUP`: the recipient has that observed annual social group and the source quarter lies inside its observed live-history bounds.

The second definition gives more support but does not assume the animal was present before its first live observation or after its last live observation.

Follow-up is truncated at each recipient's last observed live quarter. No risk time is created after disappearance.

The audit reports both pair-level events and unique recipient acquisitions. Pair-level counts can duplicate one acquisition when a badger had overlapping source exposures; therefore they are diagnostic only.

## Stage 2 — planned quarterly hazard model

If the support audit is adequate, construct **one row per susceptible recipient-quarter**. Each infection acquisition will then enter the analysis once. Candidate time-varying predictors are:

- current/recent Super-excretor exposure;
- current/recent Excretor-or-Super exposure;
- background same-group infection pressure excluding the observed source animals;
- lag since source exposure, using parsimonious bins chosen from the support audit;
- calendar period/quarter.

The principal comparison remains Super-excretor exposure versus background infection pressure. Infectious-arrival effects remain exploratory because the exact social-group-arrival data are sparse.

## Stage 3 — survival / disappearance sensitivity

The quarterly extension still uses observed live-history bounds rather than modelling survival, emigration and observation jointly. A later sensitivity should explicitly model disappearance if the quarterly result is important enough to warrant it. This is preferable to assuming animals remain alive and exposed after their final live observation.

## Interpretation rule

The annual and quarterly V7c analyses are prospective association models. They can show that infection acquisition is elevated after observed source exposure, but they cannot prove that a named source badger directly transmitted infection to a particular recipient.
