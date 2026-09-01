# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ScenarioStore
extends RefCounted

static func normalise_save_path(path: String) -> String:
	if path.to_lower().ends_with(".crashvector.json"):
		return path
	return path + ".crashvector.json"

static func save_to_path(config: ScenarioConfig, path: String) -> Error:
	if config == null:
		return ERR_INVALID_PARAMETER
	var final_path := normalise_save_path(path)
	var file := FileAccess.open(final_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(config.to_json(true))
	file.close()
	return OK

static func load_from_path(path: String) -> Dictionary:
	var result := {"scenario": null, "error": ""}
	if not FileAccess.file_exists(path):
		result["error"] = "Scenario file does not exist"
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["error"] = "Could not open scenario file"
		return result
	var config := ScenarioConfig.from_json(file.get_as_text())
	file.close()
	if config == null:
		result["error"] = "Scenario file is not valid CrashVector JSON"
		return result
	var validation := config.validation_errors()
	if not validation.is_empty():
		result["error"] = "; ".join(validation)
		return result
	result["scenario"] = config
	return result
