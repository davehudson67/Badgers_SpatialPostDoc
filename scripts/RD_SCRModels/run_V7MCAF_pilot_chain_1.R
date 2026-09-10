# V7MC-AF chain-agreement pilot 1
# Run after the 100-iteration speed benchmark is acceptable.
Sys.setenv(
  CHAIN_ID="1",
  NITER="5000",
  NBURN="1000",
  THIN="2",
  RESULT_TAG="PILOT_5K"
)
source("scripts/Woodchester_RD_Spatial_CMR_V7MCAF_CENTERED_AFSLICE_1285_CHAIN.R")
