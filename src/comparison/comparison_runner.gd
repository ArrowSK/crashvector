# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ComparisonRunner
extends RefCounted

const DT: float = 1.0 / 240.0
const REPLAY_INTERVAL: float = 1.0 / 120.0
const MATRIX_CAR_CLASSES: StringName = &"car_classes"
const MATRIX_TARGET_TYPES: StringName = &"target_types"
const MATRIX_BODY_PRESETS: StringName = &"body_presets"

static func run_speed_sweep(
	base_scenario: ScenarioConfig,
	speeds_kmh: Array[float] = [50.0, 90.0, 140.0],
	solver_substeps_override: int = -1
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for speed in _normalise_speeds(speeds_kmh):
		var config := _clone_scenario(base_scenario)
		config.car_speed_kmh = speed
		results.append(_run_variant(config, _speed_label(speed), &"speed", solver_substeps_override))
	return results

static func run_vehicle_class_sweep(
	base_scenario: ScenarioConfig,
	preset_ids: Array[StringName] = [
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		PassengerCarCatalog.C_SEGMENT_COMPACT,
		PassengerCarCatalog.D_SEGMENT_MIDSIZE,
	]
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for preset_id in _normalise_ids(preset_ids, 3):
		if not PassengerCarCatalog.preset_ids().has(preset_id):
			continue
		var config := _clone_scenario(base_scenario)
		config.car_preset_id = preset_id
		config.car_mass_kg = PassengerCarCatalog.default_mass_kg(preset_id)
		results.append(_run_variant(config, PassengerCarCatalog.display_name(preset_id), &"vehicle_class"))
	return results

static func run_matrix(
	base_scenario: ScenarioConfig,
	matrix_mode: StringName,
	variant_ids: Array[StringName],
	speeds_kmh: Array[float]
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var speeds := _normalise_speeds(speeds_kmh)
	var variants := _normalise_ids(variant_ids, 3)
	if speeds.is_empty() or variants.is_empty():
		return results
	for variant_id in variants:
		for speed in speeds:
			var config := _clone_scenario(base_scenario)
			var variant_label := ""
			match matrix_mode:
				MATRIX_CAR_CLASSES:
					if not PassengerCarCatalog.preset_ids().has(variant_id):
						continue
					config.car_preset_id = variant_id
					config.car_mass_kg = PassengerCarCatalog.default_mass_kg(variant_id)
					variant_label = PassengerCarCatalog.display_name(variant_id)
				MATRIX_TARGET_TYPES:
					if not ScenarioConfig.target_ids().has(variant_id):
						continue
					config.apply_target_defaults(variant_id)
					variant_label = ScenarioConfig.target_display_name(variant_id)
				MATRIX_BODY_PRESETS:
					if RoadUserCatalog.is_pedestrian_id(variant_id):
						config.apply_target_defaults(ScenarioConfig.TARGET_PEDESTRIAN)
						config.target_preset_id = variant_id
						config.target_mass_kg = RoadUserCatalog.default_mass_kg(variant_id)
					elif RoadUserCatalog.is_bicycle_id(variant_id):
						config.apply_target_defaults(ScenarioConfig.TARGET_BICYCLE)
						config.target_preset_id = variant_id
						config.target_mass_kg = RoadUserCatalog.default_mass_kg(variant_id)
					else:
						continue
					variant_label = RoadUserCatalog.display_name(variant_id)
				_:
					continue
			config.car_speed_kmh = speed
			results.append(_run_variant(config, "%s • %s" % [variant_label, _speed_label(speed)], &"matrix"))
	return results

static func _run_variant(
	config: ScenarioConfig,
	label: String,
	sweep_type: StringName,
	solver_substeps_override: int = -1
) -> Dictionary:
	var errors := config.validation_errors()
	if not errors.is_empty():
		return {
			"label": label,
			"sweep_type": sweep_type,
			"scenario": config,
			"error": "; ".join(errors),
		}

	var primary := PassengerCarBuilder.build(
		config.car_preset_id,
		config.car_mass_kg,
		config.car_speed_kmh,
		1000.0,
		config.car_position_m
	)
	primary.rotate_y_about(config.car_position_m, deg_to_rad(config.car_heading_deg), true)
	primary.barrier_enabled = false

	var target: StructuralModel = null
	var pair_simulation: VehiclePairSimulation = null
	var static_simulation: VehicleStaticSimulation = null
	var pedestrian_target := false

	if config.target_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		target = PassengerCarBuilder.build(
			config.target_car_preset_id,
			config.target_mass_kg,
			config.target_speed_kmh,
			1000.0,
			config.target_position_m
		)
		target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
		target.barrier_enabled = false
		pair_simulation = _pair(primary, _front_contact_nodes(), target, _front_contact_nodes() if config.target_vehicle_uses_front_contact() else _rear_contact_nodes(), config)
	elif config.target_type == ScenarioConfig.TARGET_TRUCK:
		target = HeavyTruckBuilder.build(config.target_mass_kg, config.target_speed_kmh, config.target_position_m)
		target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
		pair_simulation = _pair(primary, _front_contact_nodes(), target, HeavyTruckBuilder.rear_contact_nodes(), config)
	elif config.target_type == ScenarioConfig.TARGET_LORRY:
		target = RigidLorryBuilder.build(config.target_mass_kg, config.target_speed_kmh, config.target_position_m)
		target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
		pair_simulation = _pair(primary, _front_contact_nodes(), target, RigidLorryBuilder.rear_contact_nodes(), config)
	elif config.target_type == ScenarioConfig.TARGET_MOTORCYCLE:
		target = MotorcycleBuilder.build(config.target_mass_kg, config.target_speed_kmh, config.target_position_m)
		target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
		pair_simulation = _pair(primary, _front_contact_nodes(), target, MotorcycleBuilder.front_contact_nodes() if config.target_vehicle_uses_front_contact() else MotorcycleBuilder.rear_contact_nodes(), config)
	elif config.target_type == ScenarioConfig.TARGET_BICYCLE:
		target = BicycleBuilder.build(config.target_preset_id, config.target_mass_kg, config.target_speed_kmh, config.target_position_m)
		target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
		pair_simulation = _pair(primary, _front_contact_nodes(), target, BicycleBuilder.front_contact_nodes() if config.target_vehicle_uses_front_contact() else BicycleBuilder.rear_contact_nodes(), config)
	elif config.target_type == ScenarioConfig.TARGET_PEDESTRIAN:
		target = PedestrianBuilder.build(config.target_preset_id, config.target_mass_kg, config.target_position_m)
		target.rotate_y_about(config.target_position_m, deg_to_rad(config.target_heading_deg), true)
		pair_simulation = _pair(primary, _front_contact_nodes(), target, PedestrianBuilder.contact_nodes(), config)
		pedestrian_target = true
	else:
		static_simulation = VehicleStaticSimulation.new()
		static_simulation.configure(
			primary,
			config.target_type,
			config.target_position_m,
			config.target_heading_deg,
			config.contact_friction,
			config.restitution
		)

	var recorder := ReplayRecorder.new()
	recorder.begin(REPLAY_INTERVAL)
	_capture(recorder, 0.0, primary, target, config, pair_simulation, static_simulation, true)

	var integration_substeps := config.solver_substeps
	if solver_substeps_override > 0:
		integration_substeps = solver_substeps_override
	var elapsed_s := 0.0
	while elapsed_s < config.duration_s - 0.0000001:
		var step_s := minf(DT, config.duration_s - elapsed_s)
		if pair_simulation != null:
			pair_simulation.step(step_s, integration_substeps)
			if pedestrian_target and pair_simulation.contact.contact_events > 0 and not PedestrianBuilder.stance_released(target):
				PedestrianBuilder.release_stance(target)
		else:
			static_simulation.step(step_s, integration_substeps)
		elapsed_s += step_s
		_capture(recorder, elapsed_s, primary, target, config, pair_simulation, static_simulation, false)

	recorder.force_final(
		elapsed_s,
		primary,
		target,
		_primary_metrics(primary),
		_target_metrics(target, config.target_type),
		_context(pair_simulation, static_simulation)
	)
	var analysis := CrashAnalysis.analyze(recorder.recording)
	return {
		"label": label,
		"sweep_type": sweep_type,
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
