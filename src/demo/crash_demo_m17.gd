# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m16_2.gd"

# M17 is the production-integration review layer. It restores Comparison using
# the exact current rigid-body scene instead of the historical reduced-order
# runner, allows dynamic targets to approach from either direction, ports the
# previously blocked lorry/motorcycle targets to Godot world motion, adds direct
# rear passenger-car deformation and bounded heavy-truck front/rear collapse,
# and makes the proving road long enough for the supported speed/time envelope.

const M17_ROAD_LENGTH_M := 4000.0
const M17_ROAD_WIDTH_M := 20.0
const M17_COMPARISON_BATCH_SIZE := 3

var m17_lorry: M17RigidLorry
var m17_motorcycle: M17Motorcycle
var m17_comparison_running := false

func _ready() -> void:
	super._ready()
	_m17_expand_editor_ranges()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.028, 0.035, 0.050)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.50, 0.53, 0.60)
	environment.ambient_light_energy = 0.90
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.name = "EditorCamera"
	add_child(camera)
	camera.current = true

	# 4 km gives a 300 km/h vehicle more than the full 20 s supported simulation
	# window in either longitudinal direction while keeping one continuous road
	# collision surface under the scene.
	_create_static_box("Road", Vector3(0.0, -0.25, 0.0), Vector3(M17_ROAD_LENGTH_M, 0.5, M17_ROAD_WIDTH_M), Color(0.10, 0.11, 0.13))

func _build_m10_environment() -> void:
	super._build_m10_environment()
	_m17_resize_presentation_box("TechnicalGround", Vector3(M17_ROAD_LENGTH_M + 160.0, 0.16, 120.0), Vector3(0.0, -0.10, 0.0))
	_m17_resize_presentation_box("AsphaltSurface", Vector3(M17_ROAD_LENGTH_M, 0.012, M17_ROAD_WIDTH_M), Vector3(0.0, 0.006, 0.0))
	_m17_resize_presentation_box("LeftShoulder", Vector3(M17_ROAD_LENGTH_M, 0.022, 0.70), Vector3(0.0, 0.012, -10.35))
	_m17_resize_presentation_box("RightShoulder", Vector3(M17_ROAD_LENGTH_M, 0.022, 0.70), Vector3(0.0, 0.012, 10.35))
	_m17_resize_presentation_box("EdgeLineL", Vector3(M17_ROAD_LENGTH_M, 0.018, 0.08), Vector3(0.0, 0.024, -9.45))
	_m17_resize_presentation_box("EdgeLineR", Vector3(M17_ROAD_LENGTH_M, 0.018, 0.08), Vector3(0.0, 0.024, 9.45))
	if m10_environment_root != null:
		for x in range(-1968, 1969, 24):
			_add_visual_box("M17CentreMark%d" % x, Vector3(float(x), 0.025, 0.0), Vector3(12.0, 0.018, 0.09), Color("e4e5dd"), 0.75)

func _m17_resize_presentation_box(node_name: String, size_value: Vector3, position_value: Vector3) -> void:
	if m10_environment_root == null:
		return
	var instance := m10_environment_root.get_node_or_null(node_name) as MeshInstance3D
	if instance == null:
		return
	var mesh := instance.mesh as BoxMesh
	if mesh != null:
		mesh.size = size_value
	instance.position = position_value

func _m17_expand_editor_ranges() -> void:
	for spin in [m10_vehicle_x, m10_target_x]:
		if spin != null:
			spin.min_value = -1900.0
			spin.max_value = 1900.0
	for spin in [m10_vehicle_z, m10_target_z]:
		if spin != null:
			spin.min_value = -18.0
			spin.max_value = 18.0

func _spawn_passenger_car(
	node_name: String,
	preset_id: StringName,
	mass_kg: float,
	speed_kmh: float,
	position_m: Vector3,
	heading_deg: float
) -> CompactHatchback:
	var vehicle := M17CompactHatchback.new()
	vehicle.name = node_name
	vehicle.vehicle_preset_id = preset_id
	vehicle.total_mass_kg = mass_kg
	vehicle.initial_speed_kmh = speed_kmh
	vehicle.origin_offset_m = position_m
	vehicle.heading_deg = heading_deg
	vehicle.auto_step = false
	vehicle.show_structure = scenario.show_structure
	add_child(vehicle)
	return vehicle

func _target_supports_hybrid_world() -> bool:
	if scenario != null and scenario.target_type in [ScenarioConfig.TARGET_LORRY, ScenarioConfig.TARGET_MOTORCYCLE]:
		return true
	return super._target_supports_hybrid_world()

func _rebuild_preview() -> void:
	_m17_dispose_extra_targets()
	super._rebuild_preview()
	if scenario == null:
		return
	if scenario.target_type == ScenarioConfig.TARGET_TRUCK:
		_m17_replace_heavy_truck()
	elif scenario.target_type == ScenarioConfig.TARGET_LORRY:
		_m17_replace_static_with_lorry()
	elif scenario.target_type == ScenarioConfig.TARGET_MOTORCYCLE:
		_m17_replace_static_with_motorcycle()

func _m17_replace_heavy_truck() -> void:
	if truck != null and is_instance_valid(truck):
		if truck.get_parent() == self:
			remove_child(truck)
		truck.queue_free()
	truck = M17HeavyTruck.new()
	truck.name = "HeavyTruck"
	truck.total_mass_kg = scenario.target_mass_kg
	truck.initial_speed_kmh = scenario.target_speed_kmh
	truck.origin_offset_m = scenario.target_position_m
	truck.heading_deg = scenario.target_heading_deg
	truck.auto_step = false
	truck.show_structure = scenario.show_structure
	add_child(truck)
	truck.hybrid_physics_enabled = true
	truck.solver_substeps = scenario.solver_substeps
	_configure_chassis_material(truck.rigid_chassis)
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true
	call_deferred("_m162_refresh_presentation_skins")

func _m17_replace_static_with_lorry() -> void:
	_m17_remove_obstacle_placeholder()
	m17_lorry = M17RigidLorry.new()
	m17_lorry.name = "RigidLorry"
	m17_lorry.total_mass_kg = scenario.target_mass_kg
	m17_lorry.initial_speed_kmh = scenario.target_speed_kmh
	m17_lorry.origin_offset_m = scenario.target_position_m
	m17_lorry.heading_deg = scenario.target_heading_deg
	m17_lorry.auto_step = false
	m17_lorry.show_structure = scenario.show_structure
	add_child(m17_lorry)
	_configure_chassis_material(m17_lorry.rigid_chassis)
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true

func _m17_replace_static_with_motorcycle() -> void:
	_m17_remove_obstacle_placeholder()
	m17_motorcycle = M17Motorcycle.new()
	m17_motorcycle.name = "Motorcycle"
	m17_motorcycle.total_mass_kg = scenario.target_mass_kg
	m17_motorcycle.initial_speed_kmh = scenario.target_speed_kmh
	m17_motorcycle.origin_offset_m = scenario.target_position_m
	m17_motorcycle.heading_deg = scenario.target_heading_deg
	m17_motorcycle.auto_step = false
	m17_motorcycle.show_structure = scenario.show_structure
	add_child(m17_motorcycle)
	_configure_chassis_material(m17_motorcycle.rigid_chassis)
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true

func _m17_remove_obstacle_placeholder() -> void:
	if obstacle != null and is_instance_valid(obstacle):
		if obstacle.get_parent() == self:
			remove_child(obstacle)
		obstacle.queue_free()
	obstacle = null

func _m162_refresh_presentation_skins() -> void:
	if road_user_proxy != null and is_instance_valid(road_user_proxy):
		if m162_road_user_skin == null or not is_instance_valid(m162_road_user_skin) or m162_road_user_skin.proxy != road_user_proxy:
			if m162_road_user_skin != null and is_instance_valid(m162_road_user_skin):
				m162_road_user_skin.queue_free()
			m162_road_user_skin = RoadUserPresentationSkin3D.new()
			add_child(m162_road_user_skin)
			m162_road_user_skin.configure(road_user_proxy)
	if truck != null and is_instance_valid(truck):
		if m162_truck_skin == null or not is_instance_valid(m162_truck_skin) or not (m162_truck_skin is M17HeavyTruckVisual) or m162_truck_skin.truck != truck:
			if m162_truck_skin != null and is_instance_valid(m162_truck_skin):
				m162_truck_skin.queue_free()
			m162_truck_skin = M17HeavyTruckVisual.new()
			truck.add_child(m162_truck_skin)
			m162_truck_skin.configure(truck)

func _physics_process(delta: float) -> void:
	if simulation_running and not simulation_paused:
		if m17_lorry != null and is_instance_valid(m17_lorry):
			m17_lorry.step_external(delta)
		if m17_motorcycle != null and is_instance_valid(m17_motorcycle):
			m17_motorcycle.step_external(delta)
	super._physics_process(delta)

func _on_simulate_pressed() -> void:
	super._on_simulate_pressed()
	if not simulation_running or not hybrid_production_active:
		return
	if m17_lorry != null and is_instance_valid(m17_lorry):
		m17_lorry.begin_simulation()
	if m17_motorcycle != null and is_instance_valid(m17_motorcycle):
		m17_motorcycle.begin_simulation()

func _on_pause_pressed() -> void:
	super._on_pause_pressed()
	if m17_lorry != null and is_instance_valid(m17_lorry):
		m17_lorry.set_simulation_paused(simulation_paused)
	if m17_motorcycle != null and is_instance_valid(m17_motorcycle):
		m17_motorcycle.set_simulation_paused(simulation_paused)

func _stop_hybrid_motion() -> void:
	if m17_lorry != null and is_instance_valid(m17_lorry):
		m17_lorry.end_simulation()
	if m17_motorcycle != null and is_instance_valid(m17_motorcycle):
		m17_motorcycle.end_simulation()
	super._stop_hybrid_motion()

func _clear_runtime_objects() -> void:
	_m17_dispose_extra_targets()
	super._clear_runtime_objects()

func _m17_dispose_extra_targets() -> void:
	for node in [m17_lorry, m17_motorcycle]:
		if node != null and is_instance_valid(node):
			if node.get_parent() == self:
				remove_child(node)
			node.queue_free()
	m17_lorry = null
	m17_motorcycle = null

func _move_selected(delta_m: Vector3) -> void:
	if selected_object == &"target" and m17_lorry != null and is_instance_valid(m17_lorry):
		if delta_m.is_zero_approx():
			return
		scenario.target_position_m += delta_m
		m17_lorry.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		_sync_current_object_fields()
		return
	if selected_object == &"target" and m17_motorcycle != null and is_instance_valid(m17_motorcycle):
		if delta_m.is_zero_approx():
			return
		scenario.target_position_m += delta_m
		m17_motorcycle.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		_sync_current_object_fields()
		return
	super._move_selected(delta_m)

func _rotate_selected(delta_deg: float) -> void:
	if selected_object == &"target" and m17_lorry != null and is_instance_valid(m17_lorry):
		if is_zero_approx(delta_deg):
			return
		scenario.target_heading_deg = wrapf(scenario.target_heading_deg + delta_deg, -180.0, 180.0)
		m17_lorry.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		_sync_current_object_fields()
		return
	if selected_object == &"target" and m17_motorcycle != null and is_instance_valid(m17_motorcycle):
		if is_zero_approx(delta_deg):
			return
		scenario.target_heading_deg = wrapf(scenario.target_heading_deg + delta_deg, -180.0, 180.0)
		m17_motorcycle.set_preview_pose(scenario.target_position_m, scenario.target_heading_deg)
		_sync_current_object_fields()
		return
	super._rotate_selected(delta_deg)

func _on_structure_toggled(value: bool) -> void:
	super._on_structure_toggled(value)
	if m17_lorry != null:
		m17_lorry.set_structure_debug(value)
	if m17_motorcycle != null:
		m17_motorcycle.set_structure_debug(value)

func _target_selection_radius() -> float:
	if scenario != null:
		if scenario.target_type == ScenarioConfig.TARGET_LORRY:
			return 4.4
		if scenario.target_type == ScenarioConfig.TARGET_MOTORCYCLE:
			return 1.5
	return super._target_selection_radius()

func _capture_replay_frame(force: bool) -> void:
	var target_model: StructuralModel = null
	var target_metrics: Dictionary = {}
	if m17_lorry != null and is_instance_valid(m17_lorry):
		target_model = m17_lorry.model
		target_metrics = _m17_lorry_metrics()
	elif m17_motorcycle != null and is_instance_valid(m17_motorcycle):
		target_model = m17_motorcycle.model
		target_metrics = _m17_motorcycle_metrics()
	else:
		super._capture_replay_frame(force)
		return
	if car == null or car.model == null:
		return
	var context := _current_replay_context()
	var time_s := _simulation_elapsed_s()
	if force:
		replay_recorder.force_final(time_s, car.model, target_model, _passenger_car_metrics(car), target_metrics, context, car.replay_visual_state(), {})
	else:
		replay_recorder.capture(time_s, car.model, target_model, _passenger_car_metrics(car), target_metrics, context, car.replay_visual_state(), {})

func _apply_replay_time(time_s: float, from_playback: bool) -> void:
	super._apply_replay_time(time_s, from_playback)
	if replay_recorder == null or replay_recorder.recording == null:
		return
	var frame := replay_recorder.recording.frame_at_time(replay_time_s)
	if frame.is_empty():
		return
	var target_state: Variant = frame.get("target_state", {})
	if target_state is Dictionary:
		if m17_lorry != null and m17_lorry.model != null:
			StructuralSnapshot.apply(m17_lorry.model, target_state)
			m17_lorry.step_external(0.0)
		elif m17_motorcycle != null and m17_motorcycle.model != null:
			StructuralSnapshot.apply(m17_motorcycle.model, target_state)
			m17_motorcycle.step_external(0.0)

func _m161_target_center() -> Vector3:
	if m17_lorry != null and is_instance_valid(m17_lorry) and m17_lorry.model != null:
		return m17_lorry.model.center_of_mass_m()
	if m17_motorcycle != null and is_instance_valid(m17_motorcycle) and m17_motorcycle.model != null:
		return m17_motorcycle.model.center_of_mass_m()
	return super._m161_target_center()

func _m17_lorry_metrics() -> Dictionary:
	if m17_lorry == null:
		return {}
	var velocity := m17_lorry.global_linear_velocity_ms()
	return {
		"mass_kg": m17_lorry.total_mass_kg,
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": m17_lorry.global_momentum_kg_ms(),
		"kinetic_energy_j": m17_lorry.global_kinetic_energy_j(),
		"broken_beams": 0,
		"plastic_energy_j": 0.0,
		"elastic_energy_j": 0.0,
	}

func _m17_motorcycle_metrics() -> Dictionary:
	if m17_motorcycle == null:
		return {}
	var velocity := m17_motorcycle.global_linear_velocity_ms()
	return {
		"mass_kg": m17_motorcycle.total_mass_kg,
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": m17_motorcycle.global_momentum_kg_ms(),
		"kinetic_energy_j": m17_motorcycle.global_kinetic_energy_j(),
		"broken_beams": 0,
		"plastic_energy_j": 0.0,
		"elastic_energy_j": 0.0,
	}

func _truck_metrics(vehicle: HeavyTruck) -> Dictionary:
	var result := super._truck_metrics(vehicle)
	if vehicle is M17HeavyTruck:
		var m17_truck := vehicle as M17HeavyTruck
		result["rear_crush_m"] = m17_truck.hybrid_rear_crush_m
		result["front_crush_m"] = m17_truck.hybrid_front_crush_m
	return result

func _refresh_analysis_overlay() -> void:
	if m17_lorry == null and m17_motorcycle == null:
		super._refresh_analysis_overlay()
		return
	if analysis_overlay == null or car == null or car.model == null:
		return
	var target_model: StructuralModel = m17_lorry.model if m17_lorry != null else m17_motorcycle.model
	analysis_overlay.configure(car.model, target_model)
	analysis_overlay.set_enabled(vectors_check == null or vectors_check.button_pressed)

func _update_metrics() -> void:
	super._update_metrics()
	if metrics_label == null:
		return
	if m17_lorry != null:
		metrics_label.text += "\nRigid lorry target • %.1f km/h • Godot RigidBody3D production motion" % PhysicsMetrics.ms_to_kmh(m17_lorry.global_linear_velocity_ms().length())
	elif m17_motorcycle != null:
		metrics_label.text += "\nRiderless motorcycle target • %.1f km/h • Godot RigidBody3D production motion" % PhysicsMetrics.ms_to_kmh(m17_motorcycle.global_linear_velocity_ms().length())
	elif truck is M17HeavyTruck:
		var m17_truck := truck as M17HeavyTruck
		metrics_label.text += "\nTruck local collapse • rear %.0f mm • front %.0f mm" % [m17_truck.hybrid_rear_crush_m * 1000.0, m17_truck.hybrid_front_crush_m * 1000.0]
	if car is M17CompactHatchback:
		var m17_car := car as M17CompactHatchback
		if m17_car.hybrid_rear_impact_crush_m > 0.001:
			metrics_label.text += "\nPrimary direct rear-impact crush %.0f mm" % (m17_car.hybrid_rear_impact_crush_m * 1000.0)

# --- Production comparison -------------------------------------------------

func _on_m10_run_comparison() -> void:
	if m17_comparison_running:
		return
	var selected_mode := StringName(String(m10_compare_mode.get_item_metadata(m10_compare_mode.selected)))
	if selected_mode == &"lab":
		if comparison_lab_panel != null:
			comparison_lab_panel.visible = true
		return
	comparison_mode = MODE_CLASS if selected_mode == MODE_CLASS else MODE_SPEED
	var variants := _m17_main_comparison_variants(comparison_mode)
	await _m17_run_production_comparison(variants)

func _on_run_comparison_pressed() -> void:
	if m17_comparison_running:
		return
	var variants := _m17_main_comparison_variants(comparison_mode)
	await _m17_run_production_comparison(variants)

func _on_run_matrix_comparison() -> void:
	if m17_comparison_running:
		return
	var variants := _m17_matrix_comparison_variants()
	if variants.is_empty():
		status_label.text = "Comparison Lab needs at least one type and one speed"
		return
	if comparison_lab_panel != null:
		comparison_lab_panel.visible = false
	comparison_mode = &"matrix"
	await _m17_run_production_comparison(variants)

func _m17_main_comparison_variants(mode: StringName) -> Array[Dictionary]:
	var variants: Array[Dictionary] = []
	if mode == MODE_CLASS:
		for id in [PassengerCarCatalog.B_SEGMENT_HATCHBACK, PassengerCarCatalog.C_SEGMENT_COMPACT, PassengerCarCatalog.D_SEGMENT_MIDSIZE]:
			var config := ScenarioConfig.from_dictionary(scenario.to_dictionary())
			config.car_preset_id = id
			config.car_mass_kg = PassengerCarCatalog.default_mass_kg(id)
			variants.append({"label": PassengerCarCatalog.display_name(id), "scenario": config})
		return variants
	var speeds: Array[float] = []
	if m10_compare_speed_a != null:
		speeds.append(m10_compare_speed_a.value)
		speeds.append(m10_compare_speed_b.value)
		if m10_compare_use_c == null or m10_compare_use_c.button_pressed:
			speeds.append(m10_compare_speed_c.value)
	else:
		speeds = [50.0, 90.0, 140.0]
	for speed in speeds:
		var config := ScenarioConfig.from_dictionary(scenario.to_dictionary())
		config.car_speed_kmh = speed
		variants.append({"label": "%.0f km/h" % speed, "scenario": config})
	return variants

func _m17_matrix_comparison_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if matrix_mode_option == null:
		return result
	var mode := StringName(String(matrix_mode_option.get_item_metadata(matrix_mode_option.selected)))
	var ids: Array[StringName] = []
	for i in range(matrix_variant_options.size()):
		if i < matrix_variant_checks.size() and not matrix_variant_checks[i].button_pressed:
			continue
		var option := matrix_variant_options[i]
		if option != null and option.selected >= 0:
			ids.append(StringName(String(option.get_item_metadata(option.selected))))
	var speeds: Array[float] = []
	for i in range(matrix_speed_spins.size()):
		if i < matrix_speed_checks.size() and matrix_speed_checks[i].button_pressed:
			speeds.append(matrix_speed_spins[i].value)
	for id in ids:
		for speed in speeds:
			var config := ScenarioConfig.from_dictionary(scenario.to_dictionary())
			var label := ""
			if mode == ComparisonRunner.MATRIX_CAR_CLASSES:
				config.car_preset_id = id
				config.car_mass_kg = PassengerCarCatalog.default_mass_kg(id)
				config.car_speed_kmh = speed
				label = "%s • %.0f km/h" % [PassengerCarCatalog.display_name(id), speed]
			elif mode == ComparisonRunner.MATRIX_TARGET_TYPES:
				config.apply_target_defaults(id)
				config.target_position_m = scenario.target_position_m
				config.target_heading_deg = scenario.target_heading_deg
				config.car_speed_kmh = speed
				label = "%s • %.0f km/h" % [ScenarioConfig.target_display_name(id), speed]
			else:
				if RoadUserCatalog.bicycle_ids().has(id):
					config.apply_target_defaults(ScenarioConfig.TARGET_BICYCLE)
				else:
					config.apply_target_defaults(ScenarioConfig.TARGET_PEDESTRIAN)
				config.target_preset_id = id
				config.target_mass_kg = RoadUserCatalog.default_mass_kg(id)
				config.target_position_m = scenario.target_position_m
				config.target_heading_deg = scenario.target_heading_deg
				config.car_speed_kmh = speed
				label = "%s • %.0f km/h" % [RoadUserCatalog.display_name(id), speed]
			result.append({"label": label, "scenario": config})
	return result

func _m17_run_production_comparison(variants: Array[Dictionary]) -> void:
	if variants.is_empty():
		status_label.text = "Comparison has no variants"
		return
	m17_comparison_running = true
	_stop_replay()
	comparison_playing = false
	if m10_compare_run != null:
		m10_compare_run.disabled = true
		m10_compare_run.text = "Running production physics…"
	if comparison_run_button != null:
		comparison_run_button.disabled = true
		comparison_run_button.text = "Running production physics…"
	comparison_results.clear()

	var failure := ""
	for batch_start in range(0, variants.size(), M17_COMPARISON_BATCH_SIZE):
		var batch_end := mini(batch_start + M17_COMPARISON_BATCH_SIZE, variants.size())
		var contexts: Array[Dictionary] = []
		for index in range(batch_start, batch_end):
			var raw_config: ScenarioConfig = variants[index].get("scenario") as ScenarioConfig
			if raw_config == null:
				failure = "Variant %d has no scenario" % (index + 1)
				break
			var errors := raw_config.validation_errors()
			if not errors.is_empty():
				failure = "%s: %s" % [String(variants[index].get("label", "Variant")), "; ".join(errors)]
				break
			var context := await _m17_create_comparison_context(raw_config, String(variants[index].get("label", "Variant")))
			if context.is_empty():
				failure = "Could not create isolated production world"
				break
			contexts.append(context)
		if not failure.is_empty():
			_m17_cleanup_comparison_contexts(contexts)
			break

		for context in contexts:
			var editor: Node = context.get("editor")
			editor.call("_on_simulate_pressed")
			if not bool(editor.get("simulation_running")):
				var nested_status := editor.get("status_label") as Label
				failure = nested_status.text if nested_status != null else "Production variant did not start"
				break
		if not failure.is_empty():
			_m17_cleanup_comparison_contexts(contexts)
			break

		var maximum_frames := 0
		for context in contexts:
			var config: ScenarioConfig = context.get("scenario")
			maximum_frames = maxi(maximum_frames, int(ceil(config.duration_s * 260.0)) + 480)
		var completed := false
		for _frame in range(maximum_frames):
			completed = true
			for context in contexts:
				var editor: Node = context.get("editor")
				if bool(editor.get("simulation_running")):
					completed = false
					break
			if completed:
				break
			await get_tree().physics_frame
		if not completed:
			failure = "Production comparison exceeded its bounded simulation window"
			_m17_cleanup_comparison_contexts(contexts)
			break
		for _frame in range(3):
			await get_tree().process_frame

		for context in contexts:
			var editor: Node = context.get("editor")
			var recorder: ReplayRecorder = editor.get("replay_recorder") as ReplayRecorder
			var analysis: Dictionary = editor.get("analysis_report")
			if recorder == null or recorder.recording == null or not recorder.recording.has_frames() or analysis.is_empty():
				failure = "%s produced no production replay/analysis" % String(context.get("label", "Variant"))
				break
			comparison_results.append({
				"label": String(context.get("label", "Variant")),
				"scenario": ScenarioConfig.from_dictionary((context.get("scenario") as ScenarioConfig).to_dictionary()),
				"recording": recorder.recording,
				"analysis": analysis.duplicate(true),
				"error": "",
			})
		_m17_cleanup_comparison_contexts(contexts)
		if not failure.is_empty():
			break

	if m10_compare_run != null:
		m10_compare_run.disabled = false
		m10_compare_run.text = "Run comparison"
	if comparison_run_button != null:
		comparison_run_button.disabled = false
		comparison_run_button.text = "Run comparison"
	m17_comparison_running = false

	if not failure.is_empty():
		comparison_results.clear()
		status_label.text = "Comparison failed: %s" % failure
		return
	if comparison_results.is_empty():
		status_label.text = "Comparison produced no results"
		return
	_enter_comparison_mode()
	m10_mode = MODE_COMPARE
	_build_m10_comparison_cards()
	_refresh_m10_mode()
	status_label.text = "Production comparison ready"

func _m17_create_comparison_context(config: ScenarioConfig, label: String) -> Dictionary:
	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		return {}
	var viewport := SubViewport.new()
	viewport.name = "M17ComparisonWorld"
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var cloned := ScenarioConfig.from_dictionary(config.to_dictionary())
	editor.set("scenario", cloned)
	viewport.add_child(editor)
	for _frame in range(4):
		await get_tree().process_frame
	return {"viewport": viewport, "editor": editor, "scenario": cloned, "label": label}

func _m17_cleanup_comparison_contexts(contexts: Array[Dictionary]) -> void:
	for context in contexts:
		var viewport: SubViewport = context.get("viewport") as SubViewport
		if viewport != null and is_instance_valid(viewport):
			if viewport.get_parent() == self:
				remove_child(viewport)
			viewport.queue_free()
