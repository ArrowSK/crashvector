# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleStaticSimulation
extends RefCounted

var vehicle_model: StructuralModel
var contact := VehicleStaticContact.new()
var elapsed_s: float = 0.0
var initial_energy_j: float = 0.0
var structural_internal_work_energy_j: float = 0.0

func configure(
	model: StructuralModel,
	obstacle_type: StringName,
	obstacle_position_m: Vector3,
	obstacle_heading_deg: float,
	friction_coefficient: float,
	restitution: float
) -> void:
	vehicle_model = model
	vehicle_model.barrier_enabled = false
	contact = VehicleStaticContact.new()
	contact.configure(obstacle_type, obstacle_position_m, obstacle_heading_deg, friction_coefficient, restitution)
	elapsed_s = 0.0
	initial_energy_j = vehicle_model.initial_energy_j
	structural_internal_work_energy_j = 0.0

func step(delta_s: float, substeps: int = 8) -> void:
	if delta_s <= 0.0 or vehicle_model == null:
		return
	var count := maxi(substeps, 1)
	var h := delta_s / float(count)
	for _substep in range(count):
		vehicle_model.prepare_substep(h)
		# M11 combines axial springs, viscous damping, plastic rest-state flow,
		# fracture, fold constraints and the passenger-cell guard. Several of
		# those reduced-order forces are phenomenological and do not share one
		# conservative potential, so summing each local energy estimate can
		# double-count the same internal work. For the production work-energy
		# balance, capture the actual structural force before external contact
		# is added and integrate its work against the actual node motion.
		var structural_forces: Array[Vector3] = []
		var velocities_before: Array[Vector3] = []
		structural_forces.resize(vehicle_model.nodes.size())
		velocities_before.resize(vehicle_model.nodes.size())
		for index in range(vehicle_model.nodes.size()):
			var node := vehicle_model.nodes[index]
			var gravity_force := gravity_force_for_node(node)
			structural_forces[index] = node.force_n - gravity_force
			velocities_before[index] = node.velocity_ms

		contact.apply_forces(vehicle_model, h, elapsed_s)
		vehicle_model.integrate_substep(h)

		for index in range(vehicle_model.nodes.size()):
			var node := vehicle_model.nodes[index]
			var average_velocity := (velocities_before[index] + node.velocity_ms) * 0.5
			structural_internal_work_energy_j -= structural_forces[index].dot(average_velocity) * h
		elapsed_s += h

func gravity_force_for_node(node: StructuralNode) -> Vector3:
	if node == null or vehicle_model.gravity_ms2.is_zero_approx():
		return Vector3.ZERO
	return vehicle_model.gravity_ms2 * node.mass_kg

func accounted_energy_j() -> float:
	if vehicle_model == null:
		return 0.0
	return (
		vehicle_model.total_kinetic_energy_j()
		+ vehicle_model.total_gravitational_potential_energy_j()
		+ structural_internal_work_energy_j
		+ vehicle_model.contact_dissipation_j
		+ contact.accumulated_dissipation_j
		+ contact.current_contact_energy_j
	)

func energy_balance_relative_error() -> float:
	if initial_energy_j <= 0.0:
		return 0.0
	return absf(initial_energy_j - accounted_energy_j()) / initial_energy_j
