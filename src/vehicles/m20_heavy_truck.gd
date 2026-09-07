# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M20HeavyTruck
extends M17HeavyTruck

# M20 extends the existing single-rigid-body heavy-truck target with bounded
# local side deformation for broadside/oblique contact. Godot still owns world
# motion and contact impulses. This remains one tractor/trailer rigid assembly;
# fifth-wheel articulation is intentionally deferred to M21.

var hybrid_side_negative_z_energy_j: float = 0.0
var hybrid_side_positive_z_energy_j: float = 0.0
var hybrid_side_negative_z_crush_m: float = 0.0
var hybrid_side_positive_z_crush_m: float = 0.0
var hybrid_side_negative_z_contact_x_m: float = TRAILER_BASE_POS.x
var hybrid_side_positive_z_contact_x_m: float = TRAILER_BASE_POS.x

func begin_simulation() -> void:
	hybrid_side_negative_z_energy_j = 0.0
	hybrid_side_positive_z_energy_j = 0.0
	hybrid_side_negative_z_crush_m = 0.0
	hybrid_side_positive_z_crush_m = 0.0
	hybrid_side_negative_z_contact_x_m = TRAILER_BASE_POS.x
	hybrid_side_positive_z_contact_x_m = TRAILER_BASE_POS.x
	super.begin_simulation()

func step_external(delta: float) -> void:
	if not hybrid_physics_enabled:
		super.step_external(delta)
		return
	if delta <= 0.0:
		update_from_model()
		return
	_sync_model_to_chassis()
	_m20_consume_contacts()
	_m17_enforce_crush(delta)
	_m20_enforce_side_crush(delta)
	update_from_model()

func side_impact_deformation_m() -> float:
	return maxf(hybrid_side_negative_z_crush_m, hybrid_side_positive_z_crush_m)

func side_impact_energy_j() -> float:
	return maxf(hybrid_side_negative_z_energy_j, hybrid_side_positive_z_energy_j)

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

		# Keep M17 front/rear behaviour for the longitudinal component. A pure
		# broadside impulse has almost no projected longitudinal demand, while an
		# oblique corner strike can legitimately load both longitudinal and side
		# paths in the same real contact event.
		var contact_side_x := collider_local.x if has_collider_center else contact_local.x
		if longitudinal_energy > 1.0:
			if contact_side_x < 4.2:
				hybrid_rear_collision_energy_j = maxf(hybrid_rear_collision_energy_j, longitudinal_energy)
			else:
				hybrid_front_collision_energy_j = maxf(hybrid_front_collision_energy_j, longitudinal_energy)

		var half_width := TRAILER_BASE_SIZE.z * 0.5
		var side_region := absf(contact_local.z) >= half_width * 0.42
		side_region = side_region and contact_local.x >= -0.30 and contact_local.x <= 9.85
		if side_region and has_collider_center:
			var longitudinal_from_mid := collider_local.x - FRAME_BASE_POS.x
			side_region = absf(collider_local.z) >= half_width * 0.28
			side_region = side_region and absf(collider_local.z) > absf(longitudinal_from_mid) * 0.22
		if not side_region or lateral_energy <= 1.0:
			continue

		if contact_local.z < 0.0:
			if lateral_energy > hybrid_side_negative_z_energy_j:
				hybrid_side_negative_z_energy_j = lateral_energy
				hybrid_side_negative_z_contact_x_m = clampf(contact_local.x, 0.0, 9.5)
		else:
			if lateral_energy > hybrid_side_positive_z_energy_j:
				hybrid_side_positive_z_energy_j = lateral_energy
				hybrid_side_positive_z_contact_x_m = clampf(contact_local.x, 0.0, 9.5)

	hybrid_rear_crush_m = maxf(hybrid_rear_crush_m, minf(_m17_energy_to_crush(hybrid_rear_collision_energy_j, 190000.0, 520000.0), 0.90))
	hybrid_front_crush_m = maxf(hybrid_front_crush_m, minf(_m17_energy_to_crush(hybrid_front_collision_energy_j, 520000.0, 1050000.0), 0.78))
	hybrid_side_negative_z_crush_m = maxf(
		hybrid_side_negative_z_crush_m,
		minf(_m17_energy_to_crush(hybrid_side_negative_z_energy_j, 610000.0, 1450000.0), 0.52)
	)
	hybrid_side_positive_z_crush_m = maxf(
		hybrid_side_positive_z_crush_m,
		minf(_m17_energy_to_crush(hybrid_side_positive_z_energy_j, 610000.0, 1450000.0), 0.52)
	)

func _m20_enforce_side_crush(delta: float) -> void:
	if rigid_chassis == null or model == null:
		return
	if hybrid_reference_local_positions.size() != model.nodes.size():
		return
	if side_impact_deformation_m() <= 0.0001:
		return
	var alpha := clampf(1.0 - exp(-20.0 * maxf(delta, 0.0)), 0.0, 1.0)
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
		var local_half_width := maxf(absf(reference_local.z), 0.45)
		var side_weight := clampf(absf(reference_local.z) / local_half_width, 0.0, 1.0)
		var longitudinal_weight := clampf(1.0 - absf(reference_local.x - contact_x) / 3.4, 0.10, 1.0)
		var weight := side_weight * longitudinal_weight
		var current_local := rigid_chassis.to_local(model.nodes[index].position_m)
		var target_local := current_local
		var desired_z := reference_local.z - side_sign * crush * weight
		if side_sign > 0.0:
			target_local.z = minf(current_local.z, desired_z)
		else:
			target_local.z = maxf(current_local.z, desired_z)
		var upper := (index % 4) >= 2
		var desired_y := reference_local.y - crush * weight * (0.16 if upper else 0.035)
		target_local.y = minf(current_local.y, desired_y)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(rigid_chassis.to_global(target_local), alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO
	_m20_update_side_collision_shapes()

func _m20_update_side_collision_shapes() -> void:
	# Preserve M17's longitudinally shortened X dimensions and retreat only the
	# impacted lateral faces of the relevant rigid volumes.
	_m20_retreat_shape_side(
		trailer_collision,
		TRAILER_BASE_SIZE.z,
		TRAILER_BASE_POS.x,
		3.8,
		1.55,
		0.58
	)
	_m20_retreat_shape_side(
		tractor_collision,
		TRACTOR_BASE_SIZE.z,
		TRACTOR_BASE_POS.x,
		2.1,
		1.45,
		0.64
	)
	_m20_retreat_shape_side(
		frame_collision,
		FRAME_BASE_SIZE.z,
		FRAME_BASE_POS.x,
		5.3,
		1.15,
		0.32
	)

func _m20_retreat_shape_side(
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
