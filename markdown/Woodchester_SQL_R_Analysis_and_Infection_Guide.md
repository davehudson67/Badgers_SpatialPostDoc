# Woodchester Badger SQL Database — R Analysis Guide

**Updated:** 27 August 2026  
**Purpose:** Practical guide for connecting to the Woodchester PostgreSQL/Supabase database from R, choosing the correct table/view, querying safely, and extracting the `all_tests_inferred` probabilistic infection history for V7.

---

## 1. Database structure

The database is organised into three schemas:

- **`access_raw`** — immutable preservation of the original Access database. Use only for source auditing or resolving cleaning questions.
- **`research`** — cleaned relational tables.
- **`analysis`** — analysis-ready views. **Start here wherever possible.**

Recommended workflow:

```text
Supabase/PostgreSQL
        ↓
analysis/research query
        ↓
DataPrep.R or model-specific preparation
        ↓
versioned RDS snapshot
        ↓
R/NIMBLE analysis
```

For a major model, do not query the live database repeatedly inside the MCMC script.


## 2. Credentials and connection

Store credentials in `~/.Renviron`:

```text
BADGER_DB_HOST=YOUR_SUPABASE_SESSION_POOLER_HOST
BADGER_DB_PORT=5432
BADGER_DB_NAME=postgres
BADGER_DB_USER=YOUR_DATABASE_USER
BADGER_DB_PASSWORD=YOUR_DATABASE_PASSWORD
```

Use the **Supabase Session Pooler** on port **5432**. Restart R/RStudio after changing `.Renviron`.

Do not hard-code or print the password.

Save this as `BadgerDatabase.R`:

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

infection_probabilities_db <- function(con)
  tbl(con,in_schema("analysis","infection_probabilities"))

capture_infection_probabilities_db <- function(con)
  tbl(con,in_schema("analysis","capture_infection_probabilities"))
```

Connect:

```r
source("BadgerDatabase.R")
con <- badger_db_connect()

dbGetQuery(con,"SELECT current_database(), current_user;")
```

Disconnect when finished:

```r
dbDisconnect(con)
```


## 3. How `dbplyr` querying works

A remote table reference does not download the table:

```r
captures <- tbl(con,in_schema("analysis","capture_history"))
```

These operations are executed in PostgreSQL:

```r
captures %>%
  filter(primary_year>=2015) %>%
  count(sex)
```

Inspect the generated SQL with:

```r
captures %>%
  filter(primary_year>=2015) %>%
  count(sex) %>%
  show_query()
```

Download only the final reduced result with:

```r
collect()
```

Best practice:

```text
filter/select/group/summarise remotely
                ↓
             collect()
                ↓
      continue locally in R
```


## 4. Main `analysis` views

### `analysis.capture_history`

**Grain:** one row per capture.

Use for:

- individual and capture IDs;
- tattoo;
- capture date;
- year/quarter/season;
- sex and age;
- capture-level sett/location;
- historical capture-level social group;
- most routine CMR/SCR preparation.

Current database audit: **17,586 capture rows**.

Example:

```r
captures <- capture_history_db(con)

capture_dat <- captures %>%
  filter(primary_year>=2010) %>%
  select(
    individual_id,capture_id,tattoo,capture_date,
    primary_year,sex,age_fc,normalized_sett_name,socg
  ) %>%
  collect()
```

**Important:** capture-recorded `socg` is the historical social group. Do not overwrite it automatically from the current sett lookup.

For spatial work, prefer cleaned identifiers such as `sett_id` / `normalized_sett_name` over arbitrary raw location text.

---

### `analysis.diagnostic_results`

**Grain:** one row per diagnostic result.

A capture can therefore have several rows. Current audit: about **76,051 diagnostic-result rows**.

Use for:

- diagnostic histories;
- test-specific analyses;
- sensitivity/specificity models;
- long-format diagnostic summaries.

Example:

```r
diagnostics <- diagnostic_results_db(con)

diagnostics %>%
  count(test_type,result_label,sort=TRUE) %>%
  collect()
```

Do not join this directly to capture history and then assume one row still equals one capture.

---

### `analysis.infection_probabilities`

**Grain:** one row per capture × infection-model variant.

Current model run:

```text
infection_probabilities_2026_08_27
```

Available variants:

```text
diagnostic_fixed_prevalence
diagnostic_annual_prevalence
diagnostic_adjusted_annual
all_tests_fixed
all_tests_inferred
culture_only_fixed
```

Each currently contains:

- **16,255 rows**
- **3,214 badgers**
- **1976-02-09 to 2025-12-10**

This long-format view is the preferred canonical source when selecting one infection model or comparing variants.

---

### `analysis.capture_infection_probabilities`

**Grain:** one row per capture.

Contains the six infection probabilities as separate columns. Use when a wide one-row-per-capture infection object is more convenient.

Because it is one row per capture, it can be joined safely to `analysis.capture_history` by `capture_id`.

---

### `analysis.sett_social_group_observed`

Observed sett/social-group/year relationships.

Use it as an **observed historical summary**, not as a hard inferred validity table saying that a sett could only belong to a given group during particular years.


## 5. Main `research` tables

Use `analysis` views first. Move to `research` when a specific relational/test field is required.

### Core tables

- **`research.individuals`** — one row per badger; `individual_id`, tattoo, demographics/sex and baseline information.
- **`research.captures`** — one row per capture; `capture_id`, `individual_id`, date, live/PM status and core capture fields.
- **`research.capture_sampling`** — capture-associated biological sampling.
- **`research.capture_assessments`** — capture-associated health/clinical assessment information.
- **`research.capture_collars`** — capture-associated collar information.
- **`research.wounds`** — wound records; potentially one-to-many.

### Diagnostic/test tables

- **`research.cultures`**
- **`research.ifn_gamma_elisa`**
- **`research.dpp_tests`**
- **`research.stat_pak`**
- **`research.elisa_tests`**
- **`research.brock_tests`**

Use these if fields specific to one assay are required. Otherwise `analysis.diagnostic_results` is usually easier.

### Location tables

- **`research.setts`** — cleaned sett lookup.
- **`research.social_groups`** — cleaned social-group lookup.

There are also cleaned location/history/lookup structures used by the analysis views. Because schema details can evolve, inspect the live database rather than relying on an old list.

List every current `research` table:

```r
dbGetQuery(
  con,
  "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema='research'
  ORDER BY table_name;
  "
)
```

List every current `analysis` view:

```r
dbGetQuery(
  con,
  "
  SELECT table_name
  FROM information_schema.views
  WHERE table_schema='analysis'
  ORDER BY table_name;
  "
)
```

Inspect fields in any table/view:

```r
dbListFields(con,Id(schema="research",table="captures"))
dbListFields(con,Id(schema="analysis",table="capture_history"))
```


## 6. Example database queries

Captures per year:

```r
captures %>%
  count(primary_year) %>%
  arrange(primary_year) %>%
  collect()
```

Unique badgers per year:

```r
captures %>%
  distinct(primary_year,individual_id) %>%
  count(primary_year,name="n_badgers") %>%
  collect()
```

Pull a period:

```r
dat <- captures %>%
  filter(primary_year>=2014,primary_year<=2018) %>%
  select(
    individual_id,capture_id,tattoo,capture_date,
    primary_year,sex,age_fc,normalized_sett_name,socg
  ) %>%
  collect()
```

Direct SQL example:

```r
dbGetQuery(
  con,
  "
  SELECT primary_year,
         COUNT(*) AS n_captures,
         COUNT(DISTINCT individual_id) AS n_badgers
  FROM analysis.capture_history
  GROUP BY primary_year
  ORDER BY primary_year;
  "
)
```


## 7. Primary infection series for V7: `all_tests_inferred`

The planned primary infection information is:

```text
model_variant = all_tests_inferred
model_run     = infection_probabilities_2026_08_27
```

Pull it directly:

```r
source("BadgerDatabase.R")
con <- badger_db_connect()

infection_all_tests <- infection_probabilities_db(con) %>%
  filter(
    model_run=="infection_probabilities_2026_08_27",
    model_variant=="all_tests_inferred"
  ) %>%
  select(
    individual_id,
    tattoo,
    capture_id,
    sample_date,
    year,
    quarter,
    p_infected=infection_probability
  ) %>%
  arrange(individual_id,year,quarter,sample_date) %>%
  collect()

dbDisconnect(con)
```

Audit:

```r
infection_all_tests %>%
  summarise(
    n=n(),
    n_badgers=n_distinct(individual_id),
    first_date=min(sample_date),
    last_date=max(sample_date),
    min_p=min(p_infected),
    mean_p=mean(p_infected),
    max_p=max(p_infected)
  )
```

Current imported `all_tests_inferred` coverage is:

```text
16,255 rows
3,214 badgers
1976-02-09 to 2025-12-10
mean p(infected) ≈ 0.1121
```


## 8. Critical V7 audit: is this really every quarter-year time step?

The intended interpretation is that `all_tests_inferred` gives a posterior probability of infection at **every quarter-year time step from first capture to last capture**.

However, the SQL import came from:

```text
p_infected_per_capture.csv
```

and all **16,255/16,255** imported rows matched a live `capture_id`.

That proves that the imported file has an infection probability for every row in the per-capture export. It does **not by itself prove** that every latent quarter between first and last capture is represented in SQL.

Before V7, audit this explicitly.

### Check for multiple capture rows per individual-quarter

```r
infection_q_audit <- infection_all_tests %>%
  mutate(q_index=year*4L+(quarter-1L))

infection_q_audit %>%
  count(individual_id,year,quarter,name="n_rows") %>%
  count(n_rows)
```

### If a quarter has multiple captures, check whether the probability is identical

```r
within_quarter <- infection_q_audit %>%
  group_by(individual_id,year,quarter) %>%
  summarise(
    n_capture_rows=n(),
    p_min=min(p_infected),
    p_max=max(p_infected),
    p_range=p_max-p_min,
    .groups="drop"
  )

within_quarter %>%
  summarise(
    n_quarters=n(),
    n_multiple=sum(n_capture_rows>1),
    n_probability_disagreements=sum(p_range>1e-12)
  )
```

If `n_probability_disagreements = 0`, repeated captures within a quarter carry the same quarter-level posterior and can be collapsed safely.


## 9. Build one probability per badger-quarter

Only after the within-quarter audit is satisfactory:

```r
infection_quarter <- infection_all_tests %>%
  group_by(individual_id,tattoo,year,quarter) %>%
  summarise(
    p_infected=first(p_infected),
    n_capture_rows=n(),
    .groups="drop"
  ) %>%
  mutate(q_index=year*4L+(quarter-1L)) %>%
  arrange(individual_id,q_index)
```

Test complete coverage from first represented quarter to last:

```r
quarter_coverage <- infection_quarter %>%
  group_by(individual_id,tattoo) %>%
  summarise(
    first_q=min(q_index),
    last_q=max(q_index),
    observed_quarters=n(),
    expected_quarters=last_q-first_q+1L,
    missing_quarters=expected_quarters-observed_quarters,
    .groups="drop"
  )

quarter_coverage %>%
  summarise(
    n_badgers=n(),
    complete_badgers=sum(missing_quarters==0),
    incomplete_badgers=sum(missing_quarters>0),
    total_missing_quarters=sum(missing_quarters)
  )
```

Inspect any incomplete histories:

```r
quarter_coverage %>%
  filter(missing_quarters>0) %>%
  arrange(desc(missing_quarters))
```

### Interpretation

If every animal has `missing_quarters = 0`, the current imported data genuinely form a complete quarterly trajectory.

If many quarters are absent, then the **underlying infection model may have estimated every quarter but the current CSV exported only capture occasions**. In that case, obtain/import the full quarter-level output. Do not interpolate or carry probabilities forward unless that is explicitly part of the infection model.


## 10. Identify the missing quarters if needed

```r
expected_quarters <- infection_quarter %>%
  group_by(individual_id,tattoo) %>%
  tidyr::complete(
    q_index=seq(min(q_index),max(q_index))
  ) %>%
  ungroup() %>%
  mutate(
    year=q_index %/% 4L,
    quarter=(q_index %% 4L)+1L
  )

missing_quarter_rows <- expected_quarters %>%
  filter(is.na(p_infected))

missing_quarter_rows
```

Quarter indexing convention:

```r
q_index <- year*4L+(quarter-1L)
year <- q_index %/% 4L
quarter <- (q_index %% 4L)+1L
```


## 11. Join `all_tests_inferred` to captures

For infection probability at actual capture occasions:

```r
source("BadgerDatabase.R")
con <- badger_db_connect()

captures <- capture_history_db(con)

infection <- infection_probabilities_db(con) %>%
  filter(
    model_run=="infection_probabilities_2026_08_27",
    model_variant=="all_tests_inferred"
  ) %>%
  select(
    capture_id,
    p_infected=infection_probability
  )

capture_with_infection <- captures %>%
  left_join(infection,by="capture_id") %>%
  collect()

dbDisconnect(con)
```

Because there is one `all_tests_inferred` record per imported capture, this should remain one row per capture.


## 12. How the infection probabilities should enter V7

Do **not** default to:

```r
infected <- p_infected > .5
```

The probability itself carries uncertainty and should be preserved.

The planned directional questions are:

### Infection -> future relocation/high mobility

\[
\mathrm{logit}\{P(D_{i,t+1}=1|D_{it}=0)\}
=
lpha_{RD}+
eta_{RD,sex}Sex_i+
eta_{RD,inf}I_{it}+\ldots
\]

### Relocation/high mobility -> future infection

\[
\mathrm{logit}\{P(I_{i,t+1}=1|I_{it}=0)\}
=
lpha_I+
eta_{I,D}D_{it}+\ldots
\]

If posterior **infection-state draws** are available, they are preferable to using only posterior mean probabilities because they preserve uncertainty and temporal dependence more faithfully.

The exact V7 implementation should therefore be decided after confirming whether we possess:

1. posterior draws of the quarterly infection histories;
2. only posterior mean probabilities;
3. complete quarter-level probabilities;
4. or probabilities exported only at capture occasions.


## 13. Recommended co-author rules

1. Start from `analysis` views whenever possible.
2. Treat `access_raw` as an immutable historical archive.
3. Use `research` for specific relational/test detail.
4. Do not alter database tables without agreement.
5. Never hard-code passwords.
6. Filter/summarise in SQL before `collect()`.
7. Preserve `individual_id` and `capture_id`.
8. Remember that diagnostic data are one-to-many.
9. `analysis.diagnostic_results` is long-format.
10. `analysis.infection_probabilities` is long-format by infection-model variant.
11. `analysis.capture_infection_probabilities` is wide and one row per capture.
12. For current V7 development, select `all_tests_inferred`.
13. Preserve infection uncertainty.
14. Verify quarter-by-quarter completeness before calling the SQL import a complete latent quarterly trajectory.
15. Save final model inputs as versioned RDS snapshots.
16. Disconnect from PostgreSQL when finished.


## 14. Minimal quick-start

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

source("BadgerDatabase.R")

con <- badger_db_connect()

captures <- capture_history_db(con)

infection <- infection_probabilities_db(con) %>%
  filter(
    model_run=="infection_probabilities_2026_08_27",
    model_variant=="all_tests_inferred"
  )

dat <- captures %>%
  left_join(
    infection %>%
      select(capture_id,p_infected=infection_probability),
    by="capture_id"
  ) %>%
  collect()

dbDisconnect(con)
```

---

## 15. Current next step for V7

Run the quarter-coverage audit in Sections 8–9.

If `all_tests_inferred` is present for every quarter from first capture to last capture, it can be converted directly into the quarterly infection array for V7.

If the current SQL import contains only capture occasions, obtain the underlying complete quarter-level infection-model output and add that as a separate quarter-level SQL table/view rather than fabricating missing probabilities.
