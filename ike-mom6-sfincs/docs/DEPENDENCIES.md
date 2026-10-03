# Dependencies and external data

Use the earlier ERA5 CrocoDash release as a separate dependency. Its local README and environment.yml are in ../../project/ERA5 CrocoDash bundle/ relative to this document. Preserve its citations and notices. Add your previously published ERA5 repository or release URL here when available.

MOM6 workflows require the NCAR CrocoDash/CESM environment and datasets described by the runbook. SFINCS requires the AutoCF/HydroMT/SFINCS setup in HANDOFF_SFINCS_AutoCF.md. No combined environment has been verified.

Data remain in the parent NCARMOM6 project/ folder:

- era5.nc: ERA5 forcing.
- SFINCS_OCB_Input/: original and calendar-corrected MOM6 boundary NetCDF files.
- SFINCS_Model/: full forcing, model, terrain, and output files.
- ERA5 CrocoDash bundle/: earlier ERA5 release package.

These relative workspace paths will not exist in a fresh GitHub clone. Supply data separately and adapt the notebook/configuration paths. The copied SFINCS configuration and results document a recorded run; the lightweight folder alone does not contain all files required to rerun it.
