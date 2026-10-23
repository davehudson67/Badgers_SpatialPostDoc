# Woodchester Badger Modelling Development Roadmap

**Status:** Living project document  
**Last updated:** 23 October 2026  
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



---

# 11. Full model lineage and what each stage contributed

This section is deliberately broader than the immediate V11-V13 plan. It records
the methodological ancestry so that future development does not accidentally
recreate an old branch.

| Stage | Main purpose | Important development | Current status |
|---|---|---|---|
| V1 | Robust-design spatial CMR on full historical dataset | Years as primary occasions, four trapping seasons, sett-coordinate detection, annual movement, entry-group detection/survival | Historical scaffold; superseded |
| V2 | Improve annual activity-centre process | Latent first-year AC and direct bivariate-normal annual AC transitions | Historical scaffold; superseded |
| V3 | Introduce spatial landscape/state space | 50 m habitat/social-group grid, explicit spatial state-space constraints | Important ancestry; superseded |
| V3c | Test heavy-tailed movement | Non-centred bivariate Student-t3 movement; deliberately excluded SG penalty until it could be normalized correctly | Development result; superseded |
| V4c | Add normalized social landscape and sex | Dynamic normalization for social-group/peripheral resistance; latent/partly observed sex; sex effects on survival, detection and movement | Important proof-of-concept; not current model |
| V5 / V5c / V5d | Immigration development | Latent immigrant status among adult-entry badgers, inferred without sex; movement and in some variants survival effects; adult-enriched sampling; prepared-data version | Proof-of-concept only; informs V12 |
| V6c | Resident/local versus disperser/high-mobility states | Two-state annual movement HMM, wide movement support, sex-specific state dynamics; survival deliberately conditioned out | Direct ancestor of modern movement-state interpretation |
| V7a-T / V7b-T | Early integrated directional disease attempts | Infection→movement and movement→infection built directly into larger trajectory models | Superseded by modular V7 framework |
| V7M | Freeze movement then analyse disease directionally | Production movement-only fit with posterior movement histories exported downstream | Historical production base for V7a-M/V7b-M |
| V7a-M | Infection acquisition/status→movement | Modular directional analysis integrating movement and infection-history uncertainty | Completed biological analysis |
| V7b-M | Movement→infection acquisition | Modular susceptible-risk analysis with time ordering and robustness analyses | Completed biological analysis |
| V7b pressure | Mechanistic exposure environment | Same-group and Euclidean infection-pressure covariates based on latent infected sources | Method developed; final same-group result requires verification |
| V8 age | Chronological-age extension | Reconstructed age for known-age animals; tested age effects on high-mobility initiation | Superseded by V11's more inclusive age treatment |
| V8 maximal | Maximise movement population | Expanded movement inference to 1,932 spatially informative badgers; removed disease-analysis restriction | Important population-definition step |
| V10A | Multi-location quarterly observation model | Retained multiple within-quarter spatial observations rather than one selected sett | Modern observation-model foundation |
| V10B | AR(1) quarterly centres + extensive sampler/biology audit | Collapsed movement HMM, non-centred annual trajectory, overlapping blocks, state recovery, trajectory/ridge audits | Frozen reference model |
| V11 | Age + persistent individual mobility propensity | rho=0; current chronological age; badger random effect on entry to high mobility | Current active movement model |
| V12 | Open-population demography | Entry, survival/retention, known death, apparent emigration, immigrant inference | Next major model |
| V13 | Infectiousness/transmission | Distinguish infected from infectious; movement/demography/social exposure interactions | Planned after V12 |

## Why the numbering can be misleading

Several version numbers contain multiple experimental branches. A larger number
does not automatically mean that every ingredient of the earlier model should
be carried forward.

For example:

- V4/V5 social-group resistance was useful proof-of-concept, but it relied on a
  largely static spatial social-group layer;
- V5 immigration was useful proof-of-concept, but used an earlier movement and
  observation architecture;
- V7 directional disease models answered specific questions that should not be
  repeated merely because V13 will use a newer movement model;
- V10B's AR(1) quarterly process was investigated and intentionally removed from
  V11.

The scientific lineage is therefore **selective**, not cumulative.

---

# 12. Evidence ledger: completed biological questions

This is the canonical “have we already answered this?” table.

| Biological question | Best existing analysis | Main result | Repeat? |
|---|---|---|---|
| Are there distinct local and high-mobility annual movement states? | V6/V7 then V10 audit | Yes; V10 independent SG-change validation strongly supports interpretation | No |
| Are males more likely to show high mobility? | V6/V7/V10 | Strong recurring male signal | Retain as covariate; no need to rediscover |
| Does infection acquisition/status predict later high mobility? | V7a-M | Weak/uncertain overall effect; strict lag essentially null | No, unless exposure becomes infectiousness/progression |
| Does high mobility predict subsequent infection acquisition? | V7b-M | No positive primary population-level effect | No, unless outcome becomes infectiousness/progression or mechanism differs |
| Is within-animal movement associated with acquisition? | V7b within/time-stratified sensitivities | Positive point estimates but very wide uncertainty | Keep as sensitivity evidence; do not make primary |
| Is movement concentrated among repeat movers? | V10 audit | Yes, strongly | V11 is the formal model for this heterogeneity |
| Does a persistent individual effect reproduce repeat-mover concentration? | V11 50-badger smoke | Yes structurally; PPC concentration metrics reproduced closely | Validate at 300; do not add extra persistence effect unless needed |
| Is quarterly AR(1) persistence essential? | V10B audit | Weak rho and problematic decomposition | No; V11 fixes rho=0 |
| Are excursions present? | V10 biology audit | Yes, but not sufficiently important to justify third state now | Defer |
| Are terminal high movements important? | V10 biology audit | Yes; major unresolved biological class | Address in V12 |
| Can latent immigration be modelled at all? | V5 development | Yes in principle | Rebuild in V12 with modern architecture |
| Does social-group change validate high mobility? | V10 biology audit | Strongly yes | Use as external validation/mechanistic overlay |
| Does infected-source spatial pressure have usable data support? | V7b pressure build/audit | Yes for several metrics including same-group pressure | Reuse architecture, but distinguish infected from infectious |

---

# 13. Canonical result files for completed directional disease work

These files contain the results that must be checked before anyone proposes
re-fitting the same infection/movement question.

## Infection/status → subsequent movement

Primary:

```
results/V7aM_infection_to_movement_FULL_1500_summary.csv
```

Additional sensitivity results:

```
results/V7aM_sensitivity_period_entry_lag0_FULL_1500_summary.csv
results/V7aM_sensitivity_period_entry_lag1_STRICTLAG_FULL_1500_summary.csv
results/V7aM_within_individual_v3_lag0_FULL_1500_summary.csv
results/V7aM_within_individual_v3_lag1_STRICTLAG_FULL_1500_summary.csv
```

Primary model documentation/code:

```
scripts/ModularFitting/V7aM_README.txt
scripts/ModularFitting/Woodchester_V7aM_infection_to_movement_modular_IS.R
scripts/ModularFitting/run_V7aM_FULL_1500pairs.R
```

## Movement → subsequent infection acquisition

Primary:

```
results/V7bM_movement_to_infection_FULL_1500_summary.csv
```

Numerical robustness:

```
results/V7bM_movement_to_infection_FULL_1500_ROBUST_summary.csv
```

Within-individual/time-stratified sensitivities:

```
results/V7bM_within_individual_FULL_1500_summary.csv
results/V7bM_time_stratified_within_5yr_FULL_1500_summary.csv
results/V7bM_time_stratified_within_10yr_FULL_1500_summary.csv
```

Mundlak/random-intercept development:

```
results/V7bM_Mundlak_random_intercept_SMOKE_10_summary.csv
```

Primary documentation/code:

```
scripts/ModularFitting/V7bM_README.txt
scripts/ModularFitting/V7bM_ROBUSTNESS_README.txt
scripts/ModularFitting/Woodchester_V7bM_movement_to_infection_modular_IS.R
scripts/ModularFitting/Woodchester_V7bM_robustness_patch_poor_IS_pairs.R
```

## Spatial infection pressure

Build/audit:

```
scripts/Woodchester_V7b_build_spatial_infection_pressure.R
scripts/V7b_SPATIAL_PRESSURE_BUILD_README.txt
scripts/Woodchester_SPATIAL_INFECTION_PRESSURE_input_audit.R
scripts/SPATIAL_INFECTION_PRESSURE_AUDIT_README.txt
```

Existing pressure products/results include:

```
results/V7b_spatial_pressure_distribution.csv
results/V7b_spatial_pressure_posterior_mean_by_interval.csv
results/V7b_spatial_pressure_risk_event_retention.csv
results/V7b_spatial_pressure_support_summary.csv
results/spatial_pressure_group_year_support.csv
```

Same-group pressure model code/documentation:

```
scripts/Woodchester_V7bM_samegroup_pressure_models.R
scripts/V7bM_SAMEGROUP_PRESSURE_README.txt
```

**Current repository status:** no final same-group pressure result file was found
when this roadmap was updated. Verify local/uncommitted outputs before rerunning.
If no valid result exists, this is one of the few older analyses that may still
need completion.

---

# 14. Canonical modern movement files

## V10 reference/audit

Key reference model:

```
scripts/ModularFitting/Woodchester_V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_ANNUALNC_OVERLAP.R
```

Important V10 diagnostics:

```
scripts/ModularFitting/Woodchester_V10B_collapsed_recover_states.R
scripts/ModularFitting/Woodchester_V10B_collapsed_combine_chains.R
scripts/ModularFitting/Woodchester_V10B_collapsed_global_ridge_diagnostic.R
scripts/ModularFitting/Woodchester_V10B_collapsed_postadapt_diagnostic.R
scripts/ModularFitting/Woodchester_V10B_collapsed_trajectory_chain_diagnostic.R
scripts/ModularFitting/Woodchester_V10B_collapsed_trajectory_support_audit.R
scripts/data_audits/V10B_full_movement_biology_audit.R
```

Documentation:

```
docs/V10B_COLLAPSED_MODEL_ANNOTATED_GUIDE.md
docs/V10B_MOVEMENT_BIOLOGY_AUDIT_PLAN.md
```

V10B is frozen. The continuation jobs were stopped on 19 October 2026.

## V11 active files

Fitter:

```
scripts/ModularFitting/Woodchester_V11_RD_SCR_MULTILOC_IID_AGE_BADGERRE.R
```

State recovery:

```
scripts/ModularFitting/Woodchester_V11_recover_states.R
```

Three-chain combination:

```
scripts/ModularFitting/Woodchester_V11_combine_chains.R
```

Repeat-mover posterior predictive check:

```
scripts/ModularFitting/Woodchester_V11_repeat_mover_ppc.R
```

Smoke workflow:

```
scripts/ModularFitting/run_V11_smoke.sh
```

Specification:

```
docs/V11_AGE_BADGER_RE_SPEC.md
```

### V11 50-badger smoke status

Completed successfully on 19 October 2026.

Population:

```
50 badgers
151 annual movement intervals
150 retained draws per chain
450 retained draws total
```

Key structural PPC:

| Metric | Posterior movement states | V11 replicated |
|---|---:|---:|
| Gini of high events | 0.851 | 0.857 |
| Maximum consecutive high run | 2.47 | 2.66 |
| Max high count in one badger | 2.59 | 3.16 |
| Animals with any high event | 9.09 | 8.98 |
| Animals with >=2 high events | 3.30 | 2.71 |
| Top-10% share of high events | 0.720 | 0.734 |
| Total high events | 13.1 | 13.4 |

Interpretation:

> V11 can reproduce the strong concentration of movement among repeat movers
> without placing the badger random effect on high→high persistence.

Do not use this 50-badger fit for final coefficient inference.

### V11 current active validation

The next gate is the **300-badger three-chain validation**.

It is intended to decide whether:

- `sigma_badger` is informed by the data;
- current-age effects are estimable;
- movement-scale mixing is acceptable after rho removal;
- repeat-mover PPC remains satisfactory.

If this passes, do not create further movement-only versions without a specific
failure that requires one.

---

# 15. Infection versus infectiousness: required next disease audit

This is a critical project distinction.

The existing latent infection trajectory uses multiple diagnostics to infer
probability of **infection acquisition/status**. That trajectory is suitable for
questions such as when an animal likely became infected.

It is not automatically a model of **infectiousness**.

## Available diagnostic evidence

The database includes long-format diagnostic information covering, among other
tests:

- culture;
- ELISA;
- IFN-gamma ELISA;
- DPP;
- Stat-Pak;
- Brock tests.

Culture records also include sample-type/result fields and other microbiological
metadata. Post-mortem records can include lesion and disease-severity
information.

## Required infectiousness phenotype audit

Before V13, create a dedicated audit that answers:

1. Which diagnostic results are defensible evidence of active shedding or
   transmission potential?
2. Does sample type matter, e.g. respiratory/faecal/urine/wound or other
   culture material where recorded?
3. Should a single positive culture define an infectious quarter, or should
   repeated/persistent positivity be distinguished?
4. How should negative cultures be interpreted given imperfect sensitivity?
5. Can infectiousness cease after a positive observation, or should the model
   allow intermittent shedding?
6. Is there enough temporal information to support three disease states:
   susceptible/uninfected, infected/non-infectious, infectious?
7. Would a simpler two-layer formulation be better:
   latent infection state + conditional shedding observation process?
8. How should PM lesion/culture evidence inform the final part of an animal's
   disease trajectory?
9. Which diagnostic eras/tests change through calendar time and therefore need
   explicit observation-model treatment?
10. How many animal-quarters contain direct evidence informative about
    infectiousness?

## Preferred modelling principle

Do not force a deterministic “infectious from first culture positive forever”
rule merely because it is easy to code.

If diagnostic support is adequate, infectiousness should be treated as a
time-varying latent process with observations of shedding/infectious evidence.

---

# 16. Dynamic social structure: membership, boundaries and transmission

This is a required bridge between movement and disease.

## Existing trustworthy historical information

The current database structure preserves:

```
capture-level recorded social group
capture-level canonical social-group ID
research.sett_social_group_history
research.social_group_supergroup_history
analysis.sett_social_group_observed
```

The project database rule is explicit:

> Do not overwrite a historical capture's recorded social group merely because
> its sett is associated with another social group in the current lookup.

This historical time dependence must carry through into spatial modelling.

## Existing static spatial object

Older models use:

```
data/spatial/V3_spatial_inputs_50m_2km.rds
data/spatial/CleanSocialGroups.gpkg
```

and derived `SG_mat` layers.

These are useful as spatial reference layers but must not automatically be
treated as historically correct boundaries for every year.

## Required social-history data product

Build a dedicated versioned annual table first:

```
badger_social_structure_by_year
```

Minimum grain:

```
year × sett × social-group relationship
```

with fields for:

- canonical sett ID;
- canonical social-group ID;
- recorded evidence count;
- first/last within-year observation;
- relationship source;
- validity interval if known;
- confidence/status;
- conflict flag;
- rename/split/merge notes.

This table should be derived from the cleaned database history and recorded
capture evidence, not a retrospective static lookup.

## Then decide whether yearly polygons are identifiable

Possible product:

```
social_group_boundaries_by_year
```

but this should only be created for years with defensible spatial support.

Potential construction approaches:

- historical mapped polygons where available;
- active-sett Voronoi/Thiessen territories as a transparent baseline;
- weighted Voronoi or kernel-based territory surfaces where sett use supports
  it;
- probabilistic boundaries rather than hard polygons in uncertain years.

A boundary product must retain uncertainty/quality metadata.

## Model roles

### V11

Do not alter latent high-mobility state using social groups. Continue using
observed social-group change as external validation.

### V12

Use time-appropriate group structure to classify the demographic interpretation
of movement:

- within-group relocation;
- cross-boundary dispersal;
- settlement into a new group;
- movement toward study-area edge;
- high movement followed by permanent disappearance.

This may help distinguish settlement versus probable emigration without making
group membership itself the latent movement state.

### V13

Dynamic social structure becomes more central.

Potential infectious-pressure quantities:

- number/prevalence of infectious groupmates;
- infectious-source pressure in the origin group;
- infectious-source pressure in destination group;
- change in infectious pressure following movement;
- infectious neighbours within metric radii;
- exposure across a shared or crossed boundary;
- time spent/likelihood mass outside the origin group territory.

This is likely the main mechanism through which movement can alter transmission
risk even if V7b found no simple total effect of high mobility on acquisition.

---

# 17. V12 design constraints carried forward from previous work

V12 should not begin as a blank-sheet CJS model. It should explicitly inherit
lessons from earlier versions.

## Carry forward

- modern V11 multi-location spatial observation likelihood;
- current chronological age;
- sex;
- individual mover propensity if supported at 300;
- local/high annual movement state;
- known PM/death information;
- explicit detection/non-detection process;
- full maximal movement population where support permits.

## Reconsider from V5 rather than copy

Earlier V5 made:

- cub/yearling entrants known local recruits;
- adult entrants latent immigrant/non-immigrant;
- first-capture edge proximity informative about immigrant probability.

These are useful hypotheses but should not automatically become V12 assumptions.

V12 should ask whether immigration can be identified more generally from:

- age at entry / chronological age;
- first observed location relative to study-area edge;
- first movement trajectory;
- subsequent settlement;
- observation history;
- social-group history.

Adult first capture is evidence about possible immigration, not proof.

## Key identifiability warning

Without independent information, an animal that disappears can represent:

- death;
- permanent emigration;
- temporary absence with non-detection;
- right censoring at study end.

Known deaths help, but for other disappearances the primary demographic
parameter should be described as **apparent survival/retention** until the model
or auxiliary data support a stronger separation.

---

# 18. V13 should add new biology, not merely a newer version of V7

The reason to fit V13 is not that V7 was “old”. It is because V13 will ask
different questions.

## Already answered by V7

```
infection acquired/status at t -> high movement later
high movement at t -> infection acquisition later
```

## Genuinely new V13 targets

```
infected non-infectious -> infectious/shedding
high movement -> progression to infectiousness
infectiousness -> altered movement
infectiousness -> survival/apparent emigration
immigrant status -> infectiousness on arrival/progression
infectious group exposure -> infection acquisition
boundary crossing -> change in infectious pressure
movement × infectious-pressure mediation
```

The V7 estimates remain evidence and should be reported alongside the newer
integrated model where scientifically relevant.

---

# 19. Project data sources relevant to future models

## Movement/capture

Current prepared objects include:

```
data/badger_encounters_useful.rds
data/badger_individuals.rds
data/WoodchesterSettLocations.csv
```

Modern spatial inputs include:

```
data/spatial/V3_spatial_inputs_50m_2km.rds
data/spatial/CleanSocialGroups.gpkg
```

## Infection

Database/model-derived objects include capture-level and quarterly latent
infection probabilities.

Current documented database views:

```
analysis.capture_history
analysis.diagnostic_results
analysis.capture_infection_probabilities
analysis.infection_probabilities
analysis.infection_quarterly_probabilities
analysis.sett_social_group_observed
```

The current imported quarterly infection model is:

```
infection_probabilities_2026_08_27
model variant: all_tests_inferred
```

## Historical social structure

Canonical database structures include:

```
research.setts
research.social_groups
research.supergroups
research.sett_social_group_history
research.social_group_supergroup_history
```

Rules/provenance:

```
docs/database/SETT_SOCIAL_GROUP_RULES.md
markdown/Woodchester_SQL_R_Analysis_and_Infection_Guide.md
```

---

# 20. Model-development checklist to use in every future chat

Before proposing a new analysis, check this roadmap and answer:

### A. Has this exact biological direction already been tested?

If yes, state the existing result first.

### B. What is genuinely new?

Examples:

- newer observation model alone is **not** necessarily enough reason to repeat;
- switching from infected to infectious **is** a genuinely new biological
  exposure;
- adding demography so disappearance becomes modelled **is** genuinely new;
- adding dynamic boundary crossing as a mechanism **is** genuinely new.

### C. Does the new model require a new data audit first?

Examples:

- infectiousness requires diagnostic phenotype audit;
- time-varying boundary effects require historical social-structure audit;
- immigration requires entry/death/detection support audit.

### D. What will make us stop?

Every development should have a predefined decision gate.

For V11:

> 300-badger validation passes → proceed to V12.

For V12:

> demographic states recover in simulation and real-data fit is identifiable →
> proceed to infectiousness.

For V13:

> infectiousness observation/state model is supportable from diagnostic data →
> integrate transmission questions.

---

# 21. Current status snapshot — 19 October 2026

**Frozen/reference:**

- V10B movement model and associated audits.

**Completed historical analyses that remain scientifically relevant:**

- V7a-M infection/status → movement;
- V7b-M movement → infection acquisition;
- V7b within-individual/time-stratified sensitivities;
- V7b spatial infection-pressure infrastructure.

**Current active model:**

- V11 age + persistent mover propensity.

**Completed V11 check:**

- 50-badger smoke test passed;
- repeat-mover PPC passed structurally.

**Current next computational task:**

- V11 300-badger validation.

**Parallel data-development priorities:**

- infectiousness phenotype/state audit;
- dynamic social-group history/boundary audit;
- verify whether same-group pressure full result exists outside version control.

**Next major model:**

- V12 entry + survival/retention + apparent emigration.

**Following major model:**

- V13 infectiousness × movement × demography × social exposure.

---


## V11 300-badger validation — 20 October 2026

The three-chain 300-badger validation completed successfully:

- 300 badgers;
- 951 annual movement intervals;
- 500 retained draws per chain;
- 1,500 retained draws total;
- 300 individual mover-effect parameters.

### Biological/structural result

The repeat-mover posterior predictive check passed strongly.

Posterior-state versus replicated means:

- Gini of high events: 0.824 vs 0.828;
- maximum consecutive high run: 2.74 vs 2.93;
- maximum high count in one badger: 3.39 vs 3.68;
- animals with any high event: 63.3 vs 62.9;
- animals with >=2 high events: 13.8 vs 14.2;
- top-10% share of high events: 0.585 vs 0.602;
- total high events: 80.2 vs 81.6.

Posterior-predictive tail probabilities were all approximately 0.51-0.79 rather
than near zero.

**Decision:** the V11 individual mover-propensity formulation is sufficient to
reproduce repeat-mover concentration. Do not add the badger random effect to
high->high persistence at this stage.

### Age / sex / individual heterogeneity

The 300-badger posterior suggests:

- strong positive male effect on local->high entry (`beta_RD_sex` median ~1.57);
- little evidence for a special age-2 increase in this subset (`beta_age_2`
  median ~0.14, wide interval);
- lower high-mobility entry among age 3-5 and especially age 6+ animals, with
  the age-6+ interval below zero in this run;
- persistent individual heterogeneity remains plausible
  (`sigma_badger` median ~0.36), but convergence is not yet sufficient for a
  final magnitude estimate.

These are provisional because some new/global parameters still have R-hat >1.1.

### Remaining computational issue

V11 did **not** eliminate the annual movement-scale mixing problem.

Worst global convergence:

- mean annual male local movement: R-hat ~2.52;
- mean annual female local movement: R-hat ~2.30;
- `beta_move_high`: R-hat ~2.27;
- `alpha_logmove`: R-hat ~2.16;
- `beta_move_sex`: R-hat ~1.42.

By contrast, `omega` itself was much better (R-hat ~1.05).

Movement-state disagreement also remains non-negligible:

- 77 / 951 intervals with max chain difference >0.25;
- 33 / 951 >0.50;
- 10 / 951 >0.80;
- median max chain difference ~0.014;
- 95th percentile ~0.363.

**Interpretation:** V11's biological additions are supported, but the annual
local/high movement-scale decomposition still needs one targeted computational
fix or longer/alternative sampling before V11 is frozen for V12. Do not create
new biological movement structure in response.

### Updated gate

The next step is **not** another new biological movement model.

Use the existing V11 model and target only the annual movement-scale ridge /
mixing problem. Once the annual movement scales and key movement-state
probabilities show acceptable cross-chain agreement, freeze V11 and proceed
directly to V12 entry/survival/apparent-emigration modelling.

---

# 22. Maintenance rule

This file is the canonical modelling-development record.

Whenever a model is fitted, rejected, frozen or superseded, update this file in
the same commit or immediately afterwards with:

- date;
- model/script;
- population;
- question;
- key diagnostic;
- principal estimate/conclusion;
- status: development / sensitivity / production / frozen / rejected;
- next decision.

Future ChatGPT sessions should read this file before recommending a new
Woodchester model or re-running a previous biological analysis.


---

# 23. Movement-transition covariate logic and anti-fishing rule

This section was added after the 300-badger V11 validation to make explicit
which covariates act on which parts of the movement process and why.

## The state process contains biologically different processes

The model distinguishes:

1. **Initial high-mobility state** — the first modelled annual movement interval;
2. **Local -> high transition (RD)** — initiation of a new high-mobility episode;
3. **High -> high transition (DD)** — persistence/continuation of an existing
   high-mobility episode;
4. **Movement magnitude conditional on state** — how far an animal moves once
   it is local or high mobility.

These are not assumed to require identical predictors.

## Current V11 covariate map

| Predictor | Initial high | Local -> high | High -> high | Movement magnitude |
|---|---:|---:|---:|---:|
| Sex | yes | yes | yes | yes |
| Chronological age | yes | yes | no | no |
| Individual badger effect | yes | yes | no | no |
| Previous high state | n/a | defines transition | defines transition | state sets scale |

Sex is therefore **not omitted from any movement-state transition in V11**.
Separate sex coefficients allow sex to influence initiation and persistence
differently.

Chronological age and the individual random effect were deliberately defined as
predictors of **high-mobility initiation propensity**. Their absence from DD was
not selected after looking at the V11 result. It was specified before fitting
V11 to avoid conflating:

- propensity to start a high-mobility episode; and
- persistence once an episode has started.

The repeat-mover PPC was pre-specified as the decision test for whether the
minimal individual-propensity formulation was sufficient. At both 50 and 300
badgers it reproduced repeat-mover concentration and consecutive runs well.
Therefore adding the badger effect to DD solely because it might improve fit
would now be contrary to the pre-specified rule.

## Remaining legitimate concern

The biological assumption that age and individual heterogeneity affect
initiation but not persistence is still an assumption. Good PPC does not prove
that their true DD effects are exactly zero.

Therefore one and only one pre-specified structural sensitivity is permitted
before V11 is frozen:

### Balanced-persistence sensitivity

Add chronological-age effects and the same individual badger effect to the DD
transition while leaving every other part of V11 unchanged.

This sensitivity is not a search over models. Its purpose is to test whether
the primary conclusions are materially dependent on the initiation-only
assumption.

### Decision rule defined before fitting

Compare the primary V11 and balanced-persistence sensitivity on:

- posterior annual high-state probabilities;
- robust local/high classifications;
- repeat-mover PPC;
- sex effect on local -> high initiation;
- age-effect conclusions;
- `sigma_badger`;
- annual local/high movement scales;
- chain agreement.

If the balanced sensitivity gives essentially the same biological conclusions,
retain the simpler initiation-only V11 because it has the clearer mechanistic
interpretation and fewer weakly identified effects.

If adding age/badger effects to DD materially changes state classification or
the central biological conclusions, do **not** select whichever model has the
nicer coefficient significance or R-hat. Treat that as evidence that transition
structure is not robustly identified, and either adopt the fuller model on
biological grounds or report the sensitivity explicitly.

## Anti-fishing rule

From this point forward:

- covariates are added because of a stated biological process, not because a
  coefficient in another model was significant;
- no term is removed simply because its posterior overlaps zero;
- no new transition-specific interaction is added merely to improve convergence;
- computational reparameterisation must preserve the same biological model;
- structural sensitivities must have their question and decision rule written
  down **before** fitting;
- movement-model development stops after the annual-scale mixing issue and this
  single transition-structure sensitivity are resolved.



## V11 annual-scale chain-mode diagnostic — 20 October 2026

The 300-badger chain-mode diagnostic showed that the remaining annual-scale
problem is not well described as simple short-chain noise.

Key findings:

- chain 2 occupied a higher local-movement / lower high:local-contrast region;
- chains 1 and 3 occupied a lower local-movement / higher contrast region;
- female local movement medians were approximately 13.8, 22.3 and 13.3 m;
- beta_move_high medians were approximately 4.01, 3.49 and 3.96;
- alpha_logmove and beta_move_high were strongly negatively correlated
  (approximately -0.61 to -0.90 across chains);
- local-scale lag-1 autocorrelation was commonly about 0.96-0.99 and within-chain
  ESS could be as low as 2-5;
- the first and second halves of the chains did not show convincing movement
  toward a common scale region;
- disagreement remained localized rather than wholesale: 33/951 annual
  intervals differed by >0.50 between chains, concentrated in a relatively
  small number of animals.

**Decision:** do not respond by changing movement biology or adding/removing
covariates. Test a centred annual-activity-centre computational
parameterisation of the exact same V11 posterior.

Committed centred check:

```
scripts/ModularFitting/Woodchester_V11_centered_annual_sampler_check.R
```

The check changes only annual computational coordinates/samplers:

- annual activity centres are stochastic directly;
- the same local/high Gaussian mixture is evaluated on annual displacement;
- whole-badger annual trajectories are updated in centred coordinates;
- movement-scale updates remain interwoven.

Sex, chronological age, badger random effect, transition equations, priors,
iid-quarter structure and observation likelihood remain unchanged.

If this centred check removes the chain separation, use the better computational
parameterisation and proceed to the pre-specified balanced-persistence
sensitivity. If the same modes persist, treat the annual local/high scale as a
real identifiability/multimodality issue rather than continuing sampler
engineering indefinitely.


## V11 centred parameterisation race — pre-specified 20 October 2026

Because spare CPU/RAM is available, four centred implementations of the same
V11 biological posterior will be run in parallel on the same 300-badger subset.

The comparison is computational, not biological.

Variants:

1. **Centred control**
   - current high-scale primitive;
   - scalar slice on high/local contrast.

2. **Centred joint-high**
   - same high-scale primitive;
   - joint AF_slice block on high log-scale + high/local contrast + sex movement
     effect.

3. **Centred joint-local**
   - original local log-scale is stochastic;
   - high log-scale is deterministic local + positive contrast;
   - joint AF_slice block on local log-scale + high/local contrast + sex
     movement effect.

4. **Centred mean-separation**
   - stochastic mean log-scale and positive log separation;
   - exact transform preserving the original
     alpha_logmove ~ N(log(20),1), beta_move_high ~ Exp(1) prior;
   - joint AF_slice block on mean log-scale + separation + sex movement effect.

All variants retain:

- identical V11 transition equations;
- identical sex and age effects;
- identical badger random effect;
- identical priors after exact coordinate transformation;
- identical iid quarterly model;
- identical centred annual trajectory likelihood;
- identical observation model;
- analytically collapsed HMM.

Selection rule:

> Choose computational coordinates on convergence/mixing/state-agreement
> grounds only. Do not use coefficient significance or biological effect size
> to choose a parameterisation.

Primary comparison metrics:

- maximum and median R-hat across pre-specified key parameters;
- minimum and median ESS;
- movement-scale autocorrelation / chain separation;
- smoothed-state cross-chain disagreement;
- agreement of pooled posterior summaries across parameterisations.

Scripts:

```
scripts/ModularFitting/run_V11_parameterisation_race.sh
scripts/ModularFitting/postprocess_V11_parameterisation_race.sh
scripts/ModularFitting/Woodchester_V11_compare_parameterisations.R
```

The parameterisation race must be resolved before fitting the separate
pre-specified balanced-persistence biological sensitivity.


## V11 full-population parameterisation race and observation-model simplification — 21 October 2026

The four centred parameterisations were inadvertently run on the full
movement-eligible population (n = 1,932) rather than the planned 300-badger
validation subset. This yielded a useful full-population computational race.

### Full-population race outcome

No centred parameterisation converged adequately.

Overall computational ranking was:

1. **joint-local**: max key R-hat 2.60, median key R-hat 1.67;
2. **joint-high**: max key R-hat 6.93, median key R-hat 1.85;
3. **mean-separation**: max key R-hat 7.91, median key R-hat 3.15;
4. **centred control**: max key R-hat 9.76, median key R-hat 4.17.

Joint-local substantially improved state agreement relative to the centred
control, but still failed the convergence gate. It remains the best
movement-scale coordinate system tested, not a converged production model.

The full-population chain-mode diagnostic also showed continued within-chain
drift and strong annual local/high scale ridges. The poor mixing was therefore
not eliminated by centring or scale reparameterisation alone.

### Reassessment of the quarterly latent-centre layer

The original multi-location observation architecture retained all captures by
using:

- one annual activity centre per badger-year;
- one latent quarterly activity centre per badger-year-quarter;
- capture locations around the quarterly centre.

The quarterly layer was introduced primarily to retain repeat captures rather
than because quarterly activity centres were themselves a central biological
target.

An explicit repeat-capture audit found:

- 13,105 captured badger-quarters;
- 1,116 (8.52%) with more than one capture record;
- only 467 (3.56%) with more than one distinct sett;
- 344/1,932 badgers ever observed at >1 sett within a quarter.

Thus 96.44% of captured badger-quarters provide no observed within-quarter
multi-sett information with which to identify a separate quarterly spatial
centre.

At the same time, the 467 multi-sett quarters are biologically valuable as
direct observations of short-timescale sett switching / connectivity and should
not be discarded.

### Pre-specified V11S simplification

Before further sampler engineering or the balanced-persistence sensitivity,
fit one biologically simpler observation hierarchy:

- retain one latent **annual activity centre** per badger-year;
- retain the same annual local/high collapsed HMM;
- retain the joint-local annual movement-scale parameterisation;
- retain quarterly trapping campaigns as observation occasions;
- retain season/period detection effects;
- retain every observed capture location, including repeated locations within a
  quarter;
- evaluate those locations directly around the annual activity centre;
- remove latent quarterly centres, omega, qinnov/qeps and quarterly-centre
  samplers.

This is a biological simplification, not merely a computational
reparameterisation.

Primary question:

> Can the annual local/high movement process be identified cleanly when the
> weakly informed quarterly latent-centre layer is removed, while preserving all
> capture observations?

The separate within-quarter multi-sett data should be treated as an observed
behavioural/connectivity layer for later analyses of rapid sett switching,
historical social-group crossing and disease-relevant contact.

Scripts:

```
scripts/ModularFitting/Woodchester_V11S_annualAC_direct_multiloc.R
scripts/ModularFitting/run_V11S_annualAC_direct_multiloc.sh
scripts/ModularFitting/Woodchester_within_quarter_multisett_audit.R
```

Do not fit the balanced-persistence H->H sensitivity until this simplified
observation architecture has passed its convergence/state-agreement gate.


## V11S interpretation, observed short-timescale movement, and current live plan — 21 October 2026

### Why V11S exists

V11S is a biological simplification motivated by the observation hierarchy,
not a return to an old model and not merely another computational
reparameterisation.

The key lineage is:

```
V10A/V10B
  annual AC + quarterly latent ACs + multiple capture locations
  V10B adds AR(1) persistence among quarterly centres
          |
          v
V11
  retains annual AC + quarterly latent ACs
  fixes quarterly AR(1) rho = 0 after weak support
  replaces adult-entry movement terms with chronological age effects
  adds persistent individual mover propensity
  retains local/high annual movement HMM
          |
          v
V11S
  retains V11 annual movement biology
  retains age + individual mover propensity
  retains local/high annual movement HMM
  retains all quarterly capture/non-capture occasions
  retains every observed capture location
  REMOVES latent quarterly ACs and omega entirely
```

Thus V11S is simpler spatially than V10B/V11 but biologically richer than
V10B in the annual movement process.

### What V10B was estimating

V10B had three spatial scales:

1. annual activity centre (A_{iy});
2. quarterly latent centre (Q_{iyq}) around the annual centre;
3. observed capture locations around the quarterly centre.

The quarterly deviation scale (omega) represented the extent to which a
badger's latent spatial centre changed among quarters within the same year.
V10B additionally estimated AR(1) persistence (ho), asking whether a
quarterly displacement from the annual centre persisted into the next quarter.

Annual centre-to-centre displacement was separately classified by a two-state
local/high movement HMM.

### What V11 added

V11 retained the annual/quarterly spatial hierarchy but changed the annual
movement biology:

- quarterly AR(1) persistence was removed ((ho=0)); quarterly deviations
  became iid around the annual centre;
- chronological age at the start of each annual movement interval replaced the
  cruder adult-entry formulation;
- a persistent badger-level random effect was added to initial high-mobility
  probability and local->high initiation probability;
- H->H persistence remained sex-specific only in the primary model pending the
  pre-specified balanced-persistence sensitivity.

The full-population parameterisation race demonstrated that centring and
movement-scale reparameterisation improved computation but did not resolve the
underlying identification problem. Joint-local was best but still failed the
convergence gate.

### Why the quarterly latent-centre layer was reconsidered

The quarterly-centre layer was originally introduced mainly so that multiple
capture locations in the same quarter could all be retained. It was not itself
a primary biological target.

Two audits distinguish the complete repeat-capture information from the subset
that can support explicit distance/timing calculations.

Complete captured-quarter audit:

- 13,105 captured badger-quarters;
- 1,116 (8.52%) with >1 capture record;
- 467 (3.56%) with >1 distinct sett;
- 344/1,932 badgers ever observed at >1 sett within a quarter.

Distance/timing-resolved audit (requires usable capture date and mapped sett
coordinates):

- 12,907 captured badger-quarters;
- 443 (3.43%) multi-sett quarters;
- 328 badgers represented;
- 471 consecutive observed sett-change transitions.

The difference between 467 and 443 multi-sett quarters is data resolution, not
a contradiction. The 467 cases are the complete behavioural set; 443 have
sufficient date/coordinate information for the current distance/timing audit.

For the 471 resolved sett-change transitions:

- time between captures: minimum 5 d, Q1 20 d, median 38 d, Q3 56 d,
  90th percentile 64 d, 95th percentile 70 d, maximum 84 d;
- straight-line sett-to-sett distance: minimum 32.6 m, Q1 162 m,
  median 281 m, Q3 406 m, 90th percentile 602 m, 95th percentile 817 m,
  maximum 3,139 m.

These observations are sparse at the quarter level but biologically valuable.
They should not be discarded or averaged away.

### V11S observation model

V11S retains one latent annual activity centre per badger-year and treats each
quarter as an observation occasion rather than a separate latent biological
location.

For badger (i), year (y), quarter (q), and observed capture location
(r), the conceptual structure is:

[
A_{iy}
longrightarrow
{H_{iyq1}, H_{iyq2}, ldots}
]

rather than:

[
A_{iy}
longrightarrow
Q_{iyq}
longrightarrow
{H_{iyq1}, H_{iyq2}, ldots}.
]

The quarterly campaign still contributes one capture/non-capture term. If the
animal was captured multiple times, every observed detector location
contributes conditionally on the observed number of captures.

The spatial kernel is therefore now interpreted as the spread of observed
within-year trapping locations around the annual centre. It should not be
interpreted as directly equivalent to the old quarterly-centre detection scale
without qualification.

### Annual local/high movement model retained in V11S

Let the annual activity centre be

[
A_{iy}=(A^x_{iy},A^y_{iy}).
]

Annual displacement is

[
Delta A_{iy}=A_{iy}-A_{i,y-1}.
]

Conditional on latent movement state (z_{iy}),

[
Delta A_{iy}mid z_{iy}=0
sim N_2(0,sigma^2_{L,i}I)
]

for local movement and

[
Delta A_{iy}mid z_{iy}=1
sim N_2(0,sigma^2_{H,i}I)
]

for high mobility, with (sigma_H>sigma_L).

Sex affects movement scale. The state-transition model distinguishes:

- initial high-mobility probability;
- local->high initiation;
- high->high persistence.

Current age and the persistent badger random effect enter initial/high
initiation in the primary V11/V11S formulation; H->H currently retains sex
only.

The HMM states are collapsed during MCMC and annual local/high probabilities
are recovered afterwards by forward-backward smoothing / FFBS.

### What V11S can tell us biologically if it passes convergence

V11S targets long-timescale individual movement.

It can estimate:

- each badger's latent annual spatial centre;
- annual displacement between successive centres;
- probability that each annual interval represents local vs high mobility;
- typical local and high movement scales;
- male/female differences in movement scale;
- sex differences in initiation and persistence of high movement;
- age effects on initiating high movement;
- persistent between-individual heterogeneity in propensity to initiate high
  movement;
- repeat high-mobility episodes / persistent movers;
- posterior annual trajectories that can subsequently be overlaid with
  historical social-group membership/boundaries;
- movement histories that can feed the future entry/emigration/survival and
  infectiousness models.

V11S does **not** directly estimate:

- a true home-range centre for each quarter;
- continuous movement paths within a year;
- exact time of movement between observed captures;
- social-group crossing until historical group information is joined;
- immigration/emigration as demographic states;
- infectiousness or transmission.

Those remain later layers.

### Observed multi-sett movement is a complementary analysis, not a competing model

The within-quarter multi-sett dataset is direct empirical movement evidence.

For a pair of consecutive captures at setts (a) and (b),

[
d_{ab}=
sqrt{(x_b-x_a)^2+(y_b-y_a)^2}.
]

The observed time window is

[
Delta t=t_b-t_a.
]

This means only that the animal changed from sett (a) to sett (b) sometime
within the interval (Delta t); it does not imply that the journey itself took
(Delta t), nor that (d_{ab}) is the route length.

This observed layer can directly quantify:

- rapid sett switching;
- observed short-timescale displacement;
- individuals repeatedly using multiple setts;
- eventual same-social-group vs cross-social-group movements;
- rapid inter-group bridge events;
- overlap between direct short-timescale bridge behaviour and latent annual
  high-mobility classifications;
- later, whether infectious/shedding animals generate unusually important
  inter-group connections.

This layer is especially relevant to transmission because a modest Euclidean
movement that crosses a social-group boundary may be more epidemiologically
important than a longer movement remaining within one group.

### Relationship between the two current spatial products

The two products answer different questions and should be retained together.

**V11S latent annual model**

> What is the animal's underlying year-to-year movement history, including
> movement when it is imperfectly observed?

Strength: reconstructs latent annual behaviour across the entire capture
history and all eligible animals.

Weakness: inference is model-based and annual; it does not provide exact
within-year paths.

**Observed multi-sett movement layer**

> What rapid movements between known setts did we actually witness?

Strength: direct evidence with known capture dates and sett coordinates.

Weakness: opportunistic and detection-limited; absence of an observed move is
not evidence that no move occurred.

They should eventually be linked rather than forced into one latent hierarchy.

### Current live validation plan

The 50-badger V11S smoke test was reported complete on 21 October 2026.
The 300-badger V11S three-chain validation was subsequently reported complete
the same day and is awaiting the pre-specified convergence/state-agreement
diagnostics. A compact summary script is now available at:

```
scripts/ModularFitting/Woodchester_V11S_three_chain_summary.R
```


Its purpose is code/build/state-recovery validation rather than biological
inference; no biological conclusion should be taken from a 50-badger smoke
sample.

The next runs may proceed concurrently because their output/session namespaces
are independent:

- 300-badger validation, 3 chains: direct comparison with previous 300-badger
  V11 behaviour;
- 1,932-badger full-population validation, 3 chains: production-scale test of
  whether removal of the quarterly latent layer resolves the full-data
  identification problem.

Use the existing joint-local annual movement-scale coordinates for V11S because
they were the best computational representation in the full-population V11
race. Do not choose or reject V11S because of coefficient significance.

### V11S decision gate

Evaluate V11S on:

- cross-chain R-hat and ESS;
- within-chain movement-scale autocorrelation/drift;
- agreement of local/high annual movement scales;
- cross-chain annual state-probability agreement;
- repeat-mover PPC;
- stability of sex, age and badger-propensity conclusions.

If V11S converges substantially better while retaining sensible posterior
predictive behaviour, prefer the simpler annual-AC observation architecture.

If V11S remains seriously non-converged, the quarterly latent-centre layer has
been ruled out as the main explanation and attention should move to
identifiability of the annual local/high mixture itself rather than restoring
quarterly complexity.

Only after the observation architecture is frozen should the pre-specified
balanced H->H persistence sensitivity be fitted, followed by V12
entry/survival/emigration and then V13 infectiousness/transmission.

### Immediate observed-movement extension

Next, join the complete multi-sett-quarter dataset to the versioned historical
sett/social-group history. Preserve uncertainty/conflict rather than assigning
modern groups retrospectively.

For each observed sett transition record:

- origin sett and destination sett;
- capture dates and elapsed days;
- straight-line distance;
- historical origin and destination social group;
- same-group / cross-group / unresolved classification;
- split/merge/conflict flags where relevant.

This creates a directly observed historical connectivity dataset that can later
be related to annual movement state, immigration/emigration and infectiousness.


## Behavioural movement programme and literature-backed social-group assignment — 21 October 2026

The observed movement programme is now pre-specified separately from V11S.

### Historical Woodchester social-group method

The literature confirms that Woodchester social structure was handled in two
stages:

1. **Territory delineation.** Social-group territories were mapped annually in
   spring using bait marking at main setts. Distinctive indigestible markers
   recovered from latrines, together with boundary-run field observations, were
   used to map neighbouring group boundaries. Territory geography is therefore
   historical and time-varying.

2. **Annual individual residency.** Vicente et al. (2007) assigned each badger
   to one annual resident group using a five-step capture-history hierarchy:
   current-year modal capture group; adjacent-year allocations; three-year
   capture mode; nearest before/after-year capture among relevant candidates;
   first relevant capture if still unresolved. Over 96% were assigned by the
   current-year modal group alone.

Project consequence:

> Do not equate every capture group with residency. A capture outside the
> annual resident group can be an excursion/bridge event and must remain
> observable as such.

The literature-backed rules are now recorded in:

```
docs/database/SETT_SOCIAL_GROUP_RULES.md
```

and the reproducible derived assignment script is:

```
scripts/behaviour/Woodchester_assign_annual_resident_social_group.R
```

### Relation to previous Woodchester movement analyses

Rogers et al. (1998) used capture histories across social groups and described
non-movers, occasional movers, permanent movers and frequent movers. Their
1763-badger, 18-year analysis found that nearly half of classifiable animals had
moved at least once; among movers, occasional movement predominated, permanent
movement was less common, and frequent movement was rare. Males were much less
likely than females to be non-movers.

Vicente et al. (2007) subsequently defined annual movement from resident-group
change and also built a group movement index from capture-to-capture changes in
social group. This provides direct precedent for separating annual residency
change from more transient capture-level movement.

These historical classifications are biological reference points rather than
hard states imposed on V11S.

### Pre-specified observed-behaviour analyses

The first behavioural script is:

```
scripts/behaviour/Woodchester_observed_movement_behaviour.R
```

It deliberately excludes disease and V11S state until the basic behaviour is
described.

#### B1. Sett-switching propensity

Analysis population: badger-quarters with at least two observed captures.

Response:

[
Y_{iqy}=1
]

if the repeated captures use more than one sett, otherwise 0.

Primary explanatory structure:

- sex;
- current age class;
- quarter/season;
- number of captures in the quarter;
- elapsed time between first and last capture;
- year effect;
- persistent badger random effect.

This conditions on the opportunity to observe switching rather than comparing
all captured quarters indiscriminately.

Primary biological question:

> Are some badgers persistently more likely to use multiple setts, after
> accounting for how often and over what time window they were observed?

#### B2. Magnitude of directly observed sett-to-sett movement

Analysis population: consecutive captures at different mapped setts within the
same quarter.

Response:

[
log(d_{ab})
]

where (d_{ab}) is straight-line sett-to-sett distance.

Predictors include sex, age, season and elapsed capture interval, with year and
individual effects.

Elapsed days is an observation-window adjustment, not an estimate of movement
speed.

#### B3. Direct social-group bridging

Where contemporaneous capture-level social-group identities are resolved,
classify a transition as same-group or cross-group.

Model cross-group probability as a function of:

- sex;
- age;
- season;
- elapsed capture interval;
- sett-to-sett distance;
- year;
- individual identity.

Distance is included so sex/age/season effects are interpreted beyond the
obvious geometry that farther sett pairs are more likely to be in different
territories.

Also retain each movement's relationship to annual residency:

- same-group sett switch;
- resident -> other group;
- other group -> resident;
- nonresident group -> another nonresident group;
- unresolved.

#### B4. Link observed bridging to V11S only after V11S is accepted

After the full V11S movement fit passes convergence:

- test whether badger-years with high posterior annual mobility also contain
  more observed short-timescale bridge events;
- test whether observed bridge behaviour during year y predicts high movement
  / annual relocation from y to y+1;
- estimate overlap between persistent V11S mover propensity and persistent
  observed bridge propensity.

Because V11S and observed movement share capture data, these are consistency
and biological-linkage analyses, not independent validation.

#### B5. Disease follows behaviour, not vice versa

Do not immediately add infection status to B1-B4.

After the behavioural architecture is understood, the disease extension should
focus on infectiousness/shedding and transmission opportunity, especially
whether infectious badgers directly bridge social groups and whether exposure
after bridge events predicts subsequent acquisition.

This is a distinct question from the earlier generic infected-to-movement
analyses and therefore does not duplicate V7a-M/V7b-M.


### Behavioural time-scale expansion — adjacent quarter-to-quarter transitions

The observed behavioural programme must not be restricted to repeat captures
within the same quarter. The capture history supports three nested direct/latent
movement scales:

1. **Within-quarter observed movement**
   - consecutive captures during the same trapping campaign;
   - strongest evidence for rapid excursions / short-timescale sett switching.

2. **Adjacent quarter-to-quarter observed movement**
   - last observed capture in quarter q to first observed capture in q+1;
   - includes Q4 -> Q1 of the next calendar year;
   - retains actual endpoints and dates rather than inventing a quarterly
     activity-centre estimate;
   - can quantify sett change, social-group change and displacement between
     successive observed trapping campaigns.

3. **Annual latent/residency movement**
   - annual resident social-group changes from the Vicente-style hierarchy;
   - annual latent activity-centre local/high movement from V11S.

Longer gaps (>=2 trapping quarters between observed captures) should be retained
as descriptive capture-to-capture transitions but not pooled into the primary
adjacent-quarter analysis because the movement timing becomes increasingly
uncertain.

The behavioural script now constructs the complete ordered capture-to-capture
transition history and explicitly labels:

- within-quarter;
- adjacent-quarter;
- longer observational gap.

Primary adjacent-quarter outcomes are:

[
P(	ext{different sett at next observed quarter})
]

and, where capture-level group identities are available,

[
P(	ext{different social group at next observed quarter}).
]

Sex, current age, destination season, elapsed days, year and persistent
individual identity are included in the pre-specified models.

This extension is intentionally based on direct observed endpoints. It does not
restore the discarded latent quarterly activity-centre layer.

Updated script:

```
scripts/behaviour/Woodchester_observed_movement_behaviour.R
```


## V11S 300-badger validation result — 21 October 2026

The three-chain 300-badger V11S validation completed successfully, with 750
retained draws per chain after burn-in/thinning.

### Convergence result

V11S did **not** pass the convergence gate.

Key scorecard:

- 17 pre-specified key parameters;
- max R-hat = 2.64;
- median R-hat = 1.42;
- minimum ESS = 18.9;
- 16/17 key parameters had R-hat > 1.05;
- 14/17 had R-hat > 1.10.

The worst-converged parameter remained the female local annual movement scale
(R-hat 2.64, ESS 18.9). Persistent mover heterogeneity also showed strong chain
separation (sigma_badger R-hat 2.08).

### Movement-scale chain locations

Female local annual movement medians:

- chain 1: 4.75 m;
- chain 2: 11.0 m;
- chain 3: 6.44 m.

Male local annual movement medians:

- chain 1: 4.81 m;
- chain 2: 8.13 m;
- chain 3: 5.14 m.

Female high-mobility medians:

- chain 1: 632 m;
- chain 2: 833 m;
- chain 3: 874 m.

Male high-mobility medians:

- chain 1: 581 m;
- chain 2: 630 m;
- chain 3: 684 m.

The annual local/high scale ridge remains strong. Within-chain ACF1 is
approximately 0.95-0.99 for the local movement scale in all three chains, with
very low within-chain ESS.

### Persistent mover heterogeneity

sigma_badger chain medians were strongly separated:

- chain 1: 0.894;
- chain 2: 0.231;
- chain 3: 0.217.

This indicates that at least one chain is allocating substantially more
variation to persistent individual propensity than the other two. This tradeoff
must be diagnosed explicitly before interpreting the biological random effect.

### State agreement

There were 951 annual movement intervals.

Cross-chain high-state probability range:

- >0.25 for 96 intervals (10.1%);
- >0.50 for 60 intervals;
- >0.80 for 35 intervals;
- median range ~0.0002;
- 95th percentile range 0.611;
- maximum ~1.

Thus most intervals are nearly identical across chains, but a localized subset
has severe state ambiguity. The animals contributing most include 062W, N020,
010Y, E068, W021, M059, K052 and U057.

### Comparison with the previous 300-badger V11 model

Removing latent quarterly centres did not remove the annual-scale chain-mode
problem.

Compared with the previous 300-badger V11 result, V11S shifts the inferred local
movement scale lower (roughly 5-11 m across chains instead of roughly 10-22 m),
but does not improve cross-chain identification sufficiently.

State disagreement is not improved: the previous V11 300-badger diagnostic had
76/951 intervals with chain differences >0.25 and 33 >0.50, whereas V11S has
96/951 >0.25 and 60 >0.50.

Therefore:

> The quarterly latent-centre layer was not the principal cause of the annual
> local/high movement identification problem.

This is scientifically useful even though V11S did not converge. It rules out a
major suspected source of confounding.

### Current interpretation

The remaining problem appears to lie in the annual movement model itself,
particularly allocation among:

- the very small local annual movement scale;
- the high-mobility movement scale / local-high separation;
- the probability of entering the high state;
- persistent badger-level propensity to initiate high movement.

The model can classify most annual intervals consistently, but a minority of
ambiguous animals/intervals can be explained by markedly different combinations
of movement scale and mover propensity.

Do not interpret sex/age/persistent-mover coefficients biologically from this
300-badger fit yet.

Do not restore the quarterly-centre layer merely because V11S failed to solve
convergence; the repeat-capture audit still provides little biological
justification for that complexity.

### Next diagnostic before further model alteration

Before changing the biological model, quantify posterior correlations and
within-chain drift involving:

- sigma_badger;
- alpha_RD;
- beta_RD_sex;
- alpha_disp_init;
- age effects;
- local movement scale;
- high movement scale / separation.

The purpose is to determine whether the second major ridge is between
**movement-state assignment** and **persistent individual propensity**, rather
than only between the two Gaussian movement scales.

The full 1,932-badger V11S run remains especially informative: if the same
tradeoff is present at full population scale, the next model-development step
should target annual-state identifiability rather than additional sampling.


## Observed behavioural movement results and V11S state-process geometry — 21 October 2026

### Annual resident social-group assignment validation

The literature-backed Vicente-style annual resident social-group reconstruction
resolved all 7,307 captured badger-years.

Assignment criteria:

- criterion 1 (unique modal capture group in focal year): 6,992 = 95.69%;
- criterion 2 (adjacent-year residency resolves focal-year tie): 269 = 3.68%;
- criterion 3 (current + adjacent-year capture mode): 20 = 0.27%;
- criterion 4 (nearest relevant before/after-year capture): 21 = 0.29%;
- criterion 5 (first relevant capture): 5 = 0.07%.

The criterion-1 proportion is extremely close to the published Woodchester
benchmark (>96%), supporting the reconstructed residency hierarchy while still
requiring explicit retention of criteria 2-5 as lower-certainty assignments.

### Complete observed transition history

The behavioural pipeline yielded 12,356 consecutive usable capture transitions:

- 1,183 within-quarter;
- 6,059 adjacent-quarter;
- 5,114 longer-gap.

Observed sett-change proportions were:

- within-quarter: 496/1,183 = 41.9%;
- adjacent-quarter: 1,994/6,059 = 32.9%;
- longer-gap: 1,957/5,114 = 38.3%.

Observed capture-level social-group change proportions were:

- within-quarter: 270/1,183 = 22.8%;
- adjacent-quarter: 606/6,059 = 10.0%;
- longer-gap: 825/5,114 = 16.1%.

These raw proportions should **not** be interpreted as causal time-scale effects
because observation opportunity differs strongly among the three subsets.
Within-quarter transitions exist only for repeatedly captured animals and are
therefore selected for high observation intensity.

### B1: within-quarter sett switching

Among 1,116 repeat-captured badger-quarters, 467 (41.85%) involved >1 sett.

After accounting for capture count, elapsed observation window, year and
individual identity:

- no clear male/female difference in switch probability;
- age 2, 3-5 and 6+ all showed higher switching probability than age 0-1;
- three captures rather than two strongly increased the chance of observing a
  switch, as expected from greater observation opportunity;
- elapsed observation window was strongly associated with switch detection;
- badger identity showed substantial persistent heterogeneity
  (random-effect SD approximately 0.73 on the logit scale);
- year also contributed detectable heterogeneity.

The persistent individual effect is biologically important: some badgers appear
to use multiple setts more often than expected from observation opportunity
alone.

### B2: adjacent-quarter sett switching

Among 6,059 adjacent-quarter observed transitions:

- 1,994 = 32.9% changed sett;
- no clear overall male/female effect on whether sett changed;
- age 2 and 3-5 had roughly twice the odds of sett change relative to age 0-1;
- age 6+ also showed elevated, but smaller, sett-switching probability;
- destination quarter 3 showed a modest increase;
- elapsed time, year and badger identity all mattered;
- persistent badger heterogeneity was large (random-effect SD approximately
  1.20 on the logit scale).

This strengthens the hypothesis of repeatable individual movement phenotype.

### Adjacent-quarter social-group crossing

Among the 6,059 adjacent-quarter transitions, 606 (10.0%) changed recorded
social group.

Before conditioning on geometric distance:

- males had higher cross-group odds than females;
- age 2 and age 3-5 had much higher cross-group odds than age 0-1;
- age 6+ was also elevated;
- no clear seasonal contrast remained;
- badger identity and year both showed strong heterogeneity.

Because the first adjacent-quarter crossing model does not condition on
sett-to-sett distance, these sex/age effects combine behavioural boundary
crossing with differences in movement magnitude. A pre-specified secondary
model has now been added that includes log1p sett-to-sett distance, allowing us
to distinguish "moves farther" from "crosses boundaries more readily at a given
distance".

### B3: observed movement magnitude

Across 4,139 different-sett consecutive capture transitions:

- within-quarter median displacement: 281 m (IQR 162-406 m; 95th 817 m);
- adjacent-quarter median displacement: 191 m (IQR 127-335 m; 95th 671 m);
- longer-gap median displacement: 264 m (IQR 168-402 m; 95th 874 m).

After accounting for elapsed days, year, individual identity and temporal scale:

- male observed sett-to-sett moves were approximately exp(0.180) = 1.20 times
  the distance of female moves on average;
- age-2 moves were approximately 14% longer than age 0-1;
- age 3-5 moves were approximately 13% longer than age 0-1;
- age 6+ was not clearly different;
- temporal-scale indicators were weak once elapsed days and other covariates
  were accounted for;
- individual identity strongly affected movement magnitude.

Thus males do not appear much more likely to switch sett per se, but when a
different-sett movement is observed they tend to move farther.

### B4 social-group model correction

The first B4 run printed 12,356 group-resolved transitions but fitted the
distance-adjusted model to only 4,139 transitions because the implementation
used log(distance), making zero-distance same-sett transitions undefined and
dropping them.

This is a conditioning error for the intended all-transition cross-group model.

The behavioural script has been corrected to use:

[
log(1+d)
]

so zero-distance transitions remain valid. The corrected B4 model must be
rerun before interpreting its sex/age/temporal-scale coefficients.

Commit implementing the correction:

```
1191599ae0c3511d240a660dd544c62f13d7e21a
```

### V11S annual state-process / persistent-mover geometry

The extended 300-badger diagnostic confirms a second important posterior
trade-off beyond the local/high movement-scale ridge.

In chain 1:

- cor(female high movement scale, alpha_RD) ~ -0.80;
- cor(alpha_logmove_high, alpha_RD) ~ -0.80;
- cor(beta_move_high, alpha_RD) ~ -0.73;
- cor(sigma_badger, alpha_RD) ~ -0.64;
- cor(sigma_badger, alpha_disp_init) ~ -0.57.

Chain 1 also drifted during the run toward:

- larger sigma_badger (mean ~0.74 -> 1.08);
- lower alpha_RD (~ -2.22 -> -3.25);
- larger high-movement scale (~469 -> 772 m).

This is a coherent compensatory direction:

> stronger persistent between-badger heterogeneity can be traded against a
> lower baseline local->high transition rate and a broader high-movement scale.

The sigma_badger chain medians remain strongly separated:

- chain 1: ~0.894;
- chain 2: ~0.231;
- chain 3: ~0.217.

Therefore the persistent-mover effect is not yet separately identified from the
annual state-transition/movement-scale process in the 300-badger V11S fit.

Do not interpret sigma_badger, age transition effects, or baseline RD/DD
parameters biologically until the full-population run is diagnosed.

### Behavioural implication for the annual model

The observed behavioural analyses now provide a direct, independently
interpretable measure of persistent movement phenotype at capture timescales.
This may ultimately reduce the need for the annual latent model to carry all
"persistent mover" biology through a weakly identified random effect.

However, because the observed behavioural data and V11S share underlying
captures, this should be used as biological triangulation / complementary
description, not independent validation.

Wait for the 1,932-badger V11S result before deciding whether to:

- retain the annual persistent mover random effect;
- remove it in a pre-specified sensitivity;
- regularize it more strongly;
- or redefine the local state as effectively stable annual residency rather
  than trying to estimate a 5-10 m continuous annual movement scale.


## SOCG provenance audit before boundary-crossing interpretation — 21 October 2026

The current behavioural pipeline uses the legacy capture-level SOCG field as
historically recorded social-group information. Before interpreting a change in
SOCG as a physical territorial boundary crossing, the meaning of SOCG must be
verified empirically.

Current terminology until that audit is complete:

> "capture-level recorded SOCG change"

rather than:

> "confirmed bait-marked territory-boundary crossing".

A dedicated audit script has been added:

```
scripts/behaviour/Woodchester_SOCG_provenance_audit.R
```

The audit tests whether SOCG behaves primarily like:

1. the contemporaneous social group associated with the capture sett/location;
   or
2. the individual's annual resident social-group membership.

Key tests are:

- SOCG purity within sett-year;
- SOCG purity within sett-quarter;
- frequency of SOCG changes while sett remains unchanged;
- frequency of SOCG changes when sett changes;
- historical changes in dominant sett->SOCG relationship;
- a leave-focal-badger-out "visitor test".

For the visitor test, the dominant SOCG of a sett-year is defined using
**other badgers only**. For a focal badger whose reconstructed annual resident
group differs from that independently estimated sett-year group, ask whether
the focal capture SOCG follows:

- the other-badger sett-year group, supporting SOCG as capture-location group;
- or the focal annual resident group, supporting SOCG as individual membership.

The annual resident-group product is itself derived from SOCG and is therefore
not independent evidence; the other-badger visitor test is designed to reduce
that circularity.

If SOCG behaves consistently as a contemporaneous capture-location group, it can
be used to reconstruct inter-group movement even where annual bait-marking
polygons are unavailable, while retaining an evidence-source flag.

If SOCG instead behaves like resident membership, or behaves inconsistently
through time, the group-crossing analyses must be rebuilt from historical
sett-year group relationships and/or original bait-marking territory products.

No disease interpretation should be attached to recorded SOCG changes until
this provenance gate is passed.


## SOCG provenance gate passed — 21 October 2026

The SOCG provenance audit strongly supports the legacy capture-level `socg`
field as the contemporaneous social group associated with capture location,
rather than annual individual residency.

Evidence:

- 1,363 eligible sett-years: 99.19% >=90% pure SOCG and 98.97% 100% pure;
- 2,127 eligible sett-quarters: 99.81% >=90% pure;
- only 1/4,563 (0.02%) same-sett consecutive capture transitions changed SOCG;
- 915/2,536 (36.08%) different-sett transitions changed SOCG;
- leave-one-badger-out visitor test: 562/571 (98.42%) focal SOCG values followed
  the OTHER-badger sett-year group, while only 7/571 (1.23%) followed the
  focal badger's annual resident group;
- 15 high-purity sett-to-SOCG changes across successive observed years confirm
  historical group structure changed through time.

Conclusion:

> The behavioural pipeline may now interpret capture-to-capture SOCG change as
> observed inter-group movement.

Do not overstate this as reconstruction of the exact bait-marked boundary-crossing
path. The annual polygons are still needed if the exact boundary geometry,
territory area or boundary location is itself the analysis target.

This provenance result strengthens the distinction between:

1. **capture-level social group** = where the badger was observed in social
   space;
2. **annual resident group** = where the badger primarily belonged that year;
3. **inter-group excursion** = capture SOCG differs from annual resident group;
4. **annual resident-group change** = longer-term relocation/dispersal signal.

The next behavioural analyses should explicitly exploit this distinction,
especially temporary excursions (resident A -> group B -> resident A) versus
persistent group change and later annual relocation.


### Inter-group excursion analysis unlocked by SOCG provenance result

With the SOCG provenance gate passed, the next behavioural analysis can now
distinguish capture location in social space from annual residency.

A new script is available:

```
scripts/behaviour/Woodchester_intergroup_excursion_analysis.R
```

It defines a capture as extra-group when:

[
SOCG_{m capture} 
e ResidentGroup_{i,y}.
]

It then addresses three pre-specified questions.

1. **Quarter-level extra-group use**
   - probability that a badger is observed outside its annual resident group;
   - predictors: sex, current age, season, capture opportunity, year and
     persistent badger identity.

2. **Extra-group use as a precursor to relocation**
   - among badger-years with a resident-group assignment in year y and y+1,
     test whether any extra-group use in year y predicts:
     [
     ResidentGroup_{i,y+1} 
e ResidentGroup_{i,y}.
     ]
   - adjust for capture opportunity, sex, age, year and individual identity.
   - this is behavioural linkage, not independent validation, because annual
     residency is itself derived from capture SOCG history.

3. **Directly observed temporary excursions**
   - identify observed sequences where a capture in the annual resident group
     is followed by a capture in another group during the same year;
   - where another same-year capture follows, classify whether the badger
     returns immediately to its resident group or remains outside it.

This provides an explicit distinction among:

- resident use;
- temporary extra-group excursion;
- repeated extra-group / bridge behaviour;
- annual resident-group change.

These observed behavioural states can later be compared with V11S high-mobility
probabilities and, subsequently, infectiousness/shedding state.


## Inter-group excursion / residency-change analysis — 21 October 2026

The first complete E1-E3A run has now finished successfully.

### E1: quarter-level extra-group use

Among 13,206 observed badger-quarters:

- 750 contained at least one capture outside the reconstructed annual resident
  social group;
- quarter-level extra-group-use proportion = 5.68%.

Across 14,409 usable captures:

- 772 were extra-group captures;
- capture-level extra-group proportion = 5.36%.

Adjusted E1 results from the earlier completed fit indicated:

- males had higher odds of observed extra-group use than females
  (logit coefficient ~0.406);
- age 2 (~0.888), age 3-5 (~0.793), age 6+ (~0.366), and unknown age (~0.465)
  were all higher than age 0-1;
- quarters 2-4 had lower extra-group detection than quarter 1;
- greater capture opportunity strongly increased the probability of observing
  extra-group use;
- substantial year heterogeneity remained (RE SD ~0.535);
- substantial persistent individual heterogeneity remained (badger RE SD
  ~0.690).

Interpret E1 as **extra-group use relative to reconstructed annual modal
residency**, not as an independently observed latent behavioural state. Annual
residency and extra-group use are derived from the same capture SOCG history.

### E2: extra-group use and next-year resident-group change

There were 4,677 consecutive resident badger-years with resident groups
available in both year y and y+1.

Overall:

- 493/4,677 = 10.54% changed resident group the following year.

By observed extra-group use in year y:

- no extra-group use: 368/4,204 = 8.75% changed resident group next year;
- >=1 extra-group capture: 125/473 = 26.4% changed resident group next year.

The adjusted BAM was:

```
resident_change_next ~
    any_extra_group +
    sex +
    age_class +
    s(capture_effort, k = 5) +
    s(year_factor, bs = "re") +
    s(tattoo_factor, bs = "re")
```

Main adjusted coefficients:

- extra-group use: beta = 1.4159, SE = 0.1421, z = 9.97,
  p < 2e-16;
- male sex: beta = 0.8653, SE = 0.1062, z = 8.15,
  p = 3.78e-16;
- age 2, age 3-5 and age 6+ were not clearly different from age 0-1 in this
  model;
- unknown age was positive (beta = 0.443, p = 0.020).

For extra-group use, exp(1.4159) = approximately **4.12**, with an approximate
Wald 95% odds-ratio interval of **3.12 to 5.44**.

The model also retained detectable variation with capture effort, year and
individual identity. Adjusted R-squared was ~0.104 and deviance explained was
16.2%.

**Interpretation at this stage:**

> Badger-years containing observed use of another social group were strongly
> associated with a different reconstructed resident group in the following
> year.

Do not yet describe this as a causal effect of "excursion causing dispersal".
It is a strong predictive/behavioural linkage.

### Critical E2 logic audit

The annual resident-group reconstruction has five criteria. Criterion 1 uses
only the focal year's own capture-group mode, but criteria 2-5 can use
adjacent-year information.

This creates a potential information-leakage problem for E2 because, in a small
minority of badger-years, the y resident-group assignment can itself be informed
by y+1 data, and the y+1 assignment can be informed by y data.

Although criterion 1 accounts for ~95.7% of annual assignments, ambiguous
transition years may be disproportionately represented among criteria 2-5 and
are exactly the years most relevant to this question.

A strict E2 sensitivity has therefore been added requiring:

- criterion-1 residency in both y and y+1; and
- >=2 grouped captures in both years.

This removes adjacent-year assignment leakage and weak one-capture annual
residency assignments.

**Project rule:** the current all-assignment E2 result is important but should
not be treated as final until the strict sensitivity gives the same qualitative
conclusion.

A second interpretation gate is also required. A change in annual resident
**social-group label** is not automatically an individual spatial relocation.
Historical sett-to-group relationships themselves change as territories
reconfigure, split, merge or are renamed. The analysis now therefore derives a
unique annual modal sett and decomposes resident-group changes into:

- group change + dominant-sett change: stronger evidence of individual spatial
  relocation;
- group change with the same dominant sett: compatible with social-territory
  reconfiguration / relabelling rather than individual dispersal;
- group change with unresolved dominant sett.

Until that decomposition is inspected, use **resident-group identity change**
rather than **dispersal** or **relocation** for the E2 endpoint.

The covariate previously called `capture_effort` has also been renamed
`observation_opportunity`. It is log(1 + number of observed captures), not
measured trap-night effort. It is included because detecting an extra-group
capture becomes easier with more observations; exact historical trap-night
effort is not available.

Outputs added:

```
results/behaviour_next_year_residency_change_STRICT.csv
results/behaviour_next_year_residency_change_STRICT_raw.csv
results/behaviour_next_year_residency_change_STRICT_model.rds
results/behaviour_next_year_residency_change_STRICT_parametric.csv
```

### E3A: focal-year-modal excursion sequence

The first sequence analysis found:

- 432 resident -> other-group events;
- 190 had a later capture in the same year;
- 164/190 = 86.32% were next observed back in the annual resident group;
- 26/190 remained outside that resident group at the next capture;
- 242/432 had no later capture in the same year.

This 86.3% value must **not** be interpreted as an unbiased population return
probability.

The reason is structural: focal-year resident group is itself defined from the
same year's capture history, primarily as the modal capture group. A temporary
departure from the annual modal group is therefore more likely to be labelled an
"excursion" than a persistent mid-year relocation that changes the annual modal
group. The construction can consequently inflate the apparent return fraction.

There are two additional observation issues:

1. requiring another capture before the end of the same calendar year creates
   right-censoring at 31 December and makes follow-up depend on event timing and
   trapping opportunity;
2. sequence analyses must not order multiple different social groups observed
   on the same calendar day arbitrarily.

Therefore E3A is retained as a useful descriptive diagnostic only.

### E3B: leakage-safe prospective excursion analysis

The behavioural script now contains a stronger E3B design.

Baseline residence is defined **before** the focal year using the y-1 resident
group, and that baseline must be:

- criterion 1; and
- supported by >=2 grouped captures.

Within focal year y, a direct outward event requires:

```
prior-resident group A -> another group B
```

on consecutive unambiguous observed capture-days.

Capture records are collapsed to the capture-day level so multiple records on
the same date do not create artificial ordered transitions. Days containing
more than one social group are treated as ambiguous rather than alphabetically
ordered.

The next observed capture-day is then followed across calendar-year boundaries
rather than being administratively censored at 31 December.

Where a strict criterion-1, >=2-capture resident group is also available in
y+1, E3B additionally records whether the animal has changed long-term
residency relative to the independently established y-1 baseline.

This permits separation of:

- immediate return after an outward event;
- continued observed use outside the prior resident group;
- later confirmed resident-group change.

Output:

```
results/behaviour_observed_excursion_returns_PRIOR_BASELINE.csv
```

### Current biological conclusion

The existing evidence already supports a real distinction between routine
resident use and observed inter-group use, and the E2 association is large.

However, the strongest defensible statement before the strict rerun is:

> Observed use of another social group is strongly associated with subsequent
> reconstructed residency change, but the magnitude and interpretation must be
> checked in leakage-safe, independently baselined sensitivity analyses.

If E2S remains strong and E3B shows that independently defined outward events
often precede confirmed y+1 relocation, then the behavioural hierarchy becomes
much more secure:

```
resident use
    -> observed inter-group outward event
    -> return / repeated bridging / persistence outside
    -> confirmed resident-group relocation
```

That hierarchy can then be compared with V11/V11S annual high-mobility states
and later with infectiousness/shedding without redefining the same behaviour
multiple times.

### Implementation commit

Logic safeguards added to:

```
scripts/behaviour/Woodchester_intergroup_excursion_analysis.R
```

Commits:

```
a093c83d6a3c79fbd126071e9ea17bdaf9bfb91e
983d048d6cdfc5d32b7218487596dee3f6f0c33e
60cecb7d858a8a61b9e6e37059765062e01700a0
```



## Inter-group excursion analysis completed — 21 October 2026

The resumed E2/E3 analysis completed successfully.

### E2: observed extra-group use predicts next-year resident-group change

There were 4,677 consecutive resident badger-years with annual resident-group
assignments in both year y and y+1.

Raw next-year resident-group change:

- no observed extra-group use in year y:
  368/4,204 = 8.75%;
- >=1 observed extra-group capture in year y:
  125/473 = 26.4%.

The adjusted binomial BAM included:

- any extra-group use;
- sex;
- age class;
- smooth capture effort;
- year random effect;
- badger random effect.

Adjusted extra-group coefficient:

[
\beta_{extra}=1.416,quad SE=0.142,quad p<2\times10^{-16}
]

corresponding to an odds ratio of approximately:

[
OR=4.12quad (95\%\ CI\ approximately\ 3.12-5.44).
]

Thus observed extra-group use in year y is strongly associated with resident
social-group change in year y+1 even after accounting for observation effort,
sex, age, year and persistent individual heterogeneity.

Males also had higher odds of next-year resident-group change:

[
\beta_{male}=0.865
]

or approximately OR=2.38 (95% CI approximately 1.93-2.93).

Age effects were weak after adjustment, except the unknown-age category.

Badger identity remained significant (RE SD approximately 0.55), indicating
persistent individual heterogeneity in relocation propensity.

### E3: directly observed excursion returns

There were 432 directly observed resident -> other-group excursion events.

- 190 had a later capture in the same calendar year;
- 164/190 = 86.32% were back in their annual resident group at the next observed
  capture;
- 26/190 = 13.68% were still outside the resident group at the next observed
  capture;
- 242 had no later same-year capture and therefore cannot be classified as
  return/non-return.

This strongly supports the biological interpretation that most observed
inter-group movements are temporary excursions rather than immediate permanent
relocations.

### Combined interpretation

The two results jointly support a useful distinction:

1. most observed inter-group excursions are temporary;
2. nevertheless, a year containing extra-group use identifies a substantially
   elevated probability of resident-group change in the following year.

This is consistent with exploratory / bridge behaviour sometimes preceding
dispersal, while remaining common as temporary ranging behaviour.

### Important prospective sensitivity

Annual resident group in year y is reconstructed from the full year's capture
SOCG history, so predictor and current-year residency are not fully independent.

Before treating extra-group use as a directional precursor to dispersal, run a
prospective sensitivity in which only early-year extra-group observations
(e.g. Q1-Q3, and preferably Q1-Q2 as a stricter test) are used to predict
resident-group change in y+1.

Also test destination matching:

> among badger-years with extra-group use and a later resident-group change,
> how often is the year y+1 resident group one of the extra groups visited in
> year y?

A strong destination-match signal would provide especially direct evidence that
observed excursions can represent exploration of the eventual destination
social group.


## Prospecting / temporary bridging pathway analysis — 21 October 2026

The behavioural programme now moves away from repeated generic mover/non-mover
models. Existing movement, distance, SOCG provenance and excursion analyses are
treated as groundwork.

The next primary biological question is:

> **Do badgers prospect future social groups before dispersing into them?**

New script:

```
scripts/behaviour/Woodchester_prospecting_pathways.R
```

### Prospective design

To avoid defining "home" using the same focal-year captures that are used to
identify excursions:

- baseline resident group A comes from year y-1 only;
- baseline residency must be Vicente criterion 1 with >=2 grouped captures;
- focal-year y capture-days are then followed chronologically;
- future resident group comes from year y+1 only and must also be criterion 1
  with >=2 grouped captures.

The flagship observed sequence is therefore:

[
Resident_{y-1}=A
ightarrow
A ightarrow B ightarrow A; 	ext{during year } y
ightarrow
Resident_{y+1}=? 
]

A closed prospecting bout can contain multiple outside capture-days and more
than one outside group, e.g. A->B->B->A or A->B->C->A.

### Primary questions

1. How often are closed prospecting bouts directly observed?
2. Among closed prospecting years with strict y+1 residency, how often does the
   future resident group match a group actually prospected in year y?
3. In the clean single-target case A->B->A, what fraction later remain A,
   settle in B, or move to a different C?
4. How often do individuals make multiple separate A->B->A bouts to the same
   outside group within a year?
5. How many individuals show closed prospecting in multiple years?

Unclosed A->B sequences are retained but are never called permanent dispersal:
failure to observe a return may simply reflect incomplete capture history.

### Decision rule

Do not add another generic predictor model at this stage. First establish
whether exact prospecting, repeated temporary bridging, and destination matching
occur in sufficient numbers to support a distinct biological story.

If destination matching is common, the next inferential target should be
prospecting of a specific future destination, not generic mobility.

If repeated temporary bridging is common, that phenotype becomes a candidate
mechanism for linking social groups in later infection/shedding analyses.


## Prospecting pathway result — 21 October 2026

The prospective pathway analysis completed and provides a more specific result
than generic mover/non-mover analyses.

Design:

- strict resident group A from year y-1;
- focal-year y capture sequence observed independently;
- strict future resident group from year y+1;
- both annual resident assignments criterion 1 with >=2 grouped captures.

### Observed closed prospecting

Among 3,066 focal badger-years with focal-year capture data:

- 581 had >=1 extra-group capture-day;
- 88 had >=1 directly observed closed prospecting bout:
  A -> outside group(s) -> A;
- 93 closed prospecting bouts were observed in total;
- only 5 badger-years had >=2 separate closed bouts to the same outside group;
- 7 badgers showed closed prospecting in >=2 focal years.

Thus repeated temporary bridging exists but is not yet common enough in the
directly observed data to justify treating a stable "bridge badger" phenotype
as the primary biological story.

### Destination-specific later settlement

Among 42 closed-prospecting badger-years with strict y+1 residency known:

- 31/42 = 73.8% remained resident in baseline group A;
- 9/42 = 21.4% became resident in a group actually prospected during year y;
- 2/42 = 4.8% moved to an unvisited group.

Among the 11 animals that changed resident group after closed prospecting:

- 9/11 = 81.8% settled in a group they had directly prospected.

For the clean single-target case in which all closed prospecting involved only
one group B:

- n = 40;
- 30/40 = 75% remained resident A;
- 8/40 = 20% became resident B;
- 2/40 = 5% moved to another group C.

Among the 10 single-target prospectors that later moved, 8/10 = 80% settled in
the prospected group B.

### Current biological interpretation

The strongest current behavioural story is therefore not simply that "movers
move more."

Instead:

> Badgers sometimes make temporary inter-group prospecting trips, return to
> their established resident group, and, when they later disperse, frequently
> settle in a group that they had previously prospected.

Closed prospecting is not deterministic: most prospectors remain resident in
their original group the following year. The interesting signal is destination
specificity among subsequent dispersers.

### Next inferential target

The next test should be a destination-choice null rather than another generic
movement model.

Question:

> Is 9/11 destination matching greater than expected simply because both
> prospecting and later dispersal are directed toward nearby / accessible
> neighbouring groups?

Use a null that preserves contemporary social geography and movement
opportunity, ideally by permuting y+1 destinations within appropriate
baseline-group x year strata or by constructing a distance/adjacency-weighted
candidate-set choice model.

Only if prospecting predicts the eventual destination beyond spatial
opportunity should it be interpreted as evidence for true destination
prospecting before dispersal.


## Destination-choice null test for small prospecting sample — 21 October 2026

The closed-prospecting disperser sample is intentionally strict and small:
11 movers, of which 9 settled in a previously prospected group.

Observed destination-match proportion:

- 9/11 = 81.8%;
- exact Clopper-Pearson 95% CI approximately 48.2%-97.7%.

Therefore the effect estimate is potentially large but imprecise. Do not fit a
large multivariable model to these 11 focal events.

A dedicated small-sample destination-choice analysis was added:

```
scripts/behaviour/Woodchester_prospecting_destination_null.R
```

For each focal mover, the null destination distribution is built from OTHER
badgers that made the same two-year strict resident-group transition from the
same source group. Several temporal matching windows are evaluated:

- exact focal year;
- +/-2 years;
- +/-5 years;
- all years.

This conditions the null on empirically observed dispersal routes from the same
source social group and therefore captures local accessibility / neighbouring
group structure better than an equal-choice null.

The test reports event-level null match probabilities and exact
Poisson-binomial tail probabilities. Jeffreys-smoothed probabilities are also
reported to prevent small reference sets with 0 or 100% observed matches from
creating artificial certainty.

Decision rule:

- focus on effect size, exact interval and consistency across temporal windows;
- if local reference support is weak, describe destination matching as
  suggestive rather than definitive;
- if the excess match rate survives +/-2y, +/-5y and all-years nulls, that is
  substantially stronger evidence for destination-specific prospecting before
  dispersal.


## Destination-null result — preliminary interpretation — 21 October 2026

The first empirical destination-choice null test confirms that the prospecting
signal is promising but partially explained by source-group connectivity.

Observed focal result:

- 11 strict closed-prospecting movers;
- 9/11 = 81.8% settled in a previously prospected group.

Empirical nulls built from other strict movers from the same source group gave:

- all years:
  - all 11 focal events supported;
  - expected matches ~6.19 raw / 6.11 Jeffreys-smoothed;
  - observed 9;
  - Poisson-binomial upper-tail p ~0.0069 raw / 0.0286 smoothed;
- +/-5 years:
  - 9/11 focal events had comparator moves;
  - 8/9 supported focal events matched;
  - expected matches ~5.82 raw / 5.65 smoothed;
  - smoothed upper-tail p ~0.0475;
- +/-2 years:
  - only 7/11 focal events had comparator moves;
  - all 7 matched;
  - expected matches ~5.06 smoothed;
  - smoothed upper-tail p ~0.0617;
- exact-year support was too sparse to be informative.

Interpretation:

> The high destination-match rate is not purely a trivial consequence of
> generic mobility, but a substantial part of it is expected from repeated
> source-group-to-destination connectivity.

The local temporal nulls are underpowered, so the result should currently be
described as suggestive rather than definitive evidence of destination-specific
prospecting.

Do not report raw empirical-zero p-values as decisive: some small reference sets
contain 0 or 100% matching destinations. Prefer Jeffreys-smoothed probabilities
and report comparator support explicitly.

The clean single-target sequence A->B->A should be the primary biological
sensitivity because multi-target prospectors have a mechanically larger chance
of destination matching. The null script has therefore been extended to:

- report a single-target analysis separately;
- add a +/-10-year temporal window between +/-5 years and all-years.

The next interpretation should focus on whether the single-target result is
consistent across +/-5, +/-10 and all-years reference sets.


## Destination-null v2 result — single-target sensitivity — 21 October 2026

The clean single-target prospecting sensitivity confirms that the destination
signal is not driven by animals that prospected multiple outside groups.

Clean focal set:

- 10 strict movers with closed A->B->A-type prospecting involving one target
  group B only;
- 8/10 = 80% later became resident in B;
- exact Clopper-Pearson 95% CI = approximately 44.4%-97.5%.

Empirical same-source-group destination null:

- all years:
  - all 10 focal events supported;
  - expected matches ~5.16 using Jeffreys-smoothed event probabilities;
  - observed 8;
  - upper-tail p ~0.0299;
- +/-10 years:
  - all 10 focal events supported;
  - expected ~5.19;
  - observed 8;
  - upper-tail p ~0.0250;
- +/-5 years:
  - 9/10 focal events supported;
  - expected ~5.65;
  - observed 8;
  - upper-tail p ~0.0475;
- +/-2 years:
  - 7/10 focal events supported;
  - expected ~5.06;
  - observed 7;
  - upper-tail p ~0.0617;
- exact-year comparisons remain too sparse to be useful.

The consistency of the all-years, +/-10y and +/-5y nulls supports a real excess
of settlement into the prospected destination beyond ordinary source-group
connectivity. However, the sample remains small and the local +/-2y comparison
is underpowered.

Important replication caveat:

- focal events are not equivalent to fully independent source-group replicates;
- several focal animals share the same baseline group (notably BOXWOOD and
  SEPTICTANK) and therefore share destination opportunity structure.

The destination-null script now reports source-group replication explicitly.
Do not present nominal focal n=10 as ten independent social-landscape
replicates.

Preferred current wording:

> There is suggestive evidence that badgers which subsequently disperse are
> disproportionately likely to settle in a social group that they previously
> visited and returned from, beyond the destination frequencies expected from
> other dispersers leaving the same source group.

Avoid causal wording such as "prospecting determines destination choice" until
the result is supported by more independent source-group/time replicates or a
stronger spatially explicit destination-choice analysis.


## V11S full-data three-chain convergence result — 21 October 2026

Full V11S completed for all 1,932 movement-eligible badgers, with 750 retained
draws per chain after burn-in.

Formal three-chain scorecard:

- 17 pre-specified key parameters;
- max R-hat = 1.74;
- median R-hat = 1.10;
- minimum ESS = 17.7;
- median ESS = 221;
- 11/17 parameters have R-hat > 1.05;
- 8/17 have R-hat > 1.10.

Therefore the model is **not yet converged overall** and the full coefficient
set must not be interpreted as final.

### What improved strongly relative to the 300-badger V11S fit

The broad resident/high-mobility state process is much more stable:

- sigma_badger: R-hat 1.00, ESS 136; chain medians 0.177, 0.193, 0.170;
- alpha_RD: R-hat 1.01, ESS 221;
- beta_RD_sex: R-hat 1.02, ESS 797;
- sigma_female: R-hat 1.01;
- sigma_male: R-hat 1.08.

Recovered annual state agreement also improved materially:

- 6,316 annual movement intervals;
- median cross-chain range in P(high) = 0.000047;
- 95th percentile = 0.227;
- 309/6316 = 4.89% have cross-chain range >0.25;
- 227/6316 = 3.59% >0.50;
- 157/6316 = 2.49% >0.80.

Thus most annual intervals are now classified consistently across chains, with
severe disagreement localized to a minority of intervals/animals.

### What remains unresolved

The local annual movement-scale decomposition is still poorly mixed:

- female local mean:
  - chain medians 12.4, 10.7, 11.6 m;
  - R-hat 1.74;
  - ESS 17.7;
- male local mean:
  - chain medians 8.71, 7.04, 7.50 m;
  - R-hat 1.74;
  - ESS 26.5.

The high-movement scale is substantially better but not fully ideal:

- female high mean ~1,024 m pooled, R-hat 1.10, ESS 54.8;
- male high mean ~685 m pooled, R-hat 1.04, ESS 37.2.

Several initiation/age/persistence parameters also remain unconverged:

- beta_disp_init_sex R-hat 1.43;
- beta_age_2 R-hat 1.39;
- beta_age_6plus R-hat 1.19;
- alpha_DD R-hat 1.19;
- alpha_disp_init R-hat 1.17;
- beta_DD_sex R-hat 1.15.

Earlier half-chain diagnostics show substantial within-chain drift in the
local-scale ridge, especially chains 1 and 2, rather than three completely
stationary separated modes. Therefore one controlled chain-continuation attempt
is justified before changing model biology.

### Decision

1. Do not report/interpret final V11S age, initial-state, DD persistence or
   local-scale coefficients yet.
2. Do not abandon V11S: the full dataset has substantially stabilized the
   biologically important state classification and RD process.
3. Attempt a genuine continuation of the three existing chains from their saved
   terminal states, preserving the current model and sampler architecture.
4. Re-run the same convergence/state scorecard after continuation.
5. If local-scale R-hat/ESS and the remaining transition/age terms fail to
   improve materially, stop sampler engineering and simplify/reparameterize the
   annual movement estimand rather than repeatedly refitting the same biology.


## V11S long continuation — structural ridge confirmed — 23 October 2026

The terminal-state restart / long continuation was completed for all three
full-data chains. The result is decisive: additional chain length did **not**
resolve convergence and instead exposed a stable annual local/high movement
ridge.

Three-chain scorecard after continuation:

- max R-hat = 3.91;
- median R-hat = 1.20;
- 14/17 key parameters have R-hat > 1.05;
- 12/17 have R-hat > 1.10.

Most importantly, the annual local movement scale occupies sharply different,
internally persistent chain regions:

- female local mean:
  - chain 1 ~21.2 m;
  - chain 2 ~17.0 m;
  - chain 3 ~2.4 m;
  - R-hat 3.91;
- male local mean:
  - chain 1 ~13.4 m;
  - chain 2 ~10.6 m;
  - chain 3 ~1.57 m;
  - R-hat 3.78.

By contrast, the high-movement scale remains broadly similar across chains:

- female high ~1,118, 1,178, 1,184 m;
- male high ~702, 732, 775 m;
- alpha_logmove_high ~6.79--6.85.

The key ridge is almost exact compensation between alpha_logmove and
beta_move_high, especially chains 2 and 3 (correlations approximately -0.99
and -0.97), while alpha_logmove_high stays nearly invariant.

Half-chain diagnostics show that chains 1 and 3 are largely stable within their
own local-scale regions; chain 2 still drifts but does not collapse the
between-chain separation. Therefore this is no longer plausibly explained by
insufficient chain length.

### State inference remains much more stable than the nuisance scale decomposition

Despite parameter nonconvergence, recovered high-mobility probabilities are
remarkably consistent for most intervals:

- 6,316 annual intervals;
- median cross-chain range ~0.00047;
- 95th percentile ~0.063;
- 187/6316 = 2.96% have range >0.25;
- 127/6316 = 2.01% >0.50;
- 72/6316 = 1.14% >0.80.

Thus the model agrees on most annual high-mobility classifications while being
unable to identify the exact sub-resolution local process scale.

### Interpretation

The local annual AC displacement component is being estimated at roughly
1--20 m, whereas the quarterly observation / activity-centre scale is about
150--160 m. The data therefore cannot reliably distinguish very small annual
AC shifts within an otherwise stable resident range. The exact local movement
scale is a nuisance parameter below the effective resolution of this model.

The high-scale relocation process (~1 km) is much better identified.

### Decision

**Stop extending V11S chains. Do not combine or report the unconverged
parameter posterior as a final model.**

The next model should target the biologically identifiable estimand:

> stable annual residency versus large-scale relocation/high mobility,

rather than trying to estimate an exact local annual displacement scale below
the observation resolution.

Preferred next architecture:

1. retain one annual activity centre and the direct quarterly multi-location
   observation model;
2. retain a large-scale relocation component whose displacement scale is
   estimated;
3. treat resident-state process noise as a nuisance quantity that is fixed or
   strongly anchored, with a small pre-specified sensitivity grid rather than
   freely estimated;
4. initially retain the simplest identifiable relocation-propensity structure
   (sex + age + persistent individual heterogeneity);
5. only retain Markov RD/DD persistence if observed/posterior-predictive
   evidence demonstrates that it adds biologically useful serial dependence;
6. validate recovered relocation events against independently reconstructed
   annual resident-group changes and observed inter-group movement/prospecting.

This is a change in parameterisation/estimand, not an attempt to fit a new
biological story after seeing coefficient significance. It follows directly
from the demonstrated resolution limit and the previously defined roadmap rule
against repeated fit-fishing.


## 23 October 2026 — resolution-aware final V11 movement engine; preserve V12/V13 biology

The failed long V11S continuation changes the *parameterisation* of the final
movement engine, not the biological programme.

### Versioning decision

Do **not** rename the next movement reparameterisation V12.

V12 remains reserved for the roadmap's genuinely new demographic biology:

- entry/recruitment;
- immigration/settlement;
- apparent survival/retention;
- permanent disappearance/emigration;
- known-death information.

The immediate movement step should therefore remain in the V11 family
(provisionally **V11R: resolution-aware resident/relocation model**).

### What the V11S ridge means biologically

Annual activity-centre coordinates are continuous; the 50 m habitat raster is
not itself a 50 m coordinate measurement device. Nevertheless, the freely
estimated resident-process mean displacement has occupied modes from roughly
2--20 m while:

- the habitat/support raster is 50 m;
- the quarterly observation/activity-centre scale is roughly 150--160 m;
- the large-movement component is roughly 1 km and is much more stable.

Therefore the exact resident annual displacement scale is below the useful
resolution of this model. It should not be interpreted as literal biological
home-range movement.

The intended resident-state estimand is now:

> **no resolvable annual relocation of the activity centre**

rather than "zero movement", "movement below exactly 50 m", or "same raster
cell".

Avoid a hard same-cell rule because an arbitrarily small displacement across a
cell edge would be classified differently from the same displacement within a
cell.

### Grid-scale clarification

The 50 m habitat raster matters because it defines the discretised habitat /
state-space support used when evaluating whether a continuous annual activity
centre lies in allowed habitat. It does **not** quantise the annual activity
centre itself to 50 m coordinates.

Therefore:

- a finer raster could reduce habitat-edge discretisation;
- it would not create new information in the capture data about whether a
  resident annual centre moved 2 m versus 20 m;
- re-gridding is not the primary remedy for the V11S ridge;
- the resident-state scale should be treated as unresolved process noise and
  assessed by a pre-specified sensitivity rather than defined by raster-cell
  identity.

Use 50 m as a biologically transparent central sensitivity because it matches
the existing habitat raster scale, not because 50 m is assumed to be a true
behavioural threshold. The 25/50/100 m mean-radial-displacement sensitivity
brackets this unresolved scale.

Where year-specific social-group polygons are available, retain them as vector
geometry for posterior overlays rather than rasterising them to the 50 m
habitat grid unless a later computational step explicitly requires a raster.
This keeps territory-boundary precision conceptually separate from habitat-grid
resolution.

### V11R architecture

Preserve as much V11S biology as possible and change only the demonstrated
non-identifiable nuisance component first:

1. retain continuous annual activity centres;
2. retain the direct quarterly multi-location observation likelihood;
3. retain the two-component resident/relocation annual movement mixture;
4. **fix/anchor the resident-process movement scale** rather than estimating it
   freely;
5. estimate the relocation/high-mobility scale;
6. initially retain the existing transition biology:
   - initial relocation probability;
   - resident -> relocation transition;
   - relocation -> relocation persistence;
   - sex;
   - current chronological age;
   - persistent individual mover propensity;
7. remove transition structure only if convergence remains poor *after* the
   resident-scale ridge has been eliminated.

Pre-specify a small sensitivity set for the fixed resident scale. Express this
in biologically interpretable mean radial displacement, not raw Gaussian sigma;
candidate values should bracket the 50 m raster scale without pretending that
50 m is a biological threshold (for example 25, 50 and 100 m mean radial
displacement).

The purpose of this sensitivity is not model selection. The question is whether
the inferred relocation histories and biological coefficients are robust to a
plausible unresolved resident-process scale.

### Dynamic social-group boundaries are now an explicit parallel state layer

The annual territory archive now contains 49 year-specific polygon products
covering 1977--2025 and has its own audit outputs under
`outputs/social_group_boundary_audit/`. These polygons should **not** define
the latent relocation state. Geographic movement must remain inferable without
using group identity so that social consequences can be tested independently.

The boundary audit and earlier posterior overlay also show why assignments must
retain uncertainty: posterior annual centres can fall outside all mapped
territories or within overlapping polygons. Do not force such locations into a
group simply to obtain a complete categorical variable.

For each posterior annual transition, derive at least four distinct concepts:

1. **geographic relocation probability** from V11R;
2. **capture-derived social-group/residency change** from the audited SOCG and
   annual resident-group histories;
3. **polygon-defined territory transition** under the year-specific maps;
4. **boundary-change-only reassignment**, where group assignment changes because
   the territory map changes despite little geographic relocation.

Use both endpoint coordinates against both year-t and year-(t+1) polygon layers
where possible so that animal movement and moving boundaries are not conflated.

Do not force out-of-polygon or overlapping locations into a group. Preserve
posterior assignment uncertainty.

### Why this preserves the immigration story

V11R supplies a robust geographic relocation history. V12 then combines that
with entry timing, detection history, annual residency/group identity,
time-varying territory membership, known death and subsequent disappearance.

Probable immigration should be inferred from the *whole entry and settlement
history*, not from adult entry or sex alone.

Candidate V12 distinctions include:

- first appearance with stable local settlement;
- first appearance accompanied by geographic relocation/high mobility;
- entry into a social territory from an uncertain/outside origin;
- later within-study dispersal between established territories;
- disappearance following relocation versus disappearance from stable
  residency;
- known death versus apparent emigration/nondetection.

This keeps immigration, survival and emigration as demographic processes rather
than relabelling all high-mobility events as immigration.

### Why this preserves the infection/transmission story

V13 remains focused on infectiousness and transmission, not another generic
infected-versus-mover regression.

The combined V11R/V12/social-landscape products will allow the biologically
important distinction between:

- infectious resident source;
- infectious temporary inter-group visitor/prospector;
- infectious disperser/immigrant;
- susceptible recipient crossing into infectious territory;
- infection imported into a group;
- infection becoming established/persisting after importation.

Year-specific territory geometry then defines changing adjacency, social
membership and infectious-source pressure without being used circularly to
define movement.

The eventual group-level questions remain:

> Is infection maintained by resident infectious burden, or repeatedly reseeded
> by immigration / inter-group movement?

and

> How do mortality, social-group loss, territory expansion/contraction,
> immigration, culling and connectivity alter persistence and recolonisation?

### Immediate sequence

1. build V11R with anchored resident scale and pre-specified sensitivity;
2. require convergence and robustness of relocation histories across that
   sensitivity;
3. overlay V11R posterior states on the already-built time-varying territory
   products and capture-derived residency histories;
4. freeze the geographical movement engine;
5. proceed to V12 demographic entry/survival/apparent-emigration/immigration;
6. perform the infectiousness diagnostic audit and then V13;
7. use dynamic territory connectivity for importation, establishment,
   persistence and reseeding analyses.

Do not repeat the already-completed generic infected -> movement or movement ->
infection questions unchanged. Revisit disease only where the estimand changes
to infectiousness, demography, importation/reseeding, dynamic exposure or a
materially improved joint latent-state formulation.
