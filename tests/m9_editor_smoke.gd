# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var packed: Resource = load("res://app/main.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("M9 editor smoke could not load the main scene")
		quit(1)
		return
	var instance := (packed as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await process_frame

	var lifecycle := instance.get_node_or_null("M9LifecycleUI")
	if lifecycle == null:
		push_error("M9 lifecycle UI was not created")
		quit(1)
		return
	var updates_button := _find_named(lifecycle, "UpdatesButton")
	var update_panel := _find_named(lifecycle, "UpdatePanel")
	var version_label := _find_named(lifecycle, "CurrentVersionLabel")
	if updates_button == null or update_panel == null or version_label == null:
		push_error("M9 update controls are incomplete")
		quit(1)
		return
	if update_panel.visible:
		push_error("M9 update panel should not cover the editor on startup")
		quit(1)
		return
	if not String(version_label.get("text")).contains(AppMetadata.VERSION):
		push_error("M9 update panel does not show the installed version")
		quit(1)
		return
	if instance.get_node_or_null("UpdateService") == null:
		push_error("M9 update service was not created")
		quit(1)
		return

	instance.queue_free()
	await process_frame
	print("CrashVector M9 editor runtime smoke test passed.")
	quit(0)

func _find_named(node: Node, wanted_name: String) -> Node:
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted_name)
		if found != null:
			return found
	return null
