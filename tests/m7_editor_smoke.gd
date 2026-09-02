# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	var packed: Resource = load("res://app/main.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("M7 editor smoke could not load main scene")
		quit(1)
		return
	var instance := (packed as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	if instance.get_node_or_null("M7ExportUI") == null:
		push_error("M7 editor smoke did not create cinematic export UI")
		quit(1)
		return
	if instance.get_node_or_null("CinematicExporter") == null:
		push_error("M7 editor smoke did not create cinematic exporter")
		quit(1)
		return
	var button := instance.get_node_or_null("M7ExportUI/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/CinematicVideoButton")
	if button == null:
		# The exact generated container names are not API; locate by recursive owner traversal instead.
		button = _find_named(instance.get_node("M7ExportUI"), "CinematicVideoButton")
	if button == null:
		push_error("M7 editor smoke did not create cinematic video button")
		quit(1)
		return
	instance.queue_free()
	await process_frame
	print("CrashVector M7 editor runtime smoke test passed.")
	quit(0)

func _find_named(node: Node, wanted_name: String) -> Node:
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted_name)
		if found != null:
			return found
	return null
