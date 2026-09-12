# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M20Motorcycle
extends M17Motorcycle

# M20 gives the motorcycle a bounded local frame/fork response and a separate
# physics-backed rider. Godot RigidBody3D remains authoritative for trajectory,
# pitch, roll and all rider momentum transfer; this is not an injury model or
# manufacturer crashworthiness model.

const FRAME_BASE_SIZE := Vector3(1.88, 0.74, 0.46)
const FRAME_BASE_POS := Vector3(0.98, 0.72, 0.0)
const REAR_WHEEL_BASE_POS := Vector3(0.0, 0.34, 0.0)
const FRONT_WHEEL_BASE_POS := Vector3(1.95, 0.34, 0.0)

var hybrid_reference_local_positions: Array[Vector3] = []
var hybrid_rear_energy_j: float = 0.0
var hybrid_front_energy_j: float = 0.0
var hybrid_side_negative_z_energy_j: float = 0.0
var hybrid_side_positive_z_energy_j: float = 0.0
var hybrid_rear_crush_m: float = 0.0
var hybrid_front_crush_m: float = 0.0
var hybrid_side_negative_z_crush_m: float = 0.0
var hybrid_side_positive_z_crush_m: float = 0.0
var frame_collision: CollisionShape3D
var rear_wheel_collision: CollisionShape3D
var front_wheel_collision: CollisionShape3D
var rider_rig: MotorcycleRiderRig3D

func _ready() -> void:
	super._ready()
	_capture_m20_reference_geometry()
	frame_collision = rigid_chassis.get_node_or_null("MotorcycleFrameCollision") as CollisionShape3D
	rear_wheel_collision = rigid_chassis.get_node_or_null("MotorcycleRearWheelCollision") as CollisionShape3D
	front_wheel_collision = rigid_chassis.get_node_or_null("MotorcycleFrontWheelCollision") as CollisionShape3D
	# At ordinary speeds a full chassis contact is required before this light
	# target is driven away. The passenger car therefore defers its probe-only
	# resistance for this pair and Godot reports the impact manifold.
	rigid_chassis.defer_front_probe_resistance_to_rigid_contact = true
	rider_rig = MotorcycleRiderRig3D.new()
	rider_rig.name = "MotorcycleRiderRig"
	add_child(rider_rig)
	rider_rig.configure(rigid_chassis)

func begin_simulation() -> void:
	hybrid_rear_energy_j = 0.0
	hybrid_front_energy_j = 0.0
	hybrid_side_negative_z_energy_j = 0.0
	hybrid_side_positive_z_energy_j = 0.0
	hybrid_rear_crush_m = 0.0
	hybrid_front_crush_m = 0.0
	hybrid_side_negative_z_crush_m = 0.0
	hybrid_side_positive_z_crush_m = 0.0
	super.begin_simulation()
	_restore_m20_reference_geometry()
	_reset_m20_collision_shapes()
	if rider_rig != null:
		rider_rig.arm_for_simulation()
	update_from_model()

func step_external(delta: float) -> void:
	if not hybrid_physics_enabled:
		super.step_external(delta)
		return
	if delta <= 0.0:
		update_from_model()
		return
	_sync_m17_model_to_chassis()
	_m20_consume_contacts()
	_m20_enforce_deformation(delta)
	if rider_rig != null:
		rider_rig.sync_from_motorcycle()
	update_from_model()

func end_simulation() -> void:
	if rider_rig != null:
		rider_rig.end_simulation()
	super.end_simulation()

func set_preview_pose(position_m: Vector3, yaw_deg: float) -> void:
	super.set_preview_pose(position_m, yaw_deg)
	if rider_rig != null:
		rider_rig.sync_from_motorcycle()

func rider_released_after_contact() -> bool:
	return rider_rig != null and rider_rig.rider_released

func rear_impact_deformation_m() -> float:
	return hybrid_rear_crush_m

func front_crush_deformation_m() -> float:
	return hybrid_front_crush_m

func side_impact_deformation_m() -> float:
	return maxf(hybrid_side_negative_z_crush_m, hybrid_side_positive_z_crush_m)

func side_impact_energy_j() -> float:
	return maxf(hybrid_side_negative_z_energy_j, hybrid_side_positive_z_energy_j)

func _capture_m20_reference_geometry() -> void:
	hybrid_reference_local_positions.clear()
	if rigid_chassis == null or model == null:
		return
	hybrid_reference_local_positions.resize(model.nodes.size())
	for index in range(model.nodes.size()):
		hybrid_reference_local_positions[index] = rigid_chassis.to_local(model.nodes[index].position_m)

func _restore_m20_reference_geometry() -> void:
	if rigid_chassis == null or model == null or hybrid_reference_local_positions.size() != model.nodes.size():
		return
	for index in range(model.nodes.size()):
		model.nodes[index].position_m = rigid_chassis.to_global(hybrid_reference_local_positions[index])
		model.nodes[index].velocity_ms = Vector3.ZERO

func _m20_consume_contacts() -> void:
	if rigid_chassis == null:
		return
	var forward := rigid_chassis.global_transform.basis.x.normalized()
	var lateral := rigid_chassis.global_transform.basis.z.normalized()
	for sample in rigid_chassis.drain_contact_samples():
		var collider_name: StringName = sample.get("collider_name", StringName(""))
		if collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround":
			continue
		if rider_rig != null:
			rider_rig.release_from_real_contact()
		var collider: Object = sample.get("collider", null)
		var contact_local: Vector3 = sample.get("position_local", Vector3.ZERO)
		var collider_local := contact_local
		var has_collider_center := false
		var other_velocity := Vector3.ZERO
		var other_mass := rigid_chassis.mass
		if collider is Node3D:
			collider_local = rigid_chassis.to_local((collider as Node3D).global_position)
			has_collider_center = true
		if collider is RigidBody3D:
			var other := collider as RigidBody3D
			other_velocity = other.linear_velocity
			other_mass = maxf(other.mass, 1.0)
		var relative_velocity := other_velocity - rigid_chassis.linear_velocity
		var reduced_mass := rigid_chassis.mass * other_mass / maxf(rigid_chassis.mass + other_mass, 1.0)
		var impulse: Vector3 = sample.get("impulse", Vector3.ZERO)
		var longitudinal_speed := absf(relative_velocity.dot(forward))
		var lateral_speed := absf(relative_velocity.dot(lateral))
		var longitudinal_impulse := absf(impulse.dot(forward))
		var lateral_impulse := absf(impulse.dot(lateral))
		var longitudinal_energy := maxf(
			0.5 * reduced_mass * longitudinal_speed * longitudinal_speed,
			longitudinal_impulse * longitudinal_impulse / maxf(2.0 * reduced_mass, 1.0)
		)
		var lateral_energy := maxf(
			0.5 * reduced_mass * lateral_speed * lateral_speed,
			lateral_impulse * lateral_impulse / maxf(2.0 * reduced_mass, 1.0)
		)
		var contact_side_x := collider_local.x if has_collider_center else contact_local.x
		if longitudinal_energy > 1.0:
			if contact_side_x < 0.98:
				hybrid_rear_energy_j = maxf(hybrid_rear_energy_j, longitudinal_energy)
			else:
				hybrid_front_energy_j = maxf(hybrid_front_energy_j, longitudinal_energy)
		var side_region := absf(contact_local.z) >= 0.10
		if side_region and has_collider_center:
			side_region = absf(collider_local.z) >= 0.16
			side_region = side_region and absf(collider_local.z) > absf(collider_local.x - 0.98) * 0.18
		if side_region and lateral_energy > 1.0:
			if contact_local.z < 0.0:
				hybrid_side_negative_z_energy_j = maxf(hybrid_side_negative_z_energy_j, lateral_energy)
			else:
				hybrid_side_positive_z_energy_j = maxf(hybrid_side_positive_z_energy_j, lateral_energy)

	hybrid_rear_crush_m = maxf(hybrid_rear_crush_m, minf(_energy_to_crush(hybrid_rear_energy_j, 18000.0, 85000.0), 0.24))
	hybrid_front_crush_m = maxf(hybrid_front_crush_m, minf(_energy_to_crush(hybrid_front_energy_j, 13000.0, 65000.0), 0.34))
	hybrid_side_negative_z_crush_m = maxf(hybrid_side_negative_z_crush_m, minf(_energy_to_crush(hybrid_side_negative_z_energy_j, 16000.0, 78000.0), 0.20))
	hybrid_side_positive_z_crush_m = maxf(hybrid_side_positive_z_crush_m, minf(_energy_to_crush(hybrid_side_positive_z_energy_j, 16000.0, 78000.0), 0.20))

func _energy_to_crush(energy_j: float, force0_n: float, stiffness_n_m: float) -> float:
	if energy_j <= 0.0:
		return 0.0
	var discriminant := force0_n * force0_n + 2.0 * stiffness_n_m * energy_j
	return maxf((-force0_n + sqrt(maxf(discriminant, 0.0))) / maxf(stiffness_n_m, 1.0), 0.0)

func _m20_enforce_deformation(delta: float) -> void:
	if rigid_chassis == null or model == null or hybrid_reference_local_positions.size() != model.nodes.size():
		return
	if hybrid_rear_crush_m <= 0.0001 and hybrid_front_crush_m <= 0.0001 and side_impact_deformation_m() <= 0.0001:
		return
	var alpha := clampf(1.0 - exp(-22.0 * maxf(delta, 0.0)), 0.0, 1.0)
	_deform_station(MotorcycleBuilder.REAR_STATION, hybrid_rear_crush_m, 1.0, true, alpha)
	_deform_station(1, hybrid_rear_crush_m, 0.35, true, alpha)
	_deform_station(MotorcycleBuilder.FRONT_STATION, hybrid_front_crush_m, 1.0, false, alpha)
	_deform_station(2, hybrid_front_crush_m, 0.45, false, alpha)
	_deform_sides(alpha)
	_update_m20_collision_shapes()

func _deform_station(station: int, crush_m: float, weight: float, rear: bool, alpha: float) -> void:
	if crush_m <= 0.0:
		return
	for corner in range(4):
		var index := MotorcycleBuilder.node_index(station, corner)
		if index < 0 or index >= model.nodes.size():
			continue
		var reference_local := hybrid_reference_local_positions[index]
		var current_local := rigid_chassis.to_local(model.nodes[index].position_m)
		var target_local := current_local
		var desired_x := reference_local.x + crush_m * weight * (1.0 if rear else -1.0)
		if rear:
			target_local.x = maxf(current_local.x, desired_x)
		else:
			target_local.x = minf(current_local.x, desired_x)
		if corner >= 2:
			target_local.y = minf(current_local.y, reference_local.y - crush_m * weight * 0.22)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(rigid_chassis.to_global(target_local), alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO

func _deform_sides(alpha: float) -> void:
	for index in range(model.nodes.size()):
		var reference_local := hybrid_reference_local_positions[index]
		var side_sign := 0.0
		var crush := 0.0
		if reference_local.z < -0.02 and hybrid_side_negative_z_crush_m > 0.0001:
			side_sign = -1.0
			crush = hybrid_side_negative_z_crush_m
		elif reference_local.z > 0.02 and hybrid_side_positive_z_crush_m > 0.0001:
			side_sign = 1.0
			crush = hybrid_side_positive_z_crush_m
		if side_sign == 0.0:
			continue
		var current_local := rigid_chassis.to_local(model.nodes[index].position_m)
		var target_local := current_local
		var longitudinal_weight := 0.55 + 0.45 * (1.0 - clampf(absf(reference_local.x - 0.98) / 1.15, 0.0, 1.0))
		var desired_z := reference_local.z - side_sign * crush * longitudinal_weight
		if side_sign > 0.0:
			target_local.z = minf(current_local.z, desired_z)
		else:
			target_local.z = maxf(current_local.z, desired_z)
		if (index % 4) >= 2:
			target_local.y = minf(current_local.y, reference_local.y - crush * longitudinal_weight * 0.18)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(rigid_chassis.to_global(target_local), alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO

func _reset_m20_collision_shapes() -> void:
	_set_box(frame_collision, FRAME_BASE_SIZE, FRAME_BASE_POS)
	if rear_wheel_collision != null:
		rear_wheel_collision.position = REAR_WHEEL_BASE_POS
	if front_wheel_collision != null:
		front_wheel_collision.position = FRONT_WHEEL_BASE_POS

func _update_m20_collision_shapes() -> void:
	if frame_collision != null:
		var rear_face := FRAME_BASE_POS.x - FRAME_BASE_SIZE.x * 0.5 + hybrid_rear_crush_m * 0.55
		var front_face := FRAME_BASE_POS.x + FRAME_BASE_SIZE.x * 0.5 - hybrid_front_crush_m * 0.62
		var size := FRAME_BASE_SIZE
		size.x = maxf(front_face - rear_face, 1.20)
		var negative_face := -FRAME_BASE_SIZE.z * 0.5 + hybrid_side_negative_z_crush_m * 0.52
		var positive_face := FRAME_BASE_SIZE.z * 0.5 - hybrid_side_positive_z_crush_m * 0.52
		size.z = maxf(positive_face - negative_face, 0.24)
		var pos := FRAME_BASE_POS
		pos.x = (front_face + rear_face) * 0.5
		pos.z = (positive_face + negative_face) * 0.5
		_set_box(frame_collision, size, pos)
	if rear_wheel_collision != null:
		var rear_pos := REAR_WHEEL_BASE_POS
		rear_pos.x += hybrid_rear_crush_m * 0.70
		rear_wheel_collision.position = rear_pos
	if front_wheel_collision != null:
		var front_pos := FRONT_WHEEL_BASE_POS
		front_pos.x -= hybrid_front_crush_m * 0.72
		front_wheel_collision.position = front_pos

func _set_box(collision: CollisionShape3D, size: Vector3, position_value: Vector3) -> void:
	if collision == null:
		return
	var box := collision.shape as BoxShape3D
	if box != null:
		box.size = size
	collision.position = position_value
