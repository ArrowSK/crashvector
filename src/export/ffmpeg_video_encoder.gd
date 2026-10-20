# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name FFmpegVideoEncoder
extends RefCounted

static func locate_ffmpeg() -> String:
	var candidates: Array[String] = [
		"/opt/homebrew/bin/ffmpeg",
		"/usr/local/bin/ffmpeg",
		"/usr/bin/ffmpeg",
		"C:/ffmpeg/bin/ffmpeg.exe",
	]
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	var output: Array = []
	var exit_code := OS.execute("ffmpeg", PackedStringArray(["-version"]), output, true)
	return "ffmpeg" if exit_code == 0 else ""

static func ensure_mp4_path(path: String) -> String:
	var trimmed := path.strip_edges()
	# Keep a missing destination empty, so the exporter can reject it instead
	# of silently converting it into a file named ".mp4".
	if trimmed.is_empty():
		return ""
	if trimmed.to_lower().ends_with(".mp4"):
		return trimmed
	return "%s.mp4" % trimmed

static func build_args(frame_pattern: String, fps: int, output_path: String) -> PackedStringArray:
	return PackedStringArray([
		"-y",
		"-nostdin",
		"-hide_banner",
		"-loglevel", "error",
		"-framerate", str(maxi(fps, 1)),
		"-i", frame_pattern,
		"-c:v", "libx264",
		"-preset", "medium",
		"-crf", "18",
		"-pix_fmt", "yuv420p",
		"-movflags", "+faststart",
		ensure_mp4_path(output_path),
	])

# Launches FFmpeg without blocking the Godot main thread. The caller owns the
# process ID and must poll it and terminate it on cancellation or scene exit.
static func start_encode(frame_pattern: String, fps: int, output_path: String, executable: String = "") -> Dictionary:
	var ffmpeg := executable if not executable.is_empty() else locate_ffmpeg()
	if ffmpeg.is_empty():
		return {"ok": false, "pid": -1, "message": "FFmpeg was not found on this computer."}
	var args := build_args(frame_pattern, fps, output_path)
	var pid := OS.create_process(ffmpeg, args)
	if pid <= 0:
		return {"ok": false, "pid": -1, "message": "Could not launch FFmpeg."}
	return {
		"ok": true,
		"pid": pid,
		"output_path": ensure_mp4_path(output_path),
		"executable": ffmpeg,
	}

# A finished process must be checked for exit status before accepting its file.
static func poll_encode(pid: int) -> Dictionary:
	if pid <= 0:
		return {"finished": true, "exit_code": -1}
	if OS.is_process_running(pid):
		return {"finished": false}
	return {"finished": true, "exit_code": OS.get_process_exit_code(pid)}

static func cancel_encode(pid: int) -> Error:
	if pid <= 0:
		return ERR_INVALID_PARAMETER
	return OS.kill(pid)
