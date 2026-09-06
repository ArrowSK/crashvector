# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished := false

func _initialize() -> void:
	create_timer(70.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	_check_broadside_preflight()
	await _check_perpendicular_car_to_car_impact()
	_finish()

func _check_broadside_preflight() -> void:
	var config := ScenarioConfig.new()
	config.title = "M18 perpendicular passenger-car impact"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3.ZERO
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 0.0
	config.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	config.target_car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.target_mass_kg = PassengerCarCatalog.default_mass_kg(config.target_car_preset_id)
	config.target_position_m = Vector3(0.0, 0.0, -8.0)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 55.0
	var errors := config.validation_errors()
	_expect(errors.is_empty(), "M18 must allow a 90-degree passenger-car pair: %s" % "; ".join(errors))

	var truck_case := ScenarioConfig.from_dictionary(config.to_dictionary())
	truck_case.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	truck_case.target_position_m = Vector3(0.0, 0.0, -8.0)
	truck_case.target_heading_deg = -90.0
	truck_case.target_speed_kmh = 50.0
	var truck_errors := truck_case.validation_errors()
	var truck_broadside_still_blocked := false
	for error in truck_errors:
		if error.contains("broadside truck collapse"):
			truck_broadside_still_blocked = true
			break
	_expect(truck_broadside_still_blocked, "M18 passenger-car side support must not silently enable unmodelled truck broadside collapse")

func _check_perpendicular_car_to_car_impact() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M18 production scene must load")
	if packed == null:
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M18 T-bone regression"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3.ZERO
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 0.0
	config.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	config.target_car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.target_mass_kg = PassengerCarCatalog.default_mass_kg(config.target_car_preset_id)
	config.target_position_m = Vector3(0.0, 0.0, -8.0)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 55.0
	config.duration_s = 1.7
	config.solver_substeps = 12
	_expect(config.validation_errors().is_empty(), "M18 T-bone regression failed preflight")
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1100):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M18 perpendicular passenger-car production run did not complete")
	for _frame in range(5):
		await process_frame

	var car := editor.get("car") as M17CompactHatchback
	var target := editor.get("target_car") as M17CompactHatchback
	_expect(car != null and target != null, "M18 passenger-car pair must use the current rigid-body passenger-car compatibility class")
	if car != null and target != null:
		var side_crush := car.side_impact_deformation_m()
		print("M18 T-bone: side_crush=%.3f m side_energy=%.0f kJ striker_front=%.3f m car_contacts=%d target_contacts=%d" % [
			side_crush,
			car.side_impact_energy_j() / 1000.0,
			target.front_crush_deformation_m(),
			car.rigid_chassis.non_ground_contact_events,
			target.rigid_chassis.non_ground_contact_events,
		])
		_expect(car.rigid_chassis.non_ground_contact_events > 0, "M18 struck passenger car received no real Godot contact")
		_expect(target.rigid_chassis.non_ground_contact_events > 0, "M18 striking passenger car received no real Godot contact")
		_expect(side_crush > 0.02, "M18 broadside contact produced no material lateral deformation: %.3f m" % side_crush)
		_expect(side_crush < 0.70, "M18 lateral deformation exceeded its bounded generic envelope: %.3f m" % side_crush)
		_expect(target.front_crush_deformation_m() > 0.015, "M18 striking passenger car front did not deform against the other car's side: %.3f m" % target.front_crush_deformation_m())
		_expect(_finite_vector(car.rigid_chassis.global_position) and _finite_vector(target.rigid_chassis.global_position), "M18 side impact produced non-finite rigid-body positions")
		_expect(car.rigid_chassis.maximum_vertical_speed_ms < 20.0 and target.rigid_chassis.maximum_vertical_speed_ms < 20.0, "M18 side impact produced an implausible vertical launch")
		var box := car.safety_cell_collision.shape as BoxShape3D if car.safety_cell_collision != null else null
		_expect(box != null, "M18 struck car lost its protected-cell collision shape")
		if box != null:
			_expect(box.size.z < car.safety_cell_base_size_m.z - 0.005, "M18 side deformation did not retreat the physical lateral collision face")
		var visual_state := car.replay_visual_state()
		_expect(visual_state.has("hybrid_side_negative_z_crush_m") and visual_state.has("hybrid_side_positive_z_crush_m"), "M18 replay state does not preserve lateral deformation")

	var recorder: ReplayRecorder = editor.get("replay_recorder")
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "M18 side-impact case produced no replay")
	editor.queue_free()
	await process_frame

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M18 side-impact regression exceeded 70 seconds")
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M18 passenger-car side-impact regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
