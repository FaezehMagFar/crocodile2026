"""Create the transparent SFINCS flood overlay used by the 3-D city map.

Example
-------
python create_sfincs_3d_city_assets.py --map /path/to/sfincs_map.nc
"""

from __future__ import annotations

import argparse
import json
import warnings
from pathlib import Path

import matplotlib.colors as mcolors
import numpy as np
import xarray as xr
from PIL import Image
from rasterio.warp import transform


DEPTH_THRESHOLD_M = 0.05
DISPLAY_MAX_M = 3.0


def _as_float(data: xr.DataArray) -> np.ndarray:
    """Return a NumPy array with masked/fill values converted to NaN."""
    return np.asarray(data.where(np.isfinite(data)).values, dtype=np.float32)


def build_assets(map_path: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    with xr.open_dataset(map_path, decode_times=False, mask_and_scale=True) as ds:
        x = np.asarray(ds["x"].values, dtype=float)
        y = np.asarray(ds["y"].values, dtype=float)
        bed = _as_float(ds["zb"])
        surface = _as_float(ds["zs"])
        epsg = int(np.asarray(ds["crs"].attrs.get("epsg", 32615)).item()) if "crs" in ds else 32615

    if surface.ndim != 3:
        raise ValueError(f"Expected zs(time, y, x); got shape {surface.shape}")

    depth = surface - bed[None, :, :]
    initially_wet = np.isfinite(depth[0]) & (depth[0] >= DEPTH_THRESHOLD_M)
    newly_inundated = (
        np.isfinite(depth)
        & (~initially_wet[None, :, :])
        & (depth >= DEPTH_THRESHOLD_M)
    )

    with warnings.catch_warnings():
        warnings.simplefilter("ignore", category=RuntimeWarning)
        maximum_depth = np.nanmax(np.where(newly_inundated, depth, np.nan), axis=0)

    colors = [
        "#65c9e8",
        "#2e9cc5",
        "#176c9c",
        "#16456f",
        "#33145f",
    ]
    cmap = mcolors.LinearSegmentedColormap.from_list("sfincs_flood", colors)
    normalized = np.clip(
        (maximum_depth - DEPTH_THRESHOLD_M) / (DISPLAY_MAX_M - DEPTH_THRESHOLD_M),
        0.0,
        1.0,
    )
    rgba = (cmap(np.nan_to_num(normalized, nan=0.0)) * 255).astype(np.uint8)
    rgba[..., 3] = np.where(np.isfinite(maximum_depth), 205, 0).astype(np.uint8)

    # SFINCS y coordinates increase south-to-north; image row zero must be north.
    rgba = np.flipud(rgba)
    image_path = output_dir / "sfincs_flood_depth_max.png"
    Image.fromarray(rgba, mode="RGBA").save(image_path, optimize=True)

    dx = float(np.median(np.diff(x)))
    dy = float(np.median(np.diff(y)))
    west, east = float(x.min() - dx / 2), float(x.max() + dx / 2)
    south, north = float(y.min() - dy / 2), float(y.max() + dy / 2)
    corners_x = [west, east, east, west]
    corners_y = [north, north, south, south]
    lon, lat = transform(f"EPSG:{epsg}", "EPSG:4326", corners_x, corners_y)
    coordinates = [[round(a, 8), round(b, 8)] for a, b in zip(lon, lat)]

    valid = maximum_depth[np.isfinite(maximum_depth)]
    config = {
        "floodImage": "sfincs_flood_depth_max.png",
        "coordinates": coordinates,
        "depthThresholdM": DEPTH_THRESHOLD_M,
        "displayMaximumM": DISPLAY_MAX_M,
        "maximumDepthM": round(float(np.nanmax(valid)), 3) if valid.size else None,
        "floodedCells": int(valid.size),
        "sourceCrs": f"EPSG:{epsg}",
    }
    config_path = output_dir / "sfincs_3d_city_config.js"
    config_path.write_text(
        "window.SFINCS_3D_CONFIG = " + json.dumps(config, indent=2) + ";\n",
        encoding="utf-8",
    )

    print(f"Created {image_path}")
    print(f"Created {config_path}")
    print(f"Image coordinates (TL, TR, BR, BL): {coordinates}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--map", type=Path, required=True, help="Path to sfincs_map.nc")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "interactive",
        help="Directory for the PNG overlay and JavaScript configuration",
    )
    args = parser.parse_args()
    build_assets(args.map.expanduser().resolve(), args.output_dir.resolve())


if __name__ == "__main__":
    main()
