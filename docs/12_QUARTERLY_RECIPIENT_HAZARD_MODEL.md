# V7c quarterly recipient infection-hazard model

## Why this model is justified

The corrected quarterly support audit showed substantial exact-quarter support. Exact observed co-membership produced 2,997 recipient exposure rows involving 1,120 badgers, including 1,304 rows from group-quarters containing a Super excretor. Across sampled infection histories, exact-quarter Super-excretor exposure was followed by median unique recipient acquisitions of 27 within one quarter, 45 within two quarters, 66 within four quarters and 80 within eight quarters. Exact-lag support remained non-zero through lag 8.

These counts justify moving beyond the annual t -> t+1 source model to a quarterly discrete-time analysis.

## Primary design

The primary model uses exact observed recipient social-group membership in source quarter q. A source is an OTHER badger observed in that same group and quarter as Excretor or Super excretor. The focal recipient is never counted as its own source.

For lag L = 1,...,8, the model asks whether source exposure in quarter q predicts the recipient's first sampled infection acquisition in quarter q+L. Animals infected before q+L are no longer in that lag's risk set. Follow-up stops at last observed live quarter and outcome years are capped at 2025 because 2026 is incomplete.

This produces unique recipient-quarter risk rows for each fitted lag rather than the duplicated source-recipient pair rows used only for the support audit.

## Models at each lag

`B_BACKGROUND`: background local infection pressure + temporal covariates (+ recipient sex when available).

`S_SUPER`: B_BACKGROUND + presence of at least one observed Super excretor in the exact source group-quarter.

`C_CLASS`: B_BACKGROUND + mutually exclusive source classes: ordinary Excretor-only source versus source quarter containing at least one Super excretor. A derived Super-versus-ordinary contrast is reported.

## Background infection pressure

Background pressure is sampled latent infection prevalence in the exposure social group at the source quarter. Observed Excretor/Super-excretor source animals are excluded and the focal recipient is removed from the denominator where appropriate. This avoids simply encoding the named source inside the local-prevalence covariate.

## Dependence and uncertainty

Each infection trajectory is analysed separately. Logistic-regression covariance is two-way cluster robust by recipient badger and social group, accounting for repeated observations of the same recipient and shared group-level exposure. Coefficient uncertainty is propagated by multivariate-normal draws.

## Interpretation

This remains an observational source-exposure analysis. A positive Super-excretor coefficient means subsequent recipient acquisition is associated with observed exposure to a Super excretor above measured local background pressure. It does not prove direct transmission from the named source.

Differences among lag-specific estimates describe the timing pattern but should not be treated as independent causal contrasts because the same animals and exposure histories can contribute to multiple lag analyses.

## Remaining survival/observation issue

The quarterly model is deliberately conservative: it does not invent risk time beyond last observed live capture. It therefore still does not distinguish death, emigration and missed capture after disappearance. An explicit survival/observation sensitivity remains a later step if the quarterly source signal is important.
