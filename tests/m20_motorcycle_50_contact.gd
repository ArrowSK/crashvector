# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _check_preimpact_energy_source()
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
		_expect(motorcycle.rider_rig != null and motorcycle.rider_rig.rider_body_count() == 2, "Motorcycle must provide the physical rider rig")
		_expect(motorcycle.rider_released_after_contact(), "Motorcycle rider must release only after the real contact")
		_expect(motorcycle.rear_impact_deformation_m() > 0.01 or motorcycle.front_crush_deformation_m() > 0.01 or motorcycle.side_impact_deformation_m() > 0.01, "50 km/h motorcycle impact produced no visible local deformation")
		_expect(motorcycle.rear_impact_deformation_m() <= 0.241 and motorcycle.front_crush_deformation_m() <= 0.341 and motorcycle.side_impact_deformation_m() <= 0.201, "Motorcycle deformation exceeded its bounded envelope")
	editor.queue_free()
	await process_frame
	_finish()

func _check_preimpact_energy_source() -> void:
	var motorcycle := M20Motorcycle.new()
	motorcycle.total_mass_kg = 220.0
	motorcycle.initial_speed_kmh = 100.0
	motorcycle.origin_offset_m = Vector3.ZERO
	motorcycle.auto_step = false
	root.add_child(motorcycle)
	await process_frame
	_expect(motorcycle.rigid_chassis != null, "Motorcycle pre-impact energy regression could not create the rigid chassis")
	if motorcycle.rigid_chassis == null:
		motorcycle.queue_free()
		await process_frame
		return

	var fixture := StaticBody3D.new()
	fixture.name = "MotorcyclePreImpactFixture"
	fixture.position = Vector3(2.4, 0.0, 0.0)
	root.add_child(fixture)
	motorcycle.rigid_chassis.previous_integrated_linear_velocity_ms = Vector3(5.0, 0.0, 0.0)
	motorcycle.rigid_chassis.last_integrated_linear_velocity_ms = Vector3(1.0, 0.0, 0.0)
	motorcycle.rigid_chassis.last_integrated_physics_frame = Engine.get_physics_frames()
	motorcycle.rigid_chassis.contact_samples.append({
		"collider_name": fixture.name,
		"collider": fixture,
		"position_local": Vector3(1.95, 0.5, 0.0),
		"impulse": Vector3.ZERO,
		"pre_contact_linear_velocity_ms": Vector3(5.0, 0.0, 0.0),
	})
	motorcycle.call("_m20_consume_contacts")
	var expected_energy := 0.5 * motorcycle.rigid_chassis.mass * 25.0
	_expect(absf(motorcycle.hybrid_front_collision_energy_j - expected_energy) < 0.01, "Motorcycle deformation energy used t=0 speed instead of the immediate pre-impact velocity")
	var initial_speed_ms := PhysicsMetrics.kmh_to_ms(motorcycle.initial_speed_kmh)
	var t0_energy := 0.5 * motorcycle.rigid_chassis.mass * initial_speed_ms * initial_speed_ms
	_expect(motorcycle.hybrid_front_collision_energy_j < t0_energy * 0.20, "Motorcycle deformation energy still retains an excessive t=0-speed floor")

	fixture.queue_free()
	motorcycle.queue_free()
	await process_frame

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
