# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m10_release.gd"

var hybrid_elapsed_s: float = 0.0
var hybrid_production_active: bool = true

func _ready() -> void:
	super._ready()
	_activate_hybrid_preview()

func _physics_process(delta: float) -> void:
	var was_running := simulation_running
	if hybrid_production_active and simulation_running and not simulation_paused:
		hybrid_elapsed_s += delta
	super._physics_process(delta)
	if hybrid_production_active and was_running and not simulation_running:
		_stop_hybrid_motion()

func _rebuild_preview() -> void:
	super._rebuild_preview()
	_activate_hybrid_preview()

func _target_supports_hybrid_world() -> bool:
	if scenario == null:
		return false
	return scenario.target_type in [
		ScenarioConfig.TARGET_WALL,
		ScenarioConfig.TARGET_BARRIER,
		ScenarioConfig.TARGET_POLE,
		ScenarioConfig.TARGET_TREE,
		ScenarioConfig.TARGET_PASSENGER_CAR,
		ScenarioConfig.TARGET_TRUCK,
	]

func _activate_hybrid_preview() -> void:
	hybrid_production_active = _target_supports_hybrid_world()
	hybrid_elapsed_s = 0.0
	if not hybrid_production_active:
		# M12 deliberately refuses to run an unported target through the legacy
		# spring-cloud world-motion solver. Keeping the editable preview preserves
		# scenario files/UI while making the limitation explicit instead of
		# silently returning physically misleading output.
		if status_label != null:
			status_label.text = "M12 hybrid physics: this target is not yet ported to rigid-body world physics; simulation is unavailable in this beta."
		return
	# The legacy reduced-order contact simulators stay available for historical
	# tests/calibration only. The desktop production scene never steps them for
	# hybrid-supported targets. Godot owns world motion/contact; the passenger-
	# car structural graph is local crush only.
	pair_simulation = null
	static_simulation = null
	if car != null:
		car.hybrid_physics_enabled = true
		car.solver_substeps = scenario.solver_substeps
		_configure_chassis_material(car.rigid_chassis)
	if target_car != null:
		target_car.hybrid_physics_enabled = true
		target_car.solver_substeps = scenario.solver_substeps
		_configure_chassis_material(target_car.rigid_chassis)
	if truck != null:
		truck.hybrid_physics_enabled = true
		truck.solver_substeps = scenario.solver_substeps
		_configure_chassis_material(truck.rigid_chassis)

func _configure_chassis_material(chassis: VehicleRigidChassis) -> void:
	if chassis == null:
		return
	if chassis.physics_material_override == null:
		chassis.physics_material_override = PhysicsMaterial.new()
	chassis.physics_material_override.friction = clampf(scenario.contact_friction, 0.0, 1.0)
	# A road vehicle against a rigid wall must not inherit the old elastic-node
	# rebound. Keep engine contact almost inelastic; structural crush is
	# represented separately by the local deformation graph.
	chassis.physics_material_override.bounce = clampf(scenario.restitution, 0.0, 0.04)

func _on_simulate_pressed() -> void:
	if not _target_supports_hybrid_world():
		simulation_running = false
		simulation_paused = false
		if status_label != null:
			status_label.text = "Simulation blocked: this target has not yet been ported to M12 rigid-body physics. CrashVector will not fall back to the old world-motion solver."
		return
	super._on_simulate_pressed()
	if not simulation_running or not hybrid_production_active:
		return
	hybrid_elapsed_s = 0.0
	pair_simulation = null
	static_simulation = null
	if car != null:
		car.solver_substeps = scenario.solver_substeps
		car.begin_simulation()
	if target_car != null:
		target_car.solver_substeps = scenario.solver_substeps
		target_car.begin_simulation()
	if truck != null:
		truck.solver_substeps = scenario.solver_substeps
		truck.begin_simulation()

func _on_run_comparison_pressed() -> void:
	# M6/M8 ComparisonRunner is a synchronous reduced-order structural runner.
	# Do not expose it as if it were the new M12 world solver. The comparison UI
	# stays present for compatibility and will be re-enabled when its recorder is
	# ported to a SceneTree/RigidBody3D execution path.
	comparison_results.clear()
	comparison_playing = false
	if status_label != null:
		status_label.text = "Compare is temporarily unavailable in the M12 corrective beta while its recorder is ported to the rigid-body physics path."

func _on_run_matrix_comparison() -> void:
	comparison_results.clear()
	comparison_playing = false
	if comparison_lab_panel != null:
		comparison_lab_panel.visible = false
	if status_label != null:
		status_label.text = "Comparison Lab is temporarily unavailable in the M12 corrective beta; the legacy batch solver is not used for production results."

func _on_pause_pressed() -> void:
	super._on_pause_pressed()
	if not hybrid_production_active:
		return
	if car != null:
		car.set_simulation_paused(simulation_paused)
	if target_car != null:
		target_car.set_simulation_paused(simulation_paused)
	if truck != null:
		truck.set_simulation_paused(simulation_paused)

func _on_reset_pressed() -> void:
	_stop_hybrid_motion()
	super._on_reset_pressed()

func _on_new_pressed() -> void:
	_stop_hybrid_motion()
	super._on_new_pressed()

func _on_open_path_selected(path: String) -> void:
	_stop_hybrid_motion()
	super._on_open_path_selected(path)

func _stop_hybrid_motion() -> void:
	if car != null:
		car.end_simulation()
	if target_car != null:
		target_car.end_simulation()
	if truck != null:
		truck.end_simulation()

func _simulation_elapsed_s() -> float:
	if hybrid_production_active:
		return hybrid_elapsed_s
	return super._simulation_elapsed_s()

func _move_selected(delta_m: Vector3) -> void:
	if not hybrid_production_active:
		super._move_selected(delta_m)
		return
	if delta_m.is_zero_approx():
		return
	if selected_object == &"car":
		scenario.car_position_m += delta_m
		if car != null:
			car.set_preview_pose(scenario.car_position_m, scenario.car_heading_deg)
	else:
		scenario.target_position_m += delta_m
		if target_car != null:
			target_car.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		if truck != null:
			truck.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		if obstacle != null:
			obstacle.set_editor_transform(scenario.target_position_m, scenario.target_heading_deg)
	_sync_current_object_fields()

func _rotate_selected(delta_deg: float) -> void:
	if not hybrid_production_active:
		super._rotate_selected(delta_deg)
		return
	if is_zero_approx(delta_deg):
		return
	if selected_object == &"car":
		scenario.car_heading_deg = wrapf(scenario.car_heading_deg + delta_deg, -180.0, 180.0)
		if car != null:
			car.set_preview_pose(scenario.car_position_m, scenario.car_heading_deg)
	else:
		scenario.target_heading_deg = wrapf(scenario.target_heading_deg + delta_deg, -180.0, 180.0)
		if target_car != null:
			target_car.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		if truck != null:
			truck.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		if obstacle != null:
			obstacle.set_editor_transform(scenario.target_position_m, scenario.target_heading_deg)
	_sync_current_object_fields()

func _passenger_car_metrics(vehicle: CompactHatchback) -> Dictionary:
	var result := super._passenger_car_metrics(vehicle)
	result["linear_velocity_ms"] = vehicle.global_linear_velocity_ms()
	result["speed_kmh"] = PhysicsMetrics.ms_to_kmh(vehicle.global_linear_velocity_ms().length())
	result["momentum_kg_ms"] = vehicle.global_momentum_kg_ms()
	result["kinetic_energy_j"] = vehicle.global_kinetic_energy_j()
	return result

func _truck_metrics(vehicle: HeavyTruck) -> Dictionary:
	var result := super._truck_metrics(vehicle)
	result["linear_velocity_ms"] = vehicle.global_linear_velocity_ms()
	result["speed_kmh"] = PhysicsMetrics.ms_to_kmh(vehicle.global_linear_velocity_ms().length())
	result["momentum_kg_ms"] = vehicle.global_momentum_kg_ms()
	result["kinetic_energy_j"] = vehicle.global_kinetic_energy_j()
	return result

func _current_replay_context() -> Dictionary:
	var result := super._current_replay_context()
	if hybrid_production_active and car != null:
		result["contact_count"] = car.hybrid_contact_count()
		result["contact_dissipation_j"] = 0.0
		# Rigid-body contact and local phenomenological crush do not share one
		# conservative energy ledger. Do not present the legacy spring-cloud
		# residual as a production rigid-body energy balance.
		result["energy_balance_relative_error"] = 0.0
	return result

func _update_metrics() -> void:
	if not hybrid_production_active:
		super._update_metrics()
		return
	if metrics_label == null or car == null or car.model == null:
		return
	var car_speed := PhysicsMetrics.ms_to_kmh(car.global_linear_velocity_ms().length())
	var initial_energy_kj := PhysicsMetrics.kinetic_energy_from_speed_kmh(scenario.car_mass_kg, scenario.car_speed_kmh) / 1000.0
	var extra := "Godot RigidBody3D world motion • CCD • gravity • raycast suspension"
	if target_car != null:
		extra += " • target %.1f km/h" % PhysicsMetrics.ms_to_kmh(target_car.global_linear_velocity_ms().length())
	elif truck != null:
		extra += " • truck %.1f km/h" % PhysicsMetrics.ms_to_kmh(truck.global_linear_velocity_ms().length())
	elif obstacle != null:
		extra += " • %s" % ScenarioConfig.target_display_name(scenario.target_type)
	metrics_label.text = "%s • %.0f kg • %.1f km/h • initial KE %.1f kJ\nFront crush %.0f mm • contacts %d • max vertical %.1f km/h • max rebound %.1f km/h\n%s" % [
		car.vehicle_class_name(), car.model.total_mass_kg(), car_speed, initial_energy_kj,
		car.front_crush_deformation_m() * 1000.0,
		car.hybrid_contact_count(),
		PhysicsMetrics.ms_to_kmh(car.hybrid_maximum_vertical_speed_ms()),
		PhysicsMetrics.ms_to_kmh(car.hybrid_maximum_reverse_speed_ms()),
		extra,
	]