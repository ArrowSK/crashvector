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
	_finish()

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
