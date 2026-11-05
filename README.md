# Badgers_SpatialPostDoc

Woodchester badger database and spatial analysis code.

## Current modelling programme (single authoritative record)

- **[Woodchester Model Development Roadmap](docs/WOODCHESTER_MODEL_DEVELOPMENT_ROADMAP.md)** — the **one living modelling record** covering historical models, V11R2 diagnostics, integrated movement/social pathways, current results, scientific decisions and V12/V13 plans. Most recent update: 5 November 2026.
- **[Executable V12 survival data eligibility audit](sql/audit/WECS_V12_readonly_survival_eligibility_audit.sql)** — non-mutating queries against the curated Supabase database for encounter histories, death-only records, missing covariates, location support and mortality contradictions.

Older files in `docs/`, `markdown/` and `data/` are technical history or specific model annotations, not competing live modelling roadmaps. The current V11R2 scripts are on `main`. The audited database SQL migrations and the separate four canonical database reference documents currently live on `audit-tattoo-identifier`; reconcile branches carefully before proposing a model-data rerun.

## Database documentation

For collaborators who need straightforward read-only access:

- [Woodchester Badger Database — Quick Access Guide](markdown/Woodchester_Badger_Database_Access_Guide.md)

For database structure, analysis views, infection outputs, R workflows, maintainer tasks and access-control details:

- [Woodchester Badger Database — Detailed Technical, R and Infection Guide](markdown/Woodchester_SQL_R_Analysis_and_Infection_Guide.md)

For cleaning transparency, provenance, variable definitions and spatial-assignment rules:

- [Database Governance, Provenance and Cleaning Audit](docs/database/DATABASE_GOVERNANCE_AND_PROVENANCE.md)
- [Sett and Social-Group Assignment Rules](docs/database/SETT_SOCIAL_GROUP_RULES.md)
- [Research Data Dictionary](docs/database/DATA_DICTIONARY.md)
- [Executable Cleaning Audit SQL](sql/audit/Woodchester_database_cleaning_audit.sql)
- [Advanced Research Read-Only Access SQL](sql/access/create_badger_research_readonly.sql)

### Access levels

- **`badger_readonly`** — default collaborator access to curated `analysis` views.
- **`badger_research_readonly`** — advanced/audit access to approved canonical `research` tables plus the analysis views; still strictly read-only.
- **`postgres`** — maintainer/admin access only.

The `analysis` layer is the recommended starting point because it gives explicit analysis grains and centrally maintained joins. Direct use of `research` is appropriate for auditing and specialist work, but requires care with one-to-many joins, recorded versus normalised fields, and internal table semantics.

Database credentials are **not stored in this repository**. Use the supplied `.Renviron.example` as a template and keep the real `.Renviron` file local only.
