# AutoCF command record

Scheduler-neutral commands executed for this model.

## build — 2026-09-29T21:50:56.436670+00:00

- Status: `PASS`
- Internet: May be required by configured data sources
- Run root: `/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg`
- Model root: `/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg/data/model/main`

```bash
./autocf build projects/galveston_ike2008_subgrid.yml
```

Next command:

```bash
./autocf run-only '/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg' --cpu
# or
./autocf run-only '/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg' --gpu
```

## run-only — 2026-09-29T22:15:05.214178+00:00

- Status: `PASS`
- Backend: `GPU`
- Internet: Not required
- Run root: `/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg`
- Model root: `/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg/data/model/main`

```bash
./autocf run-only runs/galv_ike2008_noaa_sg --gpu
```

Next command:

```bash
./autocf evaluate '/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg'
```

## evaluate — 2026-09-29T22:22:25.040102+00:00

- Status: `PASS`
- Internet: Required for missing observations or uncached satellite tiles; offline HMAX fallback available
- Run root: `/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg`
- Model root: `/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg/data/model/main`

```bash
./autocf evaluate runs/galv_ike2008_noaa_sg
```

Next command:

```bash
./autocf attribute '/home/fmaghsoodifar/SFINCS-MOM6/AutoCF-1.0.0-HPC/AutoCF_release_v1.0.0/runs/galv_ike2008_noaa_sg' --prepare
```
