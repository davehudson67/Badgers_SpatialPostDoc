WOODCHESTER SPATIAL PRESSURE - COORDINATE RESOLUTION AUDIT 2

The first audit showed that posterior activity-centre coordinates were not
saved, but it also revealed:
- a 112-row final detector table in each Stage-1 chain;
- from_primary/to_primary fields in every final movement interval;
- sett coordinate lookup files and a sett distance matrix.

This audit resolves those links before we construct infection pressure.

Run:
source("scripts/run_SPATIAL_PRESSURE_coordinate_resolution_audit.R")

Paste back sections:
A. FINAL STAGE-1 DETECTOR TABLE
B. MOVEMENT from_primary / to_primary
C. annual_obs AND disp_index
D. SETT SPATIAL LOOKUPS
E. ENCOUNTER TO SETT-COORDINATE COVERAGE
F. MOVEMENT ENDPOINT COORDINATES / SANITY CHECK
G. DECISION FOR INFECTION-PRESSURE CONSTRUCTION

If successful it creates:
data/badger_annual_observed_spatial_locations.rds
results/phase2_movement_observed_endpoint_coordinates.csv

These will become the canonical observed-location inputs for the first
same-group and distance-weighted infection-pressure models.

No location imputation is performed.
