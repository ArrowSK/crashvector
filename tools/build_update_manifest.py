#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def package_entry(path: Path, platform: str, architecture: str) -> dict[str, object]:
    if not path.is_file():
        raise SystemExit(f"Missing package: {path}")
    return {
        "filename": path.name,
        "platform": platform,
        "architecture": architecture,
        "sha256": sha256_file(path),
        "size": path.stat().st_size,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--macos", required=True, type=Path)
    parser.add_argument("--windows", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if args.tag != f"v{args.version}":
        raise SystemExit("Release tag must exactly match v<version>")

    manifest = {
        "schema_version": 1,
        "version": args.version,
        "release_tag": args.tag,
        "packages": [
            package_entry(args.macos, "macos", "universal"),
            package_entry(args.windows, "windows", "x86_64"),
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(args.output)


if __name__ == "__main__":
    main()
