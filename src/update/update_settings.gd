# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name UpdateSettings
extends RefCounted

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "updates"

var auto_check: bool = true
var last_check_unix: int = 0

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	auto_check = bool(config.get_value(SECTION, "auto_check", true))
	last_check_unix = int(config.get_value(SECTION, "last_check_unix", 0))

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, "auto_check", auto_check)
	config.set_value(SECTION, "last_check_unix", last_check_unix)
	return config.save(SETTINGS_PATH)

func should_auto_check(now_unix: int = int(Time.get_unix_time_from_system())) -> bool:
	if not auto_check:
		return false
	if last_check_unix <= 0:
		return true
	return now_unix - last_check_unix >= AppMetadata.UPDATE_CHECK_INTERVAL_S
