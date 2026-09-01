# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name PassengerCarCatalog
extends RefCounted

const B_SEGMENT_HATCHBACK: StringName = &"b_segment_hatchback"
const C_SEGMENT_COMPACT: StringName = &"c_segment_compact"
const D_SEGMENT_MIDSIZE: StringName = &"d_segment_midsize"

static func preset_ids() -> Array[StringName]:
	return [B_SEGMENT_HATCHBACK, C_SEGMENT_COMPACT, D_SEGMENT_MIDSIZE]

static func data(preset_id: StringName) -> Dictionary:
	match preset_id:
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
