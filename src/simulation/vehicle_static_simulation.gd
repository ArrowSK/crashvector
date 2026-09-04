# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleStaticSimulation
extends RefCounted

var vehicle_model: StructuralModel
var contact := VehicleStaticContact.new()
var elapsed_s: float = 0.0
var initial_energy_j: float = 0.0

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

func step(delta_s: float, substeps: int = 8) -> void:
	if delta_s <= 0.0 or vehicle_model == null:
		return
	var count := maxi(substeps, 1)
	var h := delta_s / float(count)
	for _substep in range(count):
		vehicle_model.prepare_substep(h)
		contact.apply_forces(vehicle_model, h, elapsed_s)
		vehicle_model.integrate_substep(h)
		elapsed_s += h

func accounted_energy_j() -> float:
	if vehicle_model == null:
		return 0.0
	return (
		vehicle_model.accounted_energy_j()
		+ contact.accumulated_dissipation_j
		+ contact.current_contact_energy_j
	)

func energy_balance_relative_error() -> float:
	if initial_energy_j <= 0.0:
		return 0.0
	return absf(initial_energy_j - accounted_energy_j()) / initial_energy_j
