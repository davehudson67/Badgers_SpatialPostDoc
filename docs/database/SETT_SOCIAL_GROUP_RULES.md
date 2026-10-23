# Woodchester Database — Sett and Social-Group Fields

**Dave Hudson | Working Version 1 baseline**

## Recorded and canonical locations

The original capture records contain separate entries for `sett`, `socg`, `supergroup` and free-text location information. In the canonical `research.captures` table I retain:

| Field | Content |
|---|---|
| `recorded_sett_name` | Sett text in the original record |
| `sett_id` | Linked canonical sett, where established |
| `recorded_social_group_name` | Original social-group text |
| `recorded_social_group_id` | Linked canonical recorded social group, where established |
| `recorded_supergroup_name` | Original supergroup text |
| `capture_location_text` | Other recorded capture/location description |
| `os_ref` | Original grid reference, where provided |
| `location_cleaning_note` | Explanation of nontrivial existing location harmonisation |

The canonical sett and group names are in `research.setts` and `research.social_groups`. The analysis capture history joins to these canonical identifiers without replacing the original text.

## Existing name harmonisation

The research layer consolidates supported spelling and alias variations while retaining original values. Examples present in the existing spatial/data cleaning work include `TODDS`/`TODD'S`, `TOP SETT`/`TOP`, `CLIFF.FACE`/`CLIFF`, `GULLY`/`GULLEY`, `STONEY.TRACK`/`STONY TRACK` and `ELEVEN.ROW`/`ELEVENTH ROW`. The coordinate-alias mappings are maintained in `data/spatial/canonical_sett_coordinate_aliases.csv`. The last four mappings relate to spatial-coordinate harmonisation and are not represented here as evidence that all corresponding capture names have been rewritten in `research`.

There are 176 canonical sett names. Eighteen historical sett names were added during migration quality control on the basis of repeated capture records: ATCOMBE CORNER, ATCOMBE WEST, BAMBOO, BUNGALOW, DARK WOOD, GULLEY, LISTERS, PRIORY, RASPBERRY, SCARHILL, TODDS, TOP SETT, TOWER GULLEY, TWIN ASH, UPPER, WALL, WHITINGS BEECH and WOOD EDGE. Where later consolidated with an existing canonical name, the original names remain as source evidence.

## Post-mortem capture locations

The original Access records for `015S` and `053M` (2 September 2021) and `026H` (29 September 2021) are post-mortem entries with blank `sett`. Their recorded `socg` fields read CHESTNUT, CHESTNUT and HOLLOW TREE respectively. Canonical `sett_id` is therefore NULL for these three records. The recorded `socg` text is retained. This treatment was reviewed by **Dave Hudson**.

## Sett and social-group histories

`research.sett_social_group_history` and `research.social_group_supergroup_history` hold lookup relationships and validity fields. The imported sett-to-group relationships contain no established dated validity bounds. Capture-level recorded social groups therefore remain separate from later spatial reconstructions and are not treated as evidence of timeless sett ownership.

The analysis view `analysis.sett_social_group_observed` summarises observed co-occurrences. It is distinct from the independent ecological reconstruction of time-varying social-group boundaries.

## Coordinates and location evidence

`research.sett_location_evidence` holds sett coordinates with source, coordinate reference system, accuracy, observation date and approval status. `analysis.sett_coordinates_approved` reports approved entries only. No entries in the new evidence table had been approved at the initial Version 1 audit.

The database also exposes `analysis.sett_field_team_review` (canonical sett names and capture associations) and `analysis.unresolved_recorded_sett_names` (358 distinct labels covering 464 captures). These unmatched labels include place descriptions and field locations as well as potential setts.

The separate **sett and social-group scientific audit** will establish further historic aliases, verified sett coordinates and temporally varying group associations. Its results will be incorporated into the database after that exercise is complete.


## Definitive sett coordinate source — October 2026

I imported the 168-row file `WoodchesterSettLocations (1).csv` into `research.sett_coordinate_source_20261023`. The supplied fields are `Sett_Upper`, `SETT`, `SettX` and `SettY`. A copy is versioned at `data/spatial/sett_coordinates/WoodchesterSettLocations_source_20261023.csv`. The source has 168 unique names and complete numeric coordinate pairs; the British National Grid CRS (`EPSG:27700`) is inferred from the values and needs source confirmation.

I linked 155 coordinates by unique punctuation-insensitive canonical-name matching, and four more using the existing documented coordinate aliases: CLIFF.FACE/CLIFF, GULLY/GULLEY, STONEY.TRACK/STONY TRACK and ELEVEN.ROW/ELEVENTH ROW. These 159 linked coordinates are available in `research.sett_location_evidence` and `analysis.sett_coordinates_approved`; the source strings are unchanged. The unified canonical sett inventory is `analysis.capture_sett_coordinate_inventory` (176 rows). The nine unmatched source names are shown in `analysis.sett_coordinate_source_name_review`: BOWLAS, CONVENT, COVERT, JUNGLE, PEN.(NEEDS.RENAME), SELSLEY, STREAM.(NEEDS.NEW.NAME), VILLIERS.CUT and VILLIERS.UPPER.

Sixteen canonical setts associated with capture records still lack a coordinate match. Their original names and capture associations remain unchanged. The independent sett-name audit will reconcile the remaining source labels and verify any historically distinct setts.
