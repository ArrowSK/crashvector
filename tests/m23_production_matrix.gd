# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

const MATRIX_PRIMARIES = [
	ScenarioConfig.TARGET_TRUCK,
	ScenarioConfig.TARGET_LORRY,
	ScenarioConfig.TARGET_MOTORCYCLE,
	ScenarioConfig.TARGET_TANK,
]

const SUPPORTED_RECIPROCAL_TARGETS = [
	ScenarioConfig.TARGET_PASSENGER_CAR,
	ScenarioConfig.TARGET_TRUCK,
	ScenarioConfig.TARGET_LORRY,
	ScenarioConfig.TARGET_MOTORCYCLE,
	ScenarioConfig.TARGET_TANK,
	ScenarioConfig.TARGET_WALL,
	ScenarioConfig.TARGET_BARRIER,
	ScenarioConfig.TARGET_POLE,
	ScenarioConfig.TARGET_TREE,
]

const UNSUPPORTED_RECIPROCAL_TARGETS = [
	ScenarioConfig.TARGET_BICYCLE,
	ScenarioConfig.TARGET_CYCLIST,
	ScenarioConfig.TARGET_PEDESTRIAN,
]

# Representative full-editor collisions cover every movable M23 actor family in
# both roles where the scenario contract permits it. Tank remains asymmetric by
# design: dynamic as primary, fixed when selected as target.
const EDITOR_VEHICLE_CASES = [
	[ScenarioConfig.TARGET_TRUCK, ScenarioConfig.TARGET_PASSENGER_CAR],
	[ScenarioConfig.TARGET_LORRY, ScenarioConfig.TARGET_TRUCK],
	[ScenarioConfig.TARGET_MOTORCYCLE, ScenarioConfig.TARGET_LORRY],
	[ScenarioConfig.TARGET_TANK, ScenarioConfig.TARGET_MOTORCYCLE],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _check_world_capability_matrix()
	await _check_comparison_lab_primary_limits()
	await _check_editor_vehicle_family_matrix()
	await _check_editor_fixture_path()
	_finish()

func _check_comparison_lab_primary_limits() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		failures.append("M23 Comparison Lab fixture cannot load editor")
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	editor.set("scenario", _matrix_config(ScenarioConfig.TARGET_TANK, ScenarioConfig.TARGET_WALL))
	root.add_child(editor)
	for _frame in range(6):
		await process_frame
	var mode := editor.get("matrix_mode_option") as OptionButton
	_expect(mode != null, "M23 Comparison Lab mode control missing")
	if mode != null:
		for index in range(mode.item_count):
			_expect(mode.is_item_disabled(index), "M23 tank primary offered a matrix without production replay")
	var speed_spins: Array = editor.get("matrix_speed_spins")
	for spin in speed_spins:
		_expect(spin.max_value == 80.0 and spin.value <= 80.0,
			"M23 tank comparison speed exceeded its 80 km/h limit")
	var unavailable: Array = editor.call("_m17_matrix_comparison_variants")
	_expect(unavailable.is_empty(), "M23 tank primary generated comparison variants without replay")

	# A truck with a dynamic vehicle target supports replay. Its target matrix
	# must offer only compatible vehicle targets and obey its 140 km/h limit.
	editor.set("scenario", _matrix_config(ScenarioConfig.TARGET_TRUCK, ScenarioConfig.TARGET_PASSENGER_CAR))
	editor.call("_sync_m10_from_scenario")
	if mode != null:
		_expect(mode.is_item_disabled(0) and mode.is_item_disabled(2),
			"M23 truck primary exposed passenger classes or road-user matrices")
		_expect(not mode.is_item_disabled(1) and mode.selected == 1,
			"M23 truck primary failed to select the supported vehicle-target matrix")
	for spin in speed_spins:
		_expect(spin.max_value == 140.0 and spin.value <= 140.0,
			"M23 truck Comparison Lab exceeded its speed limit")
	var main_speed := editor.get("m10_compare_speed_c") as SpinBox
	if main_speed != null:
		_expect(main_speed.max_value == 140.0 and main_speed.value <= 140.0,
			"M23 truck ordinary speed comparison exceeded its limit")
	var variants: Array = editor.call("_m17_matrix_comparison_variants")
	_expect(not variants.is_empty(), "M23 truck Comparison Lab lost supported vehicle-target variants")
	for variant in variants:
		var test_config := variant.get("scenario") as ScenarioConfig
		_expect(test_config != null and test_config.validation_errors().is_empty(),
			"M23 truck Comparison Lab generated an invalid vehicle-pair scenario")
	var selected_variants: Array = editor.call("_m17_main_comparison_variants", &"vehicle_class")
	_expect(selected_variants.is_empty(), "M23 non-passenger primary generated ordinary car-class comparisons")
	if mode != null:
		mode.select(0)  # Exercise the defensive guard behind the disabled option.
		var class_variants: Array = editor.call("_m17_matrix_comparison_variants")
		_expect(class_variants.is_empty(), "M23 truck primary still generated passenger-car class matrix")
		mode.select(1)
		var options: Array = editor.get("matrix_variant_options")
		if options.size() > 0:
			var option := options[0] as OptionButton
			for index in range(option.item_count):
				var target_id := StringName(String(option.get_item_metadata(index)))
				if target_id == ScenarioConfig.TARGET_PEDESTRIAN or target_id == ScenarioConfig.TARGET_WALL:
					_expect(option.is_item_disabled(index), "M23 truck comparison offered target without replay")

	# Switching back to passenger cars restores the original comparison modes.
	var passenger := ScenarioConfig.new()
	passenger.target_position_m = Vector3(20.0, 0.0, 0.0)
	editor.set("scenario", passenger)
	editor.call("_sync_m10_from_scenario")
	if mode != null:
		_expect(not mode.is_item_disabled(0) and not mode.is_item_disabled(2),
			"M23 passenger primary did not restore all comparison modes")
	for spin in speed_spins:
		_expect(spin.max_value == 300.0, "M23 passenger primary did not restore speed range")
	editor.queue_free()
	await process_frame

func _check_world_capability_matrix() -> void:
	for target_type in ScenarioConfig.target_ids():
		var expected_supported := target_type in SUPPORTED_RECIPROCAL_TARGETS
		_expect(
			TwoVehicleWorld3D.supports_target(target_type) == expected_supported,
			"M23 production capability declaration disagrees with the locked matrix for %s"
			% ScenarioConfig.target_display_name(target_type)
		)

	for primary_type in MATRIX_PRIMARIES:
		for target_type in SUPPORTED_RECIPROCAL_TARGETS:
			var config := _matrix_config(primary_type, target_type)
			var validation_errors := config.validation_errors()
			_expect(
				validation_errors.is_empty(),
				"M23 production matrix scenario failed ScenarioConfig validation for %s -> %s: %s"
				% [ScenarioConfig.actor_display_name(primary_type), ScenarioConfig.target_display_name(target_type), "; ".join(validation_errors)]
			)
			var world := TwoVehicleWorld3D.new()
			world.name = "M23MatrixWorld"
			world.build_road = false
			root.add_child(world)
			var configured := world.configure(config)
			_expect(
				configured,
				"M23 production world rejected supported pair %s -> %s"
				% [ScenarioConfig.actor_display_name(primary_type), ScenarioConfig.target_display_name(target_type)]
			)
			if configured:
				await process_frame
				_check_world_pair_contract(world, config)
				world.begin()
				# SceneTree.physics_frame is emitted immediately before Node._physics_process.
				# Wait through one complete physics tick, then resume at the next signal so
				# TwoVehicleWorld3D has actually executed its elapsed-time step.
				await physics_frame
				await physics_frame
				_expect(world.running, "M23 production world did not start %s -> %s" % [ScenarioConfig.actor_display_name(primary_type), ScenarioConfig.target_display_name(target_type)])
				_expect(world.elapsed_s > 0.0, "M23 production world did not advance %s -> %s" % [ScenarioConfig.actor_display_name(primary_type), ScenarioConfig.target_display_name(target_type)])
				var primary_velocity := VehicleActorRuntime.linear_velocity_ms(world.primary_actor)
				_expect(
					_is_finite_vector(primary_velocity) and primary_velocity.length() > 1.0,
					"M23 production primary did not retain finite commanded motion for %s -> %s"
					% [ScenarioConfig.actor_display_name(primary_type), ScenarioConfig.target_display_name(target_type)]
				)
				world.stop()
				_expect(not world.running, "M23 production world did not stop %s -> %s" % [ScenarioConfig.actor_display_name(primary_type), ScenarioConfig.target_display_name(target_type)])
			world.queue_free()
			await process_frame

		for target_type in UNSUPPORTED_RECIPROCAL_TARGETS:
			var rejected_config := _matrix_config(primary_type, target_type)
			var rejected_world := TwoVehicleWorld3D.new()
			rejected_world.build_road = false
			_expect(
				not rejected_world.configure(rejected_config),
				"M23 production world accepted unsupported pair %s -> %s"
				% [ScenarioConfig.actor_display_name(primary_type), ScenarioConfig.target_display_name(target_type)]
			)
			rejected_world.free()

func _check_world_pair_contract(world: TwoVehicleWorld3D, config: ScenarioConfig) -> void:
	_expect(
		_actor_matches_vehicle_type(world.primary_actor, config.primary_type),
		"M23 production matrix created the wrong primary actor for %s" % ScenarioConfig.actor_display_name(config.primary_type)
	)
	var primary_bodies := VehicleActorRuntime.physics_bodies(world.primary_actor)
	var expected_primary_bodies := 2 if config.primary_type == ScenarioConfig.TARGET_TRUCK else 1
	_expect(
		primary_bodies.size() == expected_primary_bodies,
		"M23 production matrix exposed %d primary physics bodies instead of %d for %s"
		% [primary_bodies.size(), expected_primary_bodies, ScenarioConfig.actor_display_name(config.primary_type)]
	)
	_expect(
		not VehicleActorRuntime.collision_footprint_bounds(world.primary_actor).is_empty(),
		"M23 production matrix primary has no collision footprint for %s" % ScenarioConfig.actor_display_name(config.primary_type)
	)
	for body in primary_bodies:
		_check_material(body.physics_material_override, config, "primary %s" % ScenarioConfig.actor_display_name(config.primary_type))

	if ScenarioConfig.is_vehicle_actor_id(config.target_type) and config.target_type != ScenarioConfig.TARGET_TANK:
		_expect(
			_actor_matches_vehicle_type(world.target_actor, config.target_type),
			"M23 production matrix created the wrong target actor for %s" % ScenarioConfig.target_display_name(config.target_type)
		)
		var target_bodies := VehicleActorRuntime.physics_bodies(world.target_actor)
		var expected_target_bodies := 2 if config.target_type == ScenarioConfig.TARGET_TRUCK else 1
		_expect(
			target_bodies.size() == expected_target_bodies,
			"M23 production matrix exposed %d target physics bodies instead of %d for %s"
			% [target_bodies.size(), expected_target_bodies, ScenarioConfig.target_display_name(config.target_type)]
		)
		_expect(
			not VehicleActorRuntime.collision_footprint_bounds(world.target_actor).is_empty(),
			"M23 production matrix target has no collision footprint for %s" % ScenarioConfig.target_display_name(config.target_type)
		)
		for body in target_bodies:
			_check_material(body.physics_material_override, config, "target %s" % ScenarioConfig.target_display_name(config.target_type))
	else:
		var fixture := world.target_actor as StaticObstacle3D
		_expect(fixture != null, "M23 production matrix did not create a fixed fixture for %s" % ScenarioConfig.target_display_name(config.target_type))
		if fixture != null:
			_expect(fixture.obstacle_type == config.target_type, "M23 production matrix fixture type changed for %s" % ScenarioConfig.target_display_name(config.target_type))
			_expect(fixture.physics_body != null, "M23 production matrix fixture has no physics body for %s" % ScenarioConfig.target_display_name(config.target_type))
			if fixture.physics_body != null:
				_check_material(fixture.physics_body.physics_material_override, config, "fixture %s" % ScenarioConfig.target_display_name(config.target_type))

func _check_editor_vehicle_family_matrix() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M23 production-matrix editor scene did not load")
	if packed == null:
		return
	for pair in EDITOR_VEHICLE_CASES:
		var primary_type: StringName = pair[0]
		var target_type: StringName = pair[1]
		var pair_label := "%s -> %s" % [ScenarioConfig.actor_display_name(primary_type), ScenarioConfig.target_display_name(target_type)]
		var config := _near_contact_config(primary_type, target_type)
		var errors := config.validation_errors()
		_expect(
			errors.is_empty(),
			"M23 end-to-end matrix scenario failed validation for %s: %s"
			% [pair_label, "; ".join(errors)]
		)
		if not errors.is_empty():
			continue
		var editor := packed.instantiate()
		editor.set("m10_first_run_applied", true)
		editor.set("scenario", config)
		root.add_child(editor)
		for _frame in range(6):
			await process_frame

		var world := editor.get("m23_vehicle_world") as TwoVehicleWorld3D
		_expect(world != null, "M23 editor did not build production world for %s" % pair_label)
		if world != null:
			_expect(_actor_matches_vehicle_type(world.primary_actor, primary_type), "M23 editor created the wrong primary actor for %s" % pair_label)
			_expect(_actor_matches_vehicle_type(world.target_actor, target_type), "M23 editor created the wrong movable target actor for %s" % pair_label)

		var replay_supported := bool(editor.call("_m23_replay_supported"))
		_expect(
			replay_supported == (primary_type != ScenarioConfig.TARGET_TANK),
			"M23 editor replay capability changed unexpectedly for %s" % pair_label
		)

		editor.call("_on_simulate_pressed")
		_expect(bool(editor.get("simulation_running")), "M23 editor did not start %s" % pair_label)
		var completed := await _wait_for_editor_completion(editor, config.duration_s)
		_expect(completed, "M23 editor did not complete %s within the bounded production window" % pair_label)

		world = editor.get("m23_vehicle_world") as TwoVehicleWorld3D
		if world != null:
			var contact_count := maxi(
				VehicleActorRuntime.contact_event_count(world.primary_actor),
				VehicleActorRuntime.contact_event_count(world.target_actor)
			)
			_expect(contact_count > 0, "M23 end-to-end run never recorded rigid-body contact for %s" % pair_label)

		if replay_supported:
			var recorder := editor.get("replay_recorder") as ReplayRecorder
			_expect(recorder != null and recorder.recording != null and recorder.recording.frames.size() >= 2, "M23 end-to-end run did not finalize replay for %s" % pair_label)
			var analysis_value: Variant = editor.get("analysis_report")
			_expect(analysis_value is Dictionary and not (analysis_value as Dictionary).is_empty(), "M23 end-to-end run did not produce analysis for %s" % pair_label)
			if recorder != null and recorder.recording != null and recorder.recording.has_frames():
				var saw_contact_frame := false
				var all_frames_role_neutral := true
				for frame in recorder.recording.frames:
					var context_value: Variant = frame.get("context", {})
					if not context_value is Dictionary:
						all_frames_role_neutral = false
						continue
					var context: Dictionary = context_value
					if String(context.get("world", "")) != "role_neutral_rigidbody_pair":
						all_frames_role_neutral = false
					if int(context.get("contact_count", 0)) > 0:
						saw_contact_frame = true
				_expect(all_frames_role_neutral, "M23 replay mixed non-role-neutral frame context for %s" % pair_label)
				_expect(saw_contact_frame, "M23 replay never captured contact for %s" % pair_label)
				_expect(recorder.recording.marker_time(&"first_contact") >= 0.0, "M23 analysis did not mark first contact for %s" % pair_label)
				var final_primary_metrics: Dictionary = recorder.recording.last_frame().get("primary_metrics", {})
				var final_target_metrics: Dictionary = recorder.recording.last_frame().get("target_metrics", {})
				_expect(final_primary_metrics.has("linear_velocity_ms") and final_primary_metrics.has("kinetic_energy_j"), "M23 replay omitted primary motion metrics for %s" % pair_label)
				_expect(final_target_metrics.has("linear_velocity_ms") and final_target_metrics.has("kinetic_energy_j"), "M23 replay omitted target motion metrics for %s" % pair_label)
				editor.call("_apply_replay_time", recorder.recording.duration_s * 0.5, true)
				_expect(is_finite(float(editor.get("replay_time_s"))), "M23 replay scrub produced a non-finite time for %s" % pair_label)

		editor.queue_free()
		await process_frame

func _check_editor_fixture_path() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		return
	var config := _near_contact_config(ScenarioConfig.TARGET_LORRY, ScenarioConfig.TARGET_WALL)
	var errors := config.validation_errors()
	_expect(errors.is_empty(), "M23 lorry-versus-wall production scenario failed validation: %s" % "; ".join(errors))
	if not errors.is_empty():
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(6):
		await process_frame
	var world := editor.get("m23_vehicle_world") as TwoVehicleWorld3D
	_expect(world != null and world.target_actor is StaticObstacle3D, "M23 editor did not route lorry-versus-wall through the role-neutral fixture world")
	_expect(not bool(editor.call("_m23_replay_supported")), "M23 fixed-fixture path unexpectedly claims structural replay support")
	editor.call("_on_simulate_pressed")
	_expect(bool(editor.get("simulation_running")), "M23 editor did not start lorry-versus-wall")
	var completed := await _wait_for_editor_completion(editor, config.duration_s)
	_expect(completed, "M23 editor did not complete lorry-versus-wall within the bounded production window")
	world = editor.get("m23_vehicle_world") as TwoVehicleWorld3D
	if world != null:
		_expect(VehicleActorRuntime.contact_event_count(world.primary_actor) > 0, "M23 lorry-versus-wall path never recorded real fixture contact")
	editor.queue_free()
	await process_frame

func _matrix_config(primary_type: StringName, target_type: StringName) -> ScenarioConfig:
	var config := ScenarioConfig.new()
	config.apply_primary_vehicle_defaults(primary_type)
	config.car_speed_kmh = 36.0
	config.car_position_m = Vector3(-20.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.apply_target_defaults(target_type)
	config.target_speed_kmh = 0.0
	config.target_position_m = Vector3(20.0, 0.0, 0.0)
	config.target_heading_deg = 0.0
	config.contact_friction = 0.55
	config.restitution = 0.03
	config.duration_s = 0.5
	return config

func _near_contact_config(primary_type: StringName, target_type: StringName) -> ScenarioConfig:
	var config := _matrix_config(primary_type, target_type)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	var primary_envelope := ScenarioConfig._vehicle_start_envelope(primary_type, config.car_preset_id)
	var primary_front_x := (
		config.car_position_m.x
		+ float(primary_envelope.get("center_offset_x_m", 0.0))
		+ float(primary_envelope.get("half_length_m", 2.0))
	)
	if ScenarioConfig.is_vehicle_actor_id(target_type):
		var target_envelope := ScenarioConfig._vehicle_start_envelope(target_type, config.target_car_preset_id)
		config.target_position_m.x = (
			primary_front_x
			+ 0.20
			- float(target_envelope.get("center_offset_x_m", 0.0))
			+ float(target_envelope.get("half_length_m", 2.0))
		)
	else:
		var target_half_length := 0.225
		if target_type == ScenarioConfig.TARGET_BARRIER:
			target_half_length = 0.21
		elif target_type == ScenarioConfig.TARGET_POLE:
			target_half_length = 0.18
		elif target_type == ScenarioConfig.TARGET_TREE:
			target_half_length = 0.32
		config.target_position_m.x = primary_front_x + 0.20 + target_half_length
	config.target_position_m.z = 0.0
	config.duration_s = 0.7
	return config

func _wait_for_editor_completion(editor: Node, duration_s: float) -> bool:
	var maximum_frames := int(ceil(duration_s * 260.0)) + 480
	for _frame in range(maximum_frames):
		if not bool(editor.get("simulation_running")):
			return true
		await physics_frame
	return false

func _actor_matches_vehicle_type(actor: Node, actor_type: StringName) -> bool:
	match actor_type:
		ScenarioConfig.TARGET_PASSENGER_CAR:
			return actor is M162CompactHatchback
		ScenarioConfig.TARGET_TRUCK:
			return actor is M21HeavyTruck
		ScenarioConfig.TARGET_LORRY:
			return actor is M20RigidLorry
		ScenarioConfig.TARGET_MOTORCYCLE:
			return actor is M20Motorcycle
		ScenarioConfig.TARGET_TANK:
			return actor is DynamicTank3D
	return false

func _check_material(material: PhysicsMaterial, config: ScenarioConfig, context: String) -> void:
	_expect(material != null, "M23 production matrix omitted contact material on %s" % context)
	if material == null:
		return
	_expect(absf(material.friction - config.contact_friction) < 0.000001, "M23 production matrix changed friction on %s" % context)
	_expect(absf(material.bounce - config.restitution) < 0.000001, "M23 production matrix changed restitution on %s" % context)

func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("CrashVector M23 production matrix regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
