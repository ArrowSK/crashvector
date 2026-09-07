# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished := false

func _initialize() -> void:
	create_timer(75.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	_check_contact_manifold_helper()
	_check_validation_reference_catalog()
	await _check_production_replay_diagnostics()
	_finish()

func _check_contact_manifold_helper() -> void:
	var samples: Array[Dictionary] = [
		{
			"collider_name": &"Road",
			"position_local": Vector3.ZERO,
			"impulse": Vector3(999.0, 0.0, 0.0),
			"normal": Vector3.UP,
		},
		{
			"collider_name": &"OtherVehicle",
			"position_local": Vector3(1.0, 0.2, -0.5),
			"impulse": Vector3(100.0, 0.0, 0.0),
			"normal": Vector3(-1.0, 0.0, 0.0),
		},
		{
			"collider_name": &"OtherVehicle",
			"position_local": Vector3(0.5, 0.4, 0.5),
			"impulse": Vector3(200.0, 0.0, 0.0),
			"normal": Vector3(-1.0, 0.0, 0.0),
		},
	]
	var summary := ContactManifoldMetrics.summarize(samples)
	_expect(int(summary.get("contact_count", 0)) == 2, "M19 manifold helper must exclude road contacts")
	_expect(absf(float(summary.get("total_impulse_ns", 0.0)) - 300.0) < 0.001, "M19 manifold helper impulse total is incorrect")
	var span_value: Variant = summary.get("span_local_m", Vector3.ZERO)
	var span := span_value as Vector3 if span_value is Vector3 else Vector3.ZERO
	_expect(absf(span.x - 0.5) < 0.001 and absf(span.z - 1.0) < 0.001, "M19 manifold helper span is incorrect: %s" % span)
	_expect(absf(float(summary.get("projected_span_xz_m2", 0.0)) - 0.5) < 0.001, "M19 manifold projected diagnostic spread is incorrect")

func _check_validation_reference_catalog() -> void:
	var references := ValidationReferenceCatalog.load_all()
	_expect(references.size() == 4, "M19 validation catalog must load four stored public references")
	var source_refs := ValidationReferenceCatalog.source_correlation_references()
	var geometry_refs := ValidationReferenceCatalog.protocol_geometry_references()
	_expect(source_refs.size() == 1, "M19 must keep the historical NHTSA correlation reference distinct")
	_expect(geometry_refs.size() == 3, "M19 must expose three protocol-geometry-only references")
	for reference in references:
		_expect(not ValidationReferenceCatalog.production_runnable(reference), "M19 reference %s must not claim production validation" % reference.id())
	for reference in geometry_refs:
		_expect(reference.source_corridors().is_empty(), "Protocol-only reference %s must not invent source outcome corridors" % reference.id())

func _check_production_replay_diagnostics() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M19 production scene must load")
	if packed == null:
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M19 contact-manifold production regression"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3.ZERO
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 0.0
	config.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	config.target_car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.target_mass_kg = PassengerCarCatalog.default_mass_kg(config.target_car_preset_id)
	config.target_position_m = Vector3(0.0, 0.0, -8.0)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 55.0
	config.duration_s = 1.7
	config.solver_substeps = 12
	_expect(config.validation_errors().is_empty(), "M19 production diagnostic scenario failed preflight")
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1100):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M19 production diagnostic scenario did not complete")
	for _frame in range(6):
		await process_frame

	var car := editor.get("car") as M17CompactHatchback
	var target := editor.get("target_car") as M17CompactHatchback
	_expect(car != null and target != null, "M19 regression requires the current production passenger-car pair")
	if car != null:
		var diagnostics := car.rigid_chassis.contact_manifold_diagnostics()
		_expect(String(diagnostics.get("scope", "")) == "diagnostic_only_no_solver_feedback", "M19 chassis diagnostic scope marker is missing")
		_expect(int(diagnostics.get("maximum_contact_points", 0)) > 0, "M19 primary chassis reported no non-ground contact manifold")
		_expect(float(diagnostics.get("peak_total_impulse_ns", 0.0)) > 0.0, "M19 primary chassis reported no contact impulse")
		var span_value: Variant = diagnostics.get("maximum_span_local_m", Vector3.ZERO)
		var span := span_value as Vector3 if span_value is Vector3 else Vector3.ZERO
		_expect(_finite_vector(span) and span.x >= 0.0 and span.z >= 0.0, "M19 primary manifold spread is non-finite")

	var recorder: ReplayRecorder = editor.get("replay_recorder")
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "M19 production run produced no replay")
	var replay_has_diagnostics := false
	if recorder != null and recorder.recording != null:
		for frame in recorder.recording.frames:
			var context_value: Variant = frame.get("context", {})
			if not context_value is Dictionary:
				continue
			var context: Dictionary = context_value
			var diagnostic_value: Variant = context.get("primary_contact_manifold", {})
			if diagnostic_value is Dictionary and int((diagnostic_value as Dictionary).get("maximum_contact_points", 0)) > 0:
				replay_has_diagnostics = true
				break
	_expect(replay_has_diagnostics, "M19 replay frames do not preserve primary contact-manifold diagnostics")

	var report_value: Variant = editor.get("analysis_report")
	_expect(report_value is Dictionary, "M19 production analysis report is unavailable")
	if report_value is Dictionary:
		var report: Dictionary = report_value
		var summary_value: Variant = report.get("primary_contact_manifold", {})
		_expect(summary_value is Dictionary, "M19 analysis report does not expose primary contact-manifold summary")
		if summary_value is Dictionary:
			var analysis_summary: Dictionary = summary_value
			_expect(int(analysis_summary.get("maximum_contact_points", 0)) > 0, "M19 analysis lost contact-point count")
			_expect(float(analysis_summary.get("peak_total_impulse_ns", 0.0)) > 0.0, "M19 analysis lost peak contact impulse")

	editor.queue_free()
	await process_frame

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M19 contact-fidelity regression exceeded 75 seconds")
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M19 contact-fidelity and external-reference regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
