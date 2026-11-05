# 03 — Woodchester database: versioning, SQL migrations and scientific decisions

**Working WECS Version 1 — 4 November 2026.** This is the **single current decision log**. See [01 Access](01_ACCESS_AND_TABLE_GUIDE.md), [02 Master Dictionary](02_MASTER_DATA_DICTIONARY_AND_AUDIT.md) and the [flagged inconsistencies](WECS_FLAGGED_INCONSISTENCIES_2026_11_04.md). Older database documents in Git are historical background, not competing authorities.

## Operating principle: one authoritative source, reproducible change

1. **`access_raw` preserves the imported Access values** (12 imported tables, not a complete proven export of the original 62 Access objects).
2. **`research` holds canonical typed source records** and explicit curator decisions. Do not change `research.captures` to hide an original ambiguity. The scientific ID is `tattoo`; `individual_id` exists only for joins.
3. **`analysis` provides stable researcher-facing views**, mainly `encounters_clean_v1` (one source record per row), `capture_history_v1` (rich history), `diagnostic_results` (one assay result per row) and `mortality_events_review_v1` (one recorded death per primary row, with flags).
4. Every future change must have **a dated, replayable SQL script in `sql/migrations/`**, a QA check in `sql/audit/` and a concise explanation here. Avoid editing views manually without saving a matching migration and checking dependent objects.
5. Every unresolved issue belongs in `research.wecs_review_flags`. Only set a **final_decision** when approved and implemented; don't replace evidence with a guess.

## Current clean output

**`analysis.encounters_clean_v1` — 17,586 source rows.** Seven essential identifiers: `capture_id`, `tattoo`, `capture_date`, `is_pm`, `sett_id`, `episode_primary_capture_id`, `episode_record_role`. Exactly **six cleaned fields**: `encounter_type`, `outcome`, `location_type`, `location_easting`, `location_northing`, `location_quality`.

**`analysis.mortality_events_review_v1` — 1,304 recorded death-event rows**, with 433 candidate events without XY (source/event spatial row counts differ); not a finished survival endpoint. Seventeen confirmed field/PM same-event links prevent counting the PM companion as a second death. Identity conflicts and duplicate-death reports still need adjudication. **Deaths with unknown XY remain deaths** and must not be treated as never recaptured/censored solely for that reason.

**`analysis.wecs_review_flags_v1`** is the *live* issue tracker. `RESOLVED` always has a final decision; `OPEN`, `NEEDS_SOURCE_CHECK` and `WAITING_FIELD_TEAM` have provisional current interpretations.

## Migration index (apply in dependency order, don't blindly rerun against production)

### Foundation / migration work already preserved in Git

| Script | Purpose |
|---|---|
| `woodchester_v1_baseline_extension_20261023.sql` | Early canonical baseline extension |
| `woodchester_v1_access_refresh_audit_infrastructure_20261023.sql` | Access-import audit and cleaning-decision infrastructure |
| `woodchester_v1_all_six_assays_20261023.sql` | Six assay families |
| `woodchester_diagnostic_interpretation_v2_20261023.sql` | Diagnostic interpretation and missing/invalid categories |
| `woodchester_diagnostic_include_culture_v3_20261023.sql` | Include culture interpretation in combined diagnostics |
| `woodchester_standardisation_v1_20261023.sql` | Standardise research traits/diagnostic fields |
| `woodchester_v1_1_sett_location_review_20261023.sql` | Sett location quality review |
| `woodchester_v1_1_sett_review_cardinality_fix_20261023.sql` | Fix duplicate-row/cardinality issue |
| `woodchester_v1_2_revert_pm_inferred_setts_20261023.sql` | Reverse unsafe PM-inferred sett assignment |

All names are relative to `sql/migrations/`. These older scripts establish the starting environment; source import and external dependencies must already exist. The review/cardinality correction follows its earlier review migration. The 2026-10-23 scripts may have been applied in a different live-history sequence; consult migration history before replay.

### Current encounter, spatial and mortality curation

**`sql/migrations/20261104_wecs_curated_v1_snapshot.sql`** is a **replayable WECS curation baseline** exported from live database definitions and decision rows on 4 November 2026. It contains:
- The current 17 linked field–PM episode pairs and one explicit **nonlink** (Y030 netting versus later independent starvation recovery).
- All **23 manual outcome/encounter overrides**, including 1979 REMOVAL→KILLED (11 records), D061 RTA survival correction, 014D false-euthanasia correction, and 024Y explicit euthanasia.
- Nine approved **capture-specific sett aliases** (MRS MACKS, STONEY TRACK, S PEGLARS→SOUTH PEGLARS, WEST MAIN→WEST) and the distinct canonical SOUTH PEGLARS name (ID 555, no XY).
- Twelve live flagged-inconsistency cases, with current status and any final decision.
- Latest **eight WECS view definitions** including encounter clean, alias audit, mortality review and issue register.

**Important scope limitation:** this is *not* a stand-alone restoration of the entire database. It depends on pre-existing imported `access_raw`/`research` records and source standardisation/spatial views such as `analysis.encounters_standardised_v1`. Before using on a fresh database, check those prerequisite view definitions and migration history. The snapshot uses `ON CONFLICT DO NOTHING` to avoid silently overwriting already reviewed decisions. An incremental amendment after 4 November must receive **a new dated migration**, not silent mutation of this historical snapshot.

### Collaborator permissions (applied and saved)

**`sql/migrations/20261104_wecs_readonly_access_grants.sql`** must run **after** the curated WECS snapshot on fresh/rebuilt databases. It grants `SELECT` on the four curated WECS analysis views to both read-only roles, restricts direct curation-table SELECT to the advanced `badger_research_readonly` role, and establishes read-only row-level policies for that advanced role. These curated analysis views are view-owner secured to expose **only their selected columns**, without needing to grant unrestricted write access to original observations.

**Verified 4 November 2026:** both `badger_readonly` and `badger_research_readonly` have `SELECT` on `analysis.encounters_clean_v1`, `analysis.mortality_events_review_v1`, and `analysis.wecs_review_flags_v1`; advanced role also has SELECT on `research.wecs_review_flags`. These checks verify role-level grants, not a real end-to-end individual collaborator login; verify with the user's actual login when available.

### Applied spatial and identity audit migrations (4 November 2026)

Run these **in order after** `20261104_wecs_curated_v1_snapshot.sql` and the read-only grants migration:

| Saved migration in `sql/migrations/` | Implemented decision |
|---|---|
| `20261104_wecs_grid_square_qa_and_safe_corrections.sql` | Named Woodchester-area ST references were mapped ~100 km south by the original parser. **50** provisionally reinterpreted in the SO square; **four** embedded ST/SU original prefixes mechanically corrected; **33** uncertain coordinates withheld. Source unchanged |
| `20261104_wecs_six_digit_precision_and_additional_quarantine.sql` | A six-digit OS reference represents a **100 m square**, not an exact observed point. Separates explicitly recorded SO prefixes from unverified assumed prefixes; **five** additional suspect points withheld |
| `20261104_wecs_access_identity_and_spatial_conflict_resolution.sql` | Original Access data confirm U005 and 020D death/tattoo contradictions, the latter explicitly recorded first captured as CUB in **2022** although attributed a PM death in **2020**. These two deaths remain recorded but are held from tattoo terminal-event assignment; second possible repeated deaths for W023 and Q082 held. **107** nonsett/sett-association spatial conflicts resolved by retaining missing XY |


These corrections preserve the original OS reference and its interpretation before correction in `research.capture_grid_coordinate_decisions`. Check the concise view `analysis.grid_reference_audit_v1`. Use `analysis.mortality_model_candidate_v1` for tentative model event inclusion, not as a final survival fit dataset. A death with no XY is still recorded as a death.

### Further record-level mortality audit (applied after the migrations above)

| SQL file in `sql/migrations/` | Why it exists |
|---|---|
| `20261104_wecs_seven_confirmed_death_episode_pairs.sql` | Original Access/capture notes confirm seven more single-event field–PM pairs: **001R, 017R, 045W, D007, I022, M012 and Q070**. The database now has **17** linked pairs. D007 explicitly states its PM was entered the following day because historic Access could not record both rows on the true date. Six episodes are EUTHANISED; D007 is DIED under anaesthetic |
| `20261104_wecs_pm_companion_spatial_provenance.sql` | PM companions retain their own independent grid-square recovery location if recorded; a nominal sett point is **not** copied onto PM rows without independent evidence. The field record retains its own supported sett/capture location. Original spatial text unchanged |

**Final verified working counts:** 17,586 distinct capture/PM source rows; **17 confirmed two-row episodes**; 57 provisional OS-grid corrections and 40 withheld points; **981 source rows have no accepted XY** (including intentionally locationless PM companions); **1,304 recorded death episodes** after excluding linked PM companions; **1,300 candidate terminal events and four held events** (2 tattoo identity contradictions and 2 possible repeated deaths). Among candidate terminal events **430 have missing XY**, which does not remove death evidence. Twelve live issues: 5 resolved, 2 need original source checks, 4 open and one awaiting the field team.

**Outstanding mortality identity checks:** original Access still documents U005 as both dead and subsequently live; 020D's 2020 PM conflicts with age_first_capture=CUB/year_first_capture=2022. W023 and Q082 each have potentially repeated carcass records. No alternative identity has been invented. This is **not yet a certified survival-modelling input**, but the hold/candidate distinction is explicit in `analysis.mortality_model_candidate_v1`.

### Continuing spatial cleanup: malformed OS strings and one live review queue

**`sql/migrations/20261104_wecs_five_malformed_grids_and_spatial_review_queue.sql`** is applied and version-controlled. It preserves five original malformed PM grid references (capture IDs **16859, 16967, 16997, 17043, 17500**) while adding defensible, **provisional** grid-square interpretations from their named recovery localities. These points are **not certified 1 m/10 m precise observations** even when original digits describe small grid cells. The other ambiguous strings remain unlocated.

The view **`analysis.spatial_missing_review_v1`** is the single queryable worklist; it replaces the need for another descriptive audit document. All **979** rows without accepted XY fall into exactly one reason category: 331 mortality/recovery location; 306 field-team sett XY; 163 named nonsett capture sites; 107 sett-versus-physical-site conflict (already **RESOLVED** as legitimately unknown); 39 original grid to verify; 26 source-unspecified locations; and 9 PM companion records with no independent point. Totals are mutually exclusive in the view; underlying issue types can overlap.

**Current baseline after this migration:** 17,586 source rows; **57 corrected provisional grid interpretations**; 40 withheld grid points (one is categorised under a different priority in the spatial review view); 981 source rows without accepted XY; **1,300 candidate death episodes**, of which **430 lack accepted coordinates**. The four held terminal-death records remain held and the 17 paired episodes remain unchanged.

### Read-only validation (in `sql/audit/`)

- `WECS_v1_encounter_and_spatial_checks.sql` — capture preservation, six fields, six spatial quality checks and curated decisions.
- `WECS_v1_sett_only_location_review.sql` — only source `SETT` locations for historical name/XY review.
- `WECS_v1_mortality_event_review_view.sql` — SQL copy of the mortality review view.
- `Woodchester_v1_capture_identity_integrity.sql` — original Access↔canonical capture/tattoo matching.
- The older cleaning and source-check SQL under `sql/audit/` remains useful as technical audit material.

## Scientific decisions — brief but explicit

| Decision | Implemented rule / consequence |
|---|---|
| Capture identity | Use tattoo scientifically; preserve original source data; 17,586 distinct capture IDs |
| Confirmed linked episodes | Field/PM rows retained, 17 pairs, single mortality event per confirmed episode; **024Y 16882 + 16817 is one euthanasia** |
| Missing capture method | 176 ordinary captures with original blank MOC inferred TRAP/PRESUMED_RELEASED from subsequent live evidence or original trapping/sampling context; original blank retained |
| Historical removals | 11 October 1979 non-PM REMOVAL outcomes classified KILLED based on contemporary PM lethal-removal operation; **inferred**, not separately PM-proven |
| 2001 REMOVAL | U002 17555 was found alive and taken for sampling; no documented release, outcome UNKNOWN |
| Dead animals without positions | Retain death date and fate; XY nullable; model survival independently of spatial mapping |
| RTA | Recorded RTA is encounter context, **not** certain death. D061 14170 was later live and is PRESUMED_RELEASED |
| False euthanasia | 014D 8880 'put down as trap 1' means trap code, release assessment Fit; outcome PRESUMED_RELEASED |
| Identity contradiction | U005 16968 and 020D 17328 PM mortality contradicted by later live captures; source PM preserved, final animal identity unresolved |
| Potential duplicate carcasses | W023 4984/4987 and Q082 17055/7311 flagged; no independent extra death declared |
| Historical sett names | MRS MACKS→MRS MACK'S, STONEY→STONY TRACK; S PEGLARS→separate SOUTH PEGLARS (SG HOGARTHS), WEST MAIN→WEST (recorded SG WYCH ELM **not** rewritten) |
| Spatial evidence | Sett-centre point is not necessarily an actual capture point; boundary/field/wood/road recovery position may remain unknown |
| UN tattoos | Do not automatically give UN badgers social-group membership |
| Grid references | Cell SW corner is not a precise badger point; historical grid references now classified by precision and source-prefix provenance; suspect grid positions withheld pending evidence |
| Outstanding coordinates | 57 field-team names supplied, plus descriptive PM sites; no fabricated points; distinguish historical aliases/outliers from distinct physical setts |

## Workflow to make the next change

1. Investigate and document original evidence. Add/update the corresponding `research.wecs_review_flags` row (keep `final_decision` null if undecided).
2. Make the smallest possible SQL migration in `sql/migrations/YYYYMMDD_descriptive_name.sql`; preserve `access_raw` and raw observations.
3. Re-run `sql/audit/WECS_v1_encounter_and_spatial_checks.sql` and any case-specific checks. Confirm `capture_id` uniqueness, outcome counts, episode count, row-grain and coordinate uncertainty before and after.
4. Commit the SQL to Git; update **this** decision row and a final decision in the register when resolved. Do not create another standalone narrative audit for each case.
5. Verify that approved read-only researcher roles can actually SELECT newly created views (including underlying object permissions/RLS for security-invoker views).
6. Version/freeze model input only once open identity contradictions and duplicate death records are handled or deliberately excluded using transparent rules.

## Quick health check

```sql
select count(*),count(distinct capture_id) from analysis.encounters_clean_v1;
select count(*) from research.encounter_episode_decisions;
select outcome,count(*) from analysis.encounters_clean_v1 group by outcome order by count(*) desc;
select count(*) as recorded_death_events,
       count(*) filter(where location_easting is null or location_northing is null) as no_xy
from analysis.mortality_events_review_v1;
select review_status,count(*) from research.wecs_review_flags group by review_status;
```

**Baseline assurance:** the migration snapshot is now version-controlled; it has **not yet been independently replayed on a clean test database**. Access-wide field-by-field parity and real collaborator end-to-end login tests are not fully signed off. Do not describe WECS v1 as a fully frozen and validated survival-modelling dataset yet.

### Investigator-reviewed map outliers — 5 November 2026

**Applied SQL:** `sql/migrations/20261105_wecs_withhold_un260_f030_map_outliers.sql`.

- **17254 (UN260):** 2002 RTA PM, source `ST900022`, location described as Stanley Wood roadside verge opposite glider field gate. Earlier SO reinterpretation E390000 N202200 rejected on the interactive map; accepted XY now NULL, `GRID_REFERENCE_AMBIGUOUS_WITHHELD`. Original grid, PM death and date preserved. Flag `SPATIAL-UN260-17254` requires original grid/map evidence.
- **12072 (F030):** 1988 PM death, source `SU062988-NOT TRUE MOVE`. Literal SU E406200 N198800 rejected as an approved recovery/movement location. Accepted XY now NULL; original PM death/cause and preceding capture history retained. Flag `SPATIAL-F030-12072` requires clarification of the historical annotation.

**Verified after migration:** 17,586 unique source records; **57 corrected provisional grid points; 40 withheld; 981 source rows without XY; 1,304 recorded death events; 1,300 candidate terminal deaths (430 without XY), four held; 17 paired episodes**. There are **14 live issues** (5 resolved, 4 source checks, 4 open, 1 field-team). No raw Access/research capture records overwritten.
