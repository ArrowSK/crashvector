# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m16.gd"

# Final M16 production shell. The M10 responsive-layout regression and
# downstream extensions use the legacy region names as stable contracts. M16
# changes their content/hierarchy while also carrying the finalized M15
# articulated vulnerable-road-user production path into the release scene.

const M16_ROAD_USER_LAYER: int = 2
const M16_ROAD_USER_GROUND_LAYER: int = 4

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
	_configure_m15_articulated_collision_channels()
	_layout_m10()

func _rebuild_preview() -> void:
	super._rebuild_preview()
	_configure_m15_articulated_collision_channels()

func _replace_legacy_road_user_with_rigid_proxy() -> void:
	# M16 inherits the stable M14 editor/physics shell, but the production scene
	# must instantiate the finalized M15 articulated proxy rather than the M14
	# single-root compatibility proxy.
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

	road_user_proxy = RoadUserArticulatedProxy3D.new()
	road_user_proxy.name = "RoadUserArticulatedProxy"
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
	pedestrian = road_user_proxy.pedestrian_visual
	if status_label != null:
		status_label.text = "Bounded articulated road-user preview — press Simulate"
	_update_metrics()

func _configure_m15_articulated_collision_channels() -> void:
	if road_user_proxy == null or not is_instance_valid(road_user_proxy):
		return
	var road := get_node_or_null("Road") as StaticBody3D
	if road != null:
		road.collision_layer |= M16_ROAD_USER_GROUND_LAYER
	_set_m15_road_user_body_channels(road_user_proxy)
	for body in road_user_proxy.articulated_bodies:
		if body != null and is_instance_valid(body):
			_set_m15_road_user_body_channels(body)
	_rebind_m15_articulated_joints()
	if car != null and car.rigid_chassis != null and car.rigid_chassis.front_crush_probe != null:
		car.rigid_chassis.front_crush_probe.collision_mask = M16_ROAD_USER_LAYER

func _set_m15_road_user_body_channels(body: PhysicsBody3D) -> void:
	body.collision_layer = M16_ROAD_USER_LAYER
	body.collision_mask = M16_ROAD_USER_GROUND_LAYER

func _rebind_m15_articulated_joints() -> void:
	if road_user_proxy == null:
		return
	for joint in road_user_proxy.articulated_joints:
		if joint == null or not is_instance_valid(joint):
			continue
		var body_a_path := joint.node_a
		var body_b_path := joint.node_b
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.node_a = body_a_path
		joint.node_b = body_b_path

func _sync_m10_from_scenario() -> void:
	super._sync_m10_from_scenario()
	# The selected object is already named in the Properties heading. Keeping
	# these two selector labels short prevents a long target name from dictating
	# the width of the entire desktop inspector.
	if m16_primary_button != null:
		m16_primary_button.text = "Primary"
	if m16_target_button != null:
		m16_target_button.text = "Target"

func _ensure_m16_vehicle_visual(vehicle_node: CompactHatchback, node_name: String) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return
	if vehicle_node.get_node_or_null(node_name) != null:
		return
	var visual := M16VehicleVisualRefined.new()
	vehicle_node.add_child(visual)
	visual.configure(vehicle_node)
	visual.name = node_name

func _layout_m10() -> void:
	super._layout_m10()
	_fit_m16_desktop_geometry()

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

func _fit_m16_desktop_geometry() -> void:
	if m10_root == null or m10_top_bar == null:
		return
	var size := get_viewport().get_visible_rect().size
	var top_height := maxf(50.0, m10_top_bar.get_combined_minimum_size().y)
	var top_bottom := 10.0 + top_height
	var top_y := top_bottom + 10.0
	_set_rect(m10_top_bar, 12.0, 10.0, size.x - 12.0, top_bottom)

	if m10_mode == MODE_COMPARE or comparison_active:
		_set_rect(m10_viewport_frame, 12.0, top_y, size.x - 12.0, size.y - 12.0)
		if m10_compare_header != null:
			_set_rect(m10_compare_header, 22.0, top_y + 10.0, size.x - 22.0, top_y + 68.0)
		if comparison_active and m10_compare_results != null:
			_set_rect(m10_compare_results, 22.0, size.y - 238.0, size.x - 22.0, size.y - 18.0)
		return

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
