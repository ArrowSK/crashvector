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
var rider_presentation_root: Node3D
var rider_presentation: Dictionary = {}

func configure(source_chassis: VehicleRigidChassis) -> void:
	chassis = source_chassis
	if chassis == null or torso != null:
		return
	torso = _new_body("MotorcycleRiderTorso", 58.0, 0.52)
	_add_capsule(torso, "TorsoCollision", 0.17, 0.72, Color(0.08, 0.17, 0.34))
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
	_build_rider_presentation()
	_sync_seated_pose()
	process_priority = 76
	set_process(true)

func _process(_delta: float) -> void:
	if chassis == null or torso == null or head == null:
		return
	_update_rider_presentation()

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
	_update_rider_presentation()

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
	_update_rider_presentation()

func sync_from_motorcycle() -> void:
	if simulation_active and not rider_released:
		_sync_seated_pose()
	_update_rider_presentation()

func end_simulation() -> void:
	simulation_active = false
	for body in [torso, head]:
		if body == null:
			continue
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	_update_rider_presentation()

func rider_body_count() -> int:
	return 2

func replay_visual_state() -> Dictionary:
	var part_states: Array[Dictionary] = []
	for body in [torso, head]:
		if body == null or not is_instance_valid(body):
			continue
		part_states.append({
			"name": String(body.name),
			"rigid_transform": body.global_transform,
			"linear_velocity_ms": body.linear_velocity,
			"angular_velocity_rad_s": body.angular_velocity,
		})
	return {
		"rider_released": rider_released,
		"part_states": part_states,
	}

func apply_replay_visual_state(state: Dictionary) -> void:
	# Replay owns the rider pose. Keep the bodies frozen while frames are applied
	# so Godot cannot advance them independently between timeline samples.
	simulation_active = false
	rider_released = bool(state.get("rider_released", false))
	for body in [torso, head]:
		if body == null or not is_instance_valid(body):
			continue
		body.freeze = true
		body.sleeping = false
		if chassis != null:
			if rider_released:
				body.remove_collision_exception_with(chassis)
				chassis.remove_collision_exception_with(body)
			else:
				body.add_collision_exception_with(chassis)
				chassis.add_collision_exception_with(body)
	var by_name: Dictionary = {}
	for body in [torso, head]:
		if body != null and is_instance_valid(body):
			by_name[String(body.name)] = body
	var part_states: Variant = state.get("part_states", [])
	var applied_part := false
	if part_states is Array:
		for raw_state in part_states:
			if not raw_state is Dictionary:
				continue
			var part_state: Dictionary = raw_state
			var body: RigidBody3D = by_name.get(String(part_state.get("name", "")))
			if body == null:
				continue
			var transform_value: Variant = part_state.get("rigid_transform", body.global_transform)
			if transform_value is Transform3D:
				body.global_transform = transform_value
			body.linear_velocity = part_state.get("linear_velocity_ms", Vector3.ZERO)
			body.angular_velocity = part_state.get("angular_velocity_rad_s", Vector3.ZERO)
			applied_part = true
	# Older recordings have no rider-part payload. Their pre-impact representation
	# was the seated rider, so retain that compatible fallback instead of leaving
	# the rider at a stale final crash pose.
	if not applied_part and not rider_released:
		_sync_seated_pose()
	_update_rider_presentation()

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
	_update_rider_presentation()

func _build_rider_presentation() -> void:
	rider_presentation_root = Node3D.new()
	rider_presentation_root.name = "MotorcycleRiderPresentation"
	add_child(rider_presentation_root)

	var jacket := _material(Color(0.07, 0.18, 0.38))
	var trousers := _material(Color(0.045, 0.055, 0.072))
	var glove := _material(Color(0.025, 0.030, 0.038))
	var boot := _material(Color(0.020, 0.024, 0.030))

	rider_presentation["pelvis"] = _presentation_capsule("RiderPelvis", 0.13, trousers)
	rider_presentation["left_upper_arm"] = _presentation_capsule("RiderLeftUpperArm", 0.065, jacket)
	rider_presentation["right_upper_arm"] = _presentation_capsule("RiderRightUpperArm", 0.065, jacket)
	rider_presentation["left_lower_arm"] = _presentation_capsule("RiderLeftLowerArm", 0.055, jacket)
	rider_presentation["right_lower_arm"] = _presentation_capsule("RiderRightLowerArm", 0.055, jacket)
	rider_presentation["left_upper_leg"] = _presentation_capsule("RiderLeftUpperLeg", 0.085, trousers)
	rider_presentation["right_upper_leg"] = _presentation_capsule("RiderRightUpperLeg", 0.085, trousers)
	rider_presentation["left_lower_leg"] = _presentation_capsule("RiderLeftLowerLeg", 0.070, trousers)
	rider_presentation["right_lower_leg"] = _presentation_capsule("RiderRightLowerLeg", 0.070, trousers)
	rider_presentation["left_boot"] = _presentation_capsule("RiderLeftBoot", 0.060, boot)
	rider_presentation["right_boot"] = _presentation_capsule("RiderRightBoot", 0.060, boot)
	rider_presentation["left_glove"] = _presentation_sphere("RiderLeftGlove", 0.070, glove)
	rider_presentation["right_glove"] = _presentation_sphere("RiderRightGlove", 0.070, glove)
	rider_presentation_root.set_meta("presentation_only", true)
	rider_presentation_root.set_meta("presentation_role", "motorcycle_rider_articulated_skin")
	_update_rider_presentation()

func _update_rider_presentation() -> void:
	if rider_presentation_root == null or torso == null:
		return

	var pose := _seated_presentation_points() if not rider_released and chassis != null else _released_presentation_points()
	_set_segment(rider_presentation.get("pelvis"), pose["pelvis_bottom"], pose["pelvis_top"])
	_set_segment(rider_presentation.get("left_upper_arm"), pose["left_shoulder"], pose["left_elbow"])
	_set_segment(rider_presentation.get("right_upper_arm"), pose["right_shoulder"], pose["right_elbow"])
	_set_segment(rider_presentation.get("left_lower_arm"), pose["left_elbow"], pose["left_hand"])
	_set_segment(rider_presentation.get("right_lower_arm"), pose["right_elbow"], pose["right_hand"])
	_set_segment(rider_presentation.get("left_upper_leg"), pose["left_hip"], pose["left_knee"])
	_set_segment(rider_presentation.get("right_upper_leg"), pose["right_hip"], pose["right_knee"])
	_set_segment(rider_presentation.get("left_lower_leg"), pose["left_knee"], pose["left_ankle"])
	_set_segment(rider_presentation.get("right_lower_leg"), pose["right_knee"], pose["right_ankle"])
	_set_segment(rider_presentation.get("left_boot"), pose["left_ankle"], pose["left_toe"])
	_set_segment(rider_presentation.get("right_boot"), pose["right_ankle"], pose["right_toe"])
	_set_point(rider_presentation.get("left_glove"), pose["left_hand"])
	_set_point(rider_presentation.get("right_glove"), pose["right_hand"])

func _seated_presentation_points() -> Dictionary:
	var p := {}
	p["pelvis_bottom"] = chassis.to_global(Vector3(0.40, 0.96, 0.0))
	p["pelvis_top"] = chassis.to_global(Vector3(0.47, 1.13, 0.0))
	p["left_shoulder"] = chassis.to_global(Vector3(0.80, 1.47, -0.19))
	p["right_shoulder"] = chassis.to_global(Vector3(0.80, 1.47, 0.19))
	p["left_elbow"] = chassis.to_global(Vector3(1.22, 1.31, -0.25))
	p["right_elbow"] = chassis.to_global(Vector3(1.22, 1.31, 0.25))
	p["left_hand"] = chassis.to_global(Vector3(1.73, 1.17, -0.35))
	p["right_hand"] = chassis.to_global(Vector3(1.73, 1.17, 0.35))
	p["left_hip"] = chassis.to_global(Vector3(0.44, 1.03, -0.11))
	p["right_hip"] = chassis.to_global(Vector3(0.44, 1.03, 0.11))
	p["left_knee"] = chassis.to_global(Vector3(1.05, 0.80, -0.18))
	p["right_knee"] = chassis.to_global(Vector3(1.05, 0.80, 0.18))
	p["left_ankle"] = chassis.to_global(Vector3(0.88, 0.55, -0.22))
	p["right_ankle"] = chassis.to_global(Vector3(0.88, 0.55, 0.22))
	p["left_toe"] = chassis.to_global(Vector3(1.03, 0.52, -0.22))
	p["right_toe"] = chassis.to_global(Vector3(1.03, 0.52, 0.22))
	return p

func _released_presentation_points() -> Dictionary:
	var p := {}
	var t := torso.global_transform
	# Once released there are still only two physical rider bodies. Keep the
	# limbs attached to the authoritative torso body in a compact, neutral fall
	# pose instead of leaving them visually attached to the motorcycle.
	p["pelvis_bottom"] = t * Vector3(-0.07, -0.38, 0.0)
	p["pelvis_top"] = t * Vector3(-0.02, -0.20, 0.0)
	p["left_shoulder"] = t * Vector3(0.02, 0.22, -0.18)
	p["right_shoulder"] = t * Vector3(0.02, 0.22, 0.18)
	p["left_elbow"] = t * Vector3(0.24, 0.02, -0.27)
	p["right_elbow"] = t * Vector3(0.24, 0.02, 0.27)
	p["left_hand"] = t * Vector3(0.17, -0.20, -0.22)
	p["right_hand"] = t * Vector3(0.17, -0.20, 0.22)
	p["left_hip"] = t * Vector3(-0.05, -0.30, -0.11)
	p["right_hip"] = t * Vector3(-0.05, -0.30, 0.11)
	p["left_knee"] = t * Vector3(0.18, -0.55, -0.15)
	p["right_knee"] = t * Vector3(0.18, -0.55, 0.15)
	p["left_ankle"] = t * Vector3(-0.02, -0.79, -0.13)
	p["right_ankle"] = t * Vector3(-0.02, -0.79, 0.13)
	p["left_toe"] = t * Vector3(0.16, -0.82, -0.13)
	p["right_toe"] = t * Vector3(0.16, -0.82, 0.13)
	return p

func presentation_segment_count() -> int:
	return rider_presentation.size()

func presentation_point(name_value: StringName) -> Vector3:
	var visual := rider_presentation.get(String(name_value), null) as MeshInstance3D
	return visual.global_position if visual != null else Vector3.ZERO

func _presentation_capsule(node_name: String, radius: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(radius * 2.0 + 0.01, 0.30)
	mesh.radial_segments = 16
	mesh.rings = 5
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	rider_presentation_root.add_child(visual)
	return visual

func _presentation_sphere(node_name: String, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	rider_presentation_root.add_child(visual)
	return visual

func _set_segment(instance_value: Variant, start: Vector3, finish: Vector3) -> void:
	var visual := instance_value as MeshInstance3D
	if visual == null:
		return
	var delta := finish - start
	var length := delta.length()
	if length <= 0.005:
		visual.visible = false
		return
	visual.visible = true
	if visual.mesh is CapsuleMesh:
		var capsule := visual.mesh as CapsuleMesh
		capsule.height = maxf(length, capsule.radius * 2.0 + 0.01)
	visual.global_position = (start + finish) * 0.5
	visual.global_basis = _basis_y_along(delta.normalized())
	visual.set_meta("presentation_start", start)
	visual.set_meta("presentation_end", finish)

func _set_point(instance_value: Variant, position_value: Vector3) -> void:
	var visual := instance_value as MeshInstance3D
	if visual != null:
		visual.global_position = position_value

func _basis_y_along(direction: Vector3) -> Basis:
	var target := direction.normalized()
	var dot := clampf(Vector3.UP.dot(target), -1.0, 1.0)
	if dot > 0.9999:
		return Basis.IDENTITY
	if dot < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	var axis := Vector3.UP.cross(target).normalized()
	return Basis(axis, acos(dot))

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
