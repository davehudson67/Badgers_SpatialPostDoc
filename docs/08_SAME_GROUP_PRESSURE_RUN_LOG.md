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

The valid part of the first full run was the complete-case benchmark. It gave a movement odds ratio around 0.79 with a broad interval, qualitatively close to the frozen primary V7b result (around 0.82). This was reassuring, but the two models used different estimation engines, so the difference could not be attributed purely to pressure-support sample restriction.

## V2 correction: add a full-support calibration model

The next version added `M0_FULL`, giving the model ladder:

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
    calibrates the simpler GLM + badger-cluster-robust sensitivity engine
    against the frozen primary importance-sampling model.

M0_FULL → M0_CC
    shows the effect of restricting to rows where same-group pressure is
    available, using the same estimation engine on both sides.

M0_CC → M1_RAW / M1_SMOOTH
    shows what changes after adjusting for same-group infection pressure on
    exactly the same rows.
```

### V2 100-pair smoke result

`M0_FULL` and `M0_CC` both fitted in all 100 paired histories, but the three pressure models still failed in all 100 histories with the same factor-contrast error.

The two valid V2 smoke estimates were:

```text
M0_FULL movement OR ≈ 0.80   (95% interval ≈ 0.29–1.77)
M0_CC   movement OR ≈ 0.78   (95% interval ≈ 0.19–1.97)
```

This is useful despite the failed pressure fits:

1. `M0_FULL` closely reproduces the frozen primary V7b movement result (OR ≈ 0.82), so the simpler GLM/cluster-robust sensitivity engine is well calibrated to the primary analysis.
2. Restricting to pressure-supported rows changes the point estimate very little (`M0_FULL` ≈ 0.80 → `M0_CC` ≈ 0.78), although uncertainty increases because information is lost.
3. Therefore there is currently no sign that pressure-support sample restriction is masking a strong positive movement effect.

No inference about same-group pressure itself can be made from this V2 smoke run because `M1_RAW`, `M1_SMOOTH` and `M2_INTERACTION` did not fit.

## V3 implementation fix: remove factor contrasts entirely

Because stable factor levels did not solve the repeated `contrasts` error, the next implementation keeps the **same scientific models** but replaces the quarter and 5-year period factors with explicit numeric treatment-coded dummy variables before `glm()` is called.

For example, quarter is represented internally as numeric indicators for Q2, Q3 and Q4 with Q1 as the reference; 5-year periods are handled similarly. This is algebraically equivalent to the intended categorical adjustment but bypasses R's factor-contrast machinery completely.

The run launchers now use:

`scripts/Woodchester_V7bM_samegroup_pressure_models_NUMERIC_DUMMIES.R`

and write results with `V3` in the result tag so earlier failed outputs are retained as an audit trail rather than overwritten.

### V3 wrapper boundary bug

The first attempt to launch V3 stopped immediately with:

```text
Could not find make_risk_data() boundary in V2 script.
```

This happened because the wrapper was looking for the exact function signature with `require_pressure=TRUE`, whereas the actual V2 function has `require_pressure=FALSE` as its default. No model fitting had started at this point, so no statistical output was affected.

The wrapper has now been corrected to identify the start of `make_risk_data()` without depending on its argument list.

## Current next step

Run the corrected **100-pair smoke test only**:

```r
source("scripts/run_V7bM_samegroup_pressure_SMOKE_100.R")
```

Do not start the 1,500-pair run until the fit audit reports successful fits for all five models:

```text
M0_FULL
M0_CC
M1_RAW
M1_SMOOTH
M2_INTERACTION
```
