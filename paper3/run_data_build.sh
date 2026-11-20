#!/usr/bin/env bash
# Paper 3 data build (no model fitting). Run from the repo root on the server.
# SNAPSHOT_ID=<frozen snapshot folder> [SILK_GROUPS=file] bash paper3/run_data_build.sh
# Step 0 needs BADGER_DB_USER / BADGER_DB_PASSWORD (SELECT-only role).
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
: "${SNAPSHOT_ID:?set SNAPSHOT_ID to the frozen snapshot folder}"
for s in 00_extract_group_fields 01_assign_annual_groups \
         02_group_year_histories 03_territory_geometry 04_check_silk_moves; do
  out="outputs/paper3/$SNAPSHOT_ID"
  if [[ "$s" == 00_* && -e "$out/group_fields.rds" ]]; then continue; fi
  if [[ "$s" == 01_* && -e "$out/annual_resident_social_group_vicente.csv" ]]; then continue; fi
  echo "=== $s ==="
  Rscript "paper3/R/$s.R"
done
