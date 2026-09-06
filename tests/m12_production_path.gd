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

	# M17 is allowed to extend the M12 production world with targets that were
	# intentionally blocked in the original M12 beta. The invariant this gate
	# preserves is that a newly supported target must use Godot world motion and
	# must never fall back to the historical reduced-order pair/static solvers.
	editor.scenario.apply_target_defaults(ScenarioConfig.TARGET_LORRY)
	editor._rebuild_preview()
	await process_frame
	await physics_frame
	_expect(bool(editor.hybrid_production_active), "Current production rigid-lorry target must use hybrid world physics")
	_expect(editor.pair_simulation == null and editor.static_simulation == null, "Rigid-lorry port must not re-enable a legacy production solver")
	var lorry: Variant = editor.get("m17_lorry")
	_expect(lorry is M17RigidLorry, "Current production rigid-lorry target must use the M17 RigidBody3D wrapper")
	if lorry is M17RigidLorry:
		_expect((lorry as M17RigidLorry).rigid_chassis is RigidBody3D, "M17 rigid lorry must own a Godot rigid chassis")

	# M12 originally disabled Compare because M6/M8 ComparisonRunner used the old
	# reduced-order solver. A descendant may re-enable Compare only through the
	# isolated current-production SceneTree route. Do not execute the relatively
	# expensive comparison here; the M17 gate owns that end-to-end regression.
	_expect(editor.has_method("_m17_run_production_comparison"), "Current production Compare must be provided by the M17 rigid-body comparison route")
	_expect(editor.has_method("_m17_create_comparison_context"), "M17 Compare must create isolated production physics worlds")

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
		print("CrashVector M12 production-path compatibility tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
