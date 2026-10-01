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
	_check_rigidbody_contact_settings()
	await _check_two_vehicle_world()
	await _check_tank_primary_role()
	await _check_articulated_target_materials()
	await _check_vehicle_fixture_world()
	await _check_motorcycle_rider_replay()
	await _check_editor_reciprocal_vehicle_pair()
	_finish()

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
	actor.apply_replay_visual_state(recorded_state)
	_expect(actor.rider_rig.rider_released, "M23 motorcycle replay reattached the released rider")
	_expect(actor.rider_rig.torso.freeze and actor.rider_rig.head.freeze, "M23 motorcycle replay left released rider bodies live during timeline playback")
	_expect(actor.rider_rig.torso.global_transform.origin.distance_to(torso_transform.origin) < 0.000001, "M23 motorcycle replay lost the released torso position")
	_expect(actor.rider_rig.head.global_transform.origin.distance_to(head_transform.origin) < 0.000001, "M23 motorcycle replay lost the released head position")
	_expect(actor.rider_rig.torso.linear_velocity.distance_to(Vector3(6.0, 2.5, -1.2)) < 0.000001, "M23 motorcycle replay lost the released torso velocity")
	_expect(actor.rider_rig.head.linear_velocity.distance_to(Vector3(6.4, 2.9, -0.8)) < 0.000001, "M23 motorcycle replay lost the released head velocity")
	_expect(actor.rider_rig.torso.angular_velocity.distance_to(Vector3(0.4, -0.8, 1.1)) < 0.000001, "M23 motorcycle replay lost the released torso angular velocity")
	_expect(actor.rider_rig.head.angular_velocity.distance_to(Vector3(-0.3, 0.6, 1.4)) < 0.000001, "M23 motorcycle replay lost the released head angular velocity")

	actor.queue_free()
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
	var friction_control := editor.get("m10_friction") as SpinBox
	var restitution_control := editor.get("m10_restitution") as SpinBox
	var substeps_control := editor.get("m10_substeps") as SpinBox
	_expect(friction_control != null and absf(friction_control.max_value - TwoVehicleWorld3D.MAX_CONTACT_FRICTION) < 0.000001, "M23 Physics tab still exposes friction above the rigid-body limit")
	_expect(restitution_control != null and absf(restitution_control.max_value - TwoVehicleWorld3D.MAX_CONTACT_RESTITUTION) < 0.000001, "M23 Physics tab still exposes restitution above the rigid-body production bound")
	_expect(substeps_control != null and not substeps_control.editable, "M23 editor still presents solver substeps as an active RigidBody3D control")
	if substeps_control != null:
		_expect(int(substeps_control.value) == config.solver_substeps, "M23 editor changed the persisted structural-solver substep value while disabling it")
	var physics_warning := editor.find_child("PhysicsScopeWarning", true, false) as Label
	_expect(physics_warning != null and physics_warning.text.contains("do not affect this path"), "M23 Physics tab does not explain that solver substeps are unused by RigidBody3D")
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
