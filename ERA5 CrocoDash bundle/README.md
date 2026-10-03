# ERA5 atmospheric forcing for CrocoDash and regional MOM6

**Author: Faezeh Maghsoodifar**  
The University of Alabama  
https://github.com/FaezehMagFar

This repository adds a complete ERA5 atmospheric-forcing pathway to
[CrocoDash](https://github.com/CROCODILE-CESM/CrocoDash) regional MOM6 cases.
It was developed and demonstrated on NCAR Derecho/Casper during the 2026
CROCODILE/MOM6 workshop.

The extension supplies all eight atmospheric streams used by the ocean
coupler:

| Prepared field | ERA5 source | Coupler purpose |
|---|---|---|
| `u10` | `10u` | eastward 10 m wind, `Sa_u` |
| `v10` | `10v` | northward 10 m wind, `Sa_v` |
| `msl` | `msl` | mean sea-level pressure, `Sa_pslv` |
| `t2m` | `2t` | near-surface air temperature, `Sa_tbot` |
| `q2m` | derived from `2d` and `msl` | specific humidity, `Sa_shum` |
| `precip` | `mtpr` | precipitation rate, `Faxa_prec` |
| `swdn` | `msdwswrf` | downward shortwave radiation, `Faxa_swdn` |
| `lwdn` | `msdwlwrf` | downward longwave radiation, `Faxa_lwdn` |

`DATM%JRA` remains the CDEPS interface because that interface exports the
bottom-atmosphere fields expected by CMEPS. In `full` mode, the eight data
streams themselves come from ERA5; JRA data are not used.

## What is included

- A complete, verified Git bundle based on CrocoDash v1.0.0.
- A human-readable patch for review or upstream collaboration.
- ERA5 preprocessing and installation scripts for NCAR systems.
- A reusable, output-free Hurricane Ike notebook template.
- An executed Hurricane Ike example documenting the successful 21-day run.
- A detailed NCAR setup/runbook.
- Validation, troubleshooting, citation, and DOI guidance.

ERA5 data, MOM6 outputs, credentials, and machine-generated build products are
not included. They are intentionally excluded by `.gitignore`.

## Repository layout

```text
bundle/       portable CrocoDash Git bundle
patches/      reviewable ERA5 extension patch
scripts/      installation, preparation, probe, and validation tools
notebooks/    reusable notebook template and NCAR runbook
examples/     executed Hurricane Ike notebook
docs/         method, fields, NCAR workflow, troubleshooting, and DOI guide
checksums/    release SHA-256 manifest
```

## Prerequisites

- An NCAR account with access to Derecho/Casper and an eligible project code.
- A CROCODILE/CrocoDash workspace and its recommended conda environment.
- Read access to NCAR RDA dataset `d633000` (ERA5).
- `ESMF_Scrip2Unstruct` in the activated environment.
- CESM/CDEPS/CMEPS/MOM6 versions compatible with the workshop CrocoDash v1.0.0
  baseline.

The workshop-only `tutorial` queue is not generally available. Select a queue
and project that are valid for your allocation.

## Quick start on NCAR

Set your workspace and project in a Derecho shell:

```bash
export CROCODILE_WORKSPACE=/glade/work/$USER/crocodile2026
export NCAR_PROJECT=YOUR_PROJECT_CODE
```

Run the read-only environment probe:

```bash
bash scripts/probe_ncar.sh | tee probe_ncar.out
```

Install the isolated ERA5-enabled checkout:

```bash
bash scripts/install_bundle.sh "$CROCODILE_WORKSPACE/CrocoDash-era5"
```

The installed branch is `feature/era5-atmosphere`. The script does not modify
the original CrocoDash checkout or NCAR shared software.

Prepare an ERA5 forcing file:

```bash
cp scripts/prepare_era5_template.pbs scripts/prepare_era5_my_event.pbs
# Edit #PBS -A, #PBS -q, ERA5_START, ERA5_END, and ERA5_EVENT_NAME.
qsub -V scripts/prepare_era5_my_event.pbs
```

Dates passed to preprocessing should bracket the MOM6 interval. The Hurricane
Ike example prepares 29 August–21 September for a 30 August–20 September model
run, providing one day of atmospheric data on each side.

Open `notebooks/ike_era5_full_crocodash_template.ipynb` on NCAR JupyterHub,
select the CrocoDash kernel, edit the settings cell, and run the forcing
coverage check before creating a case.

## Core CrocoDash call

```python
ERA5_FIELDS = {
    field: ERA5_FILE
    for field in (
        "precip", "lwdn", "swdn", "q2m",
        "msl", "t2m", "u10", "v10",
    )
}

case.configure_forcings(
    date_range=DATE_RANGE,
    boundaries=BOUNDARIES,
    product_name="GLORYS",
    function_name="get_glorys_data_from_rda",
    tpxo_elevation_filepath=TPXO_H,
    tpxo_velocity_filepath=TPXO_U,
    tidal_constituents=TIDAL_CONSTITUENTS,
    era5_atmosphere_files=ERA5_FIELDS,
    era5_mesh_filepath=ERA5_MESH,
    era5_atmosphere_mode="full",
)
```

## Confirm that all atmospheric streams use ERA5

From the CESM case directory after `./preview_namelists`:

```bash
RUNDIR=$(./xmlquery --value RUNDIR)
grep -c "era5_atmos" "$RUNDIR/datm.streams.xml"  # expected: 8
grep -c "JRA.v1.5" "$RUNDIR/datm.streams.xml"    # expected: 0
```

The stream names may still contain `CORE_IAF_JRA` because CDEPS uses the JRA
stream interface. The `datafiles` paths are the evidence identifying ERA5 as
the actual source.

## Reusing the bundle for other time windows

The Git bundle and ERA5 ESMF mesh are independent of time. Only the prepared
NetCDF forcing file and case dates are time-specific. For a new period:

1. prepare a new `era5_atmos_<event>.nc` covering the requested interval;
2. set the same interval in the notebook `DATE_RANGE`;
3. use new case, grid, forcing-directory, and forcing-file names; and
4. run the notebook's coverage check before case creation.

## Citation

Please cite this extension as described in `CITATION.cff` or `CITATION.bib`.
When a release DOI is minted, add it to both citation files. Also cite the
upstream CrocoDash software using DOI
[10.5281/zenodo.17342301](https://doi.org/10.5281/zenodo.17342301) and cite the
ERA5, GEBCO, GLORYS, and TPXO products used in the experiment.

## Authorship and acknowledgments

Faezeh Maghsoodifar is the author of this ERA5 atmospheric-forcing extension,
preprocessing workflow, NCAR runbook, and Hurricane Ike application. The work
builds on software developed by the CROCODILE-CESM, CrocoDash, CESM, CDEPS,
CMEPS, and MOM6 communities. See `AUTHORS.md` and `NOTICE`.

## License

The extension is distributed under the Apache License, Version 2.0, consistent
with upstream CrocoDash. See `LICENSE` and `NOTICE`. Input datasets retain
their original licenses and are not redistributed here.
