# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var packed: Resource = load("res://app/main.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("Road-user editor smoke could not load main scene")
		quit(1)
		return
	var instance := (packed as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await process_frame
	var lab := instance.get_node_or_null("RoadUserComparisonLabUI")
	if lab == null:
		push_error("Extended editor did not create Comparison Lab UI")
		quit(1)
		return
	if _find_named(lab, "ComparisonLabButton") == null or _find_named(lab, "RunMatrixComparisonButton") == null:
		push_error("Comparison Lab controls are missing")
		quit(1)
		return

	instance.call("_on_target_palette_pressed", ScenarioConfig.TARGET_PEDESTRIAN)
	await process_frame
	await process_frame
	await process_frame
	var scenario := instance.get("scenario") as ScenarioConfig
	if scenario == null or scenario.target_type != ScenarioConfig.TARGET_PEDESTRIAN:
		push_error("Editor could not select Pedestrian target")
		quit(1)
		return
	if scenario.target_preset_id != RoadUserCatalog.PEDESTRIAN_ADULT or absf(scenario.target_mass_kg - 75.0) > 0.001:
		push_error("Pedestrian target did not apply the default adult automatically")
		quit(1)
		return
	var pedestrian_proxy := instance.get("road_user_proxy") as RoadUserRigidProxy3D
	if pedestrian_proxy == null or pedestrian_proxy.pedestrian_visual == null:
		push_error("Pedestrian rigid-body preview/presentation was not created")
		quit(1)
		return

	instance.call("_on_target_palette_pressed", ScenarioConfig.TARGET_BICYCLE)
	await process_frame
	await process_frame
	await process_frame
	scenario = instance.get("scenario") as ScenarioConfig
	if scenario == null or scenario.target_preset_id != RoadUserCatalog.BICYCLE_CITY or absf(scenario.target_mass_kg - 16.0) > 0.001:
		push_error("Bicycle target did not apply the default city bicycle automatically")
		quit(1)
		return
	var bicycle_proxy := instance.get("road_user_proxy") as RoadUserRigidProxy3D
	if bicycle_proxy == null or bicycle_proxy.bicycle_visual == null:
		push_error("Bicycle rigid-body preview/presentation was not created")
		quit(1)
		return

	instance.queue_free()
	await process_frame
	print("CrashVector road-user editor runtime smoke test passed.")
	quit(0)

func _find_named(node: Node, wanted_name: String) -> Node:
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted_name)
		if found != null:
			return found
	return null
