# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	await _test_pedestrian_target_moves_after_contact(failures)
	await _test_bicycle_target_moves_after_contact(failures)
	await _test_200_kmh_pole_yields(failures)
	await _test_200_kmh_tree_yields(failures)
	_test_wall_and_barrier_remain_rigid(failures)
	if failures.is_empty():
		print("CrashVector M14 road-user and yielding-obstacle tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_pedestrian_target_moves_after_contact(failures: Array[String]) -> void:
	var result := await _run_road_user_case(ScenarioConfig.TARGET_PEDESTRIAN, RoadUserCatalog.PEDESTRIAN_ADULT, 75.0, 60.0)
	print("M14 pedestrian: impact=%s target_speed=%.2f m/s travel=%.2f m target_y_speed=%.2f m/s car_y_rise=%.3f m car_rebound=%.3f m/s car_crush=%.3f m" % [
		str(result.get("impact", false)), float(result.get("target_speed_ms", 0.0)), float(result.get("travel_m", 0.0)),
		float(result.get("target_vertical_ms", 0.0)), float(result.get("car_y_rise_m", 0.0)),
		float(result.get("car_rebound_ms", 0.0)), float(result.get("car_crush_m", 0.0)),
	])
	if not bool(result.get("impact", false)):
		failures.append("M14 pedestrian production proxy never registered car contact")
	if float(result.get("target_speed_ms", 0.0)) < 2.0:
		failures.append("M14 pedestrian remains effectively fixed after a 60 km/h impact")
	if float(result.get("travel_m", 0.0)) < 0.35:
		failures.append("M14 pedestrian does not acquire a material post-impact trajectory")
	if float(result.get("car_y_rise_m", 0.0)) > 0.20:
		failures.append("M14 pedestrian impact makes the passenger car jump: %.3f m" % float(result.get("car_y_rise_m", 0.0)))
	if float(result.get("car_rebound_ms", 0.0)) > 1.5:
		failures.append("M14 pedestrian impact launches the passenger car backwards: %.3f m/s" % float(result.get("car_rebound_ms", 0.0)))

func _test_bicycle_target_moves_after_contact(failures: Array[String]) -> void:
	var result := await _run_road_user_case(ScenarioConfig.TARGET_BICYCLE, RoadUserCatalog.BICYCLE_CITY, 16.0, 60.0)
	print("M14 bicycle: impact=%s target_speed=%.2f m/s travel=%.2f m target_y_speed=%.2f m/s car_y_rise=%.3f m car_rebound=%.3f m/s car_crush=%.3f m" % [
		str(result.get("impact", false)), float(result.get("target_speed_ms", 0.0)), float(result.get("travel_m", 0.0)),
		float(result.get("target_vertical_ms", 0.0)), float(result.get("car_y_rise_m", 0.0)),
		float(result.get("car_rebound_ms", 0.0)), float(result.get("car_crush_m", 0.0)),
	])
	if not bool(result.get("impact", false)):
		failures.append("M14 bicycle production proxy never registered car contact")
	if float(result.get("target_speed_ms", 0.0)) < 2.0:
		failures.append("M14 bicycle remains effectively fixed after a 60 km/h impact")
	if float(result.get("travel_m", 0.0)) < 0.35:
		failures.append("M14 bicycle does not acquire a material post-impact trajectory")
	if float(result.get("car_y_rise_m", 0.0)) > 0.20:
		failures.append("M14 bicycle impact makes the passenger car jump: %.3f m" % float(result.get("car_y_rise_m", 0.0)))

func _run_road_user_case(target_type: StringName, preset_id: StringName, target_mass: float, speed_kmh: float) -> Dictionary:
	var road := _road_body()
	root.add_child(road)
	var car := CompactHatchback.new()
	car.name = "M14RoadUserCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.initial_speed_kmh = speed_kmh
	car.origin_offset_m = Vector3(-6.0, 0.0, 0.0)
	car.heading_deg = 0.0
	car.solver_substeps = 16
	car.show_structure = false
	car.auto_step = true
	root.add_child(car)
	var target := RoadUserRigidProxy3D.new()
	target.name = "M14RoadUserTarget"
	target.configure(target_type, preset_id, target_mass, 0.0, Vector3.ZERO, 0.0, false)
	root.add_child(target)
	await physics_frame
	var initial_car_y := car.rigid_chassis.global_position.y
	var maximum_car_y_rise := 0.0
	car.begin_simulation()
	target.begin_simulation()
	for _frame in range(420):
		await physics_frame
		maximum_car_y_rise = maxf(maximum_car_y_rise, car.rigid_chassis.global_position.y - initial_car_y)
		if car.rigid_chassis.front_crush_overlap_active() and car.rigid_chassis.front_crush_collider() == target:
			target.apply_probe_contact(car.rigid_chassis)
	var result := {
		"impact": target.impact_received,
		"target_speed_ms": target.maximum_speed_ms,
		"target_vertical_ms": target.maximum_vertical_speed_ms,
		"travel_m": target.maximum_travel_m,
		"car_y_rise_m": maximum_car_y_rise,
		"car_rebound_ms": car.hybrid_maximum_reverse_speed_ms(),
		"car_crush_m": car.front_crush_deformation_m(),
	}
	car.end_simulation()
	target.end_simulation()
	car.queue_free()
	target.queue_free()
	road.queue_free()
	await physics_frame
	return result

func _test_200_kmh_pole_yields(failures: Array[String]) -> void:
	var result := await _run_yielding_obstacle_case(ScenarioConfig.TARGET_POLE, 200.0)
	print("M14 200kmh pole: demand=%.0f kJ bend=%.1f deg failure=%s crush=%.3f m car_y_rise=%.3f m" % [
		float(result.get("demand_j", 0.0)) / 1000.0, float(result.get("bend_deg", 0.0)), str(result.get("failed", false)),
		float(result.get("crush_m", 0.0)), float(result.get("car_y_rise_m", 0.0)),
	])
	if float(result.get("demand_j", 0.0)) < 700000.0:
		failures.append("M14 200 km/h pole case did not register severe collision demand")
	if float(result.get("bend_deg", 0.0)) < 55.0:
		failures.append("M14 pole still behaves as an undeformable rigid post at 200 km/h: %.1f deg" % float(result.get("bend_deg", 0.0)))
	if float(result.get("car_y_rise_m", 0.0)) > 0.70:
		failures.append("M14 yielding pole reintroduces excessive passenger-car jump")

func _test_200_kmh_tree_yields(failures: Array[String]) -> void:
	var result := await _run_yielding_obstacle_case(ScenarioConfig.TARGET_TREE, 200.0)
	print("M14 200kmh tree: demand=%.0f kJ bend=%.1f deg failure=%s crush=%.3f m car_y_rise=%.3f m" % [
		float(result.get("demand_j", 0.0)) / 1000.0, float(result.get("bend_deg", 0.0)), str(result.get("failed", false)),
		float(result.get("crush_m", 0.0)), float(result.get("car_y_rise_m", 0.0)),
	])
	if float(result.get("demand_j", 0.0)) < 700000.0:
		failures.append("M14 200 km/h tree case did not register severe collision demand")
	if float(result.get("bend_deg", 0.0)) < 30.0:
		failures.append("M14 tree still behaves as an undeformable rigid trunk at 200 km/h: %.1f deg" % float(result.get("bend_deg", 0.0)))
	if float(result.get("car_y_rise_m", 0.0)) > 0.70:
		failures.append("M14 yielding tree reintroduces excessive passenger-car jump")

func _run_yielding_obstacle_case(target_type: StringName, speed_kmh: float) -> Dictionary:
	var road := _road_body()
	root.add_child(road)
	var obstacle := StaticObstacle3D.new()
	obstacle.name = "M14YieldTarget"
	root.add_child(obstacle)
	obstacle.configure(target_type, Vector3.ZERO, 0.0)
	var car := CompactHatchback.new()
	car.name = "M14YieldCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.initial_speed_kmh = speed_kmh
	car.origin_offset_m = Vector3(-7.0, 0.0, 0.0)
	car.heading_deg = 0.0
	car.solver_substeps = 32
	car.show_structure = false
	car.auto_step = true
	root.add_child(car)
	await physics_frame
	var initial_car_y := car.rigid_chassis.global_position.y
	var maximum_car_y_rise := 0.0
	car.begin_simulation()
	for _frame in range(600):
		await physics_frame
		maximum_car_y_rise = maxf(maximum_car_y_rise, car.rigid_chassis.global_position.y - initial_car_y)
		obstacle.apply_collision_demand(car.hybrid_collision_energy_j(), car.rigid_chassis.global_transform.basis.x.normalized())
	var result := {
		"demand_j": car.hybrid_collision_energy_j(),
		"bend_deg": obstacle.bend_angle_deg(),
		"failed": obstacle.has_failed(),
		"crush_m": car.front_crush_deformation_m(),
		"car_y_rise_m": maximum_car_y_rise,
	}
	car.end_simulation()
	car.queue_free()
	obstacle.queue_free()
	road.queue_free()
	await physics_frame
	return result

func _test_wall_and_barrier_remain_rigid(failures: Array[String]) -> void:
	for target_type in [ScenarioConfig.TARGET_WALL, ScenarioConfig.TARGET_BARRIER]:
		var obstacle := StaticObstacle3D.new()
		root.add_child(obstacle)
		obstacle.configure(target_type, Vector3.ZERO, 0.0)
		obstacle.apply_collision_demand(5000000.0, Vector3.RIGHT)
		if obstacle.has_yielded() or absf(obstacle.bend_angle_deg()) > 0.001:
			failures.append("M14 must not make wall/barrier yielding targets")
		obstacle.queue_free()

func _road_body() -> StaticBody3D:
	var road := StaticBody3D.new()
	road.name = "Road"
	road.position = Vector3(0.0, -0.25, 0.0)
	var material := PhysicsMaterial.new()
	material.friction = 0.90
	material.bounce = 0.0
	road.physics_material_override = material
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 0.5, 14.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	road.add_child(collision)
	return road
