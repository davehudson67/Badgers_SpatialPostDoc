# Badgers_SpatialPostDoc

Woodchester badger database and spatial analysis code.

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
