"""Render the interactive SFINCS city map as a looping 3-D camera-orbit GIF."""

from __future__ import annotations

import argparse
import functools
import http.server
import os
from pathlib import Path
import socketserver
import subprocess
import tempfile
import threading
import time
from urllib.parse import urlencode
import urllib.request

from PIL import Image


def find_edge() -> Path:
    candidates = [
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "Microsoft/Edge/Application/msedge.exe",
        Path(os.environ.get("PROGRAMFILES", "")) / "Microsoft/Edge/Application/msedge.exe",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError("Microsoft Edge was not found; pass --edge explicitly")


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, _format: str, *args: object) -> None:
        return


def render_gif(
    edge: Path,
    repository: Path,
    output: Path,
    frame_count: int,
    duration_ms: int,
) -> None:
    handler = functools.partial(QuietHandler, directory=str(repository))
    with socketserver.TCPServer(("127.0.0.1", 0), handler) as server:
        port = server.server_address[1]
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=10).close()

        frames: list[Image.Image] = []
        with tempfile.TemporaryDirectory(prefix="sfincs-3d-gif-", ignore_cleanup_errors=True) as temp:
            temp_path = Path(temp)
            profile = temp_path / "edge-profile"

            for index in range(frame_count):
                screenshot = temp_path / f"frame-{index:03d}.png"
                query = urlencode({"capture": 1, "frame": index, "frames": frame_count})
                url = (
                    f"http://127.0.0.1:{port}/ike-mom6-sfincs/interactive/"
                    f"sfincs_3d_city.html?{query}"
                )
                command = [
                    str(edge),
                    "--headless=new",
                    "--no-first-run",
                    "--disable-extensions",
                    "--disable-component-update",
                    "--hide-scrollbars",
                    "--enable-webgl",
                    "--use-angle=swiftshader",
                    "--window-size=1280,720",
                    "--virtual-time-budget=15000",
                    f"--user-data-dir={profile}",
                    f"--screenshot={screenshot}",
                    url,
                ]
                creation_flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
                subprocess.run(
                    command,
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    creationflags=creation_flags,
                )
                frame: Image.Image | None = None
                for _ in range(150):
                    try:
                        if screenshot.stat().st_size > 0:
                            with Image.open(screenshot) as image:
                                image.load()
                                frame = image.convert("RGB").resize(
                                    (960, 540), Image.Resampling.LANCZOS
                                )
                            break
                    except (FileNotFoundError, PermissionError, OSError):
                        pass
                    time.sleep(0.1)
                if frame is None:
                    raise RuntimeError(f"Browser did not finish {screenshot}")

                frames.append(frame.copy())
                print(f"Rendered frame {index + 1}/{frame_count}", flush=True)

        server.shutdown()

    output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        output,
        format="GIF",
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
        disposal=1,
    )
    print(f"Created {output} ({output.stat().st_size / 1024 / 1024:.2f} MiB)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--edge", type=Path, default=None, help="Path to msedge.exe")
    parser.add_argument("--frames", type=int, default=24, help="Number of orbit frames")
    parser.add_argument("--duration-ms", type=int, default=140, help="Duration per GIF frame")
    parser.add_argument("--output", type=Path, default=None, help="Output GIF path")
    args = parser.parse_args()

    repository = Path(__file__).resolve().parents[2]
    output = args.output or repository / "ike-mom6-sfincs/figures/sfincs_3d_galveston_animation.gif"
    edge = args.edge.resolve() if args.edge else find_edge()
    render_gif(edge, repository, output.resolve(), args.frames, args.duration_ms)


if __name__ == "__main__":
    main()
