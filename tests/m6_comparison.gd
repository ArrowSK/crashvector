# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	_test_speed_sweep(failures)
	_test_vehicle_class_sweep(failures)
	_test_recordings_are_independent(failures)
	_test_paint_palette(failures)

	if failures.is_empty():
		print("CrashVector M6 visual-comparison tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_speed_sweep(failures: Array[String]) -> void:
	var scenario := _short_wall_scenario()
	var results := ComparisonRunner.run_speed_sweep(scenario)
	if results.size() != 3:
		failures.append("M6 default speed sweep must return three comparison variants")
		return
	var expected_speeds: Array[float] = [50.0, 90.0, 140.0]
	var energies: Array[float] = []
	for i in range(results.size()):
		var result := results[i]
		if not String(result.get("error", "")).is_empty():
			failures.append("M6 speed sweep returned an error for variant %d" % i)
			continue
		var config := result.get("scenario") as ScenarioConfig
		var recording := result.get("recording") as ReplayRecording
		var analysis: Dictionary = result.get("analysis", {})
		if config == null or absf(config.car_speed_kmh - expected_speeds[i]) > 0.001:
			failures.append("M6 speed sweep changed the wrong primary speed")
		if recording == null or recording.frames.size() < 2:
			failures.append("M6 speed sweep did not create a replay recording")
		elif recording.marker_time(&"first_contact") < 0.0:
			failures.append("M6 speed sweep did not detect first contact")
		if analysis.is_empty():
			failures.append("M6 speed sweep did not create analysis")
		else:
			energies.append(float(analysis.get("initial_kinetic_energy_kj", 0.0)))
	if energies.size() == 3:
		var ratio := energies[2] / maxf(energies[0], 0.000001)
		if absf(ratio - 7.84) > 0.03:
			failures.append("M6 140/50 km/h kinetic-energy comparison lost the v² relationship")
		if not (energies[0] < energies[1] and energies[1] < energies[2]):
			failures.append("M6 speed-sweep kinetic energy is not monotonic")

func _test_vehicle_class_sweep(failures: Array[String]) -> void:
	var scenario := _short_wall_scenario()
	scenario.car_speed_kmh = 70.0
	var results := ComparisonRunner.run_vehicle_class_sweep(scenario)
	if results.size() != 3:
		failures.append("M6 default vehicle-class sweep must return B/C/D variants")
		return
	var expected_ids: Array[StringName] = [
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		PassengerCarCatalog.C_SEGMENT_COMPACT,
		PassengerCarCatalog.D_SEGMENT_MIDSIZE,
	]
	for i in range(results.size()):
		var result := results[i]
		if not String(result.get("error", "")).is_empty():
			failures.append("M6 vehicle-class sweep returned an error")
			continue
		var config := result.get("scenario") as ScenarioConfig
		if config == null:
			failures.append("M6 vehicle-class sweep lost scenario metadata")
			continue
		if config.car_preset_id != expected_ids[i]:
			failures.append("M6 vehicle-class sweep returned classes in the wrong order")
		if absf(config.car_mass_kg - PassengerCarCatalog.default_mass_kg(expected_ids[i])) > 0.001:
			failures.append("M6 vehicle-class sweep did not use the class default mass")

func _test_recordings_are_independent(failures: Array[String]) -> void:
	var results := ComparisonRunner.run_speed_sweep(_short_wall_scenario())
	if results.size() < 2:
		return
	var first := results[0].get("recording") as ReplayRecording
	var second := results[1].get("recording") as ReplayRecording
	if first == null or second == null:
		return
	if first == second:
		failures.append("M6 variants unexpectedly share the same replay object")
	var first_time := float(first.last_frame().get("time_s", -1.0))
	var second_time := float(second.last_frame().get("time_s", -1.0))
	if absf(first_time - 0.60) > 0.01 or absf(second_time - 0.60) > 0.01:
		failures.append("M6 offline sweep did not preserve the requested duration")

func _test_paint_palette(failures: Array[String]) -> void:
	var ids := CarPaintCatalog.ids()
	if ids.size() < 6:
		failures.append("M6 comparison should expose a useful car-paint palette")
	var seen: Array[Color] = []
	for id in ids:
		if not CarPaintCatalog.is_valid(id):
			failures.append("M6 paint catalog returned an invalid paint id")
		var color := CarPaintCatalog.color(id)
		if color.a < 0.85:
			failures.append("M6 car paint is too transparent for visual comparison")
		if seen.has(color):
			failures.append("M6 car paint palette contains duplicate colors")
		seen.append(color)

func _short_wall_scenario() -> ScenarioConfig:
	var scenario := ScenarioConfig.new()
	scenario.title = "M6 CI wall sweep"
	scenario.target_type = ScenarioConfig.TARGET_WALL
	scenario.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	scenario.car_mass_kg = 1150.0
	scenario.car_speed_kmh = 50.0
	scenario.car_position_m = Vector3(-3.2, 0.0, 0.0)
	scenario.car_heading_deg = 0.0
	scenario.target_position_m = Vector3(0.0, 0.0, 0.0)
	scenario.target_heading_deg = 0.0
	scenario.duration_s = 0.60
	scenario.solver_substeps = 6
	scenario.contact_friction = 0.55
	scenario.restitution = 0.03
	return scenario
