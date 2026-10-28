# Woodchester database — what we've got so far and how to use it

I've tried to keep the database as close as possible to the original capture and laboratory records, rather than cleaning away things we may want to revisit. The original values are still there, and where I've standardised something I've generally added a separate `_clean` field. The current structure has **18 research tables** and **five analysis views**, with the original Access imports preserved separately and the source files in `ingest`.

This is a guide to what's available and how to get at it, rather than a claim that the data are all final. **Cleaning is still in progress, particularly for sett names, sett coordinates and social groups, and we haven't signed off a frozen V1 dataset.** I've written out the actual changes and decisions in the [Cleaning Audit](V1_CLEANING_AUDIT.md), and the current plan for reviewing setts and social groups is in the [sett and social-group reconciliation notes](V1_SETT_AND_SOCIAL_GROUP_RECONCILIATION_STATUS.md).


> **Current status (28 October 2026):** The uploaded 168-entry XY list is now the starting point for **proposed** sett names and aliases; the existing `research.setts` IDs and `analysis` views have **not** yet been rebuilt around it. References below to 'V1', 'released' views or 'canonical' names describe the current working database, not a completed or approved release. Please check the [Cleaning Audit](V1_CLEANING_AUDIT.md) before treating any cleaned field as definitive.

## Getting into the database from R

For most day-to-day work, I'd start with the five `analysis` views. They're a convenient way to get to the data without having to join lots of tables yourself. If you need the original fields or want to understand how tables link together, use the `research` tables. The examples below should work from **any R project folder**, provided you've been given access. The views are still working versions where they depend on unfinished cleaning.

### 1. Connecting

If you haven't already got the packages installed, run this once:

```r
install.packages(c("DBI", "RPostgres", "dplyr", "dbplyr", "readr"))
```

The connection details are below. Please don't put usernames or passwords directly into scripts or GitHub. The easiest approach in RStudio is to keep them in a local `.Renviron` file.

**Setting up `.Renviron` (once per computer or R project):**

1. In RStudio create a plain-text file called `.Renviron` in the project root.
2. Add the following two lines, replacing the blank values with your credentials:

```text
BADGER_DB_USER=
BADGER_DB_PASSWORD=
```

3. Save the file and restart your R session so R reads the values. Add `.Renviron` to your project's `.gitignore` and never share or commit the credentials. Check that they are present with `nzchar(Sys.getenv("BADGER_DB_USER"))` and `nzchar(Sys.getenv("BADGER_DB_PASSWORD"))`; both should return `TRUE`. These checks do not print the credentials.

After restarting R, you can connect from **any R project folder** like this:

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "db.klpvihubzlyzubyyubtw.supabase.co",
  port = 5432,
  dbname = "postgres",
  user = Sys.getenv("BADGER_DB_USER"),
  password = Sys.getenv("BADGER_DB_PASSWORD"),
  sslmode = "require"
)

DBI::dbIsValid(con)  # TRUE if connected
```

### 2. Seeing what's available

```r
# All released analysis views and research tables
DBI::dbGetQuery(con, "SELECT table_schema, table_name
 FROM information_schema.tables
 WHERE table_schema IN ('analysis', 'research')
 ORDER BY table_schema, table_name")

# See field names without downloading the data
DBI::dbListFields(con, DBI::Id(schema = "research", table = "captures"))
```

The five main `analysis` views are `capture_history_v1`, `capture_location_v1`, `diagnostic_results`, `capture_infection_probabilities` and `sett_inventory_v1`. These names refer to the current working views, not a signed-off final release.

### 3. Looking at capture records

Using `tbl()` lets you filter and organise the data while it's still on the database server. The results aren't actually pulled into R until you call `collect()`, which is useful when working with a lot of records.

```r
captures <- dplyr::tbl(
  con, dbplyr::in_schema("analysis", "capture_history_v1")
)

# Only capture events from 2000 onward; exclude post-mortem records
recent_live <- captures %>%
  filter(capture_date >= as.Date("2000-01-01"), is_pm == FALSE) %>%
  select(capture_id, tattoo, capture_date, sett_id, sett_name) %>%
  collect()

```

### 4. Other useful analysis views

```r
diagnostics <- tbl(con, in_schema("analysis", "diagnostic_results"))
locations <- tbl(con, in_schema("analysis", "capture_location_v1"))
infection <- tbl(con, in_schema("analysis", "capture_infection_probabilities"))
sett_inventory <- tbl(con, in_schema("analysis", "sett_inventory_v1"))

# Diagnostic row counts by assay family
assay_counts <- diagnostics %>%
  count(test_family, name = "n_records") %>%
  collect()

# Read the small mapped-sett inventory
sett_summary <- sett_inventory %>% collect()
```

### 5. Looking directly at the research tables

The `research` tables are useful when I want to look at the recorded fields alongside any cleaned versions, or check how things have been linked. For example:

```r
raw_capture_fields <- tbl(con, in_schema("research", "captures"))
setts <- tbl(con, in_schema("research", "setts"))

# Keep all captures; append the matching canonical sett's coordinates
captures_with_sett_xy <- raw_capture_fields %>%
  left_join(
    setts %>% select(sett_id, sett_name, easting, northing),
    by = "sett_id"
  ) %>%
  select(capture_id, sett_id, sett_name, easting, northing,
         condition, condition_clean, eartags, eartags_clean) %>%
  collect()
```

The original `condition` and `eartags` entries are still there. The corresponding `_clean` columns are just the standardised versions described in the Cleaning Audit.

### 6. Working with the sett tables

```r
setts <- tbl(con, in_schema("research", "setts"))
undated_links <- tbl(con, in_schema("research", "sett_social_group_links"))
annual_polygons <- tbl(
  con, in_schema("research", "sett_annual_territory_matches")
)

# All recorded undated sett/group associations
links_df <- undated_links %>% collect()

# All annual sett/polygon rows for 2020, including overlaps
annual_2020 <- annual_polygons %>%
  filter(year == 2020L) %>%
  collect()

# Count available annual rows: returns zero until the generated CSV is uploaded
annual_polygons %>% summarise(n_rows = n()) %>% collect()
```

The undated `sett_social_group_links` table is distinct from the **year-specific polygon overlay** in `sett_annual_territory_matches`. Multiple polygon rows per sett-year are intentional; don't assume this is a one-row-per-sett-year lookup.

### 7. Exporting results and disconnecting

```r
readr::write_csv(recent_live, "captures_2000_onward.csv")
DBI::dbDisconnect(con)
```

For larger tables, it's much better to filter or summarise on the server **before** using `collect()`. All of these examples are read-only — they won't change anything in the database.

---

## Research tables — what each one contains

| Table | What it contains |
|---|---|
| `brock_tests` | Brock assay records. |
| `captures` | One row per live capture or PM record. Sampling, collar and assessments are included. |
| `cultures` | Culture tests and related typing information. |
| `disease_statuses` | Original disease status codes used by captures. |
| `dpp_tests` | DPP tests and visual lines. |
| `elisa_tests` | ELISA diagnostic results. |
| `ifn_gamma_elisa` | IFN-gamma assay records and replicate readings. |
| `individuals` | One badger per row, identified by tattoo. |
| `infection_probabilities` | Additional model-derived infection probabilities. |
| `infection_quarterly_probabilities` | Additional model-derived quarterly infection probabilities. |
| `sett_annual_territory_matches` | Year-by-year sett point matches to territory polygons, including overlaps and unmatched points (not evidence of individual residency). |
| `sett_social_group_links` | Undated sett–social group associations (173 links for 160 setts); these do not establish annual occupancy. |
| `setts` | Canonical sett names. |
| `social_group_supergroup_history` | Group/supergroup links over time. |
| `social_groups` | Canonical social group names. |
| `stat_pak_tests` | Stat-Pak tests. |
| `supergroups` | Canonical supergroup names. |
| `wounds` | Wounds recorded at captures; multiple rows can belong to one capture. |

## Analysis views — the easier starting point

| View | What it provides |
|---|---|
| `capture_history_v1` | Joined capture histories; one row per event. |
| `capture_infection_probabilities` | Comparison of model-derived infection probabilities at captures. |
| `capture_location_v1` | Recorded and interpreted capture locations, distinguishing true setts from PM grid squares. |
| `diagnostic_results` | All tests in one long-format output. |
| `sett_inventory_v1` | Sett coordinates and capture counts. |

## Column guide — what the fields mean

The following is the full list of currently released columns. I've described each as far as the original information supports.

### `analysis.capture_history_v1`

Joined capture histories; one row per event.

| Column | Meaning |
|---|---|
| `capture_id` | Unique capture or PM event identifier. |
| `tattoo` | Scientific badger identifier. |
| `elect_tag` | Electronic identification tag recorded for this badger. |
| `sex` | Original recorded sex. |
| `age_first_capture` | Original recorded age class at first capture. |
| `year_first_capture` | Year when individual first appeared in capture dataset. |
| `capture_date` | Date of the capture/PM encounter. |
| `capture_year` | Calendar year extracted from capture_date. |
| `capture_quarter` | Calendar quarter (1–4) extracted from capture_date. |
| `capture_occasion` | Formatted quarter-year capture occasion. |
| `is_pm` | Whether the event is a post-mortem record. |
| `moc` | Method or circumstances of encounter. Examples in the records include TRAP, RTA (road traffic accident), FOUND DEAD, SNARE, SHOT, NET and REMOVAL. |
| `recorded_sett_name` | Original recorded location/sett wording; may not describe a sett. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `normalized_sett_name` | Derived/cleaned value; exact rule in the audit. |
| `recorded_social_group_name` | Original recorded social group wording. |
| `recorded_social_group_id` | Canonical identifier matching recorded social group. |
| `normalized_social_group_name` | Derived/cleaned value; exact rule in the audit. |
| `recorded_supergroup_name` | Original recorded supergroup text. |
| `capture_location_text` | Original location description/category. |
| `os_ref` | Original OS reference. |
| `location_cleaning_note` | Notes explaining a change or uncertainty in the event's location interpretation. |
| `disease_status_id` | Record or lookup ID used for joins. |
| `disease_status` | Recorded disease classification. The lookup contains Negative, Exposed, Excretor and Super excretor. |
| `weight` | Recorded body mass; measurement unit has not been confirmed in the available metadata. |
| `body_length` | Measured value; original protocol determines units and coding. |
| `temperature` | Recorded body temperature; expected temperature measurement but unit not confirmed in metadata. |
| `toothwear` | Recorded tooth-wear assessment; numerical/category scale not independently established. |
| `neck_diameter` | Recorded neck diameter; measurement unit not established in available metadata. |
| `condition` | Original body-condition categories: FAIR, GOOD, POOR, V.GOOD, VERY GOOD. Values retained as recorded. |
| `condition_clean` | Standardised condition: FAIR, GOOD, POOR, VERY GOOD; V.GOOD and VERY GOOD both become VERY GOOD; missing stays missing. |
| `reproductive_status` | Observed reproductive condition/status recorded at capture; retain source descriptions as entered. |
| `testes` | Recorded testes/reproductive assessment. |
| `eartags` | Original ear-tag field. Observed: BOTH, LEFT, NEITHER, NONE, NOT TAGGED, NOT TAGûGED, REMOVED, RETAGGEûD, RIGHT. |
| `eartags_clean` | Standardised tag categories: BOTH, LEFT, RIGHT, NONE, REMOVED, RETAGGED. NEITHER/NONE/NOT TAGGED/NOT TAGûGED become NONE, RETAGGEûD becomes RETAGGED; REMOVED remains distinct. Missing stays missing. |
| `retag` | Indication or description of replacement/re-tagging. |
| `transmitter` | Capture record transmitter description or identifier. |
| `tx_number` | Transmitter number recorded at capture. |
| `pm_status` | Post-mortem status category recorded for this event. |
| `pm_cause` | Recorded circumstances or cause associated with a post-mortem event. |
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
| `sampler` | Person recorded as collecting samples for the capture. |
| `blood_sampler` | Measured value; original protocol determines units and coding. |
| `recorder` | Person recorded as completing the capture record. |
| `sampling_notes` | Original sampling-related free-text comments. |
| `health_monitoring` | Recorded health monitoring notes associated with capture. |
| `ho_supervisor` | Recorded Home Office supervisor field. |
| `severity_assessment` | Recorded severity/welfare assessment made at the capture. |
| `severity_initials` | Initials of person associated with severity assessment. |
| `release_assessment` | Recorded fitness or welfare assessment relating to release. |
| `release_initials` | Initials associated with release assessment. |
| `adverse_effects` | Recorded adverse effects associated with handling or procedures. |
| `adverse_effect_sampler` | Person associated with adverse-effects recording. |
| `adverse_effect_comment` | Free-text description of any adverse effects. |
| `collar_action_taken` | Boolean flag. |
| `collar_action_taker` | Person who took the collar-related action. |
| `collar_checked_by` | Person who inspected the collar. |
| `collar_scratch_no` | Recorded identifying scratch number on the collar. |
| `collar_transmitter` | Transmitter information recorded during collar check (distinct from general capture transmitter field). |
| `best_tune` | Recorded best-tuning information for collar/radio equipment; scale not established. |
| `collar_impact_assessment` | Recorded welfare/impact assessment relating to the collar. |
| `ppm` | Recorded collar-related PPM field; abbreviation is not defined in available source material. |
| `comment` | Recorded capture comment. |
| `sett_name` | Canonical, cleaned name identifying a sett. |
| `location_type` | Derived distinction between sett, PM grid recovery and unresolved location. |
| `location_easting` | OS easting; may be the southwest grid-square corner of a PM reference. |
| `location_northing` | OS northing; may be the southwest grid-square corner of a PM reference. |
| `location_crs` | Coordinate reference system assigned to the spatial value, normally British National Grid (EPSG:27700) where identified. |
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
| `diagnostic_fixed_prevalence` | Infection probability from diagnostic-only model using fixed prevalence assumptions. |
| `diagnostic_annual_prevalence` | Infection probability from diagnostic-only model with annually varying prevalence. |
| `diagnostic_adjusted_annual` | Infection probability from adjusted annual-prevalence diagnostic model. |
| `all_tests_fixed` | Infection probability from all-tests model with fixed assumptions. |
| `all_tests_inferred` | Infection probability from all-tests model with inferred parameters. |
| `culture_only_fixed` | Infection probability from culture-only model with fixed assumptions. |
### `analysis.capture_location_v1`

Recorded and interpreted capture locations, distinguishing true setts from PM grid squares.

| Column | Meaning |
|---|---|
| `capture_id` | Unique capture or PM event identifier. |
| `tattoo` | Scientific badger identifier. |
| `capture_date` | Date of the capture/PM encounter. |
| `is_pm` | Whether the event is a post-mortem record. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `original_recorded_sett_name` | Original recorded sett/location text in the capture form; not necessarily a confirmed sett. |
| `canonical_sett_name` | Canonical named sett matched to the record; NULL if no confirmed match. |
| `location_class` | More detailed location classification. |
| `location_display_category` | Human-readable category assigned to the recorded location. |
| `capture_location_text` | Original location description/category. |
| `os_ref` | Original OS reference. |
| `reference_source` | Original field or source from which the location/grid reference was interpreted. |
| `so_grid_six_digits` | Numeric six-figure grid portion parsed in the SO National Grid square; original text preserved elsewhere. |
| `newly_parsed_grid_reference` | Grid-reference text extracted by the later PM location parser. |
| `grid_sw_easting` | Easting of southwest corner of the grid square, not a precise recovery point. |
| `grid_sw_northing` | Northing of southwest corner of the grid square, not a precise recovery point. |
| `newly_parsed_cell_width_m` | Width of interpreted grid cell in metres; indicates positional precision. |
| `accompanying_location_description` | Any descriptive location text recorded alongside a grid reference. |
| `positional_precision_note` | Explanation of positional precision or limitations of the parsed reference. |
| `spatial_interpretation` | Explanatory assessment of whether the event is a known sett, grid cell or unresolved location. |
### `analysis.diagnostic_results`

All tests in one long-format output.

| Column | Meaning |
|---|---|
| `source_table` | Original research table that supplied this diagnostic observation. |
| `source_record_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `tattoo` | Scientific badger identifier. |
| `capture_date` | Date of the capture/PM encounter. |
| `is_pm` | Whether the event is a post-mortem record. |
| `test_family` | Diagnostic assay family, for example culture, ELISA, IFN-gamma, DPP, Brock or Stat-Pak. |
| `test_type` | Recorded variant/type of the assay. |
| `sample_type` | Recorded specimen category used for the assay. |
| `result` | Original diagnostic result value for the applicable assay. |
| `result_code` | Original diagnostic result code, interpreted in the context of the assay family. |
| `visual_line_1` | First recorded DPP test-line designation. |
| `visual_line_1_result` | Recorded result category for the first DPP visual line. |
| `optical_density_1` | Optical-density measurement associated with first line; dimensionless absorbance measurement. |
| `visual_line_2` | Second recorded DPP test-line designation. |
| `visual_line_2_result` | Recorded result category for the second DPP visual line. |
| `optical_density_2` | Optical-density measurement associated with second line; dimensionless absorbance measurement. |
| `reference_value` | Measured value; original protocol determines units and coding. |
| `mean_od` | Measured value; original protocol determines units and coding. |
| `blot_cf` | Original ELISA blot_cf assay field; exact code interpretation not established. |
| `blotson` | Original ELISA blotson assay field; exact code interpretation not established. |
| `brock_test_od` | Measured value; original protocol determines units and coding. |
| `no_clotted` | Flag recording absence/failure of a clotted specimen. |
| `afno` | Recorded AF number/identifier associated with culture sample; full abbreviation unconfirmed. |
| `lesions` | Recorded lesion observations associated with the sample/post-mortem. |
| `abscesses` | Recorded abscess observations. |
| `spoligo` | Recorded spoligotype result for isolate. |
| `spolprime` | Recorded spoligotype-associated field from source. |
| `wgs_clade` | Whole-genome sequencing clade assignment. |
| `plate_number` | Assay plate identification number. |
| `experiment_date` | Date, quarter, year or provenance timestamp. |
| `nil_value` | Measured value; original protocol determines units and coding. |
| `avian_ppd_value` | Measured value; original protocol determines units and coding. |
| `bovine_ppd_value` | Measured value; original protocol determines units and coding. |
| `pwm_value` | Measured value; original protocol determines units and coding. |
| `bovine_minus_nil` | Derived bovine-PPD response minus nil control. |
| `avian_minus_nil` | Derived avian-PPD response minus nil control. |
| `bovine_minus_avian` | Derived bovine-PPD response minus avian-PPD response. |
| `pwm_1` | First or second replicate for PWM assay control/stimulus; scale from assay import. |
| `pwm_2` | First or second replicate for PWM assay control/stimulus; scale from assay import. |
| `ppd_a_1` | First or second replicate for PPD_A assay control/stimulus; scale from assay import. |
| `ppd_a_2` | First or second replicate for PPD_A assay control/stimulus; scale from assay import. |
| `ppd_b_1` | First or second replicate for PPD_B assay control/stimulus; scale from assay import. |
| `ppd_b_2` | First or second replicate for PPD_B assay control/stimulus; scale from assay import. |
| `nil_1` | First or second replicate for NIL assay control/stimulus; scale from assay import. |
| `nil_2` | First or second replicate for NIL assay control/stimulus; scale from assay import. |
| `retest` | Recorded retest indicator or note. |
| `test_failed` | Recorded test-failure flag/comment. |
| `test_info` | Original free-text assay interpretation/information. |
| `blood_quality` | Measured value; original protocol determines units and coding. |
| `qc_note` | Quality-control comment on the assay. |
| `comments` | Original free-text note related to . |
### `analysis.sett_inventory_v1`

Sett coordinates and capture counts.

| Column | Meaning |
|---|---|
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `canonical_sett_name` | Canonical named sett matched to the record; NULL if no confirmed match. |
| `capture_count` | Number of capture in this record or summary. |
| `n_pm_records` | Number of pm records in this record or summary. |
| `first_capture_date` | Date, quarter, year or provenance timestamp. |
| `last_capture_date` | Date, quarter, year or provenance timestamp. |
| `easting` | British National Grid easting of mapped location (metres). |
| `northing` | British National Grid northing of mapped location (metres). |
| `coordinate_system` | Spatial coordinate reference system attached to the source measurement. |
| `accuracy_m` | Stated spatial accuracy of the source observation in metres. |
| `coordinate_source` | Provenance of selected coordinate. |
| `coordinate_status` | Whether a sett has a mapped, approved or unresolved coordinate. |
### `research.brock_tests`

Brock assay records.

| Column | Meaning |
|---|---|
| `brock_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `brock_test_od` | Measured value; original protocol determines units and coding. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `no_clotted` | Flag recording absence/failure of a clotted specimen. |
| `comments` | Original free-text note related to . |
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
| `moc` | Method or circumstances of encounter. Examples in the records include TRAP, RTA (road traffic accident), FOUND DEAD, SNARE, SHOT, NET and REMOVAL. |
| `capture_location_text` | Original location description/category. |
| `weight` | Recorded body mass; measurement unit has not been confirmed in the available metadata. |
| `body_length` | Measured value; original protocol determines units and coding. |
| `temperature` | Recorded body temperature; expected temperature measurement but unit not confirmed in metadata. |
| `toothwear` | Recorded tooth-wear assessment; numerical/category scale not independently established. |
| `neck_diameter` | Recorded neck diameter; measurement unit not established in available metadata. |
| `condition` | Recorded body-condition category: GOOD, FAIR, POOR, VERY GOOD, or V.GOOD (a spelling variant of very good). |
| `reproductive_status` | Observed reproductive condition/status recorded at capture; retain source descriptions as entered. |
| `testes` | Recorded testes/reproductive assessment. |
| `eartags` | Ear-tag information recorded at the encounter. |
| `retag` | Indication or description of replacement/re-tagging. |
| `transmitter` | Capture record transmitter description or identifier. |
| `tx_number` | Transmitter number recorded at capture. |
| `pm_status` | Post-mortem status category recorded for this event. |
| `pm_cause` | Recorded circumstances or cause associated with a post-mortem event. |
| `comment` | Recorded capture comment. |
| `created_at` | Database row creation timestamp. |
| `location_cleaning_note` | Notes explaining a change or uncertainty in the event's location interpretation. |
| `disease_status_id` | Record or lookup ID used for joins. |
| `os_ref` | Original OS reference. |
| `sett_name_clean` | Confirmed sett name from sett_id; NULL for unidentified setts. |
| `social_group_name_clean` | Standardised label for the recorded group; not a residence assignment. |
| `sampler` | Person recorded as collecting samples for the capture. |
| `recorder` | Person recorded as completing the capture record. |
| `blood_taken_time` | Measured value; original protocol determines units and coding. |
| `red_tube_volume` | Measured value; original protocol determines units and coding. |
| `green_tube_volume` | Measured value; original protocol determines units and coding. |
| `purple_tube_volume` | Measured value; original protocol determines units and coding. |
| `peach_tube_volume` | Measured value; original protocol determines units and coding. |
| `hair_sample_taken` | Boolean flag. |
| `fur_clip_taken` | Boolean flag. |
| `whisker_sample_taken` | Boolean flag. |
| `sampling_notes` | Original sampling-related free-text comments. |
| `blood_sampler` | Measured value; original protocol determines units and coding. |
| `yellow_tube_volume` | Measured value; original protocol determines units and coding. |
| `blood_sample_taken` | Measured value; original protocol determines units and coding. |
| `health_monitoring` | Recorded health monitoring notes associated with capture. |
| `ho_supervisor` | Recorded Home Office supervisor field. |
| `severity_assessment` | Recorded severity/welfare assessment made at the capture. |
| `severity_initials` | Initials of person associated with severity assessment. |
| `release_assessment` | Recorded fitness or welfare assessment relating to release. |
| `release_initials` | Initials associated with release assessment. |
| `adverse_effects` | Recorded adverse effects associated with handling or procedures. |
| `adverse_effect_sampler` | Person associated with adverse-effects recording. |
| `adverse_effect_comment` | Free-text description of any adverse effects. |
| `collar_action_taken` | Boolean flag. |
| `collar_action_taker` | Person who took the collar-related action. |
| `collar_checked_by` | Person who inspected the collar. |
| `collar_scratch_no` | Recorded identifying scratch number on the collar. |
| `collar_transmitter` | Transmitter information recorded during collar check (distinct from general capture transmitter field). |
| `best_tune` | Recorded best-tuning information for collar/radio equipment; scale not established. |
| `collar_impact_assessment` | Recorded welfare/impact assessment relating to the collar. |
| `ppm` | Recorded collar-related PPM field; abbreviation is not defined in available source material. |
### `research.cultures`

Culture tests and related typing information.

| Column | Meaning |
|---|---|
| `culture_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `sample_type` | Recorded specimen category used for the assay. |
| `afno` | Recorded AF number/identifier associated with culture sample; full abbreviation unconfirmed. |
| `culture_result` | Recorded culture test outcome; distinguish laboratory growth result from modelled infection status. |
| `lesions` | Recorded lesion observations associated with the sample/post-mortem. |
| `abscesses` | Recorded abscess observations. |
| `spoligo` | Recorded spoligotype result for isolate. |
| `spolprime` | Recorded spoligotype-associated field from source. |
| `wgs_clade` | Whole-genome sequencing clade assignment. |
| `sampler_1` | First/second test-line or assay replicate measurement as indicated by column name. |
| `sampler_2` | First/second test-line or assay replicate measurement as indicated by column name. |
| `comments` | Original free-text note related to . |
| `created_at` | Database row creation timestamp. |
### `research.disease_statuses`

Original disease status codes used by captures.

| Column | Meaning |
|---|---|
| `disease_status_id` | Record or lookup ID used for joins. |
| `disease_status` | Recorded disease classification. The lookup contains Negative, Exposed, Excretor and Super excretor. |
### `research.dpp_tests`

DPP tests and visual lines.

| Column | Meaning |
|---|---|
| `dpp_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `comments` | Original free-text note related to . |
| `created_at` | Database row creation timestamp. |
| `test_type` | Recorded variant/type of the assay. |
| `sample_type` | Recorded specimen category used for the assay. |
| `visual_line_1` | First recorded DPP test-line designation. |
| `optical_density_1` | Optical-density measurement associated with first line; dimensionless absorbance measurement. |
| `visual_line_2` | Second recorded DPP test-line designation. |
| `optical_density_2` | Optical-density measurement associated with second line; dimensionless absorbance measurement. |
| `source_raw_row_id` | Record or lookup ID used for joins. |
| `visual_line_1_result` | Recorded result category for the first DPP visual line. |
| `visual_line_2_result` | Recorded result category for the second DPP visual line. |
### `research.elisa_tests`

ELISA diagnostic results.

| Column | Meaning |
|---|---|
| `elisa_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `elisa_type` | Recorded elisa type field; the available records do not establish a more precise definition. |
| `reference` | Recorded reference field; the available records do not establish a more precise definition. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `mean_od` | Measured value; original protocol determines units and coding. |
| `blot_cf` | Original ELISA blot_cf assay field; exact code interpretation not established. |
| `blotson` | Original ELISA blotson assay field; exact code interpretation not established. |
| `comments` | Original free-text note related to . |
| `created_at` | Database row creation timestamp. |
### `research.ifn_gamma_elisa`

IFN-gamma assay records and replicate readings.

| Column | Meaning |
|---|---|
| `ifn_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `plate_number` | Assay plate identification number. |
| `experiment_date` | Date, quarter, year or provenance timestamp. |
| `import_filename` | Recorded import filename field; the available records do not establish a more precise definition. |
| `imported_at` | Date/time data were imported. |
| `blood_quality` | Measured value; original protocol determines units and coding. |
| `nil_value` | Measured value; original protocol determines units and coding. |
| `avian_ppd_value` | Measured value; original protocol determines units and coding. |
| `bovine_ppd_value` | Measured value; original protocol determines units and coding. |
| `pwm_value` | Measured value; original protocol determines units and coding. |
| `bovine_minus_nil` | Derived bovine-PPD response minus nil control. |
| `avian_minus_nil` | Derived avian-PPD response minus nil control. |
| `bovine_minus_avian` | Derived bovine-PPD response minus avian-PPD response. |
| `test_info` | Original free-text assay interpretation/information. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `comments` | Original free-text note related to . |
| `created_at` | Database row creation timestamp. |
| `pwm_1` | First or second replicate for PWM assay control/stimulus; scale from assay import. |
| `pwm_2` | First or second replicate for PWM assay control/stimulus; scale from assay import. |
| `ppd_a_1` | First or second replicate for PPD_A assay control/stimulus; scale from assay import. |
| `ppd_a_2` | First or second replicate for PPD_A assay control/stimulus; scale from assay import. |
| `ppd_b_1` | First or second replicate for PPD_B assay control/stimulus; scale from assay import. |
| `ppd_b_2` | First or second replicate for PPD_B assay control/stimulus; scale from assay import. |
| `nil_1` | First or second replicate for NIL assay control/stimulus; scale from assay import. |
| `nil_2` | First or second replicate for NIL assay control/stimulus; scale from assay import. |
| `retest` | Recorded retest indicator or note. |
| `test_failed` | Recorded test-failure flag/comment. |
| `capture_datetime` | Date, quarter, year or provenance timestamp. |
| `wellstage_96_pwm_1` | Plate-stage recorded value for pwm 1; verify assay scale before numerical comparison. |
| `wellstage_96_pwm_2` | Plate-stage recorded value for pwm 2; verify assay scale before numerical comparison. |
| `wellstage_96_ppda_1` | Plate-stage recorded value for ppda 1; verify assay scale before numerical comparison. |
| `wellstage_96_ppda_2` | Plate-stage recorded value for ppda 2; verify assay scale before numerical comparison. |
| `wellstage_96_ppdb_1` | Plate-stage recorded value for ppdb 1; verify assay scale before numerical comparison. |
| `wellstage_96_ppdb_2` | Plate-stage recorded value for ppdb 2; verify assay scale before numerical comparison. |
| `wellstage_96_nil_1` | Plate-stage recorded value for nil 1; verify assay scale before numerical comparison. |
| `wellstage_96_nil_2` | Plate-stage recorded value for nil 2; verify assay scale before numerical comparison. |
| `qc_note` | Quality-control comment on the assay. |
### `research.individuals`

One badger per row, identified by tattoo.

| Column | Meaning |
|---|---|
| `individual_id` | Internal key used to join badger records. |
| `tattoo` | Scientific badger identifier. |
| `elect_tag` | Electronic identification tag recorded for this badger. |
| `age_first_capture` | Original recorded age class at first capture. |
| `year_first_capture` | Year when individual first appeared in capture dataset. |
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


Location evidence, coordinates and their sources.

| Column | Meaning |
|---|---|
| `evidence_id` | Record or lookup ID used for joins. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `easting` | British National Grid easting of mapped location (metres). |
| `northing` | British National Grid northing of mapped location (metres). |
| `coordinate_system` | Spatial coordinate reference system attached to the source measurement. |
| `accuracy_m` | Stated spatial accuracy of the source observation in metres. |
| `evidence_type` | Recorded evidence type field; the available records do not establish a more precise definition. |
| `source_reference` | Recorded source reference supporting the coordinate or dataset. |
| `observed_on` | Date associated with the source coordinate observation. |
| `recorded_by` | Original recorded value, preserved. |
| `review_status` | Review decision/status assigned to this spatial evidence item. |
| `reviewed_by` | Recorded reviewed by field; the available records do not establish a more precise definition. |
| `reviewed_at` | Date, quarter, year or provenance timestamp. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.sett_social_group_links`

I retain the 173 undated lookup associations between setts and social groups; a sett can appear against more than one group. These records cannot be used as a time series of social-group occupancy.

| Column | Meaning |
|---|---|
| `sett_social_group_id` | Unique identifier for a recorded sett–group association. |
| `sett_id` | Links to `research.setts.sett_id`. |
| `social_group_id` | Links to `research.social_groups.social_group_id`. |
| `valid_from` | NULL in all 173 records: no known start date. |
| `valid_to` | NULL in all 173 records: no known end date. |
| `notes` | Source/interpretation of this undated link. |



Recorded sett/group links over time; more than one link can exist.

| Column | Meaning |
|---|---|
| `sett_social_group_id` | Record or lookup ID used for joins. |
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `social_group_id` | Record or lookup ID used for joins. |
| `valid_from` | Recorded valid from field; the available records do not establish a more precise definition. |
| `valid_to` | Recorded valid to field; the available records do not establish a more precise definition. |
| `notes` | Historical notes or provenance in the context of this table. |
### `research.setts`
| `easting` | British National Grid easting (metres) from the supplied named-sett coordinate file. |
| `northing` | British National Grid northing (metres) from the same source. |
| `coordinate_system` | EPSG:27700 where coordinates are available. |
| `accuracy_m` | Positional accuracy estimate; NULL because no measured accuracy was supplied. |
| `coordinate_source` | Filename and named-sett label used to link the coordinate. |
| `coordinate_observed_on` | Observation date; NULL because none was supplied. |


Canonical sett names.

| Column | Meaning |
|---|---|
| `sett_id` | Linked canonical sett ID, NULL when unresolved. |
| `sett_name` | Canonical, cleaned name identifying a sett. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.social_group_supergroup_history`

Group/supergroup links over time.

| Column | Meaning |
|---|---|
| `social_group_supergroup_id` | Record or lookup ID used for joins. |
| `social_group_id` | Record or lookup ID used for joins. |
| `supergroup_id` | Record or lookup ID used for joins. |
| `valid_from` | Recorded valid from field; the available records do not establish a more precise definition. |
| `valid_to` | Recorded valid to field; the available records do not establish a more precise definition. |
| `notes` | Historical notes or provenance in the context of this table. |
### `research.social_groups`

Canonical social group names.

| Column | Meaning |
|---|---|
| `social_group_id` | Record or lookup ID used for joins. |
| `social_group_name` | Name or label of social group. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.stat_pak_tests`

Stat-Pak tests.

| Column | Meaning |
|---|---|
| `stat_pak_test_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `test_result` | Original coded assay outcome; meaning depends on test. |
| `comments` | Original free-text note related to . |
| `created_at` | Database row creation timestamp. |
| `stat_pak_id` | Record or lookup ID used for joins. |
### `research.supergroups`

Canonical supergroup names.

| Column | Meaning |
|---|---|
| `supergroup_id` | Record or lookup ID used for joins. |
| `supergroup_name` | Name or label of supergroup. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |
### `research.wounds`

Wounds recorded at captures; multiple rows can belong to one capture.

| Column | Meaning |
|---|---|
| `wound_id` | Record or lookup ID used for joins. |
| `capture_id` | Unique capture or PM event identifier. |
| `wound_area` | Recorded wound area field; the available records do not establish a more precise definition. |
| `wound_amount` | Recorded wound amount field; the available records do not establish a more precise definition. |
| `wound_age` | Recorded wound age field; the available records do not establish a more precise definition. |
| `wound_size` | Recorded wound size field; the available records do not establish a more precise definition. |
| `wound_type` | Recorded wound type field; the available records do not establish a more precise definition. |
| `notes` | Historical notes or provenance in the context of this table. |
| `created_at` | Database row creation timestamp. |

## A few things to bear in mind when using these data

I use `tattoo` as the scientific individual identifier and `capture_id` for capture events. A canonical sett name is only filled when the recorded location has been matched to a sett. PM grid references are recovery-location approximations, not known sett locations. Infection probabilities are model outputs rather than diagnostic observations.



## Recorded codes and categories (current working snapshot)

I extracted the distinct, non-missing values directly from the research tables on 12 October 2026. Each list below is **exhaustive for the current stored non-NULL values** where it is shown, not a claim that the source system could never contain other values. Values are presented exactly as stored, including inconsistent spellings. NULL is not a category; it indicates missing information. A code is not automatically biologically meaningful just because it appears in the source. For identifiers, staff initials, continuous measurements and free text I explain the field rather than listing every record. Two fields are entirely empty: `research.dpp_tests.test_result` (0 of 3,316 records populated) and `research.wounds.wound_type` (0 of 1,636 populated); they therefore have **no observed entries** to list.

### `research.brock_tests`

| Field | All observed non-missing values |
|---|---|
| `no_clotted` (2) | `false`, `true` |
| `test_result` (2) | `N`, `P` |

### `research.captures`

| Field | All observed non-missing values |
|---|---|
| `adverse_effects` (2) | `No`, `Yes` |
| `blood_sample_taken` (2) | `false`, `true` |
| `collar_action_taken` (2) | `No`, `Yes` |
| `collar_impact_assessment` (4) | `0`, `1`, `2`, `N/A` |
| `collar_transmitter` (8) | `FIT`, `FITTED`, `LOST`, `PRES`, `PRESENT`, `REMOVAL`, `REPL`, `REPLACED` |
| `condition` (5) | `FAIR`, `GOOD`, `POOR`, `V.GOOD`, `VERY GOOD` |
| `eartags` (9) | `BOTH`, `LEFT`, `NEITHER`, `NONE`, `NOT TAGGED`, `NOT TAGûGED`, `REMOVED`, `RETAGGEûD`, `RIGHT` |
| `fur_clip_taken` (2) | `false`, `true` |
| `hair_sample_taken` (2) | `false`, `true` |
| `health_monitoring` (3) | `N`, `No`, `Yes` |
| `is_pm` (2) | `false`, `true` |
| `moc` (14) | `DART GUN`, `DEAD SN/TR`, `FOUND DEAD`, `FOUND EXT`, `NET`, `ON ROAD`, `PUT DOWN`, `REMOVAL`, `REPORTED BY MEMBER OF THE PUBLIC`, `RTA`, `SHOT`, `SHOT (GP)`, `SNARE`, `TRAP` |
| `pm_status` (2) | `NOT POSSIBLE`, `POSSIBLE` |
| `ppm` (28) | `.9006`, `1 PER SEC`, `200`, `39`, `40`, `42`, `45`, `46`, `47`, `48`, `49`, `50`, `52`, `54`, `55`, `56`, `58`, `60`, `60 per min`, `61`, `62`, `65`, `68`, `69`, `70`, `71`, `72`, `HIGH` |
| `release_assessment` (2) | `Death`, `Fit` |
| `reproductive_status` (13) | `LACT P Y`, `LACTATING`, `LACTATING SOMETIME`, `LACTATING THIS YEAR`, `MID`, `N LACT T Y`, `NEVER LACTATING`, `NPTD`, `PREGNANT`, `TESTES ASCENDED`, `TESTES DESCENDED`, `UNKNOWN`, `UNSURE` |
| `retag` (17) | `01`, `10`, `B81`, `B90`, `B97`, `G16`, `G40`, `K75`, `R01`, `R64`, `R95`, `W3`, `W90`, `W91`, `W92`, `W99`, `Y42` |
| `severity_assessment` (1) | `Mild` |
| `testes` (3) | `ASCENDED`, `DESCENDED`, `MID` |
| `transmitter` (8) | `FIT`, `FITTED`, `LOST`, `PRES`, `PRESENT`, `REMOVAL`, `REPL`, `REPLACED` |
| `whisker_sample_taken` (2) | `false`, `true` |

### `research.cultures`

| Field | All observed non-missing values |
|---|---|
| `abscesses` (6) | `CLOSED`, `HEALED`, `HEALING`, `NOT HEALED`, `OPEN`, `SINUS` |
| `culture_result` (8) | `CONTAMINATED`, `FAILED`, `M.AVIUM`, `M.BOVIS`, `M.OTHER`, `NEGATIVE`, `NOT TESTED`, `PENDING` |
| `lesions` (3) | `NA`, `NVL`, `VL` |
| `sample_type` (46) | `AS`, `BI`, `BODY`, `BWB`, `BWH`, `BWN`, `BWR`, `CARCASE`, `EYE`, `FAECES`, `GUT`, `HEAD`, `JAW`, `KIDNEY`, `KIDNEYS`, `L SUB`, `L SUBM`, `LIMB`, `LIVER`, `LSWAB`, `LUNG`, `LUNG1`, `LYMPH NODE`, `LYMPH NODE 2`, `LYMPH NODE 3`, `LYMPH NODE 4`, `MESENTERIC LYMPH NODE`, `NECK`, `OA`, `OTHER`, `OTHER 1`, `PAW`, `POOLED`, `R SUB`, `R SUBM`, `RUMP`, `SHOULDER`, `SPLEEN`, `STANDARD`, `SW`, `TA`, `TL`, `TO`, `URINE`, `URINE TRAY`, `VE` |
| `spoligo` (12) | `10`, `11`, `15`, `17`, `20`, `21`, `22`, `25`, `9`, `B6-11`, `FAIL`, `RETEST` |
| `spolprime` (1) | `Y` |
| `wgs_clade` (3) | `17:a`, `B6-11`, `NA` |

### `research.disease_statuses`

| Field | All observed non-missing values |
|---|---|
| `disease_status` (4) | `Excretor`, `Exposed`, `Negative`, `Super excretor` |

### `research.dpp_tests`

| Field | All observed non-missing values |
|---|---|
| `sample_type` (5) | `Serum`, `Serum Fresh`, `Serum Frozen`, `WB Field`, `Whole Blood` |
| `test_type` (2) | `Double`, `Single` |
| `visual_line_1` (4) | `N`, `Nx`, `P`, `Px` |
| `visual_line_1_result` (4) | `Negative`, `NegativeX`, `Positive`, `PositiveX` |
| `visual_line_2` (4) | `N`, `Nx`, `P`, `Px` |
| `visual_line_2_result` (4) | `Negative`, `NegativeX`, `Positive`, `PositiveX` |

### `research.elisa_tests`

| Field | All observed non-missing values |
|---|---|
| `elisa_type` (2) | `BELT`, `INDIRECT` |
| `test_result` (7) | `BIT`, `I`, `ITT`, `N`, `NO SERA`, `NO SERUM`, `P` |

### `research.ifn_gamma_elisa`

| Field | All observed non-missing values |
|---|---|
| `blood_quality` (2) | `F`, `P` |
| `retest` (5) | `A OUTLIER`, `B & A`, `B OUTLIER`, `MISSING ODs`, `NIL AVG HIGH` |
| `test_failed` (1) | `NO SAMPLE` |
| `test_info` (1) | `LOW PWM` |
| `test_result` (2) | `Negative`, `Positive` |
| `wellstage_96_nil_1` (3) | `GD`, `IV`, `NS` |
| `wellstage_96_nil_2` (4) | `CL`, `GD`, `IV`, `NS` |
| `wellstage_96_ppda_1` (3) | `GD`, `IV`, `NS` |
| `wellstage_96_ppda_2` (3) | `GD`, `IV`, `NS` |
| `wellstage_96_ppdb_1` (3) | `GD`, `IV`, `NS` |
| `wellstage_96_ppdb_2` (4) | `CL`, `GD`, `IV`, `NS` |
| `wellstage_96_pwm_1` (4) | `CL`, `GD`, `IV`, `NS` |
| `wellstage_96_pwm_2` (4) | `CL`, `GD`, `IV`, `NS` |

### `research.individuals`

| Field | All observed non-missing values |
|---|---|
| `age_first_capture` (3) | `ADULT`, `CUB`, `YEARLING` |
| `age_first_capture_clean` (4) | `ADULT`, `CUB`, `UNKNOWN`, `YEARLING` |
| `sex` (3) | `FEMALE`, `MALE`, `UNKNOWN` |
| `sex_clean` (3) | `FEMALE`, `MALE`, `UNKNOWN` |

### `research.infection_probabilities`

| Field | All observed non-missing values |
|---|---|
| `model_run` (1) | `infection_probabilities_2026_08_27` |
| `model_variant` (6) | `all_tests_fixed`, `all_tests_inferred`, `culture_only_fixed`, `diagnostic_adjusted_annual`, `diagnostic_annual_prevalence`, `diagnostic_fixed_prevalence` |
| `quarter` (4) | `1`, `2`, `3`, `4` |
| `source_file` (1) | `p_infected_per_capture.csv` |

### `research.infection_quarterly_probabilities`

| Field | All observed non-missing values |
|---|---|
| `model_run` (1) | `infection_probabilities_2026_08_27` |
| `model_variant` (1) | `all_tests_inferred` |
| `quarter` (4) | `1`, `2`, `3`, `4` |
| `source_file` (1) | `p_infected_grid_all_tests_inferred.csv` |



| Field | All observed non-missing values |
|---|---|
| `coordinate_system` (1) | `EPSG:27700` |
| `evidence_type` (1) | `OTHER` |
| `review_status` (1) | `APPROVED` |
| `reviewed_by` (1) | `Dave Hudson` |

### `research.stat_pak_tests`

| Field | All observed non-missing values |
|---|---|
| `test_result` (3) | `Negative`, `No Clotted Sample`, `Positive` |

### `research.wounds`

| Field | All observed non-missing values |
|---|---|
| `wound_age` (8) | `HEALED (scar)`, `HEALED (SCAR)`, `NEW`, `OLD`, `OPEN (fresh)`, `OPEN (FRESH)`, `OPEN (old)`, `OPEN (OLD)` |
| `wound_amount` (5) | `FEW (2 or 3)`, `FEW (2 TO 3)`, `LOTS (>3)`, `NOT RECORDED`, `ONE` |
| `wound_area` (6) | `BODY`, `HEAD`, `INGUI.`, `LIMB`, `NECK`, `RUMP` |
| `wound_size` (7) | `LGE (gaping)`, `LGE (GAPING)`, `MED (gash)`, `MED (GASH)`, `NOT RECORDED`, `SML (puncture)`, `SML (PUNCTURE)` |

### How I'm treating the recorded codes

I use **observed value** deliberately: `condition` contains both `VERY GOOD` and `V.GOOD`, and `eartags` contains source encoding artefacts (`NOT TAGûGED`, `RETAGGEûD`). For DPP and Stat-Pak codes, I use the definitions given in the companion cleaning audit. Recording a code is not evidence that all code variants are valid in every assay/time period.

### Fields that don't have a short list of codes

Free-text fields, staff/operator initials, animal or sample identifiers, arbitrary source references and numeric measurements are not treated as categorical. In particular `pm_cause` is narrative, while `best_tune`, `tx_number`, `plate_number`, `afno` and `elect_tag` refer to values/identifiers rather than defined category sets.


## Cleaning notes: body condition and ear tags

I've kept the original `condition` and `eartags` fields and added generated `condition_clean` and `eartags_clean` columns so the standardised values update automatically. In `condition_clean`, `V.GOOD` → `VERY GOOD`; `FAIR`, `GOOD` and `POOR` are unchanged. The complete cleaned condition distribution is FAIR **4,789**, GOOD **8,809**, POOR **1,281**, VERY GOOD **1,768** (including 700 originally marked V.GOOD), and missing **939**.

For `eartags_clean`, `NEITHER`, `NONE`, `NOT TAGGED`, and the encoding variant `NOT TAGûGED` all become `NONE`. `RETAGGEûD` becomes `RETAGGED`. `BOTH`, `LEFT`, `RIGHT`, and `REMOVED` remain distinct. The original field is still available if a researcher needs the exact entry. Missing entries stay missing.


## Cleaning notes: collar entries and ELISA results

I've kept the original values and made a separate cleaned column where there are obvious alternative labels for the same thing.

| Field | Standardised value and observed count |
|---|---|
| `research.captures.collar_transmitter_clean` | FITTED (668: FIT/FITTED), PRESENT (355: PRES/PRESENT), REPLACED (193: REPL/REPLACED), REMOVAL (127), LOST (29), NULL (16,214) |
| `research.elisa_tests.test_result_clean` | N (13,297), P (1,554), I (163), ITT (15), BIT (2), NO SERUM (99: NO SERA/NO SERUM), NULL (32) |

These are tidied-up labels, not extra observations. I haven't assumed that `I`, `ITT` and `BIT` mean the same diagnostic outcome.


## Setts, social groups and annual territories

I've kept three different pieces of information separate, because they tell us different things:

- `research.setts`: 176 named setts, including coordinates for 159; the remaining 17 have no mapped coordinate.
- `research.sett_social_group_links`: all 173 recorded but **undated** associations between 160 setts and social groups. Multiple associations for a sett are retained.
- `research.sett_annual_territory_matches`: the annual sett-point overlay against the 1977–2025 territory polygons. Multiple rows for a sett-year are retained where polygons overlap. No biological or movement inference is made by these records.

### `research.sett_annual_territory_matches`

| Column | Meaning |
|---|---|
| `match_id` | Unique ID for this match record. |
| `year` | Territory polygon snapshot year (1977–2025). |
| `sett_id` | Sett identifier linked to `research.setts`. |
| `polygon_id` | Feature identifier within the annual shapefile, NULL for unmatched setts. |
| `territory_name` | Recorded name of the matching territory polygon; not automatically equated with a canonical social-group ID. |
| `match_status` | One of the five spatial classifications explained below. |
| `polygon_source` | Source annual shapefile, for example `territories_1985.shp`. |
| `coordinate_source` | Source of the mapped sett coordinate. |
| `created_at` | Database row creation timestamp. |

The possible `match_status` values are `ONE_POLYGON` (inside one polygon), `MULTIPLE_POLYGONS` (intersects multiple polygons), `ON_BOUNDARY` (on a polygon boundary), `OUTSIDE_ALL` (mapped but outside all polygons) and `NO_COORDINATE` (sett has no mapped location). A sett can have more than one row per year; the original polygon labels and all matches are retained.

### Accessing the sett tables in R

Using the `con` connection defined earlier in this document:

```r
library(dplyr)
library(dbplyr)

setts <- tbl(con, in_schema("research", "setts"))
links <- tbl(con, in_schema("research", "sett_social_group_links"))
annual <- tbl(con, in_schema("research", "sett_annual_territory_matches"))

sett_locations <- setts %>%
  select(sett_id, sett_name, easting, northing, coordinate_source) %>%
  collect()

undated_group_links <- links %>% collect()

polygon_matches_2020 <- annual %>%
  filter(year == 2020L) %>%
  collect()
```

The undated links haven't been replaced by the annual polygon matches. Both are useful to keep, but neither should automatically be interpreted as proof that a badger was resident in a particular group or that it dispersed.


## Tattoo case clarification: 040l and 040L (28 October 2026)

I've confirmed that four original Access culture entries use `040l` (lowercase final L), whereas the other matching entries use `040L`. The **leading zero is part of the identifier**. The four cultures already link to the existing research individual `040L`, so there's no second badger to merge and no need to overwrite the original Access records. For original-text matching I treat the case variants as `040L` using `upper(trim(tattoo))`. The full evidence, original row IDs and check script are documented in the [Cleaning Audit](V1_CLEANING_AUDIT.md).
