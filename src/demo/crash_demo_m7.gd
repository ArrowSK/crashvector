# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m6.gd"

var export_canvas: CanvasLayer
var export_launch_panel: PanelContainer
var export_button: Button
var export_cancel_button: Button
var export_progress: ProgressBar
var export_status: Label
var export_settings_panel: PanelContainer
var resolution_option: OptionButton
var fps_option: OptionButton
var camera_option: OptionButton
var primary_paint_option: OptionButton
var target_paint_option: OptionButton
var target_paint_row: HBoxContainer
var slow_motion_check: CheckButton
var overlays_check: CheckButton
var title_card_check: CheckButton
var result_card_check: CheckButton
var keep_frames_check: CheckButton
var ffmpeg_status_label: Label
var export_file_dialog: FileDialog
var exporter: CinematicExporter

func _ready() -> void:
	super._ready()
	exporter = CinematicExporter.new()
	exporter.name = "CinematicExporter"
	add_child(exporter)
	exporter.progress_changed.connect(_on_export_progress)
	_build_m7_ui()
	_refresh_export_availability()

func _finalize_recording() -> void:
	super._finalize_recording()
	_refresh_export_availability()

func _on_simulate_pressed() -> void:
	super._on_simulate_pressed()
	_refresh_export_availability()

func _on_reset_pressed() -> void:
	super._on_reset_pressed()
	_refresh_export_availability()

func _on_new_pressed() -> void:
	super._on_new_pressed()
	_refresh_export_availability()

func _on_open_path_selected(path: String) -> void:
	super._on_open_path_selected(path)
	_refresh_export_availability()

func _request_preview_rebuild() -> void:
	if export_button != null:
		export_button.disabled = true
	super._request_preview_rebuild()

func _set_base_ui_visible(value: bool) -> void:
	super._set_base_ui_visible(value)
	if export_canvas != null:
		export_canvas.visible = value

func _build_m7_ui() -> void:
	export_canvas = CanvasLayer.new()
	export_canvas.name = "M7ExportUI"
	export_canvas.layer = 5
	add_child(export_canvas)

	export_launch_panel = PanelContainer.new()
	export_launch_panel.anchor_left = 1.0
	export_launch_panel.anchor_right = 1.0
	export_launch_panel.offset_left = -340.0
	export_launch_panel.offset_top = 125.0
	export_launch_panel.offset_right = -10.0
	export_launch_panel.offset_bottom = 215.0
	export_canvas.add_child(export_launch_panel)
	var launch_margin := MarginContainer.new()
	launch_margin.add_theme_constant_override("margin_left", 9)
	launch_margin.add_theme_constant_override("margin_top", 7)
	launch_margin.add_theme_constant_override("margin_right", 9)
	launch_margin.add_theme_constant_override("margin_bottom", 7)
	export_launch_panel.add_child(launch_margin)
	var launch_column := VBoxContainer.new()
	launch_column.add_theme_constant_override("separation", 4)
	launch_margin.add_child(launch_column)
	var launch_row := HBoxContainer.new()
	launch_column.add_child(launch_row)
	export_button = Button.new()
	export_button.name = "CinematicVideoButton"
	export_button.text = "Cinematic Video"
	export_button.pressed.connect(_on_export_button_pressed)
	launch_row.add_child(export_button)
	export_cancel_button = Button.new()
	export_cancel_button.text = "Cancel"
	export_cancel_button.visible = false
	export_cancel_button.pressed.connect(_on_cancel_export_pressed)
	launch_row.add_child(export_cancel_button)
	export_status = Label.new()
	export_status.text = "Run a simulation to enable video export."
	export_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	export_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch_row.add_child(export_status)
	export_progress = ProgressBar.new()
	export_progress.min_value = 0.0
	export_progress.max_value = 1.0
	export_progress.value = 0.0
	export_progress.show_percentage = false
	export_progress.visible = false
	launch_column.add_child(export_progress)

	export_settings_panel = PanelContainer.new()
	export_settings_panel.anchor_left = 0.5
	export_settings_panel.anchor_right = 0.5
	export_settings_panel.offset_left = -330.0
	export_settings_panel.offset_top = 92.0
	export_settings_panel.offset_right = 330.0
	export_settings_panel.offset_bottom = 660.0
	export_settings_panel.visible = false
	export_canvas.add_child(export_settings_panel)
	var settings_margin := MarginContainer.new()
	settings_margin.add_theme_constant_override("margin_left", 18)
	settings_margin.add_theme_constant_override("margin_top", 15)
	settings_margin.add_theme_constant_override("margin_right", 18)
	settings_margin.add_theme_constant_override("margin_bottom", 15)
	export_settings_panel.add_child(settings_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	settings_margin.add_child(column)
	var heading := Label.new()
	heading.text = "Cinematic Video Export"
	heading.add_theme_font_size_override("font_size", 22)
	column.add_child(heading)
	var intro := Label.new()
	intro.text = "Offline rendering uses the recorded crash, so video quality and timing are independent of live simulation frame rate. Auto cinematic mode moves from tracking to impact close-up and aftermath orbit."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)

	resolution_option = _add_option_row(column, "Resolution")
	for id in CinematicExportProfile.resolution_ids():
		resolution_option.add_item(CinematicExportProfile.resolution_display_name(id))
		resolution_option.set_item_metadata(resolution_option.item_count - 1, String(id))
	resolution_option.select(0)

	fps_option = _add_option_row(column, "Frame rate")
	for value in [30, 60]:
		fps_option.add_item("%d fps" % value)
		fps_option.set_item_metadata(fps_option.item_count - 1, value)
	fps_option.select(1)

	camera_option = _add_option_row(column, "Camera")
	for id in CinematicExportProfile.camera_ids():
		camera_option.add_item(CinematicExportProfile.camera_display_name(id))
		camera_option.set_item_metadata(camera_option.item_count - 1, String(id))
	camera_option.select(0)

	primary_paint_option = _add_option_row(column, "Primary car paint")
	_populate_paints(primary_paint_option, CarPaintCatalog.ELECTRIC_BLUE)
	target_paint_row = HBoxContainer.new()
	column.add_child(target_paint_row)
	var target_label := Label.new()
	target_label.text = "Target car paint"
	target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_paint_row.add_child(target_label)
	target_paint_option = OptionButton.new()
	target_paint_option.custom_minimum_size.x = 220.0
	target_paint_row.add_child(target_paint_option)
	_populate_paints(target_paint_option, CarPaintCatalog.SILVER)

	slow_motion_check = _add_check(column, "Impact slow motion (0.25×)", true)
	overlays_check = _add_check(column, "Educational speed / crush overlay", true)
	title_card_check = _add_check(column, "Opening title card", true)
	result_card_check = _add_check(column, "Closing result card", true)
	keep_frames_check = _add_check(column, "Keep rendered JPEG frames after encoding", false)

	ffmpeg_status_label = Label.new()
	ffmpeg_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(ffmpeg_status_label)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(button_row)
	var close_button := Button.new()
	close_button.text = "Cancel"
	close_button.pressed.connect(_on_close_export_settings)
	button_row.add_child(close_button)
	var render_button := Button.new()
	render_button.text = "Choose MP4 and Render"
	render_button.pressed.connect(_on_choose_mp4_pressed)
	button_row.add_child(render_button)

	export_file_dialog = FileDialog.new()
	export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_file_dialog.filters = PackedStringArray(["*.mp4 ; MPEG-4 Video"])
	export_file_dialog.file_selected.connect(_on_export_file_selected)
	export_canvas.add_child(export_file_dialog)

func _add_option_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 260.0
	row.add_child(option)
	return option

func _add_check(parent: VBoxContainer, text: String, enabled: bool) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = enabled
	parent.add_child(check)
	return check

func _populate_paints(option: OptionButton, selected_id: StringName) -> void:
	var selected_index := 0
	var ids := CarPaintCatalog.ids()
	for i in range(ids.size()):
		var id := ids[i]
		option.add_item(CarPaintCatalog.display_name(id))
		option.set_item_metadata(option.item_count - 1, String(id))
		if id == selected_id:
			selected_index = i
	option.select(selected_index)

func _on_export_button_pressed() -> void:
	if not _has_exportable_replay():
		export_status.text = "Run a complete simulation first."
		return
	target_paint_row.visible = scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR
	var ffmpeg := FFmpegVideoEncoder.locate_ffmpeg()
	ffmpeg_status_label.text = (
		"FFmpeg detected: %s" % ffmpeg
		if not ffmpeg.is_empty()
		else "FFmpeg is required for MP4 encoding and was not detected. CrashVector does not bundle the codec binary."
	)
	export_settings_panel.visible = true

func _on_close_export_settings() -> void:
	export_settings_panel.visible = false

func _on_choose_mp4_pressed() -> void:
	if FFmpegVideoEncoder.locate_ffmpeg().is_empty():
		ffmpeg_status_label.text = "FFmpeg is not available, so MP4 export cannot start. Install FFmpeg and reopen this panel."
		return
	export_file_dialog.current_file = "crashvector_%s.mp4" % _safe_filename(scenario.title)
	export_file_dialog.popup_centered_ratio(0.72)

func _on_export_file_selected(path: String) -> void:
	if not _has_exportable_replay() or exporter.active:
		return
	export_settings_panel.visible = false
	var profile := _profile_from_ui()
	export_progress.visible = true
	export_progress.value = 0.0
	export_cancel_button.visible = true
	export_button.disabled = true
	export_status.text = "Preparing offline render…"
	var result: Dictionary = await exporter.export_video(
		replay_recorder.recording,
		scenario,
		analysis_report,
		profile,
		path
	)
	export_cancel_button.visible = false
	export_progress.visible = false
	if bool(result.get("ok", false)):
		var output_path := String(result.get("output_path", path))
		export_status.text = "Video ready: %s" % output_path
		status_label.text = "Cinematic video exported: %s" % output_path
	else:
		export_status.text = String(result.get("message", "Video export failed."))
		status_label.text = export_status.text
	_refresh_export_availability()

func _profile_from_ui() -> CinematicExportProfile:
	var profile := CinematicExportProfile.new()
	profile.resolution_id = StringName(String(resolution_option.get_item_metadata(resolution_option.selected)))
	profile.fps = int(fps_option.get_item_metadata(fps_option.selected))
	profile.camera_id = StringName(String(camera_option.get_item_metadata(camera_option.selected)))
	profile.primary_paint_id = StringName(String(primary_paint_option.get_item_metadata(primary_paint_option.selected)))
	profile.target_paint_id = StringName(String(target_paint_option.get_item_metadata(target_paint_option.selected)))
	profile.slow_motion_enabled = slow_motion_check.button_pressed
	profile.include_overlays = overlays_check.button_pressed
	profile.include_title_card = title_card_check.button_pressed
	profile.include_result_card = result_card_check.button_pressed
	profile.keep_frame_sequence = keep_frames_check.button_pressed
	return profile

func _on_cancel_export_pressed() -> void:
	if exporter != null and exporter.active:
		exporter.cancel()
		export_status.text = "Cancelling after the current frame…"

func _on_export_progress(progress: float, message: String) -> void:
	export_progress.value = clampf(progress, 0.0, 1.0)
	export_status.text = message

func _refresh_export_availability() -> void:
	if export_button == null:
		return
	var available := _has_exportable_replay() and (exporter == null or not exporter.active)
	export_button.disabled = not available
	if available and not export_settings_panel.visible:
		export_status.text = "Replay ready for cinematic export."
	elif not available and (exporter == null or not exporter.active):
		export_status.text = "Run a simulation to enable video export."

func _has_exportable_replay() -> bool:
	return (
		replay_recorder != null
		and replay_recorder.recording != null
		and replay_recorder.recording.has_frames()
		and not analysis_report.is_empty()
	)

func _safe_filename(value: String) -> String:
	var result := value.strip_edges().to_lower().replace(" ", "_")
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(character, "-")
	return "collision" if result.is_empty() else result
