# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name Pedestrian
extends Node3D

@export var body_preset_id: StringName = RoadUserCatalog.PEDESTRIAN_ADULT
@export_range(15.0, 200.0, 1.0, "or_greater") var total_mass_kg: float = 75.0
@export var origin_offset_m: Vector3 = Vector3(2.5, 0.0, 0.0)
@export_range(-180.0, 180.0, 1.0) var heading_deg: float = 0.0
@export var show_structure: bool = false
@export var auto_step: bool = true

var model: StructuralModel
var debug_renderer: StructuralDebugRenderer
var limb_visuals: Array[MeshInstance3D] = []
var head_visual: MeshInstance3D
var torso_visual: MeshInstance3D

func _ready() -> void:
	model = PedestrianBuilder.build(body_preset_id, total_mass_kg, origin_offset_m)
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

func body_deformation_m() -> float:
	return model.max_permanent_deformation_m() if model != null else 0.0

func _build_visuals() -> void:
	var skin := _material(Color(0.78, 0.62, 0.50), 0.72)
	var cloth := _material(Color(0.17, 0.34, 0.58), 0.78)
	var dark := _material(Color(0.08, 0.10, 0.14), 0.90)
	_add_segment("LeftLowerLeg", PedestrianBuilder.LEFT_FOOT, PedestrianBuilder.LEFT_KNEE, 0.085, dark)
	_add_segment("RightLowerLeg", PedestrianBuilder.RIGHT_FOOT, PedestrianBuilder.RIGHT_KNEE, 0.085, dark)
	_add_segment("LeftUpperLeg", PedestrianBuilder.LEFT_KNEE, PedestrianBuilder.LEFT_HIP, 0.11, cloth)
	_add_segment("RightUpperLeg", PedestrianBuilder.RIGHT_KNEE, PedestrianBuilder.RIGHT_HIP, 0.11, cloth)
	_add_segment("LeftArm", PedestrianBuilder.LEFT_SHOULDER, PedestrianBuilder.LEFT_HAND, 0.07, cloth)
	_add_segment("RightArm", PedestrianBuilder.RIGHT_SHOULDER, PedestrianBuilder.RIGHT_HAND, 0.07, cloth)
	_add_segment("Shoulders", PedestrianBuilder.LEFT_SHOULDER, PedestrianBuilder.RIGHT_SHOULDER, 0.10, cloth)
	_add_segment("TorsoAxis", PedestrianBuilder.PELVIS, PedestrianBuilder.CHEST, 0.20, cloth)

	torso_visual = MeshInstance3D.new()
	torso_visual.name = "TorsoShell"
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.22, 0.40, 0.38)
	torso_mesh.material = cloth
	torso_visual.mesh = torso_mesh
	add_child(torso_visual)

	head_visual = MeshInstance3D.new()
	head_visual.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.115
	head_mesh.height = 0.23
	head_mesh.radial_segments = 14
	head_mesh.rings = 8
	head_mesh.material = skin
	head_visual.mesh = head_mesh
	add_child(head_visual)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "PedestrianStructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_segment(node_name: String, a: int, b: int, thickness: float, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, 0.5)
	mesh.material = material
	visual.mesh = mesh
	visual.set_meta("a", a)
	visual.set_meta("b", b)
	add_child(visual)
	limb_visuals.append(visual)

func update_from_model() -> void:
	if model == null:
		return
	for visual in limb_visuals:
		_update_segment(visual, int(visual.get_meta("a")), int(visual.get_meta("b")))
	var pelvis := model.nodes[PedestrianBuilder.PELVIS].position_m
	var chest := model.nodes[PedestrianBuilder.CHEST].position_m
	torso_visual.position = (pelvis + chest) * 0.5
	head_visual.position = model.nodes[PedestrianBuilder.HEAD].position_m
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _update_segment(visual: MeshInstance3D, a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= model.nodes.size() or b >= model.nodes.size():
		return
	var pa := model.nodes[a].position_m
	var pb := model.nodes[b].position_m
	var delta := pb - pa
	var length := delta.length()
	if length <= 0.001:
		return
	var mesh := visual.mesh as BoxMesh
	if mesh != null:
		mesh.size.z = length
	visual.position = (pa + pb) * 0.5
	var direction := delta / length
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.94 else Vector3.UP
	visual.look_at(pb, up)
