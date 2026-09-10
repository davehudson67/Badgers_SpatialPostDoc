# V7MC-MHMM v6 adjacent-year AC chain 2
# Run only after the 200-iteration benchmark is acceptable.
Sys.setenv(
  CHAIN_ID="2",
  NITER="15000",
  NBURN="2000",
  THIN="2",
  RESULT_TAG="TUNED_15K"
)
source("scripts/Woodchester_RD_Spatial_CMR_V7MCMHMMv6_PAIR_AC_1285_CHAIN.R")
