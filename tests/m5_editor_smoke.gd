# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var packed: Resource = load("res://app/main.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("M5 editor smoke could not load main scene")
		quit(1)
		return
	var instance := (packed as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	if instance.get_node_or_null("M5AnalysisUI") == null:
		push_error("M5 editor smoke did not create analysis UI")
		quit(1)
		return
	if instance.get_node_or_null("AnalysisOverlay3D") == null:
		push_error("M5 editor smoke did not create analysis overlay")
		quit(1)
		return
	instance.queue_free()
	await process_frame
	print("CrashVector M5 editor runtime smoke test passed.")
	quit(0)
