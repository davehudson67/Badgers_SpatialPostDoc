# 04 — Audits, checks, corrections and things we nearly missed

This document records the important checks done **after the main movement model was developed**. These are part of the scientific history, not housekeeping. Several changed how the later disease analyses should be interpreted.

---

# 1. Final movement-model convergence and state audit

After developing the modular movement model, the three final chains were combined and checked rather than simply accepting the model because it ran.

What was checked:

- Rhat and effective sample size for fitted parameters;
- agreement among chains in posterior probability of high mobility;
- numbers of intervals confidently classified as high mobility;
- whether the movement states retained a sensible relationship with observed displacement.

What we concluded:

- convergence was adequate for the Stage-1 purpose;
- the high-mobility state remained interpretable;
- high mobility was uncommon and mainly episodic;
- males were much more likely to initiate a local → high-mobility transition.

**Decision:** freeze Stage 1 and stop repeatedly redesigning the movement model before testing disease directionality.

---

# 2. Population-size audit before the directional analyses

An all-badger × all-infection-trajectory audit showed that using only the original 500-animal development sample would throw away a large amount of useful information.

The final directional population was therefore expanded to **1,285 badgers**: the animals capable of contributing ordered movement/infection information.

This increased the available information very substantially compared with the 500-badger pilots.

**Lesson:** the 500-badger runs were development/pilot analyses, not final population analyses.

---

# 3. Pairing audit: movement uncertainty and infection uncertainty

The final movement model produced 1,500 coherent sampled movement histories.

The infection model supplied 500 coherent infection histories.

Rather than classifying either process with a hard threshold, the Phase-2 builder paired them into 1,500 latent datasets:

- every movement history used once;
- each infection history used three times.

**Lesson:** uncertainty in both movement and infection must be propagated. Do not replace this with `P(infected) > 0.5` or `P(high mobility) > 0.5`.

---

# 4. First directional pilot: infection → later movement

The first V7a analyses suggested that infection might be associated with later high mobility.

At first this looked biologically interesting.

However, the timing was broad: infection status by Q4 of the origin year and movement over an annual interval can still occupy overlapping calendar windows.

That triggered a stricter audit rather than immediate interpretation.

---

# 5. Important whole-analysis review: things we had not dealt with strongly enough

A later whole-framework review identified several issues that had either been missed or not yet given enough attention.

## A. Repeated measures / stable individual differences

A population association can arise because some badgers are both naturally more mobile and more infection-prone.

That does not necessarily mean a particular badger becomes more at risk when **its own** movement changes.

### What we did about it

We added within-individual analyses.

For V7a, a badger-stratified conditional model asked whether the same animal became more likely to enter high mobility after infection.

For V7b, several approaches were tried. Absolute calendar time caused structural separation, and a random-intercept/Mundlak approach was numerically poor. The final sensitivity became a **time-stratified case-crossover analysis**.

### What we learned

The within-badger V7a result disappeared under strict temporal lag.

The within-badger V7b point estimates leaned positive, but were extremely imprecise because only a small number of event strata actually switched movement state.

---

## B. Clear temporal precedence

The original V7a same-year formulation could not guarantee that infection clearly occurred before the movement episode.

### What we did

We fitted a strict-lag version requiring infection to be established by Q4 of the **previous** year.

### What happened

The weak positive infection → movement signal disappeared.

**Current conclusion:** there is no robust evidence that established infection increases later high-mobility initiation.

---

## C. Local infection pressure — probably the biggest substantive omission

The primary V7b model treated every high-mobility relocation as equivalent.

But biologically a relocation into a low-infection area should not carry the same exposure as a relocation into a high-infection social group or neighbourhood.

This was a major conceptual point that had not been included in the original V7b formulation.

### This changed the next analysis question from:

> Does movement in general increase later infection risk?

### to:

> Does movement matter depending on the infection environment the animal reaches?

### What we have now done

We audited annual social-group and spatial information, then built posterior infection-pressure measures for every V7b interval and every infection trajectory.

These include:

- same-social-group infection prevalence;
- prevalence within 500 m;
- prevalence within 1 km;
- prevalence within 2 km;
- exponential distance-weighted pressure at 500 m scale;
- exponential distance-weighted pressure at 1 km scale.

Same-group pressure retained the most information and is the current first-choice pressure model.

**Status:** current analysis frontier.

---

## D. Survival / informative disappearance

The movement model deliberately stops at the last observed live year.

That is computationally sensible, but a final disappearance could mean:

- death;
- permanent emigration;
- continued survival with no later recapture.

If infection increases mortality, or high mobility increases permanent emigration, conditioning on being observed can distort the apparent movement/infection relationship.

### Status

**Not yet fully resolved.**

The agreed next step is a survival/disappearance diagnostic before considering a much larger open spatial survival model.

This remains an important limitation and must be visible in the repository documentation.

---

## E. Time since infection

Treating all infected badgers the same may hide a response that occurs only soon after acquisition or later in disease progression.

Possible future comparison:

- newly infected;
- infected for one year;
- longer-established infection.

### Status

**Still outstanding.**

---

## F. High-mobility persistence (D → D)

Most of the disease analyses focus on initiation of high mobility (local → high).

Another possible question is whether infection affects **persistence** once an animal is already in a high-mobility state.

### Status

The movement model estimates D → D persistence, but an infection effect on that transition has not been a primary directional analysis.

**Still a possible secondary analysis.**

---

## G. Alternative infection histories

The primary infection trajectory set is the **all-tests inferred** model.

A strong sensitivity analysis would repeat key disease-direction conclusions using alternatives such as:

- all-tests fixed;
- culture-only.

### Status

**Still outstanding.**

This is preferable to pretending the infection model itself is certain.

---

## H. Observed movement outcomes independent of the latent HMM

Because movement state is model-derived, it is useful to ask whether conclusions are also visible using simpler observed quantities such as:

- observed annual displacement;
- sett switching;
- social-group switching;
- distance thresholds.

### Status

**Still outstanding.**

These would be sensitivity checks, not replacements for the spatial model.

---

## I. Event-study around infection acquisition

Instead of reducing the whole history to one before/after coefficient, an event-study could describe movement in years around inferred infection acquisition.

For example:

```text
2 years before
1 year before
infection/acquisition window
1 year after
2 years after
```

This could reveal short-lived movement changes that are lost in a single coefficient.

### Status

**Still outstanding.**

---

## J. Infected movers as spreaders, not just recipients

The V7b question asks whether moving makes the **moving badger** more likely to acquire infection.

That is different from asking whether an already infected high-mobility badger carries infection into another area and increases infection risk for **other badgers**.

This may ultimately be the more important population-level transmission question.

A future spatial hazard model could use:

- infected neighbours;
- same-group infection pressure;
- distance kernels;
- movement-weighted infectious pressure;
- possibly directional spread.

### Status

**Future major analysis.**

---

# 6. V7b numerical robustness audit

The primary modular V7b analysis used importance sampling.

Seven paired histories had relatively poor importance-sampling efficiency.

Rather than ignoring this, those seven were rerun with much larger defensive proposals.

Their effective sample sizes improved dramatically and the pooled movement coefficient was unchanged to the reported precision.

**Lesson:** the primary V7b result is not an artefact of those seven weak numerical fits.

---

# 7. V7b within-individual methods audit

Several within-badger approaches were tried.

## Attempt 1 — ordinary badger-stratified conditional logistic regression

Problem: calendar-period coefficients repeatedly showed separation.

## Attempt 2 — add linear calendar year

Problem: complete structural failure. Within an event badger, the infection event is necessarily the final susceptible risk occasion, so absolute time predicts the ordering mechanically.

This was a **design problem**, not just a software problem.

## Attempt 3 — Mundlak/random-intercept model

Problem: singular fits, Hessian warnings and large gradients.

## Final approach — time-stratified case-crossover

The badger was matched to itself within 5-year and 10-year calendar blocks instead of trying to estimate an absolute time coefficient.

This fitted cleanly.

Result: positive point estimates but huge intervals because only about 14–20 exposure-switching event strata were informative per paired history.

**Lesson:** the within-animal data do not rule out a short-term positive movement effect, but they do not establish one.

---

# 8. Spatial coordinate audit — an important correction

During the local-pressure work, one audit temporarily interpreted:

- `from_primary`
- `to_primary`

as if they were detector-row indices.

That happened because the integer values happened to fall inside the number of detector rows.

The next review caught the problem.

The corrected v3 audit proved for **all 5,667 movement intervals** that these variables are actually temporal primary-occasion indices:

```text
chain$years[from_primary] = from_year
chain$years[to_primary]   = to_year
```

with 100% agreement.

### Consequence

The endpoint distances produced by the superseded coordinate-resolution audit are invalid and must not be used.

In particular, do not use:

`results/phase2_movement_observed_endpoint_coordinates.csv`

from that superseded audit.

### Correct spatial sources

We instead use:

- Stage-1 observed annual XY locations;
- observed annual sett coordinates;
- observed annual social groups.

This correction needs to remain permanently documented because it is exactly the kind of mistake that could otherwise be rediscovered years later.

---

# 9. Correct location-resolution audit

The corrected spatial audit showed:

- 4,598 Stage-1 observed annual XY locations;
- 93.5% of encounter rows map to sett coordinates;
- about 94% of annual observed badger-years have sett XY;
- about 98% have annual social-group information.

Stage-1 annual XY also agreed closely with observed same-year sett positions.

This gave us a defensible observed-location basis without claiming that posterior annual activity-centre coordinates had been saved.

---

# 10. Infection-pressure construction audit

The pressure builder then tested whether enough actual V7b information survives when local pressure is required.

Approximate retention:

- same-group pressure: 77% of risk quarters and 81% of infection events;
- distance measures: about 76% of risk quarters and about 81% of events.

Same-group pressure has a median of about 9 other observed badgers contributing to the denominator.

The distance-based metrics are highly correlated with one another, whereas same-group pressure is only moderately correlated with them.

**Decision:** fit same-group pressure first, then one selected distance-weighted sensitivity rather than six near-duplicate spatial models.

---

# 11. What is complete and what remains open?

## Completed / frozen

- final movement model;
- chain diagnostics;
- FFBS movement histories;
- paired infection/movement histories;
- primary V7a;
- V7a stricter timing and within-badger checks;
- primary V7b;
- V7b numerical robustness;
- V7b time-stratified within-badger sensitivity;
- corrected spatial-location audit;
- local infection-pressure construction.

## Current

- same-social-group infection-pressure model.

## Still worth doing

- selected distance-weighted pressure sensitivity;
- survival/informative disappearance diagnostic;
- alternative infection-history sensitivity;
- time-since-infection analysis;
- observed-movement sensitivity;
- event-study around acquisition;
- infected-mover / population-spread analysis.

---

# 12. The overall lesson from the audits

The project did not simply fit one increasingly complicated model.

It repeatedly asked:

1. Is the movement state identifiable?
2. Is the numerical fit trustworthy?
3. Does the timing really establish direction?
4. Could stable differences among badgers explain the association?
5. Are we measuring the relevant exposure environment?
6. Are we conditioning on survival/continued observation in a problematic way?
7. Does a model-derived conclusion survive simpler alternative definitions?

Those checks are part of the scientific result and should remain in the repository alongside the final models.
