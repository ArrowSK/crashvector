# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const OUTPUT_DIR := "res://build/presentation_visual_review"
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var packed: PackedScene
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_fail("Could not create presentation visual-review output directory: %d" % dir_error)
		return
	packed = load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load production scene for presentation snapshots")
		return

	# All six production passenger-car classes are reviewed at the same three
	# desktop resolutions. This is intentionally a manual/release visual gate,
	# not a per-push CI workload.
	for viewport_size in VIEWPORT_SIZES:
		root.size = viewport_size
		for _frame in range(3):
			await process_frame
		for preset_id in PassengerCarCatalog.preset_ids():
			await _capture_pristine_views(preset_id, viewport_size)

	if failures.is_empty():
		print("CrashVector presentation acceptance snapshots captured in %s" % absolute_dir)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _capture_pristine_views(preset_id: StringName, viewport_size: Vector2i) -> void:
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
			failures.append("%s: production scene is not using the presentation adapter" % String(preset_id))
		else:
			var presentation := visual.kenney_skin as KenneyVehiclePresentation3D
			for wheel_offset in presentation.neutral_wheel_offsets:
				if wheel_offset.length() > KenneyVehiclePresentation3D.MAX_WHEEL_ALIGNMENT_OFFSET_M + 0.001:
					failures.append("%s: a presentation wheel drifted from its suspension anchor" % String(preset_id))
					break
		if not visual.kenney_skin.USE_ANCHORED_PROCEDURAL_WHEELS or not visual.kenney_skin.wheel_nodes.is_empty():
			failures.append("%s: imported wheel scene bypassed the anchor-driven production rig" % String(preset_id))
		if String(visual.kenney_skin.get_meta("presentation_wheel_mode", "")) != "structural-anchor":
			failures.append("%s: structural-anchor wheel presentation metadata is missing" % String(preset_id))
		for index in range(visual.wheel_tires.size()):
			if not visual.wheel_tires[index].visible or not visual.wheel_rims[index].visible or not visual.wheel_hubs[index].visible:
				failures.append("%s: anchor-driven wheel %d is not visible" % [String(preset_id), index])
				break
		if not bool(visual.kenney_skin.get_meta("presentation_pristine_body", false)):
			failures.append("%s: pristine-body presentation contract metadata missing" % String(preset_id))
		_verify_body_finish(visual.kenney_skin, preset_id)

	var resolution := "%dx%d" % [viewport_size.x, viewport_size.y]
	var stem := "%s_%s" % [String(preset_id), resolution]
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

func _verify_body_finish(skin: KenneyVehicleSkin3D, preset_id: StringName) -> void:
	var found_material := false
	for material in skin.surface_materials:
		if not material is BaseMaterial3D:
			continue
		found_material = true
		var base := material as BaseMaterial3D
		if base.roughness > KenneyVehiclePresentation3D.BODY_PRESENTATION_ROUGHNESS + 0.001:
			failures.append("%s: body finish roughness was not presentation-tuned" % String(preset_id))
			return
		if base.metallic + 0.001 < KenneyVehiclePresentation3D.BODY_PRESENTATION_METALLIC:
			failures.append("%s: body finish metallic response was not presentation-tuned" % String(preset_id))
			return
	if not found_material:
		failures.append("%s: no imported body material available for presentation review" % String(preset_id))

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
