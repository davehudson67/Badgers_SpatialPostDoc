# Woodchester badger database — V1 cleaning audit

I've recorded the decisions and SQL behind the cleaned version here. Original Access imports are kept in `access_raw`, so the historical entries can always be checked. My V1 release column guide is in [V1 Release Notes](V1_RELEASE_NOTES.md).

## What I've changed

| Area | Rule or decision | SQL reference |
|---|---|---|
| Individual identity | I use tattoo as the scientific identifier and retain internal individual IDs solely for joins. | Versioned original migration scripts in `sql/migrations/` |
| Sex | `sex_clean`: trim and uppercase MALE/FEMALE; other or blank values become UNKNOWN. I retain `sex`. | `woodchester_v1_minimal_clean_columns_20261026.sql` |
| Age at first capture | `age_first_capture_clean`: CUB/YEARLING/ADULT; other or blank become UNKNOWN. I retain the original field. | Same migration |
| Sett names | `sett_name_clean` follows a confirmed canonical sett ID. Unresolved entries stay NULL; the original recorded string is retained. | `woodchester_v1_minimal_clean_columns_20261026.sql`; `woodchester_v1_clean_names_trigger_20261026.sql` |
| Social groups | `social_group_name_clean` is the canonical label associated with the **recorded** social group ID, not proof of residence. | Same clean-name migrations |
| Coordinates | I retain original sett evidence and distinguish mapped sett locations from provisional PM grid-square corners, with their sources. | V1 coordinate matching and PM grid migrations in `sql/migrations/` |
| Captures | I brought the sampling, welfare assessment and collar fields into `research.captures`. | `woodchester_v1_consolidate_capture_fields_20261026.sql`; `woodchester_v1_retire_split_capture_detail_tables_20261026.sql` |
| Analysis views | I have created five useful views. Legacy/internal SQL views were moved to `internal_v1` so their definitions and dependencies remain available. | `woodchester_v1_minimal_public_schemas_20261026.sql` |
| Code lists | I removed three tiny standalone tables after recording their entries here; I retained actual assay measurements and historical many-to-one/many-to-many relationships. | `woodchester_v1_remove_redundant_code_lookups_20261026.sql` |

## Field-by-field cleaning rules (human-readable specification)

This section is intended to be read without opening the SQL files. It describes **rules already implemented in the working database**, not a claim that every record is correct. The migration scripts remain the executable authority if the prose and implementation differ. Original values must be retained, and any disagreement needs to be documented rather than silently corrected. **Sett and social-group reconciliation is still in progress.**

### A. Individual identification

**Original evidence:** tattoo and the imported individual identifier. **Working rule:** I use the tattoo as the scientific individual identifier and retain the internal numeric individual ID as the relational key for database joins. Case variants (for example `40l` and `40L`) need consistent comparison without losing the original recorded string. **What I do not assume:** similar-looking marks or missing tattoos are not automatically evidence for joining two animals. Duplicate, absent or ambiguous tattoos need explicit review. The original-to-working identifiers must remain traceable. **Status:** working identifier convention; unusual records require audit. **Implementation:** original import/identity migrations in `sql/migrations/` (specific historical implementation to be confirmed from the migration sequence).

### B. Sex and age at first capture

**Sex:** `sex_clean` trims surrounding whitespace and standardises recognised `MALE` and `FEMALE` values to uppercase. Other values, including blanks, are assigned `UNKNOWN` in the cleaned field. I retain the original `sex` field, so `UNKNOWN` does not mean an original observer explicitly recorded that category.

**Age at first capture:** `age_first_capture_clean` uses `CUB`, `YEARLING` or `ADULT` for the recognised categories; other or blank values become `UNKNOWN`. The source age-at-entry category is retained. These are recorded categories, not reconstructed ages derived from dates or body measurements.

**Implementation:** `woodchester_v1_minimal_clean_columns_20261026.sql`.

### C. Body condition categories

I retain `research.captures.condition` unchanged and add `condition_clean`. The only documented consolidation is **`V.GOOD` → `VERY GOOD`**. Existing `VERY GOOD` stays `VERY GOOD`; `FAIR`, `GOOD` and `POOR` remain separate categories. Missing values stay **NULL**, not `UNKNOWN` and not `POOR`. At the recorded snapshot there were 700 `V.GOOD` entries and 1,068 originally entered `VERY GOOD` entries; the other recorded categories were `FAIR` 4,789, `GOOD` 8,809 and `POOR` 1,281, with 939 missing. The mapping is purely a label standardisation, not a change to an animal's assessed condition.

**Implementation:** `woodchester_v1_standardise_condition_and_eartags_20261026.sql`.

### D. Ear-tag categories and transcription errors

The source field `research.captures.eartags` is retained. In `eartags_clean`, `NEITHER`, `NONE`, `NOT TAGGED` and the imported encoding variant `NOT TAGûGED` are standardised to **`NONE`**. `RETAGGEûD` becomes **`RETAGGED`**. `BOTH`, `LEFT`, `RIGHT` and **`REMOVED`** remain distinct. In particular, I do **not** treat `REMOVED` as the same observation as `NONE`. The source text is preserved so that a disputed encoding repair can be revisited.

**Implementation:** `woodchester_v1_standardise_condition_and_eartags_20261026.sql`.

### E. Collar/transmitter descriptions

The original `research.captures.collar_transmitter` remains unchanged. In the generated `collar_transmitter_clean` field:

| Original recorded variants | Cleaned category | Interpretation |
|---|---|---|
| `FIT`, `FITTED` | `FITTED` | Same recorded label in cleaned form |
| `PRES`, `PRESENT` | `PRESENT` | Same recorded label in cleaned form |
| `REPL`, `REPLACED` | `REPLACED` | Same recorded label in cleaned form |
| `REMOVAL` | `REMOVAL` | **Not** combined with `REPLACED` |
| `LOST` | `LOST` | Separate category |
| Missing | NULL | No invented observation |

The documented snapshot is `FITTED` 668, `PRESENT` 355, `REPLACED` 193, `REMOVAL` 127, `LOST` 29 and NULL 16,214. This is not an inference about how long a collar was worn.

**Implementation:** `v1_collar_label_normalisation_20261026.sql`.

### F. ELISA test-result labels

I retain `research.elisa_tests.test_result` and introduce `test_result_clean`. `NO SERA` and `NO SERUM` are recorded as **`NO SERUM`** in the cleaned field. Other codes, including `N`, `P`, `I`, `ITT` and `BIT`, remain unchanged; these are not automatically recoded into a positive/negative biological outcome. The documented snapshot is `N` 13,297, `P` 1,554, `I` 163, `ITT` 15, `BIT` 2, `NO SERUM` 99, and NULL 32.

**Implementation:** `v1_elisa_result_label_normalisation_20261026.sql`.

### G. DPP and Stat-Pak recorded categories

These values were originally stored in small code-lookup tables and are now explicitly documented rather than retained in three separate small lookup tables. **This is a structural change, not an experimental recoding of diagnostic results.** DPP sample types remain `Serum Fresh`, `WB Field`, `Whole Blood` and `Serum Frozen`. DPP visual lines retain `N` (Negative), `Nx` (NegativeX), `P` (Positive), and `Px` (PositiveX); I have **not interpreted the X qualifier**. Stat-Pak codes remain `N` (Negative), `P` (Positive) and `C` (No Clotted Sample). I have not treated `C` as a negative test.

**Implementation:** `woodchester_v1_remove_redundant_code_lookups_20261026.sql`. Other assay measurements and relationships are retained.

### H. Capture records, sampling, welfare and collar fields

Sampling information, welfare assessments and collar-related fields from previously separate one-to-one tables were consolidated into **`research.captures`**. This was a change in table organisation: it was **not** intended to combine repeated capture events, erase historical observations or replace any original recorded value. Before retiring redundant split tables, the migration checked the one-to-one capture IDs and checked field equality for sampling time, collar transmitter and adverse effects. The documented validation result was **17,586 records with 17,586 unique capture IDs**.

**Implementation:** `woodchester_v1_consolidate_capture_fields_20261026.sql` and `woodchester_v1_retire_split_capture_detail_tables_20261026.sql`.

### I. Recorded setts, canonical names and other locations — provisional

This is the most important **unfinished** element of the cleaning. The imported `recorded_sett_name` is an observation from the original capture data, not proof that a value corresponds to a known sett.

**Previously implemented working rule:** `research.captures.sett_name_clean` takes the name of the currently assigned `research.setts.sett_id` where that link is present. Unresolved names remain NULL in that field, with the recorded string preserved. The read-only `analysis.capture_sett_location_standardised_v1` view instead presents an uppercase alphanumeric `sett_clean` based on that **existing** link, or literal **`OTHER`** where no sett ID is linked. `other_location_info` keeps the original location text, falling back to the descriptive location or OS reference where necessary.

**New proposed rule, NOT YET APPLIED:** start from the **168 entries in the uploaded XY sett coordinate inventory**, use the XY-source naming as the preferred spelling (with punctuation/spaces stripped in `sett_clean`), and maintain one approved list of historical aliases for each confirmed sett. Examples are `CLIFF.FACE` → `CLIFFFACE` (historical `CLIFF`), `GULLY` (historical `GULLEY`), `ELEVEN.ROW` → `ELEVENROW` (historical `ELEVENTH ROW`), and `STONEY.TRACK` → `STONEYTRACK` (historical `STONY TRACK`). These proposed name equivalences are **not yet approved biological identity merges**. The 176 working `research.setts` records, existing IDs and linked capture counts remain intact. Names absent from the XY file are retained for review rather than silently deleted, and entries including `PEN.(NEEDS.RENAME)` and `STREAM.(NEEDS.NEW.NAME)` need clarification. `OTHER` must not mean that a location has no useful geographic information.

**Implementation of existing rules:** `woodchester_v1_minimal_clean_columns_20261026.sql`, `woodchester_v1_clean_names_trigger_20261026.sql` and migrations defining `analysis.capture_sett_location_standardised_v1`. **Proposed policy (not implemented):** `V1_SETT_AND_SOCIAL_GROUP_RECONCILIATION_STATUS.md`.

### J. Social-group names and residency — provisional

The existing `social_group_name_clean` uses the currently assigned **recorded social-group ID** to display its canonical label. It does **not** prove that the animal was resident in that group at that time. The original group-name observation must remain accessible. I will agree the social-group naming list and aliases **separately from the sett list**. Identical text in a sett name and a social-group name does not establish that they are interchangeable, and polygon territory labels are not automatically social-group IDs.

The table `research.sett_social_group_history` was renamed `research.sett_social_group_links`. The **173 existing sett–group links covering 160 setts** were kept, but lack validity dates: they are **undated lookup associations**, not evidence of annual occupancy.

**Implementation:** `woodchester_v1_minimal_clean_columns_20261026.sql`, `woodchester_v1_clean_names_trigger_20261026.sql`, `v1_consolidate_sett_coordinates_and_rename_undated_links_20261026.sql`. **Final canonical social-group assignments remain under review.**

### K. Sett coordinates and spatial precision — provisional

The historical XY source is recorded in **British National Grid, EPSG:27700**. An earlier name-based audit matched 159 coordinate pairs to 176 working `research.setts` records, leaving 17 without a match. The 159 XY pairs were consolidated onto the sett records, with source-file and matching-name provenance. **These 159 earlier matches are not equivalent to a signed-off final XY-primary catalogue**; the matching rules and possible identity conflicts are under review.

For captures associated with mapped setts, the working standardised view exposes the matched sett-point coordinates. For sufficiently supported post-mortem OS grid references, the view may instead expose the **south-west corner of the grid square**, with `coordinate_basis='GRID_SQUARE_SOUTHWEST_CORNER'` and `grid_cell_width_m`. A six-figure grid reference locates a **100 m cell**, not an exact point. Any recorded point must retain its basis and precision. For unsupported or ambiguous locations, coordinates remain missing rather than guessed from nearby social groups or polygons. Capture `os_ref` and descriptive text are retained.

**Implementation:** `v1_consolidate_sett_coordinates_and_rename_undated_links_20261026.sql` and V1 location/PM-grid migrations. **Definitive spatial name–point mapping remains under review.**

### L. Annual social-group territory overlays (calculation, not recoding)

The R workflow overlays the then-mapped sett points against **49 annual social-group territory shapefiles (1977–2025)**, using EPSG:27700. The result records all intersections, including multiple overlapping polygons, boundary matches and points outside polygons, without forcing a unique group in ambiguous cases. The recorded snapshot is **9,140 output rows representing 8,624 sett-year combinations**, because a sett-year can have multiple matches. Polygon labels are **not** treated as canonical social groups, and a polygon overlap is **not** evidence that a particular badger was resident there. The recorded output was imported into `research.sett_annual_territory_matches`; source files were not altered.

**Implementation:** `scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R`, `v1_annual_sett_polygon_crosswalk_20261026.sql`, `v1_annual_sett_crosswalk_readonly_grants_20261026.sql`.

### M. Derived access views and data release

The `analysis` views give researchers consistent read-only access; they are not replacements for the original capture and laboratory records. Some earlier/internal SQL views were retained under `internal_v1` rather than destroyed. The current standardised capture/sett view has **17,586 rows**, one for each capture, but its existing `sett_clean` labels pre-date our newly proposed XY-primary naming policy. Treat the data as **working/provisional**, not as a frozen signed-off dataset. A future release must include exact source snapshots, approved name/coordinate dictionaries, a reproducible migration, validation checks and a release date or version identifier.

**Implementation:** `woodchester_v1_minimal_public_schemas_20261026.sql` and the versioned migrations defining the analysis views.

### Matters not yet established as fully audited cleaning rules

I do **not** currently claim a completed or validated policy for resolving every tattoo ambiguity, every `recorded_sett_name` / sett-ID conflict, historical outlier classification, missing or contradictory OS references, time-varying social-group residence, or biological interpretation of ambiguous diagnostic codes. These remain review tasks. Any additional cleaning elsewhere in the modelling scripts must be catalogued separately before calling this an exhaustive audit of **all transformations used in published analyses**.

---

## Historical code lists now documented instead of stored as tables

**DPP sample types:** Serum Fresh; WB Field; Whole Blood; Serum Frozen.

**DPP visual line results:** N = Negative; Nx = NegativeX; P = Positive; Px = PositiveX. I haven't inferred a biological interpretation of the 'X' qualifier.

**Stat-Pak results:** N = Negative (display order 1); P = Positive (2); C = No Clotted Sample (3).

## Checks

I checked that `research.captures` and the retained combined capture view have 17,586 distinct capture IDs. The previous sampling, assessment and collar data had unique capture IDs and were copied into the main capture table before removing the split copies. Checks found no differences in sampling time, collar transmitter and adverse-effects fields.


For full executable details I use the SQL migrations rather than duplicating code in this narrative. They also preserve the intermediate rules and corrections behind V1.



## Condition and ear-tag categories

I preserve the recorded `condition` and `eartags` columns and use generated cleaned fields for unambiguous variants. In `condition_clean`, V.GOOD → VERY GOOD (700 records), alongside 1,068 original VERY GOOD records. Other categories are FAIR (4,789), GOOD (8,809), POOR (1,281); missing remains NULL (939). In `eartags_clean`, NEITHER, NONE, NOT TAGGED and the encoding variant NOT TAGûGED → NONE; RETAGGEûD → RETAGGED; BOTH, LEFT, RIGHT and REMOVED remain separate. I don't equate REMOVED with NONE. Source values are unchanged. SQL: `sql/migrations/woodchester_v1_standardise_condition_and_eartags_20261026.sql`.


## Collar and ELISA label standardisation

I added `research.captures.collar_transmitter_clean` as a generated field: FIT/FITTED → FITTED; PRES/PRESENT → PRESENT; REPL/REPLACED → REPLACED. REMOVAL and LOST remain separate. The cleaned distribution is FITTED 668, PRESENT 355, REPLACED 193, REMOVAL 127, LOST 29 and NULL 16,214. The original field is unchanged.

I added `research.elisa_tests.test_result_clean` as a generated field: NO SERA/NO SERUM → NO SERUM. All other recorded codes, including I, ITT and BIT, remain unaltered; no clinical interpretation is inferred. Counts: N 13,297, P 1,554, I 163, ITT 15, BIT 2, NO SERUM 99, NULL 32.

SQL: `sql/migrations/v1_collar_label_normalisation_20261026.sql` and `sql/migrations/v1_elisa_result_label_normalisation_20261026.sql`.


## Fixed sett coordinates and undated group links

I moved the 159 approved British National Grid coordinate pairs from the former one-row-per-sett evidence table into `research.setts`, retaining easting, northing, EPSG:27700 and the source-file/sett-name reference. There are 176 setts in total; 17 have no matching coordinate. The supplied coordinate source has no observation dates or stated accuracy estimates, so these remain NULL. I rebuilt the dependent coordinate inventory and approved-coordinate views, checked that both still return 176 and 159 rows respectively, then removed the redundant coordinate table.

I renamed `research.sett_social_group_history` to `research.sett_social_group_links`. All 173 sett–group links remain (160 unique setts); none has a `valid_from` or `valid_to` date. These are undated lookup associations, not historical occupancy observations.

A distinct **annual point-in-polygon** result is the appropriate next dataset: for each year, compare the mapped sett point with that year's social-group territory polygons, keep exact polygon source/year and all matches, and explicitly flag points outside every polygon, on boundaries or in overlaps. Do not silently force a single SG in ambiguous cases. The annual polygon inputs are not yet present as queryable tables in Supabase, so no year-specific membership has been generated here.

SQL: `sql/migrations/v1_consolidate_sett_coordinates_and_rename_undated_links_20261026.sql`.


## Annual sett–territory polygon calculation

I use the 49 annual territory shapefiles (`data/spatial/social_group_boundaries/territories_1977.shp` through `territories_2025.shp`) to overlay the 159 mapped sett points. The script `scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R` reads the fixed coordinates from `research.setts`, transforms shapefiles to British National Grid (EPSG:27700), and calculates the intersection for each of the 176 setts in each year. It retains multiple hits, boundary matches, sett-years outside all territories and sett-years without coordinates. Source polygon filename and its within-year feature index are recorded. Polygon labels are not automatically treated as canonical SG IDs, and matches are not proof of badger residency.

The script writes an all-matches CSV and annual status counts to `outputs/V1_annual_sett_polygon_membership/`. By default this is an audit-only export; `UPLOAD_ANNUAL_CROSSWALK=1` additionally loads `research.sett_annual_territory_matches` in one transaction using a database connection with write permission. Source polygons are unchanged. The calculation has now been run locally, producing 9,140 records covering all 8,624 sett-year combinations; the 9,140 records have since been imported into Supabase. This is a data organisation step only; I do not use the overlaps to infer social-group residency.

SQL: `sql/migrations/v1_annual_sett_polygon_crosswalk_20261026.sql`; `sql/migrations/v1_annual_sett_crosswalk_readonly_grants_20261026.sql`.


## Annual crosswalk: V1 data-loading status

The local polygon overlay succeeded and generated `annual_sett_polygon_all_matches.csv` with **9,140 rows** for **8,624 distinct sett-years** (176 setts × 49 annual files). Multiple polygons produce multiple rows by design. The summary contains 5,614 ONE_POLYGON rows, 988 MULTIPLE_POLYGONS rows, 17 ON_BOUNDARY rows, 1,688 OUTSIDE_ALL rows and 833 NO_COORDINATE rows. These are row counts, not necessarily counts of distinct ambiguous sett-years. There is no interpretation or reassignment in V1. The 9,140 records are present in the Supabase destination table; the generated CSV remains an export of the same calculation. I preserve the 173 undated sett–group links unchanged. The upload is implemented in `scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R` with `UPLOAD_ANNUAL_CROSSWALK=1` and a write-enabled connection.


## V1 capture sett/location standardised access view

A non-destructive, read-only view `analysis.capture_sett_location_standardised_v1` now exposes one row per original capture (17,586 capture IDs). This is a convenience interface, **not** a replacement for `research.captures` or the recorded sett names. No individual capture or PM record has been deleted or collapsed.

- `sett_clean`: uppercase alphanumeric canonical name (spaces and punctuation stripped) for the currently linked `research.setts.sett_id`, or `OTHER` if no sett ID is linked. Existing links are retained provisionally; newly proposed name/identity merges still require approval.
- `other_location_info`: the recorded sett/location text for rows classified `OTHER`, falling back to capture location description or OS reference when the previous field is absent. Original text also remains in `recorded_sett_name`, `capture_location_text` and `os_ref`.
- `location_easting`, `location_northing`: British National Grid coordinates where documented; for mapped setts these refer to the approved sett coordinate; for recognised grid-referenced PM locations these refer to the **southwest corner of a grid square**, not the exact location where the animal was found.
- `coordinate_basis` gives `SETT_POINT`, `GRID_SQUARE_SOUTHWEST_CORNER` or `NO_COORDINATE`; `location_crs` is EPSG:27700 where coordinates are present. `grid_cell_width_m` retains available square-width precision.
- `location_class` retains the previous location interpretation from `analysis.capture_location_v1`.

Verified view cardinality: 17,586 rows / 17,586 unique capture IDs; 1,249 labelled `OTHER`; 16,034 with sett points; 710 with grid-square corner coordinates; and 842 without assigned coordinates. Thus 303 named-sett captures currently lack a mapped sett point despite their existing sett ID. These figures are counts of capture records, not distinct setts.

This is only a consistent **access-layer classification** using the current approved IDs. The final sett alias dictionary and source-independent `sett_clean` rules must still be agreed before V1 sign-off.


## 2026-10-28 — XY-primary sett naming policy and V1 status clarification (documentation only)

**CLEANING IN PROGRESS — NOT APPROVED AS A DEFINITIVE V1 ANALYSIS RELEASE.** The uploaded sett XY inventory, preserved as `ingest.sett_coordinate_source_20261023`, is now the **primary starting point** for reviewing sett names and locations. Original `access_raw.tbl_sett` names and `access_raw.tbl_captures.sett` entries are evidence for aliases, separately named historical setts, and capture-location descriptions; they are not allowed to supersede the XY source-name spelling without review. The 168 XY entries are coordinate-source records, not yet 168 certified distinct biological setts.

I am reviewing the proposed XY-primary sett catalogue and a **separate** social-group name catalogue. Existing named-sett records, aliases, `sett_id` links, aggregate counts and `analysis.capture_sett_location_standardised_v1.sett_clean` remain provisional and reflect **previous** naming/linkage rules; that view is **not** an implementation of the newly proposed XY-primary convention. The earlier 14 alias decisions still represent proposed identity merges/non-merges, but the preferred spelling of a canonical name follows the XY source for the new review. User-reviewed grid references, roads, descriptive places and potential sett entries require verification and must retain their raw strings and location precision. Names absent from the XY inventory remain in a separate review queue, not silently deleted.
