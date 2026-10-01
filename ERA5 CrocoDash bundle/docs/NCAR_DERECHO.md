# NCAR Derecho/Casper workflow

Author: Faezeh Maghsoodifar

## Shell versus notebook

- Run Git, PBS, build, and submission commands in a Derecho shell.
- Run CrocoDash Python cells on NCAR JupyterHub using the CrocoDash kernel.
- Activating a Jupyter kernel does not activate the same environment in a
  separate shell. Use `qsub -V` to export the active shell environment.

## Environment

```bash
export CROCODILE_WORKSPACE=/glade/work/$USER/crocodile2026
export NCAR_PROJECT=YOUR_PROJECT_CODE
module load conda
conda activate /path/to/your/CrocoDash/environment
which python
which ESMF_Scrip2Unstruct
```

## Install

```bash
bash scripts/probe_ncar.sh | tee probe_ncar.out
bash scripts/install_bundle.sh "$CROCODILE_WORKSPACE/CrocoDash-era5"
bash scripts/validate_install.sh
```

## Prepare forcing

```bash
cp scripts/prepare_era5_template.pbs scripts/prepare_era5_my_event.pbs
# Edit the PBS account, queue, event name, and dates.
qsub -V scripts/prepare_era5_my_event.pbs
qstat -u "$USER"
```

## Build and run

After the notebook creates the case:

```bash
cd "$CROCODILE_WORKSPACE/croc_cases/YOUR_CASE"
./case.setup --reset
./preview_namelists
bash /path/to/this/repository/scripts/validate_case.sh "$PWD" era5_atmos
qcmd -A "$NCAR_PROJECT" -- ./case.build
./case.submit
qstat -u "$USER"
tail -n 20 CaseStatus
```

The `tutorial` queue is a workshop reservation. Outside an active workshop,
use the queue authorized for your project.
