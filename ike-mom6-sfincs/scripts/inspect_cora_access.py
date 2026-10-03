import fsspec
import xarray as xr


REFERENCE = (
    "s3://noaa-nos-cora-pds/cora_gec/native_grid/water_levels/zarr/"
    "fort.63_1979-2022.zarr"
)

filesystem = fsspec.filesystem(
    "reference",
    fo=REFERENCE,
    remote_protocol="s3",
    remote_options={"anon": True},
    target_protocol="s3",
    target_options={"anon": True},
)
dataset = xr.open_zarr(filesystem.get_mapper(""), consolidated=False)

print(dataset)
for name in ("zeta", "x", "y", "time"):
    variable = dataset[name]
    print(name, variable.dims, variable.shape, dict(variable.attrs))
print("time coverage", dataset.time.values[0], dataset.time.values[-1])
