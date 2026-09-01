# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name HeavyTruckBuilder
extends RefCounted

const STATION_X := PackedFloat64Array([0.0, 1.5, 3.0, 4.5, 6.0, 7.2, 8.4, 9.5])
const LOWER_Y := PackedFloat64Array([0.52, 0.72, 0.72, 0.72, 0.72, 0.62, 0.60, 0.64])
const UPPER_Y := PackedFloat64Array([1.10, 3.65, 3.65, 3.65, 3.65, 3.15, 3.15, 2.50])
const HALF_WIDTH_Z := PackedFloat64Array([1.05, 1.22, 1.22, 1.22, 1.22, 1.18, 1.18, 1.10])
const STATION_MASS_SHARE := PackedFloat64Array([0.05, 0.10, 0.11, 0.12, 0.15, 0.17, 0.17, 0.13])

const REAR_STATION: int = 0
const TRAILER_END_STATION: int = 4
const FRONT_STATION: int = 7

static func build(
	total_mass_kg: float = 18000.0,
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

static func rear_reference_nodes() -> PackedInt32Array:
	return station_nodes(1)

static func front_reference_nodes() -> PackedInt32Array:
	return station_nodes(6)

static func left_reference_nodes() -> PackedInt32Array:
	return PackedInt32Array([node_index(2, 0), node_index(2, 2), node_index(5, 0), node_index(5, 2)])

static func right_reference_nodes() -> PackedInt32Array:
	return PackedInt32Array([node_index(2, 1), node_index(2, 3), node_index(5, 1), node_index(5, 3)])

static func wheel_anchor_indices() -> PackedInt32Array:
	return PackedInt32Array([
		node_index(1, 0), node_index(1, 1),
		node_index(4, 0), node_index(4, 1),
		node_index(6, 0), node_index(6, 1),
	])

static func _add_cross_section(model: StructuralModel, station: int) -> void:
	var role := _profile_for_station(station)
	var corners := [0, 1, 3, 2]
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
		return &"underride_guard"
	if station <= TRAILER_END_STATION:
		return &"trailer_structure"
	return &"tractor_structure"

static func _profile_for_segment(rear_station: int) -> StringName:
	if rear_station == REAR_STATION:
		return &"rear_chassis"
	if rear_station < TRAILER_END_STATION:
		return &"trailer_chassis"
	if rear_station == TRAILER_END_STATION:
		return &"fifth_wheel"
	return &"tractor_chassis"

static func _add_profile_beam(model: StructuralModel, a: int, b: int, role: StringName) -> void:
	match role:
		&"underride_guard":
			model.add_beam(a, b, role, 8500000.0, 9000.0, 0.025, 0.16, 0.28, 8.0)
		&"fifth_wheel":
			model.add_beam(a, b, role, 6500000.0, 10000.0, 0.045, 0.12, 0.24, 6.0)
		&"tractor_structure":
			model.add_beam(a, b, role, 11000000.0, 11500.0, 0.045, 0.11, 0.22, 5.0)
		&"tractor_chassis":
			model.add_beam(a, b, role, 18000000.0, 14000.0, 0.040, 0.09, 0.18, 4.0)
		&"trailer_structure":
			model.add_beam(a, b, role, 9000000.0, 10500.0, 0.040, 0.12, 0.24, 5.0)
		_:
			model.add_beam(a, b, role, 16000000.0, 13500.0, 0.040, 0.10, 0.20, 4.0)
