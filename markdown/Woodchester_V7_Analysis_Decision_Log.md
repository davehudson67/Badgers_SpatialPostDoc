# Woodchester V7 analysis decision log

**Updated:** 27 August 2026

This file is intended to remain short. It records modelling decisions so that later code changes do not accidentally reintroduce rejected assumptions.

| Topic | Current decision | Status / reason |
|---|---|---|
| Database access | Models use frozen RDS snapshots, not direct DB calls | Accepted |
| SCR biological input | Use `badger_encounters_useful.rds` for live spatial encounter selection | Accepted |
| 2026 | Exclude from current complete-year movement model | Accepted; year incomplete |
| Primary scale | Annual AC, four within-year secondary occasions | Accepted |
| First AC | Latent | Accepted since M2 |
| Landscape | 50 m habitat + SG + peripheral normalization | Accepted provisionally |
| Adult-entry | Entry history, not proven immigrant | Accepted |
| Permanent immigrant class | Do not use as primary movement explanation | Rejected after V5c identifiability/mixing |
| Persistent individual movement RE | Excluded from current state model | Rejected for current scaffold due confounding |
| Student-t + latent disperser state | Do not combine as current primary model | Rejected after V6a mixing/identifiability |
| Movement history end | Stop movement at last observed live year | Accepted for movement-development scaffold |
| Survival in V6c | Conditioned out | Deliberate; V6c not final survival model |
| Movement state | Stable/local vs high-mobility/relocation | Accepted interpretation |
| “Two types of badger” | Do not claim | Rejected |
| High-mobility state ID | Positive movement-scale increment | Accepted to prevent label switching |
| Sex effect on movement magnitude | Retain/test but current evidence weak | Provisional |
| Sex effect on R->D | Retain; current evidence supported | Accepted for V7 scaffold |
| Sex effect on D->D | Retain cautiously; weak current evidence | Provisional |
| Adult-entry effect on initial D | Current evidence weak | Keep only if biologically useful |
| Local sigma ~7 m | Do not interpret literally | It approximates same-sett mass |
| High-mobility sigma ~0.8–1 km | Interpretable scale, but convergence still imperfect | Provisional |
| SG resistance | Weak/uncertain | Sensitivity target |
| Peripheral resistance | Very large | Sensitivity target; possible state-space interaction |
| Persistent high mobility | Strict definition requires >=3 intervals | Accepted descriptive rule |
| V7 infection input | Preserve probabilistic uncertainty | Accepted |
| Infection threshold at 0.5 | Do not use as primary analysis | Rejected |
| V7 first hypothesis | Infection at t -> R->D transition t to t+1 | Planned |
| V7 reciprocal hypothesis | D/movement at t -> infection at t+1 | Planned |
| Multi-year gaps | Retain in latent model but flag temporal uncertainty | Accepted |
| Consecutive-year sensitivity | Required for temporal directionality | Planned |
| 25 m grid sensitivity | Required before literal small-scale movement inference | Planned |
| One-state/continuous movement comparison | Required before claiming discrete movement states | Planned |
| Spike-and-slab local/relocation model | Sensitivity model, not required before V7 | Planned |
| Full abundance/data augmentation | Do not bolt onto first V7 | Deferred |
| Ketwaroo diagnostic submodel | Borrow structure only if needed after seeing infection outputs | Deferred |

## Current scientific wording

> The current model supports a dominant stable/local annual spatial state and a rarer high-mobility/relocation state. High mobility is predominantly episodic rather than a fixed lifetime phenotype. Males appear more likely to enter the high-mobility state, while movement magnitude conditional on state is similar between sexes. V7 will test whether probabilistic infection history predicts future movement-state transitions and whether movement in turn predicts subsequent infection.

## Stop conditions before interpreting a V7 result

Do not interpret a V7 infection coefficient if:

- Rhat is materially above 1.05 for the coefficient or the transition parameters on which it depends;
- effective sample size is very low;
- infection timing is not aligned to the start of the movement interval;
- infection uncertainty has been discarded without justification;
- multi-year gaps dominate the apparent effect;
- sex is omitted despite its relation to both infection and movement;
- the result disappears under a reasonable movement-state/grid sensitivity;
- the infection posterior itself used the same movement outcome in a way that creates circularity.
