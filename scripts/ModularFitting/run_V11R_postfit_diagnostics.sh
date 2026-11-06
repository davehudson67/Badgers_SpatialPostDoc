#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
mkdir -p logs results

MAX_BADGERS="${MAX_BADGERS:-1932}"
SCALES="${SCALES:-25 50 100}"

echo "============================================================"
echo "V11R POST-FIT DIAGNOSTICS"
echo "============================================================"
echo "MAX_BADGERS=${MAX_BADGERS}"
echo "SCALES=${SCALES}"
echo

for scale in ${SCALES}; do
  stem="V11R_RES${scale}_RD_ANNUALAC_FIXEDRES_MULTILOC_AGE_BADGERRE"

  echo "===== ${scale} m three-chain summary ====="

  MAX_BADGERS="${MAX_BADGERS}"   FILE_STEM="${stem}"   Rscript scripts/ModularFitting/Woodchester_V11R_three_chain_summary.R     2>&1 | tee "logs/V11R_RES${scale}_${MAX_BADGERS}_three_chain_summary.log"

  echo
done

echo "===== Cross-resolution sensitivity ====="
MAX_BADGERS="${MAX_BADGERS}" SCALES="$(echo "${SCALES}" | tr ' ' ',')" Rscript scripts/ModularFitting/Woodchester_V11R_resolution_sensitivity_summary.R   2>&1 | tee "logs/V11R_resolution_sensitivity_${MAX_BADGERS}.log"

echo
echo "V11R post-fit diagnostics complete."
