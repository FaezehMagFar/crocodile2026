# Method

Author: Faezeh Maghsoodifar

## Problem

CrocoDash regional MOM6 cases use the CDEPS JRA atmosphere interface. The
stock CESM ERA5 data mode was designed for a different component use case and
does not export the full set of bottom-atmosphere state fields required by the
ocean flux calculation.

## Solution

The extension retains `DATM%JRA` as the field interface but overrides its eight
streams with one prepared ERA5 NetCDF file and an ERA5 ESMF mesh. This provides
the names expected by CMEPS while replacing the atmospheric data source.

The preprocessing module:

1. locates monthly ERA5 analysis and mean-flux files in NCAR RDA `d633000`;
2. subsets the requested time interval;
3. converts forecast coordinates to valid hourly time;
4. derives specific humidity from 2 m dew point and pressure;
5. standardizes eight atmospheric variables and units;
6. writes one CDEPS-ready NetCDF file; and
7. creates SCRIP and ESMF mesh files for the ERA5 grid.

The atmosphere configurator writes late stream overrides to
`user_nl_datm_streams`. CDEPS uses those entries when generating
`datm.streams.xml`.

## Demonstration

The included example uses:

- ERA5 for all eight atmospheric streams;
- GEBCO for bathymetry;
- GLORYS for ocean initial and open-boundary conditions;
- TPXO9 v1 for astronomical tides;
- a 192 x 156 regional MOM6 grid with 50 vertical levels; and
- a 21-day Hurricane Ike simulation from 30 August through 20 September 2008.

The successful Derecho run completed with exit status zero. Validation showed
eight ERA5 file references and zero JRA datafile references in
`datm.streams.xml`.
