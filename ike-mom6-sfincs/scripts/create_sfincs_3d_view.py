#!/usr/bin/env python3
"""Create a satellite-textured 3D view of SFINCS terrain and inundation."""

from __future__ import annotations

import argparse
from pathlib import Path

import contextily as cx
import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap, Normalize
from matplotlib.ticker import FuncFormatter
from netCDF4 import Dataset
from PIL import Image
from rasterio.warp import transform_bounds
from scipy.ndimage import map_coordinates
from xyzservices import TileProvider


IMAGERY_ATTRIBUTION = (
    "Imagery: Esri, Vantor, Earthstar Geographics, and the GIS User Community"
)
REFERENCE_ATTRIBUTION = (
    "Reference: Esri, HERE, Garmin, © OpenStreetMap contributors, "
    "and the GIS user community"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render a 3D SFINCS terrain and maximum-inundation view."
    )
    parser.add_argument("map_file", type=Path, help="Path to sfincs_map.nc")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("sfincs_ike_flood_3d.png"),
        help="Output PNG path",
    )
    parser.add_argument(
        "--minimum-depth",
        type=float,
        default=0.05,
        help="Minimum displayed inundation depth in metres (default: 0.05)",
    )
    parser.add_argument(
        "--maximum-depth",
        type=float,
        default=3.0,
        help="Upper flood-depth color limit in metres (default: 3.0)",
    )
    parser.add_argument(
        "--terrain-stride",
        type=int,
        default=4,
        help="Grid stride for the terrain surface (default: 4)",
    )
    parser.add_argument(
        "--flood-stride",
        type=int,
        default=2,
        help="Grid stride for flood markers (default: 2)",
    )
    parser.add_argument(
        "--tile-zoom",
        type=int,
        default=10,
        help="Satellite tile zoom level (default: 10)",
    )
    return parser.parse_args()


def reference_provider() -> TileProvider:
    return TileProvider(
        name="Esri.WorldBoundariesAndPlaces",
        url=(
            "https://services.arcgisonline.com/ArcGIS/rest/services/"
            "Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}"
        ),
        attribution=(
            "Esri, HERE, Garmin, (C) OpenStreetMap contributors, "
            "and the GIS user community"
        ),
    )


def composite_reference(imagery: np.ndarray, reference: np.ndarray) -> np.ndarray:
    """Alpha-composite transparent reference tiles over RGB imagery tiles."""
    base = imagery[..., :3].astype(np.float32)
    if reference.shape[:2] != imagery.shape[:2]:
        reference_image = Image.fromarray(reference)
        reference_image = reference_image.resize(
            (imagery.shape[1], imagery.shape[0]), Image.Resampling.BILINEAR
        )
        reference = np.asarray(reference_image)

    if reference.shape[2] == 4:
        alpha = reference[..., 3:4].astype(np.float32) / 255.0
    else:
        # Reference tiles are normally RGBA. If an RGB service response is
        # encountered, treat near-white pixels as transparent.
        rgb = reference[..., :3].astype(np.float32)
        alpha = (np.min(rgb, axis=2, keepdims=True) < 245).astype(np.float32)

    overlay = reference[..., :3].astype(np.float32)
    return np.clip(overlay * alpha + base * (1.0 - alpha), 0, 255).astype(np.uint8)


def satellite_texture(
    x: np.ndarray,
    y: np.ndarray,
    bounds: tuple[float, float, float, float],
    zoom: int,
) -> np.ndarray:
    """Download, warp, and sample the satellite-hybrid texture on the grid."""
    west, south, east, north = transform_bounds(
        "EPSG:32615",
        "EPSG:3857",
        bounds[0],
        bounds[2],
        bounds[1],
        bounds[3],
        densify_pts=21,
    )

    imagery, imagery_extent = cx.bounds2img(
        west,
        south,
        east,
        north,
        zoom=zoom,
        source=cx.providers.Esri.WorldImagery,
        ll=False,
        use_cache=True,
        n_connections=4,
    )
    reference, _ = cx.bounds2img(
        west,
        south,
        east,
        north,
        zoom=zoom,
        source=reference_provider(),
        ll=False,
        use_cache=True,
        n_connections=4,
    )
    hybrid = composite_reference(imagery, reference)
    warped, warped_extent = cx.warp_tiles(
        hybrid, imagery_extent, t_crs="EPSG:32615"
    )

    height, width = warped.shape[:2]
    col = (x - warped_extent[0]) / (warped_extent[1] - warped_extent[0]) * (width - 1)
    row = (warped_extent[3] - y) / (warped_extent[3] - warped_extent[2]) * (height - 1)
    sample_coordinates = np.vstack([row.ravel(), col.ravel()])

    channels = [
        map_coordinates(
            warped[..., channel].astype(np.float32),
            sample_coordinates,
            order=1,
            mode="nearest",
        ).reshape(x.shape)
        for channel in range(3)
    ]
    rgb = np.stack(channels, axis=-1) / 255.0
    return np.clip(rgb, 0.0, 1.0)


def maximum_new_inundation(
    dataset: Dataset,
    bed: np.ndarray,
    active: np.ndarray,
    minimum_depth: float,
) -> np.ndarray:
    """Return maximum depth on cells that are dry at the first output time."""
    initial_surface = dataset.variables["zs"][0]
    initial_depth = np.ma.filled(initial_surface, np.nan) - bed
    initial_wet = (
        active
        & ~np.ma.getmaskarray(initial_surface)
        & np.isfinite(initial_depth)
        & (initial_depth > minimum_depth)
    )
    initially_dry = active & ~initial_wet
    maximum_depth = np.full(bed.shape, np.nan, dtype=np.float32)

    for index in range(dataset.variables["zs"].shape[0]):
        surface = dataset.variables["zs"][index]
        depth = np.ma.filled(surface, np.nan) - bed
        flooded = (
            initially_dry
            & ~np.ma.getmaskarray(surface)
            & np.isfinite(depth)
            & (depth >= minimum_depth)
        )
        if not np.any(flooded):
            continue
        previous = np.nan_to_num(maximum_depth[flooded], nan=0.0)
        maximum_depth[flooded] = np.maximum(previous, depth[flooded])

    return maximum_depth


def main() -> None:
    args = parse_args()
    if args.terrain_stride < 1 or args.flood_stride < 1:
        raise ValueError("Grid strides must be at least 1")
    if args.minimum_depth <= 0 or args.maximum_depth <= args.minimum_depth:
        raise ValueError("Depth limits must satisfy 0 < minimum < maximum")

    args.output.parent.mkdir(parents=True, exist_ok=True)

    with Dataset(args.map_file) as dataset:
        required = {"x", "y", "zb", "msk", "zs"}
        missing = required.difference(dataset.variables)
        if missing:
            raise KeyError(f"Missing required SFINCS variables: {sorted(missing)}")

        x = np.ma.filled(dataset.variables["x"][:], np.nan)
        y = np.ma.filled(dataset.variables["y"][:], np.nan)
        bed = np.ma.filled(dataset.variables["zb"][:], np.nan)
        active = np.ma.filled(dataset.variables["msk"][:], 0) > 0
        maximum_depth = maximum_new_inundation(
            dataset, bed, active, args.minimum_depth
        )

    bounds = (
        float(np.nanmin(x)),
        float(np.nanmax(x)),
        float(np.nanmin(y)),
        float(np.nanmax(y)),
    )
    texture = satellite_texture(x, y, bounds, args.tile_zoom)

    terrain_stride = args.terrain_stride
    xs = x[::terrain_stride, ::terrain_stride] / 1000.0
    ys = y[::terrain_stride, ::terrain_stride] / 1000.0
    zs = np.clip(bed[::terrain_stride, ::terrain_stride], -6.0, 22.0)
    terrain_active = active[::terrain_stride, ::terrain_stride]
    zs = np.where(terrain_active, zs, np.nan)
    terrain_colors = texture[::terrain_stride, ::terrain_stride].copy()
    terrain_colors = np.clip(terrain_colors * 0.90, 0.0, 1.0)
    terrain_rgba = np.dstack(
        [terrain_colors, np.where(terrain_active, 1.0, 0.0)]
    )

    flood_stride = args.flood_stride
    flood_depth = maximum_depth[::flood_stride, ::flood_stride]
    flood_valid = np.isfinite(flood_depth) & (flood_depth >= args.minimum_depth)
    flood_x = x[::flood_stride, ::flood_stride][flood_valid] / 1000.0
    flood_y = y[::flood_stride, ::flood_stride][flood_valid] / 1000.0
    flood_bed = np.clip(
        bed[::flood_stride, ::flood_stride][flood_valid], -6.0, 22.0
    )
    flood_z = flood_bed + flood_depth[flood_valid] + 0.25

    flood_colormap = LinearSegmentedColormap.from_list(
        "sfincs_flood_3d",
        ["#5ed4ff", "#1597e5", "#1764ab", "#08306b", "#4a1486"],
    )
    flood_norm = Normalize(vmin=args.minimum_depth, vmax=args.maximum_depth)

    fig = plt.figure(figsize=(13.5, 9.0), dpi=180)
    axis = fig.add_subplot(111, projection="3d")
    figure_surface = axis.plot_surface(
        xs,
        ys,
        zs,
        facecolors=terrain_rgba,
        rstride=1,
        cstride=1,
        linewidth=0,
        antialiased=False,
        shade=False,
        zorder=1,
    )
    figure_surface.set_edgecolor("none")

    flood = axis.scatter(
        flood_x,
        flood_y,
        flood_z,
        c=flood_depth[flood_valid],
        cmap=flood_colormap,
        norm=flood_norm,
        marker="s",
        s=4.5,
        linewidths=0,
        alpha=0.88,
        depthshade=False,
        zorder=4,
    )

    axis.view_init(elev=35, azim=225)
    axis.set_xlim(bounds[0] / 1000.0, bounds[1] / 1000.0)
    axis.set_ylim(bounds[2] / 1000.0, bounds[3] / 1000.0)
    axis.set_zlim(-6.0, 26.0)
    axis.set_box_aspect((1.0, 1.12, 0.20))
    axis.set_xlabel("Easting (km)", labelpad=10)
    axis.set_ylabel("Northing (km)", labelpad=12)
    axis.set_zlabel("Elevation / water surface (m)", labelpad=9)
    axis.zaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value:.0f}"))
    axis.tick_params(labelsize=8, pad=1)
    axis.grid(True, alpha=0.20)
    axis.xaxis.pane.set_alpha(0.03)
    axis.yaxis.pane.set_alpha(0.03)
    axis.zaxis.pane.set_alpha(0.03)

    colorbar = fig.colorbar(
        flood,
        ax=axis,
        pad=0.035,
        fraction=0.035,
        shrink=0.72,
        extend="max",
    )
    colorbar.set_label("Maximum newly inundated depth (m)", fontsize=10)
    colorbar.ax.tick_params(labelsize=8)

    fig.suptitle(
        "SFINCS Hurricane Ike — 3D Flood Inundation",
        fontsize=18,
        fontweight="bold",
        y=0.965,
    )
    fig.text(
        0.5,
        0.925,
        (
            "Galveston Bay • maximum depth on initially dry cells, "
            "2008-09-08 to 2008-09-16 • vertical scale exaggerated ~600×"
        ),
        ha="center",
        va="center",
        fontsize=10.5,
        color="#263238",
    )
    fig.text(
        0.5,
        0.025,
        f"{IMAGERY_ATTRIBUTION}  |  {REFERENCE_ATTRIBUTION}",
        ha="center",
        va="center",
        fontsize=6.5,
        color="#455a64",
    )

    fig.subplots_adjust(left=0.02, right=0.91, bottom=0.06, top=0.90)
    fig.savefig(args.output, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    print(f"Saved: {args.output}")
    print(f"Maximum newly inundated depth: {np.nanmax(maximum_depth):.2f} m")
    print(f"Newly inundated cells: {np.isfinite(maximum_depth).sum():,}")


if __name__ == "__main__":
    main()
