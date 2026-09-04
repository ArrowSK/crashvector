# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleRigidChassis
extends RigidBody3D

var contact_samples: Array[Dictionary] = []
var non_ground_contact_events: int = 0
var cumulative_non_ground_impulse_ns: float = 0.0
var maximum_vertical_speed_ms: float = 0.0
var maximum_reverse_speed_ms: float = 0.0
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
