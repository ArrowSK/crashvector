# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name MotorcycleBuilder
extends RefCounted

# Riderless generic road-motorcycle structural approximation. The rider is
# intentionally outside the model: no rider kinematics or injury inference is
# performed anywhere in CrashVector.
const STATION_X: Array[float] = [0.0, 0.65, 1.35, 1.95]
const LOWER_Y: Array[float] = [0.34, 0.48, 0.52, 0.34]
const UPPER_Y: Array[float] = [0.72, 1.00, 1.08, 0.80]
const HALF_WIDTH_Z: Array[float] = [0.12, 0.20, 0.18, 0.12]
const STATION_MASS_SHARE: Array[float] = [0.24, 0.28, 0.28, 0.20]

const REAR_STATION: int = 0
const FRONT_STATION: int = 3

static func build(
	total_mass_kg: float = 220.0,
	speed_kmh: float = 0.0,
	origin_offset_m: Vector3 = Vector3.ZERO
) -> StructuralModel:
	var model := StructuralModel.new()
	model.barrier_enabled = false
	var mass := maxf(total_mass_kg, 50.0)
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

static func rear_contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([node_index(REAR_STATION, 0), node_index(REAR_STATION, 1)])

static func front_contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([node_index(FRONT_STATION, 0), node_index(FRONT_STATION, 1)])

static func wheel_anchor_indices() -> PackedInt32Array:
	return PackedInt32Array([
		node_index(REAR_STATION, 0), node_index(REAR_STATION, 1),
		node_index(FRONT_STATION, 0), node_index(FRONT_STATION, 1),
	])

static func _add_cross_section(model: StructuralModel, station: int) -> void:
	var role := &"motorcycle_frame"
	if station == REAR_STATION:
		role = &"motorcycle_rear"
	elif station == FRONT_STATION:
		role = &"motorcycle_fork"
	var corners: Array[int] = [0, 1, 3, 2]
	for i in range(corners.size()):
		_add_profile_beam(model, node_index(station, corners[i]), node_index(station, corners[(i + 1) % corners.size()]), role)
	_add_profile_beam(model, node_index(station, 0), node_index(station, 3), role)
	_add_profile_beam(model, node_index(station, 1), node_index(station, 2), role)

static func _add_longitudinal_segment(model: StructuralModel, rear_station: int, front_station: int) -> void:
	var role := &"motorcycle_frame"
	if rear_station == REAR_STATION:
		role = &"motorcycle_rear"
	elif front_station == FRONT_STATION:
		role = &"motorcycle_fork"
	for corner in range(4):
		_add_profile_beam(model, node_index(rear_station, corner), node_index(front_station, corner), role)
	_add_profile_beam(model, node_index(rear_station, 0), node_index(front_station, 3), role)
	_add_profile_beam(model, node_index(rear_station, 1), node_index(front_station, 2), role)
	_add_profile_beam(model, node_index(rear_station, 2), node_index(front_station, 1), role)
	_add_profile_beam(model, node_index(rear_station, 3), node_index(front_station, 0), role)

static func _add_profile_beam(model: StructuralModel, a: int, b: int, role: StringName) -> void:
	match role:
		&"motorcycle_fork":
			model.add_beam(a, b, role, 620000.0, 1500.0, 0.035, 0.30, 0.52, 12.0)
		&"motorcycle_rear":
			model.add_beam(a, b, role, 820000.0, 1800.0, 0.045, 0.24, 0.44, 10.0)
		_:
			model.add_beam(a, b, role, 1350000.0, 2200.0, 0.055, 0.18, 0.34, 8.0)
