#!/usr/bin/env bash
# Candidate V11R3: smoke first, then explicitly inspected full mode.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
test -n "$V12_SNAPSHOT" || { echo "Set V12_SNAPSHOT to a NEW Supabase snapshot" >&2; exit 1; }
test -f "$V12_SNAPSHOT/MANIFEST.txt" && test -f "$V12_SNAPSHOT/qualifying_live.rds" ||
 { echo "Frozen Supabase files missing" >&2; exit 1; }
command -v tmux >/dev/null
command -v Rscript >/dev/null
mode="$(printenv MODE || echo smoke)"
scenario="$(printenv V11R3_COVERAGE_SCENARIO || echo positive_5year)"
case "$scenario" in all_sites|positive_5year|positive_same_quarter) ;; *)
 echo "Invalid coverage scenario" >&2; exit 2;; esac
case "$mode" in
 smoke) max="$(printenv MAX_BADGERS || echo 60)"
        niter="$(printenv NITER || echo 800)"
        nburn="$(printenv NBURN || echo 400)"
        adapt="$(printenv AF_ADAPT_MAX || echo 300)"
        chains="1";;
 full) if [[ "$(printenv V11R3_SMOKE_VERIFIED || true)" != YES ]]; then
          echo "FULL blocked: inspect smoke, then set V11R3_SMOKE_VERIFIED=YES" >&2; exit 2
       fi
       max="$(printenv MAX_BADGERS || echo 1932)"
       niter="$(printenv NITER || echo 16000)"
       nburn="$(printenv NBURN || echo 6000)"
       adapt="$(printenv AF_ADAPT_MAX || echo 5000)"
       chains="1 2 3";;
 *) echo "MODE must be smoke or full" >&2; exit 2;;
esac
thin="$(printenv THIN || echo 4)"
for val in "$max" "$niter" "$nburn" "$thin" "$adapt"; do
 [[ "$val" =~ ^[0-9]+$ ]] || { echo "Invalid numeric setting" >&2; exit 2; }
done
((max>=2 && niter>nburn && thin>=1)) || { echo "Bad niter/nburn settings" >&2; exit 2; }
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
stem="V11R3_$scenario-RES50_$timestamp"
script="scripts/ModularFitting/Woodchester_V11R3_Curated_Coverage_Scenarios.R"
Rscript -e 'invisible(parse(file="scripts/ModularFitting/Woodchester_V11R3_Curated_Coverage_Scenarios.R"));cat("R parse OK\n")'
mkdir -p logs/v11r3
echo "V11R3 $mode / $scenario; run stem $stem; chains $chains"
echo "LIMITATION: this is a candidate fixed-sett model; nonsett K051 building observation is NOT YET in the likelihood."
echo "The detector availability masks are HYPOTHETICAL; no verified zero trapping effort exists."
snapshot_abs="$(realpath "$V12_SNAPSHOT")"
for chain in $chains; do
 session="v11r3_$mode-$timestamp-c$chain"
 log="logs/v11r3/$stem-chain$chain.log"
 exitfile="logs/v11r3/$stem-chain$chain.exit"
 jobscr="logs/v11r3/$stem-chain$chain.sh"
 [[ ! -e "$jobscr" && ! -e "$log" ]] || { echo "Job exists; refusing overwrite" >&2; exit 1; }
 cat > "$jobscr" <<EOF
#!/usr/bin/env bash
set -uo pipefail
cd "$(pwd)" || exit 1
export V12_SNAPSHOT="$snapshot_abs"
export V11R3_COVERAGE_SCENARIO="$scenario"
export OUTPUT_STEM="$stem" MAX_BADGERS="$max"
export NITER="$niter" NBURN="$nburn" THIN="$thin"
export AF_ADAPT_MAX="$adapt" RESIDENT_MEAN_M=50 CHAIN_ID="$chain"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript "$script" > "$log" 2>&1
status=\$?
echo "\$status" > "$exitfile"
exit "\$status"
EOF
 chmod 700 "$jobscr"
 tmux new-session -d -s "$session" "bash '$jobscr'"
 echo "Launched $session | log $log"
done
echo "Check: tmux ls | grep '^v11r3_'"
echo "Check: find logs/v11r3 -name '*.exit' -print -exec cat {} \\;"
echo "Do NOT infer success from tmux exiting: verify .exit status, summaries and diagnostics."
