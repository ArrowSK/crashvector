#!/usr/bin/env python3
"""Verify exact pinned Godot 4.4.1 build assets before extraction or execution.

SHA-512 values are from the official godotengine/godot-builds repository,
releases/godot-4.4.1-stable.json (recorded as fixed source-controlled values).
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

GODOT_4_4_1_SHA512 = {
    "Godot_v4.4.1-stable_macos.universal.zip": (
        "e72933ed15db495a29c918b27adc83596b6a4dc59ec72c927e1591333df14f"
        "0eb57c515a94f9f5a0ed8a13053d55f6aedf56f2a2d828add2ef3f79c698db714b"
    ),
    "Godot_v4.4.1-stable_linux.x86_64.zip": (
        "ef4e76880a514257175544952c61191106fdef3095b909bafed9fcbeb230c3e553"
        "3920a0f3012882dd4bbde83028a67549825794e2d2c3cf76eba7918b71370e"
    ),
    "Godot_v4.4.1-stable_export_templates.tpz": (
        "8f461c7d6e91a0fbabfc95b1e4ca70ff1732c6f2920956a16b086ec2a85b5f7"
        "e238baf4dbce60dcc5630fae3bcb9a1fa2ae2027b92cb495c02d082705715e441"
    ),
}


def digest_file(path: Path) -> str:
    digest = hashlib.sha512()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(asset: Path, asset_name: str) -> None:
    expected = GODOT_4_4_1_SHA512.get(asset_name)
    if expected is None or len(expected) != 128:
        raise ValueError(f"Unapproved or incorrectly pinned Godot build-tool asset: {asset_name}")
    if digest_file(asset) != expected:
        raise ValueError(f"Godot build-tool SHA-512 mismatch: {asset_name}")
    print(f"Verified pinned Godot build-tool SHA-512: {asset_name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", required=True, type=Path)
    parser.add_argument("--asset-name", required=True)
    args = parser.parse_args()
    verify(args.asset, args.asset_name)


if __name__ == "__main__":
    main()
