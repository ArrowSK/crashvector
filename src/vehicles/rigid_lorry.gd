# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RigidLorry
extends Node3D

@export_range(3500.0, 26000.0, 100.0, "or_greater") var total_mass_kg: float = 12000.0
@export_range(0.0, 140.0, 1.0, "or_greater") var initial_speed_kmh: float = 0.0
@export var origin_offset_m: Vector3 = Vector3(2.0, 0.0, 0.0)
@export_range(-180.0, 180.0, 1.0) var heading_deg: float = 0.0
@export_range(1, 16, 1) var solver_substeps: int = 6
@export var show_structure: bool = false
@export var auto_step: bool = true

var model: StructuralModel
var debug_renderer: StructuralDebugRenderer
var cargo_visual: MeshInstance3D
var cab_visual: MeshInstance3D
var chassis_visual: MeshInstance3D
var rear_guard_visual: MeshInstance3D
var wheel_visuals: Array[MeshInstance3D] = []

func _ready() -> void:
	model = RigidLorryBuilder.build(total_mass_kg, initial_speed_kmh, origin_offset_m)
	model.rotate_y_about(origin_offset_m, deg_to_rad(heading_deg), true)
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

func set_structure_debug(value: bool) -> void:
	show_structure = value
	if debug_renderer != null:
		debug_renderer.visible = value

func global_linear_velocity_ms() -> Vector3:
	return VehicleKinematics.linear_velocity_ms(model)

func rear_guard_deformation_m() -> float:
	return model.max_permanent_deformation_for_role(&"lorry_rear_guard")

func _build_visuals() -> void:
	cargo_visual = _create_box("CargoBody", Vector3(4.65, 2.70, 2.22), Color(0.70, 0.72, 0.75))
	cab_visual = _create_box("Cab", Vector3(2.35, 2.25, 2.05), Color(0.20, 0.38, 0.54))
	chassis_visual = _create_box("Chassis", Vector3(7.10, 0.18, 1.75), Color(0.08, 0.09, 0.10))
	rear_guard_visual = _create_box("RearGuard", Vector3(0.16, 0.18, 2.04), Color(0.16, 0.17, 0.18))

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.40
	wheel_mesh.bottom_radius = 0.40
	wheel_mesh.height = 0.28
	wheel_mesh.radial_segments = 14
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color(0.035, 0.035, 0.04)
	wheel_material.roughness = 0.95
	wheel_mesh.material = wheel_material
	for index in RigidLorryBuilder.wheel_anchor_indices():
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.rotation_degrees.x = 90.0
		wheel.set_meta("anchor_index", index)
		add_child(wheel)
		wheel_visuals.append(wheel)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "LorryStructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func _create_box(node_name: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.08
	material.roughness = 0.68
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance

func update_from_model() -> void:
	if model == null:
		return
	cargo_visual.position = model.average_position_for_nodes(_station_range_nodes(1, RigidLorryBuilder.CARGO_END_STATION)) + Vector3(0.0, 0.10, 0.0)
	cab_visual.position = model.average_position_for_nodes(_station_range_nodes(4, RigidLorryBuilder.FRONT_STATION)) + Vector3(0.0, -0.05, 0.0)
	chassis_visual.position = model.average_position_for_nodes(_station_range_nodes(0, RigidLorryBuilder.FRONT_STATION)) + Vector3(0.0, -0.62, 0.0)
	rear_guard_visual.position = model.average_position_for_nodes(RigidLorryBuilder.rear_contact_nodes())
	for wheel in wheel_visuals:
		var index := int(wheel.get_meta("anchor_index"))
		if index >= 0 and index < model.nodes.size():
			wheel.position = model.nodes[index].position_m + Vector3(0.0, -0.22, 0.0)
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _station_range_nodes(first_station: int, last_station: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for station in range(first_station, last_station + 1):
		for corner in range(4):
			indices.append(RigidLorryBuilder.node_index(station, corner))
	return indices
