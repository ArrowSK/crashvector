# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M17CompactHatchback
extends M162CompactHatchback

# M17 keeps Godot RigidBody3D authoritative for whole-vehicle motion and extends
# the existing local-crush model to direct rear impacts. This is a generic
# educational deformation envelope, not manufacturer crash-test correlation.

var hybrid_rear_impact_energy_j: float = 0.0
var hybrid_rear_impact_crush_m: float = 0.0

func begin_simulation() -> void:
	hybrid_rear_impact_energy_j = 0.0
	hybrid_rear_impact_crush_m = 0.0
	super.begin_simulation()

func rear_impact_deformation_m() -> float:
	return hybrid_rear_impact_crush_m

func _consume_real_contact_impulses() -> void:
	if rigid_chassis == null:
		return
	var forward := rigid_chassis.global_transform.basis.x.normalized()
	for sample in rigid_chassis.drain_contact_samples():
		var collider_name: StringName = sample.get("collider_name", StringName(""))
		if collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround":
			continue
		var impulse: Vector3 = sample.get("impulse", Vector3.ZERO)
		hybrid_crush_impulse_ns += impulse.length()
		var local_position: Vector3 = sample.get("position_local", sample.get("position_world", Vector3.ZERO))
		# The protected-cell rigid volume spans the middle of the car. Contacts on
		# its rear third are direct rear impacts; front impacts remain governed by
		# the established M12/M13 forward probe and staged crush path.
		if local_position.x > -0.55:
			continue
		var collider: Object = sample.get("collider", null)
		var other_velocity := Vector3.ZERO
		var other_mass := rigid_chassis.mass
		if collider is RigidBody3D:
			var other := collider as RigidBody3D
			other_velocity = other.linear_velocity
			other_mass = maxf(other.mass, 1.0)
		var closing_speed := maxf((other_velocity - rigid_chassis.linear_velocity).dot(forward), 0.0)
		if closing_speed <= 0.05:
			# Head-on/reversed geometry can produce the opposite sign. Contact-side
			# classification is authoritative, so retain the longitudinal magnitude.
			closing_speed = absf((other_velocity - rigid_chassis.linear_velocity).dot(forward))
		var reduced_mass := rigid_chassis.mass * other_mass / maxf(rigid_chassis.mass + other_mass, 1.0)
		var energy := 0.5 * reduced_mass * closing_speed * closing_speed
		hybrid_rear_impact_energy_j = maxf(hybrid_rear_impact_energy_j, energy)

	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var stiffness_scale := maxf(float(preset.get("stiffness_scale", 1.0)), 0.45)
	var mass_scale := sqrt(maxf(total_mass_kg / 1150.0, 0.45))
	var scale_x := maxf(float(preset.get("scale_x", 1.0)), 0.55)
	var demanded := _m17_rear_energy_limited_crush_m(hybrid_rear_impact_energy_j, stiffness_scale * mass_scale)
	hybrid_rear_impact_crush_m = maxf(hybrid_rear_impact_crush_m, minf(demanded, 0.64 * scale_x))

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

func _enforce_hybrid_crush_shape(delta: float) -> void:
	super._enforce_hybrid_crush_shape(delta)
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

func _m17_update_rear_collision_shape() -> void:
	if safety_cell_collision == null or rigid_chassis == null:
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

func replay_visual_state() -> Dictionary:
	var state := super.replay_visual_state()
	state["hybrid_rear_impact_energy_j"] = hybrid_rear_impact_energy_j
	state["hybrid_rear_impact_crush_m"] = hybrid_rear_impact_crush_m
	return state

func apply_replay_visual_state(state: Dictionary) -> void:
	hybrid_rear_impact_energy_j = float(state.get("hybrid_rear_impact_energy_j", hybrid_rear_impact_energy_j))
	hybrid_rear_impact_crush_m = float(state.get("hybrid_rear_impact_crush_m", hybrid_rear_impact_crush_m))
	super.apply_replay_visual_state(state)
	_m17_update_rear_collision_shape()
