# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralSled
extends Node3D

@export_range(1.0, 100000.0, 1.0, "or_greater") var total_mass_kg: float = 1150.0
@export_range(1.0, 300.0, 1.0, "or_greater") var initial_speed_kmh: float = 50.0
@export var barrier_x_m: float = 5.0
@export_range(1, 16, 1) var solver_substeps: int = 4

var model: StructuralModel
var beam_mesh := ImmediateMesh.new()
var beam_mesh_instance := MeshInstance3D.new()
var node_markers: Array[MeshInstance3D] = []
var beam_material := StandardMaterial3D.new()
var node_material := StandardMaterial3D.new()

func _ready() -> void:
	model = StructuralSledBuilder.build_compact_sled(total_mass_kg, initial_speed_kmh, barrier_x_m)
	_build_debug_visuals()
	_update_debug_visuals()

func _physics_process(delta: float) -> void:
	if model == null:
		return
	model.step(delta, solver_substeps)
	_update_debug_visuals()

func _build_debug_visuals() -> void:
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.vertex_color_use_as_albedo = true
	beam_mesh_instance.mesh = beam_mesh
	add_child(beam_mesh_instance)

	node_material.albedo_color = Color(0.86, 0.90, 0.96)
	node_material.metallic = 0.25
	node_material.roughness = 0.35
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.075
	marker_mesh.height = 0.15
	marker_mesh.radial_segments = 10
	marker_mesh.rings = 6
	marker_mesh.material = node_material

	for node in model.nodes:
		var marker := MeshInstance3D.new()
		marker.mesh = marker_mesh
		marker.position = node.position_m
		add_child(marker)
		node_markers.append(marker)

func _update_debug_visuals() -> void:
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
		return Color(0.95, 0.20, 0.16, 0.55)
	var permanent := absf(beam.permanent_strain())
	if permanent > 0.02:
		return Color(1.0, 0.52, 0.10)
	var strain_ratio := absf(beam.last_total_strain) / maxf(beam.yield_strain, 0.001)
	if strain_ratio > 0.75:
		return Color(0.98, 0.82, 0.18)
	return Color(0.20, 0.78, 0.92)
