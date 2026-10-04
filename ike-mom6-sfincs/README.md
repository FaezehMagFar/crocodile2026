# Hurricane Ike MOM6–SFINCS project

**Author:** Faezeh Maghsoodifar, The University of Alabama

This directory contains the curated research materials for the Hurricane Ike
(2008) ERA5–regional MOM6–SFINCS workflow.

## Results

### SFINCS flood inundation

![SFINCS Hurricane Ike flood-inundation animation](figures/sfincs_ike_flood_animation.gif)

This animation is generated from the hourly `sfincs_map.nc` output. It shows
`zs - zb` on model cells that were dry at the first output time and later had a
water depth of at least 0.05 m. Every third hourly frame is displayed, and the
exact 2008-09-13 07:00 UTC Ike landfall frame is included.

To reproduce it after extracting the SFINCS model archive:

```bash
python scripts/create_sfincs_flood_animation.py \
  /path/to/SFINCS_Model/galv_ike2008_/data/model/main/sfincs_map.nc \
  --output figures/sfincs_ike_flood_animation.gif
```

Required Python packages are `numpy`, `matplotlib`, `netCDF4`, and `Pillow`.

### MOM6 and Copernicus sea level

![MOM6 and Copernicus DUACS daily sea-level comparison](figures/presentation_mom6_copernicus_animation.gif)

The comparison uses daily Copernicus DUACS fields. The 2008-09-13 frame is the
landfall-day mean, not an observation at the exact landfall hour.

Key outputs:

- `slides/Presentation.pptx` — complete presentation with embedded media.
- `figures/` — static figures and GitHub-playable GIF animations.
- `sfincs/results/` — compact evaluation figures, tables, and provenance.
- `sfincs/archive/SFINCS_Model_Galveston_Ike_2008.zip` — complete SFINCS model
  package, stored with Git LFS.

## Reproduce the workflow

1. Follow `notebooks/ERA5_CrocoDash_NCAR_setup_runbook.ipynb` on NCAR systems.
2. Run `notebooks/ike_era5_full_crocodash.ipynb` to configure and analyze the
   regional MOM6 experiment.
3. Use `notebooks/SFINCS_MOM6_ready_files.ipynb` to prepare the regional MOM6
   products for the SFINCS workflow.
4. See `docs/HANDOFF_SFINCS_AutoCF.md` and `docs/AUTOCF_COMMANDS.md` for the
   recorded AutoCF/SFINCS build, run, and evaluation process.

The notebooks retain NCAR and UAHPC paths from the recorded runs. Adapt paths,
project codes, and environments before execution.

## Contents

- `notebooks/` — model setup, sensitivity experiments, analysis, and SFINCS
  preparation.
- `scripts/` — supporting validation and comparison utilities.
- `docs/` — experiment design, investigation notes, and execution records.
- `figures/` — publication and presentation graphics.
- `slides/` — the final PowerPoint presentation.
- `sfincs/` — lightweight configuration/evaluation records plus the LFS model
  archive.

## Attribution and reuse

AutoCF v1.0.0 HPC was used to build, run, and evaluate the SFINCS case. The
AutoCF software distribution is not included. See
`CREDITS_AND_CITATIONS.md` for the full software and data acknowledgments.
Third-party datasets and software retain their original licenses.
