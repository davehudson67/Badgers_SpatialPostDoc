# Woodchester spatial information: audit and decisions (2 November 2026)

**Status: record-level classification checks completed; remaining historical name and territory decisions pending field-team review.** I've not changed the underlying Access imports or the research capture records.

## What I am trying to distinguish

1. **Recorded place:** what the field team entered at the time (`recorded_sett_name`, `capture_location_text`, `os_ref`).
2. **Sett identity:** whether we can reliably link that recorded label to a known historical sett (`sett_id` and the agreed XY-primary name/alias catalogue).
3. **Encounter location:** where the animal was trapped, netted, shot or recovered, including uncertainty of a grid cell.
4. **Social-group residency:** a biological conclusion, requiring evidence and an appropriate date. Neither a carcass recovery location nor an undated sett/SG link proves this.

I want to preserve (1), clean and document (2), avoid false precision in (3), and infer (4) only using the agreed study design and biological rules.

## Current record-level findings

There are **17,586** `research.captures` records, including these classifications in `analysis.capture_sett_location_standardised_v1`:

| Location class | Rows |
|---|---:|
| KNOWN_SETT | 16,337 |
| GRID_REFERENCED_PM_LOCATION | 710 |
| PM_LOCATION_UNRESOLVED | 343 |
| UNMATCHED_RECORDED_SETT_NAME | 170 |
| LOCATION_NOT_RECORDED | 26 |

A total of **464** capture records have a non-null historical `recorded_sett_name` but no linked `sett_id`. This is not the same as 464 missing setts: these include off-sett descriptions, road/recovery points and alternate spellings, and the classifications above use other fields as well.

**Methods:** `TRAP` occurs in **15,916** records, of which **102** have no linked `sett_id` (**21** with no recorded sett name; **81** with an entered name). Other methods include RTA 738, FOUND DEAD 267, SNARE 140, NET 43, and SHOT (GP) 120. Method of capture/recovery must be considered before using any location as evidence of residency.

Among the 102 unresolved TRAP records, the more frequent recorded names include LAGGER LANE (7), DINGLE VALLEY (6), BEECH OUTLIER (4), FIELD WALL (4), HAZEL (3), S PEGLARS (3), WEST MAIN (3), and HOUSE (3). These are **review candidates, not approved alias or sett assignments**. Some may be genuine outliers or informal descriptions; don't force a match because the name sounds familiar.

## UN animals: decision approved

**Rule: NO `UN%` animal has an analytical resident social-group assignment, without exception for named recovery locations.** The user has explicitly approved this rule.

The database contains **498 UN identifiers/records**, all post-mortem and with **zero `TRAP` records**. **175** nevertheless have a *historically recorded* `recorded_social_group_id` or group label and **34** have a linked `sett_id`. Among those 34, methods are FOUND DEAD 23, SHOT 5, RTA 4, FOUND EXT 1, and DEAD SN/TR 1. The location description is SETT for 28, HEDGE for 3, OTHER for 2 and WOOD for 1. None has an extra populated general comment or OS-reference field.

**Interpretation:** these original location and group strings should remain intact in `access_raw` and `research` so we can audit the input. A label may describe where a carcass was recovered, not the social group to which the animal belonged. For downstream inference, `resident_sg` (name and ID) must be **NULL** for `tattoo LIKE 'UN%'`, and `residency_evidence_eligible` must be **FALSE**. This should be enforced in a derived analysis layer, not by erasing original `recorded_social_group_*` columns. An apparent SG name in the existing `analysis.capture_history_v1` is *recorded metadata*, **not** proof that the rule is already applied in that view.

A carcass found **at a sett** may still retain a valid sett-shaped *recovery* label; this does not reverse the no-SG-residency rule. `DEAD SN/TR` is not equivalent to a live trapped observation.

## Current sett catalogue, XY coordinates and annual polygons

- Original Access `tbl_sett`: **173** records; current `research.setts`: **176** named entries; XY-primary user list: **168** source entries. These are different catalogues and need a deliberate per-name crosswalk. Do not assume row count differences imply lost observations.
- Research named setts with paired easting and northing: **159/176**; both absent for **17**; none has only one of the two coordinates. A simple broad UK National Grid bounds check found no obvious outliers, but this **does not validate the locations against the master sett map**.
- `research.sett_social_group_links`: **173** links across **160** setts; every link has NULL `valid_from` and NULL `valid_to`. These are undated associations and cannot be used as an annual SG assignment.
- `research.sett_annual_territory_matches` annual 1977–2025 spatial rows: ONE_POLYGON **5,614**, OUTSIDE_ALL **1,688**, MULTIPLE_POLYGONS **988**, NO_COORDINATE **833**, ON_BOUNDARY **17**. Multiple rows per sett-year are intentional where overlapping polygons match; never force one group arbitrarily. These are polygon matches rather than observed dispersal or residence.

The study trapping area, annual bait-marking territories and carcass collection area can differ. Even a precise recovery grid cell does not establish membership of the polygon it intersects. For six-digit grid references, retain the **100 m cell and its original southwest-corner convention**, not a falsely precise point.

## Agreed rules for analysis extracts

1. **Source-preserving:** never overwrite original Access location strings or original recorded SG labels.
2. **UN:** keep as data, but `resident_sg=NULL` and `residency_evidence_eligible=FALSE`. Exclude from individual live-capture movement/SG transition models. Keep for relevant PM/disease analyses with the ascertainment process acknowledged.
3. **Marked live TRAP at recognised sett:** strongest primary evidence for residence/SG analysis, subject to dated group rules, repeated observations and conflict checks.
4. **Marked TRAP without verified sett:** retain the capture, classify location unresolved, inspect source name and field records before spatial/SG assignment.
5. **Marked SNARE/NET/other live encounters away from setts:** retain the encounters and possible location information, but do not infer SG residency from encounter location alone.
6. **Marked found-dead/road/recovery records:** retain for disease/mortality and possible last-resighting/recovery analyses; do not classify a recovery point as a live sett recapture or new resident SG.
7. **No automatic nearest-polygon, nearest-sett or default annual SG assignment.** Keep uncertainty and provenance.
8. **Annual sett/territory overlays** may inform historical reconstruction, but without independently justified timing and territory identity are not themselves confirmed annual residence.

## What is left, in priority order

**Priority 1 — recognised setts and name reconciliation:** review `docs/archive/spatial_audits/V1_SETT_AND_SOCIAL_GROUP_RECONCILIATION_STATUS.md`, the 168 XY source entries, 173 Access setts, 176 research setts, and the 'names outside XY list'. Build a source-to-canonical name crosswalk, including *do not merge* decisions and no-XY names. Field team should check the master sett map for unresolved genuine setts.

**Priority 2 — the 102 TRAP records without linked sett ID:** review 21 absent names, and 81 named records. Verify capture method, original location text, likely known sett/outlier, and dates. Assign only those supported by sources; leave the remainder unresolved and count exactly how that affects our movement sample.

**Priority 3 — view-level safeguards:** create a separate, versioned `analysis` extraction view including `is_unmarked_found_dead`, `residency_evidence_eligible`, a distinct canonical `resident_social_group_id`/name (NULL for all UN) and field-source columns. Avoid renaming the existing `recorded_social_group_*` columns in-place.

**Priority 4 — polygon review:** identify overlap/boundary/outside cases that actually affect analytical individual-year assignments; audit historical name and date alignment and verify the carcass-surveillance extent against the field team map, rather than reviewing all polygon rows by hand.

**Priority 5 — impact assessment:** compare the V11/V12 analysis cohorts, SG switch counts, extra-group observations and dispersal candidates before/after approved exclusions. Make the denominator and reason for every exclusion explicit.

### Status and limits

This audit is based on direct read-only queries against the current Supabase tables. It includes actual method/location cross-tabs and checks for coordinate and SG-link completeness. It does **not** certify that the current 159 XY points coincide with the original field-team master map or that the current polygon names always match an approved annual social group. No raw or research data have been changed in these checks, and no downstream analysis view has yet been modified to impose the UN exclusion. Review candidates must remain provisional until checked.
