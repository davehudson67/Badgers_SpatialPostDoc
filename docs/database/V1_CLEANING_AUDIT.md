# Woodchester badger database — V1 cleaning audit

I've recorded the decisions and SQL behind the cleaned version here. Original Access imports are kept in `access_raw`, so the historical entries can always be checked. My V1 release column guide is in [V1 Release Notes](V1_RELEASE_NOTES.md).

## What I've changed

| Area | Rule or decision | SQL reference |
|---|---|---|
| Individual identity | I use tattoo as the scientific identifier and retain internal individual IDs solely for joins. | Versioned original migration scripts in `sql/migrations/` |
| Sex | `sex_clean`: trim and uppercase MALE/FEMALE; other or blank values become UNKNOWN. I retain `sex`. | `woodchester_v1_minimal_clean_columns_20261026.sql` |
| Age at first capture | `age_first_capture_clean`: CUB/YEARLING/ADULT; other or blank become UNKNOWN. I retain the original field. | Same migration |
| Sett names | `sett_name_clean` follows a confirmed canonical sett ID. Unresolved entries stay NULL; the original recorded string is retained. | `woodchester_v1_minimal_clean_columns_20261026.sql`; `woodchester_v1_clean_names_trigger_20261026.sql` |
| Social groups | `social_group_name_clean` is the canonical label associated with the **recorded** social group ID, not proof of residence. | Same clean-name migrations |
| Coordinates | I retain original sett evidence and distinguish mapped sett locations from provisional PM grid-square corners, with their sources. | V1 coordinate matching and PM grid migrations in `sql/migrations/` |
| Captures | I brought the sampling, welfare assessment and collar fields into `research.captures`. | `woodchester_v1_consolidate_capture_fields_20261026.sql`; `woodchester_v1_retire_split_capture_detail_tables_20261026.sql` |
| Analysis views | I have created five useful views. Legacy/internal SQL views were moved to `internal_v1` so their definitions and dependencies remain available. | `woodchester_v1_minimal_public_schemas_20261026.sql` |
| Code lists | I removed three tiny standalone tables after recording their entries here; I retained actual assay measurements and historical many-to-one/many-to-many relationships. | `woodchester_v1_remove_redundant_code_lookups_20261026.sql` |

## Historical code lists now documented instead of stored as tables

**DPP sample types:** Serum Fresh; WB Field; Whole Blood; Serum Frozen.

**DPP visual line results:** N = Negative; Nx = NegativeX; P = Positive; Px = PositiveX. I haven't inferred a biological interpretation of the 'X' qualifier.

**Stat-Pak results:** N = Negative (display order 1); P = Positive (2); C = No Clotted Sample (3).

## Checks

I checked that `research.captures` and the retained combined capture view have 17,586 distinct capture IDs. The previous sampling, assessment and collar data had unique capture IDs and were copied into the main capture table before removing the split copies. Checks found no differences in sampling time, collar transmitter and adverse-effects fields.


For full executable details I use the SQL migrations rather than duplicating code in this narrative. They also preserve the intermediate rules and corrections behind V1.



## Condition and ear-tag categories

I preserve the recorded `condition` and `eartags` columns and use generated cleaned fields for unambiguous variants. In `condition_clean`, V.GOOD → VERY GOOD (700 records), alongside 1,068 original VERY GOOD records. Other categories are FAIR (4,789), GOOD (8,809), POOR (1,281); missing remains NULL (939). In `eartags_clean`, NEITHER, NONE, NOT TAGGED and the encoding variant NOT TAGûGED → NONE; RETAGGEûD → RETAGGED; BOTH, LEFT, RIGHT and REMOVED remain separate. I don't equate REMOVED with NONE. Source values are unchanged. SQL: `sql/migrations/woodchester_v1_standardise_condition_and_eartags_20261026.sql`.


## Collar and ELISA label standardisation

I added `research.captures.collar_transmitter_clean` as a generated field: FIT/FITTED → FITTED; PRES/PRESENT → PRESENT; REPL/REPLACED → REPLACED. REMOVAL and LOST remain separate. The cleaned distribution is FITTED 668, PRESENT 355, REPLACED 193, REMOVAL 127, LOST 29 and NULL 16,214. The original field is unchanged.

I added `research.elisa_tests.test_result_clean` as a generated field: NO SERA/NO SERUM → NO SERUM. All other recorded codes, including I, ITT and BIT, remain unaltered; no clinical interpretation is inferred. Counts: N 13,297, P 1,554, I 163, ITT 15, BIT 2, NO SERUM 99, NULL 32.

SQL: `sql/migrations/v1_collar_label_normalisation_20261026.sql` and `sql/migrations/v1_elisa_result_label_normalisation_20261026.sql`.
