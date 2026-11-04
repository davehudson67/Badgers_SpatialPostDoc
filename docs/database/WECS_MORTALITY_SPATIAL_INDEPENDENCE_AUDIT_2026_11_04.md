# WECS v1: mortality must not depend on spatial coordinates (4 November 2026)

**Core rule:** encounter, vital status, and geographic position are separate dimensions. A confirmed dead badger remains a death event even if the recovery site has no defensible XY. Do not convert a death to ordinary right-censoring merely because its location is unknown. Conversely **RTA alone is not proof of death**, especially for an animal that subsequently survives.

## Implemented and verified in live Supabase

- **analysis.encounters_clean_v1**: original 17,586 capture/PM source rows; standardised six encounter fields plus identity/episode links. `location_easting/northing=NULL` is an acceptable value. Clean `outcome` stays populated separately.
- **analysis.mortality_events_review_v1**: **1,311 recorded death-event rows**, excludes ten PM companion rows already linked to a primary record; of these 1,311 rows, **401 have no XY**. This is a review dataset, **not** yet a final terminal-survival model table. Displays the original event date (not necessarily exact time of death), outcome, original method/PM cause, possible PM companion, best available coordinate and quality, next definite live capture, previous recorded death and review status. The best-available PM point can be a grid-square southwest corner rather than an exact point.
- **024Y**: capture 16882 (2014-08-14 `FOUND EXT`, explicit euthanasia) and PM capture 16817 (same tattoo/date/weight, RTA description, `SO813006`) linked as **one episode**. Research decision in `research.encounter_episode_decisions`; grid provenance is `LINKED_GRID_CELL_PRECISION_UNCONFIRMED`, not a false sett point. If a mortality analysis uses its PM coordinate, respect grid-cell uncertainty.
- **014D, capture 8880 (2025-05-20)**: **NOT euthanised**. Source phrase "both put down as trap 1" refers to trap numbering, recorded `release_assessment=Fit`, and animal was trapped again in 2026. Corrected to `PRESUMED_RELEASED` in `research.encounter_classification_decisions` with explanation.
- **D061, capture 14170 (1998-07-28)**: originally RTA non-PM; researcher earlier inferred death, but repeated later live captures demonstrate survival. Retain `encounter_type=RTA`, correct `outcome=PRESUMED_RELEASED`; original RTA record unchanged.
- **U005, capture 16968 (2003-02-06)**: `FOUND DEAD` PM, but same canonical tattoo subsequently live trapped in Sept 2003. Keep original death evidence; **flag ID mismatch / wrong death assignment** pending original-record identification checks. Do **not** treat this as certain terminal death of U005.
- **020D, capture 17328 (2020-05-18)**: strong RTA PM evidence incl head trauma, but same canonical tattoo is subsequently trapped alive repeatedly from October 2022 onward. Preserve death evidence and flag **identity conflict**; do not assign 2020 terminal death to the later live individual before source reconciliation.
- **W023**, 4984 PM 1980-04-02, 4987 `FOUND DEAD` 1980-04-20, same Giant Beech; and **Q082**, 17055 PM 2000-05-15, 7311 `FOUND DEAD` 2000-05-17, same Jacks. These later non-PM entries are **not live recaptures**. Flag possible repeat reports of a single death for investigator review; never erase the original reports.
- Four other unnamed SETT live captures (17560 F095; 17573 F041; 17557 K070; 17542 E076) have known capture histories but no same-event sett evidence; retain `location_easting/northing=NULL`. An earlier or later sett is not a defensible exact coordinate for that encounter.
- Unnamed SETT RTA 17561 L047 on 1987-08-24 has `is_pm=true`, `pm_cause=RTA`, `FOUND_DEAD` outcome, missing XY. Preserve death even though the earlier live capture occurred at another sett.

## Exclusion logic for future survival models

1. Use `analysis.mortality_events_review_v1` for reviewing death evidence and duplicate/identity flags; do not use `is_pm` or map-coordinate availability as a surrogate for alive/dead.
2. Where two source rows have been curated as one episode, use **one event** (exclude `episode_record_role='PM_COMPANION'`).
3. For mortality records followed by definitely live trapping of the **same canonical individual**, set aside from terminal-survival fitting until source-level identity error is reconciled; do not remove the death evidence.
4. Possible duplicate FOUND DEAD reports should be adjudicated before event-count summaries.
5. Right-censoring means last known alive with **no trusted death event**; missing death XY does not turn an observed death into right-censoring.
6. A dead badger recovered somewhere other than its home sett should not contribute a false home-sett coordinate to spatial analyses.

## Read-only QA

```sql
select count(*) source_rows,count(distinct capture_id) ids
from analysis.encounters_clean_v1;

select count(*) death_event_rows,
 count(*) filter(where location_easting is null or location_northing is null) without_xy
from analysis.mortality_events_review_v1;

select capture_id,tattoo,recorded_event_date,mortality_review_status,
 next_live_capture_date,previous_death_record_date
from analysis.mortality_events_review_v1
where capture_id in (16882,16968,17328,4984,4987,17055,7311)
order by recorded_event_date;

select capture_id,outcome,encounter_type
from analysis.encounters_clean_v1 where capture_id in (8880,14170);
```

## Remaining work

- Verify identity source for U005 / 020D PM records and later tattoos, including tattoo, tags, carcass ID, any source PM paper form.
- Confirm whether paired W023 and Q082 death reports refer to the same physical carcass.
- Reassess location text `SETT` on 024Y and other unnamed sett entries only when original field evidence exists.
- Continue grid-reference precision audit independently of mortality status.
- **Model development:** build one terminal status per verified individual/episode, with reviewer flags and an explicit unknown-status category. `analysis.mortality_events_review_v1` remains a review layer, not a signed-off modelling extract.

**No original records were overwritten.** Individual identity conflicts and inferred classifications are recorded transparently.
