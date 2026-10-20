#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
mkdir -p logs results

MODE="${MODE:-smoke}"

if [[ "${MODE}" == "smoke" ]]; then
  MAX_BADGERS="${MAX_BADGERS:-50}"
  NITER="${NITER:-500}"
  NBURN="${NBURN:-250}"
  THIN="${THIN:-2}"
  AF_ADAPT_MAX="${AF_ADAPT_MAX:-500}"
elif [[ "${MODE}" == "full" ]]; then
  MAX_BADGERS="${MAX_BADGERS:-300}"
  NITER="${NITER:-3000}"
  NBURN="${NBURN:-1500}"
  THIN="${THIN:-2}"
  AF_ADAPT_MAX="${AF_ADAPT_MAX:-1500}"
else
  echo "MODE must be smoke or full" >&2
  exit 2
fi

variants=(
  "CTL|scripts/ModularFitting/Woodchester_V11_centered_annual_sampler_check.R|V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTEREDCHECK"
  "JH|scripts/ModularFitting/Woodchester_V11_centered_joint_high_scale.R|V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_JOINT_HIGH"
  "JL|scripts/ModularFitting/Woodchester_V11_centered_joint_local_scale.R|V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_JOINT_LOCAL"
  "MS|scripts/ModularFitting/Woodchester_V11_centered_meansep_scale.R|V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_MEANSEP"
)

echo "Launching V11 parameterisation race"
echo "MODE=${MODE}"
echo "MAX_BADGERS=${MAX_BADGERS}"
echo "NITER=${NITER} NBURN=${NBURN} THIN=${THIN} AF_ADAPT_MAX=${AF_ADAPT_MAX}"

for spec in "${variants[@]}"; do
  IFS='|' read -r tag script stem <<< "${spec}"

  for chain in 1 2 3; do
    session="v11race_${MODE}_${tag}_c${chain}"
    log="logs/${stem}_${MAX_BADGERS}_chain${chain}.log"
    slog="logs/${stem}_${MAX_BADGERS}_states_chain${chain}.log"

    if tmux has-session -t "${session}" 2>/dev/null; then
      echo "Session already exists: ${session}"
      continue
    fi

    tmux new-session -d -s "${session}" "bash -lc '
      set -o pipefail
      cd \"$(pwd)\"

      CHAIN_ID=${chain} \
      MAX_BADGERS=${MAX_BADGERS} \
      NITER=${NITER} \
      NBURN=${NBURN} \
      THIN=${THIN} \
      AF_ADAPT_MAX=${AF_ADAPT_MAX} \
      OUTPUT_STEM=${stem} \
      Rscript ${script} \
      2>&1 | tee ${log} &&

      CHAIN_ID=${chain} \
      MAX_BADGERS=${MAX_BADGERS} \
      FILE_STEM=${stem} \
      Rscript scripts/ModularFitting/Woodchester_V11_recover_states.R \
      2>&1 | tee ${slog}
    '"

    echo "Started ${session}"
  done
done

echo
echo "Current race sessions:"
tmux ls 2>/dev/null | grep 'v11race_' || true
