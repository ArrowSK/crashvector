# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	_test_reference_metadata(failures)
	_test_scope_labels(failures)
	_test_reference_correlation(failures)
	_test_expanded_vehicle_classes(failures)
	_test_new_target_validation(failures)
	_test_custom_wall_speed_comparison(failures)
	if failures.is_empty():
		print("CrashVector M8 calibration and expansion tests passed.")
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
	var source_corridors := reference.source_corridors()
	if not source_corridors.has("pulse_duration_s"):
		failures.append("M8 must retain the published-pulse correlation corridor")
	if source_corridors.has("delta_v_kmh"):
		failures.append("Delta-v must not be represented as a source-derived NHTSA corridor")
	var regression_corridors := reference.regression_corridors()
	if not regression_corridors.has("delta_v_kmh"):
		failures.append("M8 must retain a clearly labelled project delta-v regression guardrail")

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
	if not bool(assessment.get("source_correlation_passed", false)):
		failures.append("M8 reference pulse left the source-correlation corridor: %s" % JSON.stringify(metrics))
	if not bool(assessment.get("project_regression_passed", false)):
		failures.append("M8 reference left a project numerical regression guardrail: %s" % JSON.stringify(metrics))
	if not bool(assessment.get("passed", false)):
		failures.append("M8 reference assessment did not pass overall")
	var checks: Array = assessment.get("checks", [])
	if checks.size() != 4:
		failures.append("M8 must gate pulse duration plus three project numerical regressions")
	var source_count := 0
	var regression_count := 0
	for check in checks:
		if StringName(String(check.get("category", ""))) == &"source_correlation":
			source_count += 1
		else:
			regression_count += 1
	if source_count != 1 or regression_count != 3:
		failures.append("M8 source evidence and project regression categories were mixed")

func _test_expanded_vehicle_classes(failures: Array[String]) -> void:
	var ids := PassengerCarCatalog.preset_ids()
	for id in [PassengerCarCatalog.A_SEGMENT_CITY, PassengerCarCatalog.J_SEGMENT_SUV, PassengerCarCatalog.M_SEGMENT_MPV]:
		if not ids.has(id):
			failures.append("Expanded passenger-car catalog is missing %s" % id)
		continue
		var model := PassengerCarBuilder.build(id, -1.0, 50.0, 100.0)
		if model.nodes.size() != 28 or model.total_mass_kg() <= 0.0:
			failures.append("Expanded passenger-car preset %s did not build correctly" % id)

func _test_new_target_validation(failures: Array[String]) -> void:
	var lorry := ScenarioConfig.new()
	lorry.target_type = ScenarioConfig.TARGET_LORRY
	lorry.target_mass_kg = 12000.0
	lorry.target_speed_kmh = 0.0
	lorry.target_position_m = Vector3(3.0, 0.0, 0.0)
	if not lorry.validation_errors().is_empty():
		failures.append("Default rigid-lorry scenario should pass preflight: %s" % "; ".join(lorry.validation_errors()))

	var motorcycle := ScenarioConfig.new()
	motorcycle.target_type = ScenarioConfig.TARGET_MOTORCYCLE
	motorcycle.target_mass_kg = 220.0
	motorcycle.target_speed_kmh = 0.0
	motorcycle.target_position_m = Vector3(3.0, 0.0, 0.0)
	if not motorcycle.validation_errors().is_empty():
		failures.append("Default riderless-motorcycle scenario should pass preflight: %s" % "; ".join(motorcycle.validation_errors()))

func _test_custom_wall_speed_comparison(failures: Array[String]) -> void:
	var config := ScenarioConfig.new()
	config.title = "130 vs 140 wall demonstration"
	config.target_type = ScenarioConfig.TARGET_WALL
	config.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-3.2, 0.0, 0.0)
	config.target_position_m = Vector3.ZERO
	config.duration_s = 0.8
	config.solver_substeps = 8
	var results := ComparisonRunner.run_speed_sweep(config, [130.0, 140.0])
	if results.size() != 2:
		failures.append("Custom speed comparison must support exactly two requested speeds")
		return
	for result in results:
		if not String(result.get("error", "")).is_empty():
			failures.append("Custom rigid-wall speed comparison failed: %s" % result.get("error", ""))
			return
	var analysis_130: Dictionary = results[0].get("analysis", {})
	var analysis_140: Dictionary = results[1].get("analysis", {})
	var energy_130 := float(analysis_130.get("initial_kinetic_energy_kj", 0.0))
	var energy_140 := float(analysis_140.get("initial_kinetic_energy_kj", 0.0))
	if energy_140 <= energy_130:
		failures.append("140 km/h comparison must have more initial kinetic energy than 130 km/h")
	var expected_ratio := (140.0 * 140.0) / (130.0 * 130.0)
	if absf((energy_140 / maxf(energy_130, 0.0001)) - expected_ratio) > 0.002:
		failures.append("Custom speed comparison lost kinetic-energy v-squared behaviour")
