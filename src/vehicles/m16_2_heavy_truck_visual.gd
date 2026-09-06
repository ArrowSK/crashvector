# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M162HeavyTruckVisual
extends Node3D

# Presentation-only silhouette for the existing HeavyTruck rigid-body target.
# The production collision volume remains the single M12 rigid truck assembly;
# this skin simply makes the tractor, fifth-wheel gap and trailer visually
# legible as an articulated-road-vehicle archetype.

var truck: HeavyTruck
var cab_mesh := ImmediateMesh.new()
var cab_instance := MeshInstance3D.new()
var trailer_instance: MeshInstance3D
var chassis_instance: MeshInstance3D
var fifth_wheel_instance: MeshInstance3D
var windshield_instance: MeshInstance3D
var grille_instance: MeshInstance3D
var bumper_instance: MeshInstance3D
var trailer_front_trim: MeshInstance3D
var trailer_rear_trim: MeshInstance3D

var _cab_material := StandardMaterial3D.new()
var _trailer_material := StandardMaterial3D.new()
var _dark_material := StandardMaterial3D.new()
var _glass_material := StandardMaterial3D.new()
var _metal_material := StandardMaterial3D.new()

func configure(target: HeavyTruck) -> void:
	truck = target
	name = "M162HeavyTruckPresentation"
	if truck == null:
		return
	_build_materials()
	_hide_legacy_body_visuals()
	_build_visuals()
	process_priority = 65
	set_process(true)
	_update_pose()

func _process(_delta: float) -> void:
	if truck == null or not is_instance_valid(truck):
		queue_free()
		return
	_update_pose()

func _build_materials() -> void:
	_cab_material.albedo_color = Color(0.08, 0.29, 0.58)
	_cab_material.metallic = 0.36
	_cab_material.roughness = 0.28
	_cab_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trailer_material.albedo_color = Color(0.80, 0.83, 0.86)
	_trailer_material.metallic = 0.12
	_trailer_material.roughness = 0.52
	_dark_material.albedo_color = Color(0.022, 0.030, 0.040)
	_dark_material.metallic = 0.34
	_dark_material.roughness = 0.50
	_glass_material.albedo_color = Color(0.025, 0.060, 0.090)
	_glass_material.metallic = 0.12
	_glass_material.roughness = 0.12
	_metal_material.albedo_color = Color(0.33, 0.37, 0.42)
	_metal_material.metallic = 0.78
	_metal_material.roughness = 0.28

func _hide_legacy_body_visuals() -> void:
	for visual in [
		truck.trailer_visual,
		truck.cab_visual,
		truck.chassis_visual,
		truck.underride_visual,
		truck.windshield_visual,
		truck.grille_visual,
		truck.bumper_visual,
		truck.cab_roof_visual,
		truck.fifth_wheel_visual,
	]:
		if visual != null:
			visual.visible = false
	# Keep the existing wheel groups: they already follow the authoritative
	# structural wheel anchors and give the presentation six correctly located
	# rolling assemblies without introducing a second wheel-motion model.

func _build_visuals() -> void:
	trailer_instance = _box("TrailerPresentation", Vector3(5.72, 2.82, 2.42), _trailer_material)
	trailer_instance.position = Vector3(3.48, 2.13, 0.0)
	chassis_instance = _box("TruckFramePresentation", Vector3(9.18, 0.22, 1.76), _dark_material)
	chassis_instance.position = Vector3(4.58, 0.62, 0.0)
	fifth_wheel_instance = _box("FifthWheelPresentation", Vector3(0.72, 0.10, 1.10), _dark_material)
	fifth_wheel_instance.position = Vector3(6.67, 0.83, 0.0)
	trailer_front_trim = _box("TrailerFrontEdge", Vector3(0.08, 2.72, 2.34), _metal_material)
	trailer_front_trim.position = Vector3(6.34, 2.13, 0.0)
	trailer_rear_trim = _box("TrailerRearEdge", Vector3(0.08, 2.72, 2.34), _metal_material)
	trailer_rear_trim.position = Vector3(0.62, 2.13, 0.0)

	cab_instance.name = "TractorCabPresentation"
	cab_instance.mesh = cab_mesh
	add_child(cab_instance)
	_build_cab_mesh()

	windshield_instance = _box("TractorWindshield", Vector3(0.075, 1.25, 1.82), _glass_material)
	windshield_instance.position = Vector3(9.33, 2.30, 0.0)
	windshield_instance.rotation_degrees.z = -11.5
	grille_instance = _box("TractorGrille", Vector3(0.075, 0.68, 1.62), _dark_material)
	grille_instance.position = Vector3(9.48, 1.18, 0.0)
	bumper_instance = _box("TractorBumper", Vector3(0.18, 0.24, 2.10), _metal_material)
	bumper_instance.position = Vector3(9.48, 0.72, 0.0)

	# Side under-run bars visually separate the trailer from the tractor frame.
	for side in [-1.0, 1.0]:
		var guard := _box("TrailerSideGuard", Vector3(3.05, 0.12, 0.08), _metal_material)
		guard.position = Vector3(3.55, 0.70, side * 1.18)

func _build_cab_mesh() -> void:
	cab_mesh.clear_surfaces()
	cab_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _cab_material)
	var profile := [
		Vector2(7.14, 0.72),
		Vector2(7.14, 3.16),
		Vector2(9.04, 3.16),
		Vector2(9.42, 2.82),
		Vector2(9.50, 1.50),
		Vector2(9.50, 0.72),
	]
	var half_width := 1.12
	# Extruded side faces.
	for side in [-half_width, half_width]:
		for i in range(1, profile.size() - 1):
			_triangle(Vector3(profile[0].x, profile[0].y, side), Vector3(profile[i].x, profile[i].y, side), Vector3(profile[i + 1].x, profile[i + 1].y, side))
	# Perimeter connects the two side faces.
	for i in range(profile.size()):
		var next := (i + 1) % profile.size()
		var a := Vector3(profile[i].x, profile[i].y, -half_width)
		var b := Vector3(profile[next].x, profile[next].y, -half_width)
		var c := Vector3(profile[next].x, profile[next].y, half_width)
		var d := Vector3(profile[i].x, profile[i].y, half_width)
		_quad(a, b, c, d)
	cab_mesh.surface_end()

func _update_pose() -> void:
	if truck.rigid_chassis != null and is_instance_valid(truck.rigid_chassis):
		global_transform = truck.rigid_chassis.global_transform
	else:
		global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(truck.heading_deg)), truck.origin_offset_m)

func _box(node_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(a, b, c)
	_triangle(a, c, d)

func _triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	for vertex in [a, b, c]:
		cab_mesh.surface_set_normal(normal)
		cab_mesh.surface_add_vertex(vertex)
