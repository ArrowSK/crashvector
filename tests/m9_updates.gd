# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []

	_expect(VersionUtil.compare("0.1.0-beta.1", "0.1.0-beta.2") < 0, "beta.1 must sort before beta.2", failures)
	_expect(VersionUtil.compare("0.1.0-beta.2", "0.1.0") < 0, "prerelease must sort before stable", failures)
	_expect(VersionUtil.compare("v1.2.3", "1.2.3") == 0, "v prefix should be ignored", failures)
	_expect(VersionUtil.compare("1.10.0", "1.9.9") > 0, "numeric semver components must compare numerically", failures)

	var releases: Array = [
		_release("v0.1.0-beta.2", true),
		_release("v0.1.0", false),
	]
	var beta_pick := UpdateAssetSelector.select_update(releases, "0.1.0-beta.1", "macOS")
	_expect(String(beta_pick.get("version", "")) == "0.1.0", "beta builds should select the highest newer compatible release", failures)
	_expect(String(beta_pick.get("package_name", "")).ends_with("-macOS-universal.dmg"), "macOS package selection is wrong", failures)

	var stable_pick := UpdateAssetSelector.select_update([_release("v0.2.0-beta.1", true)], "0.1.0", "Windows")
	_expect(stable_pick.is_empty(), "stable builds must not opt into prerelease packages", failures)

	var checksum := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  CrashVector.dmg\n"
	_expect(UpdateAssetSelector.parse_checksum_text(checksum).length() == 64, "valid SHA-256 sidecar was rejected", failures)
	_expect(UpdateAssetSelector.parse_checksum_text("not-a-checksum").is_empty(), "invalid checksum text was accepted", failures)

	var version_file := FileAccess.get_file_as_string("res://VERSION").strip_edges()
	_expect(version_file == AppMetadata.VERSION, "VERSION file and AppMetadata.VERSION differ", failures)
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(presets.contains(AppMetadata.VERSION), "export_presets.cfg does not carry the app version", failures)

	if failures.is_empty():
		print("CrashVector M9 update/distribution tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _release(tag: String, prerelease: bool) -> Dictionary:
	var version := tag.trim_prefix("v")
	return {
		"tag_name": tag,
		"draft": false,
		"prerelease": prerelease,
		"html_url": "https://github.com/ArrowSK/crashvector/releases/tag/%s" % tag,
		"body": "Release notes",
		"assets": [
			{
				"name": "CrashVector-%s-macOS-universal.dmg" % version,
				"browser_download_url": "https://example.invalid/mac.dmg",
			},
			{
				"name": "CrashVector-%s-macOS-universal.dmg.sha256" % version,
				"browser_download_url": "https://example.invalid/mac.sha256",
			},
			{
				"name": "CrashVector-%s-Windows-x64-Setup.exe" % version,
				"browser_download_url": "https://example.invalid/windows.exe",
			},
			{
				"name": "CrashVector-%s-Windows-x64-Setup.exe.sha256" % version,
				"browser_download_url": "https://example.invalid/windows.sha256",
			},
		],
	}

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
