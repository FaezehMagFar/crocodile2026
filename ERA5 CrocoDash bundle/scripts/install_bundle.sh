#!/usr/bin/env bash
# Author: Faezeh Maghsoodifar, The University of Alabama, 2026
# Install the ERA5-enabled CrocoDash checkout without modifying shared code.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
bundle="$repo_root/bundle/crocodash-era5.bundle"
destination=${1:-"${CROCODILE_WORKSPACE:-/glade/work/$USER/crocodile2026}/CrocoDash-era5"}
python_exe=${PYTHON:-python}

if [[ ! -f "$bundle" ]]; then
  echo "Bundle not found: $bundle" >&2
  exit 1
fi

if [[ -e "$destination" ]]; then
  echo "Destination already exists; refusing to overwrite: $destination" >&2
  exit 1
fi

git bundle verify "$bundle"
git clone -b feature/era5-atmosphere "$bundle" "$destination"
git -C "$destination" submodule update --init --recursive
"$python_exe" -m pip install --no-deps -e "$destination"

echo "Installed checkout: $destination"
"$python_exe" -c 'from CrocoDash.forcing.atm import ERA5AtmosphereConfigurator; print(ERA5AtmosphereConfigurator.name)'
