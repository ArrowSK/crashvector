# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name HeavyTruck
extends Node3D

@export_range(1000.0, 60000.0, 100.0, "or_greater") var total_mass_kg: float = 18000.0
@export_range(0.0, 140.0, 1.0, "or_greater") var initial_speed_kmh: float = 0.0
@export var origin_offset_m: Vector3 = Vector3(2.0, 0.0, 0.0)
@export_range(-180.0, 180.0, 1.0) var heading_deg: float = 0.0
@export_range(1, 64, 1) var solver_substeps: int = 8
@export var show_structure: bool = false
@export var auto_step: bool = true
@export var hybrid_physics_enabled: bool = true

var model: StructuralModel
var rigid_chassis: VehicleRigidChassis
var last_chassis_transform := Transform3D.IDENTITY
var chassis_sync_ready: bool = false
var debug_renderer: StructuralDebugRenderer
var trailer_visual: MeshInstance3D
var cab_visual: MeshInstance3D
var chassis_visual: MeshInstance3D
var underride_visual: MeshInstance3D
var windshield_visual: MeshInstance3D
var grille_visual: MeshInstance3D
var bumper_visual: MeshInstance3D
var cab_roof_visual: MeshInstance3D
var fifth_wheel_visual: MeshInstance3D
var wheel_visuals: Array[Node3D] = []

func _ready() -> void:
	model = HeavyTruckBuilder.build(total_mass_kg, 0.0, origin_offset_m)
	model.rotate_y_about(origin_offset_m, deg_to_rad(heading_deg), true)
	_prepare_rigid_visual_model()
	_build_rigid_chassis()
	_build_visuals()
	_build_structure_debugger()
	update_from_model()

func _physics_process(delta: float) -> void:
	if model == null or not auto_step:
		return
	if hybrid_physics_enabled:
		step_external(delta)
		return
	model.step(delta, solver_substeps)
	update_from_model()

func step_external(_delta: float) -> void:
	if hybrid_physics_enabled:
		_sync_model_to_chassis()
	update_from_model()

func begin_simulation() -> void:
	if rigid_chassis == null or not hybrid_physics_enabled:
		return
	rigid_chassis.position = origin_offset_m
	rigid_chassis.rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	last_chassis_transform = rigid_chassis.global_transform
	chassis_sync_ready = true
	rigid_chassis.begin_motion(initial_speed_kmh, heading_deg)

func set_simulation_paused(value: bool) -> void:
	if rigid_chassis != null and hybrid_physics_enabled:
		rigid_chassis.set_motion_paused(value)

func end_simulation() -> void:
	if rigid_chassis != null and hybrid_physics_enabled:
		_sync_model_to_chassis()
		rigid_chassis.stop_motion()

func set_preview_pose(position_m: Vector3, yaw_deg: float) -> void:
	origin_offset_m = position_m
	heading_deg = yaw_deg
	if rigid_chassis == null:
		return
	var previous := rigid_chassis.global_transform
	rigid_chassis.position = position_m
	rigid_chassis.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	var current := rigid_chassis.global_transform
	_apply_rigid_delta_to_model(current * previous.affine_inverse())
	last_chassis_transform = current
	chassis_sync_ready = true
	update_from_model()

func toggle_structure_debug() -> void:
	set_structure_debug(not show_structure)

func set_structure_debug(value: bool) -> void:
	show_structure = value
	if debug_renderer != null:
		debug_renderer.visible = value

func global_linear_velocity_ms() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.linear_velocity
	return VehicleKinematics.linear_velocity_ms(model)

func global_momentum_kg_ms() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.linear_velocity * rigid_chassis.mass
	return model.total_momentum_kg_ms()

func global_kinetic_energy_j() -> float:
	if hybrid_physics_enabled and rigid_chassis != null:
		return 0.5 * rigid_chassis.mass * rigid_chassis.linear_velocity.length_squared()
	return model.total_kinetic_energy_j()

func rear_guard_deformation_m() -> float:
	return model.max_permanent_deformation_for_role(&"underride_guard")

func _prepare_rigid_visual_model() -> void:
	for node in model.nodes:
		node.velocity_ms = Vector3.ZERO
		node.pinned = true
		node.inverse_mass = 0.0
	model.gravity_ms2 = Vector3.ZERO
	model.ground_enabled = false
	model.barrier_enabled = false
	model.capture_initial_energy()

func _build_rigid_chassis() -> void:
	rigid_chassis = VehicleRigidChassis.new()
	rigid_chassis.name = "RigidTruckChassis"
	add_child(rigid_chassis)
	rigid_chassis.configure(total_mass_kg, origin_offset_m, heading_deg, initial_speed_kmh, 0.86, 0.0)
	rigid_chassis.add_box_shape("TrailerCollision", Vector3(6.10, 2.95, 2.42), Vector3(3.55, 2.05, 0.0))
	rigid_chassis.add_box_shape("TractorCollision", Vector3(2.65, 2.55, 2.28), Vector3(8.20, 1.72, 0.0))
	rigid_chassis.add_box_shape("TruckFrameCollision", Vector3(9.45, 0.30, 1.80), Vector3(4.72, 0.58, 0.0))
	# M12: road support is suspension force, not rigid tyre spheres. This avoids
	# high-speed wheel/road impulses kicking the truck upward during an impact.
	var mass_scale := maxf(total_mass_kg / 18000.0, 0.20)
	var suspension_k := 300000.0 * mass_scale
	var suspension_c := 22000.0 * sqrt(mass_scale)
	var suspension_max := 85000.0 * mass_scale
	for station in [1, 4, 6]:
		var x := HeavyTruckBuilder.STATION_X[station]
		var z := HeavyTruckBuilder.HALF_WIDTH_Z[station]
		var mount_y := 0.72
		var rest_distance := 0.82
		rigid_chassis.add_suspension_point("TruckSuspension", Vector3(x, mount_y, -z), rest_distance, suspension_k, suspension_c, suspension_max)
		rigid_chassis.add_suspension_point("TruckSuspension", Vector3(x, mount_y, z), rest_distance, suspension_k, suspension_c, suspension_max)
	last_chassis_transform = rigid_chassis.global_transform
	chassis_sync_ready = true

func _sync_model_to_chassis() -> void:
	if rigid_chassis == null:
		return
	var current := rigid_chassis.global_transform
	if not chassis_sync_ready:
		last_chassis_transform = current
		chassis_sync_ready = true
		return
	var delta_transform := current * last_chassis_transform.affine_inverse()
	_apply_rigid_delta_to_model(delta_transform)
	last_chassis_transform = current

func _apply_rigid_delta_to_model(delta_transform: Transform3D) -> void:
	for node in model.nodes:
		node.position_m = delta_transform * node.position_m
		node.velocity_ms = Vector3.ZERO

func _build_visuals() -> void:
	var trailer_material := _material(Color(0.79, 0.81, 0.84), 0.16, 0.52)
	var cab_material := _material(Color(0.10, 0.31, 0.60), 0.46, 0.25)
	var dark := _material(Color(0.035, 0.045, 0.058), 0.40, 0.44)
	var glass := _material(Color(0.035, 0.075, 0.11), 0.12, 0.10)
	var metal := _material(Color(0.24, 0.27, 0.31), 0.75, 0.28)
	trailer_visual = _create_box("TrailerBody", Vector3(5.35, 2.68, 2.42), trailer_material)
	cab_visual = _create_box("TractorCab", Vector3(2.30, 2.45, 2.24), cab_material)
	chassis_visual = _create_box("TruckChassis", Vector3(9.15, 0.18, 1.80), dark)
	underride_visual = _create_box("RearUnderrideGuard", Vector3(0.15, 0.22, 2.18), metal)
	windshield_visual = _create_box("CabWindshield", Vector3(0.075, 0.80, 1.72), glass)
	grille_visual = _create_box("CabGrille", Vector3(0.075, 0.62, 1.52), dark)
	bumper_visual = _create_box("CabBumper", Vector3(0.16, 0.25, 2.08), metal)
	cab_roof_visual = _create_box("CabRoof", Vector3(2.18, 0.12, 2.20), cab_material)
	fifth_wheel_visual = _create_box("FifthWheel", Vector3(0.72, 0.11, 1.15), metal)
	_build_wheels()

func _build_wheels() -> void:
	var tyre_material := _material(Color(0.015, 0.017, 0.020), 0.0, 0.92)
	var rim_material := _material(Color(0.45, 0.48, 0.52), 0.88, 0.22)
	for index in HeavyTruckBuilder.wheel_anchor_indices():
		var root := Node3D.new()
		root.name = "TruckWheel"
		root.set_meta("anchor_index", index)
		add_child(root)
		var tyre := MeshInstance3D.new()
		var tyre_mesh := CylinderMesh.new()
		tyre_mesh.top_radius = 0.46
		tyre_mesh.bottom_radius = 0.46
		tyre_mesh.height = 0.34
		tyre_mesh.radial_segments = 24
		tyre_mesh.material = tyre_material
		tyre.mesh = tyre_mesh
		tyre.rotation_degrees.x = 90.0
		root.add_child(tyre)
		var rim := MeshInstance3D.new()
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.27
		rim_mesh.bottom_radius = 0.27
		rim_mesh.height = 0.36
		rim_mesh.radial_segments = 18
		rim_mesh.material = rim_material
		rim.mesh = rim_mesh
		rim.rotation_degrees.x = 90.0
		root.add_child(rim)
		wheel_visuals.append(root)

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "TruckStructuralDebugRenderer"
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
	var reference := rigid_chassis.global_transform if hybrid_physics_enabled and rigid_chassis != null else VehicleKinematics.reference_transform(
		model,
		HeavyTruckBuilder.rear_reference_nodes(),
		HeavyTruckBuilder.front_reference_nodes(),
		HeavyTruckBuilder.left_reference_nodes(),
		HeavyTruckBuilder.right_reference_nodes()
	)
	var forward := reference.basis.x.normalized()
	var up := reference.basis.y.normalized()
	var basis := reference.basis.orthonormalized()
	var trailer_center := model.average_position_for_nodes(_station_range_nodes(1, HeavyTruckBuilder.TRAILER_END_STATION))
	var tractor_center := model.average_position_for_nodes(_station_range_nodes(5, HeavyTruckBuilder.FRONT_STATION))
	var chassis_center := model.average_position_for_nodes(_station_range_nodes(0, HeavyTruckBuilder.FRONT_STATION))
	var cab_front := model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(HeavyTruckBuilder.FRONT_STATION))
	var cab_rear := model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(5))
	trailer_visual.position = trailer_center + up * 0.14
	trailer_visual.basis = basis
	cab_visual.position = tractor_center - up * 0.02
	cab_visual.basis = basis
	chassis_visual.position = chassis_center - up * 0.66
	chassis_visual.basis = basis
	underride_visual.position = model.average_position_for_nodes(HeavyTruckBuilder.rear_contact_nodes()) - forward * 0.02 - up * 0.18
	underride_visual.basis = basis
	windshield_visual.position = cab_front - forward * 0.02 + up * 0.38
	windshield_visual.basis = basis
	grille_visual.position = cab_front + forward * 0.02 - up * 0.43
	grille_visual.basis = basis
	bumper_visual.position = cab_front + forward * 0.05 - up * 0.86
	bumper_visual.basis = basis
	cab_roof_visual.position = (cab_front + cab_rear) * 0.5 + up * 1.28
	cab_roof_visual.basis = basis
	fifth_wheel_visual.position = model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(5)) - up * 0.50
	fifth_wheel_visual.basis = basis
	for wheel in wheel_visuals:
		var index := int(wheel.get_meta("anchor_index"))
		if index >= 0 and index < model.nodes.size():
			wheel.position = model.nodes[index].position_m - up * 0.31
			wheel.basis = basis
	if debug_renderer != null:
		debug_renderer.update_from_model()

func _station_range_nodes(first_station: int, last_station: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for station in range(first_station, last_station + 1):
		for corner in range(4):
			indices.append(HeavyTruckBuilder.node_index(station, corner))
	return indices