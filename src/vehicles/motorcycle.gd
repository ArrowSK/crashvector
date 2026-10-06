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
var engine_visual: MeshInstance3D
var engine_crankcase_visual: MeshInstance3D
var fairing_visual: MeshInstance3D
var windscreen_visual: MeshInstance3D
var exhaust_visual: MeshInstance3D
var exhaust_tip_visual: MeshInstance3D
var rear_light_visual: MeshInstance3D
var footpeg_visual: MeshInstance3D
var chain_guard_visual: MeshInstance3D
var handlebar_grips: Array[MeshInstance3D] = []
var side_panel_visuals: Array[MeshInstance3D] = []
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

	# Use round structural members rather than rectangular bars. These remain
	# presentation-only and continue to follow the same authoritative stations.
	for pair in [[0, 1], [1, 2], [2, 3]]:
		var segment := _create_cylinder("FrameTube", 0.045, 0.50, frame_material)
		segment.set_meta("a", pair[0])
		segment.set_meta("b", pair[1])
		segment.set_meta("presentation_role", "frame_tube")
		frame_visuals.append(segment)

	# Rounded massing makes the motorcycle read as a motorcycle rather than a
	# collection of boxes, while all positioning still comes from the structural
	# stations below.
	tank_visual = _create_ellipsoid("FuelTank", body_material)
	seat_visual = _create_box("Seat", SEAT_BASE_SIZE, dark)
	handlebar_visual = _create_cylinder("Handlebar", 0.022, HANDLEBAR_BASE_SIZE.z, metal)
	handlebar_visual.set_meta("presentation_role", "handlebar")
	headlamp_visual = _create_cylinder("Headlamp", 0.135, 0.085, _emissive_material())
	headlamp_visual.set_meta("presentation_role", "headlamp")
	engine_visual = _create_box("EngineBlock", Vector3(0.48, 0.42, 0.38), metal)
	engine_crankcase_visual = _create_cylinder("EngineCrankcase", 0.18, 0.40, _material(Color(0.30, 0.32, 0.35), 0.82, 0.24))
	fairing_visual = _create_ellipsoid("FrontFairing", body_material)
	windscreen_visual = _create_box("Windscreen", Vector3(0.055, 0.34, 0.40), _glass_material())
	exhaust_visual = _create_cylinder("ExhaustMuffler", 0.055, 0.78, metal)
	exhaust_visual.set_meta("presentation_role", "exhaust_muffler")
	exhaust_tip_visual = _create_cylinder("ExhaustTip", 0.065, 0.11, _material(Color(0.12, 0.13, 0.15), 0.88, 0.18))
	rear_light_visual = _create_box("RearLamp", Vector3(0.10, 0.14, 0.24), _rear_emissive_material())
	footpeg_visual = _create_cylinder("FootPegBar", 0.025, 0.58, metal)
	chain_guard_visual = _create_box("ChainGuard", Vector3(0.62, 0.055, 0.045), dark)

	for side in range(2):
		var grip := _create_cylinder("HandlebarGrip", 0.032, 0.13, dark)
		grip.set_meta("side", side)
		handlebar_grips.append(grip)
		var side_panel := _create_box("SidePanel", Vector3(0.46, 0.24, 0.045), body_material)
		side_panel.set_meta("side", side)
		side_panel_visuals.append(side_panel)

		var fork := _create_cylinder("FrontFork", 0.024, 0.58, metal)
		fork.set_meta("side", side)
		fork.set_meta("presentation_role", "front_fork")
		front_fork_visuals.append(fork)
		var swingarm := _create_cylinder("RearSwingarm", 0.030, 0.56, frame_material)
		swingarm.set_meta("side", side)
		swingarm.set_meta("presentation_role", "rear_swingarm")
		rear_swingarm_visuals.append(swingarm)

	for station in [MotorcycleBuilder.REAR_STATION, MotorcycleBuilder.FRONT_STATION]:
		var root := Node3D.new()
		root.name = "MotorcycleWheel"
		root.set_meta("station", station)
		add_child(root)

		var tyre := MeshInstance3D.new()
		tyre.name = "Tyre"
		var tyre_mesh := CylinderMesh.new()
		tyre_mesh.top_radius = 0.34
		tyre_mesh.bottom_radius = 0.34
		tyre_mesh.height = 0.105
		tyre_mesh.radial_segments = 32
		tyre_mesh.material = dark
		tyre.mesh = tyre_mesh
		tyre.rotation_degrees.x = 90.0
		root.add_child(tyre)

		var rim := MeshInstance3D.new()
		rim.name = "Rim"
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.235
		rim_mesh.bottom_radius = 0.235
		rim_mesh.height = 0.055
		rim_mesh.radial_segments = 28
		rim_mesh.material = metal
		rim.mesh = rim_mesh
		rim.rotation_degrees.x = 90.0
		root.add_child(rim)

		var hub := MeshInstance3D.new()
		hub.name = "WheelHub"
		var hub_mesh := CylinderMesh.new()
		hub_mesh.top_radius = 0.060
		hub_mesh.bottom_radius = 0.060
		hub_mesh.height = 0.13
		hub_mesh.radial_segments = 20
		hub_mesh.material = metal
		hub.mesh = hub_mesh
		hub.rotation_degrees.x = 90.0
		root.add_child(hub)

		for spoke_index in range(8):
			var spoke := MeshInstance3D.new()
			spoke.name = "WheelSpoke%d" % spoke_index
			var spoke_mesh := BoxMesh.new()
			spoke_mesh.size = Vector3(0.33, 0.016, 0.016)
			spoke_mesh.material = metal
			spoke.mesh = spoke_mesh
			spoke.rotation_degrees.z = float(spoke_index) * 22.5
			root.add_child(spoke)

		var brake_disc := MeshInstance3D.new()
		brake_disc.name = "BrakeDisc"
		var disc_mesh := CylinderMesh.new()
		disc_mesh.top_radius = 0.16
		disc_mesh.bottom_radius = 0.16
		disc_mesh.height = 0.018
		disc_mesh.radial_segments = 28
		disc_mesh.material = metal
		brake_disc.mesh = disc_mesh
		brake_disc.rotation_degrees.x = 90.0
		brake_disc.position.z = 0.07
		root.add_child(brake_disc)
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

func _rear_emissive_material() -> StandardMaterial3D:
	var material := _material(Color(0.74, 0.045, 0.035), 0.06, 0.30)
	material.emission_enabled = true
	material.emission = Color(0.55, 0.015, 0.010)
	material.emission_energy_multiplier = 0.24
	return material

func _glass_material() -> StandardMaterial3D:
	var material := _material(Color(0.055, 0.11, 0.16, 0.78), 0.05, 0.10)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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

func _create_cylinder(node_name: String, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	add_child(visual)
	return visual

func _create_ellipsoid(node_name: String, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 28
	mesh.rings = 16
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

	var tank_size := Vector3(
		clampf(TANK_BASE_SIZE.x * tank_span_ratio, 0.38, TANK_BASE_SIZE.x),
		TANK_BASE_SIZE.y,
		clampf(TANK_BASE_SIZE.z * body_width_ratio, 0.24, TANK_BASE_SIZE.z)
	)
	_set_ellipsoid_transform(
		tank_visual,
		(station1 + station2) * 0.5 + tank_basis.y * 0.18,
		tank_basis,
		tank_size
	)

	_set_box_size(seat_visual, Vector3(
		clampf(SEAT_BASE_SIZE.x * rear_span_ratio, 0.36, SEAT_BASE_SIZE.x),
		SEAT_BASE_SIZE.y,
		clampf(SEAT_BASE_SIZE.z * body_width_ratio, 0.22, SEAT_BASE_SIZE.z)
	))
	seat_visual.position = station1 - rear_basis.x * 0.16 + rear_basis.y * 0.43
	seat_visual.basis = rear_basis

	var handlebar_center := front - front_basis.x * 0.18 + front_basis.y * 0.58
	var handlebar_length := clampf(HANDLEBAR_BASE_SIZE.z * front_width_ratio, 0.48, HANDLEBAR_BASE_SIZE.z)
	_update_cylinder_between_y(
		handlebar_visual,
		handlebar_center - front_basis.z * handlebar_length * 0.5,
		handlebar_center + front_basis.z * handlebar_length * 0.5,
		front_basis.x
	)
	for side in range(mini(handlebar_grips.size(), 2)):
		var side_sign := -1.0 if side == 0 else 1.0
		var grip_outer := handlebar_center + front_basis.z * side_sign * handlebar_length * 0.54
		var grip_inner := handlebar_center + front_basis.z * side_sign * maxf(handlebar_length * 0.36, handlebar_length * 0.54 - 0.13)
		_update_cylinder_between_y(handlebar_grips[side], grip_inner, grip_outer, front_basis.x)

	var headlamp_center := front + front_basis.x * 0.055 + front_basis.y * 0.30
	_update_cylinder_between_y(
		headlamp_visual,
		headlamp_center - front_basis.x * 0.043,
		headlamp_center + front_basis.x * 0.043,
		front_basis.y
	)

	var engine_center := (station1 + station2) * 0.5 - tank_basis.y * 0.17
	engine_visual.position = engine_center
	engine_visual.basis = tank_basis
	_update_cylinder_between_y(
		engine_crankcase_visual,
		engine_center - tank_basis.z * 0.20,
		engine_center + tank_basis.z * 0.20,
		tank_basis.y
	)

	_set_ellipsoid_transform(
		fairing_visual,
		station2 + front_basis.x * 0.20 + front_basis.y * 0.22,
		front_basis,
		Vector3(
			0.40,
			0.46,
			clampf(0.48 * front_width_ratio, 0.30, 0.50)
		)
	)
	windscreen_visual.position = front - front_basis.x * 0.18 + front_basis.y * 0.63
	windscreen_visual.basis = front_basis.rotated(front_basis.z.normalized(), deg_to_rad(-10.0))
	rear_light_visual.position = rear - rear_basis.x * 0.08 + rear_basis.y * 0.48
	rear_light_visual.basis = rear_basis

	var exhaust_start := rear + rear_basis.x * 0.23 - rear_basis.y * 0.18 + rear_basis.z * 0.24
	var exhaust_end := station2 - tank_basis.x * 0.08 - tank_basis.y * 0.22 + tank_basis.z * 0.24
	_update_cylinder_between_y(exhaust_visual, exhaust_start, exhaust_end, basis.y)
	_update_cylinder_between_y(
		exhaust_tip_visual,
		exhaust_start - rear_basis.x * 0.11,
		exhaust_start,
		basis.y
	)

	var footpeg_center := station1 + rear_basis.y * 0.04
	_update_cylinder_between_y(
		footpeg_visual,
		footpeg_center - rear_basis.z * 0.29,
		footpeg_center + rear_basis.z * 0.29,
		rear_basis.x
	)
	_update_box_between_x(
		chain_guard_visual,
		rear + rear_basis.y * 0.01 - rear_basis.z * 0.18,
		station1 + rear_basis.y * 0.02 - rear_basis.z * 0.20,
		rear_basis.y
	)

	for side in range(mini(side_panel_visuals.size(), 2)):
		var side_sign := -1.0 if side == 0 else 1.0
		var panel := side_panel_visuals[side]
		_set_box_size(panel, Vector3(
			clampf(0.46 * tank_span_ratio, 0.28, 0.46),
			0.24,
			0.045
		))
		panel.position = (station1 + station2) * 0.5 - tank_basis.y * 0.02 + tank_basis.z * side_sign * maxf(tank_size.z * 0.48, 0.13)
		panel.basis = tank_basis

	# Independent left/right fork and swingarm tubes follow their authoritative
	# structural endpoints. Cylinder height is along local Y, so use the matching
	# helper rather than the old box/X-axis helper that mis-oriented cylinders.
	for side in range(mini(front_fork_visuals.size(), 2)):
		_update_cylinder_between_y(
			front_fork_visuals[side],
			_node_position(2, 2 + side),
			_node_position(MotorcycleBuilder.FRONT_STATION, side),
			basis.x
		)
	for side in range(mini(rear_swingarm_visuals.size(), 2)):
		_update_cylinder_between_y(
			rear_swingarm_visuals[side],
			_node_position(MotorcycleBuilder.REAR_STATION, side),
			_node_position(1, side),
			basis.x
		)

	for root in wheel_roots:
		var station := int(root.get_meta("station"))
		root.position = _station_center(station)
		root.basis = rear_basis if station == MotorcycleBuilder.REAR_STATION else front_basis
	if debug_renderer != null:
		debug_renderer.update_from_model()

func visual_collapse_m() -> float:
	# Presentation regression metric only: measure the rendered geometry itself.
	# The structural model already has separate deformation regressions. Keeping
	# this metric visual-derived ensures the test fails if the skin ever stops
	# following an otherwise-correct structural collapse.
	var tank_collapse := 0.0
	if tank_visual != null and tank_visual.mesh is SphereMesh:
		# FuelTank uses a unit-diameter/unit-height SphereMesh, so the lengths of
		# its transformed basis axes are the actual rendered ellipsoid dimensions.
		var tank_size := Vector3(
			tank_visual.basis.x.length(),
			tank_visual.basis.y.length(),
			tank_visual.basis.z.length()
		)
		tank_collapse = maxf(
			maxf(TANK_BASE_SIZE.x - tank_size.x, 0.0),
			maxf(TANK_BASE_SIZE.z - tank_size.z, 0.0)
		)

	var seat_collapse := 0.0
	var seat_mesh := seat_visual.mesh as BoxMesh if seat_visual != null else null
	if seat_mesh != null:
		seat_collapse = maxf(
			maxf(SEAT_BASE_SIZE.x - seat_mesh.size.x, 0.0),
			maxf(SEAT_BASE_SIZE.z - seat_mesh.size.z, 0.0)
		)

	var front_fork_collapse := 0.0
	for side in range(mini(front_fork_visuals.size(), 2)):
		var mesh := front_fork_visuals[side].mesh as CylinderMesh
		if mesh == null:
			continue
		var neutral := _neutral_node_position(2, 2 + side).distance_to(
			_neutral_node_position(MotorcycleBuilder.FRONT_STATION, side)
		)
		front_fork_collapse = maxf(front_fork_collapse, neutral - mesh.height)

	var rear_swingarm_collapse := 0.0
	for side in range(mini(rear_swingarm_visuals.size(), 2)):
		var mesh := rear_swingarm_visuals[side].mesh as CylinderMesh
		if mesh == null:
			continue
		var neutral := _neutral_node_position(MotorcycleBuilder.REAR_STATION, side).distance_to(
			_neutral_node_position(1, side)
		)
		rear_swingarm_collapse = maxf(rear_swingarm_collapse, neutral - mesh.height)

	return maxf(
		maxf(tank_collapse, seat_collapse),
		maxf(front_fork_collapse, rear_swingarm_collapse)
	)

func _set_box_size(visual: MeshInstance3D, size: Vector3) -> void:
	if visual == null:
		return
	var mesh := visual.mesh as BoxMesh
	if mesh != null:
		mesh.size = size

func _set_ellipsoid_transform(visual: MeshInstance3D, position_value: Vector3, orientation: Basis, size: Vector3) -> void:
	if visual == null or not visual.mesh is SphereMesh:
		return
	visual.position = position_value
	visual.basis = orientation.orthonormalized() * Basis.from_scale(Vector3(
		maxf(size.x, 0.02),
		maxf(size.y, 0.02),
		maxf(size.z, 0.02)
	))
	visual.set_meta("presentation_size_m", size)

func _update_cylinder_between_y(visual: MeshInstance3D, a: Vector3, b: Vector3, forward_hint: Vector3) -> void:
	if visual == null:
		return
	var delta := b - a
	var length := delta.length()
	if length <= 0.001:
		visual.visible = false
		return
	visual.visible = true
	var mesh := visual.mesh as CylinderMesh
	if mesh != null:
		mesh.height = length
	visual.position = (a + b) * 0.5
	visual.basis = _basis_y_along(delta, forward_hint)
	visual.set_meta("presentation_span_start", a)
	visual.set_meta("presentation_span_end", b)
	visual.set_meta("presentation_length_m", length)

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

func _basis_y_along(direction: Vector3, forward_hint: Vector3) -> Basis:
	var local_y := direction.normalized()
	if local_y.is_zero_approx():
		return Basis.IDENTITY
	var local_x := forward_hint - local_y * forward_hint.dot(local_y)
	if local_x.length_squared() <= 0.0001:
		local_x = Vector3.RIGHT - local_y * Vector3.RIGHT.dot(local_y)
	if local_x.length_squared() <= 0.0001:
		local_x = Vector3.FORWARD - local_y * Vector3.FORWARD.dot(local_y)
	local_x = local_x.normalized()
	var local_z := local_x.cross(local_y).normalized()
	if local_z.is_zero_approx():
		local_z = Vector3.FORWARD
	local_x = local_y.cross(local_z).normalized()
	return Basis(local_x, local_y, local_z).orthonormalized()

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
	_update_cylinder_between_y(visual, a, b, _visual_basis().y)
