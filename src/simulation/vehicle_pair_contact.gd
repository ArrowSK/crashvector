# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehiclePairContact
extends RefCounted

var restitution: float = 0.03
var friction_coefficient: float = 0.55
var tangent_contact_radius_m: float = 1.25
var normal_stiffness_n_m: float = 3000000.0
var damping_ratio: float = 0.75
var maximum_force_per_pair_n: float = 1000000.0
var emergency_penetration_m: float = 0.35
var emergency_position_fraction: float = 0.015
var contact_events: int = 0
var active_contacts: int = 0
var first_contact_time_s: float = -1.0
var accumulated_dissipation_j: float = 0.0
var current_contact_energy_j: float = 0.0
var maximum_penetration_m: float = 0.0

static func damping_ratio_for_restitution(coefficient: float) -> float:
	var e := clampf(coefficient, 0.0001, 0.9999)
	var log_e := log(e)
	return clampf(-log_e / sqrt(PI * PI + log_e * log_e), 0.0, 1.0)

func apply_forces(
	model_a: StructuralModel,
	indices_a: PackedInt32Array,
	model_b: StructuralModel,
	indices_b: PackedInt32Array,
	normal: Vector3,
	delta_s: float,
	elapsed_s: float
) -> void:
	current_contact_energy_j = 0.0
	active_contacts = 0
	if model_a == null or model_b == null or delta_s <= 0.0:
		return
	var n := normal.normalized()
	if n.is_zero_approx():
		n = Vector3.RIGHT

	var used_b: Dictionary = {}
	for index_a in indices_a:
		if not _valid_index(model_a, index_a):
			continue
		var best_index_b := -1
		var best_tangent_distance_sq := INF
		for index_b in indices_b:
			if used_b.has(index_b) or not _valid_index(model_b, index_b):
				continue
			var delta := model_b.nodes[index_b].position_m - model_a.nodes[index_a].position_m
			var normal_gap := delta.dot(n)
			if normal_gap >= 0.0:
				continue
			var tangent_delta := delta - n * normal_gap
			var tangent_distance_sq := tangent_delta.length_squared()
			if tangent_distance_sq > tangent_contact_radius_m * tangent_contact_radius_m:
				continue
			if tangent_distance_sq < best_tangent_distance_sq:
				best_tangent_distance_sq = tangent_distance_sq
				best_index_b = index_b
		if best_index_b < 0:
			continue
		used_b[best_index_b] = true
		_apply_pair_force(model_a.nodes[index_a], model_b.nodes[best_index_b], n, delta_s, elapsed_s)

func resolve_pairs(
	model_a: StructuralModel,
	indices_a: PackedInt32Array,
	model_b: StructuralModel,
	indices_b: PackedInt32Array,
	normal: Vector3,
	elapsed_s: float
) -> void:
	apply_forces(model_a, indices_a, model_b, indices_b, normal, 1.0 / 240.0, elapsed_s)

func _apply_pair_force(a: StructuralNode, b: StructuralNode, normal: Vector3, delta_s: float, elapsed_s: float) -> void:
	var delta := b.position_m - a.position_m
	var normal_gap := delta.dot(normal)
	if normal_gap >= 0.0:
		return
	var penetration := -normal_gap
	maximum_penetration_m = maxf(maximum_penetration_m, penetration)
	var inverse_mass_sum := a.inverse_mass + b.inverse_mass
	if inverse_mass_sum <= 0.0:
		return
	var effective_mass := 1.0 / inverse_mass_sum
	var relative_velocity := a.velocity_ms - b.velocity_ms
	var relative_normal_speed := relative_velocity.dot(normal)
	var spring_force := normal_stiffness_n_m * penetration
	var critical_damping := 2.0 * sqrt(maxf(normal_stiffness_n_m * effective_mass, 0.0))
	var damping_coefficient := critical_damping * clampf(damping_ratio, 0.0, 1.0)
	# Positive relative normal speed is closing and adds damping. Negative speed
	# is separation and reduces the spring release.
	var raw_damping_force_signed := damping_coefficient * relative_normal_speed
	var damping_force_signed := raw_damping_force_signed
	if absf(relative_normal_speed) > 0.000001:
		var maximum_damping_force := effective_mass * absf(relative_normal_speed) / delta_s
		damping_force_signed = clampf(raw_damping_force_signed, -maximum_damping_force, maximum_damping_force)
	var requested_force := spring_force + damping_force_signed
	var normal_force := clampf(requested_force, 0.0, maximum_force_per_pair_n)
	var force_scale := 0.0
	if requested_force > 0.000001:
		force_scale = normal_force / requested_force
	var applied_spring_force := spring_force * force_scale
	var applied_damping_force_signed := damping_force_signed * force_scale

	a.add_force(-normal * normal_force)
	b.add_force(normal * normal_force)
	current_contact_energy_j += 0.5 * applied_spring_force * penetration
	if absf(relative_normal_speed) > 0.000001:
		var damping_only_after_speed := relative_normal_speed - applied_damping_force_signed * inverse_mass_sum * delta_s
		accumulated_dissipation_j += maxf(
			0.5 * effective_mass * (relative_normal_speed * relative_normal_speed - damping_only_after_speed * damping_only_after_speed),
			0.0
		)
	active_contacts += 1
	contact_events += 1
	if first_contact_time_s < 0.0:
		first_contact_time_s = elapsed_s

	var tangent_velocity := relative_velocity - normal * relative_normal_speed
	var tangent_speed := tangent_velocity.length()
	if tangent_speed > 0.000001 and friction_coefficient > 0.0:
		var tangent_direction := tangent_velocity / tangent_speed
		var desired_friction_force := effective_mass * tangent_speed / maxf(delta_s, 0.000001)
		var friction_force := minf(desired_friction_force, friction_coefficient * normal_force)
		a.add_force(-tangent_direction * friction_force)
		b.add_force(tangent_direction * friction_force)
		var tangent_after_speed := maxf(tangent_speed - friction_force * inverse_mass_sum * delta_s, 0.0)
		accumulated_dissipation_j += maxf(
			0.5 * effective_mass * (tangent_speed * tangent_speed - tangent_after_speed * tangent_after_speed),
			0.0
		)

	if penetration > emergency_penetration_m:
		var correction_depth := (penetration - emergency_penetration_m) * clampf(emergency_position_fraction, 0.0, 0.05)
		var correction := normal * correction_depth / inverse_mass_sum
		if not a.pinned:
			a.position_m -= correction * a.inverse_mass
		if not b.pinned:
			b.position_m += correction * b.inverse_mass

func _valid_index(model: StructuralModel, index: int) -> bool:
	return model != null and index >= 0 and index < model.nodes.size()
