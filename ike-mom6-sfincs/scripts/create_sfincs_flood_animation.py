#!/usr/bin/env python3
"""Create a GitHub-friendly SFINCS flood-inundation animation.

The plotted flood depth is ``zs - zb`` on cells that were dry in the first
SFINCS map output and subsequently became wet. Pre-existing water is shown in
light blue but is not counted as flood inundation.
"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
import contextily as cx
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.ticker import FuncFormatter
from netCDF4 import Dataset, num2date
from PIL import Image
from xyzservices import TileProvider


IKE_LANDFALL = datetime(2008, 9, 13, 7, 0)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Animate newly inundated cells from a SFINCS sfincs_map.nc file."
    )
    parser.add_argument("map_file", type=Path, help="Path to sfincs_map.nc")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("sfincs_ike_flood_animation.gif"),
        help="Output GIF path",
    )
    parser.add_argument(
        "--frame-step",
        type=int,
        default=3,
        help="Use every Nth model output (default: 3, or every three hours here)",
    )
    parser.add_argument(
        "--minimum-depth",
        type=float,
        default=0.05,
        help="Minimum displayed flood depth in metres (default: 0.05)",
    )
    parser.add_argument(
        "--maximum-depth",
        type=float,
        default=3.0,
        help="Upper color limit in metres (default: 3.0)",
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=160,
        help="Normal GIF frame duration in milliseconds (default: 160)",
    )
    return parser.parse_args()


def as_datetime(value: object) -> datetime:
    """Convert datetime/cftime values returned by netCDF4 to datetime."""
    return datetime(
        int(value.year),
        int(value.month),
        int(value.day),
        int(value.hour),
        int(value.minute),
        int(value.second),
    )


def time_label(timestamp: datetime) -> tuple[str, str]:
    delta_hours = (timestamp - IKE_LANDFALL).total_seconds() / 3600.0
    if abs(delta_hours) < 0.51:
        return f"{timestamp:%Y-%m-%d %H:%M UTC}  |  IKE LANDFALL", "#b71c1c"
    relation = "after" if delta_hours > 0 else "before"
    return (
        f"{timestamp:%Y-%m-%d %H:%M UTC}  |  "
        f"{abs(delta_hours):.0f} h {relation} landfall",
        "#102a43",
    )


def main() -> None:
    args = parse_args()
    if args.frame_step < 1:
        raise ValueError("--frame-step must be at least 1")
    if args.minimum_depth <= 0 or args.maximum_depth <= args.minimum_depth:
        raise ValueError("Depth limits must satisfy 0 < minimum < maximum")

    args.output.parent.mkdir(parents=True, exist_ok=True)

    with Dataset(args.map_file) as dataset:
        required = {"x", "y", "zb", "msk", "time", "zs"}
        missing = required.difference(dataset.variables)
        if missing:
            raise KeyError(f"Missing required SFINCS variables: {sorted(missing)}")

        x = np.ma.filled(dataset.variables["x"][:], np.nan)
        y = np.ma.filled(dataset.variables["y"][:], np.nan)
        bed = np.ma.filled(dataset.variables["zb"][:], np.nan)
        active = np.ma.filled(dataset.variables["msk"][:], 0) > 0

        time_variable = dataset.variables["time"]
        decoded = num2date(
            time_variable[:],
            units=time_variable.units,
            calendar=getattr(time_variable, "calendar", "standard"),
        )
        timestamps = [as_datetime(value) for value in decoded]

        initial_surface = dataset.variables["zs"][0]
        initial_depth = np.ma.filled(initial_surface, np.nan) - bed
        initial_wet = (
            active
            & ~np.ma.getmaskarray(initial_surface)
            & np.isfinite(initial_depth)
            & (initial_depth > args.minimum_depth)
        )
        initially_dry = active & ~initial_wet

        frame_indices = set(range(0, len(timestamps), args.frame_step))
        frame_indices.add(len(timestamps) - 1)
        landfall_index = min(
            range(len(timestamps)),
            key=lambda index: abs(timestamps[index] - IKE_LANDFALL),
        )
        frame_indices.add(landfall_index)
        frame_indices = sorted(frame_indices)

        if "corner_x" in dataset.variables and "corner_y" in dataset.variables:
            corner_x = np.ma.filled(dataset.variables["corner_x"][:], np.nan)
            corner_y = np.ma.filled(dataset.variables["corner_y"][:], np.nan)
            extent = [
                np.nanmin(corner_x),
                np.nanmax(corner_x),
                np.nanmin(corner_y),
                np.nanmax(corner_y),
            ]
        else:
            extent = [
                np.nanmin(x),
                np.nanmax(x),
                np.nanmin(y),
                np.nanmax(y),
            ]

        fig, axis = plt.subplots(figsize=(6.8, 6.5), dpi=100)
        fig.subplots_adjust(left=0.105, right=0.87, bottom=0.105, top=0.89)
        axis.set_xlim(extent[0], extent[1])
        axis.set_ylim(extent[2], extent[3])

        # Esri imagery plus its transparent reference layer creates the
        # satellite-hybrid background. The map is fetched once and reused for
        # all GIF frames.
        cx.add_basemap(
            axis,
            source=cx.providers.Esri.WorldImagery,
            crs="EPSG:32615",
            zoom=10,
            reset_extent=True,
            attribution=False,
        )
        flood_colormap = LinearSegmentedColormap.from_list(
            "sfincs_flood",
            ["#5ed4ff", "#1597e5", "#1764ab", "#08306b", "#4a1486"],
        )
        flood_image = axis.imshow(
            np.full(bed.shape, np.nan),
            origin="lower",
            extent=extent,
            cmap=flood_colormap,
            vmin=args.minimum_depth,
            vmax=args.maximum_depth,
            alpha=0.88,
            interpolation="nearest",
            zorder=3,
        )

        reference_tiles = TileProvider(
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
        cx.add_basemap(
            axis,
            source=reference_tiles,
            crs="EPSG:32615",
            zoom=10,
            reset_extent=True,
            attribution=False,
            zorder=4,
        )

        colorbar = fig.colorbar(
            flood_image,
            ax=axis,
            pad=0.025,
            fraction=0.047,
            extend="max",
        )
        colorbar.set_label("Flood depth, $z_s-z_b$ (m)", fontsize=11)
        colorbar.ax.tick_params(labelsize=9)

        axis.set_xlabel("Easting (km), WGS 84 / UTM zone 15N")
        axis.set_ylabel("Northing (km), WGS 84 / UTM zone 15N")
        axis.xaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value / 1000:.0f}"))
        axis.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value / 1000:.0f}"))
        axis.set_aspect("equal", adjustable="box")
        axis.grid(color="white", alpha=0.22, linewidth=0.6)
        axis.tick_params(labelsize=9)
        fig.suptitle(
            "SFINCS Hurricane Ike Flood Inundation — Galveston Bay",
            fontsize=14,
            fontweight="bold",
            y=0.965,
        )
        timestamp_text = axis.text(
            0.5,
            1.015,
            "",
            transform=axis.transAxes,
            ha="center",
            va="bottom",
            fontsize=11,
            fontweight="bold",
        )
        axis.text(
            0.01,
            0.012,
            (
                f"Newly inundated since {timestamps[0]:%Y-%m-%d %H:%M UTC}; "
                f"depth ≥ {args.minimum_depth:.2f} m"
            ),
            transform=axis.transAxes,
            ha="left",
            va="bottom",
            fontsize=8.5,
            color="#102a43",
            bbox={"facecolor": "white", "alpha": 0.82, "edgecolor": "none", "pad": 3},
        )
        axis.text(
            0.99,
            0.99,
            (
                "Imagery: Esri, Vantor, Earthstar Geographics, GIS User Community\n"
                "Reference: Esri, HERE, Garmin, © OpenStreetMap contributors"
            ),
            transform=axis.transAxes,
            ha="right",
            va="top",
            fontsize=5.2,
            color="white",
            zorder=6,
            bbox={"facecolor": "black", "alpha": 0.62, "edgecolor": "none", "pad": 2},
        )

        frames: list[Image.Image] = []
        durations: list[int] = []
        peak_flooded_cells = 0

        for index in frame_indices:
            surface = dataset.variables["zs"][index]
            depth = np.ma.filled(surface, np.nan) - bed
            flooded = (
                initially_dry
                & ~np.ma.getmaskarray(surface)
                & np.isfinite(depth)
                & (depth >= args.minimum_depth)
            )
            flood_depth = np.where(flooded, depth, np.nan)
            peak_flooded_cells = max(peak_flooded_cells, int(flooded.sum()))
            flood_image.set_data(flood_depth)

            label, color = time_label(timestamps[index])
            timestamp_text.set_text(label)
            timestamp_text.set_color(color)

            fig.canvas.draw()
            rgba = np.asarray(fig.canvas.buffer_rgba()).copy()
            frame = Image.fromarray(rgba, mode="RGBA").convert("RGB")
            frame = frame.quantize(colors=72, method=Image.Quantize.MEDIANCUT)
            frames.append(frame)

            if index == landfall_index:
                durations.append(1000)
            elif index == frame_indices[0]:
                durations.append(650)
            elif index == frame_indices[-1]:
                durations.append(1200)
            else:
                durations.append(args.duration)

        plt.close(fig)

    frames[0].save(
        args.output,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )

    size_mib = args.output.stat().st_size / (1024 * 1024)
    print(f"Saved {len(frames)} frames: {args.output}")
    print(f"GIF size: {size_mib:.2f} MiB")
    print(f"Peak newly inundated cells in sampled frames: {peak_flooded_cells:,}")
    print(f"Landfall frame: {timestamps[landfall_index]:%Y-%m-%d %H:%M UTC}")


if __name__ == "__main__":
    main()
