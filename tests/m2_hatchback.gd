# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const DT: float = 1.0 / 240.0

func _initialize() -> void:
	var failures: Array[String] = []
	_test_vehicle_architecture(failures)
	_test_global_kinematics(failures)
	_test_barrier_impact(failures)
	_test_determinism(failures)

	if failures.is_empty():
		print("CrashVector M2 compact-hatchback tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_vehicle_architecture(failures: Array[String]) -> void:
	var model := CompactHatchbackBuilder.build(1150.0, 50.0, 5.0)
	if model.nodes.size() != 28:
		failures.append("M2 hatchback must contain 28 structural nodes")
	if absf(model.total_mass_kg() - 1150.0) > 0.001:
		failures.append("M2 hatchback mass distribution does not sum to configured mass")
	for role in [&"rear_crush", &"safety_cell", &"front_transition", &"front_crush"]:
		if model.role_beam_count(role) <= 0:
			failures.append("M2 hatchback is missing structural zone: %s" % role)

	var minimum_safety_stiffness := INF
	var maximum_front_stiffness := 0.0
	for beam in model.beams:
		if beam.role == &"safety_cell":
			minimum_safety_stiffness = minf(minimum_safety_stiffness, beam.stiffness_n_m)
		elif beam.role == &"front_crush":
			maximum_front_stiffness = maxf(maximum_front_stiffness, beam.stiffness_n_m)
	if minimum_safety_stiffness <= maximum_front_stiffness:
		failures.append("Passenger safety cell is not stiffer than the front crush structure")
	if CompactHatchbackBuilder.wheel_anchor_indices().size() != 4:
		failures.append("M2 hatchback must expose four wheel anchors")

func _test_global_kinematics(failures: Array[String]) -> void:
	var model := CompactHatchbackBuilder.build(1150.0, 50.0, 5.0)
	var linear := VehicleKinematics.linear_velocity_ms(model)
	if absf(linear.x - PhysicsMetrics.kmh_to_ms(50.0)) > 0.000001:
		failures.append("Global translation extraction does not preserve initial vehicle speed")
	if VehicleKinematics.angular_velocity_rad_s(model).length() > 0.000001:
		failures.append("Uniform initial translation produced spurious global rotation")
	if VehicleKinematics.deformation_kinetic_energy_j(model) > 0.001:
		failures.append("Uniform initial translation produced spurious deformation kinetic energy")

	var transform := VehicleKinematics.reference_transform(
		model,
		CompactHatchbackBuilder.rear_reference_nodes(),
		CompactHatchbackBuilder.front_reference_nodes(),
		CompactHatchbackBuilder.left_reference_nodes(),
		CompactHatchbackBuilder.right_reference_nodes()
	)
	if transform.basis.x.dot(Vector3.RIGHT) < 0.99:
		failures.append("Vehicle reference frame does not point along the hatchback longitudinal axis")
	if transform.basis.y.dot(Vector3.UP) < 0.80:
		failures.append("Vehicle reference frame lost its expected up axis")

func _test_barrier_impact(failures: Array[String]) -> void:
	var model := CompactHatchbackBuilder.build(1150.0, 50.0, 2.15)
	for _step in range(120):
		model.step(DT, 6)
	if model.first_contact_time_s < 0.0:
		failures.append("M2 hatchback never contacted the barrier")
	if model.total_plastic_energy_j() <= 0.0:
		failures.append("M2 hatchback barrier impact produced no plastic work")
	if model.max_permanent_deformation_for_role(&"front_crush") <= 0.001:
		failures.append("M2 front crush zone produced no measurable permanent deformation")
	if not _model_is_finite(model):
		failures.append("M2 hatchback produced non-finite structural state")
	if not is_finite(model.energy_balance_relative_error()):
		failures.append("M2 energy-balance diagnostic became non-finite")

func _test_determinism(failures: Array[String]) -> void:
	var a := CompactHatchbackBuilder.build(1150.0, 90.0, 2.20)
	var b := CompactHatchbackBuilder.build(1150.0, 90.0, 2.20)
	for _step in range(80):
		a.step(DT, 6)
		b.step(DT, 6)
	var signature_a := a.state_signature()
	var signature_b := b.state_signature()
	if signature_a.size() != signature_b.size():
		failures.append("M2 determinism signatures differ in length")
		return
	for i in range(signature_a.size()):
		if absf(signature_a[i] - signature_b[i]) > 0.000000001:
			failures.append("M2 solver is not deterministic at signature index %d" % i)
			return

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
