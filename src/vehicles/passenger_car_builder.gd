# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name PassengerCarBuilder
extends RefCounted

# M11 production structure keeps the original seven visible/reference stations
# at their historical indices, then inserts four additional cross-sections in
# the engine bay. This preserves the M2/M10 reference API while giving the
# crush zone enough longitudinal resolution to shorten and fold progressively.
const M11_EXTRA_SECTION_X: Array[float] = [0.94, 1.16, 1.58, 1.80]
const M11_BASE_MASS_SHARE: Array[float] = [0.08, 0.13, 0.17, 0.18, 0.08, 0.08, 0.05]
const M11_EXTRA_MASS_SHARE: Array[float] = [0.06, 0.06, 0.06, 0.05]
const BASE_NODE_COUNT: int = 28

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

	_add_base_nodes(model, mass, scale_x, scale_y, scale_z, origin_offset_m)
	_add_extra_front_nodes(model, mass, scale_x, scale_y, scale_z, origin_offset_m)

	for station in range(CompactHatchbackBuilder.STATION_X.size()):
		_add_base_cross_section(model, station, stiffness_scale)
	# Retain the historical rear/cabin topology through the firewall. The two
	# coarse engine-bay links are deliberately replaced by the refined chain.
	for station in range(CompactHatchbackBuilder.CABIN_FRONT_STATION):
		_add_base_longitudinal_segment(model, station, station + 1, stiffness_scale)
	_add_passenger_cell_reinforcement(model, stiffness_scale)
	_add_refined_front_structure(model, stiffness_scale)
	_add_bending_constraints(model, stiffness_scale)
	model.set_uniform_velocity(Vector3.RIGHT * PhysicsMetrics.kmh_to_ms(speed_kmh))
	return model

static func extra_node_index(section: int, corner: int) -> int:
	return BASE_NODE_COUNT + section * 4 + corner

static func extra_section_nodes(section: int) -> PackedInt32Array:
	return PackedInt32Array([
		extra_node_index(section, 0),
		extra_node_index(section, 1),
		extra_node_index(section, 2),
		extra_node_index(section, 3),
	])

static func front_contact_nodes() -> PackedInt32Array:
	return CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_STATION)

static func front_crush_section_nodes() -> Array[PackedInt32Array]:
	return [
		CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.CABIN_FRONT_STATION),
		extra_section_nodes(0),
		extra_section_nodes(1),
		CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_AXLE_STATION),
		extra_section_nodes(2),
		extra_section_nodes(3),
		CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_STATION),
	]

static func _add_base_nodes(
	model: StructuralModel,
	mass: float,
	scale_x: float,
	scale_y: float,
	scale_z: float,
	origin_offset_m: Vector3
) -> void:
	for station in range(CompactHatchbackBuilder.STATION_X.size()):
		var node_mass := mass * M11_BASE_MASS_SHARE[station] / 4.0
		var x := CompactHatchbackBuilder.STATION_X[station] * scale_x
		var lower := CompactHatchbackBuilder.LOWER_Y[station] * scale_y
		var upper := CompactHatchbackBuilder.UPPER_Y[station] * scale_y
		var half_width := CompactHatchbackBuilder.HALF_WIDTH_Z[station] * scale_z
		model.add_node(origin_offset_m + Vector3(x, lower, -half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, lower, half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, upper, -half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, upper, half_width), node_mass)

static func _add_extra_front_nodes(
	model: StructuralModel,
	mass: float,
	scale_x: float,
	scale_y: float,
	scale_z: float,
	origin_offset_m: Vector3
) -> void:
	for section in range(M11_EXTRA_SECTION_X.size()):
		var rear_station := CompactHatchbackBuilder.CABIN_FRONT_STATION if section < 2 else CompactHatchbackBuilder.FRONT_AXLE_STATION
		var front_station := CompactHatchbackBuilder.FRONT_AXLE_STATION if section < 2 else CompactHatchbackBuilder.FRONT_STATION
		var local_x := M11_EXTRA_SECTION_X[section]
		var rear_x := CompactHatchbackBuilder.STATION_X[rear_station]
		var front_x := CompactHatchbackBuilder.STATION_X[front_station]
		var t := clampf((local_x - rear_x) / maxf(front_x - rear_x, 0.0001), 0.0, 1.0)
		var lower := lerpf(CompactHatchbackBuilder.LOWER_Y[rear_station], CompactHatchbackBuilder.LOWER_Y[front_station], t) * scale_y
		var upper := lerpf(CompactHatchbackBuilder.UPPER_Y[rear_station], CompactHatchbackBuilder.UPPER_Y[front_station], t) * scale_y
		var half_width := lerpf(CompactHatchbackBuilder.HALF_WIDTH_Z[rear_station], CompactHatchbackBuilder.HALF_WIDTH_Z[front_station], t) * scale_z
		var node_mass := mass * M11_EXTRA_MASS_SHARE[section] / 4.0
		var x := local_x * scale_x
		model.add_node(origin_offset_m + Vector3(x, lower, -half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, lower, half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, upper, -half_width), node_mass)
		model.add_node(origin_offset_m + Vector3(x, upper, half_width), node_mass)

static func _add_base_cross_section(model: StructuralModel, station: int, stiffness_scale: float) -> void:
	var profile := _profile_for_station(station)
	var component := &"body_cross_member"
	if station == CompactHatchbackBuilder.FRONT_STATION:
		component = &"nose_structure"
	elif station == CompactHatchbackBuilder.FRONT_AXLE_STATION:
		component = &"front_axle_cross_member"
	var nodes := CompactHatchbackBuilder.station_nodes(station)
	_add_cross_section_indices(model, nodes, profile, component, stiffness_scale)

static func _add_cross_section_indices(
	model: StructuralModel,
	indices: PackedInt32Array,
	profile: StringName,
	component: StringName,
	stiffness_scale: float
) -> void:
	var corners: Array[int] = [0, 1, 3, 2]
	for i in range(corners.size()):
		_add_profile_beam(model, indices[corners[i]], indices[corners[(i + 1) % corners.size()]], profile, stiffness_scale, component, 0.55)
	_add_profile_beam(model, indices[0], indices[3], profile, stiffness_scale, component, 0.38)
	_add_profile_beam(model, indices[1], indices[2], profile, stiffness_scale, component, 0.38)

static func _add_base_longitudinal_segment(model: StructuralModel, rear_station: int, front_station: int, stiffness_scale: float) -> void:
	var profile := _profile_for_segment(rear_station)
	var rear := CompactHatchbackBuilder.station_nodes(rear_station)
	var front := CompactHatchbackBuilder.station_nodes(front_station)
	for corner in range(4):
		_add_profile_beam(model, rear[corner], front[corner], profile, stiffness_scale, &"body_longitudinal", 1.0)
	_add_profile_beam(model, rear[0], front[2], profile, stiffness_scale, &"body_brace", 0.65)
	_add_profile_beam(model, rear[2], front[0], profile, stiffness_scale, &"body_brace", 0.65)
	_add_profile_beam(model, rear[1], front[3], profile, stiffness_scale, &"body_brace", 0.65)
	_add_profile_beam(model, rear[3], front[1], profile, stiffness_scale, &"body_brace", 0.65)
	_add_profile_beam(model, rear[0], front[1], profile, stiffness_scale, &"floor_cross_brace", 0.48)
	_add_profile_beam(model, rear[1], front[0], profile, stiffness_scale, &"floor_cross_brace", 0.48)
	_add_profile_beam(model, rear[2], front[3], profile, stiffness_scale, &"roof_cross_brace", 0.48)
	_add_profile_beam(model, rear[3], front[2], profile, stiffness_scale, &"roof_cross_brace", 0.48)

static func _add_refined_front_structure(model: StructuralModel, stiffness_scale: float) -> void:
	for section in range(M11_EXTRA_SECTION_X.size()):
		var profile: StringName = &"front_transition" if section < 2 else &"front_crush"
		var component: StringName = &"subframe_cross_member" if section < 2 else &"crush_cross_member"
		_add_cross_section_indices(model, extra_section_nodes(section), profile, component, stiffness_scale)

	var sections := front_crush_section_nodes()
	var segment_roles: Array[StringName] = [
		&"front_transition", &"front_transition", &"front_transition",
		&"front_crush", &"front_crush", &"front_crush",
	]
	var segment_components: Array[StringName] = [
		&"firewall_transition", &"subframe", &"front_rail",
		&"front_rail", &"crash_box", &"crash_box",
	]
	for segment in range(sections.size() - 1):
		_add_front_segment(
			model,
			sections[segment],
			sections[segment + 1],
			segment_roles[segment],
			segment_components[segment],
			stiffness_scale
		)

	var nose := CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_STATION)
	_add_profile_beam(model, nose[0], nose[1], &"front_crush", stiffness_scale, &"bumper_beam", 1.45)
	_add_profile_beam(model, nose[2], nose[3], &"front_crush", stiffness_scale, &"upper_bumper_tie", 0.75)

static func _add_front_segment(
	model: StructuralModel,
	rear: PackedInt32Array,
	front: PackedInt32Array,
	profile: StringName,
	component: StringName,
	stiffness_scale: float
) -> void:
	for corner in range(4):
		var member_component: StringName = component if corner < 2 else &"upper_rail"
		var multiplier := 1.0 if corner < 2 else 0.68
		_add_profile_beam(model, rear[corner], front[corner], profile, stiffness_scale, member_component, multiplier)
	_add_profile_beam(model, rear[0], front[2], profile, stiffness_scale, &"crush_brace", 0.30)
	_add_profile_beam(model, rear[2], front[0], profile, stiffness_scale, &"crush_brace", 0.30)
	_add_profile_beam(model, rear[1], front[3], profile, stiffness_scale, &"crush_brace", 0.30)
	_add_profile_beam(model, rear[3], front[1], profile, stiffness_scale, &"crush_brace", 0.30)
	_add_profile_beam(model, rear[0], front[1], profile, stiffness_scale, &"lower_cross_tie", 0.22)
	_add_profile_beam(model, rear[1], front[0], profile, stiffness_scale, &"lower_cross_tie", 0.22)

static func _add_passenger_cell_reinforcement(model: StructuralModel, stiffness_scale: float) -> void:
	for rear_station in range(CompactHatchbackBuilder.CABIN_REAR_STATION, CompactHatchbackBuilder.CABIN_FRONT_STATION):
		var front_station := rear_station + 1
		_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 0), CompactHatchbackBuilder.node_index(front_station, 3), &"safety_cell", stiffness_scale, &"safety_cell_diagonal", 1.0)
		_add_profile_beam(model, CompactHatchbackBuilder.node_index(rear_station, 1), CompactHatchbackBuilder.node_index(front_station, 2), &"safety_cell", stiffness_scale, &"safety_cell_diagonal", 1.0)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_REAR_STATION, 0), CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_FRONT_STATION, 2), &"safety_cell", stiffness_scale, &"safety_cell_long_diagonal", 1.25)
	_add_profile_beam(model, CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_REAR_STATION, 1), CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_FRONT_STATION, 3), &"safety_cell", stiffness_scale, &"safety_cell_long_diagonal", 1.25)
	# Long rocker/roof ties keep the protected cell ordered longitudinally after
	# the engine-bay crush sections have exhausted their travel. They are not a
	# rigid proxy: they use the same plastic safety-cell beam law, but span the
	# complete cabin so adjacent stations cannot fold through one another.
	for corner in range(4):
		_add_profile_beam(
			model,
			CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_REAR_STATION, corner),
			CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.CABIN_FRONT_STATION, corner),
			&"safety_cell", stiffness_scale, &"safety_cell_longitudinal_tie", 1.60
		)

static func _add_bending_constraints(model: StructuralModel, stiffness_scale: float) -> void:
	var s := maxf(stiffness_scale, 0.1)
	var sections := front_crush_section_nodes()
	for corner in range(4):
		for section in range(1, sections.size() - 1):
			var component: StringName = &"front_rail_fold" if corner < 2 else &"upper_rail_fold"
			var k := (22000.0 if corner < 2 else 14000.0) * s
			model.add_bending_constraint(
				sections[section - 1][corner], sections[section][corner], sections[section + 1][corner],
				&"front_bending", k, 420.0 * sqrt(s), deg_to_rad(6.0), deg_to_rad(68.0), deg_to_rad(118.0), 18.0, component
			)

	for corner in range(4):
		for station in range(CompactHatchbackBuilder.CABIN_REAR_STATION + 1, CompactHatchbackBuilder.CABIN_FRONT_STATION):
			model.add_bending_constraint(
				CompactHatchbackBuilder.node_index(station - 1, corner),
				CompactHatchbackBuilder.node_index(station, corner),
				CompactHatchbackBuilder.node_index(station + 1, corner),
				&"safety_cell_bending", 110000.0 * s, 1350.0 * sqrt(s), deg_to_rad(3.0), deg_to_rad(15.0), deg_to_rad(45.0), 2.5, &"safety_cell"
			)

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

static func _add_profile_beam(
	model: StructuralModel,
	a: int,
	b: int,
	profile: StringName,
	stiffness_scale: float,
	component: StringName = &"",
	member_multiplier: float = 1.0
) -> StructuralBeam:
	var s := maxf(stiffness_scale, 0.1)
	var m := maxf(member_multiplier, 0.05)
	var beam: StructuralBeam
	match profile:
		&"front_crush":
			beam = model.add_beam(a, b, profile, 420000.0 * s * m, 1800.0 * sqrt(s) * sqrt(m), 0.025, 0.66, 0.92, 34.0)
			beam.configure_progressive_curve(0.18, 0.46, 0.72, component)
		&"front_transition":
			beam = model.add_beam(a, b, profile, 900000.0 * s * m, 2800.0 * sqrt(s) * sqrt(m), 0.035, 0.44, 0.72, 23.0)
			beam.configure_progressive_curve(0.28, 0.34, 0.85, component)
		&"rear_crush":
			beam = model.add_beam(a, b, profile, 1250000.0 * s * m, 4200.0 * sqrt(s) * sqrt(m), 0.040, 0.42, 0.64, 15.0)
			beam.configure_progressive_curve(0.42, 0.32, 0.70, component)
		_:
			# The protected cell is allowed to yield, but unlike the front rails it
			# hardens strongly before its longitudinal members can collapse through
			# zero length and re-open in an inverted topology. Break strain above
			# 100% compression is deliberate for this generic cell representation.
			beam = model.add_beam(a, b, &"safety_cell", 7200000.0 * s * m, 9000.0 * sqrt(s) * sqrt(m), 0.080, 0.28, 1.05, 4.0)
			beam.configure_progressive_curve(0.58, 0.28, 2.80, component)
	return beam
