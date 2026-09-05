# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RoadUserArticulatedProxy3D
extends RoadUserRigidProxy3D

# M15 production refinement on top of the M14-compatible proxy API.
# Pedestrian segments are connected with bounded Generic6DOFJoint3D
# constraints. The limits are deliberately generic stability envelopes, not
# biomechanical range-of-motion data and not suitable for injury prediction.
# Generic6DOF is used instead of ConeTwist because the latter injected large
# amounts of energy in the Godot 4.4.1 runtime under high-speed impact loads.

var _m15_joint_pairs: Dictionary = {}
var _m15_joint_local_bases: Dictionary = {}
var _m15_initial_joint_relative_bases: Dictionary = {}

func _build_pedestrian_rig() -> void:
	var scale := RoadUserCatalog.pedestrian_height_m(preset_id) / 1.75
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

	# Joint-local X is the primary twist/hinge axis. Y/Z form the bounded swing
	# envelope. These conservative angles are generic numerical limits only.
	var vertical_axis := Basis(Vector3.FORWARD, deg_to_rad(90.0))
	var lateral_axis := Basis(Vector3.UP, deg_to_rad(-90.0))
	_add_bounded_joint("SpineJoint", self, _pedestrian_torso, Vector3(0.0, 1.00 * scale, 0.0), vertical_axis, 20.0, 28.0)
	_add_bounded_joint("NeckJoint", _pedestrian_torso, head, Vector3(0.0, 1.50 * scale, 0.0), vertical_axis, 28.0, 38.0)
	_add_bounded_joint("LeftShoulderJoint", _pedestrian_torso, left_upper_arm, Vector3(0.0, 1.35 * scale, -0.24 * scale), vertical_axis, 42.0, 72.0)
	_add_bounded_joint("RightShoulderJoint", _pedestrian_torso, right_upper_arm, Vector3(0.0, 1.35 * scale, 0.24 * scale), vertical_axis, 42.0, 72.0)
	_add_bounded_joint("LeftElbowJoint", left_upper_arm, left_lower_arm, Vector3(0.0, 1.03 * scale, -0.28 * scale), lateral_axis, 45.0, 12.0)
	_add_bounded_joint("RightElbowJoint", right_upper_arm, right_lower_arm, Vector3(0.0, 1.03 * scale, 0.28 * scale), lateral_axis, 45.0, 12.0)
	_add_bounded_joint("LeftHipJoint", self, left_upper_leg, Vector3(0.0, 0.80 * scale, -0.09 * scale), vertical_axis, 36.0, 52.0)
	_add_bounded_joint("RightHipJoint", self, right_upper_leg, Vector3(0.0, 0.80 * scale, 0.09 * scale), vertical_axis, 36.0, 52.0)
	_add_bounded_joint("LeftKneeJoint", left_upper_leg, left_lower_leg, Vector3(0.0, 0.44 * scale, -0.09 * scale), lateral_axis, 45.0, 10.0)
	_add_bounded_joint("RightKneeJoint", right_upper_leg, right_lower_leg, Vector3(0.0, 0.44 * scale, 0.09 * scale), lateral_axis, 45.0, 10.0)

func _add_bounded_joint(
	node_name: String,
	body_a: PhysicsBody3D,
	body_b: PhysicsBody3D,
	local_anchor: Vector3,
	local_basis: Basis,
	twist_deg: float,
	swing_deg: float
) -> void:
	var joint := Generic6DOFJoint3D.new()
	joint.name = node_name
	articulated_joints.append(joint)
	_joint_local_anchors[joint.name] = local_anchor
	_m15_joint_pairs[joint.name] = [body_a, body_b]
	_m15_joint_local_bases[joint.name] = local_basis
	get_parent().add_child(joint)
	_configure_6dof_axis(joint, 0, twist_deg)
	_configure_6dof_axis(joint, 1, swing_deg)
	_configure_6dof_axis(joint, 2, swing_deg)
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)

func _configure_6dof_axis(joint: Generic6DOFJoint3D, axis: int, angular_limit_deg: float) -> void:
	var angular_limit := deg_to_rad(maxf(angular_limit_deg, 1.0))
	match axis:
		0:
			joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -angular_limit)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, angular_limit)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LIMIT_SOFTNESS, 0.55)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, 0.78)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_RESTITUTION, 0.0)
			joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_ERP, 0.22)
		1:
			joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -angular_limit)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, angular_limit)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LIMIT_SOFTNESS, 0.55)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, 0.78)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_RESTITUTION, 0.0)
			joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_ERP, 0.22)
		2:
			joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -angular_limit)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, angular_limit)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LIMIT_SOFTNESS, 0.55)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, 0.78)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_RESTITUTION, 0.0)
			joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_ERP, 0.22)

func set_preview_pose(position_m: Vector3, yaw_deg: float) -> void:
	super.set_preview_pose(position_m, yaw_deg)
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	for joint in articulated_joints:
		if joint == null or not is_instance_valid(joint):
			continue
		if not _m15_joint_local_bases.has(joint.name):
			continue
		var anchor: Vector3 = _joint_local_anchors.get(joint.name, Vector3.ZERO)
		var local_basis: Basis = _m15_joint_local_bases.get(joint.name, Basis.IDENTITY)
		joint.global_transform = Transform3D(yaw_basis * local_basis, position_m + yaw_basis * anchor)
	_rebind_bounded_joints()
	_capture_joint_reference_pose()

func _rebind_bounded_joints() -> void:
	for joint in articulated_joints:
		if joint == null or not is_instance_valid(joint) or not _m15_joint_pairs.has(joint.name):
			continue
		var pair: Array = _m15_joint_pairs[joint.name]
		if pair.size() != 2:
			continue
		var body_a := pair[0] as PhysicsBody3D
		var body_b := pair[1] as PhysicsBody3D
		if body_a == null or body_b == null:
			continue
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.node_a = joint.get_path_to(body_a)
		joint.node_b = joint.get_path_to(body_b)

func _capture_joint_reference_pose() -> void:
	_m15_initial_joint_relative_bases.clear()
	for joint in articulated_joints:
		if joint == null or not is_instance_valid(joint) or not _m15_joint_pairs.has(joint.name):
			continue
		var pair: Array = _m15_joint_pairs[joint.name]
		if pair.size() != 2:
			continue
		var body_a := pair[0] as PhysicsBody3D
		var body_b := pair[1] as PhysicsBody3D
		if body_a == null or body_b == null:
			continue
		_m15_initial_joint_relative_bases[joint.name] = body_a.global_transform.basis.inverse() * body_b.global_transform.basis

func _update_articulation_metrics() -> void:
	if target_type == ScenarioConfig.TARGET_BICYCLE:
		for wheel in _bicycle_wheels:
			if wheel != null and is_instance_valid(wheel):
				maximum_wheel_spin_rad_s = maxf(maximum_wheel_spin_rad_s, wheel.angular_velocity.length())
		return
	for joint in articulated_joints:
		if joint == null or not is_instance_valid(joint) or not _m15_joint_pairs.has(joint.name):
			continue
		var pair: Array = _m15_joint_pairs[joint.name]
		if pair.size() != 2:
			continue
		var body_a := pair[0] as PhysicsBody3D
		var body_b := pair[1] as PhysicsBody3D
		if body_a == null or body_b == null:
			continue
		var initial_basis: Basis = _m15_initial_joint_relative_bases.get(joint.name, Basis.IDENTITY)
		var current_basis := body_a.global_transform.basis.inverse() * body_b.global_transform.basis
		var angle_deg := rad_to_deg(initial_basis.get_rotation_quaternion().angle_to(current_basis.get_rotation_quaternion()))
		maximum_articulation_angle_deg = maxf(maximum_articulation_angle_deg, angle_deg)
