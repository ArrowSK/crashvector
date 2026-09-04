# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StaticObstacle3D
extends Node3D

var obstacle_type: StringName = ScenarioConfig.TARGET_WALL
var surface_position_m := Vector3.ZERO
var heading_deg := 0.0

func configure(type_id: StringName, position_m: Vector3, yaw_deg: float) -> void:
	obstacle_type = type_id
	surface_position_m = position_m
	heading_deg = yaw_deg
	_build_visuals()

func set_editor_transform(position_m: Vector3, yaw_deg: float) -> void:
	surface_position_m = position_m
	heading_deg = yaw_deg
	_apply_visual_transform()

func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()
	match obstacle_type:
		ScenarioConfig.TARGET_BARRIER:
			_build_concrete_barrier()
		ScenarioConfig.TARGET_POLE:
			_build_pole()
		ScenarioConfig.TARGET_TREE:
			_build_tree()
		_:
			_build_rigid_wall()
	_apply_visual_transform()

func _build_rigid_wall() -> void:
	var concrete := _material(Color(0.58, 0.60, 0.61), 0.0, 0.92)
	var dark := _material(Color(0.25, 0.27, 0.28), 0.0, 0.96)
	_add_box("RigidWall", Vector3(0.45, 3.25, 9.0), concrete, Vector3(0.0, 1.625, 0.0))
	_add_box("WallFoot", Vector3(0.72, 0.20, 9.35), dark, Vector3(0.13, 0.10, 0.0))
	for z in [-3.0, 0.0, 3.0]:
		_add_box("WallJoint", Vector3(0.012, 3.08, 0.026), dark, Vector3(-0.231, 1.62, z))
	var stripe := _material(Color(0.86, 0.16, 0.08), 0.05, 0.55)
	_add_box("ImpactReferenceStripe", Vector3(0.014, 0.075, 8.45), stripe, Vector3(-0.235, 0.73, 0.0))

func _build_concrete_barrier() -> void:
	var concrete := _material(Color(0.58, 0.59, 0.58), 0.0, 0.94)
	var seam := _material(Color(0.33, 0.34, 0.34), 0.0, 0.96)
	# A layered Jersey-style silhouette. Physics still uses the original flat
	# target surface; these meshes are presentation only.
	_add_box("BarrierBase", Vector3(0.58, 0.24, 4.1), concrete, Vector3(0.08, 0.12, 0.0))
	_add_box("BarrierLower", Vector3(0.48, 0.34, 4.05), concrete, Vector3(0.03, 0.39, 0.0))
	_add_box("BarrierUpper", Vector3(0.32, 0.43, 4.0), concrete, Vector3(-0.04, 0.775, 0.0))
	for z in [-1.35, 0.0, 1.35]:
		_add_box("BarrierJoint", Vector3(0.014, 0.88, 0.022), seam, Vector3(-0.205, 0.52, z))

func _build_pole() -> void:
	var pole_material := _material(Color(0.38, 0.41, 0.44), 0.72, 0.34)
	var base_material := _material(Color(0.22, 0.24, 0.26), 0.62, 0.38)
	_add_cylinder("Pole", 0.17, 0.16, 2.9, pole_material, Vector3(0.0, 1.45, 0.0))
	_add_cylinder("PoleBase", 0.31, 0.28, 0.16, base_material, Vector3(0.0, 0.08, 0.0))
	_add_cylinder("PoleCollar", 0.23, 0.20, 0.11, base_material, Vector3(0.0, 0.22, 0.0))

func _build_tree() -> void:
	var bark := _material(Color(0.28, 0.15, 0.075), 0.0, 0.98)
	var bark_light := _material(Color(0.39, 0.22, 0.10), 0.0, 0.97)
	var leaves_a := _material(Color(0.15, 0.36, 0.15), 0.0, 0.98)
	var leaves_b := _material(Color(0.21, 0.45, 0.18), 0.0, 0.97)
	_add_cylinder("TreeTrunk", 0.25, 0.36, 3.5, bark, Vector3(0.0, 1.75, 0.0))
	_add_cylinder("TreeBase", 0.38, 0.30, 0.28, bark_light, Vector3(0.0, 0.14, 0.0))
	_add_sphere("TreeCrownA", 1.18, leaves_a, Vector3(0.0, 3.95, 0.0))
	_add_sphere("TreeCrownB", 0.88, leaves_b, Vector3(0.42, 4.42, 0.36))
	_add_sphere("TreeCrownC", 0.84, leaves_a, Vector3(-0.38, 4.35, -0.32))

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add_box(node_name: String, size: Vector3, material: Material, local_position: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	add_child(instance)
	return instance

func _add_cylinder(node_name: String, top_radius: float, bottom_radius: float, height: float, material: Material, local_position: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 2
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	add_child(instance)
	return instance

func _add_sphere(node_name: String, radius: float, material: Material, local_position: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	add_child(instance)
	return instance

func _apply_visual_transform() -> void:
	rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	if obstacle_type == ScenarioConfig.TARGET_WALL or obstacle_type == ScenarioConfig.TARGET_BARRIER:
		var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
		var thickness := 0.45 if obstacle_type == ScenarioConfig.TARGET_WALL else 0.42
		position = surface_position_m + forward * thickness * 0.5
	else:
		position = surface_position_m
