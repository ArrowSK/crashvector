#!/usr/bin/env python3
from base64 import b64decode
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "crashvector-icon-source.b64"
TARGET = ROOT / "assets" / "branding" / "crashvector-icon.webp"

if SOURCE.exists():
    payload = b64decode(SOURCE.read_text(encoding="ascii").strip(), validate=True)
    if not payload.startswith(b"RIFF") or payload[8:12] != b"WEBP":
        raise SystemExit("Decoded branding source is not a WebP image")
    TARGET.write_bytes(payload)
    print(f"Materialized {TARGET.relative_to(ROOT)} ({len(payload)} bytes)")
else:
    print("No encoded branding source present; nothing to materialize")
