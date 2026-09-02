# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name BicycleBuilder
extends RefCounted

const STATION_X: Array[float] = [-0.72, -0.24, 0.26, 0.74]
const LOWER_Y: Array[float] = [0.34, 0.48, 0.52, 0.34]
const UPPER_Y: Array[float] = [0.34, 0.82, 0.92, 0.34]
const HALF_WIDTH_Z: Array[float] = [0.07, 0.11, 0.10, 0.07]
const STATION_MASS_SHARE: Array[float] = [0.23, 0.29, 0.28, 0.20]
const REAR_STATION: int = 0
const FRONT_STATION: int = 3

static func build(
	preset_id: StringName = RoadUserCatalog.BICYCLE_CITY,
	total_mass_kg: float = 16.0,
	speed_kmh: float = 0.0,
	origin_offset_m: Vector3 = Vector3.ZERO
) -> StructuralModel:
	var model := StructuralModel.new()
	model.barrier_enabled = false
	var default_mass := RoadUserCatalog.default_mass_kg(preset_id)
	var mass := maxf(total_mass_kg if total_mass_kg > 0.0 else default_mass, 5.0)
	var stiffness_scale := 1.0
	if preset_id == RoadUserCatalog.BICYCLE_ROAD:
		stiffness_scale = 1.08
	elif preset_id == RoadUserCatalog.BICYCLE_EBIKE:
		stiffness_scale = 1.14
	for station in range(STATION_X.size()):
		var node_mass := mass * STATION_MASS_SHARE[station] / 4.0
		model.add_node(origin_offset_m + Vector3(STATION_X[station], LOWER_Y[station], -HALF_WIDTH_Z[station]), node_mass)
		model.add_node(origin_offset_m + Vector3(STATION_X[station], LOWER_Y[station], HALF_WIDTH_Z[station]), node_mass)
		model.add_node(origin_offset_m + Vector3(STATION_X[station], UPPER_Y[station], -HALF_WIDTH_Z[station]), node_mass)
		model.add_node(origin_offset_m + Vector3(STATION_X[station], UPPER_Y[station], HALF_WIDTH_Z[station]), node_mass)
	for station in range(STATION_X.size()):
		_add_cross_section(model, station, stiffness_scale)
	for station in range(STATION_X.size() - 1):
		_add_longitudinal_segment(model, station, station + 1, stiffness_scale)
	model.set_uniform_velocity(Vector3.RIGHT * PhysicsMetrics.kmh_to_ms(speed_kmh))
	return model

static func node_index(station: int, corner: int) -> int:
	return station * 4 + corner

static func rear_contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([node_index(REAR_STATION, 0), node_index(REAR_STATION, 1)])

static func front_contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([node_index(FRONT_STATION, 0), node_index(FRONT_STATION, 1)])

static func _add_cross_section(model: StructuralModel, station: int, stiffness_scale: float) -> void:
	var role := &"bicycle_frame"
	if station == FRONT_STATION:
		role = &"bicycle_fork"
	var corners: Array[int] = [0, 1, 3, 2]
	for i in range(corners.size()):
		_add_beam(model, node_index(station, corners[i]), node_index(station, corners[(i + 1) % corners.size()]), role, stiffness_scale)
	_add_beam(model, node_index(station, 0), node_index(station, 3), role, stiffness_scale)
	_add_beam(model, node_index(station, 1), node_index(station, 2), role, stiffness_scale)

static func _add_longitudinal_segment(model: StructuralModel, rear_station: int, front_station: int, stiffness_scale: float) -> void:
	var role := &"bicycle_frame" if front_station != FRONT_STATION else &"bicycle_fork"
	for corner in range(4):
		_add_beam(model, node_index(rear_station, corner), node_index(front_station, corner), role, stiffness_scale)
	_add_beam(model, node_index(rear_station, 0), node_index(front_station, 3), role, stiffness_scale)
	_add_beam(model, node_index(rear_station, 1), node_index(front_station, 2), role, stiffness_scale)

static func _add_beam(model: StructuralModel, a: int, b: int, role: StringName, stiffness_scale: float) -> void:
	if role == &"bicycle_fork":
		model.add_beam(a, b, role, 170000.0 * stiffness_scale, 520.0, 0.045, 0.34, 0.62, 12.0)
	else:
		model.add_beam(a, b, role, 260000.0 * stiffness_scale, 680.0, 0.060, 0.26, 0.50, 10.0)
