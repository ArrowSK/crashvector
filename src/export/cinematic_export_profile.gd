# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CinematicExportProfile
extends RefCounted

const RES_1080P: StringName = &"1080p"
const RES_1440P: StringName = &"1440p"
const RES_4K: StringName = &"4k"

const CAMERA_AUTO: StringName = &"auto_cinematic"
const CAMERA_WIDE: StringName = &"wide"
const CAMERA_TRACKING: StringName = &"tracking"
const CAMERA_IMPACT: StringName = &"impact"
const CAMERA_ORBIT: StringName = &"orbit"

var resolution_id: StringName = RES_1080P
var fps: int = 60
var camera_id: StringName = CAMERA_AUTO
var slow_motion_enabled: bool = true
var slow_motion_factor: float = 0.25
var slow_before_contact_s: float = 0.20
var slow_after_contact_s: float = 0.45
var intro_hold_s: float = 0.65
var outro_hold_s: float = 1.35
var include_overlays: bool = true
var include_title_card: bool = true
var include_result_card: bool = true
var primary_paint_id: StringName = CarPaintCatalog.ELECTRIC_BLUE
var target_paint_id: StringName = CarPaintCatalog.SILVER
var jpeg_quality: float = 0.96
var keep_frame_sequence: bool = false

static func resolution_ids() -> Array[StringName]:
	return [RES_1080P, RES_1440P, RES_4K]

static func resolution_size(id: StringName) -> Vector2i:
	match id:
		RES_1440P:
			return Vector2i(2560, 1440)
		RES_4K:
			return Vector2i(3840, 2160)
		_:
			return Vector2i(1920, 1080)

static func resolution_display_name(id: StringName) -> String:
	match id:
		RES_1440P:
			return "1440p — 2560×1440"
		RES_4K:
			return "4K — 3840×2160"
		_:
			return "1080p — 1920×1080"

static func camera_ids() -> Array[StringName]:
	return [CAMERA_AUTO, CAMERA_WIDE, CAMERA_TRACKING, CAMERA_IMPACT, CAMERA_ORBIT]

static func camera_display_name(id: StringName) -> String:
	match id:
		CAMERA_WIDE:
			return "Wide overview"
		CAMERA_TRACKING:
			return "Vehicle tracking"
		CAMERA_IMPACT:
			return "Impact close-up"
		CAMERA_ORBIT:
			return "Aftermath orbit"
		_:
			return "Auto cinematic"

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not resolution_ids().has(resolution_id):
		errors.append("Unknown export resolution")
	if fps != 30 and fps != 60:
		errors.append("Video frame rate must be 30 or 60 fps")
	if not camera_ids().has(camera_id):
		errors.append("Unknown cinematic camera preset")
	if slow_motion_factor < 0.05 or slow_motion_factor > 1.0:
		errors.append("Slow-motion factor must be between 0.05x and 1.0x")
	if slow_before_contact_s < 0.0 or slow_before_contact_s > 2.0:
		errors.append("Pre-impact slow-motion window is out of range")
	if slow_after_contact_s < 0.0 or slow_after_contact_s > 3.0:
		errors.append("Post-impact slow-motion window is out of range")
	if intro_hold_s < 0.0 or intro_hold_s > 5.0 or outro_hold_s < 0.0 or outro_hold_s > 8.0:
		errors.append("Title/result hold duration is out of range")
	if not CarPaintCatalog.is_valid(primary_paint_id) or not CarPaintCatalog.is_valid(target_paint_id):
		errors.append("Unknown vehicle paint selection")
	if jpeg_quality < 0.75 or jpeg_quality > 1.0:
		errors.append("Frame quality must be between 0.75 and 1.0")
	return errors

func to_dictionary() -> Dictionary:
	var dimensions := resolution_size(resolution_id)
	return {
		"resolution_id": String(resolution_id),
		"width": dimensions.x,
		"height": dimensions.y,
		"fps": fps,
		"camera_id": String(camera_id),
		"slow_motion_enabled": slow_motion_enabled,
		"slow_motion_factor": slow_motion_factor,
		"slow_before_contact_s": slow_before_contact_s,
		"slow_after_contact_s": slow_after_contact_s,
		"intro_hold_s": intro_hold_s,
		"outro_hold_s": outro_hold_s,
		"include_overlays": include_overlays,
		"include_title_card": include_title_card,
		"include_result_card": include_result_card,
		"primary_paint_id": String(primary_paint_id),
		"target_paint_id": String(target_paint_id),
		"jpeg_quality": jpeg_quality,
		"keep_frame_sequence": keep_frame_sequence,
	}
