# Woodchester Sett and Social-Group Assignment Rules

**Updated:** 21 October 2026

## Purpose

Sett and social-group fields are historically complicated and must remain auditable.

This document defines how recorded values, canonical identities and inferred relationships should be handled.

---

## 1. Never erase the recorded value

For captures, the research table keeps separate fields:

- `recorded_sett_name`
- `sett_id`
- `recorded_social_group_name`
- `recorded_social_group_id`
- `recorded_supergroup_name`
- `capture_location_text`
- `os_ref`
- `location_cleaning_note`

The recorded text is evidence.

A cleaned ID should not replace or destroy that evidence.

---

## 2. Canonical sett identity

`research.setts` defines canonical sett identities.

A capture may receive `sett_id` only when there is sufficient evidence that the historical record refers to that canonical sett.

The analysis view obtains `normalized_sett_name` by joining `captures.sett_id` to `research.setts`.

Therefore:

> `normalized_sett_name` is not a fresh text-cleaning operation performed by the analysis view.

It reflects an upstream canonical assignment.

---

## 3. Unresolved historical locations are allowed

At the current audit:

```text
17,586 captures
16,337 with sett_id
464 with recorded sett text but no sett_id
```

Many unmatched historical strings are road locations, grid references, outliers, field descriptions, uncertain names or corrupted legacy text.

Do **not** force them to a sett simply to eliminate missing values.

An unresolved location is preferable to a false precise assignment.

---

## 4. Case and obvious canonical spelling

Where a recorded string unambiguously refers to the same canonical named sett, case normalisation can be represented through the canonical ID.

Examples visible in the live data include:

- `box → BOX`
- `Pennys → PENNYS`
- `pylon → PYLON`

The original recorded value remains available.

---

## 5. Historical setts promoted during migration QC

Eighteen canonical setts currently have notes:

```text
Historical sett identified from repeated tblCaptures records;
manually promoted during migration QC
```

They are:

- ATCOMBE CORNER
- ATCOMBE WEST
- BAMBOO
- BUNGALOW
- DARK WOOD
- GULLEY
- LISTERS
- PRIORY
- RASPBERRY
- SCARHILL
- TODDS
- TOP SETT
- TOWER GULLEY
- TWIN ASH
- UPPER
- WALL
- WHITINGS BEECH
- WOOD EDGE

These are examples of a legitimate cleaning operation: repeated historical capture evidence demonstrated that a location functioned as a sett even though it was not adequately represented in the original sett lookup.

The note is retained specifically so this remains auditable.

---

## 6. Post-mortem records with no recorded sett

A post-mortem record does not automatically establish a physical sett at which the animal was captured, found or resident. A missing recorded sett must not be filled from the `socg` field alone.

For the BCP post-mortem records of tattoos `015S` and `053M` on 2 September 2021 (recorded `socg=CHESTNUT`) and `026H` on 29 September 2021 (`socg=HOLLOW TREE`), original Access `sett` is blank. Their canonical `sett_id` is accordingly NULL. The recorded `socg` strings remain available as historical evidence, without asserting verified residency.

Scientific review: **Dave Hudson**.

---

## 7. Capture-level social group

A capture's historical social group is represented by:

- `recorded_social_group_name`;
- `recorded_social_group_id`.

The analysis view obtains `normalized_social_group_name` from the stored canonical ID.

Do not overwrite a capture's recorded historical social group merely because its sett is currently associated with another social group.

Why:

- sett/social-group relationships can change through time;
- capture records may contain historically meaningful assignments;
- current lookup structures are not a substitute for historical evidence.

---

## 8. Sett ↔ social-group history

`research.sett_social_group_history` contains:

- `sett_id`
- `social_group_id`
- `valid_from`
- `valid_to`
- `notes`

This table is for explicit historically supported relationships.

The analysis view `analysis.sett_social_group_observed` is an observed summary of capture data.

It should **not** be interpreted as proof that a sett could only belong to one social group in a given period.

---

## 9. Social group ↔ supergroup history

`research.social_group_supergroup_history` similarly records:

- `social_group_id`
- `supergroup_id`
- validity dates
- notes

Use historical relationships where supported; do not retroactively apply a current supergroup relationship to every historical capture.

---

## 10. Rules for a new manual location correction

Before assigning a previously unresolved record:

1. preserve the original text;
2. identify the evidence used;
3. prefer stable IDs over rewriting text;
4. state whether the evidence is:
   - exact canonical match;
   - known spelling/case variant;
   - repeated capture evidence;
   - grid-reference evidence;
   - historical lookup/documentation;
   - expert judgement;
5. record the decision in `location_cleaning_note` or the appropriate lookup `notes`;
6. add the rule/code to the provenance audit;
7. report before/after unresolved counts.

Never perform fuzzy matching silently.

---

## 11. Analysis-specific location rules

Some analyses may need to collapse multiple captures within a quarter, choose modal locations, infer annual centres, or classify movement.

Those are **model/analysis decisions**, not canonical database cleaning.

They belong in analysis code and should not be written back to the historical capture record unless they become a separately named derived product.


---

## 12. Literature-backed Woodchester territory and annual-residency rules

The Woodchester literature distinguishes two related but different operations:

### 12.1 Annual territory delineation

Social-group territories were historically delineated in spring using bait
marking. Distinctive indigestible plastic markers were fed with bait at the
main sett of each social group. Markers recovered from latrines were used to
identify which group used a given area; latrines containing markers from
neighbouring groups, together with field observations of boundary runs, were
used to define territory boundaries.

This means that historical social-group geography is explicitly time-varying.
A modern static social-group polygon must never be projected backwards as if it
represented all historical years.

Where annual bait-marking territory products are available, they are the
preferred source for historical territory geography.

### 12.2 Annual resident social-group assignment

For analyses requiring one resident social group per badger per calendar year,
Vicente et al. (2007) used the following hierarchy, in order:

1. allocate the badger to the social group in which it was most frequently
   captured during that year;
2. if still unresolved, refer to allocation(s) in adjacent years and allocate
   consistently with the group in which it was most frequently caught;
3. consider captures in the current year and both adjacent years together and
   allocate to the group in which it was most frequently trapped;
4. consider the last capture before the year and first capture after the year,
   compare their temporal proximity to the year in question, and use the nearer
   candidate group, conditional on it being among the most frequent candidates
   from step 3;
5. if still indeterminate, allocate to the first relevant group in which the
   badger was caught.

Vicente et al. reported that over 96% of badger-years were assigned using
criterion 1 alone.

Project implementation rule:

> Annual resident social-group assignment should reproduce this capture-history
> hierarchy as closely and transparently as possible, with the criterion used
> stored for every badger-year.

Do not use a posterior activity-centre location or a static territory raster to
replace this annual resident-group assignment.

### 12.3 Excursions must remain separate from residency

A badger may be captured outside its annual resident group without having
permanently changed residency.

Therefore retain separately:

- annual resident social group;
- capture-level recorded social group;
- capture sett;
- observed extra-group excursion / bridge events;
- annual resident-group changes between years.

This distinction is central to reproducing the movement concepts used in the
Woodchester literature and to separating temporary extra-territorial movement
from permanent dispersal.

### 12.4 Relation to historical movement categories

Rogers et al. (1998) analysed movement among Woodchester social groups and
distinguished broad behavioural types including non-movers, occasional movers,
permanent movers and frequent movers. Later Woodchester work retained the
distinction between annual resident-group change and more transient movement.

These historical categories should be used as biological reference points, not
forced as hard thresholds into V11S. The current project can compare them with:

- V11S annual local/high-mobility probabilities;
- directly observed within-quarter sett/group switching;
- persistent individual mover propensity;
- future demographic states in V12.

### 12.5 Evidence hierarchy for observed social-group bridging

For a capture-to-capture movement event, classify origin/destination social
group using the strongest contemporaneous evidence available:

1. capture-level recorded historical social group;
2. explicit historically valid sett-to-social-group relationship;
3. annual bait-marking territory geography, if available and date appropriate;
4. unresolved if none of the above is sufficiently supported.

Do not silently substitute a current sett/social-group relationship.

Store the evidence source and an unresolved/conflict flag alongside every
derived bridge classification.


---

## 13. SOCG provenance audit result — 21 October 2026

A dedicated provenance audit tested whether the legacy capture-level `socg`
field behaved primarily as:

1. the contemporaneous social group associated with the capture location/sett;
   or
2. the annual resident social-group membership of the individual badger.

The result strongly supports interpretation (1).

### 13.1 Sett-year consistency

Among 1,363 sett-years with at least 2 badgers and at least 3 captures:

- 99.49% were at least 80% pure for one SOCG;
- 99.19% were at least 90% pure;
- 99.05% were at least 95% pure;
- 98.97% were completely pure.

At the finer sett-quarter scale, 99.81% of 2,127 eligible sett-quarters were at
least 90% pure for one SOCG.

### 13.2 Consecutive capture logic

Among 7,099 within-year consecutive capture transitions:

- when the sett did not change, SOCG changed only 1 time in 4,563 transitions
  (0.02%);
- when the sett changed, SOCG changed 915 times in 2,536 transitions (36.08%).

This is inconsistent with SOCG acting mainly as a persistent individual
membership label and strongly supports it being tied to capture location.

### 13.3 Leave-one-badger-out visitor test

For each focal badger-sett-year, the dominant sett-year SOCG was reconstructed
using OTHER badgers only. Eligible visitor cases required:

- focal annual resident group != other-badger sett-year group;
- at least 2 other badgers;
- at least 3 other captures;
- other-badger sett-year SOCG purity >= 0.80.

There were 571 eligible visitor cases.

- 562/571 (98.42%) focal capture SOCG values followed the OTHER-badger
  sett-year group;
- only 7/571 (1.23%) followed the focal badger's annual resident group;
- 2/571 followed neither.

This is the strongest current evidence that capture-level SOCG identifies the
contemporaneous social group associated with the capture location, including
when the captured badger is visiting outside its annual resident group.

### 13.4 Historical sett-to-group change

The audit identified 15 high-purity cases where the dominant SOCG of a sett
changed between successive observed sett-years. Examples include BOXWOOD,
BRAMBLE, BREAKHEART, FORK, SCOTLANDBANK, TRACKSIDE and WOODRUSH.

These are evidence that sett-to-social-group relationships are genuinely
time-varying and confirm that current/static group assignments must not be
backcast historically.

Where there are multi-year gaps between successive observations, the audit only
establishes that the dominant group differed between the two observed years; it
does not identify the exact year in which the underlying boundary/group change
occurred.

### 13.5 Approved interpretation

For behavioural analyses, a capture-to-capture change in legacy SOCG can now be
interpreted as:

> **observed movement between contemporaneously recorded social groups**

or, more briefly:

> **observed inter-group movement**.

It is still preferable not to claim the exact physical point/path of a
bait-marked territory-boundary crossing unless annual bait-marking polygons are
available. SOCG identifies the social-group side of the movement, not the
geometric boundary crossing path.

Annual resident group remains a separate derived variable. Therefore retain:

- capture sett;
- capture-level contemporaneous SOCG;
- annual resident group;
- within-group sett switch;
- inter-group visit/excursion;
- annual resident-group change.

This separation is now considered evidence-backed and should be used in all
subsequent behavioural and disease analyses.


## 2026-10-23 canonical sett duplicate resolution: TODD'S / TODDS

Approved by project investigator: merge `TODD'S` (sett_id 158) and `TODDS` (sett_id 538) as the same physical sett. **Canonical survivor: sett_id 158**. Before the merge, ID 158 had zero linked captures and one sett–SG history entry; ID 538 had eight linked captures and no history entry. The eight recorded captures belonged to recorded SG ARTHURS (social_group_id 48), consistent with ID 158 history. In a single database transaction, reassigned eight `research.captures.sett_id` references from 538 to 158, added explicit migration notes to those capture rows and the surviving sett record, and deleted duplicate canonical row 538. Original `recorded_sett_name` values were not edited. Post-merge verification: 177 canonical setts; eight captures linked to 158; zero to 538; existing history count for 158 remains one. Historical alias remains recorded here and in notes. Do not reintroduce ID 538 during future imports. This was a canonical identity correction, NOT an instruction to treat all geographical polygon labels as equivalent to social-group IDs.

