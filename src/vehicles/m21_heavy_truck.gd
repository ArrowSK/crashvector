# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M21HeavyTruck
extends M20HeavyTruck

# M21 replaces the M17-M20 one-piece tractor/trailer world body with two real
# Godot RigidBody3D assemblies connected at a constrained fifth wheel. Local
# M20 front/rear/side deformation remains phenomenological and is applied in
# each body's own frame. This is still a generic educational articulated truck,
# not a tyre, suspension, load-transfer or manufacturer-specific model.

const FIFTH_WHEEL_LOCAL := Vector3(6.62, 0.88, 0.0)
const TRAILER_MASS_FRACTION := 0.68
const TRAILER_FRAME_BASE_SIZE := Vector3(6.70, 0.30, 1.80)
const TRAILER_FRAME_BASE_POS := Vector3(3.35, 0.58, 0.0)
const TRACTOR_FRAME_BASE_SIZE := Vector3(3.05, 0.30, 1.72)
const TRACTOR_FRAME_BASE_POS := Vector3(8.00, 0.58, 0.0)
const MAX_FIFTH_WHEEL_YAW_DEG := 52.0
const MAX_FIFTH_WHEEL_PITCH_DEG := 8.0
const MAX_FIFTH_WHEEL_ROLL_DEG := 6.0

var tractor_chassis: VehicleRigidChassis
var tractor_frame_collision: CollisionShape3D
var fifth_wheel_joint: Generic6DOFJoint3D
var last_tractor_transform := Transform3D.IDENTITY
var tractor_sync_ready := false
var maximum_articulation_yaw_deg: float = 0.0

func _ready() -> void:
	super._ready()
	_m21_split_world_body()
	_m21_build_fifth_wheel()
	last_chassis_transform = rigid_chassis.global_transform
	last_tractor_transform = tractor_chassis.global_transform
	chassis_sync_ready = true
	tractor_sync_ready = true
	update_from_model()

func begin_simulation() -> void:
	maximum_articulation_yaw_deg = 0.0
	super.begin_simulation()
	# M17's inherited start path restores its historical one-piece frame size.
	# Re-apply the M21 split immediately so the trailer body cannot carry an
	# invisible full-length frame through the articulated tractor region.
	_reset_m20_collision_shapes()
	if tractor_chassis == null:
		return
	tractor_chassis.position = origin_offset_m
	tractor_chassis.rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	last_tractor_transform = tractor_chassis.global_transform
	tractor_sync_ready = true
	tractor_chassis.begin_motion(initial_speed_kmh, heading_deg)
	_m21_place_and_bind_joint()

func set_simulation_paused(value: bool) -> void:
	super.set_simulation_paused(value)
	if tractor_chassis != null:
		tractor_chassis.set_motion_paused(value)

func end_simulation() -> void:
	super.end_simulation()
	if tractor_chassis != null:
		_sync_model_to_chassis()
		tractor_chassis.stop_motion()

func set_preview_pose(position_m: Vector3, yaw_deg: float) -> void:
	super.set_preview_pose(position_m, yaw_deg)
	if tractor_chassis == null:
		return
	tractor_chassis.position = position_m
	tractor_chassis.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	last_tractor_transform = tractor_chassis.global_transform
	tractor_sync_ready = true
	_m21_place_and_bind_joint()
	update_from_model()

func step_external(delta: float) -> void:
	super.step_external(delta)
	if delta > 0.0 and tractor_chassis != null:
		maximum_articulation_yaw_deg = maxf(maximum_articulation_yaw_deg, absf(articulation_yaw_deg()))

func global_linear_velocity_ms() -> Vector3:
	if rigid_chassis == null or tractor_chassis == null:
		return super.global_linear_velocity_ms()
	var total := maxf(rigid_chassis.mass + tractor_chassis.mass, 1.0)
	return (rigid_chassis.linear_velocity * rigid_chassis.mass + tractor_chassis.linear_velocity * tractor_chassis.mass) / total

func global_momentum_kg_ms() -> Vector3:
	if rigid_chassis == null or tractor_chassis == null:
		return super.global_momentum_kg_ms()
	return rigid_chassis.linear_velocity * rigid_chassis.mass + tractor_chassis.linear_velocity * tractor_chassis.mass

func global_kinetic_energy_j() -> float:
	if rigid_chassis == null or tractor_chassis == null:
		return super.global_kinetic_energy_j()
	return (
		0.5 * rigid_chassis.mass * rigid_chassis.linear_velocity.length_squared()
		+ 0.5 * tractor_chassis.mass * tractor_chassis.linear_velocity.length_squared()
	)

func articulation_yaw_deg() -> float:
	if rigid_chassis == null or tractor_chassis == null:
		return 0.0
	var trailer_basis := rigid_chassis.global_transform.basis.orthonormalized()
	var tractor_basis := tractor_chassis.global_transform.basis.orthonormalized()
	var relative := trailer_basis.inverse() * tractor_basis
	return rad_to_deg(wrapf(relative.get_euler().y, -PI, PI))

func fifth_wheel_separation_m() -> float:
	if rigid_chassis == null or tractor_chassis == null:
		return 0.0
	return rigid_chassis.to_global(FIFTH_WHEEL_LOCAL).distance_to(tractor_chassis.to_global(FIFTH_WHEEL_LOCAL))

func combined_contact_manifold_diagnostics() -> Dictionary:
	var trailer := rigid_chassis.contact_manifold_diagnostics() if rigid_chassis != null else {}
	var tractor := tractor_chassis.contact_manifold_diagnostics() if tractor_chassis != null else {}
	var trailer_span_value: Variant = trailer.get("maximum_span_local_m", Vector3.ZERO)
	var tractor_span_value: Variant = tractor.get("maximum_span_local_m", Vector3.ZERO)
	var trailer_span := trailer_span_value as Vector3 if trailer_span_value is Vector3 else Vector3.ZERO
	var tractor_span := tractor_span_value as Vector3 if tractor_span_value is Vector3 else Vector3.ZERO
	return {
		"maximum_contact_points": maxi(int(trailer.get("maximum_contact_points", 0)), int(tractor.get("maximum_contact_points", 0))),
		"maximum_span_local_m": Vector3(
			maxf(trailer_span.x, tractor_span.x),
			maxf(trailer_span.y, tractor_span.y),
			maxf(trailer_span.z, tractor_span.z)
		),
		"maximum_projected_span_xz_m2": maxf(float(trailer.get("maximum_projected_span_xz_m2", 0.0)), float(tractor.get("maximum_projected_span_xz_m2", 0.0))),
		"peak_total_impulse_ns": maxf(float(trailer.get("peak_total_impulse_ns", 0.0)), float(tractor.get("peak_total_impulse_ns", 0.0))),
		"peak": trailer.get("peak", {}) if float(trailer.get("peak_total_impulse_ns", 0.0)) >= float(tractor.get("peak_total_impulse_ns", 0.0)) else tractor.get("peak", {}),
		"scope": "diagnostic_only_no_solver_feedback_articulated_pair",
		"trailer": trailer,
		"tractor": tractor,
	}

func _m21_split_world_body() -> void:
	if rigid_chassis == null:
		return
	var trailer_mass := maxf(total_mass_kg * TRAILER_MASS_FRACTION, 1000.0)
	var tractor_mass := maxf(total_mass_kg - trailer_mass, 1000.0)
	rigid_chassis.mass = trailer_mass

	# The M12 body originally contained the tractor collision and a full-length
	# frame. Disable only those overlapping pieces; retain the trailer box, rear
	# underride face and the established trailer-side suspension contacts.
	var old_tractor := rigid_chassis.get_node_or_null("TractorCollision") as CollisionShape3D
	if old_tractor != null:
		old_tractor.disabled = true
	if frame_collision != null:
		_m17_set_box(frame_collision, TRAILER_FRAME_BASE_SIZE, TRAILER_FRAME_BASE_POS)
	for point in rigid_chassis.suspension_points:
		var ray := point.get("ray") as RayCast3D
		if ray != null and ray.position.x > 7.0:
			ray.enabled = false

	tractor_chassis = VehicleRigidChassis.new()
	tractor_chassis.name = "ArticulatedTractorChassis"
	add_child(tractor_chassis)
	tractor_chassis.configure(tractor_mass, origin_offset_m, heading_deg, initial_speed_kmh, 0.86, 0.0)
	tractor_collision = tractor_chassis.add_box_shape("M21TractorCollision", TRACTOR_BASE_SIZE, TRACTOR_BASE_POS)
	tractor_frame_collision = tractor_chassis.add_box_shape("M21TractorFrameCollision", TRACTOR_FRAME_BASE_SIZE, TRACTOR_FRAME_BASE_POS)

	var mass_scale := maxf(tractor_mass / 5800.0, 0.35)
	var suspension_k := 245000.0 * mass_scale
	var suspension_c := 19000.0 * sqrt(mass_scale)
	var suspension_max := 72000.0 * mass_scale
	var station := 6
	var x := HeavyTruckBuilder.STATION_X[station]
	var z := HeavyTruckBuilder.HALF_WIDTH_Z[station]
	tractor_chassis.add_suspension_point("TractorSuspension", Vector3(x, 0.72, -z), 0.82, suspension_k, suspension_c, suspension_max)
	tractor_chassis.add_suspension_point("TractorSuspension", Vector3(x, 0.72, z), 0.82, suspension_k, suspension_c, suspension_max)

	rigid_chassis.add_collision_exception_with(tractor_chassis)
	tractor_chassis.add_collision_exception_with(rigid_chassis)

func _m21_build_fifth_wheel() -> void:
	if rigid_chassis == null or tractor_chassis == null:
		return
	fifth_wheel_joint = Generic6DOFJoint3D.new()
	fifth_wheel_joint.name = "FifthWheelJoint"
	add_child(fifth_wheel_joint)
	_m21_configure_joint_axis(0, MAX_FIFTH_WHEEL_PITCH_DEG)
	_m21_configure_joint_axis(1, MAX_FIFTH_WHEEL_YAW_DEG)
	_m21_configure_joint_axis(2, MAX_FIFTH_WHEEL_ROLL_DEG)
	_m21_place_and_bind_joint()

func _m21_configure_joint_axis(axis: int, angular_limit_deg: float) -> void:
	if fifth_wheel_joint == null:
		return
	var limit := deg_to_rad(maxf(angular_limit_deg, 0.5))
	match axis:
		0:
			fifth_wheel_joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			fifth_wheel_joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			fifth_wheel_joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			fifth_wheel_joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			fifth_wheel_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -limit)
			fifth_wheel_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, limit)
			fifth_wheel_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LIMIT_SOFTNESS, 0.72)
			fifth_wheel_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, 0.82)
		1:
			fifth_wheel_joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			fifth_wheel_joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			fifth_wheel_joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			fifth_wheel_joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			fifth_wheel_joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -limit)
			fifth_wheel_joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, limit)
			fifth_wheel_joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LIMIT_SOFTNESS, 0.80)
			fifth_wheel_joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, 0.72)
		2:
			fifth_wheel_joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
			fifth_wheel_joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			fifth_wheel_joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
			fifth_wheel_joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
			fifth_wheel_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -limit)
			fifth_wheel_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, limit)
			fifth_wheel_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LIMIT_SOFTNESS, 0.72)
			fifth_wheel_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, 0.84)

func _m21_place_and_bind_joint() -> void:
	if fifth_wheel_joint == null or rigid_chassis == null or tractor_chassis == null:
		return
	var basis := rigid_chassis.global_transform.basis.orthonormalized()
	fifth_wheel_joint.global_transform = Transform3D(basis, rigid_chassis.to_global(FIFTH_WHEEL_LOCAL))
	fifth_wheel_joint.node_a = NodePath()
	fifth_wheel_joint.node_b = NodePath()
	fifth_wheel_joint.node_a = fifth_wheel_joint.get_path_to(rigid_chassis)
	fifth_wheel_joint.node_b = fifth_wheel_joint.get_path_to(tractor_chassis)

func _sync_model_to_chassis() -> void:
	if rigid_chassis == null or tractor_chassis == null or model == null:
		return
	var current_trailer := rigid_chassis.global_transform
	var current_tractor := tractor_chassis.global_transform
	if not chassis_sync_ready or not tractor_sync_ready:
		last_chassis_transform = current_trailer
		last_tractor_transform = current_tractor
		chassis_sync_ready = true
		tractor_sync_ready = true
		return
	var trailer_delta := current_trailer * last_chassis_transform.affine_inverse()
	var tractor_delta := current_tractor * last_tractor_transform.affine_inverse()
	for index in range(model.nodes.size()):
		var station := int(index / 4)
		var delta_transform := trailer_delta if station <= HeavyTruckBuilder.TRAILER_END_STATION else tractor_delta
		model.nodes[index].position_m = delta_transform * model.nodes[index].position_m
		model.nodes[index].velocity_ms = Vector3.ZERO
	last_chassis_transform = current_trailer
	last_tractor_transform = current_tractor

func _m20_consume_contacts() -> void:
	if rigid_chassis == null or tractor_chassis == null:
		return
	_m21_consume_body_contacts(rigid_chassis, false)
	_m21_consume_body_contacts(tractor_chassis, true)

	hybrid_rear_crush_m = maxf(hybrid_rear_crush_m, minf(_m17_energy_to_crush(hybrid_rear_collision_energy_j, 190000.0, 520000.0), 0.90))
	hybrid_front_crush_m = maxf(hybrid_front_crush_m, minf(_m17_energy_to_crush(hybrid_front_collision_energy_j, 520000.0, 1050000.0), 0.78))
	hybrid_side_negative_z_crush_m = maxf(hybrid_side_negative_z_crush_m, minf(_m17_energy_to_crush(hybrid_side_negative_z_energy_j, 610000.0, 1450000.0), 0.52))
	hybrid_side_positive_z_crush_m = maxf(hybrid_side_positive_z_crush_m, minf(_m17_energy_to_crush(hybrid_side_positive_z_energy_j, 610000.0, 1450000.0), 0.52))

func _m21_consume_body_contacts(body: VehicleRigidChassis, tractor_part: bool) -> void:
	var forward := body.global_transform.basis.x.normalized()
	var lateral := body.global_transform.basis.z.normalized()
	for sample in body.drain_contact_samples():
		var collider_name: StringName = sample.get("collider_name", StringName(""))
		if collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround":
			continue
		var collider: Object = sample.get("collider", null)
		var contact_local: Vector3 = sample.get("position_local", Vector3.ZERO)
		var collider_local := contact_local
		var has_collider_center := false
		var other_velocity := Vector3.ZERO
		var other_mass := body.mass
		if collider is Node3D:
			collider_local = body.to_local((collider as Node3D).global_position)
			has_collider_center = true
		if collider is RigidBody3D:
			var other := collider as RigidBody3D
			other_velocity = other.linear_velocity
			other_mass = maxf(other.mass, 1.0)

		var relative_velocity := other_velocity - body.linear_velocity
		var reduced_mass := body.mass * other_mass / maxf(body.mass + other_mass, 1.0)
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
			if not tractor_part and contact_side_x < 4.2:
				hybrid_rear_collision_energy_j = maxf(hybrid_rear_collision_energy_j, longitudinal_energy)
			else:
				hybrid_front_collision_energy_j = maxf(hybrid_front_collision_energy_j, longitudinal_energy)

		var half_width := (TRAILER_BASE_SIZE.z if not tractor_part else TRACTOR_BASE_SIZE.z) * 0.5
		var side_region := absf(contact_local.z) >= half_width * 0.40
		if has_collider_center:
			var local_mid_x := TRAILER_BASE_POS.x if not tractor_part else TRACTOR_BASE_POS.x
			var longitudinal_from_mid := collider_local.x - local_mid_x
			side_region = side_region and absf(collider_local.z) >= half_width * 0.25
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

func _m17_enforce_crush(delta: float) -> void:
	if rigid_chassis == null or tractor_chassis == null or hybrid_reference_local_positions.size() != model.nodes.size():
		return
	if hybrid_rear_crush_m <= 0.0001 and hybrid_front_crush_m <= 0.0001:
		return
	var alpha := clampf(1.0 - exp(-20.0 * maxf(delta, 0.0)), 0.0, 1.0)
	_m21_deform_longitudinal_station(HeavyTruckBuilder.REAR_STATION, hybrid_rear_crush_m, 1.0, true, alpha, rigid_chassis)
	_m21_deform_longitudinal_station(1, hybrid_rear_crush_m, 0.34, true, alpha, rigid_chassis)
	_m21_deform_longitudinal_station(HeavyTruckBuilder.FRONT_STATION, hybrid_front_crush_m, 1.0, false, alpha, tractor_chassis)
	_m21_deform_longitudinal_station(6, hybrid_front_crush_m, 0.42, false, alpha, tractor_chassis)
	_m21_update_longitudinal_collision_shapes()

func _m21_deform_longitudinal_station(
	station: int,
	crush_m: float,
	weight: float,
	rear: bool,
	alpha: float,
	body: VehicleRigidChassis
) -> void:
	if crush_m <= 0.0:
		return
	for corner in range(4):
		var index := HeavyTruckBuilder.node_index(station, corner)
		if index < 0 or index >= model.nodes.size():
			continue
		var reference_local := hybrid_reference_local_positions[index]
		var current_local := body.to_local(model.nodes[index].position_m)
		var target_local := current_local
		var desired_x := reference_local.x + crush_m * weight * (1.0 if rear else -1.0)
		if rear:
			target_local.x = maxf(current_local.x, desired_x)
		else:
			target_local.x = minf(current_local.x, desired_x)
		if corner >= 2:
			target_local.y = minf(current_local.y, reference_local.y - crush_m * weight * (0.16 if rear else 0.24))
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(body.to_global(target_local), alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO

func _m20_enforce_side_crush(delta: float) -> void:
	if rigid_chassis == null or tractor_chassis == null or model == null:
		return
	if hybrid_reference_local_positions.size() != model.nodes.size() or side_impact_deformation_m() <= 0.0001:
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
		var station := int(index / 4)
		var body := rigid_chassis if station <= HeavyTruckBuilder.TRAILER_END_STATION else tractor_chassis
		var longitudinal_weight := clampf(1.0 - absf(reference_local.x - contact_x) / 3.4, 0.10, 1.0)
		var current_local := body.to_local(model.nodes[index].position_m)
		var target_local := current_local
		var desired_z := reference_local.z - side_sign * crush * longitudinal_weight
		if side_sign > 0.0:
			target_local.z = minf(current_local.z, desired_z)
		else:
			target_local.z = maxf(current_local.z, desired_z)
		if (index % 4) >= 2:
			target_local.y = minf(current_local.y, reference_local.y - crush * longitudinal_weight * 0.16)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(body.to_global(target_local), alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO
	_m20_update_side_collision_shapes()

func _reset_m20_collision_shapes() -> void:
	_m17_set_box(trailer_collision, TRAILER_BASE_SIZE, TRAILER_BASE_POS)
	_m17_set_box(tractor_collision, TRACTOR_BASE_SIZE, TRACTOR_BASE_POS)
	_m17_set_box(frame_collision, TRAILER_FRAME_BASE_SIZE, TRAILER_FRAME_BASE_POS)
	_m17_set_box(tractor_frame_collision, TRACTOR_FRAME_BASE_SIZE, TRACTOR_FRAME_BASE_POS)
	_m17_set_box(underride_collision, UNDERRIDE_BASE_SIZE, UNDERRIDE_BASE_POS)

func _m21_update_longitudinal_collision_shapes() -> void:
	var trailer_rear := TRAILER_BASE_POS.x - TRAILER_BASE_SIZE.x * 0.5 + hybrid_rear_crush_m * 0.72
	var trailer_front := TRAILER_BASE_POS.x + TRAILER_BASE_SIZE.x * 0.5
	var trailer_size := TRAILER_BASE_SIZE
	trailer_size.x = maxf(trailer_front - trailer_rear, 4.90)
	var trailer_pos := TRAILER_BASE_POS
	trailer_pos.x = (trailer_front + trailer_rear) * 0.5
	_m17_set_box(trailer_collision, trailer_size, trailer_pos)

	var tractor_rear := TRACTOR_BASE_POS.x - TRACTOR_BASE_SIZE.x * 0.5
	var tractor_front := TRACTOR_BASE_POS.x + TRACTOR_BASE_SIZE.x * 0.5 - hybrid_front_crush_m * 0.78
	var tractor_size := TRACTOR_BASE_SIZE
	tractor_size.x = maxf(tractor_front - tractor_rear, 1.82)
	var tractor_pos := TRACTOR_BASE_POS
	tractor_pos.x = (tractor_front + tractor_rear) * 0.5
	_m17_set_box(tractor_collision, tractor_size, tractor_pos)

	var trailer_frame_size := TRAILER_FRAME_BASE_SIZE
	trailer_frame_size.x = maxf(TRAILER_FRAME_BASE_SIZE.x - hybrid_rear_crush_m * 0.42, 5.90)
	var trailer_frame_pos := TRAILER_FRAME_BASE_POS
	trailer_frame_pos.x += hybrid_rear_crush_m * 0.21
	_m17_set_box(frame_collision, trailer_frame_size, trailer_frame_pos)

	var tractor_frame_size := TRACTOR_FRAME_BASE_SIZE
	tractor_frame_size.x = maxf(TRACTOR_FRAME_BASE_SIZE.x - hybrid_front_crush_m * 0.42, 2.35)
	var tractor_frame_pos := TRACTOR_FRAME_BASE_POS
	tractor_frame_pos.x -= hybrid_front_crush_m * 0.21
	_m17_set_box(tractor_frame_collision, tractor_frame_size, tractor_frame_pos)

	var underride_pos := UNDERRIDE_BASE_POS
	underride_pos.x += hybrid_rear_crush_m
	_m17_set_box(underride_collision, UNDERRIDE_BASE_SIZE, underride_pos)

func _m20_update_side_collision_shapes() -> void:
	_m20_retreat_shape_side(trailer_collision, TRAILER_BASE_SIZE.z, TRAILER_BASE_POS.x, 3.8, 1.55, 0.58)
	_m20_retreat_shape_side(tractor_collision, TRACTOR_BASE_SIZE.z, TRACTOR_BASE_POS.x, 2.1, 1.45, 0.64)
	_m20_retreat_shape_side(frame_collision, TRAILER_FRAME_BASE_SIZE.z, TRAILER_FRAME_BASE_POS.x, 3.6, 1.15, 0.32)
	_m20_retreat_shape_side(tractor_frame_collision, TRACTOR_FRAME_BASE_SIZE.z, TRACTOR_FRAME_BASE_POS.x, 2.2, 1.10, 0.34)

func update_from_model() -> void:
	super.update_from_model()
	if model == null or tractor_chassis == null:
		return
	for wheel in wheel_visuals:
		var index := int(wheel.get_meta("anchor_index"))
		if index < 0 or index >= model.nodes.size():
			continue
		var station := int(index / 4)
		var body := rigid_chassis if station <= HeavyTruckBuilder.TRAILER_END_STATION else tractor_chassis
		var basis := body.global_transform.basis.orthonormalized()
		var up := basis.y.normalized()
		wheel.position = model.nodes[index].position_m - up * 0.31
		wheel.basis = basis
	if debug_renderer != null:
		debug_renderer.update_from_model()
