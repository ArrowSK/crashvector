# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished := false

func _initialize() -> void:
	create_timer(180.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	_check_preflight_scope()
	await _check_truck_broadside()
	await _check_lorry_broadside()
	await _check_motorcycle_broadside()
	await _check_truck_oblique()
	_finish()

func _check_preflight_scope() -> void:
	for target_type in [ScenarioConfig.TARGET_TRUCK, ScenarioConfig.TARGET_LORRY, ScenarioConfig.TARGET_MOTORCYCLE]:
		var config := _broadside_config(target_type)
		_expect(config.validation_errors().is_empty(), "M20 must allow generic broadside %s layouts: %s" % [ScenarioConfig.target_display_name(target_type), "; ".join(config.validation_errors())])

	var bicycle := _broadside_config(ScenarioConfig.TARGET_BICYCLE)
	bicycle.target_preset_id = RoadUserCatalog.BICYCLE_CITY
	bicycle.target_mass_kg = RoadUserCatalog.default_mass_kg(bicycle.target_preset_id)
	var bicycle_errors := bicycle.validation_errors()
	var bicycle_broadside_blocked := false
	for error in bicycle_errors:
		if error.contains("not broadside impacts yet"):
			bicycle_broadside_blocked = true
			break
	_expect(bicycle_broadside_blocked, "M20 must not silently enable the still-unmodelled bicycle broadside path")

func _check_truck_broadside() -> void:
	var result := await _run_case(_broadside_config(ScenarioConfig.TARGET_TRUCK))
	var editor: Node = result.get("editor", null)
	if editor == null:
		return
	var truck_target := editor.get("truck") as M20HeavyTruck
	_expect(truck_target != null, "M20 heavy-truck broadside must instantiate M20HeavyTruck")
	if truck_target != null:
		_expect(truck_target.rigid_chassis.non_ground_contact_events > 0, "M20 heavy-truck broadside produced no real Godot contact")
		_expect(truck_target.side_impact_deformation_m() > 0.005, "M20 heavy-truck broadside produced no material side deformation")
		_expect(truck_target.side_impact_deformation_m() <= 0.521, "M20 heavy-truck side deformation exceeded its bounded generic envelope")
		_expect(_finite_vector(truck_target.rigid_chassis.global_position), "M20 heavy-truck broadside produced a non-finite chassis position")
		_expect(truck_target.rigid_chassis.maximum_vertical_speed_ms < 20.0, "M20 heavy-truck broadside produced an implausible vertical launch")
		var trailer_box := truck_target.trailer_collision.shape as BoxShape3D if truck_target.trailer_collision != null else null
		_expect(trailer_box != null, "M20 heavy-truck broadside lost the trailer collision shape")
		if trailer_box != null:
			_expect(trailer_box.size.z < M20HeavyTruck.TRAILER_BASE_SIZE.z - 0.001, "M20 heavy-truck side deformation did not retreat a physical trailer side face")
	_check_primary_contact_response(editor, "heavy-truck broadside")
	_dispose_case(editor)
	await process_frame

func _check_lorry_broadside() -> void:
	var result := await _run_case(_broadside_config(ScenarioConfig.TARGET_LORRY))
	var editor: Node = result.get("editor", null)
	if editor == null:
		return
	var lorry_target := editor.get("m17_lorry") as M20RigidLorry
	_expect(lorry_target != null, "M20 rigid-lorry broadside must instantiate M20RigidLorry")
	if lorry_target != null:
		_expect(lorry_target.rigid_chassis.non_ground_contact_events > 0, "M20 rigid-lorry broadside produced no real Godot contact")
		_expect(lorry_target.side_impact_deformation_m() > 0.005, "M20 rigid-lorry broadside produced no material side deformation")
		_expect(lorry_target.side_impact_deformation_m() <= 0.461, "M20 rigid-lorry side deformation exceeded its bounded generic envelope")
		_expect(_finite_vector(lorry_target.rigid_chassis.global_position), "M20 rigid-lorry broadside produced a non-finite chassis position")
		_expect(lorry_target.rigid_chassis.maximum_vertical_speed_ms < 20.0, "M20 rigid-lorry broadside produced an implausible vertical launch")
		var cargo_box := lorry_target.cargo_collision.shape as BoxShape3D if lorry_target.cargo_collision != null else null
		_expect(cargo_box != null, "M20 rigid-lorry broadside lost the cargo collision shape")
		if cargo_box != null:
			_expect(cargo_box.size.z < M20RigidLorry.CARGO_BASE_SIZE.z - 0.001, "M20 rigid-lorry side deformation did not retreat a physical cargo side face")
	_check_primary_contact_response(editor, "rigid-lorry broadside")
	_dispose_case(editor)
	await process_frame

func _check_motorcycle_broadside() -> void:
	var result := await _run_case(_broadside_config(ScenarioConfig.TARGET_MOTORCYCLE))
	var editor: Node = result.get("editor", null)
	if editor == null:
		return
	var motorcycle_target := editor.get("m17_motorcycle") as M20Motorcycle
	_expect(motorcycle_target != null, "M20 motorcycle broadside must instantiate M20Motorcycle")
	if motorcycle_target != null:
		_expect(motorcycle_target.rigid_chassis.non_ground_contact_events > 0, "M20 riderless-motorcycle broadside produced no real Godot contact")
		_expect(motorcycle_target.side_impact_deformation_m() > 0.002, "M20 riderless-motorcycle broadside produced no local side deformation")
		_expect(motorcycle_target.side_impact_deformation_m() <= 0.201, "M20 motorcycle side deformation exceeded its bounded generic envelope")
		_expect(_finite_vector(motorcycle_target.rigid_chassis.global_position), "M20 motorcycle broadside produced a non-finite chassis position")
		_expect(motorcycle_target.rigid_chassis.maximum_vertical_speed_ms < 25.0, "M20 motorcycle broadside produced an implausible vertical launch")
		var frame_box := motorcycle_target.frame_collision.shape as BoxShape3D if motorcycle_target.frame_collision != null else null
		_expect(frame_box != null, "M20 motorcycle broadside lost the frame collision shape")
		if frame_box != null:
			_expect(frame_box.size.z < M20Motorcycle.FRAME_BASE_SIZE.z - 0.001, "M20 motorcycle side deformation did not retreat the physical frame side face")
	_check_primary_contact_response(editor, "motorcycle broadside")
	_dispose_case(editor)
	await process_frame

func _check_truck_oblique() -> void:
	var config := ScenarioConfig.new()
	config.title = "M20 generic oblique heavy-truck impact"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-9.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 65.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	# Approximate the centre of the 9.5 m one-piece target on the primary lane
	# while rotating its long axis by 45 degrees. This is a generic CrashVector
	# observation case, not an external protocol replica.
	var half_length := 9.5 * 0.5
	var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(-45.0)).normalized()
	var desired_center := Vector3(3.2, 0.0, 0.0)
	config.target_position_m = desired_center - forward * half_length
	config.target_heading_deg = -45.0
	config.target_speed_kmh = 0.0
	config.duration_s = 2.0
	config.solver_substeps = 12
	_expect(config.validation_errors().is_empty(), "M20 generic oblique truck case failed preflight: %s" % "; ".join(config.validation_errors()))
	var result := await _run_case(config)
	var editor: Node = result.get("editor", null)
	if editor == null:
		return
	var truck_target := editor.get("truck") as M20HeavyTruck
	_expect(truck_target != null, "M20 oblique case must instantiate M20HeavyTruck")
	if truck_target != null:
		_expect(truck_target.rigid_chassis.non_ground_contact_events > 0, "M20 oblique truck case produced no real Godot contact")
		_expect(truck_target.side_impact_energy_j() > 0.0, "M20 oblique truck case produced no lateral contact demand")
		var longitudinal_deformation := maxf(truck_target.hybrid_front_crush_m, truck_target.hybrid_rear_crush_m)
		_expect(longitudinal_deformation > 0.001, "M20 oblique truck case produced no longitudinal deformation component")
		_expect(truck_target.side_impact_deformation_m() > 0.001, "M20 oblique truck case produced no lateral deformation component")
		_expect(truck_target.rigid_chassis.maximum_vertical_speed_ms < 20.0, "M20 oblique truck case produced an implausible vertical launch")
	_check_primary_contact_response(editor, "oblique heavy-truck")
	_dispose_case(editor)
	await process_frame

func _broadside_config(target_type: StringName) -> ScenarioConfig:
	var config := ScenarioConfig.new()
	config.title = "M20 broadside %s" % ScenarioConfig.target_display_name(target_type)
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 60.0
	config.apply_target_defaults(target_type)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 0.0
	var target_length := 9.5
	if target_type == ScenarioConfig.TARGET_LORRY:
		target_length = 7.35
	elif target_type == ScenarioConfig.TARGET_MOTORCYCLE:
		target_length = 1.95
	elif target_type == ScenarioConfig.TARGET_BICYCLE:
		target_length = 1.70
	# With -90 degrees the target's local +X points across world +Z. Offset the
	# rear/origin so the target's longitudinal centre lies on z=0 while the
	# primary car approaches its side along world +X.
	config.target_position_m = Vector3(3.0, 0.0, -target_length * 0.5)
	config.duration_s = 2.0
	config.solver_substeps = 12
	return config

func _run_case(config: ScenarioConfig) -> Dictionary:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M20 production scene must load")
	if packed == null:
		return {}
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame
	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1300):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M20 production case did not complete: %s" % config.title)
	for _frame in range(5):
		await process_frame
	return {"editor": editor, "completed": completed}

func _check_primary_contact_response(editor: Node, label: String) -> void:
	var primary := editor.get("car") as M17CompactHatchback
	_expect(primary != null, "M20 %s lost the production passenger car" % label)
	if primary == null:
		return
	_expect(primary.rigid_chassis.non_ground_contact_events > 0, "M20 %s primary car received no real Godot contact" % label)
	_expect(primary.front_crush_deformation_m() > 0.002 or primary.side_impact_deformation_m() > 0.002, "M20 %s primary car showed no contact-linked deformation" % label)
	_expect(_finite_vector(primary.rigid_chassis.global_position), "M20 %s primary car position is non-finite" % label)
	_expect(primary.rigid_chassis.maximum_vertical_speed_ms < 20.0, "M20 %s primary car produced an implausible vertical launch" % label)

func _dispose_case(editor: Node) -> void:
	if editor != null and is_instance_valid(editor):
		editor.queue_free()

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M20 heavy/other-impact regression exceeded 180 seconds")
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M20 heavy/other-impact regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
