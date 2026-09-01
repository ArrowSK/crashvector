# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehiclePairContact
extends RefCounted

var restitution: float = 0.03
var tangent_contact_radius_m: float = 0.80
var position_correction_fraction: float = 0.85
var penetration_slop_m: float = 0.001
var contact_events: int = 0
var first_contact_time_s: float = -1.0
var accumulated_dissipation_j: float = 0.0
var maximum_penetration_m: float = 0.0

func resolve_pairs(
	model_a: StructuralModel,
	indices_a: PackedInt32Array,
	model_b: StructuralModel,
	indices_b: PackedInt32Array,
	normal: Vector3,
	elapsed_s: float
) -> void:
	if model_a == null or model_b == null:
		return
	var n := normal.normalized()
	if n.is_zero_approx():
		n = Vector3.RIGHT
	var count := mini(indices_a.size(), indices_b.size())
	for i in range(count):
		var index_a := indices_a[i]
		var index_b := indices_b[i]
		if index_a < 0 or index_a >= model_a.nodes.size() or index_b < 0 or index_b >= model_b.nodes.size():
			continue
		var a := model_a.nodes[index_a]
		var b := model_b.nodes[index_b]
		var delta := b.position_m - a.position_m
		var normal_gap := delta.dot(n)
		if normal_gap >= 0.0:
			continue
		var tangent_delta := delta - n * normal_gap
		if tangent_delta.length() > tangent_contact_radius_m:
			continue
		var penetration := -normal_gap
		maximum_penetration_m = maxf(maximum_penetration_m, penetration)
		var inverse_mass_sum := a.inverse_mass + b.inverse_mass
		if inverse_mass_sum <= 0.0:
			continue

		var relative_closing_speed := (a.velocity_ms - b.velocity_ms).dot(n)
		if relative_closing_speed > 0.0:
			var before_j := a.kinetic_energy_j() + b.kinetic_energy_j()
			var impulse_ns := (1.0 + clampf(restitution, 0.0, 1.0)) * relative_closing_speed / inverse_mass_sum
			a.velocity_ms -= n * impulse_ns * a.inverse_mass
			b.velocity_ms += n * impulse_ns * b.inverse_mass
			var after_j := a.kinetic_energy_j() + b.kinetic_energy_j()
			accumulated_dissipation_j += maxf(before_j - after_j, 0.0)
			contact_events += 1
			if first_contact_time_s < 0.0:
				first_contact_time_s = elapsed_s

		var correction_depth := maxf(penetration - penetration_slop_m, 0.0)
		if correction_depth > 0.0:
			var correction := n * correction_depth * clampf(position_correction_fraction, 0.0, 1.0) / inverse_mass_sum
			if not a.pinned:
				a.position_m -= correction * a.inverse_mass
			if not b.pinned:
				b.position_m += correction * b.inverse_mass
