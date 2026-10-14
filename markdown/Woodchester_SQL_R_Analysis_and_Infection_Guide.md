# Woodchester Badger Database — Detailed Technical, R and Infection Guide

**Updated:** 14 October 2026  
**Purpose:** Detailed reference for the Woodchester PostgreSQL/Supabase database, its cleaned relational structure, approved analysis views, R access, infection-probability outputs, and collaborator access model.

For a short collaborator quick-start, see:

- [Woodchester Badger Database — Quick Access Guide](Woodchester_Badger_Database_Access_Guide.md)

---

# 1. What the database is

The historic Woodchester badger data have been migrated from Microsoft Access into a PostgreSQL database hosted by Supabase.

The database is intended to be the **single centrally maintained source of the cleaned long-term dataset**. Work that used to be repeated independently in analysis scripts — Access conversion, identifier repair, historical naming cleanup, relational joins and canonical lookups — is now handled upstream in PostgreSQL wherever possible.

The general workflow is:

```text
Original Microsoft Access data
            ↓
       access_raw
            ↓
cleaning / relational reconstruction
            ↓
         research
            ↓
 analysis-ready database views
            ↓
         analysis
            ↓
      R / NIMBLE / GIS
```

This distinction is important:

- the database should contain **shared, reusable cleaning and structure**;
- analysis scripts should contain **analysis-specific biological decisions**.

For example, the database can standardise a sett name once, but an individual analysis may still decide whether to exclude post-mortem records, collapse same-day encounters, define quarterly occasions or calculate a particular age variable.

---

# 2. Database schemas

## `access_raw`

This is the preserved import of the original Microsoft Access database.

It exists primarily for:

- source auditing;
- checking how a historical field was originally recorded;
- resolving migration or cleaning questions;
- reproducing provenance when necessary.

It should **not normally be used as the starting point for a new analysis**.

## `research`

This is the cleaned relational layer.

It contains the canonical tables for individuals, captures, diagnostics, wounds, locations, sampling, assessments and model-derived infection outputs.

Normal collaborators do not currently have direct access to this schema.

## `analysis`

This contains the curated analysis-ready views.

This is the normal entry point for research users and the only data schema exposed to the current `badger_readonly` permission role.

---

# 3. Current access model

There are now two deliberately separate access levels.

## Administrator / maintainer access

The database maintainer uses the PostgreSQL `postgres` account.

This account is used for:

- migrations;
- correcting canonical data;
- creating or changing views;
- adding model-derived outputs;
- creating database roles;
- database administration.

The `postgres` password must never be shared with ordinary collaborators.

## Researcher access

A group role called:

```text
badger_readonly
```

has been created.

It currently has:

- permission to connect to the `postgres` database;
- `USAGE` on the `analysis` schema;
- `SELECT` on the seven approved analysis views;
- no `INSERT`, `UPDATE` or `DELETE` rights on those views;
- no access to the underlying `research` schema.

Each collaborator should receive an **individual PostgreSQL login role** that inherits `badger_readonly`.

Do not create one shared researcher username for the whole project.

A typical maintainer operation is:

```sql
create role researcher_name
with login
password '<long-random-password>';

grant badger_readonly to researcher_name;
```

The password should be generated securely and supplied separately from the repository.

---

# 4. Credential handling

Real credentials are not stored in Git.

The repository now contains:

```text
.Renviron.example
```

but the real:

```text
.Renviron
```

is ignored by Git and should exist only on the user's local machine or secure server environment.

A local file should contain:

```text
BADGER_DB_HOST=YOUR_SESSION_POOLER_HOST
BADGER_DB_PORT=5432
BADGER_DB_NAME=postgres
BADGER_DB_USER=YOUR_DATABASE_USERNAME
BADGER_DB_PASSWORD=YOUR_DATABASE_PASSWORD
```

Restart R/RStudio after changing `.Renviron`.

Never:

- commit a real `.Renviron`;
- paste the database password into an R script;
- print the password into logs;
- share the administrator `postgres` password with collaborators.

---

# 5. Connecting from R

Required packages:

```r
install.packages(c(
  "DBI",
  "RPostgres",
  "dplyr",
  "dbplyr"
))
```

A reusable connection helper can be defined as:

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

badger_db_connect <- function() {
  DBI::dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("BADGER_DB_HOST"),
    port = as.integer(
      Sys.getenv("BADGER_DB_PORT", unset = "5432")
    ),
    dbname = Sys.getenv(
      "BADGER_DB_NAME",
      unset = "postgres"
    ),
    user = Sys.getenv("BADGER_DB_USER"),
    password = Sys.getenv("BADGER_DB_PASSWORD"),
    sslmode = "require"
  )
}
```

Connect:

```r
con <- badger_db_connect()
```

Check the connection:

```r
DBI::dbGetQuery(
  con,
  "SELECT current_database(), current_user;"
)
```

Disconnect when finished:

```r
DBI::dbDisconnect(con)
```

---

# 6. How remote R queries work

Using `dbplyr`, this:

```r
captures <- tbl(
  con,
  in_schema("analysis", "capture_history")
)
```

does **not** immediately download the complete capture table.

Operations such as:

```r
captures |>
  filter(capture_year >= 2020) |>
  count(sex)
```

are translated into SQL and run in PostgreSQL.

Use:

```r
show_query()
```

to inspect the generated SQL.

Only when:

```r
collect()
```

is called is the result transferred into local R memory.

Recommended pattern:

```text
filter / select / group / summarise in PostgreSQL
                        ↓
                     collect()
                        ↓
              continue locally in R
```

This is particularly useful for the long diagnostic and infection-result tables.

---

# 7. Live analysis-view inventory

The current read-only layer contains seven approved views.

| View | Grain / purpose | Rows checked 14 Oct 2026 |
|---|---|---:|
| `analysis.capture_history` | One row per recorded capture | 17,586 |
| `analysis.diagnostic_results` | One row per diagnostic result | 76,051 |
| `analysis.capture_infection_probabilities` | One row per capture with infection-model outputs in wide form | 16,255 |
| `analysis.infection_probabilities` | One row per capture × infection-model variant | 97,530 |
| `analysis.infection_quarterly_probabilities` | One row per badger-quarter for the imported quarterly infection trajectory | 29,737 |
| `analysis.historical_sett_candidates` | Summary for historical sett/location review | 358 |
| `analysis.sett_social_group_observed` | Observed sett/social-group/year combinations | 2,156 |

These are the objects normal researchers should use.

---

# 8. `analysis.capture_history`

## Grain

One row per recorded capture.

Current live audit:

```text
Capture rows:          17,586
Individuals:            3,791
First capture:     1975-12-13
Last capture:      2026-08-11
Live rows:              16,298
PM rows:                 1,288
```

## Important fields

The view currently includes fields such as:

```text
capture_id
individual_id
tattoo
elect_tag
historical_names
n_historical_names
sex
age_first_capture
year_first_capture
capture_date
capture_year
capture_quarter
capture_occasion
is_pm
moc
recorded_sett_name
sett_id
normalized_sett_name
recorded_social_group_name
recorded_social_group_id
normalized_social_group_name
recorded_supergroup_name
capture_location_text
os_ref
disease_status
weight
body_length
temperature
toothwear
condition
reproductive_status
pm_status
pm_cause
sampling fields
assessment fields
collar fields
comment
```

Inspect the full current list programmatically rather than relying on a static document:

```r
DBI::dbListFields(
  con,
  DBI::Id(
    schema = "analysis",
    table = "capture_history"
  )
)
```

## Example

```r
captures <- tbl(
  con,
  in_schema("analysis", "capture_history")
)

capture_dat <- captures |>
  filter(
    capture_year >= 2014,
    capture_year <= 2018,
    !is_pm
  ) |>
  select(
    individual_id,
    capture_id,
    tattoo,
    capture_date,
    capture_year,
    capture_quarter,
    sex,
    age_first_capture,
    sett_id,
    normalized_sett_name,
    normalized_social_group_name
  ) |>
  collect()
```

---

# 9. Sett and social-group conventions

Historical spatial data require special care.

The capture view retains both the **recorded historical information** and cleaned identifiers.

Useful fields include:

```text
recorded_sett_name
sett_id
normalized_sett_name
recorded_social_group_name
recorded_social_group_id
normalized_social_group_name
recorded_supergroup_name
```

The social group associated with a historical capture should not simply be replaced using a present-day lookup.

For spatial analyses, prefer stable cleaned identifiers such as:

```text
sett_id
normalized_sett_name
```

rather than arbitrary raw location strings.

The view:

```text
analysis.sett_social_group_observed
```

contains observed sett/social-group relationships through time. It is useful as a historical summary, but should not automatically be interpreted as a deterministic rule saying that a sett could only belong to one social group in a particular year.

The view:

```text
analysis.historical_sett_candidates
```

supports review of historical location strings and candidate sett assignments.

---

# 10. `analysis.diagnostic_results`

## Grain

One row per diagnostic result.

This is intentionally a long-format dataset.

A single capture can therefore have several rows.

Current diagnostic inventory:

| Test family | Rows | Distinct captures represented |
|---|---:|---:|
| Culture | 48,699 | 16,960 |
| ELISA | 15,162 | 12,905 |
| IFN-gamma ELISA | 4,375 | 4,089 |
| DPP | 3,316 | 1,799 |
| Stat-Pak | 2,851 | 2,851 |
| Brock | 1,648 | 1,648 |

Total diagnostic rows:

```text
76,051
```

## Important fields

The view includes:

```text
source_table
source_record_id
capture_id
individual_id
tattoo
capture_date
is_pm
test_family
test_type
sample_type
result
result_code
visual_line_1
visual_line_1_result
optical_density_1
visual_line_2
visual_line_2_result
optical_density_2
reference_value
mean_od
blot_cf
blotson
brock_test_od
no_clotted
afno
lesions
abscesses
spoligo
spolprime
wgs_clade
plate_number
experiment_date
nil_value
avian_ppd_value
bovine_ppd_value
pwm_value
bovine_minus_nil
avian_minus_nil
bovine_minus_avian
retest
test_failed
test_info
blood_quality
qc_note
comments
```

## Example

```r
diagnostics <- tbl(
  con,
  in_schema("analysis", "diagnostic_results")
)

diagnostics |>
  count(test_family, result, sort = TRUE) |>
  collect()
```

---

# 11. Joining diagnostics to captures

This is one of the most important structural points in the database.

`capture_history` is approximately one row per capture.

`diagnostic_results` can have multiple rows per capture.

Therefore:

```r
captures |>
  left_join(
    diagnostics,
    by = "capture_id"
  )
```

will generally produce **more rows than the capture history**.

That is correct if the desired unit is:

```text
capture × diagnostic result
```

but not if the desired unit is:

```text
capture
```

If one row per capture is required, diagnostics need to be aggregated or pivoted deliberately according to the biological question.

Do not silently use `first()`, `max()` or another arbitrary aggregation unless that rule has a defensible diagnostic interpretation.

---

# 12. Infection-probability system

The database now contains both capture-level and complete quarterly infection-probability outputs.

The current model run is:

```text
infection_probabilities_2026_08_27
```

## Capture-level long-format probabilities

View:

```text
analysis.infection_probabilities
```

Grain:

```text
capture × model variant
```

Available model variants are:

```text
diagnostic_fixed_prevalence
diagnostic_annual_prevalence
diagnostic_adjusted_annual
all_tests_fixed
all_tests_inferred
culture_only_fixed
```

Each variant currently contains:

```text
16,255 capture rows
3,214 badgers
1976-02-09 to 2025-12-10
```

Across all six variants, the long view contains:

```text
97,530 rows
```

Key fields:

```text
infection_probability_id
individual_id
tattoo
capture_id
sample_date
year
quarter
model_variant
infection_probability
model_run
source_file
imported_at
```

---

# 13. Capture-level wide infection view

View:

```text
analysis.capture_infection_probabilities
```

This provides one row per represented capture and places the infection-model variants in separate columns.

Current rows:

```text
16,255
```

Columns include:

```text
capture_id
individual_id
tattoo
sample_date
year
quarter
model_run
diagnostic_fixed_prevalence
diagnostic_annual_prevalence
diagnostic_adjusted_annual
all_tests_fixed
all_tests_inferred
culture_only_fixed
```

This is convenient when capture-level infection probabilities need to be joined directly onto `analysis.capture_history`.

Example:

```r
capture_inf <- tbl(
  con,
  in_schema(
    "analysis",
    "capture_infection_probabilities"
  )
)

capture_with_inf <- captures |>
  left_join(
    capture_inf |>
      select(
        capture_id,
        p_infected = all_tests_inferred
      ),
    by = "capture_id"
  ) |>
  collect()
```

---

# 14. Complete quarterly infection trajectory

The earlier database documentation treated quarter-level completeness as unresolved.

That is no longer the case.

The database now contains:

```text
analysis.infection_quarterly_probabilities
```

For the current:

```text
model_run     = infection_probabilities_2026_08_27
model_variant = all_tests_inferred
```

the live database contains:

```text
Rows:                    29,737
Badgers:                  3,224
First quarter:       1976-01-01
Last quarter:        2026-07-01
Badgers with complete
first-to-last histories:  3,224 / 3,224
Missing internal quarters: 0
```

Therefore the imported quarterly object is a **complete quarterly trajectory between each animal's first and last represented quarter**.

This is the appropriate database source when an analysis needs infection state through time rather than only infection probability at observed captures.

Key fields:

```text
infection_quarterly_id
individual_id
tattoo
quarter_date
year
quarter
model_variant
infection_probability
model_run
source_file
imported_at
```

## R example

```r
infection_quarterly <- tbl(
  con,
  in_schema(
    "analysis",
    "infection_quarterly_probabilities"
  )
) |>
  filter(
    model_run ==
      "infection_probabilities_2026_08_27",
    model_variant ==
      "all_tests_inferred"
  ) |>
  select(
    individual_id,
    tattoo,
    quarter_date,
    year,
    quarter,
    p_infected = infection_probability
  ) |>
  arrange(
    individual_id,
    year,
    quarter
  ) |>
  collect()
```

This should be the default quarterly infection source for the current movement/disease model development.

---

# 15. Which infection object should I use?

Use:

## `analysis.infection_probabilities`

when:

- comparing infection-model variants;
- extracting one variant at actual capture occasions;
- retaining long-format model metadata.

## `analysis.capture_infection_probabilities`

when:

- you need one row per capture;
- you want infection probabilities as several columns;
- you are joining directly to capture-level biological data.

## `analysis.infection_quarterly_probabilities`

when:

- infection is needed at every quarter between first and last represented state;
- modelling temporal disease history;
- studying whether infection precedes movement/relocation or vice versa;
- building quarter-level hidden-state or survival/movement models.

For current model development, the primary infection series remains:

```text
all_tests_inferred
```

Do not automatically convert:

```r
p_infected > 0.5
```

into a hard infected/not-infected state unless a particular analysis explicitly requires such a threshold.

The probability carries information about uncertainty.

If posterior infection-state draws are available for a future analysis, they may preserve uncertainty more completely than posterior mean probabilities alone.

---

# 16. Underlying `research` tables

Normal read-only users cannot query these directly, but maintainers should understand the relational layer.

## Individuals and identity

```text
research.individuals
research.individual_names
```

These store canonical individual identity and historical naming information.

## Captures and capture-associated data

```text
research.captures
research.capture_sampling
research.capture_assessments
research.capture_collars
research.wounds
```

These separate the core capture event from one-to-one or one-to-many associated biological records.

## Diagnostic tables

```text
research.cultures
research.ifn_gamma_elisa
research.dpp_tests
research.elisa_tests
research.brock_tests
research.stat_pak_tests
research.stat_pak_results
```

Supporting lookup/detail tables include:

```text
research.dpp_sample_types
research.dpp_visual_line_results
research.disease_statuses
```

## Spatial/social structure

```text
research.setts
research.social_groups
research.supergroups
research.sett_social_group_history
research.social_group_supergroup_history
```

These support cleaned sett, social-group and supergroup relationships.

## Infection-model storage

```text
research.infection_probabilities
research.infection_probabilities_import
research.infection_quarterly_probabilities
research.infection_quarterly_import
```

The `*_import` tables are staging/import structures.

Analysis scripts should use the curated `analysis` views instead of relying directly on import tables.

---

# 17. Inspecting the live schema

Because the schema can evolve, the live database should be treated as authoritative.

List the current analysis views:

```r
DBI::dbGetQuery(
  con,
  "
  SELECT table_name
  FROM information_schema.views
  WHERE table_schema = 'analysis'
  ORDER BY table_name;
  "
)
```

A read-only collaborator will see only objects for which their role has permission.

Maintainers can list research tables with:

```sql
select table_name
from information_schema.tables
where table_schema = 'research'
order by table_name;
```

Inspect fields in a view:

```r
DBI::dbListFields(
  con,
  DBI::Id(
    schema = "analysis",
    table = "capture_history"
  )
)
```

---

# 18. Example: capture dataset for a survival/movement analysis

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

con <- badger_db_connect()

captures <- tbl(
  con,
  in_schema("analysis", "capture_history")
)

dat <- captures |>
  filter(
    !is_pm,
    capture_year >= 2000
  ) |>
  select(
    individual_id,
    capture_id,
    tattoo,
    capture_date,
    capture_year,
    capture_quarter,
    sex,
    age_first_capture,
    sett_id,
    normalized_sett_name,
    recorded_social_group_id,
    normalized_social_group_name
  ) |>
  collect()

dbDisconnect(con)
```

At this point the analysis script can make its own decisions about:

- same-day biological encounter fusion;
- quarterly collapse;
- defining age at time;
- treatment of unknown location;
- study-period restrictions;
- censoring;
- movement-state construction.

Those are not necessarily database-level cleaning operations.

---

# 19. Example: diagnostic extraction

```r
con <- badger_db_connect()

diagnostics <- tbl(
  con,
  in_schema("analysis", "diagnostic_results")
)

diag_dat <- diagnostics |>
  filter(
    !is_pm,
    capture_date >= as.Date("2010-01-01")
  ) |>
  select(
    individual_id,
    capture_id,
    tattoo,
    capture_date,
    test_family,
    test_type,
    sample_type,
    result,
    result_code
  ) |>
  collect()

dbDisconnect(con)
```

Remember that this remains a one-to-many diagnostic dataset.

---

# 20. Example: quarter-level infection plus capture history

A common workflow is to use capture history for observed encounters and the quarterly infection view for latent disease information through time.

```r
con <- badger_db_connect()

captures <- tbl(
  con,
  in_schema("analysis", "capture_history")
) |>
  filter(!is_pm)

infection_q <- tbl(
  con,
  in_schema(
    "analysis",
    "infection_quarterly_probabilities"
  )
) |>
  filter(
    model_run ==
      "infection_probabilities_2026_08_27",
    model_variant ==
      "all_tests_inferred"
  )

captures_local <- captures |>
  select(
    individual_id,
    capture_id,
    tattoo,
    capture_date,
    capture_year,
    capture_quarter,
    sex,
    sett_id,
    normalized_sett_name
  ) |>
  collect()

infection_local <- infection_q |>
  select(
    individual_id,
    tattoo,
    quarter_date,
    year,
    quarter,
    p_infected = infection_probability
  ) |>
  collect()

dbDisconnect(con)
```

The two objects can then be aligned to a shared quarter index in the analysis-specific preparation code.

---

# 21. Recommended model-data workflow

For computationally intensive models, especially NIMBLE models, do not repeatedly query PostgreSQL from inside each chain.

Recommended approach:

```text
1. Query the required database views
2. Apply reproducible analysis-specific preparation
3. Audit row counts / identifiers / dates
4. Save a versioned RDS snapshot
5. Fit all model chains from the same snapshot
6. Record the database/model-data preparation version
```

This separates:

- live database maintenance;
- analysis preparation;
- model fitting.

It also makes multi-chain/HPC fitting reproducible.

---

# 22. What belongs in the database versus the analysis

## Good candidates for central database handling

- canonical individual IDs;
- capture IDs;
- repaired historical names;
- standardized sett names;
- standardized social-group names;
- shared diagnostic structure;
- reusable joins;
- centrally agreed data corrections;
- reusable infection-model outputs;
- common analysis views.

## Usually analysis-specific

- study-period filtering;
- live/PM inclusion decisions;
- same-day fusion rules;
- quarter/occasion definitions;
- age-at-time calculation;
- modal location rules;
- movement classification;
- censoring decisions;
- construction of model matrices/arrays;
- model-specific derived covariates.

If several analyses independently repeat the same complicated cleaning operation, that is a sign it may belong in a central database view instead.

---

# 23. Adding a new analysis view

A new view is preferable when a cleaned or derived object is:

- needed repeatedly;
- biologically well defined;
- useful across several projects;
- not specific to one model implementation.

New views should normally be created by the maintainer and then explicitly granted to `badger_readonly`.

For example:

```sql
grant select on analysis.new_view
to badger_readonly;
```

Future views are **not automatically exposed** to collaborators. This is deliberate.

---

# 24. Adding a new researcher

Create an individual login:

```sql
create role researcher_name
with login
password '<secure-random-password>';
```

Then:

```sql
grant badger_readonly
to researcher_name;
```

Verify effective access:

```sql
select
  has_schema_privilege(
    'researcher_name',
    'analysis',
    'usage'
  ) as can_use_analysis,
  has_schema_privilege(
    'researcher_name',
    'research',
    'usage'
  ) as can_use_research;
```

The expected result is:

```text
can_use_analysis = true
can_use_research = false
```

The researcher should then receive:

- the session-pooler host;
- port `5432`;
- database name `postgres`;
- their own username;
- their own password.

Transfer the password securely.

---

# 25. Removing researcher access

Because users have individual logins, access can be revoked per person without changing everyone else's credentials.

A maintainer can remove membership:

```sql
revoke badger_readonly
from researcher_name;
```

or disable the login:

```sql
alter role researcher_name
nologin;
```

If the account is no longer needed and owns no objects, it can later be dropped by the maintainer.

---

# 26. Current security posture

As of 14 October 2026:

- the underlying `research` tables have RLS enabled;
- ordinary researchers do not have access to the `research` schema;
- approved collaborator access is through `analysis` views;
- `badger_readonly` cannot write to the approved views;
- the repository no longer tracks the real `.Renviron`;
- `.Renviron` and `.env` files are now ignored;
- `.Renviron.example` is the only credential template kept in Git.

The Supabase security advisor reports the underlying protected tables as **RLS enabled with no policies**. For these private schemas that means ordinary roles are not granted a row-level route into those tables; access is intentionally provided through the curated analysis layer instead.

The previous administrator database password should be rotated because a real `.Renviron` had previously been committed to the public GitHub repository. Removing it from the current branch prevents future exposure but does not erase it from historical commits.

---

# 27. Current database facts at a glance

```text
Capture history
---------------
Rows:              17,586
Individuals:        3,791
Date range:         1975-12-13 to 2026-08-11
Live rows:          16,298
PM rows:             1,288

Diagnostics
-----------
Culture:            48,699
ELISA:              15,162
IFN-gamma ELISA:     4,375
DPP:                  3,316
Stat-Pak:             2,851
Brock:                1,648
Total:               76,051

Capture-level infection probabilities
-------------------------------------
Model run: infection_probabilities_2026_08_27
Variants: 6
Rows per variant:    16,255
Badgers per variant:  3,214
Date range:           1976-02-09 to 2025-12-10

Quarterly infection trajectory
------------------------------
Model variant: all_tests_inferred
Rows:                 29,737
Badgers:               3,224
Range:                 Q1 1976 to Q3 2026
Complete first-to-last histories:
                       3,224 / 3,224
Missing internal quarters:
                       0
```

---

# 28. Recommended starting points

For most work:

```text
Capture/survival/movement:
    analysis.capture_history

Diagnostic test work:
    analysis.diagnostic_results

Capture-level infection:
    analysis.capture_infection_probabilities
or
    analysis.infection_probabilities

Quarterly disease trajectory:
    analysis.infection_quarterly_probabilities

Historical sett/social-group review:
    analysis.sett_social_group_observed
    analysis.historical_sett_candidates
```

Normal researchers should not need to start from `research` or `access_raw`.

---

# 29. Minimal complete R example

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

badger_db_connect <- function() {
  DBI::dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("BADGER_DB_HOST"),
    port = as.integer(
      Sys.getenv("BADGER_DB_PORT", unset = "5432")
    ),
    dbname = Sys.getenv(
      "BADGER_DB_NAME",
      unset = "postgres"
    ),
    user = Sys.getenv("BADGER_DB_USER"),
    password = Sys.getenv("BADGER_DB_PASSWORD"),
    sslmode = "require"
  )
}

con <- badger_db_connect()

captures <- tbl(
  con,
  in_schema("analysis", "capture_history")
)

infection_q <- tbl(
  con,
  in_schema(
    "analysis",
    "infection_quarterly_probabilities"
  )
)

capture_dat <- captures |>
  filter(
    !is_pm,
    capture_year >= 2015
  ) |>
  collect()

infection_dat <- infection_q |>
  filter(
    model_run ==
      "infection_probabilities_2026_08_27",
    model_variant ==
      "all_tests_inferred"
  ) |>
  collect()

DBI::dbDisconnect(con)
```

At this point both objects are ordinary local R data frames and can be prepared for the specific biological/model analysis.

---

# 30. Summary

The database now has a clear separation of responsibilities:

```text
access_raw
    historical source archive

research
    canonical cleaned relational database
    maintainer access

analysis
    curated research-ready views
    read-only collaborator access

R analysis
    project-specific biological preparation

model
    survival / movement / disease / SCR / CMR etc.
```

The most important practical rule is:

> **Use the central database for shared data cleaning and structure; use analysis scripts for decisions that are specific to the scientific question.**

That should prevent the long-term Woodchester dataset from fragmenting again into many slightly different locally cleaned versions.
