# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CompactHatchbackBuilder
extends RefCounted

const STATION_X := PackedFloat64Array([-2.05, -1.45, -0.80, 0.00, 0.72, 1.38, 2.02])
const LOWER_Y := PackedFloat64Array([0.48, 0.46, 0.45, 0.45, 0.46, 0.48, 0.52])
const UPPER_Y := PackedFloat64Array([1.10, 1.42, 1.58, 1.62, 1.50, 1.15, 0.84])
const HALF_WIDTH_Z := PackedFloat64Array([0.68, 0.80, 0.85, 0.86, 0.84, 0.76, 0.60])
const STATION_MASS_SHARE := PackedFloat64Array([0.08, 0.13, 0.17, 0.18, 0.19, 0.16, 0.09])

const REAR_AXLE_STATION: int = 1
const FRONT_AXLE_STATION: int = 5
const CABIN_REAR_STATION: int = 1
const CABIN_FRONT_STATION: int = 4
const FRONT_STATION: int = 6
const REAR_STATION: int = 0

static func build(total_mass_kg: float = 1150.0, speed_kmh: float = 50.0, barrier_x_m: float = 5.0) -> StructuralModel:
	var model := StructuralModel.new()
	model.barrier_x_m = barrier_x_m
	var mass := maxf(total_mass_kg, 1.0)

	for station in range(STATION_X.size()):
		var node_mass := mass * STATION_MASS_SHARE[station] / 4.0
		var x := STATION_X[station]
		var lower := LOWER_Y[station]
		var upper := UPPER_Y[station]
		var half_width := HALF_WIDTH_Z[station]
		model.add_node(Vector3(x, lower, -half_width), node_mass)
		model.add_node(Vector3(x, lower, half_width), node_mass)
		model.add_node(Vector3(x, upper, -half_width), node_mass)
		model.add_node(Vector3(x, upper, half_width), node_mass)

	for station in range(STATION_X.size()):
		_add_cross_section(model, station)

	for station in range(STATION_X.size() - 1):
		_add_longitudinal_segment(model, station, station + 1)

	_add_passenger_cell_reinforcement(model)
	model.set_uniform_velocity(Vector3.RIGHT * PhysicsMetrics.kmh_to_ms(speed_kmh))
	return model

static func node_index(station: int, corner: int) -> int:
	return station * 4 + corner

static func station_nodes(station: int) -> PackedInt32Array:
	return PackedInt32Array([
		node_index(station, 0),
		node_index(station, 1),
		node_index(station, 2),
		node_index(station, 3),
	])

static func rear_reference_nodes() -> PackedInt32Array:
	return station_nodes(REAR_AXLE_STATION)

static func front_reference_nodes() -> PackedInt32Array:
	return station_nodes(FRONT_AXLE_STATION)

static func left_reference_nodes() -> PackedInt32Array:
	return PackedInt32Array([
		node_index(2, 0), node_index(2, 2),
		node_index(3, 0), node_index(3, 2),
		node_index(4, 0), node_index(4, 2),
	])

static func right_reference_nodes() -> PackedInt32Array:
	return PackedInt32Array([
		node_index(2, 1), node_index(2, 3),
		node_index(3, 1), node_index(3, 3),
		node_index(4, 1), node_index(4, 3),
	])

static func wheel_anchor_indices() -> PackedInt32Array:
	return PackedInt32Array([
		node_index(REAR_AXLE_STATION, 0),
		node_index(REAR_AXLE_STATION, 1),
		node_index(FRONT_AXLE_STATION, 0),
		node_index(FRONT_AXLE_STATION, 1),
	])

static func _add_cross_section(model: StructuralModel, station: int) -> void:
	var profile := _profile_for_station(station)
	var corners := [0, 1, 3, 2]
	for i in range(corners.size()):
		_add_profile_beam(
			model,
			node_index(station, corners[i]),
			node_index(station, corners[(i + 1) % corners.size()]),
			profile
		)
	_add_profile_beam(model, node_index(station, 0), node_index(station, 3), profile)
	_add_profile_beam(model, node_index(station, 1), node_index(station, 2), profile)

static func _add_longitudinal_segment(model: StructuralModel, rear_station: int, front_station: int) -> void:
	var profile := _profile_for_segment(rear_station)
	for corner in range(4):
		_add_profile_beam(
			model,
			node_index(rear_station, corner),
			node_index(front_station, corner),
			profile
		)
	_add_profile_beam(model, node_index(rear_station, 0), node_index(front_station, 2), profile)
	_add_profile_beam(model, node_index(rear_station, 2), node_index(front_station, 0), profile)
	_add_profile_beam(model, node_index(rear_station, 1), node_index(front_station, 3), profile)
	_add_profile_beam(model, node_index(rear_station, 3), node_index(front_station, 1), profile)
	_add_profile_beam(model, node_index(rear_station, 0), node_index(front_station, 1), profile)
	_add_profile_beam(model, node_index(rear_station, 1), node_index(front_station, 0), profile)
	_add_profile_beam(model, node_index(rear_station, 2), node_index(front_station, 3), profile)
	_add_profile_beam(model, node_index(rear_station, 3), node_index(front_station, 2), profile)

static func _add_passenger_cell_reinforcement(model: StructuralModel) -> void:
	for rear_station in range(CABIN_REAR_STATION, CABIN_FRONT_STATION):
		var front_station := rear_station + 1
		_add_profile_beam(model, node_index(rear_station, 0), node_index(front_station, 3), &"safety_cell")
		_add_profile_beam(model, node_index(rear_station, 1), node_index(front_station, 2), &"safety_cell")

	_add_profile_beam(
		model,
		node_index(CABIN_REAR_STATION, 0),
		node_index(CABIN_FRONT_STATION, 2),
		&"safety_cell"
	)
	_add_profile_beam(
		model,
		node_index(CABIN_REAR_STATION, 1),
		node_index(CABIN_FRONT_STATION, 3),
		&"safety_cell"
	)

static func _profile_for_station(station: int) -> StringName:
	if station == REAR_STATION:
		return &"rear_crush"
	if station >= CABIN_REAR_STATION and station <= CABIN_FRONT_STATION:
		return &"safety_cell"
	if station == FRONT_AXLE_STATION:
		return &"front_transition"
	return &"front_crush"

static func _profile_for_segment(rear_station: int) -> StringName:
	if rear_station == REAR_STATION:
		return &"rear_crush"
	if rear_station >= CABIN_REAR_STATION and rear_station < CABIN_FRONT_STATION:
		return &"safety_cell"
	if rear_station == CABIN_FRONT_STATION:
		return &"front_transition"
	return &"front_crush"

static func _add_profile_beam(model: StructuralModel, a: int, b: int, profile: StringName) -> void:
	match profile:
		&"front_crush":
			model.add_beam(a, b, profile, 900000.0, 3800.0, 0.035, 0.55, 0.75, 18.0)
		&"front_transition":
			model.add_beam(a, b, profile, 2100000.0, 5400.0, 0.050, 0.36, 0.56, 12.0)
		&"rear_crush":
			model.add_beam(a, b, profile, 1250000.0, 4200.0, 0.040, 0.42, 0.64, 15.0)
		_:
			model.add_beam(a, b, &"safety_cell", 5400000.0, 7600.0, 0.080, 0.16, 0.30, 6.0)
