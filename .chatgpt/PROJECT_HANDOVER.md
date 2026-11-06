# Woodchester Badgers — ChatGPT Project Handover

Last reviewed: 6 November 2026.

This is a handover for future ChatGPT conversations.
It is NOT a sixth authoritative scientific document.
Always check the repository and recent commits before acting.

## Project purpose

Develop reproducible models of Woodchester badger
movement, detection, social structure, survival,
dispersal and bovine tuberculosis epidemiology.

Repository:
davehudson67/Badgers_SpatialPostDoc

## Five authoritative documents

1. docs/WOODCHESTER_MODEL_DEVELOPMENT_ROADMAP.md
   The living scientific record. Contains model development,
   completed analyses, fitted models, diagnostics, results,
   decisions, rejected alternatives and future plans.

2. docs/database/01_ACCESS_AND_TABLE_GUIDE.md
   Supabase connections, database layers and table access.

3. docs/database/02_MASTER_DATA_DICTIONARY_AND_AUDIT.md
   Variables, table definitions, data rules and limitations.

4. docs/database/03_VERSIONING_AND_DECISIONS.md
   Database cleaning, migrations, provenance and decisions.

5. docs/database/WECS_FLAGGED_INCONSISTENCIES_2026_11_04.md
   Outstanding data-quality questions and review status.

These are the ONLY five active reference documents.
Do not create competing live roadmaps or data dictionaries.

## Repository organisation

README.md                 Entry point to five main documents
docs/                    Active scientific documentation
docs/database/           Active database documentation
docs/archive/            Historical documents
docs/archive/model_development/
docs/archive/database_history/
docs/archive/spatial_audits/
docs/archive/research_background/
docs/archive/DOCUMENT_MOVE_MAP.tsv
scripts/                 R analyses and model fitting
scripts/ModularFitting/  Bayesian model code and launch scripts
sql/audit/               Read-only SQL checks
sql/migrations/          Future database changes only
outputs/                 Analysis results and audit outputs
data/                    Research inputs and derived data
.chatgpt/                ChatGPT handover instructions

Historical documents are not authoritative, but may
contain essential scientific evidence and decisions.
Preserve their history and repair links when moving files.

## Current modelling position

V7: historical directional movement/infection analyses.

V10A/B: superseded spatial model development.
Preserve methodological lessons; do not restart V10B.

V11/V11S: fitted movement-model development, including
state-process and convergence investigations.

V11R2: current fitted geographic movement reference,
including spatial-resolution sensitivity analyses.
Its original inputs require reconciliation against
the curated Supabase data before deciding on a refit.

Important: historical V11R2 sett aliases include
unresolved or potentially incorrect biological mappings.
Do not assume distinct canonical setts are equivalent.

V12: next priority. Develop audited encounter/fate data,
detection, apparent survival and movement-demography
relationships. Do not equate disappearance with death.

V13: planned work on disease introduction,
infectiousness, transmission and persistence.

The modelling roadmap contains the detailed evidence
and MUST be consulted rather than treating this
summary as the final scientific position.

## Rules for modelling development

For every substantive analysis, append a dated entry
to the modelling roadmap recording:

- Scientific question and hypotheses
- Input data and version
- Inclusion and exclusion criteria
- Script paths, run commands and settings
- Model specification and assumptions
- Sample sizes and numerical results
- Convergence and posterior predictive checks
- Interpretation, uncertainty and limitations
- Decisions, rationale and rejected alternatives
- Next actions and dependencies

Distinguish PLANNED, RUNNING, PRELIMINARY,
VALIDATED, REJECTED, SUPERSEDED and BLOCKED.

Never describe unexecuted code as completed analysis.
Never invent numerical results, successful diagnostics,
database changes or completed model fitting.

Maintain model lineage and scientific reasoning.
Do not overwrite historical decisions silently;
append dated corrections.

## Data safeguards

Tattoo is the principal animal identifier.
Distinguish captures, encounters, death recoveries,
biological episodes, setts, territories and social groups.

Do not assign a social group to UN badgers.

Actual capture/recovery location must not be confused
with associated sett or annual resident social group.

Avoid inventing missing XY coordinates or settling
unverified name aliases.

Database corrections must be audited, versioned and
documented; do not silently modify source records.

## Git and RStudio safeguards

Primary working directory:
~/Badgers_SpatialPostDoc

Integration worktree:
~/Badgers_SpatialPostDoc_integration

At handover creation the integration branch is:
integration/20261105-main-audit

Main and audit histories were merged locally.
Check current Git status; do not assume this remains
the active branch or that changes have been pushed.

The primary RStudio directory contains local model
outputs and previously uncommitted work. Never
overwrite, delete, reset or clean it without auditing
and protecting these files.

Use Git for source, documentation and provenance.
Do not commit credentials, confidential records or
large posterior outputs indiscriminately.

## Starting a new ChatGPT conversation

1. Read this handover.
2. Read the five authoritative documents.
3. Inspect current Git branch, status and recent commits.
4. Identify the most recent dated modelling decision.
5. Resume from the current scientific decision gate.
6. Keep documentation and code in sync.

The objective is a coherent, traceable scientific
programme, not simply a sequence of model versions.


## Consolidated SQL organisation — 6 November 2026

sql/WOODCHESTER_APPLIED_MIGRATIONS.sql:
73 recorded executed migrations, chronological audit history.

sql/WOODCHESTER_DATABASE_BASELINE.sql:
Current schema-only snapshot; restore not yet validated.

docs/archive/sql_legacy/:
54 historical individual SQL files, retained for provenance.

Do not replay the consolidated migration history against
the production database or treat the schema-only export
as a complete reconstruction of the research data.


## Supabase-first data policy — 6 November 2026

For all new V12/V13 analyses use approved Supabase research/analysis data through versioned read-only R extraction. No historical local RDS is an authoritative data source. Archive old local inputs for historic reproducibility, never delete fitting outputs or overwrite saved inputs blindly.

Initial work-in-progress extractor: scripts/database/freeze_woodchester_v12_inputs.R. It creates a SHA-256-labelled, Git-ignored evidence snapshot from analysis.encounters_clean_v1 and analysis.mortality_model_candidate_v1. It does NOT create approved V12 model matrices or fit a model. Review the live checks and assumptions before fitting.

Historical Phase/RD-SCR scripts still read local RDS, but are archival/reproducibility code; update active models only after model-specific rule approval. Keep code and five authoritative documents in sync. Do not commit snapshot contents or credentials.
