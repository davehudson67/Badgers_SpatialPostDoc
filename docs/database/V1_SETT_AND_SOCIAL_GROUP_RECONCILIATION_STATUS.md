# Woodchester sett and social-group reconciliation — working policy
**Date:** 2026-10-28  
**Status:** CLEANING IN PROGRESS — NOT APPROVED AS A DEFINITIVE V1 ANALYSIS RELEASE

## Source authority and scope
1. The separately supplied sett XY coordinate inventory is the **primary starting reference** for reviewing named sett locations. The preserved imported copy is `ingest.sett_coordinate_source_20261023`; a review snapshot is `docs/database/V1_XY_source_review_snapshot_20261028.csv`. It contains **168 coordinate-source entries**, not 168 independently confirmed biological sett identities. Preserve `source_name`, grid easting/northing and original provenance.
2. The original Access `access_raw.tbl_sett` lookup is **historical supporting evidence**, not an alternate canonical-name authority. `access_raw.tbl_captures.sett` is the primary original **observation-level recorded sett/location label**. These fields are never overwritten.
3. The current `research.setts` inventory (176 named records before proposed merges) and associated `sett_id` joins are **provisional migrated/working mappings**, NOT proof of biological identity. Do not use a zero linked-capture count as grounds for dropping a named sett. Names with no confirmed matching XY go into a separate review queue; no coordinates are invented.
4. The main collaborative review workbook is **Woodchester_XY_Primary_Sett_Name_Review_20261028.xlsx** (shared separately; not a source dataset until signed off). It is derived from the user's edited review workbook and the preserved XY source. Source-name strings such as `CLIFF.FACE`, `GULLY`, `ELEVEN.ROW`, `STONEY.TRACK` take precedence as proposed canonical labels over earlier Access spelling preferences; those Access spellings become aliases.
5. **Exceptions requiring review before final approval:** `PEN.(NEEDS.RENAME)`, `STREAM.(NEEDS.NEW.NAME)`, coordinate-only names not yet matched to historical records, and any two differently named sett points with nearby/identical XY. Same point or similar spelling is not by itself evidence of the same sett.

## Agreed outputs (future, after independent review and audit)
- **Sett catalogue:** exactly one agreed canonical `sett_clean` per named sett, easting and northing in **EPSG:27700** where confirmed, coordinate provenance/precision, status, and a *single* alias list including historical alternative spellings. For XY-primary canonical spelling, uppercase and remove punctuation/spaces for `sett_clean` (e.g. source `CLIFF.FACE` -> `CLIFFFACE`). Historical `CLIFF` is an alias if the identity merge is upheld.
- **Social group catalogue:** separately approved named social groups, with their own alias dictionary and potentially **time-dependent territories/boundaries**. Identical text in a sett and social-group list does NOT equate the two biological entities. Polygon territory labels, including composite names, are not sett records.
- **Capture-level cleaned view:** original `recorded_sett_name`, `capture_location_text` and `os_ref` retained; `sett_clean` restricted to an approved sett name or literal `OTHER`; `location_easting`/`location_northing` numeric BNG coordinates if independently supported; `coordinate_source`/`coordinate_basis` and precision/grid-cell width; original descriptive information kept separately. Do **not** assign sett coordinates just because a capture belongs to a social group.
- For a six-figure OS grid reference, identify its **100 m cell**; any calculated coordinate for the SW corner is **not** an exact capture point. Incomplete, ambiguous or inconsistent refs must be review-flagged, not silently geocoded.
- **Capture counts:** distinguish (a) occurrences of original recorded name and approved aliases, (b) current captures linked by `sett_id`, and (c) currently linked `moc='TRAP'` captures. The numbers may differ and must be separately labelled. Capture records are not unique badgers.

## Review and evidence
- Full multi-source name inventory: `docs/database/V1_all_sources_sett_name_review.csv`. It contains 580 formatting keys from multiple sources, **not** 580 confirmed setts. Territory/social-group names should not inflate sett counts.
- User-reviewed alias decisions (historical working spelling targets): `docs/database/V1_SETT_ALIAS_REVIEW_DECISIONS.csv`. These record **proposed identity merges or explicit non-merges** but their earlier target spelling is superseded, for naming purposes, by the chosen XY-source name. The decisions have **not been applied** to live capture records or sett IDs.
- Current linked capture and MOC counts are available in `docs/database/V1_sett_capture_counts_source_audit_20261028.csv` and must be reconciled with original recorded-name occurrences.
- The user's reviewed location material distinguishes **coordinate-bearing**, **road**, **description** and **potential sett**. It requires quality control: transcription conflicts (e.g. a supplied grid string inconsistent with the original name), spatial extent, correct OS grid square, and original text encoding. User tagging a row as coordinate-bearing is not itself verification of an exact point.
- Names not matched to the XY inventory remain visible for review rather than being deleted, declared nonexistent, or assigned a nearby coordinate. Some may be genuine historical or outlier setts.

## Supabase governance — no destructive cleanup yet
- **`access_raw`:** retain unchanged as historical source of truth.
- **`ingest`:** retain unchanged XY source and original provenance.
- **`research`:** keep existing migrated working tables and currently linked IDs for traceability, but mark sett-name and spatial cleaning as **provisional**. Avoid replacing raw capture values with normalisations.
- **`analysis`:** existing historical cleaned views and spatial/model inputs are **interim interpretations**, not certified V1. In particular, `analysis.capture_sett_location_standardised_v1` reflects currently linked `sett_id` naming, NOT the newly proposed XY-primary naming policy. It must not be passed off as the final agreed `sett_clean`.
- Future implementation requires approved catalogues, a source-to-canonical alias mapping with justification, coordinate/conflict audit, a reproducible migration, tests of capture counts and referential integrity, and a **separate explicit sign-off** before freezing V1.
- Do not drop original tables, delete captures, rewrite historical spellings, conflate social groups with setts, or change existing Supabase mappings as part of this documentation update.

## Questions for colleagues
1. Which XY-listed names are truly distinct setts, and which are renamed/replaced versions of other mapped setts?
2. Are provisional historical identity merges correct (especially those with two original IDs)?
3. Which names missing from the XY list are known historical/outlier setts, and can their point locations be verified?
4. Which descriptive/road observations have defensible grid references or independently located points?
5. What is the approved social-group name dictionary, accounting for changes in boundaries and time?
