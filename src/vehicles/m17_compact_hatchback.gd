# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M17CompactHatchback
extends M162CompactHatchback

# M17 keeps Godot RigidBody3D authoritative for whole-vehicle motion and extends
# the existing local-crush model to direct rear impacts. M18 extends the same
# compatibility class with bounded lateral passenger-car deformation so
# broadside car-vs-car layouts can use the production rigid-body world without
# introducing another world-motion solver. These are generic educational
# deformation envelopes, not manufacturer crash-test correlation.

var hybrid_rear_impact_energy_j: float = 0.0
var hybrid_rear_impact_crush_m: float = 0.0
var hybrid_side_negative_z_energy_j: float = 0.0
var hybrid_side_positive_z_energy_j: float = 0.0
var hybrid_side_negative_z_crush_m: float = 0.0
var hybrid_side_positive_z_crush_m: float = 0.0

func begin_simulation() -> void:
	hybrid_rear_impact_energy_j = 0.0
	hybrid_rear_impact_crush_m = 0.0
	hybrid_side_negative_z_energy_j = 0.0
	hybrid_side_positive_z_energy_j = 0.0
	hybrid_side_negative_z_crush_m = 0.0
	hybrid_side_positive_z_crush_m = 0.0
	super.begin_simulation()

func rear_impact_deformation_m() -> float:
	return hybrid_rear_impact_crush_m

func side_impact_deformation_m() -> float:
	return maxf(hybrid_side_negative_z_crush_m, hybrid_side_positive_z_crush_m)

func side_impact_energy_j() -> float:
	return maxf(hybrid_side_negative_z_energy_j, hybrid_side_positive_z_energy_j)

func _consume_real_contact_impulses() -> void:
	if rigid_chassis == null:
		return
	var forward := rigid_chassis.global_transform.basis.x.normalized()
	var lateral := rigid_chassis.global_transform.basis.z.normalized()
	for sample in rigid_chassis.drain_contact_samples():
		var collider_name: StringName = sample.get("collider_name", StringName(""))
		if collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround":
			continue
		var impulse: Vector3 = sample.get("impulse", Vector3.ZERO)
		hybrid_crush_impulse_ns += impulse.length()
		var collider: Object = sample.get("collider", null)
		var local_position: Vector3 = sample.get("position_local", Vector3.ZERO)
		var other_velocity := Vector3.ZERO
		var other_mass := rigid_chassis.mass
		if collider is RigidBody3D:
			var other := collider as RigidBody3D
			other_velocity = other.linear_velocity
			other_mass = maxf(other.mass, 1.0)
		var reduced_mass := rigid_chassis.mass * other_mass / maxf(rigid_chassis.mass + other_mass, 1.0)
		var impulse_energy := impulse.length_squared() / maxf(2.0 * reduced_mass, 1.0)
		var collider_local_center := local_position
		var has_collider_center := false
		if collider is Node3D:
			collider_local_center = rigid_chassis.to_local((collider as Node3D).global_position)
			has_collider_center = true

		# M18 broadside classifier. The contact point must lie on a protected-cell
		# side face, and when the other actor exposes a centre transform its centre
		# must also approach predominantly from the lateral direction. The second
		# condition is important for preserving M17 rear impacts: a wide truck can
		# touch a side edge of the rear collision box even though its centre is
		# directly behind the car.
		var half_width := maxf(safety_cell_base_size_m.z * 0.5, 0.45)
		var half_length := maxf(safety_cell_base_size_m.x * 0.5, 0.70)
		var side_region := absf(local_position.z) >= half_width * 0.58
		side_region = side_region and absf(local_position.x - safety_cell_base_position_m.x) <= half_length * 0.92
		if side_region and has_collider_center:
			var centre_longitudinal := collider_local_center.x - safety_cell_base_position_m.x
			side_region = absf(collider_local_center.z) >= half_width * 0.35
			side_region = side_region and absf(collider_local_center.z) > absf(centre_longitudinal) * 0.60
		if side_region:
			var lateral_speed := absf((other_velocity - rigid_chassis.linear_velocity).dot(lateral))
			var lateral_velocity_energy := 0.5 * reduced_mass * lateral_speed * lateral_speed
			var side_energy := maxf(lateral_velocity_energy, impulse_energy)
			if local_position.z < 0.0:
				hybrid_side_negative_z_energy_j = maxf(hybrid_side_negative_z_energy_j, side_energy)
			else:
				hybrid_side_positive_z_energy_j = maxf(hybrid_side_positive_z_energy_j, side_energy)
			continue

		# PhysicsDirectBodyState contact points are useful for shape-local detail,
		# but actor-to-actor centre position is a more stable front/rear classifier
		# after a high-speed solver step. This also works when the other vehicle's
		# collision volume is already partly overlapping the protected cell.
		var contact_side_x := collider_local_center.x if has_collider_center else local_position.x
		# The protected-cell rigid volume spans the middle of the car. A collider
		# whose centre is materially behind the car is a direct rear-impact source;
		# forward impacts remain governed by the established M12/M13 probe path.
		if contact_side_x > -0.40:
			continue
		var closing_speed := maxf((other_velocity - rigid_chassis.linear_velocity).dot(forward), 0.0)
		if closing_speed <= 0.05:
			# Head-on/reversed geometry can produce the opposite sign. Contact-side
			# classification is authoritative, so retain the longitudinal magnitude.
			closing_speed = absf((other_velocity - rigid_chassis.linear_velocity).dot(forward))
		var velocity_energy := 0.5 * reduced_mass * closing_speed * closing_speed
		# By the time _integrate_forces exposes the contact, Godot has already
		# applied most of the collision impulse and the post-solve relative speed
		# can be close to zero. J^2/(2*mu) reconstructs the normal collision work
		# represented by that real solver impulse instead of losing the impact just
		# because both bodies now share a similar velocity.
		var energy := maxf(velocity_energy, impulse_energy)
		hybrid_rear_impact_energy_j = maxf(hybrid_rear_impact_energy_j, energy)

	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var stiffness_scale := maxf(float(preset.get("stiffness_scale", 1.0)), 0.45)
	var mass_scale := sqrt(maxf(total_mass_kg / 1150.0, 0.45))
	var scale_x := maxf(float(preset.get("scale_x", 1.0)), 0.55)
	var scale_z := maxf(float(preset.get("scale_z", 1.0)), 0.55)
	var resistance_scale := stiffness_scale * mass_scale
	var demanded := _m17_rear_energy_limited_crush_m(hybrid_rear_impact_energy_j, resistance_scale)
	hybrid_rear_impact_crush_m = maxf(hybrid_rear_impact_crush_m, minf(demanded, 0.64 * scale_x))
	var negative_side_demand := _m18_side_energy_limited_crush_m(hybrid_side_negative_z_energy_j, resistance_scale)
	var positive_side_demand := _m18_side_energy_limited_crush_m(hybrid_side_positive_z_energy_j, resistance_scale)
	hybrid_side_negative_z_crush_m = maxf(hybrid_side_negative_z_crush_m, minf(negative_side_demand, 0.50 * scale_z))
	hybrid_side_positive_z_crush_m = maxf(hybrid_side_positive_z_crush_m, minf(positive_side_demand, 0.50 * scale_z))

func _m17_rear_energy_limited_crush_m(collision_energy_j: float, resistance_scale: float) -> float:
	if collision_energy_j <= 0.0:
		return 0.0
	# Generic rear load path: lower initial resistance than the front crash-box
	# system, rising quickly once the luggage-floor/rear-rail region engages.
	var scale := maxf(resistance_scale, 0.20)
	var force0_n := 85000.0 * scale
	var stiffness_n_m := 310000.0 * scale
	var discriminant := force0_n * force0_n + 2.0 * stiffness_n_m * collision_energy_j
	return maxf((-force0_n + sqrt(maxf(discriminant, 0.0))) / maxf(stiffness_n_m, 1.0), 0.0)

func _m18_side_energy_limited_crush_m(collision_energy_j: float, resistance_scale: float) -> float:
	if collision_energy_j <= 0.0:
		return 0.0
	# Generic side load path. The initial resistance represents door/outer sill
	# engagement and the rising term represents rocker/B-pillar/roof-rail load
	# paths. It intentionally stays phenomenological and bounded.
	var scale := maxf(resistance_scale, 0.20)
	var force0_n := 130000.0 * scale
	var stiffness_n_m := 680000.0 * scale
	var discriminant := force0_n * force0_n + 2.0 * stiffness_n_m * collision_energy_j
	return maxf((-force0_n + sqrt(maxf(discriminant, 0.0))) / maxf(stiffness_n_m, 1.0), 0.0)

func _enforce_hybrid_crush_shape(delta: float) -> void:
	super._enforce_hybrid_crush_shape(delta)
	_m17_enforce_rear_crush(delta)
	_m18_enforce_side_crush(delta)

func _m17_enforce_rear_crush(delta: float) -> void:
	if hybrid_rear_impact_crush_m <= 0.0001 or rigid_chassis == null:
		return
	if hybrid_reference_local_positions.size() != model.nodes.size():
		return
	var alpha := clampf(1.0 - exp(-24.0 * maxf(delta, 0.0)), 0.0, 1.0)
	var station_weights := {
		CompactHatchbackBuilder.REAR_STATION: 1.00,
		CompactHatchbackBuilder.REAR_AXLE_STATION: 0.46,
		2: 0.14,
	}
	for station_variant in station_weights.keys():
		var station := int(station_variant)
		var weight := float(station_weights[station_variant])
		for corner in range(4):
			var index := CompactHatchbackBuilder.node_index(station, corner)
			if index < 0 or index >= model.nodes.size():
				continue
			var target_local := hybrid_reference_local_positions[index]
			target_local.x += hybrid_rear_impact_crush_m * weight
			if corner >= 2:
				target_local.y -= hybrid_rear_impact_crush_m * weight * 0.16
				target_local.z *= 1.0 - 0.055 * weight
			else:
				target_local.y += hybrid_rear_impact_crush_m * weight * 0.018
			var target_world := rigid_chassis.to_global(target_local)
			model.nodes[index].position_m = model.nodes[index].position_m.lerp(target_world, alpha)
			model.nodes[index].velocity_ms = Vector3.ZERO
	_m17_update_rear_collision_shape()

func _m18_enforce_side_crush(delta: float) -> void:
	var maximum_side_crush := side_impact_deformation_m()
	if maximum_side_crush <= 0.0001 or rigid_chassis == null:
		return
	if hybrid_reference_local_positions.size() != model.nodes.size():
		return
	var alpha := clampf(1.0 - exp(-24.0 * maxf(delta, 0.0)), 0.0, 1.0)
	var half_width := maxf(safety_cell_base_size_m.z * 0.5, 0.45)
	var half_length := maxf(safety_cell_base_size_m.x * 0.5, 0.70)
	for index in range(model.nodes.size()):
		var reference_local := hybrid_reference_local_positions[index]
		var side_sign := 0.0
		var crush := 0.0
		if reference_local.z < -0.05 and hybrid_side_negative_z_crush_m > 0.0001:
			side_sign = -1.0
			crush = hybrid_side_negative_z_crush_m
		elif reference_local.z > 0.05 and hybrid_side_positive_z_crush_m > 0.0001:
			side_sign = 1.0
			crush = hybrid_side_positive_z_crush_m
		if side_sign == 0.0:
			continue
		var side_weight := clampf(absf(reference_local.z) / half_width, 0.0, 1.0)
		var longitudinal_weight := 1.0 - clampf(absf(reference_local.x - safety_cell_base_position_m.x) / (half_length + 0.35), 0.0, 1.0)
		var weight := side_weight * (0.52 + 0.48 * longitudinal_weight)
		var current_local := rigid_chassis.to_local(model.nodes[index].position_m)
		var target_local := current_local
		var desired_z := reference_local.z - side_sign * crush * weight
		if side_sign > 0.0:
			target_local.z = minf(current_local.z, desired_z)
		else:
			target_local.z = maxf(current_local.z, desired_z)
		var upper := (index % 4) >= 2
		var desired_y := reference_local.y - crush * weight * (0.18 if upper else 0.045)
		target_local.y = minf(current_local.y, desired_y)
		var target_world := rigid_chassis.to_global(target_local)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(target_world, alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO
	_m18_update_side_collision_shape()

func _m17_update_rear_collision_shape() -> void:
	if hybrid_rear_impact_crush_m <= 0.0001 or safety_cell_collision == null or rigid_chassis == null:
		return
	var box := safety_cell_collision.shape as BoxShape3D
	if box == null:
		return
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := maxf(float(preset.get("scale_x", 1.0)), 0.55)
	var base_rear_x := safety_cell_base_position_m.x - safety_cell_base_size_m.x * 0.5
	var current_front_x := safety_cell_collision.position.x + box.size.x * 0.5
	var rear_face_x := base_rear_x + hybrid_rear_impact_crush_m * 0.62
	var minimum_length := 0.92 * scale_x
	rear_face_x = minf(rear_face_x, current_front_x - minimum_length)
	var new_size := box.size
	new_size.x = maxf(current_front_x - rear_face_x, minimum_length)
	box.size = new_size
	var new_position := safety_cell_collision.position
	new_position.x = (current_front_x + rear_face_x) * 0.5
	safety_cell_collision.position = new_position

func _m18_update_side_collision_shape() -> void:
	if safety_cell_collision == null:
		return
	var box := safety_cell_collision.shape as BoxShape3D
	if box == null:
		return
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_z := maxf(float(preset.get("scale_z", 1.0)), 0.55)
	var negative_face_z := safety_cell_base_position_m.z - safety_cell_base_size_m.z * 0.5
	var positive_face_z := safety_cell_base_position_m.z + safety_cell_base_size_m.z * 0.5
	negative_face_z += hybrid_side_negative_z_crush_m * 0.72
	positive_face_z -= hybrid_side_positive_z_crush_m * 0.72
	var minimum_width := 0.82 * scale_z
	if positive_face_z - negative_face_z < minimum_width:
		var centre := (positive_face_z + negative_face_z) * 0.5
		negative_face_z = centre - minimum_width * 0.5
		positive_face_z = centre + minimum_width * 0.5
	var new_size := box.size
	new_size.z = maxf(positive_face_z - negative_face_z, minimum_width)
	box.size = new_size
	var new_position := safety_cell_collision.position
	new_position.z = (positive_face_z + negative_face_z) * 0.5
	safety_cell_collision.position = new_position

func replay_visual_state() -> Dictionary:
	var state := super.replay_visual_state()
	state["hybrid_rear_impact_energy_j"] = hybrid_rear_impact_energy_j
	state["hybrid_rear_impact_crush_m"] = hybrid_rear_impact_crush_m
	state["hybrid_side_negative_z_energy_j"] = hybrid_side_negative_z_energy_j
	state["hybrid_side_positive_z_energy_j"] = hybrid_side_positive_z_energy_j
	state["hybrid_side_negative_z_crush_m"] = hybrid_side_negative_z_crush_m
	state["hybrid_side_positive_z_crush_m"] = hybrid_side_positive_z_crush_m
	return state

func apply_replay_visual_state(state: Dictionary) -> void:
	hybrid_rear_impact_energy_j = float(state.get("hybrid_rear_impact_energy_j", hybrid_rear_impact_energy_j))
	hybrid_rear_impact_crush_m = float(state.get("hybrid_rear_impact_crush_m", hybrid_rear_impact_crush_m))
	hybrid_side_negative_z_energy_j = float(state.get("hybrid_side_negative_z_energy_j", hybrid_side_negative_z_energy_j))
	hybrid_side_positive_z_energy_j = float(state.get("hybrid_side_positive_z_energy_j", hybrid_side_positive_z_energy_j))
	hybrid_side_negative_z_crush_m = float(state.get("hybrid_side_negative_z_crush_m", hybrid_side_negative_z_crush_m))
	hybrid_side_positive_z_crush_m = float(state.get("hybrid_side_positive_z_crush_m", hybrid_side_positive_z_crush_m))
	super.apply_replay_visual_state(state)
	_m17_update_rear_collision_shape()
	_m18_update_side_collision_shape()
