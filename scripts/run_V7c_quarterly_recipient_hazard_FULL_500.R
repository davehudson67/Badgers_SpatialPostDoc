# Full V7c quarterly recipient infection-hazard analysis.
# Only run after the SMOKE_100 fit audit is clean.
Sys.setenv(
  MAX_DRAWS="500",
  N_KEEP="100",
  SEED="7092045",
  RESULT_TAG="FULL_500",
  END_YEAR="2025"
)
source("scripts/Woodchester_V7c_quarterly_recipient_hazard_models.R")
