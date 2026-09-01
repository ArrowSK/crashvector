# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name SimpleWheelRig
extends Node3D

const WHEEL_RADIUS_M: float = 0.30
const SUSPENSION_DROP_M: float = 0.42
const SIDE_OFFSET_M: float = 0.10
const RESPONSE: float = 18.0

var model: StructuralModel
var anchor_indices := PackedInt32Array()
var wheel_instances: Array[MeshInstance3D] = []
var suspension_compression_m := PackedFloat64Array()

func configure(structural_model: StructuralModel, anchors: PackedInt32Array) -> void:
	model = structural_model
	anchor_indices = anchors
	_build_wheels()
	update_from_model(0.0)

func _build_wheels() -> void:
	var tire_material := StandardMaterial3D.new()
	tire_material.albedo_color = Color(0.03, 0.03, 0.035)
	tire_material.roughness = 0.88

	for _index in anchor_indices:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = WHEEL_RADIUS_M
		cylinder.bottom_radius = WHEEL_RADIUS_M
		cylinder.height = 0.18
		cylinder.radial_segments = 18
		cylinder.rings = 1
		cylinder.material = tire_material
		var wheel := MeshInstance3D.new()
		wheel.mesh = cylinder
		wheel.rotation_degrees.x = 90.0
		add_child(wheel)
		wheel_instances.append(wheel)
		suspension_compression_m.append(0.0)

func update_from_model(delta_s: float) -> void:
	if model == null:
		return
	for i in range(mini(anchor_indices.size(), wheel_instances.size())):
		var node := model.nodes[anchor_indices[i]]
		var side_sign := -1.0 if node.position_m.z < 0.0 else 1.0
		var desired := node.position_m + Vector3(0.0, -SUSPENSION_DROP_M, side_sign * SIDE_OFFSET_M)
		var minimum_y := WHEEL_RADIUS_M
		var visual_target := desired
		if visual_target.y < minimum_y:
			visual_target.y = minimum_y
		suspension_compression_m[i] = maxf(visual_target.y - desired.y, 0.0)
		var alpha := 1.0 if delta_s <= 0.0 else 1.0 - exp(-RESPONSE * delta_s)
		wheel_instances[i].position = wheel_instances[i].position.lerp(visual_target, alpha)
		if delta_s > 0.0:
			var spin_speed := node.velocity_ms.x / WHEEL_RADIUS_M
			wheel_instances[i].rotation.z -= spin_speed * delta_s

func maximum_suspension_compression_m() -> float:
	var result := 0.0
	for value in suspension_compression_m:
		result = maxf(result, value)
	return result
