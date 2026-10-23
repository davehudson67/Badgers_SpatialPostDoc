#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ONE-HIT V10B FULL MOVEMENT AUDIT
#
# Runs, in order:
#   1. global movement-ridge diagnostic;
#   2. state recovery for all three chains (all retained draws);
#   3. cross-chain annual-trajectory diagnostic (all retained draws);
#   4. full movement-biology audit (all retained draws);
#   5. optionally repeats 2--4 for a late-chain window.
#
# Environment:
#   FILE_STEM          required in practice; default current overlap model
#   MAX_BADGERS        default 1932
#   TAIL_MIN_RAW_ITER  default 0 (skip late-tail repeat)
#   HIGH_CUT           default 0.80
#   LOW_CUT            default 0.20
#   RETURN_RATIO       default 0.50
#   GEOM_SEP_M         default 150
#   CULL_YEAR          default 2018
#   CULL_WINDOW        default 6
# =============================================================================

FILE_STEM="${FILE_STEM:-V10B_RD_MULTILOC_AR1_COLLAPSED_ANNUALNC_OVERLAP}"
MAX_BADGERS="${MAX_BADGERS:-1932}"
TAIL_MIN_RAW_ITER="${TAIL_MIN_RAW_ITER:-0}"
HIGH_CUT="${HIGH_CUT:-0.80}"
LOW_CUT="${LOW_CUT:-0.20}"
RETURN_RATIO="${RETURN_RATIO:-0.50}"
GEOM_SEP_M="${GEOM_SEP_M:-150}"
CULL_YEAR="${CULL_YEAR:-2018}"
CULL_WINDOW="${CULL_WINDOW:-6}"

echo "============================================================"
echo "ONE-HIT V10B FULL MOVEMENT AUDIT"
echo "============================================================"
echo "FILE_STEM=${FILE_STEM}"
echo "MAX_BADGERS=${MAX_BADGERS}"
echo "TAIL_MIN_RAW_ITER=${TAIL_MIN_RAW_ITER}"
echo

echo "---- 1. GLOBAL RIDGE DIAGNOSTIC ----"
FILE_STEM="${FILE_STEM}" \
MAX_BADGERS="${MAX_BADGERS}" \
Rscript scripts/ModularFitting/Woodchester_V10B_collapsed_global_ridge_diagnostic.R

run_window () {
  local min_raw="$1"
  local suffix="$2"

  echo
  echo "============================================================"
  echo "AUDIT WINDOW: min raw iteration = ${min_raw}; suffix='${suffix}'"
  echo "============================================================"

  echo "---- 2. RECOVER STATES: CHAINS 1--3 ----"
  for ch in 1 2 3; do
    FILE_STEM="${FILE_STEM}" \
    MAX_BADGERS="${MAX_BADGERS}" \
    CHAIN_ID="${ch}" \
    MIN_RAW_ITER="${min_raw}" \
    STATE_SUFFIX="${suffix}" \
    Rscript scripts/ModularFitting/Woodchester_V10B_collapsed_recover_states.R
  done

  echo "---- 3. CROSS-CHAIN TRAJECTORY DIAGNOSTIC ----"
  FILE_STEM="${FILE_STEM}" \
  MAX_BADGERS="${MAX_BADGERS}" \
  MIN_RAW_ITER="${min_raw}" \
  STATE_SUFFIX="${suffix}" \
  OUTPUT_SUFFIX="${suffix}" \
  Rscript scripts/ModularFitting/Woodchester_V10B_collapsed_trajectory_chain_diagnostic.R

  echo "---- 4. MOVEMENT-BIOLOGY AUDIT ----"
  FILE_STEM="${FILE_STEM}" \
  MAX_BADGERS="${MAX_BADGERS}" \
  OUTPUT_SUFFIX="${suffix}" \
  HIGH_CUT="${HIGH_CUT}" \
  LOW_CUT="${LOW_CUT}" \
  RETURN_RATIO="${RETURN_RATIO}" \
  GEOM_SEP_M="${GEOM_SEP_M}" \
  CULL_YEAR="${CULL_YEAR}" \
  CULL_WINDOW="${CULL_WINDOW}" \
  Rscript scripts/data_audits/V10B_full_movement_biology_audit.R
}

run_window 0 ""

if [[ "${TAIL_MIN_RAW_ITER}" =~ ^[0-9]+$ ]] && (( TAIL_MIN_RAW_ITER > 0 )); then
  run_window "${TAIL_MIN_RAW_ITER}" "_TAIL${TAIL_MIN_RAW_ITER}"
else
  echo
  echo "Late-tail repeat skipped because TAIL_MIN_RAW_ITER=${TAIL_MIN_RAW_ITER}."
fi

echo
echo "============================================================"
echo "ONE-HIT MOVEMENT AUDIT COMPLETE"
echo "============================================================"
