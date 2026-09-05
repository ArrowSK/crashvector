# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RoadUserRigidProxy3D
extends RigidBody3D

# M15 keeps the M14 production API and RigidBody3D root, but replaces the
# single-body road-user approximation with a lightweight articulated rig.
# Pedestrians use independently simulated rigid segments connected by pin
# joints. Bicycles use a rigid frame plus independently simulated wheel bodies.
# This remains an educational contact/trajectory model, not biomechanics,
# injury prediction or a validated cyclist model.

var target_type: StringName = ScenarioConfig.TARGET_PEDESTRIAN
var preset_id: StringName = RoadUserCatalog.PEDESTRIAN_ADULT
var target_mass_kg: float = 75.0
var initial_speed_kmh: float = 0.0
var origin_offset_m := Vector3.ZERO
var heading_deg: float = 0.0
var show_structure: bool = false

# Compatibility presentation models remain available to inherited replay /
# analysis code. They are hidden and do not drive production world motion.
var bicycle_visual: Bicycle
var pedestrian_visual: Pedestrian

var impact_received: bool = false
var simulation_active: bool = false
var maximum_vertical_speed_ms: float = 0.0
var maximum_speed_ms: float = 0.0
var maximum_travel_m: float = 0.0
var maximum_articulation_angle_deg: float = 0.0
var maximum_wheel_spin_rad_s: float = 0.0
var initial_world_position := Vector3.ZERO

var articulated_bodies: Array[RigidBody3D] = []
var articulated_joints: Array[Joint3D] = []
var _body_local_offsets: Dictionary = {}
var _joint_local_anchors: Dictionary = {}
var _initial_relative_bases: Dictionary = {}
var _paused_body_states: Dictionary = {}
var _root_com_local := Vector3.ZERO
var _pedestrian_torso: RigidBody3D
var _bicycle_wheels: Array[RigidBody3D] = []
var _cleaning_up: bool = false

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
	contact_monitor = true
	max_contacts_reported = 24
	continuous_cd = true
	can_sleep = false
	linear_damp = 0.025
	angular_damp = 0.055
	_build_compatibility_model()
	if target_type == ScenarioConfig.TARGET_BICYCLE:
		_build_bicycle_rig()
	else:
		_build_pedestrian_rig()
	_apply_self_collision_exceptions()
	set_preview_pose(origin_offset_m, heading_deg)

func _exit_tree() -> void:
	if _cleaning_up:
		return
	_cleaning_up = true
	for joint in articulated_joints:
		if joint != null and is_instance_valid(joint):
			joint.queue_free()
	for body in articulated_bodies:
		if body != null and is_instance_valid(body):
			body.queue_free()
	articulated_joints.clear()
	articulated_bodies.clear()

func _physics_process(_delta: float) -> void:
	if not simulation_active:
		return
	var velocity := center_of_mass_velocity_ms()
	maximum_vertical_speed_ms = maxf(maximum_vertical_speed_ms, absf(velocity.y))
	maximum_speed_ms = maxf(maximum_speed_ms, velocity.length())
	maximum_travel_m = maxf(maximum_travel_m, center_of_mass_position().distance_to(initial_world_position))
	_update_articulation_metrics()

func _build_compatibility_model() -> void:
	if target_type == ScenarioConfig.TARGET_BICYCLE:
		bicycle_visual = Bicycle.new()
		bicycle_visual.name = "BicycleStructuralReference"
		bicycle_visual.bicycle_preset_id = preset_id
		bicycle_visual.total_mass_kg = target_mass_kg
		bicycle_visual.initial_speed_kmh = 0.0
		bicycle_visual.origin_offset_m = Vector3.ZERO
		bicycle_visual.heading_deg = 0.0
		bicycle_visual.auto_step = false
		bicycle_visual.show_structure = show_structure
		bicycle_visual.visible = false
		add_child(bicycle_visual)
	else:
		pedestrian_visual = Pedestrian.new()
		pedestrian_visual.name = "PedestrianStructuralReference"
		pedestrian_visual.body_preset_id = preset_id
		pedestrian_visual.total_mass_kg = target_mass_kg
		pedestrian_visual.origin_offset_m = Vector3.ZERO
		pedestrian_visual.heading_deg = 0.0
		pedestrian_visual.auto_step = false
		pedestrian_visual.show_structure = show_structure
		pedestrian_visual.visible = false
		add_child(pedestrian_visual)

func _configure_body(body: RigidBody3D, body_mass_kg: float, friction: float) -> void:
	body.mass = maxf(body_mass_kg, 0.20)
	body.gravity_scale = 1.0
	body.continuous_cd = true
	body.can_sleep = false
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.linear_damp = 0.025
	body.angular_damp = 0.065
	body.freeze = true
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = 0.01
	body.physics_material_override = material
	body.body_entered.connect(_on_articulated_body_entered)

func _build_pedestrian_rig() -> void:
	var scale := RoadUserCatalog.pedestrian_height_m(preset_id) / 1.75
	# Segment fractions sum to 1.00. They are intentionally generic and are used
	# only to produce a credible articulated trajectory, not injury measures.
	var root_mass := target_mass_kg * 0.14
	_configure_body(self, root_mass, 0.58)
	_root_com_local = Vector3(0.0, 0.86 * scale, 0.0)
	_add_box_collision(self, "PelvisCollision", Vector3(0.24, 0.22, 0.32) * scale, _root_com_local)
	_add_box_visual(self, "Pelvis", Vector3(0.24, 0.22, 0.32) * scale, _root_com_local, Color(0.17, 0.34, 0.58))

	_pedestrian_torso = _new_part("PedestrianTorso", target_mass_kg * 0.36, Vector3(0.0, 1.18 * scale, 0.0), 0.58)
	_add_box_collision(_pedestrian_torso, "TorsoCollision", Vector3(0.30, 0.48, 0.40) * scale, Vector3.ZERO)
	_add_box_visual(_pedestrian_torso, "Torso", Vector3(0.30, 0.48, 0.40) * scale, Vector3.ZERO, Color(0.17, 0.34, 0.58))

	var head := _new_part("PedestrianHead", target_mass_kg * 0.08, Vector3(0.0, 1.62 * scale, 0.0), 0.48)
	_add_sphere_collision(head, "HeadCollision", 0.13 * scale, Vector3.ZERO)
	_add_sphere_visual(head, "Head", 0.13 * scale, Vector3.ZERO, Color(0.78, 0.62, 0.50))

	var left_upper_arm := _new_part("LeftUpperArm", target_mass_kg * 0.03, Vector3(0.0, 1.18 * scale, -0.27 * scale), 0.52)
	var right_upper_arm := _new_part("RightUpperArm", target_mass_kg * 0.03, Vector3(0.0, 1.18 * scale, 0.27 * scale), 0.52)
	var left_lower_arm := _new_part("LeftLowerArm", target_mass_kg * 0.02, Vector3(0.0, 0.90 * scale, -0.28 * scale), 0.52)
	var right_lower_arm := _new_part("RightLowerArm", target_mass_kg * 0.02, Vector3(0.0, 0.90 * scale, 0.28 * scale), 0.52)
	for arm in [left_upper_arm, right_upper_arm]:
		_add_capsule_collision(arm, "UpperArmCollision", 0.065 * scale, 0.34 * scale, Vector3.ZERO)
		_add_capsule_visual(arm, "UpperArm", 0.065 * scale, 0.34 * scale, Color(0.17, 0.34, 0.58))
	for arm in [left_lower_arm, right_lower_arm]:
		_add_capsule_collision(arm, "LowerArmCollision", 0.055 * scale, 0.30 * scale, Vector3.ZERO)
		_add_capsule_visual(arm, "LowerArm", 0.055 * scale, 0.30 * scale, Color(0.78, 0.62, 0.50))

	var left_upper_leg := _new_part("LeftUpperLeg", target_mass_kg * 0.10, Vector3(0.0, 0.62 * scale, -0.09 * scale), 0.64)
	var right_upper_leg := _new_part("RightUpperLeg", target_mass_kg * 0.10, Vector3(0.0, 0.62 * scale, 0.09 * scale), 0.64)
	var left_lower_leg := _new_part("LeftLowerLeg", target_mass_kg * 0.06, Vector3(0.0, 0.27 * scale, -0.09 * scale), 0.68)
	var right_lower_leg := _new_part("RightLowerLeg", target_mass_kg * 0.06, Vector3(0.0, 0.27 * scale, 0.09 * scale), 0.68)
	for leg in [left_upper_leg, right_upper_leg]:
		_add_capsule_collision(leg, "UpperLegCollision", 0.085 * scale, 0.40 * scale, Vector3.ZERO)
		_add_capsule_visual(leg, "UpperLeg", 0.085 * scale, 0.40 * scale, Color(0.17, 0.34, 0.58))
	for leg in [left_lower_leg, right_lower_leg]:
		_add_capsule_collision(leg, "LowerLegCollision", 0.072 * scale, 0.36 * scale, Vector3.ZERO)
		_add_capsule_visual(leg, "LowerLeg", 0.072 * scale, 0.36 * scale, Color(0.08, 0.10, 0.14))

	_add_pin_joint("SpineJoint", self, _pedestrian_torso, Vector3(0.0, 1.00 * scale, 0.0))
	_add_pin_joint("NeckJoint", _pedestrian_torso, head, Vector3(0.0, 1.50 * scale, 0.0))
	_add_pin_joint("LeftShoulderJoint", _pedestrian_torso, left_upper_arm, Vector3(0.0, 1.35 * scale, -0.24 * scale))
	_add_pin_joint("RightShoulderJoint", _pedestrian_torso, right_upper_arm, Vector3(0.0, 1.35 * scale, 0.24 * scale))
	_add_pin_joint("LeftElbowJoint", left_upper_arm, left_lower_arm, Vector3(0.0, 1.03 * scale, -0.28 * scale))
	_add_pin_joint("RightElbowJoint", right_upper_arm, right_lower_arm, Vector3(0.0, 1.03 * scale, 0.28 * scale))
	_add_pin_joint("LeftHipJoint", self, left_upper_leg, Vector3(0.0, 0.80 * scale, -0.09 * scale))
	_add_pin_joint("RightHipJoint", self, right_upper_leg, Vector3(0.0, 0.80 * scale, 0.09 * scale))
	_add_pin_joint("LeftKneeJoint", left_upper_leg, left_lower_leg, Vector3(0.0, 0.44 * scale, -0.09 * scale))
	_add_pin_joint("RightKneeJoint", right_upper_leg, right_lower_leg, Vector3(0.0, 0.44 * scale, 0.09 * scale))

func _build_bicycle_rig() -> void:
	var wheel_fraction := 0.16
	var frame_mass := target_mass_kg * (1.0 - wheel_fraction * 2.0)
	_configure_body(self, frame_mass, 0.70)
	_root_com_local = Vector3(0.0, 0.70, 0.0)
	_add_box_collision(self, "BicycleFrameCollision", Vector3(1.18, 0.30, 0.20), Vector3(0.0, 0.70, 0.0))
	_build_bicycle_frame_visuals()

	var rear_wheel := _new_part("BicycleRearWheel", target_mass_kg * wheel_fraction, Vector3(-0.72, 0.34, 0.0), 0.82)
	var front_wheel := _new_part("BicycleFrontWheel", target_mass_kg * wheel_fraction, Vector3(0.74, 0.34, 0.0), 0.82)
	_bicycle_wheels = [rear_wheel, front_wheel]
	for wheel in _bicycle_wheels:
		_add_cylinder_collision(wheel, "WheelCollision", 0.34, 0.065, Vector3.ZERO, Vector3(90.0, 0.0, 0.0))
		_add_cylinder_visual(wheel, "Wheel", 0.34, 0.065, Color(0.025, 0.028, 0.032))
	_add_pin_joint("RearHubJoint", self, rear_wheel, Vector3(-0.72, 0.34, 0.0))
	_add_pin_joint("FrontHubJoint", self, front_wheel, Vector3(0.74, 0.34, 0.0))

func _new_part(node_name: String, body_mass_kg: float, local_offset: Vector3, friction: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = node_name
	_configure_body(body, body_mass_kg, friction)
	_body_local_offsets[body.name] = local_offset
	articulated_bodies.append(body)
	get_parent().add_child(body)
	return body

func _add_pin_joint(node_name: String, body_a: PhysicsBody3D, body_b: PhysicsBody3D, local_anchor: Vector3) -> void:
	var joint := PinJoint3D.new()
	joint.name = node_name
	articulated_joints.append(joint)
	_joint_local_anchors[joint.name] = local_anchor
	get_parent().add_child(joint)
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)

func _apply_self_collision_exceptions() -> void:
	var all_bodies: Array[PhysicsBody3D] = [self]
	for body in articulated_bodies:
		all_bodies.append(body)
	for i in range(all_bodies.size()):
		for j in range(i + 1, all_bodies.size()):
			all_bodies[i].add_collision_exception_with(all_bodies[j])
			all_bodies[j].add_collision_exception_with(all_bodies[i])

func _add_box_collision(body: CollisionObject3D, node_name: String, size_m: Vector3, local_position_m: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size_m
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	body.add_child(collision)

func _add_sphere_collision(body: CollisionObject3D, node_name: String, radius_m: float, local_position_m: Vector3) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius_m
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	body.add_child(collision)

func _add_capsule_collision(body: CollisionObject3D, node_name: String, radius_m: float, height_m: float, local_position_m: Vector3) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = radius_m
	shape.height = maxf(height_m, radius_m * 2.0 + 0.01)
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	body.add_child(collision)

func _add_cylinder_collision(body: CollisionObject3D, node_name: String, radius_m: float, height_m: float, local_position_m: Vector3, rotation_deg: Vector3) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius_m
	shape.height = height_m
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	collision.position = local_position_m
	collision.rotation_degrees = rotation_deg
	body.add_child(collision)

func _visual_material(color: Color, metallic: float = 0.0, roughness: float = 0.72) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add_box_visual(body: Node3D, node_name: String, size_m: Vector3, local_position_m: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size_m
	mesh.material = _visual_material(color)
	visual.mesh = mesh
	visual.position = local_position_m
	body.add_child(visual)

func _add_sphere_visual(body: Node3D, node_name: String, radius_m: float, local_position_m: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius_m
	mesh.height = radius_m * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _visual_material(color)
	visual.mesh = mesh
	visual.position = local_position_m
	body.add_child(visual)

func _add_capsule_visual(body: Node3D, node_name: String, radius_m: float, height_m: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius_m
	mesh.height = maxf(height_m, radius_m * 2.0 + 0.01)
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = _visual_material(color)
	visual.mesh = mesh
	body.add_child(visual)

func _add_cylinder_visual(body: Node3D, node_name: String, radius_m: float, height_m: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_m
	mesh.bottom_radius = radius_m
	mesh.height = height_m
	mesh.radial_segments = 28
	mesh.material = _visual_material(color, 0.0, 0.90)
	visual.mesh = mesh
	visual.rotation_degrees.x = 90.0
	body.add_child(visual)

func _build_bicycle_frame_visuals() -> void:
	var frame_color := Color(0.16, 0.42, 0.68)
	if preset_id == RoadUserCatalog.BICYCLE_ROAD:
		frame_color = Color(0.76, 0.16, 0.08)
	elif preset_id == RoadUserCatalog.BICYCLE_EBIKE:
		frame_color = Color(0.16, 0.50, 0.34)
	var material := _visual_material(frame_color, 0.42, 0.34)
	var rear_lower := Vector3(-0.30, 0.52, 0.0)
	var rear_upper := Vector3(-0.33, 0.98, 0.0)
	var front_upper := Vector3(0.35, 1.00, 0.0)
	var rear_hub := Vector3(-0.72, 0.34, 0.0)
	var front_hub := Vector3(0.74, 0.34, 0.0)
	_add_frame_segment_visual("TopTube", rear_upper, front_upper, 0.040, material)
	_add_frame_segment_visual("DownTube", rear_lower, front_upper, 0.046, material)
	_add_frame_segment_visual("SeatTube", rear_lower, rear_upper, 0.043, material)
	_add_frame_segment_visual("RearStay", rear_hub, rear_upper, 0.034, material)
	_add_frame_segment_visual("RearChainStay", rear_hub, rear_lower, 0.034, material)
	_add_frame_segment_visual("Fork", front_upper, front_hub, 0.040, material)
	_add_box_visual(self, "Saddle", Vector3(0.25, 0.055, 0.16), rear_upper + Vector3(-0.02, 0.11, 0.0), Color(0.02, 0.02, 0.025))
	_add_box_visual(self, "Handlebar", Vector3(0.055, 0.055, 0.52), front_upper + Vector3(0.06, 0.18, 0.0), Color(0.48, 0.50, 0.53))
	if preset_id == RoadUserCatalog.BICYCLE_EBIKE:
		_add_box_visual(self, "Battery", Vector3(0.34, 0.11, 0.13), rear_lower.lerp(front_upper, 0.52), Color(0.03, 0.04, 0.04))

func _add_frame_segment_visual(node_name: String, a: Vector3, b: Vector3, thickness: float, material: Material) -> void:
	var delta := b - a
	var length := delta.length()
	if length <= 0.001:
		return
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, thickness, thickness)
	mesh.material = material
	visual.mesh = mesh
	visual.position = (a + b) * 0.5
	visual.rotation.z = atan2(delta.y, delta.x)
	add_child(visual)

func set_preview_pose(position_m: Vector3, yaw_deg: float) -> void:
	origin_offset_m = position_m
	heading_deg = yaw_deg
	freeze = true
	global_position = position_m
	rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	for body in articulated_bodies:
		if body == null or not is_instance_valid(body):
			continue
		body.freeze = true
		var offset: Vector3 = _body_local_offsets.get(body.name, Vector3.ZERO)
		body.global_position = position_m + yaw_basis * offset
		body.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	for joint in articulated_joints:
		if joint == null or not is_instance_valid(joint):
			continue
		var anchor: Vector3 = _joint_local_anchors.get(joint.name, Vector3.ZERO)
		joint.global_position = position_m + yaw_basis * anchor
		joint.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	impact_received = false
	simulation_active = false
	maximum_vertical_speed_ms = 0.0
	maximum_speed_ms = 0.0
	maximum_travel_m = 0.0
	maximum_articulation_angle_deg = 0.0
	maximum_wheel_spin_rad_s = 0.0
	_initial_relative_bases.clear()
	for body in articulated_bodies:
		if body != null and is_instance_valid(body):
			_initial_relative_bases[body.name] = global_transform.basis.inverse() * body.global_transform.basis
	initial_world_position = center_of_mass_position()

func begin_simulation() -> void:
	set_preview_pose(origin_offset_m, heading_deg)
	var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
	var initial_velocity := forward * PhysicsMetrics.kmh_to_ms(initial_speed_kmh)
	freeze = false
	sleeping = false
	linear_velocity = initial_velocity
	for body in articulated_bodies:
		if body == null or not is_instance_valid(body):
			continue
		body.freeze = false
		body.sleeping = false
		body.linear_velocity = initial_velocity
		body.angular_velocity = Vector3.ZERO
	simulation_active = true
	initial_world_position = center_of_mass_position()

func end_simulation() -> void:
	simulation_active = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	for body in articulated_bodies:
		if body != null and is_instance_valid(body):
			body.freeze = true
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO

func set_simulation_paused(value: bool) -> void:
	if value:
		if freeze:
			return
		_paused_body_states.clear()
		_paused_body_states[name] = {"linear": linear_velocity, "angular": angular_velocity}
		freeze = true
		for body in articulated_bodies:
			if body != null and is_instance_valid(body):
				_paused_body_states[body.name] = {"linear": body.linear_velocity, "angular": body.angular_velocity}
				body.freeze = true
		return
	if not simulation_active:
		return
	freeze = false
	sleeping = false
	var root_state: Dictionary = _paused_body_states.get(name, {})
	linear_velocity = root_state.get("linear", Vector3.ZERO)
	angular_velocity = root_state.get("angular", Vector3.ZERO)
	for body in articulated_bodies:
		if body == null or not is_instance_valid(body):
			continue
		var state: Dictionary = _paused_body_states.get(body.name, {})
		body.freeze = false
		body.sleeping = false
		body.linear_velocity = state.get("linear", Vector3.ZERO)
		body.angular_velocity = state.get("angular", Vector3.ZERO)

func owns_collider(collider: Object) -> bool:
	if collider == self:
		return true
	for body in articulated_bodies:
		if collider == body:
			return true
	return false

func apply_probe_contact(source: VehicleRigidChassis, collider: Object = null) -> void:
	if impact_received or source == null or not simulation_active:
		return
	var forward := source.global_transform.basis.x.normalized()
	var target_velocity := center_of_mass_velocity_ms()
	var closing_speed := maxf((source.linear_velocity - target_velocity).dot(forward), 0.0)
	if closing_speed < 0.25:
		return
	var effective_mass := source.mass * target_mass_kg / maxf(source.mass + target_mass_kg, 1.0)
	var transfer_impulse_ns := effective_mass * closing_speed * 0.88
	if target_type == ScenarioConfig.TARGET_BICYCLE:
		# Put most of the nose impulse into the frame and a smaller share into the
		# contacted wheel/body. Hub joints then generate wheel/frame relative motion.
		apply_central_impulse(forward * transfer_impulse_ns * 0.72 + Vector3.UP * transfer_impulse_ns * 0.025)
		var contacted := _owned_body_from_collider(collider)
		if contacted != null and contacted != self:
			contacted.apply_central_impulse(forward * transfer_impulse_ns * 0.28)
		elif not _bicycle_wheels.is_empty():
			_bicycle_wheels[0].apply_central_impulse(forward * transfer_impulse_ns * 0.14)
			_bicycle_wheels[1].apply_central_impulse(forward * transfer_impulse_ns * 0.14)
	else:
		# Split the impulse across pelvis and torso rather than using the old fixed
		# artificial tumble torque. The articulated chain itself produces the body
		# rotation and limb lag after contact.
		apply_central_impulse(forward * transfer_impulse_ns * 0.48 + Vector3.UP * transfer_impulse_ns * 0.035)
		if _pedestrian_torso != null:
			_pedestrian_torso.apply_central_impulse(forward * transfer_impulse_ns * 0.44 + Vector3.UP * transfer_impulse_ns * 0.045)
		var contacted := _owned_body_from_collider(collider)
		if contacted != null and contacted != self and contacted != _pedestrian_torso:
			contacted.apply_central_impulse(forward * transfer_impulse_ns * 0.08)
	impact_received = true

func _owned_body_from_collider(collider: Object) -> RigidBody3D:
	if collider == self:
		return self
	for body in articulated_bodies:
		if collider == body:
			return body
	return null

func _on_articulated_body_entered(body: Node) -> void:
	if body is VehicleRigidChassis:
		impact_received = true

func center_of_mass_position() -> Vector3:
	var weighted := (global_position + global_transform.basis * _root_com_local) * mass
	var total := mass
	for body in articulated_bodies:
		if body == null or not is_instance_valid(body):
			continue
		weighted += body.global_position * body.mass
		total += body.mass
	return weighted / maxf(total, 0.001)

func center_of_mass_velocity_ms() -> Vector3:
	var weighted := linear_velocity * mass
	var total := mass
	for body in articulated_bodies:
		if body == null or not is_instance_valid(body):
			continue
		weighted += body.linear_velocity * body.mass
		total += body.mass
	return weighted / maxf(total, 0.001)

func _update_articulation_metrics() -> void:
	var inverse_root := global_transform.basis.inverse()
	for body in articulated_bodies:
		if body == null or not is_instance_valid(body):
			continue
		var initial_basis: Basis = _initial_relative_bases.get(body.name, Basis.IDENTITY)
		var current_basis := inverse_root * body.global_transform.basis
		var angle := rad_to_deg(initial_basis.get_rotation_quaternion().angle_to(current_basis.get_rotation_quaternion()))
		maximum_articulation_angle_deg = maxf(maximum_articulation_angle_deg, angle)
	for wheel in _bicycle_wheels:
		if wheel != null and is_instance_valid(wheel):
			maximum_wheel_spin_rad_s = maxf(maximum_wheel_spin_rad_s, wheel.angular_velocity.length())

func articulated_body_count() -> int:
	return 1 + articulated_bodies.size()

func articulated_joint_count() -> int:
	return articulated_joints.size()

func target_model() -> StructuralModel:
	if bicycle_visual != null:
		return bicycle_visual.model
	if pedestrian_visual != null:
		return pedestrian_visual.model
	return null

func global_linear_velocity_ms() -> Vector3:
	return center_of_mass_velocity_ms()

func target_speed_kmh() -> float:
	return PhysicsMetrics.ms_to_kmh(center_of_mass_velocity_ms().length())

func replay_visual_state() -> Dictionary:
	var part_states: Array[Dictionary] = []
	for body in articulated_bodies:
		if body == null or not is_instance_valid(body):
			continue
		part_states.append({
			"name": String(body.name),
			"rigid_transform": body.global_transform,
			"linear_velocity_ms": body.linear_velocity,
			"angular_velocity_rad_s": body.angular_velocity,
		})
	return {
		"rigid_transform": global_transform,
		"linear_velocity_ms": linear_velocity,
		"angular_velocity_rad_s": angular_velocity,
		"impact_received": impact_received,
		"part_states": part_states,
	}

func apply_replay_visual_state(state: Dictionary) -> void:
	freeze = true
	var transform_value: Variant = state.get("rigid_transform", global_transform)
	if transform_value is Transform3D:
		global_transform = transform_value
	linear_velocity = state.get("linear_velocity_ms", Vector3.ZERO)
	angular_velocity = state.get("angular_velocity_rad_s", Vector3.ZERO)
	impact_received = bool(state.get("impact_received", impact_received))
	var by_name: Dictionary = {}
	for body in articulated_bodies:
		if body != null and is_instance_valid(body):
			body.freeze = true
			by_name[String(body.name)] = body
	var part_states: Variant = state.get("part_states", [])
	if part_states is Array:
		for raw_state in part_states:
			if not raw_state is Dictionary:
				continue
			var part_state: Dictionary = raw_state
			var body: RigidBody3D = by_name.get(String(part_state.get("name", "")))
			if body == null:
				continue
			var body_transform: Variant = part_state.get("rigid_transform", body.global_transform)
			if body_transform is Transform3D:
				body.global_transform = body_transform
			body.linear_velocity = part_state.get("linear_velocity_ms", Vector3.ZERO)
			body.angular_velocity = part_state.get("angular_velocity_rad_s", Vector3.ZERO)
