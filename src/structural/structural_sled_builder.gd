# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralSledBuilder
extends RefCounted

const STATION_X: Array[float] = [-4.0, -2.5, -1.0, 0.5, 2.0]
const LOWER_Y: float = 0.55
const UPPER_Y: float = 1.45
const HALF_WIDTH_Z: float = 0.82

static func build_compact_sled(total_mass_kg: float = 1150.0, speed_kmh: float = 50.0, barrier_x_m: float = 5.0) -> StructuralModel:
	var model := StructuralModel.new()
	model.barrier_x_m = barrier_x_m
	var node_count := STATION_X.size() * 4
	var node_mass := maxf(total_mass_kg, 1.0) / float(node_count)

	for station in range(STATION_X.size()):
		var x: float = STATION_X[station]
		model.add_node(Vector3(x, LOWER_Y, -HALF_WIDTH_Z), node_mass)
		model.add_node(Vector3(x, LOWER_Y, HALF_WIDTH_Z), node_mass)
		model.add_node(Vector3(x, UPPER_Y, -HALF_WIDTH_Z), node_mass)
		model.add_node(Vector3(x, UPPER_Y, HALF_WIDTH_Z), node_mass)

	for station in range(STATION_X.size()):
		_add_cross_section(model, station)

	for station in range(STATION_X.size() - 1):
		_add_longitudinal_segment(model, station, station + 1)

	model.set_uniform_velocity(Vector3.RIGHT * PhysicsMetrics.kmh_to_ms(speed_kmh))
	return model

static func _node_index(station: int, corner: int) -> int:
	return station * 4 + corner

static func _add_cross_section(model: StructuralModel, station: int) -> void:
	var corners: Array[int] = [0, 1, 3, 2]
	for i in range(corners.size()):
		var a: int = corners[i]
		var b: int = corners[(i + 1) % corners.size()]
		_add_beam_profile(model, _node_index(station, a), _node_index(station, b), &"crossmember", &"cabin")
	_add_beam_profile(model, _node_index(station, 0), _node_index(station, 3), &"cross_diagonal", &"cabin")
	_add_beam_profile(model, _node_index(station, 1), _node_index(station, 2), &"cross_diagonal", &"cabin")

static func _add_longitudinal_segment(model: StructuralModel, rear_station: int, front_station: int) -> void:
	var profile: StringName
	if rear_station >= 3:
		profile = &"front_crush"
	elif rear_station == 2:
		profile = &"transition"
	else:
		profile = &"cabin"

	for corner in range(4):
		_add_beam_profile(
			model,
			_node_index(rear_station, corner),
			_node_index(front_station, corner),
			&"longitudinal",
			profile
		)

	_add_beam_profile(model, _node_index(rear_station, 0), _node_index(front_station, 2), &"side_diagonal", profile)
	_add_beam_profile(model, _node_index(rear_station, 2), _node_index(front_station, 0), &"side_diagonal", profile)
	_add_beam_profile(model, _node_index(rear_station, 1), _node_index(front_station, 3), &"side_diagonal", profile)
	_add_beam_profile(model, _node_index(rear_station, 3), _node_index(front_station, 1), &"side_diagonal", profile)
	_add_beam_profile(model, _node_index(rear_station, 0), _node_index(front_station, 1), &"floor_diagonal", profile)
	_add_beam_profile(model, _node_index(rear_station, 1), _node_index(front_station, 0), &"floor_diagonal", profile)
	_add_beam_profile(model, _node_index(rear_station, 2), _node_index(front_station, 3), &"roof_diagonal", profile)
	_add_beam_profile(model, _node_index(rear_station, 3), _node_index(front_station, 2), &"roof_diagonal", profile)

static func _add_beam_profile(model: StructuralModel, a: int, b: int, role: StringName, profile: StringName) -> void:
	match profile:
		&"front_crush":
			model.add_beam(a, b, role, 850000.0, 3600.0, 0.035, 0.52, 0.68, 18.0)
		&"transition":
			model.add_beam(a, b, role, 1800000.0, 5200.0, 0.05, 0.34, 0.52, 12.0)
		_:
			model.add_beam(a, b, role, 4200000.0, 7200.0, 0.075, 0.20, 0.36, 7.0)
