# Collaboration and upstream integration

Author: Faezeh Maghsoodifar

This repository is structured to support technical review and possible
collaboration with the CROCODILE-CESM/CrocoDash community.

## Extension scope

Relative to CrocoDash v1.0.0, the contribution changes six upstream files and
adds a modification notice:

```text
CrocoDash/forcing/atm.py
CrocoDash/raw_data_access/datasets/era5_atmos.py
docs/source/for_users/3a_configure_forcings.md
tests/forcing/test_atm.py
tests/forcing/test_configurators.py
tests/raw_data_access/test_era5_atmos.py
NOTICE
```

The exact commit is available both as
`patches/0001-add-full-era5-atmospheric-forcing.patch` and as the branch
`feature/era5-atmosphere` inside `bundle/crocodash-era5.bundle`.

## Suggested review topics

- Whether full ERA5 forcing should become a first-class CrocoDash data product.
- Whether stream names should remain compatible with the current JRA CDEPS
  interface or gain a new named data mode.
- Preferred handling of forcing padding and multi-year time windows.
- Whether the NCAR RDA access implementation should support additional ERA5
  archives or cloud sources.
- Test coverage across current CESM/CDEPS versions.

## Contact

Faezeh Maghsoodifar  
The University of Alabama  
fmaghsoodifar@crimson.ua.edu

When opening an upstream issue or pull request, link to the public release,
describe the successful Derecho case, and cite both this extension and the
upstream CrocoDash DOI.
