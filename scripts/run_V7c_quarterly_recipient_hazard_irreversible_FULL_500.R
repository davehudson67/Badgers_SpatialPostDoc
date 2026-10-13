# Full corrected quarterly V7c hazard model using irreversible source history.
Sys.setenv(
  MAX_DRAWS="500",
  N_KEEP="100",
  SEED="7092045",
  RESULT_TAG="FULL_500",
  END_YEAR="2025"
)
source("scripts/Woodchester_V7c_quarterly_recipient_hazard_irreversible_sources.R")
