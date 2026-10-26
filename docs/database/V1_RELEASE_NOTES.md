# Woodchester badger database — V1 release notes

I've kept the V1 database close to the original Access structure. The original values are retained, and where a field needed cleaning I've added a separate `_clean` field. There are **19 research tables** and **five analysis views**. The original Access imports remain available in `access_raw`; technical source files and imports are in `ingest`. The older views needed to reproduce development code remain outside the release interface in `internal_v1`.

The detailed rules, code definitions and changes I've made are in [V1 Cleaning Audit](V1_CLEANING_AUDIT.md).

## Research tables

| Table | What it contains |
|---|---|
| `brock_tests` | Brock assay records. |
| `captures` | One row per live capture or PM record. Sampling, collar and assessments are included. |
| `cultures` | Culture tests and related typing information. |
| `disease_statuses` | Original disease status codes used by captures. |
| `dpp_tests` | DPP tests and visual lines. |
| `elisa_tests` | ELISA diagnostic results. |
| `ifn_gamma_elisa` | IFN-gamma assay records and replicate readings. |
| `individual_names` | Original historical aliases; some animals have more than one. |
| `individuals` | One badger per row, identified by tattoo. |
| `infection_probabilities` | Additional model-derived infection probabilities. |
| `infection_quarterly_probabilities` | Additional model-derived quarterly infection probabilities. |
| `sett_location_evidence` | Location evidence, coordinates and their sources. |
| `sett_social_group_history` | Recorded sett/group links over time; more than one link can exist. |
| `setts` | Canonical sett names. |
| `social_group_supergroup_history` | Group/supergroup links over time. |
| `social_groups` | Canonical social group names. |
| `stat_pak_tests` | Stat-Pak tests. |
| `supergroups` | Canonical supergroup names. |
| `wounds` | Wounds recorded at captures; multiple rows can belong to one capture. |

## Analysis views

| View | What it provides |
|---|---|
| `capture_history_v1` | Joined capture histories; one row per event. |
| `capture_infection_probabilities` | Comparison of model-derived infection probabilities at captures. |
| `capture_location_v1` | Recorded and interpreted capture locations, distinguishing true setts from PM grid squares. |
| `diagnostic_results` | All tests in one long-format output. |
| `sett_inventory_v1` | Sett coordinates and capture counts. |

## Column guide

The following is the full list of currently released columns. I've described each as far as the original information supports. I haven't assigned units or meanings to uncertain historical codes without evidence; those require the original Access field definitions.

### `analysis.capture_history_v1`

Joined capture histories; one row per event.

| Column | Meaning |
|---|---|
| `capture_id` | Unique capture or PM event identifier. |
| `tattoo` | Scientific badger identifier. |
| `elect_tag` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `historical_names` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `n_historical_names` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `sex` | Original recorded sex. |
| `age_first_capture` | Original recorded age class at first capture. |
| `year_first_capture` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `capture_date` | Date of the capture/PM encounter. |
| `capture_year` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `capture_quarter` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `capture_occasion` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `is_pm` | Whether the event is a post-mortem record. |
| `moc` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `recorded_sett_name` | Original recorded location/sett wording; may not describe a sett. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `normalized_sett_name` | Derived/cleaned value; exact rule in the audit. |
| `recorded_social_group_name` | Original recorded social group wording. |
| `recorded_social_group_id` | Canonical identifier matching recorded social group. |
| `normalized_social_group_name` | Derived/cleaned value; exact rule in the audit. |
| `recorded_supergroup_name` | Original recorded supergroup text. |
| `capture_location_text` | Original location description/category. |
| `os_ref` | Original OS reference. |
| `location_cleaning_note` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `disease_status_id` | Record or lookup ID used for joins. |
| `disease_status` | Recorded or interpreted result/status; see source test rules. |
| `weight` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `body_length` | Measured value; original protocol determines units and coding. |
| `temperature` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `toothwear` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `neck_diameter` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `condition` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `reproductive_status` | Recorded or interpreted result/status; see source test rules. |
| `testes` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `eartags` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `retag` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `transmitter` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `tx_number` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `pm_status` | Recorded or interpreted result/status; see source test rules. |
| `pm_cause` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `blood_sample_taken` | Measured value; original protocol determines units and coding. |
| `blood_taken_time` | Measured value; original protocol determines units and coding. |
| `red_tube_volume` | Measured value; original protocol determines units and coding. |
| `green_tube_volume` | Measured value; original protocol determines units and coding. |
| `purple_tube_volume` | Measured value; original protocol determines units and coding. |
| `yellow_tube_volume` | Measured value; original protocol determines units and coding. |
| `peach_tube_volume` | Measured value; original protocol determines units and coding. |
| `hair_sample_taken` | Boolean flag. |
| `fur_clip_taken` | Boolean flag. |
| `whisker_sample_taken` | Boolean flag. |
| `sampler` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `blood_sampler` | Measured value; original protocol determines units and coding. |
| `recorder` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `sampling_notes` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `health_monitoring` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ho_supervisor` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `severity_assessment` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `severity_initials` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `release_assessment` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `release_initials` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `adverse_effects` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `adverse_effect_sampler` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `adverse_effect_comment` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_action_taken` | Boolean flag. |
| `collar_action_taker` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_checked_by` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_scratch_no` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_transmitter` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `best_tune` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_impact_assessment` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppm` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `comment` | Recorded capture comment. |
| `sett_name` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `location_type` | Derived distinction between sett, PM grid recovery and unresolved location. |
| `location_easting` | OS easting; may be the southwest grid-square corner of a PM reference. |
| `location_northing` | OS northing; may be the southwest grid-square corner of a PM reference. |
| `location_crs` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `location_coordinate_basis` | Provenance/type of coordinate. |
| `location_class` | More detailed location classification. |
### `analysis.capture_infection_probabilities`

Comparison of model-derived infection probabilities at captures.

| Column | Meaning |
|---|---|
| `capture_id` | Unique capture or PM event identifier. |
| `tattoo` | Scientific badger identifier. |
| `sample_date` | Date, quarter, year or provenance timestamp. |
| `year` | Date, quarter, year or provenance timestamp. |
| `quarter` | Date, quarter, year or provenance timestamp. |
| `model_run` | Identifies the model run. |
| `diagnostic_fixed_prevalence` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `diagnostic_annual_prevalence` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `diagnostic_adjusted_annual` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `all_tests_fixed` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `all_tests_inferred` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `culture_only_fixed` | Original recorded or derived field; see original Access definition for exact codes/units. |
### `analysis.capture_location_v1`

Recorded and interpreted capture locations, distinguishing true setts from PM grid squares.

| Column | Meaning |
|---|---|
| `capture_id` | Unique capture or PM event identifier. |
| `tattoo` | Scientific badger identifier. |
| `capture_date` | Date of the capture/PM encounter. |
| `is_pm` | Whether the event is a post-mortem record. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `original_recorded_sett_name` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `canonical_sett_name` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `location_class` | More detailed location classification. |
| `location_display_category` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `capture_location_text` | Original location description/category. |
| `os_ref` | Original OS reference. |
| `reference_source` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `so_grid_six_digits` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `newly_parsed_grid_reference` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `grid_sw_easting` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `grid_sw_northing` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `newly_parsed_cell_width_m` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `accompanying_location_description` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `positional_precision_note` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `spatial_interpretation` | Original recorded or derived field; see original Access definition for exact codes/units. |
### `analysis.diagnostic_results`

All tests in one long-format output.

| Column | Meaning |
|---|---|
| `source_table` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `source_record_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `tattoo` | Scientific badger identifier. |
| `capture_date` | Date of the capture/PM encounter. |
| `is_pm` | Whether the event is a post-mortem record. |
| `test_family` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `test_type` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `sample_type` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `result` | Recorded or interpreted result/status; see source test rules. |
| `result_code` | Recorded or interpreted result/status; see source test rules. |
| `visual_line_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `visual_line_1_result` | Recorded or interpreted result/status; see source test rules. |
| `optical_density_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `visual_line_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `visual_line_2_result` | Recorded or interpreted result/status; see source test rules. |
| `optical_density_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `reference_value` | Measured value; original protocol determines units and coding. |
| `mean_od` | Measured value; original protocol determines units and coding. |
| `blot_cf` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `blotson` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `brock_test_od` | Measured value; original protocol determines units and coding. |
| `no_clotted` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `afno` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `lesions` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `abscesses` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `spoligo` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `spolprime` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wgs_clade` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `plate_number` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `experiment_date` | Date, quarter, year or provenance timestamp. |
| `nil_value` | Measured value; original protocol determines units and coding. |
| `avian_ppd_value` | Measured value; original protocol determines units and coding. |
| `bovine_ppd_value` | Measured value; original protocol determines units and coding. |
| `pwm_value` | Measured value; original protocol determines units and coding. |
| `bovine_minus_nil` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `avian_minus_nil` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `bovine_minus_avian` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `pwm_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `pwm_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppd_a_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppd_a_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppd_b_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppd_b_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `nil_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `nil_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `retest` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `test_failed` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `test_info` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `blood_quality` | Measured value; original protocol determines units and coding. |
| `qc_note` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `comments` | Original recorded or derived field; see original Access definition for exact codes/units. |
### `analysis.sett_inventory_v1`

Sett coordinates and capture counts.

| Column | Meaning |
|---|---|
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `canonical_sett_name` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `capture_count` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `n_pm_records` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `first_capture_date` | Date, quarter, year or provenance timestamp. |
| `last_capture_date` | Date, quarter, year or provenance timestamp. |
| `easting` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `northing` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `coordinate_system` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `accuracy_m` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `coordinate_source` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `coordinate_status` | Recorded or interpreted result/status; see source test rules. |
### `research.brock_tests`

Brock assay records.

| Column | Meaning |
|---|---|
| `brock_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `brock_test_od` | Measured value; original protocol determines units and coding. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `no_clotted` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `comments` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `created_at` | Database row creation timestamp. |
### `research.captures`

One row per live capture or PM record. Sampling, collar and assessments are included.

| Column | Meaning |
|---|---|
| `capture_id` | Unique capture or PM event identifier. |
| `individual_id` | Internal key used to join badger records. |
| `capture_date` | Date of the capture/PM encounter. |
| `is_pm` | Whether the event is a post-mortem record. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `recorded_social_group_id` | Canonical identifier matching recorded social group. |
| `recorded_sett_name` | Original recorded location/sett wording; may not describe a sett. |
| `recorded_social_group_name` | Original recorded social group wording. |
| `recorded_supergroup_name` | Original recorded supergroup text. |
| `moc` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `capture_location_text` | Original location description/category. |
| `weight` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `body_length` | Measured value; original protocol determines units and coding. |
| `temperature` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `toothwear` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `neck_diameter` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `condition` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `reproductive_status` | Recorded or interpreted result/status; see source test rules. |
| `testes` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `eartags` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `retag` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `transmitter` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `tx_number` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `pm_status` | Recorded or interpreted result/status; see source test rules. |
| `pm_cause` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `comment` | Recorded capture comment. |
| `created_at` | Database row creation timestamp. |
| `location_cleaning_note` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `disease_status_id` | Record or lookup ID used for joins. |
| `os_ref` | Original OS reference. |
| `sett_name_clean` | Confirmed sett name from sett_id; NULL for unidentified setts. |
| `social_group_name_clean` | Standardised label for the recorded group; not a residence assignment. |
| `sampler` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `recorder` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `blood_taken_time` | Measured value; original protocol determines units and coding. |
| `red_tube_volume` | Measured value; original protocol determines units and coding. |
| `green_tube_volume` | Measured value; original protocol determines units and coding. |
| `purple_tube_volume` | Measured value; original protocol determines units and coding. |
| `peach_tube_volume` | Measured value; original protocol determines units and coding. |
| `hair_sample_taken` | Boolean flag. |
| `fur_clip_taken` | Boolean flag. |
| `whisker_sample_taken` | Boolean flag. |
| `sampling_notes` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `blood_sampler` | Measured value; original protocol determines units and coding. |
| `yellow_tube_volume` | Measured value; original protocol determines units and coding. |
| `blood_sample_taken` | Measured value; original protocol determines units and coding. |
| `health_monitoring` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ho_supervisor` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `severity_assessment` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `severity_initials` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `release_assessment` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `release_initials` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `adverse_effects` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `adverse_effect_sampler` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `adverse_effect_comment` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_action_taken` | Boolean flag. |
| `collar_action_taker` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_checked_by` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_scratch_no` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_transmitter` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `best_tune` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `collar_impact_assessment` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppm` | Original recorded or derived field; see original Access definition for exact codes/units. |
### `research.cultures`

Culture tests and related typing information.

| Column | Meaning |
|---|---|
| `culture_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `sample_type` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `afno` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `culture_result` | Recorded or interpreted result/status; see source test rules. |
| `lesions` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `abscesses` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `spoligo` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `spolprime` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wgs_clade` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `sampler_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `sampler_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `comments` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `created_at` | Database row creation timestamp. |
### `research.disease_statuses`

Original disease status codes used by captures.

| Column | Meaning |
|---|---|
| `disease_status_id` | Record or lookup ID used for joins. |
| `disease_status` | Recorded or interpreted result/status; see source test rules. |
### `research.dpp_tests`

DPP tests and visual lines.

| Column | Meaning |
|---|---|
| `dpp_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `comments` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `created_at` | Database row creation timestamp. |
| `test_type` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `sample_type` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `visual_line_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `optical_density_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `visual_line_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `optical_density_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `source_raw_row_id` | Record or lookup ID used for joins. |
| `visual_line_1_result` | Recorded or interpreted result/status; see source test rules. |
| `visual_line_2_result` | Recorded or interpreted result/status; see source test rules. |
### `research.elisa_tests`

ELISA diagnostic results.

| Column | Meaning |
|---|---|
| `elisa_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `elisa_type` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `reference` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `mean_od` | Measured value; original protocol determines units and coding. |
| `blot_cf` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `blotson` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `comments` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `created_at` | Database row creation timestamp. |
### `research.ifn_gamma_elisa`

IFN-gamma assay records and replicate readings.

| Column | Meaning |
|---|---|
| `ifn_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `plate_number` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `experiment_date` | Date, quarter, year or provenance timestamp. |
| `import_filename` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `imported_at` | Date/time data were imported. |
| `blood_quality` | Measured value; original protocol determines units and coding. |
| `nil_value` | Measured value; original protocol determines units and coding. |
| `avian_ppd_value` | Measured value; original protocol determines units and coding. |
| `bovine_ppd_value` | Measured value; original protocol determines units and coding. |
| `pwm_value` | Measured value; original protocol determines units and coding. |
| `bovine_minus_nil` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `avian_minus_nil` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `bovine_minus_avian` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `test_info` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `comments` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `created_at` | Database row creation timestamp. |
| `pwm_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `pwm_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppd_a_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppd_a_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppd_b_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `ppd_b_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `nil_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `nil_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `retest` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `test_failed` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `capture_datetime` | Date, quarter, year or provenance timestamp. |
| `wellstage_96_pwm_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wellstage_96_pwm_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wellstage_96_ppda_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wellstage_96_ppda_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wellstage_96_ppdb_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wellstage_96_ppdb_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wellstage_96_nil_1` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wellstage_96_nil_2` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `qc_note` | Original recorded or derived field; see original Access definition for exact codes/units. |
### `research.individual_names`

Original historical aliases; some animals have more than one.

| Column | Meaning |
|---|---|
| `individual_name_id` | Record or lookup ID used for joins. |
| `individual_id` | Internal key used to join badger records. |
| `name` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.individuals`

One badger per row, identified by tattoo.

| Column | Meaning |
|---|---|
| `individual_id` | Internal key used to join badger records. |
| `tattoo` | Scientific badger identifier. |
| `elect_tag` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `age_first_capture` | Original recorded age class at first capture. |
| `year_first_capture` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `sex` | Original recorded sex. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
| `sex_clean` | Standardised MALE, FEMALE, or UNKNOWN; original sex kept. |
| `age_first_capture_clean` | Standardised CUB, YEARLING, ADULT or UNKNOWN. |
### `research.infection_probabilities`

Additional model-derived infection probabilities.

| Column | Meaning |
|---|---|
| `infection_probability_id` | Record or lookup ID used for joins. |
| `individual_id` | Internal key used to join badger records. |
| `capture_id` | Unique capture or PM event identifier. |
| `sample_date` | Date, quarter, year or provenance timestamp. |
| `year` | Date, quarter, year or provenance timestamp. |
| `quarter` | Date, quarter, year or provenance timestamp. |
| `model_variant` | Identifies the model variant. |
| `infection_probability` | Model-based probability, not an observed test outcome. |
| `model_run` | Identifies the model run. |
| `source_file` | Source data file used for model-derived results. |
| `imported_at` | Date/time data were imported. |
### `research.infection_quarterly_probabilities`

Additional model-derived quarterly infection probabilities.

| Column | Meaning |
|---|---|
| `infection_quarterly_id` | Record or lookup ID used for joins. |
| `individual_id` | Internal key used to join badger records. |
| `quarter_date` | Date, quarter, year or provenance timestamp. |
| `year` | Date, quarter, year or provenance timestamp. |
| `quarter` | Date, quarter, year or provenance timestamp. |
| `model_variant` | Identifies the model variant. |
| `infection_probability` | Model-based probability, not an observed test outcome. |
| `model_run` | Identifies the model run. |
| `source_file` | Source data file used for model-derived results. |
| `imported_at` | Date/time data were imported. |
### `research.sett_location_evidence`

Location evidence, coordinates and their sources.

| Column | Meaning |
|---|---|
| `evidence_id` | Record or lookup ID used for joins. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `easting` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `northing` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `coordinate_system` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `accuracy_m` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `evidence_type` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `source_reference` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `observed_on` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `recorded_by` | Original recorded value, preserved. |
| `review_status` | Recorded or interpreted result/status; see source test rules. |
| `reviewed_by` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `reviewed_at` | Date, quarter, year or provenance timestamp. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.sett_social_group_history`

Recorded sett/group links over time; more than one link can exist.

| Column | Meaning |
|---|---|
| `sett_social_group_id` | Record or lookup ID used for joins. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `social_group_id` | Record or lookup ID used for joins. |
| `valid_from` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `valid_to` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `notes` | Historical notes or provenance in the context of this table. |
### `research.setts`

Canonical sett names.

| Column | Meaning |
|---|---|
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `sett_name` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.social_group_supergroup_history`

Group/supergroup links over time.

| Column | Meaning |
|---|---|
| `social_group_supergroup_id` | Record or lookup ID used for joins. |
| `social_group_id` | Record or lookup ID used for joins. |
| `supergroup_id` | Record or lookup ID used for joins. |
| `valid_from` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `valid_to` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `notes` | Historical notes or provenance in the context of this table. |
### `research.social_groups`

Canonical social group names.

| Column | Meaning |
|---|---|
| `social_group_id` | Record or lookup ID used for joins. |
| `social_group_name` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.stat_pak_tests`

Stat-Pak tests.

| Column | Meaning |
|---|---|
| `stat_pak_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `comments` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `created_at` | Database row creation timestamp. |
| `stat_pak_id` | Record or lookup ID used for joins. |
### `research.supergroups`

Canonical supergroup names.

| Column | Meaning |
|---|---|
| `supergroup_id` | Record or lookup ID used for joins. |
| `supergroup_name` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.wounds`

Wounds recorded at captures; multiple rows can belong to one capture.

| Column | Meaning |
|---|---|
| `wound_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `wound_area` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wound_amount` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wound_age` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wound_size` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `wound_type` | Original recorded or derived field; see original Access definition for exact codes/units. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |

## Using these data

I use `tattoo` as the scientific individual identifier and `capture_id` for capture events. A canonical sett name is only filled when the recorded location has been matched to a sett. PM grid references are recovery-location approximations, not known sett locations. Recorded social groups shouldn't automatically be treated as annual residence assignments. Infection probabilities are model outputs rather than diagnostic observations.
