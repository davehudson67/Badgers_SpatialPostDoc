#!/usr/bin/env bash
# Run V12I-03 validation chains concurrently in separate tmux sessions.
# Safe defaults: 3 simulated datasets x 3 chains, at most 3 sessions launched at once.
# No DB writes; does not touch old result directories.
set -euo pipefail
cd "${HOME}/Badgers_SpatialPostDoc"
command -v tmux >/dev/null || { echo "tmux missing"; exit 1; }
command -v Rscript >/dev/null || { echo "Rscript missing"; exit 1; }
Rscript -e 'stopifnot(requireNamespace("nimble",quietly=TRUE), requireNamespace("posterior",quietly=TRUE))'
SCRIPT="scripts/ModularFitting/Woodchester_V12I_03_NIMBLE_Spatial_Smoke.R"
[[ -f "$SCRIPT" ]] || { echo "Missing spatial script"; exit 1; }
REPS="${V12I_REPS:-3}"
CHAINS="${V12I_CHAINS:-3}"
MAX_PARALLEL="${V12I_MAX_PARALLEL:-3}"
NITER="${V12I_NITER:-12000}"
NBURN="${V12I_NBURN:-4000}"
RUN_ID="${V12I_RUN_ID:-v12i03b_$(date -u +%Y%m%dT%H%M%SZ)}"
[[ "$RUN_ID" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "Invalid RUN_ID"; exit 1; }
for n in "$REPS" "$CHAINS" "$MAX_PARALLEL" "$NITER" "$NBURN"; do
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "Invalid numeric parameter"; exit 1; }
done
(( REPS>=1 && CHAINS>=2 && MAX_PARALLEL>=1 && NITER>NBURN && NBURN>=10 )) ||
  { echo "Invalid settings"; exit 1; }
(( MAX_PARALLEL<=9 )) || { echo "Limit maximum parallel sessions to 9"; exit 1; }
BASE="outputs/v12_immigration_prototype/v12i03_validation/$RUN_ID"
[[ ! -e "$BASE" ]] || { echo "Refusing to overwrite existing run: $BASE"; exit 1; }
mkdir -p "$BASE"
printf 'run_id=%s\nreps=%s\nchains=%s\nmax_parallel=%s\nniter=%s\nburn=%s\n' \
  "$RUN_ID" "$REPS" "$CHAINS" "$MAX_PARALLEL" "$NITER" "$NBURN" > "$BASE/settings.txt"
git rev-parse HEAD > "$BASE/git_commit.txt"
echo "$BASE" > "$BASE/run_path.txt"
# Stage every job command in its private script. No credentials are embedded.
for ((r=1;r<=REPS;r++)); do
  printf -v rr '%02d' "$r"
  for ((ch=1;ch<=CHAINS;ch++)); do
    printf -v cc '%02d' "$ch"
    dir="$BASE/rep${rr}_chain${cc}"
    mkdir -p "$dir"
    cat > "$dir/run.sh" <<EOS
#!/usr/bin/env bash
cd "${HOME}/Badgers_SpatialPostDoc" || exit 1
export V12I_OUT="$dir"
export V12I_DATA_SEED="$((20261109+1000*r))"
export V12I_SEED="$((20261109+1000*r+ch))"
export V12I_MATCHED_PRIOR=1
export V12I_NITER="$NITER"
export V12I_NBURN="$NBURN"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript "$SCRIPT" > "$dir/fit.log" 2>&1
status=\$?
echo "\$status" > "$dir/exit_status.txt"
exit "\$status"
EOS
    chmod 700 "$dir/run.sh"
  done
done
# Limit simultaneous active sessions; leave completed sessions discoverable in files.
for ((r=1;r<=REPS;r++)); do
  printf -v rr '%02d' "$r"
  for ((ch=1;ch<=CHAINS;ch++)); do
    printf -v cc '%02d' "$ch"
    session="v12i_${RUN_ID}_r${rr}c${cc}"
    while true; do
      active=0
      for ((i=1;i<=REPS;i++)); do
        printf -v ii '%02d' "$i"
        for ((j=1;j<=CHAINS;j++)); do
          printf -v jj '%02d' "$j"
          tmux has-session -t "v12i_${RUN_ID}_r${ii}c${jj}" 2>/dev/null &&
            active=$((active+1)) || true
        done
      done
      (( active<MAX_PARALLEL )) && break
      sleep 5
    done
    tmux new-session -d -s "$session" \
      "bash '$BASE/rep${rr}_chain${cc}/run.sh'"
    printf 'Launched %-38s %s\n' "$session" "$BASE/rep${rr}_chain${cc}/fit.log"
  done
done
echo
echo "Batch launched: $BASE"
echo "tmux ls | grep v12i_"
echo "Watch: tail -f $BASE/rep01_chain01/fit.log"
echo "Completed: find $BASE -name exit_status.txt -type f | wc -l"
echo "Summarise after all jobs have exit_status.txt = 0:"
echo "V12I_VALIDATION_OUT='$BASE' V12I_REPS=$REPS V12I_CHAINS=$CHAINS Rscript scripts/ModularFitting/Woodchester_V12I_03c_Summarise_Parallel.R"
