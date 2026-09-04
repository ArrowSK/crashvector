# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const DT: float = 1.0 / 240.0

func _initialize() -> void:
	var failures: Array[String] = []
	_test_passenger_car_catalog(failures)
	_test_heavy_truck_architecture(failures)
	_test_lorry_architecture(failures)
	_test_motorcycle_architecture(failures)
	_test_pair_contact_conserves_momentum(failures)
	_test_rear_impact_scenario(failures)
	if failures.is_empty():
		print("CrashVector M3 vehicle-class and heavy-vehicle tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_passenger_car_catalog(failures: Array[String]) -> void:
	var ids := PassengerCarCatalog.preset_ids()
	var expected: Array[StringName] = [
		PassengerCarCatalog.A_SEGMENT_CITY,
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		PassengerCarCatalog.C_SEGMENT_COMPACT,
		PassengerCarCatalog.D_SEGMENT_MIDSIZE,
		PassengerCarCatalog.J_SEGMENT_SUV,
		PassengerCarCatalog.M_SEGMENT_MPV,
	]
	if ids != expected:
		failures.append("Passenger-car catalog must expose A/B/C/D/J/M generic classes in stable order")
	var previous_mass := 0.0
	var previous_span := 0.0
	for id in ids:
		var preset := PassengerCarCatalog.data(id)
		var mass := float(preset.get("default_mass_kg", 0.0))
		var model := PassengerCarBuilder.build(id, -1.0, 50.0, 100.0)
		if model.nodes.size() != 44:
			failures.append("Passenger-car preset %s did not build the M11 44-node production architecture" % id)
		if model.bending_constraint_count() <= 0:
			failures.append("Passenger-car preset %s lost M11 bending constraints" % id)
		if absf(model.total_mass_kg() - mass) > 0.001:
			failures.append("Passenger-car preset %s mass does not match its catalog default" % id)
		var span := _model_x_span(model)
		if previous_mass > 0.0 and mass <= previous_mass:
			failures.append("Generic passenger-car preset masses must increase through the current A/B/C/D/J/M development set")
		if previous_span > 0.0 and span <= previous_span:
			failures.append("Generic passenger-car structural length must increase through the current A/B/C/D/J/M development set")
		previous_mass = mass
		previous_span = span

func _test_heavy_truck_architecture(failures: Array[String]) -> void:
	var truck := HeavyTruckBuilder.build(18000.0, 0.0, Vector3.ZERO)
	if truck.nodes.size() != 32:
		failures.append("M3 heavy articulated truck must contain 32 structural nodes")
	if absf(truck.total_mass_kg() - 18000.0) > 0.001:
		failures.append("Heavy-truck mass distribution does not sum to configured mass")
	if HeavyTruckBuilder.rear_contact_nodes().size() != 2:
		failures.append("Heavy truck must expose the historical two-node rear contact seed")
	for role in [&"underride_guard", &"trailer_structure", &"trailer_chassis", &"fifth_wheel", &"tractor_structure", &"tractor_chassis"]:
		if truck.role_beam_count(role) <= 0:
			failures.append("Heavy truck is missing structural role: %s" % role)

func _test_lorry_architecture(failures: Array[String]) -> void:
	var lorry := RigidLorryBuilder.build(12000.0, 0.0, Vector3.ZERO)
	if lorry.nodes.size() != 24:
		failures.append("Rigid lorry must contain 24 structural nodes")
	if absf(lorry.total_mass_kg() - 12000.0) > 0.001:
		failures.append("Rigid-lorry mass distribution does not sum to configured mass")
	if RigidLorryBuilder.rear_contact_nodes().size() != 2:
		failures.append("Rigid lorry must expose the historical two-node rear contact seed")
	for role in [&"lorry_rear_guard", &"lorry_cargo_structure", &"lorry_cargo_chassis", &"lorry_cab_structure", &"lorry_cab_chassis"]:
		if lorry.role_beam_count(role) <= 0:
			failures.append("Rigid lorry is missing structural role: %s" % role)

func _test_motorcycle_architecture(failures: Array[String]) -> void:
	var motorcycle := MotorcycleBuilder.build(220.0, 0.0, Vector3.ZERO)
	if motorcycle.nodes.size() != 16:
		failures.append("Riderless motorcycle must contain 16 structural nodes")
	if absf(motorcycle.total_mass_kg() - 220.0) > 0.001:
		failures.append("Motorcycle mass distribution does not sum to configured mass")
	if MotorcycleBuilder.front_contact_nodes().size() != 2 or MotorcycleBuilder.rear_contact_nodes().size() != 2:
		failures.append("Motorcycle must expose paired front and rear contact seeds")
	for role in [&"motorcycle_frame", &"motorcycle_rear", &"motorcycle_fork"]:
		if motorcycle.role_beam_count(role) <= 0:
			failures.append("Motorcycle is missing structural role: %s" % role)

func _test_pair_contact_conserves_momentum(failures: Array[String]) -> void:
	var car := StructuralModel.new()
	car.barrier_enabled = false
	car.add_node(Vector3(0.10, 0.5, 0.0), 1000.0)
	car.set_uniform_velocity(Vector3(10.0, 0.0, 0.0))
	var truck := StructuralModel.new()
	truck.barrier_enabled = false
	truck.add_node(Vector3(0.00, 0.5, 0.0), 10000.0)
	truck.set_uniform_velocity(Vector3.ZERO)
	var solver := VehiclePairContact.new()
	var before := car.total_momentum_kg_ms() + truck.total_momentum_kg_ms()
	car.prepare_substep(DT)
	truck.prepare_substep(DT)
	solver.apply_forces(car, PackedInt32Array([0]), truck, PackedInt32Array([0]), Vector3.RIGHT, DT, 0.0)
	car.integrate_substep(DT)
	truck.integrate_substep(DT)
	var after := car.total_momentum_kg_ms() + truck.total_momentum_kg_ms()
	var momentum_error := (after - before).length()
	if momentum_error > 0.001:
		failures.append("M11 compliant pair contact does not conserve linear momentum within numerical tolerance: %.9f kg m/s" % momentum_error)
	if truck.nodes[0].velocity_ms.x <= 0.0:
		failures.append("M11 compliant pair contact did not transfer forward momentum to the heavy body")
	if solver.contact_events != 1:
		failures.append("M11 pair-contact regression expected exactly one compliant contact event")

func _test_rear_impact_scenario(failures: Array[String]) -> void:
	var car := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		-1.0,
		90.0,
		100.0,
		Vector3(-6.0, 0.0, 0.0)
	)
	var truck := HeavyTruckBuilder.build(18000.0, 0.0, Vector3(2.5, 0.0, 0.0))
	var simulation := VehiclePairSimulation.new()
	var car_contacts := PackedInt32Array([
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 0),
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 1),
	])
	simulation.configure(car, car_contacts, truck, HeavyTruckBuilder.rear_contact_nodes())
	for _step in range(180):
		simulation.step(DT, 8)
	if simulation.contact.contact_events <= 0:
		failures.append("M3 rear-impact reference scenario never contacted the truck")
	if truck.average_velocity_ms().x <= 0.0:
		failures.append("M3 rear-impact scenario transferred no net momentum to the truck")
	if car.max_permanent_deformation_for_role(&"front_crush") <= 0.001:
		failures.append("M3 rear-impact scenario produced no measurable front-crush deformation")
	if simulation.momentum_error_kg_ms() > 0.05:
		failures.append("M3 coupled scenario has excessive linear-momentum error")
	if not _model_is_finite(car) or not _model_is_finite(truck):
		failures.append("M3 coupled scenario produced non-finite state")
	if not is_finite(simulation.energy_balance_relative_error()):
		failures.append("M3 coupled energy diagnostic became non-finite")

func _model_x_span(model: StructuralModel) -> float:
	var minimum := INF
	var maximum := -INF
	for node in model.nodes:
		minimum = minf(minimum, node.position_m.x)
		maximum = maxf(maximum, node.position_m.x)
	return maximum - minimum

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
