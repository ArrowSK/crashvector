# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name TwoVehicleWorld3D
extends Node3D

# Production rigid-body world for any supported pair of movable vehicles.
# It has no UI, replay, or legacy structural-solver ownership; callers can use
# it as the common physical core for both editor roles and export.

var primary_actor: Node3D
var target_actor: Node3D
var scenario: ScenarioConfig
var running := false
var elapsed_s := 0.0
var build_road := true
var _ready_for_simulation := false
var _start_requested := false

func _ready() -> void:
	# Child actors become ready before this node, so their rigid chassis exists
	# here even when configure() was called immediately after add_child().
	_ready_for_simulation = true
	_configure_actor_materials()
	if _start_requested:
		_begin_now()

func configure(config: ScenarioConfig) -> bool:
	if config == null or not ScenarioConfig.is_vehicle_actor_id(config.primary_type) or not ScenarioConfig.is_vehicle_actor_id(config.target_type):
		return false
	scenario = config
	if build_road:
		_build_road()
	primary_actor = VehicleActorFactory.create(
		config.primary_type, config.car_mass_kg, config.car_speed_kmh,
		config.car_position_m, config.car_heading_deg, config.show_structure,
		config.car_preset_id
	)
	target_actor = VehicleActorFactory.create(
		config.target_type, config.target_mass_kg, config.target_speed_kmh,
		config.target_position_m, config.target_heading_deg, config.show_structure,
		config.target_car_preset_id
	)
	if primary_actor == null or target_actor == null:
		return false
	primary_actor.name = "PrimaryVehicleActor"
	target_actor.name = "TargetVehicleActor"
	add_child(primary_actor)
	add_child(target_actor)
	# This world can be configured either before or after it enters the SceneTree.
	# Defer once so actor _ready() has created each chassis in both cases.
	call_deferred("_configure_actor_materials")
	return true

func _configure_actor_materials() -> void:
	_configure_material(VehicleActorRuntime.chassis(primary_actor))
	_configure_material(VehicleActorRuntime.chassis(target_actor))

func begin() -> void:
	if primary_actor == null or target_actor == null:
		return
	_start_requested = true
	if not _ready_for_simulation:
		return
	_begin_now()

func _begin_now() -> void:
	if not _start_requested or primary_actor == null or target_actor == null:
		return
	elapsed_s = 0.0
	running = true
	_start_requested = false
	VehicleActorRuntime.begin(primary_actor)
	VehicleActorRuntime.begin(target_actor)

func set_paused(value: bool) -> void:
	VehicleActorRuntime.set_paused(primary_actor, value)
	VehicleActorRuntime.set_paused(target_actor, value)

func stop() -> void:
	_start_requested = false
	running = false
	VehicleActorRuntime.stop(primary_actor)
	VehicleActorRuntime.stop(target_actor)

func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed_s += delta
	if scenario != null and elapsed_s >= scenario.duration_s:
		stop()

func _build_road() -> void:
	var road := StaticBody3D.new()
	road.name = "Road"
	road.position = Vector3(0.0, -0.25, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4000.0, 0.5, 600.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	road.add_child(collision)
	add_child(road)

func _configure_material(chassis: VehicleRigidChassis) -> void:
	if chassis == null or scenario == null:
		return
	if chassis.physics_material_override == null:
		chassis.physics_material_override = PhysicsMaterial.new()
	chassis.physics_material_override.friction = clampf(scenario.contact_friction, 0.0, 1.0)
	chassis.physics_material_override.bounce = clampf(scenario.restitution, 0.0, 0.04)
