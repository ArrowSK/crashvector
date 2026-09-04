# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m9.gd"

const M10_VERSION := "0.2.0-beta.1"
const MODE_SCENARIO: StringName = &"scenario"
const MODE_COMPARE: StringName = &"compare"

var m10_canvas: CanvasLayer
var m10_root: Control
var m10_top_bar: PanelContainer
var m10_left_panel: PanelContainer
var m10_right_panel: PanelContainer
var m10_viewport_frame: PanelContainer
var m10_replay_drawer: PanelContainer
var m10_replay_content: VBoxContainer
var m10_compare_header: PanelContainer
var m10_compare_results: PanelContainer
var m10_compare_grid: GridContainer
var m10_compare_timeline: HSlider
var m10_compare_time: Label
var m10_compare_play: Button
var m10_about_panel: PanelContainer
var m10_status_chip: PanelContainer
var m10_status_label: Label
var m10_scope_chip: Button
var m10_scenario_button: Button
var m10_compare_button: Button
var m10_simulate_button: Button
var m10_pause_button: Button
var m10_reset_button: Button
var m10_replay_toggle: Button
var m10_video_button: Button
var m10_calibration_button: Button
var m10_updates_button: Button
var m10_title_edit: LineEdit
var m10_primary_option: OptionButton
var m10_target_option: OptionButton
var m10_primary_class: OptionButton
var m10_target_preset: OptionButton
var m10_vehicle_mass: SpinBox
var m10_vehicle_speed: SpinBox
var m10_vehicle_x: SpinBox
var m10_vehicle_z: SpinBox
var m10_vehicle_heading: SpinBox
var m10_target_mass: SpinBox
var m10_target_speed: SpinBox
var m10_target_x: SpinBox
var m10_target_z: SpinBox
var m10_target_heading: SpinBox
var m10_duration: SpinBox
var m10_friction: SpinBox
var m10_restitution: SpinBox
var m10_substeps: SpinBox
var m10_structure: CheckButton
var m10_primary_paint: OptionButton
var m10_target_paint: OptionButton
var m10_vectors: CheckButton
var m10_compare_mode: OptionButton
var m10_compare_speed_a: SpinBox
var m10_compare_speed_b: SpinBox
var m10_compare_speed_c: SpinBox
var m10_compare_use_c: CheckButton
var m10_compare_run: Button
var m10_save_dialog: FileDialog
var m10_open_dialog: FileDialog
var m10_selection_ring: MeshInstance3D
var m10_environment_root: Node3D
var m10_inspector_tabs: TabContainer
var m10_target_preset_row: HBoxContainer
var m10_target_mass_row: HBoxContainer
var m10_target_speed_row: HBoxContainer
var m10_target_paint_row: HBoxContainer
var m10_camera_hint: Label
var m10_metrics_summary: Label
var m10_mode: StringName = MODE_SCENARIO
var m10_replay_expanded := false
var m10_syncing := false
var m10_primary_paint_id: StringName = CarPaintCatalog.ELECTRIC_BLUE
var m10_target_paint_id: StringName = CarPaintCatalog.SILVER
var m10_first_run_applied := false

func _ready() -> void:
	super._ready()
	_apply_m10_first_run_default()
	_build_m10_environment()
	_build_m10_ui()
	_adopt_legacy_panels()
	_hide_legacy_ui()
	_sync_m10_from_scenario()
	_refresh_m10_mode()
	_refresh_m10_runtime_state()
	get_viewport().size_changed.connect(_layout_m10)
	_layout_m10()
	_frame_scenario()

func _process(delta: float) -> void:
	super._process(delta)
	if m10_root == null:
		return
	_refresh_m10_runtime_state()
	_update_selection_ring()
	_sync_m10_replay_runtime()
	_sync_m10_comparison_runtime()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if m10_root != null:
		_refresh_m10_runtime_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not simulation_running and not comparison_active:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(0.88)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(1.14)
			return
	super._unhandled_input(event)
	if m10_root != null and not simulation_running and not comparison_active:
		_sync_m10_from_scenario()

func _set_base_ui_visible(value: bool) -> void:
	super._set_base_ui_visible(value)
	_hide_legacy_ui()
	if m10_canvas != null:
		m10_canvas.visible = true
	if m10_root != null:
		_refresh_m10_mode()

func _rebuild_preview() -> void:
	super._rebuild_preview()
	_apply_m10_paints()
	if m10_root != null:
		_sync_m10_from_scenario()
		_refresh_m10_runtime_state()

func _rebuild_inspector() -> void:
	super._rebuild_inspector()
	if m10_root != null:
		_sync_m10_from_scenario()

func _sync_ui_from_scenario() -> void:
	super._sync_ui_from_scenario()
	if m10_root != null:
		_sync_m10_from_scenario()

func _move_selected(delta_m: Vector3) -> void:
	super._move_selected(delta_m)
	if m10_root != null:
		_sync_m10_from_scenario()

func _rotate_selected(delta_deg: float) -> void:
	super._rotate_selected(delta_deg)
	if m10_root != null:
		_sync_m10_from_scenario()

func _on_new_pressed() -> void:
	super._on_new_pressed()
	_apply_m10_first_run_default(true)
	_sync_m10_from_scenario()
	_frame_scenario()

func _on_save_pressed() -> void:
	if m10_title_edit != null:
		scenario.title = m10_title_edit.text
	var errors := scenario.validation_errors()
	if not errors.is_empty():
		status_label.text = "Cannot save: %s" % "; ".join(errors)
		return
	if current_scenario_path.is_empty():
		m10_save_dialog.popup_centered(Vector2i(880, 620))
		return
	_save_scenario(current_scenario_path)

func _on_open_pressed() -> void:
	m10_open_dialog.popup_centered(Vector2i(880, 620))

func _on_open_path_selected(path: String) -> void:
	super._on_open_path_selected(path)
	_sync_m10_from_scenario()
	_apply_m10_paints()

func _on_simulate_pressed() -> void:
	super._on_simulate_pressed()
	_refresh_m10_runtime_state()

func _on_reset_pressed() -> void:
	super._on_reset_pressed()
	_refresh_m10_runtime_state()

func _apply_m10_first_run_default(force: bool = false) -> void:
	if m10_first_run_applied and not force:
		return
	if not force and (not current_scenario_path.is_empty() or scenario.title != "Car vs Truck"):
		return
	m10_first_run_applied = true
	scenario.title = "B-Class vs Rigid Wall"
	scenario.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	scenario.car_mass_kg = PassengerCarCatalog.default_mass_kg(scenario.car_preset_id)
	scenario.car_speed_kmh = 50.0
	scenario.car_position_m = Vector3(-5.6, 0.0, 0.0)
	scenario.car_heading_deg = 0.0
	scenario.apply_target_defaults(ScenarioConfig.TARGET_WALL)
	scenario.target_position_m = Vector3(3.2, 0.0, 0.0)
	scenario.target_heading_deg = 0.0
	selected_object = &"car"
	_rebuild_preview()

func _build_m10_ui() -> void:
	m10_canvas = CanvasLayer.new()
	m10_canvas.name = "M10UI"
	m10_canvas.layer = 20
	add_child(m10_canvas)
	m10_root = Control.new()
	m10_root.name = "M10Root"
	m10_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m10_root.theme = CrashVectorM10Theme.build()
	m10_canvas.add_child(m10_root)

	_build_top_bar()
	_build_scenario_panel()
	_build_inspector()
	_build_viewport_frame()
	_build_replay_drawer()
	_build_compare_workspace()
	_build_status_chip()
	_build_about_panel()
	_build_file_dialogs()

func _build_top_bar() -> void:
	m10_top_bar = PanelContainer.new()
	m10_top_bar.name = "M10TopBar"
	m10_root.add_child(m10_top_bar)
	var margin := _margin(m10_top_bar, 8, 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var brand := Label.new()
	brand.text = "CrashVector"
	brand.add_theme_font_size_override("font_size", 19)
	brand.custom_minimum_size.x = 130.0
	row.add_child(brand)
	_add_button(row, "New", _on_new_pressed, "New scenario")
	_add_button(row, "Open", _on_open_pressed, "Open .crashvector.json")
	_add_button(row, "Save", _on_save_pressed, "Save scenario")

	var file_separator := VSeparator.new()
	row.add_child(file_separator)
	m10_scenario_button = _add_button(row, "Scenario", _on_m10_scenario_mode, "Scenario editor")
	m10_compare_button = _add_button(row, "Compare", _on_m10_compare_mode, "Comparison workspace")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	m10_pause_button = _add_button(row, "Pause", _on_pause_pressed, "Pause or resume simulation")
	m10_pause_button.visible = false
	m10_reset_button = _add_button(row, "Reset", _on_reset_pressed, "Return to editable preview")
	m10_reset_button.visible = false
	m10_simulate_button = _add_button(row, "Simulate", _on_simulate_pressed, "Run the current scenario")
	CrashVectorM10Theme.accent_button(m10_simulate_button)
	m10_video_button = _add_button(row, "Video", _on_m10_video_pressed, "Cinematic video export")
	m10_calibration_button = _add_button(row, "Calibration", _on_m10_calibration_pressed, "Calibration and evidence scope")
	m10_updates_button = _add_button(row, "Updates", _on_updates_button_pressed, "Check for CrashVector updates")
	_add_button(row, "About", _on_m10_about_pressed, "About CrashVector")

func _build_scenario_panel() -> void:
	m10_left_panel = PanelContainer.new()
	m10_left_panel.name = "M10ScenarioPanel"
	m10_root.add_child(m10_left_panel)
	var margin := _margin(m10_left_panel, 12, 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "SCENARIO"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	column.add_child(heading)

	m10_title_edit = LineEdit.new()
	m10_title_edit.name = "ScenarioTitle"
	m10_title_edit.placeholder_text = "Scenario name"
	m10_title_edit.text_changed.connect(func(value: String) -> void:
		if not m10_syncing:
			scenario.title = value
	)
	column.add_child(m10_title_edit)

	_add_small_label(column, "Primary vehicle")
	m10_primary_option = OptionButton.new()
	for id in PassengerCarCatalog.preset_ids():
		m10_primary_option.add_item(PassengerCarCatalog.display_name(id))
		m10_primary_option.set_item_metadata(m10_primary_option.item_count - 1, id)
	m10_primary_option.item_selected.connect(_on_m10_primary_class_selected)
	column.add_child(m10_primary_option)

	_add_small_label(column, "Impact target")
	m10_target_option = OptionButton.new()
	for id in ScenarioConfig.target_ids():
		m10_target_option.add_item(ScenarioConfig.target_display_name(id))
		m10_target_option.set_item_metadata(m10_target_option.item_count - 1, id)
	m10_target_option.item_selected.connect(_on_m10_target_selected)
	column.add_child(m10_target_option)

	_add_small_label(column, "Quick targets")
	var quick := GridContainer.new()
	quick.columns = 2
	column.add_child(quick)
	_add_quick_target(quick, "Wall", ScenarioConfig.TARGET_WALL)
	_add_quick_target(quick, "Car", ScenarioConfig.TARGET_PASSENGER_CAR)
	_add_quick_target(quick, "Truck", ScenarioConfig.TARGET_TRUCK)
	_add_quick_target(quick, "Lorry", ScenarioConfig.TARGET_LORRY)
	_add_quick_target(quick, "Pedestrian", ScenarioConfig.TARGET_PEDESTRIAN)
	_add_quick_target(quick, "Bicycle", ScenarioConfig.TARGET_BICYCLE)

	var separator := HSeparator.new()
	column.add_child(separator)
	_add_small_label(column, "View")
	var camera_grid := GridContainer.new()
	camera_grid.columns = 2
	column.add_child(camera_grid)
	_add_button(camera_grid, "Side", _on_camera_side, "Side technical view")
	_add_button(camera_grid, "3/4", _frame_scenario, "Framed three-quarter view")
	_add_button(camera_grid, "Front", _on_camera_front, "Front view")
	_add_button(camera_grid, "Top", _on_camera_top, "Top view")

	m10_camera_hint = Label.new()
	m10_camera_hint.text = "Click an object to select it. Left-drag moves; right-drag rotates. Mouse wheel zooms."
	m10_camera_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m10_camera_hint.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	m10_camera_hint.add_theme_font_size_override("font_size", 12)
	column.add_child(m10_camera_hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	m10_metrics_summary = Label.new()
	m10_metrics_summary.name = "ScenarioSummary"
	m10_metrics_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m10_metrics_summary.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	m10_metrics_summary.add_theme_font_size_override("font_size", 12)
	column.add_child(m10_metrics_summary)

func _build_inspector() -> void:
	m10_right_panel = PanelContainer.new()
	m10_right_panel.name = "M10Inspector"
	m10_root.add_child(m10_right_panel)
	var margin := _margin(m10_right_panel, 9, 9)
	m10_inspector_tabs = TabContainer.new()
	m10_inspector_tabs.name = "InspectorTabs"
	m10_inspector_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(m10_inspector_tabs)
	_build_vehicle_tab()
	_build_target_tab()
	_build_physics_tab()
	_build_appearance_tab()

func _build_vehicle_tab() -> void:
	var scroll := _tab_scroll("Vehicle")
	var column := _scroll_column(scroll)
	m10_primary_class = _option_row(column, "Class")
	for id in PassengerCarCatalog.preset_ids():
		m10_primary_class.add_item(PassengerCarCatalog.display_name(id))
		m10_primary_class.set_item_metadata(m10_primary_class.item_count - 1, id)
	m10_primary_class.item_selected.connect(_on_m10_primary_class_selected)
	m10_vehicle_mass = _spin_row(column, "Mass", 500.0, 5000.0, 5.0, " kg")
	m10_vehicle_speed = _spin_row(column, "Speed", 0.0, 300.0, 1.0, " km/h")
	m10_vehicle_x = _spin_row(column, "Position X", -25.0, 25.0, 0.1, " m")
	m10_vehicle_z = _spin_row(column, "Position Z", -8.0, 8.0, 0.1, " m")
	m10_vehicle_heading = _spin_row(column, "Heading", -180.0, 180.0, 1.0, "°")
	m10_vehicle_mass.value_changed.connect(_on_m10_vehicle_value.bind(&"mass"))
	m10_vehicle_speed.value_changed.connect(_on_m10_vehicle_value.bind(&"speed"))
	m10_vehicle_x.value_changed.connect(_on_m10_vehicle_value.bind(&"x"))
	m10_vehicle_z.value_changed.connect(_on_m10_vehicle_value.bind(&"z"))
	m10_vehicle_heading.value_changed.connect(_on_m10_vehicle_value.bind(&"heading"))
	var note := Label.new()
	note.text = "Generic vehicle classes represent size/proportion families, not production models or manufacturer crash performance."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	column.add_child(note)

func _build_target_tab() -> void:
	var scroll := _tab_scroll("Target")
	var column := _scroll_column(scroll)
	m10_target_preset_row = HBoxContainer.new()
	column.add_child(m10_target_preset_row)
	var preset_label := Label.new()
	preset_label.text = "Preset"
	preset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m10_target_preset_row.add_child(preset_label)
	m10_target_preset = OptionButton.new()
	m10_target_preset.custom_minimum_size.x = 170.0
	m10_target_preset.item_selected.connect(_on_m10_target_preset_selected)
	m10_target_preset_row.add_child(m10_target_preset)

	var mass_data := _spin_row_with_row(column, "Mass", 0.0, 60000.0, 5.0, " kg")
	m10_target_mass_row = mass_data[0]
	m10_target_mass = mass_data[1]
	var speed_data := _spin_row_with_row(column, "Speed", 0.0, 300.0, 1.0, " km/h")
	m10_target_speed_row = speed_data[0]
	m10_target_speed = speed_data[1]
	m10_target_x = _spin_row(column, "Position X", -25.0, 25.0, 0.1, " m")
	m10_target_z = _spin_row(column, "Position Z", -8.0, 8.0, 0.1, " m")
	m10_target_heading = _spin_row(column, "Heading", -180.0, 180.0, 1.0, "°")
	m10_target_mass.value_changed.connect(_on_m10_target_value.bind(&"mass"))
	m10_target_speed.value_changed.connect(_on_m10_target_value.bind(&"speed"))
	m10_target_x.value_changed.connect(_on_m10_target_value.bind(&"x"))
	m10_target_z.value_changed.connect(_on_m10_target_value.bind(&"z"))
	m10_target_heading.value_changed.connect(_on_m10_target_value.bind(&"heading"))
	var hint := Label.new()
	hint.name = "TargetScopeHint"
	hint.text = "Target-specific constraints remain exactly those of the M0–M9 solver."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	column.add_child(hint)

func _build_physics_tab() -> void:
	var scroll := _tab_scroll("Physics")
	var column := _scroll_column(scroll)
	m10_duration = _spin_row(column, "Duration", 0.5, 20.0, 0.5, " s")
	m10_friction = _spin_row(column, "Contact friction", 0.0, 1.5, 0.05, "")
	m10_restitution = _spin_row(column, "Restitution", 0.0, 0.5, 0.01, "")
	m10_substeps = _spin_row(column, "Solver substeps", 1.0, 16.0, 1.0, "")
	m10_duration.value_changed.connect(_on_m10_physics_value.bind(&"duration"))
	m10_friction.value_changed.connect(_on_m10_physics_value.bind(&"friction"))
	m10_restitution.value_changed.connect(_on_m10_physics_value.bind(&"restitution"))
	m10_substeps.value_changed.connect(_on_m10_physics_value.bind(&"substeps"))
	m10_structure = CheckButton.new()
	m10_structure.text = "Show structural X-ray"
	m10_structure.toggled.connect(_on_structure_toggled)
	column.add_child(m10_structure)
	m10_scope_chip = Button.new()
	m10_scope_chip.name = "EvidenceScopeChip"
	m10_scope_chip.text = "Evidence scope"
	m10_scope_chip.tooltip_text = "Open calibration/evidence information"
	m10_scope_chip.pressed.connect(_on_m10_calibration_pressed)
	column.add_child(m10_scope_chip)
	var warning := Label.new()
	warning.text = "Advanced contact/solver values change the numerical scenario. Presentation controls do not."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	column.add_child(warning)

func _build_appearance_tab() -> void:
	var scroll := _tab_scroll("Appearance")
	var column := _scroll_column(scroll)
	m10_primary_paint = _option_row(column, "Primary paint")
	_populate_m10_paints(m10_primary_paint, m10_primary_paint_id)
	m10_primary_paint.item_selected.connect(_on_m10_primary_paint)
	var target_paint_data := _option_row_with_row(column, "Target paint")
	m10_target_paint_row = target_paint_data[0]
	m10_target_paint = target_paint_data[1]
	_populate_m10_paints(m10_target_paint, m10_target_paint_id)
	m10_target_paint.item_selected.connect(_on_m10_target_paint)
	m10_vectors = CheckButton.new()
	m10_vectors.text = "Velocity / momentum vectors"
	m10_vectors.button_pressed = vectors_check == null or vectors_check.button_pressed
	m10_vectors.toggled.connect(_on_vectors_toggled)
	column.add_child(m10_vectors)
	_add_small_label(column, "Camera")
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	_add_button(grid, "Side", _on_camera_side)
	_add_button(grid, "3/4", _frame_scenario)
	_add_button(grid, "Front", _on_camera_front)
	_add_button(grid, "Top", _on_camera_top)
	var note := Label.new()
	note.text = "Paint, camera, lighting and overlays are presentation-only and never alter the structural solver."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	column.add_child(note)

func _build_viewport_frame() -> void:
	m10_viewport_frame = PanelContainer.new()
	m10_viewport_frame.name = "M10ViewportFrame"
	m10_viewport_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color("314054")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	m10_viewport_frame.add_theme_stylebox_override("panel", style)
	m10_root.add_child(m10_viewport_frame)

func _build_replay_drawer() -> void:
	m10_replay_drawer = PanelContainer.new()
	m10_replay_drawer.name = "M10ReplayDrawer"
	m10_root.add_child(m10_replay_drawer)
	var margin := _margin(m10_replay_drawer, 9, 7)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.name = "ReplayHeader"
	column.add_child(header)
	m10_replay_toggle = Button.new()
	m10_replay_toggle.text = "Analysis ▴"
	m10_replay_toggle.pressed.connect(_toggle_replay_drawer)
	header.add_child(m10_replay_toggle)

	_reparent_if_valid(replay_button, header)
	_reparent_if_valid(replay_speed_option, header)
	var timeline_holder := Control.new()
	timeline_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_holder.custom_minimum_size.x = 160.0
	header.add_child(timeline_holder)
	if timeline_slider != null:
		timeline_slider.reparent(timeline_holder, false)
		timeline_slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reparent_if_valid(replay_time_label, header)

	m10_replay_content = VBoxContainer.new()
	m10_replay_content.name = "ReplayAnalysisContent"
	m10_replay_content.visible = false
	column.add_child(m10_replay_content)
	var toggles := HBoxContainer.new()
	m10_replay_content.add_child(toggles)
	_reparent_if_valid(vectors_check, toggles)
	_reparent_if_valid(analysis_summary_label, m10_replay_content)
	_reparent_if_valid(event_markers_label, m10_replay_content)
	var graph_row := HBoxContainer.new()
	graph_row.add_theme_constant_override("separation", 8)
	graph_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m10_replay_content.add_child(graph_row)
	_reparent_if_valid(crash_pulse_graph, graph_row)
	_reparent_if_valid(deformation_graph, graph_row)
	if crash_pulse_graph != null:
		crash_pulse_graph.custom_minimum_size = Vector2(220.0, 92.0)
	if deformation_graph != null:
		deformation_graph.custom_minimum_size = Vector2(220.0, 92.0)

func _build_compare_workspace() -> void:
	m10_compare_header = PanelContainer.new()
	m10_compare_header.name = "M10CompareHeader"
	m10_compare_header.visible = false
	m10_root.add_child(m10_compare_header)
	var margin := _margin(m10_compare_header, 10, 7)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)
	var label := Label.new()
	label.text = "COMPARE"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	row.add_child(label)
	m10_compare_mode = OptionButton.new()
	m10_compare_mode.add_item("Custom speeds")
	m10_compare_mode.set_item_metadata(0, MODE_SPEED)
	m10_compare_mode.add_item("B / C / D classes")
	m10_compare_mode.set_item_metadata(1, MODE_CLASS)
	m10_compare_mode.add_item("Comparison Lab…")
	m10_compare_mode.set_item_metadata(2, &"lab")
	m10_compare_mode.item_selected.connect(_on_m10_compare_mode_selected)
	row.add_child(m10_compare_mode)
	m10_compare_speed_a = _compact_speed_spin(50.0)
	m10_compare_speed_b = _compact_speed_spin(90.0)
	m10_compare_speed_c = _compact_speed_spin(140.0)
	row.add_child(m10_compare_speed_a)
	row.add_child(m10_compare_speed_b)
	row.add_child(m10_compare_speed_c)
	m10_compare_use_c = CheckButton.new()
	m10_compare_use_c.text = "3rd"
	m10_compare_use_c.button_pressed = true
	m10_compare_use_c.toggled.connect(func(value: bool) -> void: m10_compare_speed_c.editable = value)
	row.add_child(m10_compare_use_c)
	m10_compare_run = Button.new()
	m10_compare_run.text = "Run comparison"
	m10_compare_run.pressed.connect(_on_m10_run_comparison)
	CrashVectorM10Theme.accent_button(m10_compare_run)
	row.add_child(m10_compare_run)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_add_button(row, "Back", _on_m10_scenario_mode)

	m10_compare_results = PanelContainer.new()
	m10_compare_results.name = "M10CompareResults"
	m10_compare_results.visible = false
	m10_root.add_child(m10_compare_results)
	var result_margin := _margin(m10_compare_results, 10, 7)
	var result_column := VBoxContainer.new()
	result_column.add_theme_constant_override("separation", 5)
	result_margin.add_child(result_column)
	var playback := HBoxContainer.new()
	result_column.add_child(playback)
	m10_compare_play = Button.new()
	m10_compare_play.text = "Play"
	m10_compare_play.pressed.connect(_on_m10_compare_play)
	playback.add_child(m10_compare_play)
	m10_compare_time = Label.new()
	m10_compare_time.text = "—"
	playback.add_child(m10_compare_time)
	m10_compare_timeline = HSlider.new()
	m10_compare_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m10_compare_timeline.editable = false
	m10_compare_timeline.value_changed.connect(_on_m10_compare_timeline)
	playback.add_child(m10_compare_timeline)
	_add_button(playback, "Exit comparison", _on_m10_exit_comparison)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_column.add_child(scroll)
	m10_compare_grid = GridContainer.new()
	m10_compare_grid.columns = 3
	m10_compare_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(m10_compare_grid)

func _build_status_chip() -> void:
	m10_status_chip = PanelContainer.new()
	m10_status_chip.name = "M10StatusChip"
	m10_status_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m10_status_chip.add_theme_stylebox_override("panel", CrashVectorM10Theme.chip(m10_status_chip, CrashVectorM10Theme.SUCCESS))
	m10_root.add_child(m10_status_chip)
	m10_status_label = Label.new()
	m10_status_label.text = "Ready"
	m10_status_label.add_theme_font_size_override("font_size", 12)
	m10_status_chip.add_child(m10_status_label)

func _build_about_panel() -> void:
	m10_about_panel = PanelContainer.new()
	m10_about_panel.name = "M10AboutPanel"
	m10_about_panel.visible = false
	m10_root.add_child(m10_about_panel)
	var margin := _margin(m10_about_panel, 22, 18)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var title := Label.new()
	title.text = "CrashVector"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var version := Label.new()
	version.text = String(ProjectSettings.get_setting("application/config/version", M10_VERSION))
	version.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	column.add_child(version)
	var body := Label.new()
	body.text = "Educational 3D vehicle collision simulator\n\nBuild a crash. Change the speed. Compare the outcome.\n\nCrashVector is not certified accident reconstruction, homologation, biomechanics, medical/injury prediction or a safety-rating system.\n\nSource licence: MPL-2.0"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: m10_about_panel.visible = false)
	column.add_child(close)

func _build_file_dialogs() -> void:
	m10_save_dialog = FileDialog.new()
	m10_save_dialog.name = "M10SaveDialog"
	m10_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	m10_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	m10_save_dialog.filters = PackedStringArray(["*.crashvector.json ; CrashVector Scenario"])
	m10_save_dialog.file_selected.connect(_on_save_path_selected)
	m10_root.add_child(m10_save_dialog)
	m10_open_dialog = FileDialog.new()
	m10_open_dialog.name = "M10OpenDialog"
	m10_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	m10_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	m10_open_dialog.filters = PackedStringArray(["*.crashvector.json ; CrashVector Scenario", "*.json ; JSON"])
	m10_open_dialog.file_selected.connect(_on_open_path_selected)
	m10_root.add_child(m10_open_dialog)

func _adopt_legacy_panels() -> void:
	# Reparent only modal content or active controls. The old fixed-position launchers
	# stay hidden; their proven behaviour/services remain intact underneath M10.
	for control in [update_panel, export_settings_panel, calibration_panel, comparison_lab_panel]:
		if control != null and is_instance_valid(control):
			control.reparent(m10_root, false)
	if export_file_dialog != null and is_instance_valid(export_file_dialog):
		export_file_dialog.reparent(m10_root, false)
	if update_panel != null:
		update_panel.theme = m10_root.theme
	if export_settings_panel != null:
		export_settings_panel.theme = m10_root.theme
	if calibration_panel != null:
		calibration_panel.theme = m10_root.theme
	if comparison_lab_panel != null:
		comparison_lab_panel.theme = m10_root.theme

func _hide_legacy_ui() -> void:
	for node_name in ["EditorUI", "M5AnalysisUI", "M6ComparisonUI", "M7ExportUI", "M8CalibrationUI", "RoadUserComparisonLabUI", "M9UpdateUI"]:
		var layer := get_node_or_null(node_name) as CanvasLayer
		if layer != null:
			layer.visible = false

func _build_m10_environment() -> void:
	m10_environment_root = Node3D.new()
	m10_environment_root.name = "M10PresentationEnvironment"
	add_child(m10_environment_root)
	# Hide only the old development meshes. Their StaticBody collisions remain in
	# place, so this presentation pass cannot change solver behaviour.
	for child in get_children():
		if child is StaticBody3D and (String(child.name) == "Road" or String(child.name).begins_with("LaneMark")):
			for visual in child.get_children():
				if visual is MeshInstance3D:
					visual.visible = false

	var world_environment := _find_world_environment()
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("536f91")
		sky_material.sky_horizon_color = Color("b9c8d8")
		sky_material.ground_horizon_color = Color("9ba9a8")
		sky_material.ground_bottom_color = Color("4b5555")
		var sky := Sky.new()
		sky.sky_material = sky_material
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.68

	for child in get_children():
		if child is DirectionalLight3D:
			child.light_energy = 1.22
			child.light_color = Color("fff1dc")
			child.shadow_enabled = true

	_add_visual_box("TechnicalGround", Vector3(2.0, -0.10, 0.0), Vector3(82.0, 0.16, 46.0), Color("6e7776"), 1.0)
	_add_visual_box("AsphaltSurface", Vector3(2.0, 0.006, 0.0), Vector3(54.0, 0.012, 12.2), Color("30353b"), 0.92)
	_add_visual_box("LeftShoulder", Vector3(2.0, 0.012, -6.35), Vector3(54.0, 0.022, 0.55), Color("9b9d96"), 0.88)
	_add_visual_box("RightShoulder", Vector3(2.0, 0.012, 6.35), Vector3(54.0, 0.022, 0.55), Color("9b9d96"), 0.88)
	for x in range(-22, 27, 4):
		_add_visual_box("CentreMark%d" % x, Vector3(float(x), 0.025, 0.0), Vector3(2.1, 0.018, 0.09), Color("e4e5dd"), 0.75)
	_add_visual_box("EdgeLineL", Vector3(2.0, 0.024, -5.55), Vector3(54.0, 0.018, 0.08), Color("e4e5dd"), 0.75)
	_add_visual_box("EdgeLineR", Vector3(2.0, 0.024, 5.55), Vector3(54.0, 0.018, 0.08), Color("e4e5dd"), 0.75)

	m10_selection_ring = MeshInstance3D.new()
	m10_selection_ring.name = "SelectionMarker"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.8
	ring_mesh.bottom_radius = 1.8
	ring_mesh.height = 0.018
	ring_mesh.radial_segments = 48
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.32, 0.16, 0.25)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mesh.material = ring_material
	m10_selection_ring.mesh = ring_mesh
	m10_selection_ring.position.y = 0.035
	m10_environment_root.add_child(m10_selection_ring)

func _find_world_environment() -> WorldEnvironment:
	for child in get_children():
		if child is WorldEnvironment:
			return child as WorldEnvironment
	return null

func _add_visual_box(node_name: String, position: Vector3, size: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = position
	m10_environment_root.add_child(visual)
	return visual

func _layout_m10() -> void:
	if m10_root == null:
		return
	var size := get_viewport().get_visible_rect().size
	var compact := size.x < 1380.0
	var left_width := 214.0 if compact else 238.0
	var right_width := 292.0 if compact else 328.0
	var gap := 10.0
	var top_y := 72.0
	var bottom_height := 248.0 if m10_replay_expanded else 58.0
	var bottom_margin := 12.0

	_set_rect(m10_top_bar, 12.0, 10.0, size.x - 12.0, 62.0)
	_set_rect(m10_left_panel, 12.0, top_y, 12.0 + left_width, size.y - bottom_height - bottom_margin - gap)
	_set_rect(m10_right_panel, size.x - 12.0 - right_width, top_y, size.x - 12.0, size.y - bottom_height - bottom_margin - gap)
	_set_rect(m10_viewport_frame, 12.0 + left_width + gap, top_y, size.x - 12.0 - right_width - gap, size.y - bottom_height - bottom_margin - gap)
	_set_rect(m10_replay_drawer, 12.0 + left_width + gap, size.y - bottom_height - bottom_margin, size.x - 12.0 - right_width - gap, size.y - bottom_margin)
	_set_rect(m10_status_chip, 12.0 + left_width + gap + 12.0, top_y + 12.0, 12.0 + left_width + gap + 220.0, top_y + 45.0)
	_set_rect(m10_compare_header, 12.0 + left_width + gap + 8.0, top_y + 8.0, size.x - 12.0 - right_width - gap - 8.0, top_y + 62.0)
	_set_rect(m10_compare_results, 12.0 + left_width + gap + 8.0, size.y - 238.0, size.x - 12.0 - right_width - gap - 8.0, size.y - 14.0)

	var modal_width := minf(760.0, size.x - 80.0)
	var modal_height := minf(540.0, size.y - 80.0)
	_set_centered_rect(m10_about_panel, minf(520.0, size.x - 80.0), minf(390.0, size.y - 80.0))
	for panel in [update_panel, export_settings_panel, calibration_panel, comparison_lab_panel]:
		if panel != null and is_instance_valid(panel):
			_set_centered_rect(panel, modal_width, modal_height)

	if size.x < 1120.0:
		m10_left_panel.visible = false
		m10_right_panel.visible = false
		_set_rect(m10_viewport_frame, 12.0, top_y, size.x - 12.0, size.y - bottom_height - bottom_margin - gap)
		_set_rect(m10_replay_drawer, 12.0, size.y - bottom_height - bottom_margin, size.x - 12.0, size.y - bottom_margin)
	else:
		_refresh_m10_mode()

func _set_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	if control == null:
		return
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom

func _set_centered_rect(control: Control, width: float, height: float) -> void:
	if control == null:
		return
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -width * 0.5
	control.offset_top = -height * 0.5
	control.offset_right = width * 0.5
	control.offset_bottom = height * 0.5

func _refresh_m10_mode() -> void:
	if m10_root == null:
		return
	var compare_view := m10_mode == MODE_COMPARE or comparison_active
	m10_left_panel.visible = not compare_view
	m10_right_panel.visible = not compare_view
	m10_replay_drawer.visible = not compare_view
	m10_compare_header.visible = m10_mode == MODE_COMPARE and not comparison_active
	m10_compare_results.visible = comparison_active
	m10_status_chip.visible = not comparison_active
	m10_scenario_button.disabled = not compare_view
	m10_compare_button.disabled = compare_view and not comparison_active
	if compare_view:
		var size := get_viewport().get_visible_rect().size
		_set_rect(m10_viewport_frame, 12.0, 72.0, size.x - 12.0, size.y - 12.0)
		_set_rect(m10_compare_header, 22.0, 80.0, size.x - 22.0, 136.0)
		if comparison_active:
			_set_rect(m10_compare_results, 22.0, size.y - 232.0, size.x - 22.0, size.y - 18.0)
	else:
		_layout_non_recursive()

func _layout_non_recursive() -> void:
	# Same scenario geometry as _layout_m10 without calling _refresh_m10_mode again.
	var size := get_viewport().get_visible_rect().size
	if size.x < 1120.0:
		return
	var compact := size.x < 1380.0
	var left_width := 214.0 if compact else 238.0
	var right_width := 292.0 if compact else 328.0
	var gap := 10.0
	var top_y := 72.0
	var bottom_height := 248.0 if m10_replay_expanded else 58.0
	var bottom_margin := 12.0
	_set_rect(m10_viewport_frame, 12.0 + left_width + gap, top_y, size.x - 12.0 - right_width - gap, size.y - bottom_height - bottom_margin - gap)
	_set_rect(m10_replay_drawer, 12.0 + left_width + gap, size.y - bottom_height - bottom_margin, size.x - 12.0 - right_width - gap, size.y - bottom_margin)
	_set_rect(m10_status_chip, 12.0 + left_width + gap + 12.0, top_y + 12.0, 12.0 + left_width + gap + 220.0, top_y + 45.0)

func _sync_m10_from_scenario() -> void:
	if m10_root == null:
		return
	m10_syncing = true
	m10_title_edit.text = scenario.title
	_select_metadata(m10_primary_option, scenario.car_preset_id)
	_select_metadata(m10_primary_class, scenario.car_preset_id)
	_select_metadata(m10_target_option, scenario.target_type)
	m10_vehicle_mass.value = scenario.car_mass_kg
	m10_vehicle_speed.value = scenario.car_speed_kmh
	m10_vehicle_x.value = scenario.car_position_m.x
	m10_vehicle_z.value = scenario.car_position_m.z
	m10_vehicle_heading.value = scenario.car_heading_deg
	m10_target_mass.value = scenario.target_mass_kg
	m10_target_speed.value = scenario.target_speed_kmh
	m10_target_x.value = scenario.target_position_m.x
	m10_target_z.value = scenario.target_position_m.z
	m10_target_heading.value = scenario.target_heading_deg
	m10_duration.value = scenario.duration_s
	m10_friction.value = scenario.contact_friction
	m10_restitution.value = scenario.restitution
	m10_substeps.value = scenario.solver_substeps
	m10_structure.button_pressed = scenario.show_structure
	_refresh_m10_target_preset_options()
	m10_target_mass_row.visible = scenario.target_mass_kg > 0.0 or _target_is_dynamic()
	m10_target_speed_row.visible = _target_is_dynamic() and scenario.target_type != ScenarioConfig.TARGET_PEDESTRIAN
	m10_target_paint_row.visible = scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR
	m10_metrics_summary.text = "%s\n%.0f kg • %.0f km/h\nvs %s" % [PassengerCarCatalog.display_name(scenario.car_preset_id), scenario.car_mass_kg, scenario.car_speed_kmh, ScenarioConfig.target_display_name(scenario.target_type)]
	if calibration_scope_label != null:
		m10_scope_chip.text = _compact_scope_text(calibration_scope_label.text)
	m10_syncing = false
	_update_selection_ring()

func _refresh_m10_target_preset_options() -> void:
	if m10_target_preset == null:
		return
	m10_target_preset.clear()
	var ids: Array[StringName] = []
	if scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		ids = PassengerCarCatalog.preset_ids()
	elif scenario.target_type == ScenarioConfig.TARGET_BICYCLE:
		ids = RoadUserCatalog.bicycle_ids()
	elif scenario.target_type == ScenarioConfig.TARGET_PEDESTRIAN:
		ids = RoadUserCatalog.pedestrian_ids()
	m10_target_preset_row.visible = not ids.is_empty()
	for id in ids:
		var text := PassengerCarCatalog.display_name(id) if scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR else RoadUserCatalog.display_name(id)
		m10_target_preset.add_item(text)
		m10_target_preset.set_item_metadata(m10_target_preset.item_count - 1, id)
	var wanted := scenario.target_car_preset_id if scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR else scenario.target_preset_id
	_select_metadata(m10_target_preset, wanted)

func _refresh_m10_runtime_state() -> void:
	if m10_status_label == null:
		return
	var current_status := status_label.text if status_label != null else "Ready"
	m10_status_label.text = _truncate(current_status, 38)
	m10_pause_button.visible = simulation_running
	m10_pause_button.text = "Resume" if simulation_paused else "Pause"
	m10_reset_button.visible = not simulation_running and replay_recorder != null and replay_recorder.recording != null and replay_recorder.recording.has_frames()
	m10_simulate_button.visible = not simulation_running and not comparison_active
	m10_simulate_button.disabled = comparison_active
	m10_video_button.disabled = export_button != null and export_button.disabled
	if updates_button != null and updates_button.text.begins_with("Updates •"):
		m10_updates_button.text = updates_button.text
	else:
		m10_updates_button.text = "Updates"

func _sync_m10_replay_runtime() -> void:
	# The replay controls were reparented, so M5 continues to drive them directly.
	if m10_vectors != null and vectors_check != null and not m10_syncing:
		m10_vectors.set_pressed_no_signal(vectors_check.button_pressed)

func _sync_m10_comparison_runtime() -> void:
	if m10_compare_results == null:
		return
	if comparison_active:
		if comparison_timeline != null:
			m10_compare_timeline.min_value = comparison_timeline.min_value
			m10_compare_timeline.max_value = comparison_timeline.max_value
			m10_compare_timeline.step = comparison_timeline.step
			m10_compare_timeline.set_value_no_signal(comparison_time_s)
			m10_compare_timeline.editable = true
		m10_compare_time.text = comparison_time_label.text if comparison_time_label != null else "%.2f s" % comparison_time_s
		m10_compare_play.text = "Pause" if comparison_playing else "Play"
		if not m10_compare_results.visible:
			m10_compare_results.visible = true
		if m10_compare_grid.get_child_count() == 0 and not comparison_results.is_empty():
			_build_m10_comparison_cards()
	else:
		m10_compare_timeline.editable = false

func _on_m10_primary_class_selected(index: int) -> void:
	if m10_syncing:
		return
	var option := m10_primary_option if get_signal_sender() == m10_primary_option else m10_primary_class
	if option == null or index < 0 or index >= option.item_count:
		return
	var id := StringName(String(option.get_item_metadata(index)))
	scenario.car_preset_id = id
	scenario.car_mass_kg = PassengerCarCatalog.default_mass_kg(id)
	selected_object = &"car"
	_request_preview_rebuild()
	_sync_m10_from_scenario()

func _on_m10_target_selected(index: int) -> void:
	if m10_syncing or index < 0 or index >= m10_target_option.item_count:
		return
	var id := StringName(String(m10_target_option.get_item_metadata(index)))
	_on_target_palette_pressed(id)
	selected_object = &"target"
	_sync_m10_from_scenario()

func _on_m10_target_preset_selected(index: int) -> void:
	if m10_syncing or index < 0 or index >= m10_target_preset.item_count:
		return
	var id := StringName(String(m10_target_preset.get_item_metadata(index)))
	if scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		scenario.target_car_preset_id = id
		scenario.target_mass_kg = PassengerCarCatalog.default_mass_kg(id)
	else:
		scenario.target_preset_id = id
		scenario.target_mass_kg = RoadUserCatalog.default_mass_kg(id)
	selected_object = &"target"
	_request_preview_rebuild()
	_sync_m10_from_scenario()

func _on_m10_vehicle_value(value: float, field: StringName) -> void:
	if m10_syncing:
		return
	match field:
		&"mass": scenario.car_mass_kg = value
		&"speed": scenario.car_speed_kmh = value
		&"x": scenario.car_position_m.x = value
		&"z": scenario.car_position_m.z = value
		&"heading": scenario.car_heading_deg = value
	selected_object = &"car"
	_request_preview_rebuild()

func _on_m10_target_value(value: float, field: StringName) -> void:
	if m10_syncing:
		return
	match field:
		&"mass": scenario.target_mass_kg = value
		&"speed": scenario.target_speed_kmh = value
		&"x": scenario.target_position_m.x = value
		&"z": scenario.target_position_m.z = value
		&"heading": scenario.target_heading_deg = value
	selected_object = &"target"
	_request_preview_rebuild()

func _on_m10_physics_value(value: float, field: StringName) -> void:
	if m10_syncing:
		return
	match field:
		&"duration": scenario.duration_s = value
		&"friction": scenario.contact_friction = value
		&"restitution": scenario.restitution = value
		&"substeps": scenario.solver_substeps = int(value)
	_request_preview_rebuild()

func _on_m10_primary_paint(index: int) -> void:
	if m10_syncing:
		return
	var ids := CarPaintCatalog.ids()
	if index >= 0 and index < ids.size():
		m10_primary_paint_id = ids[index]
		_apply_m10_paints()

func _on_m10_target_paint(index: int) -> void:
	if m10_syncing:
		return
	var ids := CarPaintCatalog.ids()
	if index >= 0 and index < ids.size():
		m10_target_paint_id = ids[index]
		_apply_m10_paints()

func _apply_m10_paints() -> void:
	if car != null:
		car.set_paint_id(m10_primary_paint_id)
	if target_car != null:
		target_car.set_paint_id(m10_target_paint_id)

func _on_m10_scenario_mode() -> void:
	if comparison_active:
		_on_comparison_exit_pressed()
	m10_mode = MODE_SCENARIO
	_refresh_m10_mode()
	_sync_m10_from_scenario()
	_frame_scenario()

func _on_m10_compare_mode() -> void:
	m10_mode = MODE_COMPARE
	_refresh_m10_mode()

func _on_m10_compare_mode_selected(index: int) -> void:
	if index < 0 or index >= m10_compare_mode.item_count:
		return
	var mode := StringName(String(m10_compare_mode.get_item_metadata(index)))
	var speed_visible := mode == MODE_SPEED
	m10_compare_speed_a.visible = speed_visible
	m10_compare_speed_b.visible = speed_visible
	m10_compare_speed_c.visible = speed_visible
	m10_compare_use_c.visible = speed_visible
	if mode == &"lab":
		if comparison_lab_panel != null:
			comparison_lab_panel.visible = true

func _on_m10_run_comparison() -> void:
	var selected_mode := StringName(String(m10_compare_mode.get_item_metadata(m10_compare_mode.selected)))
	if selected_mode == &"lab":
		comparison_lab_panel.visible = true
		return
	comparison_mode = MODE_CLASS if selected_mode == MODE_CLASS else MODE_SPEED
	if comparison_mode == MODE_SPEED:
		comparison_speed_a.value = m10_compare_speed_a.value
		comparison_speed_b.value = m10_compare_speed_b.value
		comparison_speed_c.value = m10_compare_speed_c.value
		comparison_use_third_speed.button_pressed = m10_compare_use_c.button_pressed
	_on_run_comparison_pressed()
	if comparison_active:
		m10_mode = MODE_COMPARE
		_build_m10_comparison_cards()
		_refresh_m10_mode()

func _on_m10_compare_play() -> void:
	_on_comparison_play_pressed()

func _on_m10_compare_timeline(value: float) -> void:
	if not comparison_active:
		return
	_apply_comparison_time(value, false)

func _on_m10_exit_comparison() -> void:
	_on_comparison_exit_pressed()
	m10_mode = MODE_SCENARIO
	_clear_m10_comparison_cards()
	_refresh_m10_mode()

func _build_m10_comparison_cards() -> void:
	_clear_m10_comparison_cards()
	for result in comparison_results:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var margin := _margin(card, 8, 5)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		margin.add_child(column)
		var title := Label.new()
		title.text = String(result.get("label", "Variant"))
		title.add_theme_font_size_override("font_size", 13)
		column.add_child(title)
		var analysis: Dictionary = result.get("analysis", {})
		var metrics := Label.new()
		metrics.text = "Δv %.1f km/h  •  %.1f g  •  crush %.0f mm" % [float(analysis.get("final_delta_v_kmh", 0.0)), float(analysis.get("peak_deceleration_g", 0.0)), float(analysis.get("max_front_crush_mm", 0.0))]
		metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		metrics.add_theme_font_size_override("font_size", 11)
		metrics.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
		column.add_child(metrics)
		m10_compare_grid.add_child(card)

func _clear_m10_comparison_cards() -> void:
	if m10_compare_grid == null:
		return
	for child in m10_compare_grid.get_children():
		m10_compare_grid.remove_child(child)
		child.queue_free()

func _toggle_replay_drawer() -> void:
	m10_replay_expanded = not m10_replay_expanded
	m10_replay_content.visible = m10_replay_expanded
	m10_replay_toggle.text = "Analysis ▾" if m10_replay_expanded else "Analysis ▴"
	_layout_m10()

func _on_m10_video_pressed() -> void:
	_on_export_button_pressed()
	if export_settings_panel != null:
		export_settings_panel.visible = true

func _on_m10_calibration_pressed() -> void:
	_on_calibration_pressed()
	if calibration_panel != null:
		calibration_panel.visible = true

func _on_m10_about_pressed() -> void:
	m10_about_panel.visible = true

func _on_camera_side() -> void:
	if camera == null:
		return
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5
	var separation := scenario.car_position_m.distance_to(scenario.target_position_m)
	camera.position = midpoint + Vector3(0.0, 3.0, maxf(13.5, separation * 0.75 + 8.0))
	camera.look_at(midpoint + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _on_camera_front() -> void:
	if camera == null:
		return
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5
	camera.position = midpoint + Vector3(-13.0, 3.5, 0.0)
	camera.look_at(midpoint + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _on_camera_top() -> void:
	if camera == null:
		return
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5
	camera.position = midpoint + Vector3(0.0, 22.0, 0.01)
	camera.look_at(midpoint, Vector3.FORWARD)

func _zoom_camera(scale_factor: float) -> void:
	if camera == null:
		return
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5 + Vector3(0.0, 1.0, 0.0)
	var offset := camera.position - midpoint
	var length := clampf(offset.length() * scale_factor, 4.0, 55.0)
	camera.position = midpoint + offset.normalized() * length
	camera.look_at(midpoint, Vector3.UP)

func _update_selection_ring() -> void:
	if m10_selection_ring == null:
		return
	m10_selection_ring.visible = not simulation_running and not comparison_active
	if not m10_selection_ring.visible:
		return
	var position := scenario.car_position_m if selected_object == &"car" else scenario.target_position_m
	m10_selection_ring.position = Vector3(position.x, 0.035, position.z)
	var radius := 1.75
	if selected_object == &"target":
		match scenario.target_type:
			ScenarioConfig.TARGET_TRUCK: radius = 3.8
			ScenarioConfig.TARGET_LORRY: radius = 3.1
			ScenarioConfig.TARGET_WALL: radius = 2.6
			ScenarioConfig.TARGET_BARRIER: radius = 1.8
			ScenarioConfig.TARGET_PEDESTRIAN: radius = 0.75
			ScenarioConfig.TARGET_BICYCLE: radius = 1.15
			_: radius = 1.55
	m10_selection_ring.scale = Vector3(radius / 1.8, 1.0, radius / 1.8)

func _target_is_dynamic() -> bool:
	return scenario.target_type in [ScenarioConfig.TARGET_PASSENGER_CAR, ScenarioConfig.TARGET_TRUCK, ScenarioConfig.TARGET_LORRY, ScenarioConfig.TARGET_MOTORCYCLE, ScenarioConfig.TARGET_BICYCLE, ScenarioConfig.TARGET_PEDESTRIAN]

func _compact_scope_text(text: String) -> String:
	var lower := text.to_lower()
	if lower.contains("reference-correlated"):
		return "Reference-correlated"
	if lower.contains("near reference"):
		return "Near reference"
	if lower.contains("class-scaled"):
		return "Class-scaled"
	if lower.contains("extrapolated"):
		return "Extrapolated"
	return "Evidence scope"

func _truncate(text: String, length: int) -> String:
	if text.length() <= length:
		return text
	return text.substr(0, maxi(length - 1, 1)) + "…"

func _select_metadata(option: OptionButton, wanted: StringName) -> void:
	if option == null:
		return
	for i in range(option.item_count):
		if StringName(String(option.get_item_metadata(i))) == wanted:
			option.select(i)
			return

func _populate_m10_paints(option: OptionButton, selected: StringName) -> void:
	option.clear()
	var ids := CarPaintCatalog.ids()
	for id in ids:
		option.add_item(CarPaintCatalog.display_name(id))
		option.set_item_metadata(option.item_count - 1, id)
	option.select(maxi(ids.find(selected), 0))

func _add_quick_target(parent: Container, label: String, target_id: StringName) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		_on_target_palette_pressed(target_id)
		selected_object = &"target"
		_sync_m10_from_scenario()
	)
	parent.add_child(button)

func _margin(parent: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin

func _add_button(parent: Container, text: String, callback: Callable, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _add_small_label(parent: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", CrashVectorM10Theme.MUTED)
	parent.add_child(label)
	return label

func _tab_scroll(title: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m10_inspector_tabs.add_child(scroll)
	return scroll

func _scroll_column(scroll: ScrollContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	return column

func _option_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var data := _option_row_with_row(parent, label_text)
	return data[1] as OptionButton

func _option_row_with_row(parent: VBoxContainer, label_text: String) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 170.0
	row.add_child(option)
	return [row, option]

func _spin_row(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, step: float, suffix: String) -> SpinBox:
	var data := _spin_row_with_row(parent, label_text, minimum, maximum, step, suffix)
	return data[1] as SpinBox

func _spin_row_with_row(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, step: float, suffix: String) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.suffix = suffix
	spin.custom_minimum_size.x = 132.0
	row.add_child(spin)
	return [row, spin]

func _compact_speed_spin(value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 0.0
	spin.max_value = 300.0
	spin.step = 1.0
	spin.value = value
	spin.suffix = " km/h"
	spin.custom_minimum_size.x = 100.0
	return spin

func _reparent_if_valid(node: Node, new_parent: Node) -> void:
	if node != null and is_instance_valid(node):
		node.reparent(new_parent, false)
