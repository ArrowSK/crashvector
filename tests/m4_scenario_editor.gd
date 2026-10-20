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
	_test_malformed_scenario_documents(failures)
	_test_preflight_rules(failures)
	_test_vehicle_start_envelopes(failures)
	_test_primary_vehicle_defaults(failures)
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
	source.primary_type = ScenarioConfig.TARGET_PASSENGER_CAR
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
	if loaded.primary_type != source.primary_type:
		failures.append("M4 scenario JSON lost the explicit primary actor type")
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
	var legacy_data := source.to_dictionary().duplicate(true)
	legacy_data["format_version"] = 1
	var legacy_car: Dictionary = legacy_data.get("car", {})
	legacy_car.erase("actor_type")
	legacy_data["car"] = legacy_car
	var legacy_loaded := ScenarioConfig.from_dictionary(legacy_data)
	if legacy_loaded == null or legacy_loaded.primary_type != ScenarioConfig.TARGET_PASSENGER_CAR:
		failures.append("M4 version-1 scenario migration did not default the primary actor to passenger car")

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

func _test_malformed_scenario_documents(failures: Array[String]) -> void:
	var valid := ScenarioConfig.new().to_dictionary()
	var bad_examples: Array[Dictionary] = []
	bad_examples.append({})
	var missing_version := valid.duplicate(true)
	missing_version.erase("format_version")
	bad_examples.append(missing_version)
	var future_version := valid.duplicate(true)
	future_version["format_version"] = 999
	bad_examples.append(future_version)
	var wrong_section := valid.duplicate(true)
	wrong_section["car"] = "not an object"
	bad_examples.append(wrong_section)
	var missing_section := valid.duplicate(true)
	missing_section.erase("target")
	bad_examples.append(missing_section)
	var wrong_number := valid.duplicate(true)
	wrong_number["car"]["mass_kg"] = "not a number"
	bad_examples.append(wrong_number)
	var missing_number := valid.duplicate(true)
	missing_number["target"].erase("speed_kmh")
	bad_examples.append(missing_number)
	var wrong_vector := valid.duplicate(true)
	wrong_vector["car"]["position_m"] = [1.0, "not a number", 3.0]
	bad_examples.append(wrong_vector)
	var short_vector := valid.duplicate(true)
	short_vector["target"]["position_m"] = [0.0, 1.0]
	bad_examples.append(short_vector)
	var wrong_boolean := valid.duplicate(true)
	wrong_boolean["simulation"]["show_structure"] = "false"
	bad_examples.append(wrong_boolean)
	var wrong_integer := valid.duplicate(true)
	wrong_integer["simulation"]["solver_substeps"] = 2.5
	bad_examples.append(wrong_integer)
	var missing_actor := valid.duplicate(true)
	missing_actor["car"].erase("actor_type")
	bad_examples.append(missing_actor)
	var future_scenario := valid.duplicate(true)
	future_scenario["scenario_type"] = "unsupported"
	bad_examples.append(future_scenario)
	for index in range(bad_examples.size()):
		var data := bad_examples[index]
		if ScenarioConfig.persisted_structure_error(data).is_empty():
			failures.append("M4 accepted structurally invalid scenario example %d" % index)
		if ScenarioConfig.from_dictionary(data) != null or ScenarioConfig.from_json(JSON.stringify(data)) != null:
			failures.append("M4 silently constructed malformed scenario example %d" % index)
	# Existing v1 files may omit actor_type, but still must have real structure.
	var legacy := valid.duplicate(true)
	legacy["format_version"] = 1
	legacy["car"].erase("actor_type")
	if ScenarioConfig.from_dictionary(legacy) == null:
		failures.append("M4 P2 schema validation broke valid version-1 migration")
	var invalid_path := "user://m4_invalid_scenario.crashvector.json"
	var file := FileAccess.open(invalid_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not create malformed scenario import fixture")
		return
	file.store_string(JSON.stringify(wrong_section))
	file.close()
	var stored_result := ScenarioStore.load_from_path(invalid_path)
	if String(stored_result.get("error", "")).is_empty() or stored_result.get("scenario") != null:
		failures.append("M4 scenario store silently accepted a malformed object section")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))

func _test_preflight_rules(failures: Array[String]) -> void:
	var scenario := ScenarioConfig.new()
	scenario.target_type = ScenarioConfig.TARGET_PASSENGER_CAR
	scenario.target_mass_kg = PassengerCarCatalog.default_mass_kg(scenario.target_car_preset_id)
	# M18 deliberately extends passenger-car production contact to broadside
	# layouts. Keep this historical preflight test aligned with the current
	# ScenarioConfig contract instead of preserving an obsolete rejection.
	scenario.target_heading_deg = 90.0
	if not scenario.validation_errors().is_empty():
		failures.append("M4/M18 preflight rejected supported broadside car-vs-car contact")
	scenario.target_heading_deg = 180.0
	if not scenario.validation_errors().is_empty():
		failures.append("M4 preflight rejected supported head-on car-vs-car layout")

func _test_vehicle_start_envelopes(failures: Array[String]) -> void:
	# The M23 role-neutral path used to accept this normal UI geometry because the
	# actor origins are 8.5 m apart. The articulated truck itself extends more than
	# 9 m forward from its origin, so it already intersects the target car.
	var scenario := ScenarioConfig.new()
	scenario.apply_primary_vehicle_defaults(ScenarioConfig.TARGET_TRUCK)
	scenario.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	scenario.car_position_m = Vector3(-6.0, 0.0, 0.0)
	scenario.target_position_m = Vector3(2.5, 0.0, 0.0)
	var overlap_errors := scenario.validation_errors()
	var rejected_overlap := false
	for error in overlap_errors:
		if error.contains("Vehicle start envelopes overlap"):
			rejected_overlap = true
			break
	if not rejected_overlap:
		failures.append("M4/M23 preflight accepted an articulated truck already overlapping its passenger-car target")

	# The envelope test must respect actor heading rather than treating every
	# vehicle as an axis-aligned interval around its origin.
	scenario.car_heading_deg = 90.0
	var rotated_errors := scenario.validation_errors()
	for error in rotated_errors:
		if error.contains("Vehicle start envelopes overlap"):
			failures.append("M4/M23 vehicle-envelope preflight ignored the primary truck heading")
			break
	scenario.car_heading_deg = 0.0

	# Moving the same target clear of the truck must restore a valid scenario;
	# this guards against replacing the old centre-distance rule with an
	# over-conservative blanket rejection.
	scenario.target_position_m = Vector3(6.0, 0.0, 0.0)
	var clear_errors := scenario.validation_errors()
	for error in clear_errors:
		if error.contains("Vehicle start envelopes overlap"):
			failures.append("M4/M23 vehicle-envelope preflight rejected a visibly separated truck/car pair")
			break

func _test_primary_vehicle_defaults(failures: Array[String]) -> void:
	for actor_type in ScenarioConfig.vehicle_actor_ids():
		var scenario := ScenarioConfig.new()
		# This test is about actor mass/speed defaults, not spawn geometry. Keep the
		# target far enough away that long actors such as M21 do not intentionally
		# trip the independent start-envelope preflight regression above.
		scenario.target_position_m = Vector3(16.0, 0.0, 0.0)
		scenario.apply_primary_vehicle_defaults(actor_type)
		if not scenario.validation_errors().is_empty():
			failures.append("M4 primary %s defaults failed preflight: %s" % [ScenarioConfig.actor_display_name(actor_type), "; ".join(scenario.validation_errors())])

func _test_heading_transform(failures: Array[String]) -> void:
	var model := PassengerCarBuilder.build(PassengerCarCatalog.B_SEGMENT_HATCHBACK, 1150.0, 50.0, 5.0, Vector3.ZERO)
	# This regression is specifically about rigid heading transforms preserving
	# kinetic energy. M11 adds elastic structural state, so initial_energy_j is
	# intentionally broader than the quantity this historical test names.
	var original_energy := model.total_kinetic_energy_j()
	model.rotate_y_about(Vector3.ZERO, PI * 0.5, true)
	var velocity := model.average_velocity_ms()
	if absf(velocity.length() - PhysicsMetrics.kmh_to_ms(50.0)) > 0.000001:
		failures.append("M4 heading transform changed vehicle speed")
	if absf(model.total_kinetic_energy_j() - original_energy) > 0.01:
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
