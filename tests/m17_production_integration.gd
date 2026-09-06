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
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M17 production scene must load")
	if packed == null:
		_finish()
		return

	await _check_scene_routing_and_long_road(packed)
	_check_reciprocal_scenario_validation()
	await _check_new_rigid_targets(packed)
	await _check_truck_strikes_and_deforms_car(packed)
	await _check_production_comparison(packed)
	_finish()

func _check_scene_routing_and_long_road(packed: PackedScene) -> void:
	var editor := packed.instantiate()
	root.add_child(editor)
	for _frame in range(6):
		await process_frame
	_expect(String(editor.get_script().resource_path).ends_with("crash_demo_m17.gd"), "Production scene must route through M17")
	var road := editor.get_node_or_null("Road") as StaticBody3D
	_expect(road != null, "M17 production scene must expose the continuous Road collision body")
	if road != null:
		var collision := _first_collision_shape(road)
		var box := collision.shape as BoxShape3D if collision != null else null
		_expect(box != null, "M17 Road must use a box collision surface")
		if box != null:
			_expect(box.size.x >= 3990.0, "M17 road is too short for high-speed supported runs: %.1f m" % box.size.x)
			_expect(box.size.z >= 19.5, "M17 road is narrower than the production proving surface: %.1f m" % box.size.z)
	editor.queue_free()
	await process_frame

func _check_reciprocal_scenario_validation() -> void:
	var dynamic := ScenarioConfig.new()
	dynamic.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	dynamic.car_position_m = Vector3.ZERO
	dynamic.car_heading_deg = 0.0
	dynamic.car_speed_kmh = 20.0
	dynamic.target_position_m = Vector3(-13.0, 0.0, 0.0)
	dynamic.target_heading_deg = 0.0
	dynamic.target_speed_kmh = 90.0
	var dynamic_errors := dynamic.validation_errors()
	_expect(dynamic_errors.is_empty(), "A faster truck behind a passenger car must be a valid reciprocal dynamic scenario: %s" % "; ".join(dynamic_errors))

	var static_case := ScenarioConfig.new()
	static_case.apply_target_defaults(ScenarioConfig.TARGET_BARRIER)
	static_case.car_position_m = Vector3.ZERO
	static_case.car_heading_deg = 0.0
	static_case.target_position_m = Vector3(-5.0, 0.0, 0.0)
	var static_errors := static_case.validation_errors()
	var rejected_static_behind := false
	for error in static_errors:
		if error.contains("Static target must begin"):
			rejected_static_behind = true
			break
	_expect(rejected_static_behind, "Static fixtures behind the primary car must remain rejected")

func _check_new_rigid_targets(packed: PackedScene) -> void:
	for target_type in [ScenarioConfig.TARGET_LORRY, ScenarioConfig.TARGET_MOTORCYCLE]:
		var editor := packed.instantiate()
		editor.set("m10_first_run_applied", true)
		var config := ScenarioConfig.new()
		config.apply_target_defaults(target_type)
		config.car_position_m = Vector3(-6.0, 0.0, 0.0)
		config.target_position_m = Vector3(3.0, 0.0, 0.0)
		editor.set("scenario", config)
		root.add_child(editor)
		for _frame in range(6):
			await process_frame
		await physics_frame
		_expect(bool(editor.get("hybrid_production_active")), "%s must use production rigid-body world motion" % ScenarioConfig.target_display_name(target_type))
		_expect(editor.get("pair_simulation") == null and editor.get("static_simulation") == null, "%s must not fall back to a legacy world-motion solver" % ScenarioConfig.target_display_name(target_type))
		if target_type == ScenarioConfig.TARGET_LORRY:
			var lorry: Variant = editor.get("m17_lorry")
			_expect(lorry is M17RigidLorry, "Rigid lorry must use M17RigidLorry")
			if lorry is M17RigidLorry:
				_expect((lorry as M17RigidLorry).rigid_chassis is RigidBody3D, "Rigid lorry must own a Godot RigidBody3D chassis")
		else:
			var motorcycle: Variant = editor.get("m17_motorcycle")
			_expect(motorcycle is M17Motorcycle, "Motorcycle must use M17Motorcycle")
			if motorcycle is M17Motorcycle:
				_expect((motorcycle as M17Motorcycle).rigid_chassis is RigidBody3D, "Motorcycle must own a Godot RigidBody3D chassis")
		editor.queue_free()
		await process_frame

func _check_truck_strikes_and_deforms_car(packed: PackedScene) -> void:
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M17 reciprocal truck rear impact"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(0.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 20.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	config.target_position_m = Vector3(-13.0, 0.0, 0.0)
	config.target_heading_deg = 0.0
	config.target_speed_kmh = 90.0
	config.duration_s = 1.6
	config.solver_substeps = 10
	_expect(config.validation_errors().is_empty(), "Reciprocal truck case failed preflight before production run")
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(900):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "Reciprocal truck->car production run did not complete")
	for _frame in range(4):
		await process_frame

	var car := editor.get("car") as M17CompactHatchback
	var truck := editor.get("truck") as M17HeavyTruck
	_expect(car != null, "Reciprocal case did not use M17CompactHatchback")
	_expect(truck != null, "Reciprocal case did not use M17HeavyTruck")
	if car != null and truck != null:
		_expect(car.rigid_chassis.non_ground_contact_events > 0, "Truck->car case produced no real car contact")
		_expect(truck.rigid_chassis.non_ground_contact_events > 0, "Truck->car case produced no real truck contact")
		_expect(car.hybrid_rear_impact_crush_m > 0.02, "Truck striking from behind did not produce direct passenger-car rear crush: %.3f m" % car.hybrid_rear_impact_crush_m)
		_expect(truck.hybrid_front_crush_m > 0.005, "Striking truck did not receive bounded front collapse: %.3f m" % truck.hybrid_front_crush_m)
		_expect(_finite_vector(car.rigid_chassis.global_position) and _finite_vector(truck.rigid_chassis.global_position), "Reciprocal impact produced non-finite rigid-body positions")
		_expect(car.rigid_chassis.maximum_vertical_speed_ms < 20.0 and truck.rigid_chassis.maximum_vertical_speed_ms < 20.0, "Reciprocal impact produced an implausible vertical launch")
	var recorder: ReplayRecorder = editor.get("replay_recorder")
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "Reciprocal truck->car case produced no replay")
	editor.queue_free()
	await process_frame

func _check_production_comparison(packed: PackedScene) -> void:
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M17 comparison regression"
	config.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-5.6, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 35.0
	config.apply_target_defaults(ScenarioConfig.TARGET_WALL)
	config.target_position_m = Vector3(3.2, 0.0, 0.0)
	config.target_heading_deg = 0.0
	config.duration_s = 1.0
	config.solver_substeps = 6
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame

	var speed_a := editor.get("m10_compare_speed_a") as SpinBox
	var speed_b := editor.get("m10_compare_speed_b") as SpinBox
	var speed_c := editor.get("m10_compare_speed_c") as SpinBox
	var use_c := editor.get("m10_compare_use_c") as CheckButton
	_expect(speed_a != null and speed_b != null and speed_c != null and use_c != null, "M17 comparison controls are unavailable")
	if speed_a == null or speed_b == null or speed_c == null or use_c == null:
		editor.queue_free()
		await process_frame
		return
	speed_a.value = 30.0
	speed_b.value = 45.0
	speed_c.value = 60.0
	use_c.button_pressed = false

	editor.call("_on_m10_run_comparison")
	await process_frame
	var started := bool(editor.get("m17_comparison_running"))
	_expect(started, "M17 Compare did not enter its production-physics execution path")
	var comparison_completed := false
	for _frame in range(2200):
		if not bool(editor.get("m17_comparison_running")):
			comparison_completed = true
			break
		await physics_frame
	_expect(comparison_completed, "M17 production comparison did not complete within its bounded window")
	for _frame in range(8):
		await process_frame

	var results: Array = editor.get("comparison_results")
	_expect(results.size() == 2, "M17 custom-speed comparison should produce exactly two enabled variants, got %d" % results.size())
	for index in range(results.size()):
		var result: Dictionary = results[index]
		_expect(String(result.get("error", "")).is_empty(), "Comparison variant %d reported an error: %s" % [index + 1, String(result.get("error", ""))])
		var recording := result.get("recording") as ReplayRecording
		var analysis: Dictionary = result.get("analysis", {})
		_expect(recording != null and recording.has_frames(), "Comparison variant %d has no production replay" % (index + 1))
		_expect(not analysis.is_empty(), "Comparison variant %d has no production analysis" % (index + 1))
	_expect(bool(editor.get("comparison_active")), "M17 comparison results were not entered into the comparison workspace")
	var lanes: Array = editor.get("comparison_lanes")
	_expect(lanes.size() == results.size(), "M17 comparison replay lanes do not match production results")

	editor.call("_on_m10_exit_comparison")
	await process_frame
	editor.queue_free()
	await process_frame

func _first_collision_shape(node: Node) -> CollisionShape3D:
	for child in node.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M17 production integration regression exceeded 70 seconds")
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M17 reciprocal-impact, long-road and production-comparison regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
