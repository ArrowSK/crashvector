# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ContactManifoldMetrics
extends RefCounted

# M19 diagnostic helper. It summarizes the real Godot contact samples already
# collected by VehicleRigidChassis, but does not modify impulses, collision
# shapes, classification, crush demand or solver response.

const GROUND_NAMES := [&"Road", &"Ground", &"ProvingGround"]

static func summarize(samples: Array) -> Dictionary:
	var count := 0
	var have_point := false
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	var unweighted_centroid := Vector3.ZERO
	var weighted_centroid := Vector3.ZERO
	var weighted_normal := Vector3.ZERO
	var total_impulse_ns := 0.0
	var total_weight := 0.0
	var collider_names: Array[String] = []

	for sample_variant in samples:
		if not sample_variant is Dictionary:
			continue
		var sample: Dictionary = sample_variant
		var collider_name := StringName(String(sample.get("collider_name", "")))
		if collider_name in GROUND_NAMES:
			continue
		var position_value: Variant = sample.get("position_local", Vector3.ZERO)
		if not position_value is Vector3:
			continue
		var position: Vector3 = position_value
		var impulse_value: Variant = sample.get("impulse", Vector3.ZERO)
		var impulse := impulse_value as Vector3 if impulse_value is Vector3 else Vector3.ZERO
		var normal_value: Variant = sample.get("normal", Vector3.ZERO)
		var normal := normal_value as Vector3 if normal_value is Vector3 else Vector3.ZERO
		var impulse_magnitude := impulse.length()
		var weight := maxf(impulse_magnitude, 0.000001)

		count += 1
		unweighted_centroid += position
		weighted_centroid += position * weight
		weighted_normal += normal * weight
		total_impulse_ns += impulse_magnitude
		total_weight += weight
		if not have_point:
			minimum = position
			maximum = position
			have_point = true
		else:
			minimum = minimum.min(position)
			maximum = maximum.max(position)
		var collider_text := String(collider_name)
		if not collider_text.is_empty() and collider_text not in collider_names:
			collider_names.append(collider_text)

	if count == 0:
		return {
			"contact_count": 0,
			"total_impulse_ns": 0.0,
			"centroid_local_m": Vector3.ZERO,
			"span_local_m": Vector3.ZERO,
			"normal_local": Vector3.ZERO,
			"projected_span_xz_m2": 0.0,
			"collider_names": [],
			"interpretation": "No non-ground contacts in this physics integration step.",
		}

	var centroid := weighted_centroid / total_weight if total_weight > 0.000001 else unweighted_centroid / float(count)
	var normal := weighted_normal.normalized() if not weighted_normal.is_zero_approx() else Vector3.ZERO
	var span := maximum - minimum
	return {
		"contact_count": count,
		"total_impulse_ns": total_impulse_ns,
		"centroid_local_m": centroid,
		"span_local_m": span,
		"normal_local": normal,
		# Bounding-box spread in the chassis X/Z plane is useful for comparing a
		# point-like, offset and broadside contact. It is deliberately not labelled
		# as physical contact-patch area.
		"projected_span_xz_m2": maxf(span.x, 0.0) * maxf(span.z, 0.0),
		"collider_names": collider_names,
		"interpretation": "Diagnostic spread of reported Godot contact points; not a physical contact-patch area or validation corridor.",
	}
