# 05 — Script name map

The original scripts are kept for reproducibility. These simple names are easier entry points.

| Simple name | Original script | Status |
|---|---|---|
| `01_prepare_badger_data.R` | `DataPrep_fromSupaBase.R` | current |
| `02_fit_final_movement_model_chain_1.R` | `run_V7MCMHMMv6_FINAL30K_chain_1.R` | frozen |
| `03_fit_final_movement_model_chain_2.R` | `run_V7MCMHMMv6_FINAL30K_chain_2.R` | frozen |
| `04_fit_final_movement_model_chain_3.R` | `run_V7MCMHMMv6_FINAL30K_chain_3.R` | frozen |
| `05_check_final_movement_model.R` | `Woodchester_V7MCMHMMv6_FINAL30K_combine_exact_state_diagnostics.R` | frozen |
| `06_sample_complete_movement_histories.R` | `Woodchester_V7MCMHMMv6_FINAL30K_export_FFBS_histories.R` | frozen |
| `07_pair_movement_and_infection_histories.R` | `Woodchester_PHASE2_build_and_audit_paired_histories.R` | frozen |
| `08_test_infection_before_high_mobility.R` | `Woodchester_V7aM_infection_to_movement_modular_IS.R` | primary V7a |
| `09_test_infection_before_movement_strict_timing.R` | `Woodchester_V7aM_sensitivity_period_entry_IS.R` | sensitivity |
| `10_test_infection_before_movement_within_badger.R` | `Woodchester_V7aM_within_individual_clogit_v3.R` | sensitivity |
| `11_test_high_mobility_before_infection.R` | `Woodchester_V7bM_movement_to_infection_modular_IS.R` | primary V7b |
| `12_check_high_mobility_infection_model_numerics.R` | `Woodchester_V7bM_robustness_patch_poor_IS_pairs.R` | robustness |
| `13_test_movement_before_infection_within_badger_5yr.R` | `run_V7bM_timestrat5_FULL_1500.R` | sensitivity |
| `14_test_movement_before_infection_within_badger_10yr.R` | `run_V7bM_timestrat10_FULL_1500.R` | sensitivity |
| `15_check_location_data_for_infection_pressure.R` | `run_SPATIAL_PRESSURE_location_resolution_v3.R` | frozen audit |
| `16_build_local_infection_pressure.R` | `run_V7b_build_spatial_infection_pressure.R` | frozen build |
| `17_test_same_group_infection_pressure_smoke.R` | `run_V7bM_samegroup_pressure_SMOKE_100.R` | current |
| `18_test_same_group_infection_pressure_full.R` | `run_V7bM_samegroup_pressure_FULL_1500.R` | current |
| `19_test_same_group_infection_pressure_minimum_3_badgers.R` | `run_V7bM_samegroup_pressure_minN3_FULL_1500.R` | current |

## Historical movement development

| Simple historical name | Original |
|---|---|
| `01_first_continuous_spatial_movement_and_survival.R` | `RD_SCR_V1_Full.R` |
| `02_simpler_xy_activity_centre_movement.R` | `RD_SCR_V2_Centered_BLockXY.R` |
| `03_add_habitat_and_social_group_landscape.R` | `RD_Spatial_CMR_V3.R` |
| `04_heavy_tailed_movement_with_landscape_resistance.R` | `RD_SCR_V4c_t3_DYNAMIC_NORMALIZED_SG_PERIPH_LATENT_SEX_MOVESEX_OPTIMIZED_AFmove_800_badgers.R` |
| `05_test_adult_entry_as_possible_immigrant_class.R` | `RD_SCR_V5c_800.R` |
| `06_test_persistent_and_temporary_movement_behaviour.R` | `RD_Spatial_CMR_V6_800.R` |
| `07_two_state_heavy_tailed_movement_test.R` | `RD_Spatial_CMR_V6a_800.R` |
| `08_clean_local_vs_high_mobility_gaussian_model.R` | `RD_Spatial_CMR_V6b_800.R` |
| `09_wide_support_movement_model_with_sex_effects.R` | `RD_Spatial_CMR_V6c_800.R` |
| `10_joint_pilot_infection_before_movement.R` | `Woodchester_RD_Spatial_CMR_V7aT_TRAJECTORY_INFECTION_TO_HIGH_MOBILITY.R` |
| `11_joint_pilot_movement_before_infection.R` | `Woodchester_RD_Spatial_CMR_V7bT_HIGH_MOBILITY_TO_INFECTION.R` |
| `12_modular_centered_movement_only_test.R` | `Woodchester_RD_Spatial_CMR_V7MC_CENTERED_1285_CHAIN.R` |
| `13_modular_better_activity_centre_sampler_test.R` | `Woodchester_RD_Spatial_CMR_V7MCAF_CENTERED_AFSLICE_1285_CHAIN.R` |
| `14_modular_marginalised_movement_states_test.R` | `Woodchester_RD_Spatial_CMR_V7MCMHMMv4_PI_FIX_MARGINAL_HMM_1285_CHAIN.R` |
| `15_modular_targeted_activity_centre_blocks_test.R` | `Woodchester_RD_Spatial_CMR_V7MCMHMMv5B_TARGETED_AFSLICE_1285_CHAIN.R` |
| `16_final_modular_movement_model.R` | `Woodchester_RD_Spatial_CMR_V7MCMHMMv6_PAIR_AC_1285_CHAIN.R` |
