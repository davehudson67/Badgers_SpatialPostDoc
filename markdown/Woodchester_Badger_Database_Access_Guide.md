# Woodchester Badger Database — R Access Guide

**Purpose:** Instructions for co-authors/collaborators who need read access to the Woodchester badger PostgreSQL database for analysis in R.

---

## 1. Overview

The Woodchester database is stored in **PostgreSQL**, hosted through **Supabase**.

The database is organised into three main schemas:

- **`access_raw`** — preserved import of the original Microsoft Access database. This should normally **not** be used for analysis.
- **`research`** — cleaned relational tables.
- **`analysis`** — analysis-ready views designed for most routine work.

For most analyses, start with the **`analysis`** schema.

The two most useful analysis views are:

```text
analysis.capture_history
analysis.diagnostic_results
```

### Important distinction

`analysis.capture_history` contains **one row per capture**.

`analysis.diagnostic_results` is **long format**, so one capture may have several diagnostic-result rows.

Do **not** join all diagnostic rows directly to `capture_history` and then assume you still have one row per capture.

---

## 2. Install the required R packages

If needed:

```r
install.packages(c("DBI","RPostgres","dplyr","dbplyr"))
```

Then load them:

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)
```

---

## 3. Store database credentials securely

Database usernames/passwords should **not** be written directly into analysis scripts.

Instead, store them in an R `.Renviron` file.

In R, open the user-level `.Renviron` file with:

```r
file.edit("~/.Renviron")
```

Add:

```text
BADGER_DB_HOST=YOUR_SUPABASE_SESSION_POOLER_HOST
BADGER_DB_PORT=5432
BADGER_DB_NAME=postgres
BADGER_DB_USER=YOUR_DATABASE_USER
BADGER_DB_PASSWORD=YOUR_DATABASE_PASSWORD
```

Then **save the file and restart R/RStudio**.

For this database, use the **Supabase Session Pooler on port 5432**.

### Security note

Do not commit `.Renviron` to GitHub or another shared repository.

The actual password-containing `.Renviron` file should ideally be transferred using a secure method rather than normal email. The accompanying `.Renviron.example` file can be shared freely, with the real credentials supplied separately.

---

## 4. Create the database connection script

Create a file called `BadgerDatabase.R` containing:

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

badger_db_connect <- function(){
  dbConnect(
    RPostgres::Postgres(),
    host=Sys.getenv("BADGER_DB_HOST"),
    port=as.integer(Sys.getenv("BADGER_DB_PORT",unset="5432")),
    dbname=Sys.getenv("BADGER_DB_NAME",unset="postgres"),
    user=Sys.getenv("BADGER_DB_USER"),
    password=Sys.getenv("BADGER_DB_PASSWORD"),
    sslmode="require"
  )
}

capture_history_db <- function(con)
  tbl(con,in_schema("analysis","capture_history"))

diagnostic_results_db <- function(con)
  tbl(con,in_schema("analysis","diagnostic_results"))
```

This script contains **no password**. It reads credentials from `.Renviron`.

---

## 5. Connect from R

Start a new R session, then run:

```r
source("BadgerDatabase.R")

con <- badger_db_connect()
```

Check that the connection works:

```r
dbGetQuery(
  con,
  "SELECT current_database(), current_user;"
)
```

When finished:

```r
dbDisconnect(con)
```

---

## 6. Access the main analysis views

Create remote references:

```r
captures <- tbl(
  con,
  in_schema("analysis","capture_history")
)

diagnostics <- tbl(
  con,
  in_schema("analysis","diagnostic_results")
)
```

Or use the helper functions:

```r
captures <- capture_history_db(con)
diagnostics <- diagnostic_results_db(con)
```

These are initially **remote database tables**. They are not yet downloaded into R.

---

## 7. Inspect available variables

```r
captures %>% glimpse()
diagnostics %>% glimpse()
```

Alternatively:

```r
dbListFields(
  con,
  Id(schema="analysis",table="capture_history")
)

dbListFields(
  con,
  Id(schema="analysis",table="diagnostic_results")
)
```

---

## 8. Basic querying with `dplyr`

The database can be queried using familiar `dplyr` syntax.

For example:

```r
captures %>%
  count(primary_year)
```

This is still being handled by PostgreSQL.

To bring the result into R:

```r
captures %>%
  count(primary_year) %>%
  collect()
```

Recommended workflow:

```text
filter / select / group / summarise in PostgreSQL
                    ↓
                 collect()
                    ↓
continue analysis locally in R
```

This avoids unnecessarily downloading the entire database.

---

## 9. Example queries

### Number of captures per year

```r
capture_counts <- captures %>%
  count(primary_year) %>%
  arrange(primary_year) %>%
  collect()

capture_counts
```

### Number of unique badgers per year

```r
badgers_by_year <- captures %>%
  filter(!is.na(tattoo)) %>%
  distinct(primary_year,tattoo) %>%
  count(primary_year,name="n_badgers") %>%
  collect()

badgers_by_year
```

### Extract captures from a particular period

For example, 2014–2018:

```r
dat <- captures %>%
  filter(
    primary_year>=2014,
    primary_year<=2018
  ) %>%
  select(
    individual_id,
    capture_id,
    tattoo,
    capture_date,
    primary_year,
    sex,
    age_fc,
    normalized_sett_name,
    socg
  ) %>%
  collect()
```

### Count diagnostic result types

```r
diagnostics %>%
  count(
    test_type,
    result_label,
    sort=TRUE
  ) %>%
  collect()
```

### Extract diagnostic results for a period

```r
diag_dat <- diagnostics %>%
  filter(
    primary_year>=2014,
    primary_year<=2018
  ) %>%
  select(
    individual_id,
    capture_id,
    tattoo,
    capture_date,
    primary_year,
    test_type,
    result_label
  ) %>%
  collect()
```

---

## 10. Joining capture and diagnostic data

Because `diagnostic_results` is long-format, one capture can have multiple diagnostic rows.

For example:

```r
capture_subset <- captures %>%
  filter(primary_year>=2014,primary_year<=2018) %>%
  select(
    capture_id,
    individual_id,
    tattoo,
    capture_date,
    primary_year,
    sex,
    age_fc,
    normalized_sett_name,
    socg
  )

diag_subset <- diagnostics %>%
  filter(primary_year>=2014,primary_year<=2018) %>%
  select(
    capture_id,
    test_type,
    result_label
  )
```

A direct join such as:

```r
capture_subset %>%
  left_join(
    diag_subset,
    by="capture_id"
  )
```

will create **multiple rows per capture** whenever several tests exist.

That is correct if a long-format capture × diagnostic dataset is required.

If the analysis requires **one row per capture**, diagnostic results should first be summarized or pivoted deliberately.

For example:

```r
diag_summary <- diag_subset %>%
  group_by(capture_id,test_type) %>%
  summarise(
    result_label=first(result_label),
    .groups="drop"
  ) %>%
  collect() %>%
  tidyr::pivot_wider(
    names_from=test_type,
    values_from=result_label
  )
```

The exact summarization should depend on the biological question.

---

## 11. Querying with SQL directly

You can also send SQL directly to PostgreSQL:

```r
dbGetQuery(
  con,
  "
  SELECT
    primary_year,
    COUNT(*) AS n_captures,
    COUNT(DISTINCT individual_id) AS n_badgers
  FROM analysis.capture_history
  GROUP BY primary_year
  ORDER BY primary_year;
  "
)
```

---

## 12. List available tables and views

```r
dbGetQuery(
  con,
  "
  SELECT
    table_schema,
    table_name
  FROM information_schema.tables
  WHERE table_schema IN ('research','analysis')
  ORDER BY table_schema, table_name;
  "
)
```

For views:

```r
dbGetQuery(
  con,
  "
  SELECT
    table_schema,
    table_name
  FROM information_schema.views
  WHERE table_schema IN ('research','analysis')
  ORDER BY table_schema, table_name;
  "
)
```

---

## 13. Useful database structure

The cleaned `research` schema contains relational tables including:

```text
individuals
captures
capture_sampling
capture_assessments
capture_collars
wounds
cultures
ifn_gamma_elisa
dpp_tests
stat_pak
elisa_tests
brock_tests
setts
social_groups
```

For most analyses, however, it is preferable to begin with the curated views in `analysis`.

---

## 14. Important data conventions

### Capture-level social group

The social group recorded on the capture record is treated as the **historical capture-level social group**.

Do not overwrite this automatically using the current sett-to-social-group lookup.

### Sett identity

For spatial analyses, prefer:

```text
sett_id
normalized_sett_name
```

rather than arbitrary raw location text.

### Diagnostic data

Diagnostics are intentionally stored separately from the one-row-per-capture history.

Tests include, depending on historical availability:

```text
Culture
IFN-gamma
DPP
Stat-Pak
ELISA
Brock
```

Different tests were available in different historical periods.

### Disease categories

Where disease classifications are used, the cleaned analysis convention is:

```text
1 = Negative
2 = Exposed
3 = Excretor
4 = Super excretor
```

Do not assume these classifications are equivalent to any one diagnostic test result.

---

## 15. Recommended analysis-script template

```r
# =============================================================================
# Woodchester analysis
# =============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)
library(tidyr)

source("BadgerDatabase.R")

con <- badger_db_connect()

captures <- capture_history_db(con)
diagnostics <- diagnostic_results_db(con)

# ---- query only the data required -------------------------------------------

dat <- captures %>%
  filter(primary_year>=2014,primary_year<=2018) %>%
  select(
    individual_id,
    capture_id,
    tattoo,
    capture_date,
    primary_year,
    sex,
    age_fc,
    normalized_sett_name,
    socg
  ) %>%
  collect()

# ---- close database connection ----------------------------------------------

dbDisconnect(con)

# ---- continue local analysis below ------------------------------------------

glimpse(dat)
```

---

## 16. Recommended working practice

1. **Use `analysis` views where possible.**
2. Treat `access_raw` as a preserved source archive rather than an analysis dataset.
3. Do not modify database tables unless specifically agreed with the database maintainer.
4. Filter and summarize remotely before using `collect()`.
5. Do not store passwords in R scripts, Markdown files or Git repositories.
6. Be cautious when joining one-to-many diagnostic/test tables.
7. Preserve `capture_id` and `individual_id` wherever possible when constructing derived datasets.
8. Record the exact query/code used to generate analysis datasets so analyses remain reproducible.
9. If an analysis needs a substantial new cleaned variable or view, discuss creating it centrally rather than independently re-cleaning the same field.
10. Disconnect from the database when finished.

---

## 17. Troubleshooting

### Credentials appear blank

Check:

```r
Sys.getenv("BADGER_DB_HOST")
Sys.getenv("BADGER_DB_PORT")
Sys.getenv("BADGER_DB_NAME")
Sys.getenv("BADGER_DB_USER")
```

Do **not** print `BADGER_DB_PASSWORD` into shared logs/screenshots.

If the environment variables were only just added, restart R/RStudio.

### Cannot connect

Confirm that:

- the Session Pooler hostname is being used;
- port is `5432`;
- `sslmode="require"` is present;
- the username/password are correct;
- the internet connection allows outbound PostgreSQL traffic.

### `collect()` takes a long time

The query is probably returning too many rows.

Prefer:

```r
captures %>%
  filter(primary_year>=2020) %>%
  select(tattoo,primary_year,sex) %>%
  collect()
```

rather than downloading all captures and filtering afterwards.

### Check what SQL `dbplyr` is generating

```r
captures %>%
  filter(primary_year>=2020) %>%
  count(sex) %>%
  show_query()
```

---

## 18. Closing the connection

Always close the connection when finished:

```r
dbDisconnect(con)
```

If unsure whether a connection is still valid:

```r
dbIsValid(con)
```

---

## 19. Minimal quick-start version

Once `.Renviron` and `BadgerDatabase.R` are set up:

```r
source("BadgerDatabase.R")

con <- badger_db_connect()

captures <- capture_history_db(con)

my_data <- captures %>%
  filter(primary_year>=2015) %>%
  select(
    tattoo,
    capture_date,
    primary_year,
    sex,
    age_fc,
    normalized_sett_name,
    socg
  ) %>%
  collect()

dbDisconnect(con)
```

That is all that is required for most straightforward analyses.
