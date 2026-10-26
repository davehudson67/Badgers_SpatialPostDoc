# Woodchester database — V1 release notes

**Status:** Preparing V1, 26 October 2026. This is the authoritative user-facing V1 release guide, replacing separate coauthor audit reports. Definitions not checked against the original Access documentation remain explicitly provisional.

## Design

| Schema | Meaning | Coauthor access |
|---|---|---|
| `access_raw` | 12 preserved original Access imports and provenance | Not shared by default |
| `research` | 28 relational, cleaned/source-preserving tables: badgers, captures, sampling, tests, setts, group relationships and spatial evidence | Read-only on 25 curated tables |
| `analysis` | 24 current views for joins, standardised traits/tests, locations and probabilities | Read-only |
| `ingest` | 4 technical importer / audit / baseline tables | Maintainers only |

Both custom coauthor roles (`badger_readonly` and `badger_research_readonly`) now have SELECT on the 25 curated research tables and all analysis views, without INSERT/UPDATE/DELETE permissions. Three research source/import tables stay outside coauthor access: `infection_probabilities_import`, `infection_quarterly_import`, and `sett_coordinate_source_20261023`. Actual account/login privileges, schema access and view security still need end-to-end testing.

**Recommended entry points**: `analysis.capture_history_v1` for one record per capture/PM event, `analysis.capture_traits_v1` for sex/age traits, `analysis.capture_location_v1` for spatial interpretations, `analysis.sett_inventory_v1` for sett coordinates, `analysis.diagnostic_results` for tests, and the cleaned base tables in `research` when detail is needed.

## Definitions and key joins

- `research.individuals`: scientific identity is `tattoo`; `individual_id` is an internal joining key.
- `research.captures`: `capture_id` uniquely identifies an event; `individual_id` links it to the badger. Source fields `recorded_sett_name`, `recorded_social_group_name`, `capture_location_text` and `os_ref` are preserved.
- `research.setts`: canonical identities and `sett_id`; never infer a sett from a road/field/PM recovery grid.
- `sett_name` (V1 views): canonical sett name or **NULL** when not established. `recorded_sett_name`: literal historical text, which can describe non-sett places.
- `location_type`: `SETT`, `PM_GRID_REFERENCE`, `PM_LOCATION_UNRESOLVED`, `UNMATCHED_CAPTURE_LOCATION`, or `NOT_RECORDED`. `location_class` is more specific.
- `location_easting`/`location_northing`: either a mapped canonical sett position or the **south-west corner of a provisionally decoded PM recovery grid square**; distinguish via `location_coordinate_basis`. This is not necessarily a measured recovery point.
- `research.capture_sampling`, `capture_assessments`, `capture_collars`, `wounds` and diagnostic tables join to `research.captures` by `capture_id`; verify multiplicity before combining.
- `research.sett_social_group_history` and `social_group_supergroup_history` are date-dependent. Recorded SG is not proof of inferred residence.
- `research.infection_probabilities` and `infection_quarterly_probabilities` store **model outputs**, distinguished by model variant and run, not observed test results.

## V1 baseline results

17,586 distinct capture/PM events. 16,337 have canonical setts; 710 have provisionally interpretable PM recovery grids but **no sett assigned**; 343 PM locations remain unresolved; 170 non-PM recorded locations unmatched; 26 locations not recorded. There are 176 canonical setts; 159 have linked coordinate evidence. Historical aliases such as TOP SETT/TOP and GULLY/GULLEY have already been reconciled in versioned cleaning logic without overwriting the recorded source.

## Current analysis views: their purpose

| View | Purpose | Release role |
|---|---|---|
| `capture_history_v1` | Capture history with shared V1 location columns | **Primary** |
| `capture_traits_v1` | Capture-level sex/age standardisations plus V1 location | **Primary** |
| `capture_location_v1` | Sett identity versus recovery grid and unresolved locations | **Primary** |
| `sett_inventory_v1` | Canonical sett coordinates, provenance and capture counts | **Primary** |
| `diagnostic_results` | All original diagnostic test records in a common structure | **Primary** |
| `individual_traits_standardised` | Individual-level sex and age standardisations | Useful |
| `capture_diagnostic_summary_standardised` | Capture-level diagnostic result counts and any-positive indicator | Useful |
| `culture_results_standardised` | Culture result interpretations | Useful |
| `diagnostic_interpretation_standardised` | Long-format interpreted diagnostic results | Useful |
| `stat_pak_results_standardised` | Standardised Stat-Pak results | Useful |
| `sett_social_group_observed` | Observed sett–SG by year, not residency | Useful |
| `sett_coordinates_approved` | Mapped named sett coordinates | Useful |
| `infection_probabilities` | Modelled infection probability by event | Useful |
| `infection_quarterly_probabilities` | Modelled infection probability by quarter | Useful |
| `capture_infection_probabilities` | Wide-format probability comparisons at capture | Useful |
| `capture_history` | Original joined capture view without V1 spatial fields | Legacy compatibility |
| `capture_traits_standardised` | Traits without V1 spatial fields | Legacy compatibility |
| `capture_location_fields_v1` | Shared classification fields inserted into V1 views | Internal helper |
| `capture_location_classified_v2` | Historical text with embedded PM grid parsing | Internal dependency |
| `capture_location_classified_v3` | ST/SO PM grid parsing | Internal dependency |
| `capture_pm_grid_reference_review` | Earlier numeric reference parsing logic | Internal dependency |
| `capture_sett_coordinate_inventory` | Sett capture totals and spatial lookup | Internal dependency |
| `sett_coordinate_source_name_review` | Match imported coordinate names to canonical names | Internal dependency |
| `sett_coordinate_unmatched_v1` | List of unresolved imported coordinate names | Deferred review |

**What could we remove?** The seven standalone audit views were already removed in October 2026. The six internal analysis helpers above cannot simply be deleted because V1 outputs still depend on them. They could be folded into fewer definitions after an explicit dependency and model-script test. The original Access, cleaned research tables, test detail, coordinate provenance and versioned SQL history should **not** be deleted. The legacy analysis capture views should also remain until all running code is migrated.

## Cleaned research tables and their purpose

| Table(s) | Record meaning |
|---|---|
| `individuals`, `individual_names` | Canonical badger and historical name aliases |
| `captures`, `capture_sampling`, `capture_assessments`, `capture_collars` | Capture event and associated sampling, health and collar records |
| `wounds` | Wound records linked to event |
| `setts`, `sett_location_evidence` | Canonical sett identity and coordinate evidence |
| `social_groups`, `supergroups`, `sett_social_group_history`, `social_group_supergroup_history` | Names and dated group relationships |
| `cultures`, `elisa_tests`, `ifn_gamma_elisa`, `stat_pak_tests`, `brock_tests`, `dpp_tests` | Separate assay records; preserve original test codes and detail |
| `disease_statuses`, `dpp_sample_types`, `dpp_visual_line_results`, `stat_pak_results` | Assay/status lookups |
| `infection_probabilities`, `infection_quarterly_probabilities` | Clearly-labelled model probability data |
| `infection_probabilities_import`, `infection_quarterly_import`, `sett_coordinate_source_20261023` | Internal import provenance, not curated coauthor tables |

## Data dictionary contract

For every V1 object, the database's actual column names and PostgreSQL data types are authoritative; the separately maintained `DATA_DICTIONARY.md` remains the working field glossary until all definitions and units can be verified directly against the source Access codebook. Columns that appear in multiple views retain their underlying meaning. Standardisation flags are distinct from original recorded values; test-result interpretation and age approximations are **derived**, never silently substituted for observations.

This release document is the only **release/audit narrative**. The dictionary and governance pages are reference appendices, not competing release-note versions. Their older exploratory audit sections must not be treated as current API guidance.

## Still pending before sharing externally

1. Source-to-research parity and full column units/code definitions need a verified Access codebook pass.
2. Test actual coauthor authentication, least privilege and ability to query both schemas without write access.
3. Spatial validation remains open: 16 coordinate-less named setts, nine unmatched coordinate-source names, historic ST/SO anomalies, 170 unmatched non-PM events and other PM descriptions.
4. Review scripts that may use legacy views before any future internal dependency refactor.
5. Annual SG territory centres, if used later, must be explicitly recorded as *imputed territorial proxy positions*, never as original capture locations or sett coordinates.

**Provenance:** All actual transformations remain reproducible using the original `access_raw` tables, source-backed columns, and versioned `sql/migrations/`. The existing baseline register retains label **V1**.
