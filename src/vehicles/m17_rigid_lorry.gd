# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M17RigidLorry
extends RigidLorry

# Production world-motion wrapper for the existing generic lorry model. Godot
# owns translation/rotation/contact; the structural graph remains a rigid visual
# reference in this milestone. This is not a validated lorry crashworthiness
# model.

var hybrid_physics_enabled: bool = true
var rigid_chassis: VehicleRigidChassis
var last_chassis_transform := Transform3D.IDENTITY
var chassis_sync_ready := false

func _ready() -> void:
	super._ready()
	_prepare_m17_rigid_model()
	_build_m17_chassis()
	update_from_model()

func _physics_process(delta: float) -> void:
	if model == null or not auto_step:
		return
	step_external(delta)

func step_external(delta: float) -> void:
	if hybrid_physics_enabled and rigid_chassis != null:
		if delta > 0.0:
			_sync_m17_model_to_chassis()
		update_from_model()
		return
	super.step_external(delta)

func begin_simulation() -> void:
	if rigid_chassis == null:
		return
	rigid_chassis.position = origin_offset_m
	rigid_chassis.rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	last_chassis_transform = rigid_chassis.global_transform
	chassis_sync_ready = true
	rigid_chassis.begin_motion(initial_speed_kmh, heading_deg)

func set_simulation_paused(value: bool) -> void:
	if rigid_chassis != null:
		rigid_chassis.set_motion_paused(value)

func end_simulation() -> void:
	if rigid_chassis != null:
		_sync_m17_model_to_chassis()
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
	_apply_m17_rigid_delta(current * previous.affine_inverse())
	last_chassis_transform = current
	chassis_sync_ready = true
	update_from_model()

func global_linear_velocity_ms() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.linear_velocity
	return super.global_linear_velocity_ms()

func global_momentum_kg_ms() -> Vector3:
	if hybrid_physics_enabled and rigid_chassis != null:
		return rigid_chassis.linear_velocity * rigid_chassis.mass
	return model.total_momentum_kg_ms()

func global_kinetic_energy_j() -> float:
	if hybrid_physics_enabled and rigid_chassis != null:
		return 0.5 * rigid_chassis.mass * rigid_chassis.linear_velocity.length_squared()
	return model.total_kinetic_energy_j()

func _prepare_m17_rigid_model() -> void:
	for node in model.nodes:
		node.velocity_ms = Vector3.ZERO
		node.pinned = true
		node.inverse_mass = 0.0
	model.gravity_ms2 = Vector3.ZERO
	model.ground_enabled = false
	model.barrier_enabled = false
	model.capture_initial_energy()

func _build_m17_chassis() -> void:
	rigid_chassis = VehicleRigidChassis.new()
	rigid_chassis.name = "RigidLorryChassis"
	add_child(rigid_chassis)
	rigid_chassis.configure(total_mass_kg, origin_offset_m, heading_deg, initial_speed_kmh, 0.86, 0.0)
	rigid_chassis.add_box_shape("LorryCargoCollision", Vector3(4.70, 2.72, 2.26), Vector3(2.75, 2.00, 0.0))
	rigid_chassis.add_box_shape("LorryCabCollision", Vector3(2.55, 2.45, 2.10), Vector3(6.10, 1.70, 0.0))
	rigid_chassis.add_box_shape("LorryFrameCollision", Vector3(7.35, 0.28, 1.74), Vector3(3.67, 0.58, 0.0))
	rigid_chassis.add_box_shape("LorryRearGuardCollision", Vector3(0.22, 0.60, 2.04), Vector3(0.02, 0.67, 0.0))
	var mass_scale := maxf(total_mass_kg / 12000.0, 0.20)
	var suspension_k := 220000.0 * mass_scale
	var suspension_c := 18000.0 * sqrt(mass_scale)
	var suspension_max := 72000.0 * mass_scale
	for station in [1, 3, RigidLorryBuilder.FRONT_STATION]:
		var x := RigidLorryBuilder.STATION_X[station]
		var z := RigidLorryBuilder.HALF_WIDTH_Z[station]
		rigid_chassis.add_suspension_point("LorrySuspension", Vector3(x, 0.67, -z), 0.77, suspension_k, suspension_c, suspension_max)
		rigid_chassis.add_suspension_point("LorrySuspension", Vector3(x, 0.67, z), 0.77, suspension_k, suspension_c, suspension_max)
	last_chassis_transform = rigid_chassis.global_transform
	chassis_sync_ready = true

func _sync_m17_model_to_chassis() -> void:
	if rigid_chassis == null:
		return
	var current := rigid_chassis.global_transform
	if not chassis_sync_ready:
		last_chassis_transform = current
		chassis_sync_ready = true
		return
	var delta_transform := current * last_chassis_transform.affine_inverse()
	_apply_m17_rigid_delta(delta_transform)
	last_chassis_transform = current

func _apply_m17_rigid_delta(delta_transform: Transform3D) -> void:
	for node in model.nodes:
		node.position_m = delta_transform * node.position_m
		node.velocity_ms = Vector3.ZERO
