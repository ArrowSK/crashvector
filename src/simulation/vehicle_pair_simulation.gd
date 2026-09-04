# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehiclePairSimulation
extends RefCounted

var vehicle_model: StructuralModel
var truck_model: StructuralModel
var vehicle_contact_nodes := PackedInt32Array()
var truck_contact_nodes := PackedInt32Array()
var contact_normal := Vector3.RIGHT
var contact := VehiclePairContact.new()
var elapsed_s: float = 0.0
var initial_energy_j: float = 0.0
var initial_momentum_kg_ms := Vector3.ZERO

func configure(
	car: StructuralModel,
	car_contact_nodes: PackedInt32Array,
	truck: StructuralModel,
	truck_rear_contact_nodes: PackedInt32Array,
	normal: Vector3 = Vector3.RIGHT,
	friction_coefficient: float = 0.55,
	restitution: float = 0.03
) -> void:
	vehicle_model = car
	truck_model = truck
	contact_normal = normal.normalized()
	if contact_normal.is_zero_approx():
		contact_normal = Vector3.RIGHT
	vehicle_contact_nodes = _expand_contact_surface(vehicle_model, car_contact_nodes, contact_normal)
	var target_seed := _best_transverse_pair_order(
		vehicle_model,
		vehicle_contact_nodes,
		truck_model,
		truck_rear_contact_nodes,
		contact_normal
	)
	truck_contact_nodes = _expand_contact_surface(truck_model, target_seed, contact_normal)
	vehicle_model.barrier_enabled = false
	truck_model.barrier_enabled = false
	initial_energy_j = vehicle_model.initial_energy_j + truck_model.initial_energy_j
	initial_momentum_kg_ms = vehicle_model.total_momentum_kg_ms() + truck_model.total_momentum_kg_ms()
	elapsed_s = 0.0
	contact = VehiclePairContact.new()
	contact.friction_coefficient = clampf(friction_coefficient, 0.0, 1.5)
	contact.restitution = clampf(restitution, 0.0, 0.5)
	contact.damping_ratio = VehiclePairContact.damping_ratio_for_restitution(contact.restitution)

func step(delta_s: float, substeps: int = 8) -> void:
	if delta_s <= 0.0 or vehicle_model == null or truck_model == null:
		return
	var count := maxi(substeps, 1)
	var h := delta_s / float(count)
	for _substep in range(count):
		vehicle_model.prepare_substep(h)
		truck_model.prepare_substep(h)
		contact.apply_forces(
			vehicle_model,
			vehicle_contact_nodes,
			truck_model,
			truck_contact_nodes,
			contact_normal,
			h,
			elapsed_s
		)
		vehicle_model.integrate_substep(h)
		truck_model.integrate_substep(h)
		elapsed_s += h

func closing_speed_kmh() -> float:
	if vehicle_model == null or truck_model == null:
		return 0.0
	var relative_velocity := vehicle_model.average_velocity_ms() - truck_model.average_velocity_ms()
	return PhysicsMetrics.ms_to_kmh(maxf(relative_velocity.dot(contact_normal), 0.0))

func current_total_momentum_kg_ms() -> Vector3:
	return vehicle_model.total_momentum_kg_ms() + truck_model.total_momentum_kg_ms()

func momentum_error_kg_ms() -> float:
	return (current_total_momentum_kg_ms() - initial_momentum_kg_ms).length()

func accounted_energy_j() -> float:
	return (
		vehicle_model.accounted_energy_j()
		+ truck_model.accounted_energy_j()
		+ contact.accumulated_dissipation_j
		+ contact.current_contact_energy_j
	)

func energy_balance_relative_error() -> float:
	if initial_energy_j <= 0.0:
		return 0.0
	return absf(initial_energy_j - accounted_energy_j()) / initial_energy_j

func _expand_contact_surface(
	model: StructuralModel,
	seed_indices: PackedInt32Array,
	normal: Vector3
) -> PackedInt32Array:
	if model == null or seed_indices.is_empty():
		return seed_indices.duplicate()
	var reference_projection := 0.0
	var reference_center := Vector3.ZERO
	var valid_count := 0
	for index in seed_indices:
		if not _valid_index(model, index):
			continue
		reference_projection += model.nodes[index].position_m.dot(normal)
		reference_center += model.nodes[index].position_m
		valid_count += 1
	if valid_count <= 0:
		return seed_indices.duplicate()
	reference_projection /= float(valid_count)
	reference_center /= float(valid_count)

	var expanded := PackedInt32Array()
	for index in range(model.nodes.size()):
		var position := model.nodes[index].position_m
		if absf(position.dot(normal) - reference_projection) > 0.075:
			continue
		var delta := position - reference_center
		var tangent := delta - normal * delta.dot(normal)
		if tangent.length() > 2.25:
			continue
		expanded.append(index)
	return seed_indices.duplicate() if expanded.is_empty() else expanded

func _best_transverse_pair_order(
	model_a: StructuralModel,
	indices_a: PackedInt32Array,
	model_b: StructuralModel,
	indices_b: PackedInt32Array,
	normal: Vector3
) -> PackedInt32Array:
	var result := indices_b.duplicate()
	if indices_a.size() != 2 or indices_b.size() != 2:
		return result
	if not _valid_index(model_a, indices_a[0]) or not _valid_index(model_a, indices_a[1]):
		return result
	if not _valid_index(model_b, indices_b[0]) or not _valid_index(model_b, indices_b[1]):
		return result
	var direct_score := (
		_transverse_distance_squared(model_a.nodes[indices_a[0]].position_m, model_b.nodes[indices_b[0]].position_m, normal)
		+ _transverse_distance_squared(model_a.nodes[indices_a[1]].position_m, model_b.nodes[indices_b[1]].position_m, normal)
	)
	var reversed_score := (
		_transverse_distance_squared(model_a.nodes[indices_a[0]].position_m, model_b.nodes[indices_b[1]].position_m, normal)
		+ _transverse_distance_squared(model_a.nodes[indices_a[1]].position_m, model_b.nodes[indices_b[0]].position_m, normal)
	)
	if reversed_score + 0.000001 < direct_score:
		result[0] = indices_b[1]
		result[1] = indices_b[0]
	return result

func _transverse_distance_squared(a: Vector3, b: Vector3, normal: Vector3) -> float:
	var delta := b - a
	var tangent := delta - normal * delta.dot(normal)
	return tangent.length_squared()

func _valid_index(model: StructuralModel, index: int) -> bool:
	return model != null and index >= 0 and index < model.nodes.size()
