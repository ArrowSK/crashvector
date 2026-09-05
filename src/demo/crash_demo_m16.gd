# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m14.gd"

# M16 is a presentation milestone. It intentionally leaves the M12-M14 physics
# stack untouched while replacing the accumulated M10 editor chrome with a
# task-focused shell and class-specific generated vehicle skins.

var m16_file_menu: MenuButton
var m16_more_menu: MenuButton
var m16_action_slot: HBoxContainer
var m16_selected_title: Label
var m16_primary_button: Button
var m16_target_button: Button
var m16_primary_properties: VBoxContainer
var m16_target_properties: VBoxContainer
var m16_advanced_toggle: Button
var m16_advanced_container: VBoxContainer
var m16_viewport_toolbar: PanelContainer
var m16_results_hint: Label
var m16_replay_caption: Label

func _ready() -> void:
	super._ready()
	if m10_root != null:
		m10_root.theme = CrashVectorM16Theme.build()
	if m10_simulate_button != null:
		CrashVectorM16Theme.accent_button(m10_simulate_button)
	if m10_compare_run != null:
		CrashVectorM16Theme.accent_button(m10_compare_run)
	if m10_status_chip != null:
		m10_status_chip.add_theme_stylebox_override("panel", CrashVectorM16Theme.chip())
	call_deferred("_apply_m16_vehicle_visuals")
	call_deferred("_sync_m10_from_scenario")

func _rebuild_preview() -> void:
	super._rebuild_preview()
	call_deferred("_apply_m16_vehicle_visuals")

func _build_top_bar() -> void:
	m10_top_bar = PanelContainer.new()
	m10_top_bar.name = "M16CommandBar"
	m10_root.add_child(m10_top_bar)
	var margin := _margin(m10_top_bar, 10, 5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var brand := Label.new()
	brand.name = "M16Brand"
	brand.text = "CrashVector"
	brand.add_theme_font_size_override("font_size", 20)
	brand.custom_minimum_size.x = 150.0
	row.add_child(brand)

	m16_file_menu = MenuButton.new()
	m16_file_menu.name = "M16FileMenu"
	m16_file_menu.text = "File"
	var file_popup := m16_file_menu.get_popup()
	file_popup.add_item("New scenario", 1)
	file_popup.add_item("Open…", 2)
	file_popup.id_pressed.connect(_on_m16_file_action)
	row.add_child(m16_file_menu)

	var divider := VSeparator.new()
	row.add_child(divider)
	m10_scenario_button = _add_button(row, "Scenario", _on_m10_scenario_mode, "Build and run one crash scenario")
	m10_compare_button = _add_button(row, "Compare", _on_m10_compare_mode, "Compare multiple runs")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var save_button := _add_button(row, "Save", _on_save_pressed, "Save the current scenario")
	save_button.name = "M16SaveButton"

	m16_more_menu = MenuButton.new()
	m16_more_menu.name = "M16MoreMenu"
	m16_more_menu.text = "More ⋯"
	var more_popup := m16_more_menu.get_popup()
	more_popup.add_item("Calibration & evidence", 10)
	more_popup.add_item("Check for updates", 11)
	more_popup.add_separator()
	more_popup.add_item("About CrashVector", 12)
	more_popup.id_pressed.connect(_on_m16_more_action)
	row.add_child(m16_more_menu)

	m16_action_slot = HBoxContainer.new()
	m16_action_slot.name = "M16PrimaryActionSlot"
	m16_action_slot.custom_minimum_size.x = 210.0
	m16_action_slot.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(m16_action_slot)
	m10_pause_button = _add_button(m16_action_slot, "⏸ Pause", _on_pause_pressed, "Pause or resume simulation")
	m10_pause_button.visible = false
	m10_reset_button = _add_button(m16_action_slot, "↻ Run again", _on_reset_pressed, "Return to editable preview")
	m10_reset_button.visible = false
	m10_simulate_button = _add_button(m16_action_slot, "▶ Run simulation", _on_simulate_pressed, "Run the current scenario")
	CrashVectorM16Theme.accent_button(m10_simulate_button)

func _build_scenario_panel() -> void:
	m10_left_panel = PanelContainer.new()
	m10_left_panel.name = "M16ScenarioBuilder"
	m10_root.add_child(m10_left_panel)
	var margin := _margin(m10_left_panel, 14, 14)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	margin.add_child(column)

	_add_m16_section_label(column, "SCENARIO")
	m10_title_edit = LineEdit.new()
	m10_title_edit.name = "M16ScenarioTitle"
	m10_title_edit.placeholder_text = "Scenario name"
	m10_title_edit.text_changed.connect(func(value: String) -> void:
		if not m10_syncing:
			scenario.title = value
	)
	column.add_child(m10_title_edit)

	_add_m16_field_label(column, "Primary vehicle")
	m10_primary_option = OptionButton.new()
	m10_primary_option.name = "M16VehicleSelector"
	for id in PassengerCarCatalog.preset_ids():
		m10_primary_option.add_item(PassengerCarCatalog.display_name(id))
		m10_primary_option.set_item_metadata(m10_primary_option.item_count - 1, id)
	m10_primary_option.item_selected.connect(_on_m10_primary_class_selected)
	column.add_child(m10_primary_option)

	_add_m16_field_label(column, "Impact target")
	m10_target_option = OptionButton.new()
	m10_target_option.name = "M16TargetSelector"
	for id in ScenarioConfig.target_ids():
		m10_target_option.add_item(ScenarioConfig.target_display_name(id))
		m10_target_option.set_item_metadata(m10_target_option.item_count - 1, id)
	m10_target_option.item_selected.connect(_on_m10_target_selected)
	column.add_child(m10_target_option)

	var speed_panel := PanelContainer.new()
	speed_panel.name = "M16ImpactSpeedCard"
	column.add_child(speed_panel)
	var speed_margin := _margin(speed_panel, 10, 9)
	var speed_column := VBoxContainer.new()
	speed_margin.add_child(speed_column)
	var speed_header := HBoxContainer.new()
	speed_column.add_child(speed_header)
	var speed_label := Label.new()
	speed_label.text = "Impact speed"
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_header.add_child(speed_label)
	var unit := Label.new()
	unit.text = "km/h"
	unit.add_theme_color_override("font_color", CrashVectorM16Theme.MUTED)
	speed_header.add_child(unit)
	m10_vehicle_speed = SpinBox.new()
	m10_vehicle_speed.name = "M16ImpactSpeed"
	m10_vehicle_speed.min_value = 0.0
	m10_vehicle_speed.max_value = 300.0
	m10_vehicle_speed.step = 1.0
	m10_vehicle_speed.custom_minimum_size.y = 40.0
	m10_vehicle_speed.value_changed.connect(_on_m10_vehicle_value.bind(&"speed"))
	speed_column.add_child(m10_vehicle_speed)

	var note := Label.new()
	note.text = "Choose the vehicle, target and speed. Detailed geometry and solver controls stay in Properties."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", CrashVectorM16Theme.MUTED)
	column.add_child(note)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	m10_metrics_summary = Label.new()
	m10_metrics_summary.name = "M16ScenarioSummary"
	m10_metrics_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m10_metrics_summary.add_theme_font_size_override("font_size", 12)
	m10_metrics_summary.add_theme_color_override("font_color", CrashVectorM16Theme.MUTED)
	column.add_child(m10_metrics_summary)

	# Kept for M10 compatibility; camera controls moved into the viewport.
	m10_camera_hint = Label.new()
	m10_camera_hint.visible = false

func _build_inspector() -> void:
	m10_right_panel = PanelContainer.new()
	m10_right_panel.name = "M16PropertiesPanel"
	m10_root.add_child(m10_right_panel)
	var margin := _margin(m10_right_panel, 13, 13)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	_add_m16_section_label(outer, "PROPERTIES")
	var selector_row := HBoxContainer.new()
	outer.add_child(selector_row)
	m16_primary_button = _add_button(selector_row, "Primary", _on_m16_select_primary, "Edit the primary vehicle")
	m16_primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m16_target_button = _add_button(selector_row, "Target", _on_m16_select_target, "Edit the impact target")
	m16_target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m16_selected_title = Label.new()
	m16_selected_title.name = "M16PropertiesHeader"
	m16_selected_title.text = "Primary vehicle"
	m16_selected_title.add_theme_font_size_override("font_size", 18)
	outer.add_child(m16_selected_title)

	var scroll := ScrollContainer.new()
	scroll.name = "M16PropertiesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	m16_primary_properties = VBoxContainer.new()
	m16_primary_properties.name = "M16PrimaryProperties"
	content.add_child(m16_primary_properties)
	m10_primary_class = OptionButton.new()
	m10_primary_class.visible = false
	for id in PassengerCarCatalog.preset_ids():
		m10_primary_class.add_item(PassengerCarCatalog.display_name(id))
		m10_primary_class.set_item_metadata(m10_primary_class.item_count - 1, id)
	m10_primary_class.item_selected.connect(_on_m10_primary_class_selected)
	m16_primary_properties.add_child(m10_primary_class)
	m10_vehicle_mass = _spin_row(m16_primary_properties, "Mass", 500.0, 5000.0, 5.0, " kg")
	m10_vehicle_x = _spin_row(m16_primary_properties, "Position X", -25.0, 25.0, 0.1, " m")
	m10_vehicle_z = _spin_row(m16_primary_properties, "Position Z", -8.0, 8.0, 0.1, " m")
	m10_vehicle_heading = _spin_row(m16_primary_properties, "Heading", -180.0, 180.0, 1.0, "°")
	m10_vehicle_mass.value_changed.connect(_on_m10_vehicle_value.bind(&"mass"))
	m10_vehicle_x.value_changed.connect(_on_m10_vehicle_value.bind(&"x"))
	m10_vehicle_z.value_changed.connect(_on_m10_vehicle_value.bind(&"z"))
	m10_vehicle_heading.value_changed.connect(_on_m10_vehicle_value.bind(&"heading"))
	var paint_row := _option_row_with_row(m16_primary_properties, "Paint")
	m10_primary_paint = paint_row[1]
	_populate_m10_paints(m10_primary_paint, m10_primary_paint_id)
	m10_primary_paint.item_selected.connect(_on_m10_primary_paint)

	m16_target_properties = VBoxContainer.new()
	m16_target_properties.name = "M16TargetProperties"
	content.add_child(m16_target_properties)
	m10_target_preset_row = HBoxContainer.new()
	m16_target_properties.add_child(m10_target_preset_row)
	var preset_label := Label.new()
	preset_label.text = "Preset"
	preset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m10_target_preset_row.add_child(preset_label)
	m10_target_preset = OptionButton.new()
	m10_target_preset.custom_minimum_size.x = 160.0
	m10_target_preset.item_selected.connect(_on_m10_target_preset_selected)
	m10_target_preset_row.add_child(m10_target_preset)
	var mass_data := _spin_row_with_row(m16_target_properties, "Mass", 0.0, 60000.0, 5.0, " kg")
	m10_target_mass_row = mass_data[0]
	m10_target_mass = mass_data[1]
	var target_speed_data := _spin_row_with_row(m16_target_properties, "Speed", 0.0, 300.0, 1.0, " km/h")
	m10_target_speed_row = target_speed_data[0]
	m10_target_speed = target_speed_data[1]
	m10_target_x = _spin_row(m16_target_properties, "Position X", -25.0, 25.0, 0.1, " m")
	m10_target_z = _spin_row(m16_target_properties, "Position Z", -8.0, 8.0, 0.1, " m")
	m10_target_heading = _spin_row(m16_target_properties, "Heading", -180.0, 180.0, 1.0, "°")
	m10_target_mass.value_changed.connect(_on_m10_target_value.bind(&"mass"))
	m10_target_speed.value_changed.connect(_on_m10_target_value.bind(&"speed"))
	m10_target_x.value_changed.connect(_on_m10_target_value.bind(&"x"))
	m10_target_z.value_changed.connect(_on_m10_target_value.bind(&"z"))
	m10_target_heading.value_changed.connect(_on_m10_target_value.bind(&"heading"))
	var target_paint_data := _option_row_with_row(m16_target_properties, "Paint")
	m10_target_paint_row = target_paint_data[0]
	m10_target_paint = target_paint_data[1]
	_populate_m10_paints(m10_target_paint, m10_target_paint_id)
	m10_target_paint.item_selected.connect(_on_m10_target_paint)

	var separator := HSeparator.new()
	content.add_child(separator)
	m16_advanced_toggle = Button.new()
	m16_advanced_toggle.name = "M16AdvancedToggle"
	m16_advanced_toggle.text = "Advanced setup ▸"
	m16_advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	m16_advanced_toggle.pressed.connect(_on_m16_advanced_toggled)
	content.add_child(m16_advanced_toggle)
	m16_advanced_container = VBoxContainer.new()
	m16_advanced_container.name = "M16AdvancedProperties"
	m16_advanced_container.visible = false
	content.add_child(m16_advanced_container)
	m10_duration = _spin_row(m16_advanced_container, "Duration", 0.5, 20.0, 0.5, " s")
	m10_friction = _spin_row(m16_advanced_container, "Contact friction", 0.0, 1.5, 0.05, "")
	m10_restitution = _spin_row(m16_advanced_container, "Restitution", 0.0, 0.5, 0.01, "")
	m10_substeps = _spin_row(m16_advanced_container, "Solver substeps", 1.0, 16.0, 1.0, "")
	m10_duration.value_changed.connect(_on_m10_physics_value.bind(&"duration"))
	m10_friction.value_changed.connect(_on_m10_physics_value.bind(&"friction"))
	m10_restitution.value_changed.connect(_on_m10_physics_value.bind(&"restitution"))
	m10_substeps.value_changed.connect(_on_m10_physics_value.bind(&"substeps"))
	m10_scope_chip = Button.new()
	m10_scope_chip.name = "EvidenceScopeChip"
	m10_scope_chip.text = "Calibration & evidence"
	m10_scope_chip.pressed.connect(_on_m10_calibration_pressed)
	m16_advanced_container.add_child(m10_scope_chip)
	var advanced_note := Label.new()
	advanced_note.text = "These controls change the numerical scenario. Leave them at defaults unless you specifically need them."
	advanced_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advanced_note.add_theme_font_size_override("font_size", 12)
	advanced_note.add_theme_color_override("font_color", CrashVectorM16Theme.MUTED)
	m16_advanced_container.add_child(advanced_note)

	m16_results_hint = Label.new()
	m16_results_hint.name = "M16ResultsHint"
	m16_results_hint.text = "Run the scenario to populate replay and analysis."
	m16_results_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m16_results_hint.add_theme_font_size_override("font_size", 12)
	m16_results_hint.add_theme_color_override("font_color", CrashVectorM16Theme.MUTED)
	outer.add_child(m16_results_hint)

	# Compatibility placeholder. M16 no longer exposes four parallel inspector tabs.
	m10_inspector_tabs = TabContainer.new()
	m10_inspector_tabs.visible = false

func _build_replay_drawer() -> void:
	m10_replay_drawer = PanelContainer.new()
	m10_replay_drawer.name = "M16PlaybackDock"
	m10_root.add_child(m10_replay_drawer)
	var margin := _margin(m10_replay_drawer, 9, 6)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.name = "M16PlaybackHeader"
	column.add_child(header)
	m16_replay_caption = Label.new()
	m16_replay_caption.text = "Playback"
	m16_replay_caption.custom_minimum_size.x = 70.0
	header.add_child(m16_replay_caption)
	_reparent_if_valid(replay_button, header)
	_reparent_if_valid(replay_speed_option, header)
	var timeline_holder := Control.new()
	timeline_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_holder.custom_minimum_size.x = 180.0
	header.add_child(timeline_holder)
	if timeline_slider != null:
		timeline_slider.reparent(timeline_holder, false)
		timeline_slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reparent_if_valid(replay_time_label, header)
	m10_replay_toggle = Button.new()
	m10_replay_toggle.text = "Analysis ▴"
	m10_replay_toggle.pressed.connect(_toggle_replay_drawer)
	header.add_child(m10_replay_toggle)
	m10_video_button = _add_button(header, "Export video", _on_m10_video_pressed, "Export a cinematic video of this run")

	m10_replay_content = VBoxContainer.new()
	m10_replay_content.name = "ReplayAnalysisContent"
	m10_replay_content.visible = false
	column.add_child(m10_replay_content)
	var toggles := HBoxContainer.new()
	m10_replay_content.add_child(toggles)
	_reparent_if_valid(analysis_summary_label, m10_replay_content)
	_reparent_if_valid(event_markers_label, m10_replay_content)
	var graph_row := HBoxContainer.new()
	graph_row.add_theme_constant_override("separation", 10)
	graph_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m10_replay_content.add_child(graph_row)
	_reparent_if_valid(crash_pulse_graph, graph_row)
	_reparent_if_valid(deformation_graph, graph_row)
	if crash_pulse_graph != null:
		crash_pulse_graph.custom_minimum_size = Vector2(220.0, 92.0)
	if deformation_graph != null:
		deformation_graph.custom_minimum_size = Vector2(220.0, 92.0)

func _build_status_chip() -> void:
	m10_status_chip = PanelContainer.new()
	m10_status_chip.name = "M16StatusChip"
	m10_status_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m10_status_chip.add_theme_stylebox_override("panel", CrashVectorM16Theme.chip())
	m10_root.add_child(m10_status_chip)
	m10_status_label = Label.new()
	m10_status_label.text = "Ready"
	m10_status_label.add_theme_font_size_override("font_size", 12)
	m10_status_chip.add_child(m10_status_label)
	_build_m16_viewport_toolbar()

func _build_m16_viewport_toolbar() -> void:
	m16_viewport_toolbar = PanelContainer.new()
	m16_viewport_toolbar.name = "M16ViewportToolbar"
	m10_root.add_child(m16_viewport_toolbar)
	var margin := _margin(m16_viewport_toolbar, 6, 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	margin.add_child(row)
	_add_button(row, "Fit", _frame_scenario, "Frame the whole scenario")
	_add_button(row, "Side", _on_camera_side, "Side technical view")
	_add_button(row, "Front", _on_camera_front, "Front view")
	_add_button(row, "Top", _on_camera_top, "Top view")
	var separator := VSeparator.new()
	row.add_child(separator)
	m10_structure = CheckButton.new()
	m10_structure.text = "Structure"
	m10_structure.tooltip_text = "Show the structural X-ray"
	m10_structure.toggled.connect(_on_structure_toggled)
	row.add_child(m10_structure)
	m10_vectors = CheckButton.new()
	m10_vectors.text = "Vectors"
	m10_vectors.tooltip_text = "Show velocity and momentum vectors"
	m10_vectors.button_pressed = vectors_check == null or vectors_check.button_pressed
	m10_vectors.toggled.connect(_on_vectors_toggled)
	row.add_child(m10_vectors)

func _layout_m10() -> void:
	if m10_root == null:
		return
	var size := get_viewport().get_visible_rect().size
	var compare_view := m10_mode == MODE_COMPARE or comparison_active
	var top_y := 70.0
	_set_rect(m10_top_bar, 12.0, 10.0, size.x - 12.0, 60.0)
	if compare_view:
		_set_rect(m10_viewport_frame, 12.0, top_y, size.x - 12.0, size.y - 12.0)
		_set_rect(m10_compare_header, 22.0, top_y + 10.0, size.x - 22.0, top_y + 68.0)
		if comparison_active:
			_set_rect(m10_compare_results, 22.0, size.y - 238.0, size.x - 22.0, size.y - 18.0)
		_layout_m16_modals(size)
		return

	var compact := size.x < 1420.0
	var left_width := 242.0 if compact else 262.0
	var right_width := 300.0 if compact else 326.0
	var gap := 12.0
	var bottom_height := 250.0 if m10_replay_expanded else 66.0
	var bottom_margin := 12.0
	var content_bottom := size.y - bottom_height - bottom_margin - gap
	var left_x := 12.0
	var viewport_left := left_x + left_width + gap
	var right_left := size.x - 12.0 - right_width
	var viewport_right := right_left - gap

	if size.x < 1160.0:
		m10_right_panel.visible = false
		right_left = size.x - 12.0
		viewport_right = right_left
	if size.x < 940.0:
		m10_left_panel.visible = false
		viewport_left = 12.0

	_set_rect(m10_left_panel, left_x, top_y, left_x + left_width, content_bottom)
	_set_rect(m10_right_panel, right_left, top_y, size.x - 12.0, content_bottom)
	_set_rect(m10_viewport_frame, viewport_left, top_y, viewport_right, content_bottom)
	_set_rect(m10_replay_drawer, viewport_left, size.y - bottom_height - bottom_margin, viewport_right, size.y - bottom_margin)
	_set_rect(m10_status_chip, viewport_left + 12.0, top_y + 12.0, minf(viewport_left + 310.0, viewport_right - 12.0), top_y + 44.0)
	var toolbar_width := minf(470.0, maxf(viewport_right - viewport_left - 24.0, 260.0))
	_set_rect(m16_viewport_toolbar, viewport_right - toolbar_width - 12.0, top_y + 12.0, viewport_right - 12.0, top_y + 52.0)
	_layout_m16_modals(size)

func _layout_non_recursive() -> void:
	_layout_m10()

func _layout_m16_modals(size: Vector2) -> void:
	var modal_width := minf(760.0, size.x - 80.0)
	var modal_height := minf(540.0, size.y - 80.0)
	_set_centered_rect(m10_about_panel, minf(520.0, size.x - 80.0), minf(390.0, size.y - 80.0))
	for panel in [update_panel, export_settings_panel, calibration_panel, comparison_lab_panel]:
		if panel != null and is_instance_valid(panel):
			_set_centered_rect(panel, modal_width, modal_height)

func _refresh_m10_mode() -> void:
	if m10_root == null:
		return
	var compare_view := m10_mode == MODE_COMPARE or comparison_active
	m10_left_panel.visible = not compare_view
	m10_right_panel.visible = not compare_view
	m10_replay_drawer.visible = not compare_view
	m16_viewport_toolbar.visible = not compare_view
	m10_compare_header.visible = m10_mode == MODE_COMPARE and not comparison_active
	m10_compare_results.visible = comparison_active
	m10_status_chip.visible = not comparison_active
	m10_scenario_button.disabled = not compare_view
	m10_compare_button.disabled = compare_view and not comparison_active
	_layout_m10()

func _sync_m10_from_scenario() -> void:
	super._sync_m10_from_scenario()
	if m16_primary_properties == null:
		return
	var target_selected := selected_object == &"target"
	m16_primary_properties.visible = not target_selected
	m16_target_properties.visible = target_selected
	m16_selected_title.text = ScenarioConfig.target_display_name(scenario.target_type) if target_selected else PassengerCarCatalog.display_name(scenario.car_preset_id)
	CrashVectorM16Theme.selected_button(m16_primary_button, not target_selected)
	CrashVectorM16Theme.selected_button(m16_target_button, target_selected)
	m16_target_button.text = "Target · %s" % ScenarioConfig.target_display_name(scenario.target_type)

func _refresh_m10_runtime_state() -> void:
	if m10_status_label == null:
		return
	var current_status := status_label.text if status_label != null else "Ready"
	m10_status_label.text = _truncate(current_status, 64)
	m10_status_label.tooltip_text = current_status
	m10_pause_button.visible = simulation_running
	m10_pause_button.text = "▶ Resume" if simulation_paused else "⏸ Pause"
	var has_replay := replay_recorder != null and replay_recorder.recording != null and replay_recorder.recording.has_frames()
	m10_reset_button.visible = not simulation_running and has_replay
	m10_simulate_button.visible = not simulation_running and not comparison_active and not has_replay
	m10_simulate_button.disabled = comparison_active
	m10_video_button.visible = has_replay and not simulation_running
	m10_video_button.disabled = export_button != null and export_button.disabled
	if m16_results_hint != null:
		if simulation_running:
			m16_results_hint.text = "Simulation running. Playback and analysis become available when the run completes."
		elif has_replay:
			m16_results_hint.text = "Run complete. Use the playback dock and Analysis for crash metrics and graphs."
		else:
			m16_results_hint.text = "Run the scenario to populate replay and analysis."
	if m16_more_menu != null and updates_button != null and updates_button.text.begins_with("Updates •"):
		m16_more_menu.text = "More •"
	elif m16_more_menu != null:
		m16_more_menu.text = "More ⋯"

func _on_m16_file_action(id: int) -> void:
	match id:
		1: _on_new_pressed()
		2: _on_open_pressed()

func _on_m16_more_action(id: int) -> void:
	match id:
		10: _on_m10_calibration_pressed()
		11: _on_updates_button_pressed()
		12: _on_m10_about_pressed()

func _on_m16_select_primary() -> void:
	selected_object = &"car"
	_sync_m10_from_scenario()

func _on_m16_select_target() -> void:
	selected_object = &"target"
	_sync_m10_from_scenario()

func _on_m16_advanced_toggled() -> void:
	m16_advanced_container.visible = not m16_advanced_container.visible
	m16_advanced_toggle.text = "Advanced setup ▾" if m16_advanced_container.visible else "Advanced setup ▸"

func _apply_m16_vehicle_visuals() -> void:
	_ensure_m16_vehicle_visual(car, "M16PrimaryVehicleVisual")
	_ensure_m16_vehicle_visual(target_car, "M16TargetVehicleVisual")

func _ensure_m16_vehicle_visual(vehicle_node: CompactHatchback, node_name: String) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return
	if vehicle_node.get_node_or_null(node_name) != null:
		return
	var visual := M16VehicleVisual.new()
	vehicle_node.add_child(visual)
	visual.configure(vehicle_node)
	visual.name = node_name

func _add_m16_section_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", CrashVectorM16Theme.MUTED)
	parent.add_child(label)

func _add_m16_field_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", CrashVectorM16Theme.MUTED)
	parent.add_child(label)
