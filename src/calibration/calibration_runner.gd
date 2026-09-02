# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CalibrationRunner
extends RefCounted

static func run_default_reference() -> Dictionary:
	var reference := CalibrationReference.load_default()
	if reference == null:
		return {"ok": false, "message": "Calibration reference could not be loaded."}
	var config := reference.make_scenario()
	var results := ComparisonRunner.run_speed_sweep(config, [config.car_speed_kmh])
	if results.is_empty():
		return {"ok": false, "message": "Reference simulation produced no result.", "reference": reference}
	var result := results[0]
	var error_text := String(result.get("error", ""))
	if not error_text.is_empty():
		return {"ok": false, "message": error_text, "reference": reference, "result": result}
	return assess_result(reference, result)

static func assess_result(reference: CalibrationReference, result: Dictionary) -> Dictionary:
	var metrics := CalibrationMetrics.from_result(result)
	if metrics.is_empty():
		return {"ok": false, "message": "Calibration metrics could not be computed.", "reference": reference, "result": result}
	var source_corridors := reference.source_corridors()
	var regression_corridors := reference.regression_corridors()
	var checks: Array[Dictionary] = []
	checks.append(_range_check(
		"Crash-pulse duration",
		float(metrics.get("pulse_duration_s", -1.0)),
		source_corridors.get("pulse_duration_s", {}),
		"s",
		&"source_correlation"
	))
	checks.append(_range_check(
		"Longitudinal Δv numerical guardrail",
		float(metrics.get("delta_v_kmh", 0.0)),
		regression_corridors.get("delta_v_kmh", {}),
		"km/h",
		&"project_regression"
	))
	checks.append(_range_check(
		"Safety-cell deformation proxy",
		float(metrics.get("safety_cell_proxy_mm", 0.0)),
		regression_corridors.get("safety_cell_proxy_mm", {}),
		"mm",
		&"project_regression"
	))
	var energy_limit := float(regression_corridors.get("energy_balance_relative_error_max", 1.0))
	var energy_value := float(metrics.get("energy_balance_relative_error", 0.0))
	checks.append({
		"name": "Energy-balance relative error",
		"value": energy_value,
		"unit": "ratio",
		"passed": is_finite(energy_value) and energy_value <= energy_limit,
		"corridor": {"min": 0.0, "max": energy_limit},
		"basis": "CrashVector numerical-regression limit; not an external NHTSA acceptance criterion.",
		"category": &"project_regression",
	})
	var source_passed := true
	var regression_passed := true
	for check in checks:
		var category := StringName(String(check.get("category", "project_regression")))
		if category == &"source_correlation" and not bool(check.get("passed", false)):
			source_passed = false
		elif category == &"project_regression" and not bool(check.get("passed", false)):
			regression_passed = false
	var passed := source_passed and regression_passed
	return {
		"ok": true,
		"passed": passed,
		"source_correlation_passed": source_passed,
		"project_regression_passed": regression_passed,
		"status": "correlated" if passed else "outside_corridor",
		"message": "Source correlation and project regression checks passed." if passed else "One or more source-correlation or project-regression checks are outside their stored corridor.",
		"reference": reference,
		"result": result,
		"metrics": metrics,
		"checks": checks,
	}

static func _range_check(
	name: String,
	value: float,
	corridor: Variant,
	unit: String,
	category: StringName
) -> Dictionary:
	var data: Dictionary = corridor if corridor is Dictionary else {}
	var minimum := float(data.get("min", -INF))
	var maximum := float(data.get("max", INF))
	return {
		"name": name,
		"value": value,
		"unit": unit,
		"passed": is_finite(value) and value >= minimum and value <= maximum,
		"corridor": {"min": minimum, "max": maximum},
		"basis": String(data.get("basis", "")),
		"category": category,
	}
