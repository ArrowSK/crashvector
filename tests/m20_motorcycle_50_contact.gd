# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _check_preimpact_energy_source()
	var config := ScenarioConfig.new()
	config.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-5.6, 0.0, 0.0)
	config.car_speed_kmh = 50.0
	config.apply_target_defaults(ScenarioConfig.TARGET_MOTORCYCLE)
	config.target_position_m = Vector3(3.2, 0.0, 0.0)
	config.target_mass_kg = 220.0
	config.duration_s = 4.0
	config.solver_substeps = 12
	_expect(config.validation_errors().is_empty(), "50 km/h motorcycle scenario failed preflight")
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "Production scene could not be loaded")
	if packed == null:
		_finish()
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame
	editor.call("_on_simulate_pressed")
	for _frame in range(1300):
		if not bool(editor.get("simulation_running")):
			break
		await physics_frame
	var motorcycle := editor.get("m17_motorcycle") as M20Motorcycle
	var primary := editor.get("car") as M17CompactHatchback
	_expect(not bool(editor.get("simulation_running")), "50 km/h motorcycle run did not complete")
	_expect(primary != null and primary.rigid_chassis != null, "Primary rigid chassis is missing")
	_expect(motorcycle != null and motorcycle.rigid_chassis != null, "Motorcycle rigid chassis is missing")
	if primary != null and primary.rigid_chassis != null:
		_expect(primary.rigid_chassis.non_ground_contact_events > 0, "50 km/h motorcycle run bypassed the primary physical contact")
	if motorcycle != null and motorcycle.rigid_chassis != null:
		_expect(motorcycle.rigid_chassis.non_ground_contact_events > 0, "50 km/h motorcycle run bypassed the motorcycle physical contact")
		_expect(motorcycle.rider_rig != null and motorcycle.rider_rig.rider_body_count() == 2, "Motorcycle must provide the physical rider rig")
		_expect(motorcycle.rider_released_after_contact(), "Motorcycle rider must release only after the real contact")
		_expect(motorcycle.rear_impact_deformation_m() > 0.01 or motorcycle.front_crush_deformation_m() > 0.01 or motorcycle.side_impact_deformation_m() > 0.01, "50 km/h motorcycle impact produced no local structural deformation")
		_expect(motorcycle.visual_collapse_m() > 0.005, "50 km/h motorcycle structural deformation is still hidden by an effectively rigid presentation shell")
		_expect(motorcycle.front_fork_visuals.size() == 2 and motorcycle.rear_swingarm_visuals.size() == 2, "Motorcycle presentation must expose deformable fork and swingarm members")
		_expect(motorcycle.rear_impact_deformation_m() <= 0.241 and motorcycle.front_crush_deformation_m() <= 0.341 and motorcycle.side_impact_deformation_m() <= 0.201, "Motorcycle deformation exceeded its bounded envelope")
	editor.queue_free()
	await process_frame
	_finish()

func _check_preimpact_energy_source() -> void:
	var motorcycle := M20Motorcycle.new()
	motorcycle.total_mass_kg = 220.0
	motorcycle.initial_speed_kmh = 100.0
	motorcycle.origin_offset_m = Vector3.ZERO
	motorcycle.auto_step = false
	root.add_child(motorcycle)
	await process_frame
	_check_motorcycle_presentation(motorcycle)
	_expect(motorcycle.rigid_chassis != null, "Motorcycle pre-impact energy regression could not create the rigid chassis")
	if motorcycle.rigid_chassis == null:
		motorcycle.queue_free()
		await process_frame
		return

	var fixture := StaticBody3D.new()
	fixture.name = "MotorcyclePreImpactFixture"
	fixture.position = Vector3(2.4, 0.0, 0.0)
	root.add_child(fixture)
	motorcycle.rigid_chassis.previous_integrated_linear_velocity_ms = Vector3(5.0, 0.0, 0.0)
	motorcycle.rigid_chassis.last_integrated_linear_velocity_ms = Vector3(1.0, 0.0, 0.0)
	motorcycle.rigid_chassis.last_integrated_physics_frame = Engine.get_physics_frames()
	motorcycle.rigid_chassis.contact_samples.append({
		"collider_name": fixture.name,
		"collider": fixture,
		"position_local": Vector3(1.95, 0.5, 0.0),
		"impulse": Vector3.ZERO,
		"pre_contact_linear_velocity_ms": Vector3(5.0, 0.0, 0.0),
	})
	motorcycle.call("_m20_consume_contacts")
	var expected_energy := 0.5 * motorcycle.rigid_chassis.mass * 25.0
	_expect(absf(motorcycle.hybrid_front_energy_j - expected_energy) < 0.01, "Motorcycle deformation energy used t=0 speed instead of the immediate pre-impact velocity")
	var initial_speed_ms := PhysicsMetrics.kmh_to_ms(motorcycle.initial_speed_kmh)
	var t0_energy := 0.5 * motorcycle.rigid_chassis.mass * initial_speed_ms * initial_speed_ms
	_expect(motorcycle.hybrid_front_energy_j < t0_energy * 0.20, "Motorcycle deformation energy still retains an excessive t=0-speed floor")

	fixture.queue_free()
	motorcycle.queue_free()
	await process_frame

func _check_motorcycle_presentation(motorcycle: M20Motorcycle) -> void:
	_expect(motorcycle != null, "Motorcycle presentation regression could not create the target")
	if motorcycle == null:
		return

	_expect(motorcycle.tank_visual != null and motorcycle.tank_visual.mesh is SphereMesh, "Motorcycle fuel tank is still a rectangular box")
	_expect(motorcycle.fairing_visual != null and motorcycle.fairing_visual.mesh is SphereMesh, "Motorcycle front fairing is still a rectangular box")
	_expect(motorcycle.handlebar_visual != null and motorcycle.handlebar_visual.mesh is CylinderMesh, "Motorcycle handlebar is not a round bar")
	_expect(motorcycle.headlamp_visual != null and motorcycle.headlamp_visual.mesh is CylinderMesh, "Motorcycle headlamp is not a cylindrical lens/body")
	_expect(motorcycle.engine_crankcase_visual != null and motorcycle.engine_crankcase_visual.mesh is CylinderMesh, "Motorcycle crankcase presentation is missing")
	_expect(motorcycle.exhaust_visual != null and motorcycle.exhaust_visual.mesh is CylinderMesh, "Motorcycle exhaust is not a cylindrical muffler")
	_expect(motorcycle.exhaust_tip_visual != null and motorcycle.exhaust_tip_visual.mesh is CylinderMesh, "Motorcycle exhaust tip presentation is missing")
	_expect(motorcycle.footpeg_visual != null and motorcycle.footpeg_visual.mesh is CylinderMesh, "Motorcycle footpeg bar presentation is missing")
	_expect(motorcycle.chain_guard_visual != null and motorcycle.chain_guard_visual.mesh is BoxMesh, "Motorcycle chain guard presentation is missing")
	_expect(motorcycle.handlebar_grips.size() == 2, "Motorcycle must expose two handlebar grips")
	_expect(motorcycle.side_panel_visuals.size() == 2, "Motorcycle must expose two side panels")
	_expect(motorcycle.frame_visuals.size() == 3, "Motorcycle frame presentation lost its three longitudinal members")
	for frame in motorcycle.frame_visuals:
		_expect(frame.mesh is CylinderMesh, "Motorcycle frame still uses rectangular bars")
	_expect(motorcycle.front_fork_visuals.size() == 2 and motorcycle.rear_swingarm_visuals.size() == 2, "Motorcycle presentation must expose two fork and two swingarm members")
	for fork in motorcycle.front_fork_visuals:
		_expect(fork.mesh is CylinderMesh, "Motorcycle fork member is still a rectangular bar")
	for arm in motorcycle.rear_swingarm_visuals:
		_expect(arm.mesh is CylinderMesh, "Motorcycle swingarm member is still a rectangular bar")

	_expect(motorcycle.wheel_roots.size() == 2, "Motorcycle presentation must expose front and rear wheel roots")
	if motorcycle.wheel_roots.size() == 2:
		var wheelbase := motorcycle.wheel_roots[0].position.distance_to(motorcycle.wheel_roots[1].position)
		_expect(wheelbase > 1.65 and wheelbase < 2.15, "Motorcycle visual wheelbase is implausible: %.3f m" % wheelbase)
		for wheel in motorcycle.wheel_roots:
			_expect(_count_named_children(wheel, "WheelSpoke") == 8, "Motorcycle wheel must expose eight visual spokes")
			_expect(wheel.get_node_or_null("Tyre") != null, "Motorcycle wheel tyre presentation is missing")
			_expect(wheel.get_node_or_null("Rim") != null, "Motorcycle wheel rim presentation is missing")
			_expect(wheel.get_node_or_null("WheelHub") != null, "Motorcycle wheel hub presentation is missing")
			_expect(wheel.get_node_or_null("BrakeDisc") != null, "Motorcycle wheel brake-disc presentation is missing")

	_check_cylinder_span(motorcycle.exhaust_visual, "Motorcycle exhaust")
	_check_cylinder_span(motorcycle.exhaust_tip_visual, "Motorcycle exhaust tip")
	_check_cylinder_span(motorcycle.handlebar_visual, "Motorcycle handlebar")
	for fork in motorcycle.front_fork_visuals:
		_check_cylinder_span(fork, "Motorcycle fork")
	for arm in motorcycle.rear_swingarm_visuals:
		_check_cylinder_span(arm, "Motorcycle swingarm")

	var tank_size_value: Variant = motorcycle.tank_visual.get_meta("presentation_size_m", Vector3.ZERO) if motorcycle.tank_visual != null else Vector3.ZERO
	_expect(tank_size_value is Vector3, "Motorcycle tank does not expose presentation dimensions")
	if tank_size_value is Vector3:
		var tank_size := tank_size_value as Vector3
		_expect(tank_size.x > tank_size.z and tank_size.z > tank_size.y, "Motorcycle tank proportions are not longitudinally readable: %s" % tank_size)

func _check_cylinder_span(visual: MeshInstance3D, label: String) -> void:
	_expect(visual != null and visual.mesh is CylinderMesh, "%s is not a cylinder" % label)
	if visual == null or not visual.mesh is CylinderMesh:
		return
	var start_value: Variant = visual.get_meta("presentation_span_start", null)
	var end_value: Variant = visual.get_meta("presentation_span_end", null)
	_expect(start_value is Vector3 and end_value is Vector3, "%s does not expose its structural span" % label)
	if not (start_value is Vector3 and end_value is Vector3):
		return
	var start := start_value as Vector3
	var end := end_value as Vector3
	var delta := end - start
	var length := delta.length()
	_expect(length > 0.03, "%s has a degenerate presentation span" % label)
	if length <= 0.03:
		return
	var axis := visual.basis.y.normalized()
	_expect(absf(axis.dot(delta.normalized())) > 0.995, "%s cylinder axis is not aligned with its structural span" % label)
	var mesh := visual.mesh as CylinderMesh
	_expect(absf(mesh.height - length) < 0.01, "%s cylinder height does not match its structural span" % label)

func _count_named_children(node: Node, wanted_prefix: String) -> int:
	var count := 0
	for child in node.get_children():
		if String(child.name).begins_with(wanted_prefix):
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("CrashVector 50 km/h motorcycle contact and deformation regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
