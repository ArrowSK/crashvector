# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralModel
extends RefCounted

var nodes: Array[StructuralNode] = []
var beams: Array[StructuralBeam] = []
var barrier_enabled: bool = true
var barrier_x_m: float = 5.0
var barrier_restitution: float = 0.0
var barrier_tangent_retention: float = 0.92
var elapsed_s: float = 0.0
var first_contact_time_s: float = -1.0
var contact_events: int = 0
var contact_dissipation_j: float = 0.0
var initial_energy_j: float = 0.0

func add_node(position_m: Vector3, mass_kg: float, pinned: bool = false) -> int:
	nodes.append(StructuralNode.new(position_m, mass_kg, pinned))
	return nodes.size() - 1

func add_beam(
	index_a: int,
	index_b: int,
	role: StringName,
	stiffness_n_m: float,
	damping_n_s_m: float,
	yield_strain: float,
	max_plastic_strain: float,
	break_strain: float,
	plastic_flow_rate: float
) -> StructuralBeam:
	var beam := StructuralBeam.new(
		index_a,
		index_b,
		nodes,
		role,
		stiffness_n_m,
		damping_n_s_m,
		yield_strain,
		max_plastic_strain,
		break_strain,
		plastic_flow_rate
	)
	beams.append(beam)
	return beam

func set_uniform_velocity(velocity_ms: Vector3) -> void:
	for node in nodes:
		if not node.pinned:
			node.velocity_ms = velocity_ms
	capture_initial_energy()

func translate_all_nodes(offset_m: Vector3) -> void:
	if offset_m.is_zero_approx():
		return
	for node in nodes:
		node.position_m += offset_m

func rotate_y_about(pivot_m: Vector3, angle_rad: float, rotate_velocities: bool = true) -> void:
	if is_zero_approx(angle_rad):
		return
	var basis := Basis(Vector3.UP, angle_rad)
	for node in nodes:
		node.position_m = pivot_m + basis * (node.position_m - pivot_m)
		if rotate_velocities:
			node.velocity_ms = basis * node.velocity_ms
	capture_initial_energy()

func capture_initial_energy() -> void:
	initial_energy_j = total_kinetic_energy_j() + total_elastic_energy_j()

func step(delta_s: float, substeps: int = 4) -> void:
	if delta_s <= 0.0:
		return
	var step_count := maxi(substeps, 1)
	var h := delta_s / float(step_count)
	for _substep in range(step_count):
		for node in nodes:
			node.reset_force()
		for beam in beams:
			beam.solve(nodes, h)
		for node in nodes:
			node.integrate(h)
		_resolve_barrier_contacts()
		elapsed_s += h

func _resolve_barrier_contacts() -> void:
	if not barrier_enabled:
		return
	for node in nodes:
		if node.pinned or node.position_m.x <= barrier_x_m:
			continue
		var before_j := node.kinetic_energy_j()
		node.position_m.x = barrier_x_m
		if node.velocity_ms.x > 0.0:
			node.velocity_ms.x = -node.velocity_ms.x * clampf(barrier_restitution, 0.0, 1.0)
			node.velocity_ms.y *= clampf(barrier_tangent_retention, 0.0, 1.0)
			node.velocity_ms.z *= clampf(barrier_tangent_retention, 0.0, 1.0)
			var after_j := node.kinetic_energy_j()
			contact_dissipation_j += maxf(before_j - after_j, 0.0)
			contact_events += 1
			if first_contact_time_s < 0.0:
				first_contact_time_s = elapsed_s

func total_mass_kg() -> float:
	var result := 0.0
	for node in nodes:
		result += node.mass_kg
	return result

func center_of_mass_m() -> Vector3:
	var weighted := Vector3.ZERO
	var total_mass := 0.0
	for node in nodes:
		weighted += node.position_m * node.mass_kg
		total_mass += node.mass_kg
	if total_mass <= 0.0:
		return Vector3.ZERO
	return weighted / total_mass

func average_velocity_ms() -> Vector3:
	var momentum := total_momentum_kg_ms()
	var total_mass := total_mass_kg()
	if total_mass <= 0.0:
		return Vector3.ZERO
	return momentum / total_mass

func total_momentum_kg_ms() -> Vector3:
	var momentum := Vector3.ZERO
	for node in nodes:
		momentum += node.velocity_ms * node.mass_kg
	return momentum

func average_position_for_nodes(indices: PackedInt32Array) -> Vector3:
	if indices.is_empty():
		return Vector3.ZERO
	var result := Vector3.ZERO
	var count := 0
	for index in indices:
		if index < 0 or index >= nodes.size():
			continue
		result += nodes[index].position_m
		count += 1
	return Vector3.ZERO if count == 0 else result / float(count)

func average_velocity_for_nodes(indices: PackedInt32Array) -> Vector3:
	if indices.is_empty():
		return Vector3.ZERO
	var weighted := Vector3.ZERO
	var total_mass := 0.0
	for index in indices:
		if index < 0 or index >= nodes.size():
			continue
		weighted += nodes[index].velocity_ms * nodes[index].mass_kg
		total_mass += nodes[index].mass_kg
	return Vector3.ZERO if total_mass <= 0.0 else weighted / total_mass

func total_kinetic_energy_j() -> float:
	var result := 0.0
	for node in nodes:
		result += node.kinetic_energy_j()
	return result

func total_elastic_energy_j() -> float:
	var result := 0.0
	for beam in beams:
		result += beam.elastic_energy_j(nodes)
	return result

func total_plastic_energy_j() -> float:
	var result := 0.0
	for beam in beams:
		result += beam.plastic_energy_j
	return result

func total_damping_energy_j() -> float:
	var result := 0.0
	for beam in beams:
		result += beam.damping_energy_j
	return result

func total_fracture_energy_j() -> float:
	var result := 0.0
	for beam in beams:
		result += beam.fracture_energy_j
	return result

func accounted_energy_j() -> float:
	return (
		total_kinetic_energy_j()
		+ total_elastic_energy_j()
		+ total_plastic_energy_j()
		+ total_damping_energy_j()
		+ total_fracture_energy_j()
		+ contact_dissipation_j
	)

func energy_balance_error_j() -> float:
	return initial_energy_j - accounted_energy_j()

func energy_balance_relative_error() -> float:
	if initial_energy_j <= 0.0:
		return 0.0
	return absf(energy_balance_error_j()) / initial_energy_j

func role_beam_count(role: StringName) -> int:
	var result := 0
	for beam in beams:
		if beam.role == role:
			result += 1
	return result

func broken_beam_count() -> int:
	var result := 0
	for beam in beams:
		if beam.broken:
			result += 1
	return result

func broken_beam_count_for_role(role: StringName) -> int:
	var result := 0
	for beam in beams:
		if beam.role == role and beam.broken:
			result += 1
	return result

func max_absolute_strain() -> float:
	var result := 0.0
	for beam in beams:
		result = maxf(result, absf(beam.last_total_strain))
	return result

func max_absolute_strain_for_role(role: StringName) -> float:
	var result := 0.0
	for beam in beams:
		if beam.role == role:
			result = maxf(result, absf(beam.last_total_strain))
	return result

func max_permanent_deformation_m() -> float:
	var result := 0.0
	for beam in beams:
		result = maxf(result, absf(beam.permanent_deformation_m()))
	return result

func max_permanent_deformation_for_role(role: StringName) -> float:
	var result := 0.0
	for beam in beams:
		if beam.role == role:
			result = maxf(result, absf(beam.permanent_deformation_m()))
	return result

func state_signature() -> PackedFloat64Array:
	var signature := PackedFloat64Array()
	for node in nodes:
		signature.append(node.position_m.x)
		signature.append(node.position_m.y)
		signature.append(node.position_m.z)
		signature.append(node.velocity_ms.x)
		signature.append(node.velocity_ms.y)
		signature.append(node.velocity_ms.z)
	for beam in beams:
		signature.append(beam.rest_length_m)
		signature.append(1.0 if beam.broken else 0.0)
	return signature
