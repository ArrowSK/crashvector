# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m16_1.gd"

# M16.2 is another presentation-only layer. It preserves the finalized M12-M15
# physics and addresses packaged beta.2 review findings: impact-cluster camera
# composition, immutable scenario-editor values, connected articulated-road-user
# skins, deformation fairing and a clearer tractor/trailer silhouette.

var m162_scenario_snapshot: Dictionary = {}
var m162_road_user_skin: RoadUserPresentationSkin3D
var m162_truck_skin: M162HeavyTruckVisual

func _ready() -> void:
	super._ready()
	_m162_polish_ui()
	call_deferred("_m162_refresh_presentation_skins")

func _physics_process(delta: float) -> void:
	var was_running := simulation_running
	super._physics_process(delta)
	if was_running and not simulation_running:
		_m162_restore_scenario_definition()

func _rebuild_preview() -> void:
	_m162_dispose_presentation_skins()
	super._rebuild_preview()
	call_deferred("_m162_refresh_presentation_skins")

func _clear_runtime_objects() -> void:
	_m162_dispose_presentation_skins()
	super._clear_runtime_objects()

func _ensure_m16_vehicle_visual(vehicle_node: CompactHatchback, node_name: String) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return
	var existing := vehicle_node.get_node_or_null(node_name)
	if existing != null:
		if existing is M162VehicleVisual:
			return
		vehicle_node.remove_child(existing)
		existing.queue_free()
	var visual := M162VehicleVisual.new()
	visual.name = node_name
	vehicle_node.add_child(visual)
	visual.configure(vehicle_node)
	visual.name = node_name

func _on_simulate_pressed() -> void:
	m162_scenario_snapshot = scenario.to_dictionary().duplicate(true)
	super._on_simulate_pressed()
	if not simulation_running:
		m162_scenario_snapshot.clear()

func _on_reset_pressed() -> void:
	super._on_reset_pressed()
	m162_scenario_snapshot.clear()
	call_deferred("_m162_refresh_presentation_skins")

func _on_new_pressed() -> void:
	m162_scenario_snapshot.clear()
	super._on_new_pressed()

func _on_open_path_selected(path: String) -> void:
	m162_scenario_snapshot.clear()
	super._on_open_path_selected(path)

func _m162_restore_scenario_definition() -> void:
	if m162_scenario_snapshot.is_empty():
		return
	# Runtime transforms belong to replay/analysis. The editable ScenarioConfig
	# is restored from the exact pre-run definition before the completed state is
	# shown, so Properties never turns a final rigid-body pose into the next run's
	# starting geometry.
	var restored := ScenarioConfig.from_dictionary(m162_scenario_snapshot)
	if restored == null:
		return
	scenario = restored
	_sync_m10_from_scenario()
	if m10_title_edit != null:
		m10_title_edit.tooltip_text = scenario.title

func _m161_frame_aftermath() -> void:
	if not _m161_has_replay():
		return
	_m162_apply_aftermath_camera()

func _m162_apply_aftermath_camera() -> void:
	if camera == null or scenario == null:
		return
	var forward := scenario.car_forward()
	if forward.is_zero_approx():
		forward = Vector3.RIGHT
	var lateral := forward.cross(Vector3.UP).normalized()
	if lateral.is_zero_approx():
		lateral = Vector3.FORWARD
	var anchor := _m162_impact_anchor()
	var car_center := _m161_primary_center()
	var target_center := _m161_target_center()

	# Major bodies influence the shot, but they cannot drag the camera arbitrarily
	# far from the collision site during a long 4 s coast/rebound. Detached bumper
	# pieces and other small debris are deliberately not camera subjects at all.
	var car_subject := anchor + _m162_limit_vector(car_center - anchor, 6.5)
	var target_limit := 8.5 if scenario.target_type in [ScenarioConfig.TARGET_PEDESTRIAN, ScenarioConfig.TARGET_BICYCLE] else 5.5
	if scenario.target_type == ScenarioConfig.TARGET_TRUCK:
		target_limit = 3.2
	elif scenario.target_type in [ScenarioConfig.TARGET_WALL, ScenarioConfig.TARGET_BARRIER, ScenarioConfig.TARGET_POLE, ScenarioConfig.TARGET_TREE]:
		target_limit = 1.2
	var target_subject := anchor + _m162_limit_vector(target_center - anchor, target_limit)

	var target_weight := 0.34 if scenario.target_type in [ScenarioConfig.TARGET_PEDESTRIAN, ScenarioConfig.TARGET_BICYCLE] else 0.20
	var car_weight := 0.34
	var anchor_weight := 1.0 - target_weight - car_weight
	var focus_point := anchor * anchor_weight + car_subject * car_weight + target_subject * target_weight
	focus_point.y = 1.02 if scenario.target_type == ScenarioConfig.TARGET_TRUCK else 0.88

	var primary_half := float(PassengerCarCatalog.data(scenario.car_preset_id).get("representative_length_m", 4.1)) * 0.5
	var car_projection := (car_subject - anchor).dot(forward)
	var target_projection := (target_subject - anchor).dot(forward)
	var target_extent := _m162_aftermath_target_extent()
	var min_projection := minf(-2.1, minf(car_projection - primary_half * 0.72, target_projection - target_extent))
	var max_projection := maxf(2.1, maxf(car_projection + primary_half * 0.72, target_projection + target_extent))
	var span := clampf(max_projection - min_projection, 4.6, 10.5)
	if scenario.target_type == ScenarioConfig.TARGET_TRUCK:
		span = minf(span, 8.6)

	camera.fov = 50.0
	var aspect := 1.55
	if m10_viewport_frame != null and m10_viewport_frame.size.y > 1.0:
		aspect = maxf(m10_viewport_frame.size.x / m10_viewport_frame.size.y, 1.0)
	var vertical_fov := deg_to_rad(camera.fov)
	var horizontal_fov := 2.0 * atan(tan(vertical_fov * 0.5) * aspect)
	var distance := (span * 0.5) / maxf(tan(horizontal_fov * 0.5) * 0.76, 0.10)
	distance = clampf(distance, 5.0, 13.5)

	camera.global_position = focus_point - forward * distance * 0.10 + Vector3.UP * clampf(distance * 0.22, 2.05, 3.6) + lateral * distance
	camera.look_at(focus_point, Vector3.UP)

func _m162_impact_anchor() -> Vector3:
	var forward := scenario.car_forward()
	if forward.is_zero_approx():
		forward = Vector3.RIGHT
	var primary_half := float(PassengerCarCatalog.data(scenario.car_preset_id).get("representative_length_m", 4.1)) * 0.5
	var car_contact := scenario.car_position_m + forward * primary_half
	var target_contact := scenario.target_position_m
	if scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		var target_half := float(PassengerCarCatalog.data(scenario.target_car_preset_id).get("representative_length_m", 4.1)) * 0.5
		target_contact -= forward * target_half
	elif scenario.target_type == ScenarioConfig.TARGET_BARRIER:
		target_contact -= forward * 0.20
	elif scenario.target_type == ScenarioConfig.TARGET_WALL:
		target_contact -= forward * 0.08
	return (car_contact + target_contact) * 0.5

func _m162_aftermath_target_extent() -> float:
	match scenario.target_type:
		ScenarioConfig.TARGET_TRUCK:
			# The contact is at the trailer rear. Showing the whole 9.5 m assembly in
			# the aftermath recreates the beta.2 dead-space problem; the impact end
			# and adjacent trailer structure are the relevant crash subjects.
			return 2.2
		ScenarioConfig.TARGET_PASSENGER_CAR:
			return float(PassengerCarCatalog.data(scenario.target_car_preset_id).get("representative_length_m", 4.1)) * 0.42
		ScenarioConfig.TARGET_PEDESTRIAN:
			return 0.75
		ScenarioConfig.TARGET_BICYCLE:
			return 1.05
		ScenarioConfig.TARGET_BARRIER:
			return 0.70
		_:
			return 0.55

func _m162_limit_vector(value: Vector3, maximum: float) -> Vector3:
	var length := value.length()
	if length <= maximum or length < 0.0001:
		return value
	return value / length * maximum

func _m162_refresh_presentation_skins() -> void:
	if road_user_proxy != null and is_instance_valid(road_user_proxy):
		if m162_road_user_skin == null or not is_instance_valid(m162_road_user_skin) or m162_road_user_skin.proxy != road_user_proxy:
			if m162_road_user_skin != null and is_instance_valid(m162_road_user_skin):
				m162_road_user_skin.queue_free()
			m162_road_user_skin = RoadUserPresentationSkin3D.new()
			add_child(m162_road_user_skin)
			m162_road_user_skin.configure(road_user_proxy)
	if truck != null and is_instance_valid(truck):
		if m162_truck_skin == null or not is_instance_valid(m162_truck_skin) or m162_truck_skin.truck != truck:
			if m162_truck_skin != null and is_instance_valid(m162_truck_skin):
				m162_truck_skin.queue_free()
			m162_truck_skin = M162HeavyTruckVisual.new()
			truck.add_child(m162_truck_skin)
			m162_truck_skin.configure(truck)

func _m162_dispose_presentation_skins() -> void:
	if m162_road_user_skin != null and is_instance_valid(m162_road_user_skin):
		m162_road_user_skin.queue_free()
	m162_road_user_skin = null
	if m162_truck_skin != null and is_instance_valid(m162_truck_skin):
		m162_truck_skin.queue_free()
	m162_truck_skin = null

func _m162_polish_ui() -> void:
	if m10_title_edit != null:
		m10_title_edit.tooltip_text = m10_title_edit.text
		m10_title_edit.add_theme_font_size_override("font_size", 12)
	# The selector labels already explain this workflow. Removing the leftover
	# tutorial paragraph gives the crash viewport more breathing room and avoids
	# repeating information on every run.
	if m10_left_panel != null:
		_m162_hide_label_starting_with(m10_left_panel, "Choose the vehicle, target and speed.")

func _m162_hide_label_starting_with(node: Node, prefix: String) -> void:
	if node is Label:
		var label := node as Label
		if label.text.begins_with(prefix):
			label.visible = false
	for child in node.get_children():
		_m162_hide_label_starting_with(child, prefix)
