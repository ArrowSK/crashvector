# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node3D

var PRIMARY_FRONT_CONTACT_NODES: PackedInt32Array = PackedInt32Array([
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 0),
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 1),
])
var TARGET_REAR_CONTACT_NODES: PackedInt32Array = PackedInt32Array([
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.REAR_STATION, 0),
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.REAR_STATION, 1),
])
var TARGET_FRONT_CONTACT_NODES: PackedInt32Array = PackedInt32Array([
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 0),
	CompactHatchbackBuilder.node_index(CompactHatchbackBuilder.FRONT_STATION, 1),
])

var scenario := ScenarioConfig.new()
var car: CompactHatchback
var target_car: CompactHatchback
var truck: HeavyTruck
var obstacle: StaticObstacle3D
var pair_simulation: VehiclePairSimulation
var static_simulation: VehicleStaticSimulation
var simulation_running: bool = false
var simulation_paused: bool = false
var selected_object: StringName = &"car"
var current_scenario_path: String = ""
var preview_rebuild_requested: bool = false
var syncing_ui: bool = false
var drag_mode: StringName = &""
var last_ground_point := Vector3.ZERO

var camera: Camera3D
var status_label: Label
var metrics_label: Label
var inspector_column: VBoxContainer
var title_edit: LineEdit
var duration_spin: SpinBox
var friction_spin: SpinBox
var restitution_spin: SpinBox
var substeps_spin: SpinBox
var structure_check: CheckButton
var pause_button: Button
var car_class_option: OptionButton
var mass_spin: SpinBox
var speed_spin: SpinBox
var x_spin: SpinBox
var z_spin: SpinBox
var heading_spin: SpinBox
var save_dialog: FileDialog
var open_dialog: FileDialog

func _ready() -> void:
	_build_environment()
	_build_ui()
	_sync_ui_from_scenario()
	_rebuild_preview()
	_frame_scenario()

func _physics_process(delta: float) -> void:
	if simulation_running and not simulation_paused:
		if pair_simulation != null:
			pair_simulation.step(delta, scenario.solver_substeps)
		elif static_simulation != null:
			static_simulation.step(delta, scenario.solver_substeps)
		if car != null:
			car.step_external(delta)
		if target_car != null:
			target_car.step_external(delta)
		if truck != null:
			truck.step_external(delta)
		if _simulation_elapsed_s() >= scenario.duration_s:
			simulation_running = false
			simulation_paused = false
			pause_button.disabled = true
			pause_button.text = "Pause"
			status_label.text = "Simulation complete — Reset returns to editable preview"
	_update_metrics()

func _unhandled_input(event: InputEvent) -> void:
	if simulation_running:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var point: Variant = _screen_to_ground(event.position)
				if point != null:
					_select_nearest_object(point)
					last_ground_point = point
					drag_mode = &"move"
			else:
				drag_mode = &""
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var point: Variant = _screen_to_ground(event.position)
				if point != null:
					_select_nearest_object(point)
					drag_mode = &"rotate"
			else:
				drag_mode = &""
	elif event is InputEventMouseMotion:
		if drag_mode == &"move":
			var point: Variant = _screen_to_ground(event.position)
			if point != null:
				var delta := Vector3(point.x - last_ground_point.x, 0.0, point.z - last_ground_point.z)
				_move_selected(delta)
				last_ground_point = point
		elif drag_mode == &"rotate":
			_rotate_selected(-event.relative.x * 0.35)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.028, 0.035, 0.050)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.50, 0.53, 0.60)
	environment.ambient_light_energy = 0.90
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.name = "EditorCamera"
	add_child(camera)
	camera.current = true

	_create_static_box("Road", Vector3(3.0, -0.25, 0.0), Vector3(48.0, 0.5, 12.0), Color(0.10, 0.11, 0.13))
	for x in range(-20, 25, 4):
		_create_static_box("LaneMark%d" % x, Vector3(float(x), 0.012, 0.0), Vector3(2.0, 0.02, 0.08), Color(0.75, 0.75, 0.70))

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
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	body.add_child(instance)
	return body

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "EditorUI"
	add_child(canvas)

	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 10.0
	top.offset_top = 10.0
	top.offset_right = -10.0
	top.offset_bottom = 58.0
	canvas.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 7)
	top.add_child(top_row)
	_add_toolbar_button(top_row, "New", _on_new_pressed)
	_add_toolbar_button(top_row, "Open", _on_open_pressed)
	_add_toolbar_button(top_row, "Save", _on_save_pressed)
	_add_toolbar_button(top_row, "Simulate", _on_simulate_pressed)
	pause_button = _add_toolbar_button(top_row, "Pause", _on_pause_pressed)
	pause_button.disabled = true
	_add_toolbar_button(top_row, "Reset", _on_reset_pressed)
	_add_toolbar_button(top_row, "Frame", _frame_scenario)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var title_label := Label.new()
	title_label.text = "Scenario"
	top_row.add_child(title_label)
	title_edit = LineEdit.new()
	title_edit.custom_minimum_size.x = 220.0
	title_edit.text_changed.connect(_on_title_changed)
	top_row.add_child(title_edit)
	structure_check = CheckButton.new()
	structure_check.text = "Structure"
	structure_check.toggled.connect(_on_structure_toggled)
	top_row.add_child(structure_check)

	var left := PanelContainer.new()
	left.anchor_bottom = 1.0
	left.offset_left = 10.0
	left.offset_top = 68.0
	left.offset_right = 265.0
	left.offset_bottom = -150.0
	canvas.add_child(left)
	var left_margin := _with_margin(left, 12)
	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 6)
	left_margin.add_child(left_column)
	var objects_title := Label.new()
	objects_title.text = "Objects"
	objects_title.add_theme_font_size_override("font_size", 18)
	left_column.add_child(objects_title)
	var primary_label := Label.new()
	primary_label.text = "Primary vehicle"
	left_column.add_child(primary_label)
	var primary_button := Button.new()
	primary_button.text = "Passenger Car"
	primary_button.pressed.connect(_on_select_car)
	left_column.add_child(primary_button)
	var target_label := Label.new()
	target_label.text = "Impact target"
	left_column.add_child(target_label)
	for target_id in ScenarioConfig.target_ids():
		var button := Button.new()
		button.text = ScenarioConfig.target_display_name(target_id)
		button.pressed.connect(_on_target_palette_pressed.bind(target_id))
		left_column.add_child(button)
	var separator := HSeparator.new()
	left_column.add_child(separator)
	var simulation_title := Label.new()
	simulation_title.text = "Simulation"
	simulation_title.add_theme_font_size_override("font_size", 16)
	left_column.add_child(simulation_title)
	duration_spin = _add_spin(left_column, "Duration (s)", 0.5, 20.0, 0.5)
	duration_spin.value_changed.connect(_on_common_spin_changed.bind(&"duration"))
	friction_spin = _add_spin(left_column, "Contact friction", 0.0, 1.5, 0.05)
	friction_spin.value_changed.connect(_on_common_spin_changed.bind(&"friction"))
	restitution_spin = _add_spin(left_column, "Restitution", 0.0, 0.5, 0.01)
	restitution_spin.value_changed.connect(_on_common_spin_changed.bind(&"restitution"))
	substeps_spin = _add_spin(left_column, "Solver substeps", 1.0, 16.0, 1.0)
	substeps_spin.value_changed.connect(_on_common_spin_changed.bind(&"substeps"))

	var right := PanelContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -345.0
	right.offset_top = 68.0
	right.offset_right = -10.0
	right.offset_bottom = -150.0
	canvas.add_child(right)
	var right_margin := _with_margin(right, 12)
	inspector_column = VBoxContainer.new()
	inspector_column.add_theme_constant_override("separation", 6)
	right_margin.add_child(inspector_column)

	var bottom := PanelContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 275.0
	bottom.offset_top = -140.0
	bottom.offset_right = -355.0
	bottom.offset_bottom = -10.0
	canvas.add_child(bottom)
	var bottom_margin := _with_margin(bottom, 10)
	var bottom_column := VBoxContainer.new()
	bottom_column.add_theme_constant_override("separation", 4)
	bottom_margin.add_child(bottom_column)
	status_label = Label.new()
	status_label.text = "Preview"
	status_label.add_theme_font_size_override("font_size", 16)
	bottom_column.add_child(status_label)
	metrics_label = Label.new()
	metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_column.add_child(metrics_label)
	var interaction_hint := Label.new()
	interaction_hint.text = "Central view: left-drag moves the selected object • right-drag rotates it • car-vs-car supports rear-end and near head-on layouts in M4"
	interaction_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_column.add_child(interaction_hint)

	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.filters = PackedStringArray(["*.crashvector.json ; CrashVector Scenario"])
	save_dialog.file_selected.connect(_on_save_path_selected)
	canvas.add_child(save_dialog)
	open_dialog = FileDialog.new()
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.filters = PackedStringArray(["*.crashvector.json ; CrashVector Scenario", "*.json ; JSON"])
	open_dialog.file_selected.connect(_on_open_path_selected)
	canvas.add_child(open_dialog)

func _with_margin(parent: Control, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	parent.add_child(margin)
	return margin

func _add_toolbar_button(parent: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _add_spin(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.custom_minimum_size.x = 110.0
	row.add_child(spin)
	return spin

func _rebuild_inspector() -> void:
	for child in inspector_column.get_children():
		inspector_column.remove_child(child)
		child.queue_free()
	var inspector_title := Label.new()
	inspector_title.add_theme_font_size_override("font_size", 18)
	inspector_column.add_child(inspector_title)
	var selected_is_car := selected_object == &"car"
	var selected_is_target_car := selected_object == &"target" and scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR
	if selected_is_car or selected_is_target_car:
		inspector_title.text = "Primary Passenger Car" if selected_is_car else "Target Passenger Car"
		var class_row := HBoxContainer.new()
		inspector_column.add_child(class_row)
		var class_label := Label.new()
		class_label.text = "Vehicle class"
		class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		class_row.add_child(class_label)
		car_class_option = OptionButton.new()
		for id in PassengerCarCatalog.preset_ids():
			car_class_option.add_item(PassengerCarCatalog.display_name(id))
		class_row.add_child(car_class_option)
		car_class_option.item_selected.connect(_on_car_class_selected)
		mass_spin = _add_spin(inspector_column, "Mass (kg)", 500.0, 5000.0, 5.0)
		speed_spin = _add_spin(inspector_column, "Speed (km/h)", 0.0, 300.0, 1.0)
		mass_spin.value_changed.connect(_on_object_spin_changed.bind(&"mass"))
		speed_spin.value_changed.connect(_on_object_spin_changed.bind(&"speed"))
	elif scenario.target_type == ScenarioConfig.TARGET_TRUCK:
		inspector_title.text = "Heavy Truck"
		car_class_option = null
		mass_spin = _add_spin(inspector_column, "Mass (kg)", 3500.0, 60000.0, 100.0)
		speed_spin = _add_spin(inspector_column, "Speed (km/h)", 0.0, 140.0, 1.0)
		mass_spin.value_changed.connect(_on_object_spin_changed.bind(&"mass"))
		speed_spin.value_changed.connect(_on_object_spin_changed.bind(&"speed"))
	else:
		inspector_title.text = ScenarioConfig.target_display_name(scenario.target_type)
		car_class_option = null
		mass_spin = null
		speed_spin = null
		var fixed_label := Label.new()
		fixed_label.text = "Static object — externally fixed in the current solver"
		fixed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_column.add_child(fixed_label)
	x_spin = _add_spin(inspector_column, "Position X (m)", -25.0, 25.0, 0.1)
	z_spin = _add_spin(inspector_column, "Position Z (m)", -5.0, 5.0, 0.1)
	heading_spin = _add_spin(inspector_column, "Heading (deg)", -180.0, 180.0, 1.0)
	x_spin.value_changed.connect(_on_object_spin_changed.bind(&"x"))
	z_spin.value_changed.connect(_on_object_spin_changed.bind(&"z"))
	heading_spin.value_changed.connect(_on_object_spin_changed.bind(&"heading"))
	var rotate_row := HBoxContainer.new()
	inspector_column.add_child(rotate_row)
	var rotate_left := Button.new()
	rotate_left.text = "Rotate -5°"
	rotate_left.pressed.connect(_rotate_selected.bind(-5.0))
	rotate_row.add_child(rotate_left)
	var rotate_right := Button.new()
	rotate_right.text = "Rotate +5°"
	rotate_right.pressed.connect(_rotate_selected.bind(5.0))
	rotate_row.add_child(rotate_right)
	var note := Label.new()
	note.text = "Passenger-car presets represent generic B/C/D size classes, not production models or manufacturer crash performance."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_column.add_child(note)
	_sync_current_object_fields()

func _sync_ui_from_scenario() -> void:
	syncing_ui = true
	title_edit.text = scenario.title
	duration_spin.value = scenario.duration_s
	friction_spin.value = scenario.contact_friction
	restitution_spin.value = scenario.restitution
	substeps_spin.value = scenario.solver_substeps
	structure_check.button_pressed = scenario.show_structure
	_rebuild_inspector()
	syncing_ui = false

func _sync_current_object_fields() -> void:
	if inspector_column == null:
		return
	syncing_ui = true
	if selected_object == &"car":
		_select_class_option(scenario.car_preset_id)
		if mass_spin != null:
			mass_spin.value = scenario.car_mass_kg
		if speed_spin != null:
			speed_spin.value = scenario.car_speed_kmh
		if x_spin != null:
			x_spin.value = scenario.car_position_m.x
		if z_spin != null:
			z_spin.value = scenario.car_position_m.z
		if heading_spin != null:
			heading_spin.value = scenario.car_heading_deg
	else:
		if scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR:
			_select_class_option(scenario.target_car_preset_id)
		if mass_spin != null:
			mass_spin.value = scenario.target_mass_kg
		if speed_spin != null:
			speed_spin.value = scenario.target_speed_kmh
		if x_spin != null:
			x_spin.value = scenario.target_position_m.x
		if z_spin != null:
			z_spin.value = scenario.target_position_m.z
		if heading_spin != null:
			heading_spin.value = scenario.target_heading_deg
	syncing_ui = false

func _select_class_option(id: StringName) -> void:
	if car_class_option == null:
		return
	var ids := PassengerCarCatalog.preset_ids()
	var index := ids.find(id)
	car_class_option.select(maxi(index, 0))

func _on_select_car() -> void:
	selected_object = &"car"
	_rebuild_inspector()

func _on_target_palette_pressed(target_id: StringName) -> void:
	selected_object = &"target"
	if scenario.target_type != target_id:
		scenario.target_type = target_id
		if target_id == ScenarioConfig.TARGET_PASSENGER_CAR:
			scenario.target_car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
			scenario.target_mass_kg = PassengerCarCatalog.default_mass_kg(scenario.target_car_preset_id)
			scenario.target_speed_kmh = 0.0
		elif target_id == ScenarioConfig.TARGET_TRUCK:
			scenario.target_mass_kg = 18000.0
			scenario.target_speed_kmh = 0.0
		_request_preview_rebuild()
	_rebuild_inspector()

func _on_car_class_selected(index: int) -> void:
	if syncing_ui:
		return
	var ids := PassengerCarCatalog.preset_ids()
	if index < 0 or index >= ids.size():
		return
	if selected_object == &"car":
		scenario.car_preset_id = ids[index]
		scenario.car_mass_kg = PassengerCarCatalog.default_mass_kg(scenario.car_preset_id)
	else:
		scenario.target_car_preset_id = ids[index]
		scenario.target_mass_kg = PassengerCarCatalog.default_mass_kg(scenario.target_car_preset_id)
	_sync_current_object_fields()
	_request_preview_rebuild()

func _on_object_spin_changed(value: float, field: StringName) -> void:
	if syncing_ui:
		return
	if selected_object == &"car":
		match field:
			&"mass": scenario.car_mass_kg = value
			&"speed": scenario.car_speed_kmh = value
			&"x": scenario.car_position_m.x = value
			&"z": scenario.car_position_m.z = value
			&"heading": scenario.car_heading_deg = value
	else:
		match field:
			&"mass": scenario.target_mass_kg = value
			&"speed": scenario.target_speed_kmh = value
			&"x": scenario.target_position_m.x = value
			&"z": scenario.target_position_m.z = value
			&"heading": scenario.target_heading_deg = value
	_request_preview_rebuild()

func _on_common_spin_changed(value: float, field: StringName) -> void:
	if syncing_ui:
		return
	match field:
		&"duration": scenario.duration_s = value
		&"friction": scenario.contact_friction = value
		&"restitution": scenario.restitution = value
		&"substeps": scenario.solver_substeps = int(value)
	_request_preview_rebuild()

func _on_title_changed(value: String) -> void:
	if not syncing_ui:
		scenario.title = value

func _on_structure_toggled(value: bool) -> void:
	if syncing_ui:
		return
	scenario.show_structure = value
	if car != null:
		car.set_structure_debug(value)
	if target_car != null:
		target_car.set_structure_debug(value)
	if truck != null:
		truck.set_structure_debug(value)

func _request_preview_rebuild() -> void:
	simulation_running = false
	simulation_paused = false
	if pause_button != null:
		pause_button.disabled = true
		pause_button.text = "Pause"
	if preview_rebuild_requested:
		return
	preview_rebuild_requested = true
	call_deferred("_perform_preview_rebuild")

func _perform_preview_rebuild() -> void:
	preview_rebuild_requested = false
	_rebuild_preview()

func _rebuild_preview() -> void:
	_clear_runtime_objects()
	car = _spawn_passenger_car(
		"PrimaryPassengerCar",
		scenario.car_preset_id,
		scenario.car_mass_kg,
		scenario.car_speed_kmh,
		scenario.car_position_m,
		scenario.car_heading_deg
	)

	if scenario.target_type == ScenarioConfig.TARGET_PASSENGER_CAR:
		target_car = _spawn_passenger_car(
			"TargetPassengerCar",
			scenario.target_car_preset_id,
			scenario.target_mass_kg,
			scenario.target_speed_kmh,
			scenario.target_position_m,
			scenario.target_heading_deg
		)
		pair_simulation = VehiclePairSimulation.new()
		pair_simulation.configure(
			car.model,
			PRIMARY_FRONT_CONTACT_NODES,
			target_car.model,
			_target_car_contact_nodes(),
			scenario.car_forward(),
			scenario.contact_friction,
			scenario.restitution
		)
	elif scenario.target_type == ScenarioConfig.TARGET_TRUCK:
		truck = HeavyTruck.new()
		truck.name = "HeavyTruck"
		truck.total_mass_kg = scenario.target_mass_kg
		truck.initial_speed_kmh = scenario.target_speed_kmh
		truck.origin_offset_m = scenario.target_position_m
		truck.heading_deg = scenario.target_heading_deg
		truck.auto_step = false
		truck.show_structure = scenario.show_structure
		add_child(truck)
		pair_simulation = VehiclePairSimulation.new()
		pair_simulation.configure(
			car.model,
			PRIMARY_FRONT_CONTACT_NODES,
			truck.model,
			HeavyTruckBuilder.rear_contact_nodes(),
			scenario.car_forward(),
			scenario.contact_friction,
			scenario.restitution
		)
	else:
		obstacle = StaticObstacle3D.new()
		obstacle.name = "StaticTarget"
		add_child(obstacle)
		obstacle.configure(scenario.target_type, scenario.target_position_m, scenario.target_heading_deg)
		static_simulation = VehicleStaticSimulation.new()
		static_simulation.configure(
			car.model,
			scenario.target_type,
			scenario.target_position_m,
			scenario.target_heading_deg,
			scenario.contact_friction,
			scenario.restitution
		)
	status_label.text = "Editable preview — press Simulate when ready"
	_update_metrics()

func _spawn_passenger_car(
	node_name: String,
	preset_id: StringName,
	mass_kg: float,
	speed_kmh: float,
	position_m: Vector3,
	heading_deg: float
) -> CompactHatchback:
	var vehicle := CompactHatchback.new()
	vehicle.name = node_name
	vehicle.vehicle_preset_id = preset_id
	vehicle.total_mass_kg = mass_kg
	vehicle.initial_speed_kmh = speed_kmh
	vehicle.origin_offset_m = position_m
	vehicle.heading_deg = heading_deg
	vehicle.auto_step = false
	vehicle.show_structure = scenario.show_structure
	add_child(vehicle)
	return vehicle

func _target_car_contact_nodes() -> PackedInt32Array:
	return TARGET_FRONT_CONTACT_NODES if scenario.target_car_uses_front_contact() else TARGET_REAR_CONTACT_NODES

func _clear_runtime_objects() -> void:
	for node in [car, target_car, truck, obstacle]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	car = null
	target_car = null
	truck = null
	obstacle = null
	pair_simulation = null
	static_simulation = null

func _on_simulate_pressed() -> void:
	var errors := scenario.validation_errors()
	if not errors.is_empty():
		status_label.text = "Preflight failed: %s" % "; ".join(errors)
		return
	_rebuild_preview()
	simulation_running = true
	simulation_paused = false
	pause_button.disabled = false
	pause_button.text = "Pause"
	status_label.text = "Simulation running"

func _on_pause_pressed() -> void:
	if not simulation_running:
		return
	simulation_paused = not simulation_paused
	pause_button.text = "Resume" if simulation_paused else "Pause"
	status_label.text = "Simulation paused" if simulation_paused else "Simulation running"

func _on_reset_pressed() -> void:
	simulation_running = false
	simulation_paused = false
	pause_button.disabled = true
	pause_button.text = "Pause"
	_rebuild_preview()

func _on_new_pressed() -> void:
	scenario.reset_defaults()
	current_scenario_path = ""
	selected_object = &"car"
	simulation_running = false
	simulation_paused = false
	_sync_ui_from_scenario()
	_rebuild_preview()
	_frame_scenario()
	status_label.text = "New scenario"

func _on_save_pressed() -> void:
	scenario.title = title_edit.text
	var errors := scenario.validation_errors()
	if not errors.is_empty():
		status_label.text = "Cannot save: %s" % "; ".join(errors)
		return
	if current_scenario_path.is_empty():
		save_dialog.popup_centered(Vector2i(900, 650))
		return
	_save_scenario(current_scenario_path)

func _on_open_pressed() -> void:
	open_dialog.popup_centered(Vector2i(900, 650))

func _on_save_path_selected(path: String) -> void:
	_save_scenario(path)

func _save_scenario(path: String) -> void:
	var final_path := ScenarioStore.normalise_save_path(path)
	var error := ScenarioStore.save_to_path(scenario, final_path)
	if error != OK:
		status_label.text = "Save failed with error %d" % error
		return
	current_scenario_path = final_path
	status_label.text = "Saved scenario: %s" % final_path.get_file()

func _on_open_path_selected(path: String) -> void:
	var result := ScenarioStore.load_from_path(path)
	var error_text := String(result.get("error", ""))
	if not error_text.is_empty():
		status_label.text = "Open failed: %s" % error_text
		return
	var loaded := result.get("scenario") as ScenarioConfig
	if loaded == null:
		status_label.text = "Open failed: no scenario data"
		return
	scenario = loaded
	current_scenario_path = path
	selected_object = &"car"
	simulation_running = false
	simulation_paused = false
	_sync_ui_from_scenario()
	_rebuild_preview()
	_frame_scenario()
	status_label.text = "Loaded scenario: %s" % path.get_file()

func _select_nearest_object(point: Vector3) -> void:
	var car_distance := Vector2(point.x - scenario.car_position_m.x, point.z - scenario.car_position_m.z).length()
	var target_distance := Vector2(point.x - scenario.target_position_m.x, point.z - scenario.target_position_m.z).length()
	var target_limit := _target_selection_radius()
	if car_distance <= 2.4 and (car_distance <= target_distance or target_distance > target_limit):
		selected_object = &"car"
	elif target_distance <= target_limit:
		selected_object = &"target"
	else:
		return
	_rebuild_inspector()

func _target_selection_radius() -> float:
	match scenario.target_type:
		ScenarioConfig.TARGET_PASSENGER_CAR: return 2.4
		ScenarioConfig.TARGET_TRUCK: return 5.2
		ScenarioConfig.TARGET_WALL: return 4.7
		ScenarioConfig.TARGET_BARRIER: return 2.5
		ScenarioConfig.TARGET_TREE: return 1.5
		_: return 1.0

func _move_selected(delta_m: Vector3) -> void:
	if delta_m.is_zero_approx():
		return
	if selected_object == &"car":
		scenario.car_position_m += delta_m
		if car != null:
			car.model.translate_all_nodes(delta_m)
			car.origin_offset_m = scenario.car_position_m
			car.step_external(0.0)
	else:
		scenario.target_position_m += delta_m
		if target_car != null:
			target_car.model.translate_all_nodes(delta_m)
			target_car.origin_offset_m = scenario.target_position_m
			target_car.step_external(0.0)
		if truck != null:
			truck.model.translate_all_nodes(delta_m)
			truck.origin_offset_m = scenario.target_position_m
			truck.step_external(0.0)
		if obstacle != null:
			obstacle.set_editor_transform(scenario.target_position_m, scenario.target_heading_deg)
	_sync_current_object_fields()

func _rotate_selected(delta_deg: float) -> void:
	if is_zero_approx(delta_deg):
		return
	if selected_object == &"car":
		scenario.car_heading_deg = wrapf(scenario.car_heading_deg + delta_deg, -180.0, 180.0)
		if car != null:
			car.model.rotate_y_about(scenario.car_position_m, deg_to_rad(delta_deg), true)
			car.heading_deg = scenario.car_heading_deg
			car.step_external(0.0)
	else:
		scenario.target_heading_deg = wrapf(scenario.target_heading_deg + delta_deg, -180.0, 180.0)
		if target_car != null:
			target_car.model.rotate_y_about(scenario.target_position_m, deg_to_rad(delta_deg), true)
			target_car.heading_deg = scenario.target_heading_deg
			target_car.step_external(0.0)
		if truck != null:
			truck.model.rotate_y_about(scenario.target_position_m, deg_to_rad(delta_deg), true)
			truck.heading_deg = scenario.target_heading_deg
			truck.step_external(0.0)
		if obstacle != null:
			obstacle.set_editor_transform(scenario.target_position_m, scenario.target_heading_deg)
	_sync_current_object_fields()
	_request_preview_rebuild()

func _screen_to_ground(screen_position: Vector2) -> Variant:
	if camera == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var plane := Plane(Vector3.UP, 0.0)
	return plane.intersects_ray(ray_origin, ray_direction)

func _frame_scenario() -> void:
	if camera == null:
		return
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5
	var separation := scenario.car_position_m.distance_to(scenario.target_position_m)
	camera.position = Vector3(midpoint.x, 7.2, midpoint.z + maxf(18.0, separation * 1.35 + 10.0))
	camera.look_at(midpoint + Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _simulation_elapsed_s() -> float:
	if pair_simulation != null:
		return pair_simulation.elapsed_s
	if static_simulation != null:
		return static_simulation.elapsed_s
	return 0.0

func _update_metrics() -> void:
	if metrics_label == null or car == null or car.model == null:
		return
	var car_speed := PhysicsMetrics.ms_to_kmh(car.global_linear_velocity_ms().length())
	var initial_energy_kj := PhysicsMetrics.kinetic_energy_from_speed_kmh(scenario.car_mass_kg, scenario.car_speed_kmh) / 1000.0
	var contact_count := 0
	var peak_penetration_mm := 0.0
	var energy_error_percent := 0.0
	var extra := ""
	if pair_simulation != null:
		contact_count = pair_simulation.contact.contact_events
		peak_penetration_mm = pair_simulation.contact.maximum_penetration_m * 1000.0
		energy_error_percent = pair_simulation.energy_balance_relative_error() * 100.0
		if target_car != null:
			var target_speed := PhysicsMetrics.ms_to_kmh(target_car.global_linear_velocity_ms().length())
			extra = "%s • %.0f kg • %.1f km/h • closing %.1f km/h • momentum error %.3f kg·m/s" % [
				target_car.vehicle_class_name(), target_car.model.total_mass_kg(), target_speed,
				pair_simulation.closing_speed_kmh(), pair_simulation.momentum_error_kg_ms(),
			]
		elif truck != null:
			var truck_speed := PhysicsMetrics.ms_to_kmh(truck.global_linear_velocity_ms().length())
			extra = "Heavy Truck • %.0f kg • %.1f km/h • closing %.1f km/h • momentum error %.3f kg·m/s" % [
				truck.model.total_mass_kg(), truck_speed, pair_simulation.closing_speed_kmh(), pair_simulation.momentum_error_kg_ms(),
			]
	elif static_simulation != null:
		contact_count = static_simulation.contact.contact_events
		peak_penetration_mm = static_simulation.contact.maximum_penetration_m * 1000.0
		energy_error_percent = static_simulation.energy_balance_relative_error() * 100.0
		extra = "Static target: %s" % ScenarioConfig.target_display_name(scenario.target_type)
	metrics_label.text = "%s • %.0f kg • %.1f km/h • initial KE %.1f kJ\nFront crush %.0f mm • safety cell %.0f mm • contacts %d • peak penetration %.1f mm • energy diagnostic %.2f%%\n%s" % [
		car.vehicle_class_name(), car.model.total_mass_kg(), car_speed, initial_energy_kj,
		car.front_crush_deformation_m() * 1000.0, car.safety_cell_deformation_m() * 1000.0,
		contact_count, peak_penetration_mm, energy_error_percent, extra,
	]
