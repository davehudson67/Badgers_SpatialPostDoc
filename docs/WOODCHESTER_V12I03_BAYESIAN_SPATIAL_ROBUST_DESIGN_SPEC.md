# Woodchester V12I-03: Bayesian spatial robust-design specification

Status: design freeze for first NIMBLE smoke model (9 Nov 2026). No fitted V12I-03 model yet.

## Empirical targets (audited frozen Supabase snapshot; 1976–2025)

- 3,214 individually identified tattoos, 8,618 observed individual-years, 14,921 unique individual-quarter combinations.
- Observed badger-years by number of quarters (period rows below; *conditional on at least one observation that year*):
  - 1976–85: 1:691, 2:189, 3:100, 4:11.
  - 1986–95: 1:1321, 2:983, 3:534, 4:140.
  - 1996–05: 1:1062, 2:790, 3:395, 4:60.
  - 2006–15: 1:792, 2:528, 3:253, 4:43.
  - 2016–25: 1:375, 2:235, 3:96, 4:20.
- Unique observed badger-quarter counts by period (Q1,Q2,Q3,Q4):
  - 1976–85: 140,439,608,226.
  - 1986–95: 856,1444,1941,1208.
  - 1996–05: 522,1072,1634,839.
  - 2006–15: 274,1032,868,605.
  - 2016–25: 107,336,492,278.
- 16-year matched-window checks: between 84.7% and 90.1% of gaps *between observed years* span one year; this is NOT detection p and excludes the unobserved tail after last capture.
- Observed annual spatial recapture distance is frequently zero. Verify sett identities and corrected locations before interpreting true activity-centre fidelity.
- Existing V11R2 has annual spatial positions, 119 historical detector coordinates, three RES50 chains, but posterior positions generally stop at last observed encounter. Existing posterior trajectories are retrospective and may use subsequent data.

## Proposed latent process

- Individual entry indicator and timing: distinguish *entering modelled observable population* from first capture. Recruitment versus immigration must be separate biological mechanisms and may not be identifiable without provenance data; do not label all first-captured adults immigrants.
- Alive/dead state annually; death absorbing.
- Annual activity centre s[i,t] in continuous metric coordinates. Movement mixture with high probability of locally persistent activity centre and occasional long-distance relocation, initially parameterised according to V11 (avoid double-use of V11 posterior if refitting same encounter likelihood).
- Activity centres can be outside observable detector network with positive probability; no absorbing emigration category in initial model. Temporary geographical unavailability is a consequence of position and detection.
- Four within-year secondary occasions (quarters). Annual survival and entry transitions initially between years. Future versions may handle timing of death/recruitment within a year.
- Capture observation at detector j in quarter q conditional on alive and s[i,t], with spatial detection p0[period,q] and sigma. Distance to detector positions in metres. Detectors' year/quarter-level active status is **unknown historically**; campaign_active is not sett-specific effort. Do not assume all known sett detectors were actually operating as traps each quarter in the empirical model.
- Dead recoveries are a separate recovery process, not ordinary captures; introduce after basic spatial smoke validation. PM recovery locations not equivalent to live traps.

## Model-building gates

1. **Quarterly simulator:** reproduce one to four observed quarters per animal-year, observed annual gaps and multiple within-year captures; preserve simulated latent truth and detector identity. Use measured summaries as posterior predictive targets, not fixed probabilities. Report multiple calibration windows.
2. **NIMBLE smoke model on small synthetic sample:** known alive cohort and fixed annual movement/detection scales first; latent activity centres and quarterly observations, then free one group of parameters at a time. Unit tests: likelihood finite, recovered state indexing, sampler smoke, no impossible live detections for dead animals.
3. **Open entry model:** use augmentation or justified alternative to represent never-seen animals, avoid fixing true population size or entry probability.
4. **Full movement-demography:** joint posterior for survival, movement states, location, entry and observation. Explicitly investigate confounding of survival, movement beyond network, and permanent emigration; simulate known truth.
5. **Real data:** reconcile old V11 spatial inputs with certified current Supabase locations and field-team sett corrections; release posterior predictive checks and sensitivity to unknown trapping coverage.

## Critical safeguards

- Distinguish observed capture *frequency* from latent capture *probability*; long consecutive-observed-year streaks are conditioned on seeing the individual again.
- Do not call movement beyond global convex hull emigration, nor social-group OUTSIDE territory emigration. Neither is a known annual sampling boundary.
- Keep V11R2 frozen as historical benchmark; refit when corrected coordinates materially alter the model inputs.
- Use tattoo as canonical ID; UN badgers have no assumed social group.
- No claim of separate permanent emigration vs unobserved death without independent identification evidence.
