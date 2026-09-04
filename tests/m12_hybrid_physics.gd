# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	await _test_50_kmh_wall_settles(failures)
	await _test_stationary_car_stays_on_road(failures)
	if failures.is_empty():
		print("CrashVector M12 hybrid-physics tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_50_kmh_wall_settles(failures: Array[String]) -> void:
	var road := _road_body()
	root.add_child(road)
	var wall := StaticObstacle3D.new()
	wall.name = "WallTarget"
	root.add_child(wall)
	wall.configure(ScenarioConfig.TARGET_WALL, Vector3.ZERO, 0.0)
	var car := CompactHatchback.new()
	car.name = "HybridTestCar"
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
	var initial_y := car.rigid_chassis.global_position.y
	var first_contact_x := 0.0
	var contact_seen := false
	var maximum_y_rise := 0.0
	var maximum_pitch_deg := 0.0
	var maximum_retreat_m := 0.0
	car.begin_simulation()
	for _frame in range(360):
		await physics_frame
		maximum_y_rise = maxf(maximum_y_rise, car.rigid_chassis.global_position.y - initial_y)
		maximum_pitch_deg = maxf(maximum_pitch_deg, absf(rad_to_deg(car.rigid_chassis.rotation.z)))
		if not contact_seen and car.hybrid_contact_count() > 0:
			contact_seen = true
			first_contact_x = car.rigid_chassis.global_position.x
		if contact_seen:
			maximum_retreat_m = maxf(maximum_retreat_m, first_contact_x - car.rigid_chassis.global_position.x)
	car.end_simulation()
	print("M12 50kmh wall: contacts=%d rebound=%.3f m/s retreat=%.3f m y_rise=%.3f m y_speed=%.3f m/s pitch=%.2f deg crush=%.3f m final_x=%.3f" % [
		car.hybrid_contact_count(), car.hybrid_maximum_reverse_speed_ms(), maximum_retreat_m,
		maximum_y_rise, car.hybrid_maximum_vertical_speed_ms(), maximum_pitch_deg,
		car.front_crush_deformation_m(), car.rigid_chassis.global_position.x,
	])
	if not contact_seen:
		failures.append("M12 real rigid-body wall test never established non-ground contact")
	if car.hybrid_maximum_reverse_speed_ms() > 1.25:
		failures.append("M12 50 km/h wall impact launches the car backwards: %.3f m/s" % car.hybrid_maximum_reverse_speed_ms())
	if maximum_retreat_m > 0.55:
		failures.append("M12 50 km/h wall impact retreats implausibly far from the wall: %.3f m" % maximum_retreat_m)
	if maximum_y_rise > 0.24:
		failures.append("M12 50 km/h wall impact makes the chassis jump too high: %.3f m" % maximum_y_rise)
	if car.hybrid_maximum_vertical_speed_ms() > 3.0:
		failures.append("M12 50 km/h wall impact creates excessive vertical chassis speed: %.3f m/s" % car.hybrid_maximum_vertical_speed_ms())
	if maximum_pitch_deg > 18.0:
		failures.append("M12 50 km/h centred wall impact produces excessive chassis pitch: %.2f deg" % maximum_pitch_deg)
	if car.front_crush_deformation_m() < 0.08:
		failures.append("M12 real-contact wall impact did not drive visible/local front crush: %.3f m" % car.front_crush_deformation_m())
	car.queue_free()
	wall.queue_free()
	road.queue_free()
	await physics_frame

func _test_stationary_car_stays_on_road(failures: Array[String]) -> void:
	var road := _road_body()
	root.add_child(road)
	var car := CompactHatchback.new()
	car.name = "HybridRestCar"
	car.total_mass_kg = 1150.0
	car.initial_speed_kmh = 0.0
	car.origin_offset_m = Vector3.ZERO
	car.show_structure = false
	car.auto_step = true
	root.add_child(car)
	await physics_frame
	var initial_y := car.rigid_chassis.global_position.y
	car.begin_simulation()
	var maximum_displacement := 0.0
	for _frame in range(120):
		await physics_frame
		maximum_displacement = maxf(maximum_displacement, absf(car.rigid_chassis.global_position.y - initial_y))
	car.end_simulation()
	print("M12 rest-on-road: y_delta=%.4f m max_vertical=%.4f m/s" % [
		maximum_displacement, car.hybrid_maximum_vertical_speed_ms(),
	])
	if maximum_displacement > 0.08:
		failures.append("M12 rigid chassis does not remain supported by its real road contacts: %.3f m vertical drift" % maximum_displacement)
	car.queue_free()
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
	shape.size = Vector3(48.0, 0.5, 12.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	road.add_child(collision)
	return road
