# Woodchester research database — V1 release notes

**V1 preparation snapshot: 26 October 2026.** This coauthor guide describes the **actual live schema**, not historical audit snapshots. For every cleaning decision, source mapping, executable transformation, verification result and outstanding discrepancy, see [V1 Cleaning Audit](V1_CLEANING_AUDIT.md) and the versioned SQL migrations. Definitions not supported by the original Access codebook are clearly marked for verification, rather than guessed.

## Database structure

- `access_raw`: original 12 Access-derived tables, retained unchanged and not the everyday coauthor interface.
- `research`: 25 base tables, **22 curated data/reference tables** plus three internal staging/source tables. A single `research.captures` table contains the sampling, assessment and collar fields that formerly lived in three one-to-one tables.
- `analysis`: 24 existing views, including internal implementation dependencies; only the six primary interfaces listed below need be learned by most coauthors. Existing model-compatibility views are retained for now.
- `ingest`: internal imports/audit/baseline metadata, maintainers only.

Read-only access is intended for both research and analysis. The read-only database roles are configured, but a real end-user connection/security test is still required before release.

## Key conventions

- `tattoo` identifies the badger; `capture_id` identifies an encounter; `individual_id` is an internal relational key.
- Original values remain in recorded columns; `*_clean` contains independently described cleaned interpretations. `sex_clean` and `age_first_capture_clean` are generated; `sett_name_clean` and `social_group_name_clean` reflect canonical identifiers. The original is not overwritten.
- No canonical sett is inferred from an unresolved PM grid or a social-group centroid. PM decoded grids represent a provisional **southwest grid-square corner**, not a measured point.
- Original `access_raw.tbl_captures` is still preserved. The consolidated `research.captures` has **63 fields, 17,586 unique capture events**, including original sampling/collar/assessment data and separate clean fields.
- 16,337 capture records have a canonical sett, 710 a provisional PM grid reference, 343 PM locations unresolved, 170 unmatched live locations, and 26 no location. These flags have not been silently repaired.

## Recommended analysis interfaces

| View | Meaning |
|---|---|
| `analysis.capture_history_v1` | Recommended combined capture-history representation (one record per capture). |
| `analysis.capture_location_v1` | Location semantics distinguishing named setts from recovered grid positions. |
| `analysis.sett_inventory_v1` | Canonical sett list with mapped coordinate evidence and capture counts. |
| `analysis.diagnostic_results` | Combined individual assay observations. |
| `analysis.infection_probabilities` | Infection probability model outputs, long format. |
| `analysis.infection_quarterly_probabilities` | Modelled infection probability at quarter level. |

All other analysis views are supporting harmonizations, legacy model-compatibility aliases or location-parsing dependencies. They are inventoried below for accuracy, not advertised as separate alternative datasets. See the audit for derivations. No running model's referenced SQL view was removed in this cleanup.

## Research tables and complete column dictionary

### `research.brock_tests`

Brock assay records.

| Column | Type | Description / caveat |
|---|---|---|
| `brock_test_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `brock_test_od` | `numeric` | Measurement; units or assay calibration require verification. |
| `test_result` | `text` | Recorded assay result; original coding context is assay-specific. |
| `no_clotted` | `boolean` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `comments` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.captures`

Single consolidated table: one row per live capture/PM record including sampling, collar and welfare fields.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `individual_id` | `bigint` | Internal joining key; tattoo is the scientific badger identifier. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `recorded_social_group_id` | `bigint` | Matched canonical ID of recorded social group. |
| `recorded_sett_name` | `text` | Original location/sett text from the source, preserved; may not be a sett. |
| `recorded_social_group_name` | `text` | Original reported group name, preserved. |
| `recorded_supergroup_name` | `text` | Original reported supergroup text, preserved. |
| `moc` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_location_text` | `text` | Original location category or descriptive text, e.g. SETT or FIELD. |
| `weight` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `body_length` | `numeric` | Measurement; units or assay calibration require verification. |
| `temperature` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `toothwear` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `neck_diameter` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `condition` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `reproductive_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `testes` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `eartags` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `retag` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `transmitter` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `tx_number` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `pm_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `pm_cause` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `comment` | `text` | Capture-level original comment. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |
| `location_cleaning_note` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `disease_status_id` | `integer` | Internal primary/foreign key; consult table links. |
| `os_ref` | `text` | Original recorded OS grid-reference text. |
| `sett_name_clean` | `text` | Clean named sett using confirmed sett_id, NULL otherwise. |
| `social_group_name_clean` | `text` | Cleaned name of historically recorded group ID, not annual residency. |
| `sampler` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `recorder` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blood_taken_time` | `time without time zone` | Measurement; units or assay calibration require verification. |
| `red_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `green_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `purple_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `peach_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `hair_sample_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `fur_clip_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `whisker_sample_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `sampling_notes` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blood_sampler` | `text` | Measurement; units or assay calibration require verification. |
| `yellow_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `blood_sample_taken` | `boolean` | Measurement; units or assay calibration require verification. |
| `health_monitoring` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ho_supervisor` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `severity_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `severity_initials` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `release_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `release_initials` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effects` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effect_sampler` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effect_comment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_action_taken` | `text` | Boolean indicator; NULL is not FALSE. |
| `collar_action_taker` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_checked_by` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_scratch_no` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_transmitter` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `best_tune` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_impact_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppm` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `research.cultures`

Culture and molecular isolate results by sample.

| Column | Type | Description / caveat |
|---|---|---|
| `culture_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `sample_type` | `text` | Recorded diagnostic specimen category. |
| `afno` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `culture_result` | `text` | Result or status; assay/source code meanings must be verified. |
| `lesions` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `abscesses` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `spoligo` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `spolprime` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wgs_clade` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sampler_1` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sampler_2` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `comments` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.disease_statuses`

Recorded disease category lookup.

| Column | Type | Description / caveat |
|---|---|---|
| `disease_status_id` | `integer` | Internal primary/foreign key; consult table links. |
| `disease_status` | `text` | Result or status; assay/source code meanings must be verified. |

### `research.dpp_sample_types`

DPP sample-type codes.

| Column | Type | Description / caveat |
|---|---|---|
| `sample_type` | `text` | Recorded diagnostic specimen category. |

### `research.dpp_tests`

DPP assay records.

| Column | Type | Description / caveat |
|---|---|---|
| `dpp_test_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `test_result` | `text` | Recorded assay result; original coding context is assay-specific. |
| `comments` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |
| `test_type` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sample_type` | `text` | Recorded diagnostic specimen category. |
| `visual_line_1` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `optical_density_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `visual_line_2` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `optical_density_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_raw_row_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `visual_line_1_result` | `text` | Result or status; assay/source code meanings must be verified. |
| `visual_line_2_result` | `text` | Result or status; assay/source code meanings must be verified. |

### `research.dpp_visual_line_results`

DPP visual result lookup.

| Column | Type | Description / caveat |
|---|---|---|
| `result_code` | `text` | Result or status; assay/source code meanings must be verified. |
| `result_label` | `text` | Result or status; assay/source code meanings must be verified. |

### `research.elisa_tests`

Serological ELISA assay records.

| Column | Type | Description / caveat |
|---|---|---|
| `elisa_test_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `elisa_type` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `reference` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `test_result` | `text` | Recorded assay result; original coding context is assay-specific. |
| `mean_od` | `numeric` | Measurement; units or assay calibration require verification. |
| `blot_cf` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blotson` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `comments` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.ifn_gamma_elisa`

IFN-gamma assay details and replicate readings.

| Column | Type | Description / caveat |
|---|---|---|
| `ifn_test_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `plate_number` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `experiment_date` | `timestamp without time zone` | Date/period or provenance timestamp. |
| `import_filename` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `imported_at` | `timestamp without time zone` | Date/period or provenance timestamp. |
| `blood_quality` | `text` | Measurement; units or assay calibration require verification. |
| `nil_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `avian_ppd_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `bovine_ppd_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `pwm_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `bovine_minus_nil` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `avian_minus_nil` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `bovine_minus_avian` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `test_info` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `test_result` | `text` | Recorded assay result; original coding context is assay-specific. |
| `comments` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |
| `pwm_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `pwm_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppd_a_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppd_a_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppd_b_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppd_b_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `nil_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `nil_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `retest` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `test_failed` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_datetime` | `timestamp without time zone` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wellstage_96_pwm_1` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wellstage_96_pwm_2` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wellstage_96_ppda_1` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wellstage_96_ppda_2` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wellstage_96_ppdb_1` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wellstage_96_ppdb_2` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wellstage_96_nil_1` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wellstage_96_nil_2` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `qc_note` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `research.individual_names`

Historic names associated with a badger.

| Column | Type | Description / caveat |
|---|---|---|
| `individual_name_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `individual_id` | `bigint` | Internal joining key; tattoo is the scientific badger identifier. |
| `name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `notes` | `text` | Narrative/source notes in owning table. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.individuals`

One row per badger; tattoo identifies the animal.

| Column | Type | Description / caveat |
|---|---|---|
| `individual_id` | `bigint` | Internal joining key; tattoo is the scientific badger identifier. |
| `tattoo` | `text` | Scientific badger identifier. |
| `elect_tag` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `age_first_capture` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `year_first_capture` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sex` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `notes` | `text` | Narrative/source notes in owning table. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |
| `sex_clean` | `text` | Generated MALE/FEMALE/UNKNOWN; original sex preserved. |
| `age_first_capture_clean` | `text` | Generated CUB/YEARLING/ADULT/UNKNOWN; original age class preserved. |

### `research.infection_probabilities`

New model-predicted infection probabilities at event/date.

| Column | Type | Description / caveat |
|---|---|---|
| `infection_probability_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `individual_id` | `bigint` | Internal joining key; tattoo is the scientific badger identifier. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `sample_date` | `date` | Date/period or provenance timestamp. |
| `year` | `smallint` | Date/period or provenance timestamp. |
| `quarter` | `smallint` | Date/period or provenance timestamp. |
| `model_variant` | `text` | Identity of probability model variant; essential to comparing estimates. |
| `infection_probability` | `double precision` | Estimated probability from model; not measured infection result. |
| `model_run` | `text` | Model run name/version. |
| `source_file` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `imported_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.infection_probabilities_import`

Internal source-import staging; not curated observations.

| Column | Type | Description / caveat |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier. |
| `date` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `year` | `integer` | Date/period or provenance timestamp. |
| `quarter` | `integer` | Date/period or provenance timestamp. |
| `diagnostic_fixed_prevalence` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `diagnostic_annual_prevalence` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `diagnostic_adjusted_annual` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `all_tests_fixed` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `all_tests_inferred` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `culture_only_fixed` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `research.infection_quarterly_import`

Internal quarterly import staging.

| Column | Type | Description / caveat |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier. |
| `quarter_date` | `date` | Date/period or provenance timestamp. |
| `year` | `integer` | Date/period or provenance timestamp. |
| `quarter` | `integer` | Date/period or provenance timestamp. |
| `infection_probability` | `double precision` | Estimated probability from model; not measured infection result. |

### `research.infection_quarterly_probabilities`

New quarterly infection trajectories.

| Column | Type | Description / caveat |
|---|---|---|
| `infection_quarterly_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `individual_id` | `bigint` | Internal joining key; tattoo is the scientific badger identifier. |
| `quarter_date` | `date` | Date/period or provenance timestamp. |
| `year` | `smallint` | Date/period or provenance timestamp. |
| `quarter` | `smallint` | Date/period or provenance timestamp. |
| `model_variant` | `text` | Identity of probability model variant; essential to comparing estimates. |
| `infection_probability` | `double precision` | Estimated probability from model; not measured infection result. |
| `model_run` | `text` | Model run name/version. |
| `source_file` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `imported_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.sett_coordinate_source_20261023`

Internal unmodified sett-coordinate source.

| Column | Type | Description / caveat |
|---|---|---|
| `source_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_display_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `easting` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `northing` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_file` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_system` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `imported_on` | `date` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `research.sett_location_evidence`

Sett coordinate observations, source and review metadata.

| Column | Type | Description / caveat |
|---|---|---|
| `evidence_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `easting` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `northing` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_system` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `accuracy_m` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `evidence_type` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_reference` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `observed_on` | `date` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `recorded_by` | `text` | Original source value; do not mistake for a derived clean field. |
| `review_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `reviewed_by` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `reviewed_at` | `timestamp with time zone` | Date/period or provenance timestamp. |
| `notes` | `text` | Narrative/source notes in owning table. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.sett_social_group_history`

Date-bounded sett-to-group relationships.

| Column | Type | Description / caveat |
|---|---|---|
| `sett_social_group_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `social_group_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `valid_from` | `date` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `valid_to` | `date` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `notes` | `text` | Narrative/source notes in owning table. |

### `research.setts`

Named canonical sett inventory.

| Column | Type | Description / caveat |
|---|---|---|
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `sett_name` | `text` | Canonical named sett from the sett lookup. |
| `notes` | `text` | Narrative/source notes in owning table. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.social_group_supergroup_history`

Date-bounded group-to-supergroup relationships.

| Column | Type | Description / caveat |
|---|---|---|
| `social_group_supergroup_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `social_group_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `supergroup_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `valid_from` | `date` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `valid_to` | `date` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `notes` | `text` | Narrative/source notes in owning table. |

### `research.social_groups`

Social-group lookup.

| Column | Type | Description / caveat |
|---|---|---|
| `social_group_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `social_group_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `notes` | `text` | Narrative/source notes in owning table. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.stat_pak_results`

Stat-Pak result lookup.

| Column | Type | Description / caveat |
|---|---|---|
| `result_code` | `text` | Result or status; assay/source code meanings must be verified. |
| `result_label` | `text` | Result or status; assay/source code meanings must be verified. |
| `display_order` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `research.stat_pak_tests`

Stat-Pak tests.

| Column | Type | Description / caveat |
|---|---|---|
| `stat_pak_test_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `test_result` | `text` | Recorded assay result; original coding context is assay-specific. |
| `comments` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |
| `stat_pak_id` | `text` | Internal primary/foreign key; consult table links. |

### `research.supergroups`

Supergroup lookup.

| Column | Type | Description / caveat |
|---|---|---|
| `supergroup_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `supergroup_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `notes` | `text` | Narrative/source notes in owning table. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `research.wounds`

Potentially multiple wound observations per capture.

| Column | Type | Description / caveat |
|---|---|---|
| `wound_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `wound_area` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wound_amount` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wound_age` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wound_size` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wound_type` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `notes` | `text` | Narrative/source notes in owning table. |
| `created_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

## Analysis views and complete column dictionary

The following inventories **all 24 live views** to avoid undocumented schema objects. Internal/helper views are not additional canonical data tables.

### `analysis.capture_diagnostic_summary_standardised` — Supporting/compatibility

Counts of test results per capture.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `diagnostic_test_count` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `positive_test_count` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `negative_test_count` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `uninterpretable_test_count` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `any_positive_test` | `boolean` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.capture_history` — Supporting/compatibility

Legacy joined capture history used by V1 chain.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `elect_tag` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `historical_names` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `n_historical_names` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sex` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `age_first_capture` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `year_first_capture` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `capture_year` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_quarter` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_occasion` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `moc` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `recorded_sett_name` | `text` | Original location/sett text from the source, preserved; may not be a sett. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `normalized_sett_name` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `recorded_social_group_name` | `text` | Original reported group name, preserved. |
| `recorded_social_group_id` | `bigint` | Matched canonical ID of recorded social group. |
| `normalized_social_group_name` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `recorded_supergroup_name` | `text` | Original reported supergroup text, preserved. |
| `capture_location_text` | `text` | Original location category or descriptive text, e.g. SETT or FIELD. |
| `os_ref` | `text` | Original recorded OS grid-reference text. |
| `location_cleaning_note` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `disease_status_id` | `integer` | Internal primary/foreign key; consult table links. |
| `disease_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `weight` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `body_length` | `numeric` | Measurement; units or assay calibration require verification. |
| `temperature` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `toothwear` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `neck_diameter` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `condition` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `reproductive_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `testes` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `eartags` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `retag` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `transmitter` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `tx_number` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `pm_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `pm_cause` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blood_sample_taken` | `boolean` | Measurement; units or assay calibration require verification. |
| `blood_taken_time` | `time without time zone` | Measurement; units or assay calibration require verification. |
| `red_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `green_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `purple_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `yellow_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `peach_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `hair_sample_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `fur_clip_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `whisker_sample_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `sampler` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blood_sampler` | `text` | Measurement; units or assay calibration require verification. |
| `recorder` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sampling_notes` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `health_monitoring` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ho_supervisor` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `severity_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `severity_initials` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `release_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `release_initials` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effects` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effect_sampler` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effect_comment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_action_taken` | `text` | Boolean indicator; NULL is not FALSE. |
| `collar_action_taker` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_checked_by` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_scratch_no` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_transmitter` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `best_tune` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_impact_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppm` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `comment` | `text` | Capture-level original comment. |

### `analysis.capture_history_v1` — Primary

Recommended combined capture-history representation (one record per capture).

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `elect_tag` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `historical_names` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `n_historical_names` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sex` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `age_first_capture` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `year_first_capture` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `capture_year` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_quarter` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_occasion` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `moc` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `recorded_sett_name` | `text` | Original location/sett text from the source, preserved; may not be a sett. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `normalized_sett_name` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `recorded_social_group_name` | `text` | Original reported group name, preserved. |
| `recorded_social_group_id` | `bigint` | Matched canonical ID of recorded social group. |
| `normalized_social_group_name` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `recorded_supergroup_name` | `text` | Original reported supergroup text, preserved. |
| `capture_location_text` | `text` | Original location category or descriptive text, e.g. SETT or FIELD. |
| `os_ref` | `text` | Original recorded OS grid-reference text. |
| `location_cleaning_note` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `disease_status_id` | `integer` | Internal primary/foreign key; consult table links. |
| `disease_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `weight` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `body_length` | `numeric` | Measurement; units or assay calibration require verification. |
| `temperature` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `toothwear` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `neck_diameter` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `condition` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `reproductive_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `testes` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `eartags` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `retag` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `transmitter` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `tx_number` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `pm_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `pm_cause` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blood_sample_taken` | `boolean` | Measurement; units or assay calibration require verification. |
| `blood_taken_time` | `time without time zone` | Measurement; units or assay calibration require verification. |
| `red_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `green_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `purple_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `yellow_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `peach_tube_volume` | `numeric` | Measurement; units or assay calibration require verification. |
| `hair_sample_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `fur_clip_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `whisker_sample_taken` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `sampler` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blood_sampler` | `text` | Measurement; units or assay calibration require verification. |
| `recorder` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sampling_notes` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `health_monitoring` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ho_supervisor` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `severity_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `severity_initials` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `release_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `release_initials` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effects` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effect_sampler` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `adverse_effect_comment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_action_taken` | `text` | Boolean indicator; NULL is not FALSE. |
| `collar_action_taker` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_checked_by` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_scratch_no` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_transmitter` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `best_tune` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `collar_impact_assessment` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppm` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `comment` | `text` | Capture-level original comment. |
| `sett_name` | `text` | Canonical named sett from the sett lookup. |
| `location_type` | `text` | Derived SETT/PM_GRID_REFERENCE/PM_LOCATION_UNRESOLVED/UNMATCHED_CAPTURE_LOCATION/NOT_RECORDED. |
| `location_easting` | `numeric` | BNG easting; PM grid values mark southwest corner of square, not actual sett. |
| `location_northing` | `numeric` | BNG northing; PM grid values mark southwest corner of square, not actual sett. |
| `location_crs` | `text` | Assigned coordinate reference system; original source needs verification. |
| `location_coordinate_basis` | `text` | Coordinate method/provenance (e.g. verified sett or provisional grid square). |
| `location_class` | `text` | Detailed interpretation of historical capture-location text. |

### `analysis.capture_infection_probabilities` — Supporting/compatibility

Wide comparison of models' event infection predictions.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `sample_date` | `date` | Date/period or provenance timestamp. |
| `year` | `smallint` | Date/period or provenance timestamp. |
| `quarter` | `smallint` | Date/period or provenance timestamp. |
| `model_run` | `text` | Model run name/version. |
| `diagnostic_fixed_prevalence` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `diagnostic_annual_prevalence` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `diagnostic_adjusted_annual` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `all_tests_fixed` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `all_tests_inferred` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `culture_only_fixed` | `double precision` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.capture_location_classified_v2` — Supporting/compatibility

Internal text/grid parser.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `original_recorded_sett_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `os_ref` | `text` | Original recorded OS grid-reference text. |
| `capture_location_text` | `text` | Original location category or descriptive text, e.g. SETT or FIELD. |
| `location_class` | `text` | Detailed interpretation of historical capture-location text. |
| `location_display_category` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `reference_source` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `so_grid_six_digits` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_sw_easting` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_sw_northing` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `accompanying_location_description` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `positional_precision_note` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.capture_location_classified_v3` — Supporting/compatibility

Internal ST/SO parser.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `original_recorded_sett_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `os_ref` | `text` | Original recorded OS grid-reference text. |
| `capture_location_text` | `text` | Original location category or descriptive text, e.g. SETT or FIELD. |
| `location_class` | `text` | Detailed interpretation of historical capture-location text. |
| `location_display_category` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `reference_source` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `so_grid_six_digits` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_sw_easting` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_sw_northing` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `accompanying_location_description` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `positional_precision_note` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `newly_parsed_grid_reference` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `newly_parsed_cell_width_m` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.capture_location_fields_v1` — Supporting/compatibility

Shared V1 location-field helper.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `sett_name` | `text` | Canonical named sett from the sett lookup. |
| `location_type` | `text` | Derived SETT/PM_GRID_REFERENCE/PM_LOCATION_UNRESOLVED/UNMATCHED_CAPTURE_LOCATION/NOT_RECORDED. |
| `location_easting` | `numeric` | BNG easting; PM grid values mark southwest corner of square, not actual sett. |
| `location_northing` | `numeric` | BNG northing; PM grid values mark southwest corner of square, not actual sett. |
| `location_crs` | `text` | Assigned coordinate reference system; original source needs verification. |
| `location_coordinate_basis` | `text` | Coordinate method/provenance (e.g. verified sett or provisional grid square). |
| `location_class` | `text` | Detailed interpretation of historical capture-location text. |

### `analysis.capture_location_v1` — Primary

Location semantics distinguishing named setts from recovered grid positions.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `original_recorded_sett_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `canonical_sett_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `location_class` | `text` | Detailed interpretation of historical capture-location text. |
| `location_display_category` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_location_text` | `text` | Original location category or descriptive text, e.g. SETT or FIELD. |
| `os_ref` | `text` | Original recorded OS grid-reference text. |
| `reference_source` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `so_grid_six_digits` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `newly_parsed_grid_reference` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_sw_easting` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_sw_northing` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `newly_parsed_cell_width_m` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `accompanying_location_description` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `positional_precision_note` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `spatial_interpretation` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.capture_pm_grid_reference_review` — Supporting/compatibility

Internal numeric grid parsing.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `recorded_sett_name` | `text` | Original location/sett text from the source, preserved; may not be a sett. |
| `capture_location_text` | `text` | Original location category or descriptive text, e.g. SETT or FIELD. |
| `os_ref` | `text` | Original recorded OS grid-reference text. |
| `so_six_digits` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_reference_source` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_cell_easting` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_cell_northing` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `grid_cell_width_m` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `inferred_crs` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `review_status` | `text` | Result or status; assay/source code meanings must be verified. |

### `analysis.capture_sett_coordinate_inventory` — Supporting/compatibility

Internal sett coordinate/count derivation.

| Column | Type | Description / caveat |
|---|---|---|
| `sett_name` | `text` | Canonical named sett from the sett lookup. |
| `n_captures` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `n_pm_records` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `first_capture_date` | `date` | Date/period or provenance timestamp. |
| `last_capture_date` | `date` | Date/period or provenance timestamp. |
| `easting` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `northing` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_system` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `accuracy_m` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_source` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_status` | `text` | Result or status; assay/source code meanings must be verified. |

### `analysis.capture_traits_standardised` — Supporting/compatibility

Legacy standardized capture traits feeding V1.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `capture_year` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_quarter` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `recorded_sett_name` | `text` | Original location/sett text from the source, preserved; may not be a sett. |
| `recorded_social_group_id` | `bigint` | Matched canonical ID of recorded social group. |
| `recorded_social_group_name` | `text` | Original reported group name, preserved. |
| `sex_recorded` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sex_standardised` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `sex_missing` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `age_first_capture_recorded` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `age_first_capture_standardised` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `year_first_capture` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `years_since_first_capture` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `approximate_age_if_first_captured_as_cub` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.capture_traits_v1` — Supporting/compatibility

Capture sex/age derivations with standardized V1 locations.

| Column | Type | Description / caveat |
|---|---|---|
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `capture_year` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_quarter` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `recorded_sett_name` | `text` | Original location/sett text from the source, preserved; may not be a sett. |
| `recorded_social_group_id` | `bigint` | Matched canonical ID of recorded social group. |
| `recorded_social_group_name` | `text` | Original reported group name, preserved. |
| `sex_recorded` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sex_standardised` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `sex_missing` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `age_first_capture_recorded` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `age_first_capture_standardised` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `year_first_capture` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `years_since_first_capture` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `approximate_age_if_first_captured_as_cub` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sett_name` | `text` | Canonical named sett from the sett lookup. |
| `location_type` | `text` | Derived SETT/PM_GRID_REFERENCE/PM_LOCATION_UNRESOLVED/UNMATCHED_CAPTURE_LOCATION/NOT_RECORDED. |
| `location_easting` | `numeric` | BNG easting; PM grid values mark southwest corner of square, not actual sett. |
| `location_northing` | `numeric` | BNG northing; PM grid values mark southwest corner of square, not actual sett. |
| `location_crs` | `text` | Assigned coordinate reference system; original source needs verification. |
| `location_coordinate_basis` | `text` | Coordinate method/provenance (e.g. verified sett or provisional grid square). |
| `location_class` | `text` | Detailed interpretation of historical capture-location text. |

### `analysis.culture_results_standardised` — Supporting/compatibility

Interpreted culture outcomes.

| Column | Type | Description / caveat |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `culture_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `sample_type_recorded` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sample_group` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `culture_result_recorded` | `text` | Result or status; assay/source code meanings must be verified. |
| `culture_result_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `is_m_bovis_detected` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `afno` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `spoligo` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `spolprime` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wgs_clade` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.diagnostic_interpretation_standardised` — Supporting/compatibility

Test interpretations in common outcome groups.

| Column | Type | Description / caveat |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `test_family` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_record_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `recorded_result` | `text` | Original source value; do not mistake for a derived clean field. |
| `interpreted_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `test_positive` | `boolean` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.diagnostic_results` — Primary

Combined individual assay observations.

| Column | Type | Description / caveat |
|---|---|---|
| `source_table` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_record_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `is_pm` | `boolean` | TRUE indicates PM event; FALSE live capture. |
| `test_family` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `test_type` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sample_type` | `text` | Recorded diagnostic specimen category. |
| `result` | `text` | Result or status; assay/source code meanings must be verified. |
| `result_code` | `text` | Result or status; assay/source code meanings must be verified. |
| `visual_line_1` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `visual_line_1_result` | `text` | Result or status; assay/source code meanings must be verified. |
| `optical_density_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `visual_line_2` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `visual_line_2_result` | `text` | Result or status; assay/source code meanings must be verified. |
| `optical_density_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `reference_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `mean_od` | `numeric` | Measurement; units or assay calibration require verification. |
| `blot_cf` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blotson` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `brock_test_od` | `numeric` | Measurement; units or assay calibration require verification. |
| `no_clotted` | `boolean` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `afno` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `lesions` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `abscesses` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `spoligo` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `spolprime` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `wgs_clade` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `plate_number` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `experiment_date` | `timestamp without time zone` | Date/period or provenance timestamp. |
| `nil_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `avian_ppd_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `bovine_ppd_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `pwm_value` | `numeric` | Measurement; units or assay calibration require verification. |
| `bovine_minus_nil` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `avian_minus_nil` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `bovine_minus_avian` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `pwm_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `pwm_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppd_a_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppd_a_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppd_b_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `ppd_b_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `nil_1` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `nil_2` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `retest` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `test_failed` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `test_info` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `blood_quality` | `text` | Measurement; units or assay calibration require verification. |
| `qc_note` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `comments` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.individual_traits_standardised` — Supporting/compatibility

Individual-level standardized sex and first-capture age.

| Column | Type | Description / caveat |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier. |
| `elect_tag` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `age_first_capture_recorded` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `age_first_capture_standardised` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `age_first_capture_missing` | `boolean` | Boolean indicator; NULL is not FALSE. |
| `year_first_capture` | `integer` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sex_recorded` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `sex_standardised` | `text` | Derived standardization; exact rule recorded in audit/SQL. |
| `sex_missing` | `boolean` | Boolean indicator; NULL is not FALSE. |

### `analysis.infection_probabilities` — Primary

Infection probability model outputs, long format.

| Column | Type | Description / caveat |
|---|---|---|
| `infection_probability_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `sample_date` | `date` | Date/period or provenance timestamp. |
| `year` | `smallint` | Date/period or provenance timestamp. |
| `quarter` | `smallint` | Date/period or provenance timestamp. |
| `model_variant` | `text` | Identity of probability model variant; essential to comparing estimates. |
| `infection_probability` | `double precision` | Estimated probability from model; not measured infection result. |
| `model_run` | `text` | Model run name/version. |
| `source_file` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `imported_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `analysis.infection_quarterly_probabilities` — Primary

Modelled infection probability at quarter level.

| Column | Type | Description / caveat |
|---|---|---|
| `infection_quarterly_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `tattoo` | `text` | Scientific badger identifier. |
| `quarter_date` | `date` | Date/period or provenance timestamp. |
| `year` | `smallint` | Date/period or provenance timestamp. |
| `quarter` | `smallint` | Date/period or provenance timestamp. |
| `model_variant` | `text` | Identity of probability model variant; essential to comparing estimates. |
| `infection_probability` | `double precision` | Estimated probability from model; not measured infection result. |
| `model_run` | `text` | Model run name/version. |
| `source_file` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `imported_at` | `timestamp with time zone` | Date/period or provenance timestamp. |

### `analysis.sett_coordinate_source_name_review` — Supporting/compatibility

Internal coordinate source naming reconciliation.

| Column | Type | Description / caveat |
|---|---|---|
| `source_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_display_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `easting` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `northing` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `matched_canonical_sett` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `match_status` | `text` | Result or status; assay/source code meanings must be verified. |

### `analysis.sett_coordinate_unmatched_v1` — Supporting/compatibility

Unresolved source-coordinate names.

| Column | Type | Description / caveat |
|---|---|---|
| `source_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_display_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `easting` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `northing` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `match_status` | `text` | Result or status; assay/source code meanings must be verified. |

### `analysis.sett_coordinates_approved` — Supporting/compatibility

Approved coordinate points.

| Column | Type | Description / caveat |
|---|---|---|
| `sett_name` | `text` | Canonical named sett from the sett lookup. |
| `easting` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `northing` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_system` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `accuracy_m` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `source_reference` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `observed_on` | `date` | Recorded/derived field; exact units or historical codes need source codebook verification. |

### `analysis.sett_inventory_v1` — Primary

Canonical sett list with mapped coordinate evidence and capture counts.

| Column | Type | Description / caveat |
|---|---|---|
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `canonical_sett_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `capture_count` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `n_pm_records` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `first_capture_date` | `date` | Date/period or provenance timestamp. |
| `last_capture_date` | `date` | Date/period or provenance timestamp. |
| `easting` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `northing` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_system` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `accuracy_m` | `numeric` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_source` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `coordinate_status` | `text` | Result or status; assay/source code meanings must be verified. |

### `analysis.sett_social_group_observed` — Supporting/compatibility

Observed sett–SG pairs per year (not verified residence).

| Column | Type | Description / caveat |
|---|---|---|
| `sett_id` | `bigint` | Canonical confirmed sett reference; NULL if unresolved. |
| `sett_name` | `text` | Canonical named sett from the sett lookup. |
| `social_group_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `social_group_name` | `text` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `year` | `integer` | Date/period or provenance timestamp. |
| `n_captures` | `bigint` | Recorded/derived field; exact units or historical codes need source codebook verification. |
| `first_capture_date` | `date` | Date/period or provenance timestamp. |
| `last_capture_date` | `date` | Date/period or provenance timestamp. |

### `analysis.stat_pak_results_standardised` — Supporting/compatibility

Interpreted Stat-Pak outcomes.

| Column | Type | Description / caveat |
|---|---|---|
| `tattoo` | `text` | Scientific badger identifier. |
| `capture_id` | `bigint` | Stable capture/PM event identifier (one row per capture in captures). |
| `stat_pak_test_id` | `bigint` | Internal primary/foreign key; consult table links. |
| `capture_date` | `date` | Date of encounter, including PM when applicable. |
| `original_result_code` | `text` | Result or status; assay/source code meanings must be verified. |
| `original_result_text` | `text` | Result or status; assay/source code meanings must be verified. |
| `result_status` | `text` | Result or status; assay/source code meanings must be verified. |
| `test_positive` | `boolean` | Recorded/derived field; exact units or historical codes need source codebook verification. |

## V1 caveats before coauthor release

1. Actual authenticated coauthor connection and effective view privilege test is not completed.
2. A full value-by-value comparison of the consolidated research capture table with the original Access import, including source coding and units, is still needed. Sampled crosschecks of the previously split tables were consistent.
3. Historical ST/SO PM grid interpretation, unresolved named setts, and species movement/residency proxies remain flagged.
4. The 24 analysis SQL objects include internal dependencies; further removal requires rewriting the V1 dependency chain. Their presence does not mean coauthors must work with all 24.

**Reproducibility:** transformations are tracked in [V1 Cleaning Audit](V1_CLEANING_AUDIT.md) and the `sql/migrations/` directory. Do not delete original Access imports or migration history.
