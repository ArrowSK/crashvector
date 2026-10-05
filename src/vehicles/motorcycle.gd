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
var front_fork_visuals: Array[MeshInstance3D] = []
var rear_swingarm_visuals: Array[MeshInstance3D] = []
var wheel_roots: Array[Node3D] = []

const TANK_BASE_SIZE := Vector3(0.76, 0.42, 0.48)
const SEAT_BASE_SIZE := Vector3(0.72, 0.13, 0.42)
const HANDLEBAR_BASE_SIZE := Vector3(0.06, 0.06, 0.78)

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
	# The major body pieces are presentation-only, but unlike the original rigid
	# boxes they now follow local structural spans so M20 crush is visibly legible.
	tank_visual = _create_box("FuelTank", TANK_BASE_SIZE, body_material)
	seat_visual = _create_box("Seat", SEAT_BASE_SIZE, dark)
	handlebar_visual = _create_box("Handlebar", HANDLEBAR_BASE_SIZE, metal)
	headlamp_visual = _create_box("Headlamp", Vector3(0.13, 0.22, 0.27), _emissive_material())
	for side in range(2):
		var fork := _create_box("FrontFork", Vector3(0.58, 0.045, 0.045), metal)
		fork.set_meta("side", side)
		front_fork_visuals.append(fork)
		var swingarm := _create_box("RearSwingarm", Vector3(0.56, 0.055, 0.055), frame_material)
		swingarm.set_meta("side", side)
		rear_swingarm_visuals.append(swingarm)
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
	for segment in frame_visuals:
		_update_segment(segment, int(segment.get_meta("a")), int(segment.get_meta("b")))

	var station1 := _station_center(1)
	var station2 := _station_center(2)
	var rear := _station_center(MotorcycleBuilder.REAR_STATION)
	var front := _station_center(MotorcycleBuilder.FRONT_STATION)
	var tank_basis := _basis_x_along(station2 - station1, basis.y)
	var rear_basis := _basis_x_along(station1 - rear, basis.y)
	var front_basis := _basis_x_along(front - station2, basis.y)

	var tank_span_ratio := _span_ratio(1, 2)
	var rear_span_ratio := _span_ratio(MotorcycleBuilder.REAR_STATION, 1)
	var body_width_ratio := clampf(
		(_station_width_m(1) + _station_width_m(2))
		/ maxf(_neutral_station_width_m(1) + _neutral_station_width_m(2), 0.001),
		0.50,
		1.05
	)
	var front_width_ratio := clampf(
		_station_width_m(MotorcycleBuilder.FRONT_STATION)
		/ maxf(_neutral_station_width_m(MotorcycleBuilder.FRONT_STATION), 0.001),
		0.55,
		1.05
	)

	_set_box_size(tank_visual, Vector3(
		clampf(TANK_BASE_SIZE.x * tank_span_ratio, 0.38, TANK_BASE_SIZE.x),
		TANK_BASE_SIZE.y,
		clampf(TANK_BASE_SIZE.z * body_width_ratio, 0.24, TANK_BASE_SIZE.z)
	))
	tank_visual.position = (station1 + station2) * 0.5 + tank_basis.y * 0.18
	tank_visual.basis = tank_basis

	_set_box_size(seat_visual, Vector3(
		clampf(SEAT_BASE_SIZE.x * rear_span_ratio, 0.36, SEAT_BASE_SIZE.x),
		SEAT_BASE_SIZE.y,
		clampf(SEAT_BASE_SIZE.z * body_width_ratio, 0.22, SEAT_BASE_SIZE.z)
	))
	seat_visual.position = station1 - rear_basis.x * 0.14 + rear_basis.y * 0.43
	seat_visual.basis = rear_basis

	_set_box_size(handlebar_visual, Vector3(
		HANDLEBAR_BASE_SIZE.x,
		HANDLEBAR_BASE_SIZE.y,
		clampf(HANDLEBAR_BASE_SIZE.z * front_width_ratio, 0.42, HANDLEBAR_BASE_SIZE.z)
	))
	handlebar_visual.position = front - front_basis.x * 0.18 + front_basis.y * 0.56
	handlebar_visual.basis = front_basis
	headlamp_visual.position = front + front_basis.x * 0.06 + front_basis.y * 0.27
	headlamp_visual.basis = front_basis

	# Independent left/right fork and swingarm members make shortening and folding
	# visible instead of hiding M20 structural crush underneath rigid body boxes.
	for side in range(mini(front_fork_visuals.size(), 2)):
		_update_box_between_x(
			front_fork_visuals[side],
			_node_position(2, 2 + side),
			_node_position(MotorcycleBuilder.FRONT_STATION, side),
			basis.y
		)
	for side in range(mini(rear_swingarm_visuals.size(), 2)):
		_update_box_between_x(
			rear_swingarm_visuals[side],
			_node_position(MotorcycleBuilder.REAR_STATION, side),
			_node_position(1, side),
			basis.y
		)

	for root in wheel_roots:
		var station := int(root.get_meta("station"))
		root.position = _station_center(station)
		root.basis = rear_basis if station == MotorcycleBuilder.REAR_STATION else front_basis
	if debug_renderer != null:
		debug_renderer.update_from_model()

func visual_collapse_m() -> float:
	# Presentation regression metric only: report how far the deformable shell has
	# visibly shortened relative to its neutral authored spans.
	var tank_mesh := tank_visual.mesh as BoxMesh if tank_visual != null else null
	var seat_mesh := seat_visual.mesh as BoxMesh if seat_visual != null else null
	var tank_collapse := 0.0 if tank_mesh == null else maxf(
		maxf(TANK_BASE_SIZE.x - tank_mesh.size.x, 0.0),
		maxf(TANK_BASE_SIZE.z - tank_mesh.size.z, 0.0)
	)
	var seat_collapse := 0.0 if seat_mesh == null else maxf(
		maxf(SEAT_BASE_SIZE.x - seat_mesh.size.x, 0.0),
		maxf(SEAT_BASE_SIZE.z - seat_mesh.size.z, 0.0)
	)
	var front_fork_collapse := 0.0
	for side in range(mini(front_fork_visuals.size(), 2)):
		var mesh := front_fork_visuals[side].mesh as BoxMesh
		if mesh == null:
			continue
		var neutral := _neutral_node_position(2, 2 + side).distance_to(
			_neutral_node_position(MotorcycleBuilder.FRONT_STATION, side)
		)
		front_fork_collapse = maxf(front_fork_collapse, neutral - mesh.size.x)
	var rear_swingarm_collapse := 0.0
	for side in range(mini(rear_swingarm_visuals.size(), 2)):
		var mesh := rear_swingarm_visuals[side].mesh as BoxMesh
		if mesh == null:
			continue
		var neutral := _neutral_node_position(MotorcycleBuilder.REAR_STATION, side).distance_to(
			_neutral_node_position(1, side)
		)
		rear_swingarm_collapse = maxf(rear_swingarm_collapse, neutral - mesh.size.x)
	return maxf(maxf(tank_collapse, seat_collapse), maxf(front_fork_collapse, rear_swingarm_collapse))

func _set_box_size(visual: MeshInstance3D, size: Vector3) -> void:
	if visual == null:
		return
	var mesh := visual.mesh as BoxMesh
	if mesh != null:
		mesh.size = size

func _update_box_between_x(visual: MeshInstance3D, a: Vector3, b: Vector3, up_hint: Vector3) -> void:
	if visual == null:
		return
	var delta := b - a
	var length := delta.length()
	if length <= 0.001:
		visual.visible = false
		return
	visual.visible = true
	var mesh := visual.mesh as BoxMesh
	if mesh != null:
		mesh.size.x = length
	visual.position = (a + b) * 0.5
	visual.basis = _basis_x_along(delta, up_hint)

func _basis_x_along(direction: Vector3, up_hint: Vector3) -> Basis:
	var forward := direction.normalized()
	if forward.is_zero_approx():
		return Basis.IDENTITY
	var up := up_hint.normalized()
	if up.is_zero_approx() or absf(forward.dot(up)) > 0.96:
		up = Vector3.UP if absf(forward.dot(Vector3.UP)) <= 0.96 else Vector3.FORWARD
	var lateral := forward.cross(up).normalized()
	if lateral.is_zero_approx():
		lateral = Vector3.FORWARD
	up = lateral.cross(forward).normalized()
	return Basis(forward, up, lateral).orthonormalized()

func _span_ratio(station_a: int, station_b: int) -> float:
	var neutral := _neutral_station_center(station_a).distance_to(_neutral_station_center(station_b))
	var current := _station_center(station_a).distance_to(_station_center(station_b))
	return clampf(current / maxf(neutral, 0.001), 0.45, 1.05)

func _station_width_m(station: int) -> float:
	var lower := _node_position(station, 0).distance_to(_node_position(station, 1))
	var upper := _node_position(station, 2).distance_to(_node_position(station, 3))
	return (lower + upper) * 0.5

func _neutral_station_width_m(station: int) -> float:
	return MotorcycleBuilder.HALF_WIDTH_Z[station] * 2.0

func _node_position(station: int, corner: int) -> Vector3:
	var index := MotorcycleBuilder.node_index(station, corner)
	if index < 0 or index >= model.nodes.size():
		return Vector3.ZERO
	return model.nodes[index].position_m

func _neutral_node_position(station: int, corner: int) -> Vector3:
	var y := MotorcycleBuilder.LOWER_Y[station] if corner < 2 else MotorcycleBuilder.UPPER_Y[station]
	var z_sign := -1.0 if corner in [0, 2] else 1.0
	return Vector3(
		MotorcycleBuilder.STATION_X[station],
		y,
		MotorcycleBuilder.HALF_WIDTH_Z[station] * z_sign
	)

func _neutral_station_center(station: int) -> Vector3:
	return Vector3(
		MotorcycleBuilder.STATION_X[station],
		(MotorcycleBuilder.LOWER_Y[station] + MotorcycleBuilder.UPPER_Y[station]) * 0.5,
		0.0
	)

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
