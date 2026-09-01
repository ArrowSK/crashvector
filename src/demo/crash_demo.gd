# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node3D

@export_range(1.0, 300.0, 1.0, "or_greater") var vehicle_speed_kmh: float = 50.0

const CAR_ORIGIN := Vector3(-6.0, 0.0, 0.0)
const TRUCK_ORIGIN := Vector3(2.5, 0.0, 0.0)

var car: CompactHatchback
var truck: HeavyTruck
var pair_simulation: VehiclePairSimulation
var metrics_label: Label
var event_label: Label
var car_presets: Array[StringName] = PassengerCarCatalog.preset_ids()
var car_preset_index: int = 0
var truck_mass_presets := PackedFloat64Array([18000.0, 32000.0, 40000.0])
var truck_mass_index: int = 0
var truck_speed_presets := PackedFloat64Array([0.0, 50.0, 80.0])
var truck_speed_index: int = 0

func _ready() -> void:
	_build_environment()
	_build_ui()
	_spawn_scenario()
	_update_metrics()

func _physics_process(delta: float) -> void:
	if pair_simulation != null:
		pair_simulation.step(delta, 8)
		if car != null:
			car.step_external(delta)
		if truck != null:
			truck.step_external(delta)
	_update_metrics()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_R:
			_spawn_scenario()
		KEY_1:
			vehicle_speed_kmh = 50.0
			_spawn_scenario()
		KEY_2:
			vehicle_speed_kmh = 90.0
			_spawn_scenario()
		KEY_3:
			vehicle_speed_kmh = 140.0
			_spawn_scenario()
		KEY_V:
			car_preset_index = (car_preset_index + 1) % car_presets.size()
			_spawn_scenario()
		KEY_M:
			truck_mass_index = (truck_mass_index + 1) % truck_mass_presets.size()
			_spawn_scenario()
		KEY_K:
			truck_speed_index = (truck_speed_index + 1) % truck_speed_presets.size()
			_spawn_scenario()
		KEY_D:
			if car != null:
				car.toggle_structure_debug()
			if truck != null:
				truck.toggle_structure_debug()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.48, 0.55)
	environment.ambient_light_energy = 0.85
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(3.0, 7.8, 22.0)
	add_child(camera)
	camera.look_at(Vector3(3.0, 1.25, 0.0), Vector3.UP)
	camera.current = true

	_create_static_box("Road", Vector3(3.0, -0.25, 0.0), Vector3(32.0, 0.5, 8.0), Color(0.12, 0.13, 0.15))

func _create_static_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh_resource := BoxMesh.new()
	mesh_resource.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_resource.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh_resource
	body.add_child(mesh_instance)
	return body

func _spawn_scenario() -> void:
	if car != null and is_instance_valid(car):
		car.queue_free()
	if truck != null and is_instance_valid(truck):
		truck.queue_free()
	pair_simulation = null

	var preset_id := car_presets[car_preset_index]
	car = CompactHatchback.new()
	car.name = "GenericPassengerCar"
	car.vehicle_preset_id = preset_id
	car.total_mass_kg = PassengerCarCatalog.default_mass_kg(preset_id)
	car.initial_speed_kmh = vehicle_speed_kmh
	car.origin_offset_m = CAR_ORIGIN
	car.auto_step = false
	car.show_structure = true
	add_child(car)

	truck = HeavyTruck.new()
	truck.name = "GenericHeavyTruck"
	truck.total_mass_kg = truck_mass_presets[truck_mass_index]
	truck.initial_speed_kmh = truck_speed_presets[truck_speed_index]
	truck.origin_offset_m = TRUCK_ORIGIN
	truck.auto_step = false
	truck.show_structure = false
	add_child(truck)

	pair_simulation = VehiclePairSimulation.new()
	var car_contact_nodes := PackedInt32Array([
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 0),
		CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 1),
	])
	pair_simulation.configure(car.model, car_contact_nodes, truck.model, HeavyTruckBuilder.rear_contact_nodes())
	if event_label != null:
		event_label.text = "Event: approaching truck rear underride structure"

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(540.0, 430.0)
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = "CrashVector — M3 Passenger Car vs Heavy Truck"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	var description := Label.new()
	description.text = "Generic European vehicle classes; no production model names or OEM claims"
	column.add_child(description)
	metrics_label = Label.new()
	column.add_child(metrics_label)
	event_label = Label.new()
	column.add_child(event_label)
	var hint := Label.new()
	hint.text = "1/2/3 = car 50/90/140 km/h   V = car class   M = truck mass   K = truck speed   D = structures   R = reset"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)

func _update_metrics() -> void:
	if metrics_label == null or car == null or truck == null or pair_simulation == null:
		return
	var car_speed := PhysicsMetrics.ms_to_kmh(car.global_linear_velocity_ms().length())
	var truck_speed := PhysicsMetrics.ms_to_kmh(truck.global_linear_velocity_ms().length())
	var car_initial_energy_kj := PhysicsMetrics.kinetic_energy_from_speed_kmh(car.model.total_mass_kg(), car.initial_speed_kmh) / 1000.0
	metrics_label.text = "Car class: %s\nCar mass: %.0f kg   Initial speed: %.0f km/h   Current: %.1f km/h\nTruck mass: %.0f kg   Initial speed: %.0f km/h   Current: %.1f km/h\nCurrent closing speed: %.1f km/h\nCar initial kinetic energy: %.1f kJ\nCar front-crush permanent deformation: %.0f mm\nCar safety-cell permanent deformation: %.0f mm\nTruck rear-guard permanent deformation: %.0f mm\nPair contacts: %d   Peak node penetration: %.1f mm\nMomentum-balance error: %.3f kg·m/s\nEnergy-balance diagnostic error: %.2f%%" % [
		car.vehicle_class_name(),
		car.model.total_mass_kg(), car.initial_speed_kmh, car_speed,
		truck.model.total_mass_kg(), truck.initial_speed_kmh, truck_speed,
		pair_simulation.closing_speed_kmh(),
		car_initial_energy_kj,
		car.front_crush_deformation_m() * 1000.0,
		car.safety_cell_deformation_m() * 1000.0,
		truck.rear_guard_deformation_m() * 1000.0,
		pair_simulation.contact.contact_events,
		pair_simulation.contact.maximum_penetration_m * 1000.0,
		pair_simulation.momentum_error_kg_ms(),
		pair_simulation.energy_balance_relative_error() * 100.0,
	]
	if pair_simulation.contact.first_contact_time_s >= 0.0:
		event_label.text = "Event: first car/truck contact at %.4f s" % pair_simulation.contact.first_contact_time_s
