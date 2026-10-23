#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
mkdir -p logs results

MODE="${MODE:-smoke}"
SCRIPT="scripts/ModularFitting/Woodchester_V11R_resolution_aware_relocation.R"
RECOVER="scripts/ModularFitting/Woodchester_V11_recover_states.R"

case "${MODE}" in
  smoke)
    MAX_BADGERS="${MAX_BADGERS:-60}"
    NITER="${NITER:-600}"
    NBURN="${NBURN:-300}"
    THIN="${THIN:-2}"
    AF_ADAPT_MAX="${AF_ADAPT_MAX:-300}"
    CHAINS="1"
    ;;
  full)
    MAX_BADGERS="${MAX_BADGERS:-1932}"
    NITER="${NITER:-6000}"
    NBURN="${NBURN:-3000}"
    THIN="${THIN:-2}"
    AF_ADAPT_MAX="${AF_ADAPT_MAX:-2500}"
    CHAINS="1 2 3"
    ;;
  *)
    echo "MODE must be smoke or full" >&2
    exit 2
    ;;
esac

SCALES="${SCALES:-25 50 100}"

echo "============================================================"
echo "V11R RESOLUTION SENSITIVITY"
echo "============================================================"
echo "MODE=${MODE}"
echo "MAX_BADGERS=${MAX_BADGERS}"
echo "NITER=${NITER} NBURN=${NBURN} THIN=${THIN}"
echo "AF_ADAPT_MAX=${AF_ADAPT_MAX}"
echo "RESIDENT MEAN SCALES: ${SCALES} m"
echo "CHAINS: ${CHAINS}"
echo

for scale in ${SCALES}; do
  stem="V11R_RES${scale}_RD_ANNUALAC_FIXEDRES_MULTILOC_AGE_BADGERRE"

  for chain in ${CHAINS}; do
    session="v11r_${MODE}_r${scale}_c${chain}"
    log="logs/${stem}_${MAX_BADGERS}_chain${chain}.log"
    slog="logs/${stem}_${MAX_BADGERS}_states_chain${chain}.log"

    if tmux has-session -t "${session}" 2>/dev/null; then
      echo "Session already exists: ${session}"
      continue
    fi

    if [[ -f "results/${stem}_${MAX_BADGERS}_CHAIN${chain}.rds" ]]; then
      echo "Output already exists; not overwriting:"
      echo "  results/${stem}_${MAX_BADGERS}_CHAIN${chain}.rds"
      continue
    fi

    tmux new-session -d -s "${session}" "bash -lc '
      set -o pipefail
      cd \"$(pwd)\"

      OPENBLAS_NUM_THREADS=1 \
      OMP_NUM_THREADS=1 \
      MKL_NUM_THREADS=1 \
      CHAIN_ID=${chain} \
      MAX_BADGERS=${MAX_BADGERS} \
      NITER=${NITER} \
      NBURN=${NBURN} \
      THIN=${THIN} \
      AF_ADAPT_MAX=${AF_ADAPT_MAX} \
      RESIDENT_MEAN_M=${scale} \
      OUTPUT_STEM=${stem} \
      Rscript ${SCRIPT} 2>&1 | tee ${log}

      fit_status=\${PIPESTATUS[0]}
      if [[ \${fit_status} -ne 0 ]]; then
        echo \"FIT FAILED with status \${fit_status}\" | tee -a ${log}
        exit \${fit_status}
      fi

      OPENBLAS_NUM_THREADS=1 \
      OMP_NUM_THREADS=1 \
      MKL_NUM_THREADS=1 \
      CHAIN_ID=${chain} \
      MAX_BADGERS=${MAX_BADGERS} \
      FILE_STEM=${stem} \
      Rscript ${RECOVER} 2>&1 | tee ${slog}
    '"

    echo "Started ${session}: resident mean=${scale} m, chain=${chain}"
  done
done

echo
echo "Monitor:"
echo "  tmux ls | grep '^v11r_${MODE}_'"
echo
echo "Logs:"
echo "  ls -lh logs/V11R_RES*_RD_ANNUALAC_FIXEDRES_MULTILOC_AGE_BADGERRE_${MAX_BADGERS}_chain*.log"
echo
if [[ "${MODE}" == "full" ]]; then
  echo "After all full chains finish, run for each scale:"
  echo
  for scale in ${SCALES}; do
    stem="V11R_RES${scale}_RD_ANNUALAC_FIXEDRES_MULTILOC_AGE_BADGERRE"
    echo "MAX_BADGERS=1932 FILE_STEM=${stem} \\"
    echo "Rscript scripts/ModularFitting/Woodchester_V11R_three_chain_summary.R \\"
    echo "  2>&1 | tee logs/V11R_RES${scale}_1932_three_chain_summary.log"
    echo
  done
fi
