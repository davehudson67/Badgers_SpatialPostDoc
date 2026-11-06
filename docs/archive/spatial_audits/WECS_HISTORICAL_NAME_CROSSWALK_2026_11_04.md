# Woodchester WECS — historical sett-name crosswalk review (4 November 2026)

**Scope:** capture-level place-name harmonisation in `analysis.encounters_clean_v1`; original `research.captures` rows unchanged. The 16 active sett IDs without coordinates are deliberately excluded from this work.

## Approved and applied

| Source capture | Original value | Canonical sett | Decision | Location treatment |
|---|---|---|---|---|
| 9097 (O025, 1982-08-24) | `MRS MACKS` | `MRS MACK'S`, sett ID 22 | Punctuation-only spelling alias | Recorded `BOUNDARY`, **not a sett-centre point**; retain null encounter XY, quality `SETT_ASSOCIATION_ONLY` |
| 12030 (Y040, 1981-07-24) | `STONEY TRACK` | `STONY TRACK`, sett ID 29 | Established historical spelling harmonisation | `SNARE` in `WOOD`; no encounter XY inferred from sett |
| 12031 (H044, 1998-09-08) | `STONEY TRACK` | `STONY TRACK`, sett ID 29 | Established historical spelling harmonisation | `TRAP` at `SETT`; provisional sett-point proxy E 380742, N 201140 (EPSG:27700) |

Evidence for STONY TRACK: canonical `research.setts` ID 29 and independent `ingest.sett_coordinate_source_20261023` `STONEY.TRACK` share the same BNG coordinates. **Never assume a nominal associated sett is the exact boundary/woodland encounter point.**

The database audit lives in `research.capture_sett_alias_decisions`; query `analysis.capture_sett_alias_audit_v1`. The cleaned `sett_id` is overlaid in `analysis.encounters_v1` and inherited by `analysis.encounters_clean_v1`. `research.captures.recorded_sett_name` and original `sett_id` are untouched.

After applying these three capture-specific matches, 167 records remain in the *originally unmatched-name and still unresolved* subset, down from 170. The overall unresolved location-quality count fell from 837 to 834, while two capture coordinates remain withheld as associated-only; one newly receives a provisional sett point.

## Next unresolved names — do **not** merge automatically

| Recorded name | Records currently in unmatched queue (before new aliases) | Candidate / interpretation | Proposed next action |
|---|---:|---|---|
| LAGGER LANE | 8 | No canonical name equivalent. Original `TRAP` / `REMOVAL`, `SETT`, 1979–1994 | Distinct historical sett likely; request original sett map/location rather than invent an alias |
| DINGLE VALLEY | 6 | Similar to DINGLE (ID 42), but several source rows say `NOT WP`, 1988 | Do not equate with DINGLE without evidence; possibly outside study area |
| BEECH OUTLIER | 4 | Name suggests outlier, not necessarily main BEECH (ID 8), 1981–1983 | Check outlier identity in old sett maps before assignment |
| FIELD WALL | 4 | 1989–1994 `TRAP` at `SETT`, not an exact match for canonical `WALL` | Check physical sett identity independently |
| THIRD PASTURE | 4 in current unmatched queue (5 in all source rows) | Mostly `SNARE` at `BOUNDARY`, not necessarily a sett | Keep as non-sett field/boundary location pending map evidence |
| HAZEL | 3 | Source `TRAP` / `SETT`, 1978–1994; canonical sett list has no `HAZEL` | Check older setts list, possible missing canonical sett |
| HOUSE | 3 | Source `TRAP` / `SETT`, 1995; generic and ambiguous | Check old site map / same-date field records |
| PLAIN EIGHT | 3 | Source `NET` in `FIELD`, 1977 | Treat as named field, not a sett |
| S PEGLARS | 3 | Possibly South Peglars vs canonical PEGLARS (ID 135) | Verify whether separate sett before aliasing |
| WEST MAIN | 3 | Possibly main sett of WEST (ID 35), 1999 | Verify whether canonical WEST refers to same physical point |
| ARTHURS BEECH | 2 | Potentially separate sett rather than ARTHURS (ID 5) or BEECH (ID 8) | Avoid ambiguous automatic merge |
| FOXCUB | 2 | Source `TRAP` / `SETT`, 1992 | Check whether historically distinct sett |

**Working rule:** a close-looking name is not enough for a location match. Separate the *named sett association* from the *physical trap, snare, net, or carcass location*. Explicitly record the capture ID, source name, canonical target, reasoning and any coordinate-role caveat.

## Read-only checks

```sql
select * from analysis.capture_sett_alias_audit_v1 order by capture_id;

select count(*) n,count(distinct capture_id) unique_ids
from analysis.encounters_clean_v1;

select c.recorded_sett_name,count(*) records
from analysis.encounters_clean_v1 e
join analysis.encounters_standardised_v1 s using (capture_id)
join research.captures c using (capture_id)
where e.location_quality='UNRESOLVED'
  and s.prior_location_class='UNMATCHED_RECORDED_SETT_NAME'
group by c.recorded_sett_name
order by records desc,c.recorded_sett_name;
```

**Note:** The captured decision table and updated SQL view are live in Supabase. A full replayable DDL+decisions migration is still to be committed; this note plus the earlier checks are a reproducibility guide, not a claim that Git contains every live migration.
