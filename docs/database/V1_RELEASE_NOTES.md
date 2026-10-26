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


## Complete live V1 column inventory (26 October 2026)

This is a column-by-column inventory checked against the live schema, covering all 28 research tables and 24 currently deployed analysis views. It includes internal technical views **only to accurately describe the current database**, not to recommend them to coauthors. Specific confirmed meanings are described; legacy field meanings and measurement units not evidenced by source documentation are marked for verification. For cleaning decisions, approved aliases, data migrations and derivations see [V1_CLEANING_AUDIT.md](V1_CLEANING_AUDIT.md). The original source codebook must govern ambiguous fields.

### `analysis.capture_diagnostic_summary_standardised`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `diagnostic_test_count` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `positive_test_count` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `negative_test_count` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `uninterpretable_test_count` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `any_positive_test` | `boolean` | Boolean indicator (NULL distinct from FALSE) |

### `analysis.capture_history`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `elect_tag` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `historical_names` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `n_historical_names` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sex` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `age_first_capture` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `year_first_capture` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `capture_date` | `date` | Encounter date |
| `capture_year` | `integer` | Year extracted from capture date |
| `capture_quarter` | `integer` | Calendar quarter extracted from capture date |
| `capture_occasion` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `moc` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `recorded_sett_name` | `text` | Verbatim original location/sett text |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `normalized_sett_name` | `text` | Derived cleaned/standardised field; consult audit |
| `recorded_social_group_name` | `text` | Original reported SG name (not necessarily resident SG) |
| `recorded_social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `normalized_social_group_name` | `text` | Derived cleaned/standardised field; consult audit |
| `recorded_supergroup_name` | `text` | Original reported supergroup name |
| `capture_location_text` | `text` | Original type/location such as SETT, FIELD, BOUNDARY |
| `os_ref` | `text` | Original OS reference as entered |
| `location_cleaning_note` | `text` | Original descriptive comments/notes |
| `disease_status_id` | `integer` | Row/foreign key; inspect parent table |
| `disease_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `weight` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `body_length` | `numeric` | Quantitative value; measurement units require source validation |
| `temperature` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `toothwear` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `neck_diameter` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `condition` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `reproductive_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `testes` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `eartags` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `retag` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `transmitter` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `tx_number` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `pm_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `pm_cause` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `blood_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `blood_taken_time` | `time without time zone` | Quantitative value; measurement units require source validation |
| `red_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `green_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `purple_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `yellow_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `peach_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `hair_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `fur_clip_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `whisker_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `sampler` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `blood_sampler` | `text` | Quantitative value; measurement units require source validation |
| `recorder` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sampling_notes` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `health_monitoring` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ho_supervisor` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `severity_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `severity_initials` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `release_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `release_initials` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effects` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effect_sampler` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effect_comment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_action_taken` | `text` | Boolean indicator (NULL distinct from FALSE) |
| `collar_action_taker` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_checked_by` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_scratch_no` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_transmitter` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `best_tune` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_impact_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppm` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `comment` | `text` | Original descriptive comments/notes |

### `analysis.capture_history_v1`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `elect_tag` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `historical_names` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `n_historical_names` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sex` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `age_first_capture` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `year_first_capture` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `capture_date` | `date` | Encounter date |
| `capture_year` | `integer` | Year extracted from capture date |
| `capture_quarter` | `integer` | Calendar quarter extracted from capture date |
| `capture_occasion` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `moc` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `recorded_sett_name` | `text` | Verbatim original location/sett text |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `normalized_sett_name` | `text` | Derived cleaned/standardised field; consult audit |
| `recorded_social_group_name` | `text` | Original reported SG name (not necessarily resident SG) |
| `recorded_social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `normalized_social_group_name` | `text` | Derived cleaned/standardised field; consult audit |
| `recorded_supergroup_name` | `text` | Original reported supergroup name |
| `capture_location_text` | `text` | Original type/location such as SETT, FIELD, BOUNDARY |
| `os_ref` | `text` | Original OS reference as entered |
| `location_cleaning_note` | `text` | Original descriptive comments/notes |
| `disease_status_id` | `integer` | Row/foreign key; inspect parent table |
| `disease_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `weight` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `body_length` | `numeric` | Quantitative value; measurement units require source validation |
| `temperature` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `toothwear` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `neck_diameter` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `condition` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `reproductive_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `testes` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `eartags` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `retag` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `transmitter` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `tx_number` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `pm_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `pm_cause` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `blood_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `blood_taken_time` | `time without time zone` | Quantitative value; measurement units require source validation |
| `red_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `green_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `purple_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `yellow_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `peach_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `hair_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `fur_clip_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `whisker_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `sampler` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `blood_sampler` | `text` | Quantitative value; measurement units require source validation |
| `recorder` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sampling_notes` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `health_monitoring` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ho_supervisor` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `severity_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `severity_initials` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `release_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `release_initials` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effects` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effect_sampler` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effect_comment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_action_taken` | `text` | Boolean indicator (NULL distinct from FALSE) |
| `collar_action_taker` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_checked_by` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_scratch_no` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_transmitter` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `best_tune` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_impact_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppm` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `comment` | `text` | Original descriptive comments/notes |
| `sett_name` | `text` | Canonical name when confirmed |
| `location_type` | `text` | Derived location category; not itself sett identity |
| `location_easting` | `numeric` | Coordinate: mapped sett point or provisional PM grid-square SW corner |
| `location_northing` | `numeric` | Coordinate: mapped sett point or provisional PM grid-square SW corner |
| `location_crs` | `text` | Assigned spatial CRS; source confirmation pending |
| `location_coordinate_basis` | `text` | Type/provenance of coordinate |
| `location_class` | `text` | Detailed derived location class |

### `analysis.capture_infection_probabilities`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `sample_date` | `date` | Date or timestamp; provenance/context from owning table |
| `year` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `quarter` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `model_run` | `text` | Quantitative value; measurement units require source validation |
| `diagnostic_fixed_prevalence` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `diagnostic_annual_prevalence` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `diagnostic_adjusted_annual` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `all_tests_fixed` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `all_tests_inferred` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `culture_only_fixed` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `analysis.capture_location_classified_v2`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `original_recorded_sett_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `os_ref` | `text` | Original OS reference as entered |
| `capture_location_text` | `text` | Original type/location such as SETT, FIELD, BOUNDARY |
| `location_class` | `text` | Detailed derived location class |
| `location_display_category` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `reference_source` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `so_grid_six_digits` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_sw_easting` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_sw_northing` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `accompanying_location_description` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `positional_precision_note` | `text` | Original descriptive comments/notes |

### `analysis.capture_location_classified_v3`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `original_recorded_sett_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `os_ref` | `text` | Original OS reference as entered |
| `capture_location_text` | `text` | Original type/location such as SETT, FIELD, BOUNDARY |
| `location_class` | `text` | Detailed derived location class |
| `location_display_category` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `reference_source` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `so_grid_six_digits` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_sw_easting` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_sw_northing` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `accompanying_location_description` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `positional_precision_note` | `text` | Original descriptive comments/notes |
| `newly_parsed_grid_reference` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `newly_parsed_cell_width_m` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `analysis.capture_location_fields_v1`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `sett_name` | `text` | Canonical name when confirmed |
| `location_type` | `text` | Derived location category; not itself sett identity |
| `location_easting` | `numeric` | Coordinate: mapped sett point or provisional PM grid-square SW corner |
| `location_northing` | `numeric` | Coordinate: mapped sett point or provisional PM grid-square SW corner |
| `location_crs` | `text` | Assigned spatial CRS; source confirmation pending |
| `location_coordinate_basis` | `text` | Type/provenance of coordinate |
| `location_class` | `text` | Detailed derived location class |

### `analysis.capture_location_v1`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `original_recorded_sett_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `canonical_sett_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `location_class` | `text` | Detailed derived location class |
| `location_display_category` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `capture_location_text` | `text` | Original type/location such as SETT, FIELD, BOUNDARY |
| `os_ref` | `text` | Original OS reference as entered |
| `reference_source` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `so_grid_six_digits` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `newly_parsed_grid_reference` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_sw_easting` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_sw_northing` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `newly_parsed_cell_width_m` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `accompanying_location_description` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `positional_precision_note` | `text` | Original descriptive comments/notes |
| `spatial_interpretation` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `analysis.capture_pm_grid_reference_review`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `recorded_sett_name` | `text` | Verbatim original location/sett text |
| `capture_location_text` | `text` | Original type/location such as SETT, FIELD, BOUNDARY |
| `os_ref` | `text` | Original OS reference as entered |
| `so_six_digits` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_reference_source` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_cell_easting` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_cell_northing` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `grid_cell_width_m` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `inferred_crs` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `review_status` | `text` | Coordinate evidence review state |

### `analysis.capture_sett_coordinate_inventory`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `sett_name` | `text` | Canonical name when confirmed |
| `n_captures` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `n_pm_records` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `first_capture_date` | `date` | Date or timestamp; provenance/context from owning table |
| `last_capture_date` | `date` | Date or timestamp; provenance/context from owning table |
| `easting` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `northing` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `coordinate_system` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `accuracy_m` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `coordinate_source` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `coordinate_status` | `text` | Recorded/derived code or outcome; consult assay protocol |

### `analysis.capture_traits_standardised`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `capture_date` | `date` | Encounter date |
| `capture_year` | `integer` | Year extracted from capture date |
| `capture_quarter` | `integer` | Calendar quarter extracted from capture date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `recorded_sett_name` | `text` | Verbatim original location/sett text |
| `recorded_social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `recorded_social_group_name` | `text` | Original reported SG name (not necessarily resident SG) |
| `sex_recorded` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sex_standardised` | `text` | Derived cleaned/standardised field; consult audit |
| `sex_missing` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `age_first_capture_recorded` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `age_first_capture_standardised` | `text` | Derived cleaned/standardised field; consult audit |
| `year_first_capture` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `years_since_first_capture` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `approximate_age_if_first_captured_as_cub` | `integer` | Derived proxy; not a measured exact age |

### `analysis.capture_traits_v1`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `capture_date` | `date` | Encounter date |
| `capture_year` | `integer` | Year extracted from capture date |
| `capture_quarter` | `integer` | Calendar quarter extracted from capture date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `recorded_sett_name` | `text` | Verbatim original location/sett text |
| `recorded_social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `recorded_social_group_name` | `text` | Original reported SG name (not necessarily resident SG) |
| `sex_recorded` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sex_standardised` | `text` | Derived cleaned/standardised field; consult audit |
| `sex_missing` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `age_first_capture_recorded` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `age_first_capture_standardised` | `text` | Derived cleaned/standardised field; consult audit |
| `year_first_capture` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `years_since_first_capture` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `approximate_age_if_first_captured_as_cub` | `integer` | Derived proxy; not a measured exact age |
| `sett_name` | `text` | Canonical name when confirmed |
| `location_type` | `text` | Derived location category; not itself sett identity |
| `location_easting` | `numeric` | Coordinate: mapped sett point or provisional PM grid-square SW corner |
| `location_northing` | `numeric` | Coordinate: mapped sett point or provisional PM grid-square SW corner |
| `location_crs` | `text` | Assigned spatial CRS; source confirmation pending |
| `location_coordinate_basis` | `text` | Type/provenance of coordinate |
| `location_class` | `text` | Detailed derived location class |

### `analysis.culture_results_standardised`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `culture_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `sample_type_recorded` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sample_group` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `culture_result_recorded` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `culture_result_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `is_m_bovis_detected` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `afno` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `spoligo` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `spolprime` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wgs_clade` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `analysis.diagnostic_interpretation_standardised`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `test_family` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_record_id` | `bigint` | Row/foreign key; inspect parent table |
| `recorded_result` | `text` | Historical recorded value; preserved |
| `interpreted_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `test_positive` | `boolean` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `analysis.diagnostic_results`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `source_table` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_record_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `tattoo` | `text` | Scientific badger identifier |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `test_family` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `test_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sample_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `result` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `result_code` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `visual_line_1` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `visual_line_1_result` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `optical_density_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `visual_line_2` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `visual_line_2_result` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `optical_density_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `reference_value` | `numeric` | Quantitative value; measurement units require source validation |
| `mean_od` | `numeric` | Quantitative value; measurement units require source validation |
| `blot_cf` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `blotson` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `brock_test_od` | `numeric` | Quantitative value; measurement units require source validation |
| `no_clotted` | `boolean` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `afno` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `lesions` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `abscesses` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `spoligo` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `spolprime` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wgs_clade` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `plate_number` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `experiment_date` | `timestamp without time zone` | Date or timestamp; provenance/context from owning table |
| `nil_value` | `numeric` | Quantitative value; measurement units require source validation |
| `avian_ppd_value` | `numeric` | Quantitative value; measurement units require source validation |
| `bovine_ppd_value` | `numeric` | Quantitative value; measurement units require source validation |
| `pwm_value` | `numeric` | Quantitative value; measurement units require source validation |
| `bovine_minus_nil` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `avian_minus_nil` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `bovine_minus_avian` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `pwm_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `pwm_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppd_a_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppd_a_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppd_b_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppd_b_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `nil_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `nil_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `retest` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `test_failed` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `test_info` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `blood_quality` | `text` | Quantitative value; measurement units require source validation |
| `qc_note` | `text` | Original descriptive comments/notes |
| `comments` | `text` | Original descriptive comments/notes |

### `analysis.individual_traits_standardised`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier |
| `elect_tag` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `age_first_capture_recorded` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `age_first_capture_standardised` | `text` | Derived cleaned/standardised field; consult audit |
| `age_first_capture_missing` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `year_first_capture` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sex_recorded` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sex_standardised` | `text` | Derived cleaned/standardised field; consult audit |
| `sex_missing` | `boolean` | Boolean indicator (NULL distinct from FALSE) |

### `analysis.infection_probabilities`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `infection_probability_id` | `bigint` | Row/foreign key; inspect parent table |
| `tattoo` | `text` | Scientific badger identifier |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `sample_date` | `date` | Date or timestamp; provenance/context from owning table |
| `year` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `quarter` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `model_variant` | `text` | Named infection-model variant |
| `infection_probability` | `double precision` | Model-estimated infection probability; not direct test |
| `model_run` | `text` | Quantitative value; measurement units require source validation |
| `source_file` | `text` | Source filename recorded during import |
| `imported_at` | `timestamp with time zone` | Import provenance timestamp |

### `analysis.infection_quarterly_probabilities`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `infection_quarterly_id` | `bigint` | Row/foreign key; inspect parent table |
| `tattoo` | `text` | Scientific badger identifier |
| `quarter_date` | `date` | Date or timestamp; provenance/context from owning table |
| `year` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `quarter` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `model_variant` | `text` | Named infection-model variant |
| `infection_probability` | `double precision` | Model-estimated infection probability; not direct test |
| `model_run` | `text` | Quantitative value; measurement units require source validation |
| `source_file` | `text` | Source filename recorded during import |
| `imported_at` | `timestamp with time zone` | Import provenance timestamp |

### `analysis.sett_coordinate_source_name_review`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `source_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_display_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `easting` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `northing` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `matched_canonical_sett` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `match_status` | `text` | Recorded/derived code or outcome; consult assay protocol |

### `analysis.sett_coordinate_unmatched_v1`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `source_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_display_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `easting` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `northing` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `match_status` | `text` | Recorded/derived code or outcome; consult assay protocol |

### `analysis.sett_coordinates_approved`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `sett_name` | `text` | Canonical name when confirmed |
| `easting` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `northing` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `coordinate_system` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `accuracy_m` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_reference` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `observed_on` | `date` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `analysis.sett_inventory_v1`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `canonical_sett_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `capture_count` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `n_pm_records` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `first_capture_date` | `date` | Date or timestamp; provenance/context from owning table |
| `last_capture_date` | `date` | Date or timestamp; provenance/context from owning table |
| `easting` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `northing` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `coordinate_system` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `accuracy_m` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `coordinate_source` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `coordinate_status` | `text` | Recorded/derived code or outcome; consult assay protocol |

### `analysis.sett_social_group_observed`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `sett_name` | `text` | Canonical name when confirmed |
| `social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `social_group_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `year` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `n_captures` | `bigint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `first_capture_date` | `date` | Date or timestamp; provenance/context from owning table |
| `last_capture_date` | `date` | Date or timestamp; provenance/context from owning table |

### `analysis.stat_pak_results_standardised`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `stat_pak_test_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_date` | `date` | Encounter date |
| `original_result_code` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `original_result_text` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `result_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `test_positive` | `boolean` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `research.brock_tests`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `brock_test_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `brock_test_od` | `numeric` | Quantitative value; measurement units require source validation |
| `test_result` | `text` | Recorded test result; codes vary by assay |
| `no_clotted` | `boolean` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `comments` | `text` | Original descriptive comments/notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.capture_assessments`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_assessment_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `health_monitoring` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ho_supervisor` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `severity_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `severity_initials` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `release_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `release_initials` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effects` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effect_sampler` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `adverse_effect_comment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.capture_collars`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_collar_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `collar_action_taken` | `text` | Boolean indicator (NULL distinct from FALSE) |
| `collar_action_taker` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_checked_by` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_scratch_no` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `transmitter` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `best_tune` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `collar_impact_assessment` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppm` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.capture_sampling`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_sampling_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `sampler` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `recorder` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `blood_taken_time` | `time without time zone` | Quantitative value; measurement units require source validation |
| `red_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `green_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `purple_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `peach_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `hair_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `fur_clip_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `whisker_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |
| `notes` | `text` | Source or record-specific notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |
| `blood_sampler` | `text` | Quantitative value; measurement units require source validation |
| `yellow_tube_volume` | `numeric` | Quantitative value; measurement units require source validation |
| `blood_sample_taken` | `boolean` | Boolean indicator (NULL distinct from FALSE) |

### `research.captures`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `capture_id` | `bigint` | Unique capture or PM event key |
| `individual_id` | `bigint` | Internal link to badger record |
| `capture_date` | `date` | Encounter date |
| `is_pm` | `boolean` | Post-mortem versus live encounter indicator |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `recorded_social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `recorded_sett_name` | `text` | Verbatim original location/sett text |
| `recorded_social_group_name` | `text` | Original reported SG name (not necessarily resident SG) |
| `recorded_supergroup_name` | `text` | Original reported supergroup name |
| `moc` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `capture_location_text` | `text` | Original type/location such as SETT, FIELD, BOUNDARY |
| `weight` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `body_length` | `numeric` | Quantitative value; measurement units require source validation |
| `temperature` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `toothwear` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `neck_diameter` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `condition` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `reproductive_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `testes` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `eartags` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `retag` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `transmitter` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `tx_number` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `pm_status` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `pm_cause` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `comment` | `text` | Original descriptive comments/notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |
| `location_cleaning_note` | `text` | Original descriptive comments/notes |
| `disease_status_id` | `integer` | Row/foreign key; inspect parent table |
| `os_ref` | `text` | Original OS reference as entered |

### `research.cultures`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `culture_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `sample_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `afno` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `culture_result` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `lesions` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `abscesses` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `spoligo` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `spolprime` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wgs_clade` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sampler_1` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sampler_2` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `comments` | `text` | Original descriptive comments/notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.disease_statuses`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `disease_status_id` | `integer` | Row/foreign key; inspect parent table |
| `disease_status` | `text` | Recorded/derived code or outcome; consult assay protocol |

### `research.dpp_sample_types`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `sample_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `research.dpp_tests`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `dpp_test_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `test_result` | `text` | Recorded test result; codes vary by assay |
| `comments` | `text` | Original descriptive comments/notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |
| `test_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sample_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `visual_line_1` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `optical_density_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `visual_line_2` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `optical_density_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_raw_row_id` | `bigint` | ID connecting DPP to original imported raw row |
| `visual_line_1_result` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `visual_line_2_result` | `text` | Recorded/derived code or outcome; consult assay protocol |

### `research.dpp_visual_line_results`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `result_code` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `result_label` | `text` | Recorded/derived code or outcome; consult assay protocol |

### `research.elisa_tests`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `elisa_test_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `elisa_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `reference` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `test_result` | `text` | Recorded test result; codes vary by assay |
| `mean_od` | `numeric` | Quantitative value; measurement units require source validation |
| `blot_cf` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `blotson` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `comments` | `text` | Original descriptive comments/notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.ifn_gamma_elisa`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `ifn_test_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `plate_number` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `experiment_date` | `timestamp without time zone` | Date or timestamp; provenance/context from owning table |
| `import_filename` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `imported_at` | `timestamp without time zone` | Import provenance timestamp |
| `blood_quality` | `text` | Quantitative value; measurement units require source validation |
| `nil_value` | `numeric` | Quantitative value; measurement units require source validation |
| `avian_ppd_value` | `numeric` | Quantitative value; measurement units require source validation |
| `bovine_ppd_value` | `numeric` | Quantitative value; measurement units require source validation |
| `pwm_value` | `numeric` | Quantitative value; measurement units require source validation |
| `bovine_minus_nil` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `avian_minus_nil` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `bovine_minus_avian` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `test_info` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `test_result` | `text` | Recorded test result; codes vary by assay |
| `comments` | `text` | Original descriptive comments/notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |
| `pwm_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `pwm_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppd_a_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppd_a_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppd_b_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `ppd_b_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `nil_1` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `nil_2` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `retest` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `test_failed` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `capture_datetime` | `timestamp without time zone` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wellstage_96_pwm_1` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wellstage_96_pwm_2` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wellstage_96_ppda_1` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wellstage_96_ppda_2` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wellstage_96_ppdb_1` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wellstage_96_ppdb_2` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wellstage_96_nil_1` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wellstage_96_nil_2` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `qc_note` | `text` | Original descriptive comments/notes |

### `research.individual_names`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `individual_name_id` | `bigint` | Row/foreign key; inspect parent table |
| `individual_id` | `bigint` | Internal link to badger record |
| `name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `notes` | `text` | Source or record-specific notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.individuals`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `individual_id` | `bigint` | Internal link to badger record |
| `tattoo` | `text` | Scientific badger identifier |
| `elect_tag` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `age_first_capture` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `year_first_capture` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `sex` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `notes` | `text` | Source or record-specific notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.infection_probabilities`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `infection_probability_id` | `bigint` | Row/foreign key; inspect parent table |
| `individual_id` | `bigint` | Internal link to badger record |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `sample_date` | `date` | Date or timestamp; provenance/context from owning table |
| `year` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `quarter` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `model_variant` | `text` | Named infection-model variant |
| `infection_probability` | `double precision` | Model-estimated infection probability; not direct test |
| `model_run` | `text` | Quantitative value; measurement units require source validation |
| `source_file` | `text` | Source filename recorded during import |
| `imported_at` | `timestamp with time zone` | Import provenance timestamp |

### `research.infection_probabilities_import`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier |
| `date` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `year` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `quarter` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `diagnostic_fixed_prevalence` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `diagnostic_annual_prevalence` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `diagnostic_adjusted_annual` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `all_tests_fixed` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `all_tests_inferred` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `culture_only_fixed` | `double precision` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `research.infection_quarterly_import`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier |
| `quarter_date` | `date` | Date or timestamp; provenance/context from owning table |
| `year` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `quarter` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `infection_probability` | `double precision` | Model-estimated infection probability; not direct test |

### `research.infection_quarterly_probabilities`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `infection_quarterly_id` | `bigint` | Row/foreign key; inspect parent table |
| `individual_id` | `bigint` | Internal link to badger record |
| `quarter_date` | `date` | Date or timestamp; provenance/context from owning table |
| `year` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `quarter` | `smallint` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `model_variant` | `text` | Named infection-model variant |
| `infection_probability` | `double precision` | Model-estimated infection probability; not direct test |
| `model_run` | `text` | Quantitative value; measurement units require source validation |
| `source_file` | `text` | Source filename recorded during import |
| `imported_at` | `timestamp with time zone` | Import provenance timestamp |

### `research.sett_coordinate_source_20261023`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `source_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_display_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `easting` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `northing` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_file` | `text` | Source filename recorded during import |
| `coordinate_system` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `imported_on` | `date` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `research.sett_location_evidence`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `evidence_id` | `bigint` | Row/foreign key; inspect parent table |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `easting` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `northing` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `coordinate_system` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `accuracy_m` | `numeric` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `evidence_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `source_reference` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `observed_on` | `date` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `recorded_by` | `text` | Historical recorded value; preserved |
| `review_status` | `text` | Coordinate evidence review state |
| `reviewed_by` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `reviewed_at` | `timestamp with time zone` | Date or timestamp; provenance/context from owning table |
| `notes` | `text` | Source or record-specific notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.sett_social_group_history`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `sett_social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `valid_from` | `date` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `valid_to` | `date` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `notes` | `text` | Source or record-specific notes |

### `research.setts`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `sett_id` | `bigint` | Resolved canonical sett key; NULL if unsettled |
| `sett_name` | `text` | Canonical name when confirmed |
| `notes` | `text` | Source or record-specific notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.social_group_supergroup_history`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `social_group_supergroup_id` | `bigint` | Row/foreign key; inspect parent table |
| `social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `supergroup_id` | `bigint` | Row/foreign key; inspect parent table |
| `valid_from` | `date` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `valid_to` | `date` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `notes` | `text` | Source or record-specific notes |

### `research.social_groups`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `social_group_id` | `bigint` | Row/foreign key; inspect parent table |
| `social_group_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `notes` | `text` | Source or record-specific notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.stat_pak_results`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `result_code` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `result_label` | `text` | Recorded/derived code or outcome; consult assay protocol |
| `display_order` | `integer` | Field retained in named source/derived view; consult source definitions for exact coding/units |

### `research.stat_pak_tests`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `stat_pak_test_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `test_result` | `text` | Recorded test result; codes vary by assay |
| `comments` | `text` | Original descriptive comments/notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |
| `stat_pak_id` | `text` | Row/foreign key; inspect parent table |

### `research.supergroups`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `supergroup_id` | `bigint` | Row/foreign key; inspect parent table |
| `supergroup_name` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `notes` | `text` | Source or record-specific notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |

### `research.wounds`

| Column | SQL type | Meaning / caution |
|---|---|---|
| `wound_id` | `bigint` | Row/foreign key; inspect parent table |
| `capture_id` | `bigint` | Unique capture or PM event key |
| `wound_area` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wound_amount` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wound_age` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wound_size` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `wound_type` | `text` | Field retained in named source/derived view; consult source definitions for exact coding/units |
| `notes` | `text` | Source or record-specific notes |
| `created_at` | `timestamp with time zone` | Database insertion/provenance timestamp |


## Implemented V1 cleaned columns (26 October 2026)

The following **exist in the live `research` tables**, alongside the original columns. They are not merely proposals. Exact SQL and verification are in [V1_CLEANING_AUDIT.md](V1_CLEANING_AUDIT.md).

| Table | Original field | New cleaned field | Meaning and accepted values |
|---|---|---|---|
| `research.individuals` | `sex` | `sex_clean` | Uppercase `MALE`, `FEMALE`; other/missing → `UNKNOWN`. Automatically generated. |
| `research.individuals` | `age_first_capture` | `age_first_capture_clean` | Uppercase `CUB`, `YEARLING`, `ADULT`; other/missing → `UNKNOWN`. Automatically generated. |
| `research.captures` | `recorded_sett_name` | `sett_name_clean` | Canonical label from `sett_id`; `NULL` if unassigned, including PM grid recoveries. Trigger-maintained. |
| `research.captures` | `recorded_social_group_name` | `social_group_name_clean` | Canonical label from `recorded_social_group_id`; `NULL` if unassigned. Trigger-maintained; not proof of residency. |

**Important:** Cleaned `UNKNOWN` sex/age is an explicit category and is not the same as the original column being NULL. Existing calculated `analysis.*standardised` views were retained for model compatibility, not because coauthors should prefer them. The 57-column original Access capture table has not yet been fully reconstructed from split research capture/sampling/assessment/collar tables, so we have **not** dropped or merged those tables. The 24 analysis views have also not yet been physically reduced because several support current V1 interfaces or running models; the recommended subset remains identified above. This is a safe additive V1 clean-up, rather than a completed destructive restructure.


## Implemented capture-field consolidation — 26 October 2026

**The live `research.captures` table now contains 63 columns** and remains one row per capture/PM event (**17,586 records; 17,586 unique `capture_id` values**). The one-to-one capture details previously stored separately have been copied onto it: sampling (`blood_taken_time`, tube volumes, sampler, specimen flags, etc.), assessments (`severity_assessment`, `release_assessment`, `adverse_effects`, etc.), and collars (`collar_action_taken`, `collar_checked_by`, `collar_transmitter`, etc.). In case of name collision, collar `transmitter` is exposed as `collar_transmitter` and capture-sampling `notes` as `sampling_notes`. The historic raw `access_raw.tbl_captures` remains unchanged; the original capture text and four `*_clean` fields remain intact.

The split `research.capture_sampling`, `capture_assessments`, and `capture_collars` **still physically exist** for compatibility with existing R scripts and analysis views. Coauthors should start from **`research.captures`**, not join those tables again unless explicitly needed. Comparison with the split tables found zero mismatches for the checked `blood_taken_time`, `collar_transmitter` and `adverse_effects` fields; full row-by-row Access-source parity is still pending. The `analysis` views have not yet been reduced from 24, because technical dependencies and external model scripts need migration before destructive drops. This V1 step simplifies the **main research capture interface**, not the count of physical database objects.

For field-by-field descriptions, follow the live schema column inventory and this source-to-cleaned guide. For exact SQL, provenance and validation see [V1_CLEANING_AUDIT.md](V1_CLEANING_AUDIT.md).
