# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name UpdateService
extends Node

signal check_completed(result: Dictionary)
signal download_progress(downloaded_bytes: int, total_bytes: int)
signal download_completed(installer_path: String)
signal update_error(message: String)

var selected_update: Dictionary = {}
var installer_path: String = ""
var expected_sha256: String = ""
var downloading: bool = false

var _release_request: HTTPRequest
var _checksum_request: HTTPRequest
var _package_request: HTTPRequest

func _ready() -> void:
	_release_request = HTTPRequest.new()
	_release_request.name = "ReleaseRequest"
	add_child(_release_request)
	_release_request.request_completed.connect(_on_release_request_completed)

	_checksum_request = HTTPRequest.new()
	_checksum_request.name = "ChecksumRequest"
	add_child(_checksum_request)
	_checksum_request.request_completed.connect(_on_checksum_request_completed)

	_package_request = HTTPRequest.new()
	_package_request.name = "PackageRequest"
	add_child(_package_request)
	_package_request.request_completed.connect(_on_package_request_completed)

func _process(_delta: float) -> void:
	if downloading and _package_request != null:
		download_progress.emit(_package_request.get_downloaded_bytes(), _package_request.get_body_size())

func check_for_updates() -> void:
	if _release_request == null:
		update_error.emit("Update service is not ready.")
		return
	if _release_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28",
		"User-Agent: CrashVector/%s" % AppMetadata.VERSION,
	])
	var error := _release_request.request(AppMetadata.RELEASES_API_URL, headers)
	if error != OK:
		update_error.emit("Could not start the update check (%s)." % error_string(error))

func download_selected_update() -> void:
	if selected_update.is_empty():
		update_error.emit("No update is selected.")
		return
	var checksum_url := String(selected_update.get("checksum_url", ""))
	if checksum_url.is_empty():
		update_error.emit("The release is missing its checksum file.")
		return
	var error := _checksum_request.request(checksum_url, PackedStringArray(["User-Agent: CrashVector/%s" % AppMetadata.VERSION]))
	if error != OK:
		update_error.emit("Could not download the update checksum (%s)." % error_string(error))

func launch_installer_and_quit() -> void:
	if installer_path.is_empty() or not FileAccess.file_exists(installer_path):
		update_error.emit("The downloaded installer could not be found.")
		return
	var absolute_path := ProjectSettings.globalize_path(installer_path)
	var result := OS.shell_open(absolute_path)
	if result != OK:
		update_error.emit("Could not open the system installer (%s)." % error_string(result))
		return
	get_tree().quit()

func _on_release_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		update_error.emit("Update check failed (HTTP %d)." % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Array):
		update_error.emit("GitHub returned an unexpected update response.")
		return
	selected_update = UpdateAssetSelector.select_update(parsed, AppMetadata.VERSION, OS.get_name())
	if selected_update.is_empty():
		check_completed.emit({
			"available": false,
			"version": AppMetadata.VERSION,
		})
		return
	check_completed.emit(selected_update)

func _on_checksum_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		update_error.emit("Could not retrieve the release checksum (HTTP %d)." % response_code)
		return
	expected_sha256 = UpdateAssetSelector.parse_checksum_text(body.get_string_from_utf8())
	if expected_sha256.is_empty():
		update_error.emit("The release checksum is invalid.")
		return
	var directory := "user://updates"
	var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		update_error.emit("Could not create the update download folder.")
		return
	var package_name := String(selected_update.get("package_name", "")).get_file()
	if package_name.is_empty():
		update_error.emit("The release package name is invalid.")
		return
	installer_path = "%s/%s" % [directory, package_name]
	var temp_path := installer_path + ".download"
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	_package_request.download_file = temp_path
	downloading = true
	var error := _package_request.request(
		String(selected_update.get("package_url", "")),
		PackedStringArray(["User-Agent: CrashVector/%s" % AppMetadata.VERSION])
	)
	if error != OK:
		downloading = false
		update_error.emit("Could not start the installer download (%s)." % error_string(error))

func _on_package_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	downloading = false
	var temp_path := installer_path + ".download"
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_cleanup_temp(temp_path)
		update_error.emit("Installer download failed (HTTP %d)." % response_code)
		return
	var actual_sha256 := _file_sha256(temp_path)
	if actual_sha256.is_empty() or actual_sha256 != expected_sha256:
		_cleanup_temp(temp_path)
		update_error.emit("Installer checksum verification failed. The download was deleted.")
		return
	if FileAccess.file_exists(installer_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(installer_path))
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(installer_path)
	)
	if rename_error != OK:
		_cleanup_temp(temp_path)
		update_error.emit("Could not finalize the downloaded installer.")
		return
	download_completed.emit(installer_path)

func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	while file.get_position() < file.get_length():
		context.update(file.get_buffer(1024 * 1024))
	return context.finish().hex_encode()

func _cleanup_temp(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
