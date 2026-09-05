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
var wheel_roots: Array[Node3D] = []
var frame_visuals: Array[MeshInstance3D] = []
var seat_visual: MeshInstance3D
var handlebar_visual: MeshInstance3D
var battery_visual: MeshInstance3D

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
	var frame_color := Color(0.16, 0.42, 0.68)
	if bicycle_preset_id == RoadUserCatalog.BICYCLE_ROAD:
		frame_color = Color(0.76, 0.16, 0.08)
	elif bicycle_preset_id == RoadUserCatalog.BICYCLE_EBIKE:
		frame_color = Color(0.16, 0.50, 0.34)
	var frame_material := _material(frame_color, 0.48, 0.30)
	var dark := _material(Color(0.018, 0.020, 0.023), 0.0, 0.92)
	var metal := _material(Color(0.48, 0.50, 0.53), 0.86, 0.22)
	# Frame triangle and fork. Endpoints are named semantic anchors and all are
	# recomputed from the deforming structural model on every update.
	_add_frame_segment("TopTube", &"rear_upper", &"front_upper", 0.040, frame_material)
	_add_frame_segment("DownTube", &"rear_lower", &"front_upper", 0.046, frame_material)
	_add_frame_segment("SeatTube", &"rear_lower", &"rear_upper", 0.043, frame_material)
	_add_frame_segment("RearStay", &"wheel_rear", &"rear_upper", 0.034, frame_material)
	_add_frame_segment("RearChainStay", &"wheel_rear", &"rear_lower", 0.034, frame_material)
	_add_frame_segment("Fork", &"front_upper", &"wheel_front", 0.040, frame_material)
	seat_visual = _create_box("Saddle", Vector3(0.25, 0.055, 0.16), dark)
	handlebar_visual = _create_box("Handlebar", Vector3(0.055, 0.055, 0.52), metal)
	battery_visual = _create_box("Battery", Vector3(0.34, 0.11, 0.13), dark)
	battery_visual.visible = bicycle_preset_id == RoadUserCatalog.BICYCLE_EBIKE

	for station in [BicycleBuilder.REAR_STATION, BicycleBuilder.FRONT_STATION]:
		var root := Node3D.new()
		root.name = "BicycleWheel"
		root.set_meta("station", station)
		add_child(root)
		var tyre := MeshInstance3D.new()
		var tyre_mesh := CylinderMesh.new()
		tyre_mesh.top_radius = 0.34
		tyre_mesh.bottom_radius = 0.34
		tyre_mesh.height = 0.045
		tyre_mesh.radial_segments = 30
		tyre_mesh.material = dark
		tyre.mesh = tyre_mesh
		tyre.rotation_degrees.x = 90.0
		root.add_child(tyre)
		var rim := MeshInstance3D.new()
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.305
		rim_mesh.bottom_radius = 0.305
		rim_mesh.height = 0.048
		rim_mesh.radial_segments = 30
		rim_mesh.material = metal
		rim.mesh = rim_mesh
		rim.rotation_degrees.x = 90.0
		root.add_child(rim)
		wheel_roots.append(root)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "BicycleStructuralDebugRenderer"
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
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	visual.mesh = mesh
	add_child(visual)
	return visual

func _add_frame_segment(node_name: String, a: StringName, b: StringName, thickness: float, material: Material) -> void:
	var visual := _create_box(node_name, Vector3(thickness, thickness, 0.5), material)
	visual.set_meta("anchor_a", a)
	visual.set_meta("anchor_b", b)
	frame_visuals.append(visual)

func update_from_model() -> void:
	if model == null:
		return
	var basis := _visual_basis()
	var forward := basis.x.normalized()
	var up := basis.y.normalized()
	for visual in frame_visuals:
		_update_frame_segment(visual, StringName(String(visual.get_meta("anchor_a"))), StringName(String(visual.get_meta("anchor_b"))))
	for root in wheel_roots:
		root.position = _station_center(int(root.get_meta("station")))
		root.basis = basis
	seat_visual.position = _anchor(&"rear_upper") + up * 0.11 - forward * 0.02
	seat_visual.basis = basis
	handlebar_visual.position = _anchor(&"front_upper") + up * 0.20 + forward * 0.06
	handlebar_visual.basis = basis
	battery_visual.position = _anchor(&"rear_lower").lerp(_anchor(&"front_upper"), 0.52)
	battery_visual.basis = basis
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _anchor(id: StringName) -> Vector3:
	match id:
		&"wheel_rear": return _station_center(BicycleBuilder.REAR_STATION)
		&"wheel_front": return _station_center(BicycleBuilder.FRONT_STATION)
		&"rear_lower": return _side_average(1, false)
		&"rear_upper": return _side_average(1, true)
		&"front_lower": return _side_average(2, false)
		&"front_upper": return _side_average(2, true)
		_: return Vector3.ZERO

func _side_average(station: int, upper: bool) -> Vector3:
	var offset := 2 if upper else 0
	return (model.nodes[BicycleBuilder.node_index(station, offset)].position_m + model.nodes[BicycleBuilder.node_index(station, offset + 1)].position_m) * 0.5

func _station_center(station: int) -> Vector3:
	var indices := PackedInt32Array([
		BicycleBuilder.node_index(station, 0), BicycleBuilder.node_index(station, 1),
		BicycleBuilder.node_index(station, 2), BicycleBuilder.node_index(station, 3),
	])
	return model.average_position_for_nodes(indices)

func _visual_basis() -> Basis:
	var forward := (_station_center(BicycleBuilder.FRONT_STATION) - _station_center(BicycleBuilder.REAR_STATION)).normalized()
	var up := (_side_average(2, true) - _side_average(2, false)).normalized()
	var right := forward.cross(up).normalized()
	if right.is_zero_approx():
		right = Vector3.FORWARD
	up = right.cross(forward).normalized()
	return Basis(forward, up, right).orthonormalized()

func _update_frame_segment(visual: MeshInstance3D, anchor_a: StringName, anchor_b: StringName) -> void:
	var a := _anchor(anchor_a)
	var b := _anchor(anchor_b)
	var delta := b - a
	var length := delta.length()
	if length <= 0.001:
		return
	var mesh := visual.mesh as BoxMesh
	mesh.size.z = length
	visual.position = (a + b) * 0.5
	var direction := delta / length
	var safe_up := _visual_basis().y.normalized()
	if absf(direction.dot(safe_up)) > 0.94:
		safe_up = Vector3.FORWARD
		if absf(direction.dot(safe_up)) > 0.94:
			safe_up = Vector3.RIGHT
	visual.look_at(b, safe_up)
