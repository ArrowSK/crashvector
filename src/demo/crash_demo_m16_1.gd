# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m16_release.gd"

# M16.1 is a presentation correction over the released M16 shell. It keeps the
# M12-M15 physics path intact and addresses issues observed in the packaged
# desktop beta: stale automatic scenario names, oversized chrome, a lingering
# selection ring in completed runs, weak class silhouettes and excessively wide
# setup/aftermath camera framing.

var m161_title_is_auto := true
var m161_updating_title := false
var m161_aftermath_framed := false

func _ready() -> void:
	super._ready()
	m161_title_is_auto = _m161_title_is_automatic(scenario.title)
	if m10_title_edit != null:
		m10_title_edit.text_changed.connect(_on_m161_title_text_changed)
	_m161_polish_ui()
	_m161_polish_environment()
	if m161_title_is_auto:
		_m161_apply_auto_title()
	_layout_m10()
	call_deferred("_frame_scenario")

func _physics_process(delta: float) -> void:
	var was_running := simulation_running
	super._physics_process(delta)
	if was_running and not simulation_running and not m161_aftermath_framed:
		m161_aftermath_framed = true
		call_deferred("_m161_frame_aftermath")

func _ensure_m16_vehicle_visual(vehicle_node: CompactHatchback, node_name: String) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return
	var existing := vehicle_node.get_node_or_null(node_name)
	if existing != null:
		if existing is M161VehicleVisual:
			return
		existing.queue_free()
	var visual := M161VehicleVisual.new()
	vehicle_node.add_child(visual)
	visual.configure(vehicle_node)
	visual.name = node_name

func _on_m10_primary_class_selected(index: int) -> void:
	var keep_auto := m161_title_is_auto or _m161_title_is_automatic(scenario.title)
	super._on_m10_primary_class_selected(index)
	m161_aftermath_framed = false
	if keep_auto:
		m161_title_is_auto = true
		_m161_apply_auto_title()
	call_deferred("_frame_scenario")

func _on_m10_target_selected(index: int) -> void:
	var keep_auto := m161_title_is_auto or _m161_title_is_automatic(scenario.title)
	super._on_m10_target_selected(index)
	m161_aftermath_framed = false
	if keep_auto:
		m161_title_is_auto = true
		_m161_apply_auto_title()
	call_deferred("_frame_scenario")

func _on_new_pressed() -> void:
	super._on_new_pressed()
	m161_title_is_auto = true
	m161_aftermath_framed = false
	_m161_apply_auto_title()
	call_deferred("_frame_scenario")

func _on_open_path_selected(path: String) -> void:
	super._on_open_path_selected(path)
	m161_title_is_auto = _m161_title_is_automatic(scenario.title)
	m161_aftermath_framed = false
	call_deferred("_frame_scenario")

func _on_simulate_pressed() -> void:
	m161_aftermath_framed = false
	super._on_simulate_pressed()

func _on_reset_pressed() -> void:
	super._on_reset_pressed()
	m161_aftermath_framed = false
	call_deferred("_frame_scenario")

func _on_m161_title_text_changed(_value: String) -> void:
	if m10_syncing or m161_updating_title:
		return
	m161_title_is_auto = false

func _m161_auto_title() -> String:
	return "%s vs %s" % [
		PassengerCarCatalog.display_name(scenario.car_preset_id),
		ScenarioConfig.target_display_name(scenario.target_type),
	]

func _m161_title_is_automatic(value: String) -> bool:
	return value == _m161_auto_title() or value == "B-Class vs Rigid Wall" or value == "Car vs Truck"

func _m161_apply_auto_title() -> void:
	var title := _m161_auto_title()
	if scenario.title == title and (m10_title_edit == null or m10_title_edit.text == title):
		return
	m161_updating_title = true
	scenario.title = title
	_sync_m10_from_scenario()
	m161_updating_title = false

func _refresh_m10_mode() -> void:
	super._refresh_m10_mode()
	if m10_scenario_button == null or m10_compare_button == null:
		return
	var compare_view := m10_mode == MODE_COMPARE or comparison_active
	# Selected workspace tabs should look selected, not disabled.
	m10_scenario_button.disabled = comparison_active
	m10_compare_button.disabled = comparison_active
	CrashVectorM16Theme.selected_button(m10_scenario_button, not compare_view)
	CrashVectorM16Theme.selected_button(m10_compare_button, compare_view)

func _refresh_m10_runtime_state() -> void:
	super._refresh_m10_runtime_state()
	if m10_status_label != null:
		if simulation_running:
			m10_status_label.text = "Paused" if simulation_paused else "Simulating"
		elif _m161_has_replay():
			m10_status_label.text = "Complete"
		else:
			m10_status_label.text = "Ready"
	if m16_more_menu != null:
		m16_more_menu.text = "More •" if updates_button != null and updates_button.text.begins_with("Updates •") else "More"
	if m10_reset_button != null:
		CrashVectorM16Theme.accent_button(m10_reset_button)

func _update_selection_ring() -> void:
	if m10_selection_ring == null:
		return
	if simulation_running or comparison_active or _m161_has_replay():
		m10_selection_ring.visible = false
		return
	super._update_selection_ring()
	# Keep the edit affordance useful without letting it dominate the scene.
	m10_selection_ring.scale *= 0.72

func _m161_has_replay() -> bool:
	return replay_recorder != null and replay_recorder.recording != null and replay_recorder.recording.has_frames()

func _frame_scenario() -> void:
	_m161_apply_camera(true)

func _on_camera_side() -> void:
	_m161_apply_camera(false)

func _m161_frame_aftermath() -> void:
	if not _m161_has_replay():
		return
	_m161_apply_camera(true)

func _m161_apply_camera(three_quarter: bool) -> void:
	if camera == null:
		return
	var bounds := _m161_horizontal_bounds()
	var center_x := (bounds.x + bounds.y) * 0.5
	var span_x := maxf(bounds.y - bounds.x, 4.5)
	var primary_center := _m161_primary_center()
	var target_center := _m161_target_center()
	var center_z := (primary_center.z + target_center.z) * 0.5
	var focus := Vector3(center_x, 0.92, center_z)

	camera.fov = 52.0
	var aspect := 1.55
	if m10_viewport_frame != null and m10_viewport_frame.size.y > 1.0:
		aspect = maxf(m10_viewport_frame.size.x / m10_viewport_frame.size.y, 1.0)
	var vertical_fov := deg_to_rad(camera.fov)
	var horizontal_fov := 2.0 * atan(tan(vertical_fov * 0.5) * aspect)
	var distance := (span_x * 0.5) / maxf(tan(horizontal_fov * 0.5) * 0.70, 0.10)
	distance = clampf(distance, 5.4, 24.0)

	if three_quarter:
		camera.position = Vector3(
			center_x - distance * 0.12,
			focus.y + clampf(distance * 0.23, 2.25, 4.2),
			center_z + distance
		)
	else:
		camera.position = Vector3(center_x, focus.y + clampf(distance * 0.18, 2.0, 3.3), center_z + distance)
	camera.look_at(focus, Vector3.UP)

func _m161_horizontal_bounds() -> Vector2:
	var primary_center := _m161_primary_center()
	var target_center := _m161_target_center()
	var primary_half := float(PassengerCarCatalog.data(scenario.car_preset_id).get("representative_length_m", 4.1)) * 0.5
	var target_half := _m161_target_half_length()
	var minimum := minf(primary_center.x - primary_half, target_center.x - target_half)
	var maximum := maxf(primary_center.x + primary_half, target_center.x + target_half)
	return Vector2(minimum, maximum)

func _m161_primary_center() -> Vector3:
	if car != null and is_instance_valid(car) and car.rigid_chassis != null and is_instance_valid(car.rigid_chassis):
		return car.rigid_chassis.global_position
	return scenario.car_position_m

func _m161_target_center() -> Vector3:
	if scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		if target_car != null and is_instance_valid(target_car) and target_car.rigid_chassis != null and is_instance_valid(target_car.rigid_chassis):
			return target_car.rigid_chassis.global_position
	elif scenario.target_type == ScenarioConfig.TARGET_TRUCK:
		if truck != null and is_instance_valid(truck) and truck.rigid_chassis != null and is_instance_valid(truck.rigid_chassis):
			return truck.rigid_chassis.global_position
	elif scenario.target_type == ScenarioConfig.TARGET_PEDESTRIAN or scenario.target_type == ScenarioConfig.TARGET_BICYCLE:
		if road_user_proxy != null and is_instance_valid(road_user_proxy):
			return road_user_proxy.center_of_mass_position()
	elif obstacle != null and is_instance_valid(obstacle):
		if obstacle.yield_body != null and is_instance_valid(obstacle.yield_body) and obstacle.has_yielded():
			return obstacle.yield_body.global_position
	return scenario.target_position_m

func _m161_target_half_length() -> float:
	match scenario.target_type:
		ScenarioConfig.TARGET_PASSENGER_CAR:
			return float(PassengerCarCatalog.data(scenario.target_preset_id).get("representative_length_m", 4.1)) * 0.5
		ScenarioConfig.TARGET_TRUCK:
			return 4.8
		ScenarioConfig.TARGET_LORRY:
			return 3.6
		ScenarioConfig.TARGET_MOTORCYCLE:
			return 1.2
		ScenarioConfig.TARGET_BICYCLE:
			return 0.95
		ScenarioConfig.TARGET_PEDESTRIAN:
			return 0.40
		ScenarioConfig.TARGET_BARRIER:
			return 0.45
		ScenarioConfig.TARGET_POLE, ScenarioConfig.TARGET_TREE:
			return 0.45
		_:
			return 0.35

func _m161_polish_ui() -> void:
	if m16_more_menu != null:
		m16_more_menu.text = "More"
	if m16_action_slot != null:
		m16_action_slot.custom_minimum_size.x = 168.0
	var brand := m10_root.find_child("M16Brand", true, false) as Label if m10_root != null else null
	if brand != null:
		brand.custom_minimum_size.x = 132.0
		brand.add_theme_font_size_override("font_size", 19)
	if m10_metrics_summary != null:
		m10_metrics_summary.visible = false
	if m16_results_hint != null:
		m16_results_hint.visible = false
	if m10_vehicle_speed != null:
		m10_vehicle_speed.custom_minimum_size.y = 36.0
	if m10_status_label != null:
		m10_status_label.add_theme_font_size_override("font_size", 11)
	if m10_reset_button != null:
		CrashVectorM16Theme.accent_button(m10_reset_button)
	_m161_set_panel_padding(m10_top_bar, 8, 4)
	_m161_set_panel_padding(m10_left_panel, 10, 10)
	_m161_set_panel_padding(m10_right_panel, 10, 10)
	_m161_set_panel_padding(m10_replay_drawer, 8, 4)
	_m161_set_panel_padding(m16_viewport_toolbar, 5, 3)
	if m16_viewport_toolbar != null:
		var toolbar_row := m16_viewport_toolbar.find_child("", true, false)
		for child in m16_viewport_toolbar.get_children():
			if child is MarginContainer:
				for nested in child.get_children():
					if nested is HBoxContainer:
						nested.add_theme_constant_override("separation", 0)
						for item in nested.get_children():
							if item is Button or item is CheckButton:
								item.add_theme_font_size_override("font_size", 13)

func _m161_set_panel_padding(panel: Control, horizontal: int, vertical: int) -> void:
	if panel == null:
		return
	for child in panel.get_children():
		if child is MarginContainer:
			child.add_theme_constant_override("margin_left", horizontal)
			child.add_theme_constant_override("margin_right", horizontal)
			child.add_theme_constant_override("margin_top", vertical)
			child.add_theme_constant_override("margin_bottom", vertical)
			return

func _m161_polish_environment() -> void:
	var world_environment := _find_world_environment()
	if world_environment == null or world_environment.environment == null:
		return
	var env := world_environment.environment
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("34495d")
	sky_material.sky_horizon_color = Color("91a1ad")
	sky_material.ground_horizon_color = Color("7a8684")
	sky_material.ground_bottom_color = Color("343d3f")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.78

func _fit_m16_desktop_geometry() -> void:
	if m10_root == null or m10_top_bar == null:
		return
	var size := get_viewport().get_visible_rect().size
	if m10_mode == MODE_COMPARE or comparison_active or size.x < 1060.0:
		super._fit_m16_desktop_geometry()
		return

	var outer := 8.0
	var gap := 8.0
	var top_height := 56.0
	var top_y := outer + top_height + gap
	_set_rect(m10_top_bar, outer, outer, size.x - outer, outer + top_height)

	var bottom_margin := 8.0
	var requested_bottom := 224.0 if m10_replay_expanded else 58.0
	var replay_height := maxf(requested_bottom, m10_replay_drawer.get_combined_minimum_size().y)
	var content_bottom := size.y - replay_height - bottom_margin - gap

	var compact := size.x < 1500.0
	var requested_left := 218.0 if compact else 230.0
	var requested_right := 270.0 if compact else 284.0
	var left_width := maxf(requested_left, m10_left_panel.get_combined_minimum_size().x)
	var right_width := maxf(requested_right, m10_right_panel.get_combined_minimum_size().x)
	var viewport_left := outer + left_width + gap
	var viewport_right := size.x - outer - right_width - gap

	_set_rect(m10_left_panel, outer, top_y, outer + left_width, content_bottom)
	_set_rect(m10_right_panel, size.x - outer - right_width, top_y, size.x - outer, content_bottom)
	_set_rect(m10_viewport_frame, viewport_left, top_y, viewport_right, content_bottom)
	_set_rect(m10_replay_drawer, viewport_left, size.y - replay_height - bottom_margin, viewport_right, size.y - bottom_margin)

	var viewport_width := maxf(viewport_right - viewport_left, 1.0)
	var status_width := 116.0
	_set_rect(m10_status_chip, viewport_left + 10.0, top_y + 10.0, viewport_left + 10.0 + status_width, top_y + 38.0)
	if m16_viewport_toolbar != null:
		var toolbar_width := minf(410.0, viewport_width - 20.0)
		var toolbar_top := top_y + 10.0
		if viewport_width < 570.0:
			toolbar_top = top_y + 44.0
		_set_rect(m16_viewport_toolbar, viewport_right - toolbar_width - 10.0, toolbar_top, viewport_right - 10.0, toolbar_top + 40.0)
