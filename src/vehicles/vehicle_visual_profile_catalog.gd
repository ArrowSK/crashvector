# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleVisualProfileCatalog
extends RefCounted

# Presentation-only archetypes. These values shape the generated skin, glazing
# and wheels and do not change mass, stiffness, collision geometry, structural
# nodes or solver behaviour. M16.1 deliberately increases the separation
# between classes after packaged-beta review showed that the first M16 pass was
# too subtle at normal camera distance.

static func data(preset_id: StringName) -> Dictionary:
	match preset_id:
		PassengerCarCatalog.A_SEGMENT_CITY:
			return _profile(
				"city", [0.00, 0.10, 0.10, 0.07, -0.01, -0.04, 0.00],
				[0.00, 0.19, 0.23, 0.22, 0.18, 0.08, 0.00],
				[0.98, 0.99, 0.99, 0.98, 0.97, 0.96, 0.96],
				0.12, 0.78, 0.60, 0.315, 0.185, 0.60, 0.00, 0.00
			)
		PassengerCarCatalog.C_SEGMENT_COMPACT:
			return _profile(
				"compact", [0.00, 0.12, 0.03, -0.04, -0.17, -0.12, 0.00],
				[-0.03, 0.00, -0.03, -0.05, -0.05, -0.03, 0.00],
				[1.01, 1.01, 1.00, 1.00, 0.99, 0.98, 0.98],
				0.20, 0.66, 0.57, 0.335, 0.205, 0.64, 0.00, 0.00
			)
		PassengerCarCatalog.D_SEGMENT_MIDSIZE:
			return _profile(
				"midsize", [0.00, 0.12, 0.03, -0.10, -0.28, -0.18, 0.00],
				[-0.10, -0.06, -0.08, -0.10, -0.09, -0.04, 0.00],
				[1.02, 1.02, 1.01, 1.01, 1.00, 0.99, 0.99],
				0.22, 0.62, 0.55, 0.360, 0.220, 0.67, -0.04, 0.00
			)
		PassengerCarCatalog.J_SEGMENT_SUV:
			return _profile(
				"suv", [0.00, 0.03, -0.01, -0.04, -0.13, -0.09, 0.00],
				[0.12, 0.28, 0.34, 0.35, 0.34, 0.28, 0.16],
				[1.08, 1.08, 1.07, 1.07, 1.06, 1.05, 1.04],
				0.14, 0.70, 0.61, 0.420, 0.255, 0.68, 0.27, 0.18
			)
		PassengerCarCatalog.M_SEGMENT_MPV:
			return _profile(
				"mpv", [0.00, 0.04, 0.08, 0.14, 0.30, 0.34, 0.08],
				[0.14, 0.36, 0.42, 0.43, 0.42, 0.34, 0.12],
				[1.07, 1.07, 1.07, 1.06, 1.06, 1.04, 1.02],
				0.08, 0.86, 0.59, 0.385, 0.235, 0.64, 0.08, 0.12
			)
		_:
			return _profile(
				"hatch", [0.00, 0.11, 0.04, 0.00, -0.12, -0.10, 0.00],
				[0.00, 0.03, 0.04, 0.04, 0.02, 0.00, 0.00],
				[1.00, 1.00, 0.99, 0.99, 0.98, 0.98, 0.98],
				0.20, 0.71, 0.58, 0.320, 0.195, 0.61, 0.00, 0.00
			)

static func _profile(
	style: String,
	upper_x_offset_m: Array,
	roof_offset_m: Array,
	upper_width_scale: Array,
	glass_start_u: float,
	glass_end_u: float,
	belt_ratio: float,
	wheel_radius_m: float,
	wheel_width_m: float,
	rim_ratio: float,
	hood_raise_m: float,
	cladding_height_m: float
) -> Dictionary:
	return {
		"style": style,
		"upper_x_offset_m": upper_x_offset_m,
		"roof_offset_m": roof_offset_m,
		"upper_width_scale": upper_width_scale,
		"glass_start_u": glass_start_u,
		"glass_end_u": glass_end_u,
		"belt_ratio": belt_ratio,
		"wheel_radius_m": wheel_radius_m,
		"wheel_width_m": wheel_width_m,
		"rim_ratio": rim_ratio,
		"hood_raise_m": hood_raise_m,
		"cladding_height_m": cladding_height_m,
	}

static func sample_station(profile: Dictionary, key: String, station_position: float) -> float:
	var values: Array = profile.get(key, [])
	if values.is_empty():
		return 0.0
	if values.size() == 1:
		return float(values[0])
	var clamped := clampf(station_position, 0.0, float(values.size() - 1))
	var a := int(floor(clamped))
	var b := mini(a + 1, values.size() - 1)
	return lerpf(float(values[a]), float(values[b]), clamped - float(a))

static func visual_signature(preset_id: StringName) -> Dictionary:
	var profile := data(preset_id)
	return {
		"style": profile.get("style", "hatch"),
		"wheel_radius_m": profile.get("wheel_radius_m", 0.320),
		"glass_start_u": profile.get("glass_start_u", 0.20),
		"glass_end_u": profile.get("glass_end_u", 0.71),
		"roof_mid_m": sample_station(profile, "roof_offset_m", 3.0),
		"windscreen_offset_m": sample_station(profile, "upper_x_offset_m", 4.0),
		"hood_raise_m": profile.get("hood_raise_m", 0.0),
	}
