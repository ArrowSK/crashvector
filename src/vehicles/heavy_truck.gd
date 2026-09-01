# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name HeavyTruck
extends Node3D

@export_range(1000.0, 60000.0, 100.0, "or_greater") var total_mass_kg: float = 18000.0
@export_range(0.0, 140.0, 1.0, "or_greater") var initial_speed_kmh: float = 0.0
@export var origin_offset_m: Vector3 = Vector3(2.0, 0.0, 0.0)
@export_range(1, 16, 1) var solver_substeps: int = 6
@export var show_structure: bool = false
@export var auto_step: bool = true

var model: StructuralModel
var debug_renderer: StructuralDebugRenderer
var trailer_visual: MeshInstance3D
var cab_visual: MeshInstance3D
var chassis_visual: MeshInstance3D
var underride_visual: MeshInstance3D
var wheel_visuals: Array[MeshInstance3D] = []

func _ready() -> void:
	model = HeavyTruckBuilder.build(total_mass_kg, initial_speed_kmh, origin_offset_m)
	_build_visuals()
	_build_structure_debugger()
	update_from_model()

func _physics_process(delta: float) -> void:
	if model == null or not auto_step:
		return
	model.step(delta, solver_substeps)
	update_from_model()

func step_external(_delta: float) -> void:
	update_from_model()

func toggle_structure_debug() -> void:
	show_structure = not show_structure
	if debug_renderer != null:
		debug_renderer.visible = show_structure

func global_linear_velocity_ms() -> Vector3:
	return VehicleKinematics.linear_velocity_ms(model)

func rear_guard_deformation_m() -> float:
	return model.max_permanent_deformation_for_role(&"underride_guard")

func _build_visuals() -> void:
	trailer_visual = _create_box("Trailer", Vector3(5.25, 2.72, 2.38), Color(0.73, 0.75, 0.78))
	cab_visual = _create_box("TractorCab", Vector3(2.55, 2.45, 2.25), Color(0.16, 0.30, 0.48))
	chassis_visual = _create_box("Chassis", Vector3(9.25, 0.18, 1.85), Color(0.08, 0.09, 0.10))
	underride_visual = _create_box("RearUnderrideGuard", Vector3(0.16, 0.20, 2.15), Color(0.16, 0.17, 0.18))

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.43
	wheel_mesh.bottom_radius = 0.43
	wheel_mesh.height = 0.30
	wheel_mesh.radial_segments = 14
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color(0.035, 0.035, 0.04)
	wheel_material.roughness = 0.95
	wheel_mesh.material = wheel_material
	for index in HeavyTruckBuilder.wheel_anchor_indices():
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.rotation_degrees.x = 90.0
		wheel.set_meta("anchor_index", index)
		add_child(wheel)
		wheel_visuals.append(wheel)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "TruckStructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func _create_box(node_name: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.10
	material.roughness = 0.65
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance

func update_from_model() -> void:
	if model == null:
		return
	var trailer_nodes := _station_range_nodes(1, HeavyTruckBuilder.TRAILER_END_STATION)
	var tractor_nodes := _station_range_nodes(5, HeavyTruckBuilder.FRONT_STATION)
	var chassis_nodes := _station_range_nodes(0, HeavyTruckBuilder.FRONT_STATION)
	trailer_visual.position = model.average_position_for_nodes(trailer_nodes) + Vector3(0.0, 0.15, 0.0)
	cab_visual.position = model.average_position_for_nodes(tractor_nodes) + Vector3(0.0, -0.05, 0.0)
	chassis_visual.position = model.average_position_for_nodes(chassis_nodes) + Vector3(0.0, -0.65, 0.0)
	underride_visual.position = model.average_position_for_nodes(HeavyTruckBuilder.rear_contact_nodes())

	for wheel in wheel_visuals:
		var index := int(wheel.get_meta("anchor_index"))
		if index >= 0 and index < model.nodes.size():
			wheel.position = model.nodes[index].position_m + Vector3(0.0, -0.24, 0.0)
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _station_range_nodes(first_station: int, last_station: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for station in range(first_station, last_station + 1):
		for corner in range(4):
			indices.append(HeavyTruckBuilder.node_index(station, corner))
	return indices
