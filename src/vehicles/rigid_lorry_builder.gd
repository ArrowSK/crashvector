# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RigidLorryBuilder
extends RefCounted

# Generic rigid-body lorry / box-truck structural approximation. This is a
# development model, not a representation of a particular manufacturer.
const STATION_X: Array[float] = [0.0, 1.45, 3.05, 4.65, 6.05, 7.35]
const LOWER_Y: Array[float] = [0.50, 0.66, 0.68, 0.68, 0.62, 0.60]
const UPPER_Y: Array[float] = [1.05, 3.35, 3.35, 3.35, 3.05, 2.65]
const HALF_WIDTH_Z: Array[float] = [1.00, 1.14, 1.14, 1.14, 1.08, 1.02]
const STATION_MASS_SHARE: Array[float] = [0.08, 0.16, 0.18, 0.20, 0.20, 0.18]

const REAR_STATION: int = 0
const CARGO_END_STATION: int = 3
const FRONT_STATION: int = 5

static func build(
	total_mass_kg: float = 12000.0,
	speed_kmh: float = 0.0,
	origin_offset_m: Vector3 = Vector3.ZERO
) -> StructuralModel:
	var model := StructuralModel.new()
	model.barrier_enabled = false
	var mass := maxf(total_mass_kg, 1000.0)
	for station in range(STATION_X.size()):
		var node_mass := mass * STATION_MASS_SHARE[station] / 4.0
		model.add_node(origin_offset_m + Vector3(STATION_X[station], LOWER_Y[station], -HALF_WIDTH_Z[station]), node_mass)
		model.add_node(origin_offset_m + Vector3(STATION_X[station], LOWER_Y[station], HALF_WIDTH_Z[station]), node_mass)
		model.add_node(origin_offset_m + Vector3(STATION_X[station], UPPER_Y[station], -HALF_WIDTH_Z[station]), node_mass)
		model.add_node(origin_offset_m + Vector3(STATION_X[station], UPPER_Y[station], HALF_WIDTH_Z[station]), node_mass)
	for station in range(STATION_X.size()):
		_add_cross_section(model, station)
	for station in range(STATION_X.size() - 1):
		_add_longitudinal_segment(model, station, station + 1)
	model.set_uniform_velocity(Vector3.RIGHT * PhysicsMetrics.kmh_to_ms(speed_kmh))
	return model

static func node_index(station: int, corner: int) -> int:
	return station * 4 + corner

static func station_nodes(station: int) -> PackedInt32Array:
	return PackedInt32Array([
		node_index(station, 0), node_index(station, 1),
		node_index(station, 2), node_index(station, 3),
	])

static func rear_contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([node_index(REAR_STATION, 0), node_index(REAR_STATION, 1)])

static func front_contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([node_index(FRONT_STATION, 0), node_index(FRONT_STATION, 1)])

static func wheel_anchor_indices() -> PackedInt32Array:
	return PackedInt32Array([
		node_index(1, 0), node_index(1, 1),
		node_index(3, 0), node_index(3, 1),
		node_index(5, 0), node_index(5, 1),
	])

static func _add_cross_section(model: StructuralModel, station: int) -> void:
	var role := _profile_for_station(station)
	var corners: Array[int] = [0, 1, 3, 2]
	for i in range(corners.size()):
		_add_profile_beam(model, node_index(station, corners[i]), node_index(station, corners[(i + 1) % corners.size()]), role)
	_add_profile_beam(model, node_index(station, 0), node_index(station, 3), role)
	_add_profile_beam(model, node_index(station, 1), node_index(station, 2), role)

static func _add_longitudinal_segment(model: StructuralModel, rear_station: int, front_station: int) -> void:
	var role := _profile_for_segment(rear_station)
	for corner in range(4):
		_add_profile_beam(model, node_index(rear_station, corner), node_index(front_station, corner), role)
	_add_profile_beam(model, node_index(rear_station, 0), node_index(front_station, 2), role)
	_add_profile_beam(model, node_index(rear_station, 2), node_index(front_station, 0), role)
	_add_profile_beam(model, node_index(rear_station, 1), node_index(front_station, 3), role)
	_add_profile_beam(model, node_index(rear_station, 3), node_index(front_station, 1), role)
	_add_profile_beam(model, node_index(rear_station, 0), node_index(front_station, 1), role)
	_add_profile_beam(model, node_index(rear_station, 1), node_index(front_station, 0), role)

static func _profile_for_station(station: int) -> StringName:
	if station == REAR_STATION:
		return &"lorry_rear_guard"
	if station <= CARGO_END_STATION:
		return &"lorry_cargo_structure"
	return &"lorry_cab_structure"

static func _profile_for_segment(rear_station: int) -> StringName:
	if rear_station == REAR_STATION:
		return &"lorry_rear_chassis"
	if rear_station < CARGO_END_STATION:
		return &"lorry_cargo_chassis"
	return &"lorry_cab_chassis"

static func _add_profile_beam(model: StructuralModel, a: int, b: int, role: StringName) -> void:
	match role:
		&"lorry_rear_guard":
			model.add_beam(a, b, role, 6500000.0, 7800.0, 0.030, 0.18, 0.32, 8.0)
		&"lorry_cab_structure":
			model.add_beam(a, b, role, 9500000.0, 9800.0, 0.045, 0.13, 0.25, 5.5)
		&"lorry_cab_chassis":
			model.add_beam(a, b, role, 14500000.0, 12000.0, 0.040, 0.10, 0.20, 4.5)
		&"lorry_cargo_structure":
			model.add_beam(a, b, role, 7200000.0, 8800.0, 0.040, 0.15, 0.28, 6.0)
		_:
			model.add_beam(a, b, role, 12500000.0, 11000.0, 0.040, 0.11, 0.22, 4.5)
