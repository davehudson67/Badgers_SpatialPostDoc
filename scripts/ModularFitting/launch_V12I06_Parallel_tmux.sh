#!/usr/bin/env bash
# Three concurrent V12I-06 synthetic chains; no real-data demographic inference.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
root=$(cd -- "$script_dir/../.." && pwd)
script="$script_dir/launch_V12I06_Parallel_tmux.sh"
cd "$root"

if [[ "$#" -gt 0 && "$1" == "--worker" ]]; then
  run="$2"
  exec >>"$run/launcher.log" 2>&1
  trap 'rc=$?; printf "%s\n" "$rc" >"$run/launcher.exit"' EXIT
  export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
  export V12I06_N=60 V12I06_T=8
  export V12I06_NITER=12000 V12I06_NBURN=4000 V12I06_THIN=2
  export V12I06_DATA_SEED=20261110
  pids=()
  for ch in 1 2 3; do
    printf -v tag 'chain%02d' "$ch"
    (
      set +e
      V12I06_SEED=$((20261110 + ch)) V12I06_OUT="$run/$tag" \
        Rscript scripts/ModularFitting/Woodchester_V12I_06_Core_Periphery_Entry_Survival_Smoke.R \
        >"$run/$tag.log" 2>&1
      rc=$?
      printf '%s\n' "$rc" >"$run/$tag.exit"
      exit "$rc"
    ) &
    pids+=("$!")
    printf 'Started %s, PID %s\n' "$tag" "$!"
  done
  failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then failed=1; fi
  done
  if [[ "$failed" -ne 0 ]]; then
    echo "A chain failed; inspect chain logs and .exit files. Validation skipped."
    exit 1
  fi
  V12I06_VALIDATION_OUT="$run" V12I06_CHAINS=3 \
    Rscript scripts/ModularFitting/Woodchester_V12I_06b_Validate_Multichain.R \
    >"$run/validation.log" 2>&1
  echo "All chains finished; inspect multichain_summary.csv and validation.log."
  echo "A zero launcher exit means execution succeeded, not that diagnostics passed."
  exit 0
fi

command -v tmux >/dev/null
command -v Rscript >/dev/null
Rscript -e 'stopifnot(requireNamespace("nimble", quietly=TRUE), requireNamespace("posterior", quietly=TRUE))'
mkdir -p outputs/v12_immigration_prototype
stamp=$(date -u +%Y%m%dT%H%M%SZ)
run=$(mktemp -d "$root/outputs/v12_immigration_prototype/v12i06_parallel_$stamp"_"XXXXXX")
session="v12i06_$stamp"_"$$"
printf -v command '%q ' bash "$script" --worker "$run"
tmux new-session -d -s "$session" "$command"
printf 'Session: %s\nOutput: %s\nAttach: tmux attach -t %s\n' "$session" "$run" "$session"
printf 'Progress: tail -f "%s/launcher.log"\n' "$run"
