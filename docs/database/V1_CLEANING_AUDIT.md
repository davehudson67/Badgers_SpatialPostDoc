# Woodchester database — notes on cleaning and changes so far

I've been working through the original Access database and documenting the changes as I go. I want a clear record of what I've changed, why I've changed it and what still needs checking. The original Access data are kept in `access_raw`, so we can always go back and see exactly what was recorded. The SQL migrations are the definitive record of what was run, but this document should explain the decisions without anyone needing to read SQL. There's also a fuller table and column guide in the [V1 Release Notes](V1_RELEASE_NOTES.md).

**This is still a working database, not a signed-off V1 release.** In particular, the sett names, coordinates and social-group assignments are still being reviewed.

## Quick summary of what's been done

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

## The cleaning rules, field by field

I've set out the rules below in plain language so it's possible to see what we've actually done to each field. These are changes already made in the **working** database unless I specifically say they're only proposed. That doesn't mean every record is necessarily correct. Where there's a discrepancy, I'd rather flag it and discuss it than quietly change an original entry. The SQL files remain the definitive reference for exactly what was implemented.

### Individual identification

I'm using the tattoo number as the main identifier for an individual badger. The database still uses an internal numeric ID to link tables together, but that's a technical key rather than the identifier I want researchers to work with. I've also been looking at case differences such as `40l` and `40L`. These need to be handled consistently, while keeping the original entry available.

I don't want to assume that two similar-looking tattoos necessarily belong to the same animal. Missing or ambiguous tattoos still need checking, and we need to be able to trace every working identifier back to its original record.

**Where this is implemented:** the original import and identity migrations in `sql/migrations/`. I still need to identify the precise migration for every historical identifier rule.

### Sex and age at first capture

For **sex**, I've added `sex_clean` to make recognised entries consistent: spaces at either end are removed, and `MALE` and `FEMALE` are written in uppercase. Anything else, including a blank, becomes `UNKNOWN` in the cleaned field. The original `sex` value is still there. In other words, `UNKNOWN` is a cleaning category, not necessarily something the observer wrote down.

For **age at first capture**, I've done much the same thing. Recognised values are `CUB`, `YEARLING` and `ADULT`; other or missing entries become `UNKNOWN` in `age_first_capture_clean`. I'm not estimating ages from body measurements or capture dates here; these are simply cleaned versions of the recorded age categories.

**Implementation:** `woodchester_v1_minimal_clean_columns_20261026.sql`.

### Body condition

The only change I've made to body-condition categories is to treat `V.GOOD` as `VERY GOOD` in `condition_clean`. The original `condition` column is left as it was. `FAIR`, `GOOD` and `POOR` stay separate, and missing entries stay **NULL** — I'm not assigning a condition where none was recorded.

At the time of the check, there were 700 records entered as `V.GOOD` and 1,068 already entered as `VERY GOOD`. The other categories were `FAIR` (4,789), `GOOD` (8,809), `POOR` (1,281) and missing (939). This is just tidying up a label; it doesn't change the observer's assessment.

**Implementation:** `woodchester_v1_standardise_condition_and_eartags_20261026.sql`.

### Ear tags

The ear-tag field contains a few different ways of saying the same thing, as well as some odd characters introduced during importing. In `eartags_clean`, I've grouped `NEITHER`, `NONE`, `NOT TAGGED` and `NOT TAGûGED` under `NONE`. I've also changed `RETAGGEûD` to `RETAGGED` in the cleaned field.

`BOTH`, `LEFT`, `RIGHT` and `REMOVED` remain separate. In particular, **`REMOVED` does not mean `NONE`**, so I haven't merged them. The original text is kept in case we need to revisit any of these interpretations.

**Implementation:** `woodchester_v1_standardise_condition_and_eartags_20261026.sql`.

### Collars and transmitters

For the collar/transmitter entries, I've standardised a few abbreviations in `collar_transmitter_clean`. The original `research.captures.collar_transmitter` column hasn't been changed:

| Original recorded variants | Cleaned category | Interpretation |
|---|---|---|
| `FIT`, `FITTED` | `FITTED` | Same recorded label in cleaned form |
| `PRES`, `PRESENT` | `PRESENT` | Same recorded label in cleaned form |
| `REPL`, `REPLACED` | `REPLACED` | Same recorded label in cleaned form |
| `REMOVAL` | `REMOVAL` | **Not** combined with `REPLACED` |
| `LOST` | `LOST` | Separate category |
| Missing | NULL | No invented observation |

The counts at the time were `FITTED` 668, `PRESENT` 355, `REPLACED` 193, `REMOVAL` 127, `LOST` 29 and missing 16,214. I'm only standardising what was recorded — not trying to reconstruct how long collars were worn.

**Implementation:** `v1_collar_label_normalisation_20261026.sql`.

### ELISA result labels

For ELISA results, I've combined `NO SERA` and `NO SERUM` into `NO SERUM` in a new `test_result_clean` field. Everything else, including `N`, `P`, `I`, `ITT` and `BIT`, has been left as recorded. I don't want to make biological assumptions about unusual codes as part of a simple database tidy-up.

At the time of the check, there were `N` 13,297, `P` 1,554, `I` 163, `ITT` 15, `BIT` 2, `NO SERUM` 99 and missing 32. The original result field is retained.

**Implementation:** `v1_elisa_result_label_normalisation_20261026.sql`.

### DPP and Stat-Pak codes

Some very small lookup tables didn't seem worth keeping as separate tables, so I've recorded their contents here instead. This is a change in how the codes are stored and documented, **not** a change to the test results themselves.

The DPP sample types are `Serum Fresh`, `WB Field`, `Whole Blood` and `Serum Frozen`. The visual-line codes are `N` (Negative), `Nx` (NegativeX), `P` (Positive) and `Px` (PositiveX). I haven't tried to interpret the `X` qualifier.

For Stat-Pak the codes are `N` (Negative), `P` (Positive) and `C` (No Clotted Sample). `C` has **not** been treated as a negative test.

**Implementation:** `woodchester_v1_remove_redundant_code_lookups_20261026.sql`. Other assay measurements and relationships are retained.

### Putting the capture information together

I've brought the sampling, welfare-assessment and collar information together in `research.captures`, rather than keeping several separate one-to-one tables. This should make the data easier to work with. Importantly, this didn't mean combining repeated captures or removing individual capture events.

Before the redundant split tables were retired, the capture IDs were checked and the relevant fields were compared — including sampling time, collar transmitter and adverse effects. The resulting data contained **17,586 records with 17,586 unique capture IDs**.

**Implementation:** `woodchester_v1_consolidate_capture_fields_20261026.sql` and `woodchester_v1_retire_split_capture_detail_tables_20261026.sql`.

### Sett names and other capture locations — still being worked through

This is probably the area where there's still most to sort out. Not everything entered in the original capture `sett` field is necessarily a sett: some entries refer to roads, grid references, outliers or more general descriptions.

**What the database currently does:** `research.captures.sett_name_clean` takes the name of the currently assigned `research.setts.sett_id` where that link is present. Unresolved names remain NULL in that field, with the recorded string preserved. The read-only `analysis.capture_sett_location_standardised_v1` view instead presents an uppercase alphanumeric `sett_clean` based on that **existing** link, or literal **`OTHER`** where no sett ID is linked. `other_location_info` keeps the original location text, falling back to the descriptive location or OS reference where necessary.

**What I'm proposing next (not applied yet):** start from the **168 entries in the uploaded XY sett coordinate inventory**, use the XY-source naming as the preferred spelling (with punctuation/spaces stripped in `sett_clean`), and maintain one approved list of historical aliases for each confirmed sett. Examples are `CLIFF.FACE` → `CLIFFFACE` (historical `CLIFF`), `GULLY` (historical `GULLEY`), `ELEVEN.ROW` → `ELEVENROW` (historical `ELEVENTH ROW`), and `STONEY.TRACK` → `STONEYTRACK` (historical `STONY TRACK`). These proposed name equivalences are **not yet approved biological identity merges**. The 176 working `research.setts` records, existing IDs and linked capture counts remain intact. Names absent from the XY file are retained for review rather than silently deleted, and entries including `PEN.(NEEDS.RENAME)` and `STREAM.(NEEDS.NEW.NAME)` need clarification. `OTHER` must not mean that a location has no useful geographic information.

**Implementation of existing rules:** `woodchester_v1_minimal_clean_columns_20261026.sql`, `woodchester_v1_clean_names_trigger_20261026.sql` and migrations defining `analysis.capture_sett_location_standardised_v1`. **Proposed policy (not implemented):** `V1_SETT_AND_SOCIAL_GROUP_RECONCILIATION_STATUS.md`.

### Social-group names — also still under review

The existing `social_group_name_clean` uses the currently assigned **recorded social-group ID** to display its canonical label. It does **not** prove that the animal was resident in that group at that time. The original group-name observation must remain accessible. I will agree the social-group naming list and aliases **separately from the sett list**. Identical text in a sett name and a social-group name does not establish that they are interchangeable, and polygon territory labels are not automatically social-group IDs.

The table `research.sett_social_group_history` was renamed `research.sett_social_group_links`. The **173 existing sett–group links covering 160 setts** were kept, but lack validity dates: they are **undated lookup associations**, not evidence of annual occupancy.

**Implementation:** `woodchester_v1_minimal_clean_columns_20261026.sql`, `woodchester_v1_clean_names_trigger_20261026.sql`, `v1_consolidate_sett_coordinates_and_rename_undated_links_20261026.sql`. **Final canonical social-group assignments remain under review.**

### Sett coordinates and grid references — still under review

The historical XY source is recorded in **British National Grid, EPSG:27700**. An earlier name-based audit matched 159 coordinate pairs to 176 working `research.setts` records, leaving 17 without a match. The 159 XY pairs were consolidated onto the sett records, with source-file and matching-name provenance. **These 159 earlier matches are not equivalent to a signed-off final XY-primary catalogue**; the matching rules and possible identity conflicts are under review.

For captures associated with mapped setts, the working standardised view exposes the matched sett-point coordinates. For sufficiently supported post-mortem OS grid references, the view may instead expose the **south-west corner of the grid square**, with `coordinate_basis='GRID_SQUARE_SOUTHWEST_CORNER'` and `grid_cell_width_m`. A six-figure grid reference locates a **100 m cell**, not an exact point. Any recorded point must retain its basis and precision. For unsupported or ambiguous locations, coordinates remain missing rather than guessed from nearby social groups or polygons. Capture `os_ref` and descriptive text are retained.

**Implementation:** `v1_consolidate_sett_coordinates_and_rename_undated_links_20261026.sql` and V1 location/PM-grid migrations. **Definitive spatial name–point mapping remains under review.**

### Matching mapped setts to annual group boundaries

The R workflow overlays the then-mapped sett points against **49 annual social-group territory shapefiles (1977–2025)**, using EPSG:27700. The result records all intersections, including multiple overlapping polygons, boundary matches and points outside polygons, without forcing a unique group in ambiguous cases. The recorded snapshot is **9,140 output rows representing 8,624 sett-year combinations**, because a sett-year can have multiple matches. Polygon labels are **not** treated as canonical social groups, and a polygon overlap is **not** evidence that a particular badger was resident there. The recorded output was imported into `research.sett_annual_territory_matches`; source files were not altered.

**Implementation:** `scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R`, `v1_annual_sett_polygon_crosswalk_20261026.sql`, `v1_annual_sett_crosswalk_readonly_grants_20261026.sql`.

### Analysis views and releasing a finished version

The `analysis` views give researchers consistent read-only access; they are not replacements for the original capture and laboratory records. Some earlier/internal SQL views were retained under `internal_v1` rather than destroyed. The current standardised capture/sett view has **17,586 rows**, one for each capture, but its existing `sett_clean` labels pre-date our newly proposed XY-primary naming policy. Treat the data as **working/provisional**, not as a frozen signed-off dataset. A future release must include exact source snapshots, approved name/coordinate dictionaries, a reproducible migration, validation checks and a release date or version identifier.

**Implementation:** `woodchester_v1_minimal_public_schemas_20261026.sql` and the versioned migrations defining the analysis views.

### What still needs checking

There are still quite a few things I don't want to claim we've resolved: ambiguous tattoo entries, mismatches between recorded sett names and sett IDs, outliers, incomplete OS references, social-group membership through time and some of the less clear diagnostic codes. I'd also like to check the cleaning that happens later in the modelling scripts. Until that's done, this is an audit of the database cleaning we've documented, **not yet every transformation used in the analyses**.

---

## Original code lists kept here for reference

**DPP sample types:** Serum Fresh; WB Field; Whole Blood; Serum Frozen.

**DPP visual line results:** N = Negative; Nx = NegativeX; P = Positive; Px = PositiveX. I haven't inferred a biological interpretation of the 'X' qualifier.

**Stat-Pak results:** N = Negative (display order 1); P = Positive (2); C = No Clotted Sample (3).

## Checks I've made

I checked that `research.captures` and the retained combined capture view have 17,586 distinct capture IDs. The previous sampling, assessment and collar data had unique capture IDs and were copied into the main capture table before removing the split copies. Checks found no differences in sampling time, collar transmitter and adverse-effects fields.


For full executable details I use the SQL migrations rather than duplicating code in this narrative. They also preserve the intermediate rules and corrections behind V1.



## Earlier notes: condition and ear tags

I preserve the recorded `condition` and `eartags` columns and use generated cleaned fields for unambiguous variants. In `condition_clean`, V.GOOD → VERY GOOD (700 records), alongside 1,068 original VERY GOOD records. Other categories are FAIR (4,789), GOOD (8,809), POOR (1,281); missing remains NULL (939). In `eartags_clean`, NEITHER, NONE, NOT TAGGED and the encoding variant NOT TAGûGED → NONE; RETAGGEûD → RETAGGED; BOTH, LEFT, RIGHT and REMOVED remain separate. I don't equate REMOVED with NONE. Source values are unchanged. SQL: `sql/migrations/woodchester_v1_standardise_condition_and_eartags_20261026.sql`.


## Earlier notes: collar and ELISA labels

I added `research.captures.collar_transmitter_clean` as a generated field: FIT/FITTED → FITTED; PRES/PRESENT → PRESENT; REPL/REPLACED → REPLACED. REMOVAL and LOST remain separate. The cleaned distribution is FITTED 668, PRESENT 355, REPLACED 193, REMOVAL 127, LOST 29 and NULL 16,214. The original field is unchanged.

I added `research.elisa_tests.test_result_clean` as a generated field: NO SERA/NO SERUM → NO SERUM. All other recorded codes, including I, ITT and BIT, remain unaltered; no clinical interpretation is inferred. Counts: N 13,297, P 1,554, I 163, ITT 15, BIT 2, NO SERUM 99, NULL 32.

SQL: `sql/migrations/v1_collar_label_normalisation_20261026.sql` and `sql/migrations/v1_elisa_result_label_normalisation_20261026.sql`.


## Earlier notes: sett coordinates and group links

I moved the 159 approved British National Grid coordinate pairs from the former one-row-per-sett evidence table into `research.setts`, retaining easting, northing, EPSG:27700 and the source-file/sett-name reference. There are 176 setts in total; 17 have no matching coordinate. The supplied coordinate source has no observation dates or stated accuracy estimates, so these remain NULL. I rebuilt the dependent coordinate inventory and approved-coordinate views, checked that both still return 176 and 159 rows respectively, then removed the redundant coordinate table.

I renamed `research.sett_social_group_history` to `research.sett_social_group_links`. All 173 sett–group links remain (160 unique setts); none has a `valid_from` or `valid_to` date. These are undated lookup associations, not historical occupancy observations.

A distinct **annual point-in-polygon** result is the appropriate next dataset: for each year, compare the mapped sett point with that year's social-group territory polygons, keep exact polygon source/year and all matches, and explicitly flag points outside every polygon, on boundaries or in overlaps. Do not silently force a single SG in ambiguous cases. The annual polygon inputs are not yet present as queryable tables in Supabase, so no year-specific membership has been generated here.

SQL: `sql/migrations/v1_consolidate_sett_coordinates_and_rename_undated_links_20261026.sql`.


## Earlier notes: annual territory overlays

I use the 49 annual territory shapefiles (`data/spatial/social_group_boundaries/territories_1977.shp` through `territories_2025.shp`) to overlay the 159 mapped sett points. The script `scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R` reads the fixed coordinates from `research.setts`, transforms shapefiles to British National Grid (EPSG:27700), and calculates the intersection for each of the 176 setts in each year. It retains multiple hits, boundary matches, sett-years outside all territories and sett-years without coordinates. Source polygon filename and its within-year feature index are recorded. Polygon labels are not automatically treated as canonical SG IDs, and matches are not proof of badger residency.

The script writes an all-matches CSV and annual status counts to `outputs/V1_annual_sett_polygon_membership/`. By default this is an audit-only export; `UPLOAD_ANNUAL_CROSSWALK=1` additionally loads `research.sett_annual_territory_matches` in one transaction using a database connection with write permission. Source polygons are unchanged. The calculation has now been run locally, producing 9,140 records covering all 8,624 sett-year combinations; the 9,140 records have since been imported into Supabase. This is a data organisation step only; I do not use the overlaps to infer social-group residency.

SQL: `sql/migrations/v1_annual_sett_polygon_crosswalk_20261026.sql`; `sql/migrations/v1_annual_sett_crosswalk_readonly_grants_20261026.sql`.


## Earlier notes: annual crosswalk upload

The local polygon overlay succeeded and generated `annual_sett_polygon_all_matches.csv` with **9,140 rows** for **8,624 distinct sett-years** (176 setts × 49 annual files). Multiple polygons produce multiple rows by design. The summary contains 5,614 ONE_POLYGON rows, 988 MULTIPLE_POLYGONS rows, 17 ON_BOUNDARY rows, 1,688 OUTSIDE_ALL rows and 833 NO_COORDINATE rows. These are row counts, not necessarily counts of distinct ambiguous sett-years. There is no interpretation or reassignment in V1. The 9,140 records are present in the Supabase destination table; the generated CSV remains an export of the same calculation. I preserve the 173 undated sett–group links unchanged. The upload is implemented in `scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R` with `UPLOAD_ANNUAL_CROSSWALK=1` and a write-enabled connection.


## Earlier notes: standardised capture-location view

A non-destructive, read-only view `analysis.capture_sett_location_standardised_v1` now exposes one row per original capture (17,586 capture IDs). This is a convenience interface, **not** a replacement for `research.captures` or the recorded sett names. No individual capture or PM record has been deleted or collapsed.

- `sett_clean`: uppercase alphanumeric canonical name (spaces and punctuation stripped) for the currently linked `research.setts.sett_id`, or `OTHER` if no sett ID is linked. Existing links are retained provisionally; newly proposed name/identity merges still require approval.
- `other_location_info`: the recorded sett/location text for rows classified `OTHER`, falling back to capture location description or OS reference when the previous field is absent. Original text also remains in `recorded_sett_name`, `capture_location_text` and `os_ref`.
- `location_easting`, `location_northing`: British National Grid coordinates where documented; for mapped setts these refer to the approved sett coordinate; for recognised grid-referenced PM locations these refer to the **southwest corner of a grid square**, not the exact location where the animal was found.
- `coordinate_basis` gives `SETT_POINT`, `GRID_SQUARE_SOUTHWEST_CORNER` or `NO_COORDINATE`; `location_crs` is EPSG:27700 where coordinates are present. `grid_cell_width_m` retains available square-width precision.
- `location_class` retains the previous location interpretation from `analysis.capture_location_v1`.

Verified view cardinality: 17,586 rows / 17,586 unique capture IDs; 1,249 labelled `OTHER`; 16,034 with sett points; 710 with grid-square corner coordinates; and 842 without assigned coordinates. Thus 303 named-sett captures currently lack a mapped sett point despite their existing sett ID. These figures are counts of capture records, not distinct setts.

This is only a consistent **access-layer classification** using the current approved IDs. The final sett alias dictionary and source-independent `sett_clean` rules must still be agreed before V1 sign-off.


## Update on 28 October 2026: using the XY list as the starting point

**This is still work in progress, not the final V1 dataset.** The uploaded sett XY inventory, preserved as `ingest.sett_coordinate_source_20261023`, is now the **primary starting point** for reviewing sett names and locations. Original `access_raw.tbl_sett` names and `access_raw.tbl_captures.sett` entries are evidence for aliases, separately named historical setts, and capture-location descriptions; they are not allowed to supersede the XY source-name spelling without review. The 168 XY entries are coordinate-source records, not yet 168 certified distinct biological setts.

I am reviewing the proposed XY-primary sett catalogue and a **separate** social-group name catalogue. Existing named-sett records, aliases, `sett_id` links, aggregate counts and `analysis.capture_sett_location_standardised_v1.sett_clean` remain provisional and reflect **previous** naming/linkage rules; that view is **not** an implementation of the newly proposed XY-primary convention. The earlier 14 alias decisions still represent proposed identity merges/non-merges, but the preferred spelling of a canonical name follows the XY source for the new review. User-reviewed grid references, roads, descriptive places and potential sett entries require verification and must retain their raw strings and location precision. Names absent from the XY inventory remain in a separate review queue, not silently deleted.


## 28 October 2026 — tattoo case check: 040l and 040L

I checked the apparent `40l` / `40L` discrepancy against the original Access tables. The stored tattoo is **`040L` (with a leading zero)**. In `access_raw.tbl_culture`, **four rows** (original row IDs **11480–11483**, all dated **25 January 2011**) were entered as **`040l`** with a lowercase final letter. There are **34 further culture rows** entered as `040L`. The original capture table has **10 capture records** under `040L`, and the original badger lookup also uses `040L`.

I am treating `040l` as a **case variant of the same tattoo**, not a separate badger. I verified that the four cultures are **already linked correctly** through their capture to the single research individual **`040L`** (`individual_id = 792`). This means the working research data did not need a destructive correction or a duplicate-individual merge.

**Rule:** use the canonical scientific identifier **`040L`**, retaining the leading zero; when matching original tattoo text, compare `upper(trim(tattoo))`, but keep the original `040l` value in `access_raw` for provenance. This is a confirmed **case-only correction for this tattoo**, not permission to merge other visually similar tattoos or drop leading zeros.

**Audit/verification script:** `sql/migrations/v1_040l_tattoo_case_audit_20261028.sql`. **Database action:** original source records unchanged; existing research links already correct. This is a documented interpretation and reproducibility check.
