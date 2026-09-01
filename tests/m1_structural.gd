# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const DT: float = 1.0 / 240.0

func _initialize() -> void:
	var failures: Array[String] = []
	_test_beam_plasticity(failures)
	_test_beam_failure(failures)
	_test_sled_impact(failures)
	_test_determinism(failures)

	if failures.is_empty():
		print("CrashVector M1 structural tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_beam_plasticity(failures: Array[String]) -> void:
	var nodes: Array[StructuralNode] = [
		StructuralNode.new(Vector3.ZERO, 10.0, true),
		StructuralNode.new(Vector3.RIGHT, 10.0, true),
	]
	var beam := StructuralBeam.new(0, 1, nodes, &"test", 100000.0, 0.0, 0.05, 0.40, 0.60, 20.0)
	nodes[1].position_m = Vector3(0.75, 0.0, 0.0)
	for _step in range(120):
		beam.solve(nodes, DT)
	if beam.rest_length_m >= 0.98:
		failures.append("Plastic beam did not acquire permanent compression")
	if beam.plastic_energy_j <= 0.0:
		failures.append("Plastic beam did not record plastic work")
	if beam.broken:
		failures.append("Plastic beam failed below configured break strain")

func _test_beam_failure(failures: Array[String]) -> void:
	var nodes: Array[StructuralNode] = [
		StructuralNode.new(Vector3.ZERO, 10.0, true),
		StructuralNode.new(Vector3.RIGHT, 10.0, true),
	]
	var beam := StructuralBeam.new(0, 1, nodes, &"test", 100000.0, 0.0, 0.05, 0.40, 0.60, 20.0)
	nodes[1].position_m = Vector3(0.25, 0.0, 0.0)
	beam.solve(nodes, DT)
	if not beam.broken:
		failures.append("Beam did not fail above configured break strain")

func _test_sled_impact(failures: Array[String]) -> void:
	var model := StructuralSledBuilder.build_compact_sled(1150.0, 50.0, 5.0)
	for _step in range(180):
		model.step(DT, 4)
	if model.first_contact_time_s < 0.0:
		failures.append("Structural sled never contacted the barrier")
	if model.total_plastic_energy_j() <= 0.0:
		failures.append("50 km/h barrier impact produced no plastic work")
	if model.max_permanent_deformation_m() <= 0.002:
		failures.append("50 km/h barrier impact produced no measurable permanent deformation")
	if not _model_is_finite(model):
		failures.append("Structural sled produced non-finite state")
	if not is_finite(model.energy_balance_relative_error()):
		failures.append("Energy-balance diagnostic became non-finite")

func _test_determinism(failures: Array[String]) -> void:
	var a := StructuralSledBuilder.build_compact_sled(1150.0, 90.0, 5.0)
	var b := StructuralSledBuilder.build_compact_sled(1150.0, 90.0, 5.0)
	for _step in range(120):
		a.step(DT, 4)
		b.step(DT, 4)
	var signature_a := a.state_signature()
	var signature_b := b.state_signature()
	if signature_a.size() != signature_b.size():
		failures.append("Determinism signatures differ in length")
		return
	for i in range(signature_a.size()):
		if absf(signature_a[i] - signature_b[i]) > 0.000000001:
			failures.append("Structural solver is not deterministic at signature index %d" % i)
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
