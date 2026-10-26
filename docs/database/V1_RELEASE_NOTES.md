# Woodchester badger database — Version 1 release notes

**Status: V1 in preparation — 26 October 2026.** This document is for coauthors. The detailed cleaning and historical design record is maintained separately in [V1_CLEANING_AUDIT.md](V1_CLEANING_AUDIT.md).

## Design principle

Keep the database as close as practicable to the original Access tables. `research` contains cleaned source entities, retaining original field values and providing additional `_clean` columns where transformations are justified. Keep genuinely new information, such as infection-model outputs and validated coordinate evidence, in separate tables. `analysis` contains only a few useful derived joins/views, not copies of the same dataset.

The source Access imports remain unchanged in `access_raw`. The `ingest` schema contains technical import and provenance information. Original values are never silently overwritten by a cleaning decision.

## Current core data

- **Badgers:** `research.individuals` — individual identity; `tattoo` is the scientific identifier.
- **Captures and PM records:** `research.captures` — one event per `capture_id`. Additional associated details are currently stored in `capture_sampling`, `capture_assessments` and `capture_collars`. These will be reconciled with the original Access structure in the final V1 pass, preserving every historical field.
- **Diagnostic evidence:** `cultures`, `elisa_tests`, `ifn_gamma_elisa`, `stat_pak_tests`, `brock_tests`, `dpp_tests`, with their original measurement detail.
- **Other biological records:** `wounds`, historical `individual_names`, and reference/lookup tables.
- **Sett and social groups:** `setts`, `social_groups`, `supergroups` and recorded historical relationships; coordinate provenance is stored separately.
- **New model results:** `infection_probabilities` and `infection_quarterly_probabilities`; these are estimates, not original observations.

## Recorded versus cleaned fields

Use consistent **`_clean` suffixes** for newly created standardised versions of source fields. For example, preserve `recorded_sett_name` as the historical entry and add a distinct clean canonical name only when scientifically supported. For unassigned setts, the clean sett name remains `NULL`; a recovery grid reference must not be interpreted as a physical sett. Coordinates must include enough provenance to distinguish actual sett locations, recovery grid squares and future modelled group centres. Exact column mapping and final clean-column names remain subject to V1 verification; the earlier legacy `normalized_*` fields are not renamed yet.

## Useful analysis outputs

The proposed small final group is a single joined capture-history view, a diagnostic-results view, an optional sett/coordinate reference view, and clearly labelled derived infection summaries where needed. **Existing views remain in the database until dependent running models have been checked; they are not all endorsed as final release interfaces.** Their technical disposition is recorded in the cleaning audit.

## Coverage and open work

17,586 distinct capture/PM events; 16,337 events linked to recognised setts, 710 provisionally grid-referenced PM recovery locations, 343 unresolved PM locations, 170 unmatched non-PM locations and 26 with no recorded location. There are 176 canonical setts, with coordinate evidence linked for 159. These labels and spatial coordinates remain subject to the documented historical-source checks.

Coauthors will have read-only access to both curated `research` and `analysis`. Both existing custom read-only roles have been granted SELECT on 25 curated research tables and 24 current analysis views; staging/import tables remain restricted. Actual login-level security should be tested before release.

**V1 release is not yet frozen.** The final step is an explicit source-to-cleaned column reconciliation, reducing redundant public-facing views while preserving running script compatibility, and documenting each added `_clean` field with its exact derivation in the separate audit.
