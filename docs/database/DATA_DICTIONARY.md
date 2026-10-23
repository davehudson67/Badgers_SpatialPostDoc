# Woodchester Badger Database — Data Dictionary

**Updated:** 16 October 2026

This is a working key to the canonical `research` tables.

Where a description is based only on field naming/current structure rather than surviving original Access documentation, treat it as a practical interpretation to be checked against original source documentation if available.

## General conventions

- Fields ending `_id` are stable relational identifiers.
- `capture_id` links a record to one capture event.
- `individual_id` links a record to one canonical badger.
- `created_at` / `imported_at` are database provenance timestamps.
- Recorded free text is retained where historically important.
- Import/staging tables are not canonical research products.

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

Do not join this to another one-to-many table without considering row multiplication.

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

These are intentionally excluded from `badger_research_readonly`.

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

# Original Access descriptions

The imported raw schema preserves original field names, which is useful evidence of intended meaning.

However, a complete set of original Access field descriptions/forms/validation rules has not yet been recovered into this dictionary.

If the original `.accdb` or an Access schema export is available, the next dictionary improvement should be to extract:

- table descriptions;
- field descriptions;
- lookup lists;
- relationships;
- validation rules;
- form labels/tooltips where scientifically informative.

Those should be added as **source-derived descriptions**, rather than silently replacing this working interpretation.


## Version 1.1 — comprehensive dictionary and valid-value policy (23 October 2026)

The material above describes the original canonical research tables. The **authoritative inventory of every column** across `access_raw`, `research`, `analysis` and private `ingest` can be regenerated using [`sql/audit/Woodchester_v1_1_schema_and_value_dictionary.sql`](../../sql/audit/Woodchester_v1_1_schema_and_value_dictionary.sql). The live database is the authority for column existence and SQL type; this prose dictionary is the place for scientific meanings, measurement units, applicable periods and evidence notes.

**Do not confuse observed values with allowed values.** Database `CHECK` constraints or lookup tables, where available, define allowed codes. For unconstrained free-text fields, report *observed distinct values and frequencies* rather than implying a closed valid-code list. The companion SQL provides examples and the full-column inventory. Distinguish SQL NULL, source literal UNKNOWN, invalid test, missing test and source NOT TESTED.

### Additional V1 standardisation outputs

- `analysis.individual_traits_standardised`: `tattoo`, recorded/standardised age-first-capture and sex, year first captured and corresponding `*_missing` flags.
- `analysis.capture_traits_standardised`: one row per canonical capture, with `tattoo`, `capture_id`, date/year/quarter, original and standardised individual attributes, elapsed years since first capture, and a separately named approximate age only for first-capture CUB records.
- `analysis.culture_results_standardised`: one sample/test row, original result text, standardised culture status, grouped sample type, nullable `is_m_bovis_detected`.
- `analysis.stat_pak_results_standardised`: one row per Stat-Pak test; `original_result_code` has lookup-verified N=negative, P=positive and C=no clotted sample (invalid).
- `analysis.diagnostic_interpretation_standardised`: one row per assay/sample across six test families. `test_family` distinguishes test domains; `source_record_id` identifies a record **within** its family; `interpreted_status` = POSITIVE/NEGATIVE/INVALID/INDETERMINATE, with nullable `test_positive`.
- `analysis.capture_diagnostic_summary_standardised`: one row per capture, diagnostic counts and descriptive any-positive flag (not a latent infection diagnosis).
- `analysis.sett_coordinates_approved`: one coordinate record per currently approved canonical sett; preserves provenance/precision.
- `analysis.sett_field_team_review`: each canonical sett, frequency and last capture, and whether there is an approved coordinate.
- `analysis.unresolved_recorded_sett_names`: distinct source location labels that have no verified canonical sett ID, with frequency and first/last dates.

### Sett evidence table: `research.sett_location_evidence`

Fields: `evidence_id` unique entry; `sett_id` canonical physical sett; `easting`/`northing` numeric coordinates **in `coordinate_system`**, default EPSG:27700; `accuracy_m` stated uncertainty (metres); `evidence_type` one of FIELD_TEAM, HISTORIC_MAP, GPS, OTHER; `source_reference` citation or field record; `observed_on` observation date; `recorded_by`, `notes`; `review_status` PROPOSED/APPROVED/REJECTED/SUPERSEDED; `reviewed_by`/`reviewed_at`; `created_at`. A partial unique index forbids two simultaneous APPROVED records for the same sett. The table starts empty; **no coordinates have been invented**.

### Private refresh and decision tables

`ingest.access_refresh_batches`: `batch_id`, source file name and SHA256, exported and registered dates, status (REGISTERED, STAGED, REVIEWED, APPLIED, REJECTED), Git commit, notes.
`ingest.access_refresh_table_audits`: per-batch table counts and changed/new/missing/ambiguous rows, decision status (PENDING, PASS, REVIEW, FAIL), JSON audit evidence.
`ingest.canonical_cleaning_decisions`: recorded and proposed canonical values, rule version, evidence/rationale, approval status (PROPOSED, APPROVED, REJECTED, SUPERSEDED), reviewer and Git commit.

**Outstanding documentation gap:** some original Access field labels, units and validation-code meanings are not yet independently evidenced. Do not invent these. The SQL inventory is complete as a schema query, but a fully human-curated definition for *each* raw and derived field requires checking Access forms/lookup tables and the field team.
