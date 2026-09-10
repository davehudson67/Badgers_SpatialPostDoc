# Same-group infection-pressure model — run log

## First smoke and full runs

The first same-group pressure runs completed their loops, but the pressure-adjusted models did **not** fit successfully.

The complete-case benchmark `M0_CC` fitted in all paired histories, but:

- `M1_RAW` failed in every history;
- `M1_SMOOTH` failed in every history;
- `M2_INTERACTION` failed in every history.

The repeated error was:

```text
contrasts can be applied only to factors with 2 or more levels
```

Therefore the first 100-pair smoke run and the first 1,500-pair full run contain **no valid estimate of the infection-pressure effect or movement × pressure interaction**.

The valid part of the first full run was the complete-case benchmark. It gave a movement odds ratio around 0.79 with a broad interval, qualitatively close to the frozen primary V7b result (around 0.82). This is reassuring, but the two models use different estimation engines, so the difference cannot be attributed purely to pressure-support sample restriction.

## Why a V2 model was created

Two changes were needed before another full run.

### 1. Stable factor levels

Quarter and 5-year period levels are now defined globally and retained consistently across every paired history. This removes the factor-contrast failure that stopped all pressure-adjusted models.

### 2. Add `M0_FULL`

The corrected model now fits an additional full-support benchmark using the same GLM + badger-cluster-robust engine as the pressure models.

The model ladder is now:

```text
M0_FULL        movement + sex + quarter + period, all eligible V7b rows
M0_CC          same model, pressure-supported rows only
M1_RAW         M0_CC + raw same-group infection prevalence
M1_SMOOTH      M0_CC + smoothed same-group prevalence
M2_INTERACTION M1_RAW + movement × pressure
```

This gives a cleaner decomposition:

```text
Frozen primary V7b → M0_FULL
    checks how the simpler sensitivity estimation engine compares with the
    frozen primary importance-sampling analysis.

M0_FULL → M0_CC
    shows the effect of restricting to rows where same-group pressure is
    available, using the same estimation engine on both sides.

M0_CC → M1_RAW / M1_SMOOTH
    shows what changes after adjusting for same-group infection pressure on
    exactly the same rows.
```

The interaction remains exploratory.

## Current next step

Run the corrected **100-pair smoke test only**. Do not run the 1,500-pair version until all five models fit cleanly in the smoke test.

Use:

```r
source("scripts/run_V7bM_samegroup_pressure_SMOKE_100.R")
```

The corrected run writes new files with `V2` in the result tag so the earlier failed-run audit files are not overwritten.

Only if the smoke-test fit audit reports successful fits for all five models should the full run be started.
