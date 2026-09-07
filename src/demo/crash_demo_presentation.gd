# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m17.gd"

# Presentation-only production layer. M12-M18 physics, collision geometry,
# replay, analysis and scenario behaviour remain in the inherited production
# stack. This layer only improves lighting, road presentation, selection chrome
# and camera composition.

var cv_fill_light: DirectionalLight3D

func _ready() -> void:
	super._ready()
	_cv_polish_environment()
	_cv_polish_road()
	_cv_polish_selection_marker()
	call_deferred("_frame_scenario")

func _cv_polish_environment() -> void:
	var world_environment := _find_world_environment()
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("65798d")
		sky_material.sky_horizon_color = Color("d4dce2")
		sky_material.ground_horizon_color = Color("8e9998")
		sky_material.ground_bottom_color = Color("40494b")
		var sky := Sky.new()
		sky.sky_material = sky_material
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.82
		env.fog_enabled = true
		env.fog_light_color = Color("c7d0d5")
		env.fog_light_energy = 0.55
		env.fog_density = 0.0018

	var key_light: DirectionalLight3D = null
	for child in get_children():
		if child is DirectionalLight3D and String(child.name) != "PresentationFillLight":
			key_light = child as DirectionalLight3D
			break
	if key_light != null:
		key_light.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
		key_light.light_color = Color("fff0dc")
		key_light.light_energy = 1.42
		key_light.shadow_enabled = true

	if cv_fill_light == null or not is_instance_valid(cv_fill_light):
		cv_fill_light = DirectionalLight3D.new()
		cv_fill_light.name = "PresentationFillLight"
		cv_fill_light.rotation_degrees = Vector3(-28.0, 142.0, 0.0)
		cv_fill_light.light_color = Color("dbe8f5")
		cv_fill_light.light_energy = 0.34
		cv_fill_light.shadow_enabled = false
		add_child(cv_fill_light)

func _cv_polish_road() -> void:
	_cv_set_environment_material("TechnicalGround", Color("4d5958"), 1.0)
	_cv_set_environment_material("AsphaltSurface", Color("272d32"), 0.94)
	_cv_set_environment_material("LeftShoulder", Color("858983"), 0.90)
	_cv_set_environment_material("RightShoulder", Color("858983"), 0.90)
	_cv_set_environment_material("EdgeLineL", Color("e5e1d6"), 0.72)
	_cv_set_environment_material("EdgeLineR", Color("e5e1d6"), 0.72)
	if m10_environment_root != null:
		for child in m10_environment_root.get_children():
			if String(child.name).begins_with("M17CentreMark") or String(child.name).begins_with("CentreMark"):
				_cv_set_mesh_material(child as MeshInstance3D, Color("e5e1d6"), 0.72)

func _cv_set_environment_material(node_name: String, color: Color, roughness: float) -> void:
	if m10_environment_root == null:
		return
	_cv_set_mesh_material(m10_environment_root.get_node_or_null(node_name) as MeshInstance3D, color, roughness)

func _cv_set_mesh_material(instance: MeshInstance3D, color: Color, roughness: float) -> void:
	if instance == null or instance.mesh == null:
		return
	var material := instance.mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = roughness

func _cv_polish_selection_marker() -> void:
	if m10_selection_ring == null:
		return
	var ring := TorusMesh.new()
	ring.inner_radius = 0.82
	ring.outer_radius = 0.94
	ring.rings = 48
	ring.ring_segments = 10
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.31, 0.14, 0.48)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material = material
	m10_selection_ring.mesh = ring
	m10_selection_ring.scale = Vector3.ONE
	m10_selection_ring.position.y = 0.045
	m10_selection_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _frame_scenario() -> void:
	_cv_apply_camera(false, true)

func _on_camera_side() -> void:
	_cv_apply_camera(false, false)

func _m161_apply_camera(three_quarter: bool) -> void:
	_cv_apply_camera(false, three_quarter)

func _m161_frame_aftermath() -> void:
	if not _m161_has_replay():
		return
	_cv_apply_camera(true, true)

func _on_simulate_pressed() -> void:
	super._on_simulate_pressed()
	if simulation_running:
		call_deferred("_cv_frame_impact")

func _cv_frame_impact() -> void:
	if camera == null:
		return
	var primary := _m161_primary_center()
	var target := _m161_target_center()
	var toward_primary := (primary - target)
	var focus := target
	if toward_primary.length() > 0.01:
		focus += toward_primary.normalized() * minf(toward_primary.length() * 0.22, 1.6)
	focus.y = 0.92
	camera.fov = 47.0
	var distance := clampf(primary.distance_to(target) * 0.72, 6.6, 11.5)
	camera.position = Vector3(
		focus.x - distance * 0.38,
		focus.y + clampf(distance * 0.25, 2.2, 3.4),
		focus.z + distance * 0.84
	)
	camera.look_at(focus, Vector3.UP)

func _cv_apply_camera(aftermath: bool, three_quarter: bool) -> void:
	if camera == null:
		return
	var primary := _m161_primary_center()
	var target := _m161_target_center()
	var bounds := _m161_horizontal_bounds()
	var span_x := maxf(bounds.y - bounds.x, 4.2)
	var pair_center := Vector3(
		(bounds.x + bounds.y) * 0.5,
		0.92,
		(primary.z + target.z) * 0.5
	)
	var focus := pair_center
	if not aftermath:
		focus.x = lerpf(pair_center.x, primary.x, 0.10)

	camera.fov = 47.0 if aftermath else 49.0
	var aspect := 1.55
	if m10_viewport_frame != null and m10_viewport_frame.size.y > 1.0:
		aspect = maxf(m10_viewport_frame.size.x / m10_viewport_frame.size.y, 1.0)
	var vertical_fov := deg_to_rad(camera.fov)
	var horizontal_fov := 2.0 * atan(tan(vertical_fov * 0.5) * aspect)
	var framing := 0.84 if aftermath else 0.80
	var distance := (span_x * 0.5) / maxf(tan(horizontal_fov * 0.5) * framing, 0.10)
	distance = clampf(distance, 5.2, 20.0 if aftermath else 18.0)

	if three_quarter:
		camera.position = Vector3(
			focus.x - distance * 0.38,
			focus.y + clampf(distance * 0.24, 2.15, 4.0),
			focus.z + distance * 0.84
		)
	else:
		camera.position = Vector3(
			focus.x,
			focus.y + clampf(distance * 0.17, 1.9, 3.1),
			focus.z + distance
		)
	camera.look_at(focus, Vector3.UP)
