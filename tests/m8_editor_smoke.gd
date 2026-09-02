# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var packed: Resource = load("res://app/main.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("M8 editor smoke could not load main scene")
		quit(1)
		return
	var instance := (packed as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	if instance.get_node_or_null("M8CalibrationUI") == null:
		push_error("M8 editor smoke did not create calibration UI")
		quit(1)
		return
	if _find_named(instance.get_node("M8CalibrationUI"), "CalibrationButton") == null:
		push_error("M8 editor smoke did not create calibration button")
		quit(1)
		return
	var comparison_ui := instance.get_node_or_null("M6ComparisonUI")
	if comparison_ui == null or _find_named(comparison_ui, "CustomSpeedPanel") == null:
		push_error("M8 editor smoke did not create custom speed-comparison controls")
		quit(1)
		return
	if not ScenarioConfig.target_ids().has(ScenarioConfig.TARGET_WALL):
		push_error("M8 editor lost rigid-wall crash target")
		quit(1)
		return
	if not ScenarioConfig.target_ids().has(ScenarioConfig.TARGET_LORRY):
		push_error("M8 editor did not expose rigid lorry target")
		quit(1)
		return
	if not ScenarioConfig.target_ids().has(ScenarioConfig.TARGET_MOTORCYCLE):
		push_error("M8 editor did not expose riderless motorcycle target")
		quit(1)
		return
	instance.queue_free()
	await process_frame
	print("CrashVector M8 editor runtime smoke test passed.")
	quit(0)

func _find_named(node: Node, wanted_name: String) -> Node:
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted_name)
		if found != null:
			return found
	return null
