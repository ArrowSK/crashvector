# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name UpdateAssetSelector
extends RefCounted

static func select_update(
	releases: Array,
	current_version: String,
	platform_name: String = OS.get_name()
) -> Dictionary:
	var suffix := AppMetadata.platform_package_suffix(platform_name)
	if suffix.is_empty():
		return {}
	var allow_prerelease := VersionUtil.has_prerelease(current_version)
	var best: Dictionary = {}
	for value in releases:
		if not (value is Dictionary):
			continue
		var release: Dictionary = value
		if bool(release.get("draft", false)):
			continue
		if bool(release.get("prerelease", false)) and not allow_prerelease:
			continue
		var tag := String(release.get("tag_name", "")).strip_edges()
		if tag.is_empty() or not VersionUtil.is_newer(tag, current_version):
			continue
		var package := _find_asset_with_suffix(release.get("assets", []), suffix)
		if package.is_empty():
			continue
		var checksum_name := String(package.get("name", "")) + ".sha256"
		var checksum := _find_asset_named(release.get("assets", []), checksum_name)
		if checksum.is_empty():
			continue
		if not best.is_empty() and VersionUtil.compare(tag, String(best.get("version", ""))) <= 0:
			continue
		best = {
			"available": true,
			"version": tag.trim_prefix("v"),
			"tag": tag,
			"package_name": String(package.get("name", "")),
			"package_url": String(package.get("browser_download_url", "")),
			"checksum_name": checksum_name,
			"checksum_url": String(checksum.get("browser_download_url", "")),
			"release_url": String(release.get("html_url", AppMetadata.REPOSITORY_URL + "/releases")),
			"notes": String(release.get("body", "")),
			"prerelease": bool(release.get("prerelease", false)),
		}
	return best

static func parse_checksum_text(text: String) -> String:
	var clean := text.strip_edges()
	if clean.is_empty():
		return ""
	var first_line := clean.split("\n", false, 1)[0].strip_edges()
	var token := first_line.split(" ", false, 1)[0].strip_edges().to_lower()
	if token.length() != 64:
		return ""
	for character in token:
		if "0123456789abcdef".find(String(character).to_lower()) < 0:
			return ""
	return token

static func _find_asset_with_suffix(assets: Variant, suffix: String) -> Dictionary:
	if not (assets is Array):
		return {}
	for value in assets:
		if value is Dictionary:
			var asset: Dictionary = value
			if String(asset.get("name", "")).ends_with(suffix):
				return asset
	return {}

static func _find_asset_named(assets: Variant, wanted_name: String) -> Dictionary:
	if not (assets is Array):
		return {}
	for value in assets:
		if value is Dictionary:
			var asset: Dictionary = value
			if String(asset.get("name", "")) == wanted_name:
				return asset
	return {}
