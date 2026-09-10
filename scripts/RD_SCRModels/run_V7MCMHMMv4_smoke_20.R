# V7MC-MHMM v4 smoke test
# v3 exposed the root cause: bare `pi` inside nimbleCode became an
# uninitialized model variable. v4 supplies LOG_TWO_PI explicitly as a constant.
Sys.setenv(
  CHAIN_ID="1",
  NITER="20",
  NBURN="0",
  THIN="1",
  RESULT_TAG="SMOKE_20"
)
source("scripts/Woodchester_RD_Spatial_CMR_V7MCMHMMv4_PI_FIX_MARGINAL_HMM_1285_CHAIN.R")
