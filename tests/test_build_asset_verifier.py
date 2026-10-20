"""Offline regression tests for fail-closed third-party build-asset verification."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.verify_build_asset import GODOT_4_4_1_SHA512, verify


class BuildAssetVerifierTests(unittest.TestCase):
    def test_expected_godot_downloads_are_pinned(self):
        self.assertEqual(len(GODOT_4_4_1_SHA512), 3)
        for asset_name, checksum in GODOT_4_4_1_SHA512.items():
            self.assertIn("4.4.1-stable", asset_name)
            self.assertEqual(len(checksum), 128)
            self.assertTrue(all(character in "0123456789abcdef" for character in checksum))

    def test_matching_archive_hash_is_accepted(self):
        name = "Godot_v4.4.1-stable_linux.x86_64.zip"
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "fixture.zip"
            path.write_bytes(b"verified-godot-build-fixture")
            checksum = hashlib.sha512(path.read_bytes()).hexdigest()
            with patch.dict(GODOT_4_4_1_SHA512, {name: checksum}):
                verify(path, name)

    def test_changed_archive_is_rejected(self):
        name = "Godot_v4.4.1-stable_linux.x86_64.zip"
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "fixture.zip"
            path.write_bytes(b"unmodified")
            checksum = hashlib.sha512(path.read_bytes()).hexdigest()
            path.write_bytes(b"modified")
            with patch.dict(GODOT_4_4_1_SHA512, {name: checksum}):
                with self.assertRaisesRegex(ValueError, "SHA-512 mismatch"):
                    verify(path, name)

    def test_unknown_tool_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "unapproved.exe"
            path.write_bytes(b"some-tool")
            with self.assertRaisesRegex(ValueError, "Unapproved"):
                verify(path, "unapproved.exe")


if __name__ == "__main__":
    unittest.main()
