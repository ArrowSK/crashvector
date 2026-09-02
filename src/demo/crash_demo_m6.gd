# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m5.gd"

const MODE_SPEED: StringName = &"speed"
const MODE_CLASS: StringName = &"vehicle_class"
const SYNC_IMPACT: StringName = &"impact"
const SYNC_SCENARIO: StringName = &"scenario"

var comparison_results: Array[Dictionary] = []
var comparison_lanes: Array[ComparisonLane3D] = []
var comparison_paint_ids: Array[StringName] = [
	CarPaintCatalog.CRIMSON,
	CarPaintCatalog.ELECTRIC_BLUE,
	CarPaintCatalog.SUNSET_ORANGE,
]
var comparison_active: bool = false
var comparison_playing: bool = false
var comparison_time_s: float = 0.0
var comparison_speed: float = 0.25
var comparison_mode: StringName = MODE_SPEED
var comparison_sync: StringName = SYNC_IMPACT
var syncing_comparison_ui: bool = false

var comparison_canvas: CanvasLayer
var comparison_panel: PanelContainer
var comparison_mode_option: OptionButton
var comparison_sync_option: OptionButton
var comparison_speed_option: OptionButton
var comparison_run_button: Button
var comparison_play_button: Button
var comparison_exit_button: Button
var comparison_structure_check: CheckButton
var comparison_timeline: HSlider
var comparison_time_label: Label
var comparison_cards: HBoxContainer
var comparison_hint: Label
var comparison_results_panel: PanelContainer

func _ready() -> void:
	super._ready()
	_build_m6_ui()

func _process(delta: float) -> void:
	super._process(delta)
	if not comparison_active or not comparison_playing:
		return
	comparison_time_s += delta * comparison_speed
	if comparison_time_s >= comparison_timeline.max_value:
		comparison_time_s = comparison_timeline.max_value
		comparison_playing = false
		comparison_play_button.text = "Play comparison"
	_apply_comparison_time(comparison_time_s, true)

func _request_preview_rebuild() -> void:
	if comparison_active:
		_exit_comparison_mode(false)
	comparison_results.clear()
	super._request_preview_rebuild()

func _build_m6_ui() -> void:
	comparison_canvas = CanvasLayer.new()
	comparison_canvas.name = "M6ComparisonUI"
	comparison_canvas.layer = 4
	add_child(comparison_canvas)

	comparison_panel = PanelContainer.new()
	comparison_panel.anchor_left = 0.5
	comparison_panel.anchor_right = 0.5
	comparison_panel.offset_left = -430.0
	comparison_panel.offset_top = 68.0
	comparison_panel.offset_right = 430.0
	comparison_panel.offset_bottom = 118.0
	comparison_canvas.add_child(comparison_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	comparison_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	var title := Label.new()
	title.text = "Visual Compare"
	title.add_theme_font_size_override("font_size", 18)
	row.add_child(title)

	comparison_mode_option = OptionButton.new()
	comparison_mode_option.add_item("50 / 90 / 140 km/h")
	comparison_mode_option.set_item_metadata(0, MODE_SPEED)
	comparison_mode_option.add_item("B / C / D vehicle class")
	comparison_mode_option.set_item_metadata(1, MODE_CLASS)
	comparison_mode_option.item_selected.connect(_on_comparison_mode_selected)
	row.add_child(comparison_mode_option)

	comparison_run_button = Button.new()
	comparison_run_button.text = "Run comparison"
	comparison_run_button.pressed.connect(_on_run_comparison_pressed)
	row.add_child(comparison_run_button)

	comparison_play_button = Button.new()
	comparison_play_button.text = "Play comparison"
	comparison_play_button.disabled = true
	comparison_play_button.pressed.connect(_on_comparison_play_pressed)
	row.add_child(comparison_play_button)

	comparison_exit_button = Button.new()
	comparison_exit_button.text = "Back to editor"
	comparison_exit_button.disabled = true
	comparison_exit_button.pressed.connect(_on_comparison_exit_pressed)
	row.add_child(comparison_exit_button)

	comparison_results_panel = PanelContainer.new()
	comparison_results_panel.anchor_left = 0.5
	comparison_results_panel.anchor_right = 0.5
	comparison_results_panel.anchor_top = 1.0
	comparison_results_panel.anchor_bottom = 1.0
	comparison_results_panel.offset_left = -520.0
	comparison_results_panel.offset_top = -205.0
	comparison_results_panel.offset_right = 520.0
	comparison_results_panel.offset_bottom = -12.0
	comparison_results_panel.visible = false
	comparison_canvas.add_child(comparison_results_panel)
	var result_margin := MarginContainer.new()
	result_margin.add_theme_constant_override("margin_left", 12)
	result_margin.add_theme_constant_override("margin_top", 8)
	result_margin.add_theme_constant_override("margin_right", 12)
	result_margin.add_theme_constant_override("margin_bottom", 8)
	comparison_results_panel.add_child(result_margin)
	var result_column := VBoxContainer.new()
	result_column.add_theme_constant_override("separation", 5)
	result_margin.add_child(result_column)

	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation", 7)
	result_column.add_child(playback)
	var sync_label := Label.new()
	sync_label.text = "Sync"
	playback.add_child(sync_label)
	comparison_sync_option = OptionButton.new()
	comparison_sync_option.add_item("Impact synchronized")
	comparison_sync_option.set_item_metadata(0, SYNC_IMPACT)
	comparison_sync_option.add_item("Scenario time")
	comparison_sync_option.set_item_metadata(1, SYNC_SCENARIO)
	comparison_sync_option.item_selected.connect(_on_comparison_sync_selected)
	playback.add_child(comparison_sync_option)
	var speed_label := Label.new()
	speed_label.text = "Replay"
	playback.add_child(speed_label)
	comparison_speed_option = OptionButton.new()
	var speeds: Array[float] = [0.05, 0.10, 0.25, 0.50, 1.00]
	for value in speeds:
		comparison_speed_option.add_item("%.2gx" % value)
		comparison_speed_option.set_item_metadata(comparison_speed_option.item_count - 1, value)
	comparison_speed_option.select(2)
	comparison_speed_option.item_selected.connect(_on_comparison_speed_selected)
	playback.add_child(comparison_speed_option)
	comparison_structure_check = CheckButton.new()
	comparison_structure_check.text = "X-ray structure"
	comparison_structure_check.toggled.connect(_on_comparison_structure_toggled)
	playback.add_child(comparison_structure_check)
	var playback_spacer := Control.new()
	playback_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playback.add_child(playback_spacer)
	comparison_time_label = Label.new()
	comparison_time_label.text = "—"
	playback.add_child(comparison_time_label)

	comparison_timeline = HSlider.new()
	comparison_timeline.min_value = -0.6
	comparison_timeline.max_value = 3.0
	comparison_timeline.step = 1.0 / 120.0
	comparison_timeline.editable = false
	comparison_timeline.value_changed.connect(_on_comparison_timeline_changed)
	result_column.add_child(comparison_timeline)

	comparison_cards = HBoxContainer.new()
	comparison_cards.add_theme_constant_override("separation", 8)
	comparison_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_column.add_child(comparison_cards)
	comparison_hint = Label.new()
	comparison_hint.text = "The three scenes use the same scenario and replay clock. Impact synchronization aligns first contact so the visual difference is immediately obvious. Car colors are presentation-only and never change the physics."
	comparison_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_column.add_child(comparison_hint)

func _on_comparison_mode_selected(index: int) -> void:
	comparison_mode = StringName(String(comparison_mode_option.get_item_metadata(index)))

func _on_run_comparison_pressed() -> void:
	var errors := scenario.validation_errors()
	if not errors.is_empty():
		status_label.text = "Comparison preflight failed: %s" % "; ".join(errors)
		return
	_stop_replay()
	comparison_playing = false
	comparison_run_button.disabled = true
	comparison_run_button.text = "Calculating…"
	comparison_results = (
		ComparisonRunner.run_vehicle_class_sweep(scenario)
		if comparison_mode == MODE_CLASS
		else ComparisonRunner.run_speed_sweep(scenario)
	)
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
	var offsets: Array[Vector3] = [Vector3(0.0, 0.0, -8.5), Vector3.ZERO, Vector3(0.0, 0.0, 8.5)]
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

func _exit_comparison_mode(rebuild_editor: bool = true) -> void:
	comparison_playing = false
	comparison_active = false
	_clear_comparison_lanes()
	comparison_results_panel.visible = false
	comparison_play_button.disabled = true
	comparison_play_button.text = "Play comparison"
	comparison_exit_button.disabled = true
	_set_base_ui_visible(true)
	if rebuild_editor:
		_rebuild_preview()
		_frame_scenario()
		_refresh_analysis_overlay()

func _on_comparison_exit_pressed() -> void:
	_exit_comparison_mode(true)
	status_label.text = "Returned to scenario editor"

func _clear_comparison_lanes() -> void:
	for lane in comparison_lanes:
		if lane != null and is_instance_valid(lane):
			remove_child(lane)
			lane.queue_free()
	comparison_lanes.clear()

func _set_base_ui_visible(value: bool) -> void:
	var editor_ui := get_node_or_null("EditorUI") as CanvasLayer
	if editor_ui != null:
		editor_ui.visible = value
	var m5_ui := get_node_or_null("M5AnalysisUI") as CanvasLayer
	if m5_ui != null:
		m5_ui.visible = value

func _on_comparison_play_pressed() -> void:
	if not comparison_active or comparison_results.is_empty():
		return
	if comparison_playing:
		comparison_playing = false
		comparison_play_button.text = "Play comparison"
		return
	if comparison_time_s >= comparison_timeline.max_value - 0.000001:
		comparison_time_s = comparison_timeline.min_value
		_apply_comparison_time(comparison_time_s, true)
	comparison_playing = true
	comparison_play_button.text = "Pause comparison"

func _on_comparison_speed_selected(index: int) -> void:
	comparison_speed = float(comparison_speed_option.get_item_metadata(index))

func _on_comparison_sync_selected(index: int) -> void:
	comparison_sync = StringName(String(comparison_sync_option.get_item_metadata(index)))
	if comparison_active:
		_configure_comparison_timeline(true)

func _on_comparison_structure_toggled(value: bool) -> void:
	for lane in comparison_lanes:
		lane.set_structure_debug(value)

func _on_comparison_timeline_changed(value: float) -> void:
	if syncing_comparison_ui or not comparison_active:
		return
	comparison_playing = false
	comparison_play_button.text = "Play comparison"
	_apply_comparison_time(value, false)

func _on_lane_paint_selected(option_index: int, lane_index: int, swatch: ColorRect) -> void:
	var ids := CarPaintCatalog.ids()
	if option_index < 0 or option_index >= ids.size() or lane_index < 0 or lane_index >= comparison_paint_ids.size():
		return
	var paint_id := ids[option_index]
	comparison_paint_ids[lane_index] = paint_id
	if lane_index < comparison_lanes.size():
		comparison_lanes[lane_index].set_primary_paint_id(paint_id)
	if swatch != null:
		swatch.color = CarPaintCatalog.color(paint_id)

func _configure_comparison_timeline(reset_to_start: bool) -> void:
	if comparison_results.is_empty():
		return
	var minimum := 0.0
	var maximum := 0.0
	if comparison_sync == SYNC_IMPACT:
		minimum = -0.65
		for result in comparison_results:
			var recording := result.get("recording") as ReplayRecording
			if recording == null:
				continue
			var contact_time := recording.marker_time(&"first_contact")
			if contact_time < 0.0:
				contact_time = 0.0
			maximum = maxf(maximum, recording.duration_s - contact_time)
	else:
		for result in comparison_results:
			var recording := result.get("recording") as ReplayRecording
			if recording != null:
				maximum = maxf(maximum, recording.duration_s)
	maximum = maxf(maximum, 0.5)
	syncing_comparison_ui = true
	comparison_timeline.min_value = minimum
	comparison_timeline.max_value = maximum
	comparison_timeline.step = 1.0 / 120.0
	if reset_to_start:
		comparison_time_s = minimum
	comparison_timeline.value = clampf(comparison_time_s, minimum, maximum)
	syncing_comparison_ui = false
	_apply_comparison_time(comparison_timeline.value, true)

func _apply_comparison_time(time_s: float, from_playback: bool) -> void:
	if comparison_results.is_empty():
		return
	comparison_time_s = clampf(time_s, comparison_timeline.min_value, comparison_timeline.max_value)
	for i in range(mini(comparison_results.size(), comparison_lanes.size())):
		var result := comparison_results[i]
		var recording := result.get("recording") as ReplayRecording
		if recording == null:
			continue
		var lane_time := comparison_time_s
		if comparison_sync == SYNC_IMPACT:
			var contact_time := recording.marker_time(&"first_contact")
			if contact_time < 0.0:
				contact_time = 0.0
			lane_time = contact_time + comparison_time_s
		comparison_lanes[i].apply_time(clampf(lane_time, 0.0, recording.duration_s))
	syncing_comparison_ui = true
	comparison_timeline.value = comparison_time_s
	syncing_comparison_ui = false
	if comparison_sync == SYNC_IMPACT:
		comparison_time_label.text = "impact %+0.2f s" % comparison_time_s
	else:
		comparison_time_label.text = "%.2f s" % comparison_time_s
	if not from_playback:
		comparison_hint.text = "Scrubbed synchronized comparison. The 3D lanes show actual recorded structural states, not three live simulations running at different frame rates."

func _build_comparison_cards() -> void:
	for child in comparison_cards.get_children():
		comparison_cards.remove_child(child)
		child.queue_free()
	var max_energy := 1.0
	var max_crush := 1.0
	for result in comparison_results:
		var analysis: Dictionary = result.get("analysis", {})
		max_energy = maxf(max_energy, float(analysis.get("initial_kinetic_energy_kj", 0.0)))
		max_crush = maxf(max_crush, float(analysis.get("max_front_crush_mm", 0.0)))
	for i in range(comparison_results.size()):
		comparison_cards.add_child(_make_result_card(comparison_results[i], max_energy, max_crush, i))

func _make_result_card(result: Dictionary, max_energy: float, max_crush: float, lane_index: int) -> Control:
	var analysis: Dictionary = result.get("analysis", {})
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = String(result.get("label", "Variant"))
	heading.add_theme_font_size_override("font_size", 16)
	column.add_child(heading)

	var paint_row := HBoxContainer.new()
	paint_row.add_theme_constant_override("separation", 5)
	column.add_child(paint_row)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(18.0, 18.0)
	swatch.color = CarPaintCatalog.color(comparison_paint_ids[lane_index])
	paint_row.add_child(swatch)
	var paint_option := OptionButton.new()
	paint_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paint_ids := CarPaintCatalog.ids()
	for id in paint_ids:
		paint_option.add_item(CarPaintCatalog.display_name(id))
	paint_option.select(maxi(paint_ids.find(comparison_paint_ids[lane_index]), 0))
	paint_option.item_selected.connect(_on_lane_paint_selected.bind(lane_index, swatch))
	paint_row.add_child(paint_option)

	var metrics := Label.new()
	metrics.text = "Δv %.1f km/h   peak %.1f g   crush %.0f mm   cell %.0f mm" % [
		float(analysis.get("final_delta_v_kmh", 0.0)),
		float(analysis.get("peak_deceleration_g", 0.0)),
		float(analysis.get("max_front_crush_mm", 0.0)),
		float(analysis.get("max_safety_cell_deformation_mm", 0.0)),
	]
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(metrics)
	var energy_label := Label.new()
	energy_label.text = "Initial kinetic energy %.1f kJ" % float(analysis.get("initial_kinetic_energy_kj", 0.0))
	column.add_child(energy_label)
	var energy_bar := ProgressBar.new()
	energy_bar.max_value = max_energy
	energy_bar.value = float(analysis.get("initial_kinetic_energy_kj", 0.0))
	energy_bar.show_percentage = false
	energy_bar.custom_minimum_size.y = 9.0
	column.add_child(energy_bar)
	var crush_label := Label.new()
	crush_label.text = "Maximum front crush"
	column.add_child(crush_label)
	var crush_bar := ProgressBar.new()
	crush_bar.max_value = max_crush
	crush_bar.value = float(analysis.get("max_front_crush_mm", 0.0))
	crush_bar.show_percentage = false
	crush_bar.custom_minimum_size.y = 9.0
	column.add_child(crush_bar)
	return panel

func _ensure_comparison_paint_defaults() -> void:
	if comparison_paint_ids.size() == 3:
		return
	comparison_paint_ids = [CarPaintCatalog.CRIMSON, CarPaintCatalog.ELECTRIC_BLUE, CarPaintCatalog.SUNSET_ORANGE]

func _frame_comparison() -> void:
	if camera == null:
		return
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5
	var separation := scenario.car_position_m.distance_to(scenario.target_position_m)
	camera.position = Vector3(midpoint.x - 2.0, 15.5, midpoint.z + maxf(29.0, separation * 1.25 + 22.0))
	camera.look_at(midpoint + Vector3(0.0, 1.15, 0.0), Vector3.UP)
