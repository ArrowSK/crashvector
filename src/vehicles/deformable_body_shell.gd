# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name DeformableBodyShell
extends Node3D

var model: StructuralModel
var station_count: int = 0
var body_mesh := ImmediateMesh.new()
var body_instance := MeshInstance3D.new()
var body_material := StandardMaterial3D.new()
var paint_color: Color = CarPaintCatalog.color(CarPaintCatalog.ELECTRIC_BLUE)

func configure(structural_model: StructuralModel, stations: int, color: Color = Color(0.035, 0.28, 0.82, 0.94)) -> void:
	model = structural_model
	station_count = maxi(stations, 0)
	paint_color = color
	_build_material()
	body_instance.mesh = body_mesh
	add_child(body_instance)
	update_from_model()

func set_paint_color(color: Color) -> void:
	paint_color = color
	body_material.albedo_color = paint_color

func _build_material() -> void:
	body_material.albedo_color = paint_color
	body_material.metallic = 0.34
	body_material.roughness = 0.28
	body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func update_from_model() -> void:
	if model == null or station_count < 2:
		return
	body_mesh.clear_surfaces()
	body_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, body_material)

	for station in range(station_count - 1):
		var next := station + 1
		# Left flank.
		_quad(
			_pos(station, 0), _pos(next, 0),
			_pos(next, 2), _pos(station, 2)
		)
		# Right flank.
		_quad(
			_pos(station, 1), _pos(station, 3),
			_pos(next, 3), _pos(next, 1)
		)
		# Roof / bonnet / hatch upper surface.
		_quad(
			_pos(station, 2), _pos(next, 2),
			_pos(next, 3), _pos(station, 3)
		)
		# Underbody.
		_quad(
			_pos(station, 0), _pos(station, 1),
			_pos(next, 1), _pos(next, 0)
		)

	# Rear and front caps.
	_quad(_pos(0, 0), _pos(0, 2), _pos(0, 3), _pos(0, 1))
	var last := station_count - 1
	_quad(_pos(last, 0), _pos(last, 1), _pos(last, 3), _pos(last, 2))
	body_mesh.surface_end()

func _pos(station: int, corner: int) -> Vector3:
	return model.nodes[CompactHatchbackBuilder.node_index(station, corner)].position_m

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(a, b, c)
	_triangle(a, c, d)

func _triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	for vertex in [a, b, c]:
		body_mesh.surface_set_normal(normal)
		body_mesh.surface_add_vertex(vertex)
