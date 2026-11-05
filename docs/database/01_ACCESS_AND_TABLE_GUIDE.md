# 01 — Woodchester database: quick access and table guide

**Updated 4 November 2026.** Start here if you simply want to query the clean badger data. For every field, see [02 — Master Dictionary and Audit](02_MASTER_DATA_DICTIONARY_AND_AUDIT.md). For cleaning and migrations, see [03 — Versioning](03_VERSIONING_AND_DECISIONS.md). Outstanding issues: [Live review flags](https://github.com/davehudson67/Badgers_SpatialPostDoc/blob/audit-tattoo-identifier/docs/database/WECS_FLAGGED_INCONSISTENCIES_2026_11_04.md).

## Getting access in one minute

Ask the database maintainer for an **individual read-only PostgreSQL/Supabase account**. `badger_readonly` is intended for analysis views; `badger_research_readonly` is for approved research tables too. Exact permissions on newly created views must be verified by the maintainer; a view's presence does not itself grant you access.

Add the settings to a local **`.Renviron`**, never to a committed script or public email. Use the repository `.Renviron.example`:

```text
BADGER_DB_HOST=YOUR_SUPABASE_SESSION_POOLER_HOST
BADGER_DB_PORT=5432
BADGER_DB_NAME=postgres
BADGER_DB_USER=YOUR_PERSONAL_READ_ONLY_USERNAME
BADGER_DB_PASSWORD=YOUR_PRIVATE_PASSWORD
```

Restart R, then:

```r
install.packages(c("DBI","RPostgres","dplyr","dbplyr")) # once
library(DBI); library(RPostgres); library(dplyr); library(dbplyr)
con <- dbConnect(
  RPostgres::Postgres(),
  host=Sys.getenv("BADGER_DB_HOST"),
  port=as.integer(Sys.getenv("BADGER_DB_PORT", unset="5432")),
  dbname=Sys.getenv("BADGER_DB_NAME", unset="postgres"),
  user=Sys.getenv("BADGER_DB_USER"),
  password=Sys.getenv("BADGER_DB_PASSWORD"),
  sslmode="require"
)
dbGetQuery(con,"select current_user, current_database();")
captures <- tbl(con,in_schema("analysis","encounters_clean_v1"))
head(collect(captures))
dbDisconnect(con)
```

## What to use

| Table or view | What it is | When to use it |
|---|---|---|
| **`analysis.encounters_clean_v1`** | **Recommended** clean encounter/spatial view; 17,586 source records, 13 columns (7 identifiers + 6 cleaned fields) | When you need trapping, outcome or location without wading through raw notes |
| `analysis.capture_history_v1` | Longitudinal source-rich captures, samples, historical SG, age/sex and original descriptions | Biological covariates and model-specific histories; do not confuse PM with live capture |
| `analysis.diagnostic_results` | Long-format diagnostic results (multiple possible per capture) | Disease testing; join carefully on `capture_id` |
| `analysis.capture_infection_probabilities` | Existing capture-level predicted infection probabilities | Models using derived disease-state information |
| `analysis.mortality_events_review_v1` | Death evidence, 1,304 recorded event rows (430 missing XY) | **Review** before using terminal outcomes; two tattoo conflicts and possible duplicate deaths remain |
| `analysis.mortality_model_candidate_v1` | 1,304 recorded death rows: 1,300 candidate terminal events and four held identity/repeat cases | Cautious model-event input; NOT final signed-off survival dataset |
| `analysis.grid_withheld_candidate_review_v1` | All 40 withheld grid cases, including 30 **test-only** 100 km-shift positions and two specifically rejected sites | Map candidate positions before any further approved XY change |
| `analysis.spatial_missing_review_v1` | **981 source rows lacking accepted XY**, grouped into seven evidence/review categories | The main queue for continuing spatial cleanup; retains outcomes and original notes |
| `analysis.grid_reference_audit_v1` | Original/corrected coordinates for 57 provisionally corrected and 40 withheld grid locations | Check source references and spatial uncertainties |
| `analysis.wecs_review_flags_v1` | Current open and resolved inconsistency register | Check whether a record is trusted or needs review |
| `analysis.capture_sett_alias_audit_v1` | Approved capture-specific historical sett-name aliases | Find name changes and why a coordinate is or is not applied |
| `research.captures` | Canonical linked capture/PM source data | Audit original method, sampling notes, PM cause; advanced read-only |
| `research.setts` | Canonical sett inventory; current XY where supported | Name and coordinate lookup; named missing-XY setts remain |
| `access_raw.*` | Twelve originally imported Access source tables | Strict provenance checks, not standard collaborator analysis |

The live database has additional specialist tests, wounds, lookup tables, analysis views and internal research decision tables. The master dictionary inventories **all** live tables and columns.

**Map review (5 Nov 2026):** 57 corrected points are marked **VISUALLY_VERIFIED** for geographic plausibility. They remain scientifically provisional (not surveyed-accurate). Two previously corrected outliers, UN260 and F030, are rejected and withheld. The next review is 30 **test-only** 100 km shifts, with no accepted XY assigned automatically.

**Latest OS-grid check:** 57 provisional grid interpretations; 40 withheld, including UN260 and F030 rejected by the investigator; 107 sett-versus-physical capture-site conflicts deliberately kept without XY. Mortality remains available independently.

## Important biological rules

- **Tattoo** is the scientific badger identifier; `capture_id` is a source record ID. `individual_id` is an internal DB key; don't analyse it as a separate identifier.
- `is_pm=true` identifies a source PM-coded row. **Seventeen field/PM pairs are confirmed as single episodes**. `024Y` on 2014-08-14 is one euthanasia, represented by source rows 16882 and 16817. For independent events exclude `episode_record_role='PM_COMPANION'`.
- A **confirmed death remains mortality data even with XY missing**. Missing location never converts death to live censoring. Conversely, `RTA` in the original method field does **not automatically mean fatal**.
- Coordinates may be actual recovery sites, provisional sett-centre proxies or coarse grid-square corners. Read `location_type` **and** `location_quality`; don't equate a social group or last known sett with where a carcass was recovered.
- `UN` tattoos should not receive a social-group assignment by inference.
- The mortality review is **not yet a signed-off survival input**: U005 and 020D have PM deaths but later live captures and require source-ID review.

**Seven additional confirmed same-event deaths:** 001R, 017R, 045W, D007, I022, M012 and Q070. Field and PM source records are retained, but PM companions must not be counted as additional death events. D007 died under anaesthetic; its original field note explicitly explains the one-day PM-date offset. Only W023 and Q082 still have possible repeat-death entries.

## Common safe queries

```sql
-- What happened to this tattoo?
select * from analysis.encounters_clean_v1
where tattoo='024Y'
order by capture_date,capture_id;

-- One row per source record, see method/fate/location quality
select outcome,location_quality,count(*)
from analysis.encounters_clean_v1
group by 1,2 order by 1,2;

-- Mortality events without map XY STILL COUNT as recorded deaths
select capture_id,tattoo,recorded_event_date,mortality_outcome,mortality_review_status
from analysis.mortality_events_review_v1
where location_easting is null or location_northing is null;

-- Open data quality issues
select * from analysis.wecs_review_flags_v1
where review_status <> 'RESOLVED';
```

**Close connections when finished.** Never edit source data or share credentials. If a newly created view produces permission denied, ask the maintainer to grant SELECT to your read-only role.
