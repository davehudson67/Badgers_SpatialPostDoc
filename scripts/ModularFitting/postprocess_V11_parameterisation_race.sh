#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
mkdir -p logs results

MAX_BADGERS="\${MAX_BADGERS:-300}"
PPC_DRAWS="\${PPC_DRAWS:-500}"

stems=(
  "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTEREDCHECK"
  "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_JOINT_HIGH"
  "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_JOINT_LOCAL"
  "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTERED_MEANSEP"
)

for stem in "\${stems[@]}"; do
  echo
  echo "============================================================"
  echo "POSTPROCESS \${stem}"
  echo "============================================================"

  MAX_BADGERS="\${MAX_BADGERS}" \
  FILE_STEM="\${stem}" \
  Rscript scripts/ModularFitting/Woodchester_V11_combine_chains.R \
    2>&1 | tee "logs/\${stem}_\${MAX_BADGERS}_combine.log"

  MAX_BADGERS="\${MAX_BADGERS}" \
  FILE_STEM="\${stem}" \
  PPC_DRAWS="\${PPC_DRAWS}" \
  Rscript scripts/ModularFitting/Woodchester_V11_repeat_mover_ppc.R \
    2>&1 | tee "logs/\${stem}_\${MAX_BADGERS}_ppc.log"
done

MAX_BADGERS="\${MAX_BADGERS}" \
Rscript scripts/ModularFitting/Woodchester_V11_compare_parameterisations.R \
  2>&1 | tee "logs/V11_parameterisation_comparison_\${MAX_BADGERS}.log"
