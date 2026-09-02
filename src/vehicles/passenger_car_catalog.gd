# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name PassengerCarCatalog
extends RefCounted

const A_SEGMENT_CITY: StringName = &"a_segment_city"
const B_SEGMENT_HATCHBACK: StringName = &"b_segment_hatchback"
const C_SEGMENT_COMPACT: StringName = &"c_segment_compact"
const D_SEGMENT_MIDSIZE: StringName = &"d_segment_midsize"
const J_SEGMENT_SUV: StringName = &"j_segment_suv"
const M_SEGMENT_MPV: StringName = &"m_segment_mpv"

static func preset_ids() -> Array[StringName]:
	return [
		A_SEGMENT_CITY,
		B_SEGMENT_HATCHBACK,
		C_SEGMENT_COMPACT,
		D_SEGMENT_MIDSIZE,
		J_SEGMENT_SUV,
		M_SEGMENT_MPV,
	]

static func data(preset_id: StringName) -> Dictionary:
	match preset_id:
		A_SEGMENT_CITY:
			return {
				"id": A_SEGMENT_CITY,
				"display_name": "A-Segment City Car",
				"segment": "A",
				"default_mass_kg": 950.0,
				"representative_length_m": 3.68,
				"representative_width_m": 1.67,
				"scale_x": 0.91,
				"scale_y": 0.96,
				"scale_z": 0.97,
				"stiffness_scale": 0.90,
			}
		C_SEGMENT_COMPACT:
			return {
				"id": C_SEGMENT_COMPACT,
				"display_name": "C-Segment Compact Car",
				"segment": "C",
				"default_mass_kg": 1375.0,
				"representative_length_m": 4.38,
				"representative_width_m": 1.80,
				"scale_x": 1.08,
				"scale_y": 0.99,
				"scale_z": 1.05,
				"stiffness_scale": 1.10,
			}
		D_SEGMENT_MIDSIZE:
			return {
				"id": D_SEGMENT_MIDSIZE,
				"display_name": "D-Segment Midsize Car",
				"segment": "D",
				"default_mass_kg": 1575.0,
				"representative_length_m": 4.80,
				"representative_width_m": 1.86,
				"scale_x": 1.18,
				"scale_y": 1.01,
				"scale_z": 1.08,
				"stiffness_scale": 1.20,
			}
		J_SEGMENT_SUV:
			return {
				"id": J_SEGMENT_SUV,
				"display_name": "J-Segment SUV / Crossover",
				"segment": "J",
				"default_mass_kg": 1850.0,
				"representative_length_m": 4.86,
				"representative_width_m": 1.92,
				"scale_x": 1.20,
				"scale_y": 1.10,
				"scale_z": 1.12,
				"stiffness_scale": 1.25,
			}
		M_SEGMENT_MPV:
			return {
				"id": M_SEGMENT_MPV,
				"display_name": "M-Segment MPV / Minivan",
				"segment": "M",
				"default_mass_kg": 2050.0,
				"representative_length_m": 5.00,
				"representative_width_m": 1.95,
				"scale_x": 1.23,
				"scale_y": 1.16,
				"scale_z": 1.14,
				"stiffness_scale": 1.22,
			}
		_:
			return {
				"id": B_SEGMENT_HATCHBACK,
				"display_name": "B-Segment Small Hatchback",
				"segment": "B",
				"default_mass_kg": 1150.0,
				"representative_length_m": 4.07,
				"representative_width_m": 1.72,
				"scale_x": 1.0,
				"scale_y": 1.0,
				"scale_z": 1.0,
				"stiffness_scale": 1.0,
			}

static func display_name(preset_id: StringName) -> String:
	return String(data(preset_id).get("display_name", "B-Segment Small Hatchback"))

static func default_mass_kg(preset_id: StringName) -> float:
	return float(data(preset_id).get("default_mass_kg", 1150.0))
