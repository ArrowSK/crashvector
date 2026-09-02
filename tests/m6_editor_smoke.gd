# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var packed: Resource = load("res://app/main.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("M6 editor smoke could not load main scene")
		quit(1)
		return
	var instance := (packed as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	if instance.get_node_or_null("M6ComparisonUI") == null:
		push_error("M6 editor smoke did not create comparison UI")
		quit(1)
		return
	if instance.get_node_or_null("M5AnalysisUI") == null:
		push_error("M6 editor smoke lost the M5 analysis UI")
		quit(1)
		return
	if instance.get_node_or_null("EditorUI") == null:
		push_error("M6 editor smoke lost the scenario editor UI")
		quit(1)
		return
	instance.queue_free()
	await process_frame
	print("CrashVector M6 comparison editor runtime smoke test passed.")
	quit(0)
