# Canonical sett–territory–social-group reconstruction (2026-10-23)

## Data sources and authority

- `research.setts`: **canonical sett_id / sett_name**, but **no coordinate columns** as checked against the live schema.
- `research.captures.sett_id`: canonical key connecting capture to sett. `recorded_social_group_id` is a **capture observation**, not annual residency.
- `research.sett_social_group_history`: dated associations, with validity and notes. Neither every sett-year nor every mapped polygon necessarily has such an association.
- `data/WoodchesterSettLocations.csv`: existing BNG coordinate source (historical labels). **Coordinate authority must be reviewed independently**; it is not identical to the full canonical sett register.
- `outputs/social_group_boundary_audit/annual_territories.gpkg`: annual 1977–2025 geometry in EPSG:27700. Polygon row IDs are annual only.

## Verified live database audit

Read-only SQL confirmed 178 canonical setts, 17,586 captures, 16,340 captures linked to `sett_id`, and 173 historical sett–SG relationship rows, as of 2026-10-23. The first join must establish how many canonical setts have unique clean-name matches to BNG coordinates; those numbers were **not** guessed or prematurely accepted.


## Existing RStudio database connection (recommended)

Use the project's established `scripts/BadgerDatabase.R` helper, which defines `badger_db_connect()` and reads `BADGER_DB_HOST`, `BADGER_DB_PORT`, `BADGER_DB_NAME`, `BADGER_DB_USER`, and `BADGER_DB_PASSWORD`. This is already used by `DataPrep_fromSupaBase.R`; do not configure a second connection. Credentials remain in your private environment, not in Git. Script 09 and the smoke test both source this existing helper and set their SQL session to read-only before querying. A dedicated SELECT-only DB account remains preferable.

```bash
git pull --ff-only
Rscript scripts/Spatial/09_test_supabase_connection.R
SUPABASE_SOURCE=live Rscript scripts/Spatial/09_canonical_sett_id_territory_SG_audit.R \\
  2>&1 | tee logs/canonical_sett_territory_audit.log
echo "EXIT STATUS: ${PIPESTATUS[0]}"
```

If it fails, compare the process environment with your existing working `DataPrep_fromSupaBase.R` session; never print passwords. In RStudio, `Sys.getenv('BADGER_DB_HOST')` and `Sys.getenv('BADGER_DB_USER')` can confirm whether the connection variables are present without displaying a password.

## Offline execution (no database connection)

Script 09 now reads four local CSV files from `data/local_supabase_snapshots/`:

- `setts.csv`: `sett_id,sett_name,notes` from canonical setts
- `groups.csv`: `social_group_id,social_group_name`
- `history.csv`: `sett_id,social_group_id,valid_from,valid_to,notes`
- `captures_annual_aggregate.csv`: `year,sett_id,recorded_social_group_id,n_captures`, aggregated from non-postmortem captures during 1977–2025 by year, canonical sett ID and recorded SG ID. Retain NULL SG categories.

Export these tables through Supabase SQL Editor using read-only SELECT queries and download each result as CSV. The capture aggregate must exclude captures with NULL sett_id. Keep local snapshot CSVs uncommitted and handle as restricted research data. They are **not** automatically refreshed.

```bash
git pull --ff-only
mkdir -p data/local_supabase_snapshots logs
# Place the four exported CSV files in data/local_supabase_snapshots/
Rscript scripts/Spatial/09_canonical_sett_id_territory_SG_audit.R \\
  2>&1 | tee logs/canonical_sett_territory_audit.log
echo "EXIT STATUS: ${PIPESTATUS[0]}"
```

Review `00_source_audit_summary.csv`, `04_canonical_coordinate_match.csv`, `10_all_sett_year_status.csv`, `14_annual_polygon_review_worklist.csv` and `15_annual_observed_coverage.csv` in `outputs/canonical_sett_SG_territory_crosswalk/`.

The aggregate represents linked captures only. The summary cannot infer a full unmatched-capture count from it; missing-coordinate and missing-sett-ID cases remain separate.

## Interpretation safeguards

1. **Master geographic network versus contemporaneously observed setts:** a sett is 'observed' only if it has at least one non-postmortem capture in that year. No capture does not establish biological absence, and trap effort is not measured here.
2. **Missing coordinate versus outside polygon:** only setts with coordinates can be assessed as outside.
3. **Overlap:** retain every polygon containing the coordinate, including boundary-touching cases. Distinguish boundary topology from real ranging.
4. **Stable biological ID:** use canonical `sett_id` in joins, never raw or cleaned labels alone. Clean-label correspondence is used strictly as an **audited coordinate join**, not as a social affiliation rule.
5. **Territory name:** changes in source field names (Sett, SETT, SocialName, Social_grp) do not prove an independent SG identity; the original year/label/geometry are preserved.
6. **Observed SG:** a capture's recorded SG does not by itself prove residency. Use the separately implemented Vicente annual resident-group assignment for individual residency.
7. **Infection spread:** a potential interterritory movement is not evidence of onward transmission. Analyses require source infection/infectiousness, recipient infection, timing, and uncertainty in annual group membership.

Script 09 supersedes scripts 07/08 for canonical-ID-based evidence. Those earlier scripts are retained unchanged as provenance. **Do not merge newly inferred group IDs into the research schema** without evidence review.

Run outcome is not yet verified on Exeter; R is unavailable in this assistant's environment.
