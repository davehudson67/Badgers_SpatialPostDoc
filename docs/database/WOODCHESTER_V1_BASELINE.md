# Woodchester database — working Version 1 baseline

**Recorded:** 23 October 2026  
**Baseline status:** Working V1; spatial validation and outstanding sett-name review remain open.

## Purpose and scope

I am treating this as the initial consolidated research-data baseline for the Woodchester Access-to-Supabase migration. The source Access tables are preserved under `access_raw`. Canonical individual, capture, sett and test records are in `research`, with researcher-facing views in `analysis`. No new location interpretation replaces the original source text.

The stable researcher-facing V1 location interfaces are:

- `analysis.capture_history`: original capture-history analytical fields, still available.
- `analysis.capture_location_v1`: named-sett and recovery-location interpretation without changing recorded text or source capture IDs.
- `analysis.sett_inventory_v1`: the 176 canonical sett names, capture counts, coordinate evidence and coordinate availability.
- `analysis.sett_coordinate_unmatched_v1`: definitive-coordinate-list names not yet linked to a canonical sett.
- `analysis.unmatched_capture_sett_review`: original unmatched recorded location names for independent review.

The V1 designation is entered into `ingest.woodchester_data_baseline_versions`; SQL defining the interfaces is kept in `sql/migrations/woodchester_v1_baseline_stable_interfaces_20261023.sql`.

## What I standardised

- Badgers are identified by their tattoo, individual encounters by `capture_id`, and dates by `capture_date`. The original capture fields and keys are preserved.
- The recorded `TOP SETT` captures are already associated with canonical `TOP`; `GULLEY` has an existing approved coordinate-name alias `GULLY`. These were checked, not rewritten.
- The file `WoodchesterSettLocations (1).csv` provided 168 named coordinate pairs; a traceable source copy is in `data/spatial/sett_coordinates/WoodchesterSettLocations_source_20261023.csv`. Of these, 159 coordinates have been linked to canonical setts (155 direct canonical-name matches and four previously documented aliases). The nine other source names are retained for review.
- Recorded PM recovery locations containing an interpretable six-digit grid reference, including a number embedded in a longer location description, are distinguished from sett names. Explicitly prefixed `SO` and `ST` references of recognised precision are also interpreted in the separate PM review; source evidence is retained.
- Grid-square coordinates refer to the **south-west corner of a square** at the reference's nominal precision; they are not a precise recorded recovery point and must never be treated as a sett coordinate.
- Original place descriptions, including character-encoding anomalies, are retained. Older intermediate audit views were not deleted, to avoid breaking existing queries and to retain implementation provenance.

## Verification, 23 October 2026

The 17,586 capture records are classified in `analysis.capture_location_v1`:

| Class | Records |
| --- | ---: |
| `KNOWN_SETT` | 16,337 |
| `GRID_REFERENCED_PM_LOCATION` | 710 |
| `PM_LOCATION_UNRESOLVED` | 343 |
| `UNMATCHED_RECORDED_SETT_NAME` | 170 |
| `LOCATION_NOT_RECORDED` | 26 |
| **Total** | **17,586** |

The sett inventory has 176 canonical sett records, 159 with linked coordinates. Nine coordinate-source names remain unmatched. The source includes 1,288 PM records.

## Open items and scientific cautions

**This is a working baseline, not completed geographical validation.** The supplied coordinate reference system still needs confirmation. Most importantly, historical `ST` and `SO` prefix conventions and the mapped coordinates' plausibility within the study area must be checked. A parseable `ST` reference must not be silently corrected to `SO`. The dataset still contains 343 PM records without a recognised location and 170 non-PM records without a matched canonical sett.

Reconcile the nine remaining definitive-source names, the canonical setts without coordinates, historical sett-name aliases and other descriptive recovery locations using source records and field evidence. Do not automatically classify roads, fields, recovery sites, or grid squares as sett identities. The wider Access-table and detailed field-parity audit is also outstanding.

Technical SQL migration history is retained in Git so the implemented rules remain reproducible. The research-facing documentation records this consolidated state and its open issues; new scientific corrections after V1 should be explicitly versioned and accompanied by a recorded rationale.


## Consistent V1 location fields (23 October 2026)

I use `analysis.capture_history_v1` for researcher-facing capture history and `analysis.capture_traits_v1` for standardised capture traits. Both retain their existing columns and add `sett_name`, `location_type`, `location_easting`, `location_northing`, `location_crs`, `location_coordinate_basis` and `location_class` by capture ID. The shared implementation is `analysis.capture_location_fields_v1`. Legacy `analysis.capture_history` and `analysis.capture_traits_standardised` remain unchanged for compatibility with running models and earlier analyses.

The standardised `sett_name` is **NULL unless the record has an established canonical sett**. Grid-referenced PM locations have `location_type = 'PM_GRID_REFERENCE'`, `sett_name = NULL`, and provisional grid-square south-west-corner coordinates in the separate `location_easting` and `location_northing` fields. These are not sett coordinates or precise recovery points. Other classifications are `SETT`, `PM_LOCATION_UNRESOLVED`, `UNMATCHED_CAPTURE_LOCATION` and `NOT_RECORDED`. Original `recorded_sett_name`, `os_ref`, `capture_location_text` and `sett_id` remain unchanged.

Validation: 17,586 unique captures in the V1 traits view; capture history V1: 16,337 known-sett rows (16,034 with sett coordinates), 710 grid-referenced PM recovery rows (all have parsed coordinates and **no sett name**), 343 PM location unresolved, 170 other unmatched captures and 26 missing location. The V1 label and initial 23 October baseline remain unchanged; remaining names and spatial-validation questions are explicitly deferred.
