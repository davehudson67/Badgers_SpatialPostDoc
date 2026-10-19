#!/usr/bin/env bash
set -euo pipefail

MAX_BADGERS="${MAX_BADGERS:-100}"
NITER="${NITER:-1000}"
NBURN="${NBURN:-500}"
THIN="${THIN:-2}"
AF_ADAPT_MAX="${AF_ADAPT_MAX:-1500}"
FILE_STEM="${FILE_STEM:-V11_RD_MULTILOC_IID_AGE_BADGERRE}"

mkdir -p logs results

echo "============================================================"
echo "V11 smoke: N=${MAX_BADGERS}, NITER=${NITER}, NBURN=${NBURN}, THIN=${THIN}"
echo "============================================================"

for CHAIN_ID in 1 2 3; do
  echo
  echo "---- FIT CHAIN ${CHAIN_ID} ----"
  CHAIN_ID="${CHAIN_ID}" \
  MAX_BADGERS="${MAX_BADGERS}" \
  NITER="${NITER}" \
  NBURN="${NBURN}" \
  THIN="${THIN}" \
  AF_ADAPT_MAX="${AF_ADAPT_MAX}" \
  OUTPUT_STEM="${FILE_STEM}" \
  Rscript scripts/ModularFitting/Woodchester_V11_RD_SCR_MULTILOC_IID_AGE_BADGERRE.R \
  2>&1 | tee "logs/V11_smoke_${MAX_BADGERS}_chain${CHAIN_ID}.log"

  echo
  echo "---- RECOVER STATES CHAIN ${CHAIN_ID} ----"
  CHAIN_ID="${CHAIN_ID}" \
  MAX_BADGERS="${MAX_BADGERS}" \
  FILE_STEM="${FILE_STEM}" \
  Rscript scripts/ModularFitting/Woodchester_V11_recover_states.R \
  2>&1 | tee "logs/V11_states_${MAX_BADGERS}_chain${CHAIN_ID}.log"
done

echo
echo "---- COMBINE CHAINS ----"
MAX_BADGERS="${MAX_BADGERS}" \
FILE_STEM="${FILE_STEM}" \
Rscript scripts/ModularFitting/Woodchester_V11_combine_chains.R \
2>&1 | tee "logs/V11_combine_${MAX_BADGERS}.log"

echo
echo "V11 smoke workflow complete."
