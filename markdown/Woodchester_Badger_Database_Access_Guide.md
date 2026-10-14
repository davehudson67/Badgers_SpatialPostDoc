# Woodchester Badger Database — Quick Access Guide

## What is this?

The historic Woodchester badger data are now stored in a PostgreSQL database hosted by Supabase.

The database is intended to be the **single cleaned source of the long-term badger data**. Historical Access conversion, identifier repair, and database-level cleaning are handled centrally rather than repeated in individual R projects.

For normal research use, collaborators are given **individual read-only database accounts**. These accounts can query the prepared `analysis` views but cannot edit the underlying data.

---

## Database structure

There are two important layers:

- `research` — underlying cleaned relational tables. These are maintained centrally and are **not available to normal read-only users**.
- `analysis` — analysis-ready views. These are the normal starting point for R analyses.

The read-only role currently has access to the following views:

| View | Purpose | Current rows* |
|---|---|---:|
| `analysis.capture_history` | One row per capture, with individual, capture, sett/social-group and biological information | 17,586 |
| `analysis.diagnostic_results` | Long-format diagnostic/test results linked to captures | 76,051 |
| `analysis.capture_infection_probabilities` | Capture-level infection probabilities from the fitted diagnostic models | 16,255 |
| `analysis.infection_probabilities` | Model-specific capture-level infection probability output | 97,530 |
| `analysis.infection_quarterly_probabilities` | Model-specific badger-quarter infection probabilities | 29,737 |
| `analysis.historical_sett_candidates` | Summary used when reviewing historical sett/location assignments | 358 |
| `analysis.sett_social_group_observed` | Observed sett/social-group relationships through time | 2,156 |

\*Row counts checked 14 October 2026 and will change as the database is updated.

For most biological analyses, start with:

```text
analysis.capture_history
analysis.diagnostic_results
```

For disease-state analyses, also use the infection-probability views.

---

## Getting access

Ask the database maintainer for an individual read-only username and password.

Researchers do **not** use the main `postgres` administrator account.

Each researcher account inherits the `badger_readonly` role, which:

- can connect to the database;
- can use the `analysis` schema;
- can read the approved analysis views;
- cannot insert, update or delete records;
- cannot access the underlying `research` schema.

Do not share accounts between researchers.

---

## Store credentials locally

Credentials should never be written into an R script or committed to Git.

Create or edit your local `.Renviron` file and add:

```text
BADGER_DB_HOST=YOUR_SESSION_POOLER_HOST
BADGER_DB_PORT=5432
BADGER_DB_NAME=postgres
BADGER_DB_USER=YOUR_READ_ONLY_USERNAME
BADGER_DB_PASSWORD=YOUR_READ_ONLY_PASSWORD
```

Then restart R/RStudio.

A safe template is provided in the repository as `.Renviron.example`.

---

## Connect from R

Install the required packages once:

```r
install.packages(c("DBI", "RPostgres", "dplyr", "dbplyr"))
```

Then connect:

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

con <- dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("BADGER_DB_HOST"),
  port = as.integer(Sys.getenv("BADGER_DB_PORT", unset = "5432")),
  dbname = Sys.getenv("BADGER_DB_NAME", unset = "postgres"),
  user = Sys.getenv("BADGER_DB_USER"),
  password = Sys.getenv("BADGER_DB_PASSWORD"),
  sslmode = "require"
)
```

Check the connection:

```r
dbGetQuery(con, "SELECT current_database(), current_user;")
```

---

## Load the main data

### Capture history

```r
captures <- tbl(
  con,
  in_schema("analysis", "capture_history")
)
```

Useful fields include:

```text
capture_id
individual_id
tattoo
sex
age_first_capture
year_first_capture
capture_date
capture_year
capture_quarter
is_pm
normalized_sett_name
normalized_social_group_name
recorded_supergroup_name
weight
condition
reproductive_status
```

### Diagnostic results

```r
diagnostics <- tbl(
  con,
  in_schema("analysis", "diagnostic_results")
)
```

Useful fields include:

```text
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
```

`diagnostic_results` is **long format**: a capture can have several diagnostic rows.

---

## Query before downloading

`dbplyr` lets you filter and summarise in PostgreSQL before bringing data into R.

For example:

```r
dat <- captures |>
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
    normalized_sett_name,
    normalized_social_group_name
  ) |>
  collect()
```

For diagnostics:

```r
diag_dat <- diagnostics |>
  filter(
    capture_date >= as.Date("2014-01-01"),
    capture_date < as.Date("2019-01-01")
  ) |>
  select(
    capture_id,
    tattoo,
    capture_date,
    test_family,
    test_type,
    result
  ) |>
  collect()
```

Filtering before `collect()` is preferable when only part of the database is needed.

---

## Important points

`analysis.capture_history` is approximately one row per recorded capture.

`analysis.diagnostic_results` is one row per diagnostic result, so joining it directly to `capture_history` can produce several rows per capture.

The database handles shared cleaning and data structure. Individual analysis scripts should still make analysis-specific decisions such as:

- study period;
- live versus post-mortem records;
- capture occasions;
- repeated/same-day encounters;
- age definitions;
- diagnostic aggregation;
- construction of model-specific encounter histories.

Do not independently overwrite centrally cleaned identifiers or historical sett/social-group assignments without discussing the change with the database maintainer.

---

## Minimal example

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

con <- dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("BADGER_DB_HOST"),
  port = as.integer(Sys.getenv("BADGER_DB_PORT", unset = "5432")),
  dbname = "postgres",
  user = Sys.getenv("BADGER_DB_USER"),
  password = Sys.getenv("BADGER_DB_PASSWORD"),
  sslmode = "require"
)

captures <- tbl(
  con,
  in_schema("analysis", "capture_history")
)

my_data <- captures |>
  filter(capture_year >= 2020, !is_pm) |>
  collect()

dbDisconnect(con)
```

That is sufficient for most straightforward analyses.

---

## For database maintainers

The underlying `research` schema contains the cleaned relational source tables, including individuals, captures, wounds, diagnostic-test tables, setts, social groups, sampling/assessment records and model-derived infection outputs.

Normal collaborators should not need direct access to these tables. If a commonly needed cleaned variable or derived dataset is missing, it is usually better to add or update an `analysis` view centrally rather than have multiple projects independently recreate the same cleaning.

New researcher accounts should be individual PostgreSQL login roles that inherit `badger_readonly`. Passwords should be generated separately and transferred securely.

No database passwords or administrator credentials should ever be committed to this repository.
