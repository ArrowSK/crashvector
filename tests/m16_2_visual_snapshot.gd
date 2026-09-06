# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const OUTPUT_DIR := "res://build/m16_2_visual_review"
var packed: PackedScene
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_fail("Could not create visual-review output directory: %d" % dir_error)
		return
	packed = load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load production scene for visual snapshots")
		return

	await _capture_case(PassengerCarCatalog.J_SEGMENT_SUV, ScenarioConfig.TARGET_PEDESTRIAN, 50.0, "01_suv_pedestrian_50")
	await _capture_case(PassengerCarCatalog.J_SEGMENT_SUV, ScenarioConfig.TARGET_BARRIER, 200.0, "02_suv_barrier_200")
	await _capture_case(PassengerCarCatalog.C_SEGMENT_COMPACT, ScenarioConfig.TARGET_TRUCK, 90.0, "03_compact_truck_90")

	if failures.is_empty():
		print("CrashVector M16.2 rendered acceptance snapshots captured in %s" % absolute_dir)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _capture_case(vehicle_id: StringName, target_id: StringName, speed_kmh: float, file_stem: String) -> void:
	var editor := packed.instantiate()
	root.add_child(editor)
	for _frame in range(12):
		await process_frame
	var vehicle_selector := _find_named(editor, "M16VehicleSelector") as OptionButton
	var target_selector := _find_named(editor, "M16TargetSelector") as OptionButton
	var speed_control := _find_named(editor, "M16ImpactSpeed") as SpinBox
	if vehicle_selector == null or target_selector == null or speed_control == null:
		failures.append("%s: production controls unavailable" % file_stem)
		editor.queue_free()
		await process_frame
		return
	_select_metadata(vehicle_selector, vehicle_id, file_stem)
	await process_frame
	_select_metadata(target_selector, target_id, file_stem)
	await process_frame
	speed_control.value = speed_kmh
	for _frame in range(10):
		await process_frame

	editor.call("_frame_scenario")
	for _frame in range(4):
		await process_frame
	await _save_frame("%s_preview.png" % file_stem)

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1600):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	if not completed:
		failures.append("%s: production run did not complete" % file_stem)
	else:
		for _frame in range(12):
			await process_frame
		editor.call("_m161_frame_aftermath")
		for _frame in range(5):
			await process_frame
		await _save_frame("%s_aftermath.png" % file_stem)

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

func _select_metadata(option: OptionButton, wanted: StringName, label: String) -> void:
	for index in range(option.item_count):
		if StringName(String(option.get_item_metadata(index))) == wanted:
			option.select(index)
			option.item_selected.emit(index)
			return
	failures.append("%s: could not select %s" % [label, String(wanted)])

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
