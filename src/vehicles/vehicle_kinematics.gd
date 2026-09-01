# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleKinematics
extends RefCounted

static func linear_velocity_ms(model: StructuralModel) -> Vector3:
	return model.average_velocity_ms()

static func total_momentum_kg_ms(model: StructuralModel) -> Vector3:
	return model.total_momentum_kg_ms()

static func angular_velocity_rad_s(model: StructuralModel) -> Vector3:
	if model.nodes.is_empty():
		return Vector3.ZERO
	var center := model.center_of_mass_m()
	var linear := model.average_velocity_ms()
	var angular_momentum := Vector3.ZERO
	var scalar_inertia := 0.0
	for node in model.nodes:
		var radius := node.position_m - center
		var relative_velocity := node.velocity_ms - linear
		angular_momentum += radius.cross(relative_velocity * node.mass_kg)
		scalar_inertia += node.mass_kg * radius.length_squared()
	if scalar_inertia <= 0.000001:
		return Vector3.ZERO
	return angular_momentum / scalar_inertia

static func translational_kinetic_energy_j(model: StructuralModel) -> float:
	var velocity := linear_velocity_ms(model)
	return 0.5 * model.total_mass_kg() * velocity.length_squared()

static func rotational_kinetic_energy_j(model: StructuralModel) -> float:
	var center := model.center_of_mass_m()
	var inertia := 0.0
	for node in model.nodes:
		inertia += node.mass_kg * (node.position_m - center).length_squared()
	return 0.5 * inertia * angular_velocity_rad_s(model).length_squared()

static func deformation_kinetic_energy_j(model: StructuralModel) -> float:
	return maxf(
		model.total_kinetic_energy_j()
		- translational_kinetic_energy_j(model)
		- rotational_kinetic_energy_j(model),
		0.0
	)

static func reference_transform(
	model: StructuralModel,
	rear_indices: PackedInt32Array,
	front_indices: PackedInt32Array,
	left_indices: PackedInt32Array,
	right_indices: PackedInt32Array
) -> Transform3D:
	var origin := model.center_of_mass_m()
	var rear := model.average_position_for_nodes(rear_indices)
	var front := model.average_position_for_nodes(front_indices)
	var left := model.average_position_for_nodes(left_indices)
	var right := model.average_position_for_nodes(right_indices)
	var forward := (front - rear).normalized()
	if forward.is_zero_approx():
		forward = Vector3.RIGHT
	var side := (right - left).normalized()
	if side.is_zero_approx():
		side = Vector3.BACK
	var up := side.cross(forward).normalized()
	if up.dot(Vector3.UP) < 0.0:
		up = -up
	side = forward.cross(up).normalized()
	return Transform3D(Basis(forward, up, side), origin)
