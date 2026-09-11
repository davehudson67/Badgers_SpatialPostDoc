# Same-group infection-pressure model — run log

This file records the implementation history of the same-social-group pressure sensitivity so failed development runs are not accidentally interpreted later.

## First smoke and full runs

The first implementation fitted the complete-case benchmark `M0_CC`, but every pressure-adjusted model failed with:

```text
contrasts can be applied only to factors with 2 or more levels
```

Therefore those first smoke/full outputs contain **no valid estimate of the pressure effect or movement × pressure interaction**.

The valid complete-case benchmark was still useful: its movement OR was about 0.79, qualitatively close to the frozen primary V7b-M result (about 0.82).

## V2 — add `M0_FULL`

The model ladder was expanded to:

```text
M0_FULL        movement + sex + quarter + period, all eligible V7b rows
M0_CC          same model, pressure-supported rows only
M1_RAW         M0_CC + raw same-group infection prevalence
M1_SMOOTH      M0_CC + smoothed same-group prevalence
M2_INTERACTION M1_RAW + movement × pressure
```

This creates three useful comparisons:

```text
Frozen primary V7b -> M0_FULL : estimation-framework calibration
M0_FULL -> M0_CC              : pressure-support sample restriction
M0_CC -> M1_RAW/M1_SMOOTH     : pressure adjustment on identical rows
```

The V2 smoke run fitted `M0_FULL` and `M0_CC` cleanly, with movement ORs about 0.80 and 0.78 respectively, but all pressure models still failed with the factor-contrast error.

## V3 — numeric dummy wrapper

V3 attempted to replace quarter and period factors with explicit numeric dummies while patching the V2 script at run time.

The first launch exposed a brittle wrapper-boundary bug (`Could not find make_risk_data() boundary in V2 script`). After that was corrected, the pressure models got further but failed with:

```text
Argument mu must be a nonempty numeric vector
```

Again, `M0_FULL` and `M0_CC` fitted and gave the same movement result, so the risk-set construction remained stable.

## V4 — matrix-fit wrapper

V4 bypassed formula expansion and used an explicit numeric design matrix with `glm.fit()`.

The 100-pair smoke test again fitted both benchmark models cleanly:

```text
M0_FULL movement OR ≈ 0.80
M0_CC   movement OR ≈ 0.78
```

but every pressure model failed before fitting because the constructed pressure-model design matrices contained non-finite values. The failure counts were close to the number of pressure-supported rows in each paired history.

This showed that continuing to patch and rewrite older scripts dynamically was making the debugging harder than the statistical problem itself.

## V5 — complete standalone implementation

V5 therefore abandons the run-time patching approach entirely.

The current implementation is a complete standalone file:

```text
scripts/Woodchester_V7bM_samegroup_pressure_models_V5_STANDALONE.R
```

Key differences:

- no `eval(parse())`;
- no text replacement of older scripts;
- no formula/factor machinery in model fitting;
- pressure columns are rebuilt directly from the finite `pressure` and `pressure_smooth` columns in the risk data;
- quarter and period adjustment are explicit numeric dummy variables;
- model fitting uses a numeric design matrix and `glm.fit()`;
- any non-finite input is reported by **column name and count**, rather than only by total bad rows.

The scientific model and risk-set timing are unchanged.

## Current next step

Pull the branch and run only the V5 100-pair smoke test:

```r
source("scripts/run_V7bM_samegroup_pressure_SMOKE_100.R")
```

Do not start the 1,500-pair V5 run until the fit audit reports successful fits for all five models:

```text
M0_FULL
M0_CC
M1_RAW
M1_SMOOTH
M2_INTERACTION
```

Earlier V2-V4 output files are development/audit artefacts only and must not be used for inference about same-group infection pressure.
