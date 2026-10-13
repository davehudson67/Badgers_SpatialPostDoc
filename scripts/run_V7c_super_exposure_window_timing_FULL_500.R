# Full run: one-model recent 1-2q versus earlier 3-4q Super exposure timing.
Sys.setenv(
  MAX_DRAWS="500",
  N_KEEP="100",
  SEED="7092045",
  RESULT_TAG="FULL_500",
  END_YEAR="2025"
)
source("scripts/Woodchester_V7c_super_exposure_recent_vs_earlier_window_model.R")
