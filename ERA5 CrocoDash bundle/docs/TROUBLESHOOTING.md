# Troubleshooting

Author: Faezeh Maghsoodifar

## Bundle clone reports missing objects

Verify that the release bundle was transferred without truncation:

```bash
sha256sum bundle/crocodash-era5.bundle
git bundle verify bundle/crocodash-era5.bundle
```

Compare the hash with `checksums/SHA256SUMS.txt`.

## Python imports the original CrocoDash

```bash
python -c "import CrocoDash; print(CrocoDash.__file__)"
python -c "from CrocoDash.forcing.atm import ERA5AtmosphereConfigurator; print(ERA5AtmosphereConfigurator.name)"
```

The first path must point to the private ERA5 checkout and the second command
must print `ERA5Atmosphere`.

## ESMF mesh converter is missing

```bash
command -v ESMF_Scrip2Unstruct
find /path/to/conda-env -type f -name ESMF_Scrip2Unstruct -print
```

Activate the CrocoDash environment before submitting with `qsub -V`.

## The model still appears to use JRA

Stream names can retain `CORE_IAF_JRA`; inspect the datafile paths:

```bash
RUNDIR=$(./xmlquery --value RUNDIR)
grep -c "era5_atmos" "$RUNDIR/datm.streams.xml"
grep -c "JRA.v1.5" "$RUNDIR/datm.streams.xml"
```

Expected counts for full mode are eight and zero.

## `preview_namelists` reports duplicate parameters

```bash
grep -o '^[A-Z_0-9]* *=' user_nl_mom | tr -d ' =' | sort | uniq -d
```

Remove one copy of each duplicated MOM6 parameter.

## Run failure

```bash
RUNDIR=$(./xmlquery --value RUNDIR)
grep -n -i -B3 -A8 FATAL "$RUNDIR"/*.log.*
tail -n 30 CaseStatus
```

## Archive contains no custom SFINCS files

The tiled SFINCS files can remain in the run directory because short-term
archiving does not recognize processor-suffixed custom output. Use the joining
cell in the example notebook before scratch cleanup.
