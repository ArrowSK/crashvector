# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished: bool = false

func _initialize() -> void:
	# A runtime error in a SceneTree test can abort the coroutine without
	# terminating Godot, which would leave CI hanging indefinitely. Keep this
	# gate bounded so any such regression becomes an actionable failure.
	create_timer(20.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://app/main.tscn") as PackedScene
	_expect(scene != null, "M12 production scene must load")
	if scene == null:
		_finish()
		return
	var editor := scene.instantiate()
	root.add_child(editor)
	await process_frame
	await physics_frame
	_expect(bool(editor.hybrid_production_active), "Default rigid-wall scenario must activate M12 hybrid production physics")
	_expect(editor.pair_simulation == null, "Default M12 production path must not retain legacy pair simulation")
	_expect(editor.static_simulation == null, "Default M12 production path must not retain legacy static simulation")
	_expect(editor.car != null and editor.car.rigid_chassis is RigidBody3D, "Primary passenger car must own a Godot rigid chassis")
	if editor.car != null and editor.car.rigid_chassis != null:
		_expect(editor.car.rigid_chassis.continuous_cd, "M12 production passenger car must enable continuous collision detection")
		_expect(editor.car.rigid_chassis.suspension_points.size() == 4, "M12 passenger car must have four suspension contacts")

	# An unported target may remain editable, but pressing Simulate must not fall
	# back to the old world-motion solver.
	editor.scenario.apply_target_defaults(ScenarioConfig.TARGET_LORRY)
	editor._rebuild_preview()
	await process_frame
	_expect(not bool(editor.hybrid_production_active), "Unported rigid-lorry target must be marked non-hybrid")
	editor._on_simulate_pressed()
	_expect(not bool(editor.simulation_running), "Unported target must be blocked instead of using legacy production physics")

	# M6/M8 batch comparison still uses ComparisonRunner's historical reduced-
	# order solver. M12 must refuse that production path until it is ported.
	editor.comparison_results.clear()
	editor.comparison_results.append({"sentinel": true})
	editor._on_run_comparison_pressed()
	_expect(editor.comparison_results.is_empty(), "M12 Compare must not execute/retain legacy comparison results")
	editor.comparison_results.append({"sentinel": true})
	editor._on_run_matrix_comparison()
	_expect(editor.comparison_results.is_empty(), "M12 Comparison Lab must not execute/retain legacy matrix results")

	editor.queue_free()
	await process_frame
	_finish()

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M12 production-path test exceeded 20 seconds; a runtime error or non-terminating production route prevented clean completion.")
	quit(1)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M12 production-path tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
