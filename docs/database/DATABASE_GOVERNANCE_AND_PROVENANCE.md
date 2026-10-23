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

## Reproducibility

Implemented SQL is preserved under `sql/migrations/`. The executable checks are under `sql/audit/`. The table-and-field reference is [DATA_DICTIONARY.md](DATA_DICTIONARY.md); the current location-data interpretation is [SETT_SOCIAL_GROUP_RULES.md](SETT_SOCIAL_GROUP_RULES.md).

**Status:** Working baseline. Version 1 will be signed off following the remaining Access migration integrity checks and database documentation review.
