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

func _ready() -> void:
	super._ready()
	_build_m8_ui()
	_refresh_calibration_scope()

func _request_preview_rebuild() -> void:
	super._request_preview_rebuild()
	_refresh_calibration_scope()

func _set_base_ui_visible(value: bool) -> void:
	super._set_base_ui_visible(value)
	if calibration_canvas != null:
		calibration_canvas.visible = value

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
	caution.text = "Published brake-pedal and foot-rest intrusion measurements are retained as source observations, but CrashVector does not equate them to its safety-cell beam-deformation proxy. No occupant injury or star rating is predicted."
	caution.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caution)
	var separator := HSeparator.new()
	column.add_child(separator)
	calibration_result_label = Label.new()
	calibration_result_label.text = "Run the built-in reference check to compare the current solver against the stored project corridors."
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
	lines.append("Result: %s" % ("PASS — within stored M8 corridors" if bool(assessment.get("passed", false)) else "OUTSIDE CORRIDOR — development review required"))
	lines.append("Pulse duration: %.0f ms • Δv: %.1f km/h • peak deceleration: %.1f g" % [float(metrics.get("pulse_duration_s", 0.0)) * 1000.0, float(metrics.get("delta_v_kmh", 0.0)), float(metrics.get("peak_deceleration_g", 0.0))])
	lines.append("Front crush proxy: %.0f mm • safety-cell proxy: %.1f mm • energy-balance error: %.1f%%" % [float(metrics.get("front_crush_mm", 0.0)), float(metrics.get("safety_cell_proxy_mm", 0.0)), float(metrics.get("energy_balance_relative_error", 0.0)) * 100.0])
	for check in assessment.get("checks", []):
		var corridor: Dictionary = check.get("corridor", {})
		lines.append("%s: %s (%.3f; corridor %.3f–%.3f %s)" % [String(check.get("name", "Metric")), "PASS" if bool(check.get("passed", false)) else "FAIL", float(check.get("value", 0.0)), float(corridor.get("min", 0.0)), float(corridor.get("max", 0.0)), String(check.get("unit", ""))])
	lines.append("This is a limited structural correlation check, not certification or injury validation.")
	calibration_result_label.text = "\n".join(lines)
