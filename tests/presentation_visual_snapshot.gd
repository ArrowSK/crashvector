# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const OUTPUT_DIR := "res://build/presentation_visual_review"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var packed: PackedScene
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = VIEWPORT_SIZE
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_fail("Could not create presentation visual-review output directory: %d" % dir_error)
		return
	packed = load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load production scene for presentation snapshots")
		return

	for preset_id in PassengerCarCatalog.preset_ids():
		await _capture_pristine_views(preset_id)

	if failures.is_empty():
		print("CrashVector presentation acceptance snapshots captured in %s" % absolute_dir)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _capture_pristine_views(preset_id: StringName) -> void:
	var editor := packed.instantiate()
	root.add_child(editor)
	for _frame in range(12):
		await process_frame

	var selector := _find_named(editor, "M16VehicleSelector") as OptionButton
	if selector == null:
		failures.append("%s: production vehicle selector unavailable" % String(preset_id))
		editor.queue_free()
		await process_frame
		return
	if not _select_metadata(selector, preset_id):
		failures.append("%s: could not select passenger-car class" % String(preset_id))
		editor.queue_free()
		await process_frame
		return
	for _frame in range(10):
		await process_frame

	var visual := _find_named(editor, "M16PrimaryVehicleVisual") as M162VehicleVisual
	if visual == null or visual.kenney_skin == null or not visual.kenney_skin.active:
		failures.append("%s: Kenney presentation skin unavailable" % String(preset_id))
	else:
		if not visual.kenney_skin is KenneyVehiclePresentation3D:
			failures.append("%s: production scene is not using the wheel-aligned Kenney presentation adapter" % String(preset_id))
		if visual.kenney_skin.wheel_nodes.size() != 4:
			failures.append("%s: expected four Kenney presentation wheels" % String(preset_id))

	var stem := String(preset_id)
	editor.call("_frame_scenario")
	for _frame in range(4):
		await process_frame
	await _save_frame("%s_01_three_quarter.png" % stem)

	editor.call("_on_camera_side")
	for _frame in range(4):
		await process_frame
	await _save_frame("%s_02_side.png" % stem)

	editor.call("_on_camera_front")
	for _frame in range(4):
		await process_frame
	await _save_frame("%s_03_front.png" % stem)

	editor.queue_free()
	for _frame in range(3):
		await process_frame

func _save_frame(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("%s: rendered viewport image is empty" % file_name)
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		failures.append("%s: PNG save failed with error %d" % [file_name, error])

func _select_metadata(option: OptionButton, wanted: StringName) -> bool:
	for index in range(option.item_count):
		if StringName(String(option.get_item_metadata(index))) == wanted:
			option.select(index)
			option.item_selected.emit(index)
			return true
	return false

func _find_named(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
