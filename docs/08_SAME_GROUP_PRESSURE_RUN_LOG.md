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

V5 therefore abandoned the run-time patching approach entirely.

The implementation is a complete standalone file:

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
- any non-finite input is reported by column name and count.

The scientific model and risk-set timing are unchanged.

### V5 smoke result

The 100-pair V5 smoke test was the first version in which **all five models fitted successfully in all 100 paired histories with no warnings**:

```text
M0_FULL          100 fitted / 0 failed
M0_CC            100 fitted / 0 failed
M1_RAW           100 fitted / 0 failed
M1_SMOOTH        100 fitted / 0 failed
M2_INTERACTION   100 fitted / 0 failed
```

This establishes that the pressure-model fitting problem itself is solved.

The script then stopped during pooled coefficient summarisation with:

```text
Error in quantile.default(x, 0.025): missing values and NaN's not allowed if 'na.rm' is FALSE
```

This was **not a model-fitting failure**. The cause was that `bind_rows()` combines coefficient draws from models with different columns. It therefore creates model-specific columns filled with `NA` for models that do not contain that coefficient. The original summary loop checked only whether a column name existed, so it attempted to summarise an all-NA pressure column for `M0_FULL`.

## V5B — summary-only correction

V5B leaves all V5 fitting, risk sets, covariance calculations and scientific model definitions unchanged. It changes only post-fit summarisation so a coefficient is summarised only from finite draws belonging to the model that actually estimated it.

The V5B launcher uses:

```text
scripts/Woodchester_V7bM_samegroup_pressure_models_V5B_SUMMARYFIX.R
```

and writes new result tags containing `V5B` so the earlier V5 smoke artefact remains distinguishable.

## Current next step

Run the V5B 100-pair smoke test. Because V5 already demonstrated 100/100 successful fits for all five models, this run is primarily to verify that the corrected summary and saved outputs complete cleanly and to inspect the first actual same-group pressure coefficient estimates.

Only after that should the 1,500-pair V5B run be started.

Earlier V2-V4 outputs are development/audit artefacts only and must not be used for inference about same-group infection pressure. The V5 smoke fit itself is valid, but its pooled summary was not completed because of the post-fit NA-column bug.
