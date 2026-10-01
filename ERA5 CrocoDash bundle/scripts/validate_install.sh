#!/usr/bin/env bash
# Author: Faezeh Maghsoodifar, The University of Alabama, 2026

set -euo pipefail

python - <<'PY'
import inspect
from CrocoDash.forcing.atm import ERA5AtmosphereConfigurator
from CrocoDash.raw_data_access.datasets import era5_atmos

print("Configurator:", ERA5AtmosphereConfigurator.name)
print("Atmosphere code:", inspect.getfile(ERA5AtmosphereConfigurator))
print("Preprocessor:", inspect.getfile(era5_atmos))
assert ERA5AtmosphereConfigurator.name == "ERA5Atmosphere"
PY

command -v ESMF_Scrip2Unstruct
echo "PASS: ERA5 CrocoDash extension and ESMF converter are available."
