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

var normal_stiffness_n_m: float = 3000000.0
var damping_ratio: float = 0.75
var maximum_force_per_node_n: float = 750000.0
var emergency_penetration_m: float = 0.20
var emergency_position_fraction: float = 0.02
var contact_events: int = 0
var active_contacts: int = 0
var first_contact_time_s: float = -1.0
var accumulated_dissipation_j: float = 0.0
var current_contact_energy_j: float = 0.0
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
	damping_ratio = damping_ratio_for_restitution(restitution)

static func damping_ratio_for_restitution(coefficient: float) -> float:
	var e := clampf(coefficient, 0.0001, 0.9999)
	var log_e := log(e)
	return clampf(-log_e / sqrt(PI * PI + log_e * log_e), 0.0, 1.0)

func apply_forces(model: StructuralModel, delta_s: float, elapsed_s: float) -> void:
	current_contact_energy_j = 0.0
	active_contacts = 0
	if model == null or delta_s <= 0.0:
		return
	for node in model.nodes:
		if node.pinned:
			continue
		var contact_data := _contact_for_point(node.position_m)
		if contact_data.is_empty():
			continue
		_apply_node_force(node, contact_data["normal"], float(contact_data["penetration"]), delta_s, elapsed_s)

func resolve_model(model: StructuralModel, elapsed_s: float) -> void:
	apply_forces(model, 1.0 / 240.0, elapsed_s)

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

func _apply_node_force(node: StructuralNode, normal: Vector3, penetration_m: float, delta_s: float, elapsed_s: float) -> void:
	var n := normal.normalized()
	if n.is_zero_approx() or penetration_m <= 0.0:
		return
	maximum_penetration_m = maxf(maximum_penetration_m, penetration_m)
	active_contacts += 1
	contact_events += 1
	if first_contact_time_s < 0.0:
		first_contact_time_s = elapsed_s

	var normal_speed := node.velocity_ms.dot(n)
	var spring_force := normal_stiffness_n_m * penetration_m
	var critical_damping := 2.0 * sqrt(maxf(normal_stiffness_n_m * node.mass_kg, 0.0))
	var damping_coefficient := critical_damping * clampf(damping_ratio, 0.0, 1.0)
	# Negative normal speed means compression and therefore adds damping force;
	# positive speed means separation and subtracts damping from spring release.
	# Clamping the combined force at zero prevents a tensile wall contact.
	var damping_force_signed := -damping_coefficient * normal_speed
	var requested_force := spring_force + damping_force_signed
	var normal_force := clampf(requested_force, 0.0, maximum_force_per_node_n)
	var force_scale := 0.0
	if requested_force > 0.000001:
		force_scale = normal_force / requested_force
	var applied_spring_force := spring_force * force_scale
	node.add_force(n * normal_force)
	current_contact_energy_j += 0.5 * applied_spring_force * penetration_m
	accumulated_dissipation_j += damping_coefficient * normal_speed * normal_speed * force_scale * delta_s

	var tangent_velocity := node.velocity_ms - n * normal_speed
	var tangent_speed := tangent_velocity.length()
	if tangent_speed > 0.000001 and friction_coefficient > 0.0:
		var tangent_direction := tangent_velocity / tangent_speed
		var desired_friction_force := node.mass_kg * tangent_speed / maxf(delta_s, 0.000001)
		var friction_force := minf(desired_friction_force, friction_coefficient * normal_force)
		node.add_force(-tangent_direction * friction_force)
		accumulated_dissipation_j += friction_force * tangent_speed * delta_s

	if penetration_m > emergency_penetration_m:
		var correction := (penetration_m - emergency_penetration_m) * clampf(emergency_position_fraction, 0.0, 0.05)
		node.position_m += n * correction
