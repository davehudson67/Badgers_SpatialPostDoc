#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
mkdir -p logs results

BASE_STEM="${BASE_STEM:-V11S_RD_ANNUALAC_DIRECT_MULTILOC_AGE_BADGERRE}"
OUT_STEM="${OUT_STEM:-V11S_CONT_RD_ANNUALAC_DIRECT_MULTILOC_AGE_BADGERRE}"
MAX_BADGERS="${MAX_BADGERS:-1932}"

# A controlled terminal-state restart:
# - initialise each chain from its own completed V11S terminal state;
# - re-adapt samplers during burn-in because NIMBLE sampler state is not saved;
# - retain a longer post-burn sample under a new output stem.
NITER="${NITER:-6000}"
NBURN="${NBURN:-1500}"
THIN="${THIN:-2}"
AF_ADAPT_MAX="${AF_ADAPT_MAX:-1500}"

SCRIPT="scripts/ModularFitting/Woodchester_V11S_annualAC_direct_multiloc.R"

echo "Launching V11S terminal-state restart"
echo "BASE_STEM=${BASE_STEM}"
echo "OUT_STEM=${OUT_STEM}"
echo "MAX_BADGERS=${MAX_BADGERS}"
echo "NITER=${NITER} NBURN=${NBURN} THIN=${THIN} AF_ADAPT_MAX=${AF_ADAPT_MAX}"
echo

for chain in 1 2 3; do
  source_fit="results/${BASE_STEM}_${MAX_BADGERS}_CHAIN${chain}.rds"
  session="v11s_cont_c${chain}"
  log="logs/${OUT_STEM}_${MAX_BADGERS}_chain${chain}.log"
  slog="logs/${OUT_STEM}_${MAX_BADGERS}_states_chain${chain}.log"

  if [[ ! -f "${source_fit}" ]]; then
    echo "Missing source fit: ${source_fit}" >&2
    exit 2
  fi

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
    INIT_FROM_FIT=${source_fit} \
    OUTPUT_STEM=${OUT_STEM} \
    Rscript ${SCRIPT} 2>&1 | tee ${log}

    fit_status=\${PIPESTATUS[0]}
    if [[ \${fit_status} -ne 0 ]]; then
      echo \"FIT FAILED with status \${fit_status}\" | tee -a ${log}
      exit \${fit_status}
    fi

    CHAIN_ID=${chain} \
    MAX_BADGERS=${MAX_BADGERS} \
    FILE_STEM=${OUT_STEM} \
    Rscript scripts/ModularFitting/Woodchester_V11_recover_states.R \
      2>&1 | tee ${slog}
  '"

  echo "Started ${session} from ${source_fit}"
done

echo
echo "Monitor:"
echo "  tmux ls | grep '^v11s_cont_'"
echo
echo "After all three finish:"
echo "  MAX_BADGERS=${MAX_BADGERS} FILE_STEM=${OUT_STEM} \\"
echo "  Rscript scripts/ModularFitting/Woodchester_V11S_three_chain_summary.R \\"
echo "    2>&1 | tee logs/${OUT_STEM}_${MAX_BADGERS}_three_chain_summary.log"
