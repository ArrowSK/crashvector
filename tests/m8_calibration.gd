# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	_test_reference_metadata(failures)
	_test_scope_labels(failures)
	_test_reference_correlation(failures)
	if failures.is_empty():
		print("CrashVector M8 calibration tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_reference_metadata(failures: Array[String]) -> void:
	var reference := CalibrationReference.load_default()
	if reference == null:
		failures.append("M8 could not load the default calibration reference")
		return
	if reference.id() != "nhtsa_ncap_full_frontal_midsize_56kph":
		failures.append("M8 loaded the wrong default reference")
	var source := reference.source()
	if String(source.get("report_number", "")) != "DOT HS 812 237":
		failures.append("M8 reference lost its NHTSA report identifier")
	if String(source.get("laboratory_test_id", "")) != "7078":
		failures.append("M8 reference lost laboratory test 7078")
	var vehicle := reference.reference_vehicle()
	if absf(float(vehicle.get("test_mass_kg", 0.0)) - 1661.0) > 0.001:
		failures.append("M8 reference test mass changed unexpectedly")
	var condition := reference.condition()
	if absf(float(condition.get("impact_speed_kmh", 0.0)) - 56.5) > 0.001:
		failures.append("M8 reference impact speed changed unexpectedly")
	var observations := reference.observations()
	if absf(float(observations.get("crash_pulse_duration_s_approx", 0.0)) - 0.120) > 0.0001:
		failures.append("M8 reference lost the published approximately 120 ms pulse observation")

func _test_scope_labels(failures: Array[String]) -> void:
	var reference := CalibrationReference.load_default()
	if reference == null:
		return
	var direct := reference.make_scenario()
	var direct_scope := CalibrationScope.classify(direct, reference)
	if direct_scope.get("status") != CalibrationScope.DIRECT:
		failures.append("M8 exact reference scenario is not labelled reference-correlated")

	var high_speed := ScenarioConfig.from_dictionary(direct.to_dictionary())
	high_speed.car_speed_kmh = 140.0
	if CalibrationScope.classify(high_speed, reference).get("status") != CalibrationScope.EXTRAPOLATED:
		failures.append("M8 140 km/h rigid-wall scenario must be labelled extrapolated")

	var scaled := ScenarioConfig.from_dictionary(direct.to_dictionary())
	scaled.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	scaled.car_mass_kg = PassengerCarCatalog.default_mass_kg(scaled.car_preset_id)
	if CalibrationScope.classify(scaled, reference).get("status") != CalibrationScope.CLASS_SCALED:
		failures.append("M8 B-segment wall scenario must be labelled class-scaled, not directly correlated")

	var car_car := ScenarioConfig.from_dictionary(direct.to_dictionary())
	car_car.target_type = ScenarioConfig.TARGET_PASSENGER_CAR
	car_car.target_position_m = Vector3(3.0, 0.0, 0.0)
	if CalibrationScope.classify(car_car, reference).get("status") != CalibrationScope.EXTRAPOLATED:
		failures.append("M8 car-vs-car scenario must remain explicitly extrapolated")

func _test_reference_correlation(failures: Array[String]) -> void:
	var assessment := CalibrationRunner.run_default_reference()
	if not bool(assessment.get("ok", false)):
		failures.append("M8 reference correlation could not run: %s" % String(assessment.get("message", "unknown error")))
		return
	var metrics: Dictionary = assessment.get("metrics", {})
	for key in ["pulse_duration_s", "delta_v_kmh", "peak_deceleration_g", "front_crush_mm", "safety_cell_proxy_mm", "energy_balance_relative_error"]:
		if not is_finite(float(metrics.get(key, NAN))):
			failures.append("M8 calibration metric became non-finite: %s" % key)
	if not bool(assessment.get("passed", false)):
		failures.append("M8 reference result left its stored correlation corridors: %s" % JSON.stringify(metrics))
	var checks: Array = assessment.get("checks", [])
	if checks.size() != 4:
		failures.append("M8 must gate pulse duration, delta-v, safety-cell proxy, and energy balance")
