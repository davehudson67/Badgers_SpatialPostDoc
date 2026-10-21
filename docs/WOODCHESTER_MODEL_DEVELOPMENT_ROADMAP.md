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
