# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CompactHatchback
extends Node3D

@export var vehicle_preset_id: StringName = PassengerCarCatalog.B_SEGMENT_HATCHBACK
@export var paint_id: StringName = CarPaintCatalog.ELECTRIC_BLUE
@export_range(1.0, 100000.0, 1.0, "or_greater") var total_mass_kg: float = 1150.0
@export_range(0.0, 300.0, 1.0, "or_greater") var initial_speed_kmh: float = 50.0
@export var barrier_x_m: float = 5.0
@export var origin_offset_m: Vector3 = Vector3.ZERO
@export_range(-180.0, 180.0, 1.0) var heading_deg: float = 0.0
@export_range(1, 64, 1) var solver_substeps: int = 8
@export var show_structure: bool = true
@export var auto_step: bool = true
@export var hybrid_physics_enabled: bool = true

var model: StructuralModel
var rigid_chassis: VehicleRigidChassis
var body_shell: DeformableBodyShell
var wheel_rig: SimpleWheelRig
var debug_renderer: StructuralDebugRenderer
var front_bumper := MeshInstance3D.new()
var front_bumper_detached: bool = false
var front_bumper_velocity_ms := Vector3.ZERO
var last_chassis_transform := Transform3D.IDENTITY
var chassis_sync_ready: bool = false
var hybrid_crush_impulse_ns: float = 0.0

func _ready() -> void:
	model = PassengerCarBuilder.build(vehicle_preset_id, total_mass_kg, 0.0, barrier_x_m, origin_offset_m)
	model.rotate_y_about(origin_offset_m, deg_to_rad(heading_deg), true)
	_prepare_local_crush_model()
	_build_rigid_chassis()
	_build_body_shell()
	_build_wheels()
	_build_structure_debugger()
	_build_front_bumper()
	_update_visuals(0.0)

func _physics_process(delta: float) -> void:
	if model == null or not auto_step:
		return
	if hybrid_physics_enabled:
		step_external(delta)
		return
	model.step(delta, solver_substeps)
	_update_visuals(delta)

func step_external(delta: float) -> void:
	if hybrid_physics_enabled and rigid_chassis != null and delta > 0.0:
		_sync_model_to_chassis()
		_consume_real_contact_impulses()
		model.step(delta, mini(maxi(solver_substeps, 4), ScenarioConfig.MAX_SOLVER_SUBSTEPS))
	_update_visuals(delta)

func begin_simulation() -> void:
	if not hybrid_physics_enabled or rigid_chassis == null:
		return
	rigid_chassis.position = origin_offset_m
	rigid_chassis.rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	last_chassis_transform = rigid_chassis.global_transform
	chassis_sync_ready = true
	hybrid_crush_impulse_ns = 0.0
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
	_update_visuals(0.0)

func toggle_structure_debug() -> void:
	show_structure = not show_structure
	if debug_renderer != null:
		debug_renderer.visible = show_structure

func set_structure_debug(value: bool) -> void:
	show_structure = value
	if debug_renderer != null:
		debug_renderer.visible = value

func set_paint_id(value: StringName) -> void:
	paint_id = value if CarPaintCatalog.is_valid(value) else CarPaintCatalog.ELECTRIC_BLUE
	if body_shell != null:
		body_shell.set_paint_color(CarPaintCatalog.color(paint_id))

func vehicle_class_name() -> String:
	return PassengerCarCatalog.display_name(vehicle_preset_id)

func global_linear_velocity_ms() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.linear_velocity
	return VehicleKinematics.linear_velocity_ms(model)

func global_angular_velocity_rad_s() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.angular_velocity
	return VehicleKinematics.angular_velocity_rad_s(model)

func global_momentum_kg_ms() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.linear_velocity * rigid_chassis.mass
	return model.total_momentum_kg_ms()

func global_kinetic_energy_j() -> float:
	if hybrid_physics_enabled and rigid_chassis != null:
		return 0.5 * rigid_chassis.mass * rigid_chassis.linear_velocity.length_squared()
	return model.total_kinetic_energy_j()

func global_reference_transform() -> Transform3D:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.global_transform
	return VehicleKinematics.reference_transform(
		model,
		CompactHatchbackBuilder.rear_reference_nodes(),
		CompactHatchbackBuilder.front_reference_nodes(),
		CompactHatchbackBuilder.left_reference_nodes(),
		CompactHatchbackBuilder.right_reference_nodes()
	)

func front_crush_deformation_m() -> float:
	return model.max_permanent_deformation_for_role(&"front_crush")

func safety_cell_deformation_m() -> float:
	return model.max_permanent_deformation_for_role(&"safety_cell")

func hybrid_contact_count() -> int:
	return 0 if rigid_chassis == null else rigid_chassis.non_ground_contact_events

func hybrid_maximum_vertical_speed_ms() -> float:
	return 0.0 if rigid_chassis == null else rigid_chassis.maximum_vertical_speed_ms

func hybrid_maximum_reverse_speed_ms() -> float:
	return 0.0 if rigid_chassis == null else rigid_chassis.maximum_reverse_speed_ms

func replay_visual_state() -> Dictionary:
	return {
		"front_bumper_detached": front_bumper_detached,
		"front_bumper_position_m": front_bumper.position,
		"front_bumper_velocity_ms": front_bumper_velocity_ms,
		"rigid_transform": global_reference_transform(),
		"rigid_linear_velocity_ms": global_linear_velocity_ms(),
	}

func apply_replay_visual_state(state: Dictionary) -> void:
	front_bumper_detached = bool(state.get("front_bumper_detached", false))
	front_bumper_velocity_ms = state.get("front_bumper_velocity_ms", Vector3.ZERO)
	if front_bumper_detached:
		front_bumper.position = state.get("front_bumper_position_m", front_bumper.position)
	_update_visuals(0.0)

func _prepare_local_crush_model() -> void:
	# The Godot rigid chassis owns global translation, rotation, gravity and road
	# contact. The structural graph is retained only as a local deformable nose.
	for node in model.nodes:
		node.velocity_ms = Vector3.ZERO
	for station in range(CompactHatchbackBuilder.CABIN_FRONT_STATION + 1):
		for index in CompactHatchbackBuilder.station_nodes(station):
			model.nodes[index].pinned = true
			model.nodes[index].inverse_mass = 0.0
	model.gravity_ms2 = Vector3.ZERO
	model.ground_enabled = false
	model.barrier_enabled = false
	model.capture_initial_energy()

func _build_rigid_chassis() -> void:
	rigid_chassis = VehicleRigidChassis.new()
	rigid_chassis.name = "RigidChassis"
	add_child(rigid_chassis)
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := float(preset.get("scale_x", 1.0))
	var scale_y := float(preset.get("scale_y", 1.0))
	var scale_z := float(preset.get("scale_z", 1.0))
	rigid_chassis.configure(total_mass_kg, origin_offset_m, heading_deg, initial_speed_kmh, 0.88, 0.0)
	# Compound collision geometry: a protected cell, a low-bounce front contact
	# volume and four real wheel/ground contacts. These shapes move as one rigid
	# chassis; only the visual/local crush graph deforms.
	rigid_chassis.add_box_shape(
		"SafetyCellCollision",
		Vector3(2.55 * scale_x, 0.86 * scale_y, 1.62 * scale_z),
		Vector3(-0.28 * scale_x, 0.88 * scale_y, 0.0)
	)
	rigid_chassis.add_box_shape(
		"FrontContactCollision",
		Vector3(1.48 * scale_x, 0.62 * scale_y, 1.34 * scale_z),
		Vector3(1.30 * scale_x, 0.70 * scale_y, 0.0)
	)
	var wheel_radius := 0.30 * minf(scale_x, scale_z)
	for station in [CompactHatchbackBuilder.REAR_AXLE_STATION, CompactHatchbackBuilder.FRONT_AXLE_STATION]:
		var x := CompactHatchbackBuilder.STATION_X[station] * scale_x
		var z := CompactHatchbackBuilder.HALF_WIDTH_Z[station] * scale_z
		rigid_chassis.add_sphere_shape("WheelCollision", wheel_radius, Vector3(x, wheel_radius, -z))
		rigid_chassis.add_sphere_shape("WheelCollision", wheel_radius, Vector3(x, wheel_radius, z))
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
		node.velocity_ms = delta_transform.basis * node.velocity_ms

func _consume_real_contact_impulses() -> void:
	if rigid_chassis == null:
		return
	var front_impulse := 0.0
	var rear_impulse := 0.0
	for sample in rigid_chassis.drain_contact_samples():
		var collider_name: StringName = sample.get("collider_name", StringName(""))
		if collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround":
			continue
		var impulse: Vector3 = sample.get("impulse", Vector3.ZERO)
		if impulse.length() <= 0.01:
			continue
		var world_position: Vector3 = sample.get("position_world", rigid_chassis.global_position)
		var local_contact := rigid_chassis.to_local(world_position)
		if local_contact.x >= 0.25:
			front_impulse += impulse.length()
		elif local_contact.x <= -0.50:
			rear_impulse += impulse.length()
	if front_impulse > 0.0:
		hybrid_crush_impulse_ns += front_impulse
		_drive_front_crush(front_impulse)
	if rear_impulse > 0.0:
		_drive_rear_crush(rear_impulse)

func _drive_front_crush(contact_impulse_ns: float) -> void:
	var delta_v := minf(contact_impulse_ns / maxf(total_mass_kg, 1.0), 16.0)
	if delta_v <= 0.0001:
		return
	var forward := rigid_chassis.global_transform.basis.x.normalized()
	_apply_axial_kick(PassengerCarBuilder.front_contact_nodes(), -forward, delta_v * 0.72)
	_apply_axial_kick(PassengerCarBuilder.extra_section_nodes(3), -forward, delta_v * 0.50)
	_apply_axial_kick(PassengerCarBuilder.extra_section_nodes(2), -forward, delta_v * 0.30)

func _drive_rear_crush(contact_impulse_ns: float) -> void:
	var delta_v := minf(contact_impulse_ns / maxf(total_mass_kg, 1.0), 10.0)
	if delta_v <= 0.0001:
		return
	var forward := rigid_chassis.global_transform.basis.x.normalized()
	_apply_axial_kick(CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.REAR_STATION), forward, delta_v * 0.45)

func _apply_axial_kick(indices: PackedInt32Array, direction: Vector3, speed_delta_ms: float) -> void:
	var axis := direction.normalized()
	if axis.is_zero_approx():
		return
	for index in indices:
		if index < 0 or index >= model.nodes.size():
			continue
		var node := model.nodes[index]
		if node.pinned:
			continue
		var current_axis_speed := node.velocity_ms.dot(axis)
		var desired_axis_speed := minf(current_axis_speed + speed_delta_ms, 14.0)
		node.velocity_ms += axis * (desired_axis_speed - current_axis_speed)

func _build_body_shell() -> void:
	body_shell = DeformableBodyShell.new()
	body_shell.name = "DeformableBodyShell"
	add_child(body_shell)
	body_shell.configure(model, CompactHatchbackBuilder.STATION_X.size(), CarPaintCatalog.color(paint_id), vehicle_preset_id)

func _build_wheels() -> void:
	wheel_rig = SimpleWheelRig.new()
	wheel_rig.name = "SimpleWheelRig"
	add_child(wheel_rig)
	wheel_rig.configure(model, CompactHatchbackBuilder.wheel_anchor_indices())

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "StructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func _build_front_bumper() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.22, 1.46)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.025, 0.034, 0.045)
	material.metallic = 0.28
	material.roughness = 0.36
	mesh.material = material
	front_bumper.mesh = mesh
	front_bumper.name = "FrontBumper"
	add_child(front_bumper)

func _update_visuals(delta: float) -> void:
	if body_shell != null:
		body_shell.update_from_model()
	if wheel_rig != null:
		wheel_rig.update_from_model(delta)
	if debug_renderer != null:
		debug_renderer.update_from_model()
	_update_front_bumper(delta)

func _update_front_bumper(delta: float) -> void:
	if model == null:
		return
	if not front_bumper_detached:
		var front_nodes := CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_STATION)
		var reference := global_reference_transform()
		var forward := reference.basis.x.normalized()
		var up := reference.basis.y.normalized()
		front_bumper.position = model.average_position_for_nodes(front_nodes) + forward * 0.10 - up * 0.12
		front_bumper.basis = reference.basis
		var should_detach := (
			model.broken_beam_count_for_role(&"front_crush") > 0
			or model.max_permanent_deformation_for_role(&"front_crush") > 0.18
		)
		if should_detach:
			front_bumper_detached = true
			front_bumper_velocity_ms = global_linear_velocity_ms() + model.average_velocity_for_nodes(front_nodes)
		return
	if delta <= 0.0:
		return
	front_bumper_velocity_ms.y -= 9.80665 * delta
	front_bumper.position += front_bumper_velocity_ms * delta
	if front_bumper.position.y < 0.12:
		front_bumper.position.y = 0.12
		if front_bumper_velocity_ms.y < 0.0:
			front_bumper_velocity_ms.y *= -0.18
		front_bumper_velocity_ms.x *= 0.94
		front_bumper_velocity_ms.z *= 0.94
