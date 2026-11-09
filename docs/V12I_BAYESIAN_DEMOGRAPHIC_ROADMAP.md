# V12I — Woodchester Bayesian spatial-demographic roadmap (9 Nov 2026)

## Scientific estimands
1. Annual survival and death recovery, conditional on age/sex/calendar effects where supported.
2. Quarterly/sett-specific observation conditional on availability and effort (historical effort largely unrecorded).
3. Latent geographical activity centres, residency and longer relocation, informed by V11 without double-using capture histories.
4. Population entry decomposed into **local recruitment** and **immigration**, only if auxiliary information or assumptions render these distinguishable.
5. **Emigration** separated from death or missed detection only to the extent the spatial extent, recaptures, recovery data, and movement assumptions identify it.

These are scientifically distinct from the observed first and last capture dates. In particular, initial detection does not demonstrate immigration and terminal disappearance does not demonstrate emigration or death.

## Implemented checkpoints
- V12I-03: NIMBLE spatial model, synthetic population, fixed alive states/movement scale and 4 quarterly observations.
- V12I-03b: replicated model-fit validation; 3 datasets x 3 chains (configurable), matched synthetic/fitting initial-location distribution, Rhat and bulk/tail ESS. The original mismatched initial-sett prior remains optional for sensitivity work.
- V12I-04: independent **non-spatial synthetic** annual survival + quarterly detection proof of concept, known initial cohort, latent alive/dead states, phi and p0 jointly estimated. This is not the final model.
- Scripts above have been committed but require execution and numerical validation on RStudio before they can be considered successful tests.

## Validation gates before final data analysis
- Multi-chain diagnostics for every essential parameter and representative latent states; target rank-normalised Rhat < 1.01, bulk/tail ESS > 400; inspect traces and location mixing.
- Independent simulated datasets under known parameter combinations and sparse detections. Check bias, coverage and parameter non-identifiability, not just that a single true value falls in an interval.
- Posterior predictive checks against matched Woodchester temporal windows, quarterly detection composition, number of observed years, observed gaps and sett-based spatial recaptures.
- Sensitivity to real sett aliases, XY corrections, excluded and UN captures, recovery coding, sampling windows and uncertain trapping opportunities.
- Do not interpret raw recapture rate or quarterly observed proportions as detection probabilities.

## Next joint model sequence
1. **V12I-05:** integrate spatial activity centres with latent survival and quarterly detection. Keep entry times known in simulated development datasets. Include proper movement and spatial detection observations; validate survival/detection/location recovery.
2. **V12I-06:** release population entry as an open-population latent process, allowing individuals never detected; validate cohort sizes and survival/entry confounding under data augmentation.
3. **V12I-07:** add V11-informed stable residency / long-distance movement, sett affinity, temporary availability and explicit boundaries; test relocation-vs-detection confounding.
4. **V12I-08:** integrate death recovery with separate recovery likelihood and verified PM-location semantics; test deaths vs temporary or permanent unavailability.
5. **V12I-09:** add immigrant vs locally born entry states only with defensible evidence (known births, ages, parentage, outside captures, spatial/territorial constraints) or report sensitivity/partial identification. Model emigration as a latent transition outside the study domain, but report if permanent departure and death are not separately identifiable.
6. **V12I-10:** Woodchester data fit: staged 10–20 individuals, then broader cohorts, then full history; multi-chain fitting, PPC, robust sensitivity analyses and complete provenance.

Annual demographic transitions with quarterly secondary observations are a working approximation; closure within each quarter and fieldwork period must be evaluated rather than assumed. Spatial detector availability and true effort may be unobserved.

## Operational notes
From repository root:

```bash
git pull --ff-only
Rscript -e 'if(!requireNamespace("posterior",quietly=TRUE)) install.packages("posterior",repos="https://cloud.r-project.org")'
V12I_REPS=3 V12I_CHAINS=3 V12I_NITER=12000 V12I_NBURN=4000 \
  Rscript scripts/ModularFitting/Woodchester_V12I_03b_Validate.R \
  2>&1 | tee outputs_v12i03b_validation.log
```

Separate files are written under `outputs/v12_immigration_prototype/v12i03_validation/`. The run may take considerable compute, so choose a tmux session if disconnects are likely. Do not mistake successful numerical execution for validated statistical inference.

The survival/detection smoke test can be executed separately:

```bash
Rscript scripts/ModularFitting/Woodchester_V12I_04_Survival_Detection_Smoke.R \
  2>&1 | tee outputs_v12i04_survival_detection.log
```

Avoid launching many parallel fits before validating the first run and checking resource use. Neither script writes to Supabase, rewrites the V11 outputs, or applies data cleaning.
