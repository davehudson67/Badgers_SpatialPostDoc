# Access → research migration parity audit — 2 November 2026

**Status: PARTIAL VERIFICATION, NOT FIELD-BY-FIELD SIGN-OFF**

I compared current `access_raw` import tables with `research` tables using read-only SQL, with no updates to data.

## Whole-table record counts
| Access | Research | Both counts | Result |
|---|---|---:|---|
| tbl_badger | individuals | 3,791 | Equal |
| tbl_captures | captures | 17,586 | Equal |
| tbl_culture | cultures | 48,699 | Equal |
| tbl_elisa | elisa_tests | 15,162 | Equal |
| tbl_dpp_test | dpp_tests | 3,316 | Equal |
| tbl_stat_pak | stat_pak_tests | 2,851 | Equal |
| tbl_brock_test | brock_tests | 1,648 | Equal |
| tbl_ifn_gamma_elisa | ifn_gamma_elisa | 4,375 | Equal |
| tbl_wounds | wounds | 1,636 | Equal |

The original Access sett lookup contains **173** rows and the working `research.setts` table contains **176**. This difference is expected from earlier migration and subsequent additions, but requires independent name/identity/coordinate review rather than automatic acceptance. Both original and research social-group tables contain **45** records.

## Record-group parity checks completed
Grouping is an exact **multiset comparison**, meaning that duplicate group counts are considered; matching counts do not require uniqueness of a tattoo/date pair.

1. Capture records: `UPPER(TRIM(tattoo)) + capture_date::date` — **0 mismatched groups or records** between original Access and joined research captures.
2. Capture records: tattoo + date + `UPPER(TRIM(moc))` + normalized PM flag — **0 mismatches**.
3. Capture records: tattoo + date + recorded sett + recorded social-group text + method (all compared as uppercase trimmed text) — **0 mismatches**.
4. Culture specimens: tattoo + capture date — **0 mismatched groups or records**.
5. ELISA tests: tattoo + capture date — **0 mismatches**.
6. Wound records: tattoo + capture date — **0 mismatches**.

These checks use `research.individuals` for tattoo identity and `research.captures` for the date and foreign-key links of research assays. They would detect missing, extra or date/individual-mislinked records **at those group levels**, but cannot detect every sample-type, assay-result, wound-detail or other field discrepancy within a matching group.

## Existing documented exceptions/interpretations
- Four raw culture records `040l` (lowercase final letter) are represented by the canonical research tattoo `040L` through their linked capture. The raw strings remain unchanged; see `V1_CLEANING_AUDIT.md`.
- Sett and social-group names and inferred locations are **provisional**. Read-only parity of `recorded_sett_name` and `recorded_social_group_name` does not prove correct canonical ID assignment.
- `UN` prefix animals should be preserved in raw data; handling for movement, survival and disease analyses must be determined separately.

## Outstanding before a signed-off one-to-one audit
- Match **each raw Access row to one unique research row**, ideally using a durable `source_raw_row_id` crosswalk; where that does not exist, derive a documented matching key including sample identity and duplicates.
- Compare **all shared raw fields** with type-aware canonicalization (original string, null versus blank, dates, numeric parsing) and publish an exception report with raw row ID, research row ID, field, source value and migrated value.
- Audit individual sex, age and tattoo fields; DPP, Stat-Pak, Brock and IFN-gamma tests **beyond totals**; culture/ELISA/wound individual fields **beyond grouped counts**.
- Validate every foreign key and check for duplicate, orphaned or ambiguous record mappings.
- Reconcile 173 Access sett entries to 176 working named sett records and the 168-entry XY source; inspect social groups separately.
- Independently verify that `access_raw` is a complete faithful import of **original Microsoft Access files**, not just the source tables now stored in Supabase. Direct Access file checks remain necessary for end-to-end assurance.
- Retain all exceptions and cleaning decisions, then freeze an approved and reproducible release.

**Conclusion:** Counts match for all nine main paired datasets and the tested record-group combinations show zero differences. This is substantial evidence of migration parity for those fields, **not yet proof of complete one-to-one fidelity for every column or source record.**
