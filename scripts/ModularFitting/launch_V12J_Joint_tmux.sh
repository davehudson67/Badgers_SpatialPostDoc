#!/usr/bin/env bash
# Prepare once, compile/check, then run three concurrent real-data chains.
# Existing fits/snapshots are never overwritten. No detailed effort required.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
root=$(cd -- "$script_dir/../.." && pwd)
cd "$root"
if [[ "${1:-}" == "--worker" ]]; then
  run=$2
  exec >>"$run/launcher.log" 2>&1
  trap 'rc=$?; printf "%s\n" "$rc" >"$run/launcher.exit"' EXIT
  export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
  export V12J_RUN="$run"
  git rev-parse HEAD >"$run/source_commit.txt"
  mkdir -p "$run/source/scripts/ModularFitting" "$run/source/scripts/database"
  cp scripts/ModularFitting/Woodchester_V12J*.R "$run/source/scripts/ModularFitting/"
  cp scripts/ModularFitting/launch_V12J_Joint_tmux.sh "$run/source/scripts/ModularFitting/"
  cp scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R "$run/source/scripts/database/"
  if [[ "${ZONE_AUDIT_DIR:-}" != /* ]]; then
    export ZONE_AUDIT_DIR="$root/${ZONE_AUDIT_DIR:-outputs/v11r2_core_periphery/audit_20261109T134751Z}"
  fi
  cd "$run/source"
  Rscript -e 'f<-c(Sys.glob("scripts/ModularFitting/Woodchester_V12J*.R"),"scripts/ModularFitting/launch_V12J_Joint_tmux.sh","scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R");write.csv(data.frame(path=f,sha256=vapply(f,digest::digest,character(1),file=TRUE,algo="sha256")),file.path(Sys.getenv("V12J_RUN"),"source_sha256.csv"),row.names=FALSE)'
  echo "Preparing real-data joint likelihood inputs from $V12_SNAPSHOT"
  Rscript scripts/ModularFitting/Woodchester_V12J_Prepare.R >"$run/preparation.log" 2>&1
  export V12J_INPUT="$run/joint_inputs.rds"
  echo "Checking compiled joint recursion against exact state-path enumeration."
  Rscript scripts/ModularFitting/Woodchester_V12J_Check.R >"$run/likelihood_checks.log" 2>&1
  echo "Running short REAL-data compilation/initialisation smoke."
  V12J_MAX_BADGERS=12 V12J_AUGMENT=4 V12J_NITER=80 V12J_NBURN=40 \
    V12J_THIN=2 V12J_SPATIAL_DRAWS=5 V12J_SEED=20261110 V12J_OUT="$run/smoke" \
    Rscript scripts/ModularFitting/Woodchester_V12J_Fit.R >"$run/smoke.log" 2>&1
  echo "Smoke completed; starting three concurrent real-data chains."
  pids=()
  for ch in 1 2 3; do
    printf -v tag 'chain%02d' "$ch"
    (
      set +e
      V12J_SEED=$((20261110 + ch)) V12J_OUT="$run/$tag" \
        Rscript scripts/ModularFitting/Woodchester_V12J_Fit.R >"$run/$tag.log" 2>&1
      rc=$?
      printf '%s\n' "$rc" >"$run/$tag.exit"
      exit "$rc"
    ) &
    pids+=("$!")
    printf 'Started %s, PID %s\n' "$tag" "$!"
  done
  failed=0
  for pid in "${pids[@]}"; do if ! wait "$pid"; then failed=1; fi; done
  if [[ "$failed" != 0 ]]; then
    echo "A chain failed. Inspect chain logs; no pooled results produced."
    exit 1
  fi
  Rscript scripts/ModularFitting/Woodchester_V12J_Summarise.R >"$run/validation.log" 2>&1
  echo "Finished. Read multichain_summary.csv and VALIDATION_STATUS.txt."
  echo "Execution success does not mean convergence or validated population inference."
  exit 0
fi
command -v Rscript >/dev/null
command -v tmux >/dev/null
Rscript -e 'for(p in c("nimble","posterior","sf","digest","bit64"))stopifnot(requireNamespace(p,quietly=TRUE))'
if [[ -z "${V12_SNAPSHOT:-}" ]]; then
  V12_SNAPSHOT=$(Rscript -e '
    d<-list.dirs("data/model_snapshots",recursive=FALSE,full.names=TRUE)
    ok<-vapply(d,function(x){f<-file.path(x,"MANIFEST.txt");
      file.exists(f)&&any(grepl("^source_record_evidence=",readLines(f,warn=FALSE)))},logical(1))
    d<-d[ok];if(!length(d))stop("No source-rich Supabase snapshot; run scripts/database/freeze_woodchester_v12_inputs.R")
    cat(d[which.max(file.info(file.path(d,"MANIFEST.txt"))$mtime)])')
fi
V12_SNAPSHOT=$(cd -- "$V12_SNAPSHOT" && pwd)
export V12_SNAPSHOT
# Full capture cohort by default; optional subset is explicitly a smoke fit.
export V12J_MAX_BADGERS="${V12J_MAX_BADGERS:-0}"
export V12J_AUGMENT="${V12J_AUGMENT:-200}"
export V12J_NITER="${V12J_NITER:-2000}"
export V12J_NBURN="${V12J_NBURN:-1000}"
export V12J_THIN="${V12J_THIN:-2}"
export V12J_COVERAGE="${V12J_COVERAGE:-positive_5year}"
export V12J_MORTALITY="${V12J_MORTALITY:-candidate_recovery}"
mkdir -p outputs/v12_joint
stamp=$(date -u +%Y%m%dT%H%M%SZ)
run=$(mktemp -d "$root/outputs/v12_joint/v12j_$stamp"_XXXXXX)
session="v12j_${stamp}_${BASHPID}"
printf '%s\n' "$V12_SNAPSHOT" >"$run/snapshot_path.txt"
Rscript -e 'x<-Sys.getenv();k<-grepl("^V12J_|^V12_SNAPSHOT$",names(x));cat(paste(names(x)[k],x[k],sep="="),sep="\n")' >"$run/run_settings.txt"
printf -v command '%q ' env V12_SNAPSHOT="$V12_SNAPSHOT" \
 V12J_MAX_BADGERS="$V12J_MAX_BADGERS" V12J_AUGMENT="$V12J_AUGMENT" \
 V12J_NITER="$V12J_NITER" V12J_NBURN="$V12J_NBURN" V12J_THIN="$V12J_THIN" \
 V12J_COVERAGE="$V12J_COVERAGE" V12J_MORTALITY="$V12J_MORTALITY" \
 V12J_BUFFER_KM="${V12J_BUFFER_KM:-2}" V12J_CORE_FRACTION="${V12J_CORE_FRACTION:-0.65}" \
 V12J_RESIDENT_MEAN_M="${V12J_RESIDENT_MEAN_M:-50}" V12J_AUX_SD_M="${V12J_AUX_SD_M:-250}" \
 V12J_SPATIAL_DRAWS="${V12J_SPATIAL_DRAWS:-100}" V12J_SUMMARY_DRAWS="${V12J_SUMMARY_DRAWS:-20}" \
 ZONE_AUDIT_DIR="${ZONE_AUDIT_DIR:-outputs/v11r2_core_periphery/audit_20261109T134751Z}" \
 bash "$script_dir/launch_V12J_Joint_tmux.sh" --worker "$run"
tmux new-session -d -s "$session" "$command"
printf 'Session: %s\nOutput: %s\nSnapshot: %s\n' "$session" "$run" "$V12_SNAPSHOT"
printf 'Progress: tail -f "%s/launcher.log"\n' "$run"
