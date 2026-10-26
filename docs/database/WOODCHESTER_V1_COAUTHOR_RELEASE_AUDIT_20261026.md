# Woodchester Supabase — V1 coauthor release audit (26 October 2026)

**Status:** Working V1, ready for coauthor read-only review of the existing research data; unresolved spatial locations and formal methodological validation remain flagged. The label V1 has not been incremented.

## Which schemas mean what?

| Schema | Contents | Coauthor recommendation |
| --- | --- | --- |
| `access_raw` | 12 original Access-source tables, retained as provenance | Do not edit; not the analytical interface |
| `research` | 28 canonical and source-evidence tables | Read-only specialist access when provenance/detail is needed |
| `analysis` | 24 analytical views, including stable V1 capture and location views | Default access for coauthors |
| `ingest` | 4 ingestion, audit and baseline-register tables | Maintainers only |

**Main starting points:** `analysis.capture_history_v1`, `analysis.capture_traits_v1`, `analysis.capture_location_v1`, `analysis.sett_inventory_v1`, plus existing diagnostic and infection analysis views. Historical `analysis.capture_history` / `analysis.capture_traits_standardised` remain to protect existing analysis scripts, but V1 readers should use their `_v1` counterparts.

The V1 location standard: `sett_name` is null when there is no confirmed canonical sett. `location_type` and `location_class` identify named sett vs provisional grid-referenced PM recovery vs unresolved capture location. `location_easting`/`location_northing` for a PM grid square are its **south-west corner**, not a measured capture position and never a sett point. No historical recorded names, capture IDs, or original text were rewritten.

## Structural and consistency checks performed

- `analysis.capture_history_v1`: **17,586 rows / 17,586 unique capture IDs**.
- `access_raw`: **12 source tables**; `research`: **28 base tables**; `analysis`: **24 views**; `ingest`: **4 internal tables**.
- **16,337** records classified as known sett, **710** as grid-referenced PM recovery, **343** other unresolved PM location, **170** unmatched non-PM capture location, and **26** location not recorded.
- Zero rows had `location_type='SETT'` with null canonical `sett_name`; zero grid-referenced PM rows had a non-null `sett_name`; zero live rows were classified as PM grid-reference.
- For the custom database roles audited, `badger_readonly` had SELECT on all 24 analysis views; `badger_research_readonly` had SELECT on all 24 analysis views and 25/28 research tables. Three intentionally withheld research tables are `infection_probabilities_import`, `infection_quarterly_import`, and `sett_coordinate_source_20261023` (import/source-staging).
- No direct `anon` or `authenticated` table SELECT grants were returned by the audited schema privileges query. **This is not a substitute for testing effective login roles, schema USAGE, inherited privileges and the Supabase API configuration before inviting external users.**

## Clean-up performed

Dropped seven independent interim analysis views in migration `sql/migrations/woodchester_v1_remove_redundant_review_views_20261026.sql`: `location_review_767_v1`, `historical_sett_candidates`, `sett_field_team_review`, `unmatched_capture_sett_review`, `unmatched_coordinate_sett_candidates`, `unresolved_recorded_sett_names`, and superseded `capture_location_classified`.

No research or raw table rows were deleted. Internal implementation dependencies (including the two older grid parsing classifier views and grid-source review view) were **retained** because the V1 public views still depend on them. These are not recommended coauthor entry points; consolidating their SQL later would be a separate version-controlled refactor.

## Still to verify before wider distribution

1. Test a real coauthor's **read-only** connection and least-privilege access: verify schema USAGE, SELECT, ability to access V1 views, and inability to UPDATE/DELETE; check view-security-definer and effective inherited grants, not just `information_schema` grants. Do not circulate service-role credentials.
2. Review research consent/data-sharing basis and any identifying or sensitive field exposure before supplying external access or extracts.
3. Verify remaining unmatched spatial records, grid-prefix conventions (`SO` versus `ST`), coordinate reference-system accuracy, territory-centre approximations and historical social-group mapping before publication-level spatial analyses.
4. Check downstream SQL/R scripts for references to the seven retired review views, if any; running model processes and existing research tables were not touched.
5. Validate source-versus-research field and table parity separately; not completed by this schema-level audit.

Historical decisions and the initial V1 cleaning rationale remain in `docs/database/WOODCHESTER_V1_BASELINE.md`, `docs/database/DATA_DICTIONARY.md`, and `docs/database/DATABASE_GOVERNANCE_AND_PROVENANCE.md`. Versioned migrations in `sql/migrations/` record each implemented change.
