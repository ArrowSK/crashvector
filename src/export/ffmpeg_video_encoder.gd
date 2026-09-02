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
	if trimmed.to_lower().ends_with(".mp4"):
		return trimmed
	return "%s.mp4" % trimmed

static func build_args(frame_pattern: String, fps: int, output_path: String) -> PackedStringArray:
	return PackedStringArray([
		"-y",
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

static func encode(frame_pattern: String, fps: int, output_path: String, executable: String = "") -> Dictionary:
	var ffmpeg := executable if not executable.is_empty() else locate_ffmpeg()
	if ffmpeg.is_empty():
		return {"ok": false, "exit_code": -1, "message": "FFmpeg was not found on this computer."}
	var output: Array = []
	var args := build_args(frame_pattern, fps, output_path)
	var exit_code := OS.execute(ffmpeg, args, output, true)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"message": "\n".join(output),
		"output_path": ensure_mp4_path(output_path),
		"executable": ffmpeg,
	}
