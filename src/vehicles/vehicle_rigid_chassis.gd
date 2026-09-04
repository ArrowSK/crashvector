# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleRigidChassis
extends RigidBody3D

var contact_samples: Array[Dictionary] = []
var suspension_points: Array[Dictionary] = []
var front_crush_probe: RayCast3D
var front_probe_rest_length_m: float = 0.0
var front_probe_collider: Object
var front_probe_contact_active: bool = false
var front_probe_contact_ever: bool = false
var maximum_front_probe_crush_m: float = 0.0
var non_ground_contact_events: int = 0
var cumulative_non_ground_impulse_ns: float = 0.0
var maximum_vertical_speed_ms: float = 0.0
var maximum_reverse_speed_ms: float = 0.0
var maximum_suspension_compression_m: float = 0.0
var active_suspension_contacts: int = 0
var initial_forward_world := Vector3.RIGHT
var stored_linear_velocity := Vector3.ZERO
var stored_angular_velocity := Vector3.ZERO

func configure(
	body_mass_kg: float,
	spawn_position_m: Vector3,
	heading_deg: float,
	initial_speed_kmh: float,
	friction: float = 0.85,
	bounce: float = 0.0
) -> void:
	mass = maxf(body_mass_kg, 1.0)
	position = spawn_position_m
	rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	initial_forward_world = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
	linear_velocity = initial_forward_world * PhysicsMetrics.kmh_to_ms(initial_speed_kmh)
	angular_velocity = Vector3.ZERO
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 32
	can_sleep = false
	linear_damp = 0.01
	angular_damp = 0.03
	var material := PhysicsMaterial.new()
	material.friction = clampf(friction, 0.0, 1.0)
	material.bounce = clampf(bounce, 0.0, 0.12)
	physics_material_override = material
	freeze = true

func add_box_shape(node_name: String, size_m: Vector3, local_position_m: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size_m
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	add_child(collision)
	return collision

func add_sphere_shape(node_name: String, radius_m: float, local_position_m: Vector3) -> CollisionShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius_m
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	add_child(collision)
	return collision

func add_front_crush_probe(
	local_mount_m: Vector3,
	rest_length_m: float,
	extra_range_m: float = 0.20
) -> RayCast3D:
	front_probe_rest_length_m = maxf(rest_length_m, 0.05)
	front_crush_probe = RayCast3D.new()
	front_crush_probe.name = "FrontCrushProbe"
	front_crush_probe.position = local_mount_m
	front_crush_probe.target_position = Vector3(front_probe_rest_length_m + maxf(extra_range_m, 0.02), 0.0, 0.0)
	front_crush_probe.enabled = true
	front_crush_probe.exclude_parent = true
	add_child(front_crush_probe)
	return front_crush_probe

# Compatibility bridge for the first M12 branch revision. The former box
# sensor's rear face is exactly the firewall-side probe origin and its X size
# is the undeformed crush-zone length, so preserve that call shape while using
# the more reliable distance probe internally.
func add_front_crush_sensor(size_m: Vector3, local_position_m: Vector3) -> RayCast3D:
	var mount := local_position_m - Vector3(size_m.x * 0.5, 0.0, 0.0)
	return add_front_crush_probe(mount, size_m.x, 0.22)

func add_suspension_point(
	node_name: String,
	local_mount_m: Vector3,
	rest_distance_m: float,
	stiffness_n_m: float,
	damping_n_s_m: float,
	maximum_force_n: float
) -> RayCast3D:
	var ray := RayCast3D.new()
	ray.name = node_name
	ray.position = local_mount_m
	ray.target_position = Vector3(0.0, -maxf(rest_distance_m + 0.25, 0.30), 0.0)
	ray.enabled = true
	ray.exclude_parent = true
	add_child(ray)
	suspension_points.append({
		"ray": ray,
		"rest_distance_m": maxf(rest_distance_m, 0.05),
		"stiffness_n_m": maxf(stiffness_n_m, 1.0),
		"damping_n_s_m": maxf(damping_n_s_m, 0.0),
		"maximum_force_n": maxf(maximum_force_n, 1.0),
	})
	return ray

func begin_motion(speed_kmh: float, heading_deg: float) -> void:
	initial_forward_world = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
	linear_velocity = initial_forward_world * PhysicsMetrics.kmh_to_ms(speed_kmh)
	angular_velocity = Vector3.ZERO
	stored_linear_velocity = linear_velocity
	stored_angular_velocity = Vector3.ZERO
	contact_samples.clear()
	non_ground_contact_events = 0
	cumulative_non_ground_impulse_ns = 0.0
	maximum_vertical_speed_ms = 0.0
	maximum_reverse_speed_ms = 0.0
	maximum_suspension_compression_m = 0.0
	active_suspension_contacts = 0
	front_probe_collider = null
	front_probe_contact_active = false
	front_probe_contact_ever = false
	maximum_front_probe_crush_m = 0.0
	freeze = false
	sleeping = false

func set_motion_paused(value: bool) -> void:
	if value:
		stored_linear_velocity = linear_velocity
		stored_angular_velocity = angular_velocity
		freeze = true
		return
	freeze = false
	linear_velocity = stored_linear_velocity
	angular_velocity = stored_angular_velocity
	sleeping = false

func stop_motion() -> void:
	stored_linear_velocity = linear_velocity
	stored_angular_velocity = angular_velocity
	freeze = true

func drain_contact_samples() -> Array[Dictionary]:
	var result: Array[Dictionary] = contact_samples.duplicate(true)
	contact_samples.clear()
	return result

func front_crush_travel_m() -> float:
	return maximum_front_probe_crush_m

func front_crush_overlap_active() -> bool:
	return front_probe_contact_active

func front_crush_collider() -> Object:
	return front_probe_collider

func _physics_process(delta: float) -> void:
	if freeze or delta <= 0.0:
		return
	_update_suspension()
	_update_front_crush_probe()

func _update_suspension() -> void:
	active_suspension_contacts = 0
	for point in suspension_points:
		var ray := point.get("ray") as RayCast3D
		if ray == null or not ray.is_colliding():
			continue
		var collider := ray.get_collider()
		var collider_name := StringName("")
		if collider is Node:
			collider_name = (collider as Node).name
		if not _is_ground_contact(collider_name):
			continue
		var distance_m := ray.global_position.distance_to(ray.get_collision_point())
		var rest_distance := float(point.get("rest_distance_m", 0.60))
		var compression := maxf(rest_distance - distance_m, 0.0)
		if compression <= 0.0:
			continue
		maximum_suspension_compression_m = maxf(maximum_suspension_compression_m, compression)
		active_suspension_contacts += 1
		var offset_world := ray.global_position - global_position
		var point_velocity := linear_velocity + angular_velocity.cross(offset_world)
		var spring_force := float(point.get("stiffness_n_m", 60000.0)) * compression
		var damping_force := -float(point.get("damping_n_s_m", 6000.0)) * point_velocity.dot(Vector3.UP)
		var normal_force := clampf(
			spring_force + damping_force,
			0.0,
			float(point.get("maximum_force_n", 12000.0))
		)
		apply_force(Vector3.UP * normal_force, offset_world)

func _update_front_crush_probe() -> void:
	front_probe_contact_active = false
	front_probe_collider = null
	if front_crush_probe == null:
		return
	front_crush_probe.force_raycast_update()
	if not front_crush_probe.is_colliding():
		return
	var collider := front_crush_probe.get_collider()
	var collider_name := StringName("")
	if collider is Node:
		collider_name = (collider as Node).name
	if _is_ground_contact(collider_name):
		return
	var collision_distance := front_crush_probe.global_position.distance_to(front_crush_probe.get_collision_point())
	var crush := maxf(front_probe_rest_length_m - collision_distance, 0.0)
	front_probe_collider = collider
	front_probe_contact_active = true
	front_probe_contact_ever = true
	maximum_front_probe_crush_m = maxf(maximum_front_probe_crush_m, crush)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	contact_samples.clear()
	maximum_vertical_speed_ms = maxf(maximum_vertical_speed_ms, absf(state.linear_velocity.y))
	var forward_speed := state.linear_velocity.dot(initial_forward_world)
	maximum_reverse_speed_ms = maxf(maximum_reverse_speed_ms, maxf(-forward_speed, 0.0))
	for contact_index in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(contact_index)
		var collider_name := StringName("")
		if collider is Node:
			collider_name = (collider as Node).name
		var impulse := state.get_contact_impulse(contact_index)
		var sample := {
			"position_world": state.get_contact_local_position(contact_index),
			"normal": state.get_contact_local_normal(contact_index),
			"impulse": impulse,
			"collider_name": collider_name,
			"local_shape": state.get_contact_local_shape(contact_index),
		}
		contact_samples.append(sample)
		if not _is_ground_contact(collider_name):
			non_ground_contact_events += 1
			cumulative_non_ground_impulse_ns += impulse.length()

func _is_ground_contact(collider_name: StringName) -> bool:
	return collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround"
