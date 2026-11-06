# Woodchester Badger Research

Code, versioned data audits, spatial analyses and Bayesian
modelling of badger movement, survival, social structure
and bovine tuberculosis.

## Five authoritative project documents

1. [Modelling Development Roadmap](docs/WOODCHESTER_MODEL_DEVELOPMENT_ROADMAP.md)
   - Scientific questions, model history, analyses, results,
     decisions, diagnostics and future V12/V13 development.

2. [Database Access and Table Guide](docs/database/01_ACCESS_AND_TABLE_GUIDE.md)
   - Supabase connections and how to use the database.

3. [Master Data Dictionary and Audit](docs/database/02_MASTER_DATA_DICTIONARY_AND_AUDIT.md)
   - Tables, variables, interpretations and limitations.

4. [Database Versioning and Decisions](docs/database/03_VERSIONING_AND_DECISIONS.md)
   - Cleaning rules, SQL migrations and provenance.

5. [Outstanding Inconsistencies](docs/database/WECS_FLAGGED_INCONSISTENCIES_2026_11_04.md)
   - Review issues and their recorded resolution status.

## Working principles

The modelling roadmap is the one authoritative, continuously
updated scientific development record.

New analyses must document their question, data, code,
model specification, fitting settings, diagnostics, results,
interpretation, decision and next action.

A planned analysis must not be described as completed.
Preliminary results must not be presented as validated.

Database corrections belong in the versioned database
decision log and executable SQL migrations.

Older modelling guides, technical reports and previous
database documentation are retained for historical
reference, not maintained as additional live roadmaps.

Large model outputs and confidential database credentials
must not be committed to Git.

## Model development status

V11R2 is the current fitted geographic movement reference.
Its historical inputs must be reconciled with curated
Supabase data before deciding whether refitting is necessary.

V12 will address survival, observation, disappearance and
potential emigration, with uncertainty propagated from
the movement analysis where justified.

V13 will investigate disease introduction, infectiousness,
transmission pathways and persistence.
