# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M16.2 could not load the production scene")
	if packed == null:
		_finish()
		return
	var editor := packed.instantiate()
	root.add_child(editor)
	for _frame in range(10):
		await process_frame

	_expect(editor.get_script().resource_path.ends_with("crash_demo_m16_2.gd"), "Production scene is not routed through M16.2")
	var primary_visual := _find_named(editor, "M16PrimaryVehicleVisual")
	_expect(primary_visual is M162VehicleVisual, "Production passenger car is not using the M16.2 deformation-aware skin")
	_expect(not _has_visible_label_prefix(editor.get("m10_left_panel"), "Choose the vehicle, target and speed."), "Redundant M16 tutorial paragraph is still visible")

	var vehicle_selector := _find_named(editor, "M16VehicleSelector") as OptionButton
	var target_selector := _find_named(editor, "M16TargetSelector") as OptionButton
	var speed_control := _find_named(editor, "M16ImpactSpeed") as SpinBox
	_expect(vehicle_selector != null and target_selector != null and speed_control != null, "M16.2 selectors are missing")
	if vehicle_selector == null or target_selector == null or speed_control == null:
		editor.queue_free()
		_finish()
		return

	# Packaged screenshot case 1: SUV + pedestrian. The production M15 proxy must
	# remain authoritative while M16.2 overlays a continuous-looking presentation.
	_select_metadata(vehicle_selector, PassengerCarCatalog.J_SEGMENT_SUV)
	await process_frame
	_select_metadata(target_selector, ScenarioConfig.TARGET_PEDESTRIAN)
	speed_control.value = 50.0
	for _frame in range(10):
		await process_frame
	var proxy: RoadUserRigidProxy3D = editor.get("road_user_proxy")
	var road_skin: RoadUserPresentationSkin3D = editor.get("m162_road_user_skin")
	_expect(proxy is RoadUserArticulatedProxy3D, "SUV-pedestrian preview no longer uses the finalized M15 articulated proxy")
	_expect(road_skin != null and road_skin.proxy == proxy, "M16.2 pedestrian presentation skin is missing or detached")
	if road_skin != null:
		for wanted in ["TorsoSkin", "HeadSkin", "LeftUpperLegSkin", "RightUpperLegSkin"]:
			var visual := _find_named(road_skin, wanted) as MeshInstance3D
			_expect(visual != null and visual.visible, "M16.2 pedestrian visual component %s is missing/hidden" % wanted)
	if proxy != null:
		_expect(_primitive_meshes_hidden(proxy), "Primitive articulated pedestrian blocks remain visible beneath the M16.2 skin")
		for body in proxy.articulated_bodies:
			_expect(_primitive_meshes_hidden(body), "Primitive articulated body %s remains visible beneath the M16.2 skin" % body.name)

	var suv_visual := _find_named(editor, "M16PrimaryVehicleVisual") as M162VehicleVisual
	_expect(suv_visual != null and suv_visual.profile_id == PassengerCarCatalog.J_SEGMENT_SUV, "SUV preview lost the M16.2 class visual")
	if suv_visual != null:
		var section: Dictionary = suv_visual.call("_section_at_u", 0.62)
		var height := _v3(section, "upper_left").y - _v3(section, "lower_left").y
		_expect(height > 1.05, "M16.2 SUV greenhouse/body height is not visually distinct enough: %.2f m" % height)

	# Packaged screenshot case 3: compact car + heavy truck. The old primitive cab
	# and trailer are hidden and replaced by a clearer tractor/trailer silhouette.
	_select_metadata(vehicle_selector, PassengerCarCatalog.C_SEGMENT_COMPACT)
	await process_frame
	_select_metadata(target_selector, ScenarioConfig.TARGET_TRUCK)
	speed_control.value = 90.0
	for _frame in range(10):
		await process_frame
	var truck: HeavyTruck = editor.get("truck")
	var truck_skin: M162HeavyTruckVisual = editor.get("m162_truck_skin")
	_expect(truck != null and truck_skin != null and truck_skin.truck == truck, "M16.2 heavy-truck presentation skin is missing or detached")
	if truck != null and truck_skin != null:
		_expect(truck.trailer_visual != null and not truck.trailer_visual.visible, "Legacy box trailer remains visible under M16.2")
		_expect(truck.cab_visual != null and not truck.cab_visual.visible, "Legacy box cab remains visible under M16.2")
		_expect(_find_named(truck_skin, "TractorCabPresentation") != null, "M16.2 tractor cab presentation is missing")
		_expect(_find_named(truck_skin, "TrailerPresentation") != null, "M16.2 trailer presentation is missing")
		_expect(_find_named(truck_skin, "FifthWheelPresentation") != null, "M16.2 tractor/trailer separation cue is missing")
		_expect(truck.wheel_visuals.size() == 6, "M16.2 changed the existing heavy-truck wheel-anchor presentation contract")

	editor.queue_free()
	await process_frame
	_finish()

func _select_metadata(option: OptionButton, wanted: StringName) -> void:
	for index in range(option.item_count):
		if StringName(String(option.get_item_metadata(index))) == wanted:
			option.select(index)
			option.item_selected.emit(index)
			return
	failures.append("Could not select %s" % String(wanted))

func _primitive_meshes_hidden(node: Node) -> bool:
	if node == null:
		return true
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			return false
		if not _primitive_meshes_hidden(child):
			return false
	return true

func _has_visible_label_prefix(node: Node, prefix: String) -> bool:
	if node == null:
		return false
	if node is Label:
		var label := node as Label
		if label.visible and label.text.begins_with(prefix):
			return true
	for child in node.get_children():
		if _has_visible_label_prefix(child, prefix):
			return true
	return false

func _find_named(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func _v3(section: Dictionary, key: String) -> Vector3:
	var value: Variant = section.get(key, Vector3.ZERO)
	return value if value is Vector3 else Vector3.ZERO

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("CrashVector M16.2 presentation-layer regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
