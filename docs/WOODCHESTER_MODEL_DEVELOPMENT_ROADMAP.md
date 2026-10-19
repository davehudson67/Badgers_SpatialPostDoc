# Woodchester Badger Modelling Development Roadmap

**Status:** Living project document  
**Last updated:** 19 October 2026  
**Purpose:** Prevent duplicated modelling, preserve decisions across chat windows, and keep the route from movement modelling to demography, infectiousness and social structure explicit.

---

## 1. Core scientific objective

The modelling programme is no longer simply about estimating movement distance. The overarching aim is to understand how individual behaviour, population turnover, social structure and disease transmission interact through time.

The intended causal/biological hierarchy is:

```
individual attributes
    ↓
movement state / movement propensity
    ↓
social-group encounter and boundary crossing
    ↓
entry / settlement / survival / apparent emigration
    ↓
infectiousness and transmission opportunity
```

These processes can also act in the reverse direction. In particular, infectiousness may alter movement, survival or disappearance, while movement and immigration may alter subsequent exposure and acquisition risk.

A major project rule is therefore:

> Do not refit a question already answered by an earlier modular analysis unless the new model changes the biological estimand, data support, or latent-state architecture in a meaningful way.

---

## 2. Terminology that must remain distinct

### Infection

“Infector/infected” in the earlier Phase-2 work refers to the latent infection-acquisition trajectory derived from the infection-probability model, particularly the `all_tests_inferred` trajectory.

This describes whether an animal is inferred to have acquired infection by a given quarter.

### Infectiousness

“Infectious” is not synonymous with “infected”.

For the next disease stage, the biologically relevant transmission state should represent evidence that an infected animal is capable of transmitting *M. bovis* — for example a shedding/culture-positive or otherwise defensibly defined infectious state.

The exact operational definition still requires a dedicated diagnostic-data audit. Culture sample type, repeated culture positivity, lesions/PM information and other diagnostic evidence are available in the database and should be evaluated explicitly.

**Project decision:** future transmission-focused models should prioritise infectiousness, not merely repeat the infected/uninfected analyses.

### Social-group membership versus social-group boundary

These must also remain distinct.

- **Membership:** the historically recorded or inferred social group associated with a badger/sett in a particular year.
- **Boundary:** the spatial territory boundary separating groups in a particular period.

A historical group label is not automatically a polygon boundary, and a present-day polygon must not be retrospectively applied to all years.

---

## 3. What has already been fitted or investigated

### V4/V5-era spatial movement and social resistance — development work

Earlier spatial CMR development models included social-group/peripheral resistance in the movement kernel.

The V5 development script also introduced a latent immigrant status for adult-entry animals, inferred without using sex, with potential effects on annual movement scale and apparent survival.

Important interpretation:

- this established that immigration, movement and survival can be represented jointly;
- it was a development/test architecture, not the final immigration result;
- it used an earlier movement likelihood and earlier population definition;
- it should therefore inform V12 design, not be treated as the final immigration analysis.

**Do not simply resurrect V5.**

---

### V7M — production movement histories for directional disease analyses

The V7 movement model generated posterior movement-state histories for the population contributing to the directional disease analyses.

Its two-state annual movement process distinguished local/stable versus high-mobility movement.

This supplied latent movement histories to the modular V7a-M and V7b-M analyses.

---

### V7a-M — infection acquisition/status → subsequent movement

**Already fitted. Do not repeat as the same question.**

Question:

> Does prior latent infection predict a later transition from local to high mobility?

Definition used:

- infection acquired by Q4 of the movement interval’s origin year;
- only local → high transitions;
- sex included;
- first movement interval excluded because it is an initial state rather than a transition.

Primary full 1,500-pair result:

- `beta_inf` median ≈ **0.113**
- 95% credible interval ≈ **-0.347 to 0.529**
- P(`beta_inf > 0`) ≈ **0.692**
- infection OR median ≈ **1.12**

Interpretation:

> There was no strong evidence that latent infection status increased subsequent entry into the high-mobility state.

Important sensitivities were also fitted.

A strict lagged analysis produced essentially no directional signal:

- `beta_inf` median ≈ **-0.047**
- 95% CI ≈ **-0.658 to 0.487**
- P(positive) ≈ **0.435**

A within-individual lag-0 sensitivity was more positive but highly uncertain:

- median ≈ **0.502**
- 95% CI ≈ **-0.614 to 1.626**

**Conclusion for future work:** the generic question “does being infected cause more movement?” has already been investigated. A new integrated disease model should only revisit this if the exposure becomes **infectiousness**, disease progression stage, or a materially improved joint latent-state formulation.

---

### V7b-M — high mobility → subsequent infection acquisition

**Already fitted. Do not repeat as the same question.**

Question:

> Among animals susceptible at Q4 of year t, does high mobility during the movement interval ending in year t predict infection acquisition in Q1-Q4 of year t+1?

Primary full 1,500-pair result:

- `beta_move` median ≈ **-0.198**
- 95% credible interval ≈ **-1.242 to 0.537**
- P(`beta_move > 0`) ≈ **0.316**
- OR high mobility ≈ **0.82**

The numerical robustness patch produced essentially the same result.

Interpretation:

> The primary population-level analysis provided no evidence that the old high-mobility state increased subsequent infection acquisition risk.

Within-individual/time-stratified sensitivities were more positive but very imprecise:

- within-individual median ≈ **0.694**, 95% CI ≈ **-1.35 to 2.77**;
- 5-year time-stratified median ≈ **0.697**, 95% CI ≈ **-1.35 to 2.76**;
- 10-year time-stratified median ≈ **0.381**, 95% CI ≈ **-1.36 to 1.88**.

These were explicitly treated as low-power sensitivities, not replacements for the primary result.

**Conclusion for future work:** the generic question “does high mobility cause later infection acquisition?” has already been tested. Do not repeat it unchanged in V13.

---

### V7b spatial infection pressure

A separate framework was built to represent infection pressure around a focal susceptible badger at Q4 of year t.

It calculated:

- same-social-group infection prevalence;
- prevalence within 500 m;
- prevalence within 1,000 m;
- prevalence within 2,000 m;
- exponential distance-weighted prevalence at 500 m and 1,000 m scales.

The focal badger was excluded from source animals and exact observed year-specific social-group/location information was used where available.

Crucially, source state was:

> **latent infected by Q4**, not a separate infectious/shedding state.

The same-group pressure model was identified as the preferred first mechanistic pressure model because of its biological interpretation.

Scripts for same-group pressure models exist, but no final same-group pressure result is currently committed in the repository. Until a local result is verified, treat this as **developed methodology / incomplete result**, not an established biological conclusion.

**Future use:** recycle the architecture, but replace “infected source prevalence” with a defensible **infectious-source pressure** where possible.

---

### V8 — movement and age development

V8 extended movement work to larger populations and explored age-related movement.

This has now been superseded conceptually by V11 because V11 uses current chronological age, retains unknown-age animals explicitly, and sits on the audited V10 spatial observation architecture.

Do not revive age-at-entry as the biological age effect.

---

### V10A/V10B — modern movement architecture and audit

V10 modernised the movement model by retaining multiple capture locations within quarterly campaigns and explicitly modelling annual and quarterly spatial centres.

The major V10B audit established:

- a biologically meaningful two-state local/high annual movement structure;
- strong correspondence between robust high-mobility intervals and recorded social-group change;
- repeat movers are concentrated among a subset of animals;
- male movement is more likely to enter the high-mobility state;
- current chronological age is preferable to age at first capture;
- excursions exist, but a third excursion state is not currently a priority;
- terminal high-mobility events make survival/apparent emigration a more urgent extension;
- the AR(1) quarterly persistence parameter was weak and not worth carrying forward;
- post-2018 movement patterns warrant later calendar/cull analysis but should not yet be labelled a cull effect.

**Decision:** V10B is frozen. No further V10B runs are required.

---

### V11 — current model

V11 is the final movement-only biological extension before demography.

It retains:

- two-state annual local/high movement;
- modern multi-location quarterly observation model;
- sex effects;
- collapsed HMM state inference;
- non-centred annual trajectory parameterisation.

It adds:

1. **current chronological age** at the start of each movement interval;
2. **persistent individual mover propensity** `b_i`;
3. `rho = 0`, giving iid quarterly deviations around annual centres.

Age categories in the initial V11 formulation:

- 0-1 years: reference;
- age 2;
- age 3-5;
- age 6+;
- exact age unknown.

The individual effect currently enters:

- initial probability of high mobility;
- local → high transition probability.

It does not currently enter high → high persistence.

#### V11 50-badger smoke result

The model compiled, ran, recovered states and combined successfully.

The repeat-mover posterior predictive check was encouraging:

- Gini: posterior-state ≈ **0.851**, replicated ≈ **0.857**;
- top-10% share: ≈ **0.720** versus **0.734**;
- total high events: ≈ **13.1** versus **13.4**;
- maximum consecutive run was not underpredicted.

Therefore there is currently **no evidence that the badger random effect needs to be added to high → high persistence**.

The 50-badger run is not large enough to estimate final age/random-effect magnitudes.

#### Current next step

Run the 300-badger V11 validation.

The 300 run should answer:

- is `sigma_badger` genuinely informed by the data?
- what is the current-age pattern?
- does removing `rho` improve the movement-scale decomposition?
- does the repeat-mover PPC remain satisfactory?

If satisfactory, stop developing the movement-only model.

---

## 4. What remains to be fitted

### V12 — population entry, survival and apparent emigration

**Priority after V11.**

The current movement model conditions on an observed first-to-last history. It does not explicitly distinguish population entry, retention, mortality and permanent emigration.

V12 should add a demographic/presence process.

Conceptually:

```
not yet present → present → gone
```

Key quantities:

- entry / recruitment into the observed study population;
- apparent survival / retention;
- permanent disappearance.

Known deaths should be used wherever possible.

Where death is not known, disappearance should initially be interpreted as:

> **apparent survival/retention = survival × remaining within the observable population**

rather than pretending mortality and permanent emigration are separately identified.

#### Main V12 biological questions

- Does a high-mobility interval increase subsequent probability of disappearance?
- Are newly entering animals especially likely to exhibit high mobility?
- Does mover propensity predict apparent emigration?
- Do sex and chronological age alter entry/retention?
- Can probable immigrants be identified from their full demographic/spatial history rather than declared from sex or adult-entry status?

#### Relationship to old V5 immigration model

V5 is useful proof-of-concept but V12 should rebuild immigration/demography using the modern V11 observation and movement architecture.

Do not treat V5 latent immigrant classifications as final truth.

---

### V13 — infectiousness, transmission and movement/demography

This is the major disease extension.

The starting point should **not** be another infected/uninfected regression, because V7a-M and V7b-M already tested those directional questions.

Instead V13 should distinguish, as data permit:

```
susceptible / not yet infected
        ↓
infected but not demonstrably infectious
        ↓
infectious / shedding
```

The exact state structure must be driven by the diagnostic audit rather than assumed in advance.

Candidate evidence for infectiousness includes culture results and potentially the type/site/persistence of positive culture, plus other disease-severity information where biologically justified.

#### Priority V13 questions

1. **Movement → infectiousness/progression**
   - Does high mobility or boundary crossing predict transition from infected to infectious?
   - This is different from the already-completed movement → infection-acquisition analysis.

2. **Infectiousness → movement**
   - Do infectious animals alter their movement state, movement distance or social-group switching?
   - This is different from the already-completed infected → movement analysis.

3. **Infectiousness → survival/apparent emigration**
   - Does becoming infectious alter survival or disappearance?

4. **Immigration → infectiousness**
   - Are probable immigrants more/less likely to arrive infectious or become infectious after arrival?

5. **Infectious-source pressure → acquisition**
   - Does exposure to infectious animals, particularly within the same social group or across changing boundaries, predict infection acquisition?

6. **Movement × infectious pressure**
   - Does movement matter primarily by moving a susceptible animal into a different infectious-pressure environment?
   - In this formulation, infection pressure may be a mediator rather than a confounder.

---

## 5. Social-group boundaries through time

This must become an explicit project workstream rather than an implicit static map.

### What we already know

The database now preserves:

- recorded capture-level social-group information;
- canonical social-group IDs;
- observed sett/social-group/year combinations;
- historically supported sett ↔ social-group relationships with validity dates;
- social-group ↔ supergroup history.

Historical group assignment must not be overwritten simply because a sett has a different present-day group.

### What older models did

Some earlier spatial movement models used a spatial `SG_mat` and estimated resistance to movement into another group/peripheral habitat.

This was useful development work, but the spatial group layer was effectively a static landscape representation.

That is not adequate for a 50-year analysis if group territories move, split, merge or are renamed through time.

### What V10/V11 currently do

V10/V11 deliberately do **not** fit social-group boundary resistance in the movement kernel.

Recorded social-group change has instead been used as an external biological validation of the inferred high-mobility state.

This is useful because it avoids circularly defining high mobility using group change.

### Required dynamic-boundary audit

Before inserting group boundaries into V12/V13, build a year-specific social-structure audit.

For every year, establish:

- active social groups;
- setts observed in each group;
- historically supported sett ↔ group assignments;
- group renames;
- splits;
- mergers;
- uncertain/conflicting assignments;
- spatial support available to estimate a territory boundary.

Do **not** interpolate a group history silently.

### Potential year-specific spatial product

If the historical support is adequate, create a versioned object such as:

```
social_group_boundaries_by_year
```

containing a polygon or probabilistic territory surface for every supported group-year.

The construction method must be audited. A Voronoi/Thiessen surface around active setts may be a useful baseline, but it should not automatically be treated as the biological truth. Alternative territory constructions should be checked where data support them.

### Derived transition variables

For each annual movement interval, potential derived quantities include:

- origin social group;
- destination social group;
- whether a group boundary was crossed;
- number of group boundaries crossed;
- distance travelled outside the origin territory;
- proportion of the movement kernel lying outside the origin territory;
- destination-group identity;
- whether the destination group persisted, split or merged;
- change in infectious-source pressure across the movement.

### Where boundary information belongs

**V11:** validation/descriptive overlay only.

**V12:** candidate modifier of movement/settlement and apparent emigration. A high-mobility event that crosses a contemporary group boundary is biologically different from a large movement inside a large territory.

**V13:** central to transmission opportunity. Dynamic boundaries determine who plausibly shares space/social contacts and therefore help define infectious pressure.

**Do not make boundary crossing the definition of the high-mobility state.** Keep movement inferred from spatial data, then use boundaries as explanatory/mechanistic information.

---

## 6. Analyses that should not be repeated unnecessarily

| Question | Status | Action |
|---|---|---|
| Infected status → later high mobility | Done: V7a-M | Do not repeat unchanged |
| High mobility → later infection acquisition | Done: V7b-M | Do not repeat unchanged |
| Within-individual movement → infection acquisition | Done as low-power sensitivity | Retain as sensitivity evidence |
| Static infected-source spatial pressure | Built | Reuse architecture; upgrade to infectious-source pressure |
| Same-group infected prevalence model | Scripts exist; final committed result not found | Verify local result before claiming conclusion |
| Age-at-entry effect on movement | Superseded | Use current chronological age |
| Two-state local/high movement | Audited and retained | Keep |
| Third excursion state | Deferred | Do not prioritise |
| Quarterly AR(1) persistence | Dropped | Keep rho = 0 unless future evidence demands otherwise |
| V10B continuation/sampler refinement | Stopped | Do not restart |
| Latent immigrant status | Earlier V5 proof-of-concept only | Rebuild properly in V12 |
| Social-group resistance with static boundaries | Earlier development only | Replace with time-aware treatment if used |
| Infectiousness-specific movement/demography | Not yet fitted | Priority disease extension |

---

## 7. Proposed model sequence from here

### Immediate

**V11 300-badger validation**

Decision gate only. Do not create a long new V11 development branch unless there is a clear failure.

### Next

**V12 — demographic/open-population model**

Carry forward the accepted V11 movement process and add:

- entry;
- presence;
- known death information;
- apparent survival/retention;
- permanent disappearance/emigration.

At the same time, build the **dynamic social-group boundary audit** as a parallel data product.

### Then

**V13 — infectiousness model**

First perform the infectiousness-definition audit.

Then integrate infectiousness with:

- V11 movement state and mover propensity;
- V12 population state;
- dynamic social-group membership/boundaries;
- infectious-source pressure.

### Later/explanatory extensions

After the core joint model works:

- calendar-year/cull-era effects;
- environmental/climate effects;
- changes in group density/territorial structure;
- individual disease progression;
- mechanistic mediation through social-group exposure.

---

## 8. Decision rules for future development

Before adding any new model term, record:

1. **Scientific question**
2. **Whether the question has already been tested**
3. **What is genuinely different about the new estimand**
4. **Data source**
5. **Temporal ordering**
6. **Latent versus observed variables**
7. **Potential identifiability problem**
8. **Minimal diagnostic required**
9. **Decision after the diagnostic**
10. **Whether the model becomes part of the production pathway or remains a sensitivity**

This prevents model-number inflation and protects the main biological trajectory.

---

## 9. Current working decisions

- V10B is frozen.
- V11 is the current movement model.
- Use chronological age, not age at first capture.
- Retain a persistent individual mover-propensity effect unless the 300-badger validation contradicts it.
- Do not add the badger effect to high→high persistence unless the repeat-mover PPC shows that it is needed.
- Do not introduce a third excursion state yet.
- Move next to demographic entry/survival/apparent emigration.
- Do not repeat generic infected ↔ movement analyses.
- Future disease work should distinguish **infected** from **infectious**.
- Social-group boundaries must be treated as potentially changing through time.
- Do not retrospectively apply a present-day social-group map to the full study.
- Use social-group change/boundaries as explanatory/mechanistic structure, not as the definition of the latent movement state.
- Maintain this document whenever a modelling decision changes.

---

## 10. Next concrete actions

1. Complete the V11 300-badger validation.
2. Audit whether final same-group pressure results exist locally and add them to this roadmap.
3. Build a dedicated **infectiousness phenotype/state audit** from diagnostic data.
4. Build a **time-varying social-group structure audit** from capture-level group records and historical sett/group relationships.
5. Specify V12 mathematically before coding it.
6. Carry accepted V11 movement structure directly into V12.
7. Design V13 around infectiousness/progression and infectious-source pressure rather than repeating infection-acquisition regressions.

