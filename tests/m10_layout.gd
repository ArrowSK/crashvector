# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const SIZES := [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("M10 layout test could not load main scene")
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await process_frame

	for size in SIZES:
		root.size = size
		# Headless Godot applies SceneTree root-size changes on the next frame.
		# Wait for that propagation before asking the M10 shell to lay itself out.
		await process_frame
		instance.call("_layout_m10")
		await process_frame
		if not _validate_scenario_layout(instance, size):
			return

	root.size = Vector2i(1280, 720)
	await process_frame
	instance.call("_toggle_replay_drawer")
	instance.call("_layout_m10")
	await process_frame
	var viewport := _find_named(instance, "M10ViewportFrame") as Control
	var replay := _find_named(instance, "M10ReplayDrawer") as Control
	if viewport == null or replay == null or replay.size.y < 200.0 or viewport.position.y + viewport.size.y > replay.position.y + 0.5:
		_fail("Expanded M10 analysis drawer overlaps the viewport")
		return
	instance.call("_toggle_replay_drawer")

	instance.call("_on_m10_compare_mode")
	instance.call("_layout_m10")
	await process_frame
	var left := _find_named(instance, "M10ScenarioPanel") as Control
	var right := _find_named(instance, "M10Inspector") as Control
	var compare_header := _find_named(instance, "M10CompareHeader") as Control
	viewport = _find_named(instance, "M10ViewportFrame") as Control
	if left == null or right == null or compare_header == null or viewport == null:
		_fail("M10 comparison layout controls are missing")
		return
	if left.visible or right.visible or not compare_header.visible:
		_fail("M10 Compare workspace kept scenario sidebars visible")
		return
	if viewport.size.x < 1200.0:
		_fail("M10 Compare workspace did not give the 3D scene the full desktop width")
		return

	instance.queue_free()
	await process_frame
	print("CrashVector M10 responsive-layout regression test passed.")
	quit(0)

func _validate_scenario_layout(instance: Node, size: Vector2i) -> bool:
	instance.call("_on_m10_scenario_mode")
	instance.call("_layout_m10")
	var top := _find_named(instance, "M10TopBar") as Control
	var left := _find_named(instance, "M10ScenarioPanel") as Control
	var right := _find_named(instance, "M10Inspector") as Control
	var viewport := _find_named(instance, "M10ViewportFrame") as Control
	var replay := _find_named(instance, "M10ReplayDrawer") as Control
	if top == null or left == null or right == null or viewport == null or replay == null:
		_fail("M10 responsive layout is missing a major region at %s" % size)
		return false
	for control in [top, left, right, viewport, replay]:
		if control.size.x <= 0.0 or control.size.y <= 0.0:
			_fail("M10 produced an empty layout region at %s" % size)
			return false
		if control.position.x < -0.5 or control.position.y < -0.5 or control.position.x + control.size.x > float(size.x) + 0.5 or control.position.y + control.size.y > float(size.y) + 0.5:
			_fail("M10 control escaped the window bounds at %s" % size)
			return false
	if not left.visible or not right.visible:
		_fail("M10 unexpectedly collapsed desktop sidebars at %s" % size)
		return false
	if _overlaps(left, viewport) or _overlaps(viewport, right) or _overlaps(left, right):
		_fail("M10 sidebars overlap the 3D viewport at %s" % size)
		return false
	if _overlaps(top, left) or _overlaps(top, viewport) or _overlaps(top, right):
		_fail("M10 top toolbar overlaps editor content at %s" % size)
		return false
	if viewport.position.y + viewport.size.y > replay.position.y + 0.5:
		_fail("M10 replay bar overlaps the 3D viewport at %s" % size)
		return false
	if viewport.size.x < 560.0 or viewport.size.y < 420.0:
		_fail("M10 viewport is too small at supported desktop size %s" % size)
		return false
	return true

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
