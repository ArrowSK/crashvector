# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RoadUserRigidProxy3D
extends RigidBody3D

# Production M14 rigid-body wrapper for the existing generic riderless bicycle
# and pedestrian presentation models. It is deliberately a contact/trajectory
# proxy only; it is not a biomechanical, injury or rider model.

var target_type: StringName = ScenarioConfig.TARGET_PEDESTRIAN
var preset_id: StringName = RoadUserCatalog.PEDESTRIAN_ADULT
var target_mass_kg: float = 75.0
var initial_speed_kmh: float = 0.0
var origin_offset_m := Vector3.ZERO
var heading_deg: float = 0.0
var show_structure: bool = false

var bicycle_visual: Bicycle
var pedestrian_visual: Pedestrian
var impact_received: bool = false
var simulation_active: bool = false
var maximum_vertical_speed_ms: float = 0.0
var maximum_speed_ms: float = 0.0
var maximum_travel_m: float = 0.0
var initial_world_position := Vector3.ZERO

var _paused_linear_velocity := Vector3.ZERO
var _paused_angular_velocity := Vector3.ZERO

func configure(
	type_id: StringName,
	road_user_preset_id: StringName,
	mass_kg: float,
	speed_kmh: float,
	position_m: Vector3,
	yaw_deg: float,
	structure_visible: bool
) -> void:
	target_type = type_id
	preset_id = road_user_preset_id
	target_mass_kg = mass_kg
	initial_speed_kmh = speed_kmh
	origin_offset_m = position_m
	heading_deg = yaw_deg
	show_structure = structure_visible

func _ready() -> void:
	mass = maxf(target_mass_kg, 1.0)
	gravity_scale = 1.0
	continuous_cd = RigidBody3D.CCD_MODE_CAST_SHAPE
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 16
	var material := PhysicsMaterial.new()
	material.friction = 0.62
	material.bounce = 0.02
	physics_material_override = material
	body_entered.connect(_on_body_entered)
	_build_visual_proxy()
	_build_collision_proxy()
	set_preview_pose(origin_offset_m, heading_deg)

func _physics_process(_delta: float) -> void:
	if not simulation_active:
		return
	maximum_vertical_speed_ms = maxf(maximum_vertical_speed_ms, absf(linear_velocity.y))
	maximum_speed_ms = maxf(maximum_speed_ms, linear_velocity.length())
	maximum_travel_m = maxf(maximum_travel_m, global_position.distance_to(initial_world_position))

func _build_visual_proxy() -> void:
	if target_type == ScenarioConfig.TARGET_BICYCLE:
		bicycle_visual = Bicycle.new()
		bicycle_visual.name = "BicyclePresentation"
		bicycle_visual.bicycle_preset_id = preset_id
		bicycle_visual.total_mass_kg = target_mass_kg
		bicycle_visual.initial_speed_kmh = 0.0
		bicycle_visual.origin_offset_m = Vector3.ZERO
		bicycle_visual.heading_deg = 0.0
		bicycle_visual.auto_step = false
		bicycle_visual.show_structure = show_structure
		add_child(bicycle_visual)
	else:
		pedestrian_visual = Pedestrian.new()
		pedestrian_visual.name = "PedestrianPresentation"
		pedestrian_visual.body_preset_id = preset_id
		pedestrian_visual.total_mass_kg = target_mass_kg
		pedestrian_visual.origin_offset_m = Vector3.ZERO
		pedestrian_visual.heading_deg = 0.0
		pedestrian_visual.auto_step = false
		pedestrian_visual.show_structure = show_structure
		add_child(pedestrian_visual)

func _build_collision_proxy() -> void:
	if target_type == ScenarioConfig.TARGET_BICYCLE:
		_add_box_collision("BicycleFrameCollision", Vector3(1.24, 0.34, 0.28), Vector3(0.0, 0.58, 0.0))
		_add_cylinder_collision("BicycleRearWheelCollision", 0.34, 0.075, Vector3(-0.72, 0.34, 0.0), Vector3(90.0, 0.0, 0.0))
		_add_cylinder_collision("BicycleFrontWheelCollision", 0.34, 0.075, Vector3(0.74, 0.34, 0.0), Vector3(90.0, 0.0, 0.0))
	else:
		var height_scale := RoadUserCatalog.pedestrian_height_m(preset_id) / 1.75
		_add_box_collision("PedestrianFeetCollision", Vector3(0.30, 0.10, 0.42), Vector3(0.0, 0.05, 0.0))
		_add_capsule_collision("PedestrianBodyCollision", 0.20 * height_scale, 1.28 * height_scale, Vector3(0.0, 0.86 * height_scale, 0.0))
		_add_sphere_collision("PedestrianHeadCollision", 0.13 * height_scale, Vector3(-0.04 * height_scale, 1.63 * height_scale, 0.0))

func _add_box_collision(node_name: String, size_m: Vector3, local_position_m: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size_m
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	add_child(collision)

func _add_cylinder_collision(node_name: String, radius_m: float, height_m: float, local_position_m: Vector3, rotation_deg: Vector3) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius_m
	shape.height = height_m
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	collision.rotation_degrees = rotation_deg
	add_child(collision)

func _add_capsule_collision(node_name: String, radius_m: float, height_m: float, local_position_m: Vector3) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = radius_m
	shape.height = maxf(height_m, radius_m * 2.0 + 0.01)
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	add_child(collision)

func _add_sphere_collision(node_name: String, radius_m: float, local_position_m: Vector3) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius_m
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	add_child(collision)

func set_preview_pose(position_m: Vector3, yaw_deg: float) -> void:
	origin_offset_m = position_m
	heading_deg = yaw_deg
	freeze = true
	global_position = position_m
	rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	impact_received = false
	simulation_active = false
	initial_world_position = position_m
	maximum_vertical_speed_ms = 0.0
	maximum_speed_ms = 0.0
	maximum_travel_m = 0.0

func begin_simulation() -> void:
	set_preview_pose(origin_offset_m, heading_deg)
	freeze = false
	sleeping = false
	simulation_active = true
	initial_world_position = global_position
	var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
	linear_velocity = forward * PhysicsMetrics.kmh_to_ms(initial_speed_kmh)

func end_simulation() -> void:
	simulation_active = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func set_simulation_paused(value: bool) -> void:
	if value:
		if freeze:
			return
		_paused_linear_velocity = linear_velocity
		_paused_angular_velocity = angular_velocity
		freeze = true
	else:
		if not simulation_active:
			return
		freeze = false
		sleeping = false
		linear_velocity = _paused_linear_velocity
		angular_velocity = _paused_angular_velocity

func apply_probe_contact(source: VehicleRigidChassis) -> void:
	if impact_received or source == null or not simulation_active:
		return
	var forward := source.global_transform.basis.x.normalized()
	var closing_speed := maxf((source.linear_velocity - linear_velocity).dot(forward), 0.0)
	if closing_speed < 0.25:
		return
	var effective_mass := source.mass * mass / maxf(source.mass + mass, 1.0)
	var transfer_impulse_ns := effective_mass * closing_speed * 0.92
	# A vulnerable/light target must be accelerated by the nose contact instead
	# of behaving like a rigid wall until the protected cell reaches it. The car
	# already receives the matching phenomenological nose-resistance force from
	# CompactHatchback, so this proxy only receives the road-user side here.
	apply_central_impulse(forward * transfer_impulse_ns)
	var tumble_axis := Vector3.UP.cross(forward).normalized()
	if not tumble_axis.is_zero_approx():
		var lever_m := 0.18 if target_type == ScenarioConfig.TARGET_BICYCLE else 0.30
		apply_torque_impulse(tumble_axis * transfer_impulse_ns * lever_m)
	axis_lock_angular_x = false
	axis_lock_angular_z = false
	impact_received = true

func _on_body_entered(body: Node) -> void:
	if body is VehicleRigidChassis:
		axis_lock_angular_x = false
		axis_lock_angular_z = false
		impact_received = true

func target_model() -> StructuralModel:
	if bicycle_visual != null:
		return bicycle_visual.model
	if pedestrian_visual != null:
		return pedestrian_visual.model
	return null

func global_linear_velocity_ms() -> Vector3:
	return linear_velocity

func target_speed_kmh() -> float:
	return PhysicsMetrics.ms_to_kmh(linear_velocity.length())

func replay_visual_state() -> Dictionary:
	return {
		"rigid_transform": global_transform,
		"linear_velocity_ms": linear_velocity,
		"angular_velocity_rad_s": angular_velocity,
		"impact_received": impact_received,
	}

func apply_replay_visual_state(state: Dictionary) -> void:
	freeze = true
	var transform_value: Variant = state.get("rigid_transform", global_transform)
	if transform_value is Transform3D:
		global_transform = transform_value
	linear_velocity = state.get("linear_velocity_ms", Vector3.ZERO)
	angular_velocity = state.get("angular_velocity_rad_s", Vector3.ZERO)
	impact_received = bool(state.get("impact_received", impact_received))
