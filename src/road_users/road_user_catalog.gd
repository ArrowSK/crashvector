# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RoadUserCatalog
extends RefCounted

const PEDESTRIAN_ADULT: StringName = &"pedestrian_adult"
const PEDESTRIAN_CHILD: StringName = &"pedestrian_child"
const PEDESTRIAN_TALL_ADULT: StringName = &"pedestrian_tall_adult"

const BICYCLE_CITY: StringName = &"bicycle_city"
const BICYCLE_ROAD: StringName = &"bicycle_road"
const BICYCLE_EBIKE: StringName = &"bicycle_ebike"

# M22 cyclist targets use the existing bicycle archetypes plus one generic adult
# rider. The rider mass is a default scenario assumption, not a biomechanical
# body model; users may override the combined cyclist+bicycle mass.
const DEFAULT_CYCLIST_RIDER_MASS_KG: float = 75.0
const MIN_CYCLIST_RIDER_MASS_KG: float = 35.0

static func pedestrian_ids() -> Array[StringName]:
	return [PEDESTRIAN_ADULT, PEDESTRIAN_CHILD, PEDESTRIAN_TALL_ADULT]

static func bicycle_ids() -> Array[StringName]:
	return [BICYCLE_CITY, BICYCLE_ROAD, BICYCLE_EBIKE]

static func pedestrian_data(id: StringName) -> Dictionary:
	match id:
		PEDESTRIAN_CHILD:
			return {"id": id, "display_name": "Child-sized pedestrian", "default_mass_kg": 32.0, "height_m": 1.35}
		PEDESTRIAN_TALL_ADULT:
			return {"id": id, "display_name": "Tall adult", "default_mass_kg": 90.0, "height_m": 1.90}
		_:
			return {"id": PEDESTRIAN_ADULT, "display_name": "Adult (default)", "default_mass_kg": 75.0, "height_m": 1.75}

static func bicycle_data(id: StringName) -> Dictionary:
	match id:
		BICYCLE_ROAD:
			return {"id": id, "display_name": "Road bicycle", "default_mass_kg": 9.0}
		BICYCLE_EBIKE:
			return {"id": id, "display_name": "E-bike", "default_mass_kg": 24.0}
		_:
			return {"id": BICYCLE_CITY, "display_name": "City bicycle (default)", "default_mass_kg": 16.0}

static func is_pedestrian_id(id: StringName) -> bool:
	return pedestrian_ids().has(id)

static func is_bicycle_id(id: StringName) -> bool:
	return bicycle_ids().has(id)

static func display_name(id: StringName) -> String:
	if is_pedestrian_id(id):
		return String(pedestrian_data(id).get("display_name", "Adult (default)"))
	if is_bicycle_id(id):
		return String(bicycle_data(id).get("display_name", "City bicycle (default)"))
	return "Default"

static func default_mass_kg(id: StringName) -> float:
	if is_pedestrian_id(id):
		return float(pedestrian_data(id).get("default_mass_kg", 75.0))
	if is_bicycle_id(id):
		return float(bicycle_data(id).get("default_mass_kg", 16.0))
	return 0.0

static func cyclist_default_mass_kg(bicycle_id: StringName) -> float:
	return default_mass_kg(bicycle_id) + DEFAULT_CYCLIST_RIDER_MASS_KG

static func cyclist_minimum_mass_kg(bicycle_id: StringName) -> float:
	return cyclist_bicycle_mass_kg(bicycle_id) + MIN_CYCLIST_RIDER_MASS_KG

static func cyclist_bicycle_mass_kg(bicycle_id: StringName) -> float:
	return default_mass_kg(bicycle_id)

static func cyclist_rider_mass_kg(combined_mass_kg: float, bicycle_id: StringName) -> float:
	# Scenario validation enforces the minimum rider share. Do not silently
	# inflate the returned value here: the physical articulated-body mass must
	# continue to add up to the user's configured combined target mass.
	return maxf(combined_mass_kg - cyclist_bicycle_mass_kg(bicycle_id), 0.0)

static func pedestrian_height_m(id: StringName) -> float:
	return float(pedestrian_data(id).get("height_m", 1.75))
