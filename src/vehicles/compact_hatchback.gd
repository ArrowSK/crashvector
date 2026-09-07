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
	if hybrid_physics_enabled and rigid_chassis != null:
		var previous := rigid_chassis.global_transform
		rigid_chassis.position = position_m
		rigid_chassis.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
		var current := rigid_chassis.global_transform
		_apply_rigid_delta_to_model(current * previous.affine_inverse())
		last_chassis_transform = current
		chassis_sync_ready = true
		_update_visuals(0.0)
		return
	var current_center := model.center_of_mass_m()
	var delta := position_m - current_center
	model.translate(delta, true)
	model.rotate_y_about(position_m, deg_to_rad(yaw_deg - global_heading_deg()), true)
	_update_visuals(0.0)

func global_reference_transform() -> Transform3D:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.global_transform
	return model.reference_transform()

func global_heading_deg() -> float:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rad_to_deg(atan2(-rigid_chassis.global_transform.basis.x.z, rigid_chassis.global_transform.basis.x.x))
	return model.heading_deg()

func global_linear_velocity_ms() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.linear_velocity
	return model.center_of_mass_velocity_ms()

func global_momentum_kg_ms() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.linear_velocity * rigid_chassis.mass
	return model.total_momentum_kg_ms()

func global_kinetic_energy_j() -> float:
	if hybrid_physics_enabled and rigid_chassis != null:
		return 0.5 * rigid_chassis.mass * rigid_chassis.linear_velocity.length_squared()
	return model.total_kinetic_energy_j()

func front_crush_deformation_m() -> float:
	return maxf(hybrid_target_front_crush_m, hybrid_geometric_front_crush_m)

func safety_cell_deformation_m() -> float:
	return maxf(model.max_permanent_deformation_for_role(&"safety_cell"), hybrid_cabin_collapse_m)

func hybrid_contact_count() -> int:
	if rigid_chassis != null and hybrid_physics_enabled:
		return rigid_chassis.non_ground_contact_events
	return 0

func hybrid_maximum_vertical_speed_ms() -> float:
	return rigid_chassis.maximum_vertical_speed_ms if rigid_chassis != null else 0.0

func hybrid_maximum_reverse_speed_ms() -> float:
	return rigid_chassis.maximum_reverse_speed_ms if rigid_chassis != null else 0.0

func hybrid_total_longitudinal_collapse_m() -> float:
	return front_crush_deformation_m() + hybrid_firewall_intrusion_m + hybrid_cabin_collapse_m + hybrid_rear_buckle_m

func replay_visual_state() -> Dictionary:
	var state := {
		"hybrid_physics_enabled": hybrid_physics_enabled,
		"front_crush_m": front_crush_deformation_m(),
		"hybrid_target_front_crush_m": hybrid_target_front_crush_m,
		"hybrid_geometric_front_crush_m": hybrid_geometric_front_crush_m,
		"hybrid_peak_collision_energy_j": hybrid_peak_collision_energy_j,
		"hybrid_firewall_intrusion_m": hybrid_firewall_intrusion_m,
		"hybrid_cabin_collapse_m": hybrid_cabin_collapse_m,
		"hybrid_rear_buckle_m": hybrid_rear_buckle_m,
		"hybrid_cell_front_retreat_m": hybrid_cell_front_retreat_m,
		"rigid_transform": rigid_chassis.global_transform if rigid_chassis != null else Transform3D.IDENTITY,
		"rigid_linear_velocity": rigid_chassis.linear_velocity if rigid_chassis != null else Vector3.ZERO,
		"rigid_angular_velocity": rigid_chassis.angular_velocity if rigid_chassis != null else Vector3.ZERO,
	}
	return state

func apply_replay_visual_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	if rigid_chassis != null and state.has("rigid_transform"):
		rigid_chassis.global_transform = state.get("rigid_transform", rigid_chassis.global_transform)
		rigid_chassis.linear_velocity = state.get("rigid_linear_velocity", Vector3.ZERO)
		rigid_chassis.angular_velocity = state.get("rigid_angular_velocity", Vector3.ZERO)
		hybrid_target_front_crush_m = float(state.get("hybrid_target_front_crush_m", state.get("front_crush_m", 0.0)))
		hybrid_geometric_front_crush_m = float(state.get("hybrid_geometric_front_crush_m", 0.0))
		hybrid_peak_collision_energy_j = float(state.get("hybrid_peak_collision_energy_j", 0.0))
		hybrid_firewall_intrusion_m = float(state.get("hybrid_firewall_intrusion_m", 0.0))
		hybrid_cabin_collapse_m = float(state.get("hybrid_cabin_collapse_m", 0.0))
		hybrid_rear_buckle_m = float(state.get("hybrid_rear_buckle_m", 0.0))
		hybrid_cell_front_retreat_m = float(state.get("hybrid_cell_front_retreat_m", 0.0))
		_update_safety_cell_collision_shape()
		last_chassis_transform = rigid_chassis.global_transform
		chassis_sync_ready = true
	_update_visuals(0.0)

func set_structure_debug(value: bool) -> void:
	show_structure = value
	if debug_renderer != null:
		debug_renderer.visible = value

func _prepare_local_crush_model() -> void:
	# M12: structural integration remains local deformation only. Whole-body
	# translation/rotation is driven by RigidBody3D, so keep all vehicle nodes as
	# local solver anchors and only move them explicitly with the chassis pose and
	# crush target below.
	for node in model.nodes:
		node.pinned = true

func _build_rigid_chassis() -> void:
	rigid_chassis = VehicleRigidChassis.new()
	rigid_chassis.name = "PrimaryRigidChassis"
	add_child(rigid_chassis)
	rigid_chassis.configure(total_mass_kg, origin_offset_m, heading_deg, initial_speed_kmh)
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := float(preset.get("scale_x", 1.0))
	var scale_z := float(preset.get("scale_z", 1.0))
	var cell_size := Vector3(2.15 * scale_x, 0.82, 1.48 * scale_z)
	var cell_position := Vector3(-0.68 * scale_x, 0.58, 0.0)
	safety_cell_collision = rigid_chassis.add_box_shape("ProtectedCellCollision", cell_size, cell_position)
	safety_cell_base_size_m = cell_size
	safety_cell_base_position_m = cell_position
	var front_probe_size := Vector3(1.45 * scale_x, 0.64, 1.34 * scale_z)
	var front_probe_position := Vector3(1.12 * scale_x, 0.52, 0.0)
	rigid_chassis.add_front_crush_sensor(front_probe_size, front_probe_position)
	var suspension_stiffness := maxf(total_mass_kg * 9.80665 / (4.0 * 0.075), 18000.0)
	var suspension_damping := 2.0 * sqrt(suspension_stiffness * maxf(total_mass_kg / 4.0, 1.0)) * 0.72
	var max_force := maxf(total_mass_kg * 9.80665 * 0.90, 6000.0)
	var wheel_y := 0.48
	var rest_distance := 0.50
	for wheel in [
		["SuspensionFL", Vector3(0.94 * scale_x, wheel_y, -0.63 * scale_z)],
		["SuspensionFR", Vector3(0.94 * scale_x, wheel_y, 0.63 * scale_z)],
		["SuspensionRL", Vector3(-1.20 * scale_x, wheel_y, -0.63 * scale_z)],
		["SuspensionRR", Vector3(-1.20 * scale_x, wheel_y, 0.63 * scale_z)],
	]:
		rigid_chassis.add_suspension_point(
			String(wheel[0]),
			wheel[1],
			rest_distance,
			suspension_stiffness,
			suspension_damping,
			max_force
		)
	last_chassis_transform = rigid_chassis.global_transform
	chassis_sync_ready = true

func _capture_hybrid_reference_geometry() -> void:
	hybrid_reference_local_positions.clear()
	for node in model.nodes:
		hybrid_reference_local_positions.append(rigid_chassis.to_local(node.position_m))

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
	if safety_cell_collision != null:
		var box := safety_cell_collision.shape as BoxShape3D
		if box != null:
			box.size = safety_cell_base_size_m
		safety_cell_collision.position = safety_cell_base_position_m

func _restore_reference_structure() -> void:
	if rigid_chassis == null or hybrid_reference_local_positions.size() != model.nodes.size():
		return
	for i in range(model.nodes.size()):
		model.nodes[i].position_m = rigid_chassis.to_global(hybrid_reference_local_positions[i])
		model.nodes[i].velocity_ms = Vector3.ZERO

func _sync_model_to_chassis() -> void:
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
	if front_bumper_detached:
		front_bumper.position = delta_transform * front_bumper.position

func _consume_real_contact_impulses() -> void:
	if rigid_chassis == null:
		return
	# M12 only consumes the real Godot contact impulse as a deformation/load
	# signal. It does not re-apply that impulse to the rigid body.
	for sample in rigid_chassis.drain_contact_samples():
		var collider_name: StringName = sample.get("collider_name", StringName(""))
		if collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround":
			continue
		var impulse: Vector3 = sample.get("impulse", Vector3.ZERO)
		hybrid_crush_impulse_ns += impulse.length()

func _update_hybrid_crush_target() -> void:
	if rigid_chassis == null:
		return
	var travel := rigid_chassis.front_crush_travel_m()
	var closing_speed := maxf(rigid_chassis.linear_velocity.dot(rigid_chassis.initial_forward_world), 0.0)
	var collider := rigid_chassis.front_crush_collider()
	var target_speed := Vector3.ZERO
	var target_mass := 0.0
	if collider is RigidBody3D:
		var target := collider as RigidBody3D
		target_speed = target.linear_velocity
		target_mass = target.mass
	elif collider != null:
		# Static obstacle: infinite target mass gives reduced mass = vehicle mass.
		target_mass = rigid_chassis.mass * 1000000.0
	var relative_speed := absf((rigid_chassis.linear_velocity - target_speed).dot(rigid_chassis.initial_forward_world))
	if relative_speed <= 0.001:
		relative_speed = closing_speed
	var reduced_mass := rigid_chassis.mass
	if target_mass > 0.0:
		reduced_mass = rigid_chassis.mass * target_mass / maxf(rigid_chassis.mass + target_mass, 1.0)
	var collision_energy := 0.5 * reduced_mass * relative_speed * relative_speed
	if travel > 0.0 and rigid_chassis.front_crush_overlap_active():
		hybrid_primary_collider = collider
		hybrid_peak_collision_energy_j = maxf(hybrid_peak_collision_energy_j, collision_energy)
	var demand_crush := _hybrid_energy_limited_crush_m(collision_energy)
	var crush_cap := _hybrid_front_crush_cap_m()
	# Geometric overlap is authoritative for the early crush-zone motion; the
	# energy curve limits unrealistic penetration rather than replacing contact.
	hybrid_target_front_crush_m = maxf(
		hybrid_target_front_crush_m,
		minf(maxf(travel, demand_crush * 0.72), crush_cap)
	)
	_update_hybrid_failure_demand(collision_energy)

func _hybrid_energy_limited_crush_m(collision_energy_j: float) -> float:
	if collision_energy_j <= 0.0:
		return 0.0
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var stiffness_scale := float(preset.get("stiffness_scale", 1.0))
	var mass_scale := sqrt(maxf(total_mass_kg / 1150.0, 0.45))
	var resistance_scale := stiffness_scale * mass_scale
	var force0_n := 130000.0 * resistance_scale
	var stiffness_n_m := 260000.0 * resistance_scale
	var discriminant := force0_n * force0_n + 2.0 * stiffness_n_m * collision_energy_j
	return maxf((-force0_n + sqrt(maxf(discriminant, 0.0))) / maxf(stiffness_n_m, 1.0), 0.0)

func _hybrid_front_crush_cap_m() -> float:
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := float(preset.get("scale_x", 1.0))
	# Preserve the M12 usable front travel at ordinary energy while leaving the
	# later M13 stages responsible for firewall/cabin/rear collapse.
	return 0.95 * scale_x

func _hybrid_crush_resistance_n() -> float:
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var stiffness_scale := float(preset.get("stiffness_scale", 1.0))
	var mass_scale := sqrt(maxf(total_mass_kg / 1150.0, 0.45))
	var resistance_scale := stiffness_scale * mass_scale
	return (130000.0 + 260000.0 * hybrid_target_front_crush_m) * resistance_scale

func _apply_hybrid_crush_resistance() -> void:
	if rigid_chassis == null or not rigid_chassis.front_crush_overlap_active():
		return
	var forward := rigid_chassis.initial_forward_world.normalized()
	var normal_speed := rigid_chassis.linear_velocity.dot(forward)
	if normal_speed <= 0.05:
		return
	var target_force_n := _hybrid_crush_resistance_n()
	var impulse_step := target_force_n * get_physics_process_delta_time()
	var maximum_impulse := rigid_chassis.mass * normal_speed * 0.28
	var applied_impulse := minf(impulse_step, maximum_impulse)
	rigid_chassis.apply_central_impulse(-forward * applied_impulse)

func _update_hybrid_failure_demand(collision_energy_j: float) -> void:
	var front_capacity_j := _hybrid_front_zone_capacity_j()
	var residual_j := maxf(collision_energy_j - front_capacity_j, 0.0)
	var firewall_capacity_j := 200000.0 * _hybrid_failure_scale()
	var cabin_capacity_j := 420000.0 * _hybrid_failure_scale()
	var rear_capacity_j := 950000.0 * _hybrid_failure_scale()

	hybrid_peak_collision_energy_j = maxf(hybrid_peak_collision_energy_j, collision_energy_j)
	hybrid_firewall_intrusion_m = maxf(
		hybrid_firewall_intrusion_m,
		_stage_deformation_m(residual_j, firewall_capacity_j, 0.30)
	)
	hybrid_cabin_collapse_m = maxf(
		hybrid_cabin_collapse_m,
		_stage_deformation_m(maxf(residual_j - firewall_capacity_j, 0.0), cabin_capacity_j, 0.82)
	)
	hybrid_rear_buckle_m = maxf(
		hybrid_rear_buckle_m,
		_stage_deformation_m(maxf(residual_j - firewall_capacity_j - cabin_capacity_j, 0.0), rear_capacity_j, 0.55)
	)
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := float(preset.get("scale_x", 1.0))
	hybrid_cell_front_retreat_m = minf(
		hybrid_firewall_intrusion_m * 0.80 + hybrid_cabin_collapse_m * 0.38,
		0.72 * scale_x
	)

func _hybrid_front_zone_capacity_j() -> float:
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var stiffness_scale := float(preset.get("stiffness_scale", 1.0))
	var mass_scale := sqrt(maxf(total_mass_kg / 1150.0, 0.45))
	var resistance_scale := stiffness_scale * mass_scale
	var crush_cap := _hybrid_front_crush_cap_m()
	return (130000.0 * crush_cap + 0.5 * 260000.0 * crush_cap * crush_cap) * resistance_scale

func _hybrid_failure_scale() -> float:
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var stiffness_scale := float(preset.get("stiffness_scale", 1.0))
	var mass_scale := sqrt(maxf(total_mass_kg / 1150.0, 0.45))
	return maxf(stiffness_scale * mass_scale, 0.45)

func _stage_deformation_m(residual_energy_j: float, capacity_j: float, maximum_m: float) -> float:
	if residual_energy_j <= 0.0 or capacity_j <= 0.0:
		return 0.0
	# Smoothly approaches the stage deformation limit instead of introducing a
	# new speed threshold or discontinuous failure jump.
	return maximum_m * (1.0 - exp(-residual_energy_j / capacity_j))

func _enforce_hybrid_crush_shape(delta: float) -> void:
	if rigid_chassis == null or hybrid_reference_local_positions.size() != model.nodes.size():
		return
	var alpha := clampf(1.0 - exp(-26.0 * delta), 0.0, 1.0)
	var front_station_count := CompactHatchbackBuilder.FRONT_STATION
	var front_scale := maxf(hybrid_target_front_crush_m, 0.0)
	for station in range(CompactHatchbackBuilder.FRONT_STATION, CompactHatchbackBuilder.SAFETY_FRONT_STATION - 1, -1):
		var relative := float(station - CompactHatchbackBuilder.SAFETY_FRONT_STATION) / float(maxi(front_station_count - CompactHatchbackBuilder.SAFETY_FRONT_STATION, 1))
		var weight := clampf(relative, 0.0, 1.0)
		for corner in range(4):
			var index := CompactHatchbackBuilder.node_index(station, corner)
			if index < 0 or index >= model.nodes.size():
				continue
			var target_local := hybrid_reference_local_positions[index]
			target_local.x -= front_scale * weight
			if corner >= 2:
				target_local.y -= front_scale * weight * 0.12
				target_local.z *= 1.0 - 0.06 * weight
			else:
				target_local.y += front_scale * weight * 0.018
			var target_world := rigid_chassis.to_global(target_local)
			model.nodes[index].position_m = model.nodes[index].position_m.lerp(target_world, alpha)
			model.nodes[index].velocity_ms = Vector3.ZERO

	_enforce_progressive_failure_shape(alpha)
	_update_safety_cell_collision_shape()
	_update_geometric_crush_measurement()

func _enforce_progressive_failure_shape(alpha: float) -> void:
	if hybrid_firewall_intrusion_m <= 0.0001 and hybrid_cabin_collapse_m <= 0.0001 and hybrid_rear_buckle_m <= 0.0001:
		return
	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := float(preset.get("scale_x", 1.0))
	var scale_z := float(preset.get("scale_z", 1.0))
	var firewall := hybrid_firewall_intrusion_m
	var cabin := hybrid_cabin_collapse_m
	var rear := hybrid_rear_buckle_m

	# Firewall/cowl: both lower and upper safety-front nodes move rearward. Upper
	# nodes additionally drop to represent cowl/A-pillar folding.
	_apply_station_failure(
		CompactHatchbackBuilder.SAFETY_FRONT_STATION,
		firewall * 0.82 + cabin * 0.24,
		firewall * 0.05,
		firewall * 0.16 + cabin * 0.11,
		0.035 * firewall / maxf(0.30 * scale_z, 0.01),
		alpha
	)

	# Mid/rear cabin: progressive shortening plus floor/roof collapse. Width loss
	# is deliberately limited; the major deformation is longitudinal/vertical.
	_apply_station_failure(
		CompactHatchbackBuilder.REAR_AXLE_STATION,
		cabin * 0.20 + rear * 0.10,
		cabin * 0.07,
		cabin * 0.18,
		0.055 * cabin / maxf(0.82 * scale_z, 0.01),
		alpha
	)
	_apply_station_failure(
		CompactHatchbackBuilder.REAR_STATION,
		cabin * 0.08 - rear * 0.46,
		rear * 0.12,
		cabin * 0.08 + rear * 0.22,
		0.10 * rear / maxf(0.55 * scale_z, 0.01),
		alpha
	)

	# Intermediate engine-bay stations bridge the exhausted front zone to the
	# firewall so the nose does not remain as a rigid undeformed visual slab.
	for station in range(CompactHatchbackBuilder.FRONT_STATION - 1, CompactHatchbackBuilder.SAFETY_FRONT_STATION, -1):
		var bridge := float(station - CompactHatchbackBuilder.SAFETY_FRONT_STATION) / float(maxi(CompactHatchbackBuilder.FRONT_STATION - CompactHatchbackBuilder.SAFETY_FRONT_STATION, 1))
		_apply_station_failure(
			station,
			firewall * (0.82 - 0.52 * bridge) + cabin * 0.24 * (1.0 - bridge),
			0.0,
			(firewall * 0.12 + cabin * 0.07) * (1.0 - bridge),
			0.025 * (1.0 - bridge),
			alpha
		)

func _apply_station_failure(
	station: int,
	x_shift_m: float,
	floor_drop_m: float,
	roof_drop_m: float,
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
	# Keep every distance probe on the current structural front face. The public
	# centre-line probe remains the compatibility handle; M19 lateral probes must
	# retreat with it so catastrophic M13 collapse cannot leave stale rays ahead
	# of the authoritative protected-cell collision face.
	rigid_chassis.set_front_crush_probe_mount_x(front_face_x)

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
