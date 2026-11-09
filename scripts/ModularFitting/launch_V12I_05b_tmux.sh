#!/usr/bin/env bash
# Parallel synthetic V12I-05 model validation, preserving all prior outputs.
set -euo pipefail
cd "${HOME}/Badgers_SpatialPostDoc"
command -v tmux >/dev/null
command -v Rscript >/dev/null
Rscript -e 'stopifnot(requireNamespace("nimble",quietly=TRUE),requireNamespace("posterior",quietly=TRUE))'
script="scripts/ModularFitting/Woodchester_V12I_05_Joint_Spatial_Survival_Smoke.R"
[[ -f "$script" ]] || { echo "Missing script: $script"; exit 1; }
reps="${V12I_REPS:-3}"
chains="${V12I_CHAINS:-3}"
parallel="${V12I_MAX_PARALLEL:-3}"
niter="${V12I_NITER:-12000}"
nburn="${V12I_NBURN:-4000}"
n="${V12I_N:-12}"
t="${V12I_T:-4}"
for value in "$reps" "$chains" "$parallel" "$niter" "$nburn" "$n" "$t"; do
  [[ "$value" =~ ^[0-9]+$ ]] || { echo "Invalid numeric setting"; exit 1; }
done
((reps>=1 && chains>=2 && parallel>=1 && parallel<=6 && niter>nburn && nburn>=10 && n>=2 && t>=2)) ||
  { echo "Invalid run dimensions"; exit 1; }
id="v12i05b_$(date -u +%Y%m%dT%H%M%SZ)"
base="outputs/v12_immigration_prototype/v12i05_validation/$id"
[[ ! -e "$base" ]] || { echo "Output already exists"; exit 1; }
mkdir -p "$base"
git rev-parse HEAD > "$base/git_commit.txt"
printf 'reps=%s\nchains=%s\nparallel=%s\nniter=%s\nnburn=%s\nn=%s\nt=%s\n' \
 "$reps" "$chains" "$parallel" "$niter" "$nburn" "$n" "$t" > "$base/settings.txt"
# Stage commands before launching.
for ((r=1;r<=reps;r++)); do
 for ((ch=1;ch<=chains;ch++)); do
  printf -v rr '%02d' "$r"
  printf -v cc '%02d' "$ch"
  dir="$base/rep${rr}_chain${cc}"
  mkdir -p "$dir"
  cat > "$dir/run.sh" <<EOF
#!/usr/bin/env bash
cd "${HOME}/Badgers_SpatialPostDoc" || exit 1
export V12I_OUT="$dir"
export V12I_DATA_SEED="$((20261109+1000*r))"
export V12I_SEED="$((20261109+1000*r+ch))"
export V12I_N="$n" V12I_T="$t"
export V12I_NITER="$niter" V12I_NBURN="$nburn"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript "$script" > "$dir/fit.log" 2>&1
status=\$?
echo "\$status" > "$dir/exit_status.txt"
exit "\$status"
EOF
  chmod 700 "$dir/run.sh"
 done
done
for ((r=1;r<=reps;r++)); do
 for ((ch=1;ch<=chains;ch++)); do
  printf -v rr '%02d' "$r"
  printf -v cc '%02d' "$ch"
  session="v12i05_${id}_r${rr}c${cc}"
  while :; do
   active=0
   for ((i=1;i<=reps;i++)); do
    for ((j=1;j<=chains;j++)); do
     printf -v ii '%02d' "$i"
     printf -v jj '%02d' "$j"
     tmux has-session -t "v12i05_${id}_r${ii}c${jj}" 2>/dev/null &&
       active=$((active+1)) || true
    done
   done
   ((active<parallel)) && break
   sleep 5
  done
  tmux new-session -d -s "$session" "bash '$base/rep${rr}_chain${cc}/run.sh'"
  echo "Launched $session"
 done
done
echo "Run directory: $base"
echo "After all chains finish with exit code 0:"
echo "V12I_VALIDATION_OUT='$base' V12I_REPS=$reps V12I_CHAINS=$chains Rscript scripts/ModularFitting/Woodchester_V12I_05b_Validate.R"
