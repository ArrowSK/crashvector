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
	_check_rider_presentation(motorcycle)
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

func _check_rider_presentation(motorcycle: M20Motorcycle) -> void:
	_expect(motorcycle != null, "Motorcycle rider presentation target is missing")
	if motorcycle == null or motorcycle.rigid_chassis == null:
		return
	var rig := motorcycle.rider_rig
	var chassis := motorcycle.rigid_chassis
	_expect(rig != null, "Motorcycle rider presentation rig is missing")
	if rig == null:
		return
	_expect(rig.rider_body_count() == 2, "Motorcycle rider visual upgrade changed the authoritative two-body physics topology")
	_expect(rig.presentation_segment_count() == 13, "Motorcycle rider presentation must expose articulated pelvis/arms/legs/boots/gloves")
	_expect(rig.rider_presentation_root != null, "Motorcycle rider articulated presentation root is missing")
	if rig.rider_presentation_root != null:
		_expect(
			String(rig.rider_presentation_root.get_meta("presentation_role", "")) == "motorcycle_rider_articulated_skin",
			"Motorcycle rider presentation role metadata is missing"
		)
	_expect(rig.torso != null and rig.torso.get_node_or_null("RiderArms") == null, "Motorcycle rider still contains the old rectangular arm block")
	_expect(rig.torso != null and rig.torso.get_node_or_null("RiderLegs") == null, "Motorcycle rider still contains the old rectangular leg block")

	var pelvis_world := rig.presentation_point(&"pelvis")
	var left_hand_world := rig.presentation_point(&"left_glove")
	var right_hand_world := rig.presentation_point(&"right_glove")
	var pelvis_local := chassis.to_local(pelvis_world)
	var left_hand_local := chassis.to_local(left_hand_world)
	var right_hand_local := chassis.to_local(right_hand_world)
	_expect(pelvis_local.x > 0.25 and pelvis_local.x < 0.65, "Motorcycle rider pelvis is not seated over the bike: %s" % pelvis_local)
	_expect(pelvis_local.y > 0.85 and pelvis_local.y < 1.25, "Motorcycle rider pelvis height is implausible: %s" % pelvis_local)
	_expect(left_hand_local.x > 1.35 and right_hand_local.x > 1.35, "Motorcycle rider hands do not reach forward toward the controls")
	_expect(absf(left_hand_local.y - right_hand_local.y) < 0.05, "Motorcycle rider hands are vertically asymmetric in the seated pose")
	_expect(absf(left_hand_local.z - right_hand_local.z) > 0.45, "Motorcycle rider hands are not separated across the handlebar")

	# Integration guard with the motorcycle skin: the rider must reach the actual
	# grip meshes, not merely point generally forward. This catches future drift
	# between the independent motorcycle and rider presentation layers.
	_expect(motorcycle.handlebar_grips.size() == 2, "Motorcycle rider integration requires two handlebar grips")
	if motorcycle.handlebar_grips.size() == 2:
		_expect(left_hand_world.distance_to(motorcycle.handlebar_grips[0].global_position) < 0.08, "Motorcycle rider left hand is detached from the left handlebar grip")
		_expect(right_hand_world.distance_to(motorcycle.handlebar_grips[1].global_position) < 0.08, "Motorcycle rider right hand is detached from the right handlebar grip")

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
			_check_motorcycle_wheel_geometry(wheel)
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

	# Guard the semantics of visual_collapse_m itself. Changing only a rendered
	# primitive, with the structural model untouched, must change the metric.
	# Otherwise the production impact assertion could become a false green again.
	var neutral_visual_collapse := motorcycle.visual_collapse_m()
	_expect(neutral_visual_collapse < 0.001, "Neutral motorcycle presentation already reports collapse: %.4f m" % neutral_visual_collapse)
	if not motorcycle.front_fork_visuals.is_empty():
		var probe_mesh := motorcycle.front_fork_visuals[0].mesh as CylinderMesh
		_expect(probe_mesh != null, "Motorcycle visual-collapse probe could not access a fork cylinder")
		if probe_mesh != null:
			var original_height := probe_mesh.height
			probe_mesh.height = maxf(original_height - 0.08, 0.02)
			var visual_only_collapse := motorcycle.visual_collapse_m()
			_expect(
				visual_only_collapse > neutral_visual_collapse + 0.06,
				"visual_collapse_m no longer measures rendered geometry independently of the structural model"
			)
			probe_mesh.height = original_height

func _check_motorcycle_wheel_geometry(wheel: Node3D) -> void:
	_expect(_count_named_children(wheel, "WheelSpoke") == 8, "Motorcycle wheel must expose eight visual spokes")
	var tyre := wheel.get_node_or_null("Tyre") as MeshInstance3D
	var rim := wheel.get_node_or_null("Rim") as MeshInstance3D
	_expect(tyre != null and tyre.mesh is TorusMesh, "Motorcycle tyre must be an open torus, not a solid wheel disc")
	_expect(rim != null and rim.mesh is TorusMesh, "Motorcycle rim must be an open torus so the spokes remain visible")
	if tyre != null and tyre.mesh is TorusMesh:
		var tyre_mesh := tyre.mesh as TorusMesh
		_expect(absf(tyre_mesh.outer_radius - 0.340) < 0.002, "Motorcycle tyre outer radius changed unexpectedly")
		_expect(absf(tyre_mesh.inner_radius - 0.235) < 0.002, "Motorcycle tyre inner edge no longer meets the rim envelope")
	if rim != null and rim.mesh is TorusMesh:
		var rim_mesh := rim.mesh as TorusMesh
		_expect(absf(rim_mesh.outer_radius - 0.235) < 0.002, "Motorcycle rim outer radius changed unexpectedly")
		_expect(absf(rim_mesh.inner_radius - 0.180) < 0.002, "Motorcycle rim inner edge no longer meets the spokes")

	for spoke_index in range(8):
		var spoke := wheel.get_node_or_null("WheelSpoke%d" % spoke_index) as MeshInstance3D
		_expect(spoke != null and spoke.mesh is BoxMesh, "Motorcycle wheel spoke %d is missing or has the wrong mesh" % spoke_index)
		if spoke == null or not spoke.mesh is BoxMesh:
			continue
		var spoke_mesh := spoke.mesh as BoxMesh
		var radial := Vector2(spoke.position.x, spoke.position.y)
		_expect(radial.length() > 0.001, "Motorcycle wheel spoke %d is still centred through the hub" % spoke_index)
		if radial.length() <= 0.001:
			continue
		var inner_radius := radial.length() - spoke_mesh.size.x * 0.5
		var outer_radius := radial.length() + spoke_mesh.size.x * 0.5
		_expect(absf(inner_radius - 0.060) < 0.004, "Motorcycle wheel spoke %d does not start at the hub" % spoke_index)
		_expect(absf(outer_radius - 0.180) < 0.004, "Motorcycle wheel spoke %d does not reach the inner rim" % spoke_index)
		var expected_angle := deg_to_rad(float(spoke_index) * 45.0)
		var expected_radial := Vector2(cos(expected_angle), sin(expected_angle))
		_expect(radial.normalized().dot(expected_radial) > 0.995, "Motorcycle wheel spoke %d is not evenly distributed around the wheel" % spoke_index)
		var visual_axis := Vector2(spoke.basis.x.x, spoke.basis.x.y).normalized()
		_expect(absf(visual_axis.dot(radial.normalized())) > 0.995, "Motorcycle wheel spoke %d is not aligned radially" % spoke_index)
		_expect(absf(spoke.position.z) < 0.001, "Motorcycle wheel spoke %d drifted out of the wheel plane" % spoke_index)

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
