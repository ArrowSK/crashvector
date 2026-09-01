# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const DT: float = 1.0 / 240.0

func _initialize() -> void:
	var failures: Array[String] = []
	_test_structural_snapshot_round_trip(failures)
	_test_recording_lookup(failures)
	_test_static_crash_recording_and_analysis(failures)

	if failures.is_empty():
		print("CrashVector M5 analysis and replay tests passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_structural_snapshot_round_trip(failures: Array[String]) -> void:
	var model := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		1150.0,
		50.0,
		100.0,
		Vector3.ZERO
	)
	var original_signature := model.state_signature()
	var snapshot := StructuralSnapshot.capture(model)
	model.nodes[0].position_m += Vector3(3.0, 2.0, -1.0)
	model.nodes[0].velocity_ms = Vector3(99.0, 1.0, 2.0)
	model.beams[0].rest_length_m *= 0.6
	model.beams[0].broken = true
	if not StructuralSnapshot.apply(model, snapshot):
		failures.append("M5 structural snapshot could not be reapplied")
		return
	var restored_signature := model.state_signature()
	if original_signature.size() != restored_signature.size():
		failures.append("M5 structural snapshot changed state signature size")
		return
	for i in range(original_signature.size()):
		if absf(original_signature[i] - restored_signature[i]) > 0.000000001:
			failures.append("M5 structural snapshot failed to restore state at signature index %d" % i)
			return

func _test_recording_lookup(failures: Array[String]) -> void:
	var recording := ReplayRecording.new()
	recording.add_frame({"time_s": 0.0})
	recording.add_frame({"time_s": 0.5})
	recording.add_frame({"time_s": 1.0})
	if recording.frame_index_at_time(0.10) != 0:
		failures.append("M5 replay lookup did not select nearest early frame")
	if recording.frame_index_at_time(0.76) != 2:
		failures.append("M5 replay lookup did not select nearest late frame")
	if absf(float(recording.frame_at_time(0.48).get("time_s", -1.0)) - 0.5) > 0.000001:
		failures.append("M5 replay frame lookup returned wrong timestamp")

func _test_static_crash_recording_and_analysis(failures: Array[String]) -> void:
	var model := PassengerCarBuilder.build(
		PassengerCarCatalog.B_SEGMENT_HATCHBACK,
		1150.0,
		50.0,
		100.0,
		Vector3(-3.0, 0.0, 0.0)
	)
	var simulation := VehicleStaticSimulation.new()
	simulation.configure(model, ScenarioConfig.TARGET_WALL, Vector3.ZERO, 0.0, 0.55, 0.03)
	var recorder := ReplayRecorder.new()
	recorder.begin(1.0 / 120.0)
	recorder.capture(0.0, model, null, _metrics_for(model), {}, _context_for(simulation), {}, {}, true)

	for _step in range(220):
		simulation.step(DT, 8)
		recorder.capture(simulation.elapsed_s, model, null, _metrics_for(model), {}, _context_for(simulation))
	recorder.force_final(simulation.elapsed_s, model, null, _metrics_for(model), {}, _context_for(simulation))

	if recorder.recording.frames.size() < 50:
		failures.append("M5 replay recorder captured too few samples")
	var final_velocity := model.average_velocity_ms()
	var report := CrashAnalysis.analyze(recorder.recording)
	if report.is_empty():
		failures.append("M5 crash analysis returned no report")
		return
	if float(report.get("final_delta_v_kmh", 0.0)) <= 1.0:
		failures.append("M5 crash analysis reported implausibly small delta-v for wall impact")
	if float(report.get("peak_deceleration_g", 0.0)) <= 0.0:
		failures.append("M5 crash analysis detected no crash pulse")
	if float(report.get("max_front_crush_mm", 0.0)) <= 0.5:
		failures.append("M5 crash analysis detected no meaningful front-crush deformation")
	var pulse: Variant = report.get("crash_pulse_series", [])
	if not (pulse is Array) or pulse.is_empty():
		failures.append("M5 crash-pulse graph series is empty")
	var deformation: Variant = report.get("front_crush_series", [])
	if not (deformation is Array) or deformation.is_empty():
		failures.append("M5 deformation graph series is empty")
	if recorder.recording.marker_time(&"first_contact") < 0.0:
		failures.append("M5 event markers do not include first contact")
	if recorder.recording.marker_time(&"peak_loading") < 0.0:
		failures.append("M5 event markers do not include peak loading")

	var first_frame := recorder.recording.first_frame()
	var first_state: Variant = first_frame.get("primary_state", {})
	if not (first_state is Dictionary) or not StructuralSnapshot.apply(model, first_state):
		failures.append("M5 could not restore the first recorded replay frame")
		return
	var restored_velocity := model.average_velocity_ms()
	if absf(restored_velocity.length() - PhysicsMetrics.kmh_to_ms(50.0)) > 0.00001:
		failures.append("M5 replay restoration did not recover initial vehicle speed")
	if restored_velocity.distance_to(final_velocity) < 0.5:
		failures.append("M5 replay frame is not independent from final live-physics state")

func _metrics_for(model: StructuralModel) -> Dictionary:
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
	}

func _context_for(simulation: VehicleStaticSimulation) -> Dictionary:
	return {
		"contact_count": simulation.contact.contact_events,
		"energy_balance_relative_error": simulation.energy_balance_relative_error(),
		"contact_dissipation_j": simulation.contact.accumulated_dissipation_j,
	}
