# Woodchester V7 modelling audit package

**Created:** 27 August 2026  
**Purpose:** Reproducible record of the Woodchester Park spatial CMR modelling pathway from the early continuous-space models through the current V6c movement-state model and the planned V7 infection extension.

This package contains four files:

1. **`Woodchester_V7_Model_Development_Audit.md`**  
   The main scientific and technical audit. It records the data architecture, model lineage, reasons for each structural change, failed/weak formulations, computational changes, V6a/V6b/V6c results, interpretation of the latent movement state, and the proposed V7 infection model.

2. **`Woodchester_V6c_Reproducibility_Audit.R`**  
   A standalone R audit script for the saved V6c result. It checks convergence, reconstructs the corrected movement-pattern classification, audits year gaps and raw observed relocation distances, validates the interpretation of the latent high-mobility state, summarizes sex composition, and flags movement-support/grid-resolution issues. It does **not** connect to PostgreSQL/Supabase.

3. **`Woodchester_V7_Literature_Review.md`**  
   A focused literature review of badger movement/dispersal, sex differences, movement–TB relationships, probabilistic infection inference, disease-integrated SCR, and open-SCR movement methods. It explicitly separates findings that are already established from the parts of the V7 question that still appear to be a genuine gap.

4. **`Woodchester_V7_Analysis_Decision_Log.md`**  
   A concise decision register: what has been accepted, what has been rejected, what is provisional, and what must be checked before publication.

## Current status in one sentence

The current evidence supports a **dominant stable/local movement state plus rarer episodic high-mobility/relocation events**, with males more likely to enter the high-mobility state but no clear evidence that males move farther once in a given state; V7 will test the temporal relationship between these movement-state transitions and probabilistic bTB infection histories.

## Important terminology

Use:

- **stable/local movement state**
- **high-mobility/relocation (or dispersal) state**
- **movement-state transition**
- **relocation episode**

Avoid, unless later evidence supports it:

- “two types of badger”
- “resident badgers versus disperser badgers” as permanent classes
- interpreting the small V6c resident movement scale literally as metre-scale biological movement
- treating within-year SCR detection `sigma` as annual AC displacement
- claiming infection causes movement, or movement causes infection, before the V7 temporal model is fitted

## Data architecture

The intended reproducible route remains:

`PostgreSQL/Supabase -> BadgerDatabase.R -> DataPrep.R -> fixed RDS snapshots -> model/audit scripts`

The audit script in this package starts from the saved V6c RDS result and therefore does not access the database.
