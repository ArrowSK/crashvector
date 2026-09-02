# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name PedestrianBuilder
extends RefCounted

# Generic articulated road-user proxy. It is intended for contact/trajectory
# visualisation only and is not an injury, dummy, bone, or tissue model.
const LEFT_FOOT: int = 0
const RIGHT_FOOT: int = 1
const LEFT_KNEE: int = 2
const RIGHT_KNEE: int = 3
const LEFT_HIP: int = 4
const RIGHT_HIP: int = 5
const PELVIS: int = 6
const CHEST: int = 7
const LEFT_SHOULDER: int = 8
const RIGHT_SHOULDER: int = 9
const HEAD: int = 10
const LEFT_HAND: int = 11
const RIGHT_HAND: int = 12

static func build(
	preset_id: StringName = RoadUserCatalog.PEDESTRIAN_ADULT,
	total_mass_kg: float = 75.0,
	origin_offset_m: Vector3 = Vector3.ZERO
) -> StructuralModel:
	var model := StructuralModel.new()
	model.barrier_enabled = false
	model.gravity_ms2 = Vector3(0.0, -9.80665, 0.0)
	model.ground_enabled = true
	model.ground_y_m = origin_offset_m.y
	model.ground_restitution = 0.05
	model.ground_tangent_retention = 0.72
	var height := RoadUserCatalog.pedestrian_height_m(preset_id)
	var scale := height / 1.75
	var mass := maxf(total_mass_kg, 10.0)
	var width := 0.12 * scale
	var shoulder_width := 0.23 * scale
	var hand_width := 0.43 * scale

	model.add_node(origin_offset_m + Vector3(0.0, 0.03 * scale, -width), mass * 0.035, true)
	model.add_node(origin_offset_m + Vector3(0.0, 0.03 * scale, width), mass * 0.035, true)
	model.add_node(origin_offset_m + Vector3(0.0, 0.48 * scale, -width), mass * 0.070)
	model.add_node(origin_offset_m + Vector3(0.0, 0.48 * scale, width), mass * 0.070)
	model.add_node(origin_offset_m + Vector3(0.0, 0.90 * scale, -width), mass * 0.080)
	model.add_node(origin_offset_m + Vector3(0.0, 0.90 * scale, width), mass * 0.080)
	model.add_node(origin_offset_m + Vector3(0.0, 0.96 * scale, 0.0), mass * 0.140)
	model.add_node(origin_offset_m + Vector3(-0.02 * scale, 1.29 * scale, 0.0), mass * 0.210)
	model.add_node(origin_offset_m + Vector3(-0.02 * scale, 1.43 * scale, -shoulder_width), mass * 0.050)
	model.add_node(origin_offset_m + Vector3(-0.02 * scale, 1.43 * scale, shoulder_width), mass * 0.050)
	model.add_node(origin_offset_m + Vector3(-0.04 * scale, 1.67 * scale, 0.0), mass * 0.080)
	model.add_node(origin_offset_m + Vector3(0.01 * scale, 1.08 * scale, -hand_width), mass * 0.050)
	model.add_node(origin_offset_m + Vector3(0.01 * scale, 1.08 * scale, hand_width), mass * 0.050)

	_add_beam(model, LEFT_FOOT, LEFT_KNEE, &"pedestrian_leg", 95000.0, 900.0)
	_add_beam(model, RIGHT_FOOT, RIGHT_KNEE, &"pedestrian_leg", 95000.0, 900.0)
	_add_beam(model, LEFT_KNEE, LEFT_HIP, &"pedestrian_leg", 105000.0, 1000.0)
	_add_beam(model, RIGHT_KNEE, RIGHT_HIP, &"pedestrian_leg", 105000.0, 1000.0)
	_add_beam(model, LEFT_HIP, PELVIS, &"pedestrian_pelvis", 145000.0, 1200.0)
	_add_beam(model, RIGHT_HIP, PELVIS, &"pedestrian_pelvis", 145000.0, 1200.0)
	_add_beam(model, LEFT_HIP, RIGHT_HIP, &"pedestrian_pelvis", 170000.0, 1300.0)
	_add_beam(model, PELVIS, CHEST, &"pedestrian_torso", 185000.0, 1500.0)
	_add_beam(model, CHEST, LEFT_SHOULDER, &"pedestrian_torso", 125000.0, 1100.0)
	_add_beam(model, CHEST, RIGHT_SHOULDER, &"pedestrian_torso", 125000.0, 1100.0)
	_add_beam(model, LEFT_SHOULDER, RIGHT_SHOULDER, &"pedestrian_torso", 145000.0, 1200.0)
	_add_beam(model, CHEST, HEAD, &"pedestrian_neck", 72000.0, 850.0)
	_add_beam(model, LEFT_SHOULDER, LEFT_HAND, &"pedestrian_arm", 56000.0, 650.0)
	_add_beam(model, RIGHT_SHOULDER, RIGHT_HAND, &"pedestrian_arm", 56000.0, 650.0)
	_add_beam(model, LEFT_HIP, RIGHT_SHOULDER, &"pedestrian_torso", 90000.0, 950.0)
	_add_beam(model, RIGHT_HIP, LEFT_SHOULDER, &"pedestrian_torso", 90000.0, 950.0)
	model.capture_initial_energy()
	return model

static func contact_nodes() -> PackedInt32Array:
	return PackedInt32Array([LEFT_HIP, RIGHT_HIP])

static func stance_nodes() -> PackedInt32Array:
	return PackedInt32Array([LEFT_FOOT, RIGHT_FOOT])

static func release_stance(model: StructuralModel) -> void:
	if model == null:
		return
	var transfer_velocity := model.average_velocity_ms()
	for index in stance_nodes():
		if index < 0 or index >= model.nodes.size():
			continue
		var node := model.nodes[index]
		if not node.pinned:
			continue
		node.pinned = false
		node.inverse_mass = 1.0 / maxf(node.mass_kg, 0.001)
		node.velocity_ms = transfer_velocity

static func stance_released(model: StructuralModel) -> bool:
	if model == null:
		return false
	for index in stance_nodes():
		if index >= 0 and index < model.nodes.size() and model.nodes[index].pinned:
			return false
	return true

static func _add_beam(model: StructuralModel, a: int, b: int, role: StringName, stiffness: float, damping: float) -> void:
	model.add_beam(a, b, role, stiffness, damping, 0.16, 0.42, 0.78, 8.0)
