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
  export V12K_RUN="$run"
  reference_input="${V12K_REFERENCE_INPUT:-$root/outputs/v12_joint/v12j_20261110T150849Z_ne5fqL/joint_inputs.rds}"
  if [[ "$reference_input" != /* ]]; then reference_input="$root/$reference_input"; fi
  export V12K_REFERENCE_INPUT="$reference_input"
  hostname >"$run/hostname.txt"
  git rev-parse HEAD >"$run/source_commit.txt"
  mkdir -p "$run/source/scripts/ModularFitting" "$run/source/scripts/database"
  cp scripts/ModularFitting/Woodchester_V12K*.R "$run/source/scripts/ModularFitting/"
  cp scripts/ModularFitting/launch_V12K_Covariates_tmux.sh "$run/source/scripts/ModularFitting/"
  cp scripts/ModularFitting/Woodchester_V12J_Prepare.R "$run/source/scripts/ModularFitting/"
  cp scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R "$run/source/scripts/database/"
  if [[ "${ZONE_AUDIT_DIR:-}" != /* ]]; then
    export ZONE_AUDIT_DIR="$root/${ZONE_AUDIT_DIR:-outputs/v11r2_core_periphery/audit_20261109T134751Z}"
  fi
  cd "$run/source"
  Rscript -e 'f<-c(Sys.glob("scripts/ModularFitting/Woodchester_V12K*.R"),"scripts/ModularFitting/launch_V12K_Covariates_tmux.sh","scripts/database/Woodchester_V12_Spatial_Eligibility_Rules.R","scripts/ModularFitting/Woodchester_V12J_Prepare.R");write.csv(data.frame(path=f,sha256=vapply(f,digest::digest,character(1),file=TRUE,algo="sha256")),file.path(Sys.getenv("V12K_RUN"),"source_sha256.csv"),row.names=FALSE)'
  echo "Preparing real-data joint likelihood inputs from $V12_SNAPSHOT"
  Rscript scripts/ModularFitting/Woodchester_V12K_Prepare.R >"$run/preparation.log" 2>&1
  export V12K_INPUT="$run/joint_covariate_inputs.rds"
  echo "Checking compiled joint recursion against exact state-path enumeration."
  Rscript scripts/ModularFitting/Woodchester_V12K_Check.R >"$run/likelihood_checks.log" 2>&1
  echo "Running short REAL-data compilation/initialisation smoke."
  V12K_MAX_BADGERS=12 V12K_AUGMENT=4 V12K_NITER=80 V12K_NBURN=40 \
    V12K_THIN=2 V12K_SPATIAL_DRAWS=5 V12K_SEED=20261110 V12K_OUT="$run/smoke" \
    Rscript scripts/ModularFitting/Woodchester_V12K_Fit.R >"$run/smoke.log" 2>&1
  echo "Smoke completed; starting three concurrent real-data chains."
  pids=()
  for ch in 1 2 3; do
    printf -v tag 'chain%02d' "$ch"
    (
      set +e
      V12K_SEED=$((20261110 + ch)) V12K_OUT="$run/$tag" \
        Rscript scripts/ModularFitting/Woodchester_V12K_Fit.R >"$run/$tag.log" 2>&1
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
  Rscript scripts/ModularFitting/Woodchester_V12K_Summarise.R >"$run/validation.log" 2>&1
  echo "Finished. Read multichain_summary.csv and VALIDATION_STATUS.txt."
  echo "Execution success does not mean convergence or validated population inference."
  exit 0
fi
expected_host="${V12K_EXPECT_HOST:-rstudio02n}"
if [[ "$(hostname -s)" != "$expected_host" ]]; then
  echo "Run this launcher on $expected_host (current host: $(hostname -s))." >&2
  exit 1
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
export V12K_MAX_BADGERS="${V12K_MAX_BADGERS:-0}"
export V12K_AUGMENT="${V12K_AUGMENT:-200}"
export V12K_NITER="${V12K_NITER:-2000}"
export V12K_NBURN="${V12K_NBURN:-1000}"
export V12K_THIN="${V12K_THIN:-2}"
export V12K_COVERAGE="${V12K_COVERAGE:-positive_5year}"
export V12K_MORTALITY="${V12K_MORTALITY:-candidate_recovery}"
mkdir -p outputs/v12_covariates
stamp=$(date -u +%Y%m%dT%H%M%SZ)
run=$(mktemp -d "$root/outputs/v12_covariates/v12k_$stamp"_XXXXXX)
session="v12k_${stamp}_${BASHPID}"
printf '%s\n' "$V12_SNAPSHOT" >"$run/snapshot_path.txt"
Rscript -e 'x<-Sys.getenv();k<-grepl("^V12K_|^V12_SNAPSHOT$",names(x));cat(paste(names(x)[k],x[k],sep="="),sep="\n")' >"$run/run_settings.txt"
printf -v command '%q ' env V12_SNAPSHOT="$V12_SNAPSHOT" \
 V12K_MAX_BADGERS="$V12K_MAX_BADGERS" V12K_AUGMENT="$V12K_AUGMENT" \
 V12K_NITER="$V12K_NITER" V12K_NBURN="$V12K_NBURN" V12K_THIN="$V12K_THIN" \
 V12K_COVERAGE="$V12K_COVERAGE" V12K_MORTALITY="$V12K_MORTALITY" \
 V12K_BUFFER_KM="${V12K_BUFFER_KM:-2}" V12K_CORE_FRACTION="${V12K_CORE_FRACTION:-0.65}" \
 V12K_RESIDENT_MEAN_M="${V12K_RESIDENT_MEAN_M:-50}" V12K_AUX_SD_M="${V12K_AUX_SD_M:-250}" \
 V12K_SPATIAL_DRAWS="${V12K_SPATIAL_DRAWS:-300}" V12K_SUMMARY_DRAWS="${V12K_SUMMARY_DRAWS:-20}" \
 V12K_BIRTH_PADDING="${V12K_BIRTH_PADDING:-30}" \
 V12K_ADULT_MIN_AGE="${V12K_ADULT_MIN_AGE:-1}" \
 V12K_FIRST_YEAR="${V12K_FIRST_YEAR:-1977}" V12K_LAST_YEAR="${V12K_LAST_YEAR:-2025}" \
 V12K_REFERENCE_INPUT="${V12K_REFERENCE_INPUT:-}" \
 ZONE_AUDIT_DIR="${ZONE_AUDIT_DIR:-outputs/v11r2_core_periphery/audit_20261109T134751Z}" \
 bash "$script_dir/launch_V12K_Covariates_tmux.sh" --worker "$run"
tmux new-session -d -s "$session" "$command"
printf 'Session: %s\nOutput: %s\nSnapshot: %s\n' "$session" "$run" "$V12_SNAPSHOT"
printf 'Progress: tail -f "%s/launcher.log"\n' "$run"
