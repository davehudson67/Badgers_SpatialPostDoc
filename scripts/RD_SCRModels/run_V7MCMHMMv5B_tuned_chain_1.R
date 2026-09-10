# V7MC-MHMM v5B tuned chain 1
# Run only if the 200-iteration benchmark runtime is acceptable.
Sys.setenv(
  CHAIN_ID="1",
  NITER="15000",
  NBURN="2000",
  THIN="2",
  RESULT_TAG="TUNED_15K"
)
source("scripts/Woodchester_RD_Spatial_CMR_V7MCMHMMv5B_TARGETED_AFSLICE_1285_CHAIN.R")
