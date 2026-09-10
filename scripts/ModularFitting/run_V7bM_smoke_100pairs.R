# V7b-M quick smoke test
Sys.setenv(
  MAX_PAIRS="100",
  N_PROP="3000",
  N_KEEP="50",
  SEED="7092029",
  RESULT_TAG="SMOKE_100"
)
source("scripts/Woodchester_V7bM_movement_to_infection_modular_IS.R")
