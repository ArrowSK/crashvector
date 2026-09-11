# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M22RoadUserProxy3D
extends RoadUserArticulatedStableProxy3D

# M22 adds a generic cyclist target without changing the finalized riderless
# bicycle or pedestrian topologies. A cyclist combines the existing articulated
# bicycle frame/wheels with a generic adult articulated rider. The rider is held
# to the bicycle by temporary seat/hand/foot coupling joints before contact and
# released when the existing production front-probe coupling reports impact.
# This is a contact/trajectory model only: no biomechanics or injury inference.

const CYCLIST_MAX_TRANSFER_SPEED_MS := 24.0

var cyclist_released: bool = false
var cyclist_rider_bodies: Array[RigidBody3D] = []
var cyclist_coupling_joints: Array[Joint3D] = []
var _m22_coupling_pairs: Dictionary = {}
var _m22_pelvis: RigidBody3D

func _ready() -> void:
	if target_type != ScenarioConfig.TARGET_CYCLIST:
		super._ready()
		return

	# Reuse the proven M15 bicycle implementation with its actual bicycle mass,
	# then restore the public combined target mass before adding the rider. This
	# keeps the physical body-mass sum equal to the scenario's cyclist+bicycle
	# mass instead of accidentally treating the combined mass as bicycle mass.
	var combined_mass := target_mass_kg
	var bicycle_mass := RoadUserCatalog.cyclist_bicycle_mass_kg(preset_id)
	target_type = ScenarioConfig.TARGET_BICYCLE
	target_mass_kg = bicycle_mass
	super._ready()
	target_type = ScenarioConfig.TARGET_CYCLIST
	target_mass_kg = combined_mass

	_build_cyclist_rider()
	_apply_self_collision_exceptions()
	set_preview_pose(origin_offset_m, heading_deg)

func _build_cyclist_rider() -> void:
	var rider_mass := RoadUserCatalog.cyclist_rider_mass_kg(target_mass_kg, preset_id)
	var vertical_axis := Basis(Vector3.FORWARD, deg_to_rad(90.0))
	var lateral_axis := Basis(Vector3.UP, deg_to_rad(-90.0))

	_m22_pelvis = _new_cyclist_part("CyclistPelvis", rider_mass * 0.14, Vector3(-0.30, 1.03, 0.0), 0.58)
	_add_box_collision(_m22_pelvis, "PelvisCollision", Vector3(0.24, 0.22, 0.32), Vector3.ZERO)
	_add_box_visual(_m22_pelvis, "Pelvis", Vector3(0.24, 0.22, 0.32), Vector3.ZERO, Color(0.17, 0.34, 0.58))

	_pedestrian_torso = _new_cyclist_part("PedestrianTorso", rider_mass * 0.36, Vector3(-0.08, 1.34, 0.0), 0.58)
	_add_box_collision(_pedestrian_torso, "TorsoCollision", Vector3(0.30, 0.48, 0.40), Vector3.ZERO)
	_add_box_visual(_pedestrian_torso, "Torso", Vector3(0.30, 0.48, 0.40), Vector3.ZERO, Color(0.17, 0.34, 0.58))

	var head := _new_cyclist_part("PedestrianHead", rider_mass * 0.08, Vector3(0.10, 1.68, 0.0), 0.48)
	_add_sphere_collision(head, "HeadCollision", 0.13, Vector3.ZERO)
	_add_sphere_visual(head, "Head", 0.13, Vector3.ZERO, Color(0.78, 0.62, 0.50))

	var left_upper_arm := _new_cyclist_part("LeftUpperArm", rider_mass * 0.03, Vector3(0.11, 1.41, -0.22), 0.52)
	var right_upper_arm := _new_cyclist_part("RightUpperArm", rider_mass * 0.03, Vector3(0.11, 1.41, 0.22), 0.52)
	var left_lower_arm := _new_cyclist_part("LeftLowerArm", rider_mass * 0.02, Vector3(0.36, 1.25, -0.23), 0.52)
	var right_lower_arm := _new_cyclist_part("RightLowerArm", rider_mass * 0.02, Vector3(0.36, 1.25, 0.23), 0.52)
	for arm in [left_upper_arm, right_upper_arm]:
		_add_capsule_collision(arm, "UpperArmCollision", 0.065, 0.34, Vector3.ZERO)
		_add_capsule_visual(arm, "UpperArm", 0.065, 0.34, Color(0.17, 0.34, 0.58))
	for arm in [left_lower_arm, right_lower_arm]:
		_add_capsule_collision(arm, "LowerArmCollision", 0.055, 0.30, Vector3.ZERO)
		_add_capsule_visual(arm, "LowerArm", 0.055, 0.30, Color(0.78, 0.62, 0.50))

	var left_upper_leg := _new_cyclist_part("LeftUpperLeg", rider_mass * 0.10, Vector3(-0.10, 0.84, -0.09), 0.64)
	var right_upper_leg := _new_cyclist_part("RightUpperLeg", rider_mass * 0.10, Vector3(-0.10, 0.84, 0.09), 0.64)
	var left_lower_leg := _new_cyclist_part("LeftLowerLeg", rider_mass * 0.06, Vector3(0.13, 0.57, -0.10), 0.68)
	var right_lower_leg := _new_cyclist_part("RightLowerLeg", rider_mass * 0.06, Vector3(0.13, 0.57, 0.10), 0.68)
	for leg in [left_upper_leg, right_upper_leg]:
		_add_capsule_collision(leg, "UpperLegCollision", 0.085, 0.40, Vector3.ZERO)
		_add_capsule_visual(leg, "UpperLeg", 0.085, 0.40, Color(0.17, 0.34, 0.58))
	for leg in [left_lower_leg, right_lower_leg]:
		_add_capsule_collision(leg, "LowerLegCollision", 0.072, 0.36, Vector3.ZERO)
		_add_capsule_visual(leg, "LowerLeg", 0.072, 0.36, Color(0.08, 0.10, 0.14))

	# Keep the rider body topology deliberately identical to the finalized M15
	# pedestrian chain so replay and presentation can reuse the same part names.
	_add_bounded_joint("SpineJoint", _m22_pelvis, _pedestrian_torso, Vector3(-0.22, 1.17, 0.0), vertical_axis, 20.0, 28.0)
	_add_bounded_joint("NeckJoint", _pedestrian_torso, head, Vector3(0.03, 1.55, 0.0), vertical_axis, 28.0, 38.0)
	_add_bounded_joint("LeftShoulderJoint", _pedestrian_torso, left_upper_arm, Vector3(0.00, 1.47, -0.22), vertical_axis, 42.0, 72.0)
	_add_bounded_joint("RightShoulderJoint", _pedestrian_torso, right_upper_arm, Vector3(0.00, 1.47, 0.22), vertical_axis, 42.0, 72.0)
	_add_bounded_joint("LeftElbowJoint", left_upper_arm, left_lower_arm, Vector3(0.27, 1.32, -0.23), lateral_axis, 45.0, 12.0)
	_add_bounded_joint("RightElbowJoint", right_upper_arm, right_lower_arm, Vector3(0.27, 1.32, 0.23), lateral_axis, 45.0, 12.0)
	_add_bounded_joint("LeftHipJoint", _m22_pelvis, left_upper_leg, Vector3(-0.25, 0.99, -0.09), vertical_axis, 36.0, 52.0)
	_add_bounded_joint("RightHipJoint", _m22_pelvis, right_upper_leg, Vector3(-0.25, 0.99, 0.09), vertical_axis, 36.0, 52.0)
	_add_bounded_joint("LeftKneeJoint", left_upper_leg, left_lower_leg, Vector3(0.01, 0.70, -0.10), lateral_axis, 45.0, 10.0)
	_add_bounded_joint("RightKneeJoint", right_upper_leg, right_lower_leg, Vector3(0.01, 0.70, 0.10), lateral_axis, 45.0, 10.0)

	# Temporary pre-impact coupling. Pin joints keep the seated rider attached to
	# the frame while still allowing small posture motion. They are detached on
	# the first production probe contact; self-collision remains disabled to avoid
	# adding an unstable rider/bicycle collision solver after release.
	_add_cyclist_coupling("CyclistSeatCoupling", _m22_pelvis, Vector3(-0.30, 1.03, 0.0))
	_add_cyclist_coupling("CyclistLeftHandCoupling", left_lower_arm, Vector3(0.52, 1.20, -0.22))
	_add_cyclist_coupling("CyclistRightHandCoupling", right_lower_arm, Vector3(0.52, 1.20, 0.22))
	_add_cyclist_coupling("CyclistLeftFootCoupling", left_lower_leg, Vector3(0.08, 0.46, -0.08))
	_add_cyclist_coupling("CyclistRightFootCoupling", right_lower_leg, Vector3(0.08, 0.46, 0.08))

func _new_cyclist_part(node_name: String, body_mass_kg: float, local_offset: Vector3, friction: float) -> RigidBody3D:
	var body := _new_part(node_name, body_mass_kg, local_offset, friction)
	cyclist_rider_bodies.append(body)
	return body

func _add_cyclist_coupling(node_name: String, body: PhysicsBody3D, local_anchor: Vector3) -> void:
	_add_pin_joint(node_name, self, body, local_anchor)
	if articulated_joints.is_empty():
		return
	var joint := articulated_joints[articulated_joints.size() - 1]
	cyclist_coupling_joints.append(joint)
	_m22_coupling_pairs[joint.name] = [self, body]

func set_preview_pose(position_m: Vector3, yaw_deg: float) -> void:
	if target_type == ScenarioConfig.TARGET_CYCLIST:
		cyclist_released = false
	super.set_preview_pose(position_m, yaw_deg)
	if target_type == ScenarioConfig.TARGET_CYCLIST:
		_rebind_cyclist_couplings()

func apply_probe_contact(source: VehicleRigidChassis, collider: Object = null) -> void:
	if target_type != ScenarioConfig.TARGET_CYCLIST:
		super.apply_probe_contact(source, collider)
		return
	if impact_received or source == null or not simulation_active:
		return
	var forward := source.global_transform.basis.x.normalized()
	var target_velocity := center_of_mass_velocity_ms()
	var closing_speed := maxf((source.linear_velocity - target_velocity).dot(forward), 0.0)
	if closing_speed < 0.25:
		return
	var effective_mass := source.mass * target_mass_kg / maxf(source.mass + target_mass_kg, 1.0)
	var transfer_impulse_ns := minf(
		effective_mass * closing_speed * 0.82,
		target_mass_kg * CYCLIST_MAX_TRANSFER_SPEED_MS
	)
	_release_cyclist_couplings()
	apply_central_impulse(forward * transfer_impulse_ns * 0.44)
	if _m22_pelvis != null:
		_m22_pelvis.apply_central_impulse(forward * transfer_impulse_ns * 0.30)
	if _pedestrian_torso != null:
		_pedestrian_torso.apply_central_impulse(forward * transfer_impulse_ns * 0.22)
	var contacted := _owned_body_from_collider(collider)
	if contacted != null and contacted != self and contacted != _m22_pelvis and contacted != _pedestrian_torso:
		contacted.apply_central_impulse(forward * transfer_impulse_ns * 0.04)
	impact_received = true

func _on_articulated_body_entered(body: Node) -> void:
	super._on_articulated_body_entered(body)
	if target_type == ScenarioConfig.TARGET_CYCLIST and body is VehicleRigidChassis:
		_release_cyclist_couplings()

func _release_cyclist_couplings() -> void:
	if cyclist_released:
		return
	cyclist_released = true
	for joint in cyclist_coupling_joints:
		if joint == null or not is_instance_valid(joint):
			continue
		joint.node_a = NodePath()
		joint.node_b = NodePath()

func _rebind_cyclist_couplings() -> void:
	if cyclist_released:
		return
	for joint in cyclist_coupling_joints:
		if joint == null or not is_instance_valid(joint) or not _m22_coupling_pairs.has(joint.name):
			continue
		var pair: Array = _m22_coupling_pairs[joint.name]
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

func _update_articulation_metrics() -> void:
	super._update_articulation_metrics()
	if target_type != ScenarioConfig.TARGET_CYCLIST:
		return
	for wheel in _bicycle_wheels:
		if wheel != null and is_instance_valid(wheel):
			maximum_wheel_spin_rad_s = maxf(maximum_wheel_spin_rad_s, wheel.angular_velocity.length())

func replay_visual_state() -> Dictionary:
	var state := super.replay_visual_state()
	if target_type == ScenarioConfig.TARGET_CYCLIST:
		state["cyclist_released"] = cyclist_released
	return state

func apply_replay_visual_state(state: Dictionary) -> void:
	super.apply_replay_visual_state(state)
	if target_type != ScenarioConfig.TARGET_CYCLIST:
		return
	cyclist_released = bool(state.get("cyclist_released", cyclist_released))
	if cyclist_released:
		for joint in cyclist_coupling_joints:
			if joint != null and is_instance_valid(joint):
				joint.node_a = NodePath()
				joint.node_b = NodePath()
	else:
		_rebind_cyclist_couplings()

func cyclist_rider_body_count() -> int:
	return cyclist_rider_bodies.size()

func cyclist_coupling_joint_count() -> int:
	return cyclist_coupling_joints.size()
