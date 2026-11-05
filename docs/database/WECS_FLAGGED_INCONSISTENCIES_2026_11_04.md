# Woodchester WECS — flagged inconsistencies and decisions

**Live source:** `research.wecs_review_flags`. **Read-only view:** `analysis.wecs_review_flags_v1`. Snapshot refreshed 4 November 2026. For new issues, update this **one** register and the master versioning document; do not create a parallel audit.

| Issue | Source records | Current interpretation | Status | Final decision |
|---|---|---|---|---|
| **DEATH-020D (020D)** — RTA PM with major head injuries in 2020; live capture in 2022. | 17328, 15335 | Preserve original 2020 RTA PM as genuine evidence, but exclude from terminal death assignment for the 2022-onwards 020D history. Possible tattoo reuse or incorrect historical PM identity; exact correction requires original PM/field record. | NEEDS_SOURCE_CHECK | — |
| **DEATH-U005 (U005)** — PM-found-dead in 2003 followed by live capture of same tattoo. | 16968, 15531 | Preserve original PM death as recorded; do not treat it as terminal death of the subsequently trapped U005 until original carcass/tattoo evidence clarifies identity. No supported alternative tattoo yet. | NEEDS_SOURCE_CHECK | — |
| **SPATIAL-F030-12072 (F030)** — Provisional SU reference rejected as verified death/movement coordinate. | 12072 | XY withheld. Literal SU grid should not be used to infer distant movement; preserve death pending historical map clarification. | NEEDS_SOURCE_CHECK | — |
| **SPATIAL-UN260-17254 (UN260)** — Provisional position rejected for RTA recovery at Stanley Wood near glider field gate. | 17254 | XY withheld pending original source/map confirmation. Death outcome remains recorded. | NEEDS_SOURCE_CHECK | — |
| **DEATH-Q082 (Q082)** — Two death records two days apart at Jacks. | 17055, 7311 | Likely one dead badger with two records; first death is candidate event, later entry provisionally withheld as possible duplicate. Original PM flag disagreement requires source clarification. | OPEN | — |
| **DEATH-W023 (W023)** — Two death records 18 days apart at Giant Beech. | 4984, 4987 | Possible repeat record of same carcass; no live recapture. | OPEN | — |
| **SPATIAL-GRID** — Grid-reference audit: 57 corrected provisional, 40 withheld after map review. | Multiple | 57 accepted by investigator as geographically plausible on interactive maps, while remaining provisionally precise. 40 withheld: two rejected and 38 pending, including 30 hypothetical minus-100km test locations that have NOT been applied. | OPEN | — |
| **SPATIAL-UNNAMED-SETT** — Six original SETT records with no recorded canonical sett name. | 17560, 17573, 17557, 17542, 17561, 16882 | Leave physical encounter XY unknown absent original field evidence. Preserve separate fate/mortality; 024Y two source rows already confirmed one euthanasia. | OPEN | — |
| **SPATIAL-SETT-XY** — Named sett and outlier coordinates pending from field team. | Multiple | Do not invent XY; keep unresolved and provenance flags. | WAITING_FIELD_TEAM | — |
| **DEATH-014D (014D)** — Trap-numbering wording incorrectly interpreted as euthanasia. | 8880, 9767 | Routine capture, presumed released. | RESOLVED | Outcome PRESUMED_RELEASED; words put down describe trap numbering, not killing. |
| **DEATH-024Y (024Y)** — Same-day found-in-extremis and PM; one euthanasia. | 16882, 16817 | One euthanasia episode; PM is companion, grid site is approximate. | RESOLVED | Confirmed same event. Link live 16882 to PM 16817; count one death and preserve both rows. |
| **DEATH-D061 (D061)** — RTA initially misclassified as death, with later live captures. | 14170, 14171 | Not confirmed fatal; RTA retained, outcome presumed released. | RESOLVED | Correct record 14170 to PRESUMED_RELEASED; do not censor at July 1998. |
| **DEATH-SEVEN-FURTHER-PAIRS** — Seven additional duplicate death-row pairs are one field-handling/PM episode each. | 16891, 17441, 8377, 17427, 11061, 17510, 3966, 16832, 16884, 16883, 16816, 16815, 17183, 17058 | Seven more confirmed pairs, adding to previous 10; one death per episode and both historical source rows retained. | RESOLVED | Link seven exact pairs in research.encounter_episode_decisions. Six EUTHANISED and D007 DIED_AFTER_CAPTURE; PM companion not an independent mortality event. Date and spatial provenance preserved. |
| **SPATIAL-CONFLICT** — 107 sett-association versus non-sett physical encounter conflicts. | Multiple | Spatial absence is an accepted final state. Retain canonical sett ASSOCIATION when documented, but do not turn it into an exact field/road/recovery site coordinate. Keep SETT_COORDINATE_CONFLICT QA label for model selection. | RESOLVED | Leave encounter XY null for all 107 records; preserve the associated sett separately. Exact field/recovery positions require independent evidence, not sett-centre imputation. Encounter fate and mortality unchanged. |

## Quick status and handling

**Fourteen issues:** 5 resolved, 4 needing original source checks, 4 open, 1 waiting for field-team coordinates.

- **Confirmed episodes:** 024Y and the seven newly matched deaths (001R, 017R, 045W, D007, I022, M012, Q070) are **one event per field/PM pair**, both source rows preserved. **17** confirmed paired episodes in total.
- **U005 / 020D:** original PM deaths retained, but disputed as *terminal deaths of their currently linked tattoos*. 020D source says first captured as a CUB in 2022, despite a PM recorded under 020D in 2020.
- **W023 / Q082:** possible second report of the same carcass; the later record is held as a potential duplicate. Neither is a later live recapture.
- **Sett/location conflicts:** all 107 accepted as legitimately unknown physical location; nominal associated sett retained separately. This item is **RESOLVED**, even though XY correctly remains null.
- **Grid corrections:** 57 provisional interpretations; 40 points withheld, including UN260 and F030 rejected during investigator map review. Exact grid references and original parsed coordinates retained; a six-digit reference is a 100 m **square**, not an exact point.
- **Field team:** named setts/outliers await XY; six unnamed source SETT encounters are flagged for supplementary evidence. A missing XY does **not** discard a recorded death.

**Only finalise an issue when the change has an applied, version-controlled SQL migration and a final decision.** Query live current status with:

```sql
select flag_id,tattoo,capture_ids,review_status,
       current_interpretation,final_decision
from analysis.wecs_review_flags_v1
order by review_status,flag_id;
```

For provisional survival events, `analysis.mortality_model_candidate_v1` has **1,304** recorded primary deaths: **1,300 candidates and four held** for identity or duplicate-carcase review. It is **not** yet a signed-off survival fit table.

### Investigator map review — 5 November 2026

- All **57 corrected provisional grid locations** except the two individually rejected during the preceding 59-point map review have been marked `VISUALLY_VERIFIED` for **geographical plausibility only**. Original grid strings, precision flags and decision notes remain intact. This approval does not establish precise capture/recovery XY.
- **F030 (12072)** and **UN260 (17254)** remain `REJECTED_BY_INVESTIGATOR` and `WITHHELD`; their PM death evidence is unchanged.
- The **39-grid missing-XY worklist** includes **30** possible 100km northing-prefix errors, **five** irregular/remote numeric references, **two** Leg of Mutton grid anomalies, and the **two** rejected points. An additional withheld PM grid, capture **17427**, is categorised as a missing mortality location, making **40** total withheld.
- `analysis.grid_withheld_candidate_review_v1` provides review-only hypothetical coordinates for the 30 cases (plus all other withheld rows). **Nothing from this proposal view enters `analysis.encounters_clean_v1` until explicitly approved.**
