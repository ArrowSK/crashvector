# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name DeformableBodyShell
extends Node3D

var model: StructuralModel
var station_count := 0
var vehicle_preset_id: StringName = PassengerCarCatalog.B_SEGMENT_HATCHBACK
var paint_color: Color = CarPaintCatalog.color(CarPaintCatalog.ELECTRIC_BLUE)

var body_mesh := ImmediateMesh.new()
var glass_mesh := ImmediateMesh.new()
var trim_mesh := ImmediateMesh.new()
var body_instance := MeshInstance3D.new()
var glass_instance := MeshInstance3D.new()
var trim_instance := MeshInstance3D.new()
var body_material := StandardMaterial3D.new()
var glass_material := StandardMaterial3D.new()
var trim_material := StandardMaterial3D.new()
var headlamps: Array[MeshInstance3D] = []
var tail_lamps: Array[MeshInstance3D] = []
var rocker_visuals: Array[MeshInstance3D] = []

func configure(
	structural_model: StructuralModel,
	stations: int,
	color: Color = Color(0.035, 0.28, 0.82),
	preset_id: StringName = PassengerCarCatalog.B_SEGMENT_HATCHBACK
) -> void:
	model = structural_model
	station_count = maxi(stations, 0)
	paint_color = color
	vehicle_preset_id = preset_id
	_build_materials()
	body_instance.name = "PaintedBody"
	body_instance.mesh = body_mesh
	add_child(body_instance)
	glass_instance.name = "Glazing"
	glass_instance.mesh = glass_mesh
	add_child(glass_instance)
	trim_instance.name = "WindowTrim"
	trim_instance.mesh = trim_mesh
	add_child(trim_instance)
	_build_detail_visuals()
	update_from_model()

func set_paint_color(color: Color) -> void:
	paint_color = color
	body_material.albedo_color = color

func _build_materials() -> void:
	body_material.albedo_color = paint_color
	body_material.metallic = 0.42
	body_material.roughness = 0.23
	body_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.albedo_color = Color(0.045, 0.075, 0.105)
	glass_material.metallic = 0.12
	glass_material.roughness = 0.10
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trim_material.albedo_color = Color(0.018, 0.025, 0.035)
	trim_material.metallic = 0.18
	trim_material.roughness = 0.40

func _build_detail_visuals() -> void:
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(0.86, 0.92, 0.98)
	head_material.emission_enabled = true
	head_material.emission = Color(0.30, 0.40, 0.52)
	head_material.emission_energy_multiplier = 0.25
	head_material.roughness = 0.16
	var tail_material := StandardMaterial3D.new()
	tail_material.albedo_color = Color(0.68, 0.025, 0.020)
	tail_material.emission_enabled = true
	tail_material.emission = Color(0.34, 0.008, 0.006)
	tail_material.emission_energy_multiplier = 0.20
	tail_material.roughness = 0.20
	for side in [-1.0, 1.0]:
		var head := _make_box_detail("Headlamp", Vector3(0.14, 0.17, 0.32), head_material)
		head.set_meta("side", side)
		headlamps.append(head)
		var tail := _make_box_detail("TailLamp", Vector3(0.12, 0.19, 0.28), tail_material)
		tail.set_meta("side", side)
		tail_lamps.append(tail)
	var rocker_material := StandardMaterial3D.new()
	rocker_material.albedo_color = Color(0.028, 0.038, 0.050)
	rocker_material.metallic = 0.18
	rocker_material.roughness = 0.54
	for side in [-1.0, 1.0]:
		var rocker := _make_box_detail("RockerTrim", Vector3(2.0, 0.09, 0.07), rocker_material)
		rocker.set_meta("side", side)
		rocker_visuals.append(rocker)

func _make_box_detail(node_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance

func update_from_model() -> void:
	if model == null or station_count < 2:
		return
	_build_body_surface()
	_build_glazing_surface()
	_build_trim_surface()
	_update_lamps()
	_update_rockers()

func _build_body_surface() -> void:
	body_mesh.clear_surfaces()
	body_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, body_material)

	# Rear body and passenger cell retain the M10 visual stations. The M11
	# production car then switches to the refined engine-bay section chain so
	# crash-box/rail folding is visible in the painted body instead of being
	# hidden behind two coarse interpolation spans.
	var cabin_front := mini(CompactHatchbackBuilder.CABIN_FRONT_STATION, station_count - 1)
	for station in range(cabin_front):
		_add_body_span(
			_lower(station, 0), _lower(station, 1),
			_visual_upper(station, 0), _visual_upper(station, 1),
			_lower(station + 1, 0), _lower(station + 1, 1),
			_visual_upper(station + 1, 0), _visual_upper(station + 1, 1)
		)

	if model.nodes.size() >= PassengerCarBuilder.BASE_NODE_COUNT + PassengerCarBuilder.M11_EXTRA_SECTION_X.size() * 4:
		var refined := PassengerCarBuilder.front_crush_section_nodes()
		for section in range(refined.size() - 1):
			var rear_points := _surface_points_for_refined_section(refined[section], section == 0)
			var front_points := _surface_points_for_refined_section(refined[section + 1], false)
			_add_body_span(
				rear_points[0], rear_points[1], rear_points[2], rear_points[3],
				front_points[0], front_points[1], front_points[2], front_points[3]
			)
	else:
		for station in range(cabin_front, station_count - 1):
			_add_body_span(
				_lower(station, 0), _lower(station, 1),
				_visual_upper(station, 0), _visual_upper(station, 1),
				_lower(station + 1, 0), _lower(station + 1, 1),
				_visual_upper(station + 1, 0), _visual_upper(station + 1, 1)
			)

	_quad_on(body_mesh, _lower(0, 0), _visual_upper(0, 0), _visual_upper(0, 1), _lower(0, 1))
	var last := station_count - 1
	_quad_on(body_mesh, _lower(last, 0), _lower(last, 1), _visual_upper(last, 1), _visual_upper(last, 0))
	body_mesh.surface_end()

func _add_body_span(
	rear_lower_left: Vector3,
	rear_lower_right: Vector3,
	rear_upper_left: Vector3,
	rear_upper_right: Vector3,
	front_lower_left: Vector3,
	front_lower_right: Vector3,
	front_upper_left: Vector3,
	front_upper_right: Vector3
) -> void:
	_quad_on(body_mesh, rear_lower_left, front_lower_left, front_upper_left, rear_upper_left)
	_quad_on(body_mesh, rear_lower_right, rear_upper_right, front_upper_right, front_lower_right)
	_quad_on(body_mesh, rear_upper_left, front_upper_left, front_upper_right, rear_upper_right)
	_quad_on(body_mesh, rear_lower_left, rear_lower_right, front_lower_right, front_lower_left)

func _surface_points_for_refined_section(indices: PackedInt32Array, use_cabin_visual_upper: bool) -> Array[Vector3]:
	if use_cabin_visual_upper:
		return [
			model.nodes[indices[0]].position_m,
			model.nodes[indices[1]].position_m,
			_visual_upper(CompactHatchbackBuilder.CABIN_FRONT_STATION, 0),
			_visual_upper(CompactHatchbackBuilder.CABIN_FRONT_STATION, 1),
		]
	return [
		model.nodes[indices[0]].position_m,
		model.nodes[indices[1]].position_m,
		model.nodes[indices[2]].position_m,
		model.nodes[indices[3]].position_m,
	]

func _build_glazing_surface() -> void:
	glass_mesh.clear_surfaces()
	glass_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, glass_material)
	for station in range(CompactHatchbackBuilder.CABIN_REAR_STATION, CompactHatchbackBuilder.CABIN_FRONT_STATION):
		var next := station + 1
		for side in [0, 1]:
			var sign := -1.0 if side == 0 else 1.0
			var a_upper := _visual_upper(station, side)
			var b_upper := _visual_upper(next, side)
			var a_belt := _lower(station, side).lerp(a_upper, 0.56)
			var b_belt := _lower(next, side).lerp(b_upper, 0.56)
			var outward := _vehicle_right() * sign * 0.012
			if side == 0:
				_quad_on(glass_mesh, a_belt + outward, b_belt + outward, b_upper + outward, a_upper + outward)
			else:
				_quad_on(glass_mesh, a_belt + outward, a_upper + outward, b_upper + outward, b_belt + outward)
	var rear := CompactHatchbackBuilder.CABIN_REAR_STATION
	var front := CompactHatchbackBuilder.CABIN_FRONT_STATION
	_quad_on(glass_mesh,
		_lower(front, 0).lerp(_visual_upper(front, 0), 0.58),
		_lower(front, 1).lerp(_visual_upper(front, 1), 0.58),
		_visual_upper(front, 1), _visual_upper(front, 0))
	_quad_on(glass_mesh,
		_lower(rear, 1).lerp(_visual_upper(rear, 1), 0.58),
		_lower(rear, 0).lerp(_visual_upper(rear, 0), 0.58),
		_visual_upper(rear, 0), _visual_upper(rear, 1))
	glass_mesh.surface_end()

func _build_trim_surface() -> void:
	trim_mesh.clear_surfaces()
	trim_mesh.surface_begin(Mesh.PRIMITIVE_LINES, trim_material)
	for side in [0, 1]:
		for station in range(CompactHatchbackBuilder.CABIN_REAR_STATION, CompactHatchbackBuilder.CABIN_FRONT_STATION + 1):
			var upper := _visual_upper(station, side)
			var belt := _lower(station, side).lerp(upper, 0.56)
			_line_on(trim_mesh, belt, upper)
			if station < CompactHatchbackBuilder.CABIN_FRONT_STATION:
				var next_upper := _visual_upper(station + 1, side)
				var next_belt := _lower(station + 1, side).lerp(next_upper, 0.56)
				_line_on(trim_mesh, belt, next_belt)
				_line_on(trim_mesh, upper, next_upper)
	trim_mesh.surface_end()

func _update_lamps() -> void:
	var forward := _vehicle_forward()
	var right := _vehicle_right()
	var front_center := _station_center(CompactHatchbackBuilder.FRONT_STATION)
	var rear_center := _station_center(CompactHatchbackBuilder.REAR_STATION)
	var front_width := _station_half_width(CompactHatchbackBuilder.FRONT_STATION)
	var rear_width := _station_half_width(CompactHatchbackBuilder.REAR_STATION)
	var front_up := _station_up(CompactHatchbackBuilder.FRONT_STATION)
	var rear_up := _station_up(CompactHatchbackBuilder.REAR_STATION)
	for i in range(2):
		var side := float(headlamps[i].get_meta("side"))
		headlamps[i].position = front_center + forward * 0.095 + right * side * front_width * 0.64 + front_up * 0.08
		headlamps[i].basis = _detail_basis(forward, front_up)
		tail_lamps[i].position = rear_center - forward * 0.075 + right * side * rear_width * 0.68 + rear_up * 0.10
		tail_lamps[i].basis = _detail_basis(forward, rear_up)

func _update_rockers() -> void:
	var rear_station := CompactHatchbackBuilder.REAR_AXLE_STATION
	var front_station := CompactHatchbackBuilder.FRONT_AXLE_STATION
	var rear_center := _station_center(rear_station)
	var front_center := _station_center(front_station)
	var forward_vec := front_center - rear_center
	var length := forward_vec.length()
	if length <= 0.01:
		return
	var forward := forward_vec / length
	var up := (_station_up(rear_station) + _station_up(front_station)).normalized()
	var right := forward.cross(up).normalized()
	for rocker in rocker_visuals:
		var side := float(rocker.get_meta("side"))
		var mesh := rocker.mesh as BoxMesh
		mesh.size.x = maxf(length, 0.5)
		var half_width := (_station_half_width(rear_station) + _station_half_width(front_station)) * 0.5
		rocker.position = (rear_center + front_center) * 0.5 + right * side * (half_width + 0.015) - up * 0.30
		rocker.basis = _detail_basis(forward, up)

func _visual_upper(station: int, side: int) -> Vector3:
	var lower := _lower(station, side)
	var upper := _raw_upper(station, side)
	var up := (upper - lower).normalized()
	return upper + up * _profile_roof_offset(station)

func _profile_roof_offset(station: int) -> float:
	if station <= 0 or station >= station_count - 1:
		return 0.0
	match vehicle_preset_id:
		PassengerCarCatalog.A_SEGMENT_CITY:
			return 0.10 if station <= 4 else 0.02
		PassengerCarCatalog.C_SEGMENT_COMPACT:
			return -0.025 if station in [2, 3, 4] else 0.0
		PassengerCarCatalog.D_SEGMENT_MIDSIZE:
			return -0.055 if station in [2, 3, 4] else -0.015
		PassengerCarCatalog.J_SEGMENT_SUV:
			return 0.18 if station in [1, 2, 3, 4] else 0.08
		PassengerCarCatalog.M_SEGMENT_MPV:
			return 0.27 if station in [1, 2, 3, 4] else 0.15
		_:
			return 0.025 if station in [2, 3] else 0.0

func _lower(station: int, side: int) -> Vector3:
	return model.nodes[CompactHatchbackBuilder.node_index(station, side)].position_m

func _raw_upper(station: int, side: int) -> Vector3:
	return model.nodes[CompactHatchbackBuilder.node_index(station, side + 2)].position_m

func _station_center(station: int) -> Vector3:
	return model.average_position_for_nodes(CompactHatchbackBuilder.station_nodes(station))

func _station_half_width(station: int) -> float:
	return _lower(station, 0).distance_to(_lower(station, 1)) * 0.5

func _station_up(station: int) -> Vector3:
	var left := (_raw_upper(station, 0) - _lower(station, 0)).normalized()
	var right := (_raw_upper(station, 1) - _lower(station, 1)).normalized()
	var result := (left + right).normalized()
	return result if not result.is_zero_approx() else Vector3.UP

func _vehicle_forward() -> Vector3:
	var rear := _station_center(CompactHatchbackBuilder.REAR_AXLE_STATION)
	var front := _station_center(CompactHatchbackBuilder.FRONT_AXLE_STATION)
	var result := (front - rear).normalized()
	return result if not result.is_zero_approx() else Vector3.RIGHT

func _vehicle_right() -> Vector3:
	var forward := _vehicle_forward()
	var up := (_station_up(CompactHatchbackBuilder.REAR_AXLE_STATION) + _station_up(CompactHatchbackBuilder.FRONT_AXLE_STATION)).normalized()
	var result := forward.cross(up).normalized()
	return result if not result.is_zero_approx() else Vector3.FORWARD

func _detail_basis(forward: Vector3, up: Vector3) -> Basis:
	var x := forward.normalized()
	var y := up.normalized()
	var z := x.cross(y).normalized()
	if z.is_zero_approx():
		z = Vector3.FORWARD
	y = z.cross(x).normalized()
	return Basis(x, y, z)

func _quad_on(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle_on(mesh, a, b, c)
	_triangle_on(mesh, a, c, d)

func _triangle_on(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	for vertex in [a, b, c]:
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(vertex)

func _line_on(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
