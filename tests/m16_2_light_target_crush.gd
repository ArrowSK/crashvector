# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M16.2 light-target regression could not load production scene")
	if packed == null:
		_finish()
		return
	var editor := packed.instantiate()
	root.add_child(editor)
	for _frame in range(10):
		await process_frame

	var vehicle_selector := _find_named(editor, "M16VehicleSelector") as OptionButton
	var target_selector := _find_named(editor, "M16TargetSelector") as OptionButton
	var speed_control := _find_named(editor, "M16ImpactSpeed") as SpinBox
	_expect(vehicle_selector != null and target_selector != null and speed_control != null, "M16.2 production selectors are missing")
	if vehicle_selector == null or target_selector == null or speed_control == null:
		editor.queue_free()
		_finish()
		return

	_select_metadata(vehicle_selector, PassengerCarCatalog.J_SEGMENT_SUV)
	await process_frame
	_select_metadata(target_selector, ScenarioConfig.TARGET_PEDESTRIAN)
	await process_frame
	speed_control.value = 50.0
	for _frame in range(8):
		await process_frame

	var preview_car := editor.get("car") as CompactHatchback
	_expect(preview_car is M162CompactHatchback, "M16.2 production path is not using the light-target crush guard")

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1600):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M16.2 SUV/pedestrian 50 km/h run did not complete")
	for _frame in range(8):
		await process_frame

	var report: Dictionary = editor.get("analysis_report")
	var max_front_crush_mm := float(report.get("max_front_crush_mm", 9999.0))
	# A 75 kg pedestrian at 50 km/h provides only a few kJ of reduced-mass
	# collision energy. The geometric probe must not turn that into the previous
	# near-metre passenger-car nose collapse. This is a broad sanity ceiling, not
	# a biomechanical or vehicle homologation target.
	_expect(max_front_crush_mm < 180.0, "Light road-user impact still commands implausible passenger-car crush: %.1f mm" % max_front_crush_mm)
	_expect(max_front_crush_mm >= 0.0, "Light-target crush metric is invalid")

	var car := editor.get("car") as CompactHatchback
	_expect(car != null and car.hybrid_collision_energy_j() < 50000.0, "SUV/pedestrian reduced-mass collision energy is unexpectedly high")

	editor.queue_free()
	await process_frame
	_finish()

func _select_metadata(option: OptionButton, wanted: StringName) -> void:
	for index in range(option.item_count):
		if StringName(String(option.get_item_metadata(index))) == wanted:
			option.select(index)
			option.item_selected.emit(index)
			return
	failures.append("Could not select %s" % String(wanted))

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

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("CrashVector M16.2 light-target crush-energy guard regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
