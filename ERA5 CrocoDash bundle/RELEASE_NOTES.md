# ERA5 CrocoDash extension v1.0.0

**Author: Faezeh Maghsoodifar, The University of Alabama**

This first public release provides a complete ERA5 atmospheric-forcing path
for regional MOM6 cases created with CrocoDash.

Highlights:

- eight ERA5 atmospheric fields supplied through CDEPS;
- ERA5-specific humidity derived from 2 m dew point and pressure;
- NCAR RDA preprocessing with hourly valid-time reconstruction;
- SCRIP and ESMF mesh generation;
- full-ERA5 and wind/pressure-only configuration modes;
- portable Git bundle and reviewable upstream patch;
- NCAR Derecho/Casper setup and validation tools; and
- a successful 21-day Hurricane Ike regional MOM6 example.

This release contains software and notebooks only. It does not redistribute
ERA5, GEBCO, GLORYS, TPXO, or MOM6 output data.
