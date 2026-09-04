# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Final M10 compatibility shell. The M10 presentation layer deliberately keeps
# every M0-M9 modal in its original CanvasLayer hierarchy so saved tests,
# updater/export/calibration code and external node references keep working.
extends "res://src/demo/crash_demo_m10.gd"

func _ready() -> void:
	super._ready()
	_harden_m10_scenario_rail()
	_layout_m10()

func _layout_m10() -> void:
	super._layout_m10()
	_fit_m10_scenario_geometry()

func _layout_non_recursive() -> void:
	super._layout_non_recursive()
	_fit_m10_scenario_geometry()

func _fit_m10_scenario_geometry() -> void:
	# M10 initially used estimated compact dimensions. Reserve the actual minimum
	# size of the inherited controls instead, so the sidebars and replay drawer
	# can never grow into the viewport at supported desktop sizes.
	if m10_root == null or m10_replay_drawer == null:
		return
	if m10_mode == MODE_COMPARE or comparison_active:
		return
	var size := get_viewport().get_visible_rect().size
	var bottom_margin := 12.0
	var gap := 10.0
	var top_y := 72.0
	var requested_replay_height := 248.0 if m10_replay_expanded else 58.0
	var replay_height := maxf(requested_replay_height, m10_replay_drawer.get_combined_minimum_size().y)
	var content_bottom := size.y - replay_height - bottom_margin - gap
	if size.x < 1120.0:
		_set_rect(m10_viewport_frame, 12.0, top_y, size.x - 12.0, content_bottom)
		_set_rect(m10_replay_drawer, 12.0, size.y - replay_height - bottom_margin, size.x - 12.0, size.y - bottom_margin)
		return
	var compact := size.x < 1380.0
	var requested_left := 214.0 if compact else 238.0
	var requested_right := 292.0 if compact else 328.0
	var left_width := maxf(requested_left, m10_left_panel.get_combined_minimum_size().x)
	var right_width := maxf(requested_right, m10_right_panel.get_combined_minimum_size().x)
	var content_left := 12.0 + left_width + gap
	var content_right := size.x - 12.0 - right_width - gap
	_set_rect(m10_left_panel, 12.0, top_y, 12.0 + left_width, content_bottom)
	_set_rect(m10_right_panel, size.x - 12.0 - right_width, top_y, size.x - 12.0, content_bottom)
	_set_rect(m10_viewport_frame, content_left, top_y, content_right, content_bottom)
	_set_rect(m10_replay_drawer, content_left, size.y - replay_height - bottom_margin, content_right, size.y - bottom_margin)

func _harden_m10_scenario_rail() -> void:
	# At the supported 1280x720 desktop floor, long option labels and the full
	# scenario-help stack must not dictate the outer rail's minimum dimensions.
	# Keep every control available by scrolling the M10-owned rail instead of
	# hiding functionality or allowing it to overlap the 3D viewport.
	if m10_primary_option != null:
		m10_primary_option.fit_to_longest_item = false
	if m10_target_option != null:
		m10_target_option.fit_to_longest_item = false
	if m10_left_panel == null or m10_left_panel.get_child_count() == 0:
		return
	var existing := m10_left_panel.get_child(0)
	if existing is ScrollContainer:
		return
	if not existing is Control:
		return
	m10_left_panel.remove_child(existing)
	var scroll := ScrollContainer.new()
	scroll.name = "M10ScenarioScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	m10_left_panel.add_child(scroll)
	(existing as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(existing)

func _adopt_legacy_panels() -> void:
	# M10 must never move proven M0-M9 controls out of their existing ownership
	# hierarchy. It only provides new launch surfaces for those services.
	pass

func _hide_legacy_ui() -> void:
	# Fixed legacy editor/replay/comparison chrome is superseded by M10.
	for node_name in ["EditorUI", "M5AnalysisUI", "M6ComparisonUI"]:
		var layer := get_node_or_null(node_name) as CanvasLayer
		if layer != null:
			layer.visible = false

	# Modal-bearing layers remain alive and in their original hierarchy. Only
	# their old fixed-position launchers are hidden, which is the smallest change
	# that avoids duplicate UI while preserving every M7-M9 path and callback.
	if export_canvas != null:
		export_canvas.visible = true
	if export_launch_panel != null:
		export_launch_panel.visible = false
	if calibration_canvas != null:
		calibration_canvas.visible = true
	if calibration_launch_panel != null:
		calibration_launch_panel.visible = false
	if comparison_lab_canvas != null:
		comparison_lab_canvas.visible = true
		var lab_button := _find_descendant_named(comparison_lab_canvas, "ComparisonLabButton") as Control
		if lab_button != null:
			var launch_panel := lab_button.get_parent()
			if launch_panel != null:
				launch_panel = launch_panel.get_parent()
			if launch_panel != null:
				launch_panel = launch_panel.get_parent()
			if launch_panel is Control:
				(launch_panel as Control).visible = false
	if update_canvas != null:
		update_canvas.visible = true
	if updates_button != null:
		updates_button.visible = false
	if custom_speed_panel != null:
		custom_speed_panel.visible = false

func _on_m10_primary_class_selected(index: int) -> void:
	if m10_syncing:
		return
	var ids := PassengerCarCatalog.preset_ids()
	if index < 0 or index >= ids.size():
		return
	# Both M10 primary-class selectors intentionally use the exact catalogue
	# ordering, so no signal-sender introspection or runtime script trick is needed.
	var id := ids[index]
	scenario.car_preset_id = id
	scenario.car_mass_kg = PassengerCarCatalog.default_mass_kg(id)
	selected_object = &"car"
	_request_preview_rebuild()
	_sync_m10_from_scenario()

func _find_descendant_named(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_descendant_named(child, wanted)
		if found != null:
			return found
	return null
