# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M16.1 exact-case regression could not load the production scene")
	if packed == null:
		_finish()
		return

	var editor := packed.instantiate()
	root.add_child(editor)
	for _frame in range(8):
		await process_frame

	var vehicle_selector := _find_named(editor, "M16VehicleSelector") as OptionButton
	var target_selector := _find_named(editor, "M16TargetSelector") as OptionButton
	var speed_control := _find_named(editor, "M16ImpactSpeed") as SpinBox
	_expect(vehicle_selector != null and target_selector != null and speed_control != null, "M16.1 exact-case controls are missing")
	if vehicle_selector == null or target_selector == null or speed_control == null:
		editor.queue_free()
		_finish()
		return

	var d_index := _metadata_index(vehicle_selector, PassengerCarCatalog.D_SEGMENT_MIDSIZE)
	var barrier_index := _metadata_index(target_selector, ScenarioConfig.TARGET_BARRIER)
	_expect(d_index >= 0, "D-segment midsize class is unavailable in the production selector")
	_expect(barrier_index >= 0, "Concrete barrier is unavailable in the production selector")
	if d_index < 0 or barrier_index < 0:
		editor.queue_free()
		_finish()
		return

	vehicle_selector.select(d_index)
	vehicle_selector.item_selected.emit(d_index)
	await process_frame
	target_selector.select(barrier_index)
	target_selector.item_selected.emit(barrier_index)
	await process_frame
	speed_control.value = 200.0
	await process_frame

	var scenario: ScenarioConfig = editor.get("scenario")
	_expect(scenario != null, "Production scenario could not be resolved")
	if scenario == null:
		editor.queue_free()
		_finish()
		return
	_expect(scenario.car_preset_id == PassengerCarCatalog.D_SEGMENT_MIDSIZE, "Exact-case regression did not select D-segment midsize")
	_expect(scenario.target_type == ScenarioConfig.TARGET_BARRIER, "Exact-case regression did not select concrete barrier")
	_expect(absf(scenario.car_speed_kmh - 200.0) < 0.001, "Exact-case regression did not set 200 km/h")

	var initial_visual := _find_named(editor, "M16PrimaryVehicleVisual")
	_expect(initial_visual is M161VehicleVisual, "D-segment preview is not using the M16.1 vehicle presentation skin")
	if initial_visual is M161VehicleVisual:
		var preview_visual := initial_visual as M161VehicleVisual
		_expect(preview_visual.profile_id == PassengerCarCatalog.D_SEGMENT_MIDSIZE, "D-segment preview visual profile is out of sync with the scenario")

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1500):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "D-segment 200 km/h concrete-barrier production run did not complete")

	for _frame in range(8):
		await process_frame

	var recorder: ReplayRecorder = editor.get("replay_recorder")
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "Exact-case production run did not create replay frames")
	if recorder != null and recorder.recording != null:
		_expect(recorder.recording.duration_s > 0.5, "Exact-case replay duration is implausibly short")

	var final_visual := _find_named(editor, "M16PrimaryVehicleVisual")
	_expect(final_visual is M161VehicleVisual, "M16.1 vehicle presentation skin disappeared after the 200 km/h barrier run")
	if final_visual is M161VehicleVisual:
		var visual := final_visual as M161VehicleVisual
		var car: CompactHatchback = editor.get("car")
		_expect(visual.profile_id == PassengerCarCatalog.D_SEGMENT_MIDSIZE, "Final vehicle visual no longer matches the D-segment scenario")
		_expect(car != null and visual.vehicle == car, "Final presentation skin is detached from the simulated D-segment car")
		_expect(visual.body_mesh.get_surface_count() > 0, "Final D-segment body mesh is empty")
		if car != null:
			_expect(car.body_shell != null and not car.body_shell.visible, "Legacy scaled body shell became visible after the exact-case run")
			_expect(car.wheel_rig != null and not car.wheel_rig.visible, "Legacy generic wheel rig became visible after the exact-case run")

	var ring: MeshInstance3D = editor.get("m10_selection_ring")
	_expect(ring != null and not ring.visible, "Editor selection ring remains visible over the completed 200 km/h result")

	editor.call("_m161_frame_aftermath")
	await process_frame
	var camera: Camera3D = editor.get("camera")
	_expect(camera != null, "Exact-case aftermath camera could not be resolved")
	if camera != null:
		var bounds: Vector2 = editor.call("_m161_horizontal_bounds")
		var primary_center: Vector3 = editor.call("_m161_primary_center")
		var target_center: Vector3 = editor.call("_m161_target_center")
		_expect(is_finite(primary_center.x) and is_finite(primary_center.y) and is_finite(primary_center.z), "Exact-case primary vehicle finished at a non-finite position")
		_expect(primary_center.x >= bounds.x - 0.01 and primary_center.x <= bounds.y + 0.01, "Aftermath bounds do not contain the final D-segment position")
		_expect(target_center.x >= bounds.x - 0.01 and target_center.x <= bounds.y + 0.01, "Aftermath bounds do not contain the concrete barrier")
		var focus := Vector3((bounds.x + bounds.y) * 0.5, 0.92, (primary_center.z + target_center.z) * 0.5)
		var camera_distance := camera.global_position.distance_to(focus)
		_expect(camera_distance >= 5.0 and camera_distance <= 26.0, "Aftermath camera framing is implausibly tight/wide: %.2f m" % camera_distance)
		var to_focus := (focus - camera.global_position).normalized()
		var camera_forward := (-camera.global_transform.basis.z).normalized()
		_expect(camera_forward.dot(to_focus) > 0.985, "Aftermath camera is not aimed at the final crash bounds")

	editor.queue_free()
	await process_frame
	_finish()

func _metadata_index(option: OptionButton, wanted: StringName) -> int:
	if option == null:
		return -1
	for index in range(option.item_count):
		if StringName(String(option.get_item_metadata(index))) == wanted:
			return index
	return -1

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
		print("CrashVector M16.1 D-segment 200 km/h concrete-barrier regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
