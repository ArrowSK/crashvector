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
var windshield_visual: MeshInstance3D
var grille_visual: MeshInstance3D
var bumper_visual: MeshInstance3D
var roof_visual: MeshInstance3D
var wheel_visuals: Array[Node3D] = []

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
	var cargo_material := _material(Color(0.77, 0.79, 0.82), 0.12, 0.58)
	var cab_material := _material(Color(0.19, 0.46, 0.64), 0.40, 0.28)
	var dark := _material(Color(0.035, 0.045, 0.055), 0.35, 0.48)
	var glass := _material(Color(0.035, 0.070, 0.100), 0.10, 0.10)
	var metal := _material(Color(0.30, 0.32, 0.35), 0.78, 0.26)
	cargo_visual = _create_box("CargoBody", Vector3(4.55, 2.64, 2.24), cargo_material)
	cab_visual = _create_box("Cab", Vector3(2.05, 2.20, 2.05), cab_material)
	chassis_visual = _create_box("Chassis", Vector3(7.10, 0.17, 1.72), dark)
	rear_guard_visual = _create_box("RearGuard", Vector3(0.15, 0.20, 2.04), metal)
	windshield_visual = _create_box("CabWindshield", Vector3(0.07, 0.72, 1.55), glass)
	grille_visual = _create_box("CabGrille", Vector3(0.07, 0.48, 1.40), dark)
	bumper_visual = _create_box("CabBumper", Vector3(0.15, 0.22, 1.92), metal)
	roof_visual = _create_box("CabRoof", Vector3(1.98, 0.11, 2.04), cab_material)
	_build_wheels()

func _build_wheels() -> void:
	var tyre_material := _material(Color(0.015, 0.017, 0.020), 0.0, 0.93)
	var rim_material := _material(Color(0.47, 0.49, 0.52), 0.86, 0.24)
	for index in RigidLorryBuilder.wheel_anchor_indices():
		var root := Node3D.new()
		root.name = "LorryWheel"
		root.set_meta("anchor_index", index)
		add_child(root)
		var tyre := MeshInstance3D.new()
		var tyre_mesh := CylinderMesh.new()
		tyre_mesh.top_radius = 0.42
		tyre_mesh.bottom_radius = 0.42
		tyre_mesh.height = 0.31
		tyre_mesh.radial_segments = 24
		tyre_mesh.material = tyre_material
		tyre.mesh = tyre_mesh
		tyre.rotation_degrees.x = 90.0
		root.add_child(tyre)
		var rim := MeshInstance3D.new()
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.245
		rim_mesh.bottom_radius = 0.245
		rim_mesh.height = 0.33
		rim_mesh.radial_segments = 18
		rim_mesh.material = rim_material
		rim.mesh = rim_mesh
		rim.rotation_degrees.x = 90.0
		root.add_child(rim)
		wheel_visuals.append(root)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "LorryStructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _create_box(node_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance

func update_from_model() -> void:
	if model == null:
		return
	var basis := _visual_basis()
	var forward := basis.x.normalized()
	var up := basis.y.normalized()
	var cargo_center := model.average_position_for_nodes(_station_range_nodes(1, RigidLorryBuilder.CARGO_END_STATION))
	var cab_center := model.average_position_for_nodes(_station_range_nodes(4, RigidLorryBuilder.FRONT_STATION))
	var chassis_center := model.average_position_for_nodes(_station_range_nodes(0, RigidLorryBuilder.FRONT_STATION))
	var front_center := _station_center(RigidLorryBuilder.FRONT_STATION)
	var cab_rear := _station_center(4)
	cargo_visual.position = cargo_center + up * 0.12
	cargo_visual.basis = basis
	cab_visual.position = cab_center - up * 0.04
	cab_visual.basis = basis
	chassis_visual.position = chassis_center - up * 0.58
	chassis_visual.basis = basis
	rear_guard_visual.position = model.average_position_for_nodes(RigidLorryBuilder.rear_contact_nodes()) - up * 0.18
	rear_guard_visual.basis = basis
	windshield_visual.position = front_center + forward * 0.025 + up * 0.31
	windshield_visual.basis = basis
	grille_visual.position = front_center + forward * 0.04 - up * 0.39
	grille_visual.basis = basis
	bumper_visual.position = front_center + forward * 0.06 - up * 0.76
	bumper_visual.basis = basis
	roof_visual.position = (front_center + cab_rear) * 0.5 + up * 1.13
	roof_visual.basis = basis
	for wheel in wheel_visuals:
		var index := int(wheel.get_meta("anchor_index"))
		if index >= 0 and index < model.nodes.size():
			wheel.position = model.nodes[index].position_m - up * 0.27
			wheel.basis = basis
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _visual_basis() -> Basis:
	var rear := _station_center(1)
	var front := _station_center(RigidLorryBuilder.FRONT_STATION)
	var forward := (front - rear).normalized()
	var left_lower := model.nodes[RigidLorryBuilder.node_index(3, 0)].position_m
	var left_upper := model.nodes[RigidLorryBuilder.node_index(3, 2)].position_m
	var right_lower := model.nodes[RigidLorryBuilder.node_index(3, 1)].position_m
	var right_upper := model.nodes[RigidLorryBuilder.node_index(3, 3)].position_m
	var up := ((left_upper - left_lower).normalized() + (right_upper - right_lower).normalized()).normalized()
	var right := forward.cross(up).normalized()
	if right.is_zero_approx():
		right = Vector3.FORWARD
	up = right.cross(forward).normalized()
	return Basis(forward, up, right).orthonormalized()

func _station_center(station: int) -> Vector3:
	return model.average_position_for_nodes(RigidLorryBuilder.station_nodes(station))

func _station_range_nodes(first_station: int, last_station: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for station in range(first_station, last_station + 1):
		for corner in range(4):
			indices.append(RigidLorryBuilder.node_index(station, corner))
	return indices
