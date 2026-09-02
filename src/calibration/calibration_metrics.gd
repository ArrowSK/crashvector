# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CalibrationMetrics
extends RefCounted

static func from_result(result: Dictionary) -> Dictionary:
	var recording := result.get("recording") as ReplayRecording
	var analysis: Dictionary = result.get("analysis", {})
	if recording == null or not recording.has_frames() or analysis.is_empty():
		return {}
	var first := recording.first_frame()
	var first_metrics: Dictionary = first.get("primary_metrics", {})
	var initial_velocity: Vector3 = first_metrics.get("linear_velocity_ms", Vector3.ZERO)
	var initial_speed := initial_velocity.length()
	var direction := initial_velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector3.RIGHT
	var contact_time := recording.marker_time(&"first_contact")
	var pulse_end_time := -1.0
	if contact_time >= 0.0 and initial_speed > 0.000001:
		for frame in recording.frames:
			var time_s := float(frame.get("time_s", 0.0))
			if time_s < contact_time:
				continue
			var metrics: Dictionary = frame.get("primary_metrics", {})
			var velocity: Vector3 = metrics.get("linear_velocity_ms", Vector3.ZERO)
			var longitudinal_speed := absf(velocity.dot(direction))
			if longitudinal_speed <= initial_speed * 0.10:
				pulse_end_time = time_s
				break
	var pulse_duration := -1.0 if pulse_end_time < 0.0 or contact_time < 0.0 else pulse_end_time - contact_time
	var last := recording.last_frame()
	var context: Dictionary = last.get("context", {})
	return {
		"first_contact_time_s": contact_time,
		"pulse_end_time_s": pulse_end_time,
		"pulse_duration_s": pulse_duration,
		"delta_v_kmh": float(analysis.get("final_delta_v_kmh", 0.0)),
		"peak_deceleration_g": float(analysis.get("peak_deceleration_g", 0.0)),
		"front_crush_mm": float(analysis.get("max_front_crush_mm", 0.0)),
		"safety_cell_proxy_mm": float(analysis.get("max_safety_cell_deformation_mm", 0.0)),
		"energy_balance_relative_error": float(context.get("energy_balance_relative_error", 0.0)),
	}
