# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var packed: Resource = load("res://app/main.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("M9 editor smoke could not load main scene")
		quit(1)
		return
	var instance := (packed as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var update_ui := instance.get_node_or_null("M9UpdateUI")
	if update_ui == null:
		push_error("M9 editor smoke did not create update UI")
		quit(1)
		return
	if _find_named(update_ui, "UpdatesButton") == null:
		push_error("M9 editor smoke did not create Updates button")
		quit(1)
		return
	if _find_named(update_ui, "CheckForUpdatesButton") == null:
		push_error("M9 editor smoke did not create manual update check")
		quit(1)
		return
	if _find_named(update_ui, "AutomaticUpdateCheck") == null:
		push_error("M9 editor smoke did not create automatic-update setting")
		quit(1)
		return
	if instance.get_node_or_null("M9UpdateService") == null:
		push_error("M9 editor smoke did not create update service")
		quit(1)
		return
	# Ensure the M9 layer did not replace the already-working M8/extended UI.
	if instance.get_node_or_null("M8CalibrationUI") == null:
		push_error("M9 editor smoke regressed M8 calibration UI")
		quit(1)
		return
	if instance.get_node_or_null("M6ComparisonUI") == null:
		push_error("M9 editor smoke regressed comparison UI")
		quit(1)
		return
	instance.queue_free()
	await process_frame
	print("CrashVector M9 complete editor runtime smoke test passed.")
	quit(0)

func _find_named(node: Node, wanted_name: String) -> Node:
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted_name)
		if found != null:
			return found
	return null
