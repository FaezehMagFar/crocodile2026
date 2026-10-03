import argparse
import hashlib
import json
import shutil
from pathlib import Path

import numpy as np
import xarray as xr
from netCDF4 import Dataset


CASE_NAME = "gom12_ike_ERA5full.001"
REGIONS = ("TX", "MS")


def sha256(path, block_size=8 * 1024 * 1024):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while block := stream.read(block_size):
            digest.update(block)
    return digest.hexdigest()


def next_available(path):
    if not path.exists():
        return path
    for version in range(2, 1000):
        candidate = path.with_name(f"{path.stem}_v{version}{path.suffix}")
        if not candidate.exists():
            return candidate
    raise RuntimeError(f"Could not find an unused filename for {path}")


def raw_time(path):
    with xr.open_dataset(path, decode_times=False) as dataset:
        return np.asarray(dataset.time.values), dataset.time.attrs.get("calendar")


def correct_file(source, destination):
    source_times, source_calendar = raw_time(source)
    shutil.copy2(source, destination)

    with Dataset(destination, "r+") as dataset:
        dataset.variables["time"].setncattr("calendar", "proleptic_gregorian")

    corrected_times, corrected_calendar = raw_time(destination)
    if not np.array_equal(source_times, corrected_times):
        raise RuntimeError(f"Raw time values changed in {destination}")
    if corrected_calendar != "proleptic_gregorian":
        raise RuntimeError(f"Calendar attribute was not corrected in {destination}")

    with xr.open_dataset(destination) as dataset:
        first = str(dataset.time.values[0])
        last = str(dataset.time.values[-1])
        dimensions = dict(dataset.SSH_inst.sizes)
        units = dataset.SSH_inst.attrs.get("units", "")

    if not first.startswith("2008-08-30T00:10"):
        raise RuntimeError(f"Unexpected first corrected time: {first}")
    if not last.startswith("2008-09-20T00:00"):
        raise RuntimeError(f"Unexpected last corrected time: {last}")

    return {
        "source_file": str(source),
        "source_sha256": sha256(source),
        "source_calendar": source_calendar,
        "corrected_file": str(destination),
        "corrected_sha256": sha256(destination),
        "corrected_calendar": corrected_calendar,
        "raw_numeric_time_values_changed": False,
        "ssh_values_changed": False,
        "first_time": first,
        "last_time": last,
        "dimensions": dimensions,
        "ssh_units": units,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    args = parser.parse_args()
    folder = args.folder.resolve()
    if not folder.is_dir():
        raise FileNotFoundError(folder)

    manifest = {
        "author": "Faezeh Maghsoodifar",
        "case": CASE_NAME,
        "correction": (
            "New copies were created and only time.calendar was changed from "
            "gregorian to proleptic_gregorian. SSH and raw numeric time values "
            "were not modified."
        ),
        "files": {},
    }

    for region in REGIONS:
        source = folder / f"{CASE_NAME}.mom6.sfincs_{region}.nc"
        if not source.is_file():
            raise FileNotFoundError(source)
        requested = source.with_name(
            source.name.replace(".nc", ".proleptic_gregorian.nc")
        )
        destination = next_available(requested)
        manifest["files"][region] = correct_file(source, destination)
        print(f"{region}: {destination}")

    manifest_path = next_available(folder / "manifest_calendar_corrected.json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
