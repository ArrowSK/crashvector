# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var rows: Array[Dictionary] = []
var finished := false

func _initialize() -> void:
	create_timer(150.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	for id in ContactFidelityScenarioCatalog.ids():
		rows.append(await _run_case(id))
	_write_report()
	_finish()

func _run_case(id: StringName) -> Dictionary:
	var config := ContactFidelityScenarioCatalog.make_config(id)
	var metadata := ContactFidelityScenarioCatalog.metadata(id)
	var errors := config.validation_errors()
	if not errors.is_empty():
		failures.append("%s failed preflight: %s" % [String(id), "; ".join(errors)])
		return {"metadata": metadata, "error": "; ".join(errors)}

	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		failures.append("%s could not load production scene" % String(id))
		return {"metadata": metadata, "error": "production scene load failed"}
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
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
	if not completed:
		failures.append("%s did not complete in the diagnostic window" % String(id))
	for _frame in range(5):
		await process_frame

	var primary := editor.get("car") as M17CompactHatchback
	var target := editor.get("target_car") as M17CompactHatchback
	var row := {
		"metadata": metadata,
		"completed": completed,
		"error": "",
	}
	if primary == null or target == null:
		failures.append("%s did not produce the expected passenger-car pair" % String(id))
		row["error"] = "passenger-car pair unavailable"
	else:
		var primary_diagnostics := primary.rigid_chassis.contact_manifold_diagnostics()
		var target_diagnostics := target.rigid_chassis.contact_manifold_diagnostics()
		row["primary_contact"] = _serialize_diagnostics(primary_diagnostics)
		row["target_contact"] = _serialize_diagnostics(target_diagnostics)
		row["primary_front_crush_mm"] = primary.front_crush_deformation_m() * 1000.0
		row["primary_rear_crush_mm"] = primary.rear_impact_deformation_m() * 1000.0
		row["primary_side_crush_mm"] = primary.side_impact_deformation_m() * 1000.0
		row["target_front_crush_mm"] = target.front_crush_deformation_m() * 1000.0
		row["target_rear_crush_mm"] = target.rear_impact_deformation_m() * 1000.0
		row["target_side_crush_mm"] = target.side_impact_deformation_m() * 1000.0
		if completed and int(primary_diagnostics.get("maximum_contact_points", 0)) <= 0:
			failures.append("%s completed but primary reported no non-ground contact" % String(id))
		if completed and int(target_diagnostics.get("maximum_contact_points", 0)) <= 0:
			failures.append("%s completed but target reported no non-ground contact" % String(id))

	var analysis_value: Variant = editor.get("analysis_report")
	if analysis_value is Dictionary:
		var analysis: Dictionary = analysis_value
		row["analysis"] = {
			"primary_delta_v_kmh": float(analysis.get("final_delta_v_kmh", 0.0)),
			"target_delta_v_kmh": float(analysis.get("target_final_delta_v_kmh", 0.0)),
			"peak_deceleration_g": float(analysis.get("peak_deceleration_g", 0.0)),
			"primary_contact": _serialize_diagnostics(analysis.get("primary_contact_manifold", {})),
			"target_contact": _serialize_diagnostics(analysis.get("target_contact_manifold", {})),
		}

	editor.queue_free()
	await process_frame
	return row

func _serialize_diagnostics(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var diagnostics: Dictionary = value
	var span := _vector_from(diagnostics.get("maximum_span_local_m", Vector3.ZERO))
	return {
		"maximum_contact_points": int(diagnostics.get("maximum_contact_points", 0)),
		"maximum_span_local_m": [span.x, span.y, span.z],
		"peak_total_impulse_ns": float(diagnostics.get("peak_total_impulse_ns", 0.0)),
		"peak": _serialize_manifold(diagnostics.get("peak", {})),
		"scope": String(diagnostics.get("scope", "")),
	}

func _serialize_manifold(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var manifold: Dictionary = value
	var centroid := _vector_from(manifold.get("centroid_local_m", Vector3.ZERO))
	var span := _vector_from(manifold.get("span_local_m", Vector3.ZERO))
	var normal := _vector_from(manifold.get("normal_local", Vector3.ZERO))
	return {
		"contact_count": int(manifold.get("contact_count", 0)),
		"total_impulse_ns": float(manifold.get("total_impulse_ns", 0.0)),
		"centroid_local_m": [centroid.x, centroid.y, centroid.z],
		"span_local_m": [span.x, span.y, span.z],
		"normal_local": [normal.x, normal.y, normal.z],
		"projected_span_xz_m2": float(manifold.get("projected_span_xz_m2", 0.0)),
		"collider_names": manifold.get("collider_names", []),
	}

func _vector_from(value: Variant) -> Vector3:
	return value as Vector3 if value is Vector3 else Vector3.ZERO

func _write_report() -> void:
	var output_dir := "res://build/m19_contact_fidelity"
	var absolute_dir := ProjectSettings.globalize_path(output_dir)
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK:
		failures.append("Could not create M19 diagnostic output directory: %s" % error_string(error))
		return
	var path := "%s/contact_matrix.json" % output_dir
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write %s" % path)
		return
	file.store_string(JSON.stringify({
		"scope": "production_contact_observation_only",
		"external_protocol_replica": false,
		"cases": rows,
	}, "  "))
	file.close()
	print("M19 contact diagnostic matrix written to %s" % path)

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M19 contact diagnostic matrix exceeded 150 seconds")
	quit(1)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M19 contact diagnostic matrix completed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
