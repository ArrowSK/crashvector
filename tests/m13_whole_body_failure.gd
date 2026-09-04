# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	await _test_50_kmh_preserves_cell(failures)
	await _test_200_kmh_propagates_into_body(failures)
	if failures.is_empty():
		print("CrashVector M13 whole-body failure tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_50_kmh_preserves_cell(failures: Array[String]) -> void:
	var road := _road_body()
	root.add_child(road)
	var wall := StaticObstacle3D.new()
	wall.name = "WallTarget"
	root.add_child(wall)
	wall.configure(ScenarioConfig.TARGET_WALL, Vector3.ZERO, 0.0)
	var car := CompactHatchback.new()
	car.name = "M13ModerateCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.initial_speed_kmh = 50.0
	car.origin_offset_m = Vector3(-5.60, 0.0, 0.0)
	car.heading_deg = 0.0
	car.solver_substeps = 16
	car.show_structure = false
	car.auto_step = true
	root.add_child(car)
	await physics_frame
	car.begin_simulation()
	for _frame in range(360):
		await physics_frame
	car.end_simulation()
	print("M13 50kmh preservation: energy=%.1f kJ front=%.3f firewall=%.3f cabin=%.3f rear=%.3f total=%.3f" % [
		car.hybrid_collision_energy_j() / 1000.0,
		car.front_crush_deformation_m(),
		car.hybrid_firewall_intrusion_deformation_m(),
		car.hybrid_cabin_collapse_deformation_m(),
		car.hybrid_rear_buckle_deformation_m(),
		car.hybrid_total_longitudinal_collapse_m(),
	])
	if car.front_crush_deformation_m() < 0.25:
		failures.append("M13 50 km/h wall impact lost normal front-crush behaviour")
	if car.hybrid_firewall_intrusion_deformation_m() > 0.04:
		failures.append("M13 50 km/h wall impact intrudes the firewall too early: %.3f m" % car.hybrid_firewall_intrusion_deformation_m())
	if car.hybrid_cabin_collapse_deformation_m() > 0.03:
		failures.append("M13 50 km/h wall impact collapses the protected cell too early: %.3f m" % car.hybrid_cabin_collapse_deformation_m())
	car.queue_free()
	wall.queue_free()
	road.queue_free()
	await physics_frame

func _test_200_kmh_propagates_into_body(failures: Array[String]) -> void:
	var road := _road_body()
	root.add_child(road)
	var wall := StaticObstacle3D.new()
	wall.name = "WallTarget"
	root.add_child(wall)
	wall.configure(ScenarioConfig.TARGET_WALL, Vector3.ZERO, 0.0)
	var car := CompactHatchback.new()
	car.name = "M13ExtremeCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.initial_speed_kmh = 200.0
	car.origin_offset_m = Vector3(-7.0, 0.0, 0.0)
	car.heading_deg = 0.0
	car.solver_substeps = 32
	car.show_structure = false
	car.auto_step = true
	root.add_child(car)
	await physics_frame
	var initial_y := car.rigid_chassis.global_position.y
	var maximum_y_rise := 0.0
	var maximum_pitch_deg := 0.0
	car.begin_simulation()
	for _frame in range(600):
		await physics_frame
		maximum_y_rise = maxf(maximum_y_rise, car.rigid_chassis.global_position.y - initial_y)
		maximum_pitch_deg = maxf(maximum_pitch_deg, absf(rad_to_deg(car.rigid_chassis.rotation.z)))
	car.end_simulation()
	var firewall := car.hybrid_firewall_intrusion_deformation_m()
	var cabin := car.hybrid_cabin_collapse_deformation_m()
	var rear := car.hybrid_rear_buckle_deformation_m()
	var total := car.hybrid_total_longitudinal_collapse_m()
	print("M13 200kmh whole-body: energy=%.1f kJ front=%.3f firewall=%.3f cabin=%.3f rear=%.3f total=%.3f rebound=%.3f y_rise=%.3f pitch=%.2f" % [
		car.hybrid_collision_energy_j() / 1000.0,
		car.front_crush_deformation_m(), firewall, cabin, rear, total,
		car.hybrid_maximum_reverse_speed_ms(), maximum_y_rise, maximum_pitch_deg,
	])
	if car.hybrid_collision_energy_j() < 1000000.0:
		failures.append("M13 200 km/h wall test did not capture the expected extreme normal collision energy: %.0f J" % car.hybrid_collision_energy_j())
	if car.front_crush_deformation_m() < 0.70:
		failures.append("M13 200 km/h wall impact did not exhaust the front crush zone: %.3f m" % car.front_crush_deformation_m())
	if firewall < 0.15:
		failures.append("M13 200 km/h wall impact failed to propagate into the firewall: %.3f m" % firewall)
	if cabin < 0.25:
		failures.append("M13 200 km/h wall impact still leaves an implausibly rigid passenger cell: %.3f m" % cabin)
	if total < 1.15:
		failures.append("M13 200 km/h wall impact remains confined to the nose instead of shortening the body: %.3f m" % total)
	if maximum_y_rise > 0.65:
		failures.append("M13 200 km/h wall impact reintroduced an excessive chassis jump: %.3f m" % maximum_y_rise)
	if maximum_pitch_deg > 22.0:
		failures.append("M13 200 km/h centred wall impact reintroduced excessive pitch: %.2f deg" % maximum_pitch_deg)
	if not is_finite(car.rigid_chassis.global_position.x) or not is_finite(total):
		failures.append("M13 200 km/h wall impact produced non-finite state")
	car.queue_free()
	wall.queue_free()
	road.queue_free()
	await physics_frame

func _road_body() -> StaticBody3D:
	var road := StaticBody3D.new()
	road.name = "Road"
	road.position = Vector3(0.0, -0.25, 0.0)
	var material := PhysicsMaterial.new()
	material.friction = 0.90
	material.bounce = 0.0
	road.physics_material_override = material
	var shape := BoxShape3D.new()
	shape.size = Vector3(64.0, 0.5, 12.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	road.add_child(collision)
	return road
