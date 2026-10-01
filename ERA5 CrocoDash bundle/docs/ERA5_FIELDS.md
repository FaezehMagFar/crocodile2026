# ERA5 field mapping

Author: Faezeh Maghsoodifar

| ERA5 parameter | Prepared variable | Units supplied to CDEPS | CDEPS field |
|---|---|---|---|
| `128_165_10u` | `u10` | m s-1 | `Sa_u` |
| `128_166_10v` | `v10` | m s-1 | `Sa_v` |
| `128_151_msl` | `msl` | Pa | `Sa_pslv` and `Sa_pbot` |
| `128_167_2t` | `t2m` | K | `Sa_tbot` |
| `128_168_2d` + `msl` | `q2m` | kg kg-1 | `Sa_shum` |
| `235_055_mtpr` | `precip` | kg m-2 s-1 | `Faxa_prec` |
| `235_035_msdwswrf` | `swdn` | W m-2 | `Faxa_swdn` |
| `235_036_msdwlwrf` | `lwdn` | W m-2 | `Faxa_lwdn` |

The preprocessing flattens the ERA5 mean-flux forecast axes to valid hourly
time and derives specific humidity from dew-point temperature and pressure.
The resulting file contains all eight prepared variables on the ERA5 grid.

The extension maps these fields into the existing CDEPS JRA stream interface.
Therefore stream labels can contain `JRA` even when every datafile path points
to the prepared ERA5 file.
