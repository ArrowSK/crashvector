# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _check_heavy_truck_skin_origin()
	await _check_passenger_car_wheel_axis()
	await _check_high_speed_pedestrian_vertical_transfer()
	if failures.is_empty():
		print("CrashVector reported runtime presentation/stability regressions passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check_heavy_truck_skin_origin() -> void:
	var truck := M17HeavyTruck.new()
	truck.name = "RuntimeRegressionTruck"
	truck.origin_offset_m = Vector3(3.2, 0.0, 0.0)
	truck.auto_step = false
	root.add_child(truck)
	await process_frame
	var skin := M17HeavyTruckVisual.new()
	truck.add_child(skin)
	skin.configure(truck)
	await process_frame
	var offset := skin.global_position.distance_to(truck.rigid_chassis.global_position)
	_expect(offset < 0.08, "Heavy-truck presentation root is detached from its rigid chassis by %.3f m" % offset)
	var trailer_bottom := skin.global_transform * (skin.trailer_instance.position + Vector3.DOWN * 1.41)
	_expect(trailer_bottom.y < 0.90, "Heavy-truck trailer is visibly floating before simulation: bottom y=%.3f m" % trailer_bottom.y)
	truck.queue_free()
	await process_frame

func _check_passenger_car_wheel_axis() -> void:
	var car := M17CompactHatchback.new()
	car.name = "RuntimeRegressionCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.origin_offset_m = Vector3.ZERO
	car.auto_step = false
	root.add_child(car)
	await process_frame
	var skin := M16VehicleVisualRefined.new()
	car.add_child(skin)
	skin.configure(car)
	var forward_speed := PhysicsMetrics.kmh_to_ms(130.0)
	for node in car.model.nodes:
		node.velocity_ms = Vector3.RIGHT * forward_speed
	for _frame in range(900):
		skin._update_wheels(1.0 / 60.0)
	var reference := car.global_reference_transform().basis.orthonormalized()
	for i in range(skin.wheel_groups.size()):
		var axle_alignment := absf(skin.wheel_groups[i].basis.z.normalized().dot(reference.z.normalized()))
		_expect(axle_alignment > 0.999, "Passenger-car wheel %d left its physical lateral axle after sustained spin: %.6f" % [i, axle_alignment])
		_expect(absf(skin.wheel_tires[i].rotation.x - PI * 0.5) < 0.0001, "Passenger-car wheel %d accumulated an impossible child pitch" % i)
	car.queue_free()
	await process_frame

func _check_high_speed_pedestrian_vertical_transfer() -> void:
	var car := M17CompactHatchback.new()
	car.name = "RuntimeRegressionPedestrianCar"
	car.vehicle_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car.total_mass_kg = 1150.0
	car.initial_speed_kmh = 130.0
	car.origin_offset_m = Vector3(-5.6, 0.0, 0.0)
	car.auto_step = false
	root.add_child(car)
	var target := RoadUserArticulatedStableProxy3D.new()
	target.name = "RuntimeRegressionPedestrian"
	target.configure(ScenarioConfig.TARGET_PEDESTRIAN, RoadUserCatalog.PEDESTRIAN_ADULT, 75.0, 0.0, Vector3.ZERO, 0.0, false)
	root.add_child(target)
	await physics_frame
	car.begin_simulation()
	target.begin_simulation()
	target.apply_probe_contact(car.rigid_chassis)
	await physics_frame
	var vertical_speed := absf(target.center_of_mass_velocity_ms().y)
	_expect(target.impact_received, "High-speed pedestrian regression did not apply the production probe contact")
	_expect(vertical_speed < 2.2, "High-speed pedestrian probe transfer still creates an artificial vertical launch: %.3f m/s" % vertical_speed)
	car.end_simulation()
	target.end_simulation()
	car.queue_free()
	target.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
