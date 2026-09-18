# Same-group infection-pressure model — V3/V4 debugging note

## V3 smoke result

The corrected V3 wrapper ran the 100 paired histories, so the earlier wrapper-boundary bug was resolved.

The two benchmark models again fitted cleanly:

```text
M0_FULL  100 / 100 fitted
M0_CC    100 / 100 fitted
```

Their movement estimates remained close to the frozen primary V7b result:

```text
M0_FULL movement OR ≈ 0.80
M0_CC   movement OR ≈ 0.78
```

However, all pressure-adjusted models still failed:

```text
M1_RAW         0 / 100 fitted
M1_SMOOTH      0 / 100 fitted
M2_INTERACTION 0 / 100 fitted
```

The new repeated error was:

```text
Argument mu must be a nonempty numeric vector
```

This occurred only when pressure terms were added. Because M0_FULL and M0_CC continued to fit on the same risk-set construction, the evidence still points to the model-fitting/formula machinery rather than the biological risk data.

## V4 implementation

V4 bypasses formula/model-frame handling entirely.

The V2 risk-set construction and scientific models are retained, but fitting now uses an explicit numeric design matrix with `stats::glm.fit()`.

The design matrix contains:

- intercept;
- movement state;
- raw or smoothed pressure where required;
- movement × pressure for the interaction model;
- sex;
- numeric treatment-coded quarter indicators;
- numeric treatment-coded 5-year-period indicators.

Cluster-robust covariance and the MVN coefficient-draw step are retained. This removes factor contrasts and formula expansion from the fitting path altogether.

Launcher outputs now use `V4` tags, preserving all failed V1–V3 outputs as an audit trail.

## Next step

Run only the 100-pair smoke test:

```r
source("scripts/run_V7bM_samegroup_pressure_SMOKE_100.R")
```

Only proceed to the 1,500-pair run if all five models fit without failures.
