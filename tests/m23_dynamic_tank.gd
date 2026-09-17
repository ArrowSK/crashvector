# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for actor_type in ScenarioConfig.vehicle_actor_ids():
		var config := ScenarioConfig.new()
		config.apply_primary_vehicle_defaults(actor_type)
		var factory_actor := VehicleActorFactory.create(
			actor_type,
			config.car_mass_kg,
			config.car_speed_kmh,
			config.car_position_m,
			config.car_heading_deg,
			false,
			config.car_preset_id
		)
		_expect(factory_actor != null, "M23 vehicle actor factory did not create %s" % ScenarioConfig.actor_display_name(actor_type))
		if factory_actor != null:
			factory_actor.queue_free()
	var tank := DynamicTank3D.new()
	tank.total_mass_kg = 55000.0
	tank.initial_speed_kmh = 18.0
	tank.origin_offset_m = Vector3(-4.0, 0.0, 0.0)
	root.add_child(tank)
	await process_frame
	_expect(tank.rigid_chassis != null, "M23 dynamic tank did not create a rigid chassis")
	if tank.rigid_chassis != null:
		_expect(absf(tank.rigid_chassis.mass - 55000.0) < 0.01, "M23 dynamic tank lost its configured mass")
		_expect(tank.rigid_chassis.get_node_or_null("TankLowerHullCollision") != null, "M23 dynamic tank is missing its lower-hull collision")
		_expect(tank.rigid_chassis.get_node_or_null("TankTurretCollision") != null, "M23 dynamic tank is missing its turret collision")
		_expect(tank.rigid_chassis.get_node_or_null("TankTrackCollision") != null, "M23 dynamic tank is missing its track collision")
		_expect(tank.rigid_chassis.get_node_or_null("TankHull") != null, "M23 dynamic tank did not reuse the tank hull presentation")
		_expect(tank.rigid_chassis.get_node_or_null("TankMainGun") != null, "M23 dynamic tank did not reuse the tank gun presentation")
		_expect(VehicleActorRuntime.chassis(tank) == tank.rigid_chassis, "M23 actor runtime did not resolve the tank chassis")
		tank.begin_simulation()
		await physics_frame
		_expect(tank.rigid_chassis.linear_velocity.length() > 4.0, "M23 dynamic tank did not begin moving from its configured speed")
		_expect(VehicleActorRuntime.linear_velocity_ms(tank).length() > 4.0, "M23 actor runtime did not report tank speed")
		tank.set_simulation_paused(true)
		_expect(tank.rigid_chassis.freeze, "M23 dynamic tank did not pause its rigid chassis")
		tank.set_simulation_paused(false)
		_expect(not tank.rigid_chassis.freeze, "M23 dynamic tank did not resume its rigid chassis")
	tank.queue_free()
	await process_frame
	await _check_two_vehicle_world()
	await _check_vehicle_fixture_world()
	await _check_editor_reciprocal_vehicle_pair()
	_finish()

func _check_two_vehicle_world() -> void:
	var config := ScenarioConfig.new()
	config.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_TRUCK)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_speed_kmh = 20.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TANK)
	config.target_position_m = Vector3(6.0, 0.0, 0.0)
	config.target_speed_kmh = 0.0
	config.duration_s = 0.6
	_expect(config.validation_errors().is_empty(), "M23 truck-versus-tank scenario failed preflight")
	var world := TwoVehicleWorld3D.new()
	root.add_child(world)
	_expect(world.configure(config), "M23 two-vehicle world did not configure truck versus tank")
	await process_frame
	_expect(world.primary_actor is M21HeavyTruck, "M23 two-vehicle world did not create an articulated truck primary")
	_expect(world.target_actor is DynamicTank3D, "M23 two-vehicle world did not create a dynamic tank target")
	var primary_chassis := VehicleActorRuntime.chassis(world.primary_actor)
	var target_chassis := VehicleActorRuntime.chassis(world.target_actor)
	_expect(primary_chassis != null and primary_chassis.physics_material_override != null, "M23 primary vehicle did not receive the configured contact material")
	_expect(target_chassis != null and target_chassis.physics_material_override != null, "M23 target vehicle did not receive the configured contact material")
	world.begin()
	for _frame in range(50):
		await physics_frame
	_expect(world.elapsed_s > 0.0, "M23 two-vehicle world did not advance")
	var primary_model := (world.primary_actor as M21HeavyTruck).model if world.primary_actor is M21HeavyTruck else null
	_expect(primary_model != null and primary_model.center_of_mass_m().x > -7.8, "M23 shared world did not synchronize the moving truck model")
	world.stop()
	world.queue_free()
	await process_frame

func _check_vehicle_fixture_world() -> void:
	var config := ScenarioConfig.new()
	config.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_LORRY)
	config.car_position_m = Vector3(-7.0, 0.0, 0.0)
	config.car_speed_kmh = 18.0
	config.apply_target_defaults(ScenarioConfig.TARGET_WALL)
	config.target_position_m = Vector3(5.0, 0.0, 0.0)
	config.duration_s = 0.6
	_expect(config.validation_errors().is_empty(), "M23 lorry-versus-wall scenario failed preflight")
	var world := TwoVehicleWorld3D.new()
	root.add_child(world)
	_expect(world.configure(config), "M23 vehicle world did not configure lorry versus wall")
	await process_frame
	_expect(world.primary_actor is M20RigidLorry, "M23 vehicle world did not create lorry primary")
	_expect(world.target_actor is StaticObstacle3D, "M23 vehicle world did not create static wall target")
	var fixture := world.target_actor as StaticObstacle3D
	_expect(fixture != null and fixture.physics_body != null and fixture.physics_body.physics_material_override != null, "M23 fixture target did not receive configured contact material")
	world.begin()
	for _frame in range(12):
		await physics_frame
	_expect(world.running and VehicleActorRuntime.linear_velocity_ms(world.primary_actor).length() > 4.0, "M23 lorry-versus-wall world did not start the primary actor")
	world.stop()
	world.queue_free()
	await process_frame

func _check_editor_reciprocal_vehicle_pair() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M23 production editor scene did not load")
	if packed == null:
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M23 truck primary versus passenger car"
	config.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_TRUCK)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_speed_kmh = 20.0
	config.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	config.target_position_m = Vector3(6.0, 0.0, 0.0)
	config.target_speed_kmh = 0.0
	config.duration_s = 0.8
	_expect(config.validation_errors().is_empty(), "M23 reciprocal editor scenario failed preflight")
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(6):
		await process_frame
	var world := editor.get("m23_vehicle_world") as TwoVehicleWorld3D
	_expect(world != null, "M23 editor did not route a truck primary through TwoVehicleWorld3D")
	if world != null:
		_expect(world.primary_actor is M21HeavyTruck, "M23 editor did not create the truck as the primary actor")
		_expect(world.target_actor is M162CompactHatchback, "M23 editor did not create the passenger car as the target actor")
	editor.call("_on_simulate_pressed")
	for _frame in range(12):
		await physics_frame
	world = editor.get("m23_vehicle_world") as TwoVehicleWorld3D
	_expect(world != null and world.running, "M23 reciprocal editor run did not start the shared vehicle world")
	if world != null:
		_expect(VehicleActorRuntime.linear_velocity_ms(world.primary_actor).length() > 4.0, "M23 reciprocal editor primary truck did not move from configured speed")
	editor.call("_on_reset_pressed")
	editor.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("CrashVector M23 dynamic-tank actor regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
