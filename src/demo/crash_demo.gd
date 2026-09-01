# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node3D

@export_range(1.0, 100000.0, 1.0, "or_greater") var vehicle_mass_kg: float = 1150.0
@export_range(1.0, 300.0, 1.0, "or_greater") var vehicle_speed_kmh: float = 50.0

const BARRIER_X_M: float = 5.0

var vehicle: CompactHatchback
var metrics_label: Label
var event_label: Label

func _ready() -> void:
	_build_environment()
	_build_ui()
	_spawn_vehicle(vehicle_speed_kmh)
	_update_metrics()

func _physics_process(_delta: float) -> void:
	_update_metrics()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_R:
			_spawn_vehicle(vehicle_speed_kmh)
		KEY_1:
			vehicle_speed_kmh = 50.0
			_spawn_vehicle(vehicle_speed_kmh)
		KEY_2:
			vehicle_speed_kmh = 90.0
			_spawn_vehicle(vehicle_speed_kmh)
		KEY_3:
			vehicle_speed_kmh = 140.0
			_spawn_vehicle(vehicle_speed_kmh)
		KEY_D:
			if vehicle != null:
				vehicle.toggle_structure_debug()

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
	camera.position = Vector3(-0.5, 5.8, 14.5)
	add_child(camera)
	camera.look_at(Vector3(0.8, 0.85, 0.0), Vector3.UP)
	camera.current = true

	_create_static_box(
		"Road",
		Vector3(0.0, -0.25, 0.0),
		Vector3(22.0, 0.5, 7.0),
		Color(0.12, 0.13, 0.15)
	)
	_create_static_box(
		"RigidBarrier",
		Vector3(BARRIER_X_M + 0.3, 1.6, 0.0),
		Vector3(0.6, 3.2, 5.5),
		Color(0.55, 0.57, 0.60)
	)

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

func _spawn_vehicle(speed_kmh: float) -> void:
	if vehicle != null and is_instance_valid(vehicle):
		vehicle.queue_free()
	vehicle = CompactHatchback.new()
	vehicle.name = "GenericCompactHatchback"
	vehicle.total_mass_kg = vehicle_mass_kg
	vehicle.initial_speed_kmh = speed_kmh
	vehicle.barrier_x_m = BARRIER_X_M
	vehicle.solver_substeps = 6
	vehicle.show_structure = true
	add_child(vehicle)
	if event_label != null:
		event_label.text = "Event: approaching rigid barrier"

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(485.0, 370.0)
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
	title.text = "CrashVector — M2 Generic Compact Hatchback"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	var description := Label.new()
	description.text = "Procedural body shell mapped to a zone-based structural graph"
	column.add_child(description)

	metrics_label = Label.new()
	column.add_child(metrics_label)

	event_label = Label.new()
	event_label.text = "Event: approaching rigid barrier"
	column.add_child(event_label)

	var legend := Label.new()
	legend.text = "Green: safety cell  •  Cyan: crush structure  •  Yellow: near yield  •  Orange: permanent deformation  •  Red: failed"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend)

	var hint := Label.new()
	hint.text = "1 = 50 km/h   2 = 90 km/h   3 = 140 km/h   D = structure view   R = reset"
	column.add_child(hint)

func _update_metrics() -> void:
	if metrics_label == null or vehicle == null or vehicle.model == null:
		return
	var model := vehicle.model
	var speed_kmh := PhysicsMetrics.ms_to_kmh(vehicle.global_linear_velocity_ms().length())
	var angular_speed := vehicle.global_angular_velocity_rad_s().length()
	var translational_kj := VehicleKinematics.translational_kinetic_energy_j(model) / 1000.0
	var rotational_kj := VehicleKinematics.rotational_kinetic_energy_j(model) / 1000.0
	var deformation_motion_kj := VehicleKinematics.deformation_kinetic_energy_j(model) / 1000.0
	var plastic_kj := model.total_plastic_energy_j() / 1000.0
	var dissipated_kj := (
		model.total_damping_energy_j()
		+ model.total_fracture_energy_j()
		+ model.contact_dissipation_j
	) / 1000.0
	metrics_label.text = "Mass: %.0f kg\nInitial speed: %.0f km/h   Current COM speed: %.1f km/h\nInitial kinetic energy: %.1f kJ\nRigid translation: %.1f kJ   Rigid rotation: %.1f kJ\nInternal deformation motion: %.1f kJ   Angular speed: %.2f rad/s\nPlastic work: %.1f kJ   Other dissipation: %.1f kJ\nFront-crush permanent deformation: %.0f mm\nSafety-cell permanent deformation: %.0f mm\nBroken beams: %d / %d   Front bumper: %s\nEnergy-balance diagnostic error: %.2f%%" % [
		model.total_mass_kg(),
		vehicle.initial_speed_kmh,
		speed_kmh,
		model.initial_energy_j / 1000.0,
		translational_kj,
		rotational_kj,
		deformation_motion_kj,
		angular_speed,
		plastic_kj,
		dissipated_kj,
		vehicle.front_crush_deformation_m() * 1000.0,
		vehicle.safety_cell_deformation_m() * 1000.0,
		model.broken_beam_count(),
		model.beams.size(),
		"detached" if vehicle.front_bumper_detached else "attached",
		model.energy_balance_relative_error() * 100.0,
	]

	if model.first_contact_time_s >= 0.0:
		event_label.text = "Event: first barrier contact at %.4f s — %d contact impulses" % [
			model.first_contact_time_s,
			model.contact_events,
		]
