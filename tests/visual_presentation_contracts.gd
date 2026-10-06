# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

# Cross-target presentation QA. This intentionally stays outside the physics
# implementations: it checks dimensional/placement contracts that should remain
# true even when the underlying visual assets are improved.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _check_passenger_contracts()
	await _check_articulated_truck_contracts()
	await _check_motorcycle_contracts()
	await _check_motorcycle_rider_contracts()
	await _check_cyclist_contracts()

	if failures.is_empty():
		print("CrashVector visual presentation contract regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check_passenger_contracts() -> void:
	var ids := [
		PassengerCarCatalog.A_SEGMENT_CITY,
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		PassengerCarCatalog.C_SEGMENT_COMPACT,
		PassengerCarCatalog.D_SEGMENT_MIDSIZE,
		PassengerCarCatalog.J_SEGMENT_SUV,
		PassengerCarCatalog.M_SEGMENT_MPV,
	]

	var previous_catalog_length := 0.0
	var rendered_lengths: Dictionary = {}
	for preset_id in ids:
		var data := PassengerCarCatalog.data(preset_id)
		var catalog_length := float(data.get("representative_length_m", 0.0))
		var catalog_width := float(data.get("representative_width_m", 0.0))
		_expect(catalog_length > previous_catalog_length, "Passenger catalog length order is not increasing at %s" % preset_id)
		_expect(catalog_length > 3.2 and catalog_length < 5.6, "Passenger catalog length is implausible for %s: %.3f m" % [preset_id, catalog_length])
		_expect(catalog_width > 1.45 and catalog_width < 2.25, "Passenger catalog width is implausible for %s: %.3f m" % [preset_id, catalog_width])
		previous_catalog_length = catalog_length

		var vehicle := M17CompactHatchback.new()
		vehicle.name = "VisualContractPassenger_%s" % preset_id
		vehicle.vehicle_preset_id = preset_id
		vehicle.origin_offset_m = Vector3.ZERO
		vehicle.auto_step = false
		root.add_child(vehicle)
		await process_frame

		var visual := M162VehicleVisual.new()
		visual.name = "VisualContractPassengerSkin_%s" % preset_id
		vehicle.add_child(visual)
		visual.configure(vehicle)
		for _frame in range(3):
			await process_frame

		var skin := visual.kenney_skin
		_expect(skin != null and skin.active, "Passenger %s did not activate its production Kenney skin" % preset_id)
		if skin != null and skin.active and skin.body_instance != null and skin.body_instance.mesh != null:
			var bounds := skin.body_instance.mesh.get_aabb()
			rendered_lengths[preset_id] = bounds.size.x
			_expect(bounds.size.x > 1.8 and bounds.size.x < 5.8, "Passenger %s rendered length is implausible: %.3f m" % [preset_id, bounds.size.x])
			_expect(bounds.size.y > 0.8 and bounds.size.y < 2.3, "Passenger %s rendered height is implausible: %.3f m" % [preset_id, bounds.size.y])
			_expect(bounds.size.z > 1.1 and bounds.size.z < 2.5, "Passenger %s rendered width is implausible: %.3f m" % [preset_id, bounds.size.z])
			_expect(skin.pristine_scale_host.x > 0.001 and skin.pristine_scale_host.z > 0.001, "Passenger %s lost the axis-specific class-fit contract" % preset_id)
			_expect(absf(bounds.size.x - catalog_length) < 0.07, "Passenger %s rendered length no longer follows catalog length" % preset_id)
			_expect(absf(bounds.size.z - catalog_width) < 0.10, "Passenger %s rendered width no longer follows catalog width" % preset_id)

		vehicle.queue_free()
		await process_frame

	_expect(rendered_lengths.size() == ids.size(), "Passenger visual gate did not measure every A/B/C/D/J/M class")
	if rendered_lengths.size() == ids.size():
		for index in range(ids.size() - 1):
			var left: StringName = ids[index]
			var right: StringName = ids[index + 1]
			_expect(float(rendered_lengths[right]) > float(rendered_lengths[left]), "Passenger rendered length order inverted: %s >= %s" % [left, right])

func _check_articulated_truck_contracts() -> void:
	var truck := M21HeavyTruck.new()
	truck.name = "VisualContractArticulatedTruck"
	truck.origin_offset_m = Vector3.ZERO
	truck.auto_step = false
	root.add_child(truck)
	await process_frame

	var visual := M21HeavyTruckVisual.new()
	visual.name = "VisualContractArticulatedTruckSkin"
	truck.add_child(visual)
	visual.configure(truck)
	for _frame in range(3):
		await process_frame

	_expect(truck.wheel_visuals.size() == HeavyTruckBuilder.wheel_anchor_indices().size(), "Articulated truck wheel presentation lost structural axle anchors")
	_expect(visual.trailer_instance != null and visual.trailer_instance.mesh is BoxMesh, "Articulated truck trailer presentation is missing")
	if visual.trailer_instance != null and visual.trailer_instance.mesh is BoxMesh:
		var trailer_size := (visual.trailer_instance.mesh as BoxMesh).size
		_expect(trailer_size.x > 4.8 and trailer_size.x < 8.5, "Articulated truck trailer length is implausible: %.3f m" % trailer_size.x)
		_expect(trailer_size.z > 2.0 and trailer_size.z < 2.8, "Articulated truck trailer width is implausible: %.3f m" % trailer_size.z)

	_expect(visual.tractor_presentation_root != null and visual.trailer_presentation_root != null, "Articulated truck must expose separate tractor/trailer presentation roots")
	_expect(visual.tractor_kenney_skin != null and visual.tractor_kenney_skin.active, "Articulated truck fitted tractor presentation is inactive")
	var gap := float(visual.get_meta("presentation_fifth_wheel_gap_m", 0.0))
	_expect(gap >= 0.10 and gap <= 1.20, "Articulated truck fifth-wheel presentation gap is implausible: %.3f m" % gap)

	truck.queue_free()
	await process_frame

func _check_motorcycle_contracts() -> void:
	var motorcycle := M20Motorcycle.new()
	motorcycle.name = "VisualContractMotorcycle"
	motorcycle.origin_offset_m = Vector3.ZERO
	motorcycle.auto_step = false
	root.add_child(motorcycle)
	await process_frame

	_expect(motorcycle.wheel_roots.size() == 2, "Motorcycle must expose exactly two visual wheel roots")
	if motorcycle.wheel_roots.size() == 2:
		var wheelbase := motorcycle.wheel_roots[0].position.distance_to(motorcycle.wheel_roots[1].position)
		_expect(wheelbase > 1.65 and wheelbase < 2.15, "Motorcycle visual wheelbase is implausible: %.3f m" % wheelbase)

	_expect(motorcycle.front_fork_visuals.size() == 2, "Motorcycle must expose two fork presentation members")
	_expect(motorcycle.rear_swingarm_visuals.size() == 2, "Motorcycle must expose two swingarm presentation members")

	for visual in motorcycle.front_fork_visuals + motorcycle.rear_swingarm_visuals:
		_check_cylinder_span(visual, "motorcycle structural tube")
	_check_cylinder_span(motorcycle.exhaust_visual, "motorcycle exhaust")
	for wheel in motorcycle.wheel_roots:
		var tyre := wheel.get_node_or_null("Tyre") as MeshInstance3D
		var rim := wheel.get_node_or_null("Rim") as MeshInstance3D
		_expect(tyre != null and tyre.mesh is TorusMesh, "Motorcycle tyre presentation regressed to a solid/non-ring mesh")
		_expect(rim != null and rim.mesh is TorusMesh, "Motorcycle rim presentation regressed to a solid/non-ring mesh")
		var spoke_count := 0
		for child in wheel.get_children():
			if String(child.name).begins_with("WheelSpoke"):
				spoke_count += 1
		_expect(spoke_count == 8, "Motorcycle wheel lost the eight-spoke presentation contract")

	motorcycle.queue_free()
	await process_frame

func _check_motorcycle_rider_contracts() -> void:
	var motorcycle := M20Motorcycle.new()
	motorcycle.name = "VisualContractMotorcycleRider"
	motorcycle.origin_offset_m = Vector3.ZERO
	motorcycle.auto_step = false
	root.add_child(motorcycle)
	await process_frame

	var rig := motorcycle.rider_rig
	_expect(rig != null and rig.rider_body_count() == 2, "Motorcycle rider physics topology must remain two rigid bodies")
	if rig != null:
		_expect(rig.rider_presentation_root != null, "Motorcycle rider articulated presentation root is missing")
		if rig.rider_presentation_root != null:
			_expect(String(rig.rider_presentation_root.get_meta("presentation_role", "")) == "motorcycle_rider_articulated_skin", "Motorcycle rider presentation role metadata is missing")
		_expect(rig.torso == null or rig.torso.get_node_or_null("RiderArms") == null, "Motorcycle rider old rectangular arm block reappeared")
		_expect(rig.torso == null or rig.torso.get_node_or_null("RiderLegs") == null, "Motorcycle rider old rectangular leg block reappeared")
		_expect(rig.presentation_segment_count() >= 12, "Motorcycle rider articulated presentation lost limb segments")
		_expect(motorcycle.handlebar_grips.size() == 2, "Motorcycle rider placement gate requires two handlebar grips")
		if motorcycle.handlebar_grips.size() == 2:
			var left_hand := rig.presentation_point(&"left_glove")
			var right_hand := rig.presentation_point(&"right_glove")
			_expect(left_hand.distance_to(motorcycle.handlebar_grips[0].global_position) < 0.08, "Motorcycle rider left hand detached from the handlebar grip")
			_expect(right_hand.distance_to(motorcycle.handlebar_grips[1].global_position) < 0.08, "Motorcycle rider right hand detached from the handlebar grip")

	motorcycle.queue_free()
	await process_frame

func _check_cyclist_contracts() -> void:
	var proxy := M22RoadUserProxy3D.new()
	proxy.name = "VisualContractCyclist"
	proxy.configure(
		ScenarioConfig.TARGET_CYCLIST,
		RoadUserCatalog.BICYCLE_CITY,
		RoadUserCatalog.cyclist_default_mass_kg(RoadUserCatalog.BICYCLE_CITY),
		0.0,
		Vector3.ZERO,
		0.0,
		false
	)
	root.add_child(proxy)
	await process_frame

	var skin := M22RoadUserPresentationSkin3D.new()
	proxy.add_child(skin)
	skin.configure(proxy)
	for _frame in range(3):
		await process_frame

	_expect(proxy.cyclist_rider_body_count() == 11, "Cyclist physics topology must remain the 11-body generic rider")
	_expect(proxy.cyclist_coupling_joint_count() == 5, "Cyclist must retain five pre-impact bicycle coupling joints")

	var pelvis := _find_body(proxy, "CyclistPelvis")
	_expect(pelvis != null, "Cyclist physical pelvis body is missing")
	if pelvis != null:
		var visual_pelvis := skin.cyclist_visual_pelvis_position()
		_expect(visual_pelvis.distance_to(pelvis.global_position) < 0.06, "Cyclist visual pelvis is detached from CyclistPelvis")
	var left_hand := skin.cyclist_visual_hand_position(true)
	var right_hand := skin.cyclist_visual_hand_position(false)
	var expected_left := proxy.to_global(Vector3(0.52, 1.20, -0.22))
	var expected_right := proxy.to_global(Vector3(0.52, 1.20, 0.22))
	_expect(left_hand.distance_to(expected_left) < 0.14, "Cyclist left hand is too far from the bicycle control coupling")
	_expect(right_hand.distance_to(expected_right) < 0.14, "Cyclist right hand is too far from the bicycle control coupling")

	proxy.queue_free()
	await process_frame

func _check_cylinder_span(visual: MeshInstance3D, label: String) -> void:
	_expect(visual != null and visual.mesh is CylinderMesh, "%s is not cylindrical" % label)
	if visual == null or not visual.mesh is CylinderMesh:
		return
	var start_value: Variant = visual.get_meta("presentation_span_start", null)
	var end_value: Variant = visual.get_meta("presentation_span_end", null)
	_expect(start_value is Vector3 and end_value is Vector3, "%s lost its presentation span metadata" % label)
	if not (start_value is Vector3 and end_value is Vector3):
		return
	var start := start_value as Vector3
	var finish := end_value as Vector3
	var delta := finish - start
	_expect(delta.length() > 0.03, "%s has a degenerate structural span" % label)
	if delta.length() <= 0.03:
		return
	var axis := visual.basis.y.normalized()
	_expect(absf(axis.dot(delta.normalized())) > 0.995, "%s cylinder axis is not aligned with its structural span" % label)
	var mesh := visual.mesh as CylinderMesh
	_expect(absf(mesh.height - delta.length()) < 0.015, "%s cylinder height does not match its structural span" % label)

func _find_body(proxy: RoadUserRigidProxy3D, body_name: String) -> RigidBody3D:
	for body in proxy.articulated_bodies:
		if body != null and is_instance_valid(body) and String(body.name) == body_name:
			return body
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
