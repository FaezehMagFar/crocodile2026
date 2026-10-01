# Release manifest

Author: Faezeh Maghsoodifar

| Path | Purpose |
|---|---|
| `bundle/crocodash-era5.bundle` | complete portable Git history and ERA5 branch |
| `patches/0001-add-full-era5-atmospheric-forcing.patch` | reviewable extension patch |
| `scripts/install_bundle.sh` | isolated private installation |
| `scripts/probe_ncar.sh` | read-only NCAR compatibility probe |
| `scripts/prepare_era5_template.pbs` | reusable ERA5 preparation job |
| `scripts/prepare_era5_ike2008.pbs` | Hurricane Ike preparation example |
| `scripts/validate_install.sh` | installation validation |
| `scripts/validate_case.sh` | generated-case validation |
| `scripts/check_forcing.py` | ERA5 NetCDF time/field validation |
| `notebooks/ERA5_CrocoDash_NCAR_setup_runbook.ipynb` | detailed NCAR record |
| `notebooks/ike_era5_full_crocodash_template.ipynb` | reusable clean notebook |
| `examples/ike_era5_full_crocodash_executed.ipynb` | executed successful example |
| `docs/ERA5_FIELDS.md` | source and coupler field mapping |
| `docs/METHOD.md` | design and scientific method |
| `docs/NCAR_DERECHO.md` | shell/Jupyter workflow |
| `docs/TROUBLESHOOTING.md` | common problems and diagnostics |
| `docs/COLLABORATION.md` | upstream review and collaboration guide |
| `docs/PUBLISHING_AND_DOI.md` | GitHub release and DOI steps |
| `checksums/SHA256SUMS.txt` | release integrity hashes |

Large input and output datasets are deliberately absent.
