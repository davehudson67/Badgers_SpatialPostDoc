# Woodchester Encounter Classification and Spatial Audit (WECS v1)

**Research baseline:** 4 November 2026. **Source:** Woodchester Microsoft Access-derived data in Supabase, project `klpvihubzlyzubyyubtw`. **Status:** Encounter classification working baseline; spatial provenance still under audit.

## Data governance

- `access_raw`: imported historic source values; untouched.
- `research.captures`: 17,586 canonical source capture/PM records, kept separately, including original `moc`, `is_pm`, location names, comments and PM causes. Do not overwrite to apply interpretations.
- `analysis.encounters_clean_v1`: **researcher-facing view**, one row per source capture/PM record, 17,586 distinct `capture_id`s.
- `research.encounter_episode_decisions`: nine manually confirmed same-episode live/PM source-record pairs. PM companion rows remain distinct, and should not be counted as independent capture events.
- `research.encounter_pair_nonlinks`: explicitly documented instances that must remain separate (Y030 net capture 14 July 1981 vs starvation recovery 16 July 1981).
- `research.encounter_classification_decisions`: 22 dated, reasoned overrides to the clean encounter type and/or outcome. Audit explanation is **not** exported as an extra analysis column.

## Exactly six cleaned classifications

`encounter_type`, `outcome`, `location_type`, `location_easting`, `location_northing`, `location_quality`. Essential identifiers in the same view: `capture_id`, `tattoo`, `capture_date`, `is_pm`, `sett_id`, `episode_primary_capture_id`, `episode_record_role`.

- **`encounter_type`**: observed or defensibly inferred encounter method/context (`TRAP`, `NET`, `SNARE`, `FOUND_IN_EXTREMIS`, `FOUND_ALIVE`, `REMOVAL`, `RTA`, `FOUND_DEAD`, `SHOT`, etc.). `UNKNOWN` is permitted if source method is missing. `FOUND EXT` means **found in extremis**, not 'external'.
- **`outcome`**: `RELEASED` when explicitly documented; `PRESUMED_RELEASED` for routine live captures without contradictory death evidence; `EUTHANISED`, `DIED`, `KILLED`, `FOUND_DEAD`, and `UNKNOWN`. Distinguish explicit evidence from researcher inference using the audit decision/source.
- **`location_type`**: what the spatial reference represents (sett, other capture site, road, field, recovery site, linked field site, etc.).
- **`location_easting`, `location_northing`**: British National Grid coordinates only where supported. A grid-square southwest corner is **not** a precise animal location; the `location_quality` field carries this qualification.
- **`location_quality`**: flags sett-based provisional points, approximations/grid cells, conflicts, and unresolved locations; do not equate an associated sett with a proven net/snare/field recovery point.

## Decisions and important examples

- **Routine trapping with missing original method:** 178 non-PM records investigated. 142 had subsequent live/sampling evidence. The remaining 34 have named canonical setts with coordinates, weights and blood samples (all 34), and no same-week PM; inferred `TRAP / PRESUMED_RELEASED`. Preserve original blank `moc` and mark the inference in SQL rules. Explicit found-alive exceptions are protected.
- **NET and SNARE:** live encounter by default, `PRESUMED_RELEASED` absent contradictory evidence. 140 snare records, 43 net records. G010 (1977 NET + next-day euthanasia PM) linked, Y030 (1981 NET presumed released + distinct starvation PM two days later) explicitly *not* linked.
- **Paired records:** nine confirmed episodes in `research.encounter_episode_decisions`. Preserve both source rows and source dates; location role of PM examination is not interchangeable with field capture or recovery. N070 1987 RTA-associated FOUND EXT/PUT DOWN pair reviewed as one episode despite reversed PM versus put-down dates.
- **1979 `REMOVAL`:** 11 non-PM removals inferred **`KILLED`**, based on contemporaneous PM `REMOVAL` records explicitly marked `KILLED`. These eleven are **not individually PM-confirmed**; do not invent an individual PM link. The 2001 U002 `REMOVAL` was a living badger collected under a woodpile for sampling, now `FOUND_ALIVE / UNKNOWN`; it must not inherit the 1979 lethal-removal rule.
- **Last non-PM exceptions:** 8810 found alive in garage and sampled, `PRESUMED_RELEASED` but original blank method retained; 14170 original RTA, outcome `DIED` researcher-inferred; 16920 found in extremis, `DIED` researcher-inferred (no independent PM confirmation). Do not treat inferred mortality as proof of observed death in survival models.
- **Original method absent on PM rows:** retain clean method `UNKNOWN` where mechanism cannot be verified, but use `FOUND_DEAD` or `DIED` outcome where supported by PM flag/notes or explicit research decision. Case 17055 decomposed carcass at Jacks sett is `FOUND_DEAD`. Case 6692 TRAP with iatrogenic PM cause is `DIED`.
- **Remaining unknown outcome:** one 2001 found-alive garden removal (U002, 17555), with no documented release.

## Current live audit counts (4 November 2026)

17,586 source rows; outcomes: `PRESUMED_RELEASED` 16,261, `FOUND_DEAD` 1,034, `KILLED` 223, `EUTHANISED` 43, `DIED` 23, `RELEASED` 1, `UNKNOWN` 1. Six remaining unknown encounter types (which need not have unknown outcomes).

Spatial counts: 16,642 records carry a coordinate pair, 944 have no final coordinates. Quality groups: 15,736 `SETT_POINT_PROVISIONAL`, 190 `SETT_ASSOCIATION_PROVISIONAL`, 7 `LINKED_SETT_POINT_PROVISIONAL`, 115 `GRID_CELL`, 594 `GRID_CELL_PRECISION_UNCONFIRMED`, 107 `SETT_COORDINATE_CONFLICT`, 837 `UNRESOLVED`.

Missing coordinates split: 303 known-sett records (16 sett IDs); 338 unresolved PM locations; 170 unmatched recorded names (124 unique names); 26 no recorded location. `research.setts` currently has 17 sett rows without XY, but one (FOX TREE) has zero linked captures. Do not confuse these with the earlier historic **81** missing-XY setts inventory; its definition/scope must be reconciled.

## Spatial outstanding work, deliberately separate from social-group modelling

1. **Coordinate evidence for 16 active sett IDs** behind 303 records (plus FOX TREE, zero captures). Never fabricate coordinates.
2. **Historical name crosswalk:** 170 unresolved encounter rows/124 unique recorded names. Audit alias versus non-sett site rather than mechanically equating similarly named places.
3. **107 location conflicts:** source context FIELD/WOOD/HEDGE/BOUNDARY/BUILDING/etc. versus linked sett; do not use sett point as exact non-sett encounter coordinates by default. Compare with earlier 102-record priority queue and document changes in scope.
4. **338 PM recovery locations:** avoid assigning home sett coordinates to true carcass recovery sites; extract grids/notes with original provenance.
5. **594 unresolved grid precision flags:** technical resolution of original OS reference/precision. Square southwest corners must not be interpreted as animal-location points.
6. **26 no-location records:** keep unresolved absent additional source evidence.

Research action order: reconcile named active missing-XY setts; crosswalk historical names; inspect the 107 contradictions; PM recovery records; verify grid precision; freeze versioned spatial input. Await field team on unsupported sett coordinates. **Do not assign social group to UN tattoos, or infer social group from home sett during this capture-location audit.**

## Reproducibility checklist

The SQL view definitions and curation tables are authoritative in the live Supabase database. After changes, export a replayable SQL snapshot and incorporate it in Git's `sql/migrations/` framework; verify DDL/application ordering before replaying to another environment. All manual decision notes and dates live in the two research decision tables and the episode nonlink table. Avoid direct modifications to `research.captures` or `access_raw`.

Suggested validation SQL:

```sql
select count(*),count(distinct capture_id) from analysis.encounters_clean_v1;
select outcome,count(*) from analysis.encounters_clean_v1 group by outcome order by count(*) desc;
select location_quality,count(*) from analysis.encounters_clean_v1 group by location_quality order by count(*) desc;
select * from research.encounter_classification_decisions order by capture_id;
select * from research.encounter_episode_decisions order by live_capture_id;
```
