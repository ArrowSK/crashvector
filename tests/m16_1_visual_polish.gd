# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("M16.1 could not load the production scene")
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	for _frame in range(8):
		await process_frame

	if not instance.get_script().resource_path.ends_with("crash_demo_m16_1.gd"):
		_fail("Production scene is not routed through the M16.1 presentation layer")
		return

	root.size = Vector2i(1280, 720)
	await process_frame
	instance.call("_layout_m10")
	await process_frame

	var left := _find_named(instance, "M10ScenarioPanel") as Control
	var right := _find_named(instance, "M10Inspector") as Control
	var viewport := _find_named(instance, "M10ViewportFrame") as Control
	var replay := _find_named(instance, "M10ReplayDrawer") as Control
	var status := _find_named(instance, "M10StatusChip") as Control
	var toolbar := _find_named(instance, "M16ViewportToolbar") as Control
	if left == null or right == null or viewport == null or replay == null or status == null or toolbar == null:
		_fail("M16.1 major UI regions could not be resolved")
		return
	if _overlaps(left, viewport) or _overlaps(viewport, right) or _overlaps(left, right):
		_fail("M16.1 side panels overlap the crash viewport at 1280x720")
		return
	if replay.position.y < viewport.position.y + viewport.size.y - 0.5:
		_fail("M16.1 playback dock overlaps the viewport")
		return
	if viewport.size.x < 620.0 or viewport.size.y < 420.0:
		_fail("M16.1 regressed the usable crash viewport: %s" % viewport.size)
		return
	if Rect2(status.position, status.size).intersects(Rect2(toolbar.position, toolbar.size)):
		_fail("M16.1 status chip and viewport toolbar overlap")
		return

	var more := _find_named(instance, "M16MoreMenu") as MenuButton
	if more == null or more.text != "More":
		_fail("M16.1 did not remove the broken More-menu ellipsis glyph")
		return
	var scenario_button: Button = instance.get("m10_scenario_button")
	if scenario_button == null or scenario_button.disabled:
		_fail("M16.1 still represents the active Scenario workspace as disabled")
		return

	var summary := _find_named(instance, "M16ScenarioSummary") as Label
	var results_hint := _find_named(instance, "M16ResultsHint") as Label
	if summary == null or summary.visible:
		_fail("M16.1 did not remove the duplicate left-panel scenario summary")
		return
	if results_hint == null or results_hint.visible:
		_fail("M16.1 did not remove the redundant right-panel results hint")
		return

	var title_edit := _find_named(instance, "M16ScenarioTitle") as LineEdit
	var vehicle_selector := _find_named(instance, "M16VehicleSelector") as OptionButton
	var target_selector := _find_named(instance, "M16TargetSelector") as OptionButton
	if title_edit == null or vehicle_selector == null or target_selector == null:
		_fail("M16.1 title/selector controls are unavailable")
		return
	if title_edit.text != "B-Segment Small Hatchback vs Rigid Wall (full-frontal)":
		_fail("M16.1 did not repair the stale default scenario title: %s" % title_edit.text)
		return

	var d_index := _metadata_index(vehicle_selector, PassengerCarCatalog.D_SEGMENT_MIDSIZE)
	var barrier_index := _metadata_index(target_selector, ScenarioConfig.TARGET_BARRIER)
	if d_index < 0 or barrier_index < 0:
		_fail("M16.1 selectors are missing D-segment or concrete-barrier choices")
		return
	vehicle_selector.select(d_index)
	vehicle_selector.item_selected.emit(d_index)
	for _frame in range(5):
		await process_frame
	target_selector.select(barrier_index)
	target_selector.item_selected.emit(barrier_index)
	for _frame in range(6):
		await process_frame
	if title_edit.text != "D-Segment Midsize Car vs Concrete Barrier":
		_fail("Automatic scenario title did not follow vehicle/target changes: %s" % title_edit.text)
		return

	title_edit.text = "My 200 km/h barrier test"
	title_edit.text_changed.emit(title_edit.text)
	var b_index := _metadata_index(vehicle_selector, PassengerCarCatalog.B_SEGMENT_HATCHBACK)
	vehicle_selector.select(b_index)
	vehicle_selector.item_selected.emit(b_index)
	for _frame in range(6):
		await process_frame
	if title_edit.text != "My 200 km/h barrier test":
		_fail("M16.1 overwrote a user-authored custom scenario title")
		return

	var primary_visual := _find_named(instance, "M16PrimaryVehicleVisual")
	if not primary_visual is M161VehicleVisual:
		_fail("M16.1 did not attach its strengthened class-specific presentation skin")
		return
	var primary_vehicle := primary_visual.get_parent() as CompactHatchback
	if primary_vehicle == null or primary_vehicle.body_shell == null or primary_vehicle.wheel_rig == null:
		_fail("M16.1 presentation skin is detached from the production vehicle")
		return
	if primary_vehicle.body_shell.visible or primary_vehicle.wheel_rig.visible:
		_fail("M16.1 exposed the legacy scaled vehicle skin beneath the new visual")
		return

	var b := VehicleVisualProfileCatalog.visual_signature(PassengerCarCatalog.B_SEGMENT_HATCHBACK)
	var d := VehicleVisualProfileCatalog.visual_signature(PassengerCarCatalog.D_SEGMENT_MIDSIZE)
	var suv := VehicleVisualProfileCatalog.visual_signature(PassengerCarCatalog.J_SEGMENT_SUV)
	var mpv := VehicleVisualProfileCatalog.visual_signature(PassengerCarCatalog.M_SEGMENT_MPV)
	if float(suv["wheel_radius_m"]) < 0.41 or float(suv["roof_mid_m"]) < float(b["roof_mid_m"]) + 0.28:
		_fail("M16.1 SUV archetype is still too close to the B-segment hatchback")
		return
	if float(mpv["glass_end_u"]) < 0.84 or float(mpv["windscreen_offset_m"]) < float(d["windscreen_offset_m"]) + 0.45:
		_fail("M16.1 MPV is not sufficiently cab-forward/long-greenhouse")
		return
	if float(d["glass_end_u"]) > 0.64 or float(d["roof_mid_m"]) >= float(b["roof_mid_m"]) - 0.12:
		_fail("M16.1 D-segment car is not materially lower/longer than the hatchback")
		return

	# The original frame command enforced an 18 m minimum camera offset, which
	# made even severe impacts microscopic. M16.1 should frame a normal scenario
	# materially closer while retaining the whole setup.
	instance.call("_frame_scenario")
	await process_frame
	var camera: Camera3D = instance.get("camera")
	if camera == null:
		_fail("M16.1 camera could not be resolved")
		return
	var scenario: ScenarioConfig = instance.get("scenario")
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5
	var camera_distance := camera.global_position.distance_to(midpoint + Vector3(0.0, 0.92, 0.0))
	if camera_distance >= 17.0 or camera_distance <= 4.0:
		_fail("M16.1 camera framing is still implausibly wide/tight: %.2f m" % camera_distance)
		return

	# Reproduce the orange-oval bug without running a full crash: any completed
	# recording means the editor selection marker must disappear from replay and
	# aftermath presentation.
	var recorder: ReplayRecorder = instance.get("replay_recorder")
	if recorder == null:
		_fail("M16.1 replay recorder could not be resolved")
		return
	recorder.recording.clear()
	recorder.recording.add_frame({"time_s": 0.0, "m16_1_test": true})
	instance.call("_update_selection_ring")
	await process_frame
	var ring := instance.get("m10_selection_ring") as MeshInstance3D
	if ring == null or ring.visible:
		_fail("M16.1 leaves the editor selection ring visible over completed replay")
		return

	instance.queue_free()
	await process_frame
	print("CrashVector M16.1 visual polish, camera and UI regression test passed.")
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
