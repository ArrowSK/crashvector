# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const DT: float = 1.0 / 240.0
var FRONT_CONTACTS: PackedInt32Array = PackedInt32Array([
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 0),
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 1),
])
var REAR_CONTACTS: PackedInt32Array = PackedInt32Array([
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.REAR_STATION, 0),
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.REAR_STATION, 1),
])

func _initialize() -> void:
	var failures: Array[String] = []
	_test_scenario_round_trip(failures)
	_test_scenario_store(failures)
	_test_preflight_rules(failures)
	_test_heading_transform(failures)
	_test_static_obstacle_impact(failures)
	_test_car_vs_car_rear_impact(failures)
	_test_car_vs_car_head_on(failures)

	if failures.is_empty():
		print("CrashVector M4 scenario-editor tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_scenario_round_trip(failures: Array[String]) -> void:
	var source := ScenarioConfig.new()
	source.title = "M4 car versus car round trip"
	source.target_type = ScenarioConfig.TARGET_PASSENGER_CAR
	source.car_preset_id = PassengerCarCatalog.D_SEGMENT_MIDSIZE
	source.target_car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	source.car_mass_kg = 1640.0
	source.target_mass_kg = 1420.0
	source.car_speed_kmh = 92.0
	source.target_speed_kmh = 40.0
	source.car_position_m = Vector3(-5.5, 0.0, 0.4)
	source.target_position_m = Vector3(3.0, 0.0, 0.8)
	source.car_heading_deg = 7.0
	source.target_heading_deg = 9.0
	source.contact_friction = 0.72
	source.restitution = 0.08
	source.duration_s = 6.0
	var loaded: ScenarioConfig = ScenarioConfig.from_json(source.to_json(false))
	if loaded == null:
		failures.append("M4 scenario JSON did not deserialize")
		return
	if loaded.title != source.title or loaded.target_type != source.target_type:
		failures.append("M4 scenario JSON lost identity fields")
	if loaded.car_preset_id != source.car_preset_id or loaded.target_car_preset_id != source.target_car_preset_id:
		failures.append("M4 scenario JSON lost passenger-car class fields")
	if absf(loaded.car_mass_kg - source.car_mass_kg) > 0.001 or absf(loaded.target_mass_kg - source.target_mass_kg) > 0.001:
		failures.append("M4 scenario JSON lost vehicle masses")
	if loaded.car_position_m.distance_to(source.car_position_m) > 0.000001:
		failures.append("M4 scenario JSON lost car position")
	if absf(loaded.contact_friction - source.contact_friction) > 0.000001:
		failures.append("M4 scenario JSON lost contact parameters")
	if not loaded.validation_errors().is_empty():
		failures.append("M4 valid car-vs-car round-trip scenario failed preflight")

func _test_scenario_store(failures: Array[String]) -> void:
	var scenario := ScenarioConfig.new()
	var path := "user://m4_ci_roundtrip.crashvector.json"
	var error := ScenarioStore.save_to_path(scenario, path)
	if error != OK:
		failures.append("M4 scenario store could not save")
		return
	var result: Dictionary = ScenarioStore.load_from_path(path)
	if not String(result.get("error", "")).is_empty():
		failures.append("M4 scenario store could not reload saved file")
	var loaded := result.get("scenario") as ScenarioConfig
	if loaded == null or loaded.car_preset_id != scenario.car_preset_id:
		failures.append("M4 scenario store round trip changed scenario data")

func _test_preflight_rules(failures: Array[String]) -> void:
	var scenario := ScenarioConfig.new()
	scenario.target_type = ScenarioConfig.TARGET_PASSENGER_CAR
	scenario.target_mass_kg = PassengerCarCatalog.default_mass_kg(scenario.target_car_preset_id)
	scenario.target_heading_deg = 90.0
	if scenario.validation_errors().is_empty():
		failures.append("M4 preflight did not reject unsupported broadside car-vs-car contact")
	scenario.target_heading_deg = 180.0
	if not scenario.validation_errors().is_empty():
		failures.append("M4 preflight rejected supported head-on car-vs-car layout")

func _test_heading_transform(failures: Array[String]) -> void:
	var model := PassengerCarBuilder.build(PassengerCarCatalog.B_SEGMENT_HATCHBACK, 1150.0, 50.0, 5.0, Vector3.ZERO)
	var original_energy := model.initial_energy_j
	model.rotate_y_about(Vector3.ZERO, PI * 0.5, true)
	var velocity := model.average_velocity_ms()
	if absf(velocity.length() - PhysicsMetrics.kmh_to_ms(50.0)) > 0.000001:
		failures.append("M4 heading transform changed vehicle speed")
	if absf(model.initial_energy_j - original_energy) > 0.01:
		failures.append("M4 heading transform changed kinetic energy")
	if absf(velocity.x) > 0.00001 or absf(velocity.z) < 1.0:
		failures.append("M4 heading transform did not rotate vehicle velocity")

func _test_static_obstacle_impact(failures: Array[String]) -> void:
	var model := PassengerCarBuilder.build(PassengerCarCatalog.B_SEGMENT_HATCHBACK, 1150.0, 50.0, 5.0, Vector3(-3.0, 0.0, 0.0))
	var simulation := VehicleStaticSimulation.new()
	simulation.configure(model, ScenarioConfig.TARGET_WALL, Vector3.ZERO, 0.0, 0.55, 0.03)
	for _step in range(180):
		simulation.step(DT, 8)
	if simulation.contact.contact_events <= 0:
		failures.append("M4 static wall scenario produced no contact")
	if model.max_permanent_deformation_for_role(&"front_crush") <= 0.0005:
		failures.append("M4 static wall scenario produced no front-crush deformation")
	if not _model_is_finite(model) or not is_finite(simulation.energy_balance_relative_error()):
		failures.append("M4 static obstacle scenario produced invalid numerical state")

func _test_car_vs_car_rear_impact(failures: Array[String]) -> void:
	var primary := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK, 1150.0, 90.0, 100.0, Vector3(-6.0, 0.0, 0.0)
	)
	var target := PassengerCarBuilder.build(
		PassengerCarCatalog.C_SEGMENT_COMPACT, 1375.0, 0.0, 100.0, Vector3(2.5, 0.0, 0.0)
	)
	var simulation := VehiclePairSimulation.new()
	simulation.configure(primary, FRONT_CONTACTS, target, REAR_CONTACTS, Vector3.RIGHT, 0.55, 0.03)
	for _step in range(220):
		simulation.step(DT, 8)
	if simulation.contact.contact_events <= 0:
		failures.append("M4 car-vs-car rear impact produced no contact")
	if target.average_velocity_ms().x <= 0.0:
		failures.append("M4 car-vs-car rear impact transferred no forward momentum")
	if primary.max_permanent_deformation_for_role(&"front_crush") <= 0.0005:
		failures.append("M4 car-vs-car rear impact produced no primary front-crush deformation")
	if simulation.momentum_error_kg_ms() > 0.02:
		failures.append("M4 car-vs-car rear impact has excessive momentum error")
	if not _model_is_finite(primary) or not _model_is_finite(target):
		failures.append("M4 car-vs-car rear impact produced non-finite state")

func _test_car_vs_car_head_on(failures: Array[String]) -> void:
	var primary := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK, 1150.0, 50.0, 100.0, Vector3(-5.0, 0.0, 0.0)
	)
	var target := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK, 1150.0, 50.0, 100.0, Vector3(5.0, 0.0, 0.0)
	)
	target.rotate_y_about(Vector3(5.0, 0.0, 0.0), PI, true)
	var simulation := VehiclePairSimulation.new()
	simulation.configure(primary, FRONT_CONTACTS, target, FRONT_CONTACTS, Vector3.RIGHT, 0.55, 0.03)
	for _step in range(220):
		simulation.step(DT, 8)
	if simulation.contact.contact_events <= 0:
		failures.append("M4 head-on car-vs-car scenario produced no contact")
	if primary.max_permanent_deformation_for_role(&"front_crush") <= 0.0005:
		failures.append("M4 head-on scenario produced no deformation in the primary front crush zone")
	if target.max_permanent_deformation_for_role(&"front_crush") <= 0.0005:
		failures.append("M4 head-on scenario produced no deformation in the target front crush zone")
	if simulation.momentum_error_kg_ms() > 0.02:
		failures.append("M4 head-on car-vs-car scenario has excessive momentum error")
	if not _model_is_finite(primary) or not _model_is_finite(target):
		failures.append("M4 head-on car-vs-car scenario produced non-finite state")

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
