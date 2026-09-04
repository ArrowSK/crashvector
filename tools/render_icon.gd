# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const SOURCE := "res://assets/branding/crashvector-icon.svg"
const OUTPUT := "res://build/icons/CrashVector-1024.png"

func _initialize() -> void:
	var svg := FileAccess.get_file_as_string(SOURCE)
	if svg.is_empty():
		push_error("Could not read CrashVector SVG master icon")
		quit(1)
		return
	var image := Image.new()
	var error := image.load_svg_from_string(svg, 1.0)
	if error != OK:
		push_error("Could not render CrashVector SVG master: %s" % error_string(error))
		quit(1)
		return
	if image.get_width() != 1024 or image.get_height() != 1024:
		image.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var output_dir := ProjectSettings.globalize_path("res://build/icons")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Could not create icon output directory")
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(OUTPUT)
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save rendered CrashVector icon: %s" % error_string(save_error))
		quit(1)
		return
	print("Rendered deterministic 1024 px CrashVector icon to %s" % OUTPUT)
	quit(0)
