# Woodchester database — V1 release notes

**Status:** Preparing V1, 26 October 2026. This is the authoritative user-facing V1 release guide, replacing separate coauthor audit reports. Definitions not checked against the original Access documentation remain explicitly provisional.

## Design

| Schema | Meaning | Coauthor access |
|---|---|---|
| `access_raw` | 12 preserved original Access imports and provenance | Not shared by default |
| `research` | 28 relational, cleaned/source-preserving tables: badgers, captures, sampling, tests, setts, group relationships and spatial evidence | Read-only on 25 curated tables |
| `analysis` | 24 current views for joins, standardised traits/tests, locations and probabilities | Read-only |
| `ingest` | 4 technical importer / audit / baseline tables | Maintainers only |

Both custom coauthor roles (`badger_readonly` and `badger_research_readonly`) now have SELECT on the 25 curated research tables and all analysis views, without INSERT/UPDATE/DELETE permissions. Three research source/import tables stay outside coauthor access: `infection_probabilities_import`, `infection_quarterly_import`, and `sett_coordinate_source_20261023`. Actual account/login privileges, schema access and view security still need end-to-end testing.

**Recommended entry points**: `analysis.capture_history_v1` for one record per capture/PM event, `analysis.capture_traits_v1` for sex/age traits, `analysis.capture_location_v1` for spatial interpretations, `analysis.sett_inventory_v1` for sett coordinates, `analysis.diagnostic_results` for tests, and the cleaned base tables in `research` when detail is needed.

## Definitions and key joins

- `research.individuals`: scientific identity is `tattoo`; `individual_id` is an internal joining key.
- `research.captures`: `capture_id` uniquely identifies an event; `individual_id` links it to the badger. Source fields `recorded_sett_name`, `recorded_social_group_name`, `capture_location_text` and `os_ref` are preserved.
- `research.setts`: canonical identities and `sett_id`; never infer a sett from a road/field/PM recovery grid.
- `sett_name` (V1 views): canonical sett name or **NULL** when not established. `recorded_sett_name`: literal historical text, which can describe non-sett places.
- `location_type`: `SETT`, `PM_GRID_REFERENCE`, `PM_LOCATION_UNRESOLVED`, `UNMATCHED_CAPTURE_LOCATION`, or `NOT_RECORDED`. `location_class` is more specific.
- `location_easting`/`location_northing`: either a mapped canonical sett position or the **south-west corner of a provisionally decoded PM recovery grid square**; distinguish via `location_coordinate_basis`. This is not necessarily a measured recovery point.
- `research.capture_sampling`, `capture_assessments`, `capture_collars`, `wounds` and diagnostic tables join to `research.captures` by `capture_id`; verify multiplicity before combining.
- `research.sett_social_group_history` and `social_group_supergroup_history` are date-dependent. Recorded SG is not proof of inferred residence.
- `research.infection_probabilities` and `infection_quarterly_probabilities` store **model outputs**, distinguished by model variant and run, not observed test results.

## V1 baseline results

17,586 distinct capture/PM events. 16,337 have canonical setts; 710 have provisionally interpretable PM recovery grids but **no sett assigned**; 343 PM locations remain unresolved; 170 non-PM recorded locations unmatched; 26 locations not recorded. There are 176 canonical setts; 159 have linked coordinate evidence. Historical aliases such as TOP SETT/TOP and GULLY/GULLEY have already been reconciled in versioned cleaning logic without overwriting the recorded source.

## Current analysis views: their purpose

| View | Purpose | Release role |
|---|---|---|
| `capture_history_v1` | Capture history with shared V1 location columns | **Primary** |
| `capture_traits_v1` | Capture-level sex/age standardisations plus V1 location | **Primary** |
| `capture_location_v1` | Sett identity versus recovery grid and unresolved locations | **Primary** |
| `sett_inventory_v1` | Canonical sett coordinates, provenance and capture counts | **Primary** |
| `diagnostic_results` | All original diagnostic test records in a common structure | **Primary** |
| `individual_traits_standardised` | Individual-level sex and age standardisations | Useful |
| `capture_diagnostic_summary_standardised` | Capture-level diagnostic result counts and any-positive indicator | Useful |
| `culture_results_standardised` | Culture result interpretations | Useful |
| `diagnostic_interpretation_standardised` | Long-format interpreted diagnostic results | Useful |
| `stat_pak_results_standardised` | Standardised Stat-Pak results | Useful |
| `sett_social_group_observed` | Observed sett–SG by year, not residency | Useful |
| `sett_coordinates_approved` | Mapped named sett coordinates | Useful |
| `infection_probabilities` | Modelled infection probability by event | Useful |
| `infection_quarterly_probabilities` | Modelled infection probability by quarter | Useful |
| `capture_infection_probabilities` | Wide-format probability comparisons at capture | Useful |
| `capture_history` | Original joined capture view without V1 spatial fields | Legacy compatibility |
| `capture_traits_standardised` | Traits without V1 spatial fields | Legacy compatibility |
| `capture_location_fields_v1` | Shared classification fields inserted into V1 views | Internal helper |
| `capture_location_classified_v2` | Historical text with embedded PM grid parsing | Internal dependency |
| `capture_location_classified_v3` | ST/SO PM grid parsing | Internal dependency |
| `capture_pm_grid_reference_review` | Earlier numeric reference parsing logic | Internal dependency |
| `capture_sett_coordinate_inventory` | Sett capture totals and spatial lookup | Internal dependency |
| `sett_coordinate_source_name_review` | Match imported coordinate names to canonical names | Internal dependency |
| `sett_coordinate_unmatched_v1` | List of unresolved imported coordinate names | Deferred review |

**What could we remove?** The seven standalone audit views were already removed in October 2026. The six internal analysis helpers above cannot simply be deleted because V1 outputs still depend on them. They could be folded into fewer definitions after an explicit dependency and model-script test. The original Access, cleaned research tables, test detail, coordinate provenance and versioned SQL history should **not** be deleted. The legacy analysis capture views should also remain until all running code is migrated.

## Cleaned research tables and their purpose

| Table(s) | Record meaning |
|---|---|
| `individuals`, `individual_names` | Canonical badger and historical name aliases |
| `captures`, `capture_sampling`, `capture_assessments`, `capture_collars` | Capture event and associated sampling, health and collar records |
| `wounds` | Wound records linked to event |
| `setts`, `sett_location_evidence` | Canonical sett identity and coordinate evidence |
| `social_groups`, `supergroups`, `sett_social_group_history`, `social_group_supergroup_history` | Names and dated group relationships |
| `cultures`, `elisa_tests`, `ifn_gamma_elisa`, `stat_pak_tests`, `brock_tests`, `dpp_tests` | Separate assay records; preserve original test codes and detail |
| `disease_statuses`, `dpp_sample_types`, `dpp_visual_line_results`, `stat_pak_results` | Assay/status lookups |
| `infection_probabilities`, `infection_quarterly_probabilities` | Clearly-labelled model probability data |
| `infection_probabilities_import`, `infection_quarterly_import`, `sett_coordinate_source_20261023` | Internal import provenance, not curated coauthor tables |

## Data dictionary contract

For every V1 object, the database's actual column names and PostgreSQL data types are authoritative; the separately maintained `DATA_DICTIONARY.md` remains the working field glossary until all definitions and units can be verified directly against the source Access codebook. Columns that appear in multiple views retain their underlying meaning. Standardisation flags are distinct from original recorded values; test-result interpretation and age approximations are **derived**, never silently substituted for observations.

This release document is the only **release/audit narrative**. The dictionary and governance pages are reference appendices, not competing release-note versions. Their older exploratory audit sections must not be treated as current API guidance.

## Still pending before sharing externally

1. Source-to-research parity and full column units/code definitions need a verified Access codebook pass.
2. Test actual coauthor authentication, least privilege and ability to query both schemas without write access.
3. Spatial validation remains open: 16 coordinate-less named setts, nine unmatched coordinate-source names, historic ST/SO anomalies, 170 unmatched non-PM events and other PM descriptions.
4. Review scripts that may use legacy views before any future internal dependency refactor.
5. Annual SG territory centres, if used later, must be explicitly recorded as *imputed territorial proxy positions*, never as original capture locations or sett coordinates.

**Provenance:** All actual transformations remain reproducible using the original `access_raw` tables, source-backed columns, and versioned `sql/migrations/`. The existing baseline register retains label **V1**.


---

# Appendix A — Full existing V1 data dictionary

The following complete original field dictionary is incorporated into the V1 release document to avoid separate competing references. It remains subject to source Access metadata verification.

## Woodchester database field dictionary

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

For the current coauthor-facing structure and permission checks, see [`WOODCHESTER_V1_COAUTHOR_RELEASE_AUDIT_20261026.md`](WOODCHESTER_V1_COAUTHOR_RELEASE_AUDIT_20261026.md). Seven interim diagnostic/review views were retired on 26 October; the core V1 researcher-facing views, base research tables, raw Access tables and versioned SQL migration records were retained. The historical references to old review-view names elsewhere in this document record the original workflow, not live endpoints. The working baseline is still **V1**.
