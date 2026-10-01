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
	return scenario != null and scenario.primary_type != ScenarioConfig.TARGET_PASSENGER_CAR and TwoVehicleWorld3D.supports_target(scenario.target_type)

func _m23_has_non_passenger_primary() -> bool:
	return scenario != null and scenario.primary_type != ScenarioConfig.TARGET_PASSENGER_CAR

func _target_supports_hybrid_world() -> bool:
	if _m23_uses_vehicle_world():
		return true
	if _m23_has_non_passenger_primary():
		return false
	return super._target_supports_hybrid_world()

func _rebuild_preview() -> void:
	if not _m23_has_non_passenger_primary():
		super._rebuild_preview()
		return
	_m23_dispose_vehicle_world()
	super._clear_runtime_objects()
	if not _m23_uses_vehicle_world():
		status_label.text = "%s primary is currently available against movable vehicles and fixed fixtures only" % ScenarioConfig.actor_display_name(scenario.primary_type)
		return
	var physics_errors := TwoVehicleWorld3D.contact_setting_errors(scenario)
	if not physics_errors.is_empty():
		status_label.text = "Preflight failed: %s" % "; ".join(physics_errors)
		return
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
	if not _m23_has_non_passenger_primary():
		super._on_simulate_pressed()
		return
	if not _m23_uses_vehicle_world():
		simulation_running = false
		simulation_paused = false
		status_label.text = "%s primary cannot run against this target yet; CrashVector will not substitute a passenger-car simulation" % ScenarioConfig.actor_display_name(scenario.primary_type)
		return
	var errors := scenario.validation_errors()
	errors.append_array(TwoVehicleWorld3D.contact_setting_errors(scenario))
	if not errors.is_empty():
		status_label.text = "Preflight failed: %s" % "; ".join(errors)
		return
	_stop_replay()
	analysis_report.clear()
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
	if _m23_replay_supported():
		replay_recorder.begin(1.0 / 120.0)
		replay_time_s = 0.0
		_reset_analysis_ui()
		_capture_replay_frame(true)

func _physics_process(delta: float) -> void:
	if not _m23_has_non_passenger_primary():
		super._physics_process(delta)
		return
	if not _m23_uses_vehicle_world():
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
		if _m23_replay_supported():
			_capture_replay_frame(true)
			_finalize_recording()
		else:
			status_label.text = "Complete — transform replay for the tank actor is not available yet"
		_m162_restore_scenario_definition()
		_update_metrics()
		return
	if _m23_replay_supported():
		_capture_replay_frame(false)
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
		var actor := m23_vehicle_world.primary_actor
		if _m161_has_replay():
			var model := _m23_actor_model(actor)
			if model != null:
				return model.center_of_mass_m()
		var bounds := VehicleActorRuntime.collision_footprint_bounds(actor)
		if not bounds.is_empty():
			return Vector3(
				(float(bounds["min_x"]) + float(bounds["max_x"])) * 0.5,
				0.0,
				(float(bounds["min_z"]) + float(bounds["max_z"])) * 0.5
			)
		var chassis := VehicleActorRuntime.chassis(actor)
		if chassis != null:
			return chassis.global_position
	return super._m161_primary_center()

func _m161_target_center() -> Vector3:
	if m23_vehicle_world != null and is_instance_valid(m23_vehicle_world):
		var actor := m23_vehicle_world.target_actor
		if _m161_has_replay():
			var model := _m23_actor_model(actor)
			if model != null:
				return model.center_of_mass_m()
		var bounds := VehicleActorRuntime.collision_footprint_bounds(actor)
		if not bounds.is_empty():
			return Vector3(
				(float(bounds["min_x"]) + float(bounds["max_x"])) * 0.5,
				0.0,
				(float(bounds["min_z"]) + float(bounds["max_z"])) * 0.5
			)
		var chassis := VehicleActorRuntime.chassis(actor)
		if chassis != null:
			return chassis.global_position
	return super._m161_target_center()

func _m161_primary_half_length() -> float:
	var bounds := _m23_actor_horizontal_bounds(m23_vehicle_world.primary_actor if m23_vehicle_world != null else null)
	if not bounds.is_empty():
		return (float(bounds["max_x"]) - float(bounds["min_x"])) * 0.5
	return super._m161_primary_half_length()

func _m161_target_half_length() -> float:
	if _m23_uses_vehicle_world():
		var bounds := _m23_actor_horizontal_bounds(m23_vehicle_world.target_actor if m23_vehicle_world != null else null)
		if not bounds.is_empty():
			return (float(bounds["max_x"]) - float(bounds["min_x"])) * 0.5
	return super._m161_target_half_length()

func _m161_horizontal_bounds() -> Vector2:
	if not _m23_uses_vehicle_world():
		return super._m161_horizontal_bounds()
	var primary_bounds := _m23_actor_horizontal_bounds(m23_vehicle_world.primary_actor if m23_vehicle_world != null else null)
	var target_bounds := _m23_actor_horizontal_bounds(m23_vehicle_world.target_actor if m23_vehicle_world != null else null)
	if primary_bounds.is_empty() or target_bounds.is_empty():
		return super._m161_horizontal_bounds()
	return Vector2(
		minf(float(primary_bounds["min_x"]), float(target_bounds["min_x"])),
		maxf(float(primary_bounds["max_x"]), float(target_bounds["max_x"]))
	)

func _m23_actor_horizontal_bounds(actor: Node) -> Dictionary:
	if actor == null:
		return {}
	# Replay snapshots move the structural model while the authoritative rigid body
	# remains at the final simulation pose. Use the replayed structure in that
	# state; otherwise use the live collision shapes so heading and articulation
	# are represented by the geometry actually participating in contact.
	if _m161_has_replay():
		var replay_bounds := VehicleActorRuntime.structural_footprint_bounds(actor)
		if not replay_bounds.is_empty():
			return replay_bounds
	return VehicleActorRuntime.collision_footprint_bounds(actor)

func _m161_auto_title() -> String:
	if scenario.primary_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		return super._m161_auto_title()
	return "%s vs %s" % [ScenarioConfig.actor_display_name(scenario.primary_type), ScenarioConfig.target_display_name(scenario.target_type)]

func _m23_refresh_primary_options() -> void:
	if m10_primary_option == null:
		return
	m10_primary_option.clear()
	# Keep the established passenger archetypes directly selectable. The primary
	# picker is user-facing vehicle choice, not an internal actor-type enum; the
	# non-passenger actor families follow after a separator.
	for preset_id in PassengerCarCatalog.preset_ids():
		m10_primary_option.add_item(PassengerCarCatalog.display_name(preset_id))
		m10_primary_option.set_item_metadata(m10_primary_option.item_count - 1, preset_id)
	m10_primary_option.add_separator("Other primary vehicles")
	for actor_type in ScenarioConfig.vehicle_actor_ids():
		if actor_type == ScenarioConfig.TARGET_PASSENGER_CAR:
			continue
		m10_primary_option.add_item(ScenarioConfig.actor_display_name(actor_type))
		m10_primary_option.set_item_metadata(m10_primary_option.item_count - 1, actor_type)

func _on_m10_primary_class_selected(index: int) -> void:
	if m10_syncing:
		return
	var sender := get_signal_sender()
	if sender == m10_primary_option:
		if index < 0 or index >= m10_primary_option.item_count:
			return
		var selection_id := _item_metadata_id(m10_primary_option, index)
		if selection_id.is_empty():
			return
		if PassengerCarCatalog.preset_ids().has(selection_id):
			scenario.primary_type = ScenarioConfig.TARGET_PASSENGER_CAR
			scenario.car_preset_id = selection_id
			scenario.car_mass_kg = PassengerCarCatalog.default_mass_kg(selection_id)
		else:
			scenario.apply_primary_vehicle_defaults(selection_id)
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
	_select_metadata(m10_primary_option, scenario.car_preset_id if scenario.primary_type == ScenarioConfig.TARGET_PASSENGER_CAR else scenario.primary_type)
	if m10_primary_class != null:
		m10_primary_class.get_parent().visible = scenario.primary_type == ScenarioConfig.TARGET_PASSENGER_CAR
		_select_metadata(m10_primary_class, scenario.car_preset_id)
	_m23_set_primary_spin_ranges()
	_m23_sync_physics_controls()
	m10_vehicle_mass.set_value_no_signal(scenario.car_mass_kg)
	m10_vehicle_speed.set_value_no_signal(scenario.car_speed_kmh)
	var primary_name := PassengerCarCatalog.display_name(scenario.car_preset_id) if scenario.primary_type == ScenarioConfig.TARGET_PASSENGER_CAR else ScenarioConfig.actor_display_name(scenario.primary_type)
	m10_metrics_summary.text = "%s\n%.0f kg • %.0f km/h\nvs %s" % [
		primary_name, scenario.car_mass_kg, scenario.car_speed_kmh,
		ScenarioConfig.target_display_name(scenario.target_type)
	]
	m10_syncing = false

func _m23_sync_physics_controls() -> void:
	if m10_substeps == null:
		return
	var role_neutral_rigidbody := _m23_has_non_passenger_primary()
	m10_substeps.editable = not role_neutral_rigidbody
	if m10_friction != null:
		# For normal M23 values, make the actual supported range the UI range.
		# If an imported scenario already exceeds it, retain that exact value so the
		# user can see/fix the invalid input; preflight rejects it rather than
		# silently rewriting the scenario.
		m10_friction.max_value = (
			maxf(TwoVehicleWorld3D.MAX_CONTACT_FRICTION, scenario.contact_friction)
			if role_neutral_rigidbody else 1.5
		)
	if m10_restitution != null:
		m10_restitution.max_value = (
			maxf(TwoVehicleWorld3D.MAX_CONTACT_RESTITUTION, scenario.restitution)
			if role_neutral_rigidbody else 0.5
		)
	if role_neutral_rigidbody:
		m10_substeps.tooltip_text = "The M23 RigidBody3D world runs at the project physics tick and does not use the legacy structural-solver substep setting."
		if m10_friction != null:
			m10_friction.tooltip_text = "M23 RigidBody3D contact supports friction from 0.00 to %.2f; larger imported values fail preflight rather than being silently clamped." % TwoVehicleWorld3D.MAX_CONTACT_FRICTION
		if m10_restitution != null:
			m10_restitution.tooltip_text = "M23 RigidBody3D contact supports restitution from 0.00 to %.2f; larger imported values fail preflight rather than being silently clamped." % TwoVehicleWorld3D.MAX_CONTACT_RESTITUTION
	else:
		m10_substeps.tooltip_text = ""
		if m10_friction != null:
			m10_friction.tooltip_text = ""
		if m10_restitution != null:
			m10_restitution.tooltip_text = ""
	for control_data in [
		[m10_friction, "Contact friction (RigidBody3D 0–%.2f)" % TwoVehicleWorld3D.MAX_CONTACT_FRICTION, "Contact friction"],
		[m10_restitution, "Restitution (RigidBody3D 0–%.2f)" % TwoVehicleWorld3D.MAX_CONTACT_RESTITUTION, "Restitution"],
		[m10_substeps, "Solver substeps (not used by RigidBody3D)", "Solver substeps"],
	]:
		var control := control_data[0] as SpinBox
		if control == null:
			continue
		var control_row := control.get_parent()
		if control_row != null and control_row.get_child_count() > 0 and control_row.get_child(0) is Label:
			(control_row.get_child(0) as Label).text = String(control_data[1] if role_neutral_rigidbody else control_data[2])
	var row := m10_substeps.get_parent()
	var column := row.get_parent() if row != null else null
	if column != null:
		var warning := column.get_node_or_null("PhysicsScopeWarning") as Label
		if warning != null:
			warning.text = (
				"RigidBody3D contact uses friction 0–%.2f and restitution 0–%.2f. Solver substeps belong to the structural solver and do not affect this path."
				% [TwoVehicleWorld3D.MAX_CONTACT_FRICTION, TwoVehicleWorld3D.MAX_CONTACT_RESTITUTION]
			) if role_neutral_rigidbody else "Advanced contact/solver values change the numerical scenario. Presentation controls do not."

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

func _m23_replay_supported() -> bool:
	return _m23_actor_model(_m23_primary_actor()) != null and _m23_actor_model(_m23_target_actor()) != null

func _m23_primary_actor() -> Node3D:
	return m23_vehicle_world.primary_actor if m23_vehicle_world != null else null

func _m23_target_actor() -> Node3D:
	return m23_vehicle_world.target_actor if m23_vehicle_world != null else null

func _m23_actor_model(actor: Node) -> StructuralModel:
	if actor == null:
		return null
	var value: Variant = actor.get("model")
	return value as StructuralModel if value is StructuralModel else null

func _m23_actor_metrics(actor: Node3D, mass_kg: float) -> Dictionary:
	var model := _m23_actor_model(actor)
	var velocity := VehicleActorRuntime.linear_velocity_ms(actor)
	var result := {
		"mass_kg": mass_kg,
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": VehicleActorRuntime.momentum_kg_ms(actor),
		"kinetic_energy_j": VehicleActorRuntime.kinetic_energy_j(actor),
		"broken_beams": 0 if model == null else model.broken_beam_count(),
		"plastic_energy_j": 0.0 if model == null else model.total_plastic_energy_j(),
		"elastic_energy_j": 0.0 if model == null else model.total_elastic_energy_j(),
	}
	result.merge(VehicleActorRuntime.deformation_metrics(actor), true)
	return result

func _m23_actor_visual_state(actor: Node) -> Dictionary:
	if actor != null and actor.has_method("replay_visual_state"):
		var state: Variant = actor.call("replay_visual_state")
		return state as Dictionary if state is Dictionary else {}
	return {}

func _capture_replay_frame(force: bool) -> void:
	if not _m23_uses_vehicle_world():
		super._capture_replay_frame(force)
		return
	if not _m23_replay_supported():
		return
	var primary := _m23_primary_actor()
	var target := _m23_target_actor()
	var primary_model := _m23_actor_model(primary)
	var target_model := _m23_actor_model(target)
	var primary_contact_count := VehicleActorRuntime.contact_event_count(primary)
	var target_contact_count := VehicleActorRuntime.contact_event_count(target)
	var context := {
		# Both rigid bodies report the same physical pair contact independently.
		# Preserve a monotonic event counter without double-counting the two sides.
		"contact_count": maxi(primary_contact_count, target_contact_count),
		"primary_contact_manifold": VehicleActorRuntime.contact_manifold_diagnostics(primary),
		"target_contact_manifold": VehicleActorRuntime.contact_manifold_diagnostics(target),
		"energy_balance_relative_error": 0.0,
		"contact_dissipation_j": 0.0,
		"world": "role_neutral_rigidbody_pair",
	}
	if force:
		replay_recorder.force_final(hybrid_elapsed_s, primary_model, target_model, _m23_actor_metrics(primary, scenario.car_mass_kg), _m23_actor_metrics(target, scenario.target_mass_kg), context, _m23_actor_visual_state(primary), _m23_actor_visual_state(target))
	else:
		replay_recorder.capture(hybrid_elapsed_s, primary_model, target_model, _m23_actor_metrics(primary, scenario.car_mass_kg), _m23_actor_metrics(target, scenario.target_mass_kg), context, _m23_actor_visual_state(primary), _m23_actor_visual_state(target))

func _apply_replay_time(time_s: float, from_playback: bool) -> void:
	if not _m23_uses_vehicle_world():
		super._apply_replay_time(time_s, from_playback)
		return
	if not _m23_replay_supported() or replay_recorder.recording == null:
		return
	replay_time_s = clampf(time_s, 0.0, replay_recorder.recording.duration_s)
	var frame := replay_recorder.recording.frame_at_time(replay_time_s)
	if frame.is_empty():
		return
	var primary_state: Variant = frame.get("primary_state", {})
	var target_state: Variant = frame.get("target_state", {})
	if primary_state is Dictionary:
		StructuralSnapshot.apply(_m23_actor_model(_m23_primary_actor()), primary_state)
		VehicleActorRuntime.step_external(_m23_primary_actor(), 0.0)
	if target_state is Dictionary:
		StructuralSnapshot.apply(_m23_actor_model(_m23_target_actor()), target_state)
		VehicleActorRuntime.step_external(_m23_target_actor(), 0.0)
	var primary_visual: Variant = frame.get("primary_visual_state", {})
	var target_visual: Variant = frame.get("target_visual_state", {})
	if primary_visual is Dictionary and _m23_primary_actor() != null and _m23_primary_actor().has_method("apply_replay_visual_state"):
		_m23_primary_actor().call("apply_replay_visual_state", primary_visual)
	if target_visual is Dictionary and _m23_target_actor() != null and _m23_target_actor().has_method("apply_replay_visual_state"):
		_m23_target_actor().call("apply_replay_visual_state", target_visual)
	syncing_replay_ui = true
	timeline_slider.value = replay_time_s
	syncing_replay_ui = false
	_update_replay_time_label()
	if not from_playback:
		status_label.text = "Recorded replay scrubbed to %.2f s" % replay_time_s

func _refresh_analysis_overlay() -> void:
	if not _m23_uses_vehicle_world():
		super._refresh_analysis_overlay()
		return
	if analysis_overlay == null:
		return
	analysis_overlay.configure(_m23_actor_model(_m23_primary_actor()), _m23_actor_model(_m23_target_actor()))
	analysis_overlay.set_enabled(vectors_check == null or vectors_check.button_pressed)

func _has_exportable_replay() -> bool:
	return super._has_exportable_replay()

func _on_export_button_pressed() -> void:
	super._on_export_button_pressed()
