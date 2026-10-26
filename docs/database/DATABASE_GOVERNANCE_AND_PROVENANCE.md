# Woodchester Badger Database — Version 1: structure and cleaning

**Dave Hudson | Working Version 1 baseline | October 2026**

## Data structure

I migrated the historical Woodchester Microsoft Access dataset to PostgreSQL/Supabase. I retain three distinct data layers:

| Schema | Contents |
|---|---|
| `access_raw` | Preserved values from the Access tables included in the original migration; 12 imported source tables |
| `research` | Typed, linked canonical animal, capture, sampling, diagnostic, wound, location and model-output records |
| `analysis` | Tattoo-first SQL views combining and standardising records for analysis |

The original Access structural inventory contains 62 tables. Twelve were included in `access_raw`; the remaining tables have not yet been individually reconciled against that inventory. I have not treated the twelve imported tables as a verified complete copy of every Access object.

A badger is identified scientifically by its canonical `tattoo`. A `capture_id` identifies an encounter or PM record. Internal `individual_id` values remain in `research` as relational foreign keys but are omitted from the principal `analysis` views.

## Original data and implemented cleaning

| Domain | Current implemented treatment |
|---|---|
| Individual identifiers | 3,791 canonical tattoo values, all nonblank and unique under case/whitespace normalisation |
| Historical tattoo spelling | The original `040l` culture entries resolve to canonical `040L`; original entries are retained in `access_raw` |
| Captures | 17,586 canonical captures, with dates, recorded PM status, capture attributes and relational links |
| Diagnostic tables | Original result fields remain in separate research tables linked by `capture_id` |
| Sett names | Canonical sett identities and recorded location text retained separately; evidence-supported naming aliases and existing canonical lookups are applied |
| PM locations | Records `015S`, `053M` (2 September 2021) and `026H` (29 September 2021) have `sett_id=NULL`, reflecting blank original sett fields; their recorded CHESTNUT/HOLLOW TREE social-group text is retained |
| Social-group information | Recorded historical social-group fields remain distinct from sett assignments; undated lookup relationships have no invented validity periods |
| Sex and first-capture age | Standard categories supplied in `analysis.individual_traits_standardised`; recorded values retained; missingness separately indicated |
| Culture interpretation | M.BOVIS, NEGATIVE, OTHER_ORGANISM, INVALID, PENDING, NOT_TESTED and MISSING distinguished in the culture interpretation view |
| Other diagnostic interpretations | DPP, IFN-gamma, ELISA, Brock and Stat-Pak codes standardised without replacing recorded results |
| Derived capture variables | Capture year/quarter, elapsed years since first capture, and explicitly approximate age for first-captured cubs supplied in the capture traits view |

The original Access and canonical tables both currently record age at first capture for tattoo `067B` as `CUB`; this is the retained value. No unsupported recoding to ADULT has been applied.

For culture tests, only M.BOVIS is classified as an M. bovis detection and the recorded NEGATIVE category as negative. Other organisms, missing, invalid and untested observations are not represented as negative evidence. The unified diagnostic view includes all six test families.

## Baseline data checks

| Data type | Rows |
|---|---:|
| Individuals | 3,791 |
| Captures | 17,586 |
| Cultures | 48,699 |
| DPP | 3,316 |
| ELISA | 15,162 |
| IFN-gamma ELISA | 4,375 |
| Brock | 1,648 |
| Stat-Pak | 2,851 |
| Wounds | 1,636 |
| Unified diagnostic observations (`analysis`) | 76,051 |

The 76,051 diagnostic observations aggregate to 17,586 rows in `analysis.capture_diagnostic_summary_standardised` (one per capture). Count agreement is verified; it does not by itself prove every source field or test-to-capture match was correctly migrated.

## Location tables and spatial provenance

`research.setts` contains 176 canonical named setts. Capture records retain both original location text and a canonical sett ID where supported. Three PM capture records with blank original setts retain null sett IDs (as above). The recorded location names without a canonical sett are available through `analysis.unresolved_recorded_sett_names`: 358 distinct labels occurring in 464 captures at this baseline. These labels include non-sett places and descriptions and are not assumed all to be sett names.

`research.sett_location_evidence` stores proposed and approved sett coordinates with evidence source, coordinate system, accuracy, observation date and reviewer. Only approved coordinates appear in `analysis.sett_coordinates_approved`. No coordinate evidence has yet been approved in this new table.

The **scientific audit of physical sett identities, historical coordinates and time-varying social-group boundaries is a separate exercise**, outside this database cleaning and migration summary.

## Updating from Access

The private `ingest` schema contains `access_refresh_batches`, `access_refresh_table_audits` and `canonical_cleaning_decisions` for recording source checksums, table comparisons and accepted cleaning decisions. These audit tables are installed; **the automatic Access-to-research refresh/import process has not yet been implemented**. SQL analysis views calculate standardised values against the current research tables and will therefore reflect future validated imports.


## Verified source-to-canonical integrity checks

The initial read-only audit matched all 3,791 original imported badger tattoos to canonical individuals, with **zero differences** in recorded sex or age at first capture. All **17,586** imported capture rows matched distinct canonical records on tattoo, capture date and PM status, with no duplicate canonical tattoo/date/PM combinations and no missing capture dates. All 3,316 DPP research records have a matching original imported row through `source_raw_row_id`. Canonical captures include 1,288 post-mortem records. Reproducible audit SQL: `sql/audit/Woodchester_v1_capture_identity_integrity.sql`.

These are matching-key and selected-field checks. A complete value-by-value assay audit, verification of culture and other diagnostic capture associations, full field coverage and the 62-table Access inventory reconciliation remain outside the verified scope.

## Reproducibility

Implemented SQL is preserved under `sql/migrations/`. The executable checks are under `sql/audit/`. The table-and-field reference is [DATA_DICTIONARY.md](DATA_DICTIONARY.md); the current location-data interpretation is [SETT_SOCIAL_GROUP_RULES.md](SETT_SOCIAL_GROUP_RULES.md).

**Status:** Working baseline. Version 1 will be signed off following the remaining Access migration integrity checks and database documentation review.


## Consistent V1 location fields (23 October 2026)

I use `analysis.capture_history_v1` for researcher-facing capture history and `analysis.capture_traits_v1` for standardised capture traits. Both retain their existing columns and add `sett_name`, `location_type`, `location_easting`, `location_northing`, `location_crs`, `location_coordinate_basis` and `location_class` by capture ID. The shared implementation is `analysis.capture_location_fields_v1`. Legacy `analysis.capture_history` and `analysis.capture_traits_standardised` remain unchanged for compatibility with running models and earlier analyses.

The standardised `sett_name` is **NULL unless the record has an established canonical sett**. Grid-referenced PM locations have `location_type = 'PM_GRID_REFERENCE'`, `sett_name = NULL`, and provisional grid-square south-west-corner coordinates in the separate `location_easting` and `location_northing` fields. These are not sett coordinates or precise recovery points. Other classifications are `SETT`, `PM_LOCATION_UNRESOLVED`, `UNMATCHED_CAPTURE_LOCATION` and `NOT_RECORDED`. Original `recorded_sett_name`, `os_ref`, `capture_location_text` and `sett_id` remain unchanged.

Validation: 17,586 unique captures in the V1 traits view; capture history V1: 16,337 known-sett rows (16,034 with sett coordinates), 710 grid-referenced PM recovery rows (all have parsed coordinates and **no sett name**), 343 PM location unresolved, 170 other unmatched captures and 26 missing location. The V1 label and initial 23 October baseline remain unchanged; remaining names and spatial-validation questions are explicitly deferred.


## V1 coauthor schema clean-up — 26 October 2026

For the current coauthor-facing structure and permission checks, see [`WOODCHESTER_V1_COAUTHOR_RELEASE_AUDIT_20261026.md`](WOODCHESTER_V1_COAUTHOR_RELEASE_AUDIT_20261026.md). Seven interim diagnostic/review views were retired on 26 October; the core V1 researcher-facing views, base research tables, raw Access tables and versioned SQL migration records were retained. The historical references to old review-view names elsewhere in this document record the original workflow, not live endpoints. The working baseline is still **V1**.
