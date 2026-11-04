# WECS — flagged inconsistencies and decisions

**Snapshot:** 4 November 2026, after spatial and identity QA. **Authoritative live register:** `research.wecs_review_flags`; researcher view `analysis.wecs_review_flags_v1`. This is the **one** issue register alongside the three main database documents.

## Current inconsistency list

| Issue | Capture IDs | Current interpretation | Review status | Final decision |
|---|---|---|---|---|
| **DEATH-020D** (020D): RTA PM with major head injuries in 2020; live capture in 2022. | 17328, 15335 | Preserve original 2020 RTA PM as genuine evidence, but exclude from terminal death assignment for the 2022-onwards 020D history. Possible tattoo reuse or incorrect historical PM identity; exact correction requires original PM/field record. | NEEDS_SOURCE_CHECK | — |
| **DEATH-U005** (U005): PM-found-dead in 2003 followed by live capture of same tattoo. | 16968, 15531 | Preserve original PM death as recorded; do not treat it as terminal death of the subsequently trapped U005 until original carcass/tattoo evidence clarifies identity. No supported alternative tattoo yet. | NEEDS_SOURCE_CHECK | — |
| **DEATH-Q082** (Q082): Two death records two days apart at Jacks. | 17055, 7311 | Likely one dead badger with two records; first death is candidate event, later entry provisionally withheld as possible duplicate. Original PM flag disagreement requires source clarification. | OPEN | — |
| **DEATH-W023** (W023): Two death records 18 days apart at Giant Beech. | 4984, 4987 | Possible repeat record of same carcass; no live recapture. | OPEN | — |
| **SPATIAL-GRID**: OS grid conversions: 54 provisional corrections, 38 suspect coordinates withheld; six-digit 100m precision now explicit. | Multiple | Only corrected named-site grid-square proxies and explicitly supported original 100m cells may contribute spatial evidence; quality flags distinguish inferred prefix and source prefix. 38 withheld entries require original map/source confirmation; do not interpret southwest corner as exact death position. | OPEN | — |
| **SPATIAL-UNNAMED-SETT**: Six original SETT records with no recorded canonical sett name. | 17560, 17573, 17557, 17542, 17561, 16882 | Leave physical encounter XY unknown absent original field evidence. Preserve separate fate/mortality; 024Y two source rows already confirmed one euthanasia. | OPEN | — |
| **SPATIAL-SETT-XY**: Named sett and outlier coordinates pending from field team. | Multiple | Do not invent XY; keep unresolved and provenance flags. | WAITING_FIELD_TEAM | — |
| **DEATH-014D** (014D): Trap-numbering wording incorrectly interpreted as euthanasia. | 8880, 9767 | Routine capture, presumed released. | RESOLVED | Outcome PRESUMED_RELEASED; words put down describe trap numbering, not killing. |
| **DEATH-024Y** (024Y): Same-day found-in-extremis and PM; one euthanasia. | 16882, 16817 | One euthanasia episode; PM is companion, grid site is approximate. | RESOLVED | Confirmed same event. Link live 16882 to PM 16817; count one death and preserve both rows. |
| **DEATH-D061** (D061): RTA initially misclassified as death, with later live captures. | 14170, 14171 | Not confirmed fatal; RTA retained, outcome presumed released. | RESOLVED | Correct record 14170 to PRESUMED_RELEASED; do not censor at July 1998. |
| **SPATIAL-CONFLICT**: 107 sett-association versus non-sett physical encounter conflicts. | Multiple | Spatial absence is an accepted final state. Retain canonical sett ASSOCIATION when documented, but do not turn it into an exact field/road/recovery site coordinate. Keep SETT_COORDINATE_CONFLICT QA label for model selection. | RESOLVED | Leave encounter XY null for all 107 records; preserve the associated sett separately. Exact field/recovery positions require independent evidence, not sett-centre imputation. Encounter fate and mortality unchanged. |

## Decisions and outstanding evidence

- **024Y:** two source records (`16882`, `16817`) are **one confirmed euthanasia**. Preserve both raw rows; count one episode/death.
- **020D:** the original Access badger entry says `age_fc=CUB`, `year_fc=2022`, whereas a death was recorded under the tattoo in 2020. Do not assign that PM death to the 2022-onwards animal without checking the original PM source/identity. **Death evidence remains recorded**.
- **U005:** original Access rows corroborate the February 2003 PM death and September 2003 live capture under the same tattoo. Cannot resolve the actual carcass identity from the imported fields. Hold PM as terminal for tattoo.
- **W023/Q082:** probable repeated reports of a dead animal, not live recaptures. Hold the second record from candidate terminal event use until source evidence resolves whether it is the same carcass.
- **107 non-sett site/sett-association conflicts:** **resolved by deliberate missing XY**. Zero original independent OS references. Preserve known sett association and methods/outcomes, but never convert nominal sett coordinates into physical site coordinates. No field-team request is needed solely because these XY remain missing.
- **OS grids:** 54 correction decisions, 38 withheld. Six-digit grid references give a **100 m grid square**, not an exact point. Retain recorded versus assumed prefixes separately. The 38 withheld positions need original field/map confirmation if their XY is scientifically needed; their dead outcomes remain.
- **Field team:** historical named sett XY remains outstanding; six unnamed original SETT observations have no independently defensible location.

## Closing an issue

Review statuses: `OPEN`, `NEEDS_SOURCE_CHECK`, `WAITING_FIELD_TEAM`, `RESOLVED`. `current_interpretation` is provisional, `final_decision` is the signed-off outcome. A resolved issue **must** carry a final decision and the relevant classification/SQL migration must be applied. Do not change `access_raw` or historic `research.captures` to make a conflict disappear.

```sql
select flag_id,tattoo,capture_ids,review_status,
       current_interpretation,final_decision
from analysis.wecs_review_flags_v1
order by review_status,flag_id;
```

For a candidate modelling view with disputed death rows **retained but flagged**, use `analysis.mortality_model_candidate_v1`. It is not a final survival-analysis event history.
