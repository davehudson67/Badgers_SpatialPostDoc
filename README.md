# Woodchester Park badger movement and bTB analysis

This repository contains the long-term Woodchester Park badger spatial movement and infection analyses.

## Where to start

If you only want to understand the **current analysis**, read:

1. `docs/01_CURRENT_WORKFLOW_IN_PLAIN_ENGLISH.md`
2. `docs/02_CURRENT_RESULTS_IN_PLAIN_ENGLISH.md`

If you want to understand **how the movement model developed and why so many older scripts exist**, read:

3. `docs/03_MOVEMENT_MODEL_HISTORY_IN_PLAIN_ENGLISH.md`
4. `docs/04_AUDITS_AND_THINGS_WE_ALMOST_MISSED.md`
5. `docs/05_SCRIPT_NAME_MAP.md`

The original R scripts are intentionally retained because they form the scientific audit trail. The `scripts_current/` and `scripts_history/` files use simple names and act as easy-to-read entry points to those original scripts.

## Current scientific structure

```text
Database and prepared data
        ↓
Final movement-only spatial HMM/SCR
        ↓
Movement-model diagnostics
        ↓
Sample coherent movement histories
        ↓
Pair with sampled infection histories
        ↓
Test infection → later high mobility
        ↓
Test high mobility → later infection
        ↓
Sensitivity analyses
        ↓
Build local infection pressure
        ↓
Test whether local infection pressure explains/modifies movement → infection
```

## Important terminology

Use **local/stable movement state** and **high-mobility/relocation state**.

Do not describe these as two permanent types of badger.

## Security

Database credentials must live only in a local `.Renviron`. Never commit `.Renviron` to Git.
