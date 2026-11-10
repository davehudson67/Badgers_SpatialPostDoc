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


## Sett-name curation handover update — 10 November 2026

Approved standardisations **TOP SETT → TOP** (canonical sett ID 20) and
**TODDS → TODD'S** (canonical sett ID 158) are now explicitly recorded for
357 source-confirmed fixed-sett capture records (349 + 8) in
`research.capture_sett_alias_decisions`. The existing underlying sett
IDs and coordinates were already correctly joined; source names and
`research.setts` coordinates were not rewritten. Nine additional
`TOP SETT` source records do not satisfy fixed-sett capture-location
eligibility and were intentionally not converted to trap-location
decisions. The live database integrity check returned zero violations.

**Five-document rule observed:** The scientific decision is logged in
`docs/WOODCHESTER_MODEL_DEVELOPMENT_ROADMAP.md`, current data rule
and provenance in `docs/database/02_MASTER_DATA_DICTIONARY_AND_AUDIT.md`,
and applied database transaction in
`docs/database/03_VERSIONING_AND_DECISIONS.md`. No sixth active
scientific document was created. The exact guarded applied SQL lives at
`sql/migrations/20261110_top_sett_todds_capture_alias_decisions_APPLIED.sql`
and a reusable read-only check at
`sql/audit/WECS_SETT_ALIAS_RULE_INTEGRITY_20261110.sql`.

**Important distinction:** This was a **live SQL data transaction, not
a registered Supabase schema migration**; it has no new
`supabase_migrations.schema_migrations` entry and therefore must not
be added as if registered to
`sql/WOODCHESTER_APPLIED_MIGRATIONS.sql`. The transaction is
already applied — do not rerun the file on production. New records
need source-qualified decisions and a passing integrity check before
freezing model inputs. Historical frozen V12 snapshots remain immutable.

The next work remains reconciling the reviewed Supabase fixed-sett
capture histories with the legacy 1,932-badger V11R2 modelling cohort,
then testing an explicitly coverage-aware observation likelihood.


## Modelling handover update — 10 November 2026 (parallel V11R3 / V12)

The original 1,932-badger V11R2 source cohort and 8,248 annual states / 6,316 movement intervals were reproduced. The approved 159 named-sett blank-ancillary-location TRAP observations raised curated accepted fixed-sett spatial captures to 15,680 in the frozen 6 Nov evidence; all 1,932 historical tattoos now have some mapped evidence, but some have only one *distinct year* of approved fixed-sett capture. Do not invent movement intervals for those single-year spatial histories. The 304 SETT captures lacking accepted XY remain temporally observed, awaiting mapped coordinates. After source review the other non-sett/terminal events remain excluded from the fixed-sett detector likelihood but relevant to V12. The K051 Bown Hill Farm garage capture 8810 received user-provided grid SO 82442 01956 (BNG E382442 N201956) via versioned captured-location decision; cleaned live view verified BUILDING/FOUND_ALIVE, *not* LISTERS trap XY. Old frozen snapshots do NOT include that new location.

**New GitHub code, not executed on Exeter server:** `freeze_woodchester_v12_inputs.R` now includes original capture name/location/method/notes for future immutable extracts. `Woodchester_V12_Spatial_Eligibility_Rules.R` verifies source evidence for the 159 in fresh snapshots; `Woodchester_V11R3_Prefit_Input_Gate.R` checks 110 explicit TRAP/49 curated TRAP, fixed-sett coordinates and K051's nonsett point. Candidate V11R3 source `Woodchester_V11R3_Curated_Coverage_Scenarios.R` uses Supabase fixed-sett captures and assumed detector-availability masks (`all_sites`, `positive_5year`, `positive_same_quarter`) rather than always all-setts; its original age/sex and comparative cohort fields still reference archived V7. The candidate excludes old-cohort badgers with only one approved fixed-sett year from the *movement-transition* fit, retaining them for V12. **It has not passed an R/NIMBLE smoke; it does NOT yet include K051's geolocated non-sett encounter as a separate positive spatial emission. Do not run production 3-chain long MCMC until both issues and the detection likelihood are validated.** Guarded tmux script `launch_V11R3_Curated_Coverage_tmux.sh` can run a 60-badger smoke and requires explicit reviewed permission for full. No fitted chains have yet started.

In parallel continue V12I survival/entry/core-periphery using existing old V11R2 posterior *draw-based* zone summaries, but recognise they are smoothed from observed captures and their hull boundaries are not biological immigration states. New read-only `Woodchester_V12_LegacyPosterior_Zone_Detection_Bridge.R` calculates zone-posterior-weighted **observed next-year recapture**, not unbiased survival, entry, population density or immigration. Existing V12I-04b and V12I-05b synthetic tests remain the modelling foundation (V12I-05b spatial mixing was not yet satisfactory). Latest scientific decisions and commands in `docs/WOODCHESTER_MODEL_DEVELOPMENT_ROADMAP.md`; retain five-document rule.
