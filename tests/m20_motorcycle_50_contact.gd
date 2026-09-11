# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := ScenarioConfig.new()
	config.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-5.6, 0.0, 0.0)
	config.car_speed_kmh = 50.0
	config.apply_target_defaults(ScenarioConfig.TARGET_MOTORCYCLE)
	config.target_position_m = Vector3(3.2, 0.0, 0.0)
	config.target_mass_kg = 220.0
	config.duration_s = 4.0
	config.solver_substeps = 12
	_expect(config.validation_errors().is_empty(), "50 km/h motorcycle scenario failed preflight")
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "Production scene could not be loaded")
	if packed == null:
		_finish()
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame
	editor.call("_on_simulate_pressed")
	for _frame in range(1300):
		if not bool(editor.get("simulation_running")):
			break
		await physics_frame
	var motorcycle := editor.get("m17_motorcycle") as M20Motorcycle
	var primary := editor.get("car") as M17CompactHatchback
	_expect(not bool(editor.get("simulation_running")), "50 km/h motorcycle run did not complete")
	_expect(primary != null and primary.rigid_chassis != null, "Primary rigid chassis is missing")
	_expect(motorcycle != null and motorcycle.rigid_chassis != null, "Motorcycle rigid chassis is missing")
	if primary != null and primary.rigid_chassis != null:
		_expect(primary.rigid_chassis.non_ground_contact_events > 0, "50 km/h motorcycle run bypassed the primary physical contact")
	if motorcycle != null and motorcycle.rigid_chassis != null:
		_expect(motorcycle.rigid_chassis.non_ground_contact_events > 0, "50 km/h motorcycle run bypassed the motorcycle physical contact")
		_expect(motorcycle.rear_impact_deformation_m() > 0.01 or motorcycle.front_crush_deformation_m() > 0.01 or motorcycle.side_impact_deformation_m() > 0.01, "50 km/h motorcycle impact produced no visible local deformation")
		_expect(motorcycle.rear_impact_deformation_m() <= 0.241 and motorcycle.front_crush_deformation_m() <= 0.341 and motorcycle.side_impact_deformation_m() <= 0.201, "Motorcycle deformation exceeded its bounded envelope")
	editor.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("CrashVector 50 km/h motorcycle contact and deformation regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
