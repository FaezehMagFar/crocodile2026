#!/usr/bin/env bash
# Author: Faezeh Maghsoodifar, The University of Alabama, 2026
# Read-only compatibility probe for an NCAR CrocoDash/CESM workspace.

set -u

workspace=${CROCODILE_WORKSPACE:-/glade/work/$USER/crocodile2026}
cesmroot=${CESMROOT:-$workspace/CESM}
rda=${ERA5_RDA_ROOT:-/glade/campaign/collections/rda/data/d633000}
months=${ERA5_MONTHS:-"200808 200809"}

printf 'AUTHOR: Faezeh Maghsoodifar\n'
printf 'HOST: %s\n' "$(hostname)"
printf 'DATE_UTC: %s\n' "$(date -u +%FT%TZ)"
printf 'WORKSPACE: %s\n' "$workspace"
printf 'PYTHON: %s\n' "$(command -v python || true)"
python --version 2>&1 || true
python -c 'import CrocoDash, xarray, dask, netCDF4; print("CrocoDash:", CrocoDash.__file__); print("xarray:", xarray.__version__); print("dask:", dask.__version__); print("netCDF4:", netCDF4.__version__)' 2>&1 || true

printf 'CESMROOT_EXISTS: %s\n' "$(test -d "$cesmroot" && printf yes || printf no)"
git -C "$cesmroot" rev-parse HEAD 2>&1 || true
git -C "$cesmroot/components/cdeps" rev-parse HEAD 2>&1 || true

printf 'ESMF_Scrip2Unstruct: %s\n' "$(command -v ESMF_Scrip2Unstruct || true)"

for month in $months; do
  printf 'RDA_MONTH: %s\n' "$month"
  while read -r collection parameter; do
    count=$(find "$rda/$collection/$month" -maxdepth 1 -type f -name "*$parameter*.nc" 2>/dev/null | wc -l)
    printf '  %-30s %-22s %s\n' "$collection" "$parameter" "$count"
  done <<'EOF'
e5.oper.an.sfc 128_165_10u
e5.oper.an.sfc 128_166_10v
e5.oper.an.sfc 128_167_2t
e5.oper.an.sfc 128_168_2d
e5.oper.an.sfc 128_151_msl
e5.oper.fc.sfc.meanflux 235_035_msdwswrf
e5.oper.fc.sfc.meanflux 235_036_msdwlwrf
e5.oper.fc.sfc.meanflux 235_055_mtpr
EOF
done

stream_file="$cesmroot/components/cdeps/datm/cime_config/stream_definition_datm.xml"
printf 'JRA_STREAM_DEFINITION: %s\n' "$(test -f "$stream_file" && printf yes || printf no)"
grep -n 'CORE_IAF_JRA\.\(PREC\|LWDN\|SWDN\|Q_10\|SLP_\|T_10\|U_10\|V_10\)' "$stream_file" 2>&1 || true
