# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralBeam
extends RefCounted

var node_a: int
var node_b: int
var role: StringName
var original_rest_length_m: float
var rest_length_m: float
var stiffness_n_m: float
var damping_n_s_m: float
var yield_strain: float
var max_plastic_strain: float
var break_strain: float
var plastic_flow_rate: float
var broken: bool = false
var last_force_n: float = 0.0
var last_total_strain: float = 0.0
var plastic_energy_j: float = 0.0
var damping_energy_j: float = 0.0
var fracture_energy_j: float = 0.0

func _init(
	index_a: int,
	index_b: int,
	nodes: Array[StructuralNode],
	beam_role: StringName = &"generic",
	beam_stiffness_n_m: float = 1000000.0,
	beam_damping_n_s_m: float = 3000.0,
	beam_yield_strain: float = 0.05,
	beam_max_plastic_strain: float = 0.45,
	beam_break_strain: float = 0.65,
	beam_plastic_flow_rate: float = 12.0
) -> void:
	node_a = index_a
	node_b = index_b
	role = beam_role
	stiffness_n_m = maxf(beam_stiffness_n_m, 1.0)
	damping_n_s_m = maxf(beam_damping_n_s_m, 0.0)
	yield_strain = maxf(beam_yield_strain, 0.0)
	max_plastic_strain = maxf(beam_max_plastic_strain, yield_strain)
	break_strain = maxf(beam_break_strain, max_plastic_strain + 0.001)
	plastic_flow_rate = maxf(beam_plastic_flow_rate, 0.0)
	original_rest_length_m = maxf(
		(nodes[node_b].position_m - nodes[node_a].position_m).length(),
		0.0001
	)
	rest_length_m = original_rest_length_m

func solve(nodes: Array[StructuralNode], delta_s: float) -> void:
	if broken or delta_s <= 0.0:
		return
	var a := nodes[node_a]
	var b := nodes[node_b]
	var delta := b.position_m - a.position_m
	var length_m := delta.length()
	if length_m <= 0.000001:
		return

	var direction := delta / length_m
	last_total_strain = (length_m - original_rest_length_m) / original_rest_length_m

	if absf(last_total_strain) >= break_strain:
		fracture_energy_j += elastic_energy_j(nodes)
		broken = true
		last_force_n = 0.0
		return

	var relative_speed_ms := (b.velocity_ms - a.velocity_ms).dot(direction)
	var elastic_extension_m := length_m - rest_length_m
	var spring_force_n := stiffness_n_m * elastic_extension_m
	var damping_force_n := damping_n_s_m * relative_speed_ms
	last_force_n = spring_force_n + damping_force_n

	var force_vector := direction * last_force_n
	a.add_force(force_vector)
	b.add_force(-force_vector)
	damping_energy_j += damping_n_s_m * relative_speed_ms * relative_speed_ms * delta_s

	_apply_plastic_flow(length_m, spring_force_n, delta_s)

func _apply_plastic_flow(length_m: float, spring_force_n: float, delta_s: float) -> void:
	var abs_strain := absf(last_total_strain)
	if abs_strain <= yield_strain or plastic_flow_rate <= 0.0:
		return

	var minimum_rest := original_rest_length_m * (1.0 - max_plastic_strain)
	var maximum_rest := original_rest_length_m * (1.0 + max_plastic_strain)
	var target_rest := clampf(length_m, minimum_rest, maximum_rest)
	var flow_span := maxf(max_plastic_strain - yield_strain, 0.0001)
	var flow_factor := clampf((abs_strain - yield_strain) / flow_span, 0.0, 1.0)
	var alpha := clampf(plastic_flow_rate * flow_factor * delta_s, 0.0, 1.0)
	var old_rest := rest_length_m
	rest_length_m = lerpf(rest_length_m, target_rest, alpha)
	plastic_energy_j += absf(spring_force_n) * absf(rest_length_m - old_rest)

func elastic_energy_j(nodes: Array[StructuralNode]) -> float:
	if broken:
		return 0.0
	var length_m := (nodes[node_b].position_m - nodes[node_a].position_m).length()
	var extension_m := length_m - rest_length_m
	return 0.5 * stiffness_n_m * extension_m * extension_m

func permanent_strain() -> float:
	return (rest_length_m - original_rest_length_m) / original_rest_length_m

func permanent_deformation_m() -> float:
	return rest_length_m - original_rest_length_m
