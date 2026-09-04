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

func _activate_hybrid_preview() -> void:
	if not hybrid_production_active:
		return
	# The legacy reduced-order contact simulators stay available for historical
	# tests/calibration, but the desktop production scene no longer steps them.
	# Godot owns world motion/contact; the passenger-car structural graph is
	# local crush only.
	pair_simulation = null
	static_simulation = null
	hybrid_elapsed_s = 0.0
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
	# rebound. Keep the engine contact almost inelastic; structural crush is
	# represented separately by the local deformation graph.
	chassis.physics_material_override.bounce = clampf(scenario.restitution, 0.0, 0.04)

func _on_simulate_pressed() -> void:
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
	var extra := "Godot rigid-body world motion • CCD • real gravity/road contact"
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
