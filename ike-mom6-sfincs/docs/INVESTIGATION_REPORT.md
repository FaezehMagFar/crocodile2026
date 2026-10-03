# Regional MOM6 (CrocoDash) as parent model for SFINCS — Galveston Bay

**Status:** brainstorming / read-only investigation. Nothing was run. No repo or SFINCS file was modified.
**Date:** 2026-09-29.
**Target (changed mid-investigation):** Galveston Bay, TX. Pilot event is Hurricane Beryl (July 2024). The prompt's original target was Mobile Bay/Pensacola.

Labels: **CONFIRMED** = seen in code. **DOCUMENTED** = docs, notebooks, or upstream only. **UNKNOWN** = not verifiable here.
Paths are relative to `D:\MOM6\ref\` unless noted.

### Sources read (commit / tag)

| Repo | Version |
|---|---|
| CrocoDash | `4d50375` (2026-09-25, "Version 1 release"); `rm6` submodule pinned to regional-mom6 `3ca8b9b` |
| regional-mom6 | `3ca8b9b` |
| CrocoGallery | `ff0f068` (includes `workshop_2026/`, `dart/`, `advanced/`) |
| mom6_forge | `94088b4` |
| MOM6 (CROCODILE fork) | `7d352a0` |
| MOM_interface | `89f74c0` = `mi_260715`, the tag pinned by CROCODILE-CESM/CESM `.gitmodules` |
| CDEPS | CROCODILE default branch `6488074`. Pinned tag `cdeps1.0.101` stream files saved to `_pinned_cdeps1.0.101/` |
| CMEPS | CROCODILE default branch `0130cb2`. CESM pins `cmeps1.1.54`, which was not diffed |
| DART_interface, dartobsgen, SeaSloth, CROCODILEworkspace | latest `main` |

No separate workshop material exists yet. The workshop page (`CrocoGallery/workshop_2026/index.md`) points to CrocoGallery tutorials and a live Google Doc agenda, which I did not read.

---

## 0. First: your SFINCS folder

- `GBMODEL` is a **Galveston Bay / Hurricane Beryl 2024** model: `epsg = 32615`, `tref = 20240625`, gauges named for Galveston (`Models/GB_Beryl2024_TX/sfincs.inp`, `sfincs.obs`). The work now targets Galveston, so this fits.
- Three variants: regular 200 m, subgrid, quadtree. All three share the same `sfincs.bnd` and `sfincs.bzs`.

---

## 1. Feasibility table

| # | Question | Answer | Evidence |
|---|---|---|---|
| A1 | Atmospheric datasets | **PARTIAL.** DATM modes: JRA55-do (`CORE_IAF_JRA*`, `CORE_RYF*`), CORE2, **ERA5** (`ERA5_HOURLY`), CPLHIST (CESM coupler history). Regional compset aliases are all `DATM%JRA` (CR_JRA, GR_JRA…). **Stock coverage ends 2023** (JRA v1.5 `last_year="2023"`). The stock ERA5 stream lists **2019 files only**. So Beryl 2024 has **no stock forcing**. | CONFIRMED: `_pinned_cdeps1.0.101/datm.xml` (JRA SLP 2767–2770; ERA5 3682–3698). `CDEPS/datm/cime_config/namelist_definition_datm.xml:59–95`. Aliases: `CrocoDash/docs/source/for_users/compsets_and_inputs.md`. |
| A2 | SLP → MOM6 (inverse barometer) | **YES.** Full chain: DATM exports `Sa_pslv` (JRA `slp`, ERA5 `msl`) → CMEPS maps atm→ocn → MOM cap imports it into `IOB%p` → `forces%p_surf` → used in dynamics. `MAX_P_SURF` default −1 (no cap). | CONFIRMED: `CMEPS/mediator/esmFldsExchange_cesm_mod.F90:2147–2155`; `MOM6/config_src/drivers/nuopc_cap/mom_cap.F90:865`, `mom_cap_methods.F90:114`; `mom_surface_forcing_nuopc.F90:837–846, 1249–1256`; `MOM6/src/core/MOM_dynamics_split_RK2.F90:463`. CMEPS was read at default branch, not the pinned tag. |
| A3 | Temporal resolution | **PARTIAL.** Streams are time-interpolated (`tintalgo=linear`), so any file frequency works. JRA55-do is 3-hourly; ERA5 stream is hourly. The ocean coupling interval (`OCN_NCPL`) was not found in CrocoDash. | CONFIRMED: `datm.xml` JRA `tintalgo linear` (~2785). `ERA5_HOURLY` name. 3-hourly JRA is DOCUMENTED (JRA55-do). Coupling interval: UNKNOWN. |
| A4 | Custom forcing (Holland TC, own ERA5) | **PARTIAL.** `user_nl_datm_streams` accepts `stream:datafiles`, `datavars`, `meshfile`, `tintalgo`, `year_first/last/align`. CrocoDash already writes this file for year alignment. Needed: NetCDF + an **ESMF mesh file** for the grid + variable names mapped to `Sa_u10m/Sa_pslv/…` (ERA5 mode) or JRA stream names. **Caveat:** DATM regrids streams onto the atm model grid (default `TL319`, about 0.5°). That smooths a TC vortex unless the atm grid can be finer. | CONFIRMED: `CDEPS/cime_config/stream_cdeps.py:45–56, 120–160`; `CrocoDash/CrocoDash/forcing/atm.py:130–148`; `case.py:72` (`atm_grid_name="TL319"`). Finer atm grid: UNKNOWN. |
| B5 | Tidal constituents / OBC | **YES.** TPXO constituents M2, S2, N2, K2, K1, O1, P1, Q1, MM, MF. They are **mapped by array position**, which assumes TPXO9-v1 ordering. They are written as `SSHamp/SSHphase/Uamp…` in `OBC_SEGMENT_nnn_DATA`. OBC = `FLATHER,ORLANSKI,NUDGED,ORLANSKI_TAN,NUDGED_TAN`. **Gap:** body-force tides turn on **only `TIDE_M2`**. Galveston is diurnal-dominated, so add `TIDE_K1`, `TIDE_O1`, … by hand. | CONFIRMED: `regional-mom6/regional_mom6/regional_mom6.py:66–97`; `CrocoDash/CrocoDash/forcing/tides.py:85–105`; `forcing/mom6.py:641–671`. Gallery uses `h_tpxo9.v1.nc` (`CrocoGallery/crocodash/configure_forcings.ipynb`). |
| B6 | OBC datasets; CESM/MESACLIP | **PARTIAL.** Products: `glorys`, `cesm_pop_output` (CESM-HR FOSI, LENS2), `cesm_mom_output` (nesting), `reference_ocean` (synthetic). GLORYS is **daily** (`P1D`). The API method **hardcodes the multiyear dataset `cmems_mod_glo_phy_my_0.083deg_P1D-m`**, which (per Copernicus) does not cover 2024. That is a Beryl gap. POP cm→m conversion is done by pint via the `units` attribute. MESACLIP (POP 0.1°) should fit `cesm_pop_output` through `dataset_path`. Not tested. | CONFIRMED: `raw_data_access/datasets/glorys.py:115–140`, `cesm_ocean_output.py:30–156`; `regional-mom6/regional_mom6/regridding.py:35–45`. RDA `d010049` year coverage: UNKNOWN. MESACLIP fit: UNKNOWN. |
| B7 | Interior/custom OBC (PR #269) | **PARTIAL / not merged.** PR #269 is **open** on branch `interior-obc-new`. `Segment.from_hgrid` / `from_lonlat` / `detect_open_cardinal_boundaries` exist in rm6 `main`. CrocoDash `main` still accepts only cardinal strings and raises `ValueError` otherwise. | CONFIRMED: GitHub API (PR state open); `regional-mom6/regional_mom6/segment.py:199, 627, 654`; `CrocoDash/CrocoDash/forcing/mom6.py:628–637`. Notebook: `CrocoGallery/crocodash/advanced/interior_obc_segments.ipynb` (marked experimental). |
| C8 | diag_table; hourly SSH | **YES (manual).** CrocoDash does not touch `diag_table`. Default regional output = daily-mean `zos`, monthly `SSH`. Override with `SourceMods/src.mom/diag_table`. `SSH_inst` is posted every dynamics step, so hourly or 10-min instantaneous output is possible. | CONFIRMED: `MOM_interface/cime_config/buildnml:181–195`; `param_templates/diag_table.yaml:25–27, 216–247`; `MOM6/src/core/MOM.F90:1058–1060, 3981`. `hours`/`minutes` units: DOCUMENTED (FMS diag_table). |
| C9 | Output for a sub-region | **YES (box).** FMS `regional_section` "lon0 lon1 lat0 lat1 -1 -1" per file block. There is no point or station output. Use small boxes or a thin strip along the SFINCS boundary. | CONFIRMED: `MOM_interface/param_templates/diag_table.yaml:322`; `cime_config/MOM_RPS/FType_diag_table.py:197–200`. |
| C10 | Meaning of SSH | **CONFIRMED, see §3.** `SSH` = time-mean η, **no** pressure correction. `zos` = η + p_atm/(ρg) **minus the domain area mean**, so do **not** use `zos` for SFINCS. | `MOM6/src/diagnostics/MOM_diagnostics.F90:1599–1611, 1655–1683`; `MOM6/src/core/MOM.F90:1097–1110, 4095–4131`. |
| D11 | Grid options / resolution | **YES.** `uniform_spherical`, `rectilinear_cartesian`, `from_projection` (any CRS, metres), `from_center` (rotated, e.g. perpendicular to the coast), `from_supergrid`, `from_esmf_mesh`, `subgrid_from_supergrid`. Gallery nests 1/12° → 1/48° → 1/192°. | CONFIRMED: `mom6_forge/mom6_forge/grid.py:69–159, 533–745`; `CrocoGallery/crocodash/advanced/nesting_demo.ipynb`. Practical limit: UNKNOWN (question). |
| D12 | Min depth / masking / W&D | **PARTIAL.** `Topo(min_depth=…)` masks ≤ min_depth as land and deepens wet cells to min_depth+0.1. MOM6 has `MINIMUM_DEPTH`/`MASKING_DEPTH`. I found **no dedicated wetting-drying switch**. The barotropic solver treats "dry" points, and `BT_LIMIT_INTEGRAL_TRANSPORT` defaults to false. W&D is **not on by default**. | CONFIRMED: `mom6_forge/mom6_forge/topo.py:128–167, 349–367`; `MOM6/src/initialization/MOM_shared_initialization.F90:250–256`; `MOM6/src/core/MOM_barotropic.F90:3923, 5639–5642`. |
| D13 | Rivers | **PARTIAL.** `DROF%GLOFAS` = GLOFAS v4 daily, 1979–2024, mapped rof→ocn with smoothing (`rmax`, `fold`). Swapping in Trinity/San Jacinto gauges would mean replacing stream files through `user_nl_drof_streams`. Not tested. | CONFIRMED: `_pinned_cdeps1.0.101/drof.xml:673–700`; `CrocoDash/CrocoDash/forcing/runoff.py`. Gauge swap: UNKNOWN. |
| E14 | Your SFINCS setup | See §E below. | CONFIRMED from your files. |
| E15 | bnd/bzs format + HydroMT | **YES.** See §E. | CONFIRMED (your files and notebooks). HydroMT API: DOCUMENTED. |
| E16 | Where to put the SFINCS boundary | Recommendation in §E. | Reasoning, not code. |
| F17 | Cost | **PARTIAL.** Scaled from SeaSloth's measured Derecho run. See §F. | CONFIRMED base numbers: `SeaSloth/results/mom6_scaling.json`, `docs/mom6_scaling_setup.md`. |
| + | DART data assimilation | **PARTIAL.** `CR_JRA_DA` compset, `ninst` ensemble, 24 h cycles. The tutorial assimilates **Argo T/S** only. DART defines `SEA_SURFACE_HEIGHT` obs, but whether the MOM6 `model_mod` can update SSH/η is unknown. | DOCUMENTED: `CrocoGallery/dart/tutorial3_cycling_dart_cesm.ipynb`. CONFIRMED: `DART_interface/cime_config/dart_cesm_components.py:11–17`. Upstream NCAR/DART `obs_def_ocean_mod.f90:11,60`. SSH in state: UNKNOWN. |

---

## 2. Gaps and blockers (most severe first)

1. **No stock 2024 atmospheric forcing.** JRA ends 2023. ERA5 stream is 2019 only. Beryl needs custom DATM streams. Also, CrocoDash's `StreamYearConfigurator` silently skips years outside coverage (`forcing/atm.py:105–112`, warning only), so you must write `user_nl_datm_streams` yourself.
2. **GLORYS 2024 not reachable through CrocoDash's API method.** The dataset ID is hardcoded to the multiyear product (`glorys.py:130`). The interim product ("myint") would need a new access method. RDA coverage is unknown.
3. **Atm resolution.** DATM remaps to the atm grid (TL319 ≈ 55 km). ERA5 (31 km) and any Holland field get smoothed. That loses peak winds near the eye. How to run DATM on a finer mesh is unknown.
4. **Datum mismatch.** MOM6 η has no geodetic datum (§3). Your SFINCS is NAVD88 on land and GEBCO MSL offshore, merged with no offset (`hydromt_data.yml`; notebook cell 57 note).
5. **Nesting demo uses `zos` for child OBCs** (`nesting_demo.ipynb`, `cesm_ocean_output.py:182`). `zos` removes the domain mean and adds the IB term, so it is the wrong variable for surge. Use `SSH`.
6. **Body tides are M2 only** (`tides.py:86`). Diurnal constituents dominate at Galveston.
7. **OBC is daily GLORYS with no surge and no IB.** Barotropic surge generated outside the domain is missing. A small domain loses the shelf-wide wind setup. This argues for a large parent domain (§4).
8. **PR #269 is unmerged.** A tight Gulf box with cuts at Yucatán and the Florida Straits needs that branch. A plain rectangle works on `main`.
9. **Wetting/drying:** no explicit scheme. Keep MOM6 away from intertidal cells. SFINCS does inundation.
10. **TPXO index mapping is positional** (TPXO9-v1). A TPXO10 file could silently pick the wrong constituents.

---

## 3. Datum and SSH-reference plan (MOM6 → NAVD88)

**What MOM6 SSH is (CONFIRMED):**
- `SSH` (and `SSH_inst`) = free-surface η relative to the model's resting z=0 (`find_eta(..., dZref=G%Z_ref)`, `MOM.F90:1054`).
- Atmospheric pressure drives the dynamics (§A2). So η **already contains the dynamic IB response**. Do not add IB again.
- `zos` = η + p_atm/(ρg) − domain mean (`MOM_diagnostics.F90:1678–1683`). Not usable for SFINCS.
- The initial η comes from GLORYS `zos` (`SURFACE_HEIGHT_IC_FILE=init_eta_filled.nc`, `DEPRESS_INITIAL_SURFACE=True`; `forcing/mom6.py:594, 603, 607`). The OBC η comes from GLORYS `zos` plus TPXO. So the mean level ≈ GLORYS's reference (geoid-like, per Copernicus docs), plus model drift. **It is not NAVD88.**
- Steric: MOM6 in CESM is Boussinesq (I did not check the flag). Domain-mean thermosteric rise is not produced internally. It enters only through the OBC SSH. UNKNOWN; ask.

**Plan:**
1. Output `SSH_inst` (or hourly-mean `SSH`) at each new SFINCS boundary point.
2. Build `bzs = (η − η̄_calm) + MSL_NAVD88(t0)`. Here:
   - η̄_calm = model mean over a non-storm window, e.g. 2024-06-01 to 06-25.
   - MSL_NAVD88(t0) = observed mean water level relative to NAVD88 at the nearest CO-OPS gauge over the same window. Use recent observations, not the 1983–2001 epoch value, because Galveston subsidence and SLR are large.
3. Linearly interpolate that offset alongshore between gauges (Pier 21, Galveston Bay Entrance North Jetty, San Luis Pass, Rollover Pass). HydroMT's `offset` argument can apply a spatially varying offset (DOCUMENTED).
4. Keep `pavbnd = 0` in `sfincs.inp`. Your current value is already 0. The boundary IB is then carried by MOM6 η. Keep `baro = 1` so pressure acts inside SFINCS. If you ever run MOM6 **without** SLP, set `pavbnd > 0` instead (DOCUMENTED, SFINCS manual).
5. Validate the offset on tides only first (§4, Step 1). A constant bias at all gauges means an offset error. A phase or amplitude error means a model problem.

---

## 4. Minimal pilot plan: Hurricane Beryl, Galveston Bay

**Domain question: do you need the whole Gulf?** Not strictly. But Beryl's setup builds on the wide Texas–Louisiana shelf, and GLORYS OBCs carry no surge. So the domain must hold the whole shelf the storm crossed, with OBCs in deep water. Two options:

| Option | Extent | Pros | Cons |
|---|---|---|---|
| A. Texas–Louisiana shelf | about −97.8 to −91.5 E, 26.0 to 30.3 N (open S and E edges) | cheap; `main` branch, cardinal edges | open boundaries cut the shelf on the east; remote setup is lost |
| B. **Whole Gulf of Mexico** | about −98 to −80.5 E, 18 to 31 N | OBCs at Yucatán and Florida Straits, far from Galveston; captures all shelf setup and the Loop Current | more cells, deep water (smaller barotropic step); clean straits cuts need PR #269, or use a box with open S/E edges |

**Recommendation:** B at 1/12° as the parent. Optionally nest a 1/48° Texas-shelf child using the nesting pattern (parent `SSH` output as child OBC, not `zos`). Option A at 1/25°–1/50° is the budget alternative.

**Steps:**
- **Step 1: plumbing test on stock inputs (no custom data).** A calm 2023 month, JRA + GLORYS(RDA) + TPXO9 (10 constituents, add `TIDE_K1/O1/...`). Goals: tidal amplitude and phase at the gauges; datum offset; `SSH_inst` export to `bzs`.
- **Step 2: Beryl.**
  - Run 2024-06-15 → 2024-07-15. That is 10 days of spin-up before SFINCS `tstart = 2024-06-25`. Landfall was about 2024-07-08, near Matagorda.
  - Atmosphere: custom ERA5 hourly (u10, v10, msl, plus the fields the DATM mode needs) through `user_nl_datm_streams`. You already have TX subsets of u10/v10/msl/tp (`GBMODEL/Data/raw/era5_hourly_TX_Beryl2024_*.nc`), but option B needs a Gulf-wide extent. Later: blend a Holland vortex into the same stream.
  - Ocean: GLORYS interim, daily (needs a new access method or RDA), plus TPXO.
  - Rivers: GLOFAS in MOM6 (salinity only). Rivers for flooding stay in SFINCS (your 9 `src` points).
  - Topography: GEBCO; `min_depth` about 2–5 m (to decide). Keep Galveston Bay coarse or closed in MOM6. SFINCS owns the bay.
  - Diagnostics: one file block, `SSH_inst`, `regional_section` = a thin box around the SFINCS offshore edge, 10–15 min instantaneous. Plus daily `SSH`, `SSU`, `SSV` for sanity checks.
- **Validation gauges (IDs from memory, NOT verified; nothing was executed).** Your notebook's cell-57 station lookup can confirm them.
  - Galveston Pier 21 **8771450**
  - Galveston Bay Entrance North Jetty **8771341**
  - Galveston Railroad Bridge **8771486**
  - Eagle Point **8771013**
  - Morgans Point **8770613**
  - Manchester **8770777**
  - San Luis Pass **8771972**
  - Rollover Pass **8770971**
  - Sabine Pass North **8770570** (east control)
  - The original Mobile/Pensacola IDs (8729840, 8735180, 8737048) match my memory but are also unverified. They no longer apply.
- **Metrics:** tide-only RMSE and phase; storm peak and timing; non-tidal residual at open-coast gauges (MOM6 only) and at bay gauges (MOM6→SFINCS chain).

---

## 5. Path to future scenarios (CESM / MESACLIP)

| Need | Exists | To build |
|---|---|---|
| Ocean OBC from climate model | `cesm_pop_output` (CESM-HR FOSI, LENS2 via `dataset_path`/`member`), monthly tseries (`cesm_ocean_output.py:115–155`) | Point it at MESACLIP POP 0.1° output. Check variable names, `z_t` coords, and output frequency (monthly SSH will not carry surge; that's fine for the background state). |
| Atmosphere from climate model | DATM `CPLHIST` mode reads coupler history `cpl.hx.atm.1h.inst` / `3h.avrg` (`datm.xml:5199–5368`) | MESACLIP likely has CAM output, not coupler history. You'd convert 3-hourly (or better) `UBOT/VBOT/PSL/TBOT/QBOT/FLDS/FSDS/PRECT` into custom DATM streams + mesh. UNKNOWN whether high-frequency fields exist. |
| Sea-level rise | none | Add global-mean SLR (`zostoga`) and local VLM offline to `bzs`, if the model is Boussinesq. |
| Bias handling | none | Delta method: future η anomaly + present-day observed MSL (NAVD88) + SLR. |
| Tides under SLR | TPXO (present day) | Accept a present-day tide, or run a tides-only MOM6 with raised sea level. |

---

## 6. DART (data assimilation), since you want to use it

- **What exists:** `CR_JRA_DA` compset, `ninst` ensemble members, `DATA_ASSIMILATION_OCN=TRUE`, 24 h cycles, `user_nl_dart`, Argo T/S from CrocoLake through `dartobsgen`. DOCUMENTED: `CrocoGallery/dart/tutorial3_cycling_dart_cesm.ipynb`.
- **Fit for surge:** limited as-is. Argo T/S corrects the stratification and the Loop Current, not the barotropic surge.
- **Useful now:**
  - (a) DA-constrained initial state before Beryl (warm-core eddies matter for intensity, less for surge).
  - (b) The ensemble machinery alone, without assimilation: perturb forcing (ERA5 vs Holland vortex parameters) to get an **ensemble of MOM6 boundaries → ensemble of SFINCS runs**. That gives uncertainty bands on flood depth.
- **Needs checking:** SSH or tide-gauge DA requires η in the DART MOM6 state vector and a sub-daily cycle. UNKNOWN.

---

## E. SFINCS side (your files)

**Current setup (CONFIRMED from `GBMODEL\Models\GB_Beryl2024_TX\`):**
- Grid: 504×566 at 200 m, `x0 = 260361`, `y0 = 3203951`, EPSG:32615, 2024-06-25 → 2024-07-15.
- Settings: `baro = 1`, `pavbnd = 0`, `gapres = 101200`. Meteo from `press_2d.nc`, `wind_2d.nc`, `precip_2d.nc` (ERA5).
- `sfincs.bnd`: **3 points** at Rollover Pass, San Luis Pass, and the Bay Entrance. They coincide with the obs points named `*BC`.
- `sfincs.bzs`: hourly, 481 rows, 0–1,728,000 s. Source: `data_preparation/SFINCS_WLBoundary(.bzs).py`. That script downloads **observed** CO-OPS 6-min water level, **default datum NAVD** (entered interactively, so the datum actually used is not recorded), and averages it to hourly (lines 19–95, 169–171).
- **Mismatch:** boundary *cells* come from `setup_mask_bounds(btype='waterlevel', zmax=-2)` on the offshore domain edges (Beryl notebook cells 21, 24). The 3 forcing *points* sit at the inlets, ~20–40 km away. SFINCS spreads inlet signals onto the offshore boundary. The notebook markdown still says "GTSM", but the code reads the gauge file.
- **Datum:** land is CUDEM NAVD88. Offshore gaps are filled with GEBCO (MSL) with no offset (`hydromt_data.yml`).
- **Depth at the boundary: UNKNOWN.** Reading `sfincs.dep` / `msk` needs code, which is not allowed in this brainstorm. The active zone goes to −35 m, and the boundary is where the depth is below −2 m.

**Format (CONFIRMED from your files):**
- `sfincs.bnd`: one line per point, `x y` in the model CRS. The quadtree variant adds optional `"name"`.
- `sfincs.bzs`: `t  zs1 zs2 … zsN`, where t = seconds since `tref` and there is one column per bnd point, in bnd order.

**HydroMT (DOCUMENTED):**
- Regular/subgrid (v1 API): `SfincsModel.setup_waterlevel_forcing(geodataset=… | timeseries=df, locations=gdf, offset=…, buffer=…, merge=…)`. It is already used in `SFINCS_GB_Beryl.ipynb` cell 32. A MOM6 export can go in as `timeseries` (DataFrame indexed by time, one column per point) plus `locations` (GeoDataFrame). Or as a `GeoDataset` of MOM6 points with `buffer`.
- Quadtree (hydromt_sfincs 2.0 rc): `sf.water_level.create(timeseries, locations, merge, buffer)` (`SFINCS_GB_Beryl_Quadtree.ipynb` cell 15).
- API reference: https://deltares.github.io/hydromt_sfincs/latest/

**Recommendation (E16):**
- Put new bnd points **along the actual offshore boundary cells**, spaced about one MOM6 cell apart (≈2–4 km). Drop the 3 inlet points.
- Keep the SFINCS offshore edge in **≥10–15 m** water. That is well deeper than the MOM6 `min_depth`, and ≥3–5 MOM6 cells inside the MOM6 wet area.
- Keep it far (tens of cells) from any MOM6 OBC.
- Extend the SFINCS domain south if its edge is near 5 m depth.
- At 1/12° (≈9 km) the Galveston shelf is only a few MOM6 cells wide near the coast. Use a ≤1/48° child, or option A at 1/50°, if the boundary sits within ~20 km of shore.

---

## F. Compute estimate (1 simulated month, Derecho CPU)

**Measured base:** 100×100 cells, nk = 10, DT = 600 s, 30 days, 40 PEs → **47 s wall, 26.6 PE-h per simulated year** (`SeaSloth/results/mom6_scaling.json`, "Caribbean", ntasks 40).

**Scaling assumptions:** cost ∝ cells × nk / dt. nk = 50. dt ∝ Δx.

| Case | Cells | dt (s) | Factor vs base | PE-h per sim-month |
|---|---|---|---|---|
| A 1/12° (~9 km) | 76×52 ≈ 4.0k | 600 | 2.0× | ~4 |
| A 1/25° | 158×108 ≈ 17k | 300 | 17× | ~40 |
| A 1/50° | 315×215 ≈ 68k | 150 | 135× | ~300 |
| B 1/12° (whole Gulf) | 210×156 ≈ 33k | 600 | 16× | ~36 |
| B 1/25° | 438×325 ≈ 142k | 300 | 142× | ~315 |

**Caveats:**
- The base case is flat 1000 m. The deep Gulf (≈3.7 km) shortens barotropic substeps. Apply ×2–3 margin.
- Spin-up months, a Step-1 test, and DA ensembles (×`ninst`) add on top.
- Even the largest row is under ~1,000 core-hours per month. Compute is **not** the constraint. Forcing data is.

---

## 7. Questions for the instructors

1. Is ERA5 (or JRA-3Q) for 2024 staged on GLADE as DATM streams? If not, what is the recommended recipe for a custom ERA5 DATM stream: the ERA5 mode's full variable list, or the JRA mode with replaced files?
2. Can DATM run on a finer atm mesh (e.g. the ocean mesh) so TC winds aren't smoothed to TL319? How do I set `ATM_DOMAIN_MESH` through CrocoDash?
3. What is the ocean coupling interval (`OCN_NCPL`) for `CR_JRA`? Can it be 10–15 min?
4. Does RDA `d010049` include GLORYS interim (2021-07 onward)? Can `glorys.py` get a `myint` access method?
5. Does GLORYS `zos` include an atmospheric-pressure response? How does Flather + GLORYS η interact with the IB near the OBC?
6. Is CESM-MOM6 Boussinesq in the regional config? How do you recommend handling steric/global SLR for surge?
7. Recommended `min_depth`, `MASKING_DEPTH`, and W&D settings for a 1/50° shelf domain with barrier islands? Is `BT_LIMIT_INTEGRAL_TRANSPORT` advised?
8. Why does `TidesConfigurator` enable only `TIDE_M2` body tides? Is adding `TIDE_K1/O1/...` in `user_nl_mom` safe with `OBC_TIDE_ADD_EQ_PHASE`?
9. When will PR #269 (interior segments) merge? Is it the right tool for Yucatán / Florida Straits cuts?
10. For nesting, should children use `SSH` instead of `zos`? `zos` removes the domain mean.
11. Can DART's MOM6 `model_mod` update SSH/η, and assimilate tide-gauge or altimetry SSH on sub-daily cycles?
12. Has anyone used MESACLIP (CESM1.3-HR) output through `cesm_pop_output`? Is 3-hourly atmospheric output available for DATM?
13. Practical resolution floor and timestep guidance for hydrostatic MOM6 on a ~2 km shallow shelf. Are there any timing tables beyond SeaSloth?

---

## 8. How it is doable: end-to-end workflow (Katrina, Aug 2005, as the example)

**Why Katrina is easier than Beryl:** every input is stock.
- JRA55-do covers 2005 (1958–2023).
- GLORYS multiyear covers 2005. That is the dataset CrocoDash hardcodes (`glorys.py:130`), and RDA is the tutorial default.
- GLOFAS covers 2005 (1979–2024).
- TPXO9 is time-independent.

Blockers 1–2 in §2 disappear. What remains: TC wind resolution, the datum, and the SFINCS domain.

**Honest limit:** your SFINCS model is Galveston. Katrina made landfall in Louisiana/Mississippi. At Galveston it gives only a small far-field signal. That is fine for **testing the chain**, not for **flood validation**. A whole-Gulf MOM6 parent is event-agnostic. The same run can later drive a Galveston SFINCS, a Mississippi-coast SFINCS, or Mobile Bay.

The code below was written from the APIs read in this investigation. **It was not run.** Argument names come from `CrocoGallery/dart/tutorial3_cycling_dart_cesm.ipynb` cells 6–18 and `CrocoDash/CrocoDash/case.py:62–81, 483–490`.

### Step 1: Environment (Casper/Derecho)
Follow `CrocoGallery/workshop_2026/index.md`. Use the CROCODILEworkspace template and run `./install.sh --workshop`. That installs CESM plus the CrocoDash conda env.

### Step 2: Grid, topography, vertical grid (Jupyter on Casper)
```python
from CrocoDash.grid import Grid
from CrocoDash.topo import Topo
from CrocoDash.vgrid import VGrid

grid = Grid(resolution=1/12, xstart=262.0, lenx=17.5,   # -98 -> -80.5
            ystart=18.0, leny=13.0, name="gom12")        # 18N -> 31N
topo = Topo(grid=grid, min_depth=5.0)                    # value to tune (Q7)
topo.set_from_dataset(bathymetry_path=GEBCO_PATH,
                      longitude_coordinate_name="lon",
                      latitude_coordinate_name="lat",
                      vertical_coordinate_name="elevation")
vgrid = VGrid.hyperbolic(nk=50, depth=topo.max_depth, ratio=20.0)
```
Check that the north and west edges are all land. Then only the south edge (Yucatán/Caribbean) and the east edge (Florida Straits/Bahamas) are open.

### Step 3: Case + forcings
```python
from CrocoDash.case import Case
case = Case(cesmroot=CESM, caseroot=CASEROOT, inputdir=INPUTDIR,
            ocn_grid=grid, ocn_vgrid=vgrid, ocn_topo=topo,
            compset="CR_JRA", machine="derecho", project=PROJECT)
case.configure_forcings(
    date_range=["2005-08-15 00:00:00", "2005-09-05 00:00:00"],
    boundaries=["south", "east"],
    function_name="get_glorys_data_from_rda",
    tpxo_elevation_filepath=TPXO_H, tpxo_velocity_filepath=TPXO_U,
    tidal_constituents=["M2","S2","N2","K2","K1","O1","P1","Q1"],
)
case.process_forcings()
```
This writes the IC, OBC, and tide files plus the `user_nl_mom` OBC block (`forcing/mom6.py:611–671`). It also aligns JRA stream years to 2005 (`forcing/atm.py`).

### Step 4: Hand edits in the case directory
- `user_nl_mom`: add `TIDE_S2`, `TIDE_N2`, `TIDE_K2`, `TIDE_K1`, `TIDE_O1`, `TIDE_P1`, `TIDE_Q1 = True`. CrocoDash sets only M2 (`tides.py:86`).
- `SourceMods/src.mom/diag_table`: copy `CaseDocs/diag_table` and add one boundary-strip file (FMS legacy format; DOCUMENTED). The box below is illustrative:
  ```
  "sfincs_bnd", 10, "minutes", 1, "days", "time"
  "ocean_model", "SSH_inst", "SSH_inst", "sfincs_bnd", "all", ".false.", "-95.6 -94.0 28.8 29.4 -1 -1", 2
  ```
  Then run `./preview_namelists` and check `CaseDocs/diag_table`.

### Step 5 (optional): Stronger TC winds
JRA at about 55 km, 3-hourly, badly under-resolves Katrina's core. To fix it:
1. Take the JRA 2005 `U_10`, `V_10`, and `SLP` global files.
2. Blend in a Holland vortex built from the HURDAT2 track. Keep the files **global**, so DATM still has data everywhere.
3. Point the streams at the new files in `user_nl_datm_streams`, e.g. `<stream>:datafiles = /path/u10_2005_holland.nc`. The syntax is confirmed (`CDEPS/cime_config/stream_cdeps.py:120–160`). Stream names depend on `DATM_MODE`; read them from `CaseDocs/datm.streams.xml`.
4. Remaining limit: DATM remaps to TL319, so the vortex is still smoothed (Q2).

### Step 6: Build and run on Derecho
`./case.setup` → `qcmd -A <PROJECT> -- ./case.build` → `./case.submit`. At 1/12° whole-Gulf, 3 weeks ≈ 25–100 PE-hours (§F with margin).

### Step 7: MOM6 → SFINCS
1. Read `SSH_inst` from the strip file. Interpolate to the new SFINCS bnd points on the offshore edge (§E).
2. Apply the datum anomaly method (§3).
3. Write the forcing with `sf.setup_waterlevel_forcing(timeseries=df, locations=gdf, merge=False)`, or `sf.water_level.create(...)` for the quadtree model.
4. Keep `pavbnd = 0` and `baro = 1`. Run SFINCS as today with rain and rivers.

### Step 8: Validate
- Tide-only check against open-coast gauges.
- Storm: CO-OPS gauges near landfall. IDs are unverified, and several failed at peak: Grand Isle 8761724, Shell Beach 8761305, Bay Waveland 8747437, Dauphin Island 8735180, Mobile State Docks 8737048, Pensacola 8729840. Far field: Galveston Pier 21 8771450.
- Katrina also has extensive surveyed high-water marks (FEMA/USGS). Those are the usual peak-surge check where gauges failed.

### What makes it hard (in order)
1. TC wind resolution in DATM (Step 5).
2. Datum offset (§3).
3. Shelf resolution near the SFINCS boundary (≤2–4 km, which may need a nested child).
4. Unmerged interior segments, only needed if you want exact straits cuts.

Compute and data access are not the bottleneck for Katrina.
