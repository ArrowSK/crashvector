# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished := false

func _initialize() -> void:
	create_timer(95.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M21 production scene must load")
	if packed == null:
		_finish()
		return

	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M21 articulated truck rear-quarter broadside regression"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 60.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 0.0
	# Local truck +X maps approximately across world +Z at -90 degrees. Placing
	# the origin at z=-1.5 brings a rear-quarter trailer section onto the primary
	# lane, creating an articulation moment rather than a perfectly centred hit.
	config.target_position_m = Vector3(3.0, 0.0, -1.5)
	config.duration_s = 2.4
	config.solver_substeps = 12
	_expect(config.validation_errors().is_empty(), "M21 articulation scenario failed preflight: %s" % "; ".join(config.validation_errors()))
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame

	var preview_truck := editor.get("truck") as M21HeavyTruck
	_expect(preview_truck != null, "M21 production routing did not instantiate M21HeavyTruck")
	if preview_truck != null:
		_expect(preview_truck.rigid_chassis != null and preview_truck.tractor_chassis != null, "M21 truck does not expose separate trailer and tractor rigid bodies")
		_expect(preview_truck.fifth_wheel_joint != null, "M21 truck has no fifth-wheel joint")
		var represented_mass := preview_truck.rigid_chassis.mass + preview_truck.tractor_chassis.mass
		_expect(absf(represented_mass - config.target_mass_kg) < 1.0, "M21 articulated body masses do not preserve target mass: %.1f vs %.1f kg" % [represented_mass, config.target_mass_kg])
		_expect(preview_truck.fifth_wheel_separation_m() < 0.01, "M21 fifth-wheel anchors are separated before simulation")

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1500):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M21 articulated-truck production run did not complete")
	for _frame in range(5):
		await process_frame

	var truck := editor.get("truck") as M21HeavyTruck
	_expect(truck != null, "M21 articulated truck disappeared during production run")
	if truck != null:
		var combined_contacts := truck.rigid_chassis.non_ground_contact_events + truck.tractor_chassis.non_ground_contact_events
		_expect(combined_contacts > 0, "M21 articulated truck received no real non-ground Godot contact")
		_expect(truck.maximum_articulation_yaw_deg > 0.05, "M21 rear-quarter hit produced no measurable tractor/trailer articulation")
		_expect(truck.maximum_articulation_yaw_deg <= M21HeavyTruck.MAX_FIFTH_WHEEL_YAW_DEG + 2.0, "M21 fifth-wheel yaw exceeded its configured generic envelope: %.2f deg" % truck.maximum_articulation_yaw_deg)
		_expect(truck.fifth_wheel_separation_m() < 0.18, "M21 fifth-wheel linear constraint separated by %.3f m" % truck.fifth_wheel_separation_m())
		_expect(_finite_vector(truck.rigid_chassis.global_position) and _finite_vector(truck.tractor_chassis.global_position), "M21 articulated body position became non-finite")
		_expect(truck.rigid_chassis.maximum_vertical_speed_ms < 20.0 and truck.tractor_chassis.maximum_vertical_speed_ms < 20.0, "M21 articulated truck produced an implausible vertical launch")
		var diagnostics := truck.combined_contact_manifold_diagnostics()
		_expect(String(diagnostics.get("scope", "")) == "diagnostic_only_no_solver_feedback_articulated_pair", "M21 combined contact diagnostics lost their explicit scope")
		_expect(int(diagnostics.get("maximum_contact_points", 0)) > 0, "M21 combined contact diagnostics reported no target contact")
		var skin := editor.get("m162_truck_skin") as M21HeavyTruckVisual
		_expect(skin != null and skin.tractor_presentation_root != null, "M21 production presentation does not expose a separate articulated tractor root")

	var recorder := editor.get("replay_recorder") as ReplayRecorder
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "M21 articulated-truck case produced no replay")
	if recorder != null and recorder.recording != null:
		var last_context_value: Variant = recorder.recording.last_frame().get("context", {})
		_expect(last_context_value is Dictionary, "M21 replay final frame lost context")
		if last_context_value is Dictionary:
			var last_context: Dictionary = last_context_value
			_expect(last_context.has("target_articulation_yaw_deg"), "M21 replay context does not preserve articulation diagnostics")
			var target_contact_value: Variant = last_context.get("target_contact_manifold", {})
			_expect(target_contact_value is Dictionary and String((target_contact_value as Dictionary).get("scope", "")) == "diagnostic_only_no_solver_feedback_articulated_pair", "M21 replay context did not preserve combined articulated contact diagnostics")

	editor.queue_free()
	await process_frame
	_finish()

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M21 articulated-truck regression exceeded 95 seconds")
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M21 articulated heavy-truck regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
