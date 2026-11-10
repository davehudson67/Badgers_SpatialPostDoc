# Woodchester database — MASTER DATA DICTIONARY AND AUDIT

**Live schema snapshot:** 4 November 2026, after grid/identity audit (**57 tables/views; 949 columns**). **Scope:** all current `access_raw`, `research` and `analysis` relations, not guessed old tables. Describes **every live column**. **Database is authoritative**; this inventory must be regenerated after migrations.

## How to use these tables

| Layer | Intended use | Grain |
|---|---|---|
| `access_raw` | Preserve imported Access values: 12 imported tables; **not** all 62 objects in the original Access inventory | Original source table grain |
| `research` | Canonical linked source records and **audited decision tables** | Table-dependent (one animal, capture, wound, test, alias, etc.) |
| `analysis.encounters_clean_v1` | **Recommended spatial/encounter starting point**; one row per original capture/PM record | 17,586 rows, 13 columns, one `capture_id` each |
| `analysis.capture_history_v1` | Source-rich longitudinal capture history | One row per capture/PM record; avoid conflating PM with live capture |
| `analysis.diagnostic_results` | Pooled six diagnostic families | One row per assay/test outcome (possibly multiple per capture) |
| `analysis.mortality_events_review_v1` | One primary record per **recorded** death, excluding curated PM companion; identity/duplicate flags retained | 1,304 death-event rows, **400 without XY**; not yet signed-off survival endpoint |
| `analysis.wecs_review_flags_v1` | **Live flagged-inconsistency register** | One issue per flag ID; review status and final decision |

### Key scientific rules

- `tattoo` is the scientific individual identifier. `individual_id` is only an internal relational key. `UN` animals must not be assigned a social group simply from inferred sett location.
- `capture_id` identifies a **source row**. A field row and its PM row can describe **one** episode. Currently **17 linked two-row episodes**, including 024Y (16882 + 16817). Exclude PM companions when counting distinct episodes.
- A death with missing coordinates **remains a recorded death**. An RTA label alone is **not** a proven death without adequate outcome evidence. Later live captures after recorded deaths require tattoo/identity review.
- Associated-sett XY, grid-cell SW corners and actual field/recovery locations are not interchangeable. Read `location_quality` before using coordinates in a movement model.
- `NULL`/blank means unknown or not recorded, not negative, no movement, presumed alive or exact zero.

## Cleaned capture/PM schema (six standardised attributes + seven identifiers)

`analysis.encounters_clean_v1` retains `capture_id`, `tattoo`, `capture_date`, `is_pm`, `sett_id`, `episode_primary_capture_id` and `episode_record_role`. The **six cleaned fields** are `encounter_type`, `outcome`, `location_type`, `location_easting`, `location_northing`, `location_quality`. These six fields should remain compact. All explanations and overrides are separately in `research` audit tables.

### Exact current categorical entries (with live counts)
- **`encounter_type`:** TRAP:16093; RTA:750; FOUND_DEAD:271; SHOT:146; SNARE:140; REMOVAL:76; NET:43; FOUND_IN_EXTREMIS:31; PUT_DOWN:15; DEAD_SNARE_TRAP:9; UNKNOWN:6; FOUND_ALIVE:3; DART:1; ON_ROAD:1; PUBLIC_REPORT:1.
- **`outcome`:** PRESUMED_RELEASED:16263; FOUND_DEAD:1032; KILLED:223; EUTHANISED:44; DIED:22; RELEASED:1; UNKNOWN:1.
- **`episode_record_role`:** STANDALONE:17552; FIELD_RECORD:17; PM_COMPANION:17.
- **`location_quality`:** SETT_POINT_PROVISIONAL:15740; UNRESOLVED:834; GRID_CELL_100M_RECORDED_SO:366; GRID_CELL_100M_PREFIX_UNVERIFIED:187; SETT_ASSOCIATION_PROVISIONAL:190; SETT_COORDINATE_CONFLICT:107; GRID_CELL:65; GRID_REFERENCE_CORRECTED_PROVISIONAL:87; GRID_REFERENCE_AMBIGUOUS_WITHHELD:10; SETT_ASSOCIATION_ONLY:5.
- **`location_type`:** SETT:16044; ROAD:747; RECOVERY_SITE:238; UNKNOWN:222; SETT_ASSOCIATION:164; BOUNDARY:57; FIELD:49; WOOD:30; BUILDING:10; LINKED_FIELD_SITE:10; HEDGE:8; OTHER_CAPTURE_SITE:6; GARDEN:1.
- **`research.wecs_review_flags.review_status`:** OPEN; NEEDS_SOURCE_CHECK; WAITING_FIELD_TEAM; RESOLVED.

*Note:* these are observed values in the November 2026 baseline, not an exhaustive immutable set. The source `moc`, health assessment, lab test categories and other historical free-text categories vary by era. Do not assert closed enums for raw fields; inspect `SELECT DISTINCT ...` before modelling. Clinical assay interpretations are specific to test family; a blank/invalid test is **not a negative**.

## Observed source categories in the principal raw/canonical fields

These are **observed values**, not necessarily validated biological categories, and may change after data corrections. `NULL` is an absence of entry, **not** a negative result. Counts below come directly from current live Supabase tables.

| Table.column | Observed categories (count) | Interpretation |
|---|---|---|
| `research.individuals.sex` | FEMALE 1,982; MALE 1,772; UNKNOWN 17; NULL 20 | Keep unknown sex distinct from missing |
| `research.individuals.age_first_capture` | CUB 2,823; ADULT 769; YEARLING 85; NULL 114 | Recorded age **class at first capture**; not exact birth year |
| `research.captures.condition` | GOOD 8,809; FAIR 4,789; POOR 1,281; VERY GOOD 1,068; V.GOOD 700; NULL 939 | VERY GOOD and V.GOOD appear distinct in source; harmonise explicitly if used |
| `research.captures.pm_status` | POSSIBLE 474; NOT POSSIBLE 73; NULL 17,039 | Availability/PM-status text, not a death outcome by itself |
| `research.captures.release_assessment` | Fit 1,835; Death 4; NULL 15,747 | Fit supports routine release but does not itself prove release |
| `research.captures.moc` | TRAP 15,916; RTA 738; FOUND DEAD 267; NULL 206; SNARE 140; SHOT (GP) 120; REMOVAL 77; NET 43; FOUND EXT 31; SHOT 21; PUT DOWN 15; DEAD SN/TR 9; ON ROAD 1; REPORTED BY MEMBER OF THE PUBLIC 1; DART GUN 1 | Original recorded method/context. `FOUND EXT` means found in extremis. `RTA` alone is not necessarily fatal |
| `research.captures.reproductive_status` | NEVER LACTATING 4,484; LACTATING THIS YEAR 884; LACTATING SOMETIME 671; LACTATING 475; N LACT T Y 288; LACT P Y 216; NPTD 165; UNSURE 88; TESTES DESCENDED 75; PREGNANT 51; TESTES ASCENDED 14; MID 10; UNKNOWN 3; NULL 10,162 | Mixed sex-specific, historical and abbreviated codes; **do not** map ambiguous codes without source documentation |
| `research.cultures.culture_result` | NEGATIVE 46,400; M.BOVIS 1,058; M.AVIUM 2; M.OTHER 1; CONTAMINATED 2; FAILED 7; PENDING 6; NOT TESTED 5; NULL 1,218 | Only M.BOVIS is *M. bovis detected*; OTHER, failed, pending and untested are not negative |
| `research.disease_statuses.disease_status` | Negative; Exposed; Excretor; Super excretor | Lookup categories (one row per type), not observed test counts |
| `research.stat_pak_tests.test_result` | Negative 2,149; Positive 654; No Clotted Sample 48 | No clotted sample is invalid/not tested; **not negative** |
| `research.brock_tests.test_result` | N 1,082; P 514; NULL 52 | N/P assay interpretation; NULL is missing |
| `research.elisa_tests.test_result` | N 13,297; P 1,554; I 163; NO SERA 93; ITT 15; NO SERUM 6; BIT 2; NULL 32 | Unresolved abbreviations/insufficient serum need separate assay-level interpretation; don't collapse into negative |
| `research.ifn_gamma_elisa.test_result` | Negative 3,276; Positive 698; NULL 401 | Interpretation should additionally consider QC, controls and numerical thresholds |
| `research.dpp_tests.test_result` | NULL 3,316 | This source field is entirely blank; **DPP result must be reconstructed from visual-line and optical-density fields**, not interpreted as universally negative |

For diagnostic outcomes **prefer `analysis.diagnostic_results`**, which retains the source family and test provenance. Other historical text fields (including `condition`, `testes`, injuries, notes and named locations) are not assumed to be controlled enums. Where a category matters scientifically, add a separately reviewed rule rather than silently collapsing spelling variants.

## Live column-by-column inventory

Entries under every table below show **actual database type**, nullability and explanation. For fields without verified semantics or units in their source, this is explicitly stated; the SQL and original Access documentation remain necessary.

### `analysis.encounters_clean_v1` (13 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `episode_primary_capture_id` | `bigint` | Yes | Curated episode primary capture ID; null means no currently linked companion. |
| `episode_record_role` | `text` | Yes | STANDALONE; FIELD_RECORD; PM_COMPANION. |
| `encounter_type` | `text` | Yes | Observed or inferred encounter context; see exact categorical domain below. |
| `outcome` | `text` | Yes | Recorded or inferred encounter fate; see exact categorical domain below. |
| `location_type` | `text` | Yes | What coordinate/recorded site represents; see exact categorical domain below. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `location_quality` | `text` | Yes | Spatial location precision and provenance flag; see exact domain below. |

### `analysis.mortality_events_review_v1` (16 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `recorded_event_date` | `date` | Yes | Source record date; may not be exact date of death. |
| `mortality_outcome` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `encounter_type` | `text` | Yes | Observed or inferred encounter context; see exact categorical domain below. |
| `source_is_pm` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `original_moc` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `pm_cause` | `text` | Yes | Source post-mortem cause, often free text; do not infer precise mortality from blank. |
| `linked_pm_capture_id` | `bigint` | Yes | PM source row linked to primary encounter; null if none. |
| `linked_pm_date` | `date` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `location_quality` | `text` | Yes | Spatial location precision and provenance flag; see exact domain below. |
| `next_live_capture_date` | `date` | Yes | Earliest later explicit live capture; death identity conflict if nonnull. |
| `previous_death_record_date` | `date` | Yes | Previous recorded death for same current identity; possible duplicate. |
| `mortality_review_status` | `text` | Yes | Death evidence quality/identity warning; do not treat review flags as censoring. |

### `analysis.wecs_review_flags_v1` (11 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `flag_id` | `text` | Yes | Stable unique reference for a human-review issue. |
| `category` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `capture_ids` | `ARRAY` | Yes | All source capture IDs implicated by a review flag. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `summary` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `evidence` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `current_interpretation` | `text` | Yes | Provisional interpretation; not a final adjudication. |
| `review_status` | `text` | Yes | OPEN; NEEDS_SOURCE_CHECK; WAITING_FIELD_TEAM; RESOLVED. |
| `final_decision` | `text` | Yes | Authoritative resolution; must be populated when review_status=RESOLVED. |
| `final_decision_at` | `timestamp with time zone` | Yes | Time final decision was recorded; nullable until resolved. |
| `updated_at` | `timestamp with time zone` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |

### `analysis.capture_history_v1` (79 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `elect_tag` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `historical_names` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `n_historical_names` | `bigint` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `sex` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `age_first_capture` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `year_first_capture` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `capture_year` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `capture_quarter` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `capture_occasion` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `moc` | `text` | Yes | Original capture method (uncleaned historical category; keep raw text). |
| `recorded_sett_name` | `text` | Yes | Original sett/location name as imported, preserved even after alias resolution. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `normalized_sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `recorded_social_group_name` | `text` | Yes | Historical social-group text, not time-varying reconstructed group. |
| `recorded_social_group_id` | `bigint` | Yes | Relational identifier for recorded social group; join key, not a spatial coordinate. |
| `normalized_social_group_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `recorded_supergroup_name` | `text` | Yes | Original supergroup text; not inferred from polygon membership. |
| `capture_location_text` | `text` | Yes | Original setting category or free-text description; SETT, FIELD, BOUNDARY, etc. |
| `os_ref` | `text` | Yes | Source Ordnance Survey grid reference; preserve native precision. |
| `location_cleaning_note` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `disease_status_id` | `integer` | Yes | Relational identifier for disease status; join key, not a spatial coordinate. |
| `disease_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `weight` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `body_length` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `temperature` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `toothwear` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `neck_diameter` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `condition` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `reproductive_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `testes` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `eartags` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `retag` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `transmitter` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `tx_number` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `pm_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `pm_cause` | `text` | Yes | Source post-mortem cause, often free text; do not infer precise mortality from blank. |
| `blood_sample_taken` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `blood_taken_time` | `time without time zone` | Yes | Source or derived field; meaning follows its originating table and SQL definition. |
| `red_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `green_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `purple_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `yellow_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `peach_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `hair_sample_taken` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `fur_clip_taken` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `whisker_sample_taken` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blood_sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `recorder` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sampling_notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `health_monitoring` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ho_supervisor` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `severity_assessment` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `severity_initials` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `release_assessment` | `text` | Yes | Source post-handling assessment, which may say Fit, Death etc; not a definitive fate in isolation. |
| `release_initials` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effects` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effect_sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effect_comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `collar_action_taken` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_action_taker` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_checked_by` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_scratch_no` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `collar_transmitter` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `best_tune` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_impact_assessment` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ppm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_type` | `text` | Yes | What coordinate/recorded site represents; see exact categorical domain below. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `location_crs` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_coordinate_basis` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_class` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `analysis.diagnostic_results` (52 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `source_table` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `source_record_id` | `bigint` | Yes | Original or canonical test-row identifier. |
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `test_family` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `test_type` | `text` | Yes | Diagnostic test type/family. |
| `sample_type` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `result` | `text` | Yes | Standardised diagnostic interpretation as available (assay-specific). |
| `result_code` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `visual_line_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `visual_line_1_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `optical_density_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `visual_line_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `visual_line_2_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `optical_density_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `reference_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `mean_od` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `blot_cf` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blotson` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `brock_test_od` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `no_clotted` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `afno` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `lesions` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `abscesses` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `spoligo` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `spolprime` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wgs_clade` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `plate_number` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `experiment_date` | `timestamp without time zone` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `nil_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `avian_ppd_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `bovine_ppd_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `pwm_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `bovine_minus_nil` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `avian_minus_nil` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `bovine_minus_avian` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `pwm_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `pwm_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `ppd_a_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `ppd_a_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `ppd_b_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `ppd_b_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `nil_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `nil_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `retest` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `test_failed` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `test_info` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blood_quality` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `qc_note` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `comments` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |

### `research.captures` (66 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `individual_id` | `bigint` | No | Internal database key for badger; not a scientific tattoo. |
| `capture_date` | `date` | No | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `is_pm` | `boolean` | No | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `recorded_social_group_id` | `bigint` | Yes | Relational identifier for recorded social group; join key, not a spatial coordinate. |
| `recorded_sett_name` | `text` | Yes | Original sett/location name as imported, preserved even after alias resolution. |
| `recorded_social_group_name` | `text` | Yes | Historical social-group text, not time-varying reconstructed group. |
| `recorded_supergroup_name` | `text` | Yes | Original supergroup text; not inferred from polygon membership. |
| `moc` | `text` | Yes | Original capture method (uncleaned historical category; keep raw text). |
| `capture_location_text` | `text` | Yes | Original setting category or free-text description; SETT, FIELD, BOUNDARY, etc. |
| `weight` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `body_length` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `temperature` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `toothwear` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `neck_diameter` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `condition` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `reproductive_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `testes` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `eartags` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `retag` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `transmitter` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `tx_number` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `pm_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `pm_cause` | `text` | Yes | Source post-mortem cause, often free text; do not infer precise mortality from blank. |
| `comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `location_cleaning_note` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `disease_status_id` | `integer` | Yes | Relational identifier for disease status; join key, not a spatial coordinate. |
| `os_ref` | `text` | Yes | Source Ordnance Survey grid reference; preserve native precision. |
| `sett_name_clean` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `social_group_name_clean` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `recorder` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blood_taken_time` | `time without time zone` | Yes | Source or derived field; meaning follows its originating table and SQL definition. |
| `red_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `green_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `purple_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `peach_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `hair_sample_taken` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `fur_clip_taken` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `whisker_sample_taken` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `sampling_notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `blood_sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `yellow_tube_volume` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `blood_sample_taken` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `health_monitoring` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ho_supervisor` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `severity_assessment` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `severity_initials` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `release_assessment` | `text` | Yes | Source post-handling assessment, which may say Fit, Death etc; not a definitive fate in isolation. |
| `release_initials` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effects` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effect_sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effect_comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `collar_action_taken` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_action_taker` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_checked_by` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_scratch_no` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `collar_transmitter` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `best_tune` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_impact_assessment` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ppm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `condition_clean` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `eartags_clean` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_transmitter_clean` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `research.individuals` (10 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `individual_id` | `bigint` | No | Internal database key for badger; not a scientific tattoo. |
| `tattoo` | `text` | No | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `elect_tag` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `age_first_capture` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `year_first_capture` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `sex` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `sex_clean` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `age_first_capture_clean` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `research.setts` (10 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `sett_id` | `bigint` | No | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `sett_name` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `easting` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `northing` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `coordinate_system` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `accuracy_m` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `coordinate_source` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `coordinate_observed_on` | `date` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |

### `research.wecs_review_flags` (11 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `flag_id` | `text` | No | Stable unique reference for a human-review issue. |
| `category` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `capture_ids` | `ARRAY` | No | All source capture IDs implicated by a review flag. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `summary` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `evidence` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `current_interpretation` | `text` | No | Provisional interpretation; not a final adjudication. |
| `review_status` | `text` | No | OPEN; NEEDS_SOURCE_CHECK; WAITING_FIELD_TEAM; RESOLVED. |
| `final_decision` | `text` | Yes | Authoritative resolution; must be populated when review_status=RESOLVED. |
| `final_decision_at` | `timestamp with time zone` | Yes | Time final decision was recorded; nullable until resolved. |
| `updated_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.social_groups` (5 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `social_group` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `supergroup` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `count` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `access_raw.tbl_badger` (8 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `elect_tag` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `age_fc` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `year_fc` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sex` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `time_between_capture` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_blood_sampler` (6 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `pm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blood_sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_brock_test` (7 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `badger_id` | `text` | Yes | Relational identifier for badger; join key, not a spatial coordinate. |
| `brock_test_od` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `brock_test_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `no_clotted` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_captures` (57 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `pm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `moc` | `text` | Yes | Original capture method (uncleaned historical category; keep raw text). |
| `socg` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sett` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `capture_year` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `supergroup` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `where_text` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `weight` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `eartags` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `retag` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `toothwear` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `condition` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `reproc` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `testes` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_action_taken` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_action_taker` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_checked_by` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_scratch_no` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `transmitter` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `txno` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `best_tune` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `collar_impact_ass` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ppm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `body_length` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `temp` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blood` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `pmstat` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `pm_cause` | `text` | Yes | Source post-mortem cause, often free text; do not infer precise mortality from blank. |
| `os_ref` | `text` | Yes | Source Ordnance Survey grid reference; preserve native precision. |
| `recorder` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `health_monitoring` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `disease_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `time_blood_taken` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `red_volume` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `green_volume` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `purple_volume` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `yellow_volume` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `peach_volume` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `neck_diameter` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `hair_sample` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `furclip` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `whisker_taken` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ho_supervisor` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `severity_ass` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sev_initial` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `release_ass` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `rel_initial` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effects` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effect_sampler` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `adverse_effect_comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_culture` (15 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `pm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sample` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `afno` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `result` | `text` | Yes | Standardised diagnostic interpretation as available (assay-specific). |
| `lesions` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `abscesses` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `spoligo` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `spolprime` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wgs_clade` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sampler1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sampler2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_dpp_test` (11 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `badger_id` | `text` | Yes | Relational identifier for badger; join key, not a spatial coordinate. |
| `test_type` | `text` | Yes | Diagnostic test type/family. |
| `sample_type` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `visual_line_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `optical_density_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `visual_line_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `optical_density_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `pm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_elisa` (11 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `pm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `elisa_type` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ref` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `result` | `text` | Yes | Standardised diagnostic interpretation as available (assay-specific). |
| `mean_od` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blot_cf` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blotson` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_ifn_gamma_elisa` (31 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `plate_no` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `badger_id` | `text` | Yes | Relational identifier for badger; join key, not a spatial coordinate. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `import_filename` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `import_datetime` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `experiment_date` | `text` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `blood_quality` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `comments` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `wellstage_96_pwm_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_pwm_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_ppda_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_ppda_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_ppdb_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_ppdb_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_nil_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_nil_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `pwm_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `pwm_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ppd_a_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ppd_a_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ppd_b_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `ppd_b_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `nil_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `nil_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `retest` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `test_failed` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `test_info` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `result` | `text` | Yes | Standardised diagnostic interpretation as available (assay-specific). |
| `pm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_sett` (4 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `social_group` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_stat_pak` (6 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `badger_id` | `text` | Yes | Relational identifier for badger; join key, not a spatial coordinate. |
| `stat_pak_id` | `text` | Yes | Relational identifier for stat pak; join key, not a spatial coordinate. |
| `pm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `access_raw.tbl_wounds` (9 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `raw_row_id` | `bigint` | No | Relational identifier for raw row; join key, not a spatial coordinate. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `text` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `pm` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `area` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `amount` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wound_age` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `size` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `raw_imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `analysis.capture_infection_probabilities` (12 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `sample_date` | `date` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `year` | `smallint` | Yes | Source or derived field; meaning follows its originating table and SQL definition. |
| `quarter` | `smallint` | Yes | Source or derived field; meaning follows its originating table and SQL definition. |
| `model_run` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `diagnostic_fixed_prevalence` | `double precision` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `diagnostic_annual_prevalence` | `double precision` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `diagnostic_adjusted_annual` | `double precision` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `all_tests_fixed` | `double precision` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `all_tests_inferred` | `double precision` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `culture_only_fixed` | `double precision` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |

### `analysis.capture_location_v1` (20 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `original_recorded_sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `canonical_sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_class` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_display_category` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `capture_location_text` | `text` | Yes | Original setting category or free-text description; SETT, FIELD, BOUNDARY, etc. |
| `os_ref` | `text` | Yes | Source Ordnance Survey grid reference; preserve native precision. |
| `reference_source` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `so_grid_six_digits` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `newly_parsed_grid_reference` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `grid_sw_easting` | `integer` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `grid_sw_northing` | `integer` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `newly_parsed_cell_width_m` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `accompanying_location_description` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `positional_precision_note` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `spatial_interpretation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `analysis.capture_sett_alias_audit_v1` (11 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `original_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `canonical_sett_id` | `bigint` | Yes | Relational identifier for canonical sett; join key, not a spatial coordinate. |
| `canonical_sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `capture_location_text` | `text` | Yes | Original setting category or free-text description; SETT, FIELD, BOUNDARY, etc. |
| `location_type` | `text` | Yes | What coordinate/recorded site represents; see exact categorical domain below. |
| `location_quality` | `text` | Yes | Spatial location precision and provenance flag; see exact domain below. |
| `decision_note` | `text` | Yes | Human-readable rationale explaining curated decision, with evidence limitations. |
| `decision_source` | `text` | Yes | Who/what authorised decision and when. |
| `decided_at` | `timestamp with time zone` | Yes | Timestamp when curation was recorded. |

### `analysis.capture_sett_location_standardised_v1` (16 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `recorded_sett_name` | `text` | Yes | Original sett/location name as imported, preserved even after alias resolution. |
| `sett_clean` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `other_location_info` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `capture_location_text` | `text` | Yes | Original setting category or free-text description; SETT, FIELD, BOUNDARY, etc. |
| `os_ref` | `text` | Yes | Source Ordnance Survey grid reference; preserve native precision. |
| `location_class` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `coordinate_basis` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_crs` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `grid_cell_width_m` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |

### `analysis.encounter_episode_decisions_v1` (19 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `live_capture_id` | `bigint` | Yes | Relational identifier for live capture; join key, not a spatial coordinate. |
| `pm_capture_id` | `bigint` | Yes | Relational identifier for pm capture; join key, not a spatial coordinate. |
| `episode_outcome` | `text` | Yes | Fate associated with a curated field/PM pair. |
| `decision_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `field_location_basis` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `decision_note` | `text` | Yes | Human-readable rationale explaining curated decision, with evidence limitations. |
| `review_flags` | `ARRAY` | Yes | Source or derived field; meaning follows its originating table and SQL definition. |
| `decision_source` | `text` | Yes | Who/what authorised decision and when. |
| `decided_at` | `timestamp with time zone` | Yes | Timestamp when curation was recorded. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `field_sett_id` | `bigint` | Yes | Relational identifier for field sett; join key, not a spatial coordinate. |
| `field_sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `field_easting` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `field_northing` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `field_coordinate_representation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_pm_easting` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `original_pm_northing` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `original_pm_coordinate_representation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `analysis.encounter_pair_nonlinks_v1` (11 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `first_capture_id` | `bigint` | Yes | Relational identifier for first capture; join key, not a spatial coordinate. |
| `second_capture_id` | `bigint` | Yes | Relational identifier for second capture; join key, not a spatial coordinate. |
| `decision` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `decision_note` | `text` | Yes | Human-readable rationale explaining curated decision, with evidence limitations. |
| `decision_source` | `text` | Yes | Who/what authorised decision and when. |
| `decided_at` | `timestamp with time zone` | Yes | Timestamp when curation was recorded. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `first_date` | `date` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `first_method` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `second_date` | `date` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `second_method` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `analysis.encounter_review_queue_v1` (26 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `original_moc` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `encounter_type` | `text` | Yes | Observed or inferred encounter context; see exact categorical domain below. |
| `encounter_outcome` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_location_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_location_text` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_os_ref` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `original_pm_cause` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `prior_location_class` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `spatial_interpretation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `coordinate_representation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `review_unlinked_trap` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_trap_pm` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_sett_missing_xy` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_pm_sett_role` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_trap_pm_grid_role` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_priority` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `analysis.encounters_review_v1` (18 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `encounter_type` | `text` | Yes | Observed or inferred encounter context; see exact categorical domain below. |
| `outcome` | `text` | Yes | Recorded or inferred encounter fate; see exact categorical domain below. |
| `location_type` | `text` | Yes | What coordinate/recorded site represents; see exact categorical domain below. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `location_quality` | `text` | Yes | Spatial location precision and provenance flag; see exact domain below. |
| `episode_primary_capture_id` | `bigint` | Yes | Curated episode primary capture ID; null means no currently linked companion. |
| `original_moc` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `recorded_sett_name` | `text` | Yes | Original sett/location name as imported, preserved even after alias resolution. |
| `capture_location_text` | `text` | Yes | Original setting category or free-text description; SETT, FIELD, BOUNDARY, etc. |
| `os_ref` | `text` | Yes | Source Ordnance Survey grid reference; preserve native precision. |
| `comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `pm_cause` | `text` | Yes | Source post-mortem cause, often free text; do not infer precise mortality from blank. |
| `review_reason` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `analysis.encounters_standardised_v1` (39 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `original_moc` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `original_location_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_location_text` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_os_ref` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `original_pm_cause` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `prior_location_class` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `prior_reference_source` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `grid_sw_easting` | `integer` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `grid_sw_northing` | `integer` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `newly_parsed_cell_width_m` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `spatial_interpretation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `positional_precision_note` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sett_easting` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `sett_northing` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `encounter_type` | `text` | Yes | Observed or inferred encounter context; see exact categorical domain below. |
| `alive_when_encountered` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `encounter_outcome` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_role` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_type` | `text` | Yes | What coordinate/recorded site represents; see exact categorical domain below. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `coordinate_representation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_source` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `has_spatial_location` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `needs_location_review` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_trap_pm` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_unlinked_trap` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_sett_missing_xy` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_pm_sett_role` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_trap_pm_grid_role` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `rule_version` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `analysis.encounters_v1` (13 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `episode_primary_capture_id` | `bigint` | Yes | Curated episode primary capture ID; null means no currently linked companion. |
| `episode_record_role` | `text` | Yes | STANDALONE; FIELD_RECORD; PM_COMPANION. |
| `encounter_type` | `text` | Yes | Observed or inferred encounter context; see exact categorical domain below. |
| `outcome` | `text` | Yes | Recorded or inferred encounter fate; see exact categorical domain below. |
| `location_type` | `text` | Yes | What coordinate/recorded site represents; see exact categorical domain below. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `location_quality` | `text` | Yes | Spatial location precision and provenance flag; see exact domain below. |

### `analysis.encounters_with_episodes_v1` (48 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `tattoo` | `text` | Yes | Canonical scientific badger tattoo; changes in identity require separate audit. |
| `capture_date` | `date` | Yes | Date recorded for capture, handling or PM event; may differ from exact death date. |
| `original_moc` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `is_pm` | `boolean` | Yes | Post-mortem-coded source row (true or false); not itself a unique death episode. |
| `original_location_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_location_text` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_os_ref` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `original_comment` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `original_pm_cause` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `prior_location_class` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `prior_reference_source` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `grid_sw_easting` | `integer` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `grid_sw_northing` | `integer` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `newly_parsed_cell_width_m` | `integer` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `spatial_interpretation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `positional_precision_note` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sett_easting` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `sett_northing` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `encounter_type` | `text` | Yes | Observed or inferred encounter context; see exact categorical domain below. |
| `alive_when_encountered` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `encounter_outcome` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_role` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_type` | `text` | Yes | What coordinate/recorded site represents; see exact categorical domain below. |
| `location_easting` | `numeric` | Yes | British National Grid easting, nullable; could be provisional sett point or grid-cell SW corner. |
| `location_northing` | `numeric` | Yes | British National Grid northing; interpretation identical to location_easting. |
| `coordinate_representation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_source` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `location_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `has_spatial_location` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `needs_location_review` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_trap_pm` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_unlinked_trap` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_sett_missing_xy` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_pm_sett_role` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `review_trap_pm_grid_role` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `rule_version` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `episode_primary_capture_id` | `bigint` | Yes | Curated episode primary capture ID; null means no currently linked companion. |
| `episode_pm_capture_id` | `bigint` | Yes | Relational identifier for episode pm capture; join key, not a spatial coordinate. |
| `episode_record_role` | `text` | Yes | STANDALONE; FIELD_RECORD; PM_COMPANION. |
| `resolved_episode_outcome` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `episode_decision_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `episode_review_flags` | `ARRAY` | Yes | Source or derived field; meaning follows its originating table and SQL definition. |
| `episode_field_easting` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `episode_field_northing` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `episode_field_coordinate_representation` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |

### `analysis.sett_inventory_v1` (12 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `sett_id` | `bigint` | Yes | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `canonical_sett_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `capture_count` | `bigint` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `n_pm_records` | `bigint` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `first_capture_date` | `date` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `last_capture_date` | `date` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `easting` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `northing` | `numeric` | Yes | Coordinate component; spatial precision and evidence must be assessed separately. |
| `coordinate_system` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `accuracy_m` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `coordinate_source` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `coordinate_status` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |

### `research.brock_tests` (7 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `brock_test_id` | `bigint` | No | Relational identifier for brock test; join key, not a spatial coordinate. |
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `brock_test_od` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `test_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `no_clotted` | `boolean` | Yes | Boolean true/false, potentially null where source did not record. |
| `comments` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `research.capture_sett_alias_decisions` (6 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `original_recorded_name` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `canonical_sett_id` | `bigint` | No | Relational identifier for canonical sett; join key, not a spatial coordinate. |
| `decision_note` | `text` | No | Human-readable rationale explaining curated decision, with evidence limitations. |
| `decision_source` | `text` | No | Who/what authorised decision and when. |
| `decided_at` | `timestamp with time zone` | No | Timestamp when curation was recorded. |

### `research.cultures` (14 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `culture_id` | `bigint` | No | Relational identifier for culture; join key, not a spatial coordinate. |
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `sample_type` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `afno` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `culture_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `lesions` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `abscesses` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `spoligo` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `spolprime` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wgs_clade` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sampler_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `sampler_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `comments` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `research.disease_statuses` (2 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `disease_status_id` | `integer` | No | Relational identifier for disease status; join key, not a spatial coordinate. |
| `disease_status` | `text` | No | Category/result as recorded or standardised for this table; examine distinct values and assay context. |

### `research.dpp_tests` (14 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `dpp_test_id` | `bigint` | No | Relational identifier for dpp test; join key, not a spatial coordinate. |
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `test_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `comments` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `test_type` | `text` | Yes | Diagnostic test type/family. |
| `sample_type` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `visual_line_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `optical_density_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `visual_line_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `optical_density_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `source_raw_row_id` | `bigint` | Yes | Relational identifier for source raw row; join key, not a spatial coordinate. |
| `visual_line_1_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `visual_line_2_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |

### `research.elisa_tests` (11 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `elisa_test_id` | `bigint` | No | Relational identifier for elisa test; join key, not a spatial coordinate. |
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `elisa_type` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `reference` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `test_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `mean_od` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `blot_cf` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `blotson` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `comments` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `test_result_clean` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |

### `research.encounter_classification_decisions` (6 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `encounter_type` | `text` | Yes | Observed or inferred encounter context; see exact categorical domain below. |
| `outcome` | `text` | Yes | Recorded or inferred encounter fate; see exact categorical domain below. |
| `decision_note` | `text` | No | Human-readable rationale explaining curated decision, with evidence limitations. |
| `decision_source` | `text` | No | Who/what authorised decision and when. |
| `decided_at` | `timestamp with time zone` | No | Timestamp when curation was recorded. |

### `research.encounter_episode_decisions` (9 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `live_capture_id` | `bigint` | No | Relational identifier for live capture; join key, not a spatial coordinate. |
| `pm_capture_id` | `bigint` | No | Relational identifier for pm capture; join key, not a spatial coordinate. |
| `episode_outcome` | `text` | No | Fate associated with a curated field/PM pair. |
| `decision_status` | `text` | No | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `field_location_basis` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `decision_note` | `text` | No | Human-readable rationale explaining curated decision, with evidence limitations. |
| `review_flags` | `ARRAY` | No | Source or derived field; meaning follows its originating table and SQL definition. |
| `decision_source` | `text` | No | Who/what authorised decision and when. |
| `decided_at` | `timestamp with time zone` | No | Timestamp when curation was recorded. |

### `research.encounter_pair_nonlinks` (6 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `first_capture_id` | `bigint` | No | Relational identifier for first capture; join key, not a spatial coordinate. |
| `second_capture_id` | `bigint` | No | Relational identifier for second capture; join key, not a spatial coordinate. |
| `decision` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `decision_note` | `text` | No | Human-readable rationale explaining curated decision, with evidence limitations. |
| `decision_source` | `text` | No | Who/what authorised decision and when. |
| `decided_at` | `timestamp with time zone` | No | Timestamp when curation was recorded. |

### `research.ifn_gamma_elisa` (38 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `ifn_test_id` | `bigint` | No | Relational identifier for ifn test; join key, not a spatial coordinate. |
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `plate_number` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `experiment_date` | `timestamp without time zone` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `import_filename` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `imported_at` | `timestamp without time zone` | Yes | Recorded date/time or database provenance timestamp; check original source for precision. |
| `blood_quality` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `nil_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `avian_ppd_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `bovine_ppd_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `pwm_value` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `bovine_minus_nil` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `avian_minus_nil` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `bovine_minus_avian` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `test_info` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `test_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `comments` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `pwm_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `pwm_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `ppd_a_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `ppd_a_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `ppd_b_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `ppd_b_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `nil_1` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `nil_2` | `numeric` | Yes | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `retest` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `test_failed` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `capture_datetime` | `timestamp without time zone` | Yes | Recorded date or timestamp; not necessarily an exact biological event time. |
| `wellstage_96_pwm_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_pwm_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_ppda_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_ppda_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_ppdb_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_ppdb_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_nil_1` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wellstage_96_nil_2` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `qc_note` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |

### `research.infection_probabilities` (11 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `infection_probability_id` | `bigint` | No | Relational identifier for infection probability; join key, not a spatial coordinate. |
| `individual_id` | `bigint` | No | Internal database key for badger; not a scientific tattoo. |
| `capture_id` | `bigint` | Yes | Unique source capture/PM row; foreign key to research.captures. |
| `sample_date` | `date` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `year` | `smallint` | No | Source or derived field; meaning follows its originating table and SQL definition. |
| `quarter` | `smallint` | No | Source or derived field; meaning follows its originating table and SQL definition. |
| `model_variant` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `infection_probability` | `double precision` | No | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `model_run` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `source_file` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `research.infection_quarterly_probabilities` (10 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `infection_quarterly_id` | `bigint` | No | Relational identifier for infection quarterly; join key, not a spatial coordinate. |
| `individual_id` | `bigint` | No | Internal database key for badger; not a scientific tattoo. |
| `quarter_date` | `date` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `year` | `smallint` | No | Source or derived field; meaning follows its originating table and SQL definition. |
| `quarter` | `smallint` | No | Source or derived field; meaning follows its originating table and SQL definition. |
| `model_variant` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `infection_probability` | `double precision` | No | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `model_run` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `source_file` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `imported_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `research.sett_annual_territory_matches` (9 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `year` | `integer` | No | Numeric observed or derived field; units/definition follow original Access documentation or generating SQL. |
| `sett_id` | `bigint` | No | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `polygon_id` | `text` | Yes | Relational identifier for polygon; join key, not a spatial coordinate. |
| `territory_name` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `match_status` | `text` | No | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `polygon_source` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `coordinate_source` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `match_id` | `bigint` | No | Relational identifier for match; join key, not a spatial coordinate. |

### `research.sett_social_group_links` (6 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `sett_social_group_id` | `bigint` | No | Relational identifier for sett social group; join key, not a spatial coordinate. |
| `sett_id` | `bigint` | No | Canonical sett ID where backed by recorded identity or audited alias; not necessarily physical encounter XY. |
| `social_group_id` | `bigint` | No | Relational identifier for social group; join key, not a spatial coordinate. |
| `valid_from` | `date` | Yes | Recorded date or timestamp; not necessarily an exact biological event time. |
| `valid_to` | `date` | Yes | Recorded date or timestamp; not necessarily an exact biological event time. |
| `notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |

### `research.social_group_supergroup_history` (6 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `social_group_supergroup_id` | `bigint` | No | Relational identifier for social group supergroup; join key, not a spatial coordinate. |
| `social_group_id` | `bigint` | No | Relational identifier for social group; join key, not a spatial coordinate. |
| `supergroup_id` | `bigint` | No | Relational identifier for supergroup; join key, not a spatial coordinate. |
| `valid_from` | `date` | Yes | Recorded date or timestamp; not necessarily an exact biological event time. |
| `valid_to` | `date` | Yes | Recorded date or timestamp; not necessarily an exact biological event time. |
| `notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |

### `research.social_groups` (4 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `social_group_id` | `bigint` | No | Relational identifier for social group; join key, not a spatial coordinate. |
| `social_group_name` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `research.stat_pak_tests` (6 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `stat_pak_test_id` | `bigint` | No | Relational identifier for stat pak test; join key, not a spatial coordinate. |
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `test_result` | `text` | Yes | Category/result as recorded or standardised for this table; examine distinct values and assay context. |
| `comments` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |
| `stat_pak_id` | `text` | Yes | Relational identifier for stat pak; join key, not a spatial coordinate. |

### `research.supergroups` (4 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `supergroup_id` | `bigint` | No | Relational identifier for supergroup; join key, not a spatial coordinate. |
| `supergroup_name` | `text` | No | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `research.wounds` (9 columns)

| Column | SQL type | Null? | Definition / use |
|---|---|---|---|
| `wound_id` | `bigint` | No | Relational identifier for wound; join key, not a spatial coordinate. |
| `capture_id` | `bigint` | No | Unique source capture/PM row; foreign key to research.captures. |
| `wound_area` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wound_amount` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wound_age` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wound_size` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `wound_type` | `text` | Yes | Recorded or derived text; no fixed category set assumed unless listed in categorical appendix. |
| `notes` | `text` | Yes | Free-text provenance, observation or explanation; not a controlled category. |
| `created_at` | `timestamp with time zone` | No | Recorded date/time or database provenance timestamp; check original source for precision. |

### `research.capture_grid_coordinate_decisions` (10 columns, newly audited)

One record per intentionally corrected or withheld historical grid point; **87 corrected** and **10 withheld**. No original source data is overwritten.

| Column | SQL type | Null? | Definition |
|---|---|---|---|
| `capture_id` | bigint | No | Source capture/PM record key; one grid decision per source row |
| `original_grid_reference` | text | Yes | Original recorded OS reference or embedded raw location text |
| `source_easting` | numeric | Yes | Previously parsed/derived easting before review, not raw survey measurement |
| `source_northing` | numeric | Yes | Previously parsed/derived northing before review |
| `corrected_easting` | numeric | Yes | Researcher-approved provisional BNG corrected easting; null if WITHHELD |
| `corrected_northing` | numeric | Yes | Corresponding provisional BNG northing; null if WITHHELD |
| `decision_status` | text | No | **CORRECTED** (use provisional corrected XY) or **WITHHELD** (clean XY null) |
| `decision_note` | text | No | Record-specific error explanation, evidence and uncertainties |
| `decision_source` | text | No | Provenance of decision / audit |
| `reviewed_at` | timestamptz | No | Date and time decision was recorded |

### `analysis.grid_reference_audit_v1` (19 columns, newly audited)

One row per grid correction/withheld case. Researcher-readable provenance paired with final spatial output. This is a **review view**, not a separate source of spatial observations.

| Column | SQL type | Null? | Definition |
|---|---|---|---|
| `capture_id` | bigint | Yes | Source capture identifier |
| `tattoo` | text | Yes | Canonical badger tattoo |
| `capture_date` | date | Yes | Recorded event date |
| `is_pm` | boolean | Yes | Original PM classification |
| `os_ref` | text | Yes | Original source OS reference, unmodified |
| `recorded_sett_name` | text | Yes | Original named sett or embedded location text |
| `capture_location_text` | text | Yes | Source field/road/recovery description |
| `original_grid_reference` | text | Yes | Original grid string entered in curation table |
| `source_easting` | numeric | Yes | Coordinate from previous parser, potentially erroneous |
| `source_northing` | numeric | Yes | Previous parser's northing |
| `corrected_easting` | numeric | Yes | Proposed accepted BNG correction, null if withheld |
| `corrected_northing` | numeric | Yes | Proposed accepted BNG correction, null if withheld |
| `decision_status` | text | Yes | CORRECTED or WITHHELD |
| `decision_note` | text | Yes | Why the coordinate was corrected or withheld |
| `decision_source` | text | Yes | Provenance |
| `reviewed_at` | timestamptz | Yes | Curation timestamp |
| `analysis_easting` | numeric | Yes | **Actual cleaned analysis** easting after override |
| `analysis_northing` | numeric | Yes | Actual cleaned analysis northing after override |
| `location_quality` | text | Yes | Final quality flag distinguishing corrected proxy vs withheld |

### `analysis.mortality_model_candidate_v1` (18 columns, newly audited)

**1,304 rows** (1,300 candidates, **2 ID conflicts**, **2 possible duplicate death reports**), 400 without XY. This view **retains all rows**, attaching a model-inclusion status; it is NOT a signed-off survival-input table.

| Column | SQL type | Null? | Definition |
|---|---|---|---|
| `capture_id` | bigint | Yes | Primary source death-event record (PM companion excluded) |
| `tattoo` | text | Yes | Current canonical tattoo (may be disputed) |
| `recorded_event_date` | date | Yes | Source date, not necessarily exact moment of death |
| `mortality_outcome` | text | Yes | FOUND_DEAD, DIED, EUTHANISED, KILLED |
| `encounter_type` | text | Yes | RTA, TRAP, FOUND_DEAD etc; not the terminal status itself |
| `source_is_pm` | boolean | Yes | PM flag on primary source row |
| `original_moc` | text | Yes | Original uncategorised capture/encounter method |
| `pm_cause` | text | Yes | Original PM cause/comment where supplied |
| `linked_pm_capture_id` | bigint | Yes | Companion PM source ID, if curated pair |
| `linked_pm_date` | date | Yes | Date of confirmed companion PM row |
| `location_easting` | numeric | Yes | Best supported field/recovery XY, nullable and sometimes coarse |
| `location_northing` | numeric | Yes | Companion BNG northing |
| `location_quality` | text | Yes | Grid/reference precision and any uncertainty |
| `next_live_capture_date` | date | Yes | Earliest subsequent explicit live trap/net/snare/dart observation for linked identity |
| `previous_death_record_date` | date | Yes | Earlier death under same current identity, if any |
| `mortality_review_status` | text | Yes | Evidence/identity quality (e.g. PM-supported, later-live contradiction, duplicate warning) |
| `terminal_model_status` | text | Yes | **CANDIDATE_TERMINAL_DEATH**, **HOLD_IDENTITY_CONTRADICTION**, **HOLD_POSSIBLE_REPEAT_DEATH** |
| `terminal_model_note` | text | Yes | Why record remains a candidate or is held for further review |

### New grid review metadata (3 additional columns on `research.capture_grid_coordinate_decisions`)

| Column | SQL type | Null? | Meaning |
|---|---|---|---|
| `map_review_status` | text | No | `VISUALLY_VERIFIED` (87 corrected grid points, geographic plausibility visually approved, **not** exact positional accuracy); `REJECTED_BY_INVESTIGATOR` (2 withheld outliers); `PENDING_REVIEW` (8 withheld) |
| `map_review_note` | text | Yes | Scope and limitations of investigator's visual map review |
| `map_reviewed_at` | timestamptz | Yes | When the map decision was recorded |

### `analysis.grid_withheld_candidate_review_v1` (20 columns)

Read-only review table for **10 withheld grid decisions**, including 30 **test-only** hypothetical northing corrections of -100000m. This view **does not modify** accepted spatial XY. It keeps all withheld source records and includes the two explicitly rejected points with **no** suggested replacement. The remaining original-grid-review worklist contains nine records; other withheld PM evidence may have a different missing-location priority. A further withheld PM row (17427) is categorised under a different spatial worklist reason.

| Column | SQL type | Null? | Meaning |
|---|---|---|---|
| `capture_id` | bigint | Yes | Original source-record key |
| `tattoo` | text | Yes | Badger tattoo |
| `capture_date` | date | Yes | Source encounter date |
| `is_pm` | boolean | Yes | Source PM indicator |
| `encounter_type` | text | Yes | Cleaned method/context |
| `outcome` | text | Yes | Cleaned fate, independent of spatial quality |
| `original_grid_reference` | text | Yes | Unmodified written grid reference |
| `original_place_description` | text | Yes | Original recorded locality or recovery-site description |
| `source_easting` | numeric | Yes | Original parser's inferred easting (not necessarily correct) |
| `source_northing` | numeric | Yes | Original parser's inferred northing (not necessarily correct) |
| `accepted_easting` | numeric | Yes | Audited accepted easting; always null for withheld cases |
| `accepted_northing` | numeric | Yes | Audited accepted northing; always null for withheld cases |
| `decision_status` | text | Yes | WITHHELD for this queue |
| `map_review_status` | text | Yes | Visual review status; see controlled categories above |
| `proposed_review_group` | text | Yes | TEST_100KM_NORTHING_SHIFT; IRREGULAR_OR_REMOTE_GRID; LEG_OF_MUTTON_GRID_ANOMALY; INVESTIGATOR_REJECTED |
| `test_easting` | numeric | Yes | Hypothetical location for visual test, NOT approved spatial output |
| `test_northing` | numeric | Yes | Hypothetical N-100000m for plausible boundary-error cases only |
| `test_warning` | text | Yes | Explicit warning that test points are not approved |
| `decision_note` | text | Yes | Historical source, problem and spatial decision rationale |
| `map_review_note` | text | Yes | Investigator review notes |

### `analysis.spatial_missing_review_v1` (18 columns, current missing-XY review queue)

**951 rows, one per source capture/PM record with no accepted XY.** This is an organisational QA view, **not** an exclusion list. Dead events remain available without a coordinate. `spatial_review_priority` groups each row into exactly one category: MORTALITY_RECOVERY_LOCATION (331); SETT_XY_FIELD_TEAM (306); NAMED_NON_SETT_SITE (163); ASSOCIATED_SETT_NOT_ACTUAL_SITE (107); ORIGINAL_GRID_VERIFY (9); SOURCE_LOCATION_UNSPECIFIED (26); PM_COMPANION_NO_INDEPENDENT_POINT (9). The WITHHELD decision table has 40 entries; one is grouped under another priority in this mutually exclusive queue.

| Column | SQL type | Null? | Scientific meaning |
|---|---|---|---|
| `capture_id` | bigint | Yes | Original capture/PM source row identifier |
| `tattoo` | text | Yes | Badger tattoo, potentially unidentified UN animal |
| `capture_date` | date | Yes | Source encounter date |
| `is_pm` | boolean | Yes | Source PM flag, not itself an independent death |
| `encounter_type` | text | Yes | Standardised encounter category |
| `outcome` | text | Yes | Standardised biological fate, independent of XY |
| `sett_id` | bigint | Yes | Known canonical associated sett when separately supported |
| `canonical_sett_name` | text | Yes | Current sett lookup name, not necessarily capture-site point |
| `recorded_sett_name` | text | Yes | Original named sett/location source, retained |
| `capture_location_text` | text | Yes | Original field, boundary, sett, recovery description |
| `os_ref` | text | Yes | Original OS grid text, potentially malformed |
| `original_moc` | text | Yes | Original method-of-capture/recovery code |
| `comment` | text | Yes | Source capture remarks; free text |
| `pm_cause` | text | Yes | Source PM cause/narrative; free text |
| `episode_record_role` | text | Yes | STANDALONE / FIELD_RECORD / PM_COMPANION |
| `location_type` | text | Yes | Intended physical site or associated sett category |
| `location_quality` | text | Yes | Why an XY is absent; see exact categorical domain above |
| `spatial_review_priority` | text | Yes | Mutually exclusive missing-position category and next action |

**Five further recoveries with malformed original references** (16859, 16967, 16997, 17043, 17500) now have **provisional** location estimates, each with original source reference and uncertainty notes in `research.capture_grid_coordinate_decisions`. Their nominal 1 m, 10 m or 100 m *grid cell width* is not proof of equivalent observational accuracy.

## Reproducible categorical-domain inspection

Historical free text and lab result codes are **not reliably closed enumerations**. For any candidate category use:

```sql
select encounter_type,count(*) from analysis.encounters_clean_v1 group by 1 order by 2 desc;
select outcome,count(*) from analysis.encounters_clean_v1 group by 1 order by 2 desc;
select location_type,count(*) from analysis.encounters_clean_v1 group by 1 order by 2 desc;
select location_quality,count(*) from analysis.encounters_clean_v1 group by 1 order by 2 desc;
select moc,count(*) from research.captures group by 1 order by 2 desc;
select review_status,count(*) from research.wecs_review_flags group by 1;
```

### Seven additional pair confirmations (4 November 2026)

The wider identity/death audit confirmed **seven more** field–PM pairs: 001R, 017R, 045W, D007, I022, M012 and Q070. A source `capture_id` still represents one original row, but **17 pairs** now share an episode (PM companion not a separate death). D007 was recorded as a PM one day later solely because of a documented historical database date limitation; the primary note states death under anaesthetic. Only W023 and Q082 remain as tattoos with two unlinked candidate death reports. U005 and 020D deaths are temporarily held from tattoo terminal assignments due identity contradictions. For a safe record-level audit see `analysis.mortality_model_candidate_v1` and `analysis.wecs_review_flags_v1`.

## Outstanding audit limitations

1. The 12 imported Access tables have not been proven equivalent to the **entire original 62-object Access inventory**. Counts/key-level parity have been checked for principal capture/individual data; a full field-by-field source audit is pending.
2. Two fatal PM records conflict with subsequent live tattoo histories (U005, 020D); two pairs of possible duplicate deaths (W023, Q082) are still open.
3. Named field-team sett coordinates remain pending; **38** ambiguous historical grid points are deliberately withheld, 57 grid interpretations were corrected provisionally, and the remaining six-digit references now explicitly carry 100 m grid-square provenance.
4. This schema snapshot is current at creation, not a substitute for database migrations and source records. Only primary views are recommended for scientific usage; other specialised or legacy views may remain for compatibility.


### Investigator approval of 30 more historical grid corrections (5 November 2026)

Thirty 100 km northing-shift candidates were accepted from the interactive map. Their locations are now included in `analysis.encounters_clean_v1` as `GRID_REFERENCE_CORRECTED_PROVISIONAL`; this denotes **geographical plausibility, not independently measured positional accuracy**. Source references and prior parser coordinates remain available in `research.capture_grid_coordinate_decisions`.

**Current authoritative counts:** 87 grid decisions `CORRECTED` and `VISUALLY_VERIFIED`; 10 `WITHHELD` (8 pending investigation, 2 `REJECTED_BY_INVESTIGATOR`). There are 951 source records without accepted XY, of which 400 primary recorded death events have missing XY. The one-priority missing-location review view now has 331 MORTALITY_RECOVERY_LOCATION, 306 SETT_XY_FIELD_TEAM, 163 NAMED_NON_SETT_SITE, 107 ASSOCIATED_SETT_NOT_ACTUAL_SITE, 26 SOURCE_LOCATION_UNSPECIFIED, **9 ORIGINAL_GRID_VERIFY**, and 9 PM_COMPANION_NO_INDEPENDENT_POINT.

The test-only candidate view continues to show the **remaining withheld records**, not the already approved 30. The decision status and map review status are separate fields for provenance.


### Latest spatial corrections — 5 November 2026

**Current counts:** 88 provisional corrected grids, 9 withheld; 950 source encounter rows and 399 primary recorded deaths without accepted XY. Of the corrected grids, 87 were visually accepted on the map and UN221 is separately corroborated by a historic mapped west gateway. Source grid-square width is NOT exact RTA recovery-site accuracy.

- **UN221, source capture 17285:** original numeric reference `014795` has reversed three-digit halves. Reconstructed `SO795014`, E379500 N201400 (100m square). Independently corroborated by documented Woodchester Park west-gate grid and user WGS84 location. Original uncorrected source retained.
- **Leg of Mutton** is recorded historically as FIELD / NET and HEDGE / SNARE, and in 2019 as a shot-PM locality; there is no canonical sett of that name. Two original PM records `SO820500` still have withheld XY; do not copy another animal's grid location.
- **Cockadilly** is a hamlet and historical RTA locality, not a canonical sett. Capture 18 `801791 COCKADILLY` remains withheld pending original grid verification.


### Coarse locality proxy and completion boundary — 5 November 2026

New controlled `location_quality` category: **`LOCALITY_CENTROID_APPROXIMATE`**, currently two historical Cockadilly RTA records (capture 18, 3382). Coordinates E379800 N200200 are rounded from OSM hamlet node 412786736 (51.7004528,-2.2933255). This is **only approximate hamlet context**, not actual road-recovery precision, and must not support exact spatial movement/disease distances or inferred residence/social-group. The source original grid/text is preserved in `research.capture_grid_coordinate_decisions`; 3382 had no original grid reference.

Two independently corroborated OS grid corrections: C016/16869 `008802` was transposed from `802008` (E380200 N200800; other original records 16856/17002 on Tinkley Lane), and UN492/17117 `SO988808` reconstructed as `ST808988` (E380800 N198800; Woodcock entrance reference group ST808989, ST807991, SO807992). These remain **provisional 100 m grid squares** rather than exact carcass points; UN tattoos never acquire a social group by this procedure.

**Current live totals:** 17,586 source capture/PM records; 92 corrected location decisions, including two locality-centre proxies; six withheld grid points (F030 12072, UN260 17254, two Leg of Mutton PMs 16861/17477, Watts Farm J095 17376, and PM companion 017R 17427). 946 source rows and 395 primary recorded deaths lack accepted XY. The broader missing-XY worklist is not equivalent to an error list: 330 mortality/recovery sites, 306 field-team sett XY, 163 named nonsett sites, 107 deliberately unknown associated-sett conflicts, 26 unspecified locations, nine PM companions and five other original-grid cases. Preserve any mortality regardless of whether the recovery site can be mapped.


### Canonical sett-name crosswalk for field confirmation (5 November 2026)

A **read-only export**, not a database rewrite, combines 177 canonical `research.setts` (159 with XY, 18 without) with the 41 additional historical named-sett/site labels in the field-team request. This produces **218 separate named crosswalk rows**, with **59 currently lacking confirmed XY**. The 59 include the 18 canonical sett IDs without coordinates, plus 41 labels requiring independent site/alias decisions. The earlier 58-name list omitted the existing unmapped canonical `FOX TREE` (sett_id=143), which is now explicitly present in the 59-name field-team file. Do not treat all 41 extra labels as independent biological setts until reviewed; PM-only descriptions may be recovery sites, not setts.

Files, all under `outputs/spatial_location_audit/`:

- `WECS_definitive_sett_alias_crosswalk_draft.csv`: one row per canonical sett or unresolved historical location, BNG XY where approved, **confirmed text aliases in a separate column from unapproved historical matches**. It remains a draft until the field team has validated the outstanding locations.
- `WECS_field_team_59_unlocated_names.csv`: original SETT-labelled first/last dates and methods, 59 names, canonical IDs where already known and editable field-team XY/evidence fields.
- `WECS_sett_alias_rule_register_approved_vs_unverified.csv`: 20 historical name-spelling/alias rules plus six numeric grid strings mistakenly recorded as sett-name text; status distinguishes approved alias, legacy coordinate-source spelling, unverified historical association and explicitly blocked merges.

**Confirmed text aliases** include `MRS MACKS -> MRS MACK'S`, `S PEGLARS -> SOUTH PEGLARS`, `STONEY TRACK -> STONY TRACK`, `WEST MAIN -> WEST` and the existing source `TOP SETT -> TOP` (source already linked to canonical TOP). Some of these are SETT observations; a `BOUNDARY`, `WOOD` or `FIELD` observation must **not** inherit an associated sett's coordinates merely because the name is reconciled.

**Never automatically merge** `BLACKBERRY -> BRAMBLE` or `GRAVEL -> GRAVEL PIT`: each is a pair of distinct canonical sett IDs. `FOXCUB -> FOX` and `DINGLE VALLEY -> DINGLE` remain hypotheses requiring field-team evidence. Historical lookup spelling `CHESNUT`, `JACKSMIREY`, `GULLY`, `CLIFF FACE` must not override canonical IDs or create biological aliases by themselves. Preserve source strings and track who confirmed each mapping before applying it to analysis/model data. No Supabase changes were made by this export.


### Numeric source grid references in sett-name field — resolved 5 November 2026

Six historical numeric SETT-field values were source grid references, not sett aliases: captures 30=808011 E380800/N201100; 32=810997 E381000/N199700; 57=825008 E382500/N200800; 62=830028 E383000/N202800; 73=836008 E383600/N200800; 77=837009 E383700/N200900. All six are post-mortem death/recovery events already mapped as approximate 100m BNG grid cells in analysis.encounters_clean_v1 before this resolution; capture 62 is ROAD, the others RECOVERY_SITE; all lack canonical sett_id. No original recorded name, coordinate, source record, death classification or group assignment changed. Captures 30 and 77 have CHESTNUT and PARK MILL, respectively, within their grid squares, but proximity cannot prove sett identity. Grid precision remains provisional (capture 32 already grid corrected; others prefix-unverified).


### Approved fixed-sett text aliases — TOP SETT and TODDS (10 November 2026)

The source names **TOP SETT** and **TODDS** are recognised as text variants of canonical **TOP** (research.setts ID 20) and **TODD'S** (research.setts ID 158), respectively. Preserve `research.captures.recorded_sett_name` unchanged; use canonical `sett_id` and fixed `research.setts` XY in a spatial trapping likelihood only where physical `capture_location_text=SETT`, curated `location_type=SETT`, and `location_quality=SETT_POINT_PROVISIONAL` support the association. A name match by itself does **not** turn a recovery or non-sett record into a fixed trap observation.

The canonical joins were already correct before this update. On 10 November, a guarded transactional SQL statement populated `research.capture_sett_alias_decisions` for **349 TOP SETT→TOP** and **8 TODDS→TODD'S** qualifying fixed-sett records (357 total), with explicit researcher-approved decision source and note. There were **358** capture source rows recording TOP SETT in total; the other nine do not satisfy the fixed-sett event eligibility test and **were not** automatically assigned a new spatial capture interpretation. No original name, captured sett ID, geographic coordinates, social-group identity, PM classifications or raw capture record was rewritten.

The recorded executed statement is `sql/migrations/20261110_top_sett_todds_capture_alias_decisions_APPLIED.sql`. Future consistency must be checked using read-only `sql/audit/WECS_SETT_ALIAS_RULE_INTEGRITY_20261110.sql` before a new modelling snapshot. The check flags any later named capture with a conflicting/missing canonical sett, inconsistent XY, or an eligible SETT event lacking its capture-level alias decision. New future captures are **not** automatically approved solely by their string: review them and register a source-supported decision. Original map coordinate accuracy is still provisional, as for all reference sett-point captures.


### Model input spatial classification audit: blank ancillary location field (10 November 2026)

**Read-only assessment (not a Supabase data correction):** Across the 1977–2025 qualifying live encounter records, the usual fixed-sett spatial filter `location_type='SETT'` plus `location_quality='SETT_POINT_PROVISIONAL'` retains 15,521 of 16,218 records. A distinct class of **159** live records has `location_type='SETT_ASSOCIATION'`, `location_quality='SETT_ASSOCIATION_PROVISIONAL'`, **blank** original `research.captures.capture_location_text`, but a **named original recorded sett**, valid canonical sett ID, fixed accepted reference XY and curated `encounter_type='TRAP'`. These 159 records involve **37 canonical setts and 133 tattoos**. In **110** the original `moc='TRAP'`; in **49** original `moc` is missing, but the curated encounter is `TRAP` and both original weight and `blood_sample_taken` are present. All 49 are from 1998–1999, consistent with the existing period-specific missing-method classification rule. The 33 nonblank source comments within this set were examined; none explicitly placed a capture at an alternate field/wood/road location. Six recorded sett names differ from canonical spelling by historical name standardisation; no new setter join was inferred on name proximity alone.

**Interpretation:** The original blank ancillary `capture_location_text` is not affirmative evidence of a nonsett location, and its absence alone should not force exclusion of credible named-sett trap events from *model-specific* provisional fixed-sett spatial observations. J011 FIELD FARM examples (4 records, original capture IDs 4630, 4633, 4634, 4635) illustrate this distinction. **Do not automatically promote all SETT_ASSOCIATION encounters**: the eligibility derivation must additionally require reliable trapping evidence, original named canonical sett, accepted XY, no conflicting location description and non-PM live episode. Original `capture_location_text` remains NULL and original canonical location coordinates remain the same. Modelling should retain provenance (explicit SETT versus named-sett with blank ancillary type; original TRAP versus period-imputed TRAP) and test sensitivity to including the latter.

**Remaining distinct classes:** **304** qualifying live records explicitly identify `capture_location_text='SETT'` but have noneligible `location_quality` and no accepted spatial sett reference: **301 UNRESOLVED and 3 SETT_ASSOCIATION_ONLY**, involving known but currently unmapped canonical setts. They cannot be made spatially mapped by a more permissive name rule; field-coordinate evidence is still needed. A further **52** eligible records have `SETT_COORDINATE_CONFLICT` because an explicit nonsett location type such as field, wood or boundary contradicts inference of capture at the associated sett. These must not be snapped to canonical sett XY. Other unmatched or nonsett captures retain their own location categories; a grid-coded RTA is a mortality/recovery position, not a trap detector.

**Version/counter check:** Live database query returned 16,230 qualifying encounters if 1976 is mistakenly included, including 12 records before study year 1977. Restricting to 1977–2025 matches frozen snapshot baseline **16,218** and old fixed-sett spatial **15,521** exactly. The above 159 should be treated as **candidate additions to the spatial likelihood** after a reviewed, explicit model eligibility rule; no SQL view, underlying source capture, original location, snapshot, migration or fit was modified. Reusable read-only audit: `sql/audit/WECS_V12_Blank_Sett_Location_Trap_Evidence_20261110.sql`. Documentation is not a claim that all 159 trapping *micropositions* were directly surveyed: XY denotes agreed **sett reference points**.


### Approved spatial model-input rule and deferred unmapped-sett records — 10 November 2026

**Investigator decision (APPROVED):** Accept **all 159** of the original named-sett `TRAP` observations with `SETT_ASSOCIATION_PROVISIONAL` and blank ancillary `capture_location_text` as **provisional fixed-sett spatial observations**, using their already agreed canonical sett XY. All 159 were source-audited in the current database (110 original `moc=TRAP`, 49 original `moc=NULL` but curated `TRAP` supported by weight and blood sampling). A blank secondary location field must not override the named sett and credible trapping evidence. The XY is the canonical sett reference point, **not an independently surveyed trap microposition**. Preserve original location text, capture methods, sett ID, location quality and underlying source classifications unchanged.

**Implement in model-specific preparation, not a silent rewrite of research/analysis:** `scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R` defines the V12 fixed-sett observation eligibility and explicitly labels `EXPLICIT_SETT_POINT_PROVISIONAL` versus `APPROVED_NAMED_SETT_BLANK_LOCATION`. The established 6 November snapshot must return **15,521 + 159 = 15,680** before proceeding; mismatched counts fail closed to prevent this shortcut from being applied to new or different cohorts without source verification. The V11R2 reconciliation script now uses this same derived rule; its previous 15,521 and 1,931 mapped-cohort-tattoo comparison was under the superseded restrictive rule and must be rerun before drawing conclusions.

**Deferred, not rejected:** The **304** qualifying live captures explicitly marked `SETT` but with no accepted known canonical XY remain live encounters without a fixed-sett spatial detection point until future field-team coordinate evidence is added. This comprises 301 `UNRESOLVED` and 3 `SETT_ASSOCIATION_ONLY`. When approved XY become available, re-extract a newly versioned Supabase snapshot and re-run spatial eligibility/QA; **do not rewrite the existing frozen snapshot, fabricate coordinates, or assume these records have zero trapping effort**. Distinct explicit non-sett conflict records (52) remain withheld from the fixed-sett spatial likelihood.

**Provenance limitation:** The 6 November snapshot contains curated encounter type but not source `moc`; consequently its 159 additional entries have `v12_original_method_evidence=MOC_MIXED_NOT_IN_FROZEN_SNAPSHOT`, not fabricated per-record source-method labels. The 110/49 subdivision was verified against live source captures; the next extraction/update should preserve original method to permit explicit source-MOC sensitivity while keeping the already-approved 159 eligible. These are scientific *observation-likelihood eligibility* decisions, not changes to database source locations or social-group residency.


### 10 November 2026 — K051 Bown Hill Farm garage encounter coordinates (APPLIED)

**User-provided new grid reference:** `SO 82442 01956` for the **Bown Hill Farm** garage where tattoo K051 was found alive on 27 October 1999, capture_id **8810**. Parsed full British National Grid E**382442**, N**201956** (five easting and five northing digits: nominal 1 m grid cell, **not proof of positional accuracy of a specific garage or animal**). Original Access capture text: `FOUND IN GARAGE AT BOWN HILL FARM. TWELVE YEAR OLD BADGER, FIRST CAUGHT AT LISTERS SOCIAL GROUP.` Original `recorded_sett_name='LISTERS'`, `capture_location_text='BUILDING'`, source `os_ref IS NULL`. The accepted coordinates are for the **separate building/locality live encounter**, **not** canonical LISTERS sett E383444 N201738.

**Database operation applied and verified:** one capture-specific row inserted into `research.capture_grid_coordinate_decisions`, preserving `original_grid_reference=NULL` (user-supplied grid was not present in Access), `source_easting=383444`, `source_northing=201738` (former association proxy), `corrected_easting=382442`, `corrected_northing=201956`, decision_status `CORRECTED`, clear investigator provenance, and `map_review_status=PENDING_REVIEW` (grid accepted from investigator, not independent on-map/indoor verification). The live `analysis.encounters_clean_v1` now returns `encounter_type=FOUND_ALIVE`, `location_type=BUILDING`, `location_quality=GRID_REFERENCE_CORRECTED_PROVISIONAL`, E382442/N201956 for capture 8810. Original raw location and LISTERS canonical sett remain unchanged, as do the original K051 trapping captures at LISTERS and unmapped WHITINGS BEECH.

**Model input decision:** K051 1999 is **positive live encounter with independently supplied approximate non-sett XY** and should be used as geographically informative observation in the next V12 movement model, **not** a fixed-sett detector/trap event. This requires a separately designed non-sett spatial observation component; the existing `v12_fixed_sett_spatial` filter intentionally will not classify `BUILDING` as an active fixed trap. Re-extract a new immutable Supabase snapshot before the next fit to include the newly corrected coordinates; the pre-change snapshot `v12_20261106T103144Z_1079872` remains unchanged. Do not equate nominal grid digits with surveyed coordinate accuracy.

**Audit trail:** `sql/migrations/20261110_K051_Bown_Hill_Farm_8810_capture_coordinate_APPLIED.sql` stores exact directly executed, guarded one-row SQL (not registered in Supabase's migration history); `sql/audit/WECS_K051_Bown_Hill_Farm_8810_20261110.sql` is the read-only regression test.
