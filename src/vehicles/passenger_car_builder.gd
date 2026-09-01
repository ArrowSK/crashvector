# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name PassengerCarBuilder
extends RefCounted

static func build(
	preset_id: StringName = PassengerCarCatalog.B_SEGMENT_HATCHBACK,
	total_mass_kg: float = -1.0,
	speed_kmh: float = 50.0,
	barrier_x_m: float = 5.0,
	origin_offset_m: Vector3 = Vector3.ZERO
) -> StructuralModel:
	var preset := PassengerCarCatalog.data(preset_id)
	var model := StructuralModel.new()
	model.barrier_x_m = barrier_x_m
	var mass := total_mass_kg
	if mass <= 0.0:
		mass = float(preset.get("default_mass_kg", 1150.0))
	mass = maxf(mass, 1.0)
	var scale_x := float(preset.get("scale_x", 1.0))
	var scale_y := float(preset.get("scale_y", 1.0))
	var scale_z := float(preset.get("scale_z", 1.0))
	var stiffness_scale := float(preset.get("stiffness_scale", 1.0))

	for station in range(CompactHatchbackBuilder.STATION_X.size()):
		var node_mass := mass * CompactHatchbackBuilder.STATION_MASS_SHARE[station] / 4.0
		var x := CompactHatchbackBuilder.STATION_X[station] * scale_x
		var lower := CompactHatchbackBuilder.LOWER_Y[station] * scale_y
		var upper := CompactHatchbackBuilder.UPPER_Y[station] * scale_y
		var half_width := CompactHatchbackBuilder.HALF_WIDTH_Z[station] * scale_z
		model.add_node(origin_offset_m + Vector3(x, lower, -half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, lower, half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, upper, -half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, upper, half_width), node_mass)

	for station in range(CompactHatchbackBuilder.STATION_X.size()):
		_add_cross_section(model, station, stiffness_scale)
	for station in range(CompactHatchbackBuilder.STATION_X.size() - 1):
		_add_longitudinal_segment(model, station, station + 1, stiffness_scale)
	_add_passenger_cell_reinforcement(model, stiffness_scale)
	model.set_uniform_velocity(Vector3.RIGHT * PhysicsMetrics.kmh_to_ms(speed_kmh))
	return model

static func _add_cross_section(model: StructuralModel, station: int, stiffness_scale: float) -> void:
	var profile := _profile_for_station(station)
	var corners := [0, 1, 3, 2]
	for i in range(corners.size()):
		_add_profile_beam(model, CompactHatchbackBuilder.node_index(station, corners[i]), CompactHatchbackBuilder.node_index(station, corners[(i + 1) % corners.size()]), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(station, 0), CompactHatchbackBuilder.node_index(station, 3), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(station, 1), CompactHatchbackBuilder.node_index(station, 2), profile, stiffness_scale)

static func _add_longitudinal_segment(model: StructuralModel, rear_station: int, front_station: int, stiffness_scale: float) -> void:
	var profile := _profile_for_segment(rear_station)
	for corner in range(4):
		_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, corner), CompactHatchbackBuilder.node_index(front_station, corner), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 0), CompactHatchbackBuilder.node_index(front_station, 2), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 2), CompactHatchbackBuilder.node_index(front_station, 0), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 1), CompactHatchbackBuilder.node_index(front_station, 3), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 3), CompactHatchbackBuilder.node_index(front_station, 1), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 0), CompactHatchbackBuilder.node_index(front_station, 1), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 1), CompactHatchbackBuilder.node_index(front_station, 0), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 2), CompactHatchbackBuilder.node_index(front_station, 3), profile, stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 3), CompactHatchbackBuilder.node_index(front_station, 2), profile, stiffness_scale)

static func _add_passenger_cell_reinforcement(model: StructuralModel, stiffness_scale: float) -> void:
	for rear_station in range(CompactHatchbackBuilder.CABIN_REAR_STATION, CompactHatchbackBuilder.CABIN_FRONT_STATION):
		var front_station := rear_station + 1
		_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 0), CompactHatchbackBuilder.node_index(front_station, 3), &"safety_cell", stiffness_scale)
		_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 1), CompactHatchbackBuilder.node_index(front_station, 2), &"safety_cell", stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_REAR_STATION, 0), CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_FRONT_STATION, 2), &"safety_cell", stiffness_scale)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_REAR_STATION, 1), CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_FRONT_STATION, 3), &"safety_cell", stiffness_scale)

static func _profile_for_station(station: int) -> StringName:
	if station == CompactHatchbackBuilder.REAR_STATION:
		return &"rear_crush"
	if station >= CompactHatchbackBuilder.CABIN_REAR_STATION and station <= CompactHatchbackBuilder.CABIN_FRONT_STATION:
		return &"safety_cell"
	if station == CompactHatchbackBuilder.FRONT_AXLE_STATION:
		return &"front_transition"
	return &"front_crush"

static func _profile_for_segment(rear_station: int) -> StringName:
	if rear_station == CompactHatchbackBuilder.REAR_STATION:
		return &"rear_crush"
	if rear_station >= CompactHatchbackBuilder.CABIN_REAR_STATION and rear_station < CompactHatchbackBuilder.CABIN_FRONT_STATION:
		return &"safety_cell"
	if rear_station == CompactHatchbackBuilder.CABIN_FRONT_STATION:
		return &"front_transition"
	return &"front_crush"

static func _add_profile_beam(model: StructuralModel, a: int, b: int, profile: StringName, stiffness_scale: float) -> void:
	var s := maxf(stiffness_scale, 0.1)
	match profile:
		&"front_crush":
			model.add_beam(a, b, profile, 900000.0 * s, 3800.0 * sqrt(s), 0.035, 0.55, 0.75, 18.0)
		&"front_transition":
			model.add_beam(a, b, profile, 2100000.0 * s, 5400.0 * sqrt(s), 0.050, 0.36, 0.56, 12.0)
		&"rear_crush":
			model.add_beam(a, b, profile, 1250000.0 * s, 4200.0 * sqrt(s), 0.040, 0.42, 0.64, 15.0)
		_:
			model.add_beam(a, b, &"safety_cell", 5400000.0 * s, 7600.0 * sqrt(s), 0.080, 0.16, 0.30, 6.0)
