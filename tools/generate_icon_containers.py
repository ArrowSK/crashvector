#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build" / "icons" / "CrashVector-1024.png"
ICO = ROOT / "build" / "icons" / "CrashVector.ico"
ICNS = ROOT / "build" / "icons" / "CrashVector.icns"
WINDOWS_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
MAC_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    if not SOURCE.exists():
        fail(f"Missing rendered master icon: {SOURCE}")
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != (1024, 1024):
        fail(f"Rendered master must be 1024x1024, got {image.size}")

    ICO.parent.mkdir(parents=True, exist_ok=True)
    image.save(ICO, format="ICO", sizes=WINDOWS_SIZES)

    mac_images = [image.resize((size, size), Image.Resampling.LANCZOS) for size in MAC_SIZES[:-1]]
    image.save(ICNS, format="ICNS", append_images=mac_images)

    ico_check = Image.open(ICO)
    available = set(ico_check.ico.sizes())
    missing = [size for size in WINDOWS_SIZES if size not in available]
    if missing:
        fail(f"Generated ICO is missing native sizes: {missing}; available={sorted(available)}")

    icns_check = Image.open(ICNS)
    icns_sizes = icns_check.info.get("sizes", [])
    if not icns_sizes:
        fail("Generated ICNS contains no readable icon sizes")
    if max(width * scale for width, _height, scale in icns_sizes) < 1024:
        fail(f"Generated ICNS does not contain a 1024 px representation: {icns_sizes}")

    print(f"Generated {ICO.relative_to(ROOT)} with sizes {sorted(available)}")
    print(f"Generated {ICNS.relative_to(ROOT)} with representations {icns_sizes}")


if __name__ == "__main__":
    main()
