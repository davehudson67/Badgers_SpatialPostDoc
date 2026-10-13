# 01 — Current workflow in plain English

This is the ordered analysis that matters now.

## Step 1 — Prepare the biological data

**Easy entry point:** `scripts_current/01_prepare_badger_data.R`

**Original script:** `DataPrep_fromSupaBase.R`

What it does: builds the cleaned encounter-level and CMR-ready datasets from the database. Model scripts then use frozen RDS snapshots rather than reconnecting to the database.

---

## Step 2 — Fit the final movement model

**Easy entry points:**

- `scripts_current/02_fit_final_movement_model_chain_1.R`
- `scripts_current/03_fit_final_movement_model_chain_2.R`
- `scripts_current/04_fit_final_movement_model_chain_3.R`

**Original model:** `scripts/ModularFitting/Woodchester_RD_Spatial_CMR_V7MCMHMMv6_PAIR_AC_1285_CHAIN.R`

What it does: infers annual movement states for the 1,285 badgers that can contribute to the directional infection analyses.

States:

- 0 = local/stable
- 1 = high-mobility/relocation

Disease is deliberately absent at this stage.

**Status: FINAL / FROZEN**

---

## Step 3 — Check the movement model

**Easy entry point:** `scripts_current/05_check_final_movement_model.R`

**Original script:** `scripts/ModularFitting/Woodchester_V7MCMHMMv6_FINAL30K_combine_exact_state_diagnostics.R`

What it does: combines the three chains and checks convergence and agreement.

**Status: FINAL / FROZEN**

---

## Step 4 — Sample complete movement histories

**Easy entry point:** `scripts_current/06_sample_complete_movement_histories.R`

**Original script:** `scripts/ModularFitting/Woodchester_V7MCMHMMv6_FINAL30K_export_FFBS_histories.R`

What it does: generates 1,500 coherent movement-state histories using FFBS. This is better than calling every interval simply local or high using an arbitrary probability threshold.

**Status: FINAL / FROZEN**

---

## Step 5 — Pair movement and infection uncertainty

**Easy entry point:** `scripts_current/07_pair_movement_and_infection_histories.R`

**Original script:** `scripts/ModularFitting/Woodchester_PHASE2_build_and_audit_paired_histories.R`

What it does: pairs 1,500 sampled movement histories with sampled infection histories so both sources of uncertainty are propagated.

**Status: FINAL / FROZEN**

---

## Step 6 — Test infection → later high mobility

**Easy entry point:** `scripts_current/08_test_infection_before_high_mobility.R`

**Original script:** `scripts/ModularFitting/Woodchester_V7aM_infection_to_movement_modular_IS.R`

Question: if a badger is infected, does it become more likely to enter a high-mobility state later?

Primary result: only weak positive evidence under broad same-year timing.

---

## Step 7 — Check stricter infection → movement timing

**Easy entry point:** `scripts_current/09_test_infection_before_movement_strict_timing.R`

**Original script:** `scripts/PostModularRunsAudit/Woodchester_V7aM_sensitivity_period_entry_IS.R`

What it does: adjusts for historical period and entry-age class and requires clearer temporal ordering.

Result: the weak same-year signal attenuates and disappears under strict lag.

---

## Step 8 — Compare badgers with themselves for infection → movement

**Easy entry point:** `scripts_current/10_test_infection_before_movement_within_badger.R`

**Original script:** `scripts/PostModularRunsAudit/Woodchester_V7aM_within_individual_clogit_v3.R`

Result: same-year point estimate is positive but very uncertain; strict-lag result is essentially null.

**Current conclusion:** no robust evidence that established infection increases later high mobility.

---

## Step 9 — Test high mobility → later infection

**Easy entry point:** `scripts_current/11_test_high_mobility_before_infection.R`

**Original script:** `scripts/ModularFitting/Woodchester_V7bM_movement_to_infection_modular_IS.R`

Question: after a high-mobility interval ending in year t, is a susceptible badger more likely to acquire infection in year t+1?

Result: no evidence of a general positive effect.

**Status: PRIMARY RESULT / FROZEN**

---

## Step 10 — Check the numerical robustness of that result

**Easy entry point:** `scripts_current/12_check_high_mobility_infection_model_numerics.R`

**Original script:** `scripts/ModularFitting/Woodchester_V7bM_robustness_patch_poor_IS_pairs.R`

What it does: reruns the seven weak importance-sampling pairs with much larger proposals.

Result: diagnostics improved and the pooled biological result was unchanged.

---

## Step 11 — Compare badgers with themselves for movement → infection

**Easy entry points:**

- `scripts_current/13_test_movement_before_infection_within_badger_5yr.R`
- `scripts_current/14_test_movement_before_infection_within_badger_10yr.R`

**Original script:** `scripts/Woodchester_V7bM_time_stratified_within_clogit.R`

What it does: compares the same badger with itself inside 5-year or 10-year calendar blocks.

Result: positive point estimates, but extremely wide intervals and few informative switching strata. Treat as weakly identified sensitivity, not a contradictory primary result.

---

## Step 12 — Check whether we can measure local infection pressure

**Easy entry point:** `scripts_current/15_check_location_data_for_infection_pressure.R`

**Original script:** `scripts/Woodchester_SPATIAL_PRESSURE_location_resolution_v3.R`

What it does: correctly identifies the available annual observed locations and social groups.

**Status: FINAL LOCATION AUDIT**

---

## Step 13 — Build local infection-pressure variables

**Easy entry point:** `scripts_current/16_build_local_infection_pressure.R`

**Original script:** `scripts/Woodchester_V7b_build_spatial_infection_pressure.R`

What it does: creates same-group, fixed-radius and distance-weighted infection pressure for every infection trajectory.

The preferred first measure is same-social-group prevalence because it is biologically interpretable and retains the most V7b events.

---

## Step 14 — Test same-group infection pressure

**Easy entry points:**

- `scripts_current/17_test_same_group_infection_pressure_smoke.R`
- `scripts_current/18_test_same_group_infection_pressure_full.R`
- `scripts_current/19_test_same_group_infection_pressure_minimum_3_badgers.R`

**Original model:** `scripts/Woodchester_V7bM_samegroup_pressure_models.R`

Question: does the movement → infection relationship change after accounting for infection prevalence in the badger's social group?

**Status: CURRENT FRONTIER**
