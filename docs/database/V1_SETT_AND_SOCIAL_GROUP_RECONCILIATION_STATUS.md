# Woodchester sett and social-group names — reconciliation and next steps

**28 October 2026**  
**Status: Cleaning in progress. The dataset is not yet signed off as V1 for final analyses.**

## Aim

I want to establish two clearly defined, independent reference lists: one of named badger setts, with reliable coordinates wherever available, and one of social groups. Some setts and social groups share names, but they are not the same thing. Social-group territories can also change over time.

For each capture, my eventual aim is to have a `sett_clean` value that is either an agreed sett name or `OTHER`. I also want to retain useful location information, whether that comes from a known sett, an OS grid reference or another recorded location. Crucially, the original values must remain available so that all cleaning decisions can be checked and reproduced.

## Which sources am I using?

I am using the sett XY coordinate list that I supplied as the **starting point for the sett catalogue**, including the preferred names. The original imported data are preserved in `ingest.sett_coordinate_source_20261023`, with a snapshot in `docs/database/V1_XY_source_review_snapshot_20261028.csv`. There are **168 entries** in that source. This does not necessarily mean there are 168 distinct, confirmed biological setts: names and coordinates still need checking.

I am checking these against two other historical sources:

- **Original Access sett lookup:** `access_raw.tbl_sett`. This provides historical named sett entries, including some that may no longer be used or may be alternative names.
- **Original Access capture locations:** `access_raw.tbl_captures.sett`. This records what was entered at the time of each capture. Some values are sett names, but others are road locations, grid references, descriptions or outliers.

I want these original sources preserved unchanged. I do not want to create new setts just because a different spelling appears in a capture record.

The current `research.setts` table contains **176 named records before proposed merges**, inherited from earlier migration and cleaning. Its `sett_id` values and capture links are useful for tracing the data, but they should not be treated as the final agreed sett catalogue. A sett with no currently linked captures should not automatically be removed.

## Naming convention

For the working review, I am taking the **name from the XY source** as the preferred name. Historical spellings and names that we consider to refer to the same sett will be recorded as **aliases in a single column**, rather than maintaining separate and overlapping lists of aliases and historical names.

The eventual `sett_clean` field will use uppercase letters and numbers with spaces and punctuation removed. For example:

| Original XY-source name | Proposed `sett_clean` | Historical name / alias |
|---|---|---|
| `CLIFF.FACE` | `CLIFFFACE` | `CLIFF` |
| `GULLY` | `GULLY` | `GULLEY` |
| `ELEVEN.ROW` | `ELEVENROW` | `ELEVENTH ROW` |
| `STONEY.TRACK` | `STONEYTRACK` | `STONY TRACK` |

These examples reflect the chosen **naming priority**, not evidence that a name match alone establishes biological identity. I still need to check proposed mergers, especially where the original records used different sett IDs or have potentially conflicting coordinates.

Names such as `PEN.(NEEDS.RENAME)` and `STREAM.(NEEDS.NEW.NAME)` also need clarification. I will keep historically recorded names that do not match the XY list in a separate review list rather than deleting them or assigning guessed coordinates.

The review spreadsheet, **Woodchester_XY_Primary_Sett_Name_Review_20261028.xlsx**, is the current working document for discussing these questions with colleagues. It is not yet a signed-off master list.

## Social groups

I will review social-group names separately from sett names. The two catalogues may contain some identical names, but a social group should not automatically be assigned the identity or coordinates of a sett with the same name.

I also need to take care with annual territory polygons. Their labels sometimes combine several group names or express uncertainty, and group boundaries may change between years. They should not be added to the sett catalogue simply because their names appear in the database-wide audit.

## Capture locations and coordinates

I want the final capture-level data to preserve the originally recorded sett/location text, alongside the cleaned interpretation.

My proposed fields are:

- `recorded_sett_name`, `capture_location_text` and `os_ref`: original information retained.
- `sett_clean`: one agreed sett name, or `OTHER` if no named sett can be established.
- `location_easting` and `location_northing`: British National Grid coordinates (EPSG:27700), where supported by the evidence.
- `coordinate_source`, `coordinate_basis` and an indication of precision: so we know whether a point comes from the sett inventory, a grid reference or some other source.
- A separate description for locations that are not recognised named setts.

I have reviewed the original location-name inventory and identified entries that appear to contain grid references, roads, descriptions or potential sett names. These classifications need checking before they are incorporated into the cleaned data. In particular, a six-figure OS grid reference identifies a **100 m grid square**, not an exact capture point. If we use its south-west corner as a coordinate, that distinction must be retained. Ambiguous or conflicting references should remain flagged for review.

For capture counts, I will distinguish between how often an original name or proposed alias is written in the capture records, how many captures currently link to a `sett_id`, and how many of those are recorded with `moc='TRAP'`. These are different quantities, and none is a count of unique badgers.

## What has been reviewed so far?

The database-wide inventory is in `docs/database/V1_all_sources_sett_name_review.csv`. It contains **580 standardised name keys** drawn from several sources; these are *not* 580 confirmed setts.

The naming decisions discussed so far are recorded in `docs/database/V1_SETT_ALIAS_REVIEW_DECISIONS.csv`. They are **proposed merges and explicit non-merges**. Some earlier decisions used Access spelling as the preferred canonical name; the new spreadsheet instead gives priority to the XY-source name. These changes have not been applied to capture records or `sett_id` links.

Existing linked capture counts by sett and method of capture are recorded in `docs/database/V1_sett_capture_counts_source_audit_20261028.csv`. I still need to reconcile these with the counts obtained directly from the original recorded names and their aliases.

## Current database position

For now, I want to **retain the existing Supabase tables and explicitly recognise that cleaning is ongoing**, rather than make further structural changes before the review is complete.

- `access_raw` contains the original imported Access records and should remain unchanged.
- `ingest` retains the supplied XY source data and provenance.
- `research` contains migrated working tables, including provisional sett IDs and assignments.
- `analysis` contains derived views and model inputs, which should be considered provisional wherever they depend on unresolved cleaning.

In particular, `analysis.capture_sett_location_standardised_v1` still uses the **existing sett links and earlier name-cleaning rules**. It has **not** been updated to follow the XY-first convention described here, and should not be mistaken for the final `sett_clean` definition.

Once the two catalogues and location rules have been reviewed, I will need an auditable alias mapping, a check for coordinate and identity conflicts, reproducible code to apply the decisions, and validation of capture counts and relationships before signing off a frozen V1 dataset. I do not want to overwrite raw entries or lose their provenance.
