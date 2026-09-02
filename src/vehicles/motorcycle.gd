# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name Motorcycle
extends Node3D

@export_range(80.0, 600.0, 5.0, "or_greater") var total_mass_kg: float = 220.0
@export_range(0.0, 250.0, 1.0, "or_greater") var initial_speed_kmh: float = 0.0
@export var origin_offset_m: Vector3 = Vector3(2.0, 0.0, 0.0)
@export_range(-180.0, 180.0, 1.0) var heading_deg: float = 0.0
@export_range(1, 16, 1) var solver_substeps: int = 6
@export var show_structure: bool = false
@export var auto_step: bool = true

var model: StructuralModel
var debug_renderer: StructuralDebugRenderer
var frame_visual: MeshInstance3D
var tank_visual: MeshInstance3D
var wheel_visuals: Array[MeshInstance3D] = []

func _ready() -> void:
	model = MotorcycleBuilder.build(total_mass_kg, initial_speed_kmh, origin_offset_m)
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

func frame_deformation_m() -> float:
	return model.max_permanent_deformation_for_role(&"motorcycle_frame")

func _build_visuals() -> void:
	frame_visual = _create_box("Frame", Vector3(1.20, 0.16, 0.24), Color(0.10, 0.10, 0.12))
	tank_visual = _create_box("TankSeat", Vector3(0.78, 0.36, 0.42), Color(0.26, 0.30, 0.36))
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.32
	wheel_mesh.bottom_radius = 0.32
	wheel_mesh.height = 0.10
	wheel_mesh.radial_segments = 18
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color(0.025, 0.025, 0.03)
	wheel_material.roughness = 0.95
	wheel_mesh.material = wheel_material
	for station in [MotorcycleBuilder.REAR_STATION, MotorcycleBuilder.FRONT_STATION]:
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.rotation_degrees.x = 90.0
		wheel.set_meta("station", station)
		add_child(wheel)
		wheel_visuals.append(wheel)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "MotorcycleStructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func _create_box(node_name: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.15
	material.roughness = 0.55
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance

func update_from_model() -> void:
	if model == null:
		return
	frame_visual.position = _average_stations(1, 2) + Vector3(0.0, -0.12, 0.0)
	tank_visual.position = _average_stations(1, 2) + Vector3(0.0, 0.28, 0.0)
	for wheel in wheel_visuals:
		var station := int(wheel.get_meta("station"))
		var left := MotorcycleBuilder.node_index(station, 0)
		var right := MotorcycleBuilder.node_index(station, 1)
		wheel.position = (model.nodes[left].position_m + model.nodes[right].position_m) * 0.5
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _average_stations(first_station: int, last_station: int) -> Vector3:
	var indices := PackedInt32Array()
	for station in range(first_station, last_station + 1):
		for corner in range(4):
			indices.append(MotorcycleBuilder.node_index(station, corner))
	return model.average_position_for_nodes(indices)
