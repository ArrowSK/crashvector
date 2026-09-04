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
var hybrid_target_front_crush_m: float = 0.0
var hybrid_geometric_front_crush_m: float = 0.0
var hybrid_reference_local_positions: Array[Vector3] = []

# M13 staged whole-body failure state. Whole-vehicle translation/rotation remains
# authoritative in Godot's RigidBody3D. These values represent permanent local
# structural collapse relative to that body once the engineered front zone has
# exhausted its energy/travel capacity.
var hybrid_peak_collision_energy_j: float = 0.0
var hybrid_firewall_intrusion_m: float = 0.0
var hybrid_cabin_collapse_m: float = 0.0
var hybrid_rear_buckle_m: float = 0.0
var hybrid_cell_front_retreat_m: float = 0.0
var hybrid_primary_collider: Object = null
var safety_cell_collision: CollisionShape3D
var safety_cell_base_size_m := Vector3.ZERO
var safety_cell_base_position_m := Vector3.ZERO

func _ready() -> void:
	model = PassengerCarBuilder.build(vehicle_preset_id, total_mass_kg, 0.0, barrier_x_m, origin_offset_m)
	model.rotate_y_about(origin_offset_m, deg_to_rad(heading_deg), true)
	_prepare_local_crush_model()
	_build_rigid_chassis()
	_capture_hybrid_reference_geometry()
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
		_update_hybrid_crush_target()
		_apply_hybrid_crush_resistance()
		model.step(delta, mini(maxi(solver_substeps, 4), ScenarioConfig.MAX_SOLVER_SUBSTEPS))
		_enforce_hybrid_crush_shape(delta)
	_update_visuals(delta)

func begin_simulation() -> void:
	if not hybrid_physics_enabled or rigid_chassis == null:
		return
	rigid_chassis.position = origin_offset_m
	rigid_chassis.rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	last_chassis_transform = rigid_chassis.global_transform
	chassis_sync_ready = true
	_reset_hybrid_failure_state()
	_restore_reference_structure()
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
	return maxf(model.max_permanent_deformation_for_role(&"front_crush"), hybrid_geometric_front_crush_m)

func safety_cell_deformation_m() -> float:
	return maxf(model.max_permanent_deformation_for_role(&"safety_cell"), hybrid_firewall_intrusion_m + hybrid_cabin_collapse_m)

func hybrid_contact_count() -> int:
	if rigid_chassis == null:
		return 0
	return rigid_chassis.non_ground_contact_events + (1 if rigid_chassis.front_probe_contact_ever else 0)

func hybrid_maximum_vertical_speed_ms() -> float:
	return 0.0 if rigid_chassis == null else rigid_chassis.maximum_vertical_speed_ms

func hybrid_maximum_reverse_speed_ms() -> float:
	return 0.0 if rigid_chassis == null else rigid_chassis.maximum_reverse_speed_ms

func hybrid_collision_energy_j() -> float:
	return hybrid_peak_collision_energy_j

func hybrid_firewall_intrusion_deformation_m() -> float:
	return hybrid_firewall_intrusion_m

func hybrid_cabin_collapse_deformation_m() -> float:
	return hybrid_cabin_collapse_m

func hybrid_rear_buckle_deformation_m() -> float:
	return hybrid_rear_buckle_m

func hybrid_total_longitudinal_collapse_m() -> float:
	return hybrid_geometric_front_crush_m + hybrid_cell_front_retreat_m + hybrid_rear_buckle_m * 0.20

func replay_visual_state() -> Dictionary:
	return {
		"front_bumper_detached": front_bumper_detached,
		"front_bumper_position_m": front_bumper.position,
		"front_bumper_velocity_ms": front_bumper_velocity_ms,
		"rigid_transform": global_reference_transform(),
		"rigid_linear_velocity_ms": global_linear_velocity_ms(),
		"hybrid_front_crush_m": hybrid_geometric_front_crush_m,
		"hybrid_collision_energy_j": hybrid_peak_collision_energy_j,
		"hybrid_firewall_intrusion_m": hybrid_firewall_intrusion_m,
		"hybrid_cabin_collapse_m": hybrid_cabin_collapse_m,
		"hybrid_rear_buckle_m": hybrid_rear_buckle_m,
		"hybrid_cell_front_retreat_m": hybrid_cell_front_retreat_m,
	}

func apply_replay_visual_state(state: Dictionary) -> void:
	front_bumper_detached = bool(state.get("front_bumper_detached", false))
	front_bumper_velocity_ms = state.get("front_bumper_velocity_ms", Vector3.ZERO)
	hybrid_geometric_front_crush_m = float(state.get("hybrid_front_crush_m", hybrid_geometric_front_crush_m))
	hybrid_peak_collision_energy_j = float(state.get("hybrid_collision_energy_j", hybrid_peak_collision_energy_j))
	hybrid_firewall_intrusion_m = float(state.get("hybrid_firewall_intrusion_m", hybrid_firewall_intrusion_m))
	hybrid_cabin_collapse_m = float(state.get("hybrid_cabin_collapse_m", hybrid_cabin_collapse_m))
	hybrid_rear_buckle_m = float(state.get("hybrid_rear_buckle_m", hybrid_rear_buckle_m))
	hybrid_cell_front_retreat_m = float(state.get("hybrid_cell_front_retreat_m", hybrid_cell_front_retreat_m))
	if front_bumper_detached:
		front_bumper.position = state.get("front_bumper_position_m", front_bumper.position)
	_update_visuals(0.0)

func _prepare_local_crush_model() -> void:
	# RigidBody3D owns world translation, rotation, gravity and road support.
	# Base/cabin nodes remain kinematically anchored for ordinary crashes so the
	# old spring cloud can never move the car. M13 may reposition those anchored
	# nodes relative to the chassis after the front structure exhausts its
	# energy capacity, which produces stable permanent firewall/cabin collapse
	# without reintroducing M11 whole-car instability.
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
	# The rigid collision volume begins at the protected cell/subframe. In M13
	# its front face may retreat as the firewall/cabin itself collapses, so severe
	# impacts gain real additional travel instead of hitting an indestructible
	# invisible box after roughly one metre of nose crush.
	safety_cell_collision = rigid_chassis.add_box_shape(
		"SafetyCellCollision",
		Vector3(2.55 * scale_x, 0.86 * scale_y, 1.62 * scale_z),
		Vector3(-0.28 * scale_x, 0.88 * scale_y, 0.0)
	)
	safety_cell_base_size_m = (safety_cell_collision.shape as BoxShape3D).size
	safety_cell_base_position_m = safety_cell_collision.position
	rigid_chassis.add_front_crush_sensor(
		Vector3(1.05 * scale_x, 0.72 * scale_y, 1.40 * scale_z),
		Vector3(1.53 * scale_x, 0.72 * scale_y, 0.0)
	)
	var mass_scale := maxf(total_mass_kg / 1150.0, 0.45)
	var suspension_k := 65000.0 * mass_scale
	var suspension_c := 6000.0 * sqrt(mass_scale)
	var suspension_max := 18000.0 * mass_scale
	for station in [CompactHatchbackBuilder.REAR_AXLE_STATION, CompactHatchbackBuilder.FRONT_AXLE_STATION]:
		var x := CompactHatchbackBuilder.STATION_X[station] * scale_x
		var z := CompactHatchbackBuilder.HALF_WIDTH_Z[station] * scale_z
		var mount_y := 0.62 * scale_y
		var rest_distance := 0.665 * scale_y
		rigid_chassis.add_suspension_point("Suspension", Vector3(x, mount_y, -z), rest_distance, suspension_k, suspension_c, suspension_max)
		rigid_chassis.add_suspension_point("Suspension", Vector3(x, mount_y, z), rest_distance, suspension_k, suspension_c, suspension_max)
	last_chassis_transform = rigid_chassis.global_transform
	chassis_sync_ready = true

func _capture_hybrid_reference_geometry() -> void:
	hybrid_reference_local_positions.clear()
	hybrid_reference_local_positions.resize(model.nodes.size())
	for index in range(model.nodes.size()):
		hybrid_reference_local_positions[index] = rigid_chassis.to_local(model.nodes[index].position_m)

func _reset_hybrid_failure_state() -> void:
	hybrid_crush_impulse_ns = 0.0
	hybrid_target_front_crush_m = 0.0
	hybrid_geometric_front_crush_m = 0.0
	hybrid_peak_collision_energy_j = 0.0
	hybrid_firewall_intrusion_m = 0.0
	hybrid_cabin_collapse_m = 0.0
	hybrid_rear_buckle_m = 0.0
	hybrid_cell_front_retreat_m = 0.0
	hybrid_primary_collider = null
	front_bumper_detached = false
	front_bumper_velocity_ms = Vector3.ZERO
	_reset_safety_cell_collision()

func _restore_reference_structure() -> void:
	if rigid_chassis == null or hybrid_reference_local_positions.size() != model.nodes.size():
		return
	for index in range(model.nodes.size()):
		model.nodes[index].position_m = rigid_chassis.to_global(hybrid_reference_local_positions[index])
		model.nodes[index].velocity_ms = Vector3.ZERO

func _reset_safety_cell_collision() -> void:
	if safety_cell_collision == null:
		return
	var box := safety_cell_collision.shape as BoxShape3D
	if box == null:
		return
	box.size = safety_cell_base_size_m
	safety_cell_collision.position = safety_cell_base_position_m
	if rigid_chassis.front_crush_probe != null:
		var probe_position := rigid_chassis.front_crush_probe.position
		probe_position.x = safety_cell_base_position_m.x + safety_cell_base_size_m.x * 0.5
		rigid_chassis.front_crush_probe.position = probe_position

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
	for sample in rigid_chassis.drain_contact_samples():
		var collider_name: StringName = sample.get("collider_name", StringName(""))
		if collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround":
			continue
		var impulse: Vector3 = sample.get("impulse", Vector3.ZERO)
		hybrid_crush_impulse_ns += impulse.length()

func _update_hybrid_crush_target() -> void:
	if rigid_chassis == null:
		return
	if rigid_chassis.front_crush_overlap_active():
		var collider := rigid_chassis.front_crush_collider()
		if hybrid_primary_collider == null:
			hybrid_primary_collider = collider
		hybrid_peak_collision_energy_j = maxf(hybrid_peak_collision_energy_j, _normal_collision_energy_j(collider))
	hybrid_target_front_crush_m = maxf(hybrid_target_front_crush_m, rigid_chassis.front_crush_travel_m())
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := float(preset.get("scale_x", 1.0))
	hybrid_target_front_crush_m = clampf(hybrid_target_front_crush_m, 0.0, 0.98 * scale_x)

func _normal_collision_energy_j(collider: Object) -> float:
	if rigid_chassis == null:
		return 0.0
	var forward := rigid_chassis.global_transform.basis.x.normalized()
	var collider_velocity := Vector3.ZERO
	var effective_mass := rigid_chassis.mass
	if collider is RigidBody3D:
		var other := collider as RigidBody3D
		collider_velocity = other.linear_velocity
		var other_mass := maxf(other.mass, 1.0)
		effective_mass = rigid_chassis.mass * other_mass / maxf(rigid_chassis.mass + other_mass, 1.0)
	var closing_speed := maxf((rigid_chassis.linear_velocity - collider_velocity).dot(forward), 0.0)
	return 0.5 * effective_mass * closing_speed * closing_speed

func _failure_stage_targets() -> Dictionary:
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := maxf(float(preset.get("scale_x", 1.0)), 0.55)
	var stiffness_scale := maxf(float(preset.get("stiffness_scale", 1.0)), 0.45)
	var structural_scale := stiffness_scale * scale_x
	var front_capacity_j := 430000.0 * structural_scale
	var firewall_capacity_j := 260000.0 * structural_scale
	var cabin_capacity_j := 620000.0 * structural_scale
	var rear_capacity_j := 520000.0 * structural_scale
	var front_design_crush := maxf(0.98 * scale_x, 0.20)
	var front_ratio := clampf(hybrid_target_front_crush_m / front_design_crush, 0.0, 1.0)
	var front_gate := smoothstep(0.82, 0.97, front_ratio)
	var firewall_fraction := clampf((hybrid_peak_collision_energy_j - front_capacity_j) / maxf(firewall_capacity_j, 1.0), 0.0, 1.0) * front_gate
	var cabin_fraction := clampf((hybrid_peak_collision_energy_j - front_capacity_j - firewall_capacity_j) / maxf(cabin_capacity_j, 1.0), 0.0, 1.0)
	cabin_fraction *= smoothstep(0.70, 0.98, firewall_fraction)
	var rear_fraction := clampf((hybrid_peak_collision_energy_j - front_capacity_j - firewall_capacity_j - cabin_capacity_j) / maxf(rear_capacity_j, 1.0), 0.0, 1.0)
	rear_fraction *= smoothstep(0.72, 0.98, cabin_fraction)
	return {
		"firewall_m": 0.30 * scale_x * firewall_fraction,
		"cabin_m": 0.82 * scale_x * cabin_fraction,
		"rear_m": 0.28 * scale_x * rear_fraction,
	}

func _apply_hybrid_crush_resistance() -> void:
	if rigid_chassis == null or not rigid_chassis.front_crush_overlap_active():
		return
	var collider := rigid_chassis.front_crush_collider()
	var forward := rigid_chassis.global_transform.basis.x.normalized()
	var collider_velocity := Vector3.ZERO
	if collider is RigidBody3D:
		collider_velocity = (collider as RigidBody3D).linear_velocity
	var closing_speed := (rigid_chassis.linear_velocity - collider_velocity).dot(forward)
	if closing_speed <= 0.01:
		return
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var stiffness_scale := maxf(float(preset.get("stiffness_scale", 1.0)), 0.45)
	var mass_scale := sqrt(maxf(total_mass_kg / 1150.0, 0.45))
	var crush := hybrid_target_front_crush_m
	# Normal impacts retain the M12 crash-box/rail curve. Once M13 staged cell
	# failure begins, resistance rises again for firewall/rocker/A-pillar load
	# paths rather than letting the remaining energy disappear into a rigid box.
	var force_n := (105000.0 + 155000.0 * clampf(crush / 0.62, 0.0, 1.0)) * stiffness_scale * mass_scale
	if crush > 0.62:
		force_n += 420000.0 * stiffness_scale * mass_scale * clampf((crush - 0.62) / 0.30, 0.0, 1.0)
	var cell_failure := hybrid_firewall_intrusion_m + hybrid_cabin_collapse_m
	if cell_failure > 0.01:
		force_n += (220000.0 + 520000.0 * clampf(cell_failure / 0.90, 0.0, 1.0)) * stiffness_scale * mass_scale
	force_n = minf(force_n, 1380000.0 * stiffness_scale * mass_scale)
	if collider is VehicleRigidChassis:
		var other := collider as VehicleRigidChassis
		# Only one side applies the equal/opposite pair to avoid double counting
		# when two passenger-car crush sensors overlap each other.
		if rigid_chassis.get_instance_id() > other.get_instance_id():
			return
		rigid_chassis.apply_central_force(-forward * force_n)
		other.apply_central_force(forward * force_n)
	else:
		rigid_chassis.apply_central_force(-forward * force_n)

func _enforce_hybrid_crush_shape(delta: float) -> void:
	if hybrid_reference_local_positions.size() != model.nodes.size():
		return
	if hybrid_target_front_crush_m <= 0.0001 and hybrid_peak_collision_energy_j <= 0.0:
		return
	var alpha := clampf(1.0 - exp(-28.0 * maxf(delta, 0.0)), 0.0, 1.0)
	var stage_targets := _failure_stage_targets()
	hybrid_firewall_intrusion_m = maxf(hybrid_firewall_intrusion_m, lerpf(hybrid_firewall_intrusion_m, float(stage_targets["firewall_m"]), alpha))
	hybrid_cabin_collapse_m = maxf(hybrid_cabin_collapse_m, lerpf(hybrid_cabin_collapse_m, float(stage_targets["cabin_m"]), alpha))
	hybrid_rear_buckle_m = maxf(hybrid_rear_buckle_m, lerpf(hybrid_rear_buckle_m, float(stage_targets["rear_m"]), alpha))
	var retreat_target := hybrid_firewall_intrusion_m + hybrid_cabin_collapse_m * 0.75 + hybrid_rear_buckle_m * 0.18
	hybrid_cell_front_retreat_m = maxf(hybrid_cell_front_retreat_m, lerpf(hybrid_cell_front_retreat_m, retreat_target, alpha))
	_update_safety_cell_collision_shape()

	var sections: Array[Dictionary] = [
		{"nodes": PassengerCarBuilder.extra_section_nodes(0), "weight": 0.18},
		{"nodes": PassengerCarBuilder.extra_section_nodes(1), "weight": 0.32},
		{"nodes": CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_AXLE_STATION), "weight": 0.50},
		{"nodes": PassengerCarBuilder.extra_section_nodes(2), "weight": 0.68},
		{"nodes": PassengerCarBuilder.extra_section_nodes(3), "weight": 0.86},
		{"nodes": PassengerCarBuilder.front_contact_nodes(), "weight": 1.00},
	]
	var normalized_crush := clampf(hybrid_target_front_crush_m / 0.90, 0.0, 1.0)
	for section in sections:
		var indices: PackedInt32Array = section["nodes"]
		var weight := float(section["weight"])
		for index in indices:
			if index < 0 or index >= model.nodes.size() or model.nodes[index].pinned:
				continue
			var reference_local := hybrid_reference_local_positions[index]
			var target_local := reference_local
			target_local.x -= hybrid_cell_front_retreat_m + hybrid_target_front_crush_m * weight
			var corner := index % 4
			if corner >= 2:
				target_local.y -= 0.10 * hybrid_target_front_crush_m * weight
			else:
				target_local.y += 0.025 * hybrid_target_front_crush_m * weight
			target_local.z *= 1.0 - 0.07 * normalized_crush * weight
			var target_world := rigid_chassis.to_global(target_local)
			model.nodes[index].position_m = model.nodes[index].position_m.lerp(target_world, alpha)
			model.nodes[index].velocity_ms *= 0.80

	# Staged collapse propagates rearward only after the front capacity is
	# consumed. Upper nodes move farther/downward than floor nodes so the cowl,
	# A-pillars and roof buckle instead of the cabin translating as a rigid box.
	_enforce_cabin_station(
		CompactHatchbackBuilder.CABIN_FRONT_STATION,
		hybrid_firewall_intrusion_m + hybrid_cabin_collapse_m * 0.72,
		hybrid_firewall_intrusion_m * 0.20 + hybrid_cabin_collapse_m * 0.48,
		hybrid_firewall_intrusion_m * 0.08 + hybrid_cabin_collapse_m * 0.10,
		0.11 * clampf(hybrid_cabin_collapse_m / 0.82, 0.0, 1.0), alpha
	)
	_enforce_cabin_station(
		3,
		hybrid_firewall_intrusion_m * 0.12 + hybrid_cabin_collapse_m * 0.46,
		hybrid_cabin_collapse_m * 0.38,
		hybrid_cabin_collapse_m * 0.07,
		0.10 * clampf(hybrid_cabin_collapse_m / 0.82, 0.0, 1.0), alpha
	)
	_enforce_cabin_station(
		2,
		hybrid_cabin_collapse_m * 0.20 + hybrid_rear_buckle_m * 0.05,
		hybrid_cabin_collapse_m * 0.22 + hybrid_rear_buckle_m * 0.05,
		hybrid_cabin_collapse_m * 0.035,
		0.07 * clampf(hybrid_cabin_collapse_m / 0.82, 0.0, 1.0), alpha
	)
	_enforce_cabin_station(
		CompactHatchbackBuilder.CABIN_REAR_STATION,
		-hybrid_rear_buckle_m * 0.08,
		hybrid_rear_buckle_m * 0.12,
		hybrid_rear_buckle_m * 0.04,
		0.05 * clampf(hybrid_rear_buckle_m / 0.28, 0.0, 1.0), alpha
	)
	_enforce_cabin_station(
		CompactHatchbackBuilder.REAR_STATION,
		-hybrid_rear_buckle_m * 0.24,
		hybrid_rear_buckle_m * 0.08,
		hybrid_rear_buckle_m * 0.025,
		0.04 * clampf(hybrid_rear_buckle_m / 0.28, 0.0, 1.0), alpha
	)
	_update_geometric_crush_measurement()

func _enforce_cabin_station(
	station: int,
	x_shift_m: float,
	roof_drop_m: float,
	floor_drop_m: float,
	width_failure: float,
	alpha: float
) -> void:
	for corner in range(4):
		var index := CompactHatchbackBuilder.node_index(station, corner)
		if index < 0 or index >= model.nodes.size():
			continue
		var target_local := hybrid_reference_local_positions[index]
		var upper := corner >= 2
		target_local.x -= x_shift_m * (1.08 if upper else 0.92)
		if upper:
			target_local.y -= roof_drop_m
			target_local.z *= 1.0 - width_failure
		else:
			target_local.y -= floor_drop_m
			target_local.z *= 1.0 + width_failure * 0.45
		var target_world := rigid_chassis.to_global(target_local)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(target_world, alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO

func _update_safety_cell_collision_shape() -> void:
	if safety_cell_collision == null:
		return
	var box := safety_cell_collision.shape as BoxShape3D
	if box == null:
		return
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := maxf(float(preset.get("scale_x", 1.0)), 0.55)
	var base_rear_x := safety_cell_base_position_m.x - safety_cell_base_size_m.x * 0.5
	var base_front_x := safety_cell_base_position_m.x + safety_cell_base_size_m.x * 0.5
	var rear_face_x := base_rear_x + hybrid_rear_buckle_m * 0.10
	var front_face_x := base_front_x - hybrid_cell_front_retreat_m
	var minimum_length := 1.05 * scale_x
	front_face_x = maxf(front_face_x, rear_face_x + minimum_length)
	var new_size := safety_cell_base_size_m
	new_size.x = front_face_x - rear_face_x
	box.size = new_size
	var new_position := safety_cell_base_position_m
	new_position.x = (front_face_x + rear_face_x) * 0.5
	safety_cell_collision.position = new_position
	# Keep the distance probe on the current structural front face. This lets it
	# continue measuring the obstacle while the protected-cell collision face
	# retreats during catastrophic collapse.
	if rigid_chassis.front_crush_probe != null:
		var probe_position := rigid_chassis.front_crush_probe.position
		probe_position.x = front_face_x
		rigid_chassis.front_crush_probe.position = probe_position

func _update_geometric_crush_measurement() -> void:
	var front := PassengerCarBuilder.front_contact_nodes()
	if front.is_empty():
		return
	var original_x := 0.0
	var current_x := 0.0
	var count := 0
	for index in front:
		if index < 0 or index >= model.nodes.size():
			continue
		original_x += hybrid_reference_local_positions[index].x
		current_x += rigid_chassis.to_local(model.nodes[index].position_m).x
		count += 1
	if count > 0:
		# Remove protected-cell retreat from the nose-only measurement. Whole-body
		# shortening is reported separately by hybrid_total_longitudinal_collapse_m.
		var measured := (original_x - current_x) / float(count) - hybrid_cell_front_retreat_m
		hybrid_geometric_front_crush_m = maxf(hybrid_geometric_front_crush_m, maxf(measured, 0.0))

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
			or hybrid_geometric_front_crush_m > 0.38
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
