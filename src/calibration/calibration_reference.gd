# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CalibrationReference
extends RefCounted

const DEFAULT_PATH := "res://calibration/references/nhtsa_ncap_full_frontal_midsize_56kph.json"

var data: Dictionary = {}

static func load_default() -> CalibrationReference:
	return load_from_path(DEFAULT_PATH)

static func load_from_path(path: String) -> CalibrationReference:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return null
	var reference := CalibrationReference.new()
	reference.data = parsed
	return reference

func id() -> String:
	return String(data.get("id", ""))

func title() -> String:
	return String(data.get("title", "Calibration reference"))

func source() -> Dictionary:
	return data.get("source", {})

func reference_vehicle() -> Dictionary:
	return data.get("reference_vehicle", {})

func condition() -> Dictionary:
	return data.get("test_condition", {})

func observations() -> Dictionary:
	return data.get("published_observations", {})

func corridors() -> Dictionary:
	return data.get("crashvector_correlation_corridors", {})

func scope() -> Dictionary:
	return data.get("scope", {})

func make_scenario() -> ScenarioConfig:
	var config := ScenarioConfig.new()
	config.title = "M8 NHTSA reference correlation"
	config.target_type = ScenarioConfig.TARGET_WALL
	config.car_preset_id = PassengerCarCatalog.D_SEGMENT_MIDSIZE
	config.car_mass_kg = float(reference_vehicle().get("test_mass_kg", 1661.0))
	config.car_speed_kmh = float(condition().get("impact_speed_kmh", 56.5))
	config.car_position_m = Vector3(-3.2, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.target_position_m = Vector3(0.0, 0.0, 0.0)
	config.target_heading_deg = 0.0
	config.duration_s = 0.8
	config.solver_substeps = 8
	config.contact_friction = 0.55
	config.restitution = 0.03
	return config
