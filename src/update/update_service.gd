# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CrashVectorUpdateService
extends Node

signal check_finished(result: Dictionary)
signal download_finished(result: Dictionary)
signal download_progress(received_bytes: int, total_bytes: int)
signal status_changed(message: String)

const RELEASES_URL := "https://api.github.com/repos/ArrowSK/crashvector/releases?per_page=30"
const SETTINGS_PATH := "user://crashvector_settings.cfg"
const UPDATE_DIR := "user://updates"
const AUTO_CHECK_INTERVAL_SECONDS := 86400
const MANIFEST_ASSET_NAME := "update-manifest.json"

var installed_version: String = ""
var automatic_checks_enabled: bool = true
var last_check_unix: int = 0
var selected_release: Dictionary = {}
var selected_manifest: Dictionary = {}
var selected_package: Dictionary = {}
var verified_download_path: String = ""

var release_request: HTTPRequest
var manifest_request: HTTPRequest
var package_request: HTTPRequest
var _check_in_progress := false
var _download_in_progress := false
var _manifest_release: Dictionary = {}
var _download_target_path := ""

func _ready() -> void:
	installed_version = String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	_load_settings()
	release_request = HTTPRequest.new()
	release_request.name = "ReleaseRequest"
	add_child(release_request)
	release_request.request_completed.connect(_on_release_request_completed)
	manifest_request = HTTPRequest.new()
	manifest_request.name = "ManifestRequest"
	add_child(manifest_request)
	manifest_request.request_completed.connect(_on_manifest_request_completed)
	package_request = HTTPRequest.new()
	package_request.name = "PackageRequest"
	add_child(package_request)
	package_request.request_completed.connect(_on_package_request_completed)
	set_process(false)
	if automatic_checks_enabled and not _is_headless_runtime():
		call_deferred("_maybe_run_automatic_check")

func _process(_delta: float) -> void:
	if not _download_in_progress or package_request == null:
		return
	download_progress.emit(package_request.get_downloaded_bytes(), package_request.get_body_size())

func set_automatic_checks_enabled(value: bool) -> void:
	automatic_checks_enabled = value
	_save_settings()

func check_for_updates(manual: bool = true) -> void:
	if _check_in_progress:
		return
	if _is_headless_runtime() and not manual:
		return
	_check_in_progress = true
	selected_release.clear()
	selected_manifest.clear()
	selected_package.clear()
	verified_download_path = ""
	status_changed.emit("Checking GitHub Releases…")
	var error := release_request.request(RELEASES_URL, _github_headers())
	if error != OK:
		_finish_check(_error_result("Could not start update check (%s)." % error_string(error)))

func download_selected_update() -> void:
	if _download_in_progress:
		return
	if selected_package.is_empty():
		download_finished.emit(_error_result("No compatible update package is selected."))
		return
	var filename := String(selected_package.get("filename", ""))
	var url := String(selected_package.get("download_url", ""))
	if not _safe_filename(filename) or url.is_empty():
		download_finished.emit(_error_result("Update package metadata is invalid."))
		return
	var absolute_dir := ProjectSettings.globalize_path(UPDATE_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		download_finished.emit(_error_result("Could not create the update download folder."))
		return
	_download_target_path = UPDATE_DIR.path_join(filename)
	if FileAccess.file_exists(_download_target_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_download_target_path))
	package_request.download_file = _download_target_path
	_download_in_progress = true
	set_process(true)
	status_changed.emit("Downloading %s…" % filename)
	var error := package_request.request(url, _github_headers())
	if error != OK:
		_download_in_progress = false
		set_process(false)
		package_request.download_file = ""
		download_finished.emit(_error_result("Could not start update download (%s)." % error_string(error)))

func install_verified_update() -> Dictionary:
	if verified_download_path.is_empty() or not FileAccess.file_exists(verified_download_path):
		return _error_result("No verified update package is ready to install.")
	var global_path := ProjectSettings.globalize_path(verified_download_path)
	var os_name := OS.get_name()
	var process_id := -1
	if os_name == "macOS":
		process_id = OS.create_process("/usr/bin/open", [global_path])
	elif os_name == "Windows":
		process_id = OS.create_process(global_path, [])
	else:
		return _error_result("Automatic installation handoff is supported only on macOS and Windows.")
	if process_id < 0:
		return _error_result("The operating system could not open the verified installer.")
	status_changed.emit("Installer opened. CrashVector will close cleanly.")
	get_tree().quit()
	return {"ok": true, "process_id": process_id}

func _maybe_run_automatic_check() -> void:
	var now := int(Time.get_unix_time_from_system())
	if last_check_unix <= 0 or now - last_check_unix >= AUTO_CHECK_INTERVAL_SECONDS:
		check_for_updates(false)

func _on_release_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_finish_check(_error_result("Update check failed (HTTP %d)." % response_code))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Array):
		_finish_check(_error_result("GitHub returned an invalid releases response."))
		return
	var release := choose_best_release(installed_version, parsed as Array)
	if release.is_empty():
		_finish_check({"ok": true, "available": false, "installed_version": installed_version})
		return
	var manifest_url := _release_asset_url(release, MANIFEST_ASSET_NAME)
	if manifest_url.is_empty():
		_finish_check(_error_result("The release is missing %s." % MANIFEST_ASSET_NAME))
		return
	_manifest_release = release
	status_changed.emit("Update found. Verifying release manifest…")
	var error := manifest_request.request(manifest_url, _github_headers())
	if error != OK:
		_finish_check(_error_result("Could not download the update manifest (%s)." % error_string(error)))

func _on_manifest_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_finish_check(_error_result("Update manifest download failed (HTTP %d)." % response_code))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_finish_check(_error_result("The update manifest is not valid JSON."))
		return
	var manifest := parsed as Dictionary
	var release_version := _tag_version(String(_manifest_release.get("tag_name", "")))
	var validation_error := validate_manifest(manifest, release_version)
	if not validation_error.is_empty():
		_finish_check(_error_result(validation_error))
		return
	var package := select_platform_package(manifest, OS.get_name())
	if package.is_empty():
		_finish_check(_error_result("This release has no package for %s." % OS.get_name()))
		return
	var filename := String(package.get("filename", ""))
	var package_url := _release_asset_url(_manifest_release, filename)
	if package_url.is_empty():
		_finish_check(_error_result("The release package listed in the manifest is missing."))
		return
	package["download_url"] = package_url
	selected_release = _manifest_release.duplicate(true)
	selected_manifest = manifest.duplicate(true)
	selected_package = package.duplicate(true)
	var result_data := {
		"ok": true,
		"available": true,
		"installed_version": installed_version,
		"available_version": release_version,
		"release_name": String(selected_release.get("name", "CrashVector %s" % release_version)),
		"release_notes": String(selected_release.get("body", "")),
		"release_url": String(selected_release.get("html_url", "")),
		"package": selected_package.duplicate(true),
	}
	_finish_check(result_data)

func _on_package_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_download_in_progress = false
	set_process(false)
	package_request.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_remove_download_target()
		download_finished.emit(_error_result("Update download failed (HTTP %d)." % response_code))
		return
	var expected_sha := String(selected_package.get("sha256", "")).to_lower()
	if expected_sha.length() != 64 or not verify_file_sha256(_download_target_path, expected_sha):
		_remove_download_target()
		verified_download_path = ""
		status_changed.emit("Downloaded file failed SHA-256 verification.")
		download_finished.emit(_error_result("SHA-256 verification failed. Installation is blocked."))
		return
	verified_download_path = _download_target_path
	status_changed.emit("Update verified and ready to install.")
	download_finished.emit({
		"ok": true,
		"verified": true,
		"path": verified_download_path,
		"filename": String(selected_package.get("filename", "")),
	})

func _finish_check(result: Dictionary) -> void:
	_check_in_progress = false
	last_check_unix = int(Time.get_unix_time_from_system())
	_save_settings()
	if bool(result.get("ok", false)):
		status_changed.emit("Update available." if bool(result.get("available", false)) else "CrashVector is up to date.")
	else:
		status_changed.emit(String(result.get("error", "Update check failed.")))
	check_finished.emit(result)

func _remove_download_target() -> void:
	if _download_target_path.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(_download_target_path)
	if FileAccess.file_exists(_download_target_path):
		DirAccess.remove_absolute(absolute)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		automatic_checks_enabled = bool(config.get_value("updates", "automatic_checks", true))
		last_check_unix = int(config.get_value("updates", "last_check_unix", 0))

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("updates", "automatic_checks", automatic_checks_enabled)
	config.set_value("updates", "last_check_unix", last_check_unix)
	config.save(SETTINGS_PATH)

func _github_headers() -> PackedStringArray:
	return PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: CrashVector/%s" % installed_version,
		"X-GitHub-Api-Version: 2022-11-28",
	])

static func choose_best_release(installed: String, releases: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_version := ""
	for value in releases:
		if not (value is Dictionary):
			continue
		var release := value as Dictionary
		if bool(release.get("draft", false)):
			continue
		var candidate := _tag_version(String(release.get("tag_name", "")))
		if not SemanticVersion.should_offer(installed, candidate):
			continue
		if best.is_empty() or SemanticVersion.compare_strings(candidate, best_version) > 0:
			best = release.duplicate(true)
			best_version = candidate
	return best

static func validate_manifest(manifest: Dictionary, expected_version: String) -> String:
	if int(manifest.get("schema_version", 0)) != 1:
		return "Unsupported update-manifest schema."
	var version := String(manifest.get("version", ""))
	if version != expected_version or not SemanticVersion.parse(version).valid:
		return "Update manifest version does not match the GitHub release tag."
	var expected_tag := "v%s" % expected_version
	if String(manifest.get("release_tag", "")) != expected_tag:
		return "Update manifest release tag is inconsistent."
	var packages: Variant = manifest.get("packages", [])
	if not (packages is Array) or (packages as Array).is_empty():
		return "Update manifest contains no packages."
	for value in packages as Array:
		if not (value is Dictionary):
			return "Update manifest contains an invalid package entry."
		var package := value as Dictionary
		if not _safe_filename(String(package.get("filename", ""))):
			return "Update manifest contains an unsafe package filename."
		var sha := String(package.get("sha256", "")).to_lower()
		if sha.length() != 64 or not _is_hex(sha):
			return "Update manifest contains an invalid SHA-256 value."
		if int(package.get("size", 0)) <= 0:
			return "Update manifest contains an invalid package size."
	return ""

static func select_platform_package(manifest: Dictionary, os_name: String) -> Dictionary:
	var wanted_platform := ""
	if os_name == "macOS":
		wanted_platform = "macos"
	elif os_name == "Windows":
		wanted_platform = "windows"
	else:
		return {}
	var packages: Variant = manifest.get("packages", [])
	if not (packages is Array):
		return {}
	for value in packages as Array:
		if not (value is Dictionary):
			continue
		var package := value as Dictionary
		if String(package.get("platform", "")).to_lower() == wanted_platform:
			return package.duplicate(true)
	return {}

static func verify_file_sha256(path: String, expected_sha256: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return false
	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		hashing.update(file.get_buffer(mini(1024 * 1024, remaining)))
	var actual := hashing.finish().hex_encode().to_lower()
	return actual == expected_sha256.to_lower()

static func _release_asset_url(release: Dictionary, filename: String) -> String:
	var assets: Variant = release.get("assets", [])
	if not (assets is Array):
		return ""
	for value in assets as Array:
		if value is Dictionary and String((value as Dictionary).get("name", "")) == filename:
			return String((value as Dictionary).get("browser_download_url", ""))
	return ""

static func _tag_version(tag: String) -> String:
	var value := tag.strip_edges()
	return value.substr(1) if value.begins_with("v") else value

static func _safe_filename(filename: String) -> bool:
	return not filename.is_empty() and filename.get_file() == filename and not filename.contains("..") and not filename.contains("/") and not filename.contains("\\")

static func _is_hex(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		var numeric := code >= 48 and code <= 57
		var lower_hex := code >= 97 and code <= 102
		if not numeric and not lower_hex:
			return false
	return not value.is_empty()

static func _error_result(message: String) -> Dictionary:
	return {"ok": false, "available": false, "error": message}

static func _is_headless_runtime() -> bool:
	return DisplayServer.get_name() == "headless"
