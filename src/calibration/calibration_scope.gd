# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CalibrationScope
extends RefCounted

const DIRECT: StringName = &"reference_correlated"
const NEAR: StringName = &"near_reference"
const CLASS_SCALED: StringName = &"class_scaled"
const EXTRAPOLATED: StringName = &"extrapolated"

static func classify(config: ScenarioConfig, reference: CalibrationReference = null) -> Dictionary:
	if reference == null:
		reference = CalibrationReference.load_default()
	if reference == null:
		return _result(EXTRAPOLATED, "No calibration reference is available.")
	var scope := reference.scope()
	var is_wall := config.target_type == ScenarioConfig.TARGET_WALL
	var heading_ok := absf(wrapf(config.car_heading_deg, -180.0, 180.0)) <= 5.0
	var direct_class := StringName(String(scope.get("directly_correlated_class_id", "d_segment_midsize")))
	var speed_min := float(scope.get("directly_correlated_speed_min_kmh", 50.0))
	var speed_max := float(scope.get("directly_correlated_speed_max_kmh", 60.0))
	var mass_min := float(scope.get("directly_correlated_mass_min_kg", 1500.0))
	var mass_max := float(scope.get("directly_correlated_mass_max_kg", 1800.0))
	if is_wall and heading_ok and config.car_preset_id == direct_class and config.car_speed_kmh >= speed_min and config.car_speed_kmh <= speed_max and config.car_mass_kg >= mass_min and config.car_mass_kg <= mass_max:
		return _result(DIRECT, "Within the limited NHTSA full-frontal midsize correlation envelope.")
	if is_wall and heading_ok and config.car_preset_id == direct_class and config.car_speed_kmh >= 40.0 and config.car_speed_kmh <= 70.0 and config.car_mass_kg >= 1400.0 and config.car_mass_kg <= 1900.0:
		return _result(NEAR, "Near the reference condition, but outside the directly correlated speed or mass corridor.")
	if is_wall and heading_ok and config.car_speed_kmh >= 35.0 and config.car_speed_kmh <= 70.0:
		return _result(CLASS_SCALED, "Uses CrashVector's generic class scaling; this vehicle class has not been directly correlated to a published crash test.")
	return _result(EXTRAPOLATED, "Outside the current correlation envelope. Treat deformation and crash-pulse results as qualitative/extrapolated.")

static func display_name(status: StringName) -> String:
	match status:
		DIRECT: return "Reference-correlated"
		NEAR: return "Near reference"
		CLASS_SCALED: return "Class-scaled"
		_: return "Extrapolated"

static func _result(status: StringName, detail: String) -> Dictionary:
	return {"status": status, "label": display_name(status), "detail": detail}
