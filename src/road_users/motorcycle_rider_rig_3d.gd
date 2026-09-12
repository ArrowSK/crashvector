# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name MotorcycleRiderRig3D
extends Node3D

# A compact, physics-backed rider used by the production motorcycle.  While the
# motorcycle is intact the rider follows the seat as a constrained passenger;
# at the first real non-ground contact the constraint is released and Godot
# governs the subsequent trajectory.  No synthetic launch impulse is applied.

const TORSO_LOCAL := Vector3(0.62, 1.25, 0.0)
const HEAD_LOCAL := Vector3(0.78, 1.88, 0.0)

var chassis: VehicleRigidChassis
var torso: RigidBody3D
var head: RigidBody3D
var neck_joint: PinJoint3D
var rider_released: bool = false
var simulation_active: bool = false

func configure(source_chassis: VehicleRigidChassis) -> void:
	chassis = source_chassis
	if chassis == null or torso != null:
		return
	torso = _new_body("MotorcycleRiderTorso", 58.0, 0.52)
	_add_capsule(torso, "TorsoCollision", 0.17, 0.72, Color(0.08, 0.17, 0.34))
	_add_box_visual(torso, "RiderJacket", Vector3(0.36, 0.52, 0.46), Vector3(0.0, -0.02, 0.0), Color(0.07, 0.18, 0.38))
	_add_box_visual(torso, "RiderLegs", Vector3(0.72, 0.16, 0.32), Vector3(0.28, -0.38, 0.0), Color(0.055, 0.065, 0.08))
	_add_box_visual(torso, "RiderArms", Vector3(0.56, 0.12, 0.70), Vector3(0.22, 0.11, 0.0), Color(0.07, 0.18, 0.38))
	head = _new_body("MotorcycleRiderHead", 5.0, 0.40)
	_add_sphere(head, "HeadCollision", 0.145, Color(0.77, 0.60, 0.48))
	_add_sphere_visual(head, "Helmet", 0.158, Vector3(0.0, 0.035, 0.0), Color(0.10, 0.11, 0.13))
	neck_joint = PinJoint3D.new()
	neck_joint.name = "MotorcycleRiderNeck"
	add_child(neck_joint)
	neck_joint.node_a = neck_joint.get_path_to(torso)
	neck_joint.node_b = neck_joint.get_path_to(head)
	torso.add_collision_exception_with(head)
	head.add_collision_exception_with(torso)
	_sync_seated_pose()

func arm_for_simulation() -> void:
	rider_released = false
	simulation_active = true
	_sync_seated_pose()
	for body in [torso, head]:
		if body == null:
			continue
		body.add_collision_exception_with(chassis)
		chassis.add_collision_exception_with(body)
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

func release_from_real_contact() -> void:
	if rider_released or chassis == null:
		return
	rider_released = true
	for body in [torso, head]:
		if body == null:
			continue
		body.remove_collision_exception_with(chassis)
		chassis.remove_collision_exception_with(body)
		body.freeze = false
		body.sleeping = false
		body.linear_velocity = chassis.linear_velocity
		body.angular_velocity = chassis.angular_velocity

func sync_from_motorcycle() -> void:
	if simulation_active and not rider_released:
		_sync_seated_pose()

func end_simulation() -> void:
	simulation_active = false
	for body in [torso, head]:
		if body == null:
			continue
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

func rider_body_count() -> int:
	return 2

func _on_rider_body_entered(body: Node) -> void:
	if simulation_active and body is VehicleRigidChassis:
		release_from_real_contact()

func _sync_seated_pose() -> void:
	if chassis == null or torso == null or head == null:
		return
	torso.global_transform = _seated_transform(TORSO_LOCAL, -12.0)
	head.global_transform = _seated_transform(HEAD_LOCAL, -6.0)
	var neck_transform := neck_joint.global_transform
	neck_transform.origin = chassis.to_global(Vector3(0.73, 1.61, 0.0))
	neck_transform.basis = chassis.global_transform.basis
	neck_joint.global_transform = neck_transform

func _seated_transform(local_position: Vector3, lean_deg: float) -> Transform3D:
	var transform := chassis.global_transform
	transform.origin = chassis.to_global(local_position)
	var chassis_basis := chassis.global_transform.basis
	transform.basis = chassis_basis.rotated(chassis_basis.z.normalized(), deg_to_rad(lean_deg))
	return transform

func _new_body(node_name: String, body_mass_kg: float, friction: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = node_name
	body.mass = body_mass_kg
	body.freeze = true
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 12
	body.can_sleep = false
	body.linear_damp = 0.18
	body.angular_damp = 0.25
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = 0.0
	body.physics_material_override = material
	body.body_entered.connect(_on_rider_body_entered)
	add_child(body)
	return body

func _add_capsule(body: RigidBody3D, node_name: String, radius: float, height: float, color: Color) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	body.add_child(collision)
	_add_capsule_visual(body, "RiderTorso", radius, height, Vector3.ZERO, color)

func _add_sphere(body: RigidBody3D, node_name: String, radius: float, color: Color) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	body.add_child(collision)
	_add_sphere_visual(body, "RiderFace", radius, Vector3.ZERO, color)

func _add_box_visual(body: RigidBody3D, node_name: String, size: Vector3, position_value: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = position_value
	body.add_child(visual)

func _add_capsule_visual(body: RigidBody3D, node_name: String, radius: float, height: float, position_value: Vector3, color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.material = _material(color)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = position_value
	body.add_child(visual)

func _add_sphere_visual(body: RigidBody3D, node_name: String, radius: float, position_value: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _material(color)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = position_value
	body.add_child(visual)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.05
	material.roughness = 0.68
	return material
