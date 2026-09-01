# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo.gd"

var replay_recorder := ReplayRecorder.new()
var analysis_report: Dictionary = {}
var replay_time_s: float = 0.0
var replay_playing: bool = false
var replay_speed: float = 0.25
var syncing_replay_ui: bool = false

var analysis_overlay: AnalysisOverlay3D
var replay_button: Button
var replay_speed_option: OptionButton
var timeline_slider: HSlider
var replay_time_label: Label
var analysis_summary_label: Label
var event_markers_label: Label
var crash_pulse_graph: CrashMetricGraph
var deformation_graph: CrashMetricGraph
var vectors_check: CheckButton

func _ready() -> void:
	super._ready()
	analysis_overlay = AnalysisOverlay3D.new()
	analysis_overlay.name = "AnalysisOverlay3D"
	add_child(analysis_overlay)
	_build_m5_ui()
	_refresh_analysis_overlay()
	_reset_analysis_ui()

func _physics_process(delta: float) -> void:
	var was_running := simulation_running
	super._physics_process(delta)
	if was_running:
		_capture_replay_frame(false)
		if not simulation_running:
			_capture_replay_frame(true)
			_finalize_recording()
	if analysis_overlay != null:
		analysis_overlay.update_from_models()

func _process(delta: float) -> void:
	if not replay_playing or replay_recorder.recording == null or not replay_recorder.recording.has_frames():
		return
	replay_time_s += delta * replay_speed
	if replay_time_s >= replay_recorder.recording.duration_s:
		replay_time_s = replay_recorder.recording.duration_s
		replay_playing = false
		replay_button.text = "Play Replay"
	_apply_replay_time(replay_time_s, true)

func _rebuild_preview() -> void:
	super._rebuild_preview()
	_refresh_analysis_overlay()

func _request_preview_rebuild() -> void:
	if replay_recorder.recording != null and replay_recorder.recording.has_frames():
		replay_recorder = ReplayRecorder.new()
		_reset_analysis_ui()
	super._request_preview_rebuild()

func _on_simulate_pressed() -> void:
	_stop_replay()
	analysis_report.clear()
	super._on_simulate_pressed()
	if not simulation_running:
		return
	replay_recorder.begin(1.0 / 120.0)
	replay_time_s = 0.0
	_reset_analysis_ui()
	_capture_replay_frame(true)

func _on_reset_pressed() -> void:
	_stop_replay()
	super._on_reset_pressed()
	_reset_analysis_ui()

func _on_new_pressed() -> void:
	_stop_replay()
	super._on_new_pressed()
	_reset_analysis_ui()

func _on_open_path_selected(path: String) -> void:
	_stop_replay()
	super._on_open_path_selected(path)
	_reset_analysis_ui()

func _build_m5_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "M5AnalysisUI"
	canvas.layer = 2
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 275.0
	panel.offset_top = -340.0
	panel.offset_right = -355.0
	panel.offset_bottom = -145.0
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	column.add_child(controls)
	replay_button = Button.new()
	replay_button.text = "Play Replay"
	replay_button.disabled = true
	replay_button.pressed.connect(_on_replay_button_pressed)
	controls.add_child(replay_button)
	var speed_label := Label.new()
	speed_label.text = "Speed"
	controls.add_child(speed_label)
	replay_speed_option = OptionButton.new()
	var speeds: Array[float] = [0.05, 0.10, 0.25, 0.50, 1.00]
	for speed in speeds:
		replay_speed_option.add_item("%.2gx" % speed)
		replay_speed_option.set_item_metadata(replay_speed_option.item_count - 1, speed)
	replay_speed_option.select(2)
	replay_speed_option.item_selected.connect(_on_replay_speed_selected)
	controls.add_child(replay_speed_option)
	vectors_check = CheckButton.new()
	vectors_check.text = "Velocity / momentum vectors"
	vectors_check.button_pressed = true
	vectors_check.toggled.connect(_on_vectors_toggled)
	controls.add_child(vectors_check)
	var controls_spacer := Control.new()
	controls_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(controls_spacer)
	replay_time_label = Label.new()
	replay_time_label.text = "0.00 / 0.00 s"
	controls.add_child(replay_time_label)

	timeline_slider = HSlider.new()
	timeline_slider.min_value = 0.0
	timeline_slider.max_value = 1.0
	timeline_slider.step = 1.0 / 120.0
	timeline_slider.editable = false
	timeline_slider.value_changed.connect(_on_timeline_changed)
	column.add_child(timeline_slider)

	analysis_summary_label = Label.new()
	analysis_summary_label.text = "Run a simulation to create replay and analysis data."
	analysis_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(analysis_summary_label)
	event_markers_label = Label.new()
	event_markers_label.text = "Events: —"
	event_markers_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(event_markers_label)

	var graphs := HBoxContainer.new()
	graphs.add_theme_constant_override("separation", 6)
	graphs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(graphs)
	crash_pulse_graph = CrashMetricGraph.new()
	crash_pulse_graph.custom_minimum_size = Vector2(220.0, 72.0)
	crash_pulse_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphs.add_child(crash_pulse_graph)
	deformation_graph = CrashMetricGraph.new()
	deformation_graph.custom_minimum_size = Vector2(220.0, 72.0)
	deformation_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphs.add_child(deformation_graph)

func _capture_replay_frame(force: bool) -> void:
	if car == null or car.model == null:
		return
	var target_model: StructuralModel = null
	var target_metrics: Dictionary = {}
	var target_visual: Dictionary = {}
	if target_car != null and target_car.model != null:
		target_model = target_car.model
		target_metrics = _passenger_car_metrics(target_car)
		target_visual = target_car.replay_visual_state()
	elif truck != null and truck.model != null:
		target_model = truck.model
		target_metrics = _truck_metrics(truck)
	var context := _current_replay_context()
	var time_s := _simulation_elapsed_s()
	if force:
		replay_recorder.force_final(
			time_s,
			car.model,
			target_model,
			_passenger_car_metrics(car),
			target_metrics,
			context,
			car.replay_visual_state(),
			target_visual
		)
	else:
		replay_recorder.capture(
			time_s,
			car.model,
			target_model,
			_passenger_car_metrics(car),
			target_metrics,
			context,
			car.replay_visual_state(),
			target_visual
		)

func _passenger_car_metrics(vehicle: CompactHatchback) -> Dictionary:
	var velocity := vehicle.global_linear_velocity_ms()
	return {
		"mass_kg": vehicle.model.total_mass_kg(),
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": vehicle.model.total_momentum_kg_ms(),
		"kinetic_energy_j": vehicle.model.total_kinetic_energy_j(),
		"front_crush_m": vehicle.front_crush_deformation_m(),
		"safety_cell_m": vehicle.safety_cell_deformation_m(),
		"broken_beams": vehicle.model.broken_beam_count(),
		"plastic_energy_j": vehicle.model.total_plastic_energy_j(),
		"elastic_energy_j": vehicle.model.total_elastic_energy_j(),
	}

func _truck_metrics(vehicle: HeavyTruck) -> Dictionary:
	var velocity := vehicle.global_linear_velocity_ms()
	return {
		"mass_kg": vehicle.model.total_mass_kg(),
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": vehicle.model.total_momentum_kg_ms(),
		"kinetic_energy_j": vehicle.model.total_kinetic_energy_j(),
		"rear_guard_m": vehicle.rear_guard_deformation_m(),
		"broken_beams": vehicle.model.broken_beam_count(),
		"plastic_energy_j": vehicle.model.total_plastic_energy_j(),
		"elastic_energy_j": vehicle.model.total_elastic_energy_j(),
	}

func _current_replay_context() -> Dictionary:
	var contact_count := 0
	var energy_error := 0.0
	var contact_dissipation := 0.0
	if pair_simulation != null:
		contact_count = pair_simulation.contact.contact_events
		energy_error = pair_simulation.energy_balance_relative_error()
		contact_dissipation = pair_simulation.contact.accumulated_dissipation_j
	elif static_simulation != null:
		contact_count = static_simulation.contact.contact_events
		energy_error = static_simulation.energy_balance_relative_error()
		contact_dissipation = static_simulation.contact.accumulated_dissipation_j
	return {
		"contact_count": contact_count,
		"energy_balance_relative_error": energy_error,
		"contact_dissipation_j": contact_dissipation,
	}

func _finalize_recording() -> void:
	if replay_recorder.recording == null or replay_recorder.recording.frames.size() < 2:
		return
	analysis_report = CrashAnalysis.analyze(replay_recorder.recording)
	replay_time_s = replay_recorder.recording.duration_s
	syncing_replay_ui = true
	timeline_slider.max_value = maxf(replay_recorder.recording.duration_s, replay_recorder.recording.sample_interval_s)
	timeline_slider.step = replay_recorder.recording.sample_interval_s
	timeline_slider.value = replay_time_s
	timeline_slider.editable = true
	syncing_replay_ui = false
	replay_button.disabled = false
	_refresh_analysis_ui()
	status_label.text = "Simulation complete — recorded replay is ready"

func _refresh_analysis_ui() -> void:
	if analysis_report.is_empty():
		return
	var target_delta_text := ""
	if analysis_report.has("target_final_delta_v_kmh"):
		target_delta_text = " • target Δv %.1f km/h" % float(analysis_report["target_final_delta_v_kmh"])
	analysis_summary_label.text = (
		"Primary Δv %.1f km/h • peak longitudinal decel %.1f g • front crush %.0f mm • safety-cell deformation proxy %.0f mm%s\n"
		+ "Primary KE %.1f → %.1f kJ • broken members %d • %d replay samples. Safety-cell deformation is an educational intrusion-oriented proxy, not occupant injury prediction."
	) % [
		float(analysis_report.get("final_delta_v_kmh", 0.0)),
		float(analysis_report.get("peak_deceleration_g", 0.0)),
		float(analysis_report.get("max_front_crush_mm", 0.0)),
		float(analysis_report.get("max_safety_cell_deformation_mm", 0.0)),
		target_delta_text,
		float(analysis_report.get("initial_kinetic_energy_kj", 0.0)),
		float(analysis_report.get("final_kinetic_energy_kj", 0.0)),
		int(analysis_report.get("max_broken_beams", 0)),
		int(analysis_report.get("sample_count", 0)),
	]
	var marker_parts: Array[String] = []
	for marker in replay_recorder.recording.event_markers:
		marker_parts.append("%s %.2fs" % [String(marker.get("label", "Event")), float(marker.get("time_s", 0.0))])
	event_markers_label.text = "Events: %s" % (" • ".join(marker_parts) if not marker_parts.is_empty() else "none detected in recorded window")
	crash_pulse_graph.configure(
		"Crash pulse — longitudinal deceleration",
		"g",
		_series_from_report("crash_pulse_series"),
		replay_recorder.recording.event_markers
	)
	deformation_graph.configure(
		"Front crush deformation",
		"mm",
		_series_from_report("front_crush_series"),
		replay_recorder.recording.event_markers
	)
	_update_replay_time_label()

func _series_from_report(key: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var raw: Variant = analysis_report.get(key, [])
	if raw is Array:
		for value in raw:
			if value is Vector2:
				result.append(value)
	return result

func _on_replay_button_pressed() -> void:
	if simulation_running or replay_recorder.recording == null or not replay_recorder.recording.has_frames():
		return
	if replay_playing:
		_stop_replay()
		return
	if replay_time_s >= replay_recorder.recording.duration_s - 0.000001:
		replay_time_s = 0.0
		_apply_replay_time(replay_time_s, true)
	replay_playing = true
	replay_button.text = "Pause Replay"
	status_label.text = "Recorded replay playing at %.2gx" % replay_speed

func _on_replay_speed_selected(index: int) -> void:
	var metadata: Variant = replay_speed_option.get_item_metadata(index)
	replay_speed = float(metadata)
	if replay_playing:
		status_label.text = "Recorded replay playing at %.2gx" % replay_speed

func _on_timeline_changed(value: float) -> void:
	if syncing_replay_ui or simulation_running:
		return
	_stop_replay()
	_apply_replay_time(value, false)

func _on_vectors_toggled(value: bool) -> void:
	if analysis_overlay != null:
		analysis_overlay.set_enabled(value)

func _apply_replay_time(time_s: float, from_playback: bool) -> void:
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
	if target_car != null and target_car.model != null and frame.has("target_state"):
		var target_state: Variant = frame.get("target_state", {})
		if target_state is Dictionary:
			StructuralSnapshot.apply(target_car.model, target_state)
		var target_visual: Variant = frame.get("target_visual_state", {})
		target_car.apply_replay_visual_state(target_visual if target_visual is Dictionary else {})
	elif truck != null and truck.model != null and frame.has("target_state"):
		var truck_state: Variant = frame.get("target_state", {})
		if truck_state is Dictionary:
			StructuralSnapshot.apply(truck.model, truck_state)
		truck.step_external(0.0)
	if analysis_overlay != null:
		analysis_overlay.update_from_models()
	syncing_replay_ui = true
	timeline_slider.value = replay_time_s
	syncing_replay_ui = false
	_update_replay_time_label()
	if not from_playback:
		status_label.text = "Recorded replay scrubbed to %.2f s" % replay_time_s

func _stop_replay() -> void:
	replay_playing = false
	if replay_button != null:
		replay_button.text = "Play Replay"

func _reset_analysis_ui() -> void:
	_stop_replay()
	analysis_report.clear()
	replay_time_s = 0.0
	if timeline_slider != null:
		syncing_replay_ui = true
		timeline_slider.min_value = 0.0
		timeline_slider.max_value = 1.0
		timeline_slider.value = 0.0
		timeline_slider.editable = false
		syncing_replay_ui = false
	if replay_button != null:
		replay_button.disabled = true
	if analysis_summary_label != null:
		analysis_summary_label.text = "Run a simulation to create replay and analysis data."
	if event_markers_label != null:
		event_markers_label.text = "Events: —"
	if crash_pulse_graph != null:
		crash_pulse_graph.clear()
	if deformation_graph != null:
		deformation_graph.clear()
	_update_replay_time_label()

func _update_replay_time_label() -> void:
	if replay_time_label == null:
		return
	var duration := 0.0
	if replay_recorder.recording != null and replay_recorder.recording.has_frames():
		duration = replay_recorder.recording.duration_s
	replay_time_label.text = "%.2f / %.2f s" % [replay_time_s, duration]

func _refresh_analysis_overlay() -> void:
	if analysis_overlay == null or car == null or car.model == null:
		return
	var target_model: StructuralModel = null
	if target_car != null:
		target_model = target_car.model
	elif truck != null:
		target_model = truck.model
	analysis_overlay.configure(car.model, target_model)
	analysis_overlay.set_enabled(vectors_check == null or vectors_check.button_pressed)
