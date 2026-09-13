# 03 — Movement model history in plain English

This document explains why there are so many movement scripts. Each model was a useful step, even when it was later rejected.

## Stage A — Early discrete social-group models

Before the current continuous-space work, the project tried multistate models in which social groups were the spatial states.

These models were useful for thinking about movement between groups and survival, but they treated space as discrete rather than using actual sett coordinates.

**Current role:** historical reference only.

---

## V1 — First continuous spatial movement + survival model

**Original script:** `scripts/RD_SCRModels/RD_SCR_V1_Full.R`

**Easy historical name:** `01_first_continuous_spatial_movement_and_survival.R`

Idea: give each badger an annual latent activity centre, let capture probability decline with distance from that centre, estimate annual survival, and estimate annual movement.

Movement was represented using a distance plus direction.

**What we learned:** the biology was sensible, but thousands of latent movement distances and angles mixed poorly.

**Why we changed it:** simplify the movement parameterisation.

---

## M2 / V2 — Move the annual activity centre directly in X and Y

**Original script:** `scripts/RD_SCRModels/RD_SCR_V2_Centered_BLockXY.R`

**Easy name:** `02_simpler_xy_activity_centre_movement.R`

Idea: instead of estimating a distance and angle, move X and Y directly with a bivariate Gaussian transition.

**What improved:** fewer awkward latent variables; much cleaner geometry.

**What was still missing:** the landscape was basically featureless.

---

## V3 — Add habitat and social-group geography

**Original script:** `scripts/RD_SCRModels/RD_Spatial_CMR_V3.R`

**Easy name:** `03_add_habitat_and_social_group_landscape.R`

Idea: put movement into the 50 m landscape grid, restrict it to valid habitat, and penalise movement ending in a different social group or peripheral area.

**What we learned:** a simple endpoint penalty can be confounded with how much destination area is available. A fair movement likelihood needs to account for landscape geometry.

**Why we changed it:** normalize the movement kernel over available landscape.

---

## V4 / V4c — Heavy-tailed movement + normalized landscape resistance

**Representative original script:** `scripts/RD_SCRModels/RD_SCR_V4c_t3_DYNAMIC_NORMALIZED_SG_PERIPH_LATENT_SEX_MOVESEX_OPTIMIZED_AFmove_800_badgers.R`

**Easy name:** `04_heavy_tailed_movement_with_landscape_resistance.R`

Idea: use Student-t movement so occasional long steps are not forced into a Gaussian tail, and normalize social-group/peripheral penalties across the landscape.

Sex effects were also added to movement, detection and survival.

**What improved:** the model handled long movements and landscape geometry more realistically.

**What problem remained:** we still did not know whether some animals were fundamentally different movers or whether movement state changed through time.

---

## V5c — Test a permanent “immigrant” class for adult-entry badgers

**Original script:** `scripts/RD_SCRModels/RD_SCR_V5c_800.R`

**Easy name:** `05_test_adult_entry_as_possible_immigrant_class.R`

Idea: adult-entry badgers might include immigrants, so infer a latent immigrant status and allow immigrants to have larger annual movement.

**Result:** the movement coefficient looked large, but effective sample size was only about 5–6.

**What we learned:** this was not reliable enough to interpret, and more importantly a permanent immigrant label is not the same as later movement behaviour.

**Why we changed it:** let movement state vary through time.

---

## V6 — Persistent individual tendency + temporary movement state

**Original script:** `scripts/RD_SCRModels/RD_Spatial_CMR_V6_800.R`

**Easy name:** `06_test_persistent_and_temporary_movement_behaviour.R`

Idea: each badger could have a persistent tendency to move more or less **and** switch between a local and dispersal state.

This was biologically attractive, but both the persistent random effect and the temporary state could explain the same variation.

The model also still used a heavy-tailed Student-t kernel, so a long movement could be explained either by the heavy tail or by the high-mobility state.

**What we learned:** too many mechanisms were competing to explain long movements.

---

## V6a — Simplify to two movement states but keep Student-t movement

**Original script:** `scripts/RD_SCRModels/RD_Spatial_CMR_V6a_800.R`

**Easy name:** `07_two_state_heavy_tailed_movement_test.R`

Changes:

- remove persistent individual movement random effect;
- require at least two observed live years;
- retain local/high latent states;
- retain Student-t movement.

**Result:** computationally better, but movement-state parameters still mixed badly.

**Why it failed conceptually:** Student-t tails and a high-mobility state were still competing to explain the same long moves.

---

## V6b — Clean two-state Gaussian movement

**Original script:** `scripts/RD_SCRModels/RD_Spatial_CMR_V6b_800.R`

**Easy name:** `08_clean_local_vs_high_mobility_gaussian_model.R`

Major changes:

- Gaussian local and high-mobility states;
- no persistent movement random effect;
- movement stops at the last observed live year;
- missing years between observations remain;
- 2026 excluded;
- survival conditioned out;
- high-mobility state constrained to have larger movement scale.

**Result:** this was the first clearly well-behaved local/high-mobility model.

Approximate movement scales:

- local ≈ 12 m model scale;
- high mobility ≈ 865 m.

**Remaining concern:** the local and high scales were near the support limits.

---

## V6c — Widen movement support and ask exactly where sex matters

**Original script:** `scripts/RD_SCRModels/RD_Spatial_CMR_V6c_800.R`

**Easy name:** `09_wide_support_movement_model_with_sex_effects.R`

Changes:

- widen allowed movement scale from roughly 10–1200 m to 5–2500 m;
- separately test sex effects on movement distance within state, initial high-mobility probability, local → high transition, and high → high persistence.

**Result:** high-mobility scale stayed around 0.8–1 km, so it was not simply being forced against the old upper limit.

The clearest sex effect was on **entering high mobility**: males were about twice as likely as females in this 500-badger scaffold.

This became the biological basis of the later final movement model.

---

## V7a and V7b full-joint pilots — Put infection directly inside the spatial model

### V7a-T

**Original:** `Woodchester_RD_Spatial_CMR_V7aT_TRAJECTORY_INFECTION_TO_HIGH_MOBILITY.R`

**Easy name:** `10_joint_pilot_infection_before_movement.R`

Question: does sampled infection status predict later local → high movement?

### V7b-T

**Original:** `Woodchester_RD_Spatial_CMR_V7bT_HIGH_MOBILITY_TO_INFECTION.R`

**Easy name:** `11_joint_pilot_movement_before_infection.R`

Question: does high mobility predict infection in the following year?

**What we learned:** scientifically useful, but fitting the full spatial model repeatedly across infection trajectories would be far too expensive.

This is what motivated the modular strategy.

---

# Modular movement-model development

The final idea was:

1. fit movement once, without disease;
2. integrate out the movement-state sequence during MCMC;
3. draw coherent movement histories afterwards;
4. combine those histories with infection trajectories in fast Stage-2 models.

This prevents infection from helping to invent the movement state with which it is later associated.

---

## Modular attempt 1 — Centered movement-only model

**Original:** `Woodchester_RD_Spatial_CMR_V7MC_CENTERED_1285_CHAIN.R`

**Easy name:** `12_modular_centered_movement_only_test.R`

Purpose: scale the V6c concept to the 1,285 disease-directional badgers with disease absent.

This was a computational-development step.

---

## Modular attempt 2 — Better activity-centre sampling

**Original:** `Woodchester_RD_Spatial_CMR_V7MCAF_CENTERED_AFSLICE_1285_CHAIN.R`

**Easy name:** `13_modular_better_activity_centre_sampler_test.R`

Change: use bivariate AF_slice sampling for each annual activity centre.

Goal: improve MCMC efficiency.

---

## Modular attempt 3 — Marginalize the hidden movement states

**Original:** `Woodchester_RD_Spatial_CMR_V7MCMHMMv4_PI_FIX_MARGINAL_HMM_1285_CHAIN.R`

**Easy name:** `14_modular_marginalised_movement_states_test.R`

Key conceptual change: rather than explicitly sampling every local/high state inside the MCMC, analytically sum over the hidden state sequence using an HMM likelihood.

This removed a large discrete latent-state sampling burden.

---

## Modular attempt 4 — Targeted activity-centre blocking

**Original:** `Woodchester_RD_Spatial_CMR_V7MCMHMMv5B_TARGETED_AFSLICE_1285_CHAIN.R`

**Easy name:** `15_modular_targeted_activity_centre_blocks_test.R`

Purpose: improve sampling of activity centres in the marginalized-HMM model.

---

## Modular final — Overlapping adjacent-year activity-centre blocks

**Original:** `scripts/ModularFitting/Woodchester_RD_Spatial_CMR_V7MCMHMMv6_PAIR_AC_1285_CHAIN.R`

**Easy name:** `16_final_modular_movement_model.R`

Final computational strategy: update overlapping adjacent-year activity-centre pairs as 4-D blocks while retaining the marginalized movement-state HMM.

This was run in three independent 50,000-iteration chains.

### Final movement interpretation

The final model supports:

- a dominant local/stable state;
- rarer high-mobility relocation events;
- high-mobility movement on the scale of several hundred metres;
- males much more likely to initiate high mobility;
- little evidence that males move farther conditional on state;
- episodic high mobility rather than permanent mover “types”.

This is the movement model now treated as frozen for the disease-direction analyses.

---

# What happened after the final modular movement model?

The movement-model history does not stop when the final model was fitted. A series of later audits changed how the disease analyses should be interpreted, including repeated-measures/within-badger checks, strict temporal-lag checks, local infection pressure, survival/informative disappearance, numerical robustness checks, and a correction to a temporary coordinate-index mistake.

These are described in:

**`docs/04_AUDITS_AND_THINGS_WE_ALMOST_MISSED.md`**
