WOODCHESTER SPATIAL PRESSURE LOCATION RESOLUTION v3

Important correction
--------------------
The previous audit treated from_primary/to_primary as potentially indexing the
112 detector rows because their values happened to fall inside 1:112.

That interpretation is wrong.

The movement output itself shows these are temporal primary-occasion indices:
for example from_primary 31 -> year 2006, 32 -> 2007, etc. This script proves
the mapping against chain$years for every interval.

The previous detector-derived endpoint coordinates and endpoint-distance
summary should therefore NOT be used.

Correct spatial sources
-----------------------
1. chain$annual_obs contains observed annual x/y points for the Stage-1 1,285.
2. sett_master.csv contains coordinates for observed encounter setts.
3. encounters_useful contains sett and social-group histories for the broader
   infection-model population.

Run
---
source("scripts/run_SPATIAL_PRESSURE_location_resolution_v3.R")

Please paste back sections A-H.

If successful, the script creates:
data/badger_stage1_observed_annual_locations_1285.rds
data/badger_annual_observed_sett_locations.rds

These are explicitly OBSERVED-location products, not reconstructed posterior
activity centres.

Next
----
Use these to construct:
- same-social-group infection pressure;
- distance-weighted infection pressure;
for the V7b movement-ending year t, initially leaving missing source/focal
locations missing rather than silently carrying them forward.
