# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ReplayRecorder
extends RefCounted

var recording := ReplayRecording.new()
var _last_sample_time_s: float = -1.0

func begin(sample_interval_s: float = 1.0 / 120.0) -> void:
	recording = ReplayRecording.new()
	recording.sample_interval_s = maxf(sample_interval_s, 1.0 / 480.0)
	_last_sample_time_s = -1.0

func capture(
	time_s: float,
	primary_model: StructuralModel,
	target_model: StructuralModel,
	primary_metrics: Dictionary,
	target_metrics: Dictionary,
	context: Dictionary,
	primary_visual_state: Dictionary = {},
	target_visual_state: Dictionary = {},
	force: bool = false
) -> bool:
	if primary_model == null:
		return false
	if not force and _last_sample_time_s >= 0.0:
		if time_s - _last_sample_time_s < recording.sample_interval_s * 0.95:
			return false
	var frame := {
		"time_s": maxf(time_s, 0.0),
		"primary_state": StructuralSnapshot.capture(primary_model),
		"primary_metrics": primary_metrics.duplicate(true),
		"primary_visual_state": primary_visual_state.duplicate(true),
		"context": context.duplicate(true),
	}
	if target_model != null:
		frame["target_state"] = StructuralSnapshot.capture(target_model)
		frame["target_metrics"] = target_metrics.duplicate(true)
		frame["target_visual_state"] = target_visual_state.duplicate(true)
	recording.add_frame(frame)
	_last_sample_time_s = maxf(time_s, 0.0)
	return true

func force_final(
	time_s: float,
	primary_model: StructuralModel,
	target_model: StructuralModel,
	primary_metrics: Dictionary,
	target_metrics: Dictionary,
	context: Dictionary,
	primary_visual_state: Dictionary = {},
	target_visual_state: Dictionary = {}
) -> void:
	if recording.has_frames() and absf(recording.duration_s - time_s) <= 0.000001:
		return
	capture(
		time_s,
		primary_model,
		target_model,
		primary_metrics,
		target_metrics,
		context,
		primary_visual_state,
		target_visual_state,
		true
	)
