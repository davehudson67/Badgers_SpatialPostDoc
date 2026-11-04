# WECS — flagged inconsistencies and decisions

**Live master:** `research.wecs_review_flags`. **Read-only view:** `analysis.wecs_review_flags_v1`. This Markdown file is a **snapshot dated 4 November 2026**; update the database first, then regenerate this register. The core access guide, dictionary and migration/decision log are the three main documents. **Do not overwrite original Access-derived data to resolve a flag.**

## Current register

| ID / tattoo | Capture IDs | Problem | Current interpretation | Status | Final decision |
|---|---|---|---|---|---|
| `DEATH-020D` / 020D | 17328, 15335 | RTA PM with major head injuries in 2020; live capture in 2022. | Preserve true PM record; tattoo/individual linkage unverified. | **NEEDS_SOURCE_CHECK** | — |
| `DEATH-U005` / U005 | 16968, 15531 | PM-found-dead in 2003 followed by live capture of same tattoo. | Keep PM mortality evidence; do not assume death belongs to later live animal until identity verified. | **NEEDS_SOURCE_CHECK** | — |
| `DEATH-Q082` / Q082 | 17055, 7311 | Two death records two days apart at Jacks. | Likely one carcass, retain records pending source confirmation. | **OPEN** | — |
| `DEATH-W023` / W023 | 4984, 4987 | Two death records 18 days apart at Giant Beech. | Possible repeat record of same carcass; no live recapture. | **OPEN** | — |
| `SPATIAL-CONFLICT` | Multiple | 107 sett-association versus non-sett physical encounter conflicts. | Protect physical encounter-site semantics; do not copy nominal sett XY. | **OPEN** | — |
| `SPATIAL-GRID` | Multiple | 594 grid precision warnings in current WECS clean view. | Keep resolution flags; do not present grid cell as precise individual position. | **OPEN** | — |
| `SPATIAL-SETT-XY` | Multiple | Named sett and outlier coordinates pending from field team. | Do not invent XY; keep unresolved and provenance flags. | **WAITING_FIELD_TEAM** | — |
| `DEATH-014D` / 014D | 8880, 9767 | Trap-numbering wording incorrectly interpreted as euthanasia. | Routine capture, presumed released. | **RESOLVED** | Outcome PRESUMED_RELEASED; words put down describe trap numbering, not killing. |
| `DEATH-024Y` / 024Y | 16882, 16817 | Same-day found-in-extremis and PM; one euthanasia. | One euthanasia episode; PM is companion, grid site is approximate. | **RESOLVED** | Confirmed same event. Link live 16882 to PM 16817; count one death and preserve both rows. |
| `DEATH-D061` / D061 | 14170, 14171 | RTA initially misclassified as death, with later live captures. | Not confirmed fatal; RTA retained, outcome presumed released. | **RESOLVED** | Correct record 14170 to PRESUMED_RELEASED; do not censor at July 1998. |

## How to complete a flag

`OPEN` = newly identified or unadjudicated; `NEEDS_SOURCE_CHECK` = examine original Access, field book, tattoo/tag or PM paper record; `WAITING_FIELD_TEAM` = geographical data pending; `RESOLVED` = final decision recorded and implemented. **Never mark RESOLVED without a final_decision.** The current interpretation is provisional, whereas the final decision is the approved statement. Individual capture ID references stay attached.

Example (maintainer only):

```sql
update research.wecs_review_flags
set review_status='RESOLVED',
    final_decision='DOCUMENT THE EVIDENCE-BACKED FINAL DECISION',
    final_decision_at=now(), updated_at=now()
where flag_id='DEATH-U005';
```

**Only run after updating corresponding classification/identity/episode logic and documenting it in a new versioned Git SQL migration.** The statement above is a TEMPLATE, not an approved resolution. Reviewer should record the source evidence in the master audit. Never reassign a PM death to a later trapped individual based on matching tattoo alone when records conflict.

## Non-negotiable outcomes

- 024Y capture 16882 and PM 16817: **one CONFIRMED euthanasia episode** on 2014-08-14. Two source records remain in the capture table; PM companion excluded from independent episode count.
- D061 14170: original RTA is **not** a confirmed terminal death; subsequent live captures documented.
- 014D 8880: 'both put down as trap 1' refers to **trap numbering**, not euthanasia; original release assessment Fit.
- U005 and 020D: record the PM deaths, but do not use them as undisputed terminal outcomes for the currently linked tattoos until source identity is settled.
- W023 and Q082: later found-dead entries are **not live recaptures**. Assess whether duplicate reports refer to the same carcass.
- Confirmed mortality is retained without XY; coordinates and biological fate are independently assessed.

## Exact live check

```sql
select flag_id,category,tattoo,capture_ids,summary,
       current_interpretation,review_status,final_decision,final_decision_at
from analysis.wecs_review_flags_v1
order by review_status,flag_id;
```
