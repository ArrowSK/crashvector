# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ComparisonRunner
extends RefCounted

const DT: float = 1.0 / 240.0
const DEFAULT_SPEEDS := [50.0, 90.0, 140.0]
const DEFAULT_CLASS_IDS := [
	PassengerCarCatalog.B_SEGMENT_HATCHBACK,
	PassengerCarCatalog.C_SEGMENT_COMPACT,
	PassengerCarCatalog.D_SEGMENT_MIDSIZE,
]
const DEFAULT_TARGET_IDS := [
	ScenarioConfig.TARGET_WALL,
	ScenarioConfig.TARGET_TRUCK,
	ScenarioConfig.TARGET_PASSENGER_CAR,
]

static func run_speed_sweep(
	base_scenario: ScenarioConfig,
	speeds_kmh: Array[float] = DEFAULT_SPEEDS,
	paint_ids: Array[StringName] = []
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var speeds := _normalise_speeds(speeds_kmh)
	for index in range(speeds.size()):
		var config := _clone_scenario(base_scenario)
		config.car_speed_kmh = speeds[index]
		var paint_id := CarPaintCatalog.BLUE
		if index < paint_ids.size() and CarPaintCatalog.has_id(paint_ids[index]):
			paint_id = paint_ids[index]
		var result := _run_variant(config)
		result["label"] = _speed_label(speeds[index])
		result["sweep_value"] = speeds[index]
		result["sweep_type"] = &"speed"
		result["paint_id"] = paint_id
		results.append(result)
	return results

static func run_class_sweep(
	base_scenario: ScenarioConfig,
	class_ids: Array[StringName] = DEFAULT_CLASS_IDS,
	paint_ids: Array[StringName] = []
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var ids := _normalise_ids(class_ids, 3)
	for index in range(ids.size()):
		var id := ids[index]
		if not PassengerCarCatalog.preset_ids().has(id):
			continue
		var config := _clone_scenario(base_scenario)
		config.car_preset_id = id
		config.car_mass_kg = PassengerCarCatalog.default_mass_kg(id)
		var paint_id := CarPaintCatalog.BLUE
		if index < paint_ids.size() and CarPaintCatalog.has_id(paint_ids[index]):
			paint_id = paint_ids[index]
		var result := _run_variant(config)
		result["label"] = PassengerCarCatalog.display_name(id)
		result["sweep_value"] = id
		result["sweep_type"] = &"class"
		result["paint_id"] = paint_id
		results.append(result)
	return results

static func run_target_sweep(
	base_scenario: ScenarioConfig,
	target_ids: Array[StringName] = DEFAULT_TARGET_IDS,
	paint_ids: Array[StringName] = []
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var ids := _normalise_ids(target_ids, 3)
	for index in range(ids.size()):
		var id := ids[index]
		if not ScenarioConfig.target_ids().has(id):
			continue
		var config := _clone_scenario(base_scenario)
		config.apply_target_defaults(id)
		var paint_id := CarPaintCatalog.BLUE
		if index < paint_ids.size() and CarPaintCatalog.has_id(paint_ids[index]):
			paint_id = paint_ids[index]
		var result := _run_variant(config)
		result["label"] = ScenarioConfig.target_display_name(id)
		result["sweep_value"] = id
		result["sweep_type"] = &"target"
		result["paint_id"] = paint_id
		results.append(result)
	return results

static func run_matrix(
	base_scenario: ScenarioConfig,
	class_ids: Array[StringName],
	target_ids: Array[StringName],
	speeds_kmh: Array[float]
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var classes := _normalise_ids(class_ids, 3)
	var targets := _normalise_ids(target_ids, 3)
	var speeds := _normalise_speeds(speeds_kmh)
	if classes.is_empty():
		classes.append(base_scenario.car_preset_id)
	if targets.is_empty():
		targets.append(base_scenario.target_type)
	if speeds.is_empty():
		speeds.append(base_scenario.car_speed_kmh)
	for class_id in classes:
		if not PassengerCarCatalog.preset_ids().has(class_id):
			continue
		for target_id in targets:
			if not ScenarioConfig.target_ids().has(target_id):
				continue
			for speed in speeds:
				if results.size() >= 9:
					return results
				var config := _clone_scenario(base_scenario)
				config.car_preset_id = class_id
				config.car_mass_kg = PassengerCarCatalog.default_mass_kg(class_id)
				config.car_speed_kmh = speed
				config.apply_target_defaults(target_id)
				var result := _run_variant(config)
				result["label"] = "%s • %s • %s" % [
					PassengerCarCatalog.display_name(class_id),
					ScenarioConfig.target_display_name(target_id),
					_speed_label(speed),
				]
				result["sweep_value"] = {
					"class_id": class_id,
					"target_id": target_id,
					"speed_kmh": speed,
				}
				result["sweep_type"] = &"matrix"
				result["paint_id"] = CarPaintCatalog.BLUE
				results.append(result)
	return results

static func _run_variant(config: ScenarioConfig) -> Dictionary:
	var errors := config.validation_errors()
	if not errors.is_empty():
		return {"error": " • ".join(errors)}

	var primary := PassengerCarBuilder.build(config.car_preset_id, config.car_mass_kg, config.car_speed_kmh, 100.0, config.car_position_m)
	primary.rotate_y_about(config.car_position_m, deg_to_rad(config.car_heading_deg), true)
	var target: StructuralModel
	var pair_simulation: VehiclePairSimulation
	var static_simulation: VehicleStaticSimulation
	match config.target_type:
		ScenarioConfig.TARGET_PASSENGER_CAR:
			target = PassengerCarBuilder.build(config.target_car_preset_id, config.target_mass_kg, config.target_speed_kmh, 100.0, config.target_position_m)
			target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
			pair_simulation = _pair(primary, _front_contact_nodes(), target, _front_contact_nodes() if config.target_car_uses_front_contact() else _rear_contact_nodes(), config)
		ScenarioConfig.TARGET_TRUCK:
			target = HeavyTruckBuilder.build(config.target_mass_kg, config.target_speed_kmh, config.target_position_m)
			target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
			pair_simulation = _pair(primary, _front_contact_nodes(), target, HeavyTruckBuilder.rear_contact_nodes(), config)
		ScenarioConfig.TARGET_LORRY:
			target = RigidLorryBuilder.build(config.target_mass_kg, config.target_speed_kmh, config.target_position_m)
			target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
			pair_simulation = _pair(primary, _front_contact_nodes(), target, RigidLorryBuilder.rear_contact_nodes(), config)
		ScenarioConfig.TARGET_MOTORCYCLE:
			target = MotorcycleBuilder.build(config.target_mass_kg, config.target_speed_kmh, config.target_position_m)
			target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
			pair_simulation = _pair(primary, _front_contact_nodes(), target, MotorcycleBuilder.front_contact_nodes() if config.target_vehicle_uses_front_contact() else MotorcycleBuilder.rear_contact_nodes(), config)
		ScenarioConfig.TARGET_BICYCLE:
			target = BicycleBuilder.build(config.target_preset_id, config.target_mass_kg, config.target_speed_kmh, config.target_position_m)
			target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
			pair_simulation = _pair(primary, _front_contact_nodes(), target, BicycleBuilder.contact_nodes(config.target_vehicle_uses_front_contact()), config)
		ScenarioConfig.TARGET_PEDESTRIAN:
			target = PedestrianBuilder.build(config.target_preset_id, config.target_mass_kg, config.target_position_m)
			target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), false)
			pair_simulation = _pair(primary, _front_contact_nodes(), target, PedestrianBuilder.contact_nodes(), config)
		_:
			static_simulation = VehicleStaticSimulation.new()
			static_simulation.configure(primary, config.target_type, config.target_position_m, config.target_heading_deg, config.contact_friction, config.restitution)

	var recorder := ReplayRecorder.new()
	var time_s := 0.0
	_capture(recorder, time_s, primary, target, config, pair_simulation, static_simulation, true)
	while time_s < config.duration_s - 0.000001:
		if pair_simulation != null:
			pair_simulation.step(DT, config.solver_substeps)
		else:
			static_simulation.step(DT, config.solver_substeps)
		time_s += DT
		_capture(recorder, time_s, primary, target, config, pair_simulation, static_simulation, false)
	recorder.finish(time_s, primary, target, _primary_metrics(primary), _target_metrics(target, config.target_type), _context(pair_simulation, static_simulation))
	var analysis := CrashAnalysis.analyse(recorder.recording)
	return {
		"scenario": config,
		"recording": recorder.recording,
		"analysis": analysis,
		"error": "",
	}

static func _pair(
	primary: StructuralModel,
	primary_nodes: PackedInt32Array,
	target: StructuralModel,
	target_nodes: PackedInt32Array,
	config: ScenarioConfig
) -> VehiclePairSimulation:
	var simulation := VehiclePairSimulation.new()
	simulation.configure(primary, primary_nodes, target, target_nodes, config.car_forward(), config.contact_friction, config.restitution)
	return simulation

static func _capture(
	recorder: ReplayRecorder,
	time_s: float,
	primary: StructuralModel,
	target: StructuralModel,
	config: ScenarioConfig,
	pair_simulation: VehiclePairSimulation,
	static_simulation: VehicleStaticSimulation,
	force: bool
) -> void:
	recorder.capture(
		time_s,
		primary,
		target,
		_primary_metrics(primary),
		_target_metrics(target, config.target_type),
		_context(pair_simulation, static_simulation),
		{},
		{},
		force
	)

static func _primary_metrics(model: StructuralModel) -> Dictionary:
	var velocity := model.average_velocity_ms()
	return {
		"mass_kg": model.total_mass_kg(),
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": model.total_momentum_kg_ms(),
		"kinetic_energy_j": model.total_kinetic_energy_j(),
		"front_crush_m": model.max_permanent_deformation_for_role(&"front_crush"),
		"safety_cell_m": model.max_permanent_deformation_for_role(&"safety_cell"),
		"broken_beams": model.broken_beam_count(),
		"plastic_energy_j": model.total_plastic_energy_j(),
		"damping_energy_j": model.total_damping_energy_j(),
		"fracture_energy_j": model.total_fracture_energy_j(),
		"elastic_energy_j": model.total_elastic_energy_j(),
	}

static func _target_metrics(model: StructuralModel, target_type: StringName) -> Dictionary:
	if model == null:
		return {}
	var velocity := model.average_velocity_ms()
	var result := {
		"mass_kg": model.total_mass_kg(),
		"linear_velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"momentum_kg_ms": model.total_momentum_kg_ms(),
		"kinetic_energy_j": model.total_kinetic_energy_j(),
		"broken_beams": model.broken_beam_count(),
		"plastic_energy_j": model.total_plastic_energy_j(),
		"damping_energy_j": model.total_damping_energy_j(),
		"fracture_energy_j": model.total_fracture_energy_j(),
		"elastic_energy_j": model.total_elastic_energy_j(),
	}
	if target_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		result["front_crush_m"] = model.max_permanent_deformation_for_role(&"front_crush")
		result["safety_cell_m"] = model.max_permanent_deformation_for_role(&"safety_cell")
	elif target_type == ScenarioConfig.TARGET_TRUCK:
		result["rear_guard_m"] = model.max_permanent_deformation_for_role(&"underride_guard")
	elif target_type == ScenarioConfig.TARGET_LORRY:
		result["rear_guard_m"] = model.max_permanent_deformation_for_role(&"lorry_rear_guard")
	elif target_type == ScenarioConfig.TARGET_MOTORCYCLE:
		result["frame_deformation_m"] = model.max_permanent_deformation_for_role(&"motorcycle_frame")
	elif target_type == ScenarioConfig.TARGET_BICYCLE:
		result["frame_deformation_m"] = model.max_permanent_deformation_for_role(&"bicycle_frame")
	elif target_type == ScenarioConfig.TARGET_PEDESTRIAN:
		result["body_deformation_m"] = model.max_permanent_deformation_m()
	return result

static func _context(pair_simulation: VehiclePairSimulation, static_simulation: VehicleStaticSimulation) -> Dictionary:
	if pair_simulation != null:
		return {
			"contact_count": pair_simulation.contact.contact_events,
			"energy_balance_relative_error": pair_simulation.energy_balance_relative_error(),
			"contact_dissipation_j": pair_simulation.contact.accumulated_dissipation_j,
		}
	if static_simulation != null:
		return {
			"contact_count": static_simulation.contact.contact_events,
			"energy_balance_relative_error": static_simulation.energy_balance_relative_error(),
			"contact_dissipation_j": static_simulation.contact.accumulated_dissipation_j,
		}
	return {}

static func _clone_scenario(source: ScenarioConfig) -> ScenarioConfig:
	return ScenarioConfig.from_dictionary(source.to_dictionary())

static func _front_contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 0),
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 1),
	])

static func _rear_contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.REAR_STATION, 0),
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.REAR_STATION, 1),
	])

static func _normalise_speeds(values: Array[float]) -> Array[float]:
	var result: Array[float] = []
	for value in values:
		var speed := clampf(value, 0.0, 300.0)
		var duplicate := false
		for existing in result:
			if absf(existing - speed) < 0.001:
				duplicate = true
				break
		if not duplicate:
			result.append(speed)
		if result.size() >= 3:
			break
	return result

static func _normalise_ids(values: Array[StringName], maximum: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		if not result.has(value):
			result.append(value)
		if result.size() >= maximum:
			break
	return result

static func _speed_label(speed_kmh: float) -> String:
	if absf(speed_kmh - roundf(speed_kmh)) < 0.001:
		return "%.0f km/h" % speed_kmh
	return "%.1f km/h" % speed_kmh
