# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M162VehicleVisual
extends M161VehicleVisual

# Presentation-only continuation of M16.1. The structural graph still supplies
# every deformation anchor. M16.2 applies a local visual fairing pass at severe
# collapse so adjacent body panels fold together instead of producing isolated
# triangular spikes, while leaving collision geometry and M12-M15 physics
# untouched.

func _section_at_u(u: float) -> Dictionary:
	var section: Dictionary = super._section_at_u(u)
	if vehicle == null or section.is_empty():
		return section

	var reference := vehicle.global_reference_transform()
	var forward := reference.basis.x.normalized()
	var up := reference.basis.y.normalized()
	var right := reference.basis.z.normalized()
	var clamped_u := clampf(u, 0.0, 1.0)
	var style := String(profile.get("style", "hatch"))

	# Refine the SUV greenhouse so it reads as a crossover rather than a tall
	# one-box hatch. The A-pillar is pulled rearward and the bonnet/shoulder line
	# stays visually separate from the roof volume.
	if style == "suv":
		var a_pillar := smoothstep(0.53, 0.67, clamped_u) * (1.0 - smoothstep(0.76, 0.84, clamped_u))
		var bonnet := smoothstep(0.72, 0.88, clamped_u)
		for key in ["upper_left", "upper_right"]:
			var point: Vector3 = section[key]
			section[key] = point - forward * 0.09 * a_pillar - up * 0.08 * a_pillar + up * 0.025 * bonnet
		for key in ["belt_left", "belt_right"]:
			var belt: Vector3 = section[key]
			section[key] = belt - forward * 0.035 * a_pillar + up * 0.018 * bonnet

	if not vehicle.hybrid_physics_enabled:
		return section
	var collapse := vehicle.hybrid_total_longitudinal_collapse_m()
	var fairing := smoothstep(0.24, 0.95, collapse)
	if fairing <= 0.001:
		return section

	# Neighbor samples come from the M16.1 presentation directly, not from this
	# override, so this remains a bounded one-pass filter rather than recursive
	# smoothing. X motion is preserved strongly; roof/width discontinuities are
	# smoothed more aggressively because those are what produced the visible
	# vertical wedges in beta.2.
	var previous: Dictionary = super._section_at_u(maxf(clamped_u - 0.055, 0.0))
	var following: Dictionary = super._section_at_u(minf(clamped_u + 0.055, 1.0))
	for key in ["lower_left", "lower_right", "belt_left", "belt_right", "upper_left", "upper_right"]:
		var point: Vector3 = section[key]
		var neighbor_average := (_v3(previous, key) + point * 2.0 + _v3(following, key)) * 0.25
		var correction := neighbor_average - point
		point += forward * correction.dot(forward) * fairing * 0.34
		point += up * correction.dot(up) * fairing * 0.78
		point += right * correction.dot(right) * fairing * 0.64
		section[key] = point

	# Keep each rendered cross-section ordered even when the underlying front
	# structure is deeply collapsed. The minimum visible height becomes very
	# small in the crush zone but the safety-cell region cannot invert inside-out.
	var crush_zone := smoothstep(0.72, 0.98, clamped_u)
	var minimum_height := lerpf(0.46, 0.12, crush_zone) * lerpf(1.0, 0.72, fairing)
	for side in ["left", "right"]:
		var lower_key := "lower_%s" % side
		var belt_key := "belt_%s" % side
		var upper_key := "upper_%s" % side
		var lower: Vector3 = section[lower_key]
		var belt: Vector3 = section[belt_key]
		var upper: Vector3 = section[upper_key]
		var total_height := (upper - lower).dot(up)
		if total_height < minimum_height:
			upper += up * (minimum_height - total_height)
			total_height = minimum_height
		var belt_height := (belt - lower).dot(up)
		var wanted_belt := clampf(belt_height, minf(0.18, total_height * 0.42), maxf(total_height - 0.10, total_height * 0.55))
		belt += up * (wanted_belt - belt_height)
		section[belt_key] = belt
		section[upper_key] = upper
	return section

func _update_details() -> void:
	super._update_details()
	if vehicle == null:
		return
	var collapse := vehicle.hybrid_total_longitudinal_collapse_m()
	var front_trim_survives := collapse < 0.52
	var lamps_survive := collapse < 0.66
	if grille != null:
		grille.visible = front_trim_survives
	if lower_front_trim != null:
		lower_front_trim.visible = front_trim_survives
	for lamp in headlamps:
		if lamp != null:
			lamp.visible = lamps_survive
	# Rear trim, mirrors and wheels remain tied to their authoritative anchors.
	# This avoids making severe frontal impacts look as if intact front jewellery
	# is floating in front of a collapsed structural nose.
