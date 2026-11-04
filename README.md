# Badgers_SpatialPostDoc

Woodchester badger spatial, disease and encounter-analysis repository.

## Current database documentation (WECS v1 — 4 November 2026)

For routine use there are **three authoritative documents**, plus a live inconsistency register:

1. [01 — Database access and available tables](docs/database/01_ACCESS_AND_TABLE_GUIDE.md) — connect from R, which views to use and key interpretation rules.
2. [02 — Master data dictionary and audit](docs/database/02_MASTER_DATA_DICTIONARY_AND_AUDIT.md) — complete live schema/column inventory, types, categorical definitions, evidence and limitations.
3. [03 — Versioning, SQL migrations and scientific decisions](docs/database/03_VERSIONING_AND_DECISIONS.md) — migration index, rule changes, QA and reproducibility.
4. [WECS inconsistency register](docs/database/WECS_FLAGGED_INCONSISTENCIES_2026_11_04.md) — read-only dated snapshot of the live `analysis.wecs_review_flags_v1` view; resolution status/current interpretation/final decisions.

**Current research outputs:** `analysis.encounters_clean_v1` (17,586 source capture/PM rows), `analysis.capture_history_v1`, `analysis.diagnostic_results`, `analysis.mortality_events_review_v1` (death evidence irrespective of missing XY), and `analysis.wecs_review_flags_v1`. See the guide for row-grain and mortality cautions.

**SQL:** `sql/migrations/20261104_wecs_curated_v1_snapshot.sql` captures reviewed event links, classification overrides, sett-name aliases and current WECS output views; its prerequisite import/spatial objects must already exist. Validations are in `sql/audit/`.

Older files under `docs/database/` and `markdown/` remain for historical scientific decisions, but should not be regarded as the current documentation entrypoint. Do not store credentials in Git. Use `.Renviron.example` as a local template.
