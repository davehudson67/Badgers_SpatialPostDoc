# Canonical sett–territory–social-group reconstruction (2026-10-23)

## Data sources and authority

- `research.setts`: **canonical sett_id / sett_name**, but **no coordinate columns** as checked against the live schema.
- `research.captures.sett_id`: canonical key connecting capture to sett. `recorded_social_group_id` is a **capture observation**, not annual residency.
- `research.sett_social_group_history`: dated associations, with validity and notes. Neither every sett-year nor every mapped polygon necessarily has such an association.
- `data/WoodchesterSettLocations.csv`: existing BNG coordinate source (historical labels). **Coordinate authority must be reviewed independently**; it is not identical to the full canonical sett register.
- `outputs/social_group_boundary_audit/annual_territories.gpkg`: annual 1977–2025 geometry in EPSG:27700. Polygon row IDs are annual only.

## Verified live database audit

Read-only SQL confirmed 178 canonical setts, 17,586 captures, 16,340 captures linked to `sett_id`, and 173 historical sett–SG relationship rows, as of 2026-10-23. The first join must establish how many canonical setts have unique clean-name matches to BNG coordinates; those numbers were **not** guessed or prematurely accepted.


## Live RStudio connection (recommended)

Exeter runs a persistent RStudio session. In the Supabase dashboard for the Woodchester project, choose **Connect → Session pooler** (port **5432**, IPv4-supported). Copy the **exact host and user from the dashboard**; do not invent a regional pooler hostname. Ideally create a database role with SELECT-only permissions on the specific research tables needed by the spatial analysis. A general database-admin account is not truly read-only even when the script sets a read-only session.

In Exeter, edit the private user-level `~/.Renviron` (outside this Git repo) using `usethis::edit_r_environ()`, adding:

```text
SUPABASE_DB_HOST=THE_EXACT_SESSION_POOLER_HOST
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=THE_EXACT_USERNAME_FROM_CONNECT
SUPABASE_DB_PASSWORD=YOUR_DATABASE_PASSWORD
```

**Do not paste filled-in credentials into GitHub, chat or logs.** Restart the R session after editing; R automatically loads `~/.Renviron` at startup. Make sure this file is readable only by your own account (`chmod 600 ~/.Renviron`). The connection helper enables TLS (`sslmode=require`) and a read-only SQL session.

From the repository root:

```bash
git pull --ff-only
Rscript -e 'install.packages(c("DBI", "RPostgres"))' # only if missing
Rscript scripts/Spatial/09_test_supabase_connection.R
SUPABASE_SOURCE=live Rscript scripts/Spatial/09_canonical_sett_id_territory_SG_audit.R \\
  2>&1 | tee logs/canonical_sett_territory_audit.log
```

For a local/offline fallback, set `SUPABASE_SOURCE=snapshot` and use the four CSVs detailed below. **The 09 script now defaults to live mode.**

If the connection test fails, check DNS/reachability on port 5432, whether Exeter can connect outside its firewall, the username format (pooler users usually include the project reference), and the password. Supabase direct `db.<project-ref>.supabase.co:5432` may require IPv6 and should not automatically be assumed reachable from Exeter.

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
