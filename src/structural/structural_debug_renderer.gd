# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralDebugRenderer
extends Node3D

var model: StructuralModel
var beam_mesh := ImmediateMesh.new()
var beam_mesh_instance := MeshInstance3D.new()
var node_markers: Array[MeshInstance3D] = []
var beam_material := StandardMaterial3D.new()
var node_material := StandardMaterial3D.new()

func configure(structural_model: StructuralModel) -> void:
	model = structural_model
	_build_visuals()
	update_from_model()

func _build_visuals() -> void:
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.vertex_color_use_as_albedo = true
	beam_mesh_instance.mesh = beam_mesh
	add_child(beam_mesh_instance)

	node_material.albedo_color = Color(0.88, 0.91, 0.96)
	node_material.metallic = 0.20
	node_material.roughness = 0.40
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.055
	marker_mesh.height = 0.11
	marker_mesh.radial_segments = 8
	marker_mesh.rings = 5
	marker_mesh.material = node_material

	for node in model.nodes:
		var marker := MeshInstance3D.new()
		marker.mesh = marker_mesh
		marker.position = node.position_m
		add_child(marker)
		node_markers.append(marker)

func update_from_model() -> void:
	if model == null:
		return
	for i in range(mini(node_markers.size(), model.nodes.size())):
		node_markers[i].position = model.nodes[i].position_m

	beam_mesh.clear_surfaces()
	beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES, beam_material)
	for beam in model.beams:
		var color := _beam_color(beam)
		beam_mesh.surface_set_color(color)
		beam_mesh.surface_add_vertex(model.nodes[beam.node_a].position_m)
		beam_mesh.surface_set_color(color)
		beam_mesh.surface_add_vertex(model.nodes[beam.node_b].position_m)
	beam_mesh.surface_end()

func _beam_color(beam: StructuralBeam) -> Color:
	if beam.broken:
		return Color(0.95, 0.18, 0.15, 0.70)
	if beam.role == &"safety_cell":
		var ratio := absf(beam.last_total_strain) / maxf(beam.yield_strain, 0.001)
		return Color(0.30, 0.95, 0.52) if ratio < 0.75 else Color(0.98, 0.85, 0.18)
	var permanent := absf(beam.permanent_strain())
	if permanent > 0.02:
		return Color(1.0, 0.52, 0.10)
	var strain_ratio := absf(beam.last_total_strain) / maxf(beam.yield_strain, 0.001)
	if strain_ratio > 0.75:
		return Color(0.98, 0.82, 0.18)
	return Color(0.20, 0.78, 0.92)
