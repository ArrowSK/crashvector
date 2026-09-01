# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StaticObstacle3D
extends Node3D

var obstacle_type: StringName = ScenarioConfig.TARGET_WALL
var surface_position_m: Vector3 = Vector3.ZERO
var heading_deg: float = 0.0

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
			_add_box("ConcreteBarrier", Vector3(0.42, 0.95, 4.0), Color(0.52, 0.54, 0.56), Vector3(0.0, 0.475, 0.0))
		ScenarioConfig.TARGET_POLE:
			_add_cylinder("Pole", 0.18, 2.8, Color(0.34, 0.36, 0.39))
		ScenarioConfig.TARGET_TREE:
			_add_cylinder("TreeTrunk", 0.32, 3.6, Color(0.30, 0.18, 0.09))
			var crown := SphereMesh.new()
			crown.radius = 1.35
			crown.height = 2.7
			crown.radial_segments = 16
			crown.rings = 8
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.20, 0.42, 0.18)
			material.roughness = 0.95
			crown.material = material
			var crown_instance := MeshInstance3D.new()
			crown_instance.mesh = crown
			crown_instance.position = Vector3(0.0, 3.75, 0.0)
			add_child(crown_instance)
		_:
			_add_box("RigidWall", Vector3(0.45, 3.2, 9.0), Color(0.56, 0.58, 0.61), Vector3(0.0, 1.6, 0.0))
	_apply_visual_transform()

func _add_box(node_name: String, size: Vector3, color: Color, local_position: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.90
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	add_child(instance)

func _add_cylinder(node_name: String, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = Vector3(0.0, height * 0.5, 0.0)
	add_child(instance)

func _apply_visual_transform() -> void:
	rotation = Vector3(0.0, deg_to_rad(heading_deg), 0.0)
	if obstacle_type == ScenarioConfig.TARGET_WALL or obstacle_type == ScenarioConfig.TARGET_BARRIER:
		var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
		var thickness := 0.45 if obstacle_type == ScenarioConfig.TARGET_WALL else 0.42
		position = surface_position_m + forward * thickness * 0.5
	else:
		position = surface_position_m
