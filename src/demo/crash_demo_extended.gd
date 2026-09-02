# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m8.gd"

var bicycle: Bicycle
var pedestrian: Pedestrian
var target_preset_option: OptionButton

var comparison_lab_canvas: CanvasLayer
var comparison_lab_panel: PanelContainer
var matrix_mode_option: OptionButton
var matrix_variant_options: Array[OptionButton] = []
var matrix_variant_checks: Array[CheckButton] = []
var matrix_speed_spins: Array[SpinBox] = []
var matrix_speed_checks: Array[CheckButton] = []

func _ready() -> void:
	super._ready()
	_build_comparison_lab_ui()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if bicycle != null:
		bicycle.step_external(0.0)
	if pedestrian != null:
		if pair_simulation != null and pair_simulation.contact.contact_events > 0 and not PedestrianBuilder.stance_released(pedestrian.model):
			PedestrianBuilder.release_stance(pedestrian.model)
		pedestrian.step_external(0.0)

func _set_base_ui_visible(value: bool) -> void:
	super._set_base_ui_visible(value)
	if comparison_lab_canvas != null:
		comparison_lab_canvas.visible = value

func _is_road_user_target() -> bool:
	return scenario.target_type == ScenarioConfig.TARGET_BICYCLE or scenario.target_type == ScenarioConfig.TARGET_PEDESTRIAN

func _rebuild_inspector() -> void:
	if selected_object != &"target" or not _is_road_user_target():
		super._rebuild_inspector()
		return
	for child in inspector_column.get_children():
		inspector_column.remove_child(child)
		child.queue_free()
	var inspector_title := Label.new()
	inspector_title.text = ScenarioConfig.target_display_name(scenario.target_type)
	inspector_title.add_theme_font_size_override("font_size", 18)
	inspector_column.add_child(inspector_title)

	var preset_row := HBoxContainer.new()
	inspector_column.add_child(preset_row)
	var preset_label := Label.new()
	preset_label.text = "Type"
	preset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(preset_label)
	target_preset_option = OptionButton.new()
	var ids := RoadUserCatalog.bicycle_ids() if scenario.target_type == ScenarioConfig.TARGET_BICYCLE else RoadUserCatalog.pedestrian_ids()
	for id in ids:
		target_preset_option.add_item(RoadUserCatalog.display_name(id))
		target_preset_option.set_item_metadata(target_preset_option.item_count - 1, id)
	target_preset_option.item_selected.connect(_on_target_preset_selected)
	preset_row.add_child(target_preset_option)

	if scenario.target_type == ScenarioConfig.TARGET_BICYCLE:
		mass_spin = _add_spin(inspector_column, "Mass (kg)", 5.0, 60.0, 1.0)
		speed_spin = _add_spin(inspector_column, "Speed (km/h)", 0.0, 80.0, 1.0)
	else:
		mass_spin = _add_spin(inspector_column, "Body mass (kg)", 15.0, 200.0, 1.0)
		speed_spin = null
	mass_spin.value_changed.connect(_on_object_spin_changed.bind(&"mass"))
	if speed_spin != null:
		speed_spin.value_changed.connect(_on_object_spin_changed.bind(&"speed"))

	x_spin = _add_spin(inspector_column, "Position X (m)", -25.0, 25.0, 0.1)
	z_spin = _add_spin(inspector_column, "Position Z (m)", -5.0, 5.0, 0.1)
	heading_spin = _add_spin(inspector_column, "Heading (deg)", -180.0, 180.0, 1.0)
	x_spin.value_changed.connect(_on_object_spin_changed.bind(&"x"))
	z_spin.value_changed.connect(_on_object_spin_changed.bind(&"z"))
	heading_spin.value_changed.connect(_on_object_spin_changed.bind(&"heading"))

	var rotate_row := HBoxContainer.new()
	inspector_column.add_child(rotate_row)
	var rotate_left := Button.new()
	rotate_left.text = "Rotate -5°"
	rotate_left.pressed.connect(_rotate_selected.bind(-5.0))
	rotate_row.add_child(rotate_left)
	var rotate_right := Button.new()
	rotate_right.text = "Rotate +5°"
	rotate_right.pressed.connect(_rotate_selected.bind(5.0))
	rotate_row.add_child(rotate_right)

	var note := Label.new()
	if scenario.target_type == ScenarioConfig.TARGET_PEDESTRIAN:
		note.text = "Adult is the ready-to-run default. Change body type or mass only when needed. This is an articulated contact/trajectory proxy, not an injury model."
	else:
		note.text = "City bicycle is the ready-to-run default. Change bicycle type or mass only when needed. The bicycle is riderless in the current model."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_column.add_child(note)
	_sync_current_object_fields()

func _sync_current_object_fields() -> void:
	if selected_object != &"target" or not _is_road_user_target():
		super._sync_current_object_fields()
		return
	syncing_ui = true
	if target_preset_option != null:
		for i in range(target_preset_option.item_count):
			if StringName(String(target_preset_option.get_item_metadata(i))) == scenario.target_preset_id:
				target_preset_option.select(i)
				break
	if mass_spin != null:
		mass_spin.value = scenario.target_mass_kg
	if speed_spin != null:
		speed_spin.value = scenario.target_speed_kmh
	if x_spin != null:
		x_spin.value = scenario.target_position_m.x
	if z_spin != null:
		z_spin.value = scenario.target_position_m.z
	if heading_spin != null:
		heading_spin.value = scenario.target_heading_deg
	syncing_ui = false

func _on_target_preset_selected(index: int) -> void:
	if syncing_ui or target_preset_option == null or index < 0 or index >= target_preset_option.item_count:
		return
	var id := StringName(String(target_preset_option.get_item_metadata(index)))
	scenario.target_preset_id = id
	scenario.target_mass_kg = RoadUserCatalog.default_mass_kg(id)
	_sync_current_object_fields()
	_request_preview_rebuild()

func _on_target_palette_pressed(target_id: StringName) -> void:
	if target_id != ScenarioConfig.TARGET_BICYCLE and target_id != ScenarioConfig.TARGET_PEDESTRIAN:
		super._on_target_palette_pressed(target_id)
		return
	selected_object = &"target"
	if scenario.target_type != target_id:
		scenario.apply_target_defaults(target_id)
		_request_preview_rebuild()
	_rebuild_inspector()

func _rebuild_preview() -> void:
	super._rebuild_preview()
	if not _is_road_user_target():
		return
	if obstacle != null and is_instance_valid(obstacle):
		remove_child(obstacle)
		obstacle.queue_free()
	obstacle = null
	static_simulation = null
	pair_simulation = VehiclePairSimulation.new()
	if scenario.target_type == ScenarioConfig.TARGET_BICYCLE:
		bicycle = Bicycle.new()
		bicycle.name = "Bicycle"
		bicycle.bicycle_preset_id = scenario.target_preset_id
		bicycle.total_mass_kg = scenario.target_mass_kg
		bicycle.initial_speed_kmh = scenario.target_speed_kmh
		bicycle.origin_offset_m = scenario.target_position_m
		bicycle.heading_deg = scenario.target_heading_deg
		bicycle.auto_step = false
		bicycle.show_structure = scenario.show_structure
		add_child(bicycle)
		var bicycle_contacts := BicycleBuilder.front_contact_nodes() if scenario.target_vehicle_uses_front_contact() else BicycleBuilder.rear_contact_nodes()
		pair_simulation.configure(car.model, PRIMARY_FRONT_CONTACT_NODES, bicycle.model, bicycle_contacts, scenario.car_forward(), scenario.contact_friction, scenario.restitution)
	else:
		pedestrian = Pedestrian.new()
		pedestrian.name = "Pedestrian"
		pedestrian.body_preset_id = scenario.target_preset_id
		pedestrian.total_mass_kg = scenario.target_mass_kg
		pedestrian.origin_offset_m = scenario.target_position_m
		pedestrian.heading_deg = scenario.target_heading_deg
		pedestrian.auto_step = false
		pedestrian.show_structure = scenario.show_structure
		add_child(pedestrian)
		pair_simulation.configure(car.model, PRIMARY_FRONT_CONTACT_NODES, pedestrian.model, PedestrianBuilder.contact_nodes(), scenario.car_forward(), scenario.contact_friction, scenario.restitution)
	status_label.text = "Editable preview — defaults are ready; press Simulate"
	_update_metrics()
	_refresh_analysis_overlay()

func _clear_runtime_objects() -> void:
	for node in [bicycle, pedestrian]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	bicycle = null
	pedestrian = null
	super._clear_runtime_objects()

func _on_structure_toggled(value: bool) -> void:
	super._on_structure_toggled(value)
	if bicycle != null:
		bicycle.set_structure_debug(value)
	if pedestrian != null:
		pedestrian.set_structure_debug(value)

func _target_selection_radius() -> float:
	if scenario.target_type == ScenarioConfig.TARGET_BICYCLE:
		return 1.4
	if scenario.target_type == ScenarioConfig.TARGET_PEDESTRIAN:
		return 1.2
	return super._target_selection_radius()

func _move_selected(delta_m: Vector3) -> void:
	if selected_object != &"target" or not _is_road_user_target():
		super._move_selected(delta_m)
		return
	if delta_m.is_zero_approx():
		return
	scenario.target_position_m += delta_m
	if bicycle != null:
		bicycle.model.translate_all_nodes(delta_m)
		bicycle.origin_offset_m = scenario.target_position_m
		bicycle.step_external(0.0)
	elif pedestrian != null:
		pedestrian.model.translate_all_nodes(delta_m)
		pedestrian.origin_offset_m = scenario.target_position_m
		pedestrian.step_external(0.0)
	_sync_current_object_fields()

func _rotate_selected(delta_deg: float) -> void:
	if selected_object != &"target" or not _is_road_user_target():
		super._rotate_selected(delta_deg)
		return
	if is_zero_approx(delta_deg):
		return
	scenario.target_heading_deg = wrapf(scenario.target_heading_deg + delta_deg, -180.0, 180.0)
	if bicycle != null:
		bicycle.model.rotate_y_about(scenario.target_position_m, deg_to_rad(delta_deg), true)
		bicycle.heading_deg = scenario.target_heading_deg
		bicycle.step_external(0.0)
	elif pedestrian != null:
		pedestrian.model.rotate_y_about(scenario.target_position_m, deg_to_rad(delta_deg), true)
		pedestrian.heading_deg = scenario.target_heading_deg
		pedestrian.step_external(0.0)
	_sync_current_object_fields()
	_request_preview_rebuild()

func _capture_replay_frame(force: bool) -> void:
	if not _is_road_user_target():
		super._capture_replay_frame(force)
		return
	if car == null or car.model == null:
		return
	var target_model: StructuralModel = bicycle.model if bicycle != null else pedestrian.model
	var target_metrics := _road_user_metrics(target_model)
	var context := _current_replay_context()
	var time_s := _simulation_elapsed_s()
	if force:
		replay_recorder.force_final(time_s, car.model, target_model, _passenger_car_metrics(car), target_metrics, context, car.replay_visual_state(), {})
	else:
		replay_recorder.capture(time_s, car.model, target_model, _passenger_car_metrics(car), target_metrics, context, car.replay_visual_state(), {})

func _road_user_metrics(model: StructuralModel) -> Dictionary:
	if model == null:
		return {}
	var velocity := model.average_velocity_ms()
	var result := {
		"mass_kg": model.total_mass_kg(),
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": model.total_momentum_kg_ms(),
		"kinetic_energy_j": model.total_kinetic_energy_j(),
		"broken_beams": model.broken_beam_count(),
		"plastic_energy_j": model.total_plastic_energy_j(),
		"elastic_energy_j": model.total_elastic_energy_j(),
	}
	if scenario.target_type == ScenarioConfig.TARGET_BICYCLE:
		result["frame_deformation_m"] = model.max_permanent_deformation_for_role(&"bicycle_frame")
	else:
		result["body_deformation_m"] = model.max_permanent_deformation_m()
	return result

func _apply_replay_time(time_s: float, from_playback: bool) -> void:
	if not _is_road_user_target():
		super._apply_replay_time(time_s, from_playback)
		return
	var recording := replay_recorder.recording
	if recording == null or not recording.has_frames():
		return
	replay_time_s = clampf(time_s, 0.0, recording.duration_s)
	var frame := recording.frame_at_time(replay_time_s)
	if frame.is_empty() or car == null or car.model == null:
		return
	var primary_state: Variant = frame.get("primary_state", {})
	if primary_state is Dictionary:
		StructuralSnapshot.apply(car.model, primary_state)
	var primary_visual: Variant = frame.get("primary_visual_state", {})
	car.apply_replay_visual_state(primary_visual if primary_visual is Dictionary else {})
	var target_state: Variant = frame.get("target_state", {})
	if target_state is Dictionary:
		if bicycle != null:
			StructuralSnapshot.apply(bicycle.model, target_state)
			bicycle.step_external(0.0)
		elif pedestrian != null:
			StructuralSnapshot.apply(pedestrian.model, target_state)
			pedestrian.step_external(0.0)
	if analysis_overlay != null:
		analysis_overlay.update_from_models()
	syncing_replay_ui = true
	timeline_slider.value = replay_time_s
	syncing_replay_ui = false
	_update_replay_time_label()
	if not from_playback:
		status_label.text = "Recorded replay scrubbed to %.2f s" % replay_time_s

func _refresh_analysis_overlay() -> void:
	if not _is_road_user_target():
		super._refresh_analysis_overlay()
		return
	if analysis_overlay == null or car == null or car.model == null:
		return
	var target_model: StructuralModel = bicycle.model if bicycle != null else (pedestrian.model if pedestrian != null else null)
	analysis_overlay.configure(car.model, target_model)
	analysis_overlay.set_enabled(vectors_check == null or vectors_check.button_pressed)

func _update_metrics() -> void:
	if not _is_road_user_target():
		super._update_metrics()
		return
	if metrics_label == null or car == null or car.model == null:
		return
	var target_model: StructuralModel = bicycle.model if bicycle != null else (pedestrian.model if pedestrian != null else null)
	var target_speed := 0.0 if target_model == null else PhysicsMetrics.ms_to_kmh(target_model.average_velocity_ms().length())
	var contact_count := pair_simulation.contact.contact_events if pair_simulation != null else 0
	var energy_error := pair_simulation.energy_balance_relative_error() * 100.0 if pair_simulation != null else 0.0
	var target_detail := ""
	if bicycle != null:
		target_detail = "bicycle frame deformation %.0f mm" % (bicycle.frame_deformation_m() * 1000.0)
	elif pedestrian != null:
		target_detail = "trajectory speed %.1f km/h • articulated deformation %.0f mm" % [target_speed, pedestrian.body_deformation_m() * 1000.0]
	metrics_label.text = "%s • %.0f kg • %.1f km/h\n%s • %.0f kg • %.1f km/h • contacts %d • energy diagnostic %.2f%s\n%s" % [
		car.vehicle_class_name(), car.model.total_mass_kg(), PhysicsMetrics.ms_to_kmh(car.global_linear_velocity_ms().length()),
		ScenarioConfig.target_display_name(scenario.target_type), scenario.target_mass_kg, target_speed, contact_count, energy_error, "%", target_detail,
	]

func _build_comparison_lab_ui() -> void:
	comparison_lab_canvas = CanvasLayer.new()
	comparison_lab_canvas.name = "RoadUserComparisonLabUI"
	comparison_lab_canvas.layer = 7
	add_child(comparison_lab_canvas)

	var launch := PanelContainer.new()
	launch.anchor_left = 1.0
	launch.anchor_right = 1.0
	launch.offset_left = -340.0
	launch.offset_top = 312.0
	launch.offset_right = -10.0
	launch.offset_bottom = 386.0
	comparison_lab_canvas.add_child(launch)
	var launch_margin := MarginContainer.new()
	launch_margin.add_theme_constant_override("margin_left", 8)
	launch_margin.add_theme_constant_override("margin_top", 7)
	launch_margin.add_theme_constant_override("margin_right", 8)
	launch_margin.add_theme_constant_override("margin_bottom", 7)
	launch.add_child(launch_margin)
	var launch_row := HBoxContainer.new()
	launch_row.add_theme_constant_override("separation", 7)
	launch_margin.add_child(launch_row)
	var launch_button := Button.new()
	launch_button.name = "ComparisonLabButton"
	launch_button.text = "Comparison Lab"
	launch_button.pressed.connect(func() -> void: comparison_lab_panel.visible = true)
	launch_row.add_child(launch_button)
	var launch_label := Label.new()
	launch_label.text = "types × custom speeds"
	launch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch_row.add_child(launch_label)

	comparison_lab_panel = PanelContainer.new()
	comparison_lab_panel.anchor_left = 0.5
	comparison_lab_panel.anchor_right = 0.5
	comparison_lab_panel.offset_left = -390.0
	comparison_lab_panel.offset_top = 90.0
	comparison_lab_panel.offset_right = 390.0
	comparison_lab_panel.offset_bottom = 630.0
	comparison_lab_panel.visible = false
	comparison_lab_canvas.add_child(comparison_lab_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	comparison_lab_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "Comparison Lab"
	heading.add_theme_font_size_override("font_size", 22)
	column.add_child(heading)
	var intro := Label.new()
	intro.text = "Pick up to three types and up to three speeds. CrashVector runs every combination in one batch and shows the results on the same synchronized replay clock. Defaults are ready to use."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)

	matrix_mode_option = OptionButton.new()
	matrix_mode_option.add_item("Vehicle classes × speeds")
	matrix_mode_option.set_item_metadata(0, ComparisonRunner.MATRIX_CAR_CLASSES)
	matrix_mode_option.add_item("Impact-target types × speeds")
	matrix_mode_option.set_item_metadata(1, ComparisonRunner.MATRIX_TARGET_TYPES)
	matrix_mode_option.add_item("Pedestrian / bicycle types × speeds")
	matrix_mode_option.set_item_metadata(2, ComparisonRunner.MATRIX_BODY_PRESETS)
	matrix_mode_option.item_selected.connect(_on_matrix_mode_selected)
	column.add_child(matrix_mode_option)

	var variants_title := Label.new()
	variants_title.text = "Types"
	variants_title.add_theme_font_size_override("font_size", 16)
	column.add_child(variants_title)
	for _i in range(3):
		var row := HBoxContainer.new()
		column.add_child(row)
		var check := CheckButton.new()
		check.text = "Use"
		check.button_pressed = true
		row.add_child(check)
		matrix_variant_checks.append(check)
		var option := OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(option)
		matrix_variant_options.append(option)

	var speeds_title := Label.new()
	speeds_title.text = "Impact speeds"
	speeds_title.add_theme_font_size_override("font_size", 16)
	column.add_child(speeds_title)
	var speed_defaults: Array[float] = [50.0, 90.0, 140.0]
	for i in range(3):
		var row := HBoxContainer.new()
		column.add_child(row)
		var check := CheckButton.new()
		check.text = "Use"
		check.button_pressed = true
		row.add_child(check)
		matrix_speed_checks.append(check)
		var label := Label.new()
		label.text = "Speed %d" % (i + 1)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0.0
		spin.max_value = 300.0
		spin.step = 1.0
		spin.value = speed_defaults[i]
		spin.suffix = " km/h"
		spin.custom_minimum_size.x = 150.0
		row.add_child(spin)
		matrix_speed_spins.append(spin)

	var example := Label.new()
	example.text = "Example: set Speed 1 = 130, Speed 2 = 140 and switch off Speed 3 to compare only 130 vs 140 km/h."
	example.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(example)
	var caution := Label.new()
	caution.text = "Road-user results are trajectory/contact visualisations only. They do not predict injury probability or medical outcome."
	caution.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caution)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var close := Button.new()
	close.text = "Cancel"
	close.pressed.connect(func() -> void: comparison_lab_panel.visible = false)
	buttons.add_child(close)
	var run := Button.new()
	run.name = "RunMatrixComparisonButton"
	run.text = "Run all combinations"
	run.pressed.connect(_on_run_matrix_comparison)
	buttons.add_child(run)
	_refresh_matrix_variant_choices()

func _on_matrix_mode_selected(_index: int) -> void:
	_refresh_matrix_variant_choices()

func _refresh_matrix_variant_choices() -> void:
	if matrix_mode_option == null:
		return
	var mode := StringName(String(matrix_mode_option.get_item_metadata(matrix_mode_option.selected)))
	var ids: Array[StringName] = []
	var defaults: Array[StringName] = []
	match mode:
		ComparisonRunner.MATRIX_CAR_CLASSES:
			ids = PassengerCarCatalog.preset_ids()
			defaults = [PassengerCarCatalog.B_SEGMENT_HATCHBACK, PassengerCarCatalog.C_SEGMENT_COMPACT, PassengerCarCatalog.D_SEGMENT_MIDSIZE]
		ComparisonRunner.MATRIX_TARGET_TYPES:
			ids = ScenarioConfig.target_ids()
			defaults = [ScenarioConfig.TARGET_PASSENGER_CAR, ScenarioConfig.TARGET_WALL, ScenarioConfig.TARGET_PEDESTRIAN]
		_:
			ids = RoadUserCatalog.pedestrian_ids()
			ids.append_array(RoadUserCatalog.bicycle_ids())
			defaults = [RoadUserCatalog.PEDESTRIAN_ADULT, RoadUserCatalog.PEDESTRIAN_CHILD, RoadUserCatalog.BICYCLE_CITY]
	for i in range(matrix_variant_options.size()):
		var option := matrix_variant_options[i]
		option.clear()
		for id in ids:
			var text := RoadUserCatalog.display_name(id)
			if mode == ComparisonRunner.MATRIX_TARGET_TYPES:
				text = ScenarioConfig.target_display_name(id)
			elif mode == ComparisonRunner.MATRIX_CAR_CLASSES:
				text = PassengerCarCatalog.display_name(id)
			option.add_item(text)
			option.set_item_metadata(option.item_count - 1, id)
		var wanted := defaults[mini(i, defaults.size() - 1)]
		option.select(maxi(ids.find(wanted), 0))

func _on_run_matrix_comparison() -> void:
	var mode := StringName(String(matrix_mode_option.get_item_metadata(matrix_mode_option.selected)))
	var variants: Array[StringName] = []
	for i in range(matrix_variant_options.size()):
		if not matrix_variant_checks[i].button_pressed:
			continue
		var option := matrix_variant_options[i]
		variants.append(StringName(String(option.get_item_metadata(option.selected))))
	var speeds: Array[float] = []
	for i in range(matrix_speed_spins.size()):
		if matrix_speed_checks[i].button_pressed:
			speeds.append(matrix_speed_spins[i].value)
	if variants.is_empty() or speeds.is_empty():
		status_label.text = "Comparison Lab needs at least one type and one speed"
		return
	_stop_replay()
	comparison_playing = false
	comparison_mode = &"matrix"
	comparison_results = ComparisonRunner.run_matrix(scenario, mode, variants, speeds)
	if comparison_results.is_empty():
		status_label.text = "Comparison Lab produced no valid combinations"
		return
	for result in comparison_results:
		var error_text := String(result.get("error", ""))
		if not error_text.is_empty():
			status_label.text = "Comparison failed: %s" % error_text
			comparison_results.clear()
			return
	comparison_lab_panel.visible = false
	_enter_comparison_mode()

func _enter_comparison_mode() -> void:
	if comparison_results.size() <= 3:
		super._enter_comparison_mode()
		return
	comparison_active = true
	comparison_playing = false
	_clear_runtime_objects()
	if analysis_overlay != null:
		analysis_overlay.set_enabled(false)
	_set_base_ui_visible(false)
	_clear_comparison_lanes()
	_ensure_matrix_paints(comparison_results.size())
	for i in range(comparison_results.size()):
		var lane := ComparisonLane3D.new()
		lane.name = "ComparisonLane%d" % i
		add_child(lane)
		lane.configure(comparison_results[i], _comparison_offset(i, comparison_results.size()), comparison_paint_ids[i])
		comparison_lanes.append(lane)
	_build_comparison_cards()
	comparison_results_panel.visible = true
	comparison_results_panel.offset_top = -340.0
	comparison_play_button.disabled = false
	comparison_exit_button.disabled = false
	comparison_timeline.editable = true
	_configure_comparison_timeline(true)
	_frame_comparison()

func _ensure_matrix_paints(count: int) -> void:
	var paints := CarPaintCatalog.ids()
	if paints.is_empty():
		return
	while comparison_paint_ids.size() < count:
		comparison_paint_ids.append(paints[comparison_paint_ids.size() % paints.size()])

func _comparison_offset(index: int, count: int) -> Vector3:
	var columns := 3
	var rows := int(ceil(float(count) / float(columns)))
	var col := index % columns
	var row := int(floor(float(index) / float(columns)))
	return Vector3((float(col) - 1.0) * 18.0, 0.0, (float(row) - float(rows - 1) * 0.5) * 8.5)

func _build_comparison_cards() -> void:
	if comparison_results.size() <= 3:
		super._build_comparison_cards()
		return
	for child in comparison_cards.get_children():
		comparison_cards.remove_child(child)
		child.queue_free()
	var columns := 3
	var buckets: Array[VBoxContainer] = []
	for _i in range(columns):
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		comparison_cards.add_child(column)
		buckets.append(column)
	for i in range(comparison_results.size()):
		buckets[i % columns].add_child(_make_compact_matrix_card(comparison_results[i]))

func _make_compact_matrix_card(result: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var label := Label.new()
	label.text = String(result.get("label", "Variant"))
	label.add_theme_font_size_override("font_size", 14)
	column.add_child(label)
	var analysis: Dictionary = result.get("analysis", {})
	var metrics := Label.new()
	metrics.text = "Δv %.1f km/h • peak %.1f g • crush %.0f mm • KE %.0f kJ" % [
		float(analysis.get("final_delta_v_kmh", 0.0)),
		float(analysis.get("peak_deceleration_g", 0.0)),
		float(analysis.get("max_front_crush_mm", 0.0)),
		float(analysis.get("initial_kinetic_energy_kj", 0.0)),
	]
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(metrics)
	return panel

func _frame_comparison() -> void:
	if comparison_results.size() <= 3:
		super._frame_comparison()
		return
	if camera == null:
		return
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5
	camera.position = Vector3(midpoint.x - 2.0, 26.0, midpoint.z + 42.0)
	camera.look_at(midpoint + Vector3(0.0, 1.0, 0.0), Vector3.UP)
