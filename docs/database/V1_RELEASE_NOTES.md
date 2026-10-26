# Woodchester badger database — Version 1 release notes

**Status: V1 in preparation — 26 October 2026.** This document is for coauthors. The detailed cleaning and historical design record is maintained separately in [V1_CLEANING_AUDIT.md](V1_CLEANING_AUDIT.md).

## Design principle

Keep the database as close as practicable to the original Access tables. `research` contains cleaned source entities, retaining original field values and providing additional `_clean` columns where transformations are justified. Keep genuinely new information, such as infection-model outputs and validated coordinate evidence, in separate tables. `analysis` contains only a few useful derived joins/views, not copies of the same dataset.

The source Access imports remain unchanged in `access_raw`. The `ingest` schema contains technical import and provenance information. Original values are never silently overwritten by a cleaning decision.

## Current core data

- **Badgers:** `research.individuals` — individual identity; `tattoo` is the scientific identifier.
- **Captures and PM records:** `research.captures` — one event per `capture_id`. Additional associated details are currently stored in `capture_sampling`, `capture_assessments` and `capture_collars`. These will be reconciled with the original Access structure in the final V1 pass, preserving every historical field.
- **Diagnostic evidence:** `cultures`, `elisa_tests`, `ifn_gamma_elisa`, `stat_pak_tests`, `brock_tests`, `dpp_tests`, with their original measurement detail.
- **Other biological records:** `wounds`, historical `individual_names`, and reference/lookup tables.
- **Sett and social groups:** `setts`, `social_groups`, `supergroups` and recorded historical relationships; coordinate provenance is stored separately.
- **New model results:** `infection_probabilities` and `infection_quarterly_probabilities`; these are estimates, not original observations.

## Recorded versus cleaned fields

Use consistent **`_clean` suffixes** for newly created standardised versions of source fields. For example, preserve `recorded_sett_name` as the historical entry and add a distinct clean canonical name only when scientifically supported. For unassigned setts, the clean sett name remains `NULL`; a recovery grid reference must not be interpreted as a physical sett. Coordinates must include enough provenance to distinguish actual sett locations, recovery grid squares and future modelled group centres. Exact column mapping and final clean-column names remain subject to V1 verification; the earlier legacy `normalized_*` fields are not renamed yet.

## Useful analysis outputs

The proposed small final group is a single joined capture-history view, a diagnostic-results view, an optional sett/coordinate reference view, and clearly labelled derived infection summaries where needed. **Existing views remain in the database until dependent running models have been checked; they are not all endorsed as final release interfaces.** Their technical disposition is recorded in the cleaning audit.

## Coverage and open work

17,586 distinct capture/PM events; 16,337 events linked to recognised setts, 710 provisionally grid-referenced PM recovery locations, 343 unresolved PM locations, 170 unmatched non-PM locations and 26 with no recorded location. There are 176 canonical setts, with coordinate evidence linked for 159. These labels and spatial coordinates remain subject to the documented historical-source checks.

Coauthors will have read-only access to both curated `research` and `analysis`. Both existing custom read-only roles have been granted SELECT on 25 curated research tables and 24 current analysis views; staging/import tables remain restricted. Actual login-level security should be tested before release.

**V1 release is not yet frozen.** The final step is an explicit source-to-cleaned column reconciliation, reducing redundant public-facing views while preserving running script compatibility, and documenting each added `_clean` field with its exact derivation in the separate audit.


## Field-by-field dictionary — research tables

The following is the existing documented field dictionary incorporated into the V1 release notes. It explains the meaning of known columns. For all transformations or uncertain legacy coding rules, see [V1_CLEANING_AUDIT.md](V1_CLEANING_AUDIT.md) and the associated version-controlled SQL migrations. Source metadata and measurement units that have not been verified are not claimed to be final.

### Original detailed field glossary

**Dave Hudson | Working Version 1 baseline**

This dictionary describes the canonical `research` tables and the analysis views. It records the fields retained or derived from the original Access imports. The internal database structure and the scientific identifiers are distinguished below.

## General conventions

- `tattoo` is the scientific identifier for each badger.
- `capture_id` links a record to one capture event.
- `individual_id` appears in the underlying research schema only as an internal relational key.
- `created_at` / `imported_at` are database provenance timestamps.
- Recorded free text is retained where historically important.
- Import and staging tables are not canonical research observations.

---

## `research.individuals`

One row per canonical badger.

| Variable | Meaning |
|---|---|
| `individual_id` | Stable database identifier for the badger |
| `tattoo` | Canonical tattoo identifier |
| `elect_tag` | Electronic tag identifier where recorded |
| `age_first_capture` | Recorded age class at first capture |
| `year_first_capture` | Year first captured |
| `sex` | Recorded/canonical sex |
| `notes` | Identity/cleaning notes |
| `created_at` | Database creation timestamp |

## `research.individual_names`

Historical/alternative names associated with a canonical individual.

| Variable | Meaning |
|---|---|
| `individual_name_id` | Row ID |
| `individual_id` | Canonical badger |
| `name` | Historical/alternative recorded name |
| `notes` | Provenance/cleaning notes |
| `created_at` | Database timestamp |

## `research.captures`

One row per capture/PM encounter.

| Variable | Meaning |
|---|---|
| `capture_id` | Stable capture identifier |
| `individual_id` | Canonical badger |
| `capture_date` | Date of capture/record |
| `is_pm` | Whether record is post-mortem |
| `sett_id` | Canonical cleaned sett assignment, if supported |
| `recorded_social_group_id` | Canonical ID for the historically recorded social group |
| `recorded_sett_name` | Original/recorded sett text |
| `recorded_social_group_name` | Original/recorded social-group text |
| `recorded_supergroup_name` | Original/recorded supergroup text |
| `moc` | Method/context-of-capture field retained from source terminology |
| `capture_location_text` | Other historical location text |
| `os_ref` | OS/grid reference where recorded |
| `location_cleaning_note` | Explicit explanation of non-trivial location cleaning |
| `weight` | Weight |
| `body_length` | Body length |
| `temperature` | Recorded body temperature |
| `toothwear` | Tooth-wear measure |
| `neck_diameter` | Neck diameter |
| `condition` | Recorded condition field |
| `reproductive_status` | Reproductive-status text |
| `testes` | Testes field |
| `eartags` | Ear-tag information |
| `retag` | Retag information |
| `transmitter` | Transmitter information |
| `tx_number` | Transmitter number |
| `pm_status` | Original PM-status category |
| `pm_cause` | Cause/context of PM record |
| `disease_status_id` | Link to disease-status lookup |
| `comment` | General capture comment |
| `created_at` | Database timestamp |

## `research.capture_sampling`

Sampling information associated with a capture.

Variables: `capture_sampling_id`, `capture_id`, `sampler`, `recorder`, `blood_taken_time`, `red_tube_volume`, `green_tube_volume`, `purple_tube_volume`, `yellow_tube_volume`, `peach_tube_volume`, `blood_sample_taken`, `hair_sample_taken`, `fur_clip_taken`, `whisker_sample_taken`, `blood_sampler`, `notes`, `created_at`.

Tube-volume variables are recorded volumes for the corresponding sample tubes; boolean `*_taken` fields indicate whether that sample was taken.

## `research.capture_assessments`

Health/welfare assessment information associated with a capture.

Variables: `capture_assessment_id`, `capture_id`, `health_monitoring`, `ho_supervisor`, `severity_assessment`, `severity_initials`, `release_assessment`, `release_initials`, `adverse_effects`, `adverse_effect_sampler`, `adverse_effect_comment`, `created_at`.

## `research.capture_collars`

Collar/transmitter checks and actions at capture.

Variables: `capture_collar_id`, `capture_id`, `collar_action_taken`, `collar_action_taker`, `collar_checked_by`, `collar_scratch_no`, `transmitter`, `best_tune`, `collar_impact_assessment`, `ppm`, `created_at`.

## `research.wounds`

Potentially multiple wound rows per capture.

Variables: `wound_id`, `capture_id`, `wound_area`, `wound_amount`, `wound_age`, `wound_size`, `wound_type`, `notes`, `created_at`.

Multiple wounds can be associated with a single capture.

## `research.cultures`

Culture-test records; potentially multiple samples per capture.

Variables: `culture_id`, `capture_id`, `sample_type`, `afno`, `culture_result`, `lesions`, `abscesses`, `spoligo`, `spolprime`, `wgs_clade`, `sampler_1`, `sampler_2`, `comments`, `created_at`.

## `research.dpp_tests`

DPP diagnostic-test records.

Variables: `dpp_test_id`, `capture_id`, `test_result`, `test_type`, `sample_type`, `visual_line_1`, `visual_line_1_result`, `optical_density_1`, `visual_line_2`, `visual_line_2_result`, `optical_density_2`, `source_raw_row_id`, `comments`, `created_at`.

`source_raw_row_id` provides direct provenance back to the raw imported DPP row.

## `research.dpp_sample_types`

Lookup of accepted DPP sample types.

Variable: `sample_type`.

## `research.dpp_visual_line_results`

Lookup translating DPP visual-line result codes.

Variables: `result_code`, `result_label`.

## `research.stat_pak_tests`

Stat-Pak diagnostic records.

Variables: `stat_pak_test_id`, `capture_id`, `stat_pak_id`, `test_result`, `comments`, `created_at`.

## `research.stat_pak_results`

Lookup for Stat-Pak result codes.

Variables: `result_code`, `result_label`, `display_order`.

## `research.elisa_tests`

ELISA records.

Variables: `elisa_test_id`, `capture_id`, `elisa_type`, `reference`, `test_result`, `mean_od`, `blot_cf`, `blotson`, `comments`, `created_at`.

## `research.ifn_gamma_elisa`

IFN-gamma ELISA records including plate/QC and replicate measurements.

Variables include:

- identity: `ifn_test_id`, `capture_id`;
- plate/import: `plate_number`, `experiment_date`, `import_filename`, `imported_at`;
- summary values: `nil_value`, `avian_ppd_value`, `bovine_ppd_value`, `pwm_value`;
- contrasts: `bovine_minus_nil`, `avian_minus_nil`, `bovine_minus_avian`;
- replicates: `pwm_1`, `pwm_2`, `ppd_a_1`, `ppd_a_2`, `ppd_b_1`, `ppd_b_2`, `nil_1`, `nil_2`;
- QC: `blood_quality`, `retest`, `test_failed`, `qc_note`, well-stage fields;
- interpretation: `test_info`, `test_result`, `comments`.

## `research.brock_tests`

Brock-test records.

Variables: `brock_test_id`, `capture_id`, `brock_test_od`, `test_result`, `no_clotted`, `comments`, `created_at`.

## `research.disease_statuses`

Lookup for disease-status categories.

Variables: `disease_status_id`, `disease_status`.

## `research.setts`

Canonical sett lookup.

Variables:

- `sett_id` — stable ID;
- `sett_name` — canonical name;
- `notes` — provenance/cleaning notes;
- `created_at`.

## `research.social_groups`

Canonical social-group lookup.

Variables: `social_group_id`, `social_group_name`, `notes`, `created_at`.

## `research.supergroups`

Canonical supergroup lookup.

Variables: `supergroup_id`, `supergroup_name`, `notes`, `created_at`.

## `research.sett_social_group_history`

Historically supported sett↔social-group relationships.

Variables: `sett_social_group_id`, `sett_id`, `social_group_id`, `valid_from`, `valid_to`, `notes`.

Null validity dates mean that exact temporal bounds have not been encoded; do not invent them.

## `research.social_group_supergroup_history`

Historically supported social-group↔supergroup relationships.

Variables: `social_group_supergroup_id`, `social_group_id`, `supergroup_id`, `valid_from`, `valid_to`, `notes`.

## `research.infection_probabilities`

Canonical capture-level model-derived infection probabilities.

Variables:

- `infection_probability_id`;
- `individual_id`;
- `capture_id`;
- `sample_date`;
- `year`, `quarter`;
- `model_variant`;
- `infection_probability`;
- `model_run`;
- `source_file`;
- `imported_at`.

These are model outputs, not raw observations.

## `research.infection_quarterly_probabilities`

Canonical quarter-level model-derived infection trajectory.

Variables:

- `infection_quarterly_id`;
- `individual_id`;
- `quarter_date`;
- `year`, `quarter`;
- `model_variant`;
- `infection_probability`;
- `model_run`;
- `source_file`;
- `imported_at`.

## Staging tables — not canonical researcher tables

### `research.infection_probabilities_import`

Temporary/wide import structure for infection probabilities.

### `research.infection_quarterly_import`

Temporary import structure for quarterly probabilities.

These are import/staging tables rather than canonical records.

---

# Analysis views

The curated views are documented in detail in:

`markdown/Woodchester_SQL_R_Analysis_and_Infection_Guide.md`

Important grain:

- `analysis.capture_history` — capture level;
- `analysis.diagnostic_results` — diagnostic-result level;
- `analysis.capture_infection_probabilities` — capture level, wide infection variants;
- `analysis.infection_probabilities` — capture × model variant;
- `analysis.infection_quarterly_probabilities` — badger-quarter;
- `analysis.sett_social_group_observed` — observed sett/SG/year summary;
- `analysis.historical_sett_candidates` — historical location review support.

---

## Additional Version 1 research tables

| Table | Contents |
|---|---|
| `research.sett_location_evidence` | `evidence_id` (record), `sett_id` (sett), `easting`, `northing`, `coordinate_system` (default EPSG:27700), `accuracy_m`, `evidence_type` (FIELD_TEAM/HISTORIC_MAP/GPS/OTHER), `source_reference`, `observed_on`, `recorded_by`, `review_status` (PROPOSED/APPROVED/REJECTED/SUPERSEDED), `reviewed_by`, `reviewed_at`, `notes`, `created_at` |

## Additional Version 1 analysis views

| View | Contents and principal columns |
|---|---|
| `analysis.individual_traits_standardised` | Tattoo, recorded and standardised age/sex, first capture year, missingness flags |
| `analysis.capture_traits_standardised` | Tattoo, capture ID/date/year/quarter, PM status, recorded sett/SG, standardised sex and age, time since first capture and approximate age when first observed as cub |
| `analysis.culture_results_standardised` | Culture source record and capture identifiers, sample type/group, original result, interpreted status, nullable M. bovis detection |
| `analysis.stat_pak_results_standardised` | Stat-Pak source and capture identifiers, recorded result code and interpretation (P positive; N negative; C no clotted sample/invalid) |
| `analysis.diagnostic_interpretation_standardised` | Tattoo, capture ID, test family, family-specific source record ID, recorded result, POSITIVE/NEGATIVE/INVALID/INDETERMINATE status, nullable binary indicator |
| `analysis.capture_diagnostic_summary_standardised` | One row per capture; positive, negative and uninterpretable test counts, descriptive any-positive-test flag |
| `analysis.sett_coordinates_approved` | Approved canonical sett coordinates, CRS, accuracy and source |
| `analysis.sett_field_team_review` | Canonical sett names, number and latest date of associated captures, presence of approved coordinates |
| `analysis.unresolved_recorded_sett_names` | Original sett labels without a canonical sett ID, capture frequency and earliest/latest dates |

## Access import and refresh metadata

| Schema/table | Contents |
|---|---|
| `access_raw` | Twelve original Access source tables imported without applying canonical biological corrections |
| `ingest.access_refresh_batches` | Source filename, checksum, export/import timing, review/application status and version reference |
| `ingest.access_refresh_table_audits` | Source table, expected/current record counts and reconciliation outcomes |
| `ingest.canonical_cleaning_decisions` | Evidence, recorded and cleaned values, review and version metadata for corrections |

## Field values and definitions

The database schema lists the exact column names, types, nullability and supported constraints. The query in [`sql/audit/Woodchester_v1_1_schema_and_value_dictionary.sql`](../../sql/audit/Woodchester_v1_1_schema_and_value_dictionary.sql) regenerates the full column inventory and example distributions. Lookup tables and constraints specify controlled codes where present; free-text fields have observed values rather than a finite permitted list.

The original Access field descriptions and complete allowable-code definitions have not all been recovered. The descriptions above reflect the present database and identifiable source fields; unverified original meanings and measurement units are not asserted as confirmed.


## Consistent V1 location fields (23 October 2026)

I use `analysis.capture_history_v1` for researcher-facing capture history and `analysis.capture_traits_v1` for standardised capture traits. Both retain their existing columns and add `sett_name`, `location_type`, `location_easting`, `location_northing`, `location_crs`, `location_coordinate_basis` and `location_class` by capture ID. The shared implementation is `analysis.capture_location_fields_v1`. Legacy `analysis.capture_history` and `analysis.capture_traits_standardised` remain unchanged for compatibility with running models and earlier analyses.

The standardised `sett_name` is **NULL unless the record has an established canonical sett**. Grid-referenced PM locations have `location_type = 'PM_GRID_REFERENCE'`, `sett_name = NULL`, and provisional grid-square south-west-corner coordinates in the separate `location_easting` and `location_northing` fields. These are not sett coordinates or precise recovery points. Other classifications are `SETT`, `PM_LOCATION_UNRESOLVED`, `UNMATCHED_CAPTURE_LOCATION` and `NOT_RECORDED`. Original `recorded_sett_name`, `os_ref`, `capture_location_text` and `sett_id` remain unchanged.

Validation: 17,586 unique captures in the V1 traits view; capture history V1: 16,337 known-sett rows (16,034 with sett coordinates), 710 grid-referenced PM recovery rows (all have parsed coordinates and **no sett name**), 343 PM location unresolved, 170 other unmatched captures and 26 missing location. The V1 label and initial 23 October baseline remain unchanged; remaining names and spatial-validation questions are explicitly deferred.


## V1 coauthor schema clean-up — 26 October 2026

For the current coauthor-facing structure and permission checks, see [`V1_RELEASE_NOTES.md`](V1_RELEASE_NOTES.md). Seven interim diagnostic/review views were retired on 26 October; the core V1 researcher-facing views, base research tables, raw Access tables and versioned SQL migration records were retained. The historical references to old review-view names elsewhere in this document record the original workflow, not live endpoints. The working baseline is still **V1**.
