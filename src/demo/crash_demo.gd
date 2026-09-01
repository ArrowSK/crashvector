extends Node3D

@export_range(1.0, 100000.0, 1.0, "or_greater") var vehicle_mass_kg: float = 1150.0
@export_range(1.0, 300.0, 1.0, "or_greater") var vehicle_speed_kmh: float = 50.0

var vehicle: ImpactVehicle
var telemetry: TelemetryRecorder
var metrics_label: Label
var event_label: Label
var impact_detected: bool = false

func _ready() -> void:
	_build_environment()
	_build_ui()
	vehicle = _spawn_test_vehicle()
	telemetry = TelemetryRecorder.new()
	telemetry.name = "TelemetryRecorder"
	add_child(telemetry)
	telemetry.configure(vehicle)
	vehicle.body_entered.connect(_on_vehicle_body_entered)
	_update_metrics()

func _physics_process(_delta: float) -> void:
	_update_metrics()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.48, 0.55)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 7.5, 16.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
	camera.current = true

	_create_static_box(
		"Road",
		Vector3(0.0, -0.25, 0.0),
		Vector3(40.0, 0.5, 8.0),
		Color(0.12, 0.13, 0.15)
	)
	_create_static_box(
		"RigidBarrier",
		Vector3(8.0, 1.5, 0.0),
		Vector3(0.6, 3.0, 6.0),
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

func _spawn_test_vehicle() -> ImpactVehicle:
	var body := ImpactVehicle.new()
	body.name = "CompactHatchbackTestSled"
	body.configured_mass_kg = vehicle_mass_kg
	body.initial_speed_kmh = vehicle_speed_kmh
	body.initial_direction = Vector3.RIGHT
	body.position = Vector3(-8.0, 0.75, 0.0)
	body.linear_damp = 0.02
	body.angular_damp = 0.2
	add_child(body)

	var vehicle_size := Vector3(4.0, 1.5, 1.8)
	var shape := BoxShape3D.new()
	shape.size = vehicle_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh_resource := BoxMesh.new()
	mesh_resource.size = vehicle_size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.42, 0.78)
	material.metallic = 0.25
	material.roughness = 0.35
	mesh_resource.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh_resource
	body.add_child(mesh_instance)
	return body

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(370.0, 170.0)
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
	title.text = "CrashVector — M0 Physics Skeleton"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	metrics_label = Label.new()
	column.add_child(metrics_label)

	event_label = Label.new()
	event_label.text = "Event: approaching rigid barrier"
	column.add_child(event_label)

	var hint := Label.new()
	hint.text = "R — reset scenario"
	column.add_child(hint)

func _update_metrics() -> void:
	if metrics_label == null or vehicle == null:
		return
	var speed_kmh := PhysicsMetrics.ms_to_kmh(vehicle.linear_velocity.length())
	var energy_kj := vehicle.current_kinetic_energy_j() / 1000.0
	var momentum := vehicle.current_momentum_kg_ms().length()
	metrics_label.text = "Mass: %.0f kg\nSpeed: %.1f km/h\nKinetic energy: %.1f kJ\nMomentum: %.0f kg·m/s" % [
		vehicle.mass,
		speed_kmh,
		energy_kj,
		momentum,
	]

func _on_vehicle_body_entered(body: Node) -> void:
	if impact_detected:
		return
	if body.name == "RigidBarrier":
		impact_detected = true
		event_label.text = "Event: first barrier contact at %.4f s" % telemetry.elapsed_s
