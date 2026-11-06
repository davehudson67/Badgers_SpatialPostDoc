# Review of 102 TRAP records without a linked sett (2 November 2026)

**Focus: capture/recovery location only; no social-group assignment.** Read-only Supabase audit. No research or raw values changed.

## Population
Exactly 102 `research.captures` rows have `moc='TRAP'` and `sett_id IS NULL`: **97 non-PM** and **5 PM**. Of these, **81 have a recorded sett name** and **21 do not**. All four values (original name, method, date, location-description) must be preserved during reconciliation.

Location-description counts: SETT 68, NOT WP 13, BOUNDARY 7, OTHER 2, WOOD 2, BUILDING 2, FIELD 1, NULL 2, and five specific free-text trapping/PM descriptions.

## Highest-frequency unresolved recorded names
| Original name | Records | Date span | Next action |
|---|---:|---|---|
| LAGGER LANE | 7 | 1993–94 | Historical master map; avoid assuming DINGLE despite repeated captures of same animals |
| DINGLE VALLEY | 6 | 1988 | Historical map and compare FIELD FARM/DINGLE |
| BEECH OUTLIER | 4 | 1981–83 | Distinct historical outlier? Do not merge with BEECH based on text |
| FIELD WALL | 4 | 1989–94 | Specific historic trap site? Compare WALL / ATCOMBE WEST but do not infer identity |
| HAZEL | 3 | 1978–94 | Check whether real historic sett; avoid nearest-name assignment |
| HOUSE | 3 | 1995 | Ambiguous; review field map and original captures |
| S PEGLARS | 3 | 1990 | Historically distinct from PEGLARS unless evidence of same physical sett |
| WEST MAIN | 3 | 1999 | Verify West-associated named sett versus geographical description |

Other recurring labels: BOUNDARY STONE (2), FARMPIECE 5 (2), FOXCUB (2), HOME GROUND OUTLIÛER (2), NAILSWORTH TEAM (2), NORTH (2), OUT (2), WOOD WALL (2). Numerous one-offs require the exact historical sett map / XY catalogue, not automatic nearest-neighbour mapping.

## Missing-name records with helpful original detail

| capture_id | Date | PM? | What the record actually says | Proposed disposition |
|---|---|---|---|---|
| 16903 | 2005-11-18 | yes | Trapped at Top Sett to assess injuries | **Strong named-sett candidate**, verify TOP name/ID, keep PM outcome |
| 17305 | 2003-09-02 | yes | Died in holding cage, caught at Inchbrook | **Strong named-sett candidate** for *capture* point Inchbrook; don't confuse death place |
| 16895 | 2015-07-14 | yes | Caught in trap at West sett during routine trapping | **Strong named-sett candidate**, verify WEST ID |
| 16879 | 2005-10-11 | yes | 'Ct. at W\'Edge - part of ZoneC routine catchup W.P.' | **Probable Windsor Edge**; check historical field abbreviation |
| 17532 | 2004-01-21 | no | Remote trap, bottom of Leg of Mutton above Peglar's sett | **Off-sett**, not PEG LARS XY point |
| 17371 | 2009-12-01 | no | Trapped at small sett on boundary between Septic Tank and Yew/Top | Real **small sett** noted, but name/XY unresolved |
| 16902 | 2005-11-11 | no | Single badger caught remotely on field boundary to remove collar | **Off-sett**, no sett coordinate |
| 16896 | 2001-07-15 | no | Found on track between Box and West; euthanased | **Method/event review**, do not convert recovery location to sett |
| 17427 | 2009-11-05 | yes | Euthanased at W. Park during routine sampling | **Original trap site unresolved**, review event history |

Two records have no name and no location text (capture IDs 17553 and 16902; latter has informative comment). Several earlier (1988–95) unnamed captures have only a generic location value such as SETT/NOT WP/BUILDING; need source registers.

## Important same-individual context (not sett identity proof)
- 5 of 7 LAGGER LANE records involve individuals that also have a recorded DINGLE trap capture.
- 6 of 6 DINGLE VALLEY records involve individuals also caught at FIELD FARM.
- 4 of 4 FIELD WALL records involve individuals with ATCOMBE WEST capture records.
- 3 of 3 S PEGLARS records involve individuals with HOGARTHS captures.

These may help field staff locate candidate areas but **do not prove** that two named sites are the same sett. Animals can move between different setts.

## Review protocol
For every one of the 102 capture IDs, retain the original date, original tattoo, `moc`, `is_pm`, `recorded_sett_name`, `capture_location_text`, `os_ref`, `comment`, current `sett_id` (NULL), and any related capture history. Assign one of:
- `KNOWN_SETT_CONFIRMED`: explicit name crosswalk or historical master-map evidence supports one canonical sett ID/XY.
- `HISTORIC_SETT_XY_NEEDED`: a genuine sett seems recorded, but coordinate/identity not independently known.
- `OFF_SETT_CAPTURE`: live encounter is away from a sett; retain location description and precision, don't substitute nearby sett XY.
- `PM_CAPTURE_SITE_KNOWN`: a deceased animal's original trap site is known; separately retain death/recovery place.
- `METHOD_OR_EVENT_CONFLICT`: TRAP entry conflicts with narrative; requires original field record.
- `UNRESOLVED`: not enough evidence.

The ideal finished review has **one row per capture_id**, old text and suggested action, supporting evidence, confidence level and reviewer/date; no silently invented coordinates.

## Reproducible extraction SQL

```sql
SELECT c.capture_id, i.tattoo, c.capture_date, c.is_pm, c.moc,
       c.recorded_sett_name, c.capture_location_text,
       c.os_ref, c.comment, c.location_cleaning_note, c.sett_id
FROM research.captures c
JOIN research.individuals i USING (individual_id)
WHERE c.moc = 'TRAP' AND c.sett_id IS NULL
ORDER BY c.recorded_sett_name NULLS FIRST, c.capture_date, c.capture_id;
```

**Status:** categorisation candidates are not approved spatial corrections. We have not yet reconciled all 81 named records against the independently supplied XY CSV or the original paper/master map. No updates to `research.sett_id` or coordinates have been made.
