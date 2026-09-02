# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CarPaintCatalog
extends RefCounted

const CRIMSON: StringName = &"crimson"
const ELECTRIC_BLUE: StringName = &"electric_blue"
const SUNSET_ORANGE: StringName = &"sunset_orange"
const PEARL_WHITE: StringName = &"pearl_white"
const SILVER: StringName = &"silver"
const GRAPHITE: StringName = &"graphite"
const RACING_GREEN: StringName = &"racing_green"
const VIOLET: StringName = &"violet"

static func ids() -> Array[StringName]:
	return [CRIMSON, ELECTRIC_BLUE, SUNSET_ORANGE, PEARL_WHITE, SILVER, GRAPHITE, RACING_GREEN, VIOLET]

static func display_name(id: StringName) -> String:
	match id:
		CRIMSON: return "Crimson red"
		ELECTRIC_BLUE: return "Electric blue"
		SUNSET_ORANGE: return "Sunset orange"
		PEARL_WHITE: return "Pearl white"
		SILVER: return "Silver"
		GRAPHITE: return "Graphite"
		RACING_GREEN: return "Deep green"
		VIOLET: return "Violet"
		_: return "Electric blue"

static func color(id: StringName) -> Color:
	match id:
		CRIMSON: return Color(0.72, 0.045, 0.07, 0.94)
		ELECTRIC_BLUE: return Color(0.035, 0.28, 0.82, 0.94)
		SUNSET_ORANGE: return Color(0.95, 0.24, 0.035, 0.94)
		PEARL_WHITE: return Color(0.90, 0.92, 0.95, 0.94)
		SILVER: return Color(0.58, 0.62, 0.68, 0.94)
		GRAPHITE: return Color(0.10, 0.12, 0.15, 0.94)
		RACING_GREEN: return Color(0.025, 0.31, 0.17, 0.94)
		VIOLET: return Color(0.40, 0.12, 0.68, 0.94)
		_: return Color(0.035, 0.28, 0.82, 0.94)

static func is_valid(id: StringName) -> bool:
	return ids().has(id)
