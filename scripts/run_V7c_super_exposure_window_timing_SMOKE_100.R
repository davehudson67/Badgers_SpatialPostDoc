# Smoke test: one-model recent 1-2q versus earlier 3-4q Super exposure timing.
Sys.setenv(
  MAX_DRAWS="100",
  N_KEEP="50",
  SEED="7092045",
  RESULT_TAG="SMOKE_100",
  END_YEAR="2025"
)
source("scripts/Woodchester_V7c_super_exposure_recent_vs_earlier_window_model.R")
