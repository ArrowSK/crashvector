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
var released := PackedByteArray()
var released_positions: Array[Vector3] = []
var released_velocities: Array[Vector3] = []
var released_spin_rad_s := PackedFloat64Array()
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
		released.append(0)
		released_positions.append(Vector3.ZERO)
		released_velocities.append(Vector3.ZERO)
		released_spin_rad_s.append(0.0)

func release_wheel(index: int, initial_velocity_ms: Vector3, rolling_forward_world: Vector3 = Vector3.RIGHT) -> void:
	if index < 0 or index >= wheel_instances.size() or released[index] != 0:
		return
	released[index] = 1
	released_positions[index] = wheel_instances[index].position
	released_velocities[index] = initial_velocity_ms
	var rolling_forward := rolling_forward_world.normalized()
	if rolling_forward.is_zero_approx():
		rolling_forward = Vector3.RIGHT
	released_spin_rad_s[index] = initial_velocity_ms.dot(rolling_forward) / maxf(wheel_radius_m, 0.01)

func reset_releases() -> void:
	for index in range(released.size()):
		released[index] = 0
		released_positions[index] = Vector3.ZERO
		released_velocities[index] = Vector3.ZERO
		released_spin_rad_s[index] = 0.0

func replay_visual_state() -> Dictionary:
	var wheel_rotation_z_rad := PackedFloat64Array()
	for wheel in wheel_instances:
		wheel_rotation_z_rad.append(wheel.rotation.z)
	return {
		"released": released.duplicate(),
		"released_positions": released_positions.duplicate(),
		"released_velocities": released_velocities.duplicate(),
		"released_spin_rad_s": released_spin_rad_s.duplicate(),
		"wheel_rotation_z_rad": wheel_rotation_z_rad,
	}

func apply_replay_visual_state(state: Dictionary) -> void:
	# A replay frame must own the detached/attached state. Otherwise scrubbing
	# backward after a severe impact leaves the rig in its final released state,
	# while scrubbing a newly loaded frame can incorrectly reattach the wheels.
	reset_releases()
	var replay_released_value: Variant = state.get("released", PackedByteArray())
	var replay_positions_value: Variant = state.get("released_positions", [])
	var replay_velocities_value: Variant = state.get("released_velocities", [])
	var replay_spin_value: Variant = state.get("released_spin_rad_s", PackedFloat64Array())
	var replay_rotation_value: Variant = state.get("wheel_rotation_z_rad", PackedFloat64Array())
	var replay_released := PackedByteArray()
	if replay_released_value is PackedByteArray:
		replay_released = replay_released_value
	var replay_positions: Array = []
	if replay_positions_value is Array:
		replay_positions = replay_positions_value
	var replay_velocities: Array = []
	if replay_velocities_value is Array:
		replay_velocities = replay_velocities_value
	var replay_spin := PackedFloat64Array()
	if replay_spin_value is PackedFloat64Array:
		replay_spin = replay_spin_value
	var replay_rotation := PackedFloat64Array()
	if replay_rotation_value is PackedFloat64Array:
		replay_rotation = replay_rotation_value
	for index in range(released.size()):
		if index < replay_released.size():
			released[index] = replay_released[index]
		if index < replay_positions.size() and replay_positions[index] is Vector3:
			released_positions[index] = replay_positions[index]
		if index < replay_velocities.size() and replay_velocities[index] is Vector3:
			released_velocities[index] = replay_velocities[index]
		if index < replay_spin.size():
			released_spin_rad_s[index] = replay_spin[index]
		if index < replay_rotation.size():
			wheel_instances[index].rotation.z = replay_rotation[index]
			rim_instances[index].rotation.z = replay_rotation[index]
			hub_instances[index].rotation.z = replay_rotation[index]
	update_from_model(0.0)

func update_from_model(delta_s: float) -> void:
	if model == null:
		return
	for i in range(mini(anchor_indices.size(), wheel_instances.size())):
		if released[i] != 0:
			if delta_s > 0.0:
				released_velocities[i].y -= 9.80665 * delta_s
				released_positions[i] += released_velocities[i] * delta_s
				if released_positions[i].y < wheel_radius_m:
					released_positions[i].y = wheel_radius_m
					if released_velocities[i].y < 0.0:
						released_velocities[i].y *= -0.22
					released_velocities[i].x *= 0.95
					released_velocities[i].z *= 0.95
					released_spin_rad_s[i] *= 0.985
				var spin_delta := released_spin_rad_s[i] * delta_s
				wheel_instances[i].rotation.z -= spin_delta
				rim_instances[i].rotation.z -= spin_delta
				hub_instances[i].rotation.z -= spin_delta
			wheel_instances[i].position = released_positions[i]
			rim_instances[i].position = released_positions[i]
			hub_instances[i].position = released_positions[i]
			continue
		var node := model.nodes[anchor_indices[i]]
		var center := _vehicle_center()
		var side_sign := -1.0 if node.position_m.z < center.z else 1.0
		var desired := node.position_m + Vector3(0.0, -suspension_drop_m, side_sign * side_offset_m)
		var visual_target := desired
		if model != null and get_parent() is CompactHatchback:
			var vehicle := get_parent() as CompactHatchback
			if vehicle.rigid_chassis != null:
				var support := vehicle.rigid_chassis.suspension_contact_point_world(i)
				if is_finite(support.x) and is_finite(support.y) and is_finite(support.z):
					visual_target = support + Vector3.UP * wheel_radius_m + Vector3.FORWARD * side_sign * side_offset_m
		if visual_target.y < wheel_radius_m:
			visual_target.y = wheel_radius_m
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
