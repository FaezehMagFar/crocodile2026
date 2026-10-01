#!/usr/bin/env bash
# Author: Faezeh Maghsoodifar, The University of Alabama, 2026

set -euo pipefail

case_dir=${1:-$PWD}
era5_pattern=${2:-era5_atmos}

cd "$case_dir"
./preview_namelists
rundir=$(./xmlquery --value RUNDIR)
streams="$rundir/datm.streams.xml"

era5_count=$(grep -c "$era5_pattern" "$streams" || true)
jra_file_count=$(grep -c 'JRA.v1.5' "$streams" || true)

printf 'Case: %s\n' "$case_dir"
printf 'Stream file: %s\n' "$streams"
printf 'ERA5 datafile references: %s (expected 8 for full mode)\n' "$era5_count"
printf 'JRA datafile references: %s (expected 0 for full mode)\n' "$jra_file_count"

if [[ "$era5_count" -ne 8 || "$jra_file_count" -ne 0 ]]; then
  echo "FAIL: atmosphere stream validation did not match full ERA5 mode." >&2
  exit 1
fi

echo "PASS: all eight atmospheric streams use ERA5 datafiles."
