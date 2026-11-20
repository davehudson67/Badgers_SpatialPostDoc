# Paper 3a data build

Open-population social-group demography, 1980–2025: survival, between-group movement, emigration and adult arrival (immigrants vs missed residents), by sex, age and period. The model will follow the Ponchon et al. 2026 multistate style in NIMBLE/nimbleEcology, with hidden states summed out. **No model fitting until the data checks below pass.**

All outputs go to `outputs/paper3/<SNAPSHOT_ID>/` (gitignored). Inputs come from the frozen snapshot in `data/model_snapshots/<SNAPSHOT_ID>/` (made by `scripts/database/freeze_woodchester_v12_inputs.R`).

| Step | Script | Output | Check |
| --- | --- | --- | --- |
| 0 | `R/00_extract_group_fields.R` | `group_fields.rds` | Recorded group for every snapshot capture, matched one-to-one (the V12 freezer didn't export it) |
| 1 | `R/01_assign_annual_groups.R` | `annual_resident_social_group_vicente.csv` | Vicente rules unchanged, run on live TRAP captures; criterion-1 share vs the published >96% |
| 2 | `R/02_group_year_histories.R` | `group_year_histories.csv` | >85% first caught as cubs; unresolved years; recorded deaths |
| 3 | `R/03_territory_geometry.R` | `territory_pairs.csv`, `territory_groups.csv` | Polygon vs capture group-name crosswalk resolved via `group_name_aliases.csv` |
| 4 | `R/04_check_silk_moves.R` | `check_silk_462_moves.csv` | Reproduces the Silk draft's 462 moves (20 groups, 1986–2006) |
| 5 | monitoring windows | — | **Waiting for the CaptEffort table** (34 core groups × 1980 Q1–2020 Q1) |

Run: `SNAPSHOT_ID=<id> bash paper3/run_data_build.sh`. Steps 0 and 1 are skipped if their outputs exist. Steps 2–4 can be rerun after alias edits.

Open items: the Silk draft's 20-group list (`SILK_GROUPS=file`) and move definition; CaptEffort file and format; windows for 2020–2025 and for non-core groups.
