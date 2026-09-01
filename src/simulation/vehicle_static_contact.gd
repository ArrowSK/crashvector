# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleStaticContact
extends RefCounted

var obstacle_type: StringName = ScenarioConfig.TARGET_WALL
var obstacle_position_m: Vector3 = Vector3.ZERO
var obstacle_heading_deg: float = 0.0
var restitution: float = 0.03
var friction_coefficient: float = 0.55
var position_correction_fraction: float = 0.90
var penetration_slop_m: float = 0.001
var contact_events: int = 0
var first_contact_time_s: float = -1.0
var accumulated_dissipation_j: float = 0.0
var maximum_penetration_m: float = 0.0

func configure(
	type_id: StringName,
	position_m: Vector3,
	heading_deg: float,
	friction: float,
	bounce: float
) -> void:
	obstacle_type = type_id
	obstacle_position_m = position_m
	obstacle_heading_deg = heading_deg
	friction_coefficient = clampf(friction, 0.0, 1.5)
	restitution = clampf(bounce, 0.0, 0.5)

func resolve_model(model: StructuralModel, elapsed_s: float) -> void:
	if model == null:
		return
	for node in model.nodes:
		if node.pinned:
			continue
		var contact_data := _contact_for_point(node.position_m)
		if contact_data.is_empty():
			continue
		_resolve_node(node, contact_data["normal"], float(contact_data["penetration"]), elapsed_s)

func _contact_for_point(point_m: Vector3) -> Dictionary:
	match obstacle_type:
		ScenarioConfig.TARGET_POLE:
			return _cylinder_contact(point_m, 0.18, 2.8)
		ScenarioConfig.TARGET_TREE:
			return _cylinder_contact(point_m, 0.32, 3.6)
		ScenarioConfig.TARGET_BARRIER:
			return _plane_contact(point_m, 2.0, 0.95)
		_:
			return _plane_contact(point_m, 4.5, 3.2)

func _plane_contact(point_m: Vector3, half_width_m: float, height_m: float) -> Dictionary:
	if point_m.y < 0.0 or point_m.y > height_m:
		return {}
	var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(obstacle_heading_deg)).normalized()
	var lateral := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(obstacle_heading_deg)).normalized()
	var delta := point_m - obstacle_position_m
	if absf(delta.dot(lateral)) > half_width_m:
		return {}
	var penetration := delta.dot(forward)
	if penetration <= 0.0:
		return {}
	return {"normal": -forward, "penetration": penetration}

func _cylinder_contact(point_m: Vector3, radius_m: float, height_m: float) -> Dictionary:
	if point_m.y < 0.0 or point_m.y > height_m:
		return {}
	var planar_delta := Vector3(point_m.x - obstacle_position_m.x, 0.0, point_m.z - obstacle_position_m.z)
	var distance_m := planar_delta.length()
	if distance_m >= radius_m:
		return {}
	var normal := planar_delta.normalized()
	if normal.is_zero_approx():
		normal = -Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(obstacle_heading_deg)).normalized()
	return {"normal": normal, "penetration": radius_m - distance_m}

func _resolve_node(node: StructuralNode, normal: Vector3, penetration_m: float, elapsed_s: float) -> void:
	var n := normal.normalized()
	if n.is_zero_approx():
		return
	maximum_penetration_m = maxf(maximum_penetration_m, penetration_m)
	var normal_speed := node.velocity_ms.dot(n)
	if normal_speed < 0.0:
		var before_j := node.kinetic_energy_j()
		var normal_impulse_ns := -(1.0 + restitution) * normal_speed / maxf(node.inverse_mass, 0.0000001)
		node.velocity_ms += n * normal_impulse_ns * node.inverse_mass
		var tangent_velocity := node.velocity_ms - n * node.velocity_ms.dot(n)
		var tangent_speed := tangent_velocity.length()
		if tangent_speed > 0.000001 and friction_coefficient > 0.0:
			var tangent_direction := tangent_velocity / tangent_speed
			var desired_tangent_impulse := tangent_speed / maxf(node.inverse_mass, 0.0000001)
			var tangent_impulse := minf(desired_tangent_impulse, friction_coefficient * normal_impulse_ns)
			node.velocity_ms -= tangent_direction * tangent_impulse * node.inverse_mass
		var after_j := node.kinetic_energy_j()
		accumulated_dissipation_j += maxf(before_j - after_j, 0.0)
		contact_events += 1
		if first_contact_time_s < 0.0:
			first_contact_time_s = elapsed_s

	var correction_depth := maxf(penetration_m - penetration_slop_m, 0.0)
	if correction_depth > 0.0:
		node.position_m += n * correction_depth * clampf(position_correction_fraction, 0.0, 1.0)
