# Smoke test: irreversible source history + within-group/Mundlak + capture-intensity adjustment.
Sys.setenv(
  MAX_DRAWS="100",
  N_KEEP="50",
  SEED="7092045",
  RESULT_TAG="SMOKE_100",
  END_YEAR="2025"
)
source("scripts/Woodchester_V7c_quarterly_recipient_hazard_irreversible_MUNDLAK.R")
