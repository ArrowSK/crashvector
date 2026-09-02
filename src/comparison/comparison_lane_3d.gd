# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ComparisonLane3D
extends Node3D

var result: Dictionary = {}
var lane_offset_m := Vector3.ZERO
var primary: CompactHatchback
var target_car: CompactHatchback
var truck: HeavyTruck
var lorry: RigidLorry
var motorcycle: Motorcycle
var bicycle: Bicycle
var pedestrian: Pedestrian
var obstacle: StaticObstacle3D
var lane_label: Label3D
var live_label: Label3D
var road_mesh: MeshInstance3D
var primary_paint_id: StringName = CarPaintCatalog.ELECTRIC_BLUE

func configure(comparison_result: Dictionary, offset_m: Vector3, paint_id: StringName = CarPaintCatalog.ELECTRIC_BLUE) -> void:
	result = comparison_result
	lane_offset_m = offset_m
	primary_paint_id = paint_id if CarPaintCatalog.is_valid(paint_id) else CarPaintCatalog.ELECTRIC_BLUE
	_build_lane()
	apply_time(0.0)

func apply_time(time_s: float) -> void:
	var recording := result.get("recording") as ReplayRecording
	if recording == null or not recording.has_frames():
		return
	var frame := recording.frame_at_time(time_s)
	if frame.is_empty():
		return
	_apply_car_frame(primary, frame.get("primary_state", {}))
	var target_state: Variant = frame.get("target_state", {})
	if target_car != null:
		_apply_car_frame(target_car, target_state)
	elif truck != null:
		_apply_structural_frame(truck.model, target_state)
		truck.step_external(0.0)
	elif lorry != null:
		_apply_structural_frame(lorry.model, target_state)
		lorry.step_external(0.0)
	elif motorcycle != null:
		_apply_structural_frame(motorcycle.model, target_state)
		motorcycle.step_external(0.0)
	elif bicycle != null:
		_apply_structural_frame(bicycle.model, target_state)
		bicycle.step_external(0.0)
	elif pedestrian != null:
		_apply_structural_frame(pedestrian.model, target_state)
		pedestrian.step_external(0.0)
	_update_live_label(frame)

func set_primary_paint_id(value: StringName) -> void:
	primary_paint_id = value if CarPaintCatalog.is_valid(value) else CarPaintCatalog.ELECTRIC_BLUE
	if primary != null:
		primary.set_paint_id(primary_paint_id)

func set_structure_debug(enabled: bool) -> void:
	if primary != null:
		primary.set_structure_debug(enabled)
	if target_car != null:
		target_car.set_structure_debug(enabled)
	if truck != null:
		truck.set_structure_debug(enabled)
	if lorry != null:
		lorry.set_structure_debug(enabled)
	if motorcycle != null:
		motorcycle.set_structure_debug(enabled)
	if bicycle != null:
		bicycle.set_structure_debug(enabled)
	if pedestrian != null:
		pedestrian.set_structure_debug(enabled)

func _apply_car_frame(vehicle: CompactHatchback, state: Variant) -> void:
	if vehicle == null or vehicle.model == null or not (state is Dictionary):
		return
	StructuralSnapshot.apply(vehicle.model, state)
	vehicle.model.translate_all_nodes(lane_offset_m)
	vehicle.apply_replay_visual_state({})

func _apply_structural_frame(model: StructuralModel, state: Variant) -> void:
	if model == null or not (state is Dictionary):
		return
	StructuralSnapshot.apply(model, state)
	model.translate_all_nodes(lane_offset_m)

func _build_lane() -> void:
	var config := result.get("scenario") as ScenarioConfig
	if config == null:
		return
	_build_road(config)
	primary = CompactHatchback.new()
	primary.name = "ComparisonPrimary"
	primary.vehicle_preset_id = config.car_preset_id
	primary.paint_id = primary_paint_id
	primary.total_mass_kg = config.car_mass_kg
	primary.initial_speed_kmh = config.car_speed_kmh
	primary.origin_offset_m = config.car_position_m + lane_offset_m
	primary.heading_deg = config.car_heading_deg
	primary.auto_step = false
	primary.show_structure = false
	add_child(primary)

	match config.target_type:
		ScenarioConfig.TARGET_PASSENGER_CAR:
			target_car = CompactHatchback.new()
			target_car.name = "ComparisonTargetCar"
			target_car.vehicle_preset_id = config.target_car_preset_id
			target_car.paint_id = CarPaintCatalog.SILVER
			target_car.total_mass_kg = config.target_mass_kg
			target_car.initial_speed_kmh = config.target_speed_kmh
			target_car.origin_offset_m = config.target_position_m + lane_offset_m
			target_car.heading_deg = config.target_heading_deg
			target_car.auto_step = false
			target_car.show_structure = false
			add_child(target_car)
		ScenarioConfig.TARGET_TRUCK:
			truck = HeavyTruck.new()
			truck.name = "ComparisonTruck"
			truck.total_mass_kg = config.target_mass_kg
			truck.initial_speed_kmh = config.target_speed_kmh
			truck.origin_offset_m = config.target_position_m + lane_offset_m
			truck.heading_deg = config.target_heading_deg
			truck.auto_step = false
			truck.show_structure = false
			add_child(truck)
		ScenarioConfig.TARGET_LORRY:
			lorry = RigidLorry.new()
			lorry.name = "ComparisonLorry"
			lorry.total_mass_kg = config.target_mass_kg
			lorry.initial_speed_kmh = config.target_speed_kmh
			lorry.origin_offset_m = config.target_position_m + lane_offset_m
			lorry.heading_deg = config.target_heading_deg
			lorry.auto_step = false
			lorry.show_structure = false
			add_child(lorry)
		ScenarioConfig.TARGET_MOTORCYCLE:
			motorcycle = Motorcycle.new()
			motorcycle.name = "ComparisonMotorcycle"
			motorcycle.total_mass_kg = config.target_mass_kg
			motorcycle.initial_speed_kmh = config.target_speed_kmh
			motorcycle.origin_offset_m = config.target_position_m + lane_offset_m
			motorcycle.heading_deg = config.target_heading_deg
			motorcycle.auto_step = false
			motorcycle.show_structure = false
			add_child(motorcycle)
		ScenarioConfig.TARGET_BICYCLE:
			bicycle = Bicycle.new()
			bicycle.name = "ComparisonBicycle"
			bicycle.bicycle_preset_id = config.target_preset_id
			bicycle.total_mass_kg = config.target_mass_kg
			bicycle.initial_speed_kmh = config.target_speed_kmh
			bicycle.origin_offset_m = config.target_position_m + lane_offset_m
			bicycle.heading_deg = config.target_heading_deg
			bicycle.auto_step = false
			bicycle.show_structure = false
			add_child(bicycle)
		ScenarioConfig.TARGET_PEDESTRIAN:
			pedestrian = Pedestrian.new()
			pedestrian.name = "ComparisonPedestrian"
			pedestrian.body_preset_id = config.target_preset_id
			pedestrian.total_mass_kg = config.target_mass_kg
			pedestrian.origin_offset_m = config.target_position_m + lane_offset_m
			pedestrian.heading_deg = config.target_heading_deg
			pedestrian.auto_step = false
			pedestrian.show_structure = false
			add_child(pedestrian)
		_:
			obstacle = StaticObstacle3D.new()
			obstacle.name = "ComparisonObstacle"
			add_child(obstacle)
			obstacle.configure(config.target_type, config.target_position_m + lane_offset_m, config.target_heading_deg)

	lane_label = Label3D.new()
	lane_label.name = "VariantLabel"
	lane_label.text = String(result.get("label", "Variant"))
	lane_label.font_size = 54
	lane_label.outline_size = 10
	lane_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lane_label.position = _label_position(config, 3.9)
	add_child(lane_label)

	live_label = Label3D.new()
	live_label.name = "LiveMetrics"
	live_label.font_size = 34
	live_label.outline_size = 8
	live_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	live_label.position = _label_position(config, 3.25)
	add_child(live_label)

func _build_road(config: ScenarioConfig) -> void:
	road_mesh = MeshInstance3D.new()
	road_mesh.name = "ComparisonRoad"
	var separation := absf(config.target_position_m.x - config.car_position_m.x)
	var length_m := maxf(18.0, separation + 14.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length_m, 0.04, 6.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.085, 0.09, 0.105)
	material.roughness = 0.96
	mesh.material = material
	road_mesh.mesh = mesh
	road_mesh.position = Vector3(
		(config.car_position_m.x + config.target_position_m.x) * 0.5,
		-0.015,
		(config.car_position_m.z + config.target_position_m.z) * 0.5
	) + lane_offset_m
	add_child(road_mesh)

	var center_line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(length_m * 0.78, 0.025, 0.07)
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(0.78, 0.78, 0.72)
	line_material.roughness = 0.85
	line_mesh.material = line_material
	center_line.mesh = line_mesh
	center_line.position = road_mesh.position + Vector3(0.0, 0.035, 0.0)
	add_child(center_line)

func _label_position(config: ScenarioConfig, height_m: float) -> Vector3:
	return Vector3(
		(config.car_position_m.x + config.target_position_m.x) * 0.5,
		height_m,
		(config.car_position_m.z + config.target_position_m.z) * 0.5 - 2.6
	) + lane_offset_m

func _update_live_label(frame: Dictionary) -> void:
	if live_label == null:
		return
	var primary_metrics: Variant = frame.get("primary_metrics", {})
	if not (primary_metrics is Dictionary):
		return
	var speed := float(primary_metrics.get("speed_kmh", 0.0))
	var crush_mm := float(primary_metrics.get("front_crush_m", 0.0)) * 1000.0
	live_label.text = "%.0f km/h   crush %.0f mm" % [speed, crush_mm]
