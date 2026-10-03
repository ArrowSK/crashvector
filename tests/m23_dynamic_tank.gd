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
	await _check_dynamic_tank_road_support()
	_check_rigidbody_contact_settings()
	await _check_two_vehicle_world()
	await _check_tank_primary_role()
	await _check_articulated_target_materials()
	await _check_vehicle_fixture_world()
	await _check_motorcycle_rider_replay()
	_check_role_neutral_analysis()
	await _check_editor_reciprocal_vehicle_pair()
	_finish()

func _check_dynamic_tank_road_support() -> void:
	# The suspension must carry the tank before its rigid track collision boxes
	# reach the flat road. Otherwise the same road load is resolved once by the
	# ray springs and again by Godot's rigid contact solver.
	for supported_mass_value in [20000.0, 55000.0, 80000.0]:
		var supported_mass: float = float(supported_mass_value)
		var mass_scale: float = maxf(supported_mass / 55000.0, 0.35)
		var stiffness_per_support: float = DynamicTank3D.TRACK_SUPPORT_STIFFNESS_N_M * mass_scale
		var static_compression: float = supported_mass * 9.80665 / (6.0 * stiffness_per_support)
		var equilibrium_body_y: float = (
			DynamicTank3D.TRACK_SUPPORT_REST_DISTANCE_M
			- static_compression
			- DynamicTank3D.TRACK_SUPPORT_MOUNT_Y_M
		)
		var equilibrium_track_clearance: float = (
			equilibrium_body_y
			+ DynamicTank3D.TRACK_COLLISION_CENTER_Y_M
			- DynamicTank3D.TRACK_COLLISION_SIZE.y * 0.5
		)
		_expect(
			equilibrium_track_clearance > 0.01,
			"M23 dynamic tank %.0f kg neutral suspension would settle onto the rigid track/road collision: %.4f m clearance" % [supported_mass, equilibrium_track_clearance]
		)

	var road := StaticBody3D.new()
	road.name = "Road"
	road.position = Vector3(0.0, -0.25, 0.0)
	var road_material := PhysicsMaterial.new()
	road_material.friction = 0.90
	road_material.bounce = 0.0
	road.physics_material_override = road_material
	var road_shape := BoxShape3D.new()
	road_shape.size = Vector3(120.0, 0.5, 20.0)
	var road_collision := CollisionShape3D.new()
	road_collision.shape = road_shape
	road.add_child(road_collision)
	root.add_child(road)

	var tank := DynamicTank3D.new()
	tank.total_mass_kg = 55000.0
	tank.initial_speed_kmh = 36.0
	tank.origin_offset_m = Vector3(-20.0, 0.0, 0.0)
	tank.heading_deg = 0.0
	root.add_child(tank)
	await process_frame
	_expect(tank.rigid_chassis != null, "M23 dynamic-tank road-support regression could not build the rigid chassis")
	if tank.rigid_chassis == null:
		tank.queue_free()
		road.queue_free()
		await process_frame
		return

	_expect(tank.rigid_chassis.suspension_points.size() == 6, "M23 dynamic tank no longer has six independent track-support rays")
	tank.begin_simulation()
	var rigid_ground_contacts := 0
	var minimum_settled_support_contacts := 6
	var maximum_roll_deg := 0.0
	var maximum_pitch_deg := 0.0
	var maximum_height_excursion_m := 0.0
	var initial_y := tank.rigid_chassis.global_position.y
	for frame in range(360):
		await physics_frame
		maximum_height_excursion_m = maxf(maximum_height_excursion_m, absf(tank.rigid_chassis.global_position.y - initial_y))
		maximum_roll_deg = maxf(maximum_roll_deg, absf(rad_to_deg(tank.rigid_chassis.rotation.z)))
		maximum_pitch_deg = maxf(maximum_pitch_deg, absf(rad_to_deg(tank.rigid_chassis.rotation.x)))
		if frame >= 60:
			minimum_settled_support_contacts = mini(minimum_settled_support_contacts, tank.rigid_chassis.active_suspension_contacts)
		for sample in tank.rigid_chassis.contact_samples:
			if StringName(sample.get("collider_name", StringName(""))) == &"Road":
				rigid_ground_contacts += 1

	_expect(rigid_ground_contacts == 0, "M23 dynamic tank rigid tracks still share flat-road support with the suspension rays")
	_expect(minimum_settled_support_contacts >= 4, "M23 dynamic tank loses too many suspension contacts on a flat road: minimum %d" % minimum_settled_support_contacts)
	_expect(tank.rigid_chassis.maximum_suspension_compression_m > 0.08, "M23 dynamic tank suspension did not carry measurable road load")
	_expect(tank.rigid_chassis.maximum_suspension_compression_m < 0.22, "M23 dynamic tank suspension compressed far enough to threaten rigid track/road support")
	_expect(tank.rigid_chassis.maximum_vertical_speed_ms < 0.50, "M23 dynamic tank flat-road support produced excessive vertical speed: %.3f m/s" % tank.rigid_chassis.maximum_vertical_speed_ms)
	_expect(maximum_height_excursion_m < 0.08, "M23 dynamic tank flat-road support oscillated excessively in height: %.3f m" % maximum_height_excursion_m)
	_expect(maximum_roll_deg < 2.0, "M23 dynamic tank developed excessive roll on a flat road: %.2f deg" % maximum_roll_deg)
	_expect(maximum_pitch_deg < 2.0, "M23 dynamic tank developed excessive pitch on a flat road: %.2f deg" % maximum_pitch_deg)
	_expect(tank.rigid_chassis.non_ground_contact_events == 0, "M23 dynamic tank generated non-ground contacts while travelling alone on the road")

	tank.end_simulation()
	tank.queue_free()
	road.queue_free()
	await process_frame

func _check_rigidbody_contact_settings() -> void:
	var config := ScenarioConfig.new()
	config.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_LORRY)
	config.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.target_position_m = Vector3(6.0, 0.0, 0.0)
	_expect(TwoVehicleWorld3D.contact_setting_errors(config).is_empty(), "M23 rigid-body contact preflight rejected the production defaults")
	config.contact_friction = TwoVehicleWorld3D.MAX_CONTACT_FRICTION + 0.01
	_expect(not TwoVehicleWorld3D.contact_setting_errors(config).is_empty(), "M23 rigid-body contact preflight accepted friction that the world cannot represent")
	var rejected_friction_world := TwoVehicleWorld3D.new()
	_expect(not rejected_friction_world.configure(config), "M23 rigid-body world silently accepted out-of-range friction")
	config.contact_friction = 0.55
	config.restitution = TwoVehicleWorld3D.MAX_CONTACT_RESTITUTION + 0.01
	_expect(not TwoVehicleWorld3D.contact_setting_errors(config).is_empty(), "M23 rigid-body contact preflight accepted restitution outside the production bound")
	var rejected_restitution_world := TwoVehicleWorld3D.new()
	_expect(not rejected_restitution_world.configure(config), "M23 rigid-body world silently accepted out-of-range restitution")

func _check_two_vehicle_world() -> void:
	var config := ScenarioConfig.new()
	config.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_TRUCK)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_speed_kmh = 20.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TANK)
	config.target_position_m = Vector3(6.0, 0.0, 0.0)
	config.target_speed_kmh = 0.0
	config.contact_friction = 0.41
	config.restitution = 0.02
	config.duration_s = 0.6
	_expect(config.validation_errors().is_empty(), "M23 truck-versus-tank scenario failed preflight")
	var world := TwoVehicleWorld3D.new()
	root.add_child(world)
	_expect(world.configure(config), "M23 two-vehicle world did not configure truck versus tank")
	await process_frame
	_expect(world.primary_actor is M21HeavyTruck, "M23 two-vehicle world did not create an articulated truck primary")
	_expect(world.target_actor is StaticObstacle3D, "M23 tank target did not preserve the fixed-target scenario contract")
	var primary_chassis := VehicleActorRuntime.chassis(world.primary_actor)
	_expect(primary_chassis != null and primary_chassis.physics_material_override != null, "M23 primary vehicle did not receive the configured contact material")
	var tank_fixture := world.target_actor as StaticObstacle3D
	_expect(tank_fixture != null and tank_fixture.obstacle_type == ScenarioConfig.TARGET_TANK, "M23 tank target was not configured as the generic fixed tank obstacle")
	_expect(tank_fixture != null and tank_fixture.physics_body is StaticBody3D, "M23 tank target unexpectedly owns a movable rigid body")
	if tank_fixture != null and tank_fixture.physics_body != null:
		_expect(tank_fixture.physics_body.physics_material_override != null, "M23 fixed tank target did not receive the configured contact material")
		if tank_fixture.physics_body.physics_material_override != null:
			_expect(absf(tank_fixture.physics_body.physics_material_override.friction - config.contact_friction) < 0.000001, "M23 fixed tank target did not retain scenario friction")
			_expect(absf(tank_fixture.physics_body.physics_material_override.bounce - config.restitution) < 0.000001, "M23 fixed tank target did not retain scenario restitution")
	var primary_bodies := VehicleActorRuntime.physics_bodies(world.primary_actor)
	_expect(primary_bodies.size() == 2, "M23 actor runtime did not expose both articulated-truck physics bodies")
	for body in primary_bodies:
		_expect(body.physics_material_override != null, "M23 articulated-truck body did not receive the configured contact material")
		if body.physics_material_override != null:
			_expect(absf(body.physics_material_override.friction - config.contact_friction) < 0.000001, "M23 articulated-truck body kept a hard-coded friction value")
			_expect(absf(body.physics_material_override.bounce - config.restitution) < 0.000001, "M23 articulated-truck body kept a hard-coded restitution value")
	world.begin()
	for _frame in range(50):
		await physics_frame
	_expect(world.elapsed_s > 0.0, "M23 two-vehicle world did not advance")
	var primary_model := (world.primary_actor as M21HeavyTruck).model if world.primary_actor is M21HeavyTruck else null
	_expect(primary_model != null and primary_model.center_of_mass_m().x > -7.8, "M23 shared world did not synchronize the moving truck model")
	world.stop()
	world.queue_free()
	await process_frame

func _check_tank_primary_role() -> void:
	_expect(not ScenarioConfig.target_is_dynamic_id(ScenarioConfig.TARGET_TANK), "M23 scenario contract no longer identifies tank targets as fixed")
	var fixed_target_config := ScenarioConfig.new()
	fixed_target_config.apply_target_defaults(ScenarioConfig.TARGET_TANK)
	fixed_target_config.target_speed_kmh = 1.0
	var fixed_target_errors := fixed_target_config.validation_errors()
	var rejected_moving_target := false
	for error in fixed_target_errors:
		if error.contains("tank target is fixed"):
			rejected_moving_target = true
			break
	_expect(rejected_moving_target, "M23 scenario contract accepted a moving tank in the fixed target role")

	var config := ScenarioConfig.new()
	config.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_TANK)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_speed_kmh = 18.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	config.target_position_m = Vector3(6.0, 0.0, 0.0)
	config.target_speed_kmh = 0.0
	config.duration_s = 0.6
	_expect(config.validation_errors().is_empty(), "M23 tank-primary scenario failed preflight")
	var world := TwoVehicleWorld3D.new()
	root.add_child(world)
	_expect(world.configure(config), "M23 two-vehicle world did not configure a movable tank primary")
	await process_frame
	_expect(world.primary_actor is DynamicTank3D, "M23 tank primary did not create the movable DynamicTank3D actor")
	_expect(world.target_actor is M21HeavyTruck, "M23 tank-primary scenario did not create the truck as a movable target")
	var tank_body := VehicleActorRuntime.chassis(world.primary_actor)
	_expect(tank_body != null and tank_body is RigidBody3D, "M23 movable tank primary is missing its authoritative rigid body")
	world.begin()
	for _frame in range(12):
		await physics_frame
	_expect(VehicleActorRuntime.linear_velocity_ms(world.primary_actor).length() > 4.0, "M23 movable tank primary did not begin from its configured speed")
	world.stop()
	world.queue_free()
	await process_frame

func _check_articulated_target_materials() -> void:
	var config := ScenarioConfig.new()
	config.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_LORRY)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_speed_kmh = 12.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	config.target_position_m = Vector3(6.0, 0.0, 0.0)
	config.target_speed_kmh = 0.0
	config.contact_friction = 0.37
	config.restitution = 0.01
	_expect(config.validation_errors().is_empty(), "M23 lorry-versus-truck material scenario failed preflight")
	var world := TwoVehicleWorld3D.new()
	root.add_child(world)
	_expect(world.configure(config), "M23 two-vehicle world did not configure articulated truck as target")
	await process_frame
	var target_bodies := VehicleActorRuntime.physics_bodies(world.target_actor)
	_expect(target_bodies.size() == 2, "M23 actor runtime did not expose both physics bodies when the articulated truck was the target")
	var articulated_target := world.target_actor as M21HeavyTruck
	_expect(articulated_target != null, "M23 articulated inertia regression did not create M21HeavyTruck")
	if articulated_target != null and articulated_target.rigid_chassis != null and articulated_target.tractor_chassis != null:
		_expect(articulated_target.rigid_chassis.configured_mass_distribution_size_m.distance_to(M21HeavyTruck.TRAILER_NEUTRAL_MASS_DISTRIBUTION_SIZE) < 0.000001, "M21 trailer retained one-piece/automatic inertia instead of its split neutral mass envelope")
		_expect(articulated_target.tractor_chassis.configured_mass_distribution_size_m.distance_to(M21HeavyTruck.TRACTOR_NEUTRAL_MASS_DISTRIBUTION_SIZE) < 0.000001, "M21 tractor did not receive its split neutral mass envelope")
		_expect(articulated_target.rigid_chassis.configured_center_of_mass_local_m.distance_to(M21HeavyTruck.TRAILER_NEUTRAL_CENTER_OF_MASS_LOCAL) < 0.000001, "M21 trailer neutral centre of mass is not configured")
		_expect(articulated_target.tractor_chassis.configured_center_of_mass_local_m.distance_to(M21HeavyTruck.TRACTOR_NEUTRAL_CENTER_OF_MASS_LOCAL) < 0.000001, "M21 tractor neutral centre of mass is not configured")
		var trailer_inertia := articulated_target.rigid_chassis.inertia
		var tractor_inertia := articulated_target.tractor_chassis.inertia
		articulated_target.hybrid_rear_crush_m = 0.48
		articulated_target.hybrid_front_crush_m = 0.38
		articulated_target.hybrid_side_negative_z_crush_m = 0.26
		articulated_target.hybrid_side_positive_z_crush_m = 0.14
		articulated_target.call("_m21_update_longitudinal_collision_shapes")
		articulated_target.call("_m20_update_side_collision_shapes")
		_expect(articulated_target.rigid_chassis.inertia.distance_to(trailer_inertia) < 0.000001, "M21 trailer inertia changed when its deformable shells were resized")
		_expect(articulated_target.tractor_chassis.inertia.distance_to(tractor_inertia) < 0.000001, "M21 tractor inertia changed when its deformable shells were resized")
	for body in target_bodies:
		_expect(body.physics_material_override != null, "M23 articulated target body did not receive the configured contact material")
		if body.physics_material_override != null:
			_expect(absf(body.physics_material_override.friction - config.contact_friction) < 0.000001, "M23 articulated target body kept a hard-coded friction value")
			_expect(absf(body.physics_material_override.bounce - config.restitution) < 0.000001, "M23 articulated target body kept a hard-coded restitution value")
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

func _check_motorcycle_rider_replay() -> void:
	var actor := VehicleActorFactory.create(
		ScenarioConfig.TARGET_MOTORCYCLE,
		220.0,
		30.0,
		Vector3(-3.0, 0.0, 1.0),
		25.0,
		false
	) as M20Motorcycle
	_expect(actor != null, "M23 motorcycle rider replay regression could not create the production motorcycle")
	if actor == null:
		return
	root.add_child(actor)
	await process_frame
	_expect(actor.rider_rig != null and actor.rider_rig.rider_body_count() == 2, "M23 motorcycle replay regression is missing the two-body rider rig")
	if actor.rider_rig == null:
		actor.queue_free()
		await process_frame
		return

	var attached_torso_transform := actor.rider_rig.torso.global_transform
	var attached_head_transform := actor.rider_rig.head.global_transform
	var attached_state := actor.replay_visual_state()
	var attached_rider_value: Variant = attached_state.get("rider_state", {})
	_expect(attached_rider_value is Dictionary and not bool((attached_rider_value as Dictionary).get("rider_released", true)), "M23 motorcycle replay did not capture the attached rider state")

	actor.rider_rig.arm_for_simulation()
	actor.rider_rig.release_from_real_contact()
	var torso_transform := actor.rider_rig.torso.global_transform
	torso_transform.origin += Vector3(1.25, 0.70, -0.45)
	torso_transform.basis = torso_transform.basis.rotated(Vector3.UP, deg_to_rad(18.0))
	actor.rider_rig.torso.global_transform = torso_transform
	actor.rider_rig.torso.linear_velocity = Vector3(6.0, 2.5, -1.2)
	actor.rider_rig.torso.angular_velocity = Vector3(0.4, -0.8, 1.1)
	var head_transform := actor.rider_rig.head.global_transform
	head_transform.origin += Vector3(1.55, 0.95, -0.25)
	head_transform.basis = head_transform.basis.rotated(Vector3.RIGHT, deg_to_rad(-11.0))
	actor.rider_rig.head.global_transform = head_transform
	actor.rider_rig.head.linear_velocity = Vector3(6.4, 2.9, -0.8)
	actor.rider_rig.head.angular_velocity = Vector3(-0.3, 0.6, 1.4)

	var released_state := actor.replay_visual_state()
	var rider_value: Variant = released_state.get("rider_state", {})
	_expect(rider_value is Dictionary, "M23 motorcycle replay omitted rider state after release")
	if rider_value is Dictionary:
		var rider_state: Dictionary = rider_value
		_expect(bool(rider_state.get("rider_released", false)), "M23 motorcycle replay dropped the rider-release flag")
		var parts_value: Variant = rider_state.get("part_states", [])
		_expect(parts_value is Array and (parts_value as Array).size() == 2, "M23 motorcycle replay did not serialize both rider rigid bodies")

	var recorder := ReplayRecorder.new()
	recorder.begin()
	_expect(
		recorder.capture(0.0, actor.model, null, {}, {}, {}, released_state, {}, true),
		"M23 replay recorder rejected the motorcycle rider visual state"
	)
	var recorded_state: Dictionary = recorder.recording.first_frame().get("primary_visual_state", {})
	actor.apply_replay_visual_state(attached_state)
	_expect(not actor.rider_rig.rider_released, "M23 motorcycle replay could not restore the pre-release rider state")
	_expect(actor.rider_rig.torso.freeze and actor.rider_rig.head.freeze, "M23 motorcycle replay left attached rider bodies live during timeline playback")
	_expect(actor.rider_rig.torso.global_transform.origin.distance_to(attached_torso_transform.origin) < 0.000001, "M23 motorcycle replay lost the attached torso pose")
	_expect(actor.rider_rig.head.global_transform.origin.distance_to(attached_head_transform.origin) < 0.000001, "M23 motorcycle replay lost the attached head pose")
	actor.apply_replay_visual_state(recorded_state)
	_expect(actor.rider_rig.rider_released, "M23 motorcycle replay reattached the released rider")
	_expect(actor.rider_rig.torso.freeze and actor.rider_rig.head.freeze, "M23 motorcycle replay left released rider bodies live during timeline playback")
	_expect(actor.rider_rig.torso.global_transform.origin.distance_to(torso_transform.origin) < 0.000001, "M23 motorcycle replay lost the released torso position")
	_expect(actor.rider_rig.head.global_transform.origin.distance_to(head_transform.origin) < 0.000001, "M23 motorcycle replay lost the released head position")
	_expect(actor.rider_rig.torso.global_transform.basis.x.distance_to(torso_transform.basis.x) < 0.000001, "M23 motorcycle replay lost the released torso orientation")
	_expect(actor.rider_rig.head.global_transform.basis.y.distance_to(head_transform.basis.y) < 0.000001, "M23 motorcycle replay lost the released head orientation")
	_expect(actor.rider_rig.torso.linear_velocity.distance_to(Vector3(6.0, 2.5, -1.2)) < 0.000001, "M23 motorcycle replay lost the released torso velocity")
	_expect(actor.rider_rig.head.linear_velocity.distance_to(Vector3(6.4, 2.9, -0.8)) < 0.000001, "M23 motorcycle replay lost the released head velocity")
	_expect(actor.rider_rig.torso.angular_velocity.distance_to(Vector3(0.4, -0.8, 1.1)) < 0.000001, "M23 motorcycle replay lost the released torso angular velocity")
	_expect(actor.rider_rig.head.angular_velocity.distance_to(Vector3(-0.3, 0.6, 1.4)) < 0.000001, "M23 motorcycle replay lost the released head angular velocity")

	actor.queue_free()
	await process_frame

func _check_role_neutral_analysis() -> void:
	var recording := ReplayRecording.new()
	recording.sample_interval_s = 0.10
	recording.add_frame({
		"time_s": 0.0,
		"primary_metrics": {
			"linear_velocity_ms": Vector3.ZERO,
			"speed_kmh": 0.0,
			"kinetic_energy_j": 0.0,
			"side_crush_m": 0.02,
			"broken_beams": 0,
		},
		"target_metrics": {
			"linear_velocity_ms": Vector3(0.0, 0.0, -8.0),
			"speed_kmh": 28.8,
			"rear_crush_m": 0.01,
			"broken_beams": 0,
		},
		"context": {"contact_count": 0},
	})
	recording.add_frame({
		"time_s": 0.10,
		"primary_metrics": {
			"linear_velocity_ms": Vector3(0.0, 0.0, 2.0),
			"speed_kmh": 7.2,
			"kinetic_energy_j": 2200.0,
			"side_crush_m": 0.10,
			"broken_beams": 0,
		},
		"target_metrics": {
			"linear_velocity_ms": Vector3(0.0, 0.0, -5.0),
			"speed_kmh": 18.0,
			"rear_crush_m": 0.04,
			"broken_beams": 0,
		},
		"context": {"contact_count": 1},
	})
	recording.add_frame({
		"time_s": 0.20,
		"primary_metrics": {
			"linear_velocity_ms": Vector3(0.0, 0.0, 4.0),
			"speed_kmh": 14.4,
			"kinetic_energy_j": 8800.0,
			"side_crush_m": 0.20,
			"broken_beams": 0,
		},
		"target_metrics": {
			"linear_velocity_ms": Vector3(0.0, 0.0, -2.0),
			"speed_kmh": 7.2,
			"rear_crush_m": 0.08,
			"broken_beams": 0,
		},
		"context": {"contact_count": 2},
	})
	var analysis := CrashAnalysis.analyze(recording)
	_expect(not bool(analysis.get("primary_initial_motion_direction_valid", true)), "Role-neutral analysis invented an initial direction for a stationary primary")
	_expect(absf(float(analysis.get("peak_deceleration_g", -1.0))) < 0.000001, "Stationary-primary analysis still reports artificial longitudinal deceleration")
	_expect(float(analysis.get("peak_acceleration_g", 0.0)) > 0.0, "Stationary-primary analysis dropped the real post-contact acceleration")
	_expect(absf(float(analysis.get("primary_max_reported_deformation_mm", 0.0)) - 200.0) < 0.000001, "Role-neutral analysis did not summarize primary side deformation")
	_expect(absf(float(analysis.get("target_max_reported_deformation_mm", 0.0)) - 80.0) < 0.000001, "Role-neutral analysis did not summarize target rear deformation")
	var primary_components_value: Variant = analysis.get("primary_deformation_components_mm", {})
	_expect(primary_components_value is Dictionary and absf(float((primary_components_value as Dictionary).get("side_crush_m", 0.0)) - 200.0) < 0.000001, "Role-neutral analysis lost the primary deformation component")
	_expect(recording.marker_time(&"peak_loading") >= 0.0, "Stationary-primary analysis did not create a peak-loading marker from acceleration magnitude")
	var result_stage := CinematicRenderStage.new()
	var result_scenario := ScenarioConfig.new()
	result_scenario.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_LORRY)
	result_scenario.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	result_stage.scenario = result_scenario
	result_stage.analysis = analysis
	var result_text := String(result_stage.call("_result_text"))
	_expect(result_text.contains("Maximum reported vehicle deformation"), "M23 cinematic result card did not switch to role-neutral deformation terminology")
	_expect(result_text.contains("peak simulated acceleration"), "M23 cinematic result card still labels a stationary primary as longitudinal deceleration")
	_expect(not result_text.contains("front crush") and not result_text.contains("safety-cell"), "M23 cinematic result card still uses passenger-car-only deformation labels")
	result_stage.free()

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
	var friction_control := editor.get("m10_friction") as SpinBox
	var restitution_control := editor.get("m10_restitution") as SpinBox
	var substeps_control := editor.get("m10_substeps") as SpinBox
	_expect(friction_control != null and absf(friction_control.max_value - TwoVehicleWorld3D.MAX_CONTACT_FRICTION) < 0.000001, "M23 Physics tab still exposes friction above the rigid-body limit")
	_expect(restitution_control != null and absf(restitution_control.max_value - TwoVehicleWorld3D.MAX_CONTACT_RESTITUTION) < 0.000001, "M23 Physics tab still exposes restitution above the rigid-body production bound")
	_expect(substeps_control != null and not substeps_control.editable, "M23 editor still presents solver substeps as an active RigidBody3D control")
	if substeps_control != null:
		_expect(int(substeps_control.value) == config.solver_substeps, "M23 editor changed the persisted structural-solver substep value while disabling it")
	var physics_warning := editor.call("_m23_physics_scope_label") as Label
	var substep_scope_explained := (
		physics_warning != null and physics_warning.text.contains("do not affect this path")
	) or (
		substeps_control != null and substeps_control.tooltip_text.contains("does not use the legacy structural-solver substep setting")
	)
	_expect(substep_scope_explained, "M23 Physics tab does not explain that solver substeps are unused by RigidBody3D")
	var primary_class_control := editor.get("m10_primary_class") as OptionButton
	var primary_paint_control := editor.get("m10_primary_paint") as OptionButton
	var export_primary_paint_control := editor.get("primary_paint_option") as OptionButton
	_expect(primary_class_control != null and primary_class_control.get_parent() != null and not primary_class_control.get_parent().visible, "M23 truck primary still exposes the passenger-car class control")
	_expect(primary_paint_control != null and primary_paint_control.get_parent() != null and not primary_paint_control.get_parent().visible, "M23 truck primary still exposes the passenger-car paint control")
	_expect(export_primary_paint_control != null and export_primary_paint_control.get_parent() != null and not export_primary_paint_control.get_parent().visible, "M23 export settings still expose primary-car paint for a truck primary")
	var compare_mode_control := editor.get("m10_compare_mode") as OptionButton
	var compare_class_index := -1
	if compare_mode_control != null:
		for option_index in range(compare_mode_control.item_count):
			if StringName(String(compare_mode_control.get_item_metadata(option_index))) == &"vehicle_class":
				compare_class_index = option_index
				break
	_expect(compare_mode_control != null and compare_class_index >= 0 and compare_mode_control.is_item_disabled(compare_class_index), "M23 truck primary still enables passenger B/C/D class comparison")
	if world != null and world.primary_actor != null:
		editor.set("selected_object", &"car")
		editor.call("_update_selection_ring")
		var selection_ring := editor.get("m10_selection_ring") as MeshInstance3D
		var primary_bounds := VehicleActorRuntime.collision_footprint_bounds(world.primary_actor)
		_expect(selection_ring != null and not primary_bounds.is_empty(), "M23 geometry-aware primary selection regression could not resolve ring or actor bounds")
		if selection_ring != null and not primary_bounds.is_empty():
			var min_x := float(primary_bounds["min_x"])
			var max_x := float(primary_bounds["max_x"])
			var min_z := float(primary_bounds["min_z"])
			var max_z := float(primary_bounds["max_z"])
			var expected_center := Vector3((min_x + max_x) * 0.5, 0.035, (min_z + max_z) * 0.5)
			var span_x := max_x - min_x
			var span_z := max_z - min_z
			var expected_radius := maxf(0.75, 0.5 * sqrt(span_x * span_x + span_z * span_z) + 0.20)
			_expect(selection_ring.position.distance_to(expected_center) < 0.000001, "M23 primary selection ring is still centred on the truck origin instead of its collision footprint")
			_expect(absf(selection_ring.scale.x * 1.8 - expected_radius) < 0.000001, "M23 primary selection ring still uses passenger-car sizing for the articulated truck")
			_expect(selection_ring.position.distance_to(Vector3(config.car_position_m.x, 0.035, config.car_position_m.z)) > 1.0, "M23 articulated-truck selection ring did not account for the asymmetric actor origin")
	var target_option := editor.get("m10_target_option") as OptionButton
	_expect(target_option != null, "M23 capability regression could not find the target selector")
	if target_option != null:
		for target_id in ScenarioConfig.target_ids():
			var target_index := -1
			for option_index in range(target_option.item_count):
				if StringName(String(target_option.get_item_metadata(option_index))) == target_id:
					target_index = option_index
					break
			_expect(target_index >= 0, "M23 target selector omitted %s" % ScenarioConfig.target_display_name(target_id))
			if target_index >= 0:
				var expected_supported := TwoVehicleWorld3D.supports_target(target_id)
				_expect(
					target_option.is_item_disabled(target_index) == not expected_supported,
					"M23 target selector capability disagrees with the production world for %s" % ScenarioConfig.target_display_name(target_id)
				)
	var quick_target_buttons := 0
	var quick_pedestrian_disabled := false
	var quick_bicycle_disabled := false
	var quick_wall_enabled := false
	var quick_target_value: Variant = editor.call("_m23_quick_target_button_nodes")
	_expect(typeof(quick_target_value) == TYPE_ARRAY, "M23 quick-target resolver did not return an array")
	if typeof(quick_target_value) == TYPE_ARRAY:
		var resolved_quick_targets: Array = quick_target_value
		for target_value in resolved_quick_targets:
			var button := target_value as Button
			if button == null:
				continue
			var target_id: StringName = editor.call("_m23_quick_target_id", button)
			if target_id.is_empty():
				continue
			quick_target_buttons += 1
			if target_id == ScenarioConfig.TARGET_PEDESTRIAN:
				quick_pedestrian_disabled = button.disabled
			elif target_id == ScenarioConfig.TARGET_BICYCLE:
				quick_bicycle_disabled = button.disabled
			elif target_id == ScenarioConfig.TARGET_WALL:
				quick_wall_enabled = not button.disabled
	_expect(quick_target_buttons >= 7, "M23 capability regression could not identify the quick-target controls")
	_expect(quick_pedestrian_disabled and quick_bicycle_disabled, "M23 quick targets still offer unsupported vulnerable-road-user pairs for a truck primary")
	_expect(quick_wall_enabled, "M23 quick targets incorrectly disable a supported fixed-fixture pair")
	var simulate_control := editor.get("m10_simulate_button") as Button
	_expect(simulate_control != null and not simulate_control.disabled, "M23 Simulate control is disabled for a supported truck-versus-car pair")
	var original_target := config.target_type
	editor.call("_on_target_palette_pressed", ScenarioConfig.TARGET_PEDESTRIAN)
	_expect(config.target_type == original_target, "M23 programmatic target selection bypassed the capability matrix and replaced a supported target with an unsupported pedestrian")
	var capability_status := editor.get("status_label") as Label
	_expect(capability_status != null and capability_status.text.contains("not available for this role"), "M23 rejected target selection without explaining the capability boundary")
	config.target_type = ScenarioConfig.TARGET_PEDESTRIAN
	editor.call("_m23_sync_capability_controls")
	_expect(simulate_control != null and simulate_control.disabled, "M23 Simulate control remains enabled for an imported unsupported truck-versus-pedestrian pair")
	config.target_type = ScenarioConfig.TARGET_PASSENGER_CAR
	config.primary_type = ScenarioConfig.TARGET_PASSENGER_CAR
	editor.call("_m23_sync_primary_specific_controls")
	editor.call("_m23_sync_capability_controls")
	_expect(primary_class_control != null and primary_class_control.get_parent().visible, "M23 did not restore the passenger-car class control after returning to a passenger primary")
	_expect(primary_paint_control != null and primary_paint_control.get_parent().visible, "M23 did not restore the passenger-car paint control after returning to a passenger primary")
	_expect(export_primary_paint_control != null and export_primary_paint_control.get_parent().visible, "M23 did not restore export primary-car paint after returning to a passenger primary")
	_expect(compare_mode_control != null and compare_class_index >= 0 and not compare_mode_control.is_item_disabled(compare_class_index), "M23 did not restore passenger B/C/D class comparison after returning to a passenger primary")
	if target_option != null:
		for option_index in range(target_option.item_count):
			if StringName(String(target_option.get_item_metadata(option_index))) == ScenarioConfig.TARGET_PEDESTRIAN:
				_expect(not target_option.is_item_disabled(option_index), "M23 did not re-enable pedestrian target selection after returning to the supported passenger-primary path")
				break
	config.primary_type = ScenarioConfig.TARGET_TRUCK
	editor.call("_m23_sync_primary_specific_controls")
	editor.call("_m23_sync_capability_controls")
	_expect(simulate_control != null and not simulate_control.disabled, "M23 did not re-enable Simulate after restoring a supported truck-versus-car pair")
	if world != null:
		_expect(world.primary_actor is M21HeavyTruck, "M23 editor did not create the truck as the primary actor")
		_expect(world.target_actor is M162CompactHatchback, "M23 editor did not create the passenger car as the target actor")
		if world.primary_actor is M21HeavyTruck:
			var truck_geometry := world.primary_actor as M21HeavyTruck
			var longitudinal_bounds := VehicleActorRuntime.collision_footprint_bounds(truck_geometry)
			_expect(not longitudinal_bounds.is_empty(), "M23 camera regression could not resolve articulated-truck collision bounds")
			if not longitudinal_bounds.is_empty():
				var longitudinal_span := float(longitudinal_bounds["max_x"]) - float(longitudinal_bounds["min_x"])
				_expect(longitudinal_span > 9.0, "M23 articulated-truck collision footprint lost its full longitudinal envelope")
				var camera_bounds: Vector2 = editor.call("_m161_horizontal_bounds")
				_expect(absf(camera_bounds.x - float(longitudinal_bounds["min_x"])) < 0.05, "M23 camera bounds still use a symmetric half-length instead of the truck's asymmetric collision geometry")
				var camera_center: Vector3 = editor.call("_m161_primary_center")
				var geometry_center_x := (float(longitudinal_bounds["min_x"]) + float(longitudinal_bounds["max_x"])) * 0.5
				_expect(absf(camera_center.x - geometry_center_x) < 0.05, "M23 camera focus still uses the articulated-truck origin instead of its geometry centre")
				VehicleActorRuntime.set_preview_pose(truck_geometry, config.car_position_m, 90.0)
				var rotated_bounds := VehicleActorRuntime.collision_footprint_bounds(truck_geometry)
				_expect(not rotated_bounds.is_empty(), "M23 rotated-truck camera regression could not resolve collision bounds")
				if not rotated_bounds.is_empty():
					var rotated_span_x := float(rotated_bounds["max_x"]) - float(rotated_bounds["min_x"])
					_expect(rotated_span_x < longitudinal_span * 0.5, "M23 camera footprint does not follow actor heading")
				VehicleActorRuntime.set_preview_pose(truck_geometry, config.car_position_m, config.car_heading_deg)
			# Seed known actor-specific values before begin_simulation() resets them so
			# this regression verifies the M23 adapter itself rather than relying on a
			# particular collision severity to produce every metric.
			var truck := world.primary_actor as M21HeavyTruck
			truck.hybrid_front_crush_m = 0.123
			truck.hybrid_rear_crush_m = 0.045
			truck.hybrid_side_negative_z_crush_m = 0.067
			truck.hybrid_side_negative_z_energy_j = 12345.0
			truck.maximum_articulation_yaw_deg = 8.5
			var truck_metrics: Dictionary = editor.call("_m23_actor_metrics", truck, config.car_mass_kg)
			_expect(absf(float(truck_metrics.get("front_crush_m", -1.0)) - 0.123) < 0.000001, "M23 actor metrics dropped heavy-truck front crush")
			_expect(absf(float(truck_metrics.get("rear_crush_m", -1.0)) - 0.045) < 0.000001, "M23 actor metrics dropped heavy-truck rear crush")
			_expect(absf(float(truck_metrics.get("side_crush_m", -1.0)) - 0.067) < 0.000001, "M23 actor metrics dropped heavy-truck side crush")
			_expect(absf(float(truck_metrics.get("side_impact_energy_j", -1.0)) - 12345.0) < 0.001, "M23 actor metrics dropped heavy-truck side-impact energy")
			_expect(absf(float(truck_metrics.get("maximum_articulation_yaw_deg", -1.0)) - 8.5) < 0.000001, "M23 actor metrics dropped articulated-truck peak yaw")
		if world.target_actor is CompactHatchback:
			var passenger := world.target_actor as CompactHatchback
			VehicleActorRuntime.set_preview_pose(passenger, config.target_position_m, 90.0)
			var rotated_reference := passenger.global_reference_transform()
			if passenger.wheel_rig != null and not passenger.wheel_rig.anchor_indices.is_empty():
				passenger.wheel_rig.update_from_model(0.0)
				var attached_index := 0
				var anchor_index := passenger.wheel_rig.anchor_indices[attached_index]
				var anchor_node := passenger.model.nodes[anchor_index]
				var vehicle_center := passenger.wheel_rig._vehicle_center()
				var rotated_lateral := rotated_reference.basis.z.normalized()
				var side_sign := -1.0 if (anchor_node.position_m - vehicle_center).dot(rotated_lateral) < 0.0 else 1.0
				var expected_attached_position := (
					anchor_node.position_m
					+ Vector3.DOWN * passenger.wheel_rig.suspension_drop_m
					+ rotated_lateral * side_sign * passenger.wheel_rig.side_offset_m
				)
				# The production wheel rig also enforces the ground-height floor after
				# applying the vehicle-relative lateral offset. Mirror that unrelated
				# vertical constraint so this assertion isolates the rotated X/Z basis.
				if expected_attached_position.y < passenger.wheel_rig.wheel_radius_m:
					expected_attached_position.y = passenger.wheel_rig.wheel_radius_m
				_expect(passenger.wheel_rig.wheel_instances[attached_index].position.distance_to(expected_attached_position) < 0.000001, "Attached passenger wheel offset still uses fixed world Z after vehicle rotation")
				if passenger.rigid_chassis != null:
					passenger.rigid_chassis.suspension_contact_points_world.resize(passenger.rigid_chassis.suspension_points.size())
					for support_index in range(passenger.rigid_chassis.suspension_contact_points_world.size()):
						passenger.rigid_chassis.suspension_contact_points_world[support_index] = Vector3.INF
					var synthetic_support := Vector3(1.25, 0.0, -2.5)
					passenger.rigid_chassis.suspension_contact_points_world[attached_index] = synthetic_support
					passenger.wheel_rig.update_from_model(0.0)
					var expected_supported_position := synthetic_support + Vector3.UP * passenger.wheel_rig.wheel_radius_m + rotated_lateral * side_sign * passenger.wheel_rig.side_offset_m
					_expect(passenger.wheel_rig.wheel_instances[attached_index].position.distance_to(expected_supported_position) < 0.000001, "Attached passenger wheel support offset still uses fixed world Z after vehicle rotation")
					passenger.rigid_chassis.suspension_contact_points_world[attached_index] = Vector3.INF
					passenger.wheel_rig.update_from_model(0.0)
				var saved_velocity := anchor_node.velocity_ms
				var rotated_forward := rotated_reference.basis.x.normalized()
				anchor_node.velocity_ms = rotated_forward * 3.0
				var attached_rotation_before := passenger.wheel_rig.wheel_instances[attached_index].rotation.z
				passenger.wheel_rig.update_from_model(0.10)
				var expected_spin_delta := 3.0 / maxf(passenger.wheel_rig.wheel_radius_m, 0.01) * 0.10
				var actual_spin_delta := absf(passenger.wheel_rig.wheel_instances[attached_index].rotation.z - attached_rotation_before)
				_expect(absf(actual_spin_delta - expected_spin_delta) < 0.0001, "Attached passenger wheel spin still uses world velocity X instead of vehicle-forward speed")
				anchor_node.velocity_ms = saved_velocity
			var release_base_velocity := passenger.global_linear_velocity_ms()
			var rotated_release_velocity := passenger._front_wheel_release_velocity(1.0)
			var rotated_kick := rotated_release_velocity - release_base_velocity
			_expect(absf(rotated_kick.dot(rotated_reference.basis.x.normalized()) - 0.7) < 0.0001, "Released passenger wheel kick is not aligned with the rotated vehicle forward axis")
			_expect(absf(rotated_kick.dot(rotated_reference.basis.y.normalized()) - 0.9) < 0.0001, "Released passenger wheel kick lost its vehicle-relative upward component")
			_expect(absf(rotated_kick.dot(rotated_reference.basis.z.normalized()) - 0.8) < 0.0001, "Released passenger wheel kick is not aligned with the rotated vehicle lateral axis")
			VehicleActorRuntime.set_preview_pose(passenger, config.target_position_m, config.target_heading_deg)
			var attached_visual_state := passenger.replay_visual_state()
			_expect(passenger.wheel_rig != null, "M23 passenger target is missing its wheel rig")
			if passenger.wheel_rig != null:
				var rolling_forward := passenger.global_reference_transform().basis.x.normalized()
				passenger.wheel_rig.release_wheel(2, Vector3(2.0, 1.2, -0.6), rolling_forward)
				passenger.wheel_rig.release_wheel(3, Vector3(2.0, 1.2, 0.6), rolling_forward)
				passenger.front_wheels_released = true
				var release_rotation_before := passenger.wheel_rig.wheel_instances[2].rotation.z
				_expect(absf(passenger.wheel_rig.released_spin_rad_s[2]) > 0.01, "Released passenger wheel did not inherit rolling spin")
				passenger.wheel_rig.update_from_model(0.12)
				_expect(absf(passenger.wheel_rig.wheel_instances[2].rotation.z - release_rotation_before) > 0.01, "Released passenger wheel stopped spinning after detachment")
				var released_visual_state := passenger.replay_visual_state()
				var expected_left_position := passenger.wheel_rig.released_positions[2]
				var expected_right_position := passenger.wheel_rig.released_positions[3]
				var expected_left_rotation := passenger.wheel_rig.wheel_instances[2].rotation.z
				var expected_left_spin := passenger.wheel_rig.released_spin_rad_s[2]
				var wheel_recorder := ReplayRecorder.new()
				wheel_recorder.begin()
				_expect(
					wheel_recorder.capture(0.0, passenger.model, null, {}, {}, {}, released_visual_state, {}, true),
					"M23 replay recorder rejected a passenger-wheel visual-state frame"
				)
				var recorded_visual_state: Dictionary = wheel_recorder.recording.first_frame().get("primary_visual_state", {})
				var recorded_wheel_value: Variant = recorded_visual_state.get("wheel_rig", {})
				_expect(recorded_wheel_value is Dictionary, "M23 replay frame omitted the serialized wheel-rig state")
				passenger.apply_replay_visual_state(attached_visual_state)
				_expect(not passenger.front_wheels_released, "M23 passenger replay could not restore the pre-release wheel state")
				_expect(passenger.wheel_rig.released[2] == 0 and passenger.wheel_rig.released[3] == 0, "M23 passenger replay left front wheels detached when scrubbing before release")
				passenger.apply_replay_visual_state(recorded_visual_state)
				_expect(passenger.front_wheels_released, "M23 passenger replay dropped the front-wheel release flag")
				_expect(passenger.wheel_rig.released[2] != 0 and passenger.wheel_rig.released[3] != 0, "M23 passenger replay reattached released front wheels")
				_expect(passenger.wheel_rig.released_positions[2].distance_to(expected_left_position) < 0.000001, "M23 passenger replay lost the released left-front wheel position")
				_expect(passenger.wheel_rig.released_positions[3].distance_to(expected_right_position) < 0.000001, "M23 passenger replay lost the released right-front wheel position")
				_expect(passenger.wheel_rig.wheel_instances[2].position.distance_to(expected_left_position) < 0.000001, "M23 passenger replay did not render the released left-front wheel at its recorded position")
				_expect(passenger.wheel_rig.wheel_instances[3].position.distance_to(expected_right_position) < 0.000001, "M23 passenger replay did not render the released right-front wheel at its recorded position")
				_expect(absf(passenger.wheel_rig.wheel_instances[2].rotation.z - expected_left_rotation) < 0.000001, "M23 passenger replay lost released-wheel spin orientation")
				_expect(absf(passenger.wheel_rig.released_spin_rad_s[2] - expected_left_spin) < 0.000001, "M23 passenger replay lost released-wheel angular speed")
				passenger.apply_replay_visual_state(attached_visual_state)
			var car_metrics: Dictionary = editor.call("_m23_actor_metrics", passenger, config.target_mass_kg)
			_expect(car_metrics.has("front_crush_m"), "M23 actor metrics dropped passenger-car front crush")
			_expect(car_metrics.has("safety_cell_m"), "M23 actor metrics dropped passenger-car safety-cell deformation")
	editor.call("_on_simulate_pressed")
	for _frame in range(12):
		await physics_frame
	world = editor.get("m23_vehicle_world") as TwoVehicleWorld3D
	_expect(world != null and world.running, "M23 reciprocal editor run did not start the shared vehicle world")
	if world != null:
		_expect(VehicleActorRuntime.linear_velocity_ms(world.primary_actor).length() > 4.0, "M23 reciprocal editor primary truck did not move from configured speed")
	var recorder := editor.get("replay_recorder") as ReplayRecorder
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "M23 reciprocal editor run did not capture replay frames")
	# The production world is delta-driven.  Headless runners may use a physics
	# cadence below 120 Hz, so use the same duration-derived bounded window as the
	# production comparison harness instead of treating a fixed frame count as a
	# completion contract.
	var maximum_frames := int(ceil(config.duration_s * 260.0)) + 480
	var completed := false
	for _frame in range(maximum_frames):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M23 reciprocal editor run did not complete within its duration-derived bound")
	recorder = editor.get("replay_recorder") as ReplayRecorder
	_expect(recorder != null and recorder.recording != null and recorder.recording.frames.size() >= 2, "M23 reciprocal editor run did not finalize a replay recording")
	if recorder != null and recorder.recording != null and recorder.recording.has_frames():
		var final_primary_metrics: Dictionary = recorder.recording.last_frame().get("primary_metrics", {})
		var final_target_metrics: Dictionary = recorder.recording.last_frame().get("target_metrics", {})
		_expect(final_primary_metrics.has("front_crush_m"), "M23 finalized replay omitted primary front-crush metrics")
		_expect(final_primary_metrics.has("rear_crush_m"), "M23 finalized replay omitted primary rear-crush metrics")
		_expect(final_primary_metrics.has("side_crush_m"), "M23 finalized replay omitted primary side-crush metrics")
		_expect(final_primary_metrics.has("maximum_articulation_yaw_deg"), "M23 finalized replay omitted primary articulation metrics")
		_expect(final_target_metrics.has("front_crush_m"), "M23 finalized replay omitted passenger-car front-crush metrics")
		_expect(final_target_metrics.has("safety_cell_m"), "M23 finalized replay omitted passenger-car safety-cell metrics")
		var first_context: Dictionary = recorder.recording.first_frame().get("context", {})
		_expect(int(first_context.get("contact_count", 0)) == 0, "M23 reciprocal replay reported non-ground contact before the vehicles reached each other")
		var saw_contact := false
		var saw_primary_manifold := false
		var saw_target_manifold := false
		for frame in recorder.recording.frames:
			var context_value: Variant = frame.get("context", {})
			if not context_value is Dictionary:
				continue
			var context: Dictionary = context_value
			if int(context.get("contact_count", 0)) > 0:
				saw_contact = true
			var primary_manifold_value: Variant = context.get("primary_contact_manifold", {})
			if primary_manifold_value is Dictionary and int((primary_manifold_value as Dictionary).get("maximum_contact_points", 0)) > 0:
				saw_primary_manifold = true
			var target_manifold_value: Variant = context.get("target_contact_manifold", {})
			if target_manifold_value is Dictionary and int((target_manifold_value as Dictionary).get("maximum_contact_points", 0)) > 0:
				saw_target_manifold = true
		_expect(saw_contact, "M23 reciprocal replay never recorded the real rigid-body contact counter")
		_expect(saw_primary_manifold, "M23 reciprocal replay never recorded the primary contact manifold")
		_expect(saw_target_manifold, "M23 reciprocal replay never recorded the target contact manifold")
		var analysis := CrashAnalysis.analyze(recorder.recording)
		_expect(recorder.recording.marker_time(&"first_contact") >= 0.0, "M23 reciprocal analysis did not create a first-contact marker")
		_expect(float(analysis.get("peak_deceleration_g", 0.0)) > 0.0, "M23 reciprocal analysis still reports zero peak deceleration after a real impact")
		_expect(analysis.has("primary_max_reported_deformation_mm"), "M23 reciprocal analysis omitted role-neutral primary deformation")
		editor.set("analysis_report", analysis)
		editor.call("_refresh_analysis_ui")
		var analysis_summary := editor.get("analysis_summary_label") as Label
		_expect(analysis_summary != null and analysis_summary.text.contains("max reported deformation"), "M23 analysis UI did not switch to role-neutral deformation terminology")
		_expect(analysis_summary == null or not analysis_summary.text.contains("front crush"), "M23 analysis UI still presents passenger-car front-crush terminology for a truck primary")
		_expect(analysis_summary == null or not analysis_summary.text.contains("safety-cell"), "M23 analysis UI still presents passenger-car safety-cell terminology for a truck primary")
		editor.call("_apply_replay_time", recorder.recording.duration_s * 0.5, true)
		_expect(is_finite(float(editor.get("replay_time_s"))), "M23 reciprocal replay scrubbing produced a non-finite time")
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
