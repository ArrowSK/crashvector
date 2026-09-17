# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m22.gd"

# M23 makes the production editor role-neutral for movable vehicle pairs.
# The existing passenger-car path remains responsible for vehicle-to-static and
# vehicle-to-road-user scenarios while this world owns every combination where
# both actors are movable vehicles.  There is deliberately no type-pair switch:
# both roles pass through VehicleActorFactory and VehicleActorRuntime.

var m23_vehicle_world: TwoVehicleWorld3D

func _ready() -> void:
	super._ready()
	_m23_refresh_primary_options()
	_sync_m10_from_scenario()

func _m23_uses_vehicle_world() -> bool:
	# Keep the established passenger-primary production path intact while it is
	# still the owner of static fixtures, road users, replay and export. The
	# shared world is the reciprocal path: truck/lorry/motorcycle/tank primary
	# against any movable vehicle target. This avoids changing existing car-versus
	# target behavior merely because a common actor contract now exists.
	return scenario != null and scenario.primary_type != ScenarioConfig.TARGET_PASSENGER_CAR and ScenarioConfig.is_vehicle_actor_id(scenario.target_type)

func _target_supports_hybrid_world() -> bool:
	if _m23_uses_vehicle_world():
		return true
	return super._target_supports_hybrid_world()

func _rebuild_preview() -> void:
	if not _m23_uses_vehicle_world():
		super._rebuild_preview()
		return
	_m23_dispose_vehicle_world()
	super._clear_runtime_objects()
	m23_vehicle_world = TwoVehicleWorld3D.new()
	m23_vehicle_world.name = "VehiclePairWorld"
	# The editor already provides the single authoritative road collider and its
	# matching presentation surface.  Adding another coincident road creates a
	# second contact surface and can destabilise suspension at rest.
	m23_vehicle_world.build_road = false
	add_child(m23_vehicle_world)
	if not m23_vehicle_world.configure(scenario):
		m23_vehicle_world.queue_free()
		m23_vehicle_world = null
		status_label.text = "Vehicle-pair setup failed; no simulation was started"
		return
	status_label.text = "Editable vehicle-pair preview — press Simulate when ready"
	_update_metrics()

func _clear_runtime_objects() -> void:
	_m23_dispose_vehicle_world()
	super._clear_runtime_objects()

func _m23_dispose_vehicle_world() -> void:
	if m23_vehicle_world == null or not is_instance_valid(m23_vehicle_world):
		m23_vehicle_world = null
		return
	m23_vehicle_world.stop()
	if m23_vehicle_world.get_parent() == self:
		remove_child(m23_vehicle_world)
	m23_vehicle_world.queue_free()
	m23_vehicle_world = null

func _on_simulate_pressed() -> void:
	if not _m23_uses_vehicle_world():
		super._on_simulate_pressed()
		return
	var errors := scenario.validation_errors()
	if not errors.is_empty():
		status_label.text = "Preflight failed: %s" % "; ".join(errors)
		return
	m162_scenario_snapshot = scenario.to_dictionary().duplicate(true)
	_rebuild_preview()
	if m23_vehicle_world == null:
		m162_scenario_snapshot.clear()
		return
	simulation_running = true
	simulation_paused = false
	hybrid_production_active = true
	hybrid_elapsed_s = 0.0
	pause_button.disabled = false
	pause_button.text = "Pause"
	m23_vehicle_world.begin()
	status_label.text = "Simulation running"

func _physics_process(delta: float) -> void:
	if not _m23_uses_vehicle_world():
		super._physics_process(delta)
		return
	if not simulation_running or simulation_paused:
		return
	hybrid_elapsed_s += delta
	if m23_vehicle_world == null or not m23_vehicle_world.running or hybrid_elapsed_s >= scenario.duration_s:
		if m23_vehicle_world != null:
			m23_vehicle_world.stop()
		simulation_running = false
		pause_button.disabled = true
		pause_button.text = "Pause"
		status_label.text = "Complete — vehicle-pair replay capture is being migrated to the shared actor contract"
		_m162_restore_scenario_definition()
		_update_metrics()
		return
	_update_metrics()

func _on_pause_pressed() -> void:
	if not _m23_uses_vehicle_world():
		super._on_pause_pressed()
		return
	if not simulation_running:
		return
	simulation_paused = not simulation_paused
	if m23_vehicle_world != null:
		m23_vehicle_world.set_paused(simulation_paused)
	pause_button.text = "Resume" if simulation_paused else "Pause"
	status_label.text = "Simulation paused" if simulation_paused else "Simulation running"

func _stop_hybrid_motion() -> void:
	if m23_vehicle_world != null:
		m23_vehicle_world.stop()
	super._stop_hybrid_motion()

func _move_selected(delta_m: Vector3) -> void:
	if not _m23_uses_vehicle_world():
		super._move_selected(delta_m)
		return
	if delta_m.is_zero_approx() or m23_vehicle_world == null:
		return
	if selected_object == &"car":
		scenario.car_position_m += delta_m
		VehicleActorRuntime.set_preview_pose(m23_vehicle_world.primary_actor, scenario.car_position_m, scenario.car_heading_deg)
	else:
		scenario.target_position_m += delta_m
		VehicleActorRuntime.set_preview_pose(m23_vehicle_world.target_actor, scenario.target_position_m, scenario.target_heading_deg)
	_sync_current_object_fields()

func _rotate_selected(delta_deg: float) -> void:
	if not _m23_uses_vehicle_world():
		super._rotate_selected(delta_deg)
		return
	if is_zero_approx(delta_deg) or m23_vehicle_world == null:
		return
	if selected_object == &"car":
		scenario.car_heading_deg = wrapf(scenario.car_heading_deg + delta_deg, -180.0, 180.0)
		VehicleActorRuntime.set_preview_pose(m23_vehicle_world.primary_actor, scenario.car_position_m, scenario.car_heading_deg)
	else:
		scenario.target_heading_deg = wrapf(scenario.target_heading_deg + delta_deg, -180.0, 180.0)
		VehicleActorRuntime.set_preview_pose(m23_vehicle_world.target_actor, scenario.target_position_m, scenario.target_heading_deg)
	_sync_current_object_fields()

func _on_structure_toggled(value: bool) -> void:
	super._on_structure_toggled(value)
	if m23_vehicle_world == null:
		return
	for actor in [m23_vehicle_world.primary_actor, m23_vehicle_world.target_actor]:
		if actor != null and actor.has_method("set_structure_debug"):
			actor.call("set_structure_debug", value)

func _m161_primary_center() -> Vector3:
	if m23_vehicle_world != null and is_instance_valid(m23_vehicle_world):
		var chassis := VehicleActorRuntime.chassis(m23_vehicle_world.primary_actor)
		if chassis != null:
			return chassis.global_position
	return super._m161_primary_center()

func _m161_target_center() -> Vector3:
	if m23_vehicle_world != null and is_instance_valid(m23_vehicle_world):
		var chassis := VehicleActorRuntime.chassis(m23_vehicle_world.target_actor)
		if chassis != null:
			return chassis.global_position
	return super._m161_target_center()

func _m161_primary_half_length() -> float:
	return _m23_vehicle_half_length(scenario.primary_type, scenario.car_preset_id)

func _m161_target_half_length() -> float:
	if _m23_uses_vehicle_world():
		return _m23_vehicle_half_length(scenario.target_type, scenario.target_car_preset_id)
	return super._m161_target_half_length()

func _m161_horizontal_bounds() -> Vector2:
	if not _m23_uses_vehicle_world():
		return super._m161_horizontal_bounds()
	var primary_center := _m161_primary_center()
	var target_center := _m161_target_center()
	var minimum := minf(primary_center.x - _m161_primary_half_length(), target_center.x - _m161_target_half_length())
	var maximum := maxf(primary_center.x + _m161_primary_half_length(), target_center.x + _m161_target_half_length())
	return Vector2(minimum, maximum)

func _m23_vehicle_half_length(actor_type: StringName, passenger_preset: StringName) -> float:
	match actor_type:
		ScenarioConfig.TARGET_PASSENGER_CAR:
			return float(PassengerCarCatalog.data(passenger_preset).get("representative_length_m", 4.1)) * 0.5
		ScenarioConfig.TARGET_TRUCK:
			return 4.8
		ScenarioConfig.TARGET_LORRY:
			return 3.6
		ScenarioConfig.TARGET_MOTORCYCLE:
			return 1.2
		ScenarioConfig.TARGET_TANK:
			return 3.5
	return 2.0

func _m161_auto_title() -> String:
	if scenario.primary_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		return super._m161_auto_title()
	return "%s vs %s" % [ScenarioConfig.actor_display_name(scenario.primary_type), ScenarioConfig.target_display_name(scenario.target_type)]

func _m23_refresh_primary_options() -> void:
	if m10_primary_option == null:
		return
	m10_primary_option.clear()
	for actor_type in ScenarioConfig.vehicle_actor_ids():
		m10_primary_option.add_item(ScenarioConfig.actor_display_name(actor_type))
		m10_primary_option.set_item_metadata(m10_primary_option.item_count - 1, actor_type)

func _on_m10_primary_class_selected(index: int) -> void:
	if m10_syncing:
		return
	var sender := get_signal_sender()
	if sender == m10_primary_option:
		if index < 0 or index >= m10_primary_option.item_count:
			return
		var actor_type := StringName(String(m10_primary_option.get_item_metadata(index)))
		scenario.apply_primary_vehicle_defaults(actor_type)
		selected_object = &"car"
		_request_preview_rebuild()
		_sync_m10_from_scenario()
		return
	if scenario.primary_type != ScenarioConfig.TARGET_PASSENGER_CAR:
		return
	super._on_m10_primary_class_selected(index)

func _sync_m10_from_scenario() -> void:
	super._sync_m10_from_scenario()
	if m10_root == null or scenario == null:
		return
	m10_syncing = true
	_m23_refresh_primary_options()
	_select_metadata(m10_primary_option, scenario.primary_type)
	if m10_primary_class != null:
		m10_primary_class.get_parent().visible = scenario.primary_type == ScenarioConfig.TARGET_PASSENGER_CAR
		_select_metadata(m10_primary_class, scenario.car_preset_id)
	_m23_set_primary_spin_ranges()
	m10_vehicle_mass.set_value_no_signal(scenario.car_mass_kg)
	m10_vehicle_speed.set_value_no_signal(scenario.car_speed_kmh)
	var primary_name := PassengerCarCatalog.display_name(scenario.car_preset_id) if scenario.primary_type == ScenarioConfig.TARGET_PASSENGER_CAR else ScenarioConfig.actor_display_name(scenario.primary_type)
	m10_metrics_summary.text = "%s\n%.0f kg • %.0f km/h\nvs %s" % [
		primary_name, scenario.car_mass_kg, scenario.car_speed_kmh,
		ScenarioConfig.target_display_name(scenario.target_type)
	]
	m10_syncing = false

func _m23_set_primary_spin_ranges() -> void:
	match scenario.primary_type:
		ScenarioConfig.TARGET_PASSENGER_CAR:
			m10_vehicle_mass.min_value = 500.0
			m10_vehicle_mass.max_value = 5000.0
			m10_vehicle_mass.step = 5.0
			m10_vehicle_speed.min_value = 0.0
			m10_vehicle_speed.max_value = 300.0
		ScenarioConfig.TARGET_TRUCK:
			m10_vehicle_mass.min_value = 3500.0
			m10_vehicle_mass.max_value = 60000.0
			m10_vehicle_mass.step = 50.0
			m10_vehicle_speed.min_value = 0.0
			m10_vehicle_speed.max_value = 140.0
		ScenarioConfig.TARGET_LORRY:
			m10_vehicle_mass.min_value = 3500.0
			m10_vehicle_mass.max_value = 26000.0
			m10_vehicle_mass.step = 50.0
			m10_vehicle_speed.min_value = 0.0
			m10_vehicle_speed.max_value = 140.0
		ScenarioConfig.TARGET_MOTORCYCLE:
			m10_vehicle_mass.min_value = 80.0
			m10_vehicle_mass.max_value = 600.0
			m10_vehicle_mass.step = 1.0
			m10_vehicle_speed.min_value = 0.0
			m10_vehicle_speed.max_value = 250.0
		ScenarioConfig.TARGET_TANK:
			m10_vehicle_mass.min_value = 20000.0
			m10_vehicle_mass.max_value = 80000.0
			m10_vehicle_mass.step = 100.0
			m10_vehicle_speed.min_value = 0.0
			m10_vehicle_speed.max_value = 80.0
	m10_vehicle_speed.step = 1.0

func _update_metrics() -> void:
	if not _m23_uses_vehicle_world():
		super._update_metrics()
		return
	if metrics_label == null or m23_vehicle_world == null:
		return
	var primary_velocity := VehicleActorRuntime.linear_velocity_ms(m23_vehicle_world.primary_actor)
	var target_velocity := VehicleActorRuntime.linear_velocity_ms(m23_vehicle_world.target_actor)
	metrics_label.text = "%s • %.0f kg • %.1f km/h\n%s • %.0f kg • %.1f km/h\nGodot RigidBody3D pair world • CCD • gravity • raycast suspension" % [
		ScenarioConfig.actor_display_name(scenario.primary_type), scenario.car_mass_kg, PhysicsMetrics.ms_to_kmh(primary_velocity.length()),
		ScenarioConfig.target_display_name(scenario.target_type), scenario.target_mass_kg, PhysicsMetrics.ms_to_kmh(target_velocity.length()),
	]
