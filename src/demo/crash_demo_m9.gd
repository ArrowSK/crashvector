# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_extended.gd"

var update_service: UpdateService
var update_settings := UpdateSettings.new()

var lifecycle_canvas: CanvasLayer
var updates_button: Button
var update_panel: PanelContainer
var update_status_label: Label
var update_notes_label: Label
var update_progress: ProgressBar
var auto_check_toggle: CheckButton
var check_button: Button
var download_button: Button
var install_button: Button

func _ready() -> void:
	super._ready()
	_build_m9_lifecycle_ui()
	_setup_update_service()
	call_deferred("_maybe_auto_check")

func _build_m9_lifecycle_ui() -> void:
	lifecycle_canvas = CanvasLayer.new()
	lifecycle_canvas.name = "M9LifecycleUI"
	lifecycle_canvas.layer = 30
	add_child(lifecycle_canvas)

	updates_button = Button.new()
	updates_button.name = "UpdatesButton"
	updates_button.text = "Updates"
	updates_button.anchor_top = 1.0
	updates_button.anchor_bottom = 1.0
	updates_button.offset_left = 18.0
	updates_button.offset_top = -58.0
	updates_button.offset_right = 112.0
	updates_button.offset_bottom = -20.0
	updates_button.pressed.connect(_show_update_panel)
	lifecycle_canvas.add_child(updates_button)

	update_panel = PanelContainer.new()
	update_panel.name = "UpdatePanel"
	update_panel.anchor_left = 0.5
	update_panel.anchor_top = 0.5
	update_panel.anchor_right = 0.5
	update_panel.anchor_bottom = 0.5
	update_panel.offset_left = -260.0
	update_panel.offset_top = -215.0
	update_panel.offset_right = 260.0
	update_panel.offset_bottom = 215.0
	update_panel.visible = false
	lifecycle_canvas.add_child(update_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	update_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var title := Label.new()
	title.text = "CrashVector — Updates"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	var version_label := Label.new()
	version_label.name = "CurrentVersionLabel"
	version_label.text = "Installed: v%s  •  %s" % [AppMetadata.VERSION, AppMetadata.platform_display_name()]
	column.add_child(version_label)

	update_status_label = Label.new()
	update_status_label.text = "CrashVector checks GitHub Releases. Updates are downloaded only after you choose Download."
	update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(update_status_label)

	update_notes_label = Label.new()
	update_notes_label.custom_minimum_size.y = 92.0
	update_notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_notes_label.text = "No update check has been run in this session."
	column.add_child(update_notes_label)

	update_progress = ProgressBar.new()
	update_progress.name = "UpdateProgress"
	update_progress.min_value = 0.0
	update_progress.max_value = 100.0
	update_progress.value = 0.0
	update_progress.show_percentage = true
	column.add_child(update_progress)

	auto_check_toggle = CheckButton.new()
	auto_check_toggle.text = "Automatically check once per day"
	auto_check_toggle.toggled.connect(_on_auto_check_toggled)
	column.add_child(auto_check_toggle)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 7)
	column.add_child(button_row)

	check_button = Button.new()
	check_button.name = "CheckForUpdatesButton"
	check_button.text = "Check now"
	check_button.pressed.connect(_on_check_pressed)
	button_row.add_child(check_button)

	download_button = Button.new()
	download_button.name = "DownloadUpdateButton"
	download_button.text = "Download"
	download_button.disabled = true
	download_button.pressed.connect(_on_download_pressed)
	button_row.add_child(download_button)

	install_button = Button.new()
	install_button.name = "InstallUpdateButton"
	install_button.text = "Open installer & quit"
	install_button.disabled = true
	install_button.pressed.connect(_on_install_pressed)
	button_row.add_child(install_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_hide_update_panel)
	button_row.add_child(close_button)

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "macOS updates open the downloaded DMG; Windows updates launch the normal setup program. CrashVector never rewrites its own installed files in place."
	column.add_child(note)

func _setup_update_service() -> void:
	update_settings.load_settings()
	auto_check_toggle.button_pressed = update_settings.auto_check
	update_service = UpdateService.new()
	update_service.name = "UpdateService"
	add_child(update_service)
	update_service.check_completed.connect(_on_update_check_completed)
	update_service.download_progress.connect(_on_update_download_progress)
	update_service.download_completed.connect(_on_update_download_completed)
	update_service.update_error.connect(_on_update_error)

func _maybe_auto_check() -> void:
	if OS.has_feature("editor"):
		return
	if not update_settings.should_auto_check():
		return
	_run_update_check(false)

func _show_update_panel() -> void:
	update_panel.visible = true

func _hide_update_panel() -> void:
	update_panel.visible = false

func _on_check_pressed() -> void:
	_run_update_check(true)

func _run_update_check(show_panel: bool) -> void:
	if show_panel:
		_show_update_panel()
	check_button.disabled = true
	download_button.disabled = true
	install_button.disabled = true
	update_progress.value = 0.0
	update_status_label.text = "Checking GitHub Releases…"
	update_notes_label.text = ""
	update_settings.last_check_unix = int(Time.get_unix_time_from_system())
	update_settings.save_settings()
	update_service.check_for_updates()

func _on_update_check_completed(result: Dictionary) -> void:
	check_button.disabled = false
	if not bool(result.get("available", false)):
		update_status_label.text = "You are up to date — v%s." % AppMetadata.VERSION
		update_notes_label.text = "No newer compatible package is currently published."
		return
	var version := String(result.get("version", ""))
	update_status_label.text = "CrashVector v%s is available." % version
	var notes := String(result.get("notes", "")).strip_edges()
	update_notes_label.text = notes.left(600) if not notes.is_empty() else "A newer package is available on GitHub Releases."
	download_button.disabled = false

func _on_download_pressed() -> void:
	download_button.disabled = true
	check_button.disabled = true
	install_button.disabled = true
	update_status_label.text = "Downloading and verifying the installer…"
	update_progress.value = 0.0
	update_service.download_selected_update()

func _on_update_download_progress(downloaded_bytes: int, total_bytes: int) -> void:
	if total_bytes <= 0:
		update_progress.value = 0.0
		return
	update_progress.value = clampf(float(downloaded_bytes) / float(total_bytes) * 100.0, 0.0, 100.0)

func _on_update_download_completed(_path: String) -> void:
	check_button.disabled = false
	install_button.disabled = false
	update_progress.value = 100.0
	if OS.get_name() == "macOS":
		update_status_label.text = "Verified DMG downloaded. Open it and replace CrashVector in Applications."
	elif OS.get_name() == "Windows":
		update_status_label.text = "Verified Windows installer downloaded. It will update the installed copy."
	else:
		update_status_label.text = "Verified installer downloaded."

func _on_install_pressed() -> void:
	update_service.launch_installer_and_quit()

func _on_update_error(message: String) -> void:
	check_button.disabled = false
	download_button.disabled = update_service.selected_update.is_empty()
	install_button.disabled = update_service.installer_path.is_empty()
	update_status_label.text = message

func _on_auto_check_toggled(value: bool) -> void:
	update_settings.auto_check = value
	update_settings.save_settings()
