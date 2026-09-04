# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_extended.gd"

var update_service: CrashVectorUpdateService
var update_canvas: CanvasLayer
var updates_button: Button
var update_panel: PanelContainer
var update_installed_label: Label
var update_available_label: Label
var update_status_label: Label
var update_notes: RichTextLabel
var update_auto_check: CheckButton
var update_check_button: Button
var update_download_button: Button
var update_install_button: Button
var update_progress: ProgressBar

func _ready() -> void:
	super._ready()
	_build_m9_update_ui()

func _set_base_ui_visible(value: bool) -> void:
	super._set_base_ui_visible(value)
	if update_canvas != null:
		update_canvas.visible = value

func _build_m9_update_ui() -> void:
	update_canvas = CanvasLayer.new()
	update_canvas.name = "M9UpdateUI"
	update_canvas.layer = 8
	add_child(update_canvas)

	updates_button = Button.new()
	updates_button.name = "UpdatesButton"
	updates_button.text = "Updates"
	updates_button.anchor_left = 1.0
	updates_button.anchor_right = 1.0
	updates_button.offset_left = -124.0
	updates_button.offset_top = 10.0
	updates_button.offset_right = -10.0
	updates_button.offset_bottom = 46.0
	updates_button.pressed.connect(_on_updates_button_pressed)
	update_canvas.add_child(updates_button)

	update_panel = PanelContainer.new()
	update_panel.name = "UpdatePanel"
	update_panel.anchor_left = 0.5
	update_panel.anchor_top = 0.5
	update_panel.anchor_right = 0.5
	update_panel.anchor_bottom = 0.5
	update_panel.offset_left = -380.0
	update_panel.offset_top = -255.0
	update_panel.offset_right = 380.0
	update_panel.offset_bottom = 255.0
	update_panel.visible = false
	update_canvas.add_child(update_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	update_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var heading_row := HBoxContainer.new()
	column.add_child(heading_row)
	var heading := Label.new()
	heading.text = "CrashVector Updates"
	heading.add_theme_font_size_override("font_size", 22)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(func() -> void: update_panel.visible = false)
	heading_row.add_child(close_button)

	update_installed_label = Label.new()
	column.add_child(update_installed_label)
	update_available_label = Label.new()
	update_available_label.text = "Available version: not checked"
	column.add_child(update_available_label)

	update_auto_check = CheckButton.new()
	update_auto_check.name = "AutomaticUpdateCheck"
	update_auto_check.text = "Check automatically once per day"
	column.add_child(update_auto_check)

	update_status_label = Label.new()
	update_status_label.text = "Use Check for updates to query official CrashVector GitHub Releases."
	update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(update_status_label)

	update_notes = RichTextLabel.new()
	update_notes.name = "UpdateReleaseNotes"
	update_notes.custom_minimum_size = Vector2(0.0, 230.0)
	update_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	update_notes.fit_content = false
	update_notes.bbcode_enabled = false
	update_notes.text = "Release information will appear here before you download an update."
	column.add_child(update_notes)

	update_progress = ProgressBar.new()
	update_progress.name = "UpdateDownloadProgress"
	update_progress.min_value = 0.0
	update_progress.max_value = 100.0
	update_progress.value = 0.0
	update_progress.visible = false
	column.add_child(update_progress)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 7)
	column.add_child(button_row)
	update_check_button = Button.new()
	update_check_button.name = "CheckForUpdatesButton"
	update_check_button.text = "Check for updates"
	update_check_button.pressed.connect(_on_check_for_updates_pressed)
	button_row.add_child(update_check_button)
	update_download_button = Button.new()
	update_download_button.name = "DownloadUpdateButton"
	update_download_button.text = "Download"
	update_download_button.disabled = true
	update_download_button.pressed.connect(_on_download_update_pressed)
	button_row.add_child(update_download_button)
	update_install_button = Button.new()
	update_install_button.name = "InstallUpdateButton"
	update_install_button.text = "Install"
	update_install_button.disabled = true
	update_install_button.pressed.connect(_on_install_update_pressed)
	button_row.add_child(update_install_button)

	update_service = CrashVectorUpdateService.new()
	update_service.name = "M9UpdateService"
	update_service.check_finished.connect(_on_update_check_finished)
	update_service.download_finished.connect(_on_update_download_finished)
	update_service.download_progress.connect(_on_update_download_progress)
	update_service.status_changed.connect(_on_update_status_changed)
	add_child(update_service)

	update_installed_label.text = "Installed version: %s" % update_service.installed_version
	update_auto_check.set_pressed_no_signal(update_service.automatic_checks_enabled)
	update_auto_check.toggled.connect(_on_auto_update_toggled)

func _on_updates_button_pressed() -> void:
	update_panel.visible = true

func _on_check_for_updates_pressed() -> void:
	update_check_button.disabled = true
	update_download_button.disabled = true
	update_install_button.disabled = true
	update_available_label.text = "Available version: checking…"
	update_notes.text = "Checking official GitHub Releases…"
	update_progress.visible = false
	update_service.check_for_updates(true)

func _on_auto_update_toggled(value: bool) -> void:
	update_service.set_automatic_checks_enabled(value)

func _on_update_check_finished(result: Dictionary) -> void:
	update_check_button.disabled = false
	if not bool(result.get("ok", false)):
		update_available_label.text = "Available version: unknown"
		update_notes.text = String(result.get("error", "Update check failed."))
		return
	if not bool(result.get("available", false)):
		update_available_label.text = "Available version: none"
		update_notes.text = "This installation is up to date."
		updates_button.text = "Updates"
		return
	var available_version := String(result.get("available_version", ""))
	update_available_label.text = "Available version: %s" % available_version
	var release_name := String(result.get("release_name", "CrashVector %s" % available_version))
	var release_notes := String(result.get("release_notes", "No release notes supplied."))
	update_notes.text = "%s\n\n%s" % [release_name, release_notes]
	update_download_button.disabled = false
	updates_button.text = "Updates • %s" % available_version

func _on_download_update_pressed() -> void:
	update_download_button.disabled = true
	update_install_button.disabled = true
	update_progress.visible = true
	update_progress.value = 0.0
	update_service.download_selected_update()

func _on_update_download_progress(received_bytes: int, total_bytes: int) -> void:
	if total_bytes <= 0:
		update_progress.value = 0.0
		return
	update_progress.value = clampf(float(received_bytes) / float(total_bytes) * 100.0, 0.0, 100.0)

func _on_update_download_finished(result: Dictionary) -> void:
	update_progress.visible = false
	if not bool(result.get("ok", false)) or not bool(result.get("verified", false)):
		update_download_button.disabled = false
		update_install_button.disabled = true
		update_notes.text = "%s\n\nThe existing CrashVector installation was not changed." % String(result.get("error", "Update download failed."))
		return
	update_install_button.disabled = false
	update_notes.text = "%s\n\nSHA-256 verification passed. Install will hand the verified package to the operating system; CrashVector never overwrites its running executable." % update_notes.text

func _on_install_update_pressed() -> void:
	var result := update_service.install_verified_update()
	if not bool(result.get("ok", false)):
		update_notes.text = "%s\n\n%s" % [update_notes.text, String(result.get("error", "Could not open installer."))]

func _on_update_status_changed(message: String) -> void:
	update_status_label.text = message

# M10's two primary-class controls share identical catalogue ordering. This
# compatibility helper is temporary while the M10 shell is validated; it makes
# the existing callback deterministic without altering any M9 updater behavior.
func get_signal_sender() -> Object:
	return null
