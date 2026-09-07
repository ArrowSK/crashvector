# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name KenneyVehicleAssetCatalog
extends RefCounted

# CrashVector vendors Kenney Car Kit 3.1 as a pinned third-party source tree.
# These paths deliberately stay presentation-only: vehicle mass, dimensions,
# collision geometry and deformation continue to come from CrashVector's
# production structural/rigid-body models.
const ROOT := "res://third_party/kenney_car_kit/Models/GLB format/"
const WHEEL_DEFAULT := ROOT + "wheel-default.glb"

static func passenger_car_body_path(preset_id: StringName) -> String:
	match preset_id:
		PassengerCarCatalog.A_SEGMENT_CITY:
			return ROOT + "hatchback-sports.glb"
		PassengerCarCatalog.B_SEGMENT_HATCHBACK:
			return ROOT + "sedan-sports.glb"
		PassengerCarCatalog.C_SEGMENT_COMPACT:
			return ROOT + "sedan.glb"
		PassengerCarCatalog.D_SEGMENT_MIDSIZE:
			return ROOT + "taxi.glb"
		PassengerCarCatalog.J_SEGMENT_SUV:
			return ROOT + "suv.glb"
		PassengerCarCatalog.M_SEGMENT_MPV:
			return ROOT + "van.glb"
		_:
			return ROOT + "hatchback-sports.glb"

static func passenger_car_mapping() -> Dictionary:
	var result := {}
	for preset_id in PassengerCarCatalog.preset_ids():
		result[preset_id] = passenger_car_body_path(preset_id)
	return result

static func required_passenger_car_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for preset_id in PassengerCarCatalog.preset_ids():
		var path := passenger_car_body_path(preset_id)
		if not paths.has(path):
			paths.append(path)
	paths.append(WHEEL_DEFAULT)
	return paths

static func assets_available() -> bool:
	for path in required_passenger_car_paths():
		if not ResourceLoader.exists(path):
			return false
	return true
