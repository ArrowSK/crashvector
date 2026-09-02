# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CinematicExporter
extends Node

signal progress_changed(progress: float, message: String)
signal export_finished(result: Dictionary)

var cancel_requested: bool = false
var active: bool = false

func cancel() -> void:
	cancel_requested = true

func export_video(
	recording: ReplayRecording,
	scenario: ScenarioConfig,
	analysis: Dictionary,
	profile: CinematicExportProfile,
	requested_output_path: String
) -> Dictionary:
	if active:
		return _finish({"ok": false, "message": "A cinematic export is already running."})
	var profile_errors := profile.validation_errors()
	if not profile_errors.is_empty():
		return _finish({"ok": false, "message": "; ".join(profile_errors)})
	if recording == null or not recording.has_frames():
		return _finish({"ok": false, "message": "No recorded replay is available to export."})
	if scenario == null:
		return _finish({"ok": false, "message": "The scenario is missing."})
	var output_path := FFmpegVideoEncoder.ensure_mp4_path(requested_output_path)
	if output_path.strip_edges().is_empty():
		return _finish({"ok": false, "message": "Choose an output MP4 path."})
	var ffmpeg := FFmpegVideoEncoder.locate_ffmpeg()
	if ffmpeg.is_empty():
		return _finish({
			"ok": false,
			"message": "FFmpeg was not found. CrashVector uses an external FFmpeg installation for MP4 encoding and does not bundle a codec binary.",
		})

	active = true
	cancel_requested = false
	var output_dir := output_path.get_base_dir()
	if output_dir.is_empty():
		output_dir = "."
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		active = false
		return _finish({"ok": false, "message": "Could not create the output directory."})
	var frame_dir_name := ".crashvector_frames_%d" % Time.get_ticks_msec()
	var frame_dir := output_dir.path_join(frame_dir_name)
	mkdir_error = DirAccess.make_dir_recursive_absolute(frame_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		active = false
		return _finish({"ok": false, "message": "Could not create the temporary frame directory."})

	var timeline := CinematicTimeline.new()
	timeline.configure(recording, profile)
	var stage := CinematicRenderStage.new()
	stage.name = "CinematicRenderStage"
	add_child(stage)
	stage.configure(recording, scenario, analysis, profile, timeline)
	var frame_count := timeline.frame_count(profile.fps)
	var render_result := await _render_frames(stage, timeline, profile, frame_dir, frame_count)
	remove_child(stage)
	stage.queue_free()

	if not bool(render_result.get("ok", false)):
		active = false
		if not profile.keep_frame_sequence and not cancel_requested:
			_cleanup_frame_directory(frame_dir)
		var failed := {
			"ok": false,
			"message": String(render_result.get("message", "Frame rendering failed.")),
			"frame_directory": frame_dir,
		}
		return _finish(failed)

	progress_changed.emit(0.94, "Encoding MP4 with FFmpeg…")
	var frame_pattern := frame_dir.path_join("frame_%06d.jpg")
	var encode_result := FFmpegVideoEncoder.encode(frame_pattern, profile.fps, output_path, ffmpeg)
	if not bool(encode_result.get("ok", false)):
		active = false
		var encoder_message := String(encode_result.get("message", "FFmpeg encoding failed."))
		return _finish({
			"ok": false,
			"message": "FFmpeg encoding failed. The rendered frames were kept so they are not lost. %s" % encoder_message,
			"frame_directory": frame_dir,
		})

	_write_metadata_sidecar(output_path, scenario, analysis, profile, timeline, frame_count)
	if not profile.keep_frame_sequence:
		_cleanup_frame_directory(frame_dir)
	active = false
	progress_changed.emit(1.0, "Cinematic MP4 complete")
	return _finish({
		"ok": true,
		"message": "Cinematic video export complete.",
		"output_path": output_path,
		"frame_count": frame_count,
		"output_duration_s": timeline.output_duration_s,
		"resolution": CinematicExportProfile.resolution_size(profile.resolution_id),
		"fps": profile.fps,
		"frame_directory": frame_dir if profile.keep_frame_sequence else "",
	})

func _render_frames(
	stage: CinematicRenderStage,
	timeline: CinematicTimeline,
	profile: CinematicExportProfile,
	frame_dir: String,
	frame_count: int
) -> Dictionary:
	for frame_index in range(frame_count):
		if cancel_requested:
			return {"ok": false, "message": "Video export cancelled."}
		var output_time := timeline.output_time_for_frame(frame_index, profile.fps)
		stage.apply_output_time(output_time)
		var frame_path := frame_dir.path_join("frame_%06d.jpg" % frame_index)
		var save_error: Error = await stage.render_frame_to_jpeg(frame_path)
		if save_error != OK:
			return {
				"ok": false,
				"message": "Could not render frame %d (error %d)." % [frame_index, save_error],
			}
		if frame_index % 3 == 0 or frame_index == frame_count - 1:
			var progress := 0.92 * float(frame_index + 1) / float(maxi(frame_count, 1))
			progress_changed.emit(progress, "Rendering frame %d / %d" % [frame_index + 1, frame_count])
	return {"ok": true}

func _write_metadata_sidecar(
	output_path: String,
	scenario: ScenarioConfig,
	analysis: Dictionary,
	profile: CinematicExportProfile,
	timeline: CinematicTimeline,
	frame_count: int
) -> void:
	var summary := {
		"final_delta_v_kmh": float(analysis.get("final_delta_v_kmh", 0.0)),
		"peak_deceleration_g": float(analysis.get("peak_deceleration_g", 0.0)),
		"max_front_crush_mm": float(analysis.get("max_front_crush_mm", 0.0)),
		"max_safety_cell_deformation_mm": float(analysis.get("max_safety_cell_deformation_mm", 0.0)),
		"initial_kinetic_energy_kj": float(analysis.get("initial_kinetic_energy_kj", 0.0)),
	}
	var metadata := {
		"format": "CrashVector cinematic export metadata",
		"created_at": Time.get_datetime_string_from_system(),
		"scenario": scenario.to_dictionary(),
		"profile": profile.to_dictionary(),
		"analysis_summary": summary,
		"video": {
			"frame_count": frame_count,
			"output_duration_s": timeline.output_duration_s,
			"first_contact_replay_s": timeline.first_contact_s,
			"impact_output_s": timeline.impact_output_time_s(),
		},
		"disclaimer": "Educational simulation output; not certified accident reconstruction, manufacturer crash performance, or injury prediction.",
	}
	var sidecar_path := "%s.crashvector-video.json" % output_path.get_basename()
	var file := FileAccess.open(sidecar_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metadata, "\t"))
		file.close()

func _cleanup_frame_directory(frame_dir: String) -> void:
	var directory := DirAccess.open(frame_dir)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(frame_dir.path_join(file_name))
	DirAccess.remove_absolute(frame_dir)

func _finish(result: Dictionary) -> Dictionary:
	export_finished.emit(result)
	return result
