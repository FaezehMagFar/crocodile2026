# Complete SFINCS model archive

`SFINCS_Model_Galveston_Ike_2008.zip` is the complete local
`project/SFINCS_Model/` package used for this upload. It contains the Galveston
Bay Hurricane Ike model configuration, geospatial inputs, prepared AORC/NOAA
forcing, terrain and land-surface inputs, SFINCS input/output, logs, evaluation
products, and AutoCF/HydroMT provenance records.

- Archive size: **1,446,353,370 bytes** (1.347 GiB)
- SHA-256:
  `ED5A52E7361F36622662ED3BACF483751D26E84FBA7B984A8C71EFA835E1AEF7`
- Archive root: `SFINCS_Model/galv_ike2008_/`
- Storage: Git Large File Storage (LFS)

AutoCF v1.0.0 HPC generated the recorded model workflow, but the AutoCF
software distribution is not included in the ZIP. See
`../../CREDITS_AND_CITATIONS.md` and preserve the included provenance records.

After cloning, retrieve the archive with:

```bash
git lfs install
git lfs pull
```

Verify on Linux/macOS:

```bash
sha256sum SFINCS_Model_Galveston_Ike_2008.zip
```

Verify in PowerShell:

```powershell
Get-FileHash -Algorithm SHA256 .\SFINCS_Model_Galveston_Ike_2008.zip
```
