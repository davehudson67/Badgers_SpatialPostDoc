#!/usr/bin/env bash
set -euo pipefail
mkdir -p logs results data

echo "============================================================"
echo "BUILDING FINAL V9 PHASE-2 PAIRED HISTORIES"
echo "============================================================"
Rscript scripts/ModularFitting/Woodchester_PHASE2_V9_FINAL_build_and_audit.R   > logs/V9FINAL_PHASE2_BUILD.log 2>&1
echo "Phase-2 V9 final adapter complete."

launch(){
  local name="$1"; shift
  nohup "$@" > "logs/${name}.log" 2>&1 &
  echo "${name} PID=$!"
}

echo "============================================================"
echo "LAUNCHING FINAL V9 DOWNSTREAM ANALYSES"
echo "============================================================"

launch V9FINAL_V7a_FULL   env MAX_PAIRS=1500 N_PROP=3000 N_KEEP=100 SEED=7092028 RESULT_TAG=FULL_1500   Rscript scripts/ModularFitting/Woodchester_V9FINAL_V7aM_infection_to_movement.R

launch V9FINAL_V7b_FULL   env MAX_PAIRS=1500 N_PROP=4000 N_KEEP=100 SEED=7092029 RESULT_TAG=FULL_1500   Rscript scripts/ModularFitting/Woodchester_V9FINAL_V7bM_movement_to_infection.R

launch V9FINAL_V7a_AGE_FULL   env MAX_PAIRS=1500 N_PROP=3000 N_KEEP=50 SEED=7092061 RESULT_TAG=FULL_1500   Rscript scripts/ModularFitting/Woodchester_V9FINAL_V7aM_knownage_age_sensitivity.R

launch V9FINAL_V7b_AGE_FULL   env MAX_PAIRS=1500 N_PROP=3000 N_KEEP=50 SEED=7092062 RESULT_TAG=FULL_1500   Rscript scripts/ModularFitting/Woodchester_V9FINAL_V7bM_knownage_age_sensitivity.R

launch V9FINAL_PRESSURE_MINN1_FULL   env MAX_PAIRS=1500 N_KEEP=50 MIN_GROUP_N=1 RESULT_TAG=FULL_1500_MINN1 SEED=7092063   Rscript scripts/ModularFitting/Woodchester_V9FINAL_V7bM_samegroup_pressure.R

launch V9FINAL_PRESSURE_MINN3_FULL   env MAX_PAIRS=1500 N_KEEP=50 MIN_GROUP_N=3 RESULT_TAG=FULL_1500_MINN3 SEED=7092063   Rscript scripts/ModularFitting/Woodchester_V9FINAL_V7bM_samegroup_pressure.R

echo
echo "All six final downstream jobs launched."
echo "Check with:"
echo "  ps -u \"\$USER\" -o pid,etime,%cpu,%mem,args --sort=-%cpu | grep -E 'V9FINAL|Woodchester_V9FINAL' | grep -v grep"
echo "Logs are under logs/V9FINAL_*.log"
