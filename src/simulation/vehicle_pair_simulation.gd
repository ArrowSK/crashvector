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
	vehicle_contact_nodes = car_contact_nodes
	truck_contact_nodes = truck_rear_contact_nodes
	contact_normal = normal.normalized()
	if contact_normal.is_zero_approx():
		contact_normal = Vector3.RIGHT
	vehicle_model.barrier_enabled = false
	truck_model.barrier_enabled = false
	initial_energy_j = vehicle_model.initial_energy_j + truck_model.initial_energy_j
	initial_momentum_kg_ms = vehicle_model.total_momentum_kg_ms() + truck_model.total_momentum_kg_ms()
	elapsed_s = 0.0
	contact = VehiclePairContact.new()
	contact.friction_coefficient = clampf(friction_coefficient, 0.0, 1.5)
	contact.restitution = clampf(restitution, 0.0, 0.5)

func step(delta_s: float, substeps: int = 8) -> void:
	if delta_s <= 0.0 or vehicle_model == null or truck_model == null:
		return
	var count := maxi(substeps, 1)
	var h := delta_s / float(count)
	for _substep in range(count):
		vehicle_model.step(h, 1)
		truck_model.step(h, 1)
		contact.resolve_pairs(
			vehicle_model,
			vehicle_contact_nodes,
			truck_model,
			truck_contact_nodes,
			contact_normal,
			elapsed_s
		)
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
	return vehicle_model.accounted_energy_j() + truck_model.accounted_energy_j() + contact.accumulated_dissipation_j

func energy_balance_relative_error() -> float:
	if initial_energy_j <= 0.0:
		return 0.0
	return absf(initial_energy_j - accounted_energy_j()) / initial_energy_j
