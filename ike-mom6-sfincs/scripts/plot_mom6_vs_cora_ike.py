from pathlib import Path

import fsspec
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import xarray as xr


ROOT = Path(r"C:\Users\fmagh\OneDrive\Desktop\Documents\ChatGPT\MOM6")
MOM6_FILE = Path(
    r"C:\Users\fmagh\OneDrive - The University of Alabama\Research\SummerSchool_Programs\NCARMOM6\project\SFINCS_OCB_Input\gom12_ike_ERA5full.001.mom6.sfincs_TX.proleptic_gregorian.nc"
)
CORA_REFERENCE = ROOT / "NOAA_CORA_reference" / "fort.63_1979-2022.reference.json"
COORDINATE_CACHE = ROOT / "NOAA_CORA_reference" / "cora_native_xy.npz"
OUTPUT_DIR = ROOT / "comparison_outputs"

PIER21_LON = -94.793
PIER21_LAT = 29.310
START = "2008-08-30T00:00:00"
END = "2008-09-20T00:00:00"
CALM_START = "2008-09-01T00:00:00"
CALM_END_EXCLUSIVE = "2008-09-08T00:00:00"
IKE_START = "2008-09-09T00:00:00"
IKE_END = "2008-09-15T23:59:59"
LANDFALL = pd.Timestamp("2008-09-13T07:00:00")


def haversine_km(lon, lat, target_lon, target_lat):
    radius = 6371.0088
    lon1 = np.deg2rad(lon)
    lat1 = np.deg2rad(lat)
    lon2 = np.deg2rad(target_lon)
    lat2 = np.deg2rad(target_lat)
    dlon = lon1 - lon2
    dlat = lat1 - lat2
    a = np.sin(dlat / 2.0) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon / 2.0) ** 2
    return 2.0 * radius * np.arcsin(np.sqrt(np.clip(a, 0.0, 1.0)))


def mom6_series(path):
    with xr.open_dataset(path) as dataset:
        calendar = dataset.time.encoding.get("calendar")
        if calendar != "proleptic_gregorian":
            raise ValueError(f"Expected corrected MOM6 calendar, found {calendar!r}")

        ssh = dataset["SSH_inst"]
        ydim = next(dim for dim in ssh.dims if dim.startswith("yh"))
        xdim = next(dim for dim in ssh.dims if dim.startswith("xh"))
        lon = np.asarray(dataset[xdim].values, dtype=float)
        lat = np.asarray(dataset[ydim].values, dtype=float)
        lon = np.where(lon > 180.0, lon - 360.0, lon)
        lon2d, lat2d = np.meshgrid(lon, lat)

        first = np.asarray(ssh.isel(time=0).values)
        wet = np.isfinite(first)
        distance = haversine_km(lon2d, lat2d, PIER21_LON, PIER21_LAT)
        distance = np.where(wet, distance, np.inf)
        iy, ix = np.unravel_index(np.argmin(distance), distance.shape)

        selected = ssh.isel({ydim: iy, xdim: ix}).sel(time=slice(START, END)).load()
        series = selected.to_series().sort_index()

    return series, {
        "lon": float(lon2d[iy, ix]),
        "lat": float(lat2d[iy, ix]),
        "distance_km": float(distance[iy, ix]),
        "iy": int(iy),
        "ix": int(ix),
    }


def open_cora():
    filesystem = fsspec.filesystem(
        "reference",
        fo=str(CORA_REFERENCE),
        remote_protocol="s3",
        remote_options={"anon": True},
    )
    return xr.open_zarr(filesystem.get_mapper(""), consolidated=False, chunks=None)


def cora_coordinates(dataset):
    if COORDINATE_CACHE.exists():
        cached = np.load(COORDINATE_CACHE)
        return cached["x"], cached["y"]

    print("Downloading CORA native-grid coordinates once; this may take a few minutes.")
    x = np.asarray(dataset["x"].values, dtype=float)
    y = np.asarray(dataset["y"].values, dtype=float)
    np.savez_compressed(COORDINATE_CACHE, x=x, y=y)
    return x, y


def cora_series(dataset):
    x, y = cora_coordinates(dataset)
    valid = np.isfinite(x) & np.isfinite(y)
    distance = np.full(x.shape, np.inf, dtype=float)
    distance[valid] = haversine_km(x[valid], y[valid], PIER21_LON, PIER21_LAT)
    node = int(np.argmin(distance))

    selected = dataset["zeta"].isel(node=node).sel(time=slice(START, END)).load()
    series = selected.to_series().sort_index()
    series = series.replace(-99999.0, np.nan).dropna()

    return series, {
        "node": node,
        "lon": float(x[node]),
        "lat": float(y[node]),
        "distance_km": float(distance[node]),
    }


def calm_anomaly(series):
    calm = series[(series.index >= CALM_START) & (series.index < CALM_END_EXCLUSIVE)]
    if calm.empty:
        raise ValueError("No values found in the calm-reference interval")
    return series - float(calm.mean()), float(calm.mean())


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    mom6_10min, mom6_location = mom6_series(MOM6_FILE)
    mom6_hourly = mom6_10min.resample("1h").mean()

    cora_dataset = open_cora()
    try:
        cora_hourly, cora_location = cora_series(cora_dataset)
    finally:
        cora_dataset.close()

    mom6_anomaly, mom6_reference = calm_anomaly(mom6_hourly)
    cora_anomaly, cora_reference = calm_anomaly(cora_hourly)

    comparison = pd.concat(
        [mom6_anomaly.rename("MOM6_anomaly_m"), cora_anomaly.rename("CORA_anomaly_m")],
        axis=1,
    ).loc[START:END]
    common = comparison.dropna()
    if common.empty:
        raise ValueError("MOM6 and CORA have no common timestamps")

    difference = common["MOM6_anomaly_m"] - common["CORA_anomaly_m"]
    rmse = float(np.sqrt(np.mean(difference**2)))
    bias = float(difference.mean())
    correlation = float(common.corr().iloc[0, 1])

    ike = common.loc[IKE_START:IKE_END]
    mom6_peak_time = ike["MOM6_anomaly_m"].idxmax()
    cora_peak_time = ike["CORA_anomaly_m"].idxmax()
    mom6_peak = float(ike.loc[mom6_peak_time, "MOM6_anomaly_m"])
    cora_peak = float(ike.loc[cora_peak_time, "CORA_anomaly_m"])

    export = comparison.copy()
    export["MOM6_raw_hourly_m"] = mom6_hourly
    export["CORA_raw_m"] = cora_hourly
    export.index.name = "time_UTC"
    csv_path = OUTPUT_DIR / "MOM6_vs_CORA_Ike_Pier21.csv"
    export.to_csv(csv_path, float_format="%.6f")

    figure, axis = plt.subplots(figsize=(13.2, 6.8))
    axis.plot(
        comparison.index,
        comparison["CORA_anomaly_m"],
        color="#E69F00",
        linewidth=2.0,
        label=f"NOAA CORA v1.1 ({cora_location['distance_km']:.2f} km from Pier 21)",
    )
    axis.plot(
        comparison.index,
        comparison["MOM6_anomaly_m"],
        color="#0072B2",
        linewidth=1.8,
        label=f"ERA5-forced MOM6 ({mom6_location['distance_km']:.2f} km from Pier 21)",
    )
    axis.axvline(LANDFALL, color="#C62828", linestyle="--", linewidth=1.5, label="Ike landfall (~07 UTC)")
    axis.axhline(0.0, color="0.35", linewidth=0.8)
    axis.axvspan(pd.Timestamp(CALM_START), pd.Timestamp(CALM_END_EXCLUSIVE), color="0.7", alpha=0.15)

    axis.set_title(
        "Hurricane Ike: ERA5-forced MOM6 compared with NOAA CORA v1.1\n"
        "Nearest wet/model nodes to Galveston Pier 21",
        fontsize=15,
        weight="bold",
        pad=12,
    )
    axis.set_ylabel("Water-level anomaly relative to 1–7 September mean (m)")
    axis.set_xlabel("UTC date in 2008")
    axis.xaxis.set_major_locator(mdates.DayLocator(interval=2))
    axis.xaxis.set_major_formatter(mdates.DateFormatter("%b %d"))
    axis.grid(True, color="0.87", linewidth=0.8)
    axis.legend(loc="upper left", frameon=True, framealpha=0.95)

    metrics = (
        f"Hourly comparison\n"
        f"RMSE: {rmse:.2f} m\n"
        f"Bias (MOM6 − CORA): {bias:+.2f} m\n"
        f"Correlation: {correlation:.2f}\n\n"
        f"Ike-window peaks\n"
        f"MOM6: {mom6_peak:.2f} m, {mom6_peak_time:%b %d %H:%M}\n"
        f"CORA: {cora_peak:.2f} m, {cora_peak_time:%b %d %H:%M}"
    )
    axis.text(
        0.985,
        0.97,
        metrics,
        transform=axis.transAxes,
        ha="right",
        va="top",
        fontsize=9.5,
        bbox={"boxstyle": "round,pad=0.5", "facecolor": "white", "edgecolor": "0.75", "alpha": 0.94},
    )

    figure.text(
        0.01,
        0.012,
        "CORA is an observation-assimilating ADCIRC–SWAN reanalysis, not an independent observation. "
        "Both series are referenced to their own 1–7 September means to avoid datum mismatch.",
        fontsize=8.5,
        color="0.3",
    )
    figure.tight_layout(rect=(0, 0.045, 1, 1))
    png_path = OUTPUT_DIR / "MOM6_vs_CORA_Ike_Pier21.png"
    figure.savefig(png_path, dpi=300, bbox_inches="tight", facecolor="white")
    plt.close(figure)

    summary = {
        "mom6_location": mom6_location,
        "cora_location": cora_location,
        "mom6_calm_reference_m": mom6_reference,
        "cora_calm_reference_m": cora_reference,
        "rmse_m": rmse,
        "bias_mom6_minus_cora_m": bias,
        "correlation": correlation,
        "mom6_peak_anomaly_m": mom6_peak,
        "mom6_peak_time_utc": str(mom6_peak_time),
        "cora_peak_anomaly_m": cora_peak,
        "cora_peak_time_utc": str(cora_peak_time),
        "figure": str(png_path),
        "csv": str(csv_path),
    }
    summary_path = OUTPUT_DIR / "MOM6_vs_CORA_Ike_Pier21_summary.json"
    pd.Series(summary).to_json(summary_path, indent=2)

    print(pd.Series(summary).to_string())
    print("Saved", png_path)
    print("Saved", csv_path)
    print("Saved", summary_path)


if __name__ == "__main__":
    main()
