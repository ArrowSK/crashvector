# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CrashAnalysis
extends RefCounted

const STANDARD_GRAVITY_MS2: float = 9.80665

static func analyze(recording: ReplayRecording) -> Dictionary:
	if recording == null or recording.frames.size() < 2:
		return {}
	var first := recording.first_frame()
	var last := recording.last_frame()
	var first_primary := _metrics(first, "primary_metrics")
	var last_primary := _metrics(last, "primary_metrics")
	var initial_velocity: Vector3 = first_primary.get("linear_velocity_ms", Vector3.ZERO)
	var final_velocity: Vector3 = last_primary.get("linear_velocity_ms", Vector3.ZERO)
	var initial_direction := initial_velocity.normalized()
	if initial_direction.is_zero_approx():
		initial_direction = Vector3.RIGHT

	var crash_pulse: Array[Vector2] = []
	var front_crush: Array[Vector2] = []
	var safety_cell: Array[Vector2] = []
	var peak_deceleration_g: float = 0.0
	var peak_deceleration_time_s: float = 0.0
	var max_delta_v_ms: float = 0.0
	var max_front_crush_m: float = 0.0
	var max_safety_cell_m: float = 0.0
	var max_broken_beams: int = 0
	var first_contact_time_s: float = -1.0
	var first_failure_time_s: float = -1.0
	var last_contact_increment_time_s: float = -1.0
	var previous_contact_count: int = 0
	var rest_time_s: float = -1.0

	for i in range(recording.frames.size()):
		var frame := recording.frames[i]
		var time_s := float(frame.get("time_s", 0.0))
		var primary := _metrics(frame, "primary_metrics")
		var velocity: Vector3 = primary.get("linear_velocity_ms", Vector3.ZERO)
		var delta_v_ms := (velocity - initial_velocity).length()
		max_delta_v_ms = maxf(max_delta_v_ms, delta_v_ms)
		var front_m := float(primary.get("front_crush_m", 0.0))
		var safety_m := float(primary.get("safety_cell_m", 0.0))
		max_front_crush_m = maxf(max_front_crush_m, front_m)
		max_safety_cell_m = maxf(max_safety_cell_m, safety_m)
		front_crush.append(Vector2(time_s, front_m * 1000.0))
		safety_cell.append(Vector2(time_s, safety_m * 1000.0))

		var broken_count := int(primary.get("broken_beams", 0))
		var target := _metrics(frame, "target_metrics")
		broken_count += int(target.get("broken_beams", 0))
		max_broken_beams = maxi(max_broken_beams, broken_count)
		if broken_count > 0 and first_failure_time_s < 0.0:
			first_failure_time_s = time_s

		var context := _metrics(frame, "context")
		var contact_count := int(context.get("contact_count", 0))
		if contact_count > 0 and first_contact_time_s < 0.0:
			first_contact_time_s = time_s
		if contact_count > previous_contact_count:
			last_contact_increment_time_s = time_s
		previous_contact_count = contact_count

		if i > 0:
			var previous := recording.frames[i - 1]
			var previous_primary := _metrics(previous, "primary_metrics")
			var previous_velocity: Vector3 = previous_primary.get("linear_velocity_ms", Vector3.ZERO)
			var previous_time_s := float(previous.get("time_s", time_s))
			var dt := time_s - previous_time_s
			if dt > 0.000001:
				var acceleration := (velocity - previous_velocity) / dt
				var longitudinal_deceleration_g := maxf(-acceleration.dot(initial_direction) / STANDARD_GRAVITY_MS2, 0.0)
				crash_pulse.append(Vector2(time_s, longitudinal_deceleration_g))
				if first_contact_time_s >= 0.0 and longitudinal_deceleration_g > peak_deceleration_g:
					peak_deceleration_g = longitudinal_deceleration_g
					peak_deceleration_time_s = time_s

		if first_contact_time_s >= 0.0 and rest_time_s < 0.0:
			var primary_speed := float(primary.get("speed_kmh", 0.0))
			var target_speed := float(target.get("speed_kmh", 0.0)) if not target.is_empty() else 0.0
			if primary_speed < 1.0 and target_speed < 1.0:
				rest_time_s = time_s

	var markers: Array[Dictionary] = []
	if first_contact_time_s >= 0.0:
		markers.append(_marker(&"first_contact", "First contact", first_contact_time_s))
	if peak_deceleration_g > 0.0:
		markers.append(_marker(&"peak_loading", "Peak loading", peak_deceleration_time_s))
	if first_failure_time_s >= 0.0:
		markers.append(_marker(&"structural_failure", "Structural failure", first_failure_time_s))
	if last_contact_increment_time_s >= 0.0 and last_contact_increment_time_s < recording.duration_s - recording.sample_interval_s:
		markers.append(_marker(&"separation", "Separation", minf(last_contact_increment_time_s + recording.sample_interval_s, recording.duration_s)))
	if rest_time_s >= 0.0:
		markers.append(_marker(&"rest", "Rest", rest_time_s))
	_sort_markers(markers)
	recording.set_event_markers(markers)

	var final_delta_v_ms := (final_velocity - initial_velocity).length()
	var report := {
		"duration_s": recording.duration_s,
		"sample_count": recording.frames.size(),
		"final_delta_v_kmh": PhysicsMetrics.ms_to_kmh(final_delta_v_ms),
		"max_delta_v_kmh": PhysicsMetrics.ms_to_kmh(max_delta_v_ms),
		"peak_deceleration_g": peak_deceleration_g,
		"peak_deceleration_time_s": peak_deceleration_time_s,
		"max_front_crush_mm": max_front_crush_m * 1000.0,
		"max_safety_cell_deformation_mm": max_safety_cell_m * 1000.0,
		"max_broken_beams": max_broken_beams,
		"initial_kinetic_energy_kj": float(first_primary.get("kinetic_energy_j", 0.0)) / 1000.0,
		"final_kinetic_energy_kj": float(last_primary.get("kinetic_energy_j", 0.0)) / 1000.0,
		"crash_pulse_series": crash_pulse,
		"front_crush_series": front_crush,
		"safety_cell_series": safety_cell,
		"event_markers": markers,
	}
	var first_target := _metrics(first, "target_metrics")
	var last_target := _metrics(last, "target_metrics")
	if not first_target.is_empty() and not last_target.is_empty():
		var target_initial_velocity: Vector3 = first_target.get("linear_velocity_ms", Vector3.ZERO)
		var target_final_velocity: Vector3 = last_target.get("linear_velocity_ms", Vector3.ZERO)
		report["target_final_delta_v_kmh"] = PhysicsMetrics.ms_to_kmh((target_final_velocity - target_initial_velocity).length())
	return report

static func _metrics(frame: Dictionary, key: String) -> Dictionary:
	var value: Variant = frame.get(key, {})
	return value if value is Dictionary else {}

static func _marker(id: StringName, label: String, time_s: float) -> Dictionary:
	return {"id": String(id), "label": label, "time_s": time_s}

static func _sort_markers(markers: Array[Dictionary]) -> void:
	for i in range(markers.size()):
		for j in range(i + 1, markers.size()):
			if float(markers[j].get("time_s", 0.0)) < float(markers[i].get("time_s", 0.0)):
				var temporary := markers[i]
				markers[i] = markers[j]
				markers[j] = temporary
