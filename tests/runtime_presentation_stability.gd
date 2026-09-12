# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_m19_diagnostic_foundation()
	await _check_heavy_truck_skin_origin()
	await _check_m20_replay_safe_truck_skin()
	await _check_m21_articulated_truck_construction()
	await _check_passenger_car_wheel_axis()
	await _check_high_speed_pedestrian_vertical_transfer()
	if failures.is_empty():
		print("CrashVector reported runtime presentation/stability regressions passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check_m19_diagnostic_foundation() -> void:
	# This test is already part of the manual package smoke gate. Keep a cheap
	# M19 foundation check here so a smoke package cannot silently lose the
	# diagnostic helper/reference catalog even when the dedicated M19 production
	# scenario is reserved for the consolidated/full regression set.
	var samples: Array[Dictionary] = [
		{"collider_name": &"Road", "position_local": Vector3.ZERO, "impulse": Vector3(1000.0, 0.0, 0.0), "normal": Vector3.UP},
		{"collider_name": &"Vehicle", "position_local": Vector3(0.8, 0.2, -0.4), "impulse": Vector3(120.0, 0.0, 0.0), "normal": Vector3.LEFT},
		{"collider_name": &"Vehicle", "position_local": Vector3(0.4, 0.3, 0.4), "impulse": Vector3(180.0, 0.0, 0.0), "normal": Vector3.LEFT},
	]
	var manifold := ContactManifoldMetrics.summarize(samples)
	_expect(int(manifold.get("contact_count", 0)) == 2, "M19 smoke: ground contact leaked into manifold diagnostics")
	_expect(absf(float(manifold.get("total_impulse_ns", 0.0)) - 300.0) < 0.001, "M19 smoke: manifold impulse summary changed unexpectedly")
	var references := ValidationReferenceCatalog.load_all()
	_expect(references.size() == 4, "M19 smoke: external validation reference catalog is incomplete")
	_expect(ValidationReferenceCatalog.protocol_geometry_references().size() == 3, "M19 smoke: protocol-only evidence role separation is broken")

func _check_heavy_truck_skin_origin() -> void:
	var truck := M17HeavyTruck.new()
	truck.name = "RuntimeRegressionTruck"
	truck.origin_offset_m = Vector3(3.2, 0.0, 0.0)
	truck.auto_step = false
	root.add_child(truck)
	await process_frame
	var skin := M17HeavyTruckVisual.new()
	truck.add_child(skin)
	skin.configure(truck)
	await process_frame
	var offset := skin.global_position.distance_to(truck.rigid_chassis.global_position)
	_expect(offset < 0.08, "Heavy-truck presentation root is detached from its rigid chassis by %.3f m" % offset)
	var trailer_bottom := skin.global_transform * (skin.trailer_instance.position + Vector3.DOWN * 1.41)
	_expect(trailer_bottom.y < 0.90, "Heavy-truck trailer is visibly floating before simulation: bottom y=%.3f m" % trailer_bottom.y)
	truck.queue_free()
	await process_frame

func _check_m20_replay_safe_truck_skin() -> void:
	# Replay restores StructuralSnapshot node positions, while M20's live scalar
	# crush accumulators remain monotonic for the completed simulation. The visual
	# must therefore be reconstructed from structural nodes, not from the final
	# scalar peak, or rewinding would leave the truck visibly crushed.
	var truck := M20HeavyTruck.new()
	truck.name = "RuntimeRegressionM20Truck"
	truck.origin_offset_m = Vector3.ZERO
	truck.auto_step = false
	root.add_child(truck)
	await process_frame
	var skin := M20HeavyTruckVisual.new()
	truck.add_child(skin)
	skin.configure(truck)
	await process_frame
	var pristine := StructuralSnapshot.capture(truck.model)
	var pristine_width := _m20_trailer_width(skin)
	_expect(absf(pristine_width - 2.42) < 0.06, "M20 truck pristine presentation width changed unexpectedly: %.3f m" % pristine_width)

	# Inject a deterministic structural side crush without using the physics
	# solver. Keep the live peak scalar non-zero afterwards to model the exact
	# completed-run/replay condition that previously leaked final deformation.
	for station in [1, 2, 3, 4]:
		for corner in [1, 3]:
			var index := HeavyTruckBuilder.node_index(station, corner)
			var local := truck.rigid_chassis.to_local(truck.model.nodes[index].position_m)
			local.z -= 0.24
			truck.model.nodes[index].position_m = truck.rigid_chassis.to_global(local)
	truck.hybrid_side_positive_z_crush_m = 0.24
	skin._update_pose()
	var crushed_width := _m20_trailer_width(skin)
	_expect(crushed_width < pristine_width - 0.08, "M20 truck visual did not follow structural side deformation: %.3f -> %.3f m" % [pristine_width, crushed_width])

	_expect(StructuralSnapshot.apply(truck.model, pristine), "M20 truck structural replay snapshot could not be restored")
	# Deliberately do not reset hybrid_side_positive_z_crush_m.
	skin._update_pose()
	var restored_width := _m20_trailer_width(skin)
	_expect(absf(restored_width - pristine_width) < 0.03, "M20 replay-safe presentation inherited the final live side-crush scalar: %.3f vs %.3f m" % [restored_width, pristine_width])

	truck.queue_free()
	await process_frame

func _m20_trailer_width(skin: M20HeavyTruckVisual) -> float:
	if skin == null or skin.trailer_instance == null:
		return 0.0
	var mesh := skin.trailer_instance.mesh as BoxMesh
	return 0.0 if mesh == null else mesh.size.z

func _check_m21_articulated_truck_construction() -> void:
	# Package smoke does not need another full production collision. It does need
	# to prove that the target shipped by main still has two separate bodies, a
	# constrained fifth wheel and an articulated presentation root. The existing
	# M20 production broadside smoke then exercises this same M21 route under real
	# collision load.
	var truck := M21HeavyTruck.new()
	truck.name = "RuntimeRegressionM21Truck"
	truck.total_mass_kg = 18000.0
	truck.origin_offset_m = Vector3.ZERO
	truck.auto_step = false
	root.add_child(truck)
	await process_frame
	_expect(truck.rigid_chassis != null and truck.tractor_chassis != null, "M21 smoke: articulated truck did not create separate trailer/tractor rigid bodies")
	_expect(truck.fifth_wheel_joint != null, "M21 smoke: articulated truck did not create the fifth-wheel joint")
	if truck.rigid_chassis != null and truck.tractor_chassis != null:
		_expect(absf((truck.rigid_chassis.mass + truck.tractor_chassis.mass) - truck.total_mass_kg) < 1.0, "M21 smoke: split rigid-body masses do not preserve total target mass")
		_expect(truck.fifth_wheel_separation_m() < 0.01, "M21 smoke: fifth-wheel anchors are separated in the pristine pose")
	var skin := M21HeavyTruckVisual.new()
	truck.add_child(skin)
	skin.configure(truck)
	await process_frame
	_expect(skin.tractor_presentation_root != null, "M21 smoke: articulated tractor presentation root is missing")
	var diagnostics := truck.combined_contact_manifold_diagnostics()
	_expect(String(diagnostics.get("scope", "")) == "diagnostic_only_no_solver_feedback_articulated_pair", "M21 smoke: combined contact diagnostic scope changed")
	truck.queue_free()
	await process_frame

func _check_passenger_car_wheel_axis() -> void:
	var car := M17CompactHatchback.new()
	car.name = "RuntimeRegressionCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.origin_offset_m = Vector3.ZERO
	car.auto_step = false
	root.add_child(car)
	await process_frame
	var skin := M16VehicleVisualRefined.new()
	car.add_child(skin)
	skin.configure(car)
	var forward_speed := PhysicsMetrics.kmh_to_ms(130.0)
	for node in car.model.nodes:
		node.velocity_ms = Vector3.RIGHT * forward_speed
	for _frame in range(900):
		skin._update_wheels(1.0 / 60.0)
	var reference := car.global_reference_transform().basis.orthonormalized()
	for i in range(skin.wheel_groups.size()):
		var axle_alignment := absf(skin.wheel_groups[i].basis.z.normalized().dot(reference.z.normalized()))
		_expect(axle_alignment > 0.999, "Passenger-car wheel %d left its physical lateral axle after sustained spin: %.6f" % [i, axle_alignment])
		_expect(absf(skin.wheel_tires[i].rotation.x - PI * 0.5) < 0.0001, "Passenger-car wheel %d accumulated an impossible child pitch" % i)
	car.queue_free()
	await process_frame

func _check_high_speed_pedestrian_vertical_transfer() -> void:
	var car := M17CompactHatchback.new()
	car.name = "RuntimeRegressionPedestrianCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.initial_speed_kmh = 130.0
	car.origin_offset_m = Vector3(-5.6, 0.0, 0.0)
	car.auto_step = false
	root.add_child(car)
	var target := RoadUserArticulatedStableProxy3D.new()
	target.name = "RuntimeRegressionPedestrian"
	target.configure(ScenarioConfig.TARGET_PEDESTRIAN, RoadUserCatalog.PEDESTRIAN_ADULT, 75.0, 0.0, Vector3.ZERO, 0.0, false)
	root.add_child(target)
	await physics_frame
	car.begin_simulation()
	target.begin_simulation()
	# Contact state is informational: it must never inject an artificial launch.
	target.record_physical_contact(car.rigid_chassis)
	await physics_frame
	var vertical_speed := absf(target.center_of_mass_velocity_ms().y)
	var maximum_part_vertical_speed := absf(target.linear_velocity.y)
	for body in target.articulated_bodies:
		if body != null and is_instance_valid(body):
			maximum_part_vertical_speed = maxf(maximum_part_vertical_speed, absf(body.linear_velocity.y))
	_expect(target.impact_received, "High-speed pedestrian regression did not record the contact")
	# One physics frame of gravity is expected. Any larger vertical response would
	# indicate that contact recording has started injecting momentum again.
	_expect(vertical_speed < 0.06, "Recording physical contact must not create a vertical launch: %.3f m/s" % vertical_speed)
	_expect(maximum_part_vertical_speed < 0.06, "Recording physical contact must not launch a segment: %.3f m/s" % maximum_part_vertical_speed)
	car.end_simulation()
	target.end_simulation()
	car.queue_free()
	target.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
