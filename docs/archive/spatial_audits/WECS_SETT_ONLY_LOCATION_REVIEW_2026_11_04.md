# WECS v1 — SETT-only location audit (4 November 2026)

## Strict scope
Only records with **original** `research.captures.capture_location_text = 'SETT'` (case/space normalised). This avoids mapping net, snare or carcass locations in FIELD, WOOD or BOUNDARY to the nearest associated sett. The 16 canonical setts awaiting XY are set aside on request.

## Counts from live analysis
- 15,736 records `SETT_POINT_PROVISIONAL` from known setts.
- 301 records at 16 known setts have no XY: **deferred to field team**.
- **67 unresolved records at 37 original named locations** lack canonical sett matches: active review queue.
- 7 unresolved PM/death encounters with source location `SETT` but no usable coordinates.
- 5 unresolved records classified `LOCATION_NOT_RECORDED`; in addition, the null-name audit identifies 6 records in this scope, due to one PM/unresolved difference in the location taxonomy.
- Six grid-referenced PM cases are flagged with unresolved grid precision even though their source location text says SETT; these require coordinate-precision review, not sett-name merging.
- One previously unmatched source name STONEY TRACK has already been mapped to STONY TRACK and has a provisional point.

## Unmatched source-name queue — prioritised

| Source name | Count | Evidence | Decision |
|---|---:|---|---|
| LAGGER LANE | 8 | 1979–1994; TRAP/REMOVAL; all SETT | Historical sett likely; **do not merge** with unspecified canonical record |
| BEECH OUTLIER | 4 | 1981–1983, TRAP at SETT | Outlier may differ from BEECH main sett |
| FIELD WALL | 4 | 1989–1994, TRAP at SETT | Distinct from canonical WALL unless map proves same point |
| DINGLE VALLEY | 3 | 1988, TRAP at SETT; other DINGLE VALLEY records say NOT WP | Could differ from DINGLE; no automatic merger |
| HAZEL | 3 | 1978–1994, TRAP at SETT | Not in 176 canonical names; historical sett candidate |
| HOUSE | 3 | 1995, TRAP at SETT | Too generic for automatic alias |
| S PEGLARS | 3 | 1990, TRAP at SETT | May mean South Peglars, not necessarily main PEGLARS |
| WEST MAIN | 3 | 1999, TRAP at SETT | May be main WEST sett; requires identity confirmation |
| ARTHURS BEECH | 2 | 1998, sampled/trapped at SETT | Could be separate from ARTHURS and BEECH |
| BOUNDARY STONE | 2 | 1994–1995, TRAP at SETT | Needs map |
| FOXCUB | 2 | 1992, TRAP at SETT | No canonical exact match |
| HOME GROUND OUTLIER | 2 | 1977–1979, TRAP at SETT | Treat outlier as distinct until verified |
| NORTH | 2 | 1987–1990 TRAP at SETT | Name ambiguous |
| OUT | 2 | 1988 TRAP at SETT | Name ambiguous; need original field notes |
| WOOD WALL | 2 | 1990–1992 TRAP at SETT | Don't merge with WALL automatically |

22 further names occur once each. The 67 records comprise 63 originally coded TRAP, two SNARE, one blank original method but inferred TRAP, and one 1979 REMOVAL. Explicit `SETT` text alone does not prove that SNARE/REMOVAL capture coordinates equal nominal sett coordinates.

## No automatic aliases approved in this pass
Normalised exact matching of these 67 against both `research.setts` and `ingest.sett_coordinate_source_20261023` yielded **no further exact matches**. These are candidates for historical map evidence, not spelling-only transformations.

## Decisions to preserve
For a historically distinct named sett, record a distinct canonical identity and only attach sourced XY once confirmed; don't collapse outlier, main, and field names into one point. For a verifiable historical synonym, add a **capture-specific audited alias** in `research.capture_sett_alias_decisions` and verify the original location role before using the canonical sett point. Never edit original `research.captures` names.

## Reproduction
Run `sql/audit/WECS_v1_sett_only_location_review.sql`. This is read-only and safe to use while collecting historical sett evidence.

**Other current spatial backlogs remain:** 107 sett/context conflicts, unresolved PM recovery sites, and 594 grid-precision warnings. Not addressed in this SETT-only pass.
