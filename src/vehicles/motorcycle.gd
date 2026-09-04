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
var frame_visuals: Array[MeshInstance3D] = []
var tank_visual: MeshInstance3D
var seat_visual: MeshInstance3D
var handlebar_visual: MeshInstance3D
var headlamp_visual: MeshInstance3D
var wheel_roots: Array[Node3D] = []

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
	var frame_material := _material(Color(0.065, 0.075, 0.090), 0.68, 0.32)
	var body_material := _material(Color(0.62, 0.085, 0.055), 0.48, 0.24)
	var dark := _material(Color(0.018, 0.020, 0.024), 0.0, 0.92)
	var metal := _material(Color(0.46, 0.49, 0.53), 0.88, 0.20)
	for pair in [[0, 1], [1, 2], [2, 3]]:
		var segment := _create_box("FrameTube", Vector3(0.10, 0.10, 0.5), frame_material)
		segment.set_meta("a", pair[0])
		segment.set_meta("b", pair[1])
		frame_visuals.append(segment)
	tank_visual = _create_box("FuelTank", Vector3(0.76, 0.42, 0.48), body_material)
	seat_visual = _create_box("Seat", Vector3(0.72, 0.13, 0.42), dark)
	handlebar_visual = _create_box("Handlebar", Vector3(0.06, 0.06, 0.78), metal)
	headlamp_visual = _create_box("Headlamp", Vector3(0.13, 0.22, 0.27), _emissive_material())
	for station in [MotorcycleBuilder.REAR_STATION, MotorcycleBuilder.FRONT_STATION]:
		var root := Node3D.new()
		root.name = "MotorcycleWheel"
		root.set_meta("station", station)
		add_child(root)
		var tyre := MeshInstance3D.new()
		var tyre_mesh := CylinderMesh.new()
		tyre_mesh.top_radius = 0.34
		tyre_mesh.bottom_radius = 0.34
		tyre_mesh.height = 0.105
		tyre_mesh.radial_segments = 28
		tyre_mesh.material = dark
		tyre.mesh = tyre_mesh
		tyre.rotation_degrees.x = 90.0
		root.add_child(tyre)
		var rim := MeshInstance3D.new()
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.235
		rim_mesh.bottom_radius = 0.235
		rim_mesh.height = 0.11
		rim_mesh.radial_segments = 22
		rim_mesh.material = metal
		rim.mesh = rim_mesh
		rim.rotation_degrees.x = 90.0
		root.add_child(rim)
		wheel_roots.append(root)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "MotorcycleStructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _emissive_material() -> StandardMaterial3D:
	var material := _material(Color(0.82, 0.89, 0.96), 0.18, 0.18)
	material.emission_enabled = true
	material.emission = Color(0.28, 0.36, 0.45)
	material.emission_energy_multiplier = 0.18
	return material

func _create_box(node_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	add_child(visual)
	return visual

func update_from_model() -> void:
	if model == null:
		return
	var basis := _visual_basis()
	var forward := basis.x.normalized()
	var up := basis.y.normalized()
	for segment in frame_visuals:
		_update_segment(segment, int(segment.get_meta("a")), int(segment.get_meta("b")))
	var station1 := _station_center(1)
	var station2 := _station_center(2)
	var front := _station_center(MotorcycleBuilder.FRONT_STATION)
	tank_visual.position = (station1 + station2) * 0.5 + up * 0.18
	tank_visual.basis = basis
	seat_visual.position = station1 - forward * 0.14 + up * 0.43
	seat_visual.basis = basis
	handlebar_visual.position = front - forward * 0.18 + up * 0.56
	handlebar_visual.basis = basis
	headlamp_visual.position = front + forward * 0.06 + up * 0.27
	headlamp_visual.basis = basis
	for root in wheel_roots:
		var station := int(root.get_meta("station"))
		root.position = _station_center(station)
		root.basis = basis
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _station_center(station: int) -> Vector3:
	var indices := PackedInt32Array([
		MotorcycleBuilder.node_index(station, 0), MotorcycleBuilder.node_index(station, 1),
		MotorcycleBuilder.node_index(station, 2), MotorcycleBuilder.node_index(station, 3),
	])
	return model.average_position_for_nodes(indices)

func _visual_basis() -> Basis:
	var forward := (_station_center(MotorcycleBuilder.FRONT_STATION) - _station_center(MotorcycleBuilder.REAR_STATION)).normalized()
	var lower := (model.nodes[MotorcycleBuilder.node_index(2, 0)].position_m + model.nodes[MotorcycleBuilder.node_index(2, 1)].position_m) * 0.5
	var upper := (model.nodes[MotorcycleBuilder.node_index(2, 2)].position_m + model.nodes[MotorcycleBuilder.node_index(2, 3)].position_m) * 0.5
	var up := (upper - lower).normalized()
	var right := forward.cross(up).normalized()
	if right.is_zero_approx():
		right = Vector3.FORWARD
	up = right.cross(forward).normalized()
	return Basis(forward, up, right).orthonormalized()

func _update_segment(visual: MeshInstance3D, station_a: int, station_b: int) -> void:
	var a := _station_center(station_a)
	var b := _station_center(station_b)
	var delta := b - a
	var length := delta.length()
	if length <= 0.001:
		return
	var mesh := visual.mesh as BoxMesh
	mesh.size.z = length
	visual.position = (a + b) * 0.5
	var up := _visual_basis().y
	visual.look_at(b, up)
