# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m16.gd"

# The M10 responsive-layout regression and downstream extensions use these
# region names as stable shell contracts. M16 changes the content and hierarchy,
# not those compatibility identifiers.
func _ready() -> void:
	super._ready()
	if m10_top_bar != null:
		m10_top_bar.name = "M10TopBar"
	if m10_left_panel != null:
		m10_left_panel.name = "M10ScenarioPanel"
	if m10_right_panel != null:
		m10_right_panel.name = "M10Inspector"
	if m10_replay_drawer != null:
		m10_replay_drawer.name = "M10ReplayDrawer"
	_harden_m16_compact_controls()
	_layout_m10()

func _sync_m10_from_scenario() -> void:
	super._sync_m10_from_scenario()
	# The selected object is already named in the Properties heading. Keeping
	# these two selector labels short prevents a long target name from dictating
	# the width of the entire desktop inspector.
	if m16_primary_button != null:
		m16_primary_button.text = "Primary"
	if m16_target_button != null:
		m16_target_button.text = "Target"

func _layout_m10() -> void:
	super._layout_m10()
	_fit_m16_scenario_geometry()

func _harden_m16_compact_controls() -> void:
	for option in [m10_primary_option, m10_target_option, m10_primary_class, m10_target_preset, m10_primary_paint, m10_target_paint]:
		if option != null:
			option.fit_to_longest_item = false
			option.custom_minimum_size.x = minf(option.custom_minimum_size.x, 145.0)
	for spin in [
		m10_vehicle_mass, m10_vehicle_speed, m10_vehicle_x, m10_vehicle_z, m10_vehicle_heading,
		m10_target_mass, m10_target_speed, m10_target_x, m10_target_z, m10_target_heading,
		m10_duration, m10_friction, m10_restitution, m10_substeps
	]:
		if spin != null:
			spin.custom_minimum_size.x = minf(spin.custom_minimum_size.x, 116.0)

func _fit_m16_scenario_geometry() -> void:
	if m10_root == null or m10_mode == MODE_COMPARE or comparison_active:
		return
	var size := get_viewport().get_visible_rect().size
	var top_y := 70.0
	var gap := 12.0
	var bottom_margin := 12.0
	var requested_bottom := 250.0 if m10_replay_expanded else 66.0
	var replay_height := maxf(requested_bottom, m10_replay_drawer.get_combined_minimum_size().y)
	var content_bottom := size.y - replay_height - bottom_margin - gap

	if size.x < 940.0:
		_set_rect(m10_viewport_frame, 12.0, top_y, size.x - 12.0, content_bottom)
		_set_rect(m10_replay_drawer, 12.0, size.y - replay_height - bottom_margin, size.x - 12.0, size.y - bottom_margin)
		return

	var compact := size.x < 1420.0
	var requested_left := 242.0 if compact else 262.0
	var left_width := maxf(requested_left, m10_left_panel.get_combined_minimum_size().x)
	var viewport_left := 12.0 + left_width + gap
	var viewport_right := size.x - 12.0

	if size.x >= 1160.0:
		var requested_right := 300.0 if compact else 326.0
		var right_width := maxf(requested_right, m10_right_panel.get_combined_minimum_size().x)
		viewport_right = size.x - 12.0 - right_width - gap
		_set_rect(m10_right_panel, size.x - 12.0 - right_width, top_y, size.x - 12.0, content_bottom)

	_set_rect(m10_left_panel, 12.0, top_y, 12.0 + left_width, content_bottom)
	_set_rect(m10_viewport_frame, viewport_left, top_y, viewport_right, content_bottom)
	_set_rect(m10_replay_drawer, viewport_left, size.y - replay_height - bottom_margin, viewport_right, size.y - bottom_margin)
	_set_rect(m10_status_chip, viewport_left + 12.0, top_y + 12.0, minf(viewport_left + 310.0, viewport_right - 12.0), top_y + 44.0)
	if m16_viewport_toolbar != null:
		var available_width := maxf(viewport_right - viewport_left - 24.0, 1.0)
		var toolbar_width := minf(470.0, available_width)
		_set_rect(m16_viewport_toolbar, viewport_right - toolbar_width - 12.0, top_y + 12.0, viewport_right - 12.0, top_y + 52.0)
