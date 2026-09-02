# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CinematicCameraPlanner
extends RefCounted

static func pose_for_frame(
	frame: Dictionary,
	config: ScenarioConfig,
	camera_id: StringName,
	replay_time_s: float,
	first_contact_s: float
) -> Dictionary:
	var primary_center := _snapshot_center(frame.get("primary_state", {}), config.car_position_m)
	var target_center := _snapshot_center(frame.get("target_state", {}), config.target_position_m)
	if not frame.has("target_state"):
		target_center = config.target_position_m + Vector3.UP * 0.8
	var forward := config.car_forward()
	if forward.is_zero_approx():
		forward = Vector3.RIGHT
	var side := forward.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.FORWARD

	match camera_id:
		CinematicExportProfile.CAMERA_WIDE:
			return _wide_pose(primary_center, target_center, forward, side)
		CinematicExportProfile.CAMERA_TRACKING:
			return _tracking_pose(primary_center, target_center, forward, side)
		CinematicExportProfile.CAMERA_IMPACT:
			return _impact_pose(primary_center, target_center, forward, side)
		CinematicExportProfile.CAMERA_ORBIT:
			return _orbit_pose(primary_center, target_center, forward, side, replay_time_s)
		_:
			return _auto_pose(primary_center, target_center, forward, side, replay_time_s, first_contact_s)

static func _wide_pose(primary: Vector3, target: Vector3, forward: Vector3, side: Vector3) -> Dictionary:
	var midpoint := (primary + target) * 0.5
	var separation := primary.distance_to(target)
	return _pose(
		midpoint - forward * 1.5 + side * maxf(9.0, separation * 0.55) + Vector3.UP * 5.2,
		midpoint + Vector3.UP * 0.75,
		50.0
	)

static func _tracking_pose(primary: Vector3, target: Vector3, forward: Vector3, side: Vector3) -> Dictionary:
	var look_ahead := primary.lerp(target, 0.28)
	return _pose(
		primary - forward * 5.6 + side * 5.8 + Vector3.UP * 2.6,
		look_ahead + Vector3.UP * 0.70,
		44.0
	)

static func _impact_pose(primary: Vector3, target: Vector3, forward: Vector3, side: Vector3) -> Dictionary:
	var midpoint := (primary + target) * 0.5
	return _pose(
		midpoint - forward * 3.6 + side * 4.7 + Vector3.UP * 2.15,
		midpoint + Vector3.UP * 0.65,
		38.0
	)

static func _orbit_pose(primary: Vector3, target: Vector3, forward: Vector3, side: Vector3, replay_time_s: float) -> Dictionary:
	var midpoint := (primary + target) * 0.5
	var angle := replay_time_s * 0.62 + 0.35
	var radial := side * cos(angle) + forward * sin(angle)
	return _pose(
		midpoint + radial * 7.6 + Vector3.UP * 3.0,
		midpoint + Vector3.UP * 0.75,
		42.0
	)

static func _auto_pose(
	primary: Vector3,
	target: Vector3,
	forward: Vector3,
	side: Vector3,
	replay_time_s: float,
	first_contact_s: float
) -> Dictionary:
	var tracking := _tracking_pose(primary, target, forward, side)
	var impact := _impact_pose(primary, target, forward, side)
	var orbit := _orbit_pose(primary, target, forward, side, replay_time_s)
	if first_contact_s < 0.0:
		return _blend_pose(tracking, _wide_pose(primary, target, forward, side), 0.30)
	var relative := replay_time_s - first_contact_s
	if relative <= -0.35:
		return tracking
	if relative < -0.05:
		return _blend_pose(tracking, impact, _smooth01((relative + 0.35) / 0.30))
	if relative <= 0.38:
		return impact
	if relative < 1.20:
		return _blend_pose(impact, orbit, _smooth01((relative - 0.38) / 0.82))
	return orbit

static func _pose(position: Vector3, target: Vector3, fov: float) -> Dictionary:
	return {
		"position": position,
		"target": target,
		"fov": clampf(fov, 20.0, 85.0),
	}

static func _blend_pose(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var t := clampf(weight, 0.0, 1.0)
	var position_a: Vector3 = a.get("position", Vector3.ZERO)
	var position_b: Vector3 = b.get("position", Vector3.ZERO)
	var target_a: Vector3 = a.get("target", Vector3.ZERO)
	var target_b: Vector3 = b.get("target", Vector3.ZERO)
	return _pose(
		position_a.lerp(position_b, t),
		target_a.lerp(target_b, t),
		lerpf(float(a.get("fov", 45.0)), float(b.get("fov", 45.0)), t)
	)

static func _snapshot_center(snapshot_value: Variant, fallback: Vector3) -> Vector3:
	if not (snapshot_value is Dictionary):
		return fallback
	var snapshot: Dictionary = snapshot_value
	var positions: PackedVector3Array = snapshot.get("positions_m", PackedVector3Array())
	if positions.is_empty():
		return fallback
	var x := 0.0
	var y := 0.0
	var z := 0.0
	for position in positions:
		x += float(position.x)
		y += float(position.y)
		z += float(position.z)
	var count := float(positions.size())
	return Vector3(x / count, y / count, z / count)

static func _smooth01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
