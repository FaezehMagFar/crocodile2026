# Handoff: SFINCS setup with AutoCF on UAHPC (Galveston Bay)

**For a new chat:** read this file first, then the files it points to.
State as of 2026-09-29. **Update (later 2026-09-29):** AutoCF unpacked on UAHPC at `ROOT=/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0`; `doctor` PASS (needs `APPTAINER_TMPDIR/CACHEDIR=/twater/Faezeh/apptainer/{tmp,cache}`); `show-config` OK; home has no per-user quota. First Ike subgrid builds failed on the GeoJSON. From disassembling `app/sfincs_agent.pyc` (`extract_geojson_parts`, `select_boundary_noaa`): features carry a `role` property — `domain` (exactly 1 Polygon), `ocean_boundary` (≥1 LineString), `ocean_forcing_point` (≥1 Point; these become the SFINCS bnd points), optional `river_source`, `observation_point`, `roughness_override`. For `noaa_coops`, each forcing point takes the nearest NOAA station within `max_station_distance_km` whose missing fraction ≤ `max_missing_fraction`; the choice is written to `noaa_boundary_station_selection.csv`. `forcing.ocean_boundary.source` also accepts `file` (user `timeseries` CSV + `locations` GeoJSON), `constant`, `gtsm`, `selected_stations`, `catalog_stations`. **`file` is a cleaner way to feed MOM6 than swapping `sfincs.bzs`.** The GeoJSON now has 7 forcing points ~1 km inside the Gulf edge (8–19 m deep); pasted on UAHPC via heredoc. **Ike subgrid build PASSED** (`pavbnd = 0`, ASCII bnd/bzs, sbg written). AutoCF's gauge choice was bad: Pier 21 (points 1–4; channel gauge, 5 h gap at the peak), North Jetty 8771341 (point 5; record ends 2008-09-13 01:24), Rollover Pass 8770971 (points 6–7; 60 h gap from 09-13 06:00). Its "0% missing" is measured *after* interpolation. Galveston Pleasure Pier 8771510 (Gulf-facing, complete, peak 3.36 m NAVD88 at 09-13 05:30 UTC) is not in AutoCF's station list. Fix: `autocf_galveston/set_bzs_from_noaa.py` rewrites `sfincs.bzs` with 8771510 at all points (keeps `.autocf_original`). User plans to run on the A100 (`run_autocf_gpu_a100.slurm`). Scripts now take ROOT from the sbatch submit dir. User wants NOAA-boundary runs only for now (no MOM6).

## 1. Goal
Compare two SFINCS runs of Galveston Bay. They are identical except for the ocean boundary water level (`sfincs.bzs`):

| Run | Boundary water level | Run folder (under `$ROOT/runs/`) |
|---|---|---|
| A (baseline) | NOAA CO-OPS gauges (AutoCF `noaa_coops`) | `galv_<event>_noaa[_sg]` |
| B (nested) | Regional MOM6 `SSH_inst`, sampled at Run A's `sfincs.bnd` points | `galv_<event>_mom6[_sg]` |

- Events:
  - **Ike 2008** is the main case: landfall at Galveston 2008-09-13; SFINCS window 2008-09-08 → 09-16.
  - **Katrina 2005** is a far-field test: SFINCS window 2005-08-25 → 09-02.
- Model types: **regular** (200 m) and **subgrid** (200 m cells, 20×20 subgrid = 10 m). The suffix `_sg` marks subgrid.
- Evaluation: NOAA tide gauges only. No high-water marks or FEMA data.

## 2. Machine
UAHPC:
- Login node: `uahpc-login001`. User: `fmaghsoodifar`. Scheduler: Slurm. Partition: `twater`.
- `uahpc-gpu009`: 128 CPU cores, **AMD MI210** GPUs. Use AutoCF `--cpu` only; AutoCF's GPU solver is NVIDIA-only.
- `uahpc-gpu005`: **NVIDIA A100** (`--gres=gpu:a100-80:1`). AutoCF `--gpu` works here.
- Apptainer: `module load apptainer`.
- Project storage `/twater/Faezeh/` exists. Consider it if the `/home` quota is small.
- Source of these facts: the user's earlier job scripts in `GBMODEL/HPCfolder/HPC_uahpc-gpu009_Quadtree/slurm_jobs_script/` and `HPC_NODE.md`.

## 3. AutoCF (v1.0.0 HPC release)
- Local copy: `D:\MOM6\AutoCF-1.0.0-HPC\AutoCF-1.0.0-HPC\AutoCF_release_v1.0.0.tar.gz` (+ `.sha256`, checksum verified).
- HPC location given by the user: `/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/`.
- Assumed package root: `ROOT=/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0`.
- **Not yet verified.** The last attempt gave `-bash: ./autocf: No such file or directory`. Either `$ROOT` was unset in that shell, or the tarball isn't extracted there.
- The app ships as compiled Python (`.pyc`) plus Apptainer images (`autocf-python.sif`, `sfincs-cpu.sif`, `sfincs-runtime.sif`). Only the docs were read: `README.md`, `HPC_USAGE.md`, `PATH_AUDIT.md`, `examples/sfincs_agent_config.yml`.
- License: `REVIEW-NOTICE.txt` covers evaluation and review. Check before publishing results made with it.

**Commands:**

| Command | Needs internet? |
|---|---|
| `./autocf doctor` | no |
| `./autocf show-config CFG` | no |
| `./autocf build CFG` | yes, so run on the login node |
| `./autocf run-only RUN_ROOT --cpu\|--gpu` | no. Never rebuilds or downloads; runs `sfincs.inp` exactly as built |
| `./autocf evaluate RUN_ROOT` | yes, for uncached observations or basemap tiles. `--no-hydromt-basemap` skips the tiles |

- AutoCF allocates nothing and submits nothing: wrap commands in Slurm scripts.
- Relative paths in a YAML resolve from the YAML's own folder.
- Run layout: `<run-root>/data/model/main/` holds `sfincs.inp`, `sfincs.bnd`, `sfincs.bzs`, and so on. Results go to `<run-root>/results/evaluation/`.

## 4. Files prepared locally (`D:\MOM6\autocf_galveston\`)
All files use Unix line endings, the YAML parses, and the scripts pass `bash -n`.

| File | Upload to | Notes |
|---|---|---|
| `galveston_ike2008.yml` / `galveston_katrina2005.yml` | `$ROOT/projects/` | Regular 200 m |
| `galveston_ike2008_subgrid.yml` / `galveston_katrina2005_subgrid.yml` | `$ROOT/projects/` | `model.mode: subgrid`, CUDEM at 10 m |
| `region_bbox.geojson` | `$ROOT/data/galveston/` | 95.46–94.44 °W, 28.96–29.96 °N (same polygon as GBMODEL `Data/raw/region_bbox.geojson`) + an `ocean_boundary` LineString (AutoCF requires one). Line runs along the Gulf edges: S edge from 95.25 °W, SE diagonal, E edge up to 29.50 °N; all 7–19 m deep in the GB Beryl bathymetry |
| `run_autocf_cpu.slurm` | `$ROOT/` | `sbatch run_autocf_cpu.slurm <run-name>`: gpu009, 64 OpenMP threads, `--cpu` |
| `run_autocf_gpu_a100.slurm` | `$ROOT/` | gpu005 A100, `--gpu` |
| `make_run_B.sh` | `$ROOT/` | `bash make_run_B.sh <mom6.bzs> <runA> <runB>`: rsync-copies Run A (outputs excluded), swaps `sfincs.bzs` (keeps `.noaa_original`), checks column count against `sfincs.bnd`, refuses NetCDF boundaries |
| `README_HPC_STEPS.md` | anywhere | Full command sequence |

**Config choices (all YAMLs), based on `examples/sfincs_agent_config.yml`:**
- `target_vertical_datum: NAVD88`. Ocean boundary `noaa_coops`, `datum: NAVD`. `noaa_boundary.datum` and `noaa_validation.datum` changed from the example's MSL to **NAVD**.
- Rain, wind, pressure: AORC. Rivers: `usgs_auto`. Land cover: ESA WorldCover. Infiltration: CN/GCN250.
- Terrain: CUDEM 1/9″ primary (VRT 8483), GEBCO 2024 gap-fill.
- `impact.enabled: false`, `analysis.enabled: false`. AutoCF's WorldPop data covers only 2015–2030, so 2005 and 2008 would stop with an error.
- `boundary_point_spacing_m: 5000`. Run B must use exactly these bnd points.

## 5. Next steps (in order)
1. On UAHPC:
   - `ls /home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/`
   - `find /home/fmaghsoodifar/SFINCS-MOM6 -maxdepth 4 -name autocf -type f`
   - If only the tarball is there: `sha256sum -c`, `tar -xzf`, `chmod +x autocf`.
   - Set `ROOT`, and fix the `ROOT=` line in the 3 scripts if the path differs.
2. `module load apptainer && ./autocf doctor`. It must pass.
3. Upload the files from §4. `mkdir -p $ROOT/projects $ROOT/data/galveston` first.
4. Run `./autocf show-config projects/galveston_ike2008_subgrid.yml`. Check that the output folder and GeoJSON paths resolve.
5. Run `./autocf build ...` on the login node.
   - A subgrid build may need more memory. If the login node kills it, try `srun -p twater --mem=64G --pty bash`, provided compute nodes have internet.
6. After the build, check:
   - `grep -Ei "bndfile|bzsfile|netbnd|tref|sbgfile|subgrid" runs/<run>/data/model/main/sfincs.inp`
   - Which NOAA stations fed the boundary (`data/validation/water_level/`, `logs/build/`).
7. Submit Run A with `sbatch run_autocf_cpu.slurm galv_ike2008_noaa_sg`, then `./autocf evaluate runs/galv_ike2008_noaa_sg`.
8. Run B, after the MOM6 run (§7): `make_run_B.sh`, then `sbatch`, then `evaluate`. Compare `noaa_station_comparison.csv` between A and B.

## 6. Rules for a fair comparison
- **Same everything except the bzs.** Run B is a copy of the built Run A; never rebuild it.
- **Datum:** Run B's bzs must be m NAVD88 with time in seconds since Run A's `tref`. Conversion from MOM6:
  `bzs = [η(t) − η̄(W)] + mean observed NOAA level over W (NAVD88)`
  - W is a calm window before the storm.
  - η̄(W) is MOM6's mean over the same window.
  - η is MOM6 `SSH` or `SSH_inst`, **never `zos`**: `zos` adds p_atm/ρg and removes the domain mean.
  - **Time axis:** MOM6 files say `days since 0001-01-01`, calendar `gregorian`, but count in proleptic Gregorian. Plain `xr.open_dataset` therefore puts every 2008 time **2 days early** (checked on `SFINCS_OCB_Input/gom12_ike_ERA5full.001.mom6.sfincs_TX.nc`: 08-28→09-18 instead of 08-30→09-20; Ike peak looks like 09-11 instead of 09-13 ~10 UTC). Always open with `decode_times=False`, set `time.attrs["calendar"]="proleptic_gregorian"`, then `xr.decode_cf` (as `open_mom6` in `ike.ipynb` / `SFINCS_MOM6_ready_files.ipynb`). The `first_time`/`last_time` in that folder's `manifest.json` were written before the fix and are 2 days early.
- **Pressure effect:** MOM6 η already includes the inverse barometer, so keep `pavbnd = 0`. Check that AutoCF's `sfincs.inp` doesn't set `pavbnd > 0` for Run B.
- **Scoring:** leave out the NOAA stations AutoCF used to force Run A's boundary. They match Run A almost by construction. Score at bay-interior gauges instead: Eagle Point, Morgans Point, Manchester, Galveston Railroad Bridge.
- **Gauge IDs** (from memory, unverified): Pier 21 8771450, Bay Entrance N Jetty 8771341, Eagle Point 8771013, Morgans Point 8770613, Manchester 8770777, RR Bridge 8771486, San Luis Pass 8771972, Rollover Pass 8770971.

## 7. MOM6 side (context only; handled in the other chat)
- NCAR Derecho/Casper, user `faezehmaghso`, workspace `/glade/work/faezehmaghso/crocodile2026`.
- Build notebook: `D:\MOM6\notebooks\01_build_gulf_mom6.ipynb`.
  - Whole Gulf of Mexico, 1/12°, compset `CR_JRA`, GLORYS + TPXO (8 constituents).
  - Set `EVENT = "ike"` or `"katrina"`; each event gets its own case (`gom12_<event>.001`).
- Output for SFINCS: `SSH_inst` every 10 min in a Texas box (262.5–267.0 E, 27.5–30.0 N), file `<case>.mom6.sfincs_TX`.
- **Status:** the Katrina case is blocked at `./preview_namelists`. `user_nl_mom` contains a duplicated parameter (MOM_interface "listed more than once"; its error message crashes with `TypeError ... PosixPath`). It's being diagnosed there.
- **Not written yet:** `02_mom6_to_sfincs_bzs.ipynb`. It will read Run A's `sfincs.bnd` and `tref`, sample `SSH_inst`, convert to NAVD88, and write the bzs that `make_run_B.sh` expects.

## 8. Unknowns to check early
- Whether AutoCF can build in MSL. It's compiled, so this is unknown; staying NAVD88 for now.
- Whether AutoCF writes an ASCII `sfincs.bzs` or a NetCDF boundary. `make_run_B.sh` handles only ASCII.
- Home quota versus the size of the 10 m subgrid terrain, and whether compute nodes have internet.
- Whether AutoCF's evaluation reports in NAVD88 given `noaa_validation.datum: NAVD`.

## 9. Related material
- `D:\MOM6\INVESTIGATION_REPORT.md`: the full investigation. §3 datum, §E SFINCS format and HydroMT, §8 workflow.
- Existing SFINCS model (Beryl 2024, 200 m regular/subgrid/quadtree, EPSG:32615): `D:\Users\fmaghsoodifar\OneDrive - The University of Alabama\Research\Models\SFINCS\GBMODEL\`. Its known issues:
  - The 3 bnd points sit at the inlets, not on the offshore boundary.
  - GEBCO is merged with no datum offset.
  - `zsini = 0` in NAVD88.
- Slides: `D:\MOM6\slides\MOM6_SFINCS_Galveston.pptx`.
