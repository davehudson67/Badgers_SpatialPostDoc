# V7M-C centered timing benchmark: 50 MCMC iterations
# Run only after stopping the slow production jobs.
Sys.setenv(
  CHAIN_ID="1",
  NITER="50",
  NBURN="0",
  THIN="1",
  RESULT_TAG="BENCH_50"
)
source("scripts/Woodchester_RD_Spatial_CMR_V7MC_CENTERED_1285_CHAIN.R")
