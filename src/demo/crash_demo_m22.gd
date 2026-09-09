# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m21.gd"

# M22 extends only vulnerable-road-user scope. The riderless bicycle remains a
# separate target, pedestrians retain the finalized M15 articulated topology but
# may now begin with a configured translation speed, and the new cyclist target
# uses M22RoadUserProxy3D (generic rider + bicycle with contact-time release).

func _is_road_user_target() -> bool:
	return scenario.target_type == ScenarioConfig.TARGET_CYCLIST or super._is_road_user_target()

func _target_supports_hybrid_world() -> bool:
	# The cyclist reuses M14's articulated road-user world path. Add it to the
	# M14 support gate so the preview is not left runnable-looking but blocked
	# before simulation, replay capture, and probe-contact release can begin.
	if scenario != null and scenario.target_type == ScenarioConfig.TARGET_CYCLIST:
		return true
	return super._target_supports_hybrid_world()

func _target_is_dynamic() -> bool:
	return scenario.target_type == ScenarioConfig.TARGET_CYCLIST or super._target_is_dynamic()

func _replace_legacy_road_user_with_rigid_proxy() -> void:
	if scenario.target_type != ScenarioConfig.TARGET_CYCLIST:
		super._replace_legacy_road_user_with_rigid_proxy()
		return
	if bicycle != null and is_instance_valid(bicycle) and bicycle.get_parent() == self:
		remove_child(bicycle)
		bicycle.queue_free()
	if pedestrian != null and is_instance_valid(pedestrian) and pedestrian.get_parent() == self:
		remove_child(pedestrian)
		pedestrian.queue_free()
	bicycle = null
	pedestrian = null
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true

	road_user_proxy = M22RoadUserProxy3D.new()
	road_user_proxy.name = "M22CyclistProxy"
	road_user_proxy.configure(
		scenario.target_type,
		scenario.target_preset_id,
		scenario.target_mass_kg,
		scenario.target_speed_kmh,
		scenario.target_position_m,
		scenario.target_heading_deg,
		scenario.show_structure
	)
	add_child(road_user_proxy)
	bicycle = road_user_proxy.bicycle_visual
	pedestrian = null
	if status_label != null:
		status_label.text = "Generic articulated cyclist preview — press Simulate"
	_update_metrics()

func _m162_refresh_presentation_skins() -> void:
	super._m162_refresh_presentation_skins()
	if scenario == null or scenario.target_type != ScenarioConfig.TARGET_CYCLIST:
		return
	if road_user_proxy == null or not is_instance_valid(road_user_proxy):
		return
	if m162_road_user_skin is M22RoadUserPresentationSkin3D and m162_road_user_skin.proxy == road_user_proxy:
		return
	if m162_road_user_skin != null and is_instance_valid(m162_road_user_skin):
		m162_road_user_skin.queue_free()
	m162_road_user_skin = M22RoadUserPresentationSkin3D.new()
	add_child(m162_road_user_skin)
	m162_road_user_skin.configure(road_user_proxy)

func _rebuild_inspector() -> void:
	if selected_object != &"target" or scenario.target_type not in [ScenarioConfig.TARGET_CYCLIST, ScenarioConfig.TARGET_PEDESTRIAN]:
		super._rebuild_inspector()
		return
	for child in inspector_column.get_children():
		inspector_column.remove_child(child)
		child.queue_free()

	var inspector_title := Label.new()
	inspector_title.text = ScenarioConfig.target_display_name(scenario.target_type)
	inspector_title.add_theme_font_size_override("font_size", 18)
	inspector_column.add_child(inspector_title)

	var preset_row := HBoxContainer.new()
	inspector_column.add_child(preset_row)
	var preset_label := Label.new()
	preset_label.text = "Bicycle" if scenario.target_type == ScenarioConfig.TARGET_CYCLIST else "Body type"
	preset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(preset_label)
	target_preset_option = OptionButton.new()
	var ids := RoadUserCatalog.bicycle_ids() if scenario.target_type == ScenarioConfig.TARGET_CYCLIST else RoadUserCatalog.pedestrian_ids()
	for id in ids:
		target_preset_option.add_item(RoadUserCatalog.display_name(id))
		target_preset_option.set_item_metadata(target_preset_option.item_count - 1, id)
	target_preset_option.item_selected.connect(_on_target_preset_selected)
	preset_row.add_child(target_preset_option)

	if scenario.target_type == ScenarioConfig.TARGET_CYCLIST:
		mass_spin = _add_spin(inspector_column, "Combined mass (kg)", RoadUserCatalog.cyclist_minimum_mass_kg(scenario.target_preset_id), 220.0, 1.0)
		speed_spin = _add_spin(inspector_column, "Initial speed (km/h)", 0.0, 80.0, 1.0)
	else:
		mass_spin = _add_spin(inspector_column, "Body mass (kg)", 15.0, 200.0, 1.0)
		speed_spin = _add_spin(inspector_column, "Initial speed (km/h)", 0.0, 20.0, 0.5)
	mass_spin.value_changed.connect(_on_object_spin_changed.bind(&"mass"))
	speed_spin.value_changed.connect(_on_object_spin_changed.bind(&"speed"))

	x_spin = _add_spin(inspector_column, "Position X (m)", -25.0, 25.0, 0.1)
	z_spin = _add_spin(inspector_column, "Position Z (m)", -5.0, 5.0, 0.1)
	heading_spin = _add_spin(inspector_column, "Heading (deg)", -180.0, 180.0, 1.0)
	x_spin.value_changed.connect(_on_object_spin_changed.bind(&"x"))
	z_spin.value_changed.connect(_on_object_spin_changed.bind(&"z"))
	heading_spin.value_changed.connect(_on_object_spin_changed.bind(&"heading"))

	var rotate_row := HBoxContainer.new()
	inspector_column.add_child(rotate_row)
	var rotate_left := Button.new()
	rotate_left.text = "Rotate -5°"
	rotate_left.pressed.connect(_rotate_selected.bind(-5.0))
	rotate_row.add_child(rotate_left)
	var rotate_right := Button.new()
	rotate_right.text = "Rotate +5°"
	rotate_right.pressed.connect(_rotate_selected.bind(5.0))
	rotate_row.add_child(rotate_right)

	var note := Label.new()
	if scenario.target_type == ScenarioConfig.TARGET_CYCLIST:
		note.text = "Generic rider + selected bicycle. Rider coupling releases after contact. This is a trajectory/contact model, not biomechanics or injury prediction."
	else:
		note.text = "Initial speed translates the whole articulated pedestrian along its heading. It does not simulate a walking/running gait and remains a contact/trajectory model."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_column.add_child(note)
	_sync_current_object_fields()

func _sync_m10_from_scenario() -> void:
	if m10_target_mass != null and m10_target_speed != null and scenario != null:
		match scenario.target_type:
			ScenarioConfig.TARGET_PASSENGER_CAR:
				_set_m22_target_spin_ranges(500.0, 5000.0, 5.0, 0.0, 300.0, 1.0)
			ScenarioConfig.TARGET_TRUCK:
				_set_m22_target_spin_ranges(3500.0, 60000.0, 50.0, 0.0, 140.0, 1.0)
			ScenarioConfig.TARGET_LORRY:
				_set_m22_target_spin_ranges(3500.0, 26000.0, 50.0, 0.0, 140.0, 1.0)
			ScenarioConfig.TARGET_MOTORCYCLE:
				_set_m22_target_spin_ranges(80.0, 600.0, 1.0, 0.0, 250.0, 1.0)
			ScenarioConfig.TARGET_BICYCLE:
				_set_m22_target_spin_ranges(5.0, 60.0, 1.0, 0.0, 80.0, 1.0)
			ScenarioConfig.TARGET_CYCLIST:
				_set_m22_target_spin_ranges(RoadUserCatalog.cyclist_minimum_mass_kg(scenario.target_preset_id), 220.0, 1.0, 0.0, 80.0, 1.0)
			ScenarioConfig.TARGET_PEDESTRIAN:
				_set_m22_target_spin_ranges(15.0, 200.0, 1.0, 0.0, 20.0, 0.5)
			_:
				_set_m22_target_spin_ranges(0.0, 60000.0, 5.0, 0.0, 300.0, 1.0)
	super._sync_m10_from_scenario()
	# M10 historically hid pedestrian speed because M15 forced it to zero. M22
	# exposes the now-supported initial translation speed without changing layout.
	if m10_target_speed_row != null and scenario != null and scenario.target_type == ScenarioConfig.TARGET_PEDESTRIAN:
		m10_target_speed_row.visible = true

func _set_m22_target_spin_ranges(mass_min: float, mass_max: float, mass_step: float, speed_min: float, speed_max: float, speed_step: float) -> void:
	# Changing SpinBox limits can clamp the current control value and emit
	# value_changed. Treat range updates as UI synchronisation so selecting a new
	# target cannot overwrite ScenarioConfig defaults before the values are synced.
	var was_syncing := m10_syncing
	m10_syncing = true
	m10_target_mass.min_value = mass_min
	m10_target_mass.max_value = mass_max
	m10_target_mass.step = mass_step
	m10_target_speed.min_value = speed_min
	m10_target_speed.max_value = speed_max
	m10_target_speed.step = speed_step
	m10_syncing = was_syncing

func _refresh_m10_target_preset_options() -> void:
	if scenario == null or scenario.target_type != ScenarioConfig.TARGET_CYCLIST:
		super._refresh_m10_target_preset_options()
		return
	if m10_target_preset == null:
		return
	m10_target_preset.clear()
	var ids := RoadUserCatalog.bicycle_ids()
	m10_target_preset_row.visible = true
	for id in ids:
		m10_target_preset.add_item(RoadUserCatalog.display_name(id))
		m10_target_preset.set_item_metadata(m10_target_preset.item_count - 1, id)
	_select_metadata(m10_target_preset, scenario.target_preset_id)

func _on_m10_target_preset_selected(index: int) -> void:
	if scenario.target_type != ScenarioConfig.TARGET_CYCLIST:
		super._on_m10_target_preset_selected(index)
		return
	if m10_syncing or m10_target_preset == null or index < 0 or index >= m10_target_preset.item_count:
		return
	var id := StringName(String(m10_target_preset.get_item_metadata(index)))
	scenario.target_preset_id = id
	scenario.target_mass_kg = RoadUserCatalog.cyclist_default_mass_kg(id)
	selected_object = &"target"
	_request_preview_rebuild()
	_sync_m10_from_scenario()

func _on_target_preset_selected(index: int) -> void:
	if scenario.target_type != ScenarioConfig.TARGET_CYCLIST:
		super._on_target_preset_selected(index)
		return
	if syncing_ui or target_preset_option == null or index < 0 or index >= target_preset_option.item_count:
		return
	var id := StringName(String(target_preset_option.get_item_metadata(index)))
	scenario.target_preset_id = id
	scenario.target_mass_kg = RoadUserCatalog.cyclist_default_mass_kg(id)
	_rebuild_inspector()
	_request_preview_rebuild()

func _on_target_palette_pressed(target_id: StringName) -> void:
	if target_id != ScenarioConfig.TARGET_CYCLIST:
		super._on_target_palette_pressed(target_id)
		return
	selected_object = &"target"
	if scenario.target_type != target_id:
		scenario.apply_target_defaults(target_id)
		_request_preview_rebuild()
	_rebuild_inspector()

func _target_selection_radius() -> float:
	if scenario.target_type == ScenarioConfig.TARGET_CYCLIST:
		return 1.5
	return super._target_selection_radius()

func _m162_aftermath_target_extent() -> float:
	if scenario.target_type == ScenarioConfig.TARGET_CYCLIST:
		return 1.15
	return super._m162_aftermath_target_extent()

func _m162_apply_aftermath_camera() -> void:
	if scenario == null or scenario.target_type != ScenarioConfig.TARGET_CYCLIST:
		super._m162_apply_aftermath_camera()
		return
	# Reuse the established vulnerable-road-user composition without duplicating
	# M16.2 camera code. Cyclist and riderless bicycle share the same local impact
	# scale; the actual target centre still comes from the articulated proxy.
	var original_type := scenario.target_type
	scenario.target_type = ScenarioConfig.TARGET_BICYCLE
	super._m162_apply_aftermath_camera()
	scenario.target_type = original_type

func _update_metrics() -> void:
	super._update_metrics()
	if metrics_label == null or not (road_user_proxy is M22RoadUserProxy3D):
		return
	var cyclist := road_user_proxy as M22RoadUserProxy3D
	if cyclist.target_type != ScenarioConfig.TARGET_CYCLIST:
		return
	metrics_label.text += "\nCyclist • rider coupling %s • wheel spin %.1f rad/s" % [
		"released" if cyclist.cyclist_released else "attached",
		cyclist.maximum_wheel_spin_rad_s,
	]
