# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M20RigidLorry
extends M17RigidLorry

# Generic M20 local-deformation layer for the rigid lorry / box-truck target.
# Godot remains authoritative for whole-vehicle motion/contact. The local graph
# is moved relative to that chassis only after real contact demand is observed.
# This is not manufacturer body-in-white or regulatory crash correlation.

const CARGO_BASE_SIZE := Vector3(4.70, 2.72, 2.26)
const CARGO_BASE_POS := Vector3(2.75, 2.00, 0.0)
const CAB_BASE_SIZE := Vector3(2.55, 2.45, 2.10)
const CAB_BASE_POS := Vector3(6.10, 1.70, 0.0)
const FRAME_BASE_SIZE := Vector3(7.35, 0.28, 1.74)
const FRAME_BASE_POS := Vector3(3.67, 0.58, 0.0)
const REAR_GUARD_BASE_SIZE := Vector3(0.22, 0.60, 2.04)
const REAR_GUARD_BASE_POS := Vector3(0.02, 0.67, 0.0)

var hybrid_reference_local_positions: Array[Vector3] = []
var hybrid_rear_collision_energy_j: float = 0.0
var hybrid_front_collision_energy_j: float = 0.0
var hybrid_side_negative_z_energy_j: float = 0.0
var hybrid_side_positive_z_energy_j: float = 0.0
var hybrid_rear_crush_m: float = 0.0
var hybrid_front_crush_m: float = 0.0
var hybrid_side_negative_z_crush_m: float = 0.0
var hybrid_side_positive_z_crush_m: float = 0.0
var hybrid_side_negative_z_contact_x_m: float = CARGO_BASE_POS.x
var hybrid_side_positive_z_contact_x_m: float = CARGO_BASE_POS.x
var cargo_collision: CollisionShape3D
var cab_collision: CollisionShape3D
var frame_collision: CollisionShape3D
var rear_guard_collision: CollisionShape3D

func _ready() -> void:
	super._ready()
	_capture_m20_reference_geometry()
	cargo_collision = rigid_chassis.get_node_or_null("LorryCargoCollision") as CollisionShape3D
	cab_collision = rigid_chassis.get_node_or_null("LorryCabCollision") as CollisionShape3D
	frame_collision = rigid_chassis.get_node_or_null("LorryFrameCollision") as CollisionShape3D
	rear_guard_collision = rigid_chassis.get_node_or_null("LorryRearGuardCollision") as CollisionShape3D

func begin_simulation() -> void:
	hybrid_rear_collision_energy_j = 0.0
	hybrid_front_collision_energy_j = 0.0
	hybrid_side_negative_z_energy_j = 0.0
	hybrid_side_positive_z_energy_j = 0.0
	hybrid_rear_crush_m = 0.0
	hybrid_front_crush_m = 0.0
	hybrid_side_negative_z_crush_m = 0.0
	hybrid_side_positive_z_crush_m = 0.0
	hybrid_side_negative_z_contact_x_m = CARGO_BASE_POS.x
	hybrid_side_positive_z_contact_x_m = CARGO_BASE_POS.x
	super.begin_simulation()
	_restore_m20_reference_geometry()
	_reset_m20_collision_shapes()
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
	update_from_model()

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
		lateral_energy = _m20_confirmed_lateral_energy(collider, lateral_energy, lateral)
		var contact_side_x := collider_local.x if has_collider_center else contact_local.x
		if longitudinal_energy > 1.0:
			if contact_side_x < FRAME_BASE_POS.x:
				hybrid_rear_collision_energy_j = maxf(hybrid_rear_collision_energy_j, longitudinal_energy)
			else:
				hybrid_front_collision_energy_j = maxf(hybrid_front_collision_energy_j, longitudinal_energy)

		var half_width := CARGO_BASE_SIZE.z * 0.5
		var side_region := absf(contact_local.z) >= half_width * 0.40
		side_region = side_region and contact_local.x >= -0.25 and contact_local.x <= 7.65
		if side_region and has_collider_center:
			var longitudinal_from_mid := collider_local.x - FRAME_BASE_POS.x
			side_region = absf(collider_local.z) >= half_width * 0.26
			side_region = side_region and absf(collider_local.z) > absf(longitudinal_from_mid) * 0.24
		if not side_region or lateral_energy <= 1.0:
			continue
		if contact_local.z < 0.0:
			if lateral_energy > hybrid_side_negative_z_energy_j:
				hybrid_side_negative_z_energy_j = lateral_energy
				hybrid_side_negative_z_contact_x_m = clampf(contact_local.x, 0.0, 7.35)
		else:
			if lateral_energy > hybrid_side_positive_z_energy_j:
				hybrid_side_positive_z_energy_j = lateral_energy
				hybrid_side_positive_z_contact_x_m = clampf(contact_local.x, 0.0, 7.35)

	hybrid_rear_crush_m = maxf(hybrid_rear_crush_m, minf(_energy_to_crush(hybrid_rear_collision_energy_j, 155000.0, 455000.0), 0.78))
	hybrid_front_crush_m = maxf(hybrid_front_crush_m, minf(_energy_to_crush(hybrid_front_collision_energy_j, 425000.0, 920000.0), 0.66))
	hybrid_side_negative_z_crush_m = maxf(hybrid_side_negative_z_crush_m, minf(_energy_to_crush(hybrid_side_negative_z_energy_j, 455000.0, 1120000.0), 0.46))
	hybrid_side_positive_z_crush_m = maxf(hybrid_side_positive_z_crush_m, minf(_energy_to_crush(hybrid_side_positive_z_energy_j, 455000.0, 1120000.0), 0.46))

func _m20_confirmed_lateral_energy(collider: Object, measured_energy_j: float, lateral_world: Vector3) -> float:
	# See M20HeavyTruck: only a real Godot contact may transfer the striker's
	# measured impact demand into this local broadside deformation model.
	if not collider is VehicleRigidChassis:
		return measured_energy_j
	var source_chassis := collider as VehicleRigidChassis
	var source := source_chassis.get_parent()
	if source == null or not source.has_method("hybrid_collision_energy_j"):
		return measured_energy_j
	var source_energy := float(source.call("hybrid_collision_energy_j"))
	if source_energy <= 0.0:
		return measured_energy_j
	var lateral_fraction := absf(source_chassis.initial_forward_world.dot(lateral_world.normalized()))
	return maxf(measured_energy_j, source_energy * lateral_fraction * lateral_fraction)

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
	var alpha := clampf(1.0 - exp(-20.0 * maxf(delta, 0.0)), 0.0, 1.0)
	_deform_longitudinal_station(RigidLorryBuilder.REAR_STATION, hybrid_rear_crush_m, 1.0, true, alpha)
	_deform_longitudinal_station(1, hybrid_rear_crush_m, 0.32, true, alpha)
	_deform_longitudinal_station(RigidLorryBuilder.FRONT_STATION, hybrid_front_crush_m, 1.0, false, alpha)
	_deform_longitudinal_station(4, hybrid_front_crush_m, 0.38, false, alpha)
	_deform_sides(alpha)
	_update_m20_collision_shapes()

func _deform_longitudinal_station(station: int, crush_m: float, weight: float, rear: bool, alpha: float) -> void:
	if crush_m <= 0.0:
		return
	for corner in range(4):
		var index := RigidLorryBuilder.node_index(station, corner)
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
			target_local.y = minf(current_local.y, reference_local.y - crush_m * weight * 0.18)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(rigid_chassis.to_global(target_local), alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO

func _deform_sides(alpha: float) -> void:
	for index in range(model.nodes.size()):
		var reference_local := hybrid_reference_local_positions[index]
		var side_sign := 0.0
		var crush := 0.0
		var contact_x := 0.0
		if reference_local.z < -0.05 and hybrid_side_negative_z_crush_m > 0.0001:
			side_sign = -1.0
			crush = hybrid_side_negative_z_crush_m
			contact_x = hybrid_side_negative_z_contact_x_m
		elif reference_local.z > 0.05 and hybrid_side_positive_z_crush_m > 0.0001:
			side_sign = 1.0
			crush = hybrid_side_positive_z_crush_m
			contact_x = hybrid_side_positive_z_contact_x_m
		if side_sign == 0.0:
			continue
		var longitudinal_weight := clampf(1.0 - absf(reference_local.x - contact_x) / 2.8, 0.10, 1.0)
		var current_local := rigid_chassis.to_local(model.nodes[index].position_m)
		var target_local := current_local
		var desired_z := reference_local.z - side_sign * crush * longitudinal_weight
		if side_sign > 0.0:
			target_local.z = minf(current_local.z, desired_z)
		else:
			target_local.z = maxf(current_local.z, desired_z)
		if (index % 4) >= 2:
			target_local.y = minf(current_local.y, reference_local.y - crush * longitudinal_weight * 0.15)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(rigid_chassis.to_global(target_local), alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO

func _reset_m20_collision_shapes() -> void:
	_set_box(cargo_collision, CARGO_BASE_SIZE, CARGO_BASE_POS)
	_set_box(cab_collision, CAB_BASE_SIZE, CAB_BASE_POS)
	_set_box(frame_collision, FRAME_BASE_SIZE, FRAME_BASE_POS)
	_set_box(rear_guard_collision, REAR_GUARD_BASE_SIZE, REAR_GUARD_BASE_POS)

func _update_m20_collision_shapes() -> void:
	var cargo_rear := CARGO_BASE_POS.x - CARGO_BASE_SIZE.x * 0.5 + hybrid_rear_crush_m * 0.68
	var cargo_front := CARGO_BASE_POS.x + CARGO_BASE_SIZE.x * 0.5
	var cargo_size := CARGO_BASE_SIZE
	cargo_size.x = maxf(cargo_front - cargo_rear, 3.75)
	var cargo_pos := CARGO_BASE_POS
	cargo_pos.x = (cargo_front + cargo_rear) * 0.5
	_set_box(cargo_collision, cargo_size, cargo_pos)

	var cab_rear := CAB_BASE_POS.x - CAB_BASE_SIZE.x * 0.5
	var cab_front := CAB_BASE_POS.x + CAB_BASE_SIZE.x * 0.5 - hybrid_front_crush_m * 0.74
	var cab_size := CAB_BASE_SIZE
	cab_size.x = maxf(cab_front - cab_rear, 1.75)
	var cab_pos := CAB_BASE_POS
	cab_pos.x = (cab_front + cab_rear) * 0.5
	_set_box(cab_collision, cab_size, cab_pos)

	var frame_rear := FRAME_BASE_POS.x - FRAME_BASE_SIZE.x * 0.5 + hybrid_rear_crush_m * 0.36
	var frame_front := FRAME_BASE_POS.x + FRAME_BASE_SIZE.x * 0.5 - hybrid_front_crush_m * 0.36
	var frame_size := FRAME_BASE_SIZE
	frame_size.x = maxf(frame_front - frame_rear, 6.05)
	var frame_pos := FRAME_BASE_POS
	frame_pos.x = (frame_front + frame_rear) * 0.5
	_set_box(frame_collision, frame_size, frame_pos)

	var guard_pos := REAR_GUARD_BASE_POS
	guard_pos.x += hybrid_rear_crush_m
	_set_box(rear_guard_collision, REAR_GUARD_BASE_SIZE, guard_pos)

	_retreat_shape_side(cargo_collision, CARGO_BASE_SIZE.z, CARGO_BASE_POS.x, 3.0, 1.45, 0.58)
	_retreat_shape_side(cab_collision, CAB_BASE_SIZE.z, CAB_BASE_POS.x, 1.9, 1.38, 0.62)
	_retreat_shape_side(frame_collision, FRAME_BASE_SIZE.z, FRAME_BASE_POS.x, 4.2, 1.08, 0.30)

func _retreat_shape_side(
	collision: CollisionShape3D,
	base_width_m: float,
	shape_x_m: float,
	influence_radius_m: float,
	minimum_width_m: float,
	retreat_fraction: float
) -> void:
	if collision == null:
		return
	var box := collision.shape as BoxShape3D
	if box == null:
		return
	var negative_weight := clampf(1.0 - absf(shape_x_m - hybrid_side_negative_z_contact_x_m) / maxf(influence_radius_m, 0.1), 0.0, 1.0)
	var positive_weight := clampf(1.0 - absf(shape_x_m - hybrid_side_positive_z_contact_x_m) / maxf(influence_radius_m, 0.1), 0.0, 1.0)
	var negative_face := -base_width_m * 0.5 + hybrid_side_negative_z_crush_m * retreat_fraction * negative_weight
	var positive_face := base_width_m * 0.5 - hybrid_side_positive_z_crush_m * retreat_fraction * positive_weight
	if positive_face - negative_face < minimum_width_m:
		var center := (positive_face + negative_face) * 0.5
		negative_face = center - minimum_width_m * 0.5
		positive_face = center + minimum_width_m * 0.5
	var size := box.size
	size.z = positive_face - negative_face
	box.size = size
	var position_value := collision.position
	position_value.z = (positive_face + negative_face) * 0.5
	collision.position = position_value

func _set_box(collision: CollisionShape3D, size: Vector3, position_value: Vector3) -> void:
	if collision == null:
		return
	var box := collision.shape as BoxShape3D
	if box != null:
		box.size = size
	collision.position = position_value
