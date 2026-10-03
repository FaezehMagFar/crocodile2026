# Three MOM6 experiments for the SFINCS ocean boundary (Hurricane Ike 2008, Galveston Bay)

**Question:** which MOM6 improvement changes the SFINCS ocean boundary, and the compound flood, the most:
ocean resolution, atmospheric forcing data, or coastal bathymetry data?

**Design:** change one thing at a time, so each difference has a single cause.

| Run | Ocean grid | Bathymetry | Atmosphere (wind + pressure) | Compared with | Isolates |
|---|---|---|---|---|---|
| **E0 base** (done) | 1/12° (~9 km) | GEBCO 2026 coarsened ×8 (~3.7 km), min depth 5 m | JRA55-do (~55 km, 3-hourly) | — | reference |
| **E1 resolution** | **1/24° (~4.5 km)** | GEBCO 2026 full (15″, ~450 m), min depth 5 m | JRA55-do | E0 | ocean grid resolution |
| **E2 forcing data** | 1/12° | same as E0 | **ERA5 (~31 km, hourly)** | E0 | atmospheric data |
| **E3 bathymetry data** | 1/24° | **NOAA coastal DEM (CRM/CUDEM) merged into GEBCO, min depth 2 m** | JRA55-do | E1 | nearshore bathymetry and shallow-shelf depth |

All runs: Ike window 2008-08-30 → 09-20, GLORYS OBC, TPXO9 8 constituents, same diag_table (`SSH_inst` 10 min + `taux`/`tauy`/`SSU`/`SSV` in the Texas box).

---

## E1: ocean resolution (1/12° → 1/24°)

**Why:** at 9 km the Texas coast is a coarse staircase. Gauges fall in land cells, and the shallow inner shelf, where wind setup grows as 1/depth, is poorly represented.

**Expect:** higher coastal peak, better tides near the coast, more MOM6 cells between the coast and the SFINCS boundary.

**Setup:**
- Copy `ike.ipynb` and set `RES = 1/24`, `CASENAME = "gom12_ike_r24.001"` (and a unique grid name).
- Use full-resolution GEBCO: `.../gebco_2026/GEBCO_2026.nc`, not `_coarse_x8`.
- Set `DT = 300`.
- Set `NTASKS_OCN` to about 512.

**Cost:** about 8× E0 (4× cells, 2× time steps), so roughly 15–60 min per run depending on cores. Fits the 2 h limit.

## E2: atmospheric forcing data (JRA55-do → ERA5)

**Why:** the missing forerunner and low peaks point to winds. ERA5 is finer (31 km) and hourly.

**Expect:** a stronger forerunner (11–12 Sep) and a higher peak. This is the largest expected change.

**Setup:**
- Keep JRA for the non-wind fields.
- Replace only the JRA **U_10, V_10 and SLP** streams with ERA5 (u10, v10, msl) for 2008, through `user_nl_datm_streams` (`<stream>:datafiles`, `<stream>:meshfile`).
- Needs ERA5 files for Aug–Sep 2008 over the Gulf. Check whether the ERA5 copy on GLADE (NCAR RDA) has them, or download from Copernicus. Also needs an ESMF mesh file for the ERA5 grid.
- **Ask the instructors first:** (1) the recommended custom-stream recipe; (2) whether DATM can run on a finer atmosphere grid than TL319 (~0.5°), which otherwise smooths ERA5.

**Variant E2b (optional, later):** a Holland parametric vortex from the HURDAT2 track, blended into JRA or ERA5. Tests whether resolving the storm core, rather than changing the dataset, is what matters.

**Cost:** about the same run time as E0. The work is in preparing the forcing files.

## E3: coastal bathymetry data (GEBCO → NOAA coastal DEM, min depth 2 m)

**Why:**
- GEBCO is poor on the shallow Texas–Louisiana inner shelf. The 5 m minimum depth removes the shallowest water.
- SFINCS already uses NOAA CUDEM. Using the same source in MOM6 makes the two models' seabed consistent at the SFINCS boundary.

**Expect:** stronger nearshore setup and a changed coastline mask. The change should concentrate near the coast. Compare against E1, the same grid.

**Setup:**
- On the E1 grid (1/24°), build the topography from NOAA's coastal DEM (Coastal Relief Model and/or CUDEM, NAVD88/MSL, which is small compared with depth at this scale), with GEBCO filling offshore.
- `MIN_DEPTH = 2.0`, with `DT = 300` or lower if unstable.
- `mom6_forge` `Topo.set_from_dataset` accepts any lon/lat/elevation NetCDF.

**Cost:** same as E1.

---

## How each run reaches SFINCS (the impact that matters)

For **every** run E0–E3:
1. **Notebook 02:** sample `SSH_inst` at the SFINCS boundary points (from AutoCF Run A's `sfincs.bnd`), then convert to NAVD88 → `bzs`.
2. `make_run_B.sh` → SFINCS Run B for that MOM6 variant. **Same SFINCS build, rain and rivers; only `bzs` differs.**
3. Score the boundary and the flood.

## Scorecard

| Level | Metric | Where |
|---|---|---|
| MOM6 at gauges | RMSE, bias, peak error, peak timing, forerunner (mean in the 24 h before landfall) | Galveston Pier 21, Bay Entrance, Sabine Pass (open coast) |
| MOM6 tides | M2/K1/O1 amplitude and phase vs NOAA harmonic constants | same gauges, calm period |
| **SFINCS boundary** | peak water level, time above 1 m, forerunner level, boundary spread between runs | SFINCS `bnd` points |
| **SFINCS inside bay** | RMSE and peak error | Eagle Point, Morgans Point, Manchester, RR Bridge (not used to force Run A) |
| **Compound flood** | max flooded area and volume, depth difference maps (run − E0), buildings/roads flooded | whole SFINCS domain |
| Attribution (optional) | coastal / rain / river contributions per boundary variant | AutoCF `attribute` (C/P/R factorial) |

**"Useful" means:** the change moves the SFINCS bay-gauge peak error and forerunner toward zero, and changes flood extent meaningfully (more than ~5% of flooded area), without degrading the tides.

## Order and cost

1. **E1** first: only notebook changes, and it tells you whether resolution alone helps.
2. **E3** next: same grid as E1, only a new topography.
3. **E2** when the ERA5 stream recipe is clear (instructor questions 1–2).
4. Then a combined **best** run (E3 grid and bathymetry + ERA5, or Holland winds) for the final SFINCS compound-flood runs.

## Unknowns to confirm

- The ERA5 path on GLADE for 2008, and the custom-stream recipe.
- Whether DATM can avoid TL319 smoothing.
- The coastal DEM source and coverage for the full TX–LA shelf (CRM volume / CUDEM tiles).
- Stability at 1/24° with 2 m minimum depth (DT, `BT_LIMIT_INTEGRAL_TRANSPORT`).
