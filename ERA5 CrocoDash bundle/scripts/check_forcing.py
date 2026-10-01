#!/usr/bin/env python3
"""Validate prepared ERA5 coverage and variables.

Author: Faezeh Maghsoodifar, The University of Alabama, 2026.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd
import xarray as xr


EXPECTED = {"precip", "lwdn", "swdn", "q2m", "msl", "t2m", "u10", "v10"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path)
    parser.add_argument("--start", required=True)
    parser.add_argument("--end", required=True)
    args = parser.parse_args()

    requested_start = pd.Timestamp(args.start)
    requested_end = pd.Timestamp(args.end)

    with xr.open_dataset(args.file) as dataset:
        if "time" not in dataset.coords:
            raise SystemExit("FAIL: no time coordinate")
        forcing_start = pd.Timestamp(dataset.time.values[0])
        forcing_end = pd.Timestamp(dataset.time.values[-1])
        variables = set(dataset.data_vars)

    missing = EXPECTED - variables
    print("Author: Faezeh Maghsoodifar")
    print("File:", args.file)
    print("Coverage:", forcing_start, "to", forcing_end)
    print("Requested:", requested_start, "to", requested_end)
    print("Missing variables:", sorted(missing) or "none")

    if forcing_start > requested_start:
        raise SystemExit("FAIL: forcing starts after the requested period")
    if forcing_end < requested_end:
        raise SystemExit("FAIL: forcing ends before the requested period")
    if missing:
        raise SystemExit("FAIL: required prepared variables are missing")

    print("PASS: forcing covers the requested period and contains all eight fields.")


if __name__ == "__main__":
    main()
