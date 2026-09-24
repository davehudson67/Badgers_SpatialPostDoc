# Infected movers as potential spreaders — analysis plan

## Question

The existing V7b analysis asks whether a high-mobility episode makes the **moving badger itself** more likely to acquire infection later.

The next question is different:

> Do badgers that are already infectious, especially observed **Super excretors**, contribute disproportionately to onward transmission when they move between social groups?

The database label **Super excretor** is retained throughout. It represents the established Woodchester disease-state classification for animals with culture-positive shedding from at least two body/sample sites at the same capture occasion. The analysis should use that curated state rather than attempting to reconstruct the classification from raw diagnostic rows unless a separate validation exercise is required.

## Stage V7c-1 — support audit

Before fitting a recipient transmission model, quantify whether there is enough information to identify the proposed mechanism.

The audit script is:

```text
scripts/Woodchester_V7c_infected_movers_spreader_audit.R
```

Launcher:

```r
source("scripts/run_V7c_infected_movers_spreader_audit.R")
```

It reports:

- capture occasions and badgers in each observed disease state;
- Excretor and Super-excretor badger-years aligned to V7b-compatible movement intervals;
- posterior probability of high mobility by observed disease state;
- exact observed social-group and sett switches;
- whether the disease-status capture is recorded in the movement interval's destination social group;
- group-years receiving candidate Excretor / Super-excretor movers.

The audit is descriptive. It must not be interpreted as evidence that a mover caused infection in another badger.

## Stage V7c-2 — prospective recipient-risk model

If the audit shows adequate support, construct the analysis around **other susceptible badgers** in the destination group.

For a movement interval ending in year `t`:

1. identify the destination social group using exact observed annual group information;
2. identify other badgers observed as Excretor or Super excretor in that group/year;
3. distinguish stable residents from candidate incoming/high-mobility animals;
4. require the focal recipient to be susceptible before the outcome window;
5. model acquisition by the recipient after the candidate source event.

Candidate exposure variables should include:

```text
presence/count of observed Excretor movers
presence/count of observed Super-excretor movers
posterior high-mobility-weighted Excretor exposure
posterior high-mobility-weighted Super-excretor exposure
observed social-group-switching Excretor exposure
observed social-group-switching Super-excretor exposure
```

The observed social-group-switch definitions are especially useful as a model-independent sensitivity because they do not depend on the latent high-mobility state.

## Background infection pressure

A destination group that already has high infection prevalence is intrinsically more likely to generate new infections. Therefore mover-specific effects should not simply be compared with an unadjusted recipient model.

The recipient model should retain a background local infection-pressure term and explicitly distinguish:

```text
general infection prevalence in the destination group
versus
presence of a specific infectious mover / incoming Super excretor
```

Where possible, background pressure should exclude the candidate mover(s) whose effect is being tested, so that the specific mover term is not mechanically duplicated inside the prevalence covariate.

## Timing caution

Observed Excretor / Super-excretor state in destination year `t` shows that the animal was in that state at a capture during the year. It does not prove shedding at the exact instant of relocation.

Accordingly, initial language should be:

> candidate infected mover / candidate spreading event

rather than:

> transmission caused by the mover.

A later sensitivity can tighten timing to disease-state observations close to the movement/destination observation if sufficient events exist.

## Main biological contrast

The most informative comparison is likely to be:

```text
infectious resident
versus
infectious mover
versus
Super-excretor resident
versus
Super-excretor mover
```

This separates infectiousness from mobility. A Super excretor that remains within one social group may drive intense local transmission, whereas a Super excretor that relocates could plausibly contribute more strongly to between-group spread.

## Interpretation rule

The existing V7b result and this proposed V7c analysis answer different questions:

```text
V7b: does movement increase the mover's own subsequent acquisition risk?
V7c: does movement by an already infectious animal increase infection risk in other badgers?
```

Both can be true or false independently.
