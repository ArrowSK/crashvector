#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project.godot"
EXPORT_PRESETS = ROOT / "export_presets.cfg"
INNO_VERSION = ROOT / "packaging" / "windows" / "generated_version.iss"
BUILD_METADATA = ROOT / "build" / "version-metadata.json"
SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$")


def read_version() -> str:
    text = PROJECT.read_text(encoding="utf-8")
    match = re.search(r'^config/version="([^"]+)"\s*$', text, re.MULTILINE)
    if not match:
        raise SystemExit("project.godot has no application config/version")
    version = match.group(1)
    if not SEMVER_RE.fullmatch(version):
        raise SystemExit(f"Invalid semantic application version: {version}")
    return version


def derived_versions(version: str) -> dict[str, str | int]:
    match = SEMVER_RE.fullmatch(version)
    assert match is not None
    major, minor, patch = (int(match.group(i)) for i in (1, 2, 3))
    prerelease = match.group(4) or ""
    revision = 9000
    if prerelease:
        identifiers = prerelease.split(".")
        channel = identifiers[0].lower()
        sequence = int(identifiers[-1]) if identifiers[-1].isdigit() else 0
        base = {"alpha": 100, "beta": 1000, "rc": 2000}.get(channel, 500)
        revision = base + sequence
    windows_numeric = f"{major}.{minor}.{patch}.{revision}"
    mac_short = f"{major}.{minor}.{patch}"
    return {
        "version": version,
        "windows_numeric_version": windows_numeric,
        "mac_short_version": mac_short,
        "mac_build_version": revision,
        "is_prerelease": bool(prerelease),
    }


def write_export_presets(meta: dict[str, str | int]) -> None:
    content = f'''[preset.0]
name="macOS Universal"
platform="macOS"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*,tools/*,docs/*,examples/*,packaging/*"
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]
binary_format/architecture="universal"
application/bundle_identifier="com.arrowsk.crashvector"
application/icon="res://build/icons/CrashVector.icns"
application/short_version="{meta['mac_short_version']}"
application/version="{meta['mac_build_version']}"
application/copyright="Copyright (c) ArrowSK / CrashVector contributors"

[preset.1]
name="Windows x64"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*,tools/*,docs/*,examples/*,packaging/*"
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=false
binary_format/architecture="x86_64"
codesign/enable=false
application/modify_resources=false
application/icon="res://build/icons/CrashVector.ico"
application/company_name="ArrowSK"
application/product_name="CrashVector"
application/file_description="CrashVector educational 3D crash simulation"
application/file_version="{meta['windows_numeric_version']}"
application/product_version="{meta['windows_numeric_version']}"
application/copyright="Copyright (c) ArrowSK / CrashVector contributors"
'''
    EXPORT_PRESETS.write_text(content, encoding="utf-8")


def write_inno_version(meta: dict[str, str | int]) -> None:
    INNO_VERSION.parent.mkdir(parents=True, exist_ok=True)
    content = (
        f'#define MyAppVersion "{meta["version"]}"\n'
        f'#define MyAppNumericVersion "{meta["windows_numeric_version"]}"\n'
    )
    INNO_VERSION.write_text(content, encoding="utf-8")


def prepare() -> dict[str, str | int]:
    version = read_version()
    meta = derived_versions(version)
    write_export_presets(meta)
    write_inno_version(meta)
    BUILD_METADATA.parent.mkdir(parents=True, exist_ok=True)
    BUILD_METADATA.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    return meta


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--print-version", action="store_true")
    args = parser.parse_args()
    if args.print_version:
        print(read_version())
        return
    meta = prepare()
    print(json.dumps(meta, sort_keys=True))


if __name__ == "__main__":
    main()
