# Woodchester spatial field-team queue — 4 November 2026

**Scope:** named sett IDs with no Easting/Northing in `research.setts`, ranked by the live captures that currently fail the researcher-facing spatial audit. This is a request for *measured historical/field evidence*, **not permission to infer coordinates**. British National Grid (EPSG:27700) unless evidence explicitly states otherwise.

| Sett ID | Canonical sett | Unresolved live captures | Request status |
|---:|---|---:|---|
| 552 | WHITINGS BEECH | 87 | Missing XY |
| 540 | TWIN ASH | 56 | Missing XY |
| 547 | RASPBERRY | 40 | Missing XY |
| 542 | WOOD EDGE | 32 | Missing XY |
| 78 | GATE | 22 | Missing XY |
| 553 | SCARHILL | 13 | Missing XY |
| 551 | UPPER | 12 | Missing XY |
| 34 | STONEWALL | 9 | Missing XY |
| 72 | MICHAELS | 7 | Missing XY |
| 549 | TOWER GULLEY | 7 | Missing XY |
| 76 | GRAVEL | 6 | Missing XY |
| 140 | PARK-EDGE | 3 | Missing XY |
| 149 | RAVINE | 3 | Missing XY |
| 36 | BLACKBERRY | 2 | Missing XY |
| 91 | PENNYS | 2 | Missing XY |
| 124 | SPRUCE | 2 | Missing XY |
| 143 | FOX TREE | 0 | Missing XY; no captures currently linked |
| | **Total** | **303** | **17 sett IDs; 16 used by captures** |

The first five resolve 237 of 303 missing-coordinate live capture records **if** valid historical or measured sett coordinates can be supplied, not merely proximate territory/sett descriptions. The next five add 48 records.

## Evidence required for each sett

1. Original source map, field notebook, digitised historical coordinates or authoritative current survey.
2. Easting and northing, datum/CRS, precision/accuracy, and date or historical validity.
3. Whether point describes the **actual trap site, sett centre, sett entrance, or nominal associated sett**.
4. Distinguish names reused, relocated, retired or aliased across decades. Do not assign a fixed point if the location moved through time without documenting the temporal qualification.
5. Store confirmed coordinate proposals in the established location-evidence workflow and apply only after reviewed approval.

## Other outstanding spatial cases (current live WECS v1)

- **170 unmatched recorded-name rows**: 124 distinct recorded names. Automated punctuation/case normalisation finds one highly credible name-format candidate: `MRS MACKS` ↔ `MRS MACK'S` (one record). This is a proposal, **not yet applied**; verify original site identity first. Examples requiring careful historical review: LAGGER LANE (8), DINGLE VALLEY (6), BEECH OUTLIER (4), THIRD PASTURE (4), WEST MAIN (3).
- **107 sett/context conflicts**: nominal sett association but non-sett FIELD/WOOD/BOUNDARY/BUILDING/HEDGE/etc. description. Do not copy nominal sett XY as exact capture coordinates.
- **338 PM recovery locations unresolved**: preserve carcass recovery and field capture locations separately.
- **594 grid-cell precision warnings**: check parsing rules systematically; a grid square's southwest corner is not an exact observation point.
- **26 records with no location recorded**.
- Earlier working list of **102 capture locations** needs a crosswalk to the current 107 context conflicts; they are not assumed identical.
- Earlier **81 missing-coordinate setts** list needs reconciliation with the *current* 17 canonical rows before claiming historical work is complete; scopes may differ.

## Reproducible read-only queries

```sql
select s.sett_id,s.sett_name,count(c.capture_id) as affected_captures
from research.setts s
left join research.captures c on c.sett_id=s.sett_id
where s.easting is null or s.northing is null
group by s.sett_id,s.sett_name
order by affected_captures desc,s.sett_name;

select location_quality,count(*) records
from analysis.encounters_clean_v1
group by location_quality order by records desc;
```

**Not in scope here:** annual social-group/territory assignment, polygon changes, or assigning an SG to an `UN` badger. Do not edit the historical Access-derived records.
