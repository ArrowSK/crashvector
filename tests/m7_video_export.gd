# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	_test_profile(failures)
	_test_timeline(failures)
	_test_camera_planner(failures)
	_test_ffmpeg_arguments(failures)
	_test_render_stage_instantiation(failures)
	if failures.is_empty():
		print("CrashVector M7 cinematic-export tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_profile(failures: Array[String]) -> void:
	var profile := CinematicExportProfile.new()
	if not profile.validation_errors().is_empty():
		failures.append("Default M7 export profile is invalid")
	if CinematicExportProfile.resolution_size(CinematicExportProfile.RES_1080P) != Vector2i(1920, 1080):
		failures.append("M7 1080p resolution is incorrect")
	if CinematicExportProfile.resolution_size(CinematicExportProfile.RES_4K) != Vector2i(3840, 2160):
		failures.append("M7 4K resolution is incorrect")
	profile.fps = 24
	if profile.validation_errors().is_empty():
		failures.append("M7 accepted an unsupported frame rate")

func _test_timeline(failures: Array[String]) -> void:
	var recording := _synthetic_recording()
	var profile := CinematicExportProfile.new()
	profile.intro_hold_s = 0.40
	profile.outro_hold_s = 0.60
	profile.slow_motion_factor = 0.25
	profile.slow_before_contact_s = 0.20
	profile.slow_after_contact_s = 0.40
	var timeline := CinematicTimeline.new()
	timeline.configure(recording, profile)
	if absf(timeline.output_duration_s - 4.80) > 0.0001:
		failures.append("M7 slow-motion timeline duration is incorrect")
	if absf(timeline.impact_output_time_s() - 2.00) > 0.0001:
		failures.append("M7 impact was not mapped to the expected output time")
	if absf(timeline.replay_time_for_output_time(2.00) - 1.00) > 0.0001:
		failures.append("M7 output-to-replay mapping lost first contact")
	if timeline.frame_count(60) != 289:
		failures.append("M7 fixed-frame output count is not deterministic")
	profile.slow_motion_enabled = false
	timeline.configure(recording, profile)
	if absf(timeline.output_duration_s - 3.00) > 0.0001:
		failures.append("M7 normal-speed timeline duration is incorrect")

func _test_camera_planner(failures: Array[String]) -> void:
	var config := ScenarioConfig.new()
	config.target_type = ScenarioConfig.TARGET_PASSENGER_CAR
	config.car_position_m = Vector3(-4.0, 0.0, 0.0)
	config.target_position_m = Vector3(2.0, 0.0, 0.0)
	var frame := {
		"primary_state": {"positions_m": PackedVector3Array([Vector3(-2.0, 0.5, -0.7), Vector3(-2.0, 0.5, 0.7)])},
		"target_state": {"positions_m": PackedVector3Array([Vector3(1.0, 0.5, -0.8), Vector3(1.0, 0.5, 0.8)])},
	}
	for camera_id in CinematicExportProfile.camera_ids():
		var pose := CinematicCameraPlanner.pose_for_frame(frame, config, camera_id, 1.1, 1.0)
		var position: Vector3 = pose.get("position", Vector3.ZERO)
		var target: Vector3 = pose.get("target", Vector3.ZERO)
		if not _finite_vector(position) or not _finite_vector(target):
			failures.append("M7 camera preset %s produced a non-finite pose" % String(camera_id))
		if position.distance_to(target) < 0.5:
			failures.append("M7 camera preset %s collapsed onto its target" % String(camera_id))

func _test_ffmpeg_arguments(failures: Array[String]) -> void:
	var args := FFmpegVideoEncoder.build_args("/tmp/frame_%06d.jpg", 60, "/tmp/crash.mp4")
	if args.find("-framerate") < 0 or args.find("60") < 0:
		failures.append("M7 FFmpeg arguments lost the selected frame rate")
	if args.find("libx264") < 0 or args.find("yuv420p") < 0:
		failures.append("M7 FFmpeg arguments lost the H.264 compatibility settings")
	if String(args[-1]) != "/tmp/crash.mp4":
		failures.append("M7 FFmpeg output path is incorrect")
	if FFmpegVideoEncoder.ensure_mp4_path("movie") != "movie.mp4":
		failures.append("M7 MP4 extension normalization failed")

func _test_render_stage_instantiation(failures: Array[String]) -> void:
	var stage := CinematicRenderStage.new()
	if stage == null:
		failures.append("M7 cinematic render stage could not instantiate")
	else:
		stage.free()
	var exporter := CinematicExporter.new()
	if exporter == null:
		failures.append("M7 cinematic exporter could not instantiate")
	else:
		exporter.free()

func _synthetic_recording() -> ReplayRecording:
	var recording := ReplayRecording.new()
	recording.sample_interval_s = 0.1
	for time_s in [0.0, 1.0, 2.0]:
		recording.add_frame({"time_s": time_s})
	recording.set_event_markers([{"id": "first_contact", "label": "First contact", "time_s": 1.0}])
	return recording

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
