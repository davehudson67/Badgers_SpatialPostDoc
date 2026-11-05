# Woodchester database — MASTER DATA DICTIONARY AND AUDIT

**Live schema snapshot:** 4 November 2026, after grid/identity audit (**56 tables/views; 926 columns**). **Scope:** all current `access_raw`, `research` and `analysis` relations, not guessed old tables. Describes **every live column**. **Database is authoritative**; this inventory must be regenerated after migrations.

## How to use these tables

| Layer | Intended use | Grain |
|---|---|---|
| `access_raw` | Preserve imported Access values: 12 imported tables; **not** all 62 objects in the original Access inventory | Original source table grain |
| `research` | Canonical linked source records and **audited decision tables** | Table-dependent (one animal, capture, wound, test, alias, etc.) |
| `analysis.encounters_clean_v1` | **Recommended spatial/encounter starting point**; one row per original capture/PM record | 17,586 rows, 13 columns, one `capture_id` each |
| `analysis.capture_history_v1` | Source-rich longitudinal capture history | One row per capture/PM record; avoid conflating PM with live capture |
| `analysis.diagnostic_results` | Pooled six diagnostic families | One row per assay/test outcome (possibly multiple per capture) |
| `analysis.mortality_events_review_v1` | One primary record per **recorded** death, excluding curated PM companion; identity/duplicate flags retained | 1,304 death-event rows, **430 without XY**; not yet signed-off survival endpoint |
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
- **`location_quality`:** SETT_POINT_PROVISIONAL:15740; UNRESOLVED:834; GRID_CELL_100M_RECORDED_SO:366; GRID_CELL_100M_PREFIX_UNVERIFIED:187; SETT_ASSOCIATION_PROVISIONAL:190; SETT_COORDINATE_CONFLICT:107; GRID_CELL:65; GRID_REFERENCE_CORRECTED_PROVISIONAL:57; GRID_REFERENCE_AMBIGUOUS_WITHHELD:40; SETT_ASSOCIATION_ONLY:5.
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

One record per intentionally corrected or withheld historical grid point; **57 corrected** and **40 withheld**. No original source data is overwritten.

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

**1,304 rows** (1,300 candidates, **2 ID conflicts**, **2 possible duplicate death reports**), 430 without XY. This view **retains all rows**, attaching a model-inclusion status; it is NOT a signed-off survival-input table.

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

### `analysis.spatial_missing_review_v1` (18 columns, current missing-XY review queue)

**981 rows, one per source capture/PM record with no accepted XY.** This is an organisational QA view, **not** an exclusion list. Dead events remain available without a coordinate. `spatial_review_priority` groups each row into exactly one category: MORTALITY_RECOVERY_LOCATION (331); SETT_XY_FIELD_TEAM (306); NAMED_NON_SETT_SITE (163); ASSOCIATED_SETT_NOT_ACTUAL_SITE (107); ORIGINAL_GRID_VERIFY (39); SOURCE_LOCATION_UNSPECIFIED (26); PM_COMPANION_NO_INDEPENDENT_POINT (9). The WITHHELD decision table has 40 entries; one is grouped under another priority in this mutually exclusive queue.

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
