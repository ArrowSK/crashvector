# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished := false

func _initialize() -> void:
	create_timer(80.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M20 replay-presentation production scene must load")
	if packed == null:
		_finish()
		return

	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M20 replay-safe broadside truck presentation"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 60.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 0.0
	config.target_position_m = Vector3(3.0, 0.0, -4.75)
	config.duration_s = 2.0
	config.solver_substeps = 12
	_expect(config.validation_errors().is_empty(), "M20 replay-presentation case failed preflight")
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1300):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M20 replay-presentation production run did not complete")
	for _frame in range(5):
		await process_frame

	var truck := editor.get("truck") as M20HeavyTruck
	var skin := editor.get("m162_truck_skin") as M20HeavyTruckVisual
	_expect(truck != null, "M20 replay-presentation case did not instantiate M20HeavyTruck")
	_expect(skin != null, "M20 production routing did not install M20HeavyTruckVisual")
	var recorder := editor.get("replay_recorder") as ReplayRecorder
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "M20 replay-presentation case produced no replay")

	if truck != null and skin != null and recorder != null and recorder.recording != null:
		_expect(truck.side_impact_deformation_m() > 0.005, "M20 replay-presentation case produced no side deformation")
		await process_frame
		var final_width := _trailer_width(skin)
		_expect(final_width > 0.0 and final_width < 2.419, "M20 final truck presentation did not visibly follow side deformation: %.3f m" % final_width)

		# The live scalar crush accumulator remains at the completed-run maximum.
		# Rewinding must nevertheless restore the pristine visual width because
		# M20HeavyTruckVisual derives lateral presentation from replayed structural
		# nodes rather than those monotonic live scalars.
		editor.call("_apply_replay_time", 0.0, true)
		for _frame in range(3):
			await process_frame
		var start_width := _trailer_width(skin)
		_expect(absf(start_width - 2.42) < 0.06, "M20 replay start inherited final side crush instead of pristine structure: %.3f m" % start_width)
		_expect(start_width > final_width + 0.003, "M20 replay rewind did not expand the truck presentation back from final crush")

		editor.call("_apply_replay_time", recorder.recording.duration_s, true)
		for _frame in range(3):
			await process_frame
		var replay_final_width := _trailer_width(skin)
		_expect(absf(replay_final_width - final_width) < 0.04, "M20 replay final frame did not reproduce the completed truck presentation")

	editor.queue_free()
	await process_frame
	_finish()

func _trailer_width(skin: M20HeavyTruckVisual) -> float:
	if skin == null or skin.trailer_instance == null:
		return 0.0
	var mesh := skin.trailer_instance.mesh as BoxMesh
	return 0.0 if mesh == null else mesh.size.z

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M20 replay-presentation regression exceeded 80 seconds")
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M20 replay-safe heavy-truck presentation regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
