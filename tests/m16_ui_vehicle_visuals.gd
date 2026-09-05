# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("M16 could not load the production scene")
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	for _frame in range(6):
		await process_frame

	for wanted in [
		"M10TopBar", "M10ScenarioPanel", "M10Inspector", "M10ViewportFrame", "M10ReplayDrawer",
		"M16FileMenu", "M16MoreMenu", "M16VehicleSelector", "M16TargetSelector",
		"M16PropertiesHeader", "M16PrimaryProperties", "M16TargetProperties", "M16ViewportToolbar"
	]:
		if _find_named(instance, wanted) == null:
			_fail("M16 production shell is missing %s" % wanted)
			return

	root.size = Vector2i(1280, 720)
	await process_frame
	instance.call("_layout_m10")
	await process_frame
	var left := _find_named(instance, "M10ScenarioPanel") as Control
	var right := _find_named(instance, "M10Inspector") as Control
	var viewport := _find_named(instance, "M10ViewportFrame") as Control
	var replay := _find_named(instance, "M10ReplayDrawer") as Control
	if left == null or right == null or viewport == null or replay == null:
		_fail("M16 major regions could not be resolved")
		return
	if _overlaps(left, viewport) or _overlaps(viewport, right) or _overlaps(left, right):
		_fail("M16 task-focused regions overlap at 1280x720")
		return
	if viewport.size.x < 620.0 or viewport.size.y < 420.0:
		_fail("M16 gives too little space to the crash viewport: %s" % viewport.size)
		return
	if replay.position.y < viewport.position.y + viewport.size.y - 0.5:
		_fail("M16 playback dock overlaps the viewport")
		return

	var primary_visual := _find_named(instance, "M16PrimaryVehicleVisual") as M16VehicleVisual
	if primary_visual == null:
		_fail("M16 did not attach the production vehicle presentation skin")
		return
	var primary_vehicle := primary_visual.get_parent() as CompactHatchback
	if primary_vehicle == null or primary_vehicle.body_shell == null or primary_vehicle.wheel_rig == null:
		_fail("M16 vehicle visual is not attached to the production passenger-car model")
		return
	if primary_vehicle.body_shell.visible or primary_vehicle.wheel_rig.visible:
		_fail("M16 left the legacy scaled shell/wheels visible under the replacement skin")
		return

	var b := VehicleVisualProfileCatalog.visual_signature(PassengerCarCatalog.B_SEGMENT_HATCHBACK)
	var d := VehicleVisualProfileCatalog.visual_signature(PassengerCarCatalog.D_SEGMENT_MIDSIZE)
	var suv := VehicleVisualProfileCatalog.visual_signature(PassengerCarCatalog.J_SEGMENT_SUV)
	var mpv := VehicleVisualProfileCatalog.visual_signature(PassengerCarCatalog.M_SEGMENT_MPV)
	if float(suv["roof_mid_m"]) <= float(b["roof_mid_m"]) + 0.12:
		_fail("M16 SUV profile is still effectively hatchback-height")
		return
	if float(suv["wheel_radius_m"]) <= float(b["wheel_radius_m"]) + 0.05:
		_fail("M16 SUV wheel package is not materially distinct from the B-class")
		return
	if float(d["roof_mid_m"]) >= float(b["roof_mid_m"]) - 0.08:
		_fail("M16 midsize profile did not gain a lower, longer visual stance")
		return
	if float(mpv["windscreen_offset_m"]) <= float(b["windscreen_offset_m"]) + 0.25:
		_fail("M16 MPV profile is not materially cab-forward")
		return
	if float(mpv["glass_end_u"]) <= float(b["glass_end_u"]) + 0.06:
		_fail("M16 MPV greenhouse does not extend far enough forward")
		return

	var selector := _find_named(instance, "M16VehicleSelector") as OptionButton
	var suv_index := _metadata_index(selector, PassengerCarCatalog.J_SEGMENT_SUV)
	if suv_index < 0:
		_fail("M16 vehicle selector does not expose the SUV archetype")
		return
	selector.select(suv_index)
	selector.item_selected.emit(suv_index)
	for _frame in range(8):
		await process_frame
	primary_visual = _find_named(instance, "M16PrimaryVehicleVisual") as M16VehicleVisual
	if primary_visual == null or primary_visual.profile_id != PassengerCarCatalog.J_SEGMENT_SUV:
		_fail("M16 did not rebuild the class-specific visual when the vehicle class changed")
		return

	# M16 is the production successor to M15. Selecting a pedestrian must still
	# instantiate the finalized articulated proxy rather than falling back to the
	# M14 compatibility target while the UI/vehicle presentation changes around it.
	var target_selector := _find_named(instance, "M16TargetSelector") as OptionButton
	var pedestrian_index := _metadata_index(target_selector, ScenarioConfig.TARGET_PEDESTRIAN)
	if pedestrian_index < 0:
		_fail("M16 target selector does not expose the pedestrian target")
		return
	target_selector.select(pedestrian_index)
	target_selector.item_selected.emit(pedestrian_index)
	for _frame in range(8):
		await process_frame
	var road_user_proxy: Variant = instance.get("road_user_proxy")
	if not road_user_proxy is RoadUserArticulatedProxy3D:
		_fail("M16 production scene did not preserve the finalized M15 articulated road-user path")
		return
	var articulated := road_user_proxy as RoadUserArticulatedProxy3D
	if articulated.articulated_body_count() < 10 or articulated.articulated_joint_count() < 9:
		_fail("M16 production pedestrian lost the M15 articulated topology")
		return
	if articulated.collision_layer != 2 or articulated.collision_mask != 4:
		_fail("M16 production pedestrian lost the isolated M15 collision channels")
		return

	instance.queue_free()
	await process_frame
	print("CrashVector M16 UX, vehicle-visual and M15 integration regression test passed.")
	quit(0)

func _metadata_index(option: OptionButton, wanted: StringName) -> int:
	if option == null:
		return -1
	for index in range(option.item_count):
		if StringName(String(option.get_item_metadata(index))) == wanted:
			return index
	return -1

func _overlaps(a: Control, b: Control) -> bool:
	return Rect2(a.position, a.size).intersects(Rect2(b.position, b.size))

func _find_named(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
