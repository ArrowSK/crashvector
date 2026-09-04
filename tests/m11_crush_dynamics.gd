# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const DT: float = 1.0 / 240.0

func _initialize() -> void:
	var failures: Array[String] = []
	_test_production_architecture(failures)
	_test_contact_is_compliant_not_impulsive(failures)
	_test_symmetric_wall_crush_shape(failures)
	_test_dynamic_pair_multipoint_contact(failures)
	_test_high_speed_stability(failures)
	if failures.is_empty():
		print("CrashVector M11 crush-dynamics tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_production_architecture(failures: Array[String]) -> void:
	var model := PassengerCarBuilder.build(PassengerCarCatalog.B_SEGMENT_HATCHBACK, 1150.0, 50.0, 100.0)
	if model.nodes.size() != 44:
		failures.append("M11 production passenger car must contain 44 structural nodes, got %d" % model.nodes.size())
	if absf(model.total_mass_kg() - 1150.0) > 0.001:
		failures.append("M11 refined passenger-car mass distribution does not sum to configured mass")
	if PassengerCarBuilder.front_contact_nodes().size() != 4:
		failures.append("M11 passenger car must expose the full four-node front contact face")
	if model.bending_constraint_count() < 28:
		failures.append("M11 production car is missing the expected front/cell bending constraints")
	for component in [&"bumper_beam", &"crash_box", &"front_rail", &"subframe", &"firewall_transition"]:
		if model.component_beam_count(component) <= 0:
			failures.append("M11 production car is missing structural component: %s" % component)

func _test_contact_is_compliant_not_impulsive(failures: Array[String]) -> void:
	var model := StructuralModel.new()
	model.barrier_enabled = false
	model.add_node(Vector3(0.01, 0.50, 0.0), 1000.0)
	model.set_uniform_velocity(Vector3(10.0, 0.0, 0.0))
	var contact := VehicleStaticContact.new()
	contact.configure(ScenarioConfig.TARGET_WALL, Vector3.ZERO, 0.0, 0.0, 0.0)
	model.prepare_substep(DT)
	contact.apply_forces(model, DT, 0.0)
	model.integrate_substep(DT)
	if model.nodes[0].velocity_ms.x <= 1.0:
		failures.append("M11 wall contact still behaves like an instantaneous stop/impulse")
	if model.nodes[0].position_m.x <= -0.05:
		failures.append("M11 wall contact applied a large teleport-style position correction")
	if contact.current_contact_energy_j <= 0.0:
		failures.append("M11 compliant contact did not retain elastic contact energy")
	if VehicleStaticContact.damping_ratio_for_restitution(0.01) <= VehicleStaticContact.damping_ratio_for_restitution(0.20):
		failures.append("M11 contact damping no longer follows the configured restitution")

func _test_symmetric_wall_crush_shape(failures: Array[String]) -> void:
	var model := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		1150.0,
		50.0,
		100.0,
		Vector3(-2.17, 0.0, 0.0)
	)
	var initial_front_length := _front_structure_length(model)
	var initial_cell_length := _cell_length(model)
	var initial_yaw_deg := _reference_yaw_deg(model)
	var maximum_front_crush := 0.0
	var simulation := VehicleStaticSimulation.new()
	simulation.configure(model, ScenarioConfig.TARGET_WALL, Vector3.ZERO, 0.0, 0.55, 0.02)
	for _step in range(192):
		simulation.step(DT, 12)
		maximum_front_crush = maxf(maximum_front_crush, initial_front_length - _front_structure_length(model))
	if simulation.contact.first_contact_time_s < 0.0:
		failures.append("M11 symmetric wall scenario never established compliant contact")
	var final_front_crush := initial_front_length - _front_structure_length(model)
	var cell_change := absf(_cell_length(model) - initial_cell_length)
	var yaw_change_deg := _yaw_change_deg(initial_yaw_deg, _reference_yaw_deg(model))
	var front := CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_STATION)
	var left_right_nose_error := absf(model.nodes[front[0]].position_m.x - model.nodes[front[1]].position_m.x)
	print("M11 50kmh metrics: max_crush=%.3f final_crush=%.3f cell_change=%.3f yaw_change=%.3f nose_lr=%.3f penetration=%.3f bend_deg=%.3f plastic_kj=%.3f" % [
		maximum_front_crush,
		final_front_crush,
		cell_change,
		yaw_change_deg,
		left_right_nose_error,
		simulation.contact.maximum_penetration_m,
		rad_to_deg(model.max_permanent_bending_angle_rad()),
		model.total_plastic_energy_j() / 1000.0,
	])
	if maximum_front_crush < 0.28:
		failures.append("M11 50 km/h wall impact did not materially collapse the front structure: %.3f m maximum" % maximum_front_crush)
	if final_front_crush < 0.12:
		failures.append("M11 50 km/h wall impact retained too little permanent front shortening: %.3f m" % final_front_crush)
	if cell_change > 0.20:
		failures.append("M11 50 km/h wall impact distorted the passenger-cell reference span excessively: %.3f m" % cell_change)
	if yaw_change_deg > 1.5:
		failures.append("M11 centred wall impact generated artificial vehicle yaw change: %.3f deg" % yaw_change_deg)
	if left_right_nose_error > 0.06:
		failures.append("M11 centred wall impact lost left/right crush symmetry: %.3f m" % left_right_nose_error)
	if model.max_permanent_bending_angle_rad() < deg_to_rad(0.5):
		failures.append("M11 frontal crush produced no measurable permanent fold angle")
	if model.total_plastic_energy_j() <= 0.0:
		failures.append("M11 frontal crush produced no plastic work")
	if simulation.contact.maximum_penetration_m > 0.32:
		failures.append("M11 wall contact penetrated too deeply at 50 km/h: %.3f m" % simulation.contact.maximum_penetration_m)
	if not _model_is_finite(model):
		failures.append("M11 symmetric wall scenario produced non-finite state")

func _test_dynamic_pair_multipoint_contact(failures: Array[String]) -> void:
	var car := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		1150.0,
		90.0,
		100.0,
		Vector3(-6.0, 0.0, 0.0)
	)
	var truck := HeavyTruckBuilder.build(18000.0, 0.0, Vector3(2.5, 0.0, 0.0))
	var initial_cabin_yaw_deg := _cabin_yaw_deg(car)
	var historical_two_node_seed := PackedInt32Array([
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 0),
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 1),
	])
	var simulation := VehiclePairSimulation.new()
	simulation.configure(car, historical_two_node_seed, truck, HeavyTruckBuilder.rear_contact_nodes())
	if simulation.vehicle_contact_nodes.size() < 4:
		failures.append("M11 did not expand the historical car contact seed to a multi-point face")
	if simulation.truck_contact_nodes.size() < 4:
		failures.append("M11 did not expand the truck rear contact seed to a multi-point face")
	for _step in range(240):
		simulation.step(DT, 12)
	var cabin_yaw_change_deg := _yaw_change_deg(initial_cabin_yaw_deg, _cabin_yaw_deg(car))
	print("M11 pair metrics: car_contacts=%d truck_contacts=%d events=%d cabin_yaw_change=%.3f momentum_error=%.6f front_perm=%.3f penetration=%.3f" % [
		simulation.vehicle_contact_nodes.size(), simulation.truck_contact_nodes.size(),
		simulation.contact.contact_events, cabin_yaw_change_deg, simulation.momentum_error_kg_ms(),
		car.max_permanent_deformation_for_role(&"front_crush"), simulation.contact.maximum_penetration_m,
	])
	if simulation.contact.contact_events <= 0:
		failures.append("M11 dynamic pair scenario never established compliant contact")
	if truck.average_velocity_ms().x <= 0.0:
		failures.append("M11 dynamic pair contact transferred no forward momentum to the truck")
	if car.max_permanent_deformation_for_role(&"front_crush") <= 0.01:
		failures.append("M11 dynamic pair scenario produced no meaningful front-crush deformation")
	if simulation.momentum_error_kg_ms() > 0.05:
		failures.append("M11 multipoint pair contact lost excessive linear momentum: %.6f kg m/s" % simulation.momentum_error_kg_ms())
	if cabin_yaw_change_deg > 3.0:
		failures.append("M11 symmetric rear-truck impact generated excessive passenger-cell yaw change: %.3f deg" % cabin_yaw_change_deg)
	if not _model_is_finite(car) or not _model_is_finite(truck):
		failures.append("M11 dynamic pair scenario produced non-finite state")

func _test_high_speed_stability(failures: Array[String]) -> void:
	var model := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		1150.0,
		140.0,
		100.0,
		Vector3(-2.24, 0.0, 0.0)
	)
	var initial_front_length := _front_structure_length(model)
	var initial_yaw_deg := _reference_yaw_deg(model)
	var maximum_front_crush := 0.0
	var simulation := VehicleStaticSimulation.new()
	simulation.configure(model, ScenarioConfig.TARGET_WALL, Vector3.ZERO, 0.0, 0.55, 0.01)
	for _step in range(144):
		simulation.step(DT, 16)
		maximum_front_crush = maxf(maximum_front_crush, initial_front_length - _front_structure_length(model))
	if not _model_is_finite(model):
		failures.append("M11 140 km/h wall scenario became non-finite")
	var final_front_crush := initial_front_length - _front_structure_length(model)
	var yaw_change_deg := _yaw_change_deg(initial_yaw_deg, _reference_yaw_deg(model))
	print("M11 140kmh metrics: max_crush=%.3f final_crush=%.3f yaw_change=%.3f penetration=%.3f bend_deg=%.3f plastic_kj=%.3f" % [
		maximum_front_crush, final_front_crush, yaw_change_deg,
		simulation.contact.maximum_penetration_m,
		rad_to_deg(model.max_permanent_bending_angle_rad()), model.total_plastic_energy_j() / 1000.0,
	])
	if maximum_front_crush < 0.55:
		failures.append("M11 140 km/h scenario failed to show substantial front collapse: %.3f m maximum" % maximum_front_crush)
	if final_front_crush < 0.20:
		failures.append("M11 140 km/h scenario retained too little front shortening: %.3f m" % final_front_crush)
	if simulation.contact.maximum_penetration_m > 0.55:
		failures.append("M11 high-speed contact tunneled too deeply through the wall: %.3f m" % simulation.contact.maximum_penetration_m)
	if yaw_change_deg > 3.0:
		failures.append("M11 symmetric 140 km/h wall impact generated excessive yaw change: %.3f deg" % yaw_change_deg)

func _front_structure_length(model: StructuralModel) -> float:
	var firewall := model.average_position_for_nodes(CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.CABIN_FRONT_STATION))
	var nose := model.average_position_for_nodes(CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_STATION))
	return nose.distance_to(firewall)

func _cell_length(model: StructuralModel) -> float:
	var rear := model.average_position_for_nodes(CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.CABIN_REAR_STATION))
	var front := model.average_position_for_nodes(CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.CABIN_FRONT_STATION))
	return front.distance_to(rear)

func _reference_yaw_deg(model: StructuralModel) -> float:
	var transform := VehicleKinematics.reference_transform(
		model,
		CompactHatchbackBuilder.rear_reference_nodes(),
		CompactHatchbackBuilder.front_reference_nodes(),
		CompactHatchbackBuilder.left_reference_nodes(),
		CompactHatchbackBuilder.right_reference_nodes()
	)
	return rad_to_deg(atan2(transform.basis.x.z, transform.basis.x.x))

func _cabin_yaw_deg(model: StructuralModel) -> float:
	var rear := model.average_position_for_nodes(CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.CABIN_REAR_STATION))
	var front := model.average_position_for_nodes(CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.CABIN_FRONT_STATION))
	var forward := front - rear
	if forward.length_squared() <= 0.000001:
		return 0.0
	return rad_to_deg(atan2(forward.z, forward.x))

func _yaw_change_deg(initial_yaw_deg: float, final_yaw_deg: float) -> float:
	return absf(wrapf(final_yaw_deg - initial_yaw_deg, -180.0, 180.0))

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
