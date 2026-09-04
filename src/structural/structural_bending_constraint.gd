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
var maximum_force_n: float = 500000.0
var plastic_bend_angle_rad: float = 0.0
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
	var ba := a.position_m - b.position_m
	var bc := c.position_m - b.position_m
	var len_ba := ba.length()
	var len_bc := bc.length()
	if len_ba <= 0.00001 or len_bc <= 0.00001:
		return

	var u := ba / len_ba
	var v := bc / len_bc
	var bend_angle := acos(clampf(-u.dot(v), -1.0, 1.0))
	last_angle_rad = _current_angle(nodes)
	last_angle_error_rad = bend_angle
	if bend_angle >= break_angle_rad:
		fracture_energy_j += elastic_energy_j(nodes)
		broken = true
		last_generalized_torque_nm = 0.0
		return

	_apply_plastic_hinge(bend_angle, delta_s)
	var damage := clampf(plastic_bend_angle_rad / maxf(max_plastic_angle_rad, 0.0001), 0.0, 1.0)
	var effective_stiffness := stiffness_nm_rad * lerpf(1.0, 0.12, damage)
	last_generalized_torque_nm = effective_stiffness * bend_angle

	# For a straight A-B-C rail, u and v point in opposite directions and
	# u+v is zero. As B leaves the A-C line, u+v points back toward the chord.
	# This curvature surrogate is well-conditioned at the straight position,
	# unlike an acos/sin angle-gradient formulation, and does not resist pure
	# axial shortening when all three nodes stay collinear.
	var chord := c.position_m - a.position_m
	var chord_length := chord.length()
	var tangent := chord / chord_length if chord_length > 0.00001 else (v - u).normalized()
	if tangent.is_zero_approx():
		return
	var curvature := u + v
	curvature -= tangent * curvature.dot(tangent)
	var characteristic_length := maxf((len_ba + len_bc) * 0.5, 0.05)
	var relative_middle_velocity := b.velocity_ms - (a.velocity_ms + c.velocity_ms) * 0.5
	var lateral_velocity := relative_middle_velocity - tangent * relative_middle_velocity.dot(tangent)
	var elastic_force := curvature * (effective_stiffness / characteristic_length)
	var damping_coefficient := 2.0 * damping_nm_s_rad / maxf(characteristic_length * characteristic_length, 0.0025)
	var damping_force := -lateral_velocity * damping_coefficient
	var middle_force := elastic_force + damping_force
	var force_scale := 1.0
	var force_length := middle_force.length()
	if force_length > maximum_force_n:
		force_scale = maximum_force_n / force_length
		middle_force *= force_scale

	b.add_force(middle_force)
	a.add_force(-middle_force * 0.5)
	c.add_force(-middle_force * 0.5)
	var applied_damping_force := damping_force * force_scale
	damping_energy_j += maxf(-applied_damping_force.dot(lateral_velocity), 0.0) * delta_s

func _apply_plastic_hinge(bend_angle_rad: float, delta_s: float) -> void:
	if bend_angle_rad <= yield_angle_rad or plastic_flow_rate <= 0.0:
		return
	var target_plastic := minf(bend_angle_rad, max_plastic_angle_rad)
	var flow_span := maxf(max_plastic_angle_rad - yield_angle_rad, deg_to_rad(0.1))
	var flow_factor := clampf((bend_angle_rad - yield_angle_rad) / flow_span, 0.0, 1.0)
	var alpha := clampf(plastic_flow_rate * maxf(flow_factor, 0.15) * delta_s, 0.0, 1.0)
	var old_plastic := plastic_bend_angle_rad
	plastic_bend_angle_rad = lerpf(plastic_bend_angle_rad, target_plastic, alpha)
	rest_angle_rad = original_rest_angle_rad - plastic_bend_angle_rad
	plastic_energy_j += absf(last_generalized_torque_nm) * absf(plastic_bend_angle_rad - old_plastic)

func elastic_energy_j(nodes: Array[StructuralNode]) -> float:
	if broken:
		return 0.0
	var bend_angle := _current_bend_angle(nodes)
	var damage := clampf(plastic_bend_angle_rad / maxf(max_plastic_angle_rad, 0.0001), 0.0, 1.0)
	var effective_stiffness := stiffness_nm_rad * lerpf(1.0, 0.12, damage)
	return 0.5 * effective_stiffness * bend_angle * bend_angle

func permanent_angle_rad() -> float:
	return plastic_bend_angle_rad

func _current_bend_angle(nodes: Array[StructuralNode]) -> float:
	if node_a < 0 or node_b < 0 or node_c < 0 or node_a >= nodes.size() or node_b >= nodes.size() or node_c >= nodes.size():
		return 0.0
	var ba := nodes[node_a].position_m - nodes[node_b].position_m
	var bc := nodes[node_c].position_m - nodes[node_b].position_m
	if ba.length() <= 0.00001 or bc.length() <= 0.00001:
		return 0.0
	return acos(clampf(-ba.normalized().dot(bc.normalized()), -1.0, 1.0))

func _current_angle(nodes: Array[StructuralNode]) -> float:
	if node_a < 0 or node_b < 0 or node_c < 0 or node_a >= nodes.size() or node_b >= nodes.size() or node_c >= nodes.size():
		return 0.0
	var ab := nodes[node_a].position_m - nodes[node_b].position_m
	var cb := nodes[node_c].position_m - nodes[node_b].position_m
	if ab.length() <= 0.00001 or cb.length() <= 0.00001:
		return 0.0
	return acos(clampf(ab.normalized().dot(cb.normalized()), -1.0, 1.0))
