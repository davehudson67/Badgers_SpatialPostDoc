# V7MC-MHMM v4 chain-agreement pilot 3
# Marginalized movement HMM; no discrete movement states are sampled in MCMC.
Sys.setenv(
  CHAIN_ID="3",
  NITER="15000",
  NBURN="2000",
  THIN="2",
  RESULT_TAG="PILOT_5K"
)
source("scripts/Woodchester_RD_Spatial_CMR_V7MCMHMMv4_PI_FIX_MARGINAL_HMM_1285_CHAIN.R")
