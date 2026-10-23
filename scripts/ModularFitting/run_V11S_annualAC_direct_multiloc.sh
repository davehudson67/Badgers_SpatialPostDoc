#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
mkdir -p logs results

MODE="${MODE:-smoke}"

case "${MODE}" in
  smoke)
    MAX_BADGERS="${V11S_MAX_BADGERS:-50}"
    NITER="${NITER:-500}"
    NBURN="${NBURN:-250}"
    THIN="${THIN:-2}"
    AF_ADAPT_MAX="${AF_ADAPT_MAX:-500}"
    ;;
  validation)
    MAX_BADGERS="${V11S_MAX_BADGERS:-300}"
    NITER="${NITER:-3000}"
    NBURN="${NBURN:-1500}"
    THIN="${THIN:-2}"
    AF_ADAPT_MAX="${AF_ADAPT_MAX:-1500}"
    ;;
  full)
    MAX_BADGERS="${V11S_MAX_BADGERS:-1932}"
    NITER="${NITER:-3000}"
    NBURN="${NBURN:-1500}"
    THIN="${THIN:-2}"
    AF_ADAPT_MAX="${AF_ADAPT_MAX:-1500}"
    ;;
  *)
    echo "MODE must be smoke, validation, or full" >&2
    exit 2
    ;;
esac

SCRIPT="scripts/ModularFitting/Woodchester_V11S_annualAC_direct_multiloc.R"
STEM="V11S_RD_ANNUALAC_DIRECT_MULTILOC_AGE_BADGERRE"

echo "Launching V11S annual-AC direct multi-location model"
echo "MODE=${MODE}"
echo "MAX_BADGERS=${MAX_BADGERS}"
echo "NITER=${NITER} NBURN=${NBURN} THIN=${THIN} AF_ADAPT_MAX=${AF_ADAPT_MAX}"

for chain in 1 2 3; do
  session="v11s_${MODE}_c${chain}"
  log="logs/${STEM}_${MAX_BADGERS}_chain${chain}.log"
  slog="logs/${STEM}_${MAX_BADGERS}_states_chain${chain}.log"

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
    OUTPUT_STEM=${STEM} \
    Rscript ${SCRIPT} 2>&1 | tee ${log}

    fit_status=\${PIPESTATUS[0]}
    if [[ \${fit_status} -ne 0 ]]; then
      echo \"FIT FAILED with status \${fit_status}\" | tee -a ${log}
      exit \${fit_status}
    fi

    CHAIN_ID=${chain} \
    MAX_BADGERS=${MAX_BADGERS} \
    FILE_STEM=${STEM} \
    Rscript scripts/ModularFitting/Woodchester_V11_recover_states.R \
      2>&1 | tee ${slog}
  '"

  echo "Started ${session}"
done

echo
echo "Monitor with:"
echo "  tmux ls | grep '^v11s_${MODE}_'"
