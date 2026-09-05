# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const ROAD_USER_LAYER: int = 2
const ROAD_USER_GROUND_LAYER: int = 4
const MAX_TARGET_SPEED_MS: float = 22.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	await _test_pedestrian_articulation(failures)
	await _test_bicycle_articulation(failures)
	if failures.is_empty():
		print("CrashVector M15 articulated road-user tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_pedestrian_articulation(failures: Array[String]) -> void:
	var result := await _run_case(ScenarioConfig.TARGET_PEDESTRIAN, RoadUserCatalog.PEDESTRIAN_ADULT, 75.0, 60.0)
	print("M15 pedestrian: impact=%s bodies=%d joints=%d speed=%.2f m/s travel=%.2f m joint_motion=%.1f deg car_y=%.3f m rebound=%.3f m/s" % [
		str(result.get("impact", false)), int(result.get("bodies", 0)), int(result.get("joints", 0)),
		float(result.get("speed_ms", 0.0)), float(result.get("travel_m", 0.0)), float(result.get("articulation_deg", 0.0)),
		float(result.get("car_y_rise_m", 0.0)), float(result.get("car_rebound_ms", 0.0)),
	])
	if not bool(result.get("impact", false)):
		failures.append("M15 pedestrian did not receive passenger-car contact")
	if int(result.get("bodies", 0)) < 10:
		failures.append("M15 pedestrian is not an articulated multi-body target")
	if int(result.get("joints", 0)) < 9:
		failures.append("M15 pedestrian does not expose the expected articulated joints")
	if float(result.get("speed_ms", 0.0)) < 2.0 or float(result.get("travel_m", 0.0)) < 0.35:
		failures.append("M15 pedestrian did not acquire a material post-impact trajectory")
	if float(result.get("speed_ms", 0.0)) > MAX_TARGET_SPEED_MS:
		failures.append("M15 pedestrian solver created non-physical target energy")
	if float(result.get("articulation_deg", 0.0)) < 6.0:
		failures.append("M15 pedestrian still moves effectively as one rigid mannequin")
	if float(result.get("articulation_deg", 0.0)) > 155.0:
		failures.append("M15 pedestrian still permits near-180-degree direct joint folding")
	if float(result.get("car_y_rise_m", 0.0)) > 0.25:
		failures.append("M15 pedestrian articulation destabilizes passenger-car vertical motion")
	if float(result.get("car_rebound_ms", 0.0)) > 1.5:
		failures.append("M15 pedestrian articulation launches the passenger car backwards")

func _test_bicycle_articulation(failures: Array[String]) -> void:
	var result := await _run_case(ScenarioConfig.TARGET_BICYCLE, RoadUserCatalog.BICYCLE_CITY, 16.0, 60.0)
	print("M15 bicycle: impact=%s bodies=%d joints=%d speed=%.2f m/s travel=%.2f m wheel_spin=%.2f rad/s car_y=%.3f m" % [
		str(result.get("impact", false)), int(result.get("bodies", 0)), int(result.get("joints", 0)),
		float(result.get("speed_ms", 0.0)), float(result.get("travel_m", 0.0)),
		float(result.get("wheel_spin_rad_s", 0.0)), float(result.get("car_y_rise_m", 0.0)),
	])
	if not bool(result.get("impact", false)):
		failures.append("M15 bicycle did not receive passenger-car contact")
	if int(result.get("bodies", 0)) != 3:
		failures.append("M15 bicycle must use one frame body plus two independent wheel bodies")
	if int(result.get("joints", 0)) != 2:
		failures.append("M15 bicycle must join both wheel bodies to the frame")
	if float(result.get("speed_ms", 0.0)) < 2.0 or float(result.get("travel_m", 0.0)) < 0.35:
		failures.append("M15 bicycle did not acquire a material post-impact trajectory")
	if float(result.get("speed_ms", 0.0)) > MAX_TARGET_SPEED_MS:
		failures.append("M15 bicycle solver created non-physical target energy")
	if float(result.get("wheel_spin_rad_s", 0.0)) < 0.25:
		failures.append("M15 bicycle wheels never develop independent angular motion")
	if float(result.get("car_y_rise_m", 0.0)) > 0.25:
		failures.append("M15 bicycle articulation destabilizes passenger-car vertical motion")

func _run_case(target_type: StringName, preset_id: StringName, target_mass: float, speed_kmh: float) -> Dictionary:
	var road := _road_body()
	root.add_child(road)
	var car := CompactHatchback.new()
	car.name = "M15RoadUserCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.initial_speed_kmh = speed_kmh
	car.origin_offset_m = Vector3(-6.0, 0.0, 0.0)
	car.heading_deg = 0.0
	car.solver_substeps = 16
	car.show_structure = false
	car.auto_step = true
	root.add_child(car)
	var target := RoadUserArticulatedProxy3D.new()
	target.name = "M15RoadUserTarget"
	target.configure(target_type, preset_id, target_mass, 0.0, Vector3.ZERO, 0.0, false)
	root.add_child(target)
	await physics_frame
	_configure_road_user_channels(target, car)
	var initial_car_y := car.rigid_chassis.global_position.y
	var maximum_car_y_rise := 0.0
	car.begin_simulation()
	target.begin_simulation()
	for _frame in range(480):
		await physics_frame
		maximum_car_y_rise = maxf(maximum_car_y_rise, car.rigid_chassis.global_position.y - initial_car_y)
		if car.rigid_chassis.front_crush_overlap_active():
			var collider := car.rigid_chassis.front_crush_collider()
			if target.owns_collider(collider):
				target.apply_probe_contact(car.rigid_chassis, collider)
	var result := {
		"impact": target.impact_received,
		"bodies": target.articulated_body_count(),
		"joints": target.articulated_joint_count(),
		"speed_ms": target.center_of_mass_velocity_ms().length(),
		"travel_m": target.maximum_travel_m,
		"articulation_deg": target.maximum_articulation_angle_deg,
		"wheel_spin_rad_s": target.maximum_wheel_spin_rad_s,
		"car_y_rise_m": maximum_car_y_rise,
		"car_rebound_ms": car.hybrid_maximum_reverse_speed_ms(),
	}
	car.end_simulation()
	target.end_simulation()
	car.queue_free()
	target.queue_free()
	road.queue_free()
	await physics_frame
	return result

func _configure_road_user_channels(target: RoadUserRigidProxy3D, car: CompactHatchback) -> void:
	target.collision_layer = ROAD_USER_LAYER
	target.collision_mask = ROAD_USER_GROUND_LAYER
	for body in target.articulated_bodies:
		if body != null and is_instance_valid(body):
			body.collision_layer = ROAD_USER_LAYER
			body.collision_mask = ROAD_USER_GROUND_LAYER
	for joint in target.articulated_joints:
		if joint == null or not is_instance_valid(joint):
			continue
		var body_a_path := joint.node_a
		var body_b_path := joint.node_b
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.node_a = body_a_path
		joint.node_b = body_b_path
	if car.rigid_chassis != null and car.rigid_chassis.front_crush_probe != null:
		car.rigid_chassis.front_crush_probe.collision_mask = ROAD_USER_LAYER

func _road_body() -> StaticBody3D:
	var road := StaticBody3D.new()
	road.name = "Road"
	road.position = Vector3(0.0, -0.25, 0.0)
	road.collision_layer = 1 | ROAD_USER_GROUND_LAYER
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
