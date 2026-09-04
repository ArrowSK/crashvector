# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralBendingConstraint
extends RefCounted

var node_a: int
var node_b: int
var node_c: int
var role: StringName = &"bending"
var component: StringName = &""
var original_rest_angle_rad: float = 0.0
var rest_angle_rad: float = 0.0
var stiffness_nm_rad: float = 12000.0
var damping_nm_s_rad: float = 350.0
var yield_angle_rad: float = deg_to_rad(8.0)
var max_plastic_angle_rad: float = deg_to_rad(55.0)
var break_angle_rad: float = deg_to_rad(105.0)
var plastic_flow_rate: float = 12.0
var broken: bool = false
var last_angle_rad: float = 0.0
var last_angle_error_rad: float = 0.0
var last_generalized_torque_nm: float = 0.0
var plastic_energy_j: float = 0.0
var damping_energy_j: float = 0.0
var fracture_energy_j: float = 0.0

func _init(
	index_a: int,
	index_b: int,
	index_c: int,
	nodes: Array[StructuralNode],
	constraint_role: StringName = &"bending",
	constraint_stiffness_nm_rad: float = 12000.0,
	constraint_damping_nm_s_rad: float = 350.0,
	constraint_yield_angle_rad: float = deg_to_rad(8.0),
	constraint_max_plastic_angle_rad: float = deg_to_rad(55.0),
	constraint_break_angle_rad: float = deg_to_rad(105.0),
	constraint_plastic_flow_rate: float = 12.0,
	constraint_component: StringName = &""
) -> void:
	node_a = index_a
	node_b = index_b
	node_c = index_c
	role = constraint_role
	component = constraint_component
	stiffness_nm_rad = maxf(constraint_stiffness_nm_rad, 0.0)
	damping_nm_s_rad = maxf(constraint_damping_nm_s_rad, 0.0)
	yield_angle_rad = maxf(constraint_yield_angle_rad, 0.0)
	max_plastic_angle_rad = maxf(constraint_max_plastic_angle_rad, yield_angle_rad)
	break_angle_rad = maxf(constraint_break_angle_rad, max_plastic_angle_rad + deg_to_rad(1.0))
	plastic_flow_rate = maxf(constraint_plastic_flow_rate, 0.0)
	original_rest_angle_rad = _current_angle(nodes)
	rest_angle_rad = original_rest_angle_rad
	last_angle_rad = original_rest_angle_rad

func solve(nodes: Array[StructuralNode], delta_s: float) -> void:
	if broken or delta_s <= 0.0:
		return
	if node_a < 0 or node_b < 0 or node_c < 0 or node_a >= nodes.size() or node_b >= nodes.size() or node_c >= nodes.size():
		return

	var a := nodes[node_a]
	var b := nodes[node_b]
	var c := nodes[node_c]
	var ab := a.position_m - b.position_m
	var cb := c.position_m - b.position_m
	var len_ab := ab.length()
	var len_cb := cb.length()
	if len_ab <= 0.00001 or len_cb <= 0.00001:
		return

	var u := ab / len_ab
	var v := cb / len_cb
	var cosine := clampf(u.dot(v), -0.99995, 0.99995)
	var angle := acos(cosine)
	var sine := maxf(sqrt(maxf(1.0 - cosine * cosine, 0.0)), 0.01)
	last_angle_rad = angle
	var total_change := angle - original_rest_angle_rad
	if absf(total_change) >= break_angle_rad:
		fracture_energy_j += elastic_energy_j(nodes)
		broken = true
		last_generalized_torque_nm = 0.0
		return

	var gradient_a := (v - u * cosine) / (len_ab * sine)
	var gradient_c := (u - v * cosine) / (len_cb * sine)
	var gradient_b := -(gradient_a + gradient_c)
	var angular_rate := (
		gradient_a.dot(a.velocity_ms)
		+ gradient_b.dot(b.velocity_ms)
		+ gradient_c.dot(c.velocity_ms)
	)
	last_angle_error_rad = angle - rest_angle_rad
	var generalized_torque := stiffness_nm_rad * last_angle_error_rad + damping_nm_s_rad * angular_rate
	last_generalized_torque_nm = generalized_torque

	a.add_force(-gradient_a * generalized_torque)
	b.add_force(-gradient_b * generalized_torque)
	c.add_force(-gradient_c * generalized_torque)
	damping_energy_j += damping_nm_s_rad * angular_rate * angular_rate * delta_s
	_apply_plastic_flow(angle, generalized_torque, delta_s)

func _apply_plastic_flow(angle_rad: float, generalized_torque_nm: float, delta_s: float) -> void:
	var total_change := angle_rad - original_rest_angle_rad
	var abs_change := absf(total_change)
	if abs_change <= yield_angle_rad or plastic_flow_rate <= 0.0:
		return
	var minimum_rest := original_rest_angle_rad - max_plastic_angle_rad
	var maximum_rest := original_rest_angle_rad + max_plastic_angle_rad
	var target_rest := clampf(angle_rad, minimum_rest, maximum_rest)
	var flow_span := maxf(max_plastic_angle_rad - yield_angle_rad, deg_to_rad(0.1))
	var flow_factor := clampf((abs_change - yield_angle_rad) / flow_span, 0.0, 1.0)
	var alpha := clampf(plastic_flow_rate * flow_factor * delta_s, 0.0, 1.0)
	var old_rest := rest_angle_rad
	rest_angle_rad = lerpf(rest_angle_rad, target_rest, alpha)
	plastic_energy_j += absf(generalized_torque_nm) * absf(rest_angle_rad - old_rest)

func elastic_energy_j(nodes: Array[StructuralNode]) -> float:
	if broken:
		return 0.0
	var angle := _current_angle(nodes)
	var error := angle - rest_angle_rad
	return 0.5 * stiffness_nm_rad * error * error

func permanent_angle_rad() -> float:
	return rest_angle_rad - original_rest_angle_rad

func _current_angle(nodes: Array[StructuralNode]) -> float:
	if node_a < 0 or node_b < 0 or node_c < 0 or node_a >= nodes.size() or node_b >= nodes.size() or node_c >= nodes.size():
		return 0.0
	var ab := nodes[node_a].position_m - nodes[node_b].position_m
	var cb := nodes[node_c].position_m - nodes[node_b].position_m
	if ab.length() <= 0.00001 or cb.length() <= 0.00001:
		return 0.0
	return acos(clampf(ab.normalized().dot(cb.normalized()), -1.0, 1.0))
