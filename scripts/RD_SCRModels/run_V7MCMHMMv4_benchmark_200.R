# V7MC-MHMM v4 timing benchmark
# Smoke test has passed. This measures realistic per-iteration runtime before
# launching the three 5k chain-agreement pilots.
Sys.setenv(
  CHAIN_ID="1",
  NITER="200",
  NBURN="0",
  THIN="1",
  RESULT_TAG="BENCH_200"
)
source("scripts/Woodchester_RD_Spatial_CMR_V7MCMHMMv4_PI_FIX_MARGINAL_HMM_1285_CHAIN.R")
