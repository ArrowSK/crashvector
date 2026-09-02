# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CinematicTimeline
extends RefCounted

var replay_duration_s: float = 0.0
var first_contact_s: float = -1.0
var intro_hold_s: float = 0.0
var outro_hold_s: float = 0.0
var slow_enabled: bool = false
var slow_factor: float = 1.0
var slow_start_replay_s: float = 0.0
var slow_end_replay_s: float = 0.0
var output_duration_s: float = 0.0

func configure(recording: ReplayRecording, profile: CinematicExportProfile) -> void:
	replay_duration_s = 0.0 if recording == null else maxf(recording.duration_s, 0.0)
	first_contact_s = -1.0 if recording == null else recording.marker_time(&"first_contact")
	intro_hold_s = maxf(profile.intro_hold_s if profile.include_title_card else 0.0, 0.0)
	outro_hold_s = maxf(profile.outro_hold_s if profile.include_result_card else 0.0, 0.0)
	slow_factor = clampf(profile.slow_motion_factor, 0.05, 1.0)
	slow_enabled = profile.slow_motion_enabled and first_contact_s >= 0.0 and slow_factor < 0.999999
	if slow_enabled:
		slow_start_replay_s = clampf(first_contact_s - profile.slow_before_contact_s, 0.0, replay_duration_s)
		slow_end_replay_s = clampf(first_contact_s + profile.slow_after_contact_s, slow_start_replay_s, replay_duration_s)
		if slow_end_replay_s - slow_start_replay_s <= 0.000001:
			slow_enabled = false
	else:
		slow_start_replay_s = 0.0
		slow_end_replay_s = 0.0
	output_duration_s = intro_hold_s + replay_duration_s + outro_hold_s
	if slow_enabled:
		var slow_span := slow_end_replay_s - slow_start_replay_s
		output_duration_s += slow_span / slow_factor - slow_span

func replay_time_for_output_time(output_time_s: float) -> float:
	if replay_duration_s <= 0.0:
		return 0.0
	var output_time := clampf(output_time_s, 0.0, output_duration_s)
	if output_time <= intro_hold_s:
		return 0.0
	var local_time := output_time - intro_hold_s
	if not slow_enabled:
		return clampf(local_time, 0.0, replay_duration_s)
	var pre_duration := slow_start_replay_s
	if local_time <= pre_duration:
		return clampf(local_time, 0.0, replay_duration_s)
	var slow_replay_span := slow_end_replay_s - slow_start_replay_s
	var slow_output_span := slow_replay_span / slow_factor
	if local_time <= pre_duration + slow_output_span:
		return clampf(slow_start_replay_s + (local_time - pre_duration) * slow_factor, 0.0, replay_duration_s)
	var after_slow_output := local_time - pre_duration - slow_output_span
	return clampf(slow_end_replay_s + after_slow_output, 0.0, replay_duration_s)

func frame_count(fps: int) -> int:
	var safe_fps := maxi(fps, 1)
	return maxi(int(ceil(output_duration_s * float(safe_fps))) + 1, 1)

func output_time_for_frame(frame_index: int, fps: int) -> float:
	var safe_fps := maxi(fps, 1)
	return minf(float(maxi(frame_index, 0)) / float(safe_fps), output_duration_s)

func impact_output_time_s() -> float:
	if first_contact_s < 0.0:
		return intro_hold_s
	if not slow_enabled:
		return intro_hold_s + first_contact_s
	if first_contact_s <= slow_start_replay_s:
		return intro_hold_s + first_contact_s
	if first_contact_s <= slow_end_replay_s:
		return intro_hold_s + slow_start_replay_s + (first_contact_s - slow_start_replay_s) / slow_factor
	var slow_span := slow_end_replay_s - slow_start_replay_s
	return intro_hold_s + slow_start_replay_s + slow_span / slow_factor + (first_contact_s - slow_end_replay_s)

func phase_at_output_time(output_time_s: float) -> StringName:
	var output_time := clampf(output_time_s, 0.0, output_duration_s)
	if intro_hold_s > 0.0 and output_time < intro_hold_s - 0.000001:
		return &"intro"
	if outro_hold_s > 0.0 and output_time > output_duration_s - outro_hold_s + 0.000001:
		return &"result"
	if slow_enabled:
		var replay_time := replay_time_for_output_time(output_time)
		if replay_time >= slow_start_replay_s and replay_time <= slow_end_replay_s:
			return &"slow_motion"
	var replay_time := replay_time_for_output_time(output_time)
	if first_contact_s >= 0.0 and replay_time < first_contact_s:
		return &"approach"
	return &"aftermath"
