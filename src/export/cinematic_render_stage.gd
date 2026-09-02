# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CinematicRenderStage
extends SubViewport

var recording: ReplayRecording
var scenario: ScenarioConfig
var analysis: Dictionary = {}
var profile: CinematicExportProfile
var timeline: CinematicTimeline

var primary: CompactHatchback
var target_car: CompactHatchback
var truck: HeavyTruck
var lorry: RigidLorry
var motorcycle: Motorcycle
var bicycle: Bicycle
var pedestrian: Pedestrian
var obstacle: StaticObstacle3D
var camera: Camera3D

var title_label: Label
var hud_label: Label
var watermark_label: Label
var result_panel: PanelContainer
var result_label: Label

func configure(
	replay_recording: ReplayRecording,
	config: ScenarioConfig,
	analysis_data: Dictionary,
	export_profile: CinematicExportProfile,
	export_timeline: CinematicTimeline
) -> void:
	recording = replay_recording
	scenario = config
	analysis = analysis_data.duplicate(true)
	profile = export_profile
	timeline = export_timeline
	size = CinematicExportProfile.resolution_size(profile.resolution_id)
	own_world_3d = true
	render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_build_environment()
	_build_scene()
	_build_overlay()
	apply_output_time(0.0)

func apply_output_time(output_time_s: float) -> void:
	if recording == null or not recording.has_frames():
		return
	var replay_time := timeline.replay_time_for_output_time(output_time_s)
	var frame := recording.frame_at_time(replay_time)
	if frame.is_empty():
		return
	_apply_primary_frame(frame)
	_apply_target_frame(frame)
	_apply_camera(frame, replay_time)
	_update_overlay(frame, output_time_s, replay_time)

func render_frame_to_jpeg(path: String) -> Error:
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var texture := get_texture()
	if texture == null:
		return ERR_CANT_CREATE
	var image := texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return ERR_CANT_CREATE
	return image.save_jpg(path, clampf(profile.jpeg_quality, 0.75, 1.0))

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "CinematicEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.024, 0.036)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.53, 0.64)
	environment.ambient_light_energy = 0.82
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	key_light.light_energy = 1.75
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(-30.0, 142.0, 0.0)
	fill_light.light_energy = 0.55
	fill_light.shadow_enabled = false
	add_child(fill_light)

func _build_scene() -> void:
	_build_road()
	primary = CompactHatchback.new()
	primary.name = "RenderPrimary"
	primary.vehicle_preset_id = scenario.car_preset_id
	primary.total_mass_kg = scenario.car_mass_kg
	primary.initial_speed_kmh = scenario.car_speed_kmh
	primary.origin_offset_m = scenario.car_position_m
	primary.heading_deg = scenario.car_heading_deg
	primary.paint_id = profile.primary_paint_id
	primary.auto_step = false
	primary.show_structure = false
	add_child(primary)

	match scenario.target_type:
		ScenarioConfig.TARGET_PASSENGER_CAR:
			target_car = CompactHatchback.new()
			target_car.name = "RenderTargetCar"
			target_car.vehicle_preset_id = scenario.target_car_preset_id
			target_car.total_mass_kg = scenario.target_mass_kg
			target_car.initial_speed_kmh = scenario.target_speed_kmh
			target_car.origin_offset_m = scenario.target_position_m
			target_car.heading_deg = scenario.target_heading_deg
			target_car.paint_id = profile.target_paint_id
			target_car.auto_step = false
			target_car.show_structure = false
			add_child(target_car)
		ScenarioConfig.TARGET_TRUCK:
			truck = HeavyTruck.new()
			truck.name = "RenderTruck"
			truck.total_mass_kg = scenario.target_mass_kg
			truck.initial_speed_kmh = scenario.target_speed_kmh
			truck.origin_offset_m = scenario.target_position_m
			truck.heading_deg = scenario.target_heading_deg
			truck.auto_step = false
			truck.show_structure = false
			add_child(truck)
		ScenarioConfig.TARGET_LORRY:
			lorry = RigidLorry.new()
			lorry.name = "RenderLorry"
			lorry.total_mass_kg = scenario.target_mass_kg
			lorry.initial_speed_kmh = scenario.target_speed_kmh
			lorry.origin_offset_m = scenario.target_position_m
			lorry.heading_deg = scenario.target_heading_deg
			lorry.auto_step = false
			lorry.show_structure = false
			add_child(lorry)
		ScenarioConfig.TARGET_MOTORCYCLE:
			motorcycle = Motorcycle.new()
			motorcycle.name = "RenderMotorcycle"
			motorcycle.total_mass_kg = scenario.target_mass_kg
			motorcycle.initial_speed_kmh = scenario.target_speed_kmh
			motorcycle.origin_offset_m = scenario.target_position_m
			motorcycle.heading_deg = scenario.target_heading_deg
			motorcycle.auto_step = false
			motorcycle.show_structure = false
			add_child(motorcycle)
		ScenarioConfig.TARGET_BICYCLE:
			bicycle = Bicycle.new()
			bicycle.name = "RenderBicycle"
			bicycle.bicycle_preset_id = scenario.target_preset_id
			bicycle.total_mass_kg = scenario.target_mass_kg
			bicycle.initial_speed_kmh = scenario.target_speed_kmh
			bicycle.origin_offset_m = scenario.target_position_m
			bicycle.heading_deg = scenario.target_heading_deg
			bicycle.auto_step = false
			bicycle.show_structure = false
			add_child(bicycle)
		ScenarioConfig.TARGET_PEDESTRIAN:
			pedestrian = Pedestrian.new()
			pedestrian.name = "RenderPedestrian"
			pedestrian.body_preset_id = scenario.target_preset_id
			pedestrian.total_mass_kg = scenario.target_mass_kg
			pedestrian.origin_offset_m = scenario.target_position_m
			pedestrian.heading_deg = scenario.target_heading_deg
			pedestrian.auto_step = false
			pedestrian.show_structure = false
			add_child(pedestrian)
		_:
			obstacle = StaticObstacle3D.new()
			obstacle.name = "RenderObstacle"
			add_child(obstacle)
			obstacle.configure(scenario.target_type, scenario.target_position_m, scenario.target_heading_deg)

	camera = Camera3D.new()
	camera.name = "CinematicCamera"
	camera.current = true
	camera.near = 0.08
	camera.far = 250.0
	add_child(camera)

func _build_road() -> void:
	var midpoint := (scenario.car_position_m + scenario.target_position_m) * 0.5
	var separation := scenario.car_position_m.distance_to(scenario.target_position_m)
	var length_m := maxf(34.0, separation + 28.0)
	_add_box("RenderRoad", Vector3(midpoint.x, -0.20, midpoint.z), Vector3(length_m, 0.40, 10.0), Color(0.055, 0.060, 0.072))
	for index in range(-6, 7):
		_add_box("LaneMark%d" % index, Vector3(midpoint.x + float(index) * 3.0, 0.018, midpoint.z), Vector3(1.6, 0.025, 0.065), Color(0.82, 0.80, 0.67))

func _add_box(node_name: String, position_m: Vector3, box_size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_m
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.90
	mesh.material = material
	instance.mesh = mesh
	add_child(instance)

func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "CinematicOverlay"
	canvas.layer = 10
	add_child(canvas)
	var font_size := maxi(int(round(float(size.y) / 34.0)), 24)

	title_label = Label.new()
	title_label.anchor_left = 0.12
	title_label.anchor_right = 0.88
	title_label.anchor_top = 0.33
	title_label.anchor_bottom = 0.62
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", font_size * 2)
	title_label.text = "%s\n%s vs %s" % [scenario.title, PassengerCarCatalog.display_name(scenario.car_preset_id), ScenarioConfig.target_display_name(scenario.target_type)]
	canvas.add_child(title_label)

	hud_label = Label.new()
	hud_label.position = Vector2(float(size.x) * 0.035, float(size.y) * 0.055)
	hud_label.add_theme_font_size_override("font_size", font_size)
	hud_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	canvas.add_child(hud_label)

	watermark_label = Label.new()
	watermark_label.anchor_left = 0.0
	watermark_label.anchor_right = 1.0
	watermark_label.anchor_top = 1.0
	watermark_label.anchor_bottom = 1.0
	watermark_label.offset_top = -float(font_size) * 1.9
	watermark_label.offset_bottom = -8.0
	watermark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	watermark_label.add_theme_font_size_override("font_size", maxi(font_size - 4, 16))
	watermark_label.text = "CrashVector • educational simulation • generic classes / road-user proxies"
	watermark_label.modulate = Color(1.0, 1.0, 1.0, 0.70)
	canvas.add_child(watermark_label)

	result_panel = PanelContainer.new()
	result_panel.anchor_left = 0.19
	result_panel.anchor_right = 0.81
	result_panel.anchor_top = 0.28
	result_panel.anchor_bottom = 0.72
	canvas.add_child(result_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", font_size)
	margin.add_theme_constant_override("margin_top", font_size)
	margin.add_theme_constant_override("margin_right", font_size)
	margin.add_theme_constant_override("margin_bottom", font_size)
	result_panel.add_child(margin)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", font_size)
	result_label.text = _result_text()
	margin.add_child(result_label)

func _apply_primary_frame(frame: Dictionary) -> void:
	if primary == null or primary.model == null:
		return
	var state: Variant = frame.get("primary_state", {})
	if state is Dictionary:
		StructuralSnapshot.apply(primary.model, state)
	var visual_state: Variant = frame.get("primary_visual_state", {})
	primary.apply_replay_visual_state(visual_state if visual_state is Dictionary else {})

func _apply_target_frame(frame: Dictionary) -> void:
	var state: Variant = frame.get("target_state", {})
	if not (state is Dictionary):
		return
	if target_car != null and target_car.model != null:
		StructuralSnapshot.apply(target_car.model, state)
		var visual_state: Variant = frame.get("target_visual_state", {})
		target_car.apply_replay_visual_state(visual_state if visual_state is Dictionary else {})
	elif truck != null and truck.model != null:
		StructuralSnapshot.apply(truck.model, state)
		truck.step_external(0.0)
	elif lorry != null and lorry.model != null:
		StructuralSnapshot.apply(lorry.model, state)
		lorry.step_external(0.0)
	elif motorcycle != null and motorcycle.model != null:
		StructuralSnapshot.apply(motorcycle.model, state)
		motorcycle.step_external(0.0)
	elif bicycle != null and bicycle.model != null:
		StructuralSnapshot.apply(bicycle.model, state)
		bicycle.step_external(0.0)
	elif pedestrian != null and pedestrian.model != null:
		StructuralSnapshot.apply(pedestrian.model, state)
		pedestrian.step_external(0.0)

func _apply_camera(frame: Dictionary, replay_time_s: float) -> void:
	if camera == null:
		return
	var pose := CinematicCameraPlanner.pose_for_frame(frame, scenario, profile.camera_id, replay_time_s, timeline.first_contact_s)
	var position_value: Vector3 = pose.get("position", Vector3(0.0, 4.0, 8.0))
	var target_value: Vector3 = pose.get("target", Vector3.ZERO)
	camera.position = position_value
	camera.fov = float(pose.get("fov", 45.0))
	if camera.position.distance_to(target_value) > 0.01:
		camera.look_at(target_value, Vector3.UP)

func _update_overlay(frame: Dictionary, output_time_s: float, replay_time_s: float) -> void:
	var phase := timeline.phase_at_output_time(output_time_s)
	title_label.visible = profile.include_title_card and phase == &"intro"
	result_panel.visible = profile.include_result_card and phase == &"result"
	watermark_label.visible = profile.include_overlays and phase != &"intro"
	hud_label.visible = profile.include_overlays and phase != &"intro" and phase != &"result"
	if not hud_label.visible:
		return
	var metrics_value: Variant = frame.get("primary_metrics", {})
	var metrics: Dictionary = metrics_value if metrics_value is Dictionary else {}
	var speed := float(metrics.get("speed_kmh", 0.0))
	var crush_mm := float(metrics.get("front_crush_m", 0.0)) * 1000.0
	var slow_tag := " • 0.25× impact slow motion" if phase == &"slow_motion" else ""
	hud_label.text = "%s\n%.0f km/h • front crush %.0f mm • t %.2f s%s" % [PassengerCarCatalog.display_name(scenario.car_preset_id), speed, crush_mm, replay_time_s, slow_tag]

func _result_text() -> String:
	var scope_note := "Educational simulation — not certified reconstruction or injury prediction"
	if scenario.target_type == ScenarioConfig.TARGET_PEDESTRIAN or scenario.target_type == ScenarioConfig.TARGET_BICYCLE:
		scope_note = "Road-user contact/trajectory visualisation only — no injury probability or medical outcome"
	return (
		"CRASH ANALYSIS\n\nΔv %.1f km/h   •   peak simulated deceleration %.1f g\n"
		+ "Maximum front crush %.0f mm   •   safety-cell deformation proxy %.0f mm\n"
		+ "Initial kinetic energy %.1f kJ\n\n%s"
	) % [
		float(analysis.get("final_delta_v_kmh", 0.0)),
		float(analysis.get("peak_deceleration_g", 0.0)),
		float(analysis.get("max_front_crush_mm", 0.0)),
		float(analysis.get("max_safety_cell_deformation_mm", 0.0)),
		float(analysis.get("initial_kinetic_energy_kj", 0.0)),
		scope_note,
	]
