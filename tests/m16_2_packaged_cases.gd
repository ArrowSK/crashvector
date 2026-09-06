# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var packed: PackedScene

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	packed = load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M16.2 packaged-case regression could not load production scene")
	if packed == null:
		_finish()
		return

	await _run_case(PassengerCarCatalog.J_SEGMENT_SUV, ScenarioConfig.TARGET_PEDESTRIAN, 50.0, "SUV-pedestrian 50 km/h")
	await _run_case(PassengerCarCatalog.J_SEGMENT_SUV, ScenarioConfig.TARGET_BARRIER, 200.0, "SUV-barrier 200 km/h")
	await _run_case(PassengerCarCatalog.C_SEGMENT_COMPACT, ScenarioConfig.TARGET_TRUCK, 90.0, "C-segment-truck 90 km/h")
	_finish()

func _run_case(vehicle_id: StringName, target_id: StringName, speed_kmh: float, label: String) -> void:
	var editor := packed.instantiate()
	root.add_child(editor)
	for _frame in range(10):
		await process_frame

	var vehicle_selector := _find_named(editor, "M16VehicleSelector") as OptionButton
	var target_selector := _find_named(editor, "M16TargetSelector") as OptionButton
	var speed_control := _find_named(editor, "M16ImpactSpeed") as SpinBox
	_expect(vehicle_selector != null and target_selector != null and speed_control != null, "%s: production selectors missing" % label)
	if vehicle_selector == null or target_selector == null or speed_control == null:
		editor.queue_free()
		await process_frame
		return

	_select_metadata(vehicle_selector, vehicle_id, label)
	await process_frame
	_select_metadata(target_selector, target_id, label)
	await process_frame
	speed_control.value = speed_kmh
	for _frame in range(8):
		await process_frame

	var scenario: ScenarioConfig = editor.get("scenario")
	_expect(scenario != null, "%s: scenario missing" % label)
	if scenario == null:
		editor.queue_free()
		await process_frame
		return
	var before := scenario.to_dictionary().duplicate(true)
	var expected := ScenarioConfig.from_dictionary(before)
	var initial_car_position := expected.car_position_m
	var initial_target_position := expected.target_position_m
	var initial_car_heading := expected.car_heading_deg
	var initial_target_heading := expected.target_heading_deg
	var impact_anchor_before: Vector3 = editor.call("_m162_impact_anchor")

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1600):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "%s: production run did not complete" % label)
	for _frame in range(10):
		await process_frame

	var after: ScenarioConfig = editor.get("scenario")
	_expect(after != null, "%s: scenario definition disappeared after run" % label)
	if after != null:
		_expect(after.car_position_m.distance_to(initial_car_position) < 0.0001, "%s: Properties/scenario primary X/Z was replaced by runtime pose" % label)
		_expect(after.target_position_m.distance_to(initial_target_position) < 0.0001, "%s: Properties/scenario target X/Z was replaced by runtime pose" % label)
		_expect(absf(after.car_heading_deg - initial_car_heading) < 0.0001, "%s: primary heading was replaced by runtime orientation" % label)
		_expect(absf(after.target_heading_deg - initial_target_heading) < 0.0001, "%s: target heading was replaced by runtime orientation" % label)
		_expect(after.car_preset_id == vehicle_id and after.target_type == target_id, "%s: scenario identity changed during run" % label)
		_expect(absf(after.car_speed_kmh - speed_kmh) < 0.001, "%s: configured speed changed during run" % label)

	var vehicle_x := editor.get("m10_vehicle_x") as SpinBox
	var target_x := editor.get("m10_target_x") as SpinBox
	_expect(vehicle_x != null and absf(vehicle_x.value - initial_car_position.x) < 0.001, "%s: Properties displays runtime primary position instead of configured position" % label)
	_expect(target_x != null and absf(target_x.value - initial_target_position.x) < 0.001, "%s: Properties displays runtime target position instead of configured position" % label)

	var recorder: ReplayRecorder = editor.get("replay_recorder")
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "%s: completed run has no replay" % label)
	var ring := editor.get("m10_selection_ring") as MeshInstance3D
	_expect(ring != null and not ring.visible, "%s: editor selection marker remains visible in aftermath" % label)

	editor.call("_m161_frame_aftermath")
	await process_frame
	var camera: Camera3D = editor.get("camera")
	_expect(camera != null, "%s: aftermath camera missing" % label)
	if camera != null:
		var impact_anchor_after: Vector3 = editor.call("_m162_impact_anchor")
		_expect(impact_anchor_after.distance_to(impact_anchor_before) < 0.001, "%s: impact anchor changed with runtime motion" % label)
		var anchor_distance := camera.global_position.distance_to(impact_anchor_after)
		_expect(anchor_distance >= 4.0 and anchor_distance <= 16.5, "%s: aftermath is not impact-cluster framed (camera %.2f m from impact)" % [label, anchor_distance])
		var camera_forward := (-camera.global_transform.basis.z).normalized()
		var to_anchor := (impact_anchor_after - camera.global_position).normalized()
		_expect(camera_forward.dot(to_anchor) > 0.90, "%s: aftermath camera no longer points toward the impact cluster" % label)

	var car: CompactHatchback = editor.get("car")
	var visual := _find_named(editor, "M16PrimaryVehicleVisual") as M162VehicleVisual
	_expect(car != null and visual != null and visual.vehicle == car, "%s: M16.2 passenger-car presentation is missing after run" % label)
	if visual != null:
		_expect(_visual_sections_ordered(visual), "%s: severe deformation produced inverted/pathological presentation sections" % label)

	if target_id == ScenarioConfig.TARGET_PEDESTRIAN:
		var road_skin: RoadUserPresentationSkin3D = editor.get("m162_road_user_skin")
		var proxy: RoadUserRigidProxy3D = editor.get("road_user_proxy")
		_expect(proxy is RoadUserArticulatedProxy3D, "%s: finalized M15 pedestrian proxy is not active" % label)
		_expect(road_skin != null and road_skin.proxy == proxy, "%s: connected pedestrian presentation disappeared after impact" % label)
		if road_skin != null:
			var torso := _find_named(road_skin, "TorsoSkin") as MeshInstance3D
			var head := _find_named(road_skin, "HeadSkin") as MeshInstance3D
			_expect(torso != null and torso.visible and head != null and head.visible, "%s: pedestrian aftermath no longer reads as one connected figure" % label)
	elif target_id == ScenarioConfig.TARGET_TRUCK:
		var truck: HeavyTruck = editor.get("truck")
		var truck_skin: M162HeavyTruckVisual = editor.get("m162_truck_skin")
		_expect(truck != null and truck_skin != null and truck_skin.truck == truck, "%s: tractor/trailer presentation disappeared after impact" % label)

	editor.queue_free()
	await process_frame

func _visual_sections_ordered(visual: M162VehicleVisual) -> bool:
	for index in range(19):
		var u := float(index) / 18.0
		var section: Dictionary = visual.call("_section_at_u", u)
		for side in ["left", "right"]:
			var lower := _v3(section, "lower_%s" % side)
			var belt := _v3(section, "belt_%s" % side)
			var upper := _v3(section, "upper_%s" % side)
			if not _finite_vector(lower) or not _finite_vector(belt) or not _finite_vector(upper):
				return false
			var reference := visual.vehicle.global_reference_transform()
			var up := reference.basis.y.normalized()
			if (belt - lower).dot(up) <= 0.02 or (upper - belt).dot(up) <= 0.02:
				return false
	return true

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

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

func _v3(section: Dictionary, key: String) -> Vector3:
	var value: Variant = section.get(key, Vector3.ZERO)
	return value if value is Vector3 else Vector3.ZERO

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("CrashVector M16.2 packaged screenshot acceptance cases passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
