# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralLongitudinalGuard
extends RefCounted

# A unilateral group constraint for protected structural cells. Ordinary axial
# beams measure unsigned distance: if two bulkheads numerically pass through
# one another, those beams can re-expand in the inverted order. This guard
# preserves the initial signed longitudinal ordering without making the cell
# rigid. It is dormant until the protected span has compressed beyond a large
# allowed fraction, then behaves as a capped spring/damper bottoming response.

var rear_indices := PackedInt32Array()
var front_indices := PackedInt32Array()
var forward_axis := Vector3.RIGHT
var original_span_m: float = 1.0
var minimum_span_ratio: float = 0.70
var stiffness_n_m: float = 4000000.0
var damping_n_s_m: float = 45000.0
var maximum_force_n: float = 2000000.0
var current_compression_m: float = 0.0
var minimum_observed_span_m: float = INF
var damping_energy_j: float = 0.0

func _init(
	rear_nodes: PackedInt32Array,
	front_nodes: PackedInt32Array,
	nodes: Array[StructuralNode],
	min_span_ratio: float = 0.70,
	constraint_stiffness_n_m: float = 4000000.0,
	constraint_damping_n_s_m: float = 45000.0,
	constraint_maximum_force_n: float = 2000000.0
) -> void:
	rear_indices = rear_nodes.duplicate()
	front_indices = front_nodes.duplicate()
	minimum_span_ratio = clampf(min_span_ratio, 0.20, 0.95)
	stiffness_n_m = maxf(constraint_stiffness_n_m, 0.0)
	damping_n_s_m = maxf(constraint_damping_n_s_m, 0.0)
	maximum_force_n = maxf(constraint_maximum_force_n, 0.0)
	var rear := _average_position(nodes, rear_indices)
	var front := _average_position(nodes, front_indices)
	var span_vector := front - rear
	if span_vector.length_squared() > 0.000001:
		forward_axis = span_vector.normalized()
	original_span_m = maxf(span_vector.dot(forward_axis), 0.001)
	minimum_observed_span_m = original_span_m

func solve(nodes: Array[StructuralNode], delta_s: float) -> void:
	if delta_s <= 0.0 or rear_indices.is_empty() or front_indices.is_empty():
		return
	var rear := _average_position(nodes, rear_indices)
	var front := _average_position(nodes, front_indices)
	var signed_span := (front - rear).dot(forward_axis)
	minimum_observed_span_m = minf(minimum_observed_span_m, signed_span)
	var minimum_span := original_span_m * minimum_span_ratio
	current_compression_m = maxf(minimum_span - signed_span, 0.0)
	if current_compression_m <= 0.0:
		return

	var rear_velocity := _average_velocity(nodes, rear_indices)
	var front_velocity := _average_velocity(nodes, front_indices)
	var span_rate := (front_velocity - rear_velocity).dot(forward_axis)
	var closing_speed := maxf(-span_rate, 0.0)
	var spring_force := stiffness_n_m * current_compression_m
	var damping_force := damping_n_s_m * closing_speed
	var requested_force := spring_force + damping_force
	var total_force := minf(requested_force, maximum_force_n)
	if total_force <= 0.0:
		return
	var force_scale := total_force / maxf(requested_force, 0.000001)
	var applied_damping_force := damping_force * force_scale

	_distribute_force(nodes, front_indices, forward_axis * total_force)
	_distribute_force(nodes, rear_indices, -forward_axis * total_force)
	damping_energy_j += applied_damping_force * closing_speed * delta_s

func rotate_y(angle_rad: float) -> void:
	if is_zero_approx(angle_rad):
		return
	forward_axis = (Basis(Vector3.UP, angle_rad) * forward_axis).normalized()

func signed_span_m(nodes: Array[StructuralNode]) -> float:
	return (_average_position(nodes, front_indices) - _average_position(nodes, rear_indices)).dot(forward_axis)

func span_ratio(nodes: Array[StructuralNode]) -> float:
	return signed_span_m(nodes) / maxf(original_span_m, 0.001)

func elastic_energy_j(nodes: Array[StructuralNode]) -> float:
	var minimum_span := original_span_m * minimum_span_ratio
	var compression := maxf(minimum_span - signed_span_m(nodes), 0.0)
	if compression <= 0.0:
		return 0.0
	var spring_force := minf(stiffness_n_m * compression, maximum_force_n)
	return 0.5 * spring_force * compression

func _distribute_force(nodes: Array[StructuralNode], indices: PackedInt32Array, force_n: Vector3) -> void:
	var valid_count := 0
	for index in indices:
		if index >= 0 and index < nodes.size() and not nodes[index].pinned:
			valid_count += 1
	if valid_count <= 0:
		return
	var share := force_n / float(valid_count)
	for index in indices:
		if index >= 0 and index < nodes.size():
			nodes[index].add_force(share)

func _average_position(nodes: Array[StructuralNode], indices: PackedInt32Array) -> Vector3:
	var result := Vector3.ZERO
	var count := 0
	for index in indices:
		if index < 0 or index >= nodes.size():
			continue
		result += nodes[index].position_m
		count += 1
	return Vector3.ZERO if count == 0 else result / float(count)

func _average_velocity(nodes: Array[StructuralNode], indices: PackedInt32Array) -> Vector3:
	var weighted := Vector3.ZERO
	var mass := 0.0
	for index in indices:
		if index < 0 or index >= nodes.size():
			continue
		var node := nodes[index]
		weighted += node.velocity_ms * node.mass_kg
		mass += node.mass_kg
	return Vector3.ZERO if mass <= 0.0 else weighted / mass
