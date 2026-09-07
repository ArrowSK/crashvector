# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished := false

func _initialize() -> void:
	create_timer(120.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	_check_preflight_scope()
	await _check_moving_pedestrian_initial_motion()
	await _check_cyclist_proxy_topology_and_release()
	await _check_production_cyclist_routing()
	_finish()

func _check_preflight_scope() -> void:
	var pedestrian := ScenarioConfig.new()
	pedestrian.apply_target_defaults(ScenarioConfig.TARGET_PEDESTRIAN)
	pedestrian.car_position_m = Vector3(-6.0, 0.0, 0.0)
	pedestrian.target_position_m = Vector3(3.0, 0.0, 0.0)
	pedestrian.target_speed_kmh = 5.0
	_expect(pedestrian.validation_errors().is_empty(), "M22 moving pedestrian at 5 km/h must pass preflight")
	pedestrian.target_speed_kmh = 21.0
	_expect(not pedestrian.validation_errors().is_empty(), "M22 pedestrian speed above 20 km/h must remain rejected")

	var cyclist := ScenarioConfig.new()
	cyclist.apply_target_defaults(ScenarioConfig.TARGET_CYCLIST)
	cyclist.car_position_m = Vector3(-6.0, 0.0, 0.0)
	cyclist.target_position_m = Vector3(3.0, 0.0, 0.0)
	cyclist.target_heading_deg = -90.0
	cyclist.target_speed_kmh = 18.0
	_expect(cyclist.validation_errors().is_empty(), "M22 cyclist broadside/oblique layouts must pass generic contact/trajectory preflight")

	var riderless := ScenarioConfig.new()
	riderless.apply_target_defaults(ScenarioConfig.TARGET_BICYCLE)
	riderless.car_position_m = Vector3(-6.0, 0.0, 0.0)
	riderless.target_position_m = Vector3(3.0, 0.0, 0.0)
	riderless.target_heading_deg = -90.0
	_expect(not riderless.validation_errors().is_empty(), "M22 must not silently broaden the old riderless-bicycle broadside scope")

func _check_moving_pedestrian_initial_motion() -> void:
	var proxy := M22RoadUserProxy3D.new()
	proxy.name = "M22MovingPedestrian"
	proxy.configure(
		ScenarioConfig.TARGET_PEDESTRIAN,
		RoadUserCatalog.PEDESTRIAN_ADULT,
		75.0,
		5.0,
		Vector3.ZERO,
		180.0,
		false
	)
	root.add_child(proxy)
	await process_frame
	proxy.begin_simulation()
	await physics_frame
	var expected_speed := PhysicsMetrics.kmh_to_ms(5.0)
	var measured := proxy.center_of_mass_velocity_ms()
	var expected_direction := Vector3.LEFT
	_expect(measured.dot(expected_direction) > expected_speed * 0.75, "M22 moving pedestrian did not inherit configured heading/speed: %s" % measured)
	_expect(absf(measured.y) < 1.0, "M22 moving pedestrian received an artificial initial vertical velocity: %.3f m/s" % measured.y)
	proxy.end_simulation()
	proxy.queue_free()
	await process_frame

func _check_cyclist_proxy_topology_and_release() -> void:
	var combined_mass := RoadUserCatalog.cyclist_default_mass_kg(RoadUserCatalog.BICYCLE_CITY)
	var proxy := M22RoadUserProxy3D.new()
	proxy.name = "M22CyclistTopology"
	proxy.configure(
		ScenarioConfig.TARGET_CYCLIST,
		RoadUserCatalog.BICYCLE_CITY,
		combined_mass,
		15.0,
		Vector3.ZERO,
		0.0,
		false
	)
	root.add_child(proxy)
	await process_frame

	_expect(proxy.bicycle_visual != null, "M22 cyclist must preserve the bicycle compatibility/reference model")
	_expect(proxy.cyclist_rider_body_count() == 11, "M22 cyclist must expose the generic 11-body rider, got %d" % proxy.cyclist_rider_body_count())
	_expect(proxy.cyclist_coupling_joint_count() == 5, "M22 cyclist must expose seat/hand/foot pre-impact couplings")
	_expect(proxy.articulated_body_count() == 14, "M22 cyclist must contain frame + two wheels + 11 rider bodies, got %d" % proxy.articulated_body_count())
	_expect(proxy.articulated_joint_count() == 17, "M22 cyclist must contain two hub, ten rider and five coupling joints, got %d" % proxy.articulated_joint_count())

	var represented_mass := proxy.mass
	for body in proxy.articulated_bodies:
		if body != null and is_instance_valid(body):
			represented_mass += body.mass
	_expect(absf(represented_mass - combined_mass) < 0.10, "M22 cyclist physical body masses do not preserve combined scenario mass: %.2f vs %.2f kg" % [represented_mass, combined_mass])
	_expect(not proxy.cyclist_released, "M22 cyclist coupling must be attached in preview")

	proxy.begin_simulation()
	await physics_frame
	var source := VehicleRigidChassis.new()
	source.name = "M22CyclistProbeSource"
	root.add_child(source)
	source.configure(1375.0, Vector3(-2.0, 0.0, 0.0), 0.0, 50.0, 0.55, 0.0)
	source.begin_motion(50.0, 0.0)
	proxy.apply_probe_contact(source)
	await physics_frame
	_expect(proxy.impact_received, "M22 cyclist did not accept production-compatible probe contact")
	_expect(proxy.cyclist_released, "M22 cyclist rider coupling did not release on contact")
	for joint in proxy.cyclist_coupling_joints:
		if joint != null and is_instance_valid(joint):
			_expect(joint.node_a.is_empty() and joint.node_b.is_empty(), "M22 cyclist coupling joint remained bound after contact: %s" % joint.name)
	var state := proxy.replay_visual_state()
	_expect(bool(state.get("cyclist_released", false)), "M22 cyclist replay visual state does not preserve release state")
	var part_states: Variant = state.get("part_states", [])
	_expect(part_states is Array and (part_states as Array).size() == 13, "M22 cyclist replay must capture two wheels + 11 rider rigid-body states")
	_expect(_finite_vector(proxy.center_of_mass_velocity_ms()), "M22 cyclist contact produced non-finite centre-of-mass velocity")

	proxy.end_simulation()
	proxy.queue_free()
	source.queue_free()
	await process_frame

func _check_production_cyclist_routing() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M22 production scene must load")
	if packed == null:
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M22 generic cyclist broadside regression"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-7.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 50.0
	config.apply_target_defaults(ScenarioConfig.TARGET_CYCLIST)
	config.target_preset_id = RoadUserCatalog.BICYCLE_CITY
	config.target_mass_kg = RoadUserCatalog.cyclist_default_mass_kg(config.target_preset_id)
	config.target_position_m = Vector3(2.7, 0.0, -0.15)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 0.0
	config.duration_s = 1.8
	config.solver_substeps = 10
	_expect(config.validation_errors().is_empty(), "M22 production cyclist case failed preflight: %s" % "; ".join(config.validation_errors()))
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(10):
		await process_frame
	await physics_frame

	_expect(String(editor.get_script().resource_path).ends_with("crash_demo_m22.gd"), "Production scene does not route through M22")
	var preview_proxy := editor.get("road_user_proxy") as M22RoadUserProxy3D
	_expect(preview_proxy != null and preview_proxy.target_type == ScenarioConfig.TARGET_CYCLIST, "M22 production preview did not instantiate M22RoadUserProxy3D cyclist")
	var skin := editor.get("m162_road_user_skin") as M22RoadUserPresentationSkin3D
	_expect(skin != null and skin.proxy == preview_proxy, "M22 production preview did not install combined rider+bicycle presentation")
	var speed_row := editor.get("m10_target_speed_row") as HBoxContainer
	_expect(speed_row != null and speed_row.visible, "M22 current desktop target controls did not expose cyclist speed")

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1200):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M22 production cyclist run did not complete")
	for _frame in range(5):
		await process_frame

	var cyclist := editor.get("road_user_proxy") as M22RoadUserProxy3D
	_expect(cyclist != null, "M22 cyclist target disappeared during production run")
	if cyclist != null:
		_expect(cyclist.impact_received, "M22 cyclist production case recorded no probe-linked impact")
		_expect(cyclist.cyclist_released, "M22 cyclist production case did not release rider coupling")
		_expect(cyclist.maximum_vertical_speed_ms < 18.0, "M22 cyclist production case produced an implausible vertical launch: %.2f m/s" % cyclist.maximum_vertical_speed_ms)
		_expect(_finite_vector(cyclist.center_of_mass_position()), "M22 cyclist production position became non-finite")
	var recorder := editor.get("replay_recorder") as ReplayRecorder
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "M22 cyclist production case produced no replay")
	if recorder != null and recorder.recording != null:
		var final_state_value: Variant = recorder.recording.last_frame().get("target_visual_state", {})
		_expect(final_state_value is Dictionary and bool((final_state_value as Dictionary).get("cyclist_released", false)), "M22 final replay frame did not preserve cyclist rider-release state")

	editor.queue_free()
	await process_frame

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M22 cyclist/moving-pedestrian regression exceeded 120 seconds")
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M22 cyclist and moving-pedestrian regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
