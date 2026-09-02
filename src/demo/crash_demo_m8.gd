# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m7.gd"

var calibration_canvas: CanvasLayer
var calibration_launch_panel: PanelContainer
var calibration_scope_label: Label
var calibration_panel: PanelContainer
var calibration_result_label: Label
var calibration_run_button: Button

var lorry: RigidLorry
var motorcycle: Motorcycle

var custom_speed_panel: PanelContainer
var comparison_speed_a: SpinBox
var comparison_speed_b: SpinBox
var comparison_speed_c: SpinBox
var comparison_use_third_speed: CheckButton

func _ready() -> void:
	super._ready()
	_build_m8_ui()
	_build_custom_speed_ui()
	if comparison_mode_option != null:
		comparison_mode_option.set_item_text(0, "Custom speeds")
		comparison_mode_option.set_item_text(1, "B / C / D core classes")
	_refresh_calibration_scope()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if lorry != null:
		lorry.step_external(delta)
	if motorcycle != null:
		motorcycle.step_external(delta)

func _request_preview_rebuild() -> void:
	super._request_preview_rebuild()
	_refresh_calibration_scope()

func _set_base_ui_visible(value: bool) -> void:
	super._set_base_ui_visible(value)
	if calibration_canvas != null:
		calibration_canvas.visible = value
	if custom_speed_panel != null:
		custom_speed_panel.visible = value and comparison_mode == MODE_SPEED and not comparison_active

func _build_m8_ui() -> void:
	calibration_canvas = CanvasLayer.new()
	calibration_canvas.name = "M8CalibrationUI"
	calibration_canvas.layer = 6
	add_child(calibration_canvas)

	calibration_launch_panel = PanelContainer.new()
	calibration_launch_panel.anchor_left = 1.0
	calibration_launch_panel.anchor_right = 1.0
	calibration_launch_panel.offset_left = -340.0
	calibration_launch_panel.offset_top = 222.0
	calibration_launch_panel.offset_right = -10.0
	calibration_launch_panel.offset_bottom = 304.0
	calibration_canvas.add_child(calibration_launch_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	calibration_launch_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)
	var button := Button.new()
	button.name = "CalibrationButton"
	button.text = "Calibration"
	button.pressed.connect(_on_calibration_pressed)
	row.add_child(button)
	calibration_scope_label = Label.new()
	calibration_scope_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calibration_scope_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(calibration_scope_label)

	calibration_panel = PanelContainer.new()
	calibration_panel.anchor_left = 0.5
	calibration_panel.anchor_right = 0.5
	calibration_panel.offset_left = -390.0
	calibration_panel.offset_top = 95.0
	calibration_panel.offset_right = 390.0
	calibration_panel.offset_bottom = 620.0
	calibration_panel.visible = false
	calibration_canvas.add_child(calibration_panel)
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 18)
	panel_margin.add_theme_constant_override("margin_top", 15)
	panel_margin.add_theme_constant_override("margin_right", 18)
	panel_margin.add_theme_constant_override("margin_bottom", 15)
	calibration_panel.add_child(panel_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel_margin.add_child(column)
	var heading := Label.new()
	heading.text = "M8 Calibration & Validation Scope"
	heading.add_theme_font_size_override("font_size", 22)
	column.add_child(heading)
	var explanation := Label.new()
	explanation.text = "CrashVector currently has one directly correlated structural reference: a midsize passenger car in the NHTSA NCAP full-frontal rigid-barrier condition around 56 km/h. Other scenarios are explicitly labelled near-reference, class-scaled, or extrapolated rather than inheriting that validation silently."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(explanation)
	var source := Label.new()
	source.text = "Reference: NHTSA DOT HS 812 237 • laboratory test 7078 • 1,661 kg • 56.5 km/h • published crash-pulse duration about 120 ms."
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(source)
	var caution := Label.new()
	caution.text = "Only the crash-pulse observation is treated as source-correlated. Delta-v, safety-cell proxy and energy limits are CrashVector regression guardrails; the delta-v guardrail explicitly allows model rebound. Published pedal/foot-rest intrusion is not equated to beam deformation."
	caution.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caution)
	var separator := HSeparator.new()
	column.add_child(separator)
	calibration_result_label = Label.new()
	calibration_result_label.text = "Run the built-in reference check to compare source correlation and project regression guardrails."
	calibration_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calibration_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(calibration_result_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: calibration_panel.visible = false)
	buttons.add_child(close)
	calibration_run_button = Button.new()
	calibration_run_button.text = "Run reference check"
	calibration_run_button.pressed.connect(_on_run_calibration_pressed)
	buttons.add_child(calibration_run_button)

func _build_custom_speed_ui() -> void:
	if comparison_canvas == null:
		return
	custom_speed_panel = PanelContainer.new()
	custom_speed_panel.name = "CustomSpeedPanel"
	custom_speed_panel.anchor_left = 0.5
	custom_speed_panel.anchor_right = 0.5
	custom_speed_panel.offset_left = -355.0
	custom_speed_panel.offset_top = 124.0
	custom_speed_panel.offset_right = 355.0
	custom_speed_panel.offset_bottom = 174.0
	comparison_canvas.add_child(custom_speed_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	custom_speed_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)
	var label := Label.new()
	label.text = "Compare speeds (km/h)"
	row.add_child(label)
	comparison_speed_a = _make_compare_speed_spin(50.0)
	comparison_speed_b = _make_compare_speed_spin(90.0)
	comparison_speed_c = _make_compare_speed_spin(140.0)
	row.add_child(comparison_speed_a)
	row.add_child(comparison_speed_b)
	row.add_child(comparison_speed_c)
	comparison_use_third_speed = CheckButton.new()
	comparison_use_third_speed.text = "Use third"
	comparison_use_third_speed.button_pressed = true
	comparison_use_third_speed.toggled.connect(func(value: bool) -> void: comparison_speed_c.editable = value)
	row.add_child(comparison_use_third_speed)
	var hint := Label.new()
	hint.text = "Example: 130 vs 140"
	row.add_child(hint)

func _make_compare_speed_spin(value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 0.0
	spin.max_value = 300.0
	spin.step = 1.0
	spin.value = value
	spin.custom_minimum_size.x = 92.0
	return spin

func _on_comparison_mode_selected(index: int) -> void:
	super._on_comparison_mode_selected(index)
	if custom_speed_panel != null:
		custom_speed_panel.visible = comparison_mode == MODE_SPEED and not comparison_active

func _on_run_comparison_pressed() -> void:
	if comparison_mode != MODE_SPEED:
		super._on_run_comparison_pressed()
		return
	var errors := scenario.validation_errors()
	if not errors.is_empty():
		status_label.text = "Comparison preflight failed: %s" % "; ".join(errors)
		return
	var speeds: Array[float] = [comparison_speed_a.value, comparison_speed_b.value]
	if comparison_use_third_speed.button_pressed:
		speeds.append(comparison_speed_c.value)
	for i in range(speeds.size()):
		for j in range(i + 1, speeds.size()):
			if absf(speeds[i] - speeds[j]) < 0.001:
				status_label.text = "Comparison speeds must be different."
				return
	_stop_replay()
	comparison_playing = false
	comparison_run_button.disabled = true
	comparison_run_button.text = "Calculating…"
	comparison_results = ComparisonRunner.run_speed_sweep(scenario, speeds)
	comparison_run_button.disabled = false
	comparison_run_button.text = "Run comparison"
	for result in comparison_results:
		var error_text := String(result.get("error", ""))
		if not error_text.is_empty():
			status_label.text = "Comparison failed: %s" % error_text
			comparison_results.clear()
			return
	_enter_comparison_mode()

func _enter_comparison_mode() -> void:
	comparison_active = true
	comparison_playing = false
	_clear_runtime_objects()
	if analysis_overlay != null:
		analysis_overlay.set_enabled(false)
	_set_base_ui_visible(false)
	_clear_comparison_lanes()
	_ensure_comparison_paint_defaults()
	var offsets: Array[Vector3] = []
	if comparison_results.size() == 2:
		offsets = [Vector3(0.0, 0.0, -5.2), Vector3(0.0, 0.0, 5.2)]
	else:
		offsets = [Vector3(0.0, 0.0, -8.5), Vector3.ZERO, Vector3(0.0, 0.0, 8.5)]
	for i in range(comparison_results.size()):
		var lane := ComparisonLane3D.new()
		lane.name = "ComparisonLane%d" % i
		add_child(lane)
		lane.configure(comparison_results[i], offsets[i], comparison_paint_ids[i])
		comparison_lanes.append(lane)
	_build_comparison_cards()
	comparison_results_panel.visible = true
	comparison_play_button.disabled = false
	comparison_exit_button.disabled = false
	comparison_timeline.editable = true
	_configure_comparison_timeline(true)
	_frame_comparison()

func _on_calibration_pressed() -> void:
	_refresh_calibration_scope()
	calibration_panel.visible = true

func _refresh_calibration_scope() -> void:
	if calibration_scope_label == null or scenario == null:
		return
	var assessment := CalibrationScope.classify(scenario)
	calibration_scope_label.text = "%s — %s" % [String(assessment.get("label", "Unknown")), String(assessment.get("detail", ""))]

func _on_run_calibration_pressed() -> void:
	calibration_run_button.disabled = true
	calibration_run_button.text = "Running…"
	calibration_result_label.text = "Running deterministic NHTSA reference correlation…"
	var assessment := CalibrationRunner.run_default_reference()
	calibration_run_button.disabled = false
	calibration_run_button.text = "Run reference check"
	if not bool(assessment.get("ok", false)):
		calibration_result_label.text = "Reference check could not run: %s" % String(assessment.get("message", "unknown error"))
		return
	var metrics: Dictionary = assessment.get("metrics", {})
	var lines: Array[String] = []
	lines.append("Result: %s" % ("PASS" if bool(assessment.get("passed", false)) else "OUTSIDE CORRIDOR — development review required"))
	lines.append("Source correlation: %s • project regression: %s" % ["PASS" if bool(assessment.get("source_correlation_passed", false)) else "FAIL", "PASS" if bool(assessment.get("project_regression_passed", false)) else "FAIL"])
	lines.append("Pulse duration: %.0f ms • Δv: %.1f km/h • peak deceleration: %.1f g" % [float(metrics.get("pulse_duration_s", 0.0)) * 1000.0, float(metrics.get("delta_v_kmh", 0.0)), float(metrics.get("peak_deceleration_g", 0.0))])
	lines.append("Front crush proxy: %.0f mm • safety-cell proxy: %.1f mm • energy-balance error: %.1f%s" % [float(metrics.get("front_crush_mm", 0.0)), float(metrics.get("safety_cell_proxy_mm", 0.0)), float(metrics.get("energy_balance_relative_error", 0.0)) * 100.0, "%"])
	for check in assessment.get("checks", []):
		var corridor: Dictionary = check.get("corridor", {})
		var category := "source" if StringName(String(check.get("category", ""))) == &"source_correlation" else "project"
		lines.append("[%s] %s: %s (%.3f; %.3f–%.3f %s)" % [category, String(check.get("name", "Metric")), "PASS" if bool(check.get("passed", false)) else "FAIL", float(check.get("value", 0.0)), float(corridor.get("min", 0.0)), float(corridor.get("max", 0.0)), String(check.get("unit", ""))])
	lines.append("Limited structural correlation only — not certification, manufacturer crash performance, rider/occupant injury, or star-rating prediction.")
	calibration_result_label.text = "\n".join(lines)

func _on_target_palette_pressed(target_id: StringName) -> void:
	if target_id != ScenarioConfig.TARGET_LORRY and target_id != ScenarioConfig.TARGET_MOTORCYCLE:
		super._on_target_palette_pressed(target_id)
		return
	selected_object = &"target"
	scenario.target_type = target_id
	scenario.target_speed_kmh = 0.0
	if target_id == ScenarioConfig.TARGET_LORRY:
		scenario.target_mass_kg = 12000.0
	else:
		scenario.target_mass_kg = 220.0
	_request_preview_rebuild()
	_rebuild_inspector()

func _rebuild_inspector() -> void:
	if selected_object != &"target" or (scenario.target_type != ScenarioConfig.TARGET_LORRY and scenario.target_type != ScenarioConfig.TARGET_MOTORCYCLE):
		super._rebuild_inspector()
		return
	for child in inspector_column.get_children():
		inspector_column.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.text = ScenarioConfig.target_display_name(scenario.target_type)
	inspector_column.add_child(title)
	car_class_option = null
	if scenario.target_type == ScenarioConfig.TARGET_LORRY:
		mass_spin = _add_spin(inspector_column, "Mass (kg)", 3500.0, 26000.0, 100.0)
		speed_spin = _add_spin(inspector_column, "Speed (km/h)", 0.0, 140.0, 1.0)
	else:
		mass_spin = _add_spin(inspector_column, "Mass (kg)", 80.0, 600.0, 5.0)
		speed_spin = _add_spin(inspector_column, "Speed (km/h)", 0.0, 250.0, 1.0)
	mass_spin.value_changed.connect(_on_object_spin_changed.bind(&"mass"))
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
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Generic development model. Motorcycle simulation is riderless; no rider kinematics or injury outcome is modelled." if scenario.target_type == ScenarioConfig.TARGET_MOTORCYCLE else "Generic rigid-lorry / box-truck development model, not a manufacturer-specific vehicle."
	inspector_column.add_child(note)
	_sync_current_object_fields()

func _rebuild_preview() -> void:
	super._rebuild_preview()
	if scenario.target_type != ScenarioConfig.TARGET_LORRY and scenario.target_type != ScenarioConfig.TARGET_MOTORCYCLE:
		return
	if obstacle != null and is_instance_valid(obstacle):
		remove_child(obstacle)
		obstacle.queue_free()
	obstacle = null
	static_simulation = null
	pair_simulation = VehiclePairSimulation.new()
	if scenario.target_type == ScenarioConfig.TARGET_LORRY:
		lorry = RigidLorry.new()
		lorry.name = "RigidLorry"
		lorry.total_mass_kg = scenario.target_mass_kg
		lorry.initial_speed_kmh = scenario.target_speed_kmh
		lorry.origin_offset_m = scenario.target_position_m
		lorry.heading_deg = scenario.target_heading_deg
		lorry.auto_step = false
		lorry.show_structure = scenario.show_structure
		add_child(lorry)
		pair_simulation.configure(car.model, PRIMARY_FRONT_CONTACT_NODES, lorry.model, RigidLorryBuilder.rear_contact_nodes(), scenario.car_forward(), scenario.contact_friction, scenario.restitution)
	else:
		motorcycle = Motorcycle.new()
		motorcycle.name = "Motorcycle"
		motorcycle.total_mass_kg = scenario.target_mass_kg
		motorcycle.initial_speed_kmh = scenario.target_speed_kmh
		motorcycle.origin_offset_m = scenario.target_position_m
		motorcycle.heading_deg = scenario.target_heading_deg
		motorcycle.auto_step = false
		motorcycle.show_structure = scenario.show_structure
		add_child(motorcycle)
		var contact_nodes := MotorcycleBuilder.front_contact_nodes() if scenario.target_vehicle_uses_front_contact() else MotorcycleBuilder.rear_contact_nodes()
		pair_simulation.configure(car.model, PRIMARY_FRONT_CONTACT_NODES, motorcycle.model, contact_nodes, scenario.car_forward(), scenario.contact_friction, scenario.restitution)
	status_label.text = "Editable preview — press Simulate when ready"
	_update_metrics()

func _clear_runtime_objects() -> void:
	for node in [lorry, motorcycle]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	lorry = null
	motorcycle = null
	super._clear_runtime_objects()

func _on_structure_toggled(value: bool) -> void:
	super._on_structure_toggled(value)
	if lorry != null:
		lorry.set_structure_debug(value)
	if motorcycle != null:
		motorcycle.set_structure_debug(value)

func _target_selection_radius() -> float:
	if scenario.target_type == ScenarioConfig.TARGET_LORRY:
		return 4.2
	if scenario.target_type == ScenarioConfig.TARGET_MOTORCYCLE:
		return 1.4
	return super._target_selection_radius()

func _move_selected(delta_m: Vector3) -> void:
	if selected_object != &"target" or (scenario.target_type != ScenarioConfig.TARGET_LORRY and scenario.target_type != ScenarioConfig.TARGET_MOTORCYCLE):
		super._move_selected(delta_m)
		return
	if delta_m.is_zero_approx():
		return
	scenario.target_position_m += delta_m
	var model: StructuralModel = lorry.model if lorry != null else motorcycle.model
	model.translate_all_nodes(delta_m)
	if lorry != null:
		lorry.origin_offset_m = scenario.target_position_m
		lorry.step_external(0.0)
	else:
		motorcycle.origin_offset_m = scenario.target_position_m
		motorcycle.step_external(0.0)
	_sync_current_object_fields()

func _rotate_selected(delta_deg: float) -> void:
	if selected_object != &"target" or (scenario.target_type != ScenarioConfig.TARGET_LORRY and scenario.target_type != ScenarioConfig.TARGET_MOTORCYCLE):
		super._rotate_selected(delta_deg)
		return
	if is_zero_approx(delta_deg):
		return
	scenario.target_heading_deg = wrapf(scenario.target_heading_deg + delta_deg, -180.0, 180.0)
	var model: StructuralModel = lorry.model if lorry != null else motorcycle.model
	model.rotate_y_about(scenario.target_position_m, deg_to_rad(delta_deg), true)
	if lorry != null:
		lorry.heading_deg = scenario.target_heading_deg
		lorry.step_external(0.0)
	else:
		motorcycle.heading_deg = scenario.target_heading_deg
		motorcycle.step_external(0.0)
	_sync_current_object_fields()
	_request_preview_rebuild()

func _capture_replay_frame(force: bool) -> void:
	if scenario.target_type != ScenarioConfig.TARGET_LORRY and scenario.target_type != ScenarioConfig.TARGET_MOTORCYCLE:
		super._capture_replay_frame(force)
		return
	if car == null or car.model == null:
		return
	var target_model: StructuralModel = lorry.model if lorry != null else motorcycle.model
	var target_metrics := _special_target_metrics(target_model)
	var context := _current_replay_context()
	var time_s := _simulation_elapsed_s()
	if force:
		replay_recorder.force_final(time_s, car.model, target_model, _passenger_car_metrics(car), target_metrics, context, car.replay_visual_state(), {})
	else:
		replay_recorder.capture(time_s, car.model, target_model, _passenger_car_metrics(car), target_metrics, context, car.replay_visual_state(), {})

func _special_target_metrics(model: StructuralModel) -> Dictionary:
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
	if scenario.target_type == ScenarioConfig.TARGET_LORRY:
		result["rear_guard_m"] = model.max_permanent_deformation_for_role(&"lorry_rear_guard")
	else:
		result["frame_deformation_m"] = model.max_permanent_deformation_for_role(&"motorcycle_frame")
	return result

func _apply_replay_time(time_s: float, from_playback: bool) -> void:
	if scenario.target_type != ScenarioConfig.TARGET_LORRY and scenario.target_type != ScenarioConfig.TARGET_MOTORCYCLE:
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
		if lorry != null and lorry.model != null:
			StructuralSnapshot.apply(lorry.model, target_state)
			lorry.step_external(0.0)
		elif motorcycle != null and motorcycle.model != null:
			StructuralSnapshot.apply(motorcycle.model, target_state)
			motorcycle.step_external(0.0)
	if analysis_overlay != null:
		analysis_overlay.update_from_models()
	syncing_replay_ui = true
	timeline_slider.value = replay_time_s
	syncing_replay_ui = false
	_update_replay_time_label()
	if not from_playback:
		status_label.text = "Recorded replay scrubbed to %.2f s" % replay_time_s

func _refresh_analysis_overlay() -> void:
	if scenario.target_type != ScenarioConfig.TARGET_LORRY and scenario.target_type != ScenarioConfig.TARGET_MOTORCYCLE:
		super._refresh_analysis_overlay()
		return
	if analysis_overlay == null or car == null or car.model == null:
		return
	var target_model: StructuralModel = null
	if lorry != null:
		target_model = lorry.model
	elif motorcycle != null:
		target_model = motorcycle.model
	analysis_overlay.configure(car.model, target_model)
	analysis_overlay.set_enabled(vectors_check == null or vectors_check.button_pressed)

# Override the inherited M4 metrics formatter because Godot's percent-style
# formatter treats a literal percent sign as a formatting token.
func _update_metrics() -> void:
	if metrics_label == null or car == null or car.model == null:
		return
	var car_speed := PhysicsMetrics.ms_to_kmh(car.global_linear_velocity_ms().length())
	var initial_energy_kj := PhysicsMetrics.kinetic_energy_from_speed_kmh(scenario.car_mass_kg, scenario.car_speed_kmh) / 1000.0
	var contact_count := 0
	var peak_penetration_mm := 0.0
	var energy_error_percent := 0.0
	var extra := ""
	if pair_simulation != null:
		contact_count = pair_simulation.contact.contact_events
		peak_penetration_mm = pair_simulation.contact.maximum_penetration_m * 1000.0
		energy_error_percent = pair_simulation.energy_balance_relative_error() * 100.0
		if target_car != null:
			var target_speed := PhysicsMetrics.ms_to_kmh(target_car.global_linear_velocity_ms().length())
			extra = "%s • %.0f kg • %.1f km/h • closing %.1f km/h • momentum error %.3f kg·m/s" % [target_car.vehicle_class_name(), target_car.model.total_mass_kg(), target_speed, pair_simulation.closing_speed_kmh(), pair_simulation.momentum_error_kg_ms()]
		elif truck != null:
			var truck_speed := PhysicsMetrics.ms_to_kmh(truck.global_linear_velocity_ms().length())
			extra = "Heavy articulated truck • %.0f kg • %.1f km/h • closing %.1f km/h • momentum error %.3f kg·m/s" % [truck.model.total_mass_kg(), truck_speed, pair_simulation.closing_speed_kmh(), pair_simulation.momentum_error_kg_ms()]
		elif lorry != null:
			var lorry_speed := PhysicsMetrics.ms_to_kmh(lorry.global_linear_velocity_ms().length())
			extra = "Rigid lorry • %.0f kg • %.1f km/h • closing %.1f km/h • momentum error %.3f kg·m/s" % [lorry.model.total_mass_kg(), lorry_speed, pair_simulation.closing_speed_kmh(), pair_simulation.momentum_error_kg_ms()]
		elif motorcycle != null:
			var bike_speed := PhysicsMetrics.ms_to_kmh(motorcycle.global_linear_velocity_ms().length())
			extra = "Motorcycle (riderless) • %.0f kg • %.1f km/h • closing %.1f km/h • momentum error %.3f kg·m/s" % [motorcycle.model.total_mass_kg(), bike_speed, pair_simulation.closing_speed_kmh(), pair_simulation.momentum_error_kg_ms()]
	elif static_simulation != null:
		contact_count = static_simulation.contact.contact_events
		peak_penetration_mm = static_simulation.contact.maximum_penetration_m * 1000.0
		energy_error_percent = static_simulation.energy_balance_relative_error() * 100.0
		extra = "Static target: %s" % ScenarioConfig.target_display_name(scenario.target_type)
	metrics_label.text = "%s • %.0f kg • %.1f km/h • initial KE %.1f kJ\nFront crush %.0f mm • safety cell %.0f mm • contacts %d • peak penetration %.1f mm • energy diagnostic %.2f%s\n%s" % [
		car.vehicle_class_name(), car.model.total_mass_kg(), car_speed, initial_energy_kj,
		car.front_crush_deformation_m() * 1000.0, car.safety_cell_deformation_m() * 1000.0,
		contact_count, peak_penetration_mm, energy_error_percent, "%", extra,
	]
