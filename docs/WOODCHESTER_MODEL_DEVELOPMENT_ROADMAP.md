# Woodchester Badger Modelling Development Roadmap

## Model status at a glance — 6 November 2026

This table is a navigation summary, not a replacement for
the dated analyses and scientific decisions below. See the
full history before interpreting any model result.

| Model / programme | Scientific purpose | Evidence and status | Current decision |
|---|---|---|---|
| V7 | Directional movement–infection relationships | Historical analyses completed; conclusions and limitations recorded below | Preserve results; avoid repeating the same estimands |
| V8–V9 | Earlier model-development stages | Historical; consult model lineage for specifications and results | Retain as background |
| V10A/B | Spatial capture, movement and detection formulations | Superseded model development, including unsuccessful approaches | Do not resume V10B by default |
| V11 / V11S | Age, individual heterogeneity and movement-state development | Fitted and diagnostically investigated; limitations documented | Superseded as primary movement reference |
| **V11R2** | Resolution-aware geographic movement estimation | Fitted with resolution sensitivities; legacy-input reconciliation outstanding | Current movement reference, subject to input audit |
| Behavioural/social pathways | Excursions, residence changes, group reassignment and dispersal | Exploratory analyses completed; some interpretations depend on location and territory validation | Preserve uncertainty; review before publication |
| **V12** | Detection, apparent survival, disappearance and movement–demography | Planned; data eligibility and source reconciliation underway | Next modelling priority |
| **V13** | Infectiousness, introduction, transmission and persistence | Planned research programme | Develop after appropriate V12 and disease-data validation |

### Evidence and status conventions

- **Fitted** means an analysis was run, not necessarily
  that its parameters or scientific interpretation are validated.
- **Validated** requires appropriate diagnostics and
  checks of the relevant data and model assumptions.
- **Superseded** does not mean scientifically worthless;
  preserve the reasons for abandoning or replacing a model.
- **Planned** means no completed fit or result is implied.
- The dated sections below provide numerical results,
  model specifications, scripts, diagnostics and decisions.
- Reassess this table whenever new results or audits
  materially change the scientific position.

---

## Living record: current position and update protocol

**Last structural review:** 6 November 2026.

This document is the sole authoritative scientific record
for Woodchester model development.

### Current position

- **V11R2:** fitted movement reference, including resolution
  sensitivities and retained posterior chains.
- **V11R2 input audit:** outstanding comparison of historic
  RDS-based data against curated Supabase encounters.
- **Sett/location review:** awaiting further field-team
  evidence; do not invent missing locations or merge
  biologically distinct sett identities.
- **V12:** next main scientific development programme,
  beginning with auditable encounter/fate histories,
  detection and apparent survival.
- **V13:** subsequent disease and transmission modelling,
  informed by movement, demography and dynamic social
  structure.

### How this roadmap must be maintained

Every substantive new analysis or modelling decision
must be appended as a dated entry.

Each entry should record:

1. Date, model version and status.
2. Scientific question and hypotheses.
3. Data version, sample size and inclusion/exclusion rules.
4. Executable scripts, commands and settings.
5. Model structure, assumptions and priors.
6. Fitting progress, convergence and model checks.
7. Numerical results with reproducible output references.
8. Biological interpretation and limitations.
9. Decision made, rationale and rejected alternatives.
10. Next action and any dependencies.

Use explicit statuses:
**PLANNED**, **RUNNING**, **PRELIMINARY**,
**VALIDATED**, **REJECTED**, **SUPERSEDED** or **BLOCKED**.

Do not change historical entries to make them appear
more certain than the original evidence justified.
Append dated corrections or revised interpretations.

### Scientific priorities

**Immediate:** Reconcile V11R2 legacy inputs with the
curated spatial and encounter data.

**Next:** Establish V12 survival and observation models
before integrating movement/dispersal with survival.

**Longer term:** Investigate disease introduction,
infectiousness, transmission, persistence and the effects
of changing social-group geography.

---


> **CANONICAL MODELLING RECORD — 5 November 2026**  
> This is the **one living chronological record** for Woodchester movement, spatial/social structure, demography and disease-model decisions. The other model guides and annotated code in `docs/`, `markdown/` and `data/` remain historical technical references, not independent current plans. Database access, field definitions, capture/PM cleaning and inconsistency flags are governed by the **four separate canonical database documents on `audit-tattoo-identifier`**.  
> **Current model position:** freeze V11R2-50 geographical relocation with 25m sensitivity; integrated movement/social pathway analysis complete (6,316 intervals); proceed to **V12 demographic/survival input compatibility audit**, before writing/fitting a new likelihood. Source V11R2 scripts/results are on `main`, while the latest audited Supabase SQL/docs are currently on `audit-tattoo-identifier`. Do **not** blindly merge conflicting historical database docs or refit the movement model just because PM coordinates changed.  
> **Reproducible audit:** [V12 survival eligibility SQL](../sql/audit/WECS_V12_readonly_survival_eligibility_audit.sql).  
> **Next action:** run [the V11R2 input comparison script](../scripts/data_audits/WECS_V12_compare_V11R2_legacy_to_Supabase.R) on the RStudio server to reconcile legacy model inputs with curated 2026-11-05 Supabase *live* encounters; only then decide whether to refit movement or construct the staged V12 survival/death likelihood.


**Status:** Living project document  
**Last updated:** 5 November 2026
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
docs/archive/model_development/V10B_MOVEMENT_BIOLOGY_AUDIT_PLAN.md
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
docs/archive/model_development/V11_AGE_BADGER_RE_SPEC.md
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
docs/archive/spatial_audits/SETT_SOCIAL_GROUP_RULES.md
docs/archive/database_history/Woodchester_SQL_R_Analysis_and_Infection_Guide.md
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
V10B additionally estimated AR(1) persistence (
ho), asking whether a
quarterly displacement from the annual centre persisted into the next quarter.

Annual centre-to-centre displacement was separately classified by a two-state
local/high movement HMM.

### What V11 added

V11 retained the annual/quarterly spatial hierarchy but changed the annual
movement biology:

- quarterly AR(1) persistence was removed ((
ho=0)); quarterly deviations
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
docs/archive/spatial_audits/SETT_SOCIAL_GROUP_RULES.md
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
SOCG_{
m capture} 
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
A 
ightarrow B 
ightarrow A; 	ext{during year } y

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


## V11R implementation and resolution-sensitivity launch — 23 October 2026

V11R has now been implemented as the resolution-aware replacement for the
unconverged V11S local-scale parameterisation.

Script:

`scripts/ModularFitting/Woodchester_V11R_resolution_aware_relocation.R`

The change is deliberately narrow:

- annual activity centres remain continuous;
- the 50 m raster remains habitat/state-space support, not a movement lattice;
- direct quarterly multi-location observations are unchanged;
- the two-state annual collapsed HMM is retained;
- initial relocation, resident->relocation and relocation->relocation
  transition structure is retained;
- current chronological age is retained;
- sex effects are retained;
- persistent individual mover propensity is retained;
- the reference/female resident-state mean radial displacement is fixed rather
  than freely estimated;
- the positive relocation contrast remains estimated;
- the existing movement-scale sex effect is retained, so the fixed sensitivity
  value is the female/reference resident mean and the male resident scale is
  implied by the estimated sex contrast.

Pre-specified fixed reference/female resident mean-radial sensitivities:

- 25 m;
- 50 m (central);
- 100 m.

These are sensitivity assumptions, not competing biological hypotheses and not
a model-selection exercise. The primary question is whether recovered
relocation histories and biological coefficients are robust across the three
resolution assumptions.

A parallel launcher has been added:

`scripts/ModularFitting/run_V11R_resolution_sensitivity.sh`

Full mode launches 3 chains for each of the three resident-scale assumptions
(9 independent full-data fits) with conservative BLAS/OpenMP thread caps.
State recovery is run automatically after each completed chain.

A V11R-specific convergence/state summary is available at:

`scripts/ModularFitting/Woodchester_V11R_three_chain_summary.R`

The existing FFBS state-recovery script now accepts V11R fits.

Decision gate after the nine full fits:

1. require acceptable within-scale three-chain convergence;
2. compare posterior relocation histories across 25/50/100 m assumptions;
3. compare sex, age, persistent individual heterogeneity and RD/DD transition
   coefficients across the sensitivity;
4. if relocation inference is robust, freeze V11R as the geographic movement
   engine;
5. then overlay the year-specific social-group polygons and capture-derived
   resident-group histories before proceeding to V12 demography.

Do not choose the resident scale merely because one sensitivity has a slightly
better likelihood or posterior fit. The resident scale is intentionally treated
as unresolved nuisance process noise.


## V11R full resolution sensitivity result and V11R2 decision — 24 October 2026

The full V11R 25/50/100 m resident-resolution sensitivity completed for all
1,932 movement-eligible badgers with three chains per sensitivity.

### Within-scale convergence

The fixed resident baseline removed the catastrophic V11S local-scale ridge,
but convergence still depended strongly on the assumed unresolved resident
scale.

25 m:
- max R-hat 1.74;
- median R-hat 1.07;
- 11/17 key parameters >1.05;
- 5/17 >1.10;
- strongest failure beta_age_2 R-hat 1.74.

50 m:
- max R-hat 1.40;
- median R-hat 1.04;
- 6/17 >1.05;
- 4/17 >1.10;
- remaining failure concentrated in DD persistence and some age terms.

100 m:
- max R-hat 1.08;
- median R-hat 1.00;
- 4/17 >1.05;
- 0/17 >1.10.

Do **not** select 100 m simply because it converges best. The three resident
scales were pre-specified as nuisance-resolution sensitivities, not competing
biological models.

### Relocation-state robustness

Across 6,316 annual intervals:

- robust resident at all three sensitivities: 5,979;
- robust relocation at all three sensitivities: 200;
- sensitivity-dependent classification: 137 (2.17%);
- median cross-sensitivity probability range: 0.00287;
- 95th percentile range: 0.188;
- 63 intervals differed by >0.50 across sensitivities.

Pairwise posterior relocation-probability correlations:

- 25 vs 50 m: 0.935;
- 25 vs 100 m: 0.872;
- 50 vs 100 m: 0.950.

Thus the broad annual relocation history is substantially more robust than the
V11S nuisance-scale decomposition, but a small biologically important subset of
intervals remains resolution-sensitive.

### Biological coefficient sensitivity

Some signals are comparatively stable:

- beta_age_2 remains near zero;
- beta_age_3_5 remains around -0.7 to -0.8;
- beta_age_6plus remains around -1.3 to -1.6;
- persistent individual mover heterogeneity sigma_badger remains around
  0.16--0.18;
- detection/observation sigma remains around 150 m.

Other quantities depend materially on the fixed resident scale:

- female high-movement mean changes from about 1.08 to 1.49 km;
- male high-movement mean changes from about 0.65 to 0.53 km;
- beta_RD_sex changes from about 1.36 to 2.71;
- alpha_DD changes from about -0.75 to +0.73;
- beta_DD_sex becomes increasingly negative.

### Interpretation

This sensitivity is not evidence that the true resident displacement is 100 m.

The remaining dependence is partly induced by the V11R parameterisation:

1. the high/relocation log scale is expressed as a positive contrast from the
   fixed resident scale;
2. the same beta_move_sex modifies both resident and relocation scales.

Therefore changing an intentionally arbitrary nuisance resident scale changes
the coordinate system of the biologically interesting relocation scale and
allows the sex-scale term to compensate.

### Decision: V11R2 decoupled scale architecture

Do not freeze V11R yet and do not continue its 25/50 m chains.

Implement V11R2 with the smallest possible architecture change:

1. keep continuous annual activity centres;
2. keep direct quarterly multi-location observations;
3. keep the collapsed two-state annual resident/relocation HMM;
4. keep initial, RD and DD transition biology;
5. keep chronological age;
6. keep sex effects on relocation probability;
7. keep persistent individual mover propensity;
8. fix resident process noise at 25/50/100 m sensitivities, but make it
   **sex-neutral** because it is unresolved nuisance process noise;
9. estimate the **absolute relocation scale directly** from the same prior in
   every sensitivity rather than as a contrast from the resident scale;
10. allow a separate sex effect on relocation distance only.

V11R2 uses:

- alpha_logmove = fixed resident log-sigma;
- alpha_logmove_high ~ Normal(log(800 m Gaussian sigma), 1), identical across
  resident sensitivities;
- beta_highscale_sex ~ Normal(0, 0.5), affecting high/relocation distance only.

The exact prior should be reported transparently. Its role is weak
regularisation of the identifiable large-scale component, not selection of a
preferred resident scale.

### Decision gate after V11R2

Run the same 25/50/100 m sensitivity.

Freeze the movement engine only if:

- all three sensitivities have acceptable three-chain convergence;
- absolute high-movement scales are substantially more stable;
- sex/age/persistent-mover and RD/DD coefficients no longer shift materially
  with resident resolution;
- relocation histories remain robust for the large majority of intervals.

Only then overlay the dynamic annual social-group polygons and capture-derived
resident-group histories and proceed to V12 demography.


## V11R2 full sensitivity result — freeze geographic movement engine — 25 October 2026

The full V11R2 decoupled 25/50/100 m sensitivity completed for all 1,932
movement-eligible badgers with three chains per sensitivity.

### Main result

V11R2 successfully removed most of the artificial coupling between the nuisance
resident scale and the biologically interesting relocation scale.

The 25 m and 50 m fits give essentially the same relocation process:

- female high-movement median: 1,079 m vs 1,081 m;
- male high-movement median: 572 m vs 573 m;
- beta_highscale_sex: -0.634 vs -0.634;
- beta_RD_sex: 1.76 vs 1.83;
- mean relocation occupancy: 0.0574 vs 0.0596;
- intervals with posterior relocation probability >=0.5: 280 vs 280;
- pairwise relocation-probability correlation: 0.972;
- only 56/6,316 intervals (0.89%) change >=0.5 classification.

Thus the important relocation result is stable across two clearly unresolved
resident-noise assumptions.

### Convergence

25 m still mixes imperfectly for several transition/age parameters:

- max R-hat 1.25;
- median R-hat 1.05;
- 8/17 >1.05;
- 4/17 >1.10.

50 m is acceptable for the intended biological use:

- max R-hat 1.07;
- median R-hat 1.03;
- 4/17 >1.05;
- 0/17 >1.10;
- only 48/6,316 intervals have cross-chain relocation-probability range >0.25.

100 m also converges well numerically:

- max R-hat 1.07;
- median R-hat 1.00;
- 0/17 >1.10.

Do not use numerical convergence alone to choose the biological model.

### Why 100 m is treated as a stress test

At 100 m the assumed resident process is no longer behaving as an effectively
unresolved nuisance scale. It materially changes the latent decomposition:

- mean relocation occupancy drops to 0.0408;
- >=0.5 relocation intervals drop from 280 to 198;
- female high-movement median rises to 1,266 m;
- male high-movement median rises to 691 m;
- alpha_RD shifts to -4.34;
- alpha_DD shifts to +1.08;
- sigma_badger rises to 0.345.

The 25/50 plateau and 100 m departure are therefore interpreted as evidence that
resident noise below roughly the 50 m scale is effectively nuisance variation,
whereas forcing 100 m of annual resident-process movement begins to absorb
biologically meaningful between-year relocation signal.

This is a sensitivity-plateau argument, not model selection by likelihood or
convergence.

### Biological interpretation retained across 25/50 m

Across the two primary sensitivities:

- age 2 is close to the 0-1 reference;
- ages 3-5 have lower resident->relocation transition probability;
- ages 6+ have still lower transition probability;
- males are substantially more likely than females to enter the relocation
  state (positive beta_RD_sex);
- males have a smaller high-movement displacement scale than females
  (beta_highscale_sex about -0.63);
- persistent individual mover heterogeneity remains present but modest.

Using the 50 m central fit only for interpretation, the baseline female
resident->relocation probability is approximately 2.8% per eligible annual
transition, while the corresponding male probability is approximately 15.2%
before age and individual-random-effect adjustments.

### Decision

Freeze **V11R2, resident mean 50 m** as the central geographic movement engine.

Use **25 m** as the principal movement-resolution sensitivity.

Retain **100 m** in the record as an upper stress test demonstrating where the
resident-noise assumption starts to change the biological decomposition; do not
average it into the central result.

Do not hard-code movement state as mover/nonmover for downstream biology.
Carry posterior relocation probability forward.

For each annual interval retain:

- central p_relocation from V11R2 50 m;
- 25 m sensitivity p_relocation;
- absolute 25-vs-50 difference;
- robust classification flag;
- explicit flag for the 56 intervals whose >=0.5 classification switches
  between 25 and 50 m.

### Next step

Proceed to the dynamic annual social-group overlay.

For each posterior annual activity centre / annual transition, combine:

1. V11R2 geographic relocation probability;
2. capture-derived annual resident social group;
3. year-specific territory polygons;
4. group assignment of A_t and A_t+1 under both the old-year and new-year maps.

This must distinguish:

- geographic relocation without social-group change;
- social-group change associated with geographic relocation;
- temporary inter-group visits/prospecting without annual relocation;
- apparent group reassignment caused by changing territory boundaries;
- outside/overlap/uncertain polygon membership.

Only after this overlay should the programme proceed to V12
entry/immigration/settlement/survival/apparent-emigration modelling.

## Dynamic territory lineage and integrated behavioural pathways — 26 October 2026

The post-V11R2 social-landscape work is now sufficiently developed that annual
geographic relocation, territory continuity, capture-derived annual residency
and temporary prospecting can be treated as separate evidence layers.

### V11R2 dynamic annual territory overlay

The central V11R2-50 posterior annual activity centres were overlaid on the
audited 1977--2025 annual territory polygons. V11R2-25 relocation probabilities
were carried alongside as the primary movement-resolution sensitivity.

For every annual transition t -> t+1, both activity centres were classified
under both annual maps:

- G_t(A_t);
- G_t(A_{t+1});
- G_{t+1}(A_t);
- G_{t+1}(A_{t+1}).

This explicitly separates stable-boundary crossing from apparent reassignment
caused by changing annual territory geometry.

The full overlay retained 6,316 movement intervals and the known 56
25-vs-50 m relocation classification switches. With 75 posterior AC draws
(25 per chain), the initial raw-polygon summary had:

- mean central p(relocation): 0.0596;
- mean p(stable territory cross): 0.0184;
- mean p(boundary-change-only reassignment): 0.0852;
- mean p(polygon ambiguous/outside): 0.3778.

The high ambiguity fraction is predominantly caused by posterior activity
centres lying outside the mapped annual territory union, not missing annual
maps. Do not force outside or overlapping points into a group.

### Historical polygon names are not biological SG identifiers

The first boundary-change audit identified 521 intervals with
p(boundary-change-only) >= 0.5.

Consecutive-year polygon geometry showed:

- 233 lower-continuity reconfiguration intervals;
- 232 high-continuity different-label intervals;
- 56 very-high-continuity different-label intervals.

This exposed many historical composite or changing labels, including sequences
around Top / Yew / Taxus / Wych Elm and recurring Box / Larch changes.

Therefore:

> **Do not create a global territory-name -> social-group alias dictionary.**

A change in annual polygon label is not itself evidence of social dispersal.

### Territory-lineage evidence

Consecutive annual polygons were then compared using three independent evidence
streams:

1. geometric overlap;
2. shared canonical sett IDs;
3. capture-recorded social-group evidence at those setts.

Among the 521 boundary-change intervals:

- 216 (41.5%) were STRONG_MULTI_EVIDENCE_CONTINUITY;
- 26 (5.0%) were VERY_STRONG_MULTI_EVIDENCE_CONTINUITY;
- 30 (5.8%) had GEOMETRIC_CONTINUITY_ONLY;
- 233 (44.7%) remained LOWER_GEOMETRIC_CONTINUITY;
- 16 (3.1%) showed GEOMETRIC_CONTINUITY_BUT_DIFFERENT_STRONG_SG_EVIDENCE.

Thus 242/521 (46.4%) have strong/very-strong multi-evidence support for
continuity despite changing annual polygon labels.

Examples such as Box -> Larch can retain many shared canonical setts and LARCH
as the dominant capture-recorded SG on both sides. This demonstrates why raw
polygon labels cannot be interpreted as fixed biological social-group IDs.

No territory names, canonical sett IDs or social-group identities were changed.

### Lineage-aware annual transitions

Posterior annual transitions were reclassified using the territory-lineage
evidence while preserving the raw annual polygon labels.

Across 6,316 intervals:

- 3,595 (56.9%) = SUPPORTED_SAME_TERRITORY_LINEAGE;
- 2,144 (33.9%) = POLYGON_ASSIGNMENT_AMBIGUOUS;
- 334 (5.29%) = UNRESOLVED_TERRITORY_RECONFIGURATION;
- 206 (3.26%) = POSTERIOR_LINEAGE_UNCERTAIN;
- 21 (0.332%) = LIKELY_TERRITORY_LINEAGE_SWITCH;
- 16 (0.253%) = CONFLICTING_LINEAGE_EVIDENCE.

The movement x lineage comparison is especially informative:

- 3,587 = no central relocation + supported same lineage;
- 2,449 = no central relocation + lineage uncertain;
- 251 = geographic relocation + lineage uncertain;
- 21 = geographic relocation + likely lineage switch;
- 8 = geographic relocation within supported same lineage.

All 21 likely territory-lineage switches occur within V11R2 central geographic
relocations; none occurs among the non-relocation intervals.

Capture-derived resident-SG evidence remains independent:

- among the 21 relocation + likely-lineage-switch intervals:
  - 11 have resident-SG change;
  - 8 have resident-SG unchanged;
  - 2 have resident-SG unknown;
- among 251 relocation + lineage-uncertain intervals:
  - 122 have resident-SG change;
  - 50 have resident-SG unchanged;
  - 79 have resident-SG unknown;
- among 8 relocation + supported-same-lineage intervals:
  - 3 have resident-SG change;
  - 5 have resident-SG unchanged.

This shows that geographic relocation, territory-lineage change and
capture-derived resident-SG change are related but non-equivalent processes.

### Integrated behavioural-pathway layer before V12

A new descriptive pathway script has been added:

scripts/behaviour/Woodchester_integrated_behavioural_pathways.R

This is **not another latent-state model**. It combines:

- central V11R2-50 p(relocation);
- V11R2-25 sensitivity and relocation robustness;
- lineage-aware annual territory transition;
- capture-derived annual resident-SG change;
- observed extra-group use / closed prospecting.

Two complementary classifications are retained.

#### 1. Primary annual pathway

The annual y -> y+1 transition is classified into a small set of explicit
biological pathways:

- SOCIAL_DISPERSAL_MULTI_EVIDENCE:
  geographic relocation + likely territory-lineage switch + resident-SG change;
- GEOGRAPHIC_RELOCATION_WITH_LINEAGE_SWITCH_SG_NOT_CHANGED_OR_UNKNOWN;
- GEOGRAPHIC_RELOCATION_WITHIN_SUPPORTED_TERRITORY_LINEAGE;
- GEOGRAPHIC_RELOCATION_SOCIAL_DESTINATION_UNRESOLVED;
- STABLE_LOCAL_RESIDENCY;
- LOCAL_SOCIAL_REASSIGNMENT_WITHOUT_GEOGRAPHIC_RELOCATION;
- LOCAL_RESIDENCY_RESIDENT_SG_UNKNOWN;
- NO_GEOGRAPHIC_RELOCATION_SOCIAL_TERRITORY_UNRESOLVED.

A resident-SG change without geographic relocation is deliberately **not**
called dispersal.

The central 50 m model defines the descriptive annual movement class, but the
25/50 relocation robustness flag remains attached to every interval so
resolution-sensitive cases can be identified rather than hidden.

#### 2. Prospecting / temporary-extra-group sequence

Prospecting in focal year y is aligned with the annual transition y -> y+1 and
kept as a second, orthogonal classification:

- closed prospecting -> later settlement in a visited/prospected group;
- closed prospecting -> remained baseline resident;
- closed prospecting -> later settlement elsewhere;
- closed prospecting with future residency unknown;
- unclosed extra-group use;
- no observed extra-group use.

This preserves the biologically important sequence:

> resident A -> observed A-B-A prospecting -> later settlement in B

without forcing the temporary excursion itself to be labelled annual dispersal.

### Decision gate before V12

Run the integrated behavioural-pathway script and quantify the resulting
pathway counts.

Before fitting V12, confirm:

1. how many annual intervals meet the strict multi-evidence social-dispersal
   definition;
2. how many geographic relocations remain socially unresolved;
3. how many relocations occur within a supported continuing territory lineage;
4. how often resident-SG change occurs without geographic relocation;
5. how prospecting-before-settlement maps onto the annual relocation and
   lineage classes;
6. whether the key social-dispersal pathways remain supported when the V11R2
   25 m sensitivity is considered.

Only then move to V12 entry / settlement / retention / survival /
apparent-emigration / known-death modelling.

The purpose of V12 is demographic inference. It should consume these movement
and social-history products rather than redefining geographic relocation or
territory identity.

### PM / non-sett recovery locations remain separate

The V11R2 territory-lineage overlay continues to exclude PM recovery locations,
road locations and grid-reference-only recoveries from the annual activity-centre
likelihood and territory assignment.

These records remain a separate V12 evidence stream:

- known-sett PM: known death plus established sett location;
- grid-reference PM: known death plus uncertain recovery square;
- unresolved descriptive PM location: known death with spatial location
  unresolved.

Do not assign a recovery road/grid square to the nearest sett or social group.

### Integrated behavioural-pathway results — 26 October 2026

The integrated pre-V12 behavioural-pathway analysis completed successfully for
all 6,316 annual movement intervals.

#### Primary annual pathways

- STABLE_LOCAL_RESIDENCY: 2,669 (42.3%);
- NO_GEOGRAPHIC_RELOCATION_SOCIAL_TERRITORY_UNRESOLVED: 2,449 (38.8%);
- LOCAL_RESIDENCY_RESIDENT_SG_UNKNOWN: 749 (11.9%);
- GEOGRAPHIC_RELOCATION_SOCIAL_DESTINATION_UNRESOLVED: 251 (3.97%);
- LOCAL_SOCIAL_REASSIGNMENT_WITHOUT_GEOGRAPHIC_RELOCATION: 169 (2.68%);
- SOCIAL_DISPERSAL_MULTI_EVIDENCE: 11 (0.174%);
- GEOGRAPHIC_RELOCATION_WITH_LINEAGE_SWITCH_SG_NOT_CHANGED_OR_UNKNOWN: 10 (0.158%);
- GEOGRAPHIC_RELOCATION_WITHIN_SUPPORTED_TERRITORY_LINEAGE: 8 (0.127%).

The central V11R2-50 fit therefore identifies 280 annual geographic relocations:

- 11 strict multi-evidence social dispersals;
- 10 relocation + likely territory-lineage switch without confirmed resident-SG change;
- 8 relocations within a supported continuing territory lineage;
- 251 relocations whose social/territory destination remains unresolved.

#### Movement-resolution robustness of pathway classes

All 11 strict SOCIAL_DISPERSAL_MULTI_EVIDENCE intervals are ROBUST_RELOCATION
under both the 25 m and 50 m V11R2 sensitivities.

All 10 relocation + likely-lineage-switch intervals with resident SG unchanged
or unknown are also ROBUST_RELOCATION.

For the 251 socially unresolved relocations:

- 225 (89.6%) are ROBUST_RELOCATION;
- 26 (10.4%) are 25/50 classification switches.

For the 8 relocations within supported territory lineage:

- 6 are ROBUST_RELOCATION;
- 2 are 25/50 classification switches.

The local/non-relocation pathways are also overwhelmingly movement-resolution
stable:

- 2,666/2,669 stable local residencies are ROBUST_RESIDENT;
- 162/169 local social reassignments are ROBUST_RESIDENT;
- all 749 local-residency / resident-SG-unknown intervals are ROBUST_RESIDENT.

This strongly supports the use of the 50 m central movement engine with 25 m
sensitivity retained as an uncertainty flag rather than as a competing model.

#### Social-dispersal evidence stack

Across all intervals:

- 2,669 have no dispersal signal and stable local evidence;
- 3,026 have no central relocation but incomplete social/territory evidence;
- 341 show resident-SG change without geographic relocation;
- 125 show geographic relocation + resident-SG change but lineage unresolved
  or continuing;
- 79 show relocation with resident SG unknown;
- 55 show relocation while resident SG remains the same;
- 11 show relocation + lineage switch + resident-SG change;
- 10 show relocation + lineage switch without confirmed resident-SG change.

Thus capture-derived resident-SG change alone is not an adequate definition of
dispersal: 341 resident-SG changes occur without central geographic relocation.

#### Prospecting / temporary extra-group behaviour

Of 6,316 annual intervals:

- 4,253 had no strict prospecting window available;
- 1,666 had a strict window with no observed extra-group use;
- 181 had other extra-group use;
- 141 had unclosed extra-group use;
- 33 had closed prospecting but future residency was unavailable;
- 31 had closed prospecting and remained resident in the baseline group;
- 9 had closed prospecting followed by settlement in a visited/prospected group;
- 2 had closed prospecting followed by settlement elsewhere.

Among the 9 closed-prospecting -> visited-group settlement intervals, 8 were
pure single-target prospecting followed by settlement in that same target.

However, those 9 prospecting-before-settlement intervals do not map neatly onto
the strict annual SOCIAL_DISPERSAL_MULTI_EVIDENCE class:

- 4 are NO_GEOGRAPHIC_RELOCATION_SOCIAL_TERRITORY_UNRESOLVED;
- 3 are LOCAL_SOCIAL_REASSIGNMENT_WITHOUT_GEOGRAPHIC_RELOCATION;
- 2 are GEOGRAPHIC_RELOCATION_SOCIAL_DESTINATION_UNRESOLVED.

This is biologically important rather than contradictory. Prospecting is an
observed within-year social-space sequence, while V11R2 relocation is an annual
activity-centre process and territory-lineage classification depends on
historical polygon evidence. The three streams can legitimately disagree or
have different temporal resolution.

Do not redefine prospecting as annual relocation, and do not require annual
relocation as a prerequisite for observed prospecting-before-settlement.

#### Interpretation before V12

The movement/social framework now separates at least four biologically distinct
processes:

1. stable local residency;
2. local social reassignment / apparent resident-SG change without annual
   geographic relocation;
3. geographic relocation whose social destination remains uncertain;
4. high-confidence social dispersal supported by geographic relocation +
   likely territory-lineage switch + resident-SG change.

Temporary prospecting / bridging is an orthogonal within-year behaviour that can
precede any of these annual outcomes.

### Updated V12 entry criterion

The descriptive movement/social integration is now complete enough to proceed
toward V12, but V12 should not attempt to re-estimate or redefine these
movement/social pathways.

V12 should instead model demographic state and fate using them as covariates /
supporting latent-history evidence:

- first appearance / entry;
- settlement after entry;
- retention / apparent survival;
- disappearance / apparent emigration;
- known death;
- probable immigration versus within-study dispersal.

Key V12 safeguards:

- adult entry is not automatically immigration;
- resident-SG change alone is not dispersal;
- a grid-reference PM is known death plus uncertain recovery location, not a
  sett or SG assignment;
- PM recovery locations remain outside the V11R2 movement likelihood;
- known death must be distinguished from disappearance;
- posterior relocation probability should be carried forward rather than only
  a binary mover/nonmover label;
- the 25/50 movement-resolution robustness flag should remain available;
- territory-lineage and resident-SG evidence should remain separate columns
  rather than being collapsed into one social-state variable.


## 5 November 2026 — V12 survival eligibility and restart audit

**This section is the newest scientific decision; previous chronological updates document earlier states.** SQL audit is version-controlled on `main` at `sql/audit/WECS_V12_readonly_survival_eligibility_audit.sql` and is read-only. Snapshotted from the Supabase data after capture/PM identity, spatial and OS-grid curation on 5 November 2026. These counts are **V12 candidate input evidence**, not already-fixed model inclusions or posterior estimates.

### Scientific purpose

V12 moves beyond V11R2 movement to model imperfect detection, survival and observed terminal outcomes, and—only where identified by data—emigration/unavailability, immigration-like entry and settlement. **Apparent survival is not necessarily true survival**, and permanent emigration cannot be distinguished from death without external information, informative recovery observations or structural assumptions. Death-only road/PM recoveries do not automatically join a previously marked CMR individual. Do not infer an immigrant simply from adult age at first capture, a local SG-name change or an unmatched recovery position.

### Live Supabase data audit

| Quantity | Verified |
|---|---:|
| Source capture/PM rows, all uniquely ID-ed and dated | 17,586 |
| Research animal IDs / distinct tattoos | 3,791 |
| Individuals with at least one qualifying live TRAP/NET/SNARE/DART/FOUND_ALIVE observation | **3,224** |
| Animals with no qualifying live capture but candidate death event(s) | **567** |
| Of death-only identities: `UN` tattoos | **498** |
| Of death-only identities: other tattoos | **69** |
| Qualifying live encounter rows | **16,273** |
| Animals observed in >=2 calendar years | **1,971** |
| Animals observed in one year | **1,253** |
| Animals with exactly one qualifying live encounter | **909** |
| Qualifying live animals with sex UNKNOWN | **0** |
| Qualifying live animals with age at first capture UNKNOWN | **1** |
| Qualifying live animals without recorded first-capture year | **0** |
| Qualifying live rows lacking accepted XY | **538** |
| Qualifying live animals with every live XY missing | **51** |
| Qualifying live animals with both mapped and unmapped encounters | **285** |
| Missing-XY live observations at named setts awaiting field-team coordinates | **306, involving 162 animals** |
| Primary recorded mortality events (paired PM companion removed from event count) | **1,304** |
| Candidate terminal death events | **1,300** |
| Identity-conflict terminal deaths held | **2** |
| Possible duplicate-carcass terminal deaths held | **2** |
| Candidate terminal deaths associated with >=1 live history | **733 animals/events in audited join** |

**Importantly these are not final exclusion counts.** A one-live-capture animal can contribute to a properly specified conditional CMR likelihood. A single-year capture history need not be dropped; nor should sex/age unknown force exclusion when an explicit missing-covariate or marginalization strategy is used. Missing XY alone is **never a reason to exclude an animal from survival**; the spatial movement submodel must separately decide whether an encounter can enter its distance likelihood. The 567 dead-only recoveries remain a *separate mortality evidence stream*, not 567 newly marked, released badgers. The 498 UN animals must not be assigned resident social groups, and a coarse Cockadilly locality centroid is not an exact recovery point.

### What genuinely needs an inclusion/exclusion rule

1. **Four held mortality terminal assignments**: U005 and 020D identity contradictions, plus W023 and Q082 possible repeated dead-carcass reports. Retain source death rows and audit flags; do not silently terminate a linked live history until resolved. The source chronology anomaly check also found three encounter records dated before their individual's metadata first-capture year (020D, UN117, UN619); these require separate interpretation rather than deleting all animal histories.
2. **Episode matching**: 17 linked field/PM source pairs represent **one** biological episode per pair. No double death or additional recapture occasion from PM companion.
3. **Encounter-fate ambiguity**: the core qualifying live definition excludes exceptional `FOUND_IN_EXTREMIS` and non-PM `REMOVAL` records, which need a distinct explicit alive/terminal coding. It also excludes `UNKNOWN` outcome until checked. An apparent routine trap and presumed release is a documented assumption, not directly observed survival.
4. **Entry/age and observation time**: preserve exact capture dates, annual/quarterly effort opportunities, age-at-first capture and chronological age uncertainty. There are 52 source calendar years (1975--2026), including 12 qualifying live encounters before 1977 and 43 in 2026; the previous movement model's year windows may differ. The 2026 year may be incomplete and cannot automatically be treated as fully observed.
5. **Detection/effort and disappearances**: stopping observed encounters does not prove death or emigration. Design a robust-design/annual detection component accounting for quarterly occasions, nonuniform effort, outside area/unavailability and late-life observation censoring. Do not claim identifiability of true emigration or immigration without external evidence.
6. **V11R2 input compatibility**: the frozen 1,932-animal movement population was derived from **local historic RDS and `WoodchesterSettLocations.csv`**, not direct live Supabase views. Model code on `main` uses aliases including `FOXCUB -> FOX`, `DINGLEVALLEY -> DINGLE`, `BLACKBERRY -> BRAMBLE`, which cannot be assumed biologically interchangeable or source-verified. Compare original detector/capture rows, dates, source sett names, canonical sett IDs, XY, eligibility and population/tattoo IDs against the audited live database **before deciding whether V11R2 needs a rerun**. Original model posterior files are not tracked by Git. The 3,224 live-observed animals and 1,932 previously movement-eligible animals are different populations by design; the difference **is not a demonstrated poor-data exclusion** until membership is reconciled.

### Missing field-team sett XY: exact refit decision

The recent GIS/PM grid audits primarily revised *recovery* evidence, which was deliberately excluded from V11R2 spatial likelihood; those changes alone do not require a movement refit. Field-team coordinates for previously unmapped **live-capture setts** may, however, add 306 source observations for 162 animals, and thus may alter movement state histories and detector geometry. These are upper bounds on possible effect: actual V11R2-population overlap, prior legacy CSV coverage and detection eligibility are unverified. **Do not refit automatically**; first run an old-vs-new capture-ID/date/sett/XY reconciliation. If newly mapped records alter meaningful observed locations or movement histories, rerun V11R2-50 and 25m sensitivity with harmonised vetted aliases and refreeze its posterior before using V12. If only PM/locality coordinates changed, retain V11R2.

### V12 staged development gate

- **V12a:** construct one *versioned, fully audited* animal-year and quarterly encounter/fate dataset (mark/release, live recaptures, PM/death, no observation, field/PM linked episodes, first/last seen, sex, age, optional location). Produce a complete inclusion and exclusion **reason** table at record and individual levels; no implicit dropping of missing XY or one-capture animals. Distinguish source-record, biological-episode and animal-year grains.
- **V12b:** start with identifiable annual apparent survival + quarterly detection, with deaths as separate known-death evidence where valid. Estimate age, sex and temporal effects. Check posterior predictive recapture counts, time-to-last-observation and documented death histories; don't automatically identify death vs permanent emigration from missing recaptures.
- **V12c:** propagate V11R2 relocation posterior uncertainty, not binary high-mover calls, as lagged survival/disappearance predictors; carry the 25m sensitivity, avoid reusing future observation data to define predictors. Add residence/settlement and possible immigration/emigration only when data support the extra latent states.
- **V13 follows V12**, targeting infectiousness, introduction/reseeding and persistence across the changing social landscape; do not repeat generic earlier infection/movement associations without a new estimand.

**Reproducible legacy-vs-audited input check:** \`scripts/data_audits/WECS_V12_compare_V11R2_legacy_to_Supabase.R\` is read-only, uses the existing BADGER_DB_* connection, and writes capture-date mismatch and unmapped-live reports to \`outputs/v12_input_audit/\`. It must run on the RStudio server where original V11R2 input RDS/sett CSV files exist. It screens tattoo/date/sett changes, and **cannot assert precise row identity on repeated same-day captures** without manual capture-ID reconciliation. Do not treat generated CSVs as approved data changes.\n\n**Single-authoritative-document policy:** This file is the living modelling record. Earlier files `docs/archive/model_development/Woodchester_Formal_Model_Overview_UPDATED.md`, `docs/archive/model_development/Woodchester_Badger_Project_Live_Modelling_Roadmap.md`, `docs/archive/model_development/V11_AGE_BADGER_RE_SPEC.md`, `docs/V10...` and `docs/archive/model_development/PREVIOUS_MODEL_HISTORY.md` remain historical context or specialist annotations. Do not create another competing modelling roadmap. The separate four canonical database documents still govern the cleaned data and curation decisions. Maintain this modelling record and the executable V12 audit alongside any future code changes.


### 5 November 2026 — final missing-live-location and legacy-alias audit

**READ ONLY; no Supabase data/coordinates changed.** Of the 538 accepted-live encounters missing XY, 306 are canonical named sett records awaiting field-team coordinates, while the remaining **232** break down into **161 named non-sett site observations**, **52 associated-sett records whose actual encounter location is elsewhere**, and **19 unspecified-location observations**. The 232 are not uniformly "missing sett XY" and cannot all be fixed by assigning a sett centre. The 232-row record-level field-review CSV and 58-name source SETT-labelled dates/methods list are stored separately on branch `audit-tattoo-identifier` under `outputs/spatial_location_audit/`; no automatic corrections were applied. The preexisting source alias `S PEGLARS -> SOUTH PEGLARS` is already documented and accepted, distinct from `PEGLARS`.

**Historical V11R2 alias warning (13 mapping rules):** `BLACKBERRY -> BRAMBLE` and `GRAVEL -> GRAVEL PIT` would merge **separate canonical sett IDs** and must not be carried forward into V12, detector mapping, or any V11R2 refit without explicit historical evidence of true equivalence. `FOXCUB -> FOX` and `DINGLEVALLEY -> DINGLE` are unresolved biological location identities, not safe name-only replacements. Other historical target strings (`CHESNUT`, `JACKSMIREY`, `GULLY`, `CLIFFFACE`) are legacy coordinate-file spellings and should be replaced by canonical sett IDs, not treated as additional setts. The audit CSV `WECS_V11R2_legacy_sett_aliases_safety_review.csv` lists all 13 rules with affected source-record counts and review decisions. Always distinguish a nominal associated sett from the actual trap/boundary/field position.

**Modelling consequence:** do not delay V12 apparent survival merely to fill 232 nonsett XY gaps. The next scientific gate remains original V11R2 input cross-check vs current live captures. Historical alias conflicts are a potentially more important reason to scrutinise the previous movement likelihood than PM grid correction. Field-team coordinates and confirmed aliases should be incorporated in a versioned sensitivity comparison before any movement refit.


### 6 November 2026 — decision: Supabase-first input provenance (IMPLEMENTED IN CODE; NOT YET TESTED ON RSTUDIO)

Historical local RDS versions have inconsistent season summaries, sett names and disease categories. The team decided not to reconcile these files into another local 'master'. Future active analyses must read approved, cleaned Supabase views through versioned shared R extraction, freeze the exact per-run source evidence (Git revision, database migration version where readable, SHA-256 checksums), and derive model-specific inputs with explicit reviewed rules. The original Access raw data remains unmodified; earlier RDS and fitting scripts remain historical reproducibility material, not current V12 inputs.

Initial code on feature branch: `scripts/database/freeze_woodchester_v12_inputs.R`. It reads classified encounters and reviewed mortality candidates without writing to Supabase, and saves untracked run evidence. **Not yet executed or validated on RStudio**; no model fitted. Next: verify counts and classification flags against the V12 SQL eligibility audit, review problematic deaths/episodes, develop explicit survival observation histories, and separately audit V11R2 original cohort and spatial eligibility before refitting.


### 6 November 2026 — V12.0 investigator decisions: observation coverage and age (DECIDED/PROPOSED; NOT YET FITTED)

**Evidence:** Read-only snapshot \`v12_20261106T103144Z_1079872\` (migration \`20261105150851\`, Git \`68f2028\`). Extracted 17,586 unique capture rows; 16,273 qualifying live encounters for 3,224 tattoos; 14,963 observed tattoo-calendar-quarters; 1,310 additional encounters within observed quarters; 1,300 candidate mortality events, four held terminal events; 538 qualifying live encounters without approved XY retained. Death chronology: 733 candidates with a qualifying same-day/earlier live record, 567 without qualifying live evidence (498 UN, 69 other), zero candidate deaths with a later qualifying live record. These are descriptive checks, not model validation or population abundance.

**APPROVED age principle:** When age at first capture is ADULT, chronological age is unknown: do not assign a fictitious birth year, midpoint age or reconstruct age from calendar time. Age-at-first-capture classes: CUB 2,726, YEARLING 75, ADULT 422, UNKNOWN 1. An initial CUB/YEARLING class is not automatically an exact birth date; confirm field definitions and use appropriately coarse age information. First appearance as ADULT is not proof of immigration. Keep UNKNOWN/ADULT cases in demographic analyses using age-class or latent-age handling only if separately agreed.

**INVESTIGATOR-INFORMED trapping coverage hypothesis (APPROVED FOR AUDIT/SENSITIVITY, NOT AS OBSERVED EFFORT):** The trapped geographical area contracted over time and trap numbers declined; after routine sett/outlier trapping replaced earlier snare/net approaches, locations were mainly trapped at named setts or outliers. Candidate retrospective rule: a canonical trapping site with no live captures in two consecutive years, followed by no further live captures at that site, can be flagged as *likely no longer sampled*. Record last observed live-capture year, first and second empty year, evidence type, and the uncertainty of cessation date. A zero capture is NOT evidence of zero trapping, and this rule must not be made into a known zero detection probability without sensitivity checks and independent corroboration. Do not use PM-only recovery as evidence of active live trapping. Avoid falsely equating sett membership, nominal associated sett, capture site, and social group; first define canonical site IDs with safe aliases and distinguish location confidence. Identify the beginning of routine trap-based sampling from historical documentation before applying. Recent/right-edge two-year gaps and possible return to a site require separate treatment. Site-specific exclusion does not automatically censor all captures or the entire individual history.

**Temporal coverage:** Calendar-quarter counts from live encounters are evidence of observed encounters, not formal trapping effort. Zero-live quarters include 1981 Q1; 2020 Q2; 2022–2026 Q1; and incomplete 2026 Q4. Classify each year-quarter as confirmed sampled, likely sampled, uncertain or confirmed unsampled only when supporting information exists. Do not automatically encode every zero-live quarter as an individual non-detection with ordinary detection probability. The 2026 dataset currently ends 11 August 2026; censor appropriately for incomplete follow-up; test alternative fit windows (e.g. through 2025). 1976–1981 sparse coverage merits sensitivity assessment.

**Priority next step (PLANNED):** Construct read-only site-by-year and quarter-by-year coverage diagnostics using centrally classified live events, canonical source IDs, recorded location quality and encounter methods. Report candidate last-active site years and sites with subsequent reappearance; distinguish zero known captures from verified zero trapping. Design V12A apparent survival and detection with time-varying observation opportunities and clearly specified availability/temporary absence assumptions. Compare no-site-effort-correction, two-year inferred inactivity and stricter independently corroborated inactivity alternatives. Evaluate impact on survival and movement association. Do not retroactively revise V11R2 or alter Supabase solely to encode this model assumption.


### 6 November 2026 — V12 decision update: DEFER inferred sett-retirement effort correction

**Investigator decision:** Do NOT implement the proposed two-consecutive-years-without-captures / no-later-reappearance rule as an effort or detector-retirement assumption in V12 at this stage. Field-team clarification is needed about how trapping locations and effort were chosen, reduced and discontinued historically. The observed fall in captures or in setts with captures does not prove that traps were absent. Preserve the prior sett-coverage audit only as exploratory evidence, not an approved trap-effort time series. Do not retroactively change V11 models on this basis.

**Current working assumption:** Trapping effort is not measured; use actual qualifying live encounter occasions and explicit available metadata without fabricating effort, trap deployment or site retirement. Preserve repeated same-quarter encounters for detection/movement diagnostics, and classify quarters with no captures as *effort unknown* rather than verified no sampling. Baseline V12 should test temporal variation in detection and be interpreted as apparent survival/retention where relevant; substantial time-varying availability and spatial footprint uncertainty remain a limitation. Sensitivity to study windows and late sparse sampling must be assessed. If field team provides historical effort evidence, reconsider in a documented future decision.

**Other decisions retained:** First captured as ADULT means actual chronological age unknown; do not reconstruct birth year/precise age. Animals without accepted XY remain eligible for nonspatial survival evidence. Death-only recoveries stay distinct from the live-marked cohort pending an explicit likelihood for recoveries. Four held mortality records remain held. Next: audit observation occasions, data eligibility and candidate death events and specify initial V12 conditional encounter/survival likelihood before fitting.


### 6 November 2026 — V12A fitted baseline and cull/decline historical context

**Observed V12A fitting output from the frozen Supabase snapshot, conditional CJS MLE for 1976–2025 (3,214 live-observed tattoos; 14,921 observed tattoo quarters; 940 only once):** V12A-0 constant quarterly apparent survival with quarter-specific p: convergence=TRUE, logLik -24996 (rounded), AIC 50002, phi_quarter=0.90490, phi_year_equivalent=0.67050. V12A-1 adds p differences for 1976–81 and 2016–25: convergence=TRUE, logLik -24777 (rounded), AIC 49567, phi_quarter=0.90559, phi_year_equivalent=0.67256. V12A-1 p by Q1/Q2/Q3/Q4: 1976–81 0.056/0.118/0.196/0.100; 1982–2015 0.241/0.417/0.567/0.374; 2016–25 0.231/0.404/0.553/0.361. These are preliminary constant-survival conditional CJS apparent-survival benchmarks, NOT accepted biological survival estimates; time-constant survival, sparse/inactive quarters, changing footprint, conditional time-boundary identification, and no recovery likelihood limit interpretation.

**Investigator-supplied history:** Badger population decline was already occurring before the cull started in **2018**. Culling potentially adds mortality and impacts availability; it must not be presumed the cause of an already existing trend, or treated as a simple unconfounded before/after experiment. Record 2018 as investigator-reported start date pending verification of study-area cull boundaries, implementation dates, intensity, population overlap, and whether culled animals have traceable tattoo/death/PM records. Differentiate known anthropogenic removal, unknown fate, true death and emigration; no silent recoding of alive-dead trajectories. Counts of live captures are not abundance estimates and are jointly affected by abundance, sampling extent and detectability.

**NEXT PHASE (proposed, not approved causal cull inference):** Keep V12A quick. Examine capture methods/outcomes and death recovery evidence for explicit culling/shot/removal observations and years; compare temporal CJS apparent-survival models allowing a *pre-2018 trend* and exploratory *2018-onward change*, with detection temporal structure and explicit discussion of confounding and sparse observations. Post-2018 parameter effects are descriptive associations only. Do not assume cull exposure is homogeneous across all badgers or setts. Do not fabricate trapping effort or implement sett retirement. Keep confirmed known deaths and held ambiguous deaths separate pending recovery likelihood. Prioritise spatial movement-demography analysis and defer updated diagnostic-infection survival reanalyses (Hudson et al. 2019 Diversity; Hudson et al. 2023 JAE) until V12A baseline is running.


### 6 November 2026 — investigator clarifies integrated V12/V13 biological goals

**Scientific objective:** Infer badger age-specific mortality and survival, immigration, emigration, recruitment/settlement and spatial movement, and assess how these demographic processes interact with infection acquisition, progression and infectiousness. The movement–demography–infection links are the major research objectives, not repeated fitting of simple CJS survival curves. Develop modular stages with a route to joint inference; do not equate first capture with immigration, permanent non-detection with death, or low apparent survival with true mortality. Explicitly acknowledge that independently identifying death versus emigration may be impossible for some individuals without recovery/outside-area evidence.

**Seasonal interpretation:** Investigator highlights reduced badger activity in Q1; Q1's low detection must be considered as potentially behavioural availability as well as trap deployment/effort, not evidence of low quarterly survival. Seasonal p must be included/tested in baseline, while periods with no captures have unknown effort unless externally verified.

**Agreed sequencing:** Finish V12A quickly as a diagnostic CJS benchmark; V12B address age-specific mortality/survival and candidate known-death/recovery likelihood; V12C investigate immigrant/recruitment, temporary/permanent emigration, relocation and settlement with existing V11R movement evidence; V12D combine demographic movement states and time-varying infection from the centrally curated diagnostic data, with appropriate uncertainty; V13 extend to transmission/persistence. These are modular development phases, not necessarily separate publications. Keep cull starting 2018 and already-declining population as context/confounding rather than an assumed causal step. Adult-first capture means unknown chronological age, never assign constructed birth dates; known cub/yearling age classes require validated timing. All decision changes and exclusions require documented scientific sign-off and sensitivity checks.

**Prior publications earmarked for later replication/reanalysis:** Hudson et al. (2019) 'Analysis of Lifetime Mortality Trajectories in Wildlife Disease Research: BaSTA and Beyond' (Diversity); Hudson et al. (2023) 'Multi-locus homozygosity promotes actuarial senescence in a wild mammal' (Journal of Animal Ecology). Reproduce their source inclusion and infection definitions separately, then evaluate centrally curated time-varying infection classifications, avoiding immortal-time bias from a lifetime 'ever positive' grouping. Do not delay baseline V12A to undertake these reanalyses.


### 6 November 2026 — correction: age-specific mortality modelling is previously published, not an independent new V12B goal

**Investigator correction:** Hudson et al. (2019, Diversity) already fitted age-specific mortality trajectories using BaSTA and evaluated sex/infection effects; Hudson et al. (2023, Journal of Animal Ecology) already developed bespoke NIMBLE joint survival–recapture Gompertz–Makeham models, including sex, infection, multilocus homozygosity, social group and Bayesian model selection. Do **not** characterise fitting another age-specific survival model or rediscovering senescence as a novel V12B research question. Existing model structure, published estimates and methodological experience are the baseline scientific evidence.

**Revised active priorities:** (i) complete only a short V12A cleaned-Supabase CJS survival/detection benchmark, (ii) pursue genuinely new entry/immigration, settlement, disappearance/emigration and their identifiability, (iii) integrate V11 movement and geographic relocation to test demographic consequences and mechanisms, and (iv) add time-varying infection/diagnostic uncertainty and mortality information in joint demographic–movement modelling. Replication of 2019/2023 mortality analyses using newly curated Supabase infection categories is a **separate planned reanalysis** after V12A works, not a mandatory new stand-alone modelling stage. Future model labels V12B/C/D are provisional until code and scientific scope are agreed. Preserve the investigator-approved unknown-chronological-age handling for first-adult captures.

---

## 9 November 2026 — V12I-03b synthetic spatial validation and planned V12I-04 demography

**Status:** PLANNED / CODE COMMITTED, NOT EXECUTED OR VALIDATED on RStudio.

**Question/hypotheses:** Can a quarterly spatial observation likelihood recover true annual activity centres and baseline detection under independently simulated histories? Does independent-chain inference converge and remain calibrated across simulated datasets? Subsequently, can a latent alive/dead model identify survival separately from quarterly detection?

**Source/version:** Synthetic badger encounters, initial positions and outcomes generated by code. Eight detector XY positions from the archived V11R2 RES50 local RDS are used as spatial *context*, not as authoritative real-data capture histories. Current V11R2 coordinates and aliases require reconciliation against read-only frozen Supabase data before scientific inference. No real Woodchester encounters enter these smoke/validation likelihoods.

**Inclusion/exclusion:** V12I-03b defaults to 10 synthetic animals, 4 years and 4 quarterly detector occasions per year. The matched-prior simulation draws initial activity centres uniformly from the same bounds as the fit's initial-location prior; an older sett-spawn distribution is retained as an explicit mismatch sensitivity. No immigration, actual mortality or demographic state fitting is performed in 03b. V12I-04 is a separate nonspatial synthetic cohort alive initially, annual survival and quarterly capture; its entry times are known. No real animal excluded.

**Executable code / settings:**
- `scripts/ModularFitting/Woodchester_V12I_03_NIMBLE_Spatial_Smoke.R` — now supports `V12I_DATA_SEED`, independent `V12I_SEED`, `V12I_MATCHED_PRIOR=1`, and unique `V12I_OUT`.
- `scripts/ModularFitting/launch_V12I_03b_tmux.sh` — safely creates unique run directory and separate tmux sessions, bounded concurrency (`V12I_MAX_PARALLEL=3` by default), refuses to overwrite a run identifier; preserves each chain's logs, samples, seed and exit status.
- `scripts/ModularFitting/Woodchester_V12I_03c_Summarise_Parallel.R` — reads completed outputs without refitting. Per replicate calculates R-hat, bulk/tail ESS, p0 posterior coverage, and location recovery from *pooled* posterior draws.
- `scripts/ModularFitting/Woodchester_V12I_03b_Validate.R` — previous sequential validation script, **not** the tmux runner.
- `scripts/ModularFitting/Woodchester_V12I_04_Survival_Detection_Smoke.R` — separate survival/detection developmental model, still unexecuted.

**Run command (from `~/Badgers_SpatialPostDoc`):**

```bash
git status --short --branch
git pull --ff-only
V12I_REPS=3 V12I_CHAINS=3 V12I_MAX_PARALLEL=3 \
  V12I_NITER=12000 V12I_NBURN=4000 \
  bash scripts/ModularFitting/launch_V12I_03b_tmux.sh
```

**Model assumptions / limits:** The spatial test fixes survival, demographic entry, annual movement scale and spatial detection decay, while sampling p0 and individual annual latent coordinates. Initial uniform activity-centre prior and random-walk location transitions are simplified synthetic assumptions; detector-specific effort remains absent. Actual trapping availability is unknown historically. V12I-04 fixes entry, is nonspatial and estimates phi and p0. Neither is a validated joint open-population model.

**Numerical evidence so far:** Earlier V12I-03 single-chain exploratory smoke (10 animals; 4 years; 136 live encounter indicators) reported p0 posterior mean 0.469 (95% interval 0.391–0.562) versus simulated 0.42, and median annual location error 76.9 m. It was a single synthetic dataset and does not establish convergence. **No V12I-03b parallel validation or V12I-04 new fitting results are yet available.**

**Validation gate:** Review three-chain diagnostics (rank-normalised Rhat under 1.01 and bulk/tail ESS above 400 for essential parameters, coupled with traces), parameter bias/coverage across genuinely independently simulated datasets, uncertainty and spatial recovery under low detection. These thresholds are guides, not guarantees. Test sensitivity to sett-prior mismatch and historical detector geometry. Repeat simulations beyond three replicates before making robust coverage claims.

**Decision:** Run bounded parallel V12I-03b validation and analyse before treating spatial location inference as verified. Proceed to joint survival+spatial detection, latent entry, high-mobility state, mortality-recovery process and possible immigration/emigration separation in small stages. Distinguish immigration vs local recruitment and permanent emigration vs death as identifiable only with auxiliary evidence and explicit assumptions. Prior V11 movement inference must not be double-counted as both a fixed input and likelihood evidence. Historical V11R2 RDS is for contextual geometry only; future real-data V12 analyses require audited Supabase-first frozen extracts.

**Data safeguards:** Do not modify Supabase source tables or assign UN badgers social groups. Preserve original capture and mortality evidence, associated sett vs recovery coordinates, unresolved identity conflicts and location quality. Preserve local RStudio outputs and do not commit large RDS or credentials.

**Documentation correction:** The previously created `docs/V12I_BAYESIAN_DEMOGRAPHIC_ROADMAP.md` was a competing live document. On 9 November it was archived at `docs/archive/model_development/V12I_BAYESIAN_DEMOGRAPHIC_ROADMAP_20261109_SUPERSEDED.md`. This canonical document remains the only active scientific roadmap.


### 9 November 2026 — V12I-03b tmux execution and summariser repair

**Status:** PRELIMINARY (fit execution successful; statistical validation pending).

**Run:** `v12i03b_20261109T100318Z`, 3 synthetic datasets × 3 MCMC chains, 12,000 iterations and 4,000 burn-in per chain, maximum 3 simultaneous tmux sessions. User-reported run manifest shows 9 `exit_status.txt` files, all status 0. This establishes computational completion only; posterior diagnostics and recovery have not been examined.

**Issue:** Initial execution of `Woodchester_V12I_03c_Summarise_Parallel.R` halted while building the aggregate data.frame because the returned `posterior::summarise_draws` fields did not have the expected short names (`rhat`, `ess_bulk`, `ess_tail`). This is a summary implementation error, not evidence of fit failure. The same issue was corrected in the sequential script. The implementation now passes explicit named statistic functions and checks expected diagnostic columns. Saved chain-level fits are retained.

**Next:** `git pull --ff-only` after checking local status; rerun read-only summariser on the existing run directory, inspect p0 posterior recovery, worst Rhat across latent coordinates, bulk/tail ESS and location recovery before assigning VALIDATED status. No database inputs or outcomes changed.


### 9 November 2026 — V12I-03c summariser syntax hotfix

**Status: PRELIMINARY / summarisation BLOCKED pending rerun.** All nine synthetic NIMBLE chains for `v12i03b_20261109T100318Z` reportedly exited with code 0. A prior posterior-summary repair accidentally inserted literal `\\n` sequences outside quoted R strings, yielding `unexpected symbol` during R parse. This was a code-generation error, not a model failure. Both `Woodchester_V12I_03c_Summarise_Parallel.R` and the related sequential `Woodchester_V12I_03b_Validate.R` have been patched to use real source newlines. No fits, model inputs or saved chain outputs were changed. **Required gate:** run `Rscript -e 'parse(file="scripts/ModularFitting/Woodchester_V12I_03c_Summarise_Parallel.R")'` on RStudio, then rerun the read-only summariser and inspect its diagnostics before any biological interpretation.


### 9 November 2026 — V12I-03b multi-chain parameter and spatial recovery results

**Status:** PRELIMINARY; validation gates NOT yet passed.

**Scientific question:** Does the synthetic spatial observation model recover latent annual centres and known baseline detection (`p0=0.42`) with multiple independent chains, and do diagnostics support reliable inference?

**Input/version & sample:** three independently simulated datasets, each 10 individuals × 4 annual states × four quarterly occasions × 8 detectors using historic V11R2 RES50 XY solely for geographical context; no real encounter likelihood. Run `outputs/v12_immigration_prototype/v12i03_validation/v12i03b_20261109T100318Z/`, 3 independent chains per dataset; 12,000 iterations, 4,000 burn-in, 8,000 retained per chain; initial locations simulated with fitting-matched uniform prior. All 9 fits reportedly returned exit code 0.

**User-reported numerical results** (`Woodchester_V12I_03c_Summarise_Parallel.R`):
- Dataset 1: 99 live detection indicators; p0 mean 0.390647, 95% posterior interval 0.300790–0.499703, p0 Rhat 1.003269, bulk ESS 804.6, tail ESS 1910.9; worst monitored-node Rhat 1.028223, lowest bulk ESS 128.37; median/max annual position error 121.23/863.67 m.
- Dataset 2: 99 indicators; p0 mean 0.534272, interval 0.413178–0.674721; p0 Rhat 1.007532, bulk ESS 902.1, tail ESS 1929.8; worst Rhat 1.030602, minimum bulk ESS 90.84; median/max position error 76.66/343.20 m.
- Dataset 3: 125 indicators; p0 mean 0.510589, interval 0.413236–0.617134; p0 Rhat 1.002792, bulk ESS 1001.7, tail ESS 2046.7; worst Rhat 1.036104, minimum bulk ESS 107.27; median/max position error 92.21/242.38 m.
- All 3 nominal 95% credible intervals contain simulated true p0 0.42. Three replicates cannot establish credible-interval coverage or systematic bias.

**Interpretation:** Overall p0 mixing is acceptable in these runs (Rhat <1.01, bulk and tail ESS >400), but multiple latent spatial coordinates fail the provisional diagnostic targets (worst Rhat 1.028–1.036, minimum bulk ESS 91–128). The large position error could arise from sparse encounter information, genuine location ambiguity or under-mixing; must distinguish using animal-year capture counts, spatial monitor diagnostics and posterior uncertainty. The model is not yet statistically validated. This test did not estimate survival, immigration or emigration, and cannot establish their identifiability.

**Decision:** Continue staged model development without claiming V12I-03b validated. First examine worst coordinate/animal-year diagnostics from existing outputs, checking how position error varies with observed quarters and detector encounters and diagnosing latent-location mixing. Next run independent V12I-04 synthetic survival+quarterly detection smoke, then implement joint spatial survival-detection while retaining a simulation-based validation gate. Do not refit historical V11R2 or fit real data until approved Supabase-first encounter/fate reconciliation. Preserve all previous outputs.

**Next model-development dependencies:** Check latent coordinates rather than only p0, sensitivity to detector geometry and initial state assumptions, repeat simulated datasets to assess calibration, model-specific selection of clean live encounters and reviewed terminal death episodes, and explicitly separate apparent survival from true mortality/emigration absent external evidence.


### 9 November 2026 — V12I-03b individual spatial diagnostic review

**Status: PRELIMINARY; spatial validation criterion not met.** User executed existing read-only reports for run `v12i03b_20261109T100318Z`; no new fitting or database changes.

**Hypothesis under review:** Sparse detections and/or difficult latent-coordinate sampling drive poor activity-centre recovery, potentially limiting future survival-versus-emigration discrimination.

**Dataset 1:** Badger 7 annual posterior-mean position errors: year 1 723.87 m (undetected), year 2 705.14 m (detected), year 3 724.94 m (undetected), year 4 863.67 m (undetected). Its annual coordinate nodes include worst Rhat 1.0282 and bulk ESS as low as 128.4, tail ESS as low as ~66.8. For all badger-years: 7 not detected (median error 268.5 m) versus 33 detected (median 97.6 m). A single detected year does not guarantee location identifiability.

**Dataset 2:** Badgers 5 and 8 account for most of the highest Rhat nodes (up to 1.0306) and weak ESS (as low as 90.8). Largest position error is badger 1 year 1, 343.2 m, with no detection. Five unobserved years had median error 87.0 m versus 35 observed years median 76.6 m. Thus worst mixing nodes are not necessarily the worst error nodes.

**Dataset 3:** Badger 4 coordinates have the weakest convergence (Rhat up to 1.0361, bulk ESS 107.3). All 40 badger-years have at least one detection, so sparse *annual presence* alone cannot explain poor mixing. Worst position error is badger 8 year 4, 242.4 m; this further separates sampler mixing from estimation error.

**Interpretation and limitation:** These are known-truth synthetic datasets with fixed survival/entry and fixed movement/detection scales. Poor latent-coordinate mixing and high spatial error must be distinguished from genuinely weak location information. Need capture counts by detector/quarter, true distance to trapping network, posterior location uncertainty and chain-specific traces for these animals. No evidence yet that death versus emigration can be separated by a joint model.

**Decision/next action:** Retain V12I-03b status PRELIMINARY, no further blind iteration increases. Diagnose badger 7 in replicate 1, badgers 5 and 8 in replicate 2 and badger 4 in replicate 3. In parallel, test the independent V12I-04 synthetic survival–detection model, and only then develop a staged joint spatial-demographic model. Current historic V11R2 detector geometry is contextual only; Supabase-first data and V11R2 input reconciliation are required before fitting to actual Woodchester records.


### 9 November 2026 — V12I-04 survival/detection smoke and V12I-03b detector-distance review

**Status:** PRELIMINARY. Synthetic model execution successful; convergence and repeated parameter recovery not yet validated.

**Scientific questions:** Can a simple Bayesian latent alive/dead state process jointly estimate annual survival and baseline quarterly detection? Are large spatial errors concentrated among badgers distant from spatial detectors and rarely caught?

**Input/data:** Synthetic V12I-04 model: 40 simulated badgers, 6 annual states, 4 quarterly Bernoulli occasions per year; all animals initially present, no entry/migration or spatial detection, fixed seasonal multipliers; 198 positive capture indicators. Generated truth annual survival `phi=0.82`, baseline observation `p0=0.42`. No Woodchester records used in the likelihood. The separate V12I-03b spatial assessment uses saved 3 replicated synthetic datasets and 8 historical V11R2 detector XY positions as geographical context only.

**Script/run:** `scripts/ModularFitting/Woodchester_V12I_04_Survival_Detection_Smoke.R`, `V12I_NITER=12000 V12I_NBURN=4000`, one NIMBLE chain. Saved fit to `outputs/v12_immigration_prototype/v12i04_survival_detection/` and log to `outputs_v12i04_survival_detection.log`. User reports exit status 0. V12I-03b detector-distance investigation calculated distances from simulated true activity centres to nearest contextual detector and summed simulated detector-specific captures per badger-year; no refitting.

**Results:** `phi` posterior mean 0.834, 95% credible interval 0.765–0.893 (truth 0.82); `p0` posterior mean 0.423, interval 0.372–0.471 (truth 0.42). Encouraging one-run recovery, **not** evidence of repeated parameter recovery or adequate MCMC mixing.

**Spatial case details:** V12I-03b dataset 1 badger 7 years 1–4 respectively had 0,1,0,0 detections and nearest-detector distances 332.1,284.8,325.5,426.7 m; earlier posterior location errors 723.9,705.1,724.9,863.7 m. Dataset 2 badger 5 detections 3,1,0,1 at 147.8,257.9,234.6,292.7 m; badger 8 detections 2,1,0,0 at 243.5,327.2,268.5,326.2 m. Dataset 3 badger 4 detections 1,1,1,2 at 192.3,215.1,200.4,218.6 m, with previous poor spatial coordinate mixing. These results suggest sparse spatial information contributes to difficult recovery, but do not distinguish weak identifiability from inadequate MCMC exploration.

**Limitations:** Single chain for V12I-04; no Rhat, joint ESS assessment, PPC or independent replication. V12I-03b location uncertainty is confounded with detector coverage, fixed detection scale, and random-walk assumptions; location-error summaries alone cannot establish emigration identifiability. V12I-04 NIMBLE's 'not fully initialized' note did not prevent a successful fit but warrants checking latent-state initialization if numerical warnings arise.

**Decision:** Keep both models PRELIMINARY. Next validate V12I-04 across independent chains/replicated datasets, investigate V12I-03b posterior location uncertainty and mixing, and develop a joint spatial alive-state model only with explicit parameter-recovery gates. Continue toward open-population entry and possible immigration/emigration separation; do not conflate last capture with death. All future Woodchester fitting requires Supabase-first approved data and outstanding V11R2 input reconciliation.


### 9 November 2026 — Progression to multi-chain demographic validation and joint spatial survival

**Status:** PLANNED / CODE COMMITTED, NOT YET EXECUTED for V12I-04b and V12I-05.

**Scientific question/hypotheses:** Can joint annual latent survival and quarterly capture probability be recovered from incomplete encounters across independent synthetic datasets? When spatially dependent observation is added, can posterior inference simultaneously recover annual survival, baseline detection and latent activity-centre trajectories? Only once stable should we add population entry and explore immigrant vs locally recruited classes and emigration versus death.

**Input/version:** Synthetic data only, no real encounter or death histories in these likelihoods. V12I-05 uses historical V11R2 RES50 detector coordinates solely to supply a realistic small geographical layout; these coordinates are *not* an audited current detector data source. Synthetic population initially N=12, T=4 years, 4 quarters, 8 detectors; annual true phi 0.82 and p0 0.42, fixed spatial movement SD 60 m and detection scale 170 m. Initial positions uniform over detector range ±150 m, matching the fitting prior; alive at first year with no later entry; captures condition on alive status and distance. In V12I-04b synthetic cohort N=40 and T=6 years with 4 quarterly occasions, fixed seasonal multipliers, no spatial process. No UN social group assignment, no real data exclusion.

**Scripts and reproducibility:**
- `scripts/ModularFitting/Woodchester_V12I_04_Survival_Detection_Smoke.R` now supports independent `V12I_DATA_SEED` and `V12I_SEED` for same data across independent chains.
- `scripts/ModularFitting/Woodchester_V12I_04b_Validate_Multichain.R`: sequential validation of 3 independently simulated datasets × 3 chains; rank-normalised Rhat and bulk/tail ESS via posterior, posterior-interval recovery for phi/p0; output to required NEW `V12I_OUT` path, never overwrite historical outputs.
- `scripts/ModularFitting/Woodchester_V12I_05_Joint_Spatial_Survival_Smoke.R`: developmental joint NIMBLE state-space model. Latent annual survival z and activity centre S, distance-based quarterly detection, estimates phi and p0 with fixed movement and detection scales; known initial entry and survival state, no immigration/emigration or death recovery. Requires NEW `V12I_OUT` directory. Code not yet tested on server.

**Suggested first runs** (after `git status --short --branch`, `git pull --ff-only`, and parse checks):
```bash
V12I_REPS=3 V12I_CHAINS=3 V12I_NITER=12000 V12I_NBURN=4000 \
  V12I_OUT="outputs/v12_immigration_prototype/v12i04b_$(date -u +%Y%m%dT%H%M%SZ)" \
  Rscript scripts/ModularFitting/Woodchester_V12I_04b_Validate_Multichain.R

V12I_OUT="outputs/v12_immigration_prototype/v12i05_smoke_$(date -u +%Y%m%dT%H%M%SZ)" \
  V12I_NITER=1200 V12I_NBURN=600 \
  Rscript scripts/ModularFitting/Woodchester_V12I_05_Joint_Spatial_Survival_Smoke.R
```

**Convergence/PPC:** No new outputs or diagnostics presently exist. Inspect fitted versus simulated phi, p0, missing-capture patterns, survival-state recovery and latent spatial coordinate mixing, and increase independent simulations after basic computational smoke passes. Prior spatial model V12I-03b showed under-mixed coordinate nodes; this cannot be assumed solved by adding survival.

**How the Woodchester data will inform the analysis:** A prior V12I-02c snapshot audit found 3,214 observed tattoos and 16,230 live capture-days over approximately 1976–2025; definitions differ from the annual resident-group and model-eligible subsets. Earlier audited quarterly summaries found 8,618 observed badger-years and 14,921 observed badger-quarter indicators in the specified snapshot. These are descriptive counts, not automatically the model population size, true annual survival denominator, or independently observed trapping effort. Real-data model fitting requires approved read-only Supabase freeze, explicit animal/encounter eligibility and episode de-duplication, audited alive/fate classification, spatial-provenance filtering, temporal effort proxies, and reconciliation of V11R2 legacy inputs with curated data before inference. Temporal coverage is sufficiently long that calendar period, season and demographic age dependence must be considered, but cannot be estimated indiscriminately without attention to effort and selection. Use staged fitting on biologically defined cohorts, then scale to full eligible histories rather than fitting the entire historical panel in the first smoke run.

**Limitations/decision:** These synthetic experiments test code mechanics and parameter identifiability under selected assumptions, NOT whether true immigration and emigration can be distinguished from local recruitment and death using real data. Initial full model should report apparent survival/retention unless recovery information and spatial design provide identification. Continue gated joint development without re-starting V10B or replacing V11R2 outputs. No database changes.


### 9 November 2026 — V12I-05 first joint spatial survival-detection smoke

**Status: PRELIMINARY / computational smoke PASSED; statistical validation not established.**

**Question:** Can NIMBLE jointly sample latent annual alive states and annual activity centres with four quarterly spatial observation occasions, using simulated known survival and capture probabilities?

**Model & input:** `scripts/ModularFitting/Woodchester_V12I_05_Joint_Spatial_Survival_Smoke.R`; synthetic N=12, T=4 annual states, Q=4 quarterly occasions, J=8 contextual V11R2 RES50 detector coordinates. No real Woodchester encounter data enter the likelihood. All 12 individuals are alive at first occasion, with no population entry. True annual survival phi=0.82 and baseline detection p0=0.42. Annual movement SD fixed at 60 m; detector-distance kernel scale fixed at 170 m; fixed illustrative seasonal multipliers. Initial synthetic locations match the fitted uniform initial-location prior. NIMBLE MCMC 1200 iterations, 600 burn-in, 1 chain, stored in unique path `outputs/v12_immigration_prototype/v12i05_smoke_20261109T102520Z`.

**User-reported results:** 130 positive encounter indicators; 6 animals dead by final simulated year. NIMBLE compiled, sampled and returned exit status 0. Phi posterior mean 0.759 (95% interval 0.598–0.878) versus true 0.82; p0 mean 0.472 (interval 0.390–0.573) versus true 0.42. Both intervals contain truth, though the short chain and small dataset provide no demonstrated convergence, calibration, location/state recovery, or identifiability.

**Decision:** The computational joint-likelihood smoke gate passes, but the scientific/statistical validation gate remains OPEN. Validate the simpler V12I-04 survival–detection likelihood across independent chains and datasets, then V12I-05 with independent chains, location/state mixing checks and posterior predictive comparisons. Avoid treating the simulated 12-individual model as equivalent to ~50-year Woodchester histories; candidate full-data scale previously audited as 3,214 observed tattoos and 16,230 live capture-days from a particular snapshot, and requires Supabase-first cohort eligibility, treatment of capture effort, death-episode and coordinate provenance, V11R2 source reconciliation, and careful long-term model structure. Do not claim immigration or emigration fitted at this stage.

**Next action:** Run V12I-04b multi-chain validation with a unique output directory after Git status review; diagnose phi/p0 mixing before scaling V12I-05. Preserve all prior results and source records.


### 9 November 2026 — V12I-04b multi-chain demographic validation complete; V12I-05b planned

**V12I-04b status: PRELIMINARY (multi-chain convergence and point/interval recovery criteria met for three synthetic replicates; full calibration/PPC outstanding).** User-run `Woodchester_V12I_04b_Validate_Multichain.R` used three synthetic datasets × three independent NIMBLE chains (12,000 iter/4,000 burn-in each), N=40 simulated animals × T=6 years × Q=4 quarters, known initial presence; phi truth 0.82, p0 truth 0.42, fixed seasonal detection multipliers, no spatial process, entry or emigration. Exit status 0.

**User-reported results (posterior mean, 95% interval, Rhat, bulk/tail ESS):**
- Rep 1 phi: 0.778148 (0.699466–0.850323), Rhat 1.000283, bulk ESS 4432, tail 5513. p0: 0.409924 (0.357077–0.465103), Rhat 1.001030, bulk 4377, tail 5109.
- Rep 2 phi: 0.790481 (0.715169–0.859338), Rhat 1.000535, bulk 4310, tail 5060. p0: 0.400355 (0.348107–0.453524), Rhat 1.000874, bulk 3854, tail 5559.
- Rep 3 phi: 0.846169 (0.781478–0.901415), Rhat 1.000867, bulk 4212, tail 5493. p0: 0.406006 (0.358158–0.455669), Rhat 1.000541, bulk 4472, tail 5443.
- Six of six nominal 95% intervals include known truth, but three replicates do NOT establish nominal coverage. Posterior mixing of monitored phi and p0 is excellent in this setting.

**Scientific decision:** Proceed to repeated multi-chain validation of V12I-05 joint spatial survival and detection, retaining the unresolved V12I-03b spatial-location mixing issues. Do not claim inference on emigration or true survival in real Woodchester populations from these synthetic tests.

**V12I-05b status: PLANNED / CODE COMMITTED, NOT EXECUTED.** `scripts/ModularFitting/launch_V12I_05b_tmux.sh` launches 3 synthetic datasets × 3 independent chains each, max 3 concurrent tmux sessions, with unique timestamped output directory and refusal to overwrite existing run IDs. `scripts/ModularFitting/Woodchester_V12I_05b_Validate.R` independently checks that chains in each replicate used identical synthetic encounters/latent true states/coordinates, aggregates `posterior` Rhat, bulk/tail ESS for phi/p0, saves full node diagnostics, and reports latent S and z mixing. The simulation uses N=12, T=4, Q=4, J=8 contextual detector points, fixed movement and detection scales and known entry.

**Suggested execution:**
```bash
git status --short --branch
git pull --ff-only
Rscript -e 'invisible(parse(file="scripts/ModularFitting/Woodchester_V12I_05b_Validate.R"));cat("Validation syntax OK\\n")'
V12I_REPS=3 V12I_CHAINS=3 V12I_MAX_PARALLEL=3 \
V12I_NITER=12000 V12I_NBURN=4000 \
bash scripts/ModularFitting/launch_V12I_05b_tmux.sh
```
After all nine chains exit 0, run the summariser command printed by the launcher. Assess spatial-node convergence, latent death-state Rhat issues (some z coordinates may have constant chains/undefined Rhat), marginal phi and p0 recovery and posterior predictive checks. No V12I-05b diagnostic outputs presently exist.

**Working-tree safeguard:** Immediately before this entry the user displayed a locally dirty `main` worktree: eight tracked CSV paths deleted under `docs/database/`, new `docs/database/csv/` directory, modified `scripts/WECS_39_remaining_grid_review.R`, and untracked `Woodchester_V12A_CJS_Baseline.R`, `Woodchester_V12_Movement_Recapture_Audit.R` and `Woodchester_V12_Spatial_Position_Audit.R`. `git pull --ff-only` succeeded without disturbing those changes. Do not assume these are redundant; audit/commit the CSV relocation and independent modelling work deliberately. Never reset/clean them.

**Real-data scale & dependencies:** Previous source audits identify thousands of tattoos and ~50 years of captures, but the entire historical population cannot be treated as an initially known capture cohort. Real-life entry, unknown pre-first-capture states, effort history, spatial boundary/sett quality, confirmed mortality with missing XY and selection bias must be addressed through reviewed Supabase-first snapshots before fitting V12 to Woodchester data. No real-data or database changes made here.


### 9 November 2026 — V12I-05b joint spatial/survival validation and focused follow-up

**Status:** PRELIMINARY; latent spatial-state validation FAILED; focused diagnostic PLANNED.

**Scientific question and hypothesis:** Does uncertainty in spatial capture location undermine estimation of annual survival and baseline detection? Are poorly mixing location nodes primarily from truly dead animal-years (where location is not observed) or from sparsely detected but alive animal-years? Synthetic truth is used only for diagnostic classification.

**Inputs and fitting:** `outputs/v12_immigration_prototype/v12i05_validation/v12i05b_20261109T103847Z`, 3 synthetic datasets × 3 chains, N=12 animals × T=4 years, Q=4 quarterly detection occasions, J=8 detectors for each replicate; 12,000 iterations/4,000 burn-in per chain. All initially alive; true annual phi=0.82, true baseline p0=0.42; movement SD=60 m and spatial detection scale=170 m fixed. No real Woodchester data likelihood, no birth/entry, immigration, permanent emigration or post-mortem observation.

**User-reported numerical findings** (posterior mean, 95% interval, Rhat, bulk ESS, tail ESS):
- Replicate 1: phi 0.70612 (0.51928–0.86540), 1.00065, 3461, 4480; p0 0.35769 (0.24465–0.50397), 1.00687, 493, 1202.
- Replicate 2: phi 0.63934 (0.44723–0.81370), 1.00123, 4026, 4809 — **nominal 95% CI excludes generating truth 0.82**; p0 0.45492 (0.33704–0.59827), 1.00255, 658, 1828.
- Replicate 3: phi 0.74769 (0.57736–0.88923), 1.00139, 3587, 4789; p0 0.39380 (0.28172–0.52946), 1.00473, 439, 1420.
- Spatial location nodes (96 per replicate) have worst Rhat 1.1091, 1.0489, 1.1583 and minimum bulk ESS 22.15, 90.80, 15.18, respectively: unsatisfactory spatial mixing. Survival-state nodes (48 per replicate) worst finite Rhat 1.00923, 1.00469, 1.01007 with 30, 27 and 32 undefined Rhat entries, consistent with many fixed/degenerate states; need classification.

**Interpretation:** Global phi and p0 MCMC convergence is promising; one of three survival credible intervals misses the truth and all point estimates are lower than the generating parameter. This alone cannot establish systematic bias. Latent spatial mixing clearly fails stated targets. The present model propagates S after death, with no capture likelihood for truly dead years; those locations may be weakly informed or largely prior-driven, but cannot be declared the sole cause without inspecting results. The model also conditions on known cohort entry and does not estimate emigration.

**Follow-up code:** `scripts/ModularFitting/Woodchester_V12I_05c_Inspect_State_Mixing.R` added as a read-only analysis of the existing saved posterior draws; for every simulated individual-year it computes true alive/dead category, posterior alive probability, number of detections, distance to nearest detector, location error and worst coordinate Rhat/min bulk ESS, and saves `animal_year_spatial_state_audit.csv` inside the existing validation directory. Run via:
```bash
V12I_VALIDATION_OUT="outputs/v12_immigration_prototype/v12i05_validation/v12i05b_20261109T103847Z" \
V12I_REPS=3 V12I_CHAINS=3 \
Rscript scripts/ModularFitting/Woodchester_V12I_05c_Inspect_State_Mixing.R
```

**Decision and next gate:** Diagnose alive versus dead location mixing first. If most problematic nodes concern post-death positions, consider removing or analytically marginalising their influence on the likelihood or redefining monitored quantities, while retaining a coherent state transition model; validate that any modification does not use simulation truth in the fit. If alive/observed states still mix poorly, inspect spatial MCMC samplers, posterior location intervals, detector geometry and conditional survival detection. Avoid arbitrary refitting with more iterations. Before real-data analysis: Supabase-first audited encounter/fate input, effort and spatial coordinate provenance checks and prior V11R2 input reconciliation. All outputs and prior decisions retained.


### 9 November 2026 — V12I-05c diagnostic results and V12I-05d uncertainty gate

**Status:** V12I-05c analysis COMPLETE / V12I-05b spatial model PRELIMINARY, NOT VALIDATED; V12I-05d CODE COMMITTED, NOT EXECUTED.

**Scientific hypothesis:** In the joint synthetic model, poorly mixing latent annual locations could be due to weak information after death, but the issue could also affect living badgers with low detection or inadequate spatial sampling. Assess both MCMC convergence and whether uncertainty regions contain true activity centres.

**Inputs/exclusions:** The unchanged V12I-05b output `outputs/v12_immigration_prototype/v12i05_validation/v12i05b_20261109T103847Z/`, 3 simulated datasets × 3 independent chains, N=12, T=4, J=8, 4 quarters; 144 simulated badger-years total. Synthetic true survival used *only* to stratify validation, never to initialise or fit. No Woodchester encounter or mortality data refitted. Read-only script `scripts/ModularFitting/Woodchester_V12I_05c_Inspect_State_Mixing.R`.

**User-reported evidence:** Truly alive animal-years n=94, median posterior-mean location error 113.2 m, worst Rhat 1.155 and minimum bulk ESS 15.2; truly dead n=50, median error 163.8 m, worst Rhat 1.158 and min ESS 15.2. Most problematic animal trajectory: replicate 3 animal 12, never detected, year 1 alive by assumption with year 1 location error 302 m and Rhat 1.155, subsequent dead years Rhat up to 1.158 and location errors 213–337 m; replicate 1 animal 8 likewise never detected throughout, year 1 alive by assumption and later dead. Replicate 3 animal 11 was truly alive and caught in all years (year 1 one detection, year 2 two, year 3 four, year 4 one); posterior-mean location error 348–412 m with relatively well-mixed location nodes (Rhat ~1.004–1.009, bulk ESS ~639–916). Some truly alive uncaught years had low posterior P(alive) (replicate 3 animal 8 years 3 and 4 P(alive) 0.027 and 0.010; replicate 1 animal 2 year 4 0.074). Such cases can result from observation non-identifiability, not necessarily a faulty alive-state sampler.

**Interpretation:** Dead years have worse median location recovery, but low ESS and high Rhat occur for both alive and dead cases; eliminating or excluding dead-year latent locations in diagnostics alone will NOT resolve poor mixing. Crucially, high location errors despite acceptable node mixing mean posterior bias/uncertainty, geometry and model assumptions require assessment independently of chain convergence. Some simulated individuals have no captures across their entire history, permitted only because the synthetic cohort is assumed to have known entry; these animals would ordinarily be unobserved in a real capture-mark-recapture dataset and require explicit data augmentation/conditioning. Annual alive state may remain poorly inferred in truly alive years without later encounters. The actual large Woodchester record is not a known fully enumerated cohort.

**New analysis:** `scripts/ModularFitting/Woodchester_V12I_05d_Spatial_Uncertainty_Audit.R` computes posterior-centred radial 95% credible-ball radius for each individual-year, posterior mean error against simulated true XY, proportion of simulated true centres inside these nominal balls, stratified by true survival and whether any detections occurred. Output `spatial_uncertainty_audit.csv` in the existing run directory. The radial ball is NOT an HPD contour; spatial posterior multimodality and under-mixing can invalidate naive calibration claims. Code has not yet run.

**Run:** `V12I_VALIDATION_OUT="outputs/v12_immigration_prototype/v12i05_validation/v12i05b_20261109T103847Z" V12I_REPS=3 V12I_CHAINS=3 Rscript scripts/ModularFitting/Woodchester_V12I_05d_Spatial_Uncertainty_Audit.R`.

**Decision:** Keep V12I-05b PRELIMINARY, do not claim the model is ready for true death versus emigration inference. First compare uncertainty/radial coverage for alive detected versus alive undetected individuals, inspect high-error well-mixed cases, and test stronger, justified spatial samplers and/or marginalisation after death as necessary. Develop realistic temporally heterogeneous trapping-effort and capture-location model, reconcile V11R2 with curated Supabase data and establish observed-history conditioning vs open-population data augmentation before full Woodchester fitting. No database write or previous fitting output changes.


### 9 November 2026 — V12I-05d uncertainty calibration and targeted detector audit

**Status:** PRELIMINARY (read-only uncertainty analysis completed; spatial calibration remains unverified); V12I-05e CODE COMMITTED / NOT EXECUTED.

**Scientific question:** Are large errors of posterior mean activity centres consistent with stated posterior spatial uncertainty, and does a detector-specific capture pattern explain a persistently displaced fitted trajectory?

**Data and fitting:** Existing V12I-05b 3-dataset, 3-chain synthetic output under `outputs/v12_immigration_prototype/v12i05_validation/v12i05b_20261109T103847Z`; 12 simulated animals × 4 years per replicate, 4 quarterly occasions × 8 detectors. No new fitting and no real-data observations. Reported uncertainty regions are posterior-mean-centred radial balls containing 95% of pooled spatial draw distances from the posterior mean; they are not 2D HPD regions and will be influenced by the unresolved spatial MCMC mixing problems.

**User-reported `Woodchester_V12I_05d_Spatial_Uncertainty_Audit.R` results:**
- Truly alive and detected: 75 animal-years, median position error 108.1 m, median posterior radial 95% radius 214.8 m, 92.0% of true points inside radius.
- Truly alive and undetected: 19 animal-years, median error 146.9 m, radius 281.7 m, 84.2% inside.
- Truly dead and undetected: 50 animal-years, median error 163.8 m, radius 332.4 m, 92.0% inside.
- Replicate 3 animal 11 was alive, detected in all four years (1,2,4,1 encounter indicators by year), but its four position errors were 398.2,347.8,354.2,412.4 m versus posterior 95% radii 191.4,178.2,173.9,220.0 m; the true centre is outside each year's radial ball even though latent coordinate Rhat was around 1.004–1.009. Year-specific failures for one animal are correlated and should not be counted as four independent tests.

**Interpretation:** Spatial uncertainty tends to widen when encounters are absent and when animals are dead. Empirical observed coverage over these small, dependent samples is close to but cannot confirm nominal 95% calibration; alive-undetected undercoverage may be concerning. The persistent offset for replicate 3 animal 11 despite moderately good sampler mixing suggests possible alternative spatial modes, non-identifiability from detector geometry and/or inadequacy in the assumed observation and movement process. No cause is established. Aggregate Rhat for phi/p0 cannot validate all latent S or z.

**New diagnostic and run:** `scripts/ModularFitting/Woodchester_V12I_05e_Capture_Geometry_Audit.R` reads original saved simulated truth, detector locations and 3-chain posterior, reports each quarter's captures by named detector, true and posterior mean distance to each detector, and expected capture indicators conditional on survival at true and posterior locations (simple Gaussian detection kernel). The test targets replicate 3, animal 11 by default and writes a new CSV without refitting. Run:
```bash
V12I_VALIDATION_OUT="outputs/v12_immigration_prototype/v12i05_validation/v12i05b_20261109T103847Z" \
V12I_REPLICATE=3 V12I_BADGER=11 V12I_CHAINS=3 \
Rscript scripts/ModularFitting/Woodchester_V12I_05e_Capture_Geometry_Audit.R
```
Inspect whether the captured detector pattern supports the shifted centres, whether the detector geometry has mirror/alternative solutions, and whether observed versus posterior-predicted detector counts disagree. Do not claim a complete posterior predictive check: predicted counts are conditional on being alive.

**Decision:** Retain V12I-05b PRELIMINARY. Examine detector geometry and uncertainty before changing code or extending MCMC. Then build realistic effort-aware capture likelihood and approved Supabase historical encounter/fate preparation for full Woodchester open-population modelling. The original V11R2 source still needs Supabase reconciliation; no database changes were made.


### 9 November 2026 — V12I-05e detector-specific explanation of displaced posterior location

**Status:** PRELIMINARY (diagnostic completed on a saved synthetic fit; no model refit or new likelihood validation).

**Question:** Does replicate 3 animal 11 have a persistently inaccurate activity centre because the observed detector-specific history favours a location other than the known simulated truth?

**Input and script:** Existing replicated V12I-05b output in `outputs/v12_immigration_prototype/v12i05_validation/v12i05b_20261109T103847Z`; `scripts/ModularFitting/Woodchester_V12I_05e_Capture_Geometry_Audit.R`; synthetic replicate 3, badger 11, 4 annual locations, 8 detector positions, 4 quarters, 3 MCMC chains. Coordinates relative to mean of the eight detectors. Simulation truth used only for post-fitting assessment. No real Woodchester encounters fitted.

**User-reported observations:** True annual centres (196.9,-217.7), (160.1,-272.5), (188.5,-270.7), (216.7,-187.0); posterior mean centres (-199.9,-251.1), (-186.6,-244.6), (-164.6,-242.8), (-188.6,-263.5). True centre was 72.7–93.0 m from TOP, 293.9–345.3 m from UTES. Posterior centres were 314.5–328.5 m from TOP but 47.6–81.8 m from UTES. Observed counts across all 4 years: 5 capture indicators at UTES, 1 at TOP, 1 at ASHTREE, 1 at TAXUS. Under the *generating* (true location, p0=0.42) kernel, expected detector counts across four years: UTES approximately 0.83, TOP 4.32, ASHTREE 0.81, TAXUS 0.88. Under the posterior spatial draws conditional on alive, expected counts: UTES approximately 3.49, TOP 0.88, ASHTREE 1.58, TAXUS 0.34. These are simple detector-specific expected counts, not replicated-data model PPCs.

**Interpretation:** The realised encounter history is atypical under the true annual centres yet spatially consistent with a centre nearer UTES. The persistent ~350–405 m posterior displacement along x despite reasonable coordinate mixing therefore has a plausible observation-driven explanation; it does NOT by itself demonstrate a code defect or systematic kernel bias. Still need exact likelihood comparisons and formal replicated-data checks before concluding model adequacy. Years and detector counts are dependent, and this selected outlier is not evidence of population-wide calibration failure.

**Decision:** Retain V12I-05b PRELIMINARY; stop repeatedly diagnosing one selected synthetic animal. Next use a model-scale PPC across all simulated animal-years/detectors, focusing on detector-specific capture concentration, capture-free trajectories and spatial credible-region calibration; implement actual Woodchester observation-effort and location-provenance preparation using audited Supabase-first data rather than assuming every sett was available every quarter. Resolve V11R2 coordinate/input reconciliation and ensure any real-data mortality and movement inference distinguishes survival, availability and emigration. No production database or existing fitted result changes.


### 9 November 2026 — Proposed spatial core/periphery/outside demographic model and first-vs-recapture audit

**Status: SCIENTIFIC DESIGN / AUDIT CODE COMMITTED; no zonal models fitted or density inferred.**

**Question/hypotheses:** Could time-varying core and peripheral trapping areas plus latent outside status improve inference on transitions, local residence, apparent survival and possible emigration? Can long-term first-observation versus repeat-observation patterns and observed capture intensity inform detection and entry without equating capture counts with density?

**Scientific reasoning:** The observed trapping footprint and spatial capture intensity vary across the approximately 50-year series. Proposed state structure: alive in monitored core, alive in monitored periphery, alive outside monitored area, and dead; optionally before-entry for open population and separate temporary versus permanent external residence only if supported. Use a geographically explicit latent activity centre and derive zone from its location to avoid imposing both independent categorical zones and continuous movement transitions without coherence. Retain observed catch location distinct from annual activity centre/sett/social-group association. The outside region has no currently approved spatial boundary and must be bounded or use a movement distribution; arbitrarily increasing buffer can affect density and survival in open spatial capture–recapture. Zone classifications are NOT assigned from a detector hull without evaluating effort or era.

**Relevant published context:** Open SCR state-space and movement specifications can alter survival estimates (e.g. https://doi.org/10.1002/ece3.4509). Multistate robust-design capture–recapture can distinguish temporary emigration where within-primary sampling closure and known occasion design hold (https://doi.org/10.1111/2041-210X.12792). Reviews caution that movement kernel, detector buffer width and observation histories govern apparent survival and density identifiability (https://doi.org/10.1111/2041-210X.13947). Spatial capture–recapture requires a model for capture effort and distance-based detectability rather than converting recorded capture counts directly into density. These are external methodological references, not Woodchester model results.

**Data input and provenance:** Existing `scripts/database/freeze_woodchester_v12_inputs.R` provides versioned Supabase read-only evidence snapshots: `qualifying_live.rds` plus manifest, with individual tattoos, dates, source capture IDs and location quality; these are prefit evidence, NOT approved effort histories or a fitted model. Prior snapshot audits suggested 3,214 observed tattoos and 16,230 live capture-days (in one earlier snapshot), but estimates must be recalculated by actual eligible subset, observation effort and calendar year. No real model results or new counts claimed.

**New audit script:** `scripts/ModularFitting/Woodchester_V12_Zone_FirstRecapture_Audit.R`, run only with `V12_SNAPSHOT` pointing to a recognised curated Supabase evidence snapshot containing `MANIFEST.txt` and `qualifying_live.rds`. Does not use historical local RDS as authoritative evidence. Collapses multiple capture records per tattoo/day, classifies first recorded day versus subsequent observed days conditional on dataset start, outputs annual and quarterly first/repeat counts, observed annual return next year (NOT a survival/detection probability), accepted XY availability and coordinate-quality trends. Never assigns arbitrary zone boundaries or reports density. Outputs aggregate CSVs into a new timestamped folder, refusing to overwrite pre-existing output. Does not query or mutate Supabase.

**Suggested command:**
```bash
# Set this explicitly to the reviewed Supabase evidence snapshot.
export V12_SNAPSHOT="data/model_snapshots/YOUR_REVIEWED_SNAPSHOT"
Rscript scripts/ModularFitting/Woodchester_V12_Zone_FirstRecapture_Audit.R
```
**Required before core/periphery definition:** inspect historical trapping protocols and physical trap-day/sett-quarter effort, verified historical site XY and active-trap years, boundary extent and external habitat, and cases of unsettled/ambiguous location provenance. The snapshot has only positive captures and cannot identify zero-effort versus zero-capture detector-quarters. A density analysis requires area, detection model and unobserved-animal treatment; core/periphery observed counts alone cannot provide density. As a sensitivity design consider multiple defensible periphery widths and calendar-specific detector footprints after effort review, rather than a fixed universal buffer.

**Modelling next steps:** (1) audit first/repeat temporal patterns, (2) find/check field effort and reliable mapped spatial coverage by year, (3) build zone-and-distance transition summaries with explicit evidence tags, (4) develop simulation-based multi-state spatial open-population models with entry and death recovery, (5) test robustness to outside-boundary extent, detection heterogeneity, calendar periods, sex and age. Distinguish immigration from local recruitment, and permanent emigration from temporary unavailability/death unless auxiliary data identify them. No production data modified.


### 9 November 2026 — Woodchester first/repeat capture audit and explicit infection/persistence integration

**Status:** Capture-frequency audit COMPLETE (descriptive), disease observation audit CODE COMMITTED / NOT YET EXECUTED; open-population spatial and infection models remain PLANNED.

**Question:** Are changing observed badger numbers, first-capture frequencies and subsequent recaptures consistent with changing density, detection opportunity, recruitment or movements among core/periphery/outside? How can these demographic/spatial processes ultimately inform M. bovis infection introduction, spread, infectiousness and persistence without confusing diagnostic status with true infection state?

**Input:** Supabase-derived frozen snapshot `data/model_snapshots/v12_20261106T103144Z_1079872`, `qualifying_live.rds` and manifest, via `scripts/ModularFitting/Woodchester_V12_Zone_FirstRecapture_Audit.R`. User-ran 9 Nov 2026; 16,230 qualifying live source rows/capture-days, 3,214 observed tattoos, calendar years through 2025; daily duplicate collapsed by tattoo+date. Summaries saved to `outputs/v12_zone_firstrecapture_audit/audit_20261109T122321Z`. These are positive encounters only. Location validity and trap effort are not yet established.

**Observed 2019–2025 pattern:** annual unique observed badgers 117, 73, 80, 44, 23, 35, 37; annual live capture-days 221, 115, 143, 70, 36, 66, 68; first-observed badgers 46, 26, 41, 21, 9, 25, 17. Conditional observed next-year return fractions: 2018 0.5431; 2019 0.4017; 2020 0.3699; 2021 0.2500; 2022 0.2727; 2023 0.3043; 2024 0.5429. The latter value is NOT true survival, as detection and effort can vary. Compare early years and changing sampling footprint before interpreting temporal trends. No population-density decline, immigration rate or mortality change inferred from these summaries.

**Cross-process scientific framework:** V12 survival/recruitment/movement/detection should be structured explicitly to admit the V12D/V13 time-varying infection and persistence extension. A feasible latent process includes alive and spatial state (continuous centre; core/periphery/outside derived relative to era-dependent trapping footprint), entry and death, and conditional infection/excretion state for each individual. Observation processes are separately capture history, diagnostic test outcomes (culture/DPP/other assays) and confirmed death/PM evidence. Underlying infection, infectiousness and individual-level diagnostic results are not interchangeable, and an individual's lifetime ever-positive variable is not a valid baseline time-varying infection status (immortal-time bias). Infection may affect survival or movement; individual movement and changing density influence infection acquisition/transmission and the persistence of connected infection reservoirs. Start with density proxies and identifiability, only estimate density after effort/area/data augmentation; study-area boundary and outside-buffer sensitivity must be tested.

**Database sources known from audited data dictionary:** `research.cultures` (culture_id, capture_id, culture_result), `research.dpp_tests` (dpp_test_id, capture_id, test_result), `research.captures` (capture_id, capture_date, is_pm); `analysis.capture_infection_probabilities` and `research.infection_quarterly_probabilities` are pre-existing inferred quantities whose model lineage/overlap must be reviewed before using as independent evidence, avoiding double use of diagnostic tests. Disease status lookup includes Negative/Exposed/Excretor/Super excretor, not a simple directly observed true state. PM observation is not necessarily death date and must use curated mortality classification.

**New read-only SQL audit:** `sql/audit/WECS_V12_V13_Diagnostic_Observation_Year_Audit.sql` aggregates yearly capture and PM rows, culture tests/capture-events, M. bovis-positive versus negative versus unresolved culture rows, and DPP rows/coverage, without classifying unknown DPP outcomes or defining disease prevalence from tested samples. Output is a per-year aggregate to review against changing live capture intensity. No database writes, no fitted infection or transmission results. Run in Supabase SQL editor with appropriate read-only role; report aggregate table. Test data are not independent of capture/detection.

**Decisions/next actions:** (1) Audit historical trapping effort/zero-capture sessions and changing trapping footprint, and distinguish core, peripheral and outside zones with boundary sensitivity; (2) audit availability and provenance of dated diagnostic assays and link with capture and mortality episodes without double counting; (3) define biologically interpretable multi-state entry/dispersal/temporary emigration with realistic observation histories and known-death constraints; (4) test infection observation model, latent time-varying infection and excretion, then investigate spatial importation, persistence and feedback on survival/movement; (5) keep V12 and V13 components part of one coherent scientific programme, not disconnected final extensions. No audited effort results or V13 fits yet.


### 9 November 2026 — V11R2 core/periphery/outside posterior sensitivity audit

**Status:** CODE COMMITTED / NOT EXECUTED ON RSTUDIO; scientific baseline assessment, not new fit.

**Question/hypothesis:** Do V11R2 annual latent activity-centre posterior draws support useful interpretation as core residence, peripheral residence and positions beyond the detector footprint, and which inferred movements are sensitive to the location of the inner core boundary? Does the existing spatial posterior show defensible core-to-periphery versus periphery-to-core geographic redistribution?

**Data, provenance and eligibility:** Three historical `results/V11R2_RES50_*_1932_CHAIN[123].rds` model chains, `annual_state_index` and detector XY; versioned Supabase evidence snapshot selected explicitly via `V12_SNAPSHOT`, with manifest + `qualifying_live.rds` used *only* to mark which tattoo-years have qualifying observations. V11R2 old input aliases and sett/XY decisions have not been reconciled against audited Supabase capture locations; therefore no validated spatial mapping or independently estimated demographic parameter is claimed. Historical model smoothed positions may incorporate subsequent captures (future information).

**Geographical scenarios:** The **outer** extent is the convex hull of all V11R2 model detector points; `outside` means a latent position beyond this hull, NOT known permanent emigration or the entirety of the biological outside population. The **core** is defined as the convex hull of the central 50%, 65% or 80% of legacy detector points ranked by distance from their coordinate medians, with at least four selected points; **periphery** is the remaining area inside the outer detector hull. These are *artificial sensitivity scenarios*, not validated biological boundaries or trapping-effort footprints. Output includes site coordinates and hull vertices for inspection before any biological labels or real-data fits.

**Methods:** `scripts/ModularFitting/Woodchester_V11R2_Core_Periphery_Posterior_Audit.R` reads three posterior chains sequentially, samples up to 60 evenly spaced rows per chain by default (configurable `ZONE_DRAWS_PER_CHAIN`), calculates annual posterior probability of each zone, and for each consecutive modelled tattoo-year interval calculates nine joint zone-to-zone probabilities from **the same posterior draw row at both endpoints**, preserving spatial state dependence. Aggregates by calendar year and zone-scenario, and writes individual-level output to Git-ignored/local `outputs/v11r2_core_periphery/` directories (never commit these files without confidentiality review). Requires both actual files and manifest and refuses to overwrite existing output. Observed tattoo-year flags come from the frozen qualifying-live evidence, without excluding uncertain spatial states or treating gaps as adjacent-year transitions. No trap effort, density, recruitment, survival or immigration fit; occupancy means are conditional on the V11R2 modelled badger-years, not population prevalence or density.

**Run command:**
```bash
cd ~/Badgers_SpatialPostDoc
git status --short --branch
git pull --ff-only
Rscript -e 'invisible(parse(file="scripts/ModularFitting/Woodchester_V11R2_Core_Periphery_Posterior_Audit.R"));cat("Syntax OK\\n")'
V12_SNAPSHOT="data/model_snapshots/v12_20261106T103144Z_1079872" \
ZONE_DRAWS_PER_CHAIN=60 \
Rscript scripts/ModularFitting/Woodchester_V11R2_Core_Periphery_Posterior_Audit.R
```

**Expected files:** `01_detector_geometry_reference.csv`, `02_core_hull_vertices.csv`, `03_outer_detector_hull_vertices.csv`, `04_individual_annual_zone_probabilities.csv`, `05_consecutive_year_transition_probabilities.csv`, `06_annual_model_state_occupancy.csv`, `07_annual_mean_transition_probabilities.csv`, `08_scenario_sensitivity_summary.csv`, and `README_ASSUMPTIONS.txt`. Run not yet verified on RStudio server. All current model outputs and database unchanged.

**Decision gate:** First inspect historical V11R2 detector hull and sample years and compare across all three candidate inner boundaries; check any implausible core geometry and whether interval zone occupancy is driven by model tails or observationally supported movement. If results appear robust, choose a biological/study-design core using independent evidence on actual trapping coverage and audited capture XY, and only then develop a final geographically coherent V11/V12 spatial specification. Avoid using zone classifications as an unvalidated proxy for disease, movement direction, emigration or survival.


### 9 November 2026 — V11R2 empirical core/periphery/outside sensitivity completed

**Status: PRELIMINARY descriptive posterior analysis COMPLETED, not validated new spatial model; conditional transition summary code COMMITTED / NOT EXECUTED.**

**Question:** What proportion of V11R2 modelled badger-years fall in candidate core, periphery and outside zones, and what do posterior transitions reveal across zone boundaries? Does this interpretation depend strongly on core size?

**Input, eligibility and settings:** User ran `scripts/ModularFitting/Woodchester_V11R2_Core_Periphery_Posterior_Audit.R` successfully (exit 0) with frozen `data/model_snapshots/v12_20261106T103144Z_1079872` used solely for observational flags, three legacy `V11R2_RES50` posterior chains (60 sampled draws each, 180 draws total), 8,248 annual individual spatial states, 6,316 consecutive tattoo-year intervals. Run output `outputs/v11r2_core_periphery/audit_20261109T134751Z`. Three nested central detector hull scenarios: 60, 78 and 96 of the 120 legacy detector sites (50%, 65%, 80%); same full global detector hull as outside boundary. Model lineage and historical alias/coordinate reconciliation are still outstanding.

**Numerical results:**
- central_50: mean posterior p(core)=0.2957714, p(periphery)=0.5662713, p(outside)=0.1379573; fraction of annual states with maximum-zone-probability below 0.75 = 0.2194471; mean *joint across all intervals* p(core→periphery)=0.02155636, p(periphery→core)=0.02106731.
- central_65: p(core)=0.4186759, p(periphery)=0.4433667, p(outside)=0.1379573; uncertain fraction 0.2766731; mean joint core→periphery 0.02772940, periphery→core 0.02540901.
- central_80: p(core)=0.5932280, p(periphery)=0.2688147, p(outside)=0.1379573; uncertain fraction 0.1664646; mean joint core→periphery 0.01540796, periphery→core 0.01540444.
- Outside posterior fraction constant at 13.8% **by construction**, as only the inner core boundary changes. The mean core↔periphery joint transition probabilities are ~1.5–2.8% of all intervals, NOT conditional p(destination | origin), and do NOT yet establish movement symmetry or transition rates among core residents.

**Interpretation:** Definition of the inner zone materially affects classification, uncertainty, and estimates of between-zone movement. A core defined by 50–80% of detector locations is only a geometric sensitivity test and should not be adopted as biological territory or historical trapping-effort boundary. The 13.8% posterior outside-hull occupancy is conditional on V11R2 modelled animal-year states, NOT an emigration probability or population density. Changes through time can be affected by animals/years selected into V11R2, global historical detector geometry, and unverified legacy locators.

**New read-only summary:** `scripts/ModularFitting/Woodchester_V11R2_Core_Periphery_Transition_Summary.R` reads existing 04 and 05 audit CSVs, forms conditional origin-to-destination probabilities as summed joint posterior counts divided by summed posterior origin occupancy across consecutive modelled intervals, and repeats the exercise restricted to animals observed both years (a selected, potentially biased subset). Reports all 9 zone-to-zone transitions and annual occupancy support; creates a new output folder without changing previous results. `V11R2` posterior draws remain smoothed/retrospective, so neither exercise is an independent predictive validation or a fitted transition-rate model. Script not yet run on RStudio.

**Run command:**
```bash
cd ~/Badgers_SpatialPostDoc
git pull --ff-only
Rscript -e 'invisible(parse(file="scripts/ModularFitting/Woodchester_V11R2_Core_Periphery_Transition_Summary.R"));cat("Syntax OK\\n")'
ZONE_AUDIT_DIR="outputs/v11r2_core_periphery/audit_20261109T134751Z" \
Rscript scripts/ModularFitting/Woodchester_V11R2_Core_Periphery_Transition_Summary.R
```

**Next decision:** Examine conditional transition probabilities, transitions crossing the global hull boundary, time coverage and whether annual zone results are unstable due to boundary choice. Then audit/visualise detector hulls against actual trapping footprint and historical coordinate reliability before committing to biologically named core/periphery zones or refitting V11R2. Do not advance demographic/disease models in this spatial-only decision gate.


### 9 November 2026 — Conditional V11R2 core/periphery/outside posterior transitions (completed)

**Status: PRELIMINARY / retrospective posterior summary completed, NOT independently validated biological movement rates.**

**Question:** After accounting for zone of origin, what do V11R2 posterior draws imply about annual core/periphery/outside transitions, and how sensitive are these to candidate core extent? Do we have sufficient evidence to describe observed spatial residence and movement without attributing missing observations to emigration?

**Input/settings:** Existing V11R2 spatial posterior zone audit `outputs/v11r2_core_periphery/audit_20261109T134751Z` using three historical RES50 chains (60 posterior draws per chain) and Supabase-frozen observation flags; summarised by `scripts/ModularFitting/Woodchester_V11R2_Core_Periphery_Transition_Summary.R`. User completed audit successfully; new output `outputs/v11r2_core_periphery/conditional_20261109T135150Z`, including `01_conditional_zone_transitions.csv` and `02_annual_zone_occupancy_and_observation.csv`. 6,316 consecutive modelled tattoo-year intervals across 1977–2025; annual states ranged from 12 to 356 per year. The reported origin support is expected posterior origin-zone interval mass, not the count of uniquely classified animals.

**Conditional posterior transition matrices** (row: origin; columns: core, periphery, outside):
- central_50: core (0.92378, 0.07189, 0.00433), expected origin interval mass ~1894; periphery (0.03717, 0.93403, 0.02880), mass ~3580; outside (0.00656, 0.10917, 0.88427), mass ~842.
- central_65: core (0.93005, 0.06538, 0.00457), mass ~2679; periphery (0.05742, 0.90714, 0.03544), mass ~2795; outside (0.00832, 0.10741, 0.88427), mass ~842.
- central_80: core (0.96873, 0.02579, 0.00548), mass ~3774; periphery (0.05724, 0.88945, 0.05331), mass ~1700; outside (0.01613, 0.09960, 0.88427), mass ~842.

**Interpretation/uncertainty:** Conditional same-zone probabilities 88–97% imply strong apparent annual spatial persistence in fitted retrospective locations, and inferred transitions more often cross adjacent zone boundaries than core→outside. Boundaries are central-detector convex hulls selected by ranked detector distance; the outside convex hull remains unchanged, hence its inferred self-transition is identical in all scenarios by construction. The three candidate core boundaries materially alter conditional movement probabilities and the number of posterior expected origin intervals. Do not report the values as independently fitted transition parameters, biological social-group residency, emigration, survival or density; global historic detector geometry is not an era-specific trapping footprint, model S may be constrained by its movement prior, and smoothed positions can use later observations. In particular, these values could be prior/likelihood smoothing over weakly observed intervals rather than direct evidence of residence.

**Next decision gate:** First examine `subset=detected_both_years` in the existing conditional transition CSV, comparing its conditional matrix and support with `all_modelled_intervals`. This comparison is strongly selected on observed recapture, so must NOT be interpreted as independent validation or population transition rates; it is a sensitivity diagnostic of observational support. Next inspect/map the actual core hull boundaries, detector site historical quality, years with few modelled states, and 50/65/80% sensitivity. Reconcile V11R2 legacy inputs against audited Supabase capture coordinates before selecting biological core boundaries or committing to a refit. No new model and no database changes.


### 9 November 2026 — V11R2 core/periphery spatial stability among consecutively recaptured badgers

**Status:** PRELIMINARY descriptive posterior check COMPLETED; geographical boundary plot CODE COMMITTED, NOT EXECUTED.

**Question:** Is strong annual zone persistence robust when considering only badgers caught in both consecutive years, compared with all V11R2 modelled intervals? The observed-both selection is not independent validation because its captures informed V11R2 and because of selection on recapture.

**Input:** Existing `outputs/v11r2_core_periphery/conditional_20261109T135150Z/01_conditional_zone_transitions.csv`, central_65 candidate core hull, 6,316 total consecutive modelled intervals, of which expected zone-origin masses (all) sum to 6,316 and observed-in-both-year masses sum to approximately 4,609. Historical 1977–2025 detector geometry, not era-specific vetted effort or cleaned capture XY. No new fit.

**User-reported central_65 posterior conditional probabilities (origin -> [core, periphery, outside]):**
- All modelled intervals: core (0.93005, 0.06538, 0.00457), periphery (0.05742, 0.90714, 0.03544), outside (0.00832, 0.10741, 0.88427).
- Observed both consecutive years: core (0.93381, 0.06338, 0.00281), periphery (0.06555, 0.89767, 0.03679), outside (0.00584, 0.12513, 0.86903).
- Expected origin interval masses in both-observed subset: core ~2,184, periphery ~1,923, outside ~502; total ~4,609.

**Interpretation/uncertainty:** Dominant same-zone posterior transitions persist under observation restriction: core 93.0 vs 93.4%, periphery 90.7 vs 89.8%, outside 88.4 vs 86.9%. Outside-to-periphery increases 10.7 to 12.5% in observed-both-year subset. The selected subset may overrepresent animals remaining available for capture; spatial posterior uses same data and movement prior; values are NOT independently predictive transition rates or evidence of permanent emigration. Existing V11R2 input coordinates/sett aliases still require audit before adopting zone boundaries.

**New script:** `scripts/ModularFitting/Woodchester_V11R2_Zone_Geometry_Review.R` uses prior output `01_detector_geometry_reference.csv`, `02_core_hull_vertices.csv`, `03_outer_detector_hull_vertices.csv` to plot all three 50/65/80% candidate nested detector hulls in three equal-aspect panels (PNG), save legacy detector geometry extent and caveat text; new timestamped output, no DB or model changes. No script execution results yet.

**Run:**
```bash
cd ~/Badgers_SpatialPostDoc
git pull --ff-only
ZONE_AUDIT_DIR="outputs/v11r2_core_periphery/audit_20261109T134751Z" \
Rscript scripts/ModularFitting/Woodchester_V11R2_Zone_Geometry_Review.R
```

**Decision gate:** Review actual shape/extent of candidate core regions and selected detector coverage; decide whether geometric core is defensible or period-specific sampling/effective survey coverage needed before substantive core/periphery interpretation. Do not advance density, survival, immigration or infection models until spatial data/source reconciliation and spatial inference are addressed.


### 9 November 2026 — Visual review of candidate V11R2 zone geometry and historical footprint next step

**Status:** User-supplied V11R2 candidate hull map VISUALLY REVIEWED; historical footprint audit CODE COMMITTED / NOT EXECUTED. No new model fitting.

**Observation from `01_candidate_zone_boundaries.png`:** The legacy all-detector convex hull is extended northeast/east by comparatively isolated detector points, enclosing a broad eastern sector with visibly sparse detector coverage. The central_50 hull excludes a substantial group of west/southwest detectors that appear within the main network. The central_80 hull comes near the full outer hull along the south edge, resulting in very little intervening periphery there but more in the east. The central_65 hull is a plausible **visual starting scenario only**, not an effort-verified biologically defined core. A detector centroid-ranked convex hull need not match long-run trapping footprint or actual ecological core; current zone transition results must retain sensitivity caveats.

**Scientific question:** Do historically recorded, quality-tagged Supabase capture coordinates support broadly similar capture footprints over decades; how far are those source XY positions from the old V11R2 detector coordinates? Does the candidate core require period-specific geography or another approach?

**Script:** `scripts/ModularFitting/Woodchester_V11R2_Historical_Capture_Footprint_Audit.R` uses (a) legacy V11R2 detector XY saved in the prior zone audit's `01_detector_geometry_reference.csv`; (b) frozen read-only Supabase evidence snapshot's `qualifying_live.rds`, `MANIFEST.txt`, tattoo, dates, capture_id, XY and location_quality. It shows three selected capture-history eras (1977–1992, 1993–2008, 2009–2025). It reports total live capture evidence, missing XY, distance to nearest legacy detector, positive capture records near each legacy site (100-m proximity sensitivity setting), location-quality counts and a 3-panel geographic plot. **Near-detector matching is geographic proximity alone and must NOT be used to assert recorded sett identity, an audited location match or actual trapping effort**: some curated capture coordinates can indicate sett reference, physical catch location, road recovery or low precision, and no zero-capture effort data are included. Existing modelled detector set may not cover all historical locations. No animal-level data are exported; aggregate CSV/PNG only, timestamped new output, fail if output path exists. No Supabase modifications or refit.

**Run:**
```bash
cd ~/Badgers_SpatialPostDoc
git pull --ff-only
V12_SNAPSHOT="data/model_snapshots/v12_20261106T103144Z_1079872" \
ZONE_AUDIT_DIR="outputs/v11r2_core_periphery/audit_20261109T134751Z" \
ZONE_MATCH_THRESHOLD_M=100 \
Rscript scripts/ModularFitting/Woodchester_V11R2_Historical_Capture_Footprint_Audit.R
```

**Decision gate:** Examine 3-panel capture map and location-quality table, identify whether long-term coordinate evidence and the historic detector network are sufficiently compatible to justify any static core. Then investigate historical field trapping effort and specific subset of verified location records if needed; do not infer animal-density gradients, emigration, true survival or between-zone biological transition rates from these geometric exercises. Infection/survival phases explicitly deferred until the spatial foundation is evaluated.


### 9 November 2026 — Historical capture footprint results and coordinate-provenance limitation

**Status:** Read-only historical footprint diagnostic COMPLETED; geographical classification NOT VALIDATED. Next gate is coordinate provenance and three-panel map visual check; no model refit.

**Question:** Do the historical capture coordinates show meaningful correspondence with V11R2 legacy detectors across eras, and can this correspondence independently validate the use of detector-based core/periphery boundaries?

**Run/input:** `scripts/ModularFitting/Woodchester_V11R2_Historical_Capture_Footprint_Audit.R`, `V12_SNAPSHOT=data/model_snapshots/v12_20261106T103144Z_1079872`, existing detector reference `outputs/v11r2_core_periphery/audit_20261109T134751Z`, diagnostic proximity 100 m. User's completed output: `outputs/v11r2_core_periphery/historical_footprint_20261109T143633Z` including `04_historical_capture_footprint.png`, `02_period_capture_coordinate_coverage.csv` and `03_recorded_xy_quality_by_period.csv`. Historic eras 1977–1992, 1993–2008, 2009–2025; input eligible captured years to 2025, pre-1977 explicitly excluded.

**Results:** 1977–1992: 5,297 qualifying live source rows, 4,966 finite XY, 331 missing XY, 4,966 within 100 m of a legacy detector, 83 legacy sites with nearby observed captures. 1993–2008: 7,660 rows, 7,484 finite XY, 176 missing, 7,483 within 100 m, one farther, 105 sites with nearby records. 2009–2025: 3,273 rows, 3,242 finite XY, 31 missing, 3,242 within 100 m, 66 sites with nearby records. Median and p90 nearest-detector distance are **exactly zero** in all three eras.

**Critical interpretation:** These extremely high exact matches strongly suggest Supabase coordinate values are often mapped to the same historical named-sett points as V11R2 detector references, **not independent position verification**. The official cleaned `analysis.encounters_clean_v1` documentation shows `SETT_POINT_PROVISIONAL` as the predominant `location_quality` category (15,740 source rows in November baseline), with other associations, grid squares, unresolved cases and conflicts. V11R2 modeled detectors might be canonical sett or SG references and exact equal XY can be tautological. The 83/105/66 counts describe different sites with *observed captures*, NOT independent estimates of trapping deployments or coverage, nor a biological population-area change. Location quality and exact XY provenance must be inspected before applying a high-precision distance detection kernel or inferring area-dependent zone movements.

**Next:** Review saved three-panel `04_historical_capture_footprint.png` together with `03_recorded_xy_quality_by_period.csv` and `01_legacy_detectors_near_captures_by_period.csv`. Quantify percent of finite captured XY exactly equal to historical detector coordinates stratified by `location_quality` and `location_type` from the approved snapshot; do not treat distance zero as independent corroboration. Investigate whether detector points truly represent capture-sett locations, canonical sett reference or historical social group centres, and whether period-specific availability is known. Do not select a central_65 biological core, infer trapping effort or refit the spatial model until provenance is resolved. Preserve existing posterior sensitivity findings as retrospective diagnostics.


### 9 November 2026 — Investigator clarification: fixed sett capture sites and genuine monitoring-area contraction

**Status:** KEY DATA INTERPRETATION RESOLVED BY INVESTIGATOR; retrospective spatial core definition still under investigation. New historical sett network comparison CODE COMMITTED, NOT EXECUTED.

**Clarification:** The trap positions correspond to **fixed sett locations**, rather than GPS fixes that change from trapping event to event. With the exception of some recovered/dead animals and other unusual captures, named trapping setts are the principal available spatial observations. Consequently, an exact match between a cleaned capture-location XY and a legacy V11R2 sett detector XY is **expected** where both use the same reference sett coordinate; it is not independently corroborated measurement and does NOT invalidate sett-centred spatial analysis. An animal's trapping sett, inferred annual activity centre, residential sett and resident social-group assignment remain distinct concepts. All location-quality evidence, conflicting sett assignments and recovered-body sites need separate handling. The investigator also confirms the **monitored geographical area genuinely became smaller in recent years**; do not dismiss the change in observed capture-sett footprint as purely sampling noise.

**Reported 1977–1992 / 1993–2008 / 2009–2025 location-quality counts from frozen `qualifying_live.rds`:** SETT_POINT_PROVISIONAL 4,962 / 7,335 / 3,234; SETT_ASSOCIATION_PROVISIONAL 4 / 149 / 8; SETT_COORDINATE_CONFLICT 41 / 11 / 0; SETT_ASSOCIATION_ONLY 5 / 0 / 0; UNRESOLVED 285 / 165 / 31. These are observed record-quality categories, not proof that individual sett positions change or that all recorded sett associations are correct.

**Spatial model implications:** The geometric centre-ranked central_50/65/80 detector hulls are useful exploratory sensitivity analyses only. A substantive study core should instead reflect the fixed network of **consistently monitored setts**, with a wider historical network forming the periphery and geographical 'outside' beyond the historic site footprint. However, **positive capture records alone do not establish setts actively trapped** during any particular year or zero-capture periods. Reduced recent footprint confirmed by investigator should be incorporated as an era-dependent detection-availability condition and tested for effects on inferred movement and uncertainty. Do not infer apparent return, dispersal, immigration or true outside occupancy merely from post-closure noncaptures. No area finalised.

**New script:** `scripts/ModularFitting/Woodchester_V11R2_Historical_Sett_Network_Review.R` consumes previous `01_legacy_detectors_near_captures_by_period.csv` and produces a 120-sett period-by-period captured/not-captured matrix, summary counts for recorded in all three periods / earlier-only / recent-only, and a three-panel historical site footprint PNG. This is descriptive **capture evidence**, not deployment/effort. Proximity association remains provisional because old detector coordinates can share reference setts with curated positions; no name-matching shortcuts or database writes. No NIMBLE fitting.

**Run:**
```bash
cd ~/Badgers_SpatialPostDoc
git pull --ff-only
ZONE_FOOTPRINT_DIR="outputs/v11r2_core_periphery/historical_footprint_20261109T143633Z" \
Rscript scripts/ModularFitting/Woodchester_V11R2_Historical_Sett_Network_Review.R
```

**Next spatial decision:** Review historical spatial network maps and which named setts disappear from the recent positive-capture record, identify monitoring-contracting eras from field-study records if possible, and define a fixed named-sett core only once actual active-trapping evidence is reconciled. Then reconsider V11R2 zone occupancy, transition and likelihood support under era-specific detection. Demography, density and disease/infection modelling intentionally deferred.


### 9 November 2026 — Correct unsupported 120-detector count in historical network review

**Status: R script corrected / awaiting rerun.** The read-only `Woodchester_V11R2_Historical_Sett_Network_Review.R` initially failed with `Unexpected count of V11R2 legacy detector sites: 119` because its author incorrectly hard-coded 120 detectors. The established zone sensitivity configurations of 60/78/96 central detectors are consistent with **119 reference detectors** (ceil of 50%, 65%, 80% of 119). Prior roadmap references to 120 detectors should be treated as unverified/incorrect until the detector reference CSV is checked. No scientific inference or output should be discarded on account of this mismatch. The patched script uses the actual distinct IDs from `01_legacy_detectors_near_captures_by_period.csv`, validates a complete three-period detector grid and can compare IDs with `01_detector_geometry_reference.csv` if `ZONE_AUDIT_DIR` is supplied. The user should rerun it; no database or model fit changes.


### 9 November 2026 — Fixed-sett historical network reviewed; annual continuity next gate

**Status:** Observed three-era fixed-sett map and summary completed by user. New annual capture continuity script COMMITTED but NOT EXECUTED; no spatial refit.

**Question:** Which fixed trapping setts provide temporally sustained observation evidence rather than appearing only once during each multi-year historical period? Can this inform (but not independently determine) the core of the Woodchester spatial model?

**Data and results:** Existing fixed V11R2 reference network is **119 distinct detector/sett points**, confirmed by user run (`Detector count in reference: 119`, period file 119). Read-only `Woodchester_V11R2_Historical_Sett_Network_Review.R` output `outputs/v11r2_core_periphery/sett_network_20261109T145040Z`, with map `03_sett_network_period_comparison.png`. Sites with >=1 recorded live capture in 1977–1992: **83**; in 1993–2008: **105**; in 2009–2025: **66**. Captures in all three: **46**; recorded previously but not in latest era **52**; recorded only in recent era **4**. These counts reflect positive capture histories at historical detector-reference points, not independently observed trapping effort. The recorded network contracts in the latest era, consistent with investigator's historical knowledge that geographical monitoring really shrank. The map shows losses particularly in the northeastern/eastern portion and additional gaps elsewhere.

**Interpretation:** The 46 all-three-period capture setts are a reasonable candidate *pool* of historically persistently sampled sites, not a validated biological core or proof of continuous trapping. Even one capture per 16–17 year block meets the three-era definition. Some previously captured sites may have continued being trapped without captures. Neither current outer hull nor centroid-ranked inner hull accounts for era-specific site availability; previously reported core↔periphery posterior transitions remain exploratory.

**New read-only audit:** `scripts/ModularFitting/Woodchester_V11R2_Sett_Annual_Continuity_Audit.R` links frozen `qualifying_live.rds` source XY (dated captures only) to nearest 119 reference sett locations, reports number of distinct calendar years with positive captures at each, first/last capture years, longest *observed capture* gap, years with captures per era and 2019–2025, and creates full detector × 1977–2025 annual panel plus map shaded by observed-capture continuity. Uses 100-m nearest-reference threshold by default and produces timestamped local CSV/PNG outputs. Does NOT equate capture-negative years with no active trapping; no final core assignment, biological density or movement parameter fitting. Proximity matching and unresolved location provenance remain constraints.

**Run:**
```bash
cd ~/Badgers_SpatialPostDoc
git pull --ff-only
V12_SNAPSHOT="data/model_snapshots/v12_20261106T103144Z_1079872" \
ZONE_AUDIT_DIR="outputs/v11r2_core_periphery/audit_20261109T134751Z" \
Rscript scripts/ModularFitting/Woodchester_V11R2_Sett_Annual_Continuity_Audit.R
```

**Decision:** Examine continuous annual support among the 46 historically observed setts and inspect the geographical pattern without assuming stable effort. A defensible spatial core should eventually be based on field monitoring records and a consistent era-aware trap-availability process; do not expand project into demographic or infection models at this step.


### 9 November 2026 — Annual capture continuity at 119 fixed legacy setts

**Status:** Existing observational continuity audit COMPLETED; geographical interpretation pending inspection of new continuity map; no spatial model fit/recalibration.

**Question:** Within the 46 legacy setts showing positive capture evidence in all three historic periods, how consistently were captures recorded annually? Do these sites provide a defensible *candidate pool* for a geographically coherent long-term monitoring core?

**Input/execution:** `scripts/ModularFitting/Woodchester_V11R2_Sett_Annual_Continuity_Audit.R`, curated Supabase frozen capture evidence snapshot `data/model_snapshots/v12_20261106T103144Z_1079872` and historical V11R2 detector geometry reference `outputs/v11r2_core_periphery/audit_20261109T134751Z`. User reports successful run with output `outputs/v11r2_core_periphery/continuity_20261109T161513Z`; among 119 legacy detector setts, 46 had observed captures in all three eras. Among these 46, number of distinct years with >=1 observed capture: min 7, Q1 20, median 35.5, mean 31.3, Q3 44, max 47 of 49 calendar years (1977–2025). One finite-coordinate capture fell outside the nearest-detector 100-m proximity criterion and was excluded, without silently reassigning a sett.

**Illustrative long-term setts and observed years:** ARTHURS 47 (16/16/15 years in the three eras), KENNEL 47 (15/16/16), OLDOAK 47 (15/16/16), WINDSOREDGE 47 (14/16/17), BEECH 46 (16/16/14), WEST 46 (16/16/14), INCHBROOK 45 (12/16/17), PARKMILL 45 (13/16/16), TOP 45 (15/16/14), YEW 45 (16/13/16), HONEYWELL 44, LARCH 44, NETTLE 44, COLLIERSWOOD 43, TAXUS 42. These are not yet formal core members; density, study effort, capture probability, and biological residency not estimated. Zero recorded captures in a year does NOT identify absent trapping effort.

**Output:** annual per-sett year panel `02_sett_year_observed_capture_panel.csv`, ranking `01_sett_annual_capture_continuity.csv`, and geographic plot `03_sett_capture_continuity.png`. User's attached three-panel historical map reproduces prior period comparison; new annual continuity map has not yet been visually reviewed.

**Decision:** Review the new spatially coloured annual continuity plot to see whether the high-frequency capture setts constitute one coherent spatial area or multiple clusters. Avoid choosing a capture-year threshold or forcing an enclosing convex hull before viewing geometry and considering monitoring contraction. Only then propose a *provisional*, field-verifiable core/periphery boundary and rerun existing posterior zone occupancy against it; keep distinctions between long-term capture evidence and actual effort, and legacy setts vs audited capture positions. No additional modelling stages, density or infection analyses at this point.


### 9 November 2026 — Geographic review of long-term sett capture continuity

**Status:** User-supplied `03_sett_capture_continuity.png` visually reviewed. Core definition decision REVISED; no new fit or data modifications.

**Observation:** Continuity map shows that consistently captured setts are **spatially dispersed across western, central and eastern parts** of the fixed 119-sett network rather than forming one compact central polygon. Some adjacent setts have quite different annual observation histories, and peripheral northeastern/southwestern setts are generally more intermittent although there are exceptions. Colour represents number of years with at least one recorded live capture, **not** independently measured trap deployment or effort. The previous central_50/65/80 detector convex hull classifications remain sensitivity analyses and must not be treated as biological core boundaries.

**Interpretation:** A centroid-based convex hull can both exclude a frequently observed peripheral sett and enclose broad areas where no capture observation was recorded. Core/periphery may therefore be most defensible initially as **fixed-sett observation-network categories with time-varying availability**, not as a single nested pair of ecological polygons. Continue to represent animal activity centres and movements as spatially continuous posterior positions. Explicitly separate capture-sett coordinates from inferred animal centre, residence, and social group. The documented contraction in geographical monitoring over recent decades must be incorporated in the time-indexed observation process before concluding an animal actually moved or disappeared. No first/recapture, survival, density, immigration or infection model fitted here.

**Single next spatial decision:** Establish actual monitoring/trapping availability at named setts by year or quarter if field records exist. Where effort is unknown, clearly label observed-capture continuity as a **proxy** and perform an explicit sensitivity analysis rather than setting all missing-capture cells to unsampled or surveyed. Once setts can be classified by sustained effort, select core/periphery categories and test V11R2 spatial posteriors against them without deriving ecological movement conclusions from an arbitrary convex hull. Prioritise getting this design step right over launching more synthetic models.


### 9 November 2026 — Explicit decision on unavailable negative trapping effort evidence

**Status: INVESTIGATOR CLARIFICATION / SPATIAL OBSERVATION DESIGN DECISION. No new fit or fabricated effort dataset.**

**Known field information:** The Woodchester database records successful captures; it does NOT contain a reliable historical panel of all trapping sessions or trap-nights, including zero-capture sessions. The monitoring programme describes the areas it trapped as *saturated* with sampling, but the investigator confirms its geographical footprint contracted over time. These claims are compatible: high intensity within a changing sampled area is not constant spatial coverage, and 'saturated' must not be equated with perfect detection or known site-quarter effort. Fixed named setts are the main encounter positions, with some non-trap recovery exceptions.

**Scientific consequence:** Do NOT infer surveyed-zero encounter occasions from missing entries or assume all 119 reference detector setts were equally available in every quarter/year. Do NOT define core by thresholding years with successful captures. Occupancy and zone transitions from V11R2 remain descriptive conditional on legacy fitted tracks, potentially influenced by assumptions on historical detector availability. Biological location/movement process and changing spatial observation footprint should be explicitly separated; animals should not be compelled to relocate when trapping contracts.

**Spatial-first design for next work:** Retain verified fixed setts and their named capture records as the *historical reference detector universe*. Construct limited, auditable **hypothetical** historical effort-footprint scenarios: (i) constant full detector network (legacy reference, knowingly unrealistic in later eras); (ii) contracting spatial footprint informed by actual capture-site patterns and investigator knowledge, with observed capture at a site-year implying it was sampled at least once but absence remaining unknown; (iii) conservative sensitivity bounds around site-year activity, including a latent/unknown category. Distinguish a potentially occupied area from trap availability; test effect on inferred activity centres, movement and boundary occupancy, and label assumptions rather than invented survey events. Before using a Poisson/Bernoulli encounter likelihood, establish its valid sampling units and no-capture semantics. Prefer simple, clearly defined era changes, not a complex unsupported latent effort model.

**Focus:** Complete a defensible spatial reference and movement model first. Leave open-population/density/immigration and infection/persistence for later, as requested. There are no supported numerical trapping-effort estimates; no database changes or novel fit performed for this clarification.


### 9 November 2026 — V11R2 fixed-versus-contracting spatial observation footprint sensitivity

**Status:** New read-only posterior reclassification code COMMITTED / NOT EXECUTED on RStudio. Not an updated likelihood, not a movement refit, not validated historical trapping effort. This is the single active spatial design test before choosing whether a coverage-aware V11R2 refit is justified.

**Question:** Given a fixed network of 119 historical sett-based trapping locations and reported saturation of the *monitored area* but no zero-capture trap records, how strongly do the existing V11R2 annual position posteriors change in their apparent geographical coverage when the observation footprint is allowed to contract? This isolates geographical observation-envelope assumptions without yet modifying the latent movement model.

**Inputs:** Existing three `V11R2_RES50_*_1932_CHAIN[123].rds` chain results; annual fixed-sett 1977–2025 positive-capture panel `outputs/v11r2_core_periphery/continuity_20261109T161513Z/02_sett_year_observed_capture_panel.csv`; reviewed read-only Supabase snapshot `data/model_snapshots/v12_20261106T103144Z_1079872` manifest. The legacy setts must match the source posterior detector XY set (checked by the script); fitted activity centres remain exactly as originally estimated, and year-specific posterior probabilities are calculated from 60 stored spatial draws/chain by default.

**Geographical scenarios:** (A) `global` = entire 119-point historical sett reference used as an active-site envelope every year (deliberately unrealistic later); (B) `era` = only sites with **at least one successful capture** somewhere within their corresponding 1977–1992, 1993–2008 or 2009–2025 era; (C) `trailing5` = site included if a successful capture occurred in the current or previous 4 calendar years. A site-year with a positive encounter is necessarily included in its scenario envelope. **Era/trailing-five envelopes are not verified deployed-trap histories** and zero captures do not demonstrate unsampled status; the use of a full-era record is retrospective and can include future capture observations within that era. Such scenarios will generally be lower-bound capture-positive extents but convex hulls can encompass unsampled interior patches. Report both P(latent annual location outside the active-site convex hull) and posterior P(within a specified distance to any active sett) plus mean nearest-sett distance; 250 m illustrative proximity is adjustable sensitivity, not a detection-kernel calibration or biological movement threshold. Reference geometry and capture coordinates are linked historically and not independently validated.

**Implementation:** `scripts/ModularFitting/Woodchester_V11R2_Contracting_Footprint_Sensitivity.R` is new, read-only and checks the complete site-year panel, detector ID/XY agreement with V11R2, chain animal-year alignment, all captured site-years represented by hypothetical envelopes, and finite spatial states. Outputs a new timestamped `outputs/v11r2_core_periphery/coverage_sensitivity_*` folder: `01_scenario_site_envelopes_by_year.csv`, `02_annual_spatial_coverage_sensitivity.csv`, `03_era_coverage_comparison.csv`, `04_posterior_state_footprint_probabilities.csv`, `05_coverage_sensitivity_time_series.png`, and documented assumptions. No existing outputs or source tables overwritten, no Supabase queries or writes.

**Run:**
```bash
cd ~/Badgers_SpatialPostDoc
git pull --ff-only
Rscript -e 'invisible(parse(file="scripts/ModularFitting/Woodchester_V11R2_Contracting_Footprint_Sensitivity.R")); cat("Syntax OK\\n")'
V12_SNAPSHOT="data/model_snapshots/v12_20261106T103144Z_1079872" \
ZONE_CONTINUITY_DIR="outputs/v11r2_core_periphery/continuity_20261109T161513Z" \
Rscript scripts/ModularFitting/Woodchester_V11R2_Contracting_Footprint_Sensitivity.R
```

**Decision gate:** Compare the three observation envelopes, especially recent years, and inspect whether outside-hull occupancy and nearest-site distances show strong dependence on assumed coverage. DO NOT say the *spatial posterior movement estimates change* in this step: it is **the same fitted posterior classified against changing envelopes**. If differences are consequential, the next scientific task is to specify and fit an explicit, era-aware observation likelihood, with conservative uncertainty about unobserved trap deployment and without inventing zero-capture visits. Preserve separation of sett location, latent activity centre and social group. Still defer survival, density, infection and transmission as requested.


### 9 November 2026 — Contracting monitoring footprint sensitivity completed; V11R2 likelihood audit identifies structural detector-availability assumption

**Status:** Existing-fit spatial footprint sensitivity COMPLETED by user (no refit). Direct original V11R2 source inspection COMPLETE. Historical detector availability NOT estimable without additional effort assumptions. A new coverage-sensitive refit is warranted **only after Supabase-first observation-input reconciliation**.

**Question:** How much does the interpretation of V11R2 activity centres depend on an always-open full historical detector footprint, versus observed-capture-evidence footprints that contracted in recent years? Does the existing detection likelihood explicitly incorporate detector-by-year/quarter availability?

**Input and successful user run:** `scripts/ModularFitting/Woodchester_V11R2_Contracting_Footprint_Sensitivity.R`, `V12_SNAPSHOT=data/model_snapshots/v12_20261106T103144Z_1079872`, `ZONE_CONTINUITY_DIR=outputs/v11r2_core_periphery/continuity_20261109T161513Z`. Three stored `V11R2_RES50` chains, 60 spatial posterior draws per chain; 8,248 fitted annual animal locations; output `outputs/v11r2_core_periphery/coverage_sensitivity_20261109T162648Z`. User attached `05_coverage_sensitivity_time_series.png`. Scenarios: global fixed historical detector hull (119 setts), era capture-positive hull (83/105/66 sett locations by 1977–1992 / 1993–2008 / 2009–2025), and trailing five-year capture-positive hull (site-year dynamic, not actual trap effort). The global/era/trailing5 footprints are hypotheses; a site-year with no capture does not establish absence of trapping.

**Numerical results** (era; scenario; n_modelled_annual_positions; range of capture-positive envelope sites; weighted mean posterior P(outside scenario hull); posterior P(within 250m of one of scenario sites)):
- 1977–1992 n=2,799: global sites119, outside .1311, near .9012; era sites83, outside .1372, near .8822; trailing5 sites9–72, outside .1968, near .8672.
- 1993–2008 n=3,805: global sites119, outside .1456, near .9231; era sites105, outside .1456, near .9188; trailing5 sites68–85, outside .1773, near .9099.
- 2009–2025 n=1,644: global sites119, outside .1318, near .9434; era sites66, outside .2768, near .9234; trailing5 sites37–63, outside .2640, near .9193.
- High initial trailing5 outside probability ~0.55 in 1977 reflects very few capture-positive sites in first rolling window, not known biological displacement. The period-specific hull gives a retrospective footprint using any capture within the era; it is not a year-by-year reconstruction of deployed traps. The wider area beyond the historical hull and convex hull interior gap interpretation need caution.

**Interpretation:** A static historical outer hull materially understates what fraction of existing fitted activity centres would fall outside the **capture-supported contemporary envelope** in the recent era (13.2% versus 27.7%). However, proximity to an observed-capture sett within 250 m differs little in recent era (~94.3% global vs ~92.3% era); thus much of the difference can arise from the geometrical hull boundary, not demonstrably remote animal locations. The locations themselves and movement parameters are unchanged across scenarios: this is a **reclassification of the same posterior** and must not be described as refitted movement results or a real emigration fraction.

**CRITICAL EXISTING LIKELIHOOD FINDING:** Direct inspection of `scripts/ModularFitting/Woodchester_V11R2_decoupled_relocation.R` shows `campaign_active[j,k]` is study-wide: if any qualifying capture occurs in a quarter, that quarter is marked active (lines ~398–411). Detection is defined by `calc_multi_quarter_prob` (lines ~568–617) in which `G_sum` sums Gaussian detector contributions across **all R detector reference locations**, and no site-specific availability indicator enters the denominator or detection hazard. For an active study-wide quarter, an individual with zero observed captures contributes `1-Pcap` using the full historical detector network, even if peripheral sites were no longer trapped; this can bias p0, sigma and inferred locations/movement. The old script sources `data/badger_encounters_useful.rds`, `data/WoodchesterSettLocations.csv`, `results/V7_population_inclusion_audit.rds` (lines ~96–100), which have not been reconciled with approved Supabase capture/sett evidence and must not become authoritative inputs for a future real-data refit.

**Decision:** Keep original V11R2 and all prior output unchanged as a legacy baseline. The next *specific spatial model* should preserve its continuous annual activity centre and resident/high-relocation process but explicitly specify a fixed-sett by quarter or year availability vector in the detection hazard `G_sum` and ensure positive capture location is always considered available. Compare (i) legacy all-site assumption and (ii) conservative, explicitly assumption-labelled contracting availability scenarios; **do not create nonexistent zero-capture trap visits or treat no capture as no effort**. The true monitoring matrix is not identifiable from positive-only capture histories, so posterior movements will be conditional on assumed deployment and sensitivity must be reported. The era/trailing5 event-based selection may itself be endogenous to capture success; treat only as scenarios, not objective effort truth. Before fitting, reconcile historic V11R2 cohort/capture locations with frozen Supabase observations using existing `scripts/data_audits/WECS_V12_compare_V11R2_legacy_to_Supabase.R` or a read-only, source-audited equivalent; identify any differences in site identity, physical encounter vs associated sett and location quality. Avoid widening scope to survival/density/infection yet.


### 9 November 2026 — Keep geographic movement continuous; distinguish annual social-group boundary shifts

**Status: SCIENTIFIC DESIGN DECISION; no new model fit.** The investigator flagged the changing historical social-group (SG) territories and their possible impact on movement interpretation while preparing a coverage-aware V11R2 spatial model. Preserve SG information but **do not** make annually changing SG polygons a hard prerequisite for the next spatial likelihood.

**Biological separation:**
1. **Physical movement:** annual continuous activity-centre coordinates and displacements in metres, including uncertainty from the V11R2 posterior. The primary latent movement process should initially remain in continuous space, independent of annual SG polygon labels.
2. **Territorial boundary movement:** annual SG polygons and their boundaries change across 1977–2025; a stationary badger's annual point may pass from one polygon to another solely because the polygons changed. Conversely a moving badger may stay within its current SG polygon.
3. **Social affiliation:** an individual’s recorded/resident SG is independent, potentially uncertain biological evidence. A capture at a sett or containment of the estimated activity centre in an SG polygon does **not** prove membership; never assign SG to UN badgers and never silently treat annual polygons as true individual resident group IDs.

**Proposed postfit movement decomposition:** Pair posterior activity-centre draws for consecutive years and overlay each pair on annual polygons. Retain probability distributions for (a) change of geographic point, (b) spatial change in SG classification caused by polygon change at a **fixed counterfactual point** (e.g. classify the same year-t coordinate under years t and t+1 boundary sets), and (c) actual path changes while holding polygon year fixed. Compare both orderings to expose non-additive boundary–movement interactions; do not claim a unique causal partition without a chosen reference convention. Use individual SG membership as a separate, evidence-qualified comparison rather than feeding forced SG labels into the primary likelihood. Keep missing/overlapping/unreviewed polygon cases unknown, and preserve source year, alias decisions and topology/geometry audit evidence.

**Modelling sequence:** First reconcile V11R2 legacy capture-sett data with curated Supabase and test detector-availability scenarios (the genuine observation-likelihood issue identified 9 November). Keep continuous-space annual movement and existing resident/high-relocation structure unchanged in the first comparison. Next overlay fitted activity-centre draws on **year-specific** audited SG polygons and quantify movement-vs-boundary contributions, comparing to fixed-reference polygon sensitivity; only if SG effects are biologically supported and identifiable consider territory-aware movement or interaction terms later. Avoid hard coding SG boundaries as barriers to movement or equating territory crossing with dispersal. This is still a spatial-first programme; disease, density and survival are deferred.


### 9 November 2026 — Decide high-confidence XY eligibility for next continuous-space spatial refit

**Status: MODEL INPUT POLICY PROPOSED; not yet audited or fitted.** Investigator recommends starting with captures where trapping-sett XY is known and reliable. Agree for the **spatial observation likelihood**, with an explicit quality/provenance audit and sensitivity to broader eligibility. Avoid defining 'known XY' as merely two finite numeric columns: must confirm source sett name, canonical identity/alias, map reference, valid location type and no unresolved conflict. Most historical `SETT_POINT_PROVISIONAL` rows likely represent fixed canonical sett-point coordinates rather than a distinct GPS measurement of each trapping event; review provenance before including them, but do not automatically exclude the dominant category. Hold unresolved, conflicting sett coordinate or association-only records until vetted; post-mortem/road recoveries are different processes, not ordinary trap detectors.

**Two evidence layers:** (1) Spatial encounters: qualifying non-PM capture episodes at named fixed setts with accepted XY, dates/quarters and unambiguous identity, retaining multiple observed sites within occasion according to established V11R2 process and episode deduplication. (2) Full histories: preserve encounters without reliable spatial XY as dated encounter evidence (and, when appropriate, captured/alive evidence), without fabricating the location or reducing individual history to a false gap. Missing spatial location is missing *spatial emission*, not automatically zero detection, death, departure or reason to exclude the entire tattoo. Separately evaluate whether original V11R2 likelihood architecture can accommodate unlocated observed encounters before inclusion in fitting; do not treat unspecified coordinates as detector locations.

**Single immediate data audit before coverage-aware fit:** From a reviewed Supabase snapshot, classify every qualifying live event by recorded location type, XY present, location quality, audited sett identity, ambiguity/override and suitability for a fixed-sett spatial likelihood; tabulate retained vs withheld source rows, unique tattoos, capture days, annual/quarterly variation, and impact on eligible observed transitions. Preserve original event IDs and classify exact duplicate/PM companion events explicitly. Compare results to legacy V11R2 cohort/sett references; stratify temporal and geographical missingness, particularly historical periphery. Produce inclusion manifest and two linked evidence streams without rewriting research data. Sensitivity: strictly verified setts, vetted canonical SETT_POINT_PROVISIONAL setts, and broader quality categories only where documented. Only after the audit consider refitting the continuous spatial movement model with alternative detector-availability assumptions. Infection/demographic models remain deferred.


### 9 November 2026 — High-confidence fixed-sett XY spatial inclusion audit prepared

**Status:** CODE COMMITTED / NOT EXECUTED ON RSTUDIO; no fit-ready data approval or model refit.

**Question:** How many eligible dated live captures have credible fixed-sett coordinates for the continuous V11R2 spatial likelihood, and how many tattoos and consecutive annual observed intervals remain if uncertain spatial coordinates are withheld? Do not discard valid dated encounters merely because the spatial emission is missing.

**Authoritative input:** A reviewed Supabase-frozen V12 snapshot: MANIFEST.txt, qualifying_live.rds and encounters.rds. Optional original V11R2 detector geometry is used as a comparison of coordinate sets only; no historical V11R2 RDS is used as authoritative encounter evidence.

**New code:** scripts/ModularFitting/Woodchester_V12_Spatial_Eligibility_Audit.R. Uses source capture_id, tattoo, date, location_type, location_quality, sett_id, XY and episode role. A fixed-sett spatial **candidate** must have finite XY, SETT location_type, a canonical sett_id, and SETT_POINT_PROVISIONAL quality. This is a conservative **candidate, NOT automatically verified/fit-ready**, classification pending sett-identity/coordinate provenance review. Missing XY, non-sett physical locations, associated setts, unresolved conflicts, unknown quality and inconsistent XY attached to sett IDs are held for review. Multiple sett IDs using the same XY also flagged, never silently resolved. Preserve all other qualifying dated encounters as evidence while excluding their untrusted coordinates from the spatial observation stream. Do not equate postmortem/dead recovery with an ordinary trap detector. Retain multiple distinct capture IDs on one tattoo-date for audit rather than collapsing them blindly.

**Output, local only:** timestamped outputs/v12_spatial_eligibility/audit_* directory, 01_inclusion_overview.csv; 02_inclusion_by_status.csv; 03_location_type_quality.csv; 04_inclusion_by_year.csv; 05_inclusion_by_year_quarter.csv; 06_source_pm_and_episode_roles.csv; 07_legacy_detector_coordinate_screen.csv; 08_EVENT_LEVEL_LOCAL_REVIEW_DO_NOT_COMMIT.csv; 09_spatial_interval_observed_gaps_LOCAL.csv; README_ASSUMPTIONS.txt. The individual-level review and gap files contain identifiers: do not commit or distribute. Historical read-only snapshot and model outputs unchanged.

**Run from repo root:**

    cd ~/Badgers_SpatialPostDoc
    git pull --ff-only
    Rscript -e 'invisible(parse(file="scripts/ModularFitting/Woodchester_V12_Spatial_Eligibility_Audit.R"));cat("Syntax OK\n")'
    V12_SNAPSHOT="data/model_snapshots/v12_20261106T103144Z_1079872" \
    ZONE_AUDIT_DIR="outputs/v11r2_core_periphery/audit_20261109T134751Z" \
    Rscript scripts/ModularFitting/Woodchester_V12_Spatial_Eligibility_Audit.R

**Decision:** Review eligibility status, year/quarter and peripheral-location patterns, loss of spatially paired annual transitions and identity/coordinate consistency. Obtain investigator approval for a fixed-sett XY inclusion rule before generating any fit-ready spatial model inputs. Then compare a coverage-aware V11R2 observation likelihood under explicit hypothetical detector availability scenarios. No demographic/disease or SG territory changes in this gate.


### 9 November 2026 — Curated Supabase fixed-sett XY eligibility screen completed

**Status:** READ-ONLY DATA ELIGIBILITY AUDIT COMPLETE; spatial input inclusion approval PENDING. No model fit, no data mutation, no trapping-effort reconstruction.

**Scientific question:** How much of the full curated qualifying live encounter series is usable for a reliable fixed-sett spatial likelihood, and what observed annual movement information is lost by withholding unresolved spatial positions while retaining their dated observations?

**Inputs and settings:** Frozen read-only Supabase evidence snapshot `data/model_snapshots/v12_20261106T103144Z_1079872`, years 1977–2025, script `scripts/ModularFitting/Woodchester_V12_Spatial_Eligibility_Audit.R`, optional existing legacy V11R2 detector-coordinate reference. User executed successfully; result directory `outputs/v12_spatial_eligibility/audit_20261109T163932Z`. Retains source capture ID, tattoo/date and source event status separately from spatial-coordinate eligibility. Provisional fixed-sett XY are *candidates*, not yet approved verified inputs.

**Results:** 16,218 qualifying live source rows in 1977–2025 and 3,204 observed tattoos. 15,521 candidate fixed-sett capture rows (95.70% of live rows), 3,143 tattoos with at least one spatial-candidate capture (98.10% of all observed tattoos), 697 withheld/reviewed spatial encounters (536 missing XY, 161 non-sett locations with XY). No candidate canonical sett IDs have multiple distinct XY; no XY points were shared by separate candidate sett IDs. No tattoo/date duplicates appeared under this snapshot filtering. Previous all-years summary of 16,230 rows and 3,214 tattoos includes pre-1977 observations omitted here (12 records and 10 tattoos in the full snapshot relative to this window; this difference does not necessarily mean each excluded tattoo has exactly one record).

**Observed annual movement support:** 4,693 consecutive *observed-year* tattoo pairs in the all-encounter series; 4,484 pairs (95.55%) have at least one spatial-candidate capture in both years; 209 lack spatial candidates in one/both years. 5,190 intervals between successive spatially observed years, of which 64 contain at least one intermediate year with dated unlocated encounter(s). These metrics are **not** a validation of latent unobserved-year movement; V11R2 also fills years between first and last observation under assumptions.

**Recent annual eligibility:** 2016 196/197, 2017 171/171, 2018 263/267, 2019 219/221, 2020 112/115, 2021 142/143, 2022 70/70, 2023 36/36, 2024 66/66, 2025 68/68. Most recent records retain known candidate sett XY; historical years still need inspection for disproportionate missingness. Candidate total is not equivalent to V11R2 original selected cohort of 1,932 animals: that cohort and its movement-eligible criteria require a separate, documented reconciliation with curated evidence.

**Limitations and pending decision:** Provisional SETT_POINT_PROVISIONAL means coordinates were assigned from canonical fixed-sett reference locations; this is appropriate in principle for captures known to be at that sett, given investigator confirmation of fixed trapping sett coordinates, but exact identity/alias and source provenance need review before approval. The 161 non-sett locations may include genuine off-sett live encounter types; do not force to an associated sett. Missing XY events can count as dated encounters but their observation likelihood requires explicit handling to avoid incorrectly coding a detected animal as absent. No age/sex/cohort/quarter or detection model fitted in this screen; no claim of 3,143 model-fit-ready badgers.

**Single next gate:** Review `03_location_type_quality.csv` and `07_legacy_detector_coordinate_screen.csv` from `outputs/v12_spatial_eligibility/audit_20261109T163932Z`; inspect status breakdown of withheld 161 off-sett entries and any candidate points not equal to known legacy sett XY. If coherent and approved, freeze a high-confidence spatial event filter with explicit use of missing-location encounter evidence and document discrepancy from legacy V11R2 cohort. Only then design/fit detector-availability sensitivity. Keep annual SG polygons external and defer survival/infection/density.


### 9 November 2026 — Spatial fixed-sett quality-category and legacy-coordinate cross-check

**Status:** Existing Supabase snapshot eligibility details REVIEWED; final coordinate exceptions check CODE COMMITTED / NOT RUN ON RSTUDIO. No spatial refit yet.

**Question:** Are dominant provisional fixed-sett XY values sufficiently coherent to support the primary V11R2 coverage-aware spatial observation likelihood, and where do unlocated or non-sett records affect the sampling history?

**Input/results:** User printed `03_location_type_quality.csv`, `07_legacy_detector_coordinate_screen.csv` and early-year rows of `04_inclusion_by_year.csv` from `outputs/v12_spatial_eligibility/audit_20261109T163932Z`. Of 16,218 qualifying live rows (1977–2025), 15,521 carry `SETT | SETT_POINT_PROVISIONAL` and meet candidate fixed-sett criteria; 536 lack XY, 161 have XY but are non-SETT location types. In the candidate data, 15,518 match exactly one legacy V11R2 detector reference XY; 3 do not match exactly and 1 is more than 100 m from nearest legacy point. Exact agreement is expected where the same canonical sett point was used for both datasets, not independent capture-position verification. The non-sett/uncertain categories include 159 `SETT_ASSOCIATION | SETT_ASSOCIATION_PROVISIONAL` and field/wood/boundary records with unresolved locations or conflict; do not treat an assigned sett as the physical trapping site. Note that `SETT | UNRESOLVED` 301 is held because missing/untrusted XY, not an approved observer location.

**Temporal missingness:** 1977 only 29 of 47 (61.7%) eligible live capture rows are spatial candidates; 1978 101/116, 1979 97/106, 1980 77/92, 1981 103/136, 1982 143/153, 1983 212/240, 1984 251/263, 1985 305/309, 1986 298/316, 1987 364/393, 1988 539/576. Recent years mostly retain nearly all records. Early versus late spatial exclusion is therefore nonuniform and must be reported in any fitted movement analysis.

**Decision:** Provisionally approve the class of `SETT_POINT_PROVISIONAL` **as candidates** for known fixed-sett capture XY, given investigator confirmation that trap positions are fixed named setts, subject to exactly three source-coordinate exceptions and alias/sett identity reconciliation. Do not silently approve remaining doubtful records or discard their dated alive encounters. These 15,521 records are not yet the full movement-model fitting population: cohort eligibility and legacy-to-Supabase source-row changes remain to be reconciled. No trapping-effort data are available; eventual dynamic observation availability scenarios must remain explicit assumptions.

**New targeted local-only script:** `scripts/ModularFitting/Woodchester_V12_Spatial_Coordinate_Exceptions.R`, reading event-level review CSV from eligibility audit and legacy detector reference CSV. Prints source capture ID, tattoo, capture date, canonical sett ID, location type/quality, current source XY, closest legacy named sett/XY and distance for non-exact matches. No database writes, coordinates changed or fit eligibility automatically adjusted. Run:

    cd ~/Badgers_SpatialPostDoc
    git pull --ff-only
    V12_ELIGIBILITY_DIR="outputs/v12_spatial_eligibility/audit_20261109T163932Z" \
    ZONE_AUDIT_DIR="outputs/v11r2_core_periphery/audit_20261109T134751Z" \
    Rscript scripts/ModularFitting/Woodchester_V12_Spatial_Coordinate_Exceptions.R

**Next gate:** Review the 3 actual source exceptions and clarify their coordinates and sett identities. Then make a reproducible, investigator-approved spatial input manifest and compare with the original V11R2 1,932-badger movement cohort before modifying/refitting likelihood. Continuous activity centres remain the primary spatial process; moving annual social-group polygons are a separate postfit interpretation step.


### 10 November 2026 — Three fixed-sett coordinate exceptions and BIGINT CSV ID printing defect

**Status:** TARGETED EXCEPTION REVIEW INITIATED; original data untouched; read-only R code fixed on GitHub, not yet rerun on RStudio.

**Observed original result:** Of 15,521 candidate fixed-sett encounter rows, 15,518 have exact XY equality with nearest legacy V11R2 detector; three are non-exact, of which one is >100 m. The displayed exception cases were: tattoo 002W, 2005-05-04, source XY (382191,199820), closest historical detector HOGARTHS (382627,200053), distance 494.353 m; tattoo H044, 1998-09-08, source XY (380742,201140), nearest CHESNUT (380834,201150), distance 92.542 m; tattoo D042, 1997-07-08, XY (382956,201126), nearest NETTLE (383024,201142), distance 69.857 m. DO NOT force the coordinates onto the nearest historic detector, infer false source error or silently delete; the correct source sett identity/recorded-name alias and reference provenance must be checked first. These three may be genuine additional/renamed sett points not present in the legacy detector universe. Original source coordinates are not independently validated by historical matching.

**BUG:** The output of the original `Woodchester_V12_Spatial_Coordinate_Exceptions.R` printed capture_id and sett_id as tiny subnormal doubles (e.g. 5.48e-320). These are NOT genuine identifiers: RPostgres BIGINT/bit64 fields were carried through local CSV without a safe explicit character conversion. Do not use the displayed ID numbers for matching or correction. Scientific tattoo/date/XY and count remain interpretable. GitHub scripts have been corrected to cast capture_id and sett_id from the original frozen `qualifying_live.rds` data to decimal character strings before any local CSV export or reporting; the focused exceptions script now ignores the earlier potentially damaged ID columns and reads the frozen RDS directly. The full eligibility audit script also casts these source IDs as characters before CSV output; this ensures any future regenerated local review files have readable source IDs. No source mutation, no erroneous post-hoc decoding of corrupted CSV bit patterns.

**Next specific command:**

    cd ~/Badgers_SpatialPostDoc
    git pull --ff-only
    V12_SNAPSHOT="data/model_snapshots/v12_20261106T103144Z_1079872" \
    ZONE_AUDIT_DIR="outputs/v11r2_core_periphery/audit_20261109T134751Z" \
    Rscript scripts/ModularFitting/Woodchester_V12_Spatial_Coordinate_Exceptions.R

The command reports true capture_id, canonical sett_id, capture date, tattoo, curated XY, nearest historical detector/XY and distance; when legacy encounter RDS is available, it also prints recorded historical sett text matched by tattoo/date as *context only* (not a unique event ID match). Review the 3 names and coordinates before approving the candidate set for fit. Original V11R2 and event histories unchanged; no new fitting work launched. Existing spatial data screening remains 15,521 candidate setts and 697 held spatial events, pending source approval.


### 10 November 2026 — Three coordinate discrepancies linked to original recorded sett names; integer64 reporting fix

**Status:** User reran the frozen-source exception check successfully at commit `5bdea56`; ID-formatting defect persisted because as.character on PostgreSQL BIGINT fields was not guaranteed to dispatch the bit64 conversion method. Scripts corrected in subsequent commits to explicitly use `bit64::as.character.integer64` (with an explicit original-byte reinterpretation only when the source column has lost integer64 class). New correction NOT YET RERUN ON RSTUDIO.

**Source facts:** Candidate fixed-sett rows: 15,521; exactly 15,518 match historical V11R2 detector XY; three do not, one beyond 100m. User reported 002W 2005-05-04 at (382191,199820), nearest legacy HOGARTHS ~494.353 m, recorded legacy sett text PEN; H044 1998-09-08 at (380742,201140), nearest CHESNUT ~92.542m, old sett text NA; D042 1997-07-08 at (382956,201126), nearest NETTLE ~69.857m, old sett text STUMP. Original legacy text match is based on tattoo + capture date, so does not uniquely prove same event identity. PEN and STUMP may be legitimate differently named detector sites not represented in historical reference network; do not snap to nearest or discard without an audited original sett record.

**Identifier issue:** Displayed tiny decimals (e.g. 5.48462273448368e-320) are IEEE-754 reinterpretations of 64-bit integer bit patterns, not actual capture IDs. Their raw bit patterns correspond to plausible capture IDs 11101, 12031, 12071 and sett IDs 111, 29, 50 respectively. These decoded integers are **provisional**, requiring source confirmation using explicit `bit64::as.character.integer64` applied before any CSV export/printing; absence of correct S3 method loading can yield erroneous subnormal double text even when integer64 class is present. Do not use the decimals for record joins.

**Action:** Both `Woodchester_V12_Spatial_Coordinate_Exceptions.R` and `Woodchester_V12_Spatial_Eligibility_Audit.R` now explicitly convert original BIGINT columns with bit64 before printing/export, including a fail-closed test for mixed unclassed-bit pattern and ordinary numeric fields. Run the focused exception script after git pull, then check canonical sett-name reference for IDs 111/29/50 to decide whether coordinates genuinely represent additional/renamed historical setts. Do not rerun the entire 16k-row audit merely for this display fix. Remaining spatial data inclusion policy unchanged; the full encounter history is preserved; no fitted model, research table, source snapshot or biological location has been altered.

**Next model gate:** After confirming the three source sett identities and coordinates, freeze a defensible high-confidence spatial observation event selection, reconcile the approved population with legacy V11R2 movement eligibility and capture history, then implement/fit the alternative detector-availability model. The continuous geographic movement process stays unchanged and time-specific SG polygons remain separate postfit movement interpretation.


### 10 November 2026 — Original Supabase capture-source review resolves three off-legacy-detector XY exceptions

**Status: ORIGINAL RECORDS INSPECTED IN READ-ONLY SUPABASE / NO MUTATIONS.** Direct `research.captures` and joined `analysis.encounters_clean_v1`, `research.setts`, `analysis.capture_location_v1`, `analysis.capture_sett_alias_audit_v1` were queried for source capture IDs 11101, 12031, 12071. All are original `moc=TRAP`, `capture_location_text=SETT`, `encounter_type=TRAP`, `location_type=SETT`, and `location_quality=SETT_POINT_PROVISIONAL`, with observed original named trapping setts and exact agreement between curated encounter XY and their canonical fixed-sett XY.

**Capture 11101:** tattoo 002W, 2005-05-04, original and canonical sett **PEN** (sett_id 111; BNG XY 382191,199820); original free-text comment explicitly says badger trapped/collared in a husbandry project at Tinkley Farm; original SG text PEGLARS, not definitive membership proof. Nearest legacy V11R2 detector HOGARTHS is 494.353 m away but is **not** its original trapping sett. Canonical fixed coordinate source: `WoodchesterSettLocations (1).csv; source Sett_Upper=PEN`.

**Capture 12031:** tattoo H044, 1998-09-08; original sett **STONEY TRACK**, harmonised canonical **STONY TRACK** (sett_id 29; XY 380742,201140), source `WoodchesterSettLocations (1).csv; source Sett_Upper=STONEY.TRACK`. Existing alias audit identifies a researcher-approved STONEY TRACK -> STONY TRACK spelling rule (2026-11-04) for a SETT TRAP with provisional point coordinates. Original recorded SG BEECH, not proof of physical sett membership. Original V11R2 capture sett name was NA, but **the research capture source is populated**; `analysis.capture_location_v1` returns location_view_sett null and spatial_interpretation REVIEW_OR_MISSING even though `analysis.encounters_clean_v1` resolves the canonical sett and XY. This is a **cross-view classification discrepancy to explain**, not a reason to overwrite the capture or undo the accepted alias. Nearest legacy CHESNUT 92.542 m away is a separate location.

**Capture 12071:** tattoo D042, 1997-07-08; original/canonical **STUMP** (sett_id 50; XY 382956,201126), coordinate source `WoodchesterSettLocations (1).csv; source Sett_Upper=STUMP`. Original SG NETTLE (not proof of matching capture sett). Nearest legacy NETTLE detector 69.857 m away; not a justification for snapping or merging.

**Additional positive-capture count check:** In the current cleaned view, each of canonical PEN, STONY TRACK, STUMP has **exactly one** `TRAP` record with `location_type=SETT`, on the listed historical capture date. They are legitimate rare, fixed-sett capture locations with canonical point provenance, **not evidence of repeated monitoring or known no-capture effort**. The existing V11R2 119-detector set omits their XY, so the vetted Supabase spatial capture set could contain at least 122 distinct detector points before final source validation; do not equate that with a verified count of all active detectors at any time.

**Scientific decision:** Treat the three captures as eligible **candidate** fixed-sett spatial observations at their own canonical PEN, STONY TRACK and STUMP coordinates, conditional on the already stated provisional-sett-point assumption; do not snap to nearest legacy detector, remove or overwrite without evidence. Retain provisional provenance and the unresolved cross-view STONY TRACK discrepancy in the audit notes. Source IDs are confirmed directly in Supabase, and earlier integer64 display issue is resolved by `bit64` casting on the server. **Next step** is reconciliation of new curated candidate spatial captures and their three additional detector points against the old 1,932-animal V11R2 movement cohort and extraction rules before modifying the detector-availability likelihood. Do not restart broad coordinate audits. Spatial continuous-space movement first, annual SG boundary movement as later postfit overlay.


### 10 November 2026 — Global capture-to-sett ID, canonical XY, alias and analytical-view consistency audit

**Reason:** Investigator correctly queried why three legitimate named-sett captures with known coordinates were flagged against old V11R2 detector geometry and asked whether *all* capture-to-sett links should be checked. A read-only joined **whole-database** Supabase audit was performed (not just the three records), with `research.captures`, `analysis.encounters_clean_v1`, `research.setts`, `analysis.capture_sett_alias_audit_v1` and `analysis.capture_location_v1`. NO DB WRITES, no source edits or movement fits.

**Whole database totals (current live November 10):** 17,586 research capture rows; 16,346 linked cleaned `sett_id` records; **zero** cleaned sett IDs without a corresponding `research.setts` row; **zero** rows where both raw and cleaned sett IDs exist but differ; **zero** rows where an explicit audited alias `canonical_sett_id` disagrees with cleaned sett ID. For 15,740 `location_type=SETT` and `location_quality=SETT_POINT_PROVISIONAL` source records: **zero** coordinate mismatches between cleaned event XY and the joined research.setts canonical XY; **zero** missing settled IDs or missing canonical sett coordinates. These are joins/internal logical checks: they do **not** independently verify that a canonical sett XY is correctly surveyed or that a free-text capture name was correctly mapped biologically.

**Cross-view divergence:** Exactly **four** provisional fixed-sett records have canonical sett name absent and `spatial_interpretation=REVIEW_OR_MISSING` in `analysis.capture_location_v1`, despite cleaned `analysis.encounters_clean_v1` correctly resolving source aliases and fixed-point coordinates: source capture 12031 original STONEY TRACK → canonical STONY TRACK, plus 14456,14457,14458 original WEST MAIN → canonical WEST. Explicit approved `analysis.capture_sett_alias_audit_v1` records confirm these aliases. For WEST MAIN records (June 1999), investigator already approved exact alias WEST sett 35 while preserving recorded WYCH ELM social-group text independently; no reason to overwrite that group assignment. This is **stale/inconsistent view interpretation**, not a wrong XY join. Fix/refresh the view in a separately reviewed, versioned migration after understanding its definition; do not silently alter data/views during spatial fitting.

**Whole-source textual canonical name discrepancies:** Of the same 15,740 provisional fixed-sett records, 361 have original `recorded_sett_name` text not exactly equal to linked canonical `research.setts.sett_name`. Four are explicitly recorded in the capture-level alias audit (STONEY TRACK→STONY TRACK one, WEST MAIN→WEST three). The other 357 form only two distinct patterns: **TOP SETT→TOP (349 records)** and **TODDS→TODD'S (8 records)**, consistent with conventional historic name standardisation but not supported by entries in the specific capture-level alias audit view; need to make sure they are documented in the overall name-cleaning rules/provenance rather than incorrectly labeling them four hundred join errors. All 361 have valid canonical IDs and exact canonical XY; a name mismatch alone does not establish an erroneous assignment.

**Clarification of earlier flags:** The three records 11101 PEN, 12031 STONY TRACK and 12071 STUMP were flagged because their *correct canonical fixed-sett XY* were not present in the old 119-site V11R2 detector universe, which is a selected legacy modelling reference, not the complete canonical sett registry. Nearest legacy sett distance is **not** evidence of bad source coordinates. All three are rare single known-TRAP named sett records. Keep their own canonical coordinates.

**Decision:** The database-wide referential and XY join audit has PASSED, so no reason to repeat an open-ended matching exercise or 'snap' coordinates to nearby legacy detectors. Distinguish **internally consistent fixed-sett assignments** from **independent field confirmation of physical XY**. Preserve historical original-name strings and aliases. The four capture-location-view discrepancies should be documented/fixed via a separate reviewed view migration, not changed inside a live modelling audit. Next spatial work is to reconcile **curated qualifying captures and movement cohort selection** with the original V11R2 1,932-badger model, preserving missing-location live observations and explicitly hypothesizing detector availability; moving SG boundaries remain a post-fit overlay.


### 10 November 2026 — Explicit TOP SETT and TODDS spatial name decisions applied

**Completed database-cleaning provenance task, not a movement model fit.** After the database-wide capture–sett referential/XY check, investigator requested explicit permanent documentation and applied rules for `TOP SETT→TOP` and `TODDS→TODD'S`. Existing canonical IDs/XY were already correct; only capture-specific approval provenance was missing. Applied guarded read-only-prechecked SQL transaction to `research.capture_sett_alias_decisions`: 349 qualifying TOP SETT captures (canonical TOP sett 20) and 8 TODDS captures (TODD'S sett 158). Nine additional TOP SETT source rows were outside the qualifying fixed-sett encounter subset and were not reinterpreted as trap locations. No raw names, coordinates, groups or outcomes changed. Verification in live Supabase confirmed 349+8 alias decisions and zero cleaned-canonical provisional sett XY mismatches.

**Recorded implementation:** `sql/migrations/20261110_top_sett_todds_capture_alias_decisions_APPLIED.sql` is an exact executed SQL copy and `sql/audit/WECS_SETT_ALIAS_RULE_INTEGRITY_20261110.sql` is an ongoing read-only regression test. Documentation in `docs/database/02_MASTER_DATA_DICTIONARY_AND_AUDIT.md` and `docs/database/03_VERSIONING_AND_DECISIONS.md` was updated. This was a direct SQL data transaction, **not** a registered Supabase schema migration; do not count it in historic migration totals or replay on the live database. Future records need a source-backed capture-level decision, not just an implicit text join. Frozen input snapshots remain immutable and may predate this additional provenance; regenerate a new frozen snapshot only when beginning a new fit.

**Next:** Finish reconciliation of curated fixed-sett capture observations and the original 1,932 badger V11R2 cohort, then implement a coverage-aware detection likelihood. Continuous-space movement remains the primary process; annual SG polygons are a separate postfit stage.


### 10 November 2026 — V11R2 historical movement cohort versus curated Supabase snapshot, comparison script ready

**Status: CODE COMMITTED / NOT RUN ON EXETER SERVER / NOT A REFIT.**

**Question:** If we retain exactly the 1,932 movement-eligible tattoos used in V11R2, how do the dated spatial captures and annual modelled span from old local RDS/alias/detector inputs differ from the audited 1977–2025 Supabase frozen capture history? How many additional individuals are present outside the historic fitting cohort? Does the new canonical sett-point geometry include physical sites not present in the historical 119-location network?

**Read-only script:** `scripts/ModularFitting/Woodchester_V12_V11R2_Cohort_Reconciliation.R` uses historic `results/V7_population_inclusion_audit.rds` and `data/badger_encounters_useful.rds` solely to reproduce old inclusion/geometry, `data/WoodchesterSettLocations.csv` for historic detector-coordinate matching, and vetted Supabase `qualifying_live.rds` from immutable `data/model_snapshots/v12_20261106T103144Z_1079872`. The old alias function is deliberately reproduced ONLY for historical parity; any unsafe old name merges must NOT be propagated into the new model. New fixed-sett candidate requires finite XY, canonical sett_id, SETT location type and SETT_POINT_PROVISIONAL quality, with original nonspatial encounters retained in the full evidence.

**Output:** `outputs/v12_v11r2_reconciliation/run_<UTC>/` 01 overall numbers, 02 tattoo/date status, 03 old-cohort per-tattoo years/latent states/intervals, 04 changed tattoo-date rows, 05 canonical detector XY versus old CSV and 06–07 old/new cohort exceptions. Sensitive individual-level files remain local and should never be Git committed. A tattoo/date match checks existence and row count, **not source capture ID identity, same-day independence, or correct sett mapping**. No assumptions of documented zero-capture trap effort. Full years between first and last capture are latent annual model states, not directly observed capture years. No continuous-space parameters are refitted, no SG polygons are assigned.

**Run:**

    cd ~/Badgers_SpatialPostDoc
    git pull --ff-only
    Rscript -e 'invisible(parse(file="scripts/ModularFitting/Woodchester_V12_V11R2_Cohort_Reconciliation.R"));cat("Syntax OK\n")'
    V12_SNAPSHOT="data/model_snapshots/v12_20261106T103144Z_1079872" Rscript scripts/ModularFitting/Woodchester_V12_V11R2_Cohort_Reconciliation.R

**Decision gate:** Review exact old-cohort counts, capture-date discrepancies, changes in first/last spatial observation years and hence annual movement spans, and number of new vetted fixed-sett sites. Do not assume the spatial eligibility audit's 3,143 observed tattoos are all fit-ready movement trajectories. Only then freeze spatial observation input and compare historically always-open versus transparently hypothesised detector-availability models, while preserving an explicit observation state for captured-but-unlocated events.


### 10 November 2026 — Cohort reconciliation first-run R aggregation fix

**Status: ERROR REPORTED / SCRIPT PATCH COMMITTED / NOT YET REEXECUTED ON RSTUDIO.** First run of `scripts/ModularFitting/Woodchester_V12_V11R2_Cohort_Reconciliation.R` against frozen Supabase `v12_20261106T103144Z_1079872` terminated in `annualspan` at `do.call(rbind, z$x)` with `second argument must be a list`. Reason: base R `aggregate` may simplify a function returning a vector into a matrix, not a list. Replaced annualspan with explicit per-tattoo `split`, deterministic `vapply` min/max/count, preserving intended derived annual latent-state and interval definitions; no data/model/DB modification. This is a code correction only, not scientific evidence or a successful audit run. Re-run the same command after `git pull --ff-only`; assess results before approving any spatial refit.


### 10 November 2026 — First legacy V11R2 versus frozen Supabase cohort reconciliation output (annual totals bug identified)

**Status: FIRST COMPARISON RAN; POPULATION/CAPTURE/DATE COUNTS ARE PRELIMINARY; SIX ANNUAL MODEL-SPAN TOTALS IN REPORTED OUTPUT ARE INVALID ZEROS.** This is input-data comparison only, not a model refit.

**User-reported results:** Old movement population 1,932 tattoos; 14,049 legacy spatially mapped capture rows, all 1,932 tattoos. Among the exact historic 1,932 tattoos, curated Supabase evidence has 14,395 qualifying live rows, 13,840 candidate spatial rows and 1,931 tattoos with at least one mapped capture (one old-cohort tattoo now has no candidate mapped capture). The entire curated 1977–2025 snapshot contains 16,218 qualifying live rows, 15,521 candidate spatial rows and 1,272 tattoos outside the original movement-eligible population, of which 1,212 have candidate mapped captures. Old-cohort new spatial sett IDs = 119, same numeric count as old detector sites; 121 distinct new spatial sett IDs in the full current cohort. 571 tattoo-date screening discrepancies: 360 ONLY_CURATED, 14 ONLY_LEGACY, 197 SPATIAL_DATE_ROW_COUNT_CHANGED, plus 13,838 matched spatial row counts. These categories require event-level biological reconciliation; dates alone do not prove same capture episode nor indicate movement evidence gained/lost.

**Bug caught after first run:** All six reported annual states/intervals totals erroneously displayed zero. The script renamed columns with `legacy_`, `curated_spatial_`, `curated_all_live_` but subsequently summed original non-existent column names, making R `sum(NULL)` equal zero. Patched script now sums prefixed column names and guards against impossible zero movement totals. This correction is **committed but not yet run on the user's server**. No source, snapshot, fit or DB modifications. Do not interpret the reported zero annual intervals as no modelled movement or as a legitimate result. Re-run after `git pull --ff-only`; the expected historical V11R2 reference previously had 8,248 annual activity-centre states and 6,316 annual intervals, subject to reproducing exactly its original censoring/eligibility and mapped records. Do not presume exact numerical parity until re-run.

**Scientific interpretation:** This stage compares **old V11R2 modelling data** with **cleaned, frozen Supabase encounter evidence**, keeping the old 1,932-badger sample constant. It does NOT yet test movement-rate differences, refit movement, justify adding 1,272 tattoos, or reconstruct real detector availability. Before refitting, resolve the one old-cohort badger without clean XY, audit the 571 date-level differences by original capture ID and clarify the model eligibility rule.


### 10 November 2026 — Corrected old-cohort annual-state reconciliation succeeded; follow-up triage ready

**Status: V11R2-SUPABASE COMPARISON RAN SUCCESSFULLY (DATA RECONCILIATION ONLY); focused annual-span triage CODE COMMITTED / NOT YET RUN.** The user reran `Woodchester_V12_V11R2_Cohort_Reconciliation.R` using frozen `data/model_snapshots/v12_20261106T103144Z_1079872`. It now reproduces the V11R2 reference *exactly*: **1,932 historic movement-eligible tattoos**, **14,049 mapped captures**, **8,248 latent annual positions**, **6,316 annual transition intervals**. For those same 1,932 tattoos, curated Supabase has 14,395 qualifying live encounters, 13,840 candidate fixed-sett mapped captures involving 1,931 tattoos, 8,187 spatial-only annual positions and 6,256 between-first-and-last-mapped-year annual intervals; one old tattoo lacks a curated fixed-sett capture. When annual encounter evidence with unknown/not approved XY is retained for time-window determination, curated cohort has **8,322 positions and 6,390 intervals**. Those longer spans alone do not specify a valid spatial movement likelihood; unlocated alive observations must not be misinterpreted as spatial detections or known trapping non-detections.

**Whole snapshot:** 16,218 qualifying live 1977–2025 rows, of which 15,521 are provisional fixed-sett spatial candidates. 1,272 curated tattoos are outside original movement-eligible population, of which 1,212 have one or more mapped captures; NO decision yet to add them. The old-cohort vetted spatial sites number 119 canonical sett IDs; entire curated fixed-sett set spans 121 canonical sett IDs. These numeric totals are not a verified geographic one-to-one matching of site identities nor trapping-effort schedules. 571 tattoo-date screening discrepancies: 360 ONLY_CURATED, 14 ONLY_LEGACY, 197 SPATIAL_DATE_ROW_COUNT_CHANGED, alongside 13,838 matched mapped-count combinations. A tattoo/date key cannot establish source-row identity or explain date changes by itself.

**Next code:** `scripts/ModularFitting/Woodchester_V12_V11R2_Reconciliation_Triage.R` reads only the existing local reconciliation output (no database and no re-fit), checks historical annual totals, names the one missing spatial tattoo, reports the number of old-cohort badgers with first/last observation years earlier/later, decomposition of annual-span lost/gained by badger, and timing/status of the 571 date-level discrepancies. Output is terminal summaries, sensitive individual histories remain in existing local output files. Set `V12_RECONCILIATION_DIR` to most recent run directory and call the script; then audit relevant exceptions and define input eligibility/observation treatment before any new V12 spatial model is fit.


### 10 November 2026 — Legacy spatial cohort span-change triage and J011 original capture review

**Status: LOCAL READ-ONLY TRIAGE EXECUTED / J011 SOURCE RECORDS VERIFIED IN LIVE SUPABASE / NO MODEL RE-FIT OR SOURCE CORRECTION.** The original V11R2 movement window correctly reproduces 8,248 annual latent centres and 6,316 annual intervals for 1,932 tattoos. At the **same fixed tattoo cohort**, provisional fixed-sett spatial observations alone imply 8,187 annual centres, 6,256 intervals, 1,931 spatially observed tattoos (one missing); full qualifying live encounters imply 8,322 annual centres and 6,390 intervals. Spatial-only span: 38 old-cohort tattoos have shorter annual spans, 0 longer and 1,894 unchanged; sum negative difference 60 intervals. Full-live span: 11 shorter, 56 longer, 1,865 unchanged; sum losses -16 and gains +90 = net +74. First-year: spatial cohort 9 later and none earlier; full live 24 earlier and none later. Last-year: spatial cohort 28 earlier and none later; full live 11 earlier and 35 later. Date-level discrepancy screening: 360 only curated, 14 only legacy, 197 different spatial counts at a tattoo+date combination, involving 365 distinct tattoos. All numbers are descriptive input-span diagnostics, NOT observed movement events or biological movement/detection estimates; tattoo/date equality alone does not prove event identity.

**J011 original source investigation:** Original `research.captures` joined to `analysis.encounters_clean_v1` and individual tattoo shows 4 qualifying dated live encounters at original recorded `FIELD FARM` with canonical sett_id 139 and reference XY E380936 N199687, BUT original `capture_location_text` is NULL; hence curated `location_type=SETT_ASSOCIATION` and `location_quality=SETT_ASSOCIATION_PROVISIONAL`, not an established fixed-sett trap position. IDs 4630 (1998-05-19, MOC TRAP), 4633 (1998-07-28, MOC TRAP), 4634 (1998-10-07, source MOC null, classified TRAP), 4635 (1999-01-26, source MOC null, classified TRAP). The original PM death/recovery 17354 (1999-05-30) has `RTA`, `ST DAVID'S LANE ADJACENT TO FIELD FARM`, original OS reference 811994, curated `location_type=ROAD`, `location_quality=GRID_REFERENCE_CORRECTED_PROVISIONAL`, XY E381100 N199400. The RTA must not turn FIELD FARM into a known fixed capture detector. J011 retains temporal live and death evidence, but has no high-confidence physical capture XY. No erroneous canonical-sett ID/XY join was found. Do not snap J011 to canonical FIELD FARM location without capture-provenance evidence; do not interpret its exclusion from fixed-sett *spatial* likelihood as absent from the full CMR observation history.

**Model-design consequence:** Spatial likelihood may use fixed-sett trapping captures where location type and provenance support this; time-known but spatially unresolved encounters should be represented as alive evidence with location uncertainty, or their handling made explicit in a controlled sensitivity analysis. Distinguish dates of capture, possible trapping campaigns, death recovery, first/last observation years, and detector effort. No model refit until mapped capture-by-date differences (365 tattoos) are categorised sufficiently to avoid conflating old input changes with new detection-likelihood assumptions.


### 10 November 2026 — Investigator correction: J011 FIELD FARM captures and RTA location should be retained

**Status: EARLIER CONSERVATIVE SPATIAL-ELIGIBILITY INTERPRETATION SUPERSEDED; SOURCE/DB UNCHANGED, MODEL INPUT RULE UPDATE REQUIRED BEFORE REFIT.**

The investigator clarified that **FIELD FARM is an accepted canonical trapping sett with a known fixed reference XY**, and that original J011 capture records identifying FIELD FARM should be treated as valid recorded trapping events even when the separate `capture_location_text` is NULL. Original J011 live capture IDs 4630 (1998-05-19), 4633 (1998-07-28), 4634 (1998-10-07), 4635 (1999-01-26) all record FIELD FARM, sett_id 139, canonical E380936 N199687, current live `encounter_type=TRAP`. Source MOC is TRAP for first two, missing for latter two but independently curated as TRAP. **Accept these four as provisional fixed-sett spatial captures**, with named-sett-point (not trap-microposition) provenance. Earlier decision to withhold all four solely because original `capture_location_text` was blank was unnecessarily conservative and is **superseded**. Current `analysis.encounters_clean_v1` may still classify them SETT_ASSOCIATION_PROVISIONAL; do not conflate that historic generic view label with an investigator's source-supported modelling decision. A future audited input derivation must incorporate these specific reviewed decisions explicitly, without globally promoting all `SETT_ASSOCIATION` records or modifying original source strings. No migration or eligibility-code change has yet been executed for that promotion.

The distinct J011 death/recovery ID 17354 (1999-05-30), `RTA`, recorded St David's Lane adjacent to FIELD FARM, original grid text 811994, corrected BNG E381100 N199400, `GRID_REFERENCE_CORRECTED_PROVISIONAL`, is **accepted as a geographically referenced death recovery** at stated grid-cell precision, not as a live fixed-sett detection or exact site measurement. Preserve the death record and its separate location; do not transfer it onto FIELD FARM sett XY.

**General corrected scientific rule:** An accepted named fixed sett with a known canonical XY, credible trapping evidence, and no contradictory non-sett location evidence can support a provisional fixed-sett capture observation **even when the ancillary capture-location-type field is NULL**. This is distinct from a mere social-sett association, a non-sett field/wood/hedge capture, or a grid-derived recovery site. Make positive provenance decisions explicit and review possible analogous records before a V12 model fit; do not classify all null-location records as fixed traps by default. The previous 15,521 high-confidence spatial candidate and 697 withheld figures reflect the **older conservative rule** and must not be restated as complete final fit eligibility after this correction. The earlier J011 no-spatial-capture finding is a *rule artefact*, not biological missingness or a sett-join error.


### 10 November 2026 — Whole 1977–2025 live capture audit for J011-like spatial eligibility exclusion

**Status: READ-ONLY WHOLE-DATABASE AUDIT COMPLETED; NO SPATIAL ELIGIBILITY RULE DEPLOYED YET.** After investigator approval of four FIELD FARM J011 named-sett trapping events despite blank ancillary location-type text, queried **all** current Supabase qualifying live captures (non-PM non-PM-companion TRAP, NET, SNARE, DART, FOUND_ALIVE, 1977–2025). The live totals exactly reproduce the frozen snapshot **16,218 qualifying rows**, with **15,521** old-rule fixed-sett spatial candidates; first live trial including 1976 showed 16,230 and 15,531, explained by 12 and 10 pre-1977 rows, not a change in underlying input data.

**New potential spatial evidence:** **159** original named-sett live captures at accepted canonical sett XY are classified only `SETT_ASSOCIATION_PROVISIONAL` because the supplementary `capture_location_text` was blank. The 159 are `encounter_type=TRAP` and span **37 setts / 133 badgers**; original source method is explicitly TRAP in **110**, missing in **49** (the latter all 1998–1999 and all measured weight with blood sampled, where previous curation classifies as traps). Source names are nonblank and canonical sett ID/XY valid in all 159; 33 source comments were read and none explicitly states capture in a different landscape context. **These 159 (including four J011) are candidate fixed-sett capture observations** using reference sett-point XY, with source-method missingness retained as separate evidence strength. There is no basis for discarding them merely because an ancillary location-type field was blank. This is source/likelihood eligibility, not demographic SG residency.

**Do not overgeneralise:** **304** other live captures explicitly say SETT but lack approved XY (301 UNRESOLVED + 3 SETT_ASSOCIATION_ONLY); cannot be resolved by text rules and need field mapping. **52** eligible encounters are deliberate nonsett-context conflicts (e.g., FIELD, WOOD, BOUNDARY) and must not use associated sett XY. The balance of captures outside the old spatial rule has different classes of unresolved/nonsett location; there is no assumption all are eligible. A separate RTA recovery can have grid-derived road coordinates but is not a live fixed-sett trapping detector. The old filter was **overly restrictive**, not the historical canonical sett joins themselves.

**Evidence and next gate:** Reusable read-only `sql/audit/WECS_V12_Blank_Sett_Location_Trap_Evidence_20261110.sql` returns aggregate counts and exact list of 159 records with source method, canonical sett reference XY, and context comments. `docs/database/02_MASTER_DATA_DICTIONARY_AND_AUDIT.md` explains rule boundaries. Need an explicit **model-specific** spatial inclusion derivation that preserves `EXPLICIT_SETT` vs `NAMED_SETT_BLANK_TYPE` and original `MOC=TRAP` vs `CURATED_TRAP_SOURCE_MOC_NULL`, then rerun old 1,932-tattoo cohort reconciliation and assess capture-date and movement span changes. Only after source-backed inclusion rule approved implement new V12 spatial likelihood and historical coverage-sensitivity. Keep frozen V12 November 6 evidence immutable; active SQL tables, raw names, canonical XY, migrations and old fit outputs unchanged.


### 10 November 2026 — 159 named-sett blank-location trapping observations APPROVED; 304 accepted-sett XY outstanding

**Status: SCIENTIFIC ELIGIBILITY APPROVED / R INPUT CODE COMMITTED / COMPARISON NOT YET RERUN.** Investigator explicitly approved all 159 original named-sett trapping encounters with blank ancillary capture-location field for use as **fixed-sett proxy spatial captures at canonical XY**, after live-source verification. Source methods: 110 explicit original TRAP, 49 originally missing MOC but sampling-supported curated TRAP. This does not promote field, wood, boundary, netted-off-sett, dead recovery or other `SETT_ASSOCIATION` events. The coordinate denotes agreed sett centroid/reference, not a surveyed microposition.

**Implementation:** `scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R` is a single versioned model-specific eligibility derivation for the exact frozen 2026-11-06 Supabase input. Assigns `EXPLICIT_SETT_POINT_PROVISIONAL` to original 15,521 and `APPROVED_NAMED_SETT_BLANK_LOCATION` to 159; asserts exact 16,218 eligible live, 15,521 baseline, and 159 approved records for safety. Total **15,680 prospective vetted spatial observations**, contingent on local script run confirming counts. Existing `scripts/ModularFitting/Woodchester_V12_V11R2_Cohort_Reconciliation.R` now sources this function, compares the new approved spatial set against original 1,932-badger cohort and saves a NEW local output directory. No overwrite of frozen snapshot or previous output. This is data input reconciliation only; no posterior model fit or movement likelihood change yet. Source MOC not exported in frozen input; original-method evidence label is deliberately marked unresolved at individual-event level for future source-specific sensitivity.

**304 pending:** Exactly 304 other live observations originally say SETT but lack approved reference XY (301 unresolved and 3 association-only); retain them as dated observed-alive evidence and mark awaiting field-team mapping. Once true canonical sett XY is reviewed and recorded, re-freeze a new dataset and re-run eligibility, not retrospectively alter prior MCMC input. Source records/DB and explicit non-sett capture contexts remain unchanged.

**Next task:** On RStudio, `git pull --ff-only` then rerun `V12_SNAPSHOT=data/model_snapshots/v12_20261106T103144Z_1079872 Rscript scripts/ModularFitting/Woodchester_V12_V11R2_Cohort_Reconciliation.R`. Verify 15,680 approved spatial events and updated old-cohort mapped badgers, spans and date differences. Investigate unexpected issues before the first new spatial refit.


### 10 November 2026 — Approved named-sett rule rerun: full V11R2 cohort spatially recovered

**Status: FROZEN-SNAPSHOT RECONCILIATION RUN SUCCESSFULLY ON EXETER RSTUDIO; NOT A MODEL FIT.** User ran `scripts/ModularFitting/Woodchester_V12_V11R2_Cohort_Reconciliation.R` on the unchanged `data/model_snapshots/v12_20261106T103144Z_1079872`, after the 159 investigator-approved named-sett/blank-location live trapping observations were included through versioned model-specific `Woodchester_V12_Spatial_Eligibility_Rules.R`. Output: `outputs/v12_v11r2_reconciliation/run_20261110T094951Z`.

**Validation:** Frozen whole snapshot has 16,218 qualifying live records: 15,521 explicitly stated SETT with accepted provisional sett-point XY, **159** named-sett TRAP with missing ancillary location text but investigator-approved canonical reference XY, and 538 without approved fixed-sett point. Thus **15,680** prospective approved fixed-sett spatial captures, with 304 separately acknowledged as explicit SETT records awaiting correct XY. Source captures, coordinates, death records, social-group assignments and frozen RDS remain unchanged.

**Comparison using exactly the old 1,932 tattoos:** Original V11R2 mapped captures 14,049, latent annual positions 8,248, latent annual intervals 6,316, all 1,932 mapped. Curated approved spatial records: **13,986** captures, **1,932** mapped tattoos (J011 restored), **8,208** annual positions, **6,276** annual intervals. This leaves **40 fewer** annual span intervals (0.63% of 6,316) relative to historical spatial-only baseline, compared with 60 fewer under obsolete stricter rule. All qualifying live records (including unlocated captures) from those tattoos remain 14,395, implying 8,322 first-to-last live annual states and 6,390 annual intervals, which are *model-span potential*, not 6,390 observed geographic movements. Within the 159 approved additions, 146 belong to the historical movement population and 13 to other curated animals.

**Date-level source screening:** 13,984 tattoo-date combinations matched mapped row counts; **425** differing keys: 360 ONLY_CURATED (present in curated qualifying live but absent in old *mapped* data), 14 ONLY_LEGACY, and 51 SPATIAL_DATE_ROW_COUNT_CHANGED; discrepancy categories are not confirmed source-event mismatches and need original capture ID/event-level reconciliation. Entire curated data include 1,272 tattoos outside old 1,932 cohort, of which 1,221 have mapped captures under expanded rule, but there is NO approval to automatically enter them into a new movement fit. Historical 119 detectors vs 119 canonical sett IDs in old-cohort curated captures, 121 in whole curated snapshot; matching numerical totals do not independently validate sett identity or historical detector deployment.

**Decision:** APPROVED named-sett rule is now numerically verified and recovers J011 and +20 annual spatial span intervals relative to stricter screen. Maintain same 1,932-tattoo cohort for controlled methodological comparison. Next run existing read-only `scripts/ModularFitting/Woodchester_V12_V11R2_Reconciliation_Triage.R` pointing to `run_20261110T094951Z` to isolate the animals responsible for the **40 remaining interval difference**. Examine 14 legacy-only and 51 spatial row-count mismatch date combinations; 360 curated-only dates are supplementary live evidence, not automatically evidence of changes to locations or trapping coverage. No inference that 40 real observed moves were lost. Do not infer quarterly negative trapping effort from positive captures.
