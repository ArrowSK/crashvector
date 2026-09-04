# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished: bool = false

func _initialize() -> void:
	create_timer(25.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M14 production scene must load")
	if packed == null:
		_finish()
		return
	var editor := packed.instantiate()
	root.add_child(editor)
	await process_frame
	await physics_frame

	# Regression for the M10 evidence-scope chip used by labels such as
	# "Extrapolated". The inherited M8 modal must sit above the full-screen M10
	# canvas, remain interactive, and closing it must leave the normal editor UI
	# visible. Previously the panel rendered under M10 and its Close button could
	# not receive input.
	_expect(editor.m10_root != null and editor.m10_root.visible, "Production UI must be visible before opening evidence scope")
	_expect(editor.m10_scope_chip != null, "Production UI must expose the evidence-scope chip")
	if editor.m10_scope_chip != null:
		editor.m10_scope_chip.emit_signal("pressed")
		await process_frame
		_expect(editor.calibration_panel != null and editor.calibration_panel.visible, "Evidence-scope chip must open calibration/evidence modal")
		_expect(editor.calibration_canvas != null and editor.m10_canvas != null and editor.calibration_canvas.layer > editor.m10_canvas.layer, "Calibration modal must render and receive input above M10 UI")
		_expect(editor.m10_root.visible, "Opening evidence scope must not remove the normal editor UI")
		var close_button := _find_button_by_text(editor.calibration_panel, "Close")
		_expect(close_button != null, "Calibration/evidence modal must expose its Close button")
		if close_button != null:
			close_button.emit_signal("pressed")
			await process_frame
			_expect(not editor.calibration_panel.visible, "Calibration/evidence Close button must dismiss the modal")
			_expect(editor.m10_root.visible, "Closing evidence scope must restore/retain the normal editor UI")

	# Pedestrian is no longer an unported/blocked target. The production scene
	# must replace the historical direct structural object with a rigid proxy.
	editor.scenario.apply_target_defaults(ScenarioConfig.TARGET_PEDESTRIAN)
	editor._rebuild_preview()
	await process_frame
	await physics_frame
	_expect(bool(editor.hybrid_production_active), "M14 pedestrian target must activate hybrid production physics")
	_expect(editor.pair_simulation == null and editor.static_simulation == null, "M14 pedestrian must not retain a legacy world-motion simulator")
	_expect(editor.road_user_proxy is RoadUserRigidProxy3D, "M14 pedestrian must use RoadUserRigidProxy3D")
	if editor.road_user_proxy != null:
		_expect(editor.road_user_proxy is RigidBody3D, "M14 pedestrian target must be a Godot RigidBody3D")
		_expect(editor.road_user_proxy.pedestrian_visual != null, "M14 pedestrian rigid proxy must retain pedestrian presentation")

	# Riderless bicycle follows the same rigid-body production path.
	editor.scenario.apply_target_defaults(ScenarioConfig.TARGET_BICYCLE)
	editor._rebuild_preview()
	await process_frame
	await physics_frame
	_expect(bool(editor.hybrid_production_active), "M14 bicycle target must activate hybrid production physics")
	_expect(editor.pair_simulation == null and editor.static_simulation == null, "M14 bicycle must not retain a legacy world-motion simulator")
	_expect(editor.road_user_proxy is RoadUserRigidProxy3D, "M14 bicycle must use RoadUserRigidProxy3D")
	if editor.road_user_proxy != null:
		_expect(editor.road_user_proxy.bicycle_visual != null, "M14 bicycle rigid proxy must retain riderless bicycle presentation")

	# Pole/tree are now yielding rigid targets, initially frozen like fixtures and
	# released only after collision demand crosses the target's generic capacity.
	for target_type in [ScenarioConfig.TARGET_POLE, ScenarioConfig.TARGET_TREE]:
		editor.scenario.apply_target_defaults(target_type)
		editor._rebuild_preview()
		await process_frame
		await physics_frame
		_expect(bool(editor.hybrid_production_active), "%s must remain on hybrid production physics" % ScenarioConfig.target_display_name(target_type))
		_expect(editor.obstacle != null, "%s preview must create StaticObstacle3D wrapper" % ScenarioConfig.target_display_name(target_type))
		if editor.obstacle != null:
			_expect(editor.obstacle.yield_body is RigidBody3D, "%s must own a yielding RigidBody3D" % ScenarioConfig.target_display_name(target_type))
			if editor.obstacle.yield_body != null:
				_expect(editor.obstacle.yield_body.freeze, "%s must begin anchored/frozen before impact" % ScenarioConfig.target_display_name(target_type))

	# M14 must not accidentally re-enable another unported target while adding
	# road users. Rigid lorry remains explicitly blocked pending its own port.
	editor.scenario.apply_target_defaults(ScenarioConfig.TARGET_LORRY)
	editor._rebuild_preview()
	await process_frame
	_expect(not bool(editor.hybrid_production_active), "Rigid lorry must remain blocked until separately ported")
	editor._on_simulate_pressed()
	_expect(not bool(editor.simulation_running), "Blocked rigid-lorry target must not fall back to legacy production physics")

	editor.queue_free()
	await process_frame
	_finish()

func _find_button_by_text(node: Node, wanted_text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == wanted_text:
		return node as Button
	for child in node.get_children():
		var found := _find_button_by_text(child, wanted_text)
		if found != null:
			return found
	return null

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M14 production-path test exceeded 25 seconds; a routing/runtime error prevented clean completion.")
	quit(1)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M14 production-path tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
