# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M17Motorcycle
extends Motorcycle

# Riderless production world-motion port. The existing generic structural frame
# remains the presentation reference while Godot owns rigid contact/trajectory.
# No rider, steering controller, tyre model or injury inference is implied.

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
	rigid_chassis.name = "RigidMotorcycleChassis"
	add_child(rigid_chassis)
	rigid_chassis.configure(total_mass_kg, origin_offset_m, heading_deg, initial_speed_kmh, 0.82, 0.0)
	rigid_chassis.add_box_shape("MotorcycleFrameCollision", Vector3(1.88, 0.74, 0.46), Vector3(0.98, 0.72, 0.0))
	rigid_chassis.add_sphere_shape("MotorcycleRearWheelCollision", 0.31, Vector3(0.0, 0.34, 0.0))
	rigid_chassis.add_sphere_shape("MotorcycleFrontWheelCollision", 0.31, Vector3(1.95, 0.34, 0.0))
	var mass_scale := maxf(total_mass_kg / 220.0, 0.40)
	var suspension_k := 15500.0 * mass_scale
	var suspension_c := 1800.0 * sqrt(mass_scale)
	var suspension_max := 6500.0 * mass_scale
	# Four narrowly spaced support rays keep the riderless educational proxy
	# numerically stable while still allowing pitch/roll from real contacts.
	for x in [0.0, 1.95]:
		for z in [-0.14, 0.14]:
			rigid_chassis.add_suspension_point("MotorcycleSuspension", Vector3(x, 0.46, z), 0.50, suspension_k, suspension_c, suspension_max)
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
