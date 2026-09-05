# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M161VehicleVisual
extends M16VehicleVisualRefined

# M16.1 is presentation-only. The structural nodes remain the deformation
# anchors and the rigid chassis/collision shapes remain untouched. These extra
# offsets deliberately exaggerate the visual archetype enough that each generic
# class reads correctly at the normal editor camera distance.

func _section_at_u(u: float) -> Dictionary:
	var section: Dictionary = super._section_at_u(u)
	if vehicle == null or section.is_empty():
		return section

	var reference := vehicle.global_reference_transform()
	var forward := reference.basis.x.normalized()
	var up := reference.basis.y.normalized()
	var style := String(profile.get("style", "hatch"))
	var clamped_u := clampf(u, 0.0, 1.0)

	var body_lift := 0.0
	var belt_extra := 0.0
	var roof_extra := 0.0
	var upper_forward_extra := 0.0

	match style:
		"city":
			# Short, upright, glassy city-car stance.
			body_lift = 0.025
			roof_extra = 0.07 * sin(PI * clamped_u)
			upper_forward_extra = 0.035 * sin(PI * clamped_u)
		"compact":
			# Slightly longer/lower than the hatchback baseline.
			roof_extra = -0.025 * sin(PI * clamped_u)
		"midsize":
			# A visible three-box/fastback proportion: lower deck at the rear,
			# a lower roof, and a real bonnet ahead of the windscreen.
			var rear_deck := 1.0 - smoothstep(0.08, 0.24, clamped_u)
			var bonnet := smoothstep(0.61, 0.86, clamped_u)
			roof_extra = -0.08 * sin(PI * clamped_u) - 0.16 * rear_deck - 0.17 * bonnet
			upper_forward_extra = -0.10 * smoothstep(0.48, 0.68, clamped_u) * (1.0 - smoothstep(0.82, 1.0, clamped_u))
		"suv":
			# High floor, beltline, bonnet and roof. The stronger lift and wheel
			# package make the class read as an SUV rather than a tall hatchback.
			body_lift = 0.105
			belt_extra = 0.065
			roof_extra = 0.085 + 0.045 * sin(PI * clamped_u)
			if clamped_u > 0.68:
				roof_extra += 0.07 * smoothstep(0.68, 0.92, clamped_u)
			upper_forward_extra = -0.035 * smoothstep(0.48, 0.72, clamped_u)
		"mpv":
			# Cab-forward body with a long, high greenhouse. Keep the roof tall
			# until close to the nose and push the front cabin visibly forward.
			body_lift = 0.060
			belt_extra = 0.045
			roof_extra = 0.10 + 0.08 * (1.0 - smoothstep(0.78, 0.98, clamped_u))
			upper_forward_extra = 0.18 * smoothstep(0.52, 0.78, clamped_u) * (1.0 - smoothstep(0.92, 1.0, clamped_u))
			if clamped_u > 0.90:
				roof_extra -= 0.08 * smoothstep(0.90, 1.0, clamped_u)
		_:
			# B-segment hatchback remains the neutral visual baseline.
			pass

	for key in ["lower_left", "lower_right"]:
		section[key] = (section[key] as Vector3) + up * body_lift
	for key in ["belt_left", "belt_right"]:
		section[key] = (section[key] as Vector3) + up * (body_lift + belt_extra) + forward * upper_forward_extra * 0.45
	for key in ["upper_left", "upper_right"]:
		section[key] = (section[key] as Vector3) + up * (body_lift + roof_extra) + forward * upper_forward_extra
	return section
