# V7a-M quick computational/statistical smoke test
Sys.setenv(
  MAX_PAIRS="100",
  N_PROP="2000",
  N_KEEP="50",
  SEED="7092028",
  RESULT_TAG="SMOKE_100"
)
source("scripts/Woodchester_V7aM_infection_to_movement_modular_IS.R")
