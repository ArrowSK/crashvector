# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_test_canonical_version()
	_test_semantic_versions()
	_test_release_selection()
	_test_manifest_and_package_selection()
	_test_sha256_gate()
	if failures.is_empty():
		print("CrashVector M9 updater/version tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_canonical_version() -> void:
	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	_expect(version == "0.8.0-beta.1", "Canonical application version should be 0.8.0-beta.1")
	_expect(SemanticVersion.parse(version).valid, "Canonical application version must be valid semantic version")

func _test_semantic_versions() -> void:
	_expect(SemanticVersion.compare_strings("0.1.0-beta.2", "0.1.0-beta.1") > 0, "beta.2 should be newer than beta.1")
	_expect(SemanticVersion.compare_strings("0.1.0-beta.11", "0.1.0-beta.2") > 0, "numeric prerelease identifiers should compare numerically")
	_expect(SemanticVersion.compare_strings("0.1.0", "0.1.0-beta.9") > 0, "stable should be newer than prerelease at same core version")
	_expect(SemanticVersion.should_offer("0.1.0-beta.1", "0.1.0-beta.2"), "beta should accept a later beta")
	_expect(SemanticVersion.should_offer("0.1.0-beta.1", "0.1.0"), "beta should accept stable")
	_expect(SemanticVersion.should_offer("0.4.0-beta.1", "0.5.0-beta.1"), "M12 beta should accept the M13 progressive-failure beta")
	_expect(SemanticVersion.should_offer("0.6.0-beta.1", "0.7.0-beta.1"), "M14 beta should accept the combined M15/M16 beta")
	_expect(SemanticVersion.should_offer("0.7.0-beta.1", "0.7.0-beta.2"), "M16 beta.1 should accept the M16.1 corrective beta")
	_expect(SemanticVersion.should_offer("0.7.0-beta.2", "0.8.0-beta.1"), "M16.1 beta should accept the M17/M18 beta")
	_expect(not SemanticVersion.should_offer("0.1.0", "0.2.0-beta.1"), "stable channel should not silently move to prerelease")

func _test_release_selection() -> void:
	var releases: Array = [
		{"tag_name": "v0.1.0-beta.2", "draft": false, "prerelease": true},
		{"tag_name": "v0.1.0-beta.4", "draft": true, "prerelease": true},
		{"tag_name": "v0.1.0-beta.3", "draft": false, "prerelease": true},
	]
	var best := CrashVectorUpdateService.choose_best_release("0.1.0-beta.1", releases)
	_expect(String(best.get("tag_name", "")) == "v0.1.0-beta.3", "Updater should choose highest non-draft compatible release")

func _test_manifest_and_package_selection() -> void:
	var manifest := {
		"schema_version": 1,
		"version": "0.1.0-beta.2",
		"release_tag": "v0.1.0-beta.2",
		"packages": [
			{
				"filename": "CrashVector-0.1.0-beta.2-macOS-universal.dmg",
				"platform": "macos",
				"architecture": "universal",
				"sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
				"size": 100,
			},
			{
				"filename": "CrashVector-0.1.0-beta.2-Windows-x64-Setup.exe",
				"platform": "windows",
				"architecture": "x86_64",
				"sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
				"size": 200,
			},
		],
	}
	_expect(CrashVectorUpdateService.validate_manifest(manifest, "0.1.0-beta.2").is_empty(), "Valid update manifest should pass")
	var mac := CrashVectorUpdateService.select_platform_package(manifest, "macOS")
	var windows := CrashVectorUpdateService.select_platform_package(manifest, "Windows")
	_expect(String(mac.get("platform", "")) == "macos", "macOS updater package selection failed")
	_expect(String(windows.get("platform", "")) == "windows", "Windows updater package selection failed")
	var bad_manifest := manifest.duplicate(true)
	bad_manifest["version"] = "0.1.0-beta.3"
	_expect(not CrashVectorUpdateService.validate_manifest(bad_manifest, "0.1.0-beta.2").is_empty(), "Manifest/tag mismatch must be rejected")

func _test_sha256_gate() -> void:
	var path := "user://m9_sha256_test.bin"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not create SHA-256 test file")
		return
	file.store_string("abc")
	file.close()
	var expected := "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	_expect(CrashVectorUpdateService.verify_file_sha256(path, expected), "Correct SHA-256 should pass")
	_expect(not CrashVectorUpdateService.verify_file_sha256(path, "0000000000000000000000000000000000000000000000000000000000000000"), "Hash mismatch must block installation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
