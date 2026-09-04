# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("M10 editor smoke could not load main scene")
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await process_frame

	var m10 := instance.get_node_or_null("M10UI")
	if m10 == null:
		_fail("M10 UI CanvasLayer is missing")
		return
	for wanted in ["M10Root", "M10TopBar", "M10ScenarioPanel", "M10Inspector", "M10ViewportFrame", "M10ReplayDrawer"]:
		if _find_named(m10, wanted) == null:
			_fail("M10 editor smoke is missing %s" % wanted)
			return

	var scenario := instance.get("scenario") as ScenarioConfig
	if scenario == null:
		_fail("M10 scenario model is missing")
		return
	if scenario.car_preset_id != PassengerCarCatalog.B_SEGMENT_HATCHBACK or scenario.target_type != ScenarioConfig.TARGET_WALL or absf(scenario.car_speed_kmh - 50.0) > 0.001:
		_fail("M10 first-run ready scenario is not B-class vs rigid wall at 50 km/h")
		return
	var solver_control := instance.get("m10_substeps") as SpinBox
	if solver_control == null or int(solver_control.max_value) != ScenarioConfig.MAX_SOLVER_SUBSTEPS:
		_fail("M11 desktop solver control is not aligned with the public 32-substep scenario limit")
		return

	var lab_canvas := instance.get_node_or_null("RoadUserComparisonLabUI")
	var update_canvas := instance.get_node_or_null("M9UpdateUI")
	if lab_canvas == null or update_canvas == null:
		_fail("M10 regressed an existing M8/M9 service CanvasLayer")
		return
	if _find_named(lab_canvas, "ComparisonLabButton") == null or _find_named(lab_canvas, "RunMatrixComparisonButton") == null:
		_fail("M10 regressed Comparison Lab hierarchy")
		return
	if _find_named(update_canvas, "UpdatesButton") == null or _find_named(update_canvas, "CheckForUpdatesButton") == null:
		_fail("M10 regressed updater hierarchy")
		return

	instance.call("_on_m10_compare_mode")
	await process_frame
	var compare_header := _find_named(m10, "M10CompareHeader") as Control
	var scenario_panel := _find_named(m10, "M10ScenarioPanel") as Control
	if compare_header == null or not compare_header.visible or (scenario_panel != null and scenario_panel.visible):
		_fail("M10 dedicated Compare workspace did not replace scenario chrome")
		return
	instance.call("_on_m10_scenario_mode")
	await process_frame
	if scenario_panel == null or not scenario_panel.visible:
		_fail("M10 could not return to Scenario workspace")
		return

	instance.call("_on_updates_button_pressed")
	await process_frame
	var update_panel := _find_named(update_canvas, "UpdatePanel") as Control
	if update_panel == null or not update_panel.visible:
		_fail("M10 Updates launch did not open the existing M9 update panel")
		return
	if update_panel.get_parent() != update_canvas:
		_fail("M10 moved the M9 update panel out of its proven hierarchy")
		return

	instance.queue_free()
	await process_frame
	print("CrashVector M10 editor runtime smoke test passed.")
	quit(0)

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
