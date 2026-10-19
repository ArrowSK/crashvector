#!/usr/bin/env python3
"""Verify pinned Godot release downloads before extraction or execution.

The SHA-512 for each archive comes from Godot's official SHA512-SUMS.txt, and
that checksum file itself is pinned here by its SHA-256 digest. Never trust an
unverified checksum file downloaded alongside a potentially replaced asset.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re

# Pinned to the official Godot 4.4.1-stable release checksum manifest.
# This placeholder intentionally fails closed until the exact digest is checked.
GODOT_4_4_1_SUMS_SHA256 = "PENDING_OFFICIAL_MANIFEST_SHA256"
ALLOWED_ASSETS = {
    "Godot_v4.4.1-stable_macos.universal.zip",
    "Godot_v4.4.1-stable_linux.x86_64.zip",
    "Godot_v4.4.1-stable_export_templates.tpz",
}
SUM_LINE = re.compile(r"^([a-fA-F0-9]{128})\s+\*?(.+?)\s*$")


def digest_file(path: Path, algorithm: str) -> str:
    digest = hashlib.new(algorithm)
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(asset: Path, asset_name: str, manifest: Path) -> None:
    if asset_name not in ALLOWED_ASSETS:
        raise ValueError(f"Unapproved build-tool asset: {asset_name}")
    if not re.fullmatch(r"[a-f0-9]{64}", GODOT_4_4_1_SUMS_SHA256):
        raise ValueError("Pinned official checksum manifest SHA-256 is not configured")
    if digest_file(manifest, "sha256") != GODOT_4_4_1_SUMS_SHA256:
        raise ValueError("Godot 4.4.1 official checksum manifest SHA-256 mismatch")
    matches = []
    for line in manifest.read_text(encoding="utf-8").splitlines():
        match = SUM_LINE.fullmatch(line)
        if match and Path(match.group(2)).name == asset_name:
            matches.append(match.group(1).lower())
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one official SHA-512 record for {asset_name}; found {len(matches)}")
    actual = digest_file(asset, "sha512")
    if actual != matches[0]:
        raise ValueError(f"Godot build-tool asset SHA-512 mismatch: {asset_name}")
    print(f"Verified Godot build-tool SHA-512: {asset_name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", required=True, type=Path)
    parser.add_argument("--asset-name", required=True)
    parser.add_argument("--checksum-manifest", required=True, type=Path)
    args = parser.parse_args()
    verify(args.asset, args.asset_name, args.checksum_manifest)


if __name__ == "__main__":
    main()
