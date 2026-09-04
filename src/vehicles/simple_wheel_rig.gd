# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name SimpleWheelRig
extends Node3D

const RESPONSE: float = 18.0

var model: StructuralModel
var anchor_indices := PackedInt32Array()
var wheel_instances: Array[MeshInstance3D] = []
var rim_instances: Array[MeshInstance3D] = []
var hub_instances: Array[MeshInstance3D] = []
var suspension_compression_m := PackedFloat64Array()
var wheel_radius_m := 0.30
var suspension_drop_m := 0.42
var side_offset_m := 0.10

func configure(structural_model: StructuralModel, anchors: PackedInt32Array) -> void:
	model = structural_model
	anchor_indices = anchors
	_calculate_proportions()
	_build_wheels()
	update_from_model(0.0)

func _calculate_proportions() -> void:
	if model == null or anchor_indices.is_empty():
		return
	var average_anchor_y := 0.0
	for index in anchor_indices:
		average_anchor_y += maxf(model.nodes[index].position_m.y, 0.35)
	average_anchor_y /= float(anchor_indices.size())
	wheel_radius_m = clampf(average_anchor_y * 0.64, 0.275, 0.385)
	suspension_drop_m = wheel_radius_m + 0.11
	side_offset_m = clampf(wheel_radius_m * 0.32, 0.085, 0.13)

func _build_wheels() -> void:
	var tire_material := StandardMaterial3D.new()
	tire_material.albedo_color = Color(0.018, 0.020, 0.023)
	tire_material.roughness = 0.91
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color(0.46, 0.49, 0.53)
	rim_material.metallic = 0.88
	rim_material.roughness = 0.22
	var hub_material := StandardMaterial3D.new()
	hub_material.albedo_color = Color(0.13, 0.14, 0.16)
	hub_material.metallic = 0.72
	hub_material.roughness = 0.32

	for _index in anchor_indices:
		var tire_mesh := CylinderMesh.new()
		tire_mesh.top_radius = wheel_radius_m
		tire_mesh.bottom_radius = wheel_radius_m
		tire_mesh.height = wheel_radius_m * 0.62
		tire_mesh.radial_segments = 28
		tire_mesh.rings = 2
		tire_mesh.material = tire_material
		var tire := MeshInstance3D.new()
		tire.name = "Tyre"
		tire.mesh = tire_mesh
		tire.rotation_degrees.x = 90.0
		add_child(tire)
		wheel_instances.append(tire)

		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = wheel_radius_m * 0.62
		rim_mesh.bottom_radius = wheel_radius_m * 0.62
		rim_mesh.height = wheel_radius_m * 0.66
		rim_mesh.radial_segments = 20
		rim_mesh.rings = 1
		rim_mesh.material = rim_material
		var rim := MeshInstance3D.new()
		rim.name = "AlloyRim"
		rim.mesh = rim_mesh
		rim.rotation_degrees.x = 90.0
		add_child(rim)
		rim_instances.append(rim)

		var hub_mesh := CylinderMesh.new()
		hub_mesh.top_radius = wheel_radius_m * 0.20
		hub_mesh.bottom_radius = wheel_radius_m * 0.20
		hub_mesh.height = wheel_radius_m * 0.70
		hub_mesh.radial_segments = 16
		hub_mesh.material = hub_material
		var hub := MeshInstance3D.new()
		hub.name = "WheelHub"
		hub.mesh = hub_mesh
		hub.rotation_degrees.x = 90.0
		add_child(hub)
		hub_instances.append(hub)
		suspension_compression_m.append(0.0)

func update_from_model(delta_s: float) -> void:
	if model == null:
		return
	for i in range(mini(anchor_indices.size(), wheel_instances.size())):
		var node := model.nodes[anchor_indices[i]]
		var center := _vehicle_center()
		var side_sign := -1.0 if node.position_m.z < center.z else 1.0
		var desired := node.position_m + Vector3(0.0, -suspension_drop_m, side_sign * side_offset_m)
		var minimum_y := wheel_radius_m
		var visual_target := desired
		if visual_target.y < minimum_y:
			visual_target.y = minimum_y
		suspension_compression_m[i] = maxf(visual_target.y - desired.y, 0.0)
		var alpha := 1.0 if delta_s <= 0.0 else 1.0 - exp(-RESPONSE * delta_s)
		var new_position := wheel_instances[i].position.lerp(visual_target, alpha)
		wheel_instances[i].position = new_position
		rim_instances[i].position = new_position
		hub_instances[i].position = new_position
		if delta_s > 0.0:
			var spin_speed := node.velocity_ms.x / maxf(wheel_radius_m, 0.01)
			wheel_instances[i].rotation.z -= spin_speed * delta_s
			rim_instances[i].rotation.z -= spin_speed * delta_s
			hub_instances[i].rotation.z -= spin_speed * delta_s

func _vehicle_center() -> Vector3:
	var sum := Vector3.ZERO
	for index in anchor_indices:
		sum += model.nodes[index].position_m
	return sum / maxf(float(anchor_indices.size()), 1.0)

func maximum_suspension_compression_m() -> float:
	var result := 0.0
	for value in suspension_compression_m:
		result = maxf(result, value)
	return result
