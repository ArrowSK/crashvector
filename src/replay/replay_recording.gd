# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ReplayRecording
extends RefCounted

var sample_interval_s: float = 1.0 / 120.0
var frames: Array[Dictionary] = []
var event_markers: Array[Dictionary] = []
var duration_s: float = 0.0

func clear() -> void:
	frames.clear()
	event_markers.clear()
	duration_s = 0.0

func add_frame(frame: Dictionary) -> void:
	if frame.is_empty():
		return
	frames.append(frame)
	duration_s = maxf(duration_s, float(frame.get("time_s", 0.0)))

func set_event_markers(markers: Array[Dictionary]) -> void:
	event_markers = markers.duplicate(true)

func has_frames() -> bool:
	return not frames.is_empty()

func frame_index_at_time(time_s: float) -> int:
	if frames.is_empty():
		return -1
	var target := clampf(time_s, 0.0, duration_s)
	var low := 0
	var high := frames.size() - 1
	while low < high:
		var mid := (low + high) / 2
		if float(frames[mid].get("time_s", 0.0)) < target:
			low = mid + 1
		else:
			high = mid
	if low <= 0:
		return 0
	var before_time := float(frames[low - 1].get("time_s", 0.0))
	var after_time := float(frames[low].get("time_s", 0.0))
	return low - 1 if absf(target - before_time) <= absf(after_time - target) else low

func frame_at_time(time_s: float) -> Dictionary:
	var index := frame_index_at_time(time_s)
	return {} if index < 0 else frames[index]

func first_frame() -> Dictionary:
	return {} if frames.is_empty() else frames[0]

func last_frame() -> Dictionary:
	return {} if frames.is_empty() else frames[-1]

func marker_time(id: StringName) -> float:
	for marker in event_markers:
		if StringName(String(marker.get("id", ""))) == id:
			return float(marker.get("time_s", -1.0))
	return -1.0
