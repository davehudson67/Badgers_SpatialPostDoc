# Woodchester Badger Database — Governance, Provenance and Cleaning Audit

**Updated:** 16 October 2026

## Purpose

This document records how the Woodchester badger database is organised, what is known about cleaning from the original Microsoft Access database, which transformations are considered canonical, and how future changes should be documented.

It is deliberately an **audit document**, not just a user guide.

The central principle is:

> The original information must remain recoverable, while cleaned interpretations must be explicit, reproducible and distinguishable from the source record.

---

## 1. Three data layers

### `access_raw`

Preserved import of the original Access-era tables.

Purpose:

- retain original field names and values;
- allow source auditing;
- provide evidence when a cleaned value is questioned;
- avoid repeatedly reopening/reinterpreting the original Access file.

Examples of original fields retained include:

`tattoo`, `age_fc`, `year_fc`, `pm`, `socg`, `sett`, `supergroup`, `where_text`, `reproc`, `pmstat`, etc.

This layer should not be edited for routine cleaning.

### `research`

Canonical cleaned relational database.

Purpose:

- typed fields rather than everything stored as text;
- stable internal IDs;
- one canonical individual identity;
- explicit capture IDs;
- split one-to-many information into relational tables;
- preserve both recorded and cleaned location/social information;
- hold reusable model-derived products.

This is the **source-of-truth analytical database**, but it is still low-level.

### `analysis`

Curated research-facing views.

Purpose:

- provide stable, documented analysis units;
- hide unnecessary relational complexity;
- expose common joins centrally;
- make the grain of each object explicit;
- reduce accidental duplication or inconsistent reconstruction by different users.

This layer is the recommended default for most analyses.

---

## 2. Why `research` and `analysis` are separate

The separation was intentional.

A well-normalised research database is not automatically a safe analysis dataset.

For example, `research.captures`, `research.cultures`, `research.wounds` and `research.dpp_tests` have different grains. Joining several one-to-many tables directly can multiply rows and silently bias an analysis.

The `analysis` layer therefore acts as a **scientific interface** to the canonical data.

### Hazards of using `research` directly

Direct use is legitimate, but the user must understand:

1. **Table grain.** One capture can have multiple wounds, cultures, DPP rows, etc.
2. **Join multiplication.** Joining two one-to-many tables can create combinations that never represented separate biological events.
3. **Internal/staging structures.** Import tables are implementation details, not canonical scientific products.
4. **Historical versus normalised values.** A recorded value and a cleaned lookup are not necessarily interchangeable.
5. **Schema evolution.** Internal relational tables can evolve more readily than curated views.
6. **Reproducibility.** Different coauthors can independently recreate the same join or cleaning rule in slightly different ways.
7. **Interpretive fields.** Some fields require biological rules, not merely SQL joins.

Therefore:

> `analysis` is the default interface; selected `research` tables are available read-only for advanced auditing or specialist analyses.

---

## 3. Current researcher access tiers

### `badger_readonly`

Default collaborator role.

Can:

- connect to the database;
- use the `analysis` schema;
- SELECT from approved analysis views.

Cannot:

- access `research`;
- write data.

### `badger_research_readonly`

Advanced/audit role.

Can:

- use all approved `analysis` views;
- SELECT from approved canonical `research` tables.

Cannot:

- INSERT, UPDATE or DELETE;
- access the staging tables:
  - `research.infection_probabilities_import`
  - `research.infection_quarterly_import`
- bypass RLS.

This role is appropriate for coauthors who need to audit cleaning, inspect assay-level fields, or build specialist datasets not yet represented by an analysis view.

---

## 4. What is known about the migration

Supabase migration history does **not** contain the original Access → PostgreSQL migration.

The only recorded Supabase migration at the time this audit was created relates to later access-control work.

Therefore the historic cleaning record has been reconstructed from:

1. the preserved `access_raw` tables;
2. the current `research` schema;
3. current analysis-view definitions;
4. notes stored in canonical lookup tables;
5. surviving R cleaning/audit scripts in `scripts/OLD_data_prep/`;
6. row-count and mapping audits against the live database.

This means we can distinguish:

- **confirmed current behaviour**;
- **historical cleaning evidenced by code/notes**;
- **migration decisions whose original executable SQL has not survived**.

Future changes should not have this ambiguity: every central correction should be made through version-controlled SQL/R plus a changelog entry.

---

## 5. Raw-to-research row-count audit

Core source tables retain strong row-count correspondence:

| Raw Access table | Raw rows | Research target | Research rows |
|---|---:|---|---:|
| `tbl_badger` | 3,791 | `individuals` | 3,791 |
| `tbl_captures` | 17,586 | `captures` | 17,586 |
| `tbl_culture` | 48,699 | `cultures` | 48,699 |
| `tbl_dpp_test` | 3,316 | `dpp_tests` | 3,316 |
| `tbl_elisa` | 15,162 | `elisa_tests` | 15,162 |
| `tbl_ifn_gamma_elisa` | 4,375 | `ifn_gamma_elisa` | 4,375 |
| `tbl_stat_pak` | 2,851 | `stat_pak_tests` | 2,851 |
| `tbl_brock_test` | 1,648 | `brock_tests` | 1,648 |
| `tbl_wounds` | 1,636 | `wounds` | 1,636 |
| `social_groups` | 45 | `social_groups` | 45 |
| `tbl_sett` | 173 | `setts` | 178 |

Exact row-count parity does not imply every field is unchanged; it shows that these source rows were not generally filtered away during relational migration.

---

## 6. Confirmed structural cleaning

The following are visible directly from raw and research schemas.

### Typed values

Many Access fields were stored/imported as text.

The research layer converts appropriate fields to:

- `date`;
- `time`;
- `boolean`;
- `integer` / `bigint`;
- `numeric`;
- timestamps.

### Stable IDs

The research layer introduces stable keys including:

- `individual_id`;
- `capture_id`;
- assay-specific IDs;
- `sett_id`;
- `social_group_id`;
- `supergroup_id`.

These keys should be preferred to free-text names in joins.

### Relational decomposition

Capture-associated information was separated into canonical tables such as:

- `capture_sampling`;
- `capture_assessments`;
- `capture_collars`;
- `wounds`;
- assay-specific diagnostic tables.

---

## 7. Individual identity and historical names

`research.individuals` contains the canonical individual record.

`research.individual_names` preserves additional historical names rather than forcing all historical naming information into one string.

The analysis capture view aggregates historical names for convenience but does not replace the canonical ID.

Historical analysis code also contains a specific correction:

```text
040l → 040L
```

This is evidence of a known historical identifier issue. The live database should be audited against the raw table before any further identifier correction is treated as canonical.

---

## 8. Sett and social-group provenance

See the dedicated document:

`docs/database/SETT_SOCIAL_GROUP_RULES.md`

Important summary:

- recorded sett/social-group text is retained;
- canonical IDs are separate fields;
- unresolved historical text is allowed to remain unresolved;
- a normalised value must not be invented merely because a string looks similar;
- three capture records have explicit location-cleaning notes because the original sett was blank and the value in `socg` matched a known sett rather than a valid social group;
- the affected historical values are CHESTNUT (2 captures) and HOLLOW TREE (1 capture);
- 18 canonical setts currently carry notes stating that they were historical setts manually promoted during migration QC;
- capture-level historical social-group values should not be overwritten automatically from a current sett→group lookup.

Current capture-location audit:

```text
captures                                  17,586
captures with canonical sett_id           16,340
recorded sett present but unresolved          464
captures with recorded social-group text  16,904
captures with canonical recorded SG id    16,901
recorded SG present but unresolved              3
```

Unresolved values are part of the audit trail, not necessarily errors to be guessed away.

---

## 9. Historical analysis-era cleaning found in surviving R code

The scripts in `scripts/OLD_data_prep/` pre-date the current database architecture.

They are useful evidence of historic conventions, but they should **not automatically be interpreted as current canonical database rules**.

Examples found include:

- tattoo correction `040l → 040L`;
- age-first-capture correction for badger `067B` to `ADULT`;
- harmonisation of PM strings such as `YES/NO/no`;
- missing sex converted to `UNKNOWN` in an analysis dataset;
- culture result recoding;
- grouping culture samples into URINE / FAECES / OA / TA / OTHER;
- DPP visual-line recoding;
- IFN result recoding;
- quarter/occasion construction;
- known-age filtering and derived age calculations.

These operations belong to two different categories:

### Candidate central cleaning

Corrections to a source identity/value that are universally true may belong in `research`.

### Analysis-specific preparation

Filtering to known-age animals, defining quarters, deriving age at time, collapsing diagnostic results, etc. should remain in reproducible analysis code unless a broadly reusable view is deliberately created.

---

## 10. Infection outputs

Model-derived infection probabilities are not original Access fields.

They are later analytical products stored centrally for reproducibility.

Canonical tables:

- `research.infection_probabilities`;
- `research.infection_quarterly_probabilities`.

Staging/import tables:

- `research.infection_probabilities_import`;
- `research.infection_quarterly_import`.

The staging tables are deliberately excluded from advanced collaborator access.

---

## 11. Rules for future cleaning changes

Every future canonical correction should have all of the following:

1. **Source evidence** — what raw row/value prompted the change.
2. **Rule** — exact transformation or mapping.
3. **Scope** — which rows are affected.
4. **Reason** — typo, duplicate identity, known synonym, field misuse, biological rule, etc.
5. **Code** — SQL/R that applies or audits it.
6. **Before/after audit** — counts and affected IDs.
7. **Date and author/decision context.**
8. **Git commit** — version-controlled record.

Do not silently update a canonical field in the dashboard.

---

## 12. Proposed cleaning changelog format

Add future decisions to this document or a dedicated changelog using:

```text
Date:
Object:
Source table/field:
Affected rows:
Old value(s):
New value(s):
Rule:
Evidence:
Reason:
Code/migration:
Git commit:
Notes:
```

---

## 13. Auditing live cleaning

The repository contains:

`sql/audit/Woodchester_database_cleaning_audit.sql`

It reports:

- raw/research row counts;
- unresolved sett/social-group mappings;
- location-cleaning notes;
- canonical lookup notes;
- direct raw-vs-clean identifiers;
- view definitions;
- current access privileges.

Run it after major database cleaning changes and retain the Git commit associated with the change.

---

## 14. What remains incomplete

The original Access database may have contained field descriptions, lookup forms, validation rules or other metadata not represented in the imported rows.

Those descriptions are **not currently preserved as a complete machine-readable dictionary in Supabase**.

The new data dictionary therefore distinguishes:

- field meaning supported by current schema/raw names;
- known lookup semantics;
- inferred descriptions that still need checking against original Access documentation.

If the original Access file or exported schema documentation is available, it should be used to enrich the dictionary rather than relying on memory.

---

## 15. Principle for coauthors

A coauthor should be able to answer:

> Where did this value come from, was it recorded or inferred, what cleaning rule changed it, and can I reproduce that rule?

If the answer is not clear from the database, code and documentation, the provenance system needs improving.
