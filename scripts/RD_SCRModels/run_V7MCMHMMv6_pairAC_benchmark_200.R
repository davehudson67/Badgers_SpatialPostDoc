# V7MC-MHMM v6 adjacent-year AC benchmark
# Run this BEFORE any long chains.
Sys.setenv(
  CHAIN_ID="1",
  NITER="200",
  NBURN="0",
  THIN="1",
  RESULT_TAG="BENCH_200"
)
source("scripts/Woodchester_RD_Spatial_CMR_V7MCMHMMv6_PAIR_AC_1285_CHAIN.R")
