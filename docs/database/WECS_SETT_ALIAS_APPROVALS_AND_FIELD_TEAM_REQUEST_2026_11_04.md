# WECS spatial audit — South Peglars and West Main (4 November 2026)

Investigator-approved correction, saved in live Supabase, **without overwriting historical `research.captures`**:

1. Source `S PEGLARS` (capture IDs **11607, 11608, 11609**, 6 February 1990) resolves to **SOUTH PEGLARS**, a new distinct canonical named sett (ID **555**) with **no approved coordinates**. These three source records all specify `SETT`, `TRAP`, and recorded SG **HOGARTHS**. Canonical `PEGLARS` (ID 135) is different and has coordinate **E382355, N200596**, with historical recorded SG **PEGLARS**. Do **not** copy PEGLARS XY to SOUTH PEGLARS. Result: clean `sett_id=555`, `location_type=SETT`, `location_quality=SETT_ASSOCIATION_ONLY`, XY null.
2. Source `WEST MAIN` (capture IDs **14456,14457,14458**, 22–23 June 1999) resolves to existing canonical **WEST**, sett ID **35**. All source records say `SETT` and `TRAP`. Clean XY provisional **E380190 N201400**; these are canonical sett coordinates, not independently measured capture-point locations. Original recorded SG **WYCH ELM** remains unchanged. Do not silently reassign it to WEST SG because of the sett-name correction.

All six decisions are stored in `research.capture_sett_alias_decisions` with rationale and researcher approval; view `analysis.capture_sett_alias_audit_v1`. The canonical SOUTH PEGLARS row in `research.setts` has null easting/northing and a provenance note. Complete source records remain unchanged.

**For the field team:** `WECS_FIELD_TEAM_MISSING_SETT_COORDINATES_2026_11_04.csv` is a single **59-name** list with:
- **18 canonical names with missing XY** (the original 16 associated with captures, FOX TREE with zero captures, and new SOUTH PEGLARS with three captures).
- **35 distinct unresolved historic names**, filtered to source `capture_location_text=SETT`, with 61 capture rows.
- **6 dead-recovery names**, also source-labelled SETT, with no verified spatial coordinates. These are **recovery sites**, not necessarily canonical sett points.

Six further source rows say SETT with no sett name at all: this list cannot provide a name for them; inspect separately.

Priority: provide independent historical maps, sett-centre or trap-site BNG coordinates, source, precision and approximate validity period. Distinguish a true settled trapping location from a dead recovery or nearby outlier. **No missing coordinates were invented or filled**.

```sql
select * from analysis.capture_sett_alias_audit_v1
where capture_id in (11607,11608,11609,14456,14457,14458);

select count(*),count(distinct capture_id),
       count(*) filter(where location_easting is null)
from analysis.encounters_clean_v1;

select sett_id,sett_name,easting,northing
from research.setts
where easting is null or northing is null
order by sett_name;
```

Note: Earlier SETT-only audit documentation lists original before-correction totals (67 unmatched named records); after these six decisions, **61** named SETT records remain unmatched. The overall clean view contains all **17,586** records.
