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
	var modal := _find_named(instance, "CinematicExportModal") as Control
	var dialog := _find_named(instance, "CinematicExportDialog") as Control
	if modal == null or dialog == null:
		push_error("M7 editor smoke did not create a root-level cinematic export modal")
		quit(1)
		return
	var export_canvas := instance.get_node_or_null("M7ExportUI") as CanvasLayer
	var desktop_canvas := instance.get_node_or_null("M10UI") as CanvasLayer
	if export_canvas == null or desktop_canvas == null or export_canvas.layer <= desktop_canvas.layer or modal.z_index < 100:
		push_error("M7 export modal is not above the desktop shell")
		quit(1)
		return
	if modal.anchor_left != 0.0 or modal.anchor_top != 0.0 or modal.anchor_right != 1.0 or modal.anchor_bottom != 1.0:
		push_error("M7 export modal no longer covers the full window")
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
