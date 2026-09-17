# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name DynamicTank3D
extends Node3D

# A generic tracked vehicle for the same educational scope as the fixed tank
# target. It shares that target's original presentation geometry and collision
# envelope, but owns a normal VehicleRigidChassis so it can be used as a moving
# primary actor without pretending that a StaticBody3D is a vehicle.

var total_mass_kg := 55000.0
var initial_speed_kmh := 0.0
var origin_offset_m := Vector3.ZERO
var heading_deg := 0.0
var rigid_chassis: VehicleRigidChassis
var hybrid_physics_enabled := true

func _ready() -> void:
	_build_chassis()
	_build_shared_presentation()

func _build_chassis() -> void:
	rigid_chassis = VehicleRigidChassis.new()
	rigid_chassis.name = "TankChassis"
	add_child(rigid_chassis)
	rigid_chassis.configure(total_mass_kg, origin_offset_m, heading_deg, initial_speed_kmh, 0.92, 0.0)
	rigid_chassis.add_box_shape("TankLowerHullCollision", Vector3(6.80, 0.58, 2.62), Vector3(0.0, 0.58, 0.0))
	rigid_chassis.add_box_shape("TankUpperHullCollision", Vector3(5.65, 0.64, 2.34), Vector3(-0.18, 1.08, 0.0))
	rigid_chassis.add_box_shape("TankGlacisCollision", Vector3(1.18, 0.48, 2.30), Vector3(2.58, 1.22, 0.0))
	rigid_chassis.add_box_shape("TankTurretCollision", Vector3(2.10, 0.76, 2.10), Vector3(0.32, 1.78, 0.0))
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		rigid_chassis.add_box_shape("TankTrackCollision", Vector3(6.46, 0.82, 0.64), Vector3(0.0, 0.42, side * 1.43))
	var mass_scale := maxf(total_mass_kg / 55000.0, 0.35)
	var suspension_k := 460000.0 * mass_scale
	var suspension_c := 32000.0 * sqrt(mass_scale)
	var suspension_max := 160000.0 * mass_scale
	for x in [-2.20, 0.0, 2.20]:
		for z in [-1.43, 1.43]:
			rigid_chassis.add_suspension_point("TankTrackSupport", Vector3(x, 0.58, z), 0.72, suspension_k, suspension_c, suspension_max)
	rigid_chassis.configure_box_mass_distribution(Vector3(6.80, 1.95, 2.62), Vector3(-0.10, 0.94, 0.0))

func _build_shared_presentation() -> void:
	# StaticObstacle3D already owns the repository's original generic-tank
	# geometry. Move only its render children; collision belongs solely to this
	# dynamic chassis, which prevents duplicate/contradictory physics bodies.
	var template := StaticObstacle3D.new()
	template.configure(ScenarioConfig.TARGET_TANK, Vector3.ZERO, 0.0)
	for child in template.get_children().duplicate():
		if not child is MeshInstance3D:
			continue
		template.remove_child(child)
		rigid_chassis.add_child(child)
	template.queue_free()

func begin_simulation() -> void:
	if rigid_chassis == null:
		return
	rigid_chassis.position = origin_offset_m
	rigid_chassis.rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	rigid_chassis.begin_motion(initial_speed_kmh, heading_deg)

func set_simulation_paused(value: bool) -> void:
	if rigid_chassis != null:
		rigid_chassis.set_motion_paused(value)

func end_simulation() -> void:
	if rigid_chassis != null:
		rigid_chassis.stop_motion()

func set_preview_pose(position_m: Vector3, yaw_deg: float) -> void:
	origin_offset_m = position_m
	heading_deg = yaw_deg
	if rigid_chassis == null:
		return
	rigid_chassis.position = position_m
	rigid_chassis.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)

func global_linear_velocity_ms() -> Vector3:
	return rigid_chassis.linear_velocity if rigid_chassis != null else Vector3.ZERO

func global_momentum_kg_ms() -> Vector3:
	return global_linear_velocity_ms() * total_mass_kg

func global_kinetic_energy_j() -> float:
	return 0.5 * total_mass_kg * global_linear_velocity_ms().length_squared()
