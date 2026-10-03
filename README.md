# Hurricane Ike: ERA5–MOM6–SFINCS workflow

**Author:** Faezeh Maghsoodifar, The University of Alabama

This repository documents a Gulf of Mexico regional-ocean and coastal-flooding
workflow for Hurricane Ike (2008). It combines ERA5 atmospheric forcing,
CrocoDash/CESM regional MOM6, SFINCS for Galveston Bay, NOAA observations, and
Copernicus DUACS sea-level data.

## Animated result

The animation below was extracted from the project presentation so that it
plays directly on GitHub. The Copernicus product is daily, so the frame for
2008-09-13 represents the daily mean rather than Ike's exact landfall hour.

![Daily MOM6 and Copernicus DUACS sea-level comparison](ike-mom6-sfincs/figures/presentation_mom6_copernicus_animation.gif)

An additional MOM6 sea-surface-height animation is available
[here](ike-mom6-sfincs/figures/gom12_ike_ERA5full.001_ssh_ike.gif).

## Main project files

- [Project presentation](ike-mom6-sfincs/slides/Presentation.pptx) — download
  the PowerPoint to view all embedded slide media and animations.
- [Main ERA5–MOM6 notebook](ike-mom6-sfincs/notebooks/ike_era5_full_crocodash.ipynb)
- [MOM6 products for SFINCS notebook](ike-mom6-sfincs/notebooks/SFINCS_MOM6_ready_files.ipynb)
- [Complete SFINCS model archive](ike-mom6-sfincs/sfincs/archive/SFINCS_Model_Galveston_Ike_2008.zip)
  — 1.347 GiB, stored with Git LFS.
- [SFINCS archive notes and checksum](ike-mom6-sfincs/sfincs/archive/README.md)
- [Figures](ike-mom6-sfincs/figures) and
  [SFINCS evaluation products](ike-mom6-sfincs/sfincs/results)
- [Credits and citations](ike-mom6-sfincs/CREDITS_AND_CITATIONS.md), including
  special credit for AutoCF v1.0.0 HPC.

## Time-coordinate note

The MOM6 numeric time values follow the proleptic Gregorian calendar, although
the source metadata labels the calendar as `gregorian`. The notebooks change
only the calendar metadata before CF decoding. They do **not** numerically add
two days. This places the Hurricane Ike peak on 2008-09-13 as intended.

## Downloading the large SFINCS archive

Install Git LFS before cloning so the model ZIP is downloaded rather than only
its small pointer file:

```bash
git lfs install
git clone https://github.com/FaezehMagFar/crocodile2026.git
cd crocodile2026
git lfs pull
```

## Repository layout

- `ike-mom6-sfincs/` — curated notebooks, scripts, figures, presentation,
  SFINCS configuration/evaluation products, and the full model ZIP.
- `ERA5 CrocoDash bundle/` — the previously published ERA5 extension bundle.
- `install.sh` and `install.d/` — the original CROCODILE workspace installer.
- `docs/CROCODILE_WORKSPACE_TEMPLATE.md` — the original template guidance.

Large duplicate archives, software installers, recordings, temporary build
folders, the 7.3 GiB ERA5 working file, and unrelated workshop materials are
intentionally excluded.

## Attribution

AutoCF v1.0.0 HPC was used to build, run, and evaluate the packaged SFINCS
case. AutoCF itself is not redistributed here. All model, software, and data
providers retain their own authorship, licenses, and citation requirements.
See [Credits and citations](ike-mom6-sfincs/CREDITS_AND_CITATIONS.md) before
reusing the material.
