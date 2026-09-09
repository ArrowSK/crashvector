# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ContactFidelityScenarioCatalog
extends RefCounted

# M19 diagnostic scenarios. These are generic CrashVector observation cases,
# not replicas of the NHTSA/IIHS protocol references stored in calibration/.
# Their purpose is to compare how the same production rigid-body stack reports
# contact manifolds as alignment changes before any solver/geometry tuning.

const FULL_FRONTAL := &"full_frontal_pair"
const OFFSET_FRONTAL := &"offset_frontal_pair"
const OBLIQUE_FRONTAL := &"oblique_frontal_pair"
const BROADSIDE := &"broadside_pair"

static func ids() -> Array[StringName]:
	return [FULL_FRONTAL, OFFSET_FRONTAL, OBLIQUE_FRONTAL, BROADSIDE]

static func display_name(id: StringName) -> String:
	match id:
		FULL_FRONTAL:
			return "Aligned head-on passenger cars"
		OFFSET_FRONTAL:
			return "Generic offset head-on passenger cars"
		OBLIQUE_FRONTAL:
			return "Generic 15° oblique passenger-car pair"
		BROADSIDE:
			return "Perpendicular passenger-car impact"
		_:
			return "Unknown contact-fidelity case"

static func make_config(id: StringName) -> ScenarioConfig:
	var config := ScenarioConfig.new()
	config.title = "M19 %s" % display_name(id)
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	config.target_car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.target_mass_kg = PassengerCarCatalog.default_mass_kg(config.target_car_preset_id)
	config.duration_s = 1.8
	config.solver_substeps = 12
	config.contact_friction = 0.55
	config.restitution = 0.03

	match id:
		FULL_FRONTAL:
			config.car_position_m = Vector3(-7.0, 0.0, 0.0)
			config.car_heading_deg = 0.0
			config.car_speed_kmh = 50.0
			config.target_position_m = Vector3(7.0, 0.0, 0.0)
			config.target_heading_deg = 180.0
			config.target_speed_kmh = 50.0
		OFFSET_FRONTAL:
			config.car_position_m = Vector3(-7.0, 0.0, 0.0)
			config.car_heading_deg = 0.0
			config.car_speed_kmh = 50.0
			config.target_position_m = Vector3(7.0, 0.0, 0.72)
			config.target_heading_deg = 180.0
			config.target_speed_kmh = 50.0
		OBLIQUE_FRONTAL:
			config.car_position_m = Vector3(-7.0, 0.0, 0.0)
			config.car_heading_deg = 0.0
			config.car_speed_kmh = 55.0
			# The initial offset accounts for the lateral component of the target's
			# 15° approach, so the two configured trajectories intersect.
			config.target_position_m = Vector3(7.0, 0.0, 1.65)
			config.target_heading_deg = 165.0
			config.target_speed_kmh = 45.0
		BROADSIDE:
			config.car_position_m = Vector3.ZERO
			config.car_heading_deg = 0.0
			config.car_speed_kmh = 0.0
			config.target_position_m = Vector3(0.0, 0.0, -8.0)
			config.target_heading_deg = -90.0
			config.target_speed_kmh = 55.0
		_:
			config.car_position_m = Vector3(-7.0, 0.0, 0.0)
			config.car_heading_deg = 0.0
			config.car_speed_kmh = 50.0
			config.target_position_m = Vector3(7.0, 0.0, 0.0)
			config.target_heading_deg = 180.0
			config.target_speed_kmh = 50.0
	return config

static func metadata(id: StringName) -> Dictionary:
	var config := make_config(id)
	return {
		"id": String(id),
		"label": display_name(id),
		"diagnostic_role": "production_contact_observation_only",
		"external_protocol_replica": false,
		"heading_delta_deg": config.heading_delta_deg(),
		"lateral_offset_m": absf(config.target_position_m.z - config.car_position_m.z),
		"primary_speed_kmh": config.car_speed_kmh,
		"target_speed_kmh": config.target_speed_kmh,
	}
