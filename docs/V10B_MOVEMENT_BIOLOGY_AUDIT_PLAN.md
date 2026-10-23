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

4. **Do sex and current chronological age matter?**
   Age-at-first-capture (cub/yearling/adult) is treated only as provenance for
   reconstructing birth year. For animals first caught as cubs or yearlings,
   current age is reconstructed for every annual movement interval. Adult
   entrants of unknown exact age are retained explicitly rather than being
   misclassified as a biological "adult" age category.

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
- current chronological-age effects on movement-state entry/transition;
- persistent individual mover propensity via a hierarchical badger random
  effect; this is now a preferred extension, subject to computational
  validation rather than a mere optional sensitivity;
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


## Preferred V11 transition structure after V10B validation

The working biological extension is now a persistent individual mobility
propensity combined with current chronological age.  A parsimonious formulation
is:

```
b_i ~ Normal(0, sigma_badger)

logit P(z_it = high | z_i,t-1 = local)
  = alpha_RD + beta_RD_sex * sex_i + f(age_it) + b_i

logit P(z_it = high | z_i,t-1 = high)
  = alpha_DD + beta_DD_sex * sex_i + f_DD(age_it) + kappa * b_i
```

The first implementation should be simpler than the most general form:
non-centred `b_i = sigma_badger * u_i`, with the individual effect entering
high-state entry and then a posterior-predictive check of whether the observed
repeat-mover concentration is reproduced.  If repeat high-state runs remain
underpredicted, the same mobility propensity can then be allowed to influence
high-state persistence as well.

Age should be measured at the start of each annual movement interval.  The
initial audit should retain exact integer age and also report biologically
readable classes (0, 1, 2, 3--5, 6+).  Whether the fitted model uses categorical
age, a smooth/nonlinear function, or a simpler polynomial should be decided from
support across exact ages, not from age-at-first-capture labels.

For adult first-capture animals with unknown birth year, exact chronological age
is genuinely unavailable in the current database.  These animals remain in the
movement model using explicit unknown-age handling; they should not be deleted
or assigned an arbitrary adult age.
