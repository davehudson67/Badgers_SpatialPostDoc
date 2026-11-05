# Woodchester WECS — flagged inconsistencies and decisions

**Live source:** `research.wecs_review_flags`. **Read-only view:** `analysis.wecs_review_flags_v1`. Snapshot refreshed 4 November 2026. For new issues, update this **one** register and the master versioning document; do not create a parallel audit.

| Issue | Source records | Current interpretation | Status | Final decision |
|---|---|---|---|---|
| **DEATH-014D (014D)** — Trap-numbering wording incorrectly interpreted as euthanasia. | 8880, 9767 | Routine capture, presumed released. | RESOLVED | Outcome PRESUMED_RELEASED; words put down describe trap numbering, not killing. |
| **DEATH-020D (020D)** — RTA PM with major head injuries in 2020; live capture in 2022. | 17328, 15335 | Preserve original 2020 RTA PM as genuine evidence, but exclude from terminal death assignment for the 2022-onwards 020D history. Possible tattoo reuse or incorrect historical PM identity; exact correction requires original PM/field record. | NEEDS_SOURCE_CHECK | — |
| **DEATH-024Y (024Y)** — Same-day found-in-extremis and PM; one euthanasia. | 16882, 16817 | One euthanasia episode; PM is companion, grid site is approximate. | RESOLVED | Confirmed same event. Link live 16882 to PM 16817; count one death and preserve both rows. |
| **DEATH-D061 (D061)** — RTA initially misclassified as death, with later live captures. | 14170, 14171 | Not confirmed fatal; RTA retained, outcome presumed released. | RESOLVED | Correct record 14170 to PRESUMED_RELEASED; do not censor at July 1998. |
| **DEATH-Q082 (Q082)** — Two death records two days apart at Jacks. | 17055, 7311 | Likely one dead badger with two records; first death is candidate event, later entry provisionally withheld as possible duplicate. Original PM flag disagreement requires source clarification. | OPEN | — |
| **DEATH-SEVEN-FURTHER-PAIRS** — Seven additional duplicate death-row pairs are one field-handling/PM episode each. | 16891, 17441, 8377, 17427, 11061, 17510, 3966, 16832, 16884, 16883, 16816, 16815, 17183, 17058 | Seven more confirmed pairs, adding to previous 10; one death per episode and both historical source rows retained. | RESOLVED | Link seven exact pairs in research.encounter_episode_decisions. Six EUTHANISED and D007 DIED_AFTER_CAPTURE; PM companion not an independent mortality event. Date and spatial provenance preserved. |
| **DEATH-U005 (U005)** — PM-found-dead in 2003 followed by live capture of same tattoo. | 16968, 15531 | Preserve original PM death as recorded; do not treat it as terminal death of the subsequently trapped U005 until original carcass/tattoo evidence clarifies identity. No supported alternative tattoo yet. | NEEDS_SOURCE_CHECK | — |
| **DEATH-W023 (W023)** — Two death records 18 days apart at Giant Beech. | 4984, 4987 | Possible repeat record of same carcass; no live recapture. | OPEN | — |
| **SPATIAL-COCKADILLY** — Cockadilly is a hamlet/RTA recovery locality rather than a confirmed badger sett. | 18, 12, 3382 | Both unlocated Cockadilly PM RTAs now have a coarse locality-centre proxy, explicitly distinguished from grid-cell and exact field point. | RESOLVED | Cockadilly is an RTA recovery locality, not a sett. For capture IDs 18 and 3382 use an approved rounded hamlet-centre approximation E379800,N200200 with quality LOCALITY_CENTROID_APPROXIMATE; source text and original values unchanged. Do not use these centroids as exact capture/recovery coordinates. |
| **SPATIAL-CONFLICT** — 107 sett-association versus non-sett physical encounter conflicts. | Multiple | Spatial absence is an accepted final state. Retain canonical sett ASSOCIATION when documented, but do not turn it into an exact field/road/recovery site coordinate. Keep SETT_COORDINATE_CONFLICT QA label for model selection. | RESOLVED | Leave encounter XY null for all 107 records; preserve the associated sett separately. Exact field/recovery positions require independent evidence, not sett-centre imputation. Encounter fate and mortality unchanged. |
| **SPATIAL-F030-12072 (F030)** — Provisional SU reference rejected as verified death/movement coordinate. | 12072 | XY withheld. Literal SU grid should not be used to infer distant movement; preserve death pending historical map clarification. | NEEDS_SOURCE_CHECK | — |
| **SPATIAL-GRID** — Grid location audit: 92 interpreted points accepted, 6 withheld. | Multiple | 87 investigator-verified map points plus UN221 west-gate, two corroborated C016/UN492 road grids, and 2 Cockadilly hamlet-centre proxies. Of 92 CORRECTED decisions, 90 are grid/cell interpretations and 2 are LOCALITY_CENTROID_APPROXIMATE. Six WITHHELD points remain (2 investigator-rejected); no mortality events removed. Grid accuracy not overclaimed. | OPEN | — |
| **SPATIAL-LEG-OF-MUTTON** — Leg of Mutton is a named field/trapping locality, not a verified canonical sett. | 8784, 8783, 16861, 17012, 17477, 17495, 17487, 17334, 16868, 17319 | No new sett ID or sett coordinates assigned. Retain the historical field locality, two withheld SHOT PM XY and original death outcomes. If a map names the field or shot locations can be corroborated, correct individual capture XY, not automatically all Leg of Mutton records. | NEEDS_SOURCE_CHECK | — |
| **SPATIAL-SETT-XY** — Named sett and outlier coordinates pending from field team. | Multiple | Do not invent XY; keep unresolved and provenance flags. | WAITING_FIELD_TEAM | — |
| **SPATIAL-UN221-WEST-GATE (UN221)** — West gate RTA original six-figure grid reference had reversed digit halves. | 17285 | Reconstructed six-digit OS reference 795014. BNG grid-square SW corner E379500,N201400 is accepted as historically supported approximate recovery locality; not an exact carcass measurement. | RESOLVED | Original 014795 preserved; accepted corrected 100 m grid square SO795014 E379500,N201400 for spatial use with provisional quality. Mortality event unchanged. |
| **SPATIAL-UN260-17254 (UN260)** — Provisional position rejected for RTA recovery at Stanley Wood near glider field gate. | 17254 | XY withheld pending original source/map confirmation. Death outcome remains recorded. | NEEDS_SOURCE_CHECK | — |
| **SPATIAL-UNNAMED-SETT** — Six original SETT records with no recorded canonical sett name. | 17560, 17573, 17557, 17542, 17561, 16882 | Leave physical encounter XY unknown absent original field evidence. Preserve separate fate/mortality; 024Y two source rows already confirmed one euthanasia. | OPEN | — |

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

### Further interactive-map approval (5 November 2026)

The investigator accepted **all 30 test-only minus-100km grid candidates** on the second interactive map. The approved SQL migration is `20261105_wecs_accept_30_proposed_grid_northings.sql`. Those entries now have `decision_status=CORRECTED`, `map_review_status=VISUALLY_VERIFIED`, with original grid references and prior parser positions preserved; site precision remains provisional. **87 corrected and 10 withheld** in total. Two previously rejected points, UN260 and F030, remain withheld, and no mortality observations were removed. Nine source-grid missing-XY worklist rows remain (with one additional withheld PM record categorised under mortality recovery).

### Named-locality audit and west gate (5 November 2026)

Source **17285 UN221** corrected from `014795` to `SO795014` E379500 N201400; the user-provided west-gate point and historic listed gateway independently support the reconstruction. The original numeric source remains unchanged, and 100 m grid-cell position is not a GPS death point. **Leg of Mutton** is a field/trapping locality with NET/FIELD and SNARE/HEDGE entries in 1983, plus shot-PM records in 2019; no canonical sett name match. PMs 16861 and 17477 remain withheld. **Cockadilly** is a hamlet with multiple road recoveries, not a canonical sett; capture 18 remains withheld. Remaining unlocated grid records and both previous rejections retain their death outcomes. Current totals: 88 corrected grid positions, nine withheld, 950 capture/PM rows without XY, 399 primary death events without XY.


### Grid/locality close-out — 5 November 2026

**Cockadilly marked RESOLVED:** two approximate hamlet-centre RTA proxies, capture 18 and 3382; both source records/mortality preserved. **Tinkley Lane 16869** and **Woodcock entrance 17117 (UN492)** resolved as source-corroborated transposed 100m OS grids. **Six withheld grid records remain**, only if model-specific spatial precision becomes essential: F030/12072, UN260/17254, Leg of Mutton shot/PM 16861 and 17477, Watts Farm RTA 17376, and 017R PM companion 17427 (field episode 8377 at Larch already locatable). No need to chase every uncertain location where biological death information is sufficient. Source original grid references and original typed locality remain unchanged.
