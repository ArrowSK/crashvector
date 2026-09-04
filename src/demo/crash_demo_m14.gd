# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m13.gd"

# M14 closes two production gaps left intentionally blocked/rigid by M12-M13:
# vulnerable road-user targets now have real RigidBody3D world motion, and pole
# / tree targets can yield permanently at high collision demand. The existing
# bicycle/pedestrian structural meshes remain presentation/contact proxies only.

var road_user_proxy: RoadUserRigidProxy3D

func _target_supports_hybrid_world() -> bool:
	if scenario != null and scenario.target_type in [ScenarioConfig.TARGET_BICYCLE, ScenarioConfig.TARGET_PEDESTRIAN]:
		return true
	return super._target_supports_hybrid_world()

func _rebuild_preview() -> void:
	_dispose_road_user_proxy()
	super._rebuild_preview()
	if scenario == null or not _is_road_user_target():
		return
	_replace_legacy_road_user_with_rigid_proxy()

func _replace_legacy_road_user_with_rigid_proxy() -> void:
	if bicycle != null and is_instance_valid(bicycle) and bicycle.get_parent() == self:
		remove_child(bicycle)
		bicycle.queue_free()
	if pedestrian != null and is_instance_valid(pedestrian) and pedestrian.get_parent() == self:
		remove_child(pedestrian)
		pedestrian.queue_free()
	bicycle = null
	pedestrian = null
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true

	road_user_proxy = RoadUserRigidProxy3D.new()
	road_user_proxy.name = "RoadUserRigidProxy"
	road_user_proxy.configure(
		scenario.target_type,
		scenario.target_preset_id,
		scenario.target_mass_kg,
		scenario.target_speed_kmh,
		scenario.target_position_m,
		scenario.target_heading_deg,
		scenario.show_structure
	)
	add_child(road_user_proxy)
	bicycle = road_user_proxy.bicycle_visual
	pedestrian = road_user_proxy.pedestrian_visual
	if status_label != null:
		status_label.text = "M14 rigid-body road-user preview — press Simulate"
	_update_metrics()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not hybrid_production_active or not simulation_running or simulation_paused or car == null or car.rigid_chassis == null:
		return
	if road_user_proxy != null and is_instance_valid(road_user_proxy):
		if car.rigid_chassis.front_crush_overlap_active() and car.rigid_chassis.front_crush_collider() == road_user_proxy:
			road_user_proxy.apply_probe_contact(car.rigid_chassis)
	elif obstacle != null and is_instance_valid(obstacle):
		if scenario.target_type == ScenarioConfig.TARGET_POLE or scenario.target_type == ScenarioConfig.TARGET_TREE:
			obstacle.apply_collision_demand(car.hybrid_collision_energy_j(), car.rigid_chassis.global_transform.basis.x.normalized())

func _on_simulate_pressed() -> void:
	super._on_simulate_pressed()
	if simulation_running and hybrid_production_active and road_user_proxy != null and is_instance_valid(road_user_proxy):
		road_user_proxy.begin_simulation()

func _on_pause_pressed() -> void:
	super._on_pause_pressed()
	if road_user_proxy != null and is_instance_valid(road_user_proxy):
		road_user_proxy.set_simulation_paused(simulation_paused)

func _stop_hybrid_motion() -> void:
	if road_user_proxy != null and is_instance_valid(road_user_proxy):
		road_user_proxy.end_simulation()
	super._stop_hybrid_motion()

func _clear_runtime_objects() -> void:
	_dispose_road_user_proxy()
	super._clear_runtime_objects()

func _dispose_road_user_proxy() -> void:
	if road_user_proxy == null or not is_instance_valid(road_user_proxy):
		road_user_proxy = null
		return
	# The inherited road-user variables point at presentation children of this
	# proxy. Clear those first so the historical cleanup code never tries to
	# remove a grandchild directly from the editor root.
	if bicycle != null and bicycle.get_parent() == road_user_proxy:
		bicycle = null
	if pedestrian != null and pedestrian.get_parent() == road_user_proxy:
		pedestrian = null
	if road_user_proxy.get_parent() == self:
		remove_child(road_user_proxy)
	road_user_proxy.queue_free()
	road_user_proxy = null

func _move_selected(delta_m: Vector3) -> void:
	if selected_object == &"target" and road_user_proxy != null and is_instance_valid(road_user_proxy):
		if delta_m.is_zero_approx():
			return
		scenario.target_position_m += delta_m
		road_user_proxy.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		_sync_current_object_fields()
		return
	super._move_selected(delta_m)

func _rotate_selected(delta_deg: float) -> void:
	if selected_object == &"target" and road_user_proxy != null and is_instance_valid(road_user_proxy):
		if is_zero_approx(delta_deg):
			return
		scenario.target_heading_deg = wrapf(scenario.target_heading_deg + delta_deg, -180.0, 180.0)
		road_user_proxy.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		_sync_current_object_fields()
		return
	super._rotate_selected(delta_deg)

func _capture_replay_frame(force: bool) -> void:
	if road_user_proxy == null or not is_instance_valid(road_user_proxy):
		super._capture_replay_frame(force)
		return
	if car == null or car.model == null:
		return
	var target_model := road_user_proxy.target_model()
	var target_metrics := _road_user_rigid_metrics()
	var context := _current_replay_context()
	var time_s := _simulation_elapsed_s()
	if force:
		replay_recorder.force_final(
			time_s,
			car.model,
			target_model,
			_passenger_car_metrics(car),
			target_metrics,
			context,
			car.replay_visual_state(),
			road_user_proxy.replay_visual_state()
		)
	else:
		replay_recorder.capture(
			time_s,
			car.model,
			target_model,
			_passenger_car_metrics(car),
			target_metrics,
			context,
			car.replay_visual_state(),
			road_user_proxy.replay_visual_state()
		)

func _apply_replay_time(time_s: float, from_playback: bool) -> void:
	super._apply_replay_time(time_s, from_playback)
	if road_user_proxy == null or not is_instance_valid(road_user_proxy) or replay_recorder.recording == null:
		return
	var frame := replay_recorder.recording.frame_at_time(replay_time_s)
	if frame.is_empty():
		return
	var target_visual_state: Variant = frame.get("target_visual_state", {})
	if target_visual_state is Dictionary:
		road_user_proxy.apply_replay_visual_state(target_visual_state)

func _road_user_rigid_metrics() -> Dictionary:
	if road_user_proxy == null:
		return {}
	var model := road_user_proxy.target_model()
	var velocity := road_user_proxy.linear_velocity
	var result := {
		"mass_kg": road_user_proxy.mass,
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": velocity * road_user_proxy.mass,
		"kinetic_energy_j": 0.5 * road_user_proxy.mass * velocity.length_squared(),
		"broken_beams": 0 if model == null else model.broken_beam_count(),
		"plastic_energy_j": 0.0 if model == null else model.total_plastic_energy_j(),
		"elastic_energy_j": 0.0 if model == null else model.total_elastic_energy_j(),
	}
	return result

func _refresh_analysis_overlay() -> void:
	if road_user_proxy == null or not is_instance_valid(road_user_proxy):
		super._refresh_analysis_overlay()
		return
	# The road-user structural graph is local to the rigid target. Until the
	# vector overlay learns per-model transforms, show the authoritative car
	# vectors only rather than drawing a target vector at local origin.
	if analysis_overlay != null and car != null and car.model != null:
		analysis_overlay.configure(car.model, null)
		analysis_overlay.set_enabled(vectors_check == null or vectors_check.button_pressed)

func _update_metrics() -> void:
	super._update_metrics()
	if metrics_label == null or scenario == null:
		return
	if road_user_proxy != null and is_instance_valid(road_user_proxy):
		metrics_label.text += "\nM14 target: %s • %.1f km/h • travel %.2f m • max vertical %.1f km/h • contact %s" % [
			ScenarioConfig.target_display_name(scenario.target_type),
			road_user_proxy.target_speed_kmh(),
			road_user_proxy.maximum_travel_m,
			PhysicsMetrics.ms_to_kmh(road_user_proxy.maximum_vertical_speed_ms),
			"yes" if road_user_proxy.impact_received else "no",
		]
	elif obstacle != null and is_instance_valid(obstacle) and (scenario.target_type == ScenarioConfig.TARGET_POLE or scenario.target_type == ScenarioConfig.TARGET_TREE):
		metrics_label.text += "\nM14 target yielding: %.1f°%s" % [
			obstacle.bend_angle_deg(),
			" • base failure" if obstacle.has_failed() else "",
		]
