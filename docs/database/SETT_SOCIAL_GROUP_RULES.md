# Woodchester Sett and Social-Group Assignment Rules

**Updated:** 16 October 2026

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
16,340 with sett_id
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

## 6. The CHESTNUT / HOLLOW TREE rule

Three captures have an explicit cleaning note:

```text
Original sett blank; value recorded in socg was not a valid social group
but matched a known sett and was used as cleaned sett
```

The values are:

- CHESTNUT — 2 captures
- HOLLOW TREE — 1 capture

Rule:

1. Original `sett` was blank.
2. Original `socg` contained a value.
3. That value was not a valid canonical social group.
4. It matched a known sett.
5. It was therefore assigned as the cleaned sett.
6. It was **not** forced into the social-group lookup.
7. The original recorded field remains preserved and a cleaning note explains the decision.

This is preferable to the misleading interpretation that CHESTNUT or HOLLOW TREE were genuine social-group assignments.

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
