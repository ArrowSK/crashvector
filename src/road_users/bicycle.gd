# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name Bicycle
extends Node3D

@export var bicycle_preset_id: StringName = RoadUserCatalog.BICYCLE_CITY
@export_range(5.0, 60.0, 1.0, "or_greater") var total_mass_kg: float = 16.0
@export_range(0.0, 80.0, 1.0, "or_greater") var initial_speed_kmh: float = 0.0
@export var origin_offset_m: Vector3 = Vector3(2.5, 0.0, 0.0)
@export_range(-180.0, 180.0, 1.0) var heading_deg: float = 0.0
@export var show_structure: bool = false
@export var auto_step: bool = true

var model: StructuralModel
var debug_renderer: StructuralDebugRenderer
var wheel_visuals: Array[MeshInstance3D] = []
var frame_visuals: Array[MeshInstance3D] = []

func _ready() -> void:
	model = BicycleBuilder.build(bicycle_preset_id, total_mass_kg, initial_speed_kmh, origin_offset_m)
	model.rotate_y_about(origin_offset_m, deg_to_rad(heading_deg), true)
	_build_visuals()
	_build_structure_debugger()
	update_from_model()

func _physics_process(delta: float) -> void:
	if model == null or not auto_step:
		return
	model.step(delta, 6)
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
	return model.max_permanent_deformation_for_role(&"bicycle_frame") if model != null else 0.0

func _build_visuals() -> void:
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.18, 0.44, 0.62)
	frame_material.metallic = 0.35
	frame_material.roughness = 0.48
	for pair in [[0, 1], [1, 2], [2, 3]]:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.045, 0.045, 0.5)
		mesh.material = frame_material
		visual.mesh = mesh
		visual.set_meta("station_a", pair[0])
		visual.set_meta("station_b", pair[1])
		add_child(visual)
		frame_visuals.append(visual)

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.34
	wheel_mesh.bottom_radius = 0.34
	wheel_mesh.height = 0.045
	wheel_mesh.radial_segments = 22
	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color(0.025, 0.025, 0.03)
	tyre.roughness = 0.95
	wheel_mesh.material = tyre
	for station in [BicycleBuilder.REAR_STATION, BicycleBuilder.FRONT_STATION]:
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.rotation_degrees.x = 90.0
		wheel.set_meta("station", station)
		add_child(wheel)
		wheel_visuals.append(wheel)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "BicycleStructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func update_from_model() -> void:
	if model == null:
		return
	for visual in frame_visuals:
		var station_a := int(visual.get_meta("station_a"))
		var station_b := int(visual.get_meta("station_b"))
		_update_frame_segment(visual, station_a, station_b)
	for wheel in wheel_visuals:
		var station := int(wheel.get_meta("station"))
		var left := BicycleBuilder.node_index(station, 0)
		var right := BicycleBuilder.node_index(station, 1)
		wheel.position = (model.nodes[left].position_m + model.nodes[right].position_m) * 0.5
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _station_center(station: int) -> Vector3:
	var indices := PackedInt32Array([
		BicycleBuilder.node_index(station, 0), BicycleBuilder.node_index(station, 1),
		BicycleBuilder.node_index(station, 2), BicycleBuilder.node_index(station, 3),
	])
	return model.average_position_for_nodes(indices)

func _update_frame_segment(visual: MeshInstance3D, station_a: int, station_b: int) -> void:
	var a := _station_center(station_a)
	var b := _station_center(station_b)
	var delta := b - a
	var length := delta.length()
	if length <= 0.001:
		return
	var mesh := visual.mesh as BoxMesh
	if mesh != null:
		mesh.size.z = length
	visual.position = (a + b) * 0.5
	var direction := delta / length
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.94 else Vector3.UP
	visual.look_at(b, up)
