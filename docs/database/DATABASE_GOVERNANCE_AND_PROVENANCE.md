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


---

# Live database verification and coauthor release assessment — 23 October 2026

**Status: partial verification; not yet certified as a complete original-Access-to-Supabase reconciliation.**

This is the **master governance, cleaning and audit document** for the Woodchester database. Retain detailed field meanings in [DATA_DICTIONARY.md](DATA_DICTIONARY.md), the sett-specific rules in [SETT_SOCIAL_GROUP_RULES.md](SETT_SOCIAL_GROUP_RULES.md), and executable read-only checks in `sql/audit/Woodchester_database_cleaning_audit.sql`. All modifications should be cross-referenced here rather than scattered undocumented corrections.

## Scope, methodology, and provenance of this assessment

Live, read-only SQL inspected `access_raw`, `research`, `analysis`, constraint catalogues, view definitions and the role grants on 2026-10-23. Separately, the investigator exported the structure of the password-protected original Access database: **62 tables**. This was a schema-only Access inspection, **not a complete table-by-table content comparison**. The Access capture-only annual sett/SG aggregate showed 27 names with multiple historically recorded SGs and possible transitions, but cannot establish physical group changes by itself.

### Verified live counts

| Data type | `access_raw` | `research` | Finding |
|---|---:|---:|---|
| Individuals / `tbl_badger` | 3,791 | 3,791 | Count parity |
| Captures | 17,586 | 17,586 | Count parity |
| Cultures | 48,699 | 48,699 | Count parity |
| DPP | 3,316 | 3,316 | Count parity |
| ELISA | 15,162 | 15,162 | Count parity |
| IFN-gamma ELISA | 4,375 | 4,375 | Count parity |
| Brock | 1,648 | 1,648 | Count parity |
| Stat-Pak | 2,851 | 2,851 | Count parity |
| Wounds | 1,636 | 1,636 | Count parity |

`analysis.capture_history`: **17,586** rows, matching `research.captures`. `research.capture_sampling`: **17,586** rows.

**Important limitation:** equal counts do not prove equal values, full field coverage, correct parse rules, or completeness against the live original Access database. The `access_raw` schema contains **12 source tables** compared with **62 tables** in the original Access structural inventory. Many excluded tables are temporary, lookups, backup/error outputs or archived versions; their omission may be intentional, but it **has not been individually signed off**. Reconcile each Access table by classification (core, lookup, archive, temporary, redundant, missing-needed), record count, keys and destination; examine the potentially valuable `temp_GuyOutput` seasonal residency data and older capture/error tables.

### Foreign keys and linkage

The live catalogue confirms explicit foreign keys linking captures to individuals, canonical setts, recorded SGs and disease-status lookups; assay records to captures; and history association tables to corresponding canonical identities. Verified **0 NULL individual IDs in captures**; **0 NULL capture IDs** in culture, DPP, ELISA, IFN-gamma, Brock and wounds. These checks are encouraging but do **not** test whether the *correct* capture was chosen when importing records that share the same tattoo, date and PM flags. Require per-assay match-key collision and raw-to-research identity audits.

Remaining missing canonical links: **1,246 captures without `sett_id`** and **685 without `recorded_social_group_id`**. These are permitted missing states, not automatically rejected records; distinguish genuinely unrecorded, ambiguous, geographic-only and malformed-source cases.

## Cleaning and transformation register (evidence levels)

Maintain three classifications for each item: **VERIFIED IN LIVE DATA**, **EVIDENCED BY HISTORICAL CODE/NOTES**, or **TO VERIFY AGAINST ORIGINAL ACCESS**. Record source table/field, rule, SQL/R commit, affected IDs/counts, reviewer, date, reversible mapping, and post-change checks.

| Domain | Cleaning/transformation | Evidence/status |
|---|---|---|
| Import | Preserve original values in `access_raw`, with `raw_row_id` and `raw_imported_at` | VERIFIED structure; completeness vs original Access TO VERIFY |
| Data types | Parse dates, numeric measurements, booleans and test measurements into typed research fields | VERIFIED structure; conversion exceptions/invalid inputs TO VERIFY |
| Individuals | Allocate canonical `individual_id`; retain tattoo/electronic tag and alternative historical names in `research.individual_names` | VERIFIED structure; individual-specific reconciliation TO VERIFY |
| Individual correction | Historical `040l` → `040L` correction occurs in legacy code | EVIDENCED; live value-level reconciliation TO VERIFY |
| Captures | One canonical `capture_id` per imported capture; retain recorded sett, SG, supergroup and contextual text; split sampling, assessment and collar fields into separate tables | VERIFIED row counts and structure; all column-level equivalences TO VERIFY |
| Assays | Convert source assay records to separate one-to-many `research` test tables; link by `capture_id`, expose long-format `analysis.diagnostic_results` | VERIFIED count parity and nonnull capture links; *correct-target* matches and assay fields TO VERIFY |
| Capture locations | Clean only supported canonical sett IDs; preserve unresolved source descriptions; use `location_cleaning_note` on nontrivial changes | VERIFIED architecture; complete log of all name-rule decisions TO VERIFY |
| Original sett/socg fix | Historical blank-sett/socg shifts involving CHESTNUT and HOLLOW TREE (3 records) | EVIDENCED by earlier audit; confirm source row provenance |
| Sett identity | Investigator approved `TODDS` (former ID 538) → `TODD'S` ID 158; migrated 8 linked captures, historical text preserved | EXECUTED and previously post-checked 2026-10-23 |
| Sett identity | Investigator approved `TOP SETT` (former ID 548) → `TOP` ID 20; migrated 358 linked captures, original name preserved | VERIFIED post-check: 615 captures on ID 20, no ID 548 rows |
| Sett coordinate aliases | `CLIFF.FACE`→`CLIFF` (160), `GULLY`→`GULLEY` (550), `STONEY.TRACK`→`STONY TRACK` (29), `ELEVEN.ROW`→`ELEVENTH ROW` (58) | Investigator-approved rules in `data/spatial/canonical_sett_coordinate_aliases.csv`; spatial audit Script 09 applies them |
| Annual territory crosswalk | Annual polygon containment is spatial evidence, not an assignment of residence or transmission | VERIFIED workflow; historical interpretations still under review |
| Historical SG | Current `research.sett_social_group_history` has **173 entries, none dated**; notes show current Access lookup import | VERIFIED live; cannot treat as a valid year-by-year affiliation table |
| Model infection probabilities | Imported/model-specific probability tables and `analysis` views; maintain model variants and provenance | VERIFIED structure; source CSV and version reconciliation TO VERIFY |
| Cohort/derived data | R model scripts implement encounter/quarter fusion, eligibility and age/sex/infection classifications | CODE LEVEL; do not label modelling choices as irreversible source cleaning |

**Never represent the list above as a complete retrospective changelog.** Some original migration SQL is not preserved in version control. This document is the central reconstructed audit, with unresolved evidence gaps explicitly identified. For every *future* cleaning operation, commit the exact SQL/R migration and record before/after counts and IDs.

## Should the `research` / `analysis` distinction remain?

**Recommendation: yes, keep both physically; make their use simple.** This is not a duplicate hierarchy of independently cleaned data. The `research` schema holds one canonical relational source of truth with explicit foreign keys and multiple assay rows per capture; `analysis` contains **views, not separate copies**. Coauthors can use the same biological data through views without repeating potentially dangerous many-to-many joins. Advanced coauthors should also have read-only access to canonical `research` tables, not raw staging by default.

Suggested access policy:
- `analysis`: default for ordinary research, especially `capture_history`, `diagnostic_results` and model outputs.
- `research`: accessible **read-only** to authorised collaborators for field-level audit and specialist joins, with clear join-grain warnings.
- `access_raw`: restricted provenance archive for maintainers, accessed on request for validation.

### Join contract for coauthors

- **Individuals**: `research.individuals.individual_id` (one badger).
- **Captures**: `research.captures.capture_id` (one encounter), with `individual_id` foreign key.
- **Sett and group**: `captures.sett_id` → `research.setts.sett_id`; `captures.recorded_social_group_id` → `research.social_groups.social_group_id`; recorded SG **does not** mean annual resident SG.
- **Assays and wounds**: multiple records may share a `capture_id`. Do not attach two assay tables directly to captures and assume one row per capture; aggregate separately or use `analysis.diagnostic_results` in its documented *one-row-per-test* grain.
- **Model products**: join on published `individual_id` plus temporal and `model_variant`/`model_run` keys; verify capture-level uniqueness for any capture-derived version.
- **Territories**: spatial/annual keys must include **year**; polygon labels need not equal sett IDs or annual resident SG IDs.

Illustrative read-only SQL:

```sql
-- Exactly one row per capture
select capture_id, individual_id, tattoo, capture_date,
       recorded_sett_name, normalized_sett_name,
       recorded_social_group_name, normalized_social_group_name
from analysis.capture_history;

-- Long-format test results: may include many tests per capture
select capture_id, test_family, test_type, result, source_record_id
from analysis.diagnostic_results;
```

## Coauthor launch checklist (not yet complete)

1. **Original-Access completeness:** account for all 62 Access tables and verify source/version timing, record counts and identity keys against the preserved 12 raw tables.
2. **Field-level parity:** compare source and destination columns/values across all core entities; document parsing failures, duplicate-record handling, nulls, enums, source-row links and assay capture joins.
3. **Permissions:** live verified `badger_readonly` SELECT grants on seven `analysis` views only. Verify *effective* privileges of `badger_research_readonly` (including schema USAGE, inheritance, future-table default privileges and excluded staging), **using a test account rather than admin**. Create named coauthor accounts; no sharing of maintainer credentials.
4. **Security:** confirm `anon`/`authenticated` do not unintentionally gain research/analysis access through role inheritance or exposed API views; review RLS, security-invoker behaviour, search paths, and credential rotation. Never distribute database connection passwords in repository files or logs.
5. **Documentation:** retain this page as the **single governance/cleaning index**, with field-by-field glossary in `DATA_DICTIONARY.md` and executable audit query bank in `sql/audit`.
6. **Scientific definitions:** publish the data grain, time origin, PM flags, test interpretation, missingness, SG/residency distinction, spatial coordinate provenance and limitations of infection probability outputs.
7. **Release gate:** sign off an audit snapshot and data-dictionary version, then share a sample read-only R query using `scripts/BadgerDatabase.R`; test external collaboration with least-privileged credentials.

**As of this assessment no database schema or coauthor privileges were altered.** The live inspections were read-only.


## Tattoo-first coauthor interface and the 040l historical correction — 23 October 2026

Investigator decision: **tattoo is the canonical scientific identifier for an individual badger**. Coauthors should use `tattoo` for individual-level work, and `capture_id` for capture/test joins. The surrogate `individual_id` remains a relational database implementation key and is not a second biological identity.

Live validation found **3,791** `research.individuals`, **3,791 unique nonblank tattoo values**, and **zero duplicated tattoos after `upper(btrim(tattoo))`**. Thus the current canonical register supports a tattoo-first research interface. Changes to tattoos require source-supported documented mapping, not indiscriminate case normalisation.

**Verified 040l/040L case:** In preserved `access_raw`, the individual and ten capture records use `040L`. The culture table has **34** records marked `040L` and **four** marked `040l`. All four lowercase culture records are dated **2011-01-25**, PM = No, with samples HEAD, OA, TA and URINE. `research.individuals` has exactly one canonical badger `040L` (`individual_id=792`), and its captured encounter on that date has four linked culture records. In all, `research.cultures` has **38** culture records associated with the canonical tattoo through capture relations. This constitutes strong linkage corroboration; the four row identities were not separately reconciled by a source-row foreign key, which `research.cultures` does not currently expose. The original source-case distinction remains preserved in `access_raw.tbl_culture`. No `040l` alias row was found in `research.individual_names`; **the correction is therefore documented here as a verified historical alias**, not as a claim of an existing alias-row entry.

Five `analysis.coauthor_*` SQL views were created and SELECT-granted to `badger_readonly` and `badger_research_readonly`: `coauthor_capture_history`, `coauthor_diagnostic_results`, `coauthor_capture_infection_probabilities`, `coauthor_infection_probabilities`, `coauthor_infection_quarterly_probabilities`. These expose the columns of their corresponding existing `analysis` views **except `individual_id`**, while retaining tattoo, and capture_id wherever the source view contains it. `coauthor_capture_history` returns 17,586 rows, matching the original view and research captures. Original views were not changed, protecting existing R scripts and references. These are coauthor-facing convenience views; `research` still exposes internal IDs to advanced users if granted read access.

**Caution:** a tattoo-based join links all observations of an individual. Always use `capture_id` to link diagnostics to the intended encounter. The `040l` alias is a specific evidenced correction, not a general permission to merge visually similar identifiers.

Example:

```sql
select tattoo,capture_id,capture_date,recorded_sett_name,recorded_social_group_name
from analysis.coauthor_capture_history;

select tattoo,capture_id,test_family,sample_type,result
from analysis.coauthor_diagnostic_results;
```


## Tattoo-first consolidation completed — 23 October 2026

**Live change completed and verified**: five former `analysis.coauthor_*` views were rebuilt with standalone SQL (the original base-query definition embedded, not references to original analysis views). For each, the former standard analysis view was dropped and the rebuilt tattoo-first view renamed to its original standard name. The five duplicate `coauthor_*` views no longer exist. The remaining `analysis` namespace has **seven** views: `capture_history`, `diagnostic_results`, `capture_infection_probabilities`, `infection_probabilities`, `infection_quarterly_probabilities`, `historical_sett_candidates`, `sett_social_group_observed`.

The five public-facing core/model views now contain **tattoo rather than individual_id**. Capture-grain views retain `capture_id`; `infection_quarterly_probabilities` retains tattoo and quarterly temporal keys. The internal `research` schema still uses `individual_id` and foreign keys. `badger_readonly` and `badger_research_readonly` were granted SELECT on the seven analysis views. Verification after the changes: **17,586** `analysis.capture_history` rows, matching **17,586** `research.captures` rows; **76,051** `analysis.diagnostic_results` rows. These were live SQL-level checks; **R end-to-end data-preparation pipeline has not yet been executed on Exeter**.

The repository `DataPrep_fromSupaBase.R` was updated to use tattoo-only identity checks and joins, standard `analysis.capture_history` / `analysis.diagnostic_results` view names, and omit `individual_id` from its analytical products. Once pulled, run the normal R preparation pipeline and compare output/diagnostic row counts with the previous snapshot. Record model-output consequences before replacing published results.

Earlier prose in this document referring to existing `coauthor_*` views describes a **now-retired intermediate state** and should not be interpreted as live schema documentation.
