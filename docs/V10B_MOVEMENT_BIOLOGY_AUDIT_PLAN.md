# V10B movement-biology audit plan

## Purpose

The V10B ANNUALNC_OVERLAP model remains the frozen baseline while the full chains
are continued. The next biological model will be chosen from evidence in the
fitted movement histories rather than by adding structure speculatively.

The audit is descriptive/model-diagnostic. It does **not** redefine the latent
movement state, alter priors, or change the SCR likelihood.

## Questions answered in one audit

1. **Does the two-state local/high representation capture most annual
   intervals robustly?**
   Robust high requires all three chains to have P(high) >= 0.80; robust local
   requires all three <= 0.20. The remainder are explicitly retained as
   uncertain.

2. **What does a high-mobility interval represent geometrically?**
   Robust high intervals are separated into candidate settled relocations,
   immediate returns, delayed returns, continued high mobility, and unresolved
   histories. These are descriptive labels based on annual-centre geometry,
   not new HMM states.

3. **Are high-mobility events concentrated in particular animals?**
   The audit records expected high-state counts, robust high counts, recurrence,
   consecutive high runs, the share of expected high events carried by the top
   10% of animals, and a Gini index. This is evidence relevant to a future
   individual mover-propensity random effect.

4. **Do sex and age matter?**
   Sex, entry age, exact reconstructed age where supported, and first versus
   later movement intervals are summarized without deleting adult entrants of
   unknown exact age.

5. **Does inferred movement correspond to historical recorded social-group
   change?**
   Capture-level recorded social group is summarized by animal-year. Same-SG
   versus changed-SG intervals are compared with inferred movement. This is an
   overlay/audit only; recorded SG is not treated as a fixed lifetime identity
   and is not inserted into the baseline SCR.

6. **What happened around the 2018 cull?**
   Annual P(high), displacement and SG change are shown through time and in a
   pre/onset/post window. This is temporal description only, not a causal cull
   analysis.

7. **Is there a signal of altered within-year spatial breadth around 2018?**
   The raw live-capture data are used to calculate animal-year observed capture
   span and RMS capture radius, including a stricter summary for animals caught
   in at least two quarters. These are sampling-dependent diagnostics, **not
   home-range estimates**.

8. **Does the quarterly AR(1) still look necessary?**
   The audit carries forward rho/omega and global-ridge diagnostics. If rho
   remains close to zero after continuation, an iid-quarter (rho=0) sensitivity
   becomes a high-value comparison. A signed-rho sensitivity remains required
   because the baseline restricts rho to (0,1).

9. **What biology characterizes the remaining computationally difficult
   histories?**
   Cross-chain state/trajectory-discordant intervals are annotated with sex,
   age, recurrence, SG change, year and cull phase.

## Candidate next models

The audit is designed to decide among, rather than automatically adopt:

- current two-state V10B as the reference model;
- iid quarterly deviations (rho = 0) sensitivity;
- signed rho sensitivity (-1 < rho < 1);
- age effects on movement-state entry/transition;
- persistent individual mover propensity;
- explicit excursion versus permanent-relocation biology;
- dynamic social-territory integration once bait-marking maps are ready;
- 2018 cull effects on annual relocation;
- 2018 cull effects on within-year ranging breadth.

The cull questions should eventually use spatial exposure if a defensible cull
footprint/intensity surface is available. A simple before/after contrast alone
must not be interpreted causally.

## Reproducible runner

`scripts/data_audits/run_V10B_full_movement_audit.sh` runs the global
diagnostic, state recovery, trajectory diagnostic and the biology audit for all
retained draws and, optionally, a late-chain window.

Example for the original 30k full fit:

```bash
FILE_STEM=V10B_RD_MULTILOC_AR1_COLLAPSED_ANNUALNC_OVERLAP \
MAX_BADGERS=1932 \
TAIL_MIN_RAW_ITER=22500 \
bash scripts/data_audits/run_V10B_full_movement_audit.sh
```

For the continuation fit, substitute the continuation stem after all three
chains have completed. The same audit code is then rerun unchanged.
