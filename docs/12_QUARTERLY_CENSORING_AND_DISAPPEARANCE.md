# Quarterly censoring and disappearance sensitivity

## Why this matters

The V7c quarterly recipient-hazard analysis follows susceptible badgers only while their observed LIVE history supports follow-up. This avoids inventing risk time after the last live observation, but it can still create selection if disappearance is related to exposure, disease, mortality or emigration.

The first step is therefore a descriptive censoring audit rather than immediately fitting a full survival/observation model.

## Audit definition

For every exact observed recipient social-group quarter used by the quarterly hazard framework, and for target lags 1 to 8 quarters, classify follow-up as:

- `SUPPORTED_LIVE`: another live observation exists at or after the target quarter;
- `KNOWN_PM_DEATH`: live support ends before the target and a PM record occurs by the target quarter;
- `UNRESOLVED_DISAPPEARANCE`: live support ends before the target and there is no PM record by the target quarter.

The unresolved category can contain emigration, missed capture and unrecovered death. It must not be interpreted as mortality.

Exposure classes are mutually exclusive:

- no observed infectious source;
- ordinary Excretor source only;
- at least one Super excretor.

## Decision rule

The key comparison is whether `p_unresolved` or `p_supported` differs materially for Super-excretor exposure versus no observed source over the same 1–8 quarter period in which the infection-hazard association is estimated.

If follow-up is very similar across exposure classes, the current right-censoring rule is less concerning and the existing V7c result can be retained with the censoring caveat.

If Super-excretor exposure is associated with clearly different disappearance or follow-up support, the next step should explicitly account for informative censoring, for example through a recipient observation/survival model or inverse-probability-of-censoring sensitivity.

## Run

```r
source("scripts/run_V7c_quarterly_censoring_disappearance_audit.R")
```

The main outputs are:

```text
FOLLOW-UP STATUS BY LAG AND EXPOSURE CLASS
SUPER/ORDINARY VERSUS NO-SOURCE CENSORING CONTRASTS
TIME TO END OF OBSERVED LIVE SUPPORT
```
