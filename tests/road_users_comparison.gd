# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const DT: float = 1.0 / 240.0
var FRONT_CONTACTS: PackedInt32Array = PackedInt32Array([
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 0),
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 1),
])

func _initialize() -> void:
	var failures: Array[String] = []
	_test_defaults_and_round_trip(failures)
	_test_bicycle_structure(failures)
	_test_pedestrian_stance(failures)
	_test_pedestrian_contact_trajectory(failures)
	_test_target_speed_matrix(failures)
	_test_class_speed_matrix(failures)
	_test_road_user_body_matrix(failures)
	if failures.is_empty():
		print("CrashVector road-user and comparison-matrix tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_defaults_and_round_trip(failures: Array[String]) -> void:
	if absf(RoadUserCatalog.default_mass_kg(RoadUserCatalog.PEDESTRIAN_ADULT) - 75.0) > 0.001:
		failures.append("Default adult pedestrian mass must remain 75 kg")
	if absf(RoadUserCatalog.pedestrian_height_m(RoadUserCatalog.PEDESTRIAN_ADULT) - 1.75) > 0.001:
		failures.append("Default adult pedestrian height must remain 1.75 m")
	if absf(RoadUserCatalog.default_mass_kg(RoadUserCatalog.BICYCLE_CITY) - 16.0) > 0.001:
		failures.append("Default city-bicycle mass must remain 16 kg")
	var scenario := ScenarioConfig.new()
	scenario.apply_target_defaults(ScenarioConfig.TARGET_PEDESTRIAN)
	if scenario.target_preset_id != RoadUserCatalog.PEDESTRIAN_ADULT or absf(scenario.target_mass_kg - 75.0) > 0.001:
		failures.append("Selecting Pedestrian must provide a ready-to-run default adult")
	var loaded := ScenarioConfig.from_json(scenario.to_json(false))
	if loaded == null or loaded.target_type != ScenarioConfig.TARGET_PEDESTRIAN or loaded.target_preset_id != RoadUserCatalog.PEDESTRIAN_ADULT:
		failures.append("Scenario round trip lost the pedestrian preset")

func _test_bicycle_structure(failures: Array[String]) -> void:
	var model := BicycleBuilder.build(RoadUserCatalog.BICYCLE_CITY, 16.0, 20.0, Vector3.ZERO)
	if model.nodes.size() != 16:
		failures.append("Bicycle structural proxy must contain 16 nodes")
	if absf(model.total_mass_kg() - 16.0) > 0.001:
		failures.append("Bicycle builder did not preserve configured mass")
	if BicycleBuilder.front_contact_nodes().size() != 2 or BicycleBuilder.rear_contact_nodes().size() != 2:
		failures.append("Bicycle contact-node pairs changed unexpectedly")
	if not _model_is_finite(model):
		failures.append("Bicycle builder produced non-finite state")

func _test_pedestrian_stance(failures: Array[String]) -> void:
	var model := PedestrianBuilder.build(RoadUserCatalog.PEDESTRIAN_ADULT, 75.0, Vector3.ZERO)
	if absf(model.total_mass_kg() - 75.0) > 0.001:
		failures.append("Pedestrian builder did not preserve configured mass")
	if PedestrianBuilder.stance_released(model):
		failures.append("Pedestrian stance should begin supported before impact")
	PedestrianBuilder.release_stance(model)
	if not PedestrianBuilder.stance_released(model):
		failures.append("Pedestrian stance did not release after impact")
	for index in PedestrianBuilder.stance_nodes():
		if model.nodes[index].inverse_mass <= 0.0:
			failures.append("Released pedestrian foot retained zero inverse mass")

func _test_pedestrian_contact_trajectory(failures: Array[String]) -> void:
	var car := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK, 1150.0, 40.0, 1000.0, Vector3(-3.2, 0.0, 0.0)
	)
	var person := PedestrianBuilder.build(RoadUserCatalog.PEDESTRIAN_ADULT, 75.0, Vector3.ZERO)
	var simulation := VehiclePairSimulation.new()
	simulation.configure(car, FRONT_CONTACTS, person, PedestrianBuilder.contact_nodes(), Vector3.RIGHT, 0.55, 0.03)
	for _step in range(150):
		simulation.step(DT, 8)
		if simulation.contact.contact_events > 0 and not PedestrianBuilder.stance_released(person):
			PedestrianBuilder.release_stance(person)
	if simulation.contact.contact_events <= 0:
		failures.append("Car/pedestrian proxy scenario produced no contact")
	if not PedestrianBuilder.stance_released(person):
		failures.append("Pedestrian stance did not release after car contact")
	if person.average_velocity_ms().x <= 0.05:
		failures.append("Pedestrian proxy gained no forward trajectory after contact")
	if not _model_is_finite(car) or not _model_is_finite(person):
		failures.append("Car/pedestrian proxy scenario produced non-finite state")

func _test_target_speed_matrix(failures: Array[String]) -> void:
	var scenario := _short_wall_scenario()
	var variants: Array[StringName] = [ScenarioConfig.TARGET_PEDESTRIAN, ScenarioConfig.TARGET_BICYCLE, ScenarioConfig.TARGET_WALL]
	var speeds: Array[float] = [30.0, 40.0]
	var results := ComparisonRunner.run_matrix(scenario, ComparisonRunner.MATRIX_TARGET_TYPES, variants, speeds)
	if results.size() != 6:
		failures.append("Target-type × speed matrix must return every selected combination")
		return
	for result in results:
		if not String(result.get("error", "")).is_empty():
			failures.append("Target-type × speed matrix returned an invalid combination: %s" % String(result.get("error", "")))

func _test_class_speed_matrix(failures: Array[String]) -> void:
	var scenario := _short_wall_scenario()
	var variants: Array[StringName] = [PassengerCarCatalog.A_SEGMENT_CITY, PassengerCarCatalog.J_SEGMENT_SUV]
	var speeds: Array[float] = [130.0, 140.0]
	var results := ComparisonRunner.run_matrix(scenario, ComparisonRunner.MATRIX_CAR_CLASSES, variants, speeds)
	if results.size() != 4:
		failures.append("Car-class × speed matrix must return 2 × 2 combinations")
		return
	var energy_by_class: Dictionary = {}
	for result in results:
		if not String(result.get("error", "")).is_empty():
			failures.append("130/140 km/h class matrix returned an error")
			continue
		var config := result.get("scenario") as ScenarioConfig
		var analysis: Dictionary = result.get("analysis", {})
		if config == null:
			continue
		var key := String(config.car_preset_id)
		if not energy_by_class.has(key):
			energy_by_class[key] = {}
		energy_by_class[key][int(round(config.car_speed_kmh))] = float(analysis.get("initial_kinetic_energy_kj", 0.0))
	for key in energy_by_class.keys():
		var values: Dictionary = energy_by_class[key]
		if not values.has(130) or not values.has(140):
			failures.append("130/140 matrix lost a requested speed")
			continue
		var ratio := float(values[140]) / maxf(float(values[130]), 0.000001)
		var expected := (140.0 * 140.0) / (130.0 * 130.0)
		if absf(ratio - expected) > 0.01:
			failures.append("130/140 matrix lost the kinetic-energy v² relationship")

func _test_road_user_body_matrix(failures: Array[String]) -> void:
	var scenario := _short_wall_scenario()
	var variants: Array[StringName] = [RoadUserCatalog.PEDESTRIAN_ADULT, RoadUserCatalog.BICYCLE_CITY]
	var speeds: Array[float] = [30.0]
	var results := ComparisonRunner.run_matrix(scenario, ComparisonRunner.MATRIX_BODY_PRESETS, variants, speeds)
	if results.size() != 2:
		failures.append("Road-user body/type matrix must allow pedestrian and bicycle presets in the same run")
		return
	var seen_pedestrian := false
	var seen_bicycle := false
	for result in results:
		if not String(result.get("error", "")).is_empty():
			failures.append("Road-user body/type matrix returned an error")
			continue
		var config := result.get("scenario") as ScenarioConfig
		if config != null and config.target_type == ScenarioConfig.TARGET_PEDESTRIAN:
			seen_pedestrian = true
		elif config != null and config.target_type == ScenarioConfig.TARGET_BICYCLE:
			seen_bicycle = true
	if not seen_pedestrian or not seen_bicycle:
		failures.append("Road-user body/type matrix did not preserve mixed target types")

func _short_wall_scenario() -> ScenarioConfig:
	var scenario := ScenarioConfig.new()
	scenario.title = "Road-user matrix CI"
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

func _model_is_finite(model: StructuralModel) -> bool:
	for node in model.nodes:
		if not (
			is_finite(node.position_m.x)
			and is_finite(node.position_m.y)
			and is_finite(node.position_m.z)
			and is_finite(node.velocity_ms.x)
			and is_finite(node.velocity_ms.y)
			and is_finite(node.velocity_ms.z)
		):
			return false
	return true
